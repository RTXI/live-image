#! /bin/bash

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

XENOMAI_VERSION=2.6.4
KERNEL_VERSION=3.8.13

cd $HOME

BASE=$HOME/rtxi
SCRIPTS=$BASE/scripts
DEPS=$BASE/deps
HDF=$DEPS/hdf
QWT=$DEPS/qwt
DYN=$DEPS/dynamo
INCLUDES=$DEPS/rtxi_includes

###############################################################################
# Install package dependencies. (DO NOT UPGRADE EXISTING PACKAGES!)
###############################################################################

apt-get update
# apt-get -y upgrade <- this has been problematic
apt-get -y install vim git
git clone https://github.com/rtxi/rtxi
#git clone https://github.com/anselg/handy-scripts
cd rtxi/scripts/
apt-get -y install autotools-dev automake libtool kernel-package \
                   g++ gcc gdb fakeroot crash kexec-tools makedumpfile \
                   kernel-wedge git-core libncurses5 libncurses5-dev \
                   libelf-dev binutils-dev libgsl0-dev vim stress libboost-dev \
                   qt4-dev-tools libqt4-dev libqt4-opengl-dev lshw gdebi r-base \
                   r-cran-ggplot2 r-cran-reshape2 r-cran-hdf5 r-cran-plyr r-cran-scales 
# add the deb-src urls for apt-get build-dep to work
apt-get -y build-dep linux

###############################################################################
# Install HDF5
###############################################################################

cd $DEPS

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
tar xf qwt-6.1.0.tar.bz2
cd qwt-6.1.0
qmake qwt.pro
make -sj`nproc`
make install
cp /usr/local/lib/qwt/lib/libqwt.so.6.1.0 /usr/lib/.
ln -sf /usr/lib/libqwt.so.6.1.0 /usr/lib/libqwt.so
ldconfig

###############################################################################
# Install rtxi_includes and make it writable from all uses in group "adm"
###############################################################################

rsync -a $DEPS/rtxi_includes /usr/local/lib/.
find ../plugins/. -name "*.h" -exec cp -t /usr/local/lib/rtxi_includes/ {} +

chown -R root.adm /usr/local/lib/rtxi_includes
chmod g+s /usr/local/lib/rtxi_includes
chmod -R g+w /usr/local/lib/rtxi_includes

###############################################################################
# Install dynamo
###############################################################################

echo "Installing DYNAMO utility..."

apt-get -y install mlton
cd $DYN
mllex dl.lex
mlyacc dl.grm
mlton dynamo.mlb
cp dynamo /usr/bin/

###############################################################################
# Install gridExtra (it'll get its own deb package in 16.04). Be careful about 
# version numbers. If gridExtra package updates, this link might break. 
###############################################################################

cd $DEPS
wget --no-check-certificate http://cran.r-project.org/src/contrib/gridExtra_0.9.1.tar.gz
tar xf gridExtra_0.9.1.tar.gz
R CMD INSTALL gridExtra

###############################################################################
# Install RT kernel (from the deb files you provided)
###############################################################################

cd ~/
dpkg -i linux-image*.deb
dpkg -i linux-headers*.deb

###############################################################################
# Install Xenomai
###############################################################################

# Code goes here. 
cd ~/
mkdir build
wget --no-check-certificate http://download.gna.org/xenomai/stable/xenomai-$XENOMAI_VERSION.tar.bz2
tar xf xenomai-$XENOMAI_VERSION.tar.bz2

cd build
../xenomai-$XENOMAI_VERSION/configure --enable-shared --enable-smp --enable-x86-sep
make -s
make install

###############################################################################
# Install RTXI and all the icons, config files, etc. that go with it. 
###############################################################################

cd ~/rtxi
./autogen.sh
./configure --enable-xenomai --enable-analogy --disable-comedi --disable-debug
make -sj`nproc` -C ./
make install -C ./

# Put all the icons, config files, etc. into place. 
cp -f libtool /usr/local/lib/rtxi/
cp -f scripts/icons/RTXI-icon.png /usr/local/lib/rtxi/
cp -f scripts/icons/RTXI-widget-icon.png /usr/local/lib/rtxi/
if [ ! -d /root/.config ]; then mkdir /root/.config; fi
cp -f scripts/icons/Trolltech.conf /root/.config/
cp -f scripts/rtxi.desktop /usr/share/applications/
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

mkdir /home/RTXI
chown root.adm /home/RTXI
chmod g+s /home/RTXI
chmod -R g+w /home/RTXI

# Edit permissions to make the directory accessible to all users in adm
cd /home/RTXI/
git clone https://github.com/rtxi/rtxi.git
mkdir modules
cd modules
# Just for fun...
git clone https://github.com/rtxi/signal-generator.git
git clone https://github.com/rtxi/sync.git
git clone https://github.com/rtxi/neuron.git
cd ../

chown -R root.adm rtxi
chmod g+s rtxi
chmod -R g+w rtxi
chown -R root.adm modules
chmod g+s modules
chmod -R g+w modules

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
rm -r build
rm -r xenomai-$XENOMAI_VERSION
rm -r handy-scripts
rm -r *.deb
echo "" > /run/resolvconf/resolv.conf
apt-get clean
umount /proc /sys /dev/pts

echo "We are now done chrooting"
exit
