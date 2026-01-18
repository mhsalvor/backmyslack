### High-level issues and refactoring goals

1. Safety and robustness
  - No ``set -eou pipefail``
  - Unquoted variable expressions
  - ``ps | grep`` spinner is fragile
  - ``cd "${DESTDIR}" || ext 1`` mid script without cleanup
  - Root check comes after some filesystem logic

2. Srtucture
  - Too many global variables
  - Repeated prompt logic
  - Rotation logic mixes state and I/O
  - Banner and UI functins mixed with core logic

3. Bash best practices
  - Use ``readonly`` for constants
  - Prefer ``local`` variables in functions
  - Avoid unnecessary ``echo -e``
  - Avoid parsing ``ps``
