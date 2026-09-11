# Design: program your factory

The core player activity is building and programming contraptions. Machines expose physical operations, commands, and feedback. Players supply sequencing, routing, and recovery with Wiremod gates or Expression 2.

The setting is a sci-fi industrial outpost requisitioned by distant overlords. Orders give players a reason to improve throughput, reliability, and fault handling. Spacebuild, Factories, and FactoryRP are references; this project has a new implementation.

## Current baseline: Tier 0

```text
Dirt/grass -> soil extractor -> player-built transport -> soil separator
Separator -> gravel, sand, clay, mineral concentrate -> storage or tribute
```

See [Tier 0](tier0.md) for resource IDs, the exact recipe, terrain detection, machine ports, faults, and save behavior. The starter cell purchases an extractor, separator, uplink, and construction hub from the player's bootstrap reserve. All production starts with soil. The earlier free-blank feeder is removed; the press remains a dormant later-tier prototype.

Amber boxes mark input docks and green boxes mark output docks. Only issued material physically at a dock can be loaded or submitted. Separators retain their complete batch until the player commands each fraction to eject. They do not move output to the next machine automatically.

Action inputs require a fresh nonpositive-to-positive edge. Resource selection is a value. Status updates run at 10 Hz, and controllers should wait for feedback rather than assume success. The optional E2 example sequences the separator; transport and storage remain construction and programming problems.

## Multiplayer and persistence

The server owns material identity, processing, delivery, and quotas. Clients display state and request ordinary Sandbox/Wire actions. Wiremod carries machine signals. Everyone contributes to one shared contract. Late-join behavior still requires a remote-client playtest.

Arbitrary props and duplicated material entities do not count as stock. Machine blueprints create empty hardware. The prototype is intended for trusted cooperative groups; Sandbox building freedom and ordinary addon permissions remain in effect.

Tier 0 orders, favor, and personal construction totals save separately for solo and multiplayer per map. [Construction resources](construction.md) are reserved against live builds and return on removal. Factory structures, buffered material, and loose stock are not restored automatically. World persistence needs a design covering constraints, Wire links, machine contents, construction reservations, and order state together.

## Next construction problem

[Transfer rails](logistics.md) are the proposed solids transport system: physical loader/unloader docks, finite cargo slots, and Wire-controlled routing gates. Cargo can use lightweight records inside the rail while clients animate its travel. This is a proposed optimization and must be measured in a working factory.

The first routing puzzle is collecting every separator fraction while sending only the requested resource to tribute. Further tiers can refine concentrate, turn sand and clay into useful products, add power, and give the overlords more demanding orders. Those features are future work.
