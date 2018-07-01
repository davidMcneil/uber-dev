#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create crates registry
cd ${DIR}/cargo-vendor
rm Cargo.lock
cargo generate-lockfile
cd ${DIR}
cargo local-registry --sync cargo-vendor/Cargo.lock --git crates-registry

# Create npm registry
yarn config set yarn-offline-mirror ${DIR}/npm-registry
cd ${DIR}/yarn-vendor
rm yarn.lock
yarn install
cd ${DIR}

docker build --tag=uber-dev --build-arg CRATES_REGISTRY_PATH=crates-registry .
