FROM ros:jazzy-ros-base

# Отключаем интерактивные окна apt
ENV DEBIAN_FRONTEND=noninteractive

# Устанавливаем системные зависимости, Foxglove и Slam Toolbox
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-colcon-common-extensions \
    libudev-dev \
    python3-serial \
    ros-jazzy-foxglove-bridge \
    ros-jazzy-slam-toolbox \
    ros-jazzy-cv-bridge \
    && rm -rf /var/lib/apt/lists/*

# Создаем рабочую директорию воркспейса
WORKDIR /ros2_ws

# Скачиваем исходники драйвера лидара
RUN mkdir -p src && cd src && \
    git clone https://github.com/ldrobotSensorTeam/ldlidar_stl_ros2.git

# Применяем патч pthread для GCC под ROS2 Jazzy прямо внутри образа
RUN sed -i '1s/^/#include <pthread.h>\n/' /ros2_ws/src/ldlidar_stl_ros2/ldlidar_driver/src/logger/log_module.cpp

# Собираем воркспейс в 1 поток, чтобы RPi 3B не упала по нехватке памяти
RUN /bin/bash -c "source /opt/ros/jazzy/setup.bash && colcon build --parallel-workers 1 --symlink-install"

# Настраиваем авто-сорс окружения для удобства отладки вручную
RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc && \
    echo "source /ros2_ws/install/setup.bash" >> ~/.bashrc

# Делаем скрипт запуска исполняемым (на случай, если у хоста слетят права)
RUN chmod +x /ros2_ws/start_all.sh || true

COPY ./ros2_ws/start_all.sh /ros2_ws/start_all.sh
