#! /usr/bin/bash

# Get started and extract the iso
mkdir mnt extract
mount -o loop *iso mnt/
rsync --exclude=/live/filesystem.squashfs -a mnt/ extract
unsquashfs mnt/live/filesystem.squashfs
mv squashfs-root edit
umount mnt/

# Prepare to chroot into the extracted iso
cp /etc/resolv.conf edit/etc/

# chroot
mount --bind /dev/ edit/dev
chroot edit

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C

# do extra stuff here

umount /proc /sys /dev/pts
exit

umount edit/dev
sudo bash -c "chroot edit dpkg-query -W  > extract/live/filesystem.packages"
cp edit/boot/vmlinuz-3.16.0-4-amd64 extract/live/vmlinuz
cp edit/boot/initrd.img-3.16.0-4-amd64 extract/live/initrd.img
mksquashfs edit extract/live/filesystem.squashfs -comp xz

# don't know if this is necessary
sudo bash -c "find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt"

#xorriso -as mkisofs -r -J -joliet-long -l -cache-inodes -isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin -partition_offset 16 -A "RTXI Live"  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o rtxi-2.0-debian-8.0-v1-x86_64.iso binary

genisoimage -D -r -V "RTXI" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../custom.iso . 
