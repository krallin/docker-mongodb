#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# This script expects to be passed:
# $1: primary URL.
# $2: secondary URL.

# It'll update the replication configuration on the primary
# by granting votes = 1 and priority = 1 to the secondary
# once the secondary is up.

# This is a best effort. If the primary happens to have changed
# by now, this will fail.

PRIMARY_URL="$1"
SECONDARY_URL="$2"

# TODO - Path and name of the script
function find_secondary_name () {
  run-database.sh --client "$SECONDARY_URL" "/mongo-scripts/secondary-get-name.js"  | grep "SERVER NAME" | sed "s/SERVER NAME://g"
}

until find_secondary_name ; do
  sleep 1
  echo "Waiting for secondary to come online"
done

SECONDARY_NAME="$(find_secondary_name )"

run-database.sh --client "$PRIMARY_URL" --eval "var secondary_name='$SECONDARY_NAME'" "/mongo-scripts/primary-enable-secondary.js"
echo "Reconfigured primary!"
