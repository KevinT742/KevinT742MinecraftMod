# ============================================================================
# 通过 Git Data API 推送（绕过 git:// 与 https:// 的传输层）
# ============================================================================
# 为什么需要这个脚本：
#   这台机器上 github.com 的 git 端点（git-upload-pack）直连不通，
#   经 SOCKS5 代理也不稳定（会间歇性挂死），而 api.github.com 直连稳定。
#   GitHub 的 REST API 里有一整套 Git Data API（blob / tree / commit / ref），
#   走的是 api.github.com，因此可以在传输层不可用时照样把提交送上去。
#
#   注意：这不是 git 协议，是"按内容重建一次提交"。因此：
#     * 提交 SHA 会和本地不同（作者/时间/树构造方式不同），本地需要
#       `git fetch && git reset --hard origin/main` 对齐；
#     * 只能推已提交的改动，不能推未提交的工作区内容。
#
# 用法：
#   pwsh -File tools\push-via-api.ps1                    # 推所有有改动的成员 + 装配层
#   pwsh -File tools\push-via-api.ps1 -Repos base         # 只推 base
#   pwsh -File tools\push-via-api.ps1 -Message "自定义提交信息"
#
# 依赖：github-helper 技能的 gh-api.js（下面用 -GhApi 参数指定路径），
#       以及 Windows 凭据管理器里 github.com 的已存凭据。
# ============================================================================

param(
    [string[]] $Repos = @(),
    [string]   $Message = '',
    [string]   $GhApi = 'E:\Myskills\github-helper\.minimax\skills\github-helper\scripts\gh-api.js',
    [string]   $Owner = 'KevinT742'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# 0. 工具准备
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $GhApi)) {
    throw "找不到 gh-api.js：$GhApi"
}

# 从 Windows 凭据管理器取 github.com 的已存凭据。
# 注意：PowerShell 里直接 `"..." | git credential fill` 会失败
# （refusing to work with credential missing protocol field），必须重定向 stdin。
function Get-GitHubToken {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'git'
    $psi.Arguments = 'credential fill'
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($psi)
    $process.StandardInput.Write("protocol=https`nhost=github.com`n`n")
    $process.StandardInput.Close()
    $out = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -like 'password=*') { return $line.Substring(9) }
    }
    return $null
}

$token = Get-GitHubToken
if (-not $token) {
    throw 'Windows 凭据管理器里没有 github.com 的凭据，无法认证'
}
$env:GITHUB_TOKEN = $token

# gh-api.js 把诊断行写到 stderr、JSON 写到 stdout，这里分开处理。
function Invoke-GhApi {
    param([string] $Method, [string] $Path, [object] $Body = $null)
    $args = @($GhApi, $Method, $Path)
    if ($null -ne $Body) {
        $bodyFile = Join-Path ([System.IO.Path]::GetTempPath()) ("ghapi-" + [guid]::NewGuid().ToString('N') + '.json')
        [System.IO.File]::WriteAllText($bodyFile, ($Body | ConvertTo-Json -Depth 20 -Compress), (New-Object System.Text.UTF8Encoding($false)))
        $args += @('--body-file', $bodyFile)
    }
    $raw = & node @args 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "gh-api $Method $Path 失败，exit=$LASTEXITCODE"
    }
    $text = ($raw -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return ($text | ConvertFrom-Json)
}

# 一次请求，拿不到就返回空（不抛错）——用来问"远端有没有这个分支"。
function Invoke-GhApiOptional {
    param([string] $Method, [string] $Path)
    try {
        return Invoke-GhApi -Method $Method -Path $Path
    } catch {
        return $null
    }
}

# 把提交里的一个 blob 按字节取出来。走 .NET 的原始流，不能经过 PowerShell 的
# 文本管道 —— 那会把 LF 重新折成 CRLF，取到的就不是提交里的内容了。
function Get-BlobBytes([string] $repo, [string] $sha, [string] $outFile) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'git'
    $psi.Arguments = "-C `"$repo`" cat-file blob $sha"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($psi)
    $stream = [System.IO.File]::Create($outFile)
    $process.StandardOutput.BaseStream.CopyTo($stream)
    $stream.Close()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "取不到 blob $sha" }
}

# ---------------------------------------------------------------------------
# 1. 确定要推的仓库
# ---------------------------------------------------------------------------

$familyRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# members.lock 里的成员目录 + 装配层本身
$targets = @()
if ($Repos.Count -gt 0) {
    $targets = $Repos
} else {
    $lock = Join-Path $familyRoot 'members.lock'
    if (Test-Path -LiteralPath $lock) {
        foreach ($line in (Get-Content -LiteralPath $lock)) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $targets += ($t -split '\|')[0].Trim()
        }
    }
    $targets += '.'   # 装配层自己
}

# ---------------------------------------------------------------------------
# 2. 逐仓库推送
# ---------------------------------------------------------------------------

$utf8 = New-Object System.Text.UTF8Encoding($false)

foreach ($member in $targets) {
    $worktree = if ($member -eq '.') { $familyRoot } else { Join-Path $familyRoot $member }
    if (-not (Test-Path -LiteralPath (Join-Path $worktree '.git'))) {
        Write-Host "跳过 $member ：不是 git 仓库"
        continue
    }

    # 仓库名 = 远端 origin 的路径最后一段
    $remoteUrl = (git -C $worktree remote get-url origin 2>$null)
    if (-not $remoteUrl) {
        Write-Host "跳过 $member ：没有 origin"
        continue
    }
    $repoName = ($remoteUrl -replace '\.git$', '') -split '/' | Select-Object -Last 1

    $headSha = (git -C $worktree rev-parse HEAD).Trim()
    # 新建的仓库还没有 main 分支，这时远端是空的，所有文件都是新增。
    $ref = Invoke-GhApiOptional -Method GET -Path "/repos/$Owner/$repoName/git/ref/heads/main"
    $remoteSha = if ($null -eq $ref) { $null } else { $ref.object.sha }

    # ⚠️ 空仓库有个坎：GitHub 不允许在**空仓库**里创建 blob（409 Git Repository is empty）。
    #    所以先用 Contents API 放一个文件进去，仓库就不空了，后面的 blob/tree/commit 才走得通。
    if ($null -eq $remoteSha) {
        $first = @((git -C $worktree ls-tree -r --name-only $headSha) | Sort-Object)[0]
        $seedSha = (git -C $worktree rev-parse "$headSha`:$first").Trim()
        $seedFile = Join-Path ([System.IO.Path]::GetTempPath()) ("seed-" + [guid]::NewGuid().ToString('N'))
        Get-BlobBytes $worktree $seedSha $seedFile
        $seedBytes = [System.IO.File]::ReadAllBytes($seedFile)
        Write-Host "   空仓库：先用 $first 把它填上"
        Invoke-GhApi -Method PUT -Path "/repos/$Owner/$repoName/contents/$first" -Body @{
            message = '初始化仓库'
            content = [Convert]::ToBase64String($seedBytes)
            branch = 'main'
        } | Out-Null
        $ref = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/git/ref/heads/main"
        $remoteSha = $ref.object.sha
    }

    if ($remoteSha -eq $headSha) {
        Write-Host "$repoName：远端已是最新（$($headSha.Substring(0,7))），跳过"
        continue
    }

    Write-Host "== $repoName =="
    Write-Host "   本地 $headSha  ->  远端 $remoteSha"

    # 2.1 基线树
    $baseCommit = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/git/commits/$remoteSha"
    $baseTree = $baseCommit.tree.sha

    # 2.2 取改动清单（远端 -> 本地）
    #     不能用 `git diff 远端..本地`：远端那个提交是 API 造的，本地根本没有它，
    #     diff 会失败，而失败会被当成"没有差异"，于是静默漏推。
    #     所以改成把两边的树都列出来，逐个路径比 blob。
    $remoteTree = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/git/trees/$($baseTree)?recursive=1"
    $remoteBlobs = @{}
    foreach ($entry in $remoteTree.tree) {
        if ($entry.type -eq 'blob') { $remoteBlobs[$entry.path] = $entry.sha }
    }
    $localBlobs = @{}
    foreach ($line in (git -C $worktree ls-tree -r $headSha)) {
        $parts = $line -split '\s+', 4
        if ($parts.Count -ge 4) { $localBlobs[$parts[3]] = $parts[2] }
    }

    $changes = @()
    foreach ($path in $localBlobs.Keys) {
        if (-not $remoteBlobs.ContainsKey($path)) {
            $changes += [pscustomobject]@{ Status = 'A'; Path = $path }
        } elseif ($remoteBlobs[$path] -ne $localBlobs[$path]) {
            $changes += [pscustomobject]@{ Status = 'M'; Path = $path }
        }
    }
    foreach ($path in $remoteBlobs.Keys) {
        if (-not $localBlobs.ContainsKey($path)) {
            $changes += [pscustomobject]@{ Status = 'D'; Path = $path }
        }
    }
    if ($changes.Count -eq 0) {
        Write-Host '   没有内容差异，跳过'
        continue
    }
    Write-Host "   改动 $($changes.Count) 个文件"

    # 2.3 每个文件造一个 blob
    $treeEntries = @()
    foreach ($change in $changes) {
        if ($change.Status -eq 'D') {
            Write-Host "   删除 $($change.Path)"
            $treeEntries += @{ path = $change.Path; mode = '100644'; type = 'blob'; sha = $null }
            continue
        }
        # ⚠️ 必须推**提交里的 blob**，不能直接读工作区文件。
        #    工作区文件可能是 CRLF（这台机器的 core.autocrlf 是系统级 true），
        #    而提交里的 blob 是按 .gitattributes 规范化过的 LF。
        #    直接读工作区会把 CRLF 传上去，远端 blob 与本地对不上，
        #    还会让 .gitattributes 的规则形同虚设。
        #    这里用 git cat-file 把提交里的那个 blob 原样取出来（按字节复制，
        #    不经过 PowerShell 的文本管道 —— 那会把 LF 重新折成 CRLF）。
        $expected = (& git -C $worktree rev-parse "$headSha`:$($change.Path)").Trim()
        $probe = Join-Path ([System.IO.Path]::GetTempPath()) ("blob-" + [guid]::NewGuid().ToString('N'))
        Get-BlobBytes $worktree $expected $probe
        $raw = [System.IO.File]::ReadAllBytes($probe)
        $blob = Invoke-GhApi -Method POST -Path "/repos/$Owner/$repoName/git/blobs" -Body @{
            content = [Convert]::ToBase64String($raw)
            encoding = 'base64'
        }
        Write-Host "   写入 $($change.Path)  ($($raw.Length) 字节, blob $($blob.sha.Substring(0,7)))"
        $treeEntries += @{ path = $change.Path; mode = '100644'; type = 'blob'; sha = $blob.sha }
    }

    # 2.4 造树（空仓库没有基线树，就整棵造出来）
    $treeBody = @{ tree = $treeEntries }
    if ($null -ne $baseTree) { $treeBody.base_tree = $baseTree }
    $tree = Invoke-GhApi -Method POST -Path "/repos/$Owner/$repoName/git/trees" -Body $treeBody

    # 2.5 造提交（空仓库的第一个提交没有父提交）
    $commitMessage = if ($Message) { $Message } else { (git -C $worktree log -1 --format=%B $headSha) -join "`n" }
    $identity = @{ name = 'KevinT742'; email = 'dtj126126@126.com'; date = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    $commitBody = @{
        message = $commitMessage
        tree = $tree.sha
        author = $identity
        committer = $identity
    }
    if ($null -ne $remoteSha) { $commitBody.parents = @($remoteSha) }
    $commit = Invoke-GhApi -Method POST -Path "/repos/$Owner/$repoName/git/commits" -Body $commitBody

    # 2.6 推进分支
    $refBody = @{ sha = $commit.sha; force = $false }
    if ($null -eq $remoteSha) {
        # 分支还不存在，先建出来
        Invoke-GhApi -Method POST -Path "/repos/$Owner/$repoName/git/refs" -Body @{
            ref = 'refs/heads/main'
            sha = $commit.sha
        } | Out-Null
    } else {
        Invoke-GhApi -Method PATCH -Path "/repos/$Owner/$repoName/git/refs/heads/main" -Body $refBody | Out-Null
    }

    Write-Host "   已推送：$($commit.sha)  ->  https://github.com/$Owner/$repoName/commit/$($commit.sha)"
    Write-Host "   本地对齐远端：pwsh -File tools\align-with-remote.ps1"
}
