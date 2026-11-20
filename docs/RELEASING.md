# Releasing a new version

A version tag (`v1.0.1`, ...) runs `.github/workflows/release.yml`. It builds one zip with all the folders
(`UADD` and its modules) from `.pkgmeta`, uploads it to CurseForge (project 1807250, game type Forever, game
versions from the TOC's `## Interface`) and makes a GitHub release with it.

The project ID is in `UADD/UADD.toc` (`## X-Curse-Project-ID: 1807250`). The upload also needs the repository
secret `CF_API_TOKEN` (CurseForge > My Profile > API Tokens; one token works for all projects of the account) and
GitHub Actions turned on for this repo. Actions are off for now, so a version is uploaded by hand: build the zip
with `python3 tools/make_zip.py` and upload `dist/UADD-<version>.zip` on the project's Files page.

## Steps

0. The owner checks it in the game first (owner, 2026-11-20). Install the build, then give the owner a short
   list of what to look at. Put on it only what no check proves: `check_repo.py`, the unit tests, the harness
   and the review already prove the rest, so leave that off. No upload until the owner says it works. A fix
   for a reported problem goes the same way: the owner checks the fix.
1. If Blizzard changed Forever's interface number (in game: `/dump select(4, GetBuildInfo())`), test the addon on
   the new client and add the number in front in all TOCs: `## Interface: 16002, 16001, 16000`.
2. `python3 tools/bump_version.py <version>`: it sets `## Version` in all TOCs (`UADD/UADD.toc` and each
   `UADD_*/UADD_*.toc`; the repo check fails if they differ) and renames `## Unreleased` in
   `UADD/CHANGELOG.md` to the version.
3. If Questie changed: `python3 tools/extract_questie_keys.py --out data/questie-keys.json`, then
   `python3 tools/coverage.py --list missing` shows the new strings to translate.
4. `python3 -m unittest discover -s tools`, commit, push to `main`.
5. Optional dry run (uploads nothing): Actions > release > Run workflow, or `gh workflow run release.yml`. Its log
   lists what the zip contains.
6. Tag and push: `git tag v1.0.1 && git push origin v1.0.1`, then `gh run watch`.

While Actions are off, steps 5 and 6 do nothing. Instead, `python3 tools/make_zip.py` builds the same zip into
`dist/`; upload it on the project's Files page: release type Release, game version Forever (as the TOC's
`## Interface`), the new `UADD/CHANGELOG.md` section as the changelog.

Relations: only UALL Forever, as an Optional Dependency (owner, 2026-11-20). The addons we translate are not
listed: a player needs none of them for UADD, and the list would grow with every module. The project's Default
Relations (project settings) hold only UALL Forever, so a new file gets it by itself; check it on the file's
edit page after the upload.
