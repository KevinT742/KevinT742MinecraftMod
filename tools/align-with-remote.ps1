# ============================================================================
# 让本地与远端对齐（不经过 git fetch）
# ============================================================================
# 为什么要这个脚本：
#   `git fetch` 走的是 github.com 的 git 端点，在这条网络上会间歇性地被掐断
#   （TLS connect error / unexpected eof），重试几次也不一定通。
#   但 api.github.com 直连稳定，而 GitHub 的 REST API 能把远端那个提交的
#   **元数据**（树、父提交、作者、提交时间、说明）全部读出来。
#
#   既然本地和远端的**内容**已经一样（push-via-api.ps1 是按提交里的 blob 推的），
#   就可以在本地用 commit-tree 把那个提交原样重建出来：
#   同样的树、同样的父提交、同样的作者与时间、同样的说明 —— 于是 SHA 也一样。
#   然后 reset --hard 到它，本地就和远端一模一样了。
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
    return (($raw -join "`n") | ConvertFrom-Json)
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

    $commit = Invoke-GhApi -Method GET -Path "/repos/$Owner/$repoName/commits/main"
    $remoteSha = $commit.sha
    $remoteTree = $commit.commit.tree.sha
    $localHead = (git -C $worktree rev-parse HEAD).Trim()
    if ($remoteSha -eq $localHead) {
        Write-Host "$repoName：已经一致（$($remoteSha.Substring(0,7))）"
        continue
    }

    # 远端那棵树的 SHA 与本地的那棵必须是同一个，否则内容根本不一样
    $localTree = (git -C $worktree rev-parse 'HEAD^{tree}').Trim()
    if ($localTree -ne $remoteTree) {
        Write-Host "$repoName：内容不同（本地树 $localTree / 远端树 $remoteTree），先推上去再说"
        continue
    }

    # 用远端的元数据在本地把那个提交原样重建出来。
    # 注意父提交要取**远端那个提交的父**，不是本地 HEAD^ —— API 造出来的提交
    # 挂在远端原来的头上，和本地的父链不是一回事。
    $parent = $commit.parents[0].sha
    $message = $commit.commit.message
    $authorDate = $commit.commit.author.date
    $committerDate = $commit.commit.committer.date
    $authorName = $commit.commit.author.name
    $authorEmail = $commit.commit.author.email

    $env:GIT_AUTHOR_NAME = $authorName
    $env:GIT_AUTHOR_EMAIL = $authorEmail
    $env:GIT_AUTHOR_DATE = $authorDate
    $env:GIT_COMMITTER_NAME = $authorName
    $env:GIT_COMMITTER_EMAIL = $authorEmail
    $env:GIT_COMMITTER_DATE = $committerDate

    $messageFile = Join-Path ([System.IO.Path]::GetTempPath()) ("msg-" + [guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($messageFile, $message, (New-Object System.Text.UTF8Encoding($false)))
    $rebuilt = (& git -C $worktree commit-tree $remoteTree -p $parent -F $messageFile).Trim()

    if ($rebuilt -ne $remoteSha) {
        Write-Host "$repoName：重建出来的提交是 $rebuilt，与远端的 $remoteSha 不同，跳过"
        continue
    }
    git -C $worktree reset --hard $rebuilt | Out-Null
    Write-Host "$repoName：已对齐到 $remoteSha"
}
