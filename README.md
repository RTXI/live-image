###Live Image

Contained here are the secrets to spinning out an RTXI live CD. In future, this README will contain instructions for:  
 - [x] Building the live CD from scratch.  
 - [ ] Updating a downloaded CD.  
 - [ ] Editing an already-extracted live CD's chroot filesystem.  

####Building from scratch.  
To build from scratch, you will need two things:  
 - An internet connection. 
 - \*.deb files from an already-compiled, aufs-patched real-time kernel.  

If you don't have deb files from an aufs-patched kernel, compile one using `install_rt_aufs_kernel.sh`. The script differs from the generic one in that it compiles a module for AUFS, which is needed for the live casper filesystem to work. You can follow along the generic custom install instructions on rtxi.org/install, except you want to compile a kernel for a generic processor architecture instead of the one specific to your machine.  

#####1. Clone this repo. 
````
git clone https://github.com/rtxi/live-image
````

In the base of the live-image directory, create a directory called `deb_files`. Copy the \*.deb files for the real-time kernel headers and image into this directory. The RT kernel binaries you include **must** have the aufs kernel module compiled. Otherwise, it cannot be used to boot the live CD.   

**Note:** You can compilie an aufs kernel using the `install_rt_aufs_kernel.sh` script in the `scripts/dev` subdirectory of the RTXI source code repository.  

Also, you should watch the kernel and xenomai versions in the real-time kernel you supply. By default, the build script will assume you are using kernel 3.8.13 and xenomai 2.6.4. If you aren't, you'll need to edit both the `build-from-scratch.sh` and `chroot-script.sh` scripts. 

Open the script up, and in the 'Global variables' sections, change the kernel and xenomai versions within. No further edits are needed.  

#####2. Run `build-from-scratch.sh`  
Run the `build-from-scratch.sh` script in the base of the 'live-image' repo. You don't need to run the script as root. Bits that need root permissions will prompt you for your password.  

This will take a while to run, especially if your system or network connection is slow. The script will multithread when doing heavier tasks. Feel free to sit and wait. Or go out and frolic for a while. Whatever you want.  


#####3. Test out the live CD.  
When the script finishes executing, you'll see a new directory in your repo called `image_chroots`. Inside, there will be another directory called build_[DATE]_[TIME], with DATE and TIME corresponding to when you executed the script. 

Within the build directory, there are two *iso files, one for the generic Ubuntu CD and another for the new live image. Test out the live image. If the script worked properly, the image can be cloned to a USB to demo RTXI and also install it.  
