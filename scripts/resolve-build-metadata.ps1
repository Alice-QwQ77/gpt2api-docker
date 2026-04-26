param(
    [string]$LockPath = "upstream.lock.json",
    [string]$Image = "ghcr.io/alice-qwq77/gpt2api",
    [switch]$WriteGitHubOutput
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$lock = Get-Content $LockPath -Raw | ConvertFrom-Json
$rawGoModUrl = "https://raw.githubusercontent.com/{0}/{1}/go.mod" -f $lock.repo, $lock.commit

Write-Host "[meta] reading upstream go.mod from $rawGoModUrl"
$goMod = Invoke-WebRequest -Uri $rawGoModUrl -UseBasicParsing | Select-Object -ExpandProperty Content

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
    image           = $Image.ToLowerInvariant()
    repo_url        = $lock.repo_url
    upstream_commit = $lock.commit
    upstream_short  = $lock.commit.Substring(0, 7)
    archive_url     = $lock.archive_url
    go_version      = $goVersion
    build_date      = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

if ($WriteGitHubOutput -and $env:GITHUB_OUTPUT) {
    foreach ($entry in $result.GetEnumerator()) {
        "{0}={1}" -f $entry.Key, $entry.Value | Add-Content $env:GITHUB_OUTPUT
    }
}

$result | ConvertTo-Json -Depth 4

