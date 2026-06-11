if game.PlaceId ~= 537413528 then
    return function() end
end

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT

local ok, result = pcall(function()
    local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
    local Library = loadstring(game:HttpGet(repo .. "Library.lua", true))()

    local Window = Library:CreateWindow({
        Title = "BABFT (LinoriaLib)",
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2,
    })

    local Tab = Window:AddTab("Main")
    local Group = Tab:AddLeftGroupbox("BABFT")
    Group:AddLabel("LinoriaLib — port in progress")
    Group:AddButton("Back to UI Selector", function()
        if type(BABFT.ReturnToHub) == "function" then
            BABFT.ReturnToHub()
        end
    end)

    return function()
        pcall(function() Library:Unload() end)
    end
end)

if not ok then
    warn("[BABFT Linoria]", result)
    return function() end
end

return result
