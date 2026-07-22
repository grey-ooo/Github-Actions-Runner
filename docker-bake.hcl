# Docker Hub and GHCR are co-equal registries: every publish pushes the same
# tags to both, and neither is conditional on the other.
#
# Runner-facing references (the workflow's `container:`, compose.yml) should
# still prefer GHCR. That is a pull consideration, not a publish one: Docker
# Hub rate limits anonymous pulls (~100/6h per IP) and the Forgejo runners
# pull on every job with force_pull, which exhausted the quota and broke every
# job at the setup step.
variable "GHCR_REPO" {
  default = "ghcr.io/matthewbaggett/act-runner"
}

variable "DOCKERHUB_REPO" {
  default = "matthewbaggett/act-runner"
}

variable "PHP_VERSION_CURRENT" {
  default = 8.4
}
variable "PHP_AVAILABLE_VERSIONS" {
  default = [7.4, 8.1, 8.2, 8.3, 8.4, 8.5]
}

variable "COMPOSER_VERSION" {
  default = "latest-stable"
}

# Provenance for the OCI labels. CI passes the real commit; local builds get
# the placeholders from the Dockerfile.
variable "VCS_REF" {
  default = "unknown"
}
variable "BUILD_DATE" {
  default = ""
}

group "default" {
  targets = ["runner"]
}

# Set MULTIARCH=true to build the full platform matrix (done on main only).
# Everything else builds amd64 only, which keeps PR/branch builds quick.
variable "MULTIARCH" {
  default = "false"
}

target "runner" {
  matrix = {
    php = PHP_AVAILABLE_VERSIONS
  }

  name       = "runner-php${replace(php, ".", "")}"
  context    = "."
  dockerfile = "Dockerfile"
  target     = "runner"
  tags = concat(
    ["${GHCR_REPO}:php${php}"],
    php == PHP_VERSION_CURRENT ? ["${GHCR_REPO}:latest"] : [],
    ["${DOCKERHUB_REPO}:php${php}"],
    php == PHP_VERSION_CURRENT ? ["${DOCKERHUB_REPO}:latest"] : []
  )
  args = {
    NODE_VERSION     = "20"
    PHP_VERSION      = php
    COMPOSER_VERSION = COMPOSER_VERSION
    VCS_REF          = VCS_REF
    BUILD_DATE       = BUILD_DATE
  }
  platforms = MULTIARCH == "true" ? ["linux/amd64", "linux/arm64"] : ["linux/amd64"]
}
