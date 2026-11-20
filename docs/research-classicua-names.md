# Game names from ClassicUA

ClassicUA is the other Ukrainian addon players use, alone or next to UALL Forever (the owner, 2026-11-20).
UADD asks ClassicUA first for a game name, and UALL Forever when ClassicUA has none. The code is
`UADD/uall_cua.lua`; lesson 25 in `docs/LESSONS2.md` has the rules. We ship none of ClassicUA's data or code.
How we ask UALL Forever is in `docs/research-uall-names.md`.

- **The one route.** ClassicUA keeps its glossary private. On Forever it puts a `SetText` hook on the zone
  texts (`MinimapZoneText`, `ZoneTextString`, `SubZoneTextString`) after the player enters the world. The
  hook looks the whole text up in its glossary (zones, NPCs, items, spells, quest titles and more) and writes
  the Ukrainian back. We call that hook chain with our own hidden font string, as we do for UALL Forever.
  No game label is written, so nothing flickers.
- **Whose answer.** UALL Forever hooks the same texts. An answer counts only when `debugstack` names
  ClassicUA's folder at that moment.
- **When it is asked.** One second after `PLAYER_ENTERING_WORLD`, out of combat, and only while ClassicUA is
  loaded and its options allow it: `translate_zone` not off, `disable_all_translation` off, `dev_mode` off
  (with `dev_mode` on, ClassicUA logs every miss). Before that the route says "not now" (`nil, true`).
- **What is never asked.** Text with `[`, `(`, `|`, a line break or spaces at its edges, and text over 120
  bytes. ClassicUA reads such text in other ways and could answer for part of it.
- **When it breaks.** If two test zone names get no answer through any of the three texts, ClassicUA is not
  asked again this session. Any error does the same. The routes then work as with UALL Forever alone.
- **Letter case.** Some glossary names are in small letters (an item, as used mid-sentence). When the English
  starts with a capital, the first Ukrainian letter is made a capital too.
- **Caches.** Answers and misses are saved for the session (at most 4000, then it starts again). The saved
  caches of Questie, Dungeon Journal and Attune add `ClassicUA=<version>` to their signature while ClassicUA
  is active, so they are built again when it comes, goes or updates.
- **Public calls** (`UADD.UALL`): `Providers()` (in ask order), `HasProvider(name)`, `IsAvailable()` (either
  one answers), `UallfAvailable()` (UALL Forever alone), `ProviderSig()`.
- **In the harness.** ClassicUA's own hooks do not load there. `tools/harness/flow_classicua.py` puts a
  stand-in zone hook in ClassicUA's folder that calls ClassicUA's real options and glossary; the real hook on
  the real texts is checked only in the game.
