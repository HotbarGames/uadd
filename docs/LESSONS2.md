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
