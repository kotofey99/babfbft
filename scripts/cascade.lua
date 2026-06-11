-- BABFT module: CascadeUI
if game.PlaceId ~= 537413528 then
    return function() end
end

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT

local SCRIPTS = "https://raw.githubusercontent.com/kotofey99/babfbft/main/scripts"

local function cascadeNotify(opts)
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
    warn("[BABFT Cascade] core error:", Core)
    return function() end
end

local CascadeUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/SquidGurr/CascadeUI/main/CascadeUI.lua", true))()

local Window = nil
local previewToggleRef = nil

Core.Init({Notify = cascadeNotify})

local L = Core.L
local Config = Core.Config

local function destroyWindow()
    pcall(function()
        if Window and Window.Destroy then
            Window:Destroy()
        end
    end)
    Window = nil
end

local function createMoveButtons(section)
    local step = function() return Config.MoveStep end
    section:CreateButton({
        Name = L("btn_fwd"),
        Callback = function() Core.movePreview(Vector3.new(0, 0, -step())) end,
    })
    section:CreateButton({
        Name = L("btn_back"),
        Callback = function() Core.movePreview(Vector3.new(0, 0, step())) end,
    })
    section:CreateButton({
        Name = L("btn_left"),
        Callback = function() Core.movePreview(Vector3.new(-step(), 0, 0)) end,
    })
    section:CreateButton({
        Name = L("btn_right"),
        Callback = function() Core.movePreview(Vector3.new(step(), 0, 0)) end,
    })
    section:CreateButton({
        Name = L("btn_up"),
        Callback = function() Core.movePreview(Vector3.new(0, step(), 0)) end,
    })
    section:CreateButton({
        Name = L("btn_down"),
        Callback = function() Core.movePreview(Vector3.new(0, -step(), 0)) end,
    })
    section:CreateButton({
        Name = L("btn_rotate"),
        Callback = function() Core.rotatePreview(90) end,
    })
end

local function buildImageTab(tab)
    local filesSec = tab:CreateSection(L("folder_image"))
    local initialFiles = Core.getImageFileList()
    local selectedFile = initialFiles[1] or ""

    local fileDropdown = filesSec:CreateDropdown({
        Name = L("dropdown_image"),
        Options = initialFiles,
        Default = selectedFile,
        Callback = function(opt) selectedFile = opt end,
    })

    filesSec:CreateButton({
        Name = L("btn_refresh"),
        Callback = function()
            local files = Core.getImageFileList()
            fileDropdown:Refresh(files, false)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedFile = files[1]
                fileDropdown:Set(files[1])
            end
            local count = 0
            for _, f in ipairs(files) do
                if f:sub(1, 1) ~= "(" then count += 1 end
            end
            cascadeNotify({Title = L("list_updated"), Content = L("files_found", count), Duration = 3})
        end,
    })

    filesSec:CreateButton({
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
                        cascadeNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    cascadeNotify({Title = L("error"), Content = stepOrErr or L("pick_file"), Duration = 6})
                end
            end)
        end,
    })

    local urlSec = tab:CreateSection(L("section_url"))
    urlSec:CreateButton({
        Name = L("btn_load_url") .. " (clipboard)",
        Callback = function()
            local clip = ""
            if readclipboard then
                pcall(function() clip = readclipboard() or "" end)
            elseif getclipboard then
                pcall(function() clip = getclipboard() or "" end)
            end
            clip = (clip or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if clip == "" then
                cascadeNotify({Title = L("error"), Content = L("paste_png_url"), Duration = 4})
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
                        cascadeNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    cascadeNotify({Title = L("error"), Content = stepOrErr or L("error"), Duration = 6})
                end
            end)
        end,
    })

    local cfgSec = tab:CreateSection("Config")
    cfgSec:CreateDropdown({
        Name = L("dropdown_block"),
        Options = Core.BlockTypes,
        Default = Config.BlockType,
        Callback = function(opt)
            Config.BlockType = opt
            cascadeNotify({
                Title = L("block_count"),
                Content = opt .. L("you_have", Core.getUserBlockCount(opt)),
                Duration = 3,
            })
        end,
    })

    cfgSec:CreateSlider({
        Name = L("slider_block_size"),
        Min = 0.5,
        Max = 5,
        Default = Config.BlockSize,
        Callback = function(v) Config.BlockSize = v end,
    })

    local maxSlider = cfgSec:CreateSlider({
        Name = L("slider_max_blocks"),
        Min = 50,
        Max = 10000,
        Default = Config.MaxBlocks,
        Callback = function(v) Config.MaxBlocks = math.floor(v) end,
    })

    cfgSec:CreateSlider({
        Name = L("slider_move_step"),
        Min = 1,
        Max = 50,
        Default = Config.MoveStep,
        Callback = function(v) Config.MoveStep = math.floor(v) end,
    })

    local previewSec = tab:CreateSection(L("btn_preview"))
    previewToggleRef = previewSec:CreateToggle({
        Name = L("btn_preview"),
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
    Core.setPreviewToggle(previewToggleRef)

    previewSec:CreateToggle({
        Name = L("btn_show_frame"),
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

    local moveSec = tab:CreateSection(L("section_move"))
    createMoveButtons(moveSec)

    local buildSec = tab:CreateSection(L("section_build"))
    buildSec:CreateSlider({
        Name = L("slider_build_speed"),
        Min = 1,
        Max = 5,
        Default = Config.BuildFastness,
        Callback = function(v) Config.BuildFastness = math.floor(v) end,
    })
    buildSec:CreateButton({
        Name = L("btn_build"),
        Callback = function()
            Core.buildImage()
        end,
    })
    buildSec:CreateButton({
        Name = L("btn_stop"),
        Callback = function()
            Config.IsBuilding = false
            cascadeNotify({Title = L("stop"), Content = L("building_stopped"), Duration = 3})
        end,
    })
    buildSec:CreateButton({
        Name = L("btn_clear"),
        Callback = function()
            Core.clearPreview(true)
            cascadeNotify({Title = L("cleared"), Content = L("preview_removed"), Duration = 2})
        end,
    })
    buildSec:CreateButton({
        Name = L("btn_apply_compress"),
        Callback = function()
            local data, err = Core.recompressLoadedImage()
            if not data then
                cascadeNotify({Title = L("error"), Content = err or L("load_image_first"), Duration = 5})
            end
        end,
    })
end

local function buildModelTab(tab)
    local sec = tab:CreateSection(L("folder_models"))
    local modelFiles = Core.getModelFileList()
    local selectedModel = modelFiles[1] or ""

    local modelDropdown = sec:CreateDropdown({
        Name = L("dropdown_model"),
        Options = modelFiles,
        Default = selectedModel,
        Callback = function(opt) selectedModel = opt end,
    })

    sec:CreateButton({
        Name = L("btn_refresh_models"),
        Callback = function()
            local files = Core.getModelFileList()
            modelDropdown:Refresh(files, false)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedModel = files[1]
                modelDropdown:Set(files[1])
            end
        end,
    })

    sec:CreateSlider({
        Name = L("slider_model_scale"),
        Min = 0.5,
        Max = 10,
        Default = Config.ModelScale,
        Callback = function(v) Config.ModelScale = v end,
    })

    sec:CreateToggle({
        Name = L("toggle_flip_y"),
        Default = Config.ModelFlipY,
        Callback = function(v) Config.ModelFlipY = v end,
    })

    sec:CreateSlider({
        Name = L("slider_max_blocks"),
        Min = 50,
        Max = 10000,
        Default = Config.ModelMaxBlocks or Config.MaxBlocks,
        Callback = function(v) Config.ModelMaxBlocks = math.floor(v) end,
    })

    sec:CreateButton({
        Name = L("btn_load_model"),
        Callback = function()
            Core.clearPreview(true)
            task.spawn(function()
                local count, err = Core.loadOBJByName(selectedModel)
                if count then
                    cascadeNotify({Title = "OBJ", Content = L("obj_loaded", count), Duration = 5})
                else
                    cascadeNotify({Title = L("obj_error"), Content = err or L("obj_fail"), Duration = 6})
                end
            end)
        end,
    })

    createMoveButtons(sec)

    sec:CreateButton({
        Name = L("btn_build_model"),
        Callback = function() Core.buildImage() end,
    })
end

local function buildFarmTab(tab)
    local sec = tab:CreateSection(L("tab_farm"))
    local FarmState = Core.FarmState

    sec:CreateToggle({
        Name = "Anti-Afk",
        Default = FarmState.AntiAfk,
        Callback = function(s) FarmState.AntiAfk = s end,
    })

    sec:CreateToggle({
        Name = "AutoFarm",
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
                                if not FarmState.Enabled then break end
                                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                                    plr.Character.HumanoidRootPart.CFrame = Stages["CaveStage" .. i].DarknessPart.CFrame
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

    sec:CreateToggle({
        Name = "Make it Silent",
        Default = FarmState.Silent,
        Callback = function(s) FarmState.Silent = s end,
    })

    sec:CreateButton({Name = "Save Configuration", Callback = Core.saveFarmConfig})
    sec:CreateButton({
        Name = "Load Configuration",
        Callback = function()
            Core.loadFarmConfig()
            Core.farmNotify(L("config"), L("farm_loaded"))
        end,
    })
end

local function buildPlayerTab(tab)
    local sec = tab:CreateSection(L("tab_player"))
    sec:CreateButton({
        Name = L("tp_zone"),
        Callback = function()
            local char = game:GetService("Players").LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local zone = Core.getBuildZone()
            if hrp and zone then
                hrp.CFrame = CFrame.new(zone.Position + Vector3.new(0, 25, -40))
                cascadeNotify({Title = L("tp_done"), Content = L("tp_zone"), Duration = 3})
            else
                cascadeNotify({Title = L("error"), Content = L("tp_fail"), Duration = 4})
            end
        end,
    })
    sec:CreateButton({
        Name = L("reset_char"),
        Callback = function()
            pcall(function() workspace.ChangeCharacter:FireServer("PenguinCharacter") end)
            cascadeNotify({Title = L("reset_done"), Content = L("reset_char"), Duration = 3})
        end,
    })
    createMoveButtons(sec)
end

local function buildBlockTab(tab)
    local sec = tab:CreateSection(L("blocks_header"))
    local selectedBlock = Config.BlockType

    local blockDropdown = sec:CreateDropdown({
        Name = L("dropdown_block"),
        Options = Core.BlockTypes,
        Default = selectedBlock,
        Callback = function(opt)
            selectedBlock = opt
            Config.BlockType = opt
        end,
    })

    sec:CreateButton({
        Name = L("check_blocks"),
        Callback = function()
            local cnt = Core.getUserBlockCount(selectedBlock)
            cascadeNotify({Title = L("block_count"), Content = selectedBlock .. L("you_have", cnt), Duration = 3})
        end,
    })

    sec:CreateButton({
        Name = L("check_all"),
        Callback = function()
            local n = 0
            for _, bt in ipairs(Core.BlockTypes) do
                if Core.getUserBlockCount(bt) > 0 then n += 1 end
            end
            cascadeNotify({Title = L("blocks_header"), Content = tostring(n) .. " types", Duration = 4})
        end,
    })
end

local function buildSettingsTab(tab)
    local sec = tab:CreateSection(L("hub_tab"))
    sec:CreateDropdown({
        Name = L("hub_lang"),
        Options = {"English", "Русский"},
        Default = Core.getLocale() == "ru" and "Русский" or "English",
        Callback = function(opt)
            local newLocale = (opt == "Русский") and "ru" or "en"
            if newLocale ~= Core.getLocale() then
                Core.setLocale(newLocale)
                cascadeNotify({Title = L("hub_lang"), Content = L("lang_changed"), Duration = 3})
                task.defer(buildUI)
            end
        end,
    })

    if type(BABFT.ReturnToHub) == "function" then
        sec:CreateButton({
            Name = L("mod_back_ui"),
            Callback = function()
                if type(BABFT.CleanupModule) == "function" then
                    BABFT.CleanupModule()
                end
                BABFT.ReturnToHub()
            end,
        })
    end
end

function buildUI()
    destroyWindow()
    Window = CascadeUI:CreateWindow({
        Title = "BABFT",
        Size = UDim2.new(0, 580, 0, 440),
        Position = UDim2.new(0.5, -290, 0.5, -220),
    })

    buildImageTab(Window:CreateTab(L("tab_image")))
    buildModelTab(Window:CreateTab(L("tab_model")))
    buildFarmTab(Window:CreateTab(L("tab_farm")))
    buildPlayerTab(Window:CreateTab(L("tab_player")))
    buildBlockTab(Window:CreateTab(L("tab_blocks")))
    buildSettingsTab(Window:CreateTab(L("hub_tab")))
end

buildUI()

return function()
    Core.Cleanup()
    destroyWindow()
end
