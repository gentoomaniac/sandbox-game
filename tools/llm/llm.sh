#!/bin/sh
# A local LLM for testing NPC talk: Ollama in a container, OpenAI-compatible API on
# http://127.0.0.1:11434/v1. See tools/README.md. Usage: llm.sh up | down [--purge] | check | status | logs
set -eu

# Pinned, so the test setup does not change under us.
IMAGE=docker.io/ollama/ollama:0.35.0
NAME=sandbox-game-llm
VOLUME=sandbox-game-llm-models
PORT=11434
URL=http://127.0.0.1:$PORT
MODEL=${LLM_MODEL:-qwen2.5:3b-instruct}

if [ -z "${CONTAINER:-}" ]; then
	if command -v podman >/dev/null 2>&1; then CONTAINER=podman; else CONTAINER=docker; fi
fi

is_running() {
	[ "$("$CONTAINER" inspect --format '{{.State.Running}}' "$NAME" 2>/dev/null)" = true ]
}

wait_for_api() {
	echo "Waiting for the API on $URL"
	tries=0
	while [ "$tries" -lt 60 ]; do
		curl -fs "$URL/api/version" >/dev/null 2>&1 && return 0
		if ! is_running; then
			echo "llm.sh: $NAME stopped (port $PORT taken? try: llm.sh logs)" >&2
			return 1
		fi
		tries=$((tries + 1))
		sleep 1
	done
	echo "llm.sh: the API did not answer within 60 s (try: llm.sh logs)" >&2
	return 1
}

up() {
	if ! is_running; then
		# A stopped container of that name would block the new one.
		"$CONTAINER" rm -f "$NAME" >/dev/null 2>&1 || true
		echo "Starting $NAME ($IMAGE, using $CONTAINER)"
		"$CONTAINER" run -d --name "$NAME" -p "127.0.0.1:$PORT:11434" \
			-v "$VOLUME:/root/.ollama" "$IMAGE" >/dev/null
	fi
	wait_for_api
	if "$CONTAINER" exec "$NAME" ollama show "$MODEL" >/dev/null 2>&1; then
		echo "Model $MODEL is present"
	else
		echo "Pulling $MODEL (about 2 GB the first time)"
		"$CONTAINER" exec "$NAME" ollama pull "$MODEL"
	fi
	echo "Ready: $URL/v1 (model $MODEL)"
}

down() {
	case "${1:-}" in
	"" | --purge) ;;
	*)
		echo "llm.sh: unknown option '$1' (only --purge)" >&2
		exit 2
		;;
	esac
	"$CONTAINER" rm -f "$NAME" >/dev/null
	echo "Removed container $NAME if it was there (the models are kept in volume $VOLUME)"
	if [ "${1:-}" = --purge ]; then
		"$CONTAINER" volume rm -f "$VOLUME" >/dev/null
		echo "Removed volume $VOLUME if it was there"
	fi
}

check() {
	body=$(
		cat <<JSON
{"model": "$MODEL", "messages": [
 {"role": "system", "content": "You are Jens, a farmer in a North Frisian village in 1750. Answer in one or two short sentences, in character."},
 {"role": "user", "content": "Good morning! How is the harvest this year?"}]}
JSON
	)
	start=$(date +%s)
	response=$(curl -fsS --max-time 600 -H 'Content-Type: application/json' -d "$body" \
		"$URL/v1/chat/completions") || {
		echo "llm.sh: the request failed (is it up? try: llm.sh up)" >&2
		return 1
	}
	end=$(date +%s)
	reply=$(printf '%s' "$response" | python3 -c \
		'import json, sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"])') || {
		echo "llm.sh: unexpected response: $response" >&2
		return 1
	}
	echo "Reply: $reply"
	echo "Took $((end - start)) s"
}

case "${1:-}" in
up) up ;;
down) down "${2:-}" ;;
check) check ;;
status) "$CONTAINER" ps --filter "name=^$NAME\$" --format '{{.Names}} {{.Status}} {{.Ports}}' ;;
logs) "$CONTAINER" logs "$NAME" ;;
*)
	echo "Usage: $0 up | down [--purge] | check | status | logs" >&2
	exit 2
	;;
esac
