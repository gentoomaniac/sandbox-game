# Android

**Planned, not implemented.** Control audit and proposal, 2026-11-13.

Decided by the user on 2026-11-13:

- Android only for this port. No web or iOS version for now. Desktop play stays as it is.
- Movement uses a software joystick.
- Text uses the Android on-screen keyboard, including chat, the console and naming things.
- The inventory and hotbar take touch, including drag and drop as on desktop.

Everything else below is a proposal, not a new decision. Use Godot 4.7.2, as pinned in
`.godot-version`. Keep the same GDScript state, world, content and save format.

## Today's controls

This is an audit of `project.godot` and the input handlers in `game/`, not just the README's
control list. Frequencies are estimates for ordinary play, not measurements. "Debug" means
testing, not a control that a player needs to progress. Some debug features are available in
ordinary builds today.

In the tables, bare GDScript filenames are in `game/scenes/`; for example `main.gd:428` means
`game/scenes/main.gd:428`. `project.godot` is at the repository root. Lines refer to the code on
2026-11-13, before any Android work. The final column names the touch replacement described
under "Touch controls". It is not another desktop binding.

### Every project input action

The source column gives the action's entry in `project.godot`'s `[input]` section. All defaults
there use physical keys. Settings can replace them. The dispatch sites follow the table.

| Action | Key | What it does | Source | Need | Touch |
|---|---|---|---|---|---|
| move_left | A, Left | Walk left | project.godot:74 | Constant | J |
| move_right | D, Right | Walk right | project.godot:79 | Constant | J |
| move_up | W, Up | Walk up | project.godot:84 | Constant | J |
| move_down | S, Down | Walk down | project.godot:89 | Constant | J |
| toggle_fast_forward | F2 | Speed up time | project.godot:94 | Debug | D |
| toggle_coordinates | F3 | Coordinates, weather, FPS | project.godot:100 | Rare | D |
| zoom_in | =, keypad + | Zoom in; repeats held | project.godot:106 | Often | Z |
| zoom_out | -, keypad - | Zoom out; repeats held | project.godot:111 | Often | Z |
| toggle_art_set | F7 | New or classic art | project.godot:116 | Rare | M |
| quick_save | F9 | Save now | project.godot:122 | Occasional | M |
| quick_load | F8 | Reload last save | project.godot:128 | Rare | M |
| interact | E | Talk, open, ride, sleep | project.godot:134 | Often | I |
| build_previous | Q, Left | Previous building | project.godot:140 | When building | B |
| build_next | E, Right | Next building | project.godot:145 | When building | B |
| build_style_up | Up | Next building style | project.godot:150 | When building | B |
| build_style_down | Down | Previous style | project.godot:155 | When building | B |
| take_down_mode | X | Build or take down | project.godot:160 | Occasional | B |
| use | Space | Use held item | project.godot:166 | Constant | U |
| use_click | Left click | Use at mouse tile | project.godot:172 | Constant | U |
| hotbar_1 | 1 | Select slot 1 | project.godot:178 | Constant | H |
| hotbar_2 | 2 | Select slot 2 | project.godot:184 | Constant | H |
| hotbar_3 | 3 | Select slot 3 | project.godot:190 | Constant | H |
| hotbar_4 | 4 | Select slot 4 | project.godot:196 | Constant | H |
| hotbar_5 | 5 | Select slot 5 | project.godot:202 | Constant | H |
| hotbar_6 | 6 | Select slot 6 | project.godot:208 | Constant | H |
| hotbar_7 | 7 | Select slot 7 | project.godot:214 | Constant | H |
| hotbar_8 | 8 | Select slot 8 | project.godot:220 | Constant | H |
| inventory | B | Open or close bag | project.godot:226 | Often | P |
| character | C | Character and equipment | project.godot:232 | Occasional | P |
| skills | K | Character's skills tab | project.godot:238 | Occasional | P |
| crafting | Shift+C | Hand crafting | project.godot:244 | Often | P |
| drop_item | T | Drop held whole stack | project.godot:250 | Occasional | H |
| console | / | Open console | project.godot:256 | Debug | D |
| pause | Escape | Cancel, close, pause | project.godot:262 | Often | M |

Where these actions are read:

| Keys or actions | What happens in context | Source | Need | Touch |
|---|---|---|---|---|
| Movement | Read four movement actions | build_mode.gd:226 | Constant | J |
| Movement in build mode | Poll only non-menu physical keys | build_mode.gd:243 | Building | J |
| 1-8 | Select slot and resume hammer | main.gd:405,563 | Constant | H |
| Space, left click | Food eats; lantern toggles first | main.gd:426 | Often | U |
| Space | Use current target | main.gd:428 | Constant | U |
| Left click | Ring bell or use mouse target | main.gd:430 | Often | U |
| T | Drop selected inventory stack | main.gd:420 | Occasional | H |
| E | Get off, talk, mount, open, bell, bed | main.gd:702 | Often | I |
| E in chest | Close storage | storage_screen.gd:43 | Often | P |
| E in crafting | Close crafting | crafting_screen.gd:32 | Often | P |
| E in kiln or oven | Close process screen | process_screen.gd:49 | Often | P |
| B, C, K, Shift+C | Toggle window or tab | main.gd:680 | Often | P |
| Q/E, arrows, X | Building and style choice, mode | build_mode.gd:79 | Building | B |
| Space, left click | Place chosen building | build_mode.gd:97 | Building | B |
| Hold Space or left click | Take down after one second | build_mode.gd:258 | Rare | B |
| Escape | Console, then build cancel, then pause | main.gd:384 | Often | M |
| F2, F3 | Time speed, diagnostic HUD | main.gd:406 | Debug/rare | D |
| F7 | Change art, also with windows open | main.gd:666 | Rare | M |
| F8, F9 | Load or save with non-paused windows | main.gd:868 | Occasional | M |
| =, -, keypad +, - | Zoom key presses and echoes | camera_controller.gd:26 | Often | Z |
| / | Open console unless paused or fading | main.gd:379 | Debug | D |

E's order is significant. `main.gd:702` first dismounts. Otherwise it tries a villager, a
saddled horse, a chest or station, then a bell or a bed. A nearby bed wins over the bell and
over an untargeted chest. See `game/state/interaction.gd:29,52,78,100`. With the hammer's build
menu active, E picks a building instead. Arrows also belong to the build menu, not walking.

Use covers all the work in `game/state/tool_use.gd:26,109,147`: till, plant, harvest, forage,
clear dead crops, hit trees and stone, mow, dig, dig up bushes, water, refill, pour into troughs,
feed racks and troughs, collect eggs, open gates, place objects and take placed things down.
It also gives a dog a bone, saddles or unsaddles a horse, and pets animals. The selected item
decides which. Food and the lantern are handled before tile use in `main.gd:426`. Walking
collects ground items (`main.gd:498`) and crosses doors (`main.gd:501`); neither needs a key.
On horseback the current restrictions still apply: no tools, building, crafting or doors.

### Mouse, hard-coded keys and built-in UI behaviour

These are not extra `[input]` entries. They are easy to miss when porting only InputMap.

| Key or mouse input | What it does | Source | Need | Touch |
|---|---|---|---|---|
| Mouse motion | Aim; idle returns to facing tile | use_highlight.gd:56,65 | Constant | U |
| Mouse position | Building ghost and demolition aim | build_mode.gd:188,262 | Building | B |
| Wheel up/down, without Ctrl | Previous/next hotbar slot | hotbar_wheel.gd:8 | Constant | H |
| Ctrl+wheel | Zoom, not hotbar | camera_controller.gd:33 | Often | Z |
| Left click on build cell | Choose building or style | build_menu.gd:315 | Building | B |
| Left drag on sideways bar | Scroll buildings | scrolling_list.gd:204 | Building | B |
| Right click in build mode | Dismiss build or take down | build_mode.gd:125 | Building | B |
| Left click on bag icon | Toggle bag | hotbar_hud.gd:72 | Often | P |
| Left click on idle hotbar | Pass through to world today | hotbar_hud.gd:43 | Accidental | H |
| Left drag from slot | Move, swap, merge, equip | slot_view.gd:171,200 | Often | H |
| Shift+left click on slot | Quick-move whole stack | slot_view.gd:157 | Often | H |
| Right click on slot | Emit secondary action | slot_view.gd:166 | Often | H |
| Shift+click in bag/character | Backpack to hotbar or back | hotbar_window.gd:46 | Often | H |
| Right click in bag/character | Equip inventory item | hotbar_window.gd:50 | Occasional | H |
| Right click on worn slot | Unequip to inventory | character_screen.gd:177 | Occasional | H |
| Shift+click in chest | Transfer to other side | storage_screen.gd:140 | Often | H |
| Shift+click in station | Take output or insert input | process_screen.gd:165,212 | Often | H |
| Drag outside panel | Drop backpack or hotbar stack | modal.gd:259 | Occasional | H |
| Drag onto bin | Ask before destroying stack | trash_can.gd:63 | Rare | H |
| Any outside click or wheel | Keep stack; swallow event | trash_can.gd:94 | Rare | H |
| Hover for 0.4 seconds | Item, recipe or setting tooltip | tooltip_view.gd:66 | Often | L |
| Left/right/middle click | Hide hover tooltip | tooltip_view.gd:55 | Often | L |
| Left click on cross/backdrop | Same as closing window | modal.gd:123,248 | Often | M |
| Escape / ui_cancel | Close; safe answer; back a page | modal.gd:342 | Often | M |
| Escape in settings | Previous page, then resume | pause_menu.gd:205 | Often | M |
| Left drag on window frame | Move window; clamp to screen | modal.gd:276,289 | Occasional | P |
| Wheel, scrollbar, UI arrows | Scroll lists or focused rows | scrolling_list.gd:31 | Often | P |
| Tab, Shift+Tab | Built-in UI focus navigation | controls_page.gd:81 | Occasional | P |
| Enter, keypad Enter, Space | Activate focused UI button | choice_dialog.gd:61 | Often | P |
| Left click on button/tab | Activate, select, craft, Fade | character_screen.gd:63 | Often | P |
| Click skill's Fade button | Mark a skill to give up points | skills_panel.gd:79 | Rare | P |
| Left click on recipe | Craft one recipe | crafting_screen.gd:90 | Often | P |
| Left click on process recipe | Fill requested loads | process_recipe_row.gd:79 | Often | P |
| Click -, +, Max | Set process load count | process_recipe_row.gd:84 | Often | P |
| Click station's fire button | Start loaded process | process_screen.gd:68 | Often | P |
| Drag slider / select option | Settings, volumes, profiles | pause_menu.gd:120 | Rare | P |
| Click New, Copy, Delete | Manage model profiles | language_model_page.gd:299 | Rare | P |
| Click Refresh | Fetch provider's model list | language_model_page.gd:381 | Rare | P |
| Text and editing shortcuts | Native LineEdit editing | language_model_page.gd:175 | Rare | T |
| Enter / leave name field | Commit profile name | language_model_page.gd:312 | Rare | T |
| Enter in amount field | Commit number, release focus | process_recipe_row.gd:92 | Often | T |
| E, Escape in amount field | Commit and close station | process_recipe_row.gd:168 | Often | M |
| Enter in chat | Send line; /clear forgets memory | chat_screen.gd:117,183 | Every line | T |
| Escape in chat | Leave, not pause menu | chat_screen.gd:385 | Every chat | M |
| Page Up/Down in chat | Scroll by a page | chat_screen.gd:394 | Occasional | P |
| F7 in chat | Switch portrait art too | chat_screen.gd:389 | Rare | M |
| Enter in console | Run line; empty line closes it | console_view.gd:112 | Debug | T |
| Escape in console | Close without opening pause | console_view.gd:125 | Debug | M |
| Up/Down in console | Previous/next command | console_view.gd:130 | Debug | D |
| Page Up/Down in console | Scroll log by a page | console_view.gd:134 | Debug | D |
| Tab in console | Complete command or argument | console_view.gd:138 | Debug | D |
| Click binding; next key/button | Rebind; outside click cancels | controls_page.gd:110 | Rare | P |
| Escape during capture | Cancel rebinding | controls_page.gd:128 | Rare | P |
| Delete during capture | Clear binding | controls_page.gd:132 | Rare | P |
| Right click / focused Delete | Clear binding | controls_page.gd:140 | Rare | P |
| F6, not rebindable | Cycle hair; hard-coded keycode | player_view.gd:46,214 | Debug | D |
| Any key or mouse button | Continue pass-out message | fade_screen.gd:92 | Occasional | M |

Built-in rows describe Godot Control behaviour used here, not custom key tests in those files.
LineEdit owns caret arrows, Home/End, Backspace/Delete, selection with Shift and the platform's
copy, cut, paste, select-all and undo shortcuts (Ctrl on a desktop keyboard). Android supplies
the equivalent text selection and clipboard UI. No custom Alt or Meta gameplay shortcut was
found. Ctrl is explicitly tested only for wheel zoom; Shift for crafting and quick moves.
`game/state/game_settings.gd:207,301` permits left, right, middle and mouse buttons 4 and 5 as
bindings; the last three have no default gameplay action. They need no extra touch buttons.

There is no live map action or map panel. `game/state/game_map.gd` is world state, not a map UI.
There is no sprint, rotation, stack-split or double-click action to replace. Tab is not the bag
key. The old hotbar 9/10 and select-hammer actions are retired, not missing touch controls
(`game/state/game_settings.gd:203`). `debug_runner.gd:176` injects actions for scripted tests;
it adds no player binding. F2 and the hard-coded F6 are absent from the README's main table.

## Touch controls

The letters in the audit tables refer to these replacements. Prefer labelled buttons and an
ordinary menu to a radial menu. Rare actions need not take space on the play screen.

### J: movement

- A fixed joystick at bottom left, 112 dp across, with a 16 % dead zone. Its full travel gives
  normal walking speed. Short travel gives slower movement. Release stops immediately.
- Keep the last non-zero direction as the facing direction. The joystick also rides a horse
  and gets the player up from bed. It does not choose building styles.
- Capture its finger until release, even outside the circle. Other fingers may use buttons.
  A finger that began on the world must not acquire the joystick by sliding over it.
- Feed a movement vector to the existing walk path. Merely pressing synthetic movement actions
  is not enough: `build_mode.gd:226` ignores non-key input while its menu is up. Combine the
  joystick with desktop movement without changing the desktop arrow/menu sharing rule.

### U and I: work, targeting and interaction

Use both facing and direct touch. Do not keep an invisible mouse cursor.

- With no touched target, highlight the tile in front of the player. The right-hand **Use**
  button acts there. Its label can say Hoe, Water, Harvest, Pet, Feed or the relevant verb.
- A short tap on a world tile uses the selected tool there, on release. Keep hand-tool reach
  at one tile, diagonals included: the 3x3 area of `game/state/targeting.gd:10`. An out-of-reach
  tap shows a red frame and "Too far away"; it neither acts nor walks the player there.
- A tapped target stays highlighted for the next Use. Clear it when the player walks, changes
  map or opens a panel. Recheck reach and the action on every use. A moving animal is selected
  by identity, not by a stale tile; clear it when it leaves reach.
- Resolve touches through the camera's UI/window/world conversions, not viewport pixels alone
  (`camera_controller.gd:70`, `view_math.gd:71`). Keep safe-area offsets in the UI conversion.
- A tap on a villager in reach opens chat. A tap on a chest, station, bed or bell in reach
  offers or performs its named interaction. Sleep asks "Sleep until morning?" first on touch.
  A tap on an animal uses the held bone, saddle or empty hand where that use is valid.
- For an animal or tall object, allow a tap on its visible body to select its feet or footprint.
  Never enlarge tool reach. Where hit areas overlap, select and show named choices rather than
  silently swinging an axe or talking to somebody else. Small ground tiles stay exact targets;
  zoom or the facing button is the precise alternative to a fat finger.
- Show a second, contextual button above Use: **Talk: Antje**, **Open chest**, **Workbench**,
  **Ride**, **Get off**, **Sleep**, **Ring bell** or **Open gate**. It is absent if nothing fits.
  It stays visible as Get off while riding. The displayed name must be the entity acted on.
- The untargeted context button follows the existing E priority. Explicit touches select that
  object instead of falling back to a different nearby bed or villager. This needs an explicit
  target path alongside `main.gd:702`; do not just simulate E with an unrelated mouse position.
- If Use and interaction both make sense, keep both choices: Mount versus Unsaddle, or Open
  chest versus hitting it with an axe. Default direct taps to the safe named interaction on
  chests and villagers. Never auto-select a destructive tool. Expose alternate choices in the
  long-press sheet. Food and lantern taps in the world only target; **Eat** or **Light/Put out**
  on Use performs their targetless action. This avoids eating when trying to open a chest.
- One tap or button press performs one use, as today. No automatic repeated eating, petting,
  tool swings or planting in the first port. Repeated taps still use the state rules.
- Walking through a door and over ground items remains automatic. There is no separate pickup
  button, sprint button or tap-to-walk mode.

### B: building and taking down

- Selecting the hammer still starts building. Show a compact building strip above the hotbar.
  Swipe it sideways; tap a building. A **Style** button opens that building's styles as large
  labelled choices. These replace Q/E and all four menu arrows.
- A world tap positions the ghost; a drag moves it in tile steps. Keep a small offset preview
  above the finger so the footprint and blocked tiles remain visible. Release only positions
  it. **Build** confirms once; neither a strip swipe nor a pinch places a building.
- Start the ghost in front of the player. Keep the current centred-footprint calculation from
  `build_mode.gd:346`. Preserve the builder's land, materials and occupancy checks, rather than
  imposing hand-tool reach on buildings (`game/state/builder.gd`).
- Show **Build / Take down** and **Cancel** only while the hammer is active. Take down is a
  clearly red mode. Tap its target, read what it returns, then hold **Take down** for one second
  with a progress ring. Release, move, change target, pause or lose focus cancels the hold.
  An ordinary world long press never demolishes anything.
- Show placement errors in a fixed strip above the hotbar, not beside a missing mouse pointer
  (`build_menu.gd:116`). Keep the restrictions on occupied interiors and home beds.
- Cancel replaces right click/Escape here. Selecting another item exits. Tapping the hammer
  again resumes it, as number keys and the wheel do today. The joystick still moves the player.

### H: hotbar and moving items

- Tap any of the eight hotbar slots to select it, even with no panel open. Never forward this
  touch to the world. The desktop pass-through at `hotbar_hud.gd:43` stays desktop-only.
- Drag stacks between hotbar, backpack, chest, station grid and fitting equipment slots. Keep
  whole-stack moves, merging, swapping, rejection and station limits from `slot_view.gd:186`
  and `process_screen.gd:195`. Do not add splitting as part of this port.
- In item panels, tap selects a stack and shows an action strip: **Move stack**, **Equip** or
  **Unequip**, **Drop**, **Info** as applicable. Move stack replaces Shift+click. In a chest it
  sends across, in bag/character between backpack and hotbar, in a station into or out of the
  grid. Output still goes to the backpack first. Right click becomes Equip/Unequip; it is not
  another quick-transfer shortcut in today's chest or process screen.
- A short drag beyond 8 dp starts moving a stack; a still hold of 0.45 seconds shows its tooltip
  and actions instead. Show the dragged icon above the finger, and light the destination.
  Retain the source until a valid drop, as today. Cancellation restores it without a move.
- Inside item grids a drag from a stack moves it. Scroll from the gutter or scroll rail; also
  provide page buttons on crowded grids. Auto-scroll at a grid's edge during a stack drag.
  Never interpret one gesture as both scrolling and moving an item.
- Keep a visible **Drop on ground** drop zone in item panels, plus Drop in the selected stack's
  action strip. These replace T and dragging outside the desktop panel. Do not require dragging
  beyond the physical phone screen or into Android's navigation edge. Release elsewhere returns
  the stack; closing a panel or the keyboard must not drop it accidentally.
- Keep the bin drop target and Destroy/Keep question. A tap outside or Back answers Keep and
  consumes the event. Worn items must first come off. No long-press-to-destroy gesture.
- In play, drag between hotbar slots is allowed; it never uses a tool. A selected hotbar item's
  long-press sheet supplies Drop and Equip without needing a permanent extra HUD button.

### L: information without hover

Long press for 0.45 seconds on a slot, recipe, setting or world target. Show its existing
tooltip above the finger, clamped to the safe area. For world targets show the available verb
and reach, not hidden crop or clay data that the desktop UI does not reveal. Release leaves a
small information sheet open; tap outside closes it and consumes that tap. Info is also a
labelled action, so holding is not the only way to discover it. Disabled recipes still explain
their missing materials and skill. No action fires before the long-press timer has resolved.

Moving more than 8 dp cancels the long press. A second world finger cancels both pending tap
and long press and starts zoom. World holds inspect; only the labelled Take down button can
start the demolition timer. Mouse hover remains unchanged in desktop mode.

### P and M: panels and the menu

- Keep **Bag** beside the hotbar and **Menu** at top right always visible during play. Use is
  always present there too, but disabled when no use is possible. The joystick and eight slots
  complete the permanent controls. Everything else is contextual or inside a panel.
- Menu pauses and offers Resume, Craft, Character, Skills, Save now, Load last save, Settings
  and Save and quit. Craft opens hand crafting; at a station the context button opens its own
  recipes. Character and Skills are also tabs reachable from Bag. No radial menu in version one.
- Save now and Load use the same save services as F9/F8, not simulated keys which the paused
  tree would miss. The touch Load entry asks before discarding unsaved progress. Physical F8
  keeps today's immediate-load behaviour; a missing-content save still asks on either route.
- Art stays in Settings -> Display. Fullscreen/windowed is hidden on Android. All other
  settings remain reachable, including energy, day length, autosave, volumes and model profiles.
- Tap buttons, recipes, tabs, dropdown choices and skill Fade controls. Swipe lists, chat and
  logs vertically. Swipe the build strip horizontally. Sliders have a large thumb and step
  buttons. These replace wheel, scrollbar, arrows and keyboard focus activation on touch.
- Hardware Android Back, the Android back gesture and the visible Back/Close button share one
  path: hide keyboard first; cancel drag or information sheet; answer a question safely; leave
  the current settings page or panel; cancel building; finally open pause. Never quit at once.
  Handle `NOTIFICATION_WM_GO_BACK_REQUEST` rather than letting Android close the activity.
- A pass-out message says **Tap to continue** and requires a fresh tap after the text appears.
  It consumes the tap, as `fade_screen.gd:92` consumes the desktop key. Do not skip it with a
  finger already held on Use.
- The desktop rebind page remains available for physical devices. On touch add explicit Clear
  and Cancel buttons instead of requiring Delete, right click or Escape. Do not bind a finger
  tap, its emulated mouse event or soft-keyboard text as a physical gameplay key.

### T: the Android keyboard

Use Godot LineEdit's native virtual keyboard, not a drawn keyboard. Chat has a visible Send
button as well as the keyboard's Send/Enter action. Console has Run and Close. Profile names
have Done; amounts use the numeric keyboard and retain -, + and Max. Future naming fields use
the same path; there is no general animal or world naming screen today.

Keep chat paused while typing. Use Unicode text changes and submission, not individual
`InputEventKey` characters. Test composition, accented names, paste, selection, predictive
text and backspace. Filter movement and all gameplay hotkeys while a field is editing.
Hide the keyboard on explicit close and app suspension. Do not let the forced focus paths in
`console_view.gd:146` and `chat_screen.gd:404` immediately reopen it after Back.

Refit above the reported keyboard inset, including floating and split keyboards. Scroll the
focused field into view. Send, Close and the last chat lines must remain reachable in landscape.
When space is tight, hide the large portraits and use a small name header. A physical keyboard
on Android must still type normally, without the E that opened chat leaking into the field.

### Z: camera gestures

Pinch with two fingers that began on the unobstructed world to zoom. Use the existing 0.5-2.0
zoom range and smooth camera path (`view_math.gd:15`, `camera_rig.gd:75`). Zoom about the player,
as the desktop camera does, not a new free camera. Provide Zoom - and + under Menu -> View as
an alternative. No two-finger world pan is needed: the camera follows the player. The future
map may pan with one finger and pinch to zoom, independently of the world camera.

A joystick finger plus an action finger is not a pinch. A gesture over a panel belongs to
that panel. Once a pinch starts, neither finger's release uses a tool or places anything.

### D: debugging

Keep F2 fast forward and F6 hair cycling physical-keyboard-only. Do not reserve a touch gesture
for either. Offer Coordinates/weather/FPS as a View toggle inside the menu, off by default.
It replaces F3 without occupying the HUD permanently.

In development builds only, five taps on the version label in Settings reveal a Developer
entry with Console. Opening it uses the Android keyboard. Swipe its log; provide History up,
History down and Complete buttons for Up/Down and Tab. Page Up/Down becomes log scrolling.
No hidden gesture is active in release builds; the physical console binding may remain for
testing. `/clear` remains a typed debug command, not a prominent chat button.

## Landscape layout

All positions are inside Android's safe rectangle. dp means density-independent screen units,
not the current 640x360 Godot UI units and not world art pixels.

```text
+---------------------------------------------------------------------------+
| date / time / weather                 health / energy            [Menu]    |
| harvest and save notices                                                   |
|                                                                           |
|                        unobstructed world                                  |
|                       player + target frame                               |
|                                                  [Talk: Antje]            |
|                                                                           |
|    .-----------.                                         .------------.    |
|    | joystick  |       [1][2][3][4][5][6][7][8] [Bag]        |    Use     |    |
|    '-----------'                                         '------------'    |
+---------------------------------------------------------------------------+
  Leave the cut-out and system gesture edges outside this rectangle.
  Building: choice strip above hotbar; Style / Take down / Cancel near Use.
```

The sketch is not to scale. Budget for a safe area of 640x360 dp: eight 48 dp slots with 4 dp
gaps take 412 dp, plus a 48 dp Bag and an 8 dp gap. Put the 112 dp joystick and 64 dp Use above
the bottom hotbar row on this narrow layout, not beside it. On wider phones they can sit
beside the bar as sketched. The world remains visible between the thumbs. The context button
is at least 48 dp high and at most two short lines. Leave 8 dp between unrelated buttons.

- Minimum interactive target: **48x48 dp**, including Close, tabs, bin and slider hit areas.
  Use is 64 dp; the joystick is 112 dp. Decorative icons may be smaller, but hit areas must
  neither overlap nor extend into another control. Aim for body text at least 16 sp equivalent.
- Use an Android touch theme and layout scale. `slot_view.gd:23` is only 20 UI units today;
  merely increasing `GameSettings.ui_scale` from its 0.5-2.0 range is not a physical-size rule.
  Convert physical window pixels and Android density into canvas units, then size targets.
  At 2 px per dp a 48 dp target is 96 physical pixels. Check the result on real phones.
- Start touch scale at 100 %, with 100/125/150 % accessibility choices. These affect UI only;
  never shrink targets below 48 dp to make a panel fit. Reflow or scroll instead. Keep the
  desktop scale and the world zoom settings independent (`main.gd:856`).
- Android panels occupy the safe area above the retained hotbar. Hide the joystick and world
  action buttons, stop movement and block touches to the world. Do not drag phone windows by
  their frames. Use fixed headers, a large Close button and scrollable content.
- Bag shows its 5x4 backpack, weight, bin and action strip. A short screen scrolls the backpack
  rows rather than the header or hotbar. Keep all eight hotbar slots accessible for drag/drop.
- Character combines equipment and backpack in one touch screen, rather than two desktop
  floating windows. Keep source and destination visible for equipping by drag. Use four
  backpack columns if needed; scroll the attribute details below the gear. Skills is a tab.
  Desktop `BagScreen` and `CharacterScreen` remain separate docked windows.
- Chests show backpack and chest side by side, with independent scrolling. At 640 dp width use
  five 48 dp columns per side; at larger UI sizes use three columns per side. Never put the two
  sides behind exclusive tabs that would prevent a drag between them. Keep the hotbar below.
- Hand crafting is one full-width recipe list with a selected recipe's details and Craft.
  Kiln/oven use a Recipes tab and a Contents tab. Contents keeps the 3x3 grid, backpack and
  hotbar visible together, with Start and progress fixed above them. Recipes has Fill and the
  load count controls; choosing Fill returns to Contents. Keep station time behaviour as today;
  only chat, pause and questions necessarily pause the simulation. The proposed touch bag and
  character screen also pause; see the open question below.
- Settings uses one scrolling column and native-sized choices. No tiny desktop-wide tables
  on a phone. Keep the active field and Done above the keyboard; rebind rows are optional
  physical-device settings, not the default touch page.
- There is no map screen yet. Reserve Menu -> Map for a later map task, not an always-visible
  dead button. When built, it fills the safe area, with Back, a legend and Centre on player.
  It must not be counted as existing Android functionality or required for this port.

`project.godot:11` currently has a 640x360 logical viewport with `canvas_items` and `expand`.
Test 16:9, 20:9, 4:3 tablets, cut-outs on either side and Android multi-window resizing. Use
`DisplayServer.get_display_safe_area()` and transform its screen rectangle into window and
canvas coordinates. Recompute after resize, rotation and keyboard changes. Safe areas and
keyboard occlusion are separate insets. Allow either landscape rotation; portrait is not a
supported play layout for the first version. Retain state if Android nevertheless resizes it.

## Choosing touch or desktop

Use both a platform default and a saved setting: **Auto / Touch / Mouse and keyboard**.
In Auto, Android starts with touch; other desktop platforms start as today. Do not use
touchscreen availability alone to turn every touchscreen laptop into phone mode.

On Android, real mouse motion/clicks or a physical gameplay key may switch Auto to desktop
prompts and targeting once all fingers are up. A real screen touch switches back. Keyboard
text, IME events, mouse events emulated from touch and a connected-but-idle device do not
switch modes. Keep the current mode during typing, rebinding, a drag or a demolition hold.
Explicit Touch or Mouse and keyboard overrides automatic presentation changes. Physical
keyboard/mouse input still works in Touch, useful for a tablet with both attached.

Keep desktop InputMap bindings, saves and the original window behaviour. Store the touch
layout, touch scale and control preference separately from desktop bindings. Changing prompts
must not erase or rebind any action. Android desktop mode still obeys Android lifecycle and
safe-area rules; a keyboard does not make it a Linux process.

Use `InputEventScreenTouch` and `InputEventScreenDrag` with finger indices. One owner handles
each contact: panel, joystick, action button or world gesture. Consume UI contacts before
`main.gd:404` forwards anything to the world SubViewport. A release cannot fall through to the
world after closing a panel. Release all touch-held state on pause, focus loss, map transition,
mode switch or device cancellation. Keep the controls that must close a paused screen active
while paused, without leaving gameplay buttons active.

Do not run raw touch handling and automatic touch-to-mouse gameplay handling together. Plan
to disable `input_devices/pointing/emulate_mouse_from_touch` for the Android touch route and
adapt the affected Controls explicitly. Reuse slot move rules, not simulated mouse coordinates
as the source of truth. Leave desktop mouse and keyboard paths unchanged; desktop emulated
touch can be a development option, never the release default.

## Android technical work

### Renderer and shaders

The project has no explicit renderer override in `project.godot:19`; desktop uses Forward+
by default. Do not carry that assumption into an Android export. Start with **Mobile** on a
Vulkan-capable reference phone. Compare **Compatibility** (OpenGL ES 3) on a lower-end phone
before deciding the supported range. Use an Android-specific renderer setting; do not change
desktop rendering. Compatibility is an alternative build/profile until its shaders and images
pass, not a promise that every Vulkan failure can silently fall back correctly.

All current custom shaders and includes are under `game/scenes/`. Check all of these:

| Files in game/scenes/ | Checks on Mobile and Compatibility |
|---|---|
| hash.gdshaderinc | uint overflow, shifts, floatBitsToUint, negative zero, large coordinates |
| cloud_shadows.gdshader | Warped multi-octave noise, precision, full-screen fragment cost |
| ground.gdshader | Ground atlas sampling, season colour and seams |
| ground_look.gdshaderinc | Four seasonal samplers, mixing, colour space |
| ground_cover.gdshaderinc | Global samplers, texelFetch, ring wrap, frost and snow thresholds |
| object_cover.gdshader | Atlas origin, object snow and frost |
| object_cover.gdshaderinc | Global snow/frost samplers, mask alignment |
| soil_wet.gdshader | Moisture overlay under cover, alpha and joins |
| object_sway.gdshader | Atlas-cell sampling, wind displacement, cover after sway |
| decoration_sway.gdshader | Grass and flower motion, seasonal cover and batching |
| sway.gdshaderinc | Wind phase, precision, stable motion at world edges |
| art_scale.gdshaderinc | New/classic pixel sizes and atlas coordinates |
| water.gdshader | Ripples, glints, world-space coordinates |
| water_surface.gdshaderinc | Shared water sampling and drift |
| mud.gdshader | Integer noise, tide blending, shallow-water edges |
| lily_pad.gdshader | Drift, bobbing, atlas boundaries |
| fire.gdshader | Integer hash, texelFetch flame atlas, sparks and transparency |
| weather_fog.gdshader | Full-screen overdraw, tint, camera-relative sampling |
| weather_precipitation.gdshader | Rain/snow/wind layers, hash precision, fragment cost |
| rain_splashes.gdshader | Hash, chance threshold, instancing and overdraw |
| see_through.gdshader | Occlusion circle, roof snow sampler, transparency and lights |
| sharp_bilinear.gdshader | Final world upscale, UV edges, fractional scale |
| sharp_pixels.gdshader | fwidth derivatives, UI icons at fractional scales |

There is no separately named season or snow shader: seasonal blending is in ground_look,
ground_cover and object_cover, and falling snow is in weather_precipitation. The PCG hash at
`hash.gdshaderinc:8` deliberately replaced driver-dependent sine noise. Do not replace it with
a cheap sine hash to make a compile error disappear. Check real Adreno and Mali hardware,
not only an emulator. Compare negative and far-world coordinates, both art sets, all seasons,
thin snow, thaw, night lights, interiors, cloud shadows and the see-through roof.

Retain the two-stage world rendering initially: `ViewMath.VIEWPORT_SIZE` is 1288x728, not
640x360 (`view_math.gd:19`). A high-resolution phone still pays for the final upscale and UI,
while all those world pixels and weather passes are rendered offscreen. Check SubViewport
textures, CanvasItem lights, alpha blending, texture-unit limits and texture imports. Export
Android texture variants (ETC2; ASTC if justified), not just the desktop S3TC/BPTC variants.
Pixel-art atlases need visual checks after compression. Prefer uncompressed lossless imports
for small art where block artefacts spoil the palette.

### Export and signing

`export_presets.cfg` only contains Linux and Windows today. A later task adds an Android
preset with the matching 4.7.2 export templates and the SDK/JDK versions required by that
Godot release. Do not upgrade the engine as an accidental part of the port.

- Choose a permanent reverse-domain package id, version name and increasing version code.
  Start with arm64-v8a for devices; x86_64 is an optional emulator/debug export.
- Use landscape orientation, correct adaptive icons and Android internet permission for model
  calls. No broad storage permission, microphone or location permission is needed.
- Copy the existing runtime include filter: `data/*.cfg`, `maps/interiors/*.tmx`,
  `maps/interiors/*.tsx`, `assets/music/*.mod` and `assets/music/*.cfg`. Keep tests, addons and
  build tools out. Verify these raw files are actually readable inside the packed app.
- Build assets and import them on the build machine. Python art and sound generation and
  `make llm-up` are development tools, not things to ship or run on the phone.
- Debug APKs use a debug keystore. Release APKs use a private release key; a store release uses
  a signed AAB and the store's signing arrangement. Keep keys and passwords outside the repo
  and exported resources, supplied through local configuration or CI secrets. Back up the key.
  Test an update installed over a signed earlier version without losing `user://`.
- Decide sideload versus Play before release. Check the store's then-current target SDK and
  policy requirements rather than pinning a guessed level here. A custom Gradle build is only
  needed if the chosen signing, manifest, secure-key storage or platform integration needs it.

### Performance, memory and battery

Threads prevent some stalls; they do not make work free on a phone. Measure CPU time, GPU
time, peak resident memory, storage and temperature in a signed device build.

- `game/audio/module_renderer.gd:129,179` renders tracker music in GDScript on worker threads.
  It builds a whole float mix, renders a looping section twice, then creates PCM. Stereo at
  44.1 kHz and overlapping old/new renders can consume substantial CPU and peak memory.
  `game/audio/music_player.gd:89` can leave superseded renders running; its exit path waits for
  them (`:110`). First cap concurrent Android renders at one, then measure cold-cache startup,
  crossfades and app switching. If too costly, pre-render the existing pieces for Android at
  build time or offer lower-rate renders; do not rewrite the music system before measuring.
- Keep `user://music_cache` separate from saves. `data/music.cfg` bounds it at 64 MB today;
  this is a disk bound, not a RAM bound. A full cache should not compete with a save for space.
  A missing cache is recoverable; do not treat it as progress or include it in save backups.
- `game/world/chunk_residency.gd:64` generates a whole chunk synchronously. Loading one per
  frame does not bound that frame's cost. Its load/unload radii are 3/5 (`:13`), giving a 7x7
  desired set and a larger retained fringe. Test new-game camp search, horse travel and loads
  with many edits. Profile `game/world/world_generator.gd` and `field_layout.gd` separately.
- If chunk generation misses the budget, stage it over frames or use a worker-owned generator
  and immutable results. Commit state and TileMapLayer changes on the main thread. Never
  share mutable noise, world dictionaries or scene nodes across workers. Keep deterministic
  generation and do not reduce residency below what the widest camera and horse speed need.
- `world_view.gd:35,44,47` budgets refresh/draw/urgent draw at 3/8/16 ms. Those are already most
  of a 60 fps frame before generation, UI and GPU work. Tune Android budgets from device data.
  Also measure `game/state/simulation.gd`'s sleep catch-up and the main-thread save snapshot
  (`game/state/save_service.gd:40`) on a large farm, not just an empty camp.
- Atlas variants for seasons and both art sets, many animal sprites, lights, foliage and cover
  textures compete for memory and bandwidth. Full-screen fog, cloud and precipitation passes
  cost battery even while the player stands still. Offer a measured low-effects profile:
  reduce visual particle density, cloud shadow cost and light count, not crops or weather rules.
- Default Android to 30 fps with a 60 fps option. Retain desktop's existing 60 fps default and
  frame-rate setting (`game/state/game_settings.gd:94`). Measure sustained play for 20 minutes,
  not just cold-device FPS. No uncapped default on a 120 Hz phone. Keep simulation delta-based.
- Pause rendering work, music generation, model background jobs and simulation while suspended.
  Ordinary SceneTree pause does not stop WorkerThreadPool jobs. Add cooperative stopping or
  deferral where needed; do not block the pause callback waiting for a long music render.
  Do not keep the screen awake in the background or acquire a wake lock. Let Android manage
  brightness. Optional haptics are off until tested for comfort and cost.

### Saves and suspension

`user://saves/world.json` and `user://settings.cfg` remain the paths
(`game/state/save_file.gd:27`, `game/state/game_settings.gd:41`). On Android they are in the
app's private writable storage, not beside the APK and not in Downloads. `res://` is read-only.
No filesystem permission is needed for normal saves. Updates with the same package preserve
them; clearing app data or uninstalling can remove them. Desktop and Android share the JSON
format, subject to the existing version window and content validation, not automatic sync.

Keep the existing checked temporary-write, flush and rename in `save_file.gd:61`, and the
previous good save on failure. Test low storage and process death during the write. A worker
callback may never run after Android kills the app; do not advertise a save as finished before
the write really completed. A later save import/export task can use Android's system document
picker and share sheet; never require access to an app-private path from a file manager.

`main.gd:365` currently saves on window close only. `audio_service.gd:143` handles focus for
sound, not world suspension. Android cannot rely on Save and quit, `_exit_tree` or a final
close notification: an app in the background can be killed without any of them.

- Handle `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_APPLICATION_FOCUS_OUT` idempotently.
  Stop player input and time, cancel drag/hold state, hide the keyboard and silence all audio,
  regardless of the desktop Sound in background preference. Suspend worker producers and new
  HTTP jobs too. A notification shade or system dialog must not leave the joystick held.
- Request a save of the latest stable state on suspension, even if a bag or chat was open.
  A normal background save request can be skipped while another runs (`save_service.gd:35`);
  record a pending latest snapshot and serialise it after that writer, not two concurrent
  writes to `world.json.tmp`. Keep a bounded pause-time flush path; do not await a UI frame
  after the OS has stopped supplying frames. This is best effort, not a guarantee against kill.
- A sleep or collapse catch-up must not be saved half-complete. Keep a recent stable checkpoint;
  if suspended mid-transition, preserve that checkpoint and finish the transition on resume
  before saving its result. Do not force an unbounded catch-up inside the pause notification.
- Add an Android-only rolling checkpoint every two minutes of active play, plus the existing
  sleep and manual saves. This limits loss if suspension gives no time to write. Coalesce save
  requests, measure snapshot cost and never shorten the desktop autosave interval silently.
- On `NOTIFICATION_APPLICATION_RESUMED` and focus return, show Resume over the retained game.
  Do not advance by wall-clock time spent away or replay held touches. Keep prior pause reasons
  such as a chat, settings or a question; closing one must not unpause a still-suspended app.
  Recompute safe area, keyboard inset, audio and input state before accepting a fresh contact.
- If the process died, start through the normal validated save loader. Report a failed
  suspension save on return where possible; Retry and Keep playing remain safe options.

### Language models and network

Hosted OpenAI-compatible, Claude and Gemini calls can use the existing `HTTPRequest` clients
(`model_chat.gd:140`, `open_ai_chat.gd`, `claude_chat.gd`). Android needs internet permission
and working TLS certificates, not browser CORS workarounds. Keep HTTPS certificate checks and
the no-redirect rule. Never embed a shared paid provider key in the APK.

The default `http://127.0.0.1:11434/v1` in `game/state/game_settings.gd:111` points at the
phone itself, not the developer's Ollama container. Local Ollama inference is out of scope.
Default Android to scripted dialogue with an empty endpoint; let the player opt into a hosted
profile with their own key. A LAN Ollama server is an advanced optional setup using the PC's
reachable address. It is not the phone's loopback. Plain HTTP may need an explicit Android
cleartext policy; do not enable unrestricted cleartext just to make the default URL work.

Preserve today's distinction in `npc_dialogue.gd:108`: no configured model gives scripted
lines; failure of a user-configured hosted model gives a notice and no invented reply.
Airplane mode must not freeze movement or trap the chat screen. Explain possible data charges,
provider costs and that villagers' context and the player's words leave the device.

`ModelChat` and dialogue use `PROCESS_MODE_ALWAYS`, so pausing the world for chat is not the
same as backgrounding Android. Cancel or suspend requests when the app is suspended; clear
waiting flags without adding a false reply. Keep unsent chat drafts in retained UI state.
On return, allow an explicit resend, not an automatic second paid request. A reply from a
cancelled or replaced session must not update a reloaded world. Stop ambient bubble/judge
requests in the background too, and avoid retry storms when switching Wi-Fi to mobile data.

Keys are currently plain text in `settings.cfg` (`game/state/game_settings.gd:16`). For an
initial private build, disclose this and exclude keys from logs, save sharing and Android
backup. A public release should store provider secrets through Android Keystore-backed
storage, or leave remembering keys off; this is a separate platform integration task, not
security gained merely by masking the text field. Save backup rules must exclude settings
secrets and the regenerable music cache. Decide whether world saves may use Android backup.

## Proposed tasks

Each item is one bounded task for one developer. Dependencies refer to these numbers, not
existing entries in `TASKS.md`. They are proposals only; this page changes no task tracker.

1. **Device and renderer spike.** Add a debug Android export with correct runtime filters and
   package identity. Compare Mobile and Compatibility on the reference phones with all shader
   scenes above. Record compilation, visual faults, cold start, memory and sustained frame time.
   Dependency: none. Output: renderer choice and a concrete device floor, not a full port.
2. **Control preference and routing.** Add Auto/Touch/Desktop state, contact ownership and
   duplicate-event suppression. Preserve desktop InputMap and add tests for mode switching and
   text-field exclusion. Dependency: 1.
3. **Safe-area touch shell.** Add the density-aware theme, landscape anchors, scaling and
   48 dp targets. Test narrow, wide and tablet sizes with a non-interactive HUD mock-up.
   Dependency: 2.
4. **Joystick.** Connect indexed touch movement to walking and riding, including build mode.
   Test diagonals, release outside, focus cancellation and keyboard coexistence. Dependencies:
   2, 3.
5. **Tile targeting and Use.** Add explicit touch targets, facing fallback, tool button and
   long-press information. Cover reach, camera transforms, food, lantern, pinch cancellation
   and UI fall-through. Dependencies: 2, 3, 4.
6. **Context interactions.** Add named entity buttons and explicit-target dispatch for talk,
   chests, stations, beds, bells, gates, animals and riding. Verify overlap priority and every
   horseback restriction. Dependency: 5.
7. **Hotbar and stack gestures.** Add selection, indexed drag/drop, offset previews, transfer
   actions, drop zone and safe bin handling. Reuse state move rules; retain desktop tests.
   Dependencies: 2, 3. Can proceed independently of 5 and 6 once those dependencies are done.
8. **Bag and character touch layouts.** Fit backpack and equipment together, add tabs and
   scrolling, and apply the agreed panel pause rule. Dependencies: 3, 7.
9. **Storage and process layouts.** Reflow chest sides and station Contents/Recipes. Cover
   quick transfer, locked inputs, output, amounts and edge scrolling. Dependencies: 6, 7, 8.
10. **Menu, crafting and Back.** Add touch access to all remaining actions, large recipe rows,
    save/load entries, settings navigation, rebinding Clear/Cancel and pass-out continuation.
    Test safe answers and no click-through while paused. Dependencies: 3, 6, 8.
11. **Building touch mode.** Add choice/style strip, ghost positioning, Build/Cancel and held
    demolition. Move refusal notes off the mouse and test no construction from swipes.
    Dependencies: 4, 5, 10.
12. **Camera gestures.** Add pinch and menu zoom controls, excluding joystick/UI contacts and
    cutscenes. Keep follow camera and zoom limits. Dependencies: 2, 5.
13. **IME and debug console.** Fit chat, amounts and model/profile fields above the keyboard;
    add Send/Run/Done and the development-only console entry. Test composition and Back without
    focus loops on two Android keyboards and a physical keyboard. Dependencies: 6, 9, 10.
14. **Lifecycle and save queue.** Add suspension pause reasons, coalesced stable saves, Android
    checkpoints, audio suspension and explicit Resume. Test Home, shade, screen lock, calls,
    process death and low disk, including a save or sleep already running. Dependencies: 2, 10.
15. **Model network lifecycle.** Add Android defaults, permission/TLS checks, request cancellation
    and stale-answer guards. Test offline and Wi-Fi/mobile transitions without duplicate sends.
    Dependencies: 13, 14. Secure remembered keys before public distribution.
16. **Music worker budget.** Limit concurrent renders and suspend them cooperatively. Measure
    cache misses, peak memory and quit latency; decide pre-rendered audio only from the results.
    Dependencies: 1, 14.
17. **Chunk generation budget.** Profile generation separately from drawing; fix one measured
    bottleneck with staged work or worker results. Preserve seed determinism and residency.
    Dependencies: 1, 4, 14.
18. **Graphics and battery profile.** Address shader faults from 1, tune draw budgets, effect
    quality and 30/60 fps. Repeat the sustained reference-device route in winter and storms.
    Dependencies: 11, 12, 16, 17.
19. **Release packaging and acceptance.** Set final SDK policy, permissions, backup exclusions,
    icons and release signing. Test clean install and signed update, saves, hosted chat, every
    audit-table action and an Android tablet with mouse/keyboard. Run desktop regression tests
    for controls, drags, docked windows, building and saves. Dependencies: 8-18.

The map, general naming screens, gamepads, cloud sync and a store backend are separate future
work. None is a hidden dependency of the Android control port. Existing tests worth extending
include `tests/test_build_keys.gd`, `tests/test_inventory_drag.gd`, `tests/test_docked_play.gd`,
`tests/test_chat.gd`, `tests/test_taking_down.gd` and the save tests. Add raw multi-touch tests,
not only mouse emulation. Device acceptance must cover simultaneous joystick/action use,
cancelled contacts and a resumed app that never keeps walking by itself.

## Open questions

The four user decisions at the top are settled. These are the remaining choices, each with a
recommended starting point:

- **Device floor and renderer?** Default: an arm64 Vulkan phone using Mobile, with one Adreno
  and one Mali reference device. Set exact Android/RAM requirements after task 1. Add
  Compatibility support only if its measured coverage is worth maintaining another profile.
- **How should direct taps act?** Default: one tap uses the selected tool on bare tiles; a
  named safe interaction wins on villagers and containers. Keep facing Use as an equal option.
  No tap-to-walk, auto-tool selection or repeat-on-hold in the first version.
- **Do touch item screens pause?** Default: pause Bag and Character on Android, since they
  cover the movement controls. Keep chest and station simulation as today, with no world input.
  Desktop docked windows remain live. Confirm before task 8.
- **Phone size and handedness?** Default: landscape with at least 640x360 dp of usable area,
  48 dp targets, fixed left joystick and right actions. Offer a mirrored thumb layout after
  the first device test; never solve a cramped screen by shrinking touch targets.
- **Frame rate and effects?** Default: 30 fps and a restrained effects profile, with 60 fps
  selectable. Do not promise 60 fps on the lowest supported device before sustained tests.
- **Android save interval and load confirmation?** Default: two-minute rolling checkpoints
  and a confirmation for the touch Load menu only. Physical desktop-style F8 stays immediate.
- **Dialogue setup?** Default: scripted/offline until a player chooses a hosted provider and
  supplies a key. No bundled inference, compulsory account or company-paid key in the app.
- **Keys and backups for the first release?** Default: private sideload builds may disclose
  local plain-text keys; public builds do not remember them until secure storage is ready.
  Exclude secrets and music cache from backup; allow world-save backup, with no sync promise.
- **Distribution, package id and minimum SDK?** Default: private signed APK first, permanent
  package id chosen by the user, arm64 only. Pick a Play AAB and store SDK policy later, after
  the device floor is known. Keep the release signing key from the first distributable build.
- **Debug access and map?** Default: hidden console entry only in development builds, F2/F6
  keyboard-only, diagnostics in Menu -> View. No new map implementation in the Android scope.
