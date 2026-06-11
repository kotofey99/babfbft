-- BABFT Loader — залей на GitHub: loader/loader.lua
-- Инжект одной строкой (bootstrap.lua) — хаб всегда свежий с GitHub

if game.PlaceId ~= 537413528 then
    warn("BABFT: script only works in Build A Boat For Treasure")
    return
end

local REPO = "https://raw.githubusercontent.com/kotofey99/babfbft/main"
local BASE = REPO .. "/scripts"

local MODULE_URLS = {
    Rayfield = BASE .. "/rayfield.lua",
    WindUI = BASE .. "/windui.lua",
    LinoriaLib = BASE .. "/linoria.lua",
    CascadeUI = BASE .. "/cascade.lua",
    MercuryUI = BASE .. "/mercury.lua",
}

local MODULES = {
    Rayfield = {Title = "Rayfield", Desc = "Universal UI, Dark/Light, animations"},
    WindUI = {Title = "WindUI", Desc = "Script Hub style, icons, themes"},
    LinoriaLib = {Title = "LinoriaLib", Desc = "Large scripts, tabs, group boxes"},
    CascadeUI = {Title = "CascadeUI", Desc = "Simple clean menus"},
    MercuryUI = {Title = "MercuryUI", Desc = "Minimal fast UI"},
}

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT
BABFT.Locale = BABFT.Locale or "en"
BABFT.ModuleCleanup = nil
BABFT.HubWindow = nil
BABFT.ActiveModule = nil
BABFT.Version = "v7"

local function cacheUrl(url)
    return url .. "?t=" .. tostring(os.time())
end

local function loadRemote(url)
    return loadstring(game:HttpGet(cacheUrl(url), true))()
end

function BABFT.CleanupModule()
    if BABFT.ModuleCleanup then
        pcall(BABFT.ModuleCleanup)
        BABFT.ModuleCleanup = nil
    end
    BABFT.ActiveModule = nil
end

function BABFT.HideHub()
    if BABFT.HubWindow then
        pcall(function()
            if BABFT.HubWindow.Close then
                BABFT.HubWindow:Close()
            end
        end)
    end
end

function BABFT.ShowHub()
    if BABFT.HubWindow then
        pcall(function()
            if BABFT.HubWindow.Open then
                BABFT.HubWindow:Open()
            elseif BABFT.HubWindow.Show then
                BABFT.HubWindow:Show()
            end
        end)
    end
end

function BABFT.ReturnToHub()
    BABFT.CleanupModule()
    BABFT.ShowHub()
end

local function loadModule(id)
    local url = MODULE_URLS[id]
    if not url then return end

    BABFT.CleanupModule()
    BABFT.HideHub()

    local ok, result = pcall(function()
        return loadRemote(url)
    end)

    if not ok then
        WindUI:Notify({
            Title = "BABFT Error",
            Content = tostring(result),
            Duration = 8,
        })
        BABFT.ShowHub()
        return
    end

    if type(result) == "function" then
        BABFT.ModuleCleanup = result
    end

    BABFT.ActiveModule = id
    WindUI:Notify({
        Title = "BABFT",
        Content = id .. " loaded",
        Duration = 3,
    })
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

WindUI:AddTheme({
    Name = "BABFT Dark",
    Accent = Color3.fromHex("#18181b"),
    Background = Color3.fromHex("#101010"),
    BackgroundTransparency = 0,
    Outline = Color3.fromHex("#FFFFFF"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#7a7a7a"),
    Button = Color3.fromHex("#52525b"),
    Icon = Color3.fromHex("#a1a1aa"),
    Hover = Color3.fromHex("#FFFFFF"),
    WindowBackground = Color3.fromHex("#101010"),
    WindowShadow = Color3.fromHex("#000000"),
    DialogBackground = Color3.fromHex("#101010"),
    DialogBackgroundTransparency = 0,
    DialogTitle = Color3.fromHex("#FFFFFF"),
    DialogContent = Color3.fromHex("#FFFFFF"),
    DialogIcon = Color3.fromHex("#a1a1aa"),
    WindowTopbarButtonIcon = Color3.fromHex("#a1a1aa"),
    WindowTopbarTitle = Color3.fromHex("#FFFFFF"),
    WindowTopbarAuthor = Color3.fromHex("#FFFFFF"),
    WindowTopbarIcon = Color3.fromHex("#FFFFFF"),
    TabBackground = Color3.fromHex("#FFFFFF"),
    TabTitle = Color3.fromHex("#FFFFFF"),
    TabIcon = Color3.fromHex("#a1a1aa"),
    ElementBackground = Color3.fromHex("#FFFFFF"),
    ElementTitle = Color3.fromHex("#FFFFFF"),
    ElementDesc = Color3.fromHex("#FFFFFF"),
    ElementIcon = Color3.fromHex("#a1a1aa"),
    PopupBackground = Color3.fromHex("#101010"),
    PopupBackgroundTransparency = 0,
    PopupTitle = Color3.fromHex("#FFFFFF"),
    PopupContent = Color3.fromHex("#FFFFFF"),
    PopupIcon = Color3.fromHex("#a1a1aa"),
    Toggle = Color3.fromHex("#52525b"),
    ToggleBar = Color3.fromHex("#FFFFFF"),
    Checkbox = Color3.fromHex("#52525b"),
    CheckboxIcon = Color3.fromHex("#FFFFFF"),
    Slider = Color3.fromHex("#52525b"),
    SliderThumb = Color3.fromHex("#FFFFFF"),
})

local Window = WindUI:CreateWindow({
    Title = "BABFT Hub",
    Icon = "door-open",
    Author = "by Mizuhura",
    Theme = "BABFT Dark",
})

BABFT.HubWindow = Window

Window:Tag({
    Title = BABFT.Version,
    Icon = "github",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 0,
})

local Tab = Window:Tab({
    Title = "UI Menu",
    Icon = "layout-grid",
    Locked = false,
})

Tab:Paragraph({
    Title = "Choose UI",
    Desc = "Modules load fresh from GitHub each click (?t=timestamp).",
})

local icons = {
    Rayfield = "sparkles",
    WindUI = "wind",
    LinoriaLib = "layers",
    CascadeUI = "panel-top",
    MercuryUI = "gem",
}

for id, entry in pairs(MODULES) do
    Tab:Button({
        Title = entry.Title,
        Desc = entry.Desc,
        Icon = icons[id] or "box",
        Locked = false,
        Callback = function()
            loadModule(id)
        end,
    })
end
