# Tech

- Engine: **Godot 4.x**, language: **GDScript**. The exact version is pinned in the project
  (e.g. a `.godot-version` file), and `make setup` checks that the installed Godot
  matches.
- Tiled maps (`.tmx`) are read at runtime by our own small loader (`InteriorLoader`). The
  `.tmx` file stays the source of truth; there is no manual export step. (Decided
  2026-11-05: the YATI importer addon does not run on the Gentoo Godot build and was
  removed.)
- The frame rate is capped by a setting (Settings → Game, `Engine.max_fps`), 60 by default, 10 to
  240 or no limit (task 216, the user 2026-11-12): with only vsync the game drew 240 fps on a 240 Hz
  laptop and the CPU ran hot. Game logic runs on delta, so the speed does not depend on it. `--max-fps=<n>` overrides it for
  one run, never saved; `make test` (through the environment variable `SANDBOX_GAME_MAX_FPS`, as GUT refuses unknown
  flags) and `make bench` pass 0, as `Engine.max_fps` is global and
  the cap would pace a whole test process and floor the bench's frame times.
- Build, run, test and other multi-step tasks are wrapped in **make** targets, so each one
  is a single command.
- **`make setup`** sets up the stack:
  - it installs what it can automatically: project-local addons (GUT) and
    Python tools in a project-local venv;
  - it does not try to install system packages, because the developer machine may run a
    less common Linux distro (e.g. Gentoo). It checks system dependencies (Godot, Python,
    git, curl; Tiled is optional, only for editing interiors) and prints which ones are
    missing, with a hint on what to install;
  - running it again is safe and only does what is still missing.
- Targets (`make help` lists them): `help` (the default), `setup`, `venv`, `run`,
  `screenshot`, `test`, `lint`, `format`, `assets`, `clean` and `export` (a placeholder: no
  export presets exist yet).
- Tools:
  - test LLM for NPC talk (decided 2026-11-06): `make llm-up`, `llm-check` and `llm-down`
    run Ollama (pinned tag) in a podman/docker container with Qwen2.5 7B Instruct (Apache-2.0;
    the 3B has the Qwen Research License and was not as good, 2026-11-07) on the NVIDIA GPU
    when the host has its CDI spec (`make llm-gpu-setup`, 2026-11-09), else on the CPU,
    OpenAI-compatible API on 127.0.0.1:11434/v1 (`tools/llm/llm.sh`); no test needs it;
    `make llm-eval` tries the villagers' prompts on a model (`tools/llm/`);
  - tests: **GUT**, run headless by `make test`; `make test-changed` runs only the tests a
    branch's changes need (task 192, 2026-11-11: the whole range BASE..HEAD and uncommitted files,
    never just the last commit; docs need none, tools the Python tool tests, game code the GUT
    tests that reach it, and what it cannot place runs everything; it follows only what the code
    spells out, so it is a net with holes and not a promise, and git-ignored addons/ and assets/
    are invisible to it). Workers use it while
    developing and run one full `make test` before reporting; the coordinator runs a full
    `make test` on main after every 5 merges or at the end of a batch and, if it fails, bisects
    over the merges since the last green full run;
  - lint and format: gdtoolkit (`gdlint` / `gdformat`).
