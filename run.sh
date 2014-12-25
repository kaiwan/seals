# Using the "-smp n,sockets=n" QEMU options lets us emulate n processors!
# (can do this with n=2 for the ARM Cortex-A9)
PFX=/home/kaiwan/ARM_Balau

[ $# -ne 1 ] && {
  echo "
Usage: $0 opt=0|1
 0 => nographics mode
 1 => graphics mode"
  exit 1
}

# Rootfs is now a non-volatile image on an (emulated) SD card!
if [ $1 = "0" ]; then 
  qemu-system-arm -m 256 -M vexpress-a9 -kernel ${PFX}/images/zImage -drive file=${PFX}/images/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic
else
  qemu-system-arm -m 256 -M vexpress-a9 -kernel ${PFX}/images/zImage -drive file=${PFX}/images/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init"
fi
 

#qemu-system-arm -m 256 -M vexpress-a9 -kernel images/zImage -initrd images/rootfs.img.gz -append "console=ttyAMA0 rdinit=/sbin/init" -nographic
 # rm 'root=/dev/ram' ; not really necessary as we always use a ramdisk & never a real rootfs..
