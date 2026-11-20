/**
 * Fleet mode for pi.
 *
 * Commands:
 *   /fleet <task> [--auto]   Decompose a task into sub-tasks and delegate them
 *                            to fleet subagents (implementer, reviewer,
 *                            researcher, scout, planner, ...).
 *   /fleet-roles             Assign which model powers which agent role.
 *   /fleet-config            Configure orchestrator model, agent scope,
 *                            concurrency.
 *
 * Also registers a `fleet` tool so the main agent can spawn fleets
 * mid-conversation.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { completeSimple, StringEnum, type Model, type TextContent } from "@earendil-works/pi-ai";
import { Type } from "typebox";
import * as path from "node:path";

import {
	discoverAgents,
	ensureDefaultAgents,
	setAgentFrontmatter,
	type AgentConfig,
	type AgentScope,
} from "./agents.ts";
import {
	decomposeTask,
	heuristicPlan,
	renderPlanText,
	topoWaves,
	type FleetPlan,
	type FleetTask,
} from "./orchestrator.ts";
import { loadFleetConfig, saveFleetConfig, type FleetConfig } from "./roles.ts";
import { ModelPickerComponent } from "./model-picker.ts";
import {
	isFailedResult,
	getFinalOutput,
	getResultOutput,
	runTaskGroup,
	formatUsageStats,
	type SingleResult,
	type UsageStats,
} from "./runner.ts";

/* ------------------------------------------------------------------ */
/* Shared context abstraction                                          */
/* ------------------------------------------------------------------ */

interface AuthResult {
	ok: boolean;
	apiKey?: string;
	headers?: Record<string, string>;
	error?: string;
}

interface FleetContext {
	cwd: string;
	model: Model<any> | undefined;
	signal?: AbortSignal;
	hasUI: boolean;
	modelRegistry: {
		getApiKeyAndHeaders(model: Model<any>): Promise<AuthResult>;
		getAvailable(): Model<any>[];
	};
	ui: {
		confirm(title: string, text: string): Promise<boolean>;
		notify(text: string, level?: "info" | "warning" | "error"): void;
		setStatus?(key: string, text?: string): void;
	};
}

export interface FleetTaskResult {
	id: number;
	agent: string;
	summary: string;
	status: "done" | "failed" | "skipped";
	output: string;
	error?: string;
	usage?: UsageStats;
	model?: string;
}

/* ------------------------------------------------------------------ */
/* Orchestrator model call                                             */
/* ------------------------------------------------------------------ */

function resolveModelRef(ref: string, models: Model<any>[]): Model<any> | undefined {
	if (ref.includes("/")) {
		const idx = ref.indexOf("/");
		const provider = ref.slice(0, idx);
		const id = ref.slice(idx + 1);
		return models.find((m) => m.provider === provider && m.id === id);
	}
	const matches = models.filter((m) => m.id === ref);
	return matches.length === 1 ? matches[0] : undefined;
}

async function callOrchestrator(ctx: FleetContext, systemPrompt: string, userPrompt: string): Promise<string | null> {
	const config = loadFleetConfig();
	let model: Model<any> | undefined = ctx.model;
	if (config.orchestratorModel) {
		const resolved = resolveModelRef(config.orchestratorModel, ctx.modelRegistry.getAvailable());
		if (resolved) model = resolved;
	}
	if (!model) return null;

	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model).catch(() => ({ ok: false }));
	if (!auth.ok) return null;

	try {
		const msg = await completeSimple(
			model,
			{
				systemPrompt,
				messages: [{ role: "user", content: [{ type: "text", text: userPrompt }] }],
			},
			{
				apiKey: auth.apiKey,
				headers: auth.headers,
				signal: ctx.signal,
				maxTokens: 2048,
			},
		);
		if (msg.stopReason === "error" || msg.stopReason === "aborted") return null;
		const text = msg.content
			.filter((p): p is TextContent => p.type === "text")
			.map((p) => p.text)
			.join("\n")
			.trim();
		return text || null;
	} catch {
		return null;
	}
}

/* ------------------------------------------------------------------ */
/* Decomposition + execution                                           */
/* ------------------------------------------------------------------ */

async function decomposeFleet(
	task: string,
	ctx: FleetContext,
	opts: { auto?: boolean; agentScope?: AgentScope },
): Promise<{ plan: FleetPlan; agents: AgentConfig[]; config: FleetConfig }> {
	const created = ensureDefaultAgents();
	if (created.length > 0) {
		ctx.ui.notify(
			`Created default fleet agents: ${created.map((f) => path.basename(f, ".md")).join(", ")}`,
			"info",
		);
	}

	const config = loadFleetConfig();
	const scope = opts.agentScope ?? config.agentScope;
	const discovery = discoverAgents(ctx.cwd, scope);
	const agents = discovery.agents;

	if (agents.length === 0) {
		const userAgents = discoverAgents(ctx.cwd, "user").agents;
		const hint =
			config.agentScope !== "user" && userAgents.length > 0
				? ` Agent scope is "${config.agentScope}" but this repo has no project agents. Run /fleet-config scope user (or both) to use the agents in ~/.pi/agent/agents.`
				: " Create agent definitions in ~/.pi/agent/agents/*.md.";
		throw new Error(`No fleet agents found.${hint}`);
	}

	if ((scope === "project" || scope === "both") && ctx.hasUI && !opts.auto) {
		const projectAgents = agents.filter((a) => a.source === "project");
		if (projectAgents.length > 0) {
			const ok = await ctx.ui.confirm(
				"Run project-local agents?",
				`Agents: ${projectAgents.map((a) => a.name).join(", ")}\n\nProject agents are repo-controlled. Only continue for trusted repositories.`,
			);
			if (!ok) throw new Error("Cancelled: project-local agents not approved.");
		}
	}

	ctx.ui.setStatus?.("fleet", "Decomposing task...");
	let plan: FleetPlan;
	try {
		plan = await decomposeTask(task, agents, (sys, user) => callOrchestrator(ctx, sys, user));
	} finally {
		ctx.ui.setStatus?.("fleet", undefined);
	}

	if (plan.tasks.length === 0) {
		// Nothing decomposable (e.g. no agents) - try a direct implementation task
		const direct = heuristicPlan(task, agents);
		if (direct.length === 0) throw new Error("No fleet agents available to run this task.");
		plan = { task, tasks: direct, source: "heuristic" };
	}

	return { plan, agents, config };
}

async function executePlan(
	plan: FleetPlan,
	agents: AgentConfig[],
	config: FleetConfig,
	ctx: FleetContext,
	emitStatus: (text: string) => void,
): Promise<FleetTaskResult[]> {
	const byId = new Map(plan.tasks.map((t) => [t.id, t]));
	const outputs = new Map<number, string>();
	const failed = new Set<number>();
	const results: FleetTaskResult[] = plan.tasks.map((t) => ({
		id: t.id,
		agent: t.agent,
		summary: t.summary,
		status: "skipped",
		output: "",
	}));

	const waves = topoWaves(plan.tasks);

	for (let w = 0; w < waves.length; w++) {
		const wave = waves[w];
		emitStatus(
			`Fleet wave ${w + 1}/${waves.length}: ${wave.map((id) => byId.get(id)?.agent).join(", ")}`,
		);

		const runs: { task: FleetTask; prompt: string }[] = [];
		for (const id of wave) {
			const t = byId.get(id)!;
			const rec = results.find((r) => r.id === id)!;

			let depFailed = false;
			let depContext = "";
			for (const d of t.dependsOn) {
				const depOut = outputs.get(d);
				const depTask = byId.get(d);
				if (depOut === undefined || failed.has(d) || !depTask) {
					depFailed = true;
					break;
				}
				depContext += `\n\n## Output from "${depTask.agent}" (step ${d}: ${depTask.summary})\n${depOut}`;
			}

			if (depFailed) {
				rec.status = "skipped";
				rec.error = "skipped: a dependency failed";
				failed.add(id);
				continue;
			}

			let prompt = t.prompt;
			if (t.dependsOn.length > 0) {
				prompt = prompt.replace(/\{previous\}/g, depContext.trim());
				prompt += depContext;
			}
			runs.push({ task: t, prompt });
		}

		if (runs.length === 0) continue;

		// Enforce the max-parallel-tasks cap: split oversized waves into chunks
		const chunks: Array<typeof runs> = [];
		for (let i = 0; i < runs.length; i += config.maxParallelTasks) {
			chunks.push(runs.slice(i, i + config.maxParallelTasks));
		}

		for (const chunk of chunks) {
			const groupResults = await runTaskGroup(
				chunk.map((r) => ({ agent: r.task.agent, task: r.prompt })),
				agents,
				ctx.cwd,
				ctx.signal,
				config.concurrency,
			);

			chunk.forEach((r, i) => {
				const res = groupResults[i];
				const rec = results.find((x) => x.id === r.task.id)!;
				if (isFailedResult(res)) {
					rec.status = "failed";
					rec.error = getResultOutput(res);
					rec.usage = res.usage;
					rec.model = res.model;
					failed.add(r.task.id);
				} else {
					rec.status = "done";
					rec.output = getFinalOutput(res.messages);
					rec.usage = res.usage;
					rec.model = res.model;
					outputs.set(r.task.id, rec.output);
				}
			});
		}
	}

	return results;
}

/* ------------------------------------------------------------------ */
/* Reporting / rendering                                               */
/* ------------------------------------------------------------------ */

function truncate(text: string, max: number): string {
	const t = text ?? "";
	return t.length > max ? `${t.slice(0, max - 3)}...` : t;
}

function truncateOutput(text: string, max = 4000): string {
	if (text.length <= max) return text;
	return `${text.slice(0, max)}\n\n[Output truncated in summary]`;
}

function reportStatusLine(results: FleetTaskResult[]): string {
	const done = results.filter((r) => r.status === "done").length;
	const failed = results.filter((r) => r.status === "failed").length;
	const skipped = results.filter((r) => r.status === "skipped").length;
	if (failed > 0) return `${done} ok, ${failed} failed, ${skipped} skipped`;
	return `${done}/${results.length} done`;
}

function renderFleetReport(
	plan: FleetPlan,
	results: FleetTaskResult[],
	agents: AgentConfig[],
	expanded: boolean,
	theme: any,
): Text | Container {
	const mdTheme = getMarkdownTheme();
	const statusLine = reportStatusLine(results);
	const totalUsage: UsageStats = {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		cost: 0,
		contextTokens: 0,
		turns: 0,
	};
	for (const r of results) {
		if (r.usage) {
			totalUsage.input += r.usage.input;
			totalUsage.output += r.usage.output;
			totalUsage.cacheRead += r.usage.cacheRead;
			totalUsage.cacheWrite += r.usage.cacheWrite;
			totalUsage.cost += r.usage.cost;
			totalUsage.turns += r.usage.turns;
		}
	}

	const icon = (r: FleetTaskResult) =>
		r.status === "done"
			? theme.fg("success", "✓")
			: r.status === "failed"
				? theme.fg("error", "✗")
				: theme.fg("warning", "⊘");

	const modelTagFor = (r: FleetTaskResult) => {
		const agent = agents.find((a) => a.name === r.agent);
		return agent?.model ? ` [${agent.model}]` : "";
	};

	if (!expanded) {
		let text =
			theme.fg("toolTitle", theme.bold("⚑ fleet ")) +
			theme.fg("accent", statusLine) +
			theme.fg("muted", ` [${plan.source}]`);
		for (const r of results) {
			text += `\n${icon(r)} ${theme.fg("accent", `${r.id}. ${r.agent}`)}${theme.fg("dim", ` — ${truncate(r.summary, 60)}`)}${theme.fg("muted", modelTagFor(r))}`;
		}
		const usageStr = formatUsageStats(totalUsage);
		if (usageStr) text += `\n${theme.fg("dim", `total: ${usageStr}`)}`;
		text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
		return new Text(text, 0, 0);
	}

	const container = new Container();
	container.addChild(
		new Text(
			theme.fg("toolTitle", theme.bold("⚑ fleet ")) +
				theme.fg("accent", statusLine) +
				theme.fg("muted", ` [${plan.source}]`),
			0,
			0,
		),
	);
	for (const r of results) {
		container.addChild(new Spacer(1));
		container.addChild(
			new Text(
				`${icon(r)} ${theme.fg("accent", `${r.id}. ${r.agent}`)}${theme.fg("dim", ` — ${r.summary}`)}${theme.fg("muted", modelTagFor(r))}`,
				0,
				0,
			),
		);
		if (r.status === "failed" && r.error) {
			container.addChild(new Text(theme.fg("error", truncate(r.error, 2000)), 0, 0));
		}
		if (r.status === "skipped" && r.error) {
			container.addChild(new Text(theme.fg("warning", r.error), 0, 0));
		}
		if (r.status === "done" && r.output) {
			container.addChild(new Spacer(1));
			container.addChild(new Markdown(r.output.trim(), 0, 0, mdTheme));
		}
		if (r.usage) {
			const usageStr = formatUsageStats(r.usage, r.model);
			if (usageStr) container.addChild(new Text(theme.fg("dim", usageStr), 0, 0));
		}
	}
	const usageStr = formatUsageStats(totalUsage);
	if (usageStr) {
		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", `total: ${usageStr}`), 0, 0));
	}
	return container;
}

/* ------------------------------------------------------------------ */
/* Extension entry point                                               */
/* ------------------------------------------------------------------ */

export default function (pi: ExtensionAPI) {
	/* ------------------------------ /fleet ------------------------------ */

	pi.registerCommand("fleet", {
		description: "Decompose a task into sub-tasks and delegate them to fleet subagents",
		handler: async (args, ctx) => {
			let auto = false;
			let task = args.replace(/^\s*--auto\s*/, (m) => {
				auto = true;
				return "";
			}).replace(/\s+--auto\s*$/, (m) => {
				auto = true;
				return "";
			}).trim();
			if (!task) {
				ctx.ui.notify("Usage: /fleet <task> [--auto]", "warning");
				return;
			}

			try {
				const { plan, agents, config } = await decomposeFleet(task, ctx, { auto });

				pi.appendEntry("fleet-plan", {
					task,
					plan,
					agents: agents.map((a) => ({ name: a.name, model: a.model ?? null })),
				});

				if (ctx.hasUI && !auto) {
					const ok = await ctx.ui.confirm("Fleet plan — execute?", renderPlanText(plan));
					if (!ok) {
						ctx.ui.notify("Fleet cancelled", "warning");
						return;
					}
				}

				const emitStatus = (text: string) => ctx.ui.setStatus("fleet", text);
				const results = await executePlan(plan, agents, config, ctx, emitStatus);
				ctx.ui.setStatus("fleet", undefined);

				pi.appendEntry("fleet-report", {
					plan,
					results,
					agents: agents.map((a) => ({ name: a.name, model: a.model ?? null })),
				});

				const failed = results.filter((r) => r.status === "failed").length;
				ctx.ui.notify(
					`Fleet done: ${reportStatusLine(results)}`,
					failed > 0 ? "warning" : "info",
				);
			} catch (err: any) {
				ctx.ui.notify(`Fleet error: ${err?.message ?? err}`, "error");
			} finally {
				ctx.ui.setStatus("fleet", undefined);
			}
		},
	});

	/* --------------------------- /fleet-roles --------------------------- */

	/**
	 * Searchable model picker mirroring the built-in /model selector.
	 * Returns "" for session default, "__custom__" for the custom-id entry,
	 * a "provider/id" reference, or undefined/null when cancelled.
	 */
	const pickModel = async (
		ctx: ExtensionContext,
		title: string,
		currentRef: string | undefined,
	): Promise<string | null> => {
		const models = ctx.modelRegistry.getAvailable();
		return ctx.ui.custom<string | null>((_tui, theme, keybindings, done) =>
			new ModelPickerComponent(
				title,
				models,
				currentRef,
				theme,
				keybindings,
				(v) => done(v),
				() => done(null),
			),
		);
	};

	const pickAgentModel = async (ctx: ExtensionContext, agent: AgentConfig) => {
		const choice = await pickModel(
			ctx,
			`Model for "${agent.name}" (currently ${agent.model ?? "default"})`,
			agent.model,
		);
		if (choice === undefined || choice === null) return;

		let modelRef: string | undefined;
		if (choice === "") {
			modelRef = undefined;
		} else if (choice === "__custom__") {
			const entered = await ctx.ui.input("Model id (provider/modelId or bare id):", agent.model ?? "");
			if (entered === undefined) return;
			modelRef = entered.trim() || undefined;
		} else {
			modelRef = choice;
		}

		const ok = await setAgentFrontmatter(agent.filePath, { model: modelRef });
		if (!ok) {
			ctx.ui.notify(`Failed to update ${agent.name}`, "error");
			return;
		}
		ctx.ui.notify(`${agent.name} → ${modelRef ?? "default"}`, "info");
	};

	pi.registerCommand("fleet-roles", {
		description: "Assign models to fleet agent roles (implementer, reviewer, researcher, ...)",
		getArgumentCompletions: (prefix: string) => {
			const config = loadFleetConfig();
			const { agents } = discoverAgents(process.cwd(), config.agentScope);
			const items = [
				{ value: "list", label: "list" },
				...agents.map((a) => ({ value: a.name, label: a.name })),
			].filter((i) => i.value.startsWith(prefix));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			ensureDefaultAgents();
			const config = loadFleetConfig();
			// The roles editor always shows every discoverable agent (user +
			// current project), independent of the execution scope, so a
			// "project"-only run scope can never hide agents from the editor.
			const { agents } = discoverAgents(ctx.cwd, "both");
			const trimmed = args.trim();
			const fmt = (a: AgentConfig) => `${a.name} (${a.source}) → ${a.model ?? "(default)"}`;

			// Non-interactive forms
			if (trimmed === "list") {
				const session = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "none";
				const lines = [`Session model: ${session}`, ""];
				for (const a of agents) {
					lines.push(fmt(a));
				}
				ctx.ui.notify(lines.join("\n"), "info");
				return;
			}

			const parts = trimmed.split(/\s+/);
			if (parts.length === 2) {
				const [agentName, modelRef] = parts;
				const agent = agents.find((a) => a.name === agentName);
				if (!agent) {
					ctx.ui.notify(`Unknown agent "${agentName}". Available: ${agents.map((a) => a.name).join(", ")}`, "error");
					return;
				}
				const ok = await setAgentFrontmatter(agent.filePath, {
					model: modelRef === "default" ? undefined : modelRef,
				});
				ctx.ui.notify(
					ok
						? `${agent.name} → ${modelRef === "default" ? "default" : modelRef}`
						: `Failed to update ${agent.name}`,
					ok ? "info" : "error",
				);
				return;
			}
			if (trimmed) {
				ctx.ui.notify(
					"Usage: /fleet-roles [list | <agent> <model|default>]  (no args = interactive)",
					"warning",
				);
				return;
			}

			if (!ctx.hasUI) {
				ctx.ui.notify("Interactive /fleet-roles requires the TUI. Use /fleet-roles list or /fleet-roles <agent> <model>.", "warning");
				return;
			}

			// Interactive: loop until the user picks "(done)"
			while (true) {
				// Re-discover every iteration so model assignments written to the
				// agent files are reflected in the list immediately.
				const { agents: currentAgents } = discoverAgents(ctx.cwd, "both");
				const session = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "none";
				const scopeNote =
					config.agentScope === "user" ? "" : ` (run scope: ${config.agentScope})`;
				const agentItems = currentAgents.map(fmt);
				const doneItem = `(done — session model: ${session})`;
				const pick = await ctx.ui.select(
					`Fleet roles — pick an agent to assign a model${scopeNote}:`,
					[...agentItems, doneItem],
				);
				if (!pick || pick === doneItem) return;
				const agent = currentAgents.find((a) => fmt(a) === pick);
				if (!agent) continue;
				await pickAgentModel(ctx, agent);
			}
		},
	});

	/* --------------------------- /fleet-config -------------------------- */

	pi.registerCommand("fleet-config", {
		description: "Configure fleet: orchestrator model, agent scope, concurrency",
		handler: async (args, ctx) => {
			const config = loadFleetConfig();
			const trimmed = args.trim();
			const parts = trimmed.split(/\s+/);

			const apply = async (key: string, value: string): Promise<boolean> => {
				if (key === "orchestrator") {
					config.orchestratorModel = value === "default" ? undefined : value;
					await saveFleetConfig(config);
					ctx.ui.notify(`Orchestrator model → ${value === "default" ? "session model" : value}`, "info");
					return true;
				}
				if (key === "scope") {
					if (!["user", "project", "both"].includes(value)) {
						ctx.ui.notify("scope must be user | project | both", "error");
						return true;
					}
					config.agentScope = value as AgentScope;
					await saveFleetConfig(config);
					ctx.ui.notify(`Agent scope → ${value}`, "info");
					return true;
				}
				if (key === "concurrency" || key === "max-parallel") {
					const max = key === "concurrency" ? 16 : 32;
					const n = parseInt(value, 10);
					if (isNaN(n) || n < 1 || n > max) {
						ctx.ui.notify(`${key} must be 1-${max}`, "error");
						return true;
					}
					if (key === "concurrency") config.concurrency = n;
					else config.maxParallelTasks = n;
					await saveFleetConfig(config);
					ctx.ui.notify(`${key} → ${n}`, "info");
					return true;
				}
				return false;
			};

			if (parts.length >= 2 && (await apply(parts[0], parts[1]))) return;
			if (trimmed === "show" || !ctx.hasUI) {
				const session = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "none";
				const lines = [
					`Orchestrator model: ${config.orchestratorModel ?? `(session model: ${session})`}`,
					`Agent scope: ${config.agentScope}`,
					`Concurrency: ${config.concurrency}`,
					`Max parallel tasks: ${config.maxParallelTasks}`,
				];
				ctx.ui.notify(lines.join("\n"), "info");
				return;
			}
			if (trimmed) {
				ctx.ui.notify(
					"Usage: /fleet-config [show | orchestrator <model|default> | scope <user|project|both> | concurrency <n> | max-parallel <n>]",
					"warning",
				);
				return;
			}

			// Interactive loop
			while (true) {
				const session = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "none";
				const items = [
					`Orchestrator model: ${config.orchestratorModel ?? `(session: ${session})`}`,
					`Agent scope: ${config.agentScope}`,
					`Concurrency: ${config.concurrency}`,
					`Max parallel tasks: ${config.maxParallelTasks}`,
					"(done)",
				];
				const pick = await ctx.ui.select("Fleet settings — pick one to change:", items);
				if (!pick || pick === "(done)") return;

				if (pick.startsWith("Orchestrator model")) {
					const choice = await pickModel(ctx, "Orchestrator model", config.orchestratorModel);
					if (choice === undefined || choice === null) continue;
					if (choice === "__custom__") {
						const entered = await ctx.ui.input(
							"Orchestrator model id (provider/modelId or bare id):",
						config.orchestratorModel ?? "",
					);
					if (entered === undefined) continue;
					config.orchestratorModel = entered.trim() || undefined;
				} else {
					config.orchestratorModel = choice === "" ? undefined : choice;
				}
				await saveFleetConfig(config);
				ctx.ui.notify(`Orchestrator model → ${config.orchestratorModel ?? "session model"}`, "info");
			} else if (pick.startsWith("Agent scope")) {
					const choice = await ctx.ui.select("Agent scope:", ["user", "project", "both"]);
					if (!choice) continue;
					config.agentScope = choice as AgentScope;
					await saveFleetConfig(config);
					ctx.ui.notify(`Agent scope → ${choice}`, "info");
				} else if (pick.startsWith("Concurrency")) {
					const entered = await ctx.ui.input("Concurrency (1-16):", String(config.concurrency));
					const n = parseInt(entered ?? "", 10);
					if (entered !== undefined && !isNaN(n) && n >= 1 && n <= 16) {
						config.concurrency = n;
						await saveFleetConfig(config);
						ctx.ui.notify(`Concurrency → ${n}`, "info");
					}
				} else if (pick.startsWith("Max parallel tasks")) {
					const entered = await ctx.ui.input("Max parallel tasks (1-32):", String(config.maxParallelTasks));
					const n = parseInt(entered ?? "", 10);
					if (entered !== undefined && !isNaN(n) && n >= 1 && n <= 32) {
						config.maxParallelTasks = n;
						await saveFleetConfig(config);
						ctx.ui.notify(`Max parallel tasks → ${n}`, "info");
					}
				}
			}
		},
	});

	/* ------------------------------ fleet tool -------------------------- */

	pi.registerTool({
		name: "fleet",
		label: "Fleet",
		description: [
			"Decompose a task into sub-tasks and delegate them to specialized fleet agents",
			"(implementer, reviewer, researcher, scout, planner) running as isolated subagent processes.",
			"Independent sub-tasks run in parallel; dependent ones wait for earlier output.",
		].join(" "),
		promptSnippet: "Decompose a task into parallel sub-tasks and delegate them to fleet subagents",
		promptGuidelines: [
			"Use fleet when a task is large enough to benefit from decomposition into parallel specialized subtasks (research, implementation, review).",
		],
		parameters: Type.Object({
			task: Type.String({ description: "The task to decompose and execute" }),
			auto: Type.Optional(
				Type.Boolean({ description: "Skip confirmation prompts. Default: true for tool use.", default: true }),
			),
			agentScope: Type.Optional(
				StringEnum(["user", "project", "both"] as const, {
					description: "Agent directory scope",
					default: "user",
				}),
			),
		}),
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const fleetCtx: FleetContext = {
				cwd: ctx.cwd,
				model: ctx.model,
				signal,
				hasUI: ctx.hasUI,
				modelRegistry: ctx.modelRegistry as any,
				ui: ctx.ui as any,
			};

			const emitStatus = (text: string) => {
				onUpdate?.({ content: [{ type: "text", text }], details: { phase: text } });
			};

			const { plan, agents, config } = await decomposeFleet(params.task, fleetCtx, {
				auto: params.auto ?? true,
				agentScope: params.agentScope,
			});
			const results = await executePlan(plan, agents, config, fleetCtx, emitStatus);

			const body = [
				`Fleet: ${reportStatusLine(results)} (${plan.source === "llm" ? "orchestrated" : "heuristic"} plan)`,
				"",
				...results.map((r) => {
					const head = `### ${r.id}. ${r.agent} — ${r.summary} [${r.status}]`;
					if (r.status === "failed") return `${head}\n\n${truncateOutput(r.error ?? "(no output)", 4000)}`;
					if (r.status === "done") return `${head}\n\n${truncateOutput(r.output || "(no output)", 4000)}`;
					return `${head}\n\n${r.error ?? "(skipped)"}`;
				}),
			].join("\n\n");

			return {
				content: [{ type: "text", text: body }],
				details: { plan, results, agents: agents.map((a) => ({ name: a.name, model: a.model ?? null })) },
			};
		},
		renderCall(args, theme) {
			const preview = (args.task ?? "").length > 60 ? `${(args.task ?? "").slice(0, 60)}...` : (args.task ?? "");
			return new Text(
				theme.fg("toolTitle", theme.bold("fleet ")) +
					theme.fg("accent", `⚑ ${preview}`) +
					theme.fg("muted", ` [${args.agentScope ?? "user"}]`),
				0,
				0,
			);
		},
		renderResult(result, { expanded, isPartial }, theme) {
			const details = result.details as
				| { plan?: FleetPlan; results?: FleetTaskResult[]; agents?: Array<{ name: string; model: string | null }> }
				| undefined;
			if (isPartial || !details?.results || !details.plan) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(running...)", 0, 0);
			}
			const agents: AgentConfig[] = (details.agents ?? []).map((a) => ({
				name: a.name,
				description: "",
				model: a.model ?? undefined,
				systemPrompt: "",
				source: "user",
				filePath: "",
			}));
			return renderFleetReport(details.plan, details.results, agents, expanded, theme);
		},
	});

	/* --------------------------- entry renderers ------------------------ */

	pi.registerEntryRenderer("fleet-plan", (entry, { expanded }, theme) => {
		const data = entry.data as { task?: string; plan?: FleetPlan; agents?: Array<{ name: string; model: string | null }> };
		const plan = data.plan;
		if (!plan) return new Text(theme.fg("muted", "(fleet plan)"), 0, 0);

		const lines: string[] = [theme.fg("toolTitle", theme.bold("⚑ Fleet plan"))];
		lines.push(theme.fg("dim", `Task: ${truncate(data.task ?? plan.task, 140)}`));
		lines.push(theme.fg("muted", `Decomposition: ${plan.source === "llm" ? "orchestrator LLM" : "fallback heuristic"}`));
		lines.push("");
		for (const t of plan.tasks) {
			const agent = data.agents?.find((a) => a.name === t.agent);
			const modelTag = agent?.model ? ` [${agent.model}]` : "";
			const deps = t.dependsOn.length > 0 ? ` ${theme.fg("muted", `← ${t.dependsOn.join(", ")}`)}` : "";
			lines.push(
				theme.fg("accent", `${t.id}. `) +
					theme.fg("toolTitle", t.agent) +
					theme.fg("dim", ` — ${truncate(t.summary, 70)}`) +
					theme.fg("muted", modelTag) +
					deps,
			);
			if (expanded) lines.push(theme.fg("dim", truncate(t.prompt, 500)));
		}
		return new Text(lines.join("\n"), 0, 0);
	});

	pi.registerEntryRenderer("fleet-report", (entry, { expanded }, theme) => {
		const data = entry.data as { plan?: FleetPlan; results?: FleetTaskResult[]; agents?: Array<{ name: string; model: string | null }> };
		if (!data.plan || !data.results) return new Text(theme.fg("muted", "(fleet report)"), 0, 0);
		const agents: AgentConfig[] = (data.agents ?? []).map((a) => ({
			name: a.name,
			description: "",
			model: a.model ?? undefined,
			systemPrompt: "",
			source: "user",
			filePath: "",
		}));
		return renderFleetReport(data.plan, data.results, agents, expanded, theme);
	});
}
