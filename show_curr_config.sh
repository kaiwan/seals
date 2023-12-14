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

show_curr_build_config()
{
local gccver=$(${CXX}gcc --version |head -n1 |cut -f2- -d" ")

aecho " ---------------- Current Configuration -----------------"
local msg1="
Config file : build.config -> $(realpath ${BUILD_CONFIG_FILE})   [edit it to change any settings shown below]
Config name : ${CONFIG_NAME_STR}

Toolchain prefix : ${CXX}
Toolchain version: ${gccver}
Staging folder   : ${STG}

CPU arch     : ${ARCH}
CPU model    : ${CPU_MODEL}"

local msg2="ARM Platform : ${ARM_PLATFORM_STR}"

local msg3="
Platform RAM : ${SEALS_RAM} MB

RootFS force rebuild : $(yesorno ${RFS_FORCE_REBUILD})
RootFS size  : ${RFS_SZ_MB} MB [note: new size applied only on 'RootFS force rebuild']

Linux kernel to use : ${KERNELVER}
Linux kernel codebase location : ${KERNEL_FOLDER}
Kernel command-line : \"${SEALS_K_CMDLINE}\"
Verbose Build : $(yesorno ${VERBOSE_BUILD})
Busybox location: ${BB_FOLDER}

Qemu: KGDB mode: $(yesorno ${KGDB_MODE}) | SMP mode: $(yesorno ${SMP_EMU_MODE})

Diplay:
 Terminal Colors mode: $(yesorno ${COLOR}) | DEBUG mode: $(yesorno ${DEBUG}) | VERBOSE mode: $(yesorno ${VERBOSE_MSG})
Log file              : ${LOGFILE_COMMON}"

echo "${msg1}"
[[ "${ARCH}" != "x86" ]] && echo "${msg2}"
echo "${msg3}"
echo "----------------------------------------------------------"
}

show_stg()
{
[[ ! -d  ${STG} ]] && {
	becho "!WARNING! Staging dir ${STG} not present."
	return
}
becho "Staging area ::"
ls ${STG}/
echo
becho "Latest images ::"
ls -lth ${STG}/images
}


#--- 'main'
color_reset
export PRJ_TITLE="SEALS: Simple Embedded ARM Linux System"
techo "${PRJ_TITLE}"

if [[ "${ARCH}" != "x86" ]] ; then
    which ${CXX}gcc >/dev/null || becho "!WARNING! Toolchain ${CXX}* doesn't seem to be installed correctly"
fi
show_curr_build_config
show_stg
exit 0
