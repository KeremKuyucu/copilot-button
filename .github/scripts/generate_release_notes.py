#!/usr/bin/env python3
"""
Copilot Button - GitHub Actions Release Notes Generator
Generates .github/releases/RELEASE_<version>.md using Google Gemini API and template.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

PROJECT_ROOT = Path(__file__).resolve().parents[2]

def get_current_version() -> str:
    if os.environ.get("APP_VERSION"):
        return os.environ["APP_VERSION"].lstrip("v").strip()

    rc_file = PROJECT_ROOT / "resources" / "app.rc"
    if rc_file.exists():
        content = rc_file.read_text(encoding="utf-8", errors="ignore")
        match = re.search(r'VALUE\s+"ProductVersion",\s*"([^"\\\r\n]+)', content)
        if match:
            return match.group(1).strip().rstrip("\0")

    try:
        tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip().lstrip("v")
        if tag:
            return tag
    except Exception:
        pass

    return "2.1.0"

def get_git_context() -> tuple[str, str, str]:
    """Returns (last_tag, commit_log, diff_stat)"""
    last_tag = ""
    try:
        head_tags = subprocess.check_output(
            ["git", "tag", "--points-at", "HEAD"],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip().splitlines()

        if head_tags:
            last_tag = subprocess.check_output(
                ["git", "describe", "--tags", "--abbrev=0", "HEAD~1"],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL,
                text=True
            ).strip()
        else:
            last_tag = subprocess.check_output(
                ["git", "describe", "--tags", "--abbrev=0"],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL,
                text=True
            ).strip()
    except Exception:
        try:
            tags = subprocess.check_output(
                ["git", "tag", "--sort=-v:refname"],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL,
                text=True
            ).strip().splitlines()
            if len(tags) > 1:
                last_tag = tags[1]
            elif len(tags) == 1:
                last_tag = tags[0]
        except Exception:
            last_tag = ""

    if last_tag:
        rev_range = f"{last_tag}..HEAD"
        print(f"[*] Last tag detected: {last_tag}")
    else:
        rev_range = "HEAD~15..HEAD"
        print("[*] No previous tag detected; inspecting recent commits")

    try:
        commit_log = subprocess.check_output(
            ["git", "log", rev_range, "--oneline", "--no-merges"],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()
    except Exception:
        commit_log = subprocess.check_output(
            ["git", "log", "-n", "10", "--oneline", "--no-merges"],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()

    diff_stat = ""
    try:
        diff_stat = subprocess.check_output(
            ["git", "diff", "--stat", rev_range],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()
    except Exception:
        pass

    if not commit_log:
        commit_log = "Maintenance, optimizations, and general improvements."

    return last_tag, commit_log, diff_stat

def load_template() -> str:
    tpl_file = PROJECT_ROOT / ".github" / "RELEASE_TEMPLATE.md"
    if tpl_file.exists():
        return tpl_file.read_text(encoding="utf-8").strip()
    return ""

def generate_with_gemini(api_key: str, version: str, last_tag: str, commit_log: str, diff_stat: str, template: str) -> str:
    print(f"[*] Requesting release notes from Gemini API for v{version}...")

    template_instruction = ""
    if template:
        template_instruction = f"""
STRICT TEMPLATE FORMAT TO FOLLOW:
\"\"\"
{template}
\"\"\"
Fill in {{version}} with "{version}" and {{title}} with a short, punchy release title in English.
Follow the sections from the template. Only include sections that have relevant changes.
"""

    prompt = f"""You are a professional release manager and copywriter for "Copilot Button", an open-source, ultra-lightweight native C++20 Windows utility that remaps the physical Windows Copilot key to mic mute, media controls, Spotify tracking, and custom actions with an instant OSD.

Generate clean, concise release notes in English based on the following git commits and changes for version {version}:

GIT COMMITS (since {last_tag or 'previous release'}):
{commit_log}

DIFF STAT SUMMARY:
{diff_stat or 'N/A'}
{template_instruction}
REQUIREMENTS:
- Use bullet points with bold prefixes (e.g., `- **[Component/Feature]**: [Description]`).
- Professional, developer-friendly, and concise tone.
- Do NOT include markdown code fences (```) around the JSON output.

OUTPUT FORMAT:
Respond ONLY with a valid JSON object with a single key "release_notes":
{{
  "release_notes": "markdown content here"
}}
"""

    models = [
        "gemini-3.5-flash-lite",  # 500 RPD, 15 RPM
        "gemini-3.1-flash-lite",  # 500 RPD, 15 RPM
        "gemini-3.5-flash",       # 20 RPD, 5 RPM
        "gemini-2.5-flash",       # 20 RPD, 5 RPM
        "gemini-flash-lite-latest"
    ]
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json"
        }
    }

    last_error = None
    for model in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                resp_json = json.loads(resp.read().decode("utf-8"))
                text_content = resp_json["candidates"][0]["content"]["parts"][0]["text"]
                data = json.loads(text_content)
                return data["release_notes"].strip()
        except Exception as e:
            last_error = e
            print(f"[!] Model {model} request failed: {e}. Trying fallback...")

    raise RuntimeError(f"Gemini API request failed on all models: {last_error}")

def main():
    parser = argparse.ArgumentParser(description="Copilot Button Release Notes Generator")
    parser.add_argument("--version", "-v", help="Release version (e.g. 2.1.0)")
    parser.add_argument("--engine", "-e", default="gemini", help="Generator engine (kept for workflow compatibility)")
    parser.add_argument("--api-key", "-k", help="Gemini API Key (optional, defaults to GEMINI_API_KEY env)")
    args = parser.parse_args()

    api_key = (args.api_key or os.environ.get("GEMINI_API_KEY", "")).strip()
    if not api_key:
        print("[!] Warning: No GEMINI_API_KEY found. Skipping release notes generation.")
        sys.exit(0)

    version = args.version or get_current_version()
    print(f"=== Copilot Button Release Notes Generator (v{version}) ===")

    last_tag, commit_log, diff_stat = get_git_context()
    print(f"[*] Commits to summarize:\n{commit_log}\n")
    if diff_stat:
        print(f"[*] Diff stat summary:\n{diff_stat}\n")

    template = load_template()
    if template:
        print("[*] Loaded release notes template from .github/RELEASE_TEMPLATE.md")

    release_notes = generate_with_gemini(api_key, version, last_tag, commit_log, diff_stat, template)

    releases_dir = PROJECT_ROOT / ".github" / "releases"
    releases_dir.mkdir(parents=True, exist_ok=True)
    target_file = releases_dir / f"RELEASE_{version}.md"

    target_file.write_text(release_notes, encoding="utf-8")
    print(f"\n[+] Successfully saved release notes: {target_file.relative_to(PROJECT_ROOT)}")

if __name__ == "__main__":
    main()
