#!/bin/bash

set -e

function cleanup {
  echo "---> Clean up tmp files"
  rm -rf ${ENV_FILE}
  echo "* Cleaned"
}

echo ""
echo "---> Check depedencies"
echo ""

dependencies=( "jet" "git" "docker" "aws" "kubectl" )

for dependency in ${dependencies[@]}; do
  printf "* ${dependency}: "
  if [[ $(command -v ${dependency}) ]]; then
    echo "✓"
  else
    echo "✗"
    echo "${dependency} must be installed"
    exit 1
  fi
done

echo ""
echo "---> Decrypt and set required env variables"
echo ""

while getopts b: flag;do
  case "${flag}" in
    b) GIT_BRANCH=${OPTARG} ;;
  esac
done

ENV_FILE=${ENV_FILE:-.keys/.fp.tmp.env}

if [[ -f ${ENV_FILE} ]]; then
  echo "* Sourcing env file: ${ENV_FILE}"
  source ${ENV_FILE}
else
  mkdir -p .keys/
  jet decrypt devops/secrets.encrypted ${ENV_FILE}
  source ${ENV_FILE}
fi

echo "* Env variables sourced from ${ENV_FILE}"

trap cleanup 0 1 2 3 6

echo ""
echo "---> Check environment"
echo ""

vars=( \
  "GIT_BRANCH" \
)


for var in ${vars[@]}; do
  printf "* ${var}: "

  if [[ -z ${!var} ]]; then
    echo "✗ (must be set)"
    exit 1
  elif [[ ${var} == "PRIVATE_SSH_KEY" ]]; then
		echo "✓ ([hidden value])"
  else
    echo "✓ (${!var})"
  fi
done

# aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 108338497096.dkr.ecr.us-east-1.amazonaws.com
# ./devops/build.sh
# docker tag fp-graphhopper:latest 108338497096.dkr.ecr.us-east-1.amazonaws.com/fp-graphhopper:latest
# docker push 108338497096.dkr.ecr.us-east-1.amazonaws.com/fp-graphhopper:latest