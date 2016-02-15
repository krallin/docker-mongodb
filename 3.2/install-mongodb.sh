#!/bin/bash
set -o errexit
set -o nounset

apt-install \
  "mongodb-org=${MONGO_VERSION}" \
  "mongodb-org-server=${MONGO_VERSION}" \
  "mongodb-org-shell=${MONGO_VERSION}" \
  "mongodb-org-mongos=${MONGO_VERSION}"
