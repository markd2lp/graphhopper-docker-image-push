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
CONFIRM_DEPLOY=${CONFIRM_DEPLOY:-yes}

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


git checkout ${GIT_BRANCH} > /dev/null
echo "* Current branch: ${GIT_BRANCH}"

if [[ $(git ls-remote origin ${GIT_BRANCH}) ]]; then
  git pull origin ${GIT_BRANCH}
fi

commit_id=${CI_COMMIT_ID:-$(git rev-parse HEAD)}
echo "* Commit ID (HEAD): ${commit_id}"

repository_name=prod-fp-graphhopper
image_exists= ./devops/find-ecr-image.sh ${repository_name} ${commit_id}

if [[ ${image_exists} == "no" ]];then

  echo ""
  echo "+--------------------------------------------------------------------+"
  echo "| 2. Build release image                                             |"
  echo "+--------------------------------------------------------------------+"
  echo ""

  base_image="prod-base-fp-graphhopper:${commit_id}"

  echo -e "> Build image ${base_image}\n"

  ./devops/build.sh -i ${base_image} -c ${commit_id}


  echo ""
  echo "+--------------------------------------------------------------------+"
  echo "| >>>>>>>>>>>>>>>>>>>>>>>>  DEPLOYMENT  <<<<<<<<<<<<<<<<<<<<<<<<<<<< |"
  echo "+--------------------------------------------------------------------+"
  echo ""

  if [[ ${CONFIRM_DEPLOY} == "yes" ]]; then
    read -r -p "* Are you sure to continue with the deployment? [y/N] " response

    case "${response}" in
      [[yY])
        echo "* Ok"
        ;;
      *)
        echo "* Deploy status: aborted"
        exit 1
        ;;
    esac
  fi

  echo ""
  echo "+--------------------------------------------------------------------+"
  echo "| 1. Push release image                                              |"
  echo "+--------------------------------------------------------------------+"
  echo ""

  echo ""
  echo "---> Push image to registry"
  echo ""


  aws_profile=fp-devops
  region=us-west-1
  host="108338497096.dkr.ecr.${region}.amazonaws.com"



  aws --profile ${aws_profile} ecr get-login-password --region ${region} | \
    docker login --username AWS --password-stdin ${host}

  target_image=108338497096.dkr.ecr.${region}.amazonaws.com/prod-fp-graphhopper:${commit_id}

  docker tag ${base_image} ${target_image}
  docker push ${target_image}

  echo -e "\n* Pushed image: ${target_image}\n"
else
  echo "Image ${repository_name}:${commit_id} already exists"
fi

echo ""
echo "+--------------------------------------------------------------------+"
echo "| 2. Deploy to Kubernetes                                            |"
echo "+--------------------------------------------------------------------+"
echo ""

./devops/cluster-auth.sh