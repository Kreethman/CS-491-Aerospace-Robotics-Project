#!/usr/bin/env python
import rospy
import mavros
from enum import Enum
import numpy as np

from mavros_msgs.msg import *
from mavros_msgs.srv import *
from apriltag_ros.msg import *

# What height to set for takeoff
TAKEOFF_HEIGHT = 10
# Time to wait for drone to reach altitude
CLIMB_TIME = 5
# Decide on how many subsequent detections there must be in order for this to work
SEARCH_MODE_STREAK = 5
# Parameters for movement
GAIN_PITCH = 60
GAIN_ROLL = 60
GAIN_YAW = 100 # This needs to be relatively large to have any discernable impact
GAIN_THROTTLE = 10

MAX_PITCH = 100
MAX_ROLL = 100
MAX_YAW = 100
MAX_THROTTLE = 100
# Z offset for when to transition into landing mode
LAND_HEIGHT = 10


class State(Enum):
    TAKEOFF = 1
    CLIMBING = 2
    SEARCH = 3
    ALIGN = 4
    LAND = 5

# Might be stolen from stackoverflow...
def quaternion_to_yaw(x, y, z, w):
    siny_cosp = 2.0 * (w * z + x * y)
    cosy_cosp = 1.0 - 2.0 * (y * y + z * z)

    return np.arctan2(siny_cosp, cosy_cosp)

class FlightPlan:
    def __init__(self):
        rospy.init_node("flight_node")

        self.state = State.TAKEOFF
        self.april_streak = 0
        self.takeoff_start_time = 0
        self.april_pose = None

        rospy.Subscriber("/minihawk_SIM/MH_usb_camera_link_optical/tag_detections", AprilTagDetectionArray, self.aprilCallback)

        self.rc_pub = rospy.Publisher("/minihawk_SIM/mavros/rc/override", OverrideRCIn, queue_size=10)

        self.arm = rospy.ServiceProxy("/minihawk_SIM/mavros/cmd/arming", CommandBool)
        self.set_mode = rospy.ServiceProxy("/minihawk_SIM/mavros/set_mode", SetMode)
        self.takeoff_service = rospy.ServiceProxy("/minihawk_SIM/mavros/cmd/takeoff", CommandTOL)
        self.land_service = rospy.ServiceProxy("/minihawk_SIM/mavros/cmd/land", CommandTOL)

        self.rate = rospy.Rate(20)
    
    def aprilCallback(self, msg):
        for detection in msg.detections:
            tag_id = detection.id[0]

            self.april_pose = detection.pose.pose.pose
            self.april_streak += 1
            #position = pose.position
            #orientation = pose.orientation
        if len(msg.detections) == 0 and self.april_streak > 0:
            self.april_streak -= 1
            self.april_pose = None


        

    def run(self):
        while not rospy.is_shutdown():
            if self.state == State.TAKEOFF:
                # Apply the takeoff command
                self.set_mode(custom_mode="GUIDED")
                self.arm(True)
                self.takeoff_service(0, 0, 0, 0, TAKEOFF_HEIGHT)
                
                self.takeoff_start_time = rospy.Time.now()
                self.state = State.CLIMBING
                print("CLIMBING")

            elif self.state == State.CLIMBING:
                elapsed = (rospy.Time.now() - self.takeoff_start_time).to_sec()
                if elapsed > 10:
                    self.set_mode(custom_mode="AUTO")
                    self.arm(True)
                    self.state = State.SEARCH
                    print("SEARCHING")

            elif self.state == State.SEARCH:
                if self.april_streak >= SEARCH_MODE_STREAK:
                    self.set_mode(custom_mode="QLOITER")
                    self.state = State.ALIGN
                    print("ALIGNING")

            elif self.state == State.ALIGN:
                yaw_input = 1500
                roll_input = 1500
                pitch_input = 1500
                z_input = 1500

                yaw_error = 0
                roll_error = 0
                pitch_error = 0
                z_error = 0
                # If there is a marker to compute and find errors:
                if self.april_pose:
                    p = self.april_pose.position
                    q = self.april_pose.orientation
                    # YAW
                    yaw_error = -quaternion_to_yaw(q.x,q.y,q.z,q.w)
                    if abs(yaw_error) < .3:
                        yaw_error = 0
                    # ROLL
                    roll_error = p.x
                    if abs(roll_error) < .3:
                        roll_error = 0
                    # PITCH
                    pitch_error = -p.y
                    if abs(pitch_error) < .1:
                        pitch_error = 0
                    # HEIGHT
                    z_error = LAND_HEIGHT - p.z
                    if abs(z_error) < 1:
                        z_error = 0
                    print(p,yaw_error)
                
                yaw_input = yaw_error * GAIN_YAW
                roll_input = roll_error * GAIN_ROLL 
                pitch_input = pitch_error * GAIN_PITCH
                z_input = z_error * GAIN_THROTTLE

                if yaw_input > MAX_YAW:
                    yaw_input = MAX_YAW
                elif yaw_input < -MAX_YAW:
                    yaw_input = -MAX_YAW
                yaw_input += 1500
                
                if roll_input > MAX_ROLL:
                    roll_input = MAX_ROLL
                elif roll_input < -MAX_ROLL:
                    roll_input = -MAX_ROLL
                roll_input += 1500

                if pitch_input > MAX_PITCH:
                    pitch_input = MAX_PITCH
                elif pitch_input < -MAX_PITCH:
                    pitch_input = -MAX_PITCH
                pitch_input += 1500

                if z_input > MAX_THROTTLE:
                    z_input = MAX_THROTTLE
                elif z_input < -MAX_THROTTLE:
                    z_input = -MAX_THROTTLE
                z_input += 1500
                # MESSAGE
                msg = OverrideRCIn()
                msg.channels = [1500] * 18 # default values
                msg.channels[0] = roll_input
                msg.channels[1] = pitch_input
                msg.channels[2] = z_input
                msg.channels[3] = yaw_input
                msg.channels[4] = 1800
                msg.channels[5] = 1000
                msg.channels[6] = 1000
                msg.channels[7] = 1800
                print(msg.channels[0:4])
                self.rc_pub.publish(msg)
                # if in correct position OR lost track of the marker then land
                if (self.april_pose and abs(roll_error) < .5 and abs(pitch_error) < .5 and abs(z_error) < 5 and abs(yaw_error) < .2) or self.april_streak == 0:
                    self.set_mode(custom_mode="QLAND")
                    self.state = State.LAND
                    print("LANDING!")

            self.rate.sleep()
if __name__ == '__main__':
    node = FlightPlan()
    node.run()
