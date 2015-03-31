#!/bin/sh

# Build script for the OR1K tool chain

# Copyright (C) 2015 Embecosm Limited
# Contributor Andrew Burgess  <andrew.burgess@embecosm.com>

#		     SCRIPT TO BUILD OR1K TOOL CHAIN
#		     ===============================

# Invocation Syntax

#   or1k-build-all.sh [--source-dir <source_dir>]
#                     [--build-dir <build_dir>] [--install-dir <install_dir>]
#                     [--clean | --no-clean]
#                     [--datestamp-install]
#                     [--jobs <count>] [--load <load>] [--single-thread]

# This script is a convenience wrapper to build the OR1K tool chain. It
# is assumed that git repositories are organized as follows:

#   binutils-gdb
#   dejagnu
#   gcc
#   or1k-tooling
#   sim

# On start-up, the top level directory is set to the parent of the directory
# containing this script (since this script is held in the top level of the
# or1k-tooling repository.

# --build-dir <build_dir>

#     The directory in which the tool chain will be built. It defaults
#     to bd-<release>.  Various tools are built into subdirectories of
#     the build directory.

# --install-dir <install_dir>

#     The directory in which both tool chains should be installed. If not
#     specified, defaults to the directory install-<release> in the top level
#     directory.

# --clean | --no-clean

#     If --clean is specified, build directories will be cleaned and all tools
#     will be configured anew. Otherwise build directories are preserved if
#     they exist, and only configured if not yet configured.

# --datestamp-install

#     If specified, this will append a date and timestamp to the install
#     directory name.

# --jobs <count>

#     Specify that parallel make should run at most <count> jobs. The default
#     is <count> equal to one more than the number of processor cores shown by
#     /proc/cpuinfo.

# --load <load>

#     Specify that parallel make should not start a new job if the load
#     average exceed <load>. The default is <load> equal to one more than the
#     number of processor cores shown by /proc/cpuinfo.

# --single-thread

#     Equivalent to --jobs 1 --load 1000. Only run one job at a time, but run
#     whatever the load average.

# Where directories are specified as arguments, they are relative to the
# current directory, unless specified as absolute names.

#------------------------------------------------------------------------------
#
#			       Shell functions
#
#------------------------------------------------------------------------------

# Determine the absolute path name. This should work for Linux, Cygwin and
# MinGW.
abspath ()
{
    sysname=`uname -o`
    case ${sysname} in

	Cygwin*)
	    # Cygwin
	    if echo $1 | grep -q -e "^[A-Za-z]:"
	    then
		echo $1		# Absolute directory
	    else
		echo `pwd`\\$1	# Relative directory
	    fi
	    ;;

	Msys*)
	    # MingGW
	    if echo $1 | grep -q -e "^[A-Za-z]:"
	    then
		echo $1		# Absolute directory
	    else
		echo `pwd`\\$1	# Relative directory
	    fi
	    ;;

	*)
	    # Assume GNU/Linux!
	    if echo $1 | grep -q -e "^/"
	    then
		echo $1		# Absolute directory
	    else
		echo `pwd`/$1	# Relative directory
	    fi
	    ;;
    esac
}


# Print a header to the log file and console

# @param[in] String to use for header
header () {
    str=$1
    len=`expr length "${str}"`

    # Log file header
    echo ${str} >> ${logfile} 2>&1
    for i in $(seq ${len})
    do
	echo -n "=" >> ${logfile} 2>&1
    done
    echo "" >> ${logfile} 2>&1

    # Console output
    echo "${str} ..."
}

cd_or_error () {
    dest=$1
    if ! cd "${dest}"
    then
        echo "ERROR: Failed to enter directory '${dest}'"
        exit 1
    fi
}

mkdir_or_error () {
    if ! mkdir "$@"
    then
        echo "ERROR: Failed to mkdir $@"
        exit 1
    fi
}

#------------------------------------------------------------------------------
#
#		     Argument handling and initialization
#
#------------------------------------------------------------------------------

# Generic release set up, which we'll share with sub-scripts. This defines
# (and exports RELEASE, LOGDIR and RESDIR, creating directories named $LOGDIR
# and $RESDIR if they don't exist.
d=`dirname "$0"`
OR1K_TOP=`(cd "$d/.." && pwd)`
export OR1K_TOP

. ${d}/define-release.sh

# Set defaults for some options
doclean="--no-clean"
builddir="${OR1K_TOP}/bd-${RELEASE}"
installdir="${OR1K_TOP}/install-${RELEASE}"
datestamp=""

# Parse options
until
opt=$1
case ${opt} in
    --build-dir)
	shift
	mkdir_or_error -p $1
	builddir=$(abspath $1)
	;;

    --install-dir)
	shift
	installdir=$(abspath $1)
	;;

    --clean | --no-clean)
	doclean=$1
	;;

    --datestamp-install)
	datestamp=`date -u +%F-%H%M`
	;;

    --jobs)
	shift
	jobs=$1
	;;

    --load)
	shift
	load=$1
	;;

    --single-thread)
	jobs=1
	load=1000
	;;

    ?*)
	echo "Unknown argument $1"
	echo
	echo "Usage: ./or1k-build-all.sh [--build-dir <build_dir>]"
        echo "                           [--install-dir <install_dir>]"
	echo "                           [--clean | --no-clean]"
	echo "                           [--datestamp-install]"
	echo "                           [--jobs <count>] [--load <load>]"
        echo "                           [--single-thread]"
	exit 1
	;;

    *)
	;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

# Set up a logfile
logfile="${LOGDIR}/all-build-$(date -u +%F-%H%M).log"
rm -f "${logfile}"
echo "Logging to ${logfile} ..."

# Create the build directories if necessary.
builddir_binutils=${builddir}/binutils
builddir_gcc_stage_1=${builddir}/gcc-stage-1
builddir_newlib=${builddir}/newlib
builddir_gcc_stage_2=${builddir}/gcc-stage-2
builddir_sim=${builddir}/sim
builddir_gdb=${builddir}/gdb

if [ "x${doclean}" = "x--clean" ]
then
    header "Cleaning build directories"

    rm -fr ${builddir_binutils}
    rm -fr ${builddir_gcc_stage_1}
    rm -fr ${builddir_newlib}
    rm -fr ${builddir_gcc_stage_2}
    rm -fr ${builddir_sim}
    rm -fr ${builddir_gdb}
fi

mkdir_or_error -p ${builddir_binutils}
mkdir_or_error -p ${builddir_gcc_stage_1}
mkdir_or_error -p ${builddir_newlib}
mkdir_or_error -p ${builddir_gcc_stage_2}
mkdir_or_error -p ${builddir_sim}
mkdir_or_error -p ${builddir_gdb}

if [ "x${datestamp}" != "x" ]
then
    installdir="${installdir}-$datestamp"
fi

# Sort out parallelism
make_load="`(echo processor; cat /proc/cpuinfo 2>/dev/null) \
           | grep -c processor`"

if [ "x${jobs}" = "x" ]
then
    jobs=${make_load}
fi

if [ "x${load}" = "x" ]
then
    load=${make_load}
fi

parallel="-j ${jobs} -l ${load}"

# Log the environment
header "Logging build environment"
echo "Environment variables:" >> "${logfile}" 2>&1
env >> "${logfile}" 2>&1
echo ""  >> "${logfile}" 2>&1

echo "Key script variables:" >> "${logfile}" 2>&1
echo "  doclean=${doclean}" >> "${logfile}" 2>&1
echo "  builddir=${builddir}" >> "${logfile}" 2>&1
echo "  installdir=${installdir}" >> "${logfile}" 2>&1
echo "  datestamp=${datestamp}" >> "${logfile}" 2>&1

#--------------------------------------------------------------------------
#
#			Now perform the builds
#
#--------------------------------------------------------------------------

TARGET=or1k-elf
export TARGET

# Setup the PATH to find installed components.
PATH=${installdir}/bin:$PATH
export PATH

# ----- binutils -----

header "Configuring binutils"
cd_or_error ${builddir_binutils}
if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
then
    if ! ${OR1K_TOP}/binutils/configure --target=${TARGET} \
         --prefix=${installdir} \
         --enable-shared --disable-itcl --disable-tk --disable-tcl \
         --disable-winsup --disable-gdbtk --disable-libgui \
         --disable-rda --disable-sid --disable-sim --disable-gdb \
         --with-sysroot --with-system-zlib >> ${logfile} 2>&1
    then
        echo "ERROR: Configuration of binutils failed."
        echo "- see ${logfile}"
        exit 1
    fi
fi

header "Building binutils"
if ! make ${parallel} >> ${logfile} 2>&1
then
    echo "ERROR: Build of binutils failed."
    echo "- see ${logfile}"
    exit 1
fi

header "Installing binutils"
if ! make install >> ${logfile} 2>&1
then
    echo "ERROR: Install of binutils failed."
    echo "- see ${logfile}"
    exit 1
fi

# ----- GCC ( Stage 1 ) -----

header "Configuring GCC (stage 1)"
cd_or_error ${builddir_gcc_stage_1}
if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
then
    if ! ${OR1K_TOP}/gcc/configure --target=${TARGET} \
         --prefix=${installdir} \
         --enable-languages=c --disable-shared \
         --disable-libssp >> ${logfile} 2>&1
    then
        echo "ERROR: Configuration of GCC (stage 1) failed."
        echo "- see ${logfile}"
        exit 1
    fi
fi

header "Building GCC (stage 1)"
if ! make ${parallel} >> ${logfile} 2>&1
then
    echo "ERROR: Build of GCC (stage 1) failed."
    echo "- see ${logfile}"
    exit 1
fi

header "Installing GCC (stage 1)"
if ! make install >> ${logfile} 2>&1
then
    echo "ERROR: Install of GCC (stage 1) failed."
    echo "- see ${logfile}"
    exit 1
fi

# ----- newlib -----

header "Configuring newlib"
cd_or_error ${builddir_newlib}
if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
then
    if ! ${OR1K_TOP}/newlib/configure --target=${TARGET} \
         --prefix=${installdir} >> ${logfile} 2>&1
    then
        echo "ERROR: Configuration of newlib failed."
        echo "- see ${logfile}"
        exit 1
    fi
fi

header "Building newlib"
if ! make ${parallel} >> ${logfile} 2>&1
then
    echo "ERROR: Build of newlib failed."
    echo "- see ${logfile}"
    exit 1
fi

header "Installing newlib"
if ! make install >> ${logfile} 2>&1
then
    echo "ERROR: Install of newlib failed."
    echo "- see ${logfile}"
    exit 1
fi

# ----- GCC ( Stage 2 ) -----

header "Configuring GCC (stage 2)"
cd_or_error ${builddir_gcc_stage_2}
if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
then
    if ! ${OR1K_TOP}/gcc/configure --target=${TARGET} \
         --prefix=${installdir} \
         --enable-languages=c,c++ --disable-shared --disable-libssp \
         --with-newlib >> ${logfile} 2>&1
    then
        echo "ERROR: Configuration of GCC (stage 2) failed."
        echo "- see ${logfile}"
        exit 1
    fi
fi

header "Building GCC (stage 2)"
if ! make ${parallel} >> ${logfile} 2>&1
then
    echo "ERROR: Build of GCC (stage 2) failed."
    echo "- see ${logfile}"
    exit 1
fi

header "Installing GCC (stage 2)"
if ! make install >> ${logfile} 2>&1
then
    echo "ERROR: Install of GCC (stage 2) failed."
    echo "- see ${logfile}"
    exit 1
fi

# ----- sim -----

header "Configuring or1k sim"
cd_or_error ${builddir_sim}
if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
then
    if ! ${OR1K_TOP}/sim/configure --target=${TARGET} \
         --prefix=${installdir} --enable-ethpy \
         >> ${logfile} 2>&1
    then
        echo "ERROR: Configuration of or1k sim failed."
        echo "- see ${logfile}"
        exit 1
    fi
fi

header "Building or1k sim"
if ! make ${parallel} >> ${logfile} 2>&1
then
    echo "ERROR: Build of or1k sim failed."
    echo "- see ${logfile}"
    exit 1
fi

header "Installing or1k sim"
if ! make install >> ${logfile} 2>&1
then
    echo "ERROR: Install or1k sim failed."
    echo "- see ${logfile}"
    exit 1
fi

# ----- gdb -----

header "Configuring gdb"
cd_or_error ${builddir_gdb}
if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
then
    if ! ${OR1K_TOP}/gdb/configure --target=${TARGET} \
         --prefix=${installdir} --enable-shared --disable-itcl \
         --disable-tk --disable-tcl --disable-winsup --disable-gdbtk \
         --disable-gas --disable-ld --disable-gprof --disable-binutils \
         --disable-libgui --disable-rda --disable-sid --enable-sim \
         --disable-or1ksim --enable-gdb  --with-sysroot --disable-newlib \
         --disable-libgloss >> ${logfile} 2>&1
    then
        echo "ERROR: Configuration of gdb failed."
        echo "- see ${logfile}"
        exit 1
    fi
fi

header "Building gdb"
if ! make ${parallel} >> ${logfile} 2>&1
then
    echo "ERROR: Build of gdb failed."
    echo "- see ${logfile}"
    exit 1
fi

header "Installing gdb"
if ! make install >> ${logfile} 2>&1
then
    echo "ERROR: Install gdb failed."
    echo "- see ${logfile}"
    exit 1
fi

#--------------------------------------------------------------------------
#
#				Finished
#
#--------------------------------------------------------------------------

echo "Build completed successfully."
exit 0
