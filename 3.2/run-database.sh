#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /usr/bin/utilities.sh

# Empty defaults to support [[ -n ... ]] checks with -o nounset.
: ${SSL_CERTIFICATE:=""}
: ${SSL_KEY:=""}


function startMongod() {
  SUBJ="/C=US/ST=New York/L=New York/O=Example/CN=mongodb.example.com"
  if [ ! -f "$SSL_DIRECTORY"/mongodb.crt ] && [ ! -f "$SSL_DIRECTORY"/mongodb.key ]; then
    OPTS="req -nodes -new -x509 -sha256"
    openssl $OPTS -subj "$SUBJ" -keyout "$SSL_DIRECTORY"/mongodb.key -out "$SSL_DIRECTORY"/mongodb.crt 2> /dev/null
  fi

  cat "$SSL_DIRECTORY/mongodb.key" "$SSL_DIRECTORY/mongodb.crt" > "$SSL_DIRECTORY/mongodb.pem"
  exec mongod --dbpath "$DATA_DIRECTORY" --auth --sslMode "$MONGO_SSL_MODE" --sslPEMKeyFile "$SSL_DIRECTORY/mongodb.pem"
}

dump_directory="mongodump"


if [[ "$#" -eq 0 ]]; then
  startMongod

elif [[ "$1" == "--initialize" ]]; then
  mkdir -p "$SSL_DIRECTORY"

  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "$SSL_CERTIFICATE" > "$SSL_DIRECTORY"/mongodb.crt
    echo "$SSL_KEY" > "$SSL_DIRECTORY"/mongodb.key
  fi

  PID_PATH=/tmp/mongod.pid
  mongod --dbpath "$DATA_DIRECTORY" --fork --logpath /dev/null --pidfilepath "$PID_PATH"
  mongo db --eval "db.createUser({\"user\":\"${USERNAME:-aptible}\",\"pwd\":\"$PASSPHRASE\",\"roles\":[\"dbOwner\"]}, {\"w\":1,\"j\":true})"

  kill $(cat $PID_PATH)
  # wait for lock file to be released
  while [ -s "$DATA_DIRECTORY"/mongod.lock ]; do sleep 0.1; done

elif [[ "$1" == "--client" ]]; then
  if [[ "$#" -lt 2 ]]; then
    echo "docker run -it aptible/mongodb --client mongodb://... [...]"
    exit 1
  fi
  parse_url "$2"
  shift
  shift
  exec mongo $mongo_options "$database" "$@"

elif [[ "$1" == "--dump" ]]; then
  if [[ "$#" -ne 2 ]]; then
    echo "docker run aptible/mongodb --dump mongodb://... > dump.mongo"
    exit 1
  fi
  # https://jira.mongodb.org/browse/SERVER-7860
  # Can't dump the whole database to stdout in a straightforward way. Instead,
  # dump to a directory and then tar the directory and print the tar to stdout.
  parse_url "$2"
  mongodump $mongo_options --db="$database" --out="/tmp/${dump_directory}" > /dev/null && tar cf - -C /tmp/ "$dump_directory"

elif [[ "$1" == "--restore" ]]; then
  if [[ "$#" -ne 2 ]]; then
    echo "docker run -i aptible/mongodb --restore mongodb://... < dump.mongo"
    exit 1
  fi
  tar xf - -C /tmp/
  parse_url "$2"
  mongorestore $mongo_options --db="$database" "/tmp/${dump_directory}/${database}"

elif [[ "$1" == "--readonly" ]]; then
  # MongoDB only supports read-only mode on a per-user basis. To make that
  # happen, it should be possible to mimic the `--initialize` sequence to set
  # the user's `roles` to [ "read" ].
  #
  # This presents some difficulties:
  # * no $USERNAME is being passed.
  # * normal invocations of the server would need to ensure the user wasn't in
  #     read-only mode.
  # * temporarily starting the daemon to make the change is ugly.
  #
  # With all of that said, leaving off read-only mode for now.
  echo "This image does not support read-only mode. Starting database normally."
  startMongod
else
  echo "Unrecognized command: $1"
  exit 1

fi
