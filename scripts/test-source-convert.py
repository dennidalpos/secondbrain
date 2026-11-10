"""Semantic conversion regressions, with synthetic documents and no network access."""
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import sys
from unittest.mock import patch

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location("source_convert", Path(__file__).with_name("source-convert.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def pdf_bytes(text):
    stream = ("BT /F1 12 Tf 40 700 Td (" + text + ") Tj ET").encode("ascii") if text else b"10 10 40 40 re S"
    objects = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
               b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
               b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
               b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    result = b"%PDF-1.4\n"; offsets = [0]
    for number, obj in enumerate(objects, 1):
        offsets.append(len(result)); result += str(number).encode() + b" 0 obj\n" + obj + b"\nendobj\n"
    start = len(result)
    result += b"xref\n0 6\n0000000000 65535 f \n" + b"".join(f"{n:010d} 00000 n \n".encode() for n in offsets[1:])
    return result + b"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n" + str(start).encode() + b"\n%%EOF\n"


class ConversionTests(unittest.TestCase):
    def setUp(self):
        central = Path(__file__).resolve().parents[1] / ".runtime" / "tests" / "converter"
        central.mkdir(parents=True, exist_ok=True)
        self.root = Path(tempfile.mkdtemp(prefix="conversion-", dir=central))
        # Built-in local converters must not make outbound requests.
        self.network = patch("socket.socket.connect", side_effect=AssertionError("network forbidden during conversion"))
        self.network.start(); self.addCleanup(self.network.stop)

    def convert(self, data, fmt):
        path = self.root / ("input." + fmt); path.write_bytes(data)
        return module.convert(path, fmt)[0]

    def test_html_structure_numbers_and_table(self):
        text = self.convert(b"<h1>Articolo 1</h1><p>Importo 12.345,67 e codice 000123.</p><table><tr><th>Valore</th></tr><tr><td>0.00000000000000001</td></tr></table>", "html")
        for item in ("Articolo 1", "12.345,67", "000123", "0.00000000000000001"):
            self.assertIn(item, text)
        self.assertIn("|", text)

    def test_pdf_textual(self):
        text = self.convert(pdf_bytes("Articolo 1 - Importo 12345.67 - requisito 4.2"), "pdf")
        self.assertIn("12345.67", text); self.assertIn("4.2", text)

    def test_scanned_pdf_is_not_fabricated(self):
        text = self.convert(pdf_bytes(None), "pdf")
        self.assertLess(len(text.strip()), 20)

    def test_pdf_layout_preserves_page_and_numbers(self):
        path = self.root / "layout.pdf"
        path.write_bytes(pdf_bytes("Articolo 1 - Importo 12345.67 - requisito 4.2"))
        text, report = module.pdf_layout(path)
        self.assertIn("## Pagina 1", text)
        self.assertIn("12345.67", text)
        self.assertEqual(report["pageCount"], 1)

    def test_docx_paragraph_and_table(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr("[Content_Types].xml", '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
            archive.writestr("_rels/.rels", '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
            archive.writestr("word/document.xml", '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Articolo 2 - requisito 4.2 - importo 12.345,67</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>000123</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>')
        text = self.convert(data.getvalue(), "docx")
        self.assertIn("12.345,67", text); self.assertIn("000123", text)

    def test_json_precision_and_duplicate_lexemes(self):
        data = b'{"amount":12345678901234567890.00000001,"code":"000123"}'
        text = self.convert(data, "json")
        self.assertIn(data.decode(), text)

    def test_csv_precision_and_leading_zeroes(self):
        text = self.convert(b"code,amount\n000123,12345678901234567890.00000001\n", "csv")
        self.assertIn("000123", text); self.assertIn("12345678901234567890.00000001", text)

    def test_csv_inconsistent_columns(self):
        with self.assertRaises(ValueError):
            self.convert(b"a,b\n1,2,3\n", "csv")

    def test_old_word_format_requires_manual_conversion(self):
        with self.assertRaises(ValueError):
            self.convert(b"legacy-format", "doc")

    def test_cli_incomplete_and_no_overwrite(self):
        path = self.root / "input.txt"; path.write_text("short", encoding="utf-8")
        output = self.root / "out.md"; report = self.root / "report.json"
        args = ["source-convert", "--input", str(path), "--format", "text", "--output", str(output), "--report", str(report)]
        with patch("sys.argv", args):
            self.assertEqual(module.main(), 1)
        self.assertEqual(json.loads(report.read_text())["status"], "incomplete")
        with patch("sys.argv", args), self.assertRaises(FileExistsError):
            module.main()


if __name__ == "__main__":
    unittest.main()
