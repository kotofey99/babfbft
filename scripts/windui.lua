-- BABFT module: WindUI
if game.PlaceId ~= 537413528 then
    return function() end
end

_G.BABFT = _G.BABFT or {}
local BABFT = _G.BABFT

local SCRIPTS = "https://raw.githubusercontent.com/kotofey99/babfbft/main/scripts"

local function windNotify(opts)
    opts = opts or {}
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(opts.Title or "BABFT"),
            Text = tostring(opts.Content or opts.Desc or ""),
            Duration = math.floor(opts.Duration or 5),
        })
    end)
end

local okCore, Core = pcall(function()
    return loadstring(game:HttpGet(SCRIPTS .. "/babft_core.lua?t=" .. os.time(), true))()
end)
if not okCore or not Core then
    warn("[BABFT WindUI] core error:", Core)
    return function() end
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

local Window = nil

Core.Init({Notify = windNotify})

local L = Core.L
local Config = Core.Config

local function destroyWindow()
    pcall(function()
        if Window and Window.Destroy then
            Window:Destroy()
        end
    end)
    Window = nil
    BABFT._WindModuleWindow = nil
end

local function createMoveButtons(tab)
    local step = function()
        return Config.MoveStep
    end
    local sec = tab:Section({Title = L("section_move"), Box = true, BoxBorder = true, Opened = true})
    sec:Button({
        Title = L("btn_fwd"),
        Callback = function()
            Core.movePreview(Vector3.new(0, 0, -step()))
        end,
    })
    sec:Button({
        Title = L("btn_back"),
        Callback = function()
            Core.movePreview(Vector3.new(0, 0, step()))
        end,
    })
    sec:Button({
        Title = L("btn_left"),
        Callback = function()
            Core.movePreview(Vector3.new(-step(), 0, 0))
        end,
    })
    sec:Button({
        Title = L("btn_right"),
        Callback = function()
            Core.movePreview(Vector3.new(step(), 0, 0))
        end,
    })
    sec:Button({
        Title = L("btn_up"),
        Callback = function()
            Core.movePreview(Vector3.new(0, step(), 0))
        end,
    })
    sec:Button({
        Title = L("btn_down"),
        Callback = function()
            Core.movePreview(Vector3.new(0, -step(), 0))
        end,
    })
    sec:Button({
        Title = L("btn_rotate"),
        Callback = function()
            Core.rotatePreview(90)
        end,
    })
end

local function buildImageTab(tab)
    local filesSec = tab:Section({Title = L("folder_image"), Box = true, BoxBorder = true, Opened = true})
    local initialFiles = Core.getImageFileList()
    local selectedFile = initialFiles[1] or ""

    local fileDropdown = filesSec:Dropdown({
        Title = L("dropdown_image"),
        Values = initialFiles,
        Value = selectedFile,
        Callback = function(opt)
            selectedFile = opt
        end,
    })

    filesSec:Button({
        Title = L("btn_refresh"),
        Icon = "refresh-cw",
        Callback = function()
            local files = Core.getImageFileList()
            fileDropdown:Refresh(files)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedFile = files[1]
                pcall(function() fileDropdown:Select({files[1]}) end)
            end
            local count = 0
            for _, f in ipairs(files) do
                if f:sub(1, 1) ~= "(" then
                    count += 1
                end
            end
            windNotify({Title = L("list_updated"), Content = L("files_found", count), Duration = 3})
        end,
    })

    filesSec:Button({
        Title = L("btn_load_file"),
        Icon = "file-down",
        Callback = function()
            Core.clearPreview()
            Core.setStatus(L("status_reading"))
            task.spawn(function()
                local data, stepOrErr = Core.loadLocalImageByName(selectedFile)
                if data then
                    local ok, applyErr = pcall(Core.applyLoadedImage, data, stepOrErr)
                    if not ok then
                        Core.setStatus(L("status_error"))
                        windNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    windNotify({Title = L("error"), Content = stepOrErr or L("pick_file"), Duration = 6})
                end
            end)
        end,
    })

    tab:Space()

    local urlSec = tab:Section({Title = L("section_url"), Box = true, BoxBorder = true, Opened = true})
    urlSec:Input({
        Title = "PNG URL",
        Placeholder = "https://...",
        Value = Config.ImgUrl or "",
        Callback = function(input)
            Config.ImgUrl = input
        end,
    })
    urlSec:Button({
        Title = L("btn_load_url"),
        Icon = "link",
        Callback = function()
            local clip = (Config.ImgUrl or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if clip == "" and readclipboard then
                pcall(function() clip = readclipboard() or "" end)
            elseif clip == "" and getclipboard then
                pcall(function() clip = getclipboard() or "" end)
            end
            clip = (clip or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if clip == "" then
                windNotify({Title = L("error"), Content = L("paste_png_url"), Duration = 4})
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
                        windNotify({Title = L("error"), Content = tostring(applyErr), Duration = 6})
                    end
                else
                    Core.setStatus(L("status_error"))
                    windNotify({Title = L("error"), Content = stepOrErr or L("error"), Duration = 6})
                end
            end)
        end,
    })

    tab:Space()

    local cfgSec = tab:Section({Title = "Config", Box = true, BoxBorder = true, Opened = true})
    cfgSec:Dropdown({
        Title = L("dropdown_block"),
        Values = Core.BlockTypes,
        Value = Config.BlockType,
        Callback = function(opt)
            Config.BlockType = opt
            windNotify({
                Title = L("block_count"),
                Content = opt .. L("you_have", Core.getUserBlockCount(opt)),
                Duration = 3,
            })
        end,
    })

    cfgSec:Slider({
        Title = L("slider_block_size"),
        Step = 0.1,
        Value = {Min = 0.5, Max = 5, Default = Config.BlockSize},
        Callback = function(v)
            Config.BlockSize = v
        end,
    })

    cfgSec:Slider({
        Title = L("slider_max_blocks"),
        Step = 1,
        Value = {Min = 50, Max = 10000, Default = Config.MaxBlocks},
        Callback = function(v)
            Config.MaxBlocks = math.floor(v)
        end,
    })

    cfgSec:Slider({
        Title = L("slider_move_step"),
        Step = 1,
        Value = {Min = 1, Max = 50, Default = Config.MoveStep},
        Callback = function(v)
            Config.MoveStep = math.floor(v)
        end,
    })

    tab:Space()

    local statusPara = tab:Paragraph({Title = L("status_pick"), Desc = ""})
    Core.setStatusLabel(function(text)
        pcall(function()
            if statusPara.Set then
                statusPara:Set({Title = text})
            end
        end)
    end)

    local previewSec = tab:Section({Title = L("btn_preview"), Box = true, BoxBorder = true, Opened = true})
    local previewToggleEl = previewSec:Toggle({
        Title = L("btn_preview"),
        Value = false,
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
            pcall(function()
                if previewToggleEl.Set then
                    previewToggleEl:Set(state)
                end
            end)
        end,
    })

    previewSec:Toggle({
        Title = L("btn_show_frame"),
        Value = false,
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

    tab:Space()

    local buildSec = tab:Section({Title = L("section_build"), Box = true, BoxBorder = true, Opened = true})
    buildSec:Slider({
        Title = L("slider_build_speed"),
        Step = 1,
        Value = {Min = 1, Max = 5, Default = Config.BuildFastness},
        Callback = function(v)
            Config.BuildFastness = math.floor(v)
        end,
    })
    buildSec:Button({
        Title = L("btn_build"),
        Icon = "hammer",
        Color = Color3.fromHex("#30ff6a"),
        Callback = function()
            Core.buildImage()
        end,
    })
    buildSec:Button({
        Title = L("btn_stop"),
        Icon = "square",
        Callback = function()
            Config.IsBuilding = false
            windNotify({Title = L("stop"), Content = L("building_stopped"), Duration = 3})
        end,
    })
    buildSec:Button({
        Title = L("btn_clear"),
        Icon = "trash-2",
        Callback = function()
            Core.clearPreview(true)
            windNotify({Title = L("cleared"), Content = L("preview_removed"), Duration = 2})
        end,
    })
    buildSec:Button({
        Title = L("btn_apply_compress"),
        Icon = "minimize-2",
        Callback = function()
            local data, err = Core.recompressLoadedImage()
            if not data then
                windNotify({Title = L("error"), Content = err or L("load_image_first"), Duration = 5})
            end
        end,
    })
end

local function buildModelTab(tab)
    local sec = tab:Section({Title = L("folder_models"), Box = true, BoxBorder = true, Opened = true})
    local modelFiles = Core.getModelFileList()
    local selectedModel = modelFiles[1] or ""

    local modelDropdown = sec:Dropdown({
        Title = L("dropdown_model"),
        Values = modelFiles,
        Value = selectedModel,
        Callback = function(opt)
            selectedModel = opt
        end,
    })

    sec:Button({
        Title = L("btn_refresh_models"),
        Icon = "refresh-cw",
        Callback = function()
            local files = Core.getModelFileList()
            modelDropdown:Refresh(files)
            if files[1] and files[1]:sub(1, 1) ~= "(" then
                selectedModel = files[1]
                pcall(function() modelDropdown:Select({files[1]}) end)
            end
        end,
    })

    sec:Slider({
        Title = L("slider_model_scale"),
        Step = 0.1,
        Value = {Min = 0.5, Max = 10, Default = Config.ModelScale},
        Callback = function(v)
            Config.ModelScale = v
        end,
    })

    sec:Toggle({
        Title = L("toggle_flip_y"),
        Value = Config.ModelFlipY,
        Callback = function(v)
            Config.ModelFlipY = v
        end,
    })

    sec:Slider({
        Title = L("slider_max_blocks"),
        Step = 1,
        Value = {Min = 50, Max = 10000, Default = Config.ModelMaxBlocks or Config.MaxBlocks},
        Callback = function(v)
            Config.ModelMaxBlocks = math.floor(v)
        end,
    })

    local modelStatus = sec:Paragraph({Title = L("status_model_pick"), Desc = ""})
    Core.setModelStatusLabel({
        Set = function(_, text)
            pcall(function()
                if modelStatus.Set then
                    modelStatus:Set({Title = text})
                end
            end)
        end,
    })

    sec:Button({
        Title = L("btn_load_model"),
        Icon = "box",
        Callback = function()
            Core.clearPreview(true)
            task.spawn(function()
                local count, err = Core.loadOBJByName(selectedModel)
                if count then
                    windNotify({Title = "OBJ", Content = L("obj_loaded", count), Duration = 5})
                else
                    windNotify({Title = L("obj_error"), Content = err or L("obj_fail"), Duration = 6})
                end
            end)
        end,
    })

    createMoveButtons(tab)

    sec:Button({
        Title = L("btn_build_model"),
        Icon = "hammer",
        Color = Color3.fromHex("#30ff6a"),
        Callback = function()
            Core.buildImage()
        end,
    })
end

local function buildFarmTab(tab)
    local sec = tab:Section({Title = L("tab_farm"), Box = true, BoxBorder = true, Opened = true})
    local FarmState = Core.FarmState

    sec:Toggle({
        Title = "Anti-Afk",
        Value = FarmState.AntiAfk,
        Callback = function(s)
            FarmState.AntiAfk = s
        end,
    })

    sec:Toggle({
        Title = "AutoFarm",
        Value = false,
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
        Title = "Make it Silent",
        Value = FarmState.Silent,
        Callback = function(s)
            FarmState.Silent = s
        end,
    })

    sec:Button({Title = "Save Configuration", Icon = "save", Callback = Core.saveFarmConfig})
    sec:Button({
        Title = "Load Configuration",
        Icon = "folder-open",
        Callback = function()
            Core.loadFarmConfig()
            Core.farmNotify(L("config"), L("farm_loaded"))
        end,
    })
end

local function buildPlayerTab(tab)
    local sec = tab:Section({Title = L("tab_player"), Box = true, BoxBorder = true, Opened = true})
    sec:Button({
        Title = L("tp_zone"),
        Icon = "map-pin",
        Callback = function()
            local char = game:GetService("Players").LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local zone = Core.getBuildZone()
            if hrp and zone then
                hrp.CFrame = CFrame.new(zone.Position + Vector3.new(0, 25, -40))
                windNotify({Title = L("tp_done"), Content = L("tp_zone"), Duration = 3})
            else
                windNotify({Title = L("error"), Content = L("tp_fail"), Duration = 4})
            end
        end,
    })
    sec:Button({
        Title = L("reset_char"),
        Icon = "rotate-ccw",
        Callback = function()
            pcall(function()
                workspace.ChangeCharacter:FireServer("PenguinCharacter")
            end)
            windNotify({Title = L("reset_done"), Content = L("reset_char"), Duration = 3})
        end,
    })
    createMoveButtons(tab)
end

local function buildBlockTab(tab)
    local sec = tab:Section({Title = L("blocks_header"), Box = true, BoxBorder = true, Opened = true})
    local selectedBlock = Config.BlockType

    sec:Dropdown({
        Title = L("dropdown_block"),
        Values = Core.BlockTypes,
        Value = selectedBlock,
        Callback = function(opt)
            selectedBlock = opt
            Config.BlockType = opt
        end,
    })

    sec:Button({
        Title = L("check_blocks"),
        Icon = "search",
        Callback = function()
            local cnt = Core.getUserBlockCount(selectedBlock)
            windNotify({Title = L("block_count"), Content = selectedBlock .. L("you_have", cnt), Duration = 3})
        end,
    })

    sec:Button({
        Title = L("check_all"),
        Icon = "layers",
        Callback = function()
            local n = 0
            for _, bt in ipairs(Core.BlockTypes) do
                if Core.getUserBlockCount(bt) > 0 then
                    n += 1
                end
            end
            windNotify({Title = L("blocks_header"), Content = tostring(n) .. " types", Duration = 4})
        end,
    })
end

local function buildSettingsTab(tab)
    local sec = tab:Section({Title = L("hub_tab"), Box = true, BoxBorder = true, Opened = true})
    sec:Dropdown({
        Title = L("hub_lang"),
        Values = {"English", "Русский"},
        Value = Core.getLocale() == "ru" and "Русский" or "English",
        Callback = function(opt)
            local newLocale = (opt == "Русский") and "ru" or "en"
            if newLocale ~= Core.getLocale() then
                Core.setLocale(newLocale)
                windNotify({Title = L("hub_lang"), Content = L("lang_changed"), Duration = 3})
                task.defer(buildUI)
            end
        end,
    })

    if type(BABFT.ReturnToHub) == "function" then
        sec:Button({
            Title = L("mod_back_ui"),
            Icon = "door-open",
            Callback = function()
                BABFT.ReturnToHub()
            end,
        })
    end
end

function buildUI()
    destroyWindow()

    Window = WindUI:CreateWindow({
        Title = "BABFT",
        Icon = "box",
        Author = "by Mizuhura",
        Theme = "BABFT Dark",
    })

    BABFT._WindModuleWindow = Window

    Window:Tag({
        Title = "WindUI",
        Icon = "wind",
        Color = Color3.fromHex("#30ff6a"),
    })

    buildImageTab(Window:Tab({Title = L("tab_image"), Icon = "image"}))
    buildModelTab(Window:Tab({Title = L("tab_model"), Icon = "box"}))
    buildFarmTab(Window:Tab({Title = L("tab_farm"), Icon = "coins"}))
    buildPlayerTab(Window:Tab({Title = L("tab_player"), Icon = "user"}))
    buildBlockTab(Window:Tab({Title = L("tab_blocks"), Icon = "layers"}))
    buildSettingsTab(Window:Tab({Title = L("hub_tab"), Icon = "settings"}))
end

local ok, err = pcall(buildUI)
if not ok then
    warn("[BABFT WindUI module]", err)
    return function() end
end

return function()
    Core.Cleanup()
    destroyWindow()
end
