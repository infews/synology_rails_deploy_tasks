# Rake Tasks for deploying a Rails app via a push to a container registry
#
# To Use:
#  1. gem install rainbow OR add gem rainbow to your Gemfile's development section
#  2. Download the synoctl app from https://github.com/LukeWinikates/synology-go/releases or Homebrew
#  3. Set the Configuration constants in the file deploy_config.rb
#  4. Invoke with `bundle exec rake syndeploy:update_version syndeploy:deploy`

# For colorization of output
require "rainbow/refinement"
using Rainbow

module SynDeploy
  def self.helper
    @helper ||= Helper.new
  end

  def self.configure
    yield helper if block_given?
  end

  class Helper
    attr_accessor :registry, :image, :app_id, :synoctl

    def initialize
      @current_step = 0
      @total_steps = 10
      @registry = @image = @app_id = @synoctl = ""
    end

    def full_image_name
      "#{@registry}/#{@image}"
    end

    def progress(msg)
      @current_step += 1
      puts
      puts ("🟦" * @current_step) + ("⬛️" * (@total_steps - @current_step)) + "  " + msg
      puts
    end
  end
end

# user configuration lives in this file
require_relative "deploy_config"

namespace :syndeploy do
  desc "Deploy to Synology NAS Docker"
  task deploy: [:ensure_clean_git,
                :tag_repo,
                :rebuild_assets,
                :build_image,
                :tag_image,
                :push_image,
                "assets:clobber",
                :synology_login,
                :pull_image,
                :project_restart]

  # Builds a date/time version file in Rails.root/config; Used as git tag; Can be used as a
  #   universal version in markup, etc.
  desc "Updates the version"
  task :update_version do
    version = Time.now.strftime("v%Y.%m.%d_%H.%M.%S")
    File.write("config/version.yml", version)
    git = Git.open(".")
    git.add("config/version.yml")
    git.commit("Updates version to #{version} prior to deploy")
  end

  task version_update: :update_version

  desc "Tag the git repo with a version"
  task :tag_repo do
    include SynDeploy

    deploy_tag = File.read("config/version.yml")

    git = Git.open(".")
    begin
      git.add_tag deploy_tag
    rescue => e
      if /already exists/.match?(e.message)
        git.delete_tag deploy_tag
        git.add_tag deploy_tag
      else
        puts e.message
        exit 1
      end
    end

    SynDeploy.helper.progress Rainbow("🎫 Repo tagged with current version number").cyan.bold
  end

  desc "Prevent cleaning & building with uncommitted changes"
  task :ensure_clean_git do
    stdout, _stderr, _status = Open3.capture3("git status -s")

    unless stdout.empty?
      puts
      puts Rainbow("✋ Please commit all changes before deploying so app has latest & greatest\n").goldenrod.bold
      exit 1
    end
  end

  desc "Clobber and rebuild assets"
  task :rebuild_assets do
    include SynDeploy

    # clean and rebuild assets
    begin
      system "./bin/rails assets:clobber", exception: true
      system "./bin/rails assets:precompile", exception: true
    rescue => e
      puts e.message
      exit 1
    end

    SynDeploy.helper.progress Rainbow("Re-built assets in ").cyan.bold + Rainbow("./public \n").bold
  end

  desc "Build and save container image"
  task :build_image do
    include SynDeploy

    # Build container image
    SynDeploy.helper.progress Rainbow("Building container image for Intel").cyan.bold

    _stdout, stderr, status = Open3.capture3("docker ps")

    if status != 0
      puts
      puts Rainbow(stderr).goldenrod.bold
      exit 1
    end

    key = File.read("config/master.key")
    begin
      system "docker buildx build --build-arg=\"MASTER_KEY=#{key}\" --platform linux/amd64 -t #{SynDeploy.helper.image} .", exception: true
    rescue => e
      puts e.message
      puts Rainbow("Docker build failed").red.bold
      exit 1
    end
  end

  desc "Tags image for local registry & git"
  task :tag_image do
    include SynDeploy

    SynDeploy.helper.progress Rainbow("Tagging image for local registry with version").cyan.bold

    begin
      system "docker tag #{SynDeploy.helper.image} #{SynDeploy.helper.full_image_name}", exception: true
    rescue => e
      puts e.message
      exit 1
    end
  end

  desc "Pushes image to local registry"
  task :push_image do
    include SynDeploy

    SynDeploy.helper.progress Rainbow("Pushing image to local registry").cyan.bold

    begin
      system "docker push #{SynDeploy.helper.full_image_name}", exception: true
    rescue => e
      puts e.message
      puts Rainbow("Docker image push failed").red.bold
      exit 1
    end

    SynDeploy.helper.progress Rainbow("Push complete. Update image and rebuild project on NAS.").green.bold
  end

  desc "Logs in to Synology"
  task :synology_login do
    include SynDeploy

    SynDeploy.helper.progress Rainbow("Logging into Synology").cyan.bold

    begin
      system "#{SynDeploy.helper.synoctl} login", exception: true
    rescue => e
      puts e.message
      puts Rainbow("Login failed").red.bold
      exit 1
    end
  end

  desc "Pulls the latest image from the local registry"
  task :pull_image do
    include SynDeploy

    SynDeploy.helper.progress Rainbow("Pulling image into Container Manager").cyan.bold

    begin
      system "#{SynDeploy.helper.synoctl} docker images pull --repository=#{SynDeploy.helper.image} --tag=latest", exception: true
    rescue => e
      puts e.message
      puts Rainbow("Image pull failed").red.bold
      exit 1
    end
  end

  desc "Stops, Rebuilds, Starts the project"
  task :project_restart do
    include SynDeploy

    SynDeploy.helper.progress Rainbow("Stopping App (Container Manager Project)").cyan.bold

    begin
      system "#{SynDeploy.helper.synoctl} docker projects stop --id=#{SynDeploy.helper.app_id}", exception: true
    rescue => e
      puts e.message
      puts Rainbow("Project stop failed").red.bold
      exit 1
    end

    SynDeploy.helper.progress Rainbow("Rebuilding App (Container Manager Project)").cyan.bold

    begin
      system "#{SynDeploy.helper.synoctl} docker projects build --id=#{SynDeploy.helper.app_id}", exception: true
    rescue => e
      puts e.message
      puts Rainbow("Rebuild failed").red.bold
      exit 1
    end

    puts Rainbow("Deploy Complete - Synology needs about 2 mins to restart; App will return 502 until then.").cyan.bold
  end
end
