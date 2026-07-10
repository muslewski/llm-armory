# Task: <one-line title>

## Context
- Repo: <absolute path to worktree>
- Plan: <path to plan/advisor-plan and task number>
- You are an implementation executor. Implement ONLY this task. Do not touch
  files outside the listed scope. Do not refactor unrelated code.

## Scope
- Files to create/modify: <exact paths>
- Interfaces you must match (names, signatures, types): <from the plan>

## Done criteria (machine-checkable)
- <exact command>: <expected output>
- All tests pass: <exact test command>

## STOP conditions — abort and report instead of guessing
- A file you must modify does not exist or differs materially from the plan's description.
- Done-criteria command fails twice after your best fix.
- You need a credential, migration, or dependency not listed here.

## Commit protocol
- Small commits as you complete each step.
- EVERY commit message must end with this Executed-By trailer (fill from your session env
  $ANTHROPIC_MODEL and $LLM_PRESET):

    Executed-By: <model-id> (<preset>)

## Report
End your final message with:
- STATUS: done | blocked
- COMMITS: <hashes + one-liners>
- EVIDENCE: verbatim output of each done-criteria command
- DEVIATIONS: anything you did differently from the brief, or "none"
