<#
.SYNOPSIS
  Propaga um SSOT para todos os mirrors declarados no frontmatter (regra P-102).

.DESCRIPTION
  Lê o frontmatter YAML do arquivo SSOT, extrai a lista `mirrors:` e copia o body
  do SSOT pra cada mirror. Nos mirrors, o frontmatter é reescrito automaticamente
  para conter `mirror_of: <ssot>` (ao inves de source_of_truth: true) e o body
  recebe um comentario HTML indicando origem + hash do SSOT.

  SEGURANCA:
    - Nao propaga se o mirror atual tem hash divergente do "generated from" que
      o script gravou na ultima propagacao (indica edicao manual do mirror).
    - Use -Force para sobrescrever mesmo assim (perde as edicoes manuais).

.PARAMETER Ssot
  Caminho para o arquivo SSOT (com frontmatter contendo source_of_truth: true).

.PARAMETER Force
  Sobrescreve mirrors mesmo se detectar edicao manual desde ultima propagacao.

.PARAMETER DryRun
  So mostra o que faria, nao escreve nada.

.EXAMPLE
  pwsh -File propagate-skill.ps1 -Ssot "..\..\..\Antigravity Root\.agents\skills\upcode\SKILL.md"
  pwsh -File propagate-skill.ps1 -Ssot "..\..\..\.agents\rules\graphify.md" -DryRun
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Ssot,
  [switch]$Force,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$SsotPath = (Resolve-Path -LiteralPath $Ssot).Path
if (-not (Test-Path -LiteralPath $SsotPath)) { throw "SSOT nao encontrado: $SsotPath" }

# Root do AI Roots = tres niveis acima deste script
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Read-YamlFrontmatter {
  param([string]$Path)
  # -Encoding UTF8: no PowerShell 5.1, sem isso UTF-8 sem BOM vira mojibake (causa dos acentos corrompidos de 17/09)
  $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  # (?s): '.' precisa atravessar quebras de linha; sem isso nenhum frontmatter real era reconhecido
  if ($content -notmatch '(?s)^\uFEFF?---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)$') {
    throw "Sem frontmatter: $Path"
  }
  $yaml = $Matches[1]
  $body = $Matches[2]
  $fm = @{}
  $currentKey = $null
  $listBuf = @()
  foreach ($line in $yaml -split "\r?\n") {
    if ($line -match '^([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*)$') {
      if ($currentKey -and $listBuf.Count -gt 0) { $fm[$currentKey] = $listBuf; $listBuf = @() }
      $currentKey = $Matches[1]
      $val = $Matches[2].Trim()
      if ($val -eq '') { $listBuf = @() }   # inicio de lista ou bloco
      else { $fm[$currentKey] = $val; $currentKey = $null }
    }
    elseif ($line -match '^\s*-\s*(.+)$' -and $currentKey) {
      $listBuf += $Matches[1].Trim()
    }
  }
  if ($currentKey -and $listBuf.Count -gt 0) { $fm[$currentKey] = $listBuf }
  return @{ Frontmatter = $fm; Body = $body }
}

function Get-BodyHash {
  param([string]$Text)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

$parsed = Read-YamlFrontmatter -Path $SsotPath
$fm     = $parsed.Frontmatter
$body   = $parsed.Body

if (-not ($fm.ContainsKey('source_of_truth') -and $fm['source_of_truth'] -match '^(true|True)$')) {
  throw "Arquivo nao e SSOT (falta source_of_truth: true): $SsotPath"
}

$mirrors = @()
if ($fm.ContainsKey('mirrors')) {
  $val = $fm['mirrors']
  if ($val -is [array]) { $mirrors = $val }
  elseif ($val -is [string] -and $val -ne '' -and $val -ne '[]') { $mirrors = @($val) }
}

if ($mirrors.Count -eq 0) {
  Write-Host "SSOT valido, mas nenhum mirror declarado. Nada a fazer." -ForegroundColor Yellow
  exit 0
}

$ssotHash = Get-BodyHash -Text $body
$relSsot  = $SsotPath.Substring($Root.Length).TrimStart('\','/').Replace('\','/')
$today    = Get-Date -Format 'yyyy-MM-dd'

Write-Host ""
Write-Host "propagate-skill.ps1  (P-102)" -ForegroundColor Cyan
Write-Host "SSOT: $relSsot  (sha256 body: $($ssotHash.Substring(0,12))...)"
Write-Host "Mirrors declarados: $($mirrors.Count)"
Write-Host ""

$errors = 0
foreach ($m in $mirrors) {
  $mirrorPath = if ([System.IO.Path]::IsPathRooted($m)) { $m } else { Join-Path $Root $m }

  Write-Host "-> $m" -ForegroundColor Cyan

  if (Test-Path -LiteralPath $mirrorPath) {
    # Mirror antigo pode nao ter frontmatter (ex.: comando criado a mao) — tratar como nunca propagado
    try { $existing = Read-YamlFrontmatter -Path $mirrorPath } catch { $existing = @{ Body = '' } }
    $prevOrigin = ($existing.Body -split "\r?\n" | Where-Object { $_ -match '^\s*<!--\s*generated from .* @ ([a-f0-9]{12,})\s*-->' } | Select-Object -First 1)
    if ($prevOrigin -and $prevOrigin -match '@ ([a-f0-9]{12,})') {
      $recordedHash = $Matches[1]
      $currentBodyStripped = ($existing.Body -replace '^\s*<!--\s*generated from .*-->\s*\r?\n', '')
      $currentHash = Get-BodyHash -Text $currentBodyStripped
      if ($currentHash.Substring(0, $recordedHash.Length) -ne $recordedHash -and -not $Force) {
        Write-Host "   FALHA - mirror foi editado a mao desde a ultima propagacao. Use -Force pra sobrescrever." -ForegroundColor Red
        $errors++
        continue
      }
    }
  }

  $idLines = ''
  if ($fm.ContainsKey('name')) { $idLines += "name: $($fm['name'])`n" }
  if ($fm.ContainsKey('description')) { $idLines += "description: $($fm['description'])`n" }
  $newFrontmatter = @"
---
$($idLines)mirror_of: $relSsot
last_verified: $today
verified_by: propagate-skill.ps1
---

<!-- generated from $relSsot @ $($ssotHash.Substring(0,12)) -->
"@
  $newContent = $newFrontmatter + "`n" + $body

  if ($DryRun) {
    Write-Host "   [DryRun] escreveria $($newContent.Length) chars"
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $mirrorPath) | Out-Null
    # UTF-8 sem BOM (BOM antes do '---' atrapalha o parser de frontmatter)
    [System.IO.File]::WriteAllText($mirrorPath, $newContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "   OK - propagado" -ForegroundColor Green
  }
}

Write-Host ""
if ($errors -gt 0) {
  Write-Host "Terminou com $errors erro(s)." -ForegroundColor Red
  exit 1
}
Write-Host "Propagacao completa." -ForegroundColor Green
exit 0
