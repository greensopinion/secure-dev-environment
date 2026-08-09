# Daily Workflow

Everyday development using the secure containerized environment.

## Opening a Project

1. Open the project folder in VS Code
2. VS Code detects `.devcontainer/` and prompts: "Reopen in Container"
3. Click "Reopen in Container" (or use Command Palette → "Dev Containers: Reopen in Container")
4. Wait for container to start (instant after first build)

## Development Loop

All of these happen **inside the container** (VS Code integrated terminal):

```bash
# Install dependencies
npm install

# Run tests
npm test

# Run build
npm run build

# Run dev server
npm run dev

# Any npm script
npm run <script>
```

## Git Operations

### Inside the container (read-only git — no credentials needed):

```bash
git status
git diff
git log --oneline
git branch
git show
```

### On the Mac terminal (all git mutations + remote operations):

```bash
git add .
git add -p
git reset HEAD <file>
git commit -m "feat: add new feature"
git stash
git stash pop
git checkout -b feature/new-thing
git pull
git push
git fetch
git clone git@github.com:<org>/<repo>.git
```

**Rule**: If the git command modifies `.git/` (commits, staging, stashing, branching) or talks to a remote, run it on Mac. If it only reads (status, diff, log, show), either side works.

## Editing

Edit files normally in VS Code. The files are bind-mounted from the Mac, so:
- Changes are instant (no sync delay)
- Files are visible from both Mac and container
- VS Code extensions (Jest, YAML, etc.) run in the container

## Running Tests

```bash
# Inside container terminal
npm test
npm run test:watch
npm run test:coverage
```

The Jest extension in VS Code also works for inline test running.

## Committing Work

1. Make your changes (container terminal or VS Code editor)
2. Switch to Mac terminal
3. Stage: `git add .`
4. Commit: `git commit -m "message"`
5. Push: `git push`

## End of Day

No special shutdown needed. The container keeps running. You can:
- Close VS Code (container stays running in background)
- Stop Docker Desktop (container stops, restarts next time)
- Leave everything running (fine)

## Tips

- **All git mutations on Mac**: Since `.git` is read-only in the container, stage/commit/push all from Mac terminal
- **Use VS Code's split terminal**: One pane for container commands (npm, tests), one for Mac (git, terraform)
- **npm install after pull**: If `package.json` changed, run `npm install` in the container
- **Container feels slow?**: Check Docker Desktop resource allocation (Settings → Resources)
