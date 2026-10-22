$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_common.ps1')

Add-Type -AssemblyName System.IO.Compression.FileSystem

# 1) Extract the real server jar out of the bundler
$bundleDir = Join-Path $script:Work 'server-extract'
if (-not (Test-Path -LiteralPath $bundleDir)) {
    New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $script:Work 'server-bundle.jar'), $bundleDir)
}
$inner = Get-ChildItem -LiteralPath $bundleDir -Recurse -Filter 'server-*.jar' -File |
    Where-Object { $_.FullName -match 'versions' } | Select-Object -First 1
if (-not $inner) { throw 'inner server jar not found' }
Write-Host "inner server jar: $($inner.Name)"

# 2) Build the merged class directory (client + server)
if (Test-Path -LiteralPath $script:Classes) { Remove-Item -LiteralPath $script:Classes -Recurse -Force }
New-Item -ItemType Directory -Path $script:Classes -Force | Out-Null

function ExpandJar($jar, $to) {
    $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
    foreach ($e in $z.Entries) {
        if ($e.Length -eq 0) { continue }
        # The forward slash works on every platform, the backslash only on Windows.
        $dest = Join-Path $to $e.FullName
        $dir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        try { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true) } catch { }
    }
    $z.Dispose()
}

Write-Host 'expanding client...'
ExpandJar (Join-Path $script:Work 'client.jar') $script:Classes
Write-Host 'expanding server...'
ExpandJar $inner.FullName $script:Classes
Write-Host "merged classes: $((Get-ChildItem -LiteralPath $script:Classes -Recurse -Filter '*.class' -File).Count)"
