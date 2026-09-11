# Untitled Factory Gamemode

Read `docs/design.md` for the gameplay contract and `docs/glua-notes.md` before changing GLua, networking, entity lifecycle, or debugging code. The latter preserves project-specific lessons from Luctus's wiki, with official API cross-checks and observed engine behavior.

Read `docs/development-tools.md` when setting up editors, native debuggers, linting, or profiling. Distinguish researched capabilities from tools actually validated on this project, and keep debugger modules matched to their editor adapter and game architecture.

## Project direction

- Players program contraptions using Wiremod gates and Expression 2. Machines expose operations and feedback; do not silently automate the full production line.
- Support native single-player and cooperative multiplayer with server-owned production and shared orders.
- Preserve Sandbox building tools and physical material handling.
- Our code is MIT licensed. Keep Workshop models and third-party addon source external; record candidate assets and dependencies in `docs/assets.md`.

## Implementation and validation

- `gamemodes/gmod_factory/gamemode/core/sh_logic.lua` contains engine-independent production rules.
- `sv_factory.lua` owns issued stock, spawning, contracts, and persistence.
- `entities/entities/gf_*` contains Wire machines and material entities.
- Use distinct `gf_`/`ufg_` identifiers for hooks, network keys, commands, and entities.
- Shared files execute separately in each realm. AddCSLuaFile distributes a file; include executes it.
- Treat entity creation as fallible and removal as deferred. Claim stock in the server registry before removing its entity; create ejected stock before clearing internal inventory.
- Preserve intentional hook return behavior. Validate entities inside delayed callbacks.
- Run `python -m pytest -q` with `requirements-dev.txt` installed for rule or Lua changes. Test engine/physics/Wire changes in GMod too when available.
- Use `tools/engine-test.ps1` only when GMod is closed; it starts a disposable solo test and exits the test instance. Never interrupt an existing player session to run tests.
- Record actual validation and remaining limits. A single-player engine test is not proof of remote-client synchronization or visual quality.
- Keep local inventories, extracted dependencies, and logs in ignored `.cache/`. Never commit the local virtualenv or Workshop payloads.
