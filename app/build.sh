#!/usr/bin/env bash
# ============================================================
#  构建星露谷开服器 APK（无需 Android Studio）
#
#  依赖（Debian/Ubuntu，含 arm64 设备）:
#    apt install openjdk-17-jdk-headless aapt dalvik-exchange apksigner zip
#  还需 android.jar（API >= 30），例如:
#    curl -L -o /tmp/android.jar \
#      https://raw.githubusercontent.com/Sable/android-platforms/master/android-30/android.jar
#
#  用法:  SDK_JAR=/tmp/android.jar bash build.sh
# ============================================================
set -euo pipefail

cd "$(dirname "$0")"
SDK_JAR="${SDK_JAR:-/tmp/android.jar}"
OUT="${OUT:-build}"
DEX="$(command -v dx || command -v dalvik-exchange || command -v d8)"

rm -rf "$OUT/classes" "$OUT/dex"
mkdir -p "$OUT/classes" "$OUT/dex"

echo "[1/5] javac"
javac -source 8 -target 8 -Xlint:-options \
  -bootclasspath "$SDK_JAR" \
  -d "$OUT/classes" \
  src/com/deekoz2/valleyserver/*.java

echo "[2/5] dex ($DEX)"
jar cf "$OUT/dex/classes.jar" -C "$OUT/classes" .
"$DEX" --dex --min-sdk-version=24 \
  --output="$OUT/dex/classes.dex" \
  "$OUT/dex/classes.jar"

echo "[3/5] aapt 打包"
aapt package -f -M AndroidManifest.xml -I "$SDK_JAR" \
  --min-sdk-version 24 --target-sdk-version 30 \
  --version-code 2 --version-name 1.0.1 \
  -F "$OUT/valley-launcher-unsigned.apk"
(cd "$OUT/dex" && zip -q -u ../valley-launcher-unsigned.apk classes.dex)

echo "[4/5] 生成调试签名"
KS="$OUT/debug.keystore"
if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -alias valley \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass valley123 -keypass valley123 \
    -dname "CN=deekoz2, O=ValleyServer-arm64" >/dev/null 2>&1
fi

echo "[5/5] apksigner 签名"
apksigner sign --ks "$KS" --ks-pass pass:valley123 \
  --out "$OUT/valley-launcher.apk" "$OUT/valley-launcher-unsigned.apk"
apksigner verify --print-certs "$OUT/valley-launcher.apk" | head -n 3

echo "完成: $OUT/valley-launcher.apk"
