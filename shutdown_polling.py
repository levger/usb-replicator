#!/bin/python
# shut down on button press

import RPi.GPIO as gpio
import time, os

btn_pin=24
gpio.setmode(gpio.BCM)
gpio.setup(btn_pin, gpio.IN, pull_up_down = gpio.PUD_UP)

def shutdown(channel):
    os.system("sudo shutdown -h now")

gpio.add_event_detect(btn_pin, gpio.FALLING, callback=shutdown, bouncetime = 2000)

while 1:
    time.sleep(1)

