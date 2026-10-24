<#
.SYNOPSIS
  Builds a signed RondaGo release APK and sends it to testers through Firebase App Distribution.

.DESCRIPTION
  1. Checks that the work is committed and the release key is present.
  2. Bumps the version in pubspec.yaml (1.0.2 -> 1.0.3).
     Pass -KeepVersionName to release the version already written there (e.g. 1.1.0 set by hand).
  3. Builds the APK against the hosted API.
  4. Uploads it to Firebase App Distribution for the tester group. Testers get the update
     in the Firebase App Tester app or by email.
  5. Commits the new version and tags the release (release-<version>).

  People only ever see the version (e.g. 1.0.3). Android also needs a whole number that goes
  up with every update; it is worked out from the version (1.0.3 -> 10003, 1.1.0 -> 10100) and
  passed to the build, so pubspec.yaml holds just the version.

.EXAMPLE
  .\scripts\release.ps1
  .\scripts\release.ps1 -Notes "Fixed the SOS button"
#>
param(
    # What changed, shown to testers. Defaults to the commit subjects since the last release.
    [string]$Notes = '',
    # Release the version in pubspec.yaml as it is (after changing it by hand, e.g. to 1.1.0).
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
# An old "+n" build number after the version is accepted and dropped.
$match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)(\+\d+)?')
if (-not $match.Success) { Fail 'could not read "version: x.y.z" from pubspec.yaml.' }

$versionName = $match.Groups[1].Value
if (-not $KeepVersionName) {
    $parts = $versionName.Split('.')
    $versionName = '{0}.{1}.{2}' -f $parts[0], $parts[1], ([int]$parts[2] + 1)
}

# Android's update number, from the version: 1.0.3 -> 10003. It only grows as the version does.
$parts = $versionName.Split('.') | ForEach-Object { [int]$_ }
if ($parts[1] -gt 99 -or $parts[2] -gt 99) { Fail "minor and patch must stay below 100 ($versionName)." }
$build = $parts[0] * 10000 + $parts[1] * 100 + $parts[2]

$pubspec = $pubspec.Remove($match.Index, $match.Length).Insert($match.Index, "version: $versionName")
[IO.File]::WriteAllText($pubspecPath, $pubspec, (New-Object Text.UTF8Encoding $false))
Write-Host "release: building RondaGo $versionName" -ForegroundColor Cyan

# ---- 2. build ---------------------------------------------------------------
Invoke-Checked 'flutter build' { flutter build apk --release "--build-name=$versionName" "--build-number=$build" "--dart-define=API_BASE_URL=$ApiBaseUrl" }
$apk = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path $apk)) { Fail "APK not found at $apk." }

# ---- 3. release notes -------------------------------------------------------
if (-not $Notes) {
    # The first release has no tag yet; ask git without letting its "no tags" message stop the script.
    $lastTag = (git tag --list 'release-*' --sort=-creatordate | Select-Object -First 1)
    $range = if ($lastTag) { "$lastTag..HEAD" } else { 'HEAD~10..HEAD' }
    $Notes = (git log $range --no-merges --format='- %s') -join "`n"
    if (-not $Notes) { $Notes = "RondaGo $versionName" }
}
$notesFile = Join-Path $env:TEMP "rondago-release-notes-$build.txt"
[IO.File]::WriteAllText($notesFile, "RondaGo $versionName`n`n$Notes", (New-Object Text.UTF8Encoding $false))

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
# Same version released again (-KeepVersionName): keep the tags unique.
$tag = "release-$versionName"
if (git tag --list $tag) { $tag = "release-$versionName-$build" }
Invoke-Checked 'git commit' { git add pubspec.yaml; git commit -q -m "chore(release): RondaGo $versionName" }
Invoke-Checked 'git tag' { git tag $tag }

Write-Host "release: RondaGo $versionName sent to '$TesterGroups' and tagged $tag." -ForegroundColor Green
Write-Host 'release: push when ready: git push; git push --tags'
