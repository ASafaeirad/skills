#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(dirname -- "$script_directory")"
agents_skills_directory="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
codex_root="${CODEX_HOME:-$HOME/.codex}"
codex_skills_directory="${CODEX_SKILLS_DIR:-$codex_root/skills}"
claude_skills_directory="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

declare -a skill_names=()
declare -a target_names=("Agents")
declare -a target_directories=("$agents_skills_directory")

if (( $# > 0 )); then
  skill_names=("$@")
else
  shopt -s nullglob
  for skill_file in "$repository_root"/*/SKILL.md; do
    skill_names+=("$(basename -- "$(dirname -- "$skill_file")")")
  done
fi

if (( ${#skill_names[@]} == 0 )); then
  printf '%s\n' "No skills found."
  exit 0
fi

confirm() {
  local answer
  read -r -p "$1 [y/N] " answer || return 1
  [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
}

add_target() {
  local target_name="$1"
  local target_directory="$2"
  local existing_directory

  for existing_directory in "${target_directories[@]}"; do
    if [[ $existing_directory == "$target_directory" ]]; then
      return
    fi
  done

  target_names+=("$target_name")
  target_directories+=("$target_directory")
}

if confirm "Also create Codex compatibility links in $codex_skills_directory?"; then
  add_target "Codex" "$codex_skills_directory"
fi

if confirm "Also link skills for Claude in $claude_skills_directory?"; then
  add_target "Claude" "$claude_skills_directory"
fi

has_error=0
for skill_name in "${skill_names[@]}"; do
  if [[ ! $skill_name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    printf 'error: invalid skill name: %s\n' "$skill_name" >&2
    has_error=1
    continue
  fi

  source_directory="$repository_root/$skill_name"
  if [[ ! -f $source_directory/SKILL.md ]]; then
    printf 'error: skill not found: %s\n' "$skill_name" >&2
    has_error=1
    continue
  fi

  for target_directory in "${target_directories[@]}"; do
    destination="$target_directory/$skill_name"
    if [[ -L $destination ]] && [[ $(readlink -- "$destination") == "$source_directory" ]]; then
      continue
    fi
    if [[ -e $destination || -L $destination ]]; then
      printf 'error: destination already exists: %s\n' "$destination" >&2
      has_error=1
    fi
  done
done

if (( has_error != 0 )); then
  exit 1
fi

for target_directory in "${target_directories[@]}"; do
  mkdir -p -- "$target_directory"
done

for skill_name in "${skill_names[@]}"; do
  source_directory="$repository_root/$skill_name"

  for target_index in "${!target_directories[@]}"; do
    target_name="${target_names[$target_index]}"
    target_directory="${target_directories[$target_index]}"
    destination="$target_directory/$skill_name"

    if [[ -L $destination ]] && [[ $(readlink -- "$destination") == "$source_directory" ]]; then
      printf 'already linked %s for %s\n' "$skill_name" "$target_name"
      continue
    fi

    ln -s -- "$source_directory" "$destination"
    printf 'linked %s for %s\n' "$skill_name" "$target_name"
  done
done
