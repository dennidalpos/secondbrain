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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            get_launch_context,
            get_settings,
            save_settings,
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
            local_run
        ])
        .run(tauri::generate_context!())
        .expect("error while running the orchestrator");
}

#[cfg(test)]
mod tests {
    use super::{repo_argument, valid_token};

    #[test]
    fn tokens() {
        assert!(valid_token("claude-opus-5-5"));
        assert!(valid_token("T-12"));
        assert!(!valid_token("a b"));
        assert!(!valid_token("x;rm"));
        assert!(!valid_token(""));
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
