#!/bin/bash
xhost +local:docker
docker run -it \
	-e DISPLAY=$DISPLAY \
	--device /dev/dri:/dev/dri \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v "./src":/app/aerial_robotics_ws/src \
	aerobotics:latest
