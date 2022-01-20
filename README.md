# Sipeed LicheeRV - Nezha CM C906 building boots

Alternate to official instruction small BSP building.

The current official guide seems very uncomfortable : 

- some software PhoenixCard (Windows) is need and it works crappy
- minimum size for sdcard is 16G
- large SDK >10G which is required to download from mega

so we ended up with alternate one.

Thanks to Samuel Holland <samuel@sholland.org> to make this thing easy.

## Contents

- boot0 : zsbl (zero stage boot loader) that is used instead of u-boot SPL temporary
- opensbi : mostly mainline with small changes for Allwinner D1
- u-boot : very hacked but really better than official one
- linux : a solid work on the top of v5.15 (almost the most recent)
- riscv-gnu-toolchain : linux toolchain (currently used, can be replaced with Xuantie toolchain)

I've disabled emac and spi-nand in separate dts currently, they are no harm but still useless for 
LicheeRV RV Dock and pure LicheeRV, for 86 Panel a modification is also required, so we use
sun20i-d1-nezha-lichee.dts instead of sun20i-d1-nezha.dts for now.

## Build

Install the prerequisites for the riscv-gnu-toolchain:

https://github.com/riscv-collab/riscv-gnu-toolchain/tree/f640044a947afb39c78b96fa1ba1db8aa31b1d89#prerequisites

You don't have to do any other steps except the prerequisites.

Fetch all submodules:

```
$ git submodule update --init --recursive
```

Bundled toochain:
```
$ make
```

### External toochain

Either provide TARGET_CROSS_PREFIX:

```
$ TARGET_CROSS_PREFIX=riscv64-unknown-linux-gnu make
```

Or simply nail it down in Makefile before `ifndef TARGET_CROSS_PREFIX`:

```
TARGET_CROSS_PREFIX=riscv64-unknown-linux-gnu

ifndef TARGET_CROSS_PREFIX
TARGET_CROSS_PREFIX = ${TOOLCHAIN_PREFIX}/bin/${TARGET_CROSS}
EXTERNAL_CROSS = 0
else
TARGET_CROSS_PATH := $(shell dirname $$(which $${TARGET_CROSS_PREFIX}-gcc))
TARGET_CROSS_PREFIX := ${TARGET_CROSS_PATH}/${TARGET_CROSS_PREFIX}
EXTERNAL_CROSS = 1
endif

$ make
```

## Quick deploy

After make we will need the following files:

- sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin
- u-boot.toc1
- u-boot/arch/riscv/dts/sun20i-d1-nezha-lichee.dtb
- build-linux/arch/riscv/boot/Image.gz
- initramfs.img.gz

Example of making a card (assuming card is /dev/sdd and empty) :

```
# parted /dev/sdd --script mklabel gpt
# parted /dev/sdd --script mkpart primary ext2 40MiB 100MiB
# parted /dev/sdd --script mkpart primary ext4 100MiB 100%
# mkfs.ext2 /dev/sdd1 # partion with kernel, dtb, initramfs
# mkfs.ext4 /dev/sdd2 # partition for rootfs 
# mount /dev/sdd1 /mnt/sdcard/
# cp build-linux/arch/riscv/boot/Image.gz /mnt/sdcard/
# cp u-boot/arch/riscv/dts/sun20i-d1-nezha-lichee.dtb /mnt/sdcard/ # we use dtb from u-boot !
# cp initramfs.img.gz /mnt/sdcard/
# umount /mnt/sdcard
# dd if=sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin of=/dev/sdd bs=8192 seek=16
# dd if=u-boot.toc1 of=/dev/sdd bs=512 seek=32800 # large offset thats why we make first partion on 40 MiB
```

U-boot commands (i haven't put a u-boot env yet - have to decide what i really need) : 

```
> load mmc 0:1 ${kernel_addr_r} Image.gz
> load mmc 0:1 ${ramdisk_addr_r} initramfs.img.gz
> load mmc 0:1 ${fdt_addr_r} sun20i-d1-nezha-lichee.dtb
> setenv bootargs "earlycon=sbi console=ttyS0,115200n8 root=/dev/ram0 rw rdinit=/init"
> booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
```

Enjoy!

## Bibliography

- https://linux-sunxi.org/Allwinner_Nezha - that's the first place to visit
- https://whycan.com/t_6440.html
- https://whycan.com/t_7711_2.html
- https://wiki.sipeed.com/hardware/zh/lichee/RV/flash.html
- https://github.com/T-head-Semi/riscv-aosp
