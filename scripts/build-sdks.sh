#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE="v1.0.2"
SRC="$ROOT/third_party/opennhp"
ENDPOINTS="$SRC/endpoints"
OUT="$ROOT/build/sdks"
IOS_MIN="15.1"

export PATH="$(go env GOPATH)/bin:$PATH"

if [ ! -d "$SRC/.git" ]; then
  mkdir -p "$ROOT/third_party"
  git clone https://github.com/OpenNHP/opennhp.git "$SRC"
fi

git -C "$SRC" fetch --depth 1 origin tag "$RELEASE"
git -C "$SRC" checkout -f "$RELEASE"
git -C "$SRC" apply "$ROOT/scripts/opennhp-agent-sdk.patch"

(
  cd "$ENDPOINTS"
  go get golang.org/x/mobile@v0.0.0-20261011034528-197770444867
)

if ! command -v gomobile >/dev/null 2>&1; then
  go install golang.org/x/mobile/cmd/gomobile@v0.0.0-20261011034528-197770444867
  go install golang.org/x/mobile/cmd/gobind@v0.0.0-20261011034528-197770444867
fi

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
    ANDROID_NDK_HOME="$(find "$HOME/Library/Android/sdk/ndk" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
  fi
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -d "$ANDROID_NDK_HOME" ]; then
  echo "Set ANDROID_NDK_HOME to an installed Android NDK." >&2
  exit 1
fi

PREBUILT="$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -mindepth 1 -maxdepth 1 -type d -print -quit)"

build_android() {
  local goarch="$1"
  local goarm="$2"
  local cc="$3"
  local abi="$4"
  mkdir -p "$OUT/android/$abi"
  echo "Building Android $abi"
  (
    cd "$ENDPOINTS"
    if [ -n "$goarm" ]; then
      export GOARM="$goarm"
    fi
    GOOS=android GOARCH="$goarch" CGO_ENABLED=1 \
      CC="$PREBUILT/bin/$cc" \
      CXX="$PREBUILT/bin/${cc}++" \
      go build -trimpath -buildmode=c-shared -ldflags '-s -w' \
      -o "$OUT/android/$abi/libnhpagent.so" \
      ./agent/main/main.go ./agent/main/export.go
  )
  cp "$OUT/android/$abi/libnhpagent.so" "$ROOT/android/src/main/jniLibs/$abi/libnhpagent.so"
}

build_android arm64 "" aarch64-linux-android21-clang arm64-v8a
build_android arm 7 armv7a-linux-androideabi21-clang armeabi-v7a
build_android 386 "" i686-linux-android21-clang x86
build_android amd64 "" x86_64-linux-android21-clang x86_64

echo "Building iOS xcframework"
(
  cd "$ENDPOINTS"
  gomobile bind -target ios -iosversion="$IOS_MIN" -trimpath \
    -o "$OUT/nhpagent.xcframework" ./agent/iossdk
)

rm -rf "$ROOT/ios/Frameworks/nhpagent.xcframework"
cp -R "$OUT/nhpagent.xcframework" "$ROOT/ios/Frameworks/nhpagent.xcframework"
for plist in \
  "$ROOT/ios/Frameworks/nhpagent.xcframework/ios-arm64/Nhpagent.framework/Info.plist" \
  "$ROOT/ios/Frameworks/nhpagent.xcframework/ios-arm64_x86_64-simulator/Nhpagent.framework/Info.plist"
do
  plutil -replace MinimumOSVersion -string "$IOS_MIN" "$plist"
done

# Go records local replace paths in the iOS build info. Swap them for the
# public module paths so the framework does not contain the build machine's
# home directory. The replacement is the same length, so the blob stays valid.
python3 - "$SRC/endpoints" "$SRC/nhp" \
  "$ROOT/ios/Frameworks/nhpagent.xcframework/ios-arm64/Nhpagent.framework/Nhpagent" \
  "$ROOT/ios/Frameworks/nhpagent.xcframework/ios-arm64_x86_64-simulator/Nhpagent.framework/Nhpagent" <<'PY'
import pathlib, sys
endpoints, nhp, *binaries = sys.argv[1:]
pairs = [
    (str(pathlib.Path(endpoints).resolve()).encode(), b"github.com/OpenNHP/opennhp/endpoints"),
    (str(pathlib.Path(nhp).resolve()).encode(), b"github.com/OpenNHP/opennhp/nhp"),
]
for binary in binaries:
    path = pathlib.Path(binary)
    data = path.read_bytes()
    for original, label in pairs:
        if len(label) > len(original):
            raise SystemExit(f"{label!r} is longer than {original!r}")
        replacement = label + b"/" * (len(original) - len(label))
        count = data.count(original)
        if count == 0:
            raise SystemExit(f"{original.decode()} not found in {path}")
        data = data.replace(original, replacement)
    path.write_bytes(data)
PY

echo "SDK build finished."
