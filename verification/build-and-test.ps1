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
Write-Host "[1/4] compiling $($files.Count) sources against Minecraft 26.2 ..."
& "$script:Jdk\bin\javac.exe" -Xmaxerrs 200 -d $mainOut -encoding UTF-8 -nowarn -cp $cp @($files | ForEach-Object { $_.FullName })
if ($LASTEXITCODE -ne 0) { Write-Host 'MAIN COMPILE FAILED'; exit 1 }

# The algorithm self test is compiled against a **narrow** class path on purpose: it may only
# use the api and core layers of the mod and the JDK. That is what proves the algorithm layer
# does not depend on the game.
Write-Host '[2/4] compiling the self test ...'
$testFiles = Get-ChildItem -LiteralPath (Join-Path $script:Project 'src\main\java\genesis\dev') -Recurse -Filter '*.java' -File
& "$script:Jdk\bin\javac.exe" -d $testOut -encoding UTF-8 -nowarn -cp $mainOut @($testFiles | ForEach-Object { $_.FullName })
if ($LASTEXITCODE -ne 0) { Write-Host 'TEST COMPILE FAILED'; exit 1 }

Write-Host '[3/4] running the self test ...'
& "$script:Jdk\bin\java.exe" -cp "$testOut;$mainOut;$cp" genesis.dev.GenesisSelfTest
if ($LASTEXITCODE -ne 0) { exit 1 }

# The persistence test lives in the Minecraft layer, because it needs the NBT machinery of the
# game. It checks that a ritual survives a restart.
Write-Host '[4/4] running the persistence test ...'
& "$script:Jdk\bin\java.exe" -cp "$testOut;$mainOut;$cp" genesis.mc.dev.GenesisPersistenceTest
exit $LASTEXITCODE
