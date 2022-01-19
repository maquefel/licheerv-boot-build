# -*- GNUMakefile -*-
# Requirements:
#  /bin/bash as SHELL

export SHELL = /bin/bash

all:    world

TOOLCHAIN ?= toolchain

include ${TOOLCHAIN}/target.mak

ifndef TOOLCHAIN_PREFIX
TOOLCHAIN_PREFIX := ${CURDIR}/toolchain/${TARGET_CROSS}
endif

ifndef TARGET_CROSS_PREFIX
TARGET_CROSS_PREFIX = ${TOOLCHAIN_PREFIX}/bin/${TARGET_CROSS}
endif

ifndef PARALLEL
ifndef NOPARALLEL
PARALLEL := -j$(shell echo $$((`nproc` + 2)))
endif
endif

KERNEL_TREE ?= ${CURDIR}/linux
SYSROOT ?= ${CURDIR}/initramfs

export PATH := ${TOOLCHAIN_PREFIX}/bin:${PATH}

${SYSROOT}:
	mkdir -p $@

${SYSROOT}/.mount-stamp:	| ${SYSROOT}
	touch $@

.PHONY: world

world: \
	u-boot.toc1 \
	build-linux/arch/${TARGET_ARCH}/boot/Image.gz \
	initramfs.img.gz

# --- toolchain

riscv-gnu-toolchain/Makefile:	riscv-gnu-toolchain
	( cd riscv-gnu-toolchain && \
	./configure \
	--prefix=${TOOLCHAIN_PREFIX} \
	--with-arch=${TARGET_ARCH_AUX2} \
	--with-abi=${TARGET_FLOAT_ABI} )

${TARGET_CROSS_PREFIX}-gcc:	riscv-gnu-toolchain/Makefile
	make ${PARALLEL} -C riscv-gnu-toolchain linux

.PHONY: build-toolchain
build-toolchain:	${TARGET_CROSS_PREFIX}-gcc

# --- boot0

sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin:	${TARGET_CROSS_PREFIX}-gcc
	make -C sun20i_d1_spl CROSS_COMPILE=${TARGET_CROSS_PREFIX}- p=sun20iw1p1 mmc

.PHONY: .build-boot0

.build-boot0:	sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin

# --- opensbi

opensbi/build/platform/generic/firmware/fw_dynamic.bin:	opensbi	${TARGET_CROSS_PREFIX}-gcc
	make -C opensbi CROSS_COMPILE=${TARGET_CROSS_PREFIX}- PLATFORM=generic FW_PIC=y FW_OPTIONS=0x2

.PHONY: .build-opensbi

.build-opensbi:	opensbi/build/platform/generic/firmware/fw_dynamic.bin

clean::
	make -C opensbi clean

# --- u-boot

u-boot/.config:	u-boot
	make -C u-boot nezha_defconfig

u-boot/u-boot-nodtb.bin:	u-boot u-boot/.config ${TARGET_CROSS_PREFIX}-gcc
	make ${PARALLEL} -C u-boot ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS}- all V=1

.PHONY: .build-uboot

.build-uboot:	u-boot/u-boot-nodtb.bin

clean::
	make -C u-boot clean

# --- TOC1

u-boot.toc1:	toc1/toc1.cfg  u-boot/u-boot-nodtb.bin opensbi/build/platform/generic/firmware/fw_dynamic.bin
	u-boot/tools/mkimage -T sunxi_toc1 -d toc1/toc1.cfg u-boot.toc1

.PHONY: .build-toc1

.build-toc1: u-boot.toc1

clean::
	-rm u-boot.toc1

# --- kernel

build-linux/arch/${TARGET_ARCH}/configs:
	mkdir -p $@

build-linux/arch/${TARGET_ARCH}/configs/licheerv_defconfig: | build-linux/arch/${TARGET_ARCH}/configs configs/linux/licheerv_defconfig
	cp configs/linux/licheerv_defconfig $@

build-linux/.config:	| build-linux
	make ARCH=${TARGET_ARCH} -C ${KERNEL_TREE} O=${CURDIR}/build-linux licheerv_defconfig

build-linux/arch/${TARGET_ARCH}/boot/Image.gz:	linux build-linux/.config ${TARGET_CROSS_PREFIX}-gcc
	make ${PARALLEL} -C build-linux ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- V=1

.PHONY: .build-linux

.build-linux:	build-linux/arch/${TARGET_ARCH}/boot/Image.gz

${SYSROOT}/lib/modules:	build-linux/arch/${TARGET_ARCH}/boot/Image
	make ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- ${PARALLEL} -C build-linux INSTALL_MOD_PATH=${SYSROOT} INSTALL_MOD_STRIP=1 modules_install

.PHONY: .install-modules

.install-modules: ${SYSROOT}/lib/modules ${SYSROOT}/.mount-stamp

clean::
	make -C build-linux clean

distclean::
	rm -rf build-linux

# --- initramfs

CREATE_DIRS := \
	/dev \
	/dev/pts \
	/boot \
	/etc \
	/home \
	/mnt \
	/opt \
	/proc \
	/root \
	/srv \
	/sys \
	/usr \
	/var \
	/var/log \
	/run \
	/tmp \
	/lib

$(patsubst %,${SYSROOT}%,${CREATE_DIRS}):	${SYSROOT}/.mount-stamp
	install -d -m 0755 $@

.PHONY: populate-dirs

populate-dirs:  | $(patsubst %,${SYSROOT}%,${CREATE_DIRS})

${SYSROOT}/etc/passwd:  etc/passwd ${SYSROOT}/.mount-stamp | ${SYSROOT}/etc
	install -m 644 $< $@

${SYSROOT}/etc/passwd:  etc/passwd ${SYSROOT}/.mount-stamp | ${SYSROOT}/etc
	install -m 644 $< $@

${SYSROOT}/etc/group:   etc/group ${SYSROOT}/.mount-stamp | ${SYSROOT}/etc
	install -m 644 $< $@

${SYSROOT}/etc/inittab: etc/inittab ${SYSROOT}/.mount-stamp | ${SYSROOT}/etc
	install -m 644 $< $@

${SYSROOT}/init:        scripts/init | ${SYSROOT}
	install -m 755 $< $@

${SYSROOT}/loginroot:   scripts/loginroot | ${SYSROOT}
	install -m 755 $< $@

# --- busybox

build-busybox:
	mkdir -p $@

busybox/configs/licheerv_defconfig:	configs/busybox/licheerv_busybox_config
	cp $< $@

build-busybox/.config:	busybox/configs/licheerv_defconfig | build-busybox
	make -C busybox O=../build-busybox licheerv_defconfig

build-busybox/busybox:	build-busybox/.config ${TARGET_CROSS_PREFIX}-gcc
	LDFLAGS="-static" make -C build-busybox ${PARALLEL} ARCH=${TARGET_ARCH_AUX} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- V=1

${SYSROOT}/bin/busybox:	build-busybox/busybox | populate-dirs
	make -C build-busybox ${PARALLEL} ARCH=${TARGET_ARCH_AUX} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- CONFIG_PREFIX=${SYSROOT} install
	rm -rf ${SYSROOT}/linuxrc

.PHONY: .install-busybox

.install-busybox : ${SYSROOT}/bin/busybox

clean::
	-make -C build-busybox ARCH=${TARGET_ARCH} clean

distclean::
	rm -rf build-busybox

# --- initramfs

initramfs: ${SYSROOT}/bin/busybox ${SYSROOT}/loginroot ${SYSROOT}/init ${SYSROOT}/etc/inittab ${SYSROOT}/etc/group ${SYSROOT}/etc/passwd populate-dirs

.PHONY: build-image-clean

build-image:
	mkdir -p $@

build-image-clean:	initramfs | build-image
	rm -rf build-image/rootfs
	mkdir build-image/rootfs
	(cd ${SYSROOT} && tar cf - . ) | (cd build-image/rootfs; tar xf - )
	rm -rf build-image/rootfs/usr/{include,share/doc,share/info}
	rm -rf build-image/rootfs/var/db/*
	rm -rf build-image/rootfs/var/lib/*
	rm -rf build-image/rootfs/var/log/*
	rm -rf build-image/rootfs/var/run/*
	rm -rf build-image/rootfs/usr/share/man
	rm -rf build-image/rootfs/usr/local/share/man
	rm -rf build-image/rootfs/usr/share/pkgconfig build-image/rootfs/usr/lib/pkgconfig
	rm -rf build-image/rootfs/usr/share/locale/{el,ko,sl,be,eo,bs,nb,pt,tr,ro,uk,it,hu,sv,id,kk,es,zh_CN,da,de,vi,pt_BR,nl,en_GB,ia,sq,sr,af,ru,pl,cs,tl,dz,sk,ja,nn,he,fr,zh_TW,km,gl,fi,eu,ga,lt,hr,bg,rw,ca,et,ne}
	rm -rf build-image/rootfs/etc/ssl/man
	find build-image/rootfs \( -name "*.a" -o -name "*.la" -o -name "*.o" \) -exec rm -rf {} \;
	rm -f build-image/rootfs/usr/bin/{strings,strip,ranlib,readelf,objdump,objcopy,nm,ld.gold,ld.bfd,ld}
	rm -f build-image/rootfs/usr/bin/{gdb,gdbserver,gprof,flex++,flex,c++filt,as,ar,addr2line}
	rm -f build-image/rootfs/usr/bin/{strace,strace-graph,strace-log-merge}
	rm -f build-image/rootfs/bin/udevadm
	rm -f build-image/rootfs/sbin/{udevd,udevadm}
	rm -rf build-image/rootfs/etc/udev
	rm -rf build-image/rootfs/lib/udev
	find build-image/rootfs -path build-image/rootfs/lib/modules -prune -o -type f -print | while read f; do file $$f | grep -q 'ELF 32-bit MSB' && { ${TARGET_CROSS_PREFIX}-strip -s -p $$f || true; } || true; done

initramfs.cpio:	build-image-clean
	(cd build-image/rootfs && find . -print0 | cpio --null -ov --format=newc > ../../initramfs.cpio)

clean::
	-rm -rf initramfs.cpio

distclean::
	-rm -rf ${SYSROOT}

# --- initramfs.img.gz

initramfs.img.gz:	initramfs.cpio u-boot/u-boot.itb
	u-boot/tools/mkimage -A riscv -O linux -T ramdisk -C gzip -d initramfs.cpio $@

clean::
	-rm initramfs.img.gz
