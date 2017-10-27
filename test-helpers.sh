#!/bin/bash

function _wait_for_mongo_exec {
  local container="$1"
  local command="$2"

  local mongo_args=(
    "--ssl" "--sslAllowInvalidCertificates"
    "--quiet"
    "--eval" "$command"
  )

  for _ in $(seq 1 1000); do
    if docker exec -it "$container" mongo "${mongo_args[@]}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done

  return 1;
}

function wait_for_mongo {
  local container="$1"

  if _wait_for_mongo_exec "$container" "quit(0)"; then
    return 0
  fi

  echo "DB never came online"
  docker logs "$container"
  return 1
}

function wait_for_primary {
  local container="$1"

  if _wait_for_mongo_exec "$container" 'quit(db.isMaster()["ismaster"] ? 0 : 1)'; then
    return 0
  fi

  echo "DB never became primary"
  docker logs "$container"
  return 1
}

function quietly {
  local out err

  out="$(mktemp)"
  err="$(mktemp)"

  if "$@" > "$out" 2> "$err"; then
    rm "$out" "$err"
    return 0;
  else
    local status="$?"
    echo    "COMMAND FAILED:" "$@"
    echo    "STATUS:         ${status}"
    sed 's/^/STDOUT:         /' < "$out"
    sed 's/^/STDERR:         /' < "$err"
    return "$status"
  fi
}
