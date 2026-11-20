/**
 * Fleet agent discovery, default agents, and frontmatter editing.
 *
 * Agents are markdown files with YAML frontmatter:
 *
 *   ---
 *   name: reviewer
 *   description: Code review specialist (read-only)
 *   tools: read, grep, find, ls, bash
 *   model: anthropic/claude-sonnet-4-5
 *   ---
 *
 * Locations:
 *   ~/.pi/agent/agents/*.md  - user level (always loaded)
 *   .pi/agents/*.md          - project level (only with scope "project" | "both")
 */

import * as fs from "node:fs";
import * as path from "node:path";
import {
	CONFIG_DIR_NAME,
	getAgentDir,
	parseFrontmatter,
	withFileMutationQueue,
} from "@earendil-works/pi-coding-agent";

export type AgentScope = "user" | "project" | "both";

export interface AgentConfig {
	name: string;
	description: string;
	tools?: string[];
	model?: string;
	systemPrompt: string;
	source: "user" | "project";
	filePath: string;
}

function loadAgentsFromDir(dir: string, source: "user" | "project"): AgentConfig[] {
	const agents: AgentConfig[] = [];
	if (!fs.existsSync(dir)) return agents;

	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return agents;
	}

	for (const entry of entries) {
		if (!entry.name.endsWith(".md")) continue;
		if (!entry.isFile() && !entry.isSymbolicLink()) continue;

		const filePath = path.join(dir, entry.name);
		let content: string;
		try {
			content = fs.readFileSync(filePath, "utf-8");
		} catch {
			continue;
		}

		const { frontmatter, body } = parseFrontmatter<Record<string, string>>(content);
		if (!frontmatter.name || !frontmatter.description) continue;

		const tools = frontmatter.tools
			?.split(",")
			.map((t: string) => t.trim())
			.filter(Boolean);

		agents.push({
			name: frontmatter.name,
			description: frontmatter.description,
			tools: tools && tools.length > 0 ? tools : undefined,
			model: frontmatter.model,
			systemPrompt: body,
			source,
			filePath,
		});
	}
	return agents;
}

function isDirectory(p: string): boolean {
	try {
		return fs.statSync(p).isDirectory();
	} catch {
		return false;
	}
}

function findNearestProjectAgentsDir(cwd: string): string | null {
	let currentDir = cwd;
	while (true) {
		const candidate = path.join(currentDir, CONFIG_DIR_NAME, "agents");
		if (isDirectory(candidate)) return candidate;
		const parentDir = path.dirname(currentDir);
		if (parentDir === currentDir) return null;
		currentDir = parentDir;
	}
}

export function discoverAgents(cwd: string, scope: AgentScope): { agents: AgentConfig[]; projectAgentsDir: string | null } {
	const userDir = path.join(getAgentDir(), "agents");
	const projectAgentsDir = findNearestProjectAgentsDir(cwd);

	const userAgents = scope === "project" ? [] : loadAgentsFromDir(userDir, "user");
	const projectAgents = scope === "user" || !projectAgentsDir ? [] : loadAgentsFromDir(projectAgentsDir, "project");

	const agentMap = new Map<string, AgentConfig>();
	if (scope === "both") {
		for (const agent of userAgents) agentMap.set(agent.name, agent);
		for (const agent of projectAgents) agentMap.set(agent.name, agent);
	} else if (scope === "user") {
		for (const agent of userAgents) agentMap.set(agent.name, agent);
	} else {
		for (const agent of projectAgents) agentMap.set(agent.name, agent);
	}

	return { agents: Array.from(agentMap.values()), projectAgentsDir };
}

export function formatAgentList(agents: AgentConfig[], maxItems: number): { text: string; remaining: number } {
	if (agents.length === 0) return { text: "none", remaining: 0 };
	const listed = agents.slice(0, maxItems);
	const remaining = agents.length - listed.length;
	return {
		text: listed.map((a) => `${a.name} (${a.source}): ${a.description}`).join("; "),
		remaining,
	};
}

/* ------------------------------------------------------------------ */
/* Default agents                                                      */
/* ------------------------------------------------------------------ */

interface DefaultAgentSpec {
	name: string;
	description: string;
	tools?: string;
	body: string;
}

export const DEFAULT_AGENTS: DefaultAgentSpec[] = [
	{
		name: "implementer",
		description:
			"General-purpose implementer that writes and modifies code autonomously. Use for implementation, bug fixes, and feature work.",
		body: `You are the implementer agent in a fleet. You operate in an isolated context and are expected to work autonomously.

- Read the relevant code before making changes.
- Use the edit/write tools to modify files.
- Run tests or type checks when reasonable.
- When finished, report exactly what changed and why.

Output format:

## Completed
What was done.

## Files Changed
- \`path/to/file\` - what changed

## Notes
Anything the coordinator should know.`,
	},
	{
		name: "reviewer",
		description:
			"Senior code reviewer that analyzes diffs and files for bugs, security issues, and maintainability. Read-only.",
		tools: "read, grep, find, ls, bash",
		body: `You are a senior code reviewer in a fleet. Analyze code for quality, security, and maintainability.

Bash is for read-only commands only (\`git diff\`, \`git log\`, \`git show\`). Do NOT modify files or run builds.

Strategy:
1. Run \`git diff\` to see recent changes (if applicable)
2. Read the modified files
3. Check for bugs, security issues, code smells

Output format:

## Files Reviewed
- \`path/to/file.ts\` (lines X-Y)

## Critical (must fix)
- \`file.ts:42\` - Issue description

## Warnings (should fix)
- \`file.ts:100\` - Issue description

## Suggestions (consider)
- \`file.ts:150\` - Improvement idea

## Summary
Overall assessment in 2-3 sentences.

Be specific with file paths and line numbers.`,
	},
	{
		name: "researcher",
		description:
			"Read-only research agent that investigates codebases, APIs, and documentation and returns structured findings.",
		tools: "read, grep, find, ls, bash",
		body: `You are a researcher in a fleet. Investigate and return structured findings.

- Locate relevant code, APIs, configs, and docs.
- Read key sections; do not modify anything.
- Report file paths with line ranges and short explanations.

Output format:

## Findings
1. \`path/to/file\` (lines X-Y) - what it is / why it matters

## Key APIs / Functions
- name - signature / behavior

## Open Questions
Anything that needs a decision before implementation.`,
	},
	{
		name: "planner",
		description: "Creates step-by-step implementation plans from context and requirements. Read-only.",
		tools: "read, grep, find, ls",
		body: `You are a planning specialist in a fleet. You receive context and requirements and produce a concrete implementation plan.

Do NOT make changes. Only read, analyze, and plan.

Output format:

## Goal
One sentence.

## Plan
Numbered steps, each small and actionable.

## Files to Modify
- \`path/to/file\` - what changes

## New Files (if any)
- \`path/to/new.ts\` - purpose

## Risks
Watch out for...`,
	},
	{
		name: "scout",
		description:
			"Fast codebase recon agent that returns compressed context for handoff to other agents. Read-only.",
		tools: "read, grep, find, ls, bash",
		body: `You are a scout in a fleet. Quickly investigate a codebase and return structured findings another agent can use without re-reading everything.

Strategy:
1. grep/find to locate relevant code
2. Read key sections
3. Identify types, interfaces, key functions
4. Note dependencies between files

Output format:

## Files Retrieved
1. \`path/to/file\` (lines X-Y) - description

## Key Code
Critical types/functions with actual code.

## Architecture
How the pieces connect.

## Start Here
Which file to look at first and why.`,
	},
];

/**
 * Create the default fleet agents on first use (idempotent).
 * Only runs when the user agents directory has no .md files at all,
 * so user-created agents are never overwritten.
 * Returns the list of created file paths.
 */
export function ensureDefaultAgents(): string[] {
	const dir = path.join(getAgentDir(), "agents");
	try {
		fs.mkdirSync(dir, { recursive: true });
	} catch {
		return [];
	}

	let entries: string[];
	try {
		entries = fs.readdirSync(dir);
	} catch {
		return [];
	}
	if (entries.some((e) => e.endsWith(".md"))) return [];

	const created: string[] = [];
	for (const spec of DEFAULT_AGENTS) {
		const file = path.join(dir, `${spec.name}.md`);
		const content = [
			"---",
			`name: ${spec.name}`,
			`description: ${spec.description}`,
			...(spec.tools ? [`tools: ${spec.tools}`] : []),
			"---",
			"",
			spec.body.trim(),
			"",
		].join("\n");
		try {
			fs.writeFileSync(file, content, "utf-8");
			created.push(file);
		} catch {
			/* ignore per-agent failures */
		}
	}
	return created;
}

/* ------------------------------------------------------------------ */
/* Frontmatter editing                                                 */
/* ------------------------------------------------------------------ */

function splitFrontmatter(content: string): { frontmatter: string; body: string } | null {
	const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
	if (!m) return null;
	return { frontmatter: m[1], body: m[2] ?? "" };
}

/**
 * Set (or remove, with undefined) frontmatter keys on an agent markdown file,
 * preserving every other line and the body verbatim.
 */
export async function setAgentFrontmatter(
	filePath: string,
	changes: Record<string, string | undefined>,
): Promise<boolean> {
	return withFileMutationQueue(filePath, async () => {
		let content: string;
		try {
			content = await fs.promises.readFile(filePath, "utf-8");
		} catch {
			return false;
		}

		const header = splitFrontmatter(content);
		if (!header) return false;

		const lines = header.frontmatter.split("\n");
		const updated: string[] = [];
		const applied = new Set<string>();
		for (const line of lines) {
			const m = line.match(/^([A-Za-z0-9_-]+)\s*:/);
			if (m && m[1] in changes) {
				applied.add(m[1]);
				const value = changes[m[1]];
				if (value !== undefined) updated.push(`${m[1]}: ${value}`);
				continue;
			}
			updated.push(line);
		}
		for (const [key, value] of Object.entries(changes)) {
			if (!applied.has(key) && value !== undefined) updated.push(`${key}: ${value}`);
		}

		const next = `---\n${updated.join("\n")}\n---\n${header.body}`;
		await fs.promises.writeFile(filePath, next, "utf-8");
		return true;
	});
}
