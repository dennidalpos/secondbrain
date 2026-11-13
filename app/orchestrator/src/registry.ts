// Registro: every task of the repository (active and archived) with a badge per tool that worked on it (knowledge.ps1 -Registry:
// dossier ledger plus the runner reports of this workstation), and the history of the runner's runs (runner-status.ps1 -List).
import { $, call, el, onBusyClick, fmtDate, fmtDuration, input, MODE_LABEL, option, select, toolBadge, TOOL_LABEL } from "./common";

interface RunEntry {
  recordId: string; at: string; event: string; statusBefore: string | null; statusAfter: string | null; reason?: string; source?: string;
  executor: { tool: string; mode: string; model?: string; effort?: string; runId?: string };
  outcome?: { state: string; exitCode: number | null; seconds: number | null; parked?: unknown; folder?: string };
}
interface RegistryTask {
  id: string; seq: number | null; title: string; status: string; priority: string; execution: string; archived: boolean; closedAt: string | null;
  stateReason: string | null; tools: string[]; lastTool: string | null; lastActivity: string | null; runs: RunEntry[]; evidence: { reference: string; outcome: string }[];
}
interface RegistryPage { total: number; offset: number; limit: number; nextOffset: number | null; tools: Record<string, number>; tasks: RegistryTask[] }
interface RunSummary {
  runId: string; state: string; verdict: string; provider: string; model: string | null; effort: string | null; startedAt: string; finishedAt: string | null;
  counts: { total: number; done: number; succeeded: number; failed: number } | null; stopReason: string | null; folder: string; results: { id: string; seq: number; state: string }[];
}

const STATUS_LABEL: Record<string, string> = { todo: "da fare", in_progress: "in corso", blocked: "bloccato", done: "fatto", cancelled: "annullato", unknown: "sconosciuto" };
const PAGE_SIZE = 50;
let getRepo: () => string = () => "";
let page = 0;
let view: "tasks" | "runs" = "tasks";
// Each read is numbered: a slower answer to an older filter never overwrites the rows of a newer one.
let registryRequest = 0;
let runsRequest = 0;

export function initRegistry(repo: () => string) {
  getRepo = repo;
  select("reg-tool").replaceChildren(option("", "Tutti gli strumenti"), ...Object.keys(TOOL_LABEL).map((t) => option(t, TOOL_LABEL[t])));
  select("reg-status").replaceChildren(option("", "Tutti gli stati"), ...Object.keys(STATUS_LABEL).map((s) => option(s, STATUS_LABEL[s])));
  for (const id of ["reg-tool", "reg-status", "reg-archived"]) select(id).addEventListener("change", () => { page = 0; refreshRegistry(); });
  let timer = 0;
  input("reg-search").addEventListener("input", () => { window.clearTimeout(timer); timer = window.setTimeout(() => { page = 0; refreshRegistry(); }, 350); });
  $("reg-prev").addEventListener("click", () => { if (page > 0) { page--; refreshRegistry(); } });
  $("reg-next").addEventListener("click", () => { page++; refreshRegistry(); });
  onBusyClick($("reg-refresh"), () => (view === "tasks" ? refreshRegistry() : refreshRuns()));
  document.querySelectorAll<HTMLButtonElement>("[data-reg-view]").forEach((b) => b.addEventListener("click", () => setView(b.dataset.regView as "tasks" | "runs")));
}

function setView(v: "tasks" | "runs") {
  view = v;
  document.querySelectorAll<HTMLButtonElement>("[data-reg-view]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.regView === v)));
  $("reg-tasks-view").hidden = v !== "tasks";
  $("reg-runs-view").hidden = v !== "runs";
  if (v === "tasks") refreshRegistry(); else refreshRuns();
}

export async function refreshRegistry() {
  const repo = getRepo();
  if (!repo) return;
  $("reg-state").textContent = "Lettura del registro…";
  const query = {
    repo, page, pageSize: PAGE_SIZE,
    tool: select("reg-tool").value || null, status: select("reg-status").value || null,
    archived: select("reg-archived").value || "include", search: input("reg-search").value.trim() || null,
  };
  const request = ++registryRequest;
  const r = await call<RegistryPage>("read_registry", { query }, "reg-error");
  if (request !== registryRequest || view !== "tasks") return;
  if (!r) { $("reg-state").textContent = ""; return; }
  const from = r.total ? r.offset + 1 : 0, to = r.offset + r.tasks.length;
  $("reg-state").textContent = `${from}–${to} di ${r.total} task`;
  $<HTMLButtonElement>("reg-prev").disabled = page === 0;
  $<HTMLButtonElement>("reg-next").disabled = r.nextOffset === null;
  $("reg-tools").replaceChildren(...Object.entries(r.tools).filter(([, n]) => n > 0).map(([t, n]) => toolBadge(t, String(n))));
  $("reg-empty").hidden = r.tasks.length > 0;
  $("reg-rows").replaceChildren(...r.tasks.flatMap(renderTask));
}

function lastOutcome(t: RegistryTask): string {
  const run = [...t.runs].reverse().find((x) => x.outcome);
  if (!run?.outcome) return "—";
  return run.outcome.state + (run.outcome.seconds != null ? ` · ${fmtDuration(run.outcome.seconds)}` : "");
}

function renderTask(t: RegistryTask): HTMLTableRowElement[] {
  const row = el("tr", { className: "reg-row" + (t.archived ? " archived" : "") });
  row.tabIndex = 0;
  const tools = el("span", { className: "tool-list" }, ...t.tools.map((x) => toolBadge(x)));
  const status = el("span", { className: "state-" + t.status }, STATUS_LABEL[t.status] ?? t.status);
  const title = el("span", {}, t.title, t.archived ? el("span", { className: "tag" }, "archiviato") : "");
  [t.seq != null ? String(t.seq) : "—", t.id, title, status, tools, fmtDate(t.lastActivity ?? t.closedAt), lastOutcome(t), String(t.runs.length)].forEach((c) => row.append(el("td", {}, c)));
  const detail = el("tr", { className: "reg-detail" });
  detail.hidden = true;
  const cell = el("td");
  cell.colSpan = 8;
  detail.append(cell);
  const toggle = () => {
    detail.hidden = !detail.hidden;
    row.classList.toggle("open", !detail.hidden);
    if (!detail.hidden && !cell.childElementCount) cell.append(renderRuns(t));
  };
  row.addEventListener("click", toggle);
  row.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggle(); } });
  return [row, detail];
}

function renderRuns(t: RegistryTask): HTMLElement {
  const box = el("div", { className: "reg-runs" });
  if (t.stateReason) box.append(el("p", { className: "muted small" }, "Motivo di stato: " + t.stateReason));
  if (!t.runs.length) {
    box.append(el("p", { className: "muted small" }, "Nessuna esecuzione registrata: il task precede il registro delle esecuzioni (strumento sconosciuto)."));
  } else {
    const list = el("ol", { className: "steps-log" });
    for (const r of [...t.runs].reverse()) {
      const meta = [MODE_LABEL[r.executor.mode] ?? r.executor.mode, r.executor.model, r.executor.effort].filter(Boolean).join(" · ");
      const change = r.statusBefore || r.statusAfter ? `${r.statusBefore ?? "—"} → ${r.statusAfter ?? "—"}` : "";
      const outcome = r.outcome ? ` · esito ${r.outcome.state}${r.outcome.seconds != null ? ", " + fmtDuration(r.outcome.seconds) : ""}${r.outcome.folder ? ", " + r.outcome.folder : ""}` : "";
      list.append(el("li", {}, el("span", { className: "muted small" }, fmtDate(r.at)), " ", toolBadge(r.executor.tool), " ", el("span", { className: "small" }, meta), " ", change, outcome, r.reason ? el("div", { className: "muted small" }, r.reason) : ""));
    }
    box.append(list);
  }
  if (t.evidence.length) box.append(el("p", { className: "muted small" }, "Evidenze: " + t.evidence.map((e) => `${e.reference} (${e.outcome})`).join("; ")));
  return box;
}

export async function refreshRuns() {
  const repo = getRepo();
  if (!repo) return;
  $("reg-state").textContent = "Lettura dei run…";
  const request = ++runsRequest;
  const r = await call<{ total: number; runs: RunSummary[] }>("list_runs", { repo, limit: 100 }, "reg-error");
  if (request !== runsRequest || view !== "runs") return;
  if (!r) { $("reg-state").textContent = ""; return; }
  $("reg-state").textContent = `${r.runs.length} run su ${r.total} su questa postazione`;
  $("reg-runs-empty").hidden = r.runs.length > 0;
  $("reg-run-rows").replaceChildren(...r.runs.map((x) => {
    const tr = el("tr");
    const counts = x.counts ? `${x.counts.done}/${x.counts.total} (${x.counts.succeeded} ok, ${x.counts.failed} ko)` : "—";
    const tasks = x.results.map((t) => `#${t.seq} ${t.state}`).join(", ") || "—";
    [fmtDate(x.startedAt), x.finishedAt ? fmtDate(x.finishedAt) : "in corso", toolBadge(x.provider || "unknown"), [x.model, x.effort].filter(Boolean).join(" · ") || "predefiniti della CLI",
      counts, x.stopReason ?? "—", tasks, el("span", { className: "mono small" }, x.folder)].forEach((c) => tr.append(el("td", {}, c)));
    return tr;
  }));
}

export function showRegistry() { if (view === "tasks") refreshRegistry(); else refreshRuns(); }
