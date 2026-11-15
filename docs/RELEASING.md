# Releasing a new version

A version tag (`v1.0.1`, ...) runs `.github/workflows/release.yml`. It builds one zip with both folders (`UADD` and
`UADD_Questie`) from `.pkgmeta` and makes a GitHub release with it.

There is no CurseForge project yet. Until `UADD/UADD.toc` has `## X-Curse-Project-ID: <id>`, nothing is uploaded to
CurseForge. To start uploading: create the project on CurseForge (game type Forever), add that line to the TOC, and
add the repository secret `CF_API_TOKEN` (CurseForge > My Profile > API Tokens).

## Steps

1. If Blizzard changed Forever's interface number (in game: `/dump select(4, GetBuildInfo())`), test the addon on
   the new client and add the number in front in both TOCs: `## Interface: 16002, 16001, 16000`.
2. Bump `## Version` in `UADD/UADD.toc` and `UADD_Questie/UADD_Questie.toc` (the repo check fails if they
   differ) and add a section on top of `UADD/CHANGELOG.md`.
3. If Questie changed: `python3 tools/extract_questie_keys.py --out data/questie-keys.json`, then
   `python3 tools/coverage.py --list missing` shows the new strings to translate.
4. `python3 -m unittest discover -s tools`, commit, push to `main`.
5. Optional dry run (uploads nothing): Actions > release > Run workflow, or `gh workflow run release.yml`. Its log
   lists what the zip contains.
6. Tag and push: `git tag v1.0.1 && git push origin v1.0.1`, then `gh run watch`.

`python3 tools/make_zip.py` builds the same zip by hand into `dist/`.
