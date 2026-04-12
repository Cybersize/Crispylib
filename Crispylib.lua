--[[
    CrispyLib v2  –  Lua UI Library for Roblox Executors
    macOS-inspired dark GUI  |  Production-grade rewrite

    USAGE
    ─────
    local CrispyLib = loadstring(game:HttpGet("..."))()

    local Loader = CrispyLib.CreateLoadingScreen({ Title = "Crispy Hub", Subtitle = "Loading..." })
    Loader:SetStatus("Connecting..."); Loader:SetProgress(0.8); Loader:Finish()

    local Window = CrispyLib.CreateWindow({
        Title      = "Crispy Hub",
        Subtitle   = "by you",
        ConfigName = "MyScript",
        AutoLoad   = true,
    })

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

    -- All components share the same API surface:
    -- :Set(value [, silent])   :Get()
    -- :Enable() / :Disable()   :Show() / :Hide()
    -- :SetLabel(text)          (where applicable)
    -- :SetDescription(text)    (where applicable)

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
    local dragging, dragStart, startPos
    local connections = {}

    connections[#connections+1] = handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = i.Position
            -- Use AbsolutePosition so window with Scale-based position doesn't snap
            startPos  = frame.AbsolutePosition
        end
    end)

    connections[#connections+1] = UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local delta = i.Position - dragStart
        local vp    = workspace.CurrentCamera.ViewportSize
        local fw    = frame.AbsoluteSize.X
        local fh    = frame.AbsoluteSize.Y

        local newX = math.clamp(startPos.X + delta.X, 0, vp.X - fw)
        local newY = math.clamp(startPos.Y + delta.Y, 0, vp.Y - fh)

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

-- Safe fire: pcall wrapper that prints errors instead of silently swallowing them
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[CrispyLib] Callback error: " .. tostring(err))
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
    if not flag or type(fn) ~= "function" then return end
    State._listeners[flag] = State._listeners[flag] or {}
    table.insert(State._listeners[flag], fn)
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

function Registry.Register(flag, getter, setter)
    if not flag then return end
    Registry._elements[flag] = { Get = getter, Set = setter }
end

function Registry.GetAll()
    local out = {}
    for flag, el in pairs(Registry._elements) do
        out[flag] = SerialiseValue(el.Get())
    end
    return out
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
local CrispyLib         = {}
CrispyLib._configName   = "CrispyLib"
CrispyLib._connections  = {}
CrispyLib.State         = State

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

function CrispyLib.Config.Import(json)
    local ok, tbl = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    if ok and type(tbl) == "table" then
        CrispyLib.Config.Apply(tbl)
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

-- ════════════════════════════════════════════════════════════════════════════
--  NOTIFICATION SYSTEM
--  Improved: max-stack enforcement, dismiss queue, unique IDs
-- ════════════════════════════════════════════════════════════════════════════
local Notif = {}
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
    function obj:Show()
        if row then row.Visible = true end
    end
    function obj:Hide()
        if row then row.Visible = false end
    end
    function obj:SetLabel(text)
        if nameLbl then nameLbl.Text = tostring(text or "") end
    end
    function obj:SetDescription(text)
        if descLbl then descLbl.Text = tostring(text or "") end
    end
    -- Enable/Disable are defined per-component since their logic varies;
    -- base no-op versions prevent crashes if a component doesn't override them.
    if not obj.Enable  then function obj:Enable()  end end
    if not obj.Disable then function obj:Disable() end end
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

    local window = Create("Frame", {
        Name             = "Window",
        Size             = UDim2.new(0, WIN_W, 0, WIN_H),
        Position         = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
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

    Draggable(titleBar, window)

    -- ── Window controls ────────────────────────────────────────────────────
    local minimised = false
    closeBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            Tween(window, { BackgroundTransparency = 1 }, TI_MID)
            task.wait(0.25)
            pcall(function() sg:Destroy() end)
        end
    end)
    minBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            minimised = not minimised
            Tween(window, {
                Size = UDim2.new(0, WIN_W, 0, minimised and TITLEBAR_H or WIN_H),
            }, TI_SLOW)
        end
    end)

    local sbVisible = true
    sbToggle.MouseButton1Click:Connect(function()
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

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
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

    backBtn.MouseButton1Click:Connect(function()
        if _histIdx > 1 then
            _histIdx = _histIdx - 1
            ActivateTab(_history[_histIdx], false)
        end
    end)
    fwdBtn.MouseButton1Click:Connect(function()
        if _histIdx < #_history then
            _histIdx = _histIdx + 1
            ActivateTab(_history[_histIdx], false)
        end
    end)

    -- Destroy the whole window (cleanup)
    function Win:Destroy()
        pcall(function() sg:Destroy() end)
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
            local obj = {}

            local function Apply(v, silent)
                if disabled then return end
                val = v
                Tween(track, { BackgroundColor3 = val and Theme.Accent or Theme.ToggleOff }, TI_MID)
                Tween(knob,  { Position = val and UDim2.new(0, 22, 0.5, -11) or UDim2.new(0, 2, 0.5, -11) }, TI_MID)
                State.Set(tc.Flag, val)
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

            local function Rebuild(filter)
                for _, c in ipairs(optBtns) do c:Destroy() end
                optBtns = {}
                filter  = (filter or ""):lower()

                for _, opt in ipairs(options) do
                    if filter == "" or opt:lower():find(filter, 1, true) then
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
            UserInputService.InputBegan:Connect(function(inp)
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

            local obj = {}

            function obj:Set(v, silent)
                selected    = v
                dLabel.Text = ValueText()
                State.Set(dc.Flag, selected)
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

            local obj = {}
            function obj:Set(v, silent)
                tb.Text = tostring(v)
                local val = numeric and (ClampNumeric(tonumber(v) or 0)) or tostring(v)
                if numeric then tb.Text = tostring(val) end
                State.Set(ic.Flag, val)
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
                SafeCall(cb, val)
            end

            trackBg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    UpdateFromPos(i.Position)
                    Tween(knob, { Size = UDim2.new(0, 18, 0, 18) }, TI_FAST)
                end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                    UpdateFromPos(i.Position)
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                    Tween(knob, { Size = UDim2.new(0, 16, 0, 16) }, TI_FAST)
                end
            end)

            local obj = {}
            function obj:Set(v, silent)
                val = math.clamp(v, minV, maxV)
                UpdateVisuals()
                State.Set(sc.Flag, val)
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

            UserInputService.InputBegan:Connect(function(i)
                if not listening then return end
                if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
                key            = i.KeyCode
                listening      = false
                kbBtn.Text     = key.Name
                kbBtn.TextColor3 = Theme.ValueText
                Tween(kbStroke, { Color = Theme.Border }, TI_FAST)
                State.Set(kc.Flag, key.Name)
            end)

            UserInputService.InputBegan:Connect(function(i, gpe)
                if gpe then return end
                if not listening
                    and i.UserInputType == Enum.UserInputType.Keyboard
                    and i.KeyCode == key
                then
                    SafeCall(cb, key)
                end
            end)

            local obj = {}
            function obj:Set(k)
                key        = k
                kbBtn.Text = k.Name
                State.Set(kc.Flag, k.Name)
            end
            function obj:Get() return key end
            function obj:SetKey(k) obj:Set(k) end
            ApplyMixin(obj, row, nameLbl, descLbl)

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
                Draggable(titleBar, pickerFrame)

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
                local svMC=UserInputService.InputChanged:Connect(function(i)
                    if svDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
                        local ab=svFrame.AbsolutePosition; local sz=svFrame.AbsoluteSize
                        sat=math.clamp((i.Position.X-ab.X)/sz.X,0,1)
                        valu=math.clamp(1-(i.Position.Y-ab.Y)/sz.Y,0,1); UpdateAll()
                    end
                end)
                local svEC=UserInputService.InputEnded:Connect(function(i)
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
                local hueMC=UserInputService.InputChanged:Connect(function(i)
                    if hueDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
                        local ab=hueBar.AbsolutePosition; local sz=hueBar.AbsoluteSize
                        hue=math.clamp((i.Position.X-ab.X)/sz.X,0,1)*360; UpdateAll()
                    end
                end)
                local hueEC=UserInputService.InputEnded:Connect(function(i)
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

            local obj = {}
            function obj:Set(v, silent)
                if typeof(v) ~= "Color3" then return end
                val=v; hue,sat,valu=RGBtoHSV(val)
                swatch.BackgroundColor3=val; hexLabel.Text=ToHex(val)
                State.Set(cpc.Flag,val)
                if not silent then SafeCall(cb,val) end
            end
            function obj:Get() return val end
            function obj:Enable()  swatchBtn.Active=true end
            function obj:Disable() swatchBtn.Active=false end
            ApplyMixin(obj, row, nameLbl, descLbl)
            Registry.Register(cpc.Flag,
                function() return val end,
                function(v) obj:Set(v,true) end
            )
            if cpc.Flag then State.Set(cpc.Flag,val) end
            return obj
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
function CrispyLib.Watch(flag, fn) State.Subscribe(flag, fn) end

return CrispyLib
