# Team activity register (F6)

Append-only register of who worked on which task, where and with what outcome, plus derived index and map. Development status: implemented and verified on synthetic fixtures; real activation is a separate step (#348).

## Files

All files live in the repository dossier under `history/activity/`.

| File | Role |
|---|---|
| `report.md` | Append-only JSON Lines register. One record per line; never rewritten by the tools. |
| `index.json` | Derived index by repository, user and period (UTC `yyyy-MM`), bound to the register hash. |
| `map.md` | Derived Mermaid map (user → task, repository ↔ task) and period table. Starts with a generated marker. |

`index.json` and `map.md` are regenerated, never edited by hand: a `map.md` without the generated marker is not overwritten.

## Record schema (schemaVersion 1)

Required: `schemaVersion`, `eventId` (32 lowercase hex), `user` (named Windows identity), `repository`, `taskId`, `session`, `when` (date-time), `where` (checkout path or `trace:<folder hash>`), `computer`, `outcome` (`started`, `progress`, `completed`, `blocked`, `failed`), `detail`. Optional: `links.commit` (7–40 hex), `links.pr` (`https://` URL) and `source` (`mcp` default, or `trace`). Subagent jobs add `parent` and `agent` together (see [subagents](subagents.md)). Unknown fields are rejected. `taskId` may be `untracked` only for `source=trace`. A corrupt line or duplicate `eventId` is an error, not silently skipped.

## Commands

    pwsh -NoProfile -File scripts/activity.ps1 -Operation Validate -Repository <identity>
    pwsh -NoProfile -File scripts/activity.ps1 -Operation Index -Repository <identity>
    pwsh -NoProfile -File scripts/activity.ps1 -Operation Index -Repository <identity> -Apply
    pwsh -NoProfile -File scripts/activity.ps1 -Operation Trace -Repository <identity> [-Since <date-time>]
    pwsh -NoProfile -File scripts/activity.ps1 -Operation Trace -Repository <identity> -Apply

- Validate and every operation without `-Apply` are read-only previews.
- Index with `-Apply` writes only the two derived files, and only when the register exists.
- Trace converts metadata-only Stop lines (written only under per-turn persistence permission) into `progress` records with `taskId=untracked`; the eventId is deterministic, so repeated imports add nothing. `-Apply` appends and requires `activityLogEnabled=true` in the configuration, the same gate as the MCP `activity.append` operation. Nothing enables it implicitly.

## Privacy

The register stores a named user. The register contains no prompt text or transcripts. This guide does not establish compliance.

Primary sources checked on 2026-11-07 (#361):

- GDPR, Regulation (EU) 2016/679, jurisdiction EU, registry card `eu-gdpr-consolidation` (verified version `20261028-6a31d0a65d635c77`, Italian consolidated text; application from 2018-05-25 per Art. 99(2)): Art. 5(1)(c) minimisation, Art. 5(1)(e) storage limitation, Art. 6(1)(f) legitimate interest and Art. 13(2)(a) retention period or criteria were found in that transcript. The registry verifies the transcription of the edition, not legal currency.
- Italy, Law 300/1970 Art. 4 (remote monitoring of workers), text in force from 2016-10-08 per Normattiva (registry card `it-statuto-lavoratori-art4` is reference-only, not collected into the registry; the original 2015 wording is acquired and reviewed on pages 130-131 in card `it-dlgs-151-2015`, GU 221 of 2015-09-23 S.O. 53, art. 23 of D.Lgs. 151/2015, and the D.Lgs. 185/2016 amendment of 2016, GU 235 of 2016-10-07, art. 5(2), is acquired and reviewed on page 10 in card it-dlgs-185-2016; on 2026-11-08 (#366) the Normattiva current text, version 3 with no end date, was read and matches the 2016 amendment, with no later amendment to Art. 4 listed; Normattiva is not the official text): information must be given to the worker on use and checks. Whether the register is a monitoring tool for a given team is for the controller to assess.

Decision (retention): named records are kept 12 months, then only aggregated indexes without user are kept. The notice must state purpose, legal basis, controller and this retention rule before activation. Nothing enables the register implicitly; activation stays in #348.

Decision (backups, #367): register writes keep no binary copy of named records. An append leaves the previous register as an exact prefix of the new one, the derived views are regenerable and the retention rewrite is bound to its preview hash, so these writes use the recoverable mode of `Write-SBFile` (stage record only, no `.bin` under `.runtime/backups`). Backups taken earlier are reviewed with `-Operation RetentionBackups` and removed only with explicit `-Apply` and the preview hash. The 12-month window therefore also covers the backups SecondBrain controls.

### Retention

    pwsh -NoProfile -File scripts/activity.ps1 -Operation Retention -Repository <identity> [-AsOf <date>] [-RetentionMonths 12]
    pwsh -NoProfile -File scripts/activity.ps1 -Operation Retention -Repository <identity> -Apply -PreviewSha256 <hash from the preview>

Without `-Apply` it only previews. `-Apply` needs the preview hash (bound to the log hash, the cut-off day and the expired count), moves named records older than the window into `retention.json` (counts by period, repository and outcome; no user, task, session, path or detail) and rewrites the log once with the remaining records. Repeated runs merge into the same file; a run interrupted between the two writes resumes without double counting. The rewrite takes no binary backup of the expired records and regenerates `index.json` and `map.md` when they exist (output field `views`), so expired users and eventIds leave the views too.

    pwsh -NoProfile -File scripts/activity.ps1 -Operation RetentionBackups -Repository <identity> [-AsOf <date>] [-RetentionMonths 12]
    pwsh -NoProfile -File scripts/activity.ps1 -Operation RetentionBackups -Repository <identity> -Apply -PreviewSha256 <hash from the preview>

RetentionBackups reviews `.bin`/`.bin.json` pairs in `backupRoot` whose metadata points to `report.md`, `index.json` or `map.md`. Candidates are index and map copies (regenerable) and register copies in which every record is expired or present unchanged in the current register. Blocked and kept: copies whose hash does not match the metadata (`hash`), copies with a non-expired record missing from the register (`record-not-in-log`), unreadable copies, and `.secondbrain-*.recovery` files of an interrupted write (`incomplete-transaction`; recover them as in [recovery](recovery.md)). The preview hash binds the register hash, the cut-off day and every candidate with its hashes. `-Apply` is refused while the register still holds expired records (run Retention first), re-checks each hash and removes only the listed pairs. Order: Retention, then RetentionBackups. Limits: it does not cover copies outside `backupRoot` (zip archives from `backup.ps1`, team shares, other workstations) or Git history when a dossier is tracked by Git; those must be handled by whoever controls them. Verified on synthetic fixtures only.

## Limits

Verified on synthetic fixtures only (`-Only trace`, activity fixtures 47 checks). Real activation, team-share behavior with different clocks (#219/F11) and the final qualification (#348) are not covered.
