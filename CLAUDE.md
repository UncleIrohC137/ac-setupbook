# AC Setupbook — instructions for Claude

You have been handed this folder by a user who wants their own Assetto Corsa
setups turned into a browsable, comparable page. Everything needed is here.
Read this file, do the work, and hand them the result.

## What this is

`AC-Setupbook.html` is a single self-contained page that puts Assetto Corsa car
setups side by side. It ships with someone else's library so it works on first
open. Your job is to rebuild it from **this** user's setups, so the page holds
their cars, their tracks, and the real units read from their own installation.

## What to do

Run this from the folder you are reading:

```
pwsh -File .\Update-Setupbook.ps1
```

If `pwsh` is not present, use the PowerShell that ships with Windows:

```
powershell -ExecutionPolicy Bypass -File .\Update-Setupbook.ps1
```

It prints four lines. A healthy run looks like this:

```
Assetto Corsa install: D:\SteamLibrary\steamapps\common\assettocorsa
Reading setups from C:\Users\<name>\Documents\Assetto Corsa\setups
Read 342 setups, 140 cars, 15 tracks
Real values from car data: 67 cars (73 without)
Wrote ...\AC-Setupbook.html (635 KB)
```

Then tell the user to open `AC-Setupbook.html`. That is the deliverable.

## When something is missing

**"Setups folder not found."** The script already tries the Documents folder and
the OneDrive-redirected one. If it still fails, ask the user where Assetto Corsa
is installed, or search for a folder named `setups` that contains car-named
subfolders, then pass it in:

```
.\Update-Setupbook.ps1 -SetupsRoot "D:\path\to\Assetto Corsa\setups"
```

**"No Assetto Corsa install found."** Only a downgrade, not a failure. The page
still builds; cars and tracks keep their folder names and values stay as click
positions rather than psi, litres and gear ratios. If the user has the game
somewhere unusual, pass it in:

```
.\Update-Setupbook.ps1 -AcRoot "D:\Games\assettocorsa"
```

**"Real values from car data: 0 cars"** while an install was found. The car data
could not be read. The page is still usable. Do not start editing the reading
code to chase this; report it and move on.

**Execution policy complaints.** Use the `powershell -ExecutionPolicy Bypass`
form above. Do not change the machine's execution policy.

**A very low car count.** The user probably pointed at a single car folder rather
than the `setups` folder that holds all of them. Go one level up.

## Rules

- **Only read the Assetto Corsa installation, never write to it.** The script
  opens each car's `data.acd` in memory to learn the setting ranges, compound
  names and gear ratios. It must stay that way: unpacking that data onto disk
  changes file checksums and can get the user rejected by online servers.
- **Do not rewrite the script to "improve" it.** It is tested on Windows
  PowerShell 5.1 and PowerShell 7. Fix the input, not the tool.
- `acd-keys.json` appears next to the script after the first run. It is a cache
  so later runs are instant. It is safe to delete and safe to ignore.

## Verifying it worked

1. The counts printed by the script are not zero.
2. Open the page. The sidebar lists their cars, most recently worked on first.
3. Open a car, tick two of its setups. They appear as columns.
4. Click one column header, then a second. The other values colour against them.
5. Where car data was read, tyre pressure reads as psi and bar, fuel in litres,
   compound by name, gears as ratios.

If step 5 shows plain numbers instead, car data was not available for that car —
expected, not a bug.

## Keeping it current

The page is a snapshot. After making new setups in the game, run the script
again; it rebuilds from scratch, so removed setups disappear as well.

## What not to promise

Setup values are positions on each car's own scale, not shared units. Within one
car they compare exactly. Between two cars they do not, not even two cars of the
same class. The page turns colouring off when cars are mixed and explains why.
Do not present cross-car numbers as directly comparable.
