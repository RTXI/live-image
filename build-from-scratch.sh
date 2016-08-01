#! /bin/bash

set -e

################################################################################
# The Real-Time eXperiment Interface (RTXI)
# Copyright (C) 2011 Georgia Institute of Technology, University of Utah, Weill 
# Cornell Medical College
#
# This program is free software: you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation, either version 3 of the License, or (at your option) any later 
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more 
# details.
#
# You should have received a copy of the GNU General Public License along with 
# this program.  If not, see <http://www.gnu.org/licenses/>.
################################################################################

echo "Building Ubuntu Live CD from scratch."

###############################################################################
# Install dependencies
###############################################################################

echo "Checking for dependencies..."
sudo apt-get -y install genisoimage squashfs-tools syslinux

###############################################################################
# Global variables go here. 
#
# NOTES: 
#  * UBUNTU_VERSION only works with the most recent LTS release, so the script 
#    can break when a new version comes out unless the variable is updated. 
#  * the options for UBUNTU_VERSION are: ubuntu, lubuntu, kubuntu, ubuntukylin 
#    ubuntu-core (probably won't work), ubuntu-gnome, and xubuntu.
###############################################################################

RTXI_VERSION=2.1
XENOMAI_VERSION=3.0.2
KERNEL_VERSION=4.1.18
UBUNTU_VERSION=14.04.4 # keep this updated!
UBUNTU_FLAVOR=ubuntu-gnome

ROOT=$(pwd)
BUILD=build_$(date +%F_%T)
ARCH="amd64"

###############################################################################
# Download and extract a generic Ubuntu image. 
###############################################################################

if [ ! -d image_chroots ]; then mkdir image_chroots; fi
cd image_chroots
mkdir ${BUILD}
cd ${BUILD}

if [ "$UBUNTU_FLAVOR" = "ubuntu" ]; then
	wget http://releases.ubuntu.com/$UBUNTU_VERSION/$UBUNTU_FLAVOR-$UBUNTU_VERSION-desktop-$ARCH.iso
else
	wget http://cdimage.ubuntu.com/$UBUNTU_FLAVOR/releases/$UBUNTU_VERSION/release/$UBUNTU_FLAVOR-$UBUNTU_VERSION-desktop-$ARCH.iso
fi

EXIT_STATUS=$?
if [ $EXIT_STATUS != 0 ]; then 
	echo "Live CD Download failed... exiting"
	exit $EXIT_STATUS 
fi

# Get started and extract the iso
mkdir mnt extract
sudo mount -o loop $UBUNTU_FLAVOR-$UBUNTU_VERSION-desktop-$ARCH.iso mnt/
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract
sudo unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit
sudo umount mnt/

###############################################################################
# Prepare the chroot environment. 
###############################################################################

# Copy over the network configuration file. It's in different places in 
# different distros.
if [ $(lsb_release -is) == "Debian" ]; then
	sudo cp /etc/resolv.conf edit/run/resolvconf/resolv.conf
elif [ $(lsb_release -is) == "Ubuntu" ]; then
	sudo cp /run/resolvconf/resolv.conf edit/run/resolvconf/resolv.conf
fi

# Copy pre-compiled RT kernel deb files from the deb_files/ folder
sudo cp $ROOT/deb_files/*.deb edit/root/ 

# Enter the chroot
echo "Time to chroot this mother."
echo "(This may take a while. Go outside. Frolic. Eat a sandwich.)"
sudo mount --bind /dev/ edit/dev

# Copy the chroot script into the chroot environment
sudo cp $ROOT/chroot-script.sh edit/ 

###############################################################################
# CHROOT! 
###############################################################################

sudo chroot edit ./chroot-script.sh $RTXI_VERSION $XENOMAI_VERSION \
	$KERNEL_VERSION $UBUNTU_VERSION $UBUNTU_FLAVOR

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
if [ "$ARCH" = "amd64" ]; then
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

sudo genisoimage -D -r -V "RTXI" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../rtxi-$RTXI_VERSION-$UBUNTU_FLAVOR-$UBUNTU_VERSION-$ARCH.iso . 
sudo isohybrid ../rtxi-$RTXI_VERSION-$UBUNTU_FLAVOR-$UBUNTU_VERSION-$ARCH.iso

echo "Done."
