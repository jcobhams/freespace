---
name: freespace
description: Frees disk space on macOS by clearing caches and build output that tools rebuild (Go build cache, node_modules, .next, Rust target, C and C++ builds, Python virtual environments and caches, package manager caches, Docker build cache, Xcode DerivedData and simulators, Claude Code temp files) and git worktrees whose work is merged. Use when the disk is full or nearly full, macOS Storage settings show a large System Data, or the user asks to clean caches, reclaim storage or remove old worktrees.
---

# freespace

`scripts/freespace` in this skill's folder is a bash script that finds and removes rebuildable files. Use `freespace` instead if it is on the PATH. It never deletes anything unless it is run with `--apply`.

## Steps

1. Check free space with `df -h ~` so you can report it.
2. Run a dry run: `scripts/freespace`. It walks the home folder and takes one to four minutes, so set a long timeout. Each section prints:
   - lines that start with a size: what `--apply` would remove
   - lines that start with "kept": what it left alone and why
   - `would run:` lines: commands it would run
3. Read the `Total` block at the end. It shows what this run would free, then what each opt-in option would add.
4. Tell the user the current free space and the total. Name the five biggest items, plus anything they may care about, such as `node_modules` in projects they use, git worktrees, virtual environments or Docker images.
5. Ask before removing anything. Only run `--apply` after the user says yes, and use the same options as the dry run: `scripts/freespace --apply`. It prints free space before and after; report that line.

When the user wants only some of it removed, narrow the run instead of deleting by hand: `--only a,b` or `--skip a,b` for sections, `--scan DIR` or `--exclude DIR` for folders. Don't use `--ask`: it prompts on the terminal for each item, and it exits when there is no terminal to answer, as when an agent runs it. Suggest the user run `freespace --ask` themselves if they want to choose item by item. The sections are `claude-tmp`, `go-cache`, `jetbrains`, `packages`, `node`, `rust`, `cpp`, `python`, `docker`, `xcode`, `old-ios` and `worktrees`. `scripts/freespace --help` lists what each one removes.

## Options

| Option | Default | Effect |
|---|---|---|
| `--apply` | off | Remove things instead of listing them |
| `--only a,b`, `--skip a,b` | all sections | Choose sections |
| `--days N` | 2 | Wait before removing Claude Code sessions and merged worktrees |
| `--project-days N` | 14 | Wait before removing a project's `node_modules`, Rust `target/`, C++ builds and virtual environments |
| `--min-ios N` | off | Remove iOS simulator runtimes older than iOS N |
| `--include-unmerged` | off | Remove clean, idle worktrees of unmerged branches, keeping the branches |
| `--docker-all` | off | Also remove unused Docker images, stopped containers and unused networks |
| `--scan DIR`, `--exclude DIR` | home folder | Choose where it searches |

Options in `~/.config/freespace/options` apply on every run. `--apply` is refused there.

## Rules

- Never pass `--apply` without the user's yes for that run.
- Add `--include-unmerged`, `--docker-all`, `--min-ios`, `--days 0` or `--project-days 0` only when the user asks for what that option removes. The `Total` block says how much each one adds, so offer them from there.
- Don't delete by hand anything the script kept. Its rules protect uncommitted work, unmerged branches, running builds, Docker volumes and projects in use. If the user wants something else gone, explain what it is and ask first.

## Reading the results

- `du` over-reports simulator clones, because APFS copies share disk blocks. Trust the before and after free space, not folder sizes.
- macOS removes deleted simulator runtimes in the background, and Docker Desktop and OrbStack return space slowly. Free space can keep rising for a few minutes after a run.
- The Go build cache can refill by hundreds of gigabytes in days. If it is the biggest item, suggest running `scripts/freespace --only go-cache --apply` regularly.
- macOS counts caches, developer files, simulators and Docker disk images as System Data in Storage settings, which is why that number shrinks after a run.
