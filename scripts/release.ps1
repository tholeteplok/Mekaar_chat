<#
.SYNOPSIS
    Script Otomasi Rilis & Pembaruan Versi MEKAAR untuk Windows PowerShell.

.DESCRIPTION
    Skrip ini melakukan:
    1. Validasi kebersihan repository Git.
    2. Input / bump versi SemVer di pubspec.yaml.
    3. Eksekusi pengujian otomatis (flutter analyze & flutter test).
    4. Pembuatan git commit versi baru.
    5. Pembuatan git tag rilis (misal: v1.1.0).
    6. Opsi push otomatis ke remote main dengan tags untuk memicu GitHub Actions CI/CD.

.EXAMPLE
    .\scripts\release.ps1 -NewVersion "1.1.0"
#>

param (
    [string]$NewVersion = ""
)

$ErrorActionPreference = "Stop"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   MEKAAR Release & GitHub CI/CD Automation Helper    " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Pastikan di folder root proyek
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "[ERROR] pubspec.yaml tidak ditemukan! Jalankan skrip dari root repository." -ForegroundColor Red
    exit 1
}

# 2. Baca versi saat ini dari pubspec.yaml
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+?([0-9]*)') {
    $currentSemver = $matches[1]
    $currentBuild = if ($matches[2]) { [int]$matches[2] } else { 1 }
    $currentFull = "$currentSemver+$currentBuild"
} else {
    Write-Host "[ERROR] Tidak dapat membaca format version di pubspec.yaml." -ForegroundColor Red
    exit 1
}

Write-Host "Versi Saat Ini: $currentFull" -ForegroundColor Yellow

# 3. Input versi baru jika tidak diisi parameter
if ([string]::IsNullOrWhiteSpace($NewVersion)) {
    $suggestedBuild = $currentBuild + 1
    $suggestedSemver = $currentSemver
    Write-Host "`nMasukkan versi rilis baru (format: X.Y.Z, contoh: 1.0.1 atau 1.1.0):" -ForegroundColor Cyan
    $inputVersion = Read-Host "Versi Baru (tekan Enter untuk patch $suggestedSemver+$suggestedBuild)"
    
    if ([string]::IsNullOrWhiteSpace($inputVersion)) {
        $NewVersion = $suggestedSemver
        $newBuild = $suggestedBuild
    } else {
        $cleanInput = $inputVersion.Trim().TrimStart('v').TrimStart('V')
        if ($cleanInput -match '^([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?$') {
            $NewVersion = $matches[1]
            $newBuild = if ($matches[3]) { [int]$matches[3] } else { $suggestedBuild }
        } else {
            Write-Host "[ERROR] Format versi tidak valid! Gunakan format Semantic Versioning (contoh: 1.1.0)." -ForegroundColor Red
            exit 1
        }
    }
} else {
    $cleanParam = $NewVersion.Trim().TrimStart('v').TrimStart('V')
    if ($cleanParam -match '^([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?$') {
        $NewVersion = $matches[1]
        $newBuild = if ($matches[3]) { [int]$matches[3] } else { $currentBuild + 1 }
    } else {
        Write-Host "[ERROR] Format versi parameter tidak valid!" -ForegroundColor Red
        exit 1
    }
}

$newFullVersion = "$NewVersion+$newBuild"
$tagName = "v$NewVersion"

Write-Host "`nTarget Rilis:" -ForegroundColor Cyan
Write-Host "  - Versi pubspec.yaml : $newFullVersion" -ForegroundColor Green
Write-Host "  - Git Tag Rilis      : $tagName" -ForegroundColor Green

# 4. Jalankan Quality Gate (flutter analyze & test) sebelum commit
Write-Host "`n[1/5] Menjalankan Quality Gate (flutter analyze & flutter test)..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "[GAGAL] flutter analyze mendeteksi issue. Perbaiki sebelum merilis!" -ForegroundColor Red
    exit 1
}

flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "[GAGAL] Pengujian unit test gagal. Perbaiki sebelum merilis!" -ForegroundColor Red
    exit 1
}
Write-Host "[BERHASIL] Quality Gate lolos tanpa issue!" -ForegroundColor Green

# 5. Update pubspec.yaml
Write-Host "`n[2/5] Memperbarui pubspec.yaml ke versi $newFullVersion..." -ForegroundColor Yellow
$updatedPubspec = $pubspecContent -replace 'version:\s*[^\r\n]+', "version: $newFullVersion"
Set-Content -Path "pubspec.yaml" -Value $updatedPubspec -NoNewline
Write-Host "[BERHASIL] pubspec.yaml diperbarui." -ForegroundColor Green

# 6. Git Commit
Write-Host "`n[3/5] Membuat Git Commit rilis..." -ForegroundColor Yellow
git add pubspec.yaml
git commit -m "chore(release): bump version to $tagName ($newFullVersion)"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Tidak ada perubahan untuk di-commit atau commit gagal." -ForegroundColor Yellow
}

# 7. Git Tag
Write-Host "`n[4/5] Membuat Git Tag $tagName..." -ForegroundColor Yellow
$existingTag = git tag -l $tagName
if ($existingTag) {
    git tag -d $tagName | Out-Null
}
git tag -a $tagName -m "Release $tagName (Build $newBuild)"
Write-Host "[BERHASIL] Tag $tagName berhasil dibuat." -ForegroundColor Green

# 8. Push ke Remote
Write-Host "`n[5/5] Siap Push ke GitHub Remote..." -ForegroundColor Cyan
$pushConfirm = Read-Host "Apakah Anda ingin langsung push ke origin main dengan tags sekarang? (Y/n)"
if ($pushConfirm -eq "" -or $pushConfirm -eq "Y" -or $pushConfirm -eq "y") {
    Write-Host "Melakukan git push origin main --tags..." -ForegroundColor Yellow
    git push origin main --tags
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n======================================================" -ForegroundColor Green
        Write-Host "   RILIS $tagName BERHASIL DI-PUSH KE GITHUB! 🚀      " -ForegroundColor Green
        Write-Host "======================================================" -ForegroundColor Green
        Write-Host "GitHub Actions akan otomatis mem-build APK Release dan mempublikasikannya di:" -ForegroundColor Cyan
        Write-Host "https://github.com/tholeteplok/Mekaar_chat/releases" -ForegroundColor Yellow
    } else {
        Write-Host "[ERROR] Gagal melakukan push ke remote GitHub." -ForegroundColor Red
    }
} else {
    Write-Host "`nPush ditunda. Anda dapat melakukan push manual dengan perintah:" -ForegroundColor Yellow
    Write-Host "git push origin main --tags" -ForegroundColor Cyan
}
