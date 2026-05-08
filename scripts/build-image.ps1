param(
    [string]$Image = "gpt2api-local:dev",
    [string]$LockPath = "upstream.lock.json"
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$shell = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }
$metaJson = & $shell -NoProfile -File (Join-Path $PSScriptRoot "resolve-build-metadata.ps1") `
    -LockPath $LockPath `
    -Image $Image
if ($LASTEXITCODE -ne 0) {
    throw "failed to resolve build metadata"
}
$meta = $metaJson | ConvertFrom-Json

Write-Host "[build] layout        = $($meta.layout)"
Write-Host "[build] upstream repo = $($meta.repo_url)"
Write-Host "[build] upstream ref  = $($meta.upstream_commit)"
Write-Host "[build] go version    = $($meta.go_version)"

if ($meta.layout -ne "v2") {
    throw "current local packaging only supports upstream v2 layout; got $($meta.layout)"
}

docker build `
    --build-arg "GO_VERSION=$($meta.go_version)" `
    --build-arg "UPSTREAM_ARCHIVE_URL=$($meta.archive_url)" `
    --build-arg "BUILD_DATE=$($meta.build_date)" `
    --build-arg "VERSION=$($meta.version_tag)" `
    -f .\docker\backend.Dockerfile `
    -t $Image `
    .

if ($LASTEXITCODE -ne 0) {
    throw "docker build failed"
}
