// End-to-end scenarios on the real orchestrator binary (Windows, WebView2) with a synthetic SecondBrain:
// preload from --repo, removal of recent repositories across restarts, the directives proposed by the light model and every Directives
// button with its persistence after a restart, agents and models limited to the installed CLIs, a queue run followed live, closed while
// running and found again after reopening, the registry with tool badges and archived tasks, and the analysis that makes a task autonomous.
// The fixture comes from scripts/test-orchestrator-fixture.ps1 through SB_E2E_FIXTURE; real user settings are never touched.
import { test, expect, chromium, type Browser, type Page } from "@playwright/test";
import { spawn, type ChildProcess } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import * as net from "node:net";

interface Fixture { brain: string; checkout: string; identity: string; tracker: string; dossier: string; bin: string; configDir: string; binary: string; webviewData: string }
const fixture: Fixture = JSON.parse(fs.readFileSync(process.env.SB_E2E_FIXTURE ?? "", "utf8"));
const settingsFile = path.join(fixture.configDir, "settings.json");

interface App { proc: ChildProcess; browser: Browser; page: Page; exited: Promise<number | null> }

async function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.listen(0, "127.0.0.1", () => { const p = (srv.address() as net.AddressInfo).port; srv.close(() => resolve(p)); });
    srv.on("error", reject);
  });
}

// PATH without any real agent CLI, so the probe sees only the fake Claude Code of the fixture.
function isolatedPath(): string {
  const names = ["claude.exe", "claude.cmd", "claude", "codex.exe", "codex.cmd", "codex", "gemini.exe", "gemini.cmd", "gemini"];
  const dirs = (process.env.PATH ?? "").split(path.delimiter).filter((d) => d && !names.some((n) => fs.existsSync(path.join(d, n))));
  return [fixture.bin, ...dirs].join(path.delimiter);
}

async function launch(opts: { repo?: string; agentSeconds?: number } = {}): Promise<App> {
  const port = await freePort();
  const args = opts.repo ? ["--repo", opts.repo] : [];
  const proc = spawn(fixture.binary, args, {
    cwd: fixture.brain,
    env: {
      ...process.env,
      PATH: isolatedPath(),
      SECONDBRAIN_HOME: fixture.brain,
      SECONDBRAIN_ORCHESTRATOR_CONFIG_DIR: fixture.configDir,
      SECONDBRAIN_AGENT_SEARCH_ONLY: "1",
      SECONDBRAIN_AGENT_SEARCH_PATH: fixture.bin,
      SB_E2E_BRAIN: fixture.brain,
      SB_E2E_AGENT_SECONDS: String(opts.agentSeconds ?? 3),
      WEBVIEW2_USER_DATA_FOLDER: fixture.webviewData,
      WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS: `--remote-debugging-port=${port}`,
    },
    stdio: "ignore",
  });
  const exited = new Promise<number | null>((resolve) => proc.on("exit", (code) => resolve(code)));
  let browser: Browser | null = null;
  const deadline = Date.now() + 60_000;
  while (!browser && Date.now() < deadline) {
    try { browser = await chromium.connectOverCDP(`http://127.0.0.1:${port}`); } catch { await new Promise((r) => setTimeout(r, 500)); }
  }
  if (!browser) { proc.kill(); throw new Error("WebView2 DevTools endpoint not reachable"); }
  let page: Page | undefined;
  while (!page && Date.now() < deadline) {
    page = browser.contexts().flatMap((c) => c.pages()).find((p) => !p.url().startsWith("devtools:"));
    if (!page) await new Promise((r) => setTimeout(r, 300));
  }
  if (!page) throw new Error("orchestrator page not found");
  page.on("dialog", (d) => d.accept());
  await page.waitForSelector("#repo-path");
  return { proc, browser, page, exited };
}

async function closeApp(app: App) {
  // The same close request as the title bar; without a running queue the window closes at once.
  await app.page.evaluate(() => (window as unknown as { sbOrchestrator: { requestClose: () => void } }).sbOrchestrator.requestClose()).catch(() => {});
  const code = await Promise.race([app.exited, new Promise<"timeout">((r) => setTimeout(() => r("timeout"), 15_000))]);
  if (code === "timeout") app.proc.kill();
  await app.browser.close().catch(() => {});
}

function readTracker(): { tasks: { id: string; status: string; execution: string; acceptance?: string[]; extensions?: Record<string, unknown> }[] } {
  return JSON.parse(fs.readFileSync(fixture.tracker, "utf8"));
}

test.describe.configure({ mode: "serial" });

test("repository preloaded from --repo, recent entries removed for good across restarts", async () => {
  const missing = path.join(path.dirname(fixture.checkout), "gone-checkout");
  fs.mkdirSync(fixture.configDir, { recursive: true });
  fs.writeFileSync(settingsFile, JSON.stringify({ secondbrainHome: "", pwshPath: "", recentRepos: [missing] }));
  let app = await launch({ repo: fixture.checkout });
  const { page } = app;
  await expect(page.locator("#repo-label")).toHaveText(fixture.identity);
  await expect(page.locator('.steps button[data-tab="queue"]')).toHaveAttribute("aria-selected", "true");
  await expect(page.locator("#repo-tracker")).toContainText("tracker.json");
  await page.locator('.steps button[data-tab="repo"]').click();
  await expect(page.locator("#recent li")).toHaveCount(2);
  await expect(page.locator("#recent li").filter({ hasText: "gone-checkout" })).toContainText("non trovato");
  await page.locator(`#recent button[data-remove="${missing.replace(/\\/g, "\\\\")}"]`).click();
  await expect(page.locator("#recent li")).toHaveCount(1);
  await page.locator(`#recent button[data-remove="${fixture.checkout.replace(/\\/g, "\\\\")}"]`).click();
  await expect(page.locator("#recent li")).toHaveCount(0);
  // An unrelated settings change must not bring the removed entries back (the old window rewrote its stale list).
  await page.locator('.steps button[data-tab="settings"]').click();
  await page.locator("#s-save").click();
  await expect(page.locator("#s-info")).toHaveText("Impostazioni salvate.");
  expect(JSON.parse(fs.readFileSync(settingsFile, "utf8")).recentRepos).toEqual([]);
  await closeApp(app);

  app = await launch();
  await expect(app.page.locator("#recent-empty")).toBeVisible();
  await expect(app.page.locator("#repo-label")).toHaveText("Nessun repository");
  await closeApp(app);
});

test("directives: light-model proposal, preview, approve and apply, reload; the text survives a restart", async () => {
  let app = await launch({ repo: fixture.checkout });
  let { page } = app;
  await expect(page.locator("#repo-label")).toHaveText(fixture.identity);
  await expect(page.locator('.steps button[data-tab="queue"]')).toHaveAttribute("aria-selected", "true");
  await page.locator('.steps button[data-tab="directives"]').click();
  await expect(page.locator("#dir-target")).toContainText("AGENTS.managed.md");
  // The global, common and composed blocks are shown read-only with the startup budget.
  await expect(page.locator("#dir-global")).not.toBeEmpty({ timeout: 60_000 });
  await expect(page.locator("#dir-budget")).toContainText("%");
  await expect(page.locator("#dir-light")).toContainText("Claude Code");
  await page.locator("#dir-propose").click();
  await expect(page.locator("#dir-analysis")).toBeVisible({ timeout: 120_000 });
  await expect(page.locator("#dir-sections")).toContainText("Script di test del prodotto.");
  await expect(page.locator("#dir-covered")).toContainText("Commit e push");
  await page.locator("#dir-use").click();
  await expect(page.locator("#dir-text")).toHaveValue(/## Verifiche/);
  await expect(page.locator("#dir-apply")).toBeDisabled();
  const text = "## Direttive sintetiche E2E\n\n- Verifiche: npm test prima di chiudere un task.\n";
  await page.locator("#dir-text").fill(text);
  await page.locator("#dir-preview").click();
  await expect(page.locator("#dir-apply")).toBeEnabled({ timeout: 90_000 });
  await expect(page.locator("#dir-preview-box")).toBeVisible();
  await page.locator("#dir-apply").click();
  await expect(page.locator("#dir-state")).toHaveText("Direttive approvate e allineate.", { timeout: 120_000 });
  await expect(page.locator("#dir-error")).toBeHidden();
  expect(fs.readFileSync(path.join(fixture.checkout, "AGENTS.md"), "utf8")).toContain("Direttive sintetiche E2E");
  expect(fs.readFileSync(path.join(fixture.dossier, "AGENTS.managed.md"), "utf8")).toContain("Direttive sintetiche E2E");
  // Editing invalidates nothing on disk; "Ricarica dal dossier" restores the approved text.
  await page.locator("#dir-text").fill("bozza non approvata");
  await page.locator("#dir-reload").click();
  await expect(page.locator("#dir-text")).toHaveValue(/Direttive sintetiche E2E/);
  // The import command reads Markdown only (the native file dialog itself cannot be driven here).
  const imported = await page.evaluate(async (p) => {
    const internals = (window as unknown as { __TAURI_INTERNALS__: { invoke: (c: string, a: object) => Promise<string> } }).__TAURI_INTERNALS__;
    const ok = await internals.invoke("read_text_file", { path: p });
    let refused = "";
    try { await internals.invoke("read_text_file", { path: p.replace(/\.md$/, ".txt") }); } catch (e) { refused = String(e); }
    return { ok, refused };
  }, path.join(fixture.checkout, "README.md"));
  expect(imported.ok).toContain("Synthetic product");
  expect(imported.refused).toContain("Markdown");
  await closeApp(app);

  app = await launch({ repo: fixture.checkout });
  page = app.page;
  await page.locator('.steps button[data-tab="directives"]').click();
  await expect(page.locator("#dir-text")).toHaveValue(/Direttive sintetiche E2E/);
  await expect(page.locator("#dir-current")).toContainText("Direttive sintetiche E2E");
  await closeApp(app);
});

test("queue lists only the installed agents and the models their CLI exposes", async () => {
  const app = await launch({ repo: fixture.checkout });
  const { page } = app;
  await expect(page.locator("#q-agents label.agent")).toHaveCount(3, { timeout: 60_000 });
  const claude = page.locator("#q-agents label.agent").filter({ hasText: "Claude Code" });
  await expect(claude).toContainText("pronto");
  await expect(claude).toContainText("9.9.9");
  await expect(claude.locator("input")).toBeChecked();
  for (const name of ["Codex", "Gemini CLI"]) {
    const off = page.locator("#q-agents label.agent").filter({ hasText: name });
    await expect(off).toContainText("non installato");
    await expect(off.locator("input")).toBeDisabled();
  }
  const models = await page.locator("#q-model option").evaluateAll((o) => o.map((x) => (x as HTMLOptionElement).value));
  expect(models).toEqual(["", "opus", "sonnet"]);
  const efforts = await page.locator("#q-effort option").evaluateAll((o) => o.map((x) => (x as HTMLOptionElement).value));
  expect(efforts[0]).toBe("");
  expect(efforts.every((e) => ["", "low", "medium", "high", "xhigh", "max"].includes(e))).toBe(true);
  await expect(page.locator("#q-tasks tr")).toHaveCount(3);
  await closeApp(app);
});

test("a queue run is followed live, survives closing the window and is found again after reopening", async () => {
  let app = await launch({ repo: fixture.checkout, agentSeconds: 15 });
  let { page } = app;
  await expect(page.locator("#q-tasks tr")).toHaveCount(3, { timeout: 60_000 });
  await expect(page.locator("#q-agents label.agent").filter({ hasText: "Claude Code" }).locator("input")).toBeChecked();
  await page.locator("#q-tasks tr").filter({ hasText: "E2E-1" }).locator('input[type="checkbox"]').check();
  await page.locator("#q-start").click();
  await expect(page.locator('.steps button[data-tab="run"]')).toHaveAttribute("aria-selected", "true");
  await expect(page.locator("#run-verdict")).toHaveText("In lavoro", { timeout: 60_000 });
  await expect(page.locator("#run-steps")).toContainText("Read: README.md", { timeout: 30_000 });
  await expect(page.locator("#run-task")).toContainText("E2E-1");
  await expect(page.locator("#run-folder")).toContainText("runner-run-");
  // Closing asks what to do; "leave running" closes the window and keeps the detached runner going.
  await page.evaluate(() => (window as unknown as { sbOrchestrator: { requestClose: () => void } }).sbOrchestrator.requestClose());
  await expect(page.locator("#close-dialog")).toBeVisible();
  await page.locator('#close-dialog button[data-close="leave"]').click();
  await Promise.race([app.exited, new Promise((r) => setTimeout(r, 15_000))]);
  await app.browser.close().catch(() => {});

  app = await launch({ repo: fixture.checkout, agentSeconds: 15 });
  page = app.page;
  await expect(page.locator('.steps button[data-tab="run"]')).toHaveAttribute("aria-selected", "true", { timeout: 60_000 });
  await expect(page.locator("#run-log")).toContainText("ritrovato e riagganciato");
  await expect(page.locator("#run-steps")).toContainText("Read: README.md");
  await expect(page.locator("#run-verdict")).toHaveText("Concluso", { timeout: 120_000 });
  await expect(page.locator("#run-results tr").filter({ hasText: "E2E-1" })).toContainText("finished");
  await expect(page.locator("#run-steps")).toContainText("npm test");
  expect(readTracker().tasks.find((t) => t.id === "E2E-1")?.status).toBe("in_progress");
  await page.locator('.steps button[data-tab="queue"]').click();
  await expect(page.locator("#q-tasks tr")).toHaveCount(2);
  await closeApp(app);
});

test("registry: every task with its tool badge, archived tasks and the runner history", async () => {
  const app = await launch({ repo: fixture.checkout });
  const { page } = app;
  await page.locator('.steps button[data-tab="registry"]').click();
  await expect(page.locator("#reg-rows tr.reg-row")).toHaveCount(5, { timeout: 60_000 });
  const archived = page.locator("#reg-rows tr.reg-row").filter({ hasText: "E2E-0" });
  await expect(archived).toContainText("archiviato");
  await expect(archived.locator(".tool-badge")).toHaveAttribute("data-tool", "unknown");
  const ran = page.locator("#reg-rows tr.reg-row").filter({ hasText: "E2E-1" });
  await expect(ran.locator('.tool-badge[data-tool="claude"]')).toBeVisible();
  await ran.click();
  await expect(page.locator("#reg-rows .reg-runs").first()).toContainText("Claude");
  await page.locator("#reg-archived").selectOption("only");
  await expect(page.locator("#reg-rows tr.reg-row")).toHaveCount(1, { timeout: 30_000 });
  await page.locator('[data-reg-view="runs"]').click();
  await expect(page.locator("#reg-run-rows tr").first()).toContainText("Claude", { timeout: 30_000 });
  await closeApp(app);
});

test("queue: a task that cannot run alone is analyzed, the owner answers and the update makes it autonomous", async () => {
  const app = await launch({ repo: fixture.checkout });
  const { page } = app;
  const row = page.locator("#q-skipped tr").filter({ hasText: "E2E-4" });
  await expect(row).toContainText("Serve una scelta della persona", { timeout: 60_000 });
  await row.locator("button", { hasText: "Analizza" }).click();
  const dialog = page.locator("#an-dialog");
  await expect(dialog).toBeVisible({ timeout: 120_000 });
  await expect(dialog.locator("legend")).toContainText("Quale sezione aggiungere al README?");
  await expect(dialog.locator("label.choice").first()).toContainText("Installazione (consigliata)");
  await expect(page.locator("#an-primary")).toBeDisabled();
  await dialog.locator("label.choice").first().locator("input").check();
  await page.locator("#an-primary").click();
  await expect(page.locator("#an-primary")).toHaveText("Applica al tracker", { timeout: 120_000 });
  await expect(dialog.locator("table.diff")).toContainText("autonomous");
  await page.locator("#an-primary").click();
  await expect(page.locator("#an-state")).toHaveText("Task aggiornato.", { timeout: 120_000 });
  const task = readTracker().tasks.find((t) => t.id === "E2E-4");
  expect(task?.execution).toBe("autonomous");
  expect(task?.acceptance).toContain("npm test passa");
  expect(JSON.stringify(task?.extensions?.decisions)).toContain("Installazione");
  const ledger = fs.readFileSync(path.join(fixture.dossier, "history", "task-runs.jsonl"), "utf8");
  expect(ledger).toMatch(/"taskId":"E2E-4".*"mode":"analysis"/);
  await page.locator("#an-close").click();
  await page.locator("#q-refresh").click();
  await expect(page.locator("#q-tasks tr").filter({ hasText: "E2E-4" })).toHaveCount(1, { timeout: 60_000 });
  await expect(page.locator("#q-skipped tr").filter({ hasText: "E2E-4" })).toHaveCount(0);
  await closeApp(app);
});
