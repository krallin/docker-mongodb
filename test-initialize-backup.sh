#!/bin/bash
set -o errexit
set -o nounset

. ./test-helpers.sh

IMG="$1"

MONGO_CONTAINER="mongo"
DATA_CONTAINER="${MONGO_CONTAINER}-data"

function cleanup {
  echo "Cleaning up"
  docker rm -f "$MONGO_CONTAINER" "$DATA_CONTAINER" >/dev/null 2>&1 || true
}

trap cleanup EXIT
quietly cleanup

echo "Creating data container"
docker create --name "$DATA_CONTAINER" "$IMG"

echo "Initialize DB"
quietly docker run -it --rm \
  -e USERNAME=user -e PASSPHRASE=pass -e DATABASE=db \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_27017=27017 \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" --initialize

echo "Start DB"
quietly docker run -d --name="$MONGO_CONTAINER" \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_27017=27017 \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" 

echo "Wait for DB to come online"
wait_for_mongo "$MONGO_CONTAINER"

echo "Wait for DB to transition to PRIMARY"
wait_for_primary "$MONGO_CONTAINER"

echo "Insert datae preserved"
MONGO_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$MONGO_CONTAINER")"
MONGO_URL="mongodb://user:pass@${MONGO_IP}:27017/db?ssl=true&x-sslVerify=false"
docker run --rm "$IMG" --client "$MONGO_URL" \
  --quiet --eval "db.test.insert({ 'FOO': 'CANARY' }, { w: 1, j: true});"

echo "Stop DB"
docker stop "$MONGO_CONTAINER"
docker rm "$MONGO_CONTAINER"

echo "Initialize Restore"
quietly docker run -it --rm \
  -e USERNAME=user -e PASSPHRASE=pass -e DATABASE=db \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_27017=27017 \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" --initialize-backup 

echo "Start DB after restore"
quietly docker run -d --name="$MONGO_CONTAINER" \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_27017=27017 \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG"

echo "Wait for DB to come online after restore"
wait_for_mongo "$MONGO_CONTAINER"

echo "Wait for DB to transition to PRIMARY after restore"
wait_for_primary "$MONGO_CONTAINER"

echo "Check data is preserved"
MONGO_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$MONGO_CONTAINER")"
MONGO_URL="mongodb://user:pass@${MONGO_IP}:27017/db?ssl=true&x-sslVerify=false"
docker run --rm "$IMG" --client "$MONGO_URL" \
  --quiet --eval "printjson(db.test.find()[0])"  | grep CANARY

echo "TEST OK"
