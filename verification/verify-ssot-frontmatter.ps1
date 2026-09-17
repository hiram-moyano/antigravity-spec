<#
.SYNOPSIS
  Gate de verificação da regra P-101: todo artefato compartilhado tem frontmatter SSOT/mirror.

.DESCRIPTION
  Escaneia os diretórios escopados pelas regras P-1XX e verifica que cada .md tenha
  frontmatter YAML com EXATAMENTE uma das chaves:
    - source_of_truth: true  (+ canonical_path + last_verified)
    - mirror_of: <path>       (+ last_verified)

  Escopos padrão (relativos à raiz do AI Roots):
    - .agents/skills/**/SKILL.md
    - .agents/rules/*.md
    - .agents/workflows/*.md
    - Antigravity Root/.spec/features/*.md

  Retorna exit code:
    0 = tudo ok
    1 = 1+ arquivo(s) violando P-101
    2 = erro de execução

.PARAMETER Root
  Raiz do AI Roots. Padrão: dois níveis acima deste script.

.PARAMETER Fix
  Se presente, imprime também um sugestão de frontmatter mínimo pra colar no início
  de cada arquivo violador (não escreve nada).

.EXAMPLE
  pwsh -File verify-ssot-frontmatter.ps1
  pwsh -File verify-ssot-frontmatter.ps1 -Fix
#>

[CmdletBinding()]
param(
  [string]$Root,
  [switch]$Fix
)

$ErrorActionPreference = 'Stop'

if (-not $Root) {
  # <thisFile> mora em Antigravity Root/.spec/verification/  → Root = ../../..
  $Root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
}
$Root = (Resolve-Path $Root).Path

$scopes = @(
  '.agents/skills/**/SKILL.md',
  '.agents/rules/*.md',
  '.agents/workflows/*.md',
  'Antigravity Root/.spec/features/*.md'
)

function Get-Frontmatter {
  param([string]$Path)
  $lines = Get-Content -LiteralPath $Path -TotalCount 40 -ErrorAction Stop
  if ($lines.Count -lt 3 -or $lines[0].TrimEnd() -ne '---') { return $null }
  $fm = @{}
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].TrimEnd() -eq '---') { return $fm }
    if ($lines[$i] -match '^([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*)$') {
      $fm[$Matches[1]] = $Matches[2].Trim()
    }
  }
  return $null   # abriu --- mas nunca fechou
}

$violations = @()
$checked = 0

foreach ($scope in $scopes) {
  $pattern = Join-Path $Root $scope
  Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
    $checked++
    $fm = Get-Frontmatter -Path $_.FullName
    if ($null -eq $fm) {
      $violations += [PSCustomObject]@{ File = $_.FullName; Reason = 'sem frontmatter YAML' }
      return
    }
    $hasSSOT   = $fm.ContainsKey('source_of_truth') -and $fm['source_of_truth'] -match '^(true|True|yes|Yes)$'
    $hasMirror = $fm.ContainsKey('mirror_of') -and $fm['mirror_of']
    if ($hasSSOT -and $hasMirror) {
      $violations += [PSCustomObject]@{ File = $_.FullName; Reason = 'declara SSOT e mirror ao mesmo tempo' }
    }
    elseif (-not $hasSSOT -and -not $hasMirror) {
      $violations += [PSCustomObject]@{ File = $_.FullName; Reason = 'sem source_of_truth: true nem mirror_of:' }
    }
    elseif (-not $fm.ContainsKey('last_verified')) {
      $violations += [PSCustomObject]@{ File = $_.FullName; Reason = 'sem last_verified' }
    }
  }
}

Write-Host ""
Write-Host "verify-ssot-frontmatter.ps1  (P-101)" -ForegroundColor Cyan
Write-Host "Root: $Root"
Write-Host "Escopos: $($scopes -join ', ')"
Write-Host "Arquivos verificados: $checked"
Write-Host ""

if ($violations.Count -eq 0) {
  Write-Host "OK - todos os arquivos escopados respeitam P-101." -ForegroundColor Green
  exit 0
}

Write-Host "FALHA - $($violations.Count) violacao(oes):" -ForegroundColor Red
foreach ($v in $violations) {
  $rel = $v.File.Substring($Root.Length).TrimStart('\','/')
  Write-Host ("  x " + $rel + "  -> " + $v.Reason) -ForegroundColor Yellow
}

if ($Fix) {
  Write-Host ""
  Write-Host "Sugestao de frontmatter minimo (SSOT):" -ForegroundColor Cyan
  @"
---
name: <nome-do-arquivo-sem-md>
description: <uma frase sobre o proposito deste arquivo>
source_of_truth: true
canonical_path: <caminho relativo a AI Roots>
mirrors: []
last_verified: $(Get-Date -Format 'yyyy-MM-dd')
verified_by: <nome do assistente ou humano>
---

"@ | Write-Host
}

exit 1
