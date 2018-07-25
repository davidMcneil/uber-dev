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
    nano \
    npm \
    pkg-config \
    python \
    rpm \
    sudo \
    upx-ucl \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Add a user "developer" with password "password" 
RUN useradd --create-home --shell /bin/bash -g root -G sudo developer \
    && echo 'developer:password' | chpasswd

WORKDIR ${HOME}

USER developer

# Install rust through rustup
RUN curl -o rustup.sh https://sh.rustup.rs -sS \
    && sh rustup.sh -y --no-modify-path \
    && rm -f rustup.sh
RUN rustup component add rls-preview rust-analysis rust-src
RUN rustup target add x86_64-unknown-linux-musl
RUN rustup install nightly
RUN rustup component add --toolchain=nightly clippy-preview
RUN rustup target add --toolchain=nightly x86_64-unknown-linux-musl
RUN RUSTFLAGS="--cfg procmacro2_semver_exempt" cargo install cargo-tarpaulin \
    && cargo install \
    cargo-asm \
    cargo-audit \
    cargo-benchcmp \
    cargo-bloat \
    cargo-count \
    cargo-deadlinks \
    cargo-deb \
    cargo-expand \
    cargo-fuzz \
    cargo-graph \
    cargo-make \
    cargo-rpm \
    cargo-script \
    cargo-tree \
    cargo-vendor \
    cargo-watch \
    && rm -rf ~/.cargo/registry

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

# Install yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \ 
    && apt-get -y install yarn \
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
COPY --chown=developer:root vscode_settings.json ${HOME}/.config/Code/User/settings.json

# Install vendored crates
COPY --chown=developer:root ${CRATES_REGISTRY_PATH} ${HOME}/crates-registry
RUN echo "[source.crates-io]" >> .cargo/config \
    && echo "registry = 'https://github.com/rust-lang/crates.io-index'" >> .cargo/config \
    && echo "replace-with = 'local-registry'" >> .cargo/config \
    && echo "" >> .cargo/config \
    && echo "[source.local-registry]" >> .cargo/config \
    && echo "local-registry = '/home/developer/crates-registry'" >> .cargo/config

### Install vendored npm
COPY --chown=developer:root ${NPM_REGISTRY_PATH} ${HOME}/npm-registry
COPY --chown=developer:root yarn-vendor/yarn.lock ${HOME}/npm/yarn.lock
RUN yarn config set yarn-offline-mirror ${HOME}/npm-registry
RUN curl -o ${HOME}/npm/linux-x64-47_binding.node https://github.com/sass/node-sass/releases/download/v4.9.2/linux-x64-47_binding.node
RUN curl -L -o ${HOME}/npm/yarn-1.9.1.js https://github.com/yarnpkg/yarn/releases/download/v1.9.1/yarn-1.9.1.js
RUN chmod +x ${HOME}/npm/yarn-1.9.1.js
ENV SASS_BINARY_PATH $HOME/npm/linux-x64-47_binding.node

USER root

# Increase max file handles
RUN echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

WORKDIR ${HOME}/project

USER developer
