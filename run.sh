#!/bin/bash

if [[ -z $1 ]]; then
  COMMAND=/bin/bash
else
  # used by the smoke tests to pass in exec to run
  COMMAND="/bin/bash -c $1"
fi

xhost + # allow connections to X server

XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

# grab all devices in /dev/dri/*
DRI_DEVS=$(find /dev/dri/card* -printf " --device=%p:%p ")

docker run -it \
        --privileged \
	-v $XSOCK:$XSOCK:rw \
	-v $XAUTH:$XAUTH:rw \
	-e DISPLAY=$DISPLAY \
	-e XAUTHORITY=$XAUTH \
	$DRI_DEVS \
	-w /home/devel/cairo-gl-smoke-tests \
	stuaxo/ubuntu-cairogl-debs $COMMAND
