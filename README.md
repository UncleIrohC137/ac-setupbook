# AC Setupbook

Builds one HTML page that puts your Assetto Corsa setups side by side, in the
units the game shows: psi and bar, litres, compound names, gear ratios.

## Run it

```
.\Run.cmd
```

Finds your setups folder and your Assetto Corsa install, writes
`AC-Setupbook.html` next to itself. Open that. Run it again after making new
setups — it rebuilds from scratch.

Using Claude Code instead:

```
Read CLAUDE.md in this folder and set it up for me.
```

Nothing to install. Works on the PowerShell that ships with Windows and on
PowerShell 7.

## If it can't find your folders

```
.\Update-Setupbook.ps1 -SetupsRoot "D:\...\Assetto Corsa\setups" -AcRoot "D:\SteamLibrary\steamapps\common\assettocorsa"
```

Without the Assetto Corsa install it still works; values stay as raw click
positions instead of real units.

## Files

| | |
|---|---|
| `Run.cmd` | double-click to build the page |
| `Update-Setupbook.ps1` | the script it calls |
| `setupbook.template.html` | the page without data |
| `CLAUDE.md` | instructions for Claude Code |

`AC-Setupbook.html` and `acd-keys.json` are produced by the script, not tracked.

## Two notes

Your Assetto Corsa install is only read, never written to. Car data is opened in
memory to learn the setting ranges; nothing is unpacked to disk, which would
change file checksums and can get you rejected by servers that verify them.

Setup values are positions on each car's own scale. They compare exactly within
one car, and not at all between two cars — the page turns colouring off when you
mix cars.
