"""Probe OpenCode's HTTP contract using local Qwen and a disposable Git fixture."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

root = Path(__file__).resolve().parent.parent
trial = root / "tmp/engine-trial"
fixture = Path(tempfile.mkdtemp(prefix="api-fixture-", dir=trial))
(fixture / "greeting.rb").write_text('def greeting(name)\n  "Hello, #{name.strip}!"\nend\n')
(fixture / "test_greeting.rb").write_text('require_relative "greeting"\nraise "nil broken" unless greeting(nil) == "Hello, friend!"\nraise "name broken" unless greeting(" Val ") == "Hello, Val!"\nputs "2 checks passed"\n')
for command in (["git", "init", "-q"], ["git", "add", "."], ["git", "-c", "user.name=Harness trial", "-c", "user.email=trial@localhost", "commit", "-qm", "Trial baseline"]):
    subprocess.run(command, cwd=fixture, check=True, capture_output=True)
environment = os.environ.copy()
environment.update({"OPENCODE_CONFIG": str(trial / "opencode.json"), "OPENCODE_DISABLE_MODELS_FETCH": "true",
    "XDG_DATA_HOME": str(trial / "api-data"), "XDG_CONFIG_HOME": str(trial / "config"),
    "XDG_CACHE_HOME": str(trial / "cache"), "PATH": str(Path.home() / ".rbenv/shims") + ":" + environment["PATH"]})
base = "http://127.0.0.1:4097"

def request(path, body=None, method=None, timeout=180):
    req = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(),
        method=method, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        text = response.read().decode()
        return json.loads(text) if text else None

report = {"fixture": str(fixture)}
with (trial / "api-server.log").open("w") as log:
    process = subprocess.Popen([str(root / "tmp/opencode-probe/package/bin/opencode"), "serve", "--hostname", "127.0.0.1", "--port", "4097"], cwd=fixture, env=environment, stdout=log, stderr=log, start_new_session=True)
    try:
        for attempt in range(60):
            if process.poll() is not None:
                raise RuntimeError("Trial server exited; inspect api-server.log")
            try:
                report["health"] = request("/global/health", timeout=1)
                break
            except (OSError, urllib.error.URLError):
                time.sleep(0.5)
        else:
            raise RuntimeError("Trial server did not become ready")
        print("Health verified", flush=True)
        session = request("/session", {"title": "Local Qwen API acceptance trial"})
        report["session_id"] = session["id"]
        before = time.monotonic()
        answer = request(f'/session/{session["id"]}/message', {
            "model": {"providerID": "local", "modelID": "qwen/qwen3.5-9b"}, "agent": "probe",
            "parts": [{"type": "text", "text": "Read greeting.rb and test_greeting.rb. Fix nil to return Hello, friend! Preserve normal names. Run ruby test_greeting.rb and report observed results."}]})
        report["coding_seconds"] = round(time.monotonic() - before, 2)
        (trial / "api-answer.json").write_text(json.dumps(answer, indent=2))
        report["diff"] = request(f'/session/{session["id"]}/diff')
        git_diff = subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=fixture, text=True)
        (trial / "independent.patch").write_text(git_diff)
        report["independent_git_diff_bytes"] = len(git_diff.encode())
        report["messages_count"] = len(request(f'/session/{session["id"]}/message'))
        check = subprocess.run([str(Path.home() / ".rbenv/shims/ruby"), "test_greeting.rb"], cwd=fixture, text=True, capture_output=True)
        report["independent_check"] = {"exit": check.returncode, "stdout": check.stdout, "stderr": check.stderr}
        print("Coding request and independent checks finished", flush=True)
        cancelled = request("/session", {"title": "Cancellation probe"})
        request(f'/session/{cancelled["id"]}/prompt_async', {"model": {"providerID": "local", "modelID": "qwen/qwen3.5-9b"}, "agent": "probe", "parts": [{"type": "text", "text": "Explain Ruby method dispatch in great detail."}]})
        time.sleep(1)
        report["status_before_abort"] = request("/session/status")
        report["abort"] = request(f'/session/{cancelled["id"]}/abort', {}, "POST")
        time.sleep(1)
        report["status_after_abort"] = request("/session/status")
        with urllib.request.urlopen(base + "/event", timeout=5) as events:
            report["first_sse_line"] = events.readline().decode().strip()
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=10)
        (trial / "api-report.json").write_text(json.dumps(report, indent=2))
        print(json.dumps(report, indent=2), flush=True)
