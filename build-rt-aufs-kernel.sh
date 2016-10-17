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

if ! id | grep -q root; then
	echo "Must run script as root; try again with sudo ./install_rt_kernel.sh"
	exit
fi


################################################################################
# Set base variables. 
################################################################################

ARCH=amd64
LINUX_VERSION=3.8.13
XENOMAI_VERSION=2.6.4


################################################################################
# Calculate other variables. 
################################################################################

echo  "----->Setting up variables"

BASE=/opt
SCRIPT_DIR=$(pwd)

LINUX_TREE=$BASE/linux-$LINUX_VERSION

# Hard-code some kernel config urls
LINUX_CONFIG_URL=""
if [ $LINUX_VERSION = "4.1.18" ]; then
	LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.1.18-wily/linux-image-4.1.18-040118-generic_4.1.18-040118.201602160131_$ARCH.deb"
elif [ $LINUX_VERSION = "3.18.20" ]; then
	LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.18.20-vivid/linux-image-3.18.20-031820-generic_3.18.20-031820.201508081633_$ARCH.deb"
elif [ $LINUX_VERSION = "3.8.13" ]; then
	LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.8.13.28-raring/linux-image-3.8.13-03081328-generic_3.8.13-03081328.201409030938_$ARCH.deb"
fi

XENOMAI_ROOT=$BASE/xenomai-$XENOMAI_VERSION

AUFS_VERSION=${LINUX_KERNEL%.*}
AUFS_ROOT=$BASE/aufs-$AUFS_VERSION

BUILD_ROOT=$BASE/build

DEB_FILES=$SCRIPT_DIR/deb_files

rm -rf $BUILD_ROOT
rm -rf $LINUX_TREE
rm -rf $XENOMAI_ROOT
rm -rf $AUFS_ROOT
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
	if ! [ -f "linux-$LINUX_VERSION.tar.xz" ]; then
		wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-$LINUX_VERSION.tar.xz
	fi
elif [[ "$LINUX_VERSION" =~ "4." ]]; then
	if ! [ -f "linux-$LINUX_VERSION.tar.xz" ]; then
		wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-$LINUX_VERSION.tar.xz
	fi
else
	echo "Kernel specified in the \$LINUX_VERSION variable needs to be 3.x or 4.x"
	exit 1
fi
tar xf linux-$LINUX_VERSION.tar.xz

echo  "----->Downloading Xenomai"
if ! [ -f "xenomai-$XENOMAI_VERSION.tar.bz2" ]; then
	wget https://xenomai.org/downloads/xenomai/stable/xenomai-$XENOMAI_VERSION.tar.bz2
fi
tar xf xenomai-$XENOMAI_VERSION.tar.bz2

if [ $? -eq 0 ]; then
	echo  "----->Downloads complete"
else
	echo  "----->Downloads failed"
	exit
fi

# Download kernel config
if [ "$LINUX_CONFIG_URL" != "" ]; then
	wget $LINUX_CONFIG_URL
	if [ $? -eq 0 ]; then
		dpkg-deb -x ${LINUX_CONFIG_URL##*/} linux-$LINUX_VERSION-image
		cp linux-$LINUX_VERSION-image/boot/config-$LINUX_VERSION-* $LINUX_TREE/.config
	else
		echo "wget failed to get $LINUX_CONFIG_URL"
		echo "   defaulting to /boot/config-$(uname -r)"
		cp /boot/config-$(uname -r) $LINUX_TREE/.config 
	fi
else
	#cp /boot/config-$(uname -r) $LINUX_TREE/.config 
   cd $LINUX_TREE
   make defconfig
fi


################################################################################
# Patch Aufs. Aufs enables the kernel to be booted in a live environment. 
# Without it, the live CD would be unusable. 
################################################################################

echo  "----->Patching aufs kernel"
cd $BASE
if [[ "$AUFS_VERSION" =~ "3." ]]; then 
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
elif [[ "$AUFS_VERSION" =~ "4." ]]; then
	git clone git://github.com/sfjro/aufs4-standalone.git aufs-$AUFS_VERSION
	cd $AUFS_ROOT
	git checkout origin/aufs$AUFS_VERSION
	cd $LINUX_TREE
	patch -p1 < $AUFS_ROOT/aufs4-kbuild.patch && \
	patch -p1 < $AUFS_ROOT/aufs4-base.patch && \
	patch -p1 < $AUFS_ROOT/aufs4-mmap.patch && \
	patch -p1 < $AUFS_ROOT/aufs4-standalone.patch
	cp -r $AUFS_ROOT/Documentation $LINUX_TREE
	cp -r $AUFS_ROOT/fs $LINUX_TREE
	cp $AUFS_ROOT/include/uapi/linux/aufs_type.h $LINUX_TREE/include/uapi/linux/
	cp $AUFS_ROOT/include/uapi/linux/aufs_type.h $LINUX_TREE/include/linux/
else
	echo "Aufs version specified in the \$AUFS_VERSION variable needs to be 3.x or 4.x"
	exit 1
fi


################################################################################
# Patch Xenomai 2 or 3. The script will detect the version and prepare the 
# kernel as needed. 
################################################################################

echo  "----->Patching xenomai onto kernel"
cd $LINUX_TREE
if [[ "$XENOMAI_VERSION" =~ "2.6" ]]; then 
	$XENOMAI_ROOT/scripts/prepare-kernel.sh --arch=x86 --adeos=$XENOMAI_ROOT/ksrc/arch/x86/patches/ipipe-core-$LINUX_VERSION-x86-[0-9]*.patch --linux=$LINUX_TREE
elif [[ "$XENOMAI_VERSION" =~ "3." ]]; then
	$XENOMAI_ROOT/scripts/prepare-kernel.sh --arch=x86 --adeos=$XENOMAI_ROOT/kernel/cobalt/arch/x86/patches/ipipe-core-$LINUX_VERSION-x86-[0-9]*.patch --linux=$LINUX_TREE
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

cp $BASE/linux-image-$LINUX_VERSION-xenomai-$XENOMAI_VERSION_*.deb $DEB_FILES
cp $BASE/linux-headers-$LINUX_VERSION-xenomai-$XENOMAI_VERSION_*.deb $DEB_FILES


################################################################################
# All you need to do for a live CD is have a compiled kernel. You don't need to 
# install it on your own computer. If you want to anyway, delete the exit 
# command and let the code below run. 
################################################################################

exit

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
