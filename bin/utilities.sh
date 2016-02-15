#!/bin/bash

parse_url() {
  mongo_params="$(parse_mongo_url.py "$1")"
  eval "$mongo_params"
}

randint_8() {
  openssl rand 1 | od -DAn | tr -d '[:space:]'
}
