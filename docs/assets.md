# Workshop model candidates

The prototype currently uses stock GMod models. The following candidates were found in the downloaded Workshop packs. Model paths were verified from the archive directories; appearance and collision suitability still need in-game review.

| Pack | Candidate models | Possible uses |
| --- | --- | --- |
| [Sci-fi Props Megapack](https://steamcommunity.com/sharedfiles/filedetails/?id=284266415) | `models/lt_c/sci_fi/generator_portable.mdl`, `models/lt_c/sci_fi/detector.mdl` | Power plant; inspection/processing station |
| [Sci-fi Props Megapack](https://steamcommunity.com/sharedfiles/filedetails/?id=284266415) | `models/lt_c/sci_fi/am_container.mdl`, `models/lt_c/sci_fi/dm_container_small.mdl`, `models/lt_c/sci_fi/box_crate.mdl` | Material feed, storage, shipping |
| [Sci-fi Props Megapack](https://steamcommunity.com/sharedfiles/filedetails/?id=284266415) | `models/lt_c/holo_wall_unit.mdl`, `models/lt_c/holo_keypad.mdl`, `models/lt_c/holograms/console_hr.mdl` | Overlord terminal and machine interfaces |
| [Mobile Computers](https://steamcommunity.com/sharedfiles/filedetails/?id=213181442) | `models/lt_c/tech/tablet_civ.mdl`, `models/nirrti/tablet/tablet_sfm.mdl` | Handheld diagnostics and work orders |
| [Sci-Fi Briefcase](https://steamcommunity.com/sharedfiles/filedetails/?id=156044709) | `models/ugc/76561197972497202/sci_fi/briefcase.mdl` | Finished shipment or component carrier |
| [Sci-fi Shuttle](https://steamcommunity.com/sharedfiles/filedetails/?id=259383381) | `models/lt_c/sci_fi/container_rigged.mdl`, `models/lt_c/sci_fi/shuttle/shuttle_static.mdl` | Cargo pickup and delivery scenery |

The Megapack contains 82 model entries and is the strongest initial machine-prop candidate. The Dead Space 2 station, Stelliferous, Skyport, Ganymede crater, and Ulysses downloads are map candidates; their GMA directories contained no standalone `.mdl` entries. Models may also be embedded inside maps, which this inventory does not inspect.

Keep Workshop content external to the MIT-licensed code. Before choosing a required pack, record its creator and dependency requirements from the original listing. Referencing a Workshop path does not change that asset's license.

To refresh a local inventory without extracting the assets or executing addon code:

```powershell
python tools/catalog_workshop.py 'C:\Program Files (x86)\Steam\steamapps\workshop\content\4000' --output .cache/workshop-assets.json
```

The script supports GMA archives and LZMA-compressed legacy Workshop archives. The generated local inventory is ignored by Git.
