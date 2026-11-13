---
name: good-morning
description: Summarise everything that happened in the sandbox-game project since the user's last message (or since a given time), with the files that matter sent to the user's phone. Use when the user says "good morning", asks what happened overnight or while they were away, or invokes /good-morning.
---

# Good morning

The user reads this on their phone. Give one summary of everything that happened since their
last message (or since the time they name), and send the files it refers to so they can open
them there.

## 1. Gather (do not guess)

- What was merged and pushed: `git log --oneline <last-known-sha or --since>..main` and
  `git log -1 origin/main` (is everything pushed?).
- What is in flight: `git worktree list`, and for each agent worktree `git log --oneline
  main..<branch>` and whether it has uncommitted changes. Note running agents you are waiting
  on (their last reports in this conversation) and any commit they made but have not reported
  yet.
- Running processes: `ps -eo etime,args | grep -E '[g]odot|[m]ake |[r]un_tests' | grep -v
  lsp-port` (the user's editor always runs one godot with `--lsp-port`; that one is fine).
- Open questions: QUESTIONS.md (the newest numbered items), questions you asked in this
  conversation that have no answer yet.
- The queue: the open task headings in TASKS.md in order (`grep -n '^## ' TASKS.md`).
- The last full test run on main and its result (the scratchpad `merges-since-full` counter and
  your notes).
- TO-TEST.md: how many unticked lines there are.

## 2. Write the summary

Short, plain, grouped under these headings (leave out an empty one):

1. **Done** (merged and pushed): one bullet per task number and name, what the player gets, the
   numbers chosen and where they live (data/ files), anything left out.
2. **In progress**: what is merged so far, what waits for review or a fix, and why.
3. **Questions for you**: numbered, each answerable in a word or two, with the default that
   applies if the user doesn't answer.
4. **Housekeeping**: test status, leftovers (worktrees, processes) with the exact command for
   anything you were not allowed to do yourself.
5. **Next in the queue**.

Say "I" for what you did and name agents only by their role (a worker, a reviewer, a pixel
artist). No internal agent ids.

## 3. Send the referenced files

The user is likely on the phone, so for every file the summary refers to that they would want
to look at or listen to (screenshots and comparison pictures, crops for an art verdict,
listening WAVs, a design review, a plan), send it with SendUserFile (load it with ToolSearch
`select:SendUserFile` if needed). One call per file, each with a one-line caption saying what
it is and which question or task it belongs to. Order them as the summary mentions them.

- Prefer the one picture that answers a question (e.g. a before/after) over a folder of them;
  for a folder, send the two or three that matter and name the folder in the summary.
- Files that live only in a worktree or the scratchpad count too: send them, as the user can't
  reach those paths from the phone.
- In the summary text, still give each file's full absolute path, so they can find it later at
  the desk.
- Don't send code files or logs unless the user asks.

If SendUserFile is not available, say so in one line and list the paths.
