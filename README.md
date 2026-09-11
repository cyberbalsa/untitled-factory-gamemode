# Untitled Factory Gamemode

An open-source sci-fi factory gamemode for Garry's Mod. Build and program contraptions with Wiremod to manufacture offerings for your overlords.

The name is pending. Your production quota is not.

## The idea

Machines perform individual operations. Players supply the sequencing, interlocks, sensing, and material transport using Wire gates and Expression 2. The factory becomes automated because you program it.

Designed for native single-player and cooperative multiplayer, with everyone on a server contributing to the same order.

## First prototype

- A blank feeder, servo press, and tribute uplink with real Wire inputs and outputs.
- Physical blanks and components that your contraptions must move between docks.
- A press sequence: load, clamp, cycle, wait for completion, release, and eject.
- Feedback signals, blocked outlets, interrupted cycles, and explicit fault recovery.
- Shared orders that grow from 10 to 15 to 20 components, eventually capped at 100, with favor awarded per order.
- Progress saved per map, separately for solo and multiplayer.
- F1 briefing, starter hardware, and an optional [E2 press controller](examples/press-controller.txt).

This is an early prototype. Hardware and blanks are free, there are no deadlines, and the machine visuals are placeholders. Automatic saving of contraptions and loose items is not implemented. Duplicated machines start empty; removing a loaded machine scraps its workpiece. Multiplayer is cooperative and assumes trusted builders.

## Play locally

1. Install Garry's Mod and subscribe to [Wiremod](https://steamcommunity.com/sharedfiles/filedetails/?id=160250458). Enable the addon.
2. Clone or download this repository into `GarrysMod/garrysmod/addons/untitled_factory_gamemode/`. Its `gamemodes` folder should be directly inside that addon folder.
3. Restart GMod, select **Untitled Factory Gamemode** in the main menu, and start a map. `gm_construct` or `gm_flatgrass` provides room to build.
4. Press **F1**, look at clear level ground, and request starter hardware. Alternatively run `gf_starterkit` in the console or use **Q > Entities > Untitled Factory Gamemode**.
5. Connect a Wire button to the feeder's `Dispense` input to issue a blank. Follow the briefing to operate the press, then replace manual controls with a circuit or E2 program.

On Windows, an existing checkout can be linked into the local game without copying files:

```powershell
.\tools\install-local.ps1
# For another Steam library:
.\tools\install-local.ps1 -GarrysModPath 'D:\SteamLibrary\steamapps\common\GarrysMod'
```

For a server, install this repository and Wiremod in the server's `garrysmod/addons` folder and select `+gamemode gmod_factory`. The gamemode requests Wiremod for joining clients; the server still needs its own Wiremod installation.

## Controls and development

- [Machine signals and design decisions](docs/design.md)
- [Workshop model candidates](docs/assets.md)
- [GLua and debugging notes from Luctus](docs/glua-notes.md)
- [Current editors, debuggers, and profilers](docs/development-tools.md)
- [Earlier factory projects](docs/prior-art.md)
- [Contributing](CONTRIBUTING.md)

`sbox_maxgf_machines` defaults to 24 machines per player. `gf_max_stock` defaults to 128 loose items across the server. Full outlets and the stock limit block further output until space is available. Command inputs require a new zero-to-positive edge; `Clamp` is held continuously.

Run the Lua 5.1 rules and syntax checks:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m pytest -q
```

These checks do not simulate Source physics, rendering, or remote clients. See the in-game test procedure in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Our code is [MIT licensed](LICENSE). Garry's Mod, Wiremod, and third-party Workshop assets retain their own licenses. Workshop models are referenced as dependencies and are not redistributed by this repository.
