local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local function getViewportCamera()
    local cam = Workspace.CurrentCamera
    if not cam then
        Workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
        cam = Workspace.CurrentCamera
    end
    return cam
end

local Camera = getViewportCamera()
local OriginalFOV = (Camera and Camera.FieldOfView) or 70
local targetFOV = OriginalFOV
local lerpSpeed = 8

local fadeElements = {}

local player = Players.LocalPlayer
if not player then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local EXISTING = playerGui:FindFirstChild("MultiScriptFloatingWindow")
if EXISTING then EXISTING:Destroy() end

local function toVector2(v)
    local t = typeof(v)
    if t == "Vector2" then
        return v
    elseif t == "Vector3" then
        return Vector2.new(v.X, v.Y)
    elseif t == "UDim2" then
        local cam = getViewportCamera()
        local vs = cam and cam.ViewportSize or Vector2.new(800,600)
        local absX = v.X.Scale * vs.X + v.X.Offset
        local absY = v.Y.Scale * vs.Y + v.Y.Offset
        return Vector2.new(absX, absY)
    elseif type(v) == "table" and v.X and v.Y then
        return Vector2.new(v.X, v.Y)
    else
        return Vector2.new(0,0)
    end
end

local function getViewportSize()
    local cam = getViewportCamera()
    if not cam then
        repeat task.wait() until getViewportCamera()
        cam = getViewportCamera()
    end
    return cam.ViewportSize
end

local screenSize = getViewportSize()
local baseW, baseH = 430, 410
local scale = math.min(screenSize.X / 800, screenSize.Y / 600, 1)
local winW, winH = math.floor(baseW * scale), math.floor(baseH * scale)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MultiScriptFloatingWindow"
screenGui.Parent = playerGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false

-- 置顶保护（保持不变）
do
    local TOP_DISPLAY_ORDER = 32767
    local HIGH_ZINDEX = 1000
    pcall(function() screenGui.DisplayOrder = math.min(TOP_DISPLAY_ORDER, (screenGui.DisplayOrder or 0) + 1000) end)

    local function elevateZIndices()
        pcall(function()
            for _, obj in ipairs(screenGui:GetDescendants()) do
                pcall(function()
                    if typeof(obj) == "Instance" and obj:IsA("GuiObject") then
                        if obj.ZIndex and type(obj.ZIndex) == "number" and obj.ZIndex < HIGH_ZINDEX then
                            obj.ZIndex = HIGH_ZINDEX
                        end
                    end
                end)
            end
        end)
    end

    local function getExternalMaxDisplayOrder()
        local maxOrder = 0
        for _, c in pairs(playerGui:GetChildren()) do
            if c ~= screenGui and c:IsA("ScreenGui") then
                local ok, val = pcall(function() return c.DisplayOrder end)
                if ok and type(val) == "number" and val > maxOrder then
                    maxOrder = val
                end
            end
        end
        pcall(function()
            local core = game:GetService("CoreGui")
            if core then
                for _, c in pairs(core:GetChildren()) do
                    if c:IsA("ScreenGui") then
                        local ok, val = pcall(function() return c.DisplayOrder end)
                        if ok and type(val) == "number" and val > maxOrder then
                            maxOrder = val
                        end
                    end
                end
            end
        end)
        return maxOrder
    end

    local guardDebounce = false
    local function ensureTop()
        if guardDebounce then return end
        guardDebounce = true
        task.spawn(function()
            local maxOrder = getExternalMaxDisplayOrder()
            local target = math.min(TOP_DISPLAY_ORDER, maxOrder + 1)
            pcall(function()
                if screenGui and screenGui.Parent then
                    if (screenGui.DisplayOrder or 0) < target then
                        screenGui.DisplayOrder = target
                    end
                end
            end)
            elevateZIndices()
            task.wait(0.06)
            guardDebounce = false
        end)
    end

    playerGui.ChildAdded:Connect(function(child)
        if child and child:IsA("ScreenGui") and child ~= screenGui then
            pcall(function()
                child:GetPropertyChangedSignal("DisplayOrder"):Connect(function() ensureTop() end)
            end)
            task.delay(0.02, ensureTop)
        end
    end)

    pcall(function()
        for _, c in pairs(playerGui:GetChildren()) do
            if c ~= screenGui and c:IsA("ScreenGui") then
                pcall(function() c:GetPropertyChangedSignal("DisplayOrder"):Connect(function() ensureTop() end) end)
            end
        end
    end)

    screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent or parent == nil then
            task.delay(0.05, function()
                if player and player:FindFirstChild("PlayerGui") and screenGui and not screenGui.Parent then
                    pcall(function() screenGui.Parent = player.PlayerGui end)
                    task.delay(0.03, ensureTop)
                end
            end)
        else
            task.delay(0.03, ensureTop)
        end
    end)

    task.spawn(function()
        while screenGui and screenGui.Parent do
            ensureTop()
            task.wait(1)
        end
    end)

    task.delay(0.02, function()
        ensureTop()
        elevateZIndices()
    end)
end

-- 主窗体（启动展开逻辑与主结构保持不变）
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(55, 10, 40)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 1
mainFrame.Active = true
mainFrame.Draggable = false
mainFrame.Parent = screenGui
mainFrame.ClipsDescendants = true
pcall(function() if mainFrame.ZIndex and type(mainFrame.ZIndex) == "number" then mainFrame.ZIndex = 1000 end end)
local mainUICorner = Instance.new("UICorner", mainFrame)
mainUICorner.CornerRadius = UDim.new(0, 18)
-- 初始不显示，等公告结束后再展开（为了与新公告流程配合）
mainFrame.Visible = false

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, math.floor(44 * scale))
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(110, 30, 80)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
pcall(function() if topBar.ZIndex and type(topBar.ZIndex) == "number" then topBar.ZIndex = 1001 end end)
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 18)

local titleLabel = Instance.new("TextLabel", topBar)
titleLabel.Size = UDim2.new(1, -160, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "内测版本V4.6"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = math.floor(24 * scale)
titleLabel.TextColor3 = Color3.fromRGB(255, 190, 230)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
pcall(function() if titleLabel.ZIndex and type(titleLabel.ZIndex) == "number" then titleLabel.ZIndex = 1002 end end)

local closeButton = Instance.new("TextButton", topBar)
closeButton.Size = UDim2.new(0, math.floor(38 * scale), 0, math.floor(34 * scale))
closeButton.Position = UDim2.new(1, -math.floor(44 * scale), 0, math.floor(5 * scale))
closeButton.BackgroundColor3 = Color3.fromRGB(220, 80, 150)
closeButton.Text = "🅔"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = math.floor(22 * scale)
closeButton.TextColor3 = Color3.fromRGB(255,255,255)
local closeButtonCorner = Instance.new("UICorner", closeButton)
closeButtonCorner.CornerRadius = UDim.new(0, 10)
pcall(function() if closeButton.ZIndex and type(closeButton.ZIndex) == "number" then closeButton.ZIndex = 1003 end end)
closeButton.MouseButton1Click:Connect(function()
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    pcall(function() TweenService:Create(mainFrame, tweenInfo, {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0)}):Play() end)
    task.delay(0.28, function() if screenGui and screenGui.Parent then screenGui:Destroy() end end)
end)

-- 新增：更新日志按钮（位于关闭按钮左侧）
local updateLogFrame = nil
local updateButton = Instance.new("TextButton", topBar)
updateButton.Size = UDim2.new(0, math.floor(72 * scale), 0, math.floor(34 * scale))
updateButton.Position = UDim2.new(1, -math.floor(128 * scale), 0, math.floor(5 * scale))
updateButton.BackgroundColor3 = Color3.fromRGB(150, 90, 160)
updateButton.Text = "更新日志"
updateButton.Font = Enum.Font.GothamBold
updateButton.TextSize = math.floor(14 * scale)
updateButton.TextColor3 = Color3.fromRGB(255,255,255)
updateButton.BorderSizePixel = 0
Instance.new("UICorner", updateButton).CornerRadius = UDim.new(0, 8)
pcall(function() if updateButton.ZIndex and type(updateButton.ZIndex) == "number" then updateButton.ZIndex = 1003 end end)

-- 点击动画：动态入场/出场，且支持切换（保持 mainFrame 结构不变）
local function animateShowUpdateLog()
    if not updateLogFrame or not updateLogFrame.Parent then return end
    updateLogFrame.Visible = true
    updateLogFrame.Size = UDim2.new(0, math.floor(320 * scale), 0, 0)
    updateLogFrame.Position = UDim2.new(1, -math.floor(340 * scale), 0, math.floor(62 * scale))
    updateLogFrame.BackgroundTransparency = 1
    local ulTitle = updateLogFrame:FindFirstChild("ULTitle")
    local content = updateLogFrame:FindFirstChild("ULContent")
    if ulTitle then ulTitle.TextTransparency = 1 end
    if content then content.TextTransparency = 1 end

    pcall(function()
        local tSize = TweenService:Create(updateLogFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, math.floor(320 * scale), 0, math.floor(150 * scale)), BackgroundTransparency = 0.08})
        local tPos = TweenService:Create(updateLogFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(1, -math.floor(340 * scale), 0, math.floor(50 * scale))})
        tSize:Play(); tPos:Play()
        tSize.Completed:Connect(function()
            if ulTitle then TweenService:Create(ulTitle, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play() end
            if content then TweenService:Create(content, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play() end
        end)
    end)
end

local function animateHideUpdateLog(destroyAfter)
    if not updateLogFrame or not updateLogFrame.Parent then return end
    local ulTitle = updateLogFrame:FindFirstChild("ULTitle")
    local content = updateLogFrame:FindFirstChild("ULContent")
    pcall(function()
        if ulTitle then TweenService:Create(ulTitle, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play() end
        if content then TweenService:Create(content, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play() end
        local tSize = TweenService:Create(updateLogFrame, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, math.floor(320 * scale), 0, 0), BackgroundTransparency = 1})
        local tPos = TweenService:Create(updateLogFrame, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(1, -math.floor(340 * scale), 0, math.floor(62 * scale))})
        tSize:Play(); tPos:Play()
        tSize.Completed:Connect(function()
            if destroyAfter then
                if updateLogFrame and updateLogFrame.Parent then updateLogFrame:Destroy() end
                updateLogFrame = nil
            else
                if updateLogFrame and updateLogFrame.Parent then updateLogFrame.Visible = false end
            end
        end)
    end)
end

updateButton.MouseButton1Click:Connect(function()
    if updateLogFrame and updateLogFrame.Parent and updateLogFrame.Visible then
        animateHideUpdateLog(false)
        return
    end
    if updateLogFrame and updateLogFrame.Parent and (not updateLogFrame.Visible) then
        animateShowUpdateLog()
        return
    end

    updateLogFrame = Instance.new("Frame", mainFrame)
    updateLogFrame.Name = "UpdateLogFrame"
    updateLogFrame.Size = UDim2.new(0, math.floor(320 * scale), 0, math.floor(150 * scale))
    updateLogFrame.Position = UDim2.new(1, -math.floor(340 * scale), 0, math.floor(50 * scale))
    updateLogFrame.BackgroundColor3 = Color3.fromRGB(35, 8, 30)
    updateLogFrame.BackgroundTransparency = 1
    updateLogFrame.BorderSizePixel = 0
    updateLogFrame.ZIndex = 4000
    updateLogFrame.Visible = false
    Instance.new("UICorner", updateLogFrame).CornerRadius = UDim.new(0, 10)

    local ulTitle = Instance.new("TextLabel", updateLogFrame)
    ulTitle.Name = "ULTitle"
    ulTitle.Size = UDim2.new(1, -48, 0, math.floor(30 * scale))
    ulTitle.Position = UDim2.new(0, 12, 0, 8)
    ulTitle.BackgroundTransparency = 1
    ulTitle.Text = "更新日志"
    ulTitle.Font = Enum.Font.GothamBold
    ulTitle.TextSize = math.floor(16 * scale)
    ulTitle.TextColor3 = Color3.fromRGB(255, 190, 230)
    ulTitle.TextXAlignment = Enum.TextXAlignment.Left
    ulTitle.ZIndex = 4001
    ulTitle.TextTransparency = 1

    local ulClose = Instance.new("TextButton", updateLogFrame)
    ulClose.Size = UDim2.new(0, 28, 0, 28)
    ulClose.Position = UDim2.new(1, -36, 0, 8)
    ulClose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    ulClose.Text = "X"
    ulClose.Font = Enum.Font.SourceSansBold
    ulClose.TextSize = 16
    ulClose.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", ulClose).CornerRadius = UDim.new(0, 6)
    ulClose.ZIndex = 4002
    ulClose.MouseButton1Click:Connect(function()
        animateHideUpdateLog(false)
    end)

    local content = Instance.new("TextLabel", updateLogFrame)
    content.Name = "ULContent"
    content.Size = UDim2.new(1, -24, 1, -52)
    content.Position = UDim2.new(0, 12, 0, 40)
    content.BackgroundTransparency = 1
    content.TextWrapped = true
    content.Text = "优化脚本流畅度/优化驱动/提高内置注入器运行流畅度"
    content.Font = Enum.Font.Gotham
    content.TextSize = math.floor(14 * scale)
    content.TextColor3 = Color3.fromRGB(255, 200, 230)
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextYAlignment = Enum.TextYAlignment.Top
    content.ZIndex = 4001
    content.TextTransparency = 1

    -- 使用动画显示
    animateShowUpdateLog()
end)

local fixedColors = {
    Color3.fromRGB(220,60,60),
    Color3.fromRGB(255,220,60),
    Color3.fromRGB(0,220,90),
}
for i=1,3 do
    local f = Instance.new("Frame", topBar)
    f.Size = UDim2.new(0, math.floor(16*scale), 0, math.floor(16*scale))
    f.Position = UDim2.new(1, -math.floor(180*scale) - (i-1)*math.floor(20*scale), 0.5, -math.floor(8*scale))
    f.BackgroundColor3 = fixedColors[i]
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(1,0)
    pcall(function() if f.ZIndex and type(f.ZIndex) == "number" then f.ZIndex = 1004 end end)
end

-- 运行状态灯：位置调整为“在三个小灯的右侧，间距 5px”，避免覆盖其他功能或更新日志
local statusLight = Instance.new("Frame", topBar)
statusLight.Size = UDim2.new(0, math.floor(20*scale), 0, math.floor(20*scale))
statusLight.Position = UDim2.new(1, -math.floor(180*scale) + math.floor(16*scale) + 5, 0.5, -math.floor(10*scale))
statusLight.BackgroundColor3 = Color3.fromRGB(120,120,120)
statusLight.BorderSizePixel = 0
Instance.new("UICorner", statusLight).CornerRadius = UDim.new(1,0)
pcall(function() if statusLight.ZIndex and type(statusLight.ZIndex) == "number" then statusLight.ZIndex = 1006 end end)

local statusToken = 0
local pulseTween = nil
local function stopPulse()
    if pulseTween then
        pcall(function() pulseTween:Cancel() end)
        pulseTween = nil
    end
    pcall(function()
        if statusLight and statusLight.Parent then
            statusLight.BackgroundTransparency = 0.08
        end
    end)
end

local function pulseLight(frame)
    stopPulse()
    if not frame or not frame.Parent then return end
    pcall(function() frame.BackgroundTransparency = 0.08 end)
    local info = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    pulseTween = TweenService:Create(frame, info, {BackgroundTransparency = 0.6})
    pcall(function() pulseTween:Play() end)
end

local function setStatus(status)
    statusToken = statusToken + 1
    local my = statusToken

    stopPulse()

    local color = Color3.fromRGB(120,120,120)
    local holdSeconds = nil

    if status == "running" then
        color = Color3.fromRGB(255,200,60)
        pcall(function()
            TweenService:Create(statusLight, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color}):Play()
        end)
        pulseLight(statusLight)
    elseif status == "success" then
        color = Color3.fromRGB(0,200,110)
        holdSeconds = 4
        pcall(function()
            TweenService:Create(statusLight, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color, BackgroundTransparency = 0.08}):Play()
        end)
    elseif status == "fail" then
        color = Color3.fromRGB(220,60,60)
        holdSeconds = 4
        pcall(function()
            TweenService:Create(statusLight, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color, BackgroundTransparency = 0.08}):Play()
        end)
    else
        pcall(function()
            TweenService:Create(statusLight, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color, BackgroundTransparency = 0.08}):Play()
        end)
    end

    if holdSeconds then
        task.delay(holdSeconds, function()
            if my == statusToken then
                stopPulse()
                pcall(function()
                    TweenService:Create(statusLight, TweenInfo.new(0.22), {BackgroundColor3 = Color3.fromRGB(120,120,120)}):Play()
                end)
            end
        end)
    end
end

local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, math.floor(62*scale), 0, math.floor(62*scale))
miniFrame.Position = UDim2.new(0, 80, 0, 80)
miniFrame.BackgroundColor3 = Color3.fromRGB(110,30,80)
miniFrame.Visible = false
miniFrame.Active = true
miniFrame.Draggable = true
miniFrame.Parent = screenGui
Instance.new("UICorner", miniFrame).CornerRadius = UDim.new(1,0)
local miniIcon = Instance.new("TextButton", miniFrame)
miniIcon.Size = UDim2.new(1,0,1,0)
miniIcon.BackgroundTransparency = 1
miniIcon.Text = "☰"
miniIcon.Font = Enum.Font.GothamBold
miniIcon.TextSize = math.floor(34*scale)
miniIcon.TextColor3 = Color3.fromRGB(255,190,230)
miniIcon.MouseButton1Click:Connect(function() miniFrame.Visible = false; mainFrame.Visible = true end)

local line = Instance.new("Frame", mainFrame)
line.Size = UDim2.new(1, -math.floor(32*scale), 0, 1)
line.Position = UDim2.new(0, math.floor(16*scale), 0, math.floor(54*scale))
line.BackgroundColor3 = Color3.fromRGB(140,60,110)
line.BorderSizePixel = 0

local descLabel = Instance.new("TextLabel", mainFrame)
descLabel.Size = UDim2.new(1, -math.floor(32*scale), 0, math.floor(30*scale))
descLabel.Position = UDim2.new(0, math.floor(16*scale), 0, math.floor(60*scale))
descLabel.BackgroundTransparency = 1
descLabel.Text = "选择任意功能并点击“运行”即可一键注入脚本"
descLabel.Font = Enum.Font.Gotham
descLabel.TextSize = math.floor(16 * scale)
descLabel.TextColor3 = Color3.fromRGB(255,200,230)
descLabel.TextWrapped = true

local scriptList = {
    {
        name = "MaxHub 主脚本",
        desc = "Maxhub通讯/通知",
        code = [[
script_key="QuDnnUGUqiBjOFZASOYtZPWhcsCKRieB";
_G.MaxHub = {
    ['Discord Global Chat'] = false,
    ['Maxhub Notifications'] = true
}
loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/993b07de445441e83e15ce5fde260d5f.lua"))()
        ]]
    },
    {
        name = "盗版犯罪甩飞",
        desc = "是一款犯罪辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/83808083lsy-cpu/-/refs/heads/main/message%20(3)%20(1)%20(1).txt"))()
        ]]
    },
    {
        name = "XA HUB",
        desc = "多游戏辅助",
        code = [[
loadstring(game:HttpGet("https://raw.gitcode.com/Xingtaiduan/Scripts/raw/main/Loader.lua"))()
        ]]
   
    },
    {
        name = "FE EGOR V7",
        desc = "是一款大部分游戏娱乐脚本",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/RENZXW/RENZXW-SCRIPTS/main/fakeLAGRENZXW.txt"))()
        ]]  
    
    },
    {
        name = "FE EGOR V6",
        desc = "是一款大部分游戏娱乐脚本",
        code = [[
loadstring(game:HttpGet("https://pastefy.app/5EeMRVyx/raw"))()
        ]] 
      
    },
    {
        name = "FE EGOR  V5",
        desc = "是一款大部分游戏娱乐脚本",
        code = [[
loadstring(game:HttpGet("https://pastebin.com/raw/GBmWn4eZ", true))()
        ]]  
     
    },
    {
        name = "FE EGOR V4",
        desc = "是一款大部分游戏娱乐脚本",
        code = [[
loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Roblox-Egor-Script-50669"))()
        ]]
    },
    {
        name = "VAPE V4",
        desc = "VAPE V4游戏辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua", true))()
        ]]
    },
    {
        name = "清水黑火药",
        desc = "专业黑火药脚本",
        code = [[
loadstring(game:HttpGet("\104\116\116\112\115\58\47\47\112\97\115\116\101\102\121\46\97\112\112\47\65\51\78\113\122\52\78\112\47\114\97\119"))()
        ]]
    },
    {
        name = "清风黑火药",
        desc = "专业黑火药辅助",
        code = [[
(function(v5) local l = function(...) local _ = "" for i,p in next,{...} do _ = _..string.char(p) end return _ end local x = getfenv(2) return function(v6,...) v6 = l(v6,...) return function(v1,...) v1 =l(v1,...) return function(v3,...) v3 = l(v3,...) return function(v2,...) v2 = l(v2,...) return function(v7,...) v7 = l(v7,...) v10 = (v3..v7..v6..v5..v2..v1) return function(v9,...) v9 = l(v9,...) v10 = (v3..v2..v7..v6..v5..v1..v9) return function(v8,...) v8 = l(v8,...) v10 = (v9..v5..v8..v3..v7..v6..v2) return function(v0,...) v0 = l(v0,...) v10 = (v1..v7..v0..v9..v5..v8..v6..v3..v2) return function(v4,...) v4 = l(v4,...) v10 = (v6..v4..v1..v5..v0..v8..v7..v2..v3..v9) return function(v10,...) v10 = l(v10,...) v10 = (v4..v6..v3..v1..v9..v8..v0..v2..v7..v10) return function(e) return x[l(unpack(e[1]))](game[l(unpack(e[2]))](game,v10)) end end end end end end end end end end end end)(string.char(92))(119,46,103,105,116,104,117,98,117,115,101)(47,115,107,117,114,103,102,51,48,76,70,69)(114,99,111,110,116,101,110,116,46,99,111,109)(102,47,114,101,102,115,47)(104,101,97,100,115,47,109,97)(52,48,99,98,48,70,115,112)(49,56,56,54,97,78,50,65,116)(47,116,102,54,53,56,101,90,97,83,74,49,78,71)(104,116,116,112,115,58,47,47,114,97)(105,110,47,109,70,57,71,118,51,70,120,106,81,116,79,56)({{108,111,97,100,115,116,114,105,110,103},{72,116,116,112,71,101,116}})()("qing") --z󠇗󠆖󠅱󠇖󠆝󠆒󠇗󠆄󠆘󠇔󠆪󠅾󠇗󠆋󠅸󠇕󠅸󠆙󠇘󠆑󠅼󠇔󠆨󠆪󠄜󠄐󠇕󠅼󠅵󠇖󠅻󠆜󠇔󠆭󠅶󠇔󠆨󠅽󠇙󠆉󠆀󠇔󠆪󠅾󠇗󠆋󠆤󠇖󠅾󠆕󠇕󠆄󠆞󠇕󠅽󠆆󠄜󠄐󠇕󠆌󠆘󠇕󠆀󠅴󠇗󠆗󠅽󠇘󠆗󠅶󠇙󠆒󠆁󠇕󠆩󠆣󠇕󠅿󠆠󠄘󠇕󠆖󠅲󠄲󠅙󠅜󠅙󠄲󠅙󠅜󠅙󠄙󠇘󠆖󠅱󠇖󠆡󠅲󠇕󠅵󠆣󠇖󠆣󠆘󠄜󠄐󠇘󠆟󠅴󠇘󠆞󠆪󠄜󠄐󠇕󠅺󠆐󠇗󠆮󠆔󠄜󠄐󠇗󠆗󠅱󠇘󠅱󠅺󠄜󠄐󠇖󠅺󠆅󠇕󠆨󠅱󠄜󠄐󠇗󠅲󠆩󠇘󠆥󠆎󠄜󠄐󠇖󠆄󠆦󠇘󠆇󠅿󠇗󠆝󠅹󠇕󠆒󠆎󠇕󠅺󠆐󠇘󠅾󠆧󠇕󠅿󠆆󠇘󠆥󠅴󠇖󠆪󠆀󠇖󠆍󠆑󠇔󠆫󠆦󠇗󠆊󠅴󠇘󠆑󠅼󠇔󠆨󠆪󠄞
        ]]
    },
    {
        name = "皮黑火药",
        desc = "专业黑火药脚本",
        code = [[
getgenv().XiaoPi="皮脚本-内脏与黑火药" loadstring(game:HttpGet("\104\116\116\112\115\58\47\47\114\97\119\46\103\105\116\104\117\98\117\115\101\114\99\111\110\116\101\110\116\46\99\111\109\47\120\105\97\111\112\105\55\55\47\120\105\97\111\112\105\55\55\47\114\101\102\115\47\104\101\97\100\115\47\109\97\105\110\47\82\111\98\108\111\120\45\80\105\45\71\66\45\83\99\114\105\112\116\46\108\117\97"))()
        ]]
    },
    {
        name = "内存修改FOV",
        desc = "FOV控制辅助（按需打开）",
        code = [[
print("请使用界面中的“内存修改FOV”条目来打开 FOV 控件（按需创建）。")
        ]]
    },
    {
        name = "99夜脚本",
        desc = "热门游戏辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/VapeVoidware/VW-Add/main/loader.lua", true))()
        ]]
    },
    {
        name = "自定义脚本",
        desc = "请输入你自己的代码",
        code = [[
print("请在此输入你的自定义代码")
        ]]
    }
}

local listFrame = Instance.new("Frame", mainFrame)
listFrame.Name = "ListFrame"
listFrame.Position = UDim2.new(0, math.floor(8*scale), 0, math.floor(98*scale))
listFrame.Size = UDim2.new(1, -math.floor(16*scale), 1, -math.floor(108*scale))
listFrame.BackgroundTransparency = 1

local scrollFrame = Instance.new("ScrollingFrame", listFrame)
scrollFrame.Size = UDim2.new(1,0,1,0)
scrollFrame.Position = UDim2.new(0,0,0,0)
scrollFrame.CanvasSize = UDim2.new(0,0,0,#scriptList*90*scale)
scrollFrame.ScrollBarThickness = 6
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0

local uiListLayout = Instance.new("UIListLayout", scrollFrame)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, math.floor(10*scale))
uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local contentY = uiListLayout.AbsoluteContentSize.Y
    scrollFrame.CanvasSize = UDim2.new(0,0,0, contentY + math.floor(8*scale))
end)

local function niceTween(obj, tweenInfo, props)
    local ok, tw = pcall(function() return TweenService:Create(obj, tweenInfo, props) end)
    if ok and tw then
        pcall(function() tw:Play() end)
        return tw
    end
    return nil
end

local function showRunToast(success, seconds)
    seconds = seconds or 2
    local old = playerGui:FindFirstChild("RunSuccessToast")
    if old then old:Destroy() end

    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "RunSuccessToast"
    toastGui.Parent = playerGui
    toastGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toastGui.ResetOnSpawn = false

    local toastFrame = Instance.new("Frame")
    toastFrame.Size = UDim2.new(0,220,0,56)
    local targetPos = UDim2.new(0,20,1,-80)
    local startPos = UDim2.new(0,20,1, 80)
    toastFrame.Position = startPos
    toastFrame.BackgroundColor3 = success and Color3.fromRGB(0,200,120) or Color3.fromRGB(200,60,60)
    toastFrame.BackgroundTransparency = 1
    toastFrame.BorderSizePixel = 0
    toastFrame.Parent = toastGui
    toastFrame.Active = true
    Instance.new("UICorner", toastFrame).CornerRadius = UDim.new(0,16)
    pcall(function() toastFrame.ZIndex = 4000 end)

    local label = Instance.new("TextLabel", toastFrame)
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0,16,0,0)
    label.BackgroundTransparency = 1
    label.Text = success and "运行成功" or "运行失败"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextXAlignment = Enum.TextXAlignment.Left

    local timerLabel = Instance.new("TextLabel", toastFrame)
    timerLabel.Size = UDim2.new(0,48,1,0)
    timerLabel.Position = UDim2.new(1, -54, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = tostring(seconds)
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 20
    timerLabel.TextColor3 = Color3.fromRGB(255,255,255)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Center

    local tweenIn = niceTween(toastFrame, TweenInfo.new(0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetPos, BackgroundTransparency = 0.08})
    task.spawn(function()
        while seconds > 0 do
            task.wait(1)
            seconds = seconds - 1
            if timerLabel and timerLabel.Parent then
                timerLabel.Text = tostring(seconds)
            end
        end
        local tweenOut = niceTween(toastFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = startPos, BackgroundTransparency = 1})
        if tweenOut then
            tweenOut.Completed:Connect(function()
                if toastGui and toastGui.Parent then
                    toastGui:Destroy()
                end
            end)
        else
            if toastGui and toastGui.Parent then toastGui:Destroy() end
        end
    end)
end

local currentRunPanel = nil
local function showRunPanel()
    if currentRunPanel and currentRunPanel.Parent then return end
    local vs = getViewportSize()
    local panel = Instance.new("Frame")
    panel.Name = "RunPanel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.6, 0)
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.BackgroundColor3 = Color3.fromRGB(80,20,50)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 3500
    panel.Parent = screenGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

    local label = Instance.new("TextLabel", panel)
    label.Name = "RunLabel"
    label.Size = UDim2.new(1,0,1,0)
    label.Position = UDim2.new(0,0,0,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = "正在运行..."
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = math.floor(18 * scale)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    pcall(function() label.ZIndex = 3501 end)

    currentRunPanel = panel

    local targetSize = UDim2.new(0, math.floor(320 * math.clamp(scale, 0.8, 1.2)), 0, math.floor(84 * math.clamp(scale, 0.8, 1.2)))
    local targetPos = UDim2.new(0.5, 0, 0.42, 0)

    niceTween(panel, TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = targetSize, Position = targetPos, BackgroundTransparency = 0.08})
end

local function hideRunPanel()
    if not currentRunPanel then return end
    local panel = currentRunPanel
    currentRunPanel = nil
    local tw = niceTween(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1, Position = UDim2.new(0.5,0,0.6,0)})
    if tw then
        tw.Completed:Connect(function()
            if panel and panel.Parent then panel:Destroy() end
        end)
    else
        if panel and panel.Parent then panel:Destroy() end
    end
end

local function safeLoadAndRun(code)
    if type(code) ~= "string" then
        return false, "代码必须为字符串"
    end
    code = tostring(code)
    code = code:gsub("\239\187\191", "")

    local loader = load or loadstring
    if not loader then
        return false, "此环境不支持 load 或 loadstring"
    end

    local chunk = nil
    local ok, res = pcall(function()
        local suc, c = pcall(function() return loader(code, "CustomScript", "t", _G) end)
        if suc and type(c) == "function" then return c end
        return loader(code)
    end)
    if ok then
        chunk = res
    else
        return false, ("编译错误: %s"):format(tostring(res))
    end

    if not chunk or type(chunk) ~= "function" then
        return false, ("编译错误: %s"):format(tostring(chunk))
    end

    local okRun, runRes = pcall(chunk)
    if not okRun then
        return false, ("运行时错误: %s"):format(tostring(runRes))
    end
    return true, nil
end

local runQueue = {}
local runningQueue = false
local function enqueueRun(fn)
    table.insert(runQueue, fn)
    if not runningQueue then
        runningQueue = true
        task.spawn(function()
            while #runQueue > 0 do
                local f = table.remove(runQueue, 1)
                local ok, err = pcall(f)
                if not ok then
                    warn("队列任务错误: ", err)
                    pcall(function() setStatus("fail") end)
                    pcall(function() showRunToast(false, 2) end)
                end
                task.wait(0.08)
            end
            runningQueue = false
        end)
    end
end

local function deltaRun(code) return safeLoadAndRun(code) end
local function fullInjectorRun(code) return safeLoadAndRun(code) end

-- ===== FOV UI: lazy creation with proper drag / toggle handling =====
local fovCreated = false
local fovScreenGuiRef = nil

local function ensureFOVUI()
    if fovCreated and fovScreenGuiRef and fovScreenGuiRef.Parent then
        local existingMain = fovScreenGuiRef:FindFirstChild("ControlWindow")
        if existingMain then
            existingMain.Visible = true
        end
        return
    end

    local fovScreenGui = Instance.new("ScreenGui")
    fovScreenGui.Name = "FOVControlUI"
    fovScreenGui.ResetOnSpawn = false
    fovScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    fovScreenGui.Parent = playerGui
    pcall(function() fovScreenGui.DisplayOrder = math.max(1000, (fovScreenGui.DisplayOrder or 0) + 1000) end)

    local DEFAULT_OFFSET_FROM_RIGHT = 150
    local DEFAULT_OFFSET_UP = 100
    local TOGGLE_SIZE = 40
    local MAIN_W, MAIN_H = 160, 110

    local destroyed = false
    local heartbeatConn = nil

    local function fov_getViewportSize()
        local cam = getViewportCamera()
        if not cam then
            repeat task.wait() until getViewportCamera()
            cam = getViewportCamera()
        end
        return cam.ViewportSize
    end

    local function elevateInternalZIndex()
        local HIGH_Z = 2000
        for _, obj in ipairs(fovScreenGui:GetDescendants()) do
            if obj:IsA("GuiObject") then
                pcall(function()
                    if obj.ZIndex and type(obj.ZIndex) == "number" and obj.ZIndex < HIGH_Z then
                        obj.ZIndex = HIGH_Z
                    end
                end)
            end
        end
    end

    -- Toggle 按钮（带拖动与点击开关）
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ToggleBtn"
    ToggleBtn.Size = UDim2.new(0, TOGGLE_SIZE, 0, TOGGLE_SIZE)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(210,100,190)
    ToggleBtn.Text = "▼"
    ToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    ToggleBtn.TextSize = 20
    ToggleBtn.BorderSizePixel = 0
    ToggleBtn.AutoButtonColor = false
    ToggleBtn.ZIndex = 2000
    ToggleBtn.Parent = fovScreenGui
    local uic = Instance.new("UICorner", ToggleBtn); uic.CornerRadius = UDim.new(0,8)

    -- Position default / saved
    local function fov_setDefaultTogglePosition()
        if destroyed then return end
        local vs = fov_getViewportSize()
        local absX = math.clamp(vs.X - DEFAULT_OFFSET_FROM_RIGHT - TOGGLE_SIZE/2, 0, vs.X - TOGGLE_SIZE)
        local absY = math.clamp(math.floor(vs.Y*0.5 - TOGGLE_SIZE/2) - DEFAULT_OFFSET_UP, 6, vs.Y - TOGGLE_SIZE - 6)
        local ax = ToggleBtn:GetAttribute("posX")
        local ay = ToggleBtn:GetAttribute("posY")
        if type(ax) == "number" and type(ay) == "number" then
            ToggleBtn.Position = UDim2.new(0, ax, 0, ay)
        else
            ToggleBtn.Position = UDim2.new(0, absX, 0, absY)
        end
    end

    fov_setDefaultTogglePosition()

    -- Control Window
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "ControlWindow"
    MainFrame.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
    MainFrame.BackgroundColor3 = Color3.fromRGB(55,10,40)
    MainFrame.BackgroundTransparency = 0.7
    MainFrame.BorderSizePixel = 1
    MainFrame.BorderColor3 = Color3.fromRGB(210,100,190)
    MainFrame.ZIndex = 2000
    MainFrame.Parent = fovScreenGui
    MainFrame.ClipsDescendants = true
    local mainCorner = Instance.new("UICorner", MainFrame); mainCorner.CornerRadius = UDim.new(0,8)

    local BAR_H = 22
    local BlackBar = Instance.new("Frame")
    BlackBar.Name = "BlackBar"
    BlackBar.Size = UDim2.new(0, MAIN_W + 8, 0, BAR_H)
    BlackBar.BackgroundColor3 = Color3.fromRGB(40,5,30)
    -- 关键调整：设置为透明但保持 Active 以继续接收输入（视觉上移除黑条，但保留拖动交互）
    BlackBar.BackgroundTransparency = 1
    BlackBar.BorderSizePixel = 0
    BlackBar.ZIndex = 2005
    BlackBar.Active = true
    BlackBar.Parent = fovScreenGui
    local barCorner = Instance.new("UICorner", BlackBar); barCorner.CornerRadius = UDim.new(0,6)
    -- 同步初始位置以避免创建时的错位可见条纹
    pcall(function()
        local abs = MainFrame.AbsolutePosition
        local bx = math.max(6, abs.X - 4)
        local by = math.max(6, abs.Y - BAR_H - 6)
        BlackBar.Position = UDim2.new(0, math.floor(bx), 0, math.floor(by))
    end)

    local InfoLabel = Instance.new("TextLabel", MainFrame)
    InfoLabel.Size = UDim2.new(1, -20, 0, 40)
    InfoLabel.Position = UDim2.new(0, 10, 0, 6)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.TextColor3 = Color3.fromRGB(255,255,255)
    InfoLabel.TextSize = 12
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Center
    InfoLabel.ZIndex = 2001
    InfoLabel.Text = ("原始FOV: %d\n当前FOV: %d\n上限: 1000"):format(math.floor(OriginalFOV), math.floor(targetFOV))

    local FOVInput = Instance.new("TextBox", MainFrame)
    FOVInput.Name = "FOVInput"
    FOVInput.Size = UDim2.new(1, -20, 0, 22)
    FOVInput.Position = UDim2.new(0, 10, 0, 52)
    FOVInput.BackgroundColor3 = Color3.fromRGB(80,50,60)
    FOVInput.BackgroundTransparency = 0.5
    FOVInput.PlaceholderText = "输入FOV（1-1000，回车确认）"
    FOVInput.Text = tostring(targetFOV)
    FOVInput.TextColor3 = Color3.fromRGB(255,255,255)
    FOVInput.TextSize = 13
    FOVInput.ClearTextOnFocus = false
    FOVInput.ZIndex = 2002

    local ResetBtn = Instance.new("TextButton", MainFrame)
    ResetBtn.Name = "ResetBtn"
    ResetBtn.Size = UDim2.new(1, -20, 0, 22)
    ResetBtn.Position = UDim2.new(0, 10, 0, 80)
    ResetBtn.BackgroundColor3 = Color3.fromRGB(220,80,150)
    ResetBtn.Text = "还原原始FOV"
    ResetBtn.TextColor3 = Color3.fromRGB(255,255,255)
    ResetBtn.TextSize = 12
    ResetBtn.ZIndex = 2001
    local rCorner = Instance.new("UICorner", ResetBtn); rCorner.CornerRadius = UDim.new(0,4)

    -- CloseFOVBtn（右上）
    local CloseFOVBtn = Instance.new("TextButton", MainFrame)
    CloseFOVBtn.Name = "CloseFOVBtn"
    CloseFOVBtn.Size = UDim2.new(0, 18, 0, 18)
    CloseFOVBtn.Position = UDim2.new(1, -24, 0, 6)
    CloseFOVBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
    CloseFOVBtn.Text = "X"
    CloseFOVBtn.Font = Enum.Font.SourceSansBold
    CloseFOVBtn.TextSize = 14
    CloseFOVBtn.TextColor3 = Color3.fromRGB(255,255,255)
    CloseFOVBtn.BorderSizePixel = 0
    Instance.new("UICorner", CloseFOVBtn).CornerRadius = UDim.new(0,4)
    CloseFOVBtn.MouseButton1Click:Connect(function()
        if fovScreenGui and fovScreenGui.Parent then
            fovScreenGui:Destroy()
            fovCreated = false
            fovScreenGuiRef = nil
        end
    end)

    -- FOV 插值
local isInterpolating = false
local function startFOVInterpolation()
    if destroyed then return end
    if isInterpolating then return end
    isInterpolating = true
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        if destroyed then
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
            isInterpolating = false
            return
        end
        local cam = getViewportCamera()
        if not cam then return end
        local current = cam.FieldOfView
        -- 若FOV被外部重置，强制插值或直接拉回目标值
        if math.abs(current - targetFOV) > 0.01 then
            local nextValue = current + (targetFOV - current) * math.clamp(lerpSpeed * dt, 0, 1)
            cam.FieldOfView = nextValue
        else
            cam.FieldOfView = targetFOV
        end
        -- 保持监听，不断修正FOV
        -- heartbeat监听不自动断开，只有destroyed时才断开
    end)
end

    local function UpdateFOV(newFOV)
        if destroyed then return end
        local n = tonumber(newFOV) or OriginalFOV
        n = math.floor(n)
        n = math.clamp(n, 1, 1000)
        targetFOV = n
        FOVInput.Text = tostring(targetFOV)
        InfoLabel.Text = ("原始FOV: %d\n当前FOV: %d\n上限: 1000"):format(math.floor(OriginalFOV), math.floor(targetFOV))
        pcall(startFOVInterpolation)
    end

    -- Toggle: 支持拖动与点击（InputBegan/InputChanged/InputEnded）
    local activeToggleInput = nil
    local toggleDragStart = Vector2.new(0,0)
    local toggleStartPos = Vector2.new(0,0)
    local TOGGLE_DRAG_THRESHOLD = 8
    local movedDuringTogglePress = false

    ToggleBtn.InputBegan:Connect(function(input)
        if destroyed then return end
        if activeToggleInput then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeToggleInput = input
            movedDuringTogglePress = false
            toggleDragStart = toVector2(input.Position)
            toggleStartPos = Vector2.new(ToggleBtn.AbsolutePosition.X, ToggleBtn.AbsolutePosition.Y)
            input.Changed:Connect(function()
                if destroyed then return end
                if input.UserInputState == Enum.UserInputState.End then
                    local finalPos = toVector2(input.Position)
                    local moved = (finalPos - toggleDragStart).Magnitude
                    if moved < TOGGLE_DRAG_THRESHOLD then
                        -- 短按：切换显示/隐藏 ControlWindow
                        if MainFrame.Visible then
                            MainFrame.Visible = false
                        else
                            MainFrame.Visible = true
                        end
                    else
                        -- 拖动结束 -> 保存位置
                        local abs = ToggleBtn.AbsolutePosition
                        ToggleBtn:SetAttribute("posX", math.floor(abs.X))
                        ToggleBtn:SetAttribute("posY", math.floor(abs.Y))
                    end
                    activeToggleInput = nil
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if destroyed then return end
        if not activeToggleInput then return end
        if input ~= activeToggleInput then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local cur = toVector2(input.Position)
            local delta = cur - toggleDragStart
            if delta.Magnitude >= TOGGLE_DRAG_THRESHOLD then
                movedDuringTogglePress = true
                local newPos = toggleStartPos + delta
                local vs = fov_getViewportSize()
                newPos = Vector2.new(math.clamp(newPos.X, 0, vs.X - TOGGLE_SIZE), math.clamp(newPos.Y, 0, vs.Y - TOGGLE_SIZE))
                ToggleBtn.Position = UDim2.new(0, math.floor(newPos.X), 0, math.floor(newPos.Y))
            end
        end
    end)

    -- BlackBar / MainFrame 拖动：保留原结构并修复拖动（点击并拖动 BlackBar 或 MainFrame 顶部时移动主窗口）
    local barActiveInput = nil
    local barDragging = false
    local barDragStart = Vector2.new(0,0)
    local barStartMainPos = Vector2.new(0,0)

    BlackBar.InputBegan:Connect(function(input)
        if destroyed then return end
        if barActiveInput then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            barActiveInput = input
            barDragging = true
            barDragStart = toVector2(input.Position)
            barStartMainPos = Vector2.new(MainFrame.AbsolutePosition.X, MainFrame.AbsolutePosition.Y)
            input.Changed:Connect(function()
                if destroyed then return end
                if input.UserInputState == Enum.UserInputState.End then
                    if barDragging then
                        barDragging = false
                        local abs = MainFrame.AbsolutePosition
                        MainFrame:SetAttribute("posX", math.floor(abs.X))
                        MainFrame:SetAttribute("posY", math.floor(abs.Y))
                    end
                    barActiveInput = nil
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if destroyed then return end
        if not barActiveInput then return end
        if input ~= barActiveInput then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local cur = toVector2(input.Position)
            local delta = cur - barDragStart
            local newPos = barStartMainPos + delta
            local vs = fov_getViewportSize()
            local aw, ah = MainFrame.AbsoluteSize.X, MainFrame.AbsoluteSize.Y
            if aw == 0 then aw = MAIN_W end
            if ah == 0 then ah = MAIN_H end
            newPos = Vector2.new(math.clamp(newPos.X, 0, vs.X - aw), math.clamp(newPos.Y, 0, vs.Y - ah))
            MainFrame.Position = UDim2.new(0, math.floor(newPos.X), 0, math.floor(newPos.Y))
            -- 同步 BlackBar（位置基于 MainFrame）
            pcall(function()
                local abs = MainFrame.AbsolutePosition
                local bx = math.max(6, abs.X - 4)
                local by = math.max(6, abs.Y - BAR_H - 6)
                BlackBar.Position = UDim2.new(0, math.floor(bx), 0, math.floor(by))
            end)
        end
    end)

    -- TopDrag：为 MainFrame 顶部拖动（兼容多点输入）
    local TopDrag = Instance.new("Frame", MainFrame)
    TopDrag.Name = "TopDrag"
    TopDrag.Size = UDim2.new(1,0,0,28)
    TopDrag.Position = UDim2.new(0,0,0,0)
    TopDrag.BackgroundTransparency = 1
    TopDrag.ZIndex = 2001

    local mainActiveInput = nil
    local draggingMain = false
    local mainDragStart = Vector2.new(0,0)
    local mainStartPos = Vector2.new(0,0)

    TopDrag.InputBegan:Connect(function(input)
        if destroyed then return end
        if mainActiveInput then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            mainActiveInput = input
            draggingMain = true
            mainDragStart = toVector2(input.Position)
            mainStartPos = Vector2.new(MainFrame.AbsolutePosition.X, MainFrame.AbsolutePosition.Y)
            input.Changed:Connect(function()
                if destroyed then return end
                if input.UserInputState == Enum.UserInputState.End then
                    if draggingMain then
                        draggingMain = false
                        local abs = MainFrame.AbsolutePosition
                        MainFrame:SetAttribute("posX", math.floor(abs.X))
                        MainFrame:SetAttribute("posY", math.floor(abs.Y))
                    end
                    mainActiveInput = nil
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if destroyed then return end
        if not mainActiveInput then return end
        if input ~= mainActiveInput then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local cur = toVector2(input.Position)
            local delta = cur - mainDragStart
            local newPos = mainStartPos + delta
            local vs = fov_getViewportSize()
            local aw, ah = MainFrame.AbsoluteSize.X, MainFrame.AbsoluteSize.Y
            if aw == 0 then aw = MAIN_W end
            if ah == 0 then ah = MAIN_H end
            newPos = Vector2.new(math.clamp(newPos.X, 0, vs.X - aw), math.clamp(newPos.Y, 0, vs.Y - ah))
            MainFrame.Position = UDim2.new(0, math.floor(newPos.X), 0, math.floor(newPos.Y))
            pcall(function()
                local abs = MainFrame.AbsolutePosition
                local bx = math.max(6, abs.X - 4)
                local by = math.max(6, abs.Y - BAR_H - 6)
                BlackBar.Position = UDim2.new(0, math.floor(bx), 0, math.floor(by))
            end)
        end
    end)

    -- FOVInput / ResetBtn 行为（保持）
    FOVInput.FocusLost:Connect(function(enter)
        if destroyed then return end
        if enter then
            local text = tostring(FOVInput.Text or ""):gsub("%s+", "")
            local num = tonumber(text)
            num = num and math.clamp(math.floor(num), 1, 1000) or targetFOV
            UpdateFOV(num)
        else
            if FOVInput.Text == "" then
                FOVInput.Text = tostring(targetFOV)
            end
        end
    end)

    ResetBtn.MouseButton1Click:Connect(function()
        if destroyed then return end
        UpdateFOV(OriginalFOV)
    end)
    ResetBtn.TouchTap:Connect(function()
        if destroyed then return end
        UpdateFOV(OriginalFOV)
    end)

    -- 监听视口变化，调整默认位置并同步 bar
    do
        local cam = getViewportCamera()
        if not cam then
            repeat task.wait() until getViewportCamera()
            cam = getViewportCamera()
        end
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if destroyed then return end
            fov_setDefaultTogglePosition()
            -- 若 MainFrame 有保存位置则使用；否则计算默认
            pcall(function()
                local savedX = MainFrame:GetAttribute("posX")
                local savedY = MainFrame:GetAttribute("posY")
                local vs2 = fov_getViewportSize()
                if type(savedX) == "number" and type(savedY) == "number" then
                    MainFrame.Position = UDim2.new(0, savedX, 0, savedY)
                    local abs = MainFrame.AbsolutePosition
                    local bx = math.max(6, abs.X - 4)
                    local by = math.max(6, abs.Y - BAR_H - 6)
                    BlackBar.Position = UDim2.new(0, math.floor(bx), 0, math.floor(by))
                else
                    local defaultX = math.clamp(ToggleBtn.AbsolutePosition.X - MAIN_W - 10, 6, vs2.X - MAIN_W - 6)
                    local defaultY = math.clamp(ToggleBtn.AbsolutePosition.Y, 6, vs2.Y - MAIN_H - 6)
                    MainFrame.Position = UDim2.new(0, defaultX, 0, defaultY)
                    BlackBar.Position = UDim2.new(0, math.max(6, defaultX - 4), 0, math.max(6, defaultY - BAR_H - 6))
                end
            end)
        end)
    end

    fovCreated = true
    fovScreenGuiRef = fovScreenGui
    elevateInternalZIndex()
end
-- ===== End ensureFOVUI =====

-- 渲染脚本条目（保持原结构；内存修改FOV 调用 ensureFOVUI）
for i, v in ipairs(scriptList) do
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1,0,0, math.floor(70*scale))
    item.BackgroundColor3 = Color3.fromRGB(110,30,80)
    item.BackgroundTransparency = 0.12
    item.BorderSizePixel = 0
    item.Parent = scrollFrame
    Instance.new("UICorner", item).CornerRadius = UDim.new(0,14)

    local nameLabel = Instance.new("TextLabel", item)
    nameLabel.Size = UDim2.new(0.6, -16, 0, math.floor(30*scale))
    nameLabel.Position = UDim2.new(0, math.floor(12*scale), 0, math.floor(8*scale))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = v.name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = math.floor(18*scale)
    nameLabel.TextColor3 = Color3.fromRGB(255,190,230)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left

    local descL = Instance.new("TextLabel", item)
    descL.Size = UDim2.new(0.6, -16, 0, math.floor(20*scale))
    descL.Position = UDim2.new(0, math.floor(12*scale), 0, math.floor(36*scale))
    descL.BackgroundTransparency = 1
    descL.Text = v.desc
    descL.Font = Enum.Font.Gotham
    descL.TextSize = math.floor(14*scale)
    descL.TextColor3 = Color3.fromRGB(255,200,230)
    descL.TextXAlignment = Enum.TextXAlignment.Left

    local runButton = Instance.new("TextButton", item)
    runButton.Size = UDim2.new(0, math.floor(72*scale), 0, math.floor(36*scale))
    runButton.Position = UDim2.new(1, -math.floor(96*scale), 0.5, -math.floor(18*scale))
    runButton.BackgroundColor3 = Color3.fromRGB(220,90,170)
    runButton.Text = "运行"
    runButton.Font = Enum.Font.GothamBold
    runButton.TextSize = math.floor(16*scale)
    runButton.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", runButton).CornerRadius = UDim.new(0,10)

    runButton.MouseButton1Click:Connect(function()
        if v.name == "自定义脚本" then
            local existingBox = item:FindFirstChild("CustomInputBox")
            if existingBox then existingBox:CaptureFocus(); return end
            local inputBox = Instance.new("TextBox", item)
            inputBox.Name = "CustomInputBox"
            inputBox.Size = UDim2.new(0.62,0,0, math.floor(36*scale))
            inputBox.Position = UDim2.new(0, math.floor(12*scale), 0, math.floor(36*scale))
            inputBox.PlaceholderText = ""
            inputBox.Font = Enum.Font.Gotham
            inputBox.TextSize = math.floor(14*scale)
            inputBox.TextColor3 = Color3.fromRGB(255,190,230)
            inputBox.BackgroundColor3 = Color3.fromRGB(110,30,80)
            inputBox.ClearTextOnFocus = false
            inputBox.Text = ""
            Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0,6)

            local deltaBtn = Instance.new("TextButton", item)
            deltaBtn.Size = UDim2.new(0, math.floor(40*scale), 0, math.floor(36*scale))
            deltaBtn.Position = UDim2.new(1, -math.floor(96*scale), 0, math.floor(36*scale))
            deltaBtn.BackgroundColor3 = Color3.fromRGB(210,100,190)
            deltaBtn.Text = "Δ"
            deltaBtn.Font = Enum.Font.GothamBold
            deltaBtn.TextSize = math.floor(16*scale)
            deltaBtn.TextColor3 = Color3.fromRGB(255,255,255)
            Instance.new("UICorner", deltaBtn).CornerRadius = UDim.new(0,6)

            local injBtn = Instance.new("TextButton", item)
            injBtn.Size = UDim2.new(0, math.floor(40*scale), 0, math.floor(36*scale))
            injBtn.Position = UDim2.new(1, -math.floor(48*scale), 0, math.floor(36*scale))
            injBtn.BackgroundColor3 = Color3.fromRGB(220,110,140)
            injBtn.Text = "注入"
            injBtn.Font = Enum.Font.GothamBold
            injBtn.TextSize = math.floor(14*scale)
            injBtn.TextColor3 = Color3.fromRGB(255,255,255)
            Instance.new("UICorner", injBtn).CornerRadius = UDim.new(0,6)

            local function runCustom(mode)
                local code = tostring(inputBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if code == "" then
                    pcall(function() setStatus("fail") end)
                    pcall(function() showRunToast(false, 2) end)
                    return
                end
                enqueueRun(function()
                    pcall(function() setStatus("running") end)
                    task.wait(0.06)
                    local ok, err
                    if mode == "inject" then
                        ok, err = fullInjectorRun(code)
                    elseif mode == "delta" then
                        ok, err = deltaRun(code)
                    else
                        ok, err = safeLoadAndRun(code)
                    end
                    if ok then
                        pcall(function() setStatus("success") end)
                        pcall(function() showRunToast(true, 2) end)
                    else
                        pcall(function() setStatus("fail") end)
                        pcall(function() showRunToast(false, 3) end)
                        warn("自定义脚本运行错误: ", tostring(err))
                    end
                end)
            end

            inputBox.FocusLost:Connect(function(enter)
                if enter then
                    runCustom("normal")
                    inputBox:Destroy()
                    if deltaBtn and deltaBtn.Parent then deltaBtn:Destroy() end
                    if injBtn and injBtn.Parent then injBtn:Destroy() end
                end
            end)

            deltaBtn.MouseButton1Click:Connect(function()
                local text = tostring(inputBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if text == "" then
                    pcall(function() setStatus("fail") end)
                    pcall(function() showRunToast(false, 2) end)
                    inputBox:Destroy()
                    if deltaBtn and deltaBtn.Parent then deltaBtn:Destroy() end
                    if injBtn and injBtn.Parent then injBtn:Destroy() end
                    return
                end
                runCustom("delta")
                inputBox:Destroy()
                if deltaBtn and deltaBtn.Parent then deltaBtn:Destroy() end
                if injBtn and injBtn.Parent then injBtn:Destroy() end
            end)

            injBtn.MouseButton1Click:Connect(function()
                local text = tostring(inputBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if text == "" then
                    pcall(function() setStatus("fail") end)
                    pcall(function() showRunToast(false, 2) end)
                    inputBox:Destroy()
                    if deltaBtn and deltaBtn.Parent then deltaBtn:Destroy() end
                    if injBtn and injBtn.Parent then injBtn:Destroy() end
                    return
                end
                runCustom("inject")
                inputBox:Destroy()
                if deltaBtn and deltaBtn.Parent then deltaBtn:Destroy() end
                if injBtn and injBtn.Parent then injBtn:Destroy() end
            end)

            inputBox:CaptureFocus()
        else
            if v.name == "内存修改FOV" then
                pcall(function() ensureFOVUI() end)
                pcall(function() showRunToast(true, 1) end)
                return
            end
            showRunPanel()
            enqueueRun(function()
                pcall(function() setStatus("running") end)
                task.wait(0.06)
                local ok, err = safeLoadAndRun(v.code)
                hideRunPanel()
                if ok then
                    pcall(function() setStatus("success") end)
                    pcall(function() showRunToast(true) end)
                else
                    pcall(function() setStatus("fail") end)
                    pcall(function() showRunToast(false) end)
                    warn("脚本运行出错:", err)
                end
            end)
        end
    end)
end

local floatToggle = Instance.new("TextButton")
floatToggle.Name = "FloatToggle"
floatToggle.Size = UDim2.new(0, math.floor(48 * scale), 0, math.floor(48 * scale))

local vs = getViewportSize()
local defaultAbsX = math.floor(vs.X - 150)
local defaultAbsY = math.floor(vs.Y * 0.5) - math.floor(24 * scale) - 100

local savedFX = floatToggle:GetAttribute("posX")
local savedFY = floatToggle:GetAttribute("posY")
if savedFX and savedFY then
    floatToggle.Position = UDim2.new(0, savedFX, 0, savedFY)
else
    floatToggle.Position = UDim2.new(0, defaultAbsX, 0, defaultAbsY)
end

floatToggle.BackgroundColor3 = Color3.fromRGB(180,70,140)
floatToggle.Text = "☰"
floatToggle.Font = Enum.Font.GothamBold
floatToggle.TextSize = math.floor(22*scale)
floatToggle.TextColor3 = Color3.fromRGB(255,255,255)
pcall(function() if floatToggle.ZIndex and type(floatToggle.ZIndex) == "number" then floatToggle.ZIndex = 1006 end end)
floatToggle.Parent = screenGui
Instance.new("UICorner", floatToggle).CornerRadius = UDim.new(1,0)

-- 新增：控制是否允许通过浮动开关打开主悬浮窗（公告期间禁止）
local allowOpenMain = false

do
    local dragging = false
    local dragInput = nil
    local dragStart = Vector2.new()
    local startAbsPos = Vector2.new()
    local movedThreshold = 8
    local lastMoveTime = 0

    floatToggle.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragInput = input
            dragStart = toVector2(input.Position)
            startAbsPos = Vector2.new(floatToggle.AbsolutePosition.X, floatToggle.AbsolutePosition.Y)
            dragging = false
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragInput = nil
                    task.delay(0.05, function() dragging = false end)
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragInput then return end
        if input ~= dragInput then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseMovement then return end
        local pos = toVector2(input.Position)
        local delta = pos - dragStart
        if delta.Magnitude > movedThreshold then dragging = true end
        if dragging then
            local newPos = startAbsPos + delta
            local cam = getViewportCamera()
            local vs2 = cam and cam.ViewportSize or Vector2.new(800,600)
            newPos = Vector2.new(
                math.clamp(newPos.X, 0, vs2.X - floatToggle.AbsoluteSize.X),
                math.clamp(newPos.Y, 0, vs2.Y - floatToggle.AbsoluteSize.Y)
            )
            floatToggle.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
            floatToggle:SetAttribute("posX", newPos.X)
            floatToggle:SetAttribute("posY", newPos.Y)
            lastMoveTime = tick()
        end
    end)

    floatToggle.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        if (tick() - lastMoveTime) < 0.12 then return end
        if dragging then return end

        -- 如果尚未允许打开主窗（公告期间），则拒绝打开并给出轻微提示动画
        if not allowOpenMain then
            pcall(function()
                local enlarge = TweenService:Create(floatToggle, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, math.floor(52 * scale), 0, math.floor(52 * scale))})
                local shrink = TweenService:Create(floatToggle, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, math.floor(48 * scale), 0, math.floor(48 * scale))})
                enlarge:Play()
                enlarge.Completed:Wait()
                shrink:Play()
            end)
            return
        end

        if not mainFrame.Visible or mainFrame.Size == UDim2.new(0,0,0,0) then
            local savedMX = mainFrame:GetAttribute("posX")
            local savedMY = mainFrame:GetAttribute("posY")
            local cam = getViewportCamera()
            local vs2 = cam and cam.ViewportSize or Vector2.new(800,600)
            local targetX, targetY
            if savedMX and savedMY then
                targetX = savedMX
                targetY = savedMY
            else
                targetX = math.floor(vs2.X*0.5 - winW*0.5)
                targetY = math.floor(vs2.Y*0.5 - winH*0.5)
            end
            mainFrame.Position = UDim2.new(0, targetX + math.floor(winW/2), 0, targetY + math.floor(winH/2))
            mainFrame.Size = UDim2.new(0, 0, 0, 0)
            mainFrame.BackgroundTransparency = 1
            mainFrame.Visible = true
            local twInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            pcall(function()
                TweenService:Create(mainFrame, twInfo, {
                    Size = UDim2.new(0, winW, 0, winH),
                    Position = UDim2.new(0, targetX, 0, targetY),
                    BackgroundTransparency = 0.08
                }):Play()
            end)
            mainFrame:SetAttribute("posX", targetX)
            mainFrame:SetAttribute("posY", targetY)
        else
            local twInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            local t1 = TweenService:Create(mainFrame, twInfo, {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0)})
            t1:Play()
            t1.Completed:Wait()
            mainFrame.Visible = false
        end
    end)
end

-- mainFrame 顶部拖动（保持）
do
    local draggingMain = false
    local dragInputMain = nil
    local dragStartMain = Vector2.new()
    local startAbsMain = Vector2.new()
    local movedThresholdMain = 8
    local lastMoveTimeMain = 0

    topBar.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragInputMain = input
            dragStartMain = toVector2(input.Position)
            startAbsMain = Vector2.new(mainFrame.AbsolutePosition.X, mainFrame.AbsolutePosition.Y)
            draggingMain = false
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragInputMain = nil
                    task.delay(0.05, function() draggingMain = false end)
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragInputMain then return end
        if input ~= dragInputMain then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseMovement then return end
        local pos = toVector2(input.Position)
        local delta = pos - dragStartMain
        if delta.Magnitude > movedThresholdMain then draggingMain = true end
        if draggingMain then
            local newPos = startAbsMain + delta
            local cam = getViewportCamera()
            local vs2 = cam and cam.ViewportSize or Vector2.new(800,600)
            newPos = Vector2.new(
                math.clamp(newPos.X, 0, vs2.X - mainFrame.AbsoluteSize.X),
                math.clamp(newPos.Y, 0, vs2.Y - mainFrame.AbsoluteSize.Y)
            )
            mainFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
            mainFrame:SetAttribute("posX", newPos.X)
            mainFrame:SetAttribute("posY", newPos.Y)
            lastMoveTimeMain = tick()
        end
    end)

    topBar.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        if (tick() - lastMoveTimeMain) < 0.12 then return end
        if draggingMain then return end
        local absPos = Vector2.new(mainFrame.AbsolutePosition.X, mainFrame.AbsolutePosition.Y)
        mainFrame:SetAttribute("posX", absPos.X)
        mainFrame:SetAttribute("posY", absPos.Y)
    end)
end

-- 视口变化处理（保持）
spawn(function()
    local cam = getViewportCamera()
    if not cam then
        repeat wait() until getViewportCamera()
        cam = getViewportCamera()
    end
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local vs2 = cam.ViewportSize
        scale = math.min(vs2.X / 800, vs2.Y / 600, 1)
        winW, winH = math.floor(baseW * scale), math.floor(baseH * scale)
        if mainFrame and mainFrame.Parent and mainFrame.Size ~= UDim2.new(0,0,0,0) then
            mainFrame.Size = UDim2.new(0, winW, 0, winH)
        end
        local savedMX = mainFrame:GetAttribute("posX")
        local savedMY = mainFrame:GetAttribute("posY")
        if savedMX and savedMY then
            local newX = math.clamp(savedMX, 0, vs2.X - mainFrame.AbsoluteSize.X)
            local newY = math.clamp(savedMY, 0, vs2.Y - mainFrame.AbsoluteSize.Y)
            mainFrame.Position = UDim2.new(0, newX, 0, newY)
            mainFrame:SetAttribute("posX", newX)
            mainFrame:SetAttribute("posY", newY)
        else
            mainFrame.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
        end
    end)
end)

if uiListLayout and uiListLayout.AbsoluteContentSize then
    scrollFrame.CanvasSize = UDim2.new(0,0,0, uiListLayout.AbsoluteContentSize.Y + math.floor(8*scale))
end

-- 启动流程更新：先播放公告（更长时间且增加动态感），公告期间仅阻止主悬浮窗区域的交互（不限制屏幕滑动等）
task.delay(0.04, function()
    pcall(function()
        local function startMainExpand()
            local cam = getViewportCamera()
            local vs = cam and cam.ViewportSize or Vector2.new(800,600)
            local targetX = math.floor(vs.X*0.5 - winW*0.5)
            local targetY = math.floor(vs.Y*0.5 - winH*0.5)
            -- 将主窗置于目标中心（半宽偏移），开始展开动画
            mainFrame.Position = UDim2.new(0, targetX + math.floor(winW/2), 0, targetY + math.floor(winH/2))
            mainFrame.Size = UDim2.new(0, 0, 0, 0)
            mainFrame.BackgroundTransparency = 1
            mainFrame.Visible = true
            local twInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            pcall(function()
                TweenService:Create(mainFrame, twInfo, {
                    Size = UDim2.new(0, winW, 0, winH),
                    Position = UDim2.new(0, targetX, 0, targetY),
                    BackgroundTransparency = 0.08
                }):Play()
            end)
        end

        -- Announcement GUI（单独 ScreenGui，显示优先）
        local announceGui = Instance.new("ScreenGui")
        announceGui.Name = "MSFW_Announcement"
        announceGui.Parent = playerGui
        announceGui.ResetOnSpawn = false
        announceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pcall(function() announceGui.DisplayOrder = math.max(5000, (announceGui.DisplayOrder or 0) + 1000) end)

        -- 这里只对将来主窗区域创建一个局部阻断 Frame（不阻止全局滑动或浮动按钮拖动）
        -- 计算主窗目标位置（居中）
        local cam = getViewportCamera()
        local vs = cam and cam.ViewportSize or Vector2.new(800,600)
        local targetX = math.floor(vs.X*0.5 - winW*0.5)
        local targetY = math.floor(vs.Y*0.5 - winH*0.5)

        local mainAreaBlocker = Instance.new("Frame")
        mainAreaBlocker.Name = "MSFW_MainAreaBlocker"
        mainAreaBlocker.Size = UDim2.new(0, winW, 0, winH)
        mainAreaBlocker.Position = UDim2.new(0, targetX, 0, targetY)
        mainAreaBlocker.BackgroundTransparency = 1
        mainAreaBlocker.BorderSizePixel = 0
        -- 设置较高 ZIndex 以拦截主窗区域交互，但不去覆盖 announceGui（单独 ScreenGui）或 floatToggle（floatToggle 位于别处且不会被该区域覆盖除非位置重合）
        pcall(function() mainAreaBlocker.ZIndex = 4500 end)
        mainAreaBlocker.Active = true
        mainAreaBlocker.Parent = screenGui

        -- Announcement frame (centered)
        local aFrame = Instance.new("Frame", announceGui)
        local aW = math.floor(math.clamp(winW * 0.9, 280, 520))
        local aH = math.floor(120 * scale)
        aFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        aFrame.Size = UDim2.new(0, aW, 0, aH)
        aFrame.Position = UDim2.new(0.5, 0, 0.28, 0)
        aFrame.BackgroundColor3 = Color3.fromRGB(40,10,30)
        aFrame.BackgroundTransparency = 1
        aFrame.BorderSizePixel = 0
        aFrame.ZIndex = 6000
        Instance.new("UICorner", aFrame).CornerRadius = UDim.new(0,12)

        local aLabel = Instance.new("TextLabel", aFrame)
        aLabel.Size = UDim2.new(1, -24, 1, -24)
        aLabel.Position = UDim2.new(0, 12, 0, 12)
        aLabel.BackgroundTransparency = 1
        aLabel.Text = "欢迎使用脚本"
        aLabel.Font = Enum.Font.GothamBold
        aLabel.TextSize = math.floor(28 * scale)
        aLabel.TextColor3 = Color3.fromRGB(255, 200, 230)
        aLabel.TextTransparency = 1
        aLabel.TextWrapped = true
        aLabel.TextScaled = false
        aLabel.TextXAlignment = Enum.TextXAlignment.Center
        aLabel.TextYAlignment = Enum.TextYAlignment.Center
        aLabel.ZIndex = 6001

        -- 更强动态感 + 更长时长（总 10s：淡入 1s，停留 ~8.2s，淡出 0.8s）
        local fadeInTime = 1.0
        local fadeOutTime = 0.8
        local total = 10
        local holdTime = math.max(0, total - fadeInTime - fadeOutTime)

        -- 循环动画（背景微脉冲 + 位置上下轻微浮动）
        local bgPulseTween = nil
        local posPulseTween = nil
        pcall(function()
            bgPulseTween = TweenService:Create(aFrame, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.02})
            posPulseTween = TweenService:Create(aFrame, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = UDim2.new(0.5, 0, 0.28, -6)})
        end)

        -- 淡入
        pcall(function()
            TweenService:Create(aFrame, TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.08}):Play()
            TweenService:Create(aLabel, TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        end)

        -- 等待淡入完成后开始循环动画（在停留期间）
        task.delay(fadeInTime, function()
            pcall(function()
                if bgPulseTween then bgPulseTween:Play() end
                if posPulseTween then posPulseTween:Play() end
            end)
        end)

        -- 在淡入 + 停留后触发淡出：停止循环动画并在淡出完成后移除 mainAreaBlocker，然后展开主窗
        task.delay(fadeInTime + holdTime, function()
            pcall(function()
                -- 停止循环动画（先平滑回到默认状态）
                if posPulseTween then
                    pcall(function() posPulseTween:Cancel() end)
                    -- 恢复位置到原始（确保回到预期位置）
                    TweenService:Create(aFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5, 0, 0.28, 0)}):Play()
                end
                if bgPulseTween then
                    pcall(function() bgPulseTween:Cancel() end)
                    TweenService:Create(aFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.08}):Play()
                end

                local t1 = TweenService:Create(aLabel, TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
                local t2 = TweenService:Create(aFrame, TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
                t1:Play(); t2:Play()
                t1.Completed:Connect(function()
                    if announceGui and announceGui.Parent then announceGui:Destroy() end
                    -- 移除仅用于拦截主窗区域交互的 blocker，恢复主窗交互
                    if mainAreaBlocker and mainAreaBlocker.Parent then mainAreaBlocker:Destroy() end
                    -- 允许通过浮动开关打开主窗（公告结束）
                    allowOpenMain = true
                    -- 展开主悬浮窗（原有动画）
                    pcall(startMainExpand)
                end)
            end)
        end)
    end)
end)

print("MultiScriptFloatingWindow v4.6 已加载
