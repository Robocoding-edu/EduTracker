#!/usr/bin/env python3

import math

import cv2
import rclpy
from cv_bridge import CvBridge
from rclpy.duration import Duration
from rclpy.node import Node
from sensor_msgs.msg import Image
from visualization_msgs.msg import Marker

import numpy as np
import onnxruntime as ort

class YoloDetector:

    def __init__(self):

        self.session = ort.InferenceSession(
            "yolo-fastest-sim.onnx",
            providers=["CPUExecutionProvider"]
        )

        self.input_name = (
            self.session.get_inputs()[0].name
        )

        self.confidence = 0.7

        self.input_w = 512
        self.input_h = 320

        self.real_object_width = 0.15
        self.focal_length = 280.0
        self.fov_h = math.radians(62.2)

        self.names = {
            0: "class0",
            1: "class1",
            2: "class2"
        }


    def sigmoid(self, x):
        return 1.0 / (1.0 + np.exp(-x))


    def preprocess(self, image):

        img = cv2.resize(
            image,
            (self.input_w, self.input_h)
        )

        img = cv2.cvtColor(
            img,
            cv2.COLOR_BGR2RGB
        )

        img = img.astype(np.float32)

        img /= 255.0

        img = np.transpose(
            img,
            (2, 0, 1)
        )

        img = np.expand_dims(
            img,
            axis=0
        )

        return img


    def process_frame(self, frame):

        output = frame.copy()

        frame_h, frame_w = frame.shape[:2]

        input_tensor = self.preprocess(
            frame
        )

        result = self.session.run(
            None,
            {
                self.input_name:
                    input_tensor
            }
        )

        detections = result[0][0]

        scale_x = (
            frame_w /
            self.input_w
        )

        scale_y = (
            frame_h /
            self.input_h
        )

        boxes = []
        scores = []
        class_ids = []

        for det in detections:

            x1, y1, x2, y2 = det[:4]

            logits = det[4:]

            probs = self.sigmoid(
                logits
            )

            class_id = np.argmax(
                probs
            )

            score = probs[class_id]

            if score < self.confidence:
                continue

            x1 = int(x1 * scale_x)
            y1 = int(y1 * scale_y)

            x2 = int(x2 * scale_x)
            y2 = int(y2 * scale_y)

            boxes.append([
                x1,
                y1,
                x2 - x1,
                y2 - y1
            ])

            scores.append(
                float(score)
            )

            class_ids.append(
                int(class_id)
            )

        if len(boxes) == 0:
            return output, []

        indices = cv2.dnn.NMSBoxes(
            boxes,
            scores,
            self.confidence,
            0.45
        )

        objects = []

        for idx in indices:

            if isinstance(
                idx,
                (list, tuple, np.ndarray)
            ):
                i = idx[0]
            else:
                i = idx

            x, y, w, h = boxes[i]

            if w <= 0:
                continue

            x1 = x
            y1 = y

            x2 = x + w
            y2 = y + h

            cls = class_ids[i]

            name = self.names.get(
                cls,
                str(cls)
            )

            distance = (
                self.real_object_width *
                self.focal_length
            ) / w

            center_x = frame_w / 2

            object_center = (
                x1 + x2
            ) / 2

            offset = (
                object_center -
                center_x
            )

            angle = (
                offset /
                center_x
            ) * (
                self.fov_h / 2
            )

            robot_x = (
                distance *
                math.cos(angle)
            )

            robot_y = -(
                distance *
                math.sin(angle)
            )

            objects.append(
                (
                    robot_x,
                    robot_y,
                    name
                )
            )

            cv2.rectangle(
                output,
                (x1, y1),
                (x2, y2),
                (0, 255, 0),
                2
            )

            cv2.putText(
                output,
                f"{name} {score:.2f}",
                (x1, y1 - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (0, 255, 0),
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

    # rclpy.init()

    # node=YoloNode()

    # rclpy.spin(node)
    print("yolo is to havy for rasbery pi 3b")


if __name__=="__main__":
    main()
