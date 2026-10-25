LAST ONE DRY
============

Version @VERSION@

A first-person battle-royale brawl aboard a sinking ship. The sea is coming in
room by room: shove the others into it, keep your feet, and be the last one dry.
Play against seven bots, or online with friends.


RUNNING THE GAME
----------------

Unzip the folder anywhere and run the game in it. Nothing is installed; your
settings are kept in your user folder under "LastOneDry".

  Windows  Double-click LastOneDry.exe. If SmartScreen warns about an unknown
           publisher, choose "More info", then "Run anyway".

  Linux    Run ./LastOneDry.x86_64 (chmod +x LastOneDry.x86_64 first if your
           unzip tool dropped the executable bit). Needs OpenGL 3.3 drivers.

  macOS    The app is not notarized, so the first launch needs one extra step.
           On macOS 15 (Sequoia) and later: open LastOneDry.app, dismiss the
           warning, then in System Settings > Privacy & Security choose "Open
           Anyway". On older macOS: right-click (or Control-click) the app,
           choose Open, then Open again. After that it opens normally. If macOS
           says the app is damaged, run in Terminal:
               xattr -dr com.apple.quarantine LastOneDry.app


CONTROLS
--------

                  Keyboard and mouse           Gamepad
  Move            W A S D or arrow keys        Left stick or D-pad
  Look            Mouse                        Right stick
  Shove           Left mouse button or F       Right trigger or X / Square
  Brace           Right mouse button or Shift  Left trigger or right bumper
  Jump            Space                        A / Cross
  Pause           Esc                          Start / Menu
  Rematch         R (once the match is over)   Start
  Once out:
    Next player   E                            D-pad right
    Previous      Q                            D-pad left
    Free camera   C                            Y / Triangle

Every key above but Rematch can be rebound in Settings > Keys; the pad's
buttons stay as they are. Settings also holds the sound (Sound), mouse
sensitivity, Invert Y and field of view (Controls), and window mode, VSync and
the frame cap (Graphics).


PLAYING
-------

Play starts a match against seven bots. The ship sinks fast by default; open
Custom match and untick Fast sinking for the slower, paced sinking, untick
Bonuses for a match with no bonuses below decks, or pick a seed. The pause menu
lists the controls. The results tally your points across rematches; the main
menu's corner shows the game's version.


ONLINE
------

Online play needs a game server; none is built into this download. Choose
Play online in the main menu, enter the server address you were given
(ws://HOST:PORT or wss://HOST), then Create a room and share its code, or Join
one by its code. The game remembers the last server and name you played under.
Online rooms sink at the pace the server sets, fast unless its host chose the
paced clock, and have bonuses unless its host turned them off.


LICENSES
--------

The game is built with the Godot Engine (MIT licence). The licences of the
engine, its third-party components, the fonts and every other asset are in the
licenses folder beside this file, and on the main menu's Credits screen.
