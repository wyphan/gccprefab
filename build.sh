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

# Threads for make -j
NTHR=12

# Git repo URL
GCCGIT="git://gcc.gnu.org/git/gcc.git"

# Versions
VER=""
declare -a VERS
VERS+="master"

# Directories and branches/tags
ROOTDIR="$(pwd)"
SRCDIR=""
BLDDIR=""
TREE=""

# GCC master branch
SRCDIR_MASTER="${ROOTDIR}/src"
BLDDIR_MASTER="${ROOTDIR}/build/master"
TREE_MASTER="master"

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

fi

# Delete and recreate build directory if it exists
if [ -d "${BLDDIR}" ]; then
  exe rm -rf "${BLDDIR}"
  exe mkdir -p "${BLDDIR}"
fi

pushd "${BLDDIR}"

  # Configure
  stamp "Configure..."
  CFGSCR="${SRCDIR}/configure"
  echo "$ ${CFGSCR} ${CFG[@]} 2&>1 > ${CFGLOG}"
  "${CFGSCR}" ${CFG[@]} 2&>1 > ${CFGLOG}

  status=$?
  if [ ${status} -ne 0 ]; then
    stamp "Configure failed with error ${status}"
    stamp "Check ${CFGLOG} for more details"
    exit 3
  else
    # Compress configure logfile
    xz ${CFGLOG}
  fi

  # Build
  stamp "Build..."
  echo "$ make -j ${NTHR} 2&>1 > ${BLDLOG}"
  make -j ${NTHR} 2&>1 > ${BLDLOG}

  status=$?
  if [ ${status} -ne 0 ]; then
    stamp "Build failed with error ${status}"
    stamp "Check ${BLDLOG} for more details"
    exit 3
  else
    # Compress build logfile
    xz ${BLDLOG}
  fi

  # Test
  #stamp "Test..."

  # Install
  #stamp "Install..."

popd # BLDDIR
