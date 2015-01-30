#! /bin/bash

# Define build steps as internal bash functions
function debian_amd64 {
	MODE=debian
	DIST=jessie
	ARCH=amd64
	HEAD=`pwd`

	mkdir $MODE_$DIST_$ARCH
	cd $MODE_$DIST_$ARCH

	lb config
	cp $HEAD/config_files/config-$MODE-$ARCH 

}

# Now, the user-facing part of the script

echo "Whaddaya want?!?"
echo "  1. Debian (amd64)"
echo "  2. Debian (i386)"
echo "  3. Ubuntu (x86_64)"
echo "  4. Debian (x86)"

read mode

if [ $mode == "1" ]; then
	echo "Okay, let's make a 64-bit debian cd"
elif [ $mode == "2" ]; then
	echo "Okay, let's make a 32-bit debian cd"
elif [ $mode == "3" ]; then
	echo "Sorry, Ubuntu CD's aren't supported yet"
elif [ $mode == "4" ]; then
	echo "Sorry, Ubuntu CD's aren't supported yet"
else
	echo "Huh? I don't understand."
	exit 1
fi


