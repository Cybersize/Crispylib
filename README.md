# CrispyLib

CrispyLib 3.3.0 is a single-file Roblox/Luau UI library with windows, tabs, reusable controls, themes, notifications, owned tasks, and configuration profiles.

## Load the latest release

```lua
local CrispyLib = loadstring(game:HttpGet(
    "https://github.com/Cybersize/Crispylib/releases/latest/download/CrispyLib.lua"
))()
```

For a fixed version, use `/releases/download/v3.3.0/CrispyLib.lua` instead of `/releases/latest/download/CrispyLib.lua`.

The repository source, [Crispylib.lua](Crispylib.lua), and the release asset, `CrispyLib.lua`, contain the same library. `CrispyLib.Version` reports `3.3.0`.

## Create a window

```lua
local Window = CrispyLib.CreateWindow({
    Title = "My Hub",
    ConfigFolder = "MyHub/Configs",
    ConfigFile = "main",
    AutoLoad = true,
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

## Configuration

Choose an exact folder with `Config.Configure({Folder="MyHub/Configs", File="main"})` or the window options shown above. Existing Save, Load, Import, Export, Snapshot, Apply, and profile methods remain available with dot and colon calls.

The config system supports custom Read/Write storage adapters, pure Encode/Decode methods, non-UI flag registration, and an OnApplied event for applications that manage their own runtime settings or config menus. See [the config API reference and examples](CONFIG_API.md).

### Migrating from earlier releases

Loading a configuration now invokes feature callbacks after flags and controls are synchronized, including when the supplied values are unchanged. To preserve silent feature callbacks and apply settings yourself:

```lua
CrispyLib.Config.Configure({ ApplyCallbacks = false })
local disconnect = CrispyLib.Config.OnApplied(function(values, info)
    -- Apply your runtime settings here.
end)
```

Individual controls can opt out with `ConfigCallbacks=false`, and a specific Load/Import/Apply can use `{Callbacks=false}`. Loading a keybind never fires its keypress action. New Save files include schema/version metadata; old bare snapshots remain readable.

Ensure a cached loader actually selects 3.3.0 when using the new APIs.

## Validation

Compiled with official Luau 0.740; 25 core/config regression groups pass with simulated dependencies. Existing public methods, UI text, and the default theme are retained. Live Roblox rendering and executor file APIs remain unverified.
