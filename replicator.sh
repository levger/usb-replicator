#!/bin/bash
TEMPLATE_USB="0:1.4"
TMP_DIR="/home/pi/tmp"

GREEN_PIN=14
YELLOW_PIN=15
RED_PIN=18
SWITCH_PIN=23

CLONE_MODE=false # false: use rm/cp; true: use dd
TEMPLATE_IMAGE_NAME='template.img'

#####################################################################################################
### PHASE 1
# check if any device is connected to the specified (template) usb port
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
        TEMPLATE_DEVICE=`echo ${PORT_INFO} | grep -oP 'Device Files: \K/dev/sd.'`
        TEMPLATE_MOUNT=`lsblk -p | grep "${TEMPLATE_DEVICE}" | grep -oP '/media/.*'`
        echo "Template is located in: ${TEMPLATE_DEVICE}"

        # mount template if not mounted already
        if [ -z "$TEMPLATE_MOUNT" ]; then
            echo "Template was not mounted; mounting."
            udisksctl mount -b ${TEMPLATE_DEVICE}
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

# check for available diskspace
# df output is in the form:
# Filesystem    1K-blocks   Used    Available   Use%    Mounted on
# /dev/root     1234        1234    1234        1234    /
# ...           ...         ...     ...         ...     ...
#AVAILABLE_SPACE=`df | grep -oP '/dev/root(\ +[0-9]+){2}\ +\K[0-9]+'`
RE_ROOT='/dev/root'
RE_TOTAL_SPACE='\ +\K[0-9]+'
RE_USED_SPACE='\ +[0-9]+\ +\K[0-9]+'
RE_AVAILABLE_SPACE='(\ +[0-9]+){2}\ +\K[0-9]+'
AVAILABLE_SPACE=`df | grep -oP '${RE_ROOT}${RE_AVAILABLE_SPACE}'`

if [ ${CLONE_MODE} == false ]; then
    REQ_SPACE=`df | grep -oP '${TEMPLATE_DEVICE}${RE_USED_SPACE}'`
    if [ ${AVAILABLE_SPACE} >= ${REQ_SPACE} ]; then
        # copy contents from template usb drive to tmp
        echo "Copying files from template USB drive to ${TMP_DIR}"
        cp -r ${TEMPLATE_MOUNT}/* ${TMP_DIR}/
    fi
else
    REQ_SPACE=`df | grep -oP '${TEMPLATE_DEVICE}${RE_TOTAL_SPACE}'`
    if [ ${AVAILABLE_SPACE} >= ${REQ_SPACE} ]; then
        echo "Cloning files from template USB drive to ${TMP_DIR}/${TEMPLATE_IMAGE_NAME}"
        dd if=${TEMPLATE_DEVICE} of=${TMP_DIR}/${TEMPLATE_IMAGE_NAME}
    fi
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
            TARGET_DEVICE=${line}
            echo ${TARGET_MOUNT}
            if [ -z "${TARGET_MOUNT}" ]; then
                echo "Target was not mounted"
                continue
            fi
            if [ ${CLONE_MODE} == false ]; then
                echo "... Deleting contents in ${TARGET_MOUNT}"
                rm -r ${TARGET_MOUNT}/*
                echo "... Copying tmp files to ${TARGET_MOUNT}"
                cp -r ${TMP_DIR}/* ${TARGET_MOUNT}/
                echo "... Ejecting"
                umount ${TARGET_MOUNT}
            else
                echo "... Ejecting before cloning"
                umount ${TARGET_MOUNT}
                echo "... Cloning image to ${TARGET_DEVICE}"
                dd if=${TMP_DIR}/${TEMPLATE_IMAGE_NAME} of=${TARGET_DEVICE}
            fi
        done <<< ${TARGET_PATHS}
    fi

    sleep 5
done
