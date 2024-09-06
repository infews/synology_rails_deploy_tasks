SynDeploy.configure do |h|
  # path to registry (if not using Dockerhub)
  # h.registry = "registry.balboa.local"

  # image name in Container Manager
  # h.image = "dwfrank/meals"

  # app id for this Container Manager Project (find via synoctl project list)
  # h.app_id = "some guid"

  # path to synoctl exec (if not already on PATH)
  # h.synoctl = "../synology-ctl/synoctl"
end
