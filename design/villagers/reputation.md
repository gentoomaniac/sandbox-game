# Reputation

- Building too close to NPCs costs reputation with them.
- Reputation changes spread through relationships, **one hop only**:
  - the affected NPC loses reputation with the player;
  - the NPC's direct friends also lose reputation;
  - the NPC's direct enemies gain reputation;
  - the change stops there. This keeps it predictable and explainable to the player.
- **"Too close" means inside a settlement's territory.** The world generator marks
  territory, and building inside it affects that settlement's NPCs. This is a first
  version, to be refined if it feels odd in play. **Built for Wehlsbüll (#9):** the territory is the
  record `World.village` (`World.is_village_land`, not the generator), and a deed done on it weighs
  more (`[village_land]` of `data/gossip.cfg`: [gossip.md](gossip.md)). The one-hop spread through
  friends and enemies is not built.
- What one villager thinks of the player is **friendship**, in ten levels, and has its own page:
  [relationships.md](relationships.md) (decided 2026-11-15). A bad name closes shops and services
  there; when reputation is built, a settlement's name and its villagers' levels meet by the
  lower of the two.
- Relationships can be between individual NPCs and between groups.
- Ideas for NPCs, their behaviour and LLM dialogue (nothing decided):
  [ideas.md](ideas.md).
