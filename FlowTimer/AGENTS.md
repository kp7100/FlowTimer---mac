# FlowTimer - AI Development Guidelines

## Development
- Preserve existing behavior unless explicitly asked to change it.
- Make the smallest possible change. Avoid unnecessary refactors.
- Do not modify unrelated code while fixing an issue.
- The current working tree is the source of truth.

## Git Safety
- Never run `git checkout`, `git restore`, `git reset`, `git revert`, `git switch`, or any Git command that modifies the working tree unless I explicitly ask.
- Use Git only for inspection (`status`, `diff`, `log`, `show`, `blame`).
- Before risky changes or refactors, check `git status` and create an atomic checkpoint commit if there are uncommitted changes.
- Never push automatically.

## Before Refactoring
- Briefly explain the plan.
- List behaviors that must remain unchanged.
- If the change is risky or affects architecture, wait for confirmation.

## Prevent Regressions
- Verify the requested fix.
- Verify no existing functionality was broken.
- If a regression is found, restore it before continuing.

## Documentation
- Update the relevant project documentation whenever architecture or behavior changes.
- Document important decisions and hard-earned fixes so they aren't rediscovered later.
