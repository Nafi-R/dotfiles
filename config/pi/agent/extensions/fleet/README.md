# Fleet mode for pi

Fleet mode decomposes a high-level task into sub-tasks and delegates them to
specialized subagents, each running in its own isolated `pi` process.

```
/fleet "add Redis caching to the session store"    # full orchestration
/fleet <task> --auto                                # skip the confirmation prompt
/fleet-roles                                        # assign models to roles (interactive)
/fleet-roles list                                   # show current assignments
/fleet-roles implementer anthropic/claude-sonnet-4-5   # assign a model non-interactively
/fleet-roles reviewer default                       # clear a role's model
/fleet-config                                       # orchestrator model, scope, concurrency
```

The model pickers in `/fleet-roles` and `/fleet-config` mirror the built-in
`/model` selector: a search box on top (fuzzy-filter by provider/id/name),
`id [provider]` rows with a ✓ on the currently-assigned model, scroll
indicator, and the selected model's display name. ↑/↓ navigate, Enter
selects, Esc cancels.

`/fleet-roles` always lists every discoverable agent (user + current project,
project overriding on name clash) regardless of the configured run scope — the
scope only affects which agents actually *run* in `/fleet`. The dialog title
notes the run scope when it is not `user`.

The main agent can also call the `fleet` tool mid-conversation.

## How it works

1. **Decompose** — an orchestrator LLM (the session model, or the one set via
   `/fleet-config orchestrator`) breaks the task into 2–6 sub-tasks, each
   assigned to the best available agent, with explicit `dependsOn` edges.
   If the model call fails or returns garbage, a heuristic fallback is used
   (scout → implementer → reviewer).
2. **Plan** — the plan is rendered as a card in the transcript and (in the
   TUI) confirmed before execution.
3. **Execute** — the task DAG is run in parallel waves. Independent tasks run
   concurrently (4 by default); dependent tasks receive their dependencies'
   outputs (the `{previous}` placeholder is substituted).
4. **Report** — a result card shows per-task status, output, and usage
   (tokens/cost). Subagents that modify files do so in the shared repo, so
   changes land on disk.

## Agents (roles)

Agents are markdown files in `~/.pi/agent/agents/` (user level) or
`.pi/agents/` (project level, opt-in via scope). Defaults are created on
first use: `implementer`, `reviewer`, `researcher`, `planner`, `scout`.

```markdown
---
name: reviewer
description: Senior code reviewer. Read-only.
tools: read, grep, find, ls, bash
model: anthropic/claude-sonnet-4-5
---

System prompt for the reviewer goes here.
```

- `model:` — which model powers this role. `provider/modelId` or bare id.
  Omit to use the session default. Edit with `/fleet-roles`.
- `tools:` — comma-separated allowlist. Omit for all tools.
- The body is the subagent's system prompt.

Project agents are repo-controlled: they only run with
`agentScope: "project" | "both"` (`/fleet-config scope both`) and are
confirmed interactively before execution.

## Configuration

Stored in `~/.pi/agent/fleet.json`:

| Key              | Default | Meaning                                   |
|------------------|---------|-------------------------------------------|
| `orchestratorModel` | (session) | Model used for task decomposition    |
| `agentScope`     | `user`  | `user` \| `project` \| `both`             |
| `concurrency`    | 4       | Max subagents running at once             |
| `maxParallelTasks` | 8     | Max tasks in a single wave                |

## Model assignment examples

```bash
/fleet-roles list
# implementer (user) → (default)
# reviewer (user) → anthropic/claude-sonnet-4-5
# researcher (user) → (default)

/fleet-roles implementer openai/gpt-5
/fleet-roles reviewer default
```

## Notes

- Subagents run `pi --mode json -p --no-session`, so each gets a fresh
  context window and its own model/tool config.
- Esc/Ctrl+C aborts running subagents.
- TUI: press Ctrl+O on a fleet card to expand full outputs.
