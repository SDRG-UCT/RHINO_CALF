# RHINO Borph Quickstart
The disk image containted in this directory can be used to boot a RHINO board into BORPH linux with the minimum required functionality.

## Using the disk image

1) Download the [prepared RHINO BORPH SD card image](http://rrsg.ee.uct.ac.za/rhino_sdcard.img).

2) Copy the SD Card image to a SD Card that is at least 4GB big: `dd if=[PATH to SD card image]/rhino_sdcard.img of=[SD card device file] bs=1m`. Use `sudo fdisk -l` to find the SD card device file. It should be /dev/sdb or /dev/sdc, etc.

3) Put the two switches on S1 on the RHINO board into the "off" position.

4) Insert the SD card into the card reader on the board and power up the board by shorting the PWR_BUT jumpers.

5) The ARM CPU will by default send a DHCP request on the ethernet port. If there is no response, the board defaults to `192.168.0.2`.

6) Either:
 
	* The board should be accessible using `ssh root@[board address]`, where the board address should be either the one assigned by DHCP or the default.

	* The board should also be accessible via the serial terminal. Connect to the 3 serial device created (i.e. /dev/ttyUSB2) with a baud of 115200. This can be useful for seeing the IP address assigned by the DHCP server.
