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
    items join a matching stack first, then take the first free slot, hotbar before backpack. Backpack upgrades later add rows to the backpack.
  - The selected hotbar slot is what the player holds: keys 1–8 pick a slot. The use
    action (left click or Space) acts with the held item.
  - Items of the same kind stack, up to 99 per slot; tools don't stack.
  - Every item has a weight; the total carried weight raises how much energy actions use
    (see [Energy and sleep](energy-and-sleep.md)).
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
    the ground in front of the player as piles like any drop (not inside a house). Such piles
    are not pulled back until the player has walked out of reach of them; then they are
    collected as usual.
  - **Trash can** (task 133): a slot with a bin icon in the inventory column of the character
    screen and under the backpack on the chest's screen. Letting go of a dragged stack on it (from
    the backpack, the hotbar, an equipment slot or the chest) asks "Destroy Logs (12)?" (just
    "Destroy Waistcoat?" for one) in a small panel over the screen, with Destroy and Keep (Keep
    has the focus). Destroy removes the stack for good, with no drop on the ground; Keep, Escape
    (which then does not close the screen) or any other click or wheel turn leaves the stack
    where it was (it never left its slot while it was dragged). The state classes do the
    removal (`ItemSlots.destroy`, `Equipment.destroy`); the trash can only asks and sends it,
    and does nothing if the stack asked about is no longer in its slot.
- **Character screen** (decided 2026-11-05): Tab opens one screen with the character and
  their equipment on one side and the inventory on the other.
  - Equipment slots: head, body, legs, feet, coat, back, main hand, off hand (coat added in
    task 53, for a jacket over the body item). Clothes, armour
    and later weapons, shields and backpacks are items with a slot; worn items show on the
    character (each slot is a sprite layer).
  - Items move between inventory slots and fitting equipment slots by dragging (swap
    included); an item only goes into a slot it fits, and fitting slots light up
    while an item is dragged. Right-click equips or unequips at once.
  - Keys: Tab opens the screen (and closes it from the character tab), K opens the skills tab
    and closes it from there; Escape and the pause key close it. E does nothing while it is open.
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
    turnip seeds, all tools at level 1.
  - Upgrades later come from a smith in a settlement, in tiers (level 2 copper, level 3
    iron, as palette swaps of the same icon).
  - The tool decides the action: hoe tills, seeds plant, axe fells, the pickaxe (the pick of
    the Geest, which grubbed the fieldstones of the till out of the fields) breaks stones, the
    watering can wets tilled soil, the scythe mows tall grass, the shovel digs for clay,
    an empty hand harvests crops, clears dead ones and picks bushes.
- **The lantern** (task 177): a horn lantern with a tallow candle, for the dark nights. No
  recipe yet: the console's `give lantern` hands it out. Held and selected, the use key (space,
  or a click) lights it or puts it out, anywhere, with a soft pop; it needs no fuel for now. Lit,
  it casts a warm, softly flickering circle of light around the player (5 tiles, numbers in
  `data/lighting.cfg` [lantern]), one PointLight2D on the figure, as strong as the fires at that
  hour (so nothing by day, and only a faint glow in a house, whose tint stays as it was). It
  shines only in the hand (the user, 2026-11-11): put away in the bag, in a chest or on the
  ground it gives no light but stays lit, and shines again once it is selected. The hand shows
  it lit or unlit.
