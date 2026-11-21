# Marches Crossing: Year Two battlefield graybox

Mara's [Grain on Credit](campaigns/humans.md#2-grain-on-credit) uses the separate `res://game/battlefields/marches_crossing.tscn` scene. The preview is a lit, labeled overview; it does not start a mission.

```sh
godot tests/marches_crossing_preview.tscn
godot --headless --script tests/marches_crossing.gd
```

## Tactical layout

The **360 × 310 m** valley runs north to south, with **+X east** and **−Z north**. The carts start in a sheltered west-bank staging yard. The reserve fork has room to hold infantry without blocking either route.

- **Seed-grain cart:** A **225 m** route through the northern timber bridge to the mill yard. The deck is wide enough for a cart and has rails, not tall cover. Eastern archers have clear sight of the deck and lancers have a **117 m** approach from their staging area, with room to form before they threaten the road leading off the bridge.
- **Bread-grain cart:** A **309 m** route, about **37% longer**, through the southern shallows to the town store. The bend, bank shoulder, and hedges screen the crossing from the far-bank archer position. The southern path is longer even before any mission-specific shallows movement penalty.
- The river is an obstacle outside the two marked crossings. The surrounding high ground bounds the sides of the valley; the field does not require invisible tall walls across the open lanes.

## Scene contract

Resolve these paths relative to the map instance and use marker world positions once the map joins the scene. Markers sit at foot level and face toward their suggested route where applicable. Coordinates and metadata are geometry hooks, not orders or triggers.

| Prefix under `Markers/` | Names |
| --- | --- |
| `Spawns/` | `RoyalHero`, `InfantryReserve`, `EscortArchers`, `SeedGrainCart`, `BreadGrainCart`, `RivalLancers`, `FarBankArchers` |
| `Routes/` | `ReserveFork`, `BridgeApproachWest`, `BridgeWestBank`, `BridgeDeck`, `BridgeEastBank`, `MillApproach`, `ShelteredTurn`, `FordApproachWest`, `FordWestBank`, `FordShallows`, `FordEastBank`, `StoreApproach`, `CavalryFormUp`, `CavalryChargeLane`, `CavalryIntercept` |
| `Objectives/` | `SeedGrainMillYard`, `BreadGrainStoreYard` |

The receiving markers have `yard_radius = 7.0` metadata. `FordShallows` has `route_surface = "shallows"`. The command harness can use `Rect2(-171, -146, 342, 292)` as its field bounds. Collision layer 1 is solid; layer 2 also tags walkable surfaces for the existing terrain adapter. Water shading, trails, and field strips are visual only. The scene has no actors, cart logic, triggers, combat AI, campaign registration, or final art.

The map test follows both authored routes with a 2.75 × 4.2 m cart footprint, checks the current formation movement adapter and fork clearance, and tests actual sightlines and river limits.
