"""Bounded, disposable OpenCode/Qwen compatibility trial; run inside WSL."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
trial = root / "tmp" / "engine-trial"
trial.mkdir(exist_ok=True)
fixture = trial / "fixture"
fixture.mkdir(exist_ok=True)
(fixture / "greeting.rb").write_text('def greeting(name)\n  "Hello, #{name.strip}!"\nend\n')
(fixture / "test_greeting.rb").write_text('require_relative "greeting"\nraise "nil not supported" unless greeting(nil) == "Hello, friend!"\nraise "name broken" unless greeting(" Val ") == "Hello, Val!"\nputs "2 checks passed"\n')
gateway = subprocess.check_output(["ip", "route", "show", "default"], text=True).split()[2]
config = {
    "$schema": "https://opencode.ai/config.json",
    "enabled_providers": ["local"], "autoupdate": False,
    "provider": {"local": {"npm": "@ai-sdk/openai-compatible", "name": "LM Studio trial",
        "options": {"baseURL": f"http://{gateway}:1234/v1"},
        "models": {"qwen/qwen3.5-9b": {"name": "Qwen local", "tool_call": True,
            "limit": {"context": 16640, "output": 2048}}}}},
    "agent": {"probe": {"mode": "primary", "steps": 8,
        "prompt": "You are a concise coding agent in a disposable Ruby fixture. Read files, fix the bug, run the test, report observed results. Do not delegate or inspect other directories.",
        "tools": {"*": False, "read": True, "edit": True, "write": True, "bash": True},
        "permission": {"*": "deny", "read": "allow", "edit": "allow", "bash": {"*": "deny", "ruby test_greeting.rb": "allow"}}}}
}
config_path = trial / "opencode.json"
config_path.write_text(json.dumps(config))
environment = os.environ.copy()
environment.update({"OPENCODE_CONFIG": str(config_path), "OPENCODE_DISABLE_MODELS_FETCH": "true",
    "XDG_DATA_HOME": str(trial / "data"), "XDG_CONFIG_HOME": str(trial / "config"),
    "XDG_CACHE_HOME": str(trial / "cache"),
    "PATH": str(Path.home() / ".rbenv/shims") + ":" + environment["PATH"]})
command = [str(root / "tmp/opencode-probe/package/bin/opencode"), "run", "--pure", "--dir", str(fixture),
    "--agent", "probe", "--model", "local/qwen/qwen3.5-9b", "--format", "json",
    "Read greeting.rb and test_greeting.rb. Fix greeting(nil) to return Hello, friend! while preserving normal names. Run ruby test_greeting.rb. Report the observed result."]
with (trial / "events.jsonl").open("w") as output, (trial / "stderr.log").open("w") as errors:
    try:
        result = subprocess.run(command, env=environment, stdout=output, stderr=errors, timeout=360)
        print(f"Engine exit: {result.returncode}", flush=True)
    except subprocess.TimeoutExpired:
        print("Engine timed out after 360 seconds", flush=True)
check = subprocess.run([str(Path.home() / ".rbenv/shims/ruby"), "test_greeting.rb"], cwd=fixture, text=True, capture_output=True)
print(f"Independent test exit: {check.returncode}\n{check.stdout}{check.stderr}", flush=True)
print(f"Artifacts: {trial}", flush=True)
