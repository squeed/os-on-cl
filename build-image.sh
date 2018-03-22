#!/bin/sh -e

## Build a openshift-origin container image usable in rkt fly

image="$1"
version="$2"
if [[ -z "$version" || -z "$image" ]]; then
    >&2 echo "usage: $0 <IMAGE> <VERSION>"
    >&2 echo "e.g. $0 quay.io/foo/bar 42.0"
    exit 1
fi

if [[ $version =~ ^v ]]; then
    >&2 echo "version must not start with v"
    exit 1
fi

set -x

sed \
    -e "s|%%VERS%%|${version}|g" \
    hyperkube/hyperkube.Dockerfile.in > hyperkube/.dockerfile-${version}

docker build -t ${image}:v${version} -f hyperkube/.dockerfile-${version} hyperkube
docker images -q ${image}:v${version}
# docker push ${image}:v${version}
