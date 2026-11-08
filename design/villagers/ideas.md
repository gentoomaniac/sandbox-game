# NPCs: people, behaviour and LLM dialogue

**Ideas, not decided.** An idea collection for later. Written 2026-11-06 from the user's idea:
NPCs that feel alive, answer with unscripted text, and act on intentions that can change.
For the user to edit; later the input for tasks. Setting as everywhere: the North Sea coast
about 1700-1800.

Tags: **[cheap]** = data or small code, **[medium]** = a new system or UI, **[big]** = new
art, world content or save changes.

---

## 1. The idea in one paragraph

Each NPC has a written personality, a history, a current situation and a few intentions
with priorities ("sell the eggs at the market", "worried the dyke won't hold the storm
tide"). The game decides what an NPC wants and does; an LLM only turns that into words when
the player talks to them, and may suggest small changes (a new intention, a memory, an
offer), which the game checks before applying. The player brings the model: a local one or
their own API key. Without one, NPCs speak short scripted lines.

## 2. What already exists

- [Reputation](reputation.md): building inside a settlement's territory costs reputation with its
  NPCs; changes spread one hop through friends and enemies. Open there: what reputation
  unlocks, and who in the territory is affected.
- [crafting/ideas.md](../crafting/ideas.md): NPC smith (buying the first iron tools), NPC
  commissions (bulk orders) with reward and reputation, learning a craft from a neighbour.
- No NPCs, settlements or dialogue UI in the game yet. Livestock (task 73) and the wildlife
  give a pattern for things that move on their own, sleep at night and are drawn per look.

## 3. Two layers: behaviour in the game, words from the LLM

| | Behaviour layer (game code) | Dialogue layer (LLM) |
|---|---|---|
| Decides | Where the NPC is, what it does, what it wants | What it says, and suggestions |
| Runs | Always, deterministic, tested | Only in a conversation (and a summary after) |
| Owns | Schedules, needs, intentions, actions, trades, reputation | Nothing; it proposes, the game disposes |
| Without an LLM | Unchanged | Scripted lines per intention and mood |

This split is the core decision. It keeps the game testable and its saves deterministic, lets
the world run with hundreds of NPCs at no cost, and means a weak or missing model only
makes the talk duller, never breaks the game.

## 4. The NPC as data (saved)

- **Identity:** name, age, household, home, trade (fisher, miller, smith, dyke reeve,
  pastor, innkeeper, farmhand...), look (sprite layers, clothes).
- **Personality:** a few traits on scales (warm-cold, pious-worldly, thrifty-generous,
  talkative-taciturn) plus a short free text, 2-4 sentences, written for the prompt.
- **History:** a short free text (where from, losses, the Christmas flood of 1717, a son at sea)
  and a few facts the game can use (born in, married to, owes money to).
- **Relationships:** to other NPCs and groups (kin, friend, enemy, rival, employer), with a
  strength. the one-hop reputation spread uses friends and enemies; the other kinds
  colour dialogue and carry gossip.
- **Opinion of the player:** reputation, trust, debts, favours, gifts given.
- **Intentions:** 1-4 at a time, each with a kind from a fixed list (work, sell, buy, visit,
  court, avoid, warn, ask for help, celebrate, mourn), a target, a priority and an end
  condition. They change through events (season, weather, a death, the player's doings) and
  through checked LLM suggestions.
- **Needs / mood:** hunger, tiredness, cold, worry, cheer; simple numbers that colour both
  behaviour and speech.
- **Knowledge:** what this NPC knows (rumours, prices, where the clay is, that the player
  took down the old shack). Gossip spreads knowledge (not reputation) along relationships, one hop a day.
- **Memory:** a short list of one-line summaries of past conversations and events with the
  player, newest first, capped (e.g. 10); older ones are merged into one line.

Authored NPCs (the miller, the pastor) get hand-written texts; generated villagers get
traits and facts from tables, and a generated text (by the LLM once, stored, or from
templates).

## 5. Behaviour layer

- **Schedules** per trade and season: wake, work, eat, church on Sunday, the inn in the
  evening, sleep. Like livestock: they sleep at night, at home.
- **Intentions pick actions:** a utility score per intention (priority x urgency x mood)
  chooses what to do next; actions are game actions (walk to, work at, trade with, talk to
  NPC, give item, wait). Simple, explainable, testable. [medium]
- **Reacting to the world:** storm tides, harvest, a fire, the player building nearby
  (reputation), a missing cow. Events add or change intentions.
- **Off-screen:** NPCs out of view advance coarsely (where they would be by now), like
  chunk streaming. Hundreds are affordable this way.
- **NPC to NPC talk:** shown as short scripted barks or not at all; no LLM calls unless the
  player listens in (later idea).

## 6. Dialogue layer

### 6.1 How Godot calls an LLM

1. **A local server over HTTP (recommended first).** The player runs Ollama, LM Studio or
   llama.cpp's server; the game talks to it on localhost with the OpenAI-compatible chat
   API. Godot's `HTTPClient` can read a streamed reply (server-sent events), so text appears
   word by word; `HTTPRequest` is enough without streaming. No native code, no model
   shipped.
2. **The model inside the game.** A GDExtension around llama.cpp (there are Godot plugins
   for this, NobodyWho for example) loads a GGUF model file directly. No setup for the
   player, but native builds per platform and the model shares the GPU with the game.
3. **A cloud API with the player's key.** The player enters an endpoint and key: OpenAI
   or any OpenAI-compatible host, or Claude, whose own Messages API has a different shape
   (a second adapter, `ClaudeChat`, exists now; picked in Settings). Best quality, needs the internet, costs the
   player per conversation, and adds a few hundred milliseconds or more.

**Recommendation:** one backend interface in Settings: endpoint URL, model name, optional
key. The OpenAI-compatible chat format covers option 1 and most of option 3 with the same
code; Claude's API got a second adapter behind the same interface (`ClaudeChat`, task 93). "None" uses scripted lines. Option 2
later, if setup turns out to be the main friction. The key is stored in the settings file
(user://settings.cfg, plain text on disk: Settings says so), never in the save, never
logged.

### 6.2 The prompt

Built fresh for each reply, short (a few hundred tokens):

- **Rules:** who you are, it is 17xx on the North Frisian coast, speak as such a person
  would, know only what you know (list), keep replies to 1-3 sentences, never mention
  modern things, never invent facts about the world (prices, places, people) beyond those
  given.
- **The NPC:** personality text, history text, mood, current intentions, opinion of the
  player, relevant relationships.
- **The moment:** place, time of day, season, weather, what the NPC is doing, what the
  player holds or just did.
- **Memory:** the summaries, and the last few turns of this conversation.
- **Allowed suggestions:** the fixed list below, as a JSON schema or tool definitions.

### 6.3 What the LLM may return

A reply line, plus optionally one or more suggestions from a fixed list, as structured JSON
(tool calls where the backend supports them):

- `remember(text)`: a memory line about the player.
- `change_intention(kind, target, priority)` / `drop_intention(id)`.
- `offer_trade(item, count, price)` within the NPC's stock and price limits.
- `ask_favour(kind, target)`: becomes a small quest (fetch, deliver, help with work).
- `opinion(delta)` within a small range (e.g. -2..+2 per conversation).
- `end_conversation()`.

The game validates each one (known kind, limits, the NPC can actually do it) and applies or
drops it. Raw LLM text never changes game state.

### 6.4 Player input

- **Free text:** the player types. The most alive; needs a text box and a model that copes.
- **Intents:** the player picks ask about / trade / gossip / give / goodbye, and the LLM
  phrases both sides. Robust, works with a controller, fits a quieter game.
- **Recommendation:** both: intents as buttons, plus "say something" for free text.

### 6.5 After a conversation

One more short LLM call summarises the conversation into one memory line ("The newcomer
asked about clay; I told them of the pit by the alder carr"). That keeps prompts and saves
small. Without an LLM: no summary, only the game's own memory events.

## 7. Practicalities

- **Latency:** a 3-8B local model gives a short reply in about 1-3 s on a decent GPU.
  Stream the text, keep replies short, show the NPC thinking (a pause, a pipe puff).
- **GPU and memory:** a local model and the game share the machine; small quantised models
  (Q4, 3-4B) are the safe default; document recommended models.
- **Consistency:** small models drift. Facts come from the game and are restated in every
  prompt; the memory list is the only long-term state; contradictions cost little because
  nothing is applied unchecked.
- **Period voice:** prompt rules plus a cheap filter for modern words; optional Low German
  or Frisian greetings and phrases from a small table, inserted by the game.
- **Saves:** NPC data, intentions and memories are plain data in the save (a version bump
  when added). Conversations are not saved verbatim.
- **Tests:** a fake backend that returns fixed replies and suggestions; the validation of
  suggestions is unit-tested; nothing in tests calls a real model.
- **Privacy and cost:** with a cloud key the conversation text leaves the machine; say so
  in Settings. The game never ships or bundles a key.
- **Licences:** the player downloads the model, so its licence is between them and the
  model's maker. Prefer recommending openly licensed models (e.g. Apache-2.0 ones).
- **Failure:** time-outs and errors fall back to a scripted line, never a hang; the
  conversation stays usable.

## 8. Tie-ins with the rest of the game

- **Reputation (see [reputation.md](reputation.md)):** the opinion of the player is the reputation; the one-hop spread
  runs on the relationships above.
- **Professions:** NPC crafters to buy from or learn from; commissions as `ask_favour` /
  intentions ("I need six barrel staves by Martinmas").
- **Livestock and wildlife:** a farmer who misses a cow, a child who wants the kitten, the
  stork's return in spring as a village event.
- **Weather and seasons:** storm tides, harvest, Biike fires in February, the market days.
- **Buildings:** NPC houses use the existing building types and interiors; taking down or
  building near them touches reputation.

## 9. A first prototype

1. **One NPC, behaviour only** [medium]: an NPC sprite (layers like the player), a home, a
   schedule, two intentions, walking with the existing map rules, saved. Talk shows
   scripted lines.
2. **The LLM backend** [medium]: Settings (endpoint, model, key, none), the HTTP client with
   streaming, time-out and fallback, a fake backend for tests.
3. **The dialogue UI** [medium]: a box with the NPC's portrait or name, streamed text,
   intent buttons and a text field.
4. **Suggestions and memory** [medium]: the validated list of 6.3 and the summary of 6.5.
5. **A hamlet** [big]: a few authored NPCs (miller, fisher family, dyke reeve) with
   relationships, gossip and reputation.

## 10. Open questions

1. **Free text or intents?** Recommendation: both (6.4).
2. **Which backend first?** Recommendation: the OpenAI-compatible endpoint in Settings,
   tested with Ollama locally (6.1).
3. **How many NPCs, and where?** A hamlet of 5-10 near the start, or settlements placed by
   the world generator (the design already has settlement territory)?
4. **Authored or generated people?** Recommendation: authored for the first hamlet,
   generated villagers later.
5. **May the LLM create quests?** Recommendation: only from the fixed favour kinds, with
   rewards the game sets.
6. **Language:** English text with Low German/Frisian flavour words, or a full Low German
   option later?
7. **Do NPCs need the player at all to change?** E.g. marriages, deaths, moving away over
   the years. Recommendation: later, from events, not from the LLM.
8. **Children, animals, ghosts and the fantasy layer:** the fantasy that comes later in the setting
   could start here (a Wiedergänger on the dyke, the Klabautermann on a ship).
