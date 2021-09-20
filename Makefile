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
	${SYSROOT}/lib/modules

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

.PHONY: opensbi-build

opensbi-build:	opensbi/build/platform/generic/firmware/fw_dynamic.bin

# --- u-boot

u-boot/.config:	opensbi/build/platform/generic/firmware/fw_dynamic.bin
	OPENSBI=${CURDIR}/opensbi/build/platform/generic/firmware/fw_dynamic.bin \
	make -C u-boot sifive_unmatched_defconfig

u-boot/u-boot.itb:	u-boot u-boot/.config
	OPENSBI=${CURDIR}/opensbi/build/platform/generic/firmware/fw_dynamic.bin \
	make ${PARALLEL} -C u-boot ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS}- all

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
