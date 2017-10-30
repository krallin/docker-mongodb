#!/bin/bash
set -o errexit
set -o nounset

IMG="$REGISTRY/$REPOSITORY:$TAG"

echo "Unit Tests..."
docker run -it --rm --entrypoint "bash" "$IMG" \
  -c "apt-install curl >/dev/null && bats /tmp/test"

echo
echo "Restart Test..."
./test-restart.sh "$IMG"

echo
echo "Replication Test..."
./test-replication.sh "$IMG"

echo
echo "Initialize Backup Test..."
./test-initialize-backup.sh "$IMG"

echo "#############"
echo "# Tests OK! #"
echo "#############"
