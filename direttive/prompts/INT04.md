# INT04 — Verify internationalization of strings, formats and translations

> **Scope**: repo/area | **Mode**: verify | **Needs**: interface or messages with supported languages and formats | **Example**: `verify the strings, formats and translations of the CLI`

## Purpose

Verify that the interface's strings, messages, dates, numbers and encodings respect the supported languages and locales.

## When to use

Before releasing an interface or messages in several languages or with regional formats. For accessibility use INT03, to implement the screens INT02.

## Input

List of supported languages and locales, resource files or strings in the code, a working interface, file encodings.

## Activities

Find strings embedded in code, concatenations that prevent translation, fixed date, time, number and currency formats, language-dependent sorting and non-UTF-8 encodings. Compare the supported languages looking for missing or unused keys, inconsistent placeholders and truncated text. Try the interface with at least one locale different from the development one. Do not translate or modify files without an explicit request.

## Checks

Reproduce each finding with the language or format indicated and verify that text with accents, non-Latin characters and paths containing spaces displays correctly. Distinguish proven defects from proposals.

## Delivery

A report with the languages verified, findings by file and line, reproduction evidence and recommendations; changes only if requested.

## Related prompts

- INT02: Implement an interface following requirements and references.
- INT03: Verify accessibility and keyboard and assistive-technology use.
- TST05: Verify real behavior against the requirements.
