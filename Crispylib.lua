--[[
    CrispyLib v2  –  Lua UI Library for Roblox Executors
    macOS-inspired dark GUI  |  Production-grade rewrite

    USAGE
    ─────
    local CrispyLib = loadstring(game:HttpGet("..."))()

    local Loader = CrispyLib.CreateLoadingScreen({ Title = "Crispy Hub", Subtitle = "Loading..." })
    Loader:SetStatus("Connecting..."); Loader:SetProgress(0.8); Loader:Finish()

    local Window = CrispyLib:CreateWindow({
        Title                  = "Crispy Hub",
        Subtitle               = "by you",
        ConfigName             = "MyScript",
        AutoLoad               = true,
        Size                   = UDim2.new(0, 760, 0, 490),         -- optional custom window size
        DragStyle              = 1,                                  -- 1 = title-bar drag (PC), 2 = full-window drag (Mobile)
        DisabledWindowControls = {},                                 -- hide buttons: e.g. { "Exit", "Minimize" }
        ShowUserInfo           = false,                              -- show avatar + username in title bar
        Keybind                = Enum.KeyCode.RightShift,           -- toggle window visibility
        AcrylicBlur            = false,                             -- BlurEffect behind window (may be detected)
    })
    -- runtime keybind change:
    Window:SetKeybind(Enum.KeyCode.Insert)

    -- v2.2 window methods:
    Window:SetAccent(Color3.fromRGB(255, 100, 50))  -- change accent colour live
    Window:SetIcon("rbxassetid://12345678")          -- logo in title bar
    Window:SetPosition(UDim2.new(0.1, 0, 0.1, 0))   -- reposition with tween
    Window:Resize(UDim2.new(0, 900, 0, 560))         -- animate resize
    Window:Pin()   -- lock in place (no drag)
    Window:Unpin() -- re-enable dragging

    -- v2.2 tab methods:
    local Tab = Window:AddTab({ Name = "General", Icon = "⚙" })
    Tab:SetBadge(5)       -- show "5" badge on the sidebar button
    Tab:ClearBadge()      -- remove it
    Tab:GroupEnd()        -- close AddSection group (next rows are standalone again)
    Tab:AddDivider({ Label = "Optional Label" })
    Tab:AddRichText({ Text = "Hello <b>world</b>", RichText = true })
    local bar = Tab:AddProgressBar({ Name = "Loading", Default = 0.5, Flag = "prog" })
    bar:Set(0.75)
    bar:Animate(1, 2)     -- tween to 100% over 2 seconds
    bar:Pulse()           -- glow loop
    bar:StopPulse()

    -- v2.2 component dependency:
    local toggle = Tab:AddToggle({ Name = "Master", Default = true })
    local slider  = Tab:AddSlider({ Name = "Slave", Default = 50 })
    slider:DependsOn(toggle)  -- slider auto-disables when toggle is off

    -- v2.2 config:
    CrispyLib.Config.AutoSave(30)      -- auto-save every 30 seconds
    CrispyLib.Config.StopAutoSave()    -- cancel it

    -- v2.2 theming:
    CrispyLib.AnimateThemeTransition("Midnight", 0.5)  -- smooth theme swap

    Window:AddSidebarSection("Main")
    local Tab = Window:AddTab({ Name = "General", Icon = "⚙" })

    Tab:AddSection({ Title = "⚡ Auto Reroll", Description = "Uses Power Shards automatically." })

    local toggle = Tab:AddToggle({
        Name = "Enabled", Description = "Toggle auto-reroll.",
        Default = false, Flag = "ar_enabled",
        Callback = function(v) print("Toggle:", v) end,
    })
    toggle:Set(true)        -- programmatic update (fires callback)
    toggle:Set(true, true)  -- silent update (no callback)
    toggle:Get()            -- returns current value
    toggle:Enable()
    toggle:Disable()
    toggle:Show()
    toggle:Hide()

    -- Window-level API added in v2.1:
    -- Window:SetKeybind(Enum.KeyCode.RightShift)  -- change toggle keybind at runtime

    -- All components share the same API surface:
    -- :Set(value [, silent])   :Get()
    -- :Enable() / :Disable()   :Show() / :Hide()
    -- :SetLabel(text)          (where applicable)
    -- :SetDescription(text)    (where applicable)

    CHANGELOG v2 → v2.3
    ───────────────────
    ERROR BOUNDARY
    • CrispyLib.OnError(fn)          — global error handler (fires on any callback error)
    • CrispyLib.SafeRun(fn, ...)     — pcall wrapper that shows a notification on failure
    HTTP MODULE
    • CrispyLib.HTTP.Get(url, cb)    — wrapped HttpGet with error handling
    • CrispyLib.HTTP.Post(url,d,cb)  — POST via request() with fallback
    • CrispyLib.HTTP.Webhook(url,msg,opts) — Discord webhook one-liner
    AUTO-UPDATER
    • CrispyLib.Updater.Check(url, ver, cb) — compare remote version string
    • CrispyLib.Updater.AutoUpdate(url, ver) — re-execute if update found + notify
    SYSTEM MODULE
    • CrispyLib.System.FPS()         — current framerate
    • CrispyLib.System.Ping()        — current ping in ms
    • CrispyLib.System.Memory()      — client memory in MB
    • CrispyLib.System.GetExecutor() — detect executor name
    • CrispyLib.System.Capabilities()— table of available executor APIs
    • CrispyLib.System.StatsBar(cfg) — floating FPS/Ping/Memory HUD overlay
    • CrispyLib.System.OnFPSDrop(threshold, fn) — callback when FPS falls below limit
    PROFILES
    • CrispyLib.Config.GetProfile()       — current profile name
    • CrispyLib.Config.SetProfile(name)   — switch profile (save current, load new)
    • CrispyLib.Config.ListProfiles()     — list saved profile names
    • CrispyLib.Config.DeleteProfile(name)— delete a profile
    • CrispyLib.Config.CreateProfileUI(tab) — inject a profile picker row into any tab
    DEBUG MODULE
    • CrispyLib.Debug.Log(msg, level)  — internal logger (info/warn/error)
    • CrispyLib.Debug.Panel(tab)       — inject live flag viewer + log into a tab
    • CrispyLib.Debug.Watch(flags, tab)— show specific flags live
    • CrispyLib.Debug.Export()         — dump log to string / file

    CHANGELOG v2 → v2.2
    ───────────────────
    NEW COMPONENTS
    • Tab:AddProgressBar(cfg)  — animated progress bar; :Set(0-1), :SetLabel, :Pulse, :Animate
    • Tab:AddDivider(cfg)      — thin visual separator between rows
    • Tab:AddRichText(cfg)     — multiline text block with word-wrap
    • Tab:GroupEnd()           — close the current section group
    • Tab:SetBadge(n)          — add a notification count badge to sidebar tab button
    • Tab:ClearBadge()         — remove the badge
    COMPONENTS API
    • component:DependsOn(other) — auto-disable this component when 'other' is false/off
    WINDOW API
    • Window:SetAccent(Color3) — change accent colour live across the whole window
    • Window:SetIcon(imageId)  — add/change the logo icon in the title bar
    • Window:SetPosition(UDim2)— programmatic reposition with smooth tween
    • Window:Resize(UDim2)     — animated live resize
    • Window:Pin()             — lock the window in place (no dragging)
    • Window:Unpin()           — re-enable dragging
    CONFIG
    • CrispyLib.Config.AutoSave(interval, name) — periodic background auto-save
    • CrispyLib.Config.StopAutoSave()           — cancel auto-save loop
    THEMING
    • CrispyLib.AnimateThemeTransition(presetName, duration) — smooth tween between theme presets

    CHANGELOG v2 → v2.1
    ───────────────────
    • CreateWindow: Size <UDim2> — custom window dimensions
    • CreateWindow: DragStyle <1|2> — 1=titlebar drag (PC), 2=full-window drag (Mobile)
    • CreateWindow: DisabledWindowControls <table> — hide "Exit" and/or "Minimize" buttons
    • CreateWindow: ShowUserInfo <boolean> — avatar + display name in title bar
    • CreateWindow: Keybind <Enum.KeyCode> — toggle visibility on keypress
    • CreateWindow: AcrylicBlur <boolean> — BlurEffect behind the window
    • Window:SetKeybind(<Enum.KeyCode>) — change keybind at runtime

    CHANGELOG v1 → v2
    ──────────────────
    • Architecture: split into Services / Theme / Constants / Helpers / State /
      Config / Notifications / Loader / Window+Tab+Components
    • Universal component API: Set/Get, Enable/Disable, Show/Hide, SetLabel, SetDescription
    • State engine: _state table + _listeners for reactive sync
    • AddItem / RemoveItem / ClearItems on Dropdown
    • Slider: live thumb expand, correct step snapping, SetMin/SetMax/SetRange
    • Input: numeric clamping, min/max/step support, :SetPlaceholder
    • Button: loading state, SetLabel, double-click guard, Enable/Disable
    • Keybind: full flag support + :SetKey
    • ColorPicker: :Set/:Get with flag support
    • Draggable: clamps to viewport so window cannot be dragged off-screen
    • Notifications: dismiss queue, max-stack cap
    • Config: Save/Load/Export/Import/Snapshot/Apply/List/Delete (unchanged API)
    • Memory: connections stored and disconnected on :Destroy()
    • All nil-flag guards are retained from v1 patch
]]

-- ════════════════════════════════════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer

-- ════════════════════════════════════════════════════════════════════════════
--  THEME  (unchanged from v1 – visual parity guaranteed)
-- ════════════════════════════════════════════════════════════════════════════
local Theme = {
    WindowBg      = Color3.fromRGB(26, 26, 28),
    SidebarBg     = Color3.fromRGB(20, 20, 22),
    ContentBg     = Color3.fromRGB(22, 22, 24),
    TitleBarBg    = Color3.fromRGB(24, 24, 26),
    RowBg         = Color3.fromRGB(32, 32, 36),
    RowHover      = Color3.fromRGB(42, 42, 48),

    TitleText     = Color3.fromRGB(235, 235, 240),
    SubtitleText  = Color3.fromRGB(130, 130, 142),
    LabelText     = Color3.fromRGB(215, 215, 220),
    DescText      = Color3.fromRGB(108, 108, 120),
    ValueText     = Color3.fromRGB(160, 160, 172),
    SectionLabel  = Color3.fromRGB(80,  80,  94),
    PlaceholderC  = Color3.fromRGB(90,  90, 104),

    TabHover      = Color3.fromRGB(36, 36, 42),
    Accent        = Color3.fromRGB(10, 132, 255),
    AccentHover   = Color3.fromRGB(32, 150, 255),
    AccentPress   = Color3.fromRGB(0, 106, 210),
    TabActiveText = Color3.fromRGB(255, 255, 255),
    TabInactive   = Color3.fromRGB(185, 185, 198),

    ToggleOff     = Color3.fromRGB(60, 60, 68),
    ToggleKnob    = Color3.fromRGB(255, 255, 255),

    Separator     = Color3.fromRGB(44, 44, 50),
    Border        = Color3.fromRGB(48, 48, 56),
    FocusBorder   = Color3.fromRGB(10, 132, 255),

    DropdownBg    = Color3.fromRGB(28, 28, 32),
    ItemHover     = Color3.fromRGB(44, 44, 52),
    InputBg       = Color3.fromRGB(28, 28, 32),
    ScrollThumb   = Color3.fromRGB(72, 72, 82),

    CloseBtn      = Color3.fromRGB(255,  95,  86),
    MinBtn        = Color3.fromRGB(255, 189,  46),
    MaxBtn        = Color3.fromRGB( 39, 201,  63),

    NotifBg       = Color3.fromRGB(34, 34, 38),
    NotifSuccess  = Color3.fromRGB(48, 209,  88),
    NotifError    = Color3.fromRGB(255, 69,  58),
    NotifInfo     = Color3.fromRGB(10, 132, 255),
    NotifWarn     = Color3.fromRGB(255, 159,  10),

    LoaderBg      = Color3.fromRGB(14, 14, 16),
    LoaderBarBg   = Color3.fromRGB(38, 38, 44),
    LoaderBar     = Color3.fromRGB(10, 132, 255),

    DisabledBg    = Color3.fromRGB(40, 40, 46),
    DisabledText  = Color3.fromRGB(80, 80, 90),
}

-- ════════════════════════════════════════════════════════════════════════════
--  CONSTANTS
-- ════════════════════════════════════════════════════════════════════════════
local WIN_W      = 760
local WIN_H      = 490
local SIDEBAR_W  = 210
local TITLEBAR_H = 50
local ROW_H      = 56
local NOTIF_MAX  = 5

local Z = {
    Window    = 1,
    TitleBar  = 10,
    Sidebar   = 6,
    Content   = 2,
    Popup     = 100,
    PopupItem = 101,
    Notif     = 200,
}

local TI_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_MID  = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_SLOW = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TI_EASE = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- ════════════════════════════════════════════════════════════════════════════
--  LOW-LEVEL HELPERS
-- ════════════════════════════════════════════════════════════════════════════

local function Create(cls, props)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function Tween(obj, goals, ti)
    TweenService:Create(obj, ti or TI_MID, goals):Play()
end

local function Round(f, r)
    Create("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = f })
end

local function Stroke(f, col, thick)
    return Create("UIStroke", {
        Color     = col or Theme.Border,
        Thickness = thick or 1,
        Parent    = f,
    })
end

local function Pad(f, t, b, l, r)
    Create("UIPadding", {
        PaddingTop    = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft   = UDim.new(0, l or 0),
        PaddingRight  = UDim.new(0, r or 0),
        Parent        = f,
    })
end

local function ListLayout(f, dir, gap)
    Create("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0, gap or 0),
        Parent        = f,
    })
end

local function ScrollFrame(parent, z)
    return Create("ScrollingFrame", {
        Size                 = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness   = 3,
        ScrollBarImageColor3 = Theme.ScrollThumb,
        BorderSizePixel      = 0,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ZIndex               = z or Z.Content,
        Parent               = parent,
    })
end

-- Clamp-aware draggable that keeps the frame within the viewport
local function Draggable(handle, frame)
    local dragging  = false
    local winOffset = Vector2.new(0, 0)
    local connections = {}

    connections[#connections+1] = handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local ap   = frame.AbsolutePosition
            local mpos = UserInputService:GetMouseLocation()
            dragging  = true
            -- Store fixed offset: window top-left minus mouse position at click time.
            -- Using GetMouseLocation() keeps both sides in the same coordinate system.
            winOffset = Vector2.new(ap.X - mpos.X, ap.Y - mpos.Y)
        end
    end)

    connections[#connections+1] = UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local mpos = UserInputService:GetMouseLocation()
        local vp   = workspace.CurrentCamera.ViewportSize
        local fw   = frame.AbsoluteSize.X
        local fh   = frame.AbsoluteSize.Y

        local newX = math.clamp(mpos.X + winOffset.X, 0, vp.X - fw)
        local newY = math.clamp(mpos.Y + winOffset.Y, 0, vp.Y - fh)

        frame.Position = UDim2.new(0, newX, 0, newY)
    end)

    connections[#connections+1] = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return connections
end

-- Debounce: ensure a function cannot fire more than once per `delay` seconds
local function Debounce(fn, delay)
    local last = 0
    return function(...)
        local now = os.clock()
        if now - last < delay then return end
        last = now
        return fn(...)
    end
end

local function Throttle(fn, interval)
    interval = interval or 0
    local last = 0
    local queued = false
    local lastArgs
    return function(...)
        if interval <= 0 then return fn(...) end
        local now = os.clock()
        local elapsed = now - last
        if elapsed >= interval then
            last = now
            return fn(...)
        end
        lastArgs = table.pack(...)
        if queued then return end
        queued = true
        task.delay(interval - elapsed, function()
            queued = false
            last = os.clock()
            if lastArgs then
                local args = lastArgs
                lastArgs = nil
                fn(table.unpack(args, 1, args.n))
            end
        end)
    end
end

-- Safe fire: pcall wrapper that prints errors instead of silently swallowing them
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[CrispyLib] Callback error: " .. tostring(err))
    end
    return ok, err
end

local function DisconnectOne(item)
    if not item then return end
    if typeof(item) == "RBXScriptConnection" then
        if item.Connected then item:Disconnect() end
    elseif type(item) == "table" then
        if type(item.Destroy) == "function" then
            item:Destroy()
        elseif type(item.Disconnect) == "function" then
            item:Disconnect()
        elseif type(item.Cleanup) == "function" then
            item:Cleanup()
        end
    elseif typeof(item) == "Instance" then
        if item.Parent then item:Destroy() end
    end
end

local function ShallowCopy(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do out[k] = v end
    return out
end

local function DeepMerge(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == "table" and type(dst[k]) == "table" and typeof(v) ~= "Color3" then
            DeepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function ResolveStyleValue(value)
    if type(value) == "table" and value.Theme then
        return Theme[value.Theme]
    end
    if type(value) == "string" and Theme[value] ~= nil then
        return Theme[value]
    end
    return value
end

local function ApplyStylesToInstance(inst, styles)
    if typeof(inst) ~= "Instance" or type(styles) ~= "table" then return false end
    for prop, value in pairs(styles) do
        pcall(function()
            inst[prop] = ResolveStyleValue(value)
        end)
    end
    return true
end

local function ApplyOpacity(root, opacity)
    if typeof(root) ~= "Instance" then return end
    opacity = math.clamp(tonumber(opacity) or 1, 0, 1)
    local transparency = 1 - opacity
    local items = root:GetDescendants()
    table.insert(items, 1, root)
    for _, inst in ipairs(items) do
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            pcall(function() inst.TextTransparency = transparency end)
            pcall(function()
                if inst.BackgroundTransparency < 1 then inst.BackgroundTransparency = transparency end
            end)
        elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
            pcall(function() inst.ImageTransparency = transparency end)
            pcall(function()
                if inst.BackgroundTransparency < 1 then inst.BackgroundTransparency = transparency end
            end)
        elseif inst:IsA("Frame") or inst:IsA("ScrollingFrame") then
            pcall(function()
                if inst.BackgroundTransparency < 1 then inst.BackgroundTransparency = transparency end
            end)
        elseif inst:IsA("UIStroke") then
            pcall(function() inst.Transparency = transparency end)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  FILESYSTEM CAPABILITY DETECTION
-- ════════════════════════════════════════════════════════════════════════════
local _hasWrite  = type(writefile)  == "function"
local _hasRead   = type(readfile)   == "function"
local _hasList   = type(listfiles)  == "function"
local _hasIsfile = type(isfile)     == "function"
local _hasFolder = type(makefolder) == "function"

-- ════════════════════════════════════════════════════════════════════════════
--  SERIALISATION HELPERS  (Color3 + table round-trips for JSON)
-- ════════════════════════════════════════════════════════════════════════════
local function SerialiseValue(v)
    if typeof(v) == "Color3" then
        return { __type = "Color3", r = v.R, g = v.G, b = v.B }
    elseif type(v) == "table" then
        local out = {}
        for i, x in ipairs(v) do out[i] = SerialiseValue(x) end
        return out
    end
    return v
end

local function DeserialiseValue(v)
    if type(v) == "table" then
        if v.__type == "Color3" then return Color3.new(v.r, v.g, v.b) end
        local out = {}
        for i, x in ipairs(v) do out[i] = DeserialiseValue(x) end
        return out
    end
    return v
end

-- ════════════════════════════════════════════════════════════════════════════
--  STATE ENGINE
--  Central, reactive store for all flagged component values.
--  Replaces the raw _flags table with a proper get/set/subscribe model.
-- ════════════════════════════════════════════════════════════════════════════
local State = {}
State._data      = {}
State._listeners = {}

function State.Get(flag)
    if not flag then return nil end
    return State._data[flag]
end

function State.Set(flag, value)
    if not flag then return end
    local prev = State._data[flag]
    State._data[flag] = value
    local listeners = State._listeners[flag]
    if listeners and prev ~= value then
        for _, fn in ipairs(listeners) do
            SafeCall(fn, value, prev)
        end
    end
end

function State.Subscribe(flag, fn)
    if not flag or type(fn) ~= "function" then return function() end end
    State._listeners[flag] = State._listeners[flag] or {}
    table.insert(State._listeners[flag], fn)
    local alive = true
    return function()
        if not alive then return end
        alive = false
        local listeners = State._listeners[flag]
        if not listeners then return end
        for i, listener in ipairs(listeners) do
            if listener == fn then table.remove(listeners, i); break end
        end
    end
end

function State.Snapshot()
    local snap = {}
    for k, v in pairs(State._data) do
        snap[k] = SerialiseValue(v)
    end
    return snap
end

function State.Apply(snap)
    for flag, raw in pairs(snap) do
        State.Set(flag, DeserialiseValue(raw))
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  COMPONENT REGISTRY  (replaces _flagElements)
--  Maps flag → { Get, Set } accessors for config serialisation.
-- ════════════════════════════════════════════════════════════════════════════
local Registry = {}
Registry._elements = {}
Registry._ignored = {}

function Registry.Register(flag, getter, setter)
    if not flag then return function() end end
    if Registry._elements[flag] then
        warn("[CrispyLib] Duplicate flag registered: " .. tostring(flag))
    end
    local defaultValue
    pcall(function() defaultValue = SerialiseValue(getter()) end)
    Registry._elements[flag] = { Get = getter, Set = setter, Default = defaultValue }
    return function()
        if Registry._elements[flag] and Registry._elements[flag].Get == getter then
            Registry._elements[flag] = nil
        end
    end
end

function Registry.GetAll()
    local out = {}
    for flag, el in pairs(Registry._elements) do
        if not Registry._ignored[flag] then
            out[flag] = SerialiseValue(el.Get())
        end
    end
    return out
end

function Registry.Ignore(flag, state)
    if not flag then return end
    Registry._ignored[flag] = state ~= false or nil
end

function Registry.ResetDefaults()
    for _, el in pairs(Registry._elements) do
        if el.Default ~= nil then SafeCall(el.Set, DeserialiseValue(el.Default)) end
    end
end

function Registry.ApplyAll(snap)
    for flag, raw in pairs(snap) do
        local el = Registry._elements[flag]
        if el then SafeCall(el.Set, DeserialiseValue(raw)) end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  CRISPY LIB  (public namespace)
-- ════════════════════════════════════════════════════════════════════════════
local Notif
local CrispyLib         = {}
CrispyLib._configName   = "CrispyLib"
CrispyLib._connections  = {}
CrispyLib._taskGroups   = {}
CrispyLib._styled       = setmetatable({}, { __mode = "k" })
CrispyLib._themeWatchers = {}
CrispyLib.State         = State
CrispyLib.Theme         = Theme
CrispyLib.ThemePresets  = {}
CrispyLib.DensityPresets = {
    Compact  = { WindowWidth = 720, WindowHeight = 450, RowHeight = 48 },
    Normal   = { WindowWidth = WIN_W, WindowHeight = WIN_H, RowHeight = ROW_H },
    Spacious = { WindowWidth = 820, WindowHeight = 540, RowHeight = 64 },
}

function CrispyLib.CreateTaskGroup(name)
    local group = { Name = name or "TaskGroup", _items = {}, _alive = true }

    function group:Add(item, cleanup)
        if not self._alive then
            DisconnectOne(item)
            return item
        end
        self._items[#self._items + 1] = { Item = item, Cleanup = cleanup }
        return item
    end

    function group:Connect(signal, fn)
        if not self._alive or not signal or type(fn) ~= "function" then return nil end
        return self:Add(signal:Connect(fn))
    end

    function group:Wrap(fn, opts)
        opts = opts or {}
        local once = opts.Once or false
        local debounce = opts.Debounce or 0
        local running = false
        local last = 0
        return function(...)
            if not self._alive or type(fn) ~= "function" then return end
            local now = os.clock()
            if debounce > 0 and now - last < debounce then return end
            if once and running then return end
            last = now
            running = true
            local ok, result = SafeCall(fn, ...)
            running = false
            if ok then return result end
        end
    end

    function group:Spawn(fn, ...)
        if not self._alive or type(fn) ~= "function" then return end
        local args = table.pack(...)
        task.spawn(function()
            if self._alive then SafeCall(fn, table.unpack(args, 1, args.n)) end
        end)
    end

    function group:Delay(seconds, fn, ...)
        if not self._alive or type(fn) ~= "function" then return end
        local args = table.pack(...)
        task.delay(seconds or 0, function()
            if self._alive then SafeCall(fn, table.unpack(args, 1, args.n)) end
        end)
    end

    function group:Loop(interval, fn)
        if type(fn) ~= "function" then return nil end
        local token = { Alive = true }
        self:Add(token, function(t) t.Alive = false end)
        task.spawn(function()
            while self._alive and token.Alive do
                SafeCall(fn, token)
                task.wait(interval or 0)
            end
        end)
        return token
    end

    function group:Cancel(item)
        for i = #self._items, 1, -1 do
            local entry = self._items[i]
            if entry.Item == item then
                if type(entry.Cleanup) == "function" then SafeCall(entry.Cleanup, entry.Item) else DisconnectOne(entry.Item) end
                table.remove(self._items, i)
                return true
            end
        end
        return false
    end

    function group:Cleanup()
        for i = #self._items, 1, -1 do
            local entry = self._items[i]
            if type(entry.Cleanup) == "function" then SafeCall(entry.Cleanup, entry.Item) else DisconnectOne(entry.Item) end
            self._items[i] = nil
        end
    end

    function group:Destroy()
        if not self._alive then return end
        self._alive = false
        self:Cleanup()
    end

    CrispyLib._taskGroups[#CrispyLib._taskGroups + 1] = group
    return group
end

CrispyLib.Tasks = CrispyLib.CreateTaskGroup("CrispyLib")

function CrispyLib.WrapTask(fn, opts)
    -- ════════════════════════════════════════════════════════════════════════════
--  ERROR BOUNDARY
--  CrispyLib.OnError(fn)    – register a global error handler
--  CrispyLib.SafeRun(fn)    – pcall with notification on failure
-- ════════════════════════════════════════════════════════════════════════════
CrispyLib._errorHandlers = {}

function CrispyLib.OnError(fn)
    if type(fn) ~= "function" then return function() end end
    table.insert(CrispyLib._errorHandlers, fn)
    return function()
        for i, h in ipairs(CrispyLib._errorHandlers) do
            if h == fn then table.remove(CrispyLib._errorHandlers, i); break end
        end
    end
end

-- Patch SafeCall to also fire OnError handlers
local _origSafeCall = SafeCall
SafeCall = function(fn, ...)
    local ok, err = _origSafeCall(fn, ...)
    if not ok and #CrispyLib._errorHandlers > 0 then
        for _, h in ipairs(CrispyLib._errorHandlers) do
            pcall(h, err)
        end
    end
    return ok, err
end

function CrispyLib.SafeRun(fn, ...)
    local args = table.pack(...)
    local ok, err = pcall(fn, table.unpack(args, 1, args.n))
    if not ok then
        CrispyLib.Notify({
            Title       = "Script Error",
            Description = tostring(err):sub(1, 120),
            Type        = "error",
            Duration    = 6,
        })
        for _, h in ipairs(CrispyLib._errorHandlers) do pcall(h, err) end
    end
    return ok, err
end

-- ════════════════════════════════════════════════════════════════════════════
--  HTTP MODULE
--  CrispyLib.HTTP.Get(url, callback)
--  CrispyLib.HTTP.Post(url, data, callback)
--  CrispyLib.HTTP.Webhook(url, message, opts)
-- ════════════════════════════════════════════════════════════════════════════
CrispyLib.HTTP = {}

function CrispyLib.HTTP.Get(url, callback)
    callback = callback or function() end
    task.spawn(function()
        local ok, result = pcall(function()
            if type(request) == "function" then
                local res = request({ Url = url, Method = "GET" })
                return res.Body or res.body or ""
            elseif type(game.HttpGet) == "function" then
                return game:HttpGet(url)
            end
            error("No HTTP API available")
        end)
        SafeCall(callback, ok and result or nil, not ok and result or nil)
    end)
end

function CrispyLib.HTTP.Post(url, data, callback)
    callback = callback or function() end
    task.spawn(function()
        local ok, result = pcall(function()
            if type(request) == "function" then
                local body = type(data) == "table"
                    and HttpService:JSONEncode(data)
                    or tostring(data or "")
                local res = request({
                    Url     = url,
                    Method  = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = body,
                })
                return res.Body or res.body or ""
            end
            error("request() not available")
        end)
        SafeCall(callback, ok and result or nil, not ok and result or nil)
    end)
end

function CrispyLib.HTTP.Webhook(url, message, opts)
    opts = opts or {}
    local payload = {
        username   = opts.Username or "CrispyLib",
        avatar_url = opts.Avatar   or "",
        content    = type(message) == "string" and message or nil,
        embeds     = opts.Embeds   or nil,
    }
    if type(message) == "table" then
        payload.embeds = { message }
        payload.content = nil
    end
    CrispyLib.HTTP.Post(url, payload, opts.Callback)
end

-- ════════════════════════════════════════════════════════════════════════════
--  AUTO-UPDATER
--  CrispyLib.Updater.Check(rawUrl, currentVersion, callback)
--  CrispyLib.Updater.AutoUpdate(rawUrl, currentVersion)
-- ════════════════════════════════════════════════════════════════════════════
CrispyLib.Updater = {}

-- Expects the remote URL to serve a plain version string e.g. "2.3.1"
function CrispyLib.Updater.Check(url, currentVersion, callback)
    callback = callback or function() end
    CrispyLib.HTTP.Get(url, function(body, err)
        if err then SafeCall(callback, false, nil, err); return end
        local remote = (body or ""):match("^%s*([%d%.]+)%s*$")
        if not remote then SafeCall(callback, false, nil, "Invalid version format"); return end
        local isNewer = remote ~= tostring(currentVersion or "")
        SafeCall(callback, isNewer, remote, nil)
    end)
end

function CrispyLib.Updater.AutoUpdate(scriptUrl, currentVersion)
    -- scriptUrl: URL that returns the full Lua script (not just the version)
    -- currentVersion: a string/number representing running version
    -- Checks a companion ".version" URL (scriptUrl .. ".version")
    local versionUrl = scriptUrl .. ".version"
    CrispyLib.Updater.Check(versionUrl, currentVersion, function(isNewer, remote)
        if not isNewer then return end
        CrispyLib.Notify({
            Title       = "Update Available",
            Description = "Version " .. tostring(remote) .. " is available. Reloading...",
            Type        = "info",
            Duration    = 4,
        })
        task.delay(1.5, function()
            local ok, result = pcall(function()
                return game:HttpGet(scriptUrl)
            end)
            if ok and result then
                local fn, loadErr = loadstring(result)
                if fn then
                    task.spawn(fn)
                else
                    CrispyLib.Notify({ Title = "Update Failed", Description = tostring(loadErr), Type = "error" })
                end
            end
        end)
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  SYSTEM MODULE
-- ════════════════════════════════════════════════════════════════════════════
CrispyLib.System = {}

function CrispyLib.System.FPS()
    return math.floor(1 / RunService.RenderStepped:Wait())
end

function CrispyLib.System.Ping()
    local ok, stats = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
    end)
    if ok and stats then
        return math.floor(stats:GetValue())
    end
    return -1
end

function CrispyLib.System.Memory()
    local ok, mem = pcall(function()
        return game:GetService("Stats"):GetTotalMemoryUsageMb()
    end)
    return ok and math.floor(mem * 10) / 10 or 0
end

function CrispyLib.System.GetExecutor()
    if type(identifyexecutor) == "function" then
        local ok, name = pcall(identifyexecutor)
        if ok then return name end
    end
    if type(getexecutorname) == "function" then
        local ok, name = pcall(getexecutorname)
        if ok then return name end
    end
    -- Fingerprint known executors by unique globals
    if KRNL_LOADED      then return "Krnl" end
    if syn              then return "Synapse X" end
    if getgenv and getgenv().SW_LOADED then return "Script-Ware" end
    if DELTA_EXECUTOR   then return "Delta" end
    if Fluxus           then return "Fluxus" end
    if MACSPLOIT_GLOBAL then return "MacSploit" end
    return "Unknown"
end

function CrispyLib.System.Capabilities()
    return {
        writefile  = type(writefile)        == "function",
        readfile   = type(readfile)         == "function",
        request    = type(request)          == "function",
        loadstring = type(loadstring)       == "function",
        hookfunction = type(hookfunction)   == "function",
        getgenv    = type(getgenv)          == "function",
        drawing    = type(Drawing)          ~= "nil",
        setclipboard = type(setclipboard)   == "function",
        isfolder   = type(isfolder)         == "function",
        makefolder = type(makefolder)       == "function",
    }
end

function CrispyLib.System.OnFPSDrop(threshold, callback)
    threshold = threshold or 30
    local token = { Alive = true }
    task.spawn(function()
        local lastBelow = false
        while token.Alive do
            local fps = math.floor(1 / RunService.RenderStepped:Wait())
            local below = fps < threshold
            if below and not lastBelow then
                SafeCall(callback, fps, threshold)
            end
            lastBelow = below
        end
    end)
    return function() token.Alive = false end
end

-- StatsBar: floating HUD overlay showing FPS / Ping / Memory
function CrispyLib.System.StatsBar(cfg)
    cfg = cfg or {}
    if CrispyLib.System._statsGui then
        pcall(function() CrispyLib.System._statsGui:Destroy() end)
        CrispyLib.System._statsGui = nil
        CrispyLib.System._statsToken = nil
        if cfg == "destroy" then return end
    end

    local sg = Create("ScreenGui", {
        Name           = "CrispyLib_StatsBar",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true,
        DisplayOrder   = 500,
    })
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local bar = Create("Frame", {
        Size             = UDim2.new(0, 200, 0, 26),
        Position         = cfg.Position or UDim2.new(1, -210, 0, 10),
        BackgroundColor3 = cfg.Background or Color3.fromRGB(18, 18, 20),
        BackgroundTransparency = 0.15,
        BorderSizePixel  = 0,
        ZIndex           = 10,
        Parent           = sg,
    }); Round(bar, 6); Stroke(bar, Theme.Border, 1)

    local function StatLabel(xOffset, color)
        return Create("TextLabel", {
            Size                  = UDim2.new(0, 60, 1, 0),
            Position              = UDim2.new(0, xOffset, 0, 0),
            BackgroundTransparency = 1,
            Text                  = "—",
            TextColor3            = color or Theme.LabelText,
            TextSize              = 11,
            Font                  = Enum.Font.GothamBold,
            TextXAlignment        = Enum.TextXAlignment.Center,
            ZIndex                = 11,
            Parent                = bar,
        })
    end
    local fpsLbl  = StatLabel(2,   Color3.fromRGB(48, 209, 88))
    local pingLbl = StatLabel(68,  Color3.fromRGB(255, 189, 46))
    local memLbl  = StatLabel(134, Color3.fromRGB(10, 132, 255))

    local token = { Alive = true }
    CrispyLib.System._statsToken = token
    CrispyLib.System._statsGui   = sg

    task.spawn(function()
        local fpsAccum, fpsSamples = 0, 0
        while token.Alive and sg and sg.Parent do
            local dt = RunService.RenderStepped:Wait()
            fpsAccum   = fpsAccum + (1 / dt)
            fpsSamples = fpsSamples + 1
            if fpsSamples >= 10 then
                local fps  = math.floor(fpsAccum / fpsSamples)
                local ping = CrispyLib.System.Ping()
                local mem  = CrispyLib.System.Memory()
                pcall(function()
                    fpsLbl.Text  = fps  .. " FPS"
                    pingLbl.Text = (ping >= 0 and ping .. "ms" or "—")
                    memLbl.Text  = mem  .. "MB"
                    -- colour-code FPS
                    fpsLbl.TextColor3 = fps >= 55 and Color3.fromRGB(48,209,88)
                        or fps >= 30 and Color3.fromRGB(255,189,46)
                        or Color3.fromRGB(255,69,58)
                    -- colour-code ping
                    if ping >= 0 then
                        pingLbl.TextColor3 = ping <= 80 and Color3.fromRGB(48,209,88)
                            or ping <= 150 and Color3.fromRGB(255,189,46)
                            or Color3.fromRGB(255,69,58)
                    end
                end)
                fpsAccum, fpsSamples = 0, 0
            end
        end
    end)

    return {
        Destroy = function()
            token.Alive = false
            pcall(function() sg:Destroy() end)
        end,
        SetPosition = function(_, pos) bar.Position = pos end,
    }
end

-- ════════════════════════════════════════════════════════════════════════════
--  PROFILES  (multi-config support)
-- ════════════════════════════════════════════════════════════════════════════
CrispyLib.Config._profile = "default"

function CrispyLib.Config.GetProfile()
    return CrispyLib.Config._profile
end

function CrispyLib.Config.SetProfile(name)
    if not name or name == "" then return false end
    -- Save current profile first
    CrispyLib.Config.Save("profile_" .. CrispyLib.Config._profile)
    -- Switch
    CrispyLib.Config._profile = tostring(name)
    -- Load new profile (silently ok if doesn't exist yet)
    CrispyLib.Config.Load("profile_" .. name)
    return true
end

function CrispyLib.Config.ListProfiles()
    local all = CrispyLib.Config.List()
    local profiles = {}
    for _, name in ipairs(all) do
        local p = name:match("^profile_(.+)$")
        if p then profiles[#profiles + 1] = p end
    end
    if #profiles == 0 then profiles = { "default" } end
    return profiles
end

function CrispyLib.Config.DeleteProfile(name)
    if not name or name == "default" then return false end
    return CrispyLib.Config.Delete("profile_" .. name)
end

-- CreateProfileUI: injects a profile switcher row into any Tab
function CrispyLib.Config.CreateProfileUI(tab)
    if not tab or not tab.AddDropdown then
        warn("[CrispyLib] CreateProfileUI requires a valid Tab object")
        return
    end
    local profiles = CrispyLib.Config.ListProfiles()
    local dd = tab:AddDropdown({
        Name        = "Profile",
        Description = "Switch or save config profiles",
        Options     = profiles,
        Default     = CrispyLib.Config.GetProfile(),
        Callback    = function(v)
            CrispyLib.Config.SetProfile(v)
            CrispyLib.Notify({
                Title       = "Profile Switched",
                Description = "Active profile: " .. tostring(v),
                Type        = "success",
                Duration    = 3,
            })
        end,
    })
    tab:AddButton({
        Name     = "Save Profile",
        Description = "Save current settings to active profile",
        Callback = function()
            CrispyLib.Config.Save("profile_" .. CrispyLib.Config.GetProfile())
            CrispyLib.Notify({ Title = "Saved", Description = "Profile saved.", Type = "success", Duration = 2 })
        end,
    })
    tab:AddButton({
        Name     = "New Profile",
        Description = "Create a new profile (opens input)",
        Callback = function()
            -- Simple name via a new entry; for full UI use an AddInput component
            local name = "Profile " .. tostring(#CrispyLib.Config.ListProfiles() + 1)
            CrispyLib.Config.SetProfile(name)
            local opts = CrispyLib.Config.ListProfiles()
            dd:AddItem(name)
            dd:Set(name)
            CrispyLib.Notify({ Title = "Profile Created", Description = name, Type = "success", Duration = 3 })
        end,
    })
    return dd
end

-- ════════════════════════════════════════════════════════════════════════════
--  DEBUG MODULE
-- ════════════════════════════════════════════════════════════════════════════
CrispyLib.Debug = {}
CrispyLib.Debug._log      = {}
CrispyLib.Debug._logMax   = 200
CrispyLib.Debug._listeners = {}

local DEBUG_LEVELS = { info = "INFO", warn = "WARN", error = "ERR " }

function CrispyLib.Debug.Log(msg, level)
    level = DEBUG_LEVELS[level or "info"] or "INFO"
    local entry = {
        time  = os.date("%H:%M:%S"),
        level = level,
        msg   = tostring(msg or ""),
    }
    table.insert(CrispyLib.Debug._log, 1, entry)
    if #CrispyLib.Debug._log > CrispyLib.Debug._logMax then
        CrispyLib.Debug._log[CrispyLib.Debug._logMax + 1] = nil
    end
    for _, fn in ipairs(CrispyLib.Debug._listeners) do pcall(fn, entry) end
end

function CrispyLib.Debug.Export()
    local lines = {}
    for i = #CrispyLib.Debug._log, 1, -1 do
        local e = CrispyLib.Debug._log[i]
        lines[#lines + 1] = "[" .. e.time .. "] [" .. e.level .. "] " .. e.msg
    end
    local out = table.concat(lines, "
")
    if _hasWrite then
        pcall(writefile, "CrispyLib/debug_log.txt", out)
    end
    return out
end

-- Wire OnError into Debug.Log automatically
CrispyLib.OnError(function(err)
    CrispyLib.Debug.Log(tostring(err), "error")
end)

-- Panel: inject a live flag viewer + log into a Tab
function CrispyLib.Debug.Panel(tab)
    if not tab then return end

    tab:AddSection({ Title = "Live Flags", Description = "Current state of all registered flags" })

    local flagRows = {}
    local flagSection = {}

    local function RefreshFlags()
        local snap = CrispyLib.Config.Snapshot()
        for flag, val in pairs(snap) do
            if not flagRows[flag] then
                local lbl = tab:AddRichText and tab:AddRichText({
                    Text = "<b>" .. flag .. "</b>: " .. tostring(val),
                    RichText = true,
                }) or tab:AddLabel({ Name = flag, Value = tostring(val) })
                flagRows[flag] = lbl
            else
                if flagRows[flag].Set then
                    flagRows[flag]:Set("<b>" .. flag .. "</b>: " .. tostring(val))
                end
            end
        end
    end

    tab:AddButton({
        Name     = "Refresh Flags",
        Callback = RefreshFlags,
    })

    tab:AddDivider and tab:AddDivider({ Label = "Error Log" })
    tab:AddSection({ Title = "Error Log" })

    local logLabel = tab:AddRichText and tab:AddRichText({
        Text     = "No errors logged.",
        RichText = false,
    })

    local function RefreshLog()
        if not logLabel then return end
        local lines = {}
        for i = 1, math.min(10, #CrispyLib.Debug._log) do
            local e = CrispyLib.Debug._log[i]
            lines[#lines + 1] = "[" .. e.time .. "] [" .. e.level .. "] " .. e.msg
        end
        local txt = #lines > 0 and table.concat(lines, "
") or "No logs yet."
        logLabel:Set(txt)
    end

    table.insert(CrispyLib.Debug._listeners, function(_)
        task.defer(RefreshLog)
    end)

    tab:AddButton({
        Name     = "Export Log",
        Callback = function()
            CrispyLib.Debug.Export()
            CrispyLib.Notify({ Title = "Log Exported", Description = "Saved to CrispyLib/debug_log.txt", Type = "success", Duration = 3 })
        end,
    })

    task.defer(RefreshFlags)
    task.defer(RefreshLog)
end

-- Watch: a compact HUD showing specific flags live
function CrispyLib.Debug.Watch(flags, updateInterval)
    updateInterval = updateInterval or 0.5
    local sg = Create("ScreenGui", {
        Name           = "CrispyLib_Watch",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true,
        DisplayOrder   = 600,
    })
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local panel = Create("Frame", {
        Size             = UDim2.new(0, 220, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        Position         = UDim2.new(0, 10, 0.5, 0),
        AnchorPoint      = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(16, 16, 18),
        BackgroundTransparency = 0.1,
        BorderSizePixel  = 0,
        ZIndex           = 10,
        Parent           = sg,
    }); Round(panel, 8); Stroke(panel, Theme.Border, 1)
    ListLayout(panel, Enum.FillDirection.Vertical, 0)
    Pad(panel, 6, 6, 0, 0)

    local rowMap = {}
    for _, flag in ipairs(flags or {}) do
        local row = Create("Frame", {
            Size             = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            ZIndex           = 11,
            Parent           = panel,
        })
        Create("TextLabel", {
            Size                  = UDim2.new(0.55, -8, 1, 0),
            Position              = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text                  = tostring(flag),
            TextColor3            = Theme.SubtitleText,
            TextSize              = 10,
            Font                  = Enum.Font.GothamBold,
            TextXAlignment        = Enum.TextXAlignment.Left,
            ZIndex                = 12,
            Parent                = row,
        })
        local valLbl = Create("TextLabel", {
            Size                  = UDim2.new(0.45, -8, 1, 0),
            Position              = UDim2.new(0.55, 0, 0, 0),
            BackgroundTransparency = 1,
            Text                  = "—",
            TextColor3            = Theme.Accent,
            TextSize              = 10,
            Font                  = Enum.Font.GothamSemibold,
            TextXAlignment        = Enum.TextXAlignment.Right,
            ZIndex                = 12,
            Parent                = row,
        })
        rowMap[flag] = valLbl
    end

    local token = { Alive = true }
    task.spawn(function()
        while token.Alive and sg and sg.Parent do
            for flag, lbl in pairs(rowMap) do
                local v = State.Get(flag)
                pcall(function()
                    lbl.Text = v ~= nil and tostring(v) or "nil"
                end)
            end
            task.wait(updateInterval)
        end
    end)

    return {
        Destroy = function()
            token.Alive = false
            pcall(function() sg:Destroy() end)
        end,
    }
end

return CrispyLib.Tasks:Wrap(fn, opts)
end

function CrispyLib.Spawn(fn, ...)
    return CrispyLib.Tasks:Spawn(fn, ...)
end

function CrispyLib.Delay(seconds, fn, ...)
    return CrispyLib.Tasks:Delay(seconds, fn, ...)
end

function CrispyLib.Loop(interval, fn)
    return CrispyLib.Tasks:Loop(interval, fn)
end

function CrispyLib.GetTheme()
    return ShallowCopy(Theme)
end

function CrispyLib.SetTheme(patch)
    if type(patch) ~= "table" then return false end
    DeepMerge(Theme, patch)
    for _, entry in pairs(CrispyLib._styled) do
        if entry and entry.Instance and entry.Styles then
            ApplyStylesToInstance(entry.Instance, entry.Styles)
        end
    end
    for _, fn in ipairs(CrispyLib._themeWatchers) do SafeCall(fn, Theme) end
    return true
end

CrispyLib.ThemePresets.Default = ShallowCopy(Theme)
CrispyLib.ThemePresets.Midnight = DeepMerge(ShallowCopy(Theme), {
    WindowBg = Color3.fromRGB(15, 18, 28), SidebarBg = Color3.fromRGB(12, 14, 22),
    ContentBg = Color3.fromRGB(14, 17, 26), TitleBarBg = Color3.fromRGB(13, 16, 24),
    RowBg = Color3.fromRGB(22, 26, 38), RowHover = Color3.fromRGB(32, 38, 56),
    Accent = Color3.fromRGB(124, 92, 255), AccentHover = Color3.fromRGB(146, 122, 255),
})
CrispyLib.ThemePresets.Glass = DeepMerge(ShallowCopy(Theme), {
    WindowBg = Color3.fromRGB(28, 31, 38), SidebarBg = Color3.fromRGB(21, 24, 32),
    ContentBg = Color3.fromRGB(24, 27, 35), RowBg = Color3.fromRGB(38, 42, 52),
    Border = Color3.fromRGB(72, 78, 92), Accent = Color3.fromRGB(69, 176, 255),
})
CrispyLib.ThemePresets.HighContrast = DeepMerge(ShallowCopy(Theme), {
    WindowBg = Color3.fromRGB(8, 8, 10), SidebarBg = Color3.fromRGB(0, 0, 0),
    ContentBg = Color3.fromRGB(10, 10, 12), RowBg = Color3.fromRGB(24, 24, 28),
    TitleText = Color3.fromRGB(255, 255, 255), LabelText = Color3.fromRGB(245, 245, 248),
    Accent = Color3.fromRGB(0, 170, 255), Border = Color3.fromRGB(110, 110, 125),
})

function CrispyLib.RegisterThemePreset(name, preset)
    if type(name) ~= "string" or type(preset) ~= "table" then return false end
    CrispyLib.ThemePresets[name] = preset
    return true
end

function CrispyLib.SetThemePreset(name)
    local preset = CrispyLib.ThemePresets[name]
    if not preset then return false end
    return CrispyLib.SetTheme(ShallowCopy(preset))
end

function CrispyLib.ListThemePresets()
    local names = {}
    for name in pairs(CrispyLib.ThemePresets) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function CrispyLib.SetDensity(nameOrConfig)
    local cfg = type(nameOrConfig) == "table" and nameOrConfig or CrispyLib.DensityPresets[nameOrConfig or "Normal"]
    if not cfg then return false end
    WIN_W = cfg.WindowWidth or WIN_W
    WIN_H = cfg.WindowHeight or WIN_H
    ROW_H = cfg.RowHeight or ROW_H
    return true
end

function CrispyLib.OnThemeChanged(fn)
    if type(fn) ~= "function" then return function() end end
    table.insert(CrispyLib._themeWatchers, fn)
    local alive = true
    return function()
        if not alive then return end
        alive = false
        for i, watcher in ipairs(CrispyLib._themeWatchers) do
            if watcher == fn then table.remove(CrispyLib._themeWatchers, i); break end
        end
    end
end

function CrispyLib.Style(target, styles, persistent)
    local inst = target
    if type(target) == "table" then inst = target.Instance or target._row or target._instance end
    if not ApplyStylesToInstance(inst, styles) then return target end
    if persistent then CrispyLib._styled[inst] = { Instance = inst, Styles = styles }
    end
    return target
end

function CrispyLib.SetOpacity(target, opacity)
    local inst = target
    if type(target) == "table" then inst = target.Instance or target._row or target._instance end
    ApplyOpacity(inst, opacity)
    return target
end

function CrispyLib.DestroyAll()
    for i = #CrispyLib._taskGroups, 1, -1 do
        local group = CrispyLib._taskGroups[i]
        if group and group.Destroy then group:Destroy() end
        CrispyLib._taskGroups[i] = nil
    end
    if Notif and Notif._gui then pcall(function() Notif._gui:Destroy() end) end
end

-- Backward-compat shims so any v1 code that reads _flags directly still works
CrispyLib._flags = setmetatable({}, {
    __index    = function(_, k) return State.Get(k) end,
    __newindex = function(_, k, v) State.Set(k, v) end,
})

-- ════════════════════════════════════════════════════════════════════════════
--  CONFIG / PERSISTENCE
-- ════════════════════════════════════════════════════════════════════════════
local function CFG_DIR()  return "CrispyLib/" .. CrispyLib._configName end
local function CFG_PATH(n) return CFG_DIR() .. "/" .. n .. ".json" end
local function MKDIR()
    if _hasFolder then
        pcall(makefolder, "CrispyLib")
        pcall(makefolder, CFG_DIR())
    end
end

CrispyLib.Config = {}
CrispyLib.Config.Version = 1
CrispyLib.Config._migrations = {}

function CrispyLib.Config.SetVersion(version)
    CrispyLib.Config.Version = tonumber(version) or CrispyLib.Config.Version
end

function CrispyLib.Config.RegisterMigration(fromVersion, toVersion, fn)
    if type(fn) ~= "function" then return false end
    CrispyLib.Config._migrations[#CrispyLib.Config._migrations + 1] = {
        From = tonumber(fromVersion) or 0,
        To = tonumber(toVersion) or 0,
        Fn = fn,
    }
    table.sort(CrispyLib.Config._migrations, function(a, b) return a.From < b.From end)
    return true
end

function CrispyLib.Config.Migrate(snapshot, fromVersion)
    local version = tonumber(fromVersion) or 0
    for _, migration in ipairs(CrispyLib.Config._migrations) do
        if version <= migration.From and migration.To <= CrispyLib.Config.Version then
            local ok, nextSnap = SafeCall(migration.Fn, snapshot, version)
            if ok and type(nextSnap) == "table" then snapshot = nextSnap end
            version = migration.To
        end
    end
    return snapshot
end

function CrispyLib.Config.Ignore(flag, state)
    Registry.Ignore(flag, state)
end

function CrispyLib.Config.ResetDefaults()
    Registry.ResetDefaults()
end

function CrispyLib.Config.Snapshot()
    return Registry.GetAll()
end

function CrispyLib.Config.Apply(snap)
    Registry.ApplyAll(snap)
end

function CrispyLib.Config.Export()
    local ok, json = pcall(function()
        return HttpService:JSONEncode(CrispyLib.Config.Snapshot())
    end)
    return ok and json or "{}"
end

function CrispyLib.Config.ExportBundle()
    local ok, json = pcall(function()
        return HttpService:JSONEncode({
            __crispy = true,
            version = CrispyLib.Config.Version,
            configName = CrispyLib._configName,
            values = CrispyLib.Config.Snapshot(),
        })
    end)
    return ok and json or "{}"
end

function CrispyLib.Config.Import(json)
    local ok, tbl = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    if ok and type(tbl) == "table" then
        if tbl.__crispy and type(tbl.values) == "table" then
            tbl.values = CrispyLib.Config.Migrate(tbl.values, tbl.version)
            CrispyLib.Config.Apply(tbl.values)
        else
            CrispyLib.Config.Apply(tbl)
        end
        return true
    end
    return false
end

function CrispyLib.Config.Save(name)
    name = name or "default"
    if not _hasWrite then
        CrispyLib._mem           = CrispyLib._mem or {}
        CrispyLib._mem[name]     = CrispyLib.Config.Snapshot()
        return true
    end
    MKDIR()
    return pcall(writefile, CFG_PATH(name), CrispyLib.Config.Export())
end

function CrispyLib.Config.Load(name)
    name = name or "default"
    if not _hasRead then
        if CrispyLib._mem and CrispyLib._mem[name] then
            CrispyLib.Config.Apply(CrispyLib._mem[name])
            return true
        end
        return false
    end
    local path = CFG_PATH(name)
    if _hasIsfile and not isfile(path) then return false end
    local ok, json = pcall(readfile, path)
    if not ok then return false end
    return CrispyLib.Config.Import(json)
end

function CrispyLib.Config.List()
    if not _hasList then
        local list = {}
        if CrispyLib._mem then
            for k in pairs(CrispyLib._mem) do list[#list+1] = k end
        end
        return list
    end
    MKDIR()
    local ok, files = pcall(listfiles, CFG_DIR())
    if not ok then return {} end
    local names = {}
    for _, path in ipairs(files) do
        local nm = path:match("([^/\\]+)%.json$")
        if nm then names[#names+1] = nm end
    end
    return names
end

function CrispyLib.Config.Delete(name)
    if not name then return false end
    if not _hasWrite then
        if CrispyLib._mem then CrispyLib._mem[name] = nil end
        return true
    end
    local path = CFG_PATH(name)
    if type(delfile) == "function" then
        pcall(delfile, path)
    else
        pcall(writefile, path, "{}")
    end
    return true
end

-- Auto-save: periodic background save loop
CrispyLib.Config._autoSaveToken = nil

function CrispyLib.Config.AutoSave(interval, name)
    interval = math.max(tonumber(interval) or 30, 5)
    name     = name or "default"
    if CrispyLib.Config._autoSaveToken then
        CrispyLib.Config._autoSaveToken.Alive = false
    end
    local token = { Alive = true }
    CrispyLib.Config._autoSaveToken = token
    task.spawn(function()
        while token.Alive do
            task.wait(interval)
            if not token.Alive then break end
            CrispyLib.Config.Save(name)
        end
    end)
    return token
end

function CrispyLib.Config.StopAutoSave()
    if CrispyLib.Config._autoSaveToken then
        CrispyLib.Config._autoSaveToken.Alive = false
        CrispyLib.Config._autoSaveToken = nil
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  NOTIFICATION SYSTEM
--  Improved: max-stack enforcement, dismiss queue, unique IDs
-- ════════════════════════════════════════════════════════════════════════════
Notif = {}
Notif._gui     = nil
Notif._container = nil
Notif._count   = 0

local NOTIF_TYPE_COLOR = {
    info    = Theme.NotifInfo,
    success = Theme.NotifSuccess,
    error   = Theme.NotifError,
    warn    = Theme.NotifWarn,
}

local function EnsureNotifGui()
    if Notif._gui and Notif._gui.Parent then return end

    local sg = Create("ScreenGui", {
        Name             = "CrispyLib_Notifs",
        ResetOnSpawn     = false,
        ZIndexBehavior   = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset   = true,
        DisplayOrder     = 1000,
    })
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local con = Create("Frame", {
        Size                 = UDim2.new(0, 300, 1, 0),
        Position             = UDim2.new(1, -316, 0, 0),
        BackgroundTransparency = 1,
        ZIndex               = Z.Notif,
        Parent               = sg,
    })
    ListLayout(con, Enum.FillDirection.Vertical, 8)
    Pad(con, 16, 16, 0, 0)

    Notif._gui       = sg
    Notif._container = con
end

function CrispyLib.Notify(cfg)
    cfg = cfg or {}
    EnsureNotifGui()

    if Notif._count >= NOTIF_MAX then return end
    Notif._count = Notif._count + 1

    local accentColor = NOTIF_TYPE_COLOR[cfg.Type or "info"] or Theme.NotifInfo
    local duration    = cfg.Duration or 4

    local card = Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 74),
        BackgroundColor3 = Theme.NotifBg,
        BorderSizePixel  = 0,
        ZIndex           = Z.Notif + 1,
        Parent           = Notif._container,
    })
    Round(card, 10)
    Stroke(card, Theme.Border, 1)

    Create("Frame", {
        Size             = UDim2.new(0, 3, 1, -18),
        Position         = UDim2.new(0, 9, 0.5, 0),
        AnchorPoint      = Vector2.new(0, 0.5),
        BackgroundColor3 = accentColor,
        BorderSizePixel  = 0,
        ZIndex           = Z.Notif + 2,
        Parent           = card,
    }); Round(card:FindFirstChildOfClass("Frame"), 2)

    Create("TextLabel", {
        Size                  = UDim2.new(1, -36, 0, 20),
        Position              = UDim2.new(0, 22, 0, 12),
        BackgroundTransparency = 1,
        Text                  = cfg.Title or "Notification",
        TextColor3            = Theme.TitleText,
        TextSize              = 13,
        Font                  = Enum.Font.GothamBold,
        TextXAlignment        = Enum.TextXAlignment.Left,
        ZIndex                = Z.Notif + 2,
        Parent                = card,
    })
    Create("TextLabel", {
        Size                  = UDim2.new(1, -36, 0, 26),
        Position              = UDim2.new(0, 22, 0, 32),
        BackgroundTransparency = 1,
        Text                  = cfg.Description or "",
        TextColor3            = Theme.DescText,
        TextSize              = 11,
        Font                  = Enum.Font.Gotham,
        TextXAlignment        = Enum.TextXAlignment.Left,
        TextWrapped           = true,
        ZIndex                = Z.Notif + 2,
        Parent                = card,
    })

    local progressBg = Create("Frame", {
        Size             = UDim2.new(1, -18, 0, 3),
        Position         = UDim2.new(0, 9, 1, -5),
        BackgroundColor3 = Theme.LoaderBarBg,
        BorderSizePixel  = 0,
        ZIndex           = Z.Notif + 2,
        Parent           = card,
    }); Round(progressBg, 2)

    local progressFill = Create("Frame", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = accentColor,
        BorderSizePixel  = 0,
        ZIndex           = Z.Notif + 2,
        Parent           = progressBg,
    }); Round(progressFill, 2)

    local closeBtn = Create("TextButton", {
        Size                  = UDim2.new(0, 18, 0, 18),
        Position              = UDim2.new(1, -24, 0, 8),
        BackgroundTransparency = 1,
        Text                  = "✕",
        TextColor3            = Theme.SubtitleText,
        TextSize              = 10,
        Font                  = Enum.Font.GothamBold,
        BorderSizePixel       = 0,
        ZIndex                = Z.Notif + 3,
        Parent                = card,
    })

    -- Animate in
    card.Position = UDim2.new(1, 20, 0, 0)
    Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, TI_EASE)
    Tween(progressFill,
        { Size = UDim2.new(0, 0, 1, 0) },
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    )

    local dismissed = false
    local function Dismiss()
        if dismissed then return end
        dismissed = true
        Notif._count = math.max(0, Notif._count - 1)
        Tween(card, { Position = UDim2.new(1, 20, 0, 0) }, TI_MID)
        task.delay(0.25, function() pcall(function() card:Destroy() end) end)
    end

    closeBtn.MouseButton1Click:Connect(Dismiss)
    task.delay(duration, Dismiss)
end

-- ════════════════════════════════════════════════════════════════════════════
--  LOADING SCREEN
-- ════════════════════════════════════════════════════════════════════════════
function CrispyLib.CreateLoadingScreen(cfg)
    cfg = cfg or {}
    local title   = cfg.Title       or "Loading"
    local sub     = cfg.Subtitle    or ""
    local logoId  = cfg.LogoId      or ""
    local minTime = cfg.MinimumTime or 0
    local startAt = os.clock()

    local sg = Create("ScreenGui", {
        Name           = "CrispyLib_Loader",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true,
        DisplayOrder   = 2000,
    })
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local bg = Create("Frame", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.LoaderBg,
        BorderSizePixel  = 0,
        ZIndex           = 1,
        Parent           = sg,
    })
    Create("UIGradient", {
        Color    = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 24)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 14)),
        }),
        Rotation = 140,
        Parent   = bg,
    })

    local center = Create("Frame", {
        Size                 = UDim2.new(0, 360, 0, 280),
        Position             = UDim2.new(0.5, -180, 0.5, -140),
        BackgroundTransparency = 1,
        ZIndex               = 2,
        Parent               = bg,
    })

    local yOff = 0
    if logoId ~= "" then
        local logoFrame = Create("Frame", {
            Size             = UDim2.new(0, 72, 0, 72),
            Position         = UDim2.new(0.5, -36, 0, 0),
            BackgroundColor3 = Color3.fromRGB(28, 28, 34),
            BorderSizePixel  = 0,
            ZIndex           = 3,
            Parent           = center,
        }); Round(logoFrame, 18)
        Create("ImageLabel", {
            Size                 = UDim2.new(0, 56, 0, 56),
            Position             = UDim2.new(0.5, -28, 0.5, -28),
            BackgroundTransparency = 1,
            Image                = logoId,
            ZIndex               = 4,
            Parent               = logoFrame,
        })
        yOff = 84
    end

    Create("TextLabel", {
        Size                  = UDim2.new(1, 0, 0, 34),
        Position              = UDim2.new(0, 0, 0, yOff),
        BackgroundTransparency = 1,
        Text                  = title,
        TextColor3            = Theme.TitleText,
        TextSize              = 26,
        Font                  = Enum.Font.GothamBold,
        TextXAlignment        = Enum.TextXAlignment.Center,
        ZIndex                = 3,
        Parent                = center,
    })
    local statusLbl = Create("TextLabel", {
        Size                  = UDim2.new(1, 0, 0, 18),
        Position              = UDim2.new(0, 0, 0, yOff + 38),
        BackgroundTransparency = 1,
        Text                  = sub,
        TextColor3            = Theme.SubtitleText,
        TextSize              = 13,
        Font                  = Enum.Font.Gotham,
        TextXAlignment        = Enum.TextXAlignment.Center,
        ZIndex                = 3,
        Parent                = center,
    })
    local barBg = Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 5),
        Position         = UDim2.new(0, 0, 0, yOff + 72),
        BackgroundColor3 = Theme.LoaderBarBg,
        BorderSizePixel  = 0,
        ZIndex           = 3,
        Parent           = center,
    }); Round(barBg, 3)
    local barFill = Create("Frame", {
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.LoaderBar,
        BorderSizePixel  = 0,
        ZIndex           = 4,
        Parent           = barBg,
    }); Round(barFill, 3)

    local msgLbl = Create("TextLabel", {
        Size                  = UDim2.new(1, 0, 0, 16),
        Position              = UDim2.new(0, 0, 0, yOff + 86),
        BackgroundTransparency = 1,
        Text                  = "",
        TextColor3            = Theme.DescText,
        TextSize              = 11,
        Font                  = Enum.Font.Gotham,
        TextXAlignment        = Enum.TextXAlignment.Center,
        ZIndex                = 3,
        Parent                = center,
    })
    local taskList = Create("Frame", {
        Size              = UDim2.new(1, 0, 0, 120),
        Position          = UDim2.new(0, 0, 0, yOff + 110),
        BackgroundTransparency = 1,
        ClipsDescendants  = true,
        ZIndex            = 3,
        Parent            = center,
    }); ListLayout(taskList, Enum.FillDirection.Vertical, 4)

    -- Pulse animation task
    task.spawn(function()
        while sg and sg.Parent do
            Tween(barFill, { BackgroundColor3 = Color3.fromRGB(48, 168, 255) },
                TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
            task.wait(1)
            if not (sg and sg.Parent) then break end
            Tween(barFill, { BackgroundColor3 = Theme.LoaderBar },
                TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
            task.wait(1)
        end
    end)

    local Loader = {}

    function Loader:SetProgress(pct)
        pct = math.clamp(pct, 0, 1)
        Tween(barFill, { Size = UDim2.new(pct, 0, 1, 0) },
            TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    end

    function Loader:SetStatus(text)
        msgLbl.Text = tostring(text or "")
    end

    function Loader:AddTask(text)
        Create("TextLabel", {
            Size                  = UDim2.new(1, 0, 0, 15),
            BackgroundTransparency = 1,
            Text                  = "✓  " .. tostring(text),
            TextColor3            = Theme.DescText,
            TextSize              = 11,
            Font                  = Enum.Font.Gotham,
            TextXAlignment        = Enum.TextXAlignment.Center,
            ZIndex                = 4,
            Parent                = taskList,
        })
    end

    function Loader:Finish(callback)
        local remaining = math.max(0, minTime - (os.clock() - startAt))
        task.delay(remaining, function()
            self:SetProgress(1)
            task.wait(0.25)
            Tween(bg, { BackgroundTransparency = 1 }, TI_MID)
            for _, d in ipairs(bg:GetDescendants()) do
                if d:IsA("TextLabel") then
                    pcall(Tween, d, { TextTransparency = 1 }, TI_MID)
                elseif d:IsA("ImageLabel") then
                    pcall(Tween, d, { ImageTransparency = 1 }, TI_MID)
                elseif d:IsA("Frame") and d ~= bg then
                    pcall(Tween, d, { BackgroundTransparency = 1 }, TI_MID)
                end
            end
            task.delay(0.35, function()
                pcall(function() sg:Destroy() end)
                if callback then SafeCall(callback) end
            end)
        end)
    end

    return Loader
end

-- ════════════════════════════════════════════════════════════════════════════
--  UNIVERSAL COMPONENT MIXIN
--  Attaches Show/Hide/Enable/Disable/SetLabel/SetDescription to any component.
-- ════════════════════════════════════════════════════════════════════════════
local function ApplyMixin(obj, row, nameLbl, descLbl)
    obj.Instance = row
    obj._row = row
    obj._label = nameLbl
    obj._description = descLbl
    obj._destroyed = false
    function obj:Show()
        if row then row.Visible = true end
        return self
    end
    function obj:Hide()
        if row then row.Visible = false end
        return self
    end
    function obj:SetVisible(state)
        if row then row.Visible = not not state end
        return self
    end
    function obj:ToggleVisible()
        if row then row.Visible = not row.Visible end
        return self
    end
    function obj:IsVisible()
        return row and row.Visible or false
    end
    function obj:SetLabel(text)
        if nameLbl then nameLbl.Text = tostring(text or "") end
        return self
    end
    function obj:SetDescription(text)
        if descLbl then descLbl.Text = tostring(text or "") end
        return self
    end
    function obj:SetStyle(styles, persistent)
        CrispyLib.Style(row, styles, persistent)
        return self
    end
    function obj:SetOpacity(opacity)
        CrispyLib.SetOpacity(row, opacity)
        return self
    end

    function obj:SetTooltip(text)
        if not row then return self end
        local old = row:FindFirstChild("Tooltip")
        if old then old:Destroy() end
        if text == nil or text == "" then return self end
        local tip = Create("TextLabel", {
            Name = "Tooltip",
            Size = UDim2.new(0, 220, 0, 28),
            Position = UDim2.new(1, -230, 0, -30),
            BackgroundColor3 = Theme.DropdownBg,
            BackgroundTransparency = 0.02,
            BorderSizePixel = 0,
            Text = tostring(text),
            TextColor3 = Theme.LabelText,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            Visible = false,
            ZIndex = Z.Popup + 10,
            Parent = row,
        })
        Round(tip, 6); Stroke(tip, Theme.Border, 1)
        self._tasks:Connect(row.MouseEnter, function() tip.Visible = true end)
        self._tasks:Connect(row.MouseLeave, function() tip.Visible = false end)
        return self
    end
    obj._tasks = CrispyLib.CreateTaskGroup("Component")
    obj._destroyCallbacks = {}
    obj._changeListeners = {}
    if row then
        obj._tasks:Connect(row.Destroying, function()
            if obj._destroyed then return end
            obj._destroyed = true
            for _, fn in ipairs(obj._destroyCallbacks) do SafeCall(fn, obj) end
            obj._tasks:Destroy()
        end)
    end
    function obj:Connect(signal, fn)
        return self._tasks:Connect(signal, fn)
    end
    function obj:TaskGroup(name)
        local group = CrispyLib.CreateTaskGroup(name or "ComponentTask")
        self._tasks:Add(group)
        return group
    end
    function obj:OnDestroy(fn)
        if type(fn) ~= "function" then return function() end end
        table.insert(self._destroyCallbacks, fn)
        return function()
            for i, cb in ipairs(self._destroyCallbacks) do
                if cb == fn then table.remove(self._destroyCallbacks, i); break end
            end
        end
    end
    function obj:OnChanged(fn)
        if type(fn) ~= "function" then return function() end end
        if self.Flag then return CrispyLib.Watch(self.Flag, fn) end
        table.insert(self._changeListeners, fn)
        return function()
            for i, cb in ipairs(self._changeListeners) do
                if cb == fn then table.remove(self._changeListeners, i); break end
            end
        end
    end
    function obj:_FireChanged(value, previous)
        for _, fn in ipairs(self._changeListeners) do SafeCall(fn, value, previous) end
    end
    function obj:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        for _, fn in ipairs(self._destroyCallbacks) do SafeCall(fn, self) end
        self._tasks:Destroy()
        if row then pcall(function() row:Destroy() end) end
    end
    if not obj.Enable  then function obj:Enable() return self end end
    if not obj.Disable then function obj:Disable() return self end end

    -- DependsOn: auto-disable this component when another component is false/off
    function obj:DependsOn(other)
        if not other or not other.Get then return self end
        local function _sync(v)
            if v then self:Enable() else self:Disable() end
        end
        _sync(other:Get())
        if other.Flag then
            self._tasks:Add(State.Subscribe(other.Flag, function(v) _sync(v) end))
        else
            table.insert(other._changeListeners, function(v) _sync(v) end)
        end
        return self
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  WINDOW
-- ════════════════════════════════════════════════════════════════════════════
function CrispyLib.CreateWindow(cfg)
    cfg          = cfg or {}
    local title      = cfg.Title      or "Crispy Hub"
    local subtitle   = cfg.Subtitle   or ""
    local configName = cfg.ConfigName
    local autoLoad   = cfg.AutoLoad   or false

    -- New v2.1 window options
    local cfgSize        = cfg.Size       -- UDim2 or nil
    local cfgDragStyle   = cfg.DragStyle  or 1          -- 1 = titlebar, 2 = whole window
    local cfgDisabled    = cfg.DisabledWindowControls or {}
    local cfgShowUser    = cfg.ShowUserInfo or false
    local cfgKeybind     = cfg.Keybind    -- Enum.KeyCode or nil
    local cfgAcrylic     = cfg.AcrylicBlur or false

    -- Build a lookup for disabled controls
    local _disabledCtrl  = {}
    for _, v in ipairs(cfgDisabled) do _disabledCtrl[v:lower()] = true end

    if configName then CrispyLib._configName = configName end

    local sg = Create("ScreenGui", {
        Name           = "CrispyLib_" .. title:gsub("%s+", ""),
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true,
        DisplayOrder   = 999,
    })
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local windowTasks = CrispyLib.CreateTaskGroup("Window:" .. title)
    windowTasks:Connect(sg.Destroying, function()
        windowTasks:Destroy()
    end)

    -- Resolve window dimensions from Size or global constants
    local _winW = WIN_W
    local _winH = WIN_H
    if cfgSize then
        _winW = cfgSize.X.Offset ~= 0 and cfgSize.X.Offset or WIN_W
        _winH = cfgSize.Y.Offset ~= 0 and cfgSize.Y.Offset or WIN_H
    end

    local window = Create("Frame", {
        Name             = "Window",
        Size             = UDim2.new(0, _winW, 0, _winH),
        Position         = UDim2.new(0.5, -_winW / 2, 0.5, -_winH / 2),
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = Z.Window,
        Parent           = sg,
    })
    Round(window, 12)
    Stroke(window, Color3.fromRGB(50, 50, 58), 1)
    window.BackgroundTransparency = 0.8
    Tween(window, { BackgroundTransparency = 0 }, TI_EASE)

    -- ── Title bar ──────────────────────────────────────────────────────────
    local titleBar = Create("Frame", {
        Name             = "TitleBar",
        Size             = UDim2.new(1, 0, 0, TITLEBAR_H),
        BackgroundColor3 = Theme.TitleBarBg,
        BorderSizePixel  = 0,
        ZIndex           = Z.TitleBar,
        Parent           = window,
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = titleBar })
    Create("Frame", {
        Size             = UDim2.new(1, 0, 0.5, 0),
        Position         = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.TitleBarBg,
        BorderSizePixel  = 0,
        ZIndex           = Z.TitleBar,
        Parent           = titleBar,
    })
    Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Separator,
        BorderSizePixel  = 0,
        ZIndex           = Z.TitleBar + 1,
        Parent           = titleBar,
    })

    local function TitleBtn(col, parent)
        local f = Create("Frame", {
            Size             = UDim2.new(0, 13, 0, 13),
            BackgroundColor3 = col,
            BorderSizePixel  = 0,
            ZIndex           = Z.TitleBar + 1,
            Parent           = parent,
        })
        Round(f, 7)
        return f
    end

    local btnRow = Create("Frame", {
        Size                 = UDim2.new(0, 56, 0, 14),
        Position             = UDim2.new(0, 14, 0.5, -7),
        BackgroundTransparency = 1,
        ZIndex               = Z.TitleBar + 1,
        Parent               = titleBar,
    })
    ListLayout(btnRow, Enum.FillDirection.Horizontal, 8)
    local closeBtn = TitleBtn(Theme.CloseBtn, btnRow)
    local minBtn   = TitleBtn(Theme.MinBtn,   btnRow)
    TitleBtn(Theme.MaxBtn, btnRow)

    -- Hide traffic-light buttons per DisabledWindowControls
    if _disabledCtrl["exit"] or _disabledCtrl["close"] then
        closeBtn.Visible = false
    end
    if _disabledCtrl["minimize"] or _disabledCtrl["minimise"] then
        minBtn.Visible = false
    end

    local sbToggle = Create("TextButton", {
        Size                  = UDim2.new(0, 26, 0, 26),
        Position              = UDim2.new(0, 86, 0.5, -13),
        BackgroundColor3      = Theme.TabHover,
        BackgroundTransparency = 1,
        Text                  = "⊟",
        TextColor3            = Theme.SubtitleText,
        TextSize              = 15,
        Font                  = Enum.Font.GothamBold,
        BorderSizePixel       = 0,
        AutoButtonColor       = false,
        ZIndex                = Z.TitleBar + 1,
        Parent                = titleBar,
    }); Round(sbToggle, 6)
    sbToggle.MouseEnter:Connect(function() Tween(sbToggle, { BackgroundTransparency = 0.55 }, TI_FAST) end)
    sbToggle.MouseLeave:Connect(function() Tween(sbToggle, { BackgroundTransparency = 1 }, TI_FAST) end)

    local _history = {}
    local _histIdx = 0

    local function NavBtn(text, xPos)
        return Create("TextButton", {
            Size                  = UDim2.new(0, 22, 0, 26),
            Position              = UDim2.new(0, xPos, 0.5, -13),
            BackgroundTransparency = 1,
            Text                  = text,
            TextColor3            = Theme.SubtitleText,
            TextSize              = 21,
            Font                  = Enum.Font.GothamBold,
            BorderSizePixel       = 0,
            AutoButtonColor       = false,
            ZIndex                = Z.TitleBar + 1,
            Parent                = titleBar,
        })
    end
    local backBtn = NavBtn("‹", 120)
    local fwdBtn  = NavBtn("›", 144)

    local titleFrame = Create("Frame", {
        Size                 = UDim2.new(0, 220, 1, 0),
        Position             = UDim2.new(0.5, -110, 0, 0),
        BackgroundTransparency = 1,
        ZIndex               = Z.TitleBar + 1,
        Parent               = titleBar,
    })
    Create("TextLabel", {
        Size                  = UDim2.new(1, 0, 0, 18),
        Position              = UDim2.new(0, 0, 0.5, -19),
        BackgroundTransparency = 1,
        Text                  = title,
        TextColor3            = Theme.TitleText,
        TextSize              = 14,
        Font                  = Enum.Font.GothamBold,
        TextXAlignment        = Enum.TextXAlignment.Center,
        ZIndex                = Z.TitleBar + 1,
        Parent                = titleFrame,
    })
    Create("TextLabel", {
        Size                  = UDim2.new(1, 0, 0, 14),
        Position              = UDim2.new(0, 0, 0.5, 1),
        BackgroundTransparency = 1,
        Text                  = subtitle,
        TextColor3            = Theme.SubtitleText,
        TextSize              = 11,
        Font                  = Enum.Font.Gotham,
        TextXAlignment        = Enum.TextXAlignment.Center,
        ZIndex                = Z.TitleBar + 1,
        Parent                = titleFrame,
    })

    -- ── Search ─────────────────────────────────────────────────────────────
    local searchBg = Create("Frame", {
        Size             = UDim2.new(0, 155, 0, 28),
        Position         = UDim2.new(1, -168, 0.5, -14),
        BackgroundColor3 = Theme.InputBg,
        BorderSizePixel  = 0,
        ZIndex           = Z.TitleBar + 1,
        Parent           = titleBar,
    }); Round(searchBg, 8)
    local searchStroke = Stroke(searchBg, Theme.Border, 1)
    Create("TextLabel", {
        Size                  = UDim2.new(0, 22, 1, 0),
        Position              = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text                  = "⌕",
        TextColor3            = Theme.PlaceholderC,
        TextSize              = 15,
        Font                  = Enum.Font.Gotham,
        ZIndex                = Z.TitleBar + 2,
        Parent                = searchBg,
    })
    local searchBox = Create("TextBox", {
        Size                  = UDim2.new(1, -28, 1, 0),
        Position              = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText       = "Search",
        PlaceholderColor3     = Theme.PlaceholderC,
        Text                  = "",
        TextColor3            = Theme.LabelText,
        TextSize              = 12,
        Font                  = Enum.Font.Gotham,
        TextXAlignment        = Enum.TextXAlignment.Left,
        ClearTextOnFocus      = false,
        ZIndex                = Z.TitleBar + 2,
        Parent                = searchBg,
    })
    searchBox.Focused:Connect(function() Tween(searchStroke, { Color = Theme.FocusBorder }, TI_FAST) end)
    searchBox.FocusLost:Connect(function() Tween(searchStroke, { Color = Theme.Border }, TI_FAST) end)

    -- ── Sidebar ────────────────────────────────────────────────────────────
    local sidebar = Create("Frame", {
        Name             = "Sidebar",
        Size             = UDim2.new(0, SIDEBAR_W, 1, -TITLEBAR_H),
        Position         = UDim2.new(0, 0, 0, TITLEBAR_H),
        BackgroundColor3 = Theme.SidebarBg,
        BorderSizePixel  = 0,
        ZIndex           = Z.Sidebar,
        Parent           = window,
    })
    -- Anti-corner caps: UICorner rounds all 4 corners; we square off 3,
    -- leaving only bottom-left rounded to match the window's corner.
    Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = sidebar })
    local function SidebarCap(pos)
        Create("Frame", {
            Size             = UDim2.new(0, 12, 0, 12),
            Position         = pos,
            BackgroundColor3 = Theme.SidebarBg,
            BorderSizePixel  = 0,
            ZIndex           = Z.Sidebar + 2,
            Parent           = sidebar,
        })
    end
    SidebarCap(UDim2.new(0, 0,  0, 0))     -- top-left  (square off)
    SidebarCap(UDim2.new(1, -12, 0, 0))    -- top-right (square off)
    SidebarCap(UDim2.new(1, -12, 1, -12))  -- bottom-right (square off)
    -- bottom-left is left rounded to blend with the window corner
    Create("Frame", {
        Size             = UDim2.new(0, 1, 1, 0),
        Position         = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.Separator,
        BorderSizePixel  = 0,
        ZIndex           = Z.Sidebar + 1,
        Parent           = sidebar,
    })
    local sbScroll = ScrollFrame(sidebar, Z.Sidebar)
    Pad(sbScroll, 8, 8, 8, 8)
    local sbList = Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex           = Z.Sidebar,
        Parent           = sbScroll,
    }); ListLayout(sbList, Enum.FillDirection.Vertical, 1)

    -- ── Content area ───────────────────────────────────────────────────────
    local content = Create("Frame", {
        Name             = "Content",
        Size             = UDim2.new(1, -SIDEBAR_W, 1, -TITLEBAR_H),
        Position         = UDim2.new(0, SIDEBAR_W, 0, TITLEBAR_H),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel  = 0,
        ZIndex           = Z.Content,
        Parent           = window,
    })
    -- Anti-corner caps: UICorner rounds all 4 corners; we square off 3,
    -- leaving only bottom-right rounded to match the window's corner.
    Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = content })
    local function ContentCap(pos)
        Create("Frame", {
            Size             = UDim2.new(0, 12, 0, 12),
            Position         = pos,
            BackgroundColor3 = Theme.ContentBg,
            BorderSizePixel  = 0,
            ZIndex           = Z.Content + 2,
            Parent           = content,
        })
    end
    ContentCap(UDim2.new(0, 0,   0, 0))    -- top-left  (square off)
    ContentCap(UDim2.new(1, -12, 0, 0))    -- top-right (square off)
    ContentCap(UDim2.new(0, 0,   1, -12))  -- bottom-left (square off)
    -- bottom-right is left rounded to blend with the window corner

    -- DragStyle 1 = titlebar only (PC), DragStyle 2 = entire window (Mobile)
    if cfgDragStyle == 2 then
        for _, conn in ipairs(Draggable(window, window)) do windowTasks:Add(conn) end
    else
        for _, conn in ipairs(Draggable(titleBar, window)) do windowTasks:Add(conn) end
    end

    -- AcrylicBlur: apply a BlurEffect to the Lighting so the game blurs behind the GUI
    local _blur = nil
    if cfgAcrylic then
        local Lighting = game:GetService("Lighting")
        local ok, blur = pcall(function()
            local b = Instance.new("BlurEffect")
            b.Size = 16
            b.Parent = Lighting
            return b
        end)
        if ok then _blur = blur end
    end

    -- ShowUserInfo: player avatar + username in the right side of the title bar
    if cfgShowUser then
        local ok, thumb = pcall(function()
            return game:GetService("Players"):GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size48x48
            )
        end)
        local avatarImg = ok and thumb or 

        local userFrame = Create("Frame", {
            Size                 = UDim2.new(0, 140, 0, 34),
            Position             = UDim2.new(0, 14, 0.5, -17),
            AnchorPoint          = Vector2.new(0, 0),
            BackgroundTransparency = 1,
            ZIndex               = Z.TitleBar + 1,
            Parent               = titleBar,
        })
        -- shift it to the right of the traffic-light buttons (after btnRow + sidebar toggle + nav btns)
        userFrame.Position = UDim2.new(1, -158, 0.5, -17)

        local avatarFrame = Create("Frame", {
            Size             = UDim2.new(0, 26, 0, 26),
            Position         = UDim2.new(0, 0, 0.5, -13),
            BackgroundColor3 = Theme.TabHover,
            BorderSizePixel  = 0,
            ZIndex           = Z.TitleBar + 2,
            Parent           = userFrame,
        }); Round(avatarFrame, 13)
        if avatarImg ~= "" then
            Create("ImageLabel", {
                Size                 = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Image                = avatarImg,
                ZIndex               = Z.TitleBar + 3,
                Parent               = avatarFrame,
            })
        end
        Create("TextLabel", {
            Size                  = UDim2.new(0, 100, 1, 0),
            Position              = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text                  = LocalPlayer.DisplayName,
            TextColor3            = Theme.SubtitleText,
            TextSize              = 11,
            Font                  = Enum.Font.GothamSemibold,
            TextXAlignment        = Enum.TextXAlignment.Left,
            TextTruncate          = Enum.TextTruncate.AtEnd,
            ZIndex                = Z.TitleBar + 2,
            Parent                = userFrame,
        })
    end

    -- ── Window controls ────────────────────────────────────────────────────
    local minimised = false
    -- Only wire close button if not disabled
    if not (_disabledCtrl["exit"] or _disabledCtrl["close"]) then
        windowTasks:Connect(closeBtn.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                Tween(window, { BackgroundTransparency = 1 }, TI_MID)
                if _blur then pcall(function() _blur:Destroy() end) end
                task.wait(0.25)
                pcall(function() sg:Destroy() end)
            end
        end)
    end
    -- Only wire minimize button if not disabled
    if not (_disabledCtrl["minimize"] or _disabledCtrl["minimise"]) then
        windowTasks:Connect(minBtn.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                minimised = not minimised
                Tween(window, {
                    Size = UDim2.new(0, _winW, 0, minimised and TITLEBAR_H or _winH),
                }, TI_SLOW)
            end
        end)
    end

    local sbVisible = true
    windowTasks:Connect(sbToggle.MouseButton1Click, function()
        sbVisible = not sbVisible
        if sbVisible then
            Tween(sidebar, { Size = UDim2.new(0, SIDEBAR_W, 1, -TITLEBAR_H) }, TI_SLOW)
            Tween(content, {
                Size     = UDim2.new(1, -SIDEBAR_W, 1, -TITLEBAR_H),
                Position = UDim2.new(0, SIDEBAR_W, 0, TITLEBAR_H),
            }, TI_SLOW)
        else
            Tween(sidebar, { Size = UDim2.new(0, 0, 1, -TITLEBAR_H) }, TI_SLOW)
            Tween(content, {
                Size     = UDim2.new(1, 0, 1, -TITLEBAR_H),
                Position = UDim2.new(0, 0, 0, TITLEBAR_H),
            }, TI_SLOW)
        end
    end)

    -- ── Window object ──────────────────────────────────────────────────────
    local Win          = {}
    Win._tabs          = {}
    Win._activeTab     = nil
    Win._sbList        = sbList
    Win._content       = content
    Win._order         = 0
    Win._sg            = sg
    Win._window        = window
    Win.Instance       = window
    Win._tasks         = windowTasks
    Win._components    = {}
    Win._popups        = {}
    Win._blur          = _blur
    Win._winW          = _winW
    Win._winH          = _winH

    -- Search: filter visible rows in the active tab (searches inside section groups too)
    local function IterRows(root, fn)
        for _, child in ipairs(root:GetChildren()) do
            if child.Name:sub(1, 4) == "Row_" then
                fn(child)
            elseif child.Name:sub(1, 4) == "Sec_" then
                local group = child:FindFirstChild("Group")
                if group then
                    for _, row in ipairs(group:GetChildren()) do
                        if row.Name:sub(1, 4) == "Row_" then fn(row) end
                    end
                end
            end
        end
    end

    windowTasks:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
        local query = searchBox.Text:lower()
        if not Win._activeTab then return end
        IterRows(Win._activeTab._content, function(child)
            local nLbl = child:FindFirstChild("Name")
            local dLbl = child:FindFirstChild("Desc")
            child.Visible = query == ""
                or (nLbl and nLbl.Text:lower():find(query, 1, true))
                or (dLbl and dLbl.Text:lower():find(query, 1, true))
        end)
    end)

    local function ActivateTab(tab, pushHistory)
        if Win._activeTab and Win._activeTab ~= tab then
            local prev = Win._activeTab
            Tween(prev._btn, { BackgroundTransparency = 1 }, TI_MID)
            local pIcon  = prev._btn:FindFirstChild("Icon")
            local pLabel = prev._btn:FindFirstChild("Label")
            if pIcon  then pIcon.TextColor3  = Theme.TabInactive end
            if pLabel then
                pLabel.TextColor3 = Theme.TabInactive
                pLabel.Font       = Enum.Font.Gotham
            end
            prev._scroll.Visible = false
        end
        Win._activeTab = tab
        Tween(tab._btn, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0 }, TI_MID)
        local icon  = tab._btn:FindFirstChild("Icon")
        local label = tab._btn:FindFirstChild("Label")
        if icon  then icon.TextColor3  = Theme.TabActiveText end
        if label then
            label.TextColor3 = Theme.TabActiveText
            label.Font       = Enum.Font.GothamSemibold
        end
        tab._scroll.Visible = true

        searchBox.Text = ""
        IterRows(tab._content, function(row) row.Visible = true end)

        if pushHistory then
            while #_history > _histIdx do table.remove(_history) end
            _histIdx               = _histIdx + 1
            _history[_histIdx]     = tab
        end
    end

    windowTasks:Connect(backBtn.MouseButton1Click, function()
        if _histIdx > 1 then
            _histIdx = _histIdx - 1
            ActivateTab(_history[_histIdx], false)
        end
    end)
    windowTasks:Connect(fwdBtn.MouseButton1Click, function()
        if _histIdx < #_history then
            _histIdx = _histIdx + 1
            ActivateTab(_history[_histIdx], false)
        end
    end)

    function Win:Destroy()
        windowTasks:Destroy()
        if self._blur then pcall(function() self._blur:Destroy() end) end
        pcall(function() sg:Destroy() end)
    end

    function Win:Show()
        sg.Enabled = true
        window.Visible = true
        return self
    end

    function Win:Hide()
        window.Visible = false
        return self
    end

    function Win:Toggle()
        window.Visible = not window.Visible
        return self
    end

    function Win:SetVisible(state)
        window.Visible = not not state
        return self
    end

    function Win:Minimize(state)
        minimised = state == nil and true or not not state
        Tween(window, { Size = UDim2.new(0, _winW, 0, minimised and TITLEBAR_H or _winH) }, TI_SLOW)
        return self
    end

    function Win:Restore()
        minimised = false
        Tween(window, { Size = UDim2.new(0, _winW, 0, _winH) }, TI_SLOW)
        return self
    end

    function Win:ToggleMinimize()
        minimised = not minimised
        Tween(window, { Size = UDim2.new(0, _winW, 0, minimised and TITLEBAR_H or _winH) }, TI_SLOW)
        return self
    end

    -- Keybind: toggle window visibility when the bound key is pressed
    local _keybind = cfgKeybind  -- Enum.KeyCode or nil
    local _keybindConn = nil

    local function _attachKeybind(key)
        if _keybindConn then
            pcall(function() _keybindConn:Disconnect() end)
            _keybindConn = nil
        end
        if not key then return end
        _keybindConn = windowTasks:Connect(UserInputService.InputBegan, function(i, processed)
            if processed then return end
            if i.KeyCode == key then
                window.Visible = not window.Visible
            end
        end)
    end

    _attachKeybind(_keybind)

    function Win:SetKeybind(key)
        _keybind = key
        _attachKeybind(key)
        return self
    end

    function Win:SetOpacity(opacity)
        CrispyLib.SetOpacity(window, opacity)
        return self
    end

    function Win:SetStyle(styles, persistent)
        CrispyLib.Style(window, styles, persistent)
        return self
    end

    -- SetAccent: live-update accent colour across the whole window
    function Win:SetAccent(col)
        if typeof(col) ~= "Color3" then return self end
        CrispyLib.SetTheme({ Accent = col, AccentHover = col, AccentPress = col })
        return self
    end

    -- SetIcon: add or replace a small logo image in the title bar (left of the title)
    local _iconImg = nil
    function Win:SetIcon(imageId)
        if not imageId or imageId == "" then
            if _iconImg then pcall(function() _iconImg:Destroy() end); _iconImg = nil end
            return self
        end
        if not _iconImg then
            _iconImg = Create("ImageLabel", {
                Name                 = "TitleIcon",
                Size                 = UDim2.new(0, 22, 0, 22),
                Position             = UDim2.new(0.5, -120, 0.5, -11),
                BackgroundTransparency = 1,
                Image                = imageId,
                ZIndex               = Z.TitleBar + 2,
                Parent               = titleBar,
            })
        else
            _iconImg.Image = imageId
        end
        return self
    end

    -- SetPosition: smoothly reposition the window
    function Win:SetPosition(pos)
        if typeof(pos) ~= "UDim2" then return self end
        Tween(window, { Position = pos }, TI_MID)
        return self
    end

    -- Resize: animate the window to a new size
    function Win:Resize(size)
        if typeof(size) ~= "UDim2" then return self end
        _winW = size.X.Offset ~= 0 and size.X.Offset or _winW
        _winH = size.Y.Offset ~= 0 and size.Y.Offset or _winH
        Tween(window, { Size = size }, TI_SLOW)
        return self
    end

    -- Pin / Unpin: lock the window in place
    local _pinned = false
    local _savedDragConns = {}
    function Win:Pin()
        _pinned = true
        for _, conn in ipairs(_savedDragConns) do pcall(function() conn:Disconnect() end) end
        _savedDragConns = {}
        return self
    end
    function Win:Unpin()
        if not _pinned then return self end
        _pinned = false
        local handle = cfgDragStyle == 2 and window or titleBar
        local conns = Draggable(handle, window)
        for _, conn in ipairs(conns) do
            windowTasks:Add(conn)
            _savedDragConns[#_savedDragConns + 1] = conn
        end
        return self
    end
    function Win:IsPinned() return _pinned end

    function Win:TaskGroup(name)
        local group = CrispyLib.CreateTaskGroup(name or ("WindowTask:" .. title))
        windowTasks:Add(group)
        return group
    end

    function Win:RegisterComponent(flag, component)
        if flag and component then self._components[flag] = component end
        return component
    end

    function Win:GetComponent(flag)
        return self._components[flag]
    end

    function Win:GetTab(name)
        for _, tab in ipairs(self._tabs) do
            if tab.Name == name then return tab end
        end
        return nil
    end

    function Win:RegisterPopup(instance, closeFn)
        local entry = { Instance = instance, Close = closeFn }
        self._popups[#self._popups + 1] = entry
        return function()
            for i, popup in ipairs(self._popups) do
                if popup == entry then table.remove(self._popups, i); break end
            end
        end
    end

    function Win:ClosePopups(except)
        for _, popup in ipairs(self._popups) do
            if popup.Instance ~= except and type(popup.Close) == "function" then SafeCall(popup.Close) end
        end
        return self
    end

    function Win:Search(query)
        query = tostring(query or ""):lower()
        for _, tab in ipairs(self._tabs) do
            IterRows(tab._content, function(row)
                local nLbl = row:FindFirstChild("Name")
                local dLbl = row:FindFirstChild("Desc")
                row.Visible = query == ""
                    or (nLbl and nLbl.Text:lower():find(query, 1, true))
                    or (dLbl and dLbl.Text:lower():find(query, 1, true))
            end)
        end
        return self
    end

    function Win:CreateModal(cfg)
        cfg = cfg or {}
        local overlay = Create("Frame", {
            Name = "ModalOverlay",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            Visible = cfg.Visible == true,
            ZIndex = Z.Popup + 20,
            Parent = sg,
        })
        local box = Create("Frame", {
            Name = "Modal",
            Size = UDim2.new(0, cfg.Width or 360, 0, cfg.Height or 180),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3 = Theme.WindowBg,
            BorderSizePixel = 0,
            ZIndex = Z.Popup + 21,
            Parent = overlay,
        }); Round(box, 12); Stroke(box, Theme.Border, 1)
        Create("TextLabel", {
            Name = "Title", Size = UDim2.new(1, -32, 0, 34), Position = UDim2.new(0, 16, 0, 12),
            BackgroundTransparency = 1, Text = cfg.Title or "Message", TextColor3 = Theme.TitleText,
            TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = Z.Popup + 22, Parent = box,
        })
        Create("TextLabel", {
            Name = "Message", Size = UDim2.new(1, -32, 1, -92), Position = UDim2.new(0, 16, 0, 48),
            BackgroundTransparency = 1, Text = cfg.Message or "", TextColor3 = Theme.DescText, TextWrapped = true,
            TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = Z.Popup + 22, Parent = box,
        })
        local modal = { Instance = overlay, Box = box }
        local buttons = cfg.Buttons or { { Text = "OK", Callback = cfg.Callback } }
        local bw = 86
        for i, b in ipairs(buttons) do
            local btn = Create("TextButton", {
                Size = UDim2.new(0, bw, 0, 30),
                Position = UDim2.new(1, -16 - ((#buttons - i + 1) * (bw + 8)) + 8, 1, -44),
                BackgroundColor3 = b.Accent == false and Theme.InputBg or Theme.Accent,
                BorderSizePixel = 0, AutoButtonColor = false, Text = b.Text or "OK",
                TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12, Font = Enum.Font.GothamSemibold,
                ZIndex = Z.Popup + 22, Parent = box,
            }); Round(btn, 6)
            windowTasks:Connect(btn.MouseButton1Click, function()
                if b.Callback then SafeCall(b.Callback, modal) end
                if b.Close ~= false then modal:Hide() end
            end)
        end
        function modal:Show() overlay.Visible = true; return self end
        function modal:Hide() overlay.Visible = false; return self end
        function modal:Destroy() pcall(function() overlay:Destroy() end) end
        windowTasks:Add(modal)
        return modal
    end

    function Win:Confirm(titleText, message, onConfirm, onCancel)
        return self:CreateModal({
            Title = titleText or "Confirm", Message = message or "Are you sure?", Visible = true,
            Buttons = {
                { Text = "Cancel", Accent = false, Callback = onCancel },
                { Text = "Confirm", Callback = onConfirm },
            },
        })
    end

    -- ── AddSidebarSection ──────────────────────────────────────────────────
    function Win:AddSidebarSection(name)
        local lbl = Create("TextLabel", {
            Name                  = "Sec_" .. name,
            Size                  = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            Text                  = name:upper(),
            TextColor3            = Theme.SectionLabel,
            TextSize              = 10,
            Font                  = Enum.Font.GothamBold,
            TextXAlignment        = Enum.TextXAlignment.Left,
            LayoutOrder           = self._order,
            ZIndex                = Z.Sidebar + 1,
            Parent                = self._sbList,
        })
        Pad(lbl, 0, 0, 18, 0)
        self._order = self._order + 1
    end

    -- ════════════════════════════════════════════════════════════════════════
    --  AddTab
    -- ════════════════════════════════════════════════════════════════════════
    function Win:AddTab(tabCfg)
        tabCfg       = tabCfg or {}
        local tName  = tabCfg.Name or "Tab"
        local tIcon  = tabCfg.Icon or ""
        self._order  = self._order + 1

        local tabBtn = Create("TextButton", {
            Name                  = "Tab_" .. tName,
            Size                  = UDim2.new(1, 0, 0, 34),
            BackgroundColor3      = Theme.SidebarBg,
            BackgroundTransparency = 1,
            Text                  = "",
            BorderSizePixel       = 0,
            LayoutOrder           = self._order,
            AutoButtonColor       = false,
            ZIndex                = Z.Sidebar + 1,
            Parent                = self._sbList,
        }); Round(tabBtn, 6)

        Create("TextLabel", {
            Name                  = "Icon",
            Size                  = UDim2.new(0, 20, 1, 0),
            Position              = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text                  = tIcon,
            TextColor3            = Theme.TabInactive,
            TextSize              = 14,
            Font                  = Enum.Font.Gotham,
            TextXAlignment        = Enum.TextXAlignment.Left,
            ZIndex                = Z.Sidebar + 2,
            Parent                = tabBtn,
        })
        Create("TextLabel", {
            Name                  = "Label",
            Size                  = UDim2.new(1, -34, 1, 0),
            Position              = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text                  = tName,
            TextColor3            = Theme.TabInactive,
            TextSize              = 13,
            Font                  = Enum.Font.Gotham,
            TextXAlignment        = Enum.TextXAlignment.Left,
            ZIndex                = Z.Sidebar + 2,
            Parent                = tabBtn,
        })

        local tabScroll  = ScrollFrame(self._content, Z.Content)
        tabScroll.Visible = false
        Pad(tabScroll, 0, 0, 0, 0)

        local tabContent = Create("Frame", {
            Name             = "Content_" .. tName,
            Size             = UDim2.new(1, 0, 0, 0),
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex           = Z.Content,
            Parent           = tabScroll,
        }); ListLayout(tabContent, Enum.FillDirection.Vertical, 8)
        Pad(tabContent, 8, 16, 12, 12)

        local Tab        = {}
        Tab.Name         = tName
        Tab._content     = tabContent
        Tab._scroll      = tabScroll
        Tab._btn         = tabBtn
        Tab._win         = self
        Tab._order       = 0
        Tab._currentGroup = nil

        tabBtn.MouseEnter:Connect(function()
            if Win._activeTab ~= Tab then
                Tween(tabBtn, {
                    BackgroundColor3      = Color3.fromRGB(44, 44, 52),
                    BackgroundTransparency = 0.6,
                }, TI_FAST)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if Win._activeTab ~= Tab then
                Tween(tabBtn, { BackgroundTransparency = 1 }, TI_FAST)
            end
        end)
        tabBtn.MouseButton1Click:Connect(function()
            ActivateTab(Tab, true)
        end)

        -- Badge support on the sidebar tab button
        local _badge = nil
        local _badgeLbl = nil

        function Tab:SetBadge(n)
            n = tonumber(n) or 0
            if not _badge then
                _badge = Create("Frame", {
                    Name             = "Badge",
                    Size             = UDim2.new(0, 18, 0, 18),
                    Position         = UDim2.new(1, -6, 0, 0),
                    AnchorPoint      = Vector2.new(1, 0),
                    BackgroundColor3 = Theme.NotifError,
                    BorderSizePixel  = 0,
                    ZIndex           = Z.Sidebar + 3,
                    Parent           = tabBtn,
                }); Round(_badge, 9)
                _badgeLbl = Create("TextLabel", {
                    Size                  = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text                  = tostring(n > 99 and "99+" or n),
                    TextColor3            = Color3.fromRGB(255, 255, 255),
                    TextSize              = 9,
                    Font                  = Enum.Font.GothamBold,
                    TextXAlignment        = Enum.TextXAlignment.Center,
                    ZIndex                = Z.Sidebar + 4,
                    Parent                = _badge,
                })
            else
                _badgeLbl.Text = tostring(n > 99 and "99+" or n)
            end
            _badge.Visible = n > 0
            return self
        end

        function Tab:ClearBadge()
            if _badge then _badge.Visible = false end
            return self
        end

        if #self._tabs == 0 then
            task.defer(function() ActivateTab(Tab, true) end)
        end
        table.insert(self._tabs, Tab)

        -- ── Shared row utilities ───────────────────────────────────────────

        local function MkRow(tab, h)
            tab._order = tab._order + 1
            local inGroup = tab._currentGroup ~= nil
            local parent  = tab._currentGroup or tab._content
            local row = Create("Frame", {
                Name             = "Row_" .. tab._order,
                Size             = UDim2.new(1, 0, 0, h or ROW_H),
                BackgroundColor3 = Theme.RowBg,
                BackgroundTransparency = inGroup and 1 or 0,
                BorderSizePixel  = 0,
                LayoutOrder      = tab._order,
                ZIndex           = Z.Content,
                Parent           = parent,
            })
            if not inGroup then
                Round(row, 8)
                Stroke(row, Theme.Border, 1)
            end
            local hoverBg = Create("Frame", {
                Size             = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Theme.RowHover,
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content,
                Parent           = row,
            })
            row.MouseEnter:Connect(function()
                Tween(hoverBg, { BackgroundTransparency = 0.88 }, TI_FAST)
            end)
            row.MouseLeave:Connect(function()
                Tween(hoverBg, { BackgroundTransparency = 1 }, TI_FAST)
            end)
            if inGroup then
                Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 1),
                    Position         = UDim2.new(0, 0, 1, -1),
                    BackgroundColor3 = Theme.Separator,
                    BorderSizePixel  = 0,
                    ZIndex           = Z.Content + 1,
                    Parent           = row,
                })
            end
            return row
        end

        local function RowLabels(row, name, desc)
            local hasDesc = desc and desc ~= ""
            local nameLbl = Create("TextLabel", {
                Name                  = "Name",
                Size                  = UDim2.new(0.55, -20, 0, 18),
                Position              = UDim2.new(0, 16, 0, hasDesc and 10 or 0),
                AnchorPoint           = Vector2.new(0, hasDesc and 0 or 0.5),
                BackgroundTransparency = 1,
                Text                  = name or "",
                TextColor3            = Theme.LabelText,
                TextSize              = 13,
                Font                  = Enum.Font.GothamSemibold,
                TextXAlignment        = Enum.TextXAlignment.Left,
                TextTruncate          = Enum.TextTruncate.AtEnd,
                ZIndex                = Z.Content + 2,
                Parent                = row,
            })
            if not hasDesc then
                nameLbl.Position = UDim2.new(0, 16, 0.5, 0)
            end
            local descLbl
            if hasDesc then
                descLbl = Create("TextLabel", {
                    Name                  = "Desc",
                    Size                  = UDim2.new(0.65, -20, 0, 14),
                    Position              = UDim2.new(0, 16, 0, 29),
                    BackgroundTransparency = 1,
                    Text                  = desc,
                    TextColor3            = Theme.DescText,
                    TextSize              = 11,
                    Font                  = Enum.Font.Gotham,
                    TextXAlignment        = Enum.TextXAlignment.Left,
                    TextTruncate          = Enum.TextTruncate.AtEnd,
                    ZIndex                = Z.Content + 2,
                    Parent                = row,
                })
            end
            return nameLbl, descLbl
        end

        -- ════════════════════════════════════════════════════════════════════
        --  SECTION HEADER + GROUP CARD
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddSection(sc)
            sc = sc or {}
            self._order   = self._order + 1
            local hasDesc = sc.Description and sc.Description ~= ""
            local headerH = hasDesc and 46 or 28

            -- Wrapper: header + group container stacked vertically
            local wrapper = Create("Frame", {
                Name             = "Sec_" .. self._order,
                Size             = UDim2.new(1, 0, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = Z.Content,
                Parent           = self._content,
            })
            ListLayout(wrapper, Enum.FillDirection.Vertical, 4)

            -- Section header (plain text, no card bg)
            local hFrame = Create("Frame", {
                Name             = "Header",
                Size             = UDim2.new(1, 0, 0, headerH),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content,
                Parent           = wrapper,
            })
            Create("TextLabel", {
                Size                  = UDim2.new(1, 0, 0, 18),
                Position              = UDim2.new(0, 0, 0, hasDesc and 2 or 5),
                BackgroundTransparency = 1,
                Text                  = sc.Title or "",
                TextColor3            = Theme.TitleText,
                TextSize              = 14,
                Font                  = Enum.Font.GothamBold,
                TextXAlignment        = Enum.TextXAlignment.Left,
                ZIndex                = Z.Content + 1,
                Parent                = hFrame,
            })
            if hasDesc then
                Create("TextLabel", {
                    Size                  = UDim2.new(1, 0, 0, 14),
                    Position              = UDim2.new(0, 0, 0, 22),
                    BackgroundTransparency = 1,
                    Text                  = sc.Description,
                    TextColor3            = Theme.DescText,
                    TextSize              = 11,
                    Font                  = Enum.Font.Gotham,
                    TextXAlignment        = Enum.TextXAlignment.Left,
                    ZIndex                = Z.Content + 1,
                    Parent                = hFrame,
                })
            end

            -- Group card: rows go inside this
            local groupContainer = Create("Frame", {
                Name             = "Group",
                Size             = UDim2.new(1, 0, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.RowBg,
                BorderSizePixel  = 0,
                ClipsDescendants = true,
                ZIndex           = Z.Content,
                Parent           = wrapper,
            })
            Round(groupContainer, 8)
            Stroke(groupContainer, Theme.Border, 1)
            ListLayout(groupContainer, Enum.FillDirection.Vertical, 0)

            self._currentGroup = groupContainer
        end

        -- ════════════════════════════════════════════════════════════════════
        --  LABEL
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddLabel(lc)
            lc = lc or {}
            local row = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, lc.Name, lc.Description)

            local valueLbl = Create("TextLabel", {
                Name                  = "Value",
                Size                  = UDim2.new(0.46, -20, 1, 0),
                Position              = UDim2.new(0.54, 0, 0, 0),
                BackgroundTransparency = 1,
                Text                  = tostring(lc.Value or ""),
                TextColor3            = Theme.ValueText,
                TextSize              = 13,
                Font                  = Enum.Font.Gotham,
                TextXAlignment        = Enum.TextXAlignment.Right,
                TextTruncate          = Enum.TextTruncate.AtEnd,
                ZIndex                = Z.Content + 2,
                Parent                = row,
            }); Pad(valueLbl, 0, 0, 0, 20)

            local obj = {}
            function obj:Set(v) valueLbl.Text = tostring(v) end
            function obj:Get() return valueLbl.Text end
            ApplyMixin(obj, row, nameLbl, descLbl)
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  TOGGLE
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddToggle(tc)
            tc = tc or {}
            local val    = tc.Default ~= nil and tc.Default or false
            local cb     = tc.Callback or function() end
            local row    = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, tc.Name, tc.Description)

            local track = Create("Frame", {
                Size             = UDim2.new(0, 46, 0, 26),
                Position         = UDim2.new(1, -64, 0.5, -13),
                BackgroundColor3 = val and Theme.Accent or Theme.ToggleOff,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 2,
                Parent           = row,
            }); Round(track, 13)
            Create("UIStroke", {
                Color        = Color3.fromRGB(0, 0, 0),
                Thickness    = 1,
                Transparency = 0.75,
                Parent       = track,
            })
            local knob = Create("Frame", {
                Size             = UDim2.new(0, 22, 0, 22),
                Position         = val and UDim2.new(0, 22, 0.5, -11) or UDim2.new(0, 2, 0.5, -11),
                BackgroundColor3 = Theme.ToggleKnob,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 3,
                Parent           = track,
            }); Round(knob, 11)
            local btn = Create("TextButton", {
                Size                  = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                  = "",
                ZIndex                = Z.Content + 4,
                Parent                = track,
            })

            local disabled = false
            local obj = { Flag = tc.Flag }

            local function Apply(v, silent)
                if disabled then return end
                val = v
                Tween(track, { BackgroundColor3 = val and Theme.Accent or Theme.ToggleOff }, TI_MID)
                Tween(knob,  { Position = val and UDim2.new(0, 22, 0.5, -11) or UDim2.new(0, 2, 0.5, -11) }, TI_MID)
                local prev = State.Get(tc.Flag)
                State.Set(tc.Flag, val)
                obj:_FireChanged(val, prev)
                if not silent then SafeCall(cb, val) end
            end

            btn.MouseButton1Click:Connect(function() Apply(not val) end)

            function obj:Set(v, s) Apply(not not v, s) end
            function obj:Get() return val end
            function obj:Enable()
                disabled = false
                Tween(track, { BackgroundTransparency = 0 }, TI_FAST)
                btn.Active = true
            end
            function obj:Disable()
                disabled = true
                Tween(track, { BackgroundTransparency = 0.5 }, TI_FAST)
                btn.Active = false
            end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(tc.Flag, obj)

            Registry.Register(tc.Flag,
                function() return val end,
                function(v) Apply(not not v, true) end
            )
            if tc.Flag then State.Set(tc.Flag, val) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  DROPDOWN
        --  New API: :AddItem(opt), :RemoveItem(opt), :ClearItems()
        --           :SetOptions(list), :Set(val), :Get()
        --           :Enable(), :Disable(), :Show(), :Hide()
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddDropdown(dc)
            dc       = dc or {}
            local options  = {}
            local optionLimit = dc.MaxVisibleItems or dc.VirtualLimit or 200
            local multi    = dc.Multi    or false
            local cb       = dc.Callback or function() end
            local selected = dc.Default  or (multi and {} or "")
            local disabled = false

            -- Populate initial options
            for _, v in ipairs(dc.Options or {}) do
                table.insert(options, v)
            end
            if not dc.Default then
                selected = multi and {} or (options[1] or "")
            end

            local row = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, dc.Name, dc.Description)

            local function ValueText()
                if multi then
                    if #selected == 0 then return "None" end
                    if #selected == 1 then return selected[1] end
                    return tostring(#selected) .. " selected"
                end
                return tostring(selected ~= "" and selected or "None")
            end

            local dBtn = Create("TextButton", {
                Size             = UDim2.new(0, 160, 0, 28),
                Position         = UDim2.new(1, -178, 0.5, -14),
                BackgroundColor3 = Theme.InputBg,
                Text             = "",
                BorderSizePixel  = 0,
                AutoButtonColor  = false,
                ZIndex           = Z.Content + 3,
                Parent           = row,
            }); Round(dBtn, 7)
            local dStroke = Stroke(dBtn, Theme.Border, 1)

            local dLabel = Create("TextLabel", {
                Size                  = UDim2.new(1, -30, 1, 0),
                Position              = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text                  = ValueText(),
                TextColor3            = Theme.LabelText,
                TextSize              = 12,
                Font                  = Enum.Font.Gotham,
                TextXAlignment        = Enum.TextXAlignment.Left,
                TextTruncate          = Enum.TextTruncate.AtEnd,
                ZIndex                = Z.Content + 4,
                Parent                = dBtn,
            })
            local chevron = Create("TextLabel", {
                Size                  = UDim2.new(0, 22, 1, 0),
                Position              = UDim2.new(1, -22, 0, 0),
                BackgroundTransparency = 1,
                Text                  = "⇅",
                TextColor3            = Theme.SubtitleText,
                TextSize              = 12,
                Font                  = Enum.Font.GothamBold,
                ZIndex                = Z.Content + 4,
                Parent                = dBtn,
            })

            local listOpen  = false
            local listFrame = Create("Frame", {
                Name             = "DropList_" .. tostring(self._order),
                Size             = UDim2.new(0, 180, 0, 0),
                BackgroundColor3 = Theme.DropdownBg,
                BorderSizePixel  = 0,
                ZIndex           = Z.Popup,
                ClipsDescendants = true,
                Visible          = false,
                Parent           = sg,
            }); Round(listFrame, 9); Stroke(listFrame, Theme.Border, 1)

            local searchFrame = Create("Frame", {
                Size             = UDim2.new(1, -16, 0, 28),
                Position         = UDim2.new(0, 8, 0, 6),
                BackgroundColor3 = Theme.InputBg,
                BorderSizePixel  = 0,
                ZIndex           = Z.Popup + 1,
                Parent           = listFrame,
            }); Round(searchFrame, 7)
            local sStroke = Stroke(searchFrame, Theme.Border, 1)
            local searchIn = Create("TextBox", {
                Size                  = UDim2.new(1, -10, 1, 0),
                Position              = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                PlaceholderText       = "Search...",
                PlaceholderColor3     = Theme.PlaceholderC,
                Text                  = "",
                TextColor3            = Theme.LabelText,
                TextSize              = 12,
                Font                  = Enum.Font.Gotham,
                TextXAlignment        = Enum.TextXAlignment.Left,
                ClearTextOnFocus      = false,
                ZIndex                = Z.Popup + 2,
                Parent                = searchFrame,
            })
            searchIn.Focused:Connect(function()  Tween(sStroke, { Color = Theme.FocusBorder }, TI_FAST) end)
            searchIn.FocusLost:Connect(function() Tween(sStroke, { Color = Theme.Border }, TI_FAST) end)

            local optScroll = Create("ScrollingFrame", {
                Size                 = UDim2.new(1, -8, 1, multi and -84 or -46),
                Position             = UDim2.new(0, 4, 0, 40),
                BackgroundTransparency = 1,
                ScrollBarThickness   = 3,
                ScrollBarImageColor3 = Theme.ScrollThumb,
                BorderSizePixel      = 0,
                CanvasSize           = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize  = Enum.AutomaticSize.Y,
                ClipsDescendants     = true,
                ZIndex               = Z.Popup + 1,
                Parent               = listFrame,
            })
            local optList = Create("Frame", {
                Size             = UDim2.new(1, 0, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                ZIndex           = Z.Popup + 1,
                Parent           = optScroll,
            }); ListLayout(optList, Enum.FillDirection.Vertical, 2); Pad(optList, 2, 2, 0, 0)

            local optBtns = {}

            local function IsSelected(opt)
                if multi then
                    for _, v in ipairs(selected) do
                        if v == opt then return true end
                    end
                    return false
                end
                return selected == opt
            end

            local function CloseList()
                listOpen = false
                Tween(listFrame,  { Size = UDim2.new(0, 180, 0, 0) }, TI_MID)
                Tween(chevron,    { Rotation = 0 }, TI_MID)
                Tween(dStroke,    { Color = Theme.Border }, TI_MID)
                task.delay(0.22, function() listFrame.Visible = false end)
            end
            local unregisterPopup = Win:RegisterPopup(listFrame, CloseList)
            windowTasks:Add(unregisterPopup, function(fn) fn() end)

            local function Rebuild(filter)
                for _, c in ipairs(optBtns) do c:Destroy() end
                optBtns = {}
                filter  = (filter or ""):lower()

                local rendered = 0
                for _, opt in ipairs(options) do
                    if rendered >= optionLimit then break end
                    if filter == "" or opt:lower():find(filter, 1, true) then
                        rendered = rendered + 1
                        local sel = IsSelected(opt)
                        local ob  = Create("TextButton", {
                            Size             = UDim2.new(1, 0, 0, 30),
                            BackgroundColor3 = sel and Theme.Accent or Theme.DropdownBg,
                            BackgroundTransparency = sel and 0.82 or 1,
                            Text             = "",
                            BorderSizePixel  = 0,
                            AutoButtonColor  = false,
                            ZIndex           = Z.Popup + 2,
                            Parent           = optList,
                        }); Round(ob, 5)

                        if multi then
                            local cbBox = Create("Frame", {
                                Size             = UDim2.new(0, 14, 0, 14),
                                AnchorPoint      = Vector2.new(0, 0.5),
                                Position         = UDim2.new(0, 10, 0.5, 0),
                                BackgroundColor3 = sel and Theme.Accent or Color3.fromRGB(0, 0, 0),
                                BackgroundTransparency = sel and 0 or 1,
                                BorderSizePixel  = 0,
                                ZIndex           = Z.Popup + 3,
                                Parent           = ob,
                            }); Round(cbBox, 3)
                            Create("UIStroke", {
                                Color     = sel and Theme.Accent or Theme.Border,
                                Thickness = 1.5,
                                Parent    = cbBox,
                            })
                            if sel then
                                Create("TextLabel", {
                                    Size                  = UDim2.new(1, 0, 1, 0),
                                    BackgroundTransparency = 1,
                                    Text                  = "✓",
                                    TextColor3            = Color3.fromRGB(255, 255, 255),
                                    TextSize              = 9,
                                    Font                  = Enum.Font.GothamBold,
                                    ZIndex                = Z.Popup + 4,
                                    Parent                = cbBox,
                                })
                            end
                            Create("TextLabel", {
                                Size                  = UDim2.new(1, -34, 1, 0),
                                Position              = UDim2.new(0, 30, 0, 0),
                                BackgroundTransparency = 1,
                                Text                  = opt,
                                TextColor3            = sel and Theme.TabActiveText or Theme.LabelText,
                                TextSize              = 12,
                                Font                  = sel and Enum.Font.GothamSemibold or Enum.Font.Gotham,
                                TextXAlignment        = Enum.TextXAlignment.Left,
                                TextTruncate          = Enum.TextTruncate.AtEnd,
                                ZIndex                = Z.Popup + 3,
                                Parent                = ob,
                            })
                        else
                            Create("TextLabel", {
                                Size                  = UDim2.new(1, -20, 1, 0),
                                Position              = UDim2.new(0, 10, 0, 0),
                                BackgroundTransparency = 1,
                                Text                  = opt,
                                TextColor3            = sel and Theme.TabActiveText or Theme.LabelText,
                                TextSize              = 12,
                                Font                  = sel and Enum.Font.GothamSemibold or Enum.Font.Gotham,
                                TextXAlignment        = Enum.TextXAlignment.Left,
                                TextTruncate          = Enum.TextTruncate.AtEnd,
                                ZIndex                = Z.Popup + 3,
                                Parent                = ob,
                            })
                            if sel then
                                Create("TextLabel", {
                                    Size                  = UDim2.new(0, 18, 1, 0),
                                    Position              = UDim2.new(1, -20, 0, 0),
                                    BackgroundTransparency = 1,
                                    Text                  = "✓",
                                    TextColor3            = Theme.Accent,
                                    TextSize              = 11,
                                    Font                  = Enum.Font.GothamBold,
                                    ZIndex                = Z.Popup + 3,
                                    Parent                = ob,
                                })
                            end
                        end

                        ob.MouseEnter:Connect(function()
                            if not IsSelected(opt) then
                                Tween(ob, { BackgroundColor3 = Theme.ItemHover, BackgroundTransparency = 0.6 }, TI_FAST)
                            end
                        end)
                        ob.MouseLeave:Connect(function()
                            if not IsSelected(opt) then
                                Tween(ob, { BackgroundColor3 = Theme.DropdownBg, BackgroundTransparency = 1 }, TI_FAST)
                            end
                        end)
                        ob.MouseButton1Click:Connect(function()
                            if disabled then return end
                            if multi then
                                local found = false
                                for i, v in ipairs(selected) do
                                    if v == opt then table.remove(selected, i); found = true; break end
                                end
                                if not found then table.insert(selected, opt) end
                            else
                                selected = opt
                                CloseList()
                            end
                            dLabel.Text = ValueText()
                            State.Set(dc.Flag, selected)
                            SafeCall(cb, selected)
                            Rebuild(searchIn.Text)
                        end)
                        table.insert(optBtns, ob)
                    end
                end
            end

            Rebuild()
            searchIn:GetPropertyChangedSignal("Text"):Connect(function()
                Rebuild(searchIn.Text)
            end)

            local function MaxHeight()
                return multi and math.min(#options * 30 + 88, 270)
                              or  math.min(#options * 32 + 50, 230)
            end

            local function RepositionList()
                local abp = dBtn.AbsolutePosition
                local abs = dBtn.AbsoluteSize
                listFrame.Position = UDim2.new(0, abp.X, 0, abp.Y + abs.Y + 4)
            end

            dBtn.MouseButton1Click:Connect(function()
                if disabled then return end
                if not listOpen then Win:ClosePopups(listFrame) end
                listOpen = not listOpen
                if listOpen then
                    RepositionList()
                    listFrame.Visible = true
                    searchIn.Text     = ""
                    Rebuild()
                    Tween(listFrame,  { Size = UDim2.new(0, 180, 0, MaxHeight()) }, TI_MID)
                    Tween(chevron,    { Rotation = 180 }, TI_MID)
                    Tween(dStroke,    { Color = Theme.FocusBorder }, TI_MID)
                else
                    CloseList()
                end
            end)

            -- Click-outside to close
            windowTasks:Connect(UserInputService.InputBegan, function(inp)
                if not listOpen then return end
                if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local mp = UserInputService:GetMouseLocation()
                local lp = listFrame.AbsolutePosition
                local ls = listFrame.AbsoluteSize
                local insideList = mp.X >= lp.X and mp.X <= lp.X + ls.X and mp.Y >= lp.Y and mp.Y <= lp.Y + ls.Y
                local insideBtn  = mp.X >= dBtn.AbsolutePosition.X and mp.X <= dBtn.AbsolutePosition.X + dBtn.AbsoluteSize.X
                                and mp.Y >= dBtn.AbsolutePosition.Y and mp.Y <= dBtn.AbsolutePosition.Y + dBtn.AbsoluteSize.Y
                if not insideList and not insideBtn then
                    CloseList()
                end
            end)

            -- Multi-select done/clear bar
            if multi then
                local doneBar = Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 38),
                    Position         = UDim2.new(0, 0, 1, -38),
                    BackgroundColor3 = Theme.DropdownBg,
                    BorderSizePixel  = 0,
                    ZIndex           = Z.Popup + 2,
                    Parent           = listFrame,
                })
                Create("Frame", {
                    Size             = UDim2.new(1, -16, 0, 1),
                    Position         = UDim2.new(0, 8, 0, 0),
                    BackgroundColor3 = Theme.Separator,
                    BorderSizePixel  = 0,
                    ZIndex           = Z.Popup + 3,
                    Parent           = doneBar,
                })
                local clearBtn = Create("TextButton", {
                    Size             = UDim2.new(0, 54, 0, 26),
                    Position         = UDim2.new(0, 8, 0.5, -13),
                    BackgroundColor3 = Theme.InputBg,
                    Text             = "Clear",
                    TextColor3       = Theme.SubtitleText,
                    TextSize         = 11,
                    Font             = Enum.Font.GothamSemibold,
                    BorderSizePixel  = 0,
                    AutoButtonColor  = false,
                    ZIndex           = Z.Popup + 3,
                    Parent           = doneBar,
                }); Round(clearBtn, 5); Stroke(clearBtn, Theme.Border, 1)
                clearBtn.MouseButton1Down:Connect(function()
                    selected        = {}
                    dLabel.Text     = ValueText()
                    State.Set(dc.Flag, selected)
                    SafeCall(cb, selected)
                    Rebuild(searchIn.Text)
                end)
                local doneBtn = Create("TextButton", {
                    Size             = UDim2.new(1, -74, 0, 26),
                    Position         = UDim2.new(0, 68, 0.5, -13),
                    BackgroundColor3 = Theme.Accent,
                    Text             = "Done",
                    TextColor3       = Color3.fromRGB(255, 255, 255),
                    TextSize         = 12,
                    Font             = Enum.Font.GothamSemibold,
                    BorderSizePixel  = 0,
                    AutoButtonColor  = false,
                    ZIndex           = Z.Popup + 3,
                    Parent           = doneBar,
                }); Round(doneBtn, 5)
                doneBtn.MouseEnter:Connect(function()  Tween(doneBtn, { BackgroundColor3 = Theme.AccentHover }, TI_FAST) end)
                doneBtn.MouseLeave:Connect(function() Tween(doneBtn, { BackgroundColor3 = Theme.Accent }, TI_FAST) end)
                doneBtn.MouseButton1Click:Connect(CloseList)
            end

            local obj = { Flag = dc.Flag }

            function obj:Set(v, silent)
                selected    = v
                dLabel.Text = ValueText()
                local prev = State.Get(dc.Flag)
                State.Set(dc.Flag, selected)
                obj:_FireChanged(selected, prev)
                if not silent then SafeCall(cb, selected) end
                Rebuild()
            end
            function obj:Get() return selected end
            function obj:SetOptions(newOpts)
                options = {}
                for _, v in ipairs(newOpts or {}) do table.insert(options, v) end
                Rebuild()
            end
            function obj:AddItem(item)
                if type(item) ~= "string" then return end
                for _, v in ipairs(options) do if v == item then return end end
                table.insert(options, item)
                Rebuild(searchIn.Text)
            end
            function obj:RemoveItem(item)
                for i, v in ipairs(options) do
                    if v == item then
                        table.remove(options, i)
                        break
                    end
                end
                -- Deselect if removed item was selected
                if multi then
                    for i, v in ipairs(selected) do
                        if v == item then table.remove(selected, i); break end
                    end
                elseif selected == item then
                    selected = options[1] or ""
                end
                dLabel.Text = ValueText()
                State.Set(dc.Flag, selected)
                Rebuild(searchIn.Text)
            end
            function obj:ClearItems()
                options     = {}
                selected    = multi and {} or ""
                dLabel.Text = ValueText()
                State.Set(dc.Flag, selected)
                Rebuild()
            end
            function obj:Enable()
                disabled = false
                Tween(dBtn, { BackgroundTransparency = 0 }, TI_FAST)
            end
            function obj:Disable()
                disabled = true
                Tween(dBtn, { BackgroundTransparency = 0.5 }, TI_FAST)
                if listOpen then CloseList() end
            end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(dc.Flag, obj)

            Registry.Register(dc.Flag,
                function() return selected end,
                function(v) obj:Set(v, true) end
            )
            if dc.Flag then State.Set(dc.Flag, selected) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  INPUT
        --  New: Numeric clamping, :SetPlaceholder, Min/Max/Step
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddInput(ic)
            ic      = ic or {}
            local cb      = ic.Callback    or function() end
            local numeric = ic.Numeric     or false
            local minVal  = ic.Min
            local maxVal  = ic.Max
            local step    = ic.Step
            local disabled = false
            local row     = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, ic.Name, ic.Description)

            local iBg = Create("Frame", {
                Size             = UDim2.new(0, 168, 0, 30),
                Position         = UDim2.new(1, -186, 0.5, -15),
                BackgroundColor3 = Theme.InputBg,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 3,
                Parent           = row,
            }); Round(iBg, 8)
            local iStroke = Stroke(iBg, Theme.Border, 1)

            local tb = Create("TextBox", {
                Size                  = UDim2.new(1, -18, 1, 0),
                Position              = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                PlaceholderText       = ic.Placeholder or "",
                PlaceholderColor3     = Theme.PlaceholderC,
                Text                  = tostring(ic.Default or ""),
                TextColor3            = Theme.LabelText,
                TextSize              = 12,
                Font                  = Enum.Font.Gotham,
                TextXAlignment        = Enum.TextXAlignment.Left,
                ClearTextOnFocus      = false,
                ZIndex                = Z.Content + 4,
                Parent                = iBg,
            })

            local function ClampNumeric(n)
                if minVal then n = math.max(n, minVal) end
                if maxVal then n = math.min(n, maxVal) end
                if step    then n = math.floor(n / step + 0.5) * step end
                return n
            end

            tb.Focused:Connect(function()
                if disabled then tb:ReleaseFocus(); return end
                Tween(iStroke, { Color = Theme.FocusBorder, Thickness = 1.5 }, TI_FAST)
            end)
            tb.FocusLost:Connect(function()
                Tween(iStroke, { Color = Theme.Border, Thickness = 1 }, TI_FAST)
                local v = tb.Text
                if numeric then
                    local n = tonumber(v)
                    if n == nil then
                        tb.Text = tostring(ic.Default or 0)
                        v       = tb.Text
                    else
                        n       = ClampNumeric(n)
                        tb.Text = tostring(n)
                        v       = n
                    end
                end
                State.Set(ic.Flag, v)
                SafeCall(cb, v, true)
            end)

            local obj = { Flag = ic.Flag }
            function obj:Set(v, silent)
                tb.Text = tostring(v)
                local val = numeric and (ClampNumeric(tonumber(v) or 0)) or tostring(v)
                if numeric then tb.Text = tostring(val) end
                local prev = State.Get(ic.Flag)
                State.Set(ic.Flag, val)
                obj:_FireChanged(val, prev)
                if not silent then SafeCall(cb, val, false) end
            end
            function obj:Get()
                if numeric then return tonumber(tb.Text) or 0 end
                return tb.Text
            end
            function obj:SetPlaceholder(text)
                tb.PlaceholderText = tostring(text or "")
            end
            function obj:Enable()
                disabled = false
                Tween(iBg, { BackgroundColor3 = Theme.InputBg }, TI_FAST)
                tb.TextEditable = true
            end
            function obj:Disable()
                disabled = true
                Tween(iBg, { BackgroundColor3 = Theme.DisabledBg }, TI_FAST)
                tb.TextEditable = false
            end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(ic.Flag, obj)

            Registry.Register(ic.Flag,
                function() return obj:Get() end,
                function(v) obj:Set(v, true) end
            )
            if ic.Flag then State.Set(ic.Flag, obj:Get()) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  SLIDER
        --  New: SetMin, SetMax, SetRange, step snapping fixed
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddSlider(sc)
            sc     = sc or {}
            local minV   = sc.Min    or 0
            local maxV   = sc.Max    or 100
            local suffix = sc.Suffix or ""
            local step   = sc.Step   or 1
            local cb     = sc.Callback or function() end
            local throttledCb = Throttle(function(v) SafeCall(cb, v) end, sc.Throttle or 0.035)
            local val    = math.clamp(sc.Default or minV, minV, maxV)
            local dragging = false
            local disabled = false
            local row = MkRow(self, 70)
            local nameLbl, descLbl = RowLabels(row, sc.Name, sc.Description)

            local valLbl = Create("TextLabel", {
                Name                  = "Val",
                Size                  = UDim2.new(0, 70, 0, 18),
                Position              = UDim2.new(1, -88, 0, 13),
                BackgroundTransparency = 1,
                Text                  = tostring(val) .. suffix,
                TextColor3            = Theme.Accent,
                TextSize              = 13,
                Font                  = Enum.Font.GothamBold,
                TextXAlignment        = Enum.TextXAlignment.Right,
                ZIndex                = Z.Content + 2,
                Parent                = row,
            })
            local trackBg = Create("Frame", {
                Size             = UDim2.new(1, -40, 0, 6),
                Position         = UDim2.new(0, 20, 1, -20),
                BackgroundColor3 = Theme.ToggleOff,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 2,
                Parent           = row,
            }); Round(trackBg, 4)
            local fill = Create("Frame", {
                Size             = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 3,
                Parent           = trackBg,
            }); Round(fill, 4)
            local knob = Create("Frame", {
                Size             = UDim2.new(0, 16, 0, 16),
                AnchorPoint      = Vector2.new(0.5, 0.5),
                Position         = UDim2.new((val - minV) / (maxV - minV), 0, 0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 4,
                Parent           = trackBg,
            }); Round(knob, 8)
            Create("UIStroke", { Color = Theme.Accent, Thickness = 2, Parent = knob })

            local function SnapToStep(raw)
                return math.clamp(math.floor(raw / step + 0.5) * step, minV, maxV)
            end

            local function UpdateVisuals()
                local frac = (maxV ~= minV) and ((val - minV) / (maxV - minV)) or 0
                fill.Size      = UDim2.new(frac, 0, 1, 0)
                knob.Position  = UDim2.new(frac, 0, 0.5, 0)
                valLbl.Text    = tostring(val) .. suffix
            end

            local function UpdateFromPos(pos)
                if disabled then return end
                local ab   = trackBg.AbsolutePosition
                local sz   = trackBg.AbsoluteSize
                local t    = math.clamp((pos.X - ab.X) / sz.X, 0, 1)
                val        = SnapToStep(minV + t * (maxV - minV))
                UpdateVisuals()
                State.Set(sc.Flag, val)
                throttledCb(val)
            end

            trackBg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    UpdateFromPos(i.Position)
                    Tween(knob, { Size = UDim2.new(0, 18, 0, 18) }, TI_FAST)
                end
            end)
            windowTasks:Connect(UserInputService.InputChanged, function(i)
                if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                    UpdateFromPos(i.Position)
                end
            end)
            windowTasks:Connect(UserInputService.InputEnded, function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                    Tween(knob, { Size = UDim2.new(0, 16, 0, 16) }, TI_FAST)
                end
            end)

            local obj = { Flag = sc.Flag }
            function obj:Set(v, silent)
                val = math.clamp(v, minV, maxV)
                UpdateVisuals()
                local prev = State.Get(sc.Flag)
                State.Set(sc.Flag, val)
                obj:_FireChanged(val, prev)
                if not silent then SafeCall(cb, val) end
            end
            function obj:Get() return val end
            function obj:SetMin(m)
                minV = m
                val  = math.clamp(val, minV, maxV)
                UpdateVisuals()
            end
            function obj:SetMax(m)
                maxV = m
                val  = math.clamp(val, minV, maxV)
                UpdateVisuals()
            end
            function obj:SetRange(mn, mx)
                minV = mn; maxV = mx
                val  = math.clamp(val, minV, maxV)
                UpdateVisuals()
            end
            function obj:Enable()
                disabled = false
                Tween(trackBg, { BackgroundTransparency = 0 }, TI_FAST)
            end
            function obj:Disable()
                disabled = true
                Tween(trackBg, { BackgroundTransparency = 0.5 }, TI_FAST)
            end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(sc.Flag, obj)

            Registry.Register(sc.Flag,
                function() return val end,
                function(v) obj:Set(v, true) end
            )
            if sc.Flag then State.Set(sc.Flag, val) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  BUTTON
        --  New: loading state, double-click guard, Enable/Disable
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddButton(bc)
            bc = bc or {}
            local cb       = bc.Callback or function() end
            local disabled = false
            local loading  = false
            local row      = MkRow(self, 54)
            local nameLbl, descLbl = RowLabels(row, bc.Name, bc.Description)

            local btn = Create("TextButton", {
                Size             = UDim2.new(0, 88, 0, 28),
                Position         = UDim2.new(1, -104, 0.5, -14),
                BackgroundColor3 = Theme.Accent,
                Text             = bc.Label or "Run",
                TextColor3       = Theme.TabActiveText,
                TextSize         = 12,
                Font             = Enum.Font.GothamSemibold,
                BorderSizePixel  = 0,
                AutoButtonColor  = false,
                ZIndex           = Z.Content + 3,
                Parent           = row,
            }); Round(btn, 8)

            btn.MouseEnter:Connect(function()
                if not disabled and not loading then
                    Tween(btn, { BackgroundColor3 = Theme.AccentHover }, TI_FAST)
                end
            end)
            btn.MouseLeave:Connect(function()
                if not disabled and not loading then
                    Tween(btn, { BackgroundColor3 = Theme.Accent }, TI_FAST)
                end
            end)
            btn.MouseButton1Down:Connect(function()
                if not disabled and not loading then
                    Tween(btn, { BackgroundColor3 = Theme.AccentPress }, TI_FAST)
                end
            end)
            btn.MouseButton1Up:Connect(function()
                if not disabled and not loading then
                    Tween(btn, { BackgroundColor3 = Theme.AccentHover }, TI_FAST)
                end
            end)

            local lastClick = 0
            btn.MouseButton1Click:Connect(Debounce(function()
                if disabled or loading then return end
                SafeCall(cb)
            end, 0.3))

            local obj = {}
            function obj:SetLabel(text) btn.Text = tostring(text or "") end
            function obj:SetLoading(state)
                loading  = not not state
                btn.Text = loading and "..." or (bc.Label or "Run")
                btn.BackgroundTransparency = loading and 0.3 or 0
            end
            function obj:Enable()
                disabled = false
                Tween(btn, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0 }, TI_FAST)
                btn.Active = true
            end
            function obj:Disable()
                disabled = true
                Tween(btn, { BackgroundColor3 = Theme.DisabledBg, BackgroundTransparency = 0 }, TI_FAST)
                btn.Active = false
            end
            ApplyMixin(obj, row, nameLbl, descLbl)
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  KEYBIND
        --  New: flag support, :SetKey API
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddKeybind(kc)
            kc = kc or {}
            local key       = kc.Default or Enum.KeyCode.Unknown
            local cb        = kc.Callback or function() end
            local listening = false
            local row       = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, kc.Name, kc.Description)

            local kbBg = Create("Frame", {
                Size             = UDim2.new(0, 100, 0, 28),
                Position         = UDim2.new(1, -118, 0.5, -14),
                BackgroundColor3 = Theme.InputBg,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 3,
                Parent           = row,
            }); Round(kbBg, 8)
            local kbStroke = Stroke(kbBg, Theme.Border, 1)
            local kbBtn = Create("TextButton", {
                Size                  = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                  = key.Name,
                TextColor3            = Theme.ValueText,
                TextSize              = 12,
                Font                  = Enum.Font.GothamSemibold,
                BorderSizePixel       = 0,
                ZIndex                = Z.Content + 4,
                Parent                = kbBg,
            })

            kbBtn.MouseButton1Click:Connect(function()
                if listening then return end
                listening     = true
                kbBtn.Text    = "Press..."
                kbBtn.TextColor3 = Theme.Accent
                Tween(kbStroke, { Color = Theme.FocusBorder }, TI_FAST)
            end)

            windowTasks:Connect(UserInputService.InputBegan, function(i)
                if not listening then return end
                if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
                key            = i.KeyCode
                listening      = false
                kbBtn.Text     = key.Name
                kbBtn.TextColor3 = Theme.ValueText
                Tween(kbStroke, { Color = Theme.Border }, TI_FAST)
                State.Set(kc.Flag, key.Name)
            end)

            windowTasks:Connect(UserInputService.InputBegan, function(i, gpe)
                if gpe then return end
                if not listening
                    and i.UserInputType == Enum.UserInputType.Keyboard
                    and i.KeyCode == key
                then
                    SafeCall(cb, key)
                end
            end)

            local obj = { Flag = kc.Flag }
            function obj:Set(k)
                if type(k) == "string" then
                    for _, kCode in pairs(Enum.KeyCode:GetEnumItems()) do
                        if kCode.Name == k then k = kCode; break end
                    end
                end
                if typeof(k) ~= "EnumItem" then return self end
                key        = k
                kbBtn.Text = k.Name
                State.Set(kc.Flag, k.Name)
                return self
            end
            function obj:Get() return key end
            function obj:SetKey(k) obj:Set(k) end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(kc.Flag, obj)

            Registry.Register(kc.Flag,
                function() return key.Name end,
                function(v)
                    for _, kCode in pairs(Enum.KeyCode:GetEnumItems()) do
                        if kCode.Name == v then obj:Set(kCode); break end
                    end
                end
            )
            if kc.Flag then State.Set(kc.Flag, key.Name) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  COLOR PICKER
        --  New: full flag support + :Set/:Get
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddColorPicker(cpc)
            cpc = cpc or {}
            local val    = cpc.Default or Color3.fromRGB(255, 255, 255)
            local cb     = cpc.Callback or function() end
            local row    = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, cpc.Name, cpc.Description)

            -- ── Color helpers ────────────────────────────────────────────────
            local function HSVtoRGB(h, s, v)
                h = h % 360
                local c = v * s
                local x = c * (1 - math.abs((h / 60) % 2 - 1))
                local m = v - c
                local r, g, b
                if     h < 60  then r, g, b = c, x, 0
                elseif h < 120 then r, g, b = x, c, 0
                elseif h < 180 then r, g, b = 0, c, x
                elseif h < 240 then r, g, b = 0, x, c
                elseif h < 300 then r, g, b = x, 0, c
                else              r, g, b = c, 0, x end
                return Color3.new(r + m, g + m, b + m)
            end
            local function RGBtoHSV(c3)
                local r, g, b = c3.R, c3.G, c3.B
                local mx = math.max(r, g, b); local mn = math.min(r, g, b)
                local d = mx - mn; local v = mx
                local s = mx == 0 and 0 or d / mx; local h = 0
                if d ~= 0 then
                    if     mx == r then h = ((g - b) / d) % 6
                    elseif mx == g then h = (b - r) / d + 2
                    else              h = (r - g) / d + 4 end
                    h = h * 60
                end
                if h < 0 then h = h + 360 end
                return h, s, v
            end
            local function ToHex(c)
                return string.format("#%02X%02X%02X",
                    math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
            end
            local function FromHex(h)
                h = h:gsub("#", "")
                if #h ~= 6 then return nil end
                local r,g,b = tonumber(h:sub(1,2),16), tonumber(h:sub(3,4),16), tonumber(h:sub(5,6),16)
                if r and g and b then return Color3.fromRGB(r,g,b) end
            end

            local hue, sat, valu = RGBtoHSV(val)
            local pickerFrame; local pickerOpen = false

            -- Row: color swatch (clickable) + hex label
            local swatch = Create("Frame", {
                Size             = UDim2.new(0, 44, 0, 24),
                Position         = UDim2.new(1, -60, 0.5, -12),
                BackgroundColor3 = val,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 3,
                Parent           = row,
            }); Round(swatch, 6); Stroke(swatch, Theme.Border, 1)
            local swatchBtn = Create("TextButton", {
                Size = UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="",
                ZIndex = Z.Content + 4, Parent = swatch,
            })
            local hexLabel = Create("TextLabel", {
                Size                  = UDim2.new(0, 66, 0, 24),
                Position              = UDim2.new(1, -136, 0.5, -12),
                BackgroundTransparency = 1,
                Text                  = ToHex(val),
                TextColor3            = Theme.ValueText,
                TextSize              = 11,
                Font                  = Enum.Font.GothamSemibold,
                TextXAlignment        = Enum.TextXAlignment.Right,
                ZIndex                = Z.Content + 3,
                Parent                = row,
            })

            -- ── Floating HSV picker window ───────────────────────────────────
            local function OpenPicker()
                if pickerOpen then
                    if pickerFrame and pickerFrame.Parent then pickerFrame:Destroy() end
                    pickerOpen = false; return
                end
                pickerOpen = true
                local PW, PH = 264, 312
                local abp = swatch.AbsolutePosition
                local vp  = workspace.CurrentCamera.ViewportSize
                local px  = math.clamp(abp.X - PW - 10, 0, vp.X - PW)
                local py  = math.clamp(abp.Y - 60, 0, vp.Y - PH)

                pickerFrame = Create("Frame", {
                    Name="ColorPicker", Size=UDim2.new(0,PW,0,PH),
                    Position=UDim2.new(0,px,0,py),
                    BackgroundColor3=Theme.DropdownBg, BorderSizePixel=0,
                    ZIndex=Z.Popup, Parent=sg,
                }); Round(pickerFrame, 10); Stroke(pickerFrame, Theme.Border, 1)

                local titleBar = Create("Frame", {
                    Size=UDim2.new(1,0,0,38), BackgroundColor3=Theme.TitleBarBg,
                    BorderSizePixel=0, ZIndex=Z.Popup, Parent=pickerFrame,
                })
                Create("UICorner", { CornerRadius=UDim.new(0,10), Parent=titleBar })
                Create("Frame", { Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0.5,0),
                    BackgroundColor3=Theme.TitleBarBg, BorderSizePixel=0, ZIndex=Z.Popup, Parent=titleBar })
                Create("Frame", { Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1),
                    BackgroundColor3=Theme.Separator, BorderSizePixel=0, ZIndex=Z.Popup+1, Parent=titleBar })
                Create("TextLabel", {
                    Size=UDim2.new(1,-44,1,0), Position=UDim2.new(0,14,0,0),
                    BackgroundTransparency=1, Text="Pick Color", TextColor3=Theme.TitleText,
                    TextSize=13, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left,
                    ZIndex=Z.Popup+1, Parent=titleBar,
                })
                local closeP = Create("TextButton", {
                    Size=UDim2.new(0,28,0,28), Position=UDim2.new(1,-34,0.5,-14),
                    BackgroundTransparency=1, Text="✕", TextColor3=Theme.SubtitleText,
                    TextSize=11, Font=Enum.Font.GothamBold, BorderSizePixel=0,
                    ZIndex=Z.Popup+2, Parent=titleBar,
                })
                for _, conn in ipairs(Draggable(titleBar, pickerFrame)) do windowTasks:Add(conn) end

                local M=14; local SW=PW-M*2; local SVH=126

                -- SV 2D picker
                local svFrame = Create("Frame", {
                    Size=UDim2.new(0,SW,0,SVH), Position=UDim2.new(0,M,0,46),
                    BackgroundColor3=HSVtoRGB(hue,1,1), BorderSizePixel=0,
                    ClipsDescendants=true, ZIndex=Z.Popup+1, Parent=pickerFrame,
                }); Round(svFrame, 6)
                local whiteL = Create("Frame", {
                    Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(1,1,1),
                    BorderSizePixel=0, ZIndex=Z.Popup+2, Parent=svFrame,
                })
                Create("UIGradient", {
                    Color=ColorSequence.new(Color3.new(1,1,1)),
                    Transparency=NumberSequence.new({
                        NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1),
                    }), Parent=whiteL,
                })
                local blackL = Create("Frame", {
                    Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(0,0,0),
                    BorderSizePixel=0, ZIndex=Z.Popup+3, Parent=svFrame,
                })
                Create("UIGradient", {
                    Color=ColorSequence.new(Color3.new(0,0,0)),
                    Transparency=NumberSequence.new({
                        NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0),
                    }), Rotation=90, Parent=blackL,
                })
                local svKnob = Create("Frame", {
                    Size=UDim2.new(0,12,0,12), AnchorPoint=Vector2.new(0.5,0.5),
                    Position=UDim2.new(sat,0,1-valu,0), BackgroundColor3=Color3.new(1,1,1),
                    BorderSizePixel=0, ZIndex=Z.Popup+4, Parent=svFrame,
                }); Round(svKnob,6); Create("UIStroke",{Color=Color3.new(0,0,0),Thickness=1.5,Parent=svKnob})
                local svInput = Create("TextButton", {
                    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="",
                    ZIndex=Z.Popup+5, Parent=svFrame,
                })

                -- Hue slider
                local hueY = 46 + SVH + 10
                local hueBar = Create("Frame", {
                    Size=UDim2.new(0,SW,0,12), Position=UDim2.new(0,M,0,hueY),
                    BorderSizePixel=0, ZIndex=Z.Popup+1, Parent=pickerFrame,
                }); Round(hueBar,6)
                Create("UIGradient", { Color=ColorSequence.new({
                    ColorSequenceKeypoint.new(0/6, Color3.fromRGB(255,0,0)),
                    ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255,255,0)),
                    ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0,255,0)),
                    ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0,255,255)),
                    ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0,0,255)),
                    ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255,0,255)),
                    ColorSequenceKeypoint.new(1,   Color3.fromRGB(255,0,0)),
                }), Parent=hueBar })
                local hueKnob = Create("Frame", {
                    Size=UDim2.new(0,12,0,12), AnchorPoint=Vector2.new(0.5,0.5),
                    Position=UDim2.new(hue/360,0,0.5,0), BackgroundColor3=Color3.new(1,1,1),
                    BorderSizePixel=0, ZIndex=Z.Popup+2, Parent=hueBar,
                }); Round(hueKnob,6); Create("UIStroke",{Color=Color3.new(0,0,0),Thickness=1.5,Parent=hueKnob})
                local hueInput = Create("TextButton", {
                    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="",
                    ZIndex=Z.Popup+3, Parent=hueBar,
                })

                -- Preview + hex input
                local previewY = hueY + 12 + 12
                local preview = Create("Frame", {
                    Size=UDim2.new(0,40,0,28), Position=UDim2.new(0,M,0,previewY),
                    BackgroundColor3=val, BorderSizePixel=0, ZIndex=Z.Popup+1, Parent=pickerFrame,
                }); Round(preview,6); Stroke(preview,Theme.Border,1)
                local hexBgP = Create("Frame", {
                    Size=UDim2.new(0,SW-52,0,28), Position=UDim2.new(0,M+48,0,previewY),
                    BackgroundColor3=Theme.InputBg, BorderSizePixel=0, ZIndex=Z.Popup+1, Parent=pickerFrame,
                }); Round(hexBgP,6)
                local hexBgStroke = Stroke(hexBgP, Theme.Border, 1)
                local hexIn = Create("TextBox", {
                    Size=UDim2.new(1,-12,1,0), Position=UDim2.new(0,8,0,0),
                    BackgroundTransparency=1, Text=ToHex(val), TextColor3=Theme.LabelText,
                    TextSize=12, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left,
                    ClearTextOnFocus=false, ZIndex=Z.Popup+2, Parent=hexBgP,
                })

                -- Apply / Cancel buttons
                local btnY = previewY + 36
                local halfW = math.floor((SW-6)/2)
                local cancelBtn = Create("TextButton", {
                    Size=UDim2.new(0,halfW,0,28), Position=UDim2.new(0,M,0,btnY),
                    BackgroundColor3=Theme.InputBg, Text="Cancel", TextColor3=Theme.LabelText,
                    TextSize=12, Font=Enum.Font.GothamSemibold, BorderSizePixel=0,
                    AutoButtonColor=false, ZIndex=Z.Popup+2, Parent=pickerFrame,
                }); Round(cancelBtn,7); Stroke(cancelBtn,Theme.Border,1)
                local applyBtn = Create("TextButton", {
                    Size=UDim2.new(0,halfW,0,28), Position=UDim2.new(0,M+halfW+6,0,btnY),
                    BackgroundColor3=Theme.Accent, Text="Apply", TextColor3=Color3.new(1,1,1),
                    TextSize=12, Font=Enum.Font.GothamSemibold, BorderSizePixel=0,
                    AutoButtonColor=false, ZIndex=Z.Popup+2, Parent=pickerFrame,
                }); Round(applyBtn,7)

                -- Live update
                local tempVal = val
                local function UpdateAll()
                    tempVal = HSVtoRGB(hue,sat,valu)
                    svFrame.BackgroundColor3 = HSVtoRGB(hue,1,1)
                    svKnob.Position  = UDim2.new(sat,0,1-valu,0)
                    hueKnob.Position = UDim2.new(hue/360,0,0.5,0)
                    preview.BackgroundColor3 = tempVal
                    hexIn.Text = ToHex(tempVal)
                end

                local svDrag=false
                svInput.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then
                        svDrag=true
                        local ab=svFrame.AbsolutePosition; local sz=svFrame.AbsoluteSize
                        sat=math.clamp((i.Position.X-ab.X)/sz.X,0,1)
                        valu=math.clamp(1-(i.Position.Y-ab.Y)/sz.Y,0,1); UpdateAll()
                    end
                end)
                local svMC=windowTasks:Connect(UserInputService.InputChanged, function(i)
                    if svDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
                        local ab=svFrame.AbsolutePosition; local sz=svFrame.AbsoluteSize
                        sat=math.clamp((i.Position.X-ab.X)/sz.X,0,1)
                        valu=math.clamp(1-(i.Position.Y-ab.Y)/sz.Y,0,1); UpdateAll()
                    end
                end)
                local svEC=windowTasks:Connect(UserInputService.InputEnded, function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then svDrag=false end
                end)

                local hueDrag=false
                hueInput.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then
                        hueDrag=true
                        local ab=hueBar.AbsolutePosition; local sz=hueBar.AbsoluteSize
                        hue=math.clamp((i.Position.X-ab.X)/sz.X,0,1)*360; UpdateAll()
                    end
                end)
                local hueMC=windowTasks:Connect(UserInputService.InputChanged, function(i)
                    if hueDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
                        local ab=hueBar.AbsolutePosition; local sz=hueBar.AbsoluteSize
                        hue=math.clamp((i.Position.X-ab.X)/sz.X,0,1)*360; UpdateAll()
                    end
                end)
                local hueEC=windowTasks:Connect(UserInputService.InputEnded, function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=false end
                end)

                hexIn.Focused:Connect(function() Tween(hexBgStroke,{Color=Theme.FocusBorder},TI_FAST) end)
                hexIn.FocusLost:Connect(function()
                    Tween(hexBgStroke,{Color=Theme.Border},TI_FAST)
                    local c=FromHex(hexIn.Text)
                    if c then hue,sat,valu=RGBtoHSV(c); UpdateAll()
                    else hexIn.Text=ToHex(tempVal) end
                end)

                cancelBtn.MouseEnter:Connect(function() Tween(cancelBtn,{BackgroundColor3=Theme.ItemHover},TI_FAST) end)
                cancelBtn.MouseLeave:Connect(function() Tween(cancelBtn,{BackgroundColor3=Theme.InputBg},TI_FAST) end)
                applyBtn.MouseEnter:Connect(function() Tween(applyBtn,{BackgroundColor3=Theme.AccentHover},TI_FAST) end)
                applyBtn.MouseLeave:Connect(function() Tween(applyBtn,{BackgroundColor3=Theme.Accent},TI_FAST) end)

                local function ClosePicker(apply)
                    svMC:Disconnect(); svEC:Disconnect(); hueMC:Disconnect(); hueEC:Disconnect()
                    pickerOpen=false
                    if apply then
                        val=tempVal; swatch.BackgroundColor3=val
                        hexLabel.Text=ToHex(val); State.Set(cpc.Flag,val); SafeCall(cb,val)
                    else
                        hue,sat,valu=RGBtoHSV(val)
                    end
                    pcall(function() pickerFrame:Destroy() end)
                end

                closeP.MouseButton1Click:Connect(function() ClosePicker(false) end)
                cancelBtn.MouseButton1Click:Connect(function() ClosePicker(false) end)
                applyBtn.MouseButton1Click:Connect(function() ClosePicker(true) end)
            end

            swatchBtn.MouseButton1Click:Connect(function() OpenPicker() end)

            local obj = { Flag = cpc.Flag }
            function obj:Set(v, silent)
                if typeof(v) ~= "Color3" then return end
                val=v; hue,sat,valu=RGBtoHSV(val)
                swatch.BackgroundColor3=val; hexLabel.Text=ToHex(val)
                local prev = State.Get(cpc.Flag)
                State.Set(cpc.Flag,val)
                obj:_FireChanged(val, prev)
                if not silent then SafeCall(cb,val) end
            end
            function obj:Get() return val end
            function obj:Enable()  swatchBtn.Active=true end
            function obj:Disable() swatchBtn.Active=false end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(cpc.Flag, obj)
            Registry.Register(cpc.Flag,
                function() return val end,
                function(v) obj:Set(v,true) end
            )
            if cpc.Flag then State.Set(cpc.Flag,val) end
            return obj
        end


        function Tab:AddSearchBox(ic)
            ic = ic or {}
            ic.Placeholder = ic.Placeholder or "Search..."
            return self:AddInput(ic)
        end

        function Tab:AddCheckboxGroup(cc)
            cc = cc or {}
            cc.Multi = true
            return self:AddDropdown(cc)
        end

        function Tab:AddRadioGroup(rc)
            rc = rc or {}
            rc.Multi = false
            return self:AddSegmentedControl(rc)
        end

        function Tab:AddTextArea(ic)
            ic = ic or {}
            local cb = ic.Callback or function() end
            local row = MkRow(self, ic.Height or 120)
            local nameLbl, descLbl = RowLabels(row, ic.Name, ic.Description)
            local bg = Create("Frame", {
                Size = UDim2.new(1, -34, 0, (ic.Height or 120) - 42),
                Position = UDim2.new(0, 17, 0, 38),
                BackgroundColor3 = Theme.InputBg, BorderSizePixel = 0, ZIndex = Z.Content + 2, Parent = row,
            }); Round(bg, 8); local stroke = Stroke(bg, Theme.Border, 1)
            local tb = Create("TextBox", {
                Size = UDim2.new(1, -20, 1, -12), Position = UDim2.new(0, 10, 0, 6),
                BackgroundTransparency = 1, PlaceholderText = ic.Placeholder or "", PlaceholderColor3 = Theme.PlaceholderC,
                Text = tostring(ic.Default or ""), TextColor3 = Theme.LabelText, TextSize = 12, Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, MultiLine = true,
                ClearTextOnFocus = false, ZIndex = Z.Content + 3, Parent = bg,
            })
            tb.Focused:Connect(function() Tween(stroke, { Color = Theme.FocusBorder }, TI_FAST) end)
            tb.FocusLost:Connect(function()
                Tween(stroke, { Color = Theme.Border }, TI_FAST)
                State.Set(ic.Flag, tb.Text)
                SafeCall(cb, tb.Text, true)
            end)
            local obj = { Flag = ic.Flag }
            function obj:Set(v, silent)
                local prev = State.Get(ic.Flag)
                tb.Text = tostring(v or "")
                State.Set(ic.Flag, tb.Text)
                obj:_FireChanged(tb.Text, prev)
                if not silent then SafeCall(cb, tb.Text, false) end
            end
            function obj:Get() return tb.Text end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(ic.Flag, obj)
            Registry.Register(ic.Flag, function() return tb.Text end, function(v) obj:Set(v, true) end)
            if ic.Flag then State.Set(ic.Flag, tb.Text) end
            return obj
        end

        function Tab:AddProgressBar(pc)
            pc = pc or {}
            local minV, maxV = pc.Min or 0, pc.Max or 100
            local val = math.clamp(pc.Default or minV, minV, maxV)
            local row = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, pc.Name, pc.Description)
            local track = Create("Frame", { Size = UDim2.new(0, 170, 0, 10), Position = UDim2.new(1, -188, 0.5, -5), BackgroundColor3 = Theme.ToggleOff, BorderSizePixel = 0, ZIndex = Z.Content + 2, Parent = row })
            Round(track, 6)
            local fill = Create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = Z.Content + 3, Parent = track })
            Round(fill, 6)
            local valueLbl = Create("TextLabel", { Size = UDim2.new(0, 170, 0, 18), Position = UDim2.new(1, -188, 0, 12), BackgroundTransparency = 1, TextColor3 = Theme.ValueText, TextSize = 11, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = Z.Content + 3, Parent = row })
            local function Update()
                local frac = maxV ~= minV and ((val - minV) / (maxV - minV)) or 0
                fill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
                valueLbl.Text = tostring(val) .. (pc.Suffix or "%")
            end
            Update()
            local obj = { Flag = pc.Flag }
            function obj:Set(v, silent)
                local prev = State.Get(pc.Flag)
                val = math.clamp(tonumber(v) or minV, minV, maxV)
                Update(); State.Set(pc.Flag, val); obj:_FireChanged(val, prev)
                if not silent and pc.Callback then SafeCall(pc.Callback, val) end
            end
            function obj:Get() return val end
            function obj:Increment(amount) self:Set(val + (amount or 1)); return self end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(pc.Flag, obj)
            Registry.Register(pc.Flag, function() return val end, function(v) obj:Set(v, true) end)
            if pc.Flag then State.Set(pc.Flag, val) end
            return obj
        end

        function Tab:AddSegmentedControl(scfg)
            scfg = scfg or {}
            local opts = scfg.Options or {}
            local cb = scfg.Callback or function() end
            local selected = scfg.Default or opts[1] or ""
            local row = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, scfg.Name, scfg.Description)
            local holder = Create("Frame", { Size = UDim2.new(0, scfg.Width or 220, 0, 30), Position = UDim2.new(1, -(scfg.Width or 220) - 18, 0.5, -15), BackgroundColor3 = Theme.InputBg, BorderSizePixel = 0, ZIndex = Z.Content + 2, Parent = row })
            Round(holder, 8); Stroke(holder, Theme.Border, 1)
            local buttons = {}
            local buttonValues = {}
            local function Redraw()
                for _, btn in ipairs(buttons) do
                    local on = buttonValues[btn] == selected
                    Tween(btn, { BackgroundColor3 = on and Theme.Accent or Theme.InputBg }, TI_FAST)
                    btn.TextColor3 = on and Color3.fromRGB(255,255,255) or Theme.ValueText
                end
            end
            local count = math.max(#opts, 1)
            for i, opt in ipairs(opts) do
                local btn = Create("TextButton", {
                    Size = UDim2.new(1 / count, -2, 1, -4), Position = UDim2.new((i - 1) / count, 1, 0, 2),
                    BackgroundColor3 = opt == selected and Theme.Accent or Theme.InputBg, BorderSizePixel = 0, AutoButtonColor = false,
                    Text = tostring(opt), TextColor3 = opt == selected and Color3.fromRGB(255,255,255) or Theme.ValueText, TextSize = 11, Font = Enum.Font.GothamSemibold,
                    ZIndex = Z.Content + 3, Parent = holder,
                }); buttonValues[btn] = opt; Round(btn, 6); buttons[#buttons + 1] = btn
                btn.MouseButton1Click:Connect(function()
                    selected = opt; State.Set(scfg.Flag, selected); SafeCall(cb, selected); Redraw()
                end)
            end
            local obj = { Flag = scfg.Flag }
            function obj:Set(v, silent)
                local prev = State.Get(scfg.Flag)
                selected = v; State.Set(scfg.Flag, selected); obj:_FireChanged(selected, prev); Redraw()
                if not silent then SafeCall(cb, selected) end
            end
            function obj:Get() return selected end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Win:RegisterComponent(scfg.Flag, obj)
            Registry.Register(scfg.Flag, function() return selected end, function(v) obj:Set(v, true) end)
            if scfg.Flag then State.Set(scfg.Flag, selected) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  DIVIDER
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddDivider(dc)
            dc = dc or {}
            self._order = self._order + 1
            local parent = self._currentGroup or self._content
            local h = dc.Height or 1
            local margin = dc.Margin or 6
            local wrapper = Create("Frame", {
                Name             = "Row_" .. self._order,
                Size             = UDim2.new(1, 0, 0, h + margin * 2),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = Z.Content,
                Parent           = parent,
            })
            Create("Frame", {
                Size             = UDim2.new(1, -24, 0, h),
                Position         = UDim2.new(0, 12, 0.5, 0),
                AnchorPoint      = Vector2.new(0, 0.5),
                BackgroundColor3 = dc.Color or Theme.Separator,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 1,
                Parent           = wrapper,
            })
            if dc.Label and dc.Label ~= "" then
                local lbl = Create("TextLabel", {
                    Size                  = UDim2.new(0, 0, 1, 0),
                    AutomaticSize         = Enum.AutomaticSize.X,
                    AnchorPoint           = Vector2.new(0.5, 0.5),
                    Position              = UDim2.new(0.5, 0, 0.5, 0),
                    BackgroundColor3      = Theme.ContentBg,
                    BackgroundTransparency = 0,
                    BorderSizePixel       = 0,
                    Text                  = "  " .. dc.Label .. "  ",
                    TextColor3            = Theme.SectionLabel,
                    TextSize              = 10,
                    Font                  = Enum.Font.GothamBold,
                    ZIndex                = Z.Content + 2,
                    Parent                = wrapper,
                })
                Pad(lbl, 0, 0, 4, 4)
            end
            local obj = {}
            function obj:Show() wrapper.Visible = true; return self end
            function obj:Hide() wrapper.Visible = false; return self end
            function obj:Destroy() pcall(function() wrapper:Destroy() end) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  RICH TEXT BLOCK
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddRichText(rc)
            rc = rc or {}
            self._order = self._order + 1
            local parent = self._currentGroup or self._content
            local txt = rc.Text or ""
            local minH = rc.Height or 0

            local row = Create("Frame", {
                Name             = "Row_" .. self._order,
                Size             = UDim2.new(1, 0, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.RowBg,
                BackgroundTransparency = 0,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = Z.Content,
                Parent           = parent,
            })
            if not self._currentGroup then
                Round(row, 8); Stroke(row, Theme.Border, 1)
            end
            Pad(row, 12, 12, 16, 16)

            local lbl = Create("TextLabel", {
                Size                  = UDim2.new(1, 0, 0, 0),
                AutomaticSize         = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text                  = txt,
                TextColor3            = rc.Color or Theme.LabelText,
                TextSize              = rc.TextSize or 12,
                Font                  = rc.Font or Enum.Font.Gotham,
                TextXAlignment        = Enum.TextXAlignment.Left,
                TextWrapped           = true,
                RichText              = rc.RichText ~= false,
                ZIndex                = Z.Content + 1,
                Parent                = row,
            })

            local obj = {}
            function obj:Set(v)
                lbl.Text = tostring(v or "")
                return self
            end
            function obj:Get() return lbl.Text end
            function obj:SetColor(col) lbl.TextColor3 = col; return self end
            function obj:Show() row.Visible = true; return self end
            function obj:Hide() row.Visible = false; return self end
            function obj:Destroy() pcall(function() row:Destroy() end) end
            return obj
        end

        -- ════════════════════════════════════════════════════════════════════
        --  PROGRESS BAR
        -- ════════════════════════════════════════════════════════════════════
        function Tab:AddProgressBar(pc)
            pc = pc or {}
            local val     = math.clamp(tonumber(pc.Default) or 0, 0, 1)
            local cb      = pc.Callback or function() end
            local row     = MkRow(self)
            local nameLbl, descLbl = RowLabels(row, pc.Name, pc.Description)

            local trackBg = Create("Frame", {
                Size             = UDim2.new(0, 200, 0, 8),
                Position         = UDim2.new(1, -220, 0.5, -4),
                BackgroundColor3 = Theme.LoaderBarBg,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 2,
                Parent           = row,
            }); Round(trackBg, 4)

            local fill = Create("Frame", {
                Size             = UDim2.new(val, 0, 1, 0),
                BackgroundColor3 = pc.Color or Theme.Accent,
                BorderSizePixel  = 0,
                ZIndex           = Z.Content + 3,
                Parent           = trackBg,
            }); Round(fill, 4)

            local pctLbl = Create("TextLabel", {
                Size                  = UDim2.new(0, 36, 1, 0),
                Position              = UDim2.new(1, -16, 0, 0),
                AnchorPoint          = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Text                  = math.floor(val * 100) .. "%",
                TextColor3            = Theme.ValueText,
                TextSize              = 11,
                Font                  = Enum.Font.GothamSemibold,
                TextXAlignment        = Enum.TextXAlignment.Right,
                ZIndex                = Z.Content + 4,
                Parent                = trackBg,
            })

            local obj = { Flag = pc.Flag }
            local _pulseToken = nil

            local function ApplyVal(v, silent)
                val = math.clamp(tonumber(v) or 0, 0, 1)
                local prev = State.Get(pc.Flag)
                Tween(fill, { Size = UDim2.new(val, 0, 1, 0) }, TI_MID)
                pctLbl.Text = math.floor(val * 100) .. "%"
                State.Set(pc.Flag, val)
                if not silent then SafeCall(cb, val) end
            end

            function obj:Set(v, silent) ApplyVal(v, silent); return self end
            function obj:Get() return val end
            function obj:SetColor(col)
                fill.BackgroundColor3 = col
                return self
            end
            function obj:Animate(target, duration)
                local ti = TweenInfo.new(duration or 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local t = math.clamp(tonumber(target) or 0, 0, 1)
                TweenService:Create(fill, ti, { Size = UDim2.new(t, 0, 1, 0) }):Play()
                task.delay(duration or 1, function()
                    val = t
                    pctLbl.Text = math.floor(val * 100) .. "%"
                end)
                return self
            end
            function obj:Pulse()
                if _pulseToken then _pulseToken.Alive = false end
                _pulseToken = { Alive = true }
                task.spawn(function()
                    while _pulseToken.Alive do
                        Tween(fill, { BackgroundColor3 = Theme.AccentHover },
                            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
                        task.wait(0.7)
                        if not _pulseToken.Alive then break end
                        Tween(fill, { BackgroundColor3 = pc.Color or Theme.Accent },
                            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
                        task.wait(0.7)
                    end
                end)
                return self
            end
            function obj:StopPulse()
                if _pulseToken then _pulseToken.Alive = false; _pulseToken = nil end
                fill.BackgroundColor3 = pc.Color or Theme.Accent
                return self
            end

            ApplyMixin(obj, row, nameLbl, descLbl)
            if pc.Flag then
                Win:RegisterComponent(pc.Flag, obj)
                Registry.Register(pc.Flag, function() return val end, function(v) ApplyVal(v, true) end)
                State.Set(pc.Flag, val)
            end
            return obj
        end

        -- GroupEnd: exit the current section group so next rows are top-level
        function Tab:GroupEnd()
            self._currentGroup = nil
            return self
        end

        function Tab:Clear()
            for _, child in ipairs(self._content:GetChildren()) do
                if child:IsA("GuiObject") then child:Destroy() end
            end
            self._order = 0
            self._currentGroup = nil
            return self
        end

        function Tab:Remove(component)
            if type(component) == "table" and component.Destroy then component:Destroy() end
            return self
        end

        function Tab:Show()
            self._scroll.Visible = true
            return self
        end

        function Tab:Hide()
            self._scroll.Visible = false
            return self
        end

        function Tab:Activate()
            ActivateTab(self, true)
            return self
        end

        function Tab:SetStyle(styles, persistent)
            CrispyLib.Style(self._content, styles, persistent)
            return self
        end

        function Tab:SetOpacity(opacity)
            CrispyLib.SetOpacity(self._content, opacity)
            return self
        end

        function Tab:TaskGroup(name)
            local group = CrispyLib.CreateTaskGroup(name or ("TabTask:" .. tName))
            windowTasks:Add(group)
            return group
        end

        if autoLoad then
            task.defer(function()
                CrispyLib.Config.Load()
            end)
        end

        return Tab
    end -- Win:AddTab

    return Win
end -- CrispyLib.CreateWindow

-- ════════════════════════════════════════════════════════════════════════════
--  PUBLIC UTILITY  (unchanged surface from v1)
-- ════════════════════════════════════════════════════════════════════════════

-- Quick state read/write from outside
function CrispyLib.GetFlag(flag)  return State.Get(flag) end
function CrispyLib.SetFlag(flag, value) State.Set(flag, value) end
function CrispyLib.Watch(flag, fn) return State.Subscribe(flag, fn) end
function CrispyLib.SetStyle(target, styles, persistent) return CrispyLib.Style(target, styles, persistent) end
function CrispyLib.SetThemeValue(key, value) return CrispyLib.SetTheme({ [key] = value }) end
function CrispyLib.SetThemePresetValue(name, key, value)
    local preset = CrispyLib.ThemePresets[name]
    if not preset then return false end
    preset[key] = value
    return true
end

-- AnimateThemeTransition: smoothly tween between two themes by lerping Color3 values
function CrispyLib.AnimateThemeTransition(presetNameOrTable, duration)
    local target = type(presetNameOrTable) == "string"
        and CrispyLib.ThemePresets[presetNameOrTable]
        or  (type(presetNameOrTable) == "table" and presetNameOrTable)
    if not target then return false end
    duration = math.max(tonumber(duration) or 0.4, 0.05)

    local steps = math.max(math.floor(duration / 0.016), 10)
    local current = ShallowCopy(Theme)

    task.spawn(function()
        for step = 1, steps do
            local alpha = step / steps
            local patch = {}
            for k, targetVal in pairs(target) do
                local fromVal = current[k]
                if typeof(targetVal) == "Color3" and typeof(fromVal) == "Color3" then
                    patch[k] = fromVal:Lerp(targetVal, alpha)
                end
            end
            CrispyLib.SetTheme(patch)
            task.wait(duration / steps)
        end
        -- Final snap to exact values
        CrispyLib.SetTheme(ShallowCopy(target))
    end)
    return true
end

return CrispyLib
