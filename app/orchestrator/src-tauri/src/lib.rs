//! Tauri commands of the orchestrator. Each command calls one SecondBrain PowerShell CLI; the queue starts run-ready-tasks.ps1 -Run
//! detached (its output goes to a log file) and the window follows it through the run's status.json and events.jsonl, so a run keeps
//! going when the window closes and is found again when it reopens.
mod events;
mod pwsh;
mod settings;

use serde::Deserialize;
use serde_json::Value;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Emitter, Manager, State};

pub use settings::Settings;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QueueRequest {
    pub repo: String,
    pub provider: String,
    pub model: Option<String>,
    pub effort: Option<String>,
    #[serde(default)]
    pub allow_custom_model: bool,
    pub task_ids: Vec<String>,
    pub timeout_minutes: u32,
    #[serde(default)]
    pub stall_minutes: Option<u32>,
}

/// The runner started by this window (while it lives): its process and its stop file.
struct RunInfo {
    pid: u32,
    stop_file: PathBuf,
}

#[derive(Default)]
struct AppState {
    run: Mutex<Option<RunInfo>>,
}

/// pwsh and the SecondBrain root from the saved settings.
fn context(app: &AppHandle) -> Result<(String, PathBuf), String> {
    let s = settings::load(app);
    Ok((pwsh::resolve_pwsh(&s.pwsh_path), pwsh::resolve_root(&s.secondbrain_home)?))
}

async fn script(app: AppHandle, name: &'static str, args: Vec<String>) -> Result<Value, String> {
    let (pwsh_path, root) = context(&app)?;
    tauri::async_runtime::spawn_blocking(move || pwsh::run_json(&pwsh_path, &root, name, &args))
        .await
        .map_err(|e| e.to_string())?
}

fn checkout(path: &str) -> Result<String, String> {
    let p = PathBuf::from(path.trim());
    if !p.is_dir() {
        return Err(format!("Cartella non trovata: {path}"));
    }
    Ok(p.to_string_lossy().into_owned())
}

/// `--repo <path>` or `--repo=<path>` among the process arguments (sb runner passes the checkout it was started from).
pub fn repo_argument(args: &[String]) -> Option<String> {
    let mut it = args.iter();
    while let Some(a) = it.next() {
        if a == "--repo" {
            return it.next().map(|v| v.trim().to_string()).filter(|v| !v.is_empty());
        }
        if let Some(v) = a.strip_prefix("--repo=") {
            let v = v.trim();
            if !v.is_empty() {
                return Some(v.to_string());
            }
        }
    }
    None
}

#[tauri::command]
fn get_launch_context(app: AppHandle) -> Value {
    // What the window needs at start: the repository passed by sb runner, the effective SecondBrain root and PowerShell.
    let args: Vec<String> = std::env::args().collect();
    let s = settings::load(&app);
    let root = pwsh::resolve_root(&s.secondbrain_home);
    serde_json::json!({
        "repo": repo_argument(&args),
        "secondbrainHome": root.as_ref().map(|p| p.to_string_lossy().into_owned()).ok(),
        "rootError": root.err(),
        "pwsh": pwsh::resolve_pwsh(&s.pwsh_path),
        "version": env!("CARGO_PKG_VERSION"),
    })
}

#[tauri::command]
fn get_settings(app: AppHandle) -> Result<Settings, String> {
    // As saved: an empty root means "SECONDBRAIN_HOME or the build checkout" and is never filled in here, so it is not persisted by accident.
    Ok(settings::load(&app))
}

#[tauri::command]
fn save_settings(app: AppHandle, secondbrain_home: String, pwsh_path: String) -> Result<Settings, String> {
    if !secondbrain_home.trim().is_empty() {
        pwsh::resolve_root(&secondbrain_home)?;
    }
    settings::update(&app, |s| {
        s.secondbrain_home = secondbrain_home.trim().to_string();
        s.pwsh_path = pwsh_path.trim().to_string();
    })
}

#[tauri::command]
fn save_light_model(app: AppHandle, provider: String, model: String, effort: String) -> Result<Settings, String> {
    // Empty values are allowed: they mean "agent of the queue" and "light role of the model table".
    if !provider.is_empty() && !valid_provider(&provider) {
        return Err(format!("Provider non supportato: {provider}"));
    }
    for v in [&model, &effort] {
        if !v.is_empty() && !valid_token(v) {
            return Err(format!("Valore non valido: {v}"));
        }
    }
    settings::update(&app, |s| {
        s.light_provider = provider.trim().to_string();
        s.light_model = model.trim().to_string();
        s.light_effort = effort.trim().to_string();
    })
}

#[tauri::command]
fn list_recent_repos(app: AppHandle) -> Value {
    let s = settings::load(&app);
    Value::Array(s.recent_repos.iter().map(|p| serde_json::json!({ "path": p, "exists": Path::new(p).is_dir() })).collect())
}

#[tauri::command]
fn add_recent_repo(app: AppHandle, path: String) -> Result<Settings, String> {
    let path = path.trim().to_string();
    settings::update(&app, |s| settings::push_recent(&mut s.recent_repos, &path))
}

#[tauri::command]
fn remove_recent_repo(app: AppHandle, path: String) -> Result<Settings, String> {
    settings::update(&app, |s| settings::remove_recent(&mut s.recent_repos, &path))
}

#[tauri::command]
async fn probe_agents(app: AppHandle) -> Result<Value, String> {
    script(app, "agents.ps1", vec!["-Probe".into(), "-Clients".into()]).await
}

#[tauri::command]
async fn resolve_repository(app: AppHandle, path: String) -> Result<Value, String> {
    script(app, "prompts.ps1", vec!["-Context".into(), "-RepositoryPath".into(), checkout(&path)?]).await
}

fn valid_provider(p: &str) -> bool {
    ["claude", "codex", "gemini"].contains(&p)
}

#[tauri::command]
async fn list_tasks(app: AppHandle, repo: String, provider: Option<String>) -> Result<Value, String> {
    // Preview only: runnable tasks with their prompt, and the excluded ones with the reason; nothing is written.
    // The provider decides the computer-use filter, so the preview uses the agent chosen in the queue.
    let mut args = vec!["-CheckoutPath".into(), checkout(&repo)?, "-MaxTasks".into(), "0".into()];
    if let Some(p) = provider.filter(|p| valid_provider(p)) {
        args.push("-Provider".into());
        args.push(p);
    }
    script(app, "run-ready-tasks.ps1", args).await
}

#[tauri::command]
async fn read_directives(app: AppHandle, repo: String) -> Result<Value, String> {
    script(app, "agents.ps1", vec!["-Directives".into(), "-RepositoryPath".into(), checkout(&repo)?]).await
}

#[tauri::command]
fn read_text_file(path: String) -> Result<String, String> {
    // Directive files only: Markdown, at most 2 MB.
    let p = PathBuf::from(&path);
    let is_md = p.extension().map(|e| e.eq_ignore_ascii_case("md")).unwrap_or(false);
    if !is_md {
        return Err("Sono ammessi solo file Markdown (.md).".into());
    }
    let meta = std::fs::metadata(&p).map_err(|e| format!("{path}: {e}"))?;
    if meta.len() > 2 * 1024 * 1024 {
        return Err("File troppo grande (oltre 2 MB).".into());
    }
    std::fs::read_to_string(&p).map_err(|e| format!("{path}: {e}"))
}

fn stamp() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0)
}

#[tauri::command]
async fn preview_directives(app: AppHandle, repo: String, text: String) -> Result<Value, String> {
    // The text goes to a temporary file in the app cache; agents.ps1 copies it into a SecondBrain work folder and previews the proposal.
    let dir = app.path().app_cache_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let file = dir.join(format!("directives-{}.md", stamp()));
    std::fs::write(&file, text).map_err(|e| e.to_string())?;
    let args = vec![
        "-Directives".into(),
        "-RepositoryPath".into(),
        checkout(&repo)?,
        "-DirectivesFile".into(),
        file.to_string_lossy().into_owned(),
    ];
    let result = script(app, "agents.ps1", args).await;
    let _ = std::fs::remove_file(&file);
    result
}

#[tauri::command]
async fn apply_directives(app: AppHandle, repo: String, proposal_path: String, proposal_hash: String, authorization: String) -> Result<Value, String> {
    if proposal_hash.len() != 64 || !proposal_hash.chars().all(|c| c.is_ascii_hexdigit()) {
        return Err("Hash della proposta non valido.".into());
    }
    let args = vec![
        "-Directives".into(),
        "-RepositoryPath".into(),
        checkout(&repo)?,
        "-ProposalPath".into(),
        proposal_path,
        "-ExpectedProposalHash".into(),
        proposal_hash,
        "-Authorization".into(),
        authorization,
        "-Apply".into(),
    ];
    script(app, "agents.ps1", args).await
}

fn valid_token(value: &str) -> bool {
    !value.is_empty() && value.len() <= 120 && value.chars().all(|c| c.is_ascii_alphanumeric() || "._-:/@[]".contains(c))
}
/// Model and effort of an analysis: the explicit choice, or nothing for the light role of the model table.
fn analysis_args(args: &mut Vec<String>, provider: &str, model: Option<String>, effort: Option<String>) -> Result<(), String> {
    if !valid_provider(provider) {
        return Err(format!("Provider non supportato: {provider}"));
    }
    args.push("-Provider".into());
    args.push(provider.into());
    if let Some(m) = model.filter(|m| !m.trim().is_empty()) {
        if !valid_token(m.trim()) {
            return Err(format!("Nome del modello non valido: {m}"));
        }
        args.push("-Model".into());
        args.push(m.trim().into());
        args.push("-AllowCustomModel".into());
    }
    if let Some(e) = effort.filter(|e| !e.trim().is_empty()) {
        if !valid_token(e.trim()) {
            return Err(format!("Livello di impegno non valido: {e}"));
        }
        args.push("-Effort".into());
        args.push(e.trim().into());
    }
    Ok(())
}

#[tauri::command]
async fn analyze_directives(app: AppHandle, repo: String, provider: String, model: Option<String>, effort: Option<String>) -> Result<Value, String> {
    // One read-only run of the light model in the checkout (DOC06): proposed sections, what is covered elsewhere, warnings, counts.
    let mut args = vec!["-Analyze".into(), "-Kind".into(), "directives".into(), "-RepositoryPath".into(), checkout(&repo)?];
    analysis_args(&mut args, &provider, model, effort)?;
    script(app, "agents.ps1", args).await
}

#[tauri::command]
async fn analyze_task(app: AppHandle, repo: String, task_id: String, provider: String, model: Option<String>, effort: Option<String>) -> Result<Value, String> {
    // First round of the autonomy analysis of one task (REP18): verdict and tool calls (questions or the proposed update).
    if !valid_token(&task_id) {
        return Err("ID del task non valido.".into());
    }
    let mut args = vec!["-Analyze".into(), "-Kind".into(), "task".into(), "-RepositoryPath".into(), checkout(&repo)?, "-TaskId".into(), task_id];
    analysis_args(&mut args, &provider, model, effort)?;
    script(app, "agents.ps1", args).await
}

fn analysis_folder(path: &str) -> Result<String, String> {
    let p = PathBuf::from(path.trim());
    let name = p.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    if !p.is_dir() || !name.contains("-analysis-task-") {
        return Err(format!("Cartella di analisi non valida: {path}"));
    }
    Ok(p.to_string_lossy().into_owned())
}

#[tauri::command]
async fn view_task_analysis(app: AppHandle, repo: String, analysis_path: String) -> Result<Value, String> {
    let args = vec![
        "-Analyze".into(),
        "-Kind".into(),
        "task-view".into(),
        "-RepositoryPath".into(),
        checkout(&repo)?,
        "-AnalysisPath".into(),
        analysis_folder(&analysis_path)?,
    ];
    script(app, "agents.ps1", args).await
}

#[tauri::command]
async fn resolve_task_analysis(app: AppHandle, repo: String, analysis_path: String, answers: Value) -> Result<Value, String> {
    // The owner's answers go to a temporary JSON file; agents.ps1 records them in the analysis folder and runs the next round.
    if answers.as_array().map(|a| a.is_empty()).unwrap_or(true) {
        return Err("Nessuna risposta da inviare.".into());
    }
    let dir = app.path().app_cache_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let file = dir.join(format!("answers-{}.json", stamp()));
    std::fs::write(&file, serde_json::to_string(&answers).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
    let args = vec![
        "-Analyze".into(),
        "-Kind".into(),
        "task-resolve".into(),
        "-RepositoryPath".into(),
        checkout(&repo)?,
        "-AnalysisPath".into(),
        analysis_folder(&analysis_path)?,
        "-AnswersFile".into(),
        file.to_string_lossy().into_owned(),
    ];
    let result = script(app, "agents.ps1", args).await;
    let _ = std::fs::remove_file(&file);
    result
}

#[tauri::command]
async fn apply_task_analysis(app: AppHandle, repo: String, analysis_path: String, authorization: String) -> Result<Value, String> {
    if authorization.trim().is_empty() || authorization.len() > 300 {
        return Err("Autorizzazione mancante o troppo lunga.".into());
    }
    let args = vec![
        "-Analyze".into(),
        "-Kind".into(),
        "task-apply".into(),
        "-RepositoryPath".into(),
        checkout(&repo)?,
        "-AnalysisPath".into(),
        analysis_folder(&analysis_path)?,
        "-Authorization".into(),
        authorization,
    ];
    script(app, "agents.ps1", args).await
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegistryQuery {
    pub repo: String,
    #[serde(default)]
    pub page: u32,
    #[serde(default)]
    pub page_size: Option<u32>,
    pub tool: Option<String>,
    pub status: Option<String>,
    pub archived: Option<String>,
    pub search: Option<String>,
}

/// Arguments of knowledge.ps1 -Registry from the window's filters (values checked against their closed sets).
fn registry_args(q: &RegistryQuery, checkout_path: String) -> Result<Vec<String>, String> {
    let mut args = vec![
        "-Registry".into(),
        "-CheckoutPath".into(),
        checkout_path,
        "-Page".into(),
        q.page.to_string(),
        "-PageSize".into(),
        q.page_size.unwrap_or(50).min(500).to_string(),
    ];
    if let Some(t) = q.tool.as_deref().filter(|t| !t.is_empty()) {
        if !["claude", "codex", "gemini", "antigravity", "human", "unknown"].contains(&t) {
            return Err(format!("Strumento non valido: {t}"));
        }
        args.push("-Tool".into());
        args.push(t.into());
    }
    if let Some(s) = q.status.as_deref().filter(|s| !s.is_empty()) {
        if !["todo", "in_progress", "blocked", "done", "cancelled", "unknown"].contains(&s) {
            return Err(format!("Stato non valido: {s}"));
        }
        args.push("-TaskStatus".into());
        args.push(s.into());
    }
    if let Some(a) = q.archived.as_deref().filter(|a| !a.is_empty()) {
        if !["include", "exclude", "only"].contains(&a) {
            return Err(format!("Filtro archivio non valido: {a}"));
        }
        args.push("-Archived".into());
        args.push(a.into());
    }
    if let Some(s) = q.search.as_deref().map(str::trim).filter(|s| !s.is_empty()) {
        if s.len() > 100 || s.chars().any(|c| c.is_control()) {
            return Err("Testo di ricerca non valido.".into());
        }
        args.push("-Filter".into());
        args.push(s.into());
    }
    Ok(args)
}

#[tauri::command]
async fn read_registry(app: AppHandle, query: RegistryQuery) -> Result<Value, String> {
    // Every task of the repository (active and archived) with the tools that worked on it: dossier ledger plus runner reports.
    let args = registry_args(&query, checkout(&query.repo)?)?;
    script(app, "knowledge.ps1", args).await
}

#[tauri::command]
async fn list_runs(app: AppHandle, repo: String, limit: Option<u32>) -> Result<Value, String> {
    let n = limit.unwrap_or(50).min(1000).to_string();
    script(app, "runner-status.ps1", vec!["-CheckoutPath".into(), checkout(&repo)?, "-List".into(), "-Limit".into(), n]).await
}

#[tauri::command]
async fn add_run_note(app: AppHandle, repo: String, folder: String, note: String) -> Result<Value, String> {
    // A note of the window (start, stop, reattach) kept in the run's events.jsonl, so it survives a reattach.
    let note = note.trim().to_string();
    if note.is_empty() || note.len() > 500 || note.chars().any(|c| c.is_control()) {
        return Err("Nota non valida.".into());
    }
    script(app, "runner-status.ps1", vec!["-CheckoutPath".into(), checkout(&repo)?, "-Note".into(), note, "-RunFolder".into(), folder]).await
}


#[tauri::command]
fn start_queue(app: AppHandle, state: State<'_, AppState>, request: QueueRequest) -> Result<Value, String> {
    let mut guard = state.run.lock().map_err(|e| e.to_string())?;
    if guard.is_some() {
        return Err("Una coda avviata da questa finestra è già in esecuzione.".into());
    }
    if !valid_provider(&request.provider) {
        return Err(format!("Provider non supportato: {}", request.provider));
    }
    if request.task_ids.is_empty() || !request.task_ids.iter().all(|t| valid_token(t)) {
        return Err("Elenco dei task vuoto o non valido.".into());
    }
    let (pwsh_path, root) = context(&app)?;
    let cache = app.path().app_cache_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&cache).map_err(|e| e.to_string())?;
    let id = stamp();
    let stop_file = cache.join(format!("stop-{id}.flag"));
    let log_file = cache.join(format!("runner-{id}.log"));
    let mut args: Vec<String> = vec![
        "-CheckoutPath".into(),
        checkout(&request.repo)?,
        "-Run".into(),
        "-Events".into(),
        "-MaxTasks".into(),
        "0".into(),
        "-TimeoutMinutes".into(),
        request.timeout_minutes.clamp(1, 240).to_string(),
        "-Provider".into(),
        request.provider.clone(),
        "-TaskIds".into(),
        request.task_ids.join(","),
        "-StopFile".into(),
        stop_file.to_string_lossy().into_owned(),
    ];
    if let Some(s) = request.stall_minutes {
        args.push("-StallMinutes".into());
        args.push(s.clamp(1, 240).to_string());
    }
    if let Some(m) = request.model.as_deref().filter(|m| !m.is_empty()) {
        if !valid_token(m) {
            return Err(format!("Nome del modello non valido: {m}"));
        }
        args.push("-Model".into());
        args.push(m.into());
    }
    if let Some(e) = request.effort.as_deref().filter(|e| !e.is_empty()) {
        if !valid_token(e) {
            return Err(format!("Livello di impegno non valido: {e}"));
        }
        args.push("-Effort".into());
        args.push(e.into());
    }
    if request.allow_custom_model {
        args.push("-AllowCustomModel".into());
    }
    // The person confirmed model and effort in the window (a "predefinito" entry is an explicit choice of the CLI default):
    // the runner refuses an unattended start without that choice, so the window states it.
    let has_model = request.model.as_deref().is_some_and(|m| !m.is_empty());
    let has_effort = request.effort.as_deref().is_some_and(|e| !e.is_empty());
    if !has_model || !has_effort {
        args.push("-UseCliDefault".into());
    }
    // Output to files, not pipes: the runner must outlive the window (a closed pipe would break its progress writes).
    let err = std::fs::File::create(&log_file).map_err(|e| e.to_string())?;
    let out = std::fs::File::create(log_file.with_extension("out")).map_err(|e| e.to_string())?;
    let mut child = pwsh::script_command(&pwsh_path, &root, "run-ready-tasks.ps1", &args)
        .stdin(Stdio::null())
        .stdout(Stdio::from(out))
        .stderr(Stdio::from(err))
        .spawn()
        .map_err(|e| format!("Avvio del runner non riuscito ({pwsh_path}): {e}"))?;
    let pid = child.id();
    *guard = Some(RunInfo { pid, stop_file: stop_file.clone() });
    drop(guard);

    let done_app = app.clone();
    let log = log_file.clone();
    std::thread::spawn(move || {
        let code = child.wait().ok().and_then(|s| s.code());
        let _ = std::fs::remove_file(&stop_file);
        if let Some(state) = done_app.try_state::<AppState>() {
            if let Ok(mut g) = state.run.lock() {
                *g = None;
            }
        }
        // The last lines of the runner log explain a run that ended before its status existed (busy repository, invalid model).
        let tail = std::fs::read_to_string(&log).map(|t| events::last_lines(&t, 12)).unwrap_or_default();
        let stdout = std::fs::read_to_string(log.with_extension("out")).unwrap_or_default();
        let _ = done_app.emit("runner-finished", serde_json::json!({ "code": code, "pid": pid, "log": tail, "stdout": stdout }));
    });
    Ok(serde_json::json!({ "pid": pid, "log": log_file.to_string_lossy() }))
}

#[tauri::command]
async fn get_run_status(app: AppHandle, repo: String, tail: Option<u32>) -> Result<Value, String> {
    // Active run of the repository (or the newest one) as runner-status.ps1 reports it: verdict, ages, status.json, recent events.
    let n = tail.unwrap_or(0).min(500).to_string();
    script(app, "runner-status.ps1", vec!["-CheckoutPath".into(), checkout(&repo)?, "-Tail".into(), n]).await
}

#[tauri::command]
fn read_run_events(app: AppHandle, folder: String, offset: u64) -> Result<Value, String> {
    // New lines of events.jsonl from a byte offset; the folder must be a runner run folder under the SecondBrain root.
    let (_, root) = context(&app)?;
    let file = events::run_events_file(&root, Path::new(&folder))?;
    events::read_from(&file, offset)
}

#[tauri::command]
async fn stop_queue(app: AppHandle, state: State<'_, AppState>, repo: String, force: bool) -> Result<bool, String> {
    // A run started by this window: its stop file or its process tree. A run found again after a restart: runner-status.ps1 -Stop,
    // or the process recorded in its status.json.
    let local = {
        let guard = state.run.lock().map_err(|e| e.to_string())?;
        guard.as_ref().map(|r| (r.pid, r.stop_file.clone()))
    };
    if let Some((pid, stop_file)) = local {
        if force {
            pwsh::kill_tree(pid)?;
        } else {
            std::fs::write(&stop_file, "stop").map_err(|e| e.to_string())?;
        }
        return Ok(true);
    }
    if !force {
        script(app, "runner-status.ps1", vec!["-CheckoutPath".into(), checkout(&repo)?, "-Stop".into()]).await?;
        return Ok(true);
    }
    let status = script(app, "runner-status.ps1", vec!["-CheckoutPath".into(), checkout(&repo)?, "-Tail".into(), "0".into()]).await?;
    let active = status.get("active").and_then(Value::as_bool).unwrap_or(false);
    let pid = status.pointer("/status/pid").and_then(Value::as_u64).filter(|p| *p > 0);
    match (active, pid) {
        (true, Some(pid)) => {
            pwsh::kill_tree(pid as u32)?;
            Ok(true)
        }
        _ => Ok(false),
    }
}

#[tauri::command]
fn local_run(state: State<'_, AppState>) -> Option<u32> {
    // PID of the runner started by this window, if it is still running.
    state.run.lock().ok().and_then(|g| g.as_ref().map(|r| r.pid))
}

/// Browser arguments of the windows when WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS is set: wry always passes its own arguments through the
/// WebView2 API, and the runtime then ignores the variable, so the app forwards it after wry's defaults (the end-to-end tests open the
/// DevTools port this way). None leaves wry's defaults untouched.
fn browser_args(extra: Option<String>) -> Option<String> {
    let extra = extra.map(|e| e.trim().to_string()).filter(|e| !e.is_empty())?;
    Some(format!("--disable-features=msWebOOUI,msPdfOOUI,msSmartScreenProtection {extra}"))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let mut context = tauri::generate_context!();
    if let Some(args) = browser_args(std::env::var("WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS").ok()) {
        for window in context.config_mut().app.windows.iter_mut() {
            window.additional_browser_args = Some(args.clone());
        }
    }
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            get_launch_context,
            get_settings,
            save_settings,
            save_light_model,
            list_recent_repos,
            add_recent_repo,
            remove_recent_repo,
            probe_agents,
            resolve_repository,
            list_tasks,
            read_directives,
            read_text_file,
            preview_directives,
            apply_directives,
            start_queue,
            get_run_status,
            read_run_events,
            stop_queue,
            local_run,
            analyze_directives,
            analyze_task,
            view_task_analysis,
            resolve_task_analysis,
            apply_task_analysis,
            read_registry,
            list_runs,
            add_run_note
        ])
        .run(context)
        .expect("error while running the orchestrator");
}

#[cfg(test)]
mod tests {
    use super::{analysis_args, browser_args, registry_args, repo_argument, valid_token, RegistryQuery};

    #[test]
    fn webview_arguments() {
        assert_eq!(browser_args(None), None);
        assert_eq!(browser_args(Some("  ".into())), None);
        let args = browser_args(Some("--remote-debugging-port=9333".into())).unwrap();
        assert!(args.starts_with("--disable-features=msWebOOUI,msPdfOOUI,msSmartScreenProtection "));
        assert!(args.ends_with("--remote-debugging-port=9333"));
    }

    #[test]
    fn tokens() {
        assert!(valid_token("claude-opus-5-5"));
        assert!(valid_token("T-12"));
        assert!(!valid_token("a b"));
        assert!(!valid_token("x;rm"));
        assert!(!valid_token(""));
    }

    #[test]
    fn analysis_and_registry_arguments() {
        let mut a: Vec<String> = Vec::new();
        assert!(analysis_args(&mut a, "claude", Some("haiku".into()), None).is_ok());
        assert_eq!(a, vec!["-Provider", "claude", "-Model", "haiku", "-AllowCustomModel"]);
        let mut b: Vec<String> = Vec::new();
        assert!(analysis_args(&mut b, "other", None, None).is_err());
        assert!(analysis_args(&mut b, "codex", Some("x;y".into()), None).is_err());
        let q = |tool: Option<&str>, status: Option<&str>, search: Option<&str>| RegistryQuery {
            repo: ".".into(),
            page: 1,
            page_size: Some(20),
            tool: tool.map(Into::into),
            status: status.map(Into::into),
            archived: Some("only".into()),
            search: search.map(Into::into),
        };
        let args = registry_args(&q(Some("codex"), Some("done"), Some(" runner ")), "C".into()).unwrap();
        assert!(args.windows(2).any(|w| w == ["-Tool", "codex"]));
        assert!(args.windows(2).any(|w| w == ["-TaskStatus", "done"]));
        assert!(args.windows(2).any(|w| w == ["-Filter", "runner"]));
        assert!(args.windows(2).any(|w| w == ["-Page", "1"]));
        assert!(registry_args(&q(Some("vim"), None, None), "C".into()).is_err());
        assert!(registry_args(&q(None, Some("open"), None), "C".into()).is_err());
        assert!(registry_args(&q(None, None, Some("a\nb")), "C".into()).is_err());
    }

    #[test]
    fn repo_argument_forms() {
        let a = |v: &[&str]| v.iter().map(|s| s.to_string()).collect::<Vec<_>>();
        assert_eq!(repo_argument(&a(&["app", "--repo", "D:/x y"])), Some("D:/x y".into()));
        assert_eq!(repo_argument(&a(&["app", "--repo=/srv/u/p"])), Some("/srv/u/p".into()));
        assert_eq!(repo_argument(&a(&["app", "--repo"])), None);
        assert_eq!(repo_argument(&a(&["app", "--repo", "  "])), None);
        assert_eq!(repo_argument(&a(&["app"])), None);
    }
}
