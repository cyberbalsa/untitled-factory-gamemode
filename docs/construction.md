# Personal resources and the construction hub

Each builder has a personal resource reserve. Feed separated material into that builder's physical hub to fund more construction. Raw parcels remain in the world until deposited; the reserve itself is carried as account balances and displayed on the HUD.

## Bootstrap and prices

A new account receives 40 gravel, 30 sand, 20 clay, and 40 mineral concentrate. This is granted once per player, map, and play mode. Death, respawn, and reconnecting do not create another grant. The starter-cell button purchases four machines from this reserve; it does not grant free machines on repeated use.

| Build | Gravel | Sand | Clay | Concentrate |
| --- | ---: | ---: | ---: | ---: |
| Construction hub | 8 | 2 | 4 | 4 |
| Soil extractor | 6 | 2 | 0 | 4 |
| Soil separator | 8 | 4 | 4 | 6 |
| Tribute uplink | 4 | 4 | 2 | 4 |
| Complete starter cell | 26 | 12 | 10 | 18 |
| Ordinary counted build object | 1 | 0 | 0 | 0 |
| Wire device, gate, or E2 chip | 0 | 1 | 0 | 1 |

After purchasing the starter cell, 14 gravel, 18 sand, 10 clay, and 22 concentrate remain for contraptions. Prices are provisional and centralized in `core/sh_construction.lua`. They are deliberately simple at Tier 0; models do not yet have different costs based on dimensions or mass.

## Feeding the hub

Move gravel, sand, clay, or concentrate to the hub's amber input dock and pulse `Deposit`. One parcel adds one resource to the hub builder's reserve. Soil must be separated first. The same parcel cannot also count as tribute: hub deposits and uplink submissions compete for actual physical material.

The hub belongs to its builder. Any player or circuit may feed it, which allows deliberate donations in cooperative play. Credit still goes to its builder if they disconnect. A duplicated hub belongs to the player who pays for the new copy; it does not copy the original account.

| Input | Meaning |
| --- | --- |
| `Deposit` | Rising-edge command; minimum 0.25 seconds between attempts |

| Output | Meaning |
| --- | --- |
| `Inlet` | Resource ID at the dock, or 0 |
| `Ready` | Eligible stock, room in the reserve, and cooldown complete |
| `Accepted`, `Rejected` | Deposit attempt counters |
| `Gravel`, `Sand`, `Clay`, `Mineral` | The owner's available construction resources |

Each resource has a one-million-unit owned cap. A full reserve leaves the parcel unconsumed. Reserved construction materials count toward that cap. The hub is an intake, not a machine that creates free material or withdraws the bootstrap as tribute.

## Building, undo, and recovery

Construction reserves the required quantities against a live entity. All requirements are checked together: an insufficient resource cannot partially spend the others. A failed or denied build does not leave a permanent charge. Physgun movement, rewiring, and code edits on existing hardware do not charge again.

Removal, undo, and cleanup release the original construction price to the original builder. Buffered stock is still scrapped when removing a machine. Material deposits are actual income; dismantling and rebuilding only rearrange the same construction budget. Duplication requires a new reservation for each new entity.

Receipts live in a server-side entity ledger, outside entity tables that duplicators copy. Registering an entity in multiple Sandbox count categories charges once. A second removal callback cannot refund it twice.

The current integration charges our machine spawner and Sandbox's `Player:AddCount` path. Standard Sandbox builds and the inspected Wire constructors, including E2, use that path. Addon constructors that create buildable entities without registering them there must explicitly call `GF.PayForBuild(ply, ent)` and stop if it returns false. Arbitrary third-party constructors are not yet certified. Tool connections that create no separately counted object have no additional charge.

## Save behavior

Owned totals save under `data/gmod_factory/build_solo_<map>.json` or `build_coop_<map>.json`, keyed by SteamID64 strings. The parser preserves string keys with `util.JSONToTable(..., false, true)`; the default key conversion is unsuitable for SteamID64. Source: [Facepunch documentation](https://wiki.facepunch.com/gmod/util.JSONToTable).

Reservations remain in memory while their entities exist, including while the owner is disconnected. Since factory structures are not saved yet, map/server reload makes the owned total available again. It does not add another bootstrap grant. When world persistence is added, loaded entities and their reservations must be restored together.

`gf_resources` prints available/owned quantities and machine prices in the console. The HUD shows available quantities, so it reflects what the player can currently afford.
