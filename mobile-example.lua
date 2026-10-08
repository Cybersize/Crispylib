-- UI-only mobile smoke test. Copy the updated library into the executor workspace
-- as CrispyLib.lua, then execute this file in a Roblox client.
assert(type(readfile) == "function" and type(loadstring) == "function", "This example needs readfile and loadstring")
local CrispyLib = assert(loadstring(readfile("CrispyLib.lua")))()
local Window = CrispyLib:CreateWindow({
    Title = "Mobile UI test",
    Subtitle = "Touch, rotate, type, and reopen",
    MobileMode = "Auto",
    MobileToggle = true,
    ConfigName = "CrispyMobileTest",
    ConfigStorage = false,
})
local Tab = Window:AddTab({ Name = "Controls" })
local Status = Tab:AddLabel({ Name = "Last callback", Value = "Ready" })
local actionCount = 0
local function action()
    actionCount += 1
    Status:Set("Action " .. actionCount)
end
Tab:AddToggle({ Name = "Toggle", Description = "Tap the switch; OFF must remain false after config loading.",
    Flag = "mobile_toggle", Callback = function(value) Status:Set("Toggle: " .. tostring(value)) end })
Tab:AddSlider({ Name = "Slider", Description = "Drag with one finger, then touch elsewhere with a second finger.",
    Flag = "mobile_slider", Min = 0, Max = 100, Default = 25,
    Callback = function(value) Status:Set("Slider: " .. tostring(value)) end })
Tab:AddInput({ Name = "Text", Description = "Open the native keyboard and type.", Default = "Hello", Flag = "mobile_text",
    Callback = function(value) Status:Set(value) end })
Tab:AddNumberInput({ Name = "Number", Min = 0, Max = 100, Default = 5, Flag = "mobile_number" })
Tab:AddDropdown({ Name = "Dropdown", Options = { "One", "Two", "Three", "Four", "Five", "Six", "Seven" },
    Width = 480, Flag = "mobile_dropdown", Callback = function(value) Status:Set(value) end })
Tab:AddCheckboxGroup({ Name = "Multiple choices", Options = { "One", "Two", "Three", "Four", "Five" }, Flag = "mobile_choices" })
Tab:AddSegmentedControl({ Name = "Segments", Options = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta" } })
Tab:AddChipGroup({ Name = "Chips", Multi = true, Options = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta" } })
Tab:AddColorPicker({ Name = "Color", Default = Color3.fromRGB(80, 170, 255), Flag = "mobile_color" })
Tab:AddTextArea({ Name = "Notes", Description = "Try the keyboard in portrait and landscape.", Default = "Mobile notes" })
Tab:AddButton({ Name = "Action", Callback = action })
Tab:AddKeybind({ Name = "Tap action / keyboard F", Default = Enum.KeyCode.F, Callback = action })
local Settings = Window:AddTab({ Name = "Layout and config" })
Settings:AddDropdown({ Name = "Input layout", Options = { "Auto", "Touch", "Desktop" }, Default = "Auto",
    Callback = function(mode) Window:SetMobileMode(mode) end })
Settings:AddButton({ Name = "Hide window", Callback = function() Window:Hide() end })
Settings:AddButton({ Name = "Modal", Callback = function()
    local buttons = {}
    for index = 1, 8 do buttons[index] = { Text = "Choice " .. index } end
    Window:CreateModal({ Title = "Eight actions", Message = string.rep("Scroll this message. ", 40),
        Visible = true, Width = 800, Buttons = buttons })
end })
Settings:AddButton({ Name = "Save config", Callback = function()
    local ok, err = CrispyLib.Config.Save("mobile")
    Status:Set(ok and "Saved in memory" or tostring(err))
end })
Settings:AddButton({ Name = "Load config", Callback = function()
    local ok, err = CrispyLib.Config.Load("mobile")
    Status:Set(ok and "Loaded; callbacks reapplied" or tostring(err))
end })
Settings:AddButton({ Name = "Notify", Callback = function()
    CrispyLib.Notify({ Title = "Mobile UI", Description = "Check small-screen width and the close button." })
end })
