#!/bin/bash

set -e

echo ""
echo "---> Reading parameters"
echo ""

while getopts i:c: flag;do
  case "${flag}" in
    i) IMAGE_NAME=${OPTARG} ;;
    c) COMMIT_ID=${OPTARG} ;;
  esac
done

echo ""
echo "---> Check environment"
echo ""

vars=( \
  "IMAGE_NAME" \
  "COMMIT_ID" \
)


for var in ${vars[@]}; do
  printf "* ${var}: "

  if [[ -z ${!var} ]]; then
    echo "✗ (must be set)"
    exit 1
  else
    echo "✓ (${!var})"
  fi
done



if [ ! -d graphhopper ]; then
  echo "Cloning graphhopper"
  git clone https://github.com/graphhopper/graphhopper.git
else
  echo "Pulling graphhopper"
  (cd graphhopper; git checkout master; git pull)
fi

echo "Building docker image ${IMAGE_NAME}"
docker build \
  --build-arg COMMIT_HASH=${COMMIT_ID} \
  -t "${IMAGE_NAME}" .

echo "* Image built: ${IMAGE_NAME}"