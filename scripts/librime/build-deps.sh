#!/usr/bin/env bash
# Ticket 02: cross-compile librime's third-party dependencies for iOS.
#
# Builds, for each slice (arm64-iphoneos, arm64-iphonesimulator,
# x86_64-iphonesimulator):
#   glog, leveldb, marisa-trie, opencc, yaml-cpp  (librime's git submodules)
#   boost regex                                   (librime's only Boost component)
#
# Output layout: .scratch/librime-deps/<slice>/{include,lib} — consumed by
# ticket 03 (librime XCFramework). Reproducible from a clean checkout:
#   scripts/librime/fetch.sh   # clone librime at the pinned tag + submodules
#   scripts/librime/build-deps.sh
set -euo pipefail

LIBRIME_VERSION="1.17.0"
BOOST_VERSION="1.89.0"
DEPLOYMENT_TARGET="16.0"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ROOT="$(git rev-parse --show-toplevel)"
SRC="$ROOT/.scratch/librime"
OUT="$ROOT/.scratch/librime-deps"

SLICES=("iphoneos:arm64" "iphonesimulator:arm64" "iphonesimulator:x86_64")

log() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

sdk_path() { xcrun --sdk "$1" --show-sdk-path; }

build_cmake_dep() { # $1 dep dir, $@ extra cmake args
  local dep="$1"; shift
  for slice in "${SLICES[@]}"; do
    local sdk="${slice%%:*}" arch="${slice##*:}"
    local name="${sdk}-${arch}"
    log "$dep → $name"
    cmake -S "$SRC/deps/$dep" -B "$SRC/build-deps/$dep/$name" -G Ninja \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_SYSROOT="$sdk" \
      -DCMAKE_OSX_ARCHITECTURES="$arch" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_TESTING=OFF \
      -DCMAKE_INSTALL_PREFIX="$OUT/$name" \
      "$@"
    cmake --build "$SRC/build-deps/$dep/$name"
    cmake --install "$SRC/build-deps/$dep/$name" >/dev/null
  done
}

# --- glog ---
build_cmake_dep glog -DWITH_GFLAGS=OFF -DWITH_GTEST=OFF

# --- leveldb ---
build_cmake_dep leveldb -DLEVELDB_BUILD_TESTS=OFF -DLEVELDB_BUILD_BENCHMARKS=OFF

# --- marisa-trie ---
build_cmake_dep marisa-trie -DENABLE_TOOLS=OFF

# --- opencc ---
# Cross-compiling makes CMake treat its CLI tools as MACOSX_BUNDLE, whose
# install rules then fail at generate time (no BUNDLE DESTINATION). We don't
# need the tools (libraries only), so disable the tools subdirectory in the
# submodule checkout (idempotent), build libopencc only, and copy artifacts
# manually. The bundled marisa is compiled in but NOT installed — its symbols
# resolve against our marisa-trie build at final link time.
log "opencc (custom: no tools/data, manual install)"
sed -i '' -E 's|^add_subdirectory\(tools\)|# add_subdirectory(tools) # disabled for iOS cross build|' \
  "$SRC/deps/opencc/src/CMakeLists.txt"
sed -i '' -E 's|^add_subdirectory\(data\)|# add_subdirectory(data) # needs tools, disabled for iOS cross build|' \
  "$SRC/deps/opencc/CMakeLists.txt"
for slice in "${SLICES[@]}"; do
  sdk="${slice%%:*}"; arch="${slice##*:}"; name="${sdk}-${arch}"
  log "opencc → $name"
  cmake -S "$SRC/deps/opencc" -B "$SRC/build-deps/opencc/$name" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$sdk" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DENABLE_GTEST=OFF
  cmake --build "$SRC/build-deps/opencc/$name" --target libopencc
  mkdir -p "$OUT/$name/include/opencc" "$OUT/$name/lib"
  cp "$SRC/build-deps/opencc/$name/src/libopencc.a" "$OUT/$name/lib/"
  find "$SRC/deps/opencc/src" -maxdepth 1 -name '*.h*' ! -name '*Test*' \
    -exec cp {} "$OUT/$name/include/opencc/" \;
  cp "$SRC/build-deps/opencc/$name/src/Opencc_Export.h" \
     "$SRC/build-deps/opencc/$name/src/opencc_config.h" \
     "$OUT/$name/include/opencc/" 2>/dev/null || true
done

# --- yaml-cpp ---
build_cmake_dep yaml-cpp -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF -DYAML_CPP_BUILD_CONTRIB=OFF

# --- boost regex ---
BOOST_US="${BOOST_VERSION//./_}"
BOOST_DIR="$SRC/deps/boost-${BOOST_VERSION}"
if [[ ! -d "$BOOST_DIR" ]]; then
  log "download boost ${BOOST_VERSION}"
  curl -fL "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_US}.tar.gz" \
    -o "$SRC/deps/boost_${BOOST_US}.tar.gz"
  echo "9de758db755e8330a01d995b0a24d09798048400ac25c03fc5ea9be364b13c93  $SRC/deps/boost_${BOOST_US}.tar.gz" | shasum -a 256 -c
  tar -xzf "$SRC/deps/boost_${BOOST_US}.tar.gz" -C "$SRC/deps"
  mv "$SRC/deps/boost_${BOOST_US}" "$BOOST_DIR"
fi

if [[ ! -x "$BOOST_DIR/b2" ]]; then
  log "bootstrap boost"
  (cd "$BOOST_DIR" && ./bootstrap.sh --with-toolset=clang --with-libraries=regex)
fi

declare -A TRIPLE=( [iphoneos:arm64]=arm64-apple-ios${DEPLOYMENT_TARGET} \
                    [iphonesimulator:arm64]=arm64-apple-ios${DEPLOYMENT_TARGET}-simulator \
                    [iphonesimulator:x86_64]=x86_64-apple-ios${DEPLOYMENT_TARGET}-simulator )
declare -A B2ARCH=( [iphoneos:arm64]=arm [iphonesimulator:arm64]=arm [iphonesimulator:x86_64]=x86 )

for slice in "${SLICES[@]}"; do
  name="${slice%%:*}-${slice##*:}"
  log "boost regex → $name (${TRIPLE[$slice]})"
  (cd "$BOOST_DIR" && ./b2 -q -a \
    link=static variant=release threading=multi \
    toolset=clang target-os=iphone \
    architecture="${B2ARCH[$slice]}" address-model=64 \
    cxxflags="-target ${TRIPLE[$slice]}" \
    linkflags="-target ${TRIPLE[$slice]}" \
    --stagedir="stage-$name" --with-regex)
  mkdir -p "$OUT/$name/include" "$OUT/$name/lib"
  rsync -a --delete "$BOOST_DIR/boost" "$OUT/$name/include/"
  cp "$BOOST_DIR/stage-$name/lib/libboost_regex.a" "$OUT/$name/lib/"
done

# --- record pins + verify slices ---
cat > "$OUT/VERSIONS" <<EOF
librime: $LIBRIME_VERSION
boost: $BOOST_VERSION
deployment target: $DEPLOYMENT_TARGET
deps: glog leveldb marisa-trie opencc yaml-cpp (submodule SHAs pinned by the librime tag)
EOF

log "verify slices"
fail=0
for slice in "${SLICES[@]}"; do
  name="${slice%%:*}-${slice##*:}"
  want="${slice##*:}"
  while IFS= read -r -d '' lib; do
    info=$(lipo -info "$lib" 2>/dev/null || echo "NOT-A-FAT-OR-BAD")
    case "$info" in
      *"$want"*) echo "OK   $name $(basename "$lib")" ;;
      *) echo "BAD  $name $(basename "$lib"): $info"; fail=1 ;;
    esac
  done < <(find "$OUT/$name/lib" -name '*.a' -print0)
done
[[ $fail -eq 0 ]] && log "all slices verified" || { log "SLICE VERIFICATION FAILED"; exit 1; }
