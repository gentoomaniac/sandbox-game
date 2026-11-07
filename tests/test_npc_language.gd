extends GutTest
## Which language the player speaks, as the prompt names it (NpcLanguage, [language] of
## data/npc_talk.cfg): English, German and Danish by common words and by letters only one has,
## and for a line too short to tell the language of an earlier one.

var _rules := NpcTalkRules.default_rules()


func _line(from_player: bool, text: String) -> Dictionary:
	return {"day": 12, "minute": 495, "from_player": from_player, "text": text}


func test_each_language_is_told_by_its_words() -> void:
	var cases := {
		"Good morning! Is the dyke holding after the storm?": "en",
		"What do you make of this weather?": "en",
		"Guten Tag! Wie geht es dir heute?": "de",
		"Hast du meinen Hund gesehen?": "de",
		"Goddag! Hvordan går det med fiskeriet?": "da",
		"Har du set min hund, og hvad skal jeg gøre?": "da",
	}
	for text: String in cases:
		assert_eq(NpcLanguage.detect(text, _rules), cases[text], text)


func test_a_letter_only_one_language_has_tells_it() -> void:
	assert_eq(NpcLanguage.detect("Grüße!", _rules), "de")
	assert_eq(NpcLanguage.detect("Schön", _rules), "", "ö alone: Swedish has it too")
	assert_eq(NpcLanguage.detect("Blåbær", _rules), "da")
	assert_eq(NpcLanguage.detect("Rødgrød", _rules), "da")


func test_swedish_is_not_taken_for_danish_or_german() -> void:
	var text := "Tjena! Hur går det idag för dig?"
	assert_eq(NpcLanguage.detect(text, _rules), "other")
	assert_eq(NpcLanguage.detect("Jag mår bra, tack. Och du?", _rules), "other")
	assert_eq(NpcLanguage.detect("På", _rules), "", "å tells no language")


func test_words_of_danish_and_swedish_alike_decide_neither() -> void:
	assert_eq(NpcLanguage.detect("Det går godt, kan du se det?", _rules), "da")
	assert_eq(NpcLanguage.detect("Tjena! Hur går det idag för dig? Og?", _rules), "other")


func test_a_line_of_an_unknown_language_does_not_take_that_of_the_chat() -> void:
	var history: Array[Dictionary] = [_line(true, "Guten Morgen! Wie geht es dir?")]
	assert_eq(NpcLanguage.name_of("Tjena! Hur går det idag för dig?", history, _rules), "")


func test_a_line_too_short_or_unclear_is_not_told() -> void:
	for text in ["", "Hi", "Moin", "Hej!", "ok", "Hinrich", "Hello", "12345", "Du?"]:
		assert_eq(NpcLanguage.detect(text, _rules), "", text)


func test_a_tie_between_languages_is_not_told() -> void:
	assert_eq(NpcLanguage.detect("the and und ist", _rules), "")
	assert_eq(NpcLanguage.detect("Schön, blæ", _rules), "")


func test_a_short_line_has_the_language_of_the_latest_earlier_line_that_can_be_told() -> void:
	var history: Array[Dictionary] = [
		_line(true, "Guten Morgen! Wie geht es dir?"),
		_line(false, "Moin, gut, und dir?"),
		_line(true, "Ok"),
	]
	assert_eq(NpcLanguage.name_of("Moin", history, _rules), "German")
	history.append(_line(true, "Good day to you! Is that your cow over there?"))
	assert_eq(NpcLanguage.name_of("Hej", history, _rules), "English")


func test_a_line_that_can_be_told_ignores_the_history() -> void:
	var history: Array[Dictionary] = [_line(true, "Guten Morgen! Wie geht es dir?")]
	assert_eq(NpcLanguage.name_of("Good morning! How are you?", history, _rules), "English")


func test_the_villagers_own_lines_do_not_count() -> void:
	var history: Array[Dictionary] = [
		_line(true, "Good morning! How are you today?"),
		_line(false, "Moin, Nachbar. Schönes Wetter heute, nicht wahr?"),
	]
	assert_eq(NpcLanguage.name_of("Hi", history, _rules), "English")


func test_a_language_of_the_names_needs_a_list_of_words() -> void:
	var values := DataFile.read_sections(NpcTalkRules.DEFAULT_PATH)
	values["language"]["names"]["sv"] = "Swedish"
	assert_has(NpcTalkRules.new(values).problems(), "[language] words has no list for sv")


func test_with_nothing_to_go_by_the_language_is_not_known() -> void:
	assert_eq(NpcLanguage.name_of("Moin", [] as Array[Dictionary], _rules), "")
	var history: Array[Dictionary] = [_line(true, "Hi"), _line(false, "Aye.")]
	assert_eq(NpcLanguage.name_of("Hej", history, _rules), "")


func test_a_swedish_line_with_an_o_umlaut_is_not_taken_for_german() -> void:
	assert_eq(NpcLanguage.detect("Tjena! Vem ör du då?", _rules), "other")
	assert_eq(
		NpcLanguage.detect("Wie hören Sie mich?", _rules), "de", "German words outweigh the ö"
	)
