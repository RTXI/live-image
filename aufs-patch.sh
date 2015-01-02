##DO NOT RUN THIS AS A SCRIPT!!!

git clone git://git.code.sf.net/p/aufs/aufs3-standalone aufs3-standalone.git

cd aufs3-standalone.git
git checkout origin/aufs3.8
cd ../linux-3.8.13/
patch -p1 < ../aufs3-standalone.git/aufs3-kbuild.patch
patch -p1 < ../aufs3-standalone.git/aufs3-base.patch
patch -p1 < ../aufs3-standalone.git/aufs3-mmap.patch
patch -p1 < ../aufs3-standalone.git/aufs3-standalone.patch
cp -a ../aufs3-standalone.git/{Documentation,fs} .
cp -a ../aufs3-standalone.git/include/uapi/linux/aufs_type.h include/uapi/linux/
cp -a ../aufs3-standalone.git/include/linux/aufs_type.h include/linux/
