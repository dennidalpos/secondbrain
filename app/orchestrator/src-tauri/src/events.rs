//! Runner progress lines (run-ready-tasks.ps1 -Events): one JSON object per stderr line; anything else is kept as plain text.
use serde::Serialize;
use serde_json::Value;

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
}
