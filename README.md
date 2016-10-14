# Live Image

Contained here are the secrets to spinning out an RTXI live CD. In future, this
README will contain instructions for:  
 - [x] Building the live CD from scratch.  
 - [ ] Updating a downloaded CD.  
 - [ ] Editing an already-extracted live CD's chroot filesystem.  

## Building from scratch.  
To build from scratch, you will need two things:  
 - An internet connection. 
 - \*.deb files from an already-compiled, aufs-patched real-time kernel.  

If you don't have deb files from an aufs-patched kernel, compile one using
`install_rt_aufs_kernel.sh`. The script differs from the generic one in that it
compiles a module for AUFS, which is needed for the live casper filesystem to
work. You can follow along the generic custom install instructions on
rtxi.org/install, except you want to compile a kernel for a generic processor
architecture instead of the one specific to your machine.  

### 1. Clone this repo. 

````
git clone https://github.com/rtxi/live-image
````

In the base of the directory, you will find the following: 

 - `build-from-scratch.sh`, the script the builds a live CD.
 - `chroot-script.sh`, a script used by `build-from-scratch.sh`. 
 - `build-rt-aufs-kernel.sh`, which builds deb files for real-time kernels with
 the aufs module. 
 - `deb_files`, the directory where the `build-from-scratch.sh` script expect
 deb files for real-time kernels to be stored.  


### 2. Build an Aufs-enabled RT kernel. 

Skip this step if you already compiled them. Just stick the kernels - header
and image - in the `deb_files` directory. If not, continue. 

First, open the `build-rt-aufs-kernel.sh` script. Near the top will be a section 
for setting up environment variables. The main ones to pay attention to are: 

1. LINUX_VERSION, the kernel version. 
2. ARCH, the architecture of the kernel you're building. 
3. XENOMAI_VERSION, the Xenomai version. 
4. AUFS_VERSION, Aufs version (same as LINUX_VERSION sans minor revision number). 
5. LINUX_CONFIG_URL, url to kernel deb image in Ubuntu's kernel repository (used to extract the starting kernel config for a particular kernel version.)

Edit these parameters to match what you want to build. Then, run: 

```
sudo ./build-rt-kernel-aufs.sh
```

The script will download all source code, images, etc. needed in the `/opt`
directory and then compile the kernel.  It *will not* actually install the
kernel. The kernel configurations to tweak are the same as they are for default
(non-Aufs) kernels, with the exception: 

--> Filesystems
  --> Miscellaneous filesystems
    --> Aufs (enable as module) 

Once the kernel is built, it will be copied to the `deb_files` folder. 

**Note:** If you ever try this with an PREEMPT_RT kernel, it will fail. Aufs
and the RT patch are not compatible. 

### 3. Run `build-from-scratch.sh`  

Run the `build-from-scratch.sh` script in the base of the 'live-image' repo.
You don't need to run the script as root. Bits that need root permissions will
prompt you for your password.  

This will take a while to run, especially if your system or network connection
is slow. The script will multithread when doing heavier tasks. You will need to
be present for a few steps, such as:  

1. Telling the system to *not* use kexec-tools for handling reboots.  
2. Prompting you for your password if Ubuntu's `sudo` timer went out while some
	step was running.  

Other than that, the script will handle everything. Your system will be
somewhat unresponsive during compression and image generation steps.  


### 4. Test out the live CD.  
When the script finishes executing, you'll see a new directory in your repo
called `image_chroots`. Inside, there will be another directory called
build_[DATE]_[TIME], with DATE and TIME corresponding to when you executed the
script. 

Within the build directory, there are two *iso files, one for the generic
Ubuntu CD and another for the new live image. The live image is named
rtxi_[RTXI_VERSION]_[UBUNTU_FLAVOR]_[UBUNTU_VERSION]_[ARCH].iso. Test out the
live image. Clone it to a USB or burn it on a CD to demo RTXI and also install
it.  

To clone to a USB within Linux, use `dd`:

```
$ sudo dd if=the-new-live-cd.iso of=/dev/your_device bs=1M && sync
```

If done from another OS, don't use UNetbootin. It rarely works, and it'll
probably save you time to not bother with it.  
