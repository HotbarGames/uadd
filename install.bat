@echo off
setlocal EnableExtensions
rem Copies UADD, UADD_Questie, UADD_DungeonJournal, UADD_OpenMap, UADD_DialogueUI, UADD_ForeverXPBar, UADD_Auctionator, UADD_Attune, UADD_LayerSwap, UADD_AutoPotion, UADD_Bagnon, UADD_Mastercraft, UADD_WhatsTraining, UADD_TomTom, UADD_RareScanner, UADD_Pawn, UADD_GatherMate2, UADD_Scrap, UADD_SpeedyAutoLoot, UADD_WaypointUI
rem UADD_ForeverQuestPins, UADD_LiteMount, UADD_WhatTheWhisper, UADD_LootTriage, UADD_DeleteCheapestItem, UADD_WowheadQuickLink, UADD_BugSack and UADD_RoadToSixty into the WoW Forever AddOns folder. See docs\TESTING.md.
rem
rem   install.bat            -> _forever_
rem
rem Set WOW_ROOT to override the World of Warcraft folder. Close the game first: a new addon folder
rem is only picked up when the client starts (a /reload is enough for file changes).

set "WOW_ROOT_DIR=%WOW_ROOT%"
if "%WOW_ROOT_DIR%"=="" set "WOW_ROOT_DIR=C:\Program Files (x86)\World of Warcraft"
set "CLIENT=%WOW_ROOT_DIR%\_forever_"
set "ADDONS=%CLIENT%\Interface\AddOns"

if not exist "%~dp0UADD\UADD.toc" (
    echo [error] not found: "%~dp0UADD\UADD.toc"
    goto :fail
)
if not exist "%CLIENT%\.flavor.info" (
    echo [error] "%CLIENT%" is not an installed WoW client ^(no .flavor.info^).
    goto :fail
)
if not exist "%ADDONS%" mkdir "%ADDONS%"

set "MODS=UADD UADD_Questie UADD_DungeonJournal UADD_OpenMap UADD_DialogueUI UADD_ForeverXPBar UADD_Auctionator UADD_Attune UADD_LayerSwap UADD_AutoPotion UADD_Bagnon UADD_Mastercraft UADD_WhatsTraining UADD_TomTom UADD_RareScanner UADD_Pawn UADD_GatherMate2 UADD_Scrap"
set "MODS=%MODS% UADD_SpeedyAutoLoot UADD_WaypointUI UADD_ForeverQuestPins UADD_LiteMount UADD_WhatTheWhisper UADD_LootTriage UADD_DeleteCheapestItem UADD_WowheadQuickLink UADD_BugSack UADD_RoadToSixty"
for %%A in (%MODS%) do (
    echo Installing %%A ...
    robocopy "%~dp0%%A" "%ADDONS%\%%A" /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1
    if errorlevel 8 goto :copyfail
)

echo.
for %%A in (Questie QuestieDB %MODS%) do (
    rem a folder check: QuestieDB has only QuestieDB_Forever.toc
    if exist "%ADDONS%\%%A\" (
        echo   ok       %%A
    ) else (
        echo   MISSING  %%A
    )
)
if exist "%ADDONS%\UALLF\UALLF.toc" (
    echo   ok       UALLF ^(names in Ukrainian^)
) else (
    echo   optional UALLF not installed: quest, NPC, item and zone names stay English
)
if exist "%ADDONS%\ForeverDungeonJournal\" (
    echo   ok       ForeverDungeonJournal ^(for UADD_DungeonJournal^)
) else (
    echo   optional ForeverDungeonJournal not installed: the journal module stays off
)
if exist "%ADDONS%\OpenMap\" (
    echo   ok       OpenMap ^(for UADD_OpenMap^)
) else (
    echo   optional OpenMap not installed: the OpenMap module stays off
)
if exist "%ADDONS%\DialogueUI\" (
    echo   ok       DialogueUI ^(for UADD_DialogueUI^)
) else (
    echo   optional DialogueUI not installed: the DialogueUI module stays off
)
if exist "%ADDONS%\ForeverXPbar\" (
    echo   ok       ForeverXPbar ^(for UADD_ForeverXPBar^)
) else (
    echo   optional ForeverXPbar not installed: the ForeverXP Bar module stays off
)
if exist "%ADDONS%\Auctionator\" (
    echo   ok       Auctionator ^(for UADD_Auctionator^)
) else (
    echo   optional Auctionator not installed: the Auctionator module stays off
)
if exist "%ADDONS%\Attune\" (
    echo   ok       Attune ^(for UADD_Attune^)
) else (
    echo   optional Attune not installed: the Attune module stays off
)
if exist "%ADDONS%\LayerSwap\" (
    echo   ok       LayerSwap ^(for UADD_LayerSwap^)
) else (
    echo   optional LayerSwap not installed: the LayerSwap module stays off
)
if exist "%ADDONS%\AutoPotion\" (
    echo   ok       AutoPotion ^(for UADD_AutoPotion^)
) else (
    echo   optional AutoPotion not installed: the Auto Potion module stays off
)
if exist "%ADDONS%\Bagnon\" (
    echo   ok       Bagnon ^(for UADD_Bagnon^)
) else (
    echo   optional Bagnon not installed: the Bagnon module stays off
)
if exist "%ADDONS%\Mastercraft\" (
    echo   ok       Mastercraft ^(for UADD_Mastercraft; Mastercraft_Inbox needs nothing^)
) else (
    echo   optional Mastercraft not installed: the Mastercraft module stays off
)
if exist "%ADDONS%\WhatsTraining\" (
    echo   ok       WhatsTraining ^(for UADD_WhatsTraining^)
) else (
    echo   optional WhatsTraining not installed: the What's Training? module stays off
)
if exist "%ADDONS%\TomTom\" (
    echo   ok       TomTom ^(for UADD_TomTom^)
) else (
    echo   optional TomTom not installed: the TomTom module stays off
)
if exist "%ADDONS%\RareScanner\" (
    echo   ok       RareScanner ^(for UADD_RareScanner^)
) else (
    echo   optional RareScanner not installed: the RareScanner module stays off
)
if exist "%ADDONS%\Pawn\" (
    echo   ok       Pawn ^(for UADD_Pawn^)
) else (
    echo   optional Pawn not installed: the Pawn module stays off
)
if exist "%ADDONS%\GatherMate2\" (
    echo   ok       GatherMate2 ^(for UADD_GatherMate2^)
) else (
    echo   optional GatherMate2 not installed: the GatherMate2 module stays off
)
if exist "%ADDONS%\Scrap\" (
    echo   ok       Scrap ^(for UADD_Scrap^)
) else (
    echo   optional Scrap not installed: the Scrap module stays off
)
if exist "%ADDONS%\SpeedyAutoLoot\" (
    echo   ok       SpeedyAutoLoot ^(for UADD_SpeedyAutoLoot^)
) else (
    echo   optional SpeedyAutoLoot not installed: the Speedy AutoLoot module stays off
)
if exist "%ADDONS%\WaypointUI\" (
    echo   ok       WaypointUI ^(for UADD_WaypointUI^)
) else (
    echo   optional WaypointUI not installed: the Waypoint UI module stays off
)
if exist "%ADDONS%\ForeverQuestPins\" (
    echo   ok       ForeverQuestPins ^(for UADD_ForeverQuestPins^)
) else (
    echo   optional ForeverQuestPins not installed: the Forever Quest Pins module stays off
)
if exist "%ADDONS%\LiteMount\" (
    echo   ok       LiteMount ^(for UADD_LiteMount^)
) else (
    echo   optional LiteMount not installed: the LiteMount module stays off
)
if exist "%ADDONS%\WhatTheWhisper\" (
    echo   ok       WhatTheWhisper ^(for UADD_WhatTheWhisper^)
) else (
    echo   optional WhatTheWhisper not installed: the WhatTheWhisper module stays off
)
if exist "%ADDONS%\LootTriage\" (
    echo   ok       LootTriage ^(for UADD_LootTriage^)
) else (
    echo   optional LootTriage not installed: the LootTriage module stays off
)
if exist "%ADDONS%\DeleteCheapestItem\" (
    echo   ok       DeleteCheapestItem ^(for UADD_DeleteCheapestItem^)
) else (
    echo   optional DeleteCheapestItem not installed: the DeleteCheapestItem Reloaded module stays off
)
if exist "%ADDONS%\WowheadQuickLink\" (
    echo   ok       WowheadQuickLink ^(for UADD_WowheadQuickLink^)
) else (
    echo   optional WowheadQuickLink not installed: the Wowhead Quick Link module stays off
)
if exist "%ADDONS%\BugSack\" (
    echo   ok       BugSack ^(for UADD_BugSack^)
) else (
    echo   optional BugSack not installed: the BugSack module stays off
)
if exist "%ADDONS%\RoadToSixty\" (
    echo   ok       RoadToSixty ^(for UADD_RoadToSixty^)
) else (
    echo   optional RoadToSixty not installed: the Road to Sixty module stays off
)
echo.
echo Done: %ADDONS%
if "%~1"=="" pause
exit /b 0

:copyfail
echo [error] robocopy failed ^(code %errorlevel%^). Is the game running or the folder read-only?
:fail
if "%~1"=="" pause
exit /b 1
