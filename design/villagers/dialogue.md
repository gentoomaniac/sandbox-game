# Talking to villagers

- **Talking:** E speaks to the villager on the targeted tile, or the nearest one in reach in
  front of the player, before any chest, station or bed; that villager's name shows over
  their head. The chat pauses the game and is laid out like a messenger: the villager's
  portrait on the left, the player's on the right (32x32 head-and-shoulders portraits laid
  together from the same layers, each the top of the layer's frame facing the viewer, drawn at
  2x), names under them, and between them the lines as
  bubbles: the villager's on the left with their name above the first of a run, the player's
  on the right, each with the game time small in its bottom corner, at most 70% of the window
  wide with the text wrapped, closer together within one speaker's run than between speakers
  (palette colours only). Above each day's lines a small centred line says the day ("Today",
  "Yesterday" or the date, decided 2026-11-09), so a line of an earlier day doesn't look newer
  than the next. The window scrolls to the newest line (and back with the wheel or
  Page Up/Down), and a one-line input. The log is 340x176 UI pixels at most and never bigger than
  the window leaves at the current UI scale (less the margin other windows keep), down to a
  minimum of 128x64; the bubbles' widths follow it and the text wraps within them, while the
  text still grows with the UI scale (decided 2026-11-09). Enter sends; while the answer is awaited the villager
  has a "..." bubble; Escape leaves (and doesn't open the
  pause menu). The villager turns to the player and stands a while.
- **Answers:** one function, `NpcDialogue.reply`, awaited by the chat. With a language model
  set in Settings (a provider, an OpenAI-compatible chat endpoint by default, the test LLM's
  `http://127.0.0.1:11434/v1`, or Claude, whose endpoint and model, `claude-opus-5-5`, it starts
  with, or Gemini through its OpenAI-compatible endpoint, with `gemini-2.5-flash-lite`; each
  profile has a provider and its own endpoint, model, most tokens an answer may take, temperature of
  a reply (empty: the game's own) and lines a villager keeps, and the key is the provider's, so it
  goes only to its own provider (`LanguageModelProfiles`; Settings picks the profile and adds,
  copies, renames and deletes them, the last one stays, and several may share a provider, say
  Gemini with a pro and a flash model; a file from before the profiles is upgraded: a profile
  for each provider, named after it); a model, picked from the endpoint's list of models or typed; an optional key; an
  emptied endpoint is none) it asks the model; without one it says a scripted line of `data/npc_talk.cfg` ("Aye.", "Is that so?"), and so it
  does on the default test endpoint when nothing answers, on an error or after 30 s. With any
  other endpoint, such a failure (also an empty answer) gives no line at all: nothing is added
  to the chat, the typing bubble is removed at once, the player's line stays and they may write
  again (`NpcDialogue.say`; a failed exchange is not compacted). When the model
  of an endpoint the player set fails, `ModelChat` sends `failed` and `ModelNotices` shows it in
  the notifications (task 168): one key, "Villagers' language model is busy (HTTP 503): <API
  message, cut>", the same trouble not again for `notice_repeat_seconds`, "... answers again"
  after it works; the default test endpoint stays silent. The answer is trimmed to the
  spoken line: no quotes or name in front, its first line, at most two sentences. Only the
  words come from the model; nothing else in the game changes by what it says.
- **The prompt** (`data/npc_talk.cfg`, the user's working example of 2026-11-06 in shape;
  temperature 0.5 since task 96 (was 0.7; the Temperature of Settings replaces it for a
  provider, 0 to 2, but not for the memory summary, which has its own 0.3), at most 60 tokens): a system line (dialogue for one
  villager of Wehlsbüll on the North Frisian coast in 1750, one or two short sentences of small
  talk that answer what was said, in the language of the neighbour's latest line (English if that
  is English), never break character or act as an assistant, keep to the sheets and to what was
  said earlier, never make up relatives, friends, names or places beyond them but say one doesn't
  know, speak in one's own manner (the sample lines show the manner, not the language), puzzled by
  what did not exist in 1750, sharp to the rude) followed by the village's sheet and the
  villager's: in full for a hosted model (a provider that needs a key, `needs_key` of
  `GameSettings.LANGUAGE_MODEL_PROVIDERS`: Gemini, Claude), cut down for a local one (the
  villager's essentials, family and friends by name and kind, speech and one sample line; the
  village line and who is who), so that a 3B or 7B stays fast; the example
  exchange ("Villager: Hark Nissen, a blacksmith. / His neighbour says: "Fine weather for the hay
  today." / Hark's reply:" and his answer; not a villager of the game, so that the models do not
  copy a villager's words into the others), the lines the villager keeps as turns of the same
  shape, and last what the player says, with the villager's age, look in words from the layers
  and memories, the moment (the date as the clock shows it and early, mid or late in the
  season; the time and part of the day by the sun: dawn, morning, noon, afternoon, dusk, night; the
  weather as it is: thunder, storm, snow, rain or fog by strength, else the sky by its clouds, the
  temperature, frost below 0 °C, the wind by strength and where it blows from; the building or fire
  within 8 tiles), that the player is a newcomer whose name they don't know, what the villager
  thinks of them in words (cold, neutral or warm, task 128; see [gossip.md](gossip.md)), and, right before the
  answer, the language the villager answers in (so a switch of language is followed, the user's
  word of 2026-11-07; task 95): the game detects it (`NpcLanguage`: English, German or Danish by
  the common words and telling letters of `[language]` in the data file; "Antje answers in
  German." and "Antje's reply in German:"). A line too short to tell has the language of the
  player's latest earlier line that can be told; with none, or in a language it does not know
  (Swedish has a word list of its own so that it is not taken for Danish), the prompt only asks
  for "the language the neighbour just spoke in". Derived from the chat, so nothing is saved.
- **The wait:** belongs to the villager: while one answers, the player can leave and talk to
  another (who shows no typing); the answer lands in the chat of the one asked. `NpcDialogue.say`
  sees the exchange through (line, wait, answer, memory), not the window, so freeing the window
  leaves no villager answering.
- **Chat history and memory (task 91):** a villager keeps the last N lines of the chat (the
  setting "Lines a villager keeps", 2 to 200, default 24, one for each profile); all go to the
  model as earlier turns, so a reopened chat goes on. Lines that drop out (after an exchange,
  when the setting is lowered, applied once the menu is closed, and on load) are made one dated memory ("On the 12th day of
  Spring, year 1 (mid spring): ..."): summed up by the model with a small prompt of its own (one sentence of at most 25 words, in
  the villager's first person),
  else the start of what the player said. One summary is asked for at a time; what drops
  meanwhile is summed up next. The memory is long-term, `{day, text, weight}` with the weight
  medium (task 126; see [gossip.md](gossip.md), Memory). A villager keeps "Memories a villager
  keeps" of them (1 to 200, default 20, one for each profile); beyond that the
  lightest is forgotten, between equal weights the oldest. Later prompts tell the memories and
  the kept lines.
  The prompt tells their knowledge (the sheets, in the system line), the long-term memories, the
  stories of the gossip buffer and the chat, in that order (the chat as the earlier turns). A story
  is told by its template line, or, once the judge has had the model put it in the villager's own
  words (task 128, in the background, one request at a time, its own temperature 0.2; see
  [gossip.md](gossip.md), The judge), by that line.
  Typing `/clear` in the chat forgets everything but the villager's knowledge: the chat, the
  stories, the memories and the lines waiting for a memory, with a line saying so (not sent, not kept); other text with a "/" is said as it is.
- **Settings:** the endpoint (default the test LLM's), the model (default
  `qwen2.5:7b-instruct`, the test LLM's) and the key are in the settings file
  (`[language_model]`); the key is plain text there, as the Settings page says, never in the
  save; it is sent as `Authorization: Bearer <key>`, and the client follows no redirect, so
  the key goes only to that endpoint. Claude's own API needs an adapter of its own (later).
