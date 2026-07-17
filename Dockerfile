FROM ros:jazzy-ros-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions \
    libudev-dev \
    python3-serial \
    ros-jazzy-foxglove-bridge \
    ros-jazzy-slam-toolbox \
    ros-jazzy-cv-bridge \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /ros2_ws

# The complete ROS workspace, including the lidar driver, is versioned here.
COPY ros2_ws/ /ros2_ws/

# Keep the pthread compatibility patch for GCC with ROS 2 Jazzy.
RUN grep -qxF '#include <pthread.h>' /ros2_ws/src/ldlidar_stl_ros2/ldlidar_driver/src/logger/log_module.cpp || \
    sed -i '1s/^/#include <pthread.h>\n/' /ros2_ws/src/ldlidar_stl_ros2/ldlidar_driver/src/logger/log_module.cpp

# A single build worker prevents out-of-memory failures on RPi 3B.
RUN chmod +x /ros2_ws/start_all.sh && \
    /bin/bash -c "source /opt/ros/jazzy/setup.bash && colcon build --parallel-workers 1 --symlink-install"

RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc && \
    echo "source /ros2_ws/install/setup.bash" >> ~/.bashrc
