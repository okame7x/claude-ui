-- Bloom Hub UI demo: every element, Chilli-style sections, right-side tabs, and the Status / Steal HUD templates
-- fed with fake data. Everything only prints / notifies.
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/okame7x/claude-ui/main/claudeui.lua"))()

local Window = Library:CreateWindow({
	Name = "Bloom Hub",
	LoadingSubtitle = "Demo",
	ToggleUIKeybind = "RightControl",
	ConfigurationSaving = { Enabled = true, FolderName = "BloomHubDemo", FileName = "default" },
})

local function notify(title, content)
	Library:Notify({ Title = title, Content = content, Icon = "bell", Type = "Success", Duration = 3 })
end

-- Main: collapsible sections (click the header to fold them).
local Main = Window:CreateTab({ Name = "Main", Desc = "Farming and automation", Icon = "house", SectionsExpanded = true })

local Farm = Main:CreateSection({ Name = "Auto Farm", Expanded = true })
Farm:CreateToggle({
	Name = "Auto Farm",
	Desc = "Steals the best egg on the field",
	CurrentValue = false,
	Flag = "DemoAutoFarm",
	Callback = function(value)
		print("Auto Farm", value)
	end,
})
Farm:CreateToggle({
	Name = "Auto Attack Players",
	CurrentValue = true,
	Flag = "DemoAutoAttack",
	Callback = function(value)
		print("Auto Attack", value)
	end,
})
Farm:CreateSlider({
	Name = "Min Gen",
	Range = { 0, 1000 },
	Increment = 10,
	Suffix = "/s",
	CurrentValue = 100,
	Flag = "DemoMinGen",
	Callback = function(value)
		print("Min Gen", value)
	end,
})
Farm:CreateDropdown({
	Name = "Delivery Method",
	Options = { "Method 1", "Method 2", "Line Drop" },
	CurrentOption = "Method 1",
	Flag = "DemoDelivery",
	Callback = function(option)
		print("Delivery", option)
	end,
})

local Eggs = Main:CreateSection({ Name = "Eggs", Expanded = false })
Eggs:CreateToggle({ Name = "Auto Plant", CurrentValue = false, Flag = "DemoPlant", Callback = print })
Eggs:CreateToggle({ Name = "Auto Hatch", CurrentValue = false, Flag = "DemoHatch", Callback = print })
Eggs:CreateDropdown({
	Name = "Skip Rarities",
	Options = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	MultipleOptions = true,
	CurrentOption = { "Common" },
	Flag = "DemoSkip",
	Callback = function(options)
		print("Skip", table.concat(options, ", "))
	end,
})
Eggs:CreateButton({
	Name = "Sell Inventory",
	Desc = "Rebirth-style button",
	Icon = "coins",
	Callback = function()
		notify("Sell", "Sold everything (demo)")
	end,
})

-- Player: inputs, keybinds, colors, stepper and progress.
local Player = Window:CreateTab({ Name = "Player", Desc = "Movement and visuals", Icon = "user" })

local Movement = Player:CreateSection({ Name = "Movement" })
Movement:CreateSlider({
	Name = "Walk Speed",
	Range = { 16, 200 },
	Increment = 1,
	CurrentValue = 16,
	Flag = "DemoSpeed",
	Callback = function(value)
		print("Speed", value)
	end,
})
Movement:CreateStepper({ Name = "Jump Count", Range = { 1, 10 }, Increment = 1, CurrentValue = 2, Flag = "DemoJumps", Callback = print })
Movement:CreateKeybind({
	Name = "Fly",
	CurrentKeybind = "F",
	Flag = "DemoFly",
	Callback = function(key)
		print("Fly key", key.Name)
	end,
})

local Visuals = Player:CreateSection({ Name = "Visuals" })
Visuals:CreateToggle({ Name = "Egg ESP", CurrentValue = true, Flag = "DemoEsp", Callback = print })
Visuals:CreateColorPicker({
	Name = "ESP Color",
	Color = Color3.fromRGB(58, 255, 55),
	Flag = "DemoEspColor",
	Callback = function(color)
		print("ESP color", color)
	end,
})
Visuals:CreateInput({
	Name = "Player Name",
	PlaceholderText = "Type a name",
	Flag = "DemoName",
	Callback = function(text)
		print("Name", text)
	end,
})
Visuals:CreateProgress({ Name = "Index Progress", CurrentValue = 0.65 })

-- Popups: notifications and dialogs.
local Popups = Window:CreateTab({ Name = "Popups", Desc = "Notifications and dialogs", Icon = "bell" })
local Alerts = Popups:CreateSection({ Name = "Alerts" })
Alerts:CreateButton({
	Name = "Notification",
	Callback = function()
		notify("Claude UI", "This is a notification")
	end,
})
Alerts:CreateButton({
	Name = "Confirm",
	Style = "Primary",
	Callback = function()
		Library:Confirm({
			Title = "Are you sure?",
			Content = "This is a confirm dialog.",
			ConfirmText = "Yes",
			CancelText = "No",
			Callback = function()
				notify("Confirm", "Confirmed")
			end,
		})
	end,
})
Alerts:CreateText({ Name = "About", Text = "Mix of the Ghost Pepper UI and the Chilli Library look." })

-- Right side tabs (Chilli's Side = "Right") gather under MORE at the end of the sidebar.
local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings", Side = "Right" })
local Interface = Settings:CreateSection({ Name = "Interface" })
Interface:CreateKeybind({
	Name = "Toggle UI",
	CurrentKeybind = "RightControl",
	OnChanged = function(key)
		Window:SetKeybind(key)
	end,
})
Interface:CreateConfigManager({ Name = "Configs" })
Interface:CreateButton({
	Name = "Unload",
	Icon = "power",
	Callback = function()
		Library:Confirm({
			Title = "Unload?",
			ConfirmText = "Unload",
			Callback = function()
				Window:Destroy()
			end,
		})
	end,
})

local Credits = Window:CreateTab({ Name = "Credits", Icon = "heart", Side = "Right" })
Credits:CreateSection({ Name = "Made with" }):CreateParagraph({
	Title = "Bloom Hub",
	Content = "Bloom UI structure with the Chilli Library style: shiny titles, Rebirth buttons, green toggles.",
})

-- HUD templates with fake data (the real hub fills these from the game).
local Status = Library:CreateStatus({ Title = "Bloom Hub" })
local Steal = Library:CreateStealPanel({
	Title = "Steal",
	Side = "Right",
	OnSteal = function(id)
		notify("Steal", "Going for " .. tostring(id))
	end,
	OnQueue = function(id)
		notify("Queue", "Queued " .. tostring(id))
	end,
})
Status:SetStat("STOLEN", 0, { Color3.fromRGB(255, 132, 123), Color3.fromRGB(239, 28, 28) })

local rarityColors = {
	Legendary = Color3.fromRGB(255, 196, 60),
	Mythic = Color3.fromRGB(200, 120, 255),
	Epic = Color3.fromRGB(110, 200, 255),
	Rare = Color3.fromRGB(77, 255, 122),
}
local eggs = {
	{ Id = "egg1", Name = "Astral Jackalope", Rarity = "Mythic", Value = "$30M/s", Info = "8 kg", State = "In Forest", Featured = true },
	{ Id = "egg2", Name = "Golden Phoenix", Rarity = "Legendary", Value = "$4.2M/s", Info = "12 kg", State = "Carried by Bob", StateColor = Color3.fromRGB(255, 150, 60) },
	{ Id = "egg3", Name = "Frost Wolf", Rarity = "Epic", Value = "$850K/s", Info = "6 kg", State = "In Jungle", Queued = 1 },
	{ Id = "egg4", Name = "Moss Turtle", Rarity = "Rare", Value = "$120K/s", Info = "3 kg", State = "Dropped" },
}
for _, egg in eggs do
	egg.RarityColor = rarityColors[egg.Rarity]
	egg.Icon = "rbxassetid://72213445673978"
end
Steal:SetItems(eggs)

-- Cycle the status through a steal so the steps, bar and pills animate.
task.spawn(function()
	local stolen = 0
	local phases = { "Running to", "Taking", "Delivering" }
	while Status.Gui.Parent do
		for phase = 1, 3 do
			Status:Set({
				Text = phases[phase] .. " Astral Jackalope",
				State = "active",
				Tag = "AUTO FARM",
				Icon = "rbxassetid://72213445673978",
				Chips = {
					{ Text = "MYTHIC", Colors = { Color3.fromRGB(220, 160, 255), Color3.fromRGB(150, 60, 220) } },
					{ Text = "$30M/s" },
					{ Text = "8 kg" },
				},
				Steps = { Names = { "Run", "Take", "Deliver" }, Current = phase },
			})
			task.wait(2)
		end
		stolen += 1
		Status:SetStat("STOLEN", stolen)
		Status:Set({
			Text = "Wisp: Steal 20 Enchanted Forest eggs",
			Detail = "Mission 1/3",
			State = "waiting",
			Tag = "WISP",
			Bar = { Fraction = (stolen % 20) / 20, Text = ("%d/20 eggs  -  %d left"):format(stolen % 20, 20 - stolen % 20) },
		})
		task.wait(3)
	end
end)

Window:LoadConfig()
