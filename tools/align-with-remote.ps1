# ============================================================================
# 让本地与远端对齐（不经过 git fetch）
# ============================================================================
# 为什么要这个脚本：
#   `git fetch` 走的是 github.com 的 git 端点，在这条网络上会间歇性地被掐断
#   （TLS connect error / unexpected eof），重试几次也不一定通。
#   但 api.github.com 直连稳定，而 GitHub 的 REST API 能把远端提交的
#   **元数据**（树、父提交、作者、提交时间、说明）全部读出来。
#
#   既然本地和远端的**内容**已经一样（push-via-api.ps1 是按提交里的 blob 推的），
#   就可以在本地把远端那条提交链原样重建出来：同样的树、同样的父提交、
#   同样的作者与时间、同样的说明 —— 于是 SHA 也一样。然后 reset --hard 到它，
#   本地就和远端一模一样了。
#
#   远端那条链上可能有**本地从来没有过的提交**（API 造的中间提交），
#   所以要一路往回走，把本地没有的那些逐个补出来，再对齐到远端的头。
#
# 用法：
#   pwsh -File tools\align-with-remote.ps1                 # 对齐所有成员
#   pwsh -File tools\align-with-remote.ps1 -Repos base      # 只对齐 base
# ============================================================================

param(
    [string[]] $Repos = @(),
    [string]   $GhApi = 'E:\Myskills\github-helper\.minimax\skills\github-helper\scripts\gh-api.js',
    [string]   $Owner = 'KevinT742'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$familyRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

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
if (-not $token) { throw 'Windows 凭据管理器里没有 github.com 的凭据，无法认证' }
$env:GITHUB_TOKEN = $token

function Invoke-GhApi {
    param([string] $Method, [string] $Path)
    $raw = & node $GhApi $Method $Path 2>$null
    if ($LASTEXITCODE -ne 0) { throw "gh-api $Method $Path 失败，exit=$LASTEXITCODE" }
    $text = ($raw -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    # ⚠️ 必须用 -DateKind String：ConvertFrom-Json 默认会把日期字符串转成 DateTime 对象，
    #    再拼回字符串时变成 "10/22/2026 08:08:14" 这种本地格式 —— 时区丢了，
    #    重建出来的提交 SHA 就和远端对不上。
    return ($text | ConvertFrom-Json -DateKind String)
}

# 本地有没有这个提交对象
function Test-HasCommit([string] $worktree, [string] $sha) {
    & git -C $worktree cat-file -e "$sha" 2>$null
    return ($LASTEXITCODE -eq 0)
}

# 本地有没有这个对象
function Test-HasObject([string] $worktree, [string] $sha) {
    & git -C $worktree cat-file -e "$sha" 2>$null
    return ($LASTEXITCODE -eq 0)
}

# 用条目造一个树对象。
# ⚠️ git mktree 从**标准输入**读条目，不是从文件参数读 ——
#    把文件名当参数传进去，它会读到空的输入，于是造出一棵空树。
function New-TreeObject([string] $worktree, [string[]] $lines) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'git'
    $psi.Arguments = "-C `"$worktree`" mktree"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($psi)
    $process.StandardInput.Write(($lines -join "`n") + "`n")
    $process.StandardInput.Close()
    $out = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "造树失败：$($process.StandardError.ReadToEnd())" }
    return $out.Trim()
}

# 把远端的一棵树搬到本地来。
# API 造出来的提交挂在远端原来的头上，它用的那棵树本地没有。
# 树里的 blob 本地都有（内容一样，SHA 就一样），缺的只是树对象本身 ——
# 那就把树按远端的条目重新造一遍：同样的条目，同样的 SHA。
function Restore-Tree([string] $worktree, [string] $repoName, [string] $treeSha) {
    if (Test-HasObject $worktree $treeSha) { return $treeSha }

    $listing = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/git/trees/$($treeSha)?recursive=1"

    # 先把缺的 blob 补上
    foreach ($entry in $listing.tree) {
        if ($entry.type -ne 'blob') { continue }
        if (Test-HasObject $worktree $entry.sha) { continue }
        $blob = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/git/blobs/$($entry.sha)"
        $bytes = [Convert]::FromBase64String(($blob.content -replace '\s', ''))
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("blob-" + [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllBytes($tmp, $bytes)
        & git -C $worktree hash-object -w $tmp | Out-Null
    }

    # 再自底向上把子目录的树对象补上（路径越深的越先造）
    $trees = @($listing.tree | Where-Object { $_.type -eq 'tree' } | Sort-Object { $_.path.Length } -Descending)
    foreach ($entry in $trees) {
        if (Test-HasObject $worktree $entry.sha) { continue }
        $prefix = $entry.path + '/'
        $lines = @()
        foreach ($child in $listing.tree) {
            if ($child.path -eq $entry.path) { continue }
            if (-not $child.path.StartsWith($prefix)) { continue }
            $rest = $child.path.Substring($prefix.Length)
            if ($rest.Contains('/')) { continue }   # 更深的一层，不是直接子项
            $lines += "$($child.mode) $($child.type) $($child.sha)`t$rest"
        }
        $listingFile = Join-Path ([System.IO.Path]::GetTempPath()) ("tree-" + [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllLines($listingFile, $lines)
        $made = New-TreeObject $worktree $lines
        if ($made -ne $entry.sha) {
            throw "重建树 $($entry.sha) 失败：得到 $made"
        }
    }

    # 最后造这棵树本身 —— 递归列表里只有它的子项，不含它自己
    $lines = @()
    foreach ($child in $listing.tree) {
        if ($child.path.Contains('/')) { continue }
        $lines += "$($child.mode) $($child.type) $($child.sha)`t$($child.path)"
    }
    $made = New-TreeObject $worktree $lines
    if ($made -ne $treeSha) {
        throw "重建树 $treeSha 失败：得到 $made"
    }
    return $treeSha
}

# 用远端的元数据在本地把一个提交重建出来。
# 注意：这里用的是 GET /git/commits/{sha} 那个端点，它的作者、时间、说明、树
# 都在**顶层**；另一个端点 GET /commits/{ref} 是把它们放在 commit 下面的。
function Rebuild-Commit([string] $worktree, $commit, [string] $parent) {
    $env:GIT_AUTHOR_NAME = $commit.author.name
    $env:GIT_AUTHOR_EMAIL = $commit.author.email
    $env:GIT_AUTHOR_DATE = $commit.author.date
    $env:GIT_COMMITTER_NAME = $commit.committer.name
    $env:GIT_COMMITTER_EMAIL = $commit.committer.email
    $env:GIT_COMMITTER_DATE = $commit.committer.date

    $messageFile = Join-Path ([System.IO.Path]::GetTempPath()) ("msg-" + [guid]::NewGuid().ToString('N'))
    # ⚠️ API 报的 message 把结尾的换行去掉了，而提交里是有的 —— 得补回去，
    #    否则重建出来的提交会差一个字节，SHA 自然对不上。
    [System.IO.File]::WriteAllText($messageFile, ($commit.message + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    $tree = Restore-Tree $worktree $repoName $commit.tree.sha
    # 链首的那个提交没有父提交，这时不能带 -p。
    if ([string]::IsNullOrWhiteSpace($parent)) {
        $rebuilt = (& git -C $worktree commit-tree $tree -F $messageFile).Trim()
    } else {
        $rebuilt = (& git -C $worktree commit-tree $tree -p $parent -F $messageFile).Trim()
    }
    if ($rebuilt -ne $commit.sha) {
        throw "重建出来的提交是 $rebuilt，与远端的 $($commit.sha) 不同"
    }
    return $rebuilt
}

# 要对齐哪些成员
$targets = @()
if ($Repos.Count -gt 0) {
    $targets = $Repos
} else {
    $lock = Join-Path $familyRoot 'members.lock'
    foreach ($line in (Get-Content -LiteralPath $lock)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $targets += ($trimmed -split '\|')[0].Trim()
    }
    $targets += '.'
}

foreach ($member in $targets) {
    $worktree = if ($member -eq '.') { $familyRoot } else { Join-Path $familyRoot $member }
    if (-not (Test-Path -LiteralPath (Join-Path $worktree '.git'))) { continue }

    $remoteUrl = (git -C $worktree remote get-url origin 2>$null)
    if (-not $remoteUrl) { continue }
    $repoName = ($remoteUrl -replace '\.git$', '') -split '/' | Select-Object -Last 1

    $head = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/commits/main"
    $remoteSha = $head.sha
    $localHead = (git -C $worktree rev-parse HEAD).Trim()
    if ($remoteSha -eq $localHead) {
        Write-Host "$repoName：已经一致（$($remoteSha.Substring(0,7))）"
        continue
    }

    # 内容必须一样，否则对齐没有意义
    $remoteTree = $head.commit.tree.sha
    $localTree = (git -C $worktree rev-parse 'HEAD^{tree}').Trim()
    if ($localTree -ne $remoteTree) {
        Write-Host "$repoName：内容不同（本地树 $localTree / 远端树 $remoteTree），先推上去再说"
        continue
    }

    # 一路往回走，把本地没有的提交逐个重建出来
    $chain = @()
    $cursor = $remoteSha
    while ($cursor -and -not (Test-HasCommit $worktree $cursor)) {
        $commit = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/git/commits/$cursor"
        $chain += $commit
        $cursor = $commit.parents[0].sha
    }
    if ($chain.Count -eq 0) {
        Write-Host "$repoName：远端那个提交本地已经有了，但两边 SHA 不同（内容一样）"
        continue
    }
    Write-Host "$repoName：补上 $($chain.Count) 个本地没有的提交"

    # chain 是从新到旧的顺序，倒着重建
    $ordered = @($chain)
    [System.Array]::Reverse($ordered)
    $parent = $cursor
    foreach ($commit in $ordered) {
        $parent = Rebuild-Commit $worktree $commit $parent
    }
    git -C $worktree reset --hard $parent | Out-Null
    Write-Host "$repoName：已对齐到 $remoteSha"
}
