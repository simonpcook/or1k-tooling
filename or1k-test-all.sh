#!/bin/sh

# Test script for the OR1K tool chain

# Copyright (C) 2015 Embecosm Limited
# Contributor Andrew Burgess  <andrew.burgess@embecosm.com>

#		     SCRIPT TO TEST OR1K TOOL CHAIN
#		     ==============================

# Invocation Syntax

#   or1k-test-all.sh [--install-dir <install_dir>]
#                    [--build-dir <build_dir>]
#                    [--binutils|--no-binutils]
#                    [--gas|--no-gas]
#                    [--gdb|--no-gdb]
#                    [--ld|--no-ld]
#                    [--gcc|--no-gcc]
#                    [--sim|--no-sim]
#                    [--jobs <count>] [--load <load>] [--single-thread]

# This script is a convenience wrapper to test the OR1K tool chain.
# It assumes the same directory layout at the or1k-build-all.sh
# script.

# On start-up, the top level directory is set to the parent of the directory
# containing this script (since this script is held in the top level of the
# or1k-tooling repository.

# Results are placed into the results-<RELEASE> directory within the
# top level directory, each test run will create a new, datestamped
# sub-directory within the results directory and copy any collected
# results there.

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

save_results () {
    path_root=$1
    cp ${path_root}.sum ${resultdir}
    cp ${path_root}.log ${resultdir}
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
do_binutils="--binutils"
do_gas="--gas"
do_gdb="--gdb"
do_ld="--ld"
do_gcc="--gcc"
do_sim="--sim"
datestamp=`date -u +%F-%H%M`
builddir="${OR1K_TOP}/bd-${RELEASE}"
installdir="${OR1K_TOP}/install-${RELEASE}"

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

    --binutils | --no-binutils)
	do_binutils=$1
	;;

    --gas | --no-gas)
	do_gas=$1
	;;

    --gdb | --no-gdb)
	do_gdb=$1
	;;

    --ld | --no-ld)
	do_ld=$1
	;;

    --gcc | --no-gcc)
	do_gcc=$1
	;;

    --sim | --no-sim)
	do_sim=$1
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
	echo "Usage: ./or1k-test-all.sh [--install-dir <install_dir>]"
        echo "                          [--build-dir <build_dir>]"
        echo "                          [--binutils|--no-binutils]"
        echo "                          [--gas|--no-gas]"
        echo "                          [--gdb|--no-gdb]"
        echo "                          [--ld|--no-ld]"
        echo "                          [--gcc|--no-gcc]"
        echo "                          [--sim|--no-sim]"
	echo "                          [--jobs <count>] [--load <load>]"
        echo "                          [--single-thread]"
	exit 1
	;;

    *)
	;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

# Ensure the installed tools can be found.
PATH=$(abspath ${installdir}/bin):$PATH
export PATH

# Ensure required DeJaGnu setup is found.
export DEJAGNU=${OR1K_TOP}/or1k-tooling/site-sim.exp

# Set up a logfile
logfile="${LOGDIR}/test-all-${datestamp}.log"
rm -f "${logfile}"
echo "Logging to ${logfile} ..."

# Create a results directory.
resultdir="${RESDIR}/results-${datestamp}"
echo "Results copied to ${resultdir} ..."
if [ -d ${resultdir} ]
then
    echo "ERROR: Results directory already exists (re-run too soon?)"
    exit 1
fi

if ! mkdir -p ${resultdir}
then
    echo "ERROR: Unable to create results directory"
    exit 1
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

gitverfile=${resultdir}/git-versions
/bin/rm -f ${gitverfile}
for srcdir in dejagnu gcc or1k-tooling sim
do
    echo -n "${srcdir}: " >> ${gitverfile}
    if [ -d ${OR1K_TOP}/${srcdir} ]
    then
        cd ${OR1K_TOP}/${srcdir}
        if [ -d .git ]
        then
            git describe --always --dirty >> ${gitverfile}
        else
            echo "Not a git tree: ${srcdir}" >> ${gitverfile}
        fi
    else
        echo "Missing directory: ${srcdir}" >> ${gitverfile}
    fi
done

echo "Git versions being tested..."
cat ${gitverfile}

#------------------------------------------------------------------------------
#
#		     		Run The Tests
#
#------------------------------------------------------------------------------

binutils_test_dir=${builddir}/binutils
gas_test_dir=${builddir}/binutils
ld_test_dir=${builddir}/binutils
gcc_test_dir=${builddir}/gcc-stage-2
sim_test_dir=${builddir}/sim
gdb_test_dir=${builddir}/gdb

if [ "x${do_binutils}" = "x--binutils" -a -d "${binutils_test_dir}" ]
then
    header "Running binutils tests"
    cd_or_error "${binutils_test_dir}"
    # TODO: Consider using ${parallel} here.
    make check-binutils >> ${logfile} 2>&1
    header "Saving binutils results"
    save_results binutils/binutils
fi

if [ "x${do_ld}" = "x--ld" -a -d "${ld_test_dir}" ]
then
    header "Running ld tests"
    cd_or_error "${ld_test_dir}"
    # TODO: Consider using ${parallel} here.
    make check-ld >> ${logfile} 2>&1
    header "Saving ld results"
    save_results ld/ld
fi

if [ "x${do_gas}" = "x--gas" -a -d "${gas_test_dir}" ]
then
    header "Running gas tests"
    cd_or_error "${gas_test_dir}"
    # TODO: Consider using ${parallel} here.
    make check-gas >> ${logfile} 2>&1
    header "Saving gas results"
    save_results gas/testsuite/gas
fi

if [ "x${do_gdb}" = "x--gdb" -a -d "${gdb_test_dir}" ]
then
    header "Running gdb tests"
    cd_or_error "${gdb_test_dir}"
    make ${parallel} check-gdb >> ${logfile} 2>&1
    header "Saving gdb results"
    save_results gdb/testsuite/gdb
fi

if [ "x${do_gcc}" = "x--gcc" -a -d "${gcc_test_dir}" ]
then
    header "Running gcc tests"
    cd_or_error "${gcc_test_dir}"
    make ${parallel} check >> ${logfile} 2>&1
    header "Saving gcc results"
    save_results or1k-elf/libstdc++-v3/testsuite/libstdc++
    save_results gcc/testsuite/gcc/gcc
    save_results gcc/testsuite/g++/g++
fi

if [ "x${do_sim}" = "x--sim" -a -d "${sim_test_dir}" ]
then
    header "Running sim tests"
    cd_or_error "${sim_test_dir}"
    # TODO: Consider using ${parallel} here.
    make check >> ${logfile} 2>&1
    header "Saving sim results"
    save_results testsuite/libsim
    save_results testsuite/or1ksim
fi
