#!/usr/bin/env python3

import math

import cv2
import rclpy
from cv_bridge import CvBridge
from rclpy.duration import Duration
from rclpy.node import Node
from sensor_msgs.msg import Image
from visualization_msgs.msg import Marker

from ultralytics import YOLO
# import onnxruntime as ort

class YoloDetector:

    def __init__(self):
        self.model = YOLO("yolov8n.pt")

        self.confidence = 0.5

        # твоя камера
        self.real_object_width = 0.15
        self.focal_length = 280.0
        self.fov_h = math.radians(62.2)


    def process_frame(self, frame):

        output = frame.copy()

        results = self.model(
            frame,
            conf=self.confidence,
            verbose=False
        )


        objects = []


        for result in results:

            for box in result.boxes:

                x1, y1, x2, y2 = box.xyxy[0]

                x1 = int(x1)
                y1 = int(y1)
                x2 = int(x2)
                y2 = int(y2)


                cls = int(box.cls[0])
                name = self.model.names[cls]

                width = x2 - x1


                if width <= 0:
                    continue


                distance = (
                    self.real_object_width *
                    self.focal_length
                ) / width


                center_x = frame.shape[1] / 2

                object_center = (x1+x2)/2

                offset = object_center-center_x

                angle = (
                    offset / center_x
                ) * (self.fov_h/2)


                robot_x = distance * math.cos(angle)
                robot_y = -distance * math.sin(angle)


                objects.append(
                    (
                        robot_x,
                        robot_y,
                        name
                    )
                )


                cv2.rectangle(
                    output,
                    (x1,y1),
                    (x2,y2),
                    (0,255,0),
                    2
                )


                cv2.putText(
                    output,
                    f"{name} {distance:.2f}m",
                    (x1,y1-10),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.5,
                    (0,255,0),
                    2
                )


        return output, objects



class YoloNode(Node):

    def __init__(self):

        super().__init__("yolo_processor")


        self.bridge = CvBridge()

        self.detector = YoloDetector()

        self.marker_id = 0


        self.processed_pub = self.create_publisher(
            Image,
            "/camera/image_processed",
            1
        )


        self.marker_pub = self.create_publisher(
            Marker,
            "/robot/detected_objects",
            10
        )


        self.subscription = self.create_subscription(
            Image,
            "/camera/image_raw",
            self.callback,
            1
        )


        self.get_logger().info(
            "YOLO node started"
        )


    def callback(self,msg):

        frame = self.bridge.imgmsg_to_cv2(
            msg,
            "bgr8"
        )


        processed, objects = (
            self.detector.process_frame(frame)
        )


        out = self.bridge.cv2_to_imgmsg(
            processed,
            "bgr8"
        )

        out.header = msg.header

        self.processed_pub.publish(out)



        for x,y,name in objects:
            self.publish_marker(
                msg.header.stamp,
                x,
                y,
                name
            )


    def publish_marker(
        self,
        stamp,
        x,
        y,
        name
    ):

        marker = Marker()

        marker.header.stamp = stamp
        marker.header.frame_id="base_link"

        marker.ns="yolo_objects"

        marker.id=self.marker_id

        self.marker_id+=1


        marker.type=Marker.CUBE

        marker.action=Marker.ADD


        marker.pose.position.x=x
        marker.pose.position.y=y


        marker.pose.orientation.w=1


        marker.scale.x=0.1
        marker.scale.y=0.1
        marker.scale.z=0.1


        marker.color.g=1.0
        marker.color.a=1.0


        marker.text=name

        marker.lifetime=Duration(
            seconds=0.5
        ).to_msg()


        self.marker_pub.publish(marker)



def main():

    rclpy.init()

    node=YoloNode()

    rclpy.spin(node)


if __name__=="__main__":
    main()
