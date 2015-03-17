#! /usr/bin/bash

echo "Ubuntu mode...ISN'T DONE SO DON'T USE IT!!!!!"
exit

# Get started and extract the iso
mkdir mnt extract
sudo mount -o loop *iso mnt/
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract
sudo unsquashfs mnt/live/filesystem.squashfs
mv squashfs-root edit
sudo umount mnt/

# Prepare to chroot into the extracted iso
sudo cp /etc/resolv.conf edit/run/resolvconf/resolv.conf
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
git clone https://github.com/rtxi/rtxi
cd rtxi
git checkout qt4
cd scripts
DIR=$PWD
ROOT=${DIR}/../
DEPS=${ROOT}/deps
HDF=${DEPS}/hdf
QWT=${DEPS}/qwt
DYN=${DEPS}/dynamo
apt-get -y install autotools-dev automake libtool
apt-get -y install kernel-package
apt-get -y install fakeroot crash kexec-tools makedumpfile kernel-wedge # Select "No" for kexec handling restarts
apt-get -y build-dep linux
apt-get -y install git-core libncurses5 libncurses5-dev libelf-dev binutils-dev libgsl0-dev vim stress libboost-dev
apt-get -y install qt4-dev-tools libqt4-dev libqt4-opengl-dev
apt-get -y install r-base lshw

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
	sudo make install
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
	sudo make install
	sudo cp /usr/local/lib/qwt/lib/libqwt.so.6.1.0 /usr/lib/.
	sudo ln -sf /usr/lib/libqwt.so.6.1.0 /usr/lib/libqwt.so
	sudo ldconfig
	if [ $? -eq 0 ]; then
		echo "----->Qwt installed."
	else
		echo "----->Qwt installation failed."
	exit
	fi
fi

# Install rtxi_includes
sudo rsync -a ${DEPS}/rtxi_includes /usr/local/lib/.
if [ $? -eq 0 ]; then
	echo "----->rtxi_includes synced."
else
	echo "----->rtxi_includes sync failed."
	exit
fi
find ../plugins/. -name "*.h" -exec cp -t /usr/local/lib/rtxi_includes/ {} +

# Install dynamo
echo "Installing DYNAMO utility..."

sudo apt-get -y install mlton
cd ${DYN}
mllex dl.lex
mlyacc dl.grm
mlton dynamo.mlb
sudo cp dynamo /usr/bin/
if [ $? -eq 0 ]; then
	echo "----->DYNAMO translation utility installed."
else
	echo "----->DYNAMO translation utility installation failed."
	exit
fi

# Install RT kernel and RTXI
cd ~/
mkdir .config
gdebi linux-image*
gdebi linux-headers*
./install_rtxi.sh # needs user to enter 1 in prompt, also don't use sudo

# Install ggplot
R
install.packages("ggplot2") # use mirror 96 if you want
install.packages("scales")
install.packages("gridExtra")
install.packages("plyr")
q() # "n" - don't save workspace

# Clean environment and exit
# rm /run/resolvconf/resolv.conf # maybe don't do this...? 
umount /proc /sys /dev/pts
exit
sudo umount edit/dev

# Update files in live/ directory
sudo bash -c "chroot edit dpkg-query -W > extract/casper/filesystem.manifest"
sudo cp extract/casper/filesystem.manifest extract/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' extract/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' extract/casper/filesystem.manifest-desktop

sudo cp edit/boot/vmlinuz-3.8.13-xenomai-2.6.3-aufs extract/casper/vmlinuz.efi
sudo cp edit/boot/initrd.img-3.8.13-xenomai-2.6.3-aufs extract/casper/initrd.lz
sudo mksquashfs edit extract/casper/filesystem.squashfs -comp xz
sudo bash -c "printf $(sudo du -sx --block-size=1 edit | cut -f1) > extract/casper/filesystem.size"

cd extract
sudo bash -c "find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt"

sudo genisoimage -D -r -V "RTXI" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../custom.iso . 
sudo isohybrid ../custom.iso
echo "Done...maybe."
