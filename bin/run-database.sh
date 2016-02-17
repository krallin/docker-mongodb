#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


# shellcheck disable=SC1091
. /usr/bin/utilities.sh


DEFAULT_USER="aptible"
DEFAULT_HOST="$(hostname)"
DEFAULT_PORT="27017"
DEFAULT_DATABASE="db"


REPL_SET_NAME_FILE="${DATA_DIRECTORY}/.aptible-replica-set-name"
CLUSTER_KEY_FILE="${DATA_DIRECTORY}/.aptible-keyfile"
MEMBER_ID_FILE="${DATA_DIRECTORY}/.aptible-member-id"
PRE_START_FILE="${DATA_DIRECTORY}/.aptible-on-start"


function mongo_init_debug () {
  # shellcheck disable=2086
  if [[ -n "${ENABLE_DEBUG:-""}" ]]; then
    set -o xtrace
  fi
}


function mongo_environment_minimal () {
  # shellcheck disable=2086
  {
    : ${SSL_CERTIFICATE:=""}
    : ${SSL_KEY:=""}
    : ${PORT:="$DEFAULT_PORT"}
  }
}


function mongo_environment_full () {
  mongo_environment_minimal

  # Database defaults

  # shellcheck disable=2086
  {
    : ${USERNAME:="$DEFAULT_USER"}
    : ${DATABASE:="$DEFAULT_DATABASE"}
  }

  # Clustering defaults

  EXPOSE_PORT_PTR="EXPOSE_PORT_${PORT}"
  # shellcheck disable=2086
  {
    : ${EXPOSE_HOST:="$DEFAULT_HOST"}
  }

  # Set !EXPOSE_PORT_PTR to a default value of PORT if unset. We can't
  # use ${!EXPOSE_PORT_PTR:=""} because it doesn't work for indirect
  # references.
  local canary="VAR_NOT_SET"
  if [[ "${!EXPOSE_PORT_PTR:-"$canary"}" = "$canary" ]]; then
    eval "${EXPOSE_PORT_PTR}=${PORT}"
  fi

  # Check that variables that do not accept defaults are properly set
  # in the environment.
  # shellcheck disable=2086
  {
    : ${PASSPHRASE:?"PASSPHRASE must be set in the environment"}
    : ${CLUSTER_KEY:?"CLUSTER_KEY must be set in the environment"}
  }
}



function mongo_initialize_certs () {
  mkdir -p "$SSL_DIRECTORY"

  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "$SSL_CERTIFICATE" > "$SSL_DIRECTORY"/mongodb.crt
    echo "$SSL_KEY" > "$SSL_DIRECTORY"/mongodb.key
  else
    echo "No certs found - autogenerating"
    SUBJ="/C=US/ST=New York/L=New York/O=Example/CN=mongodb.example.com"
    OPTS="req -nodes -new -x509 -sha256"
    # shellcheck disable=2086
    openssl $OPTS -subj "$SUBJ" -keyout "$SSL_DIRECTORY"/mongodb.key -out "$SSL_DIRECTORY"/mongodb.crt 2> /dev/null
  fi

  cat "$SSL_DIRECTORY/mongodb.key" "$SSL_DIRECTORY/mongodb.crt" > "$SSL_DIRECTORY/mongodb.pem"
}


function mongo_exec_and_extract () {
  # Unfortunately, MongoDB insists on logging SSL verification errors to stdout, which means
  # we can't simply capture the output of our script. Instead, we need our script to prefix
  # the data we're interested in, and then check that prefix.
  local script="$1"
  shift
  local prefix="MONGO_EXTRACT_PREFIX:"
  local mongo_out

  # Execute the command (or script), but send in our prefix so the command / script
  # knows what to prefix its output with so we can find it.
  if ! mongo_out="$(mongo "$@" --eval "var extract_prefix = '$prefix';" "$script")"; then
    # Oops, something failed. Log the output to stderr and exit.
    echo -n "$mongo_out" > 2
    false
  fi

  # Then do some grep & sed to extract what we actually wanted...
  if ! echo "$mongo_out" | grep "$prefix" | sed "s/${prefix}//"; then
    # Oops, the output didn't have the data we were interested in. Here again,
    # log the output and exit.
    echo -n "$mongo_out" > 2
    false
  fi
}


function startMongod () {
  # Run the "PRE_START_FILE" if provided
  if [ -f "$PRE_START_FILE" ]; then
    "$PRE_START_FILE"
  fi

  # Standalone configuration
  local mongo_options=(
    "--dbpath" "$DATA_DIRECTORY"
    "--port" "$PORT"
    "--sslMode" "$MONGO_SSL_MODE"
    "--sslPEMKeyFile" "$SSL_DIRECTORY/mongodb.pem"
    "--auth"
  )

  if [ -f "$REPL_SET_NAME_FILE" ]; then
    # We have a replica set name file: expand the configuration
    # to start as a replica set member.
    mongo_options+=(
      "--replSet" "$(cat "$REPL_SET_NAME_FILE")"
      "--keyFile" "$CLUSTER_KEY_FILE"
    )
  fi

  exec mongod "${mongo_options[@]}"
}

dump_directory="mongodump"

# If requested, enable debug before anything.
mongo_init_debug

if [[ "$#" -eq 0 ]]; then
  mongo_environment_minimal
  mongo_initialize_certs
  startMongod

elif [[ "$1" == "--initialize" ]]; then
  mongo_environment_full

  # Auto-generate replica set name. We randomize this to ensure multiple MongoDB servers have a different
  # replica set name (as recommended by MongoDB).
  REPL_SET_NAME="rs$(pwgen -s 12)"
  echo "$REPL_SET_NAME" > "$REPL_SET_NAME_FILE"

  # Use the connection password for intra-cluster authentication
  echo "$CLUSTER_KEY" > "$CLUSTER_KEY_FILE"
  chmod 600 "$CLUSTER_KEY_FILE"

  # Initialize MongoDB
  PID_PATH=/tmp/mongod.pid
  LOG_PATH=/tmp/mongod.log
  trap 'cat "$LOG_PATH"; rm "$LOG_PATH"' EXIT

  # Start MongoDB. We're only going to connect locally here; we don't enable auth or SSL.
  mongod --dbpath "$DATA_DIRECTORY" --port "$PORT" --fork --logpath "$LOG_PATH" --pidfilepath "$PID_PATH" --replSet "$REPL_SET_NAME"

  mongo_options="--port $PORT"

  # Initialize replica set configuration using the host we were provided. Since we're using --initialize,
  # we'll force the host _id to 0 (we're guaranteed that --initialize only runs once per replica set).
  # shellcheck disable=2086
  mongo $mongo_options --eval "var replica_set_name = '${REPL_SET_NAME}', primary_member_id = 0, primary_host = '${EXPOSE_HOST}:${!EXPOSE_PORT_PTR}';" "/mongo-scripts/primary-initiate-replica-set.js"

  # Wait until MongoDB node becomes primary
  # shellcheck disable=2086
  until mongo $mongo_options --quiet --eval 'quit(db.isMaster()["ismaster"] ? 0 : 1)'; do
    echo "Waiting until new MongoDB instance becomes primary"
    sleep 2
  done

  # Create users using the connection URL that was provided
  # shellcheck disable=2086
  mongo $mongo_options --eval "var user_db = '${DATABASE}', user_name = '${USERNAME}', user_passphrase = '${PASSPHRASE}';" "/mongo-scripts/primary-add-user-permissions.js"

  # Terminate MongoDB and wait for it to exit
  kill "$(cat "$PID_PATH")"
  while [ -s "$DATA_DIRECTORY"/mongod.lock ]; do sleep 0.1; done

elif [[ "$1" == "--initialize-from" ]]; then
  if [[ "$#" -lt 2 ]]; then
    echo "docker run -it aptible/mongodb --initialize-from mongodb://..."
    exit 1
  fi

  # We'll need users, passwords, certificates, cluster key, etc. here. They should all come from the environment.
  mongo_environment_full

  # We have no guarantee that whatever is in FROM_URL is actually the primary, so we have to actually query the primary.
  # Obviously, this is racy. If there are changes happening on the cluster while we work, we might end up sending cluster
  # commands to the wrong node. There isn't much we can do about it besides not provisioning multiple MongoDB nodes at the
  # same time or during an outage.
  FROM_URL="$2"
  parse_url "$FROM_URL"

  # Now, get the *actual* primary from that URL
  # shellcheck disable=2154 disable=2086
  PRIMARY_HOST_PORT="$(mongo_exec_and_extract "/mongo-scripts/secondary-find-primary.js" $mongo_options admin)"

  # Reconstruct primary URL using the credentials we were provided.
  # TODO - Consider using system and keyfile creds?
  # shellcheck disable=2154
  PRIMARY_URL="mongodb://${username}:${password}@${PRIMARY_HOST_PORT}/admin?ssl=true&x-sslVerify=false"

  parse_url "$PRIMARY_URL"
  # shellcheck disable=2154
  {
    PRIMARY_OPTIONS="$mongo_options"
  }

  # Create key file using cluster key that was provided in the environment.
  echo "$CLUSTER_KEY" > "$CLUSTER_KEY_FILE"
  chmod 600 "$CLUSTER_KEY_FILE"

  # Get the replica set name from the primary, and store it for future restarts. Unfortunately, MongoDB logs
  # things like SSL errors to stdout, so we can't really just get the output of db.runCommand and expect that
  # to match out replica set name.
  # shellcheck disable=2154 disable=2086
  REPL_SET_NAME="$(mongo_exec_and_extract "/mongo-scripts/secondary-get-replica-set-name.js" $PRIMARY_OPTIONS admin)"
  echo "$REPL_SET_NAME" > "$REPL_SET_NAME_FILE"

  # Autogenerate a random member ID. This makes it easier for us to update our votes and priority later on,
  # and also happens to be required for MongoDB 2.6. Unfortunately, the member ID needs to be a rather small
  # number. We pick one at random, but on the off chance that we pick the same one twice, the commands below
  # will fail (and exit with an error), and the `--initialize-from` operation needs to be restarted.
  MEMBER_ID="$(randint_8)"
  # shellcheck disable=2086
  until mongo $PRIMARY_OPTIONS admin --eval "var member_id = ${MEMBER_ID};" "/mongo-scripts/primary-test-member-id.js"; do
    echo "Member ID ${MEMBER_ID} is in use - trying another one"
    MEMBER_ID="$(randint_8)"
  done

  echo "$MEMBER_ID" > "$MEMBER_ID_FILE"

  # Start our local MongoDB to kickstart replication. Since we have SSL either set to requireSSL or preferSSL,
  # the slave needs to have SSL enabled when it comes up. This operation might take a while (MongoDB will rsync data
  # over from the slave), so we enable auth to ensure there is no unauthorized access to the replica as it comes up
  # (which means we won't be able to log in until the users DB is replicated).
  PID_PATH=/tmp/mongod.pid
  LOG_PATH=/tmp/mongod.log
  trap 'cat "$LOG_PATH"; rm "$LOG_PATH"' EXIT

  mongo_initialize_certs
  mongod --dbpath "$DATA_DIRECTORY" --port "$PORT" --fork --logpath "$LOG_PATH" --pidfilepath "$PID_PATH" --replSet "$REPL_SET_NAME" --keyFile "$CLUSTER_KEY_FILE" --sslMode "$MONGO_SSL_MODE" --sslPEMKeyFile "$SSL_DIRECTORY/mongodb.pem" --auth

  # Initate replication, from the primary Point it to the new replica we just launched.
  # shellcheck disable=2086
  mongo $PRIMARY_OPTIONS admin --quiet --eval "var secondary_member_id = $MEMBER_ID, secondary_host = '${EXPOSE_HOST}:${!EXPOSE_PORT_PTR}';" "/mongo-scripts/primary-add-nonvoting-secondary.js"

  # Determine the URL this replica will acquire (and check its validity by parsing it - we'll use it later anyway)
  SECONDARY_URL="mongodb://${USERNAME}:${PASSPHRASE}@${EXPOSE_HOST}:${!EXPOSE_PORT_PTR}/admin?ssl=true&x-sslVerify=false"
  parse_url "$SECONDARY_URL"

  # Let's tell our Mongo that it should update itself to become a voting member when it comes back up
  cat > "$PRE_START_FILE" <<EOM
#!/bin/bash
/mongo-scripts/reconfig.sh "$PRIMARY_URL" "$SECONDARY_URL" &
EOM
  chmod +x "$PRE_START_FILE"

  # Wait until we actually join the cluster.
  # shellcheck disable=2154 disable=2086
  until mongo $mongo_options "$database" --quiet --eval 'quit((db.isMaster()["ismaster"] || db.isMaster()["secondary"]) ? 0 : 1)'; do
    echo "Waiting until new MongoDB instance becomes primary or secondary"
    sleep 2
  done

  # Initialization is done, terminate MongoDB
  echo "Initial sync complete. Terminating MongoDB"
  kill "$(cat "$PID_PATH")"
  while [ -s "$DATA_DIRECTORY"/mongod.lock ]; do sleep 0.1; done

elif [[ "$1" == "--discover" ]]; then
  mongo_environment_minimal

  cat <<EOM
{
  "exposed_ports": [
    ${PORT}
  ],
  "suggested_configuration": {
    "CLUSTER_KEY": "$(pwgen -s 64)",
    "PASSPHRASE": "$(pwgen -s 32)"
  }
}
EOM

elif [[ "$1" == "--connection-url" ]]; then
  mongo_environment_full
  cat <<EOM
{
  "url": "mongodb://${USERNAME}:${PASSPHRASE}@${EXPOSE_HOST}:${!EXPOSE_PORT_PTR}/${DATABASE}?ssl=true"
}
EOM

elif [[ "$1" == "--client" ]]; then
  if [[ "$#" -lt 2 ]]; then
    echo "docker run -it aptible/mongodb --client mongodb://... [...]"
    exit 1
  fi
  parse_url "$2"
  shift
  shift
  # shellcheck disable=2154 disable=2086
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

  # shellcheck disable=2154 disable=2086
  mongodump $mongo_options --db="$database" --out="/tmp/${dump_directory}" > /dev/null && tar cf - -C /tmp/ "$dump_directory"

elif [[ "$1" == "--restore" ]]; then
  if [[ "$#" -ne 2 ]]; then
    echo "docker run -i aptible/mongodb --restore mongodb://... < dump.mongo"
    exit 1
  fi
  tar xf - -C /tmp/
  parse_url "$2"
  # shellcheck disable=2154 disable=2086
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
  mongo_environment_minimal
  mongo_initialize_certs
  startMongod
else
  echo "Unrecognized command: $1"
  exit 1
fi
