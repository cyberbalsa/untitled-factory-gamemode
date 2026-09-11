# Tier 0: everything starts in the dirt

Tier 0 is the renewable-resource starting point, inspired by the user's Seablock comparison. There are no ore patches to search for or deplete yet. Exposed grass/dirt yields soil; processing turns that bulk parcel into several raw materials. Values are provisional and live in `core/sh_tier0.lua`.

```text
Exposed dirt/grass
  -> Extract pulse -> soil parcel
  -> physical transport -> Load -> Cycle (4 seconds)
  -> select Resource -> Eject one fraction
       11 gravel / 12 sand / 13 clay / 14 mineral concentrate
  -> physical transport -> construction hub, storage, or requested tribute
```

## Resources and recipe

| ID | Resource | Current source | Future role |
| --- | --- | --- | --- |
| 10 | Soil | Extractor on suitable world terrain; one parcel per pulse, two-second cooldown | Feedstock |
| 11 | Gravel | One per soil batch | Crushing, aggregate |
| 12 | Sand | One per soil batch | Glass/silica processing |
| 13 | Clay | One per soil batch | Ceramics |
| 14 | Mineral concentrate | One per soil batch | Later separation/refining into metals |

Future uses are design intentions. Tier 0 currently ends in collection and raw-resource orders. One large soil parcel becomes four smaller fractions; item counts do not represent equal mass. No random roll discards a byproduct. All four fractions occupy a finite internal buffer, and another soil batch cannot load until all are collected.

The earlier free-blank feeder is removed. The press rules and entity remain as a future-tier prototype, but the press is absent from the Tier 0 spawn list and starter kit.

## Ground detection

The server traces 48 units straight down from an upright extractor, ignoring only the extractor itself. Any intervening prop blocks access. The trace must reach visible world ground, start outside solids, and have a surface normal with vertical component at least 0.7. Sky, nodraw, props, walls, and ceilings are rejected.

First use `MAT_DIRT` or `MAT_GRASS`, then the surface-property names `dirt`, `grass`, `soil`, or `mud`. For unclassified material types only, allow those complete word tokens in the material name. `gf_soil_texture_fallback 0` disables the name fallback. Explicit concrete or metal classification is not overridden by a soil-looking filename.

Why use tags first: `HitTexture` can be `**displacement**` for terrain or `**studio**` for props. It is not a reliable texture filename on every surface. `MatType` and `SurfaceProps` provide additional metadata. Sources: [Facepunch: TraceResult](https://wiki.facepunch.com/gmod/Structures/TraceResult), [MAT enums](https://wiki.facepunch.com/gmod/Enums/MAT), [surface-property names](https://wiki.facepunch.com/gmod/util.GetSurfacePropName).

Use `gf_ground` while looking at a surface to print its classification, material type, surface name, and material path. The extractor overlay reports why it can or cannot operate. This performs local traces, not a whole-map texture scan during gameplay.

For a map with incorrect material metadata, a server addon can supply an exact exception:

```lua
hook.Add("GF_AllowSoilSurface", "my_map_soil", function(trace, machine)
    if game.GetMap() == "my_map" and trace.HitTexture == "my_map/garden_ground" then
        return true
    end
    -- Return nil for normal classification; false explicitly excludes a surface.
end)
```

An exception changes soil eligibility only; it does not permit props, steep walls, sky, or traces inside solids. The `machine` parameter is nil during a crosshair survey. Maps with no suitable terrain need a deliberate map exception or a future terrain-source design; the extractor does not default to mining any floor.

## Wire interface

| Machine | Inputs | Outputs |
| --- | --- | --- |
| Soil extractor | `Extract` pulse | `Ground`, `Ready`, `Blocked`, `Limited`, `Extracted` |
| Soil separator | `Load`, `Cycle`, `Eject`, `Reset` pulses; `Resource` ID | `Inlet`, `CanLoad`, `Loaded`, `Ready`, `Busy`, `Done`, `Progress`, `Blocked`, `Fault`, `Selected`, `Gravel`, `Sand`, `Clay`, `Mineral`, `Pending` |
| Tribute uplink | `Submit` pulse | `Inlet`, `Target`, `Ready`, `Accepted`, `Rejected`, `Order`, `Delivered`, `Required`, `Favor` |
| Construction hub | `Deposit` pulse | `Inlet`, `Ready`, `Accepted`, `Rejected`, `Gravel`, `Sand`, `Clay`, `Mineral` |

All action inputs need a fresh nonpositive-to-positive transition. A held-high input never repeats. Finite positive numbers are high. Resource selection requires an exact integer ID; invalid selections become 0. `Inlet` and `Target` use the same resource IDs; Inlet 0 means no issued stock at the dock.

`CanLoad` means the separator is empty and fault-free. `Ready` means soil is loaded and can start processing. `Done` remains high while any finished fraction is buffered. `Pending` and the four named resource outputs are inventory counts. Signals update at 10 Hz; use feedback rather than assuming a command succeeded.

`Resource` initially selects gravel (11), but a connected Wire input controls it. Set the selector before pulsing Eject. Select 10 to recover loaded, unprocessed soil while idle. Reset cancels an unfinished cycle while preserving soil; completed fractions survive Reset. Blocked output or entity-creation failure preserves inventory. Machine deletion scraps its contents, and duplication creates empty hardware.

| Separator fault | Meaning |
| --- | --- |
| 0 | Operational |
| 1 | No soil loaded |
| 2 | Wrong input material |
| 3 | Outlet blocked or loose-item cap reached |
| 4 | Selected resource is not available |
| 5 | Invalid Resource ID |

Correct the cause, then pulse Reset. Busy commands and attempts to load over remaining fractions are ignored without replacing the current batch.

The [example E2 controller](../examples/soil-separator-controller.txt) cycles and empties the separator in a fixed priority order. It is intentionally an optional example; the extractor, transport, storage, and tribute routing remain the player's circuits.

The [construction hub](construction.md) turns physical fractions into its builder's personal construction reserve. Bootstrap resources cover the first production cell and some props/Wire devices; further expansion requires deposits. Hub deposits do not also count as tribute.

## Orders and persistence

Orders request gravel, sand, clay, and mineral concentrate in rotation. Quotas rise by five from an initial ten and cap at 100. Completing an order awards 100 favor. Wrong resources are not consumed. Read `Target` when designing the dispatch controller; do not assume every resource is always accepted.

Tier 0 saves use `data/gmod_factory/tier0_solo_<map>.json` or `tier0_coop_<map>.json`. The earlier component-prototype save files are preserved separately. Saves still cover orders and favor, not factory structures or buffered/loose resources.
