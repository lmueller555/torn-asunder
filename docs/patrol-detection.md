# Patrol detection policy

`game/battlefield/patrol_detection_policy.gd` is a standalone decision model for a patrol or sentry. It does not control an existing mission, know the map, choose routes, or resolve damage. Each scene provides its own finite sight range, pursuit leash, and last-seen memory duration. The mine's minimap spotting distance is a separate UI rule, not a default for this model.

1. Supply the unit's position, its authored patrol/guard intent and leash anchor, and living eligible observations. An observation can be unobstructed only if that patrol actually has line of sight through the battlefield's terrain. The returned visible contacts are **only** current eligible observations inside sight range with that clear line.
2. Visible contacts inside the leash can interrupt the authored intent. The model retains its eligible pursued contact, otherwise takes the closest eligible contact with a stable tie rule. `ENGAGE` also requires a separate combat-supplied melee reach observation. Being visible is not permission to strike.
3. When sight is lost, the returned investigation position is the last **seen** point, never a supplied hidden coordinate. The current visible-contact list does not include memory. Expiry or leaving the leash returns the original patrol/guard intent; the movement controller can resume its existing waypoint rather than restarting the route.
4. A scenario may call `assign_interception` with a fixed authored position. That explicit march can exceed the patrol leash but never uses a player's hidden position. Once the movement controller reports arrival or blockage, or the script cancels it, ordinary detection resumes.

An inactive or defeated patrol should not receive further battle observations. The movement adapter still owns reachability, collision, and what happens when an autonomous pursuit meets solid cover. None of these decisions forces a path, attack, or teleport.

Run `godot --headless --script tests/patrol_detection_policy.gd`.

## Standard enemy aggro

The shared proximity trigger is **50 m**, inclusive, in world units. Generic mission layouts do not multiply it with map scale. Enemies still need an unobstructed view through opaque terrain: water alone does not block sight. An authored group with proximity aggro disabled is still passive unless the scenario issues an order. Skirmish target acquisition uses 50 m while its close engagement and attack distances are unchanged.

Seeing and targeting an opponent does not grant attack reach or permission to leave a scripted position:

- The Greyhollow campaign guard locks on, turns to identify the threat, and holds its post unless the target enters its local chase boundary. The original rescue and civilian triggers are separate. The corresponding practice guard can pursue at the full detection range.
- High Quay can spot and react to a target at 50 m with clear sight, but the levy follows its authored patrol and only pursues within its 18 m territory. It does not trigger the combat camera without physical contact.
- The Pass Writ's hostile sentry alarm uses 50 m, clear sight, and the existing warning delay. The separate courier and yard requirements are unchanged.

The 48 m map spotting setting and weapon/ability reach are not aggro. Run `tests/enemy_aggro_radius.gd` and `tests/authored_enemy_aggro.gd` after normal Godot import to test the exact boundary and scenario constraints.
