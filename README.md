# Synology on Rails Deploy Tasks
 
Rake tasks supporting my blog series [Synology On Rails](https://dwf.bigpencil.net/series/rails-docker-nas/).

This is from Part V, where I embraced [Luke Winikates's](https://github.com/LukeWinikates/) [Synoctl](https://github.com/LukeWinikates/synology-go) for communicating with the Synology DSM.

## Why?

Because you have a Synology NAS, it runs Kubernetes, so whyynot deploy your toy Rails apps to it? More in the blog series above.

And if you're curious about why I'm not just using Kamal, I will just say that at this moment, Kamal's expectations don't quite match what Synology expects.

## Dependencies and Assumptions

- You're writing a Rails App
- Docker is running locally
- You have a Synology NAS with DSM 7.x
- You have installed synoctl
- You have a registry running on your Synology (see part III of the blog series)

## What's Here?

This is a set of Rails Rake tasks that automates building your Rails app's image, then deploying it on your Synology NAS via the DSM 7.x Container Manager.

### `rake syndeploy:update_version`

_Alias:_ `rake syndeploy:version_update`

This is my pattern, but I like having a date-based application version that lives in `config/version.yml`, renders in the app footer, and is a tag on the commit in the app repo. YMMV.


### `rake syndeploy:ensure_clean_git`

Prevents a deploy from happening if your git repo has uncommitted changes. This saves my behind regularly.

### `rake syndeploy:tag_repo`

Tags `HEAD` with the version from `config/version.yml`.

### `rake syndeploy:rebuild_assets`

Clobbers and rebuilds the Rails assets so the latest version is deployed.

### `rake syndeploy:build_image`

Builds the Docker image. 

_Note:_ Assumes that you are on different silicon architecture than your Intel/x86-64 of your Synology.

### `rake syndeploy:tag_image`

Tags image for local registry. This is necessary for Docker to push the image to the local registry instead of DockerHub.

### `rake syndeploy:push_image`

Pushes image to the registry.

### `rake syndeploy:synology_login`

Logs in to Synology. Provide your username and password for your Synology DSM admin on the command line.

Uses `synoctl`.

### `rake syndeploy:pull_image`

Tells Container Manager to pull the latest image from the local registry.

Uses `synoctl`.

### `rake syndeploy:project_restart`

Stops, Rebuilds, Starts the Container Manager Project. 

Uses `synoctl`.

### `rake syndeploy:deploy`

Wraps all of the above in (almost) one task to do it all

## How to Use

1. Add `deploy.rake` in your Rails App's `lib/tasks`
2. Add `deploy_config.rb` in your Rails App's `lib/tasks`. Update the `configure` block for your app
4. Deploy with: `bundle exec rake syndeploy:update_version syndeploy:deploy`