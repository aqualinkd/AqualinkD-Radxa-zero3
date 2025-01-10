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

To use, simply download `patchImage.sh` script and run it passing in the Radxa OS image to patch ie
```
./patchImage.sh radxa-zero3_debian_bullseye_cli_b6.img
```
The script will download any patches it needs from this repo, so no need to clone the repo if you don't want to.

## Even easier
The script can also download the appropriate image if you want. For an all inclusive command simply run the two commands below in a linux terminal, answer a few questions and your image will be ready.

```
cd ~ && mkdir radxa-os-patched && cd radxa-os-patched
```
```
curl -sO https://raw.githubusercontent.com/sfeakes/AqualinkD-Radxa-zero3/refs/heads/main/patchImage.sh && chmod 755 patchImage.sh && sudo ./patchImage.sh
```

Once complete, burn image to CF or eMMC with your preferred tool.