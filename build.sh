#!/bin/bash

whatscr() { echo "Wil's GCC easy build script"; }
whenscr() { echo "Last updated: May 19, 2022 (WYP)"; }

usage() { echo "Usage: $0 [version]"; }

stamp() { echo "$(date) $@"; }
now() { date "+%Y%m%d-%H%M%z"; }

dblsub() {
  CAPS="$(echo "${VER}" | tr [:lower:] [:upper:])"
  VAR="$(echo "$1_${CAPS}")"
  export "$1"="$(eval echo "\$${VAR}")"
}

# Taken from https://stackoverflow.com/a/23342259
exe() { echo "\$ $@"; "$@"; }

versions() {
  echo "Supported versions:"
  echo "- 12      Latest GCC 12 release"  
  echo "- master  Latest master branch on the main GCC git repo"
}

parsever() {
  found=0
  for v in "${VERS[@]}"; do
    if [ "$1" == "$v" ]; then
      found=1
      VER="$v"
    fi
  done
  if [ ${found} -ne 1 ]; then
    echo "Unsupported version $1"
    versions
    exit 1
  else
    dblsub SRCDIR
    dblsub BLDDIR
    dblsub TREE
  fi
}

checkout() {
  exe git checkout "${TREE}"
  if [ $? -ne 0 ]; then
    stamp "Cannot checkout ${TREE}"
    stamp "Output of git status:"
    git status
  fi	
}

# Check status of previous operation
# Usage: `status [error-code] [phase-name] [logfile]
status() {
  ierr=$?
  errcode=$1  
  phase="$2"  
  logfile="$3"  
  if [ ${ierr} -ne 0 ]; then
    stamp "${phase^} phase failed with error ${ierr}"
    stamp "Check $3 for more details"
    exit $1
  else
    stamp "Finished ${phase} phase!"
    # Compress logfile
    stamp "Compressing ${logfile}..."
    xz ${logfile}
    stamp "Compressed into ${logfile}.xz"
  fi  
}

# Threads for make -j
NTHR=12

# Git repo URL
GCCGIT="git://gcc.gnu.org/git/gcc.git"

# Versions
VER=""
declare -a VERS
VERS+=("12")
VERS+=("master")

# Directories and branches/tags
ROOTDIR="$(pwd)"
SRCDIR=""
BLDDIR=""
TREE=""

# GCC master branch
SRCDIR_MASTER="${ROOTDIR}/src"
BLDDIR_MASTER="${ROOTDIR}/build/master"
TREE_MASTER="master"

# GCC 12 release tag
SRCDIR_12="${ROOTDIR}/src"
BLDDIR_12="${ROOTDIR}/build/gcc-12"
TREE_12="releases/gcc-12"

# Prerequisites
declare -a PREREQS
PREREQS+=("gmp")
PREREQS+=("isl")
PREREQS+=("mpc")
PREREQS+=("mpfr")

# Flags
LANGUAGES="--enable-languages=c,c++,fortran"
NOBOOTSTRAP="--disable-bootstrap"
NOSANITIZER="--disable-libsanitizer"
NOMULTILIB="--disable-multilib"

# Check argc and bail out if no versions are specified
if [ $# -lt 1 ]; then
  usage; versions; exit 0
else
  parsever "$1"
fi

# Set up configure flags
CFGFLAGS=""
declare -a CFG
CFG+=("${LANGUAGES}")
CFG+=("${NOBOOTSTRAP}")
CFG+=("${NOSANITIZER}")
CFG+=("${NOMULTILIB}")
CFG+=("--prefix=${BLDDIR}")

# Set up tests
declare -a TST
TST+=("check")

# Logfiles
NOW="$(now)"
CFGLOG="${ROOTDIR}/${NOW}-configure-gcc${VER}.log"
BLDLOG="${ROOTDIR}/${NOW}-build-gcc${VER}.log"
TSTLOG="${ROOTDIR}/${NOW}-test-gcc${VER}.log"

# Start the build
whatscr; whenscr
stamp "Building GCC ${VER}"
stamp "Source: ${SRCDIR}"
stamp "Build:  ${BLDDIR}"

if [ ! -d "${SRCDIR}" ]; then

  # Download source tree if nonexistent
  exe git clone "${GCCGIT}" "${SRCDIR}"

  pushd "${SRCDIR}"

    # Checkout selected branch/tag
    checkout

    # Download prerequisites
    PRESCR="${SRCDIR}/contrib/download_prerequisites"
    exe ${PRESCR} --verify

  popd # SRCDIR

else  

  pushd "${SRCDIR}"

    # Stash work and checkout selected branch/tag
    exe git stash push -m "WIP-$(now)"
    checkout

    # Check for prerequisites
    cnt=0
    for d in "${PREREQS[@]}"; do
      if [ -h "$d" ]; then
        cnt=$(( ${cnt} + 1 ))
      else
        stamp "Prerequisite $d not found as a linked dir"
	stamp "Please rerun contrib/download_prerequisites"
        exit 2
      fi
    done

  popd # SRCDIR

fi # SRCDIR

# Delete and recreate build directory if it exists
if [ -d "${BLDDIR}" ]; then
  exe rm -rf "${BLDDIR}"
fi
exe mkdir -p "${BLDDIR}"

pushd "${BLDDIR}"

  # Configure
  stamp "Configure..."
  CFGSCR="${SRCDIR}/configure"
  echo "$ ${CFGSCR} ${CFG[@]} > ${CFGLOG} 2>&1"
  "${CFGSCR}" ${CFG[@]} > ${CFGLOG} 2>&1
  status 3 "configure" "${CFGLOG}"

  # Build
  stamp "Build..."
  echo "$ make -j ${NTHR} > ${BLDLOG} 2>&1"
  make -j ${NTHR} > ${BLDLOG} 2>&1
  status 4 "build" "${BLDLOG}"

  # Test
  stamp "Test..."
  for t in "${TST[@]}"; do
    echo "$ make -k $t > ${TSTLOG} 2>&1"
    make -k $t > ${TSTLOG} 2>&1
  done
  status 5 "test" "${TSTLOG}"

  # Install
  #stamp "Install..."

popd # BLDDIR
