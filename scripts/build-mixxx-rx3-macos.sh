#!/bin/sh
# Rebuild NauticMixxx from official Mixxx 2.5.6 sources.
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# Arquitectura: arm64 (Apple Silicon) por defecto en Apple Silicon, x64 en Intel.
# RX3_ARCH=x64|arm64 permite forzarla.
host_arch=$(uname -m)
case "${RX3_ARCH:-$host_arch}" in
  arm64)
    arch=arm64
    deps_name=mixxx-deps-2.5-arm64-osx-min1100-release-40c29ff
    deps_sha=b76685e77f681baf8fdc5037297b0f16d323a405d09ce276d8844304530278e1
    ;;
  x86_64|x64)
    arch=x64
    # Mismo commit de dependencias (40c29ff) que la build arm64; SHA-256 tomado
    # de tools/macos_buildenv.sh del tag oficial Mixxx 2.5.6.
    deps_name=mixxx-deps-2.5-x64-osx-min1100-release-40c29ff
    deps_sha=a9b7dd2cb9ab00db6d05ac1f05aab933ed0ab2697f71db1a1bad70305befcf1b
    ;;
  *) printf 'Arquitectura no soportada: %s\n' "${RX3_ARCH:-$host_arch}" >&2; exit 1 ;;
esac
triplet="$arch-osx-min1100-release"
if [ "$arch" = x64 ]; then osx_arch=x86_64; else osx_arch=arm64; fi
if [ -z "${RX3_BUILD_JOBS:-}" ]; then
  if [ "$arch" = x64 ]; then
    # Mixxx necesita ~2 GB por proceso de compilación: limita según la RAM.
    cpus=$(sysctl -n hw.ncpu 2>/dev/null || echo 2)
    mem_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 4294967296) / 1073741824 ))
    by_mem=$(( mem_gb / 2 )); [ "$by_mem" -ge 1 ] || by_mem=1
    RX3_BUILD_JOBS=$cpus; [ "$by_mem" -lt "$RX3_BUILD_JOBS" ] && RX3_BUILD_JOBS=$by_mem
  else
    RX3_BUILD_JOBS=6
  fi
fi
work=${RX3_BUILD_ROOT:-"$project/build/test-candidate/$(cat "$project/VERSION")-native-$arch"}
mkdir -p "$work"
# Ruta canónica (sin "..", enlaces ni /tmp→/private/tmp): fixup_bundle de CMake
# compara rutas como texto y rechaza librerías si el prefijo no coincide.
work=$(CDPATH= cd -- "$work" && pwd -P)
printf 'NauticMixxx %s · %s · %s procesos\n' "$(cat "$project/VERSION")" "$arch" "$RX3_BUILD_JOBS"
fetch() {
  if [ ! -f "$2" ]; then curl --fail --location --retry 3 "$1" -o "$2"; fi
  actual=$(shasum -a 256 "$2" | awk '{print $1}')
  if [ "$actual" != "$3" ]; then printf 'SHA-256 incorrecto: %s\n' "$2" >&2; exit 1; fi
}
fetch https://github.com/mixxxdj/mixxx/archive/refs/tags/2.5.6.tar.gz \
  "$work/mixxx-2.5.6.tar.gz" 9cfc9025d50d2511767ee52a07b8854f75c581f0585197d043bc219fcf9f9050
fetch "https://downloads.mixxx.org/dependencies/2.5-rel/macOS/$deps_name.zip" \
  "$work/dependencies-$arch.zip" "$deps_sha"
if [ ! -d "$work/buildenv/$deps_name" ]; then
  mkdir -p "$work/buildenv"
  unzip -q "$work/dependencies-$arch.zip" -d "$work/buildenv"
fi
patch_digest=$(cat "$project"/patches/00[0-9][0-9]-*.patch | shasum -a 256 | awk '{print $1}')
source_tree="$work/mixxx-2.5.6"
patch_marker="$source_tree/.rx3-patched"
patch_signature="$source_tree/src/test/trackcapabilitypolicy_test.cpp"
if [ ! -d "$source_tree" ]; then
  tar -xzf "$work/mixxx-2.5.6.tar.gz" -C "$work"
fi
if [ -f "$patch_marker" ] && [ "$(cat "$patch_marker")" != "$patch_digest" ]; then
  printf 'La carpeta fuente no coincide con el conjunto de parches NauticMixxx; usa otro RX3_BUILD_ROOT.\n' >&2
  exit 1
fi
if [ ! -f "$patch_signature" ]; then
  for patch in "$project"/patches/00[0-9][0-9]-*.patch; do
    # The extracted tarball is nested inside the Mixxx working tree but is not
    # a repository. --no-index plus the ceiling keeps paths relative to this
    # source tree instead of accidentally applying them to the parent repo.
    (cd "$source_tree" && GIT_CEILING_DIRECTORIES="$work" git apply --no-index "$patch")
  done
  printf '%s\n' "$patch_digest" > "$patch_marker"
fi
if [ ! -f "$patch_marker" ] || [ ! -f "$patch_signature" ] || [ "$(cat "$patch_marker")" != "$patch_digest" ]; then
  printf 'La carpeta fuente no coincide con el conjunto de parches NauticMixxx; usa otro RX3_BUILD_ROOT.\n' >&2
  exit 1
fi
deps="$work/buildenv/$deps_name"
python3 "$project/scripts/sparkle-sdk.py" --destination "$work/sparkle"
python3 "$project/scripts/prepare-app-branding.py" "$source_tree" "$project"
"$project/scripts/build-app-icon-macos.sh" "$source_tree/res/osx/application.icns"
cmake -S "$work/mixxx-2.5.6" -B "$work/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DNAUTICMIX_VERSION="$(cat "$project/VERSION")" \
  -DNAUTIC_SPARKLE_FRAMEWORK="$work/sparkle/Sparkle.framework" \
  -DCMAKE_TOOLCHAIN_FILE="$deps/scripts/buildsystems/vcpkg.cmake" \
  -DMIXXX_VCPKG_ROOT="$deps" -DVCPKG_TARGET_TRIPLET="$triplet" -DCMAKE_OSX_ARCHITECTURES="$osx_arch" \
  -DVCPKG_HOST_TRIPLET=x64-osx-min1100-release \
  -DQT6=ON -DQML=OFF -DAU_EFFECTS=OFF -DMACOS_BUNDLE=ON \
  '-DMACOS_BUNDLE_NAME=NauticMixxx' \
  '-DMACOS_BUNDLE_IDENTIFIER=org.mixxx.mixxx' \
  -DBUILD_TESTING=ON -DBUILD_BENCH=OFF
cmake --build "$work/build" --target mixxx mixxx-test --parallel "$RX3_BUILD_JOBS"
if [ "${RX3_SKIP_TESTS:-0}" = 1 ]; then
  printf 'Pruebas RX3 omitidas (RX3_SKIP_TESTS=1).\n'
else
# Las pruebas de interfaz dependen de temporizadores; en máquinas lentas o
# compartidas pueden fallar por tiempo. Se reintentan hasta RX3_TEST_ATTEMPTS veces.
attempt=1
until (cd "$work/build" && QT_QPA_PLATFORM=offscreen NAUTIC_SKIN_DIR="$project/skins/XDJ_RX3_Mixxx" NAUTIC_RX3_STYLESHEET="$project/skins/XDJ_RX3_Mixxx/style.qss" ./mixxx-test \
  --gtest_filter='IntegratedUpdaterTest.*:UpdatePayloadTest.*:StartupUpdateCheckerTest.*:StartupUpdateDialogTest.*:StreamCompletionTest.*:LibraryTableViewStateTest.*:Rx3*:RekordboxDecoderTimingTest.*:RekordboxUsbSessionAudioTest.*:RekordboxWaveformImporterTest.*' \
  --gtest_output=xml:rx3-tests.xml); do
  if [ "$attempt" -ge "${RX3_TEST_ATTEMPTS:-3}" ]; then
    printf 'Las pruebas RX3 fallaron %s veces.\n' "$attempt" >&2
    # RX3_TESTS_NONFATAL=1: seguir y dejar constancia (solo para CI sin pantalla).
    if [ "${RX3_TESTS_NONFATAL:-0}" = 1 ]; then echo "RX3_TESTS_FAILED" > "$work/build/rx3-tests-failed"; break; fi
    exit 1
  fi
  attempt=$((attempt + 1)); printf 'Reintentando pruebas RX3 (intento %s)...\n' "$attempt"
done
fi
cmake --install "$work/build" --prefix "$work/stage"
app="$work/stage/NauticMixxx.app"
ditto "$project/skins/XDJ_RX3_Mixxx" "$app/Contents/Resources/skins/XDJ_RX3_Mixxx"
ditto "$project/controllers/Hercules_DJControl_Inpulse_500_RX3" "$app/Contents/Resources/controllers"
ditto "$project/controllers/Pioneer_DDJ_FLX4_RX3" "$app/Contents/Resources/controllers"
ditto "$project/controllers/Pioneer_DDJ_FLX6_RX3" "$app/Contents/Resources/controllers"
ditto "$project/controllers/Pioneer_Roland_RX3" "$app/Contents/Resources/controllers"
mkdir -p "$app/Contents/Resources/effects/chains" "$app/Contents/Resources/licenses"
ditto "$project/effects/chains" "$app/Contents/Resources/effects/chains"
cp "$project/skins/XDJ_RX3_Mixxx/LICENSE" "$app/Contents/Resources/licenses/NauticMixxx-GPL-3.0.txt"
cp "$work/mixxx-2.5.6/LICENSE" "$app/Contents/Resources/licenses/Mixxx-LICENSE.txt"
cp "$project/THIRD_PARTY_NOTICES.md" "$app/Contents/Resources/licenses/THIRD_PARTY_NOTICES.md"
"$project/scripts/build-app-icon-macos.sh" "$app/Contents/Resources/application.icns"
# Mixxx also installs a secondary copy under Resources/osx. Keep both copies
# identical, while CFBundleIconFile resolves the root Resources copy.
mkdir -p "$app/Contents/Resources/osx"
cp "$app/Contents/Resources/application.icns" "$app/Contents/Resources/osx/application.icns"
plutil -replace CFBundleDisplayName -string NauticMixxx "$app/Contents/Info.plist"
plutil -replace CFBundleName -string NauticMixxx "$app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$(cat "$project/VERSION")" "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(cat "$project/VERSION")" "$app/Contents/Info.plist"
plutil -replace NSHumanReadableCopyright -string 'NauticMixxx contributors and Mixxx Development Team' "$app/Contents/Info.plist"
signing_identity=${NAUTIC_SIGNING_IDENTITY:--}
# Las releases publicadas solo traen DMG arm64: en Intel el actualizador apunta
# a un feed propio (appcast-macos-x64.xml) para no instalar nunca un binario arm64.
if [ "$arch" = x64 ]; then
  export NAUTIC_UPDATE_FEED_URL=${NAUTIC_UPDATE_FEED_URL:-https://github.com/nauticsoftware/NauticMixxx/releases/latest/download/appcast-macos-x64.xml}
fi
NAUTIC_SIGNING_IDENTITY="$signing_identity" python3 "$project/scripts/configure-updater-macos.py" --app "$app" --sdk "$work/sparkle"
codesign --verify --deep --strict "$app"
printf 'Aplicación reconstruida: %s\n' "$app"
