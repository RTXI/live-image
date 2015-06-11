#! /bin/bash

echo "Building Ubuntu Live CD from scratch."

ROOT=$(pwd)
BUILD=build_$(date +%F_%T)
if [ "$(uname -m)" == "x86_64" ]; then
	ARCH="amd64"
else
	ARCH="i386"
fi

mkdir image_chroots
cd image_chroots
mkdir ${BUILD}
cd ${BUILD}

if [ $ARCH == "amd64" ]; then
	wget --nio-check-certificate http://cdimage.ubuntu.com/ubuntu-gnome/releases/14.04.2/release/ubuntu-gnome-14.04.2-desktop-amd64.iso
else
	wget --no-check-certificate http://cdimage.ubuntu.com/ubuntu-gnome/releases/14.04.2/release/ubuntu-gnome-14.04.2-desktop-i386.iso
fi

# Get started and extract the iso
mkdir mnt extract
sudo mount -o loop *.iso mnt/
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract
sudo unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit
sudo umount mnt/

# Prepare to chroot into the extracted iso
#sudo cp /etc/resolv.conf edit/run/resolvconf/resolv.conf <-For non-ubuntu systems
sudo cp /run/resolvconf/resolv.conf edit/run/resolvconf/resolv.conf
sudo cp /etc/apt/sources.list edit/etc/apt/sources.list
sudo cp $ROOT/deb_files/*.deb edit/root/
# ^-THIS IS WRONG
sudo cp -r /usr/xenomai edit/usr/
# ^- this can cause problems later...

# Enter the chroot
echo "Time to chroot this mother."
echo "(This could take a while.)"
sudo mount --bind /dev/ edit/dev
sudo cp $ROOT/chroot-script.sh edit/
sudo chroot edit ./chroot-script.sh

# Exit the chroot
sudo umount edit/dev
sudo rm edit/chroot-script.sh

# Update the filesystem.manifest
sudo bash -c "chroot edit dpkg-query -W > extract/casper/filesystem.manifest"
if [ $ARCH == "amd64" ]; then
	sudo cp edit/boot/vmlinuz-3.8.13-xenomai-2.6.3-aufs extract/casper/vmlinuz.efi
else
	sudo cp edit/boot/vmlinuz-3.8.13-xenomai-2.6.3-aufs extract/casper/vmlinuz
fi
sudo cp edit/boot/initrd.img-3.8.13-xenomai-2.6.3-aufs extract/casper/initrd.lz
sudo mksquashfs edit extract/casper/filesystem.squashfs -comp xz
sudo bash -c "printf $(sudo du -sx --block-size=1 edit | cut -f1) > extract/casper/filesystem.size"

cd extract
sudo bash -c "find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt"

sudo genisoimage -D -r -V "RTXI" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../rtxi-ubuntu-$ARCH.iso . 
sudo isohybrid ../rtxi-ubuntu-$ARCH.iso

echo "Done...maybe."
