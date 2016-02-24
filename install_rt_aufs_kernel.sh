#!/bin/bash

#
# The Real-Time eXperiment Interface (RTXI)
# Copyright (C) 2011 Georgia Institute of Technology, University of Utah, Weill Cornell Medical College
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#	Created by Yogi Patel <yapatel@gatech.edu> 2014.1.31
#

if ! id | grep -q root; then
  echo "Must run script as root; try again with sudo ./install_rt_kernel.sh"
	exit
fi

# Export environment variables
echo  "----->Setting up variables"
export BASE=$(pwd)
export LINUX_VERSION=3.8.13
export LINUX_TREE=linux-$LINUX_VERSION

export XENOMAI_VERSION=2.6.4
export XENOMAI_ROOT=xenomai-$XENOMAI_VERSION

export AUFS_VERSION=3.8
export AUFS_ROOT=aufs-$AUFS_VERSION

export SCRIPTS_DIR=`pwd`

export BUILD_ROOT=build

rm -rf $BUILD_ROOT
rm -rf $LINUX_TREE
rm -rf $XENOMAI_ROOT
mkdir $BUILD_ROOT

if [ $? -eq 0 ]; then
	echo  "----->Environment configuration complete"
else
	echo  "----->Environment configuration failed"
	exit
fi

# Download essentials
echo  "----->Downloading Linux kernel"
cd $BASE
wget --no-check-certificate https://www.kernel.org/pub/linux/kernel/v3.x/linux-$LINUX_VERSION.tar.bz2
tar xf linux-$LINUX_VERSION.tar.bz2

echo  "----->Downloading Xenomai"
wget --no-check-certificate http://download.gna.org/xenomai/stable/xenomai-$XENOMAI_VERSION.tar.bz2
tar xf xenomai-$XENOMAI_VERSION.tar.bz2

if [ $? -eq 0 ]; then
	echo  "----->Downloads complete"
else
	echo  "----->Downloads failed"
	exit
fi

# Patch kernel
echo  "----->Patching aufs kernel"
cd $BASE
git clone git://git.code.sf.net/p/aufs/aufs3-standalone aufs-$AUFS_VERSION
cd $AUFS_ROOT
git checkout origin/aufs$AUFS_VERSION
cd $LINUX_TREE
patch -p1 < $AUFS_ROOT/aufs3-kbuild.patch && \
patch -p1 < $AUFS_ROOT/aufs3-base.patch && \
patch -p1 < $AUFS_ROOT/aufs3-mmap.patch && \
patch -p1 < $AUFS_ROOT/aufs3-standalone.patch
cp -r $AUFS_ROOT/Documentation $LINUX_TREE
cp -r $AUFS_ROOT/fs $LINUX_TREE
cp $AUFS_ROOT/include/uapi/linux/aufs_type.h $LINUX_TREE/include/uapi/linux/
cp $AUFS_ROOT/include/uapi/linux/aufs_type.h $LINUX_TREE/include/linux/

echo  "----->Patching xenomai onto kernel"
cd $LINUX_TREE
cp -vi /boot/config-`uname -r` $LINUX_TREE/.config
$XENOMAI_ROOT/scripts/prepare-kernel.sh --arch=x86 --adeos=$XENOMAI_ROOT/ksrc/arch/x86/patches/ipipe-core-$LINUX_VERSION-x86-*.patch --linux=$LINUX_TREE
yes "" | make oldconfig
make menuconfig

if [ $? -eq 0 ]; then
	echo  "----->Patching complete"
else
	echo  "----->Patching failed"
	exit
fi

# Compile kernel
echo  "----->Compiling kernel"
cd $LINUX_TREE
export CONCURRENCY_LEVEL=$(grep -c ^processor /proc/cpuinfo)
fakeroot make-kpkg --initrd --append-to-version=-xenomai-$XENOMAI_VERSION-aufs --revision $(date +%Y%m%d) kernel-image kernel-headers modules

if [ $? -eq 0 ]; then
	echo  "----->Kernel compilation complete."
else
	echo  "----->Kernel compilation failed."
	exit
fi

exit

## Install compiled kernel
#echo  "----->Installing compiled kernel"
#cd $BASE
#sudo dpkg -i linux-image-*.deb
#sudo dpkg -i linux-headers-*.deb
#
#if [ $? -eq 0 ]; then
#	echo  "----->Kernel installation complete"
#else
#	echo  "----->Kernel installation failed"
#	exit
#fi
#
## Update
#echo  "----->Updating boot loader about the new kernel"
#cd $LINUX_TREE
#sudo update-initramfs -c -k $LINUX_VERSION-xenomai-$XENOMAI_VERSION-aufs
#sudo update-grub
#
#if [ $? -eq 0 ]; then
#	echo  "----->Boot loader update complete"
#else
#	echo  "----->Boot loader update failed"
#	exit
#fi
#
## Install user libraries
#echo  "----->Installing user libraries"
#cd $BUILD_ROOT
#$XENOMAI_ROOT/configure --enable-shared --enable-smp --enable-x86-sep
#make -s
#sudo make install
#
#if [ $? -eq 0 ]; then
#	echo  "----->User library installation complete"
#else
#	echo  "----->User library installation failed"
#	exit
#fi
#
## Setting up user permissions
#echo  "----->Setting up user/group"
#sudo groupadd xenomai
#sudo usermod -aG xenomai `whoami`
#
#if [ $? -eq 0 ]; then
#	echo  "----->Group setup complete"
#else
#	echo  "----->Group setup failed"
#	exit
#fi
#
## Restart
#echo  "----->Kernel patch complete."
#echo  "----->Reboot to boot into RT kernel."
