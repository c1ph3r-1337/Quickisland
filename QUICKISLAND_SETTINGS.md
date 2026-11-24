# QuickIsland Settings

QuickIsland Settings opens in the existing centered settings window. The QuickIsland tab contains the pill and notch dimensions, Game Mode bar, playback visualizer, typography, motion, window layout and opacity, and editable QuickIsland shortcuts. The other existing tabs continue to manage the launcher, media, notifications, lock screen, wallpaper, control center, screen tools, and the rest of the shell.

The default Settings shortcut is **Super+I**. Change it from QuickIsland → QuickIsland shortcuts. The top **Reset QuickIsland defaults** button restores the values shipped in `Assets/settings-default.json`; individual controls also have their own reset buttons.

## Hyprland integration

The installer adds a marked source block for window settings to `~/.config/hypr/userprefs.conf`, adds a generated Lua keybinding hook to `quickisland_keybindings.lua`, and writes generated files under `~/.config/quickisland/`. Shortcuts use the Lua hook only, so each binding is registered once. The settings page regenerates these files and reloads Hyprland after a shortcut or window setting changes. While Game Mode is active, window changes are also written into its restore snapshot so Game Mode exits to the newly selected values.

To remove this integration and restore the previous QuickIsland bindings:

```sh
python3 scripts/settings_integration.py uninstall
```

Installation preserves copies of the two Hyprland files and the exact removed bindings under `~/.local/state/quickisland/settings-integration/`.

The full pre-settings QuickIsland checkpoint is commit `7240471` on `main`. The settings work is developed separately on `feature/quickisland-settings`.
