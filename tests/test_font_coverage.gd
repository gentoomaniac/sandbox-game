extends GutTest
## The pixel font has a glyph for every letter villagers answer with in German, Danish,
## Norwegian, Swedish, Dutch, Frisian and the neighbours' languages, and for the punctuation
## and symbols language models like to write.

const FONT := preload("res://assets/ui/font.fnt")

const LATIN_1_LETTERS_FIRST := 0xC0
const LATIN_1_LETTERS_LAST := 0xFF
const EXTENDED_LETTERS := "ĀāĂăĄąĆćČčĐđĒēĖėĘęĚěĞğıİĪīŁłŃńŇňŌōŐőŒœŘřŚśŞşŠšŪūŮůŰűŹźŻżŽž"
const PUNCTUATION := "¡¿«»‹›°·±•‘’“”„‚–—…\u00a0"
const SYMBOLS := "€£©§µ²³"


func test_every_latin_1_letter_has_a_glyph() -> void:
	var letters := ""
	for code in range(LATIN_1_LETTERS_FIRST, LATIN_1_LETTERS_LAST + 1):
		letters += char(code)
	assert_eq(_without_glyph(letters), "")


func test_the_extended_letters_have_glyphs() -> void:
	assert_eq(_without_glyph(EXTENDED_LETTERS), "")


func test_the_punctuation_and_symbols_have_glyphs() -> void:
	assert_eq(_without_glyph(PUNCTUATION + SYMBOLS), "")


func _without_glyph(characters: String) -> String:
	var missing := ""
	for character in characters:
		if not FONT.has_char(character.unicode_at(0)):
			missing += character
	return missing
