param(
    [ValidateSet("patch", "minor", "major")]
    [string]$Bump = "patch",
    [string]$RemoteImage = "<dockerhub-user>/poc-ui",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$branch = git rev-parse --abbrev-ref HEAD
if ($LASTEXITCODE -ne 0) {
    throw "git rev-parse failed (exit $LASTEXITCODE)."
}
if ($branch -ne "main") {
    throw "Current branch is '$branch'. Releases must be cut from main."
}

$dirty = git status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw "git status failed (exit $LASTEXITCODE)."
}
if ($dirty) {
    throw "Working tree has uncommitted changes."
}

git fetch --tags
if ($LASTEXITCODE -ne 0) {
    throw "git fetch --tags failed (exit $LASTEXITCODE)."
}
$localMain = git rev-parse main
if ($LASTEXITCODE -ne 0) {
    throw "git rev-parse main failed (exit $LASTEXITCODE)."
}
$originMain = git rev-parse origin/main
if ($LASTEXITCODE -ne 0) {
    throw "origin/main is not available (exit $LASTEXITCODE)."
}
if ($localMain -ne $originMain) {
    throw "Local main differs from origin/main. Push or pull so the tag points at a commit on GitHub."
}

$listed = git tag --list "v*" --sort=-v:refname
if ($LASTEXITCODE -ne 0) {
    throw "git tag --list failed (exit $LASTEXITCODE)."
}
$latest = "v0.0.0"
if ($listed) {
    $latest = @($listed)[0].Trim()
}
if ($latest -notmatch "^v(\d+)\.(\d+)\.(\d+)$") {
    throw "Latest tag '$latest' is not vMAJOR.MINOR.PATCH."
}
$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
switch ($Bump) {
    "patch" { $patch += 1 }
    "minor" { $minor += 1; $patch = 0 }
    "major" { $major += 1; $minor = 0; $patch = 0 }
}
$newTag = "v$major.$minor.$patch"
$version = "$major.$minor.$patch"

Write-Host "Latest: $latest -> New: $newTag"
$answer = Read-Host "Continue? (y/N)"
if ($answer -ne "y") {
    exit 0
}

$localTag = git tag --list $newTag
if ($LASTEXITCODE -ne 0) {
    throw "git tag --list $newTag failed (exit $LASTEXITCODE)."
}
if ($localTag) {
    throw "Tag $newTag already exists locally."
}
$remoteTags = git ls-remote --tags origin
if ($LASTEXITCODE -ne 0) {
    throw "git ls-remote --tags origin failed (exit $LASTEXITCODE)."
}
if ($remoteTags) {
    foreach ($line in @($remoteTags)) {
        $ref = ($line -split "\s+", 2)[-1]
        if ($ref -eq "refs/tags/$newTag" -or $ref -eq "refs/tags/${newTag}^{}") {
            throw "Tag $newTag already exists on origin."
        }
    }
}

git tag -a $newTag -m "Release $newTag"
if ($LASTEXITCODE -ne 0) {
    throw "git tag failed (exit $LASTEXITCODE)."
}

try {
    & .\publish-docker-hub.ps1 -Tag $version -RemoteImage $RemoteImage -SkipPush:$DryRun
    if ($LASTEXITCODE -ne 0) {
        throw "publish-docker-hub.ps1 failed (exit $LASTEXITCODE)."
    }
} catch {
    # A failed build must not leave a tag behind.
    git tag -d $newTag
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to delete local tag $newTag."
    }
    throw
}

if ($DryRun) {
    git tag -d $newTag
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete local tag $newTag (exit $LASTEXITCODE)."
    }
    Write-Host "Dry run complete, nothing pushed"
} else {
    git push origin $newTag
    if ($LASTEXITCODE -ne 0) {
        throw "git push origin $newTag failed (exit $LASTEXITCODE)."
    }
    Write-Host "Released $newTag"
}
