// Shared helpers of the orchestrator views: DOM shortcuts, Tauri calls with inline errors, small formatters and the shared types.
import { invoke } from "@tauri-apps/api/core";

export type Source = "probe" | "config" | "fallback";
export type AgentStatus = "ready" | "not-found" | "not-responding";
export interface ModelInfo { id: string; label: string; source: Source; efforts: string[]; defaultEffort: string | null }
export interface AgentCaps {
  provider: string; name: string; installed: boolean; status: AgentStatus; origin: string | null; path: string | null; version: string | null; helpRead: boolean;
  supports: { model: boolean; effort: boolean; streamJson: boolean };
  configured: { model: string | null; effort: string | null };
  models: ModelInfo[]; efforts: { id: string; source: Source }[];
  light?: { model: string | null; effort: string | null; source: string };
}
/** Agent, model and effort of a one-shot analysis; empty model/effort = the light role of the model table. */
export interface LightChoice { provider: string; model: string; effort: string; label: string }

export const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
export const input = (id: string) => $<HTMLInputElement>(id);
export const select = (id: string) => $<HTMLSelectElement>(id);

export function errorText(e: unknown): string { return typeof e === "string" ? e : e instanceof Error ? e.message : JSON.stringify(e); }
export function setError(id: string, e: unknown | null) {
  const node = $(id);
  if (!node) return;
  node.hidden = e === null;
  node.textContent = e === null ? "" : errorText(e);
}
export async function call<T>(cmd: string, args: Record<string, unknown> = {}, errorId?: string): Promise<T | null> {
  try {
    const r = await invoke<T>(cmd, args);
    if (errorId) setError(errorId, null);
    return r;
  } catch (e) {
    if (errorId) setError(errorId, e);
    return null;
  }
}
export function el<K extends keyof HTMLElementTagNameMap>(tag: K, props: Record<string, unknown> = {}, ...children: (string | Node)[]): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  Object.assign(node, props);
  node.append(...children);
  return node;
}
/** Runs fn with the button marked busy (spinner, aria-busy) until fn ends; a click while it is busy is ignored. The button's own
 *  disabled state is left to the views, so their render functions stay the only source of it. Returns undefined when ignored. */
export async function busy<T>(button: HTMLButtonElement, fn: () => Promise<T> | T, label?: string): Promise<T | undefined> {
  if (button.getAttribute("aria-busy") === "true") return undefined;
  const text = button.textContent;
  button.setAttribute("aria-busy", "true");
  button.classList.add("busy");
  if (label) button.textContent = label;
  try {
    return await fn();
  } finally {
    button.removeAttribute("aria-busy");
    button.classList.remove("busy");
    if (label) button.textContent = text;
  }
}
/** Click handler that runs through busy(): spinner on the clicked button and no second start while the first is running. */
export function onBusyClick(button: HTMLElement, fn: () => Promise<unknown> | unknown, label?: string) {
  button.addEventListener("click", () => { void busy(button as HTMLButtonElement, fn, label); });
}
export function option(value: string, label: string) { return el("option", { value, textContent: label }); }
export function fmtDuration(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) return "—";
  const s = Math.floor(seconds % 60), m = Math.floor(seconds / 60) % 60, h = Math.floor(seconds / 3600);
  return h ? `${h} h ${m} min` : m ? `${m} min ${s} s` : `${s} s`;
}
export function fmtDate(iso: string | null | undefined): string { return iso ? new Date(iso).toLocaleString() : "—"; }
export function since(iso: string | null | undefined): number { return iso ? (Date.now() - Date.parse(iso)) / 1000 : NaN; }
export function baseName(p: string) { return p.split(/[\\/]/).filter(Boolean).pop() ?? p; }

export const TOOL_LABEL: Record<string, string> = { claude: "Claude", codex: "Codex", gemini: "Gemini", antigravity: "Antigravity", human: "Persona", unknown: "Sconosciuto" };
export const MODE_LABEL: Record<string, string> = { runner: "runner", interactive: "sessione interattiva", mcp: "MCP", cli: "riga di comando", analysis: "analisi", "memory-cycle": "ciclo della memoria", backfill: "recupero" };
/** Colored badge of the tool that worked on a task (claude, codex, gemini, antigravity, human, unknown). */
export function toolBadge(tool: string, extra = ""): HTMLSpanElement {
  const t = TOOL_LABEL[tool] ? tool : "unknown";
  const b = el("span", { className: "tool-badge", textContent: TOOL_LABEL[t] + (extra ? " · " + extra : "") });
  b.dataset.tool = t;
  return b;
}
