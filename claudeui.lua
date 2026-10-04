local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Library = {}

Library.Flags = {}
Library.Windows = {}

local function normalize(source, map)
    local opts = {}
    if type(source) == "string" then
        opts.Name = source
    elseif type(source) == "table" then
        for key, value in pairs(source) do
            opts[key] = value
        end
    end
    for from, to in pairs(map or {}) do
        if opts[to] == nil and opts[from] ~= nil then
            opts[to] = opts[from]
        end
    end
    if opts.Range then
        opts.Min = opts.Min or opts.Range[1]
        opts.Max = opts.Max or opts.Range[2]
    end
    return opts
end

local function finishElement(tab, opts, element, frame, kind)
    element._type = kind
    element._frame = frame
    element._listeners = element._listeners or {}
    local window = tab and tab.Window
    if opts.Flag then
        Library.Flags[opts.Flag] = element
        if window then
            local callback = opts.Callback
            opts.Callback = function(...)
                if type(callback) == "function" then
                    callback(...)
                end
                window:_autoSave()
            end
        end
    end
    function element:Destroy()
        if element._destroyed then
            return
        end
        element._destroyed = true
        for _, disconnect in ipairs(element._listeners) do
            disconnect()
        end
        element._listeners = {}
        if opts.Flag and Library.Flags[opts.Flag] == element then
            Library.Flags[opts.Flag] = nil
        end
        if window then
            window._controlsDirty = true
        end
        if frame then
            frame:Destroy()
        end
    end
    return element
end

-- Bloom: deep plum surfaces, a blossom pink accent with a lilac partner. Outline is the near-black ink every
-- heading, card and button is drawn with.
Library.Theme = {
    Background = Color3.fromRGB(17, 13, 22),
    Surface = Color3.fromRGB(23, 18, 29),
    Surface2 = Color3.fromRGB(30, 23, 38),
    Surface3 = Color3.fromRGB(46, 35, 57),
    Stroke = Color3.fromRGB(70, 50, 84),
    StrokeHover = Color3.fromRGB(255, 110, 180),
    Accent = Color3.fromRGB(255, 99, 170),
    Accent2 = Color3.fromRGB(178, 120, 255),
    AccentDark = Color3.fromRGB(42, 12, 30),
    Text = Color3.fromRGB(250, 242, 248),
    Muted = Color3.fromRGB(180, 158, 184),
    Outline = Color3.fromRGB(14, 6, 12),
    Warning = Color3.fromRGB(255, 196, 100),
    Success = Color3.fromRGB(120, 230, 160),
    Error = Color3.fromRGB(255, 110, 130),
}

Library.Assets = {
    Shadow = "rbxassetid://6014261993",
    Glow = "rbxassetid://8992230677",
    Logo = "rbxassetid://102764279440635",
}

local LUCIDE_URL = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"
local lucideSet = nil

local function loadLucide()
    if lucideSet ~= nil then
        return lucideSet
    end
    local ok, result = pcall(function()
        local source = game:HttpGet(LUCIDE_URL)
        return loadstring(source)()
    end)
    if ok and type(result) == "table" then
        lucideSet = result
    else
        lucideSet = false
        warn("[Bloom UI] lucide icons unavailable: " .. tostring(result))
    end
    return lucideSet
end

local FONT_PRESETS = {
    ValleySans = {
        Regular = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Regular.ttf",
        Medium = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Medium.ttf",
        SemiBold = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-SemiBold.ttf",
    },
}

local FONT_WEIGHTS = {
    Regular = { 400, Enum.FontWeight.Regular },
    Medium = { 500, Enum.FontWeight.Medium },
    SemiBold = { 600, Enum.FontWeight.SemiBold },
    Bold = { 700, Enum.FontWeight.Bold },
}

function Library:LoadFont(opts)
    opts = normalize(opts, {})
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[Bloom UI] custom fonts need writefile, isfile and getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    local weights = opts.Weights or FONT_PRESETS[name]
    if type(weights) ~= "table" then
        warn("[Bloom UI] no font weights for " .. name)
        return false
    end
    local folder = opts.Folder or "BloomFonts"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
            makefolder(folder)
        end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then
                ok = pcall(function()
                    writefile(path, game:HttpGet(url))
                end)
            end
            if ok then
                table.insert(faces, { name = weightName, weight = info[1], style = "normal", assetId = getcustomasset(path) })
            else
                warn("[Bloom UI] could not download " .. weightName .. " weight of " .. name)
            end
        end
    end
    if #faces == 0 then
        return false
    end
    local familyPath = folder .. "/" .. name .. ".json"
    local okWrite = pcall(function()
        writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces }))
    end)
    if not okWrite then
        return false
    end
    local family = getcustomasset(familyPath)
    local function face(weightName, fallback)
        local info = FONT_WEIGHTS[weightName]
        if info and weights[weightName] then
            return Font.new(family, info[2])
        end
        return fallback
    end
    Library.Fonts.Regular = face("Regular", Library.Fonts.Regular)
    Library.Fonts.Medium = face("Medium", face("Regular", Library.Fonts.Medium))
    Library.Fonts.Bold = face("SemiBold", face("Bold", Library.Fonts.Bold))
    return true
end

function Library:PreloadIcons()
    return loadLucide() ~= false
end

local function resolveIcon(icon)
    if typeof(icon) == "table" then
        return icon.Image, icon.RectOffset, icon.RectSize
    end
    if type(icon) ~= "string" then
        return nil
    end
    if icon:find("^rbxassetid://") or icon:find("^rbxasset://") or icon:find("^http") then
        return icon
    end
    local name = icon:gsub("^lucide:", "")
    local set = loadLucide()
    if not set then
        return nil
    end
    local entry = (set.Icons and set.Icons[name]) or set[name]
    if type(entry) == "table" then
        local image = entry.Image
        if type(image) == "number" then
            image = "rbxassetid://" .. tostring(image)
        end
        local sheet = (set.Spritesheets and set.Spritesheets[tostring(image)]) or image
        return sheet, entry.ImageRectPosition, entry.ImageRectSize
    elseif type(entry) == "string" then
        return entry
    end
    warn("[Bloom UI] unknown lucide icon: " .. name)
    return nil
end

local BUTTON_HINT_ICON = "chevron-right"

local FONT_FAMILY = "rbxasset://fonts/families/BuilderSans.json"
-- Heading face: Gotham SSm ExtraBold for titles, section heads and pills; body text stays Builder Sans.
local TITLE_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
Library.Fonts = {
    Regular = Font.new(FONT_FAMILY, Enum.FontWeight.Regular),
    Medium = Font.new(FONT_FAMILY, Enum.FontWeight.Medium),
    Bold = Font.new(FONT_FAMILY, Enum.FontWeight.SemiBold),
    Title = Font.new(TITLE_FAMILY, Enum.FontWeight.ExtraBold),
    Heavy = Font.new(TITLE_FAMILY, Enum.FontWeight.Bold),
}

local Theme = Library.Theme
local Assets = Library.Assets
local Fonts = Library.Fonts

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Library.Touch = TOUCH

local SIDEBAR_WIDTH = 156
local HEADER_HEIGHT = 72
local CARD_HEIGHT = TOUCH and 54 or 48
local CARD_HEIGHT_DESC = TOUCH and 70 or 64
local DROPDOWN_OPTION_HEIGHT = TOUCH and 40 or 34
local CHIP_HEIGHT = TOUCH and 34 or 28

local tweenInfoCache = {}

local function tween(object, props, duration, style, direction)
    duration = duration or 0.2
    if duration <= 0 then
        for key, value in pairs(props) do
            object[key] = value
        end
        return nil
    end
    style = style or Enum.EasingStyle.Quart
    direction = direction or Enum.EasingDirection.Out
    local key = duration .. style.Name .. direction.Name
    local info = tweenInfoCache[key]
    if not info then
        info = TweenInfo.new(duration, style, direction)
        tweenInfoCache[key] = info
    end
    local t = TweenService:Create(object, info, props)
    t:Play()
    return t
end

local function create(className, props, children)
    local inst = Instance.new(className)
    for key, value in pairs(props) do
        if key ~= "Parent" then
            inst[key] = value
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end

    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = radius or UDim.new(0, 8),
        Parent = parent,
    })
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent,
    })
end

local function label(props)
    local defaults = {
        BackgroundTransparency = 1,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for key, value in pairs(props) do
        defaults[key] = value
    end
    local text = create("TextLabel", defaults)
    -- Headings in Gotham SSm ExtraBold carry an ink outline so they read over anything; body text stays plain.
    if defaults.FontFace == Fonts.Title then
        create("UIStroke", {
            Name = "Outline",
            ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
            Color = Theme.Outline,
            Thickness = 1.2,
            LineJoinMode = Enum.LineJoinMode.Round,
            Parent = text,
        })
    end
    return text
end

-- Bloom styling shared by the window and the HUDs: button gradients, the accent, the shiny heading recipe.
local Style = {
    -- Button face: blush highlight at the top running into blossom pink, a deeper rose lip under it.
    ButtonFace = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 208, 232)),
        ColorSequenceKeypoint.new(0.06, Color3.fromRGB(255, 140, 198)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 58, 140)),
    }),
    ButtonShine = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 208, 232)),
        ColorSequenceKeypoint.new(0.016, Color3.fromRGB(255, 140, 198)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 58, 140)),
    }),
    ButtonBase = Color3.fromRGB(150, 24, 90),
    -- Accent for "on" states and chevrons.
    Accent = ColorSequence.new(Theme.Accent, Theme.Accent2),
    AccentColor = Theme.Accent,
    -- Shiny heading text: white with a soft break, a plum outline.
    ShinyText = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.486, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.519, Color3.fromRGB(236, 224, 234)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(246, 236, 244)),
    }),
    ShinyStroke = ColorSequence.new(Color3.fromRGB(86, 16, 62), Color3.fromRGB(46, 8, 34)),
    Plate = Color3.fromRGB(8, 4, 10),
}
Library.Style = Style

-- Ink outline that frames cards, buttons and panels (rest colour Theme.Outline).
local function outlineStroke(parent, thickness, mode)
    local outline = create("UIStroke", {
        Name = "Outline",
        ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
        Color = Theme.Outline,
        LineJoinMode = Enum.LineJoinMode.Round,
        Thickness = thickness or 2,
        Parent = parent,
    })
    return outline
end

local function verticalGradient(parent, color, name)
    return create("UIGradient", { Name = name or "Gradient", Color = color, Rotation = 90, Parent = parent })
end

-- Shiny heading: white vertical gradient on the text, a plum gradient on its outline.
local function shinyText(text)
    text.FontFace = Fonts.Title
    text.TextColor3 = Color3.new(1, 1, 1)
    local outline = text:FindFirstChild("Outline") or create("UIStroke", {
        Name = "Outline",
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        LineJoinMode = Enum.LineJoinMode.Round,
        Parent = text,
    })
    outline.Color = Color3.new(1, 1, 1)
    outline.Thickness = 1.6
    if not outline:FindFirstChild("StrokeStyleGradient") then
        verticalGradient(outline, Style.ShinyStroke, "StrokeStyleGradient")
    end
    if not text:FindFirstChild("TextStyleGradient") then
        verticalGradient(text, Style.ShinyText, "TextStyleGradient")
    end
    return text
end

-- Grows a little on hover, squeezes on press.
local function scaleFeedback(button, hoverScale, pressScale)
    local scale = button:FindFirstChild("InteractionScale") or create("UIScale", { Name = "InteractionScale", Parent = button })
    local hovered = false
    hoverScale, pressScale = hoverScale or 1.02, pressScale or 0.97
    button.MouseEnter:Connect(function()
        hovered = true
        tween(scale, { Scale = hoverScale }, 0.1, Enum.EasingStyle.Quad)
    end)
    button.MouseLeave:Connect(function()
        hovered = false
        tween(scale, { Scale = 1 }, 0.1, Enum.EasingStyle.Quad)
    end)
    button.MouseButton1Down:Connect(function()
        tween(scale, { Scale = pressScale }, 0.055, Enum.EasingStyle.Quad)
    end)
    button.MouseButton1Up:Connect(function()
        tween(scale, { Scale = hovered and hoverScale or 1 }, 0.08, Enum.EasingStyle.Quad)
    end)
    return scale
end

-- Bloom button face inside `parent`: a rose lip, the pink gradient face over it, an inner shine. Returns base, face.
local function buttonFace(parent, zIndex)
    zIndex = zIndex or 1
    local base = create("Frame", {
        Name = "ButtonBase",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Style.ButtonBase,
        BorderSizePixel = 0,
        ZIndex = zIndex,
        Parent = parent,
    })
    corner(base)
    outlineStroke(base, 2)
    local face = create("Frame", {
        Name = "ButtonFace",
        Size = UDim2.new(1, 0, 1, -4),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = zIndex,
        Parent = base,
    })
    corner(face)
    verticalGradient(face, Style.ButtonFace, "FaceGradient")
    local highlight = create("Frame", {
        Name = "ButtonShine",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -6, 1, -6),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = zIndex,
        Parent = face,
    })
    corner(highlight, UDim.new(0, 6))
    verticalGradient(highlight, Style.ButtonShine, "FaceGradient")
    return base, face
end

local function glow(parent, size, position, transparency, rotation)
    local image = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Color3.fromRGB(226, 218, 230),
        ImageTransparency = transparency,
        ZIndex = 0,
        Parent = parent,
    })
    create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Theme.Accent),
        Rotation = rotation or 90,
        Parent = image,
    })
    return image
end

local function edgeHighlight(parent)
    return create("Frame", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.93,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = parent,
    })
end

local function applyIcon(imageLabel, icon)
    local image, rectOffset, rectSize = resolveIcon(icon)
    if not image then
        return
    end
    imageLabel.Image = image
    imageLabel.ImageRectOffset = rectOffset or Vector2.zero
    imageLabel.ImageRectSize = rectSize or Vector2.zero
end

local function defaultParent()
    local hidden
    pcall(function()
        if typeof(gethui) == "function" then
            hidden = gethui()
        end
    end)
    if typeof(hidden) == "Instance" then
        return hidden
    end
    local core
    pcall(function()
        core = game:GetService("CoreGui")
        local probe = Instance.new("Folder")
        probe.Parent = core
        probe:Destroy()
    end)
    if core then
        return core
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local insetFrame, insetValue = nil, Vector2.zero
local function pointerPosition()
    local frame = time()
    if insetFrame ~= frame then
        insetFrame = frame
        insetValue = GuiService:GetGuiInset()
    end
    return UserInputService:GetMouseLocation() - insetValue
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function glowIcon(parent, icon, color, position)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = position,
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local image = create("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ImageColor3 = color,
        ScaleType = Enum.ScaleType.Fit,
        Parent = holder,
    })
    applyIcon(image, icon)
    return holder, image
end

local function arrowIndicator(parent, anchorX, offsetX)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(anchorX, 0.5),
        Position = UDim2.new(anchorX, offsetX, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local indicator = {}
    local image = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ScaleType = Enum.ScaleType.Fit,
        Parent = holder,
    })
    applyIcon(image, "chevron-down")
    if image.Image ~= "" then
        function indicator:Set(open)
            tween(image, {
                Rotation = open and 180 or 0,
                ImageColor3 = open and Theme.Accent or Theme.Muted,
            }, 0.3, Enum.EasingStyle.Quint)
        end
        return indicator
    end
    image:Destroy()
    local function glyph(rotation, transparency)
        return label({
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(18, 18),
            Text = "›",
            TextSize = 22,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextColor3 = Theme.Muted,
            TextTransparency = transparency,
            Rotation = rotation,
            Parent = holder,
        })
    end
    local down = glyph(90, 0)
    local up = glyph(270, 1)
    function indicator:Set(open)
        tween(down, { TextTransparency = open and 1 or 0 }, 0.2)
        tween(up, { TextTransparency = open and 0 or 1, TextColor3 = open and Theme.Accent or Theme.Muted }, 0.2)
    end
    return indicator
end

local ripplePool = {}

local function ripple(button)
    local mouse = pointerPosition()
    local diameter = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.2
    local circle = table.remove(ripplePool)
    if not circle then
        circle = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
        })
        corner(circle, UDim.new(1, 0))
    end
    circle.Position = UDim2.fromOffset(mouse.X - button.AbsolutePosition.X, mouse.Y - button.AbsolutePosition.Y)
    circle.Size = UDim2.fromOffset(0, 0)
    circle.BackgroundTransparency = 0.82
    circle.ZIndex = button.ZIndex + 1
    circle.Parent = button
    tween(circle, { Size = UDim2.fromOffset(diameter, diameter), BackgroundTransparency = 1 }, 0.55)
    task.delay(0.55, function()
        circle.Parent = nil
        if #ripplePool < 4 then
            table.insert(ripplePool, circle)
        else
            circle:Destroy()
        end
    end)
end

local function flashStroke(strokeObject)
    if not strokeObject then
        return
    end
    tween(strokeObject, { Color = Theme.Accent, Transparency = 0.2 }, 0.08)
    task.delay(0.12, function()
        tween(strokeObject, { Color = strokeObject:GetAttribute("RestColor") or Theme.Stroke, Transparency = 0 }, 0.35)
    end)
end

-- Rest colour comes from the stroke itself (cards rest on their ink outline, the rest on Theme.Stroke).
local function hoverStroke(target, strokeObject)
    target.MouseEnter:Connect(function()
        tween(strokeObject, { Color = Theme.StrokeHover }, 0.12)
    end)
    target.MouseLeave:Connect(function()
        tween(strokeObject, { Color = strokeObject:GetAttribute("RestColor") or Theme.Stroke }, 0.25)
    end)
end

local KEY_NAMES = {
    [Enum.KeyCode.LeftControl] = "LCtrl",
    [Enum.KeyCode.RightControl] = "RCtrl",
    [Enum.KeyCode.LeftShift] = "LShift",
    [Enum.KeyCode.RightShift] = "RShift",
    [Enum.KeyCode.LeftAlt] = "LAlt",
    [Enum.KeyCode.RightAlt] = "RAlt",
    [Enum.KeyCode.Return] = "Enter",
    [Enum.KeyCode.Escape] = "Esc",
    [Enum.KeyCode.Backspace] = "Backspace",
}

local function keyName(keyCode)
    if keyCode == nil then
        return "None"
    end
    return KEY_NAMES[keyCode] or keyCode.Name
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[Bloom UI] callback error: " .. tostring(err))
    end
end

local function numberFormat(min, max, step)
    local decimals = 0
    local text = tostring(step)
    local dot = text:find("%.")
    if dot then
        decimals = #text - dot
    end
    local pattern = "%." .. decimals .. "f"
    return {
        snap = function(value)
            value = math.floor(value / step + 0.5) * step
            return math.clamp(value, min, max)
        end,
        format = function(value)
            return string.format(pattern, value)
        end,
    }
end

local function card(tab, className, height, opts)
    local props = {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = tab:_nextOrder(),
        Parent = tab.List,
    }
    if className == "TextButton" then
        props.AutoButtonColor = false
        props.Text = ""
    end
    local frame = create(className, props)
    frame:SetAttribute("NoDrag", true)
    corner(frame)
    -- Row plate (the theme's surface darkened, a thick ink outline); the outline is also
    -- the hover / flash ring and rests black again afterwards.
    frame.BackgroundColor3 = Theme.Surface2:Lerp(Style.Plate, 0.35)
    frame.BackgroundTransparency = 0.15
    local frameStroke = outlineStroke(frame, 2.5)
    frameStroke:SetAttribute("RestColor", Theme.Outline)
    -- Soft top-to-bottom gloss on every card (named, so a card with its own gradient can drop it).
    create("UIGradient", {
        Name = "Gloss",
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(176, 170, 178)),
        Parent = frame,
    })
    if className == "TextButton" then
        scaleFeedback(frame, 1.01, 0.985)
    end
    return frame, frameStroke
end

local function titleDesc(parent, name, desc, rightReserve)
    local title, descLabel
    if desc then
        local top = (CARD_HEIGHT_DESC - 38) / 2
        title = label({
            Position = UDim2.fromOffset(14, top),
            Size = UDim2.new(1, -(14 + rightReserve), 0, 18),
            Text = name,
            Parent = parent,
        })
        descLabel = label({
            Position = UDim2.fromOffset(14, top + 20),
            Size = UDim2.new(1, -(14 + rightReserve), 0, 17),
            Text = desc,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = parent,
        })
    else
        title = label({
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -(14 + rightReserve), 1, 0),
            Text = name,
            Parent = parent,
        })
    end
    return title, descLabel
end

local function beginElement(tab, opts, map, className, rightReserve, fallbackName)
    opts = normalize(opts, map)
    local height = opts.Desc and CARD_HEIGHT_DESC or CARD_HEIGHT
    local frame, frameStroke = card(tab, className or "Frame", height, opts)
    hoverStroke(frame, frameStroke)
    local title, descLabel
    if rightReserve then
        title, descLabel = titleDesc(frame, opts.Name or fallbackName, opts.Desc, rightReserve)
    end
    return opts, frame, frameStroke, height, title, descLabel
end

local function reserveRight(title, descLabel, width)
    if title then
        title.Size = UDim2.new(1, -(14 + width), title.Size.Y.Scale, title.Size.Y.Offset)
    end
    if descLabel then
        descLabel.Size = UDim2.new(1, -(14 + width), 0, descLabel.Size.Y.Offset)
    end
end

local Tab = {}
Tab.__index = Tab

function Tab:_nextOrder()
    self._order = self._order + 1
    return self._order
end

function Tab:Section(text)
    if type(text) == "table" then
        text = text.Name or text.Title or ""
    end
    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List,
    })
    -- Accent pill, the title, then a rule that fades out to the right.
    local pill = create("Frame", {
        Position = UDim2.fromOffset(2, 10),
        Size = UDim2.fromOffset(3, 12),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = holder,
    })
    corner(pill, UDim.new(1, 0))
    local text_ = label({
        Position = UDim2.fromOffset(11, 8),
        Size = UDim2.new(0, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = string.upper(text),
        TextSize = 12,
        TextColor3 = Theme.Text:Lerp(Theme.Muted, 0.35),
        TextTruncate = Enum.TextTruncate.None,
        Parent = holder,
    })
    local rule = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0, 16),
        Size = UDim2.new(1, -21, 0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = holder,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.55),
            NumberSequenceKeypoint.new(0.35, 0.85),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = rule,
    })
    text_:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        rule.Size = UDim2.new(1, -(text_.AbsoluteSize.X + 23), 0, 1)
    end)
    task.defer(function()
        rule.Size = UDim2.new(1, -(text_.AbsoluteSize.X + 23), 0, 1)
    end)
    return finishElement(self, {}, {
        Set = function(_, value)
            text_.Text = string.upper(value)
        end,
    }, holder, "Section")
end

function Tab:Divider()
    local line = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List,
    })
    return finishElement(self, {}, {}, line, "Divider")
end

function Tab:Label(opts)
    opts = normalize(opts, { Name = "Text", Title = "Text" })
    local text_ = label({
        Size = UDim2.new(1, 0, 0, 18),
        Text = opts.Text or "",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = opts.Color or Theme.Muted,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List,
    })
    padding(text_, 2)
    local handle = {
        Set = function(_, value)
            text_.Text = tostring(value)
        end,
        Get = function()
            return text_.Text
        end,
    }
    if type(opts.Update) == "function" then
        local rate = math.max(tonumber(opts.UpdateRate) or 1, 0.05)
        local running = true
        handle._listeners = handle._listeners or {}
        table.insert(handle._listeners, function()
            running = false
        end)
        task.spawn(function()
            while running and text_.Parent do
                local ok, value = pcall(opts.Update)
                if ok and value ~= nil then
                    text_.Text = tostring(value)
                elseif not ok then
                    warn("[Bloom UI] label update error: " .. tostring(value))
                end
                task.wait(rate)
            end
        end)
        function handle:SetUpdateRate(seconds)
            rate = math.max(tonumber(seconds) or rate, 0.05)
        end
    end
    return finishElement(self, opts, handle, text_, "Label")
end

function Tab:Paragraph(opts)
    opts = normalize(opts, { Title = "Name" })
    local frame = card(self, "Frame", 0, opts)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    padding(frame, 14, 14, 11, 12)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = frame,
    })
    label({
        Size = UDim2.new(1, 0, 0, 14),
        Text = opts.Name or "",
        LayoutOrder = 1,
        Parent = frame,
    })
    local content = label({
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = opts.Content or "",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = frame,
    })
    return finishElement(self, opts, {
        Set = function(_, value)
            content.Text = value
        end,
    }, frame, "Paragraph")
end

function Tab:Button(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc" })
    local primary = opts.Style == "Primary"
    local height = opts.Desc and CARD_HEIGHT_DESC or CARD_HEIGHT
    local button, buttonStroke = card(self, "TextButton", height, opts)
    button.ClipsDescendants = true

    -- Bloom button: the pink gradient face carries the look, the card plate goes see-through. Primary
    -- buttons get the brighter inner highlight on hover.
    button.BackgroundTransparency = 1
    buttonStroke.Transparency = 1
    local gloss = button:FindFirstChild("Gloss")
    if gloss then
        gloss:Destroy()
    end
    local base, face = buttonFace(button, 0)
    button.MouseEnter:Connect(function()
        tween(face, { BackgroundTransparency = 0 }, 0.12)
        tween(base, { BackgroundColor3 = primary and Style.ButtonBase:Lerp(Color3.new(1, 1, 1), 0.15) or Style.ButtonBase }, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(base, { BackgroundColor3 = Style.ButtonBase }, 0.25)
    end)

    local textColor = Color3.new(1, 1, 1)
    local iconOffset = 0
    if opts.Icon then
        glowIcon(button, opts.Icon, textColor, UDim2.new(0, 14, 0.5, 0))
        iconOffset = 26
    end
    local title = titleDesc(button, opts.Name or "Button", opts.Desc, 30)
    for _, child in ipairs(button:GetChildren()) do
        if child:IsA("TextLabel") then
            child.ZIndex = 3
            child.TextColor3 = textColor
            if iconOffset > 0 then
                child.Position = child.Position + UDim2.fromOffset(iconOffset, 0)
                child.Size = child.Size - UDim2.fromOffset(iconOffset, 0)
            end
            if child.FontFace == Fonts.Title then
                shinyText(child)
            end
        end
    end

    glowIcon(button, BUTTON_HINT_ICON, textColor, UDim2.new(1, -30, 0.5, 0))

    button.MouseButton1Click:Connect(function()
        ripple(button)
        safeCall(opts.Callback)
    end)

    return finishElement(self, opts, {
        SetText = function(_, value)
            title.Text = value
        end,
    }, button, "Button")
end

function Tab:Toggle(opts)
    local button, buttonStroke
    opts, button, buttonStroke = beginElement(self, opts, { Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default" }, "TextButton", 56, "Toggle")

    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = TOUCH and UDim2.fromOffset(44, 24) or UDim2.fromOffset(36, 20),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = button,
    })
    corner(pill, UDim.new(1, 0))
    outlineStroke(pill, 2)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = TOUCH and UDim2.fromOffset(18, 18) or UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.Muted,
        BorderSizePixel = 0,
        Parent = pill,
    })
    corner(knob, UDim.new(1, 0))
    local pillGlow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 24, 1, 24),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Style.AccentColor,
        ImageTransparency = 1,
        ZIndex = 0,
        Parent = pill,
    })
    outlineStroke(knob, 1.5)

    -- Gloss on the switch.
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 190, 196)),
        Parent = pill,
    })

    local self_ = { Value = opts.Default == true }

    local function render(animate)
        local on = self_.Value
        local duration = animate and 0.25 or 0
        -- Accent pink for "on"; the knob goes white.
        tween(pill, { BackgroundColor3 = on and Style.AccentColor or Theme.Surface3 }, duration)
        tween(pillGlow, { ImageTransparency = on and 0.75 or 1 }, duration)
        local knobSize = TOUCH and 18 or 14
        tween(knob, {
            Position = on and UDim2.new(0, (TOUCH and 44 or 36) - 3 - knobSize, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = on and Color3.new(1, 1, 1) or Theme.Muted,
        }, duration, Enum.EasingStyle.Back)
        if animate then
            tween(knob, { Size = UDim2.fromOffset(knobSize + 4, knobSize - 2) }, 0.08)
            task.delay(0.08, function()
                tween(knob, { Size = UDim2.fromOffset(knobSize, knobSize) }, 0.2, Enum.EasingStyle.Back)
            end)
        end
    end

    local fromClick = false
    function self_:Set(value, silent)
        value = value == true
        if value == self_.Value then
            return
        end
        self_.Value = value
        render(true)
        if not fromClick then
            flashStroke(buttonStroke)
        end
        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function self_:Get()
        return self_.Value
    end

    render(false)
    button.MouseButton1Click:Connect(function()
        fromClick = true
        self_:Set(not self_.Value)
        fromClick = false
    end)

    local handle = finishElement(self, opts, self_, button, "Toggle")
    if self_.Value then
        safeCall(opts.Callback, true)
    end
    return handle
end

function Tab:Slider(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default", Increment = "Step" })
    local min = opts.Min or 0
    local max = opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local numbers = numberFormat(min, max, step)

    local frame, frameStroke = card(self, "Frame", CARD_HEIGHT_DESC, opts)
    hoverStroke(frame, frameStroke)

    label({
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.new(1, -120, 0, 18),
        Text = opts.Name or "Slider",
        Parent = frame,
    })

    local valueChip = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 9),
        Size = UDim2.fromOffset(40, 24),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(valueChip, UDim.new(0, 6))
    local chipStroke = stroke(valueChip)
    local valueLabel = label({
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = valueChip,
    })
    local valueBox = create("TextBox", {
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Visible = false,
        Parent = valueChip,
    })
    create("UISizeConstraint", { MinSize = Vector2.new(14, 0), Parent = valueBox })
    local suffixLabel = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = suffix,
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        Parent = valueChip,
    })
    local chipButton = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
        Parent = valueChip,
    })
    local editing = false
    local function fitChip(instant)
        local width
        if editing then
            width = 9 + valueBox.AbsoluteSize.X / (self.Window.Scale.Scale) + suffixLabel.TextBounds.X + 9
            suffixLabel.Position = UDim2.fromOffset(9 + valueBox.AbsoluteSize.X / (self.Window.Scale.Scale), 0)
        else
            width = valueLabel.TextBounds.X + 18
        end
        width = math.max(width, 36)
        if instant then
            valueChip.Size = UDim2.fromOffset(width, 24)
        else
            tween(valueChip, { Size = UDim2.fromOffset(width, 24) }, 0.2)
        end
    end
    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        if not editing then
            fitChip(false)
        end
    end)
    valueBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if editing then
            fitChip(false)
        end
    end)

    local track = create("Frame", {
        Position = UDim2.new(0, 14, 0, CARD_HEIGHT_DESC - 18),
        Size = UDim2.new(1, -28, 0, 5),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(track, UDim.new(1, 0))
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, UDim.new(1, 0))

    local knobGlow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.85,
        ZIndex = 2,
        Parent = track,
    })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = track,
    })
    corner(knob, UDim.new(1, 0))

    local hit = create("TextButton", {
        Position = UDim2.new(0, 8, 0, CARD_HEIGHT_DESC - (TOUCH and 37 or 31)),
        Size = UDim2.new(1, -16, 0, TOUCH and 40 or 28),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
        Parent = frame,
    })

    local self_ = { Value = math.clamp(opts.Default or min, min, max) }
    local dragging = false
    chipButton.MouseEnter:Connect(function()
        tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
    end)
    chipButton.MouseLeave:Connect(function()
        if not valueBox:IsFocused() then
            tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        end
    end)
    chipButton.MouseButton1Click:Connect(function()
        editing = true
        valueBox.Text = numbers.format(self_.Value)
        valueLabel.Visible = false
        valueBox.Visible = true
        suffixLabel.Visible = suffix ~= ""
        chipButton.Visible = false
        tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
        valueBox:CaptureFocus()
        task.defer(fitChip, false)
    end)
    valueBox.FocusLost:Connect(function()
        local typed = tonumber(valueBox.Text)
        editing = false
        valueBox.Visible = false
        suffixLabel.Visible = false
        valueLabel.Visible = true
        chipButton.Visible = true
        tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        if typed then
            self_:Set(typed)
        end
        fitChip(false)
    end)
    hit.MouseEnter:Connect(function()
        if not dragging then
            tween(knobGlow, { ImageTransparency = 0.78, Size = UDim2.fromOffset(34, 34) }, 0.15)
        end
    end)
    hit.MouseLeave:Connect(function()
        if not dragging then
            tween(knobGlow, { ImageTransparency = 0.85, Size = UDim2.fromOffset(28, 28) }, 0.2)
        end
    end)

    local snap = numbers.snap

    local function fraction()
        return (max - min) == 0 and 0 or (self_.Value - min) / (max - min)
    end

    local function moveTo(frac, duration, style)
        style = style or Enum.EasingStyle.Linear
        tween(fill, { Size = UDim2.new(frac, 0, 1, 0) }, duration, style)
        tween(knob, { Position = UDim2.new(frac, 0, 0.5, 0) }, duration, style)
        tween(knobGlow, { Position = UDim2.new(frac, 0, 0.5, 0) }, duration, style)
    end

    local function render(duration, style)
        moveTo(fraction(), duration, style)
        valueLabel.Text = numbers.format(self_.Value) .. suffix
    end

    local function settleTo(previousFrac)
        local target = fraction()
        local width = math.max(track.AbsoluteSize.X, 1)
        local overshoot = (target >= previousFrac and 1 or -1) * (5 / width)
        moveTo(math.clamp(target + overshoot, 0, 1), 0.22, Enum.EasingStyle.Quint)
        task.delay(0.22, function()
            if not dragging then
                moveTo(fraction(), 0.18, Enum.EasingStyle.Quint)
            end
        end)
        valueLabel.Text = numbers.format(self_.Value) .. suffix
    end

    local function bounceKnob()
        tween(knob, { Size = UDim2.fromOffset(14, 12) }, 0.08)
        tween(knobGlow, { Size = UDim2.fromOffset(32, 32), ImageTransparency = 0.78 }, 0.12)
        task.delay(0.1, function()
            tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.25, Enum.EasingStyle.Quint)
            tween(knobGlow, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.25)
        end)
    end

    function self_:Set(value, silent)
        value = snap(tonumber(value) or min)
        if value == self_.Value then
            return
        end
        local previousFrac = fraction()
        self_.Value = value
        if dragging then
            render(0.05)
        else
            settleTo(previousFrac)
            bounceKnob()
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function self_:Get()
        return self_.Value
    end

    local function updateFromX(x)
        local frac = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        self_:Set(min + (max - min) * frac)
    end

    hit.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.15, Enum.EasingStyle.Back)
            tween(knobGlow, { Size = UDim2.fromOffset(44, 44), ImageTransparency = 0.7 }, 0.15)
            updateFromX(pointerPosition().X)
        end
    end)

    self.Window:_listen("Changed", function(input)
        if dragging and isMove(input) then
            updateFromX(pointerPosition().X)
        end
    end, self_)

    self.Window:_listen("Ended", function(input)
        if dragging and isPress(input) then
            dragging = false
            tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.2)
            tween(knobGlow, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.2)
        end
    end, self_)

    self_.Value = snap(self_.Value)
    render(0)
    task.defer(fitChip, true)
    return finishElement(self, opts, self_, frame, "Slider")
end

function Tab:Dropdown(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", CurrentOption = "Default", Value = "Default", MultipleOptions = "Multi", Values = "Options" })
    if opts.Multi and type(opts.Default) ~= "table" and opts.Default ~= nil then
        opts.Default = { opts.Default }
    elseif not opts.Multi and type(opts.Default) == "table" then
        opts.Default = opts.Default[1]
    end
    local multi = opts.Multi == true
    local options = opts.Options or {}
    local frame, frameStroke, height
    opts, frame, frameStroke, height = beginElement(self, opts, {}, "Frame")
    frame.ClipsDescendants = true

    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = frame,
    })
    local titleLabel, descLabel = titleDesc(header, opts.Name or "Dropdown", opts.Desc, 180)

    local chip = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(60, CHIP_HEIGHT),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = header,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    local valueLabel = label({
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = chip,
    })
    local arrow = arrowIndicator(chip, 1, -6)
    local measure = label({
        Size = UDim2.fromOffset(0, CHIP_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 13,
        Visible = false,
        Parent = chip,
    })
    local fullText = ""
    local function trimmed()
        local maxText = 190 - 10 - 34
        measure.Text = fullText
        if measure.TextBounds.X <= maxText then
            return fullText
        end
        local text = fullText
        while #text > 1 do
            text = text:sub(1, -2)
            measure.Text = text .. ".."
            if measure.TextBounds.X <= maxText then
                return text .. ".."
            end
        end
        return ".."
    end
    local function fitChip(instant)
        local width = math.clamp(valueLabel.TextBounds.X + 10 + 34, 60, 190)
        reserveRight(titleLabel, descLabel, width + 20)
        if instant then
            chip.Size = UDim2.fromOffset(width, CHIP_HEIGHT)
        else
            tween(chip, { Size = UDim2.fromOffset(width, CHIP_HEIGHT) }, 0.2)
        end
    end
    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        fitChip(false)
    end)

    local listHolder = create("Frame", {
        Position = UDim2.new(0, 10, 0, height),
        Size = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = listHolder,
    })

    local self_ = { Open = false }
    local selected = {}
    local optionButtons = {}
    local filter = ""
    local SEARCH_THRESHOLD = opts.SearchAfter or 6

    local searchHolder = create("Frame", {
        Size = UDim2.new(1, 0, 0, DROPDOWN_OPTION_HEIGHT),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 0,
        Visible = false,
        Parent = listHolder,
    })
    corner(searchHolder, UDim.new(0, 6))
    local searchStroke = stroke(searchHolder, Theme.Stroke, 1)
    local searchBox = create("TextBox", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextTransparency = 1,
        Parent = searchHolder,
    })

    local function matches(option)
        return filter == "" or string.find(string.lower(tostring(option)), filter, 1, true) ~= nil
    end

    if multi then
        for _, value in ipairs(opts.Default or {}) do
            selected[value] = true
        end
    elseif opts.Default ~= nil then
        selected[opts.Default] = true
    end

    local function currentValue()
        if multi then
            local list = {}
            for _, option in ipairs(options) do
                if selected[option] then
                    table.insert(list, option)
                end
            end
            return list
        end
        for _, option in ipairs(options) do
            if selected[option] then
                return option
            end
        end
        return nil
    end

    local function renderValueLabel()
        local value = currentValue()
        if multi then
            fullText = #value > 0 and table.concat(value, ", ") or "None"
        else
            fullText = value ~= nil and tostring(value) or "None"
        end
        valueLabel.Text = trimmed()
        for option, button in pairs(optionButtons) do
            local on = selected[option] == true
            if button.On ~= on then
                button.On = on
                tween(button.Label, { TextColor3 = on and Theme.Text or Theme.Muted }, 0.15)
                if self_.Open then
                    tween(button.Check, { ImageTransparency = on and 0 or 1 }, 0.15)
                    tween(button.CheckScale, { Scale = on and 1 or 0.6 }, on and 0.3 or 0.15, on and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
                end
            end
        end
    end

    local function visibleCount()
        local count = 0
        for _, option in ipairs(options) do
            if matches(option) then
                count = count + 1
            end
        end
        return count
    end

    local function applyFilter()
        for option, button in pairs(optionButtons) do
            button.Frame.Visible = matches(option)
        end
    end

    local function expandedHeight()
        local rows = visibleCount() + (searchHolder.Visible and 1 or 0)
        return height + rows * (DROPDOWN_OPTION_HEIGHT + 4) + 8
    end

    local function setOpen(open)
        self_.Open = open
        searchHolder.Visible = #options > SEARCH_THRESHOLD
        if not open then
            filter = ""
            searchBox.Text = ""
            applyFilter()
        end
        tween(frame, { Size = UDim2.new(1, 0, 0, open and expandedHeight() or height) }, 0.3, Enum.EasingStyle.Quint)
        tween(searchHolder, { BackgroundTransparency = open and 0 or 1 }, 0.2)
        tween(searchStroke, { Transparency = open and 0 or 1 }, 0.2)
        tween(searchBox, { TextTransparency = open and 0 or 1 }, 0.2)
        arrow:Set(open)
        tween(chipStroke, { Color = open and Theme.StrokeHover or Theme.Stroke }, 0.2)
        local function show(button)
            if not button.Stroke then
                button.Stroke = stroke(button.Frame, Theme.Stroke, 1)
            end
            local on = open and button.On
            tween(button.Check, { ImageTransparency = on and 0 or 1 }, 0.18)
            button.CheckScale.Scale = on and 1 or 0.6
            tween(button.Label, { TextTransparency = open and 0 or 1 }, 0.18)
            tween(button.Stroke, { Transparency = open and 0 or 1 }, 0.18)
            tween(button.Frame, { BackgroundTransparency = open and 0 or 1 }, 0.18)
        end
        if open then
            local generation = (self_._openGeneration or 0) + 1
            self_._openGeneration = generation
            task.spawn(function()
                local first = true
                for _, option in ipairs(options) do
                    local button = optionButtons[option]
                    if button and button.Frame.Visible then
                        if not first then
                            task.wait(0.025)
                            if self_._openGeneration ~= generation or not self_.Open then
                                return
                            end
                        end
                        first = false
                        show(button)
                    end
                end
            end)
        else
            local generation = (self_._openGeneration or 0) + 1
            self_._openGeneration = generation
            local visible = {}
            for _, option in ipairs(options) do
                local button = optionButtons[option]
                if button and button.Frame.Visible then
                    table.insert(visible, button)
                end
            end
            task.spawn(function()
                for index = #visible, 1, -1 do
                    show(visible[index])
                    if index > 1 then
                        task.wait(0.015)
                        if self_._openGeneration ~= generation or self_.Open then
                            return
                        end
                    end
                end
            end)
        end
    end

    local function buildOptions()
        local keep = {}
        for index, option in ipairs(options) do
            keep[option] = index
        end
        for option, button in pairs(optionButtons) do
            if not keep[option] then
                button.Frame:Destroy()
                optionButtons[option] = nil
            end
        end
        for index, option in ipairs(options) do
            local existing = optionButtons[option]
            if existing then
                existing.Frame.LayoutOrder = index
                continue
            end
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, DROPDOWN_OPTION_HEIGHT),
                BackgroundColor3 = Theme.Surface,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
                Parent = listHolder,
            })
            corner(button, UDim.new(0, 6))
            local check = create("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Accent,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
                Parent = button,
            })
            applyIcon(check, "check")
            local checkScale = create("UIScale", { Scale = 0.6, Parent = check })
            local text_ = label({
                Position = UDim2.fromOffset(12, -1),
                Size = UDim2.new(1, -36, 1, 0),
                Text = tostring(option),
                TextSize = 13,
                TextColor3 = Theme.Muted,
                TextTransparency = 1,
                Parent = button,
            })
            button.MouseEnter:Connect(function()
                tween(text_, { TextColor3 = Theme.Text }, 0.15)
                local entry = optionButtons[option]
                if entry and entry.Stroke then
                    tween(entry.Stroke, { Color = Theme.StrokeHover }, 0.12)
                end
            end)
            button.MouseLeave:Connect(function()
                tween(text_, { TextColor3 = selected[option] and Theme.Text or Theme.Muted }, 0.2)
                local entry = optionButtons[option]
                if entry and entry.Stroke then
                    tween(entry.Stroke, { Color = Theme.Stroke }, 0.2)
                end
            end)
            button.MouseButton1Click:Connect(function()
                if selected[option] then
                    selected[option] = nil
                else
                    if not multi then
                        selected = {}
                    end
                    selected[option] = true
                end
                renderValueLabel()
                safeCall(opts.Callback, currentValue())
                if not multi and selected[option] then
                    setOpen(false)
                end
            end)
            optionButtons[option] = { Frame = button, Label = text_, Check = check, CheckScale = checkScale, Stroke = nil, On = nil }
        end
        applyFilter()
        if self_.Open then
            frame.Size = UDim2.new(1, 0, 0, expandedHeight())
        end
    end

    function self_:Set(value, silent)
        selected = {}
        if multi then
            for _, item in ipairs(type(value) == "table" and value or { value }) do
                selected[item] = true
            end
        elseif value ~= nil then
            selected[value] = true
        end
        renderValueLabel()
        flashStroke(frameStroke)
        if not silent then
            safeCall(opts.Callback, currentValue())
        end
    end

    function self_:Get()
        return currentValue()
    end

    function self_:Refresh(newOptions, keepSelection)
        options = newOptions or {}
        if not keepSelection then
            selected = {}
        end
        buildOptions()
        renderValueLabel()
        if self_.Open then
            setOpen(true)
        end
    end

    function self_:SetOpen(open)
        setOpen(open == true)
    end

    header.MouseButton1Click:Connect(function()
        setOpen(not self_.Open)
    end)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        filter = string.lower(searchBox.Text)
        applyFilter()
        if self_.Open then
            tween(frame, { Size = UDim2.new(1, 0, 0, expandedHeight()) }, 0.2, Enum.EasingStyle.Quint)
        end
    end)
    buildOptions()
    renderValueLabel()
    task.defer(fitChip, true)
    return finishElement(self, opts, self_, frame, "Dropdown")
end

function Tab:Input(opts)
    local frame, frameStroke, _, titleLabel, descLabel
    opts, frame, frameStroke, _, titleLabel, descLabel = beginElement(self, opts, { Title = "Name", Description = "Desc", PlaceholderText = "Placeholder", CurrentValue = "Default", Value = "Default" }, "Frame", 160, "Input")

    local boxHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(170, 30),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(boxHolder, UDim.new(0, 6))
    local boxStroke = stroke(boxHolder)

    local boxIcon = opts.Icon
    if boxIcon then
        glowIcon(boxHolder, boxIcon, Theme.Muted, UDim2.new(0, 8, 0.5, 0))
    end
    local box = create("TextBox", {
        Position = UDim2.fromOffset(boxIcon and 30 or 8, 0),
        Size = UDim2.new(1, boxIcon and -38 or -16, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = boxHolder,
    })
    boxHolder.ClipsDescendants = true

    local focused = false
    local textInset = (boxIcon and 30 or 8) + 8
    local function fitBox(instant)
        local cardWidth = frame.AbsoluteSize.X / self.Window.Scale.Scale
        local maxWidth = math.clamp(cardWidth - 14 - 110 - 20, 100, 200)
        local content = box.Text
        local measured = box.TextBounds.X
        if #content == 0 then
            measured = math.min(box.TextBounds.X, 90)
        end
        local width = math.clamp(measured + textInset + 12, 90, maxWidth) + (focused and 8 or 0)
        width = math.min(width, maxWidth + 8)
        reserveRight(titleLabel, descLabel, width + 20)
        if instant then
            boxHolder.Size = UDim2.fromOffset(width, 30)
        else
            tween(boxHolder, { Size = UDim2.fromOffset(width, 30) }, 0.18)
        end
    end
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        fitBox(true)
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        fitBox(false)
    end)
    box:GetPropertyChangedSignal("TextBounds"):Connect(function()
        fitBox(false)
    end)
    task.defer(fitBox, true)

    box.Focused:Connect(function()
        focused = true
        tween(boxStroke, { Color = Theme.StrokeHover }, 0.15)
        fitBox(false)
    end)
    box.FocusLost:Connect(function(enterPressed)
        focused = false
        tween(boxStroke, { Color = Theme.Stroke }, 0.15)
        fitBox(false)
        if opts.Numeric then
            local number = tonumber(box.Text)
            if not number then
                box.Text = ""
                return
            end
        end
        safeCall(opts.Callback, box.Text, enterPressed)
    end)

    return finishElement(self, opts, {
        Set = function(_, value)
            box.Text = tostring(value)
            flashStroke(frameStroke)
        end,
        Get = function()
            return box.Text
        end,
    }, frame, "Input")
end

function Tab:Keybind(opts)
    local frame, frameStroke, _, titleLabel, descLabel
    opts, frame, frameStroke, _, titleLabel, descLabel = beginElement(self, opts, { Title = "Name", Description = "Desc", CurrentKeybind = "Default", Value = "Default" }, "Frame", 110, "Keybind")
    if type(opts.Default) == "string" then
        opts.Default = Enum.KeyCode[opts.Default]
    end

    local chip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(44, CHIP_HEIGHT),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    local chipLabel = label({
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = 13,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = chip,
    })

    local self_ = { Value = opts.Default, Listening = false }

    local function fitChip(instant)
        local width = math.max(chipLabel.TextBounds.X + 20, TOUCH and 44 or 36)
        reserveRight(titleLabel, descLabel, width + 20)
        if instant then
            chip.Size = UDim2.fromOffset(width, CHIP_HEIGHT)
        else
            tween(chip, { Size = UDim2.fromOffset(width, CHIP_HEIGHT) }, 0.2)
        end
    end
    chipLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        fitChip(false)
    end)

    local function render()
        chipLabel.Text = self_.Listening and "..." or keyName(self_.Value)
        tween(chipStroke, { Color = self_.Listening and Theme.StrokeHover or Theme.Stroke }, 0.15)
        tween(chipLabel, { TextColor3 = self_.Listening and Theme.Accent or Theme.Muted }, 0.15)
    end

    function self_:Set(keyCode, silent)
        local wasListening = self_.Listening
        self_.Value = keyCode
        self_.Listening = false
        render()
        if not wasListening then
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.OnChanged, keyCode)
        end
    end

    chip.MouseButton1Click:Connect(function()
        self_.Listening = not self_.Listening
        render()
    end)

    self.Window:_listen("Began", function(input, gameProcessed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if self_.Listening then
            self.Window._consumedKey = input.KeyCode
            self.Window._consumedAt = os.clock()
            if input.KeyCode == Enum.KeyCode.Escape then
                self_.Listening = false
                render()
            else
                self_:Set(input.KeyCode)
            end
            return
        end
        if not gameProcessed and self_.Value ~= nil and input.KeyCode == self_.Value then
            safeCall(opts.Callback, input.KeyCode)
        end
    end, self_)

    render()
    task.defer(fitChip, true)
    function self_:Get()
        return self_.Value
    end
    return finishElement(self, opts, self_, frame, "Keybind")
end

function Tab:ColorPicker(opts)
    local PANEL_HEIGHT = 168
    local frame, frameStroke, height
    opts, frame, frameStroke, height = beginElement(self, opts, { Title = "Name", Description = "Desc", Color = "Default", CurrentValue = "Default", Value = "Default" }, "Frame")
    frame.ClipsDescendants = true

    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = frame,
    })
    titleDesc(header, opts.Name or "Color", opts.Desc, 90)

    local swatch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -34, 0.5, 0),
        Size = UDim2.fromOffset(36, 20),
        BorderSizePixel = 0,
        Parent = header,
    })
    corner(swatch, UDim.new(0, 6))
    stroke(swatch, Theme.Stroke)
    local arrow = arrowIndicator(header, 1, -12)

    local panel = create("Frame", {
        Position = UDim2.fromOffset(14, height + 2),
        Size = UDim2.new(1, -28, 0, PANEL_HEIGHT - 12),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = frame,
    })

    local svBox = create("TextButton", {
        Size = UDim2.new(1, -30, 0, 110),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = panel,
    })
    corner(svBox, UDim.new(0, 6))
    local svHueGradient = create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 0, 0)),
        Parent = svBox,
    })
    local svDark = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Parent = svBox,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
        Parent = svDark,
    })
    local svCursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = svBox,
    })
    corner(svCursor, UDim.new(1, 0))
    stroke(svCursor, Color3.new(1, 1, 1), 0, 2)

    local hueBar = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(14, 110),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = panel,
    })
    corner(hueBar, UDim.new(0, 6))
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
        Rotation = 90,
        Parent = hueBar,
    })
    local hueCursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.fromOffset(18, 5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = hueBar,
    })
    corner(hueCursor, UDim.new(1, 0))
    stroke(hueCursor, Theme.AccentDark, 0.4)

    local hexHolder = create("Frame", {
        Position = UDim2.fromOffset(6, 122),
        Size = UDim2.fromOffset(118, 28),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = panel,
    })
    corner(hexHolder, UDim.new(0, 6))
    local hexStroke = stroke(hexHolder)
    local hexBox = create("TextBox", {
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = false,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = hexHolder,
    })
    local rgbLabel = label({
        Position = UDim2.fromOffset(134, 122),
        Size = UDim2.new(1, -134, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = panel,
    })

    local self_ = { Open = false }
    local hue, sat, val = Color3.toHSV(opts.Default or Theme.Accent)
    local dragTarget = nil

    local function toHex(color)
        return string.format("#%02X%02X%02X",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function render(duration)
        local color = Color3.fromHSV(hue, sat, val)
        self_.Value = color
        swatch.BackgroundColor3 = color
        svHueGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
        tween(svCursor, { Position = UDim2.fromScale(sat, 1 - val) }, duration, Enum.EasingStyle.Linear)
        tween(hueCursor, { Position = UDim2.new(0.5, 0, hue, 0) }, duration, Enum.EasingStyle.Linear)
        if not hexBox:IsFocused() then
            hexBox.Text = toHex(color)
        end
        rgbLabel.Text = string.format("RGB %d, %d, %d",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function commit(duration, silent)
        render(duration)
        if not silent then
            safeCall(opts.Callback, self_.Value)
        end
    end

    function self_:Set(color, silent)
        hue, sat, val = Color3.toHSV(color)
        commit(0.25, silent)
        flashStroke(frameStroke)
    end

    function self_:Get()
        return self_.Value
    end

    local function setOpen(open)
        self_.Open = open
        tween(frame, { Size = UDim2.new(1, 0, 0, open and (height + PANEL_HEIGHT) or height) }, 0.35, Enum.EasingStyle.Quint)
        arrow:Set(open)
        if open then
            panel.Visible = true
        else
            task.delay(0.35, function()
                if not self_.Open then
                    panel.Visible = false
                end
            end)
        end
    end

    function self_:SetOpen(open)
        setOpen(open == true)
    end

    header.MouseButton1Click:Connect(function()
        setOpen(not self_.Open)
    end)

    local function updateSV(position)
        sat = math.clamp((position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
        val = 1 - math.clamp((position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
        commit(0.04)
    end
    local function updateHue(position)
        hue = math.clamp((position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 0.999)
        commit(0.04)
    end

    svBox.InputBegan:Connect(function(input)
        if isPress(input) then
            dragTarget = "sv"
            tween(svCursor, { Size = UDim2.fromOffset(14, 14) }, 0.15, Enum.EasingStyle.Back)
            updateSV(pointerPosition())
        end
    end)
    hueBar.InputBegan:Connect(function(input)
        if isPress(input) then
            dragTarget = "hue"
            tween(hueCursor, { Size = UDim2.fromOffset(20, 7) }, 0.15, Enum.EasingStyle.Back)
            updateHue(pointerPosition())
        end
    end)
    self.Window:_listen("Changed", function(input)
        if not dragTarget or not isMove(input) then
            return
        end
        local position = pointerPosition()
        if dragTarget == "sv" then
            updateSV(position)
        else
            updateHue(position)
        end
    end, self_)
    self.Window:_listen("Ended", function(input)
        if dragTarget and isPress(input) then
            dragTarget = nil
            tween(svCursor, { Size = UDim2.fromOffset(10, 10) }, 0.2)
            tween(hueCursor, { Size = UDim2.fromOffset(18, 5) }, 0.2)
        end
    end, self_)

    hexBox.Focused:Connect(function()
        tween(hexStroke, { Color = Theme.StrokeHover }, 0.15)
    end)
    hexBox.FocusLost:Connect(function()
        tween(hexStroke, { Color = Theme.Stroke }, 0.15)
        local r, g, b = hexBox.Text:match("^%s*#?(%x%x)(%x%x)(%x%x)%s*$")
        if r then
            self_:Set(Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)))
        else
            hexBox.Text = toHex(self_.Value)
        end
    end)

    render(0)
    return finishElement(self, opts, self_, frame, "ColorPicker")
end

function Tab:Stepper(opts)
    local frame, frameStroke, _, titleLabel, descLabel
    opts, frame, frameStroke, _, titleLabel, descLabel = beginElement(self, opts, { Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default", Increment = "Step" }, "Frame", 150, "Stepper")
    local min = opts.Min or 0
    local max = opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local numbers = numberFormat(min, max, step)

    local group = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(0, CHIP_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(group, UDim.new(0, 6))
    local groupStroke = stroke(group)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = group,
    })

    local function stepButton(text, order)
        local button = create("TextButton", {
            Size = UDim2.fromOffset(CHIP_HEIGHT, CHIP_HEIGHT),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.Muted,
            TextSize = 18,
            FontFace = Fonts.Medium,
            AutoButtonColor = false,
            LayoutOrder = order,
            Parent = group,
        })
        button.MouseEnter:Connect(function()
            tween(button, { TextColor3 = Theme.Accent }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { TextColor3 = Theme.Muted }, 0.2)
        end)
        return button
    end
    local minus = stepButton("−", 1)
    local valueLabel = label({
        Size = UDim2.new(0, 30, 1, 0),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        Parent = group,
    })
    local plus = stepButton("+", 3)
    local function fitValue(instant)
        local width = math.max(valueLabel.TextBounds.X + 12, 30)
        if instant then
            valueLabel.Size = UDim2.new(0, width, 1, 0)
        else
            tween(valueLabel, { Size = UDim2.new(0, width, 1, 0) }, 0.2)
        end
    end
    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        fitValue(false)
    end)
    group:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        reserveRight(titleLabel, descLabel, group.AbsoluteSize.X / self.Window.Scale.Scale + 20)
    end)

    local self_ = { Value = math.clamp(opts.Default or min, min, max) }
    local snap = numbers.snap
    local fromButton = false
    local function render()
        valueLabel.Text = numbers.format(self_.Value) .. suffix
        tween(minus, { TextTransparency = self_.Value <= min and 0.6 or 0 }, 0.15)
        tween(plus, { TextTransparency = self_.Value >= max and 0.6 or 0 }, 0.15)
    end
    function self_:Set(value, silent)
        value = snap(tonumber(value) or min)
        if value == self_.Value then
            return
        end
        self_.Value = value
        render()
        if not fromButton then
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.Callback, value)
        end
    end
    function self_:Get()
        return self_.Value
    end

    local function bump(direction)
        fromButton = true
        self_:Set(self_.Value + direction * step)
        fromButton = false
        tween(groupStroke, { Color = Theme.StrokeHover }, 0.08)
        task.delay(0.12, function()
            tween(groupStroke, { Color = Theme.Stroke }, 0.2)
        end)
    end
    local function holdRepeat(button, direction)
        local holding = false
        button.InputBegan:Connect(function(input)
            if not isPress(input) then
                return
            end
            holding = true
            bump(direction)
            task.delay(0.4, function()
                while holding do
                    bump(direction)
                    task.wait(0.07)
                end
            end)
        end)
        button.InputEnded:Connect(function(input)
            if isPress(input) then
                holding = false
            end
        end)
        button.MouseLeave:Connect(function()
            holding = false
        end)
    end
    holdRepeat(minus, -1)
    holdRepeat(plus, 1)

    render()
    task.defer(fitValue, true)
    return finishElement(self, opts, self_, frame, "Stepper")
end

function Tab:Progress(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default" })
    local frame, frameStroke = card(self, "Frame", opts.Desc and CARD_HEIGHT_DESC + 10 or CARD_HEIGHT + 10, opts)
    hoverStroke(frame, frameStroke)
    local top = opts.Desc and (CARD_HEIGHT_DESC - 38) / 2 - 2 or 12

    label({
        Position = UDim2.fromOffset(14, top),
        Size = UDim2.new(1, -110, 0, 18),
        Text = opts.Name or "Progress",
        Parent = frame,
    })
    if opts.Desc then
        label({
            Position = UDim2.fromOffset(14, top + 20),
            Size = UDim2.new(1, -110, 0, 17),
            Text = opts.Desc,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = frame,
        })
    end
    local valueLabel = label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, top),
        Size = UDim2.fromOffset(90, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 13,
        TextColor3 = Theme.Accent,
        Parent = frame,
    })
    local track = create("Frame", {
        Position = UDim2.new(0, 14, 1, -16),
        Size = UDim2.new(1, -28, 0, 5),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(track, UDim.new(1, 0))
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = opts.Color or Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, UDim.new(1, 0))

    local self_ = { Value = math.clamp(opts.Default or 0, 0, 1) }
    local formatter = opts.Format
    local function render(duration)
        local frac = self_.Value
        tween(fill, { Size = UDim2.new(frac, 0, 1, 0) }, duration, Enum.EasingStyle.Quint)
        if type(formatter) == "function" then
            valueLabel.Text = tostring(formatter(frac))
        else
            valueLabel.Text = string.format("%d%%", math.floor(frac * 100 + 0.5))
        end
    end
    function self_:Set(value, silent)
        value = math.clamp(tonumber(value) or 0, 0, 1)
        if value == self_.Value then
            return
        end
        self_.Value = value
        render(0.35)
        if not silent then
            safeCall(opts.Callback, value)
        end
    end
    function self_:Get()
        return self_.Value
    end
    function self_:SetColor(color)
        fill.BackgroundColor3 = color
    end
    render(0)
    return finishElement(self, opts, self_, frame, "Progress")
end


function Tab:ConfigManager(opts)
    opts = normalize(opts, {})
    local window = self.Window
    local manager = {}
    self:Section(opts.Name or "Configs")
    local nameInput = self:Input({
        Name = "Config name",
        Placeholder = window.ConfigName,
        Callback = function(text, enterPressed)
            if enterPressed and #text > 0 then
                manager:Save(text)
            end
        end,
    })
    local list = self:Dropdown({
        Name = "Saved configs",
        Options = window:ListConfigs(),
        Default = window.ConfigName,
        Callback = function(choice)
            if choice then
                nameInput:Set(choice)
            end
        end,
    })
    function manager:Refresh()
        list:Refresh(window:ListConfigs(), true)
    end
    function manager:Save(name)
        name = name or list:Get() or window.ConfigName
        local ok, err = window:SaveConfig(name)
        manager:Refresh()
        list:Set(name, true)
        window:Notify({ Title = ok and "Config saved" or "Save failed", Content = ok and name or tostring(err), Type = ok and "Success" or "Error", Duration = 3 })
    end
    function manager:Load(name)
        name = name or list:Get()
        if not name then
            return
        end
        local ok, err = window:LoadConfig(name)
        window:Notify({ Title = ok and "Config loaded" or "Load failed", Content = ok and name or tostring(err), Type = ok and "Success" or "Error", Duration = 3 })
    end
    function manager:Delete(name)
        name = name or list:Get()
        if not name then
            return
        end
        local ok, err = window:DeleteConfig(name)
        manager:Refresh()
        window:Notify({ Title = ok and "Config deleted" or "Delete failed", Content = ok and name or tostring(err), Type = ok and "Info" or "Error", Duration = 3 })
    end
    self:Button({ Name = "Save", Desc = "Writes every flagged element to the selected name", Icon = "save", Style = "Primary", Callback = function()
        local typed = nameInput:Get()
        manager:Save(#typed > 0 and typed or nil)
    end })
    self:Button({ Name = "Load", Icon = "folder-open", Callback = function()
        manager:Load()
    end })
    self:Button({ Name = "Delete", Icon = "trash-2", Callback = function()
        local name = list:Get()
        if not name then
            return
        end
        window:Confirm({
            Title = "Delete config",
            Content = "Remove " .. name .. "? This cannot be undone.",
            Icon = "trash-2",
            ConfirmText = "Delete",
            Callback = function()
                manager:Delete(name)
            end,
        })
    end })
    self:Toggle({
        Name = "Auto save",
        Desc = "Save whenever a flagged element changes",
        Default = window._autoSaveEnabled,
        Callback = function(on)
            window._autoSaveEnabled = on
        end,
    })
    return manager
end

for name, method in pairs(table.clone(Tab)) do
    if type(method) == "function" and name:sub(1, 1) ~= "_" and name:sub(1, 6) ~= "Create" then
        Tab["Create" .. name] = method
    end
end

local function detectExecutor()
    local name
    pcall(function()
        if typeof(identifyexecutor) == "function" then
            name = (identifyexecutor())
        elseif typeof(getexecutorname) == "function" then
            name = getexecutorname()
        end
    end)
    if type(name) == "string" and #name > 0 then
        return name
    end
    return RunService:IsStudio() and "Studio" or "Unknown"
end

local function detectGameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" and info.Name then
        return info.Name
    end
    return "Unknown game"
end

local REGION_NAMES = {
    US = "United States", GB = "United Kingdom", DE = "Germany", FR = "France",
    NL = "Netherlands", SG = "Singapore", JP = "Japan", AU = "Australia",
    BR = "Brazil", IN = "India", HK = "Hong Kong", CA = "Canada",
}

local function detectRegion(callback)
    task.spawn(function()
        local requester = request or http_request or (syn and syn.request) or (http and http.request)
        local region
        if type(requester) == "function" then
            pcall(function()
                local response = requester({ Url = "https://ipinfo.io/json", Method = "GET" })
                local body = type(response) == "table" and (response.Body or response.body) or nil
                if type(body) == "string" then
                    local data = HttpService:JSONDecode(body)
                    if type(data) == "table" and data.country then
                        local label = REGION_NAMES[data.country] or data.country
                        region = data.city and (data.city .. ", " .. label) or label
                    end
                end
            end)
        end
        callback(region or "Unavailable")
    end)
end

local NOTIFY_COLORS = {
    Success = Theme.Success,
    Warning = Theme.Warning,
    Error = Theme.Error,
}

local Window = {}
Window.__index = Window

function Library.Window(_, opts)
    opts = normalize(opts, { Name = "Title", LoadingSubtitle = "Subtitle", ToggleUIKeybind = "Keybind" })

    if type(opts.Keybind) == "string" then
        opts.Keybind = Enum.KeyCode[opts.Keybind]
    end
    -- GameFont = true (or { Body = true }): take the game's text style before anything is drawn.
    if opts.GameFont then
        pcall(Library.UseGameFont, Library, type(opts.GameFont) == "table" and opts.GameFont or nil)
    end
    -- Compact by default so the game (its HUD, the egg field) stays visible next to the hub.
    local size = opts.Size or (TOUCH and UDim2.fromOffset(560, 400) or UDim2.fromOffset(580, 420))
    local keybind = opts.Keybind or Enum.KeyCode.RightControl

    local self = setmetatable({
        Tabs = {},
        CurrentTab = nil,
        Open = true,
        Keybind = keybind,
        _connections = {},
        _controls = {},
        _inputListeners = { Began = {}, Changed = {}, Ended = {}, Render = {} },
        _frameSteps = {},
        _destroyed = false,
    }, Window)
    local function dispatch(kind)
        return function(...)
            for _, handler in ipairs(self._inputListeners[kind]) do
                handler(...)
            end
        end
    end
    local renderDispatch = dispatch("Render")
    table.insert(self._connections, RunService.RenderStepped:Connect(function(deltaTime)
        renderDispatch(deltaTime)
        for _, step in ipairs(self._frameSteps) do
            step(deltaTime)
        end
    end))
    table.insert(self._connections, UserInputService.InputBegan:Connect(dispatch("Began")))
    table.insert(self._connections, UserInputService.InputChanged:Connect(dispatch("Changed")))
    table.insert(self._connections, UserInputService.InputEnded:Connect(dispatch("Ended")))

    local gui = create("ScreenGui", {
        Name = opts.Name or "BloomHub",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui:SetAttribute("BloomUI", true)
    self.Gui = gui

    local root = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        BackgroundTransparency = 1,
        Parent = gui,
    })
    self.Root = root
    local scale = create("UIScale", { Parent = root })
    self.Scale = scale

    local shadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-25, -25),
        Size = UDim2.new(1, 50, 1, 50),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Parent = root,
    })
    self.Shadow = shadow

    local body = create("CanvasGroup", {
        Name = "Body",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = root,
    })
    self.Body = body
    corner(body, UDim.new(0, 10))
    -- Thick ink frame around the window (only its transparency is animated elsewhere).
    self.BodyStroke = stroke(body, Theme.Outline, 0, 3)
    self.BodyStroke.LineJoinMode = Enum.LineJoinMode.Round
    edgeHighlight(body)

    glow(body, UDim2.fromOffset(500, 180), UDim2.new(0.5, 0, 1, 8), 0.86, 270)
    glow(body, UDim2.fromOffset(130, 60), UDim2.new(0, -10, 1, -10), 0.75, 90)
    glow(body, UDim2.fromOffset(520, 240), UDim2.new(1, -14, 0, 10), 0.92, 90)

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
        BackgroundTransparency = 1,
        Parent = body,
    })
    -- Sidebar panel: a shade apart from the content, with a faint accent wash coming down from the top.
    local sidebarPanel = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = sidebar,
    })
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Surface:Lerp(Theme.Accent, 0.14)),
            ColorSequenceKeypoint.new(0.35, Theme.Surface),
            ColorSequenceKeypoint.new(1, Theme.Background),
        }),
        Parent = sidebarPanel,
    })
    create("Frame", {
        Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 28),
        Size = UDim2.new(0, 1, 1, -56),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = body,
    })

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BackgroundTransparency = 1,
        Parent = sidebar,
    })
    local logo = create("ImageLabel", {
        Position = UDim2.fromOffset(22, 27),
        Size = UDim2.fromOffset(30, 28),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        Parent = header,
    })
    applyIcon(logo, opts.Icon or Assets.Logo)
    shinyText(label({
        Position = UDim2.fromOffset(60, 25),
        Size = UDim2.new(1, -70, 0, 20),
        Text = opts.Title or "Bloom Hub",
        TextSize = 18,
        Parent = header,
    }))
    label({
        Position = UDim2.fromOffset(60, 45),
        Size = UDim2.new(1, -70, 0, 14),
        Text = opts.Subtitle or "",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = header,
    })

    local tabList = create("ScrollingFrame", {
        Name = "Tabs",
        Position = UDim2.fromOffset(0, HEADER_HEIGHT + 8),
        Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 8 + 36)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = sidebar,
    })
    self.TabList = tabList
    padding(tabList, 16, 16, 4, 4)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = tabList,
    })

    local indicator = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(6, 0),
        Size = UDim2.fromOffset(3, 18),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
        Parent = sidebar,
    })
    corner(indicator, UDim.new(1, 0))
    self.Indicator = indicator
    local lastCanvasY = tabList.CanvasPosition.Y
    table.insert(self._frameSteps, function()
        local canvasY = tabList.CanvasPosition.Y
        if canvasY == lastCanvasY or not self.CurrentTab or not self._introDone then
            return
        end
        lastCanvasY = canvasY
        local targetY = self:_indicatorY(self.CurrentTab)
        local top = tabList.Position.Y.Offset
        local bottom = top + tabList.AbsoluteSize.Y / self.Scale.Scale
        indicator.Visible = targetY > top and targetY < bottom
        indicator.Position = UDim2.fromOffset(6, targetY)
    end)

    local footer = create("Frame", {
        Position = UDim2.new(0, 22, 1, -36),
        Size = UDim2.new(1, -44, 0, 22),
        BackgroundTransparency = 1,
        Parent = sidebar,
    })
    local keyChip = create("Frame", {
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = footer,
    })
    corner(keyChip, UDim.new(0, 5))
    stroke(keyChip)
    padding(keyChip, 7, 7)
    local keyChipLabel = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = keyName(keybind),
        TextSize = 11,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        Parent = keyChip,
    })
    self._keyChipLabel = keyChipLabel
    local hintLabel = label({
        Size = UDim2.new(1, 0, 1, 0),
        Text = TOUCH and "or tap the icon" or "to hide",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = footer,
    })
    local function placeHint()
        hintLabel.Position = UDim2.fromOffset(keyChip.AbsoluteSize.X / self.Scale.Scale + 8, 0)
    end
    keyChip:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeHint)
    task.defer(placeHint)

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(SIDEBAR_WIDTH + 1, 0),
        Size = UDim2.new(1, -(SIDEBAR_WIDTH + 1), 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = body,
    })
    self.Content = content
    self._outLayer = create("CanvasGroup", {
        Name = "TransitionOut",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 2,
        Parent = content,
    })
    self._inLayer = create("CanvasGroup", {
        Name = "TransitionIn",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 3,
        Parent = content,
    })

    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 28,
        FontFace = Fonts.Bold,
        AutoButtonColor = false,
        ZIndex = 5,
        Parent = content,
    })
    padding(closeButton, 0, 0, 1, 0)
    corner(closeButton, UDim.new(0, 8))
    closeButton.MouseEnter:Connect(function()
        tween(closeButton, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, 0.15)
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, { BackgroundTransparency = 1, TextColor3 = Theme.Muted }, 0.2)
    end)
    closeButton.MouseButton1Click:Connect(function()
        self:Toggle(false)
    end)

    local notifyHolder = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.new(0, 220, 1, -40),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    local function fitToasts()
        -- Compact toasts: a third of a phone screen at most, never wider than 220.
        notifyHolder.Size = UDim2.new(0, math.min(220, math.floor(gui.AbsoluteSize.X * 0.32)), 1, -40)
    end
    table.insert(self._connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToasts))
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 4),
        Parent = notifyHolder,
    })
    self.NotifyHolder = notifyHolder
    self._notifyOrder = 0
    self._toasts = {}
    self.MaxNotifications = opts.MaxNotifications or 4

    self._controlsDirty = true
    table.insert(self._connections, body.DescendantAdded:Connect(function()
        self._controlsDirty = true
    end))
    table.insert(self._connections, body.DescendantRemoving:Connect(function()
        self._controlsDirty = true
    end))

    self:_enableDrag()
    self.MaxSize = opts.MaxSize
    self.KeepOnScreen = opts.KeepOnScreen ~= false
    self:_enableResize(opts.MinSize or (TOUCH and Vector2.new(420, 320) or Vector2.new(480, 360)))

    local saving = opts.ConfigurationSaving
    if type(saving) == "table" and saving.Enabled ~= false then
        self.ConfigFolder = saving.FolderName or "BloomHub"
        self.ConfigName = saving.FileName or "default"
        self._autoSaveEnabled = true
    else
        self.ConfigFolder = "BloomHub"
        self.ConfigName = "default"
        self._autoSaveEnabled = false
    end

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self.Keybind then
            task.defer(function()
                local consumed = self._consumedKey == input.KeyCode and os.clock() - (self._consumedAt or 0) < 0.2
                self._consumedKey = nil
                if not consumed and not self._destroyed then
                    self:Toggle(not self.Open)
                end
            end)
        end
    end))

    pcall(function()
        if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
        end
    end)
    gui.Parent = opts.Parent or defaultParent()

    scale.Scale = 0.9
    body.GroupTransparency = 1
    shadow.ImageTransparency = 1
    self.BodyStroke.Transparency = 1
    root.Visible = false
    self:_fitToScreen(true)
    table.insert(self._connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_fitToScreen()
        self:_clampToScreen()
    end))
    if opts.OpenButton ~= false then
        self:_createOpenButton(type(opts.OpenButton) == "table" and opts.OpenButton or {})
    end
    self._introDone = false

    table.insert(Library.Windows, self)

    if opts.Home then
        self:_buildHome(type(opts.Home) == "table" and opts.Home or {})
    end

    local loading = opts.Loading
    if type(loading) == "table" then
        opts.LoadingDuration = loading.Duration or opts.LoadingDuration
        opts.LoadingText = loading.Text or loading.Subtitle or opts.LoadingText
        opts.LoadingSteps = loading.Steps or opts.LoadingSteps
        opts.LoadingTitle = loading.Title or opts.LoadingTitle
        loading = loading.Enabled ~= false
    end
    if loading == false then
        task.defer(function()
            self:_playIntro()
        end)
    else
        self:_showLoader(opts)
    end
    return self
end

Library.CreateWindow = Library.Window



function Library:Notify(opts)
    local window = Library.Windows[#Library.Windows]
    if window then
        return window:Notify(opts)
    end
end

function Library:Confirm(opts)
    local window = Library.Windows[#Library.Windows]
    if window then
        return window:Confirm(opts)
    end
end

function Library:Dialog(opts)
    local window = Library.Windows[#Library.Windows]
    if window then
        return window:Dialog(opts)
    end
end

local function pointInside(point, object)
    local position, size = object.AbsolutePosition, object.AbsoluteSize
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

-- Inside `object` and within its border band: windows and HUDs only move when grabbed by their edges, so a press in
-- the middle (scrolling a list, missing a button) never drags them.
local EDGE_BAND = TOUCH and 22 or 14
local function nearEdge(point, object)
    if not pointInside(point, object) then
        return false
    end
    local position, size = object.AbsolutePosition, object.AbsoluteSize
    return point.X - position.X <= EDGE_BAND or position.X + size.X - point.X <= EDGE_BAND
        or point.Y - position.Y <= EDGE_BAND or position.Y + size.Y - point.Y <= EDGE_BAND
end

local function isShown(object, stopAt, point)
    local child = object
    while child and child ~= stopAt and child:IsA("GuiObject") do
        if not child.Visible then
            return false
        end
        local parent = child.Parent
        if parent and parent ~= stopAt and parent:IsA("GuiObject") and (parent.ClipsDescendants or parent:IsA("ScrollingFrame")) and not pointInside(point, parent) then
            return false
        end
        child = parent
    end
    return true
end

function Window:_refreshControls()
    local controls = {}
    for _, object in ipairs(self.Body:GetDescendants()) do
        if object:IsA("GuiButton") or object:IsA("TextBox") or object:GetAttribute("NoDrag") then
            table.insert(controls, object)
        end
    end
    self._controls = controls
    self._controlsDirty = false
end

function Window:_overControl(point)
    if self._dialog then
        return true
    end
    if self._controlsDirty then
        self:_refreshControls()
    end
    for _, object in ipairs(self._controls) do
        if object.Parent and pointInside(point, object) and isShown(object, self.Body, point) then
            return true
        end
    end
    return false
end

function Window:_enableDrag()
    -- Only the touch that grabbed the window moves it (GetMouseLocation on mobile is the last touch of ANY finger).
    local dragInput = nil
    local touchPoint = nil
    local grabOffset = Vector2.zero
    local target = nil

    local function centre()
        local root = self.Root
        return root.AbsolutePosition + root.AbsoluteSize * root.AnchorPoint - self.Gui.AbsolutePosition
    end
    local function dragPoint()
        if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch then
            return touchPoint or pointerPosition()
        end
        return pointerPosition()
    end

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input)
        if not isPress(input) or dragInput then
            return
        end
        if not self.Open or not self.Root.Visible then
            return
        end
        local point = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or pointerPosition()
        if not nearEdge(point, self.Body) or self:_overControl(point) then
            return
        end
        dragInput, touchPoint = input, point
        grabOffset = point - centre()
    end))

    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if dragInput and input == dragInput and input.UserInputType == Enum.UserInputType.Touch then
            touchPoint = Vector2.new(input.Position.X, input.Position.Y)
        end
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if not dragInput or not isPress(input) then
            return
        end
        if dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        dragInput, touchPoint = nil, nil
        target = nil
        self:_clampToScreen()
    end))

    table.insert(self._frameSteps, function(deltaTime)
        if not dragInput then
            return
        end
        target = dragPoint() - grabOffset
        local current = centre()
        local alpha = 1 - math.exp(-deltaTime * 45)
        local step = current:Lerp(target, alpha)
        self.Root.Position = UDim2.fromOffset(step.X, step.Y)
    end)
end

local function popIn(object, delay, force)
    if not object.Visible and not force then
        return
    end
    object.Visible = false
    task.delay(delay, function()
        if not object.Parent then
            return
        end
        local scaleObject = create("UIScale", { Scale = 0.94, Parent = object })
        object.Visible = true
        tween(scaleObject, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
        task.delay(0.4, function()
            scaleObject:Destroy()
        end)
    end)
end

function Window:_revealCards(tab, baseDelay)
    if tab._revealed then
        return
    end
    tab._revealed = true
    local index = 0
    for _, child in ipairs(tab.List:GetChildren()) do
        if child:IsA("GuiObject") then
            popIn(child, (baseDelay or 0) + index * 0.035)
            index += 1
        end
    end
end

function Window:_playIntro(morph)
    if self._introDone then
        return
    end
    self._introDone = true
    task.delay(1, function()
        self._autoSaveReady = true
    end)
    local root, body, shadow, scale = self.Root, self.Body, self.Shadow, self.Scale
    if self.CurrentTab then
        self:_revealCards(self.CurrentTab, morph and 0.15 or 0.25)
    end
    root.Visible = true
    if morph then
        scale.Scale = self._fitScale or 1
        root.Position = UDim2.fromScale(0.5, 0.5)
        tween(body, { GroupTransparency = 0 }, 0.3)
        tween(self.BodyStroke, { Transparency = 0 }, 0.3)
        tween(shadow, { ImageTransparency = 0.6 }, 0.3)
    else
        root.Position = UDim2.new(0.5, 0, 0.5, 24)
        tween(scale, { Scale = self._fitScale or 1 }, 0.5, Enum.EasingStyle.Back)
        tween(root, { Position = UDim2.fromScale(0.5, 0.5) }, 0.5, Enum.EasingStyle.Quint)
        tween(body, { GroupTransparency = 0 }, 0.35)
        tween(self.BodyStroke, { Transparency = 0 }, 0.35)
    end
    if not morph then
        tween(shadow, { ImageTransparency = 0.6 }, 0.5)
    end

    for index, tab in ipairs(self.Tabs) do
        popIn(tab._button, 0.1 + index * 0.05, true)
    end
    self.Indicator.Visible = false
    task.delay(0.15 + #self.Tabs * 0.05, function()
        if self.CurrentTab then
            self:_placeIndicator(self.CurrentTab)
        end
    end)
end

function Window:_showLoader(opts)
    local duration = opts.LoadingDuration or 1.6
    local gui = self.Gui
    local loader = create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 16),
        Size = UDim2.fromOffset(300, 132),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 10,
        Parent = gui,
    })
    local loaderCorner = corner(loader, UDim.new(0, 12))
    local loaderStroke = stroke(loader, Theme.Stroke, 1)
    edgeHighlight(loader)
    glow(loader, UDim2.fromOffset(320, 140), UDim2.new(1, -20, 0, -20), 0.85, 90)
    glow(loader, UDim2.fromOffset(240, 100), UDim2.new(0, 10, 1, 10), 0.9, 270)
    local loaderScale = create("UIScale", { Scale = 0.92, Parent = loader })
    local loaderShadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-25, -25),
        Size = UDim2.new(1, 50, 1, 50),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = loader,
    })

    local logoHolder = create("Frame", {
        Position = UDim2.fromOffset(24, 26),
        Size = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1,
        Parent = loader,
    })
    local logo = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.5, 0.5),
        Rotation = -14,
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Parent = logoHolder,
    })
    applyIcon(logo, opts.Icon or Assets.Logo)
    task.delay(0.15, function()
        tween(logo, { Size = UDim2.fromScale(0.85, 0.85), Rotation = 0, ImageTransparency = 0 }, 0.6, Enum.EasingStyle.Back)
    end)
    label({
        Position = UDim2.fromOffset(78, 30),
        Size = UDim2.new(1, -100, 0, 22),
        Text = opts.LoadingTitle or opts.Title or "Bloom Hub",
        TextSize = 20,
        Parent = loader,
    })
    local statusLabel = label({
        Position = UDim2.fromOffset(78, 52),
        Size = UDim2.new(1, -100, 0, 16),
        Text = opts.LoadingText or opts.Subtitle or "Loading",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = loader,
    })
    local track = create("Frame", {
        Position = UDim2.new(0, 24, 1, -30),
        Size = UDim2.new(1, -48, 0, 4),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = loader,
    })
    corner(track, UDim.new(1, 0))
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, UDim.new(1, 0))
    local sheen = create("Frame", {
        Position = UDim2.fromScale(-0.4, 0),
        Size = UDim2.fromScale(0.4, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = track,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = sheen,
    })

    tween(loader, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.4, Enum.EasingStyle.Quint)
    tween(loaderScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)
    tween(loaderShadow, { ImageTransparency = 0.6 }, 0.4)
    local sweep = TweenService:Create(sheen, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), {
        Position = UDim2.fromScale(1, 0),
    })
    sweep:Play()
    tween(fill, { Size = UDim2.fromScale(0.85, 1) }, duration * 0.8, Enum.EasingStyle.Quart)

    task.spawn(loadLucide)

    local steps = opts.LoadingSteps or { "Preparing interface", "Loading icons", "Almost there" }
    for index, text in ipairs(steps) do
        task.delay(duration * (index - 1) / #steps, function()
            if loader.Parent then
                statusLabel.Text = text
            end
        end)
    end

    task.delay(duration, function()
        tween(fill, { Size = UDim2.fromScale(1, 1) }, 0.25, Enum.EasingStyle.Quint)
        task.delay(0.25, function()
            sweep:Cancel()
            for _, item in ipairs(loader:GetChildren()) do
                if item:IsA("TextLabel") then
                    tween(item, { TextTransparency = 1 }, 0.15)
                end
            end
            for _, item in ipairs(logoHolder:GetChildren()) do
                tween(item, { ImageTransparency = 1 }, 0.15)
            end
            tween(track, { BackgroundTransparency = 1 }, 0.15)
            tween(fill, { BackgroundTransparency = 1 }, 0.15)
            tween(sheen, { BackgroundTransparency = 1 }, 0.1)

            local fit = self._fitScale or 1
            local target = self.Root.Size
            tween(loader, {
                Size = UDim2.fromOffset(target.X.Offset * fit, target.Y.Offset * fit),
                Position = UDim2.fromScale(0.5, 0.5),
            }, 0.5, Enum.EasingStyle.Quint)
            tween(loaderCorner, { CornerRadius = UDim.new(0, 10) }, 0.5, Enum.EasingStyle.Quint)
            tween(loaderScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Quint)

            task.delay(0.28, function()
                self:_playIntro(true)
                tween(loader, { GroupTransparency = 1 }, 0.25)
                tween(loaderStroke, { Transparency = 1 }, 0.2)
                tween(loaderShadow, { ImageTransparency = 1 }, 0.2)
            end)
            task.delay(0.6, function()
                loader:Destroy()
            end)
        end)
    end)
end

function Window:_fitToScreen(instant)
    local viewport = self.Gui.AbsoluteSize
    if viewport.X == 0 or viewport.Y == 0 then
        return
    end
    local size = self.Root.Size
    local scale = math.min(1, (viewport.X - 24) / math.max(size.X.Offset, 1), (viewport.Y - 24) / math.max(size.Y.Offset, 1))
    self._fitScale = math.max(scale, 0.45)
    if self._introDone and self.Open then
        if instant then
            self.Scale.Scale = self._fitScale
        else
            tween(self.Scale, { Scale = self._fitScale }, 0.2)
        end
    end
end

function Window:_clampToScreen()
    if not self.KeepOnScreen then
        return
    end
    local viewport = self.Gui.AbsoluteSize
    local root = self.Root
    local half = root.AbsoluteSize / 2
    local centre = root.AbsolutePosition + half - self.Gui.AbsolutePosition
    local clamped = Vector2.new(
        math.clamp(centre.X, math.min(half.X, viewport.X / 2), math.max(viewport.X - half.X, viewport.X / 2)),
        math.clamp(centre.Y, math.min(half.Y, viewport.Y / 2), math.max(viewport.Y - half.Y, viewport.Y / 2))
    )
    if (clamped - centre).Magnitude > 0.5 then
        tween(root, { Position = UDim2.fromOffset(clamped.X, clamped.Y) }, 0.25, Enum.EasingStyle.Quint)
    end
end

-- Floating icon that opens / closes the window: a round logo disc with a pink border. Drag it anywhere; tap to toggle.
function Window:_createOpenButton(opts)
    local gui = self.Gui
    local size = TOUCH and 60 or 54
    -- The button itself is invisible: it only takes the clicks / drags; the disc inside is the look.
    local button = create("TextButton", {
        Name = "OpenButton",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 18, 0.5, -60),
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 30,
        Parent = gui,
    })
    -- Clean disc: white face, the logo in its own colours. No halos and nothing per frame; the only movement is
    -- the input-driven hover / press scale below.
    local face = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 30,
        Parent = button,
    })
    -- Round disc with a blossom pink border.
    corner(face, UDim.new(1, 0))
    create("UIStroke", {
        Name = "Border",
        Thickness = 2.5,
        Color = Theme.Accent,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = face,
    })
    -- The logo is a square picture with its own background: it fills the disc and gets its own round corner, which
    -- crops the image itself (the disc's corner does not clip its children).
    local icon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 31,
        Parent = face,
    })
    corner(icon, UDim.new(1, 0))
    applyIcon(icon, opts.Icon or Assets.Logo)
    local buttonScale = create("UIScale", { Parent = button })
    self.OpenButton = button

    button.MouseEnter:Connect(function()
        tween(buttonScale, { Scale = 1.08 }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tween(buttonScale, { Scale = 1 }, 0.2)
    end)

    -- Drag follows only the touch (or mouse) that started it: on mobile GetMouseLocation is the LAST touch of any
    -- finger, so a second finger on the screen made the icon jump between them.
    local dragInput, moved = nil, false
    local grab = Vector2.zero
    local function pointOf(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            return Vector2.new(input.Position.X, input.Position.Y)
        end
        return pointerPosition()
    end
    button.InputBegan:Connect(function(input)
        if isPress(input) and not dragInput then
            dragInput = input
            moved = false
            grab = pointOf(input) - button.AbsolutePosition
            tween(buttonScale, { Scale = 0.92 }, 0.1)
        end
    end)
    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragInput or not isMove(input) then
            return
        end
        -- Touch: the very same InputObject as the press; mouse: any mouse movement.
        if dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        if dragInput.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local point = pointOf(input) - grab - gui.AbsolutePosition
        if (point - (button.AbsolutePosition - gui.AbsolutePosition)).Magnitude > 3 then
            moved = true
        end
        button.AnchorPoint = Vector2.new(0, 0)
        button.Position = UDim2.fromOffset(
            math.clamp(point.X, 0, math.max(gui.AbsoluteSize.X - button.AbsoluteSize.X, 0)),
            math.clamp(point.Y, 0, math.max(gui.AbsoluteSize.Y - button.AbsoluteSize.Y, 0))
        )
    end))
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if not dragInput or not isPress(input) then
            return
        end
        -- Another finger lifting does not end (or click) this drag.
        if dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        dragInput = nil
        tween(buttonScale, { Scale = 1 }, 0.15)
        if not moved then
            self:Toggle()
        end
    end))

    -- Size from the screen: a bit bigger on phones, never tiny on small screens nor huge on big ones.
    local function fit()
        local screen = gui.AbsoluteSize
        local side = math.clamp(math.floor(math.min(screen.X, screen.Y) * (TOUCH and 0.13 or 0.075)), 44, 66)
        button.Size = UDim2.fromOffset(side, side)
    end
    fit()
    table.insert(self._connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
end

function Window:_enableResize(minSize)
    local maxSize = self.MaxSize or Vector2.new(math.huge, math.huge)
    local grip = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 4, 1, 4),
        Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 20,
        Parent = self.Root,
    })
    local gripImage = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -16, 0.5, -16),
        Size = UDim2.fromOffset(96, 96),
        BackgroundTransparency = 1,
        Image = "rbxassetid://120997033468887",
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.8,
        ZIndex = 20,
        Parent = grip,
    })

    local resizing = false
    local initialSize = self.Root.Size
    local initialPointer = Vector2.zero
    local targetSize = nil

    grip.InputBegan:Connect(function(input)
        if isPress(input) then
            resizing = true
            initialSize = self.Root.Size
            initialPointer = pointerPosition()
            tween(gripImage, { ImageTransparency = 0.35 }, 0.1)
        end
    end)
    grip.MouseEnter:Connect(function()
        if not resizing then
            tween(gripImage, { ImageTransparency = 0.35 }, 0.1)
        end
    end)
    grip.MouseLeave:Connect(function()
        if not resizing then
            tween(gripImage, { ImageTransparency = 0.8 }, 0.17)
        end
    end)
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if resizing and isPress(input) then
            resizing = false
            tween(gripImage, { ImageTransparency = 0.8 }, 0.17)
            if targetSize then
                self.Root.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)
                targetSize = nil
            end
            self:_fitToScreen()
            self:_clampToScreen()
        end
    end))
    table.insert(self._frameSteps, function(deltaTime)
        if not resizing then
            return
        end
        local delta = (pointerPosition() - initialPointer) / self.Scale.Scale
        targetSize = Vector2.new(
            math.clamp(initialSize.X.Offset + delta.X * 2, minSize.X, maxSize.X),
            math.clamp(initialSize.Y.Offset + delta.Y * 2, minSize.Y, maxSize.Y)
        )
        local current = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset)
        local alpha = 1 - math.exp(-deltaTime * 35)
        local step = current:Lerp(targetSize, alpha)
        step = Vector2.new(math.floor(step.X + 0.5), math.floor(step.Y + 0.5))
        if step ~= current then
            self.Root.Size = UDim2.fromOffset(step.X, step.Y)
        end
    end)
end

local function configPath(self, name)
    return self.ConfigFolder .. "/" .. name .. ".json"
end

local function fileApiAvailable()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function ensureFolder(folder)
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
        makefolder(folder)
    end
end

local function serializeFlag(element)
    local kind = element._type
    local value = element:Get()
    if kind == "Keybind" then
        return { Type = kind, Value = value and value.Name or nil }
    elseif kind == "ColorPicker" then
        return { Type = kind, Value = { value.R, value.G, value.B } }
    end
    return { Type = kind, Value = value }
end

local function deserializeFlag(element, entry, silent)
    local kind = element._type
    local value = entry.Value
    if kind == "Keybind" then
        element:Set(value and Enum.KeyCode[value] or nil, silent)
    elseif kind == "ColorPicker" then
        if type(value) == "table" then
            element:Set(Color3.new(value[1], value[2], value[3]), silent)
        end
    elseif value ~= nil then
        element:Set(value, silent)
    end
end

function Window:SaveConfig(name)
    name = name or self.ConfigName
    if not fileApiAvailable() then
        return false, "file API unavailable"
    end
    ensureFolder(self.ConfigFolder)
    local data = {}
    for flag, element in pairs(Library.Flags) do
        if element._type and type(element.Get) == "function" then
            data[flag] = serializeFlag(element)
        end
    end
    local ok, err = pcall(function()
        writefile(configPath(self, name), HttpService:JSONEncode(data))
    end)
    if ok then
        self.ConfigName = name
    end
    return ok, err
end

function Window:LoadConfig(name, silent)
    name = name or self.ConfigName
    if not fileApiAvailable() then
        return false, "file API unavailable"
    end
    local path = configPath(self, name)
    if not isfile(path) then
        return false, "no config named " .. name
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then
        return false, "config is not valid JSON"
    end
    local previous = self._autoSaveEnabled
    self._autoSaveEnabled = false
    for flag, entry in pairs(data) do
        local element = Library.Flags[flag]
        if element and type(element.Set) == "function" and type(entry) == "table" and entry.Type == element._type then
            pcall(deserializeFlag, element, entry, silent == true)
        end
    end
    self._autoSaveEnabled = previous
    self._autoSaveReady = true
    self.ConfigName = name
    return true
end


function Window:DeleteConfig(name)
    if not fileApiAvailable() or type(delfile) ~= "function" then
        return false, "file API unavailable"
    end
    local path = configPath(self, name)
    if not isfile(path) then
        return false, "no config named " .. name
    end
    delfile(path)
    return true
end

function Window:ListConfigs()
    local names = {}
    if type(listfiles) ~= "function" or type(isfolder) ~= "function" or not isfolder(self.ConfigFolder) then
        return names
    end
    for _, path in ipairs(listfiles(self.ConfigFolder)) do
        local name = path:match("([^/\\]+)%.json$")
        if name then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function Window:_autoSave()
    if not self._autoSaveEnabled or self._destroyed or not self._autoSaveReady then
        return
    end
    if self._autoSavePending then
        return
    end
    self._autoSavePending = true
    task.delay(0.5, function()
        self._autoSavePending = false
        if not self._destroyed then
            self:SaveConfig(self.ConfigName)
        end
    end)
end

local function emptyState(parent, icon, text)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -10),
        Size = UDim2.fromOffset(200, 70),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local image = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ImageTransparency = 0.15,
        ScaleType = Enum.ScaleType.Fit,
        Parent = holder,
    })
    applyIcon(image, icon)
    local caption = label({
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 0, 16),
        Text = text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = holder,
    })
    return holder, caption, image
end

local function statRow(parent, order, icon, title)
    local card = create("Frame", {
        Size = UDim2.new(0.5, -4, 0, 62),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(card)
    stroke(card)
    card:SetAttribute("NoDrag", true)
    if icon then
        glowIcon(card, icon, Theme.Muted, UDim2.new(0, 14, 0, 21))
    end
    label({
        Position = UDim2.fromOffset(icon and 36 or 14, 12),
        Size = UDim2.new(1, -(icon and 50 or 28), 0, 16),
        Text = title,
        TextSize = 12,
        TextColor3 = Theme.Muted,
        Parent = card,
    })
    return label({
        Position = UDim2.fromOffset(14, 34),
        Size = UDim2.new(1, -28, 0, 18),
        Text = "…",
        TextSize = 15,
        Parent = card,
    })
end

local function fadeCard(card)
    local parts = {}
    local function collect(object)
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                table.insert(parts, { child, "TextTransparency", child.TextTransparency })
            elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                table.insert(parts, { child, "ImageTransparency", child.ImageTransparency })
            elseif child:IsA("UIStroke") then
                table.insert(parts, { child, "Transparency", child.Transparency })
            elseif child:IsA("Frame") then
                table.insert(parts, { child, "BackgroundTransparency", child.BackgroundTransparency })
            end
            collect(child)
        end
    end
    if card:IsA("Frame") then
        table.insert(parts, { card, "BackgroundTransparency", card.BackgroundTransparency })
    end
    collect(card)
    for _, part in ipairs(parts) do
        part[1][part[2]] = 1
        tween(part[1], { [part[2]] = part[3] }, 0.28)
    end
end

local function fadeSlideIn(group, restY)
    restY = restY or 0
    group.GroupTransparency = 1
    group.Position = UDim2.fromOffset(0, restY + 14)
    group.Visible = true
    tween(group, { GroupTransparency = 0, Position = UDim2.fromOffset(0, restY) }, 0.32, Enum.EasingStyle.Quint)
end

function Window:_buildHome(opts)
    local tab = self:Tab({
        Name = opts.Name or "Home",
        Desc = opts.Desc,
        Icon = opts.Icon or "house",
    })
    local list = tab.List

    local pages = opts.Pages or opts.Tabs
    local panels = {}
    local strip = nil
    if type(pages) == "table" and #pages > 0 then
        strip = create("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = list,
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            Parent = strip,
        })
    end

    local greeting = opts.Greeting
    if greeting == nil then
        local hour = tonumber(os.date("%H")) or 12
        local part = hour < 12 and "morning" or (hour < 18 and "afternoon" or "evening")
        greeting = "Good " .. part .. "."
    end
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = list,
    })
    header:SetAttribute("NoDrag", true)
    corner(header)
    stroke(header)
    local avatar = create("ImageLabel", {
        Position = UDim2.fromOffset(12, 11),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = header,
    })
    corner(avatar, UDim.new(0, 8))
    stroke(avatar)
    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and url then
            avatar.Image = url
        end
    end)
    label({
        Position = UDim2.fromOffset(58, 11),
        Size = UDim2.new(1, -72, 0, 18),
        Text = (opts.Welcome or "Hello, ") .. LocalPlayer.DisplayName,
        TextSize = 15,
        Parent = header,
    })
    label({
        Position = UDim2.fromOffset(58, 30),
        Size = UDim2.new(1, -72, 0, 16),
        Text = greeting,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = header,
    })

    local infoPanel = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = list,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = infoPanel,
    })

    if opts.Sections ~= false then
        local heading = create("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = infoPanel,
        })
        local headingText = label({
            Position = UDim2.fromOffset(2, 6),
            Size = UDim2.new(0, 0, 0, 16),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = string.upper(opts.SectionName or "System info"),
            TextSize = 12,
            TextColor3 = Theme.Muted,
            TextTruncate = Enum.TextTruncate.None,
            Parent = heading,
        })
        local rule = create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0, 14),
            Size = UDim2.new(1, -12, 0, 1),
            BackgroundColor3 = Theme.Stroke,
            BorderSizePixel = 0,
            Parent = heading,
        })
        local function fitRule()
            rule.Size = UDim2.new(1, -(headingText.AbsoluteSize.X + 14), 0, 1)
        end
        headingText:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRule)
        task.defer(fitRule)
    end

    local grid = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = infoPanel,
    })
    create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -4, 0, 62),
        CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = grid,
    })

    local show = opts.Stats or { "FPS", "Ping", "Executor", "Game", "Region", "Time" }
    local enabled = {}
    for _, name in ipairs(show) do
        enabled[name] = true
    end
    local order = 0
    local function add(name, icon, title)
        if not enabled[name] then
            return nil
        end
        order += 1
        return statRow(grid, order, icon, title)
    end

    local fpsValue = add("FPS", "activity", "FPS")
    local pingValue = add("Ping", "wifi", "Ping")
    local executorValue = add("Executor", "terminal", "Executor")
    local gameValue = add("Game", "gamepad-2", "Game")
    local regionValue = add("Region", "globe", "Server region")
    local timeValue = add("Time", "clock", "Time of day")
    local playersValue = add("Players", "users", "Players")
    local uptimeValue = add("Uptime", "timer", "Session")

    if executorValue then
        executorValue.Text = detectExecutor()
    end
    if gameValue then
        gameValue.Text = "Loading"
        task.spawn(function()
            gameValue.Text = detectGameName()
        end)
    end
    if regionValue then
        regionValue.Text = "Loading"
        detectRegion(function(region)
            regionValue.Text = region
        end)
    end

    local frames = 0
    local started = os.clock()
    self:_listen("Render", function()
        frames += 1
    end)
    task.spawn(function()
        while not self._destroyed and tab.List.Parent and tab._page.Parent do
            if not self.Open or self.CurrentTab ~= tab then
                frames = 0
                task.wait(1)
                continue
            end
            if fpsValue then
                fpsValue.Text = tostring(frames)
            end
            frames = 0
            if pingValue then
                local ok, ping = pcall(function()
                    return math.floor(LocalPlayer:GetNetworkPing() * 1000)
                end)
                pingValue.Text = (ok and ping or 0) .. " ms"
            end
            if timeValue then
                timeValue.Text = os.date(opts.TimeFormat or "%H:%M")
            end
            if playersValue then
                playersValue.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
            end
            if uptimeValue then
                local elapsed = math.floor(os.clock() - started)
                uptimeValue.Text = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
            end
            task.wait(1)
        end
    end)

    table.insert(panels, { Title = opts.SectionName or "Details", Icon = opts.TabIcon or "layout-grid", Frame = infoPanel })

    if strip then
        for _, page in ipairs(pages) do
            local panel = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Visible = false,
                LayoutOrder = 3,
                Parent = list,
            })
            create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
                Parent = panel,
            })
            if type(page.Content) == "string" then
                local card = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Surface2,
                    BorderSizePixel = 0,
                    LayoutOrder = 1,
                    Parent = panel,
                })
                card:SetAttribute("NoDrag", true)
                corner(card)
                stroke(card)
                padding(card, 14, 14, 12, 14)
                label({
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Text = page.Content,
                    TextSize = 13,
                    FontFace = Fonts.Regular,
                    TextColor3 = Theme.Muted,
                    TextWrapped = true,
                    TextTruncate = Enum.TextTruncate.None,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Parent = card,
                })
            end
            if type(page.Entries) == "table" then
                for index, entry in ipairs(page.Entries) do
                    local card = create("Frame", {
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundColor3 = Theme.Surface2,
                        BorderSizePixel = 0,
                        LayoutOrder = index,
                        Parent = panel,
                    })
                    card:SetAttribute("NoDrag", true)
                    corner(card)
                    stroke(card)
                    padding(card, 14, 14, 12, 14)
                    create("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 4),
                        Parent = card,
                    })
                    local head = create("Frame", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        LayoutOrder = 1,
                        Parent = card,
                    })
                    label({
                        Size = UDim2.new(1, -70, 1, 0),
                        Text = entry.Title or entry.Version or "Update",
                        TextSize = 14,
                        Parent = head,
                    })
                    if entry.Date or entry.Tag then
                        local chip = create("Frame", {
                            AnchorPoint = Vector2.new(1, 0.5),
                            Position = UDim2.new(1, 0, 0.5, 0),
                            Size = UDim2.fromOffset(0, 20),
                            AutomaticSize = Enum.AutomaticSize.X,
                            BackgroundColor3 = Theme.Surface,
                            BorderSizePixel = 0,
                            Parent = head,
                        })
                        corner(chip, UDim.new(0, 5))
                        stroke(chip)
                        padding(chip, 8, 8)
                        label({
                            Size = UDim2.new(0, 0, 1, 0),
                            AutomaticSize = Enum.AutomaticSize.X,
                            Text = entry.Tag or entry.Date,
                            TextSize = 11,
                            TextColor3 = Theme.Muted,
                            TextTruncate = Enum.TextTruncate.None,
                            Parent = chip,
                        })
                    end
                    local body = entry.Content or entry.Body
                    if type(entry.Changes) == "table" then
                        body = "• " .. table.concat(entry.Changes, "\n• ")
                    end
                    if body then
                        label({
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            Text = body,
                            TextSize = 13,
                            FontFace = Fonts.Regular,
                            TextColor3 = Theme.Muted,
                            TextWrapped = true,
                            TextTruncate = Enum.TextTruncate.None,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            LayoutOrder = 2,
                            Parent = card,
                        })
                    end
                end
            end
            if type(page.Build) == "function" then
                safeCall(page.Build, panel)
                for _, child in ipairs(panel:GetChildren()) do
                    if child:IsA("GuiObject") then
                        child:SetAttribute("NoDrag", true)
                    end
                end
            end
            table.insert(panels, { Title = page.Name or page.Title or "Page", Icon = page.Icon, Frame = panel })
        end

        local buttons = {}
        local function select(index, instant)
            local changed = self._homeIndex ~= index
            self._homeIndex = index
            header.Visible = index == 1
            if index == 1 and changed and not instant then
                fadeCard(header)
            end
            for position, entry in ipairs(panels) do
                local on = position == index
                local frame = entry.Frame
                frame.Visible = on
                if on and changed and not instant then
                    for _, child in ipairs(frame:GetChildren()) do
                        if child:IsA("GuiObject") then
                            fadeCard(child)
                        end
                    end
                end
                local button = buttons[position]
                if button then
                    tween(button.Frame, { BackgroundTransparency = on and 0 or 1 }, 0.15)
                    tween(button.Stroke, { Transparency = on and 0 or 1 }, 0.15)
                    tween(button.Label, { TextColor3 = on and Theme.Text or Theme.Muted }, 0.15)
                    if button.Icon then
                        tween(button.Icon, { ImageColor3 = on and Theme.Accent or Theme.Muted }, 0.15)
                    end
                end
            end
        end
        for index, entry in ipairs(panels) do
            local button = create("TextButton", {
                Size = UDim2.fromOffset(0, 32),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Theme.Surface2,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
                Parent = strip,
            })
            corner(button, UDim.new(0, 7))
            local buttonStroke = stroke(button, Theme.Stroke, 1)
            padding(button, 12, 12)
            local iconImage
            if entry.Icon then
                iconImage = create("ImageLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14),
                    BackgroundTransparency = 1,
                    ImageColor3 = Theme.Muted,
                    ScaleType = Enum.ScaleType.Fit,
                    Parent = button,
                })
                applyIcon(iconImage, entry.Icon)
            end
            local text = label({
                Position = UDim2.fromOffset(iconImage and 20 or 0, 0),
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Text = entry.Title,
                TextSize = 13,
                TextColor3 = Theme.Muted,
                TextTruncate = Enum.TextTruncate.None,
                Parent = button,
            })
            buttons[index] = { Frame = button, Stroke = buttonStroke, Label = text, Icon = iconImage }
            button.MouseEnter:Connect(function()
                if self._homeIndex ~= index then
                    tween(button, { BackgroundTransparency = 0.4 }, 0.12)
                    tween(buttonStroke, { Transparency = 0.5 }, 0.12)
                end
            end)
            button.MouseLeave:Connect(function()
                if self._homeIndex ~= index then
                    tween(button, { BackgroundTransparency = 1 }, 0.2)
                    tween(buttonStroke, { Transparency = 1 }, 0.2)
                end
            end)
            button.MouseButton1Click:Connect(function()
                select(index)
            end)
        end
        select(1)
    end

    tab._order = 10
    self.Home = tab
    return tab
end

function Window:Tab(opts, icon)
    opts = normalize(opts, { Title = "Name", Description = "Desc" })
    if icon ~= nil and opts.Icon == nil then
        opts.Icon = icon
    end
    local tab = setmetatable({
        Name = opts.Name or "Tab",
        Window = self,
        _order = 0,
        _sectionsExpanded = opts.SectionsExpanded,
        _rightSide = opts.Side == "Right",
    }, Tab)

    -- Side = "Right": those tabs gather in a second group at the end of the sidebar, under a small label.
    local right = opts.Side == "Right"
    self._rightTabs = self._rightTabs or 0
    if right and self._rightTabs == 0 then
        label({
            Size = UDim2.new(1, 0, 0, 22),
            Text = "MORE",
            TextSize = 11,
            TextColor3 = Theme.Muted,
            LayoutOrder = 1000,
            Parent = self.TabList,
        })
    end
    if right then
        self._rightTabs += 1
    end

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Style.Plate,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = right and 1000 + self._rightTabs or #self.Tabs + 1,
        Parent = self.TabList,
    })
    corner(button)
    local buttonStroke = outlineStroke(button, 2)
    buttonStroke.Transparency = 1
    buttonStroke:SetAttribute("RestColor", Theme.Outline)
    scaleFeedback(button, 1.03, 0.96)
    tab._button = button
    -- Selected tab: the pink button face fading in behind the label (shown by SelectTab).
    local selectedFace = create("CanvasGroup", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        ZIndex = 0,
        Parent = button,
    })
    buttonFace(selectedFace, 0)
    tab._selectedFace = selectedFace

    local hasIcon = opts.Icon ~= nil
    if hasIcon then
        local iconImage = create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Muted,
            ScaleType = Enum.ScaleType.Fit,
            Parent = button,
        })
        applyIcon(iconImage, opts.Icon)
        tab._icon = iconImage
    end
    tab._label = label({
        Position = UDim2.fromOffset(hasIcon and 36 or 14, 0),
        Size = UDim2.new(1, -(hasIcon and 44 or 22), 1, 0),
        Text = tab.Name,
        TextColor3 = Theme.Muted,
        Parent = button,
    })

    local page = create("Frame", {
        Name = tab.Name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.Content,
    })
    tab._page = page
    shinyText(label({
        Position = UDim2.fromOffset(24, 20),
        Size = UDim2.new(1, -72, 0, 24),
        Text = tab.Name,
        TextSize = 20,
        Parent = page,
    }))
    if opts.Desc then
        label({
            Position = UDim2.fromOffset(24, 44),
            Size = UDim2.new(1, -72, 0, 16),
            Text = opts.Desc,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = page,
        })
    end
    local listTop = opts.Desc and 70 or 58
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0, listTop),
        Size = UDim2.new(1, 0, 1, -listTop),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.5,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = page,
    })
    padding(list, 24, 24, 2, 24)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = list,
    })
    tab.List = list

    local empty = emptyState(page, opts.Icon or "layout-grid", opts.EmptyText or "Nothing here yet")
    local elementCount = 0
    list.ChildAdded:Connect(function(child)
        if child:IsA("GuiObject") then
            elementCount += 1
            empty.Visible = false
        end
    end)
    list.ChildRemoved:Connect(function(child)
        if child:IsA("GuiObject") then
            elementCount = math.max(elementCount - 1, 0)
            empty.Visible = elementCount <= 0
        end
    end)
    empty.Visible = true

    button.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then
            tween(button, { BackgroundTransparency = 0.4 }, 0.12)
            tween(buttonStroke, { Transparency = 0.5 }, 0.12)
        end
    end)
    button.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then
            tween(button, { BackgroundTransparency = 1 }, 0.2)
            tween(buttonStroke, { Transparency = 1 }, 0.2)
        end
    end)
    button.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)
    tab._stroke = buttonStroke

    if not self._introDone then
        button.Visible = false
    end
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        task.defer(function()
            self:SelectTab(tab)
        end)
    end
    return tab
end

Window.CreateTab = Window.Tab

function Window:Dialog(opts)
    opts = normalize(opts, { Text = "Content", Message = "Content" })
    if self._dialog then
        self._dialog.Close()
    end
    local WIDTH = 300
    local PAD = 18

    local overlay = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 40,
        Parent = self.Body,
    })
    local card = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10),
        Size = UDim2.fromOffset(WIDTH, 120),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 41,
        Parent = overlay,
    })
    corner(card, UDim.new(0, 10))
    local cardStroke = stroke(card, Theme.Stroke, 1)
    local cardScale = create("UIScale", { Scale = 0.94, Parent = card })
    local fading = {}

    local titleOffset = 0
    if opts.Icon then
        local holder, image = glowIcon(card, opts.Icon, Theme.Accent, UDim2.new(0, PAD, 0, PAD + 9))
        image.ImageTransparency = 1
        holder.ZIndex = 42
        image.ZIndex = 42
        table.insert(fading, { image, "ImageTransparency", 0 })
        titleOffset = 24
    end
    local title = label({
        Position = UDim2.fromOffset(PAD + titleOffset, PAD),
        Size = UDim2.new(1, -(PAD * 2 + titleOffset), 0, 18),
        Text = opts.Title or "Are you sure?",
        TextSize = 15,
        TextTransparency = 1,
        ZIndex = 42,
        Parent = card,
    })
    table.insert(fading, { title, "TextTransparency", 0 })

    local contentHeight = 0
    if opts.Content then
        local content = label({
            Position = UDim2.fromOffset(PAD, PAD + 24),
            Size = UDim2.new(1, -PAD * 2, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = opts.Content,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTransparency = 1,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 42,
            Parent = card,
        })
        table.insert(fading, { content, "TextTransparency", 0 })
        contentHeight = math.max(content.TextBounds.Y, 16) + 6
        content:GetPropertyChangedSignal("TextBounds"):Connect(function()
            local newHeight = math.max(content.TextBounds.Y, 16) + 6
            if newHeight ~= contentHeight then
                contentHeight = newHeight
                card.Size = UDim2.fromOffset(WIDTH, PAD + 24 + contentHeight + 12 + 34 + PAD)
                local rowFrame = card:FindFirstChild("ButtonRow")
                if rowFrame then
                    rowFrame.Position = UDim2.fromOffset(PAD, PAD + 24 + contentHeight + 12)
                end
            end
        end)
    end

    local row = create("Frame", {
        Name = "ButtonRow",
        Position = UDim2.fromOffset(PAD, PAD + 24 + contentHeight + 12),
        Size = UDim2.new(1, -PAD * 2, 0, 34),
        BackgroundTransparency = 1,
        ZIndex = 42,
        Parent = card,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = row,
    })
    card.Size = UDim2.fromOffset(WIDTH, PAD + 24 + contentHeight + 12 + 34 + PAD)

    local dialog = {}
    local closed = false
    function dialog.Close()
        if closed then
            return
        end
        closed = true
        if self._dialog == dialog then
            self._dialog = nil
        end
        tween(overlay, { BackgroundTransparency = 1 }, 0.18)
        tween(card, { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 8) }, 0.18, Enum.EasingStyle.Quint)
        tween(cardScale, { Scale = 0.96 }, 0.18, Enum.EasingStyle.Quint)
        tween(cardStroke, { Transparency = 1 }, 0.12)
        for _, entry in ipairs(fading) do
            tween(entry[1], { [entry[2]] = 1 }, 0.12)
        end
        task.delay(0.2, function()
            overlay:Destroy()
        end)
    end

    for index, spec in ipairs(opts.Buttons or {}) do
        local primary = spec.Variant == "Primary"
        local buttonFrame = create("TextButton", {
            Size = UDim2.fromOffset(0, 34),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = primary and Theme.Accent or Theme.Surface2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = index,
            ZIndex = 43,
            Parent = row,
        })
        corner(buttonFrame, UDim.new(0, 7))
        local buttonStroke = stroke(buttonFrame, primary and Theme.Accent or Theme.Stroke, 1)
        padding(buttonFrame, 14, 14)
        local text = label({
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = spec.Title or spec.Name or "OK",
            TextSize = 13,
            TextColor3 = primary and Theme.AccentDark or Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 1,
            ZIndex = 44,
            Parent = buttonFrame,
        })
        local restBg = primary and 0.12 or 0
        local restStroke = primary and 0.4 or 0
        table.insert(fading, { buttonFrame, "BackgroundTransparency", restBg })
        table.insert(fading, { buttonStroke, "Transparency", restStroke })
        table.insert(fading, { text, "TextTransparency", 0 })
        buttonFrame.MouseEnter:Connect(function()
            if closed then
                return
            end
            if primary then
                tween(buttonFrame, { BackgroundTransparency = 0 }, 0.12)
                tween(buttonStroke, { Transparency = 0 }, 0.12)
            else
                tween(buttonStroke, { Color = Theme.StrokeHover }, 0.12)
            end
        end)
        buttonFrame.MouseLeave:Connect(function()
            if closed then
                return
            end
            if primary then
                tween(buttonFrame, { BackgroundTransparency = restBg }, 0.2)
                tween(buttonStroke, { Transparency = restStroke }, 0.2)
            else
                tween(buttonStroke, { Color = Theme.Stroke }, 0.2)
            end
        end)
        buttonFrame.MouseButton1Click:Connect(function()
            dialog.Close()
            safeCall(spec.Callback)
        end)
    end

    if opts.CloseOnBackdrop ~= false then
        overlay.MouseButton1Click:Connect(function()
            dialog.Close()
            safeCall(opts.OnCancel)
        end)
    end

    self._dialog = dialog
    tween(overlay, { BackgroundTransparency = 0.45 }, 0.25)
    tween(card, { BackgroundTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.3, Enum.EasingStyle.Quint)
    tween(cardStroke, { Transparency = 0 }, 0.25)
    tween(cardScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
    for _, entry in ipairs(fading) do
        tween(entry[1], { [entry[2]] = entry[3] }, 0.25)
    end
    return dialog
end

function Window:Confirm(opts)
    opts = normalize(opts, { Text = "Content", Message = "Content" })
    return self:Dialog({
        Title = opts.Title or "Are you sure?",
        Content = opts.Content,
        Icon = opts.Icon,
        OnCancel = opts.OnCancel,
        Buttons = {
            { Title = opts.CancelText or "Cancel", Callback = opts.OnCancel },
            { Title = opts.ConfirmText or "Confirm", Variant = "Primary", Callback = opts.Callback },
        },
    })
end

function Window:_listen(kind, handler, owner)
    local list = self._inputListeners[kind]
    table.insert(list, handler)
    local function disconnect()
        for index, entry in ipairs(list) do
            if entry == handler then
                table.remove(list, index)
                break
            end
        end
    end
    if owner then
        owner._listeners = owner._listeners or {}
        table.insert(owner._listeners, disconnect)
    end
    return disconnect
end

function Window:_indicatorY(tab)
    local list = self.TabList
    local scale = self.Scale.Scale
    return (tab._button.AbsolutePosition.Y - list.AbsolutePosition.Y + tab._button.AbsoluteSize.Y / 2) / scale
        + list.Position.Y.Offset
end

function Window:_placeIndicator(tab)
    local indicator = self.Indicator
    local targetY = self:_indicatorY(tab)
    if not indicator.Visible then
        indicator.Visible = true
        indicator.Position = UDim2.fromOffset(6, targetY)
        indicator.Size = UDim2.fromOffset(3, 0)
    end
    tween(indicator, { Position = UDim2.fromOffset(6, targetY), Size = UDim2.fromOffset(3, 18) }, 0.35, Enum.EasingStyle.Back)
end

function Window:SelectTab(tab)
    if self.CurrentTab == tab then
        return
    end
    local previous = self.CurrentTab
    self.CurrentTab = tab

    self:_settleTransition()
    local generation = (self._transitionGeneration or 0) + 1
    self._transitionGeneration = generation

    if previous then
        tween(previous._button, { BackgroundTransparency = 1 }, 0.2)
        tween(previous._stroke, { Transparency = 1 }, 0.2)
        tween(previous._label, { TextColor3 = Theme.Muted }, 0.2)
        if previous._selectedFace then
            tween(previous._selectedFace, { GroupTransparency = 1 }, 0.2)
        end
        if previous._icon then
            tween(previous._icon, { ImageColor3 = Theme.Muted }, 0.2)
        end
        local outLayer = self._outLayer
        previous._page.Parent = outLayer
        self._outPage = previous._page
        outLayer.GroupTransparency = 0
        outLayer.Position = UDim2.fromOffset(0, 0)
        outLayer.Visible = true
        tween(outLayer, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -10) }, 0.18)
        task.delay(0.18, function()
            if self._transitionGeneration == generation then
                self:_settleOut()
            end
        end)
    end

    -- The button face is the selected look, so the plate itself stays clear.
    tween(tab._button, { BackgroundTransparency = 1 }, 0.2)
    tween(tab._stroke, { Transparency = 1 }, 0.2)
    tween(tab._label, { TextColor3 = Color3.new(1, 1, 1) }, 0.2)
    if tab._selectedFace then
        tween(tab._selectedFace, { GroupTransparency = 0 }, 0.2)
    end
    if tab._icon then
        tween(tab._icon, { ImageColor3 = Color3.new(1, 1, 1) }, 0.2)
    end

    self:_placeIndicator(tab)

    local page = tab._page
    page.Position = UDim2.fromOffset(0, 0)
    page.Visible = true
    page.Parent = self._inLayer
    self._inPage = page
    fadeSlideIn(self._inLayer)
    task.delay(0.32, function()
        if self._transitionGeneration == generation then
            self:_settleIn()
        end
    end)
end

function Window:_settleOut()
    local page = self._outPage
    if page then
        page.Parent = self.Content
        page.Visible = false
        self._outPage = nil
    end
    self._outLayer.Visible = false
end

function Window:_settleIn()
    local page = self._inPage
    if page then
        page.Parent = self.Content
        page.Position = UDim2.fromOffset(0, 0)
        self._inPage = nil
    end
    self._inLayer.Visible = false
end

function Window:_settleTransition()
    self:_settleOut()
    self:_settleIn()
end

function Window:Toggle(open)
    if not self._introDone then
        return
    end
    if open == nil then
        open = not self.Open
    end
    if open == self.Open then
        return
    end
    self.Open = open
    if open then
        self.Root.Visible = true
        tween(self.Scale, { Scale = self._fitScale or 1 }, 0.4, Enum.EasingStyle.Back)
        tween(self.Body, { GroupTransparency = 0 }, 0.25)
        tween(self.BodyStroke, { Transparency = 0 }, 0.25)
        tween(self.Shadow, { ImageTransparency = 0.6 }, 0.3)
    else

        tween(self.Scale, { Scale = (self._fitScale or 1) * 0.94 }, 0.2, Enum.EasingStyle.Quint)
        tween(self.Body, { GroupTransparency = 1 }, 0.16)
        tween(self.BodyStroke, { Transparency = 1 }, 0.12)
        tween(self.Shadow, { ImageTransparency = 1 }, 0.16)
        task.delay(0.2, function()
            if not self.Open then
                self.Root.Visible = false
            end
        end)
    end
end

function Window:SetKeepOnScreen(enabled)
    self.KeepOnScreen = enabled ~= false
    if self.KeepOnScreen then
        self:_clampToScreen()
    end
end

function Window:SetKeybind(keyCode)
    self.Keybind = keyCode
    self._keyChipLabel.Text = keyName(keyCode)
end

function Window:Notify(opts)
    opts = normalize(opts, { Text = "Content", Message = "Content", Image = "Icon" })
    local duration = opts.Duration or 4
    local titleColor = NOTIFY_COLORS[opts.Type] or Theme.Text

    self._notifyOrder = self._notifyOrder + 1
    local outer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = self._notifyOrder,
        Parent = self.NotifyHolder,
    })
    local slide = create("Frame", {
        Position = UDim2.fromOffset(320, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = outer,
    })
    local shadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-20, -20),
        Size = UDim2.new(1, 40, 1, 40),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = slide,
    })
    local toast = create("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = slide,
    })
    corner(toast, UDim.new(0, 10))
    local toastStroke = stroke(toast, Theme.Stroke)
    edgeHighlight(toast)
    glow(toast, UDim2.fromOffset(260, 120), UDim2.new(1, -10, 0, -10), 0.86, 90)

    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = toast,
    })
    padding(inner, 12, 12, 10, 18)

    local titleOffset = 0
    if opts.Icon then
        glowIcon(inner, opts.Icon, titleColor == Theme.Text and Theme.Accent or titleColor, UDim2.new(0, 0, 0, 7))
        titleOffset = 20
    end
    label({
        Position = UDim2.fromOffset(titleOffset, 0),
        Size = UDim2.new(1, -24 - titleOffset, 0, 14),
        Text = opts.Title or "Notification",
        TextSize = 12,
        TextColor3 = titleColor,
        Parent = inner,
    })
    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 5, 0, -4),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 17,
        FontFace = Fonts.Bold,
        AutoButtonColor = false,
        Parent = inner,
    })
    closeButton.MouseEnter:Connect(function()
        tween(closeButton, { TextColor3 = Theme.Text }, 0.15)
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, { TextColor3 = Theme.Muted }, 0.2)
    end)
    if opts.Content then
        label({
            Position = UDim2.fromOffset(titleOffset, 17),
            Size = UDim2.new(1, -titleOffset, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = opts.Content,
            TextSize = 11,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = inner,
        })
    end

    local track = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 12, 1, -6),
        Size = UDim2.new(1, -24, 0, 2),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = toast,
    })
    corner(track, UDim.new(1, 0))
    local progress = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(progress, UDim.new(1, 0))

    task.defer(function()
        if outer.Parent then
            tween(outer, { Size = UDim2.new(1, 0, 0, toast.AbsoluteSize.Y) }, 0.3, Enum.EasingStyle.Quint)
        end
    end)
    tween(slide, { Position = UDim2.fromOffset(0, 0) }, 0.5, Enum.EasingStyle.Back)
    tween(toast, { GroupTransparency = 0 }, 0.3)
    tween(shadow, { ImageTransparency = 0.6 }, 0.4)
    tween(progress, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

    local dismissed = false
    local function dismiss()
        if dismissed then
            return
        end
        dismissed = true
        for index, entry in ipairs(self._toasts) do
            if entry == dismiss then
                table.remove(self._toasts, index)
                break
            end
        end
        tween(slide, { Position = UDim2.fromOffset(320, 0) }, 0.3, Enum.EasingStyle.Quint)
        tween(toast, { GroupTransparency = 1 }, 0.2)
        tween(toastStroke, { Transparency = 1 }, 0.15)
        tween(shadow, { ImageTransparency = 1 }, 0.2)
        task.delay(0.22, function()
            outer.ClipsDescendants = true
            tween(outer, { Size = UDim2.new(1, 0, 0, -4) }, 0.22, Enum.EasingStyle.Quint)
            task.delay(0.24, function()
                outer:Destroy()
            end)
        end)
    end

    task.delay(duration, dismiss)
    closeButton.MouseButton1Click:Connect(dismiss)

    table.insert(self._toasts, dismiss)
    while #self._toasts > self.MaxNotifications do
        local oldest = table.remove(self._toasts, 1)
        oldest()
    end

    return { Dismiss = dismiss }
end

function Window:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    for index, entry in ipairs(Library.Windows) do
        if entry == self then
            table.remove(Library.Windows, index)
            break
        end
    end
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    self._connections = {}
    tween(self.Scale, { Scale = 0.9 }, 0.2)
    tween(self.Body, { GroupTransparency = 1 }, 0.2)
    tween(self.BodyStroke, { Transparency = 1 }, 0.12)
    tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
    task.delay(0.22, function()
        self.Gui:Destroy()
    end)
end

-- Bloom compatibility layer. The hub groups controls in sections and
-- uses Add* names, while the original library exposes controls directly on tabs.
local function compatibilityOptions(idOrOptions, options)
    local id
    local result = {}
    if type(idOrOptions) == "table" then
        options = idOrOptions
    else
        id = idOrOptions
    end
    for key, value in pairs(type(options) == "table" and options or {}) do
        result[key] = value
    end
    result.Name = result.Name or result.Text or (id ~= nil and tostring(id)) or nil
    result.Flag = result.Flag or (id ~= nil and tostring(id)) or nil
    return result
end

local function addSetValueAlias(handle)
    handle.SetValue = function(first, second)
        local value = first == handle and second or first
        return handle:Set(value)
    end
    return handle
end

-- Collapsible section: a header plate with shiny text and an accent chevron, the rows below it. text may be
-- a string or { Name, Expanded }; Expanded defaults to the tab's SectionsExpanded (true when unset).
function Tab:AddSection(text)
    local expanded = self._sectionsExpanded ~= false
    if type(text) == "table" then
        if text.Expanded ~= nil then
            expanded = text.Expanded ~= false
        end
        text = text.Name or text.Title or text.Text or ""
    end

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = holder,
    })

    local heading = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Style.Plate,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1,
        Parent = holder,
    })
    heading:SetAttribute("NoDrag", true)
    corner(heading)
    outlineStroke(heading, 2.5)
    scaleFeedback(heading, 1.01, 0.98)
    local headingText = label({
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -48, 1, 0),
        Text = string.upper(tostring(text or "")),
        TextSize = 14,
        Parent = heading,
    })
    shinyText(headingText)
    local chevron = create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ImageColor3 = Style.AccentColor,
        ScaleType = Enum.ScaleType.Fit,
        Parent = heading,
    })
    applyIcon(chevron, "chevron-down")

    local sectionList = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Visible = expanded,
        Parent = holder,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = sectionList,
    })

    local section = setmetatable({
        Name = tostring(text or ""),
        Window = self.Window,
        List = sectionList,
        Expanded = expanded,
        _order = 0,
        _sectionHolder = holder,
    }, Tab)

    local function render(animate)
        sectionList.Visible = section.Expanded
        tween(chevron, { Rotation = section.Expanded and 0 or -90 }, animate and 0.2 or 0)
    end
    function section:SetExpanded(value)
        section.Expanded = value ~= false
        render(true)
        if self.Window then
            self.Window._controlsDirty = true
        end
    end
    function section:SetTitle(value)
        headingText.Text = string.upper(tostring(value or ""))
    end
    heading.MouseButton1Click:Connect(function()
        section:SetExpanded(not section.Expanded)
    end)
    render(false)
    return section
end

local function compactNumber(value)
    value = tonumber(value) or 0
    local suffixes = {
        { 1e12, "T" },
        { 1e9, "B" },
        { 1e6, "M" },
        { 1e3, "K" },
    }
    for _, entry in ipairs(suffixes) do
        if math.abs(value) >= entry[1] then
            local scaled = value / entry[1]
            local formatted = scaled >= 100 and string.format("%.0f", scaled)
                or scaled >= 10 and string.format("%.1f", scaled)
                or string.format("%.2f", scaled)
            if string.find(formatted, ".", 1, true) then
                formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
            end
            return formatted .. entry[2]
        end
    end
    return tostring(math.floor(value + 0.5))
end

local function imageAsset(value)
    if type(value) == "number" then
        return "rbxassetid://" .. tostring(value)
    end
    return type(value) == "string" and value or ""
end

local function mountAssetPreview(viewport, item)
    local previewHolder = viewport.Parent
    if typeof(item.Model) ~= "Instance" then
        viewport:Destroy()
        local image = create("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Image = imageAsset(item.Icon),
            ScaleType = Enum.ScaleType.Fit,
            Parent = previewHolder,
        })
        return image
    end

    local ok = pcall(function()
        local camera = Instance.new("Camera")
        camera.FieldOfView = 35
        camera.Parent = viewport
        viewport.CurrentCamera = camera

        local world = Instance.new("WorldModel")
        world.Parent = viewport
        local clone = item.Model:Clone()
        clone.Parent = world
        for _, descendant in ipairs(clone:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanQuery = false
                descendant.CanTouch = false
            end
        end

        local center
        local size
        if clone:IsA("Model") then
            clone:PivotTo(CFrame.new())
            local bounds
            bounds, size = clone:GetBoundingBox()
            center = bounds.Position
        elseif clone:IsA("BasePart") then
            clone.CFrame = CFrame.new()
            center = clone.Position
            size = clone.Size
        else
            error("unsupported preview object")
        end
        local distance = math.max(size.X, size.Y, size.Z) * 1.65 + 2
        camera.CFrame = CFrame.lookAt(
            center + Vector3.new(distance * 0.65, distance * 0.28, distance),
            center
        )
    end)
    if not ok then
        viewport:Destroy()
        return create("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Image = imageAsset(item.Icon),
            ScaleType = Enum.ScaleType.Fit,
            Parent = previewHolder,
        })
    end
    return viewport
end

function Tab:AssetFilter(opts)
    opts = normalize(opts, {})
    local items = opts.Items or {}
    local selected = opts.Selected or {}
    local rows = {}
    local height = TOUCH and 410 or 380
    local frame, frameStroke = card(self, "Frame", height, opts)
    hoverStroke(frame, frameStroke)
    frame.ClipsDescendants = true

    label({
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -150, 0, 20),
        Text = opts.Name or opts.Text or "Animal Filter",
        TextSize = 14,
        Parent = frame,
    })
    local summary = label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 11),
        Size = UDim2.fromOffset(124, 18),
        Text = "",
        TextSize = 12,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = frame,
    })
    summary.Visible = opts.ReadOnly ~= true

    local searchHolder = create("Frame", {
        Position = UDim2.fromOffset(14, 38),
        Size = UDim2.new(1, -28, 0, TOUCH and 38 or 34),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(searchHolder, UDim.new(0, 6))
    local searchStroke = stroke(searchHolder, Theme.Stroke)
    local search = create("TextBox", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = opts.Placeholder or "Search animals...",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = searchHolder,
    })
    search.Focused:Connect(function()
        tween(searchStroke, { Color = Theme.StrokeHover }, 0.15)
    end)
    search.FocusLost:Connect(function()
        tween(searchStroke, { Color = Theme.Stroke }, 0.15)
    end)

    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(14, TOUCH and 84 or 80),
        Size = UDim2.new(1, -28, 1, TOUCH and -98 or -94),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.35,
        CanvasSize = UDim2.new(),
        Parent = frame,
    })
    -- Virtualized list: rows are positioned by hand (no UIListLayout) and only the ones near the viewport
    -- are Visible, so opening the tab lays out and measures a screenful of cards instead of hundreds.
    local ROW_HEIGHT = TOUCH and 74 or 68
    local ROW_STRIDE = ROW_HEIGHT + 6

    local function updateSummary()
        local count = 0
        for _, item in ipairs(items) do
            local id = item.Id or item.Name
            if selected[id] == true then
                count += 1
            end
        end
        summary.Text = tostring(count) .. " selected"
    end

    local function renderRow(row)
        local enabled = selected[row.Id] == true
        local selectedColor = opts.SelectedColor or Theme.Accent
        local blockedColor = opts.BlockedColor or Theme.Surface3
        row.State.Text = enabled and (opts.SelectedText or "Selected") or (opts.BlockedText or "Blocked")
        row.State.TextColor3 = enabled and (opts.SelectedTextColor or Theme.AccentDark) or (opts.BlockedTextColor or Theme.Text)
        row.State.BackgroundColor3 = enabled and selectedColor or blockedColor
        row.Stroke.Color = enabled and selectedColor or blockedColor
        row.Stroke.Transparency = enabled and 0.25 or 0
    end

    local refreshVisible

    -- Stacks the rows matching the search and sizes the canvas; visibility is left to refreshVisible.
    local function layoutRows()
        local query = string.lower(search.Text)
        local y = 0
        for _, row in ipairs(rows) do
            row.Match = query == "" or string.find(row.SearchText, query, 1, true) ~= nil
            if row.Match then
                row.Y = y
                row.Frame.Position = UDim2.fromOffset(0, y)
                y += ROW_STRIDE
            end
        end
        list.CanvasSize = UDim2.fromOffset(0, y)
        refreshVisible()
    end

    local function applySearch()
        list.CanvasPosition = Vector2.zero
        layoutRows()
    end

    local function clearRows()
        for _, row in ipairs(rows) do
            row.Frame:Destroy()
        end
        table.clear(rows)
    end

    -- Only rows inside (or one screen around) the scroll viewport get their icon and text effects.
    -- Icons stay once loaded; effects toggle off again when a row scrolls away.
    local visibleQueued = false
    function refreshVisible()
        visibleQueued = false
        local height = list.AbsoluteSize.Y
        local scroll = list.CanvasPosition.Y
        -- Not laid out yet (no size): nothing is shown until it has one.
        local open = height > 0 and list.Visible
        for _, row in ipairs(rows) do
            local near = open and row.Match and row.Y + ROW_STRIDE > scroll - height and row.Y < scroll + height * 2
            if row.Frame.Visible ~= near then
                row.Frame.Visible = near
            end
            if near and row.IconLabel.Image == "" then
                row.IconLabel.Image = row.IconAsset
            end
            if near ~= row.Shown then
                row.Shown = near
                for _, effect in ipairs(row.Effects) do
                    effect.Enabled = near
                end
            end
        end
    end
    local function queueVisible()
        if not visibleQueued then
            visibleQueued = true
            task.defer(refreshVisible)
        end
    end
    list:GetPropertyChangedSignal("CanvasPosition"):Connect(queueVisible)
    list:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueVisible)
    list:GetPropertyChangedSignal("AbsolutePosition"):Connect(queueVisible)

    -- Rows are built in small batches across frames (a big list built in one frame froze the client);
    -- a newer build cancels an older one still in progress.
    local buildToken = 0
    local ROWS_PER_FRAME = 16
    local function buildRows()
        clearRows()
        buildToken += 1
        local token = buildToken
        updateSummary()
        task.spawn(function()
        for index, item in ipairs(items) do
            if token ~= buildToken then return end
            local id = item.Id or item.Name or tostring(index)
            local rowFrame = create("TextButton", {
                Size = UDim2.new(1, -4, 0, ROW_HEIGHT),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                Visible = false,
                Parent = list,
            })
            corner(rowFrame, UDim.new(0, 6))
            local rowStroke = stroke(rowFrame, Theme.Stroke)

            create("Frame", {
                Size = UDim2.fromOffset(3, TOUCH and 74 or 68),
                BackgroundColor3 = typeof(item.RarityColor) == "Color3" and item.RarityColor or Theme.Accent,
                BorderSizePixel = 0,
                Parent = rowFrame,
            })
            local previewHolder = create("Frame", {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.fromOffset(TOUCH and 62 or 56, TOUCH and 62 or 56),
                BackgroundColor3 = Theme.Surface2,
                BorderSizePixel = 0,
                Parent = rowFrame,
            })
            corner(previewHolder, UDim.new(0, 6))
            -- Icon is assigned lazily by refreshVisible (only rows on / near screen download textures).
            local iconLabel = create("ImageLabel", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Image = "",
                ScaleType = Enum.ScaleType.Fit,
                Parent = previewHolder,
            })

            local textLeft = TOUCH and 82 or 76
            local nameLabel = label({
                Position = UDim2.fromOffset(textLeft, 12),
                Size = UDim2.new(1, -(textLeft + 98), 0, 20),
                Text = tostring(item.Name or id),
                TextSize = item.NameTextSize or 14,
                FontFace = typeof(item.NameFontFace) == "Font" and item.NameFontFace or Fonts.Medium,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = rowFrame,
            })
            local detailLabel = label({
                Position = UDim2.fromOffset(textLeft, 34),
                Size = UDim2.new(1, -(textLeft + 98), 0, 18),
                Text = item.Details or ("Gen: " .. compactNumber(item.Gen)),
                TextSize = item.DetailTextSize or 12,
                FontFace = typeof(item.DetailFontFace) == "Font" and item.DetailFontFace or Fonts.Regular,
                TextColor3 = typeof(item.RarityColor) == "Color3" and item.RarityColor or Theme.Muted,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = rowFrame,
            })
            -- Optional per-item text styling (e.g. a game's rarity look): a UIGradient and/or UIStroke to copy
            -- onto the label. Gradients tint the text color, so the label goes white to show them true.
            -- Copies start disabled; refreshVisible only turns them on for rows on screen.
            local effects = {}
            local function styleText(target, gradient, strokeSource)
                if typeof(gradient) == "Instance" and gradient:IsA("UIGradient") then
                    local copy = gradient:Clone()
                    copy.Enabled = false
                    copy.Parent = target
                    target.TextColor3 = Color3.new(1, 1, 1)
                    table.insert(effects, copy)
                end
                if typeof(strokeSource) == "Instance" and strokeSource:IsA("UIStroke") then
                    local copy = strokeSource:Clone()
                    copy.Enabled = false
                    copy.Parent = target
                    table.insert(effects, copy)
                end
            end
            pcall(styleText, nameLabel, item.NameGradient, item.NameStroke)
            pcall(styleText, detailLabel, item.DetailGradient, item.DetailStroke)
            local state = create("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(82, TOUCH and 30 or 26),
                BackgroundColor3 = Theme.Surface3,
                BorderSizePixel = 0,
                Text = "",
                TextSize = 11,
                TextColor3 = Theme.Muted,
                FontFace = Fonts.Medium,
                Parent = rowFrame,
            })
            corner(state, UDim.new(0, 6))
            state.Visible = opts.ReadOnly ~= true

            local row = {
                Id = id,
                Frame = rowFrame,
                State = state,
                Stroke = rowStroke,
                IconLabel = iconLabel,
                IconAsset = imageAsset(item.Icon),
                Effects = effects,
                Shown = false,
                Match = false,
                Y = 0,
                SearchText = string.lower(tostring(item.Name or id) .. " " .. tostring(id)),
            }
            table.insert(rows, row)
            renderRow(row)
            rowFrame.MouseButton1Click:Connect(function()
                if opts.ReadOnly == true then return end
                selected[id] = selected[id] ~= true
                renderRow(row)
                updateSummary()
                safeCall(opts.Callback, id, selected[id])
            end)
            if index % ROWS_PER_FRAME == 0 then
                layoutRows()
                task.wait()
            end
        end
        if token == buildToken then
            updateSummary()
            layoutRows()
        end
        end)
    end

    search:GetPropertyChangedSignal("Text"):Connect(applySearch)
    buildRows()
    return finishElement(self, opts, {
        Add = function(_, item)
            if type(item) ~= "table" then return end
            table.insert(items, 1, item)
            buildRows()
        end,
        Refresh = function(_, newItems)
            items = type(newItems) == "table" and newItems or {}
            buildRows()
        end,
        -- Re-paints the existing rows from the Selected table (bulk select/clear) without rebuilding them.
        Render = function()
            for _, row in ipairs(rows) do
                renderRow(row)
            end
            updateSummary()
        end,
        Get = function()
            return selected
        end,
    }, frame, "AssetFilter")
end

function Tab:AddButton(options)
    return self:Button(compatibilityOptions(options))
end

function Tab:AddToggle(idOrOptions, options)
    local handle = self:Toggle(compatibilityOptions(idOrOptions, options))
    addSetValueAlias(handle)
    handle.SetStage = function(value)
        handle:Set(value)
    end
    return handle
end

function Tab:AddSlider(idOrOptions, options)
    return addSetValueAlias(self:Slider(compatibilityOptions(idOrOptions, options)))
end

function Tab:AddInput(idOrOptions, options)
    return addSetValueAlias(self:Input(compatibilityOptions(idOrOptions, options)))
end

local function selectionArray(value)
    local result = {}
    if type(value) ~= "table" then
        if value ~= nil then result[1] = value end
        return result
    end
    for key, selectedValue in pairs(value) do
        if type(key) == "number" then
            result[#result + 1] = selectedValue
        elseif selectedValue == true then
            result[#result + 1] = key
        end
    end
    return result
end

local function selectionMap(value)
    local result = {}
    for _, entry in ipairs(selectionArray(value)) do
        result[entry] = true
    end
    return result
end

function Tab:AddDropdown(idOrOptions, options)
    local config = compatibilityOptions(idOrOptions, options)
    local callback = config.Callback
    local multi = config.Multi == true or config.MultipleOptions == true
    local previous = selectionMap(config.Default or config.CurrentOption)
    if multi then
        config.Default = selectionArray(config.Default or config.CurrentOption)
        config.Callback = function(values)
            local current = selectionMap(values)
            local keys = {}
            for key in pairs(previous) do keys[key] = true end
            for key in pairs(current) do keys[key] = true end
            for key in pairs(keys) do
                if previous[key] ~= current[key] then
                    safeCall(callback, key, current[key] == true)
                end
            end
            previous = current
        end
    end

    local handle = self:Dropdown(config)
    addSetValueAlias(handle)
    handle.GetNewList = function(first, second)
        local value = first == handle and second or first
        if multi then
            previous = selectionMap(value)
            handle:Set(selectionArray(value), true)
        else
            handle:Set(value, true)
        end
    end
    handle.SetValues = function(first, second)
        local values = first == handle and second or first
        handle:Refresh(type(values) == "table" and values or {}, true)
    end
    return handle
end

function Tab:AddAssetFilter(options)
    return self:AssetFilter(options)
end

function Tab:AddAssetLogItem(item)
    item = type(item) == "table" and item or {}
    local height = TOUCH and 84 or 80
    local row, rowStroke = card(self, "Frame", height, {})
    row.ClipsDescendants = true
    rowStroke.Color = typeof(item.RarityColor) == "Color3" and item.RarityColor or Theme.Stroke

    -- Mini gradient: a soft rarity tint on the left fading into the card color (background only, not the text).
    if typeof(item.RarityColor) == "Color3" then
        row.BackgroundColor3 = Color3.new(1, 1, 1)
        -- Only one gradient can paint the card: the rarity tint replaces the default gloss.
        local gloss = row:FindFirstChild("Gloss")
        if gloss then
            gloss:Destroy()
        end
        create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Theme.Surface2:Lerp(item.RarityColor, 0.28)),
                ColorSequenceKeypoint.new(0.45, Theme.Surface2:Lerp(item.RarityColor, 0.08)),
                ColorSequenceKeypoint.new(1, Theme.Surface2),
            }),
            Parent = row,
        })
    end

    local previewHolder = create("Frame", {
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromOffset(TOUCH and 70 or 64, TOUCH and 70 or 64),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(previewHolder, UDim.new(0, 6))
    create("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = imageAsset(item.Icon),
        ScaleType = Enum.ScaleType.Fit,
        Parent = previewHolder,
    })
    -- Optional egg icon badge in the preview's corner (animal + the egg it came from).
    if item.EggIcon then
        create("ImageLabel", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, 4, 1, 4),
            Size = UDim2.fromOffset(TOUCH and 28 or 26, TOUCH and 28 or 26),
            BackgroundTransparency = 1,
            Image = imageAsset(item.EggIcon),
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 2,
            Parent = previewHolder,
        })
    end

    local textLeft = TOUCH and 90 or 84
    local nameLabel = label({
        Position = UDim2.fromOffset(textLeft, 10),
        Size = UDim2.new(1, -(textLeft + 96), 0, 20),
        Text = tostring(item.Name or "Unknown"),
        TextSize = item.NameTextSize or 15,
        FontFace = typeof(item.NameFontFace) == "Font" and item.NameFontFace or Fonts.Medium,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    -- Detail line: rarity (+ mutations) in the rarity color, like the Farm Config cards.
    local detailLabel = label({
        Position = UDim2.fromOffset(textLeft, 33),
        Size = UDim2.new(1, -(textLeft + 14), 0, 18),
        Text = tostring(item.Details or item.Rarity or "Unknown"),
        TextSize = item.DetailTextSize or 12,
        FontFace = typeof(item.DetailFontFace) == "Font" and item.DetailFontFace or Fonts.Bold,
        TextColor3 = typeof(item.RarityColor) == "Color3" and item.RarityColor or Theme.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    -- Stats line (rich text): gen / weight / anything the caller formats.
    label({
        Position = UDim2.fromOffset(textLeft, 55),
        Size = UDim2.new(1, -(textLeft + 14), 0, 18),
        Text = type(item.Stats) == "string" and item.Stats ~= "" and item.Stats
            or ('<font color="#5AFF82">$%s/s</font>   <font color="#FFD764">%s kg</font>'):format(compactNumber(item.Gen), tostring(item.Weight or "0.00")),
        RichText = true,
        TextSize = 12,
        FontFace = typeof(item.DetailFontFace) == "Font" and item.DetailFontFace or Fonts.Bold,
        TextColor3 = Theme.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local function styleText(target, gradient, strokeSource)
        if typeof(gradient) == "Instance" and gradient:IsA("UIGradient") then
            gradient:Clone().Parent = target
            target.TextColor3 = Color3.new(1, 1, 1)
        end
        if typeof(strokeSource) == "Instance" and strokeSource:IsA("UIStroke") then
            strokeSource:Clone().Parent = target
        end
    end
    pcall(styleText, nameLabel, item.NameGradient, item.NameStroke)
    pcall(styleText, detailLabel, item.DetailGradient, item.DetailStroke)

    -- Top-right chip: time / source text (defaults to the rarity name).
    local chip = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 10),
        Size = UDim2.fromOffset(82, 22),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Text = tostring(item.Chip or item.Rarity or ""),
        TextSize = 11,
        TextColor3 = Theme.Text,
        FontFace = Fonts.Bold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    corner(chip, UDim.new(0, 6))
    return finishElement(self, {}, {}, row, "AssetLogItem")
end

Window.AddTab = Window.Tab
-- Create* names: CreateSection is the collapsible section ({ Name, Expanded }), CreateText a titled note.
Tab.CreateSection = Tab.AddSection
Tab.CreateLabel = Tab.Label
Tab.CreateParagraph = Tab.Paragraph
Tab.CreateDivider = Tab.Divider
function Tab:CreateText(opts)
    opts = type(opts) == "table" and opts or { Text = tostring(opts or "") }
    return self:Paragraph({ Name = opts.Name or opts.Title or "", Content = opts.Text or opts.Content or "" })
end
Tab.CreateButton = Tab.Button
Tab.CreateToggle = Tab.Toggle
Tab.CreateSlider = Tab.Slider
Tab.CreateDropdown = Tab.Dropdown
Tab.CreateInput = Tab.Input
Tab.CreateKeybind = Tab.Keybind
Tab.CreateColorPicker = Tab.ColorPicker
Tab.CreateStepper = Tab.Stepper
Tab.CreateProgress = Tab.Progress
Tab.CreateConfigManager = Tab.ConfigManager

function Library:Notification(opts)
    return self:Notify(opts)
end

-- Bloom HUD templates: Status (what the hub is doing) and Steal (things to take). The library only draws them; the
-- hub pushes its data with status:Set(info) and steal:SetItems(items). Both sit in their own ScreenGui, scale with
-- the screen (designed at 1280x720), can be dragged by their header and share the look of the window.
local Hud = {
    StateColors = {
        active = { Color3.fromRGB(58, 255, 55), Color3.fromRGB(20, 140, 30) },
        waiting = { Color3.fromRGB(255, 214, 84), Color3.fromRGB(230, 140, 20) },
        idle = { Color3.fromRGB(170, 174, 184), Color3.fromRGB(90, 94, 110) },
    },
    StateWords = { active = "WORKING", waiting = "WAITING", idle = "IDLE" },
    Red = { Color3.fromRGB(255, 132, 123), Color3.fromRGB(239, 28, 28) },
    Green = { Color3.fromRGB(58, 255, 55), Color3.fromRGB(20, 109, 0) },
    Grey = { Color3.fromRGB(218, 204, 222), Color3.fromRGB(122, 100, 130) },
    Bloom = { Color3.fromRGB(255, 150, 205), Color3.fromRGB(214, 52, 136) },
    Sky = { Color3.fromRGB(130, 228, 255), Color3.fromRGB(18, 156, 255) },
    Lilac = { Color3.fromRGB(206, 170, 255), Color3.fromRGB(130, 76, 220) },
    Gold = { Color3.fromRGB(255, 214, 84), Color3.fromRGB(255, 150, 20) },
}
Library.Hud = Hud
Library.Screens = Library.Screens or {}

-- The game's own UI text style: the FontFace (family, weight, italic) most used by the visible text in PlayerGui,
-- weighted by text size. Headings, element names and pills (Fonts.Title / Heavy) take it; opts.Body = true moves the
-- body text to the same family too. Works before CreateWindow (or with CreateWindow{ GameFont = true }) and after
-- it: text already on screen is restyled. Returns the font, or nil when the game shows no text yet.
function Library:UseGameFont(opts)
    opts = type(opts) == "table" and opts or {}
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end
    local scores, faces = {}, {}
    for _, object in playerGui:GetDescendants() do
        if not (object:IsA("TextLabel") or object:IsA("TextButton")) then
            continue
        end
        local screen = object:FindFirstAncestorOfClass("ScreenGui")
        if not screen or screen:GetAttribute("BloomUI") or not screen.Enabled or object.Text == "" then
            continue
        end
        local ok, face = pcall(function()
            return object.FontFace
        end)
        if ok and typeof(face) == "Font" then
            local key = face.Family .. "|" .. face.Weight.Name .. "|" .. face.Style.Name
            scores[key] = (scores[key] or 0) + (object.TextScaled and 24 or math.max(object.TextSize, 8))
            faces[key] = face
        end
    end
    local best, bestScore = nil, 0
    for key, score in pairs(scores) do
        if score > bestScore then
            best, bestScore = faces[key], score
        end
    end
    if not best then
        return nil
    end
    local previous = {}
    for name, face in pairs(Fonts) do
        previous[name] = face
    end
    Fonts.Title = best
    Fonts.Heavy = Font.new(best.Family, Enum.FontWeight.Bold, best.Style)
    if opts.Body then
        Fonts.Regular = Font.new(best.Family, Enum.FontWeight.Regular, best.Style)
        Fonts.Medium = Font.new(best.Family, Enum.FontWeight.Medium, best.Style)
        Fonts.Bold = Font.new(best.Family, Enum.FontWeight.SemiBold, best.Style)
    end
    Library:ApplyFonts(previous)
    Library.GameFont = best
    return best
end

-- Moves text already built from the faces in `previous` (name -> Font) to the current Library.Fonts.
function Library:ApplyFonts(previous)
    local map = {}
    for name, face in pairs(previous or {}) do
        if Fonts[name] and Fonts[name] ~= face then
            map[face] = Fonts[name]
        end
    end
    if next(map) == nil then
        return
    end
    local screens = table.clone(Library.Screens)
    for _, window in ipairs(Library.Windows) do
        table.insert(screens, window.Gui)
    end
    for _, screen in ipairs(screens) do
        if screen and screen.Parent then
            for _, object in screen:GetDescendants() do
                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    for old, new in pairs(map) do
                        if object.FontFace == old then
                            object.FontFace = new
                            break
                        end
                    end
                end
            end
        end
    end
end

function Hud.screen(name, order)
    local gui = create("ScreenGui", {
        Name = name,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = order or 990,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui:SetAttribute("BloomUI", true)
    table.insert(Library.Screens, gui)
    pcall(function()
        if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
        end
    end)
    gui.Parent = defaultParent()
    return gui
end

-- One UIScale from the screen size, so the HUD keeps its proportions on phones and on big monitors.
function Hud.autoScale(gui, target, connections)
    local scale = create("UIScale", { Parent = target })
    local function fit()
        local size = gui.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then
            return
        end
        scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720) * (TOUCH and 1.15 or 1), 0.55, 1.25)
    end
    fit()
    table.insert(connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    return scale
end

-- Drags `target` when a press lands on the border band of `edgeObject` (never from its middle), following only the
-- touch / mouse that started it (another finger never takes over).
function Hud.drag(edgeObject, target, connections)
    local dragInput, startPoint, startPosition
    table.insert(connections, UserInputService.InputBegan:Connect(function(input)
        if dragInput or not isPress(input) or not edgeObject.Visible or not target.Visible then
            return
        end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if input.UserInputType ~= Enum.UserInputType.Touch then
            point = pointerPosition()
        end
        if not nearEdge(point, edgeObject) then
            return
        end
        dragInput = input
        startPoint = point
        startPosition = target.Position
    end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not dragInput or not isMove(input) then
            return
        end
        if dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        if dragInput.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        -- Same source as the press point (touch position, or the inset-corrected mouse), so nothing jumps.
        local point = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or pointerPosition()
        local delta = point - startPoint
        target.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if not dragInput then
            return
        end
        if input == dragInput or (dragInput.UserInputType ~= Enum.UserInputType.Touch and isPress(input)) then
            dragInput = nil
        end
    end))
end

-- Panel plate: the window's dark surface, a soft gloss and the thick ink outline.
function Hud.plate(parent, props)
    local frame = create("Frame", {
        BackgroundColor3 = Theme.Background:Lerp(Style.Plate, 0.35),
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Parent = parent,
    })
    for key, value in pairs(props or {}) do
        frame[key] = value
    end
    corner(frame, UDim.new(0, 12))
    outlineStroke(frame, 3)
    create("UIGradient", {
        Name = "Gloss",
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 164, 172)),
        Parent = frame,
    })
    return frame
end

-- Small inset (icon wells, stat tiles, bar tracks): half-transparent black with a black outline.
function Hud.inset(parent, props, radius)
    local frame = create("Frame", {
        BackgroundColor3 = Style.Plate,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = parent,
    })
    for key, value in pairs(props or {}) do
        frame[key] = value
    end
    corner(frame, radius or UDim.new(0, 8))
    outlineStroke(frame, 2)
    return frame
end

-- Gradient pill with outlined text; returns frame, text label, gradient.
function Hud.pill(parent, text, colors, layoutOrder)
    local frame = create("Frame", {
        Size = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder or 0,
        Parent = parent,
    })
    corner(frame, UDim.new(1, 0))
    outlineStroke(frame, 1.5)
    local gradient = verticalGradient(frame, ColorSequence.new(colors[1], colors[2]))
    padding(frame, 8, 8)
    local text_ = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = text,
        TextSize = 11,
        TextColor3 = Color3.new(1, 1, 1),
        TextTruncate = Enum.TextTruncate.None,
        Parent = frame,
    })
    return frame, text_, gradient
end

function Hud.setColors(gradient, colors)
    gradient.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
end

-- A clean, centered copy of `source` in `viewport` (scripts / sounds / effects stripped, parts anchored).
function Hud.preview(viewport, camera, source)
    viewport:ClearAllChildren()
    camera.Parent = viewport
    local copy
    pcall(function()
        local archivable = source.Archivable
        source.Archivable = true
        copy = source:Clone()
        source.Archivable = archivable
    end)
    if not copy then
        return nil
    end
    if not copy:IsA("Model") then
        local holder = Instance.new("Model")
        copy.Parent = holder
        copy = holder
    end
    for _, descendant in copy:GetDescendants() do
        if descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") or descendant:IsA("ParticleEmitter")
            or descendant:IsA("Beam") or descendant:IsA("Trail") or descendant:IsA("Light") or descendant:IsA("BillboardGui")
            or descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector") then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
        end
    end
    local ok, boxFrame, boxSize = pcall(copy.GetBoundingBox, copy)
    if not ok then
        copy:Destroy()
        return nil
    end
    copy:PivotTo(boxFrame:ToObjectSpace(copy:GetPivot()))
    copy.Parent = viewport
    local radius = boxSize.Magnitude / 2
    return { model = copy, base = copy:GetPivot(), distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.08 }
end

-- Status HUD: preview (icon or a spinning 3D model), state / tag pills, a title, a detail line or chips, a steps line
-- or a progress bar, and stat tiles (FPS and PING built in, more through SetStat).
-- info for status:Set: { Text, Detail, State = "active" | "waiting" | "idle", Tag, Icon, Model,
--   Chips = { { Text, Colors = { c1, c2 } } }, Steps = { Names = { ... }, Current = n },
--   Bar = { Fraction = 0..1, Text, Colors = { c1, c2 } } }
function Library:CreateStatus(opts)
    opts = type(opts) == "table" and opts or {}
    local status = { Visible = true, _connections = {}, _stats = {}, _statOrder = 0 }
    local connections = status._connections
    local gui = Hud.screen(opts.Name or "BloomStatus", 995)
    status.Gui = gui

    local frame = Hud.plate(gui, {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = opts.Position or UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(520, 112),
    })
    status.Frame = frame
    Hud.autoScale(gui, frame, connections)
    Hud.drag(frame, frame, connections)

    -- State colour runs down the left edge.
    local edge = create("Frame", {
        Position = UDim2.fromOffset(5, 14),
        Size = UDim2.new(0, 4, 1, -28),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(edge, UDim.new(1, 0))
    local edgeGradient = verticalGradient(edge, ColorSequence.new(Hud.StateColors.idle[1], Hud.StateColors.idle[2]))

    local well = Hud.inset(frame, {
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.fromOffset(84, 84),
        ClipsDescendants = true,
    }, UDim.new(0, 10))
    local icon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.78, 0.78),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Parent = well,
    })
    applyIcon(icon, opts.Logo or Assets.Logo)
    local viewport = create("ViewportFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(190, 190, 200),
        LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-1, -1, -1),
        Visible = false,
        Parent = well,
    })
    local camera = create("Camera", { FieldOfView = 40, Parent = viewport })
    viewport.CurrentCamera = camera

    local textX, textWidth = 112, -(112 + 112)
    local pills = create("Frame", {
        Position = UDim2.fromOffset(textX, 12),
        Size = UDim2.new(1, textWidth, 0, 18),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = pills,
    })
    local _, stateText, stateGradient = Hud.pill(pills, "IDLE", Hud.StateColors.idle, 1)
    local tagPill, tagText = Hud.pill(pills, "", Hud.Lilac, 2)
    tagPill.Visible = false

    local title = shinyText(label({
        Position = UDim2.fromOffset(textX, 34),
        Size = UDim2.new(1, textWidth, 0, 22),
        Text = opts.Title or "Bloom Hub",
        TextSize = 17,
        Parent = frame,
    }))
    local detail = label({
        Position = UDim2.fromOffset(textX, 57),
        Size = UDim2.new(1, textWidth, 0, 16),
        Text = opts.Detail or "",
        TextSize = 12,
        FontFace = Fonts.Medium,
        TextColor3 = Theme.Muted,
        Parent = frame,
    })
    local chips = create("Frame", {
        Position = UDim2.fromOffset(textX, 56),
        Size = UDim2.new(1, textWidth, 0, 18),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = frame,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = chips,
    })
    local chipPool = {}

    -- Bottom line: either the steps (nodes on a line, captions under) or a progress bar.
    local bottom = create("Frame", {
        Position = UDim2.fromOffset(textX, 80),
        Size = UDim2.new(1, textWidth, 0, 20),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    local barTrack = Hud.inset(bottom, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 2), Visible = false }, UDim.new(1, 0))
    local barFill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = barTrack,
    })
    corner(barFill, UDim.new(1, 0))
    local barGradient = verticalGradient(barFill, ColorSequence.new(Hud.Bloom[1], Hud.Bloom[2]))
    local barText = label({
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
        Parent = barTrack,
    })
    local steps = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = bottom })
    local stepLine = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0, 6),
        Size = UDim2.new(1, -16, 0, 4),
        BackgroundColor3 = Style.Plate,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = steps,
    })
    corner(stepLine, UDim.new(1, 0))
    local stepFill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = stepLine,
    })
    corner(stepFill, UDim.new(1, 0))
    verticalGradient(stepFill, ColorSequence.new(Hud.Bloom[1], Hud.Bloom[2]))
    local stepNodes = {}

    -- Stat tiles on the right.
    local column = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(92, 88),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5), Parent = column })

    function status:SetStat(name, value, colors)
        local tile = status._stats[name]
        if not tile then
            if status._statOrder >= 3 then
                return
            end
            status._statOrder += 1
            local frame_ = Hud.inset(column, { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = status._statOrder })
            label({
                Position = UDim2.fromOffset(8, 0),
                Size = UDim2.new(0.5, 0, 1, 0),
                Text = string.upper(name),
                TextSize = 10,
                FontFace = Fonts.Medium,
                TextColor3 = Theme.Muted,
                Parent = frame_,
            })
            local valueLabel = label({
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -8, 0, 0),
                Size = UDim2.new(0.6, 0, 1, 0),
                TextSize = 13,
                TextColor3 = Color3.new(1, 1, 1),
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame_,
            })
            tile = { value = valueLabel, gradient = verticalGradient(valueLabel, ColorSequence.new(Hud.Green[1], Hud.Green[2])) }
            status._stats[name] = tile
        end
        tile.value.Text = tostring(value)
        if colors then
            Hud.setColors(tile.gradient, colors)
        end
    end
    status:SetStat("FPS", "--")
    status:SetStat("PING", "--")

    local function renderSteps(info)
        local names = info and info.Names
        steps.Visible = type(names) == "table" and #names > 0
        if not steps.Visible then
            return
        end
        if #stepNodes ~= #names then
            for _, node in stepNodes do
                node.dot:Destroy()
                node.caption:Destroy()
            end
            table.clear(stepNodes)
            for index, name in ipairs(names) do
                local x = #names > 1 and (index - 1) / (#names - 1) or 0.5
                local dot = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(x, index == 1 and 8 or (index == #names and -8 or 0), 0, 6),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 2,
                    Parent = steps,
                })
                corner(dot, UDim.new(1, 0))
                outlineStroke(dot, 2)
                local caption = label({
                    AnchorPoint = Vector2.new(x, 0),
                    Position = UDim2.new(x, 0, 0, 11),
                    Size = UDim2.fromOffset(70, 12),
                    Text = string.upper(name),
                    TextSize = 9,
                    TextXAlignment = index == 1 and Enum.TextXAlignment.Left or (index == #names and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center),
                    TextTruncate = Enum.TextTruncate.None,
                    Parent = steps,
                })
                table.insert(stepNodes, { dot = dot, caption = caption })
            end
        end
        local current = math.clamp(tonumber(info.Current) or 1, 1, #names)
        tween(stepFill, { Size = UDim2.fromScale(#names > 1 and (current - 1) / (#names - 1) or 1, 1) }, 0.25)
        for index, node in stepNodes do
            local done, now = index < current, index == current
            node.dot.BackgroundColor3 = done and Hud.Bloom[1] or (now and Color3.new(1, 1, 1) or Theme.Surface3)
            node.caption.TextColor3 = now and Color3.new(1, 1, 1) or (done and Hud.Bloom[1] or Theme.Muted)
        end
    end

    local function renderBar(info)
        barTrack.Visible = type(info) == "table"
        if not barTrack.Visible then
            return
        end
        tween(barFill, { Size = UDim2.fromScale(math.clamp(tonumber(info.Fraction) or 0, 0, 1), 1) }, 0.25)
        Hud.setColors(barGradient, info.Colors or Hud.Bloom)
        barText.Text = info.Text or ""
    end

    local function renderChips(list)
        local show = type(list) == "table" and #list > 0
        chips.Visible = show
        detail.Visible = not show
        if not show then
            return
        end
        for index, chip in ipairs(list) do
            local entry = chipPool[index]
            if not entry then
                local frame_, text_, gradient = Hud.pill(chips, "", Hud.Grey, index)
                entry = { frame = frame_, text = text_, gradient = gradient }
                chipPool[index] = entry
            end
            entry.frame.Visible = true
            entry.text.Text = tostring(chip.Text or "")
            Hud.setColors(entry.gradient, chip.Colors or Hud.Grey)
        end
        for index = #list + 1, #chipPool do
            chipPool[index].frame.Visible = false
        end
    end

    function status:SetModel(model)
        if model == status._modelSource then
            return
        end
        status._modelSource = model
        status._preview = model and Hud.preview(viewport, camera, model) or nil
        viewport.Visible = status._preview ~= nil
        icon.Visible = status._preview == nil
    end

    function status:Set(info)
        info = type(info) == "table" and info or {}
        local state = Hud.StateColors[info.State] and info.State or "idle"
        stateText.Text = Hud.StateWords[state]
        Hud.setColors(stateGradient, Hud.StateColors[state])
        Hud.setColors(edgeGradient, Hud.StateColors[state])
        tagPill.Visible = type(info.Tag) == "string" and info.Tag ~= ""
        tagText.Text = info.Tag or ""
        title.Text = info.Text or opts.Title or "Bloom Hub"
        detail.Text = info.Detail or ""
        if info.Icon ~= status._icon then
            status._icon = info.Icon
            applyIcon(icon, info.Icon or opts.Logo or Assets.Logo)
        end
        status:SetModel(info.Model)
        renderChips(info.Chips)
        renderSteps(info.Steps)
        renderBar(not steps.Visible and info.Bar or nil)
    end

    function status:SetVisible(value)
        status.Visible = value ~= false
        frame.Visible = status.Visible
    end

    function status:Destroy()
        for _, connection in connections do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(connections)
        gui:Destroy()
    end

    -- FPS / PING every half second; the preview turns slowly while it is shown.
    local frames, clock, spin = 0, 0, 0
    table.insert(connections, RunService.RenderStepped:Connect(function(deltaTime)
        frames += 1
        clock += deltaTime
        if clock >= 0.5 then
            local fps = math.floor(frames / clock + 0.5)
            frames, clock = 0, 0
            status:SetStat("FPS", fps, fps >= 50 and Hud.Green or (fps >= 25 and Hud.Gold or Hud.Red))
            local ok, ping = pcall(function()
                return LocalPlayer:GetNetworkPing() * 1000
            end)
            if ok and ping then
                ping = math.floor(ping + 0.5)
                status:SetStat("PING", ping, ping <= 120 and Hud.Green or (ping <= 250 and Hud.Gold or Hud.Red))
            end
        end
        local preview = status._preview
        if preview and status.Visible then
            spin = (spin + deltaTime * 40) % 360
            camera.CFrame = CFrame.Angles(0, math.rad(spin), 0) * CFrame.new(0, preview.distance * 0.18, preview.distance)
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, Vector3.zero)
        end
    end))

    status:Set({ Text = opts.Title or "Bloom Hub", Detail = opts.Detail or "Nothing running", State = "idle" })
    return status
end

-- One pooled steal card (reused by SetItems, so a refresh never rebuilds the list). Its plate is white so the
-- rarity tint gradient shows its real colours; the left bar, the icon ring and the glow take the rarity too.
function Hud.stealCard(panel, list)
    local card = {}
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = list,
    })
    corner(frame, UDim.new(0, 12))
    card.frame = frame
    card.stroke = outlineStroke(frame, 2.5)
    card.tint = create("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new(Theme.Surface2, Theme.Surface2),
        Parent = frame,
    })
    frame.MouseEnter:Connect(function()
        tween(card.stroke, { Color = Theme.StrokeHover }, 0.12)
    end)
    frame.MouseLeave:Connect(function()
        tween(card.stroke, { Color = card.restColor or Theme.Outline }, 0.25)
    end)

    local accent = create("Frame", {
        Position = UDim2.fromOffset(6, 12),
        Size = UDim2.new(0, 4, 1, -24),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(accent, UDim.new(1, 0))
    card.accent = verticalGradient(accent, ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)))

    -- Icon well: a soft rarity glow behind it, a rarity ring around it, the item badge on its corner.
    card.glow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(44, 40),
        Size = UDim2.fromOffset(96, 96),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageTransparency = 0.72,
        Parent = frame,
    })
    card.well = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(56, 56),
        BackgroundColor3 = Style.Plate,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = frame,
    })
    corner(card.well, UDim.new(0, 10))
    card.wellStroke = outlineStroke(card.well, 2)
    card.icon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.84, 0.84),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 2,
        Parent = card.well,
    })
    card.badge = create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 7, 1, 7),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = Theme.Surface,
        ScaleType = Enum.ScaleType.Fit,
        Visible = false,
        ZIndex = 3,
        Parent = card.well,
    })
    corner(card.badge, UDim.new(1, 0))
    outlineStroke(card.badge, 1.5)

    -- Text: name, then the rarity pill, then value / weight chips.
    local textX, reserve = 84, 98
    card.name = shinyText(label({
        Position = UDim2.fromOffset(textX, 9),
        Size = UDim2.new(1, -(textX + reserve), 0, 19),
        TextSize = 15,
        Parent = frame,
    }))
    local row = create("Frame", {
        Position = UDim2.fromOffset(textX, 31),
        Size = UDim2.new(1, -(textX + reserve), 0, 18),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = row,
    })
    card.rarityPill, card.rarityText, card.rarityGradient = Hud.pill(row, "", Hud.Grey, 1)
    local chips = create("Frame", {
        Position = UDim2.fromOffset(textX, 53),
        Size = UDim2.new(1, -(textX + reserve), 0, 18),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = chips,
    })
    card.chips = chips
    card.valuePill, card.valueText = Hud.pill(chips, "", Hud.Green, 1)
    card.infoPill, card.infoText = Hud.pill(chips, "", Hud.Sky, 2)

    card.best = Hud.pill(frame, "BEST", Hud.Gold)
    card.best.AnchorPoint = Vector2.new(1, 0)
    card.best.Position = UDim2.new(1, -10, 0, -9)
    card.best.ZIndex = 4
    card.best.Visible = false

    -- Actions: the pink button steals now; QUEUE adds it to the list and turns lilac with its spot once queued.
    card.steal = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 11),
        Size = UDim2.fromOffset(82, 32),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = frame,
    })
    buttonFace(card.steal, 1)
    scaleFeedback(card.steal, 1.05, 0.94)
    card.stealText = shinyText(label({
        Size = UDim2.new(1, 0, 1, -4),
        Text = "STEAL",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
        Parent = card.steal,
    }))
    card.queue = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 48),
        Size = UDim2.fromOffset(82, 22),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Text = "",
        AutoButtonColor = false,
        Parent = frame,
    })
    corner(card.queue, UDim.new(1, 0))
    outlineStroke(card.queue, 2)
    card.queueFill = create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Theme.Surface3, Theme.Surface2),
        Parent = card.queue,
    })
    scaleFeedback(card.queue, 1.05, 0.94)
    card.queueText = label({
        Size = UDim2.fromScale(1, 1),
        Text = "+ QUEUE",
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = card.queue,
    })
    card.steal.MouseButton1Click:Connect(function()
        if card.id ~= nil then
            safeCall(panel.OnSteal, card.id)
        end
    end)
    card.queue.MouseButton1Click:Connect(function()
        if card.id ~= nil then
            safeCall(panel.OnQueue, card.id)
        end
    end)
    return card
end

-- item: { Id, Name, Icon, Badge, Rarity, RarityColor, Value, Info (weight, light blue), Featured, Queued, ActionText }
function Hud.paintCard(card, item, order)
    card.id = item.Id
    local featured = item.Featured == true
    local rarityColor = item.RarityColor or Theme.Muted
    card.frame.LayoutOrder = order
    card.frame.Size = UDim2.new(1, 0, 0, featured and 92 or 80)
    local wellSize = featured and 66 or 56
    card.well.Size = UDim2.fromOffset(wellSize, wellSize)
    card.glow.Position = UDim2.fromOffset(16 + wellSize / 2, (featured and 92 or 80) / 2)
    card.glow.Size = UDim2.fromOffset(wellSize * 1.8, wellSize * 1.8)
    card.glow.ImageColor3 = rarityColor
    card.glow.ImageTransparency = featured and 0.6 or 0.74

    -- Featured: a gold rim; the rest rest on the ink outline. A light rarity wash from the left on every card.
    card.restColor = featured and Hud.Gold[1] or Theme.Outline
    card.stroke.Color = card.restColor
    card.stroke.Thickness = featured and 3 or 2.5
    card.tint.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, rarityColor:Lerp(Theme.Surface2, featured and 0.7 or 0.8)),
        ColorSequenceKeypoint.new(0.55, Theme.Surface2),
        ColorSequenceKeypoint.new(1, Theme.Surface2:Lerp(Style.Plate, 0.3)),
    })
    Hud.setColors(card.accent, { rarityColor:Lerp(Color3.new(1, 1, 1), 0.3), rarityColor })
    card.wellStroke.Color = rarityColor:Lerp(Theme.Outline, 0.25)

    if item.Icon ~= card.iconValue then
        card.iconValue = item.Icon
        card.icon.Image = ""
        if item.Icon then
            applyIcon(card.icon, item.Icon)
        end
    end
    card.badge.Visible = item.Badge ~= nil
    if item.Badge and item.Badge ~= card.badgeValue then
        card.badgeValue = item.Badge
        applyIcon(card.badge, item.Badge)
    end

    card.name.Text = tostring(item.Name or "")
    card.rarityPill.Visible = item.Rarity ~= nil
    card.rarityText.Text = string.upper(tostring(item.Rarity or ""))
    Hud.setColors(card.rarityGradient, { rarityColor:Lerp(Color3.new(1, 1, 1), 0.35), rarityColor:Lerp(Style.Plate, 0.25) })

    card.valuePill.Visible = item.Value ~= nil
    card.valueText.Text = tostring(item.Value or "")
    card.infoPill.Visible = item.Info ~= nil
    card.infoText.Text = tostring(item.Info or "")
    card.best.Visible = featured
    card.stealText.Text = item.ActionText or "STEAL"

    local queued = item.Queued ~= nil
    card.queueText.Text = queued and ("#" .. tostring(item.Queued) .. " QUEUED") or "+ QUEUE"
    card.queueText.TextColor3 = queued and Color3.new(1, 1, 1) or Theme.Text
    card.queueFill.Color = queued and ColorSequence.new(Hud.Lilac[1], Hud.Lilac[2]) or ColorSequence.new(Theme.Surface3, Theme.Surface2)
end

-- Steal HUD: a side panel listing things to take (featured first), each with STEAL and QUEUE; a tab on its inner
-- edge hides / shows it. opts: { Title, Subtitle, Side = "Right" | "Left", Width, Height, EmptyText, OnSteal,
-- OnQueue }.
function Library:CreateStealPanel(opts)
    opts = type(opts) == "table" and opts or {}
    local panel = { Collapsed = false, Visible = true, OnSteal = opts.OnSteal, OnQueue = opts.OnQueue, _cards = {}, _connections = {} }
    local connections = panel._connections
    local gui = Hud.screen(opts.Name or "BloomSteal", 994)
    panel.Gui = gui
    local right = opts.Side ~= "Left"
    local width, height = opts.Width or 330, opts.Height or 420
    local openPosition = UDim2.new(right and 1 or 0, right and -16 or 16, 0.5, 0)

    local holder = create("Frame", {
        AnchorPoint = Vector2.new(right and 1 or 0, 0.5),
        Position = openPosition,
        Size = UDim2.fromOffset(width, height),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    panel.Holder = holder
    Hud.autoScale(gui, holder, connections)
    local frame = Hud.plate(holder, { Size = UDim2.fromScale(1, 1), ClipsDescendants = true })

    -- Header: title over a subtitle, the item count; a soft accent wash behind it.
    local headerHeight = 62
    local header = create("Frame", { Size = UDim2.new(1, 0, 0, headerHeight), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = frame })
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
        Parent = header,
    })
    local titleLabel = shinyText(label({
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -90, 0, 20),
        Text = string.upper(opts.Title or "Steal"),
        TextSize = 16,
        Parent = header,
    }))
    label({
        Position = UDim2.fromOffset(16, 33),
        Size = UDim2.new(1, -90, 0, 15),
        Text = opts.Subtitle or "Best eggs on the field",
        TextSize = 12,
        FontFace = Fonts.Medium,
        TextColor3 = Theme.Muted,
        Parent = header,
    })
    local countPill, countText = Hud.pill(header, "0", Hud.Bloom)
    countPill.AnchorPoint = Vector2.new(1, 0.5)
    countPill.Position = UDim2.new(1, -14, 0.5, 0)
    Hud.drag(frame, holder, connections)
    local rule = create("Frame", {
        Position = UDim2.new(0, 14, 0, headerHeight),
        Size = UDim2.new(1, -28, 0, 2),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = frame,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = rule,
    })

    local footerHeight = 6
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0, headerHeight + 4),
        Size = UDim2.new(1, 0, 1, -(headerHeight + 4 + footerHeight)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Style.AccentColor,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = frame,
    })
    padding(list, 12, 12, 10, 10)
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = list })

    -- Empty state: an icon over the text.
    local empty = create("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1, LayoutOrder = 0, Parent = list })
    local emptyIcon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 16),
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        Parent = empty,
    })
    applyIcon(emptyIcon, "search")
    label({
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(1, 0, 0, 18),
        Text = opts.EmptyText or "Nothing to steal yet",
        TextSize = 13,
        FontFace = Fonts.Medium,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = empty,
    })

    -- Hide / show tab on the inner edge: it stays on screen while the panel slides out.
    local tab = create("TextButton", {
        AnchorPoint = Vector2.new(right and 1 or 0, 0.5),
        Position = UDim2.new(right and 0 or 1, right and -6 or 6, 0.5, 0),
        Size = UDim2.fromOffset(26, 66),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = holder,
    })
    buttonFace(tab, 1)
    scaleFeedback(tab, 1.06, 0.94)
    local arrow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ImageColor3 = Color3.new(1, 1, 1),
        ZIndex = 3,
        Parent = tab,
    })
    applyIcon(arrow, right and "chevron-right" or "chevron-left")

    -- Slides off the screen edge and back to wherever it was dragged to.
    function panel:SetCollapsed(value)
        value = value == true
        if value == panel.Collapsed then
            return
        end
        panel.Collapsed = value
        local goal
        if value then
            panel._restore = holder.Position
            -- Push the panel just past the screen edge, leaving its tab fully on screen against that edge.
            local screen = gui.AbsoluteSize.X
            local left, holderWidth = holder.AbsolutePosition.X, holder.AbsoluteSize.X
            local shift
            if right then
                local gap = left - (tab.AbsolutePosition.X + tab.AbsoluteSize.X)
                shift = (screen - 2 + gap) - left
            else
                local gap = tab.AbsolutePosition.X - (left + holderWidth)
                shift = (2 - gap) - (left + holderWidth)
            end
            goal = UDim2.new(holder.Position.X.Scale, holder.Position.X.Offset + shift, holder.Position.Y.Scale, holder.Position.Y.Offset)
        else
            goal = panel._restore or openPosition
        end
        tween(holder, { Position = goal }, 0.35, Enum.EasingStyle.Quint)
        tween(arrow, { Rotation = value and 180 or 0 }, 0.25)
    end
    tab.MouseButton1Click:Connect(function()
        panel:SetCollapsed(not panel.Collapsed)
    end)

    function panel:SetItems(items)
        items = type(items) == "table" and items or {}
        for index, item in ipairs(items) do
            local card = panel._cards[index]
            if not card then
                card = Hud.stealCard(panel, list)
                panel._cards[index] = card
            end
            card.frame.Visible = true
            Hud.paintCard(card, item, index)
        end
        for index = #items + 1, #panel._cards do
            panel._cards[index].frame.Visible = false
            panel._cards[index].id = nil
        end
        countText.Text = tostring(#items)
        empty.Visible = #items == 0
    end

    function panel:SetTitle(value)
        titleLabel.Text = string.upper(tostring(value or ""))
    end

    function panel:SetVisible(value)
        panel.Visible = value ~= false
        holder.Visible = panel.Visible
    end

    function panel:Destroy()
        for _, connection in connections do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(connections)
        gui:Destroy()
    end

    panel:SetItems({})
    return panel
end

Library.CreateSteal = Library.CreateStealPanel

-- The downloaded file included a runnable showcase. Keep it as a reference,
-- but never create its extra window when this source is loaded as a library.
if false then
local Airflow = Library

Airflow:LoadFont({ Name = "ValleySans" }) -- downloads the font once into workspace/AirFlowFonts and uses it everywhere

local Window = Airflow:CreateWindow({
    Name = "Airflow",
    LoadingSubtitle = "Example",
    ToggleUIKeybind = "RightControl", -- key that hides and shows the window
    -- examples: "RightShift", "RightControl", "LeftAlt", "Insert", "Home", "F1", "Backquote"
    -- Enum.KeyCode values also work: ToggleUIKeybind = Enum.KeyCode.RightShift
    ConfigurationSaving = { Enabled = true, FolderName = "AirflowExample", FileName = "default" },
    Home = {
        Name = "Home",
        Stats = { "FPS", "Ping", "Executor", "Game", "Region", "Time" },
        Pages = { -- extra tabs beside the info one
            {
                Name = "Changelog",
                Icon = "scroll-text",
                Entries = {
                    { Title = "v1.2", Tag = "Latest", Changes = { "Added the home tab", "Smaller input boxes that grow", "Faster dropdowns" } },
                    { Title = "v1.1", Tag = "Aug 30", Changes = { "Config manager", "Stepper and progress elements" } },
                },
            },
            {
                Name = "Info",
                Icon = "info",
                Content = "Airflow UI example. Everything on the Elements tab just prints, so you can click around safely.",
            },
        },
    }
})

local Elements = Window:CreateTab({ Name = "Elements", Desc = "One of everything", Icon = "layout-grid" })

Elements:CreateSection("Example section")

Elements:CreateButton({
    Name = "Example button",
    Desc = "Example description",
    Icon = "mouse-pointer-click",
    Callback = function()
        print("button")
    end,
})

Elements:CreateButton({
    Name = "Example primary button",
    Style = "Primary",
    Callback = function()
        print("primary button")
    end,
})

Elements:CreateToggle({
    Name = "Example toggle",
    Desc = "Example description",
    CurrentValue = false,
    Flag = "ExampleToggle",
    Callback = function(Value)
        print("toggle", Value)
    end,
})

Elements:CreateSlider({
    Name = "Example slider",
    Range = { 0, 100 },
    Increment = 1,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "ExampleSlider",
    Callback = function(Value)
        print("slider", Value)
    end,
})

Elements:CreateStepper({
    Name = "Example stepper",
    Range = { 0, 10 },
    Increment = 1,
    CurrentValue = 5,
    Flag = "ExampleStepper",
    Callback = function(Value)
        print("stepper", Value)
    end,
})

Elements:CreateProgress({
    Name = "Example progress",
    CurrentValue = 0.65,
})

Elements:CreateDropdown({
    Name = "Example dropdown",
    Options = { "Option 1", "Option 2", "Option 3" },
    CurrentOption = "Option 1",
    Flag = "ExampleDropdown",
    Callback = function(Option)
        print("dropdown", Option)
    end,
})

Elements:CreateDropdown({
    Name = "Example multi dropdown",
    Options = { "Option 1", "Option 2", "Option 3", "Option 4" },
    MultipleOptions = true,
    CurrentOption = { "Option 1" },
    Flag = "ExampleMultiDropdown",
    Callback = function(Options)
        print("multi dropdown", table.concat(Options, ", "))
    end,
})

Elements:CreateInput({
    Name = "Example input",
    PlaceholderText = "Type here",
    Flag = "ExampleInput",
    Callback = function(Text, EnterPressed)
        print("input", Text, EnterPressed)
    end,
})

Elements:CreateKeybind({
    Name = "Example keybind",
    CurrentKeybind = "F",
    Flag = "ExampleKeybind",
    Callback = function(Key)
        print("keybind", Key.Name)
    end,
})

Elements:CreateColorPicker({
    Name = "Example color picker",
    Color = Color3.fromRGB(235, 199, 246),
    Flag = "ExampleColor",
    Callback = function(Color)
        print("color", Color)
    end,
})

Elements:CreateDivider()

Elements:CreateLabel("Example label")

Elements:CreateParagraph({
    Title = "Example paragraph",
    Content = "Longer text that wraps across several lines.",
})

local Popups = Window:CreateTab({ Name = "Popups", Desc = "Notifications and dialogs", Icon = "bell" })

Popups:CreateButton({
    Name = "Example notification",
    Callback = function()
        Airflow:Notify({
            Title = "Example",
            Content = "Example notification",
            Icon = "bell",
            Type = "Success",
            Duration = 3,
        })
    end,
})

Popups:CreateButton({
    Name = "Example confirm",
    Callback = function()
        Airflow:Confirm({
            Title = "Example confirm",
            Content = "Are you sure?",
            ConfirmText = "Yes",
            CancelText = "No",
            Callback = function()
                print("confirmed")
            end,
        })
    end,
})

Popups:CreateButton({
    Name = "Example dialog",
    Callback = function()
        Airflow:Dialog({
            Title = "Example dialog",
            Content = "Pick one.",
            Buttons = {
                { Title = "One", Callback = function() print("one") end },
                { Title = "Two", Callback = function() print("two") end },
                { Title = "Three", Variant = "Primary", Callback = function() print("three") end },
            },
        })
    end,
})

Window:CreateTab({ Name = "Empty", Desc = "Nothing in here", Icon = "package" })

local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })

Settings:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = "RightControl",
    OnChanged = function(Key)
        Window:SetKeybind(Key)
    end,
})

Settings:CreateConfigManager({ Name = "Configs" })

Settings:CreateButton({
    Name = "Unload",
    Icon = "power",
    Callback = function()
        Airflow:Confirm({
            Title = "Unload?",
            ConfirmText = "Unload",
            Callback = function()
                Window:Destroy()
            end,
        })
    end,
})

Window:LoadConfig()
end

return Library
