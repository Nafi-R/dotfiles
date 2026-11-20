/**
 * Fleet configuration: orchestrator model, agent scope, concurrency.
 * Stored in ~/.pi/agent/fleet.json.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { getAgentDir, withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import type { AgentScope } from "./agents.ts";

export interface FleetConfig {
	/** Model used for task decomposition (provider/id or bare id). Empty = use session model. */
	orchestratorModel?: string;
	agentScope: AgentScope;
	concurrency: number;
	maxParallelTasks: number;
}

export const DEFAULT_CONFIG: FleetConfig = {
	orchestratorModel: undefined,
	agentScope: "user",
	concurrency: 4,
	maxParallelTasks: 8,
};

export function getFleetConfigPath(): string {
	return path.join(getAgentDir(), "fleet.json");
}

export function loadFleetConfig(): FleetConfig {
	try {
		const data = JSON.parse(fs.readFileSync(getFleetConfigPath(), "utf-8"));
		return {
			orchestratorModel:
				typeof data.orchestratorModel === "string" && data.orchestratorModel.trim()
					? data.orchestratorModel.trim()
					: undefined,
			agentScope: ["user", "project", "both"].includes(data.agentScope)
				? (data.agentScope as AgentScope)
				: "user",
			concurrency:
				typeof data.concurrency === "number" && data.concurrency > 0 && data.concurrency <= 16
					? data.concurrency
					: 4,
			maxParallelTasks:
				typeof data.maxParallelTasks === "number" && data.maxParallelTasks > 0 && data.maxParallelTasks <= 32
					? data.maxParallelTasks
					: 8,
		};
	} catch {
		return { ...DEFAULT_CONFIG };
	}
}

export async function saveFleetConfig(config: FleetConfig): Promise<void> {
	const file = getFleetConfigPath();
	await withFileMutationQueue(file, async () => {
		await fs.promises.mkdir(path.dirname(file), { recursive: true });
		await fs.promises.writeFile(file, JSON.stringify(config, null, 2) + "\n", "utf-8");
	});
}
