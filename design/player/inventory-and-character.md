# Inventory, tools and character

- **Tile targeting with the mouse:** the tile highlight follows the mouse cursor.
  - Within reach (the 3×3 tiles around the player for hand tools; later tools may reach
    further), the highlight shows normally, and the action (left click or Space) works on
    that tile.
  - Out of reach, the highlight turns translucent red and the action does nothing (the use rules refuse it themselves, so the same goes for any caller, not only a click).
  - When the mouse hasn't moved for a few seconds, the highlight fades out. Then the
    keyboard action (Space) works on the tile the player faces, as before, and the
    highlight shows that tile again once the player moves.
- **Inventory and equipment** (decided 2026-11-05):
  - The **hotbar** (8 slots, shown at the bottom of the screen; 10 until task 72) and the
    **backpack** (20 slots) are separate (changed 2026-11-05): what is on the hotbar takes no
    backpack space, so the player carries 28 slots. Screens show the backpack (4 rows of 5);
    the hotbar is only the HUD's (changed 2026-11-06, task 88): while the character or chest
    screen is open it stays lit, above the screens' dimmed backdrop, and is the quick bar
    there (its slots take the clicks; the screens draw no copy of it). A version 10 save moves
    what lay in the two dropped hotbar slots into the backpack (onto a stack of the same item
    first), or onto the ground at the player's feet when the backpack is full.
    Shift+click from a chest sends a stack to the backpack first, then the hotbar. Picked-up
    items (and anything else gained) fill the hotbar first: a matching stack there, then a free
    slot, then the backpack the same way; the held slot only when it is empty and nothing else is
    free. Backpack upgrades later add rows to the backpack.
  - The selected hotbar slot is what the player holds: keys 1–8 pick a slot. The use
    action (left click or Space) acts with the held item.
  - Items of the same kind stack, up to 99 per slot; tools don't stack.
  - Every item has a weight; the total carried weight raises how much energy actions use
    (see [Energy and sleep](energy-and-sleep.md)). The bag shows "Carrying x / y kg": the load
    over the carry capacity that Strength sets (task 187), which is a soft limit: more can
    always be picked up, it only costs more energy.
  - An inventory screen shows all slots; items are moved between slots by dragging (task 134,
    before that by clicking: pick up, put down, task 88). Press on a stack and drag it: its icon
    follows the mouse only while the button is held, and a plain click picks nothing up. Let go
    over a slot and the stack goes there; on a different item it swaps places, on the same item
    it merges (as far as the stack limit allows). Let go over nothing that takes it (the gaps of
    the panel, a slot that refuses it) and it stays where it was. Shift+click on the character
    screen sends a stack from the backpack to the hotbar and back (onto stacks of the same item
    first, then the first free slot, as far as there is room); in a chest screen it sends it to
    the other side.
  - **Dropping** (task 88): a backpack or hotbar stack dragged and let go outside the screen's
    panel, or the rebindable `drop_item` action (T) for the held stack, puts the stack on
    the ground in front of the player as piles like any drop (inside a house, on its floor: see
    [first buildings](../building/first-buildings.md)). Such piles
    are not pulled back until the player has walked out of reach of them; then they are
    collected as usual.
  - **Trash can** (task 133): a slot with a bin icon under the backpack in the bag and on the
    chest's screen (the character window has none: a worn item is taken off into the backpack
    first). Letting go of a dragged stack on it (from the backpack, the hotbar or the chest) asks "Destroy Logs (12)?" (just
    "Destroy Waistcoat?" for one) in a small panel over the screen, with Destroy and Keep (Keep
    has the focus). Destroy removes the stack for good, with no drop on the ground; Keep, Escape
    (which then does not close the screen) or any other click or wheel turn leaves the stack
    where it was (it never left its slot while it was dragged). The state classes do the
    removal (`ItemSlots.destroy`, `Equipment.destroy`); the trash can only asks and sends it,
    and does nothing if the stack asked about is no longer in its slot.
- **Character window and bag** (decided 2026-11-05 as one screen; B instead of Tab since task 190;
  split in two windows in task 191, 2026-11-12): C opens the character window with the character
  and their equipment, B opens the bag with the backpack. Both are Modals, so one is open at a
  time: from the backpack a worn item is chosen by right click in the bag, and from the hotbar
  (the quick bar of both) by dragging onto the slot in the character window.
  - Equipment slots: head, body, legs, feet, coat, back, main hand, off hand (coat added in
    task 53, for a jacket over the body item). Clothes, armour
    and later weapons, shields and backpacks are items with a slot; worn items show on the
    character (each slot is a sprite layer).
  - Items move between inventory slots and fitting equipment slots by dragging (swap
    included; from the hotbar, as the backpack is in the other window); an item only goes into a slot it fits, and fitting slots light up
    while an item is dragged. Right-click equips or unequips at once.
  - Keys: C opens the character window and closes it, K opens its skills tab and closes it from
    there; B opens the bag and closes it (Tab is unbound); Escape and the pause key close either.
    E does nothing while one is open. Crafting is Shift+C.
  - Worn items count toward the carried weight.
  - Hair and body are the character's look, not equipment.
  - New game (period clothes since task 53, North Sea coast 1700–1800): a red waistcoat
    over a linen shirt, brown knee breeches with white stockings and wooden clogs worn; a
    straw hat, a knitted cap, a spare linen shirt and a short blue jacket in the inventory.
    The clothes are light (0.3 to 0.6 kg) and the tools weigh nothing, so a new game carries
    2.9 kg, far under the 40 kg that cost no extra energy. Three hair styles: short, shoulder length, and long tied back
    with a ribbon. Old saves (version 8) get the tunic and trousers renamed to the waistcoat
    and breeches and clogs on their bare feet. The straw hat has a low crown and a wide brim drooping at its ends (task 52,
    it read as a pith helmet); the knitted cap is a red wool stocking cap, as the guide's
    period dress has it.
- **Movement keys:** arrow keys and WASD (decided 2026-11-05). All keys can be changed in
  the settings (see [Menus and settings](../presentation/menus-and-hud.md)).
- **Scale between character and world:** the character figure is 61 px tall (hat to soles)
  in its 32×64 frame (task 113; 27–28 px in 16×32 before). Mature trees are about 2–2.5× the
  character, a small house about 3.4× (5×3 footprint, door at least as tall as the
  character); numbers in `docs/archive/art-review-2026-11-05.md`, in pixels of the 16 px art.
- **Character sprite: 32×64 pixels** (one tile wide, two tall; 16×32 before task 113), built
  from **layers** (body, clothes, head/hair, held tool or weapon, later gear), so equipment
  can be shown by swapping or adding a layer instead of redrawing the character. Every layer
  is drawn on the same figure, so they line up; the faces have eyes with a glint, brows, a
  nose shadow, cheeks and a mouth. The player and the villagers stand on a small contact
  shadow, as the animals do. Every tool shows in the hand (its item's `held_sheet`), in
  every facing and walk frame; there is no use animation yet, so a tool stays in the hand as
  it is used. The held layer of the appearance follows the selected item in the player's
  state (as the worn layers follow the equipment), so every view of the look, also the preview
  on the character screen, shows it with no PlayerView at work.
- **Tools** are bought and upgraded (decided 2026-11-05):
  - The player starts with a hoe, axe, pickaxe, watering can, scythe, shovel and a bag of
    turnip seeds, all tools of the first grade, rusty iron.
  - **Grades** (task 207, 2026-11-13): every tool comes in five grades, from the worst: rusty iron,
    iron, brittle steel, steel and sharp steel, each its own item ("Rusty iron hoe", "Iron hoe",
    ...; the id is `<grade>_<tool>`, `rusty_iron_hoe`), drawn in its metal (see
    `docs/art-style.md`; the tool in the hand has a sheet of each grade). For now they come only
    from the console (`give iron_axe`); how they are made or bought is for later (a smith in a
    settlement, the user's 2026-11-05 idea). The grades are data (`data/tools.cfg`, read by
    `ToolGradeRules`, the items made in `ItemTypes`). An old save's tools become the rusty iron
    ones (save version 33). "Needs a better axe" names the kind of tool, not the grade.
  - **The numeral** (the user, 2026-11-11): a tool's grade shows as a Roman numeral, I (rusty
    iron) to V (sharp steel), drawn by the inventory slot (`SlotView`) bottom left, where the
    count is bottom right and the can's water top left; it is not baked into the icons, so the
    items lying on the ground stay clean. It is drawn pixel by pixel from the glyphs the task 206
    icons had (4 px tall, 1 px strokes, cream on an ink backing), so it is crisp in both arts at
    every UI scale; the data (`numeral` in `data/tools.cfg`) names it. The hotbar, the bag and
    the chests all show it, as they all use the slot; the icon dragged with the mouse has none.
  - **How a grade plays** (task 207; the numbers are the user's to tune in `data/tools.cfg`):

    | Grade | Level | Power (hit points a hit takes) | Energy of a use |
    |---|---|---|---|
    | Rusty iron | 1 | 1 | 100 % |
    | Iron | 2 | 2 | 95 % |
    | Brittle steel | 2 | 3 | 95 % |
    | Steel | 3 | 3 | 85 % |
    | Sharp steel | 3 | 4 | 75 % |

    The level is the tool's `level` (a tree or stone needs a tool of its `harvest_level`: the
    pine and the boulders need level 2, so a rusty iron axe and pickaxe can't, an iron one can).
    The power is what the axe and pickaxe take off an object's hit points per hit, so a better
    grade needs fewer hits (an oak of 5 hit points: 5, 3, 2, 2 and 2 hits; a boulder of 6: 3
    hits with iron). The energy share scales what every use of the tool costs
    (`data/energy.cfg`, on top of the weight factor), so a better tool tires less. The rusty iron
    tool is what the tools were before, to the number. There is no durability in the game, so
    the brittle steel tool does not chip: it hits hard, but being brittle it is no gentler on
    the energy than iron; the chip comes with durability.
  - The tool decides the action: hoe tills, seeds plant, axe fells, the pickaxe (the pick of
    the Geest, which grubbed the fieldstones of the till out of the fields) breaks stones, the
    watering can wets tilled soil, the scythe mows tall grass, the shovel digs for clay and digs bushes up,
    an empty hand harvests crops, clears dead ones and picks bushes.
- **The lantern** (task 177): a horn lantern with a tallow candle, for the dark nights. No
  recipe yet: the console's `give lantern` hands it out. Held and selected, the use key (space,
  or a click) lights it or puts it out, anywhere, with a soft pop; it needs no fuel for now. Lit,
  it casts a warm, softly flickering circle of light around the player (5 tiles, numbers in
  `data/lighting.cfg` [lantern]), one PointLight2D on the figure, as strong as the fires at that
  hour (so nothing by day, and only a faint glow in a house, whose tint stays as it was). It
  shines only in the hand (the user, 2026-11-11): put away in the bag, in a chest or on the
  ground it gives no light but stays lit, and shines again once it is selected. The hand shows
  it lit or unlit. Whether it is lit is saved (save version 28).
- **Attributes** (task 187): four levels, Strength, Agility, Stamina and HP, in `data/attributes.cfg`
  (name, tooltip text and base level each, and what one level gives). A new character has every
  level at 10, which gives what the game had before them: 100 energy, 100 health and 40 kg
  carried before the load costs more energy. One level of Stamina gives +10 maximum energy, one of
  HP +10 maximum health, one of Strength +4 kg carry capacity; Agility has no effect yet. The
  game reads them only through `Attributes` (`max_energy()`, `max_health()`, `carry_capacity()`),
  which counts an attribute's level plus the bonuses on it (food, items and the like later; a
  bonus belongs to a source and is not saved), so a new attribute or bonus source touches that
  class and the data file, and a villager or an animal can own one later. The levels are saved
  (save version 30); how a level grows is open, the console's `attribute` sets it for testing.
  The character tab (C) shows them below the figure: each level (a bonus beside it, "12 (+2)") with
  the attribute's tooltip, and the maximum energy, maximum health and carry capacity they give.
