#!/bin/bash
set -e
# SETUP AND BUILD
mkdir -p /app/aerial_robotics_ws
# Safe to uncomment these commands
cd /app/aerial_robotics_ws
#catkin config -DCMAKE_BUILD_TYPE=Release
#catkin build

# INSTALL ARDUPILOT
git clone --recursive https://github.com/ArduPilot/ardupilot && cd ardupilot

git checkout Plane-4.2
./Tools/gittools/submodule-sync.sh
# Script will panic if it is in sudouser context, despite using sudo at many points. Gaping security hole but a necessary one to introduce user to proxy sudo
useradd -m -G sudo --password="" --shell /bin/bash fake_user
# Also note that we need to prevent pip from reinstalling these packages or else the script will crash from trying to use the wrong python environment. Crude but works
sed -i 's/MAVProxy/MAVProxy==1.8.49/g' ./Tools/environment_install/install-prereqs-ubuntu.sh
sed -i 's/pymavlink/pymavlink==2.4.42/g' ./Tools/environment_install/install-prereqs-ubuntu.sh
sudo -u fake_user -H git config --global --add safe.directory '*'
sudo -u fake_user -H ./Tools/environment_install/install-prereqs-ubuntu.sh -y
# Close gaping security hole!
userdel fake_user
# reset mavproxy version
#pip install mavproxy==1.8.49

cd /app/aerial_robotics_ws/ardupilot
patch -p0 < /opt/docker_data/data/vehicleinfo_py.patch 
cp /opt/docker_data/data/ArduPlane_MiniHawk_Gazebo.parm ./Tools/autotest/default_params
# Gazebo for simulation
cd /app/aerial_robotics_ws && git clone --recursive https://github.com/khancyr/ardupilot_gazebo && cd ardupilot_gazebo
mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -S . -B ..
make -j 12 && make install


cd /app/aerial_robotics_ws/ardupilot_gazebo
patch -p0 < /opt/docker_data/data/ArduPilotPlugin_hh.patch
patch -p0 < /opt/docker_data/data/ArduPilotPlugin_cc.patch
cd build && make -j 12 && make install

cd /app/aerial_robotics_ws && git clone --recursive https://github.com/PX4/sitl_gazebo.git && cd sitl_gazebo
git checkout 9343aaf4e275db48fce02dd25c5bd8273c2d583a
mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -S . -B ..
make -j 12 && make install
# The sitl_gazebo make install script does not copy libphysics_msgs.so to the install path, do so manually:
cp /app/aerial_robotics_ws/sitl_gazebo/build/libphysics_msgs.so /usr/lib/x86_64-linux-gnu/mavlink_sitl_gazebo/plugins/
# The sitl_gazebo package installs its own libLiftDragPlugin.so (breaks flight transition simulation) which can overlap with the version of gazebo-9, as they are both installed under the /usr/lib/x86_64-linux-gnu system path, so we have to hide it:
mv /usr/lib/x86_64-linux-gnu/mavlink_sitl_gazebo/plugins/libLiftDragPlugin.so /usr/lib/x86_64-linux-gnu/mavlink_sitl_gazebo/plugins/libLiftDragPlugin.so.PX4_SITL_VERSION
# Note in future may need to move this to /root, OR create a user context for gazebo and move into that home directory (not fakeuser as that has super sudo)
mkdir -p /app/.gazebo/models/
cp -r /opt/docker_data/models/* /app/.gazebo/models/

cd /app/aerial_robotics_ws
#catkin build
