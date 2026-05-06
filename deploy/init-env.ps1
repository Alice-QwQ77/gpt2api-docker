param(
    [string]$BackendImage = "",
    [string]$AdminWebImage = "",
    [string]$UserWebImage = "",
    [string]$BackendPackageName = "gpt2api",
    [string]$AdminWebPackageName = "gpt2api-admin-web",
    [string]$UserWebPackageName = "gpt2api-user-web",
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

if ([string]::IsNullOrWhiteSpace($BackendImage) -or [string]::IsNullOrWhiteSpace($AdminWebImage) -or [string]::IsNullOrWhiteSpace($UserWebImage)) {
    Push-Location $repoRoot
    try {
        $remote = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remote)) {
            if ([string]::IsNullOrWhiteSpace($BackendImage)) {
                $BackendImage = Resolve-GhcrImage -RemoteUrl $remote.Trim() -PackageName $BackendPackageName
            }
            if ([string]::IsNullOrWhiteSpace($AdminWebImage)) {
                $AdminWebImage = Resolve-GhcrImage -RemoteUrl $remote.Trim() -PackageName $AdminWebPackageName
            }
            if ([string]::IsNullOrWhiteSpace($UserWebImage)) {
                $UserWebImage = Resolve-GhcrImage -RemoteUrl $remote.Trim() -PackageName $UserWebPackageName
            }
        } else {
            if ([string]::IsNullOrWhiteSpace($BackendImage)) {
                $BackendImage = ("ghcr.io/{0}/{1}:latest" -f $DefaultOwner, $BackendPackageName).ToLowerInvariant()
            }
            if ([string]::IsNullOrWhiteSpace($AdminWebImage)) {
                $AdminWebImage = ("ghcr.io/{0}/{1}:latest" -f $DefaultOwner, $AdminWebPackageName).ToLowerInvariant()
            }
            if ([string]::IsNullOrWhiteSpace($UserWebImage)) {
                $UserWebImage = ("ghcr.io/{0}/{1}:latest" -f $DefaultOwner, $UserWebPackageName).ToLowerInvariant()
            }
        }
    } finally {
        Pop-Location
    }
}

$content = Get-Content $templatePath -Raw
$content = [regex]::Replace($content, '(?m)^KLEIN_BACKEND_IMAGE=.*$', ('KLEIN_BACKEND_IMAGE=' + $BackendImage))
$content = [regex]::Replace($content, '(?m)^KLEIN_ADMIN_WEB_IMAGE=.*$', ('KLEIN_ADMIN_WEB_IMAGE=' + $AdminWebImage))
$content = [regex]::Replace($content, '(?m)^KLEIN_USER_WEB_IMAGE=.*$', ('KLEIN_USER_WEB_IMAGE=' + $UserWebImage))

Set-Content -Path $outputPath -Value $content -Encoding utf8
Write-Host "[init-env] wrote $outputPath"
Write-Host "[init-env] KLEIN_BACKEND_IMAGE=$BackendImage"
Write-Host "[init-env] KLEIN_ADMIN_WEB_IMAGE=$AdminWebImage"
Write-Host "[init-env] KLEIN_USER_WEB_IMAGE=$UserWebImage"
