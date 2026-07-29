#!/usr/bin/env bash
# Ticket 03: build librime core and assemble Rime.xcframework.
#
# Consumes ticket 02's prefixes (.scratch/librime-deps/<slice>) and produces:
#   .scratch/librime-deps/Rime.xcframework      (ios-arm64 + ios-simulator fat)
#   vendor/licenses/                            (third-party licenses, committed)
#
# The XCFramework ships one combined static library per platform slice —
# librime-static merged with all ticket-02 deps — plus the public C API
# headers and a module map, so Swift can `import Rime` with no C++ exposure.
set -euo pipefail

DEPLOYMENT_TARGET="16.0"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ROOT="$(git rev-parse --show-toplevel)"
SRC="$ROOT/.scratch/librime"
DEPS="$ROOT/.scratch/librime-deps"
BUILD="$SRC/build-librime"
HEADERS_STAGING="$BUILD/headers"

SLICES=("iphoneos:arm64" "iphonesimulator:arm64" "iphonesimulator:x86_64")
DEP_LIBS=(libglog.a libleveldb.a libmarisa.a libopencc.a libyaml-cpp.a libboost_regex.a)

log() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# --- 1. librime-static per slice ---
for slice in "${SLICES[@]}"; do
  sdk="${slice%%:*}"; arch="${slice##*:}"; name="${sdk}-${arch}"
  log "librime → $name"
  cmake -S "$SRC" -B "$BUILD/$name" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$sdk" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_PREFIX_PATH="$DEPS/$name" \
    -DCMAKE_FIND_ROOT_PATH="$DEPS/$name" \
    -DBoost_ROOT="$DEPS/$name" \
    -DBoost_INCLUDE_DIR="$DEPS/$name/include" \
    -DBoost_LIBRARY_DIR="$DEPS/$name/lib" \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC=ON \
    -DBUILD_TEST=OFF
  cmake --build "$BUILD/$name" --target rime-static

  log "merge static libs → $name"
  mkdir -p "$BUILD/$name/merged"
  # NOTE: rime-static's OUTPUT_NAME is "rime" (lib/librime.a), and macOS
  # libtool only *warns* on missing inputs — so verify symbols afterwards.
  libtool -static -o "$BUILD/$name/merged/librime-combined.a" \
    "$BUILD/$name/lib/librime.a" \
    $(for lib in "${DEP_LIBS[@]}"; do echo "$DEPS/$name/lib/$lib"; done)
  if ! nm "$BUILD/$name/merged/librime-combined.a" | grep 'T _rime_get_api' >/dev/null 2>&1; then
    echo "FATAL: merged archive for $name lacks rime symbols" >&2
    exit 1
  fi
done

# --- 2. fat simulator lib + XCFramework ---
SIM_FAT="$BUILD/iphonesimulator-fat"
mkdir -p "$SIM_FAT"
log "lipo simulator slices"
lipo -create \
  "$BUILD/iphonesimulator-arm64/merged/librime-combined.a" \
  "$BUILD/iphonesimulator-x86_64/merged/librime-combined.a" \
  -output "$SIM_FAT/librime-combined.a"
lipo -info "$SIM_FAT/librime-combined.a"

log "stage headers + module map"
rm -rf "$HEADERS_STAGING" && mkdir -p "$HEADERS_STAGING"
cp "$SRC/src/rime_api.h" "$SRC/src/rime_api_stdbool.h" "$SRC/src/rime_levers_api.h" \
   "$SRC/src/rime_api_deprecated.h" "$HEADERS_STAGING/"
cat > "$HEADERS_STAGING/module.modulemap" <<'EOF'
module Rime [system] {
  header "rime_api.h"
  header "rime_api_stdbool.h"
  header "rime_levers_api.h"
  export *
}
EOF

log "create Rime.xcframework"
rm -rf "$DEPS/Rime.xcframework"
xcodebuild -create-xcframework \
  -library "$BUILD/iphoneos-arm64/merged/librime-combined.a" -headers "$HEADERS_STAGING" \
  -library "$SIM_FAT/librime-combined.a" -headers "$HEADERS_STAGING" \
  -output "$DEPS/Rime.xcframework"

# --- 3. collect third-party licenses ---
log "collect licenses"
LIC="$ROOT/vendor/licenses"
mkdir -p "$LIC"
cp "$SRC/LICENSE" "$LIC/librime-LICENSE.txt"
cp "$SRC/deps/glog/COPYING" "$LIC/glog-COPYING.txt"
cp "$SRC/deps/leveldb/LICENSE" "$LIC/leveldb-LICENSE.txt"
cp "$SRC/deps/marisa-trie/COPYING.md" "$LIC/marisa-trie-COPYING.md" 2>/dev/null \
  || cp "$SRC/deps/marisa-trie/COPYING" "$LIC/marisa-trie-COPYING.txt"
cp "$SRC/deps/opencc/LICENSE" "$LIC/opencc-LICENSE.txt"
cp "$SRC/deps/yaml-cpp/LICENSE" "$LIC/yaml-cpp-LICENSE.txt"
cp "$SRC/deps/boost-1.89.0/LICENSE_1_0.txt" "$LIC/boost-LICENSE_1_0.txt"
ls "$LIC"

# --- 4. verify ---
log "verify XCFramework"
xcodebuild -create-xcframework -list "$DEPS/Rime.xcframework" 2>/dev/null || true
find "$DEPS/Rime.xcframework" -name '*.a' | while read -r lib; do
  echo "-- $lib"; lipo -info "$lib"
done
log "done: $DEPS/Rime.xcframework"
