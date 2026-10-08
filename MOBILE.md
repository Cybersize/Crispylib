# CrispyLib 3.4.0 mobile UI

Mobile support is enabled automatically on touch-capable devices. Existing window, tab, control, and config calls continue to work.

```lua
local Window = CrispyLib:CreateWindow({
    Title = "My UI",
    MobileMode = "Auto", -- "Auto", "Touch", or "Desktop"
    MobileToggle = true,
    MobileToggleText = "UI",
    MobileTogglePosition = UDim2.new(1, -60, 0.5, -24),
})

Window:SetMobileMode("Touch") -- optional, also useful for desktop previews
print(Window:GetMobileMode())
```

Omit these settings to use the defaults. `Auto` uses `UserInputService.TouchEnabled`; `Touch` forces touch sizing and tap actions; `Desktop` uses keyboard binding controls and desktop target sizes. Small windows use a compact layout in every mode. Set `MobileToggle = false` only when your script provides another way to show a hidden window.

On phones, the menu button opens the tabs over the content. Selecting a tab or tapping the dimmed backdrop closes the drawer. Controls stack below their labels when a row is narrow. Standard interactive controls have larger touch targets, including a 44-pixel slider hit area. Segmented choices and chips scroll horizontally when necessary.

The floating UI button shows or hides its own window and can be dragged. Dragging it does not toggle the window. The close button hides a touch window while its floating button is available; `Window:Destroy()` still permanently destroys the window and its owned controls.

## Keybind controls

A touch keybind displays **Run**. Tapping it invokes the control's callback with its current `Enum.KeyCode`, without changing the saved keyboard binding or config flag. Mouse/gamepad activation in forced Touch mode invokes the same action. Physical keyboard bindings still work.

```lua
local Action = Tab:AddKeybind({
    Name = "My action",
    Default = Enum.KeyCode.F,
    Callback = function(key)
        print("Action", key)
    end,
    -- Optional: use a different callback for the touch action.
    TouchCallback = function(key)
        print("Touch action", key)
    end,
    -- MobileAction = false keeps the keyboard capture editor.
})

Action:Trigger() -- optional explicit invocation; respects disabled/destroyed state
```

This invokes the supplied function. Consumer code that checks physical mouse or keyboard input separately still needs its own touch input handling.

## Screen changes and input ownership

Windows refit to the ScreenGui safe area and remain reachable when the display rotates or the current camera is replaced. Dropdowns and color panels stay inside that area; color panels can scroll on short screens. Modal actions wrap into a scrollable footer and long messages scroll independently. Notification widths and loading panels also fit small displays.

Opening the software keyboard reduces the usable area. Open dropdown searches and temporary color selections are retained while their panels refit. Focused fields inside scrolling panels are brought into view. Very short compact windows use a smaller header to leave room for content.

One pointer owns a drag until it ends. Extra fingers cannot steal it. Slider/color dragging temporarily suspends its containing scroll panel and restores its previous scrolling setting on release, cancellation, focus loss, tab switching, hiding, or destruction. Owned input-state connections are removed when the gesture ends.

The changes use Roblox's [cross-platform button activation](https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated), [ScreenGui safe insets](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets), and [software keyboard properties](https://create.roblox.com/docs/reference/engine/classes/UserInputService#OnScreenKeyboardVisible).

## Verification

The library compiles with official Luau 0.740 tools. The existing 11 core and 14 config regression groups and 12 mobile regression groups pass. Mobile checks execute the actual window/control/input implementations against a UI model, including portrait/landscape geometry, camera swaps, pointer cancellation, click/end event ordering, popup fitting, software keyboards, mode switching, and cleanup.

The UI model does not render Roblox widgets or emulate operating-system touch input. Live rendering, scrolling gestures, and native keyboard behavior still need verification in Roblox on a phone/tablet. The [mobile example](mobile-example.lua) provides a UI-only smoke test. Download the release asset as `CrispyLib.lua` into your script workspace before running it.
