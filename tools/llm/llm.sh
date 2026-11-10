#!/bin/sh
# A local LLM for testing NPC talk: Ollama in a container, OpenAI-compatible API on
# http://127.0.0.1:11434/v1. See tools/README.md.
# Usage: llm.sh up | down [--purge] | check | pull | models | rm | status | logs | gpu-setup
# LLM_GPU=auto (default: NVIDIA if a CDI spec for it exists, else AMD if ROCm can reach the
# card, else the CPU) | nvidia | amd | 1 (any GPU or fail) | 0 (CPU).
# LLM_HSA_OVERRIDE=10.3.0 passes HSA_OVERRIDE_GFX_VERSION to the AMD container (see tools/README.md).
# LLM_DRY_RUN=1 llm.sh up only prints the command that would start the container.
set -eu

# Pinned, so the test setup does not change under us. The AMD image is the same version with ROCm.
VERSION=0.35.0
IMAGE=docker.io/ollama/ollama:$VERSION
IMAGE_AMD=docker.io/ollama/ollama:$VERSION-rocm
NAME=sandbox-game-llm
VOLUME=sandbox-game-llm-models
PORT=11434
URL=http://127.0.0.1:$PORT
MODEL=${LLM_MODEL:-qwen2.5:7b-instruct}
GPU=${LLM_GPU:-auto}
GPU_DEVICE=nvidia.com/gpu=all
GPU_LABEL=sandbox-game.gpu
CDI_SPEC=/etc/cdi/nvidia.yaml
# Where container tools look for CDI specs (podman and docker 28+ read both); a test points it
# at a fake tree.
CDI_DIRS=${LLM_CDI_DIRS:-/etc/cdi:/var/run/cdi}
# Where the AMD GPU shows up; the variables let a test point them at a fake tree.
KFD_DEVICE=${LLM_KFD_DEVICE:-/dev/kfd}
DRI_DIR=${LLM_DRI_DIR:-/dev/dri}
KFD_NODES=${LLM_KFD_NODES:-/sys/class/kfd/kfd/topology/nodes}
AMDGPU_MODULE=${LLM_AMDGPU_MODULE:-/sys/module/amdgpu}

if [ -z "${CONTAINER:-}" ]; then
	if command -v podman >/dev/null 2>&1; then CONTAINER=podman; else CONTAINER=docker; fi
fi

is_running() {
	[ "$("$CONTAINER" inspect --format '{{.State.Running}}' "$NAME" 2>/dev/null)" = true ]
}

# The first render node in /dev/dri, if there is one.
render_node() {
	for node in "$DRI_DIR"/renderD*; do
		if [ -e "$node" ]; then
			echo "$node"
			return 0
		fi
	done
	return 1
}

# Says what keeps ROCm from the AMD GPU; says nothing if it can use it.
amd_problem() {
	if [ ! -e "$KFD_DEVICE" ]; then
		echo "no $KFD_DEVICE: the amdgpu kernel driver is not loaded, or there is no AMD GPU"
		return 0
	fi
	if ! node=$(render_node); then
		echo "no render node in $DRI_DIR"
		return 0
	fi
	for device in "$KFD_DEVICE" "$node"; do
		if [ ! -r "$device" ] || [ ! -w "$device" ]; then
			group=$(stat -c %G "$device")
			echo "$device is not accessible: join its group with sudo usermod -aG $group $(id -un), then log in again"
			return 0
		fi
	done
}

# Prints the gfx targets of the GPUs ROCm sees, as "gfx1100 11.0.0" lines (name, HSA version).
# The kernel gives them as one number, major*10000 + minor*100 + step; the CPU node says 0.
amd_gfx_targets() {
	for properties in "$KFD_NODES"/*/properties; do
		[ -r "$properties" ] || continue
		version=$(sed -n 's/^gfx_target_version  *//p' "$properties")
		[ "${version:-0}" -gt 0 ] || continue
		major=$((version / 10000))
		minor=$((version / 100 % 100))
		step=$((version % 100))
		printf 'gfx%d%x%x %d.%d.%d\n' "$major" "$minor" "$step" "$major" "$minor" "$step"
	done
}

# Prints the detected gfx targets, with the LLM_HSA_OVERRIDE to try for the consumer cards
# ROCm does not list: RDNA2 except the 6800/6900 (gfx1030), and the RDNA3 7600 (gfx1102).
amd_describe() {
	targets=$(amd_gfx_targets)
	count=$(printf '%s\n' "$targets" | grep -c . || true)
	[ "$count" -gt 0 ] || return 0
	printf '%s\n' "$targets" | while read -r gfx _; do
		echo "AMD GPU: $gfx"
		case "$gfx" in
		gfx1030) ;;
		gfx103?) echo "  not listed by ROCm; if it fails, try LLM_HSA_OVERRIDE=10.3.0 (RDNA2, as the 6800/6900)" ;;
		gfx1102) echo "  not listed by ROCm; if it fails, try LLM_HSA_OVERRIDE=11.0.0 (RDNA3, as the 7900)" ;;
		esac
	done
	# A Ryzen's built-in graphics shows up as a GPU too; an override would apply to every one of
	# them and could break a card ROCm supports as it is.
	if [ "$count" -gt 1 ]; then
		echo "  several AMD GPUs: an LLM_HSA_OVERRIDE applies to all of them, so only set one if none is supported"
	fi
}

# nvidia-ctk writes the spec into one of the CDI directories.
has_gpu_spec() {
	for dir in $(echo "$CDI_DIRS" | tr : ' '); do
		grep -qsF 'nvidia.com/gpu' "$dir"/*.yaml "$dir"/*.json && return 0
	done
	return 1
}

# Prints nvidia, amd or cpu: what the container gets. Fails if LLM_GPU asks for a GPU that is
# not there. Says on stderr why a GPU is not used.
choose_gpu() {
	case "$GPU" in
	0) echo cpu ;;
	nvidia)
		has_gpu_spec || {
			echo "llm.sh: LLM_GPU=nvidia but there is no CDI spec for nvidia.com/gpu (see tools/README.md)" >&2
			return 1
		}
		echo nvidia
		;;
	amd)
		problem=$(amd_problem)
		if [ -n "$problem" ]; then
			echo "llm.sh: LLM_GPU=amd but $problem (see tools/README.md)" >&2
			return 1
		fi
		echo amd
		;;
	1 | auto)
		problem=$(amd_problem)
		if has_gpu_spec; then
			[ -n "$problem" ] || echo "llm.sh: NVIDIA and AMD GPUs are both usable, taking NVIDIA (LLM_GPU=amd picks the other)" >&2
			echo nvidia
		elif [ -z "$problem" ]; then
			echo amd
		elif [ "$GPU" = 1 ]; then
			echo "llm.sh: LLM_GPU=1 but no GPU is usable: no CDI spec for nvidia.com/gpu; AMD: $problem (see tools/README.md)" >&2
			return 1
		else
			if command -v nvidia-smi >/dev/null 2>&1; then
				echo "llm.sh: the NVIDIA GPU has no CDI spec, using the CPU (see tools/README.md)" >&2
			fi
			# Without any sign of an AMD GPU there is nothing to say about one.
			if [ -e "$KFD_DEVICE" ] || [ -d "$AMDGPU_MODULE" ]; then
				echo "llm.sh: the AMD GPU is not usable, using the CPU: $problem (see tools/README.md)" >&2
			fi
			echo cpu
		fi
		;;
	*)
		echo "llm.sh: LLM_GPU must be auto, nvidia, amd, 1 or 0, not '$GPU'" >&2
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

# Pulls $MODEL unless the volume has it.
ensure_model() {
	if "$CONTAINER" exec "$NAME" ollama show "$MODEL" >/dev/null 2>&1; then
		echo "Model $MODEL is present"
	else
		echo "Pulling $MODEL"
		"$CONTAINER" exec "$NAME" ollama pull "$MODEL"
	fi
}

up() {
	gpu=$(choose_gpu)
	case "$gpu" in
	nvidia)
		set -- --device "$GPU_DEVICE"
		image=$IMAGE
		;;
	amd)
		amd_describe
		set -- --device "$KFD_DEVICE" --device "$DRI_DIR"
		# The devices belong to groups the container may not have by name.
		if [ "$CONTAINER" = podman ]; then
			set -- "$@" --group-add keep-groups
		else
			set -- "$@" --group-add "$(stat -c %g "$KFD_DEVICE")" --group-add "$(stat -c %g "$(render_node)")"
		fi
		if [ -n "${LLM_HSA_OVERRIDE:-}" ]; then
			set -- "$@" -e "HSA_OVERRIDE_GFX_VERSION=$LLM_HSA_OVERRIDE"
		fi
		image=$IMAGE_AMD
		;;
	cpu)
		set --
		image=$IMAGE
		;;
	esac
	if [ -n "${LLM_DRY_RUN:-}" ]; then
		echo "$CONTAINER run -d --name $NAME --label $GPU_LABEL=$gpu $* -p 127.0.0.1:$PORT:11434 -v $VOLUME:/root/.ollama $image"
		return 0
	fi
	# The label records how the container was started, so a GPU change recreates it.
	if is_running && [ "$("$CONTAINER" inspect --format "{{index .Config.Labels \"$GPU_LABEL\"}}" "$NAME")" != "$gpu" ]; then
		echo "Recreating $NAME: it runs with a different GPU setting"
		"$CONTAINER" rm -f "$NAME" >/dev/null
	fi
	if ! is_running; then
		# A stopped container of that name would block the new one.
		"$CONTAINER" rm -f "$NAME" >/dev/null 2>&1 || true
		echo "Starting $NAME ($image, using $CONTAINER, on $gpu)"
		"$CONTAINER" run -d --name "$NAME" --label "$GPU_LABEL=$gpu" "$@" \
			-p "127.0.0.1:$PORT:11434" -v "$VOLUME:/root/.ollama" "$image" >/dev/null
	fi
	wait_for_api
	ensure_model
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
	wait_for_api
	ensure_model
	echo "To use it: Settings -> Language model -> Model: $MODEL (and make llm-check LLM_MODEL=$MODEL)"
}

# Writes the CDI spec that lets containers have the NVIDIA GPU (root, via sudo). Run it once,
# and again after each driver update: a spec of an older driver breaks the container's start.
nvidia_setup() {
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		echo "llm.sh: no nvidia-smi: the NVIDIA driver is not installed" >&2
		return 1
	fi
	if ! nvidia-smi >/dev/null 2>&1; then
		echo "llm.sh: nvidia-smi fails (after a driver update, reboot first):" >&2
		nvidia-smi >&2 || true
		return 1
	fi
	if ! command -v nvidia-ctk >/dev/null 2>&1; then
		echo "llm.sh: no nvidia-ctk: install the NVIDIA container toolkit first" >&2
		echo "  (Gentoo: sudo emerge app-containers/nvidia-container-toolkit; see tools/README.md)" >&2
		return 1
	fi
	echo "Writing $CDI_SPEC (needs root)"
	sudo nvidia-ctk cdi generate --output="$CDI_SPEC"
	nvidia-ctk cdi list
	echo "Done: make llm-up now starts the container on the GPU"
}

# AMD needs no spec, only a driver and access to two device files: this checks them (no root).
amd_setup() {
	problem=$(amd_problem)
	if [ -n "$problem" ]; then
		echo "llm.sh: $problem (see tools/README.md)" >&2
		return 1
	fi
	amd_describe
	echo "Done: $KFD_DEVICE and $(render_node) are usable; make llm-up now starts the container on the GPU"
}

# Sets up the GPU the host has: NVIDIA first, or the one LLM_GPU names.
gpu_setup() {
	case "$GPU" in
	nvidia) nvidia_setup ;;
	amd) amd_setup ;;
	0) echo "llm.sh: LLM_GPU=0 asks for the CPU, nothing to set up" >&2 ;;
	*)
		if command -v nvidia-smi >/dev/null 2>&1; then
			nvidia_setup
		elif [ -e "$KFD_DEVICE" ] || [ -d "$AMDGPU_MODULE" ]; then
			amd_setup
		else
			echo "llm.sh: no NVIDIA driver (nvidia-smi) and no AMD driver (amdgpu) found: nothing to set up, the CPU is used" >&2
			return 1
		fi
		;;
	esac
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
gpu-setup) gpu_setup ;;
*)
	echo "Usage: $0 up | down [--purge] | check | pull | models | rm | status | logs | gpu-setup" >&2
	exit 2
	;;
esac
