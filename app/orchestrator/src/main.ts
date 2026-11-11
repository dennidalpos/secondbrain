// SecondBrain Orchestrator UI: a thin shell over the SecondBrain PowerShell CLIs (agents.ps1, run-ready-tasks.ps1, prompts.ps1).
// Every write goes through those scripts; the UI only collects choices and shows their JSON results.
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { open } from "@tauri-apps/plugin-dialog";

type Source = "probe" | "config" | "fallback";
interface ModelInfo { id: string; label: string; source: Source; efforts: string[]; defaultEffort: string | null }
interface AgentCaps {
  provider: string; name: string; installed: boolean; path: string | null; version: string | null; helpRead: boolean;
  supports: { model: boolean; effort: boolean };
  configured: { model: string | null; effort: string | null };
  models: ModelInfo[]; efforts: { id: string; source: Source }[];
}
interface PreviewTask { id: string; seq: number; priority: string | null; title: string }
interface Skipped { id?: string; seq?: number | null; reason: string; repository?: string }
interface RunRecord { id: string; seq: number; state: string; exitCode: number | null; statusBefore: string; statusAfter: string; seconds: number; folder: string; parked: boolean }
interface Settings { secondbrainHome: string; pwshPath: string; recentRepos: string[] }

const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const state = {
  repo: "" as string,
  agents: [] as AgentCaps[],
  tasks: [] as PreviewTask[],
  selected: new Set<string>(),
  proposal: null as { proposalPath: string; proposalHash: string } | null,
  running: false,
  settings: { secondbrainHome: "", pwshPath: "", recentRepos: [] } as Settings,
};

const DIRECTIVES_TEMPLATE = `## Direttive di sviluppo

- Stack e versioni: <linguaggi, framework e versioni supportate>.
- Struttura: <cartelle principali e responsabilità>.
- Verifiche obbligatorie prima di chiudere un task: <comandi di build, lint e test>.
- Stile: <convenzioni di codice, messaggi, nomi>.
- Vietato senza richiesta esplicita: commit, push, pubblicazione, cancellazione di artefatti.

## Tracciamento dei task

- Lavora un solo task per sessione, quello indicato nel prompt del runner.
- All'avvio porta il task a in_progress; alla fine imposta done solo con criteri di accettazione verificati ed evidenze (comandi e risultati).
- Se serve una decisione o un accesso della persona, imposta blocked o user_required con il motivo nel campo stateReason.
- Aggiorna il tracker solo con gli strumenti SecondBrain (knowledge.ps1 -UpdateTaskId o gli strumenti MCP preview/submit_dossier_write), mai a mano.
- Nuovo lavoro scoperto durante il task: registralo come nuovo task con dipendenze, senza eseguirlo.
`;

function show(id: string, value: unknown) {
  $(id).textContent = typeof value === "string" ? value : JSON.stringify(value, null, 2);
}
function errorText(e: unknown): string { return typeof e === "string" ? e : e instanceof Error ? e.message : JSON.stringify(e); }
async function call<T>(cmd: string, args: Record<string, unknown> = {}, target?: string): Promise<T | null> {
  try { return await invoke<T>(cmd, args); }
  catch (e) { if (target) show(target, "Errore: " + errorText(e)); else alert(errorText(e)); return null; }
}

// Tabs
function selectTab(name: string) {
  document.querySelectorAll<HTMLButtonElement>(".tabs button").forEach((b) => b.setAttribute("aria-selected", String(b.dataset.tab === name)));
  document.querySelectorAll<HTMLElement>(".panel").forEach((p) => (p.hidden = p.id !== "tab-" + name));
}
document.querySelectorAll<HTMLButtonElement>(".tabs button").forEach((b) => b.addEventListener("click", () => selectTab(b.dataset.tab!)));

// Settings
async function loadSettings() {
  const s = await call<Settings>("get_settings", {}, "s-info");
  if (!s) return;
  state.settings = s;
  ($("s-home") as HTMLInputElement).value = s.secondbrainHome;
  ($("s-pwsh") as HTMLInputElement).value = s.pwshPath;
  renderRecent();
}
$("s-save").addEventListener("click", async () => {
  state.settings.secondbrainHome = ($("s-home") as HTMLInputElement).value.trim();
  state.settings.pwshPath = ($("s-pwsh") as HTMLInputElement).value.trim();
  const ok = await call<Settings>("save_settings", { settings: state.settings }, "s-info");
  if (ok) { state.settings = ok; show("s-info", "Impostazioni salvate."); }
});
$("s-probe").addEventListener("click", () => probeAgents("s-info"));

function renderRecent() {
  const box = $("recent");
  box.replaceChildren(...state.settings.recentRepos.map((p) => {
    const b = document.createElement("button");
    b.textContent = p; b.title = p;
    b.addEventListener("click", () => { ($("repo-path") as HTMLInputElement).value = p; loadRepository(); });
    return b;
  }));
}

// 1. Repository
$("repo-browse").addEventListener("click", async () => {
  const dir = await open({ directory: true, multiple: false, title: "Checkout del repository" });
  if (typeof dir === "string") ($("repo-path") as HTMLInputElement).value = dir;
});
$("repo-load").addEventListener("click", () => loadRepository());
async function loadRepository() {
  const path = ($("repo-path") as HTMLInputElement).value.trim();
  if (!path) return;
  show("repo-info", "Risoluzione del dossier…");
  const info = await call<{ repositories: { identity: string; dossier: string; tracker: string; agents: string }[] }>("resolve_repository", { path }, "repo-info");
  const repo = info?.repositories?.[0];
  if (!repo) { if (info) show("repo-info", "Checkout non associato a un dossier SecondBrain attivo. Registralo con secondbrain.ps1 -AddRepo."); return; }
  state.repo = path;
  $("repo-label").textContent = repo.identity;
  show("repo-info", { identity: repo.identity, dossier: repo.dossier, tracker: repo.tracker, agents: repo.agents });
  ($("dir-file") as HTMLInputElement).value = repo.agents ?? "";
  state.settings.recentRepos = [path, ...state.settings.recentRepos.filter((p) => p !== path)].slice(0, 8);
  const saved = await call<Settings>("save_settings", { settings: state.settings });
  if (saved) state.settings = saved;
  renderRecent();
  await Promise.all([readDirectives(), probeAgents(), refreshTasks()]);
}

// 2. Directives
$("dir-browse").addEventListener("click", async () => {
  const file = await open({ multiple: false, title: "File delle direttive", filters: [{ name: "Markdown", extensions: ["md"] }] });
  if (typeof file === "string") { ($("dir-file") as HTMLInputElement).value = file; await readDirectiveFile(); }
});
$("dir-read").addEventListener("click", () => readDirectiveFile());
$("dir-template").addEventListener("click", () => {
  const area = $("dir-text") as HTMLTextAreaElement;
  area.value = area.value.trim() ? area.value.trimEnd() + "\n\n" + DIRECTIVES_TEMPLATE : DIRECTIVES_TEMPLATE;
});
async function readDirectiveFile() {
  const path = ($("dir-file") as HTMLInputElement).value.trim();
  if (!path) return;
  const text = await call<string>("read_text_file", { path }, "dir-current");
  if (text !== null) show("dir-current", text);
}
async function readDirectives() {
  if (!state.repo) return;
  const d = await call<{ managedBlock: string | null; dossierDirectives: string; agentsFile: string }>("read_directives", { repo: state.repo }, "dir-result");
  if (!d) return;
  ($("dir-text") as HTMLTextAreaElement).value = d.dossierDirectives ?? "";
  if (d.agentsFile) ($("dir-file") as HTMLInputElement).value = d.agentsFile;
  await readDirectiveFile();
  state.proposal = null; ($("dir-apply") as HTMLButtonElement).disabled = true;
  show("dir-result", "");
}
$("dir-preview").addEventListener("click", async () => {
  if (!state.repo) return show("dir-result", "Carica prima un repository.");
  show("dir-result", "Preparazione della proposta…");
  const text = ($("dir-text") as HTMLTextAreaElement).value;
  const r = await call<{ proposal: { proposalPath: string; proposalHash: string | null; preview: unknown } | null }>("preview_directives", { repo: state.repo, text }, "dir-result");
  if (!r?.proposal) return;
  show("dir-result", r.proposal.preview);
  if (r.proposal.proposalHash) {
    state.proposal = { proposalPath: r.proposal.proposalPath, proposalHash: r.proposal.proposalHash };
    ($("dir-apply") as HTMLButtonElement).disabled = false;
  }
});
$("dir-apply").addEventListener("click", async () => {
  if (!state.proposal) return;
  if (!confirm("Approvi la proposta esaminata e allinei il blocco gestito del repository?")) return;
  const authorization = "Approvazione nell'orchestratore desktop " + new Date().toISOString();
  show("dir-result", "Approvazione e allineamento…");
  const r = await call<unknown>("apply_directives", { repo: state.repo, proposalPath: state.proposal.proposalPath, proposalHash: state.proposal.proposalHash, authorization }, "dir-result");
  if (r) { show("dir-result", r); state.proposal = null; ($("dir-apply") as HTMLButtonElement).disabled = true; await readDirectiveFile(); }
});

// 3. Queue
async function probeAgents(target = "q-agent") {
  const r = await call<{ agents: AgentCaps[] }>("probe_agents", {}, target);
  if (!r) return;
  state.agents = r.agents;
  const select = $("q-provider") as HTMLSelectElement;
  const current = select.value;
  select.replaceChildren(...r.agents.map((a) => {
    const o = document.createElement("option");
    o.value = a.provider;
    o.textContent = a.name + (a.installed ? (a.version ? " " + a.version : "") : " (non installato)");
    o.disabled = !a.installed;
    return o;
  }));
  const firstInstalled = r.agents.find((a) => a.installed)?.provider ?? "";
  select.value = r.agents.some((a) => a.provider === current && a.installed) ? current : firstInstalled;
  renderAgentOptions();
  if (target === "s-info") show("s-info", r.agents);
}
function currentAgent(): AgentCaps | undefined { return state.agents.find((a) => a.provider === ($("q-provider") as HTMLSelectElement).value); }
function option(value: string, label: string) { const o = document.createElement("option"); o.value = value; o.textContent = label; return o; }
const SOURCE_LABEL: Record<Source, string> = { probe: "rilevato", config: "configurazione", fallback: "tabella di riserva" };
function renderAgentOptions() {
  const a = currentAgent();
  const model = $("q-model") as HTMLSelectElement;
  const custom = $("q-custom") as HTMLInputElement;
  if (!a) { model.replaceChildren(); ($("q-effort") as HTMLSelectElement).replaceChildren(); $("q-agent").textContent = "Nessun agente installato."; return; }
  const def = "predefinito della CLI" + (a.configured.model ? " (" + a.configured.model + ")" : "");
  model.replaceChildren(option("", def), ...(a.supports.model ? a.models.map((m) => option(m.id, m.label + " · " + SOURCE_LABEL[m.source])) : []));
  model.disabled = !a.supports.model; custom.disabled = !a.supports.model;
  renderEffortOptions();
  $("q-agent").textContent = a.installed
    ? `${a.name} ${a.version ?? ""} · ${a.path ?? ""} · modello ${a.supports.model ? "selezionabile" : "non selezionabile"} · impegno ${a.supports.effort ? "selezionabile" : "non disponibile"}`
    : `${a.name} non installato.`;
}
function renderEffortOptions() {
  const a = currentAgent();
  const effort = $("q-effort") as HTMLSelectElement;
  if (!a) return;
  const chosen = (($("q-custom") as HTMLInputElement).value.trim() || ($("q-model") as HTMLSelectElement).value || a.configured.model) ?? "";
  const perModel = a.models.find((m) => m.id === chosen && m.efforts.length);
  const levels = perModel ? perModel.efforts.map((id) => ({ id, source: perModel.source })) : a.efforts;
  const def = "predefinito" + (a.configured.effort ? " (" + a.configured.effort + ")" : "");
  effort.replaceChildren(option("", def), ...(a.supports.effort ? levels.map((l) => option(l.id, l.id + " · " + SOURCE_LABEL[l.source])) : []));
  effort.disabled = !a.supports.effort;
}
$("q-provider").addEventListener("change", renderAgentOptions);
$("q-model").addEventListener("change", renderEffortOptions);
$("q-custom").addEventListener("input", renderEffortOptions);
$("q-refresh").addEventListener("click", () => refreshTasks());
$("q-all").addEventListener("click", () => { state.tasks.forEach((t) => state.selected.add(t.id)); renderTasks(); });

async function refreshTasks() {
  if (!state.repo) return;
  const r = await call<{ tasks: PreviewTask[]; skipped: Skipped[] }>("list_tasks", { repo: state.repo }, "q-agent");
  if (!r) return;
  state.tasks = r.tasks ?? [];
  // Nothing is preselected (#517): the person opts in task by task, or with "Seleziona tutti".
  state.selected = new Set<string>();
  renderTasks();
  $("q-skipped").replaceChildren(...(r.skipped ?? []).filter((s) => s.id).map((s) => {
    const li = document.createElement("li"); li.textContent = `${s.id} — ${s.reason}`; return li;
  }));
}
function renderTasks() {
  const order = state.tasks;
  $("q-tasks").replaceChildren(...order.map((t, i) => {
    const tr = document.createElement("tr");
    const cb = document.createElement("input"); cb.type = "checkbox"; cb.checked = state.selected.has(t.id);
    cb.addEventListener("change", () => { cb.checked ? state.selected.add(t.id) : state.selected.delete(t.id); });
    const up = document.createElement("button"); up.textContent = "↑"; up.disabled = i === 0; up.title = "Sposta su";
    up.addEventListener("click", () => { [order[i - 1], order[i]] = [order[i], order[i - 1]]; renderTasks(); });
    const cells: (string | Node)[] = [cb, String(t.seq), t.id, t.title, t.priority ?? "—", up];
    cells.forEach((c) => { const td = document.createElement("td"); td.append(c); tr.append(td); });
    return tr;
  }));
}
$("q-start").addEventListener("click", async () => {
  if (state.running) return;
  const a = currentAgent();
  const taskIds = state.tasks.filter((t) => state.selected.has(t.id)).map((t) => t.id);
  if (!state.repo || !a || !taskIds.length) return alert("Seleziona un repository, un agente installato e almeno un task.");
  const custom = ($("q-custom") as HTMLInputElement).value.trim();
  const request = {
    repo: state.repo, provider: a.provider,
    model: custom || ($("q-model") as HTMLSelectElement).value || null,
    effort: ($("q-effort") as HTMLSelectElement).value || null,
    allowCustomModel: Boolean(custom),
    taskIds, timeoutMinutes: Number(($("q-timeout") as HTMLInputElement).value) || 30,
  };
  if (!confirm(`Avviare ${taskIds.length} task con ${a.name}${request.model ? " · " + request.model : ""}${request.effort ? " · " + request.effort : ""}?\nGli agenti modificano file nel checkout; commit, push e cancellazioni sono vietati.`)) return;
  $("run-results").replaceChildren(); show("run-log", "");
  const ok = await call<boolean>("start_queue", { request }, "run-log");
  if (ok) { setRunning(true); selectTab("run"); }
});

// 4. Run
function setRunning(on: boolean, label?: string) {
  state.running = on;
  const s = $("run-status");
  s.textContent = label ?? (on ? "In esecuzione" : "Inattivo");
  s.className = "status " + (on ? "state-running" : "");
  ($("q-start") as HTMLButtonElement).disabled = on;
}
function appendLog(line: string) {
  const log = $("run-log");
  log.textContent += line + "\n";
  log.scrollTop = log.scrollHeight;
}
function addResult(r: RunRecord) {
  const tr = document.createElement("tr");
  const badge = document.createElement("span"); badge.className = "state-" + r.state; badge.textContent = r.state + (r.parked ? " (parcheggiato)" : "");
  const cells: (string | Node)[] = [String(r.seq), r.id, badge, `${r.statusBefore} → ${r.statusAfter}`, String(r.seconds), r.folder];
  cells.forEach((c) => { const td = document.createElement("td"); td.append(c); tr.append(td); });
  $("run-results").append(tr);
}
$("run-stop").addEventListener("click", () => call("stop_queue", { force: false }, "run-log").then(() => appendLog("Arresto richiesto: la coda si ferma dopo il task corrente.")));
$("run-abort").addEventListener("click", () => {
  if (!confirm("Interrompere subito l'agente in corso? Il task resta nello stato lasciato dall'agente.")) return;
  call("stop_queue", { force: true }, "run-log");
});

interface RunnerEvent { line: string; json: { event?: string; message?: string; record?: RunRecord; reason?: string } | null }
listen<RunnerEvent>("runner-event", (e) => {
  const ev = e.payload.json;
  appendLog(ev?.message ?? e.payload.line);
  if (ev?.event === "start") setRunning(true, ev.message);
  if (ev?.event === "done" && ev.record) addResult(ev.record);
});
listen<{ code: number | null; stdout: string }>("runner-finished", (e) => {
  let summary = "Coda terminata (uscita " + e.payload.code + ")";
  try {
    const out = JSON.parse(e.payload.stdout.slice(e.payload.stdout.indexOf("{")));
    if (out.stopReason) summary += " · arresto: " + out.stopReason;
  } catch { /* final JSON missing: the runner was interrupted */ }
  setRunning(false, summary);
  appendLog(summary);
  refreshTasks();
});

loadSettings().then(() => probeAgents());
