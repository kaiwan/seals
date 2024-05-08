#!/bin/bash
# Part of the SEALs project
# https://github.com/kaiwan/seals
# (c) kaiwanTECH
# Set Bash unofficial 'strict mode'; _really_ helps catch bugs
# ref: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

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
source ./common.sh || {
	echo "${name}: source failed! ./common.sh missing or invalid?"
	exit 1
}
color_reset

cd ${TOPDIR} || exit 1

SMP_EMU=""
if [ ${SMP_EMU_MODE} -eq 1 ]; then
    # Using the "-smp n,sockets=n" QEMU options lets us emulate n processors!
    # (can do this only for appropriate platforms)
     SMP_EMU="-smp 4,sockets=2"
fi

KGDB_MODE=0
[ $# -ne 1 ] && {
  echo "Usage: ${name} boot-option
 boot-option == 0 : normal console boot; use this unless you want a KGDB session
 boot-option == 1 : console boot in KGDB mode (-s -S, waits for GDB client to connect)
                    Expect you've configured a kernel for KGDB and have the vmlinux handy;
If booting in KGDB mode, the emulator will wait (via the embedded GDB server within the kernel!);
you're expected to run ${CXX}gdb <path/to/vmlinux> in another terminal window
and issue the
(gdb) target remote :1234
command to connect to the ARM/Linux kernel."
  exit 1
}
[ $1 -eq 1 ] && KGDB_MODE=1

echo "TIP:
*** If another hypervisor (like VirtualBox) is running, Qemu run with KVM support won't work properly ***
"
ShowTitle "
RUN: Running ${QEMUNAME} now ..."

# Device Tree Blob (DTB) pathname
DTB_BLOB_IMG=""
[[ ! -z "${DTB_BLOB}" ]] && {
	export DTB_BLOB_PATHNAME=${IMAGES_FOLDER}/${DTB_BLOB} # gen within kernel src tree
	DTB_BLOB_IMG=${IMAGES_FOLDER}/$(basename ${DTB_BLOB}) # within image folder
}

# TODO - when ARCH is x86[_64], use Qemu's --enable-kvm to give a big speedup!

# TODO : Networking
# ref: https://gist.github.com/extremecoders-re/e8fd8a67a515fee0c873dcafc81d811c#example-tap-network

RUNCMD=""
if [ "${ARCH}" = "arm" ]; then
   RUNCMD="${QEMUNAME} -m ${SEALS_RAM} -M ${ARM_PLATFORM_OPT} \
-cpu max ${SMP_EMU} -cpu ${CPU_MODEL} \
-kernel ${IMAGES_FOLDER}/zImage \
-drive file=${IMAGES_FOLDER}/rfs.img,if=sd,format=raw \
-append \"${SEALS_K_CMDLINE}\" -nographic -no-reboot"
   [ -f ${DTB_BLOB_PATHNAME} ] && RUNCMD="${RUNCMD} -dtb ${DTB_BLOB_PATHNAME}"

elif [ "${ARCH}" = "arm64" ]; then

	RUNCMD="${QEMUNAME} -m ${SEALS_RAM} -M ${ARM_PLATFORM_OPT} \
-cpu max ${SMP_EMU} -cpu ${CPU_MODEL} \
-kernel ${IMAGES_FOLDER}/Image.gz \
-drive file=${IMAGES_FOLDER}/rfs.img,format=raw,id=drive0 \
-append \"${SEALS_K_CMDLINE}\" -nographic -no-reboot"
	# no DTB for the 'dummy,virt' platform
#set -x
	#echo "DTB_BLOB_IMG = ${DTB_BLOB_IMG}"
	[[ -f ${DTB_BLOB_IMG} && -n "${DTB_BLOB_IMG}" ]] && RUNCMD="${RUNCMD} -dtb ${DTB_BLOB_IMG}"

elif [ "${ARCH_PLATFORM}" = "x86_64" ]; then

#	echo "SEALS_K_CMDLINE = ${SEALS_K_CMDLINE}"
	RUNCMD="${QEMUNAME} -M ${CPU_MODEL} -m ${SEALS_RAM} \
-cpu max ${SMP_EMU} \
-kernel ${IMAGES_FOLDER}/bzImage \
-drive file=${IMAGES_FOLDER}/rfs.img,format=raw,id=drive0 \
-append \"${SEALS_K_CMDLINE}\" \
-nographic -no-reboot"
	[[ ${USE_INITRAMFS} -eq 1 ]] && RUNCMD="${RUNCMD} -initrd ${IMAGES_FOLDER}/initrd.img"
fi

[[ -z "${RUNCMD}" ]] && {
	echo "${name}: FATAL: no run command defined, aborting..."
	exit 1
}

# Run it!
if [ ${KGDB_MODE} -eq 1 ]; then
	# KGDB/QEMU cmdline
	ShowTitle "Running ${QEMUNAME} in KGDB mode now ..."
	RUNCMD="${RUNCMD} -s -S"
	# qemu-system-xxx(1) :
	#  -S  Do not start CPU at startup (you must type 'c' in the monitor).
	#  -s  Shorthand for -gdb tcp::1234, i.e. open a gdbserver on TCP port 1234.
	aecho "
@@@@@@@@@@@@ NOTE NOTE NOTE @@@@@@@@@@@@
REMEMBER this qemu instance is run with the -S option: it *waits* for a GDB client to connect to it...

You are expected to run (in another terminal window):
$ ${CXX}gdb <path-to-${ARCH}-built-kernel-src-tree>/vmlinux  <-- built w/ -g
...
and then have GDB connect to the target kernel using
(gdb) target remote :1234
...
@@@@@@@@@@@@ NOTE NOTE NOTE @@@@@@@@@@@@"
fi

echo "${RUNCMD}" |tee -a ${LOGFILE_COMMON}
#echo "${RUNCMD}" > cmd1
#aecho "${RUNCMD}
#"
Prompt "Ok? (after pressing ENTER, give it a moment ...)

Also, please exit the Qemu VM by properly shutting down:
use the 'poweroff' command to do so.
(Worst case, typing Ctrl-a x (abruptly) shuts Qemu - and thus the guest platform - down).
"
# if we're still here, it's about to run!
eval ${RUNCMD} |tee -a ${LOGFILE_COMMON}

aecho "
... and done."
