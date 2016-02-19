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

@test "It should return valid JSON for --discover and --connection-url" {
  run-database.sh --discover | python -c 'import sys, json; json.load(sys.stdin)'
  CLUSTER_KEY=test PASSPHRASE=test run-database.sh --connection-url | python -c 'import sys, json; json.load(sys.stdin)'
}

@test "It should return a valid connection URL for --connection-url" {
  initialize_mongodb
  wait_for_mongodb

  USERNAME="$DATABASE_USER" PASSPHRASE="$DATABASE_PASSWORD" DATABASE=db run run-database.sh --connection-url
  [ "$status" -eq "0" ]
  URL="$(echo "$output" | python -c "import sys, json; print json.load(sys.stdin)['url']")"
  URL="${URL}&x-sslVerify=false"  # Certs are invalid in test, but --connection-url doesn't know that.
  run-database.sh --client "$URL" --eval 'quit(0);'
}

@test "It should allow --initialize without CLUSTER_KEY" {
  USERNAME="$DATABASE_USER" PASSPHRASE="$DATABASE_PASSWORD" DATABASE=db run run-database.sh --initialize
  [ "$status" -eq 0 ]
  echo "$output" | grep "WARNING: CLUSTER_KEY is unset"
}

@test "It should not allow --initialize-from without CLUSTER_KEY" {
  USERNAME="$DATABASE_USER" PASSPHRASE="$DATABASE_PASSWORD" DATABASE=db run run-database.sh --initialize-from "mongodb://dummy:dummy@dummy@dummy/dummy"
  [ "$status" -eq 1 ]
  echo "$output" | grep "CLUSTER_KEY must be set"
}
