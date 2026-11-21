# Campaign implementation index

Six campaign specs cover 18 planned missions across ten battlefield layouts. For narrative order and the six briefs, see the [five-year war timeline](../war-timeline.md#six-campaign-windows). Mission IDs below are stable design IDs, not scene paths or a list of levels available from the Campaign Vault.

## What you can play

A **campaign route** launches a mission from the Campaign Vault after travelling and confirming its briefing. A **standalone playtest** runs from its Godot scene but does not record a campaign clear. A **graybox** is a battlefield layout, not a playable mission on its own.

- **Humans (Mara):** The Pass Below the Mine → Grain on Credit → The High Quay.
- **Orcs (Raska):** One Person to Ask → The Second Bucket → River, Not Sea.
- **Druids (Sova):** The Workers' Way Out → Let Them Walk Out. [Vault Road](../../game/battlefield/sova_vault_return_playtest.tscn) has a standalone playtest.
- **Elves (Ilyra):** Hulls on Stone. Two Shorelines is playable as a standalone scene, not yet deployable from the next waypoint.
- **Dryads (Neris):** [What We Planted Here](../../game/battlefield/neris_failing_grove_playtest.tscn) is a standalone playtest with separately authored dispatch and debrief.
- **Undead (Sereth):** The Still Kingdom Cut graybox and opening objective rules exist; neither is a routed mission.

The [profile store](../../game/profile_store.gd) records waypoint arrivals separately from mission clears. First-result saves for branching missions are not rewritten by replay. The separate travel and deployment steps follow the [original *Kingdom Under Fire: Heroes* manual, pp. 20–21](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf#page=12).

## Battlefield inventory

| Layout and status | Mission IDs | Shared geography or implementation focus |
|---|---|---|
| **Year One Mine** · All three opening views reachable from their campaign maps | `mara_mine_escort`, `orc_mine_witness`, `sova_mine_tunnels` | One map and opening clash. Haul road and east pass for the bridle; ridge approaches for coverage and interception; tunnel, outlet and western trail for the miners. The Orc rally is separate from Druid safety. |
| **Marches crossing** · Routed Grain escort prototype with reserve interdiction | `mara_grain_crossing` | Two carts at a road fork; short exposed bridge and screened ford lead to separate receiving yards. |
| **Moonwash harbor** · Both perspectives routed | `mara_moonwash_quay`, `ilyra_moonwash_rescue` | One post-rise layout. Exposed walls, moorings, lower quay, stairs and upper exit stay fixed. Humans withdraw uphill while Elves transfer crews at water level. |
| **Moonwash survey shore** · Standalone playtest; deployment not routed | `ilyra_coast_survey` | Ancestral stone and working inlet; beach and headland signal points serve the cutter's physical loop. See [standalone launch and controls](../moonwash-survey-shore-graybox.md#standalone-two-shorelines-prototype). |
| **Red Basin well road** · Raska's second mission routed | `orc_well_road` | Open salt road and winding wash offer different cover and charge lanes for the well carts. |
| **Spanwater Lock** · Raska finale routed; Elf and Dryad scenarios not deployable | `orc_spanwater_release`, `neris_spanwater_feeder`, `ilyra_spanwater_evacuation` | One lock and water-release event. Shared causeway, old riverbed and crossing, spillway controls, separate sea gate, feeder branch and maintenance path, and low landing and boat exit. |
| **Isolated grove and town nursery** · Standalone playtest | `neris_failing_grove` | Loading yard, raised sled road, sunken approach, and separate nursery receiving area; dispatch/debrief are authored, not routed. |
| **Cairnspine assembly and vault road** · Sova hearing routed; Vault Return standalone | `sova_public_record`, `sova_vault_return`, `neris_cairnspine_passage`, `sereth_no_proxy` | Reuse the assembly as the Year Two hearing venue and Year Five staging area. The three final views share the narrow shelf, side path, forecourt, witness terrace and vault; the Year Two hearing is a separate event confined to the assembly. |
| **Still Kingdom cut and village** · Graybox and opening objective rules | `sereth_voices_at_the_cut` | Cemetery stair, road, screened lanes and record room; a living clerk and recoverable records are distinct objectives. |
| **Cairnspine boundary post** · Planned | `sereth_pass_writ` | Road and sunken track lead to a Keeper boundary post; a courier and mounted reserve make this a separate approach, not a second vault map. |

## Shared-event checks

For in-battle conditions, see the [mission event authoring guide](mission-events.md).

- **Mine:** The bridle exits east in Human custody; Druids evacuate the miners through the tunnels; one miner voluntarily goes with Raska once the others clear the outlet. Pickup and departure, worker safety, and the witness's agreement are separate objective states.
- **Moonwash:** The same rising harbor displaces the ships. The Human upper exit never requires completing the Elven rescue, and the Elven receiving deck never requires blocking or fighting the Human withdrawal.
- **Spanwater:** Raska opens the spillway to the riverbed and keeps the sea gate shut. The Dryads can establish flow at the town gauge while Ilyra's loaded launches depart the low landing. The later handover to Sova is not a fourth combat objective.
- **Cairnspine:** Neris delivers people to the terrace, Sereth stops his court's bid before its custody line, and Sova closes the vault without a new command. Keep the terrace and closure zone distinct. A view can stage the other outcomes in the background or debrief; it must not depend on mission saves from another campaign.
