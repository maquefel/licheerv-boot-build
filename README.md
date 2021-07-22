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
https://dpaste.com/AAS5ZTN8W

## u-boot hijack

- PROM на ядре с нулевым mhartid инициализирует переферийные делители осциллятора
- PROM сканирует GPT партиции и ищет GUID 5B193300-FC78-40CD-8002-E86C45580B47
- PROM загружает U-Boot SPL в L2 LIM (scratchpad TCM L2) в начало 0x08000000
- U-Boot SPL помимо прочего инициализирует DDR и загружает u-boot.bin в 0x80200000, 
  opensbi в 0x80000000

```
CONFIG_SPL_TEXT_BASE=0x08000000
CONFIG_SPL_LOAD_FIT_ADDRESS=0x84000000
CONFIG_SYS_TEXT_BASE=0x80200000
CONFIG_SPL_OPENSBI_LOAD_ADDR=0x80000000
```
Интересный момент, что в оригинальном конфиге Unmatched фигурирует **CONFIG_SPL_LOAD_FIT_ADDRESS**,
хотя данный адрес используется только при загрузке **spl_ram**.

Дальнейшее нас пока не интересует. Из всего выше перечисленного можно сделать вывод, что возможна подмена 
образа U-Boot SPL и U-Boot, мы можем перехватить исполнение по адресу **CONFIG_SPL_TEXT_BASE**, 
загрузить свой U-Boot SPL, позволить U-Boot SPL произвести всю необходимую инициализацию и перехватить 
доступ по адресу **CONFIG_SPL_LOAD_FIT_ADDRESS**, загрузить по этому адресу U-Boot и продолжить исполнение.

Используется модифицированный конфиг **sifive-hifive-unmatched-fu740** и модифицированный файл 
**board/sifive/hifive_unmatched_fu740/spl.c**, ветка **riscv/unmatched-spl-ram**.

Лучше всего использовать fork OpenOCD для RISCV:
https://github.com/riscv/riscv-openocd

С конфигом openocd/openocd-unmatched.cfg

Функция для openocd:
```
proc load_uboot {} {
        reset init
        bp 0x08000000 0x1000 hw
        resume
        after 10000
        regexp {(0x[a-fA-F0-9]*)} [reg pc] pc
        echo "PC=$pc"
        load_image /home/user/nshubin/u-boot-spl.bin 0x8000000 bin
        rbp all
        wp 0x84000000 0x1000
        resume
        after 5000
        rwp 0x84000000
        load_image /home/user/nshubin/u-boot.itb 0x84000000 bin
        verify_image /home/user/nshubin/u-boot.itb 0x84000000 bin
        resume
}
```

Выхлоп:
```
U-Boot SPL 2021.01-00053-g8afbe20524-dirty (Jul 21 2021 - 04:00:02 +0000)
Trying to boot from RAM


U-Boot 2021.01-00053-g8afbe20524-dirty (Jul 21 2021 - 04:00:02 +0000)
```

Такая схема является рабочей до тех пор пока мы не трогаем оригинальный **u-boot-spl.bin** на MMC,
если он по каким-то причинам отсутствует или отсутствует sd-карта, поведение PROM пока остается 
неизвестным, но вполне возможно, что можно просто загрузить **u-boot-spl.bin** и передать управление на адрес.

## MSEL

```
> wp 0x00001000 0x4 
> wp
address: 0x00001000, len: 0x00000001, r/w/a: 2, value: 0x00000000, mask: 0xffffffff
> resume
> reg pc
pc (/64): 0x0000000000001008 -> (Reset Vector)
> resume
> reg pc
pc (/64): 0x00000000000101d8 -> (ZSBL)
```

Should be access from U-Boot SPL somewhere but i can't see it...
