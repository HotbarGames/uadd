# Lessons index

Only this index loads by itself. Full lessons (bug, rule, check): 1-11 and "Before a new addon" in
`docs/LESSONS.md`, 12-27 in `LESSONS2.md`, 28-39 in `LESSONS3.md`, 40-47 in `LESSONS4.md`, 48 in `LESSONS5.md`.
Read lesson 18: `awk '/^## /{p=/^## 18\./}p' docs/LESSONS*.md`. A `+`: more cases in later files:
`grep -n -A14 'Lesson 18 again' docs/LESSONS*.md`.

**Must read.** You write or review module code (Lua of `UADD/` or `UADD_*/`, not only words): first read all five
files in full, file by file (again after a compaction); this index is not enough (2026-11-25: partial reads missed faults). Harness and flows: lessons 2, 18, 21, 32, 45. Words: 4, 5, 7, 9. Anything else: the `*`
lessons of its group, with their `+` cases.
A: checked in any module. P: in some, or once you register yours. N: no check.

A new kind of problem: a lesson (newest file with room), a check and its line here, in the fix's commit.

## Fonts and drawing
- 2* P Read a font back from the text; SetFont's return says nothing. Cover windows made later (scan on first open), nameless option pages (by content), tables that copied `L.` words at load.
- 5 P Text in a button, column or shared row: no longer than the English; shorten words, never the font or its scale. Measured only in Auctionator headers, LayerSwap, DCI, TomTom, BugSack: measure yours.
- 18*+ A Put an old font back only with U.SaveFont/U.FontBack (the object). By path only for a label U.CyrOnOwn set by hand, never a game tooltip line.
- 32*+ A Our text on an addon's label (it inherits its template's font): UADD's font on, kept over SetFont, SetFontObject. A button: U.ButtonCyr (UADD/ButtonFont.lua, lesson 46). Never save a font while ours is on; give it back off and held.
- 33* P Game menu checkbox, dropdown: add our initializer that sets button.fontString. Test what is drawn, not what is stored.
- 38* P Game menu row (MenuUtil): reading SetFont or CreateFontString on it throws. U.Locked, U.CyrOnLocked, read back; else its own object and English.
- 44* P Label whose font the addon set by hand: our font object first; when it did not take, U.CyrOnOwn (its own size), read back. Text box: its hint only, never typed text. Line "- Name": keep.
- 45* A Cyrillic is always in a Cyrillic font. Going back: English first, then the old font (U.CyrFix/CyrUnfix), through the setter the addon uses. The check sees only what flows show. Mutant clients set H.boxQuiet.
- 46* A On hover, press or greyed out the client puts the state's font object on a button's label: our Cyrillic in every state (U.ButtonCyr/U.ButtonBack), whole or nothing; protected buttons stay English. U.CyrFix false: English first. BoxGuard gives up to whole English (U.BoxGiveUp). Checks: boxes.lua state rule, flow_button.py.
- 47* A A saved font object goes back only by U.SetFontObject (U.SafeFontObject): an edit box's own record loops.

## Hooks and game-wide state
- 12* A Hook on all chat, tooltips or frames: leave first by the cheapest test, before Translate or debugstack. Each-frame hook: each frame keeps its own last English and Ukrainian.
- 16 A Never CreateFrame an EditBox, a kind from a variable, or a shown throwaway: UADD.WidgetMethods(kind).
- 19*+ A Hooks run under U.Safe (5 errors turn the module off); fonts, keyboard, chat, tooltips, walks only through core helpers. A hook that gives English back or must work after off-for-errors: plain pcall + U.ReportError + U.Fault + ns.On(), not Safe.
- 21 A New module: a recipe in chaos_mods.py in the same commit; it must survive odd values, off/on x100, combat, its own errors. Never call geterrorhandler().
- 22+ A No pattern with two `.-`/`.*` over a line: find(s, mark, 1, true). A path that may answer "wait" must be cheap uncached. Time limits through clock.py.
- 23*+ P Going off: put English back only while the text is still ours, never over what the addon wrote since. Text drawn once keeps its key: two keys may share one Ukrainian.
- 26* P The addon's own SetText may draw, then throw: read back, U.Fault each error, write English to the font string if its setter fails.
- 28* P Another Ukrainian addon hooks the same text: on hold show the addon's last English, whole, inside their call. UADD off: leave their line.
- 35* A Chat U.ChatHook, print U.PrintHook, frames U.OnNewFrame/OnNewFontString. U.Plain before a string op; U.GameMade: leave. A new-frame handler or its timer: no scan in combat. Gate by whole-line hash, not length. Wraps off in instances.
- 36 P Redraw, walk, popup work: never in combat; core Tell or U.AfterCombat, once, with the final state.
- 37 P Code that installs and undoes: install only while ns.On(). Test that after off the addon's own function is back (same function).
- 39 P A guard against boxes or dead keys goes in always, on or off; its error gives the addon's own output. Beware code taking the first byte of a Cyrillic name.
- 48+ P Kept hidden pages fill the 4000-frame walk: skip hidden ones, walk on OnShow.

## Finding and matching texts
- 1*+ P List every English text shown, also code-built and game globals (ADD, YES): start with scan_addon.py. Never write a global; swap only English, on the addon's own frames. Popups and their buttons: U.Popups.Register; Sushi's: SushiPopups.
- 6* P Glued line (name + level, count, zone, colour): the whole line is ours: split, ask each name; one unknown = whole English. Each template needs a flow with a real glued line. Never ship "•".
- 7*+ P A free slot holds one name; never a colour code, number, clock or glue-only template. New joiner: SEPS, wider first. Whole-line module: glue=True in halves_mods.
- 13* P Player's own text (profile, group, note) stays as typed, in lists and labels too; know it by its source, never by its words.
- 14*+ P Word the addon saves or compares stays English (STAY). Saved and shown: wrap the saving call so its English is back for it. Search its setters and saved tables.
- 15*+ P Words set once (at load, registered, in a closure): switch them both ways on on/off/hold, or rebuild. A slot the addon fills with its own English: whole line English unless that text is ours. Our word beside a game global: only while that is Cyrillic. After updates look for new `..` around L.
- 27* P Our word glued into a line that may stay English: put its English back first, also off and held.
- 30 P Settings sub-pages: by subcategories/parentCategory links, never by name; rename only while it holds ours or its English.
- 31* P Cell of our word + player name, note, money, age: a reader per cell kind swaps only our parts; one missing = whole English.
- 34*+ P Map/quest API English is a game name: U.Place / UADD.UALL.Quest, only if it equals the waypoint/map chain or tracked quest. Never keep "wait". Fix every addon showing it.

## Words and game names
- 3 N Read UALL Forever's Settings.lua (addons.*) and its *Hooks.lua first and at each of its versions: leave its parts out, use its words. Grep UALLF and ClassicUA before naming; note the version.
- 4 A Word decided against: BANNED in test_banned_words.py, right word in the glossary, same commit.
- 8 P The owner picks a word: same turn glossary (owner, date), a GLOSSARY.md row if needed, ban the old one.
- 9* P Never write a game name (item, spell, NPC, zone, quest, event) or leave it Latin in Ukrainian: ClassicUA's, then UALLF's, else say it without or whole English. Checked in 7 modules (game_names_src.py): add yours or read each capital.
- 17 A Glossary profession, rank, trainer, weapon: UALLF's exact word, else its pattern; ban the old.
- 20 A Game names only through UADD.UALL routes; stubs patch UADD.UALL; list the module in SHOWS (test_uall_routes).
- 25* A ClassicUA first, then UALLF. Never ask text with [ ( | a line break or edge spaces. Both in every TOC's OptionalDeps.
- 40* A Saved name cache: sign it with ProviderSig(); never save partial or unsaved; ask nothing before ClassicUA settles. Objective lines: UADD.UALL.Item, else as is.
- 43* P Never translate What's New, News, changelog windows; no hook there, skip in extractors. Ours: the button that opens it, a one-line notice (KEEP in news_texts.py).

## Generator, checks, records
- 10 A Checks read untracked files too; local-only files go in .gitignore.
- 11 A Each record in addon_versions.json has a version (VERSION_FROM). Owner's steps: only what the real client shows.
- 29 A A new Lua file goes in the TOC in the same change; a test that reads by path also checks the TOC.
- 41+ A Faster check: same checks, same order; a dead job is a FAIL with its repro; keep the old code as reference.
- 42* P --update-versions never hides new texts (--module only for texts left English on purpose). Extractor: every place shown (not news), keys as shown (\n, \\).

## New addon and release
- Before a new addon*: do that list first (`docs/LESSONS.md`).
- 24 A Module by its TOC Title in README, core TOC Notes, curseforge-description.md + Thanks; no "coming next". A release pastes the page when it changed and stamps it.
