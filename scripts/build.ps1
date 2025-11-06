#!/usr/bin/env pwsh

param(
    [Parameter(Position = 0)]
    [string]$ListPath = "../domains/common.txt",
    [Parameter(Position = 1)]
    [string]$OutputName = "my-domains",
    [string]$MihomoPath
)

$ErrorActionPreference = 'Stop'

function Resolve-ExistingPath {
    param([string]$Path)
    try {
        return (Resolve-Path -LiteralPath $Path).Path
    } catch {
        throw "Не удалось найти файл: $Path"
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Resolve-Path -LiteralPath (Join-Path $scriptDir '..')
$listFile = Resolve-ExistingPath (Join-Path $scriptDir $ListPath)
$outputDir = Join-Path $rootDir 'output'

if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$rawLines = Get-Content -LiteralPath $listFile -Encoding utf8
$domains = @()

foreach ($line in $rawLines) {
    $clean = ($line -replace '\r', '').Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) { continue }
    if ($clean.StartsWith('#')) { continue }
    $domains += $clean.ToLowerInvariant()
}

$domains = $domains | Sort-Object -Unique

if ($domains.Count -eq 0) {
    throw "Файл $listFile не содержит доменов"
}

$yamlPath = Join-Path $outputDir "$OutputName.yaml"
$listPath = Join-Path $outputDir "$OutputName.list"
$mrsPath = Join-Path $outputDir "$OutputName.mrs"

"payload:" | Set-Content -LiteralPath $yamlPath -Encoding utf8
$domains | ForEach-Object { "  - '+.$_'" } | Add-Content -LiteralPath $yamlPath -Encoding utf8
$domains | ForEach-Object { '+.' + $_ } | Set-Content -LiteralPath $listPath -Encoding utf8

$resolvedMihomo = $null
if ($PSBoundParameters.ContainsKey('MihomoPath') -and -not [string]::IsNullOrWhiteSpace($MihomoPath)) {
    $resolvedMihomo = Resolve-ExistingPath $MihomoPath
} else {
    $cmd = Get-Command -Name 'mihomo' -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command -Name 'mihomo.exe' -ErrorAction SilentlyContinue
    }
    if ($cmd) {
        $resolvedMihomo = $cmd.Source
    }
}

if ($resolvedMihomo) {
    try {
        & $resolvedMihomo convert-ruleset domain yaml $yamlPath $mrsPath
        Write-Host "Создан файл: $mrsPath"
    } catch {
        Write-Warning "Не удалось собрать .mrs через $resolvedMihomo: $_"
    }
} else {
    Write-Warning "Бинарник mihomo не найден. Пропускаю генерацию .mrs."
}

Write-Host "YAML:   $yamlPath"
Write-Host "LIST:   $listPath"
if (Test-Path -LiteralPath $mrsPath) {
    Write-Host "MRS:    $mrsPath"
}
