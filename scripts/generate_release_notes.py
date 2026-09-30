#!/usr/bin/env python3
"""
Copilot Button Release Notes Generator
Generates .github/releases/RELEASE_<version>.md
using either Google Gemini API or Antigravity CLI (agy).
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

PROJECT_ROOT = Path(__file__).resolve().parent.parent

def get_current_version() -> str:
    globals_file = PROJECT_ROOT / "lib" / "Globals.ahk"
    if not globals_file.exists():
        globals_file = PROJECT_ROOT / "copilot-buton.ahk"
    if not globals_file.exists():
        raise FileNotFoundError(f"Globals.ahk not found at {globals_file}")

    content = globals_file.read_text(encoding="utf-8", errors="ignore")
    match = re.search(r'(?:global\s+)?APP_VERSION\s*:=\s*["\']([^"\']+)["\']', content)
    if not match:
        raise ValueError("Could not extract APP_VERSION from Globals.ahk")
    return match.group(1).strip()

def get_git_context() -> tuple[str, str]:
    """Returns (last_tag, commit_log)"""
    try:
        last_tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()
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

    if not commit_log:
        commit_log = "Maintenance and general improvements."

    return last_tag, commit_log

def find_gemini_api_key(explicit_key: str = None) -> str:
    if explicit_key:
        return explicit_key.strip()
    if os.environ.get("GEMINI_API_KEY"):
        return os.environ["GEMINI_API_KEY"].strip()

    # Check local key files if any
    key_file = Path("C:/Users/kerem/Projects/imza-bilgileri/gemini.key")
    if key_file.exists():
        key = key_file.read_text(encoding="utf-8").strip()
        if key:
            return key

    return ""

def generate_with_gemini(api_key: str, version: str, last_tag: str, commit_log: str) -> str:
    print(f"[*] Requesting release notes from Gemini API for v{version}...")

    prompt = f"""You are a professional release manager and copywriter for an open-source Windows utility called "Copilot Button" (a lightweight AutoHotkey v2 utility that remaps the Windows Copilot key to media control, mic mute, YouTube Music, Spotify, custom apps, and OSD actions).

Generate a clean, structured release notes document in Turkish (with an optional English summary section) based on the following git commits for version {version}:

GIT COMMITS (since {last_tag or 'previous release'}):
{commit_log}

REQUIREMENTS:
- Follow this structure:
  - Header: ## 📦 Sürüm [{version}] – [Kısa Başlık Türkçe]
  - Section: ### 🚀 Değişiklikler (with bullet points: * **[Özellik/Düzeltme Adı]:** [Açıklama])
  - Section: ### 🐛 Hata Düzeltmeleri (with bullet points)
  - Section: ### ⚡ Performans & İyileştirmeler (if applicable)
  - Section: ### ⚠️ Kırıcı Değişiklikler (varsa, yoksa 'Yoktur')
  - English section below: ## 📦 Version [{version}] – [Short Title English] with Changes and Bug Fixes.
- Emojis to use: 📦, 🚀, 🐛, ⚡, 🎨, 🔧, 🔒.
- Professional, developer-friendly, clear and concise tone.

OUTPUT FORMAT:
Respond ONLY with a valid JSON object with a single key "release_notes" (no surrounding text or markdown formatting except the JSON):
{{
  "release_notes": "# ... markdown content ..."
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
            print(f"[!] Model {model} request failed: {e}. Trying fallback if available...")

    raise RuntimeError(f"Gemini API request failed on all models: {last_error}")

def generate_with_agy(version: str) -> str:
    print(f"[*] Calling Antigravity CLI (agy) to generate release notes for v{version}...")
    agy_prompt = (
        f"Copilot Button projesinin v{version} surumu icin surum notlarini olustur. "
        "1. Git commit loglarini ve son degisiklikleri incele. "
        "2. .github/RELEASE_TEMPLATE.md sablonuna birebir uyarak '.github/releases/RELEASE_{version}.md' dosyasini olustur."
    )

    cmd = ["agy", "-p", agy_prompt, "--add-dir", str(PROJECT_ROOT), "--dangerously-skip-permissions"]
    res = subprocess.run(cmd, cwd=PROJECT_ROOT)
    if res.returncode != 0:
        raise RuntimeError(f"agy CLI exited with code {res.returncode}")

    target_file = PROJECT_ROOT / ".github" / "releases" / f"RELEASE_{version}.md"
    if not target_file.exists():
        raise FileNotFoundError(f"agy completed but {target_file} was not created.")

    return target_file.read_text(encoding="utf-8")

def main():
    parser = argparse.ArgumentParser(description="Copilot Button Release Notes Generator")
    parser.add_argument("--version", "-v", help="Release version (default: from lib/Globals.ahk)")
    parser.add_argument("--engine", "-e", choices=["gemini", "agy", "auto"], default="auto",
                        help="Generator engine: gemini, agy, or auto (default: auto)")
    parser.add_argument("--api-key", "-k", help="Gemini API Key (optional)")
    args = parser.parse_args()

    version = args.version or get_current_version()
    print(f"=== Copilot Button Release Notes Generator (v{version}) ===")

    last_tag, commit_log = get_git_context()
    print(f"[*] Commits to summarize:\n{commit_log}\n")

    api_key = find_gemini_api_key(args.api_key)
    engine = args.engine

    if engine == "auto":
        engine = "gemini" if api_key else "agy"

    print(f"[*] Using engine: {engine.upper()}")

    release_notes = ""

    if engine == "gemini":
        if not api_key:
            print("[!] Error: Gemini engine selected but no GEMINI_API_KEY found.")
            print("    Provide it via --api-key, GEMINI_API_KEY environment variable,")
            print("    or save it to C:/Users/kerem/Projects/imza-bilgileri/gemini.key")
            sys.exit(1)
        release_notes = generate_with_gemini(api_key, version, last_tag, commit_log)
    elif engine == "agy":
        release_notes = generate_with_agy(version)
    else:
        print(f"[!] Unknown engine: {engine}")
        sys.exit(1)

    releases_dir = PROJECT_ROOT / ".github" / "releases"
    releases_dir.mkdir(parents=True, exist_ok=True)
    target_file = releases_dir / f"RELEASE_{version}.md"

    target_file.write_text(release_notes, encoding="utf-8")
    print(f"\n[+] Successfully saved release notes: {target_file.relative_to(PROJECT_ROOT)}")

    print("\n=== Next Steps ===")
    print(f"1. Review {target_file.relative_to(PROJECT_ROOT)}")
    print("2. Commit and push:")
    print(f"   git add {target_file.relative_to(PROJECT_ROOT)}")
    print(f"   git commit -m \"docs: add release notes for v{version}\"")
    print(f"   git push origin main")
    print(f"   git tag v{version}")
    print(f"   git push origin v{version}")

if __name__ == "__main__":
    main()
