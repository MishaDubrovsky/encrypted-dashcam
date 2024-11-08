This guide is intended to assist with decrypting video written by the encrypted-dashcam software.

It is highly recommended to read the instructions once over before beginning any work.

If you do not fully understand the instructions, and the video is valuable to you, then it is highly recommended to not attempt decryption and consult with a professional.

# Background

It is assumed in these instructions that the original encrypted-dashcam software was set up per the instructions in the repository.

The encrypted-dashcam software is designed to run on a Raspberry Pi platform with USB flash storage attached. The SD card does not store video data, it is read-only. The USB flash drive contains all the video in encrypted form.

The following instructions assume you are using a Linux platform for recovery (tested on Fedora with GNOME). If you are using a different system, adjust the instructions accordingly. You can also use the Raspberry Pi itself, if you connect a keyboard, mouse, and monitor.

You will be importing the GPG master key with ultimate trust, so I suggest using a throwaway install of Linux (a virtual machine or container) or at least backing up the ~/.gnupg directory and restoring it later.

(TODO: Is it necessary to install key with ultimate trust?)

# Instructions

These are instructions to decrypt video recorded by encrypted-dashcam.

1. Create a forensic (block level) master copy of the USB storage, if needed. Create throwaway copies of this master as needed. All further references to USB storage in these instructions are references to a throwaway copy.
2. Mount the USB storage. There should be a single partition with the "ext4" filesystem.
3. Run fsck to check and repair the filesystem.
4. In the root of the filesystem, there is a file master.key. Run `gpg --import master.key` and set this key to ultimate trust.
5. In the root of the filesystem, there are files like `encrypted_key.gpg.26` and files like `video.enc.26.2`. The `video.enc` files are ~1 minute long mjpeg (not to be confused with mpeg) video files encrypted with AES-256-CBC. The `encrypted_key.gpg` files hold the keys to decrypt. For a video file `video.enc.26.2`, 26 is the number of the key used to encrypt it, and 2 is the sequence number of the clip. A new key is generated every time the dashcam is powered on.
6. There is currently no automated way to decrypt the clips and assemble them into video, so this guide will describe the manual steps to decrypt. Assembling into a video can be done with the ffmpeg software, but is not described here.
7. Start by decrypting the `encrypted_key.gpg` files. They are encrypted by a GPG public key you imported in step 4. Run `gpg -d encrypted_key.gpg.XX` to decrypt. You will be prompted for a password. Enter the password provided to you with these instructions. Two lines will be printed, the first longer line is the `K` value and the second shorter line is the `iv` value. 
8. To decrypt a clip with the corresponding number, `video.enc.XX.1`, run the following command: `openssl enc -d -aes-256-cbc -in video.enc -out video.mjpeg -K 85d7a9680c18df091ccd70105b32043af9c8ddb5318896f74f5d744b4c85926d -iv ab0d41518e5a37a8f5206e074aab1a73`. Replace the K and iv values with the ones from the command above.
9. You may get an error about a "bad decrypt" but this could just be because the file was truncated. As long at the file is large (not 0 bytes), you should be able to play it. Use any mjpeg compatible player, e.g. GNOME Videos (formerly Totem). 
10. In GNOME Videos, you can step through one frame at a time with the '.' (dot) key.

