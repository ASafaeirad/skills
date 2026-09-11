#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(dirname -- "$script_directory")"

usage() {
  printf '%s\n' "usage: list-skills.sh [--format table|plain]"
}

if [[ -t 1 ]]; then
  format="table"
else
  format="plain"
fi

while (( $# > 0 )); do
  case "$1" in
    --format)
      if (( $# < 2 )); then
        printf 'error: --format requires a value\n' >&2
        usage >&2
        exit 1
      fi
      format="$2"
      shift 2
      ;;
    --format=*)
      format="${1#--format=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ $format != "table" && $format != "plain" ]]; then
  printf 'error: invalid format: %s\n' "$format" >&2
  usage >&2
  exit 1
fi

shopt -s nullglob
skill_files=("$repository_root"/*/SKILL.md)

if (( ${#skill_files[@]} == 0 )); then
  printf '%s\n' "No skills found."
  exit 0
fi

declare -a skill_names=()
declare -a descriptions=()

for skill_file in "${skill_files[@]}"; do
  skill_name="$(basename -- "$(dirname -- "$skill_file")")"
  description="$(awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && /^description:[[:space:]]*/ {
      sub(/^description:[[:space:]]*/, "")
      if ((substr($0, 1, 1) == "\"" && substr($0, length($0), 1) == "\"") ||
          (substr($0, 1, 1) == "\047" && substr($0, length($0), 1) == "\047")) {
        print substr($0, 2, length($0) - 2)
      } else {
        print
      }
      exit
    }
  ' "$skill_file")"

  if [[ -z $description ]]; then
    description="description missing"
  fi

  skill_names+=("$skill_name")
  descriptions+=("$description")
done

if [[ $format == "plain" ]]; then
  for index in "${!skill_names[@]}"; do
    printf '%s\t%s\n' "${skill_names[$index]}" "${descriptions[$index]}"
  done
  exit 0
fi

name_heading="SKILL"
description_heading="DESCRIPTION"

terminal_width="${COLUMNS:-0}"
if (( terminal_width == 0 )) && [[ -t 1 ]]; then
  terminal_width="$(tput cols 2>/dev/null || printf '80')"
fi
if (( terminal_width < 40 )); then
  terminal_width=80
fi

# Names wider than the limit get a line of their own, so they do not stretch
# the column for everything else.
name_width_limit=$(( terminal_width / 3 ))
if (( name_width_limit > 28 )); then
  name_width_limit=28
fi
if (( name_width_limit < ${#name_heading} )); then
  name_width_limit=${#name_heading}
fi

name_width=${#name_heading}
for skill_name in "${skill_names[@]}"; do
  if (( ${#skill_name} > name_width && ${#skill_name} <= name_width_limit )); then
    name_width=${#skill_name}
  fi
done

gap="  "
description_width=$(( terminal_width - name_width - ${#gap} ))
if (( description_width < 24 )); then
  description_width=24
fi

if [[ ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} == *[Uu][Tt][Ff]*8* ]]; then
  rule_character="\u2500"
else
  rule_character="-"
fi

if [[ -t 1 ]]; then
  bold="$(printf '\033[1m')"
  dim="$(printf '\033[2m')"
  reset="$(printf '\033[0m')"
else
  bold=""
  dim=""
  reset=""
fi

rule() {
  local count="$1"
  local index
  for (( index = 0; index < count; index++ )); do
    printf '%b' "$rule_character"
  done
}

wrap_description() {
  awk -v width="$1" '
    {
      line = ""
      for (i = 1; i <= NF; i++) {
        if (line == "") {
          candidate = $i
        } else {
          candidate = line " " $i
        }
        if (length(candidate) > width && line != "") {
          print line
          line = $i
        } else {
          line = candidate
        }
      }
      if (line != "") {
        print line
      }
    }
  '
}

printf '%s%-*s%s%s%s%s%s\n' \
  "$bold" "$name_width" "$name_heading" "$reset" "$gap" "$bold" "$description_heading" "$reset"
printf '%s' "$dim"
rule "$name_width"
printf '%s' "$gap"
rule "$description_width"
printf '%s\n' "$reset"

for index in "${!skill_names[@]}"; do
  label="${skill_names[$index]}"

  if (( ${#label} > name_width )); then
    printf '%s\n' "$label"
    label=""
  fi

  while IFS= read -r description_line; do
    printf '%-*s%s%s\n' "$name_width" "$label" "$gap" "$description_line"
    label=""
  done < <(printf '%s\n' "${descriptions[$index]}" | wrap_description "$description_width")
done

if (( ${#skill_names[@]} == 1 )); then
  printf '\n%s1 skill%s\n' "$dim" "$reset"
else
  printf '\n%s%d skills%s\n' "$dim" "${#skill_names[@]}" "$reset"
fi
