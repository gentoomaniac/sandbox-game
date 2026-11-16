# Architecture refactor: progress check — 2026-11-16

## Verdict

Real architectural progress: the save, flood and chest boundary repairs are substantive.
At `f6790fe7`: **8 done, 5 partly done, 6 not started**; #121 landed during review, bringing main to **9 / 5 / 5**.
Several splits remove independent reasons to edit the old owner; art registration and object-state validation remain incomplete seams.
Continue, but judge the next work by extension paths and preserved invariants, not file length.

## Scope and how to read the statuses

Compared the original review's baseline `6083e770` with main **`f6790fe7`**: 105 commits, including
the review's own commit, #109's remaining UI work and the word-rating test fix. Read the range's
`git log --stat`, relevant `git show` patches, current implementations and tests, and the issue
bodies/comments for #110–#123 and #125–#128. All those issues were still OPEN when read;
implementation status below follows the code and merge comments, not the issue checkbox/state.

Also read `git diff main...worktree-agent-adc7e1a9f13a71d43`, whose observed tip was
**`ec143247`**. References marked **[121]** mean that revision, not main. Its final GameState is
**265 lines**, rather than the brief's 267; at `f6790fe7` it is 995. #124's branch was deliberately
skipped. Other file:line references below mean `f6790fe7`. Source assessments are not fresh runtime results.

**Final-verification update:** main advanced to that same inspected **`ec143247`** while this report
was being written: #121's nine commits are now merged, making 114 commits since the baseline.
F13's final status and the final source census below include that landing. The other findings'
statuses are unchanged. This timing update does not include any #124 work.

“Done” means the original responsibility/boundary problem is addressed, not that every surrounding
API or test is flawless. “Partly done” identifies a remaining part of the original acceptance
criterion. The remaining-plan section carries both those remainders and newly exposed problems.

## 1. Per finding

### F01 — Cart prices and save validation: **done** (#49; then #116/#117)

`2abc1fa4` repaired the actual unloadable-save representation, in the proposed direction: nested
prices are checked, not simply exempted. The resulting checks are now
`game/state/save_checks/save_object_checks.gd:176–179,194–215`: non-negative whole till, price
dictionary, non-negative integer-text slot key, item text and whole positive price, with removed
items using the missing-content path. `SalesCart.price_of`, `game/state/sales_cart.gd:47–54`,
still associates a price with its original item.

The public-load regression and malformed-state cases in `tests/test_save_validation_cart.gd:22–61`
exercise READY/refusal/drop-missing; the feature round-trip now also uses the real loader
(`tests/test_sales_cart.gd:89–98`). This is a sound repair. Extending object-state checks remains
F12; it does not invalidate this specific fix.

### F02 — Scene-owned flood stepping: **done** (#111; play-loop extraction in #113)

`3b77e994` follows the proposal. `SurgeFlow` only connects notifications
(`game/scenes/surge_flow.gd:11–26`); `SurgeUpkeep.frame_work` advances the water
(`game/state/surge_upkeep.gd:27–28`). `PlayLoop.begin_frame` calls clock ticking and state frame
work once (`game/scenes/play_loop.gd:46–48`), and `Simulation.frame_work` refuses ordinary work
while a skip is spreading (`game/state/simulation.gd:41–45`). The console freeze gate is in
GameState, retained at **[121]** `game/state/game_state.gd:99–104`.

Rate, tile budget, final settled water, freeze, indoors and skip behavior have meaningful source
coverage in `tests/test_frame_work.gd:42–112`. There is no separate blackout-driver test there;
the source path deliberately permits frame work under black and gates calendar time separately.
That is the documented policy, not an accidental second clock. Keep this single state entry point.

### F03 — State importing TerrainTileset: **done** (#115)

Both suggested repairs landed (`66ba18e0`, `f8fb8cfb`). NpcSpeech converts the camera region and
head clearance to tiles (`game/scenes/npc_speech.gd:79–91`); NpcBubbles takes tile coordinates
(`game/state/npc_bubbles.gd:23–26,49–58`). Tide owns tile-point relief conversion and uses it for
its own heights (`game/state/tide.gd:59–62,84`); SeaSearch uses that query
(`game/state/sea_search.gd:75`). No state script still names TerrainTileset.

Sound and small. Tide still uses the existing state-side `WildlifeRules.TILE_SIZE`; that is an
odd home for shared scale, but it is not a new scene dependency or a reason to reopen this repair.

### F04 — The closing chest window creates theft: **done** (#112)

`985f1bd1` implements immediate committed taking, explicitly changing the old net-per-visit
policy: returning goods does not erase what a witness saw. `ChestTransfers` performs the move
and reports its actual reduction (`game/state/chest_transfers.gd:19–56`); the screen routes
drag, Shift and chest-trash through it (`game/scenes/storage_screen.gd:123–143`). Closing only
disconnects and releases UI ownership (`83–87`). The old signal/Main/GameState forwarding path
is gone. The operation is usable without a window.

`tests/test_storage_taken.gd:74–162` covers swaps, refusal, returns, witness timing and a real
save before closing. Its chest is a synthetic object, not installed in the world's edit store
(`28–29`), so that last test proves persisted theft/opinion, not persisted chest contents.
That is useful coverage, but do not cite it as a complete chest/inventory persistence scenario.

One API limit remains: ChestTransfers captures a chest and the game, not its map
(`game/state/chest_transfers.gd:13–16,56`); reporting uses the player's current map. Existing UI
callers keep those identities together. A future remote/asynchronous transfer must carry or
validate map identity rather than treating this operation as safe for arbitrary chests.

### F05 — Copied backpack columns: **done** (#119)

`d8c48e22`, `2635c2fd`, `7e497472` follow the composition proposal. BackpackGrid owns construction,
slot binding, quick-move forwarding, hotbar acquire/release and dimming
(`game/scenes/backpack_grid.gd:28–83`). Campfire, process and storage screens all use it; their
domain-specific transfer rules remain local. In particular, the station still goes through
ProcessStation (`game/scenes/process_screen.gd:169–189`), while chest moves go through
ChestTransfers.

This removes a real growth path. `bind`/`refresh`/`unbind` is an explicit, paired lifecycle;
screen open/close hooks still own their subscriptions. Do not add another binding abstraction
just to remove those few hooks. Public `views` (`backpack_grid.gd:21–22`) exposes the component's
mutable construction index, mostly for tests; prefer behavior-based access if production callers
ever start relying on its layout.

### F06 — Repeated art registration: **partly done** (#118; remainder belongs in #128)

`b38f8138` and `950c1cfe` establish one object-row declaration and furniture order
(`tools/art/declaration.py:18–125`). Both generators consume them. Checked merge and
missing/undeclared checks (`132–153`) are sound improvements, and duplicate-source tests are real
(`tools/art/test_declaration.py:14–32`). This follows the proposed stable-identity direction.

The promised **provider/declaration-only extension is not yet implemented for ordinary objects**.
A new family still adds drawing calls to `tools/art/generate.py:172–249` and
`tools/art/classic/generate.py:193–272`, icon contributions to `generate.py:395–414` and
`classic/generate.py:318–333`, and winter behavior elsewhere. Source names in those dictionaries
are provenance labels, not independently installed providers. The declaration's header
(`tools/art/declaration.py:4–6`) overstates the resulting workflow.

Bare redraw identities remain duplicated (`generate.py:286–297`,
`classic/generate.py:280–291`); winter-key validation is still outstanding. #128 already names
those two leftovers, but must also close object/icon provider assembly, not only split artists.

### F07 — Save tests missing the load boundary: **done** (#116)

`73941d37..dacd49f0` add `RealLoad.of` and migrate the intended feature families.
`tests/real_load.gd:12–18` writes current save text, calls `SaveFile.load_game`, requires READY
and returns the loaded state. It goes through production encoding, not a parallel envelope
implementation. Cart coverage above and `tests/test_save_surge.gd:45–56` are concrete examples.
The restored-game continuation test now loads publicly (`tests/test_save.gd:222–234`).

Keeping explicit codec tests is correct. Most were renamed accordingly. A few old world-codec
scenarios in `tests/test_save_surge.gd:59–101` and the restore normalization test in
`tests/test_farming_upkeep.gd:185–196` still lack “codec” in their names. They are not evidence
of public-load behavior, but each feature now has representative public-load coverage; no blanket
rewrite is warranted.

### F08 — Giant catalog assembly and hidden collisions: **partly done** (#110)

The major relocation is complete and good: `f2c1ab40..d001584d` move declarations to topic-sized
GDScript files, use raw IDs, share sorted export-aware enumeration, check cross-topic duplicates
with both source paths, retain derived crops/tools/trunks, and deep-freeze the result.
See `game/state/catalog_topics.gd:15–48`, `item_types.gd:214–269` and
`world_object_types.gd:245–295`. Typed GDScript declarations instead of cfg are a sensible
alternative already allowed by the review. Ordinary definitions no longer require central class
edits; compatibility ID constants are not forwarding shims.

**One collision hole remains:** `world_object_types.gd:264` merges generated snag types without
the reused-ID check used for crops and trunks. A topic defining `dead_oak` can silently win over
the generated `dead_oak` (Dictionary.merge's default keeps the existing key). The final graph
checker cannot diagnose the discarded contribution. This is a retained derivation gap, not a
claim that the new cross-topic check fails. Reserve/check all derived IDs before merging.

Also, `CatalogTopics.read_folder` checks that TYPES exists, not that it is a Dictionary
(`catalog_topics.gd:22–26`), then `merged` assumes a Dictionary and StringName keys (`39–40`).
An ill-shaped new topic can fail a typed assignment before the intended controlled catalog
diagnostics. Add shape diagnostics at this new extension boundary, alongside its existing
no-TYPES/duplicate tests (`tests/test_catalog_topics.gd:17–30`).

### F09 — Incomplete, manually maintained startup gate: **partly done** (#114)

`8a1d7f27`, `84d4455d` fix current rule-family coverage and short-circuiting. The named ordered
dictionary in `game/scenes/rules_check.gd:14–62`, followed by `all_pass` (`70–75`), is much clearer
and reports all failed checks. Main still gates state setup on the result (`main.gd:99–106`).
That is a sound first repair and a reasonable explicit-catalog choice.

It remains one central list, not topic contributions; forgetting a new family still gives no
missing-registration diagnostic. `tests/test_rules_check.gd:50–58` calls each selected callable
directly, and `61–70` tests the aggregate loop separately; neither establishes completeness for
a newly added family. The original final extensibility/coverage step is therefore not finished.
More immediately, #120 introduces discovery failures that are only logged and never enter this
gate; see §3. Fix that before building a more elaborate registration mechanism.

### F10 — New activity target kinds: **done**, with discovery follow-ups (#120)

`f60b730d`, `26888a39` supply the proposed small kind contract. Metadata, place resolution and
wild's delayed lookup now belong to targets (`game/state/activity_target.gd:8–34`;
`activity_targets/wild_target.gd:13–44`). ActivityPlaces dispatches through the rules' target
(`game/state/activity_places.gd:27–28`), so adding an implementation does not add scheduler arms.
The scheduler remains a scheduler. This is a genuine extension seam.

Two details are incomplete rather than reasons to redesign it. Church-specific searching remains
in `ActivityPlaces.church_yard_near` (`activity_places.gd:41–53`), called by a two-line target
(`activity_targets/church_target.gd:18–19`); move that policy into its target when next touched.
And the “inn” test injects an inner-class instance into a copied dictionary
(`tests/test_activity_targets.gd:10–41,55–73`): it proves scheduler extensibility, **not** that a
new script file is discovered. The exact seven-name assertion (`44–47`) also has to change when
an eighth target is added. Add a real fixture-folder discovery test; retain the useful scheduler
test under its accurate claim. The loader's lost diagnostics are a separate concrete new issue.

### F11 — Main, feature installation and page registration: **done**, with composition limits (#113/#127)

The two rounds are meaningfully complementary. `96c1181f` gives CharacterScreen one registration
point for button/page/list/on-show (`game/scenes/character_screen.gd:68–100,152–165`).
`f3041f5c..984b6f10` and `410005cd..9b24c8ee` move screen/action/sound wiring into flows and
extract PlayLoop, AimViews, WalkFlow, ClockViews and MapSwitch. Main's frame now reads as a short
ordered sequence (`game/scenes/main.gd:554–562`), and FeatureFlows builds the production/test
flows together (`game/scenes/feature_flows.gd:24–50`). The old ActionHint E-switch is gone.
This is the proposed explicit composition direction, not a generic scene loader.

Construction, tree installation and the test's `all()` list remain distinct
(`feature_flows.gd:35–57`; `main.gd:221–230,315–319`). That can be legitimate for layer order,
but the registry test proves construction, not identical production installation; see §3.
Chat/trade still intentionally route through InteractFlow and its quest voice. Do not claim
that *any* new screen is now one added file; a new interaction still needs a domain choice and
an explicit composition entry. Those are real responsibilities, not duplication of hint/open logic.

### F12 — Domain persistence ownership: **partly done** (#117; codec work in #121)

`504a1cf6..0f40d5fc` give SaveValidator a 62-line ordered orchestration role, split checks by
domain, and share primitive diagnostics, removal decisions and building-reference facts through
SaveContext. The dependency order remains explicit (`game/state/save_validator.gd:48–62`;
`save_checks/save_world_checks.gd:38–66`). Numbered migrations retain literal historical defaults
and one version sequence; the directory-continuity test checks the exact supported set
(`game/state/save_migrations.gd:12–19`; `tests/test_save_migrations.gd:6–23`). Deterministic filename
lookup plus a repository check is the proposed alternative to a manifest; it does not need
another discovery layer.

**The object-state problem was partitioned, not fully given to feature owners.** A new nested
state value must still edit both `OWN_SHAPE_STATE_KEYS` and `_state_checks` in
`game/state/save_checks/save_object_checks.gd:8–24`, and add its implementation there. If the
author registers only the checker, the preceding numeric-default loop still rejects the valid
dictionary (`119–130`): the exact mechanism behind F01 survives in a smaller file.
Dyke checks take a third, type-specific route (`54–55,183–191`); item state already delegates
to LanternCandle (`108–116`). Bring feature adapters behind one shape/check registration, retaining
explicit policy for existing numeric keys; do not make a class per save field.

World snapshot/restore and JSON assembly still enumerate features separately
(`game/state/world.gd:858–920`; `world_save.gd:41–56`). #121's GameCodec relocates session
encoding, but does not solve that World extension cost. Pair the remaining domain codec work
with #122's ownership moves. Do not repeat the completed validator/migration extraction.

### F13 — GameState responsibilities: **done at final main `ec143247`** (#121)

At the requested `f6790fe7` snapshot this was **not started**, in a 995-line GameState.
At **[121]** `ec143247`, which landed during the review, all
seven owners are present: PlayerTravel (178 lines), PlayerRest (222), GroundPickup (81),
Demolition (71), GameFactory (77), GameCodec (102) and HeldItem (58). Travel's final form is
stateless operations over PlayerState's transient riding data, rather than the intermediate
stateful travel helper. That is a sound plain-data alternative to an owned travel object.

The important part is caller migration: WalkFlow calls PlayerTravel/PlayerRest/GroundPickup,
SaveFile and LoadResult call GameCodec, and game loading calls GameFactory. There are no
compatibility forwards for the moved travel/rest/pickup/demolition/factory/codec APIs. The
existing ToolUse convenience forwards remain at **[121]** `game/state/game_state.gd:213–230`;
they predate this split and do not route the newly extracted responsibilities back through it.
Factory attachment is shared by new-game and restore (**[121]** `game_codec.gd:52–64`), so there
is one ordered system-installation path. Static operations retain no aggregate reference.

This removes several independent growth paths, not just lines. It still exposes construction
state and leaves aggregate growth for new session systems, weather queries and signals. New
public internals and the inaccurate lifetime test need attention before claiming stronger
encapsulation/lifetime coverage; details in §3. The retained public-method lint exemption is not,
by itself, evidence that this extraction failed.

### F14 — World: **not started** (#122)

No implementation change in this range. The 978-line class still owns edit maps, per-chunk
indexes and feature indexes (`game/state/world.gd:78–100`), with crop/scarecrow/campfire arms in
`_edit_object` (`940–955`), building storage/index updates (`975–978`), environmental operations
and persistence. The stated “new indexed family without another World arm” acceptance remains
entirely ahead. Extracting data while leaving those mutations in World would not meet it.

### F15 — Livestock: **not started** (#123)

Unchanged 979-line coordinator. The two priority paths remain in `game/state/livestock.gd:256–284`
and `330–360`; roosting, needs, following and movement are still implementations inside it.
The art-species split is unrelated to these state machines. #121 updates the ridden-stamina
ownership reference, but does not extract animal behavior. Keep the original concrete-owner
plan and shared RNG/order constraints.

### F16 — WorldView: **not started on main** (#124 branch excluded)

Main's `game/scenes/world_view.gd` remains the original 921-line file, unchanged in this range.
The original terrain/object/effects ownership finding therefore stands on main. No assessment
or acceptance of #124's in-progress implementation is implied here. Preserve the original
single draw-budget/settle and unload-cleanup requirements for its eventual review.

### F17 — GameSettings: **not started** (#125)

Unchanged at 780 lines. InputMap and DisplayServer are still read during construction
(`game/state/game_settings.gd:250–262`), binding/conflict mutation is still here (`322–377`),
and provider metadata remains at `112–150`. More scene flows/tests now construct GameSettings;
they still inherit that engine dependency. The proposed KeyBindings/application/provider
ownership split remains warranted; no new settings framework is needed.

### F18 — Generator and wildlife view: **not started** (#126)

Both implementations are unchanged: WorldGenerator still initializes coast/dyke/vegetation
concerns together (`game/world/world_generator.gd:228–275`) and mixes placement priorities and
species selection (`543–607`); WildlifeView still owns roof queries, the animal factory and
saved-animal presentation (`game/scenes/wildlife/wildlife_view.gd:498–667`). Existing per-animal
view/behavior scripts do not constitute the missing constructor/spawn seam. Keep the two halves
as separate work packages rather than a combined “generation and animals” abstraction.

### F19 — Independent art families: **partly done** (#118; remainder #128)

The native livestock, buildings and furniture moves follow the proposed authoring seams:
species live in `livestock_<family>.py`, houses in huts/farmhouses/hall_house, and furniture in
beds/tables_and_seats/kitchen/byre_and_store. Shared pose/material/room primitives remain in
livestock.py (312 lines), buildings.py (404) and interior.py (376). The registries are small and
understandable (`tools/art/farm_animals.py`, `houses.py`, `furnishings.py`); these are genuine
independent editing destinations, not arbitrary “part 2” files.

Character, terrain, crops, snags/seasons and classic families are substantially untouched, as
#128 records. Also, farm-animal assembly merely concatenates sheets
(`tools/art/farm_animals.py:30–33`; `generate.py:382–384`), whereas houses/furniture use checked
named contributions. Two species providers can emit the same output name and overwrite a file.
The final writer does not catch this either (`tools/art/palette.py:160–168`).
Complete the checked provider contract before multiplying the remaining registries. The range
contains no tracked generated-art changes; that supports the pure-move intent, but is not an
independent regeneration/byte-identity check by this review.

## 2. The 1000-line question

**Both things happened: responsibilities were separated, and some assembly bottlenecks were
merely relocated.** BackpackGrid, the state-owned flood path, chest operations, catalog topics,
feature flows and #121's named operations change where a future feature belongs. SaveObjectChecks
still accumulates every special object-state key; the generators still accumulate every object
provider; Main's feature construction/installation still has more than one list to maintain.

Using the original census scope—`.gd`, `.py`, `.sh` under `game/`, `tests/`, `tools/`, excluding
caches—the requested `f6790fe7` snapshot had **1,320 source files; 18 over 700 lines**, down from
25. Seven former entries fell below the threshold: WorldObjectTypes, ItemTypes, SaveValidator,
Main, native livestock.py, buildings.py and interior.py. After #121 landed at `ec143247`, the
final census is **1,328 source files; 17 over 700 lines**, listed below. GameState is now 265
lines and no longer qualifies. None is in `tests/`. No #124 reduction is counted.

| Current file | Lines | Remaining reason to grow / disposition |
|---|---:|---|
| `game/state/livestock.gd` | 979 | Yes: each behavior edits live and skip paths plus shared movement/needs bookkeeping. #123 still needed. |
| `game/state/world.gd` | 978 | Yes: indexed families, edits, buildings, environment and serialization. #122 is the highest-value remaining state ownership split. |
| `game/scenes/world_view.gd` | 921 | Yes on main: terrain, objects, special looks, effects and invalidation. #124's branch was not checked. |
| `game/state/game_settings.gd` | 780 | Yes: controls, providers, preferences and engine mutation. #125's three owners address different change causes. |
| `game/world/world_generator.gd` | 750 | Yes: coastal topology and each vegetation/resource distribution still expand one class. #126, preserving query/seed identity. |
| `game/scenes/wildlife/wildlife_view.gd` | 709 | Yes: kinds, exceptional spawn policy, roofs/nests and farm-animal view lifecycle. #126's presentation half. |
| `tools/art/classic/livestock.py` | 1382 | Yes: every classic species and its pose/sheet assembly. Split species as for native; keep distinct classic primitives. |
| `tools/art/terrain.py` | 1280 | Yes: wet/coastal ground, grass, paths, soil/weed/overlay artists share one module. Keep edge primitives and stable layer order. |
| `tools/art/character.py` | 1006 | Yes: clothing, headwear, held tools, poses, sheets and effects. Split independently authored painters without scattering composition/hand-mask invariants. |
| `tools/art/classic/terrain.py` | 991 | Yes: classic water, meadow, paths and soil families. Same authoring split, distinct textures. |
| `tools/art/classic/buildings.py` | 990 | Yes: individual houses remain beside shared material/roof helpers. Apply the native house-provider pattern. |
| `tools/art/snags.py` | 969 | Yes: independent tree-species snag artists; existing row/redraw assembly still needs provider contributions. |
| `tools/art/trees.py` | 840 | Yes: trees, rocks, bushes, ferns and stumps. Existing beech/birch/alder modules show the useful seam; retain true canopy/bark helpers. |
| `tools/art/classic/character.py` | 830 | Yes: classic clothing/tools/effects and sheet composition still collect independent artists. |
| `tools/art/classic/snags.py` | 811 | Yes: all classic deadwood species; preserve each species' related appearances and seed strings. |
| `tools/art/crops.py` | 789 | Yes: crop artists collect here; split coherent grain/vegetable/trellis/fruit families, retaining shared growth-stage/sheet contracts. |
| `tools/art/seasons.py` | 764 | Yes: ground/house transforms and per-object winter policies; put family policy with providers and retain shared transforms. |

The remaining >1000 files are all art: classic livestock, native terrain and native character.
That does not make them the most urgent three changes. Conversely, Main at 696 lines can still
grow for settings wiring, input policy and feature installation (`main.gd:135–175,490–551`),
and SaveObjectChecks at 243 can still repeat F01. A threshold is a useful inventory, not acceptance.

## 3. New problems and newly exposed limits

### N1 — Activity discovery logs an error but can pass startup (**P1**, introduced by #120)

`game/state/activity_targets.gd:13–19` discards the loader's `problems` after `push_error` and
caches the surviving kinds. `ActivityRules.problems` starts with an empty array
(`game/state/activity_rules.gd:81–90`), unlike `QuestRules.problems`, which includes
`_kind_problems` (`game/state/quests/quest_rules.gd:85–87`).

Concrete consequence: an extra duplicate `home` target, or a script that does not extend
ActivityTarget, reports an error, leaves the original seven valid targets available, and need
not make ActivityRules invalid. RulesCheck can return true and Main can continue. This reopens
F09's “logged but not refused” failure through the new extension seam.

**Change:** retain target-discovery diagnostics and feed them into rules/startup validity. Exercise
an invalid extra script and duplicate kind through that gate, not only an injected good target.
QuestKinds is already generic in implementation (`quests/quest_kinds.gd:15–39`); move/name that
shared primitive appropriately instead of making activities depend on a quest-named owner.

### N2 — The new registries disagree about collisions and installation (**P2**)

These different *payloads* are legitimate: catalog constants, instantiated target kinds,
interaction callables, numbered upgrades and ordered scene flows are not one plugin interface.
Their error policies should nevertheless be deliberate:

| Boundary | Actual contract / gap |
|---|---|
| ScriptFolder | Sorted export-aware path enumeration only (`game/state/script_folder.gd:9–15`); good shared primitive. It does not itself validate an empty/missing required family. |
| CatalogTopics | Retains first duplicate and accumulates both source paths, but trusts TYPES/key shapes. See F08. |
| QuestKinds / ActivityTargets | Enforces base/kind uniqueness, but duplicate diagnostics only name the later path (`quests/quest_kinds.gd:26–27`), and ActivityTargets loses failures. See N1. |
| InteractionRegistry | Last registration silently replaces both label and opener (`game/scenes/interaction_registry.gd:14–16`), unlike the newly checked content registries. |
| Art houses/furniture | Reject duplicate names through declaration.merge; good. |
| Art farm animals | Streams sheet tuples with no duplicate-output-name check; a later writer silently wins. |
| SaveMigrations | Deterministic serial lookup, with a repository continuity check; appropriate for an ordered version chain, not interchangeable with discovery. |

Reject duplicate interaction registrations with kind/owner context, and validate sheet names
across *all* wildlife contributors before writing. Keep the domain-specific interfaces.
`ConsoleLoader.script_paths` (`game/state/console/console_loader.gd:10–12`) is still a small
forward to ScriptFolder with a command-specific default; it is not another enumeration algorithm
and does not justify a new loader refactor of its own.

### N3 — Shared flow construction does not prove Main installed those flows (**P2**, #127)

`FeatureFlows._init` registers actions before any flow enters the tree
(`game/scenes/feature_flows.gd:35–49`). The test helper installs `flows.all()`
(`tests/flows_case.gd:27–28`); Main separately names children and a later flow array
(`game/scenes/main.gd:221–230,315–319`). Forgetting Main's new flow installation can leave the
registry test green: the callable exists, but its screen is not in the production tree.
`tests/test_feature_flows.gd:82–87` also checks only `is_registered`, not valid/non-empty labels
and usable openers. Commit `cba7b10f`'s “cannot drift” claim is stronger than the test.

**Change:** preserve explicit layer/input order, but represent production installations once or
assert that every constructed flow is parented in the production composition. Add a small
composition check rather than another universal scene-discovery mechanism.

### N4 — Smaller classes gained wider public construction surfaces (**P2**, #127/#121)

AimViews exposes twelve collaborators, explicitly because a constructor would exceed the lint
argument limit (`game/scenes/aim_views.gd:8–21`); MapSwitch similarly exposes eleven
(`game/scenes/map_switch.gd:7–19`). Main must keep the long field-assignment recipes correct.
The new names improve readability, but this is still broad, mutable wiring rather than a
narrower dependency boundary. Prefer cohesive setup groups or an explicit setup operation when
these owners next change; do not hide the same fields in a string-keyed service locator.

On **[121]**, `_building_inside` becomes `building_inside` (with its important households setter
retained), and callbacks become public (`game/state/game_state.gd:76–80,233–264`); PlayerState
holds public `moving_seconds` and `is_horse_winded` (`game/state/player_state.gd:35–40`). This is
a reasonable cost of stateless operations over plain data, not an automatic encapsulation bug.
Document who mutates those coordinated values and avoid exposing every old private helper by
default in #122/#123.

More concretely, **[121]** `GameFactory.attach_world` (`game/state/game_factory.gd:39–45`) says
“once” but accepts a second call: it replaces the world/weather and appends another set of
simulation systems, leaving old systems bound to old collaborators. Add a construction-time
guard for that public precondition. No inspected production caller currently attaches twice.

### N5 — New tests overstate the boundary they exercise (**P2**, coverage corrections)

- **[121]** `tests/test_game_state_owners.gd:23–33`, named
  `test_a_game_is_freed_after_the_player_slept_and_passed_a_door`, only advances awake time,
  goes to the camp bed and teleports. It neither sleeps nor passes a door, much less awaits a
  frame-spread sleep. Rename it to its actual scope or exercise the named operations before
  dropping the state. The other factory/travel weak-reference tests are useful.
- The activity “inn” test proves injected implementation dispatch, not folder discovery (F10).
- The feature registry test proves registration after shared construction, not production
  tree installation (N3). Its lifetime counterpart explicitly frees every flow before dropping
  the registry (`tests/test_interaction_registry.gd:68–81`); that is valid teardown coverage,
  not proof that dropping the RefCounted FeatureFlows wrapper alone destroys unparented Nodes.

### N6 — Old extension traps now have better names, but remain traps (**P1/P2**, retained)

The two object-state registrations/numeric fallback (F12), unchecked snag derivation (F08),
manual startup completeness (F09), duplicated art object/icon assembly and unchecked winter
policy identities (F06) predate or survive the moves. They are not newly reproduced gameplay
regressions. They matter because new documentation now directs authors into these seams, e.g.
`docs/development.md:93–100` explicitly teaches the two-table object-state procedure. Close the
seam, then simplify that authoring rule; moving more families alone will not close it.

## 4. Changes to the remaining plan

Keep the original small, atomic responsibility moves. Retire the completed repairs, backpack,
page/feature installation, catalog relocation and save-migration extractions from the work list;
carry only their concrete remainders above. Do not restart them under another framework name.

| Remaining issue | Updated scope / order / acceptance |
|---|---|
| **#121 GameState** | Landed during review; do not queue its integration again. The final static-owner version is sound in direction and removes the intended forwards. Follow up with N5's test correction and the construction-only attachment guard, as small separate changes. This report does not certify its checks. |
| **#122 World** | Next major state package. Keep WorldEdits → WorldBuildings → environmental operations, separately. Move authoritative dictionaries **and** their indexes/mutation/replay rules together; no public raw-dictionary bridge back to World. Carry snapshot/restore with each owner and keep WorldSave's worker-safe JSON conversion explicit. Acceptance includes a new indexed family with no new World field/query/update arm, unloaded edit replay, index rebuilding and unchanged signal order. |
| **#123 Livestock** | Follow #121's final API; it need not wait for every #122 leaf if the World query API is stable. Keep motion → needs → roosting → following. Leave one explicit live/skip priority coordinator; share passed RNG, animal iteration order, search budget and roost occupancy. Do not copy the whole coordinator's internals into a public context bag. Compare synchronous/frame-spread outcomes and RNG state using existing meaningful catch-up cases. |
| **#124 WorldView** | Let its current work continue; no branch changes or verdict from this review. Its eventual acceptance must cover one aggregate draw budget/settle result, object/effect cleanup on unload, and explicit invalidation responsibilities. Freeze needed public view access before #126's wildlife half integrates: ClockViews, PlayLoop and MapSwitch now also consume that API. |
| **#125 GameSettings** | Still independent and worthwhile; can precede #123 if useful. Keep KeyBindings, engine application, provider metadata as distinct commits. Preserve one file and signal/write timing. Coordinate adapter wiring with Main's current composition, and migrate all provider references rather than leaving permanent GameSettings forwarding constants. Isolate/restore InputMap in affected tests. |
| **#126 Generator** | Separate from wildlife. CoastLayout → DykeLayout → VegetationPlacement remains right. Explicit inputs/query ownership, no callbacks that create a generator↔helper dependency loop. Keep exact tile/object answers, boulder-neighbor probes, terrain precedence and seed/hash strings; test chunk-order independence, not only a few attractive generated samples. It need not depend on rendering extraction. |
| **#126 Wildlife view** | Integrate after #124's view contract settles. Roof/nest placement → farm-animal presenter → checked constructor table remains sensible. FarmAnimalView already exists: extract lifecycle/visibility orchestration, not a duplicate sprite class. Keep ordered exceptional spawn policies, ambient camera lifetime and ephemeral prey; do not convert this to persistent simulation. |
| **#128 Art** | **Reorder its first work:** close checked object/icon/seasonal provider registration and duplicate sheet-output detection before broad leaf moves. Share redraw *identity/assembly*, while each art set supplies its own painters; check winter keys against declared kinds in both sets. Then split character, terrain, crops, trees/snags/seasons and classic families at authoring seams, one coherent family per commit. Include the still-large trees.py and classic character.py even though the issue's abbreviated list omits them. Retain one explicit layer/furniture/row order and classic fallback behavior. |

### Add these bounded follow-ups

1. **#120/#114: make discovery failure fail startup** (N1), and test real file discovery.
   This outranks cosmetic shrinking and does not require finishing topic-based startup providers.
2. **#110: finish checked catalog construction:** validate contribution shapes and reserve derived
   snag IDs before merge. Add focused invalid-contribution regressions, not a second catalog.
3. **#117: one object-state shape/check registration with feature-owned adapters.** Keep domain
   validators and migrations as landed; pair remaining World codecs with #122. The present numeric
   exemption list must not be the permanent extension contract.
4. **#113/#127: duplicate interaction rejection and production-installation coverage** (N2/N3).
   Keep Main's explicit order. A new feature should have one composition entry, not a second
   hidden test-only list claiming to certify it.
5. **#114 final gate extensibility:** retain a named explicit dependency sequence, with small topic
   check contributions and a completeness check for mandatory families. Drop the idea that merely
   changing `and` into a dictionary completed the original final step. No discovery of ordered
   scenes or simulation systems.

Also retain #121's bounded lifetime-test/attachment follow-ups now that it has landed. These are
small additions to existing issues, not another architecture programme. Source/runtime behavior
fixes, contract tightening and pure artist moves should remain separate atomic commits.

### The next three steps

1. **Propagate activity-target discovery errors into startup validity**, with malformed/duplicate
   target fixture files and a genuine new-file discovery case. This closes the new N1 failure.
2. **Extract WorldEdits as #122's first atomic ownership move**, including authoritative edit maps,
   per-chunk indexes and existing indexed-kind maintenance; preserve replay/notification semantics.
3. **Extract WorldBuildings as #122's second atomic ownership move**, moving the building list,
   tile index, placement/query invariants and their persistence together. Environmental/codec
   moves follow separately rather than turning this into a monolithic World rewrite.

After those, close the catalog/object-state follow-ups and continue #123/#125; #128's registration
work can use an independent art lane. Shared docs and composition/API integration remain serial
collision points. A branch being ready sooner is not a reason to combine unrelated fixes.

## 5. What I did not check

- No game, tests, lint, import, export, generator, screenshot, benchmark or memory soak was run.
  Merge comments' green suites, manual checks and byte-identical generation are their authors'
  reports; this review independently checked source/history, not those results.
- No files outside this repository, player saves/settings, external working-rule files or tool-output
  spill files were read. GitHub access was limited to the requested issue bodies/comments. No
  checkout, switch, reset or rebase was used; no background work or processes were started.
- #124's in-progress branch was not read. #121 was assessed at `ec143247` while still a branch;
  final ref verification found main at that identical commit. No extra integration behavior was
  executed, and commits after that tip are outside this verdict.
- Detailed inspection concentrated on ownership, loaders/registries, persistence, composition and
  meaningful test boundaries. Mechanical caller migrations and artist-family moves were sampled
  alongside the full commit-stat inventory; this is not a line-by-line audit of every changed test,
  drawing function, shader, audio system or asset. Pixel/RNG/output identity was not regenerated.
- The line census covers the original source scope, not Markdown, generated assets, vendored addons
  or caches. Existing unrelated working-tree changes were left alone. Only this progress file was written.
