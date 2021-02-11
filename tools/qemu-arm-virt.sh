#!/bin/bash

PROGNAME=${0##*/}
PROGVERSION=0.0.0
IP=
KERNEL=build-linux/arch/arm/boot/zImage
DTB=
ROOTFSTYPE=
NFS=no
PLAN9=no
IMAGE=no
NFS_SERVER=
NFS_ROOT=
PLAN9_ROOTFS=
USB_IMAGE=
INITRD_IMAGE=
QEMU=qemu-system-arm

usage()
{
cat <<EO
        Usage: $PROGNAME [options]
               $PROGNAME --profile [profile] all

        Options:
EO

cat <<EO | column -s\& -t
      -h|--help & show this output
      -v|--version & show version information
      -i|--ip & specify remote ip address for serial port connection
      -k|--kernel & specify kernel path
      -t|--type & rootfs type (nfs, plan9, img)
      -s|--nfsserver & ip addr of nfs server
      -r|--nfsroot & path to nfs rootfs
      -p|--plan9root & path to plan9 rootfs
      -u|--usbimage & path to usbimage file partitioned same as internal storage
      -d|--initrd & path to initrd image
EO
}

var_exit_on_empty()
{
    if [ -z "$2" ]; then
        echo "Empty variable: $1"
        exit 1
    fi
    return 0
}

SHORTOPTS="hvi:k:t:s:r:p:u:d:"
LONGOPTS="help,version,ip:,kernel:,type:,nfsserver:,nfsroot:,plan9root:,usbimage:,initrd:"

ARGS=$(getopt -s bash --options $SHORTOPTS --longoptions $LONGOPTS --name $PROGNAME -- "$@" )

eval set -- "$ARGS"

while true; do
   case $1 in
      -h|--help)
         usage
         exit 0
         ;;
      -v|--version)
         echo "$PROGVERSION"
         exit 0
         ;;
      -i|--ip)
         shift
         IP=$1
         shift
         ;;
      -k|--kernel)
         shift
         KERNEL=$1
         shift
         ;;
      -t|--type)
         shift
         ROOTFSTYPE=$1
         shift
         ;;
      -s|--nfsserver)
         shift
         NFS_SERVER=yes
         shift
         ;;
      -r|--nfsroot)
         shift
         NFS_ROOT=$1
         shift
         ;;
      -p|--plan9root)
         shift
         PLAN9_ROOTFS=$1
         shift
         ;;
      -u|--usbimage)
         shift
         USB_IMAGE=$1
         shift
         ;;
      -d|--initrd)
         shift
         INITRD_IMAGE=$1
         shift
         ;;
      --)
         shift
         break
         ;;
      *)
         break
         ;;
   esac
done

var_exit_on_empty KERNEL $KERNEL
echo "Using kernel: $KERNEL"

ROOT_OPTS=
ROOTCMD_LINE="console=ttyAMA0 init=/linuxrc"

var_exit_on_empty ROOTFSTYPE $ROOTFSTYPE
case "${ROOTFSTYPE}" in
  nfs)
    # nfs
    var_exit_on_empty NFS_SERVER $NFS_SERVER
    var_exit_on_empty NFS_ROOT $NFS_ROOT
    echo "Using nfs server: ${NFS_SERVER}"
    echo "Using nfsroot: ${NFS_ROOT}"
    ROOTCMD_LINE="${ROOTCMD_LINE} nfsroot=${NFS_SERVER}:${NFS_ROOT},nfsvers=3 rw ip=dhcp"
    ;;
  plan9)
    # plan9
    var_exit_on_empty PLAN9_ROOTFS $PLAN9_ROOTFS
    ROOT_OPTS="-fsdev local,id=roothd,path=$PLAN9_ROOTFS,security_model=none \\ \n \
               -device virtio-9p-pci,fsdev=roothd,mount_tag=/dev/root \\ \n"
    ROOTCMD_LINE="${ROOTCMD_LINE} root=/dev/root rootfstype=9p rootflags=trans=virtio"
    ;;
  img)
    # img
    ROOT_OPTS="-hda /dev/loop1 \\ \n"
    ROOTCMD_LINE="${ROOTCMD_LINE} root=/dev/sda1 rootfstype=ext3 rw"
    ;;
  initrd)
    # initrd
    var_exit_on_empty INITRD_IMAGE $INITRD_IMAGE
    ROOT_OPTS="-initrd ${INITRD_IMAGE} \\ \n"
    ROOTCMD_LINE="${ROOTCMD_LINE} root=/dev/ram0 rw"
    ;;
  *)
    $dolog "No known rootfstype detected..."
    exit 1
    ;;
esac

echo "Using rootfstype : $ROOTFSTYPE"

USB_DISK=
if [ ! -z "$USB_IMAGE" ]; then
  echo "Using flash image: $USB_IMAGE"
  USB_DISK="-drive if=none,id=stick,file=$USB_IMAGE,format=raw \\ \n"
fi

set -x

echo ${ROOTCMD_LINE}

OPTS="qemu-system-arm -M virt -m 512M"
OPTS="${OPTS} -kernel ${KERNEL} -append '${ROOTCMD_LINE}'"
OPTS="${OPTS} -initrd ${INITRD_IMAGE}"
OPTS="${OPTS} -append '${ROOTCMD_LINE}'"
OPTS="${OPTS} -nographic -serial mon:stdio"

eval "$OPTS"
"$@"
