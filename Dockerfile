FROM ros:jazzy-ros-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions \
    libudev-dev \
    python3-serial \
    python3-pip \
    python3-numpy \
    ros-jazzy-foxglove-bridge \
    ros-jazzy-slam-toolbox \
    ros-jazzy-cv-bridge \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir onnxruntime

WORKDIR /ros2_ws

# Копируем workspace
COPY ros2_ws/ /ros2_ws/

# Фикс для ldlidar под Jazzy
RUN grep -qxF '#include <pthread.h>' \
    /ros2_ws/src/ldlidar_stl_ros2/ldlidar_driver/src/logger/log_module.cpp || \
    sed -i '1s/^/#include <pthread.h>\n/' \
    /ros2_ws/src/ldlidar_stl_ros2/ldlidar_driver/src/logger/log_module.cpp

# Собираем workspace внутри образа
RUN chmod +x /ros2_ws/start_all.sh && \
    bash -c " \
      source /opt/ros/jazzy/setup.bash && \
      colcon build \
        --parallel-workers 1 \
        --symlink-install \
    "

# Чтобы контейнер сразу видел ROS
RUN echo 'source /opt/ros/jazzy/setup.bash' >> /root/.bashrc && \
    echo 'source /ros2_ws/install/setup.bash' >> /root/.bashrc

WORKDIR /ros2_ws

CMD ["bash", "-c", "source /opt/ros/jazzy/setup.bash && source /ros2_ws/install/setup.bash && ./start_all.sh"]
