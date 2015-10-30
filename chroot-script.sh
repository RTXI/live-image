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
QWT_VERSION=6.1.2

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
apt-get -y install git
git clone https://github.com/rtxi/rtxi
cd rtxi
git checkout qt5
#git clone https://github.com/anselg/handy-scripts
cd scripts/
apt-get -y install autotools-dev automake libtool kernel-package gcc g++ \
                   gdb fakeroot crash kexec-tools makedumpfile \
                   kernel-wedge libncurses5-dev libelf-dev binutils-dev \
                   libgsl0-dev libboost-dev vim emacs lshw stress \
                   libqt5svg5-dev libqt5opengl5 libqt5gui5 libqt5core5a \
                   libqt5xml5 libqt5network5 qtbase5-dev qt5-default \
                   libgles2-mesa-dev gdebi libqt5designer5 qttools5-dev-tools \
                   libqt5designercomponent5 qttools5-dev
apt-get -y install -f

# add the deb-src urls for apt-get build-dep to work
apt-get -y build-dep linux

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
# Install rtxi_includes and make it writable from all uses in group "adm"
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
#dpkg -i linux-image*.deb
#dpkg -i linux-headers*.deb
gdebi linux-image*.deb
gdebi linux-headers*.deb

###############################################################################
# Install Xenomai
###############################################################################

# Code goes here. 
cd $DEPS
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

cd $BASE

./autogen.sh
./configure --enable-xenomai --enable-analogy 
make -sj`nproc` -C ./
make install -C ./

# Put all the icons, config files, etc. into place. 
cp -f libtool /usr/local/lib/rtxi/
cp -f scripts/icons/RTXI-icon.png /usr/local/lib/rtxi/
cp -f scripts/icons/RTXI-widget-icon.png /usr/local/lib/rtxi/
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
rm -r *.deb
echo "" > /run/resolvconf/resolv.conf
apt-get clean
umount /proc /sys /dev/pts

echo "We are now done chrooting"
exit
