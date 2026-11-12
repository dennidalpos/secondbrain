//! The window's own settings (settings.json in the app config folder): SecondBrain root, PowerShell path and recent repositories.
//! Every change re-reads the file and replaces it whole through a temporary sibling, so two actions never overwrite each other
//! with a stale copy kept in memory. SECONDBRAIN_ORCHESTRATOR_CONFIG_DIR moves the folder (isolated end-to-end tests).
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Manager};

pub const RECENT_LIMIT: usize = 12;

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    pub secondbrain_home: String,
    pub pwsh_path: String,
    pub recent_repos: Vec<String>,
    /// Light model of the one-shot analyses (directive proposals, task analysis): provider, model and effort; empty = the agent
    /// chosen in the queue with the light role of config/agent-models.json.
    pub light_provider: String,
    pub light_model: String,
    pub light_effort: String,
}

fn config_dir(app: &AppHandle) -> Result<PathBuf, String> {
    if let Ok(dir) = std::env::var("SECONDBRAIN_ORCHESTRATOR_CONFIG_DIR") {
        if !dir.trim().is_empty() {
            return Ok(PathBuf::from(dir.trim()));
        }
    }
    app.path().app_config_dir().map_err(|e| e.to_string())
}

pub fn path(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = config_dir(app)?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join("settings.json"))
}

pub fn read_file(file: &Path) -> Settings {
    std::fs::read_to_string(file).ok().and_then(|t| serde_json::from_str(&t).ok()).unwrap_or_default()
}

pub fn write_file(file: &Path, settings: &Settings) -> Result<(), String> {
    let text = serde_json::to_string_pretty(settings).map_err(|e| e.to_string())?;
    let temp = file.with_extension(format!("json.{}.tmp", std::process::id()));
    std::fs::write(&temp, text).map_err(|e| e.to_string())?;
    std::fs::rename(&temp, file).map_err(|e| {
        let _ = std::fs::remove_file(&temp);
        e.to_string()
    })
}

pub fn load(app: &AppHandle) -> Settings {
    path(app).map(|p| read_file(&p)).unwrap_or_default()
}

/// Read, change, write: the change applies to what is on disk now.
pub fn update(app: &AppHandle, change: impl FnOnce(&mut Settings)) -> Result<Settings, String> {
    let file = path(app)?;
    let mut s = read_file(&file);
    change(&mut s);
    write_file(&file, &s)?;
    Ok(s)
}

fn same_path(a: &str, b: &str) -> bool {
    let norm = |s: &str| s.trim().trim_end_matches(['\\', '/']).replace('\\', "/");
    if cfg!(windows) {
        norm(a).eq_ignore_ascii_case(&norm(b))
    } else {
        norm(a) == norm(b)
    }
}

/// Most recent first, no duplicates (same path in another spelling included), at most RECENT_LIMIT entries.
pub fn push_recent(list: &mut Vec<String>, path: &str) {
    if path.trim().is_empty() {
        return;
    }
    list.retain(|p| !same_path(p, path));
    list.insert(0, path.trim().to_string());
    list.truncate(RECENT_LIMIT);
}

pub fn remove_recent(list: &mut Vec<String>, path: &str) {
    list.retain(|p| !same_path(p, path));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recent_list_rules() {
        let mut l = vec!["/a".to_string(), "/b".to_string()];
        push_recent(&mut l, "/b/");
        assert_eq!(l, vec!["/b/".to_string(), "/a".to_string()]);
        remove_recent(&mut l, "/b");
        assert_eq!(l, vec!["/a".to_string()]);
        for i in 0..20 {
            push_recent(&mut l, &format!("/r{i}"));
        }
        assert_eq!(l.len(), RECENT_LIMIT);
        push_recent(&mut l, "  ");
        assert_eq!(l.len(), RECENT_LIMIT);
    }

    #[test]
    fn file_round_trip_keeps_changes_of_others() {
        let dir = std::env::temp_dir().join(format!("sb-orch-settings-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let file = dir.join("settings.json");
        let mut first = Settings::default();
        push_recent(&mut first.recent_repos, "/one");
        write_file(&file, &first).unwrap();
        // Another action removes the entry; a later change re-reads the file instead of writing back a stale copy.
        let mut on_disk = read_file(&file);
        remove_recent(&mut on_disk.recent_repos, "/one");
        write_file(&file, &on_disk).unwrap();
        let mut later = read_file(&file);
        later.pwsh_path = "pwsh".into();
        write_file(&file, &later).unwrap();
        let end = read_file(&file);
        assert!(end.recent_repos.is_empty());
        assert_eq!(end.pwsh_path, "pwsh");
        let _ = std::fs::remove_dir_all(&dir);
    }
}
