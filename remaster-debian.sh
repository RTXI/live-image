#! /usr/bin/bash

echo "Debian mode..."

# Get started and extract the iso
mkdir mnt extract
sudo mount -o loop *iso mnt/
sudo rsync --exclude=/live/filesystem.squashfs -a mnt/ extract
sudo unsquashfs mnt/live/filesystem.squashfs
mv squashfs-root edit
sudo umount mnt/

# Prepare to chroot into the extracted iso
sudo cp /etc/resolv.conf edit/etc/
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

# Make things take on dark theme (cinnamon, maybe gnome)
touch /etc/gtk-3.0/settings.ini
echo "[Settings]" >> /etc/gtk-3.0/settings.ini
echo "gtk-application-prefer-dark-theme=1" >> /etc/gtk-3.0/settings.ini

# Install RT kernel and RTXI
cd ~/
mkdir .config
gdebi linux-image*
gdebi linux-headers*
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

# Install RTXI
./install_rtxi.sh # needs user to enter 1 in prompt

# Install ggplot
R
install.packages("ggplot2") # use mirror 96 if you want
install.packages("scales")
install.packages("gridExtra")
q() # "n" - don't save workspace

# Clean environment and exit
rm /etc/resolv.conf
umount /proc /sys /dev/pts
exit
sudo umount edit/dev

# Update files in live/ directory
sudo bash -c "chroot edit dpkg-query -W  > extract/live/filesystem.packages"
sudo cp edit/boot/vmlinuz-3.8.13-xenomai-2.6.3-aufs extract/live/vmlinuz
sudo cp edit/boot/initrd.img-3.8.13-xenomai-2.6.3-aufs extract/live/initrd.img
sudo mksquashfs edit extract/live/filesystem.squashfs -comp xz

cd extract
sudo bash -c "find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt"

sudo genisoimage -D -r -V "RTXI" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../custom.iso . 
sudo isohybrid ../custom.iso

echo "Done...I think."
