#!/bin/sh
# Fails if a file git would commit (tracked, or new and not ignored) holds what looks like a real
# API key: Anthropic's (sk-ant-...), Google's (AIza...) or OpenAI's (sk-..., and sk-proj-... or
# sk-svcacct-... with _ and - in them). Keys belong in the game's settings.cfg in the user data
# folder, which is outside the repository. Tests use short fakes such as "sk-ant-test", which are
# too short to match.
set -eu
pattern='sk-ant-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|sk-(proj|svcacct)-[A-Za-z0-9_-]{32,}|sk-[A-Za-z0-9]{32,}'
if git grep --untracked -nIE "$pattern" -- . ':!*.png' ':!*.wav' ':!*.ogg'; then
	echo "check_secrets: the lines above look like API keys; keep keys out of the repository." >&2
	exit 1
fi
