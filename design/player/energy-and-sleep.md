# Energy and sleep

- **Energy bar:** actions use up energy.
  - Carrying weight increases how much energy actions use.
  - **At zero energy the player passes out** and wakes up in their bed. They lose no items
    or money, but they get a **debuff for the next day**: very slow walking, low health,
    very little energy. The real loss is the time: crops and other chores may go
    untended.
  - A game setting scales how fast energy drains.
  - Details (decided 2026-11-05):
    - **Energy and health bars**, 100 points each, next to the hotbar. A bar at 20 % or
      less pulses to show it is low. Health matters once combat exists; for now only the
      pass-out debuff and sleep change it.
    - **Costs per action** live in a hand-editable data file (`data/energy.cfg`). First
      values: tool use (till, hit, water) 2, planting and picking 0.5; walking is free.
    - **Weight:** up to 40 kg costs nothing extra (changed 2026-11-06, was 20 kg); above
      that, +10 % cost per 10 kg more. Tools weigh nothing (task 72).
    - **Low energy slows walking:** at 10 % or less to 75 % speed, below 5 % to 50 %.
    - **Passing out** at 0 (changed 2026-11-05): the player sleeps until the next 06:30,
      but at least 10 hours (collapsing at 22:00 wakes at 08:00, at 15:00 at 06:30), and
      wakes in the home bed. That day: half walking speed, energy only up to 50 %, health
      25. Speed effects don't stack; the slowest wins. The debuff lasts until the next
      midnight the player lives through (awake or asleep, a console `skip` is not that);
      sleeping does not end it early.
    - **Staying up too late** (decided 2026-11-05): a player still awake at 01:00 passes
      out as well, with the same flow and debuff (the 10-hour minimum wakes them at 11:00);
      the message says they stayed up too late instead of running out of energy. Only time
      the player lives through counts: a console `skip` over 01:00 does not make them pass
      out (like it costs no energy and ends no debuff: the player is a time traveller, and a
      `skip` moves only the world), and sleeping over it of course doesn't either.
    - **How passing out looks** (decided 2026-11-05): the player stops, can't be
      controlled, sinks to the knees, tips over and lies asleep with rising "z"s (about
      1.5 s, the world keeps running), then the screen fades to black. A short message fades
      in: what happened, how long they slept, where they wake ("at home" or "at the camp")
      and what the debuff does, e.g. "You collapsed from exhaustion. You slept 10 hours and
      wake at the camp, still worn out: slow, weak and with half your energy until
      midnight." After a key or click it fades into the bed in the morning. The asleep
      frames are reused for sleeping on the ground later. The collapse is drawn from the
      side: a player facing up or down falls to the right. The held tool is not drawn while
      down. The clock stands still while the screen is black.
    - **Signs of tiredness** (decided 2026-11-05):
      - **Sweat:** while energy is at 20 % or less, every action (tool hit, till, water,
        mow, dig, plant, pick) throws one sweat drop off the head; at 10 % or less two or
        three, in a slightly bigger arc.
      - **Thought bubble** (changed 2026-11-05): a small "zzz…" bubble pops up above the
        player for about 2 s at 00:00 and again at 00:30 while they are awake, as the
        warning before passing out at 01:00. It is only the late-hour warning; low energy
        shows by sweat alone.
        The bubble is a general system: an icon in a bubble over the player, to be used
        later for other states (cold, hungry, a question mark, ...).
    - **Sleeping** fills energy and health per bed (sleeping bag 100 %, ground 50 %), and
      **eating** food (berries, turnips) restores a little energy. Both are values in the
      data file (`data/energy.cfg`).
    - The energy drain setting: Low ×0.5, Normal ×1, High ×1.5.
- **Home is the last bed the player slept in**, like a spawn point. Passing out wakes the
  player there. The bedroll can be taken down and set up elsewhere (task 137): if it was the
  home bed, the home has no bed until one is set up, and that bed becomes home. **With no bed
  at home** (taken down, or something else standing on its tile) passing out wakes the player
  standing at the world's start point, the spot where a new game begins (like a world spawn;
  `CampSite.spawn_of_seed`, derived from the seed, so nothing new is saved), and that spot is
  home until a bed is set up or slept in (decided by the user, 2026-11-09). If something now
  stands on the start point the player is put on the nearest free ground. A bedroll set up
  while another bed is home leaves the home alone until the player sleeps in it.
- **Waking in the bed** (decided 2026-11-06, after a player woke behind a bed and was stuck):
  after sleeping and after passing out the player wakes lying in the middle of the bed, head
  on the pillow and the body under the blanket (the asleep frame of the collapse, turned to
  the bed; the bedroll at the camp has its own cover, `ObjectCover`). The beds of the houses
  are drawn in layers: frame and pillow under the player, the blanket over them while they
  lie there, down to the foot, so the clogs don't show (task 112). Beds block walking (the bedroll does not). **Getting out** (decided 2026-11-06, after
  players walked into the cupboard bed): the first move puts the player on the free tile beside
  the bed in the direction they pressed; if that is a wall or taken, on a free tile at the front
  of the bed (opposite its head, facing into the room), else at its sides, never behind it.
  Then they walk on. A player standing where they do not fit (an old save, or one made in
  bed) walks through objects, not walls, until they are free, so nobody is stuck.
  Nothing of this is saved: a game saved in bed loads with the player standing on it.
- **Starting shelter:** the game starts at a small camp site with a fireplace and a
  bedroll, so there is a bed at the start (it is no longer always there: the player can take
  it down, see Home above). The bedroll (task 52, replacing a modern sleeping bag) is a straw
  sack with a rolled grey wool blanket; its type id stays `sleeping_bag`, so saves and
  `data/energy.cfg` are unchanged. It has snow and frost looks.
- **The player can sleep without a bed** (on the ground, anywhere), with a real penalty:
  - energy fills to only 50 %;
  - it does not set home;
  - in dangerous areas, creatures can attack the sleeping player;
  - there is no next-day debuff. That stays unique to passing out, so the two feel
    different.
- **Sleep lasts until the next morning** (changed 2026-11-05, replaces the fixed duration
  per bed): sleeping always wakes the player at the next 06:30, whenever they lie down
  (after midnight that is the same morning). The screen fades to black and back, showing
  the new day briefly (its date on the black), with no key press. Beds differ only in what
  they restore.
- **Later: sleeping quality depends on the bed.**
  - The sleeping bag is the baseline: it fills the energy bar to 100 %.
  - Better beds may fill the bar a little above 100 %. Better beds should feel like a
    bonus, not like escaping a penalty.
  - Other bed bonuses come later.
  - Left out for now: less energy when going to bed very late (a 05:00 nap still refills
    fully).
