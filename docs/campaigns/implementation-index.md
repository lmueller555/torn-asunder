# Campaign implementation index

Six campaign routes cover 18 chapters across ten battlefield layouts. For narrative order and the six briefs, see the [five-year war timeline](../war-timeline.md#six-campaign-windows). Mission IDs below are stable design IDs, not scene paths. The lists distinguish active campaign routes from standalone playtests.

## Development playtests

All 18 missions across the six campaigns are deployable from the Campaign Vault in the development build. These playtests still use [unapproved placeholder art](../visual-audit-inventory.md). A **campaign route** launches a mission from the Campaign Vault after travelling and confirming its briefing. A **standalone playtest** runs from its Godot scene but does not record a campaign clear. A **graybox** is a battlefield layout, not a playable mission on its own.

- **Humans (Mara):** Get Them Out → Grain on Credit → The High Quay (all Year Three).
- **Orcs (Raska):** One Person to Ask → The Second Bucket (both Year Three) → River, Not Sea (Year Four).
- **Druids (Sova):** The Workers' Way Out → Let Them Walk Out (both Year Three) → No New Command (Year Five).
- **Elves (Ilyra):** Hulls on Stone → Two Shorelines (both Year Three) → Last Boat at Spanwater (Year Four).
- **Dryads (Neris):** What We Planted Here (Year One) → Where the Road Goes (Year Two) → Greyhollow (Year Three). The feeder and vault-road prototypes remain available separately.
- **Undead (Sereth):** The Names at the Cut → An Audience, Not a Seizure → The Lamp in the Window.

The [profile store](../../game/profile_store.gd) records waypoint arrivals separately from mission clears. First-result saves for branching missions are not rewritten by replay. The separate travel and deployment steps follow the [original *Kingdom Under Fire: Heroes* manual, pp. 20–21](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf#page=12).

## Battlefield inventory

| Layout and status | Mission IDs | Shared geography or implementation focus |
|---|---|---|
| **Greyhollow mines** · Four campaign deployments on the stock `year_one_mine` battlefield | `mara_mine_escort`, `neris_greyhollow`, `orc_mine_witness`, `sova_mine_tunnels` | Two events: the Human–Dryad rescue and the later Orc–Druid departure. The Human rescue runs through the south tunnel to western safety; the Orc rally is separate from Druid safety. The technical ID does not date the story. |
| **Marches crossing** · Routed Grain escort prototype with reserve interdiction | `mara_grain_crossing` | Two carts at a road fork; short exposed bridge and screened ford lead to separate receiving yards. |
| **Moonwash harbor** · Both perspectives routed | `mara_moonwash_quay`, `ilyra_moonwash_rescue` | One post-rise layout. Exposed walls, moorings, lower quay, stairs and upper exit stay fixed. Humans withdraw uphill while Elves transfer crews at water level. |
| **Moonwash survey shore** · Ilyra survey routed | `ilyra_coast_survey` | Ancestral stone and working inlet; beach and headland signal points serve the cutter's physical loop. See [standalone launch and controls](../moonwash-survey-shore-graybox.md#standalone-two-shorelines-prototype). |
| **Red Basin well road** · Raska's second mission routed | `orc_well_road` | Open salt road and winding wash offer different cover and charge lanes for the well carts. |
| **Spanwater Lock** · Orc and Elven routes; Dryad feeder standalone | `orc_spanwater_release`, `ilyra_spanwater_evacuation`; standalone `neris_spanwater_feeder` | One lock and water-release event. Shared causeway, old riverbed and crossing, spillway controls, separate sea gate, feeder branch and maintenance path, and low landing and boat exit. |
| **Isolated grove and town nursery** · Neris opener routed | `neris_failing_grove` | Loading yard, raised sled road, sunken approach, and separate nursery receiving area. |
| **Cairnspine assembly and vault road** · Druid and Undead routes; Dryad passage standalone | `sova_public_record`, `sova_vault_return`, `sereth_no_proxy`; standalone `neris_cairnspine_passage` | Reuse the assembly for the separate Year Three hearing and the Year Five events. The vault-road views share the narrow shelf, side path, forecourt, and witness terrace. |
| **Still Kingdom cut and village** · Sereth opener routed | `sereth_voices_at_the_cut` | Cemetery stair, road, screened lanes and record room; a living clerk and recoverable records are distinct objectives. |
| **Cairnspine boundary post** · Dryad survey and Undead writ routes | `neris_cairnspine_survey`, `sereth_pass_writ` | The Dryads physically survey the road and sunken track in Year Two. The later Undead mission uses the same post for its courier and mounted reserve. |

## Shared-event checks

For in-battle conditions, see the [mission event authoring guide](mission-events.md).

- **Greyhollow:** The Humans rescue the miners under Dryad attack, then see “What They Brought Out.” The Dryads can cover their retreat, not deny Human access to the bridle. Later, Sova gets the workers away and a miner voluntarily goes with Raska after the others clear the outlet. Neither battle depends on clears in another campaign.
- **Moonwash:** The same rising harbor displaces the ships. The Human upper exit never requires completing the Elven rescue, and the Elven receiving deck never requires blocking or fighting the Human withdrawal.
- **Spanwater:** Raska opens the spillway to the riverbed and keeps the sea gate shut. The Dryads keep the town feeder working in shared history and in their standalone playtest, while Ilyra's loaded launches depart the low landing. The later handover to Sova is not a fourth combat objective.
- **Cairnspine:** Neris delivers people to the terrace in shared history and in her standalone playtest. Sereth stops his court's bid before its custody line, and Sova closes the vault without a new command. Keep the terrace and closure zone distinct. A view can stage the other outcomes in the background or debrief; it must not depend on mission saves from another campaign.
