//! PowerShell 7 process helpers: locating pwsh and the SecondBrain root, building commands, parsing JSON output, stopping a process tree.
use serde_json::Value;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Folder of the SecondBrain checkout: explicit setting, SECONDBRAIN_HOME, then the checkout this app was built from.
pub fn resolve_root(setting: &str) -> Result<PathBuf, String> {
    let mut candidates: Vec<PathBuf> = Vec::new();
    if !setting.trim().is_empty() {
        candidates.push(PathBuf::from(setting.trim()));
    }
    if let Ok(home) = std::env::var("SECONDBRAIN_HOME") {
        if !home.trim().is_empty() {
            candidates.push(PathBuf::from(home.trim()));
        }
    }
    candidates.push(Path::new(env!("CARGO_MANIFEST_DIR")).join("../../.."));
    for c in candidates {
        if c.join("scripts").join("agents.ps1").is_file() {
            return Ok(c.canonicalize().unwrap_or(c));
        }
    }
    Err("SecondBrain non trovato: imposta la radice nelle Impostazioni o la variabile SECONDBRAIN_HOME (deve contenere scripts/agents.ps1).".into())
}

/// pwsh from the setting, PATH, or the usual install locations (GUI apps on macOS do not inherit the shell PATH).
pub fn resolve_pwsh(setting: &str) -> String {
    if !setting.trim().is_empty() {
        return setting.trim().to_string();
    }
    let known: &[&str] = if cfg!(windows) {
        &[r"C:\Program Files\PowerShell\7\pwsh.exe"]
    } else {
        &["/opt/homebrew/bin/pwsh", "/usr/local/bin/pwsh", "/usr/bin/pwsh", "/snap/bin/pwsh", "/usr/local/microsoft/powershell/7/pwsh"]
    };
    if which("pwsh") {
        return "pwsh".into();
    }
    known.iter().find(|p| Path::new(p).is_file()).map(|p| p.to_string()).unwrap_or_else(|| "pwsh".into())
}

fn which(name: &str) -> bool {
    let exe = if cfg!(windows) { format!("{name}.exe") } else { name.to_string() };
    std::env::var_os("PATH").map(|paths| std::env::split_paths(&paths).any(|d| d.join(&exe).is_file())).unwrap_or(false)
}

/// PATH for child processes, extended with the usual per-user and Homebrew folders where agent CLIs live.
pub fn child_path() -> Option<std::ffi::OsString> {
    let current = std::env::var_os("PATH").unwrap_or_default();
    if cfg!(windows) {
        return Some(current);
    }
    let mut dirs: Vec<PathBuf> = std::env::split_paths(&current).collect();
    let home = std::env::var_os("HOME").map(PathBuf::from);
    let mut extra: Vec<PathBuf> = vec!["/opt/homebrew/bin".into(), "/usr/local/bin".into()];
    if let Some(h) = home {
        extra.push(h.join(".local/bin"));
        extra.push(h.join(".npm-global/bin"));
        extra.push(h.join(".bun/bin"));
    }
    for e in extra {
        if !dirs.contains(&e) {
            dirs.push(e);
        }
    }
    std::env::join_paths(dirs).ok()
}

/// `pwsh -NoProfile -NonInteractive -File <root>/scripts/<script> <args>` with no console window and its own process group.
pub fn script_command(pwsh: &str, root: &Path, script: &str, args: &[String]) -> Command {
    let mut cmd = Command::new(pwsh);
    cmd.arg("-NoProfile").arg("-NonInteractive").arg("-File").arg(root.join("scripts").join(script));
    cmd.args(args).current_dir(root);
    if let Some(p) = child_path() {
        cmd.env("PATH", p);
    }
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
    }
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        cmd.process_group(0);
    }
    cmd
}

/// The SecondBrain CLIs print one JSON document on stdout, possibly after other lines: parse from the first bracket.
pub fn parse_json_output(stdout: &str) -> Result<Value, String> {
    let start = stdout.find(|c| c == '{' || c == '[').ok_or_else(|| "Nessun JSON nell'output dello script.".to_string())?;
    serde_json::from_str(stdout[start..].trim()).map_err(|e| format!("JSON non valido dallo script: {e}"))
}

/// Runs one script to completion: JSON on success, stderr and stdout as the error otherwise.
pub fn run_json(pwsh: &str, root: &Path, script: &str, args: &[String]) -> Result<Value, String> {
    let output = script_command(pwsh, root, script, args)
        .output()
        .map_err(|e| format!("Avvio di PowerShell non riuscito ({pwsh}): {e}. Installa PowerShell 7.5+ o indica il percorso nelle Impostazioni."))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    if !output.status.success() {
        let text = format!("{}\n{}", stderr.trim(), stdout.trim());
        return Err(format!("{script} terminato con codice {:?}: {}", output.status.code(), text.trim()));
    }
    parse_json_output(&stdout)
}

/// Stops the process and every child (the agent started by the runner).
pub fn kill_tree(pid: u32) -> Result<(), String> {
    let status = if cfg!(windows) {
        let mut cmd = Command::new("taskkill");
        cmd.args(["/PID", &pid.to_string(), "/T", "/F"]);
        #[cfg(windows)]
        {
            use std::os::windows::process::CommandExt;
            cmd.creation_flags(0x0800_0000);
        }
        cmd.status()
    } else {
        Command::new("kill").args(["-TERM", &format!("-{pid}")]).status()
    };
    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("Arresto del processo {pid} non riuscito (codice {:?})", s.code())),
        Err(e) => Err(format!("Arresto del processo {pid} non riuscito: {e}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn json_after_noise() {
        let v = parse_json_output("WARNING: x\n{\"a\":1}\n").unwrap();
        assert_eq!(v["a"], 1);
    }

    #[test]
    fn no_json_is_an_error() {
        assert!(parse_json_output("nothing here").is_err());
    }
}
