#!/usr/bin/env bash
# ============================================================================
# 拉取家族成员仓库
# ============================================================================
# 本仓库（装配层）只保存家族脚手架：settings.gradle / build.gradle /
# gradle.properties / verification/ / CI。
#
# 每个家族成员是**独立的 git 仓库**，源码不在本仓库里。
# 这个脚本按 members.lock 把每个成员拉到装配好的母文件夹里，
# 让 Gradle 能看到完整的家族成员清单。
#
# 用法：
#   tools/fetch-members.sh              # 按 members.lock 拉取
#   tools/fetch-members.sh --force      # 先删掉已有成员目录再拉
#
# CI 里也是调这个脚本，保证本地和 CI 用同一套装配逻辑。
# ============================================================================

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/members.lock"

if [[ ! -f "$lock" ]]; then
    echo "找不到成员清单: $lock" >&2
    exit 1
fi

force=0
for arg in "$@"; do
    case "$arg" in
        --force) force=1 ;;
        *) echo "未知参数: $arg" >&2; exit 2 ;;
    esac
done

fetched=0
while IFS='|' read -r path url ref; do
    # 去掉首尾空白
    path="$(echo "$path" | tr -d '[:space:]')"
    url="$(echo "$url" | tr -d '[:space:]')"
    ref="$(echo "$ref" | tr -d '[:space:]')"

    # 跳过空行与注释行
    [[ -z "$path" ]] && continue
    [[ "$path" == \#* ]] && continue
    if [[ -z "$url" || -z "$ref" ]]; then
        echo "成员行不完整（需要 目录|仓库|ref）: $path" >&2
        exit 1
    fi

    target="$root/$path"
    if [[ $force -eq 1 && -d "$target/.git" ]]; then
        echo "==> 重建 $path"
        rm -rf "$target"
    fi

    if [[ -d "$target/.git" ]]; then
        echo "==> $path 已存在，检查 ref $ref"
        git -C "$target" fetch --depth 1 origin "$ref"
        git -C "$target" checkout --force FETCH_HEAD
    else
        echo "==> 拉取 $path <- $url @ $ref"
        mkdir -p "$target"
        git -C "$target" init -q
        git -C "$target" remote add origin "$url"
        git -C "$target" fetch --depth 1 origin "$ref"
        git -C "$target" checkout --force FETCH_HEAD
    fi
    fetched=$((fetched + 1))
done < "$lock"

echo "==> 装配完成，共 $fetched 个成员"
