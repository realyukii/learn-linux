#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: BASE_INTERP= OUT_DIR= $0 <executable>"
    exit 1
fi

EXE="$1"
EXE_NAME=$(basename "$EXE")

if [ -z ${OUT_DIR+x} ]; then
	OUT_DIR="output-${EXE_NAME}"
fi

# Validate input
if [ ! -f "$EXE" ]; then
    echo "Error: File '$EXE' not found" >&2
    exit 1
fi
if ! file "$EXE" | grep -q "ELF .* executable"; then
    echo "Error: '$EXE' is not an ELF executable" >&2
    exit 1
fi

# Create output directory structure
if [ ! -d "${OUT_DIR}/lib" ]; then
	mkdir -vp "${OUT_DIR}/lib"
fi

cp "$EXE" "$OUT_DIR/"

# Get dependencies using ldd and copy to lib directory
echo "Copying dependencies..."
ldd "$EXE" | awk '
    /=> \// { print $3 }    # Normal libraries
    /^\//  { print $1 }     # Directly linked libraries (no arrow)
' | grep -v -e "linux-vdso" -e "ld-linux" | while read -r lib; do
    [ -e "$lib" ] && cp -L "$lib" "${OUT_DIR}/lib/"
done

if [ -z ${BASE_INTERP+x} ]; then
	BASE_INTERP='./lib'
fi

# Copy dynamic linker separately (for patching)
INTERP=$(patchelf --print-interpreter "$EXE" 2>/dev/null || true)
if [ -n "$INTERP" ]; then
    cp -L "$INTERP" "${OUT_DIR}/lib/"
    patchelf --set-interpreter "$BASE_INTERP/$(basename "$INTERP")" "${OUT_DIR}/${EXE_NAME}"
fi

# Set rpath to use local lib directory
patchelf --set-rpath '$ORIGIN/lib' "${OUT_DIR}/${EXE_NAME}"

echo "Successfully created portable package in '$OUT_DIR'"
echo "To run on another system:"
echo "  cp -r $OUT_DIR <target-machine>"
echo "  ${OUT_DIR}/${EXE_NAME}"
