#!/bin/bash

if [ "${ORGANIZATION}" == "" ] ; then
    echo "Please set the ORGANIZATION environment variable"
    exit -1
fi
if [ "${ACCESS_TOKEN}" == "" ] ; then
    echo "Please set the ACCESS_TOKEN environment variable"
    exit -1
fi

# Start docker
service docker start || exit -1

# Get the token
REG_TOKEN=$(curl -sX POST -H "Authorization: token ${ACCESS_TOKEN}" https://api.github.com/orgs/${ORGANIZATION}/actions/runners/registration-token | jq .token --raw-output)

# Configure the runner
cd /home/docker/actions-runner
gosu docker ./config.sh --url https://github.com/${ORGANIZATION} --token ${REG_TOKEN}

cleanup() {
    echo "Removing runner..."
    gosu docker ./config.sh remove --unattended --token ${REG_TOKEN}
    echo "Stopping docker..."
    service docker stop
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Run the runner
gosu docker ./run.sh & wait $!
