# encrypted-dashcam
Dashcam software for Raspberry Pi with Encryption

## Rationale

- Protect your privacy
- Prevent car thieves from knowing where you've been to
- Give yourself (and people chosen by you) control over your dashcam recordings

## Hardware

Tested on the following hardware:

- Raspberry Pi 3B
- [Webcam, 120 Degree FOV, Manual Focus, Full HD 1080P](https://www.amazon.ca/dp/B07TDQ8NL3)
- SanDisk 8G USB Flash Drive
- Generic SD Card (it is used in read-only mode)
- Generic SAE J563 (automobile 12V power) to USB micro power cord

Other recommended components:

- Nanotape for mounting
- Raspberry Pi Case

Possible upgrades:

- Change USB Flash drive to [SLC CFast 2.0 card with power off protection](https://www.digikey.ca/en/products/detail/swissbit/SFCF1024H1AF2TO-C-MS-527-STD/12171452) and use it with a generic CFast 2.0 to USB adapter

## Software

The software consists of Bash scripts, successfully tested on 64-bit Raspberry Pi OS. You can probably get away with a different Linux distribution with minor adjustments.

The software is intentionally minimal to make it easier to audit / review.

## Design Requirement

1. The key required to decrypt the video is not physically present anywhere in your vehicle, so it is practically impossible for anyone to decrypt your videos without having possetion of a physically seperate key that can be kept in a secure location.
2. No keys or passwords need to be entered or transmitted at power up.
3. For convenience and ease of use, the key may be stored onboard the device, protected by a password.

## Principle of Operation

On power up, a random new AES-256 key is generated in memory. The key is encrypted by GPG using a master public key and recorded to USB storage. Videos are captured from a webcam and encrypted with this AES-256 key. They are also recorded to USB storage.

To decrypt the video, the private key corresponding to the master public key is used to decrypt each AES-256 key. These keys are then used to decrypt the video files.

Raspberry Pi OS is put into read-only mode to prevent SD card damage and to avoid security implications of swap (if it uses it at all). The USB Storage media could be damaged at a firmware level by power loss. Therefore it is recommended to use either power loss tolerant media (e.g. the SwissBit CFast 2.0 card mentioned above), or a small Uninterruptible Power Supply (UPS), which are available for Raspberry Pi.

Even if there is no firmware level damage to the media, there could be loss of the last portion of recording in event of an ungraceful shutdown. Using the "ext4" file system on the USB storage should prevent the file system from being corrupted, however a UPS is preferable to maximize the likelihood of capturing and recovering the last moments of video before power loss.

## Known Limitations

- The random number is generated with little-to-no entropy. A possible fix would be to use the last recorded videos as a source of entropy.
- There is no indication if recording is in progress. A possible fix is to add a status LED
- Audio is not recorded
- There is no transcoding or compression performed on the Pi (this may be desirable to make recovery easier in case of data damage)
- Raspberry Pi OS may remount the USB storage as read-only if it detects a power drop. This should be disabled somehow.
- The frame rate is low during testing (~10 frames per second?)
- The playback speed doesn't seem quite right, at least not in GNOME Videos
- The delay from power on to recording start, from recording stop to power off, and between clips hasn't yet been tested
- All decryption processes are manual, there is no tool for that yet
- No secure boot and SD card is unencrypted, so an adversary with physical access could swap out the software. Fix: you need an encrypted disk, trusted boot, TPM-secured platform. Maybe a smartphone?
- The temperature in your car may go outside the operating range of the hardware used here
- Doesn't matter that much in this application, but for code hygiene, need to add `builtin` keyword in a few places and make sure keys don't show up in `ps aux`

## Setup Instructions

It's an easy ~17 step process :)

I have not tested these instructions, they are just off-the-top-of-my-head. Some adjustments may be needed.

The following instructions are for "password" mode, wherein the GPG private key is stored on the Pi but password protected. Another, more secure option is to generate the GPG key elsewhere and import the public key to the Pi. I have not yet written out the instructions, but it should be very similar to these steps.

1. Prepare an SD card with Raspberry Pi OS. Tested with Raspberry Pi OS (64-bit) with desktop (Release date: October 22nd 2024) based on Debian version 12 "bookworm"
2. Power on the Pi and connect it to the Internet (detailed instruction available elsewhere)
3. Create user "dashcam" with any password you want. (Security Note: we give this user passwordless sudo, but the SD card is not encrypted so it doesn't make much difference.)
4. Copy start.sh from this repository to `/home/dashcam/start.sh`
5. In the Pi, `chmod +x /home/dashcam/start.sh`
6. Copy dashcam.service from this repository to `/etc/systemd/system/dashcam.service`
7. In the Pi, `sudo systemctl enable dashcam.service`
8. In the Pi, `sudo apt update; sudo apt install gpg ffmpeg`
9. In the Pi, `gpg --full-generate-key`. Set the name to "Driver", otherwise edit the script with your chosen name. Key data will be stored in `/home/dashcam/.gnupg`. CHOOSE A STRONG PASSWORD. RECORD YOUR PASSWORD, THIS IS YOUR MASTER PASSWORD.
10. In the Pi, `sudo nano /etc/sudoers.d/010_pi-nopasswd` and add the line `dashcam ALL=(ALL) NOPASSWD: ALL`
11. In the Pi, run `sudo raspi-config` and in "Performance Options > Overlay File System" - answer Yes to all
12. Format the USB flash drive with a single ext4 partition (detailed instruction available elsewhere)
13. Plug in the USB Webcam and USB flash drive to any USB port
14. In the Pi, run `mkdir /tmp/usb; sudo mount /dev/sda1 /tmp/usb` (do not add to /etc/fstab, mounting is handled by the start.sh script)
15. In the Pi, run `gpg --output /tmp/usb/secret.key --armor --export-secret-key Driver`
16. Reboot. The system should be operating normally after this power up, and subsequent ones as well
17. All the system to record some video, then follow the decryption instructions to confirm that it is working correctly

Now, you can print out the recovery procedure in doc/video-recovery along with your chosen GPG private key password, and keep it in a safe location. You can provide copies of this package to trusted people.

