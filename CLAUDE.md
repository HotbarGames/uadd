# UADD

## Other addons' texts

**Rule.** Never commit another addon's text or code in bulk unless its licence allows it.

- Not allowed (all rights reserved): Auctionator (LICENSE: All Rights Reserved), Attune, DialogueUI,
  ForeverXPbar, ForeverDungeonJournal (no licence file).
- Allowed: Questie (GPL-3.0), OpenMap (MIT; its notice must go with copies). See `THIRD-PARTY-NOTICES.md`.

For the not-allowed ones:

- Our data keeps only our Ukrainian, keyed by the addon's own locale key or by a hash of the English.
- Read the English from the installed addon at build or test time. Never commit it; write files made from it
  to a git-ignored place (add the path to `.gitignore`).
- No English of theirs in comments.
- `tools/harness/` stand-ins may use a few short real labels (the check allows 10 per file), not bulk.

**Why.** This repo is public. A bulk copy of an all-rights-reserved addon breaks its authors' rights, and
CurseForge can pull the whole project for it.

**How to check.** `python3 tools/check_repo.py` (the pre-push hook runs it). Lines that start with `[copy]`
are this rule. It reads the installed addons (their `.lua` and `.xml`) from the WoW `_forever_` AddOns
folder, or from `$UADD_ADDONS_DIR`; one that is not installed is a note, not a problem. It checks tracked
files and untracked ones git does not ignore. It counts their sentences (any file outside `tools/harness/`:
none; one harness file: 10; all harness files together: 20) and their short labels ("Buy Now"), which fail
only in bulk (a limit per addon, per file). The scan is cached in `tools/.cache/` (git-ignored) until a file
it reads changes; delete it to force a fresh scan. Thresholds: `tools/copy_check.py`; what counts as a
sentence or a label, and the scan itself: `tools/copy_scan.py`.
