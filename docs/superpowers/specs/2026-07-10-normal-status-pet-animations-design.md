# Normal Status Labels and Semantic Pet Animations

## Goal

Make Codex Status Bar calm and immediately understandable. Thinking uses the fixed label `Thinking…`; tool activity keeps the existing concise tool labels; the selected Codex pet communicates the specific activity through its standard animation rows.

## Labels

- Thinking: `Thinking…`
- Shell and command tools: `Running command`
- File mutation tools: `Editing`
- File and resource reads: `Reading`
- Search tools: `Searching`
- Browser and web tools: `Browsing web`
- Unknown tools: `Using tool`
- Permission requests: `Awaiting permission`
- Completed turns: `Done`

The rotating playful thinking-word list and its menu toggle are removed. The timer and pet-animation toggles remain unchanged.

## Animation Mapping

The app uses the standard Codex pet atlas row contract for both v1 and v2 pets:

| Activity | Atlas row | Used columns | Behavior |
| --- | ---: | ---: | --- |
| Idle | 0 | 0–5 | Animate the calm idle loop when animation is enabled; otherwise show its first frame. |
| Running command | 1 or 2 | 0–7 | Alternate run-right and run-left on successive command actions. |
| Editing | 3 | 0–3 | Use the waving/hand-motion loop. |
| Completed turn | 4 | 0–4 | Play one complete jumping loop, then return to idle. |
| Explicit tool failure | 5 | 0–7 | Use the failed loop only when the hook payload provides a reliable failure signal. Do not infer failure from output text. |
| Awaiting permission | 6 | 0–5 | Animate the waiting loop and retain the amber permission indicator. |
| Thinking or unknown tool | 7 | 0–5 | Use the active-work loop. |
| Reading, searching, or browsing | 8 | 0–5 | Use the review loop. |

Rows 9 and 10 in v2 pets are look-direction rows and are not activity animations.

## State and Rendering

`HookEventMapper` remains responsible for normalizing hook events into states and labels. It additionally emits a stable animation activity so rendering does not have to infer behavior from display text. The command direction alternates per session and is persisted in that session's state file so it remains stable while an action is active.

The status controller selects the highest-priority session as it does today, then renders the animation row for that session's activity. Frame counts and per-frame timing follow the standard Codex pet row contract instead of assuming six working frames and a fixed frame rate for every state. Reduced Motion and the existing `Animate pet` toggle display the first frame of the selected row.

`Stop` remains visible as `Done` for one complete jumping loop (840 milliseconds under the standard timing), then collapses to idle. Escape/interrupted-turn detection still collapses directly to idle and does not celebrate an aborted turn.

If a selected pet or requested row cannot load, the app falls back to the existing bundled Codex mark without changing the status label.

## Validation

Core tests cover label normalization, activity selection, command-direction alternation, and state transitions. Rendering tests cover standard row/frame selection for v1 and v2 layouts. The full test suite, universal build, code-sign verification, local installation, and a live status-bar smoke check complete verification.
