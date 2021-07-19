# HiFive Unmatched сборка бутов

## Сборка

$ git submodule update --init --recursive
$ make kernel

Результирующие файлы:

```
build-linux/arch/riscv/boot/Image.gz
build-linux/arch/riscv/boot/dts/sifive/hifive-unmatched-a00.dtb
```

## toolchain

тулчейн (https://github.com/riscv/riscv-gnu-toolchain) собирается вместе с проектом, полагается что у нас RV64GC с LP64D FLOAT ABI.

Можно просто положить (или подмонтировать) собранный тулчэйн на toolchain/riscv64-unknown-linux-gnu/

| The SiFive 7-series core IP options are 64-bit RISC-V RV64GC, RV64IMAC
| 
| G - Shorthand for the IMAFDZicsr Zifencei base and extensions, intended to represent a standard general-purpose ISA
| C - Standard Extension for Compressed Instructions
| M - Standard Extension for Integer Multiplication and Division
| A - Standard Extension for Atomic Instructions

## Полезная ссылка по процессу загрузки HiFive Unmatched

https://github.com/carlosedp/riscv-bringup
https://github.com/carlosedp/riscv-bringup/blob/master/unmatched/Readme.md

## Заметка про reboot

https://forums.sifive.com/t/reboot-command/4721/7
https://www.dialog-semiconductor.com/products/pmics?post_id=10052#tab-support_tab_content
https://github.com/riscv/opensbi/commits/master
