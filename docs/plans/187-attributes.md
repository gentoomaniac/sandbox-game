# Task 187 plan (approved by the user 2026-11-12)

User decisions:
- Strength: soft limit only (option A). Strength sets the carry capacity in kg = the "free weight" above which tool use costs more energy (the existing EnergyRules weight surcharge). Pickup is never refused. No hard limit.
- Display: levels AND derived numbers (Max energy, Max health, Carry capacity) in the character window; the bag label becomes "Carrying x / y kg".
- Scale numbers (base 10, +10 energy per Stamina, +10 health per HP, +4 kg per Strength) are the worker's pick, in data/attributes.cfg; the user tunes later. At base the game must be exactly as today (energy 100, health 100, 40 kg).

Existing code (from the planner):
- PlayerState.MAX_ENERGY / MAX_HEALTH = 100.0, used in player_state.gd, game_state.gd:208 (energy_cap), pass_out_message.gd:19, vitals_hud.gd:62/64 and ~8 tests.
- Inventory.total_weight(), PlayerState.carried_weight() -> bag label and ToolUse; EnergyRules.weight_factor(kg) with [weight] free_kg=40, step_kg=10, +10% per step in data/energy.cfg.
- Save VERSION 29, upgrade steps 19..28, rules in the save_file.gd header (strict to_dict/from_dict, bump, _upgrade_from_version_<old>, test, SaveValidator check, drop oldest step in its own commit).
- Model to copy: data/skills.cfg + SkillRules (DataFile.read_sections) + Skills (player.skills, saved, `skill` console command), CharacterScreen tabs, SkillsPanel.

Design:
- data/attributes.cfg: [strength] [agility] [stamina] [hp] with name, description, base; [effects] energy_per_stamina, health_per_hp, free_kg_per_strength.
- AttributeRules (game/state/attribute_rules.gd, problems() like other *Rules) and Attributes (game/state/attributes.gd, player.attributes): levels saved; value(id) = level + transient bonuses (add_bonus(source,id,amount)/remove_bonus(source), not saved); derived max_energy(), max_health(), carry_capacity(). changed signal. Built so NPCs/animals can own Attributes later.
- MAX_ENERGY/MAX_HEALTH replaced by the derived stats everywhere; a lowered max clamps current values.
- EnergyRules.weight_factor takes the capacity; free_kg leaves energy.cfg (step_kg and extra stay).
- Agility: stored, saved, shown, console-settable; no effect ("no effect yet").
- AttributesPanel in the Character tab of CharacterScreen: four rows (bonus shown as "12 (+2)"), tooltips, plus derived numbers.
- Save: VERSION 30, attributes in player to_dict/from_dict, _upgrade_from_version_29 sets base levels, SaveValidator check, upgrade test; separate commit "Save: drop the upgrade from version 19".
- Console: `attribute <name> <level>` with completion, prints the value and derived stat.

Commits (atomic, each green on its own):
1. attributes.cfg + AttributeRules + Attributes + unit tests (not wired).
2. PlayerState owns attributes; MAX_ENERGY/MAX_HEALTH replaced; tests migrated.
3. Strength sets the carry capacity in EnergyRules/ToolUse; bag label "x / y kg".
4. Save v30 + upgrade + validator + tests.
5. Console `attribute`.
6. AttributesPanel in the character window.
7. README + design/player/ notes (energy-and-sleep.md, inventory-and-character.md) — or fold doc lines into the commits they describe.
8. Save: drop the upgrade from version 19.
