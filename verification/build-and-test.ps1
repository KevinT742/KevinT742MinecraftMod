$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_common.ps1')

$cp = Get-LibraryClasspath
$members = Get-MemberList
if ($members.Count -eq 0) {
    Write-Host 'members.lock 里没有成员'
    exit 1
}

# 校验哪些成员：默认全部；MC_MOD_MEMBER 指定时只校验它（但它的前置成员仍要编译）。
$verified = if ($script:Member) { @($script:Member) } else { $members }

# ---------------------------------------------------------------------------
# 1. 按 members.lock 的顺序编译每一个成员
#    后面的成员编译时，类路径里已经有前面成员的类 —— 这就是"家族"在构建上的含义。
# ---------------------------------------------------------------------------
$outputs = [ordered]@{}

foreach ($member in $members) {
    $project = Get-MemberProject $member
    $out = Join-Path $script:Work ("out-$member")
    if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Recurse -Force }
    New-Item -ItemType Directory -Path $out -Force | Out-Null

    $files = Get-ChildItem -LiteralPath (Join-Path $project 'src\main\java') -Recurse -Filter '*.java' -File
    $memberCp = @($cp) + @($outputs.Values)
    Write-Host "[编译] $member ($($files.Count) 个源文件)"
    & "$script:Jdk\bin\javac.exe" -Xmaxerrs 200 -d $out -encoding UTF-8 -nowarn -cp ($memberCp -join ';') @($files | ForEach-Object { $_.FullName })
    if ($LASTEXITCODE -ne 0) { Write-Host "COMPILE FAILED: $member"; exit 1 }
    $outputs[$member] = $out
}

# ---------------------------------------------------------------------------
# 2. 编译并运行每一个成员的自检
#    自检分两种：
#      * <成员根包>/dev/ 下的自检 —— 用**窄类路径**编译（只有各成员的类，没有游戏），
#        这机械地证明了 api / core 层不依赖游戏；
#      * 更深的 dev/ 包下的自检 —— 需要游戏的 NBT 之类的机制，用完整类路径。
# ---------------------------------------------------------------------------
$allOutputs = @($outputs.Values)
$fullCp = (@($allOutputs) + @($cp)) -join ';'
$narrowCp = $allOutputs -join ';'

foreach ($member in $verified) {
    $project = Get-MemberProject $member
    $out = $outputs[$member]

    $tests = Get-ChildItem -LiteralPath (Join-Path $project 'src\main\java') -Recurse -Filter '*Test.java' -File |
        Where-Object { $_.DirectoryName -match '[\\/]dev$' }
    if ($tests.Count -eq 0) { continue }

    foreach ($test in $tests) {
        # 自检的类名 = 包名 + 类名
        $relative = $test.FullName.Substring((Join-Path $project 'src\main\java').Length + 1)
        $className = ($relative -replace '\.java$', '') -replace '[\\/]', '.'
        # 相对源码根只有一层包（即 <成员根包>/dev/）的自检走窄类路径
        $depth = ($relative -split '[\\/]').Count
        $useNarrow = ($depth -eq 3)

        $testOut = Join-Path $script:Work ("test-$member-" + ($className -replace '\.', '_'))
        if (Test-Path -LiteralPath $testOut) { Remove-Item -LiteralPath $testOut -Recurse -Force }
        New-Item -ItemType Directory -Path $testOut -Force | Out-Null

        $testCp = if ($useNarrow) { $narrowCp } else { $fullCp }
        Write-Host "[自检] $className  ($($(if ($useNarrow) { '窄类路径' } else { '完整类路径' })))"
        & "$script:Jdk\bin\javac.exe" -d $testOut -encoding UTF-8 -nowarn -cp $testCp $test.FullName
        if ($LASTEXITCODE -ne 0) { Write-Host "TEST COMPILE FAILED: $className"; exit 1 }

        & "$script:Jdk\bin\java.exe" -cp "$testOut;$fullCp" $className
        if ($LASTEXITCODE -ne 0) { Write-Host "TEST FAILED: $className"; exit 1 }
    }
}

Write-Host '==> 全部通过'
exit 0
