#!/bin/bash

if [ ! $1 ]; then
  echo -e "Please pass valid image file example:-\n          $0 radxa-zero3_debian_bullseye_cli_b6.img.xz\n"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi



mnt=./tmp-mnt
PANFROST="/etc/modprobe.d/panfrost.conf"
UBOOT_MENU="/usr/share/u-boot-menu/conf.d/radxa.conf"
UBOOT_UPDATE="/usr/sbin/u-boot-update"
KERNEL_CMDLINE="/etc/kernel/cmdline"
EXTLINUX_CONFIG="/boot/extlinux/extlinux.conf"

UART2="./tmp-mnt/boot/dtbo/rk3568-uart2-m0.dtbo"


function msg() {
  echo "$@" >&2
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
  file="$mnt/$1"

  # Let patch make the back file.
#  makeBackup "$file"
#  if [ ! $0 ]; then
#    error "Not patching file '$1'"
#    return
#  fi

  if [ ! -f "$1" ]; then
    error "File '$1' does not exist, can't patch"
    echo 1
    return
  fi

  filename=$(basename "$file")

  if [ -f ./"$filename".diff ]; then
    msg "using $filename.diff"
    #patch --ignore-whitespace -p0 < ./"$filename".diff
    patch --forward --ignore-whitespace --backup --suffix=.origional "$file" ./"$filename".diff
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
      chroot $mnt /usr/sbin/u-boot-update
    ;;
    *)
      msg "WARNING: Source OS is not amd64, forcing a extLinux configuration, please run 'u-boot-update' once system is running!"
      patchFile "$EXTLINUX_CONFIG"
    ;;
  esac
}

function createWiFi() {
  read -p "WiFi SSID :" wifissid
  read -p "WiFi Password :" wifipasswd

  wififile="$mnt/etc/NetworkManager/system-connections/$wifissid.nmconnection"

cat << EOF > "$wififile" 
[connection]
id=$wifissid
type=wifi
interface-name=wlan0
permissions=

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

 msg "Created rudimentary WiFi config '$wififile', if it doesn't work, please delete file and use rsetup or nmcli to configure WiFi"
}


########################################################
#                    main                              #
########################################################


checkCommand mount
checkCommand awk 
checkCommand chroot
checkCommand patch
checkCommand dpkg



image=$1

extension="${image##*.}"

if [ ! -f $image ]; then
  error "No image file '$image'"
  exit
fi

if [ "$extension" == "xz" ]; then
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

mount -o loop,rw,sync,offset=$offset $image $mnt
if [ ! $? ]; then
  error "Mounting image!"
  exit 1
fi

# second check for mount
if [ ! -f "$mnt/$PANFROST" ]; then
  error "Doesn't look like image mounted correctly and/or incorrect image"
  umount "$mnt"
  exit 1
fi

patchFile "$PANFROST"

# Don't seem to need to run this, would also only work on amr64 arch so leaving it out.
#chroot ./tmp-mnt /usr/sbin/update-initramfs -u


read -rep $'If you want to use standard UART2 for RS485/232 for GPIO pins 8 & 10 (ie for a RS485 Hat) then you need to enable it now.\
This will also disable U-Boot menu over serial connection & Radxa serial debugging.\
Do you want to enable UART2? (y/n) ' -n 1

if [[ $REPLY =~ ^[Yy]$ ]]; then
  enableUART2
fi

read -rep 'Do you want to create a WiFi connection? (y/n) ' -n 1
if [[ $REPLY =~ ^[Yy]$ ]]; then
  createWiFi
fi

umount $mnt
rmdir $mnt

exit



#makeBackup "$PANFROST"

# Patch panfrost
#patch --ignore-whitespace -p0 <<'EOF'
#--- ./tmp-mnt/etc/modprobe.d/panfrost.conf      2024-01-04 07:27:44.000000000 +0000
#+++ ./tmp-mnt/etc/modprobe.d/panfrost.conf      2025-01-08 15:46:54.864235383 +0000
#@@ -8,4 +8,4 @@
# # Uncomment the following line and comment above lines
# # to use mali driver for GPU instead
# # You will have to install desktop from vendor repo
#-#blacklist     panfrost
#+blacklist      panfrost
#EOF
#
#chroot ./tmp-mnt /usr/sbin/update-initramfs -u


exit

# Diff were created with below
# diff -Naur ./tmp-mnt/etc/modprobe.d/panfrost.conf ./panfrost.conf > panfrost.conf.diff

fdisk -lu ./radxa-zero3_cli.img

offset = start from above * 512

sudo mount -o loop,offset=348127232 radxa-zero3_cli.img /mnt

1) Boot their full OS version from CF or eMMC,  
2) make a CF card with the CLI version.   
3) Attach the CF card to a USB port (with USB CF card reader), and mount the CF card / 3rd partition only (so usually /dev/sda3)
3) edit file  <CF-card-root>/etc/modprobe.d/panfrost and uncomment line "blacklist       panfrost”
3) run command.  sudo chroot  <CF-card-root> update-initramfs -u


Enable uart at boot.
https://docs.radxa.com/en/zero/zero3/os-config/rsetup

Enable uart2
rename
./tmp-mnt/boot/dtbo/rk3568-uart2-m0.dtbo.disabled

Boot issue

In file prompt and timeout have to be 0
/boot/extlinux/extlinux.conf
prompt 0 
timeout 0

Need to modify to set values
/usr/share/u-boot-menu/conf.d/radxa.conf

AND change script 
/usr/sbin/u-boot-update to use prompt value (already uses timeout value)



chmod 600 on belof file
/etc/NetworkManager/system-connections/$wifissid.nmconnection

[connection]
id=$wifissid
uuid=fec2082a-6b20-4e34-b2f0-ddd593e7d776
type=wifi
interface-name=wlan0
permissions=

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

