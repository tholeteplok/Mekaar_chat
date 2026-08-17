#!/usr/bin/env bash
# ==============================================================================
# Script Otomasi Rilis & Pembaruan Versi MEKAAR untuk Linux / macOS / Git Bash.
# ==============================================================================

set -e

echo -e "\033[0;36m======================================================\033[0m"
echo -e "\033[0;32m   MEKAAR Release & GitHub CI/CD Automation Helper    \033[0m"
echo -e "\033[0;36m======================================================\033[0m"

if [ ! -f "pubspec.yaml" ]; then
  echo -e "\033[0;31m[ERROR] pubspec.yaml tidak ditemukan! Jalankan skrip dari root repository.\033[0m"
  exit 1
fi

CURRENT_FULL=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
CURRENT_SEMVER=$(echo "$CURRENT_FULL" | cut -d'+' -f1)
CURRENT_BUILD=$(echo "$CURRENT_FULL" | cut -d'+' -f2)

if [ -z "$CURRENT_BUILD" ]; then
  CURRENT_BUILD=1
fi

echo -e "\033[0;33mVersi Saat Ini: $CURRENT_FULL\033[0m"

NEW_VERSION="$1"

if [ -z "$NEW_VERSION" ]; then
  SUGGESTED_BUILD=$((CURRENT_BUILD + 1))
  echo -e "\n\033[0;36mMasukkan versi rilis baru (format: X.Y.Z, contoh: 1.0.1 atau 1.1.0):\033[0m"
  read -p "Versi Baru (tekan Enter untuk $CURRENT_SEMVER+$SUGGESTED_BUILD): " INPUT_VERSION
  if [ -z "$INPUT_VERSION" ]; then
    NEW_VERSION="$CURRENT_SEMVER"
    NEW_BUILD="$SUGGESTED_BUILD"
  else
    NEW_VERSION=$(echo "$INPUT_VERSION" | sed -e 's/^[vV]//')
    NEW_BUILD="$SUGGESTED_BUILD"
  fi
else
  NEW_VERSION=$(echo "$NEW_VERSION" | sed -e 's/^[vV]//')
  NEW_BUILD=$((CURRENT_BUILD + 1))
fi

NEW_FULL="$NEW_VERSION+$NEW_BUILD"
TAG_NAME="v$NEW_VERSION"

echo -e "\n\033[0;36mTarget Rilis:\033[0m"
echo -e "  - Versi pubspec.yaml : \033[0;32m$NEW_FULL\033[0m"
echo -e "  - Git Tag Rilis      : \033[0;32m$TAG_NAME\033[0m"

echo -e "\n\033[0;33m[1/5] Menjalankan Quality Gate (flutter analyze & flutter test)...\033[0m"
flutter analyze
flutter test
echo -e "\033[0;32m[BERHASIL] Quality Gate lolos tanpa issue!\033[0m"

echo -e "\n\033[0;33m[2/5] Memperbarui pubspec.yaml ke versi $NEW_FULL...\033[0m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/^version:.*/version: $NEW_FULL/" pubspec.yaml
else
  sed -i "s/^version:.*/version: $NEW_FULL/" pubspec.yaml
fi
echo -e "\033[0;32m[BERHASIL] pubspec.yaml diperbarui.\033[0m"

echo -e "\n\033[0;33m[3/5] Membuat Git Commit rilis...\033[0m"
git add pubspec.yaml
git commit -m "chore(release): bump version to $TAG_NAME ($NEW_FULL)" || echo "Tidak ada perubahan untuk di-commit."

echo -e "\n\033[0;33m[4/5] Membuat Git Tag $TAG_NAME...\033[0m"
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  git tag -d "$TAG_NAME" >/dev/null 2>&1 || true
fi
git tag -a "$TAG_NAME" -m "Release $TAG_NAME (Build $NEW_BUILD)"
echo -e "\033[0;32m[BERHASIL] Tag $TAG_NAME berhasil dibuat.\033[0m"

echo -e "\n\033[0;36m[5/5] Siap Push ke GitHub Remote...\033[0m"
read -p "Apakah Anda ingin langsung push ke origin main dengan tags sekarang? (Y/n) " PUSH_CONFIRM
if [ -z "$PUSH_CONFIRM" ] || [ "$PUSH_CONFIRM" = "Y" ] || [ "$PUSH_CONFIRM" = "y" ]; then
  echo -e "\033[0;33mMelakukan git push origin main --tags...\033[0m"
  git push origin main --tags
  echo -e "\n\033[0;32m======================================================\033[0m"
  echo -e "\033[0;32m   RILIS $TAG_NAME BERHASIL DI-PUSH KE GITHUB! 🚀      \033[0m"
  echo -e "\033[0;32m======================================================\033[0m"
  echo -e "\033[0;36mGitHub Actions akan otomatis mem-build APK Release di:\033[0m"
  echo -e "\033[0;33mhttps://github.com/tholeteplok/Mekaar_chat/releases\033[0m"
else
  echo -e "\n\033[0;33mPush ditunda. Jalankan manual dengan: git push origin main --tags\033[0m"
fi
