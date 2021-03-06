#! /bin/bash
set -eu

################################################################################
# The Real-Time eXperiment Interface (RTXI)
#
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
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more 
# details.
#
# You should have received a copy of the GNU General Public License along with 
# this program. If not, see <http://www.gnu.org/licenses/>.
################################################################################

if ! id | grep -q root; then
  echo "Must run script as root; try again with sudo"
  exit
fi

################################################################################
# Set base variables. 
#
# ARCH can be either amd64 or i386. 
# 
# The choice of XENOMAI_VERSION determines the available LINUX_VERSION options: 
#
#   Xenomai |            Linux 
#    2.6.2  |  3.2.21   3.4.6    3.5.3   
#    2.6.3  |  3.4.6    3.5.7    3.8.13  
#    2.6.4  |  3.8.13   3.10.32  3.14.17 
#    2.6.5  |  3.10.32  3.14.44  3.18.20 
#    3.0.1  |  3.10.32  3.14.39  3.18.20 
#    3.0.2  |  3.10.32  3.14.44  3.18.20  4.1.18 
#    3.0.3  |  3.10.32  3.14.44  3.18.20  4.1.18 
# 
################################################################################

ARCH=amd64
LINUX_VERSION=4.9.51
XENOMAI_VERSION=3.0.5

################################################################################
# Calculate other variables. 
################################################################################

echo  "----->Checking dependencies"
apt-get update
apt-get upgrade
apt-get install git libncurses5-dev kernel-package libssl-dev

echo  "----->Setting up variables"

BASE=/opt
SCRIPT_DIR=$(pwd)

LINUX_TREE=$BASE/linux-$LINUX_VERSION

# Hard-code some kernel config urls
LINUX_CONFIG_URL=""
if [ $LINUX_VERSION = "4.9.51" ]; then
  LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.9.51/linux-headers-4.9.51-040951-generic_4.9.51-040951.201709200331_$ARCH.deb"
elif [ $LINUX_VERSION = "4.1.18" ]; then
  LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.1.18-wily/linux-image-4.1.18-040118-generic_4.1.18-040118.201602160131_$ARCH.deb"
elif [ $LINUX_VERSION = "3.18.20" ]; then
  LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.18.20-vivid/linux-image-3.18.20-031820-generic_3.18.20-031820.201508081633_$ARCH.deb"
elif [ $LINUX_VERSION = "3.14.44" ]; then
  LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.14.44-utopic/linux-image-3.14.44-031444-generic_3.14.44-031444.201506061305_$ARCH.deb"
elif [ $LINUX_VERSION = "3.10.32" ]; then
  LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.10.32-saucy/linux-image-3.10.32-031032-generic_3.10.32-031032.201402221635_$ARCH.deb"
elif [ $LINUX_VERSION = "3.8.13" ]; then
  LINUX_CONFIG_URL="http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.8.13.28-raring/linux-image-3.8.13-03081328-generic_3.8.13-03081328.201409030938_$ARCH.deb"
fi

XENOMAI_ROOT=$BASE/xenomai-$XENOMAI_VERSION

AUFS_VERSION=${LINUX_VERSION%.*}
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
if ! [ -f "linux-$LINUX_VERSION.tar.xz" ]; then
  wget https://www.kernel.org/pub/linux/kernel/v${LINUX_VERSION%%.*}.x/linux-$LINUX_VERSION.tar.xz
fi
tar xf linux-$LINUX_VERSION.tar.xz

echo  "----->Downloading Xenomai"
cd $BASE
if ! [ -f "xenomai-$XENOMAI_VERSION.tar.bz2" ]; then
  wget http://xenomai.org/downloads/xenomai/stable/xenomai-$XENOMAI_VERSION.tar.bz2
fi
tar xf xenomai-$XENOMAI_VERSION.tar.bz2

echo  "----->Downloading ipipe"
cd $BASE
wget http://xenomai.org/downloads/ipipe/v4.x/x86/ipipe-core-4.9.51-x86-4.patch

if [ $? -eq 0 ]; then
  echo  "----->Downloads complete"
else
  echo  "----->Downloads failed"
  exit
fi

# Download kernel config
if [ "$LINUX_CONFIG_URL" != "" ]; then
  if ! [ -f ${LINUX_CONFIG_URL##*/} ]; then
    wget $LINUX_CONFIG_URL
  fi
  if [ $? -eq 0 ]; then
    #dpkg-deb -x ${LINUX_CONFIG_URL##*/} linux-$LINUX_VERSION-image
    #cp linux-$LINUX_VERSION-image/boot/config-$LINUX_VERSION-* $LINUX_TREE/.config
  #else
    echo "wget failed to get $LINUX_CONFIG_URL"
    echo "  defaulting to /boot/config-$(uname -r)"
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
elif [[ "$AUFS_VERSION" =~ "4." ]]; then
  git clone git://github.com/sfjro/aufs4-standalone.git aufs-$AUFS_VERSION
else
  echo "Aufs version specified in the \$AUFS_VERSION variable needs to be 3.x or 4.x"
  exit 1
fi

cd $AUFS_ROOT
git checkout origin/aufs$AUFS_VERSION
if [ $LINUX_VERSION = 3.14.44 ]; then
  git checkout origin/aufs3.14.40+
elif [ $LINUX_VERSION = 3.10.32 ]; then
  git checkout origin/aufs3.10.x
fi
cd $LINUX_TREE
patch -p1 < $AUFS_ROOT/aufs${AUFS_VERSION%.*}-kbuild.patch
patch -p1 < $AUFS_ROOT/aufs${AUFS_VERSION%.*}-base.patch
patch -p1 < $AUFS_ROOT/aufs${AUFS_VERSION%.*}-mmap.patch
patch -p1 < $AUFS_ROOT/aufs${AUFS_VERSION%.*}-standalone.patch
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
  $XENOMAI_ROOT/scripts/prepare-kernel.sh --arch=x86 --adeos=$XENOMAI_ROOT/ksrc/arch/x86/patches/ipipe-core-$LINUX_VERSION-x86-[0-9]*.patch --linux=$LINUX_TREE
elif [[ "$XENOMAI_VERSION" =~ "3." ]]; then
  $XENOMAI_ROOT/scripts/prepare-kernel.sh --arch=x86 --ipipe=$BASE/ipipe-core-$LINUX_VERSION-x86-[0-9]*.patch --linux=$LINUX_TREE
else
  echo "Xenomai version specified in the \$XENOMAI_VERSION variable needs to be 2.6.x or 3.x"
  exit 1
fi


################################################################################
# Compile the kernel. The menuconfig options are the same as for a standard RT 
# kernel, except that you need to enable the Aufs module: 
# 
# Filesystems ->
#  Miscellaneous Filesystems ->
#    [M] Aufs
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
fakeroot make-kpkg \
  --initrd \
  --append-to-version=-xenomai-$XENOMAI_VERSION-aufs \
  --revision $(date +%Y%m%d) \
  kernel-image kernel-headers modules

if [ $? -eq 0 ]; then
  echo  "----->Kernel compilation complete."
else
  echo  "----->Kernel compilation failed."
  exit
fi

cp $BASE/linux-image-$LINUX_VERSION-xenomai-$XENOMAI_VERSION*.deb $DEB_FILES
cp $BASE/linux-headers-$LINUX_VERSION-xenomai-$XENOMAI_VERSION*.deb $DEB_FILES


################################################################################
# All you need to do for a live CD is have a compiled kernel. You don't need to 
# install it on your own computer. If you want to anyway, delete the exit 
# command and let the code below run. 
################################################################################

#exit

echo  "----->Installing compiled kernel"
cd $BASE
dpkg -i linux-image-${LINUX_VERSION}-xenomai-$XENOMAI_VERSION*_$ARCH.deb
dpkg -i linux-headers-${LINUX_VERSION}-xenomai-$XENOMAI_VERSION*_$ARCH.deb

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
#if [[ "$XENOMAI_VERSION" =~ "2.6" ]]; then 
#  $XENOMAI_ROOT/configure \
#    --enable-shared \
#    --enable-smp \
#    --enable-x86-sep
#elif [[ "$XENOMAI_VERSION" =~ "3." ]]; then
  $XENOMAI_ROOT/configure \
    --with-core=cobalt \
    --enable-pshared \
    --enable-smp \
    --enable-x86-vsyscall \
    --enable-dlopen-libs
#else
#  echo "Xenomai version specified in the \$XENOMAI_VERSION variable needs to be 2.6.x or 3.x"
#  exit 1
#fi
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
