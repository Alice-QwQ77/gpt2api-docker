param(
    [string]$Image = "",
    [string]$PackageName = "gpt2api",
    [string]$DefaultOwner = "alice-qwq77",
    [string]$EnvPath = ".env",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$deployDir = Resolve-Path $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $deployDir "..")
$templatePath = Join-Path $deployDir ".env.example"
$outputPath = Join-Path $deployDir $EnvPath

function Resolve-GhcrImage {
    param(
        [string]$RemoteUrl,
        [string]$PackageName
    )

    $patterns = @(
        '^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$',
        '^git@github\.com:(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$',
        '^ssh://git@github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$'
    )

    foreach ($pattern in $patterns) {
        if ($RemoteUrl -match $pattern) {
            $owner = $Matches.owner
            return ("ghcr.io/{0}/{1}:latest" -f $owner, $PackageName).ToLowerInvariant()
        }
    }

    throw "unable to derive ghcr image from remote: $RemoteUrl"
}

if (-not (Test-Path $templatePath)) {
    throw "template not found: $templatePath"
}

if ((Test-Path $outputPath) -and -not $Force) {
    throw "$outputPath already exists. Use -Force to overwrite."
}

if ([string]::IsNullOrWhiteSpace($Image)) {
    Push-Location $repoRoot
    try {
        $remote = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remote)) {
            $Image = Resolve-GhcrImage -RemoteUrl $remote.Trim() -PackageName $PackageName
        } else {
            $Image = ("ghcr.io/{0}/{1}:latest" -f $DefaultOwner, $PackageName).ToLowerInvariant()
        }
    } finally {
        Pop-Location
    }
}

$content = Get-Content $templatePath -Raw
$content = [regex]::Replace(
    $content,
    '(?m)^GPT2API_IMAGE=.*$',
    ('GPT2API_IMAGE=' + $Image)
)

Set-Content -Path $outputPath -Value $content -Encoding utf8
Write-Host "[init-env] wrote $outputPath"
Write-Host "[init-env] GPT2API_IMAGE=$Image"
