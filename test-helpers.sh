#!/bin/bash

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
