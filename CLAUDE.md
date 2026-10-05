# Windrose Cheat Menu

UE4SS Lua mod for Windrose (Steam AppID 3041230): per-feature player, ship and building cheats driven from the in-game `wcm` console command. **Public repo.** README.md covers features, install and usage; CHANGELOG.md the release history.

## Layout

- `WindroseCheatMenu/` is the mod folder exactly as it ships (`enabled.txt`, `Scripts/*.lua`).
- `scripts/publish-release.ps1` publishes a GitHub Release.
- `dist/` holds built zips and is git-ignored; zips go on GitHub Releases, never in git.

## Status

v0.1.1 released (2026-05-14). `party_buff` and `wcm dumpfields` are committed under `[Unreleased]` in CHANGELOG.md but **untested in-game**. Next step: test both in Windrose (party_buff needs a hosted multiplayer session), then release v0.1.2.

## Testing

Only possible on a Windows machine with Windrose and UE4SS installed (see README "Requirements" and "Installation"): copy `WindroseCheatMenu/` into `<Windrose>\R5\Binaries\Win64\ue4ss\Mods\`, launch, open the F10 console and run `wcm`. Results are in `UE4SS.log`. There are no automated tests. **Cloud agents can only edit the Lua and docs;** say so in the changelog when a change has not been tested in-game.

## Releasing

1. Move the `[Unreleased]` notes in CHANGELOG.md under `## [x.y.z] — <date>` (the script pulls the release notes from that heading).
2. Commit, then `git tag -a vx.y.z -m "vx.y.z release"` and `git push origin main vx.y.z`.
3. `.\scripts\publish-release.ps1 -Version x.y.z` (PowerShell, needs `gh` authenticated). It zips `WindroseCheatMenu/` into `dist\WindroseCheatMenu-x.y.z.zip` if missing (`-Force` rebuilds), then creates or updates the GitHub Release for the tag and attaches the zip. `-Draft` makes a draft release.

<!-- cloud-sync:start -->
## The remote is the source of truth

- GitHub (`origin`) holds the truth. Local work may replace it only when it was made on top of its latest.
- Fetch before changing anything. If this copy is behind, bring it up to date first (fast-forward, or rebase your own commits onto origin). Never force-push, and never overwrite a remote change you have not seen.
- If the remote moved and the work cannot be brought on top of it cleanly, stop and ask.
- Push what you commit as soon as it is ready (in a cloud session: to your working branch).
<!-- cloud-sync:end -->
