"""Offline, bounded conversion of acquired originals; extraction is never verification."""
import argparse
import csv
import hashlib
import importlib.metadata
import io
import json
from pathlib import Path
import re
import sys
import zipfile


def pdf_layout(path: Path, layout="single"):
    """Keep page boundaries and monospaced table positions alongside native text."""
    import pdfplumber
    pages = []
    image_only = []
    with pdfplumber.open(path) as document:
        for number, page in enumerate(document.pages, 1):
            if layout == "two-column":
                sections = [page.crop((0, 0, page.width / 2, page.height)),
                            page.crop((page.width / 2, 0, page.width, page.height))]
                text = "\n\n".join("### Colonna " + str(index) + "\n\n" + (section.extract_text(layout=True, x_tolerance=1) or "") for index, section in enumerate(sections, 1))
            else:
                text = page.extract_text(layout=True, x_tolerance=1) or ""
            image_area = sum(float(i.get("width", 0)) * float(i.get("height", 0)) for i in page.images)
            if len(re.sub(r"\W", "", text)) < 40 and image_area > page.width * page.height * 0.5:
                image_only.append(number)
            pages.append(f"## Pagina {number}\n\n````text\n{text.rstrip()}\n````\n")
    return "\n".join(pages), {"pageCount": len(pages), "imageOnlyPages": image_only}


def convert(path: Path, fmt: str):
    data = path.read_bytes()
    if len(data) > 50 * 1024 * 1024:
        raise ValueError("input-too-large")
    if fmt in ("text", "json", "csv"):
        text = data.decode("utf-8-sig", errors="strict")
        if fmt == "json":
            # Parse for validation, retain exact decimal lexemes in the original representation.
            json.loads(text, parse_float=str, parse_int=str)
            return "# Dataset JSON\n\nDati integrali nell'originale; valori riportati senza conversioni numeriche.\n\n```json\n" + text + "\n```\n", "stdlib"
        if fmt == "csv":
            rows = list(csv.reader(io.StringIO(text)))
            if not rows or any(len(row) != len(rows[0]) for row in rows):
                raise ValueError("csv-inconsistent-columns")
            escape = lambda cell: cell.replace("\\", "\\\\").replace("|", "\\|").replace("\n", "<br>")
            lines = ["| " + " | ".join(map(escape, row)) + " |" for row in rows]
            lines.insert(1, "| " + " | ".join(["---"] * len(rows[0])) + " |")
            return "# Dataset CSV\n\n" + "\n".join(lines) + "\n", "stdlib"
        return text, "stdlib"
    if fmt not in ("html", "pdf", "docx"):
        raise ValueError("format-requires-manual-conversion")
    if fmt == "docx":
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            entries = archive.infolist()
            if len(entries) > 10000 or sum(i.file_size for i in entries) > 100 * 1024 * 1024:
                raise ValueError("docx-expanded-size-limit")
            if any(i.filename.startswith(("/", "\\")) or ".." in i.filename.replace("\\", "/").split("/") for i in entries):
                raise ValueError("docx-unsafe-member-path")
    version = importlib.metadata.version("markitdown")
    if version != "0.1.9":
        raise ValueError("converter-version-mismatch")
    from markitdown import MarkItDown, StreamInfo
    converter = MarkItDown(enable_plugins=False)
    with io.BytesIO(data) as stream:
        result = converter.convert_stream(stream, stream_info=StreamInfo(extension="." + ("html" if fmt == "html" else fmt)))
    text = result.markdown if hasattr(result, "markdown") else result.text_content
    return text, "markitdown==" + version


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--format", required=True)
    parser.add_argument("--layout", choices=("single", "two-column"), default="single")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists() or args.report.exists():
        raise FileExistsError("Conversion outputs must be new")
    report = {"schemaVersion": 1, "status": "incomplete", "reason": None, "converter": None,
              "requiresReview": True, "sourceSha256": hashlib.sha256(args.input.read_bytes()).hexdigest().upper()}
    try:
        text, engine = convert(args.input, args.format)
        report["converter"] = engine
        if args.format == "pdf":
            # MarkItDown extracts semantic text; the local layout pass preserves tables
            # and page references instead of silently flattening their relationships.
            semantic_characters = len(text)
            text, pdf_report = pdf_layout(args.input, args.layout)
            report.update(pdf_report)
            report["semanticCharacters"] = semantic_characters
            report["converter"] += "; pdfplumber-layout==" + importlib.metadata.version("pdfplumber")
        report["characters"] = len(text)
        report["numericTokens"] = len(re.findall(r"\d+(?:[.,]\d+)*", text))
        if (args.format == "pdf" and (report["semanticCharacters"] < 20 or report["imageOnlyPages"])) or len(re.sub(r"\W", "", text)) < 20 or "\ufffd" in text:
            report["reason"] = "scanned-empty-or-incomplete"
        else:
            report["status"] = "extracted"
        if text.strip():
            with args.output.open("x", encoding="utf-8", newline="\n") as output:
                output.write(text.replace("\r\n", "\n").rstrip() + "\n")
    except Exception as error:
        report["reason"] = type(error).__name__ + ": " + str(error)[:160]
    with args.report.open("x", encoding="utf-8", newline="\n") as output:
        json.dump(report, output, ensure_ascii=False, indent=2)
        output.write("\n")
    return 0 if report["status"] == "extracted" else 1


if __name__ == "__main__":
    sys.exit(main())
