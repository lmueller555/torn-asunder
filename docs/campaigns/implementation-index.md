# Campaign implementation index

Six campaign specs cover 18 planned missions across ten battlefield layouts. For narrative order and the six briefs, see the [five-year war timeline](../war-timeline.md#six-campaign-windows). Mission IDs below are stable design IDs, not scene paths or a list of levels available from the Campaign Vault.

## What exists

- Mara can open the campaign map at Marches Camp, read the dispatch in Camp Operations, and travel to the Mine briefing. Only confirming deployment there opens the [campaign-scale Mine prototype](../year-one-mine-campaign-map.md). A successful delivery records the clear, opens the debrief, and unlocks travel to the road into the Marches. The linked map and separate battlefield briefing follow the structure in the [original *Kingdom Under Fire: Heroes* manual, pp. 20–21](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf#page=12).
- The [original Mine graybox](../year-one-mine-map.md) and its standalone command harness are not additional missions available from the Campaign Vault. [Moonwash](../moonwash-harbor-map.md) and [Spanwater](../spanwater-lock-map.md) have terrain grayboxes, not playable scenarios.
- The [profile store](../../game/profile_store.gd) keeps waypoint arrivals separate from mission clears. In the same overworld flow, Sova can reach his own campaign-scale Mine briefing and evacuate workers. This unlocks Cairnspine Assembly as a waypoint, not another mission. Raska can reach the same Mine on his own route and escort the willing witness, opening Basin Well Road as a waypoint. The other 15 campaign missions remain outside the playable campaign flow.

## Battlefield inventory

| Layout and status | Mission IDs | Shared geography or implementation focus |
|---|---|---|
| **Year One Mine** · All three opening views reachable from their campaign maps | `mara_mine_escort`, `orc_mine_witness`, `sova_mine_tunnels` | One map and opening clash. Haul road and east pass for the bridle; ridge approaches for coverage and interception; tunnel, outlet and western trail for the miners. The Orc rally is separate from Druid safety. |
| **Marches crossing** · Standalone logistics playtest; campaign combat planned | `mara_grain_crossing` | Two carts at a road fork; short exposed bridge and screened ford lead to separate receiving yards. |
| **Moonwash harbor** · Graybox exists; scenarios planned | `mara_moonwash_quay`, `ilyra_moonwash_rescue` | One post-rise layout. Exposed walls, moorings, lower quay, stairs and upper exit stay fixed. Humans withdraw uphill while Elves transfer crews at water level. |
| **Moonwash survey shore** · Planned | `ilyra_coast_survey` | Ancestral stone and working inlet; beach and headland signal points serve the cutter's loop. Separate from the battle at the harbor. |
| **Red Basin well road** · Planned | `orc_well_road` | Open salt road and winding wash offer different cover and charge lanes for the well carts. |
| **Spanwater Lock** · Graybox exists; scenarios planned | `orc_spanwater_release`, `neris_spanwater_feeder`, `ilyra_spanwater_evacuation` | One lock and water-release event. Shared causeway, old riverbed and crossing, spillway controls, separate sea gate, feeder branch and maintenance path, and low landing and boat exit. |
| **Isolated grove and town nursery** · Planned | `neris_failing_grove` | Loading yard and raised sled road, with a sunken approach and a separate nursery receiving area. |
| **Cairnspine assembly and vault road** · Planned | `sova_public_record`, `sova_vault_return`, `neris_cairnspine_passage`, `sereth_no_proxy` | Reuse the assembly as the Year Two hearing venue and Year Five staging area. The three final views share the narrow shelf, side path, forecourt, witness terrace and vault; the Year Two hearing is a separate event confined to the assembly. |
| **Still Kingdom cut and village** · Planned | `sereth_voices_at_the_cut` | Cemetery stair, road, screened lanes and record room; a living clerk and recoverable records are distinct objectives. |
| **Cairnspine boundary post** · Planned | `sereth_pass_writ` | Road and sunken track lead to a Keeper boundary post; a courier and mounted reserve make this a separate approach, not a second vault map. |

## Shared-event checks

For in-battle conditions, see the [mission event authoring guide](mission-events.md).

- **Mine:** The bridle exits east in Human custody; Druids evacuate the miners through the tunnels; one miner voluntarily goes with Raska once the others clear the outlet. Pickup and departure, worker safety, and the witness's agreement are separate objective states.
- **Moonwash:** The same rising harbor displaces the ships. The Human upper exit never requires completing the Elven rescue, and the Elven receiving deck never requires blocking or fighting the Human withdrawal.
- **Spanwater:** Raska opens the spillway to the riverbed and keeps the sea gate shut. The Dryads can establish flow at the town gauge while Ilyra's loaded launches depart the low landing. The later handover to Sova is not a fourth combat objective.
- **Cairnspine:** Neris delivers people to the terrace, Sereth stops his court's bid before its custody line, and Sova closes the vault without a new command. Keep the terrace and closure zone distinct. A view can stage the other outcomes in the background or debrief; it must not depend on mission saves from another campaign.
