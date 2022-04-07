#!/bin/bash
# Part of the SEALs project
# https://github.com/kaiwan/seals
# (c) kaiwanTECH
name=$(basename $0)
# Fetch the SEALs env
source ./build.config || {
	echo "${name}: ./build.config file missing or invalid? using defaults if they exist..."
	if [ -d ./images ]; then
		STG=./
	else
		echo "No ./images/ dir, aborting..."
		exit 1
	fi
}
[ -z "${STG}" -o ! -d "${STG}" ] && {
  echo "${name}: SEALS staging folder \"${STG}\" invalid, pl correct and retry..."
  echo "Tip: check/edit the build.config file"
  exit 1
}

SMP_EMU_MODE=1
if [ ${SMP_EMU_MODE} -eq 1 ]; then
    # Using the "-smp n,sockets=n" QEMU options lets us emulate n processors!
    # (can do this with n=4 for the ARM Cortex-A9)
     SMP_EMU="-smp 4,sockets=2"
fi

KGDB_MODE=0
[ $# -ne 1 ] && {
  echo "Usage: ${name} boot-option
 boot-option == 0 : normal console boot
 boot-option == 1 : console boot in KGDB mode (-s -S, waits for GDB client to connect)
                    Expect you've configured a kernel for KGDB and have the vmlinux handy;
If booting in KGDB mode, the emulator will wait (via the embedded GDB server within the kernel!);
you're expected to run ${CROSS_COMPILE}gdb <path/to/vmlinux> in another terminal window
and issue the
(gdb) target remote :1234
command to connect to the ARM/Linux kernel."
  exit 1
}
[ $1 -eq 1 ] && KGDB_MODE=1

KERN=${STG}/images/zImage
ROOTFS=${STG}/images/rfs.img
DTB=${STG}/images/vexpress-v2p-ca9.dtb

K_CMDLINE_BASE="console=ttyAMA0 rootfstype=ext4 root=/dev/mmcblk0 init=/sbin/init"
# uncomment the below line for 'debug'
#K_CMDLINE_DBG="initcall_debug ignore_loglevel debug crashkernel=16M"
# uncomment the below line for 'KGDB debug'
K_CMDLINE_KGDB="nokaslr"
K_CMDLINE="${K_CMDLINE_BASE} ${K_CMDLINE_DBG}"

RAM=512
[ ${KGDB_MODE} -eq 1 ] && K_CMDLINE="${K_CMDLINE} nokaslr"
RUNCMD="qemu-system-arm -m ${RAM} -M vexpress-a9 ${SMP_EMU} -kernel ${KERN} \
	-drive file=${ROOTFS},if=sd,format=raw \
	-append \"${K_CMDLINE}\" \
	-nographic -no-reboot \
	-audiodev id=none,driver=none"
[ -f ${DTB} ] && RUNCMD="${RUNCMD} -dtb ${DTB}"
[ ${KGDB_MODE} -eq 1 ] && RUNCMD="${RUNCMD} -s -S"
# qemu-system-arm --help
# -S              freeze CPU at startup (use 'c' to start execution)
# -s              shorthand for -gdb tcp::1234
echo

echo "Tips:
1. Qemu may not run properly if any other hypervisor is already running ! (like VirtualBox)!
2. To shutdown the emulated Qemu system, run the 'poweroff' command
"
[ ${KGDB_MODE} -eq 1 ] && echo "KGDB mode: *** we expect you to run ***
  \${CROSS_COMPILE}gdb <path/to/vmlinux>
in another terminal window and issue the
(gdb) target remote :1234
command to connect to the ARM/Linux kernel.
"
echo "About to execute:

${RUNCMD}

Now press [Enter] to continue or ^C to abort ..."
read x
eval ${RUNCMD}
