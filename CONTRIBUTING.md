# Contributing

Build small changes around the central activity: players program physical contraptions with Wiremod. Keep the Lua rules independent of the engine where practical, and keep authoritative production state on the server.

Read [GLua working notes](docs/glua-notes.md) for the project's collected debugging guidance, source references, and engine-specific pitfalls.

See [development tools](docs/development-tools.md) for the GLuaLS/gm_rdb evaluation, editor alternatives, and profiling workflow.

Open a pull request with the player-facing behavior and relevant validation. Contributions to this repository's code use the MIT license. Keep third-party models, textures, sounds, and addons out of source commits; document their original Workshop dependencies instead.

## Checks

Install `requirements-dev.txt` and run `python -m pytest -q`. Tests compile every gamemode Lua file in Lua 5.1 and exercise terrain eligibility, separation, material conservation, orders, and the retained press rules.

For in-game checks, use a disposable local map with Wiremod enabled:

1. Start native single-player, survey grass and concrete with `gf_ground`, request starter hardware on grass, and verify the Wire ports. Props, walls, distant ground, and tipped extractors must not yield soil.
2. Complete extraction/separation/uplink delivery with wired buttons, then use the E2 example to control the separator. Route and store every fraction.
3. Hold Extract high, check its cooldown, reset a processing batch, obstruct the outlet, and recover. No action may create extra items or erase buffered fractions.
4. Deliver ten gravel parcels, confirm the next quota requests sand, and reload the map to check saved progress. Wrong resources remain unconsumed.
5. Duplicate loaded hardware: the copy must be empty. Copied stock must not become deliverable material.
6. Host multiplayer, join from a second client, and verify shared orders, late-join state, simultaneous loading/delivery, and Wire-controlled transport.
7. Purchase the starter cell from the bootstrap, deposit a fraction into its hub, and verify the personal reserve. Build/remove/undo/duplicate props and Wire devices. Each new entity pays once and removal refunds its original builder. Reconnect without receiving another bootstrap.

Automated Lua checks cannot validate Source physics, client rendering, Steam addon mounting, or a second player's experience. Record the game version and which in-game checks were actually performed.

On Windows, `tools/engine-test.ps1` automates a disposable native single-player check. GMod must be closed. If direct launch fails to mount Workshop addons, pass `-WireSource` pointing to a locally extracted Wiremod folder. The script creates temporary addon links, runs `lua/ufg/tests/smoke.lua`, restores the original contract and personal reserve, writes `data/gmod_factory/smoke_result.json`, and closes the test game. The integration test also compiles the supplied E2 examples against the installed Wiremod compiler. Test actions span engine ticks to respect Wire's per-tick input limit; test parcels are frozen for deterministic dock placement.
