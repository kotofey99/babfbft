-- BABFT module: MercuryUI
if game.PlaceId ~= 537413528 then
    return function() end
end

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT

local SCRIPTS = "https://raw.githubusercontent.com/kotofey99/babfbft/main/scripts"

local function mercNotify(opts)
    opts = opts or {}
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(opts.Title or "BABFT"),
            Text = tostring(opts.Content or ""),
            Duration = math.floor(opts.Duration or 5),
        })
    end)
end

local okCore, Core = pcall(function()
    return loadstring(game:HttpGet(SCRIPTS .. "/babft_core.lua?t=" .. os.time(), true))()
end)
if not okCore or not Core then
    warn("[BABFT Mercury] core error:", Core)
    return function() end
end

Core.Init({Notify = mercNotify})

local L = Core.L
local Config = Core.Config
local Mercury = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua", true))()

local function destroyGUI()
    if getgenv and getgenv().MercuryUI then
        pcall(getgenv().MercuryUI)
        getgenv().MercuryUI = nil
    end
end

local function createMoveButtons(tab)
    local step = function()
        return Config.MoveStep
    end
    local sec = tab:Section({Name = L("section_move")})
    sec:Button({Name = L("btn_fwd"), Callback = function() Core.movePreview(Vector3.new(0, 0, -step())) end})
    sec:Button({Name = L("btn_back"), Callback = function() Core.movePreview(Vector3.new(0, 0, step())) end})
    sec:Button({Name = L("btn_left"), Callback = function() Core.movePreview(Vector3.new(-step(), 0, 0)) end})
    sec:Button({Name = L("btn_right"), Callback = function() Core.movePreview(Vector3.new(step(), 0, 0)) end})
    sec:Button({Name = L("btn_up"), Callback = function() Core.movePreview(Vector3.new(0, step(), 0)) end})
    sec:Button({Name = L("btn_down"), Callback = function() Core.movePreview(Vector3.new(0, -step(), 0)) end})
    sec:Button({Name = L("btn_rotate"), Callback = function() Core.rotatePreview(90) end})
end

local function buildImageTab(tab)
    local filesSec = tab:Section({Name = L("folder_image")})
    local initialFiles = Core.getImageFileList()
    local selectedFile = initialFiles[1] or ""

    local fileDropdown = filesSec:Dropdown({
        Name = L("dropdown_image"),
        Items = initialFiles,
        StartingText = selectedFile ~= "" and selectedFile or "Select...",
        Callback = function(opt)
            selectedFile = opt
        end,
    })

    filesSec:Button({
        Name = L("btn_refresh"),
        Callback = function()
            local files = Core.getImageFileList()
            fileDropdown:Clear()
            fileDropdown:AddItems(files)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedFile = files[1]
                fileDropdown:Set(files[1])
            end
            local count = 0
            for _, f in ipairs(files) do
                if f:sub(1, 1) ~= "(" then
                    count += 1
                end
            end
            mercNotify({Title = L("list_updated"), Content = L("files_found", count), Duration = 3})
        end,
    })

    filesSec:Button({
        Name = L("btn_load_file"),
        Callback = function()
            Core.clearPreview()
            Core.setStatus(L("status_reading"))
            task.spawn(function()
                local data, stepOrErr = Core.loadLocalImageByName(selectedFile)
                if data then
                    local ok, applyErr = pcall(Core.applyLoadedImage, data, stepOrErr)
                    if not ok then
                        Core.setStatus(L("status_error"))
                        mercNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    mercNotify({Title = L("error"), Content = stepOrErr or L("pick_file"), Duration = 6})
                end
            end)
        end,
    })

    local urlSec = tab:Section({Name = L("section_url")})
    urlSec:Textbox({
        Name = "PNG URL",
        Placeholder = "https://...",
        Callback = function(input)
            Config.ImgUrl = input
        end,
    })
    urlSec:Button({
        Name = L("btn_load_url"),
        Callback = function()
            local clip = (Config.ImgUrl or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if clip == "" and readclipboard then
                pcall(function() clip = readclipboard() or "" end)
            elseif clip == "" and getclipboard then
                pcall(function() clip = getclipboard() or "" end)
            end
            clip = (clip or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if clip == "" then
                mercNotify({Title = L("error"), Content = L("paste_png_url"), Duration = 4})
                return
            end
            Config.ImgUrl = clip
            Core.clearPreview()
            Core.setStatus(L("status_loading"))
            task.spawn(function()
                local data, stepOrErr = Core.fetchImageFromUrl(clip)
                if data then
                    local ok, applyErr = pcall(Core.applyLoadedImage, data, stepOrErr)
                    if not ok then
                        Core.setStatus(L("status_error"))
                        mercNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    mercNotify({Title = L("error"), Content = stepOrErr or L("error"), Duration = 6})
                end
            end)
        end,
    })

    local cfgSec = tab:Section({Name = "Config"})
    cfgSec:Dropdown({
        Name = L("dropdown_block"),
        Items = Core.BlockTypes,
        StartingText = Config.BlockType,
        Callback = function(opt)
            Config.BlockType = opt
            mercNotify({
                Title = L("block_count"),
                Content = opt .. L("you_have", Core.getUserBlockCount(opt)),
                Duration = 3,
            })
        end,
    })

    cfgSec:Slider({
        Name = L("slider_block_size"),
        Min = 5,
        Max = 50,
        Default = math.floor(Config.BlockSize * 10),
        Callback = function(v)
            Config.BlockSize = v / 10
        end,
    })

    cfgSec:Slider({
        Name = L("slider_max_blocks"),
        Min = 50,
        Max = 10000,
        Default = Config.MaxBlocks,
        Callback = function(v)
            Config.MaxBlocks = math.floor(v)
        end,
    })

    cfgSec:Slider({
        Name = L("slider_move_step"),
        Min = 1,
        Max = 50,
        Default = Config.MoveStep,
        Callback = function(v)
            Config.MoveStep = math.floor(v)
        end,
    })

    local statusLabel = tab:Label({Text = L("status_pick")})
    Core.setStatusLabel(function(text)
        statusLabel:SetText(text)
    end)

    local previewSec = tab:Section({Name = L("btn_preview")})
    local previewToggleEl = previewSec:Toggle({
        Name = L("btn_preview"),
        StartingState = false,
        Callback = function(state)
            Config.PreviewEnabled = state
            if state then
                task.spawn(Core.buildPreview)
            else
                Core.clearPreview(true)
            end
        end,
    })
    Core.setPreviewToggle({
        Set = function(_, state)
            previewToggleEl:SetState(state)
        end,
    })

    previewSec:Toggle({
        Name = L("btn_show_frame"),
        StartingState = false,
        Callback = function(state)
            local frame = workspace:FindFirstChild("ImagePreview")
            if frame then
                local pf = frame:FindFirstChild("PreviewSize")
                if pf and pf:IsA("BasePart") then
                    pf.Transparency = state and 0.4 or 1
                end
            end
        end,
    })

    createMoveButtons(tab)

    local buildSec = tab:Section({Name = L("section_build")})
    buildSec:Slider({
        Name = L("slider_build_speed"),
        Min = 1,
        Max = 5,
        Default = Config.BuildFastness,
        Callback = function(v)
            Config.BuildFastness = math.floor(v)
        end,
    })
    buildSec:Button({Name = L("btn_build"), Callback = function() Core.buildImage() end})
    buildSec:Button({
        Name = L("btn_stop"),
        Callback = function()
            Config.IsBuilding = false
            mercNotify({Title = L("stop"), Content = L("building_stopped"), Duration = 3})
        end,
    })
    buildSec:Button({
        Name = L("btn_clear"),
        Callback = function()
            Core.clearPreview(true)
            mercNotify({Title = L("cleared"), Content = L("preview_removed"), Duration = 2})
        end,
    })
    buildSec:Button({
        Name = L("btn_apply_compress"),
        Callback = function()
            local data, err = Core.recompressLoadedImage()
            if not data then
                mercNotify({Title = L("error"), Content = err or L("load_image_first"), Duration = 5})
            end
        end,
    })
end

local function buildModelTab(tab)
    local sec = tab:Section({Name = L("folder_models")})
    local modelFiles = Core.getModelFileList()
    local selectedModel = modelFiles[1] or ""

    local modelDropdown = sec:Dropdown({
        Name = L("dropdown_model"),
        Items = modelFiles,
        StartingText = selectedModel ~= "" and selectedModel or "Select...",
        Callback = function(opt)
            selectedModel = opt
        end,
    })

    sec:Button({
        Name = L("btn_refresh_models"),
        Callback = function()
            local files = Core.getModelFileList()
            modelDropdown:Clear()
            modelDropdown:AddItems(files)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedModel = files[1]
                modelDropdown:Set(files[1])
            end
        end,
    })

    sec:Slider({
        Name = L("slider_model_scale"),
        Min = 5,
        Max = 100,
        Default = math.floor((Config.ModelScale or 1) * 10),
        Callback = function(v)
            Config.ModelScale = v / 10
        end,
    })

    sec:Toggle({
        Name = L("toggle_flip_y"),
        StartingState = Config.ModelFlipY,
        Callback = function(v)
            Config.ModelFlipY = v
        end,
    })

    sec:Slider({
        Name = L("slider_max_blocks"),
        Min = 50,
        Max = 10000,
        Default = Config.ModelMaxBlocks or Config.MaxBlocks,
        Callback = function(v)
            Config.ModelMaxBlocks = math.floor(v)
        end,
    })

    local modelStatus = sec:Label({Text = L("status_model_pick")})
    Core.setModelStatusLabel({
        Set = function(_, text)
            modelStatus:SetText(text)
        end,
    })

    sec:Button({
        Name = L("btn_load_model"),
        Callback = function()
            Core.clearPreview(true)
            task.spawn(function()
                local count, err = Core.loadOBJByName(selectedModel)
                if count then
                    mercNotify({Title = "OBJ", Content = L("obj_loaded", count), Duration = 5})
                else
                    mercNotify({Title = L("obj_error"), Content = err or L("obj_fail"), Duration = 6})
                end
            end)
        end,
    })

    createMoveButtons(tab)

    sec:Button({Name = L("btn_build_model"), Callback = function() Core.buildImage() end})
end

local function buildFarmTab(tab)
    local sec = tab:Section({Name = L("tab_farm")})
    local FarmState = Core.FarmState

    sec:Toggle({
        Name = "Anti-Afk",
        StartingState = FarmState.AntiAfk,
        Callback = function(s)
            FarmState.AntiAfk = s
        end,
    })

    sec:Toggle({
        Name = "AutoFarm",
        StartingState = false,
        Callback = function(state)
            FarmState.Enabled = state
            _G.FarmEnabled = state
            if state then
                FarmState.StartTime = tick()
                FarmState.StartGold = Core.getPlayerGold()
                FarmState.StartGoldBlocks = Core.getUserBlockCount("GoldBlock")
                Core.farmNotify("Farm", L("farm_started"))
                task.spawn(function()
                    while FarmState.Enabled do
                        pcall(function()
                            local Stages = workspace.BoatStages.NormalStages
                            local plr = game:GetService("Players").LocalPlayer
                            for i = 1, 10 do
                                if not FarmState.Enabled then
                                    break
                                end
                                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                                    plr.Character.HumanoidRootPart.CFrame =
                                        Stages["CaveStage" .. i].DarknessPart.CFrame
                                end
                                task.wait(0.12)
                            end
                            if FarmState.Enabled then
                                workspace.ClaimRiverResultsGold:FireServer()
                                task.wait(0.4)
                                workspace.ChangeCharacter:FireServer("PenguinCharacter")
                            end
                        end)
                        task.wait(0.5)
                    end
                end)
            else
                Core.farmNotify("Farm", L("farm_stopped"))
            end
        end,
    })

    sec:Toggle({
        Name = "Make it Silent",
        StartingState = FarmState.Silent,
        Callback = function(s)
            FarmState.Silent = s
        end,
    })

    sec:Button({Name = "Save Configuration", Callback = Core.saveFarmConfig})
    sec:Button({
        Name = "Load Configuration",
        Callback = function()
            Core.loadFarmConfig()
            Core.farmNotify(L("config"), L("farm_loaded"))
        end,
    })
end

local function buildPlayerTab(tab)
    local sec = tab:Section({Name = L("tab_player")})
    sec:Button({
        Name = L("tp_zone"),
        Callback = function()
            local char = game:GetService("Players").LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local zone = Core.getBuildZone()
            if hrp and zone then
                hrp.CFrame = CFrame.new(zone.Position + Vector3.new(0, 25, -40))
                mercNotify({Title = L("tp_done"), Content = L("tp_zone"), Duration = 3})
            else
                mercNotify({Title = L("error"), Content = L("tp_fail"), Duration = 4})
            end
        end,
    })
    sec:Button({
        Name = L("reset_char"),
        Callback = function()
            pcall(function()
                workspace.ChangeCharacter:FireServer("PenguinCharacter")
            end)
            mercNotify({Title = L("reset_done"), Content = L("reset_char"), Duration = 3})
        end,
    })
    createMoveButtons(tab)
end

local function buildBlockTab(tab)
    local sec = tab:Section({Name = L("blocks_header")})
    local selectedBlock = Config.BlockType

    sec:Dropdown({
        Name = L("dropdown_block"),
        Items = Core.BlockTypes,
        StartingText = selectedBlock,
        Callback = function(opt)
            selectedBlock = opt
            Config.BlockType = opt
        end,
    })

    sec:Button({
        Name = L("check_blocks"),
        Callback = function()
            local cnt = Core.getUserBlockCount(selectedBlock)
            mercNotify({Title = L("block_count"), Content = selectedBlock .. L("you_have", cnt), Duration = 3})
        end,
    })

    sec:Button({
        Name = L("check_all"),
        Callback = function()
            local n = 0
            for _, bt in ipairs(Core.BlockTypes) do
                if Core.getUserBlockCount(bt) > 0 then
                    n += 1
                end
            end
            mercNotify({Title = L("blocks_header"), Content = tostring(n) .. " types", Duration = 4})
        end,
    })
end

local function buildSettingsTab(tab)
    local sec = tab:Section({Name = L("hub_tab")})
    sec:Dropdown({
        Name = L("hub_lang"),
        Items = {"English", "Русский"},
        StartingText = Core.getLocale() == "ru" and "Русский" or "English",
        Callback = function(opt)
            local newLocale = (opt == "Русский") and "ru" or "en"
            if newLocale ~= Core.getLocale() then
                Core.setLocale(newLocale)
                mercNotify({Title = L("hub_lang"), Content = L("lang_changed"), Duration = 3})
                task.defer(buildUI)
            end
        end,
    })

    if type(BABFT.ReturnToHub) == "function" then
        sec:Button({
            Name = L("mod_back_ui"),
            Callback = function()
                BABFT.ReturnToHub()
            end,
        })
    end
end

function buildUI()
    destroyGUI()

    local GUI = Mercury:Create({
        Name = "BABFT",
        Size = UDim2.fromOffset(580, 440),
        Theme = Mercury.Themes.Dark,
        Link = "https://github.com/kotofey99/babfbft",
    })

    buildImageTab(GUI:Tab({Name = L("tab_image")}))
    buildModelTab(GUI:Tab({Name = L("tab_model")}))
    buildFarmTab(GUI:Tab({Name = L("tab_farm")}))
    buildPlayerTab(GUI:Tab({Name = L("tab_player")}))
    buildBlockTab(GUI:Tab({Name = L("tab_blocks")}))
    buildSettingsTab(GUI:Tab({Name = L("hub_tab")}))
end

local ok, err = pcall(buildUI)
if not ok then
    warn("[BABFT Mercury module]", err)
    destroyGUI()
    return function() end
end

return function()
    Core.Cleanup()
    destroyGUI()
end
