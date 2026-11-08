// The shaders of the world's art work on the pixels of the art: those of the 16 px art, which
// tools/art doubles until its group is drawn at 32 px (and the classic art, see ArtSet), are
// `art_scale` texture and world pixels each. AmbientMotion, which makes the materials, sets it to
// TerrainTileset.ART_16_SCALE for those; at 1 a texture pixel is an art pixel. The fire, the
// rain's splashes and the weather are drawn at 32 px and do without it.
uniform float art_scale = 1.0;
// A tile in world pixels (TerrainTileset.TILE_SIZE); GAME_TILE / art_scale in art pixels.
const float GAME_TILE = 32.0;
