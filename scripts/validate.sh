#!/usr/bin/env bash
# 注册表仓自检（契约 §7.3 的三件事 + 字段形状）
# 依赖：bash + jq（CI 里 apt-get install jq 或直接用 ubuntu-latest 自带的）
# 用法：bash scripts/validate.sh [目录，缺省本仓根]
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || exit 2

JQ="${JQ:-jq}"
command -v "$JQ" >/dev/null || { echo "[error] 需要 jq" >&2; exit 2; }

FAILS=0
fail() { echo "[FAIL] $*" >&2; FAILS=$((FAILS + 1)); }
ok() { echo "[ok] $*"; }

# ---- 1. 拒绝二进制（本仓永不托管包体） ----
while IFS= read -r f; do
  [ -n "$f" ] || continue
  fail "禁止提交二进制：$f"
done < <(find . -path ./.git -prune -o -type f \
  \( -name '*.zip' -o -name '*.exe' -o -name '*.7z' -o -name '*.tar' -o -name '*.tgz' \
     -o -name '*.tar.gz' -o -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.bin' -o -name '*.msi' \) -print)

# ---- 2. 只认根目录 *.json；文件名必须合命名规则 ----
RE='^[a-z][a-z0-9]*(-[a-z0-9]+)*\.json$'
FILES=()
for f in ./*.json; do
  [ -e "$f" ] || continue
  base="${f#./}"
  if [[ ! "$base" =~ $RE ]]; then
    fail "文件名不合命名规则（$RE）：$base"
    continue
  fi
  FILES+=("$base")
done
[ "${#FILES[@]}" -gt 0 ] || fail "根目录没有任何注册文件"

# ---- 3. 逐文件字段校验 ----
for f in "${FILES[@]}"; do
  id="${f%.json}"
  if ! "$JQ" -e . "$f" >/dev/null 2>&1; then
    fail "$f: JSON 语法错"
    continue
  fi
  # schema / id / type / name / repo
  err=$("$JQ" -r --arg id "$id" '
    def bad(m): m;
    if (.schema != 2) then bad("schema 必须为 2，实际 \(.schema // "缺失")")
    elif (.id // "") == "" then bad("缺 id")
    elif .id != $id then bad("id (\(.id)) 与文件名 (\($id)) 不符")
    elif ((.type // "") | IN("channel","hook","main") | not) then bad("type 必须为 channel|hook|main，实际 \(.type // "缺失")")
    elif (.name // "") == "" then bad("缺 name")
    elif (.repo // "") == "" then bad("缺 repo")
    elif (.repo | test("^https://github\\.com/[^/]+/[^/]+$")) | not then bad("repo 必须是 https://github.com/<owner>/<repo>，实际 \(.repo)")
    elif ((.versions // []) | length) == 0 then bad("versions 为空")
    else empty end' "$f" 2>&1)
  [ -z "$err" ] || { fail "$f: $err"; continue; }

  # main 特有：gateway 对象
  if [ "$id" = "main" ]; then
    err=$("$JQ" -r '
      if (.gateway | type) != "object" then "main 必须有 gateway 对象"
      elif (.gateway.version // "") == "" then "gateway.version 缺失"
      elif ((.gateway.sha256 // "") | test("^[0-9a-f]{64}$")) | not then "gateway.sha256 必须是 64 位小写十六进制"
      else empty end' "$f" 2>&1)
    [ -z "$err" ] || { fail "$f: $err"; continue; }
  fi

  # versions[] 每条：version + file（纯文件名 .zip）+ sha256(64hex) + os/arch
  err=$("$JQ" -r '
    [ .versions[] | select(
        ((.version // "") == "")
        or ((.file // "") == "")
        or (((.file // "") | test("^[^/]+[.]zip$")) | not)
        or (((.sha256 // "") | test("^[0-9a-f]{64}$")) | not)
        or ((.os // "") == "")
        or ((.arch // "") == "")
      ) | "版本条目不合法：\(.version // "?")（file 必填、不能带路径、必须 .zip；sha256 需 64 位小写十六进制）" ] | .[0] // empty' "$f" 2>&1)
  [ -z "$err" ] || { fail "$f: $err"; continue; }

  # 同一版本号可以为 6 个平台各出一条，故去重键是 version+os+arch 复合键（W3-55）
  err=$("$JQ" -r '
    [ .versions[] | "\(.version)/\(.os)/\(.arch)" ] | group_by(.) | map(select(length > 1) | .[0])
    | if length > 0 then "同版本同平台重复声明：\(join(", "))" else empty end' "$f" 2>&1)
  [ -z "$err" ] || { fail "$f: $err"; continue; }

  # 包文件名不得在当前文件内重复（不然一个平台会装到另一个平台的包）
  err=$("$JQ" -r '
    [ .versions[].file ] | group_by(.) | map(select(length > 1) | .[0])
    | if length > 0 then "包文件名重复：\(join(", "))" else empty end' "$f" 2>&1)
  [ -z "$err" ] || { fail "$f: $err"; continue; }

  ok "$f"
done

# ---- 4. id 全表唯一（文件名唯一即已保证；再兜一层 type=main 只能有一个） ----
mains=$(for f in "${FILES[@]}"; do
  [ "$("$JQ" -r '.type // ""' "$f")" = "main" ] && echo "$f"
done | wc -l)
[ "$mains" -le 1 ] || fail "type=main 的文件只能有一个，实际 $mains 个"
[ "$mains" -ge 1 ] || fail "缺少 main.json（主程序条目）"

echo
if [ "$FAILS" -gt 0 ]; then
  echo "[error] $FAILS 项不通过" >&2
  exit 1
fi
echo "全部通过（${#FILES[@]} 个注册文件）"
