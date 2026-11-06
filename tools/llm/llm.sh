#!/bin/sh
# A local LLM for testing NPC talk: Ollama in a container, OpenAI-compatible API on
# http://127.0.0.1:11434/v1. See tools/README.md.
# Usage: llm.sh up | down [--purge] | check | pull | models | rm | status | logs
# LLM_GPU=auto (default: the NVIDIA GPU if a CDI spec for it exists) | 1 (GPU or fail) | 0 (CPU).
set -eu

# Pinned, so the test setup does not change under us.
IMAGE=docker.io/ollama/ollama:0.35.0
NAME=sandbox-game-llm
VOLUME=sandbox-game-llm-models
PORT=11434
URL=http://127.0.0.1:$PORT
MODEL=${LLM_MODEL:-qwen2.5:3b-instruct}
GPU=${LLM_GPU:-auto}
GPU_DEVICE=nvidia.com/gpu=all
GPU_LABEL=sandbox-game.gpu

if [ -z "${CONTAINER:-}" ]; then
	if command -v podman >/dev/null 2>&1; then CONTAINER=podman; else CONTAINER=docker; fi
fi

is_running() {
	[ "$("$CONTAINER" inspect --format '{{.State.Running}}' "$NAME" 2>/dev/null)" = true ]
}

# podman and docker (28+) both read CDI specs from these places; nvidia-ctk writes them.
has_gpu_spec() {
	grep -qsF 'nvidia.com/gpu' /etc/cdi/*.yaml /etc/cdi/*.json /var/run/cdi/*.yaml /var/run/cdi/*.json
}

# Prints 1 if the container gets the GPU, 0 if not; fails if LLM_GPU=1 cannot be met.
want_gpu() {
	case "$GPU" in
	0) echo 0 ;;
	1 | auto)
		if has_gpu_spec; then
			echo 1
			return 0
		fi
		if [ "$GPU" = 1 ]; then
			echo "llm.sh: LLM_GPU=1 but there is no CDI spec for nvidia.com/gpu (see tools/README.md)" >&2
			return 1
		fi
		if command -v nvidia-smi >/dev/null 2>&1; then
			echo "llm.sh: the NVIDIA GPU has no CDI spec, using the CPU (see tools/README.md)" >&2
		fi
		echo 0
		;;
	*)
		echo "llm.sh: LLM_GPU must be auto, 1 or 0, not '$GPU'" >&2
		return 1
		;;
	esac
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
	gpu=$(want_gpu)
	# The label records how the container was started, so a GPU change recreates it.
	if is_running && [ "$("$CONTAINER" inspect --format "{{index .Config.Labels \"$GPU_LABEL\"}}" "$NAME")" != "$gpu" ]; then
		echo "Recreating $NAME: it runs with a different GPU setting"
		"$CONTAINER" rm -f "$NAME" >/dev/null
	fi
	if ! is_running; then
		# A stopped container of that name would block the new one.
		"$CONTAINER" rm -f "$NAME" >/dev/null 2>&1 || true
		if [ "$gpu" = 1 ]; then
			set -- --device "$GPU_DEVICE"
			where=GPU
		else
			set --
			where=CPU
		fi
		echo "Starting $NAME ($IMAGE, using $CONTAINER, on the $where)"
		"$CONTAINER" run -d --name "$NAME" --label "$GPU_LABEL=$gpu" "$@" \
			-p "127.0.0.1:$PORT:11434" -v "$VOLUME:/root/.ollama" "$IMAGE" >/dev/null
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
	# The PROCESSOR column says whether the model sits on the GPU or the CPU.
	"$CONTAINER" exec "$NAME" ollama ps
}

# The other commands need the container up.
need_running() {
	if ! is_running; then
		echo "llm.sh: $NAME is not running (start it: make llm-up)" >&2
		exit 1
	fi
}

# Fetches $MODEL into the volume, next to the others; the game uses the one set in its
# Settings (Language model -> Model).
pull() {
	need_running
	if "$CONTAINER" exec "$NAME" ollama show "$MODEL" >/dev/null 2>&1; then
		echo "Model $MODEL is present"
	else
		echo "Pulling $MODEL"
		"$CONTAINER" exec "$NAME" ollama pull "$MODEL"
	fi
	echo "To use it: Settings -> Language model -> Model: $MODEL (and make llm-check LLM_MODEL=$MODEL)"
}

case "${1:-}" in
up) up ;;
down) down "${2:-}" ;;
check) check ;;
pull) pull ;;
models)
	need_running
	"$CONTAINER" exec "$NAME" ollama list
	;;
rm)
	need_running
	"$CONTAINER" exec "$NAME" ollama rm "$MODEL"
	;;
status) "$CONTAINER" ps --filter "name=^$NAME\$" --format '{{.Names}} {{.Status}} {{.Ports}}' ;;
logs) "$CONTAINER" logs "$NAME" ;;
*)
	echo "Usage: $0 up | down [--purge] | check | pull | models | rm | status | logs" >&2
	exit 2
	;;
esac
