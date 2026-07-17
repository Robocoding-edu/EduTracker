#!/bin/bash
source /opt/ros/jazzy/setup.bash
source /ros2_ws/install/setup.bash


echo "=== 1. Запуск драйвера лидара с автореанимацией ==="
(
    while true; do
        ros2 launch ldlidar_stl_ros2 ld19.launch.py
        echo "⚠️ Лидар упал из-за лага CPU! Воскрешаю..."
        sleep 2
    done
) &
LIDAR_PID=$!
sleep 4 # Даем лидару спокойно раскрутиться

echo "=== 2. Запуск Slam Toolbox ==="
ros2 launch slam_toolbox online_sync_launch.py \
  slam_params_file:=/ros2_ws/my_slam_params.yaml &
SLAM_PID=$!
sleep 4

echo "=== 3. Запуск ROS-ноды камеры ==="
python3 /ros2_ws/camera_driver.py &
CAMERA_DRIVER_PID=$!
sleep 1

echo "=== 4. Запуск OpenCV-ноды камеры ==="
python3 /ros2_ws/openCV.py &
OPENCV_PID=$!
sleep 1

echo "=== 5. Запуск Serial моста с Atmega2560 ==="
python3 /ros2_ws/serial_bridge.py &
SERIAL_PID=$!
sleep 1

echo "=== 6. Запуск Foxglove Bridge ==="
ros2 launch foxglove_bridge foxglove_bridge_launch.xml &
BRIDGE_PID=$!

wait $LIDAR_PID $SLAM_PID $CAMERA_DRIVER_PID $OPENCV_PID $SERIAL_PID $BRIDGE_PID
