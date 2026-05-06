param(
    [string]$LockPath = "upstream.lock.json",
    [string]$BackendImage = "ghcr.io/alice-qwq77/gpt2api",
    [string]$AdminWebImage = "ghcr.io/alice-qwq77/gpt2api-admin-web",
    [string]$UserWebImage = "ghcr.io/alice-qwq77/gpt2api-user-web",
    [switch]$WriteGitHubOutput
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$lock = Get-Content $LockPath -Raw | ConvertFrom-Json
$repoArchiveUrl = $lock.archive_url
$tempRoot = [System.IO.Path]::GetTempPath()
$tmpDir = Join-Path $tempRoot ("gpt2api-meta-" + $lock.commit.Substring(0, 12) + "-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $tmpDir | Out-Null
$archivePath = Join-Path $tmpDir "src.tar.gz"
Invoke-WebRequest -Uri $repoArchiveUrl -OutFile $archivePath -UseBasicParsing
tar -xzf $archivePath -C $tmpDir
$srcRoot = Get-ChildItem $tmpDir -Directory | Where-Object { $_.Name -like "gpt2api-*" } | Select-Object -First 1
if (-not $srcRoot) {
    throw "unable to extract upstream archive"
}

$layout = "legacy"
$goModPath = Join-Path $srcRoot.FullName "go.mod"
$backendGoModPath = Join-Path (Join-Path $srcRoot.FullName "backend") "go.mod"
if (Test-Path $backendGoModPath) {
    $layout = "v2"
    $goModPath = $backendGoModPath
}

Write-Host "[meta] detected upstream layout: $layout"
Write-Host "[meta] reading go.mod from $goModPath"
$goMod = Get-Content $goModPath -Raw

$goVersion = $null
$toolchainMatch = [regex]::Match($goMod, '(?m)^\s*toolchain\s+go(?<version>[0-9][0-9A-Za-z.\-]*)\s*$')
if ($toolchainMatch.Success) {
    $goVersion = $toolchainMatch.Groups["version"].Value
}

if (-not $goVersion) {
    $goMatch = [regex]::Match($goMod, '(?m)^\s*go\s+(?<version>[0-9][0-9A-Za-z.\-]*)\s*$')
    if ($goMatch.Success) {
        $goVersion = $goMatch.Groups["version"].Value
    }
}

if (-not $goVersion) {
    throw "unable to determine Go version from upstream go.mod"
}

$result = [ordered]@{
    layout          = $layout
    backend_image   = $BackendImage.ToLowerInvariant()
    admin_web_image = $AdminWebImage.ToLowerInvariant()
    user_web_image  = $UserWebImage.ToLowerInvariant()
    repo_url        = $lock.repo_url
    upstream_commit = $lock.commit
    upstream_short  = $lock.commit.Substring(0, 7)
    archive_url     = $lock.archive_url
    go_version      = $goVersion
    build_date      = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    version_tag     = "upstream-" + $lock.commit.Substring(0, 7)
}

if ($WriteGitHubOutput -and $env:GITHUB_OUTPUT) {
    foreach ($entry in $result.GetEnumerator()) {
        "{0}={1}" -f $entry.Key, $entry.Value | Add-Content $env:GITHUB_OUTPUT
    }
}

$result | ConvertTo-Json -Depth 4
