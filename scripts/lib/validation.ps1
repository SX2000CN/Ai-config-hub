$ErrorActionPreference = 'Stop'
$script:AiConfigHubValidationScriptPath = $MyInvocation.MyCommand.Path

function Get-AiConfigHubScanFiles {
    param(
        [Parameter(Mandatory = $true)][string[]]$Paths,
        [Parameter(Mandatory = $true)][string]$Root,
        [string[]]$Extensions = @(
            '.md', '.toml', '.tpl', '.ps1', '.psd1', '.psm1', '.json', '.txt', '.yaml', '.yml',
            '.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx', '.cmd', '.bat', '.sh', '.sql', '.xml',
            '.ini', '.cfg', '.conf'
        )
    )

    $privateRoot = Join-Path $Root 'private'
    return @(Get-ChildItem -Path $Paths -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
        -not $_.FullName.StartsWith($privateRoot, [StringComparison]::OrdinalIgnoreCase) -and
        -not ($_.FullName -match '[\\/]\.git[\\/]') -and
        -not ($_.FullName -match '[\\/]node_modules[\\/]') -and
        -not ($_.FullName -match '[\\/]dist[\\/]') -and
        -not ($_.FullName -match '[\\/]release[\\/]') -and
        -not $_.FullName.Equals($script:AiConfigHubValidationScriptPath, [StringComparison]::OrdinalIgnoreCase) -and
        ($Extensions -contains $_.Extension -or $_.Name -eq '.gitignore')
    } | Sort-Object FullName -Unique)
}

function Test-AiConfigHubSensitiveContent {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Files,
        [Parameter(Mandatory = $true)][scriptblock]$Fail
    )

    $highConfidencePatterns = @(
        @{
            Name = 'OpenAI-style secret key'
            Pattern = '(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{16,}'
        }
        @{
            Name = 'GitHub token'
            Pattern = '(?<![A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{36,}'
        }
        @{
            Name = 'AWS access key'
            Pattern = '(?<![A-Z0-9])AKIA[0-9A-Z]{16}(?![A-Z0-9])'
        }
        @{
            Name = 'PEM private key'
            Pattern = '-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----'
        }
    )
    $warningPatterns = @(
        @{
            Name = 'api key assignment'
            Pattern = '(?i)\bapi[_-]?key\b\s*[:=]'
        }
        @{
            Name = 'token assignment'
            Pattern = '(?i)\btoken\b\s*[:=]'
        }
        @{
            Name = 'password assignment'
            Pattern = '(?i)\bpassword\b\s*[:=]'
        }
        @{
            Name = 'secret assignment'
            Pattern = '(?i)\bsecret\b\s*[:=]'
        }
    )

    foreach ($file in $Files) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        foreach ($item in $highConfidencePatterns) {
            if ($content -match $item.Pattern) {
                & $Fail "High-confidence sensitive content ($($item.Name)) in $($file.FullName)"
            }
        }
        foreach ($item in $warningPatterns) {
            if ($content -match $item.Pattern) {
                Write-Warning "Potential sensitive text ($($item.Name)) in $($file.FullName)"
            }
        }
    }
}
