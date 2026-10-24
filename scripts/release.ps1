<#
.SYNOPSIS
  Builds a signed RondaGo release APK and sends it to testers through Firebase App Distribution.

.DESCRIPTION
  1. Checks that the work is committed and the release key is present.
  2. Bumps the build number in pubspec.yaml (1.0.0+5 -> 1.0.0+6). Android only installs an
     update when this number goes up.
  3. Builds the APK against the hosted API.
  4. Uploads it to Firebase App Distribution for the tester group. Testers get the update
     in the Firebase App Tester app or by email.
  5. Commits the new build number and tags the release (release-<version>-<build>).

.EXAMPLE
  .\scripts\release.ps1
  .\scripts\release.ps1 -Notes "Fixed the SOS button"
#>
param(
    # What changed, shown to testers. Defaults to the commit subjects since the last release.
    [string]$Notes = '',
    # Release even if there are uncommitted changes (they will not be in the release commit).
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'

# ---- settings -------------------------------------------------------------
# Firebase console > Project settings > Your apps > RondaGo (Android) > App ID.
$FirebaseAppId = '1:519313660154:android:f1dc533472747e19719143'
$TesterGroups  = 'testers'
$ApiBaseUrl    = 'https://gobike.up.railway.app/api'
# ---------------------------------------------------------------------------

function Fail([string]$message) {
    Write-Host "release: $message" -ForegroundColor Red
    exit 1
}

function Invoke-Checked([string]$what, [scriptblock]$command) {
    & $command
    if ($LASTEXITCODE -ne 0) { Fail "$what failed (exit code $LASTEXITCODE)." }
}

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not $FirebaseAppId) { Fail 'set $FirebaseAppId at the top of scripts/release.ps1 first.' }
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) { Fail 'Firebase CLI not found. Run: npm i -g firebase-tools; firebase login' }

# A debug-signed APK cannot update an installed release, so never ship one.
if (-not (Test-Path 'android/key.properties')) {
    Fail 'android/key.properties is missing, so the APK would be signed with the debug key. Restore it from the keystore backup.'
}

if (-not $AllowDirty) {
    $dirty = git status --porcelain
    if ($dirty) { Fail 'there are uncommitted changes. Commit them first, or pass -AllowDirty.' }
}

# ---- 1. bump the build number ---------------------------------------------
$pubspecPath = Join-Path $root 'pubspec.yaml'
$pubspec = [IO.File]::ReadAllText($pubspecPath)
$match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)')
if (-not $match.Success) { Fail 'could not read "version: x.y.z+n" from pubspec.yaml.' }

$versionName = $match.Groups[1].Value
$build = [int]$match.Groups[2].Value + 1
$version = "$versionName+$build"
$pubspec = $pubspec.Remove($match.Index, $match.Length).Insert($match.Index, "version: $version")
[IO.File]::WriteAllText($pubspecPath, $pubspec, (New-Object Text.UTF8Encoding $false))
Write-Host "release: building RondaGo $version" -ForegroundColor Cyan

# ---- 2. build ---------------------------------------------------------------
Invoke-Checked 'flutter build' { flutter build apk --release "--dart-define=API_BASE_URL=$ApiBaseUrl" }
$apk = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path $apk)) { Fail "APK not found at $apk." }

# ---- 3. release notes -------------------------------------------------------
if (-not $Notes) {
    # The first release has no tag yet; ask git without letting its "no tags" message stop the script.
    $lastTag = (git tag --list 'release-*' --sort=-creatordate | Select-Object -First 1)
    $range = if ($lastTag) { "$lastTag..HEAD" } else { 'HEAD~10..HEAD' }
    $Notes = (git log $range --no-merges --format='- %s') -join "`n"
    if (-not $Notes) { $Notes = "RondaGo $version" }
}
$notesFile = Join-Path $env:TEMP "rondago-release-notes-$build.txt"
[IO.File]::WriteAllText($notesFile, "RondaGo $version`n`n$Notes", (New-Object Text.UTF8Encoding $false))

# ---- 4. upload --------------------------------------------------------------
Invoke-Checked 'Firebase upload' {
    firebase appdistribution:distribute $apk --app $FirebaseAppId --groups $TesterGroups --release-notes-file $notesFile
}

# ---- 5. record the release --------------------------------------------------
$tag = "release-$versionName-$build"
Invoke-Checked 'git commit' { git add pubspec.yaml; git commit -q -m "chore(release): RondaGo $version" }
Invoke-Checked 'git tag' { git tag $tag }

Write-Host "release: RondaGo $version sent to '$TesterGroups' and tagged $tag." -ForegroundColor Green
Write-Host 'release: push when ready: git push; git push --tags'
