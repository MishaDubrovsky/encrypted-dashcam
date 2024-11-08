#!/bin/bash

# Exit upon any failure (by default)
set -e

CAMERA_DEVICE="/dev/video0"
STORAGE_DEVICE="/dev/sda1"
MOUNTPOINT="$HOME/usbflash"
THRESHOLD_HIGH=75
THRESHOLD_LOW=50

# Function to check disk usage percentage
get_disk_usage() {
    df "$MOUNTPOINT" | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to delete files from the disk until sufficient space is freed.
delete_old_files() {
        # Check the current disk usage
        current_usage=$(get_disk_usage)

        # If current usage is more than THRESHOLD_HIGH %, proceed to delete files
        if [ "$current_usage" -gt "$THRESHOLD_HIGH" ]; then
                echo "Current disk usage is ${current_usage}%, which is above ${THRESHOLD_HIGH}%. Checking for files to delete..."

                # Sort files by their numeric value of n and delete them one by one
                while [ "$current_usage" -gt "$THRESHOLD_LOW" ]; do
                        # Find the file with the lowest value of n
                        # TODO: any '.' in the path other than in the final video file name will mess up this logic.
                        file_to_delete=$(ls "$MOUNTPOINT"/video.enc.* 2>/dev/null | sort -t. -k3,3n | head -n 1)

                        # Check if there's a file to delete
                        if [ -z "$file_to_delete" ]; then
                                echo "No more files to delete."
                                break
                        fi

                        # Delete the file
                        echo "Deleting $file_to_delete..."
                        rm "$file_to_delete"

                        # Check disk usage again
                        current_usage=$(get_disk_usage)
                done
        else
            	echo "Current disk usage is ${current_usage}%, which is below ${THRESHOLD_HIGH}%. No action needed."
        fi
}

get_next_key_filename() {
    local base_name="$1"
    local pattern="${base_name}.*"
    local highest_number=0

    for file in $pattern; do
        if [[ $file =~ ${base_name}\.([0-9]+) ]]; then
            number=${BASH_REMATCH[1]}
            if (( number > highest_number )); then
                highest_number=$number
            fi
	fi
    done

    local next_number=$((highest_number + 1))
    echo "${next_number}"
}

# Make sure camera is present
if [ ! -c "$CAMERA_DEVICE" ]; then
    echo "ERROR: cannot find camera. Is a V4L2 compatible USB camera attached?"
    exit 1
fi

# Make sure disk and partition 1 are present
if [ ! -b "$STORAGE_DEVICE" ]; then
    echo "ERROR: Disk or partition 1 missing. Check USB flash drive."
    exit 1
fi

# Create mountpoint if needed
mkdir -p "$MOUNTPOINT"

# Make sure mountpoint was created
if [ ! -d "$MOUNTPOINT" ]; then
    echo "ERROR: Cannot create mountpoint."
    exit 1
fi

# Mount disk (Assuming UID and GID are 1000)
# Disable "e" check (We will check if it fails in the next step)
set +e
sudo mount "$STORAGE_DEVICE" "$MOUNTPOINT"
# This was for VFAT but not needed for EXT4: -o gid=1000,uid=1000
set -e

# Make sure it's mounted successfully
df "$MOUNTPOINT" | grep "$STORAGE_DEVICE"

# Clear up old files until there is enough space on the disk
delete_old_files

# Location of the encrypted symmetrical key and encrypted video
ENCRYPTED_KEY_BASE="$MOUNTPOINT/encrypted_key.gpg"
ENCRYPTED_VIDEO_BASE="$MOUNTPOINT/video.enc"
NEXT_INDEX="$(get_next_key_filename "$ENCRYPTED_KEY_BASE")"
ENCRYPTED_KEY="${ENCRYPTED_KEY_BASE}.${NEXT_INDEX}"
ENCRYPTED_VIDEO_SERIES="${ENCRYPTED_VIDEO_BASE}.${NEXT_INDEX}"

# Name of asymmetric gpg key
KEY_NAME="Driver"

# Generate AES-256-CBC key and IV and store them in variables
KEY=$(openssl rand -hex 32)  # 32 bytes = 256 bits, output as hexadecimal
IV=$(openssl rand -hex 16)   # 16 bytes = 128 bits, output as hexadecimal

# Encrypt the key and IV using GPG for user KEY_NAME
# Combine the key and IV in one string, echo it, and pipe to gpg for encryption
echo -e "$KEY\n$IV" | gpg --output $ENCRYPTED_KEY --encrypt --recipient "$KEY_NAME" -

# Check if key and IV encryption was successful before proceeding
if [ ! -f "$ENCRYPTED_KEY" ]; then
    echo "ERROR: Failed to encrypt key and IV."
    exit 1
fi

# Set Camera mode to HD (Specifying it in ffmpeg didn't work for me)
v4l2-ctl --device "$CAMERA_DEVICE" --set-fmt-video width=1920,height=1080

# Record 60 seconds of video at a time
while true; do
    NEXT_SUBINDEX="$(get_next_key_filename "$ENCRYPTED_VIDEO_SERIES")"
    ENCRYPTED_VIDEO="${ENCRYPTED_VIDEO_SERIES}.${NEXT_SUBINDEX}"

    ffmpeg -f v4l2 -input_format mjpeg -i "$CAMERA_DEVICE" \
      -c:v copy -t 60 -v verbose -f mjpeg - | \
      openssl enc -aes-256-cbc -salt -out "$ENCRYPTED_VIDEO" \
      -K "$KEY" -iv "$IV"
done

# To decrypt the video:
# gpg -d encrypted_key.gpg
# openssl enc -d -aes-256-cbc -in video.enc -out video.mjpeg -K ... -iv ...
# E.g.
# openssl enc -d -aes-256-cbc -in video.enc -out video.mjpeg -K 85d7a9680c18df091ccd70105b32043af9c8ddb5318896f74f5d744b4c85926d \
# -iv ab0d41518e5a37a8f5206e074aab1a73

