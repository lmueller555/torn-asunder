# Building a unit from concept to rig

New or revised units follow the [visual asset quality gate](asset-quality-gate.md) before they enter the repository.

The Human Heavy Infantry was the first unit we took through this process. Each milestone answered a visual question we could review before building on the result. Its endpoint was a painted, rigged soldier with two fit tests in Godot. The first gameplay animation comes after this sequence.

## 0. Research the unit and plan its animation set

Do this before modeling, rigging, authoring clips, or assigning an asset builder to do those steps. For a new unit, a revised kit, or an existing unit with incomplete animation coverage, write a short unit brief. Keep it with the unit's editable source and audit evidence; use this workflow as the central checklist rather than creating a separate policy per unit.

1. **Start with Torn Asunder.** Identify the stable unit or slot ID, faction, battlefield job, upgrade source and unlock, intended gameplay entry, formation size, and hero and command camera distances. Read the [faction roster](faction-rosters.md), [combat rules](combat.md), relevant campaign and runtime, and [visual inventory](visual-audit-inventory.md). Separate what the game runs today from prototype values, planned branches, and missing mechanics. Do not turn a reference stat or a placeholder behavior into our rules.
2. **Study the closest Kingdom Under Fire: Heroes reference.** Use the [official unit guides](https://www.kufheroes.com/eng/characters/unit_human.asp) for jobs and abilities and timestamped gameplay footage for movement, weapons, posture and formation behavior. Record the source, faction and unit, time range, camera, command, and visible action. Observe the actual deployed role, not just a Barracks portrait. If there is no direct analogue, identify the parts each reference answers. Mark an unobserved motion or rule as unobserved, not verified. Use references to understand function and timing; make original models, materials, rigs, silhouettes and motion.
3. **Make a clip and state list.** For each planned motion record its trigger, start and end pose, loop or one-shot, locomotion distance or in-place ownership, equipment contacts or attachment changes, frame or normalized time for the visible action, expected gameplay event, success and interruption exits, formation playback, and how to reproduce it in Godot. Cover ready, locomotion and turns; signature actions with windup, commit and recovery; transitions and cancellation; hit, defeat and any role-specific reactions the runtime actually uses. Include mount, flight, siege setup, stow, casting, or engineering only where appropriate. For a state with no runtime consumer, say what must be implemented before it can ship. Name the unit's main visual read from both cameras.
4. **Review the brief before making the asset.** Have someone other than the author check the evidence, required states and scope, including distances, timings, variant reuse and exceptional cases. Then build the original kit and its planned clips in Blender, export to a private Godot checkout, and verify the event is driven once by the real gameplay owner. A plausible-looking pose, placeholder fallback, or storyboard does not count as gameplay verification.

A useful brief fits five fields: **intended deployment**, **timestamped observations**, **Torn Asunder behavior**, **clip/state matrix**, and **native review cases**. For example, an Archer should have an explicit draw, release, reload, and return to ready; also test move-cancel and what the current battle actually does when it is pinned in melee. If the footage verifies a volley but not the cancel, document the cancel from our runtime or mark it as design work.

This discovery step decides **what** to build. It does not replace the independent [visual asset quality gate](asset-quality-gate.md), which decides whether the exact source, export, clips, and intended gameplay use can ship. Failed or incomplete candidates stay private and out of approved gameplay until corrected and re-reviewed.

## 1. Agree on the design from several angles

We started with a standing heavy foot soldier in mail, a nasal helmet and a blue surcoat, carrying a round metal shield and a sword. Six approved views covered the front, back, both sides and two three-quarter angles. We aligned the reference images to one floor line and standing height, then marked landmarks such as the crown, belt and hems. That gave the artist something more precise to build against than a single illustration. [Concept sheet](../assets/source/heavy_infantry/reference/approved-concept.png) · [Proportion guide](../assets/source/heavy_infantry/reference/proportion-guide.png)

## 2. Approve the silhouette in neutral clay

We built a new body and kit around the concept. The review compared the reference and clay figure at the same height, rotated the model through 360°, and reduced it to 96 pixels tall to approximate battle distance. We also inspected the hand behind the shield. A convincing front view could still conceal a misplaced grip or a shield that only worked from one angle. [Concept beside clay](../assets/source/heavy_infantry/review/concept-and-clay.png) · [Grip and silhouette study](../assets/source/heavy_infantry/review/details.png)

## 3. Sculpt how the kit is constructed and worn

With the proportions approved, we worked on how the coif gathers under the jaw, how the mail and padding fit beneath the shoulder edges, where the belt draws in the surcoat, and how the nasal guard joins the helmet brow. We kept the blockout camera and lighting for the sculpt review so changes in shape were easy to see. The editable sculpt also became the source for baking detail onto the game model. [Matched full-body views](../assets/source/heavy_infantry/review/sculpt/full-body.png) · [Construction close-ups](../assets/source/heavy_infantry/review/sculpt/construction.png)

## 4. Build and test a paintable game mesh

We kept geometry for shapes that change the outline as the camera moves, including the nasal guard, shield rim and split skirt. Individual mail rings became baked surface detail. The face, surcoat front and shield face each received a continuous area on the texture sheet so their identifying features could be painted cleanly. The shield and full sword remained separate movable pieces.

We compared the neutral game mesh with the sculpt, inspected a UV checker for stretching, and rendered two platoons of 32 in Godot. The game mesh used 24,352 triangles per soldier and one shared material. At 96 pixels tall, its front and three-quarter silhouettes each overlapped the sculpt by more than 99%. These measurements are examples for sizing future units against their own concepts and battlefield roles. [Game mesh, UVs and formation measurements](../assets/source/heavy_infantry/game-mesh.md)

## 5. Paint the materials and review them in game

We painted the face, faded blue cloth, pale gold lion, leather, mail and shield. Dark backing made the mail links legible, and chipped blue paint exposed steel on the shield. Base color supplied the pigment, the normal map carried fine relief, and roughness and metallic values controlled how the surfaces caught the light. We reviewed the painted figure beside the neutral one, then checked the face and equipment close up and the faction colors across a formation. [Paint comparison](../assets/source/heavy_infantry/review/materials/comparison.png) · [Painted formation](../assets/source/heavy_infantry/review/materials/formation.png)

## 6. Revisit anatomy when a review exposes a problem

In the painted review, the front and back of the helmeted head looked too similar. We brought the neck 7° forward and moved the head 17 mm while keeping the gaze level. We reshaped the brow, refitted the coif under the jaw and carried the change through the shoulders and upper back. Aligned before-and-after profiles made the correction visible. For another unit, the reusable step is to address a weak pose before fitting the skeleton. The angle and offset belong to this soldier. [Profile comparison](../assets/source/heavy_infantry/review/posture/profile.png) · [Front, rear and battle-distance checks](../assets/source/heavy_infantry/review/posture/fit.png)

## 7. Fit the rig and prove it with a small motion

We fitted a dedicated Heavy Infantry skeleton to the approved body. The boots could stay planted, the shield followed the left hand, the scabbard followed the pelvis, and the sword could sit in the scabbard or in the curled right hand. We weighted the hood, overlapping sleeves and layered skirt so they moved with the joints beneath them.

Two short tests isolated different questions. **Shield Fit Test** showed the weight shift, shield lift, hold and return over four seconds. **Drawn Sword Fit** exposed the grip for inspection in a held pose. We reviewed both in **Unit Test → Humans · Heavy Infantry** and checked the shield motion on 64 soldiers with staggered playback. This was the last completed milestone before the proposed shield-ready idle. [Rig controls and Godot review](../assets/source/heavy_infantry/rig.md) · [Shield fit video](../assets/source/heavy_infantry/review/rig/shield-fit.mp4)

## What to carry into the next unit's PRs

Give each PR one question the reviewer can answer by looking at the unit. Show the last approved version beside the revision with the same pose, camera, scale and lighting. Pair a close-up of the feature under review with a view at normal battle size. Use a turntable when the question is about shape and a short in-engine clip when it is about motion or grip. Keep the editable Blender source, the Godot export once available, and the review evidence together so the next pass can start from the approved work.
