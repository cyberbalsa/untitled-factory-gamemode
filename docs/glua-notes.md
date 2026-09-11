# GLua working notes and debugging guide

Reviewed September 11, 2026 for Untitled Factory Gamemode. These are our own condensed notes from [Luctus's wiki](https://luctus.at/wiki/), maintained by OverlordAkise, plus official documentation and observations from this project. They are not a copy of the wiki. Follow the source links for the full explanations.

## Realms and loading

Server and client have separate Lua state. A shared file provides the same definitions to both; it does not synchronize variables. Keep inventory, machine transitions, and rewards on the server, and drawing on the client. Source: [Luctus: realms](https://luctus.at/wiki/glua/1_realms/).

`AddCSLuaFile` distributes source to clients; `include` executes a file in the current realm. Names such as `sh_` are conventions, not a universal loader. Our gamemode explicitly includes its files. Autorun directories have special behavior. GMod merges addons into a virtual filesystem, so identical paths can collide. Sources: [Luctus: loading](https://luctus.at/wiki/general/loading_order/), [Facepunch: loading order](https://wiki.facepunch.com/gmod/Lua_Loading_Order).

Project application: investigate an absent WireLib as a dependency/mount/loading problem before patching individual machines. Check that Wiremod loaded on the server and client. A subscribed archive being present on disk does not prove it mounted before a directly launched map.

## Debug in the right realm

Start from the first relevant error and its stack, not the later cascade. Use `print` for a few scalar values and `PrintTable` for structured state. Clearly label temporary instrumentation and remove or disable it before release. `debug.Trace()` helps locate an unexpected caller. Source: [Luctus: debugging](https://luctus.at/wiki/glua/debugging/).

Useful read-only commands in the console of our local development server:

```text
lua_run print("[UFG] server Wiremod:", WireLib ~= nil)
lua_run print("[UFG] gamemode:", engine.ActiveGamemode())
lua_run PrintTable(GF.Contract)
lua_run print("[UFG] loose stock:", GF.StockCount())
lua_run PrintTable(player.GetAll())
```

For one machine, replace `123` with its entity index:

```text
lua_run local e = Entity(123) if IsValid(e) then print(e:GetClass(), e:GetModel(), e:GetPos()) PrintTable(e.GFState or {}) end
```

These commands are project-specific examples. Do not assume player entity 1 is always the player being investigated. Use the player list and validate references.

For reproducible tests, run the checked-in local test script. Do not make remote HTTP-to-RunString loading part of the project's debugging workflow. A fresh game start is the reference test for changed dependencies and added files.

## Hooks, errors, and timers

Use unique hook IDs. A non-nil return, including `false`, stops later callbacks and can prevent the gamemode callback. Return a value only for an intentional decision defined by that hook. Sources: [Luctus: hooks](https://luctus.at/wiki/tutorial/3_hooks/), [Facepunch: hook.Add](https://wiki.facepunch.com/gmod/hook.Add).

Reserve thrown errors for conditions that should abort the current operation. In shared hook execution, consider `ErrorNoHaltWithStack` so diagnostics retain context without interrupting other callbacks. Expected gameplay faults, such as an open clamp, belong in machine state and feedback, not Lua exceptions. Source: [Luctus: error handling](https://luctus.at/wiki/glua/error_handling/).

Recheck entity/player validity inside delayed callbacks. Named timers help when an operation must be canceled or cleaned up. Source: [Luctus: timers](https://luctus.at/wiki/tutorial/4_timer/).

Project application: press progress is calculated from elapsed server time, rather than counting Think calls. Reset and clamp release explicitly cancel an active operation. The welcome timer checks the player again before use.

## Entity lifecycle and performance

Check whether `ents.Create` succeeded before using the result. Budget networked entities and physics work; old maximum-entity or memory figures are not suitable factory-size targets. Schedule server entity work with `NextThink` and the required return value, instead of automatically doing everything every tick. Source: [Luctus: entities](https://luctus.at/wiki/general/about_entities/).

GMod uses LuaJIT and runs Lua work on the main execution path. Expensive loops can stall gameplay; benchmark in the real runtime rather than relying on generic Lua micro-optimization advice. Source: [Luctus: engine details](https://luctus.at/wiki/general/1_lua_engine/).

Project application: machines update signals at 10 Hz, changed Wire values are cached, and loose stock has a cap. Profile with realistic machine and constraint counts before expanding those limits.

An entity can remain valid until the next tick after `Remove()`. To prevent double consumption, remove it from `GF.LiveStock` immediately, before requesting engine deletion. A test that expects immediate `not IsValid(ent)` is incorrect. This was observed in our smoke test and confirmed by [Facepunch: Entity:Remove](https://wiki.facepunch.com/gmod/Entity:Remove).

## Networking

Choose a mechanism based on update frequency, recipients, and late-join behavior. A small set of persistent NW/global values can be sufficient; explicit net messages provide more control but need an initial-state strategy. Do not assume a one-time broadcast reaches later players. Source: [Luctus: networking](https://luctus.at/wiki/networking/1_intro/).

Avoid wholesale table traffic in a hot loop. Compression can reduce a bulk payload but costs CPU and does not eliminate limits. If compression becomes necessary, bound input/output sizes and preserve a clear schema. JSON also needs deliberate handling of engine types. Sources: [Luctus: table networking](https://luctus.at/wiki/networking/efficient_net_writetable/), [Facepunch: util.Decompress](https://wiki.facepunch.com/gmod/util.Decompress).

Current official documentation warns against NW2 on Lua-based entities. Do not adopt NW2 for our machines just because it sounds newer or more efficient. Source: [Facepunch: SetNW2Int](https://wiki.facepunch.com/gmod/Entity:SetNW2Int).

Project application: Wiremod carries machine signals. Global contract values support the HUD. Production rewards never come from a client-supplied total. Test late joins and distant factories explicitly before claiming multiplayer validation.

## Persistence

Luctus recommends SQLite for frequently changing structured data and JSON files for smaller, less frequent state. Treat that as a workload decision, not an absolute performance guarantee. SQLite is a persistent database, not merely RAM storage; GMod documents separate server/client database files. Sources: [Luctus: storage](https://luctus.at/wiki/general/storage/), [Facepunch: sql](https://wiki.facepunch.com/gmod/sql).

Project application: the prototype saves a tiny contract record as JSON after delivery. Revisit persistence before scaling throughput or saving whole factories. Future saves must account for machines, contained material, Wire links, constraints, and orders together. Distinguish SQL errors from empty results and use parameter binding where supported.

## Lag and hot reload

First distinguish client frame/rendering problems from server simulation delays. Use `net_graph 3` alongside FPS and server measurements. Isolate addon conflicts by testing smaller sets in a separate local session. Source: [Luctus: lag diagnosis](https://luctus.at/wiki/server/identify_lag/).

Reloaded code does not automatically remove an old hook, timer, or receiver that disappeared from the file. Reproduce suspicious behavior after a clean restart. Source: [Facepunch: hot loading](https://wiki.facepunch.com/gmod/Auto_Refresh).

## Debugger and editor options

See [development tools](development-tools.md) for the original gm_rdb, its newer Pollux/GLuaLS continuation, editor alternatives, GLua linting, and profilers. These are researched candidates; the native debuggers have not yet been validated with this gamemode.

## Project validation record

On September 11, 2026, 21 Lua rule/syntax checks and all 22 engine smoke assertions passed. The game reported `2026.05.08`; the installed Wiremod reported Workshop `2026.09.10 (d6cf473)`. The smoke test covers real ports, physical items, interlocks, output obstruction, duplication, order completion, the file API, and compilation of our example controller by the installed Expression 2 compiler.

A direct executable launch reported zero mounted Workshop addons. The repeatable engine test therefore used a temporary filesystem link to the locally extracted, installed Wiremod archive. Test links were removed afterward. The developer's gamemode link remains installed.

Client visuals, a fully wired E2 transport line, and a second remote player's synchronization still require hands-on checks. The engine helper exits its disposable game instance; do not use it in an ongoing play session.
