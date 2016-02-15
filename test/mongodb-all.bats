#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"


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

  run-database.sh --client "$DATABASE_URL" --eval "db.test.insert({\"$test_data\": null})"
  run-database.sh --dump "$DATABASE_URL" > "$BATS_TEST_DIRNAME/backup"
  run-database.sh --client "$DATABASE_URL" --eval "db.dropDatabase()"
  run-database.sh --restore "$DATABASE_URL" < "$BATS_TEST_DIRNAME/backup"

  run run-database.sh --client "$DATABASE_URL" --eval "printjson(db.test.find()[0])"
  [ "$status" -eq "0" ]
  [[ "$output" =~ "$test_data" ]]
}

@test "It should pass parse_mongo_url.py unit tests" {
  python -B -m doctest /usr/bin/parse_mongo_url.py
}

@test "--discover and --connection-url should return valid JSON" {
  run-database.sh --discover | python -c 'import sys, json; json.load(sys.stdin)'
  CLUSTER_KEY=test PASSPHRASE=test run-database.sh --connection-url | python -c 'import sys, json; json.load(sys.stdin)'
}

@test "--connection-url should return a valid connection URL" {
  # TODO
}
