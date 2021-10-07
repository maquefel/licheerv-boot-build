#!/bin/bash

build-qemu/qemu-system-riscv64 -machine virt -cpu rv64,sscof=true -m 2G -nographic -bios opensbi/build/platform/generic/firmware/fw_jump.bin -kernel build-linux/arch/riscv/boot/Image \
-append "console=ttyS0 ip=dhcp root=/dev/nfs rootfstype=nfs nfsroot=192.168.1.110:rootfs,nfsvers=4.1" \
-netdev bridge,id=net0,helper=build-qemu/qemu-bridge-helper \
-device e1000,netdev=net0 \
-serial mon:stdio
