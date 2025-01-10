#!/bin/bash

VERSION=0.1

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi


MOUNT="./tmp-mnt"

PANFROST="/etc/modprobe.d/panfrost.conf"
UBOOT_MENU="/usr/share/u-boot-menu/conf.d/radxa.conf"
UBOOT_UPDATE="/usr/sbin/u-boot-update"
KERNEL_CMDLINE="/etc/kernel/cmdline"
EXTLINUX_CONFIG="/boot/extlinux/extlinux.conf"

UART2="./tmp-mnt/boot/dtbo/rk3568-uart2-m0.dtbo"


function msg() {
  echo -e "$@" >&2
}

function error() {
  echo "ERROR: $@" 1>&2;
}

function checkCommand() {
  if ! command -v $1 2>&1 >/dev/nul; then
    error "Command '$1' not found, please check path or install if missing!"
    exit 1
  fi
}

function downloadImage() {
  msg "Downloading Image"
  curl -LfO https://github.com/radxa-build/radxa-zero3/releases/download/b6/radxa-zero3_debian_bullseye_cli_b6.img.xz
           

  echo "radxa-zero3_debian_bullseye_cli_b6.img.xz"
}

function getOffset() {
  file=$1
  size=$(fdisk -lu $file | grep ${file}3 | awk '{print $2}')
  size=$(( $size * 512))

  if [ $? ]; then
    echo $size
    return
  fi

  echo 1
  return
}

function makeBackup() {
  if [ ! -f "$1" ]; then
    error "File '$1' does not exist"
    echo 1
    return
  fi

  if [ ! -f "$1".origional ]; then
    cp "$1" "$1".origional
  else
    msg "File '$1.origional' already exists, not making backup"
  fi

  echo 0
  return
}

function patchFile() {
  file="$MOUNT/$1"

#  Let patch make the back file.
#  makeBackup "$file"
#  if [ ! $0 ]; then
#    error "Not patching file '$1'"
#    return
#  fi

#  if [ ! -f "$1" ]; then
#    error "File '$1' does not exist, can't patch"
#    return
#  fi

  filename=$(basename "$file")
  
  # Try to download if missing
  if [ ! -f ./"$filename".diff ]; then
    msg "Downloading patch for '$filename'"
    curl --fail --silent --show-error "https://raw.githubusercontent.com/sfeakes/AqualinkD-Radxa-zero3/main/$filename.diff" -o ./"$filename".diff 1>&2
  fi

  if [ -f ./"$filename".diff ]; then
    msg "using $filename.diff"
    #patch --ignore-whitespace -p0 < ./"$filename".diff
    patch --forward --ignore-whitespace --backup --suffix=.origional "$file" ./"$filename".diff 1>&2
  else
    error "No diff file '$filename.diff'"
  fi
}

function enableUART2() {
  patchFile "$UBOOT_MENU"
  patchFile "$UBOOT_UPDATE"
  patchFile "$KERNEL_CMDLINE"
# rename
  if [ ! -f "$UART2" ]; then
    if [ -f "$UART2".disabled ]; then
      mv "$UART2".disabled "$UART2"
    else
      error "Can't find '$UART2' ($UART2.disables)"
    fi
  fi

  # If we are in amd64 arch, we can run u-boot-update, if not force it manually
  ARCH=$(dpkg --print-architecture)
  case $ARCH in 
    arm64)
      chroot $MOUNT /usr/sbin/u-boot-update
      echo 0
    ;;
    *)
      msg "WARNING: Source OS is not amd64, forcing a extLinux configuration, please run 'u-boot-update' once system is running!"
      patchFile "$EXTLINUX_CONFIG"
      echo 1
    ;;
  esac

  return
}

function createWiFi() {
  # create SSID if we can
  if command -v openssl 2>&1 >/dev/nul; then
    uuid=$(openssl rand -hex 16)
    wifiuuid="uuid="${uuid:0:8}-${uuid:8:4}-${uuid:12:4}-${uuid:16:4}-${uuid:20:12}
  else
    wifiuuid=""
  fi

  read -p "WiFi SSID :" wifissid
  read -p "WiFi Password :" wifipasswd

  wififile="$MOUNT/etc/NetworkManager/system-connections/$wifissid.nmconnection"

cat << EOF > "$wififile" 
[connection]
id=$wifissid
type=wifi
interface-name=wlan0
permissions=
$wifiuuid

[wifi]
mac-address-blacklist=
mode=infrastructure
ssid=$wifissid

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$wifipasswd

[ipv4]
dns-search=
method=auto

[ipv6]
addr-gen-mode=stable-privacy
dns-search=
method=auto

[proxy]
EOF

 chmod 600 "$wififile"

 msg "\nCreated rudimentary WiFi config '$wififile',\nif it doesn't work, please delete file and use rsetup or nmcli to configure WiFi"
}

function cleanup() {
  # Check if mounted and unmount, blindly unmount and hide any errors
  umount $MOUNT > /dev/null 2>&1
  rmdir $MOUNT > /dev/null 2>&1
}

########################################################
#                    main                              #
########################################################

is_zipped=0
showWifi=0
showUbootupdate=0
showInitramfs=0

checkCommand mount
checkCommand awk 
checkCommand chroot
checkCommand patch
checkCommand dpkg
checkCommand curl
#checkCommand xz

image=$1

if [ ! $1 ]; then
  read -rep 'No immage passed on command line, do you want to downlod Radxa-zero3 image? (y/n) ' -n 1
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    image=$(downloadImage)
  else
    echo -e "Please pass valid image file example:-\n          $0 radxa-zero3_debian_bullseye_cli_b6.img.xz\n"
    exit 1
  fi
fi

extension="${image##*.}"

if [ ! -f $image ]; then
  error "No image file '$image'"
  exit
fi

if [ "$extension" == "xz" ]; then
  checkCommand xz
  is_zipped=1
  msg "Decompressing $image"
  xz --decompress "$image"
  # Remove extension .xz
  image="${image%.*}"
  # Check it decompressed and file is there
  if [ ! -f $image ]; then
    error "Decompressing image file '$1' to '$image'"
    exit
  fi
fi

offset=$(getOffset $image)

# offset should = 348127232 for this image.
if [ $offset -ne 348127232 ]; then
  msg "$image does not look like radxa-zero3_debian_bullseye_cli_b6"

  if [ $offset -gt 512 ]; then
    read -p "Are you sure you want to continue? (y/n) " -n 1 -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      exit 0
    fi
  else
    exit 1
  fi
fi

if [ ! -d "$MOUNT" ]; then
  mkdir "$MOUNT"
fi

mount -o loop,rw,sync,offset=$offset $image $MOUNT
if [ ! $? ]; then
  error "Mounting image!"
  exit 1
fi

# second check for mount
if [ ! -f "$MOUNT/$PANFROST" ]; then
  error "Doesn't look like image mounted correctly and/or incorrect image"
  cleanup
  exit 1
fi

patchFile "$PANFROST"

# Don't seem to need to run this, would also only work on amr64 arch so leaving it out.
#chroot ./tmp-mnt /usr/sbin/update-initramfs -u
# Since we did run command, show update message
showInitramfs=1


read -rep $'If you want to use standard UART2 for RS485/232 for GPIO pins 8 & 10 (ie for a RS485 Hat) then you need to enable it now.
This will also disable U-Boot menu over serial connection & Radxa serial debugging.
Do you want to enable UART2? (y/n) ' -n 1

if [[ $REPLY =~ ^[Yy]$ ]]; then
  showUbootupdate=$(enableUART2)
fi

read -rep 'Do you want to create a WiFi connection? (y/n) ' -n 1
if [[ $REPLY =~ ^[Yy]$ ]]; then
  createWiFi
  showWifi=1
fi

cleanup

if [ $is_zipped -eq 1 ]; then
  msg "Compressing '$image'"
  xz "$image"
  image="$image".xz
fi

msg "\nImage '$image' is ready, please burn to CF or load to eMMC"

msg "Once system new image has booted, run the following command(s)"
if [ $showUbootupdate -eq 1 ]; then
  msg "u-boot-update"
fi
if [ $showInitramfs -eq 1 ]; then
  msg "update-initramfs -u"
fi

msg ""

exit

