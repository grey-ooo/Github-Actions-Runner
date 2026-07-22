variable "DOCKERHUB_REPO" {
  default = "matthewbaggett/act-runner"
}

variable "GHCR_REPO" {
  default = "ghcr.io/grey-ooo/github-actions-runner"
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
    ["${DOCKERHUB_REPO}:php${php}"],
    php == PHP_VERSION_CURRENT ? ["${DOCKERHUB_REPO}:latest"] : [],
    ["${GHCR_REPO}:php${php}"],
    php == PHP_VERSION_CURRENT ? ["${GHCR_REPO}:latest"] : []
  )
  args = {
    NODE_VERSION     = "20"
    PHP_VERSION      = php
    COMPOSER_VERSION = COMPOSER_VERSION
  }
  platforms = MULTIARCH == "true" ? ["linux/amd64", "linux/arm64"] : ["linux/amd64"]
}
