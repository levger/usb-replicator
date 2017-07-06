#!/usr/bin/python

import RPi.GPIO as GPIO
import time
import sys, getopt

def showUsage():
    print 'USAGE:\
         \nled.py -p <pin> -v <high/low>'
    sys.exit(2)

def main(argv):
    try:
        opts, args = getopt.getopt(argv,"hp:v:",["help=","pin=","voltage="])
    except getopt.GetoptError:
        showUsage()
    if not opts:
	showUsage()

    for opt, arg in opts:
        if opt in ("-h", "--help"):
            showUsage()
        elif opt in ("-p", "--pin"):
            pin = int(arg)
        elif opt in ("-v", "--voltage"):
            if (arg == "high"):
                hilo = GPIO.HIGH
            elif (arg == "low"):
                hilo = GPIO.LOW
        else:
            showUsage()

    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(pin,GPIO.OUT)
    GPIO.output(pin,hilo)

if __name__ == "__main__":
    main(sys.argv[1:])
