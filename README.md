# Claude UI

Roblox UI library: the Ghost Pepper UI structure with the Chilli Library look (Gotham SSm titles with the game's
black outline, shiny headers, red Rebirth buttons, green toggles, collapsible sections, right-side tabs).

## Load

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/okame7x/claude-ui/main/claudeui.lua"))()
```

## Demo

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/okame7x/claude-ui/main/demo.lua"))()
```

## Quick start

```lua
local Window = Library:CreateWindow({ Name = "My Hub", ToggleUIKeybind = "RightControl" })

local Main = Window:CreateTab({ Name = "Main", Icon = "house", SectionsExpanded = true })
local Farm = Main:CreateSection({ Name = "Auto Farm", Expanded = true })

Farm:CreateToggle({ Name = "Auto Farm", CurrentValue = false, Flag = "AutoFarm", Callback = print })
Farm:CreateButton({ Name = "Sell", Callback = function() end })

local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings", Side = "Right" })
```

Elements: `CreateToggle`, `CreateButton`, `CreateSlider`, `CreateStepper`, `CreateDropdown`, `CreateInput`,
`CreateKeybind`, `CreateColorPicker`, `CreateProgress`, `CreateText`, `CreateLabel`, `CreateParagraph`,
`CreateDivider`, `CreateConfigManager`. Sections: `section:SetExpanded(bool)`, `section:SetTitle(text)`.
Popups: `Library:Notify`, `Library:Confirm`, `Library:Dialog`.
