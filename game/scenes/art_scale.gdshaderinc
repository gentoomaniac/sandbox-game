// The shaders of the world's art work on the pixels of the art: those of the 16 px art, which
// tools/art doubles until its group is drawn at 32 px, are `art_scale` texture and world pixels
// each. Whoever makes the material (AmbientMotion, WeatherView) sets it to
// TerrainTileset.ART_16_SCALE; at 1 a texture pixel is an art pixel.
uniform float art_scale = 1.0;
