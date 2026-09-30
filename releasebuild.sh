#!/usr/bin/env bash

VERSIONFILE="./VERSION"

echo "Bump version then build"
#Find minor version - text AFTER last dot in version string
OLDVERSION=$(cat ${VERSIONFILE})
OLDMINORVERSION=$(echo ${OLDVERSION} | sed 's/.*\.//')
CHARSINFIRSTPART=$(expr ${#OLDVERSION} - ${#OLDMINORVERSION})
RES=$?
if [ ${RES} -ne 0 ]; then
  echo "Invalid version number"
  exit 1
fi
OLDVERSIONWITHOUTMINOR=${OLDVERSION:0:${CHARSINFIRSTPART}}
RES=$?
if [ ${RES} -ne 0 ]; then
  echo "Invalid version number (Can't get first part)"
  exit 1
fi
NEWVERSION=${OLDVERSIONWITHOUTMINOR}$(expr ${OLDMINORVERSION} + 1)

echo ${NEWVERSION} > ${VERSIONFILE}

VERSION=$(cat ${VERSIONFILE})

echo "Building version ${VERSION}"

docker build -t hermes-custom:${VERSION} .
RES=$?
if [[ ${RES} -ne 0 ]]; then
	echo "Failed to build image"
	exit ${RES}
fi

echo "Build complete"
echo "output image is hermes-custom:${VERSION}"

exit 0
