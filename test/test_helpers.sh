#!/bin/bash

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export OLD_SSL_DIRECTORY="$SSL_DIRECTORY"
  export DATA_DIRECTORY=/tmp/datadir
  export SSL_DIRECTORY=/tmp/ssldir
  export QUERY="printjson(db.getCollectionNames())"
  export DATABASE_USER="aptible"
  export DATABASE_PASSWORD="password12345"
  export DATABASE_CLUSTER_KEY="key1234"
  export DATABASE_URL_NO_SSL="mongodb://$DATABASE_USER:$DATABASE_PASSWORD@localhost/db"
  export DATABASE_URL="$DATABASE_URL_NO_SSL?ssl=true&x-sslVerify=false"
  rm -rf "$DATA_DIRECTORY"
  rm -rf "$SSL_DIRECTORY"
  mkdir -p "$DATA_DIRECTORY"
  mkdir -p "$SSL_DIRECTORY"
}

teardown() {
  export DATA_DIRECTORY="$OLD_DATA_DIRECTORY"
  export SSL_DIRECTORY="$OLD_SSL_DIRECTORY"
  unset OLD_DATA_DIRECTORY
  unset OLD_SSL_DIRECTORY
  unset QUERY
  unset DATABASE_USER
  unset DATABASE_PASSWORD
  unset DATABASE_CLUSTER_KEY
  unset DATABASE_URL
  PID=$(pgrep mongod) || return 0
  run pkill mongod
  while [ -n "$PID" ] && [ -e "/proc/${PID}" ]; do sleep 0.1; done
}

initialize_mongodb() {
  USERNAME="$DATABASE_USER" CLUSTER_KEY="$DATABASE_CLUSTER_KEY" PASSPHRASE="$DATABASE_PASSWORD" DATABASE=db run-database.sh --initialize
}

wait_for_mongodb() {
  run-database.sh > "$BATS_TEST_DIRNAME/mongodb.log" &

  # Transition to PRIMARY shows in the log before the node is actually able to accept writes,
  # so we sleep a little bit after seeing it.
  timeout 4 sh -c "while  ! grep 'PRIMARY' '$BATS_TEST_DIRNAME/mongodb.log' ; do sleep 0.1; done"
  sleep 2
}

