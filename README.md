# TymeHelper

CLI tool that queries [Tyme 3](https://www.tyme-app.com) for time logged on a task and compares it against a budgeted number of hours.

Auto-detects the current Xcode project from your working directory and maps it to a Tyme task via a simple config file.

## Why

Freelance projects have budgets. When you're deep in code — or when an AI coding agent like Claude Code or Codex is working on your behalf — it's easy to lose track of hours spent vs hours remaining.

TymeHelper gives you (and your agents) a single command to check budget status before starting work. Add it to your `CLAUDE.md` or agent bootstrap and every session starts with budget awareness:

```markdown
## On Session Start
Run `tymehelper` at the start of every conversation to show hours logged vs budget.
```

No context needed, no manual lookup — just run it from the project directory.

## Output

```
  MyApp
  ──────────────────────────────
  Logged:     24h 30m
  Budget:     80h 00m (30% used)
  Remaining:  55h 30m

  Rate:       $75/hr
  Spent:      $1838 / $6000
  Left:       $4163
```

## Install

```bash
git clone https://github.com/stormychel/TymeHelper.git
cd TymeHelper
Scripts/install.sh
```

This builds a release binary and copies it to `/usr/local/bin/tymehelper`.

To uninstall:

```bash
Scripts/install.sh --uninstall
```

## Setup

Register a project with its Tyme task name, budgeted hours, and hourly rate:

```bash
tymehelper set MyApp "MyApp - Billable" 80 75
```

This creates a config entry in `~/.config/tymehelper/projects.json` mapping the Xcode project name `MyApp` to the Tyme task `MyApp - Billable` with a budget of 80 hours at $75/hr.

## Usage

From any Xcode project directory:

```bash
cd ~/Source/MyApp
tymehelper
```

The tool detects the `.xcodeproj` name, looks up the mapped Tyme task, and shows logged vs budgeted hours.

You can also pass the project name explicitly:

```bash
tymehelper MyApp
```

### With AI coding agents

Add a `tymehelper` call to your agent's startup instructions. The agent sees the budget before making decisions about scope, complexity, and whether to ask before proceeding:

```markdown
# CLAUDE.md
Run `tymehelper` at the start of every conversation.
```

This works with any agent that can run shell commands — Claude Code, Codex, Cursor, Windsurf, etc.

## How it works

1. Detects the Xcode project name from the current directory (looks for `.xcodeproj`)
2. Looks up the Tyme task name from `~/.config/tymehelper/projects.json`
3. Queries Tyme 3 via AppleScript for all timed task records on that task
4. Displays logged hours against the configured budget

## Requirements

- macOS 13+
- [Tyme 3](https://www.tyme-app.com) (must be running when querying)
- Swift 5.9+
