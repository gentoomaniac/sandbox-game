# Architecture code review — 2026-11-16

**Baseline:** main `6083e77052ce501b40c72934d535e567f7a55332`, Godot 4.7 / GDScript. Runtime scope: `game/`; supporting scope: `tests/`, `tools/`, data and project documentation. **19 findings**, F01–F19. This is an implementation handoff, not a game-design proposal.

This was a source/history review. No game, tests, import, asset generation or lint was run. Concrete failures below are deductions from the cited execution paths, not newly reproduced runtime results. Paths and line numbers refer to the baseline unless a branch commit is explicitly named. Re-find the named functions before implementing.

## Executive verdict

The architecture has improved substantially since November 9. Keep plain state, explicit commands, committed action outcomes, strict load codecs, headless tests, and the existing UI components. The next work should address five structural problems:

1. **Features can bypass the boundaries already established.** Cart prices cannot pass save validation; chest-taking facts are synthesized by a closing window; flood progression has a scene-owned clock path. These are more important than reducing line counts.
2. **The content boundary validates the final tables but still assembles content through central edit lists.** New objects and art repeatedly touch the same catalogs, two generators and seasonal tables. Existing extraction files are plugged in by hand, sometimes without duplicate checks.
3. **GameState, World and Main remain places where new responsibilities accumulate.** Previous extractions were useful, but new features still need new fields, setup, routing and special cases in the same files. Split ownership, then let callers use the new owners; indefinitely adding forwarding methods does not solve the public-method limit.
4. **Persistence is explicit but its extension workflow is scattered.** A feature author must update its codec, snapshot, validator, migration and integration tests separately. The central validator is close to its limit and knows individual feature-state keys. Give each domain one validation/codec owner while retaining one ordered version sequence.
5. **The UI refactor fixes real layout/style issues, but it cannot fix domain or feature-composition coupling.** Finish #109 as agreed. Afterwards, share the repeated backpack component and give pages/features small installation contracts. Do not build another modal hierarchy.

Sizes below mean: **S** = localized change and focused regression; **M** = one coherent subsystem with several callers; **L** = a staged migration across ownership boundaries. Priority is stated separately. Large entries must be broken into the atomic steps in §7.

## 1. Earlier reviews: credit completed work and retain only the remainder

### November 6 (`docs/code-review-2026-11-06.md`)

| Earlier recommendation | Status at this baseline |
|---|---|
| Architecture/development/UI/tool/map onboarding; archive completed tasks | Substantially done: the requested guides exist; `TASKS.md:1–43` now gives board/work rules, rather than the old task archive. |
| Quiet, honest tests and build housekeeping | Runner now rejects zero tests, unloaded/skipped scripts and unsuccessful processes (`tools/run_tests.py:123–163`); Makefile has the documented targets. Historical warning/orphan totals were not remeasured. |
| Split the giant art entry point; palette and atlas checks | Topic modules, `canvas.py`, palette checking and generated manifests exist; `tools/art/generate.py` is now 473 lines. The remaining problem is registration fan-out and oversized topic modules, F06/F19, not the old 2,290-line entry point. |
| Derive current map, inject clock, extract ToolUse, common data-file reader | Done: `GameState.current_map`, its clock construction, per-call `ToolUse`, and `DataFile.read_sections`. Do not redo these moves. |
| Split World ground items/night upkeep; Main startup/debug; WorldView buildings/decorations | Done in meaningful parts: `GroundItems`, upkeep systems, `StartupOptions`/debug runners, `BuildingViews`, `DecorationView`. The owners have since gained more responsibilities; F13–F16 explain the next seams. |
| Share shader noise; central backdrop; object-gone contract | Present as shader includes, `UiColors.BACKDROP` and `World.is_gone`. Existing purposeful differences in drawing helpers and destruction policies should remain. |
| Later: settings/key-binding split, object known-key checks, Python lint/performance work | Settings split still open (F17); catalog field/reference checks now exist, but are not a general unknown-key schema. Python lint and old slow-test timings were not audited. |

### November 9 (`review/code-review-2026-11-09/README.md`)

| Package | What is now present / what remains |
|---|---|
| R1: item accounting | `ItemSlots` completes both stores before notification, guards self-send, and provides `take_from`, `exchange`, `hold_notifications`; held use consumes the selected slot (`item_slots.gd:60–139,173–228`; `inventory.gd:64–67`). Equipment and crafting use the improved paths. Do not re-file the old 12→24 observer probe as a current failure. New feature code must respect that contract too. |
| R2: safe saves | `SaveFile.load_game` validates before construction; write/flush/rename errors propagate; missing-content and quit questions are explicit (`save_file.gd:82–143`; `session_flow.gd:22–35`). This boundary exists. F01/F07/F12 concern how additions escape or overload it. |
| R3: durable dialogue and cleanup | `NpcDialogue.say` commits the reply (`npc_dialogue.gd:103–118`); `Modal._exit_tree` calls `close` (`modal.gd:128–130`). Hotbar binding/release exists; WorldView explicitly refuses another residency rather than silently rebinding (`world_view.gd:221–231`). Do not require every one-shot view to become arbitrarily reusable. |
| R4: catalogs | Deep read-only tables, `CatalogCheck`, `AssetCheck`, crop/trunk collision checks and explicit `placeable_in` are implemented. Definition relocation/extension remains partial; F08 builds on those checks instead of proposing them anew. |
| R5: item UI | Most of the old duplicated click/cursor/merge model is gone: `SlotView` owns Godot drag/drop and screens delegate quantities to domain APIs. `HotbarHud.acquire/release` exists. The narrower remaining repetition is backpack construction/binding/dimming, F05. |
| R6: authoritative actions/maps | Reach/station checks, common map notifications and `action_done` exist (`crafting.gd:65–91,129–135`; `game_state.gd:550–553`). Interior redraw is no longer a Main result-code branch. F04 is a new chest-taking path that does not yet follow this direction. |
| R7: bounded presentation/queries | Nearby pile and NPC presenters exist; pickup uses nearby chunk queries (`game_state.gd:717–754`); edit replay is indexed per chunk (`world.gd:145–166,924–964`). Do not propose those original indexes again. No new scale benchmark was run. |
| R8: simulation/residency | `Simulation`, `ChunkResidency`, state-owned `CatHunt`, session-local wildlife rules and inventory-driven held appearance are present. `PlayerState` synchronizes held layers independently of PlayerView. Main still owns frame policy, and new flood code adds another frame driver (F02/F11). |

Gossip, quests, relationships and trading now exist; the earlier review's instruction to leave unbuilt gossip out of scope is historical context, not a description of today's implementation.

**Existing extension seams worth copying:** ConsoleLoader discovers one command per script with export-aware resource listing and duplicate-name diagnostics (`game/state/console/console_loader.gd:11–48`). QuestRules already discovers one cfg per quest (`game/state/quests/quest_rules.gd:64–81`), and QuestKinds discovers objective/condition scripts. Recipes, crops, building styles and skills already support data additions. These are successful boundaries: extend their pattern to the specific remaining registries below rather than creating a competing universal plugin system.

## 2. What changes together: evidence of collision points

I read `git log --stat`, including the latest surge/economy work, and counted path co-occurrence in **744 non-merge commits** reachable from `6083e770`, selected with `--since=2026-11-09` and touching `game/`, `tests/` or `tools/`. Counts are commits, not changed lines; merge commits and `.uid` files are excluded from the script counts. This is a broad time window, including November 9 before its review; it is not a count of regressions since that report.

| Script | Commits changing it |
|---|---:|
| `game/scenes/main.gd` | 116 |
| `game/state/game_state.gd` | 73 |
| `game/state/save_file.gd` | 73 |
| `game/state/world.gd` | 41 |
| `tools/art/generate.py`, `tools/art/classic/generate.py` | 40 each |
| `game/state/save_validator.gd` | 40 |
| `game/state/tool_use.gd` | 32 |
| `game/scenes/world_view.gd` | 28 |

| Pair of game scripts | Same-commit changes | Interpretation |
|---|---:|---|
| `save_file.gd` + `save_validator.gd` | 31 | Expected codec/schema coupling, but all domains share the same two edit destinations. |
| `main.gd` + `game_state.gd` | 21 | New behavior repeatedly crosses both composition roots. |
| `game_state.gd` + `world.gd` | 16 | World features and session orchestration expand together. |
| `item_types.gd` + `world_object_types.gd` | 14 | An ordinary placeable still edits two giant definition files. |
| `npc.gd` + `save_validator.gd` | 12 | Villager additions expand the global schema checker. |
| `main.gd` + `game_settings.gd` | 10 | New settings repeatedly add application wiring to Main. |

Examples are stronger than counts alone:

- `94a8b95d` (sales cart) changed **37 files**, including ItemTypes, WorldObjectTypes, Interaction, ActionHint, InteractFlow, Main, both art generators and seasonal registration, alongside the feature's own classes/tests/art. Much of the art/design scope is legitimate; the repeated central registration edits are the avoidable part.
- `0d3f6d98` explicitly moved the dyke definition out because WorldObjectTypes was at its limit, but still edited its central assembly. `af540c0d` moved hover text because GameState was at 996 lines. `f1e1777e` moved quick-load/weather text out of Main to create room. Useful moves, but the commit messages demonstrate a recurring capacity-management workflow.
- `bc27d75a` replaced six friendship-rule accessors with `value` so the class stayed within 20 public methods. That may be fine for uniform tuning data, but the lint threshold, rather than a newly named responsibility, drove the API change.

## 3. Coupling findings

### F01 — Object feature state and the save validator disagree about cart prices

**Priority: P0; size: S for the repair, M for the extension seam (F12).**

**Evidence:** `game/state/sales_cart.gd:59–65` stores `state["prices"]` as a nested dictionary. `save_validator.gd:393–400` requires every object-state value except `tree`, `run` and `lit` to be numeric. Objects reach that check through `360–375`. `SaveFile.load_game`, `save_file.gd:138–143`, refuses the game on any such problem.

**Concrete failure:** put eggs on a cart, set their price, save, load through `SaveFile.load_game`: the legitimate `prices` dictionary is reported as “should be a number,” so the save cannot load as READY. The cart test at `tests/test_sales_cart.gd:89–99` bypasses SaveFile and therefore cannot catch it. No save version change is necessary merely to accept the representation already being written.

**Fix:** add cart-specific validation of `prices` (slot key, entry dictionary, item text, whole positive price) and non-negative whole `till`; retain the existing price-belongs-to-item behavior. Do not merely exempt `prices` from all checking. Add a full load-boundary regression for a priced cart, plus malformed cart state rejection. Then move feature-state checks behind F12's domain dispatch.

### F02 — Flood work is authoritative state advanced by a notification scene

**Priority: P1; size: M.**

**Evidence:** `game/scenes/surge_flow.gd:13–33` combines notifications with `_state.world.flood.step(world, delta)` in `_process`. `game/state/surge_upkeep.gd:27–58` handles calendar advancement and skip settling separately. Flood stepping changes wet tiles and emits chunk changes (`flood_state.gd:185–213`), affecting walkability, crop harm and saved water; it is not just animation. `GameClockTicker.tick` respects freeze/hold (`game_clock_ticker.gd:27–40`), whereas SurgeFlow has no corresponding gate. Simulation says outside movers must be held during frame-spread skips (`simulation.gd:50–65`).

**Cost/failure:** a headless caller advancing played minutes through Simulation does not get the same intermediate fill as a live scene unless it knows to step FloodState too. With the console's clock freeze, the flood's real-time worker still progresses. During a frame-spread sleep another scene can step the same flood between catch-up phases. Those policies are implicit rather than deliberately selected at the simulation boundary.

**Fix:** make budgeted frame work an explicit state/session simulation entry point and call it once from the play-loop owner. Move flood stepping there; SurgeFlow becomes notification-only. Preserve the designed real-second fill rate and tile budget, and state explicitly whether freeze/indoors/blackout holds that work. Keep skip settling as the alternate execution mode of the same owner. Acceptance: direct/headless and live-driver calls have the documented behavior; a frame-spread skip cannot race ordinary flood work; no dependency on NotificationHud is required to progress a flood.

### F03 — Two state helpers import the rendering scale through TerrainTileset

**Priority: P2; size: S.**

**Evidence:** `game/state/npc_bubbles.gd:23–27,48–59` converts tile positions using scene class `TerrainTileset.TILE_SIZE`; `game/state/sea_search.gd:65–78` does the same for tidal relief. The constant belongs to `game/scenes/terrain_tileset.gd:49–54`, a class responsible for rendering atlases. This is a real state→scene class dependency, despite the documented one-way rule.

**Cost:** bubble eligibility, sea queries and their tests depend on a rendering catalog just to convert units. A renderer change propagates into unrelated state rules; pixel-based camera visibility is mixed with domain selection.

**Fix:** have NpcSpeech convert the visible region/head allowance into tiles before asking NpcBubbles, or keep the visibility predicate in the scene. Give Tide a tile-coordinate relief query that owns its fixed coordinate conversion, and use it in SeaSearch. Keep exact relief/shader agreement covered by existing tide tests. Do not move the entire tileset into state, or replace this with another unrelated magic `32` in each caller.

### F04 — A chest window creates the authoritative fact that goods were taken

**Priority: P1; size: M.**

**Evidence:** `game/scenes/storage_screen.gd:72–79,97–121` snapshots chest totals on open, computes a net difference on close and emits `taken_from`. Main forwards that to `GameState.report_taken_from_chest` (`main.gd:327–329`; `game_state.gd:545–547`). Actual Shift transfers and slot drags happen earlier (`storage_screen.gd:165–169`; `slot_view.gd:208–219`). `Harm.record` finds witnesses when it receives the outcome (`harm.gd:61–70,101–110`). Quick save can run with a window open (`session_flow.gd:45–50`).

**Concrete cost:** taking goods, saving with the chest still open, then loading stores the inventory change without the close-generated theft fact. Witnesses also count at close rather than at acquisition; NPCs can move while this non-pausing screen is open. A non-UI chest transfer reports nothing at all. This is a new exception to the action-outcome boundary added since the previous review.

**Fix:** route player chest transfers through a domain operation carrying chest/map identity, source/destination and moved quantities. Emit the taken fact after the transfer commits. If net-per-visit accounting is intentional, a state-owned visit must own that policy, its witness timing and save flush; a disposable window must not own the only record. Prefer immediate committed transfers unless preserving the documented net policy requires otherwise. Cover drag, Shift transfer, refusal, return of goods and saving before close. Avoid double-reporting from the old close path.

## 4. Duplication findings

### F05 — Backpack columns are copied across specialized container screens

**Priority: P2; size: M.**

**Evidence:** `process_screen.gd:77–90,109–132,244–261` and `campfire_screen.gd:66–82,95–117,135–146` repeat icon header, 5-column backpack creation, slot IDs, binding, hotbar acquisition, Shift callback connections and dim/reset loops. `storage_screen.gd:53–68,133–158,187–193` builds the same backpack through local helpers. Quantity movement is already shared in ItemSlots/ProcessStation; do not replace it.

**Cost:** adding a new container screen copies a lifecycle recipe, not just a few style lines. Fixes to slot badges, layout or hotbar dim cleanup must reach several screens. These repetitions survive every planned #109 commit.

**Fix:** a composed `BackpackGrid` owns its header/grid/SlotViews, binds an Inventory, emits indexed quick-move intent and applies a supplied dim predicate. Keep station acceptance rules in ProcessStation and campfire fuel policy in its domain operation. Use the existing hotbar ownership API; add a small shared binding helper only if the remaining lifecycle duplication still warrants it. Migrate one screen per commit; retain equipment layout, chest backpack-first ordering and station-specific no-swap rules. Use existing drag/cleanup tests, with a behavioral regression for a genuinely changed contract.

### F06 — Art registration repeats identity/order separately from drawing

**Priority: P1 for new-content throughput; size: M.**

**Evidence:** `tools/art/generate.py:164–307` lists object identities/order; `classic/generate.py:187–257` repeats it. Runtime definitions carry the same row numbers. Item icon maps are merged with `|` at `generate.py:446–450`; house maps likewise at `349–352`. Seasonal dispatch is maintained separately (`seasons.py:452–585` and classic object looks). These unions overwrite duplicate names; the overwritten contribution is gone before downstream checks see it.

**Cost:** the cart and dyke histories above show both generators and season tables edited together. A new content author must know atlas order, icons, indoor pictures and winter registration. An accidentally repeated icon key silently selects the later contribution. The existing generated atlas test detects many mismatches but does not remove this workflow coupling.

**Fix:** one checked, ordered asset declaration list with stable art-kind/row identities, and per-topic providers for pictures/icons/seasonal policy. Both art sets consume the identity/order list but retain their own drawing functions and explicit supported/fallback capabilities. Merge named contributions with duplicate rejection before writing. Preserve current row order, variant order, seed strings and classic fallback; interior tile IDs must also retain their explicit order. Do not generate artistic drawing code from game cfg. A new ordinary art family should add its provider/declaration, not edit several independent assembly lists.

### F07 — Feature round-trip tests repeat codecs while missing the public load boundary

**Priority: P1; size: S per migrated test family.**

**Evidence:** cart's “saved” test calls `WorldObject.from_dict` directly (`tests/test_sales_cart.gd:89–99`); `ResourceCase._through_save` directly calls `GameState.from_dict` (`tests/resource_case.gd:115–123`). `SaveUpgradeCase:14–23` already knows how to write an envelope, and `SaveValidationCase:27–44` exercises refusal/missing-content paths. Snapshot integration fixture setup is in `test_save_snapshot.gd:43–83`.

**Cost:** feature authors copy JSON round-trip patterns and can pass a codec test while creating a save the real loader refuses (F01). Adding each new world feature to one enormous “everything” fixture also makes unrelated workers collide.

**Fix:** keep raw codec tests named as codec tests. Add a small shared **successful public load** helper beside the existing refusal helper: write a current envelope, call SaveFile.load_game, require READY and return the state. Each feature owns its own representative setup and round-trip assertions in a dedicated test file; reuse focused fixtures such as ResourceCase/CoastWorld instead of a universal scenario builder. Add snapshot-isolation coverage for mutable feature data when needed, without requiring every feature to edit the central “change everything” fixture. This is boundary coverage, not a blanket test rewrite.

## 5. Modularity for parallel work and new content

### F08 — Catalog shards still require edits to giant assembly files and can hide collisions

**Priority: P1; size: M.**

**Evidence:** `world_object_types.gd:952–961` hand-merges Plants, Ways, Village, Stall and Dyke contributions with `_OTHER_TYPES`. Checks at `936–949,965–989` cover crop/trunk additions, not every preceding shard merge. Item definitions remain predominantly `_OTHER_TYPES` (`item_types.gd:570–713,719–724`). The cart added both central definitions; the dyke extraction still edited central assembly.

**Cost/failure:** two workers add different placeables but collide in ItemTypes and WorldObjectTypes. A duplicate ID across shard dictionaries can be discarded by merge before CatalogCheck checks the final table. The graph validator cannot recover the discarded definition's provenance.

**Fix:** complete the existing read-only catalog design with checked contributions from **topic-sized** files/data: resources, clothing, food, yard fixtures, stations, boundaries, furniture, vegetation. A small sorted directory loader or checked declaration manifest loads each contribution with its source path and rejects duplicate IDs before any merge. Use raw stable IDs in declarations so ItemTypes/WorldObjectTypes initialization does not become cyclic. Preserve constants as compatibility names for callers that genuinely use them; do not demand one new global constant for every cfg-only item. Resolve derived crops/tools/trunks, validate the graph, then freeze. Keep tests able to supply isolated definitions. This is the still-open relocation part of old R4, with the now-concrete shard-collision gap.

### F09 — The startup validity gate is a manually maintained, incomplete list

**Priority: P1; size: S for coverage, M for an extensible gate.**

**Evidence:** `game/scenes/rules_check.gd:8–29` checks older rule families but omits, for example, ActivityRules, QuestRules, FriendshipRules, ShopRules, Prices, BarterRules and StallRules. A rule's `from_file` logs problems yet returns the object (`barter_rules.gd:29–33`); accessors then trust required keys (`60–62`). GameState constructs quests/stall sales and starts activities (`game_state.gd:117–125,904–925`). `docs/architecture.md:361–375` still tells an author to add checks in Main, although they moved to RulesCheck.

**Cost:** a malformed newly added file can log an error and continue into gameplay instead of causing the promised controlled startup refusal. Adding a rule family also requires remembering a distant gate and outdated instructions.

**Fix:** first include every mandatory current family and fix the documented location. Then register startup checks by topic through small check providers or a checked explicit catalog; keep dependency order explicit (base definitions before cross-reference checks, assets last). Collect diagnostics rather than relying on a short-circuit `and` chain to reach all checks. Reuse DataFile; no inherited Rules hierarchy. Acceptance: an invalid representative new-family file prevents state/view setup; adding a check contribution is discoverable and duplicate/missing registrations are diagnosed.

### F10 — Villager activities are data-driven until a new target kind is needed

**Priority: P2; size: M.**

**Evidence:** `activity_rules.gd:23–41` fixes target kinds, searchable kinds and door-capable kinds in separate lists. `activity_places.gd:28–46` dispatches target behavior with a match. `activity_upkeep.gd:106–110,124–137,369–378` knows the special `wild` availability exception and resolves inside/radius behavior. Existing activities of an existing target can already be added as data; preserve that success.

**Cost:** a new destination such as an inn or fishing spot needs edits to validation, place resolution and possibly availability/door dispatch; independent behavior workers meet in those files. The `wild` exception shows that “availability” and “resolve now” are different operations already.

**Fix:** introduce a small target-kind interface with ID, validation capabilities (search/door), availability and place resolution. Put home/work/field/church/meeting/friend/wild implementations in a target folder and load them using the same export-aware approach as `QuestKinds` (`quests/quest_kinds.gd:13–36`). ActivityUpkeep still owns scheduling/travel and does not become a behavior-tree engine. Add a fake/new target test proving that its file registers without changing the scheduler. For ordinary new activities keep cfg-only authoring.

### F11 — New screens/features still expand Main and routing tables in several places

**Priority: P2; size: M.**

**Evidence:** Main declares screens (`main.gd:49–58`), adds them (`209–222`), wires feature flows (`291–310`), and separately lists sound watchers (`731–750`). InteractFlow declares concrete screen fields (`interact_flow.gd:12–20`) and switches on Interaction.Kind (`26–55`); Interaction and ActionHint add their own matching kinds (`interaction.gd:59–69`; `action_hint.gd:51–62`). Character pages are declared, listed, added and refreshed individually (`character_screen.gd:44–46,69–91,113–120,144–153`). On the UI branch, pages also require manual `_lists.append` calls.

**Cost:** a cart-like screen touches Main, Interaction, ActionHint and InteractFlow even though it has its own screen/flow. A new character tab touches several places in CharacterScreen. Composition-root edits are legitimate, but four or five registration lists for one feature are not.

**Fix:** use feature-owned installation functions/flows, as QuestFlow/BarterFlow already begin to do. Register a small interaction descriptor (kind, label formatter and scene opener), while the domain still owns target choice and priority. An explicit ordered installer list is enough; do not auto-discover arbitrary scenes whose input order matters. Give CharacterScreen one `add_page(id, title, control, on_show, lists)`-style registration point or equivalent descriptor, so titles/buttons/scroll fitting come from that entry. Keep page state binding and refresh styles local. Register sound behavior with the owning feature. Do not give every flow the entire Main object or a string-keyed service locator.

### F12 — Persistence needs domain-owned checks/codecs, not one script per new save field

**Priority: P1; size: L, staged.**

**Evidence:** `save_validator.gd:59–84` dispatches every domain; `160–221` knows flood layout; `393–453` knows campfires, nests, dykes and process runs; `677–844` knows villager identity, relationships, plans and memories. `World.snapshot/from_dict` enumerate world concerns (`world.gd:858–920`); WorldSave repeats the shape conversion (`world_save.gd:8–56`); SaveFile owns I/O and ten migration functions (`save_file.gd:214–310`). The 31 co-changes and F01 show the extension cost.

**Cost:** a flood-like saved feature edits its state codec, World snapshot/load, WorldSave conversion, the global validator and SaveFile version sequence, plus tests. A checker author has to understand every feature's special keys. Moving only the long validator to “part 2” would leave that ownership unchanged.

**Fix:** keep SaveValidator as orchestrator over explicit domain validators: world/maps and references, items/object state, player, actors/villager memory, economy/quests, flood. Share one small validation context for paths, primitive shape/range checks, missing-content removals and building-reference facts. Domain modules expose their own current-format check and explicit snapshot/restore logic where useful; do not add reflective serialization. Move object-state validation to its actual feature owner/adapter so a new cart-like dictionary does not need a numeric exception in a global loop.

Keep **one** save envelope/version, ordered cross-domain loading and the ten-upgrade window. Extract supported migrations to individually numbered scripts with a checked contiguous manifest or deterministic version lookup. Allocate the next version serially at integration: parallel work cannot independently claim version 57. Keep historical migration defaults literal; never let a balance change rewrite their meaning. Existing on-disk keys/IDs do not change during extraction. A new optional object-state key needs validation even when it does not need a version bump.

## 6. The line-limit symptom: ownership findings and every file over 700 lines

The census counted lines in 1,221 `.gd`, `.py` and `.sh` source files under `game/`, `tests/`, `tools/` (not caches). **25 files exceed 700 lines; none is in tests/.** Makefile `15,341–343` runs GDScript lint/format on `game tests`; Python drawing files above 1,000 are not evidence of that GDScript lint failing.

GameState, World and Livestock explicitly disable `max-public-methods` at their headers. That is useful evidence that forwarding everything through the old owner cannot be the end state. A well-named, cohesive file need not be made artificially tiny; the objective is to remove an independent reason to edit it.

### F13 — GameState mixes session assembly, player policies and save restoration

**Priority: P1; size: L.**

**Evidence:** `game_state.gd:117–162` builds the session, village and starting kit; `169–224,568–617` handles travel/rest; `330–497` movement/riding; `500–542` held-item actions; `619–678` demolition; `717–774` pickup/drop; `777–925` persistence and simulation installation. It is 992 lines even after ToolUse and hover text were extracted.

**Cost:** a new mount rule, wake rule, saved feature or upkeep system lands in the same file. Broad state dependencies also make almost every test reachable from a change to it. Extracting only presentation text made room but did not stop these independent growth paths.

**Fix:** retain GameState as the aggregate/session identity with world, player, clock and composed systems. Move riding/movement policy to `PlayerTravel` (including horse stamina/displacement); home/doors/rest to `PlayerRest` or a cohesive player-location owner; pickup/drop to `GroundPickup`/player item actions; demolition to the building-action owner. Put ordered system installation/new-game construction and save reconstruction in explicit factory/codec modules. Stage these separately and migrate callers to the named owner rather than adding a permanent forward for every method. Keep action_done reporting on the aggregate if that remains the clearest observation point. Avoid RefCounted self-cycles: use per-call aggregate arguments or the existing non-owning named-method pattern.

### F14 — World is both the edit store and the adapter for every environmental feature

**Priority: P1; size: L.**

**Evidence:** `world.gd:76–100,145–178,933–964` keeps residency/edit maps and feature indexes; `310–417` soil/fallow mutations; `646–729` building placement/ownership/indexing; `735–766` clay; `772–835` paths/mud; `858–920` serialization. Crop, scarecrow and campfire indexing is repeated inside `_edit_object` (`939–953`). Existing SoilMoisture/FallowSoil/WorldWear extractions own data, but World still owns much feature execution.

**Cost:** adding an indexed placed-object family requires another field/query/update arm in World; new environmental rules consume its shrinking capacity. Splitting helpers while all state invariants remain in World leaves new contributors coupled to its internals.

**Fix:** a `WorldEdits` owner maintains terrain/object entries and chunk indexes together; a `WorldBuildings` owner maintains building list/tile index and placement queries; soil/fallow and resource recovery operations belong to their existing domain owners or named adapters. Keep World as GameMap and the command boundary coordinating edits plus necessary signals. Rebuild auxiliary indexes on load, never mutate two owners' backing dictionaries from the outside. Replace repeated hard-coded feature-index arms with a small indexed-kind query mechanism only for real current consumers. Preserve notification order, dormant/clearable policy and edits in unloaded chunks.

### F15 — Livestock has a collection API and several independent behavior machines

**Priority: P2; size: L.**

**Evidence:** `livestock.gd:240–284` chooses follower/sleep/coop/awake precedence; `330–515` catch-up and roosting; `535–592` hunting/flee/wander; `602–771` needs/friendship; `791–860` following; `918–979` movement/collision. CatHunt, Coop, Crowing and NeedSources exist but the coordinator still contains their transition policy and substantial implementations.

**Cost:** adding another animal behavior means modifying update precedence, live execution and catch-up in one 979-line class. A change that works in play can be forgotten in sleep catch-up. Making a new enum value alone does not supply those contracts.

**Fix:** retain Livestock's collection/signals/spawn entry points and one explicit priority policy. Extract `AnimalMotion`, `AnimalNeeds` (accounting/search/consume), `ChickenRoosting` and `AnimalFollowing` as cohesive operations with live/catch-up hooks. Use CatHunt as an existing precedent. Keep one passed RNG and stable iteration/draw order so extraction does not change seeded outcomes. Do not combine NPC pathfinding and animal steering merely because both walk. A small ordered behavior list is warranted only after the concrete extraction makes the shared hook clear; no generic AI framework.

### F16 — WorldView still owns terrain production, object presentation and transient effects

**Priority: P2; size: L.**

**Evidence:** `world_view.gd:369–418` fans out invalidation; `476–655` draws terrain/chunk rows and corners; `657–817` chooses object atlas state, lights and occluding sprites; `882–921` owns tree-fall/trunk visibility. Season/cover state and queues are fields at `127–155`. BuildingViews/DecorationView already exist and should stay.

**Cost:** changing a terrain edge and changing tree-hit presentation collide in one 921-line owner. Object appearance now includes explicit dyke/flood knowledge (`803–817`) as well as scarecrow wind and crop sources. The renderer-residency extraction did not eliminate these separate reasons to edit the renderer.

**Fix:** WorldView becomes the rendering composition/invalidation boundary. `TerrainChunkView` owns packed layer caches, cell/corner drawing and chunk draw/refresh queues; `WorldObjectView` owns tile/sprite substitution, atlas selection, object lights and occlusion; a small `TreeFallEffects` owns falls/hidden trunks and their cleanup, using the object presenter. Preserve one controlled draw budget and explicit settle status; do not create unbounded independently ticking queues. Object presentation extensions get named functions/providers only where existing special cases justify them.

### F17 — GameSettings grows because it owns both user preferences and engine adapters

**Priority: P2; size: M.**

**Evidence:** `game_settings.gd:42–57,152–225,270–377,558–625,663–780` contains keybinding catalogs, conflict rules and codecs. Display-server calls are at `258–262,673–680`; general/audio file parsing at `469–555`, writing at `628–660`. Model-provider metadata remains here (`112–150`) although LanguageModelProfiles is already a separate owner.

**Cost:** new controls, a provider and an audio/game preference all edit this 780-line class. Controls metadata and engine mutation have no relation to energy drain or save interval except sharing one file on disk. Earlier review's deferred split is now worth doing.

**Fix:** composed `KeyBindings` owns defaults/conflicts/event codecs and contributes its ConfigFile section; `LanguageModelProfiles`/provider catalog owns provider metadata. A small settings application adapter owns InputMap/DisplayServer effects. GameSettings keeps persistence coordination and genuinely small preference groups, with section read/write contributors rather than one class per scalar. Preserve the single settings file, write-on-change semantics, migration rules, silent loading and signal contracts. Update affected tests to isolate/restore InputMap instead of making all settings tests depend on engine bindings.

### F18 — Generation and ambient presentation need named feature seams, not more branches

**Priority: P2; size: M per owner.**

**Evidence:** `world_generator.gd:228–275,304–530` combines terrain, coast/tideways/Warften and dyke topology; `543–607,625–750` combines vegetation/species/resource rules. `wildlife_view.gd:312–344,498–584` owns roof/nest geometry; `587–629` constructs every animal kind; `632–667` also presents saved livestock. These owners are 750 and 709 lines respectively.

**Cost:** a new coastal landform and a new forest distribution both edit WorldGenerator; another roof bird and a livestock visibility feature both edit WildlifeView. New wildlife already has a script per behavior, but its factory and exceptional spawn rules remain central.

**Fix:** use plain `CoastLayout`, `DykeLayout` and `VegetationPlacement` operations with explicit inputs/order, retaining RiverLine/CreekLayout/WoodLayout. Keep `terrain_at`, `object_type_at` and generated-chunk answers identical. For wildlife, extract roof/nest placement and farm-animal presentation; a checked kind→constructor table handles the existing factory, with explicitly ordered special spawn policies. Preserve camera-dependent ambient existence and ephemeral prey as designed; do not make wildlife persistent or move all birds into the saved simulation.

### F19 — Art topics became content collections; split by independently authored drawing families

**Priority: P2; size: M per family.**

**Evidence:** native `tools/art/livestock.py:187–265,551–659,876–969,1047–1093,1138–1389,1866–2218` mixes shared pose construction and every species. `buildings.py:481–773,1064–1168` collects independent buildings beside material primitives. `interior.py:353–581,585–704,909–978` combines beds, tables, hearth and stable tile assembly. `crops.py:221–770` collects all crop artists; `snags.py:933–969` shows species providers behind a shared registry. The table below identifies the rest.

**Cost:** artists working on different animals/buildings edit the same long module. These are meaningful families, not algorithmic complexity requiring a framework. Sharing native and classic painting implementations would erase intentionally different visual rules and increase parameterization.

**Fix:** keep real shared drawing primitives and sheet assembly; move species/building/crop/furniture families into topic provider modules. A stable explicit registry consumes those modules (checked contribution registration from F06), so new artists do not edit the assembler. Move classic families similarly when they are being worked on, keeping their distinct primitives. Preserve random seed spelling, call order, export names and byte-identical generated output for pure moves. Split only at actual authoring seams, not every drawing function.

### Complete >700-line disposition

All paths below are relative to the repository root. These are destination responsibilities, not mandates to execute 25 simultaneous rewrites. Ranges give a useful starting point in the existing file.

| File | Lines | What it should become, and why |
|---|---:|---|
| `game/state/game_state.gd` | 992 | Aggregate + named player travel/rest/item actions + session factory/codec; F13. Move independent policies, then remove obsolete forwards. |
| `game/state/world_object_types.gd` | 989 | Small immutable catalog/derived-type assembly; topic declarations for vegetation, furniture, stations, boundaries and yard content. Header/schema stays a reference, not a dumping ground for definitions; F08. |
| `game/state/livestock.gd` | 979 | Collection/coordinator + motion, needs, following and chicken roosting operations, each with explicit catch-up behavior; F15. |
| `game/state/world.gd` | 978 | GameMap coordinator over edits, buildings and environmental owners. Snapshot/load move with owners; F14/F12. |
| `game/state/save_validator.gd` | 952 | Orchestrator + shared validation context; domain checks for world/references, item/object state, player, villagers, economy/quests and flood; F12. |
| `game/scenes/world_view.gd` | 921 | Rendering composition + terrain-chunk presenter, world-object presenter and tree-fall effects. Existing BuildingViews/DecorationView stay; F16. |
| `game/state/item_types.gd` | 823 | Immutable item catalog/queries; resource, wearable, food, fixture declarations plus existing tool/crop derivation. Ordinary content additions stop editing this class; F08. |
| `game/scenes/main.gd` | 812 | Composition root plus explicit play-loop and map-presentation owners. Feature flows install their screens/actions/sounds together; move coherent `_process` policies (`523–619`) and map switching (`710–725`), not random helper methods; F02/F11/F13. |
| `game/state/game_settings.gd` | 780 | Preference persistence coordinator, KeyBindings and engine application adapter; provider definitions move with profiles; F17. |
| `game/world/world_generator.gd` | 750 | Generator coordinator over coast, dyke topology and vegetation placement; exact query/seed order preserved; F18. |
| `game/scenes/wildlife/wildlife_view.gd` | 709 | Ambient population coordinator; roof/nest placement, farm-animal presenter and checked animal constructors. World/camera queries stay explicit; F18. |
| `tools/art/livestock.py` | 2218 | Shared quadruped/pose helpers (`69–277`), one species family per module (cow, pig, sheep, chicken/rooster, rabbit, dog, cat, horse/riding), small sheet registry (`2196–2218`). Largest worker-collision hotspot in drawing; F19. |
| `tools/art/classic/livestock.py` | 1382 | Classic pose helpers (`29–332`) and classic species families (`344–1382`), keeping classic art independent of native geometry; F19. |
| `tools/art/terrain.py` | 1280 | Edge/mask helpers (`104–263`), wet/coastal terrain family, meadow/grass family, worn paths, tilled soil/weed/overlay family (`1150–1275`); stable `LAYERS` ordering (`1278–1280`) stays explicit. F19, separate from gameplay generation. |
| `tools/art/buildings.py` | 1168 | Materials/roofs/windows primitives (`72–480` and roof helpers), individual house/barn/hall-house providers (`481–773,1064–1158`), small checked PICTURES registry. Different houses can be authored independently; F19. |
| `tools/art/character.py` | 1006 | Figure/pose geometry (`71–229`), clothing/hair/headwear painters, held-tool artists (ending `801–808`), sheet assembly (`811–939`), small effects (`942–1006`). Keep hand-mask/outline contracts next to sheet composition; F19. |
| `tools/art/classic/terrain.py` | 991 | Classic edge helpers (`79–205`), water/ford/mud (`206–434`), land/meadow, worn paths (`777–929`), soil/weeds (`930–991`). Preserve LAYERS order and distinct classic texture rules; F19. |
| `tools/art/classic/buildings.py` | 990 | Classic material/roof primitives and separate house providers (`364–620`, hall-house section after roof helpers); explicit PICTURES order/IDs. No native/classic parameterized megagenerator; F19. |
| `tools/art/interior.py` | 978 | Room floors/walls, beds/blankets (`321–456`), tables/seating (`457–581`), hearth (`582–711`), stores/furniture (`712–895`), stable marker/atlas assembly (`896–978`). Preserve Tiled IDs when moving definitions; F19. |
| `tools/art/snags.py` | 969 | Shared deadwood primitives plus dead/half-dead/bare provider per tree species; keep the species' three appearances together. `DEAD`/`HALF_DEAD`/rows (`933–969`) become checked assembly; F19. |
| `tools/art/trees.py` | 840 | Real shared canopy/bark/shadow primitives (`32–199`), oak/conifers, rocks (`250–298`), bushes/ferns (`575–693`), stumps (`694–801`), small assembly (`808–840`). Existing beech/birch/alder modules demonstrate the seam; F19. |
| `tools/art/classic/character.py` | 830 | Classic pose/body/clothing/hair/headwear families, held tools (`608–668`), sheet/collapse/riding composition (`669–787`), effects (`788–830`). Do not rewrite legacy pixels while moving them; F19. |
| `tools/art/classic/snags.py` | 811 | Same family boundaries as native snags, with classic-specific primitive implementations (`43–192`) and registry (`781–811`); F19. |
| `tools/art/crops.py` | 789 | Shared plant primitives (`85–220`, grain helpers), per-crop or coherent grain/vegetable/trellis/fruit providers (`221–754`), checked ARTISTS/sheet assembly (`755–789`); F19. |
| `tools/art/seasons.py` | 764 | Palette/look vocabulary (`22–56`), ground transforms (`58–204,319–344`), object/vegetation transforms + family winter policies (`205–318,345–682`), house/roof transforms (`683–764`). Extract transforms without creating a palette↔provider import cycle; F06/F19. |

## 7. Atomic refactor order and conflict-free parallel scopes

### Implementation rules

- Each numbered commit below is a complete behavioral repair or responsibility move, with its necessary tests, generated files and directly affected documentation. Keep IDs, save keys, input ordering, classic fallback, gameplay rates and RNG order unless a step explicitly repairs behavior.
- Each must pass `make test` and `make lint` on its own. `make test-changed` is a development aid, not the final gate. Existing tests should verify pure moves; add meaningful regressions for F01–F04 and changed contracts, not tests that restate constants.
- UI/render changes also need `make run`/appropriate `make screenshot` checks at small viewports, UI scale 2.0, both arts and after map transitions. Pure art moves need `make art`, then verification that generated art is byte-identical, and `make assets`/existing atlas checks. Use make targets for these jobs. These checks are instructions for implementers; they were not executed for this review.
- A commit moves one owner and migrates all affected callers. Do not land a “tests temporarily red” intermediary or combine behavior fixes with broad moves. One version allocation is integrated at a time; retaining/removing an oldest migration remains its own complete commit under the existing save policy.
- Finish #109 first for files it owns. Re-read its merged forms before changing CharacterScreen, scrolling pages, colours or theme resources. Do not duplicate its pending commits.

### Ordered commits

| Step | One commit's change | Prerequisite / acceptance |
|---|---|---|
| 01 | Accept and validate legitimate sales-cart state; add priced-cart public-load regression (F01) | First priority; old valid saves still load; bad nested prices refuse cleanly. Keep this test local initially. |
| 02 | Add successful public-load fixture helper and migrate the relevant feature round-trip assertions (F07) | After 01; keep codec-only tests explicit, exercise READY through SaveFile. |
| 03 | Move NpcBubbles visibility conversion to its scene boundary (F03) | Independent; same visible speaker set at every zoom/scale. |
| 04 | Add/use Tide's tile relief query in SeaSearch (F03) | Independent of 03; preserve tide/shader numerical results. |
| 05 | Add one explicit frame-work entry point and move flood stepping out of SurgeFlow (F02) | Serial Main integration; test freeze/skip/indoors policy, notification-only SurgeFlow. |
| 06 | Add domain-owned chest transfer reporting; migrate drag/Shift paths and remove close-only reporting (F04) | Serial Main/SlotView integration; save-before-close and witness timing tested. Preserve declared net/immediate policy. |
| 07 | Complete RulesCheck coverage and correct its authoring instructions (F09) | Local controlled-startup regression; no loader redesign in this repair. |
| 08 | Extract reusable validation context and one item/object-state validator (F12) | After 01/02; same diagnostics and missing-content decisions, cart check travels with it. |
| 09a–e | Extract world/reference, player, actor/villager, economy/quest, then flood validators, one per commit (F12) | Chain after 08; preserve cross-reference pass order and exactly the current save format. |
| 10 | Extract ordered supported migrations from SaveFile with continuity/window check (F12) | After 09; all 46→56 supported transitions unchanged; I/O stays in SaveFile. |
| 11 | Introduce checked topic catalog contributions and migrate one world-object family (F08) | Duplicate IDs fail with source names; deep read-only/crop/trunk checks remain. |
| 12a–c | Move remaining world-object topics, item topics, then item derivation/assembly behind the checked boundary, one coherent move per commit (F08) | Chain after 11; ordinary placeable can be added without modifying the large catalog classes. Split a row into more commits if its diff contains unrelated families. |
| 13 | Extract checked asset identity/order declarations shared by both generators (F06) | Independent of runtime catalog relocation if row IDs remain identical; duplicate contribution test and byte-identical art. |
| 14a–c | Move native livestock, building, then furniture artist families, one family per commit (F19) | After 13; keep source/generated output stable. These are repeating commit templates, not three omnibus commits. |
| 15a–d | Apply the same family-at-a-time moves to character, terrain, crops and snags/seasons, including classic counterparts when touched (F19) | After the relevant provider seam; do not combine independent artists in one commit. Use §6's table as the work list. |
| 16 | Introduce composed BackpackGrid and migrate CampfireScreen (F05) | After #109; preserve hover/drop/focus and badges. |
| 17a–b | Migrate ProcessScreen then StorageScreen to BackpackGrid, separately (F05) | Chain after 16/06; station rules and chest ordering remain distinct. |
| 18 | Introduce target-kind loading and migrate ActivityPlaces/rule target metadata (F10) | New target file registers; same default day/travel behavior. Do not rewrite scheduler. |
| 19 | Consolidate character-page registration around page/list descriptors (F11) | After all #109 page commits; existing panels still compose ScrollingList. |
| 20 | Consolidate scene feature installation/interaction openers and local sound registration (F11) | After 05/06 and #109; one existing feature per commit. Main retains explicit input/layer order. |
| 21a–c | Extract player travel/riding, rest/location, then pickup/drop from GameState, separately (F13) | Serial GameState integration; same headless actions and outcomes. Coordinate callers from 06/20. |
| 22a–b | Extract session construction/system installation, then game save reconstruction, separately (F13/F12) | After 21/09; each move migrates its callers. No permanent duplicated installation path. |
| 23a–c | Extract WorldEdits, WorldBuildings, then environmental execution adapters, separately (F14) | Serial World integration, after validator/codec seams; replay/unloaded/signal-order coverage. |
| 24a–d | Extract livestock motion, needs, chicken roosting, following, separately (F15) | Stable priority/RNG, live vs synchronous/frame-spread skip regressions. |
| 25a–c | Extract terrain-chunk drawing, object presentation, tree-fall effects, separately (F16) | Stable aggregate budget/settle status and chunk-unload cleanup; visual checks. |
| 26a–c | Extract KeyBindings, settings engine application, then provider ownership, separately (F17) | Preserve one-file preferences, binding conflicts, profiles and signal timing. |
| 27a–c | Extract coast layout, dyke layout, vegetation placement, separately (F18) | Fixed seed/query/chunk-order fixtures unchanged; generation is saved-world identity. |
| 28a–c | Extract roof/nest placement, saved farm-animal presentation, then the animal constructor registry, separately (F18) | Same ambient spawn/clear/skip behavior; no new persistence. |
| 29 | Replace the manually growing startup gate with checked topic check contributions (F09) | After catalog/target seams; explicit dependency order and all required family checks. |

Steps with letter ranges are **individual commits**, not permission to squash multiple moves. If a move becomes too broad, stop at the smallest complete family with all callers migrated; verify it and integrate it before the next.

### Which work can run in parallel without touching the same files?

The project's one-task-at-a-time queue rule still governs execution; this is a conflict map if parallel work is authorized, not authorization to start workers. Shared documentation (`docs/architecture.md`, `docs/ui.md`, `tools/README.md`) and central test helpers are serialized with their integration steps; two otherwise independent code lanes must not both edit them. Give leaf work its domain-local notes/tests, then integrate shared-guide updates in sequence.

| Work lane | Exclusive source/test ownership | Can coexist with |
|---|---|---|
| Pure boundary repairs 03 and 04 | 03: NpcBubbles/NpcSpeech and bubble tests. 04: Tide/SeaSearch and sea/tide tests. | Each other and 01; no Main edit required. |
| Save structure 08–10 | SaveValidator/new save modules/SaveFile and save-specific tests; no new runtime state fields | Backpack 16, activity targets 18, art 13–15 after their prerequisites. Hold World/GameState codec moves until this lane lands. |
| Content 11–12 | ItemTypes/WorldObjectTypes/catalog declarations and catalog tests | Art declaration work 13 if numeric rows/IDs are frozen and it touches no catalog tests; settings 26. |
| UI backpack 16–17 | New BackpackGrid, container screens and their dedicated tests | Save modules, activity targets, art modules. Never overlap #109, chest repair 06 or scene routing 20. |
| Activities 18 | ActivityRules/ActivityPlaces/new target modules and activity-target tests | Backpack, save structure, settings, art; do not edit GameState setup. |
| Livestock 24 | Livestock/new animal operations and dedicated animal tests | WorldView drawing 25, settings 26, generator 27, art family work with disjoint generated paths. No simultaneous GameState changes. |
| Rendering 25 | WorldView/new drawing presenters and view-specific tests | Livestock 24, settings 26, generator 27. Wildlife extraction 28 waits if it needs the same WorldView-facing API/tests. |
| Settings 26 | GameSettings/KeyBindings/application adapter and settings tests | State/content/art lanes, but adapter installation in Main is serialized with 20. |
| Generation 27 | WorldGenerator/new layouts and generation-specific tests | Livestock, rendering, settings. Do not mix world-generation behavior changes with moves. |
| Art leaf providers after 13 | One artist family, its tests, and that family's generated paths | Another family only once assembly/registry edits are no longer shared. Classic/native same-family work stays in one lane. |

**Serial choke points:** Main (05/06/20 and adapter installation), GameState (21/22), World (23), catalog assembly (11/12), save-version allocation, asset declaration/season registry installation, and shared docs. “Different features” is not a safe parallel boundary while those files are shared. Land the seam first; only then fan out leaf additions. The new shape should demonstrably reduce edit sets, rather than just distribute helpers across more files.

## 8. Assessment of the in-progress UI refactor (#109)

I read both `build/ui-refactor-proposal.md` and `build/ui-refactor-agreed.md`, plus `git diff main...worktree-agent-aed32b3173ad29c95` and its commits. The observed branch tip was **`084cb557`**:

- `85b3f99e`: row tooltip hover ownership fix.
- `5219f965`: Neighbours rows scroll beneath a persistent title, with viewport/scroll preservation tests.
- `084cb557`: Quests uses the same composition; its old incidental child lookup is updated.

CharacterScreen now appends the two nested lists and resets/refits on tab selection. Those changes address the specific omissions identified in the agreed review. Do not schedule them again. Skills scrolling, portrait refresh, Audio/Game/notice-board scrolling, UiColors, theme variations and BuildMenu styles remain reserved to the rest of that agreed ten-commit sequence; this review does not claim those unimplemented commits were inspected as code.

**Direction: correct.** Composition fits the differing page lifecycles. Skills is signal-driven; Quests/Neighbours have snapshots/polling. BuildMenu must remain a non-modal overlay with wheel/world-click passthrough. Colour roles/theme variations are better than common UI inheritance. Chat plates and speech bubbles remain legitimately different concepts.

**After all ten commits, these structural issues still remain by scope:**

1. Backpack construction/binding/dimming repeats (F05); palette/theme consolidation cannot remove it.
2. CharacterScreen must still learn each page's binding/refresh/list contract. The branch's explicit list registration is appropriate for this small fix, but repeated future page additions justify the registration seam in F11. Do not replace all panels with a polling TabPage base.
3. A new specialized screen still needs Main/Interaction/ActionHint/InteractFlow wiring and sound registration (F11).
4. Chest-taking authority remains in StorageScreen (F04); scroll/style work cannot fix that.
5. Domain rules should answer acceptance/amounts; screens should choose layout and format text. Retain current ProcessStation/ItemSlots boundaries rather than hiding them behind a generic GUI framework.

The repeated 0.25-second refresh scaffolding in Quests/Neighbours is too small to justify another class now. Nested list registration, mouse ownership, narrow wrapping and focus should be verified as behavioral contracts, not by hard-coded descendant indices. #109's tooltip fix is already progress in that direction.

## 9. What not to do

- No ECS rewrite, global event bus, service locator, universal Entity/Manager, or event-sourced persistence. Existing direct commands and signals for committed facts are suitable.
- No automatic directory loader for systems with hidden order dependencies. Explicit system order and scene input/layer order are part of behavior. Use discovery where IDs and independent contributions make it safe: content/target kinds/migrations with checks.
- No script subclass per ordinary item, scalar setting or save field. Use topic-sized declarations and domain codecs; make new content of an existing capability data-only.
- No Rules base class merely to remove the few repeated cache/load/report functions. DataFile is already shared. A small primitive validator is worthwhile only where several real schemas need the same type/range semantics.
- No universal transfer policy for chests, equipment, campfire fuel, station grids and demolition. Share accounting and presentation primitives while preserving their different rules.
- No persistent ambient wildlife rewrite, generic behavior tree or merged NPC/animal locomotion engine. Their current lifetimes and walking policies differ intentionally.
- No native/classic mega-artist with a parameter for every pixel difference. Share identity/manifests and actual geometry helpers only where they truly agree.
- No file-length target as the acceptance criterion. A 950-line topic may be coherent; a 100-line close callback can own the wrong domain fact. Do not replace named APIs with arbitrary string dispatch solely to get below 20 methods.
- No blanket getters/copies for every state read. Encapsulate mutation, reference invariants and durable operations first; scenes reading plain state is an intended design rule.
- No mass test reorganization or assertions about private child order. Keep existing focused cases, add load/commit/hold regressions at the boundaries that failed, and let leaf features own their fixtures.

## 10. What I did not check

- No runtime reproduction, game/test/lint execution, export run, screenshot, audio listening, benchmark or memory soak; no current green-suite or performance claim.
- No reads outside this repository, player saves/settings, external services, issue comments or worker processes. No branches were checked out and no code was changed.
- #109 was inspected only through the three commits and agreed plan above; its remaining commits were assessed by intended scope, not hypothetical implementation details.
- The source census covers all scoped scripts; detailed inspection concentrated on ownership paths, feature registration, persistence, UI, generation and the large-file responsibilities. I did not line-review every test assertion, shader, tracker/DSP algorithm or individual artist's pixel geometry. Audio/music and tooling boundaries were sampled; no new sound/music correctness finding is claimed.
- Historical tests/probes from the November 9 report were not rerun. Its recommendations are marked implemented where current source supports that conclusion, not as a fresh runtime certification. Unrelated pre-existing working-tree documentation changes were left alone.
