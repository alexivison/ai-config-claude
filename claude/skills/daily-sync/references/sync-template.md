# Daily Sync Template

## Slack Message Format

```
*Daily Sync — <Month Day> (<Weekday>)*

*What I wrought:*
• <ticket-link>: <description>

*What I pursue today:*
• <ticket-link>: <description>

*Blockers:*
• <description or "None">

*Notes:*
• <OOO/AFK from calendar, meeting-heavy warnings, or other context>
```

- Do NOT include a "Sent using Claude" footer — Slack adds this automatically.
- Omit the *Notes* section entirely if there's nothing to surface (no OOO, no calendar notes).

## Ticket Link Format

Every ticket ID must be a clickable Slack link using the Linear workspace URL
from `data-sources.md`. Format:
```
<https://linear.app/<workspace>/issue/PROJ-XXX|PROJ-XXX>
```

Example:
```
<https://linear.app/<workspace>/issue/PROJ-525|PROJ-525>: Reusable UI components — done
```

When two tickets share the same line (e.g., worked on together in one PR):
```
<link|PROJ-8> / <link|PROJ-41>: Description
```

Read the Linear workspace slug from `data-sources.md` to construct the URLs.

## Tone Guide

Lightly playful — a colleague should smile, not squint.

| Standard | Playful alternative |
|----------|-------------------|
| What I did | What I wrought |
| What I'm doing | What I pursue today |
| Blockers | Blockers (keep as-is) |
| completed | vanquished, sealed, done |
| working on | forging, wiring, pursuing |
| waiting for | awaiting |
| started | began the craft |
| depends on | once X is sealed / lands |

Don't force it — use plain language when the playful version sounds awkward.

## Section Guidelines

**What I wrought:**
- Only include work that's actually done (merged, completed, delivered)
- Group related tickets on the same line when they were part of one effort
- Lead with the ticket link, then a colon, then a concise description

**What I pursue today:**
- What you plan to work on today
- Include context on readiness (e.g., "deps in place", "awaiting review")

**Blockers:**
- Concrete blockers only — not "nice to haves"
- Include who/what you're waiting on
- "None" is a valid answer

**Notes:** (optional — omit if empty)
- OOO/AFK blocks from Google Calendar (e.g., "AFK ~9:30–11:30, commuting to office")
- Meeting-heavy day warnings
- Other relevant context (team events, etc.)

## Channel

Post to the **sync target** channel configured in `data-sources.md`.
