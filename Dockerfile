FROM ubuntu:18.04

ARG CRATES_REGISTRY_PATH
ARG NPM_REGISTRY_PATH

ENV HOME /home/developer
ENV RUSTUP_HOME ${HOME}/.rustup
ENV CARGO_HOME ${HOME}/.cargo
ENV PATH=${HOME}/.cargo/bin:$PATH

# Install required system libraries
RUN apt-get update \
    && apt-get install -y \
    ca-certificates \
    cmake \
    curl \
    gcc \
    git \
    libasound2 \
    libc6-dev \
    libgtk2.0-0 \
    libssl-dev \
    libxss1 \
    make \
    pkg-config \
    sudo \
    upx-ucl \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Add a user "developer" with password "password" 
RUN useradd --create-home --shell /bin/bash -g root -G sudo developer \
    && echo 'developer:password' | chpasswd
WORKDIR ${HOME}

# Install rust through rustup
USER developer
RUN curl -o rustup.sh https://sh.rustup.rs -sS \
    && sh rustup.sh -y --no-modify-path \
    && rustup component add rls-preview rust-analysis rust-src \
    && rustup target add x86_64-unknown-linux-musl \
    && rustup install nightly \
    && rustup component add --toolchain=nightly clippy-preview \
    && rustup target add --toolchain=nightly x86_64-unknown-linux-musl \
    && rm -f rustup.sh
USER root

# Install yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \ 
    && apt-get -y install yarn \
    && yarn config set yarn-offline-mirror ${HOME}/npm-registry \
    && rm -rf /var/lib/apt/lists/*

# Install vscode
RUN apt-get update \
    && curl -o vscode.deb -J -L https://vscode-update.azurewebsites.net/1.24.1/linux-deb-x64/stable \
    && apt install -y ./vscode.deb \
    && rm -f vscode.deb \
    && rm -rf /var/lib/apt/lists/*

USER developer

# Install vscode extensions
RUN code --install-extension bungcip.better-toml
RUN code --install-extension streetsidesoftware.code-spell-checker
RUN code --install-extension msjsdiag.debugger-for-chrome
RUN code --install-extension PKief.material-icon-theme
RUN code --install-extension AdamCaviness.theme-monokai-dark-soda
RUN code --install-extension esbenp.prettier-vscode
RUN code --install-extension rust-lang.rust
RUN code --install-extension robinbentley.sass-indented
RUN code --install-extension mrmlnc.vscode-scss
RUN code --install-extension eg2.tslint

# Modify vscode settings
COPY vscode_settings.json ${HOME}/.config/Code/User/settings.json

# Install vendored crates
COPY ${CRATES_REGISTRY_PATH} ${HOME}/crates-registry
RUN echo "[source.crates-io]" >> .cargo/config \
    && echo "registry = 'https://github.com/rust-lang/crates.io-index'" >> .cargo/config \
    && echo "replace-with = 'local-registry'" >> .cargo/config \
    && echo "" >> .cargo/config \
    && echo "[source.local-registry]" >> .cargo/config \
    && echo "local-registry = '/home/developer/crates-registry'" >> .cargo/config

### Install vendored npm
COPY ${NPM_REGISTRY_PATH} ${HOME}/npm-registry

USER root

### Setup musl target
COPY musl-setup/musl.sh musl-setup/openssl.sh /
COPY musl-setup/musl-gcc.x86_64-unknown-linux-musl /usr/local/bin/musl-gcc
COPY musl-setup/musl-gcc.specs.x86_64-unknown-linux-musl /usr/local/lib/musl-gcc.specs
RUN bash /musl.sh 1.1.15 && \
    bash /openssl.sh linux-x86_64 musl- -static
ENV CC_x86_64_unknown_linux_musl=musl-gcc \
    OPENSSL_DIR=/openssl \
    OPENSSL_INCLUDE_DIR=/openssl/include \
    OPENSSL_LIB_DIR=/openssl/lib

WORKDIR ${HOME}/project

USER developer
