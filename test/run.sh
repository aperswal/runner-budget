#!/usr/bin/env bash
# Runs the bats suite and shellcheck in their official images, so nothing needs installing.
set -euo pipefail
cd "$(dirname "$0")/.."
docker run --rm -v "$PWD:/code" --entrypoint sh bats/bats:latest \
  -c 'apk add --no-cache jq >/dev/null && bats /code/test'
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable -x runner-budget test/run.sh
echo "shellcheck: clean"
