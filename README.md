# LINUX KERNEL GIT BISECT TEMPLATE

A template for bisecting kernel and for some test tasks on different kernel version.

## Requirements

- gcc ;)
- binutils
- expect (easily replaced for anything you want to use for tests)
- qemu

### Warning

kernel is highly dependable on gcc and bin-utils version, you can easily encounter situation when on large diversity of kernel versions, some kernel version won't build or build with suppressed warnings. With bin-utils see [x86: Treat R_X86_64_PLT32 as R_X86_64_PC32](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=b21ebf2fb4cd).

This is currently the only situation with bin-utils i am aware of - this results in modules are not being loaded.

## Explanatory note

### Concept

This a simple project template currently capable of building minimal kernel that can boot in  qemu-system-x86_64, consists of kernel, small busybox and pair of scripts and config files.

The kernel togather with initrafs is launched by qemu :
```
$ qemu-system-x86_64 -cpu host \
-kernel build-linux/arch/x86/boot/bzImage \
-initrd initramfs.cpio.xz \
-nographic -append "nokaslr console=ttyS0 root=/dev/ram" \
-enable-kvm -serial mon:stdio
```

Password has been scrambled and we are dropped directly to console after boot.

With this template a simple auto bisect [^git_auto_bisect] can be performed.

# Example

The problem is that **debugfs** path from **gpio-mockup** module has changed it's name, i.e :

Linux kernel **v5.3-rc2** :
```
# ls /sys/kernel/debug/
gpio-mockup
# ls /sys/kernel/debug/gpio-mockup
gpiochip1
```

Linux kernel **v4.14** :

```
# ls /sys/kernel/debug/
gpio-mockup-event
# ls /sys/kernel/debug/gpio-mockup-event
gpio-mockup-A
```

which breaks my puny tests with new kernels.

The test itself is extremely simple, we just need to load module and check if a particular directory and file apperead in **/sys/kernel/debug/** (see **tests/bisect.expect**).

```
$ git -C linux bisect start
$ git -C linux bisect good v4.14
$ git -C linux bisect bad 5.3-rc2
$ git -C linux bisect run ../bisect.sh
```

Gives us the first bad commit : **d51ee07a8de7d6d3f7738a5e74861133fd2d46a0**

and **git bisect log** gives us the following picture :

```
$ git bisect log
git bisect start
# good: [bebc6082da0a9f5d47a1ea2edc099bf671058bd4] Linux 4.14
git bisect good bebc6082da0a9f5d47a1ea2edc099bf671058bd4
# bad: [609488bc979f99f805f34e9a32c1e3b71179d10b] Linux 5.3-rc2
git bisect bad 609488bc979f99f805f34e9a32c1e3b71179d10b
# good: [798bba01b44b0ddf8cd6e542635b37cc9a9b739c] RDMA/core: Fail early if unsupported QP is provided
git bisect good 798bba01b44b0ddf8cd6e542635b37cc9a9b739c
# good: [e266ca36da7de45b64b05698e98e04b578a88888] Merge tag 'staging-5.1-rc1' of git://git.kernel.org/pub/scm/linux/kernel/git/gregkh/staging
git bisect good e266ca36da7de45b64b05698e98e04b578a88888
# bad: [318222a35bfb0ae9b5ff3e359a583463e6cfcd94] Merge branch 'akpm' (patches from Andrew)
git bisect bad 318222a35bfb0ae9b5ff3e359a583463e6cfcd94
# bad: [962d5ecca101e65175a8cdb1b91da8e1b8434d96] Merge tag 'regmap-v5.2' of git://git.kernel.org/pub/scm/linux/kernel/git/broonie/regmap
git bisect bad 962d5ecca101e65175a8cdb1b91da8e1b8434d96
# bad: [f47d633134f7033e3d0c667419d9f8afd69e308d] Merge tag 'tag-chrome-platform-for-v5.1' of git://git.kernel.org/pub/scm/linux/kernel/git/chrome-platform/linux
git bisect bad f47d633134f7033e3d0c667419d9f8afd69e308d
# good: [6c3f98faddc7f07981c5365ba2f45905ad75fcaa] Merge branch 'i2c/for-5.1' of git://git.kernel.org/pub/scm/linux/kernel/git/wsa/linux
git bisect good 6c3f98faddc7f07981c5365ba2f45905ad75fcaa
# bad: [2901752c14b8e1b7dd898d2e5245c93e531aa624] Merge tag 'pci-v5.1-changes' of git://git.kernel.org/pub/scm/linux/kernel/git/helgaas/pci
git bisect bad 2901752c14b8e1b7dd898d2e5245c93e531aa624
# bad: [1a29e857507046e413ca7a4a7c9cd32fed9ea255] Merge tag 'docs-5.1' of git://git.lwn.net/linux
git bisect bad 1a29e857507046e413ca7a4a7c9cd32fed9ea255
# bad: [3601fe43e8164f67a8de3de8e988bfcb3a94af46] Merge tag 'gpio-v5.1-1' of git://git.kernel.org/pub/scm/linux/kernel/git/linusw/linux-gpio
git bisect bad 3601fe43e8164f67a8de3de8e988bfcb3a94af46
# good: [cf2e8c544cd3b33e9e403b7b72404c221bf888d1] Merge tag 'mfd-next-5.1' of git://git.kernel.org/pub/scm/linux/kernel/git/lee/mfd
git bisect good cf2e8c544cd3b33e9e403b7b72404c221bf888d1
# good: [8fab3d713ca36bf4ad4dadec0bf38f5e70b8999d] Merge tag 'gpio-v5.1-updates-for-linus' of git://git.kernel.org/pub/scm/linux/kernel/git/brgl/linux into devel
git bisect good 8fab3d713ca36bf4ad4dadec0bf38f5e70b8999d
# bad: [9aac1e336c3ab3824f646224f4b2309b63c51668] Documentation: gpio: legacy: Don't use POLLERR for poll(2)
git bisect bad 9aac1e336c3ab3824f646224f4b2309b63c51668
# good: [0248baca03b8f188eccbb991bda2caec4c330975] Merge tag 'intel-gpio-v5.1-1' of git://git.kernel.org/pub/scm/linux/kernel/git/andy/linux-gpio-intel into devel
git bisect good 0248baca03b8f188eccbb991bda2caec4c330975
# bad: [e09313ce7ea1706d1642c7d5af103915e69fc6d0] gpio: mockup: change the signature of unlocked get/set helpers
git bisect bad e09313ce7ea1706d1642c7d5af103915e69fc6d0
# good: [cbf1e092f2d86e6d7cdb7f9ff8a333f52c826232] gpio: mockup: implement get_multiple()
git bisect good cbf1e092f2d86e6d7cdb7f9ff8a333f52c826232
# bad: [83336668b94eb44ecd78a0b7840e43f0859e05cb] gpio: mockup: change the type of 'offset' to unsigned int
git bisect bad 83336668b94eb44ecd78a0b7840e43f0859e05cb
# bad: [d51ee07a8de7d6d3f7738a5e74861133fd2d46a0] gpio: mockup: don't create the debugfs link named after the label
git bisect bad d51ee07a8de7d6d3f7738a5e74861133fd2d46a0
# first bad commit: [d51ee07a8de7d6d3f7738a5e74861133fd2d46a0] gpio: mockup: don't create the debugfs link named after the label
```

Well actually it's the first commit failing this one check:

```
send "ls /sys/kernel/debug/\r"

expect {
    "gpio-mockup-event" {}
    timeout  { puts "gpio-mockup-event not found"; exit 1 }
}
```

The other check is breaked by **2a9e27408e12de455b9fcf66b5d0166f2129579e** (we can of course edit our test and find it by bisect but i am too lazy - so i just looked at the nearest commits) :

```
send "ls /sys/kernel/debug/gpio-mockup-event/\r"

expect {
    "gpio-mockup-A" { puts "gpio-mockup-A found" }
    timeout  { puts "gpio-mockup-A not found"; exit 1 }
}
```

Let's find when this commit was accepted into main line and in which official version it was introduced [^merge_includes_commit].

We don't have all the branches and remotes in our linux repository so we will find commit by listing all between master and found commit selecting only **merge commits** [^merge_commits] and **ancestry chain** [^ancestry_chain] .

```
git log --pretty=oneline d51ee07a8de7d6d3f7738a5e74861133fd2d46a0..master --ancestry-path --merges
```

This one will gives all merges between out commit and master and let's get to the bottom (output truncated) :

```
3601fe43e8164f67a8de3de8e988bfcb3a94af46 Merge tag 'gpio-v5.1-1' of git://git.kernel.org/pub/scm/linux/kernel/git/linusw/linux-gpio
3dda927fdbaac926c50b550ccb51ed18c184468b Merge branch 'ib-qcom-ssbi' into devel
2f7db3c70fdfb22480a1b0aa734664fc256532f2 Merge tag 'gpio-v5.1-updates-for-linus-part-2' of git://git.kernel.org/pub/scm/linux/kernel/git/brgl/linux into devel
```

As we see (studying this commits of course) the last commit is merge from **git://git.kernel.org/pub/scm/linux/kernel/git/brgl/linux** to  **git://git.kernel.org/pub/scm/linux/kernel/git/linusw/linux-gpio** and first is actual merge from Linus Walleij (gpio subsystem maintainer) branch to Linus Torvalds master branch.

We can also use this script for finding merge commit [^git_find_merge] :

```
$ git-find-merge d51ee07a8de7d6d3f7738a5e74861133fd2d46a0 master
```

Let's find the first tagged version after this commit:

```
$ git name-rev --name-only 3601fe43e8164f67a8de3de8e988bfcb3a94af46
tags/v5.1-rc1~102
```

The **102** is number of commits between **3601fe43e8164f67a8de3de8e988bfcb3a94af46** and **v5.1-rc1** - let's check it [^first_parent] :

```
$ git -P log --pretty --oneline --first-parent --graph 3601fe43e8164f67a8de3de8e988bfcb3a94af46..v5.1-rc1 | wc -l
102
```

Everythin seems fine - so i am claiming the official version that broke our puny test is **v5.1-rc1** and **v5.0** is fine:

```
git describe 3601fe43e8164f67a8de3de8e988bfcb3a94af46
v5.0-8748-g3601fe43e816
```
[^git_auto_bisect]: https://lwn.net/Articles/317154/
[^git_find_merge]: https://github.com/rmandvikar/git-shell-setup/blob/next/bin/git-find-merge/
[^merge_commits]: https://git-scm.com/docs/git-log#Documentation/git-log.txt---merges
[^ancestry_chain]: https://stackoverflow.com/questions/36433572/how-does-ancestry-path-work-with-git-log/
[^first_parent]: https://marcgg.com/blog/2015/08/04/git-first-parent-log/
[^merge_includes_commit]: https://stackoverflow.com/questions/8475448/find-merge-commit-which-include-a-specific-commit/
```
```
