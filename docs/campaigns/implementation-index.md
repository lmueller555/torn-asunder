# Campaign implementation index

Six campaign specs cover 18 planned missions across ten battlefield layouts. For narrative order and the six briefs, see the [five-year war timeline](../war-timeline.md#six-campaign-windows). Mission IDs below are stable design IDs, not scene paths or a list of levels available from the Campaign Vault.

## What exists

- The [Year One Mine graybox](../year-one-mine-map.md) has shared terrain, collision and spawn, route and objective markers. Its preview and tests check the layout and individual clearance, not enemy behavior or formation navigation. The separate [Human escort objective model](../../game/battlefield/mine_escort_objective.gd) tracks pickup, delivery and defeat.
- The [command harness](../../game/battlefield/command_harness.tscn) demonstrates hero movement and live formation move/hold orders with camera switching, on a separate test field. It is not a scenario controller or a playable mine mission.
- The Campaign Vault opens and saves leader briefings. The [profile store](../../game/profile_store.gd) can persist explicit mission clears but does not launch missions. The Vault's drills are not story missions. All nine other battlefield layouts and the 18 campaign mission integrations are planned. Do not infer a playable campaign from a preview, test harness, or objective model.

## Battlefield inventory

| Layout and status | Mission IDs | Shared geography or implementation focus |
|---|---|---|
| **Year One Mine** · Graybox and Human objective model exist; scenarios planned | `mara_mine_escort`, `orc_mine_witness`, `sova_mine_tunnels` | One map and opening clash. Haul road and east pass for the bridle; ridge approaches for coverage and interception; tunnel, outlet and western trail for the miners. The Orc rally is separate from Druid safety. |
| **Marches crossing** · Planned | `mara_grain_crossing` | Two carts at a road fork; short exposed bridge and screened ford lead to separate receiving yards. |
| **Moonwash harbor** · Planned | `mara_moonwash_quay`, `ilyra_moonwash_rescue` | One post-rise layout. Exposed walls, moorings, lower quay, stairs and upper exit stay fixed. Humans withdraw uphill while Elves transfer crews at water level. |
| **Moonwash survey shore** · Planned | `ilyra_coast_survey` | Ancestral stone and working inlet; beach and headland signal points serve the cutter's loop. Separate from the battle at the harbor. |
| **Red Basin well road** · Planned | `orc_well_road` | Open salt road and winding wash offer different cover and charge lanes for the well carts. |
| **Spanwater Lock** · Planned | `orc_spanwater_release`, `neris_spanwater_feeder`, `ilyra_spanwater_evacuation` | One lock and water-release event. Shared causeway, old riverbed and crossing, spillway controls, separate sea gate, feeder branch and maintenance path, and low landing and boat exit. |
| **Isolated grove and town nursery** · Planned | `neris_failing_grove` | Loading yard and raised sled road, with a sunken approach and a separate nursery receiving area. |
| **Cairnspine assembly and vault road** · Planned | `sova_public_record`, `sova_vault_return`, `neris_cairnspine_passage`, `sereth_no_proxy` | Reuse the assembly as the Year Two hearing venue and Year Five staging area. The three final views share the narrow shelf, side path, forecourt, witness terrace and vault; the Year Two hearing is a separate event confined to the assembly. |
| **Still Kingdom cut and village** · Planned | `sereth_voices_at_the_cut` | Cemetery stair, road, screened lanes and record room; a living clerk and recoverable records are distinct objectives. |
| **Cairnspine boundary post** · Planned | `sereth_pass_writ` | Road and sunken track lead to a Keeper boundary post; a courier and mounted reserve make this a separate approach, not a second vault map. |

## Shared-event checks

- **Mine:** The bridle exits east in Human custody; Druids evacuate the miners through the tunnels; one miner voluntarily goes with Raska once the others clear the outlet. Pickup and departure, worker safety, and the witness's agreement are separate objective states.
- **Moonwash:** The same rising harbor displaces the ships. The Human upper exit never requires completing the Elven rescue, and the Elven receiving deck never requires blocking or fighting the Human withdrawal.
- **Spanwater:** Raska opens the spillway to the riverbed and keeps the sea gate shut. The Dryads can establish flow at the town gauge while Ilyra's loaded launches depart the low landing. The later handover to Sova is not a fourth combat objective.
- **Cairnspine:** Neris delivers people to the terrace, Sereth stops his court's bid before its custody line, and Sova closes the vault without a new command. Keep the terrace and closure zone distinct. A view can stage the other outcomes in the background or debrief; it must not depend on mission saves from another campaign.
