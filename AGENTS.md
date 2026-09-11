# Working in this repository

Each top-level skill directory must contain `SKILL.md`. Keep the entrypoint
short. Put instructions that apply only to one mode in `references/`, and link
them from `SKILL.md` where an agent needs to read them.

Use lowercase letters, digits, and hyphens for skill names. The directory name
and the `name` field in `SKILL.md` must match.

Add `scripts/`, `references/`, or `assets/` only when the skill uses them. Do
not add empty directories or placeholder files.

Run `deno task check` after changing a skill. Run any changed helper scripts
too.

Do not commit secrets, generated caches, or local Codex configuration.
