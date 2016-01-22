#!/bin/bash

parse_url() {
  eval "$(parse_mongo_url.py "$1")"
}
