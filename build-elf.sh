#!/bin/bash -ex
# Script to build or1k toolchain for bare metal

BASEDIR=`pwd`
BUILDDIR=`pwd`/BUILD
INSTALL=`pwd`/INSTALL
#INSTALL=/opt/or1k-toolchain
PARALLEL="-j12"

# Set terminal title
# @param string $1  Tab/window title
# @param string $2  (optional) Separate window title
# The latest version of this software can be obtained here:
# http://fvue.nl/wiki/NameTerminal
# (Modified to avoid breakage with -e in this script by Simon Cook)
nameTerminal() {
    echo " * $1"
    [ "${TERM:0:5}" = "xterm" ]   && local ansiNrTab=0
    [ "$TERM"       = "rxvt" ]    && local ansiNrTab=61
    [ "$TERM"       = "konsole" ] && local ansiNrTab=30 ansiNrWindow=0
        # Change tab title
    [ $ansiNrTab ] && echo -n $'\e'"]$ansiNrTab;$0 - $1"$'\a'
} # nameTerminal()

mkcd() {
  mkdir -p "${1}" && cd "${1}"
}

echo " * Starting in directory ${BASEDIR}"
OR1KSRC=${BASEDIR}/or1k-src
OR1KGCC=${BASEDIR}/or1k-gcc

nameTerminal "Cleaning up existing builds"
rm -rf ${BUILDDIR} ${INSTALL}

nameTerminal "Configuring Binutils Stage 1"
mkcd ${BUILDDIR}/binutilss1
${OR1KSRC}/configure --prefix=${INSTALL} --target=or1k-elf --enable-shared \
  --disable-itcl --disable-tk --disable-tcl --disable-winsup --disable-libgui \
  --disable-rda --disable-sid --disable-sim --disable-gdb --with-sysroot \
  --disable-newlib --disable-libgloss --disable-werror

nameTerminal "Building Binutils Stage 1"
make ${PARALLEL}

nameTerminal "Install Binutils Stage 1"
make install

export PATH="${INSTALL}/bin:$PATH"

nameTerminal "Configuring GCC Stage 1"
mkcd ${BUILDDIR}/gccs1
${OR1KGCC}/configure --prefix=${INSTALL} --target=or1k-elf \
  --enable-languages=c --disable-shared --disable-libssp

nameTerminal "Building GCC Stage 1"
make ${PARALLEL}

nameTerminal "Installing GCC Stage 1"
make install

nameTerminal "Configuring Binutils Stage 2"
mkcd ${BUILDDIR}/binutilss2
${OR1KSRC}/configure --prefix=${INSTALL} --target=or1k-elf  --enable-shared \
  --disable-itcl --disable-tk --disable-tcl --disable-winsup --disable-libgui \
  --disable-rda --disable-sid --enable-sim --disable-or1ksim --enable-gdb \
  --with-sysroot --enable-newlib --enable-libgloss

nameTerminal "Building Binutils Stage 2"
make ${PARALLEL}

nameTerminal "Installing Binutils Stage 2"
make install

nameTerminal "Configuring GCC Stage 2"
echo " * Configuring GCC Stage 2"
mkcd ${BUILDDIR}/gccs2
${OR1KGCC}/configure --prefix=${INSTALL} --target=or1k-elf \
  --enable-languages=c,c++ --disable-shared --disable-libssp --with-newlib

nameTerminal "Building GCC Stage 2"
make ${PARALLEL}

nameTerminal "Installing GCC Stage 2"
make -s install

echo " * Done!"
