class_name NpcLanguage
extends RefCounted
## Which language the player speaks (English, German or Danish), for NpcPrompt to name it to the
## model: a model that is only asked for "the language of the neighbour's line" follows a switch
## of language about three times in five. The words are those of [language] in
## data/npc_talk.cfg: each common word of a language in the line scores one for it, each letter
## only it has (such as ä or æ) scores `letter_score`.


## The name of the language of the player's `message`, such as "German": if it can't be told
## (too short, or two languages tie), that of the player's latest line in `history` (as Npc
## `chat_history`) that can; "" if there is none, or if it is one the game does not know.
static func name_of(message: String, history: Array[Dictionary], rules: NpcTalkRules) -> String:
	var code := detect(message, rules)
	var i := history.size() - 1
	while code == "" and i >= 0:
		if history[i]["from_player"]:
			code = detect(history[i]["text"], rules)
		i -= 1
	return rules.value("language", "names").get(code, "")


## The code ("en", "de", "da", or "other" for a language the game does not know) of the language
## of `text`, or "" if no language has a score of `min_score` and more than every other.
static func detect(text: String, rules: NpcTalkRules) -> String:
	var lower := text.to_lower()
	var words := RegEx.create_from_string("[a-zäöüßæøå]+").search_all(lower)
	var heard: Array[String] = []
	for found in words:
		heard.append(found.get_string())
	var word_lists: Dictionary = rules.value("language", "words")
	var letters: Dictionary = rules.value("language", "letters")
	var best := ""
	var best_score := 0
	var runner_up_score := 0
	for code: String in word_lists:
		var score := 0
		for word in heard:
			if word in word_lists[code]:
				score += 1
		for letter in letters.get(code, ""):
			score += lower.count(letter) * int(rules.value("language", "letter_score"))
		if score > best_score:
			runner_up_score = best_score
			best = code
			best_score = score
		elif score > runner_up_score:
			runner_up_score = score
	if best_score < int(rules.value("language", "min_score")) or best_score == runner_up_score:
		return ""
	return best
