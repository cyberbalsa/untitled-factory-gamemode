# Prior work: GMod factory gamemode

Research date: 2026-09-11.

Target concept: a sci-fi factory gamemode playable alone or with other players. Players use Wiremod to automate machines and contraptions, manufacture goods, and meet demands from their overlords.

## Findings

Related projects exist. The closest factory gamemode found is **Factories - Beta**. **FactoryRP** is another direct precedent, while **Spacebuild** provides relevant sci-fi resource systems. None of the sources checked established the complete combination of required Wiremod automation, overlord production quotas, and native single-player/co-op support.

The project workspace was empty when inspected and was not a Git repository. No existing gamemode implementation was found there.

### Factories - Beta

- [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=1096820835)
- [Source repository](https://github.com/Luabee/Factories)
- Released in 2017. The Workshop author explicitly says support has ended.
- The README describes assembly lines, three research trees, extensible items/recipes/technologies, and permission-controlled collaboration on player factories.
- The source tree contains miners, furnaces, assemblers, conveyors, inserters, labs, inventory, saving, and grid-placement systems. The assembler source implements ingredient consumption and recipe progress.
- The README advertises solo and multiplayer play, but the Workshop instructions specifically say native single-player does not work: playing alone requires a LAN server. The Workshop also requires `gm_flatgrass`. Treat that as an unresolved compatibility limitation until tested.
- No explicit license file appeared in the repository tree, and GitHub's repository API returned no detected license. The Workshop invites someone to continue the project, but an explicit reuse license was not located.
- Assessment: the strongest production-chain reference. Its custom factory/grid systems would need evaluation before adapting them to freeform Wiremod contraptions.

### FactoryRP

- [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2078237272)
- [Creator's announcement](https://www.reddit.com/r/gmod/comments/ga1ov8/check_out_my_gamemode/)
- The Workshop describes a demo, version 0.26, with an update entry dated May 19, 2020.
- Its premise is building factories and buying/selling goods. The documented demo lets players mine stone and process it in a machine.
- More machines, items, and recipes are described as planned for version 0.3; their availability was not verified.
- The page lists Counter-Strike: Source and Half-Life 2 as requirements.
- Assessment: a direct economic/gameplay precedent, but the inspected sources do not establish required Wiremod automation, a sci-fi quota system, or a reusable source repository.

### Spacebuild

- [Source repository](https://github.com/spacebuild/spacebuild)
- [Official Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=693838486)
- [Resource distribution implementation](https://github.com/spacebuild/spacebuild/blob/master/lua/caf/addons/server/resourcedistribution.lua)
- [Resource node implementation](https://github.com/spacebuild/spacebuild/blob/master/lua/entities/resource_node/init.lua)
- A sci-fi construction project with resource distribution and resource-node systems. The inspected resource-node code includes Wiremod duplication/restoration integration.
- The repository declares Apache-2.0 licensing. Its README asks users to use the official Workshop distribution instead of reuploading it.
- Assessment: useful reference for resource networks and Wiremod integration. The checked sources do not describe the requested factory-quota progression loop.

### Wiremod and Advanced Duplicator 2

- [Wiremod source and installation links](https://github.com/wiremod/wire)
- [Wiremod documentation](https://github.com/wiremod/wire/wiki)
- [Advanced Duplicator 2](https://github.com/wiremod/advdupe2)
- Wiremod supplies entities that communicate through wires and supports automatic and player-controlled contraptions. Its README links Advanced Duplicator 2 as a companion addon.
- Wiremod declares Apache-2.0 licensing. GitHub reported a repository push on September 9, 2026, providing evidence of recent activity.
- Assessment: use Wiremod as the automation dependency. Evaluate duplication support separately from progression/world saving; duplication alone should not be assumed to preserve a factory campaign.

## Recommended direction

Start a new gamemode derived from Sandbox, with Wiremod as a required dependency. Use Factories as a production-design reference and Spacebuild as a resource-network reference. This is an implementation recommendation, not a tested compatibility result.

The distinguishing gameplay should be:

1. Machines expose useful Wire inputs and outputs, so player-built control systems matter.
2. Manufacturing and delivery satisfy escalating overlord contracts.
3. One simulation and progression model supports native single-player and cooperative multiplayer.
4. Physics contraptions remain useful for handling and transporting goods.

## Scope and limitations

This was a public-source discovery and static inspection pass, not an in-game test or exhaustive catalog. No third-party project was installed, executed, or copied into this workspace. Current playability remains unverified.

Kagi discovery was attempted once but returned a quota-exhaustion error. Research continued through native web search, original Workshop pages, GitHub repositories, and the public GitHub API.
