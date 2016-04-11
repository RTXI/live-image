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

################################################################################
# Export environment variables. The kernel will be downloaded and build in the 
# directory where this script is run. 
################################################################################
echo  "----->Setting up variables"

BASE=/opt/
LINUX_VERSION=4.1.18
LINUX_TREE=$BASE/linux-$LINUX_VERSION

XENOMAI_VERSION=3.0.2
XENOMAI_ROOT=$BASE/xenomai-$XENOMAI_VERSION

AUFS_VERSION=4.1
AUFS_ROOT=$BASE/aufs-$AUFS_VERSION

BUILD_ROOT=$BASE/build

DEB_FILES=$BASE/deb_files/

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

################################################################################
# Download all software needed to patch a real-time, aufs-enabled kernel. 
################################################################################
echo  "----->Downloading Linux kernel"
cd $BASE
if [[ "$LINUX_VERSION" =~ "3." ]]; then 
	wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-$LINUX_VERSION.tar.xz
elif [[ "$LINUX_VERSION" =~ "4." ]]; then
	wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-$LINUX_VERSION.tar.xz
else
	echo "Kernel specified in the \$LINUX_VERSION variable needs to be 3.x or 4.x"
	exit 1
fi
tar xf linux-$LINUX_VERSION.tar.xz

echo  "----->Downloading Xenomai"
wget https://xenomai.org/downloads/xenomai/stable/xenomai-$XENOMAI_VERSION.tar.bz2
tar xf xenomai-$XENOMAI_VERSION.tar.bz2

if [ $? -eq 0 ]; then
	echo  "----->Downloads complete"
else
	echo  "----->Downloads failed"
	exit
fi

# Download kernel config
#wget --no-check-certificate http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.14.17-utopic/linux-image-3.14.17-031417-generic_3.14.17-031417.201408132253_amd64.deb
#dpkg-deb -x linux-image-3.14.17-031417-generic_3.14.17-031417.201408132253_amd64.deb linux-image
#cp linux-image/boot/config-$LINUX_VERSION-* $LINUX_TREE/.config
wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.1.18-wily/linux-image-4.1.18-040118-generic_4.1.18-040118.201602160131_amd64.deb
dpkg-deb -x linux-image-4.1.18-040118-generic_4.1.18-040118.201602160131_amd64.deb linux-$LINUX_VERSION-image
cp linux-$LINUX_VERSION-image/boot/config-$LINUX_VERSION-* $LINUX_TREE/.config

#cp /boot/config-$(uname -r) $LINUX_TREE/.config # needs work.

################################################################################
# Patch Aufs. Aufs enables the kernel to be booted in a live environment. 
# Without it, the live CD would be unusable. 
################################################################################
echo  "----->Patching aufs kernel"
cd $BASE
if [[ "$AUFS_VERSION" =~ "3." ]]; then 
	git clone git://git.code.sf.net/p/aufs/aufs3-standalone aufs-$AUFS_VERSION
elif [[ "$AUFS_VERSION" =~ "4." ]]; then
	git clone git://github.com/sfjro/aufs4-standalone.git aufs-$AUFS_VERSION
else
	echo "Aufs version specified in the \$AUFS_VERSION variable needs to be 3.x or 4.x"
	exit 1
fi

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

################################################################################
# Patch Xenomai 2 or 3. The script will detect the version and prepare the 
# kernel as needed. 
################################################################################
echo  "----->Patching xenomai onto kernel"
cd $LINUX_TREE
if [[ "$XENOMAI_VERSION" =~ "2.6" ]]; then 
	$XENOMAI_ROOT/scripts/prepare-kernel.sh --arch=x86 --adeos=$XENOMAI_ROOT/ksrc/arch/x86/patches/ipipe-core-$LINUX_VERSION-x86-?.patch --linux=$LINUX_TREE
elif [[ "$XENOMAI_VERSION" =~ "3." ]]; then
	$XENOMAI_ROOT/scripts/prepare-kernel.sh --arch=x86 --adeos=$XENOMAI_ROOT/kernel/cobalt/arch/x86/patches/ipipe-core-$LINUX_VERSION-x86-?.patch --linux=$LINUX_TREE
else
	echo "Xenomai version specified in the \$XENOMAI_VERSION variable needs to be 2.6.x or 3.x"
	exit 1
fi

################################################################################
# Compile the kernel. The menuconfig options are the same as for a standard RT 
# kernel, except that you need to enable the Aufs module: 
# 
# Filesystems ->
#   Miscellaneous Filesystems ->
#     [M] Aufs
################################################################################
yes "" | make oldconfig
make menuconfig

if [ $? -eq 0 ]; then
	echo  "----->Patching complete"
else
	echo  "----->Patching failed"
	exit
fi

echo  "----->Compiling kernel"
cd $LINUX_TREE
export CONCURRENCY_LEVEL=$(nproc)
fakeroot make-kpkg --initrd --append-to-version=-xenomai-$XENOMAI_VERSION-aufs --revision $(date +%Y%m%d) kernel-image kernel-headers modules

if [ $? -eq 0 ]; then
	echo  "----->Kernel compilation complete."
else
	echo  "----->Kernel compilation failed."
	exit
fi

cp linux-image-$LINUX_VERSION-xenomai-$XENOMAI_VERSION_*.deb $DEB_FILES
cp linux-headers-$LINUX_VERSION-xenomai-$XENOMAI_VERSION_*.deb $DEB_FILES

################################################################################
# All you need to do for a live CD is have a compiled kernel. You don't need to 
# install it on your own computer. If you want to anyway, delete the exit 
# command and let the code below run. 
################################################################################

exit 0  # Delete this line to continue. 

echo  "----->Installing compiled kernel"
cd $BASE
dpkg -i linux-image-$LINUX_VERSION-xenomai-$XENOMAI_VERSION_*.deb
dpkg -i linux-headers-$LINUX_VERSION-xenomai-$XENOMAI_VERSION_*.deb

if [ $? -eq 0 ]; then
	echo  "----->Kernel installation complete"
else
	echo  "----->Kernel installation failed"
	exit
fi

echo  "----->Updating boot loader about the new kernel"
cd $LINUX_TREE
update-initramfs -c -k $LINUX_VERSION-xenomai-$XENOMAI_VERSION-aufs
update-grub

if [ $? -eq 0 ]; then
	echo  "----->Boot loader update complete"
else
	echo  "----->Boot loader update failed"
	exit
fi

exit

# Install Xenomai libraries. 
echo  "----->Installing user libraries"
cd $BUILD_ROOT
if [[ "$XENOMAI_VERSION" =~ "2.6" ]]; then 
	$XENOMAI_ROOT/configure --enable-shared --enable-smp --enable-x86-sep
elif [[ "$XENOMAI_VERSION" =~ "3." ]]; then
	$XENOMAI_ROOT/configure --with-core=cobalt --enable-pshared --enable-smp --enable-x86-vsyscall --enable-dlopen-libs
else
	echo "Xenomai version specified in the \$XENOMAI_VERSION variable needs to be 2.6.x or 3.x"
	exit 1
fi
make -s
make install

if [ $? -eq 0 ]; then
	echo  "----->User library installation complete"
else
	echo  "----->User library installation failed"
	exit
fi

# Restart
echo  "----->Kernel patch complete."
echo  "----->Reboot to boot into RT kernel."
