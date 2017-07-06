#!/bin/bash
TEMPLATE_USB="0:1.4"
TMP_DIR="/home/pi/tmp"

GREEN_PIN=14
YELLOW_PIN=15
RED_PIN=18
SWITCH_PIN=23

CLONE_MODE=false # false: use rm/cp; true: use dd

#####################################################################################################
### PHASE 1
# check if any device is connected to the specified usb port
# and determine copy/clone mode
#####################################################################################################
./led.py -p $GREEN_PIN -v high
while true
do
    # Select replication mode: clone or just copy
    SWITCH_STATUS="$(./switch.py -p ${SWITCH_PIN})"
    if [ "${SWITCH_STATUS}" == "0" ]; then
        CLONE_MODE=false
    else
        CLONE_MODE=true
    fi

    # Check if template usb pen drive is connected
    PORT_INFO="$(sudo hwinfo --usb | grep usb-${TEMPLATE_USB})"
    if [ -z "$PORT_INFO" ]; then
        # input not found
        continue
    else
        # input found
        TEMPLATE_PATH=`echo ${PORT_INFO} | grep -oP 'Device Files: \K/dev/sd.'`
        TEMPLATE_MOUNT=`lsblk -p | grep "${TEMPLATE_PATH}" | grep -oP '/media/.*'`
        echo "Template is located in: ${TEMPLATE_PATH}"

        # mount template if not mounted already
        if [ -z "$TEMPLATE_MOUNT" ]; then
            echo "Template was not mounted; mounting."
            udisksctl mount -b ${TEMPLATE_PATH}
            sleep 1
            continue
        else
            break
        fi

        echo "Template is mounted in: ${TEMPLATE_MOUNT}"
    fi
    sleep 1
done

#####################################################################################################
### PHASE 2
# write template onto raspberry pi
#####################################################################################################
./led.py -p $RED_PIN -v high

# delete old contents of tmp directory
echo "Cleaning up ${TMP_DIR}"
mkdir -p ${TMP_DIR}
rm -r ${TMP_DIR}/*

if [ ${CLONE_MODE} == false ]; then
    # copy contents from template usb drive to tmp
    echo "Copying files from template USB drive to ${TMP_DIR}"
    cp -r ${TEMPLATE_MOUNT}/* ${TMP_DIR}/
else
    # TODO dd
fi

umount ${TEMPLATE_MOUNT}

#####################################################################################################
### PHASE 3
# wait for usb drives to be connected and write data onto them
#####################################################################################################
./led.py -p $YELLOW_PIN -v high

while true
do
    TARGET_PATHS=`lsblk -p | grep -oP '/dev/sd.'`
    echo "Target devices are:"
    echo "${TARGET_PATHS}"

    # check if any of the inserted usb sticks is actually mounted.
    # only freshly inserted ones are mounted, since we actively unmount all sticks when
    # we are done writing to them.
    while read line
    do
        TARGET_MOUNT=`lsblk -p | grep "$line" | grep -oP '/media/.*'`
        echo ${TARGET_MOUNT}
        if [ -z "${TARGET_MOUNT}" ]; then
            continue
        else
            NEED_TO_REPLICATE=true
            break
        fi
    done <<< ${TARGET_PATHS}

    if [ ${NEED_TO_REPLICATE} == false ]; then
        ./led.py -p $RED_PIN -v low
    else
        ./led.py -p $RED_PIN -v high

        # do the actual work
        while read line
        do
            TARGET_MOUNT=`lsblk -p | grep "$line" | grep -oP '/media/.*'`
            echo ${TARGET_MOUNT}
            if [ -z "${TARGET_MOUNT}" ]; then
                echo "Target was not mounted"
                continue
            fi
            if [ ${CLONE_MODE} == false ]; then
                echo "... Copying tmp files to ${TARGET_MOUNT}"
                cp -r ${TMP_DIR}/* ${TARGET_MOUNT}/
            else
                echo "... Cloning image to ${TARGET_MOUNT}"
                #TODO dd ${TMP_DIR}/image.img ${TARGET_MOUNT}
            fi
            echo "... Ejecting"
            umount ${TARGET_MOUNT}
        done <<< ${TARGET_PATHS}
    fi

    sleep 5
done
