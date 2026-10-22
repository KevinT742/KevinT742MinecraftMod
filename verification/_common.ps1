$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Offline verification harness for the mod family.
#
# It downloads the real Minecraft 26.2 client and server jars from Mojang, extracts them and
# compiles the mod against them. That makes it possible to verify the whole mod on a machine
# that cannot reach maven.neoforged.net.
#
# Usage:
#   pwsh -File fetch26.ps1      # download Minecraft 26.2 (only needed once)
#   pwsh -File prep.ps1         # extract the jars and build the compile classpath
#   pwsh -File build-and-test.ps1   # compile the mod and run the self test
#
# 校验某个家族成员时，用环境变量指定它的目录名：
#   $env:MC_MOD_MEMBER='sandbox'; pwsh -File build-and-test.ps1
#
# 成员之间的依赖关系由 members.lock 的**顺序**表达：靠前的先编译，
# 靠后的成员编译时，类路径里已经有靠前成员的类。

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Work = Join-Path $script:Root 'work'
$script:Libs = Join-Path $script:Work 'libs'
$script:Classes = Join-Path $script:Work 'mc-classes'
$script:StubRoot = Join-Path $script:Root 'stubs'
$script:Jdk = 'E:\DevEnv\JDKs\ms-25.0.4'
# 母文件夹（家族根工程）——本目录的上一级
$script:FamilyRoot = (Resolve-Path (Join-Path $script:Root '..')).Path
# 被校验的家族成员工程。默认校验全部成员。
$script:Member = if ($env:MC_MOD_MEMBER) { $env:MC_MOD_MEMBER } else { $null }

function Get-LibraryClasspath {
    $libs = (Get-ChildItem -LiteralPath $script:Libs -Filter '*.jar' -File | Select-Object -ExpandProperty FullName)
    return (@($script:Classes, $script:StubRoot) + $libs) -join ';'
}

# 家族成员清单，按 members.lock 的顺序。
function Get-MemberList {
    $lock = Join-Path $script:FamilyRoot 'members.lock'
    if (-not (Test-Path -LiteralPath $lock)) {
        return @()
    }
    $members = @()
    foreach ($line in (Get-Content -LiteralPath $lock)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $members += ($trimmed -split '\|')[0].Trim()
    }
    return $members
}

# 某个成员工程的源码目录。
function Get-MemberProject([string] $member) {
    return (Resolve-Path (Join-Path $script:FamilyRoot $member)).Path
}
