#!/bin/sh

# Copyright (C) 2009, 2013, 2014 Embecosm Limited
# Contributor Andrew Burgess  <andrew.burgess@embecosm.com>

# This file is part of the Embecosm LLVM build system for OR1K.

# This file is distributed under the University of Illinois Open Source
# License. See COPYING for details.

#		SCRIPT TO DEFINE RELEASE SPECIFIC INFORMATION
#               =============================================

# Script must be sourced, since it sets up environment variables for the
# parent script.

# Defines the RELEASE, LOGDIR and RESDIR environment variables, creating the
# LOGDIR and RESDIR directories if they don't exist.

# Usage:

#     . define-release.sh

# The variable ${OR1K_TOP} must be defined, and be the absolute directory
# containing all the repositories.

if [ "x${OR1K_TOP}" = "x" ]
then
    echo "define-release.sh: Top level directory not defined."
    exit 1
fi

# The release number
RELEASE=master

# Create a common log directory for all logs
LOGDIR=${OR1K_TOP}/logs-${RELEASE}
mkdir -p ${LOGDIR}

# Create a common results directory in which sub-directories will be created
# for each set of tests.
RESDIR=${OR1K_TOP}/results-${RELEASE}
mkdir -p ${RESDIR}

# Export the environment variables
export RELEASE
export LOGDIR
export RESDIR
