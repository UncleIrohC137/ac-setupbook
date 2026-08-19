# AC Setupbook

Compare Assetto Corsa car setups side by side, per car and per track, instead of
opening them one at a time in the game.

The page groups every setting into blocks, folds left and right into "front" and
"rear", and shows values the way the game shows them — tyre pressure in psi and
bar, fuel in litres, compounds by name, gears as ratios with their tooth counts —
with the raw click position still visible next to each one.

Pick any two setups as reference **A** and **B** and everything else shades
against them: same as A, same as B, in between, or past both. One button hides
every row where the columns agree. Then build a new setup out of what is on
screen: click cells to take values, nudge them with **+** and **−** or type a
number, and copy the finished ini.

Five languages, English by default. Everything happens in your browser — nothing
is uploaded and there is no server.

## Getting started

Clone or download this repository, then:

```
.\Run.cmd
```

That is it. The script finds your `Documents\Assetto Corsa\setups` folder and
your Assetto Corsa installation on its own, reads them, and writes
`AC-Setupbook.html` next to itself. Open that file.

Run it again whenever you have made new setups. It rebuilds from scratch, so
setups you deleted disappear as well.

### If you use Claude Code

Open the folder and say:

```
Read CLAUDE.md in this folder and set it up for me.
```

`CLAUDE.md` covers what to run, what a healthy run looks like, where to look when
a folder is not where it expects, and which non-findings are normal rather than
errors.

### If Run.cmd is not for you

```
pwsh -File .\Update-Setupbook.ps1
```

or, on the PowerShell that ships with Windows:

```
powershell -ExecutionPolicy Bypass -File .\Update-Setupbook.ps1
```

Pass paths yourself if the automatic search comes up empty:

```
.\Update-Setupbook.ps1 -SetupsRoot "D:\...\Assetto Corsa\setups" -AcRoot "D:\SteamLibrary\steamapps\common\assettocorsa"
```

## What is here

| | |
|---|---|
| `Run.cmd` | double-click to build the page from your setups |
| `Update-Setupbook.ps1` | the script it calls; runs on Windows PowerShell 5.1 and PowerShell 7 |
| `setupbook.template.html` | the page without data; the script fills it |
| `CLAUDE.md` | instructions for Claude Code |

`AC-Setupbook.html` and `acd-keys.json` are produced by the script and are not
tracked here.

## How the real values are read

Setup files store click positions, not units. What a click means lives in each
car's `data.acd`, alongside compound names and gear ratio tables. The script
opens that file **in memory only** to learn the ranges. It never writes to your
Assetto Corsa installation, and deliberately does not unpack anything to disk —
that changes file checksums and can get you rejected by servers that verify them.

Cars whose data cannot be read still work; their values stay as click positions.

## One thing worth knowing

Setup values sit on each car's own scale. Within one car they compare exactly.
Between two cars they do not — not even two cars in the same class. Put two
different cars side by side and the colouring switches itself off and says why.
You can override that if you know what you are looking at.
