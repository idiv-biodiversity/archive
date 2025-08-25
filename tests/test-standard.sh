#!/bin/bash

# safety first
set \
  -o errexit \
  -o pipefail \
  -o noglob \
  -o nounset \

# -----------------------------------------------------------------------------
# setup
# -----------------------------------------------------------------------------

tmpdir=$(mktemp -p /tmp -d "archive-XXXXXXXXXX")

function trapper {
  rc=$?

  set +x

  if [[ $rc -eq 0 ]]
  then
    echo "$(basename "$0" .sh) SUCCESS"
  else
    echo "$(basename "$0" .sh) FAILURE"
  fi

  rm -fr "$tmpdir"

  exit $rc
}

trap 'trapper' EXIT INT TERM

# -----------------------------------------------------------------------------
# create source files
# -----------------------------------------------------------------------------

srcdir="$tmpdir/src"
target="$srcdir.tar.gz"

mkdir "$srcdir"
echo a > "$srcdir"/a
mkdir "$srcdir"/d
echo b > "$srcdir"/d/b

tree "$tmpdir"

# -----------------------------------------------------------------------------
# run
# -----------------------------------------------------------------------------

bash ../archive.sh "$srcdir" "$target"

# -----------------------------------------------------------------------------
# tests
# -----------------------------------------------------------------------------

set -x

# check if tarball contains correct paths
tar tzf "$target" | grep -q src/a || exit 1
tar tzf "$target" | grep -q src/d/b || exit 1

# check if checksum file contains correct paths
grep -q src/a "$target.md5" || exit 1
grep -q src/d/b "$target.md5" || exit 1

# check if all checksums are fine
cd "$tmpdir" || exit 1
md5sum --quiet -c "$target.md5" || exit 1

# check if extracted tarball is fine
mkdir extracted
cd extracted || exit 1
tar xzf "$target"
tree
awk 'NR > 1' "$target.md5" | md5sum --quiet -c || exit 1
