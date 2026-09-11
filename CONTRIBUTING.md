# Contributing

Build small changes around the central activity: players program physical contraptions with Wiremod. Keep the Lua rules independent of the engine where practical, and keep authoritative production state on the server.

Read [GLua working notes](docs/glua-notes.md) for the project's collected debugging guidance, source references, and engine-specific pitfalls.

See [development tools](docs/development-tools.md) for the GLuaLS/gm_rdb evaluation, editor alternatives, and profiling workflow.

Open a pull request with the player-facing behavior and relevant validation. Contributions to this repository's code use the MIT license. Keep third-party models, textures, sounds, and addons out of source commits; document their original Workshop dependencies instead.

## Checks

Install `requirements-dev.txt` and run `python -m pytest -q`. Tests compile every gamemode Lua file in Lua 5.1 and exercise the actual press and contract rules, including interrupted cycles, blocked ejection, repeated signals, and invalid saved counters.

For in-game checks, use a disposable local map with Wiremod enabled:

1. Start native single-player, request starter hardware, and verify all three machines expose their Wire inputs and outputs.
2. Complete the feeder/press/uplink sequence with wired buttons, then use the E2 example to control the press.
3. Verify holding Dispense high creates only one blank. Release the clamp mid-cycle and recover with Reset. Obstruct the outlet, clear it, reset, and eject.
4. Deliver ten components, confirm the next quota and favor, and reload the map to check saved progress.
5. Duplicate a loaded machine: the copy must be empty. A copied stock entity must not become deliverable material.
6. Host multiplayer, join from a second client, and verify shared orders, late-join state, simultaneous loading/delivery, and Wire-controlled transport.

Automated Lua checks cannot validate Source physics, client rendering, Steam addon mounting, or a second player's experience. Record the game version and which in-game checks were actually performed.

On Windows, `tools/engine-test.ps1` automates a disposable native single-player check. GMod must be closed. If direct launch fails to mount Workshop addons, pass `-WireSource` pointing to a locally extracted Wiremod folder. The script creates temporary addon links, runs `lua/ufg/tests/smoke.lua`, restores the original contract counters, writes `data/gmod_factory/smoke_result.json`, and closes the test game. The integration test also compiles the supplied E2 example against the installed Wiremod compiler.
