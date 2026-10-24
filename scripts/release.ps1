<#
.SYNOPSIS
  Builds a signed RondaGo release APK and sends it to testers through Firebase App Distribution.

.DESCRIPTION
  1. Checks that the work is committed and the release key is present.
  2. Bumps the version in pubspec.yaml (1.0.2+4 -> 1.0.3+5): the last digit of the name testers
     see, and the build number. Android only installs an update when the build number goes up.
     Pass -KeepVersionName to raise only the build number.
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
    # Raise only the build number and keep the version name (e.g. after changing it by hand).
    [switch]$KeepVersionName,
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

# ---- 1. bump the version ---------------------------------------------------
$pubspecPath = Join-Path $root 'pubspec.yaml'
$pubspec = [IO.File]::ReadAllText($pubspecPath)
$match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)')
if (-not $match.Success) { Fail 'could not read "version: x.y.z+n" from pubspec.yaml.' }

$versionName = $match.Groups[1].Value
if (-not $KeepVersionName) {
    $parts = $versionName.Split('.')
    $versionName = '{0}.{1}.{2}' -f $parts[0], $parts[1], ([int]$parts[2] + 1)
}
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
# The ~55 MB upload sometimes drops on a slow connection, so try a few times.
$attempts = 3
for ($attempt = 1; $attempt -le $attempts; $attempt++) {
    firebase appdistribution:distribute $apk --app $FirebaseAppId --groups $TesterGroups --release-notes-file $notesFile
    if ($LASTEXITCODE -eq 0) { break }
    if ($attempt -eq $attempts) { Fail "Firebase upload failed $attempts times (exit code $LASTEXITCODE)." }
    Write-Host "release: upload failed, retrying ($($attempt + 1)/$attempts)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}

# ---- 5. record the release --------------------------------------------------
$tag = "release-$versionName-$build"
Invoke-Checked 'git commit' { git add pubspec.yaml; git commit -q -m "chore(release): RondaGo $version" }
Invoke-Checked 'git tag' { git tag $tag }

Write-Host "release: RondaGo $version sent to '$TesterGroups' and tagged $tag." -ForegroundColor Green
Write-Host 'release: push when ready: git push; git push --tags'
