#!/usr/bin/env python3
"""Run gh with its own login, or reuse this repository's GitHub credential helper.

Credentials stay in memory and are never printed, saved, or passed as arguments.
Usage: python3 Scripts/github_cli.py release list --repo akmumu/ttcalendar
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
gh = shutil.which("gh")
if not gh:
    sys.exit("Missing gh. Install with: HOMEBREW_NO_INSTALL_CLEANUP=1 brew install gh")

env = os.environ.copy()
if not (env.get("GH_TOKEN") or env.get("GITHUB_TOKEN")):
    logged_in = subprocess.run([gh, "auth", "status", "--hostname", "github.com"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if not logged_in:
        result = subprocess.run(
            ["git", "credential", "fill"], cwd=root,
            input="protocol=https\nhost=github.com\nusername=akmumu\n\n",
            text=True, capture_output=True, env={**env, "GIT_TERMINAL_PROMPT": "0"},
        )
        credential = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
        if result.returncode or not credential.get("password"):
            sys.exit("No usable GitHub login. Run: gh auth login --hostname github.com")
        env["GH_TOKEN"] = credential["password"]

sys.exit(subprocess.run([gh, *sys.argv[1:]], cwd=root, env=env).returncode)
