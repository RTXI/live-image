#! /usr/bin/env bash

# install mercurial and subversion
sudo apt-get install mr subversion

# lots of files. this'll take a while
svn co svn://anonscm.debian.org/svn/d-i/trunk debian-installer
cd debian-installer
scripts/git-setup
mr -p checkout

# go to /idebian-installer/installer/build and run fakeroot make build_cdrom_isolinux. The result will be in the dest folder
