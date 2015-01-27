# Part of the SEALs project
# (c) kaiwanTECH
# Loop Mount the QEMU ext4 fs 
# so that one can update it..
IMG=staging/images/rfs.img
MNTPT=/mnt/tmp

[ $(id -u) -ne 0 ] && {
 echo "$0: need to be root."
 exit 1
}

mount |grep -i ${MNTPT} >/dev/null && {
  sync
  umount ${MNTPT}
}
mkdir -p ${MNTPT}
mount -o loop -t ext4 ${IMG} ${MNTPT} && {
 echo "${IMG} loop mounted at ${MNTPT}"
 echo "Update fs contents, then umount it..."
 ls ${MNTPT}
} || {
 echo "${IMG} loop mounting failed! aborting..."
 exit 1
}
# Once done updating, just umount & try w/ QEMU!

