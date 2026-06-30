ARG PHP_VERSION=8.4
FROM matthewbaggett/php:${PHP_VERSION} AS runner
WORKDIR /root
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=24

WORKDIR /build
ARG BASE_PACKAGES="bash bash-completion shadow \
                   ca-certificates coreutils findutils  \
                   tar gzip bzip2 xz zip unzip zstd \
                   ncurses \
                   git openssh-client net-tools \
                   curl wget rsync \
                   nano vim make \
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

COPY ./fs/. /

RUN <<CONFIGURE
  date -u +"%Y-%m-%dT%H:%M:%SZ" > /etc/build-time

  # Setup known hosts for git over ssh
  mkdir -p /root/.ssh
  touch /root/.ssh/known_hosts
  ssh-keyscan -p 222 git.grey.ooo >> /root/.ssh/known_hosts
  chmod 644 /root/.ssh/known_hosts
CONFIGURE

#FROM runner AS embedded-runner
#ARG BUILD_ESSENTIAL="alpine-sdk make cmake git build-base linux-headers"
#ARG ARDUINO_PACKAGES="arduino-cli"
#RUN apk add --no-cache $BUILD_ESSENTIAL
#RUN apk add --no-cache $ARDUINO_PACKAGES --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing
