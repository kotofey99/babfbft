if game.PlaceId ~= 537413528 then
    return function() end
end

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT

local ok, result = pcall(function()
    local Mercury = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua", true))()

    local GUI = Mercury:Create({
        Name = "BABFT (MercuryUI)",
        Size = UDim2.fromOffset(560, 400),
        Theme = Mercury.Themes.Dark,
        Link = "https://github.com/kotofey99/babfbft",
    })

    local Tab = GUI:Tab({Name = "Main"})
    Tab:Label({Text = "MercuryUI — port in progress"})
    Tab:Button({
        Name = "Back to UI Selector",
        Callback = function()
            if type(BABFT.ReturnToHub) == "function" then
                BABFT.ReturnToHub()
            end
        end,
    })

    return function()
        pcall(function()
            if getgenv and getgenv().MercuryUI then
                getgenv().MercuryUI()
            end
        end)
    end
end)

if not ok then
    warn("[BABFT Mercury]", result)
    return function() end
end

return result
