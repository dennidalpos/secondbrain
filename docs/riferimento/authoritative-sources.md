# Authoritative sources

[Retained Italian source; use this English page for current behavior](authoritative-sources.it.md)

Resolve the resource-authoritative-sources identity through PARA and validate para.json. Source cards and version manifests are authoritative; catalog.json and README are generated views. Folder names alone do not establish identity.

## Source versions and applicability

Cards follow source.schema.json and identify issuer, jurisdiction, language, rights, registered HTTPS endpoints, relationships and effective dates. Original bytes retain SHA-256 hashes; every version has a manifest, transcription and diagnostics.

acceptedVersion requires a verified review.json with reviewer/date, fingerprint, transcription hash and checks of structure, tables/numbers and cited passages. This qualifies transcription, not product compliance or complete current legal validity.

Dossier authoritative-sources.json follows source-applicability.schema.json. Applicability and implementation have separate states; a lexical citation proves neither. Inventories preserve locations/hashes/coverage and exclude secrets, dependencies, history and snapshots.

Registry profiles are advisory. New common instructions still require concrete text approval, hashes, Sync and SYS01.

## Commands and writes

~~~powershell
pwsh -NoProfile -File scripts/sources.ps1 -Check
pwsh -NoProfile -File scripts/sources.ps1 -Probe
~~~

Run from the brain checkout. Check is local; Probe accesses the network and does not save unless SaveReport is requested. Collect stores a candidate, not an accepted version or directive. BuildIndex regenerates views. Writing operations require the authorized session.

Repeated identical originals do not create another version. Preserve interrupted directories. Resume conversion into a new file with manifest preconditions and verified backups; retain originals and alternative transcriptions by hash.

Probe releases coordination while networking and binds the report to source-card hashes. Changing a card invalidates freshness. Exit codes: 0 regular, 1 changes/reviews pending, 2 error/incomplete coverage, 3 contention.

## Conversion

The dedicated runtime Python 3.13 environment (runtime sources/python) is installed from source-requirements.lock.txt; it is not a product-build dependency. The lock pins 30 packages, each with the sha256 of every PyPI file of that version, so install it with hash checking: `python -m pip install --require-hashes -r scripts/source-requirements.lock.txt`. After changing a pin, regenerate all hashes for that version before installing. Local streams are converted with plugins/cloud services disabled.

PDF conversion combines MarkItDown with pdfplumber page/table diagnostics. The original PDF remains authoritative for layout/graphics/images; unsupported scans are reported. Other supported formats retain their own diagnostics. Dataset numbers are not silently converted to floating point.

Downloads are limited to 50 MiB, 30 seconds and five redirects through registered hosts with public addresses. Authentication bypass is not attempted. Unavailable endpoints and unsupported formats receive explicit outcomes.

## Reports and verification

Probe and collection are explicit; no source-monitor schedule is installed. Reports live under runtimeRoot/sources/reports, with latest.json as a view. Check flags missing/incompatible results, results older than 14 days, changes and incomplete coverage. Retention remains subject to authorized cleanup.

Offline consultation is supported. test-secondbrain-sources.ps1 covers fixtures; PythonPath adds real converter checks. Stored sources and fixture results do not certify general regulatory compliance.

See [CLI](../../scripts/sources.ps1), [schema](../../config/source.schema.json) and [MarkItDown](https://github.com/microsoft/markitdown).
