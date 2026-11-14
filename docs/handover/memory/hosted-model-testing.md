---
name: hosted-model-testing
description: sandbox-game: workers may test NPC talk against the user's own Gemini config in settings.cfg, read-only, key never printed or committed
metadata:
  type: feedback
---

From 2026-11-07 the user allows testing against their own model config in `~/.local/share/godot/app_userdata/Sandbox Game/settings.cfg` (Gemini, gemini-3.1-flash-lite), alongside the local Ollama.

**Why:** the user finds Gemini's replies good and wants prompt work measured on it too.

**How to apply:** put this in briefs for NPC/LLM work. The file may only be read. Pass the key via an env var such as LLM_API_KEY, and never print, log or commit it. Keep hosted runs small and back off on HTTP 429. Related: [[quiet-test-runs]].

Caveat seen on 2026-11-07: in auto mode the permission classifier refused a worker reading the api_key from settings.cfg ("Credential Exploration"). Don't work around it. Either the user exports LLM_API_KEY themselves or adds an allow rule. The eval tool takes `LLM_API_KEY` plus `--endpoint`/`--model`.
