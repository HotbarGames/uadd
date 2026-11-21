# Testing in the game: the other addons, part 2

Steps 149 and on of `docs/TESTING.md` (steps 42-148: `docs/TESTING-ADDONS.md`). Install and turn on Lua errors
as `docs/TESTING.md` says. Type `/uadd missed on` first, then `/reload`. Each part needs its addon on an English
client. Only what the real client can show is here; the harness covers the rest.

### Waypoint UI

149. Log in. `/uadd` lists "Waypoint UI". Open its settings and each tab (General, Waypoint, Map, Navigation,
     Appearance, Audio, Extensions, About): every text is Ukrainian, with letters, not boxes, and fits. Open
     the font dropdown and a colour picker: the same.
150. Set a waypoint and walk: the in-world line shows the place, the distance and the arrival time in Ukrainian.
     Point at the map pin on the World Map and the minimap: its tooltip is Ukrainian.
151. Click Reset All (then cancel), and paste with `/way paste` (then cancel): both questions are Ukrainian.
152. Hold Shift: English; let go: Ukrainian. `/uadd waypointui off`: English; `on`: Ukrainian.

### Forever Quest Pins

153. Log in. `/uadd` lists "Forever Quest Pins". On the World Map open its filter menu: Ukrainian, fits.
154. Open the game's Settings, AddOns, Forever Quest Pins and each page under it in the tree: page names,
     checkboxes and their tooltips are Ukrainian, with letters, not boxes. The level range on a checkbox
     stays as the addon shows it.
155. Skip a breadcrumb quest, and abandon a quest: the window and the chat line are whole Ukrainian, or whole
     English when a quest name has no Ukrainian. No "action blocked" message (taint) in the session.
156. Hold Shift with the settings open: English; let go: Ukrainian. `/uadd foreverquestpins off`: English; `on`: Ukrainian.

### LiteMount

157. Log in. `/uadd` lists "LiteMount". Type `/lm`: the page names in the tree (General, Rules, Falling,
     Mounts, Advanced and the rest) are Ukrainian, with letters, not boxes. With ClassicUA alone, too.
158. On the Mounts page open the filter menu: Ukrainian. Mount names stay as the game gives them. The Falling
     dropdown is Ukrainian. The Rename and "Key Binding 1" buttons fit.
159. Click New Profile: the question and its buttons are Ukrainian, and you can type in the box. Cancel it.
160. Hold Shift: English; let go: Ukrainian. `/uadd litemount off`: English; `on`: Ukrainian.

### Popups of all modules

161. With ClassicUA alone (no UALL Forever), open one popup each of Auctionator (the sell question) and one
     more module: the buttons are Ukrainian; Shift shows English; a popup of another addon is not changed.
