#! /bin/bash

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

###############################################################################
# Mount ramfs and virtual filesystems. Prepare chroot environment. 
###############################################################################

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C

###############################################################################
# Set global variables. 
###############################################################################

RTXI_VERSION=2.1
XENOMAI_VERSION=3.0.2
KERNEL_VERSION=4.1.18
if [ "$RTXI_VERSION" == "2.1" ]; then
	QWT_VERSION=6.1.2 
elif [ "$RTXI_VERSION" == "2.0" ]; then
	QWT_VERSION=6.1.0 
fi

cd $HOME

BASE=$HOME/rtxi
SCRIPTS=$BASE/scripts
DEPS=$BASE/deps
HDF=$DEPS/hdf
QWT=$DEPS/qwt
DYN=$DEPS/dynamo
INCLUDES=$DEPS/rtxi_includes

###############################################################################
# Enable deb-src and the universe/multiverse repositories. 
###############################################################################
add-apt-repository -s "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main universe restricted multiverse"


###############################################################################
# Install package dependencies. (DO NOT UPGRADE EXISTING PACKAGES!)
###############################################################################

apt-get update
# apt-get -y upgrade <- this has been problematic
apt-get -y install git

# check whether to build v2.0 or v2.1. 
if [ "$RTXI_VERSION" == "2.1" ]; then
	git clone https://github.com/rtxi/rtxi
	cd rtxi
	if [[ "XENOMAI_VERSION" ~= "3." ]]; then
		git checkout rttweak
	elif [[ "XENOMAI_VERSION" ~= "2.6." ]]; then
		git checkout qt5
	fi
	apt-get -y install autotools-dev automake libtool kernel-package gcc g++ \
	                   gdb fakeroot crash kexec-tools makedumpfile \
	                   kernel-wedge libncurses5-dev libelf-dev binutils-dev \
	                   libgsl0-dev libboost-dev vim emacs lshw stress \
	                   libqt5svg5-dev libqt5opengl5 libqt5gui5 libqt5core5a \
	                   libqt5xml5 libqt5network5 qtbase5-dev qt5-default \
	                   libgles2-mesa-dev gdebi libqt5designer5 qttools5-dev \
	                   libqt5designercomponents5 qttools5-dev-tools \
	                   libgit2-dev libmarkdown2-dev
elif [ "$RTXI_VERSION" == "2.0" ]; then
	git clone https://github.com/rtxi/rtxi
	git clone https://github.com/anselg/handy-scripts
	cd rtxi
	apt-get -y install autotools-dev automake libtool kernel-package \
	                   g++ gcc gdb fakeroot crash kexec-tools makedumpfile \
	                   kernel-wedge git-core libncurses5 libncurses5-dev \
	                   libelf-dev binutils-dev libgsl0-dev vim stress lshw \
	                   libboost-dev qt4-dev-tools libqt4-dev libqt4-opengl-dev \
	                   gdebi r-base r-cran-ggplot2 r-cran-reshape2 r-cran-hdf5 \
	                   r-cran-plyr r-cran-scales
else 
	echo "Invalid RTXI version set"
	exit
fi
	
apt-get -y install -f

# add the deb-src urls for apt-get build-dep to work
apt-get -y build-dep linux

###############################################################################
# Install gridExtra for v2.0 (it'll get its own deb package in 16.04). Be 
# careful about version numbers. If gridExtra package updates, this link might 
# break. 
###############################################################################

if [ "$RTXI_VERSION" == "2.0" ]; then
	cd $DEPS
	wget https://cran.r-project.org/src/contrib/Archive/gridExtra/gridExtra_0.9.1.tar.gz
	R CMD INSTALL gridExtra_0.9.1.tar.gz
fi

###############################################################################
# Install dynamo for v2.0
###############################################################################

if [ "$RTXI_VERSION" == "2.0" ]; then
	echo "Installing DYNAMO utility..."
	apt-get -y install mlton
	
	cd $DYN
	mllex dl.lex
	mlyacc dl.grm
	mlton dynamo.mlb
	cp dynamo /usr/bin/
fi

###############################################################################
# Install HDF5
###############################################################################

echo "----->Checking for HDF5"
cd $HDF
tar xf hdf5-1.8.4.tar.bz2
cd hdf5-1.8.4
./configure --prefix=/usr
make -sj`nproc`
make install

###############################################################################
# Install Qwt
###############################################################################

echo "----->Installing Qwt..."
cd $QWT
tar xf qwt-$QWT_VERSION.tar.bz2
cd qwt-$QWT_VERSION
qmake qwt.pro
make -sj`nproc`
make install
cp -vf /usr/local/qwt-$QWT_VERSION/lib/libqwt.so.$QWT_VERSION /usr/lib/.
ln -sf /usr/lib/libqwt.so.$QWT_VERSION /usr/lib/libqwt.so
ldconfig

###############################################################################
# Install rtxi_includes and make it writable from all users in group "adm"
###############################################################################

rsync -a $DEPS/rtxi_includes /usr/local/lib/.
find $BASE/plugins/. -name "*.h" -exec cp -t /usr/local/lib/rtxi_includes/ {} +

chown -R root.adm /usr/local/lib/rtxi_includes
chmod g+s /usr/local/lib/rtxi_includes
chmod -R g+w /usr/local/lib/rtxi_includes

###############################################################################
# Install RT kernel (from the deb files you provided)
###############################################################################

cd ~/
gdebi -n linux-image*.deb
gdebi -n linux-headers*.deb

###############################################################################
# Install Xenomai
###############################################################################

# Code goes here. 
cd $DEPS
wget https://xenomai.org/downloads/xenomai/stable/xenomai-$XENOMAI_VERSION.tar.bz2
tar xf xenomai-$XENOMAI_VERSION.tar.bz2

mkdir build
cd build
if [[ "$XENOMAI_VERSION" =~ "2.6" ]]; then
   ../xenomai-$XENOMAI_VERSION/configure --enable-shared --enable-smp --enable-x86-sep
elif [[ "$XENOMAI_VERSION" =~ "3." ]]; then
   ../xenomai-$XENOMAI_VERSION/configure --with-core=cobalt --enable-pshared --enable-smp --enable-x86-vsyscall --enable-dlopen-libs
else
   echo "Xenomai version specified in the \$XENOMAI_VERSION variable needs to be 2.6.x or 3.x"
   exit 1
fi

make -s
make install

###############################################################################
# Install RTXI and all the icons, config files, etc. that go with it. 
###############################################################################

cd $BASE

# Theming for Qt4 (v2.0 only)
if [ "$RTXI_VERSION" == "2.0" ]; then
	cp ../handy-scripts/rtxi_utils/ui-tweaks/main.cpp src/main.cpp
	cp ../handy-scripts/rtxi_utils/ui-tweaks/default_gui_model.cpp src/default_gui_model.cpp
	if [ ! -d /root/.config ]; then mkdir /root/.config; fi
	cp -f scripts/icons/Trolltech.conf /root/.config/ 
fi

./autogen.sh
./configure --enable-xenomai --enable-analogy 
make -sj`nproc` -C ./
make install -C ./

# Put all the icons, config files, etc. into place. 
cp -f libtool /usr/local/lib/rtxi/
cp -f scripts/icons/RTXI-icon.png /usr/local/lib/rtxi/
cp -f scripts/icons/RTXI-widget-icon.png /usr/local/lib/rtxi/
cp -f scripts/rtxi.desktop /usr/share/applications/
chmod +x /usr/share/applications/rtxi.desktop
cp -f rtxi.conf /etc/rtxi.conf
cp -f /usr/xenomai/sbin/analogy_config /usr/sbin/

cp -f scripts/services/rtxi_load_analogy /etc/init.d/
update-rc.d rtxi_load_analogy defaults
ldconfig

###############################################################################
# Create shared RTXI folder in /home/RTXI. All users can add and edit files 
# here, and a process in /etc/profile.d/ will create a symlink to /home/RTXI in
# all users' home directories. 
###############################################################################

# Edit permissions to make the directory accessible to all users in adm
mkdir /home/RTXI
chown root.adm /home/RTXI
chmod g+s /home/RTXI
chmod -R g+w /home/RTXI

# Create shared folders
cd /home/RTXI/
git clone https://github.com/rtxi/rtxi.git
mkdir modules

chown -R root.adm /home/RTXI/rtxi
chmod g+s /home/RTXI/rtxi
chmod -R g+w /home/RTXI/rtxi
chown -R root.adm modules
chmod g+s modules
chmod -R g+w modules

# Clone and install some modules
mkdir /usr/local/lib/rtxi_modules
cd /usr/local/lib/rtxi_modules
git clone https://github.com/RTXI/iir-filter.git
git clone https://github.com/RTXI/fir-window.git
git clone https://github.com/RTXI/sync.git
git clone https://github.com/RTXI/mimic-signal.git
git clone https://github.com/RTXI/signal-generator.git
git clone https://github.com/RTXI/ttl-pulses.git
git clone https://github.com/RTXI/wave-maker.git
git clone https://github.com/RTXI/noise-generator.git

for dir in *; do
	if [ -d "$dir" ]; then
		cd "$dir"
		make -j`nproc`
		make install
		make clean
		git clean -xdf
		cd ../
	fi
done

# Create file in /etc/profile.d/ that will make the RTXI symlink at login
echo 'if [ -d /home/RTXI ]; then
	if ! [ -d $HOME/RTXI ]; then
		ln -s /home/RTXI $HOME/RTXI
	fi
fi' > /etc/profile.d/create_rtxi_symlink.sh

# Disable the Public and Templates directories from being formed
sed -i 's/PUBLICSHARE/#PUBLICSHARE/g' /etc/xdg/user-dirs.defaults
sed -i 's/TEMPLATE/#TEMPLATE/g' /etc/xdg/user-dirs.defaults

###############################################################################
# Cleanup and exit chroot.
###############################################################################
cd ~/
rm -r rtxi
if [ "$RTXI_VERSION" == "2.0" ]; then rm -r handy-scripts; fi
rm -r *.deb
echo "" > /run/resolvconf/resolv.conf
apt-get clean
umount /proc /sys /dev/pts

echo "We are now done chrooting"
exit
