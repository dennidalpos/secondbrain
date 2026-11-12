// SecondBrain Orchestrator UI: a thin shell over the SecondBrain PowerShell CLIs (agents.ps1, run-ready-tasks.ps1, runner-status.ps1, prompts.ps1).
// Every write goes through those scripts; the UI only collects choices and shows their JSON results. A run is followed through its
// status.json and events.jsonl, so it can be found again after the window is closed and reopened.
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { open } from "@tauri-apps/plugin-dialog";

type Source = "probe" | "config" | "fallback";
type AgentStatus = "ready" | "not-found" | "not-responding";
interface ModelInfo { id: string; label: string; source: Source; efforts: string[]; defaultEffort: string | null }
interface AgentCaps {
  provider: string; name: string; installed: boolean; status: AgentStatus; origin: string | null; path: string | null; version: string | null; helpRead: boolean;
  supports: { model: boolean; effort: boolean; streamJson: boolean };
  configured: { model: string | null; effort: string | null };
  models: ModelInfo[]; efforts: { id: string; source: Source }[];
}
interface ClientInfo { name: string; confidence: string; provider: string | null; runnable: boolean; reason: string | null }
interface PreviewTask { id: string; seq: number; priority: string | null; title: string }
interface Skipped { id?: string; seq?: number | null; reason: string; repository?: string }
interface RunRecord { id: string; seq: number; state: string; exitCode: number | null; statusBefore: string; statusAfter: string; seconds: number; folder: string; parked: boolean }
interface Settings { secondbrainHome: string; pwshPath: string; recentRepos: string[] }
interface Launch { repo: string | null; secondbrainHome: string | null; rootError: string | null; pwsh: string; version: string }
interface RunStatusFile {
  state: string; phase: string; pid: number; startedAt: string; updatedAt: string; finishedAt: string | null;
  lastAgentEventAt: string | null; lastAgentEvent: { kind: string; summary: string; time: string } | null;
  task: { id: string; seq: number; title: string; position: number; total: number; startedAt: string; folder: string } | null;
  counts: { total: number; done: number; succeeded: number; failed: number }; stopReason: string | null; stallMinutes: number; folder: string; quota?: { state: string; source: string; resetAt?: string | null } | null;
}
interface RunReport { active: boolean; verdict: "working" | "stalled" | "finished" | "orphaned" | "none"; folder?: string; status: RunStatusFile | null }
interface EventJson { event?: string; message?: string; time?: string; record?: RunRecord; kind?: string; summary?: string; minutes?: number }
interface RunnerEvent { line: string; json: EventJson | null }

const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const input = (id: string) => $<HTMLInputElement>(id);
const select = (id: string) => $<HTMLSelectElement>(id);

const state = {
  launch: null as Launch | null,
  repo: "",
  identity: "",
  agents: [] as AgentCaps[],
  clients: [] as ClientInfo[],
  provider: "",
  tasks: [] as PreviewTask[],
  selected: new Set<string>(),
  proposal: null as { proposalPath: string; proposalHash: string } | null,
  run: { active: false, starting: false, pid: 0, folder: "", offset: 0, startedAt: "", status: null as RunStatusFile | null, verdict: "idle" },
  timers: { events: 0, status: 0, clock: 0, find: 0 },
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

const VERDICT_LABEL: Record<string, string> = {
  idle: "Inattivo", starting: "Avvio…", working: "In lavoro", stalled: "Possibile stallo", finished: "Concluso", orphaned: "Interrotto", none: "Inattivo",
};
const STATUS_LABEL: Record<AgentStatus, string> = { ready: "pronto", "not-found": "non installato", "not-responding": "non risponde" };
const ORIGIN_LABEL: Record<string, string> = { path: "", search: "trovato fuori dal PATH", package: "dal pacchetto Store" };
const SOURCE_LABEL: Record<Source, string> = { probe: "dalla CLI", config: "dalla configurazione", fallback: "tabella di riserva" };
const REASON_LABEL: Record<string, string> = { "no-headless-cli": "nessuna CLI pilotabile dal runner", "cli-not-found": "CLI non installata", "cli-not-responding": "CLI non risponde" };

function errorText(e: unknown): string { return typeof e === "string" ? e : e instanceof Error ? e.message : JSON.stringify(e); }
function setError(id: string, e: unknown | null) {
  const el = $(id);
  el.hidden = e === null;
  el.textContent = e === null ? "" : errorText(e);
}
async function call<T>(cmd: string, args: Record<string, unknown> = {}, errorId?: string): Promise<T | null> {
  try {
    const r = await invoke<T>(cmd, args);
    if (errorId) setError(errorId, null);
    return r;
  } catch (e) {
    if (errorId) setError(errorId, e);
    return null;
  }
}
function el<K extends keyof HTMLElementTagNameMap>(tag: K, props: Record<string, unknown> = {}, ...children: (string | Node)[]): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  Object.assign(node, props);
  node.append(...children);
  return node;
}
function fmtDuration(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) return "—";
  const s = Math.floor(seconds % 60), m = Math.floor(seconds / 60) % 60, h = Math.floor(seconds / 3600);
  return h ? `${h} h ${m} min` : m ? `${m} min ${s} s` : `${s} s`;
}
function since(iso: string | null | undefined): number { return iso ? (Date.now() - Date.parse(iso)) / 1000 : NaN; }
function baseName(p: string) { return p.split(/[\\/]/).filter(Boolean).pop() ?? p; }

// Steps
function selectTab(name: string) {
  document.querySelectorAll<HTMLButtonElement>(".steps button[data-tab]").forEach((b) => b.setAttribute("aria-selected", String(b.dataset.tab === name)));
  document.querySelectorAll<HTMLElement>(".panel").forEach((p) => (p.hidden = p.id !== "tab-" + name));
}
function updateSteps() {
  const loaded = Boolean(state.repo);
  const tab = (n: string) => document.querySelector<HTMLButtonElement>(`.steps button[data-tab="${n}"]`)!;
  tab("directives").disabled = !loaded;
  tab("queue").disabled = !loaded;
  tab("run").disabled = !loaded && !state.run.active;
  tab("repo").classList.toggle("done", loaded);
  tab("queue").classList.toggle("done", state.run.active || state.run.verdict === "finished");
  $<HTMLButtonElement>("repo-next").disabled = !loaded;
}
// A tab chosen by the person is never overridden by the startup preload.
let navigated = false;
document.querySelectorAll<HTMLButtonElement>(".steps button[data-tab]").forEach((b) => b.addEventListener("click", () => { if (!b.disabled) { navigated = true; selectTab(b.dataset.tab!); } }));
$("repo-next").addEventListener("click", () => selectTab("directives"));
$("dir-next").addEventListener("click", () => selectTab("queue"));

// Settings
async function loadSettings() {
  const s = await call<Settings>("get_settings", {}, "s-error");
  if (!s) return;
  input("s-home").value = s.secondbrainHome;
  input("s-pwsh").value = s.pwshPath;
  input("s-home").placeholder = state.launch?.secondbrainHome ? "automatica: " + state.launch.secondbrainHome : "SECONDBRAIN_HOME";
  input("s-pwsh").placeholder = state.launch?.pwsh ?? "pwsh";
}
$("s-save").addEventListener("click", async () => {
  const ok = await call<Settings>("save_settings", { secondbrainHome: input("s-home").value, pwshPath: input("s-pwsh").value }, "s-error");
  if (ok) { $("s-info").textContent = "Impostazioni salvate."; state.launch = await call<Launch>("get_launch_context"); probeAgents(); }
});

// 1. Repository
async function renderRecent() {
  const list = (await call<{ path: string; exists: boolean }[]>("list_recent_repos")) ?? [];
  $("recent-empty").hidden = list.length > 0;
  $("recent").replaceChildren(...list.map((r) => {
    const openBtn = el("button", { textContent: "Apri", disabled: !r.exists, title: r.path });
    openBtn.addEventListener("click", () => { input("repo-path").value = r.path; loadRepository(); });
    const removeBtn = el("button", { textContent: "Rimuovi", className: "ghost", title: "Togli dall'elenco (il checkout non viene toccato)" });
    removeBtn.dataset.remove = r.path;
    removeBtn.addEventListener("click", async () => {
      if (!confirm(`Togliere dall'elenco ${r.path}?\nIl checkout e il suo dossier non vengono toccati.`)) return;
      await call("remove_recent_repo", { path: r.path }, "repo-error");
      renderRecent();
    });
    const current = r.path === state.repo;
    return el("li", { className: current ? "current" : "" },
      el("span", { className: "recent-name" }, baseName(r.path)),
      el("span", { className: "muted small mono recent-path" }, r.path),
      r.exists ? (current ? el("span", { className: "tag" }, "in uso") : "") : el("span", { className: "tag warn" }, "non trovato"),
      openBtn, removeBtn);
  }));
}
$("repo-browse").addEventListener("click", async () => {
  const dir = await open({ directory: true, multiple: false, title: "Checkout del repository" });
  if (typeof dir === "string") input("repo-path").value = dir;
});
$("repo-load").addEventListener("click", () => loadRepository());
input("repo-path").addEventListener("keydown", (e) => { if (e.key === "Enter") loadRepository(); });

async function loadRepository(): Promise<boolean> {
  const path = input("repo-path").value.trim();
  if (!path) return false;
  setError("repo-error", null);
  $("repo-info").hidden = true;
  $<HTMLButtonElement>("repo-load").disabled = true;
  $("repo-load").textContent = "Caricamento…";
  try {
    const info = await call<{ repositories: { identity: string; dossier: string; tracker: string; agents: string }[] }>("resolve_repository", { path }, "repo-error");
    const repo = info?.repositories?.[0];
    if (!repo) {
      if (info) setError("repo-error", "Checkout non associato a un dossier SecondBrain attivo. Registralo con secondbrain.ps1 -AddRepo.");
      return false;
    }
    state.repo = path; state.identity = repo.identity;
    $("repo-label").textContent = repo.identity;
    $("repo-tracker").textContent = repo.tracker ?? "";
    const facts = $("repo-info");
    facts.replaceChildren(
      el("dt", {}, "Identità"), el("dd", {}, repo.identity),
      el("dt", {}, "Dossier"), el("dd", { className: "mono small" }, repo.dossier),
      el("dt", {}, "Tracker"), el("dd", { className: "mono small" }, repo.tracker ?? "—"),
      el("dt", {}, "AGENTS.md"), el("dd", { className: "mono small" }, repo.agents ?? "—"));
    facts.hidden = false;
    $("dir-agents").textContent = repo.agents ?? "AGENTS.md";
    await call("add_recent_repo", { path });
    renderRecent();
    resetRunView();
    updateSteps();
    await Promise.all([readDirectives(), refreshTasks(), checkExistingRun()]);
    return true;
  } finally {
    $<HTMLButtonElement>("repo-load").disabled = false;
    $("repo-load").textContent = "Carica";
  }
}

// 2. Directives
function setProposal(p: { proposalPath: string; proposalHash: string } | null, note = "") {
  state.proposal = p;
  $<HTMLButtonElement>("dir-apply").disabled = !p;
  $("dir-state").textContent = note;
}
$("dir-import").addEventListener("click", async () => {
  const file = await open({ multiple: false, title: "Testo delle direttive da importare", filters: [{ name: "Markdown", extensions: ["md"] }] });
  if (typeof file !== "string") return;
  const text = await call<string>("read_text_file", { path: file }, "dir-error");
  if (text === null) return;
  const area = $<HTMLTextAreaElement>("dir-text");
  if (area.value.trim() && !confirm("Sostituire il testo nell'editor con quello del file?")) return;
  area.value = text;
  setProposal(null, `Testo importato da ${file}: crea l'anteprima per proporlo.`);
});
$("dir-template").addEventListener("click", () => {
  const area = $<HTMLTextAreaElement>("dir-text");
  area.value = area.value.trim() ? area.value.trimEnd() + "\n\n" + DIRECTIVES_TEMPLATE : DIRECTIVES_TEMPLATE;
  setProposal(null, "Modello inserito: completa i segnaposto e crea l'anteprima.");
});
$("dir-reload").addEventListener("click", () => readDirectives());
$<HTMLTextAreaElement>("dir-text").addEventListener("input", () => { if (state.proposal) setProposal(null, "Testo modificato: l'anteprima precedente non vale più."); });
async function readDirectives() {
  if (!state.repo) return;
  const d = await call<{ managedBlock: string | null; dossierDirectives: string; agentsFile: string; dossierRelative: string }>("read_directives", { repo: state.repo }, "dir-error");
  if (!d) return;
  $<HTMLTextAreaElement>("dir-text").value = d.dossierDirectives ?? "";
  $("dir-target").textContent = d.dossierRelative ?? "AGENTS.managed.md";
  $("dir-agents").textContent = d.agentsFile || "AGENTS.md";
  $("dir-current").textContent = d.agentsFile ? ((await call<string>("read_text_file", { path: d.agentsFile })) ?? "") : "";
  $("dir-preview-box").hidden = true;
  setProposal(null, d.dossierDirectives ? "Testo attuale del dossier." : "Nessuna direttiva specifica nel dossier: usa il modello o importa un file.");
}
$("dir-preview").addEventListener("click", async () => {
  if (!state.repo) return;
  setError("dir-error", null);
  $("dir-state").textContent = "Preparazione della proposta…";
  const text = $<HTMLTextAreaElement>("dir-text").value;
  const r = await call<{ proposal: { proposalPath: string; proposalHash: string | null; preview: unknown } | null }>("preview_directives", { repo: state.repo, text }, "dir-error");
  if (!r?.proposal) { $("dir-state").textContent = ""; return; }
  $("dir-result").textContent = JSON.stringify(r.proposal.preview, null, 2);
  $("dir-preview-box").hidden = false;
  ($("dir-preview-box") as HTMLDetailsElement).open = true;
  if (r.proposal.proposalHash) setProposal({ proposalPath: r.proposal.proposalPath, proposalHash: r.proposal.proposalHash }, "Anteprima pronta: rileggila, poi approva e applica.");
  else setProposal(null, "L'anteprima non ha prodotto un hash di proposta: nessuna modifica da approvare (testo uguale all'attuale o proposta non valida, vedi l'anteprima).");
});
$("dir-apply").addEventListener("click", async () => {
  if (!state.proposal) return;
  if (!confirm("Approvi la proposta esaminata e allinei il blocco gestito del repository?")) return;
  const authorization = "Approvazione nell'orchestratore desktop " + new Date().toISOString();
  $("dir-state").textContent = "Approvazione e allineamento…";
  const r = await call<unknown>("apply_directives", { repo: state.repo, proposalPath: state.proposal.proposalPath, proposalHash: state.proposal.proposalHash, authorization }, "dir-error");
  if (r) {
    $("dir-result").textContent = JSON.stringify(r, null, 2);
    await readDirectives();
    setProposal(null, "Direttive approvate e allineate.");
  } else $("dir-state").textContent = "";
});

// 3. Queue: agents and models come from the installed CLIs only.
async function probeAgents() {
  $("q-agents-state").textContent = "Rilevamento degli agenti…";
  const r = await call<{ agents: AgentCaps[]; clients?: ClientInfo[] }>("probe_agents", {}, "q-error");
  if (!r) { $("q-agents-state").textContent = "Rilevamento non riuscito."; return; }
  state.agents = r.agents; state.clients = r.clients ?? [];
  const before = state.provider;
  if (!state.agents.some((a) => a.provider === state.provider && a.status === "ready")) state.provider = state.agents.find((a) => a.status === "ready")?.provider ?? "";
  renderAgents();
  // The task preview depends on the agent (computer-use filter): read it again when the default agent changed.
  // An empty choice previewed with the runner default (claude).
  if (state.repo && (before || "claude") !== (state.provider || "claude")) refreshTasks();
}
function renderAgents() {
  $("q-agents").replaceChildren(...state.agents.map((a) => {
    const ready = a.status === "ready";
    const radio = el("input", { type: "radio", name: "agent", value: a.provider, checked: a.provider === state.provider, disabled: !ready });
    radio.addEventListener("change", () => { state.provider = a.provider; renderAgentOptions(); refreshTasks(); });
    const meta = [a.version, a.origin ? ORIGIN_LABEL[a.origin] : "", ready && a.supports.streamJson ? "passi in tempo reale" : ""].filter(Boolean).join(" · ");
    return el("label", { className: "agent" + (ready ? "" : " off"), title: a.path ?? "" }, radio,
      el("span", { className: "agent-name" }, a.name),
      el("span", { className: "tag" + (ready ? " ok" : " warn") }, STATUS_LABEL[a.status] ?? a.status),
      el("span", { className: "muted small" }, meta));
  }));
  const ready = state.agents.filter((a) => a.status === "ready").length;
  $("q-agents-state").textContent = ready ? `${ready} agenti pronti su ${state.agents.length}.` : "Nessun agente pronto: installa Claude Code, Codex o Gemini CLI e premi «Rileva di nuovo».";
  $("q-clients").replaceChildren(...state.clients.map((c) => el("li", {}, el("strong", {}, c.name), " — ",
    c.runnable ? `pilotabile come ${c.provider}` : REASON_LABEL[c.reason ?? ""] ?? c.reason ?? "")));
  $("q-clients-box").hidden = state.clients.length === 0;
  renderAgentOptions();
}
function currentAgent(): AgentCaps | undefined { return state.agents.find((a) => a.provider === state.provider); }
function option(value: string, label: string) { return el("option", { value, textContent: label }); }
function renderAgentOptions() {
  const a = currentAgent();
  const model = select("q-model");
  if (!a) { model.replaceChildren(); select("q-effort").replaceChildren(); model.disabled = true; select("q-effort").disabled = true; return; }
  const def = "predefinito della CLI" + (a.configured.model ? " (" + a.configured.model + ")" : "");
  const previous = model.value;
  model.replaceChildren(option("", def), ...(a.supports.model ? a.models.map((m) => option(m.id, m.label + " · " + SOURCE_LABEL[m.source])) : []));
  model.value = a.models.some((m) => m.id === previous) ? previous : "";
  model.disabled = !a.supports.model;
  input("q-custom-on").disabled = !a.supports.model;
  if (!a.supports.model) { input("q-custom-on").checked = false; input("q-custom").hidden = true; }
  renderEffortOptions();
}
function chosenModel(): string {
  const a = currentAgent();
  return (input("q-custom-on").checked ? input("q-custom").value.trim() : "") || select("q-model").value || a?.configured.model || "";
}
function renderEffortOptions() {
  const a = currentAgent();
  const effort = select("q-effort");
  if (!a) return;
  const perModel = a.models.find((m) => m.id === chosenModel() && m.efforts.length);
  const levels = perModel ? perModel.efforts.map((id) => ({ id, source: perModel.source })) : a.efforts;
  const def = "predefinito" + (a.configured.effort ? " (" + a.configured.effort + ")" : "");
  effort.replaceChildren(option("", def), ...(a.supports.effort ? levels.map((l) => option(l.id, l.id + " · " + SOURCE_LABEL[l.source])) : []));
  effort.disabled = !a.supports.effort;
}
select("q-model").addEventListener("change", renderEffortOptions);
input("q-custom-on").addEventListener("change", () => { input("q-custom").hidden = !input("q-custom-on").checked; renderEffortOptions(); });
input("q-custom").addEventListener("input", renderEffortOptions);
$("q-reprobe").addEventListener("click", () => probeAgents());
$("q-refresh").addEventListener("click", () => refreshTasks());
$("q-all").addEventListener("click", () => { state.tasks.forEach((t) => state.selected.add(t.id)); renderTasks(); });
$("q-none").addEventListener("click", () => { state.selected.clear(); renderTasks(); });

async function refreshTasks() {
  if (!state.repo) return;
  $("q-count").textContent = "Lettura del tracker…";
  const r = await call<{ tasks: PreviewTask[]; skipped: Skipped[] }>("list_tasks", { repo: state.repo, provider: state.provider || null }, "q-error");
  if (!r) { $("q-count").textContent = ""; return; }
  state.tasks = r.tasks ?? [];
  // Nothing is preselected (#517): the person opts in task by task, or with "Seleziona tutti".
  state.selected = new Set<string>();
  renderTasks();
  const skipped = (r.skipped ?? []).filter((s) => s.id);
  $("q-skipped-count").textContent = String(skipped.length);
  $("q-skipped").replaceChildren(...skipped.map((s) => el("li", {}, `${s.id} — ${s.reason}`)));
}
function renderTasks() {
  const order = state.tasks;
  $("q-empty").hidden = order.length > 0;
  $("q-count").textContent = order.length ? `${state.selected.size} selezionati su ${order.length}` : "";
  $("q-tasks").replaceChildren(...order.map((t, i) => {
    const cb = el("input", { type: "checkbox", checked: state.selected.has(t.id) });
    cb.setAttribute("aria-label", "Seleziona " + t.id);
    cb.addEventListener("change", () => { cb.checked ? state.selected.add(t.id) : state.selected.delete(t.id); $("q-count").textContent = `${state.selected.size} selezionati su ${order.length}`; });
    const up = el("button", { textContent: "↑", disabled: i === 0, title: "Sposta su", className: "ghost" });
    up.addEventListener("click", () => { [order[i - 1], order[i]] = [order[i], order[i - 1]]; renderTasks(); });
    const tr = el("tr");
    [cb, String(t.seq), t.id, t.title, t.priority ?? "—", up].forEach((c) => tr.append(el("td", {}, c)));
    return tr;
  }));
}
$("q-start").addEventListener("click", async () => {
  if (state.run.active || state.run.starting) return selectTab("run");
  // Model, effort and defaults are read again now: the probe at window start can be stale (CLI updated or reconfigured since).
  const chosen = { model: select("q-model").value, effort: select("q-effort").value, provider: state.provider };
  await probeAgents();
  if (state.provider === chosen.provider) {
    if ([...select("q-model").options].some((o) => o.value === chosen.model)) select("q-model").value = chosen.model;
    renderEffortOptions();
    if ([...select("q-effort").options].some((o) => o.value === chosen.effort)) select("q-effort").value = chosen.effort;
  }
  const a = currentAgent();
  const taskIds = state.tasks.filter((t) => state.selected.has(t.id)).map((t) => t.id);
  if (!state.repo || !a || !taskIds.length) return setError("q-error", "Scegli un agente pronto e almeno un task.");
  const custom = input("q-custom-on").checked ? input("q-custom").value.trim() : "";
  const request = {
    repo: state.repo, provider: a.provider,
    model: custom || select("q-model").value || null,
    effort: select("q-effort").value || null,
    allowCustomModel: Boolean(custom),
    taskIds, timeoutMinutes: Number(input("q-timeout").value) || 30, stallMinutes: Number(input("q-stall").value) || 5,
  };
  const shownModel = request.model ?? (a.configured.model ? `predefinito della CLI (${a.configured.model})` : "predefinito della CLI");
  const shownEffort = !a.supports.effort ? "impegno non regolabile" : request.effort ?? (a.configured.effort ? `impegno predefinito (${a.configured.effort})` : "impegno predefinito");
  if (!confirm(`Avviare ${taskIds.length} task con ${a.name} · ${shownModel} · ${shownEffort}?\nModello e impegno letti ora dalla CLI installata.\nGli agenti modificano file nel checkout; commit, push e cancellazioni sono vietati.`)) return;
  resetRunView();
  const r = await call<{ pid: number; log: string }>("start_queue", { request }, "q-error");
  if (!r) return;
  state.run.starting = true; state.run.pid = r.pid;
  setVerdict("starting");
  appendLog(`Runner avviato (PID ${r.pid}); in attesa del suo stato…`);
  selectTab("run");
  updateSteps();
  // The run folder appears once the runner has read the tracker: look for the status written by this process.
  window.clearInterval(state.timers.find);
  state.timers.find = window.setInterval(async () => {
    const rep = await call<RunReport>("get_run_status", { repo: state.repo, tail: 0 });
    if (rep?.status && rep.status.pid === state.run.pid && rep.folder) { window.clearInterval(state.timers.find); attachRun(rep); }
  }, 1500);
});

// 4. Run: status card from status.json, steps and results from events.jsonl.
function setVerdict(v: string) {
  state.run.verdict = v;
  for (const id of ["run-verdict", "run-badge"]) { const b = $(id); b.dataset.verdict = v; b.textContent = VERDICT_LABEL[v] ?? v; }
}
function resetRunView() {
  stopPolling();
  state.run = { active: false, starting: false, pid: 0, folder: "", offset: 0, startedAt: "", status: null, verdict: "idle" };
  setVerdict("idle");
  $("run-task").textContent = "Nessun task in corso";
  for (const id of ["run-elapsed", "run-last", "run-counts", "run-folder"]) $(id).textContent = "—";
  $("run-steps").replaceChildren(); $("run-results").replaceChildren(); $("run-log").textContent = "";
  $("run-warning").hidden = true; setError("run-error", null);
}
function stopPolling() {
  window.clearInterval(state.timers.events); window.clearInterval(state.timers.status); window.clearInterval(state.timers.clock); window.clearInterval(state.timers.find);
}
function appendLog(line: string) {
  const log = $("run-log");
  log.textContent += line + "\n";
  log.scrollTop = log.scrollHeight;
}
function addResult(r: RunRecord) {
  const badge = el("span", { className: "state-" + r.state }, r.state + (r.parked ? " (parcheggiato)" : ""));
  const tr = el("tr");
  [String(r.seq), r.id, badge, `${r.statusBefore} → ${r.statusAfter}`, String(r.seconds), el("span", { className: "mono small" }, r.folder)].forEach((c) => tr.append(el("td", {}, c)));
  $("run-results").append(tr);
}
function addStep(ev: EventJson) {
  const time = ev.time ? new Date(ev.time).toLocaleTimeString() : "";
  const steps = $("run-steps");
  steps.append(el("li", { className: "step-" + (ev.kind ?? "text") }, el("span", { className: "muted small" }, time), " ", el("span", { className: "tag" }, ev.kind ?? ""), " ", ev.summary ?? ""));
  while (steps.childElementCount > 300) steps.firstElementChild?.remove();
  steps.lastElementChild?.scrollIntoView({ block: "nearest" });
}
function handleEvent(e: RunnerEvent) {
  const ev = e.json;
  if (!ev) { appendLog(e.line); return; }
  if (ev.event !== "agent") appendLog(ev.message ?? e.line);
  switch (ev.event) {
    case "agent": addStep(ev); break;
    case "start": $("run-warning").hidden = true; break;
    case "done": if (ev.record) addResult(ev.record); break;
    case "stalled": $("run-warning").textContent = ev.message ?? "Possibile stallo dell'agente."; $("run-warning").hidden = false; break;
  }
}
function renderStatus(rep: RunReport) {
  const s = rep.status;
  state.run.status = s;
  setVerdict(rep.verdict);
  if (!s) return;
  state.run.startedAt = s.startedAt;
  $("run-folder").textContent = rep.folder ?? s.folder ?? "—";
  $("run-counts").textContent = `${s.counts.done} di ${s.counts.total} task (${s.counts.succeeded} riusciti, ${s.counts.failed} non riusciti)` + (s.stopReason ? ` · arresto: ${s.stopReason}${!rep.active && s.finishedAt ? " (run chiuso il " + new Date(s.finishedAt).toLocaleString() + ")" : ""}` : "") + (s.quota ? ` · quota letta: ${s.quota.state}${s.quota.resetAt ? " fino a " + new Date(s.quota.resetAt).toLocaleString() : ""}` : "");
  $("run-task").textContent = s.task ? `[${s.task.position}/${s.task.total}] #${s.task.seq} ${s.task.id} — ${s.task.title}` : rep.active ? `Fase: ${s.phase}` : "Nessun task in corso";
  renderClock();
}
function renderClock() {
  const s = state.run.status;
  if (!s) return;
  const end = s.finishedAt && !state.run.active ? Date.parse(s.finishedAt) : Date.now();
  $("run-elapsed").textContent = fmtDuration((end - Date.parse(s.startedAt)) / 1000);
  const last = s.lastAgentEventAt ?? s.task?.startedAt ?? null;
  $("run-last").textContent = state.run.active && last ? `${fmtDuration(since(last))} fa` + (s.lastAgentEvent ? ` · ${s.lastAgentEvent.kind}: ${s.lastAgentEvent.summary}` : "") : s.lastAgentEvent ? `${s.lastAgentEvent.kind}: ${s.lastAgentEvent.summary}` : "—";
}
async function pullEvents() {
  if (!state.run.folder) return;
  const r = await call<{ events: RunnerEvent[]; offset: number }>("read_run_events", { folder: state.run.folder, offset: state.run.offset });
  if (!r) return;
  state.run.offset = r.offset;
  r.events.forEach(handleEvent);
  // The last agent step refreshes the card at once, without waiting for the next status read.
  const lastAgent = [...r.events].reverse().find((e) => e.json?.event === "agent")?.json;
  if (lastAgent && state.run.status) { state.run.status.lastAgentEventAt = lastAgent.time ?? null; state.run.status.lastAgentEvent = { kind: lastAgent.kind ?? "", summary: lastAgent.summary ?? "", time: lastAgent.time ?? "" }; renderClock(); }
}
async function pullStatus() {
  if (!state.repo) return;
  const rep = await call<RunReport>("get_run_status", { repo: state.repo, tail: 0 }, "run-error");
  if (!rep) return;
  if (rep.folder && rep.folder !== state.run.folder && rep.active) { attachRun(rep); return; }
  renderStatus(rep);
  if (!rep.active) await finishRun(rep);
}
async function finishRun(rep: RunReport) {
  if (!state.run.active) return;
  await pullEvents();
  state.run.active = false; state.run.starting = false;
  stopPolling();
  renderStatus(rep);
  if (rep.verdict === "orphaned") {
    $("run-warning").textContent = "Il runner si è interrotto senza chiudere il run (processo terminato o arresto forzato).";
    $("run-warning").hidden = false;
  }
  appendLog("Run concluso: " + (VERDICT_LABEL[rep.verdict] ?? rep.verdict));
  updateSteps();
  refreshTasks();
}
function attachRun(rep: RunReport) {
  // Follow a run from the start of its events: one started here, or one found again after the window was reopened.
  stopPolling();
  state.run.active = true; state.run.starting = false;
  state.run.folder = rep.folder ?? ""; state.run.offset = 0;
  if (rep.status) state.run.pid = rep.status.pid;
  $("run-steps").replaceChildren(); $("run-results").replaceChildren(); $("run-log").textContent = "";
  renderStatus(rep);
  pullEvents();
  state.timers.events = window.setInterval(pullEvents, 1000);
  state.timers.status = window.setInterval(pullStatus, 4000);
  state.timers.clock = window.setInterval(renderClock, 1000);
  updateSteps();
}
async function checkExistingRun() {
  const rep = await call<RunReport>("get_run_status", { repo: state.repo, tail: 0 });
  if (!rep) return;
  if (rep.active && rep.folder) { attachRun(rep); appendLog("Run in corso ritrovato e riagganciato."); selectTab("run"); }
  else if (rep.status) renderStatus(rep);
}
$("run-refresh").addEventListener("click", () => pullStatus());
$("run-stop").addEventListener("click", async () => {
  if (!state.run.active && !state.run.starting) return setError("run-error", "Nessuna coda in esecuzione.");
  const ok = await call<boolean>("stop_queue", { repo: state.repo, force: false }, "run-error");
  if (ok) appendLog("Arresto richiesto: la coda si ferma dopo il task corrente.");
});
$("run-abort").addEventListener("click", async () => {
  if (!state.run.active && !state.run.starting) return setError("run-error", "Nessuna coda in esecuzione.");
  if (!confirm("Interrompere subito l'agente in corso? Il task resta nello stato lasciato dall'agente.")) return;
  const ok = await call<boolean>("stop_queue", { repo: state.repo, force: true }, "run-error");
  if (ok) { appendLog("Interruzione immediata richiesta."); window.setTimeout(pullStatus, 1500); }
});

listen<{ code: number | null; pid: number; log: string; stdout: string }>("runner-finished", async (e) => {
  if (e.payload.pid !== state.run.pid) return;
  window.clearInterval(state.timers.find);
  if (!state.run.folder) {
    // Ended before writing its status (busy repository, invalid model, missing agent): show why.
    state.run.starting = false;
    setVerdict("idle");
    setError("run-error", `Il runner è terminato (uscita ${e.payload.code}) prima di avviare il run.\n${e.payload.log}`);
    updateSteps();
    return;
  }
  await pullStatus();
});

// Closing with a run in progress asks what to do; the runner itself is detached and survives the window.
const dialog = $<HTMLDialogElement>("close-dialog");
async function closeWindow() { await getCurrentWindow().destroy(); }
dialog.querySelectorAll<HTMLButtonElement>("button[data-close]").forEach((b) => b.addEventListener("click", async () => {
  const action = b.dataset.close;
  if (action === "cancel") return dialog.close();
  if (action === "abort" && !confirm("Interrompere subito l'agente in corso?")) return;
  if (action === "stop" || action === "abort") await call("stop_queue", { repo: state.repo, force: action === "abort" });
  dialog.close();
  await closeWindow();
}));
getCurrentWindow().onCloseRequested((event) => {
  if (state.run.active || state.run.starting) { event.preventDefault(); dialog.showModal(); }
});
// Hook for the end-to-end tests: the same close request the window title bar sends.
(window as unknown as { sbOrchestrator: object }).sbOrchestrator = { requestClose: () => getCurrentWindow().close() };

async function start() {
  state.launch = await call<Launch>("get_launch_context");
  if (state.launch) {
    $("app-version").textContent = "v" + state.launch.version;
    if (state.launch.rootError) setError("repo-error", state.launch.rootError);
  }
  await loadSettings();
  await renderRecent();
  updateSteps();
  probeAgents();
  // Preload: the repository passed by sb runner, otherwise the most recent one that still exists.
  const recent = (await call<{ path: string; exists: boolean }[]>("list_recent_repos")) ?? [];
  const target = state.launch?.repo ?? recent.find((r) => r.exists)?.path ?? "";
  if (target) {
    input("repo-path").value = target;
    const ok = await loadRepository();
    // Opened by sb runner: straight to the queue; agents keep loading in place.
    if (ok && state.launch?.repo && !state.run.active && !navigated) selectTab("queue");
  }
}
start();
