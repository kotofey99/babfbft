if game.PlaceId ~= 537413528 then
    return function() end
end

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT

local function cleanup()
    if BABFT._WindModuleWindow then
        pcall(function()
            if BABFT._WindModuleWindow.Destroy then
                BABFT._WindModuleWindow:Destroy()
            end
        end)
    end
    BABFT._WindModuleWindow = nil
end

local ok, err = pcall(function()
    local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

    local Window = WindUI:CreateWindow({
        Title = "BABFT (WindUI module)",
        Icon = "box",
        Author = "by Mizuhura",
    })

    BABFT._WindModuleWindow = Window

    local Tab = Window:Tab({Title = "Info", Icon = "bird"})
    Tab:Paragraph({
        Title = "Coming soon",
        Desc = "Full BABFT on WindUI after CascadeUI. Use Rayfield or Cascade for now.",
    })
    Tab:Button({
        Title = "Back to UI Selector",
        Desc = "Return to hub",
        Callback = function()
            if type(BABFT.ReturnToHub) == "function" then
                BABFT.ReturnToHub()
            else
                cleanup()
            end
        end,
    })
end)

if not ok then
    warn("[BABFT WindUI module]", err)
end

return cleanup
