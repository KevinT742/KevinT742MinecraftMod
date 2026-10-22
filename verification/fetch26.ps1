$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_common.ps1')

$version = '26.2'
New-Item -ItemType Directory -Path $script:Libs -Force | Out-Null

function Fetch($url, $out) {
    if (Test-Path -LiteralPath $out) { Write-Host "  cached: $(Split-Path -Leaf $out)"; return }
    curl.exe -sS -f --max-time 600 --noproxy '*' -o $out $url
    if (-not (Test-Path -LiteralPath $out)) { throw "download failed: $url" }
}

Write-Host "[1/4] version manifest..."
$vm = (curl.exe -s --max-time 60 --noproxy '*' 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json' | Out-String) | ConvertFrom-Json

$v = $vm.versions | Where-Object { $_.id -eq $version } | Select-Object -First 1
if (-not $v) { throw "version $version not found" }

Write-Host "[2/4] $version metadata..."
$vj = (curl.exe -s --max-time 60 --noproxy '*' $v.url | Out-String) | ConvertFrom-Json
$vj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:Work "version-$version.json") -Encoding utf8
Write-Host "  javaVersion: $($vj.javaVersion.majorVersion)  libs: $(@($vj.libraries).Count)"

Write-Host "[3/4] client + server jars..."
Fetch $vj.downloads.client.url (Join-Path $script:Work 'client.jar')
Fetch $vj.downloads.server.url (Join-Path $script:Work 'server-bundle.jar')

Write-Host "[4/4] libraries..."
$i = 0
foreach ($lib in $vj.libraries) {
    $i++
    $artifact = $lib.downloads.artifact
    if (-not $artifact) { continue }
    $out = Join-Path $script:Libs ($artifact.path -replace '/', '__')
    try { Fetch $artifact.url $out } catch { Write-Host "  [skip] $($artifact.path)" }
    if ($i % 25 -eq 0) { Write-Host "  ...$i / $(@($vj.libraries).Count)" }
}
Write-Host "DONE. libs on disk: $((Get-ChildItem -LiteralPath $script:Libs -File).Count)"
