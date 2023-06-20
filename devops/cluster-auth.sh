#!/usr/bin/env bash

function remove_env {
  echo "---> Remove temporary env file"
  rm -rf ${ENV_FILE}
  echo "* ${ENV_FILE} removed"
}

set -e

trap remove_env 0 1 2 3 6

echo "Checking dependencies"
dependencies=( "jet" "aws" )

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

ENV_FILE=${ENV_FILE:-".keys/.devops.prod.env"}

if [[ -f ${ENV_FILE} ]]; then
  echo "* Sourcing env file: ${ENV_FILE}"
  source ${ENV_FILE}
else
  mkdir -p .keys/
  jet decrypt devops/secrets.encrypted ${ENV_FILE}
  source ${ENV_FILE}
fi

echo -e "* Env variables sourced from ${ENV_FILE}\n"

aws_credentials_file=~/.aws/credentials
has_set_aws_profile=$(cat ${aws_credentials_file} | { grep fp-devops  || :; })

if [[ ! ${has_set_aws_profile} ]]; then
  echo ${AWS_AUTH_CREDENTIALS} | base64 --decode >> ${aws_credentials_file}
fi

auth_command="aws --profile fp-devops eks update-kubeconfig"
auth_command+=" --region ${EKS_ZONE}"
auth_command+=" --name ${EKS_CLUSTER}"

echo "> ${auth_command}"
${auth_command}

echo -e "\n"
echo -e "* Cluster authentication: success\n"