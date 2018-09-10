#!/usr/bin/env bash

# safety first
set \
  -o errexit \
  -o pipefail \
  -o noglob \
  -o nounset \

app=$(basename "$0" .sh)

version="1.1.2"

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

  $app [options] [--] input [output]

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
verbose=no

for arg in "$@"
do
  case "$arg" in
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

set +o nounset
shopt -s extglob
input="${1%%+(/)}"
shift || bailout "missing argument: input"
shopt -u extglob
set -o nounset

if [[ "$*" == "" ]]
then
  output=$input.tar.gz
else
  output=$1
  shift
fi

if [[ "$*" != "" ]]
then
  bailout "trailing arguments: $*"
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
- $app $version
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

# -----------------------------------------------------------------------------
# preparation
# -----------------------------------------------------------------------------

if [[ "${output:0:1}" != "/" ]]
then
  output="$PWD/$output"
fi

output_dir=$(dirname "$output")

if [[ ! -e $output_dir ]]
then
  mkdir -p "$output_dir"
fi

output_bs=$(stat -c %o "$output_dir")

input_dir="$(dirname "$input")"

cd "$input_dir" ||
  bailout "unable to change to input directory: $input_dir"

input=$(basename "$input")

output_hash_file="$output.md5"

# -----------------------------------------------------------------------------
# create archive
# -----------------------------------------------------------------------------

[[ $verbose == yes ]] &&
  log.info "creating archive"

tar cz "$input" |
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
