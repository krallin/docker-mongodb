#!/bin/bash

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export OLD_SSL_DIRECTORY="$SSL_DIRECTORY"
  export DATA_DIRECTORY=/tmp/datadir
  export SSL_DIRECTORY=/tmp/ssldir
  export QUERY="printjson(db.getCollectionNames())"
  export DATABASE_USER="aptible"
  export DATABASE_PASSWORD="password12345"
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
  unset DATABASE_URL
  PID=$(pgrep mongod) || return 0
  run pkill mongod
  while [ -n "$PID" ] && [ -e "/proc/${PID}" ]; do sleep 0.1; done
}

initialize_mongodb() {
  USERNAME="$DATABASE_USER" PASSPHRASE="$DATABASE_PASSWORD" run-database.sh --initialize
}

wait_for_mongodb() {
  run-database.sh > "$BATS_TEST_DIRNAME/mongodb.log" &
  timeout 4 sh -c "while  ! grep 'waiting for connections' '$BATS_TEST_DIRNAME/mongodb.log' ; do sleep 0.1; done"
}

