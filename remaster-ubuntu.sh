#! /usr/bin/env bash

echo "Ubuntu mode..."

# Get started and extract the iso
mkdir mnt extract
sudo mount -o loop *iso mnt/
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract
sudo unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit
sudo umount mnt/

# Prepare to chroot into the extracted iso
#sudo cp /etc/resolv.conf edit/run/resolvconf/resolv.conf <-hehehe
sudo cp /run/resolvconf/resolv.conf edit/run/resolvconf/resolv.conf
# copy RT kernel *.deb files and the Xenomai build

# Enter the chroot
sudo mount --bind /dev/ edit/dev
sudo chroot edit

# Mount things and prepare environment
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C

# Install dependencies
apt-get update
apt-get -y upgrade
apt-get -y install vim git
git clone https://github.com/rtxi/rtxi
git clone https://github.com/anselg/handy-scripts
cd rtxi
cd scripts
DIR=$PWD
ROOT=${DIR}/../
DEPS=${ROOT}/deps
HDF=${DEPS}/hdf
QWT=${DEPS}/qwt
DYN=${DEPS}/dynamo
apt-get -y install autotools-dev automake libtool kernel-package \
                   g++ gcc gdb fakeroot crash kexec-tools makedumpfile \ 
						 kernel-wedge git-core libncurses5 libncurses5-dev \ 
						 libelf-dev binutils-dev libgsl0-dev vim stress libboost-dev \
                   qt4-dev-tools libqt4-dev libqt4-opengl-dev lshw gdebi r-base \
                   r-cran-ggplot2 r-cran-reshape2 r-cran-hdf5 r-cran-plyr r-cran-scales 
# add the deb-src urls for apt-get build-dep to work
apt-get -y build-dep linux

cd ${DEPS}

# Installing HDF5
echo "----->Checking for HDF5"

if [ -f "/usr/include/hdf5.h" ]; then
	echo "----->HDF5 already installed."
else
	echo "----->Installing HDF5..."
	cd ${HDF}
	tar xf hdf5-1.8.4.tar.bz2
	cd hdf5-1.8.4
	./configure --prefix=/usr
	make -sj2
	make install
	if [ $? -eq 0 ]; then
			echo "----->HDF5 installed."
	else
		echo "----->HDF5 installation failed."
		exit
	fi
fi

# Installing Qwt
echo "----->Checking for Qwt"

if [ -f "/usr/local/lib/qwt/include/qwt.h" ]; then
	echo "----->Qwt already installed."
else
	echo "----->Installing Qwt..."
	cd ${QWT}
	tar xf qwt-6.1.0.tar.bz2
	cd qwt-6.1.0
	qmake qwt.pro
	make -sj2
	make install
	cp /usr/local/lib/qwt/lib/libqwt.so.6.1.0 /usr/lib/.
	ln -sf /usr/lib/libqwt.so.6.1.0 /usr/lib/libqwt.so
	ldconfig
	if [ $? -eq 0 ]; then
		echo "----->Qwt installed."
	else
		echo "----->Qwt installation failed."
	exit
	fi
fi

# Install rtxi_includes
rsync -a ${DEPS}/rtxi_includes /usr/local/lib/.
if [ $? -eq 0 ]; then
	echo "----->rtxi_includes synced."
else
	echo "----->rtxi_includes sync failed."
	exit
fi
find ../plugins/. -name "*.h" -exec cp -t /usr/local/lib/rtxi_includes/ {} +

chown -R root.adm /usr/local/lib/rtxi_includes
chmod g+s /usr/local/lib/rtxi_includes
chmod -R g+w /usr/local/lib/rtxi_includes

# Install dynamo
echo "Installing DYNAMO utility..."

apt-get -y install mlton
cd ${DYN}
mllex dl.lex
mlyacc dl.grm
mlton dynamo.mlb
cp dynamo /usr/bin/
if [ $? -eq 0 ]; then
	echo "----->DYNAMO translation utility installed."
else
	echo "----->DYNAMO translation utility installation failed."
	exit
fi

# Install ggplot (use mirror 94 if you want)
apt-get install r-cran-ggplot2 r-cran-reshape2 r-cran-hdf5 r-cran-plyr r-cran-scales
R
install.packages("gridExtra")
q() # "n" - don't save workspace

# Install RT kernel
cd ~/
gdebi linux-image*.deb
gdebi linux-headers*.deb
#cp handy-scripts/main.cpp rtxi/src/main.cpp # hehehe

# Install RTXI and keep sources in /rtxi/home
mkdir /home/RTXI
chown root.adm /home/RTXI
chmod -R g+w /home/RTXI
mv ~/rtxi /home/RTXI/
cd /home/RTXI/rtxi/scripts
./install_rtxi.sh # needs user to enter 1 in prompt, also don't use sudo

# Edit permissions to make the directory accessible to all users in adm
cd /home/RTXI/rtxi
git reset --hard
git clean -xdf
cd ../
chown -R root.adm rtxi
chmod 2775 rtxi
chmod -R g+w rtxi
#find rtxi/. -name *.sh -type f -exec chmod 775 {} \;
#find rtxi/. -not -name *.sh -type f -exec chmod 664 {} \; #bad outcome need to git reset --hard

# Create file in /etc/profile.d/ that will make the RTXI symlink at login
cd /etc/profile.d/
vi create_rtxi_symlink.sh # Enter text below into the file. DON'T RUN IT IN THE SHELL!!!
if [ -d /home/RTXI ]; then
	if ! [ -d $HOME/RTXI ]; then
		ln -s /home/RTXI $HOME/RTXI
	fi
fi #Last line for the script. DON'T PUT THE FOLLOWING IN THIS SCRIPT!!!

# Disable the Public and Templates directories from being formed
vi /etc/xdg/user-dirs.defaults
# Comment out PUBLICSHARE and TEMPLATE

# Clean environment and exit
echo "" > /run/resolvconf/resolv.conf
apt-get clean
umount /proc /sys /dev/pts
exit
sudo umount edit/dev

# Update files in live/ directory
sudo bash -c "chroot edit dpkg-query -W > extract/casper/filesystem.manifest"

sudo cp edit/boot/vmlinuz-3.8.13-xenomai-2.6.3-aufs extract/casper/vmlinuz.efi #vmlinuz (no .efi) for 32-bit
sudo cp edit/boot/initrd.img-3.8.13-xenomai-2.6.3-aufs extract/casper/initrd.lz
sudo mksquashfs edit extract/casper/filesystem.squashfs -comp xz
sudo bash -c "printf $(sudo du -sx --block-size=1 edit | cut -f1) > extract/casper/filesystem.size"

cd extract
sudo bash -c "find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt"

sudo genisoimage -D -r -V "RTXI" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../custom.iso . 
sudo isohybrid ../custom.iso
echo "Done...maybe."
