#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"

@test "It should install mongod 2.6" {
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
