#!/usr/bin/env bash

set -u

export GH_NO_UPDATE_NOTIFIER=1
export GH_PROMPT_DISABLED=1
export GH_SPINNER_DISABLED=1
export LC_ALL=C

api_version='2026-03-10'
hostname='github.com'
targets='centitenka KinomotoMio proto-commons'
output_format='markdown'
dry_run=false
gh_path=''
api_calls=0
put_attempts=0
last_error=''
TAB=$(printf '\t')

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output-format|-OutputFormat)
      [ "$#" -ge 2 ] || { printf '%s\n' 'missing output format' >&2; exit 2; }
      output_format=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
      shift 2
      ;;
    --dry-run|-DryRun)
      dry_run=true
      shift
      ;;
    --gh-path|-GhPath)
      [ "$#" -ge 2 ] || { printf '%s\n' 'missing gh path' >&2; exit 2; }
      gh_path=$2
      shift 2
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

case "$output_format" in
  json|markdown) ;;
  *) printf 'unsupported output format: %s\n' "$output_format" >&2; exit 2 ;;
esac

json_escape() {
  value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\r'/\\r}
  value=${value//$'\n'/\\n}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

json_quote() {
  printf '"%s"' "$(json_escape "$1")"
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

write_terminal_failure() {
  status=$1
  message=$2
  exit_code=$3
  markdown="未执行：$message
未添加或移除任何 Star。"
  if [ "$output_format" = json ]; then
    printf '{"schema_version":1,"status":'
    json_quote "$status"
    printf ',"exit_code":%s,"dry_run":%s,"detail":' "$exit_code" "$dry_run"
    json_quote "$message"
    printf ',"writes_attempted":0,"markdown":'
    json_quote "$markdown"
    printf '}\n'
  else
    printf '%s\n' "$markdown"
  fi
  exit "$exit_code"
}

if [ -z "$gh_path" ]; then
  gh_path=$(command -v gh 2>/dev/null || true)
elif [ "${gh_path#*/}" = "$gh_path" ]; then
  gh_path=$(command -v "$gh_path" 2>/dev/null || true)
fi

if [ -z "$gh_path" ] || [ ! -f "$gh_path" ]; then
  write_terminal_failure 'cli_unavailable' '未找到 GitHub CLI。' 10
fi

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wan-ge-niu-bi.XXXXXX") ||
  write_terminal_failure 'discovery_failed' '无法创建临时工作目录。' 20
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

viewer_file=$temp_dir/viewer
added_file=$temp_dir/added
failure_file=$temp_dir/failures
global_error_file=$temp_dir/global-errors
: > "$added_file"
: > "$failure_file"
: > "$global_error_file"

retryable_error() {
  printf '%s' "$1" | grep -Eqi \
    'HTTP (429|5[0-9][0-9])|secondary rate limit|rate limit exceeded|timed? out|connection (reset|refused)|temporarily unavailable'
}

invoke_gh() {
  output_file=$1
  shift
  attempt=1
  while [ "$attempt" -le 3 ]; do
    api_calls=$((api_calls + 1))
    attempt_file=$temp_dir/gh-attempt
    if "$gh_path" api "$@" > "$attempt_file" 2>&1; then
      mv "$attempt_file" "$output_file"
      return 0
    fi
    raw_error=$(cat "$attempt_file")
    last_error=$(protect_text "$raw_error")
    [ -n "$last_error" ] || last_error="GitHub CLI exited with an error."
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

same_login() {
  awk -v left="$1" -v right="$2" 'BEGIN { exit !(tolower(left) == tolower(right)) }'
}

is_target() {
  for target in $targets; do
    if same_login "$target" "$1"; then return 0; fi
  done
  return 1
}

owner_key() {
  case "$1" in
    centitenka) printf '%s' centitenka ;;
    KinomotoMio) printf '%s' kinomotomio ;;
    proto-commons) printf '%s' proto-commons ;;
    *) printf '%s' unknown ;;
  esac
}

contains_repo() {
  file=$1
  full_name=$2
  awk -F '\t' -v name="$full_name" '
    tolower($3) == tolower(name) { found = 1 }
    END { exit !found }
  ' "$file"
}

set_contains() {
  file=$1
  value=$2
  grep -Fxiq -- "$value" "$file" 2>/dev/null
}

process_records() {
  records=$1
  discovery=$2
  while IFS="$TAB" read -r kind first second third fourth; do
    case "$kind" in
      V)
        [ -n "$first" ] || { last_error='GitHub GraphQL did not return the authenticated account.'; return 1; }
        printf '%s\n' "$first" > "$viewer_file"
        ;;
      O)
        if ! is_target "$first" || ! same_login "$first" "$second"; then
          last_error="GitHub GraphQL did not return target $first."
          return 1
        fi
        key=$(owner_key "$first")
        : > "$temp_dir/owner-$key-seen"
        ;;
      P)
        key=$(owner_key "$first")
        [ "$key" != unknown ] || { last_error="Unexpected target $first."; return 1; }
        case "$second" in true|false) ;; *) last_error="Invalid pagination state for $first."; return 1 ;; esac
        printf '%s\t%s\n' "$second" "$third" > "$temp_dir/page-$key"
        ;;
      R)
        if ! is_target "$first" || [ -z "$second" ] || [ -z "$third" ]; then
          last_error='GitHub GraphQL returned an invalid repository.'
          return 1
        fi
        if ! awk -v owner="$first" -v full="$third" \
          'BEGIN { exit !(index(tolower(full), tolower(owner) "/") == 1) }'; then
          last_error="Unexpected repository owner in GraphQL response: $third"
          return 1
        fi
        case "$fourth" in true|false) ;; *) last_error="Invalid Star state for $third."; return 1 ;; esac
        if ! contains_repo "$discovery" "$third"; then
          printf '%s\t%s\t%s\t%s\n' "$first" "$second" "$third" "$fourth" >> "$discovery"
        fi
        ;;
      E)
        last_error="GitHub GraphQL error: $first"
        return 1
        ;;
      '') ;;
      *) last_error="Unexpected GitHub record: $kind"; return 1 ;;
    esac
  done < "$records"
  return 0
}

initial_query='query WanGeNiuBiState(
  $centitenkaLogin: String!
  $kinomotoMioLogin: String!
  $protoCommonsLogin: String!
) {
  viewer { login }
  centitenka: repositoryOwner(login: $centitenkaLogin) {
    login
    repositories(first: 100, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
  kinomotoMio: repositoryOwner(login: $kinomotoMioLogin) {
    login
    repositories(first: 100, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
  protoCommons: repositoryOwner(login: $protoCommonsLogin) {
    login
    repositories(first: 100, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
}'

initial_filter='if ((.errors // []) | length) > 0 then
  ["E", ((.errors // []) | map(.message) | join("; "))] | @tsv
else
  [
    ["V", (.data.viewer.login // "")],
    ["O", "centitenka", (.data.centitenka.login // "")],
    ["P", "centitenka", (.data.centitenka.repositories.pageInfo.hasNextPage | tostring), (.data.centitenka.repositories.pageInfo.endCursor // "-")],
    (.data.centitenka.repositories.nodes[]? | ["R", "centitenka", .name, .nameWithOwner, (.viewerHasStarred | tostring)]),
    ["O", "KinomotoMio", (.data.kinomotoMio.login // "")],
    ["P", "KinomotoMio", (.data.kinomotoMio.repositories.pageInfo.hasNextPage | tostring), (.data.kinomotoMio.repositories.pageInfo.endCursor // "-")],
    (.data.kinomotoMio.repositories.nodes[]? | ["R", "KinomotoMio", .name, .nameWithOwner, (.viewerHasStarred | tostring)]),
    ["O", "proto-commons", (.data.protoCommons.login // "")],
    ["P", "proto-commons", (.data.protoCommons.repositories.pageInfo.hasNextPage | tostring), (.data.protoCommons.repositories.pageInfo.endCursor // "-")],
    (.data.protoCommons.repositories.nodes[]? | ["R", "proto-commons", .name, .nameWithOwner, (.viewerHasStarred | tostring)])
  ] | .[] | @tsv
end'

page_query='query WanGeNiuBiOwnerPage($login: String!, $endCursor: String) {
  repositoryOwner(login: $login) {
    login
    repositories(first: 100, after: $endCursor, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
}'

page_filter_template='if ((.errors // []) | length) > 0 then
  ["E", ((.errors // []) | map(.message) | join("; "))] | @tsv
else
  [
    ["O", "__OWNER__", (.data.repositoryOwner.login // "")],
    ["P", "__OWNER__", (.data.repositoryOwner.repositories.pageInfo.hasNextPage | tostring), (.data.repositoryOwner.repositories.pageInfo.endCursor // "-")],
    (.data.repositoryOwner.repositories.nodes[]? | ["R", "__OWNER__", .name, .nameWithOwner, (.viewerHasStarred | tostring)])
  ] | .[] | @tsv
end'

load_state() {
  discovery=$1
  : > "$discovery"
  : > "$viewer_file"
  for owner in $targets; do
    key=$(owner_key "$owner")
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
  [ -s "$viewer_file" ] || { last_error='GitHub GraphQL did not return the authenticated account.'; return 1; }

  for owner in $targets; do
    key=$(owner_key "$owner")
    [ -f "$temp_dir/owner-$key-seen" ] && [ -f "$temp_dir/page-$key" ] || {
      last_error="GitHub GraphQL did not return target $owner."
      return 1
    }
    : > "$temp_dir/visited-$key"
    while IFS="$TAB" read -r has_next cursor; do
      [ "$has_next" = true ] || break
      if [ -z "$cursor" ] || [ "$cursor" = '-' ] ||
         grep -Fqx -- "$cursor" "$temp_dir/visited-$key"; then
        last_error="Invalid GraphQL pagination cursor for $owner."
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

  sort -f -t "$TAB" -k3,3 "$discovery" > "$temp_dir/sorted-state"
  mv "$temp_dir/sorted-state" "$discovery"
  return 0
}

classify_discovery_failure() {
  message=$last_error
  if printf '%s' "$message" | grep -Eqi 'HTTP 401|bad credentials|authentication failed|requires authentication'; then
    write_terminal_failure 'credential_rejected' 'GitHub 拒绝了当前凭据。' 11
  fi
  if printf '%s' "$message" | grep -Eqi 'not logged (in|into)|gh auth login|authentication token is missing'; then
    write_terminal_failure 'credential_unavailable' '正常用户上下文中没有可用的 GitHub CLI 凭据。' 10
  fi
  write_terminal_failure 'discovery_failed' "实时仓库或 Star 状态发现失败：$message" 20
}

missing_to_file() {
  state=$1
  output=$2
  awk -F '\t' '$4 == "false" { print $3 }' "$state" > "$output"
}

count_lines() {
  awk 'END { print NR + 0 }' "$1"
}

remove_verified_failures() {
  state=$1
  awk -F '\t' 'NR == FNR { if ($4 == "true") ok[tolower($3)] = 1; next }
    !ok[tolower($1)]' "$state" "$failure_file" > "$temp_dir/failures-next"
  mv "$temp_dir/failures-next" "$failure_file"
}

failure_detail() {
  full_name=$1
  awk -F '\t' -v name="$full_name" '
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

initial_state=$temp_dir/initial-state
if ! load_state "$initial_state"; then
  classify_discovery_failure
fi

authenticated_account=$(cat "$viewer_file")
final_state=$initial_state
status='complete'
exit_code=0

if [ "$dry_run" = true ]; then
  status='dry_run'
else
  missing_file=$temp_dir/missing
  missing_to_file "$initial_state" "$missing_file"
  if [ "$(count_lines "$missing_file")" -gt 0 ]; then
    current_state=$initial_state
    verification_ok=false
    round=1
    while [ "$round" -le 2 ]; do
      missing_to_file "$current_state" "$missing_file"
      while IFS= read -r full_name; do
        [ -n "$full_name" ] || continue
        owner=${full_name%%/*}
        repository=${full_name#*/}
        put_attempts=$((put_attempts + 1))
        write_output=$temp_dir/write-output
        if invoke_gh "$write_output" "user/starred/$owner/$repository" \
            --method PUT --silent \
            --header 'Accept: application/vnd.github+json' \
            --header "X-GitHub-Api-Version: $api_version"; then
          if ! set_contains "$added_file" "$full_name"; then
            printf '%s\n' "$full_name" >> "$added_file"
          fi
        else
          printf '%s\t%s\n' "$full_name" "$last_error" >> "$failure_file"
        fi
      done < "$missing_file"

      verified_state=$temp_dir/verified-state-$round
      if ! load_state "$verified_state"; then
        printf 'Full-scope verification failed: %s\n' "$last_error" >> "$global_error_file"
        break
      fi
      final_state=$verified_state
      remove_verified_failures "$final_state"
      missing_to_file "$final_state" "$missing_file"
      if [ "$(count_lines "$missing_file")" -eq 0 ]; then
        verification_ok=true
        break
      fi
      current_state=$final_state
      round=$((round + 1))
    done
    if [ "$verification_ok" != true ]; then
      status='partial'
      exit_code=30
    fi
  fi
fi

newly_file=$temp_dir/newly
would_file=$temp_dir/would
failed_report=$temp_dir/failed-report
owners_file=$temp_dir/owners
: > "$newly_file"
: > "$would_file"
: > "$failed_report"
: > "$owners_file"

public_count=0
verified_count=0
while IFS="$TAB" read -r owner repository full_name starred; do
  public_count=$((public_count + 1))
  if [ "$starred" = true ]; then
    verified_count=$((verified_count + 1))
    if set_contains "$added_file" "$full_name"; then
      printf '%s\n' "$full_name" >> "$newly_file"
    fi
  elif [ "$dry_run" = true ]; then
    printf '%s\n' "$full_name" >> "$would_file"
  else
    detail=$(failure_detail "$full_name" 2>/dev/null || printf '%s' 'Final verification did not confirm this Star.')
    printf '%s\t%s\n' "$full_name" "$detail" >> "$failed_report"
  fi
done < "$final_state"

newly_count=$(count_lines "$newly_file")
would_count=$(count_lines "$would_file")
failed_count=$(count_lines "$failed_report")
already_count=$((verified_count - newly_count))

for target in $targets; do
  owner_public=$(awk -F '\t' -v owner="$target" 'tolower($1) == tolower(owner) { n++ } END { print n + 0 }' "$final_state")
  owner_verified=$(awk -F '\t' -v owner="$target" 'tolower($1) == tolower(owner) && $4 == "true" { n++ } END { print n + 0 }' "$final_state")
  if [ "$dry_run" = true ]; then
    owner_changed=$(awk -v owner="$target/" 'index(tolower($0), tolower(owner)) == 1 { n++ } END { print n + 0 }' "$would_file")
  else
    owner_changed=$(awk -v owner="$target/" 'index(tolower($0), tolower(owner)) == 1 { n++ } END { print n + 0 }' "$newly_file")
  fi
  owner_failed=$((owner_public - owner_verified))
  [ "$dry_run" = true ] && owner_failed=0
  printf '%s\t%s\t%s\t%s\t%s\n' "$target" "$owner_public" "$owner_verified" "$owner_changed" "$owner_failed" >> "$owners_file"
done

markdown_file=$temp_dir/report.md
heading='✅ 已完成'
[ "$dry_run" = true ] && heading='🧭 Dry Run'
[ "$status" = partial ] && heading='⚠️ 部分完成'
change_label='新增'
change_count=$newly_count
if [ "$dry_run" = true ]; then
  change_label='待新增'
  change_count=$would_count
fi

{
  printf '%s\n\n' '# ⭐ 万哥牛逼｜执行报告'
  printf '> %s · %s/%s 已 Star · %s %s\n>\n' "$heading" "$verified_count" "$public_count" "$change_label" "$change_count"
  printf '> 执行账号：`%s` · API 调用：%s\n\n' "$authenticated_account" "$api_calls"
  printf '%s\n\n' '## 作者概览'
  if [ "$dry_run" = true ]; then owner_change_header='待新增'; else owner_change_header='本次新增'; fi
  printf '| 作者 | 公开仓库 | 已 Star | %s | 失败 |\n' "$owner_change_header"
  printf '%s\n' '| --- | ---: | ---: | ---: | ---: |'
  while IFS="$TAB" read -r owner owner_public owner_verified owner_changed owner_failed; do
    printf '| %s | %s | %s | %s | %s |\n' "$owner" "$owner_public" "$owner_verified" "$owner_changed" "$owner_failed"
  done < "$owners_file"

  change_file=$newly_file
  change_heading='## 本次新增'
  if [ "$dry_run" = true ]; then change_file=$would_file; change_heading='## 待新增'; fi
  if [ "$(count_lines "$change_file")" -gt 0 ]; then
    printf '\n%s\n\n' "$change_heading"
    while IFS= read -r full_name; do printf -- '- `%s`\n' "$full_name"; done < "$change_file"
  fi

  if [ "$failed_count" -gt 0 ] || [ "$(count_lines "$global_error_file")" -gt 0 ]; then
    printf '\n%s\n\n' '## ⚠️ 失败详情'
    while IFS="$TAB" read -r full_name detail; do
      printf -- '- `%s`：%s\n' "$full_name" "$detail"
    done < "$failed_report"
    while IFS= read -r detail; do printf -- '- 全局：%s\n' "$detail"; done < "$global_error_file"
  fi
  printf '\n%s' '私有仓库：按规则不查询、不操作。'
} > "$markdown_file"

emit_string_array() {
  file=$1
  first_item=true
  printf '['
  while IFS= read -r value; do
    [ -n "$value" ] || continue
    if [ "$first_item" = true ]; then first_item=false; else printf ','; fi
    json_quote "$value"
  done < "$file"
  printf ']'
}

emit_failed_array() {
  first_item=true
  printf '['
  while IFS="$TAB" read -r full_name detail; do
    [ -n "$full_name" ] || continue
    if [ "$first_item" = true ]; then first_item=false; else printf ','; fi
    printf '{"repository":'
    json_quote "$full_name"
    printf ',"detail":'
    json_quote "$detail"
    printf '}'
  done < "$failed_report"
  printf ']'
}

emit_owner_array() {
  first_item=true
  printf '['
  while IFS="$TAB" read -r owner owner_public owner_verified owner_changed owner_failed; do
    if [ "$first_item" = true ]; then first_item=false; else printf ','; fi
    printf '{"owner":'
    json_quote "$owner"
    printf ',"public_repositories":%s,"verified_starred":%s,"changed":%s,"failed":%s}' \
      "$owner_public" "$owner_verified" "$owner_changed" "$owner_failed"
  done < "$owners_file"
  printf ']'
}

if [ "$output_format" = json ]; then
  printf '{"schema_version":1,"status":'
  json_quote "$status"
  printf ',"dry_run":%s,"authenticated_account":' "$dry_run"
  json_quote "$authenticated_account"
  printf ',"fixed_targets":["centitenka","KinomotoMio","proto-commons"]'
  printf ',"totals":{"public_repositories":%s,"verified_starred":%s,"newly_starred":%s,"already_starred":%s,"would_star":%s,"failed":%s}' \
    "$public_count" "$verified_count" "$newly_count" "$already_count" "$would_count" "$failed_count"
  printf ',"owners":'
  emit_owner_array
  printf ',"newly_starred":'
  emit_string_array "$newly_file"
  printf ',"would_star":'
  emit_string_array "$would_file"
  printf ',"failed":'
  emit_failed_array
  printf ',"global_errors":'
  emit_string_array "$global_error_file"
  printf ',"api":{"version":"%s","calls":%s,"put_attempts":%s}' "$api_version" "$api_calls" "$put_attempts"
  printf ',"private_repositories":"Not queried or modified.","exit_code":%s,"markdown":' "$exit_code"
  json_quote "$(cat "$markdown_file")"
  printf '}\n'
else
  cat "$markdown_file"
  printf '\n'
fi

exit "$exit_code"
