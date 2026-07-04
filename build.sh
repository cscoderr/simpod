#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

NATIVE_DIR="$ROOT/packages/native"
CLI_DIR="$ROOT/packages/simpod"
CLIENT_DIR="$ROOT/packages/simpod_client"
BUILD_DIR="$ROOT/build"
HELPER_BIN="simpod-helper-bin"

echo "Building simpod…"


echo -e "\033[33m[1/5] swift build -c release\033[0m"
swift build -c release --package-path "$NATIVE_DIR"

echo -e "\033[33m[2/5] copy $HELPER_BIN -> simpod_cli/lib/bin\033[0m"
mkdir -p "$CLI_DIR/lib/bin"
cp -f "$NATIVE_DIR/.build/release/$HELPER_BIN" "$CLI_DIR/lib/bin/$HELPER_BIN"

echo -e "\033[33m[3/5] flutter build web --wasm\033[0m"
( cd "$CLIENT_DIR" && flutter build web --wasm --release )

# Always reset the generated embed file back to the committed stub on exit, so
# the working tree is never left holding the multi-MB generated payload.
restore_stub() {
  ( cd "$CLI_DIR" && dart run tool/embed_assets.dart --stub >/dev/null 2>&1 || true )
}

echo -e "\033[33m[4/5] embed assets into the CLI\033[0m"
( cd "$CLI_DIR" && dart pub get )
trap restore_stub EXIT
( cd "$CLI_DIR" && dart run tool/embed_assets.dart )

echo -e "\033[33m[5/5] dart compile exe -> build/simpod\033[0m"
mkdir -p "$BUILD_DIR"
( cd "$CLI_DIR" && dart compile exe bin/simpod.dart -o "$BUILD_DIR/simpod" )

echo ""
echo -e "\033[32m✓ Build completed: $BUILD_DIR/simpod\033[0m"