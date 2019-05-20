#!/usr/bin/env bash

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

outside="$tmpdir/outside"

mkdir "$outside"
echo a > "$outside"/a
mkdir "$outside"/d
echo b > "$outside"/d/b

mkdir "$srcdir"
echo f > "$srcdir"/f
pushd "$srcdir" &> /dev/null || exit 1
ln -s "$outside"/a a
ln -s "$outside"/d d
popd &> /dev/null || exit 1

tree "$tmpdir"

# -----------------------------------------------------------------------------
# run
# -----------------------------------------------------------------------------

bash ../archive.sh -h "$srcdir" "$target"

# -----------------------------------------------------------------------------
# tests
# -----------------------------------------------------------------------------

set -x

# check if tarball contains correct paths
tar tzf "$target" | grep -q src/a || exit 1
tar tzf "$target" | grep -q src/f || exit 1
tar tzf "$target" | grep -q src/d/b || exit 1

# check if checksum file contains correct paths
grep -q src/a "$target.md5" || exit 1
grep -q src/f "$target.md5" || exit 1
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
