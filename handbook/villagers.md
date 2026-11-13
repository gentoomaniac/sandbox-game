# Villagers

The people of Wehlsbüll: how they live, what they notice, and how to talk to them.

The first people of the coast: villagers dressed in the clothes of the period, the men in knee
breeches, waistcoats and felt hats, tricornes or red and white stocking caps, the women in long
skirts, laced bodices, white, blue or striped aprons, shawls and white coifs or headscarves, each
with a skin, hair and clothes of their own and a North Frisian or Low German name (Antje Boysen,
Momme Ketels). Like you they are drawn at 32 px per tile, with faces, buttons, stockings and clogs,
and stand on a small shadow. They keep to within about six tiles of the house or campfire nearest to
where they came, stand about and stroll by day and stand still at night; you walk through them, so
they never shut you in. For now they come from the console; they are saved with the game.

Villagers notice what you do. Each tree you fell, house you build or take down, fence or wall you
put up, patch you till, sow, harvest or mow and clay you dig is a deed, and every villager within 20
tiles of it (6 at night, when they stand still) saw it. The game writes down who saw what, where (by
the house of the villager whose home is nearest, else "out on the geest" and the like) and on which
day, merging a day's deeds of one kind in one place ("felled 7 trees by Antje's house"), and keeps
it for 7 days, in the save. Each witness remembers the deed as a story in their gossip buffer (10
stories by default, set under Settings → Language model), which the chat prompt tells as a plain
line ("Today you saw the newcomer fell 7 trees by Antje's house."). A story weighs high if the deed
was by the witness's own house or that of family or friends, else medium; when the buffer is full
the oldest story leaves, and becomes a long-term memory of its weight (a story that weighs little is
forgotten). The console's `deeds` lists the log. The kinds, their words, the radius and the places
are in [data/gossip.cfg](../data/gossip.cfg).

Villagers talk. Two who stand within 3 tiles of each other meet (a pair at most once an hour of game
time, villagers in view or not), and each may pass on one story the other lacks: the weightiest and
newest of those they have known for 2 hours, more likely to family and friends, then to neighbours
(the 3 villagers whose homes are nearest), least to anyone else. A rumour stops after 3 hops or when
its deed is 7 days old. The one who hears it keeps it as a light story and is told it by the teller:
"Today Moiken told you that the newcomer was seen to fell 7 trees by Antje's house." (`gossip
<villager>` in the console shows who heard what from whom.) The chances and waits are in the
`[meetings]` section of [data/gossip.cfg](../data/gossip.cfg). Rumours change on the way: at each
hop, one time in ten, the count grows ("7 trees" become "10", or "a dozen"), the place moves to a
neighbour's house, or the deed turns into a similar one (felling into mowing, building into
fencing); `[whispers]` and `[whisper_kinds]` of the same file hold the steps and the table.

Each villager has an opinion of you, in points from -100 to 1000 (it starts at 0 and moves at most
20 points a day, up or down). The chat prompt tells it in words, never in numbers: cold (below -20),
neutral, or warm (from 20), and the villager answers accordingly. What moves it is what they make of
the stories they come to know, seen or heard (the judge): each deed has a fixed change in
[data/gossip.cfg](../data/gossip.cfg) (felling a tree -1, building a house +1, taking one down -2; a
step is 10 points), in full for what the villager saw and by half for what they only heard. With a
language model set, the model is asked in the background, one story at a time, with a low
temperature of its own (`[judge]` of [data/npc_talk.cfg](../data/npc_talk.cfg)), and answers in
JSON: the story in the villager's own words ("Moiken told me you felled half the Boysen wood", which
the chat prompt then tells in place of the plain line), what they make of it from -2 to 2, and
whether it touches them personally (the story then weighs high and is kept longer). An answer that
is missing, does not parse or is out of range counts as no model: the plain line, the deed's fixed
change, not personal; without a model all stories are judged that way at once. The console's
`opinion` shows and sets the opinion; the limits are in `[opinion]` of the same file.

They all live in Wehlsbüll, a made-up marsh parish two hours north of Husum in 1750, which
[data/village.cfg](../data/village.cfg) describes as everyone there knows it: the church, the Krug,
the mill, the dyke and its sluice, the Koog, the creeks and the Geest; who is who (Pastor Johann
Martens, the Deichgraf Peter Momsen, the Deichvogt Brar Feddersen, the innkeeper, the Amtmann at
Husum); prices in Schilling and Mark; this year's news (the cattle plague, the dyke broken last
autumn); the church year; and what people of the time know of the world (the Danish king, the Duke
of Gottorf, who speaks what). The villagers written by hand know all of it; a made-up one (`spawn
npc`) starts knowing none of it, only that they live in Wehlsbüll, and a model is told just the
topics a villager knows. When two villagers meet, one who knows a topic teaches the other the next
they lack, so newcomers learn the village from the locals and from each other, one topic at a
meeting (`chance_topic` in [data/gossip.cfg](../data/gossip.cfg)). The console's `gossip <villager>`
lists them.

**Bubbles.** About once a minute a villager in view says a short line in a bubble over their head
for five seconds, never more than one on screen: about the weather or the time of day, or, when they
are near you, about you, by what they think of you and the stories they know. With a language model
the line is asked of it quietly in the background (with the chat's temperature) and dropped if the
villager has left the view by then or the model gives nothing usable; without one it is a scripted
line of `[bubble_lines]` in [data/npc_talk.cfg](../data/npc_talk.cfg), by weather, part of the day
or opinion. The numbers (`[bubble]` there) are the interval, how long a bubble stays, the longest
line and how near is "near". The bubble is HUD text in the pixel font, cream with ink, at any zoom;
nothing of it is saved or remembered.

![A lone villager in the rain with a speech bubble and its tail over her head, in the 32 px and the classic art](../docs/screenshots/villager-bubbles.png)

Each villager has a sheet: age, trade, personality, background, home, how they speak (a manner, so
it holds in any language), lines in their voice, their family and friends with what they think of
each, likes, wants, their day, what they don't know or won't talk about, and a secret or two. Eight
are written by hand in [data/villagers.cfg](../data/villagers.cfg), two families and their friends,
and come with `spawn npc <id>`: `antje` (Antje Boysen, a farmer's wife), `hinrich` (her husband) and
`boy` (their son), `momme` (Momme Ketels, a fisherman of the tidal creeks) and `inken` (his
daughter, Boy's sweetheart), `ocke` (Ocke Hansen, the miller) and `gesche` (his wife, Antje's
friend), and `kerrin` (Kerrin Paulsen, the late Deichvogt's widow, Gesche's aunt, who lived through
the Christmas flood of 1717). Everyone a sheet names as kin or close friend is one of them, and the
sheets agree with each other (a test checks that each names the other back, the ages and the homes).
Edit their sheets freely: a saved game takes them from the file each time it loads. `spawn npc 3`
makes villagers up, with a sheet drawn from the tables of [data/npcs.cfg](../data/npcs.cfg) once and
kept: newcomers and people of the outlying farms, kin to none of the families.

Face a villager and press E to talk: the name over their head shows whom E speaks to. The chat is
laid out like a messenger: the villager's portrait on the left and yours on the right, and between
them the talk as bubbles, the villager's on the left under their name, yours on the right, each with
the game time in its corner; a "..." bubble shows the villager is still answering. The chat never
outgrows the window, also at a larger UI scale: it gets narrower and shorter and the lines wrap.
Type a line and press Enter; Escape leaves. The game stands still while you talk. A villager keeps
the latest lines of your chat (24 by default, set under Settings → Language model) for the next
time, so a reopened chat goes on where it left off; the older lines are summed up in one remembered
line (by the model, else it is what you said), kept as a long-term memory (20 by default; the
lightest is forgotten first), and later talks build on it. Type `/clear` in a chat to make that
villager forget everything but what they know: the chat, the stories they keep and their memories
(for debugging). With a language model set under Settings → Language model (see [Talking
NPCs](#talking-with-a-language-model)) villagers answer in their own words; without one they say
short scripted lines ("Aye.", "Is that so?"). While one villager is still answering you may leave
and talk to another; the answer waits in the first one's chat.

![Villagers by the camp, the name of the one E would speak to over their head](../docs/screenshots/npcs.png)

![A chat with Antje Boysen: the villager's bubbles on the left, yours on the right, the villager still typing](../docs/screenshots/npc-chat.png)

The pixel font has the Latin-1 letters (ä ö ü ß å æ ø é ç ñ ...), the Latin Extended-A letters of
the neighbours' languages (Polish, Czech, Turkish and others) and the typographic quotes, dashes and
« » ¿ ¡ …, so the villagers' German, Danish and Dutch show as written.

![A chat with German and Danish lines, and the accented capitals](../docs/screenshots/font-umlauts.png)

## Talking with a language model

Villagers talk through an OpenAI-compatible chat endpoint, or through Claude. Out of the box the
game asks the test LLM on `http://127.0.0.1:11434/v1` (see below); when nothing answers there, or a
reply takes longer than 30 seconds, villagers say short scripted lines instead, so the game never
needs a model. With a model you set up yourself it is different: if it fails, the villager says
nothing (see "When the model fails" below).

**Configuring it.** Settings → Language model has a choice of profile with New, Copy and Delete
buttons, a name, a provider, five fields and the chat length, each stored as you type or pick. A
profile is a provider (OpenAI-compatible, Claude or Gemini) with its own endpoint, model, max
tokens, temperature and chat length, so the same provider can have several: say Gemini with a flash
and with a pro model, or one model warm and one steady. There is one profile for each provider to
begin with, named after it. The key belongs to the provider, not to the profile: type it once, and
it is only ever sent to that provider's endpoint.

| Field | Default | What it is |
|---|---|---|
| Profile | OpenAI-compatible | The profile in use; choosing one shows its settings and the key of its provider. The three to begin with are OpenAI-compatible (the test LLM, Ollama, LM Studio, hosted APIs), Claude (starting with `https://api.anthropic.com/v1` and `claude-opus-5-5`) and Gemini. New adds one of the same provider with that provider's endpoint and model, Copy one with the same settings (named "<name> copy"), Delete removes the one in use (the last stays). |
| Name | the provider's | What the profile is called in the list; typed in and kept when you press Enter or leave the field. Every profile has a name of its own: an empty one or one another profile has is refused, and the page says why. |
| Provider | OpenAI-compatible | OpenAI-compatible, Claude or Gemini. Choosing another gives the profile that provider's endpoint and model; the rest stays. |
| Endpoint | `http://127.0.0.1:11434/v1` | The base address of the chat API; the game posts to `<endpoint>/chat/completions`. Empty it to turn the model off (villagers then always speak scripted lines). |
| Model | `qwen2.5:7b-instruct` | The model name the endpoint should use: typed, or picked from the drop-down below it, which lists what `<endpoint>/models` answers (Claude's `/v1/models` with the key), asks again a moment after the endpoint or key is typed and by the Refresh button, and shows only the saved model with a note when the endpoint can't be asked. |
| Stories a villager keeps | 10 | A number from 1 to 100, one for each profile: how many stories (the deeds a villager saw you do) a villager keeps in mind. The oldest leaves when there are more: a light story is forgotten, any other becomes a long-term memory. Every story is sent with each question. |
| Memories a villager keeps | 20 | A number from 1 to 200, one for each profile: how many long-term memories a villager keeps. Each has a weight (low, medium or high; a summed-up chat is medium). When there are more, the lightest is forgotten, between equal weights the oldest. Every memory is sent with each question. |
| Lines a villager keeps | 24 | A number from 2 to 200, one for each profile: how many of the latest chat lines a villager keeps in the save and tells the model. Older lines are summed up in a memory; lowering it sums up the lines it drops, once the menu is closed. Every kept line is sent with each question, so higher values make the answers slower (and cost more with a hosted model). |
| Key | empty | Only for endpoints that need one: sent as the header `Authorization: Bearer <key>`, and never sent along a redirect. One for all the profiles of a provider. |
| Max tokens per answer | empty | The most tokens a villager's line or memory may take, a number from 1 to 32000. Empty is the game's own: 60 for a line and 40 for a memory, 1000 with Claude. A model that thinks first counts its thinking too, so give one such as Gemini's Flash a few hundred or more. |
| Temperature | empty | How freely a villager's reply varies, a number from 0 to 2: lower is steadier, higher more surprising. Empty is the game's own, 0.5. It does not change the memory summaries, which keep their own low temperature, and Claude's API takes none. |

The same live in `settings.cfg` (in Godot's user folder, e.g.
`~/.local/share/godot/app_userdata/Sandbox Game/settings.cfg` on Linux): the profiles and the name
of the one in use under `[language_model]`, the key of the OpenAI-compatible provider next to them
(where it was before there was a choice), Claude's under `[language_model.claude]` and Gemini's
under `[language_model.gemini]`. Only what differs from the defaults is written. A file from before
the profiles is upgraded when it is read: each provider's endpoint, model and tokens become the
profile named after it, the provider in use the profile in use, and the one number of chat lines
goes into each profile.

```
[language_model]
active="Gemini pro"
profiles=[{"name": "OpenAI-compatible", ...}, {"name": "Gemini pro", "provider": "gemini",
"endpoint": "https://generativelanguage.googleapis.com/v1beta/openai", "model": "gemini-2.5-pro",
"max_tokens": "", "temperature": "0.3", "chat_history_lines": 24}]
api_key="sk-..."

[language_model.claude]
api_key="sk-ant-..."

[language_model.gemini]
api_key="AIza..."
```

The key is stored as plain text there (never in the save, never logged; `make lint` fails on
anything that looks like a key in the repository, and `.gitignore` keeps any `settings.cfg` out),
and what you say to villagers goes to that endpoint. Ollama, LM Studio (`http://127.0.0.1:1234/v1`),
llama.cpp's server and hosted OpenAI-compatible APIs work as the OpenAI-compatible provider. To try
an endpoint and key by hand:

```
curl -s <endpoint>/chat/completions -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <key>' \
  -d '{"model": "<model>", "messages": [{"role": "user", "content": "Moin!"}]}'
```

(Leave out the `Authorization` line for an endpoint without a key, like the test LLM.) When the
endpoint can't be reached, the game's output says so once, not for every line.

**When the model fails.** If a model you set up yourself is busy, refuses the key, can't be reached,
takes too long or gives nothing, a red notice at the top left says so, like "Villagers' language
model is busy (HTTP 503): This model is currently experiencing high demand." (the message is the
API's own, cut short; the game's output has it in full). The model's notices share one line, the
same trouble is shown again only after 5 minutes, and a quiet "Villagers' language model answers
again" follows when it works again. A failed request adds nothing to the chat: your line stays, the
"..." of the villager typing goes at once and you can write again. The test LLM on the default
endpoint never shows a notice and, as before, gets a scripted line. The times are in `[request]` of
`data/npc_talk.cfg`.

**Claude.** Pick the profile Claude under Settings → Language model and paste an Anthropic API key
(console.anthropic.com) into Key; the endpoint becomes `https://api.anthropic.com/v1` and the model
`claude-opus-5-5`. Everything the villager is told and everything you say to villagers then goes to
Anthropic over the internet, and the key sits in `settings.cfg` as plain text. A line costs about
2,500 tokens in (the full sheets, more with a long chat) and 40 out: roughly 1 cent with
`claude-opus-5-5` ($4 / $20 per million tokens), roughly 0.03 cents with `claude-haiku-5-5` ($0.10 /
$0.50), which is plenty for small talk: pick it from the model list. The game sends the Messages
API's `x-api-key` and `anthropic-version` headers, no temperature (current models refuse it), low
effort and room for 1000 tokens (a model's thinking counts against that; the reply is trimmed to two
sentences anyway); on Opus and Sonnet a refusal falls back server-side. A refusal, an error or a
time-out gives no line and a notice, as with any endpoint you set up. The numbers are in `[claude]`
of `data/npc_talk.cfg`.

**Gemini.** Free within Google's limits, with an API key from AI Studio (aistudio.google.com/apikey:
Create API key, in an existing or new Google Cloud project; without billing the key stays on the
free tier). Pick the profile Gemini under Settings → Language model and paste the key (it starts
with `AIza`); the endpoint becomes Gemini's OpenAI-compatible
`https://generativelanguage.googleapis.com/v1beta/openai` and the model `gemini-2.5-flash-lite`,
which answers fast and doesn't think first: a model that thinks may spend a line's 60 tokens before
saying anything (raise Max tokens per answer for one). The model list shows what the key may use.
What villagers are told and what you say goes to Google, and on the free tier Google may use it to
improve its models. To check a key: `curl -s
https://generativelanguage.googleapis.com/v1beta/openai/models -H "Authorization: Bearer <key>"`.

**The test LLM.** `make llm-up` runs Ollama with Qwen2.5 7B Instruct (4.7 GB, Apache-2.0) in a
podman or docker container on `http://127.0.0.1:11434/v1`, the default endpoint, so villagers talk
as soon as it is up; `make llm-check` asks it one question and `make llm-down` stops it. The
container image (5.5 GB) and the model live in the container tool's storage and the volume
`sandbox-game-llm-models`; `make llm-down PURGE=1` deletes the model. Details in
[tools/README.md](../tools/README.md). A reply takes a second or two on the GPU (NVIDIA or AMD,
found by itself; `make llm-gpu-setup` prepares it, see the same page), a few seconds on the CPU; one
that takes longer than 30 seconds, or fails, becomes a scripted line. To try another model, run
`make llm-pull LLM_MODEL=qwen2.5:3b-instruct` (twice as fast, but its lines are less sensible) and
set it as the model in Settings; [tools/README.md](../tools/README.md) lists some that fit, and says
how `make llm-eval` compares models on the villagers' prompts.

What the model is told for each reply (the words are in [data/npc_talk.cfg](../data/npc_talk.cfg),
shaped like a prompt that worked well with the test model): a system line (1750 on the North Frisian
coast, one or two sentences of small talk that answer what you said, in your language, never break
character, puzzled by what did not exist then; keep to the sheets and to what was said earlier in
the talk, never make up relatives, names or places that are not on them but say they don't know,
speak in one's own manner, of which the sample lines show the manner and not the language) with the
village's sheet and the villager's, one example exchange (of a blacksmith who is not one of the
villagers, so that the model does not copy a villager's words into the others' mouths), the lines of
your chat with them that they keep (24 by default; the older ones are in their memories), and then
the villager's name, trade, age, look in words and what they remember of earlier talks and of what
they saw you do lately, the moment (the date as the clock shows it and how far into the season, the
time and part of the day by the sun, the weather as it is: rain, snow, fog or the sky, the
temperature, frost, the wind and where it blows from; and the house or fire they stand by), that you
are a newcomer whose name they don't know, what you said, and the language they answer in. The game
tells that itself: it recognises English, German and Danish by common words and letters (the lists
are in the data file), so the prompt says "Antje answers in German." right before the answer, and a
line too short to tell ("Moin", "Hej") keeps the language of your last line that could be told. A
language it does not know (Swedish) is not named; the villager is then only asked to answer in the
language you spoke (switch language mid-chat and they follow). Only the reply and the memory lines
are kept (a memory is one sentence the villager writes in the first person); nothing else in the
game changes by what the model says.

**Full or cut-down sheets.** A hosted model (a provider that needs a key: Gemini, Claude) is told
the full sheets, about 2,000 tokens a line. A local model (the OpenAI-compatible provider, such as
the test LLM) is told cut-down ones, so that a 3B or 7B stays fast: the villager's essentials,
family and friends by name, manner of speaking and one sample line, and the village facts most
likely needed (where it is, who is who).
