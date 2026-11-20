/**
 * Model picker component that mirrors the built-in /model selector UX:
 * a search box on top, windowed list of "id [provider]" rows with a check
 * mark for the currently-assigned model, scroll indicator, and the selected
 * model's display name.
 *
 * Replaces the generic ctx.ui.select (no search) for fleet model pickers.
 */

import { Container, fuzzyFilter, Input, Spacer, Text } from "@earendil-works/pi-tui";
import type { KeybindingsManager } from "@earendil-works/pi-tui";
import type { Model } from "@earendil-works/pi-ai";

/** Minimal structural theme type (the real Theme is internal to pi). */
export interface ThemeLike {
	fg(color: string, text: string): string;
	bold(text: string): string;
}

interface PickerRow {
	/** "" = session default, "__custom__" = custom id entry, otherwise "provider/id". */
	ref: string;
	label: string;
	searchText: string;
	name?: string;
	isModel: boolean;
	current: boolean;
}

const MAX_VISIBLE = 10;

export class ModelPickerComponent extends Container {
	searchInput = new Input();

	private listContainer = new Container();
	private infoText = new Text("", 1, 0);
	private rows: PickerRow[] = [];
	private filteredRows: PickerRow[] = [];
	private selectedIndex = 0;
	private _focused = false;
	private theme: ThemeLike;
	private keybindings: KeybindingsManager;
	private onSelectCallback: (ref: string) => void;
	private onCancelCallback: () => void;

	constructor(
		title: string,
		models: Model<any>[],
		currentRef: string | undefined,
		theme: ThemeLike,
		keybindings: KeybindingsManager,
		onSelect: (ref: string) => void,
		onCancel: () => void,
	) {
		super();
		this.theme = theme;
		this.keybindings = keybindings;
		this.onSelectCallback = onSelect;
		this.onCancelCallback = onCancel;

		// Sort: currently-assigned model first, then by provider, then by name
		const sorted = [...models].sort((a, b) => {
			const aCur = currentRef === `${a.provider}/${a.id}`;
			const bCur = currentRef === `${b.provider}/${b.id}`;
			if (aCur && !bCur) return -1;
			if (!aCur && bCur) return 1;
			return a.provider.localeCompare(b.provider) || a.name.localeCompare(b.name);
		});

		this.rows = [
			{
				ref: "",
				label: "(default — use session model)",
				searchText: "default session model inherit current",
				isModel: false,
				current: currentRef === undefined || currentRef === "",
			},
			...sorted.map((m) => ({
				ref: `${m.provider}/${m.id}`,
				label: `${m.id} [${m.provider}]`,
				searchText: `${m.provider} ${m.id} ${m.name}`,
				name: m.name,
				isModel: true,
				current: currentRef === `${m.provider}/${m.id}`,
			})),
			{
				ref: "__custom__",
				label: "✏️ Enter a custom model id",
				searchText: "custom enter type model id",
				isModel: false,
				current: false,
			},
		];

		this.addChild(new Text(theme.fg("accent", theme.bold(title)), 1, 0));
		this.addChild(new Spacer(1));
		this.addChild(new Text(theme.fg("dim", "─".repeat(240)), 1, 0));
		this.addChild(this.searchInput);
		this.addChild(new Spacer(1));
		this.addChild(this.listContainer);
		this.addChild(new Spacer(1));
		this.addChild(this.infoText);
		this.addChild(new Spacer(1));
		this.addChild(
			new Text(
				theme.fg("muted", "type to search · ↑/↓ navigate · enter select · esc cancel"),
				1,
				0,
			),
		);

		this.searchInput.onSubmit = () => {
			const row = this.filteredRows[this.selectedIndex];
			if (row) this.onSelectCallback(row.ref);
		};

		this.filter();
	}

	/* Focusable: propagate to the search input so the hardware cursor (and
	 * IME candidate window) lands in the search box. */
	get focused(): boolean {
		return this._focused;
	}
	set focused(value: boolean) {
		this._focused = value;
		this.searchInput.focused = value;
	}

	handleInput(data: string): void {
		const kb = this.keybindings;
		if (kb.matches(data, "tui.select.up")) {
			if (this.filteredRows.length === 0) return;
			this.selectedIndex =
				this.selectedIndex === 0 ? this.filteredRows.length - 1 : this.selectedIndex - 1;
			this.updateList();
		} else if (kb.matches(data, "tui.select.down")) {
			if (this.filteredRows.length === 0) return;
			this.selectedIndex =
				this.selectedIndex === this.filteredRows.length - 1 ? 0 : this.selectedIndex + 1;
			this.updateList();
		} else if (kb.matches(data, "tui.select.confirm")) {
			const row = this.filteredRows[this.selectedIndex];
			if (row) this.onSelectCallback(row.ref);
		} else if (kb.matches(data, "tui.select.cancel")) {
			this.onCancelCallback();
		} else {
			this.searchInput.handleInput(data);
			this.filter();
		}
	}

	private filter(): void {
		const query = this.searchInput.getValue().trim();
		this.filteredRows = query ? fuzzyFilter(this.rows, query, (r) => r.searchText) : [...this.rows];
		this.selectedIndex = query
			? 0
			: Math.min(this.selectedIndex, Math.max(0, this.filteredRows.length - 1));
		this.updateList();
	}

	private updateList(): void {
		const theme = this.theme;
		this.listContainer.clear();

		const total = this.filteredRows.length;
		if (total === 0) {
			this.listContainer.addChild(new Text(theme.fg("muted", "  No matching models"), 1, 0));
			this.infoText.setText("");
			return;
		}

		const start = Math.max(
			0,
			Math.min(this.selectedIndex - Math.floor(MAX_VISIBLE / 2), total - MAX_VISIBLE),
		);
		const end = Math.min(start + MAX_VISIBLE, total);

		for (let i = start; i < end; i++) {
			const row = this.filteredRows[i];
			if (!row) continue;
			const isSelected = i === this.selectedIndex;
			const check = row.current ? theme.fg("success", " ✓") : "";
			let line: string;
			if (isSelected) {
				line = theme.fg("accent", "→ ") + theme.fg("accent", row.label) + check;
			} else {
				line = `  ${row.isModel ? row.label : theme.fg("muted", row.label)}${check}`;
			}
			this.listContainer.addChild(new Text(line, 1, 0));
		}

		const parts: string[] = [];
		if (total > MAX_VISIBLE) parts.push(`(${this.selectedIndex + 1}/${total})`);
		const selected = this.filteredRows[this.selectedIndex];
		if (selected?.name) parts.push(`Model Name: ${selected.name}`);
		this.infoText.setText(parts.length > 0 ? theme.fg("muted", `  ${parts.join(" · ")}`) : "");
	}
}
