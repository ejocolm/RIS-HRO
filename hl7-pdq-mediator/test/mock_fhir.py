"""Facade FHIR simulado para pruebas locales.

Responde GET /fhir/Patient?identifier=system|value usando test/patient-837871.json.
Uso:  python3 test/mock_fhir.py 8099
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PATIENT = json.loads((Path(__file__).parent.parent / "src" / "test" / "resources" / "patient-837871.json").read_text(encoding="utf-8"))


def matches(patient, token):
    system, _, value = token.partition("|")
    for ident in patient.get("identifier", []):
        if ident.get("value") == value and (not system or ident.get("system") == system):
            return True
    return False


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path != "/fhir/Patient":
            self.send_error(404)
            return
        token = parse_qs(url.query).get("identifier", [""])[0]
        if token.endswith("|500"):  # para probar errores del facade
            self.send_error(500)
            return
        entries = [{"resource": PATIENT}] if matches(PATIENT, token) else []
        body = json.dumps({"resourceType": "Bundle", "type": "searchset",
                           "total": len(entries), "entry": entries}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/fhir+json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        sys.stderr.write("[mock-fhir] " + (fmt % args) + "\n")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
