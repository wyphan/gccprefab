#!/bin/bash

whatscr() { echo "gccprefab - Wil's GCC easy build script"; }
whenscr() { echo "Last updated: Jun 4, 2022 (WYP)"; }

usage() { echo "Usage: $0 [version]"; }

stamp() { echo "$(date) $@"; }
now() { date "+%Y%m%d-%H%M%z"; }

# Bash double substitution
dblsub() {
  CAPS="$(echo $(eval echo \$$2) | tr [:lower:] [:upper:])"
  VAR="$(echo "$1_${CAPS}")"
  export "$1"="$(eval echo "\$${VAR}")"
}

pusharr() { "$1"+=("$2"); }
poparr() {}

# Taken from https://stackoverflow.com/a/23342259
exe() { echo "\$ $@"; "$@"; }

versions() {
  echo "Supported versions:"
  echo "- 11      Latest GCC 11 release"
  echo "- 12      Latest GCC 12 release"
  echo "- master  Latest master branch on the main GCC git repo"
  echo "- dev     Current development branch"
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
    dblsub SRCDIR VER
    dblsub BLDDIR VER
    dblsub TREE VER
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

# Read configuration file
# Usage: `readcfg [error-code] [cfgfile]`
readcfg() {

  # First, check read access
  if [ ! -r "$2" ]; then
    stamp "Cannot read config file $2"
    exit $1
  else

    # Internal vars
    SEC=""
    FLAG_YES="--enable-"
    FLAG_NO="--disable-"

    while read -r line; do

      pfx="${line:0:1}"

      if [ "${pfx}" == "[" ]; then

	# Section header
	SEC="${line:1:(-1)}"
	verb 1 "Section header: ${SEC}"

      elif [ "${pfx}" == "+" ]; then

	if [ "${SEC}" == "flags" ]; then

	  # Add flag
	  FLAG="${FLAG_YES}${line:1::}"
          pusharr FLAGS FLAG
	  verb 1 "Addition flag: ${FLAG}"

	elif [ "${SEC}" == "languages" ]; then

	  # Add language
	  LANG="${line}"
	  pusharr LANGUAGES LANG
	  verb 1 "Add language: ${LANG}"

	fi # sec
	    
      elif [ "${pfx}" == "~" ]; then

	if [ "${SEC}" == "flags" ]; then

	  # Subtract flag
	  FLAG="${FLAG_NO}${line:1::}"
          pusharr FLAGS FLAG
	  verb "Removal flag: ${FLAG}"

	elif [ "${SEC}" == "languages" ]; then

	  # Remove language
	  LANG="${line}"
	  poparr LANGUAGES LANG  
	  verb "Remove language: ${LANG}"

	fi # sec

      else

	if [ "${SEC}" == "version" ]; then

	  # Version code
	  export VER="${line}"
	    
	elif [ "${SEC}" == "flag" ]; then

	  # Normal flag
	  FLAG="${FLAG_YES}${line:1::}"
          pusharr FLAGS FLAG
	  verb 1 "Addition flag: ${FLAG}"

	else

	  # Defaults
	  def_languages

	fi # sec

      fi # pfx

    done < "$2"
  fi # readable
}

# Check status of previous operation
# Usage: `status [error-code] [phase-name] [logfile]`
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
NTHREADS=12

# Git repo URL
GCCGIT="git://gcc.gnu.org/git/gcc.git"

# Versions
VER=""
declare -a VERS
VERS+=("11")
VERS+=("12")
VERS+=("master")

# Directories and branches/tags
ROOTDIR="$(pwd)"
SRCDIR=""
BLDDIR=""
TREE=""

# Current development branch
SRCDIR_DEV="${ROOTDIR}/src"
BLDDIR_DEV="${ROOTDIR}/build/dev"
TREE_DEV=$(git branch --show-current)

# GCC master branch
SRCDIR_MASTER="${ROOTDIR}/src"
BLDDIR_MASTER="${ROOTDIR}/build/master"
TREE_MASTER="master"

# GCC 11 release tag
SRCDIR_11="${ROOTDIR}/src"
BLDDIR_11="${ROOTDIR}/build/gcc-11"
TREE_11="releases/gcc-11"

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

# Languages
declare -a LANGUAGES
def_languages() {
  pusharr LANGUAGES "c"
  pusharr LANGUAGES "c++"
  pusharr LANGUAGES "fortran"
}

# Check argc and bail out if no versions are specified
if [ $# -lt 1 ]; then
  usage; versions; exit 0
else
  parsever "$1"
fi

# Set up configure flags
CFGFLAGS=""
declare -a FLAGS
FLAGS+=("${LANGUAGES}")
FLAGS+=("${NOBOOTSTRAP}")
FLAGS+=("${NOSANITIZER}")
FLAGS+=("${NOMULTILIB}")
FLAGS+=("--prefix=${BLDDIR}")

# Set up tests
declare -a CHECKS
CHECKS+=("check-fortran")

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

    if [ "${VER}" != "dev" ]; then
      # Stash work and checkout selected branch/tag
      exe git stash push -m "WIP-$(now)"
      checkout
    fi # dev

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
