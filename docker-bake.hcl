variable "BAKE_CONTEXT" {
  default = "./dockerfiles"
}

variable "DOCKERFILE" {
  default = "rust-debian.Dockerfile"
}

variable "DOCKER_IMAGE" {
  default = "docker.io/hichamaz/base"
}

variable "DOCKER_TAG_PRIMARY" {
  default = "latest"
}

variable "DOCKER_TAG_EXTRA" {
  default = ""
}

variable "DOCKER_PLATFORMS" {
  default = "linux/amd64,linux/arm64"
}

target "_common" {
  context    = "${BAKE_CONTEXT}"
  dockerfile = "${DOCKERFILE}"
  platforms  = split(",", DOCKER_PLATFORMS)
  provenance = false
  secret = [
    "id=git-credentials,env=GIT_CREDENTIALS",
  ]
}

target "base" {
  inherits = ["_common"]
  target   = "base"
  tags     = ["${DOCKER_IMAGE}:${DOCKER_TAG_PRIMARY}"]
}

target "dev" {
  inherits = ["_common"]
  target   = "dev"
  tags     = ["${DOCKER_IMAGE}:${DOCKER_TAG_PRIMARY}-dev"]
}

group "default" {
  targets = ["base", "dev"]
}
