#!/bin/bash

# safety first
set \
  -o errexit \
  -o pipefail \
  -o noglob \
  -o nounset \

app=$(basename "$0" .sh)

version="2.0.2"

# -----------------------------------------------------------------------------
# utilities
# -----------------------------------------------------------------------------

function log.info {
  if [[ -t 1 ]]
  then
    echo -e "\\e[1m$app: $*\\e[0m"
  else
    echo "$app: $*"
  fi
}

function log.error {
  if [[ -t 2 ]]
  then
    echo -e "\\e[1m\\e[31m$app: $*\\e[0m" >&2
  else
    echo "$app: $*" >&2
  fi
}

# $1 message
# $2 exit status, optional, defaults to 1
function bailout {
  log.error "$1"
  exit "${2:-1}"
}

function tool.available {
  local tool=$1

  if ! command -v "$tool" &> /dev/null
  then
    bailout "$tool not found"
  fi
}

# -----------------------------------------------------------------------------
# usage
# -----------------------------------------------------------------------------

function usage { cat << EOF
$app $version

USAGE

  $app [options] [--] input

DESCRIPTION

  create an archive and verify its contents

ARGUMENTS

  input                 the directory to be archived,
                        e.g.: /path/to/dir

  --                    ends option parsing

OPTIONS

  -o|--output <output>  the path where the archive should be put
                        e.g.: /path/to/archive.tar.gz
                        defaults to \$input.tar.gz

  -f, --force           overwrites existing output
  -h, --dereference     follow symlinks
  -q, --quiet           disables verbose
  -v, --verbose         output every command as it executes

OTHER OPTIONS

  -?, --help            shows this help text
  --version             shows this tools version

EOF
}

# -----------------------------------------------------------------------------
# external tools
# -----------------------------------------------------------------------------

tool.available archive-sum
tool.available tar

# -----------------------------------------------------------------------------
# configuration
# -----------------------------------------------------------------------------

force=no
symlinks=no
verbose=no

while [[ -v 1 ]]
do
  case "$1" in
    -\?|--help)
      usage
      exit
      ;;

    --version)
      echo "$app $version"
      exit
      ;;

    -f|--force)
      force=yes
      shift
      ;;

    -h|--symlinks)
      symlinks=yes
      shift
      ;;

    -o|--output)
      shift
      output=$1
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
      bailout "unrecognized option: $1"
      ;;

    *)
      break
      ;;
  esac
done

[[ -v 1 ]] || bailout 'missing argument: input'
shopt -s extglob
input="${1%%+(/)}"
shopt -u extglob
shift

[[ -n $input ]] ||
  bailout "no input specified"

[[ -d $input ]] ||
  bailout "input is not an existing directory"

input=$(realpath "$input")

if [[ ! -v output ]]
then
  output=$input.tar.gz
fi

[[ -e $output && $force == "no" ]] &&
  bailout "output already exist"

output=$(realpath -m "$output")

if [[ "$*" != "" ]]
then
  bailout "trailing arguments: $*"
fi

# -----------------------------------------------------------------------------
# configuration: tar options
# -----------------------------------------------------------------------------

case "$output" in
  *.tar.gz|*.tgz)
    tar_options="cz"
    ;;

  *.tar)
    tar_options="c"
    ;;

  *)
    bailout "no matching output file ending"
    ;;
esac

if [[ $symlinks == yes ]]
then
  tar_options="${tar_options}h"
fi

if [[ $verbose == yes ]]
then
  tar_options="${tar_options}v"
fi

# -----------------------------------------------------------------------------
# verbose: output configuration
# -----------------------------------------------------------------------------

[[ $verbose == yes ]] &&
cat << EOF
wd: $PWD
input: $input
output: $output
tar options: $tar_options

versions:
- $app $version
- $(tar --version | head -1)
- $(md5sum --version | head -1)
- $(archive-sum --version)

EOF

# -----------------------------------------------------------------------------
# preparation
# -----------------------------------------------------------------------------

output_dir=$(dirname "$output")

if [[ ! -e $output_dir ]]
then
  mkdir -p "$output_dir"
fi

input_dir=$(dirname "$input")

cd "$input_dir" ||
  bailout "unable to change to input directory: $input_dir"

input=$(basename "$input")

output_hash_file="$output.md5"

# -----------------------------------------------------------------------------
# determine optimal output I/O size
# -----------------------------------------------------------------------------

touch "$output"
output_bs=$(stat -c %o "$output")

# -----------------------------------------------------------------------------
# create archive
# -----------------------------------------------------------------------------

[[ $verbose == yes ]] &&
  log.info "creating archive"

tar "$tar_options" "$input" |
  tee >(md5sum | sed -e "s|-$|$(basename "$output")|" > "$output_hash_file") |
  dd of="$output" bs="$output_bs" status=none ||
  bailout "creating archive failed"

# -----------------------------------------------------------------------------
# verify archive
# -----------------------------------------------------------------------------

[[ $verbose == yes ]] &&
  log.info "verifying archive"

cd "$output_dir" ||
  bailout "unable to change to output directory: $output_dir"

md5sum -c --quiet "$output_hash_file" ||
  bailout "verification error archive itself"

[[ $verbose == yes ]] &&
  log.info "verifying archive contents"

cd "$input_dir" ||
  bailout "unable to change to input directory: $input_dir"

archive-sum -c --append "$output_hash_file" --quiet "$output" ||
  bailout "verification error archive internals"

if [[ $verbose == yes ]]
then
  log.info "done"
fi
