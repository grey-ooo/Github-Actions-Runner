ARG PHP_VERSION=8.4
FROM matthewbaggett/php:${PHP_VERSION} AS runner

# `source` points at the Forgejo repo this is actually built from. Note that
# GHCR only attaches a package to a github.com repo owned by the same account
# as the package, so no linkage appears on the GHCR side either way.
ARG PHP_VERSION
LABEL org.opencontainers.image.source="https://git.grey.ooo/actions/Github-Actions-Runner"
LABEL org.opencontainers.image.url="https://git.grey.ooo/actions/Github-Actions-Runner"
LABEL org.opencontainers.image.title="Github-Actions-Runner"
LABEL org.opencontainers.image.description="Self-hosted GitHub/Forgejo Actions runner image"
LABEL org.opencontainers.image.version="php${PHP_VERSION}"
WORKDIR /root
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=24

WORKDIR /build
ARG BASE_PACKAGES="bash bash-completion shadow \
                   ca-certificates openssl coreutils findutils  \
                   tar gzip bzip2 xz zip unzip zstd \
                   ncurses \
                   git openssh-client net-tools \
                   gpg gnupg \
                   curl wget rsync \
                   nano vim make g++ \
                   libc6-compat musl-dev linux-headers"
ARG DOCKER_PACKAGES="docker-cli docker-cli-compose docker-cli-buildx docker-bash-completion"
ARG AWS_PACKAGES="aws-cli aws-cli-bash-completion"
ARG GO_PACKAGES="go"
ARG EXTRA_PACKAGES="nginx sqlite postgresql-client mysql-client mariadb-connector-c redis yq jq sudo nmap"

RUN sed -i '/community/s/^#//' /etc/apk/repositories
RUN apk add --no-cache $BASE_PACKAGES
RUN apk add --no-cache $DOCKER_PACKAGES
RUN apk add --no-cache $AWS_PACKAGES
RUN apk add --no-cache $GO_PACKAGES
RUN apk add --no-cache $EXTRA_PACKAGES
RUN chsh root -s /bin/bash || true
SHELL ["/bin/bash", "-c"]

# Install nvm with node and npm and yarn
RUN <<NODE_INSTALL
  apk add --no-cache nodejs nodejs-dev yarn npm

  node --version
NODE_INSTALL

# OpenTofu only reached Alpine's community repo in 3.20, so `apk add opentofu`
# fails outright on the older bases (php7.4, php8.1). Install the upstream
# release archive instead: it is a static binary, and every PHP variant then
# gets the same pinned version regardless of what its base image packages.
ARG TOFU_VERSION=1.12.5
RUN <<TOFU_INSTALL
  set -euo pipefail
  case "$(apk --print-arch)" in
    x86_64)  TOFU_ARCH=amd64 ;;
    aarch64) TOFU_ARCH=arm64 ;;
    *)       echo "No OpenTofu build for $(apk --print-arch)" >&2; exit 1 ;;
  esac
  TOFU_URL="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}"
  cd "$(mktemp -d)"
  curl -fsSLO "${TOFU_URL}/tofu_${TOFU_VERSION}_linux_${TOFU_ARCH}.zip"
  curl -fsSLO "${TOFU_URL}/tofu_${TOFU_VERSION}_SHA256SUMS"
  grep " tofu_${TOFU_VERSION}_linux_${TOFU_ARCH}.zip\$" "tofu_${TOFU_VERSION}_SHA256SUMS" | sha256sum -c -
  unzip -q "tofu_${TOFU_VERSION}_linux_${TOFU_ARCH}.zip" tofu -d /usr/local/bin
  chmod +x /usr/local/bin/tofu
  tofu version
TOFU_INSTALL

# The AWS CLI itself comes from apk (see AWS_PACKAGES above), but the wider AWS
# toolchain is not packaged for Alpine. eksctl and aws-iam-authenticator are
# static Go binaries, so the upstream release archives run fine on musl and
# every PHP variant gets the same pinned version. Both publish a checksums file
# we verify against.
#
# session-manager-plugin is deliberately omitted: AWS ships it only as a
# glibc-linked binary (needs libresolv.so.2 etc.), so it cannot run on Alpine's
# musl without bundling a full glibc — the same dead end as the AWS CLI v2
# installer, which is why the v1/v2 apk build above is what provides `aws`.
ARG EKSCTL_VERSION=0.229.0
ARG AWS_IAM_AUTHENTICATOR_VERSION=0.7.18
RUN <<AWS_TOOLS_INSTALL
  set -euo pipefail
  case "$(apk --print-arch)" in
    x86_64)  GO_ARCH=amd64 ;;
    aarch64) GO_ARCH=arm64 ;;
    *)       echo "No AWS tool builds for $(apk --print-arch)" >&2; exit 1 ;;
  esac

  # eksctl
  cd "$(mktemp -d)"
  EKSCTL_URL="https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}"
  curl -fsSLO "${EKSCTL_URL}/eksctl_Linux_${GO_ARCH}.tar.gz"
  curl -fsSLO "${EKSCTL_URL}/eksctl_checksums.txt"
  grep " eksctl_Linux_${GO_ARCH}.tar.gz\$" eksctl_checksums.txt | sha256sum -c -
  tar -xzf "eksctl_Linux_${GO_ARCH}.tar.gz" -C /usr/local/bin eksctl
  eksctl version

  # aws-iam-authenticator
  cd "$(mktemp -d)"
  AIA_URL="https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${AWS_IAM_AUTHENTICATOR_VERSION}"
  curl -fsSLO "${AIA_URL}/aws-iam-authenticator_${AWS_IAM_AUTHENTICATOR_VERSION}_linux_${GO_ARCH}"
  curl -fsSLO "${AIA_URL}/authenticator_${AWS_IAM_AUTHENTICATOR_VERSION}_checksums.txt"
  grep " aws-iam-authenticator_${AWS_IAM_AUTHENTICATOR_VERSION}_linux_${GO_ARCH}\$" "authenticator_${AWS_IAM_AUTHENTICATOR_VERSION}_checksums.txt" | sha256sum -c -
  install -m 0755 "aws-iam-authenticator_${AWS_IAM_AUTHENTICATOR_VERSION}_linux_${GO_ARCH}" /usr/local/bin/aws-iam-authenticator
  aws-iam-authenticator version
AWS_TOOLS_INSTALL

COPY ./fs/. /

RUN <<CONFIGURE
  date -u +"%Y-%m-%dT%H:%M:%SZ" > /etc/build-time

  # Setup known hosts for git over ssh
  mkdir -p /root/.ssh /root/.ssh/.control
  touch /root/.ssh/known_hosts
  ssh-keyscan -p 222 git.grey.ooo >> /root/.ssh/known_hosts
  chmod 644 /root/.ssh/known_hosts
  chmod 700 /root/.ssh/.control

  # OpenTofu ships no bash-completion subpackage, so register the completion
  # handler ourselves. Appends to /root/.bashrc and /root/.profile.
  tofu -install-autocomplete
CONFIGURE

# Kept last: these change on every commit, so declaring them earlier would
# invalidate the build cache for everything below them.
ARG VCS_REF="unknown"
ARG BUILD_DATE=""
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"

#FROM runner AS embedded-runner
#ARG BUILD_ESSENTIAL="alpine-sdk make cmake git build-base linux-headers"
#ARG ARDUINO_PACKAGES="arduino-cli"
#RUN apk add --no-cache $BUILD_ESSENTIAL
#RUN apk add --no-cache $ARDUINO_PACKAGES --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing
