#!/usr/bin/env bash

# safety first
set -efu -o pipefail

version="1.0.0"

# -----------------------------------------------------------------------------
# usage
# -----------------------------------------------------------------------------

function usage { cat << EOF
archive $version

USAGE

  archive [options] [--] input [output]

DESCRIPTION

  create an archive and verify its contents

ARGUMENTS

  input                 the directory to be archived,
                        e.g.: /path/to/dir

  output                the path where the archive should be put
                        e.g.: /path/to/archive.tar.gz
                        defaults to \$input.tar.gz

  --                    ends option parsing

OPTIONS

  -f, --force           overwrites existing output
  -q, --quiet           disables verbose
  -v, --verbose         output every command as it executes

OTHER OPTIONS

  -h, --help            shows this help text

EOF
}

# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------

# $1 message
# $2 exit status, optional, defaults to 1
function bailout {
  echo "archive: error: $1" >&2
  exit "${2:-1}"
}

# -----------------------------------------------------------------------------
# configuration
# -----------------------------------------------------------------------------

force=no
verbose=no

while true ; do
  case "$1" in
    -h|--help)
      usage
      exit
      ;;

    -f|--force)
      force=yes
      shift
      ;;

    -q|--quiet)
      verbose=no
      shift
      ;;

    -v|--verbose)
      verbose=yes
      shift
      ;;

    --)
      shift
      break
      ;;

    -*)
      echo "archive: unrecognized option: $1" >&2
      usage >&2
      exit 1
      ;;

    *)
      break
      ;;
  esac
done

shopt -s extglob
input="${1%%+(/)}"
shopt -u extglob
shift

if [[ "$*" == "" ]] ; then
  output=$input.tar.gz
else
  output=$1
fi

# -----------------------------------------------------------------------------
# verbose: output configuration
# -----------------------------------------------------------------------------

[[ $verbose == yes ]] &&
cat << EOF
wd: $PWD
input: $input
output: $output

versions:
- archive $version
- $(tar --version | head -1)
- $(md5sum --version | head -1)
- $(archive-sum --version)

EOF

# -----------------------------------------------------------------------------
# check arguments
# -----------------------------------------------------------------------------

[[ -n $input ]] ||
  bailout "no input specified"

[[ -d $input ]] ||
  bailout "input is not an existing directory"

[[ -e $output && $force == "no" ]] &&
  bailout "output already exist"

if [[ "${output:0:1}" != "/" ]] ; then
  output="$PWD/$output"
fi

# -----------------------------------------------------------------------------
# prepare
# -----------------------------------------------------------------------------

output_dir=$(dirname "$output")

if [[ ! -e $output_dir ]] ; then
  mkdir -p "$output_dir"
fi

output_bs=$(stat -c %o "$output_dir")

cd "$(dirname "$input")" ||
  bailout "unable to change to parent of input"

input=$(basename "$input")

output_hash_file="$output.md5"

# -----------------------------------------------------------------------------
# create archive
# -----------------------------------------------------------------------------

[[ $verbose == yes ]] &&
set -x

tar cz "$input" |
  tee >(md5sum | sed -e "s|-$|$(basename "$output")|" > "$output_hash_file") |
  dd of="$output" bs="$output_bs" status=none

# -----------------------------------------------------------------------------
# verify archive
# -----------------------------------------------------------------------------

md5sum -c --quiet "$output_hash_file" ||
  bailout "verification error archive itself"

archive-sum -c --append "$output_hash_file" --quiet "$output" ||
  bailout "verification error archive internals"
