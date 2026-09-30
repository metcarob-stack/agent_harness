#!/bin/bash

export PROJECT_NAME=${PWD##*/}          # to assign to a variable
export PROJECT_NAME=${PROJECT_NAME:-/}

export RJM_VERSION=$(cat ./VERSION)
export RJM_VERSION_UNDERSCORE=$(cat ./VERSION | tr '.' '_')
export RJM_MAJOR_VERSION=$(echo ${RJM_VERSION%%.*})

##export DOCKER_USERNAME=metcarob
export DOCKER_USERNAME=ghcr.io/metcarob-stack
export DOCKER_IMAGENAME=${PROJECT_NAME}
