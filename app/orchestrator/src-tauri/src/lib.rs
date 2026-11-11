//! Tauri commands of the orchestrator. Each command calls one SecondBrain PowerShell CLI; the queue runs run-ready-tasks.ps1 -Run -Events.
mod events;
mod pwsh;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::io::{BufRead, BufReader, Read};
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Emitter, Manager, State};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    pub secondbrain_home: String,
    pub pwsh_path: String,
    pub recent_repos: Vec<String>,
}

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
}

struct RunInfo {
    pid: u32,
    stop_file: PathBuf,
}

#[derive(Default)]
struct AppState {
    run: Mutex<Option<RunInfo>>,
}

fn settings_path(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = app.path().app_config_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join("settings.json"))
}

fn load_settings(app: &AppHandle) -> Settings {
    settings_path(app)
        .ok()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .and_then(|t| serde_json::from_str(&t).ok())
        .unwrap_or_default()
}

/// pwsh and the SecondBrain root from the saved settings.
fn context(app: &AppHandle) -> Result<(String, PathBuf), String> {
    let s = load_settings(app);
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

#[tauri::command]
fn get_settings(app: AppHandle) -> Result<Settings, String> {
    let mut s = load_settings(&app);
    if s.secondbrain_home.is_empty() {
        if let Ok(root) = pwsh::resolve_root("") {
            s.secondbrain_home = root.to_string_lossy().into_owned();
        }
    }
    Ok(s)
}

#[tauri::command]
fn save_settings(app: AppHandle, settings: Settings) -> Result<Settings, String> {
    if !settings.secondbrain_home.trim().is_empty() {
        pwsh::resolve_root(&settings.secondbrain_home)?;
    }
    let text = serde_json::to_string_pretty(&settings).map_err(|e| e.to_string())?;
    std::fs::write(settings_path(&app)?, text).map_err(|e| e.to_string())?;
    Ok(settings)
}

#[tauri::command]
async fn probe_agents(app: AppHandle) -> Result<Value, String> {
    script(app, "agents.ps1", vec!["-Probe".into()]).await
}

#[tauri::command]
async fn resolve_repository(app: AppHandle, path: String) -> Result<Value, String> {
    script(app, "prompts.ps1", vec!["-Context".into(), "-RepositoryPath".into(), checkout(&path)?]).await
}

#[tauri::command]
async fn list_tasks(app: AppHandle, repo: String) -> Result<Value, String> {
    // Preview only: runnable tasks with their prompt, and the excluded ones with the reason; nothing is written.
    script(app, "run-ready-tasks.ps1", vec!["-CheckoutPath".into(), checkout(&repo)?, "-MaxTasks".into(), "0".into()]).await
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

#[tauri::command]
async fn preview_directives(app: AppHandle, repo: String, text: String) -> Result<Value, String> {
    // The text goes to a temporary file in the app cache; agents.ps1 copies it into a SecondBrain work folder and previews the proposal.
    let dir = app.path().app_cache_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let stamp = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0);
    let file = dir.join(format!("directives-{stamp}.md"));
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
fn start_queue(app: AppHandle, state: State<'_, AppState>, request: QueueRequest) -> Result<bool, String> {
    let mut guard = state.run.lock().map_err(|e| e.to_string())?;
    if guard.is_some() {
        return Err("Una coda è già in esecuzione.".into());
    }
    if !["claude", "codex", "gemini"].contains(&request.provider.as_str()) {
        return Err(format!("Provider non supportato: {}", request.provider));
    }
    if request.task_ids.is_empty() || !request.task_ids.iter().all(|t| valid_token(t)) {
        return Err("Elenco dei task vuoto o non valido.".into());
    }
    let (pwsh_path, root) = context(&app)?;
    let cache = app.path().app_cache_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&cache).map_err(|e| e.to_string())?;
    let stamp = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0);
    let stop_file = cache.join(format!("stop-{stamp}.flag"));
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
    let mut child = pwsh::script_command(&pwsh_path, &root, "run-ready-tasks.ps1", &args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Avvio del runner non riuscito ({pwsh_path}): {e}"))?;
    let pid = child.id();
    let stderr = child.stderr.take().ok_or("stderr non disponibile")?;
    let mut stdout = child.stdout.take().ok_or("stdout non disponibile")?;
    *guard = Some(RunInfo { pid, stop_file: stop_file.clone() });
    drop(guard);

    let events_app = app.clone();
    let reader = std::thread::spawn(move || {
        for line in BufReader::new(stderr).lines().map_while(Result::ok) {
            if line.trim().is_empty() {
                continue;
            }
            let _ = events_app.emit("runner-event", events::parse_line(&line));
        }
    });
    let out_reader = std::thread::spawn(move || {
        let mut text = String::new();
        let _ = stdout.read_to_string(&mut text);
        text
    });
    let done_app = app.clone();
    std::thread::spawn(move || {
        let code = child.wait().ok().and_then(|s| s.code());
        let _ = reader.join();
        let stdout = out_reader.join().unwrap_or_default();
        let _ = std::fs::remove_file(&stop_file);
        if let Some(state) = done_app.try_state::<AppState>() {
            if let Ok(mut g) = state.run.lock() {
                *g = None;
            }
        }
        let _ = done_app.emit("runner-finished", serde_json::json!({ "code": code, "stdout": stdout }));
    });
    Ok(true)
}

#[tauri::command]
fn stop_queue(state: State<'_, AppState>, force: bool) -> Result<bool, String> {
    let guard = state.run.lock().map_err(|e| e.to_string())?;
    let Some(run) = guard.as_ref() else { return Ok(false) };
    if force {
        pwsh::kill_tree(run.pid)?;
    } else {
        std::fs::write(&run.stop_file, "stop").map_err(|e| e.to_string())?;
    }
    Ok(true)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            get_settings,
            save_settings,
            probe_agents,
            resolve_repository,
            list_tasks,
            read_directives,
            read_text_file,
            preview_directives,
            apply_directives,
            start_queue,
            stop_queue
        ])
        .run(tauri::generate_context!())
        .expect("error while running the orchestrator");
}

#[cfg(test)]
mod tests {
    use super::valid_token;

    #[test]
    fn tokens() {
        assert!(valid_token("claude-opus-5-5"));
        assert!(valid_token("T-12"));
        assert!(!valid_token("a b"));
        assert!(!valid_token("x;rm"));
        assert!(!valid_token(""));
    }
}
