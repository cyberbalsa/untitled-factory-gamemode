# Design: program your factory

The core player activity is building and programming contraptions. A machine exposes one physical operation, its commands, and its feedback. It must not silently provide the entire automation sequence.

The setting is a sci-fi industrial outpost requisitioned by distant overlords. Their orders give players a reason to improve throughput, reliability, and fault handling. Spacebuild, Factories, and FactoryRP are references; this project has a new implementation.

## First production cell

```text
Wire-controlled feeder -> player-built transport -> servo press
servo press -> player-built transport -> tribute uplink -> shared order
```

Amber boxes mark input docks. Green boxes mark output docks. Only material physically at the inlet can be loaded or submitted. The press stores one workpiece while processing and creates a physical item again when commanded to eject. It never transfers items to the next machine automatically.

## Wire interface

Actions trigger once when their value changes from zero/nonpositive to positive. A continuously high action does not repeat. Positive finite values are high; Clamp is a continuous level. Inlet values are `0` empty, `1` blank, `2` component.

| Machine | Inputs | Outputs |
| --- | --- | --- |
| Blank feeder | `Dispense` pulse | `Ready`, `Blocked`, `Limited`, `Dispensed` |
| Servo press | `Load`, `Cycle`, `Eject`, `Reset` pulses; `Clamp` level | `Inlet`, `Loaded`, `Clamped`, `Ready`, `Busy`, `Done`, `Progress`, `Blocked`, `Fault` |
| Tribute uplink | `Submit` pulse | `Inlet`, `Ready`, `Accepted`, `Rejected`, `Order`, `Delivered`, `Required`, `Favor` |

Status signals are Boolean numbers except Inlet, Progress (0-100), Fault, and counters. `Done` remains high until the component is ejected. `Ready` on the press means a blank is loaded, clamped, idle, and fault-free. Uplink Ready means a component is waiting and its cooldown has elapsed. Feeder Ready includes output clearance, stock capacity, and its one-second cooldown.

Signals update at 10 Hz. Controllers should use feedback rather than assuming commands succeed immediately. The optional E2 example only sequences the press; transport is still a construction/programming problem.

### Press faults

| Code | Meaning | Recovery |
| --- | --- | --- |
| 0 | Operational | None |
| 1 | No blank | Supply a blank; reset |
| 2 | Clamp closed during load/eject | Release clamp; reset |
| 3 | Cycle requested without clamping | Clamp; reset |
| 4 | Wrong material | Move a blank to the inlet; reset |
| 5 | Clamp released during cycle | Reset, clamp, and restart the full cycle |
| 6 | Output obstructed or loose-item limit reached | Clear space; reset |
| 7 | Nothing to eject | Load material; reset |

Reset clears the fault and cancels an active cycle without converting the blank. It does not release the clamp. An idle workpiece can be ejected for recovery. Requests to start another cycle while busy do not restart the clock.

## Multiplayer and persistence

The server owns material identity, processing, delivery, and quotas. Clients display state and request ordinary Sandbox/Wire actions. Wiremod handles wire synchronization. Everyone contributes to one shared contract, including late joiners.

Only issued stock is tracked as material. Arbitrary props and duplicated material entities do not count toward orders. Machine blueprints create empty hardware. The current prototype is intended for trusted cooperative groups; Sandbox building freedom and ordinary addon permissions remain in effect.

Orders and favor save under `data/gmod_factory/solo_<map>.json` or `coop_<map>.json`. Factory structures and loose stock are not automatically restored. World persistence needs a deliberate design covering constraints, Wire links, machine contents, and order state together.

## Next design questions

- Add programmable gantries, grippers, and loaders that make physical logistics satisfying.
- Choose machine models and verify collision geometry, scale, dock placement, and visibility.
- Introduce a second processing operation and mixed products to require sorting and routing.
- Add finite inputs, power, and overloads after the first control loop is enjoyable.
- Introduce overlord personalities, time-sensitive orders, and consequences with a forgiving learning phase.

These are future directions, not implemented features.
