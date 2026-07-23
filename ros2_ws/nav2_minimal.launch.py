from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():

    params = "/ros2_ws/nav2_params.yaml"

    return LaunchDescription([

        Node(
            package="nav2_controller",
            executable="controller_server",
            output="screen",
            parameters=[params],
            remappings=[
                ("/cmd_vel", "/cmd_vel_nav")
            ]
        ),

        Node(
            package="nav2_planner",
            executable="planner_server",
            output="screen",
            parameters=[params]
        ),

        Node(
            package="nav2_bt_navigator",
            executable="bt_navigator",
            output="screen",
            parameters=[params]
        ),

        Node(
            package="nav2_behaviors",
            executable="behavior_server",
            output="screen",
            parameters=[params]
        ),

        Node(
            package="nav2_lifecycle_manager",
            executable="lifecycle_manager",
            output="screen",
            parameters=[{
                "autostart": True,
                "node_names": [
                    "controller_server",
                    "planner_server",
                    "bt_navigator",
                    "behavior_server"
                ]
            }]
        )
    ])
