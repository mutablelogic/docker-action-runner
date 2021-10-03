#!/bin/bash

if [ "${ORGANIZATION}" == "" ] ; then
    echo "Please set the ORGANIZATION environment variable"
    exit -1
fi
if [ "${ACCESS_TOKEN}" == "" ] ; then
    echo "Please set the ACCESS_TOKEN environment variable"
    exit -1
fi

# Get the token
REG_TOKEN=$(curl -sX POST -H "Authorization: token ${ACCESS_TOKEN}" https://api.github.com/orgs/${ORGANIZATION}/actions/runners/registration-token | jq .token --raw-output)

# Configure the runner
cd /home/docker/actions-runner
gosu docker ./config.sh --url https://github.com/${ORGANIZATION} --token ${REG_TOKEN} \
   --name "${NAME}" \
   --labels "${LABELS}" \
   --runnergroup "${GROUP}" \
   --unattended \
   --replace

# Trap signals and cleanup
cleanup() {
    echo "Removing runner..."
    gosu docker ./config.sh remove --unattended --token ${REG_TOKEN}
    exit
}

# Deregister runner on exit
trap cleanup SIGINT SIGQUIT SIGTERM INT TERM QUIT

# Set the docker permissions
echo "Setting docker permissions..."
if [ -e "/var/run/docker.sock" ] ; then
  chmod 666 /var/run/docker.sock
fi

# Run
gosu docker ./run.sh

