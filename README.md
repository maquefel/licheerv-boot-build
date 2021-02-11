# QEMU ARM template for cortex-a9

Unpack toolchain to toolchain directory:

https://developer.arm.com/-/media/Files/downloads/gnu-a/10.2-2020.11/binrel/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf.tar.xz?revision=d0b90559-3960-4e4b-9297-7ddbc3e52783&la=en&hash=985078B758BC782BC338DB947347107FBCF8EF6B

tools/qemu-arm-virt.sh -t nfs -s 192.168.1.110 -r /exports/rootfs/ -k build-linux/arch/arm/boot/zImage

qemu-system-arm -M vexpress-a9 -m 512M -kernel build-linux/arch/arm/boot/zImage -dtb build-linux/arch/arm/boot/dts/vexpress-v2p-ca9.dtb -append console=ttyAMA0 -nographic -serial mon:stdio
