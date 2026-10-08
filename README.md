# CrispyLib

CrispyLib 3.4.0 is a single-file Roblox/Luau UI library with windows, tabs, reusable controls, themes, notifications, owned tasks, configuration profiles, and automatic mobile support.

## Load the latest release

```lua
local CrispyLib = loadstring(game:HttpGet(
    "https://github.com/Cybersize/Crispylib/releases/latest/download/CrispyLib.lua"
))()
```

For a fixed version, use `/releases/download/v3.4.0/CrispyLib.lua` instead of `/releases/latest/download/CrispyLib.lua`.

The repository source, [Crispylib.lua](Crispylib.lua), and the release asset, `CrispyLib.lua`, contain the same library. `CrispyLib.Version` reports `3.4.0`.

## Create a window

```lua
local Window = CrispyLib.CreateWindow({
    Title = "My Hub",
    ConfigFolder = "MyHub/Configs",
    ConfigFile = "main",
    AutoLoad = true,
    MobileMode = "Auto", -- optional: "Auto", "Touch", or "Desktop"
})

local Tab = Window:AddTab({ Name = "Settings" })
Tab:AddToggle({
    Name = "Enabled",
    Flag = "enabled",
    Default = false,
    Callback = function(value)
        print("Enabled:", value)
    end,
})

CrispyLib.Config.AutoSave(30)
```

Create controls before yielding during startup. Loaded values also apply to controls registered later.

## Mobile UI

Touch-capable devices automatically receive larger touch targets, a draggable show/hide button, and tap actions for keybind controls. Narrow windows use a tab drawer and stacked control rows. Windows, dropdowns, color panels, and modals fit the safe area and refit when the screen rotates, the camera changes, or the software keyboard opens.

Existing window, tab, control, and config calls remain available. `Window:SetMobileMode("Touch")` forces the touch layout; `"Desktop"` restores desktop sizing and binding controls; `"Auto"` uses the device's touch capability. A touch keybind invokes its callback without changing its saved keyboard binding. Consumer code that separately checks physical mouse or keyboard input still needs its own touch input handling.

See the [mobile API guide](MOBILE.md) and [UI-only mobile smoke test](mobile-example.lua).

## Configuration

Choose an exact folder with `Config.Configure({Folder="MyHub/Configs", File="main"})` or the window options shown above. Existing Save, Load, Import, Export, Snapshot, Apply, and profile methods remain available with dot and colon calls.

The config system supports custom Read/Write storage adapters, pure Encode/Decode methods, non-UI flag registration, and an OnApplied event for applications that manage their own runtime settings or config menus. See [the config API reference and examples](CONFIG_API.md).

### Config migration from releases before 3.3.0

Loading a configuration invokes feature callbacks after flags and controls are synchronized, including when the supplied values are unchanged. To preserve silent feature callbacks and apply settings yourself:

```lua
CrispyLib.Config.Configure({ ApplyCallbacks = false })
local disconnect = CrispyLib.Config.OnApplied(function(values, info)
    -- Apply your runtime settings here.
end)
```

Individual controls can opt out with `ConfigCallbacks=false`, and a specific Load/Import/Apply can use `{Callbacks=false}`. Loading a keybind never fires its keypress action. New Save files include schema/version metadata; old bare snapshots remain readable.

Reload the library to receive the update. A loader pinned to an older release or returning a cached library must select 3.4.0 to use the mobile APIs.

## Validation

Compiled with official Luau 0.740; all 37 regression groups pass (11 core, 14 config, and 12 mobile). The checks execute library implementations against simulated dependencies, including viewport changes, input cancellation, popup fitting, software keyboards, and cleanup. Existing public methods, UI text, and the default theme are retained. Live Roblox phone/tablet rendering and executor file APIs remain unverified.
