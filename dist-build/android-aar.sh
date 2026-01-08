#! /bin/sh

# Build a plain AAR containing only full libsodium.so variants for multiple ABIs.
# The resulting AAR is created in the current working directory.

SODIUM_VERSION="1.0.23.0.1"
DEST_PATH=$(mktemp -d)
AAR_PATH="$(pwd)/libsodium-${SODIUM_VERSION}.aar"

# Default Android NDK platform
if [ -z "$NDK_PLATFORM" ]; then
  export NDK_PLATFORM="android-21"
  echo "Compiling for default platform: [$NDK_PLATFORM]"
fi
SDK_VERSION=$(echo "$NDK_PLATFORM" | cut -f2 -d"-")

cd "$(dirname "$0")/../" || exit
trap 'rm -rf "$DEST_PATH"; exit' INT TERM EXIT

# Minimal AndroidManifest.xml
cat <<EOF >"$DEST_PATH/AndroidManifest.xml"
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.goterl.lazysodium"
    android:versionCode="1"
    android:versionName="1.0">
    <uses-sdk android:minSdkVersion="$SDK_VERSION" android:targetSdkVersion="$SDK_VERSION"/>
</manifest>
EOF

# META-INF folder with LICENSE
mkdir -p "$DEST_PATH/META-INF"
cp LICENSE "$DEST_PATH/META-INF"

# Create jni folders for ABIs
for abi in "armeabi-v7a" "arm64-v8a" "x86" "x86_64"; do
  mkdir -p "$DEST_PATH/jni/$abi"
done

# --- Run cross-compilation scripts to produce full libsodium.so ---
LIBSODIUM_FULL_BUILD="Y"
export LIBSODIUM_FULL_BUILD

echo "Building full libsodium binaries..."
dist-build/android-armv7-a.sh
dist-build/android-armv8-a.sh
dist-build/android-x86.sh
dist-build/android-x86_64.sh

# --- Function to copy compiled libsodium .so into jni/<abi> ---
copy_libs() {
  build_hint="$1"   # e.g. armv7-a
  abi="$2"          # e.g. armeabi-v7a

  SRC_DIR="libsodium-android-${build_hint}"
  src_so="${SRC_DIR}/lib/libsodium.so"
  dest_so="${DEST_PATH}/jni/${abi}/libsodium.so"

  if [ ! -f "$src_so" ]; then
    echo "Error: $src_so not found. Did dist-build/${build_hint}.sh run correctly?"
    exit 1
  fi

  echo "Copying: $src_so -> $dest_so"
  cp "$src_so" "$dest_so"
}

# Copy only full variants
copy_libs "armv7-a" "armeabi-v7a"
copy_libs "armv8-a+crypto" "arm64-v8a"
copy_libs "i686" "x86"
copy_libs "westmere" "x86_64"

# Package into AAR directly in current working directory
cd "$DEST_PATH" || exit
zip -9 -r "$AAR_PATH" AndroidManifest.xml META-INF jni
cd ..

# Cleanup temporary build folder
rm -rf "$DEST_PATH"

echo "
Congrats! Plain AAR built at:
$AAR_PATH

Contains libsodium.so for ABIs: armeabi-v7a, arm64-v8a, x86, x86_64 (full variants only)

Usage in Gradle:

dependencies {
    implementation files('$AAR_PATH')
}
"