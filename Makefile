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
	build-linux/arch/${TARGET_ARCH}/boot/Image \
	opensbi/build/platform/generic/firmware/fw_dynamic.bin \
	u-boot/u-boot.itb \
	${SYSROOT}/lib/modules \
	${SYSROOT}/etc/group \
	${SYSROOT}/etc/passwd \
	${SYSROOT}/etc/inittab \
	${SYSROOT}/init \
	${SYSROOT}/loginroot

# --- toolchain

riscv-gnu-toolchain/Makefile:	riscv-gnu-toolchain
	( cd riscv-gnu-toolchain && \
	./configure \
	--prefix=${TOOLCHAIN_PREFIX} \
	--with-arch=${TARGET_ARCH_AUX2} \
	--with-abi=${TARGET_FLOAT_ABI} )

${TARGET_CROSS_PREFIX}-gcc:	riscv-gnu-toolchain/Makefile
	make ${PARALLEL} -C riscv-gnu-toolchain linux

# --- opensbi

opensbi/build/platform/generic/firmware/fw_dynamic.bin: opensbi ${TARGET_CROSS_PREFIX}-gcc
	make -C opensbi CROSS_COMPILE=${TARGET_CROSS_PREFIX}- PLATFORM=generic FW_OPTIONS=0x2

.PHONY: opensbi-build opensbi-clean

opensbi-build:	opensbi/build/platform/generic/firmware/fw_dynamic.bin

opensbi-clean:
	-rm opensbi/build/platform/generic/firmware/fw_dynamic.bin

opensbi/build/platform/generic/firmware/fw_payload.elf:	opensbi ${TARGET_CROSS_PREFIX}-gcc build-linux/arch/${TARGET_ARCH}/boot/Image
	make -C opensbi CROSS_COMPILE=${TARGET_CROSS_PREFIX}- \
	PLATFORM=generic FW_OPTIONS=0x2 \
	FW_PAYLOAD_PATH=build-linux/arch/${TARGET_ARCH}/boot/Image

# --- u-boot

u-boot/.config:	configs/u-boot-defconfig configs/u-boot-env opensbi/build/platform/generic/firmware/fw_dynamic.bin
	cp configs/u-boot-defconfig $@
	make -C u-boot olddefconfig
	sed -i 's|^CONFIG_DEFAULT_ENV_FILE=.*|CONFIG_DEFAULT_ENV_FILE="../configs/u-boot-env"|g' $@

u-boot/u-boot.itb:	u-boot u-boot/.config
	OPENSBI=${CURDIR}/opensbi/build/platform/generic/firmware/fw_dynamic.bin \
	make ${PARALLEL} -C u-boot ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS}- all V=1

.PHONY: build-uboot

build-uboot:	u-boot/u-boot.itb

# --- kernel

build-linux/arch/${TARGET_ARCH}/configs:
	mkdir -p $@

.PHONY: kernel .build-kernel

build-linux/arch/${TARGET_ARCH}/configs/hifive_unmatched_defconfig: | build-linux/arch/${TARGET_ARCH}/configs configs/hifive_unmatched_defconfig
	cp configs/hifive_unmatched_defconfig $@

.build-kernel:
	make ${PARALLEL} -C build-linux ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- V=1

build-linux/.config:   | build-linux/arch/${TARGET_ARCH}/configs/hifive_unmatched_defconfig
	make ARCH=${TARGET_ARCH} -C ${KERNEL_TREE} O=${CURDIR}/build-linux hifive_unmatched_defconfig

build-linux/arch/${TARGET_ARCH}/boot/Image: linux build-linux/.config ${TARGET_CROSS_PREFIX}-gcc
	make ${PARALLEL} -C build-linux ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- V=1

kernel:	build-linux/arch/${TARGET_ARCH}/boot/Image

.PHONY: .install-modules

${SYSROOT}/lib/modules:	build-linux/arch/${TARGET_ARCH}/boot/Image
	make ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- ${PARALLEL} -C build-linux INSTALL_MOD_PATH=${SYSROOT} INSTALL_MOD_STRIP=1 modules_install

.install-modules: ${SYSROOT}/lib/modules ${SYSROOT}/.mount-stamp

# --- perf-tools

build-linux/tools/perf:
	mkdir -p $@

build-linux/tools/perf/perf:  build-linux/tools/perf
	LDFLAGS="-static" make -C linux/tools/perf/ O=build-linux/tools/perf ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS_PREFIX}-

${SYSROOT}/usr/bin/perf:      build-linux/tools/perf/perf
	make -C linux/tools/perf/ O=build-linux/tools/perf DESTDIR=${SYSROOT} iARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- install 

.PHONY: .perf-tools

.perf-tools: ${SYSROOT}/usr/bin/perf

clean::
	-make ${PARALLEL} -C build-linux clean
	-make ${PARALLEL} -C ${KERNEL_TREE} mrproper
	-rm -rf ${SYSROOT}/lib/modules

distclean::
	-rm -rf build-linux

# --- klibc
# Author: Petr Ovchenkov <ptr@void-ptr.info>
# copied from git://void-ptr.info/continuous-toolchain.git Makefile

TARGET_ARCH_KLIBC ?= $(TARGET_ARCH_AUX)
SYSROOT_INITRAMFS ?= ${CURDIR}/${TARGET_OS}-initramfs
TOOLCHAIN_KLIBC   ?= ${CURDIR}/toolchain-klibc-${TARGET_CROSS}

klibc/linux/include/linux/stddef.h:
	make -C linux ARCH=${TARGET_ARCH_AUX} INSTALL_HDR_PATH=${CURDIR}/klibc/linux headers_install
	find klibc/linux \( -name .install -o -name ..install.cmd \) -delete

klibc/.config:	klibc/defconfig
	cp $< $@

klibc/usr/klibc/libc.so:	klibc/.config klibc/linux/include/linux/stddef.h
	make -C klibc \
	CROSS_COMPILE=${TARGET_CROSS_PREFIX}- \
	KLIBCARCH=$(TARGET_ARCH_KLIBC) \
	INSTALLROOT=${TOOLCHAIN_KLIBC} \
	CPU_ARCH=${TARGET_ARCH_AUX2} \
	CPU_TUNE=${TARGET_CPU} \
	V=1

${TOOLCHAIN_KLIBC}/usr/lib/klibc/lib/libc.so:   klibc/usr/klibc/libc.so
	make -C klibc \
	CROSS_COMPILE=${TARGET_CROSS_PREFIX}- \
	KLIBCARCH=$(TARGET_ARCH_KLIBC) \
	INSTALLROOT=${TOOLCHAIN_KLIBC} \
	CPU_ARCH=${TARGET_ARCH_AUX2} \
	CPU_TUNE=${TARGET_CPU} \
	V=1 \
	install
	sed -i -e '/^$$prefix/ s|"|"${TOOLCHAIN_KLIBC}/|' \
	  ${TOOLCHAIN_KLIBC}/usr/bin/klcc

.PHONY: .build-klibc

.build-klibc: ${TOOLCHAIN_KLIBC}/usr/lib/klibc/lib/libc.so

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
	mkdir $@

busybox/configs/unmatched_defconfig:	configs/busybox/unmatched_busybox_config
	cp $< $@

build-busybox/.config:	busybox/configs/unmatched_defconfig | build-busybox
	make -C busybox O=../build-busybox ARCH=${TARGET_ARCH_AUX} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- unmatched_defconfig

build-busybox/busybox:	build-busybox/.config
	make -C build-busybox ${PARALLEL} ARCH=${TARGET_ARCH_AUX} CROSS_COMPILE=${TARGET_CROSS_PREFIX}- V=1

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

build-image-clean:	initramfs/ | build-image
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

# --- qemu

build-qemu:
	mkdir -p $@

build-qemu/Makefile:	qemu/configure build-qemu
	(cd build-qemu && \
	../qemu/configure \
	--target-list="riscv64-softmmu")

build-qemu/qemu-system-riscv64:	build-qemu/Makefile
	make -C build-qemu ${PARALLEL}
