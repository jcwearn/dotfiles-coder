# Git Workflow

**REQUIRED: Before editing any files**, always follow this workflow to create a branch first. Never commit directly to `main`. This applies to every task that modifies files in the repository.

1. Check for uncommitted changes: `git status --porcelain`
   - If there are changes, stash them: `git stash push -m "auto-stash: $(git branch --show-current) - WIP before branch switch"`
   - If clean, skip to the next step
2. Pull the latest from `main`: `git checkout main && git pull origin main`
3. Create a branch: `git checkout -b <type>/<description>` where type matches the work (e.g., `feat/`, `fix/`, `chore/`, `refactor/`, `docs/`)
4. Make changes and commit
5. Push and open a PR: `gh pr create --fill`
6. Merge after review
