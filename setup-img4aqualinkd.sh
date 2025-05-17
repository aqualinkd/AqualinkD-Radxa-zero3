#!/bin/bash

REPO="https://api.github.com/repos/AqualinkD/AqualinkD"
OWN_REPO="https://api.github.com/repos/AqualinkD/AqualinkD-Radxa-zero3"
TEMP_INSTALL="/tmp/aqualinkd"

MOUNT="./tmp-mnt"
HOSTS="/etc/hosts"
HOSTNAME="/etc/hostname"

TRUE=0
FALSE=1

function msg() {
  echo -e "$@" >&2
}

function logerr() {
  echo "Error: $@" 1>&2;
}

function checkCommand() {
  if ! command -v $1 2>&1 >/dev/null; then
    logerr "Command '$1' not found, please check path or install if missing!"
    exit $FALSE
  fi

  return $TRUE
}


if command -v dpkg 2>&1 >/dev/null; then
  ARCH=$(dpkg --print-architecture)
  
  if [ "$ARCH" != "arm64" ]; then
     logerr "WARNING: Source OS $ARCH, this will only work on arm64"
     exit $FALSE
  fi
fi

if [ "$EUID" -ne 0 ]; then
  logerr "Please run as root"
  exit $FALSE
fi



function getOffset() {
  file=$1
  size=$(fdisk -lu $file | grep ${file}3 | awk '{print $2}')
  size=$(( $size * 512))

  if [ $? ]; then
    echo $size
    return
  fi

  echo $FALSE
  return
}

function mountImage() {
  image=$1

  if [ ! $1 ]; then
      logerr "Please pass valid image file example:-\n          $0 radxa-zero3_debian_bullseye_cli_b6.img.xz\n"
      exit $FALSE
  fi

  extension="${image##*.}"

  if [ ! -f $image ]; then
    logerr "No image file '$image'"
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
      logerr "Decompressing image file '$1' to '$image'"
      exit
    fi
  fi

  offset=$(getOffset $image)

  if [ ! -d "$MOUNT" ]; then
    mkdir "$MOUNT"
  fi

  mount -o loop,rw,sync,offset=$offset $image $MOUNT
  if [ ! $? ]; then
    logerr "Mounting image!"
    exit 1
  fi

  # second check for mount
  if [ ! -f "$MOUNT/$HOSTS" ]; then
    logerr "Doesn't look like image mounted correctly and/or incorrect image"
    cleanup
    exit 1
  fi
}


function download_install_aqualinkd {
  mkdir -p "$MOUNT/$TEMP_INSTALL"
  tar_url=$(curl -fsSL "$REPO/releases/latest" | grep -Po '"tarball_url": "\K.*?(?=")')
  if [[ "$tar_url" == "" ]]; then
    logerr "Find AqualinkD latest release failed"
    return "$FALSE"; 
  fi

  curl -fsSL "$tar_url" | tar xz --strip-components=1 --directory="$MOUNT/$TEMP_INSTALL"
  if [ $? -ne 0 ]; then 
    logerr "Download and extract $tar_url failed"
    return "$FALSE"; 
  fi

  if [ ! -f "$MOUNT/$TEMP_INSTALL/release/install.sh" ]; then
    logerr "Can not find install script $MOUNT/$TEMP_INSTALL/release/install.sh"
    return "$FALSE"
  fi

  # Get latest install script
  curl -fsSL -H "Accept: application/vnd.github.raw" "$REPO/contents/release/install.sh" -o $MOUNT/$TEMP_INSTALL/release/install.sh
  #cp /nas/data/Development/Raspberry/AqualinkD/release/install.sh $MOUNT/$TEMP_INSTALL/release/install.sh

  chmod u+x $MOUNT/$TEMP_INSTALL/release/install.sh
  chroot $MOUNT $TEMP_INSTALL/release/install.sh --arch arm64 nosystemd

  # Create sym link (ie systemctl enable aqualinkd)
  # Created symlink /etc/systemd/system/multi-user.target.wants/aqualinkd.service → /etc/systemd/system/aqualinkd.service.
  chroot $MOUNT ln -s /etc/systemd/system/aqualinkd.service /etc/systemd/system/multi-user.target.wants/aqualinkd.service

  rm -rf $MOUNT/$TEMP_INSTALL 

  return "$TRUE";
}


function cleanup() {
  umount $MOUNT > /dev/null 2>&1
  rmdir $MOUNT > /dev/null 2>&1
}

msg "Mounting $1"
mountImage $1

msg "Renaming host to aqualinkd"
sed -i 's/radxa-zero3/aqualinkd/g' $MOUNT/$HOSTS
sed -i 's/radxa-zero3/aqualinkd/g' $MOUNT/$HOSTNAME


# Install patchImage script
msg "Installing patchImage Script"
curl -fsSL -H "Accept: application/vnd.github.raw" "$OWN_REPO/contents/radxa_serial_patch.sh" -o $MOUNT/usr/local/bin/radxa_serial_patch

# Install auto-wifi-setip script
msg "Installing auto-wifi-setup Script"
curl -fsSL -H "Accept: application/vnd.github.raw" "$OWN_REPO/contents/wifi-mount/auto-wifi-connect.sh" -o $MOUNT/usr/local/bin/auto-wifi-connect
#cp /nas/data/Development/Raspberry/AqualinkD-Radxa-zero3/wifi-mount/auto-wifi-connect.sh $MOUNT/usr/local/bin/auto-wifi-connect
chmod u+x $MOUNT/usr/local/bin/auto-wifi-connect
chroot $MOUNT /usr/local/bin/auto-wifi-connect install


# Install AqualinkD
msg "Installing AqualinkD"
download_install_aqualinkd

#curl -fsSL https://install.aqualinkd.com | /usr/sbin/chroot $MOUNT bash -s -- latest