#!/usr/bin/env bats

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export OLD_SSL_DIRECTORY="$SSL_DIRECTORY"
  export DATA_DIRECTORY=/tmp/datadir
  export SSL_DIRECTORY=/tmp/ssldir
  export QUERY="printjson(db.getCollectionNames())"
  export DATABASE_USER="aptible"
  export DATABASE_PASSWORD="password12345"
  export DATABASE_URL_NO_SSL="mongodb://$DATABASE_USER:$DATABASE_PASSWORD@localhost/db"
  export DATABASE_URL="$DATABASE_URL_NO_SSL?uri.ssl=true&uri.x-sslVerify=false"
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
  while [ -n "$PID" ] && [ -e /proc/$PID ]; do sleep 0.1; done
}

initialize_mongodb() {
  USERNAME="$DATABASE_USER" PASSPHRASE="$DATABASE_PASSWORD" run-database.sh --initialize
}

wait_for_mongodb() {
  run-database.sh > $BATS_TEST_DIRNAME/mongodb.log &
  while  ! grep "waiting for connections" $BATS_TEST_DIRNAME/mongodb.log ; do sleep 0.1; done
}

@test "It should install mongod" {
  run mongod --version
  [[ "$output" =~ "db version v2.6.11"  ]]
}

@test "It should install mongo tools to /usr/local/bin" {
  test -x /usr/local/bin/mongod
  test -x /usr/local/bin/mongo
  test -x /usr/local/bin/mongorestore
  test -x /usr/local/bin/mongodump
}

@test "It should accept non-SSL connections" {
  initialize_mongodb
  wait_for_mongodb
  run run-database.sh --client "$DATABASE_URL_NO_SSL" --eval "$QUERY"
  [ "$status" -eq "0" ]
  [[ "$output" =~ "[ ]" ]]
}

@test "It should accept SSL connections" {
  initialize_mongodb
  wait_for_mongodb
  run run-database.sh --client "$DATABASE_URL" --eval "$QUERY"
  [ "$status" -eq "0" ]
  [[ "$output" =~ "[ ]" ]]
}

@test "It should successfully backup and restore" {
  test_data="APTIBLE_TEST"

  initialize_mongodb
  wait_for_mongodb

  run run-database.sh --client "$DATABASE_URL" --eval "db.test.insert({\"$test_data\": null})"
  run run-database.sh --dump "$DATABASE_URL" > "$BATS_TEST_DIRNAME/backup"
  run run-database.sh --client "$DATABASE_URL" --eval "db.dropDatabase()"
  run run-database.sh --restore "$DATABASE_URL" < "$BATS_TEST_DIRNAME/backup"

  run run-database.sh --client "$DATABASE_URL" --eval "printjson(db.test.find()[0])"
  [ "$status" -eq "0" ]
  [[ "$output" =~ "$test_data" ]]
}

@test "It should pass parse_mongo_url.py unit tests" {
  python -B -m doctest /usr/bin/parse_mongo_url.py
}
