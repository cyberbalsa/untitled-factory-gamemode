# Proposed logistics: transfer rails

Design direction recorded from the user's request for pipes/belts that remain fun, challenging, and fast. These rails are not implemented yet. The Tier 0 prototype still exchanges physical parcels at docks.

## The player experience

Use visible sci-fi cargo rails for solids, with animated capsules or trays moving along the route. Players build the path; Wire controls loaders and junctions. Basic transit along a built route should work consistently so players can spend their effort on sequencing, sorting, capacity, and coordination.

The first challenge is the soil separator: four fractions share an outlet. The player must remove every fraction, divide output between construction reserves and tribute, and buffer the remainder. An unhandled byproduct backs up the separator. The challenge is legible through item labels, inventory counts, and occupied/blocked lights.

Start with cheap straight links and bends, a loader, an unloader, a small storage buffer, and a two-way routing gate. A clear first objective is to deliver gravel automatically without losing the sand, clay, and concentrate. A second is to react when the next order changes to sand. Larger factories add shared routes, competing sources, and full storage.

## Where programming matters

| Part | Player control | Feedback |
| --- | --- | --- |
| Loader | Pulse `Load` to claim a parcel; hold `Run` to release into a free link | `Item`, `Loaded`, `Ready`, `Blocked` |
| Routing gate | Set `Route`: 0 hold, 1 exit A, 2 exit B | `Item`, `Occupied`, `ReadyA`, `ReadyB`, `Blocked` |
| Unloader | Pulse `Eject` to place a parcel at the physical dock | `Item`, `Occupied`, `Ready`, `Blocked` |
| Storage | Select `Resource`, pulse `Release` | Per-resource counts, `Capacity`, `Full` |

These names are proposed, not a stable API. Ordinary straight segments should not each need a clock circuit. Wire earns its place at decisions: loading, release, routing, order selection, and jam recovery. A constant Run signal is enough for an uncomplicated line; more complex factories reward more capable controllers.

## Performance and transfer rules

Inside the network, cargo is a server-owned record with a resource ID and journey state. Clients draw its motion. At the boundaries, loaders consume registered physical stock and unloaders recreate it. This is intended to reduce the number of independently simulated physics items; benchmark it before making throughput or factory-size promises.

Each segment and junction has finite capacity. Reserve a receiving slot before releasing the source, and commit each transfer exactly once. A full destination backs up upstream cargo. It must never disappear, duplicate, skip the selected route, or teleport across an unbuilt gap.

Routes must exist in world space with bounded segment lengths, real endpoints, and obstruction checks. For the first version, use fixed travel times based on link length. Update occupied links rather than scanning every idle link or searching a path for every item. Late-joining clients need the current cargo state before animating it.

Keep in-transit cargo separate from the loose-physics-item cap, but give cargo and rail entities their own explicit caps. Otherwise a player could merely move unlimited stock into pipes. An unloader with no room retains its parcel. Disconnecting, deleting, duplicating, saving, and restoring a loaded network need material-conservation rules before release.

## What to build first

Implement and test one short loader-to-unloader route, including a blocked output and a full input. Then add the two-way routing gate and storage needed for all four Tier 0 fractions. Keep spills, damage, power grids, fluid simulation, and speed upgrades for later playtests; the initial difficulty comes from control and throughput.

Transport should also coexist with ordinary Wire contraptions. Players can use rails for bulk transfer and pistons, grabbers, or custom machinery where physical manipulation is useful. Pipes for fluids can share the transfer rules later, with a separate presentation and capacity model.
