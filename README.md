# Synology on Rails Deploy Tasks
 
The `deploy.rake` is a companion file to my blog series [Synology On Rails](https://dwf.bigpencil.net/series/rails-docker-nas/).

This is from Part IV, where I embraced `docker-compose.yml` and how Synology handles containers in DSM 7.x.

## What's Here?

- Generating a version in `config/version.yml`
- Building your container image using however you've set up your `Dockerfile`, etc.
- Tagging your Git repo with the version
- Tagging your image with the repo you're pushing to
- Pushing your image to that repo
- Nice STDOUT messaging

## Prerequisites & Notes

- Assumes/requires Docker running
- Git for version control
- Embracing the version number generation

## How to Use

1. Drop `deploy.rake` in your Rails App's `lib/tasks`
2. Update the constants at the top of the file
3. Customize as you see fit
4. Deploy with: `bundle exec rake update_version deploy`