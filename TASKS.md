# Tasks: Prototype

Implements milestone 1 from the [design](design/README.md). Each task is small enough for one
developer brief. Tasks whose dependencies are done can run in parallel. This file holds only the
open tasks and the later ideas: when a task is merged, it is ticked, given its "Done:" note and
moved with its full text to [docs/tasks-done.md](docs/tasks-done.md) (the user, 2026-11-09).

SPEC.md became the [design/](design/README.md) tree on 2026-11-08. Old task notes below that say
"SPEC" mean those pages; "SPEC.md" and its section names are history.

Finished tasks live in [docs/tasks-done.md](docs/tasks-done.md). Their numbers still mean the
same: the design and code comments refer to them.

Rules for every task:

- Use only make targets for build, run, test and lint. A new multi-step command gets a new
  make target.
- Keep game state (world, tiles, buildings, crops, time) in plain GDScript classes with no
  rendering or input code. Scenes only read the state and send actions to it.
- State logic gets GUT tests (`make test`). Rendering and input are checked by hand with
  `make run`.
- `make lint` passes.
- Visuals come from the art generator (task 5 on). Until a task adds art for something,
  use simple placeholder shapes in palette colours.

## 125. The deed log: what the player does near villagers, and who saw it

- [ ] Done

The deeds come from the action outcomes of task 143: listen to `GameState.action_done` (see
game/state/action_outcome.gd; a hammer take-down is `take_down` for a placed object and
`demolish` for a building).

From design/villagers/gossip.md (Deeds). No language model in this task.
- A `data/gossip.cfg` with the deed kinds (felled a tree, built a building, took down a building,
  placed a fence or wall, tilled, sowed, harvested, dug clay, mowed), each with its words and a
  fixed opinion change for later, the radius (20 tiles, 6 at night) and the place words per biome.
- A deed log in the game state, saved (save version bump): each deed within 20 tiles of any
  villager as `{day, minute, kind, count, place, witnesses}`; the same kind and place on the
  same day merge, adding up the count and the witnesses. Kept for 7 days.
- The place in words: "by <name>'s house" for the villager whose home is nearest within 20 tiles,
  else the biome's word.
- Every villager within the radius is a witness and gets the deed as a story they saw at once,
  for now kept in a plain list on the villager (task 126 makes it the gossip buffer). The chat
  prompt tells it as a template line ("Today you saw the newcomer fell 7 trees by Antje's house.").
- Console: `deeds` lists the log.
- Tests: logging, merging, witnesses by radius and night, the place words, save and load.

## 126. Villager memory in three layers: knowledge, short-term, long-term

- [ ] Done

From design/villagers/gossip.md (Memory). Needs 125.
- Knowledge: the sheet, and the village sheet for villagers of data/villagers.cfg (as today).
- Short-term: the chat buffer (`chat_history`, as today) and a gossip buffer of stories (the
  witnessed deeds of 125; a story as on the design page: fact, seen or heard, told_by, seen_by,
  hops, day learned, line, weight, personal), both first in, first out.
- Long-term: memories become `{day, text, weight}` (low, medium, high). Full: the lightest goes,
  between equal weights the oldest. This replaces the merge of the oldest two.
- Leaving the chat buffer: summed up as today, weight medium. Leaving the gossip buffer: low is
  forgotten, else the line moves to long-term with its weight. High: a deed by their own home or
  that of family or friends on their sheet.
- Settings "Stories a villager keeps" (default 10) and "Memories a villager keeps" (default 20),
  next to "Lines a villager keeps".
- The prompt tells knowledge, long-term, gossip and chat in that order; `/clear` forgets all but
  knowledge.
- Save version bump; old memories load as medium.
- Console: `gossip <villager>` lists their stories and memories with weights.
- Tests for the buffers, eviction by weight, save and upgrade; docs in dialogue.md.

## 127. Rumours spread when villagers meet, and change on the way

- [ ] Done

From design/villagers/gossip.md (How stories spread, Whispers). Needs 126. No language model.
- Two villagers within 3 tiles meet, a pair at most once an hour of game time. Each may pass one
  story the other lacks: the weightiest and newest that it has known for at least 2 game hours,
  with a chance by tie (family and friends from the sheet, the 3 nearest neighbours by anchor,
  anyone), values in data/gossip.cfg. The hearer gets it as heard, `told_by` the teller, one hop
  more. A deed's story stops after 3 hops or 7 days.
- Whispers: at each hop a chance (10%) that one thing shifts: the count grows by a table of steps
  ("a dozen", "half a wood"), the place moves to a neighbouring house, or the kind turns into a
  similar one (a table). Seeded, so tests can fix it.
- The template line for heard stories names the teller ("Moiken told me ...").
- Works for all loaded villagers (the moment they come into view or not), not only the ones on
  screen.
- Tests: meetings, chances by tie, the 2-hour wait, the stop, whispers with fixed seeds, saving.

## 128. The judge: villagers word what they saw and heard, and think of the player by it

- [ ] Done

From design/villagers/gossip.md (The judge). Needs 127.
- A background queue, saved, of stories without a voiced line. One call at a time (like the
  memory summary), its prompt in data/npc_talk.cfg with a low temperature of its own: the
  villager's sheet (cut down for a local model), the fact, who told them. It returns JSON
  `{line, change, personal}`; anything that doesn't parse, is out of range or doesn't come is
  the template line, the deed's fixed change and not personal.
- Opinion of the player per villager, saved: one change step is 10 friendship points of
  design/villagers/relationships.md; full for who saw it, half for who heard it; a daily cap in
  data/gossip.cfg. Personal raises the story to high weight.
- The chat prompt tells the opinion in words (the levels of relationships.md, or a plain
  warm/neutral/cold until those are decided).
- Console: `opinion <villager> [points]`.
- Tests with a fake model: parsing, fallbacks, caps, the queue across save and load.

## 129. Newcomers learn the village from the locals

- [ ] Done

From design/villagers/gossip.md (Locals and newcomers). Needs 127.
- Made-up villagers start with no village sheet, only its base line (Wehlsbüll, the North
  Frisian coast, 1750). The sections of data/village.cfg are topics; a villager who knows a topic
  passes it at a meeting as a story, like a deed, with no hops limit and no whispers.
- A learned topic goes into knowledge and is never forgotten; the prompt carries only the topics
  a villager knows (full or cut down by provider, as today).
- Saved (version bump): made-up villagers of older saves start with no topics.
- Tests: learning, the prompt, saving. Docs in villagers.md.

## 130. Bubbles: villagers say a line now and then

- [ ] Done

From design/villagers/gossip.md (Bubbles). Needs 128 for lines about the player; the rest can
come earlier.
- Now and then a villager in view says a short line in a bubble over their head for a few
  seconds: at most one on screen and about one a minute (data file).
- Reuse what exists: ThoughtBubble (game/scenes/thought_bubble.gd, the player's icon bubbles)
  for the look, NpcMoment (game/state/npc_moment.gd) for the weather and part of the day.
- About the moment (weather, part of the day, the place, what they do), or about the player when
  near, with their opinion and newest stories.
- Asked of the model in the background with the chat's temperature (task 124), dropped if the
  villager is out of view when it comes; without a model, scripted lines per weather and part of
  the day in data/npc_talk.cfg.
- Not saved, not remembered. Bubbles drawn in palette colours, readable at every zoom; a
  screenshot in the README.

## 170. Music: the game plays the modules (after 169's decision)

- [ ] Done

Known limitation from 169: MusicCrossfade counts a fade's progress across loop wraps from the time
between audio mixes, which is when they happened, not how much they mixed; an audio thread held up
and then mixing one block looks like a long stretch of play, so a fade into a short loop may end
early by the hold-up (docs/music-viability.md, "Switching on the beat").

To be rewritten from task 169's report with the user. The plan so far: render sections in the
background with a bounded cache (user:// keyed by the module hash, renderer version and mix
settings), never wait for a late render during play (keep looping), sections with explicit
entry state, tempo, meter, loop points and allowed exits.

## 171. Music: what plays when, with loops, transitions and crossfades

- [ ] Done

After task 170. A music director (a scene service) loops a section, plays a fill now and then
and returns on the bar, switches between two loops (later by time of day, season, weather,
indoors) with a minimum time before switching again. A "music" bus with its own slider in
Settings (and off), muted in test runs (comes with task 184). Rules in data/music.cfg; tests; README.
- Indoors (from task 172, which leaves the music to this task): inside a building the director
  switches to an indoor piece or a quieter mix of the current one (the weather is faint there
  and a hearth crackles, task 172), crossfading as the player passes the door.
- The user, 2026-11-10, on three ambient sketches: "Tide" (6/8 sway, D dorian) and "Harbour
  evening" (80 BPM capstan bass, A aeolian) are great compositions; "Heath at dawn" is dropped; the
  tempos (60 dotted-quarter, 80 and 92 BPM) are right. The sound quality was bad: held notes
  wavered like a voice breaking, not like vibrato; the instruments must hold notes cleanly.
  After the fix: plain notes, no vibrato; the instrument tone is fine; note switches must not
  click.
  Approved the same day: "Tide" and "Harbour evening" (plain notes, held notes fading out
  rather than stopping) are the first everyday pieces (their data on the sketch branch of 2026-11-10).
- The user, 2026-11-10: the chiptune sound fits the classic 16 px graphics. Each piece gets two
  versions that switch with the graphics setting: the chiptune one with the classic art, a
  fuller one (more channels, softer instruments, still in the folk style) with the 32 px art,
  following the setting when it changes (a crossfade on the bar). The test piece's tempo was too
  fast for the game: calm tempos, around 100-110 BPM.
- The user, 2026-11-10, after hearing the 106 BPM test reel: "it still sounds like festive music
  for special events. The default music should probably be more of an ambient style music with a
  naval flair. Take inspiration from the German band Santiano." So the default (everyday) pieces
  are calm and ambient: slow sustained pads and drones, sparse melody, the sea and the coast in
  them (shanty-like modal tunes, a slow sway like a rolling ship, a low bass like a capstan
  song), our own tunes only, no melody of the band's or anyone else's songs. A second
  inspiration (the user, the same day): the German folk band Faun: medieval and pagan folk,
  hypnotic repeating figures, drones like a hurdy-gurdy or bagpipe, modal melodies like a
  nyckelharpa or flute, frame-drum pulses; again style only, our own tunes. Lively, festive
  pieces like the test reel are kept for special events (festivals, a market day). Later: stems
(AudioStreamSynchronized), more pieces, the season and weather choices.

## 184. Console: /play and /stop the music, and a music volume in the audio settings

- [ ] Done

The user, 2026-11-11: "add a command /play <trackname> to play the background music. add /stop to
stop it. add settings in the audio settings about volume."
- A first, small way to hear the music in the game before the music director (tasks 170 and 171):
  the console's `play <track>` renders a piece (art/generated/music/*.mod: today sketch_tide,
  sketch_harbour, test_reel; the names without the prefix may do) with the ModuleRenderer on the
  worker thread pool (game/audio/, task 169) and loops it; `stop` fades it out. An unknown name
  lists the tracks. Playing another track while one plays crossfades or stops the old one
  (MusicCrossfade exists: use it if simple).
- A "music" audio bus and a Music volume slider in the audio settings (game/scenes/audio_page.gd),
  saved with the other settings, with mute at 0; test runs stay muted. This takes over task 171's
  "a music bus with its own slider in Settings" (note it there).
- No automatic music yet: nothing plays unless the console says so.
- Tests for the commands (known, unknown, stop), the bus and the slider's setting; README and
  design/presentation/console.md lines.

## 205. The console log scrolls

- [ ] Done

The user, 2026-11-11: "The console needs scrolling. Use shared code for it. Start this now"
- Today the console (game/scenes/console_view.gd) shows only the last `VISIBLE_LOG_LINES` lines
  of `_log_lines` in a clipped Label; older lines (long `help` output, spawn lists, the track
  list of task 184) can't be seen.
- Make the log scroll with the shared scrolling code (ScrollingList, game/scenes/scrolling_list.gd,
  as the panels use it; extend it rather than writing a second scroller, if the console's case
  needs something it lacks): the mouse wheel and the scroll bar, and Page Up / Page Down (or
  Shift+Up/Down if those are free; keep Up/Down for the input history) while the input line has
  focus. A new line scrolls to the bottom unless the player has scrolled up to read (then it
  stays, as chat windows do); opening the console shows the bottom. The visible height stays
  `VISIBLE_LOG_LINES`. Keep a cap on the kept lines (e.g. 500) so the log can't grow forever.
- The log text stays selectable or not as today; the console stays on top and keeps its focus
  rules.
- Tests: long output can be scrolled to its first line, a new line keeps the view at the bottom,
  scrolled up it stays, the cap. README or docs/ui.md line.

## 185. Seasons change the ground gradually, as overlays: dark green, fallen leaves, frost, snow

- [ ] Done

The user, 2026-11-11, with a winter screenshot (blotchy patches of snow, grey and dark ground in
hard-edged tile shapes all over the meadow): "the current seasonal shift in itself is good but it
looks chaotic and distracting. we somehow need to do that more gradual, like adding the snow layer
gradually across all the areas, not as a tileset but as an overlay. For autumn it looks weird that
patches get yellowish, in winter grey. That's not how grass behaves, but instead it gets dark green
and in autumn gets leaves on top gradually and in winter frost and/or snow."
- Today SeasonBlend (game/state/season_blend.gd) gives each tile one of the looks (spring,
  summer, autumn, bare, frost, snow; SeasonalArt picks the picture file per look, the art
  generator draws them in tools/art/seasons.py) by a noise threshold that moves through the
  season, and SnowCover (game/state/snow_cover.gd) does the same for snow: so the change shows as
  patches of whole tiles in different looks, with hard edges.
- New approach, to be planned first (a short plan for the user, with a second opinion, before
  building; it touches the terrain art, the views and performance):
  - The grass itself keeps one base look through the year and only shifts its colour gently and
    evenly (fresher in spring, darker green in autumn and winter), with no yellow or grey patches.
  - Autumn: fallen leaves come on top as an overlay that builds up gradually over the weeks (a few
    leaves, then more, thicker under and near deciduous trees), the same everywhere it applies,
    not tile-shaped.
  - Winter: frost (a fine white rime, on cold mornings, fading in the day) and snow as overlays
    that build up and melt gradually and evenly across the area (a light dusting first, then a
    full cover, thinner in the lee and under trees, melting first in the sun and on paths), not
    as tiles switching look.
  - Soft, organic edges where an overlay is thin, never the tile grid; both arts; houses' roofs,
    trees and objects follow the same cover (snow on roofs builds up the same way).
  - Performance: the overlay must be cheap (a shader or a coarse cover texture blended per pixel
    rather than per-tile atlas swaps every hour).
- Keep what works: the season timing and the weather that drives snow, frost and thaw.
- Tests and before/after screenshots for each season and in a snowfall and a thaw, both arts.

## 186. Footsteps are silent on snow

- [ ] Done

The user, 2026-11-11: "there is no sound walking on snow". SoundEvents.footstep returns
`step_snow` when `is_snowed`, the step_snow files exist and are as loud as the others, and
data/sounds.cfg has the event; so find where it goes wrong: what passes `is_snowed` (SnowCover's
cover at the tile, maybe only partly snowed tiles or the dusting look), whether a snowed tile
makes no step event at all (e.g. the walk sound keyed on the terrain or a look that has no
entry), or the playback. Fix it; a test with a snowed tile giving the snow step in play, not only
the pure function. Coordinate with task 185 (snow as an overlay): the step should follow the snow
cover there too.

## 187. Character attributes: strength, agility, HP and stamina

- [ ] Done

Run after task 191 (the character window it shows in).

The user, 2026-11-11: "we want some basic rpg elements, character attributes specifically
Strength, agility, hp, stamina. strength increases carrying capacity, agility i don't know yet, hp
is obvious and stamina increases energy max. build the system so that we can easily expand on it
later."
- Today PlayerState has fixed MAX_ENERGY and MAX_HEALTH constants (game/state/player_state.gd),
  and carrying is the slot count of the hotbar and the backpack (Inventory).
- A small attribute system on the player: Strength, Agility, HP and Stamina, each a level with a
  base value, kept in data/ (e.g. data/attributes.cfg: base levels, what one level gives), saved,
  shown in the inventory/character screen. Built to grow: an attribute is data plus the
  effects it has, read through one place (e.g. `Attributes.value(STRENGTH)` and derived stats
  like `max_energy`, `max_health`, `carry_capacity`), so later attributes, bonuses (food, items,
  levels, skills) and NPC/animal attributes can be added without touching every caller.
- Effects now: Stamina raises the maximum energy; HP is the maximum health; Strength raises the
  carrying capacity: decide what that means with the user before building (more backpack slots,
  bigger stacks, or a weight limit, which doesn't exist yet). Agility: no effect yet (a later
  idea: walking speed, fewer stumbles, faster work), only the value.
- How attributes grow (levels from use, from skill levels, from items) is left open: a console
  command to set them for testing. Keep the game exactly as today at the base values.
- Plan first: a short plan for the user (the data shape, the strength question), then build.
- Save version bump with the upgrade rule; tests for the derived stats, the save and the base
  values matching today; README and design notes (design/player/).

## 188. The energy and health bars move to the top right

- [ ] Done

The user, 2026-11-11 (to run before task 187): "Move energy and health indicator to the top right
of the screen. add a bag icon right next to the quick bar, a bit separated. this icon when clicked
or b is pressed should open the bag which is the inventory (the build menu now only opens when the
hammer is in hand). The bag opens a bit on the right of the screen, the character part (and later
the character attributes) get their own window that opens on C." Split into 188, 190 and 191 at
the user's word the same day (they don't depend on each other).
- The energy and health bars move to the top right corner of the screen (mind the notifications
  and the clock that may sit there; say where those go). Both window sizes the game supports.
- Tests for the placement if the HUD has them; a screenshot for the user; README picture if it
  shows the HUD.

## 190. A bag button by the hotbar, and B opens the bag

- [ ] Done

From the user's words under task 188.
- A bag icon (both arts, pixel-artist job) beside the hotbar, set a little apart from it; clicking
  it or pressing B opens the bag. The bag is today's inventory screen (Tab), placed a bit to the
  right of the screen centre instead of where it is now. Tab: keep it as a second key unless the
  user says otherwise.
- B is the hammer key today (`select_hammer`, which puts the hammer in hand and opens building).
  The build menu now only opens with the hammer in hand (the hammer selected in the hotbar, then
  the build key/use); B no longer selects the hammer. Update the controls page and the README's
  key list.
- Tests for the keys, the button and the window place; screenshots for the user; README.

## 191. The character window on C

- [ ] Done

From the user's words under task 188. Before task 187, whose attributes it will show.
- The character part of today's inventory screen (the figure, equipment) moves into its own
  window opened with C; the bag (task 190) keeps the items.
- C is the crafting key today (`crafting`): crafting needs another key or a place in the bag
  window. The user, 2026-11-11: crafting moves to Shift+C for now; a better place is to be found
  later, maybe no hotkey at all but something like Minecraft (crafting at a table or in the
  inventory's own grid).
- Escape closes it as the others; it uses Modal (and is movable once task 189 is in).
- Tests for the key and the window; screenshots for the user; README and controls page.

## 194. Cloud shadows drift over the ground

- [ ] Done

The user, 2026-11-11: "add clouds to the weather system. cloudy weather shows cloud shadows on the
ground when the sun is out (no actual clouds are drawn). it can be slightly darker when there is a
closed sky with only clouds. the shadows should move corresponding with wind speed. the clouds only
affect the visuals, they have no effect on the plants etc."
- The weather already has `cloud_cover` (0 to 1, game/state/weather.gd; the forced weathers set it).
  Use it for the look only: no change to sunlight hours, crops, drying or anything in the state.
- By day with the sun out and partial cover: soft cloud shadows on the ground (a cheap overlay or
  shader, e.g. a scrolling noise mask darkening the world a little), more and larger shadows with
  more cover, none under a clear sky. They drift downwind at a speed that follows the wind speed and
  direction (the same wind the sway shader and gusts use). Under a closed sky (cover near 1) no
  moving shadows but the whole scene slightly darker (with the day/night tint and the overcast
  logic of task 177 in mind; don't double-darken). Fade with dusk; none at night or indoors.
- Shadows fall on the ground and what stands on it alike (one screen-space or world-space overlay
  under the UI); they move with the world when the camera moves (world-anchored, not stuck to the
  screen). Both arts.
- Cheap: one overlay, no per-tile work; numbers (shadow strength, size, speed per m/s, closed-sky
  darkening) in data/ (lighting.cfg or ambience).
- Tests for no shadows when clear or at night, darkness under a closed sky, drift following the
  wind, no state effect; screenshots and a short clip or frames for the user; README note.

## 196. Windows get a close button, and a click outside closes them

- [ ] Done

The user, 2026-11-11: "add a close button to the modal. clicking outside it should have the same
effect as the registered close key"
- Modal (game/scenes/modal.gd) gets a close button (a small X in the panel's top right corner,
  both arts, palette colours, a hover look) on every window. Pressing it does exactly what Escape
  does in that window: it goes through `_takes_escape()`, so where Escape first goes back a page
  (the pause menu's settings pages, the storage screen's and the character screen's own steps, the
  trash-can question) the button does the same. One code path for Escape, the button and the
  outside click.
- A left click on the dimmed area outside the panel does the same as Escape, for every window,
  including the fixed ones (the pause menu and ChoiceDialog, where Escape's answer, such as "no",
  is what the click gives). `closes_on_backdrop_click` and the windows' own `_on_backdrop_input`
  give way to it, or are dropped if nothing else needs them.
- Must not break: letting a dragged stack go on the dimmed area still drops it (`_drop_outside_panel`)
  and doesn't close the window. A window drag (189) whose release ends outside the panel doesn't
  close it. A press that starts inside the panel and ends outside doesn't count as a click outside.
  Clicks on the HUD's hotbar while a window is open keep working.
- The close button takes no part in the window drag (pressing it doesn't start one).
- Tests: the button and the outside click match Escape (closing, going back a page, the dialog's
  answer); a stack dropped outside still drops; a drag ending outside doesn't close. README, docs/ui.md
  and design/presentation/menus-and-hud.md. Screenshots of the button on a few windows, both arts.

## 195. Tidal water can't be walked on (bug)

- [ ] Done

The user, 2026-11-11 (a screenshot of the player standing far out in high water): "bug: you can
walk on tidal areas while water is there. right now you should not be able to walk on or in the
water, we'll add something later"
- Today the tide is a look only (game/state/tide.gd, game/scenes/mud.gdshader): MUD is walkable at
  any tide. Make it follow the water: a MUD tile under water at the current tide can't be walked
  onto, the same as SEA. Wading or swimming comes later, so keep the rule in one place that a later
  task can change.
- Which tiles are under water must match what the player sees. The shader floods each pixel where a
  relief (two layers of integer-hashed value noise, the dark troughs a bit lower) lies below
  `mix(LOW_WATER, HIGH_WATER, tide)`. Move that relief into state code (a GDScript port that gives
  the same numbers, with a test that pins it against the shader's constants), and call a tile
  flooded when the water covers its centre, or most of it. Pick whichever looks right at the edges,
  and show both in screenshots.
- No one is cut off by the rising water. Someone standing on a tile that floods can still walk off
  it, but can't step from dry ground onto flooded mud. Villagers, farm animals and wild ground
  animals obey the same rule; wading birds may stay. Pathing avoids flooded tiles. A path that was
  open when it started and floods on the way stops at the water's edge.
- Placing, building, dropping items and tilling on flooded mud are refused, as on water.
- Update the comments in tile.gd and tide.gd ("walked on at any tide"), and the design and README.
- Tests: tiles flood and dry with the tide, no stepping onto flooded mud, walking off a tile that
  floods, NPC and animal paths avoid the water. Screenshots at high and low water for the user.

## 176. Wind gusts are heard with the wind you see, and as loud as the wind

- [ ] Done

The user, 2026-11-11: "with 5m/s wind speed the sound sometimes has loud gusts of wind while
nothing is moving. feels like the sound is off."
- Today the sound and the picture don't share their gusts. AmbienceSounds (game/scenes/
  ambience_sounds.gd) plays the `wind_gust` sound at random (`gust_chance` per second, scaled by
  the wind loop's level, data/ambience.cfg [loops]) and always at the sound's full volume, while
  the sway shader (game/scenes/sway.gdshaderinc, AmbientMotion.gust_for) shows gusts as fronts
  sweeping downwind every GUST_SPACING px at GUST_SPEED, only above GUSTS_FROM (3 m/s) and faint at
  5 m/s. So at 5 m/s a full-volume gust can sound while the grass barely stirs.
- Tie the gust sound to the visible gusts: compute on the CPU when a gust front passes the player
  (the shader's formula, from the same wind direction and time) and play/swell then, so a gust is
  heard when the grass and trees near the player bend. No gust sound below the speed where gusts
  show.
- Scale the gust sound's volume (and the loop's swell) with the wind strength, so a light breeze
  gives at most a soft rustle and a storm a loud gust.
- Indoors the gusts stay faint, as the rest of the weather (task 172).
- Tests: no gust below the threshold, gust volume grows with wind, the gust timing matches the
  shader's front at the player's place; a listening file at 5, 10 and 15 m/s for the user.

## 199. Process stations: the kiln and the oven get a 3x3 load, an activation button and a progress bar

- [ ] Done

The user, 2026-11-11: "The killing [kiln] does the recipes on the side and offers an inventory 3x3
slots. You put in raw material and fuel (wood for now) and after some time you'll get the resulting
material. Only one recipe per craft. Add a little fire button to start the process with a progress
bar above the greyed out inventory. Clicking a recipe adds the required materials from your
inventory." Then: "the oven should work the same. Make that a type of crafting station code that's
reusable. We'll have more use for it in the future." And: "leave out the ash. Only allow to put in
what fits a recipe. If there's too much of a kind leave it in as is. That'll make the code easier
and better reusable. We can later expand on it. Maybe the kiln implementation can turn it to ash,
the cooking station to burnt food. The 'fire button' should just be an activation button where the
implementation can add a symbol. So the cooking station and kiln might add a fire, a saw mill might
add a saw blade, a fish breeding pond might add a fish."

Today:
- The kiln is a crafting station. Picking a recipe takes the materials and starts the firing.
  - Its recipes are bricks, bricks_large and bricks_master in data/recipes.cfg, with `hours=12`
    and logs among the materials.
  - The firing runs in StationWork. Opening the menu when it's done takes the result out.
  - Task 198 drops what doesn't fit by the kiln. This task replaces that path.
- The oven's recipes are made at once, with no time and no fuel: bread, berry_tart and feast_cake.

**One reusable kind of station, a process station** (name it to fit the code). The kiln and the
oven both use it. A later station is a config section plus its recipes, with no new code. Examples
are a forge, a smokehouse, a saw mill and a fish pond.
- A station becomes one by its config in data/stations.cfg:
  - that it is a process station;
  - its grid size (3x3 for both);
  - the icon of its activation button (a fire for the kiln and the oven).
- There is no separate fuel concept. Wood is simply one of a recipe's materials, as the logs are
  in the brick recipes today. A saw mill or a fish pond then needs nothing special.
- **The window:**
  - The station's recipes are listed on the side, with the grid and the activation button
    beside them.
  - The grid is the station's own storage. It is saved with the station, with a save version
    bump and its upgrade per the save rules.
  - The player moves stacks in and out as with a chest: drag and shift-click.
- **Only what fits a recipe goes in, filtered as the grid fills.** The user, 2026-11-11: "once you
  add ingredients, the materials you can add is filtered by the recipes. If you have one that
  needs wood and stone and one that needs coal and stone, you can add stone and still be able to
  put in wood and coal. But if you start with coal, you can only put in [stone]. Grey out items in
  your inventory part that you can't put in. Materials not in a recipe are of course greyed out
  from the beginning. Quantities work similarly: you can only put in as much stone as you have
  either coal or wood. If you put in too much stone for the wood recipe but have enough coal, the
  wood recipe gets greyed out." (Their example says "only wood" after coal; read it as the other
  material of the coal recipe, stone. Say so in the report.)
  - The rule: the grid's contents must always be part of one load of at least one of the
    station's recipes, at some amount that fits the grid (the ratios of its materials kept). A
    recipe still possible is "open"; one the contents rule out is greyed out in the list.
  - An item, or a count of it, that would leave no open recipe is refused: a drag or shift-click
    moves only as many as keep a recipe open (none if no count does).
  - The player's inventory beside the grid greys out the stacks that can't go in now. Items in no
    recipe of the station are greyed out from the start.
  - Taking items back out of the grid opens recipes again.
  - Keep this rule in the shared code as one plain function over the recipes and the contents
    (pure state code, well tested), so the window only asks it.
- **The recipe list:**
  - There is one recipe per kind of result: one "Bricks", not today's three brick recipes.
  - Under each recipe is an amount: a small number field to type in, and +/- buttons.
  - The +/- buttons only go as high as the player's materials allow and as fits the grid. A
    typed number is held to the same limit.
  - A Max button by each recipe sets the amount to the most the player's materials, the grid and
    what is already in the grid allow.
  - A recipe the player can't make even once, or one the grid's contents rule out, is greyed out
    and can't be clicked.
  - Clicking a recipe moves the materials for the chosen amount from the inventory into the grid,
    counting what is already in it.
- **The activation button:**
  - It starts the run when the grid holds at least one recipe's materials, one recipe per run.
    Which recipe the grid matches when it could hold more than one is up to you; say which.
  - The button shows the station's icon.
- **While it runs:**
  - A progress bar shows above the grid, and the grid is greyed out and locked.
  - The time comes from the recipe's `hours`.
  - The station shows its activity in the world, using the existing lit look and light, if any.
  - It goes on with the window closed and with the player away, in game time.
- **When done:**
  - The materials of the amount made are used up, and the result is in the grid.
  - With the filter there are no leftovers (the user, 2026-11-11: "This way we should also never
    have too much of anything in the station"): the grid can only hold parts of one recipe's
    loads, and the activation button runs only when it holds whole loads (n full loads of the open
    recipe, no part load), so a run uses up everything that is in the grid. A part load keeps the
    button greyed out with a short note of what is missing. Nothing turns into ash or anything
    else; leftover handling (ash, burnt food) is not needed and not built.
  - The player takes the results out like from a chest, only as much as fits. The rest stays in
    the station.
  - Nothing new goes in, and nothing new starts, until every produced item is taken out (the user,
    2026-11-11: "You can't start anything new in the crafting station unless the produced items
    are all taken out"): while results are in the grid, the recipe list and the inventory beside
    it are greyed out with a short note, and the grid only lets things out.
- **Skill:**
  - Recipe `level` locks stay, for later recipes that unlock at a skill level, and each run
    practises the recipe's skill.
  - The masonry levels that made bricks_large and bricks_master pay off become a bonus on the one
    Bricks recipe: at a high enough skill a run gives extra bricks besides the ones selected,
    automatically.
  - The old recipes gave one brick per raw brick and saved wood (6 bricks for 2 logs, 12 for 3,
    18 for 3). The new bonus is extra bricks instead, for example a share of the load at level 50
    and a larger one at 70.
  - Pick the rule and the numbers and put them in data/, where the user tunes them; no need to ask.
  - Make the bonus a setting of the shared code, per recipe or per station, so the oven could get
    extra loaves the same way later. The oven gets none for now.
- **The oven:**
  - Its recipes get a baking time and wood among their materials. Pick them (bread about an hour)
    and put the numbers in data/.
  - Their cooking levels stay as recipe locks.
  - It works indoors and outdoors, as it is placed today.
- Other stations (the workbench and the hearth) keep today's instant crafting menu.
- **Tests:**
  - the shared code with a station defined only in test config;
  - the grid saved and loaded;
  - only recipe materials accepted, the filtering as the grid fills (the user's wood/coal/stone
    example as a test, with quantities), recipes greyed out by the contents, inventory items
    greyed out, taking out reopening recipes;
  - the Max button;
  - a recipe click moving materials;
  - the amount limits;
  - the button refused without a full recipe;
  - locked while running;
  - the button greyed out on a part load, a run using up the whole grid, the result after the
    time;
  - taking out only what fits, and nothing going in or starting while results are left;
  - the kiln and the oven.
- **Docs and screenshots:**
  - README, the design pages on crafting, the kiln and the oven, and docs/ui.md.
  - Screenshots of the kiln and the oven windows: empty, loaded, running and done.

## 201. Wild animals keep away from villagers and buildings (mice excepted)

- [ ] Done

The user, 2026-11-11, after task 181 left wild animals able to stand on a door tile: "Wild animals
should stay away from NPC's and buildings, except mice maybe."
- Today wild ground animals (WildlifeRules.GROUND_KINDS: rabbit, squirrel, deer, mouse, frog; and
  the birds that land) walk on `world.is_walkable` (game/scenes/wildlife/wildlife_view.gd), which
  includes door tiles, and only shy from the player (`flee_tiles`, `alert_tiles` in
  WildlifeRules).
- Never on a building tile, the door included, for every wild kind (mice too); and none spawns or
  lands on one.
- Keep a distance from buildings and from villagers, as from the player: they don't spawn or settle
  near them, and flee or turn away when a villager comes as near as their flee distance (a
  per-kind distance in data/, e.g. the same `flee_tiles`, or a smaller one for buildings). Mice are
  the exception: they live by the fields and the houses and may come close to buildings and
  villagers (but still never onto a building tile). Pick the other kinds' distances; the user tunes
  them in data/.
- Cheap: villagers are few, but don't scan every villager per wild animal per frame if a spatial
  lookup exists; say what you used.
- Tests: no wild animal on a building tile over play and spawning; a rabbit or deer moves away from
  a villager; mice may stay near a house; the config check. Design note on wildlife.

## 202. Storks come too often

- [ ] Done

The user, 2026-11-11: "Storks spawn too frequent"
- Wild storks today (data/wildlife.cfg): `[stork]` (hunting on wet ground, cap 2, spawn_chance
  0.03, spring and summer) and `[roof_stork]` (on a roof near the view, cap 2, spawn_chance 0.02);
  plus the nest pairs of task 152, which belong to their nest and are not counted.
- Find out what the player sees as "too often": how many storks are about at once and how often a
  new one flies in, in spring and summer, near the village and the wet meadows; whether settle on
  skip or chunk streaming tops them up again and again, or a stork that flies off is replaced at
  once. Measure it (a short headless run counting stork arrivals per game hour) before and after.
- Make them rarer: a lower cap and spawn chance, a longer gap before one comes back after leaving,
  and roof storks only now and then; numbers in data/ (the user tunes them). Keep the nest pairs
  as they are.
- Tests for the rate (arrivals per hour within a bound) and the cap; design note.

## 203. Wattle fences and stone walls can be made and placed

- [ ] Done

The user, 2026-11-11: "Are the willow fences or the stone walls that the map generated creatable?
If not they should"
- Today the world generator lays them along field boundaries (WorldObjectTypes.WATTLE_FENCE, hazel
  rods woven between stakes, cut with the axe for 2 fibre; STONE_WALL, dry fieldstones, taken
  apart with the pickaxe for 3 stone; both `connects: field_boundary`, drawn tile by tile), but
  there is no recipe or item for either: the player can only take them down.
- Add both as things the player makes and places piece by piece, as the pig pen's fence (task
  165: a `pen_fence` item from a workbench recipe, placed on a tile, joining its neighbours):
  - a wattle fence piece: made by hand or at the workbench from rods or sticks and fibre (pick
    what fits the items that exist; hazel rods if there is such an item, else branches or
    sticks), cheap;
  - a stone wall piece: stacked by hand from stone (about the 3 stone it gives back), no station.
  Pick the recipes, skill and level (woodworking for the fence, masonry for the wall if fitting);
  numbers in data/.
- Placed pieces are the same world objects as the generated ones: they join each other and the
  generated runs (the `field_boundary` connection), block walking, are taken down with the same
  tool for the same drops (take care the drops don't make more than the recipe cost, or say why),
  and are saved like other placed objects. Both arts (the art exists).
- Placement: the same rules as the pen fence (free tile, not on water, buildings or paths that must
  stay open); a placement ghost if the pen fence has one.
- Tests: crafting, placing, joining a generated run, taking down, saving. README (building or
  crafting section), design pages.

## 204. A rooster among the chickens, crowing now and then

- [ ] Done

The user, 2026-11-11: "The chicken need a rooster that's occasionally shouting"
- Today the chickens (data/livestock.cfg, the chicken coop of task 122) are all hens with a cluck
  (`chicken_cluck` in data/sounds.cfg).
- Add a rooster: a chicken flock has one (a flock that gets its first hens gets a rooster too;
  `spawn rooster` in the console; old saves get one per coop or flock, with the save upgrade per
  the save rules). Bigger than a hen, upright tail and red comb and wattles: art in both sets, the
  same moves as the hens (a pixel-artist job); it walks and pecks with them, sleeps in the coop,
  lays no eggs, can be petted (friendship, task 173) and counts as a chicken where the game counts
  them (or say where it doesn't).
- It crows now and then: most at dawn (a run of crows around sunrise), a few times through the
  day, never at night while asleep. A new generated cock-a-doodle sound (2 or 3 variants, a
  sound-designer job), positional, heard across the farm, faint indoors like other outside
  sounds. How often: pick it, numbers in data/ (the user tunes them).
- Tests: a flock has a rooster, it lays no eggs, it crows at dawn and not at night, save and load;
  a listening file and a picture of the rooster in both arts for the user; README, design pages.

## 206. Tool designs: rusty iron tools redrawn from scratch, and four better grades (design only)

- [ ] Done

The user, 2026-11-11: "We need better tools. Redesign the tools to be rusty ones, let the agent
design them from scratch. The current ones still look distorted. Then design 4 more quality
levels. The current ones will be 'rusty iron <tool>', then we'll have 'iron', 'brittle steel',
'steel' and 'sharp steel'. Only do the designs and give them to me for approval. Make sure the
tools don't look distorted or in any other way deformed." Run by a worker on Fable with the
pixel-artist instructions (.claude/agents/pixel-artist.md), at the user's request.
- The tools: hoe, axe, pickaxe, watering can, scythe, shovel, hammer (game/state/item_types.gd;
  check for others). Today's art comes from the generator (tools/art: items.py and the held-tool
  code) and looks distorted.
- Design every tool from scratch, not by patching the old drawing: clean, straight, true shapes,
  no warping, skew, broken lines or squashed parts; each sprite in every view it has today (the
  inventory icon and the held/in-hand frames, in both art sets, 32 px new and 16 px classic).
- Five grades of each tool, told apart at a glance by the metal (and the handle where it helps),
  same silhouette per tool: rusty iron (today's tools: rust-brown, pitted, dull), iron (plain grey
  iron), brittle steel (lighter, cold bluish, a hint of a crack or a rough edge), steel (bright,
  clean), sharp steel (bright with a keen highlight on the edge). Wooden handles may age too.
- Design only: render contact sheets (all tools by grade, at 1x and an enlarged view, both arts,
  icon and held) into the scratchpad for the user's approval. Changes to the generator code are
  fine on the worker's branch so the sheets come from the generator, but nothing is merged, no
  items or game code are added, and the current art stays until the user approves.
- Task 207 then makes them items.

## 207. The tool grades as items, given with the console

- [ ] Done

After task 206's designs are approved: the five grades of each tool (rusty iron, iron, brittle
steel, steel, sharp steel) as items in the game, named "Rusty iron hoe", "Iron hoe" and so on; the
current tools become the rusty iron ones (renamed; old saves keep working). For now they come only
through the console `give` (no recipes, no shops). How the grades differ in play (the tool `level`
of item_types.gd, hit points per hit, durability if any) is to be proposed in the brief with the
numbers in data/ (the user tunes them). Both arts from the approved generator code.

## 208. Dig up bushes with the shovel and plant them elsewhere

- [ ] Done

The user, 2026-11-11: "Bushes need to be removable. Use a shovel to dig them out and be able to
place them somewhere else"
- The bushes (game/state/world_object_types.gd): BERRY_BUSH (blocks walking, picked for berries,
  regrows), SHRUB and FERN_BUSH (fibre by hand); check for other bush-like plants (the young
  saplings may fit too: say). Today they can be picked or cut by hand, but not moved.
- The shovel used on a bush digs it out whole: the bush becomes an item ("Berry bush", "Shrub",
  "Fern"; icon from its world sprite, both arts) in the inventory (or dropped if full), its tile is
  left as dug earth or grass. The bush keeps what matters (a berry bush's picked/regrow state may
  reset, say which). Digging takes a few shovel hits like other shovel work, with its sound and
  energy cost.
- The item is placed like other placeable things (a placement ghost if they have one) on a free
  tile where a bush can grow (grass or similar, not on water, paths, buildings, farmland), and
  becomes the same world object again, with its season looks and regrowth. Saved like other placed
  objects (save version bump if the save needs it).
- Picking berries and cutting by hand stay as today; only the shovel digs out.
- Tests: digging each bush gives its item, placing it back, refused tiles, a berry bush still
  bears after replanting, save and load. README, design pages.

## Later (not part of the prototype)

- **Villagers go inside** (the user, 2026-11-11): villagers enter their houses (and the church,
  workplaces) through the door instead of waiting in front of it, and are seen in the interior.

- **Taming wild animals** (the user, 2026-11-11): wild animals already carry a friendship value
  (task 173); a later feature could let the player tame them. Design notes (second opinion,
  2026-11-11): a sparse store on GameState holds only wild animals whose value is above 0, ships
  together with bringing a tracked animal back near its last tile (wildlife nodes vanish indoors,
  over skips and with distance, so despawn is not death); one live node per id; ids from a saved
  allocator; records {id, kind, friendship, last tile, accounted_day}, decay counted in the state;
  a record goes when the animal dies (cats catch mice, storks catch frogs), drops back to 0 or is
  tamed into the livestock; wild-kind rules with the wildlife rules, not the livestock species
  (both have a "rabbit").

- **Animal breeding** (the user, 2026-11-10): a cheap way to get new animals, but the young take
  at least a year to grow up. With simple traits per animal (one cow gives more milk, another more
  meat) that the young may inherit, as in Palworld, and the looks (breeding only brown cows).

- **Keeping animals is costly** (the user, 2026-11-10): animals should take real work and
  resources, to fit the period.

- **Hired hands** (the user, 2026-11-10): money is hard to come by, so people could be taken on to
  live on the player's plot if the player builds them somewhere to live and produces enough food
  for them.

- **Where crafting lives** (the user, 2026-11-11): Shift+C is a stop-gap (task 191); find a
  better place, maybe no hotkey but something like Minecraft (a crafting table, or a small grid in
  the inventory).

- **Tombstones** (the user, 2026-11-10): a placed grave marker is always the oak cross; a
  headstone and a fieldstone slab could come as crafted items of their own (their art is already
  drawn in tools/art/church.py).

- **A relationship system** (the user, 2026-11-08): friendship levels per villager, like Stardew
  Valley, but actions count as well as gifts, in the manner of the Sims (helping, talking,
  events, rudeness, theft, being there in trouble). A first draft is in
  [design/villagers/relationships.md](design/villagers/relationships.md), planned and not
  decided. Plan with the user (its open questions are in QUESTIONS.md), then split into tasks.

- **Economy and currency** (the user, 2026-11-08): small trades with villagers, shops that buy and
  sell for money, and the player's own little stall where villagers occasionally buy produce and
  goods. A first draft is in [design/economy/README.md](design/economy/README.md), planned and
  not decided. Plan with the user (its open questions are in QUESTIONS.md), then split into
  tasks. It also settles where seeds come from once shops exist.

- **A windmill to build** (the user, 2026-11-10, replacing task 62, a post mill as a landmark
  prop placed by the world generator): the player builds a windmill as a building and grinds
  grain into flour there (the flour recipe moves from the oven to the mill). Art notes on the post
  mill are in docs/art-style.md (Mills, bigger item 10) and review/art-review-2026-11-08 (item 4).

- `WildlifeSprites.frame_index` and `max_frames` allocate on every call (`keys()`,
  `values().max()`); the older animals call them per frame. Cache them per sheet. And rename
  `SoundEvents.animal_alarm`, which since task 60 also gives the stork's clatter, to something
  like `animal_state_sound`.
- A committed pixel guard (a GUT test hashing the tile cells, sprites and lights for a fixed seed
  and a few days) would catch silent rendering changes in refactors like task 70; left out while
  the art tasks change the pictures on purpose, as its golden value would need updating each time.

- World keeps its `max-public-methods` lint exception after task 68 (chunks, objects, soil,
  buildings and clay share the same edits). Getting under 20 would take one more split, most
  likely buildings and their placement rules.

- Season looks follow-ups (from the task 29 review): SeasonBlend `_season_look` indexes the
  shares by hand, a loop would do (`conditions()` already loops); `frost_at` belongs with the
  season rules, not SnowCover. SnowCover's cold start (~80 ms for a fresh region in late winter) could be
  spread over frames. Snow cover of the player's region is applied to the whole loaded
  world for now.

- Split the object edits (`_object_edits`, `replace_object`, `hit_object`, `change_object`,
  `take_off`) out of `World` into their own class with their own tests, and drop the
  `max-public-methods` lint exception in world.gd (the regrowth is in NightUpkeep already).
- Edits of objects that are back to their generated state (a healed tree, a mown tuft that
  regrew) stay in the save forever; drop them. Harmless, bounded by what the player touched.
- Ground items (task 33 review): a pile that falls back onto a non-walkable source may be out of
  reach (`_scatter_tiles` returns the source). A pulled pile moves straight through walls and
  water (the pull reaches 1.25 tiles since 2026-11-05).
- Use (swing) poses for the axe, pickaxe, scythe and shovel; the held art is done (task 119).
- The shovel could later dig up a young sapling to move it.

- Floodplain farming: floodplain is the most fertile farmland, but only grass can be tilled
  now. Tilling it needs a "tilled" tile property that keeps the floodplain flag, so floods
  can still act on it.

Art notes (reviewed 2026-11-09; the rest was redone by tasks 101 to 119):

- The late-evening tint (DAY to DUSK_GLOW, day_night_tint.gd) over green grass reads olive
  rather than warm; check at the sunset hour of summer and autumn. Also check the player's face
  at 20:30 to 22:00 next to the fire (an old note said it turns pink at night).
- Lush and dry grass looked blotchy (dry has its own yellower colours since task 107); keep only
  if a fresh screenshot still shows it.
- tools/art/terrain.py: `brown_caps` is defined twice (and twice in classic/terrain.py); make it
  one module-level sprite. Add `canvas.size(picture)` for the repeated
  `len(picture), len(picture[0])`.
- A test that `_unload_chunk` leaves the decoration cells empty (redrawing is tested by the path
  tests).
- A grass tuft can stay under a boulder's right half at the load frontier (hidden): after a chunk
  loads, recheck the decorations under its objects' tiles that reach into loaded right or bottom
  neighbours.
- `World.add_chunk` replay removes a generated object only at the origin tile of a replayed
  multi-tile object, not at the other tiles it covers.

Saving notes from the task 15 review:

- Ctrl-C/SIGTERM doesn't save; only play since the last autosave (or quick save) is lost.
- `--new-game` without `--save-path` replaces the real save at the first autosave or on quit
  (intended); `make screenshot` uses build/screenshot.save, so test runs never touch it.

See-through notes from the task 14 review:

- A swapped sprite may change draw order against a same-row neighbour tree (small pop): walk
  behind a tree with a neighbour in the same row to see it.

World generation notes from the task 3 review:

- The river is measured by vertical distance to its centre line, so it gets thin (about
  2 tiles) in steep bends. Use perpendicular distance, or a smaller meander.
- The noise seeds use offsets 1 to 18 from the world seed (the wetland's `seed + 1` equals the
  river noise of the next seed; its comment says "independent"), so every noise collides with
  another noise of a nearby seed. Give them large distinct offsets. This changes every world:
  it needs a world version note.

Still missing from the old feature list: combat, reputation (see tasks 125 to 128 and the
relationship system), building expansions, more distinct biomes.
