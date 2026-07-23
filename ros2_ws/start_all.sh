#!/bin/bash
source /opt/ros/jazzy/setup.bash
source /ros2_ws/install/setup.bash

run_node()
{
    NAME=$1
    CMD=$2

    while true; do
        echo "Starting $NAME"
        eval $CMD

        echo "$NAME crashed. Restarting in 2 sec..."
        sleep 2
    done
}


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


echo "=== 4. Запуск Vision ==="

case "$DETECTION_MODE" in

    opencv)
        run_node "OpenCV" "python3 /ros2_ws/openCV.py" &
        VISION_PID=$!
        ;;


    yolo)
        run_node "YOLO" "python3 /ros2_ws/yolo.py" &
        VISION_PID=$!
        ;;


    *)
        echo "❌ Неизвестный VISION_ENGINE=$VISION_ENGINE"
        echo "Доступно: opencv,yolo"
        exit 1
        ;;

esac
sleep 1



echo "=== 5. Запуск Serial моста с Atmega2560 ==="
python3 /ros2_ws/serial_bridge.py &
SERIAL_PID=$!
sleep 1

echo "=== 6. Запуск nav2 ==="
ros2 launch /ros2_ws/nav2_minimal.launch.py &
NAV_PID=$!
sleep 4

echo "=== 7. Запуск Foxglove Bridge ==="
ros2 launch foxglove_bridge foxglove_bridge_launch.xml &
BRIDGE_PID=$!

wait $LIDAR_PID \
     $SLAM_PID \
     $CAMERA_DRIVER_PID \
     $VISION_PID \
     $SERIAL_PID \
     $NAV_PID \
     $BRIDGE_PID
