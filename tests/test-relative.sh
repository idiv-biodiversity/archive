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

mkdir -p "$srcdir"/d
echo a > "$srcdir"/a
echo b > "$srcdir"/d/b

target_dir="$tmpdir/dest"
target="$target_dir/src.tar.gz"

mkdir "$target_dir"

tree "$tmpdir"

# -----------------------------------------------------------------------------
# run
# -----------------------------------------------------------------------------

archive_cmd=$PWD/../archive.sh
cd "$tmpdir" || exit 1
bash "$archive_cmd" src dest/src.tar.gz || exit 1
cd "$OLDPWD" || exit 1

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
cd "$target_dir" || exit 1
head -1 "$target.md5" | md5sum --quiet -c || exit 1

cd "$tmpdir" || exit 1
awk 'NR > 1' "$target.md5" | md5sum --quiet -c || exit 1

# check if extracted tarball is fine
mkdir extracted
cd extracted || exit 1
tar xzf "$target"
tree
awk 'NR > 1' "$target.md5" | md5sum --quiet -c || exit 1
