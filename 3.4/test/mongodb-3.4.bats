#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"

@test "It should install mongod 3.4.10" {
  run mongod --version
  [[ "$output" =~ "db version v3.4.10"  ]]
}

@test "It should install mongo tools to /usr/bin" {
  test -x /usr/bin/mongod
  test -x /usr/bin/mongo
  test -x /usr/bin/mongorestore
  test -x /usr/bin/mongodump
}

@test "It should reject non-SSL connections" {
  initialize_mongodb
  wait_for_mongodb
  run run-database.sh --client "$DATABASE_URL_NO_SSL" --eval "$QUERY"
  [ "$status" -ne "0" ]
}
