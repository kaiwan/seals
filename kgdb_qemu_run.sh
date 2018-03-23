#!/bin/sh
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# Project URL:
# https://github.com/kaiwan/seals
# (c) kaiwanTECH
name=$(basename $0)
#############################
# ${BUILD_CONFIG_FILE} : a configuration script that asks the user for and sets up
# folder locations, toolchain PATH, any other configs as required.
#############################
export BUILD_CONFIG_FILE=./build.config
source ${BUILD_CONFIG_FILE} || {
	echo "${name}: source failed! ${BUILD_CONFIG_FILE} missing or invalid?"
	exit 1
}
source ./common.sh || {
	echo "${name}: source failed! ./common.sh missing or invalid?"
	exit 1
}
color_reset

if [ $# -ne 1 ]; then
	echo "Usage: $name kernel-[b]zImage (compiled with -g)"
	exit 1
fi
[ ! -f $1 ] && {
 echo "$1 invalid.."
 exit 1
}

echo
echo "REMEMBER this kernel is run w/ the -S QEMU switch: it *waits* for a gdb client to connect to it..."
echo
echo "You are expected to run (in another terminal window):
$ ${CXX}gdb <path-to-ARM-built-kernel-src-tree>/vmlinux  # <-- built w/ -g
...
# and then have gdb connect to the target kernel using
(gdb) target remote :1235
...
"
echo

#####
## UPDATE for your box
#   Freescale I.MX6
#STG=~/scratchpad/SEALS_staging/IMX6_SEALS_staging #$(pwd)/staging
#   Vexpress CA-9
STG=~/scratchpad/SEALS_staging/SEALS_staging_vexpress #$(pwd)/staging
#####

ARMPLAT=vexpress-a9  ## make sure it's right! ##
# It's IMPORTANT to pass along the Device Tree Blob !
DTB=${STG}/images/vexpress-v2p-ca9.dtb
PORT=1235

[ ! -f ${DTB} ] && {
	echo "${name}: FATAL: DTB file \"${DTB}\" not present?"
	exit 1
}

qemu-system-arm -m 256 -M ${ARMPLAT} -kernel $1 \
	-drive file=${STG}/images/rfs.img,if=sd,format=raw \
	-append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic \
	-gdb tcp::${PORT} -S \
	-dtb ${DTB}
 	 # qemu help:
	 #  -gdb dev   wait for gdb connection on 'dev'
	 #  -S         freeze CPU at startup (use 'c' to start execution)

#
# If you get this error::
#
# inet_listen_opts: bind(ipv4,0.0.0.0,1234): Address already in use
#inet_listen_opts: bind(ipv6,::,1234): Address already in use
#inet_listen_opts: FAILED
#chardev: opening backend "socket" failed
##
# try using a different port # (and do 
# (gdb) target remote :<new-port#>
