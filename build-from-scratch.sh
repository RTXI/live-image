#! /bin/bash

echo "Building Ubuntu Live CD from scratch."

###############################################################################
# Install dependencies
###############################################################################

echo "Checking for dependencies first. (It's possible I forgot to add one.)"
sudo apt-get -y install genisoimage squashfs-tools syslinux

###############################################################################
# Global variables go here. 
###############################################################################

XENOMAI_VERSION=2.6.4
KERNEL_VERSION=3.8.13
UBUNTU_VERSION=14.04.3

ROOT=$(pwd)
BUILD=build_$(date +%F_%T)
if [ "$(uname -m)" == "x86_64" ]; then
	ARCH="amd64"
else
	ARCH="i386"
fi

###############################################################################
# Download and extract a generic Ubuntu image. 
###############################################################################

if [ ! -d image_chroots]; then mkdir image_chroots; fi
cd image_chroots
mkdir ${BUILD}
cd ${BUILD}

if [ $ARCH == "amd64" ]; then
#	wget --no-check-certificate http://cdimage.ubuntu.com/ubuntu-gnome/releases/trusty/release/ubuntu-gnome-$UBUNTU_VERSION-desktop-amd64.iso
	wget --no-check-certificate http://cdimage.ubuntu.com/lubuntu/releases/$UBUNTU_VERSION/release/lubuntu-$UBUNTU_VERSION-desktop-amd64.iso
else
#	wget --no-check-certificate http://cdimage.ubuntu.com/ubuntu-gnome/releases/trusty/release/ubuntu-gnome-$UBUNTU_VERSION-desktop-i386.iso
	wget --no-check-certificate http://cdimage.ubuntu.com/lubuntu/releases/$UBUNTU_VERSION/release/lubuntu-$UBUNTU_VERSION-desktop-i386.iso
fi

# Get started and extract the iso
mkdir mnt extract
sudo mount -o loop *.iso mnt/
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract
sudo unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit
sudo umount mnt/

###############################################################################
# Prepare the chroot environment. 
###############################################################################

# Prepare to chroot into the extracted iso
#sudo cp /etc/resolv.conf edit/run/resolvconf/resolv.conf <-For non-ubuntu systems
sudo cp /run/resolvconf/resolv.conf edit/run/resolvconf/resolv.conf
sudo cp /etc/apt/sources.list edit/etc/apt/sources.list # the live-cd sources.list is incomplete, so replace it with your own
sudo cp $ROOT/deb_files/*.deb edit/root/ # assumes pre-compiled rt kernel *.deb files are in deb_files/
#sudo cp -r /usr/xenomai edit/usr/
# ^- this can cause problems later...

# Enter the chroot
echo "Time to chroot this mother."
echo "(This may take a while. Go outside. Frolic. Eat a sandwich.)"
sudo mount --bind /dev/ edit/dev
sudo cp $ROOT/chroot-script.sh edit/ # copy the chroot script into the chroot environment

###############################################################################
# CHROOT! 
###############################################################################

sudo chroot edit ./chroot-script.sh

###############################################################################
# Exit chroot and clean up a bit. 
###############################################################################

sudo umount edit/dev
sudo rm edit/chroot-script.sh

###############################################################################
# Update the image md5sum, package lists, etc. with changed introduced by the
# chroot script, and then regenerate a compressed squashfs filesystem. 
#
# Also, overwrite the casper boot image with the RT-aufs versions. 
###############################################################################

sudo bash -c "chroot edit dpkg-query -W > extract/casper/filesystem.manifest"
if [ $ARCH == "amd64" ]; then
	sudo cp edit/boot/vmlinuz-$KERNEL_VERSION-xenomai-$XENOMAI_VERSION-aufs extract/casper/vmlinuz.efi
else
	sudo cp edit/boot/vmlinuz-$KERNEL_VERSION-xenomai-$XENOMAI_VERSION-aufs extract/casper/vmlinuz
fi
sudo cp edit/boot/initrd.img-$KERNEL_VERSION-xenomai-$XENOMAI_VERSION-aufs extract/casper/initrd.lz
sudo mksquashfs edit extract/casper/filesystem.squashfs -comp xz
sudo bash -c "printf $(sudo du -sx --block-size=1 edit | cut -f1) > extract/casper/filesystem.size"

cd extract
sudo bash -c "find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt"

###############################################################################
# Create a new hybrid *.iso and make it bootable from USB (thanks to syslinux)
###############################################################################

sudo genisoimage -D -r -V "RTXI" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../rtxi-ubuntu-$ARCH.iso . 
sudo isohybrid ../rtxi-ubuntu-$ARCH.iso

echo "Done."
