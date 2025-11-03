FROM git.grey.ooo/mirrors/node:22-alpine AS runner
WORKDIR /build
RUN <<UPDATE_NPM
#  npm --version
#  npm install npm@latest -g
#  npm --version
  npm update -g
UPDATE_NPM

ARG PHP_VERSION=8.4
ARG COMPOSER_VERSION=latest-stable
ARG BASE_PACKAGES="bash bash-completion shadow \
                   ca-certificates coreutils findutils \
                   tar gzip bzip2 xz zip unzip \
                   procps-ng \
                   git openssh-client net-tools iputils-ping \
                   curl wget rsync \
                   nano vim"
ARG DOCKER_PACKAGES="docker-cli docker-cli-compose docker-cli-buildx docker-bash-completion"
ARG AWS_PACKAGES="aws-cli aws-cli-bash-completion"
ARG GO_PACKAGES="go"
ARG PHP_PACKAGES="php84 php84-bcmath php84-bz2 php84-calendar php84-ctype php84-curl php84-dom php84-exif php84-fileinfo php84-ftp \
                  php84-fpm php84-gd php84-gettext php84-gmp php84-iconv php84-imap php84-intl php84-ldap php84-mbstring \
                  php84-mysqli php84-mysqlnd php84-odbc php84-opcache php84-openssl php84-pcntl \
                  php84-pdo php84-pdo_dblib php84-pdo_mysql php84-pdo_odbc php84-pdo_pgsql php84-pdo_sqlite php84-pgsql php84-phar \
                  php84-posix php84-session php84-shmop php84-simplexml php84-snmp php84-soap php84-sockets php84-sodium php84-sqlite3 \
                  php84-sysvmsg php84-sysvsem php84-sysvshm php84-tidy php84-tokenizer php84-xml php84-xmlreader php84-xmlwriter \
                  php84-xsl php84-zip php84-zlib \
                  php84-pecl-apcu php84-pecl-redis php84-pecl-msgpack php84-pecl-xdebug"
ARG EXTRA_PACKAGES="nginx sqlite postgresql-client mysql-client mariadb-connector-c redis yq jq sudo"

RUN sed -i 's/https:\/\//http:\/\//g' /etc/apk/repositories
RUN apk add --no-cache $BASE_PACKAGES
RUN apk add --no-cache $DOCKER_PACKAGES
RUN apk add --no-cache $AWS_PACKAGES
RUN apk add --no-cache $GO_PACKAGES
RUN apk add --no-cache $PHP_PACKAGES
RUN apk add --no-cache $EXTRA_PACKAGES
RUN chsh root -s /bin/bash

SHELL ["/bin/bash", "-c"]

RUN <<FIX_PHP
  set -ue
  PHP_VER=$(echo $PHP_VERSION | tr -d '.')
  # if PHP_VER is less than 80, set it to 7
  if [[ "$PHP_VER" -lt 80 ]]; then
    PHP_VER=7
  fi

  # Move some binary names around as well as other bits and pieces
  ln -s /etc/php /etc/php${PHP_VER} || true
  ln -s /usr/bin/php${PHP_VER} /usr/bin/php || true
  ln -s /usr/sbin/php-fpm${PHP_VER} /usr/sbin/php-fpm || true
  ln -s /usr/share/php${PHP_VER} /usr/share/php || true
  ln -s /var/log/php${PHP_VER} /var/log/php || true

  php --version
FIX_PHP

RUN <<INSTALL_COMPOSER
  # Install composer
  curl https://getcomposer.org/download/$COMPOSER_VERSION/composer.phar --output /usr/local/bin/composer --silent
  chmod +x /usr/local/bin/composer

  composer --version
INSTALL_COMPOSER

RUN <<INSTALL_TRUNK
    npm install -D @trunkio/launcher
INSTALL_TRUNK

COPY ./fs/. /
ENV BASH_ENV="/etc/bash.bashrc"

RUN <<CONFIGURE
  date -u +"%Y-%m-%dT%H:%M:%SZ" > /etc/build-time

  # Setup known hosts for git over ssh
  mkdir -p /root/.ssh
  touch /root/.ssh/known_hosts
  ssh-keyscan -p 222 git.grey.ooo >> /root/.ssh/known_hosts
  chmod 644 /root/.ssh/known_hosts
CONFIGURE

FROM runner AS embedded-runner
ARG ARDUINO_PACKAGES="arduino-cli"
RUN apk add --no-cache $ARDUINO_PACKAGES --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing
