//! Runner progress (run-ready-tasks.ps1): one JSON object per line in the run's events.jsonl; anything else is kept as plain text.
//! Lines are read from a byte offset and decoded leniently, so one malformed byte never stops the reading.
use serde::Serialize;
use serde_json::Value;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, Serialize)]
pub struct RunnerEvent {
    pub line: String,
    pub json: Option<Value>,
}

pub fn parse_line(line: &str) -> RunnerEvent {
    let trimmed = line.trim();
    let json = if trimmed.starts_with('{') {
        serde_json::from_str::<Value>(trimmed).ok().filter(|v| v.get("event").is_some())
    } else {
        None
    };
    RunnerEvent { line: trimmed.to_string(), json }
}

/// The last `n` non-empty lines of a text.
pub fn last_lines(text: &str, n: usize) -> String {
    let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
    lines[lines.len().saturating_sub(n)..].join("\n")
}

/// events.jsonl of a runner run folder (`<date>-runner-run-<time>-<pid>`) under the SecondBrain root, or under the declared
/// SECONDBRAIN_WORK_LOCAL_ROOT; any other folder is refused.
pub fn run_events_file(root: &Path, folder: &Path) -> Result<PathBuf, String> {
    let name = folder.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    if !name.contains("-runner-run-") {
        return Err(format!("Non è una cartella di run del runner: {}", folder.display()));
    }
    let real = folder.canonicalize().map_err(|e| format!("{}: {e}", folder.display()))?;
    let mut allowed: Vec<PathBuf> = vec![root.to_path_buf()];
    if let Ok(local) = std::env::var("SECONDBRAIN_WORK_LOCAL_ROOT") {
        if !local.trim().is_empty() {
            allowed.push(PathBuf::from(local.trim()));
        }
    }
    let inside = allowed.iter().filter_map(|a| a.canonicalize().ok()).any(|a| real.starts_with(&a));
    if !inside {
        return Err(format!("Cartella fuori dalla radice SecondBrain: {}", folder.display()));
    }
    Ok(real.join("events.jsonl"))
}

/// Complete lines after `offset` (a partial last line waits for the next read) and the new offset; an offset past the end restarts at 0.
pub fn read_from(file: &Path, offset: u64) -> Result<Value, String> {
    let mut f = match std::fs::File::open(file) {
        Ok(f) => f,
        Err(_) => return Ok(serde_json::json!({ "events": [], "offset": 0 })),
    };
    let len = f.metadata().map(|m| m.len()).unwrap_or(0);
    let start = if offset > len { 0 } else { offset };
    f.seek(SeekFrom::Start(start)).map_err(|e| e.to_string())?;
    let mut bytes = Vec::new();
    f.read_to_end(&mut bytes).map_err(|e| e.to_string())?;
    let complete = bytes.iter().rposition(|b| *b == b'\n').map(|i| i + 1).unwrap_or(0);
    let text = String::from_utf8_lossy(&bytes[..complete]);
    let events: Vec<RunnerEvent> = text.lines().filter(|l| !l.trim().is_empty()).map(parse_line).collect();
    Ok(serde_json::json!({ "events": events, "offset": start + complete as u64 }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn event_line_is_parsed() {
        let e = parse_line(r#"{"event":"done","message":"[1/1] #3: finished","record":{"id":"T-3","state":"finished"}}"#);
        let j = e.json.unwrap();
        assert_eq!(j["event"], "done");
        assert_eq!(j["record"]["state"], "finished");
    }

    #[test]
    fn plain_text_stays_text() {
        let e = parse_line("Write-Error: something failed");
        assert!(e.json.is_none());
        assert_eq!(e.line, "Write-Error: something failed");
    }

    #[test]
    fn json_without_event_is_text() {
        assert!(parse_line(r#"{"a":1}"#).json.is_none());
    }

    #[test]
    fn reads_complete_lines_from_offset_and_tolerates_bad_bytes() {
        let dir = std::env::temp_dir().join(format!("sb-orch-events-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let file = dir.join("events.jsonl");
        let mut bytes = b"{\"event\":\"start\",\"message\":\"a\"}\n".to_vec();
        bytes.extend_from_slice(&[0xff, 0xfe, b'x', b'\n']);
        bytes.extend_from_slice(b"{\"event\":\"agent\"");
        std::fs::write(&file, &bytes).unwrap();
        let first = read_from(&file, 0).unwrap();
        assert_eq!(first["events"].as_array().unwrap().len(), 2);
        let offset = first["offset"].as_u64().unwrap();
        assert!(offset < bytes.len() as u64);
        let mut more = std::fs::OpenOptions::new().append(true).open(&file).unwrap();
        std::io::Write::write_all(&mut more, b",\"message\":\"b\"}\n").unwrap();
        let second = read_from(&file, offset).unwrap();
        assert_eq!(second["events"][0]["json"]["event"], "agent");
        assert_eq!(read_from(&file, 1 << 40).unwrap()["events"].as_array().unwrap().len(), 3);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn only_runner_folders_under_the_root() {
        let root = std::env::temp_dir().join(format!("sb-orch-root-{}", std::process::id()));
        let run = root.join(".runtime").join("20261112-runner-run-101010-1");
        std::fs::create_dir_all(&run).unwrap();
        assert!(run_events_file(&root, &run).is_ok());
        let other = root.join("plain");
        std::fs::create_dir_all(&other).unwrap();
        assert!(run_events_file(&root, &other).is_err());
        let outside = std::env::temp_dir().join(format!("sb-orch-out-{}-runner-run-1", std::process::id()));
        std::fs::create_dir_all(&outside).unwrap();
        assert!(run_events_file(&root, &outside).is_err());
        let _ = std::fs::remove_dir_all(&root);
        let _ = std::fs::remove_dir_all(&outside);
    }

    #[test]
    fn last_lines_keeps_the_tail() {
        assert_eq!(last_lines("a\n\nb\nc\n", 2), "b\nc");
        assert_eq!(last_lines("", 3), "");
    }
}
