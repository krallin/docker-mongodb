#!/bin/bash

. /usr/bin/utilities.sh

command="/usr/bin/mongod --dbpath "$DATA_DIRECTORY" --auth"
dump_directory="mongodump"
if [[ "$1" == "--initialize" ]]; then
  PID_PATH=/tmp/mongod.pid
  mongod --dbpath "$DATA_DIRECTORY" --fork --logpath /dev/null --pidfilepath "$PID_PATH"
  mongo db --eval "db.createUser({\"user\":\"${USERNAME:-aptible}\",\"pwd\":\"$PASSPHRASE\",\"roles\":[\"dbOwner\"]}, {\"w\":1,\"j\":true})"

  kill $(cat $PID_PATH)
  # wait for lock file to be released
  while [ -s "$DATA_DIRECTORY"/mongod.lock ]; do sleep 0.1; done

elif [[ "$1" == "--client" ]]; then
  [ -z "$2" ] && echo "docker run -it aptible/mongodb --client mongodb://..." && exit
  parse_url "$2"
  mongo --host="$host" --port="${port:-27017}" --username="$user" --password="$password" "$database"

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run aptible/mongodb --dump mongodb://... > dump.mongo" && exit
  # https://jira.mongodb.org/browse/SERVER-7860
  # Can't dump the whole database to stdout in a straightforward way. Instead,
  # dump to a directory and then tar the directory and print the tar to stdout.
  parse_url "$2"
  dump_command="mongodump --host="$host" --port="${port:-27017}" --username="$user" --password="$password" --db="$database" --out=/tmp/"$dump_directory""
  $dump_command > /dev/null && tar cf - -C /tmp/ "$dump_directory"

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/mongodb --restore mongodb://... < dump.mongo" && exit
  tar xf - -C /tmp/
  parse_url "$2"
  mongorestore --host="$host" --port="${port:-27017}" --username="$user" --password="$password" --db="$database" /tmp/"$dump_directory"/"$database"

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
  $command

else
  $command

fi
