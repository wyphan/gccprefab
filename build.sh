\#!/bin/bash

whatscr() { echo "gccprefab - Wil's GCC easy build script"; }
whenscr() { echo "Last updated: Jun 11, 2022 (WYP)"; }

usage() { echo "Usage: $0 [options] configfile"; }

helptext() {
  echo "Available options:"
  echo "  -h, --help      Display this help text"
  # echo "  -v, --verbose   Verbose mode" # FIXME
  echo "  -V, --versions  List available versions to build"
}

stamp() { echo "$(date) $@"; }
now() { date "+%Y%m%d-%H%M%z"; }

push_flag() { FLAGS+=("$1"); }
push_lang() { LANGUAGES+=("$1"); }
push_check() { CHECKS+=("$1"); }

# Taken from https://stackoverflow.com/a/23342259
exe() { echo "\$ $@"; "$@"; }

# Output the value for a given key $1 inside the config file $2
grepln() { grep "$1=" "$2" | awk -F '=' '{print $2}'; }

# Read value from line $1
readvar() { echo "$1" | awk -F '=' '{print $2}'; }

# Output message $2 is verbosity is >= level $1
verb() { if [ ${VERBOSE} -ge $1 ]; then echo "$2"; fi; }

# Turn a Bash array into a comma-separated list
# Adapted from https://stackoverflow.com/a/16203497
# Usage: `export ENVVAR=$(commalist ${ARRAY[@]})`
commalist() { echo "$*" | awk -v OFS=',' '$1=$1'; }

versions() {
  echo "Supported versions:"
  VERS="$(ls -1 *.cfg | tr "\n" ' ')"
  for cfg in ${VERS}; do
    VERSTR=$(grepln "ver" "${cfg}")
    VERDESC=$(grepln "desc" "${cfg}")
    echo -e "- ${cfg}\t${VERSTR}\t${VERDESC}"
  done
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
    FLAG_WITH="--with-"
    FLAG_CHK="check-"

    stamp "Reading config file $2"
    while read -r line; do

      pfx="${line:0:1}"
      eq=$(echo ${line} | grep -c -v '=')

      if [ -z "${line}" ]; then

	# Empty line (treat as end of section)
	SEC=""
        verb 1 "=========="

      elif [ "${pfx}" == "[" ]; then

	# Section header
	SEC="${line:1:(-1)}"
	verb 1 "Section header: ${SEC}"

      elif [ "${pfx}" == '+' ]; then
	val=$(echo "${line}" | awk -F '+' '{print $2}')
	  
	if [ "${SEC}" == "flags" ]; then

	  # Add flag
	  FLAG="${FLAG_YES}${val}"
          push_flag "${FLAG}"
	  verb 1 "Addition flag: ${FLAG}"

	elif [ "${SEC}" == "languages" ]; then

	  # Add language
	  LANG="${val}"
	  push_lang "${LANG}"
	  verb 1 "Add language: ${LANG}"

	else

	  echo "Addition not implemented for section ${SEC}"

	fi # sec
	    
      elif [ "${pfx}" == '~' ]; then
	val=$(echo "${line}" | awk -F '~' '{print $2}')

	if [ "${SEC}" == "flags" ]; then

	  # Subtract flag
	  FLAG="${FLAG_NO}${val}"
          push_flag "${FLAG}"
	  verb 1 "Removal flag: ${FLAG}"

	else

	  echo "Removal not implemented for section ${SEC}"

	fi # sec

      else

	if [ "${SEC}" == "version" ]; then

	  if [ ${eq} ]; then
	    case "${line}" in
  
	      ver* )
		# Version code
		export VER=$(readvar "${line}")
		verb 1 "Version code: ${VER}"
		;;

	      desc* )
	        # Version description
	        export DESC=$(readvar "${line}")
		verb 1 "Version description: ${DESC}"
		;;

	      git* )
		# Custom Git repo link
	        export CUSTOMGIT=$(readvar "${line}")
		verb 1 "Using custom Git repo at ${CUSTOMGIT}"
		;;

	      source* )
		# Source directory
		export SRCDIR=$(eval echo $(readvar "${line}"))
		;;

	      build* )
		# Build directory
		export BLDDIR=$(eval echo $(readvar "${line}"))
		;;

	      tree* )
		# Git branch to build
		export TREE=$(readvar "${line}")
		;;
	      
	      * )
		echo "Unsupported key pair ${line}"
		;;

	    esac # line
	  else
	    echo "Please use a key=val pair in section ${SEC} instead of ${line}"
	  fi # eq

	elif [ "${SEC}" == "build" ]; then

	  if [ eq ]; then
	    case "${line}" in

	      njobs* )
		# Number of jobs for `make -j`
		export NJOBS=$(readvar "${line}")
		;;

	      * )
		echo "Unsupported key pair ${line}"
		;;

	    esac # line
	  else
	    echo "Please use a key=val pair in section ${SEC} instead of ${line}"
	  fi # eq
	  
	elif [ "${SEC}" == "flag" ]; then

	  # Normal flag
	  FLAG="${line}"
          push_flag "${FLAG}"
	  verb 1 "Normal flag: ${FLAG}"

	elif [ "${SEC}" == "languages" ]; then

	  if [ "${line}" == "default" ]; then	
	    def_languages
	    verb 1 "Using default languages: ${LANGUAGES[@]}"
	  fi # default

	elif [ "${SEC}" == "checks" ]; then

	  CHECK="${FLAG_CHK}${line}"
          push_check "${CHECK}"
	  verb 1 "Add test: ${CHECK}"

	else

	  echo "Option ${line} not implemented for section ${SEC}"

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

# Git repo URL
GCCGIT="git://gcc.gnu.org/git/gcc.git"
CUSTOMGIT=""

# Version to build
VER=""

# Directories and branches/tags
ROOTDIR="$(pwd)"
SRCDIR=""
BLDDIR=""
TREE=""

# Verbosity
VERBOSE=0

# Current development branch
SRCDIR_DEV="${ROOTDIR}/src"
BLDDIR_DEV="${ROOTDIR}/build/dev"
TREE_DEV=

# Prerequisites
declare -a PREREQS
PREREQS+=("gmp")
PREREQS+=("isl")
PREREQS+=("mpc")
PREREQS+=("mpfr")

# Languages
declare -a LANGUAGES
def_languages() {
  push_lang "c"
  push_lang "c++"
  push_lang "fortran"
}

# Set up configure flags
CFGFLAGS=""
declare -a FLAGS
FLAGS+=("--prefix=${BLDDIR}")

# Set up list of tests
declare -a CHECKS

# Check argc and bail out if no options or build config files are specified
if [ $# -lt 1 ]; then
  usage; versions; exit 0
else
  case "$1" in
    "-h" | "--help" ) whatscr; whenscr; usage; helptext; versions; exit 0 ;;
    # "-v" | "--verbose" ) export VERBOSE=1; shift 1 ;; # FIXME
    "-V" | "--versions" ) versions; exit 0 ;;
    * )
      # Read build config file
      readcfg -1 "$1"
      FLAGS+=("--languages=$(commalist ${LANGUAGES[@]})")	
      ;;
  esac
fi # argc

# Logfiles
NOW="$(now)"
CFGLOG="${ROOTDIR}/${NOW}-configure-gcc${VER}.log"
BLDLOG="${ROOTDIR}/${NOW}-build-gcc${VER}.log"
TSTLOG="${ROOTDIR}/${NOW}-test-gcc${VER}.log"
INSLOG="${ROOTDIR}/${NOW}-install-gcc${VER}.log"

# Start the build
whatscr; whenscr
stamp "Building GCC ${VER}"
stamp "Source dir: ${SRCDIR}"
stamp "Build dir:  ${BLDDIR}"

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
  echo "$ ${CFGSCR} ${FLAGS[@]} > ${CFGLOG} 2>&1"
  "${CFGSCR}" ${CFG[@]} > ${CFGLOG} 2>&1
  status 3 "configure" "${CFGLOG}"

  # Build
  stamp "Build..."
  echo "$ make -j ${NJOBS} > ${BLDLOG} 2>&1"
  make -j ${NJOBS} > ${BLDLOG} 2>&1
  status 4 "build" "${BLDLOG}"

  # Test
  stamp "Test..."
  for t in ${CHECKS[@]}; do
    echo "$ make -k $t > ${TSTLOG} 2>&1"
    make -k $t > ${TSTLOG} 2>&1
    status 5 "test" "${TSTLOG}"
  done

  # Install
  #stamp "Install..."

popd # BLDDIR
