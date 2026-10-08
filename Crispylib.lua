--[[
    CrispyLib 3.4.0
    Responsive desktop/touch UI, owned input, and extensible config/storage API.
    Single-file Roblox/Luau UI library for executor environments.

    Compatibility goals:
      * loadstring(source)() returns the public CrispyLib table.
      * Both CrispyLib.CreateWindow(config) and CrispyLib:CreateWindow(config) work.
      * Existing v2 window, tab, component, config, notification, HTTP, system,
        debug, theme, task, and state APIs remain available unless documented.

    The implementation is intentionally kept in one source file for executor
    compatibility, but its internals are separated into small subsystems.
]]

local VERSION = "3.4.0"

local function getService(name)
    local ok, service = pcall(function()
        return game:GetService(name)
    end)
    if not ok or service == nil then
        error("[CrispyLib] Required Roblox service is unavailable: " .. tostring(name), 2)
    end
    return service
end

local Players = getService("Players")
local TweenService = getService("TweenService")
local UserInputService = getService("UserInputService")
local HttpService = getService("HttpService")
local RunService = getService("RunService")
local CoreGui = getService("CoreGui")
local Lighting = getService("Lighting")
local Stats = getService("Stats")
local Workspace = getService("Workspace")

local LocalPlayer = Players.LocalPlayer
if LocalPlayer == nil then
    error("[CrispyLib] Players.LocalPlayer is unavailable", 2)
end

local unpackValues = table.unpack or unpack
local robloxType = typeof or type

local LIMITS = {
    MaxTaskItems = 4096,
    MaxListeners = 2048,
    MaxWindows = 16,
    MaxTabsPerWindow = 64,
    MaxComponentsPerTab = 2048,
    MaxHistoryEntries = 64,
    MaxOptions = 10000,
    MaxDropdownRender = 500,
    MaxRows = 10000,
    MaxTableColumns = 32,
    MaxLogLines = 2000,
    MaxCodeCharacters = 500000,
    MaxCodeLines = 20000,
    MaxNotificationsQueued = 50,
    MaxSerializationNodes = 20000,
    MaxSerializationDepth = 32,
    MaxMigrationSteps = 128,
    MaxHttpBodyBytes = 4 * 1024 * 1024,
}

local DEFAULTS = {
    WindowWidth = 820,
    WindowHeight = 520,
    MinWindowWidth = 640,
    MinWindowHeight = 380,
    SidebarWidth = 188,
    TitleBarHeight = 58,
    WindowCornerRadius = 20,
    SurfaceCornerRadius = 19,
    RowHeight = 70,
    NotificationLimit = 5,
}

local Z_INDEX = {
    Window = 1,
    Content = 10,
    Sidebar = 20,
    TitleBar = 30,
    Popup = 200,
    Notification = 500,
    Modal = 700,
}

local TWEEN = {
    Instant = TweenInfo.new(0),
    Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Medium = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Slow = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Ease = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function isFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function numberOr(value, fallback)
    local parsed = tonumber(value)
    if not isFiniteNumber(parsed) then
        return fallback
    end
    return parsed
end

local function shallowCopy(source, maximum)
    local result = {}
    if type(source) ~= "table" then
        return result
    end
    local processed = 0
    for key, value in pairs(source) do
        processed = processed + 1
        if processed > (maximum or LIMITS.MaxSerializationNodes) then
            break
        end
        result[key] = value
    end
    return result
end

local function arrayCopy(source, maximum)
    local result = {}
    if type(source) ~= "table" then
        return result
    end
    local count = math.min(#source, maximum or LIMITS.MaxRows)
    for index = 1, count do
        result[index] = source[index]
    end
    return result
end

local function removeArrayValue(array, value, maximum)
    local count = math.min(#array, maximum or LIMITS.MaxRows)
    for index = count, 1, -1 do
        if array[index] == value then
            table.remove(array, index)
            return true
        end
    end
    return false
end

local function scalarValuesEqual(left, right)
    if left == right then
        return true
    end
    if robloxType(left) == "Color3" and robloxType(right) == "Color3" then
        return left.R == right.R and left.G == right.G and left.B == right.B
    end
    return false
end

local function countTableEntries(value)
    local count = 0
    for _ in pairs(value) do
        count = count + 1
        if count > LIMITS.MaxSerializationNodes then
            return nil
        end
    end
    return count
end

local function queueComparableValues(leftValue, rightValue, queues, seen)
    if scalarValuesEqual(leftValue, rightValue) then
        return true
    end
    if type(leftValue) ~= "table" or type(rightValue) ~= "table" then
        return false
    end
    local mappedRight = seen.Left[leftValue]
    local mappedLeft = seen.Right[rightValue]
    if (mappedRight ~= nil and mappedRight ~= rightValue)
        or (mappedLeft ~= nil and mappedLeft ~= leftValue) then
        return false
    end
    if mappedRight == nil then
        seen.Left[leftValue] = rightValue
        seen.Right[rightValue] = leftValue
        queues.Left[#queues.Left + 1] = leftValue
        queues.Right[#queues.Right + 1] = rightValue
    end
    return true
end

local function valuesEqual(left, right)
    if scalarValuesEqual(left, right) then
        return true
    end
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    local queues = { Left = { left }, Right = { right } }
    local seen = { Left = { [left] = right }, Right = { [right] = left } }
    local comparedNodes = 0

    for queueIndex = 1, LIMITS.MaxSerializationNodes do
        local leftTable = queues.Left[queueIndex]
        local rightTable = queues.Right[queueIndex]
        if leftTable == nil then
            return true
        end

        local leftCount = 0
        for key, leftValue in pairs(leftTable) do
            leftCount = leftCount + 1
            comparedNodes = comparedNodes + 1
            if leftCount > LIMITS.MaxSerializationNodes or comparedNodes > LIMITS.MaxSerializationNodes then
                return false
            end

            local rightValue = rightTable[key]
            if rightValue == nil then
                return false
            end
            if not queueComparableValues(leftValue, rightValue, queues, seen) then
                return false
            end
        end

        local rightCount = countTableEntries(rightTable)
        if leftCount ~= rightCount then
            return false
        end
    end
    return false
end

local function normalizeText(value, fallback)
    if value == nil then
        return fallback or ""
    end
    return tostring(value)
end

local function isKeyCode(value)
    return robloxType(value) == "EnumItem" and value.EnumType == Enum.KeyCode
end

local function normalizeConfig(first, second, owner)
    if first == owner then
        return type(second) == "table" and second or {}
    end
    return type(first) == "table" and first or {}
end

local function normalizeMethodArgument(first, second, owner)
    if first == owner then
        return second
    end
    return first
end

-- Preserve false/nil values when normalizing dot and colon calls.
local function methodArguments(owner, first, ...)
    if first == owner then return ... end
    return first, ...
end

local function getGlobalEnvironment()
    local getter
    local ok = pcall(function()
        getter = getgenv
    end)
    if ok and type(getter) == "function" then
        local envOk, environment = pcall(getter)
        if envOk and type(environment) == "table" then
            return environment, true
        end
    end
    return _G, false
end

local GLOBAL_ENVIRONMENT, HAS_GETGENV = getGlobalEnvironment()

local function getGlobal(name)
    local value
    if type(GLOBAL_ENVIRONMENT) == "table" then
        value = rawget(GLOBAL_ENVIRONMENT, name)
    end
    if value == nil and type(_G) == "table" then
        value = rawget(_G, name)
    end
    return value
end

local ErrorBoundary = {
    _handlers = {},
    _reporting = false,
}

local function dispatchSnapshot(snapshot, invoke, ...)
    for _, subscription in ipairs(snapshot) do
        if subscription.Active then
            invoke(subscription.Callback, ...)
        end
    end
end

local function clearSubscriptions(list)
    for _, subscription in ipairs(list) do subscription.Active = false end
    table.clear(list)
end

local function reportError(message)
    local formatted = "[CrispyLib] " .. tostring(message)
    warn(formatted)

    -- A handler may itself call an API that reports an error. Guard that
    -- feedback while starting callbacks, and isolate yielded handlers from the
    -- reporting caller so its cancellation cannot strand this shared guard.
    if ErrorBoundary._reporting then return end
    ErrorBoundary._reporting = true
    local function invokeHandler(callback, value)
        task.spawn(pcall, callback, value)
    end
    dispatchSnapshot(table.clone(ErrorBoundary._handlers), invokeHandler, message)
    ErrorBoundary._reporting = false
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, "callback must be a function"
    end

    local arguments = table.pack(...)
    local results = table.pack(pcall(function()
        return callback(unpackValues(arguments, 1, arguments.n))
    end))
    if not results[1] then
        reportError(results[2])
    end
    return unpackValues(results, 1, results.n)
end

local function subscribe(list, callback, maximum)
    if type(callback) ~= "function" then
        return function() end
    end
    if #list >= (maximum or LIMITS.MaxListeners) then
        reportError("listener limit reached")
        return function() end
    end

    local subscription = { Callback = callback, Active = true }
    list[#list + 1] = subscription
    return function()
        if not subscription.Active then return end
        subscription.Active = false
        removeArrayValue(list, subscription, maximum or LIMITS.MaxListeners)
    end
end

local Runtime = {}

function Runtime.GetRequestFunction()
    local direct = getGlobal("request")
    if type(direct) == "function" then
        return direct
    end

    local synapse = getGlobal("syn")
    if type(synapse) == "table" and type(synapse.request) == "function" then
        return synapse.request
    end

    local aliases = { "http_request", "httprequest" }
    for index = 1, #aliases do
        local candidate = getGlobal(aliases[index])
        if type(candidate) == "function" then
            return candidate
        end
    end

    local httpGlobal = getGlobal("http")
    if type(httpGlobal) == "table" and type(httpGlobal.request) == "function" then
        return httpGlobal.request
    end
    return nil
end

function Runtime.GetFileFunction(name)
    local candidate = getGlobal(name)
    if type(candidate) == "function" then
        return candidate
    end
    return nil
end

function Runtime.ProtectGui(screenGui)
    local protect = getGlobal("protect_gui") or getGlobal("protectgui")
    local synapse = getGlobal("syn")
    if type(protect) ~= "function" and type(synapse) == "table" then
        protect = synapse.protect_gui
    end
    if type(protect) == "function" then
        pcall(protect, screenGui)
    end
end

function Runtime.GetGuiParent()
    local getHiddenUi = getGlobal("gethui") or getGlobal("get_hidden_gui")
    if type(getHiddenUi) == "function" then
        local ok, parent = pcall(getHiddenUi)
        if ok and robloxType(parent) == "Instance" then
            return parent
        end
    end

    if CoreGui ~= nil then
        return CoreGui
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui == nil then
        local ok, result = pcall(function()
            return LocalPlayer:WaitForChild("PlayerGui", 5)
        end)
        if ok then
            playerGui = result
        end
    end
    return playerGui
end

function Runtime.ParentScreenGui(screenGui)
    if robloxType(screenGui) ~= "Instance" then
        return false, "screenGui must be an Instance"
    end

    Runtime.ProtectGui(screenGui)
    local parent = Runtime.GetGuiParent()
    if parent == nil then
        return false, "no supported GUI parent is available"
    end

    local ok, err = pcall(function()
        screenGui.Parent = parent
    end)
    if not ok or screenGui.Parent == nil then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui ~= nil then
            ok, err = pcall(function()
                screenGui.Parent = playerGui
            end)
        end
    end
    return ok, err
end

function Runtime.Capabilities()
    return {
        request = Runtime.GetRequestFunction() ~= nil,
        writefile = Runtime.GetFileFunction("writefile") ~= nil,
        readfile = Runtime.GetFileFunction("readfile") ~= nil,
        listfiles = Runtime.GetFileFunction("listfiles") ~= nil,
        isfile = Runtime.GetFileFunction("isfile") ~= nil,
        isfolder = Runtime.GetFileFunction("isfolder") ~= nil,
        makefolder = Runtime.GetFileFunction("makefolder") ~= nil,
        delfile = Runtime.GetFileFunction("delfile") ~= nil,
        loadstring = type(getGlobal("loadstring")) == "function",
        getgenv = HAS_GETGENV or type(getGlobal("getgenv")) == "function",
        drawing = getGlobal("Drawing") ~= nil,
        setclipboard = type(getGlobal("setclipboard")) == "function",
        hookfunction = type(getGlobal("hookfunction")) == "function",
        gethui = type(getGlobal("gethui")) == "function",
    }
end

local function cleanupOne(item)
    if item == nil then return end
    local itemType = robloxType(item)
    if itemType == "RBXScriptConnection" then
        if item.Connected then safeCall(item.Disconnect, item) end
    elseif itemType == "Instance" then
        -- Unparenting an Instance does not destroy its resources.
        safeCall(item.Destroy, item)
    elseif type(item) == "function" then
        safeCall(item)
    elseif type(item) == "table" then
        for _, name in ipairs({ "Destroy", "Disconnect", "Cancel", "Cleanup" }) do
            if type(item[name]) == "function" then
                safeCall(item[name], item)
                break
            end
        end
    end
end

local function cleanupEntry(entry)
    if type(entry.Cleanup) == "function" then
        safeCall(entry.Cleanup, entry.Item)
    else
        cleanupOne(entry.Item)
    end
end

local function cancelTaskToken(token)
    token.Alive = false
    local connection = token.Connection
    if connection and connection.Connected then safeCall(connection.Disconnect, connection) end
    local thread = token.Thread
    -- A callback may destroy its own owner (for example Loader:Finish).
    -- Let that current callback finish; cancel tasks suspended in other threads.
    if thread ~= nil and thread ~= coroutine.running() and type(task.cancel) == "function" then
        pcall(task.cancel, thread)
    end
end

local TaskGroup = {}
TaskGroup.__index = TaskGroup

function TaskGroup.new(name)
    return setmetatable({ Name = normalizeText(name, "TaskGroup"), _alive = true, _items = {} }, TaskGroup)
end

function TaskGroup:IsAlive()
    return self._alive
end

function TaskGroup:Add(item, cleanup)
    if item == nil then return nil, false end
    local entry = { Item = item, Cleanup = cleanup }
    if not self._alive or #self._items >= LIMITS.MaxTaskItems then
        if self._alive then reportError(self.Name .. " reached its task limit") end
        cleanupEntry(entry)
        return item, false
    end
    self._items[#self._items + 1] = entry
    return item, true
end

function TaskGroup:_take(item)
    for index = #self._items, 1, -1 do
        if self._items[index].Item == item then
            return table.remove(self._items, index)
        end
    end
    return nil
end

function TaskGroup:_forget(item)
    return self:_take(item) ~= nil
end

function TaskGroup:Connect(signal, callback)
    if not self._alive or signal == nil or type(callback) ~= "function" then return nil end
    local ok, connection = pcall(function() return signal:Connect(callback) end)
    if not ok then reportError(connection); return nil end
    local _, accepted = self:Add(connection)
    return accepted and connection or nil
end

function TaskGroup:Wrap(callback, options)
    options = type(options) == "table" and options or {}
    local debounceSeconds = math.max(numberOr(options.Debounce, 0), 0)
    local once = options.Once == true
    local called, running, lastCall = false, false, -math.huge
    return function(...)
        if not self._alive or type(callback) ~= "function" or (once and called) then return nil end
        local now = os.clock()
        if running or now - lastCall < debounceSeconds then return nil end
        local token = { Alive = true, Thread = coroutine.running() }
        local _, accepted = self:Add(token, function(value)
            if value.Thread ~= coroutine.running() then running = false end
            cancelTaskToken(value)
        end)
        if not accepted then return nil end
        running, called, lastCall = true, true, now
        local results = table.pack(safeCall(callback, ...))
        token.Alive = false
        self:_forget(token)
        running = false
        return unpackValues(results, 1, results.n)
    end
end

function TaskGroup:_start(callback, arguments, seconds)
    if not self._alive or type(callback) ~= "function" then return nil end
    local token = { Alive = true, Thread = nil }
    local _, accepted = self:Add(token, cancelTaskToken)
    if not accepted then return nil end
    local function run()
        token.Thread = coroutine.running()
        if token.Alive and self._alive then
            safeCall(callback, unpackValues(arguments, 1, arguments.n))
        end
        token.Alive = false
        self:_forget(token)
    end
    local ok, thread
    if seconds == nil then
        ok, thread = pcall(task.spawn, run)
    else
        ok, thread = pcall(task.delay, math.max(numberOr(seconds, 0), 0), run)
    end
    if not ok then
        self:Cancel(token)
        reportError(thread)
        return nil
    end
    token.Thread = thread
    return token
end

function TaskGroup:Spawn(callback, ...)
    return self:_start(callback, table.pack(...), nil)
end

function TaskGroup:Delay(seconds, callback, ...)
    return self:_start(callback, table.pack(...), math.max(numberOr(seconds, 0), 0))
end

function TaskGroup:Loop(interval, callback)
    if not self._alive or type(callback) ~= "function" then return nil end
    local period = math.max(numberOr(interval, 0), 0)
    local token = { Alive = true, Connection = nil, Thread = nil }
    local _, accepted = self:Add(token, cancelTaskToken)
    if not accepted then return nil end
    local elapsed = period
    local ok, connection = pcall(function()
        return RunService.Heartbeat:Connect(function(deltaTime)
            if not self._alive or not token.Alive then self:Cancel(token); return end
            elapsed = elapsed + deltaTime
            if period ~= 0 and elapsed < period then return end
            elapsed = period == 0 and 0 or (elapsed % period)
            -- A yielded callback remains owned and cannot overlap the next tick.
            if token.Thread ~= nil then return end
            token.Thread = coroutine.running()
            safeCall(callback, token, deltaTime)
            token.Thread = nil
            if not token.Alive or not self._alive then self:Cancel(token) end
        end)
    end)
    if not ok then self:Cancel(token); reportError(connection); return nil end
    token.Connection = connection
    return token
end

function TaskGroup:Cancel(item)
    -- Detach before invoking cleanup so recursive cancellation is harmless.
    local entry = self:_take(item)
    if entry == nil then return false end
    cleanupEntry(entry)
    return true
end

function TaskGroup:Cleanup()
    local items = self._items
    self._items = {}
    for index = #items, 1, -1 do
        local entry = items[index]
        items[index] = nil
        cleanupEntry(entry)
    end
end

function TaskGroup:Destroy()
    if not self._alive then return end
    self._alive = false
    local onDestroy = self._onDestroy
    self._onDestroy = nil
    self:Cleanup()
    if type(onDestroy) == "function" then safeCall(onDestroy, self) end
end

local CrispyLib = {
    Version = VERSION,
    Limits = LIMITS,
    Runtime = Runtime,
    _windows = {},
    _loaders = {},
    _taskGroups = {},
    _configName = "CrispyLib",
}

function CrispyLib.CreateTaskGroup(first, second)
    local name = normalizeMethodArgument(first, second, CrispyLib)
    local group = TaskGroup.new(name)
    if #CrispyLib._taskGroups < LIMITS.MaxTaskItems then
        CrispyLib._taskGroups[#CrispyLib._taskGroups + 1] = group
        group._onDestroy = function(value)
            removeArrayValue(CrispyLib._taskGroups, value, LIMITS.MaxTaskItems)
        end
    else
        group:Destroy()
        reportError("global task-group limit reached")
    end
    return group
end

CrispyLib.Tasks = CrispyLib.CreateTaskGroup("CrispyLib")

function CrispyLib.WrapTask(first, second, third)
    local callback, options = methodArguments(CrispyLib, first, second, third)
    return CrispyLib.Tasks:Wrap(callback, options)
end

function CrispyLib.Spawn(first, ...)
    local callback = first == CrispyLib and select(1, ...) or first
    if first == CrispyLib then
        return CrispyLib.Tasks:Spawn(callback, select(2, ...))
    end
    return CrispyLib.Tasks:Spawn(callback, ...)
end

function CrispyLib.Delay(first, second, ...)
    if first == CrispyLib then
        return CrispyLib.Tasks:Delay(second, select(1, ...), select(2, ...))
    end
    return CrispyLib.Tasks:Delay(first, second, ...)
end

function CrispyLib.Loop(first, second, third)
    local interval, callback = methodArguments(CrispyLib, first, second, third)
    return CrispyLib.Tasks:Loop(interval, callback)
end

function CrispyLib.OnError(first, second)
    local callback = normalizeMethodArgument(first, second, CrispyLib)
    return subscribe(ErrorBoundary._handlers, callback, LIMITS.MaxListeners)
end

local DEFAULT_THEME = {
    WindowBg = Color3.fromRGB(18, 35, 62),
    SidebarBg = Color3.fromRGB(22, 40, 68),
    ContentBg = Color3.fromRGB(17, 33, 58),
    TitleBarBg = Color3.fromRGB(30, 50, 82),
    RowBg = Color3.fromRGB(31, 52, 86),
    RowHover = Color3.fromRGB(41, 68, 108),
    PopupBg = Color3.fromRGB(23, 42, 70),
    InputBg = Color3.fromRGB(27, 47, 78),
    DisabledBg = Color3.fromRGB(37, 50, 72),
    DisabledText = Color3.fromRGB(95, 111, 138),

    TitleText = Color3.fromRGB(241, 246, 255),
    SubtitleText = Color3.fromRGB(139, 157, 188),
    LabelText = Color3.fromRGB(229, 237, 251),
    DescText = Color3.fromRGB(120, 140, 171),
    ValueText = Color3.fromRGB(174, 193, 221),
    SectionLabel = Color3.fromRGB(148, 125, 255),
    Placeholder = Color3.fromRGB(96, 115, 145),

    TabHover = Color3.fromRGB(43, 75, 119),
    TabInactive = Color3.fromRGB(151, 171, 202),
    TabActiveText = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(113, 92, 255),
    AccentHover = Color3.fromRGB(80, 190, 255),
    AccentPress = Color3.fromRGB(83, 67, 211),

    ToggleOff = Color3.fromRGB(69, 88, 119),
    ToggleKnob = Color3.fromRGB(255, 255, 255),
    Separator = Color3.fromRGB(65, 88, 122),
    Border = Color3.fromRGB(91, 120, 164),
    FocusBorder = Color3.fromRGB(115, 211, 255),
    ItemHover = Color3.fromRGB(46, 75, 115),
    ScrollThumb = Color3.fromRGB(110, 139, 184),

    CloseButton = Color3.fromRGB(255, 112, 133),
    MinimizeButton = Color3.fromRGB(255, 199, 100),
    MaximizeButton = Color3.fromRGB(91, 226, 163),

    NotificationBg = Color3.fromRGB(13, 24, 43),
    NotificationInfo = Color3.fromRGB(78, 184, 255),
    NotificationSuccess = Color3.fromRGB(73, 218, 154),
    NotificationWarning = Color3.fromRGB(255, 190, 92),
    NotificationError = Color3.fromRGB(255, 102, 128),

    LoaderBg = Color3.fromRGB(5, 11, 23),
    LoaderTrack = Color3.fromRGB(31, 44, 68),
    LoaderFill = Color3.fromRGB(113, 92, 255),

    DangerBg = Color3.fromRGB(64, 24, 43),
    DangerHover = Color3.fromRGB(91, 31, 56),
    DangerText = Color3.fromRGB(255, 129, 150),
    SuccessBg = Color3.fromRGB(15, 61, 49),
    WarningBg = Color3.fromRGB(68, 48, 15),
    ErrorBg = Color3.fromRGB(72, 24, 42),
    InfoBg = Color3.fromRGB(18, 48, 85),
    CodeBg = Color3.fromRGB(7, 14, 28),

    WindowGradientStart = Color3.fromRGB(32, 53, 86),
    WindowGradientEnd = Color3.fromRGB(14, 29, 52),
    PanelGradientStart = Color3.fromRGB(41, 67, 105),
    PanelGradientEnd = Color3.fromRGB(23, 42, 70),
    SurfaceGradientStart = Color3.fromRGB(44, 70, 109),
    SurfaceGradientEnd = Color3.fromRGB(26, 47, 78),
    AccentGradientStart = Color3.fromRGB(132, 93, 255),
    AccentGradientEnd = Color3.fromRGB(45, 205, 255),
    GlassHighlight = Color3.fromRGB(190, 222, 255),

    WindowTransparency = 0,
    TitleBarTransparency = 0.02,
    PanelTransparency = 0.02,
    ContentTransparency = 0,
    RowTransparency = 0.02,
    InputTransparency = 0.02,
    PopupTransparency = 0.01,
    StrokeTransparency = 0.38,
}

-- Legacy theme aliases are real entries so direct reads remain compatible.
DEFAULT_THEME.PlaceholderC = DEFAULT_THEME.Placeholder
DEFAULT_THEME.DropdownBg = DEFAULT_THEME.PopupBg
DEFAULT_THEME.CloseBtn = DEFAULT_THEME.CloseButton
DEFAULT_THEME.MinBtn = DEFAULT_THEME.MinimizeButton
DEFAULT_THEME.MaxBtn = DEFAULT_THEME.MaximizeButton
DEFAULT_THEME.NotifBg = DEFAULT_THEME.NotificationBg
DEFAULT_THEME.NotifInfo = DEFAULT_THEME.NotificationInfo
DEFAULT_THEME.NotifSuccess = DEFAULT_THEME.NotificationSuccess
DEFAULT_THEME.NotifWarn = DEFAULT_THEME.NotificationWarning
DEFAULT_THEME.NotifError = DEFAULT_THEME.NotificationError
DEFAULT_THEME.LoaderBarBg = DEFAULT_THEME.LoaderTrack
DEFAULT_THEME.LoaderBar = DEFAULT_THEME.LoaderFill

local ThemeManager = {
    Values = shallowCopy(DEFAULT_THEME),
    Presets = {},
    _bindings = setmetatable({}, { __mode = "k" }),
    _watchers = {},
    _animation = nil,
}

local function resolveThemeValue(specification)
    if type(specification) == "string" and ThemeManager.Values[specification] ~= nil then
        return ThemeManager.Values[specification]
    end
    if type(specification) == "table" and type(specification.Theme) == "string" then
        return ThemeManager.Values[specification.Theme]
    end
    if type(specification) == "function" then
        local ok, value = safeCall(specification, ThemeManager.Values)
        if ok then
            return value
        end
        return nil
    end
    return specification
end

function ThemeManager.ApplyBinding(instance, bindings)
    if robloxType(instance) ~= "Instance" or type(bindings) ~= "table" then
        return false
    end

    local processed = 0
    for property, specification in pairs(bindings) do
        processed = processed + 1
        if processed > 128 then
            reportError("theme binding property limit reached")
            break
        end
        local value = resolveThemeValue(specification)
        local ok, err = pcall(function()
            instance[property] = value
        end)
        if not ok then
            reportError("cannot theme " .. instance.ClassName .. "." .. tostring(property) .. ": " .. tostring(err))
        end
    end
    return true
end

function ThemeManager.Bind(instance, bindings)
    if robloxType(instance) ~= "Instance" or type(bindings) ~= "table" then
        return instance
    end
    local merged = shallowCopy(ThemeManager._bindings[instance] or {}, 128)
    local processed = 0
    for property, specification in pairs(bindings) do
        processed = processed + 1
        if processed > 128 then
            reportError("theme binding property limit reached")
            break
        end
        merged[property] = specification
    end
    if ThemeManager.ApplyBinding(instance, merged) then
        ThemeManager._bindings[instance] = merged
    end
    return instance
end

function ThemeManager.Unbind(instance)
    ThemeManager._bindings[instance] = nil
end

function ThemeManager.Refresh()
    local processed = 0
    for instance, bindings in pairs(ThemeManager._bindings) do
        processed = processed + 1
        if processed > LIMITS.MaxSerializationNodes then
            reportError("theme binding refresh limit reached")
            break
        end
        if robloxType(instance) == "Instance" and instance.Parent ~= nil then
            ThemeManager.ApplyBinding(instance, bindings)
        else
            ThemeManager._bindings[instance] = nil
        end
    end
end

function ThemeManager.NotifyWatchers()
    dispatchSnapshot(table.clone(ThemeManager._watchers), safeCall, ThemeManager.Values)
end

function ThemeManager.ExpandPatch(patch)
    local expanded = shallowCopy(patch, 256)
    local white = Color3.new(1, 1, 1)
    local black = Color3.new(0, 0, 0)

    if robloxType(patch.Accent) == "Color3" then
        expanded.AccentGradientStart = patch.AccentGradientStart or patch.Accent:Lerp(white, 0.1)
        expanded.AccentGradientEnd = patch.AccentGradientEnd or patch.AccentHover or patch.Accent:Lerp(white, 0.22)
    end
    if robloxType(patch.WindowBg) == "Color3" then
        expanded.WindowGradientStart = patch.WindowGradientStart or patch.WindowBg:Lerp(white, 0.1)
        expanded.WindowGradientEnd = patch.WindowGradientEnd or patch.WindowBg:Lerp(black, 0.16)
    end
    if robloxType(patch.RowBg) == "Color3" then
        expanded.SurfaceGradientStart = patch.SurfaceGradientStart or patch.RowBg:Lerp(white, 0.11)
        expanded.SurfaceGradientEnd = patch.SurfaceGradientEnd or patch.RowBg:Lerp(black, 0.13)
    end

    local panelBase = patch.InputBg or patch.TitleBarBg or patch.SidebarBg
    if robloxType(panelBase) == "Color3" then
        expanded.PanelGradientStart = patch.PanelGradientStart or panelBase:Lerp(white, 0.12)
        expanded.PanelGradientEnd = patch.PanelGradientEnd or panelBase:Lerp(black, 0.12)
    end
    return expanded
end

function ThemeManager.IsPatchSizeValid(patch)
    local count = 0
    for _ in pairs(patch) do
        count = count + 1
        if count > 256 then return false end
    end
    return true
end

function ThemeManager.Set(patch, notify)
    if type(patch) ~= "table" then
        return false, "theme patch must be a table"
    end
    if not ThemeManager.IsPatchSizeValid(patch) then
        return false, "theme patch is too large"
    end

    patch = ThemeManager.ExpandPatch(patch)
    local validated = {}
    local processed = 0
    for key, value in pairs(patch) do
        processed = processed + 1
        if processed > 272 then
            return false, "theme patch is too large"
        end
        local current = ThemeManager.Values[key]
        if current == nil or robloxType(current) == robloxType(value) then
            validated[key] = value
        else
            return false, "theme value type mismatch for " .. tostring(key)
        end
    end

    for key, value in pairs(validated) do
        ThemeManager.Values[key] = value
    end

    local aliases = {
        Placeholder = "PlaceholderC",
        PopupBg = "DropdownBg",
        CloseButton = "CloseBtn",
        MinimizeButton = "MinBtn",
        MaximizeButton = "MaxBtn",
        NotificationBg = "NotifBg",
        NotificationInfo = "NotifInfo",
        NotificationSuccess = "NotifSuccess",
        NotificationWarning = "NotifWarn",
        NotificationError = "NotifError",
        LoaderTrack = "LoaderBarBg",
        LoaderFill = "LoaderBar",
    }
    for canonical, legacy in pairs(aliases) do
        if patch[canonical] ~= nil then
            ThemeManager.Values[legacy] = ThemeManager.Values[canonical]
        elseif patch[legacy] ~= nil then
            ThemeManager.Values[canonical] = ThemeManager.Values[legacy]
        end
    end

    ThemeManager.Refresh()
    if notify ~= false then
        ThemeManager.NotifyWatchers()
    end
    return true
end

function ThemeManager.Animate(target, duration)
    if type(target) ~= "table" then
        return false, "target theme must be a table"
    end
    if ThemeManager._animation ~= nil then
        CrispyLib.Tasks:Cancel(ThemeManager._animation)
        ThemeManager._animation = nil
    end

    local seconds = clamp(numberOr(duration, 0.4), 0.05, 5)
    local initial = shallowCopy(ThemeManager.Values, 256)
    local elapsed = 0
    local token
    token = CrispyLib.Tasks:Loop(0, function(loopToken, deltaTime)
        elapsed = elapsed + deltaTime
        local alpha = clamp(elapsed / seconds, 0, 1)
        local eased = 1 - ((1 - alpha) ^ 3)
        local patch = {}
        local count = 0
        for key, targetValue in pairs(target) do
            count = count + 1
            if count > 256 then
                break
            end
            local fromValue = initial[key]
            if robloxType(fromValue) == "Color3" and robloxType(targetValue) == "Color3" then
                patch[key] = fromValue:Lerp(targetValue, eased)
            elseif alpha >= 1 then
                patch[key] = targetValue
            end
        end
        ThemeManager.Set(patch, false)
        if alpha >= 1 then
            loopToken.Alive = false
            ThemeManager._animation = nil
            ThemeManager.Set(target, true)
        end
    end)
    ThemeManager._animation = token
    return true
end

local function makeThemePreset(patch)
    local preset = shallowCopy(DEFAULT_THEME, 256)
    local processed = 0
    for key, value in pairs(patch) do
        processed = processed + 1
        if processed > 256 then
            break
        end
        preset[key] = value
    end
    return preset
end

ThemeManager.Presets.Default = makeThemePreset({})
ThemeManager.Presets.Guardian = makeThemePreset({})
ThemeManager.Presets.Midnight = makeThemePreset({
    WindowBg = Color3.fromRGB(15, 18, 28),
    SidebarBg = Color3.fromRGB(12, 14, 22),
    ContentBg = Color3.fromRGB(14, 17, 26),
    TitleBarBg = Color3.fromRGB(13, 16, 24),
    RowBg = Color3.fromRGB(22, 26, 38),
    RowHover = Color3.fromRGB(32, 38, 56),
    Accent = Color3.fromRGB(124, 92, 255),
    AccentHover = Color3.fromRGB(146, 122, 255),
    AccentPress = Color3.fromRGB(96, 66, 230),
    WindowGradientStart = Color3.fromRGB(25, 25, 57),
    WindowGradientEnd = Color3.fromRGB(8, 10, 27),
    AccentGradientStart = Color3.fromRGB(150, 89, 255),
    AccentGradientEnd = Color3.fromRGB(92, 110, 255),
})
ThemeManager.Presets.Glass = makeThemePreset({
    WindowBg = Color3.fromRGB(28, 31, 38),
    SidebarBg = Color3.fromRGB(21, 24, 32),
    ContentBg = Color3.fromRGB(24, 27, 35),
    RowBg = Color3.fromRGB(38, 42, 52),
    Border = Color3.fromRGB(72, 78, 92),
    Accent = Color3.fromRGB(69, 176, 255),
    WindowGradientStart = Color3.fromRGB(48, 61, 82),
    WindowGradientEnd = Color3.fromRGB(20, 29, 43),
    AccentGradientStart = Color3.fromRGB(75, 184, 255),
    AccentGradientEnd = Color3.fromRGB(84, 231, 209),
    WindowTransparency = 0.1,
    PanelTransparency = 0.24,
    RowTransparency = 0.22,
})
ThemeManager.Presets.HighContrast = makeThemePreset({
    WindowBg = Color3.fromRGB(8, 8, 10),
    SidebarBg = Color3.fromRGB(0, 0, 0),
    ContentBg = Color3.fromRGB(10, 10, 12),
    RowBg = Color3.fromRGB(24, 24, 28),
    TitleText = Color3.fromRGB(255, 255, 255),
    LabelText = Color3.fromRGB(245, 245, 248),
    Accent = Color3.fromRGB(0, 170, 255),
    Border = Color3.fromRGB(110, 110, 125),
    WindowGradientStart = Color3.fromRGB(14, 14, 18),
    WindowGradientEnd = Color3.fromRGB(0, 0, 0),
    AccentGradientStart = Color3.fromRGB(0, 170, 255),
    AccentGradientEnd = Color3.fromRGB(0, 235, 255),
    WindowTransparency = 0,
    PanelTransparency = 0,
    RowTransparency = 0,
    InputTransparency = 0,
    StrokeTransparency = 0.2,
})

CrispyLib.Theme = ThemeManager.Values
CrispyLib.ThemePresets = ThemeManager.Presets
CrispyLib.DensityPresets = {
    Compact = { WindowWidth = 740, WindowHeight = 460, RowHeight = 60 },
    Normal = { WindowWidth = 820, WindowHeight = 520, RowHeight = 70 },
    Spacious = { WindowWidth = 880, WindowHeight = 570, RowHeight = 78 },
}

function CrispyLib.GetTheme()
    return shallowCopy(ThemeManager.Values, 256)
end

function CrispyLib.SetTheme(first, second)
    local patch = normalizeMethodArgument(first, second, CrispyLib)
    return ThemeManager.Set(patch)
end

function CrispyLib.RegisterThemePreset(first, second, third)
    local name, preset = methodArguments(CrispyLib, first, second, third)
    if type(name) ~= "string" or name == "" or type(preset) ~= "table" then
        return false
    end
    ThemeManager.Presets[name] = makeThemePreset(preset)
    return true
end

function CrispyLib.SetThemePreset(first, second)
    local name = normalizeMethodArgument(first, second, CrispyLib)
    local preset = ThemeManager.Presets[name]
    if type(preset) ~= "table" then
        return false
    end
    return ThemeManager.Set(shallowCopy(preset, 256))
end

function CrispyLib.ListThemePresets()
    local names = {}
    local count = 0
    for name in pairs(ThemeManager.Presets) do
        count = count + 1
        if count > 256 then
            break
        end
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function CrispyLib.OnThemeChanged(first, second)
    local callback = normalizeMethodArgument(first, second, CrispyLib)
    return subscribe(ThemeManager._watchers, callback, LIMITS.MaxListeners)
end

function CrispyLib.AnimateThemeTransition(first, second, third)
    local requested, duration = methodArguments(CrispyLib, first, second, third)
    local target = type(requested) == "string" and ThemeManager.Presets[requested] or requested
    return ThemeManager.Animate(target, duration)
end

function CrispyLib.SetThemeValue(first, second, third)
    local key, value = methodArguments(CrispyLib, first, second, third)
    if type(key) ~= "string" or key == "" then
        return false, "theme key must be a non-empty string"
    end
    return ThemeManager.Set({ [key] = value })
end

function CrispyLib.SetThemePresetValue(first, second, third, fourth)
    local name, key, value = methodArguments(CrispyLib, first, second, third, fourth)
    local preset = ThemeManager.Presets[name]
    if type(preset) ~= "table" or type(key) ~= "string" or key == "" then
        return false
    end
    preset[key] = value
    return true
end

function CrispyLib.SetDensity(first, second)
    local requested = normalizeMethodArgument(first, second, CrispyLib)
    local density = type(requested) == "table" and requested or CrispyLib.DensityPresets[requested or "Normal"]
    if type(density) ~= "table" then
        return false
    end
    DEFAULTS.WindowWidth = clamp(numberOr(density.WindowWidth, DEFAULTS.WindowWidth), 320, 2400)
    DEFAULTS.WindowHeight = clamp(numberOr(density.WindowHeight, DEFAULTS.WindowHeight), 220, 1600)
    DEFAULTS.RowHeight = clamp(numberOr(density.RowHeight, DEFAULTS.RowHeight), 36, 120)
    return true
end

local UI = {
    _activeTweens = setmetatable({}, { __mode = "k" }),
}

function UI.Create(className, properties)
    if type(className) ~= "string" or className == "" then
        error("[CrispyLib] UI.Create requires an Instance class name", 2)
    end

    local ok, instance = pcall(Instance.new, className)
    if not ok or instance == nil then
        error("[CrispyLib] cannot create " .. className .. ": " .. tostring(instance), 2)
    end

    properties = type(properties) == "table" and properties or {}
    local parent = properties.Parent
    local themeBindings = properties.Theme
    local processed = 0
    for property, value in pairs(properties) do
        processed = processed + 1
        if processed > 192 then
            instance:Destroy()
            error("[CrispyLib] too many properties for " .. className, 2)
        end
        if property ~= "Parent" and property ~= "Theme" then
            local propertyOk, propertyError = pcall(function()
                instance[property] = value
            end)
            if not propertyOk then
                instance:Destroy()
                error("[CrispyLib] invalid " .. className .. "." .. tostring(property) .. ": " .. tostring(propertyError), 2)
            end
        end
    end

    if type(themeBindings) == "table" then
        ThemeManager.Bind(instance, themeBindings)
    end
    if parent ~= nil then
        instance.Parent = parent
    end
    return instance
end

function UI.Tween(instance, goals, tweenInfo)
    if robloxType(instance) ~= "Instance" or instance.Parent == nil or type(goals) ~= "table" then
        return nil
    end

    local activeByProperty = UI._activeTweens[instance]
    if activeByProperty == nil then
        activeByProperty = {}
        UI._activeTweens[instance] = activeByProperty
    end
    for property in pairs(goals) do
        local previous = activeByProperty[property]
        if previous ~= nil then
            pcall(function()
                previous:Cancel()
            end)
        end
    end

    local ok, tween = pcall(function()
        return TweenService:Create(instance, tweenInfo or TWEEN.Medium, goals)
    end)
    if not ok then
        reportError(tween)
        return nil
    end

    for property in pairs(goals) do
        activeByProperty[property] = tween
    end
    local completedConnection
    completedConnection = tween.Completed:Connect(function()
        for property in pairs(goals) do
            if activeByProperty[property] == tween then
                activeByProperty[property] = nil
            end
        end
        if completedConnection and completedConnection.Connected then
            completedConnection:Disconnect()
        end
    end)
    tween:Play()
    return tween
end

function UI.Round(parent, radius)
    return UI.Create("UICorner", {
        CornerRadius = UDim.new(0, numberOr(radius, 8)),
        Parent = parent,
    })
end

function UI.RoundCorners(parent, radius, corners)
    local corner = UI.Round(parent, radius)
    if type(corners) ~= "table" then
        return corner
    end

    local rounded = UDim.new(0, numberOr(radius, 8))
    local square = UDim.new(0, 0)
    local supported = pcall(function()
        corner.TopLeftRadius = corners.TopLeft == false and square or rounded
        corner.TopRightRadius = corners.TopRight == false and square or rounded
        corner.BottomRightRadius = corners.BottomRight == false and square or rounded
        corner.BottomLeftRadius = corners.BottomLeft == false and square or rounded
    end)
    if not supported then
        corner.CornerRadius = rounded
    end
    return corner
end

function UI.Stroke(parent, color, thickness, transparency)
    local stroke = UI.Create("UIStroke", {
        Color = color or ThemeManager.Values.Border,
        Thickness = numberOr(thickness, 1),
        Transparency = clamp(numberOr(transparency, ThemeManager.Values.StrokeTransparency), 0, 1),
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
    local bindings = {}
    if color == nil then
        bindings.Color = "Border"
    end
    if transparency == nil then
        bindings.Transparency = "StrokeTransparency"
    end
    if next(bindings) ~= nil then
        ThemeManager.Bind(stroke, bindings)
    end
    return stroke
end

function UI.Gradient(parent, startKey, endKey, rotation, transparency)
    local firstKey = type(startKey) == "string" and startKey or "SurfaceGradientStart"
    local secondKey = type(endKey) == "string" and endKey or "SurfaceGradientEnd"
    local alpha = clamp(numberOr(transparency, 0), 0, 1)
    local gradient = UI.Create("UIGradient", {
        Rotation = numberOr(rotation, 135),
        Transparency = NumberSequence.new(alpha),
        Parent = parent,
    })
    ThemeManager.Bind(gradient, {
        Color = function(theme)
            local first = theme[firstKey] or theme.Accent
            local second = theme[secondKey] or theme.AccentHover
            return ColorSequence.new(first, second)
        end,
    })
    return gradient
end

function UI.Padding(parent, top, right, bottom, left)
    return UI.Create("UIPadding", {
        PaddingTop = UDim.new(0, numberOr(top, 0)),
        PaddingRight = UDim.new(0, numberOr(right, 0)),
        PaddingBottom = UDim.new(0, numberOr(bottom, 0)),
        PaddingLeft = UDim.new(0, numberOr(left, 0)),
        Parent = parent,
    })
end

function UI.List(parent, direction, spacing)
    return UI.Create("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, numberOr(spacing, 0)),
        Parent = parent,
    })
end

function UI.ScrollingFrame(parent, zIndex)
    return UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ZIndex = zIndex or Z_INDEX.Content,
        Parent = parent,
        Theme = { ScrollBarImageColor3 = "ScrollThumb" },
    })
end

function UI.Hover(taskGroup, button, normalColor, hoverColor, pressedColor)
    local gradient = button:FindFirstChildOfClass("UIGradient")
    local function setVisual(specification, offset, info)
        if button.Parent ~= nil and button.Active then
            UI.Tween(button, { BackgroundColor3 = resolveThemeValue(specification) }, info or TWEEN.Fast)
            if gradient ~= nil and gradient.Enabled then
                UI.Tween(gradient, { Offset = offset }, info or TWEEN.Fast)
            end
        end
    end
    taskGroup:Connect(button.MouseEnter, function()
        setVisual(hoverColor, Vector2.new(0.06, 0))
    end)
    taskGroup:Connect(button.MouseLeave, function()
        setVisual(normalColor, Vector2.new(0, 0))
    end)
    if pressedColor ~= nil then
        taskGroup:Connect(button.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                setVisual(pressedColor, Vector2.new(-0.04, 0), TWEEN.Instant)
            end
        end)
        taskGroup:Connect(button.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                setVisual(normalColor, Vector2.new(0, 0))
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                setVisual(hoverColor, Vector2.new(0.06, 0))
            end
        end)
    end
end

-- Shared coordinates use the actual ScreenGui safe area, including its origin.
local MobileUI = {}

function MobileUI.TouchMode(mode)
    return mode == "Touch" or (mode ~= "Desktop" and UserInputService.TouchEnabled == true)
end

function MobileUI.SafeScreen(screenGui, touch)
    pcall(function()
        screenGui.ScreenInsets = touch and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.DeviceSafeInsets
        screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
        screenGui.ClipToDeviceSafeArea = true
    end)
end

function MobileUI.Bounds(root, ignoreKeyboard)
    local origin, size
    if root ~= nil then
        local ok, rootOrigin, rootSize = pcall(function() return root.AbsolutePosition, root.AbsoluteSize end)
        if ok and rootSize.X > 0 and rootSize.Y > 0 then origin, size = rootOrigin, rootSize end
    end
    if size == nil then
        local camera = Workspace.CurrentCamera
        size = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        origin = Vector2.new(0, 0)
    end
    if not ignoreKeyboard then
        local ok, visible, keyboardPosition, keyboardSize = pcall(function()
            return UserInputService.OnScreenKeyboardVisible, UserInputService.OnScreenKeyboardPosition, UserInputService.OnScreenKeyboardSize
        end)
        if ok and visible and robloxType(keyboardPosition) == "Vector2" and robloxType(keyboardSize) == "Vector2"
            and keyboardSize.X >= size.X / 2 and keyboardSize.Y > 0 and keyboardPosition.Y > origin.Y
            and keyboardPosition.X < origin.X + size.X and keyboardPosition.X + keyboardSize.X > origin.X then
            size = Vector2.new(size.X, math.min(size.Y, keyboardPosition.Y - origin.Y - 8))
        end
    end
    return origin, Vector2.new(math.max(1, size.X), math.max(1, size.Y))
end

function MobileUI.WindowSize(size, viewport, fallbackWidth, fallbackHeight, touch)
    local width, height = fallbackWidth or DEFAULTS.WindowWidth, fallbackHeight or DEFAULTS.WindowHeight
    if robloxType(size) == "UDim2" then
        if size.X.Scale ~= 0 or size.X.Offset ~= 0 then width = viewport.X * size.X.Scale + size.X.Offset end
        if size.Y.Scale ~= 0 or size.Y.Offset ~= 0 then height = viewport.Y * size.Y.Scale + size.Y.Offset end
    end
    local availableWidth, availableHeight = math.max(1, viewport.X - 24), math.max(1, viewport.Y - 24)
    width = clamp(numberOr(width, DEFAULTS.WindowWidth), math.min(touch and 280 or DEFAULTS.MinWindowWidth, availableWidth), availableWidth)
    height = clamp(numberOr(height, DEFAULTS.WindowHeight), math.min(touch and 200 or DEFAULTS.MinWindowHeight, availableHeight), availableHeight)
    return math.floor(width + 0.5), math.floor(height + 0.5)
end

function MobileUI.PopupRect(root, absolute, anchorSize, wantedWidth, wantedHeight)
    local origin, viewport = MobileUI.Bounds(root)
    local width = math.min(wantedWidth, math.max(1, viewport.X - 12))
    local height = math.min(wantedHeight, math.max(1, viewport.Y - 12))
    local localPoint = absolute - origin
    local maxX, maxY = math.max(0, viewport.X - width - 6), math.max(0, viewport.Y - height - 6)
    local x = clamp(localPoint.X + anchorSize.X - width, math.min(6, maxX), maxX)
    local below = localPoint.Y + anchorSize.Y + 5
    local y = below + height <= viewport.Y - 6 and below or (localPoint.Y - height - 5)
    return x, clamp(y, math.min(6, maxY), maxY), width, height
end

function MobileUI.Contains(object, point)
    if not object.Visible then return false end
    local position, size = object.AbsolutePosition, object.AbsoluteSize
    return size.X > 0 and size.Y > 0 and point.X >= position.X and point.Y >= position.Y
        and point.X <= position.X + size.X and point.Y <= position.Y + size.Y
end

function MobileUI.InteractiveAt(handle, point)
    for _, child in ipairs(handle:GetDescendants()) do
        if (child:IsA("GuiButton") or child:IsA("TextBox") or child:IsA("ScrollingFrame"))
            and MobileUI.Contains(child, point) then
            local parent, visible = child.Parent, true
            while parent ~= nil and parent ~= handle do
                if parent:IsA("GuiObject") and (not parent.Visible
                    or (parent.ClipsDescendants and not MobileUI.Contains(parent, point))) then visible = false; break end
                parent = parent.Parent
            end
            if visible then return true end
        end
    end
    return false
end

function MobileUI.SuspendScroll(owner)
    local root = type(owner) == "table" and (owner._root or owner.Popup) or nil
    if robloxType(root) ~= "Instance" then return nil end
    local scroll = root:FindFirstAncestorWhichIsA("ScrollingFrame")
    if scroll == nil then return nil end
    local previous = scroll.ScrollingEnabled
    scroll.ScrollingEnabled = false
    return { Instance = scroll, Enabled = previous }
end

function MobileUI.RestoreScroll(state)
    if state ~= nil and state.Instance.Parent ~= nil then state.Instance.ScrollingEnabled = state.Enabled end
end

function MobileUI.RevealTextBox(textBox, screenGui)
    if robloxType(textBox) ~= "Instance" or not textBox:IsDescendantOf(screenGui) then return end
    local scroll = textBox:FindFirstAncestorWhichIsA("ScrollingFrame")
    if scroll == nil then return end
    local top = scroll.AbsolutePosition.Y + 8
    local bottom = top + math.max(0, scroll.AbsoluteSize.Y - 16)
    local textTop = textBox.AbsolutePosition.Y
    local textBottom = textTop + textBox.AbsoluteSize.Y
    local delta = textBottom > bottom and textBottom - bottom or (textTop < top and textTop - top or 0)
    if delta ~= 0 then
        local current = scroll.CanvasPosition
        local maximum = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y)
        scroll.CanvasPosition = Vector2.new(current.X, clamp(current.Y + delta, 0, maximum))
    end
end

function MobileUI.AttachRow(component)
    local row, label, description = component._root, component._label, component._description
    if label == nil or row.Name:sub(1, 4) ~= "Row_" then return end
    local originalSize = row.Size
    local entries, controls = {}, {}
    for _, child in ipairs(row:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "Hover" then
            local entry = { Instance = child, Size = child.Size, Position = child.Position }
            entries[#entries + 1] = entry
            if child ~= label and child ~= description then controls[#controls + 1] = entry end
        end
    end
    local function layout()
        if component._destroyed or row.Parent == nil then return end
        local window = component._tab._window
        local width = row.AbsoluteSize.X
        if width <= 0 then width = window._width - (window._compact and 0 or DEFAULTS.SidebarWidth) - 48 end
        local touch, stacked = window._touch, width < 480
        local nextRowSize = originalSize
        for _, entry in ipairs(entries) do
            if entry.Instance.Parent == row then
                entry.Instance.Size, entry.Instance.Position = entry.Size, entry.Position
            end
        end
        if description ~= nil then
            description.TextWrapped = touch or stacked
            description.TextTruncate = (touch or stacked) and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
            description.TextSize = touch and 11 or 10
        end
        if #controls == 0 then
            label.Size = UDim2.new(1, -32, 0, 18)
            if description ~= nil then description.Size = UDim2.new(1, -32, 0, touch and 28 or 14) end
            if touch and description ~= nil then nextRowSize = UDim2.new(1, 0, 0, math.max(originalSize.Y.Offset, 78)) end
            row.Size = nextRowSize
            return
        end
        local toggle = controls[1].Instance.Name == "ToggleTrack"
        if toggle then
            label.Size = UDim2.new(1, -100, 0, 18)
            if description ~= nil then description.Size = UDim2.new(1, -100, 0, (touch or stacked) and 28 or 14) end
            if touch and description ~= nil then nextRowSize = UDim2.new(1, 0, 0, math.max(originalSize.Y.Offset, 78)) end
            row.Size = nextRowSize
            return
        end
        if stacked then
            label.Size, label.Position = UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 12)
            local top = description ~= nil and 70 or 40
            if description ~= nil then
                description.Size, description.Position = UDim2.new(1, -32, 0, 28), UDim2.fromOffset(16, 36)
            end
            local contentHeight = touch and 44 or 30
            for _, entry in ipairs(controls) do
                local child = entry.Instance
                if child.Name == "SliderTrack" or child.Name == "ProgressTrack" then
                    child.Size = UDim2.new(1, -32, 0, entry.Size.Y.Offset)
                    child.Position = UDim2.fromOffset(16, top + 22 - entry.Size.Y.Offset / 2)
                    contentHeight = 44
                elseif child.Name == "SliderValue" or child.Name == "ProgressValue" then
                    label.Size = UDim2.new(1, -116, 0, 18)
                    child.Size, child.Position = UDim2.new(0, 84, 0, 18), UDim2.new(1, -100, 0, 12)
                else
                    local height = math.max(contentHeight, originalSize.Y.Offset * entry.Size.Y.Scale + entry.Size.Y.Offset)
                    child.Size, child.Position = UDim2.new(1, -32, 0, height), UDim2.fromOffset(16, top)
                    contentHeight = math.max(contentHeight, height)
                end
            end
            nextRowSize = UDim2.new(1, 0, 0, top + contentHeight + 12)
        elseif touch then
            nextRowSize = UDim2.new(1, 0, 0, math.max(originalSize.Y.Offset, description ~= nil and 78 or 70))
            for _, entry in ipairs(controls) do
                if entry.Size.Y.Scale == 0 and entry.Size.Y.Offset >= 26 and entry.Size.Y.Offset <= 36 then
                    local child = entry.Instance
                    child.Size = UDim2.new(entry.Size.X.Scale, entry.Size.X.Offset, 0, 44)
                    if entry.Position.Y.Scale == 0.5 then
                        child.Position = UDim2.new(entry.Position.X.Scale, entry.Position.X.Offset, 0.5, -22)
                    end
                end
            end
            if description ~= nil then description.Size = UDim2.new(description.Size.X.Scale, description.Size.X.Offset, 0, 28) end
        end
        row.Size = nextRowSize
    end
    component._layoutRow = layout
    component._tasks:Connect(row:GetPropertyChangedSignal("AbsoluteSize"), layout)
    layout()
end

local opacityStates = setmetatable({}, { __mode = "k" })

local function transparencyProperties(instance)
    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        return { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" }
    end
    if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
        return { "BackgroundTransparency", "ImageTransparency" }
    end
    if instance:IsA("GuiObject") then
        return { "BackgroundTransparency" }
    end
    if instance:IsA("UIStroke") then
        return { "Transparency" }
    end
    return nil
end

local function applyInstanceOpacity(instance, opacity, baselines)
    local properties = transparencyProperties(instance)
    if properties == nil then
        return
    end

    local stored = baselines[instance]
    if stored == nil then
        stored = {}
        baselines[instance] = stored
    end
    for index = 1, #properties do
        local property = properties[index]
        if stored[property] == nil then
            local ok, value = pcall(function()
                return instance[property]
            end)
            if ok then
                stored[property] = value
            end
        end
        local original = stored[property]
        if type(original) == "number" then
            pcall(function()
                instance[property] = 1 - ((1 - original) * opacity)
            end)
        end
    end
end

function UI.SetOpacity(root, opacity)
    if robloxType(root) ~= "Instance" then
        return false
    end
    local normalized = clamp(numberOr(opacity, 1), 0, 1)
    local baselines = opacityStates[root]
    if baselines == nil then
        baselines = setmetatable({}, { __mode = "k" })
        opacityStates[root] = baselines
    end

    applyInstanceOpacity(root, normalized, baselines)
    local descendants = root:GetDescendants()
    local count = math.min(#descendants, LIMITS.MaxSerializationNodes)
    for index = 1, count do
        applyInstanceOpacity(descendants[index], normalized, baselines)
    end
    return true
end

local function resolveTargetInstance(target)
    if robloxType(target) == "Instance" then
        return target
    end
    if type(target) == "table" then
        return target.Instance or target._root or target._instance or target._row
    end
    return nil
end

function CrispyLib.Style(first, second, third, fourth)
    local target, styles, persistent = methodArguments(CrispyLib, first, second, third, fourth)
    local instance = resolveTargetInstance(target)
    if robloxType(instance) ~= "Instance" or type(styles) ~= "table" then
        return target
    end

    if persistent then
        ThemeManager.Bind(instance, styles)
    else
        ThemeManager.ApplyBinding(instance, styles)
    end
    return target
end

function CrispyLib.SetStyle(...)
    return CrispyLib.Style(...)
end

function CrispyLib.SetOpacity(first, second, third)
    local target, opacity = methodArguments(CrispyLib, first, second, third)
    UI.SetOpacity(resolveTargetInstance(target), opacity)
    return target
end

local Serializer = {}

local function encodeSpecial(value)
    local valueType = robloxType(value)
    if valueType == "Color3" then
        return { __crispyType = "Color3", r = value.R, g = value.G, b = value.B }, true
    end
    if valueType == "EnumItem" then
        local enumName = tostring(value.EnumType):match("^Enum%.(.+)$")
        if enumName == nil or enumName == "" then
            return nil, false
        end
        return {
            __crispyType = "EnumItem",
            enum = enumName,
            name = value.Name,
        }, true
    end
    if valueType == "Vector2" then
        return { __crispyType = "Vector2", x = value.X, y = value.Y }, true
    end
    if valueType == "Vector3" then
        return { __crispyType = "Vector3", x = value.X, y = value.Y, z = value.Z }, true
    end
    if valueType == "UDim" then
        return { __crispyType = "UDim", scale = value.Scale, offset = value.Offset }, true
    end
    if valueType == "UDim2" then
        return {
            __crispyType = "UDim2",
            xs = value.X.Scale,
            xo = value.X.Offset,
            ys = value.Y.Scale,
            yo = value.Y.Offset,
        }, true
    end
    if valueType == "CFrame" then
        return { __crispyType = "CFrame", components = { value:GetComponents() } }, true
    end
    return nil, false
end

local function decodeSpecial(value)
    if type(value) ~= "table" then
        return nil, false
    end
    local tag = value.__crispyType or value.__type
    local fields = ({ Color3 = { "r", "g", "b" }, Vector2 = { "x", "y" }, Vector3 = { "x", "y", "z" },
        UDim = { "scale", "offset" }, UDim2 = { "xs", "xo", "ys", "yo" } })[tag]
    if fields ~= nil then
        for _, field in ipairs(fields) do
            if not isFiniteNumber(value[field]) then return nil, false, "invalid " .. tag .. " component " .. field end
        end
    end
    if tag == "Nil" then
        return nil, true
    end
    if tag == "Color3" then
        return Color3.new(numberOr(value.r, 0), numberOr(value.g, 0), numberOr(value.b, 0)), true
    end
    if tag == "Vector2" then
        return Vector2.new(numberOr(value.x, 0), numberOr(value.y, 0)), true
    end
    if tag == "Vector3" then
        return Vector3.new(numberOr(value.x, 0), numberOr(value.y, 0), numberOr(value.z, 0)), true
    end
    if tag == "UDim" then
        return UDim.new(numberOr(value.scale, 0), numberOr(value.offset, 0)), true
    end
    if tag == "UDim2" then
        return UDim2.new(
            numberOr(value.xs, 0),
            numberOr(value.xo, 0),
            numberOr(value.ys, 0),
            numberOr(value.yo, 0)
        ), true
    end
    if tag == "EnumItem" and type(value.enum) == "string" and type(value.name) == "string" then
        local ok, enumItem = pcall(function()
            return Enum[value.enum][value.name]
        end)
        if ok and enumItem ~= nil then
            return enumItem, true
        end
    end
    if tag == "CFrame" then
        local values = value.components
        if type(values) ~= "table" or #values ~= 12 then return nil, false, "invalid CFrame components" end
        for index = 1, 12 do
            if not isFiniteNumber(values[index]) then return nil, false, "invalid CFrame component" end
        end
        local ok, decoded = pcall(CFrame.new, unpackValues(values, 1, 12))
        if not ok then return nil, false, "invalid CFrame: " .. tostring(decoded) end
        return decoded, true
    end
    if tag == "EnumItem" then return nil, false, "invalid EnumItem" end
    return nil, false
end

local function encodePrimitive(value)
    local special, isSpecial = encodeSpecial(value)
    if isSpecial then
        return special, true, nil
    end
    local valueType = type(value)
    if valueType == "nil" then
        return { __crispyType = "Nil" }, true, nil
    end
    if valueType == "string" or valueType == "boolean" then
        return value, true, nil
    end
    if valueType == "number" then
        if not isFiniteNumber(value) then
            return nil, false, "non-finite numbers cannot be serialized"
        end
        return value, true, nil
    end
    if valueType == "table" then
        return nil, false, nil
    end
    return nil, false, "unsupported value type: " .. robloxType(value)
end

function Serializer.Encode(value)
    local encoded, complete, primitiveError = encodePrimitive(value)
    if complete then
        return encoded
    end
    if primitiveError ~= nil then
        return nil, primitiveError
    end

    local root = {}
    local queue = { { Source = value, Target = root, Depth = 0 } }
    local nodeCount = 1

    for queueIndex = 1, LIMITS.MaxSerializationNodes do
        local frame = queue[queueIndex]
        if frame == nil then
            return root
        end
        if frame.Depth >= LIMITS.MaxSerializationDepth then
            return nil, "serialization depth limit reached"
        end

        local numericCount, stringCount, maximumIndex = 0, 0, 0
        for key in pairs(frame.Source) do
            if type(key) == "number" then
                if not isFiniteNumber(key) or key < 1 or key % 1 ~= 0 then return nil, "array keys must be positive integers" end
                numericCount, maximumIndex = numericCount + 1, math.max(maximumIndex, key)
            elseif type(key) == "string" then stringCount = stringCount + 1
            else return nil, "table keys must be strings or numbers" end
            if numericCount + stringCount > LIMITS.MaxSerializationNodes then return nil, "serialization node limit reached" end
        end
        if numericCount > 0 and stringCount > 0 then return nil, "mixed array/dictionary keys cannot be saved as JSON" end
        if maximumIndex ~= numericCount then return nil, "sparse arrays cannot be saved as JSON" end
        local entryCount = 0
        for key, childValue in pairs(frame.Source) do
            entryCount = entryCount + 1
            nodeCount = nodeCount + 1
            if entryCount > LIMITS.MaxSerializationNodes or nodeCount > LIMITS.MaxSerializationNodes then
                return nil, "serialization node limit reached"
            end
            if type(key) ~= "string" and type(key) ~= "number" then
                return nil, "table keys must be strings or numbers"
            end

            local childEncoded, childComplete, childError = encodePrimitive(childValue)
            if childError ~= nil then
                return nil, childError
            end
            if childComplete then
                frame.Target[key] = childEncoded
            else
                local ancestor = frame
                while ancestor ~= nil do
                    if ancestor.Source == childValue then return nil, "cyclic tables cannot be serialized" end
                    ancestor = ancestor.Parent
                end
                local childTarget = {}
                frame.Target[key] = childTarget
                queue[#queue + 1] = {
                    Source = childValue,
                    Target = childTarget,
                    Depth = frame.Depth + 1,
                    Parent = frame,
                }
            end
        end
    end
    return nil, "serialization queue limit reached"
end

function Serializer.Decode(value)
    if type(value) ~= "table" then
        local _, _, primitiveError = encodePrimitive(value)
        if primitiveError ~= nil then return nil, primitiveError end
        return value
    end
    local special, isSpecial, specialError = decodeSpecial(value)
    if specialError ~= nil then return nil, specialError end
    if isSpecial then
        return special
    end

    local root = {}
    local queue = { { Source = value, Target = root, Depth = 0 } }
    local nodeCount = 1
    for queueIndex = 1, LIMITS.MaxSerializationNodes do
        local frame = queue[queueIndex]
        if frame == nil then
            return root
        end
        if frame.Depth >= LIMITS.MaxSerializationDepth then
            return nil, "deserialization depth limit reached"
        end

        local entryCount = 0
        for key, childValue in pairs(frame.Source) do
            entryCount = entryCount + 1
            nodeCount = nodeCount + 1
            if entryCount > LIMITS.MaxSerializationNodes or nodeCount > LIMITS.MaxSerializationNodes then
                return nil, "deserialization node limit reached"
            end
            if type(key) ~= "string" and type(key) ~= "number" then
                return nil, "table keys must be strings or numbers"
            end
            if type(childValue) == "table" then
                local decodedSpecial, decoded, decodeError = decodeSpecial(childValue)
                if decodeError ~= nil then return nil, decodeError end
                if decoded then
                    frame.Target[key] = decodedSpecial
                else
                    local childTarget = {}
                    frame.Target[key] = childTarget
                    queue[#queue + 1] = {
                        Source = childValue,
                        Target = childTarget,
                        Depth = frame.Depth + 1,
                    }
                end
            else
                local _, _, primitiveError = encodePrimitive(childValue)
                if primitiveError ~= nil then return nil, primitiveError end
                frame.Target[key] = childValue
            end
        end
    end
    return nil, "deserialization queue limit reached"
end

CrispyLib.Serializer = Serializer

local State = {
    _data = {}, _listeners = {}, _pending = {}, _dispatching = false, _hold = 0,
}

local function normalizeFlag(flag)
    if type(flag) == "string" and flag ~= "" then return flag end
    if type(flag) == "number" and isFiniteNumber(flag) then return tostring(flag) end
    return nil
end

function State.Get(flag)
    local normalized = normalizeFlag(flag)
    if normalized == nil then return nil end
    return State._data[normalized]
end

local function invokeStateListener(callback, ...)
    -- Non-yielding listeners finish immediately. A yielded listener must not
    -- suspend the shared dispatch queue inside a caller-owned cancellable task.
    task.spawn(safeCall, callback, ...)
end

-- Internal batches commit every value before their notifications are delivered.
function State._apply(updates)
    local notifications = {}
    for _, update in ipairs(updates) do
        local previous = State._data[update.Flag]
        local listeners = State._listeners[update.Flag]
        if listeners and not valuesEqual(previous, update.Value) then
            notifications[#notifications + 1] = {
                Flag = update.Flag, Value = update.Value, Previous = previous,
                Source = update.Source, Listeners = table.clone(listeners),
            }
        end
    end
    if #State._pending + #notifications > LIMITS.MaxSerializationNodes then
        return false, "state notification limit reached"
    end
    for _, update in ipairs(updates) do State._data[update.Flag] = update.Value end
    for _, notification in ipairs(notifications) do
        State._pending[#State._pending + 1] = notification
    end
    return State._flush()
end

function State._flush()
    if State._dispatching or State._hold > 0 then return true end
    State._dispatching = true
    local index = 1
    -- Recursive writes append notifications; they cannot interrupt the current one.
    while index <= #State._pending do
        local notification = State._pending[index]
        dispatchSnapshot(notification.Listeners, invokeStateListener,
            notification.Value, notification.Previous, notification.Source)
        index = index + 1
    end
    table.clear(State._pending)
    State._dispatching = false
    return true
end

function State.Set(flag, value, source)
    local normalized = normalizeFlag(flag)
    if normalized == nil then return false, "flag must be a non-empty string or finite number" end
    return State._apply({ { Flag = normalized, Value = value, Source = source } })
end

function State.Subscribe(flag, callback)
    local normalized = normalizeFlag(flag)
    if normalized == nil or type(callback) ~= "function" then return function() end end
    local listeners = State._listeners[normalized]
    if listeners == nil then listeners = {}; State._listeners[normalized] = listeners end
    local unsubscribe = subscribe(listeners, callback, LIMITS.MaxListeners)
    local active = true
    return function()
        if not active then return end
        active = false
        unsubscribe()
        if #listeners == 0 and State._listeners[normalized] == listeners then
            State._listeners[normalized] = nil
        end
    end
end

function State.Snapshot()
    return shallowCopy(State._data, LIMITS.MaxSerializationNodes)
end

function State.Apply(snapshot)
    if type(snapshot) ~= "table" then return false, "snapshot must be a table" end
    local updates, seen = {}, {}
    for flag, value in pairs(snapshot) do
        if #updates >= LIMITS.MaxSerializationNodes then return false, "snapshot limit reached" end
        local normalized = normalizeFlag(flag)
        if normalized == nil or seen[normalized] then return false, "invalid or duplicate snapshot flag" end
        seen[normalized] = true
        updates[#updates + 1] = { Flag = normalized, Value = value }
    end
    return State._apply(updates)
end

function State._restore(snapshot)
    local updates = {}
    for flag in pairs(State._data) do
        if snapshot[flag] == nil then updates[#updates + 1] = { Flag = flag } end
    end
    for flag, value in pairs(snapshot) do updates[#updates + 1] = { Flag = flag, Value = value } end
    return State._apply(updates)
end

CrispyLib.State = State

local Registry = {
    _entries = {}, _defaults = {}, _ignored = {}, _loaded = {},
    _applySource = {}, _applying = false,
}

-- Control getters/setters and schema functions must finish synchronously. A
-- yielded setter cannot leave the shared state transaction suspended.
local function invokeConfigFunction(callback, ...)
    local arguments = table.pack(...)
    local thread = coroutine.create(function()
        return pcall(callback, unpackValues(arguments, 1, arguments.n))
    end)
    local result = table.pack(coroutine.resume(thread))
    if not result[1] then return false, tostring(result[2]) end
    if coroutine.status(thread) ~= "dead" then
        pcall(task.cancel, thread)
        return false, "config getter, setter, or validator must not yield"
    end
    return unpackValues(result, 2, result.n)
end

local function validateRegistryValue(entry, value)
    local options = entry.Options
    if type(options.Normalize) == "function" then
        local ok, normalized, err = invokeConfigFunction(options.Normalize, value)
        if not ok then return nil, tostring(normalized) end
        if err ~= nil then return nil, tostring(err) end
        value = normalized
    end
    if value ~= nil and options.Type ~= nil and options.Type ~= false
        and robloxType(value) ~= options.Type then
        return nil, "expected " .. tostring(options.Type) .. ", got " .. robloxType(value)
    end
    if type(options.Validate) == "function" then
        local ok, valid, err = invokeConfigFunction(options.Validate, value)
        if not ok then return nil, tostring(valid) end
        if valid ~= true then return nil, tostring(err or "value rejected by validator") end
    end
    local _, encodeError = Serializer.Encode(value)
    if encodeError ~= nil then return nil, encodeError end
    return value
end

local function storeRegistryDefault(flag, initialValue)
    if Registry._defaults[flag] ~= nil then return end
    local encoded, err = Serializer.Encode(initialValue)
    if err == nil then Registry._defaults[flag] = encoded
    else reportError("cannot store default for " .. flag .. ": " .. err) end
end

local function unregisterRegistryEntry(flag, entries, entry)
    if not entry.Active then return end
    entry.Active = false
    if entry.Unsubscribe ~= nil then entry.Unsubscribe() end
    removeArrayValue(entries, entry, LIMITS.MaxListeners)
    if #entries == 0 and Registry._entries[flag] == entries then Registry._entries[flag] = nil end
end

local function createRegistryUnregister(flag, entries, entry)
    return function() unregisterRegistryEntry(flag, entries, entry) end
end

function Registry.Register(flag, getter, setter, owner, options)
    local normalized = normalizeFlag(flag)
    if normalized == nil then return function() end, "invalid flag" end
    if type(getter) ~= "function" or type(setter) ~= "function" then
        return function() end, "registry getter and setter must be functions"
    end
    local entries = Registry._entries[normalized]
    if entries == nil then entries = {}; Registry._entries[normalized] = entries end
    if #entries >= LIMITS.MaxListeners then return function() end, "too many components share flag " .. normalized end
    local ok, initialValue = invokeConfigFunction(getter)
    if not ok then return function() end, tostring(initialValue) end
    options = type(options) == "table" and shallowCopy(options, 32) or {}
    if options.Canonical == true and options.Type == nil and initialValue ~= nil then
        options.Type = robloxType(initialValue)
    end
    local entry = { Getter = getter, Setter = setter, Owner = owner or {},
        Options = options, Active = true, Unsubscribe = nil }
    local validDefault, defaultError = validateRegistryValue(entry, initialValue)
    if defaultError ~= nil then return function() end, "invalid default: " .. defaultError end
    storeRegistryDefault(normalized, validDefault)
    entries[#entries + 1] = entry
    entry.Unsubscribe = State.Subscribe(normalized, function(value, _, source)
        if entry.Active and source ~= entry.Owner and source ~= Registry._applySource then
            safeCall(setter, value, true, true)
        end
    end)
    local existing = State.Get(normalized)
    local loaded = Registry._loaded[normalized]
    if existing == nil and loaded == nil then
        State.Set(normalized, validDefault, entry.Owner)
    else
        local value, validationError = validateRegistryValue(entry, existing)
        if validationError ~= nil then
            reportError("invalid stored value for " .. normalized .. ": " .. validationError)
            value = validDefault
        end
        local setOk, setError = invokeConfigFunction(setter, value, true, true)
        if not setOk then
            unregisterRegistryEntry(normalized, entries, entry)
            return function() end, tostring(setError)
        end
        if options.Canonical == true then
            local getOk, canonical = invokeConfigFunction(getter)
            if getOk then value = canonical else reportError(canonical) end
        end
        State.Set(normalized, value, entry.Owner)
        if loaded and loaded.Callbacks and type(options.Apply) == "function" then
            safeCall(options.Apply, value, loaded.Context)
        end
    end
    return createRegistryUnregister(normalized, entries, entry)
end

function Registry.Ignore(flag, shouldIgnore)
    local normalized = normalizeFlag(flag)
    if normalized == nil then return false end
    Registry._ignored[normalized] = shouldIgnore ~= false
    return true
end

function Registry.GetAll()
    local snapshot, count = {}, 0
    for flag in pairs(Registry._defaults) do
        count = count + 1
        if count > LIMITS.MaxSerializationNodes then return nil, "config snapshot limit reached" end
        if not Registry._ignored[flag] then
            local value, err = Serializer.Encode(State.Get(flag))
            if err ~= nil then return nil, "cannot serialize flag " .. flag .. ": " .. err end
            snapshot[flag] = value
        end
    end
    return snapshot
end

function Registry.Prepare(snapshot)
    if type(snapshot) ~= "table" then return nil, "snapshot must be a table" end
    local updates, seen = {}, {}
    for flag, encoded in pairs(snapshot) do
        if #updates >= LIMITS.MaxSerializationNodes then return nil, "config value limit reached" end
        local normalized = normalizeFlag(flag)
        if normalized == nil or seen[normalized] then return nil, "invalid or duplicate config flag" end
        local ok, value, err = pcall(Serializer.Decode, encoded)
        if not ok then err = tostring(value) end
        if err ~= nil then return nil, "cannot decode flag " .. normalized .. ": " .. err end
        local prepared = nil
        local entries = table.clone(Registry._entries[normalized] or {})
        for _, entry in ipairs(entries) do
            if entry.Active then
                local accepted, validationError = validateRegistryValue(entry, value)
                if validationError ~= nil then return nil, "invalid flag " .. normalized .. ": " .. validationError end
                if prepared and not valuesEqual(prepared.Value, accepted) then
                    return nil, "incompatible normalizers for shared flag " .. normalized
                end
                prepared = { Value = accepted }
            end
        end
        if prepared then value = prepared.Value end
        local _, encodeError = Serializer.Encode(value)
        if encodeError ~= nil then return nil, "invalid flag " .. normalized .. ": " .. encodeError end
        seen[normalized] = true
        updates[#updates + 1] = { Flag = normalized, Value = value, Entries = entries, Source = Registry._applySource }
    end
    table.sort(updates, function(left, right) return left.Flag < right.Flag end)
    return updates
end

function Registry.ApplyAll(snapshot)
    if Registry._applying then return false, "a registry application is already in progress" end
    local updates, prepareError = Registry.Prepare(snapshot)
    if updates == nil then return false, prepareError end
    local before = table.clone(State._data)
    local pendingCount = #State._pending
    local controls, changed, normalizedFlags = {}, {}, {}
    Registry._applying = true
    State._hold = State._hold + 1
    local ok, applyError = pcall(function()
        for _, update in ipairs(updates) do
            for _, entry in ipairs(update.Entries) do
                if entry.Active then
                    local getOk, previous = invokeConfigFunction(entry.Getter)
                    if not getOk then error(update.Flag .. ": " .. tostring(previous), 0) end
                    controls[#controls + 1] = { Entry = entry, Value = previous }
                end
            end
            State._data[update.Flag] = update.Value
        end
        for _, update in ipairs(updates) do
            local canonical = nil
            for _, entry in ipairs(update.Entries) do
                if entry.Active then
                    local setOk, setError = invokeConfigFunction(entry.Setter, update.Value, true, true)
                    if not setOk then error(update.Flag .. ": " .. tostring(setError), 0) end
                    if entry.Options.Canonical == true then
                        local getOk, value = invokeConfigFunction(entry.Getter)
                        if not getOk then error(update.Flag .. ": " .. tostring(value), 0) end
                        local accepted, validationError = validateRegistryValue(entry, value)
                        if validationError ~= nil then error(update.Flag .. ": " .. validationError, 0) end
                        if canonical and not valuesEqual(canonical.Value, accepted) then
                            error("shared controls disagree for flag " .. update.Flag, 0)
                        end
                        canonical = { Value = accepted }
                    end
                end
            end
            if canonical then
                if not valuesEqual(update.Value, canonical.Value) then normalizedFlags[#normalizedFlags + 1] = update.Flag end
                State._data[update.Flag] = canonical.Value
                update.Value = canonical.Value
            end
        end
        local staged = table.clone(State._data)
        State._data = before
        for index = #State._pending, pendingCount + 1, -1 do State._pending[index] = nil end
        for flag, value in pairs(staged) do
            if not valuesEqual(before[flag], value) then changed[#changed + 1] = { Flag = flag, Value = value, Source = Registry._applySource } end
        end
        for flag in pairs(before) do
            if staged[flag] == nil then changed[#changed + 1] = { Flag = flag, Source = Registry._applySource } end
        end
        table.sort(changed, function(left, right) return left.Flag < right.Flag end)
        local committed, commitError = State._apply(changed)
        if not committed then error(commitError, 0) end
    end)
    if not ok then
        local rollbackErrors = {}
        for index = #controls, 1, -1 do
            local control = controls[index]
            if control.Entry.Active then
                local restored, restoreError = invokeConfigFunction(control.Entry.Setter, control.Value, true, true)
                if not restored then rollbackErrors[#rollbackErrors + 1] = tostring(restoreError) end
            end
        end
        State._data = before
        for index = #State._pending, pendingCount + 1, -1 do State._pending[index] = nil end
        if #rollbackErrors > 0 then applyError = tostring(applyError) .. "; rollback: " .. table.concat(rollbackErrors, "; ") end
    end
    State._hold = State._hold - 1
    Registry._applying = false
    State._flush()
    if not ok then return false, tostring(applyError) end
    local changedFlags = {}
    for _, update in ipairs(changed) do changedFlags[#changedFlags + 1] = update.Flag end
    return true, nil, { Updates = updates, ChangedFlags = changedFlags, NormalizedFlags = normalizedFlags }
end

function Registry.ResetDefaults()
    return Registry.ApplyAll(Registry._defaults)
end

CrispyLib.Registry = Registry

CrispyLib._flags = setmetatable({}, {
    __index = function(_, flag)
        return State.Get(flag)
    end,
    __newindex = function(_, flag, value)
        State.Set(flag, value)
    end,
})

function CrispyLib.GetFlag(first, second)
    local flag = normalizeMethodArgument(first, second, CrispyLib)
    return State.Get(flag)
end

function CrispyLib.SetFlag(first, second, third)
    local flag, value = methodArguments(CrispyLib, first, second, third)
    return State.Set(flag, value)
end

function CrispyLib.Watch(first, second, third)
    local flag, callback = methodArguments(CrispyLib, first, second, third)
    return State.Subscribe(flag, callback)
end

local Config = {
    Version = 1, _migrations = {}, _memory = {}, _profile = "default",
    _autoSaveToken = nil, _switching = false, _switchThread = nil,
    _switchValues = nil, _switchLoaded = nil,
    _applyThread = nil, _readThread = nil, _writeThread = nil, _notifying = false,
    _listeners = {}, _pendingAutoLoads = {}, _blockedAutoSaves = {},
    _settings = { Folder = nil, File = "default", Storage = nil, ApplyCallbacks = true },
}
CrispyLib.Config = Config

local function sanitizePathSegment(value, fallback)
    local segment = normalizeText(value, fallback or "default")
    segment = segment:gsub("^%s+", ""):gsub("%s+$", "")
    segment = segment:gsub("[<>:\"/\\|%?%*%c]", "_"):gsub("%.+$", "")
    if segment == "" or segment == "." or segment == ".." then segment = fallback or "default" end
    return segment:sub(1, 64)
end

do -- Config codec, application, and storage are separate API boundaries.
local function normalizeFolder(folder)
    if type(folder) ~= "string" then return nil, "config folder must be a string" end
    folder = folder:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
    if #folder == 0 or #folder > 1024 then return nil, "invalid config folder length" end
    local unc = folder:sub(1, 2) == "//"
    folder = folder:gsub("/+", "/")
    if unc then folder = "/" .. folder end
    if folder ~= "/" and not folder:match("^%a:/$") then folder = folder:gsub("/+$", "") end
    local rest = folder:gsub("^%a:/", "")
    if rest:find('[<>:"|%?%*%c]') then return nil, "config folder contains invalid characters" end
    local segments = 0
    for segment in rest:gmatch("[^/]+") do
        segments = segments + 1
        if segment == "." or segment == ".." then return nil, "config folder must not contain dot segments" end
    end
    if unc and segments < 2 then return nil, "UNC folders require a server and share" end
    return folder
end

local function joinPath(folder, name)
    return folder .. (folder:sub(-1) == "/" and "" or "/") .. name
end

local function liveGuard(field)
    local thread = Config[field]
    if thread ~= nil and coroutine.status(thread) == "dead" then Config[field] = nil; return false end
    return thread ~= nil
end

local function profileBusy()
    if Config._switching and Config._switchThread ~= nil and coroutine.status(Config._switchThread) == "dead" then
        local previousValues, previousLoaded = Config._switchValues, Config._switchLoaded
        Config._switching, Config._switchThread = false, nil
        Config._switchValues, Config._switchLoaded = nil, nil
        if previousLoaded ~= nil then Registry._loaded = previousLoaded end
        if previousValues ~= nil then
            local ok, restored, err = pcall(State._restore, previousValues)
            if not ok or not restored then reportError("cancelled profile rollback failed: " .. tostring(err or restored)) end
        end
    end
    return Config._switching
end

local function applicationBusy()
    return liveGuard("_applyThread") or Config._notifying
end

local function validateStorage(storage)
    if storage == nil or storage == false then return true end
    if type(storage) ~= "table" or type(storage.Read) ~= "function" or type(storage.Write) ~= "function" then
        return false, "custom storage requires Read(path) and Write(path, contents)"
    end
    for _, name in ipairs({ "List", "Delete", "Exists", "EnsureFolder" }) do
        if storage[name] ~= nil and type(storage[name]) ~= "function" then return false, "invalid storage method " .. name end
    end
    return true
end

local MemoryStorage = {}
function MemoryStorage.Read(path)
    local contents = Config._memory[path]
    if contents == nil then return nil, "config does not exist" end
    return contents
end
function MemoryStorage.Write(path, contents) Config._memory[path] = contents; return true end
function MemoryStorage.Exists(path) return Config._memory[path] ~= nil end
function MemoryStorage.Delete(path) Config._memory[path] = nil; return true end
function MemoryStorage.List(folder)
    local files, prefix = {}, joinPath(folder, "")
    for path in pairs(Config._memory) do
        if path:sub(1, #prefix) == prefix and not path:sub(#prefix + 1):find("/", 1, true) then
            files[#files + 1] = path
            if #files >= LIMITS.MaxRows then break end
        end
    end
    return files
end

local FileStorage = {}
function FileStorage.Read(path)
    local isFile = Runtime.GetFileFunction("isfile")
    if isFile ~= nil and not isFile(path) then return nil, "config does not exist" end
    return Runtime.GetFileFunction("readfile")(path)
end
function FileStorage.Write(path, contents) return Runtime.GetFileFunction("writefile")(path, contents) end
function FileStorage.List(folder)
    local listFiles = Runtime.GetFileFunction("listfiles")
    if listFiles == nil then error("listfiles is unavailable", 0) end
    return listFiles(folder)
end
function FileStorage.Delete(path)
    local deleteFile = Runtime.GetFileFunction("delfile")
    if deleteFile == nil then error("delfile is unavailable", 0) end
    return deleteFile(path)
end
function FileStorage.EnsureFolder(folder)
    local makeFolder, isFolder = Runtime.GetFileFunction("makefolder"), Runtime.GetFileFunction("isfolder")
    local current, rest = "", folder
    local drive = folder:match("^%a:/")
    if drive then current, rest = drive, folder:sub(4)
    elseif folder:sub(1, 2) == "//" then
        local server, share, tail = folder:match("^//([^/]+)/([^/]+)(.*)$")
        current, rest = "//" .. server .. "/" .. share, tail
    elseif folder:sub(1, 1) == "/" then current, rest = "/", folder:sub(2) end
    for segment in rest:gmatch("[^/]+") do
        current = current == "" and segment or joinPath(current, segment)
        if isFolder == nil or not isFolder(current) then
            if makeFolder == nil then error("makefolder is unavailable for " .. current, 0) end
            local ok, err = pcall(makeFolder, current)
            if not ok and (isFolder == nil or not isFolder(current)) then error(err, 0) end
        end
    end
    return true
end

local function resolveStorage(override, hasOverride)
    local storage = Config._settings.Storage
    if hasOverride then storage = override end
    local valid, validationError = validateStorage(storage)
    if not valid then return nil, validationError end
    if storage == false then return MemoryStorage end
    if type(storage) == "table" then return storage end
    local read, write = Runtime.GetFileFunction("readfile"), Runtime.GetFileFunction("writefile")
    if read ~= nil and write ~= nil then return FileStorage end
    if read == nil and write == nil then return MemoryStorage end
    return nil, "incomplete filesystem API; use SetStorage(false) or a custom adapter"
end

local function location(name, options)
    options = type(options) == "table" and options or {}
    local folder = Config.GetFolder()
    if options.Folder ~= nil then
        local err
        folder, err = normalizeFolder(options.Folder)
        if folder == nil then return nil, err end
    end
    local storage, err = resolveStorage(options.Storage, options.Storage ~= nil)
    if storage == nil then return nil, err end
    local safeName = sanitizePathSegment(name, Config._settings.File)
    return { Name = safeName, Folder = folder, Path = joinPath(folder, safeName .. ".json"), Storage = storage }
end

local function callStorage(storage, method, ...)
    local callback = storage[method]
    if type(callback) ~= "function" then return false, "storage does not support " .. method end
    local result = table.pack(pcall(callback, ...))
    if not result[1] then return false, tostring(result[2]) end
    if result[2] == false then return false, tostring(result[3] or method .. " failed") end
    return true, unpackValues(result, 2, result.n)
end

local function readStorage(target)
    if target.Storage.Exists ~= nil then
        local ok, exists, err = pcall(target.Storage.Exists, target.Path)
        if not ok then return false, tostring(exists) end
        if err ~= nil then return false, tostring(err) end
        if type(exists) ~= "boolean" then return false, "storage Exists must return a boolean" end
        if not exists then return true, nil, "config does not exist" end
    end
    return callStorage(target.Storage, "Read", target.Path)
end

local function copyConfigData(value)
    local seen, nodes = {}, 0
    local function copy(current, depth)
        if robloxType(current) ~= "table" then return current end
        if seen[current] ~= nil then return seen[current] end
        if depth >= LIMITS.MaxSerializationDepth then error("config event depth limit reached", 0) end
        local result = {}
        seen[current] = result
        for key, child in pairs(current) do
            nodes = nodes + 1
            if nodes > LIMITS.MaxSerializationNodes then error("config event node limit reached", 0) end
            result[key] = copy(child, depth + 1)
        end
        return result
    end
    return copy(value, 0)
end

local function emitApplied(info)
    if #Config._listeners == 0 then return end
    local ok, values, metadata = pcall(function()
        return copyConfigData(State.Snapshot()), copyConfigData(info)
    end)
    if not ok then reportError(values); return end
    Config._notifying = true
    dispatchSnapshot(table.clone(Config._listeners), function(callback)
        -- Owned observer threads may yield without suspending the config caller.
        CrispyLib.Tasks:Spawn(callback, copyConfigData(values), copyConfigData(metadata))
    end)
    Config._notifying = false
end

local function applyValues(snapshot, options)
    if applicationBusy() then return false, "a config application is already in progress" end
    if liveGuard("_readThread") or liveGuard("_writeThread") then return false, "config storage is busy" end
    if profileBusy() and Config._switchThread ~= coroutine.running() then return false, "profile switch is in progress" end
    options = type(options) == "table" and options or {}
    if options.Callbacks ~= nil and type(options.Callbacks) ~= "boolean" then return false, "Callbacks must be a boolean" end
    if options.Notify ~= nil and type(options.Notify) ~= "boolean" then return false, "Notify must be a boolean" end
    Config._applyThread = coroutine.running()
    local result = table.pack(pcall(function()
        local ok, err, detail = Registry.ApplyAll(snapshot)
        if not ok then return false, err end
        local callbacks = Config._settings.ApplyCallbacks
        if options.Callbacks ~= nil then callbacks = options.Callbacks end
        local info = { Operation = options.Operation or "apply", Name = options.Name,
            Profile = options.Profile or Config._profile, Folder = options.Folder or Config.GetFolder(),
            ChangedFlags = detail.ChangedFlags, NormalizedFlags = detail.NormalizedFlags, Applied = true,
            CallbackErrors = {}, Context = options.Context }
        for _, update in ipairs(detail.Updates) do
            Registry._loaded[update.Flag] = { Callbacks = callbacks, Context = info }
        end
        if callbacks then
            for _, update in ipairs(detail.Updates) do
                for _, entry in ipairs(update.Entries) do
                    if entry.Active and type(entry.Options.Apply) == "function" then
                        local applied, applyError = safeCall(entry.Options.Apply, State.Get(update.Flag), info)
                        if not applied then info.CallbackErrors[#info.CallbackErrors + 1] = update.Flag .. ": " .. tostring(applyError) end
                    end
                end
            end
        end
        if #info.CallbackErrors > 0 then return false, "config values applied; callback failed: " .. table.concat(info.CallbackErrors, "; "), info end
        return true, nil, info
    end))
    Config._applyThread = nil
    if not result[1] then return false, tostring(result[2]) end
    if result[4] ~= nil and options.Notify ~= false then emitApplied(result[4]) end
    return unpackValues(result, 2, result.n)
end

function Config.IsBusy()
    return applicationBusy() or profileBusy() or liveGuard("_readThread") or liveGuard("_writeThread")
        or next(Config._pendingAutoLoads) ~= nil
end

function Config.Configure(first, second)
    local options = methodArguments(Config, first, second)
    if type(options) ~= "table" then return false, "config options must be a table" end
    local settings = shallowCopy(Config._settings, 16)
    local name, version = CrispyLib._configName, Config.Version
    for key, value in pairs(options) do
        if key == "Folder" then
            local err
            settings.Folder, err = normalizeFolder(value)
            if err ~= nil then return false, err end
        elseif key == "File" then
            if type(value) ~= "string" or value == "" then return false, "File must be a non-empty string" end
            settings.File = sanitizePathSegment(value, "default")
        elseif key == "Name" then
            if type(value) ~= "string" or value == "" then return false, "Name must be a non-empty string" end
            name = sanitizePathSegment(value, "CrispyLib")
        elseif key == "Storage" then
            local ok, err = validateStorage(value)
            if not ok then return false, err end
            settings.Storage = value
        elseif key == "ApplyCallbacks" then
            if type(value) ~= "boolean" then return false, "ApplyCallbacks must be a boolean" end
            settings.ApplyCallbacks = value
        elseif key == "Version" then
            if not isFiniteNumber(value) or value < 0 or value % 1 ~= 0 then return false, "Version must be a non-negative integer" end
            version = value
        else return false, "unknown config option: " .. tostring(key) end
    end
    local scopeChanged = settings.Folder ~= Config._settings.Folder or settings.Storage ~= Config._settings.Storage
        or name ~= CrispyLib._configName
    local changed = scopeChanged or settings.File ~= Config._settings.File
        or settings.ApplyCallbacks ~= Config._settings.ApplyCallbacks or version ~= Config.Version
    if changed and Config.IsBusy() then return false, "config is busy" end
    if scopeChanged or settings.File ~= Config._settings.File then Config.StopAutoSave() end
    if scopeChanged then Config._profile = "default" end
    Config._settings, CrispyLib._configName, Config.Version = settings, name, version
    return true
end

function Config.SetFolder(first, second)
    local folder = methodArguments(Config, first, second)
    if folder == nil then
        if Config._settings.Folder == nil then return true end
        if Config.IsBusy() then return false, "config is busy" end
        Config.StopAutoSave(); Config._settings.Folder = nil; Config._profile = "default"; return true
    end
    return Config.Configure({ Folder = folder })
end
function Config.GetFolder()
    return Config._settings.Folder or ("CrispyLib/" .. sanitizePathSegment(CrispyLib._configName, "CrispyLib"))
end
function Config.SetStorage(first, second)
    local storage = methodArguments(Config, first, second)
    if storage == nil then
        if Config._settings.Storage == nil then return true end
        if Config.IsBusy() then return false, "config is busy" end
        Config.StopAutoSave(); Config._settings.Storage = nil; Config._profile = "default"; return true
    end
    return Config.Configure({ Storage = storage })
end
function Config.GetOptions()
    local result = shallowCopy(Config._settings, 16)
    result.Folder, result.Name, result.Version = Config.GetFolder(), CrispyLib._configName, Config.Version
    return result
end
function Config.GetPath(first, second)
    local name = methodArguments(Config, first, second)
    return joinPath(Config.GetFolder(), sanitizePathSegment(name, Config._settings.File) .. ".json")
end
function Config.OnApplied(first, second)
    local callback = methodArguments(Config, first, second)
    return subscribe(Config._listeners, callback, LIMITS.MaxListeners)
end
function Config.Register(first, second, third, fourth, fifth)
    local flag, getter, setter, options = methodArguments(Config, first, second, third, fourth, fifth)
    options = type(options) == "table" and shallowCopy(options, 32) or {}
    if options.Canonical == nil then options.Canonical = true end
    return Registry.Register(flag, getter, setter, options.Owner, options)
end
function Config.SetVersion(first, second)
    local version = methodArguments(Config, first, second)
    local parsed = math.floor(numberOr(version, Config.Version))
    if parsed < 0 then return false end
    return Config.Configure({ Version = parsed })
end
function Config.RegisterMigration(first, second, third, fourth)
    local from, target, callback = methodArguments(Config, first, second, third, fourth)
    if not isFiniteNumber(from) or not isFiniteNumber(target) or from < 0 or target <= from
        or from % 1 ~= 0 or target % 1 ~= 0 or type(callback) ~= "function" then return false end
    if #Config._migrations >= LIMITS.MaxMigrationSteps then return false end
    Config._migrations[#Config._migrations + 1] = { From = from, To = target, Callback = callback }
    table.sort(Config._migrations, function(left, right)
        if left.From == right.From then return left.To < right.To end
        return left.From < right.From
    end)
    return true
end
function Config.Migrate(first, second, third)
    local snapshot, fromVersion = methodArguments(Config, first, second, third)
    if type(snapshot) ~= "table" then return snapshot, false, "snapshot must be a table" end
    if not isFiniteNumber(fromVersion) or fromVersion < 0 or fromVersion % 1 ~= 0 then
        return snapshot, false, "invalid config version"
    end
    if fromVersion > Config.Version then return snapshot, false, "config was saved by a newer schema version" end
    local version = fromVersion
    for _ = 1, LIMITS.MaxMigrationSteps do
        if version == Config.Version then return snapshot, true end
        local selected
        for _, migration in ipairs(Config._migrations) do
            if migration.From == version and migration.To <= Config.Version then selected = migration; break end
        end
        if selected == nil then return snapshot, false, "no migration path from version " .. tostring(version) end
        local ok, value = safeCall(selected.Callback, snapshot, version, selected.To)
        if not ok or type(value) ~= "table" then return snapshot, false, "migration failed at version " .. tostring(version) end
        snapshot, version = value, selected.To
    end
    return snapshot, false, "migration step limit reached"
end
function Config.Ignore(first, second, third)
    local flag, ignored = methodArguments(Config, first, second, third)
    return Registry.Ignore(flag, ignored)
end
function Config.Snapshot() return Registry.GetAll() end
function Config.Apply(first, second, third)
    local snapshot, options = methodArguments(Config, first, second, third)
    return applyValues(snapshot, options)
end
function Config.ResetDefaults(first, second)
    local options = methodArguments(Config, first, second)
    options = type(options) == "table" and shallowCopy(options, 16) or {}
    options.Operation = "reset"
    return applyValues(Registry._defaults, options)
end

function Config.Encode(first, second, third)
    local snapshot, options = methodArguments(Config, first, second, third)
    options = type(options) == "table" and options or {}
    if snapshot == nil then
        local err
        snapshot, err = Config.Snapshot()
        if snapshot == nil then return nil, err end
    end
    if type(snapshot) ~= "table" then return nil, "snapshot must be a table" end
    local values, count = {}, 0
    for flag, value in pairs(snapshot) do
        count = count + 1
        if count > LIMITS.MaxSerializationNodes then return nil, "config value limit reached" end
        local normalized = normalizeFlag(flag)
        if normalized == nil or values[normalized] ~= nil then return nil, "invalid or duplicate config flag" end
        local encoded, err = Serializer.Encode(value)
        if err ~= nil then return nil, "cannot serialize flag " .. normalized .. ": " .. err end
        values[normalized] = encoded
    end
    local payload, err = Serializer.Encode(values)
    if payload == nil then return nil, err end
    if options.Bundle == true then
        payload = { __crispy = true, version = Config.Version, libraryVersion = VERSION,
            configName = sanitizePathSegment(CrispyLib._configName, "CrispyLib"), values = payload }
    end
    local ok, json = pcall(HttpService.JSONEncode, HttpService, payload)
    if not ok then return nil, tostring(json) end
    if #json > LIMITS.MaxHttpBodyBytes then return nil, "config output is too large" end
    return json
end
function Config.Decode(first, second, third)
    local input, options = methodArguments(Config, first, second, third)
    options = type(options) == "table" and options or {}
    local payload = input
    if type(input) == "string" then
        if #input > LIMITS.MaxHttpBodyBytes then return nil, "config input is too large" end
        local ok, value = pcall(HttpService.JSONDecode, HttpService, input)
        if not ok then return nil, tostring(value) end
        payload = value
    end
    if type(payload) ~= "table" then return nil, "config input must decode to a table" end
    local snapshot, metadata = payload, { Legacy = true }
    if payload.__crispy == true then
        if type(payload.values) ~= "table" then return nil, "config bundle has no values table" end
        local migrated, ok, err = Config.Migrate(payload.values, payload.version)
        if not ok then return nil, err end
        snapshot, metadata = migrated, { Legacy = false, Version = payload.version, ConfigName = payload.configName }
    elseif options.FromVersion ~= nil then
        local migrated, ok, err = Config.Migrate(snapshot, options.FromVersion)
        if not ok then return nil, err end
        snapshot = migrated
    end
    local values, count = {}, 0
    for flag, encoded in pairs(snapshot) do
        count = count + 1
        if count > LIMITS.MaxSerializationNodes then return nil, "config value limit reached" end
        local normalized = normalizeFlag(flag)
        if normalized == nil or values[normalized] ~= nil then return nil, "invalid or duplicate config flag" end
        local ok, value, err = pcall(Serializer.Decode, encoded)
        if not ok then err = tostring(value) end
        if err ~= nil then return nil, "cannot decode flag " .. normalized .. ": " .. err end
        local serialized, encodeError = Serializer.Encode(value)
        if encodeError ~= nil then return nil, "invalid flag " .. normalized .. ": " .. encodeError end
        values[normalized] = serialized
    end
    local copied, err = Serializer.Encode(values)
    if copied == nil then return nil, err end
    return copied, nil, metadata
end
function Config.Export()
    local json, err = Config.Encode()
    return json or "{}", err
end
function Config.ExportBundle()
    local json, err = Config.Encode(nil, { Bundle = true })
    return json or "{}", err
end
function Config.Import(first, second, third)
    local input, options = methodArguments(Config, first, second, third)
    options = type(options) == "table" and shallowCopy(options, 16) or {}
    local snapshot, err, metadata = Config.Decode(input, options)
    if snapshot == nil then return false, err end
    options.Operation = options.Operation or "import"
    options.Context = options.Context or metadata
    return applyValues(snapshot, options)
end

function Config.Save(first, second, third)
    local name, options = methodArguments(Config, first, second, third)
    if liveGuard("_readThread") or liveGuard("_writeThread") then return false, "config storage is busy" end
    if liveGuard("_applyThread") and Config._applyThread ~= coroutine.running() then return false, "config application is in progress" end
    if profileBusy() and Config._switchThread ~= coroutine.running() then return false, "profile switch is in progress" end
    local target, err = location(name, options)
    if target == nil then return false, err end
    local json, encodeError = Config.Encode(nil, { Bundle = true })
    if json == nil then return false, encodeError end
    Config._writeThread = coroutine.running()
    local result = table.pack(pcall(function()
        if target.Storage.EnsureFolder ~= nil then
            local ok, folderError = callStorage(target.Storage, "EnsureFolder", target.Folder)
            if not ok then return false, folderError end
        end
        local ok, writeError = callStorage(target.Storage, "Write", target.Path, json)
        if not ok then return false, writeError end
        Config._blockedAutoSaves[target.Path] = nil
        return true
    end))
    Config._writeThread = nil
    if not result[1] then return false, tostring(result[2]) end
    return unpackValues(result, 2, result.n)
end
function Config.Load(first, second, third)
    local name, options = methodArguments(Config, first, second, third)
    if applicationBusy() or liveGuard("_readThread") or liveGuard("_writeThread") then return false, "config is busy" end
    if profileBusy() and Config._switchThread ~= coroutine.running() then return false, "profile switch is in progress" end
    local target, locationError = location(name, options)
    if target == nil then return false, locationError end
    -- A cancelled/yielded read must not authorize overwriting unread settings.
    Config._blockedAutoSaves[target.Path] = true
    Config._readThread = coroutine.running()
    local readOk, contents, readError = readStorage(target)
    Config._readThread = nil
    if not readOk or contents == nil then
        local err = readOk and (readError or "config does not exist") or contents
        Config._blockedAutoSaves[target.Path] = err ~= "config does not exist" and true or nil
        return false, err
    end
    options = type(options) == "table" and shallowCopy(options, 16) or {}
    options.Operation, options.Name, options.Folder = options.Operation or "load", target.Name, target.Folder
    local result = table.pack(Config.Import(contents, options))
    if result[1] then Config._blockedAutoSaves[target.Path] = nil
    else Config._blockedAutoSaves[target.Path] = true end
    return unpackValues(result, 1, result.n)
end
function Config.List(first, second)
    local options = methodArguments(Config, first, second)
    if liveGuard("_readThread") or liveGuard("_writeThread") then return {}, "config storage is busy" end
    local target, err = location(nil, options)
    if target == nil then return {}, err end
    Config._readThread = coroutine.running()
    local ok, files = callStorage(target.Storage, "List", target.Folder)
    Config._readThread = nil
    if not ok then return {}, files end
    if type(files) ~= "table" then return {}, "storage List must return an array" end
    local names, seen, prefix = {}, {}, joinPath(target.Folder, "")
    for index = 1, math.min(#files, LIMITS.MaxRows) do
        local path = type(files[index]) == "string" and files[index]:gsub("\\", "/") or ""
        local filename = path
        if path:sub(1, #prefix) == prefix then filename = path:sub(#prefix + 1) end
        if not filename:find("/", 1, true) then
            local name = filename:match("^(.+)%.json$")
            if name ~= nil and not seen[name] then seen[name] = true; names[#names + 1] = name end
        end
    end
    table.sort(names)
    return names
end
function Config.Delete(first, second, third)
    local name, options = methodArguments(Config, first, second, third)
    if name == nil then return false, "config name is required" end
    if Config.IsBusy() then return false, "config is busy" end
    local target, err = location(name, options)
    if target == nil then return false, err end
    Config._writeThread = coroutine.running()
    local ok, deleteError = callStorage(target.Storage, "Delete", target.Path)
    Config._writeThread = nil
    if not ok then return false, deleteError end
    Config._blockedAutoSaves[target.Path] = nil
    return true
end
function Config.GetProfile() return Config._profile end
function Config.SetProfile(first, second, third)
    local name, options = methodArguments(Config, first, second, third)
    if type(options) == "table" then
        if options.Folder ~= nil or options.Storage ~= nil then
            return false, "set the config folder/storage before switching profiles"
        end
        if options.Callbacks ~= nil and type(options.Callbacks) ~= "boolean" then return false, "Callbacks must be a boolean" end
        if options.Notify ~= nil and type(options.Notify) ~= "boolean" then return false, "Notify must be a boolean" end
    end
    local requested = sanitizePathSegment(name, "")
    if requested == "" then return false, "profile name is required" end
    if profileBusy() or applicationBusy() or liveGuard("_readThread") or liveGuard("_writeThread") then
        return false, "a config operation is already in progress"
    end
    Config._switching, Config._switchThread = true, coroutine.running()
    local previousProfile, previousValues = Config._profile, State.Snapshot()
    local previousLoaded = table.clone(Registry._loaded)
    Config._switchValues, Config._switchLoaded = previousValues, previousLoaded
    local applyOptions = type(options) == "table" and shallowCopy(options, 16) or {}
    applyOptions.Operation, applyOptions.Profile, applyOptions.Notify = "profile", requested, false
    local result = table.pack(pcall(function()
        local saved, saveError = Config.Save("profile_" .. previousProfile)
        if not saved then return false, saveError end
        local loaded, loadError, info = Config.Load("profile_" .. requested, applyOptions)
        if not loaded and loadError == "config does not exist" then
            local snapshot, snapshotError = Config.Snapshot()
            if snapshot == nil then return false, snapshotError end
            loaded, loadError, info = applyValues(snapshot, applyOptions)
        end
        if not loaded then return false, loadError, info end
        Config._profile = requested
        return true, nil, info
    end))
    if not result[1] or not result[2] then
        Config._profile = previousProfile
        Registry._loaded = previousLoaded
        local restoreOk, restored, restoreError = pcall(State._restore, previousValues)
        if not restoreOk or not restored then
            result = table.pack(true, false, "profile rollback failed: " .. tostring(restoreError or restored))
        elseif result[4] ~= nil then result[4].StateRolledBack = true end
    end
    Config._switching, Config._switchThread = false, nil
    Config._switchValues, Config._switchLoaded = nil, nil
    if not result[1] then return false, tostring(result[2]) end
    if result[2] and result[4] and (type(options) ~= "table" or options.Notify ~= false) then emitApplied(result[4]) end
    return unpackValues(result, 2, result.n)
end
function Config.ListProfiles()
    local names, err = Config.List()
    local profiles, hasDefault = {}, false
    for _, name in ipairs(names) do
        local profile = name:match("^profile_(.+)$")
        if profile ~= nil then profiles[#profiles + 1] = profile; hasDefault = hasDefault or profile == "default" end
    end
    if not hasDefault then table.insert(profiles, 1, "default") end
    return profiles, err
end
function Config.DeleteProfile(first, second)
    local name = sanitizePathSegment(methodArguments(Config, first, second), "")
    if name == "" or name == "default" or name == Config._profile then return false, "cannot delete the default or active profile" end
    return Config.Delete("profile_" .. name)
end
function Config.AutoSave(first, second, third)
    local interval, name = methodArguments(Config, first, second, third)
    Config.StopAutoSave()
    local period, startedAt = math.max(numberOr(interval, 30), 5), os.clock()
    local saveName, firstSave = sanitizePathSegment(name, Config._settings.File), true
    Config._autoSaveToken = CrispyLib.Tasks:Loop(period, function()
        if firstSave and os.clock() - startedAt < period then return end
        if Config.IsBusy() or Config._blockedAutoSaves[Config.GetPath(saveName)] or next(Registry._defaults) == nil then return end
        firstSave = false
        local ok, err = Config.Save(saveName)
        if not ok then reportError("autosave failed: " .. tostring(err)) end
    end)
    return Config._autoSaveToken
end
function Config.StopAutoSave()
    if Config._autoSaveToken ~= nil then CrispyLib.Tasks:Cancel(Config._autoSaveToken); Config._autoSaveToken = nil end
end
function Config._queueAutoLoad(group, name)
    local target, err = location(name)
    if target == nil then reportError(err); return nil end
    local marker = {}
    Config._pendingAutoLoads[marker] = true
    Config._blockedAutoSaves[target.Path] = true
    local _, accepted = group:Add(marker, function() Config._pendingAutoLoads[marker] = nil end)
    if not accepted then return nil end
    local token = group:Delay(0, function()
        local result = table.pack(pcall(Config.Load, target.Name, { Folder = target.Folder, Storage = target.Storage }))
        Config._pendingAutoLoads[marker] = nil
        group:_forget(marker)
        local ok, loadError = result[2], result[3]
        if not result[1] then ok, loadError = false, result[2] end
        if not ok and loadError ~= "config does not exist" then reportError("autoload failed: " .. tostring(loadError)) end
    end)
    if token == nil then group:Cancel(marker) end
    return token
end
end


function Config.CreateProfileUI(tab)
    if type(tab) ~= "table" or type(tab.AddDropdown) ~= "function" then
        reportError("Config.CreateProfileUI requires a Tab")
        return nil
    end

    local dropdown
    dropdown = tab:AddDropdown({
        Name = "Profile",
        Description = "Switch or save configuration profiles",
        Options = Config.ListProfiles(),
        Default = Config.GetProfile(),
        Callback = function(profile)
            local ok, err = Config.SetProfile(profile)
            if ok then
                CrispyLib.Notify({
                    Title = "Profile switched",
                    Description = "Active profile: " .. tostring(profile),
                    Type = "success",
                    Duration = 3,
                })
            else
                dropdown:Set(Config.GetProfile(), true)
                reportError(err)
            end
        end,
    })
    tab:AddButton({
        Name = "Save Profile",
        Description = "Save the current values to the active profile",
        Callback = function()
            Config.Save("profile_" .. Config.GetProfile())
        end,
    })
    tab:AddButton({
        Name = "New Profile",
        Description = "Create a numbered profile",
        Callback = function()
            local profile = "Profile " .. tostring(#Config.ListProfiles() + 1)
            if Config.SetProfile(profile) then
                dropdown:AddItem(profile)
                dropdown:Set(profile, true)
            end
        end,
    })
    return dropdown
end

function CrispyLib.SafeRun(first, ...)
    local callback
    local arguments
    if first == CrispyLib then
        callback = select(1, ...)
        arguments = table.pack(select(2, ...))
    else
        callback = first
        arguments = table.pack(...)
    end

    local results = table.pack(safeCall(callback, unpackValues(arguments, 1, arguments.n)))
    if not results[1] and type(CrispyLib.Notify) == "function" then
        CrispyLib.Notify({
            Title = "Script Error",
            Description = tostring(results[2]):sub(1, 240),
            Type = "error",
            Duration = 6,
        })
    end
    return unpackValues(results, 1, results.n)
end

local HTTP = {}
CrispyLib.HTTP = HTTP

local function validateHttpUrl(url)
    if type(url) ~= "string" or #url > 4096 then
        return false, "URL must be a string no longer than 4096 bytes"
    end
    if not url:match("^https?://") then
        return false, "only http:// and https:// URLs are supported"
    end
    return true
end

local function responseBody(response)
    if type(response) ~= "table" then
        return tostring(response or "")
    end
    local body = response.Body
    if body == nil then
        body = response.body
    end
    return tostring(body or "")
end

local function responseStatus(response)
    if type(response) ~= "table" then
        return 200
    end
    return tonumber(response.StatusCode or response.Status or response.status_code) or 0
end

local function finishHttp(callback, body, err, response)
    if type(callback) == "function" then
        safeCall(callback, body, err, response)
    end
end

function HTTP.Get(first, second, third)
    local url, callback = methodArguments(HTTP, first, second, third)
    local valid, validationError = validateHttpUrl(url)
    if not valid then
        finishHttp(callback, nil, validationError, nil)
        return nil
    end

    return CrispyLib.Tasks:Spawn(function()
        local requestFunction = Runtime.GetRequestFunction()
        if requestFunction ~= nil then
            local ok, response = pcall(requestFunction, {
                Url = url,
                Method = "GET",
                Headers = { ["Accept"] = "*/*" },
            })
            if not ok then
                finishHttp(callback, nil, response, nil)
                return
            end

            local body = responseBody(response)
            local status = responseStatus(response)
            if #body > LIMITS.MaxHttpBodyBytes then
                finishHttp(callback, nil, "HTTP response is too large", response)
            elseif status < 200 or status >= 300 then
                finishHttp(callback, nil, "HTTP status " .. tostring(status), response)
            else
                finishHttp(callback, body, nil, response)
            end
            return
        end

        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)
        if not ok then
            finishHttp(callback, nil, body, nil)
        elseif #tostring(body) > LIMITS.MaxHttpBodyBytes then
            finishHttp(callback, nil, "HTTP response is too large", nil)
        else
            finishHttp(callback, tostring(body), nil, nil)
        end
    end)
end

function HTTP.Post(first, second, third, fourth)
    local url, data, callback = methodArguments(HTTP, first, second, third, fourth)
    local valid, validationError = validateHttpUrl(url)
    if not valid then
        finishHttp(callback, nil, validationError, nil)
        return nil
    end

    local requestFunction = Runtime.GetRequestFunction()
    if requestFunction == nil then
        finishHttp(callback, nil, "no executor HTTP request API is available", nil)
        return nil
    end

    local body
    if type(data) == "table" then
        local encodeOk, encoded = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if not encodeOk then
            finishHttp(callback, nil, encoded, nil)
            return nil
        end
        body = encoded
    else
        body = tostring(data or "")
    end
    if #body > LIMITS.MaxHttpBodyBytes then
        finishHttp(callback, nil, "HTTP request body is too large", nil)
        return nil
    end

    return CrispyLib.Tasks:Spawn(function()
        local ok, response = pcall(requestFunction, {
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
        if not ok then
            finishHttp(callback, nil, response, nil)
            return
        end

        local status = responseStatus(response)
        local resultBody = responseBody(response)
        if #resultBody > LIMITS.MaxHttpBodyBytes then
            finishHttp(callback, nil, "HTTP response is too large", response)
        elseif status < 200 or status >= 300 then
            finishHttp(callback, nil, "HTTP status " .. tostring(status), response)
        else
            finishHttp(callback, resultBody, nil, response)
        end
    end)
end

function HTTP.Webhook(first, second, third, fourth)
    local url, message, options = methodArguments(HTTP, first, second, third, fourth)
    options = type(options) == "table" and options or {}

    local payload = {
        username = normalizeText(options.Username, "CrispyLib"),
        avatar_url = normalizeText(options.Avatar, ""),
    }
    if type(message) == "table" then
        payload.embeds = { message }
    else
        payload.content = normalizeText(message, "")
        if type(options.Embeds) == "table" then
            payload.embeds = options.Embeds
        end
    end
    return HTTP.Post(url, payload, options.Callback)
end

local Updater = {}
CrispyLib.Updater = Updater

local function splitVersionSuffix(suffix)
    local identifiers = {}
    if suffix == "" then return identifiers end
    local startIndex = 1
    for index = 1, 16 do
        local separator = suffix:find(".", startIndex, true)
        local endIndex = separator == nil and #suffix or separator - 1
        if endIndex < startIndex then return nil end
        identifiers[index] = suffix:sub(startIndex, endIndex)
        if separator == nil then return identifiers end
        startIndex = separator + 1
    end
    return nil
end

local function parseVersion(version)
    local text = normalizeText(version, "0")
    local core, suffix = text:match("^%s*[vV]?([%d%.]+)%-?([%w%.%-]*)%s*$")
    if core == nil or core:sub(-1) == "." or core:find("..", 1, true) ~= nil then
        return nil
    end

    local parts = {}
    local count = 0
    for piece in core:gmatch("(%d+)") do
        count = count + 1
        if count > 8 then
            return nil
        end
        parts[count] = tonumber(piece) or 0
    end
    if #parts == 0 then
        return nil
    end
    if splitVersionSuffix(suffix or "") == nil then return nil end
    return parts, suffix or ""
end

local function compareNumericIdentifiers(left, right)
    local normalizedLeft = left:gsub("^0+", "")
    local normalizedRight = right:gsub("^0+", "")
    if normalizedLeft == "" then normalizedLeft = "0" end
    if normalizedRight == "" then normalizedRight = "0" end
    if #normalizedLeft ~= #normalizedRight then return #normalizedLeft < #normalizedRight and -1 or 1 end
    if normalizedLeft == normalizedRight then return 0 end
    return normalizedLeft < normalizedRight and -1 or 1
end

local function compareVersionSuffixes(leftSuffix, rightSuffix)
    if leftSuffix == rightSuffix then return 0 end
    if leftSuffix == "" then return 1 end
    if rightSuffix == "" then return -1 end
    local leftIdentifiers = splitVersionSuffix(leftSuffix)
    local rightIdentifiers = splitVersionSuffix(rightSuffix)
    if leftIdentifiers == nil or rightIdentifiers == nil then return nil end
    for index = 1, 16 do
        local left, right = leftIdentifiers[index], rightIdentifiers[index]
        if left == nil or right == nil then
            if left == right then return 0 end
            return left == nil and -1 or 1
        end
        local leftNumeric = left:match("^%d+$") ~= nil
        local rightNumeric = right:match("^%d+$") ~= nil
        if leftNumeric and rightNumeric then
            local comparison = compareNumericIdentifiers(left, right)
            if comparison ~= 0 then return comparison end
        elseif leftNumeric ~= rightNumeric then
            return leftNumeric and -1 or 1
        elseif left ~= right then
            return left < right and -1 or 1
        end
    end
    return nil
end

local function compareVersions(left, right)
    local leftParts, leftSuffix = parseVersion(left)
    local rightParts, rightSuffix = parseVersion(right)
    if leftParts == nil or rightParts == nil then
        return nil
    end

    for index = 1, 8 do
        local leftValue = leftParts[index] or 0
        local rightValue = rightParts[index] or 0
        if leftValue < rightValue then
            return -1
        end
        if leftValue > rightValue then
            return 1
        end
    end
    return compareVersionSuffixes(leftSuffix, rightSuffix)
end

function Updater.Check(first, second, third, fourth)
    local url, currentVersion, callback = methodArguments(Updater, first, second, third, fourth)
    if type(callback) ~= "function" then
        callback = function() end
    end

    return HTTP.Get(url, function(body, err)
        if err ~= nil then
            safeCall(callback, false, nil, err)
            return
        end
        local remote = tostring(body or ""):match("^%s*[vV]?([%d%.]+[%w%.%-]*)%s*$")
        if remote == nil then
            safeCall(callback, false, nil, "invalid remote version format")
            return
        end
        if parseVersion(remote) == nil then
            safeCall(callback, false, remote, "invalid remote version format")
            return
        end
        local comparison = compareVersions(remote, currentVersion)
        if comparison == nil then
            safeCall(callback, false, remote, "invalid current version format")
            return
        end
        safeCall(callback, comparison > 0, remote, nil)
    end)
end

local function executeDownloadedUpdate(source, remote, options)
    if type(options.BeforeExecute) == "function" then
        local approved, result = safeCall(options.BeforeExecute, source, remote)
        if not approved or result == false then return end
    end
    local loader = getGlobal("loadstring")
    if type(loader) ~= "function" then
        reportError("loadstring is unavailable")
        return
    end
    local loadOk, chunkOrError, compileError = pcall(loader, source, "@CrispyLibUpdate")
    if not loadOk then loadOk, chunkOrError, compileError = pcall(loader, source) end
    if not loadOk or type(chunkOrError) ~= "function" then
        reportError("update compile failed: " .. tostring(compileError or chunkOrError))
        return
    end
    CrispyLib.Tasks:Spawn(chunkOrError)
end

local function downloadAndExecuteUpdate(scriptUrl, remote, options)
    HTTP.Get(scriptUrl, function(source, downloadError)
        if downloadError ~= nil then
            reportError("update download failed: " .. tostring(downloadError))
            return
        end
        executeDownloadedUpdate(source, remote, options)
    end)
end

local function handleAvailableUpdate(scriptUrl, remote, options)
    CrispyLib.Notify({
        Title = "Update Available",
        Description = "Version " .. tostring(remote) .. " is available. Reloading...",
        Type = "info",
        Duration = 4,
    })
    CrispyLib.Tasks:Delay(numberOr(options.Delay, 1.5), function()
        downloadAndExecuteUpdate(scriptUrl, remote, options)
    end)
end

function Updater.AutoUpdate(first, second, third, fourth)
    local scriptUrl, currentVersion, options = methodArguments(Updater, first, second, third, fourth)
    options = type(options) == "table" and options or {}

    local valid, validationError = validateHttpUrl(scriptUrl)
    if not valid then
        reportError(validationError)
        return nil
    end
    local versionUrl = options.VersionUrl or (scriptUrl .. ".version")
    local versionUrlValid, versionUrlError = validateHttpUrl(versionUrl)
    if not versionUrlValid then
        reportError(versionUrlError)
        return nil
    end
    return Updater.Check(versionUrl, currentVersion, function(isNewer, remote, checkError)
        if checkError ~= nil then
            reportError("update check failed: " .. tostring(checkError))
            return
        end
        if isNewer then handleAvailableUpdate(scriptUrl, remote, options) end
    end)
end

local System = {
    _fps = 0,
    _lastDelta = 1 / 60,
    _statsHandle = nil,
}
CrispyLib.System = System

local function startFpsSampler()
    local elapsed = 0
    local frames = 0
    CrispyLib.Tasks:Connect(RunService.RenderStepped, function(deltaTime)
        if deltaTime > 0 then
            System._lastDelta = deltaTime
        end
        elapsed = elapsed + deltaTime
        frames = frames + 1
        if elapsed >= 0.5 then
            System._fps = math.floor((frames / elapsed) + 0.5)
            elapsed = 0
            frames = 0
        end
    end)
end

startFpsSampler()

function System.FPS()
    if System._fps > 0 then
        return System._fps
    end
    return math.floor((1 / math.max(System._lastDelta, 0.0001)) + 0.5)
end

function System.Ping()
    local ok, value = pcall(function()
        local network = Stats.Network
        local item = network and network.ServerStatsItem and network.ServerStatsItem["Data Ping"]
        if item == nil then
            return nil
        end
        return item:GetValue()
    end)
    if ok and isFiniteNumber(value) then
        return math.floor(value + 0.5)
    end
    return -1
end

function System.Memory()
    local ok, value = pcall(function()
        return Stats:GetTotalMemoryUsageMb()
    end)
    if ok and isFiniteNumber(value) then
        return math.floor((value * 10) + 0.5) / 10
    end
    return 0
end

function System.GetExecutor()
    local identifiers = { "identifyexecutor", "getexecutorname" }
    for index = 1, #identifiers do
        local identify = getGlobal(identifiers[index])
        if type(identify) == "function" then
            local ok, name, version = pcall(identify)
            if ok and name ~= nil then
                if version ~= nil and tostring(version) ~= "" then
                    return tostring(name), tostring(version)
                end
                return tostring(name)
            end
        end
    end

    local fingerprints = {
        { Key = "KRNL_LOADED", Name = "Krnl" },
        { Key = "syn", Name = "Synapse" },
        { Key = "DELTA_EXECUTOR", Name = "Delta" },
        { Key = "Fluxus", Name = "Fluxus" },
        { Key = "MACSPLOIT_GLOBAL", Name = "MacSploit" },
    }
    for index = 1, #fingerprints do
        if getGlobal(fingerprints[index].Key) ~= nil then
            return fingerprints[index].Name
        end
    end
    return "Unknown"
end

function System.Capabilities()
    return Runtime.Capabilities()
end

function System.OnFPSDrop(threshold, callback)
    local floorValue = math.max(numberOr(threshold, 30), 1)
    if type(callback) ~= "function" then
        return function() end
    end

    local wasBelow = false
    local token = CrispyLib.Tasks:Loop(0.25, function()
        local fps = System.FPS()
        local isBelow = fps < floorValue
        if isBelow and not wasBelow then
            safeCall(callback, fps, floorValue)
        end
        wasBelow = isBelow
    end)
    return function()
        CrispyLib.Tasks:Cancel(token)
    end
end

local function clampedDragPosition(target, positionStart, absoluteStart, pointerDelta, viewport, origin)
    origin = origin or Vector2.new(0, 0)
    local size = target.AbsoluteSize
    local x = clamp(absoluteStart.X + pointerDelta.X, origin.X, origin.X + math.max(0, viewport.X - size.X))
    local y = clamp(absoluteStart.Y + pointerDelta.Y, origin.Y, origin.Y + math.max(0, viewport.Y - size.Y))
    return UDim2.new(
        positionStart.X.Scale, positionStart.X.Offset + x - absoluteStart.X,
        positionStart.Y.Scale, positionStart.Y.Offset + y - absoluteStart.Y
    )
end

local function attachSimpleDrag(group, handle, target)
    local dragging = false
    local inputType
    local activeInput
    local pointerStart = Vector2.new(0, 0)
    local targetPositionStart = target.Position
    local targetAbsoluteStart = target.AbsolutePosition

    local function pointerPosition(input, kind)
        if kind == Enum.UserInputType.MouseButton1 then
            return UserInputService:GetMouseLocation()
        end
        return Vector2.new(input.Position.X, input.Position.Y)
    end

    group:Connect(handle.InputBegan, function(input)
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
            return
        end
        if dragging or MobileUI.InteractiveAt(handle, pointerPosition(input, kind)) then return end
        dragging = true
        inputType = kind
        activeInput = input
        pointerStart = pointerPosition(input, kind)
        targetPositionStart = target.Position
        targetAbsoluteStart = target.AbsolutePosition
    end)
    group:Connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        local kind = input.UserInputType
        if inputType == Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.MouseMovement then
            return
        end
        if inputType == Enum.UserInputType.Touch and input ~= activeInput then
            return
        end
        local origin, viewport = MobileUI.Bounds(target:FindFirstAncestorOfClass("ScreenGui"))
        local delta = pointerPosition(input, inputType) - pointerStart
        target.Position = clampedDragPosition(target, targetPositionStart, targetAbsoluteStart, delta, viewport, origin)
    end)
    group:Connect(UserInputService.InputEnded, function(input)
        local matches = inputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1
            or input == activeInput
        if matches then
            dragging = false
            inputType = nil
            activeInput = nil
        end
    end)
    group:Connect(UserInputService.WindowFocusReleased, function()
        dragging, inputType, activeInput = false, nil, nil
    end)
end

local function makeStatLabel(parent, position, color)
    return UI.Create("TextLabel", {
        Size = UDim2.new(0, 62, 1, 0),
        Position = UDim2.new(0, position, 0, 0),
        BackgroundTransparency = 1,
        Text = "--",
        TextColor3 = color,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 12,
        Parent = parent,
    })
end

local function createStatsBarSurface(group, config)
    local screenGui = UI.Create("ScreenGui", {
        Name = "CrispyLib_StatsBar",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 500,
    })
    local parentOk, parentError = Runtime.ParentScreenGui(screenGui)
    if not parentOk then
        screenGui:Destroy()
        group:Destroy()
        reportError(parentError)
        return nil
    end

    local bar = UI.Create("Frame", {
        Size = UDim2.fromOffset(202, 28),
        Position = config.Position or UDim2.new(1, -212, 0, 10),
        BackgroundTransparency = clamp(numberOr(config.Transparency, 0.12), 0, 1),
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = screenGui,
        Theme = { BackgroundColor3 = "TitleBarBg" },
    })
    UI.Round(bar, 12)
    UI.Stroke(bar, nil, 1, 0.48)
    UI.Gradient(bar, "PanelGradientStart", "PanelGradientEnd", 110, 0.12)
    local fpsLabel = makeStatLabel(bar, 4, Color3.fromRGB(48, 209, 88))
    local pingLabel = makeStatLabel(bar, 69, Color3.fromRGB(255, 189, 46))
    local memoryLabel = makeStatLabel(bar, 134, Color3.fromRGB(10, 132, 255))
    attachSimpleDrag(group, bar, bar)
    return screenGui, bar, fpsLabel, pingLabel, memoryLabel
end

local function updateStatsBar(fpsLabel, pingLabel, memoryLabel)
    local fps, ping, memory = System.FPS(), System.Ping(), System.Memory()
    fpsLabel.Text = tostring(fps) .. " FPS"
    pingLabel.Text = ping >= 0 and (tostring(ping) .. " ms") or "-- ms"
    memoryLabel.Text = tostring(memory) .. " MB"
    fpsLabel.TextColor3 = fps >= 55 and Color3.fromRGB(48, 209, 88)
        or (fps >= 30 and Color3.fromRGB(255, 189, 46) or Color3.fromRGB(255, 69, 58))
    if ping >= 0 then
        pingLabel.TextColor3 = ping <= 80 and Color3.fromRGB(48, 209, 88)
            or (ping <= 150 and Color3.fromRGB(255, 189, 46) or Color3.fromRGB(255, 69, 58))
    end
end

local function createStatsBarHandle(group, screenGui, bar)
    local handle = { Instance = screenGui, _destroyed = false }
    function handle:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        group:Destroy()
        if screenGui.Parent ~= nil then
            screenGui:Destroy()
        end
        if System._statsHandle == self then
            System._statsHandle = nil
        end
    end
    function handle:SetPosition(position)
        if not self._destroyed and robloxType(position) == "UDim2" then
            bar.Position = position
        end
        return self
    end
    function handle:Show()
        if not self._destroyed then screenGui.Enabled = true end
        return self
    end
    function handle:Hide()
        if not self._destroyed then screenGui.Enabled = false end
        return self
    end

    group:Connect(screenGui.Destroying, function()
        if not handle._destroyed then
            handle._destroyed = true
            if System._statsHandle == handle then System._statsHandle = nil end
            group:Destroy()
        end
    end)
    return handle
end

function System.StatsBar(first, second)
    local config = methodArguments(System, first, second)
    if System._statsHandle ~= nil then System._statsHandle:Destroy() end
    if config == "destroy" then return nil end
    config = type(config) == "table" and config or {}
    local group = TaskGroup.new("StatsBar")
    local screenGui, bar, fpsLabel, pingLabel, memoryLabel = createStatsBarSurface(group, config)
    if screenGui == nil then return nil end
    group:Loop(0.5, function() updateStatsBar(fpsLabel, pingLabel, memoryLabel) end)
    local handle = createStatsBarHandle(group, screenGui, bar)
    System._statsHandle = handle
    return handle
end

local Debug = {
    _log = {},
    _logMax = 200,
    _listeners = {},
}
CrispyLib.Debug = Debug

local DEBUG_LEVELS = {
    info = "INFO",
    warn = "WARN",
    error = "ERROR",
    success = "SUCCESS",
    debug = "DEBUG",
}

function Debug.Log(first, second, third)
    local message, requestedLevel = methodArguments(Debug, first, second, third)
    local level = DEBUG_LEVELS[tostring(requestedLevel or "info"):lower()] or "INFO"
    local timestamp = "--:--:--"
    pcall(function()
        timestamp = os.date("%H:%M:%S")
    end)

    local entry = {
        time = timestamp,
        level = level,
        msg = normalizeText(message, ""),
    }
    Debug._log[#Debug._log + 1] = entry
    local maximum = clamp(math.floor(numberOr(Debug._logMax, 200)), 1, LIMITS.MaxLogLines)
    if #Debug._log > maximum then
        table.remove(Debug._log, 1)
    end

    dispatchSnapshot(table.clone(Debug._listeners), safeCall, entry)
    return entry
end

function Debug.Export()
    local lines = {}
    local count = math.min(#Debug._log, LIMITS.MaxLogLines)
    for index = 1, count do
        local entry = Debug._log[index]
        lines[index] = "[" .. entry.time .. "] [" .. entry.level .. "] " .. entry.msg
    end
    local output = table.concat(lines, "\n")

    local writeFile = Runtime.GetFileFunction("writefile")
    local makeFolder = Runtime.GetFileFunction("makefolder")
    if writeFile ~= nil then
        if makeFolder ~= nil then
            pcall(makeFolder, "CrispyLib")
        end
        local ok, err = pcall(writeFile, "CrispyLib/debug_log.txt", output)
        if not ok then
            reportError(err)
        end
    end
    return output
end

local function formatFlagSnapshot()
    local snapshot = Config.Snapshot()
    local names = {}
    local count = 0
    for flag in pairs(snapshot) do
        count = count + 1
        if count > LIMITS.MaxRows then
            break
        end
        names[#names + 1] = flag
    end
    table.sort(names)

    local lines = {}
    for index = 1, #names do
        local flag = names[index]
        local value = State.Get(flag)
        lines[index] = flag .. " = " .. tostring(value)
    end
    return #lines > 0 and table.concat(lines, "\n") or "No registered flags."
end

function Debug.Panel(first, second)
    local tab = methodArguments(Debug, first, second)
    if type(tab) ~= "table" or type(tab.AddSection) ~= "function" then
        return nil
    end

    tab:AddSection({ Title = "Debug", Description = "Live state and captured callback errors" })
    local flagsView = tab:AddCodeView({ Name = "Flags", Height = 130, LineNumbers = false })
    local logBox = tab:AddLogBox({ Name = "Error Log", Height = 150, MaxLines = 200 })
    local function refreshFlags()
        flagsView:SetCode(formatFlagSnapshot())
    end
    tab:AddButton({ Name = "Refresh Flags", Callback = refreshFlags })
    tab:AddButton({
        Name = "Export Log",
        Callback = function()
            Debug.Export()
        end,
    })

    local group = tab:TaskGroup("DebugPanel")
    local unsubscribe = subscribe(Debug._listeners, function(entry)
        logBox:Write(entry.msg, entry.level:lower())
    end, LIMITS.MaxListeners)
    group:Add(unsubscribe)
    refreshFlags()
    return { Flags = flagsView, Log = logBox, Group = group }
end

local function createDebugWatchSurface(group)
    local screenGui = UI.Create("ScreenGui", {
        Name = "CrispyLib_Watch",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 600,
    })
    local parentOk, parentError = Runtime.ParentScreenGui(screenGui)
    if not parentOk then
        screenGui:Destroy()
        group:Destroy()
        reportError(parentError)
        return nil
    end
    local panel = UI.Create("Frame", {
        Size = UDim2.fromOffset(230, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 10, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = screenGui,
        Theme = { BackgroundColor3 = "TitleBarBg" },
    })
    UI.Round(panel, 12)
    UI.Stroke(panel, nil, 1, 0.48)
    UI.Gradient(panel, "PanelGradientStart", "PanelGradientEnd", 110, 0.12)
    UI.Padding(panel, 6, 8, 6, 8)
    UI.List(panel, Enum.FillDirection.Vertical, 2)
    attachSimpleDrag(group, panel, panel)
    return screenGui, panel
end

local function addDebugWatchFlag(group, panel, labels, flag, order)
    local row = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
        LayoutOrder = order, ZIndex = 11, Parent = panel,
    })
    UI.Create("TextLabel", {
        Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1,
        Text = flag, TextSize = 10, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = row,
        Theme = { TextColor3 = "SubtitleText" },
    })
    local valueLabel = UI.Create("TextLabel", {
        Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.new(0.55, 0, 0, 0),
        BackgroundTransparency = 1, Text = tostring(State.Get(flag)), TextSize = 10,
        Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 12, Parent = row, Theme = { TextColor3 = "Accent" },
    })
    labels[flag] = valueLabel
    group:Add(State.Subscribe(flag, function(value)
        if valueLabel.Parent ~= nil then
            valueLabel.Text = value == nil and "nil" or tostring(value)
        end
    end))
end

local function refreshDebugWatch(labels)
    local processed = 0
    for flag, label in pairs(labels) do
        processed = processed + 1
        if processed > 256 then break end
        if label.Parent ~= nil then
            local value = State.Get(flag)
            label.Text = value == nil and "nil" or tostring(value)
        end
    end
end

local function createDebugWatchHandle(group, screenGui)
    local handle = { Instance = screenGui, _destroyed = false }
    function handle:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        group:Destroy()
        if screenGui.Parent ~= nil then
            screenGui:Destroy()
        end
    end
    group:Connect(screenGui.Destroying, function()
        if not handle._destroyed then
            handle._destroyed = true
            group:Destroy()
        end
    end)
    return handle
end

function Debug.Watch(first, second, third)
    local flags, updateInterval = methodArguments(Debug, first, second, third)
    flags = type(flags) == "table" and flags or {}
    local group = TaskGroup.new("DebugWatch")
    local screenGui, panel = createDebugWatchSurface(group)
    if screenGui == nil then return nil end
    local labels = {}
    local count = math.min(#flags, 256)
    for index = 1, count do
        local flag = normalizeFlag(flags[index])
        if flag ~= nil and labels[flag] == nil then
            addDebugWatchFlag(group, panel, labels, flag, index)
        end
    end
    if numberOr(updateInterval, 0) > 0 then
        group:Loop(math.max(numberOr(updateInterval, 0.5), 0.1), function()
            refreshDebugWatch(labels)
        end)
    end
    return createDebugWatchHandle(group, screenGui)
end

CrispyLib.OnError(function(err)
    Debug.Log(err, "error")
end)

local NotificationManager = {
    _gui = nil,
    _container = nil,
    _active = {},
    _queue = {},
    _nextId = 0,
}

local NOTIFICATION_THEME_KEYS = {
    info = "NotificationInfo",
    success = "NotificationSuccess",
    warn = "NotificationWarning",
    warning = "NotificationWarning",
    error = "NotificationError",
}

local function ensureNotificationGui()
    if NotificationManager._gui ~= nil and NotificationManager._gui.Parent ~= nil then
        return true
    end
    if NotificationManager._gui ~= nil then
        local activeCount = math.min(#NotificationManager._active, DEFAULTS.NotificationLimit)
        for index = activeCount, 1, -1 do
            local handle = NotificationManager._active[index]
            if handle._group ~= nil then handle._group:Destroy() end
            handle._group = nil
            handle.Instance = nil
            handle._state = "dismissed"
            NotificationManager._active[index] = nil
        end
        NotificationManager._gui = nil
        NotificationManager._container = nil
    end

    local screenGui = UI.Create("ScreenGui", {
        Name = "CrispyLib_Notifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 1000,
    })
    local ok, err = Runtime.ParentScreenGui(screenGui)
    if not ok then
        screenGui:Destroy()
        return false, err
    end

    local container = UI.Create("Frame", {
        Size = UDim2.new(1, -24, 1, -24), AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        BackgroundTransparency = 1,
        ZIndex = Z_INDEX.Notification,
        Parent = screenGui,
    })
    UI.Create("UISizeConstraint", { MaxSize = Vector2.new(320, 10000), Parent = container })
    MobileUI.SafeScreen(screenGui, MobileUI.TouchMode("Auto"))
    UI.List(container, Enum.FillDirection.Vertical, 8)
    NotificationManager._gui = screenGui
    NotificationManager._container = container
    return true
end

local function notificationAccent(config)
    if robloxType(config.Color) == "Color3" then
        return config.Color
    end
    local key = NOTIFICATION_THEME_KEYS[tostring(config.Type or "info"):lower()] or "NotificationInfo"
    return ThemeManager.Values[key]
end

local function removeNotification(array, handle)
    return removeArrayValue(array, handle, LIMITS.MaxNotificationsQueued + DEFAULTS.NotificationLimit)
end

local pumpNotifications

local function finalizeNotification(handle)
    if handle._group ~= nil then
        handle._group:Destroy()
        handle._group = nil
    end
    if handle.Instance ~= nil and handle.Instance.Parent ~= nil then
        handle.Instance:Destroy()
    end
    handle.Instance = nil
    handle._state = "dismissed"
    removeNotification(NotificationManager._active, handle)
    if type(handle._config.OnDismiss) == "function" then
        safeCall(handle._config.OnDismiss, handle)
    end
    pumpNotifications()
end

local function dismissNotification(handle)
    if handle._state == "dismissed" or handle._state == "closing" then
        return handle
    end
    if handle._state == "queued" then
        removeNotification(NotificationManager._queue, handle)
        handle._state = "dismissed"
        return handle
    end

    handle._state = "closing"
    if handle.Instance ~= nil and handle.Instance.Parent ~= nil then
        UI.Tween(handle.Instance, {
            Position = UDim2.new(1, 24, 0, 0),
            BackgroundTransparency = 1,
        }, TWEEN.Medium)
    end
    handle._group:Delay(0.24, function()
        finalizeNotification(handle)
    end)
    return handle
end

local function createNotificationCard(handle)
    local card = UI.Create("Frame", {
        Name = "Notification_" .. tostring(handle.Id),
        Size = UDim2.new(1, 0, 0, 78),
        Position = UDim2.new(1, 24, 0, 0),
        BackgroundTransparency = ThemeManager.Values.PanelTransparency,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Notification + 1,
        Parent = NotificationManager._container,
        Theme = { BackgroundColor3 = "NotificationBg", BackgroundTransparency = "PanelTransparency" },
    })
    UI.Round(card, 14)
    UI.Stroke(card, nil, 1, 0.42)
    UI.Gradient(card, "SurfaceGradientStart", "SurfaceGradientEnd", 115, 0.1)
    return card
end

local function createNotificationText(card, config)
    local accent = UI.Create("Frame", {
        Size = UDim2.new(0, 3, 1, -18),
        Position = UDim2.new(0, 9, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = notificationAccent(config),
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Notification + 2,
        Parent = card,
    })
    UI.Round(accent, 2)
    local titleLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -50, 0, 20),
        Position = UDim2.new(0, 22, 0, 11),
        BackgroundTransparency = 1,
        Text = normalizeText(config.Title, "Notification"),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_INDEX.Notification + 2,
        Parent = card,
        Theme = { TextColor3 = "TitleText" },
    })
    local descriptionLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -44, 0, 31),
        Position = UDim2.new(0, 22, 0, 32),
        BackgroundTransparency = 1,
        Text = normalizeText(config.Description, ""),
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        ZIndex = Z_INDEX.Notification + 2,
        Parent = card,
        Theme = { TextColor3 = "DescText" },
    })
    return accent, titleLabel, descriptionLabel
end

local function createNotificationControls(card, config)
    local closeButton = UI.Create("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.new(1, -30, 0, 6),
        BackgroundTransparency = 1,
        Text = "x",
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = Z_INDEX.Notification + 3,
        Parent = card,
        Theme = { TextColor3 = "SubtitleText" },
    })
    local progressTrack = UI.Create("Frame", {
        Size = UDim2.new(1, -18, 0, 3),
        Position = UDim2.new(0, 9, 1, -6),
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Notification + 2,
        Parent = card,
        Theme = { BackgroundColor3 = "LoaderTrack" },
    })
    UI.Round(progressTrack, 2)
    local progressFill = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = notificationAccent(config),
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Notification + 3,
        Parent = progressTrack,
    })
    UI.Round(progressFill, 2)
    return closeButton, progressTrack, progressFill
end

local function buildNotification(handle)
    local config = handle._config
    local group = TaskGroup.new("Notification:" .. tostring(handle.Id))
    handle._group, handle._state = group, "visible"
    local card = createNotificationCard(handle)
    local accent, titleLabel, descriptionLabel = createNotificationText(card, config)
    local closeButton, progressTrack, progressFill = createNotificationControls(card, config)
    handle.Instance = card
    handle._titleLabel = titleLabel
    handle._descriptionLabel = descriptionLabel
    handle._accent = accent
    handle._progressFill = progressFill
    group:Connect(closeButton.Activated, function()
        dismissNotification(handle)
    end)
    UI.Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, TWEEN.Ease)

    local duration = clamp(numberOr(config.Duration, 4), 0, 120)
    if duration > 0 then
        UI.Tween(progressFill, { Size = UDim2.new(0, 0, 1, 0) }, TweenInfo.new(duration, Enum.EasingStyle.Linear))
        group:Delay(duration, function()
            dismissNotification(handle)
        end)
    else
        progressTrack.Visible = false
    end
end

pumpNotifications = function()
    local ready, err = ensureNotificationGui()
    if not ready then
        reportError(err)
        return
    end

    for _ = 1, DEFAULTS.NotificationLimit do
        if #NotificationManager._active >= DEFAULTS.NotificationLimit or #NotificationManager._queue == 0 then
            break
        end
        local handle = table.remove(NotificationManager._queue, 1)
        NotificationManager._active[#NotificationManager._active + 1] = handle
        buildNotification(handle)
    end
end

function CrispyLib.Notify(first, second)
    local config = normalizeConfig(first, second, CrispyLib)
    if type(first) == "string" then
        config = { Title = first }
    end
    NotificationManager._nextId = NotificationManager._nextId + 1
    local handle = {
        Id = NotificationManager._nextId,
        _config = shallowCopy(config, 64),
        _state = "queued",
    }

    function handle:Dismiss()
        return dismissNotification(self)
    end
    function handle:Update(patch)
        if type(patch) ~= "table" then
            return self
        end
        local processed = 0
        for key, value in pairs(patch) do
            processed = processed + 1
            if processed > 64 then break end
            self._config[key] = value
        end
        if self._state == "visible" then
            self._titleLabel.Text = normalizeText(self._config.Title, "Notification")
            self._descriptionLabel.Text = normalizeText(self._config.Description, "")
            local color = notificationAccent(self._config)
            self._accent.BackgroundColor3 = color
            self._progressFill.BackgroundColor3 = color
        end
        return self
    end
    function handle:IsVisible()
        return self._state == "visible"
    end

    if #NotificationManager._queue >= LIMITS.MaxNotificationsQueued then
        local oldest = table.remove(NotificationManager._queue, 1)
        if oldest ~= nil then
            oldest._state = "dismissed"
        end
    end
    NotificationManager._queue[#NotificationManager._queue + 1] = handle
    pumpNotifications()
    return handle
end

function NotificationManager.Destroy()
    local activeCount = math.min(#NotificationManager._active, DEFAULTS.NotificationLimit)
    for index = activeCount, 1, -1 do
        local handle = NotificationManager._active[index]
        if handle._group ~= nil then
            handle._group:Destroy()
        end
        if handle.Instance ~= nil and handle.Instance.Parent ~= nil then
            handle.Instance:Destroy()
        end
        handle._state = "dismissed"
        NotificationManager._active[index] = nil
    end
    local queuedCount = math.min(#NotificationManager._queue, LIMITS.MaxNotificationsQueued)
    for index = queuedCount, 1, -1 do
        NotificationManager._queue[index]._state = "dismissed"
        NotificationManager._queue[index] = nil
    end
    if NotificationManager._gui ~= nil and NotificationManager._gui.Parent ~= nil then
        NotificationManager._gui:Destroy()
    end
    NotificationManager._gui = nil
    NotificationManager._container = nil
end

local InputRouter = {}
InputRouter.__index = InputRouter

local function inputPosition2(input)
    local kind = input.UserInputType
    if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseMovement then
        -- Mouse button and movement InputObjects may use different inset origins.
        return UserInputService:GetMouseLocation()
    end
    return Vector2.new(input.Position.X, input.Position.Y)
end

function InputRouter.new(taskGroup)
    local self = setmetatable({
        _tasks = taskGroup,
        _pointer = nil,
        _keyCapture = nil,
        _keyBindings = {},
    }, InputRouter)

    taskGroup:Connect(UserInputService.InputChanged, function(input)
        self:_onInputChanged(input)
    end)
    taskGroup:Connect(UserInputService.InputEnded, function(input)
        self:_onInputEnded(input)
    end)
    taskGroup:Connect(UserInputService.InputBegan, function(input, processed)
        self:_onInputBegan(input, processed)
    end)
    taskGroup:Connect(UserInputService.WindowFocusReleased, function()
        self:CancelPointer()
        self:CancelCapture()
    end)
    return self
end

function InputRouter:BeginPointer(input, onMove, onEnd, owner, updateImmediately)
    local kind = input and input.UserInputType
    if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
        return false
    end
    if type(onMove) ~= "function" then
        return false
    end

    -- One pointer owns an interaction until it ends; a second finger cannot steal it.
    if self._pointer ~= nil then return false end
    self._pointer = {
        Input = input,
        Kind = kind,
        Owner = owner,
        OnMove = onMove,
        OnEnd = onEnd,
        Scroll = MobileUI.SuspendScroll(owner),
    }
    local pointer = self._pointer
    if type(input.GetPropertyChangedSignal) == "function" then
        pointer.EndConnection = self._tasks:Connect(input:GetPropertyChangedSignal("UserInputState"), function()
            if self._pointer == pointer and (input.UserInputState == Enum.UserInputState.End
                or input.UserInputState == Enum.UserInputState.Cancel) then self:_onInputEnded(input) end
        end)
    end
    if updateImmediately ~= false then safeCall(onMove, inputPosition2(input), input) end
    return true
end

function InputRouter:_onInputChanged(input)
    local pointer = self._pointer
    if pointer == nil then
        return
    end
    local kind = input.UserInputType
    if pointer.Kind == Enum.UserInputType.MouseButton1 then
        if kind ~= Enum.UserInputType.MouseMovement then
            return
        end
    elseif input ~= pointer.Input then
        return
    end
    safeCall(pointer.OnMove, inputPosition2(input), input)
end

function InputRouter:CancelPointer(owner)
    local pointer = self._pointer
    if pointer == nil or (owner ~= nil and pointer.Owner ~= owner) then
        return false
    end
    self._pointer = nil
    MobileUI.RestoreScroll(pointer.Scroll)
    if pointer.EndConnection ~= nil then self._tasks:Cancel(pointer.EndConnection) end
    if type(pointer.OnEnd) == "function" then
        safeCall(pointer.OnEnd, true)
    end
    return true
end

function InputRouter:_onInputEnded(input)
    local pointer = self._pointer
    if pointer == nil then
        return
    end
    local matches = pointer.Kind == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1
        or input == pointer.Input
    if not matches then
        return
    end

    self._pointer = nil
    local cancelled = input.UserInputState == Enum.UserInputState.Cancel
    if not cancelled then safeCall(pointer.OnMove, inputPosition2(input), input) end
    MobileUI.RestoreScroll(pointer.Scroll)
    if pointer.EndConnection ~= nil then self._tasks:Cancel(pointer.EndConnection) end
    if type(pointer.OnEnd) == "function" then safeCall(pointer.OnEnd, cancelled) end
end

function InputRouter:_onInputBegan(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    local capture = self._keyCapture
    if capture ~= nil then
        self._keyCapture = nil
        if input.KeyCode == Enum.KeyCode.Escape then
            if type(capture.OnCancel) == "function" then
                safeCall(capture.OnCancel)
            end
        else
            safeCall(capture.Callback, input.KeyCode)
        end
        return
    end
    if processed or UserInputService:GetFocusedTextBox() ~= nil then
        return
    end

    for _, binding in ipairs(table.clone(self._keyBindings)) do
        if binding.Active then
            local ok, key = safeCall(binding.GetKey)
            if ok and key == input.KeyCode then
                safeCall(binding.Callback, input.KeyCode)
            end
        end
    end
end

function InputRouter:CaptureKey(owner, callback, onCancel)
    if type(callback) ~= "function" then
        return false
    end
    if self._keyCapture ~= nil and type(self._keyCapture.OnCancel) == "function" then
        safeCall(self._keyCapture.OnCancel)
    end
    self._keyCapture = {
        Owner = owner,
        Callback = callback,
        OnCancel = onCancel,
    }
    return true
end

function InputRouter:CancelCapture(owner)
    if self._keyCapture == nil or (owner ~= nil and self._keyCapture.Owner ~= owner) then
        return false
    end
    local capture = self._keyCapture
    self._keyCapture = nil
    if type(capture.OnCancel) == "function" then
        safeCall(capture.OnCancel)
    end
    return true
end

function InputRouter:BindKey(owner, getKey, callback)
    if type(getKey) ~= "function" or type(callback) ~= "function" then
        return function() end
    end
    if #self._keyBindings >= LIMITS.MaxListeners then
        reportError("window key-binding limit reached")
        return function() end
    end

    local binding = {
        Owner = owner,
        GetKey = getKey,
        Callback = callback,
        Active = true,
    }
    self._keyBindings[#self._keyBindings + 1] = binding
    return function()
        if not binding.Active then
            return
        end
        binding.Active = false
        removeArrayValue(self._keyBindings, binding, LIMITS.MaxListeners)
    end
end

function InputRouter:Destroy()
    self:CancelPointer()
    self:CancelCapture()
    for index = math.min(#self._keyBindings, LIMITS.MaxListeners), 1, -1 do
        self._keyBindings[index].Active = false
        self._keyBindings[index] = nil
    end
end

local ComponentMethods = {}
ComponentMethods.__index = ComponentMethods

local function componentRootAlive(component)
    return not component._destroyed
        and robloxType(component._root) == "Instance"
        and component._root.Parent ~= nil
end

function ComponentMethods:Show()
    if componentRootAlive(self) then
        self._root.Visible = true
    end
    return self
end

function ComponentMethods:Hide()
    if componentRootAlive(self) then
        self._root.Visible = false
    end
    return self
end

function ComponentMethods:SetVisible(state)
    if componentRootAlive(self) then
        self._root.Visible = state == true
    end
    return self
end

function ComponentMethods:ToggleVisible()
    if componentRootAlive(self) then
        self._root.Visible = not self._root.Visible
    end
    return self
end

function ComponentMethods:IsVisible()
    return componentRootAlive(self) and self._root.Visible or false
end

function ComponentMethods:SetLabel(text)
    if self._label ~= nil and self._label.Parent ~= nil then
        self._label.Text = normalizeText(text, "")
        self:_refreshSearchText()
    end
    return self
end

function ComponentMethods:SetDescription(text)
    if self._description ~= nil and self._description.Parent ~= nil then
        self._description.Text = normalizeText(text, "")
        self:_refreshSearchText()
    end
    return self
end

function ComponentMethods:_refreshSearchText()
    local label = self._label and self._label.Text or ""
    local description = self._description and self._description.Text or ""
    self._searchText = (label .. " " .. description):lower()
end

function ComponentMethods:SetStyle(styles, persistent)
    CrispyLib.Style(self._root, styles, persistent)
    return self
end

function ComponentMethods:SetOpacity(opacity)
    UI.SetOpacity(self._root, opacity)
    return self
end

function ComponentMethods:SetTooltip(text)
    if self._tooltip ~= nil then
        self._tooltip:Destroy()
        self._tooltip = nil
    end
    if text == nil or text == "" or self._tab == nil then
        return self
    end
    self._tooltip = self._tab._window:_createTooltip(self._root, tostring(text), self._tasks)
    return self
end

function ComponentMethods:Connect(signal, callback)
    return self._tasks:Connect(signal, callback)
end

function ComponentMethods:TaskGroup(name)
    local group = TaskGroup.new(name or "ComponentTask")
    self._tasks:Add(group)
    return group
end

function ComponentMethods:OnDestroy(callback)
    if self._destroyed then return function() end end
    return subscribe(self._destroyCallbacks, callback, LIMITS.MaxListeners)
end

function ComponentMethods:OnChanged(callback)
    if self._destroyed then return function() end end
    if type(callback) ~= "function" then return function() end end
    local function ownedCallback(...)
        self._tasks:Spawn(callback, ...)
    end
    local unsubscribe
    if self.Flag ~= nil then
        unsubscribe = State.Subscribe(self.Flag, ownedCallback)
    else
        unsubscribe = subscribe(self._changeListeners, ownedCallback, LIMITS.MaxListeners)
    end
    self._tasks:Add(unsubscribe)
    return function()
        self._tasks:_forget(unsubscribe)
        unsubscribe()
    end
end

function ComponentMethods:_FireChanged(value, previous)
    dispatchSnapshot(table.clone(self._changeListeners), safeCall, value, previous)
end

function ComponentMethods:_publish(value, previous, callback, silent, stateValue)
    if valuesEqual(value, previous) then
        return false
    end
    if self.Flag ~= nil then
        local published = stateValue
        if published == nil then published = value end
        State.Set(self.Flag, published, self)
    else
        self:_FireChanged(value, previous)
    end
    if not silent and type(callback) == "function" then
        safeCall(callback, value)
    end
    return true
end

function ComponentMethods:Enable()
    if self._destroyed or self._enabled then
        return self
    end
    self._enabled = true
    if type(self._applyEnabled) == "function" then
        safeCall(self._applyEnabled, self, true)
    end
    return self
end

function ComponentMethods:Disable()
    if self._destroyed or not self._enabled then
        return self
    end
    self._enabled = false
    if type(self._applyEnabled) == "function" then
        safeCall(self._applyEnabled, self, false)
    end
    return self
end

function ComponentMethods:IsEnabled()
    return self._enabled
end

function ComponentMethods:DependsOn(other)
    if type(other) ~= "table" or type(other.Get) ~= "function" then
        return self
    end
    local function synchronize(value)
        if value then
            self:Enable()
        else
            self:Disable()
        end
    end
    local ok, value = safeCall(other.Get, other)
    if ok then
        synchronize(value)
    end
    if type(other.OnChanged) == "function" then
        self._tasks:Add(other:OnChanged(synchronize))
    end
    return self
end

function ComponentMethods:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    if self._unregisterFlag ~= nil then
        self._unregisterFlag()
        self._unregisterFlag = nil
    end
    if self._tab ~= nil then
        local inputRouter = self._tab._window and self._tab._window._input
        if inputRouter ~= nil then
            inputRouter:CancelPointer(self)
            inputRouter:CancelCapture(self)
        end
        if self._tab._tasks:IsAlive() then
            self._tab._tasks:_forget(self)
        end
        self._tab:_forgetComponent(self)
    end

    dispatchSnapshot(table.clone(self._destroyCallbacks), safeCall, self)
    clearSubscriptions(self._destroyCallbacks)
    clearSubscriptions(self._changeListeners)
    self._tasks:Destroy()
    if not self._externalDestroying and robloxType(self._root) == "Instance" and self._root.Parent ~= nil then
        self._root:Destroy()
    end
end

local function newComponent(tab, root, label, description, flag, config)
    local component = setmetatable({
        Instance = root,
        _root = root,
        _row = root,
        _label = label,
        _description = description,
        _tab = tab,
        _tasks = TaskGroup.new("Component"),
        _destroyCallbacks = {},
        _changeListeners = {},
        _destroyed = false,
        _enabled = true,
        Flag = normalizeFlag(flag),
        _configSettings = type(config) == "table" and config or {},
    }, ComponentMethods)
    component:_refreshSearchText()
    tab:_adoptComponent(component)
    MobileUI.AttachRow(component)

    component._tasks:Connect(root.Destroying, function()
        if not component._destroyed then
            component._externalDestroying = true
            component:Destroy()
        end
    end)
    return component
end

local function registerComponentFlag(component, getter, setter)
    if component.Flag == nil then return end
    local config = component._configSettings or {}
    local callback = config.Callback
    local options = { Canonical = true, Normalize = config.ConfigNormalize, Validate = config.ConfigValidate }
    if component._configKeybind then
        options.Normalize = component._configKeyNormalizer
    elseif config.ConfigCallbacks ~= false and type(callback) == "function" then
        options.Apply = function(value)
            if component._destroyed then return end
            if component._inputConfig ~= nil then return callback(value, false) end
            return callback(value)
        end
    end
    local unregister, err = Registry.Register(component.Flag, getter, setter, component, options)
    component._unregisterFlag = unregister
    if err ~= nil then reportError("cannot register config flag " .. component.Flag .. ": " .. err) end
    if component._tab and component._tab._window then
        component._tab._window:RegisterComponent(component.Flag, component)
    end
end

local WindowMethods = {}
WindowMethods.__index = WindowMethods
local TabMethods = {}
TabMethods.__index = TabMethods

local function screenGuiName(title)
    local safe = normalizeText(title, "CrispyLib"):gsub("[^%w_]", "")
    if safe == "" then
        safe = "Window"
    end
    return "CrispyLib_" .. safe:sub(1, 40)
end

local function viewportSize()
    local camera = Workspace.CurrentCamera
    if camera ~= nil then
        return camera.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function requestedWindowSize(config, root)
    local _, viewport = MobileUI.Bounds(root)
    return MobileUI.WindowSize(config.Size, viewport, nil, nil, MobileUI.TouchMode(config.MobileMode))
end

local function disabledControlSet(config)
    local result = {}
    local values = type(config.DisabledWindowControls) == "table" and config.DisabledWindowControls or {}
    local count = math.min(#values, 32)
    for index = 1, count do
        result[tostring(values[index]):lower()] = true
    end
    return result
end

local function createWindowScreenGui(title, config)
    local screenGui = UI.Create("ScreenGui", {
        Name = screenGuiName(title),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 999,
    })
    MobileUI.SafeScreen(screenGui, MobileUI.TouchMode(config.MobileMode))
    local ok, err = Runtime.ParentScreenGui(screenGui)
    if not ok then
        screenGui:Destroy()
        return nil, err
    end
    return screenGui
end

local function makeTrafficButton(parent, order, themeKey)
    local symbol = themeKey == "CloseButton" and "x"
        or (themeKey == "MinimizeButton" and "-" or "□")
    local button = UI.Create("TextButton", {
        Name = themeKey,
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Text = symbol,
        TextSize = 11,
        Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = Z_INDEX.TitleBar + 2,
        Parent = parent,
        Theme = {
            BackgroundColor3 = "InputBg",
            TextColor3 = themeKey,
        },
    })
    UI.Round(button, 9)
    UI.Stroke(button, nil, 1, 0.62)
    UI.Gradient(button, "PanelGradientStart", "PanelGradientEnd", 130, 0.08)
    return button
end

local function buildTrafficControls(window)
    local holder = UI.Create("Frame", {
        Size = UDim2.fromOffset(86, 26),
        Position = UDim2.new(0, 15, 0.5, -13),
        BackgroundTransparency = 1,
        ZIndex = Z_INDEX.TitleBar + 1,
        Parent = window._titleBar,
    })
    window._trafficHolder = holder
    UI.List(holder, Enum.FillDirection.Horizontal, 5)
    local closeButton = makeTrafficButton(holder, 1, "CloseButton")
    local minimizeButton = makeTrafficButton(holder, 2, "MinimizeButton")
    local maximizeButton = makeTrafficButton(holder, 3, "MaximizeButton")

    local disabled = window._disabledControls
    closeButton.Visible = not (disabled.exit or disabled.close)
    minimizeButton.Visible = not (disabled.minimize or disabled.minimise)
    maximizeButton.Visible = not (disabled.maximize or disabled.maximise)
    UI.Hover(window._tasks, closeButton, "InputBg", "DangerBg", "DangerHover")
    UI.Hover(window._tasks, minimizeButton, "InputBg", "RowHover", "ItemHover")
    UI.Hover(window._tasks, maximizeButton, "InputBg", "SuccessBg", "ItemHover")
    window._closeButton = closeButton
    window._minimizeButton = minimizeButton
    window._maximizeButton = maximizeButton
end

local function buildTitleIdentity(window, config)
    local titleHolder = UI.Create("Frame", {
        Size = UDim2.new(0, 260, 1, 0),
        Position = UDim2.new(0.5, -130, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = Z_INDEX.TitleBar + 1,
        Parent = window._titleBar,
    })
    window._titleHolder = titleHolder
    window._titleLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0.5, -18),
        BackgroundTransparency = 1,
        Text = window.Title,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_INDEX.TitleBar + 2,
        Parent = titleHolder,
        Theme = { TextColor3 = "TitleText" },
    })
    window._subtitleLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 13),
        Position = UDim2.new(0, 0, 0.5, 1),
        BackgroundTransparency = 1,
        Text = normalizeText(config.Subtitle or config.SubTitle, ""),
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_INDEX.TitleBar + 2,
        Parent = titleHolder,
        Theme = { TextColor3 = "SubtitleText" },
    })
end

local function buildSearchBox(window)
    local searchHolder = UI.Create("Frame", {
        Size = UDim2.fromOffset(140, 32),
        Position = UDim2.new(1, -154, 0.5, -16),
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.TitleBar + 1,
        Parent = window._titleBar,
        Theme = { BackgroundColor3 = "InputBg" },
    })
    UI.Round(searchHolder, 10)
    local stroke = UI.Stroke(searchHolder, nil, 1, 0.64)
    UI.Gradient(searchHolder, "PanelGradientStart", "PanelGradientEnd", 120, 0.08)
    UI.Create("TextLabel", {
        Size = UDim2.fromOffset(24, 32),
        Position = UDim2.fromOffset(4, 0),
        BackgroundTransparency = 1,
        Text = "⌕",
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        ZIndex = Z_INDEX.TitleBar + 2,
        Parent = searchHolder,
        Theme = { TextColor3 = "Placeholder" },
    })
    local searchBox = UI.Create("TextBox", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.fromOffset(28, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Search",
        ClearTextOnFocus = false,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.TitleBar + 2,
        Parent = searchHolder,
        Theme = { TextColor3 = "LabelText", PlaceholderColor3 = "Placeholder" },
    })
    window._searchHolder = searchHolder
    window._searchBox = searchBox
    window._tasks:Connect(searchBox.Focused, function()
        UI.Tween(stroke, { Color = ThemeManager.Values.FocusBorder }, TWEEN.Fast)
    end)
    window._tasks:Connect(searchBox.FocusLost, function()
        UI.Tween(stroke, { Color = ThemeManager.Values.Border }, TWEEN.Fast)
    end)
    window._tasks:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
        if window._activeTab ~= nil then
            window._activeTab:_search(searchBox.Text)
        end
    end)
end

local function buildWindowBody(window)
    local sidebar = UI.Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, DEFAULTS.SidebarWidth, 1, -DEFAULTS.TitleBarHeight),
        Position = UDim2.new(0, 0, 0, DEFAULTS.TitleBarHeight),
        BackgroundTransparency = ThemeManager.Values.PanelTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = Z_INDEX.Sidebar,
        Parent = window._surface,
        Theme = { BackgroundColor3 = "SidebarBg", BackgroundTransparency = "PanelTransparency" },
    })
    UI.RoundCorners(sidebar, DEFAULTS.SurfaceCornerRadius, {
        TopLeft = false, TopRight = false, BottomRight = false, BottomLeft = true,
    })
    UI.Gradient(sidebar, "PanelGradientStart", "PanelGradientEnd", 118, 0.05)
    local sidebarScroll = UI.ScrollingFrame(sidebar, Z_INDEX.Sidebar + 1)
    sidebarScroll.ScrollBarThickness = 0
    UI.Padding(sidebarScroll, 16, 12, 16, 12)
    local sidebarList = UI.Create("Frame", {
        Size = UDim2.new(1, -24, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = Z_INDEX.Sidebar + 1,
        Parent = sidebarScroll,
    })
    UI.List(sidebarList, Enum.FillDirection.Vertical, 5)

    local content = UI.Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -DEFAULTS.SidebarWidth, 1, -DEFAULTS.TitleBarHeight),
        Position = UDim2.new(0, DEFAULTS.SidebarWidth, 0, DEFAULTS.TitleBarHeight),
        BackgroundTransparency = ThemeManager.Values.ContentTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = Z_INDEX.Content,
        Parent = window._surface,
        Theme = { BackgroundColor3 = "ContentBg", BackgroundTransparency = "ContentTransparency" },
    })
    UI.RoundCorners(content, DEFAULTS.SurfaceCornerRadius, {
        TopLeft = false, TopRight = false, BottomRight = true, BottomLeft = false,
    })
    UI.Gradient(content, "WindowGradientStart", "WindowGradientEnd", 145, 0.04)
    local divider = UI.Create("Frame", {
        Name = "SidebarDivider",
        Size = UDim2.new(0, 1, 1, -DEFAULTS.TitleBarHeight),
        Position = UDim2.new(0, DEFAULTS.SidebarWidth - 1, 0, DEFAULTS.TitleBarHeight),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Sidebar + 3,
        Parent = window._surface,
        Theme = { BackgroundColor3 = "Border" },
    })
    window._sidebar = sidebar
    window._sidebarList = sidebarList
    window._sidebarDivider = divider
    window._content = content
end

local function createGuardianSurface(frame)
    local surface = UI.Create("CanvasGroup", {
        Name = "GuardianSurface", Size = UDim2.new(1, -2, 1, -2),
        Position = UDim2.fromOffset(1, 1),
        BackgroundTransparency = ThemeManager.Values.WindowTransparency,
        BorderSizePixel = 0, ClipsDescendants = true, GroupTransparency = 1,
        ZIndex = Z_INDEX.Window, Parent = frame,
        Theme = { BackgroundColor3 = "WindowBg", BackgroundTransparency = "WindowTransparency" },
    })
    UI.Round(surface, DEFAULTS.SurfaceCornerRadius)
    UI.Gradient(surface, "WindowGradientStart", "WindowGradientEnd", 140, 0)
    return surface
end

local function createGuardianTitleBar(surface)
    local titleBar = UI.Create("Frame", {
        Name = "TitleBar", Size = UDim2.new(1, 0, 0, DEFAULTS.TitleBarHeight),
        BackgroundTransparency = ThemeManager.Values.TitleBarTransparency,
        BorderSizePixel = 0, Active = true, ZIndex = Z_INDEX.TitleBar, Parent = surface,
        Theme = { BackgroundColor3 = "TitleBarBg", BackgroundTransparency = "TitleBarTransparency" },
    })
    local corner = UI.RoundCorners(titleBar, DEFAULTS.SurfaceCornerRadius, {
        TopLeft = true, TopRight = true, BottomRight = false, BottomLeft = false,
    })
    UI.Gradient(titleBar, "PanelGradientStart", "PanelGradientEnd", 100, 0.05)
    local separator = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundTransparency = 0.45, BorderSizePixel = 0,
        ZIndex = Z_INDEX.TitleBar + 1, Parent = titleBar,
        Theme = { BackgroundColor3 = "Separator" },
    })
    return titleBar, corner, separator
end

local function setMinimizedTitleShape(window, minimized)
    local corner = window._titleCorner
    if corner ~= nil and corner.Parent ~= nil then
        local rounded = UDim.new(0, DEFAULTS.SurfaceCornerRadius)
        local square = UDim.new(0, 0)
        local supported = pcall(function()
            corner.BottomLeftRadius = minimized and rounded or square
            corner.BottomRightRadius = minimized and rounded or square
        end)
        if not supported then
            corner.CornerRadius = rounded
        end
    end
    if window._titleSeparator ~= nil and window._titleSeparator.Parent ~= nil then
        window._titleSeparator.Visible = not minimized
    end
end

local function buildWindowShell(window, config)
    window._viewport = UI.Create("Frame", {
        Name = "SafeViewport", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, Parent = window._screenGui,
    })
    local width, height = requestedWindowSize(config, window._viewport)
    window._width = width
    window._height = height
    local frame = UI.Create("Frame", {
        Name = "Window",
        Size = UDim2.fromOffset(width, height),
        Position = UDim2.new(0.5, -math.floor(width / 2), 0.5, -math.floor(height / 2)),
        BackgroundTransparency = 1,
        BackgroundColor3 = ThemeManager.Values.Border,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        ZIndex = Z_INDEX.Window,
        Parent = window._viewport,
        Theme = { BackgroundColor3 = "Border" },
    })
    UI.Round(frame, DEFAULTS.WindowCornerRadius)
    local outline = UI.Stroke(frame, nil, 1.25, 1)
    window._frame = frame
    window._outline = outline
    window.Instance = frame

    local surface = createGuardianSurface(frame)
    window._surface = surface
    window._titleBar, window._titleCorner, window._titleSeparator = createGuardianTitleBar(surface)
    buildTrafficControls(window)
    buildTitleIdentity(window, config)
    buildSearchBox(window)
    buildWindowBody(window)
    UI.Tween(frame, { BackgroundTransparency = 0 }, TWEEN.Ease)
    UI.Tween(surface, { GroupTransparency = 0 }, TWEEN.Ease)
    UI.Tween(outline, { Transparency = 0.26 }, TWEEN.Ease)
end

function WindowMethods:_applyBodyLayout()
    local titleHeight = self._titleHeight
    local sidebarWidth = self._sidebarVisible and math.max(0, math.min(DEFAULTS.SidebarWidth, self._width - 24)) or 0
    local contentInset = self._compact and 0 or sidebarWidth
    self._titleBar.Size = UDim2.new(1, 0, 0, titleHeight)
    self._sidebar.Visible = self._sidebarVisible and not self._minimized
    self._sidebar.Size = UDim2.new(0, sidebarWidth, 1, -titleHeight)
    self._sidebar.Position = UDim2.fromOffset(0, titleHeight)
    self._content.Visible = not self._minimized
    self._content.Size = UDim2.new(1, -contentInset, 1, -titleHeight)
    self._content.Position = UDim2.fromOffset(contentInset, titleHeight)
    self._sidebarDivider.Visible = self._sidebarVisible and not self._minimized
    self._sidebarDivider.Size = UDim2.new(0, 1, 1, -titleHeight)
    self._sidebarDivider.Position = UDim2.fromOffset(sidebarWidth - 1, titleHeight)
    self._drawerBackdrop.Visible = self._compact and self._sidebarVisible and not self._minimized
    self._drawerBackdrop.Size = UDim2.new(1, 0, 1, -titleHeight)
    self._drawerBackdrop.Position = UDim2.fromOffset(0, titleHeight)
end

function WindowMethods:_refreshLayout()
    if self._destroyed or self._frame.Parent == nil then return end
    local _, viewport = MobileUI.Bounds(self._viewport)
    self._touch = MobileUI.TouchMode(self._mobileMode)
    local width, height = MobileUI.WindowSize(self._requestedSize, viewport, nil, nil, self._touch)
    self._width, self._height, self._winW, self._winH = width, height, width, height
    if self._maximized then width, height = math.max(1, viewport.X - 16), math.max(1, viewport.Y - 16) end
    local compact = width < 640
    if compact ~= self._compact then
        if compact then
            self._desktopSidebarVisible, self._sidebarVisible = self._sidebarVisible, false
        else
            self._sidebarVisible = self._desktopSidebarVisible ~= false
        end
        self._compact = compact
    end
    local shortHeader = compact and height < 240
    self._titleHeight = compact and (shortHeader and 60 or 116) or DEFAULTS.TitleBarHeight
    -- Cancel resize tweens before applying geometry from a changed viewport.
    UI.Tween(self._frame, { Size = UDim2.fromOffset(width, self._minimized and self._titleHeight + 2 or height) }, TWEEN.Instant)
    self._sidebarButton.Visible = compact
    local buttonSize = self._touch and 44 or 26
    local count = 0
    for _, button in ipairs({ self._closeButton, self._minimizeButton, self._maximizeButton }) do
        button.Size = UDim2.fromOffset(buttonSize, buttonSize)
        if button.Visible then count += 1 end
    end
    local trafficWidth = math.max(0, count * (buttonSize + 5) - 5)
    self._trafficHolder.Size = UDim2.fromOffset(trafficWidth, buttonSize)
    self._trafficHolder.Position = compact and UDim2.fromOffset(12, 8) or UDim2.new(0, 15, 0.5, -buttonSize / 2)
    self._trafficHolder.Visible, self._titleHolder.Visible = not shortHeader, not shortHeader
    if shortHeader then
        self._searchHolder.Size, self._searchHolder.Position = UDim2.new(1, -80, 0, 44), UDim2.fromOffset(12, 8)
    elseif compact then
        local titleLeft = 24 + trafficWidth
        self._titleHolder.Size = UDim2.fromOffset(math.max(1, width - titleLeft - 66), 60)
        self._titleHolder.Position = UDim2.fromOffset(titleLeft, 0)
        self._searchHolder.Size, self._searchHolder.Position = UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 62)
    else
        self._titleHolder.Size, self._titleHolder.Position = UDim2.new(0, 260, 1, 0), UDim2.new(0.5, -130, 0, 0)
        self._searchHolder.Size = UDim2.fromOffset(140, self._touch and 44 or 32)
        self._searchHolder.Position = UDim2.new(1, -154, 0.5, self._touch and -22 or -16)
    end
    if self._userInfo ~= nil then self._userInfo.Visible = not compact and width >= 900 end
    if self._icon ~= nil then self._icon.Visible = not compact end
    self:_applyBodyLayout()
    for _, tab in ipairs(self._tabs) do
        tab._button.Size = UDim2.new(1, 0, 0, self._touch and 44 or 36)
        local padding = tab._content:FindFirstChildOfClass("UIPadding")
        if padding ~= nil then
            padding.PaddingLeft, padding.PaddingRight = UDim.new(0, compact and 12 or 24), UDim.new(0, compact and 12 or 24)
        end
        for _, component in ipairs(tab._components) do
            if component._layoutRow ~= nil then component._layoutRow() end
            if component._updateKeyDisplay ~= nil then component._updateKeyDisplay() end
            if component._layoutTouch ~= nil then component._layoutTouch() end
        end
    end
    for modal in pairs(self._modals) do
        if modal._fit ~= nil and not modal._destroyed then modal._fit() end
    end
    self._mobileToggle.Visible = self._mobileToggleEnabled == true
        or (self._mobileToggleEnabled ~= false and self._touch)
    self:_clampToViewport()
    for _, popup in ipairs(table.clone(self._popups)) do
        if type(popup.Fit) == "function" then safeCall(popup.Fit) end
    end
end

function WindowMethods:SetMobileMode(mode)
    if mode ~= "Auto" and mode ~= "Touch" and mode ~= "Desktop" then
        reportError("mobile mode must be Auto, Touch, or Desktop")
        return self
    end
    self._mobileMode = mode
    MobileUI.SafeScreen(self._screenGui, MobileUI.TouchMode(mode))
    self:ClosePopups()
    self._input:CancelPointer()
    self:_refreshLayout()
    return self
end

function WindowMethods:GetMobileMode()
    return self._mobileMode
end

function WindowMethods:_buildMobileControls(config)
    local button = UI.Create("TextButton", {
        Name = "MobileTabs", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -56, 0, 8),
        BackgroundTransparency = 0.08, BorderSizePixel = 0, Text = "☰", TextSize = 20,
        Font = Enum.Font.GothamBold, AutoButtonColor = false, Visible = false,
        ZIndex = Z_INDEX.TitleBar + 3, Parent = self._titleBar,
        Theme = { BackgroundColor3 = "InputBg", TextColor3 = "LabelText" },
    })
    UI.Round(button, 10)
    UI.Stroke(button)
    self._sidebarButton = button
    local backdrop = UI.Create("TextButton", {
        Name = "TabBackdrop", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false,
        ZIndex = Z_INDEX.Sidebar - 1, Parent = self._surface,
    })
    self._drawerBackdrop = backdrop
    self._tasks:Connect(backdrop.Activated, function() self:SetSidebarVisible(false) end)
    local toggle = UI.Create("TextButton", {
        Name = "MobileToggle", Size = UDim2.fromOffset(48, 48),
        Position = robloxType(config.MobileTogglePosition) == "UDim2" and config.MobileTogglePosition or UDim2.new(1, -60, 0.5, -24),
        BackgroundTransparency = 0.06, BorderSizePixel = 0, Text = normalizeText(config.MobileToggleText, "UI"),
        TextSize = 13, Font = Enum.Font.GothamBold, AutoButtonColor = false,
        ZIndex = Z_INDEX.Popup - 1, Parent = self._viewport,
        Theme = { BackgroundColor3 = "Accent", TextColor3 = "TabActiveText" },
    })
    UI.Round(toggle, 16)
    UI.Stroke(toggle, nil, 1, 0.35)
    self._mobileToggle = toggle
    local suppressUntil, dragMoved = 0, false
    self._tasks:Connect(toggle.InputBegan, function(input)
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then return end
        if self._input._pointer ~= nil then return end
        dragMoved = false
        local start, positionStart, absoluteStart = inputPosition2(input), toggle.Position, toggle.AbsolutePosition
        local moved = false
        self._input:BeginPointer(input, function(position)
            local delta = position - start
            if delta.Magnitude < 8 and not moved then return end
            moved = true
            dragMoved = true
            local origin, viewport = MobileUI.Bounds(self._viewport)
            toggle.Position = clampedDragPosition(toggle, positionStart, absoluteStart, delta, viewport, origin)
        end, function(cancelled)
            if moved or cancelled then suppressUntil = os.clock() + 0.25 end
            dragMoved = false
        end, toggle, false)
    end)
    self._tasks:Connect(toggle.Activated, function()
        if not dragMoved and os.clock() >= suppressUntil then self:Toggle() end
    end)
end

local function buildNavigationControls(window, config)
    window:_buildMobileControls(config)
    window._backButton, window._forwardButton = nil, nil
end

local function buildUserInfo(window, config)
    if config.ShowUserInfo ~= true then
        return
    end
    local holder = UI.Create("Frame", {
        Size = UDim2.fromOffset(125, 30),
        Position = UDim2.new(1, -302, 0.5, -15),
        BackgroundTransparency = 1,
        ZIndex = Z_INDEX.TitleBar + 1,
        Parent = window._titleBar,
    })
    window._userInfo = holder
    local avatar = UI.Create("ImageLabel", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(0, 2),
        BackgroundTransparency = 0,
        Image = "",
        ZIndex = Z_INDEX.TitleBar + 2,
        Parent = holder,
        Theme = { BackgroundColor3 = "TabHover" },
    })
    UI.Round(avatar, 13)
    UI.Create("TextLabel", {
        Size = UDim2.new(1, -32, 1, 0),
        Position = UDim2.fromOffset(32, 0),
        BackgroundTransparency = 1,
        Text = normalizeText(LocalPlayer.DisplayName, LocalPlayer.Name),
        TextSize = 11,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_INDEX.TitleBar + 2,
        Parent = holder,
        Theme = { TextColor3 = "LabelText" },
    })

    window._tasks:Spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size48x48
            )
        end)
        if ok and avatar.Parent ~= nil then
            avatar.Image = image
        end
    end)
end

local function createAcrylicBlur(window, config)
    if config.AcrylicBlur ~= true then
        return
    end
    local ok, blur = pcall(function()
        local effect = Instance.new("BlurEffect")
        effect.Name = "CrispyLibBlur"
        effect.Size = clamp(numberOr(config.BlurSize, 16), 0, 56)
        effect.Parent = Lighting
        return effect
    end)
    if ok then
        window._blur = blur
    end
end

function WindowMethods:_clampToViewport()
    if self._destroyed or self._frame.Parent == nil then return end
    local origin, viewport = MobileUI.Bounds(self._viewport)
    local size, position = self._frame.AbsoluteSize, self._frame.AbsolutePosition
    local x = clamp(position.X, origin.X, origin.X + math.max(0, viewport.X - size.X))
    local y = clamp(position.Y, origin.Y, origin.Y + math.max(0, viewport.Y - size.Y))
    if x ~= position.X or y ~= position.Y then
        local current = self._frame.Position
        self._frame.Position = UDim2.new(current.X.Scale, current.X.Offset + x - position.X,
            current.Y.Scale, current.Y.Offset + y - position.Y)
    end
    if self._mobileToggle ~= nil then
        local toggle = self._mobileToggle
        toggle.Position = clampedDragPosition(toggle, toggle.Position, toggle.AbsolutePosition, Vector2.new(0, 0), viewport, origin)
    end
end

function WindowMethods:_attachDrag(handle)
    self._tasks:Connect(handle.InputBegan, function(input)
        if self._pinned then
            return
        end
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
            return
        end
        local pointerStart = inputPosition2(input)
        if self._input._pointer ~= nil then return end
        if MobileUI.InteractiveAt(handle, pointerStart) then return end
        self:ClosePopups()
        local framePositionStart = self._frame.Position
        local frameAbsoluteStart = self._frame.AbsolutePosition
        self._input:BeginPointer(input, function(position)
            local delta = position - pointerStart
            if delta.X == 0 and delta.Y == 0 then
                return
            end
            local origin, viewport = MobileUI.Bounds(self._viewport)
            self._frame.Position = clampedDragPosition(
                self._frame, framePositionStart, frameAbsoluteStart, delta, viewport, origin
            )
        end, nil, self, false)
    end)
end

function WindowMethods:_wireControls(config)
    if self._closeButton.Visible then
        self._tasks:Connect(self._closeButton.Activated, function()
            if self._touch and self._mobileToggle.Visible then self:Hide(); return end
            UI.Tween(self._frame, { BackgroundTransparency = 1 }, TWEEN.Medium)
            UI.Tween(self._surface, { GroupTransparency = 1 }, TWEEN.Medium)
            UI.Tween(self._outline, { Transparency = 1 }, TWEEN.Medium)
            self._tasks:Delay(0.22, function()
                self:Destroy()
            end)
        end)
    end
    if self._minimizeButton.Visible then
        self._tasks:Connect(self._minimizeButton.Activated, function()
            self:ToggleMinimize()
        end)
    end
    if self._maximizeButton.Visible then
        self._tasks:Connect(self._maximizeButton.Activated, function()
            self:ToggleMaximize()
        end)
    end
    if self._sidebarButton ~= nil then
        self._tasks:Connect(self._sidebarButton.Activated, function()
            self:SetSidebarVisible(not self._sidebarVisible)
        end)
    end
    if self._backButton ~= nil then
        self._tasks:Connect(self._backButton.Activated, function()
            self:_navigateHistory(-1)
        end)
    end
    if self._forwardButton ~= nil then
        self._tasks:Connect(self._forwardButton.Activated, function()
            self:_navigateHistory(1)
        end)
    end

    self._keybind = isKeyCode(config.Keybind) and config.Keybind or nil
    if config.Keybind ~= nil and self._keybind == nil then
        reportError("window keybind must be an Enum.KeyCode or nil")
    end
    self._tasks:Add(self._input:BindKey(self, function()
        return self._keybind
    end, function()
        self:Toggle()
    end))
end

function WindowMethods:_createTooltip(owner, text, componentTasks)
    local tooltip = UI.Create("TextLabel", {
        Name = "Tooltip",
        Size = UDim2.fromOffset(230, 34),
        BackgroundTransparency = ThemeManager.Values.PopupTransparency,
        BorderSizePixel = 0,
        Text = text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        Visible = false,
        ZIndex = Z_INDEX.Popup + 20,
        Parent = self._screenGui,
        Theme = {
            BackgroundColor3 = "PopupBg",
            BackgroundTransparency = "PopupTransparency",
            TextColor3 = "LabelText",
        },
    })
    UI.Round(tooltip, 10)
    UI.Stroke(tooltip)
    UI.Gradient(tooltip, "SurfaceGradientStart", "SurfaceGradientEnd", 115, 0.12)

    local function reposition()
        local origin, viewport = MobileUI.Bounds(self._viewport)
        local position = owner.AbsolutePosition - origin
        local width = math.min(230, math.max(1, viewport.X - 12))
        tooltip.Size = UDim2.fromOffset(width, 34)
        local x = clamp(position.X, 6, math.max(6, viewport.X - width - 6))
        local above = position.Y - 38
        local y = above >= 6 and above or (position.Y + owner.AbsoluteSize.Y + 4)
        tooltip.Position = UDim2.fromOffset(x, y)
    end
    componentTasks:Connect(owner.MouseEnter, function()
        reposition()
        tooltip.Visible = true
    end)
    componentTasks:Connect(owner.MouseLeave, function()
        tooltip.Visible = false
    end)
    componentTasks:Add(tooltip)
    return tooltip
end

function WindowMethods:RegisterComponent(flag, component)
    local normalized = normalizeFlag(flag)
    if normalized ~= nil and component ~= nil then
        local components = self._componentLists[normalized]
        if components == nil then
            components = {}
            self._componentLists[normalized] = components
        end
        local exists = false
        local count = math.min(#components, LIMITS.MaxListeners)
        for index = 1, count do
            if components[index] == component then
                exists = true
                break
            end
        end
        if not exists and #components < LIMITS.MaxListeners then
            components[#components + 1] = component
        end
        self._components[normalized] = component
    end
    return component
end

function WindowMethods:_unregisterComponent(flag, component)
    local normalized = normalizeFlag(flag)
    if normalized == nil then
        return
    end
    local components = self._componentLists[normalized]
    if components ~= nil then
        removeArrayValue(components, component, LIMITS.MaxListeners)
        if #components == 0 then
            self._componentLists[normalized] = nil
            self._components[normalized] = nil
        elseif self._components[normalized] == component then
            self._components[normalized] = components[#components]
        end
    elseif self._components[normalized] == component then
        self._components[normalized] = nil
    end
end

function WindowMethods:GetComponent(flag)
    return self._components[normalizeFlag(flag)]
end

function WindowMethods:RegisterPopup(instance, closeCallback, fitCallback)
    if robloxType(instance) ~= "Instance" or type(closeCallback) ~= "function" then
        return function() end
    end
    if #self._popups >= LIMITS.MaxListeners then
        reportError("window popup limit reached")
        return function() end
    end

    local entry = { Instance = instance, Close = closeCallback, Fit = fitCallback }
    self._popups[#self._popups + 1] = entry
    local active = true
    return function()
        if active then
            active = false
            removeArrayValue(self._popups, entry, LIMITS.MaxListeners)
        end
    end
end

function WindowMethods:ClosePopups(except)
    local count = math.min(#self._popups, LIMITS.MaxListeners)
    for index = count, 1, -1 do
        local popup = self._popups[index]
        if popup.Instance ~= except then
            safeCall(popup.Close)
        end
    end
    return self
end

function WindowMethods:_activateTab(tab, pushHistory)
    if self._destroyed or tab == nil or tab._destroyed then return self end
    if self._compact then self:SetSidebarVisible(false) end
    if self._activeTab == tab then return self end
    self:ClosePopups()
    self._input:CancelPointer()
    self._input:CancelCapture()
    if self._activeTab ~= nil then
        self._activeTab:_setActive(false)
    end
    self._activeTab = tab
    tab:_setActive(true)
    self._searchBox.Text = ""
    tab:_search("")

    if pushHistory then
        for index = math.min(#self._history, LIMITS.MaxHistoryEntries), self._historyIndex + 1, -1 do
            self._history[index] = nil
        end
        self._history[#self._history + 1] = tab
        if #self._history > LIMITS.MaxHistoryEntries then
            table.remove(self._history, 1)
        end
        self._historyIndex = #self._history
    end
    return self
end

function WindowMethods:_navigateHistory(offset)
    local target = self._historyIndex + offset
    if target < 1 or target > #self._history then
        return
    end
    local tab = self._history[target]
    if tab == nil or tab._destroyed then
        return
    end
    self._historyIndex = target
    self:_activateTab(tab, false)
end

function WindowMethods:GetTab(name)
    local requested = tostring(name or "")
    local count = math.min(#self._tabs, LIMITS.MaxTabsPerWindow)
    for index = 1, count do
        if self._tabs[index].Name == requested then
            return self._tabs[index]
        end
    end
    return nil
end

function WindowMethods:Search(query)
    local text = normalizeText(query, "")
    local count = math.min(#self._tabs, LIMITS.MaxTabsPerWindow)
    for index = 1, count do
        self._tabs[index]:_search(text)
    end
    return self
end

function WindowMethods:SetSidebarVisible(visible)
    self._sidebarVisible = visible == true
    if not self._compact then self._desktopSidebarVisible = self._sidebarVisible end
    self:_applyBodyLayout()
    return self
end

function WindowMethods:Show()
    if not self._destroyed then
        self._screenGui.Enabled = true
        self._frame.Visible = true
        if self._blur ~= nil then self._blur.Enabled = true end
    end
    return self
end

function WindowMethods:Hide()
    if not self._destroyed then
        self:ClosePopups()
        self._input:CancelPointer()
        self._input:CancelCapture()
        self._frame.Visible = false
        if self._blur ~= nil then self._blur.Enabled = false end
    end
    return self
end

function WindowMethods:Toggle()
    if not self._destroyed then
        if self._frame.Visible then
            self:Hide()
        else
            self:Show()
        end
    end
    return self
end

function WindowMethods:SetVisible(visible)
    if visible then
        return self:Show()
    end
    return self:Hide()
end

function WindowMethods:Minimize(state)
    self._minimized = state == nil and true or state == true
    self:ClosePopups()
    self._input:CancelPointer()
    setMinimizedTitleShape(self, self._minimized)
    self:_refreshLayout()
    return self
end

function WindowMethods:Restore()
    local wasMaximized = self._maximized
    self._maximized, self._minimized = false, false
    setMinimizedTitleShape(self, false)
    self:_refreshLayout()
    if wasMaximized and self._restorePosition ~= nil then self._frame.Position = self._restorePosition end
    self:_clampToViewport()
    return self
end

function WindowMethods:ToggleMinimize()
    return self:Minimize(not self._minimized)
end

function WindowMethods:Maximize()
    if self._maximized then return self end
    self._restorePosition, self._maximized, self._minimized = self._frame.Position, true, false
    self:ClosePopups()
    self._input:CancelPointer()
    setMinimizedTitleShape(self, false)
    self:_refreshLayout()
    self._frame.Position = UDim2.fromOffset(8, 8)
    return self
end

function WindowMethods:ToggleMaximize()
    if self._maximized then
        return self:Restore()
    end
    return self:Maximize()
end

function WindowMethods:SetKeybind(key)
    if key == nil or isKeyCode(key) then
        self._keybind = key
    else
        reportError("window keybind must be an Enum.KeyCode or nil")
    end
    return self
end

function WindowMethods:SetOpacity(opacity)
    UI.SetOpacity(self._frame, opacity)
    return self
end

function WindowMethods:SetStyle(styles, persistent)
    CrispyLib.Style(self._surface, styles, persistent)
    return self
end

function WindowMethods:SetAccent(color)
    if robloxType(color) == "Color3" then
        ThemeManager.Set({ Accent = color, AccentHover = color:Lerp(Color3.new(1, 1, 1), 0.12), AccentPress = color:Lerp(Color3.new(0, 0, 0), 0.15) })
    end
    return self
end

function WindowMethods:SetIcon(imageId)
    local image = normalizeText(imageId, "")
    if image == "" then
        if self._icon ~= nil then
            self._icon:Destroy()
            self._icon = nil
        end
        return self
    end
    if self._icon == nil then
        self._icon = UI.Create("ImageLabel", {
            Name = "TitleIcon",
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset(-26, 14),
            BackgroundTransparency = 1,
            Image = image,
            ZIndex = Z_INDEX.TitleBar + 2,
            Parent = self._titleHolder,
        })
    else
        self._icon.Image = image
    end
    return self
end

function WindowMethods:SetPosition(position)
    if robloxType(position) == "UDim2" then
        self._maximized = false
        UI.Tween(self._frame, { Position = position }, TWEEN.Medium)
    end
    return self
end

function WindowMethods:Resize(size)
    if robloxType(size) ~= "UDim2" then return self end
    self._requestedSize, self._maximized = size, false
    self:ClosePopups()
    self._input:CancelPointer()
    self:_refreshLayout()
    return self
end

function WindowMethods:Pin()
    self._pinned = true
    return self
end

function WindowMethods:Unpin()
    self._pinned = false
    return self
end

function WindowMethods:IsPinned()
    return self._pinned
end

function WindowMethods:TaskGroup(name)
    local group = TaskGroup.new(name or ("WindowTask:" .. self.Title))
    self._tasks:Add(group)
    return group
end

local function createModalButton(modal, config, index, count)
    local width = 88
    local button = UI.Create("TextButton", {
        Size = UDim2.fromOffset(width, 30),
        Position = UDim2.new(1, -16 - ((count - index + 1) * (width + 8)) + 8, 1, -44),
        BorderSizePixel = 0,
        Text = normalizeText(config.Text, "OK"),
        TextSize = 12,
        Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false,
        ZIndex = Z_INDEX.Modal + 2,
        Parent = modal._buttonHolder,
        LayoutOrder = index,
        Theme = {
            BackgroundColor3 = config.Accent == false and "InputBg" or "Accent",
            TextColor3 = config.Accent == false and "LabelText" or "TabActiveText",
        },
    })
    button.BackgroundTransparency = config.Accent == false and ThemeManager.Values.InputTransparency or 0.06
    UI.Round(button, 10)
    UI.Stroke(button, nil, 1, 0.68)
    if config.Accent ~= false then
        UI.Gradient(button, "AccentGradientStart", "AccentGradientEnd", 15, 0)
    else
        UI.Gradient(button, "PanelGradientStart", "PanelGradientEnd", 115, 0.18)
    end
    UI.Hover(modal._tasks, button,
        config.Accent == false and "InputBg" or "Accent",
        config.Accent == false and "RowHover" or "AccentHover",
        config.Accent == false and "RowBg" or "AccentPress")
    modal._tasks:Connect(button.Activated, function()
        if type(config.Callback) == "function" then
            safeCall(config.Callback, modal)
        end
        if config.Close ~= false then
            modal:Hide()
        end
    end)
end

local function createModalSurface(window, config)
    local overlay = UI.Create("Frame", {
        Name = "ModalOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.48,
        BorderSizePixel = 0,
        Visible = config.Visible == true, Active = true,
        ZIndex = Z_INDEX.Modal,
        Parent = window._screenGui,
    })
    local box = UI.Create("Frame", {
        Name = "Modal",
        Size = UDim2.fromOffset(clamp(numberOr(config.Width, 360), 240, 800), clamp(numberOr(config.Height, 180), 120, 700)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = ThemeManager.Values.WindowTransparency,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Modal + 1,
        Parent = overlay,
        Theme = { BackgroundColor3 = "WindowBg", BackgroundTransparency = "WindowTransparency" },
    })
    UI.Round(box, 18)
    UI.Stroke(box, nil, 1.25, 0.3)
    UI.Gradient(box, "WindowGradientStart", "WindowGradientEnd", 135, 0)
    UI.Create("TextLabel", {
        Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 12), BackgroundTransparency = 1,
        Text = normalizeText(config.Title, "Message"), TextSize = 16, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = Z_INDEX.Modal + 2, Parent = box,
        Theme = { TextColor3 = "TitleText" },
    })
    local messageScroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, -32, 1, -92), Position = UDim2.fromOffset(16, 48),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
        ZIndex = Z_INDEX.Modal + 2, Parent = box,
    })
    UI.Create("TextLabel", {
        Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = normalizeText(config.Message, ""), TextSize = 13, Font = Enum.Font.Gotham, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = Z_INDEX.Modal + 2, Parent = messageScroll, Theme = { TextColor3 = "DescText" },
    })
    return overlay, box, messageScroll
end

local function installModalMethods(modal)
    function modal:Show()
        if not self._destroyed then self.Instance.Visible = true end
        return self
    end
    function modal:Hide()
        if not self._destroyed then self.Instance.Visible = false end
        return self
    end
    function modal:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        self._window._modals[self] = nil
        self._parentTasks:_forget(self)
        self._tasks:Destroy()
        if self.Instance.Parent ~= nil then self.Instance:Destroy() end
    end
end

local function attachModal(window, modal)
    window._tasks:Add(modal)
    modal._tasks:Connect(modal.Instance.Destroying, function()
        if modal._destroyed then return end
        modal._destroyed = true
        modal._window._modals[modal] = nil
        modal._parentTasks:_forget(modal)
        modal._tasks:Destroy()
    end)
end

function WindowMethods:CreateModal(config)
    config = type(config) == "table" and config or {}
    local overlay, box, messageScroll = createModalSurface(self, config)
    local modal = {
        Instance = overlay, Box = box, _window = self, _tasks = TaskGroup.new("Modal"),
        _parentTasks = self._tasks, _destroyed = false,
    }
    installModalMethods(modal)
    self._modals[modal] = true
    attachModal(self, modal)

    local buttons = type(config.Buttons) == "table" and config.Buttons or { { Text = "OK", Callback = config.Callback } }
    local count = math.min(#buttons, 8)
    local footer = UI.Create("ScrollingFrame", {
        Name = "ModalActions", BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ZIndex = Z_INDEX.Modal + 2, Parent = box,
    })
    local grid = UI.Create("UIGridLayout", {
        CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = footer,
    })
    modal._buttonHolder = footer
    local function fitModal()
        if modal._destroyed then return end
        local _, viewport = MobileUI.Bounds(self._viewport)
        local width = math.min(clamp(numberOr(config.Width, 360), 240, 800), math.max(1, viewport.X - 24))
        local columns = math.max(1, math.min(math.max(count, 1), math.floor((width - 32) / 96)))
        local actionHeight = self._touch and 44 or 30
        local rows = math.ceil(count / columns)
        local totalFooter = rows > 0 and (rows * (actionHeight + 8) - 8) or 0
        local height = math.min(math.max(numberOr(config.Height, 180), totalFooter + 96), math.max(1, viewport.Y - 24))
        local footerHeight = math.min(totalFooter, math.max(0, height - 100))
        box.Size = UDim2.fromOffset(width, height)
        grid.FillDirectionMaxCells = columns
        grid.CellSize = UDim2.fromOffset(math.max(1, (width - 32 - (columns - 1) * 8) / columns), actionHeight)
        footer.Size, footer.Position = UDim2.new(1, -32, 0, footerHeight), UDim2.new(0, 16, 1, -footerHeight - 14)
        messageScroll.Size = UDim2.new(1, -32, 0, math.max(0, height - footerHeight - 72))
    end
    modal._fit = fitModal
    modal._tasks:Connect(self._viewport:GetPropertyChangedSignal("AbsoluteSize"), fitModal)
    fitModal()
    for index = 1, count do
        createModalButton(modal, buttons[index], index, count)
    end
    return modal
end

function WindowMethods:Confirm(title, message, onConfirm, onCancel)
    return self:CreateModal({
        Title = title or "Confirm",
        Message = message or "Are you sure?",
        Visible = true,
        Buttons = {
            { Text = "Cancel", Accent = false, Callback = onCancel },
            { Text = "Confirm", Callback = onConfirm },
        },
    })
end

function WindowMethods:AddSidebarSection(name)
    self._sidebarOrder = self._sidebarOrder + 1
    self._order = self._sidebarOrder
    local label = UI.Create("TextLabel", {
        Name = "SidebarSection_" .. tostring(self._sidebarOrder),
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        Text = normalizeText(name, ""):upper(),
        TextSize = 8,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = self._sidebarOrder,
        ZIndex = Z_INDEX.Sidebar + 2,
        Parent = self._sidebarList,
        Theme = { TextColor3 = "SectionLabel" },
    })
    UI.Padding(label, 0, 0, 0, 9)
    return label
end

function WindowMethods:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    self:ClosePopups()
    for index = math.min(#self._tabs, LIMITS.MaxTabsPerWindow), 1, -1 do
        local tab = self._tabs[index]
        if tab ~= nil then
            tab:Destroy()
        end
    end
    self._input:Destroy()
    self._tasks:Destroy()
    if self._blur ~= nil and self._blur.Parent ~= nil then
        self._blur:Destroy()
    end
    if self._screenGui ~= nil and self._screenGui.Parent ~= nil then
        self._screenGui:Destroy()
    end
    removeArrayValue(CrispyLib._windows, self, LIMITS.MaxWindows)
end

local function createTabNavigation(window, config, name)
    local button = UI.Create("TextButton", {
        Name = "Tab_" .. name:gsub("[^%w_]", ""),
        Size = UDim2.new(1, 0, 0, window._touch and 44 or 36),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = window._sidebarOrder,
        ZIndex = Z_INDEX.Sidebar + 2,
        Parent = window._sidebarList,
        Theme = { BackgroundColor3 = "TabHover" },
    })
    UI.Round(button, 10)
    UI.Gradient(button, "AccentGradientStart", "AccentGradientEnd", 15, 0.18)
    local stroke = UI.Stroke(button, ThemeManager.Values.Border, 1, 1)
    local indicator = UI.Create("Frame", {
        Name = "ActiveIndicator",
        Size = UDim2.fromOffset(3, 18),
        Position = UDim2.new(0, 0, 0.5, -9),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Sidebar + 4,
        Parent = button,
        Theme = { BackgroundColor3 = "Accent" },
    })
    UI.Round(indicator, 2)
    UI.Gradient(indicator, "AccentGradientStart", "AccentGradientEnd", 90, 0)
    local icon = UI.Create("TextLabel", {
        Name = "Icon", Size = UDim2.fromOffset(20, 36), Position = UDim2.fromOffset(11, 0),
        BackgroundTransparency = 1, Text = normalizeText(config.Icon, ""), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Sidebar + 3, Parent = button, Theme = { TextColor3 = "TabInactive" },
    })
    local label = UI.Create("TextLabel", {
        Name = "Label", Size = UDim2.new(1, -41, 1, 0), Position = UDim2.fromOffset(34, 0),
        BackgroundTransparency = 1, Text = name, TextSize = 11, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_INDEX.Sidebar + 3, Parent = button, Theme = { TextColor3 = "TabInactive" },
    })
    return button, icon, label, indicator, stroke
end

local function createTabContent(window, name)
    local scroll = UI.ScrollingFrame(window._content, Z_INDEX.Content + 1)
    scroll.Visible = false
    scroll.ScrollBarThickness = 2
    local content = UI.Create("Frame", {
        Name = "Content_" .. name:gsub("[^%w_]", ""),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = Z_INDEX.Content + 1,
        Parent = scroll,
    })
    UI.List(content, Enum.FillDirection.Vertical, 16)
    UI.Padding(content, 22, window._compact and 12 or 24, 24, window._compact and 12 or 24)
    return scroll, content
end

local function wireTabNavigation(tab)
    local window, tasks = tab._window, tab._tasks
    ThemeManager.Bind(tab._button, {
        BackgroundColor3 = function()
            return window._activeTab == tab and ThemeManager.Values.TabHover or ThemeManager.Values.SidebarBg
        end,
    })
    ThemeManager.Bind(tab._icon, {
        TextColor3 = function()
            return window._activeTab == tab and ThemeManager.Values.TabActiveText or ThemeManager.Values.TabInactive
        end,
    })
    ThemeManager.Bind(tab._buttonLabel, {
        TextColor3 = function()
            return window._activeTab == tab and ThemeManager.Values.TabActiveText or ThemeManager.Values.TabInactive
        end,
    })
    ThemeManager.Bind(tab._tabStroke, {
        Color = function()
            return window._activeTab == tab and ThemeManager.Values.GlassHighlight or ThemeManager.Values.Border
        end,
        Transparency = function()
            return window._activeTab == tab and 0.48 or 1
        end,
    })
    tasks:Connect(tab._button.MouseEnter, function()
        if window._activeTab ~= tab then
            UI.Tween(tab._button, { BackgroundTransparency = 0.68, BackgroundColor3 = ThemeManager.Values.TabHover }, TWEEN.Fast)
        end
    end)
    tasks:Connect(tab._button.MouseLeave, function()
        if window._activeTab ~= tab then
            UI.Tween(tab._button, { BackgroundTransparency = 1 }, TWEEN.Fast)
        end
    end)
    tasks:Connect(tab._button.Activated, function() window:_activateTab(tab, true) end)
end

local function newTab(window, config)
    local name = normalizeText(config.Name or config.Title, "Tab")
    window._sidebarOrder = window._sidebarOrder + 1
    window._order = window._sidebarOrder
    local tasks = TaskGroup.new("Tab:" .. name)
    local button, icon, label, indicator, stroke = createTabNavigation(window, config, name)
    local scroll, content = createTabContent(window, name)
    local tab = setmetatable({
        Name = name, Instance = content, _window = window, _tasks = tasks,
        _button = button, _icon = icon, _buttonLabel = label,
        _indicator = indicator, _tabStroke = stroke,
        _scroll = scroll, _content = content, _order = 0,
        _components = {}, _searchables = {}, _sections = {},
        _currentGroup = nil, _destroyed = false, _badge = nil,
    }, TabMethods)
    tab._btn, tab._win = button, window
    window._tasks:Add(tab)
    wireTabNavigation(tab)
    return tab
end

function WindowMethods:AddTab(config)
    config = type(config) == "table" and config or {}
    if self._destroyed or #self._tabs >= LIMITS.MaxTabsPerWindow then
        reportError("window tab limit reached")
        return nil
    end
    local tab = newTab(self, config)
    self._tabs[#self._tabs + 1] = tab
    if self._activeTab == nil then
        self:_activateTab(tab, true)
    end
    return tab
end

local function newWindowState(title, screenGui, tasks, config)
    return setmetatable({
        Title = title,
        _screenGui = screenGui,
        _tasks = tasks,
        _input = nil,
        _tabs = {},
        _activeTab = nil,
        _history = {},
        _historyIndex = 0,
        _sidebarOrder = 0,
        _components = {},
        _componentLists = {},
        _popups = {},
        _modals = {},
        _disabledControls = disabledControlSet(config),
        _sidebarVisible = true,
        _desktopSidebarVisible = true,
        _mobileMode = (config.MobileMode == "Touch" or config.MobileMode == "Desktop") and config.MobileMode or "Auto",
        _touch = MobileUI.TouchMode(config.MobileMode),
        _mobileToggleEnabled = config.MobileToggle,
        _requestedSize = config.Size,
        _compact = false,
        _titleHeight = DEFAULTS.TitleBarHeight,
        _minimized = false,
        _maximized = false,
        _pinned = false,
        _destroyed = false,
        _blur = nil,
    }, WindowMethods)
end

local function initializeWindowView(window, config)
    window._input = InputRouter.new(window._tasks)
    buildWindowShell(window, config)
    window._sg = window._screenGui
    window._window = window._frame
    window._sbList = window._sidebarList
    window._order = window._sidebarOrder
    window._winW = window._width
    window._winH = window._height
    buildNavigationControls(window, config)
    buildUserInfo(window, config)
    createAcrylicBlur(window, config)
    window:_wireControls(config)
    window:_refreshLayout()
    window:_attachDrag(config.DragStyle == 2 and window._frame or window._titleBar)
end

local function wireWindowLifecycle(window)
    local tasks, screenGui = window._tasks, window._screenGui
    local cameraConnection
    local function updateViewport()
        if window._destroyed then return end
        window:ClosePopups()
        window._input:CancelPointer()
        window:_refreshLayout()
    end
    local function bindCamera()
        if cameraConnection ~= nil then tasks:Cancel(cameraConnection); cameraConnection = nil end
        local camera = Workspace.CurrentCamera
        if camera ~= nil then cameraConnection = tasks:Connect(camera:GetPropertyChangedSignal("ViewportSize"), updateViewport) end
        updateViewport()
    end
    tasks:Connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
    tasks:Connect(window._viewport:GetPropertyChangedSignal("AbsoluteSize"), updateViewport)
    tasks:Connect(window._viewport:GetPropertyChangedSignal("AbsolutePosition"), updateViewport)
    tasks:Connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"), function()
        MobileUI.SafeScreen(screenGui, MobileUI.TouchMode(window._mobileMode))
        updateViewport()
    end)
    local keyboardToken
    local function updateKeyboard()
        if window._destroyed then return end
        window._input:CancelPointer()
        window:_refreshLayout()
        if keyboardToken ~= nil then tasks:Cancel(keyboardToken) end
        keyboardToken = tasks:Delay(0.05, function()
            keyboardToken = nil
            MobileUI.RevealTextBox(UserInputService:GetFocusedTextBox(), screenGui)
        end)
    end
    for _, property in ipairs({ "OnScreenKeyboardVisible", "OnScreenKeyboardPosition", "OnScreenKeyboardSize" }) do
        local ok, signal = pcall(function() return UserInputService:GetPropertyChangedSignal(property) end)
        if ok then tasks:Connect(signal, updateKeyboard) end
    end
    tasks:Connect(UserInputService.TextBoxFocused, updateKeyboard)
    bindCamera()

    tasks:Connect(screenGui.Destroying, function()
        if not window._destroyed then
            window._destroyed = true
            window._input:Destroy()
            tasks:Destroy()
            if window._blur ~= nil and window._blur.Parent ~= nil then
                window._blur:Destroy()
            end
            removeArrayValue(CrispyLib._windows, window, LIMITS.MaxWindows)
        end
    end)
end

local function applyWindowConfig(window, config)
    CrispyLib._windows[#CrispyLib._windows + 1] = window
    if config.AutoLoad == true then Config._queueAutoLoad(window._tasks, config.ConfigFile) end
end

local function createWindow(config)
    if #CrispyLib._windows >= LIMITS.MaxWindows then
        error("[CrispyLib] window limit reached", 2)
    end
    local configOptions = {}
    if config.ConfigName ~= nil then configOptions.Name = config.ConfigName end
    if config.ConfigFolder ~= nil then configOptions.Folder = config.ConfigFolder end
    if config.ConfigFile ~= nil then configOptions.File = config.ConfigFile end
    if config.ConfigStorage ~= nil then configOptions.Storage = config.ConfigStorage end
    if config.ConfigCallbacks ~= nil then configOptions.ApplyCallbacks = config.ConfigCallbacks end
    if next(configOptions) ~= nil then
        local configured, configError = Config.Configure(configOptions)
        if not configured then error("[CrispyLib] " .. tostring(configError), 2) end
    end
    local title = normalizeText(config.Title, "Crispy Hub")
    local screenGui, guiError = createWindowScreenGui(title, config)
    if screenGui == nil then
        error("[CrispyLib] cannot parent window: " .. tostring(guiError), 2)
    end
    local tasks = TaskGroup.new("Window:" .. title)
    local window = newWindowState(title, screenGui, tasks, config)
    initializeWindowView(window, config)
    wireWindowLifecycle(window)
    applyWindowConfig(window, config)
    return window
end

function CrispyLib.CreateWindow(first, second)
    return createWindow(normalizeConfig(first, second, CrispyLib))
end

function TabMethods:_setActive(active)
    self._scroll.Visible = active
    if active then
        UI.Tween(self._button, { BackgroundTransparency = 0.14, BackgroundColor3 = ThemeManager.Values.TabHover }, TWEEN.Medium)
        UI.Tween(self._indicator, { BackgroundTransparency = 0 }, TWEEN.Medium)
        UI.Tween(self._tabStroke, { Transparency = 0.48, Color = ThemeManager.Values.GlassHighlight }, TWEEN.Medium)
        self._icon.TextColor3 = ThemeManager.Values.TabActiveText
        self._buttonLabel.TextColor3 = ThemeManager.Values.TabActiveText
        self._buttonLabel.Font = Enum.Font.GothamSemibold
    else
        UI.Tween(self._button, { BackgroundTransparency = 1 }, TWEEN.Medium)
        UI.Tween(self._indicator, { BackgroundTransparency = 1 }, TWEEN.Medium)
        UI.Tween(self._tabStroke, { Transparency = 1 }, TWEEN.Medium)
        self._icon.TextColor3 = ThemeManager.Values.TabInactive
        self._buttonLabel.TextColor3 = ThemeManager.Values.TabInactive
        self._buttonLabel.Font = Enum.Font.Gotham
    end
end

function TabMethods:_nextOrder()
    self._order = self._order + 1
    return self._order
end

function TabMethods:_parentForComponent()
    return self._currentGroup or self._content
end

function TabMethods:_createRow(height)
    if #self._components >= LIMITS.MaxComponentsPerTab then
        error("[CrispyLib] component limit reached for tab " .. self.Name, 2)
    end
    local order = self:_nextOrder()
    local row = UI.Create("Frame", {
        Name = "Row_" .. tostring(order),
        Size = UDim2.new(1, 0, 0, clamp(numberOr(height, DEFAULTS.RowHeight), 28, 1000)),
        BackgroundTransparency = ThemeManager.Values.RowTransparency,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = Z_INDEX.Content + 1,
        Parent = self:_parentForComponent(),
        Theme = { BackgroundColor3 = "RowBg", BackgroundTransparency = "RowTransparency" },
    })
    UI.Round(row, 13)
    UI.Stroke(row, nil, 1, 0.58)
    UI.Gradient(row, "SurfaceGradientStart", "SurfaceGradientEnd", 115, 0.06)
    local hover = UI.Create("Frame", {
        Name = "Hover",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 1,
        Parent = row,
        Theme = { BackgroundColor3 = "RowHover" },
    })
    UI.Round(hover, 13)
    return row, hover
end

function TabMethods:_createStandalone(height, name)
    if #self._components >= LIMITS.MaxComponentsPerTab then
        error("[CrispyLib] component limit reached for tab " .. self.Name, 2)
    end
    local order = self:_nextOrder()
    local root = UI.Create("Frame", {
        Name = name or ("Row_" .. tostring(order)),
        Size = UDim2.new(1, 0, 0, clamp(numberOr(height, 100), 1, 4000)),
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = Z_INDEX.Content + 1,
        Parent = self:_parentForComponent(),
        Theme = { BackgroundColor3 = "RowBg", BackgroundTransparency = "RowTransparency" },
    })
    UI.Round(root, 13)
    UI.Stroke(root, nil, 1, 0.58)
    UI.Gradient(root, "SurfaceGradientStart", "SurfaceGradientEnd", 115, 0.06)
    return root
end

function TabMethods:_createLabels(row, name, description)
    local hasDescription = description ~= nil and tostring(description) ~= ""
    local label = UI.Create("TextLabel", {
        Name = "Name",
        Size = UDim2.new(0.56, -20, 0, 18),
        Position = hasDescription and UDim2.fromOffset(16, 15) or UDim2.new(0, 16, 0.5, -9),
        BackgroundTransparency = 1,
        Text = normalizeText(name, ""),
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_INDEX.Content + 3,
        Parent = row,
        Theme = { TextColor3 = "LabelText" },
    })
    local descriptionLabel
    if hasDescription then
        descriptionLabel = UI.Create("TextLabel", {
            Name = "Description",
            Size = UDim2.new(0.62, -20, 0, 14),
            Position = UDim2.fromOffset(16, 37),
            BackgroundTransparency = 1,
            Text = tostring(description),
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = Z_INDEX.Content + 3,
            Parent = row,
            Theme = { TextColor3 = "DescText" },
        })
    end
    return label, descriptionLabel
end

function TabMethods:_adoptComponent(component)
    if #self._components >= LIMITS.MaxComponentsPerTab then
        error("[CrispyLib] component limit reached for tab " .. self.Name, 2)
    end
    self._components[#self._components + 1] = component
    self._searchables[#self._searchables + 1] = component
    self._tasks:Add(component)

    local hover = component._root:FindFirstChild("Hover")
    if hover ~= nil and hover:IsA("GuiObject") then
        component._tasks:Connect(component._root.MouseEnter, function()
            if component._enabled then
                UI.Tween(hover, { BackgroundTransparency = 0.9 }, TWEEN.Fast)
            end
        end)
        component._tasks:Connect(component._root.MouseLeave, function()
            UI.Tween(hover, { BackgroundTransparency = 1 }, TWEEN.Fast)
        end)
    end
end

function TabMethods:_forgetComponent(component)
    removeArrayValue(self._components, component, LIMITS.MaxComponentsPerTab)
    removeArrayValue(self._searchables, component, LIMITS.MaxComponentsPerTab)
    if component.Flag ~= nil then
        self._window:_unregisterComponent(component.Flag, component)
    end
end

function TabMethods:_search(query)
    local needle = normalizeText(query, ""):lower()
    local count = math.min(#self._searchables, LIMITS.MaxComponentsPerTab)
    for index = 1, count do
        local component = self._searchables[index]
        if not component._destroyed and component._root.Parent ~= nil then
            component._root.Visible = needle == "" or component._searchText:find(needle, 1, true) ~= nil
        end
    end
    local sectionCount = math.min(#self._sections, LIMITS.MaxComponentsPerTab)
    for index = 1, sectionCount do
        local section = self._sections[index]
        if section.Wrapper.Parent ~= nil then
            local visible = needle == ""
            if not visible then
                local children = section.Group:GetChildren()
                local childCount = math.min(#children, LIMITS.MaxComponentsPerTab)
                for childIndex = 1, childCount do
                    local child = children[childIndex]
                    if child:IsA("GuiObject") and child.Visible then
                        visible = true
                        break
                    end
                end
            end
            section.Wrapper.Visible = visible
        end
    end
end

local function createSectionHeader(parent, config)
    local hasDescription = config.Description ~= nil and tostring(config.Description) ~= ""
    local header = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, hasDescription and 56 or 40),
        BackgroundTransparency = 1,
        ZIndex = Z_INDEX.Content + 1,
        Parent = parent,
    })
    UI.Create("TextLabel", {
        Size = UDim2.new(0.75, 0, 0, 19), Position = UDim2.fromOffset(0, hasDescription and 7 or 11),
        BackgroundTransparency = 1, Text = normalizeText(config.Title, ""), TextSize = 15,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Content + 2, Parent = header, Theme = { TextColor3 = "TitleText" },
    })
    if hasDescription then
        UI.Create("TextLabel", {
            Size = UDim2.new(0.8, 0, 0, 15), Position = UDim2.fromOffset(0, 31),
            BackgroundTransparency = 1, Text = tostring(config.Description), TextSize = 9,
            Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = Z_INDEX.Content + 2, Parent = header, Theme = { TextColor3 = "DescText" },
        })
    end
    if config.Status ~= nil then
        local statusColor = robloxType(config.StatusColor) == "Color3" and config.StatusColor or nil
        UI.Create("TextLabel", {
            Size = UDim2.fromOffset(100, 18), Position = UDim2.new(1, -100, 0, 9),
            BackgroundTransparency = 1, Text = normalizeText(config.Status, ""), TextSize = 8,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = Z_INDEX.Content + 2, Parent = header,
            TextColor3 = statusColor or ThemeManager.Values.NotificationSuccess,
            Theme = statusColor == nil and { TextColor3 = "NotificationSuccess" } or nil,
        })
    end
    return header
end

function TabMethods:AddSection(config)
    config = type(config) == "table" and config or {}
    if #self._sections >= LIMITS.MaxComponentsPerTab then
        error("[CrispyLib] section limit reached for tab " .. self.Name, 2)
    end
    local order = self:_nextOrder()
    local wrapper = UI.Create("Frame", {
        Name = "Section_" .. tostring(order), Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        LayoutOrder = order, ZIndex = Z_INDEX.Content + 1, Parent = self._content,
    })
    UI.List(wrapper, Enum.FillDirection.Vertical, 10)
    local header = createSectionHeader(wrapper, config)
    local group = UI.Create("Frame", {
        Name = "Group", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false,
        ZIndex = Z_INDEX.Content + 1, Parent = wrapper,
    })
    UI.List(group, Enum.FillDirection.Vertical, 10)
    self._currentGroup = group
    local section = { Wrapper = wrapper, Header = header, Group = group }
    self._sections[#self._sections + 1] = section
    return section
end

function TabMethods:GroupEnd()
    self._currentGroup = nil
    return self
end

function TabMethods:SetBadge(value)
    local number = math.max(math.floor(numberOr(value, 0)), 0)
    if self._badge == nil then
        local badge = UI.Create("TextLabel", {
            Name = "Badge", Size = UDim2.fromOffset(24, 18), Position = UDim2.new(1, -6, 0.5, -9),
            AnchorPoint = Vector2.new(1, 0), BorderSizePixel = 0, Text = "", TextSize = 9,
            Font = Enum.Font.GothamBold, ZIndex = Z_INDEX.Sidebar + 4, Parent = self._button,
            Theme = { BackgroundColor3 = "NotificationError", TextColor3 = "TabActiveText" },
        })
        UI.Round(badge, 9)
        self._badge = badge
    end
    self._badge.Text = number > 99 and "99+" or tostring(number)
    self._badge.Visible = number > 0
    return self
end

function TabMethods:ClearBadge()
    if self._badge ~= nil then
        self._badge.Visible = false
    end
    return self
end

function TabMethods:Clear()
    for index = math.min(#self._components, LIMITS.MaxComponentsPerTab), 1, -1 do
        local component = self._components[index]
        if component ~= nil then
            component:Destroy()
        end
    end
    local children = self._content:GetChildren()
    local count = math.min(#children, LIMITS.MaxComponentsPerTab * 2)
    for index = 1, count do
        local child = children[index]
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    self._components = {}
    self._searchables = {}
    self._sections = {}
    self._currentGroup = nil
    self._order = 0
    return self
end

function TabMethods:Remove(component)
    if type(component) == "table" and type(component.Destroy) == "function" then
        component:Destroy()
    end
    return self
end

function TabMethods:Show()
    self._scroll.Visible = true
    return self
end

function TabMethods:Hide()
    self._scroll.Visible = false
    return self
end

function TabMethods:Activate()
    self._window:_activateTab(self, true)
    return self
end

function TabMethods:SetStyle(styles, persistent)
    CrispyLib.Style(self._content, styles, persistent)
    return self
end

function TabMethods:SetOpacity(opacity)
    UI.SetOpacity(self._content, opacity)
    return self
end

function TabMethods:TaskGroup(name)
    local group = TaskGroup.new(name or ("TabTask:" .. self.Name))
    self._tasks:Add(group)
    return group
end

function TabMethods:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    self:Clear()
    if self._window._tasks:IsAlive() then
        self._window._tasks:_forget(self)
    end
    self._tasks:Destroy()
    if self._button.Parent ~= nil then self._button:Destroy() end
    if self._scroll.Parent ~= nil then self._scroll:Destroy() end
    removeArrayValue(self._window._tabs, self, LIMITS.MaxTabsPerWindow)
    removeArrayValue(self._window._history, self, LIMITS.MaxHistoryEntries)
    if self._window._activeTab == self then
        self._window._activeTab = nil
        if #self._window._tabs > 0 then
            self._window:_activateTab(self._window._tabs[1], true)
        end
    end
end

local function createControlFrame(row, width, height)
    local frame = UI.Create("Frame", {
        Size = UDim2.fromOffset(width, height),
        Position = UDim2.new(1, -(width + 16), 0.5, -math.floor(height / 2)),
        BackgroundTransparency = ThemeManager.Values.InputTransparency,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 3,
        Parent = row,
        Theme = { BackgroundColor3 = "InputBg", BackgroundTransparency = "InputTransparency" },
    })
    UI.Round(frame, 10)
    local stroke = UI.Stroke(frame, nil, 1, 0.62)
    UI.Gradient(frame, "PanelGradientStart", "PanelGradientEnd", 120, 0.08)
    return frame, stroke
end

local function makeThrottle(group, callback, interval)
    local period = math.max(numberOr(interval, 0), 0)
    local lastCall = -math.huge
    local pending
    local delayToken
    return function(...)
        local arguments = table.pack(...)
        if period == 0 or os.clock() - lastCall >= period then
            lastCall = os.clock()
            pending = nil
            safeCall(callback, unpackValues(arguments, 1, arguments.n))
            return
        end
        pending = arguments
        if delayToken ~= nil and delayToken.Alive then
            return
        end
        delayToken = group:Delay(period - (os.clock() - lastCall), function()
            lastCall = os.clock()
            local queued = pending
            pending = nil
            delayToken = nil
            if queued ~= nil then
                safeCall(callback, unpackValues(queued, 1, queued.n))
            end
        end)
    end
end

local function normalizedRange(minimum, maximum, fallbackMinimum, fallbackMaximum)
    local minValue = numberOr(minimum, fallbackMinimum)
    local maxValue = numberOr(maximum, fallbackMaximum)
    if minValue > maxValue then
        minValue, maxValue = maxValue, minValue
    end
    return minValue, maxValue
end

local function snapNumber(value, minimum, maximum, step)
    local fallback = 0
    if isFiniteNumber(minimum) then
        fallback = minimum
    elseif isFiniteNumber(maximum) and maximum < 0 then
        fallback = maximum
    end
    local number = numberOr(value, fallback)
    local increment = math.abs(numberOr(step, 1))
    if increment == 0 then
        increment = 1
    end
    local anchor = isFiniteNumber(minimum) and minimum or 0
    number = anchor + math.floor(((number - anchor) / increment) + 0.5) * increment
    return clamp(number, minimum, maximum)
end

local function formatNumber(value)
    if not isFiniteNumber(value) then
        return "0"
    end
    if math.abs(value - math.floor(value + 0.5)) < 0.0000001 then
        return tostring(math.floor(value + 0.5))
    end
    local text = string.format("%.6f", value)
    return text:gsub("0+$", ""):gsub("%.$", "")
end

function TabMethods:AddLabel(config)
    config = type(config) == "table" and config or {}
    local row = self:_createRow()
    local nameLabel, descriptionLabel = self:_createLabels(row, config.Name, config.Description)
    local valueLabel = UI.Create("TextLabel", {
        Name = "Value",
        Size = UDim2.new(0.42, -20, 1, 0),
        Position = UDim2.new(0.58, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = normalizeText(config.Value, ""),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_INDEX.Content + 3,
        Parent = row,
        Theme = { TextColor3 = "ValueText" },
    })
    UI.Padding(valueLabel, 0, 20, 0, 0)

    local component = newComponent(self, row, nameLabel, descriptionLabel)
    function component:Set(value)
        valueLabel.Text = normalizeText(value, "")
        return self
    end
    function component:Get()
        return valueLabel.Text
    end
    return component
end

do -- Toggle control helpers.
local function updateToggleVisual(component, animated)
    local track = component._track
    local knob = component._knob
    local trackColor = component._value and ThemeManager.Values.Accent or ThemeManager.Values.ToggleOff
    local knobPosition = component._value and UDim2.new(0, 22, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
    component._trackGradient.Enabled = component._value
    if animated then
        UI.Tween(track, { BackgroundColor3 = trackColor }, TWEEN.Medium)
        UI.Tween(knob, { Position = knobPosition }, TWEEN.Medium)
    else
        track.BackgroundColor3 = trackColor
        knob.Position = knobPosition
    end
end

local function createToggleView(tab, config)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local track = UI.Create("Frame", {
        Name = "ToggleTrack", Size = UDim2.fromOffset(46, 26),
        Position = UDim2.new(1, -62, 0.5, -13),
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 3,
        Parent = row,
    })
    UI.Round(track, 13)
    UI.Stroke(track, nil, 1, 0.66)
    local trackGradient = UI.Gradient(track, "AccentGradientStart", "AccentGradientEnd", 15, 0)
    trackGradient.Enabled = false
    local knob = UI.Create("Frame", {
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 4,
        Parent = track,
        Theme = { BackgroundColor3 = "ToggleKnob" },
    })
    UI.Round(knob, 11)
    UI.Stroke(knob, ThemeManager.Values.GlassHighlight, 1, 0.48)
    local button = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = Z_INDEX.Content + 5,
        Parent = track,
    })
    button.Size, button.Position = UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0.5, -22)
    return row, nameLabel, descriptionLabel, track, knob, button, trackGradient
end

local function installToggleMethods(component, button, track, config)
    ThemeManager.Bind(track, {
        BackgroundColor3 = function()
            return component._value and ThemeManager.Values.Accent or ThemeManager.Values.ToggleOff
        end,
    })
    function component:Set(value, silent)
        local nextValue = value == true
        local previous = self._value
        self._value = nextValue
        updateToggleVisual(self, true)
        if previous ~= nextValue then
            self:_publish(nextValue, previous, config.Callback, silent)
        end
        return self
    end
    function component:Get()
        return self._value
    end
    component._applyEnabled = function(self, enabled)
        button.Active = enabled
        UI.Tween(track, { BackgroundTransparency = enabled and 0 or 0.5 }, TWEEN.Fast)
    end
    component._tasks:Connect(button.Activated, function()
        if component._enabled then
            component:Set(not component._value)
        end
    end)
end

function TabMethods:AddToggle(config)
    config = type(config) == "table" and config or {}
    local row, nameLabel, descriptionLabel, track, knob, button, trackGradient = createToggleView(self, config)
    local component = newComponent(self, row, nameLabel, descriptionLabel, config.Flag, config)
    component._value, component._track, component._knob = config.Default == true, track, knob
    component._trackGradient = trackGradient
    installToggleMethods(component, button, track, config)
    updateToggleVisual(component, false)
    registerComponentFlag(component, function()
        return component._value
    end, function(value)
        component:Set(value, true)
    end)
    return component
end

end

do -- Input control helpers.
local function normalizeInputValue(config, text, minimum, maximum, step)
    if config.Numeric ~= true then
        return normalizeText(text, "")
    end
    local fallback = numberOr(config.Default, 0)
    return snapNumber(numberOr(text, fallback), minimum, maximum, step)
end

local function createInputComponent(tab, config, minimum, maximum, step)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local holder, stroke = createControlFrame(row, 168, 30)
    local textBox = UI.Create("TextBox", {
        Size = UDim2.new(1, -18, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = normalizeText(config.Default, ""),
        PlaceholderText = normalizeText(config.Placeholder, ""),
        ClearTextOnFocus = false,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Content + 4,
        Parent = holder,
        Theme = { TextColor3 = "LabelText", PlaceholderColor3 = "Placeholder" },
    })
    local component = newComponent(tab, row, nameLabel, descriptionLabel, config.Flag, config)
    component._value = normalizeInputValue(config, config.Default, minimum, maximum, step)
    component._inputConfig, component._minimum, component._maximum = config, minimum, maximum
    component._step, component._textBox, component._inputHolder = step, textBox, holder
    component._inputStroke = stroke
    ThemeManager.Bind(holder, {
        BackgroundColor3 = function()
            return component._enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
        end,
    })
    ThemeManager.Bind(textBox, {
        TextColor3 = function()
            return component._enabled and ThemeManager.Values.LabelText or ThemeManager.Values.DisabledText
        end,
        PlaceholderColor3 = "Placeholder",
    })
    textBox.Text = config.Numeric == true and formatNumber(component._value) or component._value
    return component
end

local function setInputValue(component, value, silent, submitted)
    local config = component._inputConfig
    local nextValue = normalizeInputValue(config, value, component._minimum, component._maximum, component._step)
    local previous = component._value
    component._value = nextValue
    component._textBox.Text = config.Numeric == true and formatNumber(nextValue) or nextValue
    if not valuesEqual(previous, nextValue) then
        if component.Flag ~= nil then State.Set(component.Flag, nextValue, component) else component:_FireChanged(nextValue, previous) end
        if not silent and type(config.Callback) == "function" then
            safeCall(config.Callback, nextValue, submitted == true)
        end
    end
    return component
end

local function wireInputComponent(component)
    local textBox, holder, stroke = component._textBox, component._inputHolder, component._inputStroke
    component._applyEnabled = function(_, enabled)
        textBox.TextEditable = enabled
        ThemeManager.ApplyBinding(holder, ThemeManager._bindings[holder])
    end
    component._tasks:Connect(textBox.Focused, function()
        if not component._enabled then
            textBox:ReleaseFocus()
            return
        end
        UI.Tween(stroke, { Color = ThemeManager.Values.FocusBorder, Thickness = 1.5 }, TWEEN.Fast)
    end)
    component._tasks:Connect(textBox.FocusLost, function()
        UI.Tween(stroke, { Color = ThemeManager.Values.Border, Thickness = 1 }, TWEEN.Fast)
        if component._enabled then
            setInputValue(component, textBox.Text, false, true)
        else
            textBox.Text = component._inputConfig.Numeric == true and formatNumber(component._value) or component._value
        end
    end)
end

function TabMethods:AddInput(config)
    config = type(config) == "table" and config or {}
    local minimum, maximum = normalizedRange(config.Min, config.Max, -math.huge, math.huge)
    local component = createInputComponent(self, config, minimum, maximum, math.abs(numberOr(config.Step, 1)))
    component.Set = function(self, value, silent) return setInputValue(self, value, silent, false) end
    component.Get = function(self) return self._value end
    component.SetPlaceholder = function(self, text) self._textBox.PlaceholderText = normalizeText(text, ""); return self end
    wireInputComponent(component)
    registerComponentFlag(component, function()
        return component._value
    end, function(value)
        setInputValue(component, value, true, false)
    end)
    return component
end

function TabMethods:AddSearchBox(config)
    config = type(config) == "table" and shallowCopy(config, 64) or {}
    config.Placeholder = config.Placeholder or "Search..."
    return self:AddInput(config)
end

end

do -- Slider control helpers.
local function updateSliderVisual(component)
    local range = component._maximum - component._minimum
    local fraction = range == 0 and 0 or ((component._value - component._minimum) / range)
    fraction = clamp(fraction, 0, 1)
    component._fill.Size = UDim2.new(fraction, 0, 1, 0)
    component._knob.Position = UDim2.new(fraction, 0, 0.5, 0)
    component._valueLabel.Text = formatNumber(component._value) .. component._suffix
end

local function createSliderComponent(tab, config, minimum, maximum, step)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local trackWidth = clamp(numberOr(config.Width, 170), 120, 280)
    local valueLabel = UI.Create("TextLabel", {
        Name = "SliderValue", Size = UDim2.fromOffset(trackWidth, 15), Position = UDim2.new(1, -(trackWidth + 16), 0, 13),
        BackgroundTransparency = 1, Text = "", TextSize = 10, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = Z_INDEX.Content + 3, Parent = row, Theme = { TextColor3 = "Accent" },
    })
    local track = UI.Create("Frame", {
        Name = "SliderTrack", Size = UDim2.fromOffset(trackWidth, 6), Position = UDim2.new(1, -(trackWidth + 16), 0.5, 7),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0, Active = true, ZIndex = Z_INDEX.Content + 3, Parent = row,
        Theme = { BackgroundColor3 = "ToggleOff" },
    })
    UI.Round(track, 3)
    UI.Stroke(track, nil, 1, 0.76)
    local fill = UI.Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 4, Parent = track, Theme = { BackgroundColor3 = "Accent" },
    })
    UI.Round(fill, 3)
    UI.Gradient(fill, "AccentGradientStart", "AccentGradientEnd", 0, 0)
    local knob = UI.Create("Frame", {
        Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 5, Parent = track,
    })
    UI.Round(knob, 9)
    ThemeManager.Bind(UI.Stroke(knob, ThemeManager.Values.Accent, 2, 0.18), { Color = "Accent" })

    local component = newComponent(tab, row, nameLabel, descriptionLabel, config.Flag, config)
    component._minimum, component._maximum = minimum, maximum
    component._step = step == 0 and 1 or step
    component._suffix = normalizeText(config.Suffix, "")
    component._value = snapNumber(config.Default, minimum, maximum, component._step)
    component._fill, component._knob, component._valueLabel = fill, knob, valueLabel
    component._track, component._callback = track, config.Callback
    component._sliderHit = UI.Create("TextButton", {
        Name = "SliderHit", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0.5, -22),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        ZIndex = Z_INDEX.Content + 6, Parent = track,
    })
    component._throttledCallback = makeThrottle(component._tasks, function(value)
        if type(component._callback) == "function" then safeCall(component._callback, value) end
    end, config.Throttle or 0.035)
    return component
end

local function setSliderValue(component, value, silent, fromPointer)
    local nextValue = snapNumber(value, component._minimum, component._maximum, component._step)
    local previous = component._value
    component._value = nextValue
    updateSliderVisual(component)
    if previous ~= nextValue then
        if component.Flag ~= nil then State.Set(component.Flag, nextValue, component) else component:_FireChanged(nextValue, previous) end
        if not silent then
            if fromPointer then
                component._throttledCallback(nextValue)
            elseif type(component._callback) == "function" then
                safeCall(component._callback, nextValue)
            end
        end
    end
    return component
end

local function updateSliderFromPosition(component, position)
    local width = math.max(component._track.AbsoluteSize.X, 1)
    local fraction = clamp((position.X - component._track.AbsolutePosition.X) / width, 0, 1)
    setSliderValue(component, component._minimum + fraction * (component._maximum - component._minimum), false, true)
end

function TabMethods:AddSlider(config)
    config = type(config) == "table" and config or {}
    local minimum, maximum = normalizedRange(config.Min, config.Max, 0, 100)
    local component = createSliderComponent(self, config, minimum, maximum, math.abs(numberOr(config.Step, 1)))
    component.Set = function(self, value, silent) return setSliderValue(self, value, silent, false) end
    component.Get = function(self) return self._value end
    component.SetMin = function(self, value) self._minimum, self._maximum = normalizedRange(value, self._maximum, self._minimum, self._maximum); return setSliderValue(self, self._value, true, false) end
    component.SetMax = function(self, value) self._minimum, self._maximum = normalizedRange(self._minimum, value, self._minimum, self._maximum); return setSliderValue(self, self._value, true, false) end
    component.SetRange = function(self, minValue, maxValue) self._minimum, self._maximum = normalizedRange(minValue, maxValue, self._minimum, self._maximum); return setSliderValue(self, self._value, true, false) end
    component._applyEnabled = function(_, enabled)
        component._track.Active = enabled
        component._sliderHit.Active = enabled
        UI.Tween(component._track, { BackgroundTransparency = enabled and 0.05 or 0.5 }, TWEEN.Fast)
    end
    component._tasks:Connect(component._sliderHit.InputBegan, function(input)
        if not component._enabled then return end
        local accepted = self._window._input:BeginPointer(input, function(position) updateSliderFromPosition(component, position) end, function()
            UI.Tween(component._knob, { Size = UDim2.fromOffset(18, 18) }, TWEEN.Fast)
        end, component)
        if accepted then UI.Tween(component._knob, { Size = UDim2.fromOffset(21, 21) }, TWEEN.Fast) end
    end)
    updateSliderVisual(component)
    registerComponentFlag(component, function() return component._value end, function(value) setSliderValue(component, value, true, false) end)
    return component
end

end

function TabMethods:AddButton(config)
    config = type(config) == "table" and config or {}
    local row = self:_createRow()
    local nameLabel, descriptionLabel = self:_createLabels(row, config.Name, config.Description)
    local button = UI.Create("TextButton", {
        Size = UDim2.fromOffset(92, 30), Position = UDim2.new(1, -108, 0.5, -15),
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0, Text = normalizeText(config.Label, "Run"), TextSize = 12,
        Font = Enum.Font.GothamSemibold, AutoButtonColor = false,
        ZIndex = Z_INDEX.Content + 3, Parent = row,
        Theme = { BackgroundColor3 = "Accent", TextColor3 = "TabActiveText" },
    })
    UI.Round(button, 10)
    UI.Stroke(button, ThemeManager.Values.GlassHighlight, 1, 0.62)
    local buttonGradient = UI.Gradient(button, "AccentGradientStart", "AccentGradientEnd", 15, 0)
    local component = newComponent(self, row, nameLabel, descriptionLabel)
    component._loading = false
    component._buttonGradient = buttonGradient
    component._buttonText = button.Text
    ThemeManager.Bind(button, {
        BackgroundColor3 = function()
            return component._enabled and ThemeManager.Values.Accent or ThemeManager.Values.DisabledBg
        end,
        TextColor3 = function()
            return component._enabled and ThemeManager.Values.TabActiveText or ThemeManager.Values.DisabledText
        end,
    })
    button.Active = component._enabled
    button.TextTransparency = component._enabled and 0 or 0.5
    function component:SetLabel(text)
        self._buttonText = normalizeText(text, "")
        if not self._loading then button.Text = self._buttonText end
        return self
    end
    function component:SetLoading(state)
        self._loading = state == true
        button.Text = self._loading and "..." or self._buttonText
        button.BackgroundTransparency = self._loading and 0.3 or 0.06
        self._buttonGradient.Enabled = not self._loading and self._enabled
        return self
    end
    component._applyEnabled = function(_, enabled)
        button.Active = enabled
        buttonGradient.Enabled = enabled
        button.BackgroundColor3 = enabled and ThemeManager.Values.Accent or ThemeManager.Values.DisabledBg
        button.TextColor3 = enabled and ThemeManager.Values.TabActiveText or ThemeManager.Values.DisabledText
    end
    UI.Hover(component._tasks, button, "Accent", "AccentHover", "AccentPress")
    local activate = component._tasks:Wrap(function()
        if component._enabled and not component._loading then
            safeCall(config.Callback or function() end)
        end
    end, { Debounce = 0.25 })
    component._tasks:Connect(button.Activated, activate)
    return component
end

do -- Keybind control helpers.
local function keyCodeFrom(value)
    if isKeyCode(value) then
        return value
    end
    if type(value) == "string" then
        local ok, key = pcall(function()
            return Enum.KeyCode[value]
        end)
        if ok and key ~= nil then
            return key
        end
    end
    return Enum.KeyCode.Unknown
end

local function createKeybindView(tab, config)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local holder, stroke = createControlFrame(row, 106, 30)
    local button = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = "", TextSize = 12, Font = Enum.Font.GothamSemibold, AutoButtonColor = false,
        ZIndex = Z_INDEX.Content + 4, Parent = holder, Theme = { TextColor3 = "ValueText" },
    })
    return row, nameLabel, descriptionLabel, holder, stroke, button
end

local function installKeybindMethods(component, button, holder, window)
    ThemeManager.Bind(holder, {
        BackgroundColor3 = function()
            return component._enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
        end,
    })
    function component:Set(value)
        local key = keyCodeFrom(value)
        local previous = self._key
        self._key = key
        if self._updateKeyDisplay ~= nil then self._updateKeyDisplay() else button.Text = key.Name end
        if previous ~= key then
            if self.Flag ~= nil then State.Set(self.Flag, key.Name, self) else self:_FireChanged(key, previous) end
        end
        return self
    end
    function component:Get() return self._key end
    function component:SetKey(value) return self:Set(value) end
    component._applyEnabled = function(_, enabled)
        button.Active = enabled
        holder.BackgroundColor3 = enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
        if not enabled then window._input:CancelCapture(component) end
    end
end

local function wireKeybind(component, button, stroke, window, callback)
    local function displayKey()
        local mobile = window._touch and component._configSettings.MobileAction ~= false
        button.Text = mobile and "Run" or component._key.Name
    end
    function component:Trigger()
        if self._enabled and not self._destroyed then
            local action = window._touch and self._configSettings.TouchCallback or callback
            safeCall(type(action) == "function" and action or callback or function() end, self._key)
        end
        return self
    end
    component._updateKeyDisplay = displayKey
    displayKey()
    local function stopListening()
        component._listening = false
        displayKey()
        button.TextColor3 = ThemeManager.Values.ValueText
        UI.Tween(stroke, { Color = ThemeManager.Values.Border }, TWEEN.Fast)
    end
    component._tasks:Connect(button.Activated, function(input)
        if not component._enabled or component._listening then return end
        if window._touch and component._configSettings.MobileAction ~= false then component:Trigger(); return end
        component._listening = true
        button.Text = "Press..."
        button.TextColor3 = ThemeManager.Values.Accent
        UI.Tween(stroke, { Color = ThemeManager.Values.FocusBorder }, TWEEN.Fast)
        window._input:CaptureKey(component, function(key)
            component:Set(key)
            stopListening()
        end, stopListening)
    end)
    component._tasks:Add(window._input:BindKey(component, function()
        return component._key
    end, function(key)
        if component._enabled and not component._listening and key ~= Enum.KeyCode.Unknown then
            safeCall(callback or function() end, key)
        end
    end))
end

function TabMethods:AddKeybind(config)
    config = type(config) == "table" and config or {}
    local row, nameLabel, descriptionLabel, holder, stroke, button = createKeybindView(self, config)
    local component = newComponent(self, row, nameLabel, descriptionLabel, config.Flag, config)
    component._key, component._listening = keyCodeFrom(config.Default), false
    button.Text = component._key.Name
    installKeybindMethods(component, button, holder, self._window)
    wireKeybind(component, button, stroke, self._window, config.Callback)
    -- Loading a binding changes its key; it must not fire its keypress action.
    component._configKeybind = true
    component._configKeyNormalizer = function(value) return keyCodeFrom(value).Name end
    registerComponentFlag(component, function() return component._key.Name end, function(value) component:Set(value) end)
    return component
end

end

do -- Number input control helpers.
local function createNumberInputComponent(tab, config, minimum, maximum, step)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local holder = createControlFrame(row, 134, 30)
    local minusButton = UI.Create("TextButton", {
        Size = UDim2.new(0, tab._window._touch and 44 or 30, 1, 0), BackgroundTransparency = 1, Text = "-", TextSize = 16,
        Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = Z_INDEX.Content + 4, Parent = holder,
        Theme = { TextColor3 = "LabelText", BackgroundColor3 = "RowHover" },
    })
    local plusButton = UI.Create("TextButton", {
        Size = UDim2.new(0, tab._window._touch and 44 or 30, 1, 0), Position = UDim2.new(1, tab._window._touch and -44 or -30, 0, 0), BackgroundTransparency = 1,
        Text = "+", TextSize = 16, Font = Enum.Font.GothamBold, AutoButtonColor = false,
        ZIndex = Z_INDEX.Content + 4, Parent = holder, Theme = { TextColor3 = "LabelText", BackgroundColor3 = "RowHover" },
    })
    local textBox = UI.Create("TextBox", {
        Size = UDim2.new(1, tab._window._touch and -88 or -60, 1, 0), Position = UDim2.fromOffset(tab._window._touch and 44 or 30, 0), BackgroundTransparency = 1,
        Text = "", TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
        ClearTextOnFocus = false, ZIndex = Z_INDEX.Content + 4, Parent = holder,
        Theme = { TextColor3 = "LabelText" },
    })
    local component = newComponent(tab, row, nameLabel, descriptionLabel, config.Flag, config)
    component._minimum, component._maximum, component._step = minimum, maximum, step
    component._value = snapNumber(config.Default, minimum, maximum, step)
    component._holder, component._minusButton = holder, minusButton
    component._plusButton, component._textBox, component._callback = plusButton, textBox, config.Callback
    component._layoutTouch = function()
        local size = tab._window._touch and 44 or 30
        minusButton.Size = UDim2.new(0, size, 1, 0)
        plusButton.Size, plusButton.Position = UDim2.new(0, size, 1, 0), UDim2.new(1, -size, 0, 0)
        textBox.Size, textBox.Position = UDim2.new(1, -size * 2, 1, 0), UDim2.fromOffset(size, 0)
    end
    ThemeManager.Bind(holder, {
        BackgroundColor3 = function()
            return component._enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
        end,
    })
    textBox.Text = formatNumber(component._value)
    return component
end

local function setNumberInputValue(component, value, silent)
    local nextValue = snapNumber(value, component._minimum, component._maximum, component._step)
    local previous = component._value
    component._value = nextValue
    component._textBox.Text = formatNumber(nextValue)
    component:_publish(nextValue, previous, component._callback, silent)
    return component
end

local function wireNumberInput(component)
    local textBox, minusButton, plusButton = component._textBox, component._minusButton, component._plusButton
    component._applyEnabled = function(_, enabled)
        textBox.TextEditable = enabled
        minusButton.Active = enabled
        plusButton.Active = enabled
        ThemeManager.ApplyBinding(component._holder, ThemeManager._bindings[component._holder])
    end
    UI.Hover(component._tasks, minusButton, "InputBg", "RowHover", "RowBg")
    UI.Hover(component._tasks, plusButton, "InputBg", "RowHover", "RowBg")
    component._tasks:Connect(minusButton.Activated, function()
        if component._enabled then setNumberInputValue(component, component._value - component._step, false) end
    end)
    component._tasks:Connect(plusButton.Activated, function()
        if component._enabled then setNumberInputValue(component, component._value + component._step, false) end
    end)
    component._tasks:Connect(textBox.FocusLost, function()
        if component._enabled then setNumberInputValue(component, textBox.Text, false) else textBox.Text = formatNumber(component._value) end
    end)
    component._tasks:Connect(textBox.MouseWheelForward, function()
        if component._enabled then setNumberInputValue(component, component._value + component._step, false) end
    end)
    component._tasks:Connect(textBox.MouseWheelBackward, function()
        if component._enabled then setNumberInputValue(component, component._value - component._step, false) end
    end)
end

function TabMethods:AddNumberInput(config)
    config = type(config) == "table" and config or {}
    local minimum, maximum = normalizedRange(config.Min, config.Max, -math.huge, math.huge)
    local step = math.abs(numberOr(config.Step, 1))
    if step == 0 then step = 1 end
    local component = createNumberInputComponent(self, config, minimum, maximum, step)
    component.Set = setNumberInputValue
    component.Get = function(self) return self._value end
    component.SetMin = function(self, value) self._minimum, self._maximum = normalizedRange(value, self._maximum, self._minimum, self._maximum); return setNumberInputValue(self, self._value, true) end
    component.SetMax = function(self, value) self._minimum, self._maximum = normalizedRange(self._minimum, value, self._minimum, self._maximum); return setNumberInputValue(self, self._value, true) end
    component.SetRange = function(self, minValue, maxValue) self._minimum, self._maximum = normalizedRange(minValue, maxValue, self._minimum, self._maximum); return setNumberInputValue(self, self._value, true) end
    component.SetStep = function(self, value) self._step = math.max(math.abs(numberOr(value, 1)), 0.0000001); return setNumberInputValue(self, self._value, true) end
    wireNumberInput(component)
    registerComponentFlag(component, function() return component._value end, function(value) setNumberInputValue(component, value, true) end)
    return component
end

end

local function optionIndex(options, value)
    local count = math.min(#options, LIMITS.MaxOptions)
    for index = 1, count do
        if valuesEqual(options[index], value) then
            return index
        end
    end
    return nil
end

local function selectionContains(selection, value)
    return optionIndex(selection, value) ~= nil
end

local function normalizedMultiSelection(value, options)
    local result = {}
    local source = type(value) == "table" and value or { value }
    local count = math.min(#source, LIMITS.MaxOptions)
    for index = 1, count do
        local item = source[index]
        if item ~= nil and optionIndex(options, item) ~= nil and not selectionContains(result, item) then
            result[#result + 1] = item
        end
    end
    return result
end

do -- Dropdown control helpers.
local function dropdownValueText(component)
    if component._multi then
        local count = #component._selected
        if count == 0 then return "None" end
        if count == 1 then return tostring(component._selected[1]) end
        return tostring(count) .. " selected"
    end
    if component._selected == nil or component._selected == "" then
        return "None"
    end
    return tostring(component._selected)
end

local function clearGuiChildren(parent, maximum)
    local children = parent:GetChildren()
    local count = math.min(#children, maximum or LIMITS.MaxRows)
    for index = 1, count do
        if children[index]:IsA("GuiObject") then
            children[index]:Destroy()
        end
    end
end

local function positionDropdown(component, targetHeight)
    local anchor = component._dropdownButton
    local x, y, width, height = MobileUI.PopupRect(component._tab._window._viewport,
        anchor.AbsolutePosition, anchor.AbsoluteSize, component._popupWidth, targetHeight)
    component._popup.Position = UDim2.fromOffset(x, y)
    return width, height
end

local function setDropdownOpen(component, open, reflow)
    if component._destroyed then return end
    if open and not component._enabled then return end
    if component._closeToken ~= nil then
        component._tasks:Cancel(component._closeToken)
        component._closeToken = nil
    end
    component._open = open == true
    if component._open then
        if not reflow then
            component._tab._window:ClosePopups(component._popup)
            component._searchBox.Text = ""
            component:_rebuildOptions("")
        end
        component._popup.Visible = true
        local touch = component._tab._window._touch
        local headerHeight = touch and (component._multi and 116 or 62) or (component._multi and 84 or 46)
        local rows = math.min(component._renderedOptions, component._visibleLimit)
        local targetHeight = clamp(headerHeight + (rows * (touch and 46 or 31)), headerHeight + 32, touch and 380 or 330)
        local width, height = positionDropdown(component, targetHeight)
        component._searchHolder.Size = UDim2.new(1, -16, 0, touch and 44 or 30)
        component._optionScroll.Position = UDim2.fromOffset(4, touch and 58 or 42)
        component._optionScroll.Size = UDim2.new(1, -8, 1, -headerHeight)
        if component._doneButton ~= nil then
            component._doneButton.Size = UDim2.new(1, -16, 0, touch and 44 or 30)
            component._doneButton.Position = UDim2.new(0, 8, 1, touch and -51 or -37)
        end
        if not reflow then component._popup.Size = UDim2.fromOffset(width, 0) end
        UI.Tween(component._popup, { Size = UDim2.fromOffset(width, height) }, reflow and TWEEN.Instant or TWEEN.Medium)
        UI.Tween(component._dropdownStroke, { Color = ThemeManager.Values.FocusBorder }, TWEEN.Fast)
        UI.Tween(component._chevron, { Rotation = 180 }, TWEEN.Medium)
    else
        UI.Tween(component._popup, { Size = UDim2.fromOffset(component._popup.Size.X.Offset, 0) }, TWEEN.Medium)
        UI.Tween(component._dropdownStroke, { Color = ThemeManager.Values.Border }, TWEEN.Fast)
        UI.Tween(component._chevron, { Rotation = 0 }, TWEEN.Medium)
        component._closeToken = component._tasks:Delay(0.22, function()
            if not component._open and component._popup.Parent ~= nil then
                component._popup.Visible = false
            end
            component._closeToken = nil
        end)
    end
end

local function createDropdownPopupSurface(component)
    local popup = UI.Create("Frame", {
        Name = "DropdownPopup",
        Size = UDim2.fromOffset(component._popupWidth, 0),
        BackgroundTransparency = ThemeManager.Values.PopupTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = Z_INDEX.Popup,
        Parent = component._tab._window._screenGui,
        Theme = { BackgroundColor3 = "PopupBg", BackgroundTransparency = "PopupTransparency" },
    })
    UI.Round(popup, 14)
    UI.Stroke(popup, nil, 1, 0.34)
    UI.Gradient(popup, "WindowGradientStart", "WindowGradientEnd", 130, 0.06)
    return popup
end

local function createDropdownSearch(popup)
    local searchHolder = UI.Create("Frame", {
        Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 7),
        BackgroundTransparency = ThemeManager.Values.InputTransparency, BorderSizePixel = 0,
        ZIndex = Z_INDEX.Popup + 1, Parent = popup,
        Theme = { BackgroundColor3 = "InputBg", BackgroundTransparency = "InputTransparency" },
    })
    UI.Round(searchHolder, 10)
    local searchStroke = UI.Stroke(searchHolder)
    local searchBox = UI.Create("TextBox", {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
        Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false, TextSize = 12,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Popup + 2, Parent = searchHolder,
        Theme = { TextColor3 = "LabelText", PlaceholderColor3 = "Placeholder" },
    })
    return searchBox, searchStroke, searchHolder
end

local function createDropdownOptionList(component, popup)
    local scroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, component._multi and -84 or -46),
        Position = UDim2.fromOffset(4, 42), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ZIndex = Z_INDEX.Popup + 1, Parent = popup,
        Theme = { ScrollBarImageColor3 = "ScrollThumb" },
    })
    local content = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, ZIndex = Z_INDEX.Popup + 1, Parent = scroll,
    })
    UI.List(content, Enum.FillDirection.Vertical, 2)
    UI.Padding(content, 2, 0, 2, 0)
    return scroll, content
end

local function wireDropdownSearch(component, searchBox, searchStroke)
    component._tasks:Connect(searchBox.Focused, function()
        UI.Tween(searchStroke, { Color = ThemeManager.Values.FocusBorder }, TWEEN.Fast)
    end)
    component._tasks:Connect(searchBox.FocusLost, function()
        UI.Tween(searchStroke, { Color = ThemeManager.Values.Border }, TWEEN.Fast)
    end)
    component._tasks:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
        component:_rebuildOptions(searchBox.Text)
    end)
end

local function createDropdownDoneButton(component, popup)
    if not component._multi then return end
    local doneButton = UI.Create("TextButton", {
        Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 1, -37),
        BorderSizePixel = 0, Text = "Done", TextSize = 12, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, ZIndex = Z_INDEX.Popup + 2, Parent = popup,
        Theme = { BackgroundColor3 = "Accent", TextColor3 = "TabActiveText" },
    })
    UI.Round(doneButton, 7)
    UI.Hover(component._tasks, doneButton, "Accent", "AccentHover", "AccentPress")
    component._doneButton = doneButton
    component._tasks:Connect(doneButton.Activated, function()
        setDropdownOpen(component, false)
    end)
end

local function createDropdownPopup(component)
    local popup = createDropdownPopupSurface(component)
    local searchBox, searchStroke, searchHolder = createDropdownSearch(popup)
    component._searchHolder = searchHolder
    local scroll, content = createDropdownOptionList(component, popup)
    component._popup, component._searchBox = popup, searchBox
    component._optionScroll, component._optionContent = scroll, content
    wireDropdownSearch(component, searchBox, searchStroke)
    createDropdownDoneButton(component, popup)
    component._tasks:Add(popup)
    local unregister = component._tab._window:RegisterPopup(popup, function()
        setDropdownOpen(component, false)
    end, function()
        if component._open then setDropdownOpen(component, true, true) end
    end)
    component._tasks:Add(unregister)
end

local function publishDropdownSelection(component, silent)
    local output = component._multi and arrayCopy(component._selected, LIMITS.MaxOptions) or component._selected
    local previous = component._lastPublished
    component._lastPublished = component._multi and arrayCopy(output, LIMITS.MaxOptions) or output
    component._valueLabel.Text = dropdownValueText(component)
    component:_publish(output, previous, component._callback, silent)
end

local function selectDropdownOption(component, option)
    if component._multi then
        local selectedIndex = optionIndex(component._selected, option)
        if selectedIndex ~= nil then
            table.remove(component._selected, selectedIndex)
        else
            component._selected[#component._selected + 1] = option
        end
        publishDropdownSelection(component, false)
        component:_rebuildOptions(component._searchBox.Text)
    else
        component._selected = option
        publishDropdownSelection(component, false)
        setDropdownOpen(component, false)
    end
end

local function createDropdownOption(component, option, order, selected)
    local optionButton = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, component._tab._window._touch and 44 or 30), BackgroundTransparency = selected and 0.78 or 1,
        BorderSizePixel = 0, Text = tostring(option), TextSize = 12, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
        LayoutOrder = order, ZIndex = Z_INDEX.Popup + 2, Parent = component._optionContent,
        Theme = { BackgroundColor3 = selected and "Accent" or "ItemHover", TextColor3 = selected and "TabActiveText" or "LabelText" },
    })
    UI.Padding(optionButton, 0, 8, 0, 10)
    UI.Round(optionButton, 6)
    component._optionTasks:Connect(optionButton.MouseEnter, function()
        if not selected then UI.Tween(optionButton, { BackgroundTransparency = 0.35 }, TWEEN.Fast) end
    end)
    component._optionTasks:Connect(optionButton.MouseLeave, function()
        if not selected then UI.Tween(optionButton, { BackgroundTransparency = 1 }, TWEEN.Fast) end
    end)
    component._optionTasks:Connect(optionButton.Activated, function()
        selectDropdownOption(component, option)
    end)
end

local function rebuildDropdownOptions(component, filter)
    if component._optionTasks ~= nil then component._optionTasks:Destroy() end
    component._optionTasks = TaskGroup.new("DropdownOptions")
    clearGuiChildren(component._optionContent, LIMITS.MaxDropdownRender + 8)
    local needle = normalizeText(filter, ""):lower()
    local rendered = 0
    local optionCount = math.min(#component._options, LIMITS.MaxOptions)
    for index = 1, optionCount do
        if rendered >= component._visibleLimit then break end
        local option = component._options[index]
        local text = tostring(option)
        if needle == "" or text:lower():find(needle, 1, true) ~= nil then
            rendered = rendered + 1
            local selected = component._multi and selectionContains(component._selected, option)
                or valuesEqual(component._selected, option)
            createDropdownOption(component, option, rendered, selected)
        end
    end
    component._renderedOptions = rendered
end

local function setDropdownValue(component, value, silent)
    if component._multi then
        component._selected = normalizedMultiSelection(value, component._options)
    elseif optionIndex(component._options, value) ~= nil or value == "" then
        component._selected = value
    else
        return component
    end
    publishDropdownSelection(component, silent)
    if component._open then component:_rebuildOptions(component._searchBox.Text) end
    return component
end

local function setDropdownOptions(component, values)
    component._options = arrayCopy(values or {}, LIMITS.MaxOptions)
    if component._multi then
        component._selected = normalizedMultiSelection(component._selected, component._options)
    elseif optionIndex(component._options, component._selected) == nil then
        component._selected = component._options[1] or ""
    end
    publishDropdownSelection(component, true)
    if component._open then component:_rebuildOptions(component._searchBox.Text) end
    return component
end

local function removeDropdownItem(component, value)
    local index = optionIndex(component._options, value)
    if index ~= nil then table.remove(component._options, index) end
    if component._multi then
        local selectedIndex = optionIndex(component._selected, value)
        if selectedIndex ~= nil then table.remove(component._selected, selectedIndex) end
    elseif valuesEqual(component._selected, value) then
        component._selected = component._options[1] or ""
    end
    publishDropdownSelection(component, true)
    if component._open then component:_rebuildOptions(component._searchBox.Text) end
    return component
end

local function createDropdownComponent(tab, config, options, selected, multi)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local button = UI.Create("TextButton", {
        Size = UDim2.fromOffset(170, 30), Position = UDim2.new(1, -186, 0.5, -15),
        BackgroundTransparency = ThemeManager.Values.InputTransparency,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        ZIndex = Z_INDEX.Content + 3, Parent = row, Theme = { BackgroundColor3 = "InputBg" },
    })
    UI.Round(button, 10)
    local stroke = UI.Stroke(button)
    UI.Gradient(button, "PanelGradientStart", "PanelGradientEnd", 115, 0.18)
    local valueLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
        Text = "", TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Z_INDEX.Content + 4, Parent = button,
        Theme = { TextColor3 = "LabelText" },
    })
    local chevron = UI.Create("TextLabel", {
        Size = UDim2.fromOffset(24, 30), Position = UDim2.new(1, -26, 0, 0), BackgroundTransparency = 1,
        Text = "v", TextSize = 11, Font = Enum.Font.GothamBold,
        ZIndex = Z_INDEX.Content + 4, Parent = button, Theme = { TextColor3 = "SubtitleText" },
    })
    local component = newComponent(tab, row, nameLabel, descriptionLabel, config.Flag, config)
    component._options, component._selected, component._multi = options, selected, multi
    component._open, component._renderedOptions, component._optionTasks = false, 0, nil
    component._popupWidth = clamp(numberOr(config.Width, 210), 170, 480)
    component._visibleLimit = clamp(math.floor(numberOr(config.MaxVisibleItems or config.VirtualLimit, 200)), 1, LIMITS.MaxDropdownRender)
    component._dropdownButton, component._dropdownStroke = button, stroke
    component._valueLabel, component._chevron, component._callback = valueLabel, chevron, config.Callback
    ThemeManager.Bind(button, {
        BackgroundColor3 = function()
            return component._enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
        end,
        BackgroundTransparency = function(theme)
            return component._enabled and theme.InputTransparency or 0.22
        end,
    })
    valueLabel.Text = dropdownValueText(component)
    return component
end

function TabMethods:AddDropdown(config)
    config = type(config) == "table" and config or {}
    local options = arrayCopy(config.Options or {}, LIMITS.MaxOptions)
    local multi = config.Multi == true
    local selected = multi and normalizedMultiSelection(config.Default or {}, options) or config.Default
    if not multi and selected == nil then selected = options[1] or "" end
    local component = createDropdownComponent(self, config, options, selected, multi)
    component._rebuildOptions = rebuildDropdownOptions
    component.Set = setDropdownValue
    component.Get = function(self) return self._multi and arrayCopy(self._selected, LIMITS.MaxOptions) or self._selected end
    component.SetOptions = setDropdownOptions
    component.AddItem = function(self, value)
        if #self._options < LIMITS.MaxOptions and optionIndex(self._options, value) == nil then
            self._options[#self._options + 1] = value
            if self._open then self:_rebuildOptions(self._searchBox.Text) end
        end
        return self
    end
    component.RemoveItem = removeDropdownItem
    component.ClearItems = function(self)
        self._options, self._selected = {}, self._multi and {} or ""
        publishDropdownSelection(self, true)
        if self._open then self:_rebuildOptions("") end
        return self
    end
    component._applyEnabled = function(_, enabled)
        component._dropdownButton.Active = enabled
        ThemeManager.ApplyBinding(component._dropdownButton, ThemeManager._bindings[component._dropdownButton])
        if not enabled then setDropdownOpen(component, false) end
    end
    component._tasks:Connect(component._dropdownButton.Activated, function()
        if component._enabled then setDropdownOpen(component, not component._open) end
    end)
    component._tasks:Add(function() if component._optionTasks ~= nil then component._optionTasks:Destroy() end end)
    createDropdownPopup(component)
    component._lastPublished = component:Get()
    registerComponentFlag(component, function() return component:Get() end, function(value) component:Set(value, true) end)
    return component
end

function TabMethods:AddCheckboxGroup(config)
    local copy = type(config) == "table" and shallowCopy(config, 64) or {}
    copy.Multi = true
    return self:AddDropdown(copy)
end

end

function TabMethods:AddTextArea(config)
    config = type(config) == "table" and config or {}
    local height = clamp(numberOr(config.Height, 120), 90, 600)
    local row = self:_createRow(height)
    local nameLabel, descriptionLabel = self:_createLabels(row, config.Name, config.Description)
    local holder = UI.Create("Frame", {
        Size = UDim2.new(1, -34, 1, -48), Position = UDim2.fromOffset(17, 42),
        BackgroundTransparency = ThemeManager.Values.InputTransparency,
        BorderSizePixel = 0, ZIndex = Z_INDEX.Content + 3, Parent = row,
        Theme = { BackgroundColor3 = "InputBg", BackgroundTransparency = "InputTransparency" },
    })
    UI.Round(holder, 12)
    local stroke = UI.Stroke(holder)
    UI.Gradient(holder, "PanelGradientStart", "PanelGradientEnd", 115, 0.18)
    local textBox = UI.Create("TextBox", {
        Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = normalizeText(config.Default, ""), PlaceholderText = normalizeText(config.Placeholder, ""),
        ClearTextOnFocus = false, MultiLine = true, TextWrapped = true,
        TextSize = 12, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = Z_INDEX.Content + 4, Parent = holder,
        Theme = { TextColor3 = "LabelText", PlaceholderColor3 = "Placeholder" },
    })
    local component = newComponent(self, row, nameLabel, descriptionLabel, config.Flag, config)
    component._value = textBox.Text
    local function apply(value, silent, submitted)
        local nextValue = normalizeText(value, "")
        local previous = component._value
        component._value = nextValue
        textBox.Text = nextValue
        if previous ~= nextValue then
            if component.Flag ~= nil then State.Set(component.Flag, nextValue, component) else component:_FireChanged(nextValue, previous) end
            if not silent and type(config.Callback) == "function" then safeCall(config.Callback, nextValue, submitted == true) end
        end
        return component
    end
    function component:Set(value, silent) return apply(value, silent, false) end
    function component:Get() return self._value end
    component._applyEnabled = function(_, enabled)
        textBox.TextEditable = enabled
        holder.BackgroundColor3 = enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
    end
    component._tasks:Connect(textBox.Focused, function()
        if not component._enabled then textBox:ReleaseFocus(); return end
        UI.Tween(stroke, { Color = ThemeManager.Values.FocusBorder }, TWEEN.Fast)
    end)
    component._tasks:Connect(textBox.FocusLost, function()
        UI.Tween(stroke, { Color = ThemeManager.Values.Border }, TWEEN.Fast)
        apply(textBox.Text, false, true)
    end)
    registerComponentFlag(component, function() return component._value end, function(value) apply(value, true, false) end)
    return component
end

do -- Progress control helpers.
local function progressDisplay(component)
    if component._percentMode then
        local range = component._maximum - component._minimum
        local fraction = range == 0 and 0 or ((component._value - component._minimum) / range)
        return formatNumber(fraction * 100) .. component._suffix
    end
    return formatNumber(component._value) .. component._suffix
end

local function updateProgressVisual(component)
    local range = component._maximum - component._minimum
    local fraction = range == 0 and 0 or ((component._value - component._minimum) / range)
    component._fill.Size = UDim2.new(clamp(fraction, 0, 1), 0, 1, 0)
    component._valueLabel.Text = progressDisplay(component)
end

local function createProgressComponent(tab, config, minimum, maximum, percentMode)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local track = UI.Create("Frame", {
        Name = "ProgressTrack", Size = UDim2.fromOffset(174, 10), Position = UDim2.new(1, -190, 0.5, -5),
        BackgroundTransparency = 0.08, BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 3, Parent = row,
        Theme = { BackgroundColor3 = "ToggleOff" },
    })
    UI.Round(track, 5)
    UI.Stroke(track, nil, 1, 0.76)
    local fill = UI.Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 4, Parent = track, Theme = { BackgroundColor3 = "Accent" },
    })
    UI.Round(fill, 5)
    UI.Gradient(fill, "AccentGradientStart", "AccentGradientEnd", 0, 0)
    local valueLabel = UI.Create("TextLabel", {
        Name = "ProgressValue", Size = UDim2.fromOffset(174, 17), Position = UDim2.new(1, -190, 0.5, 7),
        BackgroundTransparency = 1, Text = "", TextSize = 10, Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = Z_INDEX.Content + 4,
        Parent = row, Theme = { TextColor3 = "ValueText" },
    })
    local component = newComponent(tab, row, nameLabel, descriptionLabel, config.Flag, config)
    component._minimum, component._maximum = minimum, maximum
    component._value = clamp(numberOr(config.Default, minimum), minimum, maximum)
    component._suffix = config.Suffix ~= nil and tostring(config.Suffix) or (percentMode and "%" or "")
    component._percentMode, component._fill, component._valueLabel = percentMode, fill, valueLabel
    component._pulseTween, component._animationTween = nil, nil
    component._animationGeneration = 0
    component._callback = config.Callback
    return component
end

local function cancelProgressAnimation(component)
    if component._animationTween == nil then return end
    component._animationGeneration = component._animationGeneration + 1
    local tween = component._animationTween
    component._animationTween = nil
    pcall(function() tween:Cancel() end)
end

local function setProgressValue(component, value, silent)
    cancelProgressAnimation(component)
    local nextValue = clamp(numberOr(value, component._minimum), component._minimum, component._maximum)
    local previous = component._value
    component._value = nextValue
    updateProgressVisual(component)
    component:_publish(nextValue, previous, component._callback, silent)
    return component
end

local function pulseProgress(component)
    if component._pulseTween ~= nil then return component end
    local ok, tween = pcall(function()
        return TweenService:Create(component._fill,
            TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.55 })
    end)
    if ok then
        component._pulseTween = tween
        tween:Play()
    end
    return component
end

local function stopProgressPulse(component)
    if component._pulseTween ~= nil then
        pcall(function() component._pulseTween:Cancel() end)
        component._pulseTween = nil
    end
    component._fill.BackgroundTransparency = 0
    return component
end

local function animateProgress(component, target, duration)
    cancelProgressAnimation(component)
    component._animationGeneration = component._animationGeneration + 1
    local generation, startingValue = component._animationGeneration, component._value
    local valueObject = UI.Create("NumberValue", { Value = component._value, Parent = component._root })
    component._tasks:Add(valueObject)
    local changedConnection = component._tasks:Connect(valueObject.Changed, function(value)
        if generation == component._animationGeneration and not component._destroyed then
            component._value = clamp(numberOr(value, component._minimum), component._minimum, component._maximum)
            updateProgressVisual(component)
        end
    end)
    local seconds = clamp(numberOr(duration, 0.4), 0.01, 30)
    local tween = TweenService:Create(valueObject,
        TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Value = clamp(numberOr(target, component._minimum), component._minimum, component._maximum) })
    component._animationTween = tween
    local completed
    completed = component._tasks:Connect(tween.Completed, function(playbackState)
        component._tasks:Cancel(completed)
        component._tasks:Cancel(changedConnection)
        local finalValue = valueObject.Value
        component._tasks:Cancel(valueObject)
        if component._animationTween == tween then component._animationTween = nil end
        if generation == component._animationGeneration
            and playbackState == Enum.PlaybackState.Completed and not component._destroyed then
            component._value = clamp(numberOr(finalValue, component._minimum), component._minimum, component._maximum)
            updateProgressVisual(component)
            component:_publish(component._value, startingValue, component._callback, false)
        end
    end)
    tween:Play()
    return component
end

function TabMethods:AddProgressBar(config)
    config = type(config) == "table" and config or {}
    local percentMode = config.Max == nil and config.Min == nil
    local minimum, maximum = normalizedRange(config.Min, config.Max, 0, percentMode and 1 or 100)
    local component = createProgressComponent(self, config, minimum, maximum, percentMode)
    component.Set = setProgressValue
    component.Get = function(self) return self._value end
    component.Increment = function(self, amount) return setProgressValue(self, self._value + numberOr(amount, 1), false) end
    component.Pulse, component.StopPulse, component.Animate = pulseProgress, stopProgressPulse, animateProgress
    component._tasks:Add(function()
        stopProgressPulse(component)
        cancelProgressAnimation(component)
    end)
    updateProgressVisual(component)
    registerComponentFlag(component, function() return component._value end, function(value) setProgressValue(component, value, true) end)
    return component
end

end

do -- Segmented and radio control helpers.
local function redrawSegments(component)
    local count = math.min(#component._segmentButtons, 64)
    for index = 1, count do
        local entry = component._segmentButtons[index]
        local selected = valuesEqual(entry.Value, component._selected)
        entry.Gradient.Enabled = selected
        entry.Button.BackgroundTransparency = selected and 0.06 or ThemeManager.Values.InputTransparency
        entry.Button.BackgroundColor3 = selected and ThemeManager.Values.Accent or ThemeManager.Values.InputBg
        entry.Button.TextColor3 = selected and ThemeManager.Values.TabActiveText or ThemeManager.Values.ValueText
    end
end

local function createSegmentedView(tab, config, width)
    local row = tab:_createRow()
    local nameLabel, descriptionLabel = tab:_createLabels(row, config.Name, config.Description)
    local holder = UI.Create("ScrollingFrame", {
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0,
        Size = UDim2.fromOffset(width, 30), Position = UDim2.new(1, -(width + 16), 0.5, -15),
        BackgroundTransparency = ThemeManager.Values.InputTransparency,
        BorderSizePixel = 0, ZIndex = Z_INDEX.Content + 3, Parent = row,
        Theme = { BackgroundColor3 = "InputBg", BackgroundTransparency = "InputTransparency" },
    })
    UI.Round(holder, 10)
    UI.Stroke(holder)
    UI.Gradient(holder, "PanelGradientStart", "PanelGradientEnd", 115, 0.2)
    UI.List(holder, Enum.FillDirection.Horizontal, 2)
    return row, nameLabel, descriptionLabel, holder
end

local function createSegmentButton(component, holder, option, index, count)
    local button = UI.Create("TextButton", {
        Size = UDim2.new(1 / count, count > 1 and -2 or 0, 1, 0),
        BackgroundColor3 = ThemeManager.Values.InputBg,
        BackgroundTransparency = ThemeManager.Values.InputTransparency, BorderSizePixel = 0,
        Text = tostring(option), TextSize = 11, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, LayoutOrder = index, ZIndex = Z_INDEX.Content + 4, Parent = holder,
    })
    UI.Round(button, 8)
    local gradient = UI.Gradient(button, "AccentGradientStart", "AccentGradientEnd", 15, 0)
    local entry = { Button = button, Value = option, Gradient = gradient }
    component._segmentButtons[index] = entry
    ThemeManager.Bind(button, {
        BackgroundColor3 = function()
            return valuesEqual(entry.Value, component._selected)
                and ThemeManager.Values.Accent or ThemeManager.Values.InputBg
        end,
        BackgroundTransparency = function(theme)
            return valuesEqual(entry.Value, component._selected) and 0.06 or theme.InputTransparency
        end,
        TextColor3 = function()
            return valuesEqual(entry.Value, component._selected)
                and ThemeManager.Values.TabActiveText or ThemeManager.Values.ValueText
        end,
    })
    component._tasks:Connect(button.Activated, function()
        if component._enabled then component:Set(option) end
    end)
end

local function installSegmentedMethods(component, options, callback)
    function component:Set(value, silent)
        if optionIndex(options, value) == nil then return self end
        local previous = self._selected
        self._selected = value
        redrawSegments(self)
        if not valuesEqual(previous, value) then self:_publish(value, previous, callback, silent) end
        return self
    end
    function component:Get() return self._selected end
    component._applyEnabled = function(_, enabled)
        local buttonCount = math.min(#component._segmentButtons, 16)
        for index = 1, buttonCount do
            component._segmentButtons[index].Button.Active = enabled
            component._segmentButtons[index].Button.TextTransparency = enabled and 0 or 0.5
        end
    end
end

function TabMethods:AddSegmentedControl(config)
    config = type(config) == "table" and config or {}
    local options = arrayCopy(config.Options or {}, 16)
    local selected = config.Default ~= nil and config.Default or options[1] or ""
    local width = clamp(numberOr(config.Width, 220), 100, 480)
    local row, nameLabel, descriptionLabel, holder = createSegmentedView(self, config, width)
    local component = newComponent(self, row, nameLabel, descriptionLabel, config.Flag, config)
    component._selected, component._segmentButtons = selected, {}
    local count = math.max(#options, 1)
    for index = 1, math.min(#options, 16) do
        createSegmentButton(component, holder, options[index], index, count)
    end
    local function layoutSegments()
        if component._destroyed then return end
        local available = holder.AbsoluteSize.X
        if available <= 0 then available = width end
        local touch = component._tab._window._touch
        for _, entry in ipairs(component._segmentButtons) do
            entry.Button.Size = UDim2.new(0, math.max(touch and 72 or 44, available / count - (count > 1 and 2 or 0)), 1, 0)
        end
    end
    component._tasks:Connect(holder:GetPropertyChangedSignal("AbsoluteSize"), layoutSegments)
    component._layoutTouch = layoutSegments
    layoutSegments()
    installSegmentedMethods(component, options, config.Callback)
    redrawSegments(component)
    registerComponentFlag(component, function() return component._selected end, function(value) component:Set(value, true) end)
    return component
end

function TabMethods:AddRadioGroup(config)
    local copy = type(config) == "table" and shallowCopy(config, 64) or {}
    copy.Multi = false
    return self:AddSegmentedControl(copy)
end

end

do -- Chip group control helpers.
local function orderedChipSelection(component)
    local result = {}
    local optionCount = math.min(#component._chipOptions, LIMITS.MaxOptions)
    for index = 1, optionCount do
        local option = component._chipOptions[index]
        if selectionContains(component._chipSelected, option) then
            result[#result + 1] = option
        end
    end
    return result
end

local function redrawChips(component)
    local count = math.min(#component._chipButtons, LIMITS.MaxOptions)
    for index = 1, count do
        local entry = component._chipButtons[index]
        local selected = selectionContains(component._chipSelected, entry.Value)
        entry.Gradient.Enabled = selected
        entry.Button.BackgroundTransparency = selected and 0.06 or ThemeManager.Values.InputTransparency
        entry.Button.BackgroundColor3 = selected and ThemeManager.Values.Accent or ThemeManager.Values.InputBg
        entry.Button.TextColor3 = selected and ThemeManager.Values.TabActiveText or ThemeManager.Values.ValueText
    end
end

local function createChipComponent(tab, config, options, selected, multi)
    local row = tab:_createRow(42)
    local nameLabel = tab:_createLabels(row, config.Name, nil)
    local scroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(0.66, -18, 1, -10), Position = UDim2.new(0.34, 0, 0, 5),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0, ZIndex = Z_INDEX.Content + 3, Parent = row,
    })
    local content = UI.Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, ZIndex = Z_INDEX.Content + 3, Parent = scroll,
    })
    UI.List(content, Enum.FillDirection.Horizontal, 5)
    local component = newComponent(tab, row, nameLabel, nil, config.Flag, config)
    component._chipOptions, component._chipSelected = options, selected
    component._chipButtons, component._multi = {}, multi
    component._chipContent, component._callback = content, config.Callback
    component._layoutTouch = function()
        for _, entry in ipairs(component._chipButtons) do
            entry.Button.Size = UDim2.fromOffset(entry.Button.Size.X.Offset, tab._window._touch and 44 or 30)
        end
    end
    return component
end

local function toggleChip(component, option)
    local previous = orderedChipSelection(component)
    local currentIndex = optionIndex(component._chipSelected, option)
    if component._multi then
        if currentIndex ~= nil then
            table.remove(component._chipSelected, currentIndex)
        else
            component._chipSelected[#component._chipSelected + 1] = option
        end
    else
        component._chipSelected = { option }
    end
    local output = orderedChipSelection(component)
    redrawChips(component)
    component:_publish(output, previous, component._callback, false)
end

local function addChipButton(component, option, index)
    local text = tostring(option)
    local button = UI.Create("TextButton", {
        Size = UDim2.fromOffset(clamp((#text * 7) + 20, 44, 180), component._tab._window._touch and 44 or 30),
        BackgroundTransparency = ThemeManager.Values.InputTransparency,
        BorderSizePixel = 0, Text = text, TextSize = 11, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, LayoutOrder = index, ZIndex = Z_INDEX.Content + 4,
        Parent = component._chipContent,
    })
    UI.Round(button, 10)
    UI.Stroke(button, nil, 1, 0.72)
    local gradient = UI.Gradient(button, "AccentGradientStart", "AccentGradientEnd", 15, 0)
    local entry = { Button = button, Value = option, Gradient = gradient }
    component._chipButtons[index] = entry
    ThemeManager.Bind(button, {
        BackgroundColor3 = function() return selectionContains(component._chipSelected, entry.Value)
            and ThemeManager.Values.Accent or ThemeManager.Values.InputBg end,
        BackgroundTransparency = function(theme) return selectionContains(component._chipSelected, entry.Value)
            and 0.06 or theme.InputTransparency end,
        TextColor3 = function() return selectionContains(component._chipSelected, entry.Value)
            and ThemeManager.Values.TabActiveText or ThemeManager.Values.ValueText end,
    })
    component._tasks:Connect(button.Activated, function()
        if component._enabled then toggleChip(component, option) end
    end)
end

local function setChipValues(component, values, silent)
    local previous = orderedChipSelection(component)
    local source = type(values) == "table" and values or { values }
    component._chipSelected = normalizedMultiSelection(source, component._chipOptions)
    if not component._multi and #component._chipSelected > 1 then
        component._chipSelected = { component._chipSelected[1] }
    end
    redrawChips(component)
    component:_publish(orderedChipSelection(component), previous, component._callback, silent)
    return component
end

local function setChipGroupEnabled(component, enabled)
    local buttonCount = math.min(#component._chipButtons, LIMITS.MaxOptions)
    for index = 1, buttonCount do
        component._chipButtons[index].Button.Active = enabled
        component._chipButtons[index].Button.TextTransparency = enabled and 0 or 0.5
    end
end

function TabMethods:AddChipGroup(config)
    config = type(config) == "table" and config or {}
    local options = arrayCopy(config.Options or {}, LIMITS.MaxOptions)
    local multi = config.Multi == true
    local initial = type(config.Default) == "table" and config.Default or { config.Default }
    local selected = normalizedMultiSelection(initial, options)
    if not multi and #selected == 0 and options[1] ~= nil then selected[1] = options[1] end
    if not multi and #selected > 1 then selected = { selected[1] } end
    local component = createChipComponent(self, config, options, selected, multi)
    for index = 1, math.min(#options, LIMITS.MaxOptions) do addChipButton(component, options[index], index) end
    component.Set, component.Get = setChipValues, function(self) return orderedChipSelection(self) end
    component.IsSelected = function(self, value) return selectionContains(self._chipSelected, value) end
    component._applyEnabled = function(_, enabled)
        setChipGroupEnabled(component, enabled)
    end
    redrawChips(component)
    registerComponentFlag(component, function() return component:Get() end, function(value) component:Set(value, true) end)
    return component
end

end

do -- Color picker control helpers.
local function colorToHex(color)
    local red = clamp(math.floor((color.R * 255) + 0.5), 0, 255)
    local green = clamp(math.floor((color.G * 255) + 0.5), 0, 255)
    local blue = clamp(math.floor((color.B * 255) + 0.5), 0, 255)
    return string.format("#%02X%02X%02X", red, green, blue)
end

local function hexToColor(text)
    local hex = normalizeText(text, ""):gsub("#", ""):gsub("%s", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 or hex:find("[^%x]") ~= nil then
        return nil
    end
    return Color3.fromRGB(
        tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16),
        tonumber(hex:sub(5, 6), 16)
    )
end

local function updateColorPickerUi(context)
    context.TempColor = Color3.fromHSV(context.Hue, context.Saturation, context.Value)
    context.SaturationValue.BackgroundColor3 = Color3.fromHSV(context.Hue, 1, 1)
    context.SaturationKnob.Position = UDim2.new(context.Saturation, 0, 1 - context.Value, 0)
    context.HueKnob.Position = UDim2.new(context.Hue, 0, 0.5, 0)
    context.Preview.BackgroundColor3 = context.TempColor
    context.HexBox.Text = colorToHex(context.TempColor)
end

local function createSaturationValueArea(component, popup, context)
    local area = UI.Create("Frame", {
        Size = UDim2.new(1, -24, 0, context.SVHeight), Position = UDim2.fromOffset(12, context.SVTop),
        BackgroundColor3 = Color3.fromHSV(context.Hue, 1, 1), BorderSizePixel = 0,
        Active = true, ZIndex = Z_INDEX.Popup + 2, Parent = popup,
    })
    UI.Round(area, 7)
    local white = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = Z_INDEX.Popup + 3, Parent = area,
    })
    UI.Round(white, 7)
    UI.Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = white,
    })
    local black = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0, ZIndex = Z_INDEX.Popup + 4, Parent = area,
    })
    UI.Round(black, 7)
    UI.Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(0, 0, 0)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
        Parent = black,
    })
    local knob = UI.Create("Frame", {
        Size = UDim2.fromOffset(13, 13), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        ZIndex = Z_INDEX.Popup + 6, Parent = area,
    })
    UI.Round(knob, 7)
    UI.Stroke(knob, Color3.new(0, 0, 0), 1.5)
    local hit = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = Z_INDEX.Popup + 7, Parent = area,
    })
    context.SaturationValue = area
    context.SaturationKnob = knob

    context.Group:Connect(hit.InputBegan, function(input)
        component._tab._window._input:BeginPointer(input, function(position)
            local size = area.AbsoluteSize
            context.Saturation = clamp((position.X - area.AbsolutePosition.X) / math.max(size.X, 1), 0, 1)
            context.Value = 1 - clamp((position.Y - area.AbsolutePosition.Y) / math.max(size.Y, 1), 0, 1)
            updateColorPickerUi(context)
        end, nil, context)
    end)
end

local function createHueArea(component, popup, context)
    local hueBar = UI.Create("Frame", {
        Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, context.HueTop + (context.Touch and 15 or 0)),
        BorderSizePixel = 0, Active = true, ZIndex = Z_INDEX.Popup + 2, Parent = popup,
    })
    UI.Round(hueBar, 7)
    UI.Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
        Parent = hueBar,
    })
    local knob = UI.Create("Frame", {
        Size = UDim2.fromOffset(13, 18), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        ZIndex = Z_INDEX.Popup + 4, Parent = hueBar,
    })
    UI.Round(knob, 6)
    UI.Stroke(knob, Color3.new(0, 0, 0), 1.5)
    local hit = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = Z_INDEX.Popup + 5, Parent = hueBar,
    })
    if context.Touch then hit.Size, hit.Position = UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, -15) end
    context.HueKnob = knob
    context.Group:Connect(hit.InputBegan, function(input)
        component._tab._window._input:BeginPointer(input, function(position)
            context.Hue = clamp((position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
            updateColorPickerUi(context)
        end, nil, context)
    end)
end

local function createColorPickerActions(popup, context)
    local cancelButton = UI.Create("TextButton", {
        Size = UDim2.new(0.5, -15, 0, context.Touch and 44 or 30), Position = UDim2.fromOffset(12, context.ActionsTop),
        BorderSizePixel = 0, Text = "Cancel", TextSize = 12, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, ZIndex = Z_INDEX.Popup + 2, Parent = popup,
        Theme = {
            BackgroundColor3 = "InputBg",
            BackgroundTransparency = "InputTransparency",
            TextColor3 = "LabelText",
        },
    })
    local applyButton = UI.Create("TextButton", {
        Size = UDim2.new(0.5, -15, 0, context.Touch and 44 or 30), Position = UDim2.new(0.5, 3, 0, context.ActionsTop),
        BorderSizePixel = 0, Text = "Apply", TextSize = 12, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, ZIndex = Z_INDEX.Popup + 2, Parent = popup,
        Theme = { BackgroundColor3 = "Accent", TextColor3 = "TabActiveText" },
    })
    UI.Round(cancelButton, 10)
    UI.Round(applyButton, 10)
    UI.Stroke(cancelButton, nil, 1, 0.68)
    UI.Stroke(applyButton, ThemeManager.Values.GlassHighlight, 1, 0.62)
    UI.Gradient(cancelButton, "PanelGradientStart", "PanelGradientEnd", 115, 0.18)
    UI.Gradient(applyButton, "AccentGradientStart", "AccentGradientEnd", 15, 0)
    UI.Hover(context.Group, cancelButton, "InputBg", "RowHover", "RowBg")
    UI.Hover(context.Group, applyButton, "Accent", "AccentHover", "AccentPress")
    context.Group:Connect(cancelButton.Activated, function() context.Close(false) end)
    context.Group:Connect(applyButton.Activated, function() context.Close(true) end)
end

local function createColorPickerFooter(popup, context)
    local preview = UI.Create("Frame", {
        Size = UDim2.fromOffset(42, context.Touch and 44 or 30), Position = UDim2.fromOffset(12, context.FooterTop),
        BackgroundColor3 = context.TempColor, BorderSizePixel = 0,
        ZIndex = Z_INDEX.Popup + 2, Parent = popup,
    })
    UI.Round(preview, 7)
    UI.Stroke(preview)
    local hexHolder = UI.Create("Frame", {
        Size = UDim2.new(1, -72, 0, context.Touch and 44 or 30), Position = UDim2.fromOffset(62, context.FooterTop),
        BackgroundTransparency = ThemeManager.Values.InputTransparency,
        BorderSizePixel = 0, ZIndex = Z_INDEX.Popup + 2, Parent = popup,
        Theme = { BackgroundColor3 = "InputBg", BackgroundTransparency = "InputTransparency" },
    })
    UI.Round(hexHolder, 10)
    local hexStroke = UI.Stroke(hexHolder)
    UI.Gradient(hexHolder, "PanelGradientStart", "PanelGradientEnd", 115, 0.18)
    local hexBox = UI.Create("TextBox", {
        Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = colorToHex(context.TempColor), ClearTextOnFocus = false,
        TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Popup + 3, Parent = hexHolder, Theme = { TextColor3 = "LabelText" },
    })
    context.Preview = preview
    context.HexBox = hexBox
    context.Group:Connect(hexBox.Focused, function()
        UI.Tween(hexStroke, { Color = ThemeManager.Values.FocusBorder }, TWEEN.Fast)
    end)
    context.Group:Connect(hexBox.FocusLost, function()
        UI.Tween(hexStroke, { Color = ThemeManager.Values.Border }, TWEEN.Fast)
        local color = hexToColor(hexBox.Text)
        if color ~= nil then
            context.Hue, context.Saturation, context.Value = color:ToHSV()
            updateColorPickerUi(context)
        else
            hexBox.Text = colorToHex(context.TempColor)
        end
    end)

    createColorPickerActions(popup, context)
end

local function openColorPicker(component)
    if component._pickerContext ~= nil or not component._enabled then return end
    component._tab._window:ClosePopups()
    local window = component._tab._window
    local _, viewport = MobileUI.Bounds(window._viewport)
    local touch = window._touch
    local svTop = touch and 54 or 46
    local svHeight = math.max(44, math.min(170, viewport.Y - 12 - (touch and 228 or 164)))
    local hueTop = svTop + svHeight + 10
    local footerTop = hueTop + (touch and 44 or 14) + (touch and 10 or 12)
    local actionsTop = footerTop + (touch and 44 or 30) + 10
    local canvasHeight = actionsTop + (touch and 44 or 30) + 12
    local x, y, width, height = MobileUI.PopupRect(window._viewport,
        component._swatchButton.AbsolutePosition, component._swatchButton.AbsoluteSize, 270, canvasHeight)
    local popup = UI.Create("Frame", {
        Name = "ColorPickerPopup", Size = UDim2.fromOffset(width, height), ClipsDescendants = true,
        BackgroundTransparency = ThemeManager.Values.PopupTransparency,
        BorderSizePixel = 0, ZIndex = Z_INDEX.Popup, Parent = component._tab._window._screenGui,
        Theme = { BackgroundColor3 = "PopupBg", BackgroundTransparency = "PopupTransparency" },
    })
    UI.Round(popup, 16)
    UI.Stroke(popup, nil, 1, 0.34)
    UI.Gradient(popup, "WindowGradientStart", "WindowGradientEnd", 130, 0.06)
    popup.Position = UDim2.fromOffset(x, y)
    local scroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, canvasHeight), ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = Z_INDEX.Popup + 1, Parent = popup,
    })
    local canvas = UI.Create("Frame", {
        Size = UDim2.new(1, -4, 0, canvasHeight), BackgroundTransparency = 1,
        ZIndex = Z_INDEX.Popup + 1, Parent = scroll,
    })

    UI.Create("TextLabel", {
        Size = UDim2.new(1, -44, 0, 38), Position = UDim2.fromOffset(12, 2),
        BackgroundTransparency = 1, Text = "Choose Color", TextSize = 14,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Popup + 2, Parent = canvas, Theme = { TextColor3 = "TitleText" },
    })
    local closeButton = UI.Create("TextButton", {
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0, 6),
        BackgroundTransparency = 1, Text = "x", TextSize = 12, Font = Enum.Font.GothamBold,
        AutoButtonColor = false, ZIndex = Z_INDEX.Popup + 3, Parent = canvas,
        Theme = { TextColor3 = "SubtitleText" },
    })

    local hue, saturation, value = component._value:ToHSV()
    local group = TaskGroup.new("ColorPickerPopup")
    local context = {
        Popup = popup, _root = canvas,
        Touch = touch, SVTop = svTop, SVHeight = svHeight, HueTop = hueTop, FooterTop = footerTop, ActionsTop = actionsTop,
        Group = group,
        Hue = hue,
        Saturation = saturation,
        Value = value,
        TempColor = component._value,
    }
    component._pickerContext = context
    local unregister
    context.Close = function(apply)
        if component._pickerContext ~= context then return end
        component._pickerContext = nil
        component._tab._window._input:CancelPointer(context)
        if apply then component:Set(context.TempColor, false) end
        if unregister ~= nil then unregister(); unregister = nil end
        group:Destroy()
        if popup.Parent ~= nil then popup:Destroy() end
    end
    if touch then closeButton.Size, closeButton.Position = UDim2.fromOffset(44, 44), UDim2.new(1, -50, 0, 0) end
    createSaturationValueArea(component, canvas, context)
    createHueArea(component, canvas, context)
    createColorPickerFooter(canvas, context)
    updateColorPickerUi(context)
    group:Connect(closeButton.Activated, function() context.Close(false) end)
    unregister = component._tab._window:RegisterPopup(popup, function() context.Close(false) end, function()
        if component._pickerContext ~= context then return end
        local px, py, pw, ph = MobileUI.PopupRect(window._viewport,
            component._swatchButton.AbsolutePosition, component._swatchButton.AbsoluteSize, 270, canvasHeight)
        popup.Position, popup.Size = UDim2.fromOffset(px, py), UDim2.fromOffset(pw, ph)
    end)
end

function TabMethods:AddColorPicker(config)
    config = type(config) == "table" and config or {}
    local default = robloxType(config.Default) == "Color3" and config.Default or Color3.new(1, 1, 1)
    local row = self:_createRow()
    local nameLabel, descriptionLabel = self:_createLabels(row, config.Name, config.Description)
    local button = UI.Create("TextButton", {
        Size = UDim2.fromOffset(122, 30), Position = UDim2.new(1, -138, 0.5, -15),
        BackgroundTransparency = ThemeManager.Values.InputTransparency,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        ZIndex = Z_INDEX.Content + 3, Parent = row,
        Theme = { BackgroundColor3 = "InputBg", BackgroundTransparency = "InputTransparency" },
    })
    UI.Round(button, 10)
    UI.Stroke(button)
    UI.Gradient(button, "PanelGradientStart", "PanelGradientEnd", 115, 0.18)
    local swatch = UI.Create("Frame", {
        Size = UDim2.fromOffset(38, 20), Position = UDim2.fromOffset(6, 5),
        BackgroundColor3 = default, BorderSizePixel = 0, ZIndex = Z_INDEX.Content + 4, Parent = button,
    })
    UI.Round(swatch, 6)
    local hexLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(50, 0),
        BackgroundTransparency = 1, Text = colorToHex(default), TextSize = 11,
        Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Content + 4, Parent = button, Theme = { TextColor3 = "ValueText" },
    })
    local component = newComponent(self, row, nameLabel, descriptionLabel, config.Flag, config)
    component._value = default
    component._swatchButton = button
    component._pickerContext = nil
    ThemeManager.Bind(button, {
        BackgroundColor3 = function()
            return component._enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
        end,
    })
    function component:Set(color, silent)
        if robloxType(color) ~= "Color3" then return self end
        local previous = self._value
        self._value = color
        swatch.BackgroundColor3 = color
        hexLabel.Text = colorToHex(color)
        if not valuesEqual(previous, color) then self:_publish(color, previous, config.Callback, silent) end
        return self
    end
    function component:Get() return self._value end
    component._applyEnabled = function(_, enabled)
        button.Active = enabled
        button.BackgroundColor3 = enabled and ThemeManager.Values.InputBg or ThemeManager.Values.DisabledBg
        if not enabled and component._pickerContext ~= nil then component._pickerContext.Close(false) end
    end
    component._tasks:Connect(button.Activated, function()
        if component._enabled then openColorPicker(component) end
    end)
    component._tasks:Add(function()
        if component._pickerContext ~= nil then component._pickerContext.Close(false) end
    end)
    registerComponentFlag(component, function() return component._value end, function(value) component:Set(value, true) end)
    return component
end

end

do -- Scroll panel control helpers.
local function updatePanelEmptyState(panel)
    panel._emptyLabel.Visible = #panel._panelRows == 0
end

local function buildPanelAction(panel, rowObject, area, action, order)
    local danger = action.Danger == true
    local button = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 31), BorderSizePixel = 0,
        Text = normalizeText(action.Label, "Action"), TextSize = 11, Font = Enum.Font.GothamMedium,
        AutoButtonColor = false, LayoutOrder = order, ZIndex = Z_INDEX.Content + 5, Parent = area,
        Theme = {
            BackgroundColor3 = danger and "DangerBg" or "InputBg",
            TextColor3 = danger and "DangerText" or "LabelText",
        },
    })
    UI.Round(button, 6)
    UI.Hover(rowObject._tasks, button,
        danger and "DangerBg" or "InputBg",
        danger and "DangerHover" or "RowHover",
        danger and "DangerBg" or "RowBg")
    rowObject._tasks:Connect(button.Activated, function()
        safeCall(action.Callback or function() end, rowObject, panel)
    end)
end

local function setPanelRowOpen(rowObject, open)
    rowObject._open = open == true and rowObject._actionHeight > 0
    local height = rowObject._headerHeight + (rowObject._open and rowObject._actionHeight or 0)
    UI.Tween(rowObject.Instance, { Size = UDim2.new(1, 0, 0, height) }, TWEEN.Medium)
    UI.Tween(rowObject._chevron, { Rotation = rowObject._open and 90 or 0 }, TWEEN.Medium)
end

local function removePanelRow(panel, rowObject, animate)
    if rowObject._removed then return end
    rowObject._removed = true
    removeArrayValue(panel._panelRows, rowObject, LIMITS.MaxRows)
    panel._tasks:Cancel(rowObject._tasks)
    if animate and rowObject.Instance.Parent ~= nil then
        UI.Tween(rowObject.Instance, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, TWEEN.Fast)
        panel._tasks:Delay(0.16, function()
            if rowObject.Instance.Parent ~= nil then rowObject.Instance:Destroy() end
            updatePanelEmptyState(panel)
        end)
    else
        if rowObject.Instance.Parent ~= nil then rowObject.Instance:Destroy() end
        updatePanelEmptyState(panel)
    end
end

local function createPanelRowView(panel, config, actionCount, headerHeight, actionHeight)
    local root = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, headerHeight), BorderSizePixel = 0, ClipsDescendants = true,
        LayoutOrder = #panel._panelRows + 1, ZIndex = Z_INDEX.Content + 2,
        Parent = panel._panelContent,
        Theme = { BackgroundColor3 = "RowBg", BackgroundTransparency = "RowTransparency" },
    })
    UI.Round(root, 10)
    UI.Stroke(root, nil, 1, 0.72)
    UI.Gradient(root, "SurfaceGradientStart", "SurfaceGradientEnd", 115, 0.18)
    local hit = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, headerHeight), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = Z_INDEX.Content + 4, Parent = root,
    })
    local badge = UI.Create("TextLabel", {
        Size = UDim2.fromOffset(30, 17), Position = UDim2.fromOffset(9, 14), BorderSizePixel = 0,
        Text = normalizeText(config.Badge, ""), TextSize = 9, Font = Enum.Font.GothamBold,
        Visible = config.Badge ~= nil and tostring(config.Badge) ~= "",
        ZIndex = Z_INDEX.Content + 5, Parent = root,
        Theme = { BackgroundColor3 = "Accent", TextColor3 = "TabActiveText" },
    })
    if robloxType(config.BadgeColor) == "Color3" then
        ThemeManager.Unbind(badge)
        badge.BackgroundColor3 = config.BadgeColor
    end
    UI.Round(badge, 5)
    local labelX = badge.Visible and 47 or 11
    local label = UI.Create("TextLabel", {
        Size = UDim2.new(1, -(labelX + 34), 0, 16), Position = UDim2.fromOffset(labelX, 7),
        BackgroundTransparency = 1, Text = normalizeText(config.Label, ""), TextSize = 12,
        Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Z_INDEX.Content + 5, Parent = root,
        Theme = { TextColor3 = "LabelText" },
    })
    local subtext = UI.Create("TextLabel", {
        Size = UDim2.new(1, -(labelX + 34), 0, 14), Position = UDim2.fromOffset(labelX, 25),
        BackgroundTransparency = 1, Text = normalizeText(config.Subtext, ""), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Z_INDEX.Content + 5, Parent = root,
        Theme = { TextColor3 = "DescText" },
    })
    local chevron = UI.Create("TextLabel", {
        Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -27, 0, 13),
        BackgroundTransparency = 1, Text = actionCount > 0 and ">" or "", TextSize = 13,
        Font = Enum.Font.GothamBold, ZIndex = Z_INDEX.Content + 5, Parent = root,
        Theme = { TextColor3 = "DescText" },
    })
    local area = UI.Create("Frame", {
        Size = UDim2.new(1, -16, 0, actionHeight - 4), Position = UDim2.fromOffset(8, headerHeight + 2),
        BackgroundTransparency = 1, ZIndex = Z_INDEX.Content + 3, Parent = root,
    })
    UI.List(area, Enum.FillDirection.Vertical, 3)
    UI.Padding(area, 4, 0, 4, 0)
    return root, hit, badge, label, subtext, chevron, area
end

local function setPanelRowBadge(rowObject, text, color)
    rowObject._badge.Text = normalizeText(text, "")
    rowObject._badge.Visible = text ~= nil and tostring(text) ~= ""
    if robloxType(color) == "Color3" then
        ThemeManager.Unbind(rowObject._badge)
        rowObject._badge.BackgroundColor3 = color
    end
    local labelX = rowObject._badge.Visible and 47 or 11
    rowObject._label.Position = UDim2.fromOffset(labelX, 7)
    rowObject._label.Size = UDim2.new(1, -(labelX + 34), 0, 16)
    rowObject._subtext.Position = UDim2.fromOffset(labelX, 25)
    rowObject._subtext.Size = UDim2.new(1, -(labelX + 34), 0, 14)
    return rowObject
end

local function flashPanelRow(rowObject)
    UI.Tween(rowObject.Instance, { BackgroundColor3 = ThemeManager.Values.Accent }, TWEEN.Fast)
    rowObject._panel._tasks:Delay(0.35, function()
        if rowObject.Instance.Parent ~= nil then
            UI.Tween(rowObject.Instance, { BackgroundColor3 = ThemeManager.Values.RowBg }, TWEEN.Medium)
        end
    end)
    return rowObject
end

local function wirePanelRow(rowObject, hit, actionCount)
    local tasks, root = rowObject._tasks, rowObject.Instance
    tasks:Connect(hit.MouseEnter, function()
        if not rowObject._open then UI.Tween(root, { BackgroundColor3 = ThemeManager.Values.RowHover }, TWEEN.Fast) end
    end)
    tasks:Connect(hit.MouseLeave, function()
        if not rowObject._open then UI.Tween(root, { BackgroundColor3 = ThemeManager.Values.RowBg }, TWEEN.Fast) end
    end)
    if actionCount > 0 then
        tasks:Connect(hit.Activated, function() setPanelRowOpen(rowObject, not rowObject._open) end)
    end
    rowObject.SetLabel = function(self, text) self._label.Text = normalizeText(text, ""); return self end
    rowObject.SetSubtext = function(self, text) self._subtext.Text = normalizeText(text, ""); return self end
    rowObject.SetBadge, rowObject.Flash = setPanelRowBadge, flashPanelRow
    rowObject.Expand = function(self) setPanelRowOpen(self, true); return self end
    rowObject.Collapse = function(self) setPanelRowOpen(self, false); return self end
    rowObject.Toggle = function(self) setPanelRowOpen(self, not self._open); return self end
    rowObject.Remove = function(self) removePanelRow(self._panel, self, true); return self end
end

local function createPanelRow(panel, config)
    config = type(config) == "table" and config or {}
    local actions = type(config.Actions) == "table" and config.Actions or {}
    local actionCount = math.min(#actions, 32)
    local headerHeight = 46
    local actionHeight = actionCount > 0 and ((actionCount * 34) + 8) or 0
    local root, hit, badge, label, subtext, chevron, area =
        createPanelRowView(panel, config, actionCount, headerHeight, actionHeight)
    local rowObject = {
        Instance = root, _tasks = TaskGroup.new("ScrollPanelRow"), _panel = panel,
        _label = label, _subtext = subtext, _badge = badge, _chevron = chevron,
        _headerHeight = headerHeight, _actionHeight = actionHeight, _open = false, _removed = false,
    }
    panel._tasks:Add(rowObject._tasks)
    for index = 1, actionCount do buildPanelAction(panel, rowObject, area, actions[index], index) end
    wirePanelRow(rowObject, hit, actionCount)
    return rowObject
end

local function createScrollPanelView(tab, config, panelHeight, headerHeight)
    local wrapper = tab:_createStandalone(panelHeight + headerHeight, "ScrollPanel")
    ThemeManager.Bind(wrapper, { BackgroundColor3 = "ContentBg" })
    local titleLabel
    if headerHeight > 0 then
        titleLabel = UI.Create("TextLabel", {
            Size = UDim2.new(1, -20, 0, headerHeight), Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1, Text = normalizeText(config.Name, "Panel"):upper(),
            TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = Z_INDEX.Content + 3, Parent = wrapper, Theme = { TextColor3 = "SubtitleText" },
        })
    end
    local scroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, panelHeight), Position = UDim2.fromOffset(0, headerHeight),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
        ZIndex = Z_INDEX.Content + 2, Parent = wrapper, Theme = { ScrollBarImageColor3 = "ScrollThumb" },
    })
    local content = UI.Create("Frame", {
        Size = UDim2.new(1, -8, 0, 0), Position = UDim2.fromOffset(4, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        ZIndex = Z_INDEX.Content + 2, Parent = scroll,
    })
    UI.List(content, Enum.FillDirection.Vertical, 3)
    UI.Padding(content, 4, 0, 4, 0)
    local emptyLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, panelHeight), Position = UDim2.fromOffset(0, headerHeight),
        BackgroundTransparency = 1, Text = normalizeText(config.EmptyText, "Empty"),
        TextSize = 12, Font = Enum.Font.Gotham, ZIndex = Z_INDEX.Content + 3,
        Parent = wrapper, Theme = { TextColor3 = "DescText" },
    })
    return wrapper, titleLabel, scroll, content, emptyLabel
end

local function installScrollPanelMethods(panel)
    function panel:AddRow(rowConfig)
        if #self._panelRows >= LIMITS.MaxRows then return nil end
        local rowObject = createPanelRow(self, rowConfig)
        self._panelRows[#self._panelRows + 1] = rowObject
        updatePanelEmptyState(self)
        return rowObject
    end
    function panel:Clear()
        for index = math.min(#self._panelRows, LIMITS.MaxRows), 1, -1 do
            removePanelRow(self, self._panelRows[index], false)
        end
        self._panelRows = {}
        updatePanelEmptyState(self)
        return self
    end
    function panel:ScrollToBottom()
        self._tasks:Delay(0, function()
            if self._scroll.Parent ~= nil then self._scroll.CanvasPosition = Vector2.new(0, 1000000000) end
        end)
        return self
    end
    function panel:ScrollToTop() self._scroll.CanvasPosition = Vector2.new(0, 0); return self end
    function panel:SetHeight(height)
        self._panelHeight = clamp(numberOr(height, self._panelHeight), 80, 1200)
        self._root.Size = UDim2.new(1, 0, 0, self._panelHeight + self._headerHeight)
        self._scroll.Size = UDim2.new(1, 0, 0, self._panelHeight)
        self._emptyLabel.Size = UDim2.new(1, 0, 0, self._panelHeight)
        return self
    end
    function panel:GetRowCount() return #self._panelRows end
    function panel:GetFrame() return self._root end
end

function TabMethods:AddScrollPanel(config)
    config = type(config) == "table" and config or {}
    local panelHeight = clamp(numberOr(config.Height, 240), 80, 1200)
    local headerHeight = config.ShowHeader == false and 0 or 30
    local wrapper, titleLabel, scroll, content, emptyLabel =
        createScrollPanelView(self, config, panelHeight, headerHeight)
    local panel = newComponent(self, wrapper, titleLabel, nil)
    panel._panelRows = {}
    panel._panelContent = content
    panel._emptyLabel = emptyLabel
    panel._panelHeight = panelHeight
    panel._headerHeight = headerHeight
    panel._scroll = scroll
    installScrollPanelMethods(panel)
    return panel
end

end

do -- Log box control helpers.
local LOG_COLORS = {
    info = "#A0A0AC", warn = "#FFBD2E", warning = "#FFBD2E",
    error = "#FF5F56", success = "#30D158", debug = "#0A84FF",
}

local function escapeRichText(text)
    return normalizeText(text, ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function renderLogBox(component)
    local richLines = {}
    local count = math.min(#component._entries, component._maxLines)
    for index = 1, count do
        local entry = component._entries[index]
        local color = LOG_COLORS[entry.Level] or LOG_COLORS.info
        richLines[index] = '<font color="' .. color .. '">[' .. entry.Time .. "] " .. escapeRichText(entry.Text) .. "</font>"
    end
    component._textLabel.Text = table.concat(richLines, "\n")
    if component._autoScroll then
        component._tasks:Delay(0, function()
            if component._scroll.Parent ~= nil then component._scroll.CanvasPosition = Vector2.new(0, 1000000000) end
        end)
    end
end

function TabMethods:AddLogBox(config)
    config = type(config) == "table" and config or {}
    local height = clamp(numberOr(config.Height, 160), 80, 1000)
    local wrapper = self:_createStandalone(height + 32, "LogBox")
    ThemeManager.Bind(wrapper, { BackgroundColor3 = "ContentBg" })
    local titleLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -70, 0, 32), Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1, Text = normalizeText(config.Name, "Console"):upper(),
        TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Z_INDEX.Content + 3, Parent = wrapper, Theme = { TextColor3 = "SubtitleText" },
    })
    local clearButton = UI.Create("TextButton", {
        Size = UDim2.fromOffset(50, 24), Position = UDim2.new(1, -58, 0, 4),
        BackgroundTransparency = 1, Text = "Clear", TextSize = 10, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, ZIndex = Z_INDEX.Content + 3, Parent = wrapper,
        Theme = { TextColor3 = "ValueText", BackgroundColor3 = "RowHover" },
    })
    local scroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, height), Position = UDim2.fromOffset(0, 32),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
        ZIndex = Z_INDEX.Content + 2, Parent = wrapper, Theme = { ScrollBarImageColor3 = "ScrollThumb" },
    })
    local textLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -18, 0, 0), Position = UDim2.fromOffset(8, 6),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "", RichText = true,
        TextSize = 11, Font = config.Monospace == false and Enum.Font.Gotham or Enum.Font.RobotoMono,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = Z_INDEX.Content + 3, Parent = scroll, Theme = { TextColor3 = "ValueText" },
    })
    local component = newComponent(self, wrapper, titleLabel, nil)
    component._entries = {}
    component._maxLines = clamp(math.floor(numberOr(config.MaxLines, 200)), 1, LIMITS.MaxLogLines)
    component._autoScroll = config.AutoScroll ~= false
    component._scroll = scroll
    component._textLabel = textLabel
    function component:Write(text, level)
        local timestamp = "--:--:--"
        pcall(function() timestamp = os.date("%H:%M:%S") end)
        self._entries[#self._entries + 1] = {
            Time = timestamp, Text = normalizeText(text, ""), Level = tostring(level or "info"):lower(),
        }
        if #self._entries > self._maxLines then table.remove(self._entries, 1) end
        renderLogBox(self)
        return self
    end
    function component:Clear() self._entries = {}; renderLogBox(self); return self end
    function component:SetAutoScroll(value) self._autoScroll = value == true; return self end
    function component:Export()
        local lines = {}
        for index = 1, math.min(#self._entries, self._maxLines) do
            local entry = self._entries[index]
            lines[index] = "[" .. entry.Time .. "] [" .. entry.Level:upper() .. "] " .. entry.Text
        end
        return table.concat(lines, "\n")
    end
    function component:GetFrame() return wrapper end
    component._tasks:Connect(clearButton.Activated, function() component:Clear() end)
    return component
end

end

function TabMethods:AddDataCard(config)
    config = type(config) == "table" and config or {}
    local row = self:_createRow(70)
    local nameLabel, descriptionLabel = self:_createLabels(row, config.Name, config.Description)
    local valueLabel = UI.Create("TextLabel", {
        Size = UDim2.new(0.42, -18, 0, 28), Position = UDim2.new(0.58, 0, 0, 9),
        BackgroundTransparency = 1, Text = normalizeText(config.Value, "0"), TextSize = 22,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Z_INDEX.Content + 3,
        Parent = row, Theme = { TextColor3 = "Accent" },
    })
    local subtext = UI.Create("TextLabel", {
        Size = UDim2.new(0.42, -18, 0, 15), Position = UDim2.new(0.58, 0, 0, 39),
        BackgroundTransparency = 1, Text = normalizeText(config.Subtext, ""), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = Z_INDEX.Content + 3, Parent = row, Theme = { TextColor3 = "DescText" },
    })
    UI.Padding(valueLabel, 0, 18, 0, 0)
    UI.Padding(subtext, 0, 18, 0, 0)
    if robloxType(config.Accent) == "Color3" then
        ThemeManager.Unbind(valueLabel)
        valueLabel.TextColor3 = config.Accent
    end
    local component = newComponent(self, row, nameLabel, descriptionLabel)
    function component:SetValue(value) valueLabel.Text = normalizeText(value, ""); return self end
    function component:Set(value) return self:SetValue(value) end
    function component:Get() return valueLabel.Text end
    function component:SetSubtext(value) subtext.Text = normalizeText(value, ""); return self end
    function component:SetAccent(color)
        if robloxType(color) == "Color3" then ThemeManager.Unbind(valueLabel); valueLabel.TextColor3 = color end
        return self
    end
    function component:Pulse()
        local original = valueLabel.TextColor3
        valueLabel.TextColor3 = Color3.new(1, 1, 1)
        self._tasks:Delay(0.16, function()
            if valueLabel.Parent ~= nil then UI.Tween(valueLabel, { TextColor3 = original }, TWEEN.Medium) end
        end)
        return self
    end
    return component
end

do -- Virtual table control helpers.
local function normalizeColumnWidths(columns, widths)
    local result = {}
    local total = 0
    local count = math.max(#columns, 1)
    for index = 1, count do
        local value = math.max(numberOr(widths[index], 1), 0)
        result[index] = value
        total = total + value
    end
    if total <= 0 then total = count; for index = 1, count do result[index] = 1 end end
    for index = 1, count do result[index] = result[index] / total end
    return result
end

local function createVirtualTableRow(component, poolIndex)
    local row = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, component._rowHeight), Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0, Visible = false, ZIndex = Z_INDEX.Content + 3,
        Parent = component._tableScroll,
    })
    local labels = {}
    local x = 0
    for column = 1, component._columnCount do
        labels[column] = UI.Create("TextLabel", {
            Size = UDim2.new(component._columnWidths[column], -8, 1, 0), Position = UDim2.new(x, 6, 0, 0),
            BackgroundTransparency = 1, Text = "", TextSize = 11, Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = Z_INDEX.Content + 4, Parent = row, Theme = { TextColor3 = "LabelText" },
        })
        x = x + component._columnWidths[column]
    end
    local pooled = { Frame = row, Labels = labels, DataIndex = 0 }
    component._rowPool[poolIndex] = pooled
    ThemeManager.Bind(row, {
        BackgroundColor3 = function()
            return pooled.DataIndex % 2 == 0 and ThemeManager.Values.RowBg or ThemeManager.Values.ContentBg
        end,
    })
end

local function renderVirtualTable(component, force)
    local firstIndex = math.floor(component._tableScroll.CanvasPosition.Y / component._rowHeight) + 1
    if not force and component._firstTableIndex == firstIndex then return end
    component._firstTableIndex = firstIndex
    local poolCount = math.min(#component._rowPool, 128)
    for poolIndex = 1, poolCount do
        local dataIndex = firstIndex + poolIndex - 1
        local pooled = component._rowPool[poolIndex]
        local cells = component._tableData[dataIndex]
        if cells ~= nil then
            pooled.DataIndex = dataIndex
            pooled.Frame.Visible = true
            pooled.Frame.Position = UDim2.fromOffset(0, (dataIndex - 1) * component._rowHeight)
            pooled.Frame.BackgroundColor3 = dataIndex % 2 == 0 and ThemeManager.Values.RowBg or ThemeManager.Values.ContentBg
            for column = 1, component._columnCount do
                pooled.Labels[column].Text = normalizeText(cells[column], "")
            end
        else
            pooled.DataIndex = 0
            pooled.Frame.Visible = false
        end
    end
end

local function refreshVirtualTable(component)
    component._tableScroll.CanvasSize = UDim2.new(0, 0, 0, #component._tableData * component._rowHeight)
    renderVirtualTable(component, true)
end

local function createTableHeader(wrapper, columns, widths)
    local header = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 30),
        BorderSizePixel = 0, ZIndex = Z_INDEX.Content + 2, Parent = wrapper,
        Theme = { BackgroundColor3 = "RowBg", BackgroundTransparency = "PanelTransparency" },
    })
    local x = 0
    for index = 1, math.min(#columns, LIMITS.MaxTableColumns) do
        UI.Create("TextLabel", {
            Size = UDim2.new(widths[index], -8, 1, 0), Position = UDim2.new(x, 6, 0, 0),
            BackgroundTransparency = 1, Text = tostring(columns[index]), TextSize = 10,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Z_INDEX.Content + 3,
            Parent = header, Theme = { TextColor3 = "SubtitleText" },
        })
        x = x + widths[index]
    end
end

local function createTableView(tab, config, columns, widths, height)
    local wrapper = tab:_createStandalone(height + 58, "DataTable")
    ThemeManager.Bind(wrapper, { BackgroundColor3 = "ContentBg" })
    local titleLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
        Text = normalizeText(config.Name, "Table"):upper(), TextSize = 10, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = Z_INDEX.Content + 3,
        Parent = wrapper, Theme = { TextColor3 = "SubtitleText" },
    })
    createTableHeader(wrapper, columns, widths)
    local scroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, height), Position = UDim2.fromOffset(0, 58),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3, ZIndex = Z_INDEX.Content + 2, Parent = wrapper,
        Theme = { ScrollBarImageColor3 = "ScrollThumb" },
    })
    return wrapper, titleLabel, scroll
end

local function installTableMethods(component)
    function component:AddRow(cells)
        if #self._tableData >= LIMITS.MaxRows then return nil end
        self._tableData[#self._tableData + 1] = arrayCopy(type(cells) == "table" and cells or {}, self._columnCount)
        refreshVirtualTable(self)
        return #self._tableData
    end
    function component:SetRow(index, cells)
        local target = math.floor(numberOr(index, 0))
        if self._tableData[target] ~= nil then
            self._tableData[target] = arrayCopy(type(cells) == "table" and cells or {}, self._columnCount)
            renderVirtualTable(self, true)
        end
        return self
    end
    function component:RemoveRow(index)
        local target = math.floor(numberOr(index, 0))
        if target >= 1 and target <= #self._tableData then
            table.remove(self._tableData, target)
            refreshVirtualTable(self)
        end
        return self
    end
    function component:Clear()
        self._tableData = {}
        self._tableScroll.CanvasPosition = Vector2.new(0, 0)
        refreshVirtualTable(self)
        return self
    end
    function component:GetRowCount() return #self._tableData end
    function component:GetFrame() return self._root end
end

local function initializeVirtualTable(component, height)
    local poolSize = math.min(math.ceil(height / component._rowHeight) + 3, 128)
    for index = 1, poolSize do createVirtualTableRow(component, index) end
    component._tasks:Connect(component._tableScroll:GetPropertyChangedSignal("CanvasPosition"), function()
        renderVirtualTable(component)
    end)
end

function TabMethods:AddTable(config)
    config = type(config) == "table" and config or {}
    local columns = arrayCopy(config.Columns or {}, LIMITS.MaxTableColumns)
    if #columns == 0 then columns[1] = "Value" end
    local widths = normalizeColumnWidths(columns, type(config.Widths) == "table" and config.Widths or {})
    local height = clamp(numberOr(config.Height, 180), 60, 1200)
    local wrapper, titleLabel, scroll = createTableView(self, config, columns, widths, height)
    local component = newComponent(self, wrapper, titleLabel, nil)
    component._tableData, component._tableScroll = {}, scroll
    component._columnCount, component._columnWidths = #columns, widths
    component._rowHeight, component._rowPool = 25, {}
    installTableMethods(component)
    initializeVirtualTable(component, height)
    refreshVirtualTable(component)
    return component
end

end

do -- Alert control helpers.
local ALERT_STYLE = {
    info = { Background = Color3.fromRGB(16, 42, 78), Stripe = Color3.fromRGB(78, 184, 255), Text = Color3.fromRGB(157, 213, 255) },
    warn = { Background = Color3.fromRGB(68, 48, 15), Stripe = Color3.fromRGB(255, 190, 92), Text = Color3.fromRGB(255, 215, 142) },
    warning = { Background = Color3.fromRGB(68, 48, 15), Stripe = Color3.fromRGB(255, 190, 92), Text = Color3.fromRGB(255, 215, 142) },
    error = { Background = Color3.fromRGB(72, 24, 42), Stripe = Color3.fromRGB(255, 102, 128), Text = Color3.fromRGB(255, 162, 178) },
    success = { Background = Color3.fromRGB(15, 61, 49), Stripe = Color3.fromRGB(73, 218, 154), Text = Color3.fromRGB(142, 239, 196) },
}

local function setAlertType(component, alertType, animated)
    local normalized = tostring(alertType or "info"):lower()
    local style = ALERT_STYLE[normalized] or ALERT_STYLE.info
    component._alertType = normalized
    if animated then
        UI.Tween(component._root, { BackgroundColor3 = style.Background }, TWEEN.Medium)
        UI.Tween(component._alertStripe, { BackgroundColor3 = style.Stripe }, TWEEN.Medium)
        UI.Tween(component._alertLabel, { TextColor3 = style.Text }, TWEEN.Medium)
        if component._alertIcon ~= nil then UI.Tween(component._alertIcon, { TextColor3 = style.Stripe }, TWEEN.Medium) end
    else
        component._root.BackgroundColor3 = style.Background
        component._alertStripe.BackgroundColor3 = style.Stripe
        component._alertLabel.TextColor3 = style.Text
        if component._alertIcon ~= nil then component._alertIcon.TextColor3 = style.Stripe end
    end
end

function TabMethods:AddAlert(config)
    config = type(config) == "table" and config or {}
    local root = self:_createStandalone(40, "Alert")
    ThemeManager.Unbind(root)
    local surfaceGradient = root:FindFirstChildOfClass("UIGradient")
    if surfaceGradient ~= nil then surfaceGradient.Enabled = false end
    local stripe = UI.Create("Frame", {
        Size = UDim2.new(0, 3, 0.66, 0), Position = UDim2.new(0, 9, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0,
        ZIndex = Z_INDEX.Content + 3, Parent = root,
    })
    UI.Round(stripe, 2)
    local icon
    local textX = 19
    if config.Icon ~= nil and tostring(config.Icon) ~= "" then
        icon = UI.Create("TextLabel", {
            Size = UDim2.fromOffset(20, 40), Position = UDim2.fromOffset(18, 0),
            BackgroundTransparency = 1, Text = tostring(config.Icon), TextSize = 14,
            Font = Enum.Font.Gotham, ZIndex = Z_INDEX.Content + 4, Parent = root,
        })
        textX = 42
    end
    local label = UI.Create("TextLabel", {
        Size = UDim2.new(1, -(textX + 16), 1, 0), Position = UDim2.fromOffset(textX, 0),
        BackgroundTransparency = 1, Text = normalizeText(config.Text, ""), TextSize = 12,
        Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, ZIndex = Z_INDEX.Content + 4, Parent = root,
    })
    local component = newComponent(self, root, label, nil)
    component._alertStripe = stripe
    component._alertLabel = label
    component._alertIcon = icon
    function component:Set(text, alertType)
        label.Text = normalizeText(text, "")
        self:_refreshSearchText()
        if alertType ~= nil then setAlertType(self, alertType, true) end
        return self
    end
    function component:SetType(alertType) setAlertType(self, alertType, true); return self end
    function component:Get() return label.Text end
    setAlertType(component, config.Type, false)
    return component
end

end

do -- Code view control helpers.
local function countCodeLines(code)
    local count = 1
    local position = 1
    for _ = 1, LIMITS.MaxCodeLines do
        local nextBreak = code:find("\n", position, true)
        if nextBreak == nil then return count end
        count = count + 1
        position = nextBreak + 1
    end
    return LIMITS.MaxCodeLines
end

local function lineNumberText(count)
    local values = {}
    local bounded = math.min(count, LIMITS.MaxCodeLines)
    for index = 1, bounded do values[index] = tostring(index) end
    return table.concat(values, "\n")
end

local function createCodeViewRoot(tab, config, height, headerHeight, font, fontSize)
    local root = tab:_createStandalone(height + headerHeight, "CodeView")
    ThemeManager.Bind(root, { BackgroundColor3 = "CodeBg" })
    local titleLabel
    if headerHeight > 0 then
        titleLabel = UI.Create("TextLabel", {
            Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1, Text = tostring(config.Name), TextSize = 12,
            Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = Z_INDEX.Content + 3, Parent = root, Theme = { TextColor3 = "LabelText" },
        })
    end
    local placeholder = UI.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, height), Position = UDim2.fromOffset(0, headerHeight),
        BackgroundTransparency = 1, Text = normalizeText(config.Placeholder, "-- no code to display"),
        TextSize = fontSize, Font = font,
        ZIndex = Z_INDEX.Content + 3, Parent = root, Theme = { TextColor3 = "DescText" },
    })
    local scroll = UI.Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, height), Position = UDim2.fromOffset(0, headerHeight),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY, ScrollBarThickness = 3,
        Visible = false, ZIndex = Z_INDEX.Content + 2, Parent = root,
        Theme = { ScrollBarImageColor3 = "ScrollThumb" },
    })
    return root, titleLabel, placeholder, scroll
end

local function createCodeLabels(scroll, config, font, fontSize)
    local showLineNumbers = config.LineNumbers ~= false
    local numbers = UI.Create("TextLabel", {
        Size = UDim2.fromOffset(showLineNumbers and 42 or 0, 0), Position = UDim2.fromOffset(7, 6),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "",
        TextSize = fontSize, Font = font, TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Top, ZIndex = Z_INDEX.Content + 3,
        Visible = showLineNumbers, Parent = scroll, TextColor3 = Color3.fromRGB(75, 75, 90),
    })
    local codeLabel = UI.Create("TextLabel", {
        Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(showLineNumbers and 56 or 9, 6),
        AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Text = "",
        TextSize = fontSize, Font = font, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false,
        ZIndex = Z_INDEX.Content + 3, Parent = scroll, Theme = { TextColor3 = "LabelText" },
    })
    return numbers, codeLabel, showLineNumbers
end

local function setCodeViewCode(component, value)
    local code = normalizeText(value, "")
    if #code > LIMITS.MaxCodeCharacters then
        reportError("code view input was truncated at " .. tostring(LIMITS.MaxCodeCharacters) .. " characters")
        code = code:sub(1, LIMITS.MaxCodeCharacters) .. "\n-- [truncated]"
    end
    component._code = code
    local hasCode = code ~= ""
    component._codePlaceholder.Visible = not hasCode
    component._codeScroll.Visible = hasCode
    component._codeLabel.Text = hasCode and code or ""
    component._lineNumbers.Text = hasCode and component._showLineNumbers
        and lineNumberText(countCodeLines(code)) or ""
    component._codeScroll.CanvasPosition = Vector2.new(0, 0)
    return component
end

local function installCodeViewMethods(component)
    component.SetCode = setCodeViewCode
    function component:Set(value) return self:SetCode(value) end
    function component:Clear() return self:SetCode("") end
    function component:GetCode() return self._code end
    function component:Get() return self._code end
    function component:ScrollTop() self._codeScroll.CanvasPosition = Vector2.new(0, 0); return self end
    function component:ScrollBottom() self._codeScroll.CanvasPosition = Vector2.new(0, 1000000000); return self end
end

function TabMethods:AddCodeView(config)
    config = type(config) == "table" and config or {}
    local height = clamp(numberOr(config.Height, 160), 60, 1200)
    local headerHeight = config.Name ~= nil and 30 or 0
    local font = config.Monospace == false and Enum.Font.Gotham or Enum.Font.RobotoMono
    local fontSize = clamp(numberOr(config.FontSize, 11), 8, 32)
    local root, titleLabel, placeholder, scroll =
        createCodeViewRoot(self, config, height, headerHeight, font, fontSize)
    local numbers, codeLabel, showLineNumbers = createCodeLabels(scroll, config, font, fontSize)
    local component = newComponent(self, root, titleLabel, nil)
    component._code, component._codePlaceholder, component._codeScroll = "", placeholder, scroll
    component._lineNumbers, component._codeLabel = numbers, codeLabel
    component._showLineNumbers = showLineNumbers
    installCodeViewMethods(component)
    if config.Code ~= nil then component:SetCode(config.Code) end
    return component
end

end

function TabMethods:AddSplitPanel(config)
    config = type(config) == "table" and config or {}
    local height = clamp(numberOr(config.Height, 260), 60, 1400)
    local leftWidth = clamp(numberOr(config.LeftWidth, 180), 40, 1000)
    local root = self:_createStandalone(height, "SplitPanel")
    if robloxType(config.Bg) == "Color3" then ThemeManager.Unbind(root); root.BackgroundColor3 = config.Bg end
    local left = UI.Create("Frame", {
        Size = UDim2.new(0, leftWidth, 1, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ClipsDescendants = true, ZIndex = Z_INDEX.Content + 2, Parent = root,
    })
    UI.RoundCorners(left, 13, {
        TopLeft = true, TopRight = false, BottomRight = false, BottomLeft = true,
    })
    local divider = UI.Create("Frame", {
        Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(leftWidth, 0),
        BorderSizePixel = 0, ZIndex = Z_INDEX.Content + 2, Parent = root,
        Theme = { BackgroundColor3 = "Separator" },
    })
    local right = UI.Create("Frame", {
        Size = UDim2.new(1, -(leftWidth + 1), 1, 0), Position = UDim2.fromOffset(leftWidth + 1, 0),
        BorderSizePixel = 0, ClipsDescendants = true, ZIndex = Z_INDEX.Content + 2,
        Parent = root, Theme = { BackgroundColor3 = "CodeBg" },
    })
    UI.RoundCorners(right, 13, {
        TopLeft = false, TopRight = true, BottomRight = true, BottomLeft = false,
    })
    if robloxType(config.RightBg) == "Color3" then ThemeManager.Unbind(right); right.BackgroundColor3 = config.RightBg end
    local component = newComponent(self, root, nil, nil)
    component.Left = left
    component.Right = right
    function component:SetLeftWidth(value)
        leftWidth = clamp(numberOr(value, leftWidth), 40, math.max(40, root.AbsoluteSize.X - 40))
        left.Size = UDim2.new(0, leftWidth, 1, 0)
        divider.Position = UDim2.fromOffset(leftWidth, 0)
        right.Size = UDim2.new(1, -(leftWidth + 1), 1, 0)
        right.Position = UDim2.fromOffset(leftWidth + 1, 0)
        return self
    end
    function component:GetFrame() return root end
    return component
end

do -- Button grid control helpers.
local function updateGridHeight(component)
    if component._gridLayout.Parent ~= nil then
        component._root.Size = UDim2.new(1, 0, 0, component._gridLayout.AbsoluteContentSize.Y + 2)
    end
end

local function createGridButton(component, config)
    config = type(config) == "table" and config or {}
    local danger = config.Danger == true
    local tasks = TaskGroup.new("GridButton")
    component._tasks:Add(tasks)
    local button = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0,
        Text = normalizeText(config.Label, "Button"), TextSize = 11, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, LayoutOrder = #component._gridButtons + 1,
        ZIndex = Z_INDEX.Content + 2, Parent = component._root,
        Theme = {
            BackgroundColor3 = danger and "DangerBg" or "InputBg",
            TextColor3 = danger and "DangerText" or "LabelText",
        },
    })
    UI.Round(button, 6)
    local object = { Instance = button, _tasks = tasks, _danger = danger, _destroyed = false }
    UI.Hover(tasks, button,
        function() return object._danger and ThemeManager.Values.DangerBg or ThemeManager.Values.InputBg end,
        function() return object._danger and ThemeManager.Values.DangerHover or ThemeManager.Values.RowHover end,
        function() return object._danger and ThemeManager.Values.DangerBg or ThemeManager.Values.RowBg end)
    ThemeManager.Bind(button, {
        BackgroundColor3 = function()
            if component._gridDisabled then return ThemeManager.Values.DisabledBg end
            return object._danger and ThemeManager.Values.DangerBg or ThemeManager.Values.InputBg
        end,
        TextColor3 = function()
            if component._gridDisabled then return ThemeManager.Values.DisabledText end
            return object._danger and ThemeManager.Values.DangerText or ThemeManager.Values.LabelText
        end,
    })
    button.Active = component._enabled and not component._gridDisabled
    button.TextTransparency = button.Active and 0 or 0.5
    tasks:Connect(button.Activated, function()
        if component._enabled and not component._gridDisabled and type(config.Callback) == "function" then
            safeCall(config.Callback, object, component)
        end
    end)
    function object:SetLabel(text) button.Text = normalizeText(text, ""); return self end
    function object:SetDanger(value)
        self._danger = value == true
        ThemeManager.ApplyBinding(button, ThemeManager._bindings[button])
        return self
    end
    function object:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        component._tasks:Cancel(tasks)
        removeArrayValue(component._gridButtons, self, LIMITS.MaxRows)
        if button.Parent ~= nil then button:Destroy() end
        updateGridHeight(component)
    end
    component._gridButtons[#component._gridButtons + 1] = object
    updateGridHeight(component)
    return object
end

function TabMethods:AddButtonGrid(config)
    config = type(config) == "table" and config or {}
    local columns = clamp(math.floor(numberOr(config.Columns, 3)), 1, 12)
    local buttonHeight = clamp(numberOr(config.ButtonHeight, 28), 22, 100)
    local root = self:_createStandalone(2, "ButtonGrid")
    ThemeManager.Unbind(root)
    root.BackgroundTransparency = 1
    local rootStroke = root:FindFirstChildOfClass("UIStroke")
    if rootStroke ~= nil then rootStroke.Transparency = 1 end
    local gap = 4
    local layout = UI.Create("UIGridLayout", {
        CellSize = UDim2.new(1 / columns, -((gap * (columns - 1)) / columns), 0, buttonHeight),
        CellPadding = UDim2.fromOffset(gap, gap), FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = root,
    })
    local component = newComponent(self, root, nil, nil)
    component._gridLayout = layout
    component._gridButtons = {}
    component._gridDisabled = false
    function component:AddButton(buttonConfig)
        if #self._gridButtons >= LIMITS.MaxRows then return nil end
        return createGridButton(self, buttonConfig)
    end
    function component:SetEnabled(value)
        self._gridDisabled = value ~= true
        local count = math.min(#self._gridButtons, LIMITS.MaxRows)
        for index = 1, count do
            local entry = self._gridButtons[index]
            local button = entry.Instance
            button.Active = not self._gridDisabled
            button.TextTransparency = self._gridDisabled and 0.5 or 0
            ThemeManager.ApplyBinding(button, ThemeManager._bindings[button])
        end
        return self
    end
    function component:Clear()
        for index = math.min(#self._gridButtons, LIMITS.MaxRows), 1, -1 do self._gridButtons[index]:Destroy() end
        self._gridButtons = {}
        updateGridHeight(self)
        return self
    end
    component._applyEnabled = function(_, enabled) component:SetEnabled(enabled) end
    component._tasks:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function() updateGridHeight(component) end)
    local buttons = type(config.Buttons) == "table" and config.Buttons or {}
    for index = 1, math.min(#buttons, LIMITS.MaxRows) do component:AddButton(buttons[index]) end
    updateGridHeight(component)
    return component
end

end

do -- Expandable item control helpers.
local function refreshExpandableHeight(component)
    local contentHeight = component._expanded and (component._buttonLayout.AbsoluteContentSize.Y + 12) or 0
    local target = component._headerHeight + contentHeight
    UI.Tween(component._root, { Size = UDim2.new(1, 0, 0, target) }, TWEEN.Medium)
end

local function createExpandableButton(component, config)
    config = type(config) == "table" and config or {}
    local danger = config.Danger == true
    local tasks = TaskGroup.new("ExpandableButton")
    component._tasks:Add(tasks)
    local button = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0,
        Text = normalizeText(config.Label, "Button"), TextSize = 11, Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false, LayoutOrder = #component._buttons + 1,
        ZIndex = Z_INDEX.Content + 4, Parent = component._buttonArea,
        Theme = { BackgroundColor3 = danger and "DangerBg" or "InputBg", TextColor3 = danger and "DangerText" or "LabelText" },
    })
    UI.Round(button, 6)
    local object = { Instance = button, _tasks = tasks, _danger = danger, _destroyed = false }
    UI.Hover(tasks, button,
        function() return object._danger and ThemeManager.Values.DangerBg or ThemeManager.Values.InputBg end,
        function() return object._danger and ThemeManager.Values.DangerHover or ThemeManager.Values.RowHover end)
    ThemeManager.Bind(button, {
        BackgroundColor3 = function()
            if not component._enabled then return ThemeManager.Values.DisabledBg end
            return object._danger and ThemeManager.Values.DangerBg or ThemeManager.Values.InputBg
        end,
        TextColor3 = function()
            if not component._enabled then return ThemeManager.Values.DisabledText end
            return object._danger and ThemeManager.Values.DangerText or ThemeManager.Values.LabelText
        end,
    })
    button.Active = component._enabled
    button.TextTransparency = component._enabled and 0 or 0.5
    tasks:Connect(button.Activated, function()
        if component._enabled and type(config.Callback) == "function" then
            safeCall(config.Callback, component, object)
        end
    end)
    function object:SetLabel(text) button.Text = normalizeText(text, ""); return self end
    function object:SetDanger(value)
        self._danger = value == true
        ThemeManager.ApplyBinding(button, ThemeManager._bindings[button])
        return self
    end
    function object:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        component._tasks:Cancel(tasks)
        removeArrayValue(component._buttons, self, LIMITS.MaxRows)
        if button.Parent ~= nil then button:Destroy() end
        refreshExpandableHeight(component)
    end
    component._buttons[#component._buttons + 1] = object
    refreshExpandableHeight(component)
    return object
end

local function createExpandableHeader(root, config, headerHeight)
    local header = UI.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, headerHeight), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = Z_INDEX.Content + 3, Parent = root,
    })
    local badge = UI.Create("TextLabel", {
        Size = UDim2.fromOffset(32, 17), Position = UDim2.fromOffset(10, math.floor((headerHeight - 17) / 2)),
        BorderSizePixel = 0, Text = normalizeText(config.Badge, ""), TextSize = 9,
        Font = Enum.Font.GothamBold, Visible = config.Badge ~= nil and tostring(config.Badge) ~= "",
        ZIndex = Z_INDEX.Content + 4, Parent = root,
        Theme = { BackgroundColor3 = "Accent", TextColor3 = "TabActiveText" },
    })
    if robloxType(config.BadgeColor) == "Color3" then
        ThemeManager.Unbind(badge)
        badge.BackgroundColor3 = config.BadgeColor
    end
    UI.Round(badge, 5)
    local labelX = badge.Visible and 50 or 14
    local nameLabel = UI.Create("TextLabel", {
        Size = UDim2.new(1, -(labelX + 42), 0, 16), Position = UDim2.fromOffset(labelX, 7),
        BackgroundTransparency = 1, Text = normalizeText(config.Name, "Item"), TextSize = 12,
        Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Z_INDEX.Content + 4,
        Parent = root, Theme = { TextColor3 = "LabelText" },
    })
    local subtext = UI.Create("TextLabel", {
        Size = UDim2.new(1, -(labelX + 42), 0, 14), Position = UDim2.fromOffset(labelX, 24),
        BackgroundTransparency = 1, Text = normalizeText(config.Subtext, ""), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = Z_INDEX.Content + 4,
        Parent = root, Theme = { TextColor3 = "DescText" },
    })
    local chevron = UI.Create("TextLabel", {
        Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -30, 0, math.floor((headerHeight - 22) / 2)),
        BackgroundTransparency = 1, Text = ">", TextSize = 13, Font = Enum.Font.GothamBold,
        ZIndex = Z_INDEX.Content + 4, Parent = root, Theme = { TextColor3 = "DescText" },
    })
    return header, badge, nameLabel, subtext, chevron
end

local function createExpandableComponent(tab, config, headerHeight, columns, buttonHeight)
    local root = tab:_createStandalone(headerHeight, "ExpandableItem")
    root.ClipsDescendants = true
    local header, badge, nameLabel, subtext, chevron = createExpandableHeader(root, config, headerHeight)
    local buttonArea = UI.Create("Frame", {
        Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, headerHeight + 6),
        BackgroundTransparency = 1, ZIndex = Z_INDEX.Content + 3, Parent = root,
    })
    local gap = 4
    local layout = UI.Create("UIGridLayout", {
        CellSize = UDim2.new(1 / columns, -((gap * (columns - 1)) / columns), 0, buttonHeight),
        CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = buttonArea,
    })
    local component = newComponent(tab, root, nameLabel, subtext)
    component._headerHeight, component._buttonArea, component._buttonLayout = headerHeight, buttonArea, layout
    component._buttons, component._expanded, component._selected = {}, false, false
    component._badge, component._chevron, component._header = badge, chevron, header
    component._nameLabel, component._subtext = nameLabel, subtext
    component._onSelect = config.OnSelect
    return component
end

local function setExpandableBadge(component, text, color)
    component._badge.Text = normalizeText(text, "")
    component._badge.Visible = text ~= nil and tostring(text) ~= ""
    if robloxType(color) == "Color3" then
        ThemeManager.Unbind(component._badge)
        component._badge.BackgroundColor3 = color
    end
    local labelX = component._badge.Visible and 50 or 14
    component._nameLabel.Position = UDim2.fromOffset(labelX, 7)
    component._nameLabel.Size = UDim2.new(1, -(labelX + 42), 0, 16)
    component._subtext.Position = UDim2.fromOffset(labelX, 24)
    component._subtext.Size = UDim2.new(1, -(labelX + 42), 0, 14)
    return component
end

local function setExpandableEnabled(component, enabled)
    component._header.Active = enabled
    local count = math.min(#component._buttons, LIMITS.MaxRows)
    for index = 1, count do
        local button = component._buttons[index].Instance
        button.Active = enabled
        button.TextTransparency = enabled and 0 or 0.5
        ThemeManager.ApplyBinding(button, ThemeManager._bindings[button])
    end
end

local function expandItem(component, expanded)
    component._expanded = expanded
    UI.Tween(component._chevron, { Rotation = expanded and 90 or 0 }, TWEEN.Medium)
    refreshExpandableHeight(component)
    return component
end

function TabMethods:AddExpandableItem(config)
    config = type(config) == "table" and config or {}
    local headerHeight = clamp(numberOr(config.RowHeight, 44), 36, 100)
    local columns = clamp(math.floor(numberOr(config.Columns, 2)), 1, 8)
    local buttonHeight = clamp(numberOr(config.ButtonH, 28), 22, 80)
    local component = createExpandableComponent(self, config, headerHeight, columns, buttonHeight)
    component.AddButton = function(self, buttonConfig)
        if #self._buttons >= LIMITS.MaxRows then return nil end
        return createExpandableButton(self, buttonConfig)
    end
    component.SetName = function(self, text) self._nameLabel.Text = normalizeText(text, ""); self:_refreshSearchText(); return self end
    component.SetLabel = component.SetName
    component.SetSubtext = function(self, text) self._subtext.Text = normalizeText(text, ""); self:_refreshSearchText(); return self end
    component.SetBadge = setExpandableBadge
    component.Select = function(self) self._selected = true; UI.Tween(self._root, { BackgroundColor3 = ThemeManager.Values.TabHover }, TWEEN.Fast); return self end
    component.Deselect = function(self) self._selected = false; UI.Tween(self._root, { BackgroundColor3 = ThemeManager.Values.RowBg }, TWEEN.Fast); return self end
    component.Expand = function(self) return expandItem(self, true) end
    component.Collapse = function(self) return expandItem(self, false) end
    component.Toggle = function(self) return expandItem(self, not self._expanded) end
    component.IsExpanded = function(self) return self._expanded end
    component.Remove = function(self) self:Destroy() end
    component._applyEnabled = setExpandableEnabled
    local header, layout, buttonArea = component._header, component._buttonLayout, component._buttonArea
    component._tasks:Connect(header.Activated, function()
        if not component._enabled then return end
        component:Toggle()
        if type(component._onSelect) == "function" then safeCall(component._onSelect, component) end
    end)
    component._tasks:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        buttonArea.Size = UDim2.new(1, -16, 0, layout.AbsoluteContentSize.Y)
        refreshExpandableHeight(component)
    end)
    local buttons = type(config.Buttons) == "table" and config.Buttons or {}
    for index = 1, math.min(#buttons, LIMITS.MaxRows) do component:AddButton(buttons[index]) end
    refreshExpandableHeight(component)
    return component
end

end

function TabMethods:AddDivider(config)
    config = type(config) == "table" and config or {}
    local height = clamp(numberOr(config.Height or config.Margin, 22), 4, 100)
    local order = self:_nextOrder()
    local root = UI.Create("Frame", {
        Name = "Divider_" .. tostring(order), Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1, LayoutOrder = order, ZIndex = Z_INDEX.Content + 1,
        Parent = self:_parentForComponent(),
    })
    local line = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0),
        BorderSizePixel = 0, ZIndex = Z_INDEX.Content + 2, Parent = root,
        Theme = { BackgroundColor3 = "Separator" },
    })
    local label
    if config.Label ~= nil and tostring(config.Label) ~= "" then
        label = UI.Create("TextLabel", {
            Size = UDim2.fromOffset(clamp((#tostring(config.Label) * 7) + 16, 30, 260), height),
            Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 0,
            Text = tostring(config.Label), TextSize = 10, Font = Enum.Font.GothamSemibold,
            ZIndex = Z_INDEX.Content + 3, Parent = root,
            Theme = { BackgroundColor3 = "ContentBg", TextColor3 = "SectionLabel" },
        })
    end
    if robloxType(config.Color) == "Color3" then ThemeManager.Unbind(line); line.BackgroundColor3 = config.Color end
    return newComponent(self, root, label, nil)
end

function TabMethods:AddRichText(config)
    config = type(config) == "table" and config or {}
    local order = self:_nextOrder()
    local fixedHeight = config.Height ~= nil and clamp(numberOr(config.Height, 50), 20, 1000) or nil
    local root = UI.Create("Frame", {
        Name = "RichText_" .. tostring(order),
        Size = UDim2.new(1, 0, 0, fixedHeight or 0),
        AutomaticSize = fixedHeight == nil and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        BackgroundTransparency = 1, LayoutOrder = order,
        ZIndex = Z_INDEX.Content + 1, Parent = self:_parentForComponent(),
    })
    local label = UI.Create("TextLabel", {
        Size = fixedHeight and UDim2.new(1, -8, 1, 0) or UDim2.new(1, -8, 0, 0),
        AutomaticSize = fixedHeight == nil and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1,
        Text = normalizeText(config.Text, ""), RichText = config.RichText == true,
        TextSize = clamp(numberOr(config.TextSize, 12), 8, 48),
        Font = robloxType(config.Font) == "EnumItem" and config.Font or Enum.Font.Gotham,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, ZIndex = Z_INDEX.Content + 2,
        Parent = root, Theme = { TextColor3 = "LabelText" },
    })
    if robloxType(config.Color) == "Color3" then ThemeManager.Unbind(label); label.TextColor3 = config.Color end
    local component = newComponent(self, root, label, nil)
    function component:Set(value) label.Text = normalizeText(value, ""); self:_refreshSearchText(); return self end
    function component:Get() return label.Text end
    function component:SetColor(color)
        if robloxType(color) == "Color3" then ThemeManager.Unbind(label); label.TextColor3 = color end
        return self
    end
    return component
end

do -- Loading screen helpers.
local function createLoaderRoot()
    local screenGui = UI.Create("ScreenGui", {
        Name = "CrispyLib_Loader",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 2000,
    })
    local ok, err = Runtime.ParentScreenGui(screenGui)
    if not ok then
        screenGui:Destroy()
        return nil, err
    end

    MobileUI.SafeScreen(screenGui, MobileUI.TouchMode("Auto"))
    local background = UI.Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0,
        ZIndex = 1, Parent = screenGui, Theme = { BackgroundColor3 = "LoaderBg" },
    })
    UI.Gradient(background, "WindowGradientStart", "WindowGradientEnd", 140, 0)
    local center = UI.Create("Frame", {
        Size = UDim2.fromOffset(420, 320), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = ThemeManager.Values.PanelTransparency,
        BorderSizePixel = 0, ZIndex = 2, Parent = background,
        Theme = { BackgroundColor3 = "RowBg", BackgroundTransparency = "PanelTransparency" },
    })
    UI.Round(center, 22)
    UI.Stroke(center, nil, 1.25, 0.32)
    UI.Gradient(center, "SurfaceGradientStart", "SurfaceGradientEnd", 125, 0.1)
    return screenGui, background, center
end

local function createLoaderLogo(center, config)
    local logo = normalizeText(config.LogoId or config.Logo, "")
    if logo == "" then return 52 end
    local logoFrame = UI.Create("Frame", {
        Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0.5, -36, 0, 24),
        BackgroundTransparency = ThemeManager.Values.RowTransparency,
        BorderSizePixel = 0, ZIndex = 3, Parent = center,
        Theme = { BackgroundColor3 = "RowBg", BackgroundTransparency = "RowTransparency" },
    })
    UI.Round(logoFrame, 18)
    UI.Stroke(logoFrame, nil, 1, 0.46)
    UI.Gradient(logoFrame, "AccentGradientStart", "AccentGradientEnd", 20, 0.2)
    UI.Create("ImageLabel", {
        Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, -28, 0.5, -28),
        BackgroundTransparency = 1, Image = logo, ZIndex = 4, Parent = logoFrame,
    })
    return 108
end

local function createLoaderContent(center, config, yOffset)
    UI.Create("TextLabel", {
        Size = UDim2.new(1, -56, 0, 36), Position = UDim2.fromOffset(28, yOffset),
        BackgroundTransparency = 1, Text = normalizeText(config.Title, "Loading"), TextSize = 26,
        Font = Enum.Font.GothamBold, ZIndex = 3, Parent = center, Theme = { TextColor3 = "TitleText" },
    })
    local subtitle = UI.Create("TextLabel", {
        Size = UDim2.new(1, -56, 0, 18), Position = UDim2.fromOffset(28, yOffset + 40),
        BackgroundTransparency = 1, Text = normalizeText(config.Subtitle, ""), TextSize = 13,
        Font = Enum.Font.Gotham, ZIndex = 3, Parent = center, Theme = { TextColor3 = "SubtitleText" },
    })
    local track = UI.Create("Frame", {
        Size = UDim2.new(1, -56, 0, 7), Position = UDim2.fromOffset(28, yOffset + 74),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0, ZIndex = 3, Parent = center, Theme = { BackgroundColor3 = "LoaderTrack" },
    })
    UI.Round(track, 3)
    local fill = UI.Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0,
        ZIndex = 4, Parent = track, Theme = { BackgroundColor3 = "LoaderFill" },
    })
    UI.Round(fill, 3)
    UI.Gradient(fill, "AccentGradientStart", "AccentGradientEnd", 0, 0)
    local status = UI.Create("TextLabel", {
        Size = UDim2.new(1, -56, 0, 18), Position = UDim2.fromOffset(28, yOffset + 90),
        BackgroundTransparency = 1, Text = "", TextSize = 11,
        Font = Enum.Font.Gotham, ZIndex = 3, Parent = center, Theme = { TextColor3 = "DescText" },
    })
    local taskList = UI.Create("Frame", {
        Size = UDim2.new(1, -56, 0, 76), Position = UDim2.fromOffset(28, yOffset + 114),
        BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = center,
    })
    UI.List(taskList, Enum.FillDirection.Vertical, 4)
    return subtitle, track, fill, status, taskList
end

local function createLoaderScreen(config)
    local screenGui, background, centerOrError = createLoaderRoot()
    if screenGui == nil then return nil, background end
    local center = centerOrError
    local yOffset = createLoaderLogo(center, config)
    local subtitle, track, fill, status, taskList = createLoaderContent(center, config, yOffset)
    return {
        ScreenGui = screenGui, Background = background, Center = center,
        Subtitle = subtitle, Track = track, Fill = fill, Status = status, TaskList = taskList,
    }
end

local function fadeLoader(loader)
    local descendants = loader._ui.Background:GetDescendants()
    local count = math.min(#descendants, 512)
    UI.Tween(loader._ui.Background, { BackgroundTransparency = 1 }, TWEEN.Medium)
    for index = 1, count do
        local item = descendants[index]
        if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
            UI.Tween(item, { TextTransparency = 1, BackgroundTransparency = 1 }, TWEEN.Medium)
        elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
            UI.Tween(item, { ImageTransparency = 1, BackgroundTransparency = 1 }, TWEEN.Medium)
        elseif item:IsA("Frame") then
            UI.Tween(item, { BackgroundTransparency = 1 }, TWEEN.Medium)
        elseif item:IsA("UIStroke") then
            UI.Tween(item, { Transparency = 1 }, TWEEN.Medium)
        end
    end
end

local function stopLoaderPulse(loader)
    if loader._pulseTween ~= nil then
        pcall(function() loader._pulseTween:Cancel() end)
        loader._pulseTween = nil
    end
end

local function setLoaderProgress(loader, value)
    if loader._destroyed then return loader end
    local progress = clamp(numberOr(value, 0), 0, 1)
    UI.Tween(loader._ui.Fill, { Size = UDim2.new(progress, 0, 1, 0) }, TWEEN.Medium)
    return loader
end

local function addLoaderTask(loader, text)
    if loader._destroyed or loader._taskCount >= 50 then return loader end
    loader._taskCount = loader._taskCount + 1
    UI.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
        Text = "OK  " .. normalizeText(text, ""), TextSize = 11, Font = Enum.Font.Gotham,
        LayoutOrder = loader._taskCount, ZIndex = 4, Parent = loader._ui.TaskList,
        Theme = { TextColor3 = "DescText" },
    })
    return loader
end

local function finishLoader(loader, callback)
    if loader._destroyed or loader._finished then return loader end
    loader._finished = true
    local remaining = math.max(0, loader._minimumTime - (os.clock() - loader._startedAt))
    loader._tasks:Delay(remaining, function()
        if loader._destroyed then return end
        loader:SetProgress(1)
        loader._tasks:Delay(0.25, function()
            if loader._destroyed then return end
            fadeLoader(loader)
            loader._tasks:Delay(0.34, function()
                loader:Destroy()
                if type(callback) == "function" then safeCall(callback) end
            end)
        end)
    end)
    return loader
end

local function destroyLoader(loader)
    if loader._destroyed then return end
    loader._destroyed = true
    stopLoaderPulse(loader)
    loader._tasks:Destroy()
    if loader._ui.ScreenGui.Parent ~= nil then loader._ui.ScreenGui:Destroy() end
    removeArrayValue(CrispyLib._loaders, loader, LIMITS.MaxWindows)
end

local function createLoadingScreen(config)
    if #CrispyLib._loaders >= LIMITS.MaxWindows then
        error("[CrispyLib] loading-screen limit reached", 2)
    end
    local ui, uiError = createLoaderScreen(config)
    if ui == nil then error("[CrispyLib] cannot create loading screen: " .. tostring(uiError), 2) end
    local group = TaskGroup.new("LoadingScreen")
    local loader = {
        Instance = ui.ScreenGui, _ui = ui, _tasks = group, _startedAt = os.clock(),
        _minimumTime = math.max(numberOr(config.MinimumTime, 0), 0),
        _finished = false, _destroyed = false, _taskCount = 0, _pulseTween = nil,
    }
    loader.SetProgress, loader.AddTask, loader.Finish, loader.Destroy =
        setLoaderProgress, addLoaderTask, finishLoader, destroyLoader
    loader.SetStatus = function(self, text)
        if not self._destroyed then self._ui.Status.Text = normalizeText(text, "") end
        return self
    end
    local panelScale = UI.Create("UIScale", { Scale = 1, Parent = ui.Center })
    local function fitLoader()
        local _, viewport = MobileUI.Bounds(ui.Background)
        panelScale.Scale = math.max(0.01, math.min(1, (viewport.X - 24) / 420, (viewport.Y - 24) / 320))
    end
    group:Connect(ui.Background:GetPropertyChangedSignal("AbsoluteSize"), fitLoader)
    fitLoader()
    local pulseOk, pulse = pcall(function()
        return TweenService:Create(ui.Fill,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundColor3 = ThemeManager.Values.AccentHover })
    end)
    if pulseOk then loader._pulseTween = pulse; pulse:Play() end
    group:Connect(ui.ScreenGui.Destroying, function()
        if not loader._destroyed then
            loader._destroyed = true
            stopLoaderPulse(loader)
            group:Destroy()
            removeArrayValue(CrispyLib._loaders, loader, LIMITS.MaxWindows)
        end
    end)
    CrispyLib._loaders[#CrispyLib._loaders + 1] = loader
    return loader
end

function CrispyLib.CreateLoadingScreen(first, second)
    return createLoadingScreen(normalizeConfig(first, second, CrispyLib))
end

end

function CrispyLib.DestroyAll()
    Config.StopAutoSave()
    if System._statsHandle ~= nil then System._statsHandle:Destroy() end
    NotificationManager.Destroy()

    for index = math.min(#CrispyLib._loaders, LIMITS.MaxWindows), 1, -1 do
        local loader = CrispyLib._loaders[index]
        if loader ~= nil then loader:Destroy() end
    end
    for index = math.min(#CrispyLib._windows, LIMITS.MaxWindows), 1, -1 do
        local window = CrispyLib._windows[index]
        if window ~= nil then window:Destroy() end
    end
    local taskGroups = CrispyLib._taskGroups
    CrispyLib._taskGroups = {}
    for index = math.min(#taskGroups, LIMITS.MaxTaskItems), 1, -1 do
        local group = taskGroups[index]
        if group ~= nil then group:Destroy() end
        taskGroups[index] = nil
    end
    CrispyLib.Tasks:Destroy()
    CrispyLib.Tasks = CrispyLib.CreateTaskGroup("CrispyLib")
    startFpsSampler()
    return true
end

return CrispyLib
