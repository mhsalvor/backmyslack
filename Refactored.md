### After Refactoring rewrite report
---

## What stayed the same

- Same behavior, workflow, and UX
- Same directory layout (previous, archived, timestamped backups)
- Same rsync logic (incremental via hardlinks)
- Same config/exclude handling
- Same logging format

## What changed (internally)

- Strict mode (set -Eeuo pipefail)
- Fixed real bugs (DESTDIR creation, spinner, quoting)
- Safer rsync invocation (arrays, no word-splitting)
- Cleaner rotation logic
- Centralized prompts, logging, rsync, root checks
- More readable and maintainable structure

