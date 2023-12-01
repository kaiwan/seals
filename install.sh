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
source ./common.sh || {
	echo "${name}: source failed! ./common.sh missing or invalid?"
	exit 1
}

ShowTitle "SEALS :: Install Script"
[[ -z "${STG}" ]] && {
  aecho "${name}: SEALS staging folder isn't defined? You Must correct this and retry..."
  aecho "Tip: read the docs (wiki pages), recheck / edit the build.config file"
  color_reset
  exit 1
}
[[ -d "${STG}" ]] && {
	wecho "The staging directory already exists (${STG}).

OVERWRITE it ? Doing so will DESTROY it's content, you can't recover it:
(As a safety measure, you'll again be prompted before wiping Busybox and the kernel source trees)
y/N ? "
get_yn_reply "" n
[ $? -eq 1 ] && exit 0
}

aecho "Creating the staging dir..."
mkdir -p ${STG} || FatalError "Creating the staging dir failed (permission issues?). Aborting..."

#-------------------- Busybox
#BB_INSTALLED=0
echo
set +e		# work-around for bash strict mode
get_yn_reply "Pl confirm: Install (and possibly overwrite) busybox source tree (to ${BB_FOLDER}) now? Y/n" y
ans=$?
set -e

#set -x
if [[ ${ans} -eq 0 ]] ; then  # ans 'y'
   aecho "Installing the busybox source tree"
   [[ -d ${BB_FOLDER} ]] && {
     aecho "Deleting old content..."
		rm -rf ${BB_FOLDER} $(dirname ${BB_FOLDER})/busybox
   }
   mkdir -p ${BB_FOLDER} # abs pathname #|| FatalError "Creating the staging dir failed (permission issues?). Aborting..."
   cd ${STG}
   runcmd "git clone --depth=1 https://github.com/mirror/busybox"
   [[ ! -d ${BB_FOLDER}/applets ]] && {
		# [1] Pecuiliar! busybox src gets installed under the dir 'busybox' NOT 'busybox-<ver#>'
		# BB_FOLDER_ALT is set to $STG/busybox
		[[ ! -d ${BB_FOLDER_ALT}/applets ]] && FatalError "Failed to install busybox source."
   }
   # Because of [1]:
   rmdir ${BB_FOLDER}
   ln -sf busybox ${BB_FOLDER}
   #BB_INSTALLED=1
   aecho "[+] Busybox source tree installed"
fi

#-------------------- Linux kernel
#KSRC_INSTALLED=0
echo
set +e		# work-around for bash strict mode
get_yn_reply "Pl confirm: Install (and possibly overwrite) kernel source tree (to ${BB_FOLDER}) now? Y/n" y
ans=$?
set -e

if [[ ${ans} -eq 0 ]] ; then  # ans 'y'
   aecho "Installing the Linux kernel source tree"
   cd ${STG}  # abs pathname
   # have to figure the URL based on kernel ver...
   # f.e. if kver is 3.16.68:
   #  https://mirrors.edge.kernel.org/pub/linux/kernel/v3.x/linux-3.16.68.tar.xz
   # support only >=3.x
   K_MJ=$(echo ${KERNELVER} | cut -d'.' -f1)
   [[ ${K_MJ} -lt 3 ]] && FatalError "Your specified kernel ver (${KERNELVER}) is too old!
SEALS supports only kernel ver >= 3.x.
Pl change the kernel ver (in the build.config) and rerun"

   mkdir -p ${KERNEL_FOLDER} #|| FatalError "Creating the staging dir failed (permission issues?). Aborting..."
   #K_MN=$(echo ${KERNELVER} | cut -d'.' -f2)
   #K_PL=$(echo ${KERNELVER} | cut -d'.' -f3)
   K_URL_BASE=https://mirrors.edge.kernel.org/pub/linux/kernel
   K_URL_TARXZ=${K_URL_BASE}/v${K_MJ}.x/linux-${KERNELVER}.tar.xz

   [[ -d ${KERNEL_FOLDER} ]] && {
     aecho "Deleting old content..."
     rm -f $(basename ${K_URL_TARXZ})*
     rm -rf ${KERNEL_FOLDER}
   }

   echo "wget ${K_URL_TARXZ}"
   wget ${K_URL_TARXZ} || FatalError "Failed to fetch kernel source."
   # TODO - verify integrity
   # Uncompress
   echo "tar xf $(basename ${K_URL_TARXZ})"
   tar xf $(basename ${K_URL_TARXZ}) || FatalError "Failed to extract kernel source."
   #KSRC_INSTALLED=1
   aecho "[+] Kernel source tree linux-${KERNELVER} installed"
fi

# TODO - toolchain install
echo "To install the toolchain (Linux x86_64 host to AArch32 or AArch64 target), pl see:
https://github.com/kaiwan/seals/wiki/SEALs-HOWTO
It has detailed instructions.
"

aecho "${name}: all done."
color_reset

exit 0
