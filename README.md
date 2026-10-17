# freespace

`freespace` frees disk space on a Mac. It clears caches and build output that your tools can rebuild, and git worktrees whose work is already merged.

It shows what it would remove before it removes anything. A plain `freespace` is always a dry run.

## Install

```bash
git clone https://github.com/jcobhams/freespace.git
cd freespace
./install.sh
```

`install.sh` links the `freespace` command into `~/.local/bin` (set `FREESPACE_BIN` for another folder). It also links the agent skill into every AI coding agent it finds, as described in [Use it from an AI agent](#use-it-from-an-ai-agent). Both are symlinks into the clone, so `git pull` updates them. `./install.sh --uninstall` removes them. You can also skip the installer and run `./freespace` from the clone.

It needs macOS and git. It runs on the bash that ships with macOS. Each section checks for its tool first, so one you don't use (Docker, Rust, Xcode) skips itself.

## Use

```bash
freespace                      # dry run: what would go, and how big it is
freespace --apply              # remove it
freespace --only node,python   # just these sections
freespace --skip docker,xcode  # everything except these
freespace --help               # all sections and options
```

In a dry run, a line that starts with a size is something `--apply` removes. Lines that start with "kept" explain what it left alone and why. Commands it would run are shown as `would run:`.

```
Node and Next build output
  10.9 GB  ~/code/dash/.next
  802.5 MB  ~/code/videos/node_modules (project untouched for 14+ days)
  kept 55 folders in use now or in projects changed in the last 14 days

Git worktrees
  kept ~/code/api/.worktrees/deposits: used in the last 2 days
  183.0 MB  ~/code/api/.worktrees/search (feature/search, merged into main)
    would run: git -C ~/code/api worktree remove --force ~/code/api/.worktrees/search

Total
  281.4 GB  this run frees with --apply
  336.9 GB  with every option on:
    +35.9 GB  --project-days 0
    +3.5 GB  --days 0
    +8.3 GB  --include-unmerged
    +7.8 GB  --min-ios 27
```

The dry run ends with a total. The first line is what this run frees. The second is what you'd free with every opt-in option turned on, followed by what each option adds. Simulator clones, the pnpm store, conda and dangling Docker images aren't counted, because their size can't be measured reliably up front. A dry run that measures the options takes a few minutes, since it sizes everything it keeps too.

After `--apply` it prints your free space before and after.

## Use it from an AI agent

`skills/freespace` is an [Agent Skill](https://agentskills.io): a folder with a `SKILL.md` that tells a coding agent when and how to run `freespace`. Once it's installed, you can ask your agent things like "why is my disk full?" or "free up some space". The skill tells the agent to run a dry run first, show you the total, and only run `--apply` after you say yes.

`./install.sh` links it for every agent it finds:

| Agent | Skill folder |
|---|---|
| Claude Code | `~/.claude/skills/freespace` |
| Codex, Gemini CLI | `~/.agents/skills/freespace` |
| Grok | `~/.grok/skills/freespace` |

To install it by hand, or for another agent that reads Agent Skills, link the folder into that agent's skills folder:

```bash
ln -s "$PWD/skills/freespace" ~/.claude/skills/freespace
```

Copy it with `cp -RL` instead of `cp -R` if you'd rather not link it. The skill's `scripts/freespace` is a link to the script at the top of the repo, and `-L` copies the real file. Start a new agent session afterwards so it picks the skill up.

## What it removes

| Section | Removes | Comes back with |
|---|---|---|
| `claude-tmp` | Claude Code session temp folders untouched for 2 days, and Xcode build folders inside newer sessions' scratchpads | Claude Code makes new ones |
| `go-cache` | The Go build cache | The next `go build` or `go test` |
| `jetbrains` | Caches and logs of JetBrains IDE versions that a newer version replaced | Nothing needed |
| `packages` | bun, yarn and npm caches (including npx downloads), Homebrew downloads and old formula versions, unreferenced pnpm packages | The next install downloads them |
| `node` | `.next`, `.open-next` and `.turbo`, plus `node_modules` in projects untouched for 14 days | `next dev` or `next build`, and `npm install` or `bun install` |
| `rust` | `target/` in Cargo projects untouched for 14 days, and cargo's unpacked registry sources and git checkouts | `cargo build` |
| `cpp` | CMake, CLion (`cmake-build-*`) and Meson build folders in projects untouched for 14 days, and the ccache cache | Configure and build again |
| `python` | pip, uv, poetry, conda and pre-commit caches; `__pycache__`, pytest, mypy, ruff, tox and nox caches; `.venv` and `venv` in projects untouched for 14 days | `uv sync`, `poetry install` or `pip install -r requirements.txt` |
| `docker` | Build cache and dangling images. With `--docker-all`, also images no container uses, stopped containers and unused networks | `docker build` or `docker pull` |
| `xcode` | Simulator clones from parallel testing, DerivedData, simulators for runtimes that are no longer installed | The next build or test run |
| `old-ios` | iOS simulator runtimes older than `--min-ios`, and their simulators. Off unless you pass `--min-ios` | Xcode, Settings, Components |
| `worktrees` | Git worktrees that are merged, clean and idle, plus their local branches and empty leftover worktree folders | `git worktree add` |

`node`, `rust`, `cpp`, `python` and `worktrees` search every folder in your home folder except hidden ones, `Library`, `Applications`, `Movies`, `Music`, `Pictures`, `Public`, `OrbStack` and the Go module cache. They also search `~/.config/superpowers/worktrees`. Use `--scan` to search only the folders you name, and `--exclude` to skip one.

## How it stays safe

- Nothing is deleted without `--apply`, and the config file can't turn `--apply` on.
- It only deletes inside your home folder and the Claude Code temp folder.
- Build output written in the last hour is kept, so a running dev server or build keeps its files.
- `node_modules`, Rust `target/` folders, C++ build folders and virtual environments are only removed from projects with no file changes in 14 days (`--project-days`).
- A worktree is only removed when all of these hold:
  - its branch is merged into the repo's `main` or `master`;
  - it has no uncommitted changes (Finder's `.DS_Store` files don't count);
  - it had no commits or checkouts in the last 2 days (`--days`);
  - it isn't locked.
- Its branch is then deleted with `git branch -d`, which refuses anything unmerged.
- An unmerged worktree is kept. With `--include-unmerged`, its folder goes but its branch stays, and the output shows the command that brings it back.
- A worktree whose repo has moved gets its `.git` link repaired before it's checked.
- C++ builds inside the source folder (in-source builds) are never removed, and neither are virtual environments without a `pyproject.toml`, `requirements*.txt`, `Pipfile`, `setup.py` or `uv.lock` to rebuild them from.
- Docker volumes and poetry's virtualenvs are never removed.
- Nothing is removed from hidden folders in your home folder, so tools like `~/.nvm` and `~/.vscode` keep their own `node_modules`.
- The Xcode section waits while `xcodebuild` is running, and cargo's sources are kept while `cargo` is running.

## Options

| Option | Default | What it does |
|---|---|---|
| `--apply` | off | Remove things instead of listing them |
| `--only a,b` | all | Run only these sections |
| `--skip a,b` | none | Run every section except these |
| `--days N` | 2 | How long a Claude Code session or a worktree must sit unused |
| `--project-days N` | 14 | How long a project must sit unchanged before its dependencies and builds go |
| `--min-ios N` | off | Remove iOS simulator runtimes older than iOS N |
| `--include-unmerged` | off | Also remove clean, idle worktrees of unmerged branches (the branches stay) |
| `--docker-all` | off | Also remove unused Docker images, stopped containers and unused networks |
| `--scan DIR` | home folder | Search only this folder. Repeat it for more than one |
| `--exclude DIR` | none | Skip this folder. Repeat it for more than one |

`--days 0` and `--project-days 0` drop the waiting period. The one-hour guard still applies.

## Config file

Put options you always want in `~/.config/freespace/options`, one per line. Command-line options override them.

```
# Docker keeps its data here
--exclude ~/docker-data
--min-ios 26
--project-days 30
```

`FREESPACE_CONFIG` points it at a different file.

## Good to know

- `du` over-reports simulator clones, because APFS copies share disk blocks. That's why the summary compares free space before and after instead of adding up folder sizes.
- macOS removes deleted simulator runtimes in the background. Check your free space again a few minutes later.
- Docker Desktop and OrbStack keep images inside a disk image. Space can take a while to return to your Mac after Docker deletes things.
- The Go build cache can grow by hundreds of gigabytes in a few days if you build in many worktrees. `freespace --only go-cache --apply` is worth running often.

## License

MIT. See [LICENSE](LICENSE).
