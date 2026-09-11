#!/usr/bin/env -S deno run --allow-read

/** Validate the required metadata for every skill in the repository. */

const root = new URL("../", import.meta.url);
const namePattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const fieldPattern = /^([A-Za-z0-9_-]+):\s*(.*?)\s*$/;

interface SkillFile {
  url: URL;
  segments: string[];
}

async function findSkillFiles(
  directory: URL,
  segments: string[] = [],
): Promise<SkillFile[]> {
  const skillFiles: SkillFile[] = [];

  for await (const entry of Deno.readDir(directory)) {
    if (entry.name === ".git") continue;

    const entryUrl = new URL(
      entry.isDirectory ? `${entry.name}/` : entry.name,
      directory,
    );
    const entrySegments = [...segments, entry.name];
    if (entry.isDirectory) {
      skillFiles.push(...await findSkillFiles(entryUrl, entrySegments));
    } else if (entry.isFile && entry.name === "SKILL.md") {
      skillFiles.push({ url: entryUrl, segments: entrySegments });
    }
  }

  return skillFiles;
}

function parseFrontmatter(text: string): {
  values: Record<string, string>;
  errors: string[];
} {
  const lines = text.split(/\r?\n/);
  if (lines[0] !== "---") {
    return {
      values: {},
      errors: ["SKILL.md must start with YAML frontmatter"],
    };
  }

  const end = lines.indexOf("---", 1);
  if (end === -1) {
    return {
      values: {},
      errors: ["SKILL.md frontmatter has no closing delimiter"],
    };
  }

  const values: Record<string, string> = {};
  for (const line of lines.slice(1, end)) {
    if (!line.trim() || /^\s/.test(line)) continue;

    const match = line.match(fieldPattern);
    if (match) values[match[1]] = match[2].replace(/^['"]|['"]$/g, "");
  }

  const errors = text.includes("TODO") ? ["replace all TODO starter text"] : [];
  return { values, errors };
}

async function validate(skillFile: SkillFile): Promise<string[]> {
  const relative = skillFile.segments.join("/");
  const skillName = skillFile.segments.at(-2) ?? "";
  const skillDirectory = new URL("./", skillFile.url);
  const text = await Deno.readTextFile(skillFile.url);
  const { values, errors } = parseFrontmatter(text);
  const name = values.name ?? "";
  const description = values.description ?? "";

  if (skillFile.segments.length !== 2) {
    errors.push(
      "skill directories must live directly under the repository root",
    );
  }
  if (!name) {
    errors.push("frontmatter needs a name");
  } else if (name.length > 64 || !namePattern.test(name)) {
    errors.push(
      "name must use at most 64 lowercase letters, digits, or hyphens",
    );
  } else if (name !== skillName) {
    errors.push(
      `name ${JSON.stringify(name)} does not match directory ${
        JSON.stringify(skillName)
      }`,
    );
  }
  if (!description) errors.push("frontmatter needs a description");

  const openaiFile = new URL("agents/openai.yaml", skillDirectory);
  try {
    const openaiText = await Deno.readTextFile(openaiFile);
    if (openaiText.includes("TODO")) {
      errors.push("replace all TODO starter text in agents/openai.yaml");
    }
    for (
      const field of ["display_name", "short_description", "default_prompt"]
    ) {
      const pattern = new RegExp(`^\\s+${field}:\\s*\\S`, "m");
      if (!pattern.test(openaiText)) {
        errors.push(`agents/openai.yaml needs ${field}`);
      }
    }
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) {
      errors.push("agents/openai.yaml is missing");
    } else {
      throw error;
    }
  }

  return errors.map((error) => `${relative}: ${error}`);
}

const skillFiles = (await findSkillFiles(root)).sort((left, right) =>
  left.url.href.localeCompare(right.url.href)
);
const errors = (await Promise.all(skillFiles.map(validate))).flat();

if (errors.length > 0) {
  console.error(errors.join("\n"));
  Deno.exit(1);
}

const noun = skillFiles.length === 1 ? "skill" : "skills";
console.log(`checked ${skillFiles.length} ${noun}`);
