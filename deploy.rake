# Rake Tasks for deploying a Rails app via a push to a container registry
#
# To Use:
#  1. gem install rainbow OR add gem rainbow to your Gemfile's development section
#  2. Set the IMAGE and REGISTRY constants below
#  3. Invoke with `bundle exec rake update_version deploy`

# For colorization of output
require "rainbow/refinement"
using Rainbow

# Name of the image, and the registry you are pushing to
IMAGE = "dwfrank/derby"
REGISTRY  = "registry.balboa.local"

def progress(num, total)
  ("🟦" * num) + ("⬛️" * (total - num)) + " "
end

desc "Deploy to Synology NAS Docker"
task deploy: [:ensure_clean_git,
              :tag_repo,
              :rebuild_assets,
              :build_image,
              :tag_image,
              :push_image,
              "assets:clobber"]

# Builds a date/time version file in ./config; Used as git tag; Can be used as a
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

desc "Prevent cleaning & building with uncommitted changes"
task :ensure_clean_git do
  stdout, _stderr, _status = Open3.capture3("git status -s")

  unless stdout.empty?
    puts
    puts Rainbow("✋ Please commit all changes before deploying so app has latest & greatest\n").goldenrod.bold
    exit 1
  end
end

desc "Tag the git repo with a version"
task :tag_repo do
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
    end
  end

  puts
  puts progress(1, 6) + Rainbow("🎫 Repo tagged with current version number").cyan.bold
  puts
end

desc "Clobber and rebuild assets"
task :rebuild_assets do
  # clean and rebuild assets
  system "./bin/rails assets:clobber"
  system "./bin/rails assets:precompile"

  puts ""
  puts progress(2,6) + Rainbow("Re-built assets in ").cyan.bold + Rainbow("./public \n").bold
end

desc "Build and save container image"
task :build_image do
  # Build container image
  puts
  puts progress(3, 6) + Rainbow("Building container image for Intel").cyan.bold

  _stdout, stderr, status = Open3.capture3("docker ps")

  if status != 0
    puts
    puts Rainbow(stderr).goldenrod.bold
    exit 1
  end

  key = File.read("config/master.key")
  success = system "docker buildx build --build-arg=\"MASTER_KEY=#{key}\" --platform linux/amd64 -t #{IMAGE} ."

  if success == false
    puts Rainbow("Docker build failed").red.bold
    exit 1
  end
end

desc "Tags image for local registry & git"
task :tag_image do
  puts
  puts progress(4, 6) + Rainbow("Tagging image for local registry with version").cyan.bold
  system "docker tag #{IMAGE} #{REGISTRY}/#{IMAGE}"
end

desc "Pushes image to local registry"
task :push_image do
  
  puts
  puts progress(5,6) + Rainbow("Pushing image to local registry").cyan.bold
  system "docker push #{REGISTRY}/#{IMAGE}"

  puts
  puts progress(6,6) + Rainbow("Push complete. Update image and rebuild project on NAS.").green.bold
  puts
end