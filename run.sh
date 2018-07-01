#!/usr/bin/env bash

docker run \
    -it \
    --rm \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    -v ${1}:/home/developer/project \
    uber-dev
