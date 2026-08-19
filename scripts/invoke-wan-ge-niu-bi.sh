#!/usr/bin/env bash

set -u

export GH_NO_UPDATE_NOTIFIER=1
export GH_PROMPT_DISABLED=1
export GH_SPINNER_DISABLED=1
export LC_ALL=C

api_version='2026-03-10'
hostname='github.com'
targets='centitenka KinomotoMio proto-commons'
last_error=''
added_names='|'
added_attempts=0
discovered_names='|'
TAB=$(printf '\t')

[ "$#" -eq 0 ] || { printf 'unknown argument: %s\n' "$1" >&2; exit 1; }

fail() {
  printf '❌ 未执行：%s\n' "$1"
  exit 1
}

protect_text() {
  printf '%s' "$1" |
    tr '\r\n\t' '   ' |
    sed -E \
      -e 's/gh[pousr]_[[:alnum:]_]{8,}/[REDACTED]/g' \
      -e 's/github_pat_[[:alnum:]_]{8,}/[REDACTED]/g' \
      -e 's/[[:space:]]+/ /g' \
      -e 's/^ //; s/ $//'
}

gh_path=$(command -v gh 2>/dev/null || true)
[ -n "$gh_path" ] || fail '未找到 GitHub CLI。'

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wan-ge-niu-bi.XXXXXX") ||
  fail '无法创建临时工作目录。'
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

viewer_file=$temp_dir/viewer
failure_file=$temp_dir/failures
: > "$failure_file"

retryable_error() {
  printf '%s' "$1" | grep -Eqi \
    'HTTP (429|5[0-9][0-9])|secondary rate limit|rate limit exceeded|timed? out|connection (reset|refused)|temporarily unavailable'
}

invoke_gh() {
  output_file=$1
  shift
  attempt=1
  while [ "$attempt" -le 3 ]; do
    attempt_file=$temp_dir/gh-attempt
    if "$gh_path" api "$@" > "$attempt_file" 2>&1; then
      mv "$attempt_file" "$output_file"
      return 0
    fi
    last_error=$(protect_text "$(cat "$attempt_file")")
    [ -n "$last_error" ] || last_error='GitHub CLI 调用失败。'
    if [ "$attempt" -lt 3 ] && retryable_error "$last_error"; then
      sleep "$attempt"
      attempt=$((attempt + 1))
      continue
    fi
    rm -f "$attempt_file"
    return 1
  done
  return 1
}

set_owner_key() {
  case "$1" in
    [Cc][Ee][Nn][Tt][Ii][Tt][Ee][Nn][Kk][Aa]) owner_key_value=centitenka ;;
    [Kk][Ii][Nn][Oo][Mm][Oo][Tt][Oo][Mm][Ii][Oo]) owner_key_value=kinomotomio ;;
    [Pp][Rr][Oo][Tt][Oo]-[Cc][Oo][Mm][Mm][Oo][Nn][Ss]) owner_key_value=proto-commons ;;
    *) owner_key_value=''; return 1 ;;
  esac
}

was_added() {
  case "$added_names" in *"|$1|"*) return 0 ;; *) return 1 ;; esac
}

process_records() {
  records=$1
  discovery=$2
  while IFS="$TAB" read -r kind first second third fourth fifth; do
    case "$kind" in
      V)
        [ -n "$first" ] || { last_error='GitHub 未返回当前账号。'; return 1; }
        printf '%s\n' "$first" > "$viewer_file"
        ;;
      O)
        if ! set_owner_key "$first"; then
          last_error="GitHub 未返回目标 owner：$first"
          return 1
        fi
        key=$owner_key_value
        if ! set_owner_key "$second" || [ "$owner_key_value" != "$key" ]; then
          last_error="GitHub 未返回目标 owner：$first"
          return 1
        fi
        : > "$temp_dir/owner-$key-seen"
        ;;
      P)
        set_owner_key "$first" || { last_error="GitHub 返回了意外 owner：$first"; return 1; }
        key=$owner_key_value
        case "$second" in true|false) ;; *) last_error="GitHub 返回了无效分页状态：$first"; return 1 ;; esac
        printf '%s\t%s\n' "$second" "$third" > "$temp_dir/page-$key"
        ;;
      R)
        if ! set_owner_key "$first" || [ -z "$second" ] || [ -z "$third" ]; then
          last_error='GitHub 返回了无效仓库。'
          return 1
        fi
        key=$owner_key_value
        repo_owner=${third%%/*}
        if [ "$repo_owner" = "$third" ] || ! set_owner_key "$repo_owner" ||
           [ "$owner_key_value" != "$key" ]; then
          last_error="GitHub 返回了意外仓库：$third"
          return 1
        fi
        case "$fourth" in true|false) ;; *) last_error="GitHub 返回了无效 Star 状态：$third"; return 1 ;; esac
        case "$fifth" in ''|*[!0-9]*) last_error="GitHub 返回了无效 Star 数：$third"; return 1 ;; esac
        case "$discovered_names" in
          *"|$third|"*) ;;
          *)
            printf '%s\t%s\t%s\t%s\t%s\n' "$first" "$second" "$third" "$fourth" "$fifth" >> "$discovery"
            discovered_names="${discovered_names}${third}|"
            ;;
        esac
        ;;
      E) last_error="GitHub GraphQL 错误：$first"; return 1 ;;
      '') ;;
      *) last_error="GitHub 返回了意外记录：$kind"; return 1 ;;
    esac
  done < "$records"
}

initial_query='query WanGeNiuBiState($centitenkaLogin:String!,$kinomotoMioLogin:String!,$protoCommonsLogin:String!){viewer{login} centitenka:repositoryOwner(login:$centitenkaLogin){login repositories(first:100,privacy:PUBLIC,ownerAffiliations:[OWNER],orderBy:{field:NAME,direction:ASC}){nodes{name nameWithOwner viewerHasStarred stargazerCount} pageInfo{hasNextPage endCursor}}} kinomotoMio:repositoryOwner(login:$kinomotoMioLogin){login repositories(first:100,privacy:PUBLIC,ownerAffiliations:[OWNER],orderBy:{field:NAME,direction:ASC}){nodes{name nameWithOwner viewerHasStarred stargazerCount} pageInfo{hasNextPage endCursor}}} protoCommons:repositoryOwner(login:$protoCommonsLogin){login repositories(first:100,privacy:PUBLIC,ownerAffiliations:[OWNER],orderBy:{field:NAME,direction:ASC}){nodes{name nameWithOwner viewerHasStarred stargazerCount} pageInfo{hasNextPage endCursor}}}}'

initial_filter='if ((.errors//[])|length)>0 then ["E",((.errors//[])|map(.message)|join("; "))]|@tsv else [["V",(.data.viewer.login//"")],["O","centitenka",(.data.centitenka.login//"")],["P","centitenka",(.data.centitenka.repositories.pageInfo.hasNextPage|tostring),(.data.centitenka.repositories.pageInfo.endCursor//"-")],(.data.centitenka.repositories.nodes[]?|["R","centitenka",.name,.nameWithOwner,(.viewerHasStarred|tostring),(.stargazerCount|tostring)]),["O","KinomotoMio",(.data.kinomotoMio.login//"")],["P","KinomotoMio",(.data.kinomotoMio.repositories.pageInfo.hasNextPage|tostring),(.data.kinomotoMio.repositories.pageInfo.endCursor//"-")],(.data.kinomotoMio.repositories.nodes[]?|["R","KinomotoMio",.name,.nameWithOwner,(.viewerHasStarred|tostring),(.stargazerCount|tostring)]),["O","proto-commons",(.data.protoCommons.login//"")],["P","proto-commons",(.data.protoCommons.repositories.pageInfo.hasNextPage|tostring),(.data.protoCommons.repositories.pageInfo.endCursor//"-")],(.data.protoCommons.repositories.nodes[]?|["R","proto-commons",.name,.nameWithOwner,(.viewerHasStarred|tostring),(.stargazerCount|tostring)])]|.[]|@tsv end'

page_query='query WanGeNiuBiOwnerPage($login:String!,$endCursor:String){repositoryOwner(login:$login){login repositories(first:100,after:$endCursor,privacy:PUBLIC,ownerAffiliations:[OWNER],orderBy:{field:NAME,direction:ASC}){nodes{name nameWithOwner viewerHasStarred stargazerCount} pageInfo{hasNextPage endCursor}}}}'

page_filter_template='if ((.errors//[])|length)>0 then ["E",((.errors//[])|map(.message)|join("; "))]|@tsv else [["O","__OWNER__",(.data.repositoryOwner.login//"")],["P","__OWNER__",(.data.repositoryOwner.repositories.pageInfo.hasNextPage|tostring),(.data.repositoryOwner.repositories.pageInfo.endCursor//"-")],(.data.repositoryOwner.repositories.nodes[]?|["R","__OWNER__",.name,.nameWithOwner,(.viewerHasStarred|tostring),(.stargazerCount|tostring)])]|.[]|@tsv end'

load_state() {
  discovery=$1
  discovered_names='|'
  : > "$discovery"
  : > "$viewer_file"
  for owner in $targets; do
    set_owner_key "$owner"
    key=$owner_key_value
    rm -f "$temp_dir/page-$key" "$temp_dir/owner-$key-seen" "$temp_dir/visited-$key"
  done

  records=$temp_dir/initial-records
  if ! invoke_gh "$records" graphql --hostname "$hostname" \
      -F centitenkaLogin=centitenka \
      -F kinomotoMioLogin=KinomotoMio \
      -F protoCommonsLogin=proto-commons \
      -f "query=$initial_query" --jq "$initial_filter"; then
    return 1
  fi
  process_records "$records" "$discovery" || return 1
  [ -s "$viewer_file" ] || { last_error='GitHub 未返回当前账号。'; return 1; }

  for owner in $targets; do
    set_owner_key "$owner"
    key=$owner_key_value
    [ -f "$temp_dir/owner-$key-seen" ] && [ -f "$temp_dir/page-$key" ] || {
      last_error="GitHub 未返回目标 owner：$owner"
      return 1
    }
    : > "$temp_dir/visited-$key"
    while IFS="$TAB" read -r has_next cursor; do
      [ "$has_next" = true ] || break
      if [ -z "$cursor" ] || [ "$cursor" = '-' ] ||
         grep -Fqx -- "$cursor" "$temp_dir/visited-$key"; then
        last_error="GitHub 返回了无效分页游标：$owner"
        return 1
      fi
      printf '%s\n' "$cursor" >> "$temp_dir/visited-$key"
      page_filter=${page_filter_template//__OWNER__/$owner}
      page_records=$temp_dir/page-records
      if ! invoke_gh "$page_records" graphql --hostname "$hostname" \
          -F "login=$owner" -F "endCursor=$cursor" \
          -f "query=$page_query" --jq "$page_filter"; then
        return 1
      fi
      process_records "$page_records" "$discovery" || return 1
    done < "$temp_dir/page-$key"
  done

  sort -f -t "$TAB" -k5,5nr -k3,3 "$discovery" > "$temp_dir/sorted-state"
  mv "$temp_dir/sorted-state" "$discovery"
}

missing_to_file() {
  awk -F '\t' '$4 == "false" { print $3 }' "$1" > "$2"
}

count_lines() {
  awk 'END { print NR + 0 }' "$1"
}

failure_detail() {
  awk -F '\t' -v name="$1" '
    tolower($1) == tolower(name) {
      $1 = ""
      sub(/^\t/, "")
      print
      found = 1
      exit
    }
    END { if (!found) exit 1 }
  ' "$failure_file"
}

render_report() {
  state=$1
  report_missing=$temp_dir/report-missing
  confirmed_added=$temp_dir/confirmed-added
  missing_to_file "$state" "$report_missing"
  : > "$confirmed_added"

  total=$(count_lines "$state")
  missing_count=$(count_lines "$report_missing")
  starred_count=$((total - missing_count))
  while IFS="$TAB" read -r owner repository full_name starred stars; do
    if [ "$starred" = true ] && was_added "$full_name"; then
      printf '%s\n' "$full_name" >> "$confirmed_added"
    fi
  done < "$state"
  added_count=$(count_lines "$confirmed_added")

  if [ "$missing_count" -eq 0 ]; then
    printf '✅ %s/%s 已 Star，本次新增 %s\n' "$starred_count" "$total" "$added_count"
  else
    printf '⚠️ %s/%s 已 Star，失败 %s\n' "$starred_count" "$total" "$missing_count"
  fi
  printf '账号：`%s`\n' "$(cat "$viewer_file")"

  change_file=$confirmed_added
  change_heading='本次新增：'
  if [ "$(count_lines "$change_file")" -gt 0 ]; then
    printf '\n%s\n' "$change_heading"
    while IFS= read -r full_name; do printf -- '- `%s`\n' "$full_name"; done < "$change_file"
  fi

  if [ "$missing_count" -gt 0 ]; then
    printf '\n%s\n' '失败：'
    while IFS= read -r full_name; do
      detail=$(failure_detail "$full_name" 2>/dev/null || printf '%s' '最终核验未确认该 Star。')
      printf -- '- `%s`：%s\n' "$full_name" "$detail"
    done < "$report_missing"
  fi

  printf '\n%s\n' '| # | 仓库 | Stars |'
  printf '%s\n' '| ---: | --- | ---: |'
  rank=0
  while IFS="$TAB" read -r owner repository full_name starred stars; do
    rank=$((rank + 1))
    case "$rank" in 1) place='🥇' ;; 2) place='🥈' ;; 3) place='🥉' ;; *) place="#$rank" ;; esac
    project="[$full_name](https://github.com/$full_name)"
    printf '| %s | %s | %s |\n' "$place" "$project" "$stars"
  done < "$state"
}

initial_state=$temp_dir/initial-state
if ! load_state "$initial_state"; then
  fail "实时仓库或 Star 状态发现失败：$last_error"
fi
account=$(cat "$viewer_file")
missing_file=$temp_dir/missing
missing_to_file "$initial_state" "$missing_file"

if [ "$(count_lines "$missing_file")" -eq 0 ]; then
  render_report "$initial_state"
  exit 0
fi

while IFS= read -r full_name; do
  [ -n "$full_name" ] || continue
  owner=${full_name%%/*}
  repository=${full_name#*/}
  write_output=$temp_dir/write-output
  if invoke_gh "$write_output" "user/starred/$owner/$repository" \
      --method PUT --silent \
      --header 'Accept: application/vnd.github+json' \
      --header "X-GitHub-Api-Version: $api_version"; then
    added_names="${added_names}${full_name}|"
    added_attempts=$((added_attempts + 1))
  else
    printf '%s\t%s\n' "$full_name" "$last_error" >> "$failure_file"
  fi
done < "$missing_file"

final_state=$temp_dir/final-state
if ! load_state "$final_state"; then
  printf '⚠️ 部分完成：已尝试补齐 %s 个 Star，但最终核验失败。\n' "$added_attempts"
  printf '账号：`%s`\n' "$account"
  printf '错误：%s\n' "$last_error"
  exit 1
fi

render_report "$final_state"
missing_to_file "$final_state" "$missing_file"
[ "$(count_lines "$missing_file")" -eq 0 ] || exit 1
