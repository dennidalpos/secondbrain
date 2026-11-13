// Analysis that makes a task autonomous (REP18 through agents.ps1 -Analyze): the light model answers with tool calls that this
// dialog dispatches. ask_user becomes a multiple-choice question (recommended option first, free text under "Altro"); the answers go
// back for the next round; propose_task_update is shown as a before/after diff and written to the tracker only after confirmation;
// mark_not_automatable records the reason. The analysis state lives in its work folder, so a closed window loses nothing.
import { $, call, el, setError, type LightChoice } from "./common";

interface Option { id: string; label: string; description: string }
interface CallArgs {
  questionId: string | null; header: string | null; question: string | null; options: Option[] | null; multiSelect: boolean | null; recommended: string | null;
  description: string | null; acceptance: string[] | null; execution: string | null; awaiting: string | null; requires: string[] | null; dependencies: string[] | null;
  stateReason: string | null; reason: string | null;
}
interface ToolCall { name: "ask_user" | "propose_task_update" | "mark_not_automatable"; arguments: CallArgs }
interface AnalysisResult { taskId: string; verdict: "autonomous-now" | "needs-answers" | "not-automatable"; summary: string; calls: ToolCall[]; blockersRemaining: { kind: string; detail: string }[] }
interface TaskSnapshot { id: string; seq: number; title: string; status: string; execution: string; description: string | null; acceptance: string[]; extensions: Record<string, unknown> | null }
export interface AnalysisView {
  analysisPath: string; taskId: string; seq: number; provider: string; model: string | null; effort: string | null; round: number; maxRounds: number;
  reason: string | null; dependencies: { id: string; status: string }[]; task: TaskSnapshot; result: AnalysisResult;
  answered: { questionId: string; question: string; answer: string }[]; applied?: { at: string; state: unknown; verdict: string } | null;
}
interface Hooks { repo: () => string; identity: () => string; light: () => LightChoice | null; onChange: () => void }

export const VERDICT_LABEL: Record<string, string> = { "autonomous-now": "pronto per l'autonomia", "needs-answers": "servono risposte", "not-automatable": "non automatizzabile" };
const BLOCKER_LABEL: Record<string, string> = { "owner-consent": "consenso della persona", credential: "credenziale", hardware: "hardware", "live-access": "accesso dal vivo", "computer-use": "uso del computer", "other-repository": "altro repository" };
let hooks: Hooks;
let current: AnalysisView | null = null;
let busy = false;
const verdicts = new Map<string, string>();

function storeKey() { return "sb-analyses:" + hooks.identity(); }
function stored(): Record<string, string> { try { return JSON.parse(localStorage.getItem(storeKey()) ?? "{}"); } catch { return {}; } }
function remember(taskId: string, path: string | null) {
  const map = stored();
  if (path) map[taskId] = path; else delete map[taskId];
  localStorage.setItem(storeKey(), JSON.stringify(map));
}
export function storedAnalysis(taskId: string): string | null { return stored()[taskId] ?? null; }
export function verdictOf(taskId: string): string | null { return verdicts.get(taskId) ?? null; }

export function initAnalysis(h: Hooks) {
  hooks = h;
  $("an-close").addEventListener("click", () => $<HTMLDialogElement>("an-dialog").close());
}

function lightArgs(): Record<string, unknown> | null {
  const l = hooks.light();
  if (!l) return null;
  return { provider: l.provider, model: l.model || null, effort: l.effort || null };
}

/** First round on one task; the dialog opens on its result unless quiet. */
export async function analyzeTask(taskId: string, quiet = false, errorId = "q-error"): Promise<AnalysisView | null> {
  const args = lightArgs();
  if (!args) { setError(errorId, "Nessun agente pronto per l'analisi: rileva gli agenti o scegli il modello leggero nelle impostazioni."); return null; }
  const view = await call<AnalysisView>("analyze_task", { repo: hooks.repo(), taskId, ...args }, errorId);
  if (!view) return null;
  remember(taskId, view.analysisPath);
  verdicts.set(taskId, view.result.verdict);
  if (!quiet) show(view);
  hooks.onChange();
  return view;
}

/** Reopens a stored analysis (no agent call). */
export async function openAnalysis(taskId: string, errorId = "q-error") {
  const path = storedAnalysis(taskId);
  if (!path) return analyzeTask(taskId, false, errorId);
  const view = await call<AnalysisView>("view_task_analysis", { repo: hooks.repo(), analysisPath: path }, errorId);
  if (!view) { remember(taskId, null); return null; }
  verdicts.set(taskId, view.result.verdict);
  show(view);
  return view;
}

function show(view: AnalysisView) {
  current = view;
  render();
  const d = $<HTMLDialogElement>("an-dialog");
  if (!d.open) d.showModal();
}

function setBusy(on: boolean, text = "") {
  busy = on;
  $("an-state").textContent = text;
  const primary = $<HTMLButtonElement>("an-primary");
  primary.disabled = on;
  primary.classList.toggle("busy", on);
  if (on) primary.setAttribute("aria-busy", "true"); else primary.removeAttribute("aria-busy");
}

function render() {
  const v = current!;
  const r = v.result;
  setError("an-error", null);
  $("an-title").textContent = `#${v.task.seq} ${v.task.title}`;
  $("an-meta").textContent = `Analisi con ${v.provider}${v.model ? " · " + v.model : ""}${v.effort ? " · " + v.effort : ""} · giro ${v.round} di ${v.maxRounds} · ${VERDICT_LABEL[r.verdict] ?? r.verdict}`;
  $("an-reason").textContent = v.reason ? "Motivo dell'esclusione: " + v.reason : "";
  $("an-summary").textContent = r.summary;
  const body = $("an-body");
  body.replaceChildren();
  if (v.answered.length) {
    body.append(el("details", {}, el("summary", {}, `Risposte già date (${v.answered.length})`),
      el("ul", { className: "small" }, ...v.answered.map((a) => el("li", {}, el("strong", {}, a.question), " — ", a.answer)))));
  }
  if (r.blockersRemaining.length) {
    body.append(el("div", { className: "warning" }, "Prerequisiti reali: ", ...r.blockersRemaining.map((b, i) => `${i ? "; " : ""}${BLOCKER_LABEL[b.kind] ?? b.kind}: ${b.detail}`)));
  }
  const primary = $<HTMLButtonElement>("an-primary");
  primary.hidden = false;
  primary.onclick = null;
  if (v.applied) {
    body.append(el("p", { className: "ok-note" }, `Risultato già applicato il ${new Date(v.applied.at).toLocaleString()} (${v.applied.state === "deferred" ? "in coda di scrittura" : "scritto nel tracker"}).`));
    primary.hidden = true;
    return;
  }
  if (r.verdict === "needs-answers") renderQuestions(body, primary);
  else if (r.verdict === "autonomous-now") renderUpdate(body, primary);
  else renderNotAutomatable(body, primary);
}

function renderQuestions(body: HTMLElement, primary: HTMLButtonElement) {
  const v = current!;
  const asks = v.result.calls.filter((c) => c.name === "ask_user" && c.arguments.question);
  const form = el("form", { className: "questions" });
  asks.forEach((c, qi) => {
    const a = c.arguments;
    const name = "q" + qi;
    const type = a.multiSelect ? "checkbox" : "radio";
    const options = [...(a.options ?? [])].sort((x, y) => Number(y.id === a.recommended) - Number(x.id === a.recommended));
    const set = el("fieldset", {}, el("legend", {}, a.header ? `${a.header}: ` : "", a.question ?? ""));
    for (const o of options) {
      const box = el("input", { type, name, value: o.label });
      set.append(el("label", { className: "choice" }, box, el("span", {}, el("strong", {}, o.label + (o.id === a.recommended ? " (consigliata)" : "")), el("span", { className: "muted small" }, " — " + o.description))));
    }
    const otherBox = el("input", { type, name, value: "__other" });
    const otherText = el("input", { type: "text", placeholder: "Altro: scrivi la tua risposta", className: "other" });
    otherText.addEventListener("input", () => { if (otherText.value.trim()) otherBox.checked = true; update(); });
    set.append(el("label", { className: "choice" }, otherBox, otherText));
    set.dataset.questionId = a.questionId ?? name;
    set.dataset.question = a.question ?? "";
    form.append(set);
  });
  const update = () => {
    const sets = [...form.querySelectorAll<HTMLFieldSetElement>("fieldset")];
    primary.disabled = busy || !sets.length || sets.some((s) => !s.querySelector("input:checked"));
  };
  form.addEventListener("change", update);
  body.append(form);
  if (v.round >= v.maxRounds) {
    body.append(el("p", { className: "warning" }, "Ultimo giro raggiunto: con queste risposte non si può fare un altro giro. Riavvia l'analisi dalla coda se serve."));
    primary.hidden = true;
    return;
  }
  primary.textContent = "Invia risposte";
  update();
  primary.onclick = async () => {
    const answers = [...form.querySelectorAll<HTMLFieldSetElement>("fieldset")].map((s) => {
      const chosen = [...s.querySelectorAll<HTMLInputElement>("input:checked")].map((i) => (i.value === "__other" ? (s.querySelector<HTMLInputElement>("input.other")?.value.trim() || "Altro") : i.value));
      return { questionId: s.dataset.questionId, question: s.dataset.question, answer: chosen.join("; ") };
    });
    setBusy(true, "Nuovo giro di analisi con le tue risposte…");
    const next = await call<AnalysisView>("resolve_task_analysis", { repo: hooks.repo(), analysisPath: v.analysisPath, answers }, "an-error");
    setBusy(false);
    if (!next) return;
    verdicts.set(next.taskId, next.result.verdict);
    current = next;
    render();
    hooks.onChange();
  };
}

function listText(items: string[] | null | undefined): string { return items && items.length ? items.join("\n") : "—"; }

function renderUpdate(body: HTMLElement, primary: HTMLButtonElement) {
  const v = current!;
  const u = v.result.calls.find((c) => c.name === "propose_task_update")?.arguments;
  if (!u) { body.append(el("p", { className: "warning" }, "Il modello non ha proposto l'aggiornamento: riavvia l'analisi.")); primary.hidden = true; return; }
  const ext = (v.task.extensions ?? {}) as Record<string, unknown>;
  const awaiting = String(ext.awaiting ?? "");
  const deps = (v.dependencies ?? []).map((d) => d.id);
  const rows: [string, string, string][] = [
    ["Descrizione", v.task.description ?? "—", u.description ?? "(invariata)"],
    ["Criteri di accettazione", listText(v.task.acceptance), u.acceptance?.length ? listText(u.acceptance) : "(invariati)"],
    ["Esecuzione", v.task.execution, u.execution ?? "autonomous"],
    ["Stato", v.task.status, ["blocked", "unknown"].includes(v.task.status) ? "todo" : v.task.status],
    ["In attesa di", awaiting || "—", u.awaiting || "—"],
    ["Requisiti", listText(ext.requires as string[] | undefined), listText(u.requires)],
    ["Dipendenze", listText(deps), u.dependencies ? listText(u.dependencies) : "(invariate)"],
    ["Motivo di stato", String(ext.stateReason ?? "—"), u.stateReason ?? "(invariato)"],
  ];
  const table = el("table", { className: "tasks diff" }, el("thead", {}, el("tr", {}, el("th", {}, "Campo"), el("th", {}, "Attuale"), el("th", {}, "Proposto"))));
  const tbody = el("tbody");
  for (const [f, a, b] of rows) tbody.append(el("tr", { className: a === b ? "" : "changed" }, el("td", {}, f), el("td", { className: "pre" }, a), el("td", { className: "pre" }, b)));
  table.append(tbody);
  body.append(table);
  if (awaiting && awaiting !== "structural-completion" && (u.awaiting ?? "") !== awaiting) {
    body.append(el("p", { className: "warning" }, `L'attesa «${awaiting}» viene tolta: si applica solo se le tue risposte la concedono esplicitamente.`));
  }
  primary.textContent = "Applica al tracker";
  primary.disabled = busy;
  primary.onclick = () => apply("Aggiornare il task nel tracker con la proposta mostrata? La scrittura passa da knowledge.ps1 e resta nel registro delle esecuzioni.");
}

function renderNotAutomatable(body: HTMLElement, primary: HTMLButtonElement) {
  const v = current!;
  const why = v.result.calls.find((c) => c.name === "mark_not_automatable")?.arguments.reason ?? v.result.summary;
  body.append(el("p", {}, el("strong", {}, "Motivo: "), why));
  primary.textContent = "Registra il motivo nel task";
  primary.disabled = busy;
  primary.onclick = () => apply("Registrare il motivo nel task (esecuzione user_required)?");
}

async function apply(question: string) {
  const v = current!;
  if (!confirm(question)) return;
  setBusy(true, "Scrittura nel tracker…");
  const r = await call<{ applied: boolean | string }>("apply_task_analysis", { repo: hooks.repo(), analysisPath: v.analysisPath, authorization: "Conferma nell'orchestratore desktop " + new Date().toISOString() }, "an-error");
  setBusy(false);
  if (!r) return;
  current = { ...v, applied: { at: new Date().toISOString(), state: r.applied, verdict: v.result.verdict } };
  render();
  $("an-state").textContent = r.applied === "deferred" ? "Scrittura accettata: verrà applicata appena il tracker è libero." : "Task aggiornato.";
  hooks.onChange();
}

/** Analyzes the given tasks one after the other (quietly), reporting progress; the dialog opens on demand. */
export async function analyzeMany(ids: string[], progress: (done: number, total: number, id: string) => void) {
  for (let i = 0; i < ids.length; i++) {
    progress(i, ids.length, ids[i]);
    await analyzeTask(ids[i], true);
  }
  progress(ids.length, ids.length, "");
}
