# GLua development and debugging tools

Research snapshot: September 11, 2026. These are evaluated candidates, not a claim that their debuggers have been installed or tested with this gamemode. See [GLua working notes](glua-notes.md) for everyday debugging and the actual validation record.

## Recommended direction

Evaluate **GLuaLS with its matching Pollux debugger** for editor diagnostics and interactive debugging. Keep **GLua Enhanced plus GLuaFixer** as the simpler editor alternative. Use **FProfiler** when a factory becomes slow, and retain our automated rule and real-engine tests for repeatability.

| Tool | Useful for this project | Assessment |
| --- | --- | --- |
| [GLuaLS](https://github.com/Pollux12/vscode-gmod-glua-ls) | Realm and network diagnostics, navigation, breakpoints, error tracking, entity inspection | Most promising integrated candidate; early release, validate against our installation |
| [Pollux's gm_rdb](https://github.com/Pollux12/gm_rdb) | Runtime debugger paired with GLuaLS | Newer continuation of the module the user suggested |
| [Original gm_rdb](https://github.com/danielga/gm_rdb) and [vscode-gmrdb](https://github.com/danielga/vscode-gmrdb) | Standalone GLua stepping and inspection | Useful reference/fallback; published native binaries date to 2021 |
| [GLua Enhanced](https://github.com/WilliamVenner/vscode-glua-enhanced) | GMod autocomplete, realm flags, wiki links, asset-path assistance | Established editor alternative; choose one GLua editor stack |
| [GLuaFixer / glualint](https://github.com/FPtje/GLuaFixer) | GLua syntax/style checks, deprecated calls, duplicate keys, unused variables | Useful complement to behavior tests |
| [FProfiler](https://github.com/FPtje/FProfiler) | Function cost, call counts, spikes; client or server realm | First profiler to evaluate for machine and Wire callback cost |
| [gmod-tracy](https://github.com/e-gleba/gmod-tracy) | Instrumented timing zones and graphs | Interesting experiment; repository archived August 14, 2026 |

## GLuaLS and the modern gm_rdb fork

The extension ID is `Pollux.gmod-glua-ls`. Its [August 23 release](https://github.com/Pollux12/vscode-gmod-glua-ls/releases/tag/1.2.1) is marked prerelease. The project explicitly describes itself as early software. Its realm analysis, scripted-entity support, and live inspection fit our server-owned machine state. Do not enable GLua Enhanced alongside it: the extension reports a conflict and blocks startup. Source: [extension documentation](https://github.com/Pollux12/vscode-gmod-glua-ls).

The companion [Pollux fork](https://github.com/Pollux12/gm_rdb) started from Daniel's module. Its current source describes separate server `rdb` and client `rdb_client` modules, ports 21111 and 21112, CMake builds, and Windows/Linux CI. Published [v0.0.14](https://github.com/Pollux12/gm_rdb/releases/tag/v0.0.14) dates to June 16, 2026. Match the extension, module release, realm, OS, and actual game architecture; a 64-bit Windows installation does not establish which GMod executable is running.

There is documentation drift: the extension README still emphasizes SRCDS-only debugging, while its [current client provider](https://github.com/Pollux12/vscode-gmod-glua-ls/blob/main/src/debugger/gmod_debugger/GmodClientDebuggerProvider.ts) and the companion module describe client support. Treat client/listen-server compatibility as an explicit trial, not an established result. Do not combine instructions from the original module and this fork: their activation behavior differs.

Our proposed evaluation is a disposable local dedicated server first, followed by the client HUD and native single-player. Verify a breakpoint in a press callback, inspect `GFState`, resume a production cycle, capture a runtime error, and confirm that source links open this checkout. The project lives outside the game directory and is mounted through an addon junction, so source mapping needs verification.

The extension's [debugger setup action](https://github.com/Pollux12/vscode-gmod-glua-ls/blob/main/res/walkthrough/debugger.md) installs native modules and an autorun bootstrap. Keep that setup in the development installation. Record exact installed versions when the evaluation is performed; a recent repository push alone does not establish runtime compatibility.

## Original gm_rdb: preserve the useful details

Daniel's [VS Code adapter](https://github.com/danielga/vscode-gmrdb) uses debugger type `gmrdb`, with attach/launch configurations, source-root mapping, breakpoints, variables, watches, and stepping. It is specifically paired with Daniel's module, not an arbitrary generic LRDB extension. The original activation sequence is `require("rdb")` followed by `rdb.activate()`; it waits for a debugger connection and resume. `rdb.deactivate()` is exposed by the [module source](https://github.com/danielga/gm_rdb/blob/master/source/main.cpp).

The [native release list](https://github.com/danielga/gm_rdb/releases) contains both regular and `x86_64/1.1.0` assets from March 26, 2021. Select by game branch and architecture, not just the newest-looking filename. The original [build README](https://github.com/danielga/gm_rdb) documents Visual Studio 2017 and older SDK assumptions. Those instructions are historical evidence, not a validated build recipe for this machine.

## Editing and automated checks

[GLua Enhanced](https://github.com/WilliamVenner/vscode-glua-enhanced) supplies GMod API completion, realm flags, wiki context, and model/material browsing. Its bytecode heatmap is explicitly approximate: it cannot tell us how a working physics factory performs.

[GLuaFixer](https://github.com/FPtje/GLuaFixer) understands GLua syntax and supports editor integration and a reusable CI workflow. Configure syntax-error reporting deliberately: its documented default is off. If adopted as a required check, pin the tool version and establish a clean baseline before making CI fail on warnings. A formatter should never change the tested production rules merely to satisfy a style preset.

Our current Lua 5.1 suite tests the production rules and compiles our intentionally compatible source. That is useful but narrower than validating every GLua extension. Keep engine-specific syntax out of the independent rules, or update the test runtime deliberately when that changes.

## Profiling a factory

[FProfiler](https://github.com/FPtje/FProfiler) opens with the `FProfiler` console command and supports client/server selection, focused profiling, aggregate bottlenecks, and expensive individual calls. Server profiling requires its administrative permission. It uses `debug.sethook` and `SysTime`; profiling changes the workload. Facepunch also [documents LuaJIT caveats for debug hooks](https://wiki.facepunch.com/gmod/debug.sethook). Use captures to find candidates, then compare actual performance with the profiler stopped.

For our first representative benchmark, hold the map and addon set constant and compare idle machines, processing machines, and machines connected to a working Wire/E2 transport line. Record machine count, loose-item count, constraints, server tick time, client frame time, and throughput. Investigate dock searches, outlet traces, signal fan-out, and contract writes based on measurements. Large improvements should preserve physical handling and player programming. This follows Facepunch's [measure-before-optimizing guidance](https://wiki.facepunch.com/gmod/optimizationTips).

[gmod-tracy](https://github.com/e-gleba/gmod-tracy) exposes explicit zones, frame marks, plots, and messages to the Tracy UI. Its [February 2026 release](https://github.com/e-gleba/gmod-tracy/releases/tag/v1.0.0) is newer than the original gm_rdb binaries, but its archived status makes it an optional experiment. Native module compatibility and instrumentation overhead remain untested here.

## Wiremod-specific debugging workflow

Inspect our machine's inputs, outputs, fault code, and inventory before stepping into Wiremod internals. Distinguish a missing rising edge, a blocked physical dock, and a production-rule fault. Use the smallest circuit that reproduces the behavior, then restore the full E2 program and transport system.

An E2 program is not an ordinary Lua file. Its first checks belong in the installed E2 compiler and Wire signal feedback. Our smoke test compiles the supplied controller with the real E2 compiler; it does not prove an entire wired line works. Native GLua stepping is for our entity callbacks and the Lua implementation underneath E2.

Breakpoints pause execution and distort timing-sensitive behavior. Use state inspection for sequencing bugs, recorded signals for intermittent behavior, and profiling for cost. Keep the separate multiplayer and late-join checks in [CONTRIBUTING.md](../CONTRIBUTING.md).
