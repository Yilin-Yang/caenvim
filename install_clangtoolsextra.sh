#!/bin/bash

# Downloads, extracts, and builds LLVM, clang, clang-tools, and
# clang-tools-extra, installing them into '/home/your_uniqname/.local'.
# (Binaries will be in '/home/your_uniqname/.local/bin')
#
# Specifically, this installs tools like clang-check (for linting and static
# code analysis), clangd (if you wanna Get Funky with some code completion in
# vim and are willing to brave the the Language Server Protocol), and
# clang-format (if you want your group to stop bickering about indentation
# style/brace positioning/etc. and want to reformat things automatically).
#
# Note that this build takes a **LONG** time. It would be faster to download
# and extract prebuilt binaries from the LLVM website, but none of them were
# built specifically for RedHat Enterprise Linux, and I haven't been able to
# get the one I tried (SuSE Linux Enterprise Server) to work reliably.
#
# TODO
# After running this, you should prepend $HOME/.local/bin to your $PATH, or
# else you'll only be able to run these tools with commands like:
#
#   $ /home/your_uniqname/.local/bin/clang-check *.cpp
#
# An easy way to do this would be to add:
#
#   export PATH="$HOME/.local/bin:$PATH"
#
# To your .bash_profile.
# TODO

# Global Constants
TEMP="$HOME/temp"
INSTALLDIR="$TEMP/clang"

# Executables
# you could also `module load gcc/7.1.0` and `module load cmake/3.12.0`
CC="/usr/um/gcc-7.1.0/bin/gcc"
CPP="/usr/um/gcc-7.1.0/bin/g++"
CMAKE_EXE="/usr/um/cmake-3.12.0/bin/cmake"

# create directories, if they don't yet exist
mkdir -p "$INSTALLDIR"
mkdir -p "$TEMP"

# move into tempfile directory
cd "$TEMP"

# clone LLVM, create and cd into the build folder
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
mkdir -p build && cd build

# Configure the Build
#
# The list in LLVM_ENABLE_PROJECTS is semicolon-separated. Possible "PROJECTS"
# are:
#  clang;clang-tools-extra;compiler-rt;debuginfo-tests;libclc;libcxx;libcxxabi;
#  libunwind;lld;lldb;llgo;openmp;parallel-libs;polly;pstl
$CMAKE_EXE \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CPP" \
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALLDIR" \
  ../llvm

# If this is set to make -j, no limit is placed on the number of processes
# spawned, so `make` will spawn hundreds of child processes and all of your
# processes (including SSH) will get killed by CAEN.
make -j8

# Some build problems you may encounter:
# 1) "final close failed: disk quota exceeded"
# A. You're using too much disk space on CAEN; delete some of your other
# folders. Try running `du --summarize` in your home folder to locate the
# biggest space-takers.
#
# 2) You leave it running overnight, but your SSH connection times out and the
# build is canceled
# A. Try `ssh -o ServerAliveInterval=60 your_uniqname@login.engin.umich.edu`.
#
# 3) Somebody else is running this script on the same login server!
# A. Try changing $TEMP to somewhere in your home directory, so you don't try
# to clone LLVM's repository on top of theirs ('/tmp' is a "shared" temp
# directory). This might trigger error (1), though.

if [ $? -ne 0 ]; then
  # the build can be temperamental, so try again the first time it fails
  (>&2 echo "Build failed on first attempt, retrying.")
  make -j8
  if [ $? -ne 0 ]; then
    (>&2 echo "Failed again. Exiting.")
    exit 1
 fi
fi

# Install files to '$HOME/.local'. Because you have write access to this
# folder, you don't need `sudo`.
make install
