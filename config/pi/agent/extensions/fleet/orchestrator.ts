/**
 * Fleet orchestrator: decomposes a high-level task into sub-tasks, assigns
 * each sub-task to the best available agent, and schedules them as a DAG
 * (parallel "waves" of independent tasks).
 */

import type { AgentConfig } from "./agents.ts";

export interface FleetTask {
	id: number;
	agent: string;
	summary: string;
	prompt: string;
	dependsOn: number[];
}

export interface FleetPlan {
	task: string;
	tasks: FleetTask[];
	source: "llm" | "heuristic";
}

export const ROLE_ALIASES: Record<string, string[]> = {
	implementer: ["implementer", "worker", "coder", "developer", "engineer", "implement", "code"],
	reviewer: ["reviewer", "review", "critic", "qa"],
	researcher: ["researcher", "research", "investigator"],
	planner: ["planner", "plan", "architect"],
	scout: ["scout", "recon", "explorer"],
};

export function resolveAgentName(name: string, agents: AgentConfig[]): string | null {
	const n = name.trim().toLowerCase();
	if (!n) return null;

	const exact = agents.find((a) => a.name === name.trim());
	if (exact) return exact.name;

	const lower = agents.find((a) => a.name.toLowerCase() === n);
	if (lower) return lower.name;

	for (const [role, aliases] of Object.entries(ROLE_ALIASES)) {
		if (aliases.includes(n) || aliases.some((a) => n.includes(a))) {
			const agent = agents.find((a) => a.name.toLowerCase() === role);
			if (agent) return agent.name;
		}
	}

	const fuzzy = agents.find(
		(a) => a.name.toLowerCase().includes(n) || n.includes(a.name.toLowerCase()),
	);
	if (fuzzy) return fuzzy.name;

	// Fall back to the first full-capability agent (write-capable tools or unrestricted)
	const fallback = agents.find(
		(a) => !a.tools || a.tools.some((t) => ["edit", "write", "bash"].includes(t)),
	);
	if (fallback) return fallback.name;
	return agents[0]?.name ?? null;
}

/* ------------------------------------------------------------------ */
/* LLM decomposition                                                   */
/* ------------------------------------------------------------------ */

function extractJsonArray(text: string): any[] | null {
	const cleaned = text.replace(/```(?:json)?/gi, "").trim();
	const start = cleaned.indexOf("[");
	const end = cleaned.lastIndexOf("]");
	if (start < 0 || end <= start) return null;

	let slice = cleaned.slice(start, end + 1);
	try {
		return JSON.parse(slice);
	} catch {
		/* fall through */
	}
	try {
		return JSON.parse(slice.replace(/,\s*([}\]])/g, "$1"));
	} catch {
		return null;
	}
}

function truncate(text: string, max: number): string {
	return text.length > max ? `${text.slice(0, max - 3)}...` : text;
}

function resolveDepId(dep: any, raw: any[], map: Map<number, number>): number | undefined {
	if (typeof dep === "string" && /^\d+$/.test(dep.trim())) {
		return resolveDepId(parseInt(dep.trim(), 10), raw, map);
	}
	if (typeof dep === "number") {
		const idx = raw.findIndex((it: any) => it?.id === dep);
		if (idx >= 0) return map.get(idx);
		return map.get(dep);
	}
	return undefined;
}

/**
 * Validate and normalize an LLM-produced plan array.
 * Renumbers ids sequentially, drops unknown agents, resolves role aliases,
 * and keeps only valid dependency references.
 */
export function sanitizePlan(raw: any[], agents: AgentConfig[]): FleetTask[] | null {
	if (!Array.isArray(raw) || raw.length === 0) return null;

	const tasks: FleetTask[] = [];
	const newIdByRawIndex = new Map<number, number>();

	for (let i = 0; i < raw.length; i++) {
		const item = raw[i];
		if (!item || typeof item !== "object") continue;

		const agentName = resolveAgentName(String(item.agent ?? ""), agents);
		const taskText = typeof item.task === "string" && item.task.trim() ? item.task.trim() : "";
		if (!agentName || !taskText) continue;

		const newId = tasks.length + 1;
		newIdByRawIndex.set(i, newId);
		tasks.push({
			id: newId,
			agent: agentName,
			summary:
				typeof item.summary === "string" && item.summary.trim()
					? item.summary.trim()
					: truncate(taskText, 60),
			prompt: taskText,
			dependsOn: [],
		});
	}

	for (let i = 0; i < raw.length; i++) {
		const newId = newIdByRawIndex.get(i);
		if (newId === undefined) continue;
		const task = tasks.find((t) => t.id === newId)!;
		const deps = Array.isArray(raw[i].dependsOn) ? raw[i].dependsOn : [];
		for (const d of deps) {
			const depNewId = resolveDepId(d, raw, newIdByRawIndex);
			if (depNewId !== undefined && depNewId !== newId && !task.dependsOn.includes(depNewId)) {
				task.dependsOn.push(depNewId);
			}
		}
	}

	return tasks.length > 0 ? tasks : null;
}

export function buildOrchestratorPrompt(task: string, agents: AgentConfig[]): { system: string; user: string } {
	const agentList = agents
		.map((a) => `- ${a.name}: ${a.description}${a.model ? ` (model: ${a.model})` : ""}`)
		.join("\n");

	const system = [
		"You are the orchestrator of a fleet of specialized coding agents.",
		"Decompose the user's task into a small set (2-6) of sub-tasks, each assigned to exactly one agent.",
		"Prefer parallelizing independent sub-tasks. Use dependsOn only when a task truly needs",
		"another task's output (e.g. review depends on implementation; implementation may depend on scout context).",
		"Return ONLY a JSON array. No markdown fences, no commentary.",
	].join("\n");

	const user = [
		`Available agents:\n${agentList}`,
		"",
		'Return strictly: [ { "id": 1, "agent": "<agent name>", "summary": "<short label>", "task": "<detailed instructions for the subagent>", "dependsOn": [] }, ... ]',
		"",
		`Task to decompose:\n${task}`,
	].join("\n");

	return { system, user };
}

/* ------------------------------------------------------------------ */
/* Heuristic fallback                                                  */
/* ------------------------------------------------------------------ */

export function heuristicPlan(task: string, agents: AgentConfig[]): FleetTask[] {
	const tasks: FleetTask[] = [];
	const byRole = (roles: string[]) => {
		const agent = agents.find((a) => roles.includes(a.name.toLowerCase()));
		return agent?.name ?? null;
	};

	const scout = byRole(["scout"]);
	const implementer = byRole(["implementer", "worker"]);
	const reviewer = byRole(["reviewer"]);

	let scoutId: number | undefined;
	if (scout) {
		scoutId = tasks.length + 1;
		tasks.push({
			id: scoutId,
			agent: scout,
			summary: "Gather codebase context",
			prompt: [
				"Investigate the codebase and gather all context relevant to the task below.",
				"Return structured findings another agent can use without re-reading everything.",
				"",
				`Task: ${task}`,
			].join("\n"),
			dependsOn: [],
		});
	}

	let implementerId: number | undefined;
	if (implementer) {
		implementerId = tasks.length + 1;
		tasks.push({
			id: implementerId,
			agent: implementer,
			summary: "Implement",
			prompt: [
				"Complete the following task. Use the context from earlier steps when available.",
				"",
				`Task: ${task}`,
			].join("\n"),
			dependsOn: scoutId !== undefined ? [scoutId] : [],
		});
	}

	if (reviewer) {
		const dep = implementerId ?? scoutId;
		tasks.push({
			id: tasks.length + 1,
			agent: reviewer,
			summary: "Review the work",
			prompt: [
				"Review the work produced in the previous step for the task below.",
				"Report bugs, issues, and suggestions with specific file paths and line numbers.",
				"",
				`Task: ${task}`,
			].join("\n"),
			dependsOn: dep !== undefined ? [dep] : [],
		});
	}

	return tasks;
}

/* ------------------------------------------------------------------ */
/* Orchestration entry point                                           */
/* ------------------------------------------------------------------ */

export type ModelCaller = (systemPrompt: string, userPrompt: string) => Promise<string | null>;

export async function decomposeTask(
	task: string,
	agents: AgentConfig[],
	callModel: ModelCaller,
): Promise<FleetPlan> {
	const { system, user } = buildOrchestratorPrompt(task, agents);
	const response = await callModel(system, user);
	if (response) {
		const raw = extractJsonArray(response);
		const tasks = raw ? sanitizePlan(raw, agents) : null;
		if (tasks) return { task, tasks, source: "llm" };
	}
	return { task, tasks: heuristicPlan(task, agents), source: "heuristic" };
}

/* ------------------------------------------------------------------ */
/* DAG scheduling                                                      */
/* ------------------------------------------------------------------ */

/**
 * Group tasks into parallel waves: tasks in wave n only depend on tasks
 * in waves < n. Cycles are broken by dropping the offending dependency.
 */
export function topoWaves(tasks: FleetTask[]): number[][] {
	const byId = new Map(tasks.map((t) => [t.id, t]));
	const remaining = new Set(tasks.map((t) => t.id));
	const waves: number[][] = [];

	while (remaining.size > 0) {
		const wave = [...remaining].filter((id) => {
			const t = byId.get(id)!;
			return t.dependsOn.every((d) => !remaining.has(d));
		});
		if (wave.length === 0) {
			// cycle: pick one task and drop its remaining dependencies
			const pick = [...remaining][0];
			const t = byId.get(pick)!;
			t.dependsOn = t.dependsOn.filter((d) => !remaining.has(d));
			wave.push(pick);
		}
		for (const id of wave) remaining.delete(id);
		waves.push(wave);
	}
	return waves;
}

export function renderPlanText(plan: FleetPlan): string {
	const lines: string[] = [
		`Task: ${plan.task}`,
		`Decomposition: ${plan.source === "llm" ? "orchestrator LLM" : "fallback heuristic"}`,
		"",
	];
	for (const t of plan.tasks) {
		const deps = t.dependsOn.length > 0 ? ` (after step ${t.dependsOn.join(", ")})` : "";
		lines.push(`${t.id}. [${t.agent}] ${t.summary}${deps}`);
	}
	return lines.join("\n");
}
