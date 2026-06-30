ARG PHP_VERSION=8.4
FROM matthewbaggett/php:${PHP_VERSION} AS runner
WORKDIR /root
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=24

WORKDIR /build
ARG PHP_VERSION=8.4
ARG COMPOSER_VERSION=latest-stable
ARG BASE_PACKAGES="bash bash-completion shadow \
                   ca-certificates coreutils findutils  \
                   tar gzip bzip2 xz zip unzip zstd \
                   procps-ng ncurses \
                   git openssh-client net-tools iputils-ping \
                   curl wget rsync \
                   nano vim make \
                   libc6-compat musl-dev linux-headers"
ARG DOCKER_PACKAGES="docker-cli docker-cli-compose docker-cli-buildx docker-bash-completion"
ARG AWS_PACKAGES="aws-cli aws-cli-bash-completion"
ARG GO_PACKAGES="go"
ARG PHP_VER=${PHP_VERSION//./}
ARG PHP_PACKAGES="php$PHP_VER php$PHP_VER-bcmath php$PHP_VER-bz2 php$PHP_VER-calendar php$PHP_VER-ctype php$PHP_VER-curl php$PHP_VER-dom php$PHP_VER-exif php$PHP_VER-fileinfo php$PHP_VER-ftp \
                  php$PHP_VER-fpm php$PHP_VER-gd php$PHP_VER-gettext php$PHP_VER-gmp php$PHP_VER-iconv php$PHP_VER-imap php$PHP_VER-intl php$PHP_VER-ldap php$PHP_VER-mbstring \
                  php$PHP_VER-mysqli php$PHP_VER-mysqlnd php$PHP_VER-odbc php$PHP_VER-openssl php$PHP_VER-pcntl \
                  php$PHP_VER-pdo php$PHP_VER-pdo_dblib php$PHP_VER-pdo_mysql php$PHP_VER-pdo_odbc php$PHP_VER-pdo_pgsql php$PHP_VER-pdo_sqlite php$PHP_VER-pgsql php$PHP_VER-phar \
                  php$PHP_VER-posix php$PHP_VER-session php$PHP_VER-shmop php$PHP_VER-simplexml php$PHP_VER-snmp php$PHP_VER-soap php$PHP_VER-sockets php$PHP_VER-sodium php$PHP_VER-sqlite3 \
                  php$PHP_VER-sysvmsg php$PHP_VER-sysvsem php$PHP_VER-sysvshm php$PHP_VER-tidy php$PHP_VER-tokenizer php$PHP_VER-xml php$PHP_VER-xmlreader php$PHP_VER-xmlwriter \
                  php$PHP_VER-xsl php$PHP_VER-zip php$PHP_VER-zlib \
                  php$PHP_VER-pecl-apcu php$PHP_VER-pecl-redis php$PHP_VER-pecl-msgpack php$PHP_VER-pecl-xdebug"
ARG EXTRA_PACKAGES="nginx sqlite postgresql-client mysql-client mariadb-connector-c redis yq jq sudo nmap"

RUN sed -i '/community/s/^#//' /etc/apk/repositories
RUN apk add --no-cache $BASE_PACKAGES
RUN apk add --no-cache $DOCKER_PACKAGES
RUN apk add --no-cache $AWS_PACKAGES
RUN apk add --no-cache $GO_PACKAGES
RUN apk add --no-cache $PHP_PACKAGES
# Conditionally install php$PHP_VER-opcache if it exists.
RUN if apk info | grep -q "php$PHP_VER-opcache"; then apk add --no-cache php$PHP_VER-opcache; fi
RUN apk add --no-cache $EXTRA_PACKAGES
RUN chsh root -s /bin/bash
SHELL ["/bin/bash", "-c"]

RUN <<FIX_PHP
  set -ue
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
