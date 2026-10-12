# Gamepad Shoulder Slots

A World of Warcraft **Forever** add-on (Interface 16001) for the Gamepad UI.

When you hold the hostile-target shoulder button, the Gamepad UI replaces the top action bar with a targeting bar. That bar's four D-pad buttons are empty placeholders. This add-on lets you drag spells, macros and items onto them, so the D-pad gives you four more actions without changing pages.

## Use

- Click the minimap button, or type `/gpslots`, to open the editor.
- Drag a spell from the spellbook, a macro from `/macro`, or an item from your bags onto a D-pad slot.
  - Dropping onto a filled slot swaps: the old action goes back to your cursor.
  - Dragging a slot out lifts its action onto the cursor.
  - Right-click a slot to clear it.
- Hold the hostile-target shoulder and press the D-pad.

Slots are saved per character. Changes made in combat apply when combat ends, because Blizzard's buttons can only be changed out of combat.

### Slash commands

| Command | Effect |
| --- | --- |
| `/gpslots` | Open or close the editor |
| `/gpslots status` | List the slots and their state |
| `/gpslots set <up\|left\|right\|down> [spell\|item\|macro <name>]` | Assign by name, or from the cursor when no name is given |
| `/gpslots clear <direction\|all>` | Clear slots |
| `/gpslots focuskey <KEY\|off>` | Bind a key that returns gamepad focus from an open panel to the world (`TOGGLEUIFOCUS`) |
| `/gpslots minimap` | Show or hide the minimap button |

## How it works

The D-pad slots belong to Blizzard's `GamepadHostileTargetingActionBar`, at `GamepadMainActionBarFrame.PageUnit.HostileTargetingActionBar`. Blizzard's own D-pad bindings press them through `GamepadMainActionBarFrame:PressActionButton`. They are secure action buttons, so out of combat the add-on sets their `type` and `spell`/`item`/`macro` attributes, enables them, and shows the icon. Blizzard's Shoot button on the same bar is set up the same way. In combat, Blizzard's secure code performs the click, so the action isn't blocked.

What the add-on does to stay taint-free:

- It changes Blizzard's buttons only out of combat, and only through widget methods and attributes. It never writes a field on a Blizzard table.
- Blizzard re-runs `SetUpActionButtons` when `GamepadSwapHostileTargetActions` changes. The add-on follows it with `hooksecurefunc(bar, "SetUpDpadBottom", …)` and reapplies the slots.
- The editor is an ordinary frame shown with `Show()`. It isn't opened with `ShowUIPanel` and isn't added to `UISpecialFrames`, so the Gamepad UI's focus manager is left alone. Close it with its X button, the minimap button or `/gpslots`.
- The focus key is an override binding set at each login. `SaveBindings` for a Gamepad-context binding crashes Forever 1.60.1 (`InputBindings.cpp:745`).

The friendly-target shoulder's D-pad isn't used. In a group, Blizzard assigns it to party targeting and rebuilds it every time the bar is shown, including in combat.

## Known limits

- The bar slots show no tooltip in game. The editor's slots do.
- The cooldown swipe on the bar is cosmetic and can stay blank in combat.
- Spells and target macros behave normally. An item or macro that neither casts a spell nor changes your target may also trigger the shoulder button's own "target nearest enemy" when you let go of the shoulder.

## Development

```sh
lua5.1 tests/core.lua    # slot engine against a model of Blizzard's bar
lua5.1 tests/panel.lua   # editor drag/drop, swap, lift, clear, status
```

For live editing, symlink the repo into `Interface/AddOns/GamepadShoulderSlots` and `/reload` after each change. WoW loads only the files listed in the TOC, so `tests/` and `.git/` are ignored.

## Bundled libraries

These are taken unmodified from the LibDBIcon-1.0 release **v12.1.1** (`repos.wowace.com/wow/libdbicon-1-0/tags/v12.1.1`):

| Library | Version | License |
| --- | --- | --- |
| LibStub | minor 2 | Public domain (stated in the file) |
| CallbackHandler-1.0 | minor 8 | BSD (Ace3) |
| LibDataBroker-1.1 | minor 4 | Not stated upstream (tekkub/libdatabroker-1-1); widely embedded |
| LibDBIcon-1.0 | minor 57 | All Rights Reserved; embedding in add-ons is the intended use |

Before publishing this repository, decide whether to keep LibDBIcon vendored or fetch it at package time with a `.pkgmeta` external.

## License

MIT, see [LICENSE](LICENSE). This covers the add-on's own code only; the libraries under `Libs/` keep their own terms, listed above.
