# CrispyLib config API

CrispyLib 3.3.0, released 8 October 2026. The [library](Crispylib.lua) now separates configuration values, application, JSON conversion, and storage. You can choose the folder, replace the storage backend, or use the codec and apply methods with your own config UI. Existing Save/Load/Import/Export methods remain available with both dot and colon calls.

## Choose a folder

```lua
local Config = CrispyLib.Config

local ok, err = Config.Configure({
    Folder = "MyHub/Configs",
    File = "main",
})
assert(ok, err)

Config.Save()       -- MyHub/Configs/main.json
Config.Load()
Config.Save("pvp")  -- MyHub/Configs/pvp.json
```

The folder is used exactly as configured, with slash normalization. Nested folders are created when saving through the built-in filesystem backend. Absolute paths work when the host's file API supports them. Slot names are sanitized and limited to 64 characters; folder paths cannot contain `.` or `..` segments.

The same settings can be supplied when creating a window:

```lua
local window = CrispyLib.CreateWindow({
    Title = "My Hub",
    ConfigFolder = "MyHub/Configs",
    ConfigFile = "main",
    AutoLoad = true,
})
```

Create controls before yielding during startup. AutoLoad may also restore flags before their controls exist; those controls adopt loaded values and apply their callbacks when registered later.

`Config.SetFolder(nil)` restores `CrispyLib/<ConfigName>`. `ConfigName` retains its legacy meaning and does not override an explicit folder. The config object is shared by all windows from the same library instance. Changing the folder, storage adapter, or ConfigName stops autosave and resets the selected profile to `default`; restart autosave after loading the new scope.

## Loading activates settings

Successful Load, Import, Apply, ResetDefaults, and profile changes update controls and flags, then invoke feature callbacks. Supplied values invoke callbacks even when unchanged, so reloading can reapply runtime settings. A loaded false value invokes the callback with false.

Keybind configuration changes the binding without firing its keypress action. Input callbacks receive `(value, false)` during config application. Controls may opt out individually with `ConfigCallbacks = false`.

For a custom runtime settings system, disable automatic feature callbacks and use the shared application event:

```lua
local Config = CrispyLib.Config
assert(Config.Configure({ ApplyCallbacks = false }))

local disconnect = Config.OnApplied(function(values, info)
    -- values are ordinary Luau/Roblox values, after control normalization.
    ApplyMySettings(values)
end)

local ok, err, info = Config.Load("main")
if not ok then warn(err) end

-- When the owning UI/module is removed:
-- disconnect()
```

`OnApplied` runs once after each application, including unchanged values. It receives independent copies of table values and metadata. Listeners may call Save, unsubscribe, or yield. Listener errors are logged, and yielded listeners finish independently of the caller; their completion is not part of Load's success result. Recursive applications started inside synchronous event delivery are rejected. For runtime errors that must reach the Load caller, use a control Callback or a registered flag's `Apply` function instead.

Per-call options override the default policy:

```lua
Config.Load("main", { Callbacks = false })
Config.Import(json, { Callbacks = true, Context = { source = "paste" } })
Config.Apply(snapshot, { Notify = false }) -- omit OnApplied for this call
```

Event metadata includes `Operation`, `Name` where available, `Profile`, `Folder`, `ChangedFlags`, `NormalizedFlags`, `Applied`, `CallbackErrors`, and `Context`.

## Use your own config system

The codec has no file access and does not apply flags or UI values. These methods let a custom menu or persistence module handle JSON itself:

```lua
local Config = CrispyLib.Config

local function saveWithMySystem(name)
    local json, err = Config.Encode(nil, { Bundle = true })
    if not json then return false, err end
    return MyStorage.Save(name, json)
end

local function loadWithMySystem(name)
    local json, readError = MyStorage.Load(name)
    if json == nil then return false, readError or "config does not exist" end

    local snapshot, decodeError = Config.Decode(json)
    if snapshot == nil then return false, decodeError end
    return Config.Apply(snapshot)
end
```

`MyStorage` and `ApplyMySettings` in these examples are supplied by the application. A standalone codec can also encode an explicit flag table: `Config.Encode(myValues, {Bundle=true})`.

Snapshot and Decode return **serialized snapshots**, including tagged Roblox datatypes and a Nil marker. Apply consumes that format and produces ordinary values. OnApplied receives the ordinary values. Snapshot/Save include registered flags except those excluded by Ignore; register non-UI settings if they should be saved by the built-in methods.

## Replace storage while keeping Save/Load

Adapter methods are plain functions, called without an implicit `self`. Read and Write are required. This example supplies an in-memory adapter; substitute your own backend inside its functions.

```lua
local files = {}
local storage = {
    Read = function(path)
        return files[path] -- nil means missing
    end,
    Write = function(path, contents)
        files[path] = contents
        return true
    end,
    List = function(folder)
        local result = {}
        local prefix = folder .. "/"
        for path in pairs(files) do
            if path:sub(1, #prefix) == prefix then
                result[#result + 1] = path
            end
        end
        return result
    end,
    Delete = function(path)
        files[path] = nil
        return true
    end,
}

assert(CrispyLib.Config.Configure({
    Folder = "MyHub/Configs",
    Storage = storage,
}))

CrispyLib.Config.Save("main")
CrispyLib.Config.Load("main")
```

| Adapter method | Contract |
| --- | --- |
| `Read(path)` | Return JSON text. Return `nil` or `nil, "config does not exist"` for a missing slot. Return `false, error` or `nil, error` for another read failure. |
| `Write(path, contents)` | Return true or nil on success; false, error on failure. |
| `List(folder)` — optional | Return an array of `.json` filenames or full paths in that folder. Nested and foreign paths are filtered out. |
| `Delete(path)` — optional | Return true or nil on success; false, error on failure. Missing support reports an error. |
| `Exists(path)` — optional | Return a boolean, optionally with an error as the second return. Load skips Read when false. |
| `EnsureFolder(folder)` — optional | Called before Write. Return true or nil on success; false, error on failure. |

Thrown adapter errors are returned to the caller. Storage methods may yield; conflicting read/write/delete operations and scope changes are rejected while an operation is in progress. Cancellation releases stale guards on the next guarded operation. A backend is responsible for making its own writes atomic if required.

`SetStorage(false)` explicitly selects the built-in memory backend. `SetStorage(nil)` restores automatic selection: filesystem when readfile and writefile both exist, otherwise memory when neither exists. A partial filesystem API reports an error. Memory storage is separated by folder and uses the same JSON format as disk; it lasts for the lifetime of the library instance.

Save, Load, List, and Delete accept optional per-call `Folder`/`Storage` overrides. Profile operations use the configured scope: change it with SetFolder/SetStorage before switching profiles.

## Register settings without controls

```lua
local settings = { enabled = false }
local unregister, err = CrispyLib.Config.Register(
    "enabled",
    function() return settings.enabled end,
    function(value) settings.enabled = value end,
    {
        Type = "boolean",
        Apply = function(value, info)
            SetFeatureEnabled(value)
        end,
    }
)
assert(err == nil, err)

-- unregister() detaches the getter/setter and runtime applier.
```

Getters, setters, Normalize, and Validate must finish without yielding. The setter assigns state; Apply performs runtime work and may yield. Options include `Type` (the Roblox `typeof` name, inferred from a non-nil default), `Normalize(value)`, `Validate(value)` returning true or false/error, `Apply(value, info)`, `Canonical` (default true), and `Owner`.

Canonical getters read back the accepted value after assignment. For example, a slider that clamps 1000 to 100 stores and exports 100. Incompatible controls sharing a flag cause application to fail. Widget options `ConfigNormalize` and `ConfigValidate` provide the equivalent schema hooks.

## API reference

| API | Result / purpose |
| --- | --- |
| `Configure(options)` | `ok, error`; supports Folder, File, Name, Storage, ApplyCallbacks, Version. Validates the whole update before committing it. |
| `SetFolder(folder)` / `GetFolder()` | Configure or read the resolved folder; nil resets the legacy layout. |
| `SetStorage(adapter)` / `GetOptions()` | Configure storage; inspect resolved settings. |
| `GetPath(name)` / `IsBusy()` | Resolve a slot path; inspect operation/startup guards. |
| `Register(flag, getter, setter, options)` | `unregister, error`; register a non-UI setting. |
| `OnApplied(callback)` | Return an unsubscribe function. |
| `Snapshot()` | `serializedSnapshot, error`; capture registered, non-ignored flags. |
| `Apply(snapshot, options)` | `ok, error, info`; stage, validate, assign, and apply values. |
| `Encode(snapshot, options)` | `json, error`; omit snapshot to capture current flags. `Bundle=true` includes version metadata. |
| `Decode(jsonOrTable, options)` | `serializedSnapshot, error, metadata`; validate and migrate without applying. `FromVersion` opts legacy data into migration. |
| `Save(name, options)` / `Load(name, options)` | Save a versioned bundle; Load returns `ok, error, info`. Omitted names use the configured File. |
| `Export()` / `ExportBundle()` | `json, error`; bare snapshot or versioned bundle. Legacy failure return remains `"{}", error`. |
| `Import(jsonOrTable, options)` | Decode and apply; returns `ok, error, info`. |
| `List(options)` / `Delete(name, options)` | `names, error` / `ok, error`. |
| `ResetDefaults(options)` / `Ignore(flag, ignored)` | Apply registered defaults; include/exclude a flag (`false` restores inclusion). |
| `SetVersion(version)` / `RegisterMigration(from, to, callback)` | Configure schema version and migration steps. |
| `GetProfile()` / `SetProfile(name, options)` | Read or switch the active profile; save the previous profile before loading the destination. |
| `ListProfiles()` / `DeleteProfile(name)` | List profiles; deletion rejects the default or active profile. |
| `CreateProfileUI(tab)` | Optional built-in profile controls; your application can use its own menu. |
| `AutoSave(seconds, name)` / `StopAutoSave()` | Autosave after the first full interval (minimum five seconds); stop the owned loop. |

New saves contain schema metadata and use migration when loaded. Legacy bare configs remain readable. Export keeps its bare format for compatibility; use ExportBundle or Encode with Bundle=true when migrations are required. Future schema versions, malformed datatypes, mixed array/dictionary keys, and sparse arrays are rejected instead of silently losing values.

Values and controls commit together before callbacks run. A setter error rejects the application and attempts to restore previous flags and control values. A runtime callback error returns false with `info.Applied=true` and entries in `info.CallbackErrors`: values were assigned, but runtime work failed. Arbitrary callback side effects cannot be automatically undone. Failed profile switches restore previous flags, controls, profile selection, and late-registration callback policy; `info.StateRolledBack` identifies a rollback after callbacks began. Cancelled profile switches recover their prior values on the next guarded operation.

Autosave skips busy operations, empty registries, and paths whose loading failed or was cancelled. A successful Load or explicit Save clears that path's overwrite protection. A manual Apply/Import alone does not clear it. This preserves the unread or invalid file until the application explicitly resolves it.

When integrating this local version, ensure your loader selects it. A loader that first returns a cached global or downloads a release can bypass the edited local file. Replace config-method monkeypatches with OnApplied where possible; wrappers must preserve all arguments and return values, including Notify=false during profile loading.

## Validation

The complete library compiles with official Luau 0.740. All 11 core regression groups and 14 config regression groups pass. The checks use extracted library functions and simulated UI, scheduling, JSON, and filesystem dependencies. The previous public methods, UI text, and default theme remain present. Live Roblox rendering and executor file APIs have not been tested.
