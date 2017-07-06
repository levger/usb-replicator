#!/usr/bin/python

import RPi.GPIO as GPIO
import time
import sys, getopt

def main(argv):
    try:
        opts, args = getopt.getopt(argv,"p:",["pin="])
    except getopt.GetoptError:
        print("switch.py -p PINNUMBER")
    for opt, arg in opts:
        if opt in ("-p", "--pin"):
            pin = int(arg)
        else:
            sys.exit(2)

    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(pin,GPIO.IN)

    if GPIO.input(pin):
        print '1'
    else: 
        print '0'

if __name__ == "__main__":
    main(sys.argv[1:])
