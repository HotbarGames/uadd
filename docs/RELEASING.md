# Releasing a new version

A version tag (`v1.0.1`, ...) runs `.github/workflows/release.yml`. It builds one zip with all the folders
(`UADD` and its modules) from `.pkgmeta`, uploads it to CurseForge (project 1807250, game type Forever, game
versions from the TOC's `## Interface`) and makes a GitHub release with it.

The project ID is in `UADD/UADD.toc` (`## X-Curse-Project-ID: 1807250`). The upload also needs the repository
secret `CF_API_TOKEN` (CurseForge > My Profile > API Tokens; one token works for all projects of the account) and
GitHub Actions turned on for this repo. Actions are off for now, so a version is uploaded by hand: build the zip
with `python3 tools/make_zip.py` and upload `dist/UADD-<version>.zip` on the project's Files page.

## Steps

**No release while one case of boxes instead of letters is not fixed (owner, 2026-11-26; very important).**
`docs/OPEN-BOXES.md` lists them; `bump_version.py`, `make_zip.py` and the release workflow refuse until it is empty.

0. The owner checks it in the game first (owner, 2026-11-20). Install the build, then give the owner a short
   list of what to look at. Put on it only what no check proves: `check_repo.py`, the unit tests, the harness
   and the review already prove the rest, so leave that off. No upload until the owner says it works. A fix
   for a reported problem goes the same way: the owner checks the fix. A new addon may ship with some words
   still in English, but not before at least one owner check of it (owner, 2026-11-26). Give full commands.
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

Description: the project page's text is `docs/curseforge-description.md`, pasted by hand (the upload cannot change
it). `python3 tools/make_zip.py` says when it changed since the last paste. Then paste it on
https://authors.curseforge.com/#/projects/1807250/description (Markdown), press Save, run
`python3 tools/listing.py --pasted` and commit `tools/cf_description.sha256`. Save stays greyed out until a key is
typed in the box; check it saved by opening the page fresh. CurseForge rewrites the Markdown a little on save
(bullets as `*`, lines of one paragraph joined); the page looks the same. A new module is added to that file
when it is registered (`python3 -m unittest tools.test_listing` fails until it is), and describes only what players
can download, so paste it with the release that ships the module.

Relations: UALL Forever and ClassicUA, both as Optional Dependency (owner, 2026-11-20). The addons we translate
are not listed: a player needs none of them for UADD, and the list would grow with every module. The project's
Default Relations (project settings) hold just these two, so a new file gets them by itself; check it on the
file's edit page after the upload.
