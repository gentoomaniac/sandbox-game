# Game Design Review — 2026-11-11

**Baseline:** `ddb588e37dfeeb5b4347bb2a19e84035880fb16d` (2026-11-11).
**Type:** design/document review, not a playtest or another architecture audit.
**Status:** recommendations for discussion; this review changes no game rules or task priorities by itself.

## Verdict

**The game has a distinctive place and a substantial set of working activities, but has not yet
connected them into a self-contained player journey.** Its strongest promise is not simply
“Stardew Valley with more systems.” It is making a home in a living North Frisian landscape:
reading the weather, choosing where to settle, working the land and becoming known to neighbours.
The coast, worked fields, period houses, animals and sound already support that identity.

The next design milestone should prove **why the player wants another day**, not how many more
things can be simulated. Three priorities follow:

1. **Close the non-console loop:** replacement seeds, understandable farming, reachable people
   and a reason to use surplus. Do not make the full economy a prerequisite for testing this.
2. **Protect room for exploration:** establish how long a player can leave home without losing
   their work, and make weather, exhaustion and social consequences understandable beforehand.
3. **Make progression change play:** useful crafts, meaningful homes and social recognition,
   rather than more numbers and repetitive production without a purpose.

This does **not** require a compulsory story, quest treadmill, land ownership, harsher survival,
or combat. Player-authored building and observation can be worthwhile ends in themselves.

## Scope and design intent

Sources are the gameplay pages in [design/](../../design/README.md), the open and later work in
[TASKS.md](../../TASKS.md), the current [README](../../README.md), and selected balance data and
rules. Existing [art](../art-review-2026-11-08/README.md),
[resolution](../resolution-mockup-2026-11-08/README.md) and
[technical](../code-review-2026-11-09/README.md) reviews were checked for context. Their historical
missing-asset lists and technical defects are not treated as current design findings.
`.claude/` and its worktrees were excluded.

The review uses four distinct statuses:

| Status | Examples | Treatment |
|---|---|---|
| Implemented | Farming, weather-driven growth, building, stations, sleeping, animal needs and petting | Assess how these connect; do not recommend rebuilding them |
| Decided, unbuilt | Gossip tasks 125–130; queued UI, harvest and presentation changes | Review their dependencies and player-facing risks |
| Draft, not decided | Detailed economy and relationship proposals | Discuss options, not acceptance criteria for implementation |
| New proposal | The milestone, information improvements and tests below | Needs approval before becoming work |

Preserve the four [pillars](../../design/README.md#pillars): a steady home loop, exploration,
optional combat and free building. Also preserve no land ownership, preset-based buildings
with customisation, peaceful viability and useful play without a language model.

**Priority labels:** P0 = resolve before calling the next slice self-contained; P1 = important
to that slice or before the named dependent feature; P2 = validate after it. These are design
priorities, not an instruction to interrupt the user's existing queue.

## What already works

- **A recognisable place.** Ditches, Knicks, the Geest, marsh, Warften, reed roofs and regional
  people give the game a stronger identity than another generic set of fantasy biomes.
- **Activities change the home visibly.** Clearing, planting, storage, stations, buildings and
  furniture let the player see their own work accumulate. Free building is a genuine source of
  goals; not every house needs to unlock a new resource tier.
- **Several systems already interlock.** Food restores work energy; clay becomes bricks for an
  oven; stations give a yard its purpose; wells and fresh water affect where farming is convenient.
  A kiln started before bed being ready later is a good reason to plan a day.
- **The year matters beyond a palette swap.** Crop requirements, rain and drying, reeds,
  forage and wildlife change the rhythm. Preserve the existing hourly growth and overnight
  advancement rather than proposing them as new features.
- **A forgiving base exists.** Walking costs no energy; a starting bedroll restores fully;
  passing out does not remove items or money; current unmet animal needs cause no suffering.
  Those choices support experimentation.
- **Social foundations are unusually specific.** Eight connected authored villagers, shared
  local knowledge and remembered conversations can make recognition more personal than a generic
  gift meter. Gossip could connect building and farming to that social world.
- **Feedback is already substantial.** Targeting, placement ghosts, material shortfalls,
  item tooltips, sounds and tiredness signs are valuable. The main information gap is explaining
  longer-term consequences, not an absence of feedback everywhere.

## Priority design findings

### GD1 — A new player cannot reach much of the advertised game through ordinary play

**P0 · Confirmed access gaps; onboarding consequences are hypotheses.**

The [starting inventory](../../game/state/inventory.gd) has tools, a hammer and 15 turnip seeds.
It does not offer the other crop seeds. [Villagers](../../design/villagers/villagers.md) and
[livestock](../../design/farming/livestock.md) are introduced through console spawning; the
[lantern](../../design/player/inventory-and-character.md) has no recipe and is obtained with
`give`. The village exists richly in text, but not as an ordinarily discoverable populated
settlement. Building and basic crafting work without these additions; the broader life-sim
journey does not yet.

**Risk:** a developer knows which command demonstrates each feature; a new player may conclude
that those features do not exist. “No shop yet” is an honest prototype limit, not a reason to
build every trade system before fixing access.

**Recommendation:** approve one modest starting scenario using existing assets. Teach tilling,
planting, watering/refilling, making an empty hand, eating, crafting and sleep through short
contextual prompts or discoverable instructions—not a compulsory tutorial campaign. Provide:

- a repeatable, discoverable seed source and a way back after losing the starter crop;
- one named neighbour at a real reachable location, with a useful non-model interaction;
- one non-console route to light for the already-dark nights;
- one optional short goal that connects production to another person or home improvement.

Giving, earning, finding or trading these things are **choices to approve**, not decisions made
here. All eight villagers, a complete town, every animal species and Husum can wait. If the
project is intentionally a developer sandbox, say so instead and evaluate it on that basis.

**Success test:** a fresh player completes a harvest, replants, makes a useful improvement and
finds a neighbour without console commands or verbal coaching.

### GD2 — Occasional seed returns need a replacement supply in the same playable slice

**P0 · Mathematical dependency in task 178, not a defect in its unbuilt implementation.**

[Crops](../../design/farming/crops.md) currently return one seed per harvest;
[task 178](../../TASKS.md#178-harvests-vary-a-little-and-now-and-then-give-a-seed) makes returns
occasional. The [economy draft](../../design/economy/README.md#shops) still assumes
the guaranteed seed. The task already asks for sustainability analysis: that requirement needs
a concrete answer, not just plausible-looking percentages.

For a single-harvest crop returning **at most one seed** with probability `p`, and no other seed
source, expected planting stock after `n` successful generations is `N₀ × pⁿ`. With 15 starters
and an illustrative `p = 0.8`, only about 4.9 seeds remain after five generations. For any
`p < 1`, even a perfectly tended closed farm eventually runs out. Crop deaths accelerate this.
Extra produce does not solve it unless produce can become seeds or pay for replacements.
Regrowing crops need separate analysis: repeated harvests can instead accumulate seeds.

**Recommendation:** keep the requested variability, but ship an approved replacement route
with it: seed purchase/barter, seed saving, or a renewable in-world source. Any temporary rule
or sequencing change needs the user's agreement. Essential recovery seeds must not depend on
good friendship, a model response, or having produce left after a total crop loss.

Two numerical decisions are needed before choosing defaults:

- A yield restricted to 2 or 3 cannot average **exactly 2** while sometimes giving 3. Clarify
  whether the task's carrot example means “usually 2” or permits a lower result too.
- Define the unit of a “bag”: the current seed item plants one tile. Future prices quoted
  per bag are meaningless until the number of plantings is clear.

**Success test:** trace seed stock through repeated harvests, winter and a failed crop, with
no console. Document replacement cost and recovery route; do not require farming to be
profitable forever without trade if buying seeds is the approved design.

### GD3 — Agronomy is deeper than the information available for learning it

**P1 · Confirmed rules/information mismatch; perceived unfairness needs playtesting.**

Growth depends on warmth, light, moisture and wind; damage can kill crops; ripeness has a
deadline. The [crop rules](../../data/crops.cfg) and [CropLife](../../game/state/crop_life.gd)
explain this precisely, but the [seed tooltip](../../game/state/item_tooltip.gd) chiefly says what
grows and where to plant. Detailed crop status is available through the debug `crop` command.
The four soil shades help, but the deliberate rain-wet surface can appear wetter than the
underlying moisture actually is.

**Risk:** a dead field teaches “the game is unpredictable” instead of “this crop was unsuitable
for this weather.” Complexity becomes interesting only when it supports a decision.

**Recommendation:** expose a small player-facing explanation, not the entire simulation:

- seed guidance in plain language: cool/warm weather, water demand, wind tolerance, approximate
  good-condition growing time;
- an inspectable crop state: growing, slowed by cold/dryness, damaged, ripe, withering risk;
- a truthful distinction between a wet surface and adequately watered roots;
- a useful warning before irreversible loss, plus the action the player can actually take.

Forecasts or seasonal advice are options to discuss; neither requires a perfect weather oracle.
Do not imply that a building provides wind shelter until shelter actually changes crop rules.
Do not make players discover every threshold through losing their first harvest.

**Success test:** after a dry spell and a windy spell, players can explain the dominant problem
and whether they can fix it, without inspecting configs or the console.

### GD4 — The home loop needs an explicit allowance for being away

**P1 · Existing rules create a tension with exploration; balance is not playtested.**

The game promises more exploration than its genre peers, but water, crop damage, harvest
deadlines and daily animal petting create reasons to return. Animal friendship currently loses
5 per unpetted day: an animal at 100 reaches 0 after 20 absent days, although the value has no
gameplay use yet. Food/water stocks already offer a useful preparation mechanism; needs
currently have no adverse consequences. The later proposals for costly husbandry and hired
hands could change this balance considerably.

[Exhaustion](../../design/player/energy-and-sleep.md) adds another pressure: low energy slows
the journey home; collapse then imposes half speed and at most half energy for the next day.
The warning signs and explanation already exist. The untested question is whether recovery
feels like a story or a second day of punishment—especially on a first expedition. Horses
help travel, but currently require console access to horse and saddle.

**Recommendation:** choose an absence target to test. An initial candidate is a full day trip,
then a prepared two-night trip. This is a **test target, not a new guarantee**. Measure:

- how long stocked food/water and crop moisture last;
- which crops can safely be left and which require a timely return;
- which setbacks are recoverable and what information makes departure an informed choice;
- whether exhaustion recovery leaves a satisfying action besides sleeping again.

Before needs or friendship affect produce, approve a coherent care policy. Preparation,
resilient crops and later help can preserve exploration; an ever-growing daily click checklist
will undermine it. Do not silently remove the user's decided petting decay or add animal death.
Test a genuinely distant home as well as overnight advancement beside the farm: the player
should understand which care continues while they are away, not need to reason about loaded chunks.
Ground sleeping is described in the design but explicitly not implemented in the energy data;
do not count it as a current expedition fallback.

**Success test:** someone can deliberately leave a prepared farm, enjoy a destination and
return to understandable consequences rather than discover that exploration was a mistake.

### GD5 — Craft progression has gates, but too few reasons to produce at scale

**P1 · Structural risk supported by current recipes; grind duration is unmeasured.**

[Professions](../../design/crafting/professions.md) have use-based gain, visible requirements,
falling returns and a 200-point total cap. Those are real mechanics, not missing features.
However, three master recipes at 70 require 210 points to retain simultaneously; some
specialisation or fading is unavoidable. There is no functioning NPC trade alternative yet.
The [ideas page](../../design/crafting/ideas.md) already recognises the danger of importing a
multiplayer-style cap into single-player without someone who supplies the missing craft.

Current [recipes](../../data/recipes.cfg) give woodworking useful early outlets in pens and yard
equipment. Later storage expands from 15 to 20 to 25 slots, while more basic chests are cheap.
Masonry improves firing efficiency, but bricks have a narrow current outlet in ovens; houses
still consume raw clay. Cooking has an immediate energy benefit, but varied ingredients beyond
turnips are not readily supplied to a new game. Extra crafts may become practice products
rather than things the player wanted to make.

**Recommendation:** retain the existing cap pending evidence, but test one complete craft path
before adding more professions or repeated stat progression. Track useful output versus items
made only to gain points, resource trips and repeated clicks. Give each chosen milestone an
actual use: a desired yard object, a meal for work, storage that suits a room, or an approved
commission/trade outlet. A commission is a possible small experiment, not a demand for a quest
framework or permission to adopt the entire economy draft.

For [task 187](../../TASKS.md#187-character-attributes-strength-agility-hp-and-stamina), honour
base-value compatibility and its plan-first requirement. Settle what Strength's carrying
capacity means alongside the existing weight surcharge; do not accidentally impose both a new
hard limit and the old penalty without approval. Agility has no decided effect, and attribute
growth is open. Label inert attributes honestly; do not invent speed bonuses or a levelling
curve merely to fill the screen.

**Success test:** players can name a capability or desirable object they are working toward,
and reach it mainly by making things they use. Test the cap near 200 separately; do not wait
for a fresh-session playtest to discover it.

### GD6 — Homes and husbandry need clear promises, not necessarily more bonuses

**P2 · Intentional incompleteness, with expectation risks.**

The [starting bedroll](../../data/energy.cfg) restores 100 energy; the shack's mat restores 80,
and larger house beds restore 100. A house can therefore be aesthetically desirable and offer
interior space without being an energy upgrade. That is compatible with the stated principle
that better beds should eventually feel like bonuses, not escape from a penalty. It should not
be sold as a mechanical improvement that it does not provide.

Similarly, the barn's art suggests livestock accommodation, but only the coop currently houses
animals and produces collectable eggs. The pig shelter is not used for sleeping yet. Needs and
animal friendship currently change behaviour or internal values, not production; eggs have no
cooking use yet, and milk/wool are later work. These are prototype boundaries, not reasons to
add death, spoilage or roof maintenance now.

**Recommendation:** tell the truth in building/item descriptions: what works now, what is
decorative, what capacity it provides. Ask which first home improvement should be felt—layout,
storage, cooking convenience, appearance, or a later comfort benefit. Then connect **one**
husbandry output to a use and provide a way to acquire the animal before expanding products.
Do not force every building style to be a superior tier or replace free building with a fixed
upgrade ladder. Moving a house currently returns only half its materials; test the cost of
early placement regret before increasing settlement pressure.

**Success test:** players choose a house or farm-yard investment for a reason its current
mechanics actually support, without expecting a barn to house cows automatically.

### GD7 — Gossip can make the world personal, but social consequences need a fair contract

**P1 before opinion affects important access · Decided feature; unresolved interactions.**

[Gossip](../../design/villagers/gossip.md) is a strong bridge between the pillars: people notice
the farm the player made and share imperfect stories. Its templates, recorded provenance and
bounded model output are good foundations. But witnesses currently use a radius without line
of sight, stories can change place/count/kind, and a model can judge a deed differently from
the fixed offline fallback. A cap bounds the size of a change; it does not make a negative
judgement understandable.

Three issues should be settled before attaching shop access, essential seeds or recipe locks:

1. **Free building versus offence.** The older [reputation rule](../../design/villagers/reputation.md)
   penalises building within settlement territory. If that rule remains, the affected area and
   likely reaction must be knowable before committing materials. This can be social etiquette,
   not land ownership; an invisible penalty radius would still contradict perceived freedom.
2. **One consequence path.** Reputation says one-hop spread. Gossip says meeting-based spread
   up to three hops. The undecided [relationships draft](../../design/villagers/relationships.md)
   refers to replacing one-hop propagation but also retains friendship-to-reputation-to-friends
   changes. Specify which number each mechanism changes so one deed is not multiplied twice.
3. **Fact, rumour and judgement.** The player needs to understand who saw what, who repeated it
   and what is only an opinion. If damaging rumours later have serious effects, decide whether
   and how the player can respond. Never make essential progress depend on persuading an LLM.

**Recommendation:** build the approved 125–127 observation/memory chain, then prove one social
story with two neighbours before expanding stakes. They need a real chance to meet: current
villagers stay within six tiles of their anchors, and the gossip design itself warns that few
meet. A modest shared meeting place or authored encounter is an option to approve; an entire
schedule/intentions system is not a prerequisite.

Use task 130's bubbles or chat to make the result visible. Keep task 128's approved bounded
judge, but test contradictory judgements, offline fallback and delayed replies before letting
opinions deny important services. No-model play should be less eloquent, not missing the
information needed to play. Current scripted small talk alone cannot fulfil that role.

**Success test:** after an ordinary deed, players can explain why a neighbour knows about it,
distinguish hearsay from a witnessed fact, and understand any relationship consequence.

### GD8 — The control scheme needs visible action intent as its windows separate

**P1 · Confirmed interaction complexity; error frequency is unmeasured.**

The eight starting hotbar slots are all occupied. Harvesting, foraging, petting and some gate
interactions require an empty hand, so a new player must first rearrange a tool or finish the
seed stack. That step is not obvious from “click the ripe crop.” The selected-empty-slot-last
pickup rule currently protects an empty hand once made; task 179 explicitly leaves the selected
slot decision open while changing pickup order. Filling that slot mid-harvest could change the
next click from harvesting to using the newly collected item.

[Interaction](../../game/state/interaction.gd) also gives nearby villagers priority over
chests/stations/beds; hammer mode changes E into building selection, and an empty-hand use on
a saddled horse removes the saddle before petting. These rules are decided, but a tile highlight
alone does not always explain them.

**Recommendation:** show a small action-and-target hint for the action that will actually run:
“E: Talk to Antje”, “E: Open chest”, “Use: Refill”, “Use: Remove saddle”. Teach making an empty
hand; discuss a direct empty-hand affordance if rearranging tools proves cumbersome. Resolve
task 179's selected-slot policy with harvesting tests, not pickup-count tests alone.

Tasks 190–191 correctly specify B for bag, C for character and temporary Shift+C for hand
crafting. Preserve that decision. Give hand crafting a visible entry so a critical early action
is not hidden behind the stop-gap shortcut. With only one modal open, verify that inventory-to-
equipment transfers remain understandable when bag and character no longer share a window;
do not assume movable modals imply simultaneous windows.

Finally, bag/storage/crafting time currently runs while chat pauses. Moving windows (189) and
reading new attributes should not accidentally change this policy. Test how much of a short day
a newcomer loses arranging items or reading recipes. If that pressure is not intended, ask for
a pause-policy decision rather than silently changing it during the UI split.

**Success test:** players can harvest, refill, craft and equip something without unintended
actions, shortcut memorisation or accidentally spending the end of their day in a menu.

## Core loop, progression and pacing

### The intended loop and its missing connections

| Rhythm | Player question | Existing support | Connection to prove next |
|---|---|---|---|
| Moment to moment | What can I do here? | Tools, targeting, drops, sound, placement ghosts | Clear action intent and an accessible empty hand |
| A day | What do I work on, and when do I stop? | Energy, food, weather, sleep, station timers | A readable work budget and satisfying recovery |
| Several days | Why plant/build this rather than that? | Crop requirements, recipes, pens, storage, houses | Seed supply, useful surplus and a meaningful next investment |
| An expedition | What is worth leaving home for? | Coast, landscapes, wildlife, movable camp, riding | A discoverable destination, navigation home and an informed absence budget |
| A season | What changes my plan? | Weather, forage, crop suitability, shorter winter light | Seasonal advice and a viable winter activity/access plan |
| Longer term | What sort of home and neighbour am I becoming? | Customisation, craft cap, authored villagers, memory | Recognition, optional specialisation and chosen projects with useful outcomes |

**Suggested first journey, not a scripted quest chain:** learn the camp → plant a modest bed →
make storage/workbench → cook some produce → improve a home or yard → visit a neighbour or
coastal landmark → return with something useful or newly understood → choose the next project.
There should be multiple acceptable orders; building-focused players need not become dedicated
farmers, and explorers should not be required to maximise every crop.

### Useful baseline numbers—not measured player experience

- One game day is 16 real minutes before sleep or pauses
  ([GameClock](../../game/state/game_clock.gd)). From a normal 06:30 wake to the 01:00 collapse
  threshold is **12 minutes 20 seconds** of unpaused real time. A 30-day season at that waking
  schedule is about **6 hours 10 minutes**; a year about **24 hours 40 minutes**. Earlier sleep
  reduces those totals, while pauses increase them. The later “young animals take at least a
  year to mature” proposal is therefore a major pacing commitment, not just a believable date.
- At normal drain below the weight threshold, tilling, planting and watering 15 starter tiles
  costs `15 × (2 + 0.5 + 2) = 67.5` energy. Harvesting later costs another 7.5. That leaves
  limited same-day energy for learning gathering/building if the player plants everything at
  once; it does **not** prove the starting budget is wrong.
- The can's 20 units cover those 15 tiles once. Another watering of 15 dry tiles costs 30
  energy. Water only when needed: actual rain and drying determine how often this is necessary.
- Turnips need three transitions at three growth points each: **nine perfect growth days**.
  Real weather can take longer. This is not a nine-minute tutorial payoff, nor a measured
  first-harvest time. Give players a short useful achievement before the first crop ripens.

Avoid balancing each subsystem in isolation. More stamina expands the workday but not the
clock; a harsher care schedule can consume that expansion immediately. More crops do not add
choices if all feed the same energy bar and none can be acquired or exchanged. Conversely,
watching migrating birds or shaping a beautiful yard is worthwhile without a numerical reward.

## Feature priorities and task alignment

**Proposed milestone: “A first season without the console.”** A player can establish a home,
complete and restart the farm loop, meet someone, make a useful product, take a prepared trip,
and understand the season's consequences. This is a proposed milestone after the already-done
technical vertical slice, not a claim that milestone 1 failed.

No task numbers are allocated here and `TASKS.md` is unchanged. Preserve work already queued
by the user; add approved integration work alongside it rather than replacing it wholesale.

| Existing work | Design assessment / dependency |
|---|---|
| **178: variable harvests/seeds** | Resolve GD2 before choosing seed defaults. Align the economy draft's seed assumption. |
| **179: hotbar-first gains** | Implement the user's order, with an explicit selected-empty-hand decision and harvesting regression scenario (GD8). |
| **188, 190, 191: HUD, bag, character** | Proceed with the approved layout/keys. Check crafting discoverability, equipment transfer and HUD information hierarchy. |
| **189: movable windows** | Already specifically queued by the user. Keep it scoped; dragging windows is not a substitute for readable controls or a new multi-window system. |
| **187: attributes** | Build only after the specified plan/Strength decision and 191. Do not let an unspecified growth loop become a second progression system by accident. |
| **125–127: deeds, memory, spreading** | Strong integration value once real neighbours and a meeting opportunity exist; use a small playable example, not console-only proof. |
| **128–130: judge, learned village knowledge, bubbles** | Make recognition visible. Reconcile propagation rules and test offline/judge differences before consequential opinion gates. |
| **181: doorway behaviour** | Supports credibility and approachability of neighbours. It does not provide their acquisition, homes or schedules. |
| **176, 186: wind/audio coherence, snow footsteps** | Worth fixing: contradictory sensory signals weaken trust in the world. These are already tasks, not new review discoveries. |
| **185: gradual seasonal cover** | Supports legibility, especially separating ground/weather appearance from farming state. Retain its plan-first scope and crop readability checks. |
| **182, 183, 194: leaves, migration, cloud shadows** | Fit the game's identity; do not dismiss them as useless polish. Keep them visual where specified—especially 194, which must not silently alter crop sunlight. |
| **180: bell** | A good small act of inhabiting the place. No need to invent a village event system to justify its first version. |
| **184, then 170–171: music access/director** | Existing route to audition approved calm pieces. Test music with wind, work and animal cues; music is not required to validate seed supply or the home loop. |
| **Later: economy and relationships** | Approve a small first interaction/outlet if useful; do not adopt every draft price, friendship threshold or ownership rule as a package. |
| **Later: windmill, breeding, hired hands, taming, more crafts** | Add when they solve a demonstrated player need or provide a desired long-term project. Breeding especially needs a real-time pacing decision. |

The best next *design decisions* are seed replacement, the starting scenario, absence tolerance
and the first useful surplus outlet. The full shop/stall economy, settlement simulation, combat,
magic and additional professions are not prerequisites for those decisions.

### Documentation decisions to settle before dependent work

- **Scope:** `design/README.md` still asks whether this is a hobby/learning project or a release
  target, and the task header still says “milestone 1” after that slice is complete. Name the
  next player-facing goal; avoid treating every later idea as a prototype requirement.
- **Setting:** the vision says “semi-fantasy, medieval,” while villagers explicitly live in
  1750 and most material culture is 1700–1800 North Frisia. Confirm the public description;
  this is not a request to redraw the art or remove future fantasy.
- **Social authority:** reconcile reputation's one-hop rule, gossip's meeting-based propagation
  and the relationship draft's additional propagation before 128 gains important consequences.
- **Current versus historical wording:** crafting still describes click-to-move chests despite
  the implemented drag rules; the weather page says crops do not react yet despite the crop
  rules. Update those statements when the affected pages are next edited. Pending B/C/Shift+C
  changes should remain pending until their tasks merge.

## Playtest plan

**None of these sessions has been performed for this review.** Start with a few fresh players
(for example 3–5), then repeat after changes. Small sessions reveal problems; they do not establish
statistical balance. Log the first confusion and its cause, not just whether a feature was used.

| Session | Setup and question | Evidence / provisional pass condition |
|---|---|---|
| **Fresh start, 30 minutes** | New save, defaults, no model, no console, no coaching. What does the player think the game asks of them? | Can plant, refill, make an empty hand, eat, craft and sleep; identifies a next project. Record time in menus, unintended actions and requests for help. Do not demand a full harvest within this session. |
| **Farm continuity** | Follow through first harvest and replanting across multiple days; separately test crop loss and a winter save. | Replacement route is findable and affordable/recoverable. Record seed stock, weather losses, food eaten and surplus use. Separate debug-assisted setup from ordinary-play results. |
| **Prepared expedition** | A small farm, stocked yard and a known destination; attempt a day trip, then two nights after preparation. | Player predicts what needs attention, can navigate home without debug coordinates, and explains any losses. Record chores as a share of the waking day and whether the player chooses another trip. |
| **Exhaustion recovery** | An explicit separate test just before energy collapse and another near 01:00. | Warnings are noticed, recovery understood, and the next day offers a satisfying option. Record avoidable mistakes versus knowingly accepted risk. |
| **Craft identity** | Early workbench progression, then a prepared save near the total skill cap. | Player understands the next useful unlock and Fade. Count unwanted practice output, material trips and clicks; ask whether specialisation feels chosen or obstructive. |
| **Two-neighbour story** | Once 125–130 exist, perform one deed and allow a real meeting; test templates, then a configured model and a failure case. | Player can identify source, distortion and opinion. Mechanical information remains available without a model; no unexplained indispensable service loss. |
| **Interface / seasons** | Both art modes, widest zoom, supported window sizes, enlarged UI, a dark night and winter. | Action targets, crop status and energy warnings remain readable; split bag/character supports equipping; visual wetness/snow/clouds do not communicate nonexistent mechanics. |

For longer-term claims, use both ordinary continuation and prepared saves. A prepared year-2
save can test winter feedback or cap behaviour; it cannot prove that playing a whole year to
reach it is enjoyable.

## Decision and implementation handoff

These are **proposed briefs**, not approved additions to the backlog. Each should first receive
the user's answer to its design question, then be split into ordinary implementation tasks.

| Order | Brief | Decision required | Definition of done |
|---|---|---|---|
| **A** | Seed continuity, coordinated with 178 | Where do new/replacement seeds come from; how many plantings per bag; what yield distribution was intended? | Document expected replenishment and a crop-loss recovery route; acquire/replant in ordinary play; test non-regrow and regrow crops separately. |
| **B** | Minimal starting-world scenario | Where is the first neighbour, what light can be obtained, and what optional first goal introduces the place? | A new save exposes the chosen loop without spawn/give commands. Reuse assets; no requirement for a complete settlement. |
| **C** | Farming/action information, coordinated with 179–191 | How does the player inspect a crop, select an empty hand and discover hand crafting? | Plain-language causes and real action intent are available; first-time players complete the core interactions without coaching. |
| **D** | Absence and recovery balance | What trip length should preparation support, and how demanding should care/exhaustion be? | Test the chosen trip with actual stocks and weather; record recovery options. Change decided penalties only after approval. |
| **E** | One useful production path | Which product/home improvement matters first, and does surplus have an outlet? | One path from acquisition through production to a desired use works without placeholder commerce, unnecessary practice stock or a new profession framework. |
| **F** | One socially legible story | Which opinion/reputation rules apply, and what can they affect at this stage? | Two reachable neighbours witness/share/respond; source and stakes are understandable; no-model play retains necessary information. |

Suggested gates: **A and B before claiming self-contained progression; C before judging
onboarding; D before adding husbandry penalties; E before expanding professions; F before
opinion locks important access.** Existing tasks can continue independently where they do not
depend on these answers.

## Sources and limitations

Primary evidence:

- [Vision, pillars, milestones and exclusions](../../design/README.md).
- [Open tasks and later proposals](../../TASKS.md), including the user-confirmed constraints
  inside individual briefs.
- [Farming](../../design/farming/crops.md), [resources](../../design/farming/resources.md),
  [livestock](../../design/farming/livestock.md), [crafting](../../design/crafting/crafting.md),
  [professions](../../design/crafting/professions.md), [building](../../design/building/README.md)
  and [first buildings](../../design/building/first-buildings.md).
- [World generation](../../design/world/generation.md), [coast](../../design/world/coast.md),
  [weather](../../design/world/seasons-and-weather.md), [wildlife](../../design/world/wildlife.md),
  [energy/sleep](../../design/player/energy-and-sleep.md) and
  [inventory/tools](../../design/player/inventory-and-character.md).
- [Villagers](../../design/villagers/villagers.md), [dialogue](../../design/villagers/dialogue.md),
  [gossip](../../design/villagers/gossip.md), [reputation](../../design/villagers/reputation.md),
  and the **undecided** [relationships](../../design/villagers/relationships.md) and
  [economy](../../design/economy/README.md) drafts.
- [Menus/HUD](../../design/presentation/menus-and-hud.md),
  [look](../../design/presentation/look.md), [sound](../../design/presentation/sound.md),
  [README's implemented-feature descriptions](../../README.md), and the linked current
  data/rules used for the numerical checks above.

No gameplay session, usability study, economy simulation, screenshot comparison or performance
benchmark was run. Numerical examples are direct calculations from the cited baseline, not
observed averages. Statements about confusion, grind, fairness and enjoyment are testable design
hypotheses. The review does not re-audit save safety, networking, architecture or technical-review
completion; nor does it independently validate historical price accuracy.

**Bottom line:** keep the distinctive world and freedom. Connect a few existing systems into a
journey that survives without the console, explains its consequences, and leaves time to go
somewhere new before making that journey more demanding.
