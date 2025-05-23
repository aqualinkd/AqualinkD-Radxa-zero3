# AqualinkD-Radxa-zero3

This tool is specifically for patching Radax OS Zero3 image for use with AqualinkD.

# Reason for existence.

The official Radax OS (debian 11 bullseye) for ZERO 3 
- Image will not boot. (see there repo linked below for explanation as to why)
- Image forces u-boot menu selection over UART2 serial. If you have anything using pins 8 and 10 at boot (like a RS458 Hat connected), this will stop image from booting.
- Image uses UART2 serial for debug terminal, this stops a RS485 hat from working once booted.

This tool patches the standard Radax image to fix all of the above.  All patches can be seen in this repo so you ca see exactly what they are doing.  Quick explanation
- blacklist panfrost driver.
- disable u-boot menu selection (and fix bug in Radxa u-boot-update script)
- disable debug terminal on UART2
- enable UART2 
- Option to add WiFi connection if desired.

Radxa Zero3 OS repo.
https://github.com/radxa-build/radxa-zero3/releases/tag/b6

#
# To Use
This script will only work on a Linux device, ARM64 is preferred, but will work on AMD64,ARMHF,x86

To use, simply download `radxa-serial-patch` script and run it passing in the Radxa OS image to patch ie
```
./radxa-serial-patch radxa-zero3_debian_bullseye_cli_b6.img
```
The script will download any patches it needs from this repo, so no need to clone the repo if you don't want to.

## Even easier
The script can also download the appropriate image if you want. For an all inclusive command simply run the two commands below in a linux terminal, answer a few questions and your image will be ready.

```
cd ~ && mkdir radxa-os-patched && cd radxa-os-patched
```
```
curl -sO https://raw.githubusercontent.com/sfeakes/AqualinkD-Radxa-zero3/refs/heads/main/radxa-serial-patch && chmod 755 radxa-serial-patch && sudo ./radxa-serial-patch
```

Once complete, burn image to CF or eMMC with your preferred tool.

## Running in Container
Using a VM is fine, using a docker you will need to pass true root privileges.

ie
`docker run -it --privileged -v ~/Downloads:/tmp/Downloads ubuntu:latest`

In the container:
```
apt-get update
apt-get install patch curl xz-utils fdisk sudo -y
cd ~ && mkdir radxa-os-patched && cd radxa-os-patched
curl -sO https://raw.githubusercontent.com/sfeakes/AqualinkD-Radxa-zero3/refs/heads/main/radxa-serial-patch && chmod 755 radxa-serial-patch && sudo ./radxa-serial-patch
Answer script prompts
Copy the patched image out of the container into my host Downloads folder: cp ./radxa-zero3_debian_bullseye_cli_b6.img.xz /tmp/Downloads/
```

<!--
curl -fsSL https://raw.githubusercontent.com/aqualinkd/AqualinkD-Radxa-zero3/refs/heads/main/radxa_serial_patch.sh | sudo bash -s
-->

## System udates
Radxa recomends using `rsetup` over `apt upgrade`.  Both of which can kill any changes made by these patches.
If you do run either please check the following files BEFORE YOU REBOOT.

In most cases you can simply run the `radxa-serial-patch` again selecting `s` (for system) at the first prompt, this will patch a running system.
```
curl -sO https://raw.githubusercontent.com/aqualinkd/AqualinkD-Radxa-zero3/refs/heads/main/radxa-serial-patch && chmod 755 radxa-serial-patch && sudo ./radxa-serial-patch
```

Current known issues caused by `apt upgrade` or `rsetup -> update`

#### U-Boot menu.  
Runing `rsetup -> system -> system update` will enable u-boot menu again, you can disable by the following

look in `/boot/extlinux/extlinux.conf`, first few lines you should see the following
```
prompt 0 
timeout 0
```
If they are set back to the default `1` and `10`, then your system will not boot with anything attached to the serial pins 8 & 10, like a RS485 hat.  
To Fix Please modify `/usr/share/u-boot-menu/conf.d/radxa.conf`, set them both to 0 and run `u-boot-update`, then check `/boot/extlinux/extlinux.conf` and make sure that has the appropriate values.

#### WiFi
Running `apt upgrade` seems to disable wifi.  you can use `nmcli` to reenable.
