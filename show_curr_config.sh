#!/bin/bash
# Part of the SEALS opensource Project
# SEALS : Simple Embedded Arm Linux System
# Author and Maintainer : Kaiwan N Billimoria
# Project URL:
# https://github.com/kaiwan/seals
#----------------------------------------------------------------------
# Important:
# To get started, pl read:
#  https://github.com/kaiwan/seals/wiki
# (and follow the links on the right panel of the Wiki page).
#----------------------------------------------------------------------
# ${BUILD_CONFIG_FILE} : a configuration script that asks the user for and sets up
# folder locations, toolchain PATH, any other configs as required.
#############################

# Turn on Bash 'strict mode'!
# ref: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

export name=$(basename $0)
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
export PRJ_TITLE="SEALS: Simple Embedded ARM Linux System"

techo "${PRJ_TITLE}"

show_curr_build_config()
{
local gccver=$(${CXX}gcc --version |head -n1 |cut -f2- -d" ")

aecho " ---------------- Current Configuration -----------------"
local msg1="
Config file : ${BUILD_CONFIG_FILE}   [edit it to change any settings shown below]
Config name : ${CONFIG_NAME_STR}

Toolchain prefix : ${CXX}
Toolchain version: ${gccver}
Staging folder   : ${STG}

CPU arch     : ${ARCH}
CPU model    : ${CPU_MODEL}
ARM Platform : ${ARM_PLATFORM_STR}
Platform RAM : ${SEALS_RAM} MB

RootFS force rebuild : ${RFS_FORCE_REBUILD}
RootFS size  : ${RFS_SZ_MB} MB [note: new size applied only on 'RootFS force rebuild']

Linux kernel to use : ${KERNELVER}
Linux kernel codebase location : ${KERNEL_FOLDER}
Kernel command-line : \"${SEALS_K_CMDLINE}\"

Verbose Build : ${VERBOSE_BUILD}

Busybox location: ${BB_FOLDER}

Qemu: KGDB mode: ${KGDB_MODE} | SMP mode: ${SMP_EMU_MODE}

Diplay:
 [Terminal Colors mode: ${COLOR}] [DEBUG mode: ${DEBUG}] [VERBOSE mode: ${VERBOSE_MSG}]
Log file              : ${LOGFILE_COMMON}"

echo "${msg1}"
echo "----------------------------------------------------------"
}

show_stg()
{
becho "Staging area ::"
ls ${STG}/
echo
becho "Latest images ::"
ls -lth ${STG}/images
}

show_curr_build_config
show_stg
exit 0
