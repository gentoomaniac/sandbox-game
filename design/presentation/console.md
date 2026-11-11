# Console

Decided 2026-11-05. A text console for testing and cheats.

- `/` opens it (a rebindable action like all keys); Escape or Enter on an empty line closes
  it. While it is open the game keeps running, but the player doesn't walk or act.
- Commands: `help`; `tp <x> <y>` (teleport to a world tile; from inside a house the player steps out there); `give <item>
  [count]` (into the inventory); `god` (toggle invincibility:
  health doesn't drop); `nodrain` (toggle: actions cost no energy); `noweight` (toggle:
  carried weight doesn't raise costs); `noneeds` (toggle: the farm animals' hunger and thirst
  don't rise, task 122); `noclip` (toggle: nothing blocks the player, who stays
  on the map's tiles; turned off where they don't fit, they are put on the nearest free
  ground); `freeze` (toggle: the game clock stands still, so the day, crops and weather
  wait, while the player and the animals still move; `skip`, sleep and passing out still move
  it on). Later commands: `spawn` (villagers: `npc`; farm
  animals: `cow`, `sheep`, `chicken`, `rabbit`, `dog`, `cat`, `horse`; wild ones: `bird`,
  `wild_rabbit`, `squirrel`, `deer`, `bee`, `butterfly`, `flock`, `stork`, `roof_stork`,
  `geese`, `flying_geese`, `mouse`, `frog`), `killall <kind>` (task 193: removes every animal of a
  kind `spawn` knows, from the running game and from the saved state, and says how many;
  `killall npc <id>`, or just `killall <id>`, removes that one villager of data/villagers.cfg with
  their chat and memories; a bare `killall npc` removes every villager without an id (those made
  up by `spawn npc` or the tables), says how many, and that the named ones stay and need their id;
  a villager's home, trade and relatives are text in data/villagers.cfg, so nothing else holds on
  to them; wild animals are not saved, so only those alive now go and the spawn rules may bring
  others, which the answer says; a horse the player rides is not removed, the player gets off
  first), `weather`, `snow`, `crop`
  (see `help`), `friendship [0..100]` (shows the friendship of the nearest animal that can be
  petted within 3 tiles, or sets it; task 173), `reset` (puts the player in the bed they wake in,
  inside or out), and
  `skip <n>m|h|d` (let minutes, hours or days pass, at most a year; only the world
  moves on, as when sleeping, so crops grow; the player's energy, tiredness, debuff and
  position are left alone).
- Tab completes command names and every argument with a fixed set of values: item ids,
  animal kinds (also for `killall`), weather conditions, snow values. Each command lists its
  argument kinds in one table in the console code; numbers are not completed. `help <command>` and a missing
  or unknown name (`spawn`, `spawn unicorn`) list the animal kinds, weather conditions and
  snow values from that same table.
- Cheat toggles last for the session; they are not saved. A line in the HUD shows which
  are on.
- The log is a `ScrollingList` of a fixed height (8 lines) holding the newest 500 lines: the wheel,
  its bar and Page Up / Page Down scroll it; new output keeps the view at the bottom unless the
  player scrolled up, and opening the console shows the bottom.
- A history with up/down; output and errors in the console log. The input line keeps the
  focus while the console is open: clicks elsewhere don't take it, and it stays ready
  after Enter.
- Always available for now. Whether release builds lock it is decided later.
