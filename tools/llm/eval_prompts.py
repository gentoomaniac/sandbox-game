"""Tries the villagers' prompts on a language model and writes a report to read.

Godot builds the requests (tools/llm/dump_requests.gd, with NpcPrompt itself, so they are what
the game sends); each is sent --runs times to the model of the OpenAI-compatible endpoint (the
test LLM, see llm.sh), and every reply is written to build/llm-eval/<model>.md with a few
automatic checks. The checks are crude: they find what is plainly wrong, a person judges the rest.

    eval_prompts.py [--model TAG] [--endpoint URL] [--runs N] [--only ID ...] [--requests FILE]
                    [--compare TAG TAG]

LLM_API_KEY, if set, is sent as the bearer key (a hosted model: also give --endpoint).
--requests sends the requests of an earlier dump (to try other words on the same scenarios).
--compare puts the replies of two models, as written by earlier runs, side by side.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "llm-eval"
ENDPOINT = "http://127.0.0.1:11434/v1"
GODOT = os.environ.get("GODOT", "godot")
# A reply this long, in characters, would not fit the token budget of a short line anyway.
MAX_CHARS = 200
TIMEOUT_SECONDS = 300

# Words that give away an assistant, or a game that is not set in 1750.
FORBIDDEN = [
    "as an ai", "language model", "help you", "assist", "how can i", "happy to help",
    "feel free", "let me know", "certainly", "okay", "smartphone", "of course!",
]  # fmt: skip
NOT_UNDERSTOOD = re.compile(r"don't understand|do not understand|förstår inte|verstehe nicht", re.I)
LABEL_ECHO = re.compile(r"reply\s*(\(in the language[^)]*\))?\s*:|^\(in the language|^[\w ]+:\s", re.I)

# Words that mark a language, crude but enough to tell a reply in German from one in English.
STOPWORDS = {
    "de": "ich nicht und der die das ist ein eine mit auch wir wie gut heute aber mein mir dir dich "
    "noch auf von zu es nein schon hier kann bin sind war ihr euch du moin".split(),
    "da": "jeg ikke og det er med også vi har godt på af til som men min mit mig dig hvad nej "
    "hvordan går fra at den de en et så var kan du".split(),
    "en": "the and is you i my to of it that in aye not for with but your are was have this "
    "there what has me we be".split(),
}
# Letters only one language has: each counts as two words, as in the game's detector.
LETTERS = {"de": "äöüß", "da": "æø"}


def build_requests():
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "requests.json"
    subprocess.run(
        [GODOT, "--headless", "--quiet", "--path", str(ROOT), "-s",
         "tools/llm/dump_requests.gd", "--", str(path)],
        check=True, stdout=subprocess.DEVNULL,
    )  # fmt: skip
    return json.loads(path.read_text())


class RateLimited(Exception):
    """The endpoint answered HTTP 429."""


def ask(endpoint, model, request):
    body = json.dumps({**request, "model": model}).encode()
    headers = {"Content-Type": "application/json"}
    if os.environ.get("LLM_API_KEY"):
        headers["Authorization"] = "Bearer " + os.environ["LLM_API_KEY"]
    http_request = urllib.request.Request(endpoint + "/chat/completions", body, headers)
    started = time.monotonic()
    try:
        with urllib.request.urlopen(http_request, timeout=TIMEOUT_SECONDS) as response:
            answer = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            raise RateLimited from error
        raise
    choice = answer["choices"][0]
    seconds = time.monotonic() - started
    return choice["message"]["content"], choice["finish_reason"], seconds


def trimmed(text, label, villager, sentences):
    """What the game makes of the answer (NpcPrompt.trimmed_reply)."""
    said = text.strip()
    if label and said.lower().startswith(label.lower()):
        said = said[len(label):].strip()
    line = said.split("\n")[0]
    first_name = villager.split()[0]
    for prefix in (f"{first_name}'s reply:", f"{villager}:", f"{first_name}:"):
        if line.lower().startswith(prefix.lower()):
            line = line[len(prefix):].strip()
    for quotes in ('""', "“”", "''"):
        if len(line) > 1 and line[0] == quotes[0] and line[-1] == quotes[1]:
            line = line[1:-1].strip()
    end = 0
    for found in list(re.finditer(r"([!?]+|(?<!\.)\.)[\"”']?(\s|$)", line))[:sentences]:
        end = found.end()
    return line[:end].strip() if end else line


def words_of(text):
    return re.findall(r"\w+", text.lower())


def language_of(text):
    words = re.findall(r"[a-zäöüßæøå]+", text.lower())
    scores = {lang: sum(word in stop for word in words) for lang, stop in STOPWORDS.items()}
    for lang, letters in LETTERS.items():
        scores[lang] += 2 * sum(text.lower().count(letter) for letter in letters)
    best = max(scores.values())
    leaders = [lang for lang, score in scores.items() if score == best]
    return leaders[0] if best > 0 and len(leaders) == 1 else None


def checks(raw, finish_reason, scenario):
    """Names of the checks that failed for this reply."""
    reply = trimmed(raw, scenario["label"], scenario["villager"], scenario["sentences"])
    lower = raw.lower()
    failed = []
    if not reply:
        return ["empty"]
    if len(reply) > MAX_CHARS:
        failed.append("long")
    ends_properly = reply[-1] in ".!?\"'”…"
    if finish_reason == "length" and reply == raw.strip().split("\n")[0] and not ends_properly:
        failed.append("cut off")
    if len(re.findall(r"[.!?]+(\s|$)", reply)) > scenario["sentences"]:
        failed.append("too many sentences")
    if words_of(reply)[:6] == words_of(scenario["example_reply"])[:6]:
        failed.append("copies the example")
    if scenario["message"] and words_of(reply)[:5] == words_of(scenario["message"])[:5]:
        failed.append("echoes the neighbour")
    if any(word in lower for word in FORBIDDEN):
        failed.append("assistant words")
    if LABEL_ECHO.search(raw.strip()):
        failed.append("label echo")
    if scenario["id"] != "memory_summary":
        found = language_of(reply)
        if scenario["language"] == "other":
            # The word lists only know the game's languages: for another one it is wrong to
            # answer in English or to say one does not understand.
            if found == "en" or NOT_UNDERSTOOD.search(reply):
                failed.append(f"language ({found})")
        elif found != scenario["language"] and not (found is None and scenario["language"] == "en"):
            failed.append(f"language ({found or '?'})")
    elif not re.search(r"\b(i|my|me)\b", reply, re.I):
        failed.append("not first person")
    return failed


def run(args):
    requests = json.loads(Path(args.requests).read_text()) if args.requests else build_requests()
    scenarios = [s for s in requests if not args.only or s["id"] in args.only]
    results = []
    rate_limited = False
    for scenario in scenarios:
        replies = []
        try:
            for _ in range(args.runs):
                raw, finish_reason, seconds = ask(args.endpoint, args.model, scenario["request"])
                replies.append({
                    "raw": raw,
                    "reply": trimmed(raw, scenario["label"], scenario["villager"], scenario["sentences"]),
                    "failed": checks(raw, finish_reason, scenario),
                    "seconds": round(seconds, 1),
                })  # fmt: skip
                print(f"{scenario['id']}: {replies[-1]['reply']}  {replies[-1]['failed']}", flush=True)
        except RateLimited:
            rate_limited = True
        if replies:
            results.append({"scenario": scenario["id"], "villager": scenario["villager"],
                            "language": scenario["language"], "replies": replies})  # fmt: skip
        if rate_limited:
            break
    scenarios = scenarios[: len(results)]
    stem = args.model.replace(":", "-")
    (OUT / f"{stem}.json").write_text(json.dumps(results, indent=1, ensure_ascii=False))
    (OUT / f"{stem}.md").write_text(report(args.model, args.runs, scenarios, results))
    print(f"wrote {OUT / (stem + '.md')}")
    if rate_limited:
        sys.exit("The endpoint is rate limiting (HTTP 429): stopped, the report is partial.")


def totals(results):
    replies = [r for result in results for r in result["replies"]]
    clean = sum(not r["failed"] for r in replies)
    seconds = sum(r["seconds"] for r in replies) / max(len(replies), 1)
    return len(replies), clean, seconds


def report(model, runs, scenarios, results):
    count, clean, seconds = totals(results)
    failures = {}
    for result in results:
        for r in result["replies"]:
            for failed in r["failed"]:
                key = failed.split(" (")[0]
                failures[key] = failures.get(key, 0) + 1
    lines = [
        f"# Villager prompts on {model}", "",
        f"{count} replies ({runs} per scenario), {clean} without a failed check, "
        f"{seconds:.1f} s per reply.", "",
    ]  # fmt: skip
    lines += [f"- {name}: {n}" for name, n in sorted(failures.items())] or ["- no check failed"]
    for scenario, result in zip(scenarios, results):
        message = scenario["request"]["messages"][-1]["content"].split("\n")
        said = next((line for line in message if "says:" in line or line.startswith("Neighbour")), "")
        lines += ["", f"## {scenario['id']} ({result['villager']}, {result['language']})", "", said, ""]
        for r in result["replies"]:
            flags = f"  **[{', '.join(r['failed'])}]**" if r["failed"] else ""
            lines.append(f"- {r['reply']!r}{flags}")
    return "\n".join(lines) + "\n"


def compare(tags):
    loaded = [json.loads((OUT / f"{tag.replace(':', '-')}.json").read_text()) for tag in tags]
    lines = ["# " + " vs ".join(tags), ""]
    for tag, results in zip(tags, loaded):
        count, clean, seconds = totals(results)
        lines.append(f"- {tag}: {clean}/{count} replies without a failed check, {seconds:.1f} s each")
    for rows in zip(*loaded):
        lines += ["", f"## {rows[0]['scenario']} ({rows[0]['language']})"]
        for tag, row in zip(tags, rows):
            lines += ["", f"{tag}:"]
            for r in row["replies"]:
                flags = f"  **[{', '.join(r['failed'])}]**" if r["failed"] else ""
                lines.append(f"- {r['reply']!r}{flags}")
    path = OUT / "compare.md"
    path.write_text("\n".join(lines) + "\n")
    print(f"wrote {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--model", default=os.environ.get("LLM_MODEL", "qwen2.5:7b-instruct"))
    parser.add_argument("--endpoint", default=ENDPOINT)
    parser.add_argument("--runs", type=int, default=3, help="replies per scenario")
    parser.add_argument("--only", nargs="*", help="scenario ids to run")
    parser.add_argument("--requests", help="send the requests of this dump of an earlier run")
    parser.add_argument("--compare", nargs=2, metavar="TAG")
    args = parser.parse_args()
    if args.compare:
        compare(args.compare)
    else:
        run(args)


if __name__ == "__main__":
    sys.exit(main())
