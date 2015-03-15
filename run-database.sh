#!/bin/bash

if [[ "$1" == "--initialize" ]]; then
  PID_PATH=/tmp/mongod.pid
  mongod --dbpath "$DATA_DIRECTORY" --fork --logpath /dev/null --pidfilepath "$PID_PATH"
  mongo db --eval "db.createUser({\"user\":\"${USERNAME:-aptible}\",\"pwd\":\"$PASSPHRASE\",\"roles\":[\"dbOwner\"]}, {\"w\":1,\"j\":true})"

  kill $(cat $PID_PATH)
  # wait for lock file to be released
  while [ -s "$DATA_DIRECTORY"/mongod.lock ]; do sleep 0.1; done
  exit
fi

/usr/bin/mongod --dbpath "$DATA_DIRECTORY" --auth
