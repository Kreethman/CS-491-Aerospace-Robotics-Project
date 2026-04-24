# Robotics Project

## Getting the container ready

### Build docker container

Build the docker container (this takes a while to compile):
```
docker build -t aerobotics:latest .
```

### Spin the docker container

This is where user configuration comes into play; how you actually start the container and bind system resources depends largely on your operating system 
so I can't guarantee that this will work for you- in fact it almost certainly wont't. The content of ```run_container.sh``` does the following:

- ```+xhost local:docker``` allows the container to create graphic applications
- ```--device /dev/dri:/dev/dri``` allows container access to GPU also for graphic applications
- ```-v /tmp/.X11-unix:/tmp/.X11-unix``` also is necessary for using graphic applications
- ```-v "./src":/app/aerial_robotics_ws/src``` Grabs src directory for wherever its being run and binds that to the container; this means ```/src``` is where you keep your code

### Execute into container

You can find the container's id with ```docker ps -a```. Additional terminals can enter the same container by running ```exec_container.sh <CONTAINER_ID>```.

## Once inside the container...

### Build packages

Enter ```/app/aerial_robotics_ws``` and execute ```catkin build``` to compile packages. Note that the src directory was bound at container runtime so we can't compile earlier

NOTE: The .bashrc file *should* be executing both ```/ros_entrypoint.sh``` and ```/app/aerial_robotics_ws/devel/setup.bash``` automatically when creating a terminal but I find it to not work a lot of the time and frankly don't know why. If commands don't work first step is always to try re-executing these two values! Here's the two of them together for easy copy/pasting
```
source /ros_entrypoint.sh
source /app/aerial_robotics_ws/devel/setup.bash
```

### Gazebo Sim

This is the actual engine that does the physics sim and stuff. This will hang the terminal while it runs and sometimes has important error output for troubleshooting so I would recommend leaving this terminal open
```
roslaunch robowork_minihawk_gazebo minihawk_playpen.launch
```

### Ardupilot

This is a really common autopilot software and uses Mavlink to communicate with Gazebo

```
cd /app/aerial_robotics_ws/ardupilot
./Tools/autotest/sim_vehicle.py -v ArduPlane -f gazebo-minihawk --model gazebo-quadplane-tilttri --console  # --map
wp load ../src/aerial_robotics/robowork_minihawk_gazebo/resources/waypoints.txt
```

### Rviz

This isn't actually necessary but good to have so you can see what the drone is viewing on the USB camera and local physics simulation

```
rviz -d /app/aerial_robotics_ws/src/aerial_robotics/robowork_minihawk_launch/config/minihawk_SIM.rviz
```

### MAVROS

This is where the actual ROS connectivity comes into play; this will create topics that communicate with Mavlink that communicates with Ardupilot and Gazebo

```
ROS_NAMESPACE="minihawk_SIM" roslaunch robowork_minihawk_launch vehicle1_apm_SIM.launch
```

## Packages

### Creating your package

Okay, so now we're in our ```/src``` directory on the docker terminal. Run ```catkin_create_pkg <package_name> geometry_msgs mavros_msgs rospy std_msgs apriltag_ros```. This will add a new package that catkin will build from the root ```/app/aerial_robotics_ws```. Inside the package is another ```src``` directory and that's where you can create your first node via just a python file! Not going to go over how to implement a node for brevity

### Running your node

Once we have a node working and we've recompiled via ```catkin build```, we can run our new node via
```
rosrun my_package test_node.py
```