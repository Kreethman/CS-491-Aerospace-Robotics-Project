FROM ros:melodic

SHELL ["/bin/bash", "-c"]

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ros-melodic-mavros \
    ros-melodic-mavros-msgs \
    ros-melodic-apriltag \
    ros-melodic-apriltag-ros \
    ros-melodic-libmavconn \
    ros-melodic-message-to-tf \
    ros-melodic-xacro \
    ros-melodic-pcl-ros \
    ros-melodic-pcl-conversions \
    ros-melodic-camera-info-manager \
    ros-melodic-image-transport \
    ros-melodic-cv-bridge \
    ros-melodic-tf-conversions \
    ros-melodic-rviz \ 
    ros-melodic-gazebo-ros-pkgs \
    ros-melodic-gazebo-ros-control \
    ros-melodic-robot-state-publisher \
    ros-melodic-roscpp-tutorials \
    ros-melodic-ros-control \ 
    ros-melodic-ros-controllers \ 
    libgstreamer-plugins-base1.0-dev \
    python3-numpy \
    python3-jinja2 \
    python-pexpect \
    python-pip \
    python-catkin-tools \ 
    git \
    build-essential \
    cmake \
    gazebo9 \
    libgazebo9-dev \
    libpcl-dev \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade "pip<21"

RUN pip install \
    cython \
    monotonic==1.5 \
    future==0.18.2 \
    pymavlink==2.4.42 \
    mavproxy==1.8.49

RUN /opt/ros/melodic/lib/mavros/install_geographiclib_datasets.sh

RUN echo "source /opt/ros/melodic/setup.bash" >> /root/.bashrc
RUN echo "source /app/aerial_robotics_ws/devel/setup.bash" >> /root/.bashrc

RUN git config --global --add safe.directory '*'

COPY ./setup.sh /root

COPY ./docker_data /opt/docker_data

RUN chmod +x /root/setup.sh && /root/setup.sh

RUN echo "export  GAZEBO_MODEL_PATH=/usr/share/gazebo-9/models:/usr/share/mavlink_sitl_gazebo/models:/app/.gazebo/models:${GAZEBO_MODEL_PATH}" >> /root/.bashrc
RUN echo "export  GAZEBO_RESOURCE_PATH=/usr/share/gazebo-9:${GAZEBO_RESOURCE_PATH}" >> /root/.bashrc
RUN echo "export  GAZEBO_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/gazebo-9/plugins:/usr/lib/x86_64-linux-gnu/mavlink_sitl_gazebo/plugins:${GAZEBO_PLUGIN_PATH}" >> /root/.bashrc
RUN echo "export  LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/mavlink_sitl_gazebo/plugins:${LD_LIBRARY_PATH}" >> /root/.bashrc
