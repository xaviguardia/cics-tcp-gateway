#!/usr/bin/env python3
"""Small SSE web console for independent CICS TCP gateway sessions."""

from __future__ import annotations

import argparse
import json
import queue
import socket
import struct
import sys
import threading
import time
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8088
DEFAULT_BACKEND = "127.0.0.1:4321"
MAX_COMMAREA = 4096
MAX_SESSIONS = 128
HEADER_LEN = 12
RESPONSE_HEADER_LEN = 8
SOCKET_TIMEOUT = 60.0


HTML = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CICS Gateway Sessions</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #101214;
      --panel: #191d21;
      --panel-2: #20262b;
      --line: #303840;
      --text: #eef2f4;
      --muted: #9ba7b1;
      --ok: #69d391;
      --warn: #f2c46d;
      --bad: #f07878;
      --accent: #65b7ff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 14px;
      line-height: 1.4;
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 18px 22px;
      border-bottom: 1px solid var(--line);
      background: #14181c;
    }
    h1 { margin: 0; font-size: 19px; font-weight: 650; letter-spacing: 0; }
    main { display: grid; grid-template-columns: 360px 1fr; min-height: calc(100vh - 65px); }
    form {
      padding: 18px;
      border-right: 1px solid var(--line);
      background: var(--panel);
    }
    label { display: block; margin: 0 0 14px; color: var(--muted); font-size: 12px; font-weight: 650; }
    input, textarea {
      width: 100%;
      margin-top: 6px;
      padding: 9px 10px;
      color: var(--text);
      background: #0f1215;
      border: 1px solid var(--line);
      border-radius: 6px;
      font: 13px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      outline: none;
    }
    input:focus, textarea:focus { border-color: var(--accent); }
    textarea { min-height: 78px; resize: vertical; }
    .row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .buttons { display: flex; gap: 10px; margin-top: 14px; }
    button {
      border: 1px solid var(--line);
      background: var(--panel-2);
      color: var(--text);
      border-radius: 6px;
      padding: 9px 12px;
      font-weight: 650;
      cursor: pointer;
    }
    button.primary { background: var(--accent); border-color: var(--accent); color: #071018; }
    button:hover { filter: brightness(1.08); }
    .status {
      display: flex;
      gap: 10px;
      align-items: center;
      color: var(--muted);
      font: 12px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--warn); }
    .dot.live { background: var(--ok); }
    .content { display: grid; grid-template-rows: auto 1fr; min-width: 0; }
    .summary {
      display: grid;
      grid-template-columns: repeat(4, minmax(120px, 1fr));
      gap: 1px;
      background: var(--line);
      border-bottom: 1px solid var(--line);
    }
    .metric { background: var(--panel); padding: 14px 16px; }
    .metric b { display: block; font-size: 22px; line-height: 1.1; }
    .metric span { color: var(--muted); font-size: 12px; }
    .logs { overflow: auto; padding: 14px; }
    .event {
      display: grid;
      grid-template-columns: 90px 90px 70px 1fr;
      gap: 12px;
      align-items: start;
      padding: 9px 10px;
      border-bottom: 1px solid rgba(255,255,255,0.06);
      font: 12px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }
    .event .kind { color: var(--accent); }
    .event .err { color: var(--bad); }
    .event .ok { color: var(--ok); }
    .payload { white-space: pre-wrap; word-break: break-word; color: #d8dee4; }
    @media (max-width: 860px) {
      main { grid-template-columns: 1fr; }
      form { border-right: 0; border-bottom: 1px solid var(--line); }
      .summary { grid-template-columns: repeat(2, 1fr); }
      .event { grid-template-columns: 70px 70px 1fr; }
      .event .backend { display: none; }
    }
  </style>
</head>
<body>
  <header>
    <h1>CICS Gateway Sessions</h1>
    <div class="status"><span id="dot" class="dot"></span><span id="sse">SSE connecting</span></div>
  </header>
  <main>
    <form id="controls">
      <div class="row">
        <label>Sessions
          <input name="count" type="number" min="1" max="128" value="4">
        </label>
        <label>Interval ms
          <input name="intervalMs" type="number" min="100" max="60000" value="1000">
        </label>
      </div>
      <label>Program
        <input name="program" value="GWDEMO" maxlength="8">
      </label>
      <label>Commarea hex
        <textarea name="commareaHex" spellcheck="false">00000000</textarea>
      </label>
      <label>Backends
        <textarea name="backends" spellcheck="false">127.0.0.1:4321</textarea>
      </label>
      <div class="buttons">
        <button class="primary" type="submit">Start</button>
        <button id="stop" type="button">Stop</button>
        <button id="clear" type="button">Clear</button>
      </div>
    </form>
    <section class="content">
      <div class="summary">
        <div class="metric"><b id="m-running">0</b><span>running</span></div>
        <div class="metric"><b id="m-responses">0</b><span>responses</span></div>
        <div class="metric"><b id="m-errors">0</b><span>errors</span></div>
        <div class="metric"><b id="m-active">0</b><span>active sockets</span></div>
      </div>
      <div id="logs" class="logs"></div>
    </section>
  </main>
  <script>
    const logs = document.getElementById('logs');
    const metrics = { running: 0, responses: 0, errors: 0, active: 0 };
    const active = new Set();

    function setMetric(id, value) {
      document.getElementById(id).textContent = String(value);
    }

    function refreshMetrics() {
      setMetric('m-running', metrics.running);
      setMetric('m-responses', metrics.responses);
      setMetric('m-errors', metrics.errors);
      setMetric('m-active', active.size);
    }

    function addEvent(item) {
      if (item.type === 'response') metrics.responses += 1;
      if (item.type === 'error') metrics.errors += 1;
      if (item.type === 'connected') active.add(item.session);
      if (item.type === 'stopped') active.delete(item.session);
      refreshMetrics();

      const row = document.createElement('div');
      row.className = 'event';
      const cls = item.type === 'error' ? 'err' : item.type === 'response' ? 'ok' : 'kind';
      row.innerHTML = `
        <div>${item.time || ''}</div>
        <div>${item.session || '-'}</div>
        <div class="backend">${item.backend || '-'}</div>
        <div class="payload"><span class="${cls}">${item.type}</span> ${formatMessage(item)}</div>`;
      logs.appendChild(row);
      logs.scrollTop = logs.scrollHeight;
      while (logs.children.length > 1000) logs.removeChild(logs.firstChild);
    }

    function formatMessage(item) {
      if (item.type === 'response') {
        return `seq=${item.seq} rc=${item.rc} len=${item.length} hex=${item.payloadHex} text=${JSON.stringify(item.payloadText)}`;
      }
      return item.message || '';
    }

    function parseBackends(value) {
      return value.split(/[\n,]+/).map(v => v.trim()).filter(Boolean);
    }

    document.getElementById('controls').addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const form = new FormData(ev.currentTarget);
      const body = {
        count: Number(form.get('count')),
        intervalMs: Number(form.get('intervalMs')),
        program: String(form.get('program')),
        commareaHex: String(form.get('commareaHex')).replace(/\s+/g, ''),
        backends: parseBackends(String(form.get('backends'))),
      };
      const res = await fetch('/api/start', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) addEvent({ type: 'error', message: data.error || 'start failed' });
      metrics.running = data.running || 0;
      metrics.responses = 0;
      metrics.errors = 0;
      active.clear();
      refreshMetrics();
    });

    document.getElementById('stop').addEventListener('click', async () => {
      const res = await fetch('/api/stop', { method: 'POST' });
      const data = await res.json();
      metrics.running = data.running || 0;
      active.clear();
      refreshMetrics();
    });

    document.getElementById('clear').addEventListener('click', () => {
      logs.replaceChildren();
      metrics.responses = 0;
      metrics.errors = 0;
      refreshMetrics();
    });

    const evs = new EventSource('/events');
    evs.onopen = () => {
      document.getElementById('dot').classList.add('live');
      document.getElementById('sse').textContent = 'SSE live';
    };
    evs.onerror = () => {
      document.getElementById('dot').classList.remove('live');
      document.getElementById('sse').textContent = 'SSE reconnecting';
    };
    evs.addEventListener('message', (ev) => {
      const item = JSON.parse(ev.data);
      if (item.type === 'status') {
        metrics.running = item.running || 0;
        refreshMetrics();
      } else {
        addEvent(item);
      }
    });
  </script>
</body>
</html>
"""


@dataclass(frozen=True)
class Backend:
    host: str
    port: int

    @property
    def label(self) -> str:
        return f"{self.host}:{self.port}"


class EventBroker:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._subscribers: list[queue.Queue[dict[str, Any]]] = []

    def subscribe(self) -> queue.Queue[dict[str, Any]]:
        q: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=1000)
        with self._lock:
            self._subscribers.append(q)
        return q

    def unsubscribe(self, q: queue.Queue[dict[str, Any]]) -> None:
        with self._lock:
            if q in self._subscribers:
                self._subscribers.remove(q)

    def publish(self, item: dict[str, Any]) -> None:
        item.setdefault("time", time.strftime("%H:%M:%S"))
        with self._lock:
            subscribers = list(self._subscribers)
        for q in subscribers:
            try:
                q.put_nowait(item)
            except queue.Full:
                pass


class CicsSession(threading.Thread):
    def __init__(
        self,
        session_id: str,
        backend: Backend,
        program: str,
        commarea: bytes,
        interval_ms: int,
        broker: EventBroker,
    ) -> None:
        super().__init__(name=f"cics-session-{session_id}", daemon=True)
        self.session_id = session_id
        self.backend = backend
        self.program = program
        self.commarea = commarea
        self.interval = interval_ms / 1000.0
        self.broker = broker
        self.stop_event = threading.Event()
        self._sock_lock = threading.Lock()
        self._sock: socket.socket | None = None
        self.seq = 0

    def stop(self) -> None:
        self.stop_event.set()
        with self._sock_lock:
            sock = self._sock
            self._sock = None
        if sock is not None:
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                sock.close()
            except OSError:
                pass

    def emit(self, item: dict[str, Any]) -> None:
        item.setdefault("session", self.session_id)
        item.setdefault("backend", self.backend.label)
        self.broker.publish(item)

    def run(self) -> None:
        try:
            while not self.stop_event.is_set():
                try:
                    self._run_connected()
                except Exception as exc:  # noqa: BLE001 - emit and retry loop
                    if not self.stop_event.is_set():
                        self.emit({"type": "error", "message": str(exc)})
                        self._close_socket()
                        self.stop_event.wait(min(max(self.interval, 0.5), 3.0))
        finally:
            self._close_socket()
            self.emit({"type": "stopped", "message": "session stopped"})

    def _run_connected(self) -> None:
        sock = socket.create_connection((self.backend.host, self.backend.port), timeout=5.0)
        sock.settimeout(SOCKET_TIMEOUT)
        with self._sock_lock:
            self._sock = sock
        self.emit({"type": "connected", "message": "socket connected"})

        while not self.stop_event.is_set():
            self.seq += 1
            sock.sendall(build_request(self.program, self.commarea))
            header = read_exact(sock, RESPONSE_HEADER_LEN)
            rc, length = struct.unpack(">II", header)
            if length > MAX_COMMAREA:
                raise ValueError(f"bad response length {length}")
            payload = read_exact(sock, length)
            self.emit(
                {
                    "type": "response",
                    "seq": self.seq,
                    "rc": rc,
                    "length": length,
                    "payloadHex": payload.hex(),
                    "payloadText": decode_ebcdic(payload),
                }
            )
            self.stop_event.wait(self.interval)

    def _close_socket(self) -> None:
        with self._sock_lock:
            sock = self._sock
            self._sock = None
        if sock is not None:
            try:
                sock.close()
            except OSError:
                pass


class SessionManager:
    def __init__(self, broker: EventBroker, default_backends: list[Backend]) -> None:
        self.broker = broker
        self.default_backends = default_backends
        self._lock = threading.Lock()
        self._sessions: list[CicsSession] = []

    def start(
        self,
        count: int,
        program: str,
        commarea: bytes,
        interval_ms: int,
        backends: list[Backend] | None = None,
    ) -> dict[str, Any]:
        if count < 1 or count > MAX_SESSIONS:
            raise ValueError(f"count must be between 1 and {MAX_SESSIONS}")
        if interval_ms < 100 or interval_ms > 60000:
            raise ValueError("intervalMs must be between 100 and 60000")
        if len(commarea) > MAX_COMMAREA:
            raise ValueError(f"commarea must be <= {MAX_COMMAREA} bytes")

        selected_backends = backends or self.default_backends
        if not selected_backends:
            raise ValueError("at least one backend is required")

        self.stop()
        sessions: list[CicsSession] = []
        for index in range(count):
            backend = selected_backends[index % len(selected_backends)]
            session = CicsSession(
                session_id=f"S{index + 1:03d}",
                backend=backend,
                program=program,
                commarea=commarea,
                interval_ms=interval_ms,
                broker=self.broker,
            )
            sessions.append(session)

        with self._lock:
            self._sessions = sessions
        for session in sessions:
            session.start()
        self.broker.publish({"type": "status", "running": len(sessions)})
        return {"running": len(sessions)}

    def stop(self) -> dict[str, Any]:
        with self._lock:
            sessions = self._sessions
            self._sessions = []
        for session in sessions:
            session.stop()
        self.broker.publish({"type": "status", "running": 0})
        return {"running": 0}

    def status(self) -> dict[str, Any]:
        with self._lock:
            running = sum(1 for session in self._sessions if session.is_alive())
        return {"running": running}


def encode_program(program: str) -> bytes:
    value = program.strip().upper()
    if not value:
        raise ValueError("program is required")
    return value[:8].ljust(8).encode("cp037")


def decode_ebcdic(data: bytes) -> str:
    return data.decode("cp037", errors="replace")


def build_request(program: str, commarea: bytes) -> bytes:
    return encode_program(program) + struct.pack(">I", len(commarea)) + commarea


def read_exact(sock: socket.socket, length: int) -> bytes:
    chunks: list[bytes] = []
    remaining = length
    while remaining:
        chunk = sock.recv(remaining)
        if not chunk:
            raise ConnectionError("socket closed")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def parse_backend(value: str) -> Backend:
    host, sep, port_text = value.strip().rpartition(":")
    if not sep:
        host = "127.0.0.1"
        port_text = value.strip()
    port = int(port_text)
    if not host or port < 1 or port > 65535:
        raise ValueError(f"invalid backend {value!r}")
    return Backend(host=host, port=port)


def parse_backends(values: list[str]) -> list[Backend]:
    result: list[Backend] = []
    for value in values:
        for item in value.replace("\n", ",").split(","):
            item = item.strip()
            if item:
                result.append(parse_backend(item))
    return result


def parse_commarea_hex(value: str) -> bytes:
    cleaned = "".join(value.split())
    if len(cleaned) % 2:
        raise ValueError("commareaHex must contain an even number of hex digits")
    try:
        return bytes.fromhex(cleaned)
    except ValueError as exc:
        raise ValueError("commareaHex is not valid hex") from exc


class CicsWebHandler(BaseHTTPRequestHandler):
    manager: SessionManager
    broker: EventBroker

    server_version = "CicsWebSessions/1.0"

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-methods", "GET,POST,OPTIONS")
        self.send_header("access-control-allow-headers", "content-type")
        self.end_headers()

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/":
            self._send_html(HTML)
        elif path == "/events":
            self._send_events()
        elif path == "/api/status":
            self._send_json(self.manager.status())
        else:
            self.send_error(404)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/start":
            self._start_sessions()
        elif path == "/api/stop":
            self._send_json(self.manager.stop())
        else:
            self.send_error(404)

    def _start_sessions(self) -> None:
        try:
            body = self._read_json()
            backends = parse_backends(body.get("backends", []))
            result = self.manager.start(
                count=int(body.get("count", 1)),
                program=str(body.get("program", "KLASTCCG")),
                commarea=parse_commarea_hex(str(body.get("commareaHex", "00000000"))),
                interval_ms=int(body.get("intervalMs", 1000)),
                backends=backends or None,
            )
            self._send_json(result)
        except Exception as exc:  # noqa: BLE001 - JSON API error path
            self._send_json({"error": str(exc)}, status=400)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("content-length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8"))

    def _send_html(self, html: str) -> None:
        data = html.encode("utf-8")
        self.send_response(200)
        self.send_header("content-type", "text/html; charset=utf-8")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_json(self, payload: dict[str, Any], status: int = 200) -> None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("access-control-allow-origin", "*")
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_events(self) -> None:
        subscriber = self.broker.subscribe()
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("cache-control", "no-cache")
        self.send_header("connection", "keep-alive")
        self.send_header("x-accel-buffering", "no")
        self.end_headers()
        try:
            self._write_sse({"type": "status", **self.manager.status()})
            while True:
                try:
                    item = subscriber.get(timeout=15)
                    self._write_sse(item)
                except queue.Empty:
                    self.wfile.write(b": ping\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            self.broker.unsubscribe(subscriber)

    def _write_sse(self, item: dict[str, Any]) -> None:
        data = json.dumps(item, separators=(",", ":")).encode("utf-8")
        self.wfile.write(b"event: message\n")
        self.wfile.write(b"data: " + data + b"\n\n")
        self.wfile.flush()

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"{self.address_string()} - {fmt % args}")


class CicsThreadingHTTPServer(ThreadingHTTPServer):
    def handle_error(self, request: Any, client_address: Any) -> None:
        exc = sys.exc_info()[1]
        if isinstance(exc, (BrokenPipeError, ConnectionResetError, OSError)):
            return
        super().handle_error(request, client_address)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument(
        "--backend",
        action="append",
        default=[],
        help="CICS backend host:port. Can be repeated.",
    )
    parser.add_argument("--backends", default="")
    args = parser.parse_args()

    backend_values = list(args.backend)
    if args.backends:
        backend_values.append(args.backends)
    if not backend_values:
        backend_values = [DEFAULT_BACKEND]

    broker = EventBroker()
    manager = SessionManager(broker, parse_backends(backend_values))
    CicsWebHandler.broker = broker
    CicsWebHandler.manager = manager

    server = CicsThreadingHTTPServer((args.host, args.port), CicsWebHandler)
    print(f"CICS web sessions on http://{args.host}:{args.port}/")
    print("Backends: " + ", ".join(backend.label for backend in manager.default_backends))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        manager.stop()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
