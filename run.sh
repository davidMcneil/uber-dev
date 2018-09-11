#!/usr/bin/env bash

docker run \
    -it \
    --rm \
    --network none \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    -v ${1}:/home/developer/project \
    -v /usr/share/icons:/usr/share/icons:ro \
    uber-dev
