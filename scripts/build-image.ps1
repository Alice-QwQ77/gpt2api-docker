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

$metaJson = & powershell -NoProfile -File (Join-Path $PSScriptRoot "resolve-build-metadata.ps1") -LockPath $LockPath -Image $ImageName
if ($LASTEXITCODE -ne 0) {
    throw "failed to resolve build metadata"
}
$meta = $metaJson | ConvertFrom-Json

Write-Host "[build] image         = $ImageName"
Write-Host "[build] upstream repo = $($meta.repo_url)"
Write-Host "[build] upstream ref  = $($meta.upstream_commit)"
Write-Host "[build] go version    = $($meta.go_version)"

docker build `
    --build-arg "GO_VERSION=$($meta.go_version)" `
    --build-arg "UPSTREAM_REPO=$($meta.repo_url).git" `
    --build-arg "UPSTREAM_REF=$($meta.upstream_commit)" `
    --build-arg "UPSTREAM_REF_SHORT=$($meta.upstream_short)" `
    --build-arg "UPSTREAM_ARCHIVE_URL=$($meta.archive_url)" `
    --build-arg "BUILD_DATE=$($meta.build_date)" `
    -t $ImageName `
    .

if ($LASTEXITCODE -ne 0) {
    throw "docker build failed"
}
