# Sound and music

What you hear in the game, and how to turn it up or down.

Footsteps follow the walk and the ground (grass, soil, sand, wetland, ice, snow, a wooden floor),
and every tool, pickup, building and menu has a sound, played from where it happens. Inside a house
the weather and the world outside are muffled and faint, and a room with a hearth crackles with the
fire, louder the nearer you stand to it (all through a small house, only near the fire in a big
one). Settings → Audio has Master, Effects, Ambience and Music volumes and "Sound in background"
(off: silent while the window is not focused). What you do is heard when it worked; an action the
game refuses only says "denied". While the game is paused (the pause menu and its settings, a chat,
a choice) every sound of the world fades out and comes back when you go on; only the music and the
menu's own clicks play (moving a volume slider clicks at its level, so you hear it). Which file each
sound plays is in [data/sounds.cfg](../data/sounds.cfg), so any sound can be swapped for a
recording.

The game plays its own music: two calm pieces made of chiptune instruments, "Tide" (a slow 6/8 sway
in D dorian) and "Harbour evening" (a capstan bass under a shanty-like tune, in A aeolian). Each
loops three times, then the other crossfades in on the next beat, round and round (the Music volume
is in Settings → Audio; 0 turns it off). The pieces are rendered in the background, so the game
never stalls: the first start takes a second or two before the music begins, and later starts load
the renders from a cache in the save folder (`music_cache/`, at most 64 MB, the oldest go first).
The pieces, the loops, the fades and the cache bound are in [data/music.cfg](../data/music.cfg).
There is no music in test runs (`--mute`) or headless.

The world has an ambience too: rain and wind loops that follow the weather (and swell with gusts,
heard as the gust fronts that bend the grass reach you), thunder after each flash of lightning by
how far the strike was (a far rumble many seconds later and faint, now and then a close crack almost
at once, now and then a rumble that crawls across the sky), birds chirping by day, deer, rabbits and
squirrels, bees buzzing at their flowers, frogs croaking near water on warm spring and summer
evenings and nights (and, where frogs are about, a quiet chorus of them at dusk), a stork clattering
its bill, geese honking and crows cawing, and now and then a quiet moo, baa or cluck from the farm
animals, and a rooster who crows at dawn and now and then through the day (the numbers are in
[data/livestock.cfg](../data/livestock.cfg)). How often and how loud the others are is in
[data/ambience.cfg](../data/ambience.cfg).
