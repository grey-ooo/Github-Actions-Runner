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

group "default" {
  targets = ["runner"]
}

variable "PLATFORMS" {
  default = [
    "linux/amd64",
    "linux/arm64"
  ]
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
    php == PHP_VERSION_CURRENT ? ["${DOCKERHUB_REPO}:latest"] : []
  )
  args = {
    NODE_VERSION     = "20"
    PHP_VERSION      = php
    COMPOSER_VERSION = COMPOSER_VERSION
  }
  platforms = PLATFORMS
}
