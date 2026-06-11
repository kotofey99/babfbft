-- BABFT module: LinoriaLib
if game.PlaceId ~= 537413528 then
    return function() end
end

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT

local SCRIPTS = "https://raw.githubusercontent.com/kotofey99/babfbft/main/scripts"
local REPO = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

local function linNotify(opts)
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
    warn("[BABFT Linoria] core error:", Core)
    return function() end
end

Core.Init({Notify = linNotify})

local L = Core.L
local Config = Core.Config
local Library = nil

local function unloadLibrary()
    if Library then
        pcall(function() Library:Unload() end)
        Library = nil
    end
end

local function createMoveButtons(box)
    local step = function()
        return Config.MoveStep
    end
    box:AddButton({
        Text = L("btn_fwd"),
        Func = function()
            Core.movePreview(Vector3.new(0, 0, -step()))
        end,
    })
    box:AddButton({
        Text = L("btn_back"),
        Func = function()
            Core.movePreview(Vector3.new(0, 0, step()))
        end,
    })
    box:AddButton({
        Text = L("btn_left"),
        Func = function()
            Core.movePreview(Vector3.new(-step(), 0, 0))
        end,
    })
    box:AddButton({
        Text = L("btn_right"),
        Func = function()
            Core.movePreview(Vector3.new(step(), 0, 0))
        end,
    })
    box:AddButton({
        Text = L("btn_up"),
        Func = function()
            Core.movePreview(Vector3.new(0, step(), 0))
        end,
    })
    box:AddButton({
        Text = L("btn_down"),
        Func = function()
            Core.movePreview(Vector3.new(0, -step(), 0))
        end,
    })
    box:AddButton({
        Text = L("btn_rotate"),
        Func = function()
            Core.rotatePreview(90)
        end,
    })
end

local function buildImageTab(Tab)
    local left = Tab:AddLeftGroupbox(L("folder_image"))
    local initialFiles = Core.getImageFileList()
    local selectedFile = initialFiles[1] or ""

    left:AddDropdown("BABFT_ImgFile", {
        Text = L("dropdown_image"),
        Values = initialFiles,
        Default = selectedFile,
        Callback = function(v)
            selectedFile = v
        end,
    })

    left:AddButton({
        Text = L("btn_refresh"),
        Func = function()
            local files = Core.getImageFileList()
            Options.BABFT_ImgFile:SetValues(files)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedFile = files[1]
                Options.BABFT_ImgFile:SetValue(files[1])
            end
            local count = 0
            for _, f in ipairs(files) do
                if f:sub(1, 1) ~= "(" then
                    count += 1
                end
            end
            linNotify({Title = L("list_updated"), Content = L("files_found", count), Duration = 3})
        end,
    })

    left:AddButton({
        Text = L("btn_load_file"),
        Func = function()
            Core.clearPreview()
            Core.setStatus(L("status_reading"))
            task.spawn(function()
                local data, stepOrErr = Core.loadLocalImageByName(selectedFile)
                if data then
                    local ok, applyErr = pcall(Core.applyLoadedImage, data, stepOrErr)
                    if not ok then
                        Core.setStatus(L("status_error"))
                        linNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    linNotify({Title = L("error"), Content = stepOrErr or L("pick_file"), Duration = 6})
                end
            end)
        end,
    })

    left:AddDivider()

    left:AddInput("BABFT_ImgUrl", {
        Text = L("section_url"),
        Default = Config.ImgUrl or "",
        Placeholder = "https://...",
        Callback = function(v)
            Config.ImgUrl = v
        end,
    })

    left:AddButton({
        Text = L("btn_load_url"),
        Func = function()
            local clip = (Config.ImgUrl or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if clip == "" and readclipboard then
                pcall(function() clip = readclipboard() or "" end)
            elseif clip == "" and getclipboard then
                pcall(function() clip = getclipboard() or "" end)
            end
            clip = (clip or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if clip == "" then
                linNotify({Title = L("error"), Content = L("paste_png_url"), Duration = 4})
                return
            end
            Config.ImgUrl = clip
            Options.BABFT_ImgUrl:SetValue(clip)
            Core.clearPreview()
            Core.setStatus(L("status_loading"))
            task.spawn(function()
                local data, stepOrErr = Core.fetchImageFromUrl(clip)
                if data then
                    local ok, applyErr = pcall(Core.applyLoadedImage, data, stepOrErr)
                    if not ok then
                        Core.setStatus(L("status_error"))
                        linNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    linNotify({Title = L("error"), Content = stepOrErr or L("error"), Duration = 6})
                end
            end)
        end,
    })

    local right = Tab:AddRightGroupbox("Config")
    right:AddDropdown("BABFT_BlockType", {
        Text = L("dropdown_block"),
        Values = Core.BlockTypes,
        Default = Config.BlockType,
        Callback = function(opt)
            Config.BlockType = opt
            linNotify({
                Title = L("block_count"),
                Content = opt .. L("you_have", Core.getUserBlockCount(opt)),
                Duration = 3,
            })
        end,
    })

    right:AddSlider("BABFT_BlockSize", {
        Text = L("slider_block_size"),
        Default = Config.BlockSize,
        Min = 0.5,
        Max = 5,
        Rounding = 1,
        Callback = function(v)
            Config.BlockSize = v
        end,
    })

    right:AddSlider("BABFT_MaxBlocks", {
        Text = L("slider_max_blocks"),
        Default = Config.MaxBlocks,
        Min = 50,
        Max = 10000,
        Rounding = 0,
        Callback = function(v)
            Config.MaxBlocks = math.floor(v)
        end,
    })

    right:AddSlider("BABFT_MoveStep", {
        Text = L("slider_move_step"),
        Default = Config.MoveStep,
        Min = 1,
        Max = 50,
        Rounding = 0,
        Callback = function(v)
            Config.MoveStep = math.floor(v)
        end,
    })

    local statusLabel = right:AddLabel(L("status_pick"))
    Core.setStatusLabel(function(text)
        statusLabel:SetText(text)
    end)

    right:AddToggle("BABFT_Preview", {
        Text = L("btn_preview"),
        Default = false,
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
            Toggles.BABFT_Preview:SetValue(state)
        end,
    })

    right:AddToggle("BABFT_ShowFrame", {
        Text = L("btn_show_frame"),
        Default = false,
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

    local build = Tab:AddLeftGroupbox(L("section_build"))
    createMoveButtons(build)

    build:AddSlider("BABFT_BuildSpeed", {
        Text = L("slider_build_speed"),
        Default = Config.BuildFastness,
        Min = 1,
        Max = 5,
        Rounding = 0,
        Callback = function(v)
            Config.BuildFastness = math.floor(v)
        end,
    })

    build:AddButton({
        Text = L("btn_build"),
        Func = function()
            Core.buildImage()
        end,
    })
    build:AddButton({
        Text = L("btn_stop"),
        Func = function()
            Config.IsBuilding = false
            linNotify({Title = L("stop"), Content = L("building_stopped"), Duration = 3})
        end,
    })
    build:AddButton({
        Text = L("btn_clear"),
        Func = function()
            Core.clearPreview(true)
            linNotify({Title = L("cleared"), Content = L("preview_removed"), Duration = 2})
        end,
    })
    build:AddButton({
        Text = L("btn_apply_compress"),
        Func = function()
            local data, err = Core.recompressLoadedImage()
            if not data then
                linNotify({Title = L("error"), Content = err or L("load_image_first"), Duration = 5})
            end
        end,
    })
end

local function buildModelTab(Tab)
    local box = Tab:AddLeftGroupbox(L("folder_models"))
    local modelFiles = Core.getModelFileList()
    local selectedModel = modelFiles[1] or ""

    box:AddDropdown("BABFT_ModelFile", {
        Text = L("dropdown_model"),
        Values = modelFiles,
        Default = selectedModel,
        Callback = function(opt)
            selectedModel = opt
        end,
    })

    box:AddButton({
        Text = L("btn_refresh_models"),
        Func = function()
            local files = Core.getModelFileList()
            Options.BABFT_ModelFile:SetValues(files)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedModel = files[1]
                Options.BABFT_ModelFile:SetValue(files[1])
            end
        end,
    })

    box:AddSlider("BABFT_ModelScale", {
        Text = L("slider_model_scale"),
        Default = Config.ModelScale,
        Min = 0.5,
        Max = 10,
        Rounding = 1,
        Callback = function(v)
            Config.ModelScale = v
        end,
    })

    box:AddToggle("BABFT_FlipY", {
        Text = L("toggle_flip_y"),
        Default = Config.ModelFlipY,
        Callback = function(v)
            Config.ModelFlipY = v
        end,
    })

    box:AddSlider("BABFT_ModelMaxBlocks", {
        Text = L("slider_max_blocks"),
        Default = Config.ModelMaxBlocks or Config.MaxBlocks,
        Min = 50,
        Max = 10000,
        Rounding = 0,
        Callback = function(v)
            Config.ModelMaxBlocks = math.floor(v)
        end,
    })

    local modelStatus = box:AddLabel(L("status_model_pick"))
    Core.setModelStatusLabel({
        Set = function(_, text)
            modelStatus:SetText(text)
        end,
    })

    box:AddButton({
        Text = L("btn_load_model"),
        Func = function()
            Core.clearPreview(true)
            task.spawn(function()
                local count, err = Core.loadOBJByName(selectedModel)
                if count then
                    linNotify({Title = "OBJ", Content = L("obj_loaded", count), Duration = 5})
                else
                    linNotify({Title = L("obj_error"), Content = err or L("obj_fail"), Duration = 6})
                end
            end)
        end,
    })

    createMoveButtons(box)

    box:AddButton({
        Text = L("btn_build_model"),
        Func = function()
            Core.buildImage()
        end,
    })
end

local function buildFarmTab(Tab)
    local box = Tab:AddLeftGroupbox(L("tab_farm"))
    local FarmState = Core.FarmState

    box:AddToggle("BABFT_AntiAfk", {
        Text = "Anti-Afk",
        Default = FarmState.AntiAfk,
        Callback = function(s)
            FarmState.AntiAfk = s
        end,
    })

    box:AddToggle("BABFT_AutoFarm", {
        Text = "AutoFarm",
        Default = false,
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

    box:AddToggle("BABFT_Silent", {
        Text = "Make it Silent",
        Default = FarmState.Silent,
        Callback = function(s)
            FarmState.Silent = s
        end,
    })

    box:AddButton({Text = "Save Configuration", Func = Core.saveFarmConfig})
    box:AddButton({
        Text = "Load Configuration",
        Func = function()
            Core.loadFarmConfig()
            Core.farmNotify(L("config"), L("farm_loaded"))
        end,
    })
end

local function buildPlayerTab(Tab)
    local box = Tab:AddLeftGroupbox(L("tab_player"))
    box:AddButton({
        Text = L("tp_zone"),
        Func = function()
            local char = game:GetService("Players").LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local zone = Core.getBuildZone()
            if hrp and zone then
                hrp.CFrame = CFrame.new(zone.Position + Vector3.new(0, 25, -40))
                linNotify({Title = L("tp_done"), Content = L("tp_zone"), Duration = 3})
            else
                linNotify({Title = L("error"), Content = L("tp_fail"), Duration = 4})
            end
        end,
    })
    box:AddButton({
        Text = L("reset_char"),
        Func = function()
            pcall(function()
                workspace.ChangeCharacter:FireServer("PenguinCharacter")
            end)
            linNotify({Title = L("reset_done"), Content = L("reset_char"), Duration = 3})
        end,
    })
    createMoveButtons(box)
end

local function buildBlockTab(Tab)
    local box = Tab:AddLeftGroupbox(L("blocks_header"))
    local selectedBlock = Config.BlockType

    box:AddDropdown("BABFT_BlockPick", {
        Text = L("dropdown_block"),
        Values = Core.BlockTypes,
        Default = selectedBlock,
        Callback = function(opt)
            selectedBlock = opt
            Config.BlockType = opt
        end,
    })

    box:AddButton({
        Text = L("check_blocks"),
        Func = function()
            local cnt = Core.getUserBlockCount(selectedBlock)
            linNotify({Title = L("block_count"), Content = selectedBlock .. L("you_have", cnt), Duration = 3})
        end,
    })

    box:AddButton({
        Text = L("check_all"),
        Func = function()
            local n = 0
            for _, bt in ipairs(Core.BlockTypes) do
                if Core.getUserBlockCount(bt) > 0 then
                    n += 1
                end
            end
            linNotify({Title = L("blocks_header"), Content = tostring(n) .. " types", Duration = 4})
        end,
    })
end

local function buildSettingsTab(Tab)
    local box = Tab:AddLeftGroupbox(L("hub_tab"))
    box:AddDropdown("BABFT_Locale", {
        Text = L("hub_lang"),
        Values = {"English", "Русский"},
        Default = Core.getLocale() == "ru" and "Русский" or "English",
        Callback = function(opt)
            local newLocale = (opt == "Русский") and "ru" or "en"
            if newLocale ~= Core.getLocale() then
                Core.setLocale(newLocale)
                linNotify({Title = L("hub_lang"), Content = L("lang_changed"), Duration = 3})
                task.defer(buildUI)
            end
        end,
    })

    if type(BABFT.ReturnToHub) == "function" then
        box:AddButton({
            Text = L("mod_back_ui"),
            Func = function()
                BABFT.ReturnToHub()
            end,
        })
    end
end

function buildUI()
    unloadLibrary()

    Library = loadstring(game:HttpGet(REPO .. "Library.lua", true))()

    local Window = Library:CreateWindow({
        Title = "BABFT",
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2,
    })

    local Tabs = {
        Image = Window:AddTab(L("tab_image")),
        Model = Window:AddTab(L("tab_model")),
        Farm = Window:AddTab(L("tab_farm")),
        Player = Window:AddTab(L("tab_player")),
        Blocks = Window:AddTab(L("tab_blocks")),
        Settings = Window:AddTab(L("hub_tab")),
    }

    buildImageTab(Tabs.Image)
    buildModelTab(Tabs.Model)
    buildFarmTab(Tabs.Farm)
    buildPlayerTab(Tabs.Player)
    buildBlockTab(Tabs.Blocks)
    buildSettingsTab(Tabs.Settings)
end

local ok, err = pcall(buildUI)
if not ok then
    warn("[BABFT Linoria module]", err)
    unloadLibrary()
    return function() end
end

return function()
    Core.Cleanup()
    unloadLibrary()
end
