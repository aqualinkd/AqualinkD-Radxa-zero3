# AqualinkD-Radxa-zero3

This tool is specifically for patching Radax OS Zero3 image for use with AqualinkD.

Reason for existence.
Official Radax ZERO 3
- Image will not boot. (see there repo linked below for explanation as to why)
- Image forces u-boot menu selection over UART2 serial. If you have a RS458 Hat connected at boot, this will stop image from booting.
- Image uses UART2 serial for debug terminal, this stops a RS485 hat from working.

This tool patches the standard Radax image to fix all of the above.  All patches can be seen in this repo so you ca see exactly what they are doing.  Quick explanation
- blacklist panfrost driver.
- disable u-boot menu selection (and fix bug in Radxa u-boot-update script)
- disable debug terminal on UART2
- enable UART2 
- Option to add WiFi connection if desired.

Radxa Zero3 OS repo.
https://github.com/radxa-build/radxa-zero3/releases/tag/b6

Simply download `patchImage.sh` and run it passing in the Radxa OS image to patch ie
```
./patchImage.sh radxa-zero3_debian_bullseye_cli_b6.img
```

The script can also download the image it you want. For an all inclusive command simply run the below in a linux terminal, answer a few questions and your image will be ready.

```
curl -sO https://raw.githubusercontent.com/sfeakes/AqualinkD-Radxa-zero3/refs/heads/main/patchImage.sh && chmod 755 patchImage.sh && sudo ./patchImage.sh
```

Once complete, burn image to CF or eMMC with your preferred tool.