#!/usr/bin/env bash
# Fixes a known PyTorch3D Windows build issue where Pulsar's GPU renderer
# fails to link with errors like:
#
#   renderer.backward.gpu.obj : error LNK2001: unresolved external symbol
#   "void __cdecl pulsar::Renderer::calc_signature<1>(...)"
#
# even though all translation units compile without error and the right
# .obj files are present in the link line.
#
# Root cause (per community reports, e.g. facebookresearch/pytorch3d#1970):
# pytorch3d/csrc/pulsar/global.h defines, on Windows only:
#
#   #define uint unsigned int
#   #define ushort unsigned short
#
# Being plain macros rather than typedefs, these can expand inconsistently
# across translation units depending on include order (interacting badly
# with CUDA's own headers, which also touch uint/ushort), causing separate
# .cu files to disagree on the mangled name for template instantiations
# like calc_signature<1>. Switching to typedefs (as recommended in that
# thread) resolves it.
#
# Usage: run from the root of a pytorch3d checkout, e.g.:
#   bash /path/to/fix-pulsar-uint-windows.sh
# or point the build workflow's `patch-command` input at this script.

set -euo pipefail

TARGET="pytorch3d/csrc/pulsar/global.h"

if [ ! -f "$TARGET" ]; then
  echo "::error::Expected to find $TARGET relative to the current directory ($(pwd)). Are you running this from the pytorch3d checkout root?"
  exit 1
fi

if grep -q '^typedef unsigned int uint;' "$TARGET"; then
  echo "Patch already applied (or file already uses typedefs) - nothing to do."
  exit 0
fi

if ! grep -q '#define uint unsigned int' "$TARGET"; then
  echo "::warning::Expected macro '#define uint unsigned int' not found in $TARGET - pytorch3d's source may have changed. Skipping patch; build may still fail with the original LNK2001 symptom if this fix was still needed."
  exit 0
fi

sed -i \
  -e 's/#define uint unsigned int/typedef unsigned int uint;/' \
  -e 's/#define ushort unsigned short/typedef unsigned short ushort;/' \
  "$TARGET"

echo "Patched $TARGET: uint/ushort macros -> typedefs"
