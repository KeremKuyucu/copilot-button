# Permanent AI Agent Instructions for Copilot Button

> [!IMPORTANT]
> Loaded on EVERY session and turn. AI MUST strictly follow all instructions herein and in `knowledge/` without exception.

---

## 1. Modern Memory Safety & C++20 Standards (MANDATORY)

- **Rule 1.1 (RAII & Zero Memory Leak Mandate)**: Raw owning pointers and unmanaged manual resource allocations (`malloc`/`free`, naked `new`/`delete`) are strictly forbidden. Use RAII wrappers, smart pointers (`std::unique_ptr`, `std::shared_ptr`), or stack semantics. All Win32 handles (`HANDLE`, `HDC`, `HBITMAP`, `HHOOK`, `HWND`) and COM interfaces (`CComPtr`, `winrt::com_ptr`) must have guaranteed deterministic cleanup.
- **Rule 1.2 (Modern C++20 Standards & Robust Error Management)**: Use modern C++20 idioms, `<concepts>`, `std::optional`, `std::string_view`, and strict HRESULT/DWORD error checking. Buffer overflows, unchecked pointer dereferencing, and undefined behavior are strictly forbidden.
- **Rule 1.3 (API Accuracy & Deprecated API Prohibition)**: Adhere strictly to latest stable Windows SDK specifications (Win32, Windows Core Audio MMDevice, Windows Runtime GSMTC, DWM, GDI+). Deprecated Win32 APIs or unsafe C string routines (`strcpy`, `sprintf` without size bounds) are forbidden; use bounds-checked equivalents or modern C++ standard library strings.
- **Rule 1.4 (Breaking Changes & User Confirmation)**: Inform user and request explicit confirmation before introducing breaking architectural changes, modifying external build configurations, or upgrading core platform toolchain targets.

---

## 2. Mandatory Triple-Slash (`///`) Documentation & Quality Score Rule (MANDATORY)

- **Rule 2.1 (Mandatory Doc-Comments)**: Every new/modified public class, struct, enum, function, public method, and public member in headers (`include/*.hpp`) MUST include triple-slash (`///`) doc-comments.
- **Rule 2.2 (Documentation Quality Score Requirement)**: Doc-comments must internally score >=8/10. Lower scores are strictly unacceptable.
- **Rule 2.3 (Meaningful Technical Descriptions)**: Comments must explain purpose, constraints, thread-safety invariants, failure modes, and integration usage. Merely repeating item names is forbidden.
- **Rule 2.4 (English-Only Source Code & Code Comments Mandate)**: Source code, identifiers, struct/field names, UI text/labels, logs, and comments (`///`, `//`) MUST be 100% English. Turkish inside source files is forbidden.
- **Rule 2.5 (Turkish Language Mandate for User Plans & Chat Interaction)**: User communication, plans (`implementation_plan.md`), and walkthroughs (`walkthrough.md`) MUST be written in Turkish for optimal clarity.

### Documentation Score Standard

```txt
0/10 = Missing documentation.
1/10 = Useless placeholder comment.
2/10 = Extremely vague and not technically helpful.
3/10 = Mostly repeats the item name.
4/10 = Mentions purpose but lacks useful context.
5/10 = Basic explanation, but incomplete.
6/10 = Understandable but missing constraints, behavior, or usage notes.
7/10 = Good enough for humans, but not strong enough for long-term AI context.
8/10 = Acceptable: clear purpose, behavior, thread-safety, and relevant context.
9/10 = Strong: explains purpose, behavior, constraints, error handling, and integration context.
10/10 = Excellent: future-proof, precise, technically rich, and useful for AI/human maintenance.
```

---

## 3. Persistent Knowledge Base & Memory Bank Synchronization (MANDATORY - Zero Postponement)

- **Rule 3.1 (Dual-Track Targeted Synchronous Documentation Execution)**: Synchronously update targeted docs BEFORE completing response:
  - **Bug Fixes**: Log in `knowledge/history/bug_fixes.md`. Never add bug fixes to feature tables.
  - **New Features**: Document in `knowledge/history/engine_features.md` in categorized tables.
  - **Session Progress**: Synchronize in `memory-bank/activeContext.md` & `progress.md`.
- **Rule 3.2 (Zero-Postponement Policy)**: "Will write later" or batching is strictly forbidden. Apply updates immediately in the same turn.
- **Rule 3.3 (Memory Bank Reading on Task Start)**: Read relevant memory bank and history files before starting any task.
- **Rule 3.4 (Dedicated Feature Documentation)**: Create or update a dedicated descriptive `.md` document under `knowledge/` for major new systems or architectural subsystems.

---

## 4. Modular Responsibility, SRP & Clean Boundaries (MANDATORY)

- **Rule 4.1 (Single Responsibility Per File - SRP)**: Every `.cpp` / `.hpp` pair must have ONE specific responsibility. Keep `main.cpp` thin (initialization, message loop, shutdown) and delegate logic to specialized subsystems (`KeyHook`, `Audio`, `MediaTracker`, `Osd`, `Tray`, `Config`, `AppRegister`, `Actions`).
- **Rule 4.2 (Anti-God Object Mandate)**: Centralized monolithic manager classes controlling disconnected domains are strictly forbidden. Decompose large structures into focused sub-systems.
- **Rule 4.3 (File & Function Size Limits)**: Source files MUST NOT exceed 800 lines. Functions should be small and focused (<100 lines). Break monolithic routines into private helpers.
- **Rule 4.4 (Strict File Boundary Enforcement)**: Existing module boundaries are absolute. Never merge files, collapse modules, or centralize logic without explicit instruction.
- **Rule 4.5 (Header Purity & Modern C++ Layout Mandate)**: Headers (`include/*.hpp`) must strictly serve as declaration and interface definition points. Placing implementation logic, non-inline functions, or algorithmic bodies inside headers is strictly forbidden (except for templates). Use `#pragma once` consistently across all header files.

---

## 5. Scope Isolation, Architecture Preservation & AI Behavior Lock (MANDATORY)

- **Rule 5.1 (Scope Isolation)**: Only modify the explicitly requested file or module. Unrequested changes or refactoring outside the target area are forbidden.
- **Rule 5.2 (No Implicit Refactoring)**: Reorganizing or rewriting code without instruction is forbidden. Existing architecture is stable and production-grade.
- **Rule 5.3 (AI Behavior Lock & Uncertainty Resolution)**: Never assume missing context or guess. If uncertain or facing ambiguity, ASK the user.

---

## 6. Comprehensive Quality, Formatting & Performance Verification (MANDATORY)

- **Rule 6.1 (Multi-Tool Verification Suite)**: Whenever source code or build configs (`.cpp`, `.hpp`, `CMakeLists.txt`, `resources/app.rc`) are modified, execute before completion:
  1. Build compilation check (MSVC `/W4` or GCC `-Wall -Wextra`, 0 warnings / 0 errors).
  2. Formatting compliance (clean indentation, consistent C++20 conventions).
  3. Logical invariant verification (check memory allocations, state transitions, handle leaks).
  *(Skip checks if only markdown files (`.md`) or docs are modified).*
- **Rule 6.2 (Quantitative Performance & Resource Reporting)**: When modifying source code, report: zero polling loops in steady state, zero heap allocations in per-frame hot loops, and binary size delta.
- **Rule 6.3 (Mandatory Verification Report Block)**: When source code changes are made, final response MUST include:
  - 🛠️ **Compiler & Linter**: 0 warnings / 0 errors (MSVC `/W4` / GCC `-Wall -Wextra`)
  - 🎨 **Code Formatting**: 100% Compliant
  - 🧪 **Verification / Invariants**: All invariants verified (state transitions, handle cleanup)
  - ⚡ **Performance Impact**: [Quantitative impact, e.g., "0.0% change, zero polling"]
  - 🧠 **Memory Footprint**: [Zero allocations in hot loop / Zero memory leaks]
  - 📦 **Binary Size Impact**: [Impact delta, e.g., "+0 KB"]
- **Rule 6.4 (Mandatory State Machine & Parser Testing)**: Whenever state machine transitions (anti-leak timers, tap aggregations), parsers (INI, UTF-8 BOM), or Win32 message routing are modified, verify invariants and edge cases (timer expiration, rapid keystrokes, missing configuration, corrupted inputs).

---

## 9. Strict Redundant Copy & Allocation Prevention (MANDATORY)

- **Rule 9.1 (No Unnecessary Copies)**: Deep copying large strings (`std::wstring`, `std::string`), vectors, or buffers merely out of convenience is forbidden. Pass by `const&`, `std::string_view`, or `std::span` where appropriate.
- **Rule 9.2 (Ownership & Move Semantics First)**: Use `std::move` or references wherever transferring ownership. When consuming collections, avoid intermediate heap allocations.
- **Rule 9.3 (Hot Path Heap Allocation Lock)**: Calling `new`, `malloc`, or reallocating `std::vector`/`std::wstring` inside high-frequency hot paths (hook callbacks, mouse hit-testing, paint/timer loops) is a direct rule violation. Pre-allocate or reuse static buffers.

---

## 10. Absolute Prohibition of Hardcoded Magic String Heuristics (MANDATORY)

- **Rule 10.1 (Universal Ban on String-Based Subsystem Logic)**: Engine decisions MUST NEVER inspect localized window titles, localized device names, or fragile string matching (`str.find(...)`, hardcoded language filters).
- **Rule 10.2 (100% Data-Driven & Explicit Type System Mandate)**: Decisions must be driven directly by type-safe C++ enums (`enum class Action`, `enum class MediaCardButton`), structured configuration schemas, and native OS APIs (Core Audio endpoint IDs, WinRT GSMTC session tokens).
- **Rule 10.3 (Asset, Language & Localization Independence)**: Application must function flawlessly across any Windows display language and character set (English, Turkish, Japanese, German, etc.).
- **Rule 10.4 (Industrial Solution Mandate)**: Never write temporary string checks for specific test cases. Solutions must be generic, modular, and industry-standard architecture.

---

## 11. Strict Prohibition of Compiler Warning Suppressions (MANDATORY)

- **Rule 11.1 (Universal Ban on Warning Suppressions)**: Pragmas and attributes that suppress compiler diagnostics (such as `#pragma warning(disable: ...)` or `__attribute__((unused))`) are universally banned without exception.
- **Rule 11.2 (Refactor Over Suppression)**: Resolve warnings at root cause: fix signed/unsigned conversions, initialize all struct members, use `static_cast` safely, group parameters into descriptor structures, and remove unused variables.
- **Rule 11.3 (Root-Cause Engineering)**: Resolve warnings at root cause; never sweep under the rug.

---

## 12. Neutral & Brand-Free Technical Documentation Standard (MANDATORY)

- **Rule 12.1 (No Third-Party Software / Brand Name-Dropping)**: Never reference third-party commercial software by name in comments, commits, or docs ("Unreal-style", "Unity standard", "Blender-like" are forbidden). Describe technical patterns directly.
- **Rule 12.2 (No Hype or Superlative Adjectives)**: Subjective marketing words ("AAA", "perfect", "flawless", "legendary", "world-class") are forbidden.
- **Rule 12.3 (Factual, Concise & Objective Engineering Language)**: Documentation and comments must describe only what the code does, inputs/outputs, math/physics principles, and architectural purpose in objective engineering language.
