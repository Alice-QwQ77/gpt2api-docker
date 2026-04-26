param(
    [string]$Repo = "432539/gpt2api",
    [string]$Branch = "main",
    [string]$LockPath = "upstream.lock.json",
    [string]$Commit = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$repoUrl = "https://github.com/$Repo"
$lockFile = Join-Path $repoRoot $LockPath

function Set-ActionOutput {
    param(
        [string]$Name,
        [string]$Value
    )

    if ($env:GITHUB_OUTPUT) {
        "$Name=$Value" | Add-Content $env:GITHUB_OUTPUT
    }
}

if ([string]::IsNullOrWhiteSpace($Commit)) {
    Write-Host "[sync] checking $repoUrl ($Branch)"
    $remote = git ls-remote --heads $repoUrl $Branch
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remote)) {
        throw "unable to resolve upstream branch head"
    }
    $Commit = ($remote -split "\s+")[0].Trim()
} else {
    $Commit = $Commit.Trim()
}

if ($Commit.Length -lt 7) {
    throw "resolved upstream commit is invalid: $Commit"
}

$archiveUrl = "https://codeload.github.com/$Repo/tar.gz/$Commit"
$timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")

$current = $null
if (Test-Path $lockFile) {
    $current = Get-Content $lockFile -Raw | ConvertFrom-Json
}

$changed = $true
if ($null -ne $current) {
    $changed = (
        $current.repo -ne $Repo -or
        $current.repo_url -ne $repoUrl -or
        $current.branch -ne $Branch -or
        $current.commit -ne $Commit -or
        $current.archive_url -ne $archiveUrl
    )
}

$desired = [ordered]@{
    repo        = $Repo
    repo_url    = $repoUrl
    branch      = $Branch
    commit      = $Commit
    archive_url = $archiveUrl
    synced_at   = if ($changed -or $null -eq $current) { $timestamp } else { $current.synced_at }
}

if ($changed) {
    Write-Host "[sync] upstream changed to $Commit"
    if (-not $DryRun) {
        $json = $desired | ConvertTo-Json -Depth 4
        Set-Content -Path $lockFile -Value ($json + "`n") -Encoding utf8
        Write-Host "[sync] wrote $LockPath"
    } else {
        Write-Host "[sync] dry-run enabled, lock file not updated"
    }
} else {
    Write-Host "[sync] upstream unchanged at $Commit"
}

Set-ActionOutput -Name "changed" -Value ($changed.ToString().ToLowerInvariant())
Set-ActionOutput -Name "commit" -Value $Commit
Set-ActionOutput -Name "commit_short" -Value $Commit.Substring(0, 7)
Set-ActionOutput -Name "archive_url" -Value $archiveUrl
Set-ActionOutput -Name "repo" -Value $Repo
Set-ActionOutput -Name "repo_url" -Value $repoUrl
Set-ActionOutput -Name "branch" -Value $Branch

