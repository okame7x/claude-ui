# Bloom Hub UI

Roblox UI library for Bloom Hub: dark plum surfaces with a blossom pink accent, Gotham SSm titles with an ink
outline, shiny headers, pink gradient buttons, collapsible sections, right-side tabs and a clean floating icon, plus
Status and Steal HUD templates.

## Load

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/okame7x/claude-ui/main/claudeui.lua"))()
```

## Demo

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/okame7x/claude-ui/main/demo.lua"))()
```

## Window

```lua
local Window = Library:CreateWindow({ Name = "Bloom Hub", ToggleUIKeybind = "RightControl" })

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

## Status HUD

```lua
local Status = Library:CreateStatus({ Title = "Bloom Hub" })

Status:Set({
    Text = "Taking Astral Jackalope",
    State = "active",                -- "active" | "waiting" | "idle"
    Tag = "AUTO FARM",
    Icon = "rbxassetid://...",       -- or Model = someModel for a spinning 3D preview
    Chips = { { Text = "MYTHIC", Colors = { c1, c2 } }, { Text = "$30M/s" } },  -- replaces Detail
    Steps = { Names = { "Run", "Take", "Deliver" }, Current = 2 },             -- or:
    Bar = { Fraction = 0.35, Text = "7/20 eggs", Colors = { c1, c2 } },
})
Status:SetStat("STOLEN", 12)         -- FPS and PING are built in (3 tiles max)
Status:SetVisible(false)
Status:Destroy()
```

## Steal HUD

```lua
local Steal = Library:CreateStealPanel({
    Title = "Steal", Side = "Right",
    OnSteal = function(id) end,
    OnQueue = function(id) end,
    OnMove = function(id, step) end,   -- optional: reorder arrows on queued cards
})
Steal:SetSubtitle("3 eggs  |  queue 1")

Steal:SetItems({
    { Id = "uid", Name = "Astral Jackalope", Icon = "rbxassetid://...", Badge = "rbxassetid://...",
      Rarity = "Mythic", RarityColor = Color3.fromRGB(200, 120, 255),
      Value = "$30M/s", Info = "8 kg", Extra = "Gold, Shiny", Featured = true, Tag = "TARGET",
      Queued = 1, CanUp = false, CanDown = true, ActionText = "STEAL" },
})
Steal:SetCollapsed(true)             -- the red tab on its edge also toggles it
Steal:SetVisible(false)
Steal:Destroy()
```

Both HUDs scale with the screen, drag by their edges and reuse their cards on every update.

## Game font

```lua
local Window = Library:CreateWindow({ Name = "Bloom Hub", GameFont = true })  -- or GameFont = { Body = true }
-- or at any time (restyles what is already on screen):
Library:UseGameFont({ Body = false })
```

Picks the font family, weight and style most used by the game's own visible UI text. Windows and HUDs move only
when grabbed by their edges.
