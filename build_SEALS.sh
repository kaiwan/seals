#!/bin/bash
#
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Author and Maintainer : Kaiwan N Billimoria
#  https://amazon.com/author/kaiwanbillimoria
# Project URL:
# https://github.com/kaiwan/seals
#----------------------------------------------------------------------
# Important:
# To get started, please read:
#  https://github.com/kaiwan/seals/wiki
# (and follow the links on the right panel of the Wiki page).
#----------------------------------------------------------------------
# A helper script designed to build:
# a custom kernel + root filesystem for an "embedded" QEMU/ARM Linux system.
# By default, this helper script uses the 'default config' found in the file
# 'build.config'. For convenience, build.config is simply a soft (symbolic) link
# to the actual config file (of the form build.config.FOO).
# The build.config holds the configuration for building:
#  - a Linux kernel (+DTB) and root filesystem for:
#    - the ARM Versatile Express (Cortex-A9) platform (supported by Qemu).
# By tweaking build.config , you can use the SEALS project to build something else..
#----------------------------------------------------------------------
# Cmdline:
# ./build_seals.sh [-c]
#   -c : run in console mode only (no gui) [optional]
#
# Ref:
# (old but still) very good References (by 'Balau'):
#  Kernel: 
#    http://balau82.wordpress.com/2012/03/31/compile-linux-kernel-3-2-for-arm-and-emulate-with-qemu/
# [OLDer LINK]: http://balau82.wordpress.com/2010/03/22/compiling-linux-kernel-for-qemu-arm-emulator/
#  Busybox: http://balau82.wordpress.com/2010/03/27/busybox-for-arm-on-qemu/
#
# (c) Kaiwan N Billimoria <kaiwan -at- kaiwantech -dot- com>
# (c) kaiwanTECH
#
# License: MIT
#
# TODO / ISSUES
# [ ] networking
#     ref- https://github.com/MichielDerhaeg/build-linux
# [+] installer- for busybox & kernel source trees
# [ ] signals (like SIGINT ^C, SIGQUIT ^\, etc) not being handled within the Qemu guest ?
#         (I think we need 'getty' running for this... ?)
# [+] GUI for target machine selection
# [.] AMD64 / x86_64 platform
# [ ] Kernel
#    [ ] Do the kbuild outside k src tree (w/ the O=... );
#        this way we can reuse the same k src tree for diff builds!
#    [ ] x86/pc: option to perform the 'localmodconfig' build (quicker)
# [ ] Only GUI menu for target board selection; fix for console mode (in config_symlink_setup())
# [.] Testing/Q&A: Add test/ folder
#   [+] shellcheck
#   [.] for all boards: generate everything & run
# [ ] Minor / various / misc
#   [ ] unattended run (non-interactive)
#   [ ] use sudo, not via wrapper mysudo
#
#----------------------------------------------------------------------

# Turn on Bash 'strict mode'!
# ref: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
export name=$(basename $0)

#############################
# ${BUILD_CONFIG_FILE} : a configuration script that specifies
# folder locations, toolchain PATH, kernel & busybbox versions and locations,
# memory sizes, any other configs as required.
#############################
export BUILD_CONFIG_FILE=./build.config
[[ ! -f ${BUILD_CONFIG_FILE} ]] && {
	echo "
*** FATAL ***              Couldn't find build.config

Check:
- Is the relevant board config file present?
- Does the symbolic link 'build.config' point to it?

Tip: If new to SEALS, we urge you, read the documentation here and then proceed:
 https://github.com/kaiwan/seals/wiki
 https://github.com/kaiwan/seals/wiki/SEALs-HOWTO"
	exit 1
}
source ${BUILD_CONFIG_FILE} || {
	echo "${name}: ${BUILD_CONFIG_FILE} missing, creating it (to the default platform, the AArch32 VExpress)"
	ln -sf build.config.arm32_vexpress build.config || exit 1  # set to default
}
source ./common.sh || {
	echo "${name}: source failed! ./common.sh missing or invalid?"
	exit 1
}
color_reset

### "Globals"
export PRJ_TITLE="SEALS - Simple Embedded ARM Linux System"

# Message strings
export MSG_GIVE_PSWD_IF_REQD="If asked, please enter password"
export MSG_EXITING="
All done, exiting.
Thanks for using SEALS, hope you like it.
Please do consider contributing your feedback, ideas, and code!
https://github.com/kaiwan/seals"

STEPS=5
export CPU_CORES=$(getconf -a|grep _NPROCESSORS_ONLN|awk '{print $2}')
[ -z "${CPU_CORES}" ] && CPU_CORES=2

# Signals
trap 'wecho "User Abort. ${MSG_EXITING}" ; dumpstack ; [ ${COLOR} -eq 1 ] && color_reset ; exit 2' HUP INT QUIT


##-------------------- Functions Start --------------------------------

kernel_uname_r()
{
# /lib/modules/`uname -r` required for rmmod to function
# FIXME - when kernel ver has '-extra' it doesn't take it into account..
local KDIR=$(echo ${KERNELVER} | cut -d'-' -f2)
# get the EXTRAVERSION component from the kernel config
local XV=$(grep "^CONFIG_LOCALVERSION=" ${KERNEL_FOLDER}/.config |cut -d'=' -f2|tr -d '"')
KDIR=${KDIR}${XV}
echo "${KDIR}"
}

set_kernelimg_var()
{
# TODO : put this in individual build.config* files
export KIMG=arch/${ARCH}/boot/zImage
[ "${ARCH}" = "arm64" ] && KIMG=arch/${ARCH}/boot/Image.gz
set +u
[ "${ARCH_PLATFORM}" = "x86_64" ] && KIMG=arch/x86/boot/bzImage
set -u
#echo "@@@ KIMG = ${KIMG}"

# Set the kernel modules install location
# Careful! see https://www.kernel.org/doc/Documentation/kbuild/modules.txt
# ...
# A prefix can be added to the installation path using the variable INSTALL_MOD_PATH:
#	$ make INSTALL_MOD_PATH=/frodo modules_install
#	=> Install dir: /frodo/lib/modules/$(KERNELRELEASE)/kernel/
# ...
export KMODDIR=${ROOTFS_DIR}
#echo "KMODDIR = ${KMODDIR}"

# Device Tree Blob (DTB) pathname
[[ "${ARCH_PLATFORM}" != "x86_64" ]] && \
  export DTB_BLOB_PATHNAME=${KERNEL_FOLDER}/arch/${ARCH}/boot/dts/${DTB_BLOB} || true  # gen within kernel src tree
}

install_kernel_modules()
{
# Have the kernel modules been generated?
echo -n "
Checking kernel modules ...  "
find ${KERNEL_FOLDER} -name "*.ko" >/dev/null 2>&1 || 
        FatalError "Dependency: need to build+install the kernel+modules for correct root fs generation.
  Please enable the kernel build step and retry."
echo "[Yes]"
set_kernelimg_var
echo "[+] Install kernel modules
     ( into dir: ${KMODDIR}/lib/modules/$(kernel_uname_r)/ )"

[[ ! -d ${KMODDIR} ]] && mkdir -p ${KMODDIR}
cd ${KERNEL_FOLDER} || FatalError "cd to kernel dir failed"
sudo make INSTALL_MOD_PATH=${KMODDIR} modules_install || \
  FatalError "Kernel modules install step failed; have you performed the kernel build step?"
}

# x86-64 only, and invoked only if USE_INITRAMFS=1 in the board config file
setup_initramfs()
{
local INITRD=${ROOTFS_DIR}/initrd.img
echo "[+] PC (x86-64/AMD64): Install initramfs (initrd)"
[[ -z "${KMODDIR}" ]] && set_kernelimg_var
which mkinitramfs >/dev/null 2>&1 && {
	rm -f ${INITRD}
	echo "Generating (Ubuntu-flavor) initramfs image..."
	cd ${KERNEL_FOLDER} || FatalError "cd to kernel dir failed"
	mkinitramfs -o ${ROOTFS_DIR}/initrd.img || FatalError "failed to generate initramfs image"
	sudo chown root:root ${ROOTFS_DIR}/initrd.img
	cp -au ${ROOTFS_DIR}/initrd.img ${IMAGES_FOLDER}/ || FatalError "copying initrd to images failed?"
	ls -lh ${IMAGES_FOLDER}/initrd.img
	cd -
} || FatalError "Cannot generate initramfs (mkinitramfs missing or it's not an Ubuntu build host?)"
# TODO - Fedora/CentOS/RH - use mkinird

echo "Installing boot files into the root fs..."
sudo make INSTALL_PATH=${ROOTFS_DIR} install || FatalError "PC: 'sudo make install' step failed"
}

#------------------ b u i l d _ k e r n e l ---------------------------
build_kernel()
{
 report_progress
cd ${KERNEL_FOLDER} || exit 1
ShowTitle "KERNEL: Configure and Build [kernel ver ${KERNELVER}] now ..."

if [ -z "${ARM_PLATFORM}" ] ; then  # arm64 and x86_64
	PLATFORM=defconfig # by default all platforms selected
else
	PLATFORM=${ARM_PLATFORM}_defconfig
fi
if [ ${WIPE_KERNEL_CONFIG} -eq 1 ]; then
	ShowTitle "Setting default kernel config"
    echo "make defconfig"
    make defconfig
    #make mrproper
    make V=${VERBOSE_BUILD} ARCH=${ARCH} ${PLATFORM} || \
	FatalError "Kernel config for platform failed.."
fi

#set -x
aecho "[Optional] Kernel Manual Configuration:
Edit the kernel config as required, Save & Exit...
"
[ "${ARCH}" = "arm64" ] && aecho "TIP: On AArch64, with recent kernels, *all* platforms will be selected by default.
(Can see them within the 'Platform selection' menu).
Either build it this way or deselect all and enable only the platform(s) you want to support..."
Prompt ""

USE_QT=n   # make 'y' to use a GUI Qt configure environment
           #  if 'y', you'll require the Qt runtime installed..
if [ ${USE_QT} = "y" ]; then
	make V=${VERBOSE_BUILD} ARCH=${ARCH} xconfig || {
	  FatalError "make xconfig failed.."
	}
else
	make V=${VERBOSE_BUILD} ARCH=${ARCH} menuconfig || {
	  FatalError "make menuconfig failed.."
	}
fi

# Tip- On many Ubuntu/Deb systems, we need to turn Off the
# SYSTEM_REVOCATION_KEYS config option, else the build fails
echo "[+] scripts/config --disable SYSTEM_REVOCATION_KEYS"
scripts/config --disable SYSTEM_REVOCATION_KEYS || echo "Warning! Disabling SYSTEM_REVOCATION_KEYS failed"
echo "[+] scripts/config --disable WERROR" # turn off 'treat warnings as errors'
scripts/config --disable WERROR || echo "Warning! Disabling WERROR failed"

ShowTitle "Kernel Build:"

#iecho "--- # detected CPU cores is ${CPU_CORES}" ; read
CPU_OPT=$((${CPU_CORES}*2))

#Prompt
# make all => kernel image, modules, dtbs (device-tree-blobs), ... - all will be built!
local CMD="time make V=${VERBOSE_BUILD} -j${CPU_OPT} ARCH=${ARCH} CROSS_COMPILE=${CXX} all"
set +u
if [[ "${ARCH_PLATFORM}" = "x86_64" ]] ; then
	CMD="time make V=${VERBOSE_BUILD} -j${CPU_OPT}"
fi
set -u
aecho "Doing: ${CMD}"
eval ${CMD} || {
  FatalError "Kernel build failed! Aborting ..."
} && true

install_kernel_modules
[[ "${ARCH_PLATFORM}" = "x86_64" && ${USE_INITRAMFS} -eq 1 ]] && setup_initramfs
#  echo "[-] Skipping initramfs generation"

# Refresh our variables!
set_kernelimg_var

#echo "KIMG = ${KIMG}"
ls -lh ${KIMG}*
cp -u ${KIMG}* ${IMAGES_FOLDER}/ || FatalError "copying kernel image failed"

[[ "${ARCH_PLATFORM}" != "x86_64" && -f ${DTB_BLOB_PATHNAME} ]] && {
   echo; ls -lh ${DTB_BLOB_PATHNAME}
   cp -u ${DTB_BLOB_PATHNAME} ${IMAGES_FOLDER}/ || FatalError "copying DTB failed"
} || true
aecho "... and done."
cd ${TOPDIR}
} # end build_kernel()

#--------------- b u i l d _ c o p y _ b u s y b o x ------------------
build_copy_busybox()
{
 report_progress
cd ${BB_FOLDER} || exit 1

ShowTitle "BUSYBOX: Configure and Build Busybox now ... [$(basename ${BB_FOLDER})]"
iecho " [Sanity chk: ROOTFS_DIR=${ROOTFS_DIR}]"
# safety check!
if [ -z "${ROOTFS_DIR}" -o ! -d ${ROOTFS_DIR} -o "${ROOTFS_DIR}" = "/" ]; then
	FatalError "SEALS: ROOTFS_DIR has dangerous value of null or '/'. Aborting..."
fi

if [ ${WIPE_BUSYBOX_CONFIG} -eq 1 ]; then
	ShowTitle "BusyBox default config:"
	make V=${VERBOSE_BUILD} ARCH=${ARCH} CROSS_COMPILE=${CXX} defconfig
fi

aecho "Edit the BusyBox config as required, Save & Exit..."
Prompt " " ${MSG_EXITING}

USE_QT=n   # make 'y' to use a GUI Qt configure environment
if [ ${USE_QT} = "y" ]; then
	make V=${VERBOSE_BUILD} ARCH=${ARCH} CROSS_COMPILE=${CXX} xconfig
else
	make V=${VERBOSE_BUILD} ARCH=${ARCH} CROSS_COMPILE=${CXX} menuconfig
fi

# Ensure CONFIG_BASH_IS_ASH=y (so that we can run bash)
sed -i '/# CONFIG_BASH_IS_ASH/d' .config
cat >> .config << @MYMARKER@
CONFIG_BASH_IS_ASH=y
@MYMARKER@

ShowTitle "BusyBox Build:"
aecho "If prompted like this: 'Choose which shell is aliased to 'bash' name'
select option 1 : '  1. hush (BASH_IS_ASH)'"
Prompt ""

local CMD="time make V=${VERBOSE_BUILD} -j${CPU_CORES} ARCH=${ARCH} CROSS_COMPILE=${CXX} install"
set +u
if [[ "${ARCH_PLATFORM}" = "x86_64" ]] ; then
	CMD="time make V=${VERBOSE_BUILD} -j${CPU_CORES} install"
fi
set -u
#set -x
aecho "Doing: ${CMD}"
eval ${CMD} || {
  FatalError "Building and/or Installing busybox failed!"
} && true

mysudo "SEALS Build:Step 1 of ${STEPS}: Copying of required busybox files. ${MSG_GIVE_PSWD_IF_REQD}" \
 cp -af ${BB_FOLDER}/_install/* ${ROOTFS_DIR}/ || \
  FatalError "Copying required folders from busybox _install/ failed! 
 [Tip: Ensure busybox has been successfully built]. Aborting..."
aecho "SEALS Build: busybox files copied across successfully ..."
} # end build_copy_busybox()

#---------- s e t u p _ e t c _ i n _ r o o t f s ---------------------
setup_etc_in_rootfs()
{
 report_progress
cd ${ROOTFS_DIR}
aecho "SEALS Build: Manually generating required SEALS rootfs /etc files ..."

# /etc/inittab
cat > etc/inittab << @MYMARKER@
::sysinit:/etc/init.d/rcS
#tty1::respawn:/sbin/getty 38400 tty1
#::respawn:/sbin/getty 115200 ttyS0
@MYMARKER@

# Custom prompt str (PS1)!
# Earlier ensured that CONFIG_BASH_IS_ASH=y (so that we can run bash)
if [[ "${ARCH}" = "arm" ]]; then
   cat >> etc/inittab << @MYMARKER@
::respawn:env PS1='arm \w \$ ' ${SHELL2RUN}
@MYMARKER@
# this one - rpi3b - should come before the 'arm64' one...
elif [[ "${ARM_PLATFORM_STR}" = "Qemu Rpi3B" ]]; then
   cat >> etc/inittab << @MYMARKER@
::respawn:env PS1='rpi3b \w \$ ' ${SHELL2RUN}
@MYMARKER@
elif [[ "${ARCH}" = "arm64" ]]; then
   cat >> etc/inittab << @MYMARKER@
::respawn:env PS1='arm64 \w \$ ' ${SHELL2RUN}
@MYMARKER@
elif [[ "${ARCH_PLATFORM}" = "x86_64" ]]; then
   cat >> etc/inittab << @MYMARKER@
::respawn:env PS1='pc \w \$ ' ${SHELL2RUN}
@MYMARKER@
fi

cat >> etc/inittab << @MYMARKER@
::restart:/sbin/init
::shutdown:/bin/umount -a -r
@MYMARKER@

# rcS master script
cat > etc/init.d/rcS << @MYMARKER@
echo "SEALS: /etc/init.d/rcS running now ..."
/bin/mount -a
## remount / as rw; requires CONFIG_LBDAF (old stuff)
#/bin/mount -o remount,rw /

# networking : don't try until n/w is properly setup in SEALS
#ifconfig eth0 192.168.1.100 netmask 255.255.255.0 up

# Misc
if [ $(id -u) -eq 0 ]; then
   # guarantee all printk's appear on console device
   echo "7 4 1 7" > /proc/sys/kernel/printk
   # better core-file pathname
   echo "core_%h_%E_%p_%s_%u" > /proc/sys/kernel/core_pattern
   # Kexec (for kdump/crashkernel facility)
   if [ -x /kx.sh ]; then
       /kx.sh
   fi
fi
@MYMARKER@

chmod +x etc/init.d/rcS

# etc/fstab
# Ensure that procfs and sysfs are mounted.
cat > etc/fstab << @MYMARKER@
# device     directory type options
none         /proc     proc nodev,noexec
none         /sys      sysfs noexec
none         /sys/kernel/debug debugfs
@MYMARKER@
} # end setup_etc_in_rootfs

#-------- s e t u p _ l i b _ i n _ r o o t f s -----------------------
setup_lib_in_rootfs()
{
 report_progress
aecho "SEALS Build: copying across shared objects, etc to SEALS /lib /sbin /usr ..."

if [[ "${ARCH_PLATFORM}" = "x86_64" ]] ; then
  #echo "@@@ x86-64 ROOTFS lib @@@"
  # if busybox built as a dynamic executable... requires:
	# linux-vdso.so.1   <---------- via kernel so ignore
	# libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6
	# libresolv.so.2 => /lib/x86_64-linux-gnu/libresolv.so.2
	# libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
	# /lib64/ld-linux-x86-64.so.2

# libgcc* ??
# busybox says
#...
# Static linking against glibc, can't use --gc-sections
#Trying libraries: crypt m resolv rt
# Library crypt is not needed, excluding it
# Library m is needed, can't exclude it (yet)
# Library resolv is needed, can't exclude it (yet)
# Library rt is not needed, excluding it
# Library m is needed, can't exclude it (yet)
# Library resolv is needed, can't exclude it (yet)
#Final link with: m resolv

  # Loader: /lib64/ld-linux-x86-64.so.2 ->  /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
  mkdir -p ${ROOTFS_DIR}/lib/x86_64-linux-gnu
  cp -au /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ${ROOTFS_DIR}/lib64/ || FatalError "copying ld-linux* failed"

  #cp -au /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ${ROOTFS_DIR}/lib/x86_64-linux-gnu/

  # std c lib: libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
  cp -au /lib/x86_64-linux-gnu/libc.so.6  ${ROOTFS_DIR}/lib/x86_64-linux-gnu/ || FatalError "copying glibc failed"

  # libresolv
  cp -au /lib/x86_64-linux-gnu/libresolv.so.2 ${ROOTFS_DIR}/lib/x86_64-linux-gnu/ || FatalError "copying libresolv failed"

  # libm
  cp -au /lib/x86_64-linux-gnu/libm.so.6 ${ROOTFS_DIR}/lib/x86_64-linux-gnu/ || FatalError "copying libm failed"

  return
fi

#--- NON-X86

# First, get the 'sysroot' from the compiler itself
SYSROOT=${GCC_SYSROOT}/
echo "[Sanity check:
ROOTFS_DIR=${ROOTFS_DIR}
SYSROOT = ${SYSROOT} ]"

set +u
if [ -z "${SYSROOT}" -o ! -d ${SYSROOT} -o "${SYSROOT}" = "/" ]; then
	  cd ${TOPDIR}
	  FatalError "Toolchain shared library locations invalid (NULL or '/')? Aborting..."
fi
set -u

# 'Which (shared) libraries do we copy into the rootfs?'
# Quick solution: just copy _all_ the shared libraries, etc from the toolchain
# into the rfs/lib.
# EXCEPTION : the x86_64
set +u
if [[ "${ARCH_PLATFORM}" != "x86_64" ]] ; then
 mysudo "SEALS Build:Step 2 of ${STEPS}: [SEALS rootfs]:setup of library objects. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/lib/* ${ROOTFS_DIR}/lib || {
   FatalError "Copying required libs [/lib] from toolchain failed!"
 }
 mysudo "SEALS Build:Step 3 of ${STEPS}: [SEALS rootfs]:setup of /sbin. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/sbin/* ${ROOTFS_DIR}/sbin || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
 }
 mysudo "SEALS Build:Step 4 of ${STEPS}: [SEALS rootfs]:setup of /usr. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/usr/* ${ROOTFS_DIR}/usr || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
 }
 sudo mkdir -p ${ROOTFS_DIR}/lib64 || true
 mysudo "SEALS Build:Step 4.2 of ${STEPS}: [SEALS rootfs]:setup of /lib64. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/lib64/* ${ROOTFS_DIR}/lib64 || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
 }
 mysudo "SEALS Build:Step 4.3 of ${STEPS}: [SEALS rootfs]:setup of /var. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/var/* ${ROOTFS_DIR}/var || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
 }
  # RELOOK: 
  # $ ls rootfs/usr/
  # bin/  include/  lib/  libexec/  sbin/  share/
  # $ 
  # usr/include - not really required?
fi
} # end setup_lib_in_rootfs

#------ s e t u p _ d e v _ i n _ r o o t f s -------------------------
setup_dev_in_rootfs()
{
 report_progress
#---------- Device Nodes [static only]
aecho "SEALS Build: Manually generating required Device Nodes in /dev ..."
cd ${ROOTFS_DIR}/dev

cat > mkdevtmp.sh << @MYMARKER@
#!/bin/sh
rm -f *

mknod -m 600 mem c 1 1
mknod -m 600 kmem c 1 2
mknod -m 666 null c 1 3
mknod -m 666 zero c 1 5
mknod -m 644 random c 1 8
mknod -m 644 urandom c 1 9

mknod -m 666 tty c 5 0
mknod -m 666 tty0 c 4 0
mknod -m 666 tty1 c 4 1
mknod -m 666 tty2 c 4 2
mknod -m 666 tty3 c 4 3
mknod -m 666 tty4 c 4 4
mknod -m 666 console c 5 1
mknod -m 666 ttyS0 c 4 64
mknod -m 660 fb0 c 29 0

mknod -m 660 ram b 1 0
mknod -m 660 loop b 7 0
mknod -m 640 mmcblk0 b 179 0

mknod -m 660 hda b 3 0
mknod -m 660 sda b 8 0

# FIXME / TODO :: FAILS
## recommended slinks
#ln -s /proc/self/fd fd
#ln -s /proc/self/fd/0 stdin
#ln -s /proc/self/fd/1 stdout
#ln -s /proc/self/fd/2 stderr
@MYMARKER@

chmod u+x ${ROOTFS_DIR}/dev/mkdevtmp.sh
mysudo "SEALS Build:Step 5 of ${STEPS}: [SEALS rootfs]:setup of device nodes. ${MSG_GIVE_PSWD_IF_REQD}" \
  ${ROOTFS_DIR}/dev/mkdevtmp.sh || {
   rm -f mkdevtmp.sh
   FatalError "Setup of device nodes failed!"
}
rm -f mkdevtmp.sh
} # end setup_dev_in_rootfs

#---------- r o o t f s _ x t r a s -----------------------------------
rootfs_xtras()
{
 report_progress
# To be copied into the RFS..any special cases
# strace, tcpdump, gdb[server], misc scripts (strace, gdb copied from buildroot build)

# Copy configs into the rootfs
mkdir -p ${ROOTFS_DIR}/configs 2>/dev/null
[[ -f ${KERNEL_FOLDER}/.config ]] && cp ${KERNEL_FOLDER}/.config ${ROOTFS_DIR}/configs/kernel_config
[[ -f ${BB_FOLDER}/.config ]] && cp ${BB_FOLDER}/.config ${ROOTFS_DIR}/configs/busybox_config

if [ -d ${TOPDIR}/xtras ]; then
	aecho "SEALS Build: Copying 'xtras' (goodies!) into the root filesystem..."
	cd ${TOPDIR}/xtras

	[ -f strace ] && cp strace ${ROOTFS_DIR}/usr/bin
	[ -f tcpdump ] && cp tcpdump ${ROOTFS_DIR}/usr/sbin

	# for gdb on-board, we need libncurses* & libz* (for gdb v7.1)
	mkdir -p ${ROOTFS_DIR}/usr/lib
	cp -a libncurses* libz* ${ROOTFS_DIR}/usr/lib
	[ -f gdb ] && cp gdb ${ROOTFS_DIR}/usr/bin

	# misc
	[ -f 0setup ] && cp 0setup ${ROOTFS_DIR}/
	[ -f procshow.sh ] && chmod +x procshow.sh
	#cp common.sh procshow.sh pidshow.sh ${ROOTFS_DIR}/${MYPRJ}

	# useful for k debug stuff
	cp ${KERNEL_FOLDER}/System.map ${ROOTFS_DIR}/
fi
} # end rootfs_xtras

# r o o t f s _ d i r s ( )
# Create the minimal rootfs directories
rootfs_dirs()
{
cd ${ROOTFS_DIR}
mkdir -p dev etc/init.d lib lib64 ${MYPRJ} proc root/dev run srv sys tmp 2>/dev/null || true
chmod 1777 tmp || true
chmod 0700 root || true
rmdir home/root 2>/dev/null || true
}

#------------------ b u i l d _ r o o t f s ---------------------------
#
# NOTE: The root filesystem is now populated in the ${ROOTFS_DIR} folder under ${TOPDIR}
#
build_rootfs()
{
 report_progress
# First reset the 'rootfs' staging area so that regular user can update
mysudo "SEALS Build: reset SEALS root fs. ${MSG_GIVE_PSWD_IF_REQD}" \
 chown -R ${LOGNAME}:${LOGNAME} ${ROOTFS_DIR}/*

#---------Generate necessary pieces for the rootfs
   build_copy_busybox
   rootfs_dirs
   setup_etc_in_rootfs
   setup_lib_in_rootfs
   setup_dev_in_rootfs
   rootfs_xtras
#else
#   pc_build_rootfs_debootstrap

aecho "SEALS Build: enable final setup of SEALS root fs. ${MSG_GIVE_PSWD_IF_REQD}"
sudo chown -R root:root ${ROOTFS_DIR}/* || FatalError "SEALS Build: chown on ${ROOTFS_DIR}/ failed!"

cd ${TOPDIR}/
ShowTitle "Done! Platform root filesystem toplevel content follows:"
ls -lh ${ROOTFS_DIR}/
local RFS_ACTUAL_SZ_MB=$(du -ms ${ROOTFS_DIR}/ 2>/dev/null |awk '{print $1}')
aecho "SEALS root fs: actual size = ${RFS_ACTUAL_SZ_MB} MB"
} # end build_rootfs()

#------- g e n e r a t e _ r o o t f s _ i m g _ e x t 4 --------------
generate_rootfs_img_ext4()
{
 report_progress
cd ${ROOTFS_DIR} || FatalError "generate_rootfs_img_ext4(): cd failed"

ShowTitle "SEALS ROOT FS: Generating ext4 image for root fs now:"

# RFS should be the final one ie the one in images/
local RFS=${IMAGES_FOLDER}/rfs.img
local MNTPT=/mnt/tmp
# Size of the rootfs 'file' is in the build.config file
local COUNT=$((${RFS_SZ_MB}*256))  # for given blocksize (bs) of 4096

[ ! -d ${MNTPT} ] && {
  mysudo "SEALS Build: root fs image generation: enable mount dir creation. ${MSG_GIVE_PSWD_IF_REQD}" \
   mkdir -p ${MNTPT}
}
# If config option RFS_FORCE_REBUILD is set -OR- the RootFS file does not exist,
# create from scratch. If it does exist, just loop mount and update.
if [ ${RFS_FORCE_REBUILD} -eq 1 -o ! -f ${RFS} ]; then
  aecho "SEALS Build: *** Deleting and re-creating raw RFS image file now *** [dd, mkfs.ext4]"
  rm -f ${RFS}
  dd if=/dev/zero of=${RFS} bs=4096 count=${COUNT}
  mysudo "SEALS Build: root fs image generation (via mkfs). ${MSG_GIVE_PSWD_IF_REQD}" \
   mkfs.ext4 -F -L qemu_rfs_SEALS ${RFS} || FatalError "mkfs failed!"
fi

# Keep FORCE_RECREATE_RFS to 0 by default!!
# Alter at your Own Risk!!
local FORCE_RECREATE_RFS=0

sync
mysudo "SEALS Build: root fs image generation: enable umount. ${MSG_GIVE_PSWD_IF_REQD}" \
 umount ${MNTPT} 2>/dev/null
mysudo "SEALS Build: root fs image generation: enable mount. ${MSG_GIVE_PSWD_IF_REQD}" \
 mount -o loop ${RFS} ${MNTPT} || {
  wecho "### $name: !WARNING! Loop mounting rootfs image file Failed! ###"
  if [ ${FORCE_RECREATE_RFS} -eq 0 ]; then
    aecho "-- Aborting this function! --"
	aecho "To *force* root filesystem creation by deleting current RFS, set"
	aecho "the FORCE_RECREATE_RFS in the script to 1."
	return
  else
    wecho "
### $name: !WARNING! FORCE_RECREATE_RFS flag is non-zero! Now *deleting* current RFS image and re-creating it...
"
    rm -f ${RFS} 2>/dev/null
    #dd if=/dev/zero of=${RFS} bs=4096 count=16384
    dd if=/dev/zero of=${RFS} bs=4096 count=${COUNT}
    mysudo "SEALS Build: root fs image generation: enable mkfs (in force_recreate_rfs). ${MSG_GIVE_PSWD_IF_REQD}" \
     mkfs.ext4 -F -L qemu_rfs_SEALS ${RFS} || exit 1
    mysudo "SEALS Build: root fs image generation: enable mount (in force_recreate_rfs). ${MSG_GIVE_PSWD_IF_REQD}" \
     mount -o loop ${RFS} ${MNTPT} || {
	  FatalError " !!! The loop mount RFS failed Again !!! Wow. Too bad. See ya :-/"
	}
  fi
 }

aecho " Now copying across all rootfs data to ${RFS} ..."
sudo cp -au ${ROOTFS_DIR}/* ${MNTPT}/ || FatalError "Copying all rootfs content failed"

mysudo "SEALS Build: root fs image generation: enable unmount. ${MSG_GIVE_PSWD_IF_REQD}" \
 umount ${MNTPT}
sync
ls -lh ${RFS}
aecho "... and done."
cd ${TOPDIR}
} # end generate_rootfs_img_ext4()

#-------- s a v e _ i m a g e s _ c o n f i g s -----------------------
# fn to place final images in images/ and save imp config files as well...
save_images_configs()
{
 report_progress
ShowTitle "BACKUP: kernel, busybox images and config files now (as necessary) ..."
cd ${TOPDIR}
set_kernelimg_var
unalias cp 2>/dev/null || true

cp -afu ${IMAGES_FOLDER}/ ${IMAGES_BKP_FOLDER} || FatalError "copying images to backup folder failed"
 # backup!
cp -u ${KERNEL_FOLDER}/${KIMG} ${IMAGES_FOLDER}/ || FatalError "copying kernel image to backup folder failed"
[ -f ${DTB_BLOB_PATHNAME} ] && cp -u ${DTB_BLOB_PATHNAME} ${IMAGES_FOLDER}/ || true
cp ${KERNEL_FOLDER}/.config ${CONFIGS_FOLDER}/kernel_config || FatalError "copying k config to backup folder failed"
cp ${BB_FOLDER}/.config ${CONFIGS_FOLDER}/busybox_config || FatalError "copying bb config to backup folder failed"

aecho " ... and done."
} # end save_images_configs()

#-------------- r u n _ q e m u _ S E A L S ---------------------------
# Wrapper over the run-qemu.sh script
run_qemu_SEALS()
{
	[[ ! -f ${TOPDIR}/run-qemu.sh ]] && {
	  FatalError "run script run-qemu.sh not found? Aborting..."
	}
	${TOPDIR}/run-qemu.sh 0
} # end run_qemu_SEALS()

#------ s e a l s _ m e n u _ c o n s o l e m o d e -------------------
seals_menu_consolemode()
{
 report_progress
becho "SEALS :: Console Menu
"

# get_yn_reply() returns 0 on 'y', 1 on 'n' answer
get_yn_reply "1. Build Linux kernel? : " y
[ $? -eq 0 ] && BUILD_KERNEL=1
# First-time kernel build? then ensure config is wiped
[ ! -f ${KERNEL_FOLDER}/vmlinux ] && {
  echo "First-time kernel build (?), recommend keeping wipe-config On"
}
get_yn_reply " a) Wipe Linux kernel current configuration clean? : " n
[ $? -eq 0 ] && WIPE_KERNEL_CONFIG=1 || WIPE_KERNEL_CONFIG=0

get_yn_reply "2. Build Root Filesystem? : " y
[ $? -eq 0 ] && BUILD_ROOTFS=1

# First-time busybox build? then ensure config is wiped
[ ! -d ${BB_FOLDER}/_install ] && {
  echo "First-time busybox build (?), recommend keeping wipe-config On"
}
get_yn_reply " a) Wipe Busybox current configuration clean? : " n
[ $? -eq 0 ] && WIPE_BUSYBOX_CONFIG=1 || WIPE_BUSYBOX_CONFIG=0

get_yn_reply " b) Generate Root Filesystem ext4 image? [y/n] : " y
[ $? -eq 0 ] && GEN_EXT4_ROOTFS_IMAGE=1
get_yn_reply "3. Backup kernel & busybox images & configs? [y/n] : " y
[ $? -eq 0 ] && SAVE_BACKUP_IMG_CONFIGS=1
get_yn_reply "4. Run emulated system with Qemu? [y/n] : " y
[ $? -eq 0 ] && RUN_QEMU=1
} # end seals_menu_consolemode()

display_current_config()
{
 report_progress

  echo -n " Build kernel                          :: "
  yesorno_color ${BUILD_KERNEL}

  echo -n "  Wipe kernel config clean             :: "
  yesorno_color ${WIPE_KERNEL_CONFIG}

  echo -n " Build Root Filesystem                 :: "
  yesorno_color ${BUILD_ROOTFS}

  echo -n "  Wipe busybox config clean            :: "
  yesorno_color ${WIPE_BUSYBOX_CONFIG}

  echo -n " Generate rootfs ext4 image            :: "
  yesorno_color ${GEN_EXT4_ROOTFS_IMAGE}

  echo -n " Backup kernel & rootfs images/configs :: "
  yesorno_color ${SAVE_BACKUP_IMG_CONFIGS}

  echo -n " Run the Qemu emulator                 :: "
  yesorno_color ${RUN_QEMU}
}

# Set up the config.build symbolic (soft) link to point to the appropriate platform build.config.<foo> file
config_symlink_setup()
{
	aecho "config_symlink_setup()"
	# Match the current config to set it to selected state
#set -x
	local arm32_vexpress_state=False arm64_qemuvirt_state=False arm64_rpi3b_cm3_state=False amd64_state=False 
	local CONFIG_CURR="$(basename "$(realpath ${BUILD_CONFIG_FILE})")"
	local CONFIG_FILE=$(ls "${CONFIG_CURR}")
	[[ -z "${CONFIG_FILE}" ]] && FatalError "Couldn't get config file" || true

	case "${CONFIG_FILE}" in
	  build.config.arm32_vexpress) arm32_vexpress_state=True ;;
	  build.config.arm64_qemuvirt) arm64_qemuvirt_state=True ;;
	  build.config.arm64_rpi3b_cm3) arm64_rpi3b_cm3_state=True ;;
	  build.config.amd64) amd64_state=True ;;
	esac

	# Fmt of radio btn: Bool                        "label str"                  value_when_selected 
	local OUT=$(yad --on-top  --center --title "Select the target machine to deploy via Qemu; press Esc / Cancel to keep the current one, or select a new target platform to build" \
			--width 500 --height 210  \
			--text "The current machine is the one that's now selected; press Esc / Cancel to keep the current one, or select a new target platform to build" \
			--list --radiolist --columns=3 \
			--column "   Select   " --column "   Machine   " --column "   Machine number - Do Not Display":HD  \
			${arm32_vexpress_state} "ARM-32 Versatile Express (vexpress-cortex a15)" arm32_vexpress   \
			${arm64_qemuvirt_state} "ARM-64 Qemu Virt" arm64_qemuvirt   \
			${arm64_rpi3b_cm3_state} "ARM-64 Raspberry Pi 3B (CM3)" arm64_rpi3b_cm3   \
			${amd64_state} "x86_64 (or AMD64) Qemu Virt" amd64   \
			--print-column=2 --print-column 3 \
			--buttons-layout=center --button="Select":2  --button=gtk-cancel:1)

	if [ -z "${OUT}" -o $? = "1" ]; then return; fi;  # Cancel clicked (or Esc); keep current m/c and return

	# Retrieve the just-selected machine
	local TARGET MACH=$(echo ${OUT} | cut -d '|' -f1) MACH_STR
	local MACH_CURR=$(echo ${CONFIG_CURR} |cut -d'.' -f3)
	# Short circuit, return if it's the same machine that's selected
	if [ "${MACH}" = "${MACH_CURR}" ]; then return; fi;

	# (Re)create the build.config soft link to point to the selected machine's config file
	#  ln [OPTION]... [-T] TARGET LINK_NAME
	case "${MACH}" in
	  arm32_vexpress) TARGET=build.config.arm32_vexpress
			  MACH_STR="AArch32: ARM Versatile Express for Cortex-A15" ;;
	  arm64_qemuvirt) TARGET=build.config.arm64_qemuvirt
			  MACH_STR="AArch64: (ARM-64) Qemu Virtual Machine" ;;
	  arm64_rpi3b_cm3) TARGET=build.config.arm64_rpi3b_cm3
			   MACH_STR="AArch32: Raspberry Pi 3B" ;;
	  amd64) TARGET=build.config.amd64
		 MACH_STR="x86-64 or AMD64: Qemu Standard PC (i440FX + PIIX, 1996)" ;;
	esac
	[[ ! -f ${TARGET} ]] && FatalError "Couldn't find the required build.config file : ${TARGET}"
	ln -sf ${TARGET} build.config || FatalError "Couldn't setup new build.config symlink"
	sync ; sleep .5  # ? but it MUST be refreshed via the 'source  ${BUILD_CONFIG_FILE}' below...
	BUILD_CONFIG_FILE=$(realpath ./build.config)
	[[ ! -f ${BUILD_CONFIG_FILE} ]] && FatalError "Couldn't setup new build.config (is the relevant config file present?)"
	# IMP : Must refresh (source) the newly selected config
	# Side effect: GUI_MODE can get reset to 0; so do a save & restore
	local saved_guimode=${GUI_MODE}
	source ${BUILD_CONFIG_FILE} || echo "*Warning* Couldn't source the just-set build.config file ${BUILD_CONFIG_FILE}"
	GUI_MODE=${saved_guimode}

	yad --center --title "Target Machine Confirmation" --text-info \
			--text="CONFIRM :: Target machine is now set to ${MACH_STR}" \
			--width 500 --height 50  \
			--wrap --justify=center --button=OK:0
#set +x
}

#---------- c o n f i g _ s e t u p -----------------------------------
# config_setup
# Based on values in the build.config file,
# display the current configurables, and,
# allow the end-user to _change_ what is done by the script now.
# The change applies ONLY for this run, i.e., it is volatile and NOT
# written into the build.config file.
# Parameters:
# -none-
config_setup()
{
 local msg1=""
 local gccver=$(${CXX}gcc --version |head -n1 |cut -f2- -d" ")

 report_progress

 msg1="
Config file : ${BUILD_CONFIG_FILE} -> $(basename "$(realpath ${BUILD_CONFIG_FILE})")\
 [edit it to change any settings shown below]
Config name : ${CONFIG_NAME_STR}

Toolchain prefix : ${CXX}
Toolchain version: ${gccver}
Staging folder   : ${STG}

CPU Arch     : ${ARCH}
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
 Terminal Colors mode: ${COLOR} | DEBUG mode: ${DEBUG} | VERBOSE mode: ${VERBOSE_MSG}
Log file            : ${LOGFILE_COMMON}"

local msg1_2="
-------------------------------------------------------------
To change any of the above configs, abort now and edit the
config file: ${BUILD_CONFIG_FILE}
-------------------------------------------------------------- "

 # Same message text for the yad GUI display - font attributes are added on...
 # !NOTE!   !Keep them - msg1 and msg1_yad - in SYNC!
 local msg1_yad="<b><i><span foreground='Crimson'>\
SEALS Config :: Please Review Carefully\
</span></i></b>
<span foreground='blue'>
Config file : ${BUILD_CONFIG_FILE} -> $(basename "$(realpath ${BUILD_CONFIG_FILE})")\
      <span foreground='red'><i>[edit it to change any settings shown below]</i></span>
Config name : ${CONFIG_NAME_STR}\
</span>
Staging folder   : ${STG}
<span foreground='blue'>\
Toolchain prefix : ${CXX}
Toolchain version: ${gccver}
</span>\
CPU Arch     : ${ARCH}
ARM Platform : ${ARM_PLATFORM_STR}
Platform RAM : ${SEALS_RAM} MB
<span foreground='blue'>\
RootFS force rebuild : ${RFS_FORCE_REBUILD}
RootFS size  : ${RFS_SZ_MB} MB     [note: new size applied only on 'RootFS force rebuild']
</span>\
Linux kernel to use : ${KERNELVER}
Linux kernel codebase location : ${KERNEL_FOLDER}
Kernel command-line : \"${SEALS_K_CMDLINE}\"
Verbose Build : ${VERBOSE_BUILD}
<span foreground='blue'>\
Busybox location: ${BB_FOLDER}
</span>\
Qemu: KGDB mode: ${KGDB_MODE} | SMP mode: ${SMP_EMU_MODE}
<span foreground='blue'>\
Diplay:
 Terminal Colors mode: ${COLOR} | DEBUG mode: ${DEBUG} | VERBOSE mode: ${VERBOSE_MSG}
</span>\
Log file            : ${LOGFILE_COMMON}
<span foreground='red'><b>
To change any of these, please abort now, edit the config file ${BUILD_CONFIG_FILE} \
appropriately, and rerun.\
</b></span>
<span foreground='crimson'><i>\
Press 'Yes' (or Enter) to proceed, 'No' (or Esc) to abort
</i></span>"


 if [ ${GUI_MODE} -eq 0 ] ; then
        becho "
[[ SEALS Config :: Please Review Carefully ]]"
	iecho "${msg1}"
	aecho "${msg1_2}"
	Prompt ""
 else
   #wecho "WIDTHxHT=$CAL_WIDTH x ${CAL_HT} "
   iecho "${msg1}"   # also show it on the terminal window..
   echo
#set -x
   YAD_COMMON_OPTS="--on-top  --center"
   yad ${YAD_COMMON_OPTS} --image "dialog-question" --title "${PRJ_TITLE} : $(basename "$(realpath ${BUILD_CONFIG_FILE})")" \
 	     --text "${msg1_yad}" \
         --button=gtk-yes:0 --button=gtk-no:1 \
		 --fixed
	 # Oh Wow! we need '--fixed' to keep the height sane and show the buttons !!
   local ret=$?
   echo "ret=$?"
   if [[ ${ret} -eq 1 || ${ret} -eq 252 ]] ; then
     aecho "Aborting. Edit the config file ${BUILD_CONFIG_FILE} as required and re-run."
     exit 1
   fi
 fi

if [ ${GUI_MODE} -eq 1 ] ; then
 #--- YAD
 local disp_kernel="FALSE"
 [ ${BUILD_KERNEL} -eq 1 ] && disp_kernel="TRUE"

 local disp_kwipe="FALSE"
 [ ${WIPE_KERNEL_CONFIG} -eq 1 ] && disp_kwipe="TRUE"

 local disp_rootfs="FALSE"
 [ ${BUILD_ROOTFS} -eq 1 ] && disp_rootfs="TRUE"

 local disp_bbwipe="FALSE"
 [ ${WIPE_BUSYBOX_CONFIG} -eq 1 ] && disp_bbwipe="TRUE"

 local disp_genrfsimg="FALSE"
 [ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && disp_genrfsimg="TRUE"

 local disp_bkp="FALSE"
 [ "${SAVE_BACKUP_IMG_CONFIGS}" -eq 1 ] && disp_bkp="TRUE"

 local disp_run="FALSE"
 [ ${RUN_QEMU} -eq 1 ] && disp_run="TRUE"

 local MSG_CONFIG_VOLATILE="The settings you make now are volatile, i.e., they will take
effect for ONLY this run. Once completed, the default (build.config) settings resume.
To change settings permenantly, please edit the build.config file.

* Wiping out the kernel / busybox config:
- only has an effect when the corresponding build option is selected
- if selected and wipe, implies that you will lose your existing config, of course.
"

 local yad_dothis=$(yad ${YAD_COMMON_OPTS} --form \
	--width 800 --height 220 \
   --field="Build Kernel (ver ${KERNELVER})":CHK \
   --field=" Wipe kernel config (Careful!*)":CHK \
   --field="Build Root Filesystem":CHK \
   --field=" Wipe busybox config (Careful!*)":CHK \
   --field="Generate Root Filesystem EXT4 image file":CHK \
   --field="Backup the kernel and root fs images and configs":CHK \
   --field="Run QEMU":CHK \
   ${disp_kernel} ${disp_kwipe} ${disp_rootfs} ${disp_bbwipe} \
   ${disp_genrfsimg} ${disp_bkp} ${disp_run} \
   --title="${PRJ_TITLE} : Configure this Run" \
   --center --width=${CAL_WIDTH} --on-top --no-escape \
   --text="<span foreground='blue'><i>${MSG_CONFIG_VOLATILE}</i></span>")

 BUILD_KERNEL=$(echo "${yad_dothis}" |awk -F"|" '{print $1}')
 WIPE_KERNEL_CONFIG=$(echo "${yad_dothis}" |awk -F"|" '{print $2}')
 BUILD_ROOTFS=$(echo "${yad_dothis}" |awk -F"|" '{print $3}')
 WIPE_BUSYBOX_CONFIG=$(echo "${yad_dothis}" |awk -F"|" '{print $4}')
 GEN_EXT4_ROOTFS_IMAGE=$(echo "${yad_dothis}" |awk -F"|" '{print $5}')
 SAVE_BACKUP_IMG_CONFIGS=$(echo "${yad_dothis}" |awk -F"|" '{print $6}')
 RUN_QEMU=$(echo "${yad_dothis}" |awk -F"|" '{print $7}')

 # yad has the (rather unpleasant) side-effect of changing our build
 # variables to the strings "TRUE" or "FALSE"; we'd like it to be integer
 # values 1 or 0.
 # Rationalize the 'build variables' to integer values
 [ "${BUILD_KERNEL}" = "TRUE" ] && BUILD_KERNEL=1 || BUILD_KERNEL=0
 [ "${WIPE_KERNEL_CONFIG}" = "TRUE" ] && WIPE_KERNEL_CONFIG=1 || WIPE_KERNEL_CONFIG=0
 [ "${BUILD_ROOTFS}" = "TRUE" ] && BUILD_ROOTFS=1 || BUILD_ROOTFS=0
 [ "${WIPE_BUSYBOX_CONFIG}" = "TRUE" ] && WIPE_BUSYBOX_CONFIG=1 || WIPE_BUSYBOX_CONFIG=0
 [ "${GEN_EXT4_ROOTFS_IMAGE}" = "TRUE" ] && GEN_EXT4_ROOTFS_IMAGE=1 || GEN_EXT4_ROOTFS_IMAGE=0
 [ "${SAVE_BACKUP_IMG_CONFIGS}" = "TRUE" ] && SAVE_BACKUP_IMG_CONFIGS=1 || SAVE_BACKUP_IMG_CONFIGS=0
 [ "${RUN_QEMU}" = "TRUE" ] && RUN_QEMU=1 || RUN_QEMU=0

 display_current_config

else # console mode

  seals_menu_consolemode
  becho "
  Confirm your choices please ::
"
  display_current_config

  echo
  get_yn_reply "Proceed? (if you say No, you can reenter choices)" y
  [ $? -eq 1 ] && seals_menu_consolemode
fi

} # end config_setup()

install_deb_pkgs()
{
 # For libncurses lib: have to take into account whether running on Ubuntu/Deb
 # or Fedora/RHEL/CentOS
 lsb_release -a|grep -w "Ubuntu" >/dev/null 2>&1
 if [ $? -ne 0 ] ; then
	echo "install_deb_pkgs(): this build host isn't Ubuntu/Debian, returning..."
	return
 fi
 # Ubuntu/Debian
 local pkg
 for pkg in "$@"
 do
    set +e  # Bash strict mode side effects
    dpkg -l |grep ${pkg} >/dev/null 2>&1
	  # don't use grep -q here: see https://stackoverflow.com/a/19120438/779269
    local ret=$? #; echo "ret=$ret"
    set -e
    if [ ${ret} -ne 0 ]; then
	   # installing libgmp3-dev libmpc-dev regardless of ARCH=arm here... should be ok?
	   sudo apt -y install ${pkg}
    fi
done
}

#--------- c h e c k _ i n s t a l l e d _ p k g ----------------------
#  + use superior checking func (fr CQuATS code)
# TODO
#  - gather and install required packages
#  - check for and install openssl-* (trouble is, the exact pkg name depends
#    on the distro [??])
check_installed_pkg()
{
 report_progress || true
#set -x
 # Toolchain
 set +e
 which ${CXX}gcc >/dev/null 2>&1
 res=$?
 set -e
 [[ ${res} -ne 0 ]] && {
   FatalError "
   There is an issue with the toolchain
   (as specified in your build.config: ${CXX}).
   *** It doesn't seem to be installed ***

We insist you install a complete proper toolchain (Linux x86_64 host to AArch32 or
AArch64 target) as appropriate. To do so, please read:

https://github.com/kaiwan/seals/wiki/SEALs-HOWTO

It has detailed instructions.

Thanks.
"
 }

 GCC_SYSROOT=$(${CXX}gcc --print-sysroot) || true
 if [[ "${ARCH_PLATFORM}" != "x86_64" ]] ; then
	if [ -z "${GCC_SYSROOT}" -o "${GCC_SYSROOT}" = "/" ] ; then
		FatalError "There is an issue with the provided toolchain.

It appears to not have the toolchain 'sysroot' libraries, sbin and usr
components within it. This could (and usually does) happen if it was installed
via a simple package manager cmd similar to 'sudo apt install ${ARCH}-linux-gnueabi'.

We insist you install a complete proper toolchain; to do so, please follow the
detailed instructions provided here:
https://github.com/kaiwan/seals/wiki/SEALs-HOWTO

Thanks.
"
   fi
fi

 which ${CXX}gcc > /dev/null || {
   FatalError "Cross toolchain does not seem to be valid! PATH issue?

Tip 1: If new to SEALS, we urge you, read the documentation here and then proceed:
 https://github.com/kaiwan/seals/wiki
 https://github.com/kaiwan/seals/wiki/SEALs-HOWTO

Tip 2: Install the cross toolchain first, update the build.config to reflect it and rerun.

Tip 3: (Less likely) This error can be thrown when you run the script with sudo (the
env vars are not setup. So run from a root shell where the PATH is correctly setup).
Aborting..."
 }

 [ "${ARCH}" = "arm" ] && QEMUPKG=qemu-system-arm
 [ "${ARCH}" = "arm64" ] && QEMUPKG=qemu-system-aarch64
 check_deps_fatal "${QEMUPKG} mkfs.ext4 lzop bison flex bc yad make"
  # lzop(1) required for the IMX6 kernel build
 [ ${GUI_MODE} -eq 1 ] && check_deps_fatal "yad xrandr"

## TODO : the dpkg & rpm -qa are very time consuming!
## so do this only on 'first-time'.

 # TODO - more pkgs to check for on these distros...
 if [ -f /etc/fedora-release ] || [ -f /etc/fedora ] ; then
  # Fedora/RHEL/CentOS - probably :)
  rpm -qa |grep ncurses-devel >/dev/null
  [ $? -ne 0 ] && {
     FatalError "The 'ncurses-devel' package does not seem to be installed.
(Required for kernel config UI).
Pl install the package (with dnf/yum/rpm) & re-run.  Aborting..."
   }
 else # Debian / Ubuntu - probably   :-)
	install_deb_pkgs libncurses-dev libssl-dev libgmp3-dev libmpc-dev
 fi

 # Terminal 'color' support?
 which tput > /dev/null || {
   COLOR=0
   wecho "tput does not seem to be installed, no color support..."
 } && {
   local numcolor=$(tput colors)
   [ ${numcolor} -ge 8 ] && COLOR=1
 }
} # end check_installed_pkg()
##----------------------------- Functions End -------------------------

testColor()
{
  ShowTitle "testing... KERNEL: Configure and Build [kernel ver ${KERNELVER}] now ..."
#  FatalError "Testing ; the libncurses-dev dev library and headers does not seem to be installed."
  Echo "Echo : a quick test ..."
  decho "decho : a quick test ..."
  iecho "cecho : a quick test ..."
  aecho "aecho : a quick test ..."
  wecho "wecho : a quick test ..."
  #fecho "wecho : a quick test ..."
  fg_grey;  echo "rep progres ..." 
  color_reset
}


### "main" here

mysudo  # warmup sudo
mysudo "SEALS Build:setup logfile ${LOGFILE_COMMON}. ${MSG_GIVE_PSWD_IF_REQD}" \
  touch ${LOGFILE_COMMON}
mysudo "" \
  chown ${USER}:${USER} ${LOGFILE_COMMON}

GUI_MODE=$(is_gui_supported) # || true
# If we pass '-c' on cmdline, force console mode
mode_opt=${1:--g}
if [ $# -ge 1 -a "${mode_opt}" = "-c" ] ; then
	GUI_MODE=0
fi
[ ${GUI_MODE} -eq 1 ] && echo "[+] Running in GUI mode.. (use '-c' option switch to run in console-only mode)" || echo "[+] Running in console mode.."
echo "[+] ${name}: initializing, please wait ..."

#testColor
#exit 0

which tput >/dev/null 2>&1 && color_reset
unalias cp 2>/dev/null || true

TESTMODE=0
[ ${TESTMODE} -eq 1 ] && {
  FatalError "some issue blah ..."
  exit 0
}

config_symlink_setup
check_installed_pkg
[ ${GUI_MODE} -eq 1 ] && gui_init

# NOTE: From now on we use the var ROOTFS_DIR as the rootfs dir
export ROOTFS_DIR=${ROOTFS}
[[ "${ARCH_PLATFORM}" = "x86_64" ]] && ROOTFS_DIR=${ROOTFS_PC}


###
# !NOTE!
# The script expects that these folders are pre-populated with 
# appropriate content, i.e., the source code for their resp projects:
# STG       : staging folder (where all build work happens)
#   KERNEL_FOLDER  : kernel source tree
#   BB_FOLDER      : busybox source tree
###
report_progress

[ ! -d ${STG} ] && {
	FatalError "
!!! SEALS Staging folder (STG) not present !!!
Currently, STG is set to \"${STG}\"

IMPORTANT ::
  Fix this by:
  - First verifying that the staging folder pathname is correct within your SEALS build config file
  - Then running the install script (install.sh).

FYI, we expect a project 'staging area' is setup and pre-populated with appropriate content,
i.e., the source code for their resp projects, as follows:
STG              : the project staging folder
     KERNEL_FOLDER  : kernel source tree
     BB_FOLDER      : busybox source tree

*You must fix this by running the install.sh script*

Tip: the place to update these folder pathnames is within the above-mentioned
config file.
"
}

check_folder_createIA ${ROOTFS_DIR}
check_folder_createIA ${IMAGES_FOLDER}
check_folder_createIA ${IMAGES_BKP_FOLDER}
check_folder_createIA ${CONFIGS_FOLDER}

config_setup

# Conditionally verify that the kernel and busybox src trees are indeed under STG
CHK_SRCTREES=""
[ ${BUILD_KERNEL} -eq 1 ] && CHK_SRCTREES="${KERNEL_FOLDER}/kernel"
[ ${BUILD_ROOTFS} -eq 1 ] && CHK_SRCTREES="${CHK_SRCTREES} ${BB_FOLDER}/applets"

i=1
for dir in ${CHK_SRCTREES}
do
  if [ ! -d ${dir} ] ; then
     [[ ${dir} = *kernel* ]] && {
	   err="kernel"
	   errdir=${KERNEL_FOLDER}
	} || {
	   err="busybox"
	   errdir=${BB_FOLDER}
	}
	FatalError "
We expect the ${err} source tree to be present here:
${errdir}

It appears to be invalid or missing!

IMPORTANT ::
  Fix this by:
  - First verifying that the ${err} source version is correct within your SEALS build config file
  - Then running the install script (install.sh).

"
  fi
  let i=i+1
done

### Which of the functions below run depends on the
# config specified in the Build Config file!
# So just set it there man ...
###
[ ${BUILD_KERNEL} -eq 1 ] && {
  check_folder_AIA ${KERNEL_FOLDER}
  set_kernelimg_var
  build_kernel
}
[ ${BUILD_ROOTFS} -eq 1 ] && {
  [[ ! -d ${BB_FOLDER} ]] && FatalError "Busybox source folder not found?"
  build_rootfs
}
[ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && {
  # First ensure that kernel modules have been generated into the rootfs
  if [[ ${BUILD_KERNEL} -eq 0 ]] ; then
     [[ -z $(ls -A ${ROOTFS_DIR}/lib/modules/"$(kernel_uname_r)") ]] && install_kernel_modules
  fi
  generate_rootfs_img_ext4
}
[ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && save_images_configs
[ ${RUN_QEMU} -eq 1 ] && run_qemu_SEALS

aecho "${MSG_EXITING}"
color_reset
exit 0
