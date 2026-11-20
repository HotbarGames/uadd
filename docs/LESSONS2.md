# Lessons, part 2

Lessons 12 and up: how a module's code behaves in the game (hooks, the player's own text, saved data, on and
off, widgets). Part 1, with the rules for this list and "Before a new addon", is `docs/LESSONS.md`.

## 12. A hook on a game-wide path that translates first and asks later

**What went wrong.** The review of the new TomTom module (2026-11-19) found three hooks that ran for the
whole game, not only for TomTom:

- The shared chat hook (`UADD/Lines.lua`, `ChatLines` without a prefix) sent every chat line of the game to
  `Translate`, and only then asked if TomTom wrote it. Each line of other addons and of the game cost a
  lookup and a cache entry. What's Training? uses the same hook.
- The arrow's distance hook ran `Translate` on every frame, though the text is mostly the same.
- The tooltip hook ran `debugstack` on every `GameTooltip:Show` of the game (a unit, a spell, a button).

**Rule.** A hook on a path the whole game uses (all chat, every tooltip, every frame) leaves first for text
that is not the addon's, with the cheapest test first (the source, a compare with the last text, "is there
a line to fix at all"), before any translate work or `debugstack`. A hook that runs every frame keeps the
last English and its Ukrainian and does no lookup when the text did not change.

**Check.** `python3 tools/harness/run.py`, TomTom's "review 2", "review 3" and "review 4"
(`tools/harness/flow_tomtom_review.py`): a chat line of other code makes no `Translate` call and does not
grow the Words cache (`W.CacheSize`); the arrow with the same text for 50 frames calls `Translate` once; a
unit's tooltip runs no `debugstack`. Each fails with its fix taken out.

## 13. The player's own names inside the addon's list

**What went wrong.** In the same review: TomTom's profile dropdown lists the profiles the player named, and the
module translated every entry, so a profile named like one of TomTom's texts showed our Ukrainian. Pawn
(2026-11-20): the window scan changed the label that shows the chosen scale's name the same way, both ways.

**Rule.** Text the player wrote stays as typed, also in a list, menu or label the addon builds. Tell it apart by
where it comes from (TomTom: the `TOMTOM_PROFILE_*` settings; Pawn: `PawnUIFrame_ScaleNameLabel`, unless it
shows Pawn's own "no scale" text), never by what the name says.

**Check.** `python3 tools/harness/run.py`: TomTom's "review 1" (also: the installed TomTom still names its
profile settings that way) and Pawn's "4 lesson 13" step.

## 14. The addon's own text saved into the player's data

**What went wrong.** RareScanner (2026-11-20) names the first custom NPC group and the first custom item group
with its locale texts and saves the names in the player's data. Our draft translated both: the Ukrainian name
would stay saved with the module off, and would no longer match the text RareScanner compares it with.

**Rule.** A locale text the addon writes into its saved data stays English (the module's STAY list). Before
translating, search the addon's code for locale texts passed to its database setters or saved tables.

**Check.** `python3 -m unittest tools.test_rs_text` (`SavedData`) finds such texts in the installed RareScanner, also
over a call that spans lines and through a variable saved later (the "treasure" text as a nameless container's name,
now in STAY); each must be in STAY (`tools/rs_rules.py`). `python3 tools/harness/run.py` ("1 STAY keys") keeps them
English. Other modules: manual, read the addon's saves.

## 15. Words set after load, and slots the addon fills with its own English

**What went wrong.** The RareScanner review (2026-11-20): the explorer's labels, set when it first opens, and a page
built by a function that keeps what it built, kept our Ukrainian with the module off. A slot holding a time ("1h 5m",
in RareScanner's English units) or another of its texts made half lines.

**Rule.** Words set once are switched both ways on every on/off and on the hold key, or built with the English in.
A line whose slot the addon fills with its own English stays English unless that text is ours (`u`, `INNER`).

**Check.** `python3 tools/harness/run.py`, RareScanner steps "5" and "7"; `python3 -m unittest tools.test_rs_text`
(`Slots`: `u` and `INNER` in `tools/rs_rules.py` match the installed code). Each fails with its fix taken out.

## 16. A throwaway text box that took the keyboard

**What went wrong.** With UADD on, the keyboard was dead: Enter did not open chat (the owner, in the game,
2026-11-20). Mastercraft's and What's Training?'s `S.Install()` made one frame of each widget kind, an EditBox
too, only to reach the kind's methods and hook `CreateFontString`. A new EditBox is shown and has autoFocus on,
so it took the keyboard for good. The other throwaway frames were left shown too. The harness had no keyboard
focus, so nothing failed.

**Rule.** Never make an EditBox, or any shown throwaway widget, to reach a widget kind's methods. Use the core
helper `UADD.WidgetMethods(kind)` (`UADD/Widgets.lua`): it takes an EditBox's methods from one the game already
has (the chat edit box), and makes other kinds once, hidden at once.

**Check.** `python3 -m unittest tools.test_no_editbox`: no `CreateFrame` in the files a `UADD*/*.toc` loads has
the kind "EditBox" or a kind that is not a string (also through `pcall`), outside the helper.
`python3 tools/harness/run.py`, step "focus: keyboard free after login" (`tools/harness/flow_focus.py`): every
stand-in and the modules that load with them, and after login `GetCurrentKeyBoardFocus()` is nil. The harness
EditBox has autoFocus on, as in the game (`tools/harness/wow_focus.lua`). Each fails with the fix taken out.

## 17. A glossary game word never compared with UALL Forever

**What went wrong.** Mastercraft showed «Здирання шкур» for Skinning, while UALL Forever, which the player sees
everywhere else in the game, says «Білування» (the owner, 2026-11-20). The glossary's profession, rank, trainer
and weapon words were our own picks and nobody had compared them with UALL Forever: 27 of them differed
(«Гірництво» for «Гірнича справа», «Знавець» for «Експерт», «Наставник алхімії» for «Вчитель Алхімії», ...).

**Rule.** A game name in the glossary (a profession, rank, trainer title, weapon skill) is UALL Forever's exact
word. Where it has the word, we use its word. Where it has none, follow its pattern. Ban the old word in the
same commit (`tools/test_banned_words.py`).

**Check.** `python3 -m unittest tools.test_glossary_uallf`: each `prof.*`, `npc.*` and `weapon.*` entry in
`UADD/glossary/professions.lua` whose English UALL Forever has (UI, spells, NPC titles) uses one of its words
(case aside), or is in `ALLOW` with a reason. It skips with a message when UALL Forever is not installed.
It finds the 27 with the fix taken out.

## 18. A font put back by its file

**What went wrong.** After a while, item and spell tooltips showed boxes until /reload (the owner, 2026-11-20).
One bag item's tooltip did it right after /reload: lines 1-3 were fine, line 4 and on were boxes, with
Mastercraft's lines at the bottom. UADD put a tooltip line's old font back with `SetFont(path)`. GetFont reports
only FRIZQT__.TTF, but the line's font object (GameTooltipText, GameTooltipHeaderText) is a family with a
Cyrillic file. SetFont pinned the line to the Latin file, so UALL Forever's Ukrainian on the next fill drew as
boxes. Bag tooltips fill again on a timer and on BAG_UPDATE, so one clear was enough. TomTom's arrow title
(made from GameFontHighlightSmall) showed boxes the same way after `/uadd tomtom off`.

**Rule.** Save a line's font with `UADD.SaveFont(fs)` and put it back with `UADD.FontBack(fs, was)`: SetFontObject
with the saved object, every time, keeping the line's colour and justify. SetFont only when the line had no
object, or when a font had been set on it by hand before ours. Never put a font back by its path.

**Check.** `python3 tools/harness/run.py`: after every segment, "tooltip font object back after clear: <key>"
(`tools/harness/tipfont.py`, `wow_fontfam.lua`: the harness fonts are families, as in the game); Mastercraft's
"item tooltip filled again" step; "tt: arrow A" (`tools/harness/flow_tomtom_arrow.py --prove`).
`python3 -m unittest tools.test_shared_state` lists every SetFont in module code against an allowed count.

## 19. One module's bug that could break the whole game

**What went wrong.** Lessons 16 and 18 each broke the whole game (a dead keyboard, boxes in every tooltip) from
one module's file. A wider review (2026-11-20) also found that a module that kept throwing errors stayed on, the
error list grew without end, and a few hooks did work for every chat line and tooltip of the game.

**Rule.** The worst UADD may do is leave a text English (the owner, 2026-11-20).
- A module's hooks run under `UADD.Safe` / `UADD.SafeCall`. After 5 errors the module turns itself off for the
  session through its own `Command("off")`, says so once in chat, and its English comes back. An Install that
  fails half way turns the module off at once.
- Game-wide state (fonts, the keyboard, chat, tooltips, frame walks) is touched only through core helpers
  (`U.FontBack`, `U.ChatLines`, `U.TipLines`, `U.Regions`, `U.Children`, `U.WidgetMethods`).
- The guard (`UADD/Guard.lua`) repairs what still slips through (a pinned tooltip line or watched text, a shared
  font object, a keyboard held by an unseen box) and says so once per kind.

**Check.** `python3 tools/harness/run.py`, steps "safe 1-7" (`tools/harness/flow_safe.py --prove` shows each
fail with its fix taken out) and "tt: arrow B". `python3 -m unittest tools.test_shared_state`: every risky call
in module code (set font, chat replace, frame walk, keyboard, frame kind) against an allowed count that only goes
down.

## 20. A game name asked from the wrong place

**What went wrong.** Game names (zones, NPCs, items, spells) come from UALL Forever through the routes in
`UADD.UALL` (`UADD/uall.lua`). Core `Words.lua` asked `UADD.Text`, `UADD.Zone`, ... instead: UADD's root has no
such routes, so every game-name slot of What's Training?, TomTom and Mastercraft stayed English in the game. The
harness passed, because its stubs set `UADD.Zone` and the like on the root.

**Rule.** Ask a game name only through `UADD.UALL.<Route>`. A harness stub patches `UADD.UALL`, never the root.
A module whose data has a game-name slot (sort `n`) says which routes its windows need.

**Check.** `python3 -m unittest tools.test_uall_routes`: no code reads a route from UADD's root, and each module
in `SHOWS` reaches each route it needs through `UADD.UALL`; a module with `n` slots must be listed. Its mutant
tests put the old code back and want it to fail.

## 21. Bugs we found only one at a time

**What went wrong.** The dead keyboard (lesson 16) and the pinned tooltip font (lesson 18) each reached the owner
before a check knew about them. Each check was written after its bug, for that bug only. On 2026-11-20 a chaos test
fed every module bad and odd cases on purpose. On its first run it found 8 more problems no check had caught: three
modules' hooks or timers let an error reach the game's error handler (Bagnon, What's Training?, LayerSwap); two
tooltip hooks translated every line of the game (Mastercraft, TomTom); a joined DialogueUI text kept an English line
next to Ukrainian ones; OpenMap's idle work rose with the map open; RareScanner's memo had no bound.

**Rule.** Every module must survive the chaos test: bad values, odd text, 10k calls, off/on 100 times, a second
install, combat, its own code throwing, an install that fails part-way, an addon update, other addons' tooltips and
chat. After each case the game still works and each text is whole English or whole Ukrainian. Never call
`geterrorhandler()` yourself. A new module gets a recipe in `tools/harness/chaos_mods.py` in the same commit.

**Check.** `python3 tools/harness/chaos.py` (part of `python3 tools/harness/run.py`). `CHAOS_SEED`, `CHAOS_N` and
`CHAOS_ONLY` repeat a failure; each FAIL line prints its repro. A module folder without a recipe fails. It catches
lesson 16's EditBox and lesson 18's pinned font with their fixes taken out.

## 22. A text pattern that slows down with the square of the line

**What went wrong.** Mastercraft's Words.lua (2026-11-20) had a Lua pattern with two lazy runs (`.-`) over the whole
line. It was there before, but cheap, since its answer was cached. A new step asked UALL Forever, whose "wait"
answer skips the cache, so the slow pattern ran on every call: 220-360 ms on a 10 KB text.

**Rule.** No Lua pattern with two `.-` or `.*` runs over a whole line in a hook. Split at the first mark with
`find(s, mark, 1, true)` instead. A path whose answer may not be cached must be cheap by itself.

**Check.** `python3 tools/harness/chaos.py` (in `run.py`): "Mastercraft 10 KB under 5 ms" fails with the old pattern.

## 23. A module that writes English over another language

**What went wrong.** Mastercraft has its own languages. A switch to German outside its menu (its slash command or
setup screen) turned UADD_Mastercraft off, and its off path put back the English it saw, through the raw SetText. The
labels showed English, not German (harness flow `flow_mc_lang`, 2026-11-20).

**Rule.** Going off leaves the addon's text as the addon would draw it now: put a text back only while it is still
our Ukrainian, and never over a text the addon has changed since.

**Check.** `python3 tools/harness/run.py`, the Mastercraft language steps (`tools/harness/flow_mc_lang.py --prove`).
