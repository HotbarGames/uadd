@echo off
setlocal EnableExtensions
rem Copies UADD, UADD_Questie, UADD_DungeonJournal, UADD_OpenMap, UADD_DialogueUI, UADD_ForeverXPBar, UADD_Auctionator, UADD_Attune, UADD_LayerSwap, UADD_AutoPotion, UADD_Bagnon, UADD_Mastercraft, UADD_WhatsTraining and UADD_TomTom into the WoW Forever AddOns folder. See docs\TESTING.md.
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

for %%A in (UADD UADD_Questie UADD_DungeonJournal UADD_OpenMap UADD_DialogueUI UADD_ForeverXPBar UADD_Auctionator UADD_Attune UADD_LayerSwap UADD_AutoPotion UADD_Bagnon UADD_Mastercraft UADD_WhatsTraining UADD_TomTom) do (
    echo Installing %%A ...
    robocopy "%~dp0%%A" "%ADDONS%\%%A" /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1
    if errorlevel 8 goto :copyfail
)

echo.
for %%A in (Questie QuestieDB UADD UADD_Questie UADD_DungeonJournal UADD_OpenMap UADD_DialogueUI UADD_ForeverXPBar UADD_Auctionator UADD_Attune UADD_LayerSwap UADD_AutoPotion UADD_Bagnon UADD_Mastercraft UADD_WhatsTraining UADD_TomTom) do (
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
echo.
echo Done: %ADDONS%
if "%~1"=="" pause
exit /b 0

:copyfail
echo [error] robocopy failed ^(code %errorlevel%^). Is the game running or the folder read-only?
:fail
if "%~1"=="" pause
exit /b 1
