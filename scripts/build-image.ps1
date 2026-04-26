param(
    [string]$ImageName = "gpt2api-local:dev",
    [string]$LockPath = "upstream.lock.json"
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$lock = Get-Content $LockPath -Raw | ConvertFrom-Json
$buildDate = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$upstreamShort = $lock.commit.Substring(0, 7)

Write-Host "[build] image         = $ImageName"
Write-Host "[build] upstream repo = $($lock.repo_url)"
Write-Host "[build] upstream ref  = $($lock.commit)"

docker build `
    --build-arg "UPSTREAM_REPO=$($lock.repo_url).git" `
    --build-arg "UPSTREAM_REF=$($lock.commit)" `
    --build-arg "UPSTREAM_REF_SHORT=$upstreamShort" `
    --build-arg "UPSTREAM_ARCHIVE_URL=$($lock.archive_url)" `
    --build-arg "BUILD_DATE=$buildDate" `
    -t $ImageName `
    .

if ($LASTEXITCODE -ne 0) {
    throw "docker build failed"
}

