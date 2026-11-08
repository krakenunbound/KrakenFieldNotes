# Kraken Field Notes

Notes about other players in World of Warcraft: Forever, with a **good**,
**neutral** or **bad** rating, plus who you've **ignored and why**. As someone
runs past, a glance tells you if you had a good or bad time with them, or
ignored them for something they said.

Current version: **3.1.1**, for the official Forever client (build 1.60.1.70790,
interface 16001). Rewritten from Field Notes 2.0 for Classic Era.

## Where the symbol shows up

| Rating | Symbol |
|---|---|
| Good | green check |
| Neutral | note |
| Bad | red cross |
| Ignored | the priest's Silence spell icon, beside the rating or on its own |

- **Over their nameplate**, above their name. Friendly nameplates inside
  instances are protected by the game, so there's no symbol on those.
- **On your target frame**, at the corner of their portrait. Hover it to read the
  note, click it to edit.
- **Beside their paper doll** when you inspect them: the rating and the note,
  or "No note yet" with a click to write one.
- **In their tooltip.**
- **Before their chat messages.**

## Ignored players

- **Shown everywhere a rating is.** Anyone on your ignore list gets the Ignored
  symbol, even with no note. With [Kraken Ignore Sync](../KrakenIgnoreSync)
  installed, that includes people you ignored on your other characters.
- **The reason is written for you.** Field Notes keeps the last 3 things each
  player said in chat over the last 30 minutes (in memory only, never saved). The
  moment you ignore someone, it writes them a note, rated Bad unless you'd already
  rated them, for example:
  `Ignored 2026-11-07 14:32 in Elwynn Forest. Last said: (say) "lol noobs, go back to retail" (Trade - City) "WTS gold cheap www"`.
  An existing note keeps its text, with this added on a new line.
- **What doesn't get a note:**
  - your ignore list loading at login, however late it arrives
  - several names added at once (the list loading, or Ignore Sync filling it in),
    since you ignore people one at a time
  - in the first two minutes after login, a single new name from someone who
    hadn't said anything, since that looks just like a one-name list loading
  - Ignore Sync copying an ignore over from another character, since that
    character already wrote the note (notes are shared by all your characters)
- `/fn show autonote` turns the automatic notes off or on, and `/fn show ignored`
  the Ignored symbol.

## Writing notes

- Right-click a player (their portrait, nameplate, chat name, party or raid frame,
  friends or guild list) and choose **Field Note...**.
- `/fn` writes a note about your target. `/fn First Surname` writes one by name.
- In the editor, pick Good, Neutral or Bad, write anything, and Save. Erase deletes
  the note.
- `/fn good`, `/fn neutral`, `/fn bad` rate your target in one go, keeping any text.
- `/fn list` lists everyone you've noted.
- `/fn show nameplates` (or `target`, `inspect`, `tooltip`, `chat`) turns the
  symbol off or on in that place.
- `/fn show ignored` / `/fn show autonote`: see above.

Notes are account-wide, in `KrakenFieldNotesDB`. A note is found by the
player's full name ("Prime Arnold" and "Prime-Arnold" match) and remembers their
character ID, so they're still recognised in combat when Forever hides names.

## Testing

`tests/kfn_harness.py` runs the addon against a mock client with
[lupa](https://pypi.org/project/lupa/): `python -I tests/kfn_harness.py .`

It covers:

- writing and rating a note
- nameplates: recycled plates and unit frames, protected plates
- secret names in combat
- the target frame, the inspect window, the tooltip and chat
- the right-click menu
- `/fn` commands and erasing
- ignored players: the symbol, the automatic note and what it records, Ignore Sync's
  shared list, and no notes for the login load or synced ignores

It's a mock, so it still needs checking in the live client.

## License

The [LICENSE](LICENSE) applies: copyright 2026 tf4482, all rights reserved unless
otherwise explicitly stated.
