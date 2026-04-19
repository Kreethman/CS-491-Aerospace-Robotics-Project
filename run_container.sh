#!/bin/bash
xhost +local:docker
docker run -it \
	-e DISPLAY=$DISPLAY \
	--device /dev/dri:/dev/dri \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v "/shared/School Stuff/CS 491 Aerospace/project/src":/app/aerial_robotics_ws/src \
	aerobotics:latest
