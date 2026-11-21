# Lessons, part 3

Lessons 28 and up, and new cases of older lessons that no longer fit in parts 1 and 2. The rules for this list
and "Before a new addon" are in `docs/LESSONS.md`.

## More cases of older lessons

**Lesson 1 again, in LiteMount (2026-11-21).** The Rules and Falling page names, the buttons (Add, Delete, Revert,
Defaults, ...), "Key Binding n" in two dropdowns, and the rule conditions (Instance, Level, Map, Falling) stayed
English (the owner's shots). LiteMount takes them from the game's globals (`ADD`, `KEY_BINDING`, ...), not from its
L, and ClassicUA alone leaves those globals English. Rule: grep the addon for game globals it shows on its own
frames; each one is ours there while the global is English, English while held and off, and the global itself is
never written (another addon reads it too). A global already Cyrillic is left as it is. Check:
`python3 tools/harness/run.py`, LiteMount's steps `gpages`, `gbuttons`, `gbind`, `gconds`, `gcyr`
(`tools/harness/flow_litemount_globals.py`) and their mutants.

**Lesson 1 again, in Auctionator's popups (2026-11-21).** The «Продаж» question had Ukrainian text but English
buttons. Auctionator puts the game's `ACCEPT` and `CANCEL` globals on its popups, and ClassicUA alone leaves them
English. Our Words.lua had even kept those two words English on purpose. The bid question was missed too: its name
is in mixed case, and we looked only for names in capitals. Rule: the button fields of Auctionator's own popups
(any name that starts with "Auctionator", in any case) hold our word while the global is English, and the English
again while held and off; a shown popup flips both ways. The globals are never written. A global that is already
Cyrillic is left as it is. The logic is now the core helper `UADD/Popups.lua`, and every module whose addon has
StaticPopupDialogs uses it (Auctionator, LiteMount, TomTom, Forever Quest Pins, Attune, and Dungeon Journal and
ForeverXP Bar for the game's YES and NO, 2026-11-21). Check:
`python3 tools/harness/run.py`, the "pop:" steps 1-8 (`tools/harness/flow_auc_popup.py`; its mutants `fields`,
`prefix`, `shown`, `restore`, `rescan`, `ours`, `cyr` and `words` each take one fix out and want their step to
fail) and the "pops:" steps (`tools/harness/flow_popups.py`, each module and its mutants; step 8: a popup shown in
combat has no record, yet its buttons go English on the hold key and off, mutant `unrecorded`);
`python3 -m unittest tools.test_popups` (each installed addon's dialog with a game global or an L word on a
button is registered, or in its ALLOW with a reason).

**Lesson 1 again, in Bagnon and Scrap's popups (2026-11-21).** Their questions (delete a character's data, destroy
junk, reset settings) had Ukrainian text but English buttons. Both put the game's OKAY, CANCEL, YES, NO, ACCEPT (and
UNLOCK, CHAT_LEAVE in the vault) on popups of the Sushi-3.2 library. That library is shared: one Popup class and one
frame pool for every addon that carries it, so a hook on it sees other addons' popups too. Rule: a popup is the
addon's only when the first stack line outside libs/ and UADD is in the module's OWNERS folders. Its buttons show our
word only while they hold the global's English, and English while held and off. A body flips only as a whole L text.
Globals are never written, and one already Cyrillic is left. A released frame is forgotten, so the pool never carries
our words to another addon. The logic is now the core helper `UADD/SushiPopups.lua`. Check:
`python3 tools/harness/run.py`, the "pop: sushi:" steps 1-6
(`tools/harness/flow_sushi_popup.py`) and its mutants fields, shown, owner, cyr, release, seen, body, sync;
`python3 -m unittest tools.test_sushi_popups` fails on a popup of the installed addons whose global or body is not
handled and not in ALLOW.

**Lesson 19 again, in LiteMount (2026-11-21).** Its SetText hooks (the macro count, rows, the mount list, the
Falling page) ran under `U.Safe`. After 5 errors the module went off, and `U.Safe` stays dead for the session, so
after "/uadd litemount on" the count was ours once and then English again. Rule: a hook that must work again after
"on" runs under `Lc.Guard` (pcall, `U.ReportError`, `U.Fault`) and checks `ns.WordsWanted()` itself, not Safe's off
flag. Check: `CHAOS_ONLY=UADD_LiteMount python3 tools/harness/chaos.py` (off for errors, then on). TomTom's title
and Forever Quest Pins' breadcrumb hooks have the same shape: not fixed yet.

**Lesson 22 again, time bounds under load (2026-11-21).** Other projects' tests kept the PC's load at 12-50 on 8
cores. Then Mastercraft's half-translation time (5.2-8.5 ms) and the orders 10 KB line failed "under 5 ms" on fine
code: even CPU time grows when cores are shared. Rule: a time bound is measured against a reference job run in the
same check (`tools/harness/clock.py`: fixed Lua string work). The bound is 5 ms times the reference's slowdown, never
under 5 ms and never over 8 times. The slow pattern takes 280-460 ms, so it still fails by far. Check:
`python3 -m unittest tools.test_halves` (`test_slow_fails`: a CPU busy-loop past the cap; `test_bound_follows_load`);
`python3 tools/harness/chaos.py` with lesson 22's old pattern put back still fails "Mastercraft 10 KB under 5 ms".

## 28. Another addon's hook that writes over ours

**What went wrong.** With ClassicUA on, the OpenMap zone title on the World Map stayed Ukrainian while Shift was
held (the owner, 2026-11-21). ClassicUA hooks the same text's `SetText` and writes its own word over OpenMap's line
(«Терниста долина(30-45)») on every call. It does not know our hold key. Our hook only put back the English it had
swapped itself, so it never saw ClassicUA's line.

**Rule.** Where another Ukrainian addon hooks the same text, the hold key still shows the addon's whole English:
keep the addon's last English, and when the text shows another addon's Ukrainian over it, put that English back
(inside their call, where their own flag keeps them out). With UADD off, leave their line alone, as without UADD.

**Check.** `python3 tools/harness/run.py`, "map label with ClassicUA's hook" steps
(`tools/harness/flow_openmap_label.py`, a stand-in of ClassicUA's hook put on after ours). Manual, in the game:
the real hook order, and no flicker while Shift is held.

## 29. A strings file the game never loads

**What went wrong.** Dungeon Journal 2.1.2 got three new strings files (`ui/strings_rpg.lua`, `strings_runlog.lua`,
`strings_tier.lua`). Our tests read every `ui/strings*.lua` by path and passed, but the TOC did not list them, so
in the game their words would have stayed English.

**Rule.** A new Lua file in a module goes into its TOC in the same change. A test that reads files by path must
also check that the TOC loads them.

**Check.** `python3 -m unittest tools.test_dj_strings` (`test_every_strings_file_loads`).

## 30. Another addon's settings pages found by their names

**What went wrong.** Forever Quest Pins 1.1.1 put five settings pages under its main one. Their names are common
words ("Interface", "Navigation"): a search by name could find the game's own pages or another addon's, and our
words would land there. The names in the settings tree are also set from L when the pages load, before our words
come in, so they stayed English.

**Rule.** Find an addon's sub-pages through its main page's links (`subcategories`, `parentCategory`), never by
their names. Rename a page in the tree only while it holds our word or its English, both ways.

**Check.** `python3 tools/harness/run.py`, "fqp: 6 settings tree" (`tools/harness/flow_fqp.py`; the stand-in in
`flow_fqp_pages.lua` gives a game page the same name); the mutants `pages` and `rename` take each fix out.

## 31. Raw cells that glue our words to a player's name

**What went wrong.** Mastercraft 2.0.8's craft orders board sets every cell as one raw string, built in code: our
word glued to a buyer's name, a note in quotes, money or an age ("Buyer: <name>", "1 h 20 min"). No cell matched a
whole text of ours, so the board stayed English.

**Rule.** Where the addon glues our words to other text in code, give each kind of cell a reader that knows its
layout (`mcWords` in `UADD_Mastercraft/Raw.lua`): it swaps only the parts that are ours, keeps the name, note and
money as they are, and leaves the whole cell English when one part is missing.

**Check.** `python3 tools/harness/run.py`, the "orders:" steps (`tools/harness/flow_mc_orders.py`): each card and
row, a player named like our word, odd input, and a 10 KB line in under 5 ms.

## 32. A button label that inherits a font without Cyrillic

**What went wrong.** LiteMount's Profiles buttons showed boxes for our words (the owner's shots, 2026-11-21). Their
template's label inherits GameFontNormal, and on Forever that font object has no Ukrainian letters. Our text was
right; the font under it was not. The harness never looked at the font a text is drawn in, so nothing failed.

**Rule.** A text we put on another addon's frame is drawn in a font with Cyrillic: set UADD's font on it, keep it when
the addon sets its font object again (hook `SetFont` and `SetFontObject`), and give the addon's font back when off
(`UADD_LiteMount/Fonts.lua`). Look at the template, not only at the text: a button's label inherits its font.

**Check.** `python3 tools/harness/run.py`, "litemount: 9 no Cyrillic in a font without it"
(`tools/harness/flow_litemount_shots.py`, `H.cyrBoxes`): no LiteMount line shows Cyrillic in a font without it, on,
held and released; its mutant `sfont` takes the font fix out and wants that step to fail.

## 33. A menu checkbox that draws its text in its own initializer

**What went wrong.** Forever Quest Pins' World Map menu stayed English (the owner's shots, 2026-11-21). The game's
menu checkbox draws its label in its own initializer, from the text it got when it was made. We changed the
element's text with `SetElementText`, but nothing on screen read it again. Our stand-in menu never drew through
initializers, so the harness saw our word and passed.

**Rule.** For a client menu, add our own initializer that sets the font string the button draws
(`button.fontString`, `Drawer` in `UADD_ForeverQuestPins/Menu.lua`). The stand-in draws through the initializers
too (`HARNESS.menuApi` in `tools/harness/wow_frames2.lua`), so a test reads what is drawn, not what is stored.

**Check.** `python3 tools/harness/run.py`, "fqp: 2 World Map menu" (`tools/harness/flow_fqp.lua`, `M.menu()` reads
the drawn text); its mutant `draw` takes our initializer out and wants that step to fail.

## 34. A game name the addon builds from the map API

**What went wrong.** Waypoint UI showed zone names in English (the owner's shots, 2026-11-21). The name comes from
`C_Map.GetMapInfo().name`, which is English on Forever. It travels from an OpenMap pin with no note, through
TomTom, into Waypoint UI's info text and pinpoint. No locale table holds it, so the map stage never listed it.

**Rule.** Tell such a name apart by its source: Latin text of at most 120 bytes that equals the waypoint's map, the
player's map, or a map up to 5 levels above (`ns.Place` in `UADD_WaypointUI/Words.lua`). Translate it through
`UADD.UALL.Zone`; we write no game names. Never cache a "wait" answer, and try again later (every 3 s, at most 10
times). In the map stage, follow each shown text back to its source, not only to the locale table.

**Check.** `python3 tools/harness/run.py`, "wp: 13" (`tools/harness/flow_wp_steps.py`, `M.place` in
`tools/harness/flow_wp.lua`) and its mutants `place`, `pinplace`, `wait`; `python3 -m unittest
tools.test_uall_routes` (`UADD_WaypointUI` asks the Zone route).

**Lesson 34 again, in TomTom (2026-11-21).** TomTom's arrow showed "Tirisfal Glades" in English (the owner's shots).
OpenMap gives TomTom the map's English name as the title of a pin with no note. We had fixed it only in Waypoint UI.
Rule: a title an addon builds from the map API is a game name wherever it travels. Every module that shows a
waypoint title asks for it through the core helper `U.Place` (`UADD/Place.lua`), only for the waypoint's or the
player's map chain, through `UADD.UALL.Zone`. A hook that runs every frame keeps its last answer; it never keeps a
"wait". When one fix fits several addons, follow the text to every addon that shows it. Check:
`python3 tools/harness/run.py`, "tt: place 1-6" (`tools/harness/flow_tomtom_place.py`); its mutants `hook`, `map`,
`cache`, `wait`, `back` and `tip` each take one fix out and want their step to fail. Also "wp: 13".
