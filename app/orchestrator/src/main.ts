// SecondBrain Orchestrator UI: a thin shell over the SecondBrain PowerShell CLIs (agents.ps1, run-ready-tasks.ps1, runner-status.ps1, prompts.ps1).
// Every write goes through those scripts; the UI only collects choices and shows their JSON results. A run is followed through its
// status.json and events.jsonl, so it can be found again after the window is closed and reopened.
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { open } from "@tauri-apps/plugin-dialog";
import { $, busy, call, el, fmtDuration, onBusyClick, input, option, select, setError, since, baseName, type AgentCaps, type AgentStatus, type LightChoice, type Source } from "./common";
import { initRegistry, showRegistry } from "./registry";
import { analyzeMany, analyzeTask, initAnalysis, openAnalysis, storedAnalysis, verdictOf, VERDICT_LABEL } from "./analysis";

interface ClientInfo { name: string; confidence: string; provider: string | null; runnable: boolean; reason: string | null }
interface PreviewTask { id: string; seq: number; priority: string | null; title: string }
interface Skipped { id?: string; seq?: number | null; reason: string; repository?: string; title?: string; status?: string; execution?: string; stateReason?: string; awaiting?: string }
interface RunRecord { id: string; seq: number; state: string; exitCode: number | null; statusBefore: string; statusAfter: string; seconds: number; folder: string; parked: boolean | string }
interface Settings { secondbrainHome: string; pwshPath: string; recentRepos: string[]; lightProvider?: string; lightModel?: string; lightEffort?: string }
interface DirectiveCounts { global: number; common: number; dossier: number; agentsOutside: number; composed: number; loaded: number; budget: number; percent: number }
interface DirectivesRead {
  managedBlock: string | null; dossierDirectives: string; agentsFile: string; dossierRelative: string;
  globalBlock?: string; commonBlock?: string; agentsOutside?: string; composedPreview?: string; counts?: DirectiveCounts;
}
interface DirectivesProposal {
  provider: string; model: string | null; effort: string | null; role: string; seconds: number; attempts: number; markdown: string; portable: boolean;
  sections: { title: string; body: string; rationale: string; sources: string[] }[]; coveredElsewhere: { topic: string; where: string }[]; warnings: string[]; counts: DirectiveCounts;
}
interface Launch { repo: string | null; secondbrainHome: string | null; rootError: string | null; pwsh: string; version: string }
interface RunStatusFile {
  state: string; phase: string; pid: number; startedAt: string; updatedAt: string; finishedAt: string | null;
  lastAgentEventAt: string | null; lastAgentEvent: { kind: string; summary: string; time: string } | null;
  task: { id: string; seq: number; title: string; position: number; total: number; startedAt: string; folder: string } | null;
  counts: { total: number; done: number; succeeded: number; failed: number }; stopReason: string | null; stallMinutes: number; folder: string; quota?: { state: string; source: string; resetAt?: string | null } | null;
  quotaWait?: { resumeAt: string; source: string; since: string; attempt: number; deadline: string; taskId: string } | null;
}
/** The newest resume point a quota stop left and no run used yet (runner-status.ps1, #554): run-ready-tasks.ps1 -Resume <runId> continues it. */
interface ResumePoint {
  runId: string; path: string; reason: string; stoppedAt: string | null; provider: string; model: string | null; effort: string | null;
  interrupted: { id: string; seq: number | null } | null; remaining: string[]; resetAt: string | null;
}
interface RunReport { active: boolean; verdict: "working" | "stalled" | "waiting" | "finished" | "orphaned" | "none"; folder?: string; status: RunStatusFile | null; resume?: ResumePoint | null }
interface QueueRequest {
  repo: string; provider: string; model: string | null; effort: string | null; allowCustomModel: boolean; taskIds: string[];
  timeoutMinutes: number; stallMinutes: number; waitForReset: boolean; maxWaitHours: number; resume?: string; allowNoPowerRequest?: boolean;
}
interface EventJson { event?: string; message?: string; time?: string; record?: RunRecord; kind?: string; summary?: string; minutes?: number }
interface RunnerEvent { line: string; json: EventJson | null }

const state = {
  settings: null as Settings | null,
  directives: null as DirectivesRead | null,
  directiveProposal: null as DirectivesProposal | null,
  skipped: [] as Skipped[],
  skippedSelected: new Set<string>(),
  analyzing: false,
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

const WAIT_SOURCE_LABEL: Record<string, string> = { "runner-observation": "segnalato dall'agente", "codex-session": "dalle sessioni di Codex", message: "dal messaggio di limite", recheck: "orario non noto: nuovo controllo" };
const RUN_VERDICT_LABEL: Record<string, string> = {
  idle: "Inattivo", starting: "Avvio…", working: "In lavoro", stalled: "Possibile stallo", waiting: "In attesa del ripristino", finished: "Concluso", orphaned: "Interrotto", none: "Inattivo",
};
const STATUS_LABEL: Record<AgentStatus, string> = { ready: "pronto", "not-found": "non installato", "not-responding": "non risponde" };
const ORIGIN_LABEL: Record<string, string> = { path: "", search: "trovato fuori dal PATH", package: "dal pacchetto Store" };
const SOURCE_LABEL: Record<Source, string> = { probe: "dalla CLI", config: "dalla configurazione", fallback: "tabella di riserva" };
const REASON_LABEL: Record<string, string> = { "no-headless-cli": "nessuna CLI pilotabile dal runner", "cli-not-found": "CLI non installata", "cli-not-responding": "CLI non risponde" };
const STATUS_TEXT: Record<string, string> = { blocked: "bloccato", unknown: "stato sconosciuto", in_progress: "in corso", done: "fatto", cancelled: "annullato" };
/** Readable reason of a runner exclusion (stable codes from SecondBrain.TaskRunner.psm1 and run-ready-tasks.ps1). */
function reasonText(code: string): string {
  const [kind, value = ""] = code.split(/:(.*)/s, 2);
  switch (kind) {
    case "execution": return value === "user_required" ? "richiede la persona (user_required)" : "modalità di esecuzione non indicata";
    case "status": return STATUS_TEXT[value] ?? "stato " + value;
    case "stream": return "flusso escluso dal runner: " + value;
    case "awaiting": return "in attesa: " + value;
    case "requires": return "richiede l'uso del computer";
    case "dependency": return "dipende da " + value.split(",").join(", ");
    case "not-ready": return "non pronto (dipendenze o stato)";
    case "not-queued": return "non in coda";
    case "max-tasks": return "oltre il limite di task";
    default: return code;
  }
}
/** Exclusions that an analysis can change; excluded streams and queue cuts stay with the runner rules. */
function analyzable(code: string): boolean { return /^(execution|status|awaiting|requires|dependency|not-ready)/.test(code) && !/^status:(done|cancelled|in_progress)/.test(code); }

// Steps
function selectTab(name: string) {
  document.querySelectorAll<HTMLButtonElement>(".steps button[data-tab]").forEach((b) => b.setAttribute("aria-selected", String(b.dataset.tab === name)));
  document.querySelectorAll<HTMLElement>(".panel").forEach((p) => (p.hidden = p.id !== "tab-" + name));
  if (name === "registry") showRegistry();
}
function updateSteps() {
  const loaded = Boolean(state.repo);
  const tab = (n: string) => document.querySelector<HTMLButtonElement>(`.steps button[data-tab="${n}"]`)!;
  tab("directives").disabled = !loaded;
  tab("queue").disabled = !loaded;
  tab("run").disabled = !loaded && !state.run.active;
  tab("registry").disabled = !loaded;
  tab("repo").classList.toggle("done", loaded);
  tab("queue").classList.toggle("done", state.run.active || state.run.verdict === "finished");
  $<HTMLButtonElement>("repo-next").disabled = !loaded;
}
// A tab chosen by the person is never overridden by the startup preload.
let navigated = false;
document.querySelectorAll<HTMLButtonElement>(".steps button[data-tab]").forEach((b) => b.addEventListener("click", () => { if (!b.disabled) { navigated = true; selectTab(b.dataset.tab!); } }));
$("repo-next").addEventListener("click", () => selectTab("directives"));
$("dir-next").addEventListener("click", () => selectTab("queue"));
$("run-registry").addEventListener("click", () => selectTab("registry"));

// Settings
async function loadSettings() {
  const s = await call<Settings>("get_settings", {}, "s-error");
  if (!s) return;
  state.settings = s;
  input("s-home").value = s.secondbrainHome;
  input("s-pwsh").value = s.pwshPath;
  input("s-home").placeholder = state.launch?.secondbrainHome ? "automatica: " + state.launch.secondbrainHome : "SECONDBRAIN_HOME";
  input("s-pwsh").placeholder = state.launch?.pwsh ?? "pwsh";
  renderLightSettings();
}
// Light model of the one-shot analyses: saved in the window settings; empty = agent of the queue with its light role.
function currentLight(): LightChoice | null {
  const s = state.settings;
  const provider = s?.lightProvider || state.provider;
  const a = state.agents.find((x) => x.provider === provider && x.status === "ready");
  if (!a) return null;
  const explicit = Boolean(s?.lightProvider) && s?.lightProvider === provider;
  const model = explicit ? s?.lightModel ?? "" : "";
  const effort = explicit ? s?.lightEffort ?? "" : "";
  const shownModel = model || a.light?.model || (a.configured.model ? `predefinito della CLI (${a.configured.model})` : "predefinito della CLI");
  const shownEffort = effort || a.light?.effort || "";
  return { provider, model, effort, label: `${a.name} · ${shownModel}${shownEffort ? " · " + shownEffort : ""}` };
}
function renderLightLabels() {
  const l = currentLight();
  const text = l ? `Analisi con ${l.label} (modello leggero, sola lettura).` : "Nessun agente pronto per le analisi.";
  $("dir-light").textContent = text;
  $("q-light").textContent = text;
  $<HTMLButtonElement>("dir-propose").disabled = !l || !state.repo;
  $<HTMLButtonElement>("dir-propose").title = l ? "" : "Installa o rileva un agente (Coda → Rileva di nuovo) oppure scegli il modello leggero nelle impostazioni.";
}
function renderLightSettings() {
  const s = state.settings;
  const prov = select("s-light-provider");
  prov.replaceChildren(option("", "Agente scelto nella coda"), ...state.agents.filter((a) => a.status === "ready").map((a) => option(a.provider, a.name)));
  prov.value = s?.lightProvider && [...prov.options].some((o) => o.value === s.lightProvider) ? s.lightProvider : "";
  renderLightModelOptions();
  renderLightLabels();
}
function renderLightModelOptions() {
  const s = state.settings;
  const a = state.agents.find((x) => x.provider === select("s-light-provider").value);
  const model = select("s-light-model"), effort = select("s-light-effort");
  const lightDefault = a?.light?.model ? `leggero predefinito (${a.light.model})` : "leggero predefinito";
  model.replaceChildren(option("", lightDefault), ...(a?.supports.model ? a.models.map((m) => option(m.id, m.label)) : []));
  if (a?.light?.model && ![...model.options].some((o) => o.value === a.light!.model)) model.append(option(a.light.model, a.light.model));
  effort.replaceChildren(option("", a?.light?.effort ? `predefinito (${a.light.effort})` : "predefinito"), ...(a?.supports.effort ? a.efforts.map((e) => option(e.id, e.id)) : []));
  model.disabled = effort.disabled = !a;
  if (a && s?.lightProvider === a.provider) {
    if ([...model.options].some((o) => o.value === s.lightModel)) model.value = s.lightModel ?? "";
    if ([...effort.options].some((o) => o.value === s.lightEffort)) effort.value = s.lightEffort ?? "";
  }
}
select("s-light-provider").addEventListener("change", renderLightModelOptions);
onBusyClick($("s-light-save"), async () => {
  const provider = select("s-light-provider").value;
  const s = await call<Settings>("save_light_model", { provider, model: provider ? select("s-light-model").value : "", effort: provider ? select("s-light-effort").value : "" }, "s-error");
  if (s) { state.settings = s; $("s-light-info").textContent = "Modello leggero salvato."; renderLightLabels(); }
});
onBusyClick($("s-save"), async () => {
  const ok = await call<Settings>("save_settings", { secondbrainHome: input("s-home").value, pwshPath: input("s-pwsh").value }, "s-error");
  if (ok) { $("s-info").textContent = "Impostazioni salvate."; state.launch = await call<Launch>("get_launch_context"); probeAgents(); }
});

// 1. Repository
async function renderRecent() {
  const list = (await call<{ path: string; exists: boolean }[]>("list_recent_repos")) ?? [];
  $("recent-empty").hidden = list.length > 0;
  $("recent").replaceChildren(...list.map((r) => {
    const openBtn = el("button", { textContent: "Apri", disabled: !r.exists, title: r.path });
    onBusyClick(openBtn, () => { input("repo-path").value = r.path; return loadRepository(); });
    const removeBtn = el("button", { textContent: "Rimuovi", className: "ghost", title: "Togli dall'elenco (il checkout non viene toccato)" });
    removeBtn.dataset.remove = r.path;
    onBusyClick(removeBtn, async () => {
      if (!confirm(`Togliere dall'elenco ${r.path}?\nIl checkout e il suo dossier non vengono toccati.`)) return;
      await call("remove_recent_repo", { path: r.path }, "repo-error");
      await renderRecent();
    });
    const current = r.path === state.repo;
    return el("li", { className: current ? "current" : "" },
      el("span", { className: "recent-name" }, baseName(r.path)),
      el("span", { className: "muted small mono recent-path" }, r.path),
      r.exists ? (current ? el("span", { className: "tag" }, "in uso") : "") : el("span", { className: "tag warn" }, "non trovato"),
      openBtn, removeBtn);
  }));
}
onBusyClick($("repo-browse"), async () => {
  const dir = await open({ directory: true, multiple: false, title: "Checkout del repository" });
  if (typeof dir === "string") input("repo-path").value = dir;
});
$("repo-load").addEventListener("click", () => loadRepository());
input("repo-path").addEventListener("keydown", (e) => { if (e.key === "Enter") loadRepository(); });

async function loadRepository(): Promise<boolean> {
  const path = input("repo-path").value.trim();
  if (!path) return false;
  // Spinner on «Carica» whoever starts the load (button, Enter, recent list, startup); a second load while one runs is ignored.
  return (await busy($<HTMLButtonElement>("repo-load"), () => doLoadRepository(path), "Caricamento…")) ?? false;
}
async function doLoadRepository(path: string): Promise<boolean> {
  setError("repo-error", null);
  $("repo-info").hidden = true;
  {
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
  }
}

// 2. Directives
function setProposal(p: { proposalPath: string; proposalHash: string } | null, note = "") {
  state.proposal = p;
  $<HTMLButtonElement>("dir-apply").disabled = !p;
  $("dir-state").textContent = note;
}
onBusyClick($("dir-import"), async () => {
  const file = await open({ multiple: false, title: "Testo delle direttive da importare", filters: [{ name: "Markdown", extensions: ["md"] }] });
  if (typeof file !== "string") return;
  const text = await call<string>("read_text_file", { path: file }, "dir-error");
  if (text === null) return;
  const area = $<HTMLTextAreaElement>("dir-text");
  if (area.value.trim() && !confirm("Sostituire il testo nell'editor con quello del file?")) return;
  area.value = text;
  setProposal(null, `Testo importato da ${file}: crea l'anteprima per proporlo.`);
});
// Proposal of the light model (agents.ps1 -Analyze -Kind directives, DOC06): it surveys the checkout read-only and proposes only what the
// global block, the common block and AGENTS.md do not already say. The text reaches the editor only when the person chooses so.
onBusyClick($("dir-propose"), async () => {
  const l = currentLight();
  if (!state.repo || !l) return;
  setError("dir-error", null);
  $("dir-state").textContent = `Ricognizione del repository con ${l.label}: può richiedere qualche minuto…`;
  const started = Date.now();
  const r = await call<DirectivesProposal>("analyze_directives", { repo: state.repo, provider: l.provider, model: l.model || null, effort: l.effort || null }, "dir-error");
  if (!r) { $("dir-state").textContent = ""; return; }
  state.directiveProposal = r;
  $("dir-state").textContent = `Proposta pronta in ${fmtDuration((Date.now() - started) / 1000)}: rileggila e scegli se usarla.`;
  renderDirectiveProposal(r);
});
function renderDirectiveProposal(r: DirectivesProposal) {
  const box = $("dir-analysis");
  box.hidden = false;
  $("dir-analysis-meta").textContent = `${r.provider}${r.model ? " · " + r.model : ""}${r.effort ? " · " + r.effort : ""} · ${r.sections.length} sezioni · ${r.markdown.length} caratteri` + (r.attempts > 1 ? ` · ${r.attempts} tentativi` : "");
  $("dir-sections").replaceChildren(...r.sections.map((s) => el("li", {},
    el("strong", {}, s.title), el("pre", { className: "box small" }, s.body),
    el("div", { className: "muted small" }, s.rationale), s.sources.length ? el("div", { className: "muted small mono" }, "Fonti: " + s.sources.join(", ")) : "")));
  const warnings = [...r.warnings, ...(r.portable ? [] : ["Il testo contiene percorsi assoluti, commenti secondbrain o segnaposto {{ }}: l'anteprima lo rifiuterà finché non li togli."])];
  $("dir-warnings").hidden = warnings.length === 0;
  $("dir-warnings").textContent = warnings.join(" · ");
  $("dir-covered-count").textContent = String(r.coveredElsewhere.length);
  const where: Record<string, string> = { global: "direttive globali", common: "blocco comune", dossier: "direttive attuali del dossier", "agents-md": "AGENTS.md" };
  $("dir-covered").replaceChildren(...r.coveredElsewhere.map((c) => el("li", {}, `${c.topic} — ${where[c.where] ?? c.where}`)));
}
function useDirectiveProposal(append: boolean) {
  const r = state.directiveProposal;
  if (!r) return;
  const area = $<HTMLTextAreaElement>("dir-text");
  area.value = append && area.value.trim() ? area.value.trimEnd() + "\n\n" + r.markdown : r.markdown;
  $("dir-analysis").hidden = true;
  updateComposed();
  setProposal(null, "Proposta inserita nell'editor: rileggila, correggila se serve e crea l'anteprima.");
}
$("dir-use").addEventListener("click", () => useDirectiveProposal(false));
$("dir-append").addEventListener("click", () => useDirectiveProposal(true));
$("dir-discard").addEventListener("click", () => { state.directiveProposal = null; $("dir-analysis").hidden = true; $("dir-state").textContent = "Proposta scartata."; });
onBusyClick($("dir-reload"), () => readDirectives());
$<HTMLTextAreaElement>("dir-text").addEventListener("input", () => { updateComposed(); if (state.proposal) setProposal(null, "Testo modificato: l'anteprima precedente non vale più."); });
/** Repository block composed with the editor text and the characters every session loads (global + AGENTS.md outside + repository block). */
function updateComposed() {
  const d = state.directives;
  if (!d?.counts) return;
  const text = $<HTMLTextAreaElement>("dir-text").value.trim();
  const base = (d.composedPreview ?? "").slice(0, Math.max(0, (d.composedPreview ?? "").length - (d.dossierDirectives ?? "").trim().length)).trimEnd();
  const composed = [base, text].filter(Boolean).join("\n\n");
  $("dir-composed").textContent = composed;
  $("dir-composed-count").textContent = composed.length.toLocaleString();
  const loaded = d.counts.global + d.counts.agentsOutside + composed.length;
  const pct = Math.round((1000 * loaded) / d.counts.budget) / 10;
  $("dir-budget-box").hidden = false;
  const fill = $("dir-budget-fill");
  fill.style.width = Math.min(100, pct) + "%";
  fill.dataset.level = pct >= 80 ? "high" : pct >= 50 ? "mid" : "low";
  $("dir-budget").textContent = `Direttive caricate a ogni sessione: ${loaded.toLocaleString()} di ${d.counts.budget.toLocaleString()} caratteri del tetto di avvio (${pct}%) — globali ${d.counts.global.toLocaleString()}, AGENTS.md fuori dai blocchi ${d.counts.agentsOutside.toLocaleString()}, blocco di repository ${composed.length.toLocaleString()}. Il pacchetto di avvio del dossier si aggiunge a queste.`;
}
async function readDirectives() {
  if (!state.repo) return;
  const d = await call<DirectivesRead>("read_directives", { repo: state.repo }, "dir-error");
  if (!d) return;
  state.directives = d;
  $<HTMLTextAreaElement>("dir-text").value = d.dossierDirectives ?? "";
  $("dir-target").textContent = d.dossierRelative ?? "AGENTS.managed.md";
  $("dir-agents").textContent = d.agentsFile || "AGENTS.md";
  $("dir-current").textContent = d.agentsFile ? ((await call<string>("read_text_file", { path: d.agentsFile })) ?? "") : "";
  for (const [id, text] of [["global", d.globalBlock], ["common", d.commonBlock], ["outside", d.agentsOutside]] as const) {
    $("dir-" + id).textContent = text ?? "";
    $("dir-" + id + "-count").textContent = (text ?? "").length.toLocaleString();
  }
  updateComposed();
  $("dir-preview-box").hidden = true;
  $("dir-analysis").hidden = true;
  renderLightLabels();
  setProposal(null, d.dossierDirectives ? "Testo attuale del dossier." : "Nessuna direttiva specifica nel dossier: fai proporre la struttura al modello leggero o importa un file.");
}
onBusyClick($("dir-preview"), async () => {
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
onBusyClick($("dir-apply"), async () => {
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
  renderLightSettings();
  // The task preview depends on the agent (computer-use filter): read it again when the default agent changed.
  // An empty choice previewed with the runner default (claude).
  if (state.repo && (before || "claude") !== (state.provider || "claude")) refreshTasks();
}
function renderAgents() {
  $("q-agents").replaceChildren(...state.agents.map((a) => {
    const ready = a.status === "ready";
    const radio = el("input", { type: "radio", name: "agent", value: a.provider, checked: a.provider === state.provider, disabled: !ready });
    radio.addEventListener("change", () => { state.provider = a.provider; renderAgentOptions(); renderLightLabels(); refreshTasks(); });
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
onBusyClick($("q-reprobe"), () => probeAgents());
onBusyClick($("q-refresh"), () => refreshTasks());
$("q-all").addEventListener("click", () => { state.tasks.forEach((t) => state.selected.add(t.id)); renderTasks(); });
$("q-none").addEventListener("click", () => { state.selected.clear(); renderTasks(); });

// Only the newest read applies: an older one (e.g. the reload when a run ends) answering late would replace the list and clear the selection.
let tasksRequest = 0;
async function refreshTasks() {
  if (!state.repo) return;
  const request = ++tasksRequest;
  $("q-count").textContent = "Lettura del tracker…";
  const r = await call<{ tasks: PreviewTask[]; skipped: Skipped[] }>("list_tasks", { repo: state.repo, provider: state.provider || null }, "q-error");
  if (request !== tasksRequest) return;
  if (!r) { $("q-count").textContent = ""; return; }
  state.tasks = r.tasks ?? [];
  // Nothing is preselected (#517): the person opts in task by task, or with "Seleziona tutti".
  state.selected = new Set<string>();
  renderTasks();
  state.skipped = (r.skipped ?? []).filter((s) => s.id);
  state.skippedSelected = new Set([...state.skippedSelected].filter((id) => state.skipped.some((s) => s.id === id)));
  renderSkipped();
}
// Tasks the runner does not take: reason in words, the verdict of an analysis already made, and the action that starts or reopens it.
function renderSkipped() {
  const showStreams = input("q-show-streams").checked;
  const list = state.skipped.filter((s) => showStreams || !s.reason.startsWith("stream:"));
  $("q-skipped-count").textContent = list.length === state.skipped.length ? String(list.length) : `${list.length} di ${state.skipped.length}`;
  $("q-skipped").replaceChildren(...list.map((s) => {
    const id = s.id!;
    const can = analyzable(s.reason);
    const cb = el("input", { type: "checkbox", checked: state.skippedSelected.has(id), disabled: !can || state.analyzing });
    cb.setAttribute("aria-label", "Seleziona per l'analisi " + id);
    cb.addEventListener("change", () => { cb.checked ? state.skippedSelected.add(id) : state.skippedSelected.delete(id); updateAnalyzeButton(); });
    const verdict = verdictOf(id);
    const has = Boolean(storedAnalysis(id));
    const badge = verdict ? el("span", { className: "tag verdict-" + verdict }, VERDICT_LABEL[verdict] ?? verdict) : has ? el("span", { className: "tag" }, "analisi salvata") : "—";
    const action = el("button", { textContent: has ? "Apri" : "Analizza", disabled: (!can && !has) || state.analyzing, className: has ? "" : "accent" });
    onBusyClick(action, async () => {
      $("q-analysis-state").textContent = has ? "" : `Analisi di ${id} con ${currentLight()?.label ?? "—"}…`;
      if (has) await openAnalysis(id); else await analyzeTask(id);
      $("q-analysis-state").textContent = "";
    });
    const again = has ? el("button", { textContent: "Rifai", className: "ghost", title: "Nuova analisi da zero", disabled: !can || state.analyzing }) : "";
    if (again) onBusyClick(again, async () => { $("q-analysis-state").textContent = `Nuova analisi di ${id}…`; await analyzeTask(id); $("q-analysis-state").textContent = ""; });
    const reason = el("span", { title: s.reason }, reasonText(s.reason), s.stateReason ? el("div", { className: "muted small clamp", title: s.stateReason }, s.stateReason) : "");
    const tr = el("tr");
    [cb, s.seq != null ? String(s.seq) : "—", id, s.title ?? "", reason, badge, el("span", { className: "row-actions" }, action, again)].forEach((c) => tr.append(el("td", {}, c)));
    return tr;
  }));
  updateAnalyzeButton();
}
function updateAnalyzeButton() {
  const n = state.skippedSelected.size;
  const b = $<HTMLButtonElement>("q-analyze-selected");
  b.disabled = n === 0 || state.analyzing || !currentLight();
  b.textContent = n ? `Analizza selezionati (${n})` : "Analizza selezionati";
}
input("q-show-streams").addEventListener("change", renderSkipped);
onBusyClick($("q-analyze-selected"), async () => {
  const ids = state.skipped.filter((s) => state.skippedSelected.has(s.id!)).map((s) => s.id!);
  if (!ids.length) return;
  state.analyzing = true;
  renderSkipped();
  await analyzeMany(ids, (done, total, id) => { $("q-analysis-state").textContent = done < total ? `Analisi ${done + 1} di ${total}: ${id}…` : `Analisi completate: ${total}. Apri ciascun task per rispondere o applicare.`; });
  state.analyzing = false;
  state.skippedSelected.clear();
  renderSkipped();
});
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
onBusyClick($("q-start"), async () => {
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
  const request: QueueRequest = {
    repo: state.repo, provider: a.provider,
    model: custom || select("q-model").value || null,
    effort: select("q-effort").value || null,
    allowCustomModel: Boolean(custom),
    taskIds, timeoutMinutes: Number(input("q-timeout").value) || 30, stallMinutes: Number(input("q-stall").value) || 5,
    waitForReset: input("q-wait").checked, maxWaitHours: Number(input("q-wait-hours").value) || 24,
  };
  const shownModel = request.model ?? (a.configured.model ? `predefinito della CLI (${a.configured.model})` : "predefinito della CLI");
  const shownEffort = !a.supports.effort ? "impegno non regolabile" : request.effort ?? (a.configured.effort ? `impegno predefinito (${a.configured.effort})` : "impegno predefinito");
  if (!confirm(`Avviare ${taskIds.length} task con ${a.name} · ${shownModel} · ${shownEffort}?\nModello e impegno letti ora dalla CLI installata.\n${request.waitForReset ? `Al limite del piano la coda attende il ripristino (al massimo ${request.maxWaitHours} h) e riprende da sola.` : "Al limite del piano la coda si ferma (riprendibile con -Resume latest)."}\nGli agenti modificano file nel checkout; commit, push e cancellazioni sono vietati.`)) return;
  await launchQueue(request, "q-error");
});
/** Starts the runner for a confirmed request (new queue or resume) and follows it in the Run tab. */
let lastRequest: QueueRequest | null = null;
async function launchQueue(request: QueueRequest, errorBox: string) {
  resetRunView();
  lastRequest = request;
  const r = await call<{ pid: number; log: string }>("start_queue", { request }, errorBox);
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
}

// 4. Run: status card from status.json, steps and results from events.jsonl.
function setVerdict(v: string) {
  state.run.verdict = v;
  for (const id of ["run-verdict", "run-badge"]) { const b = $(id); b.dataset.verdict = v; b.textContent = RUN_VERDICT_LABEL[v] ?? v; }
}
function resetRunView() {
  stopPolling();
  state.run = { active: false, starting: false, pid: 0, folder: "", offset: 0, startedAt: "", status: null, verdict: "idle" };
  setVerdict("idle");
  $("run-task").textContent = "Nessun task in corso";
  for (const id of ["run-elapsed", "run-last", "run-counts", "run-folder"]) $(id).textContent = "—";
  $("run-steps").replaceChildren(); $("run-results").replaceChildren(); $("run-log").textContent = "";
  $("run-warning").hidden = true; setError("run-error", null);
  $("run-resume").hidden = true; resumePoint = null;
}
function stopPolling() {
  window.clearInterval(state.timers.events); window.clearInterval(state.timers.status); window.clearInterval(state.timers.clock); window.clearInterval(state.timers.find);
}
/** A note of the window kept in the run's events.jsonl (it comes back through the event stream and survives a reattach); before the
 *  run folder exists it stays in the local log only. */
function note(text: string) {
  if (state.run.folder) persistNote(text, true); else appendLog(text);
}
async function persistNote(text: string, fallbackToLog: boolean) {
  if (!state.run.folder || !state.repo) return;
  const ok = await call("add_run_note", { repo: state.repo, folder: state.run.folder, note: text });
  if (!ok && fallbackToLog) appendLog(text);
}
function appendLog(line: string) {
  const log = $("run-log");
  log.textContent += line + "\n";
  log.scrollTop = log.scrollHeight;
}
function addResult(r: RunRecord) {
  const badge = el("span", { className: "state-" + r.state }, r.state + (r.parked === true ? " (parcheggiato)" : r.parked === "deferred" ? " (parcheggio in coda di scrittura)" : ""));
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
    case "quotawait": $("run-warning").textContent = ev.message ?? "Limite del piano raggiunto: attesa del ripristino."; $("run-warning").hidden = false; break;
    case "quotaresumed": $("run-warning").hidden = true; break;
  }
}
// #554: a run stopped by a plan limit leaves a resume point; while no run is active the card offers to continue it with -Resume.
let resumePoint: ResumePoint | null = null;
const agentName = (provider: string) => state.agents.find((a) => a.provider === provider)?.name ?? provider;
function renderResume(rep: RunReport) {
  resumePoint = !rep.active && !state.run.active && !state.run.starting ? rep.resume ?? null : null;
  const box = $("run-resume");
  box.hidden = !resumePoint;
  if (!resumePoint) return;
  const p = resumePoint;
  const choice = [agentName(p.provider), p.model ?? "CLI default model", p.effort ?? "CLI default effort"].join(" · ");
  $("run-resume-text").textContent =
    `Run ${p.runId} stopped${p.stoppedAt ? " on " + new Date(p.stoppedAt).toLocaleString() : ""} by a plan limit` +
    (p.interrupted?.id ? ` · interrupted task ${p.interrupted.id}` : "") +
    ` · ${p.remaining.length} task${p.remaining.length === 1 ? "" : "s"} to run (${p.remaining.join(", ") || "none"})` +
    ` · ${choice}` +
    (p.resetAt ? ` · plan reset ${Date.parse(p.resetAt) > Date.now() ? "expected" : "reached"} at ${new Date(p.resetAt).toLocaleString()}` : "");
}
onBusyClick($("run-resume-start"), async () => {
  const p = resumePoint;
  if (!p || !state.repo) return;
  if (state.run.active || state.run.starting) return setError("run-error", "A queue is already running.");
  const resetAhead = p.resetAt && Date.parse(p.resetAt) > Date.now();
  if (!confirm(`Resume run ${p.runId} with ${agentName(p.provider)}?\n${p.interrupted?.id ? `The interrupted task ${p.interrupted.id} runs first; ` : ""}${p.remaining.length} task(s) in all, with the model and effort of the stopped run.` +
    (resetAhead ? `\nThe plan limit resets at ${new Date(p.resetAt!).toLocaleString()}: before then the runner does not start the agent.` : "") +
    `\nAgents change files in the checkout; commits, pushes and deletions are forbidden.`)) return;
  const request: QueueRequest = {
    repo: state.repo, provider: p.provider, model: p.model, effort: p.effort,
    // The model the stopped run resolved (possibly the CLI's configured name) is accepted as it is.
    allowCustomModel: Boolean(p.model),
    taskIds: [], timeoutMinutes: Number(input("q-timeout").value) || 30, stallMinutes: Number(input("q-stall").value) || 5,
    waitForReset: input("q-wait").checked, maxWaitHours: Number(input("q-wait-hours").value) || 24, resume: p.runId,
  };
  await launchQueue(request, "run-error");
});
function renderStatus(rep: RunReport) {
  const s = rep.status;
  state.run.status = s;
  setVerdict(rep.verdict);
  renderResume(rep);
  if (!s) return;
  state.run.startedAt = s.startedAt;
  $("run-folder").textContent = rep.folder ?? s.folder ?? "—";
  $("run-counts").textContent = `${s.counts.done} di ${s.counts.total} task (${s.counts.succeeded} riusciti, ${s.counts.failed} non riusciti)` + (s.stopReason ? ` · arresto: ${s.stopReason}${!rep.active && s.finishedAt ? " (run chiuso il " + new Date(s.finishedAt).toLocaleString() + ")" : ""}` : "") + (s.quota ? ` · quota letta: ${s.quota.state}${s.quota.resetAt ? " fino a " + new Date(s.quota.resetAt).toLocaleString() : ""}` : "");
  $("run-task").textContent = s.task ? `[${s.task.position}/${s.task.total}] #${s.task.seq} ${s.task.id} — ${s.task.title}` : s.quotaWait && rep.active ? `In attesa del ripristino dei limiti, poi riprende da ${s.quotaWait.taskId}` : rep.active ? `Fase: ${s.phase}` : "Nessun task in corso";
  renderClock();
}
function renderClock() {
  const s = state.run.status;
  if (!s) return;
  const end = s.finishedAt && !state.run.active ? Date.parse(s.finishedAt) : Date.now();
  $("run-elapsed").textContent = fmtDuration((end - Date.parse(s.startedAt)) / 1000);
  const w = state.run.active ? s.quotaWait : null;
  // #564: while the run waits for the reset this row shows the resume time, under a label that names it.
  $("run-last-label").textContent = w ? "Ripresa" : "Ultimo segnale dell'agente";
  if (w) {
    $("run-last").textContent = `Ripresa alle ${new Date(w.resumeAt).toLocaleString()} (tra ${fmtDuration(-since(w.resumeAt))}) · ${WAIT_SOURCE_LABEL[w.source] ?? w.source}` + (w.attempt > 1 ? ` · attesa n. ${w.attempt}` : "");
    return;
  }
  const last = s.lastAgentEventAt ?? s.task?.startedAt ?? null;
  $("run-last").textContent = state.run.active && last ? `${fmtDuration(since(last))} fa` + (s.lastAgentEvent ? ` · ${s.lastAgentEvent.kind}: ${s.lastAgentEvent.summary}` : "") : s.lastAgentEvent ? `${s.lastAgentEvent.kind}: ${s.lastAgentEvent.summary}` : "—";
}
// One read at a time: two overlapping reads from the same offset (timer plus reattach) would show every event twice.
let pullingEvents = false;
async function pullEvents() {
  if (!state.run.folder || pullingEvents) return;
  pullingEvents = true;
  let r: { events: RunnerEvent[]; offset: number } | null | undefined;
  try {
    r = await call<{ events: RunnerEvent[]; offset: number }>("read_run_events", { folder: state.run.folder, offset: state.run.offset });
  } finally { pullingEvents = false; }
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
  const ended = "Run concluso: " + (RUN_VERDICT_LABEL[rep.verdict] ?? rep.verdict);
  appendLog(ended);
  persistNote(ended, false);
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
  if (rep.active && rep.folder) { attachRun(rep); note("Run in corso ritrovato e riagganciato dalla finestra."); selectTab("run"); }
  else if (rep.status) renderStatus(rep);
}
onBusyClick($("run-refresh"), () => pullStatus());
onBusyClick($("run-stop"), async () => {
  if (!state.run.active && !state.run.starting) return setError("run-error", "Nessuna coda in esecuzione.");
  const ok = await call<boolean>("stop_queue", { repo: state.repo, force: false }, "run-error");
  if (ok) note("Arresto richiesto dalla finestra: la coda si ferma dopo il task corrente.");
});
onBusyClick($("run-abort"), async () => {
  if (!state.run.active && !state.run.starting) return setError("run-error", "Nessuna coda in esecuzione.");
  if (!confirm("Interrompere subito l'agente in corso? Il task resta nello stato lasciato dall'agente.")) return;
  const ok = await call<boolean>("stop_queue", { repo: state.repo, force: true }, "run-error");
  if (ok) { note("Interruzione immediata richiesta dalla finestra."); window.setTimeout(pullStatus, 1500); }
});

// #604: the runner refused to start without its power request (event powerrefused, exit 2): the owner chooses Run anyway or Cancel.
const powerDialog = $<HTMLDialogElement>("power-dialog");
let powerRetry: QueueRequest | null = null;
function askPowerChoice(log: string) {
  if (!lastRequest || lastRequest.allowNoPowerRequest) return false;
  powerRetry = { ...lastRequest, allowNoPowerRequest: true };
  const reason = /"event":"powerrefused".*?"error":"([^"]*)"/.exec(log)?.[1];
  $("power-reason").textContent = reason ? `Reason: ${reason}.` : "";
  if (!powerDialog.open) powerDialog.showModal();
  return true;
}
powerDialog.querySelectorAll<HTMLButtonElement>("button[data-power]").forEach((b) => onBusyClick(b, async () => {
  const retry = powerRetry;
  powerRetry = null;
  powerDialog.close();
  if (b.dataset.power === "run" && retry) await launchQueue(retry, "run-error");
}));
listen<{ code: number | null; pid: number; log: string; stdout: string }>("runner-finished", async (e) => {
  if (e.payload.pid !== state.run.pid) return;
  window.clearInterval(state.timers.find);
  const powerRefused = e.payload.code === 2 && e.payload.log.includes('"event":"powerrefused"');
  if (!state.run.folder) {
    // Ended before writing its status (busy repository, invalid model, missing agent): show why.
    state.run.starting = false;
    setVerdict("idle");
    setError("run-error", `Il runner è terminato (uscita ${e.payload.code}) prima di avviare il run.\n${e.payload.log}`);
    updateSteps();
    if (powerRefused) askPowerChoice(e.payload.log);
    return;
  }
  await pullStatus();
  if (powerRefused) askPowerChoice(e.payload.log);
});

// Closing with a run in progress asks what to do; the runner itself is detached and survives the window.
const dialog = $<HTMLDialogElement>("close-dialog");
async function closeWindow() { await getCurrentWindow().destroy(); }
dialog.querySelectorAll<HTMLButtonElement>("button[data-close]").forEach((b) => onBusyClick(b, async () => {
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
  initRegistry(() => state.repo);
  initAnalysis({ repo: () => state.repo, identity: () => state.identity, light: currentLight, onChange: () => { renderSkipped(); } });
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
