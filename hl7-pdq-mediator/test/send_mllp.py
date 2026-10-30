"""Cliente MLLP de prueba: envía uno o varios mensajes por la misma conexión
y muestra la respuesta.

Uso:
  python3 test/send_mllp.py HOST PORT archivo.hl7 [archivo2.hl7 ...]

Los archivos pueden tener los segmentos separados por saltos de línea normales;
el script los convierte a <CR> como exige HL7.
"""
import socket
import sys

VT, FS, CR = b"\x0b", b"\x1c", b"\x0d"


def frame(text: str) -> bytes:
    segs = [s.strip() for s in text.replace("\r\n", "\n").replace("\r", "\n").split("\n") if s.strip()]
    return VT + "\r".join(segs).encode("utf-8") + FS + CR


def read_frame(sock) -> str:
    data = b""
    while not data.endswith(FS + CR):
        chunk = sock.recv(4096)
        if not chunk:
            break
        data += chunk
    return data.strip(VT + FS + CR).decode("utf-8")


def main():
    host, port, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    with socket.create_connection((host, port), timeout=15) as s:
        for path in files:
            with open(path, encoding="utf-8") as f:
                s.sendall(frame(f.read()))
            print(f"===== {path} =====")
            print(read_frame(s).replace("\r", "\n"))
            print()


if __name__ == "__main__":
    main()
