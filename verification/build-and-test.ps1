$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_common.ps1')

$cp = Get-LibraryClasspath
$mainOut = Join-Path $script:Work 'out-main'
$testOut = Join-Path $script:Work 'out-test'
foreach ($d in @($mainOut, $testOut)) {
    if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

$files = Get-ChildItem -LiteralPath (Join-Path $script:Project 'src\main\java') -Recurse -Filter '*.java' -File
Write-Host "[1/3] compiling $($files.Count) sources against Minecraft 26.2 ..."
& "$script:Jdk\bin\javac.exe" -Xmaxerrs 200 -d $mainOut -encoding UTF-8 -nowarn -cp $cp @($files | ForEach-Object { $_.FullName })
if ($LASTEXITCODE -ne 0) { Write-Host 'MAIN COMPILE FAILED'; exit 1 }

Write-Host '[2/3] compiling the self test ...'
$testFiles = Get-ChildItem -LiteralPath (Join-Path $script:Project 'src\main\java\genesis\dev') -Recurse -Filter '*.java' -File
& "$script:Jdk\bin\javac.exe" -d $testOut -encoding UTF-8 -nowarn -cp $mainOut @($testFiles | ForEach-Object { $_.FullName })
if ($LASTEXITCODE -ne 0) { Write-Host 'TEST COMPILE FAILED'; exit 1 }

Write-Host '[3/3] running the self test ...'
& "$script:Jdk\bin\java.exe" -cp "$testOut;$mainOut;$cp" genesis.dev.GenesisSelfTest
exit $LASTEXITCODE
