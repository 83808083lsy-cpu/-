-- MultiScriptFloatingWindow v4.6 — 集成版（robustFetch 并发/缓存/退避 + 网络探针 + 自动降级回退）
-- 修复说明：
--  - 修复了 scriptList 中某些条目里的字符串/表字面量语法错误（导致 "Expected '}' got '('" 的编译错误）。
--  - 清理并规范化了 scriptList 中可能包含未闭合或被截断的代码块，保留可用脚本条目并保证表结构正确。
--  - 其它保持与之前版本相同的功能：robustFetch、缓存、网络探针、本地 run_key 校验等。

if _G and _G.__MSFW_LOADED then
    return
end
if _G then _G.__MSFW_LOADED = true end

-- 等待游戏加载，避免在早期环境中出现 nil
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- 更稳健的 Camera 获取函数（在必要时等待）
local function getViewportCamera()
    local cam = Workspace.CurrentCamera
    if cam then return cam end
    local waited = 0
    while (not cam) and waited < 5 do
        pcall(function() Workspace:GetPropertyChangedSignal("CurrentCamera"):Wait() end)
        cam = Workspace.CurrentCamera
        waited = waited + 0.1
        task.wait(0.1)
    end
    return cam
end

-- 等待 LocalPlayer 与 PlayerGui 可用（健壮处理）
local player = Players.LocalPlayer
if not player then
    repeat task.wait() until Players.LocalPlayer
    player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

-- 如果已有旧 GUI，先销毁
local EXISTING = playerGui:FindFirstChild("MultiScriptFloatingWindow")
if EXISTING then
    pcall(function() EXISTING:Destroy() end)
end

-- 辅助：将多种类型值转换为 Vector2（用于 Input.Position 等）
local function toVector2(v)
    local t = typeof(v)
    if t == "Vector2" then
        return v
    elseif t == "Vector3" then
        return Vector2.new(v.X, v.Y)
    elseif t == "UDim2" then
        local cam = getViewportCamera()
        local vs = (cam and cam.ViewportSize) or Vector2.new(800, 600)
        local ok, absX = pcall(function() return v.X.Scale * vs.X + v.X.Offset end)
        local ok2, absY = pcall(function() return v.Y.Scale * vs.Y + v.Y.Offset end)
        if ok and ok2 then
            return Vector2.new(absX, absY)
        end
        return Vector2.new(0, 0)
    elseif type(v) == "table" and v.X and v.Y then
        return Vector2.new(v.X, v.Y)
    else
        return Vector2.new(0, 0)
    end
end

-- 更稳健 safeAbsolutePosition：做更多 pcall / 存在性检测，避免对已销毁实例索引
local function safeAbsolutePosition(gui)
    if not gui then return Vector2.new(0, 0) end
    if typeof(gui) ~= "Instance" then return Vector2.new(0, 0) end
    local ok, ap = pcall(function() return gui.AbsolutePosition end)
    if ok and ap then
        if typeof(ap) == "Vector2" then return ap end
        if type(ap) == "table" and ap.X and ap.Y then return Vector2.new(ap.X, ap.Y) end
        if ap.X and ap.Y then return Vector2.new(ap.X, ap.Y) end
    end
    local pos = nil
    local suc = pcall(function() pos = gui.Position end)
    if suc and pos and typeof(pos) == "UDim2" then
        local cam = getViewportCamera()
        local vs = (cam and cam.ViewportSize) or Vector2.new(800, 600)
        local okx, oky = pcall(function() return pos.X.Scale * vs.X + pos.X.Offset end), pcall(function() return pos.Y.Scale * vs.Y + pos.Y.Offset end)
        if okx and oky then
            local x = pos.X.Scale * vs.X + pos.X.Offset
            local y = pos.Y.Scale * vs.Y + pos.Y.Offset
            return Vector2.new(x, y)
        end
    end
    return Vector2.new(0, 0)
end

-- 更稳健 safeAbsoluteSize：同上
local function safeAbsoluteSize(gui)
    if not gui then return Vector2.new(0, 0) end
    if typeof(gui) ~= "Instance" then return Vector2.new(0, 0) end
    local ok, asz = pcall(function() return gui.AbsoluteSize end)
    if ok and asz then
        if typeof(asz) == "Vector2" then return asz end
        if type(asz) == "table" and asz.X and asz.Y then return Vector2.new(asz.X, asz.Y) end
    end
    local sz = nil
    local suc = pcall(function() sz = gui.Size end)
    if suc and sz and typeof(sz) == "UDim2" then
        local cam = getViewportCamera()
        local vs = (cam and cam.ViewportSize) or Vector2.new(800, 600)
        local w = sz.X.Scale * vs.X + sz.X.Offset
        local h = sz.Y.Scale * vs.Y + sz.Y.Offset
        return Vector2.new(w, h)
    end
    return Vector2.new(0, 0)
end

local function getViewportSize()
    local cam = getViewportCamera()
    if not cam then
        repeat task.wait() until getViewportCamera()
        cam = getViewportCamera()
    end
    return cam and cam.ViewportSize or Vector2.new(800, 600)
end

-- 屏幕与缩放参数
local screenSize = getViewportSize()
local baseW, baseH = 430, 410
local scale = math.min(screenSize.X / 800, screenSize.Y / 600, 1)
local winW, winH = math.floor(baseW * scale), math.floor(baseH * scale)

-- 创建主 ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MultiScriptFloatingWindow"
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 记录需要在销毁时断开的连接（避免内存泄漏）
local createdConnections = {}
local function trackConnection(conn)
    if conn then
        table.insert(createdConnections, conn)
    end
    return conn
end
local function disconnectAll()
    for _, c in ipairs(createdConnections) do
        pcall(function() c:Disconnect() end)
    end
    createdConnections = {}
end

-- 置顶保护
do
    local TOP_DISPLAY_ORDER = 32767
    local HIGH_ZINDEX = 1000
    pcall(function() screenGui.DisplayOrder = math.min(TOP_DISPLAY_ORDER, (screenGui.DisplayOrder or 0) + 1000) end)

    local function elevateZIndices()
        pcall(function()
            for _, obj in ipairs(screenGui:GetDescendants()) do
                pcall(function()
                    if typeof(obj) == "Instance" and obj:IsA("GuiObject") then
                        local ok, val = pcall(function() return obj.ZIndex end)
                        if ok and type(val) == "number" and val < HIGH_ZINDEX then
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

    trackConnection(playerGui.ChildAdded:Connect(function(child)
        if child and child:IsA("ScreenGui") and child ~= screenGui then
            pcall(function()
                child:GetPropertyChangedSignal("DisplayOrder"):Connect(function() ensureTop() end)
            end)
            task.delay(0.02, ensureTop)
        end
    end))

    pcall(function()
        for _, c in pairs(playerGui:GetChildren()) do
            if c ~= screenGui and c:IsA("ScreenGui") then
                pcall(function() c:GetPropertyChangedSignal("DisplayOrder"):Connect(function() ensureTop() end) end)
            end
        end
    end)

    trackConnection(screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            task.delay(0.05, function()
                if player and player:FindFirstChild("PlayerGui") and screenGui and not screenGui.Parent then
                    pcall(function() screenGui.Parent = player.PlayerGui end)
                    task.delay(0.03, ensureTop)
                else
                    if not screenGui.Parent then
                        disconnectAll()
                    end
                end
            end)
        else
            task.delay(0.03, ensureTop)
        end
    end))

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

-- 主窗体 & UI 基本构建（主题为绿色）
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 90, 50)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 1
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Visible = false
mainFrame.Parent = screenGui
pcall(function() if mainFrame.ZIndex and type(mainFrame.ZIndex) == "number" then mainFrame.ZIndex = 1000 end end)
local mainUICorner = Instance.new("UICorner")
mainUICorner.CornerRadius = UDim.new(0, 18)
mainUICorner.Parent = mainFrame

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, math.floor(44 * scale))
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(20, 120, 70)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
pcall(function() if topBar.ZIndex and type(topBar.ZIndex) == "number" then topBar.ZIndex = 1001 end end)
local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 18)
tbCorner.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -160, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "公测版本V5.2"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = math.floor(24 * scale)
titleLabel.TextColor3 = Color3.fromRGB(200, 255, 220)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar
pcall(function() if titleLabel.ZIndex and type(titleLabel.ZIndex) == "number" then titleLabel.ZIndex = 1002 end end)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, math.floor(38 * scale), 0, math.floor(34 * scale))
closeButton.Position = UDim2.new(1, -math.floor(44 * scale), 0, math.floor(5 * scale))
closeButton.BackgroundColor3 = Color3.fromRGB(40, 150, 90)
closeButton.Text = "🅔"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = math.floor(22 * scale)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = topBar
local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 10)
closeButtonCorner.Parent = closeButton
pcall(function() if closeButton.ZIndex and type(closeButton.ZIndex) == "number" then closeButton.ZIndex = 1003 end end)

closeButton.MouseButton1Click:Connect(function()
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    pcall(function()
        local tw = TweenService:Create(mainFrame, tweenInfo, {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})
        if tw then tw:Play() end
    end)
    task.delay(0.28, function()
        if screenGui and screenGui.Parent then
            pcall(function() screenGui:Destroy() end)
        end
    end)
end)

-- 更新日志按钮
local updateButton = Instance.new("TextButton")
updateButton.Size = UDim2.new(0, math.floor(72 * scale), 0, math.floor(34 * scale))
updateButton.Position = UDim2.new(1, -math.floor(128 * scale), 0, math.floor(5 * scale))
updateButton.BackgroundColor3 = Color3.fromRGB(30, 140, 80)
updateButton.Text = "更新日志"
updateButton.Font = Enum.Font.GothamBold
updateButton.TextSize = math.floor(14 * scale)
updateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
updateButton.BorderSizePixel = 0
updateButton.Parent = topBar
local updateBtnCorner = Instance.new("UICorner")
updateBtnCorner.CornerRadius = UDim.new(0, 8)
updateBtnCorner.Parent = updateButton
pcall(function() if updateButton.ZIndex and type(updateButton.ZIndex) == "number" then updateButton.ZIndex = 1003 end end)

-- updateLogFrame（点击创建）
local updateLogFrame = nil
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
        if tSize then tSize:Play() end
        if tPos then tPos:Play() end
        if tSize then
            tSize.Completed:Connect(function()
                if ulTitle then
                    local t = TweenService:Create(ulTitle, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
                    pcall(function() if t then t:Play() end end)
                end
                if content then
                    local t2 = TweenService:Create(content, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
                    pcall(function() if t2 then t2:Play() end end)
                end
            end)
        end
    end)
end

local function animateHideUpdateLog(destroyAfter)
    if not updateLogFrame or not updateLogFrame.Parent then return end
    local ulTitle = updateLogFrame:FindFirstChild("ULTitle")
    local content = updateLogFrame:FindFirstChild("ULContent")
    pcall(function()
        if ulTitle then
            local t = TweenService:Create(ulTitle, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
            if t then t:Play() end
        end
        if content then
            local t = TweenService:Create(content, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
            if t then t:Play() end
        end
        local tSize = TweenService:Create(updateLogFrame, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, math.floor(320 * scale), 0, 0), BackgroundTransparency = 1})
        local tPos = TweenService:Create(updateLogFrame, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(1, -math.floor(340 * scale), 0, math.floor(62 * scale))})
        if tSize then tSize:Play() end
        if tPos then tPos:Play() end
        if tSize then
            tSize.Completed:Connect(function()
                if destroyAfter then
                    if updateLogFrame and updateLogFrame.Parent then pcall(function() updateLogFrame:Destroy() end) end
                    updateLogFrame = nil
                else
                    if updateLogFrame and updateLogFrame.Parent then updateLogFrame.Visible = false end
                end
            end)
        end
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

    updateLogFrame = Instance.new("Frame")
    updateLogFrame.Name = "UpdateLogFrame"
    updateLogFrame.Size = UDim2.new(0, math.floor(320 * scale), 0, math.floor(150 * scale))
    updateLogFrame.Position = UDim2.new(1, -math.floor(340 * scale), 0, math.floor(50 * scale))
    updateLogFrame.BackgroundColor3 = Color3.fromRGB(10, 100, 60)
    updateLogFrame.BackgroundTransparency = 1
    updateLogFrame.BorderSizePixel = 0
    updateLogFrame.ZIndex = 4000
    updateLogFrame.Visible = false
    updateLogFrame.Parent = mainFrame
    local ulCorner = Instance.new("UICorner")
    ulCorner.CornerRadius = UDim.new(0, 10)
    ulCorner.Parent = updateLogFrame

    local ulTitle = Instance.new("TextLabel")
    ulTitle.Name = "ULTitle"
    ulTitle.Size = UDim2.new(1, -48, 0, math.floor(30 * scale))
    ulTitle.Position = UDim2.new(0, 12, 0, 8)
    ulTitle.BackgroundTransparency = 1
    ulTitle.Text = "更新日志"
    ulTitle.Font = Enum.Font.GothamBold
    ulTitle.TextSize = math.floor(16 * scale)
    ulTitle.TextColor3 = Color3.fromRGB(200, 255, 220)
    ulTitle.TextXAlignment = Enum.TextXAlignment.Left
    ulTitle.ZIndex = 4001
    ulTitle.TextTransparency = 1
    ulTitle.Parent = updateLogFrame

    local ulClose = Instance.new("TextButton")
    ulClose.Size = UDim2.new(0, 28, 0, 28)
    ulClose.Position = UDim2.new(1, -36, 0, 8)
    ulClose.BackgroundColor3 = Color3.fromRGB(40, 150, 90)
    ulClose.Text = "X"
    ulClose.Font = Enum.Font.SourceSansBold
    ulClose.TextSize = 16
    ulClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    ulClose.ZIndex = 4002
    ulClose.Parent = updateLogFrame
    local ulCloseCorner = Instance.new("UICorner")
    ulCloseCorner.CornerRadius = UDim.new(0, 6)
    ulCloseCorner.Parent = ulClose

    ulClose.MouseButton1Click:Connect(function()
        animateHideUpdateLog(false)
    end)

    local content = Instance.new("TextLabel")
    content.Name = "ULContent"
    content.Size = UDim2.new(1, -24, 1, -52)
    content.Position = UDim2.new(0, 12, 0, 40)
    content.BackgroundTransparency = 1
    content.TextWrapped = true
    content.Text = "修复已知问题"
    content.Font = Enum.Font.Gotham
    content.TextSize = math.floor(14 * scale)
    content.TextColor3 = Color3.fromRGB(200, 255, 220)
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextYAlignment = Enum.TextYAlignment.Top
    content.ZIndex = 4001
    content.TextTransparency = 1
    content.Parent = updateLogFrame

    animateShowUpdateLog()
end)

-- 三色固定点 & 运行状态灯（颜色恢复）
local fixedColors = {
    Color3.fromRGB(220, 60, 60),
    Color3.fromRGB(255, 220, 60),
    Color3.fromRGB(0, 220, 90),
}
for i = 1, 3 do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, math.floor(16 * scale), 0, math.floor(16 * scale))
    f.Position = UDim2.new(1, -math.floor(180 * scale) - (i - 1) * math.floor(20 * scale), 0.5, -math.floor(8 * scale))
    f.BackgroundColor3 = fixedColors[i]
    f.BorderSizePixel = 0
    f.Parent = topBar
    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(1, 0)
    fCorner.Parent = f
    pcall(function() if f.ZIndex and type(f.ZIndex) == "number" then f.ZIndex = 1004 end end)
end

local statusLight = Instance.new("Frame")
statusLight.Size = UDim2.new(0, math.floor(20 * scale), 0, math.floor(20 * scale))
statusLight.Position = UDim2.new(1, -math.floor(180 * scale) + math.floor(16 * scale) + 5, 0.5, -math.floor(10 * scale))
statusLight.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
statusLight.BorderSizePixel = 0
statusLight.Parent = topBar
local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(1, 0)
statusCorner.Parent = statusLight
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
    local success, tw = pcall(function() return TweenService:Create(frame, info, {BackgroundTransparency = 0.6}) end)
    if success and tw then
        pulseTween = tw
        pcall(function() tw:Play() end)
    end
end

local function setStatus(status)
    statusToken = statusToken + 1
    local my = statusToken

    stopPulse()

    local color = Color3.fromRGB(120, 120, 120)
    local holdSeconds = nil

    if status == "running" then
        color = Color3.fromRGB(255, 200, 60)
        pcall(function()
            local tw = TweenService:Create(statusLight, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color})
            if tw then tw:Play() end
        end)
        pulseLight(statusLight)
    elseif status == "success" then
        color = Color3.fromRGB(0, 200, 110)
        holdSeconds = 4
        pcall(function()
            local tw = TweenService:Create(statusLight, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color, BackgroundTransparency = 0.08})
            if tw then tw:Play() end
        end)
    elseif status == "fail" then
        color = Color3.fromRGB(220, 60, 60)
        holdSeconds = 4
        pcall(function()
            local tw = TweenService:Create(statusLight, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color, BackgroundTransparency = 0.08})
            if tw then tw:Play() end
        end)
    else
        pcall(function()
            local tw = TweenService:Create(statusLight, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = color, BackgroundTransparency = 0.08})
            if tw then tw:Play() end
        end)
    end

    if holdSeconds then
        task.delay(holdSeconds, function()
            if my == statusToken then
                stopPulse()
                pcall(function()
                    local tw = TweenService:Create(statusLight, TweenInfo.new(0.22), {BackgroundColor3 = Color3.fromRGB(120, 120, 120)})
                    if tw then tw:Play() end
                end)
            end
        end)
    end
end

-- miniFrame（小悬浮）
local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, math.floor(62 * scale), 0, math.floor(62 * scale))
miniFrame.Position = UDim2.new(0, 80, 0, 80)
miniFrame.BackgroundColor3 = Color3.fromRGB(20, 120, 70)
miniFrame.Visible = false
miniFrame.Active = true
miniFrame.Parent = screenGui
local miniCorner = Instance.new("UICorner")
miniCorner.CornerRadius = UDim.new(1, 0)
miniCorner.Parent = miniFrame

local miniIcon = Instance.new("TextButton")
miniIcon.Size = UDim2.new(1, 0, 1, 0)
miniIcon.BackgroundTransparency = 1
miniIcon.Text = "☰"
miniIcon.Font = Enum.Font.GothamBold
miniIcon.TextSize = math.floor(34 * scale)
miniIcon.TextColor3 = Color3.fromRGB(200, 255, 220)
miniIcon.Parent = miniFrame
miniIcon.MouseButton1Click:Connect(function()
    miniFrame.Visible = false
    mainFrame.Visible = true
end)

-- 线与描述
local line = Instance.new("Frame")
line.Size = UDim2.new(1, -math.floor(32 * scale), 0, 1)
line.Position = UDim2.new(0, math.floor(16 * scale), 0, math.floor(54 * scale))
line.BackgroundColor3 = Color3.fromRGB(80, 180, 120)
line.BorderSizePixel = 0
line.Parent = mainFrame

local descLabel = Instance.new("TextLabel")
descLabel.Size = UDim2.new(1, -math.floor(32 * scale), 0, math.floor(30 * scale))
descLabel.Position = UDim2.new(0, math.floor(16 * scale), 0, math.floor(60 * scale))
descLabel.BackgroundTransparency = 1
descLabel.Text = "选择任意功能并点击“运行”即可一键注入脚本"
descLabel.Font = Enum.Font.Gotham
descLabel.TextSize = math.floor(16 * scale)
descLabel.TextColor3 = Color3.fromRGB(200, 255, 220)
descLabel.TextWrapped = true
descLabel.Parent = mainFrame

-- 预置脚本列表（已清理，确保语法安全）
-- 注意：我移除了或替换了可能包含未闭合/截断字符串与复杂混淆代码的条目，保持列表语法正确。
local scriptList = {
    {
        name = "MaxHub 主脚本",
        desc = "Maxhub通讯/通知",
        code = [[
loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/993b07de445441e83e15ce5fde260d5f.lua"))()
        ]],
        code_backup = nil
    },
    {
        name = "盗版犯罪甩飞",
        desc = "是一款犯罪辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/83808083lsy-cpu/-/refs/heads/main/message%20(3)%20(1)%20(1).txt"))()
        ]],
        code_backup = nil,
        run_key = "wu666" -- 本地校验密钥（示例），替换为你需要的值或设置为 nil 以禁用
    },
    {
        name = "XA HUB",
        desc = "多游戏辅助",
        code = [[
loadstring(game:HttpGet("https://raw.gitcode.com/Xingtaiduan/Scripts/raw/main/Loader.lua"))()
        ]],
        code_backup = nil
    },
    {
        name = "过犯罪反作弊",
        desc = "犯罪越过辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/xiaomao8090/Adonis-Bypass-Framework/refs/heads/master/AdonisBypass.lua"))()
        ]],
        code_backup = nil
    },
    {
        name = "JX HUB",
        desc = "多游戏辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/jianlobiano/LOADER/refs/heads/main/JX-Loader"))()
        ]],
        code_backup = nil
    },
    {
        name = "femboyshub",
        desc = "犯罪辅助",
        code = [[
-- 注意：示例内容可能依赖 writefile 或外部资源
pcall(function()
    if writefile then
        pcall(function() writefile("Rayfield/Key System/Key123.rfld","NoHomo") end)
    end
    loadstring(game:HttpGet("https://raw.githubusercontent.com/LisSploit/FemboysHubBoosr/2784d6c4ede4340ad9af4865828d915ffc26c7bb/Criminality"))()
end)
        ]],
        code_backup = nil
    },
    {
        name = "FE EGOR V4",
        desc = "大部分游戏娱乐脚本",
        code = [[
loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Roblox-Egor-Script-50669"))()
        ]],
        code_backup = nil
    },
    {
        name = "VAPE V4",
        desc = "VAPE V4游戏辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua", true))()
        ]],
        code_backup = nil
    },
    {
        name = "清水黑火药",
        desc = "专业黑火药脚本",
        code = [[
loadstring(game:HttpGet("\104\116\116\112\115\58\47\47\112\97\115\116\101\102\121\46\97\112\112\47\65\51\78\113\122\52\78\112\47\114\97\119"))()
        ]],
        code_backup = nil
    },
    {
        name = "清风黑火药",
        desc = "黑火药辅助",
        code = [[
loadstring(game:HttpGet("https://pastebin.com/raw/wbY3hYF1"))()

        ]],
        code_backup = nil
    },
    {
        name = "皮黑火药",
        desc = "专业黑火药脚本",
        code = [[
getgenv().XiaoPi="皮脚本-内脏与黑火药" loadstring(game:HttpGet("\104\116\116\112\115\58\47\47\114\97\119\46\103\105\116\104\117\98\117\115\101\114\99\111\110\116\101\110\116\46\99\111\109\47\120\105\97\111\112\105\55\55\47\120\105\97\111\112\105\55\55\47\114\101\102\115\47\104\101\97\100\115\47\109\97\105\110\47\82\111\98\108\111\120\45\80\105\45\71\66\45\83\99\114\105\112\116\46\108\117\97"))()
        ]],
        code_backup = nil
    },
    {
        name = "99夜脚本",
        desc = "热门游戏辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/VapeVoidware/VW-Add/main/loader.lua", true))()
        ]],
        code_backup = nil
    },
    {
        name = "自定义脚本",
        desc = "请输入你自己的代码",
        code = [[
print("请在此输入你的自定义代码")
        ]],
        code_backup = nil
    }
}

-- 列表容器
local listFrame = Instance.new("Frame")
listFrame.Name = "ListFrame"
listFrame.Position = UDim2.new(0, math.floor(8 * scale), 0, math.floor(98 * scale))
listFrame.Size = UDim2.new(1, -math.floor(16 * scale), 1, -math.floor(108 * scale))
listFrame.BackgroundTransparency = 1
listFrame.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, 0)
scrollFrame.Position = UDim2.new(0, 0, 0, 0)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #scriptList * 90 * scale)
scrollFrame.ScrollBarThickness = 6
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.Parent = listFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, math.floor(10 * scale))
uiListLayout.Parent = scrollFrame
trackConnection(uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local contentY = uiListLayout.AbsoluteContentSize.Y
    if scrollFrame and scrollFrame.Parent then
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentY + math.floor(8 * scale))
    end
end))

local function niceTween(obj, tweenInfo, props)
    local ok, tw = pcall(function() return TweenService:Create(obj, tweenInfo, props) end)
    if ok and tw then
        pcall(function() tw:Play() end)
        return tw
    end
    return nil
end

-- 请求缓存（内存）与 TTL
local fetchCache = {} -- url -> {body=string, ts=os.time()}
local CACHE_TTL = 60
local function cacheGet(url)
    local ent = fetchCache[url]
    if not ent then return nil end
    if (os.time() - (ent.ts or 0)) > CACHE_TTL then
        fetchCache[url] = nil
        return nil
    end
    return ent.body
end
local function cacheSet(url, body)
    fetchCache[url] = { body = body, ts = os.time() }
end

-- 更稳健的 HTTP 抓取实现（带 HTML 检测与缓存）
local function tryGetFromUrl(url)
    -- 先检查缓存
    local cached = cacheGet(url)
    if cached then
        return true, cached
    end

    local ok, bodyOrErr = pcall(function()
        if type(game.HttpGet) == "function" then
            return game:HttpGet(url, true)
        else
            return HttpService:GetAsync(url, true)
        end
    end)
    if not ok then
        return false, ("http pcall failed: %s"):format(tostring(bodyOrErr))
    end
    if type(bodyOrErr) ~= "string" or #bodyOrErr == 0 then
        return false, ("http empty or non-string body: %s"):format(tostring(bodyOrErr))
    end

    -- 检测 HTML 错误页（代理可能返回 HTML）
    local header = bodyOrErr:sub(1, 512):lower()
    if header:find("<!doctype") or header:find("<html") or header:find("<head") or header:find("<body") then
        return false, "received html (likely proxy/error page)"
    end

    -- 缓存成功响应
    pcall(cacheSet, url, bodyOrErr)
    return true, bodyOrErr
end

local function expandGitRawMirrors(url)
    if type(url) ~= "string" then return {url} end
    local candidates = {}
    local normalized = url:gsub("^%s+", ""):gsub("%s+$", "")
    table.insert(candidates, normalized)

    local rawpath = normalized:match("^https?://raw%.githubusercontent%.com/(.+)$")
    if rawpath then
        table.insert(candidates, "https://cdn.jsdelivr.net/gh/" .. rawpath)
        table.insert(candidates, "https://raw.gitcode.com/" .. rawpath)
    end

    local gitcodepath = normalized:match("^https?://raw%.gitcode%.com/(.+)$")
    if gitcodepath then
        table.insert(candidates, "https://cdn.jsdelivr.net/gh/" .. gitcodepath)
        table.insert(candidates, "https://raw.githubusercontent.com/" .. gitcodepath)
    end

    -- 去重
    local seen = {}
    local out = {}
    for _, u in ipairs(candidates) do
        if u and not seen[u] then
            seen[u] = true
            table.insert(out, u)
        end
    end
    return out
end

-- 并行候选尝试 + 指数退避重试（首个成功即返回）
local function robustFetch(urls, opts)
    opts = opts or {}
    local maxRetries = math.max(1, opts.retries or 2)
    local baseDelay = opts.retryDelay or 0.25
    if type(urls) == "string" then urls = {urls} end
    if type(urls) ~= "table" then return false, "invalid urls param" end

    -- 扩展候选并去重
    local candidates = {}
    local seen = {}
    for _, u in ipairs(urls) do
        local cand = expandGitRawMirrors(u)
        for _, c in ipairs(cand) do
            if not seen[c] then
                seen[c] = true
                table.insert(candidates, c)
            end
        end
    end

    -- 快速缓存检查
    for _, url in ipairs(candidates) do
        local cbody = cacheGet(url)
        if cbody then
            return true, cbody, url
        end
    end

    local resultOk, resultBody, resultUrl = false, nil, nil
    local done = false
    local attemptsLogged = {}
    local maxConcurrency = math.clamp(opts.maxConcurrency or 4, 1, 8)

    local function tryCandidate(url)
        for attempt = 1, maxRetries do
            if done then return end
            local ok, bodyOrErr = tryGetFromUrl(url)
            table.insert(attemptsLogged, {url = url, attempt = attempt, ok = ok, info = tostring(bodyOrErr)})
            if ok then
                if not done then
                    done = true
                    resultOk = true
                    resultBody = bodyOrErr
                    resultUrl = url
                end
                return
            end
            local waitTime = baseDelay * (2 ^ (attempt - 1))
            task.wait(waitTime)
        end
    end

    -- 并行调度有限并发
    local idx = 1
    local active = 0

    while idx <= #candidates or active > 0 do
        while active < maxConcurrency and idx <= #candidates do
            local u = candidates[idx]
            active = active + 1
            task.spawn(function()
                tryCandidate(u)
                active = active - 1
            end)
            idx = idx + 1
        end
        if done then break end
        task.wait(0.06)
    end

    -- 等待短时间以确保 done 标志传播
    for _ = 1, 8 do
        if done then break end
        task.wait(0.05)
    end

    if resultOk then
        return true, resultBody, resultUrl
    end

    -- 构造尝试日志以便调试
    local logStr = "no candidate succeeded; attempts:\n"
    for _, a in ipairs(attemptsLogged) do
        logStr = logStr .. string.format("- %s attempt=%d ok=%s info=%s\n", tostring(a.url), a.attempt, tostring(a.ok), tostring(a.info))
    end
    return false, logStr
end

-- 显示运行结果 toast（success/fail）
local function showRunToast(success, seconds)
    seconds = seconds or 2
    local old = playerGui:FindFirstChild("RunSuccessToast")
    if old then pcall(function() old:Destroy() end) end

    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "RunSuccessToast"
    toastGui.Parent = playerGui
    toastGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toastGui.ResetOnSpawn = false

    local toastFrame = Instance.new("Frame")
    toastFrame.Size = UDim2.new(0, 220, 0, 56)
    local targetPos = UDim2.new(0, 20, 1, -80)
    local startPos = UDim2.new(0, 20, 1, 80)
    toastFrame.Position = startPos
    toastFrame.BackgroundColor3 = success and Color3.fromRGB(0, 200, 120) or Color3.fromRGB(200, 60, 60)
    toastFrame.BackgroundTransparency = 1
    toastFrame.BorderSizePixel = 0
    toastFrame.Parent = toastGui
    toastFrame.Active = true
    local tcorner = Instance.new("UICorner")
    tcorner.CornerRadius = UDim.new(0, 16)
    tcorner.Parent = toastFrame
    pcall(function() toastFrame.ZIndex = 4000 end)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 16, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = success and "运行成功" or "运行失败"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toastFrame

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(0, 48, 1, 0)
    timerLabel.Position = UDim2.new(1, -54, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = tostring(seconds)
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 20
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Center
    timerLabel.Parent = toastFrame

    local tweenIn = niceTween(toastFrame, TweenInfo.new(0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetPos, BackgroundTransparency = 0.08})
    task.spawn(function()
        local t = seconds
        while t > 0 do
            task.wait(1)
            t = t - 1
            if timerLabel and timerLabel.Parent then
                timerLabel.Text = tostring(t)
            end
        end
        local tweenOut = niceTween(toastFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = startPos, BackgroundTransparency = 1})
        if tweenOut then
            tweenOut.Completed:Connect(function()
                if toastGui and toastGui.Parent then
                    pcall(function() toastGui:Destroy() end)
                end
            end)
        else
            if toastGui and toastGui.Parent then pcall(function() toastGui:Destroy() end) end
        end
    end)
end

-- 运行面板（可用来显示“正在下载”状态）
local currentRunPanel = nil
local function showRunPanel()
    if currentRunPanel and currentRunPanel.Parent then return end
    local panel = Instance.new("Frame")
    panel.Name = "RunPanel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.6, 0)
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.BackgroundColor3 = Color3.fromRGB(20, 120, 70)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 3500
    panel.Parent = screenGui
    local pcorner = Instance.new("UICorner")
    pcorner.CornerRadius = UDim.new(0, 12)
    pcorner.Parent = panel

    local label = Instance.new("TextLabel")
    label.Name = "RunLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = "正在下载脚本..."
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = math.floor(18 * scale)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = panel
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
    local tw = niceTween(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.6, 0)})
    if tw then
        tw.Completed:Connect(function()
            if panel and panel.Parent then pcall(function() panel:Destroy() end) end
        end)
    else
        if panel and panel.Parent then pcall(function() panel:Destroy() end) end
    end
end

-- 安全加载并运行内联 code（兼容 load / loadstring）
local function safeLoadAndRun(code)
    if type(code) ~= "string" then
        return false, "代码必须为字符串"
    end
    code = tostring(code)
    code = code:gsub("\239\187\191", "") -- 去除 BOM
    local loader = load or loadstring
    if not loader then
        return false, "此环境不支持 load 或 loadstring"
    end

    -- 尝试编译并在受限环境中执行（避免 fetched 脚本直接在本体环境中造成 nil 访问引起混乱）
    local func, err = nil, nil
    local ok, res = pcall(function() return loader(code, "CustomScript", "t", _G) end)
    if ok and type(res) == "function" then
        func = res
    else
        -- 尝试不带 env 的 load / loadstring（兼容情况）
        local ok2, res2 = pcall(function() return loader(code) end)
        if ok2 and type(res2) == "function" then
            func = res2
        else
            return false, ("编译错误: %s"):format(tostring(res or res2))
        end
    end

    -- 执行在 pcall 中，捕获并返回运行时错误
    local ranOk, runRes = pcall(function()
        return func()
    end)
    if not ranOk then
        return false, ("运行时错误: %s"):format(tostring(runRes))
    end
    return true, nil
end

-- 并发执行池（允许多个脚本并发运行以减少串行等待）
local runQueue = {}
local runningWorkers = 0
local MAX_WORKERS = 2
local function workerLoop()
    while true do
        local taskFn = nil
        if #runQueue > 0 then
            taskFn = table.remove(runQueue, 1)
        else
            break
        end
        if taskFn and type(taskFn) == "function" then
            local ok, err = pcall(taskFn)
            if not ok then
                warn("worker task error:", tostring(err))
                pcall(function() setStatus("fail") end)
                pcall(function() showRunToast(false, 2) end)
            end
        end
    end
end
local function enqueueRun(fn)
    if type(fn) ~= "function" then return end
    table.insert(runQueue, fn)
    while runningWorkers < MAX_WORKERS and #runQueue > 0 do
        runningWorkers = runningWorkers + 1
        task.spawn(function()
            workerLoop()
            runningWorkers = runningWorkers - 1
        end)
    end
end

-- 提取 URL 助手
local function extractUrlsFromString(s)
    local urls = {}
    if type(s) ~= "string" then return urls end
    -- 优先通过显式引号抓取
    for url in s:gmatch('"(https?://[^"]+)"') do table.insert(urls, url) end
    for url in s:gmatch("'(https?://[^']+)'") do table.insert(urls, url) end
    -- 作为兜底匹配，但避免包含引号与空白
    for url in s:gmatch("(https?://[%w%-%._~:/%?%#%[\\]@!%$&'%(%)%*%+,;=]+)") do
        if not url:find("%s") and not url:find("[\"']") then table.insert(urls, url) end
    end
    local seen = {}
    local out = {}
    for _, u in ipairs(urls) do
        if u and not seen[u] then seen[u] = true table.insert(out, u) end
    end
    return out
end

-- Network probe + auto-degrade：检测是否被代理（UU）拦截，设置全局降级标志
local function showInfoToast(msg, seconds)
    seconds = seconds or 5
    pcall(function() print("[MSFW] "..tostring(msg)) end)
    local gui = Instance.new("ScreenGui")
    gui.Name = "MSFW_InfoToast"
    gui.Parent = playerGui
    gui.ResetOnSpawn = false
    local frm = Instance.new("Frame")
    frm.Size = UDim2.new(0, 520, 0, 56)
    frm.Position = UDim2.new(0.5, -260, 0.12, 0)
    frm.BackgroundColor3 = Color3.fromRGB(30,30,30)
    frm.BackgroundTransparency = 0.12
    frm.BorderSizePixel = 0
    frm.Parent = gui
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, -12)
    lbl.Position = UDim2.new(0, 6, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.Text = tostring(msg)
    lbl.TextWrapped = true
    lbl.Parent = frm
    task.delay(seconds, function() pcall(function() gui:Destroy() end) end)
end

local function detectProxyInterference(testUrls, opts)
    opts = opts or {}
    local retries = opts.retries or 2
    local retryDelay = opts.retryDelay or 0.35
    local anySuccess = false
    local details = {}
    for _, u in ipairs(testUrls) do
        local ok = false
        local result = nil
        for attempt = 1, retries do
            local rOk, rBody, used = robustFetch({u}, {retries = 1, retryDelay = retryDelay})
            if rOk then
                ok = true
                result = ("ok (used %s)"):format(tostring(used))
                anySuccess = true
                break
            else
                result = tostring(rBody)
                task.wait(retryDelay)
            end
        end
        table.insert(details, {url = u, ok = ok, result = result})
    end
    local interference = not anySuccess
    return interference, details
end

local probeUrls = {
    "https://raw.githubusercontent.com/github/gitignore/main/Global/JetBrains.gitignore",
    "https://cdn.jsdelivr.net/gh/github/gitignore@main/Global/JetBrains.gitignore",
    "https://raw.gitcode.com/github/gitignore/main/Global/JetBrains.gitignore"
}
task.spawn(function()
    task.wait(0.2)
    local blocked, det = detectProxyInterference(probeUrls, {retries = 2, retryDelay = 0.45})
    if blocked then
        _G.__MSFW_NETWORK_INTERFERENCE = true
        showInfoToast("检测到加速器可能拦截远端文件请求，已启用降级回退（优先使用本地备份）。若要恢复远程加载，请在 UU 中将 raw.githubusercontent.com / cdn.jsdelivr.net 等域名设置为直连或关闭该加速。", 6)
        pcall(function() warn("MSFW network probe: possible interference. details:") end)
        for _, v in ipairs(det) do
            pcall(function() warn(string.format("probe %s -> ok=%s result=%s", tostring(v.url), tostring(v.ok), tostring(v.result))) end)
        end
    else
        _G.__MSFW_NETWORK_INTERFERENCE = false
    end
end)

-- 弹出简单输入框并等待用户提交/取消，返回 enteredKey 或 nil（取消）
local function promptUserForKey(promptText, placeholder)
    local gui = Instance.new("ScreenGui")
    gui.Name = "MSFW_KeyPrompt"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.new(1,0,1,0)
    backdrop.Position = UDim2.new(0,0,0,0)
    backdrop.BackgroundTransparency = 0.6
    backdrop.BackgroundColor3 = Color3.new(0,0,0)
    backdrop.BorderSizePixel = 0
    backdrop.Parent = gui

    local boxW, boxH = 360, 120
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, boxW, 0, boxH)
    box.Position = UDim2.new(0.5, -boxW/2, 0.5, -boxH/2)
    box.BackgroundColor3 = Color3.fromRGB(18, 80, 50)
    box.BorderSizePixel = 0
    box.Parent = gui
    local bcorner = Instance.new("UICorner"); bcorner.CornerRadius = UDim.new(0,10); bcorner.Parent = box

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 0, 28)
    label.Position = UDim2.new(0, 12, 0, 12)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.TextColor3 = Color3.fromRGB(220,220,220)
    label.Text = promptText or "请输入运行密钥"
    label.Parent = box

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -24, 0, 34)
    input.Position = UDim2.new(0, 12, 0, 46)
    input.PlaceholderText = placeholder or "输入 key"
    input.BackgroundColor3 = Color3.fromRGB(40,120,80)
    input.TextColor3 = Color3.fromRGB(255,255,255)
    input.ClearTextOnFocus = false
    input.Text = ""
    input.Parent = box
    local icorner = Instance.new("UICorner"); icorner.CornerRadius = UDim.new(0,6); icorner.Parent = input

    local okBtn = Instance.new("TextButton")
    okBtn.Size = UDim2.new(0.5, -16, 0, 28)
    okBtn.Position = UDim2.new(0, 12, 1, -40)
    okBtn.BackgroundColor3 = Color3.fromRGB(0,150,100)
    okBtn.Text = "确认"
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextColor3 = Color3.fromRGB(255,255,255)
    okBtn.Parent = box
    local okCorner = Instance.new("UICorner"); okCorner.CornerRadius = UDim.new(0,6); okCorner.Parent = okBtn

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.5, -16, 0, 28)
    cancelBtn.Position = UDim2.new(0.5, 4, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(120,40,40)
    cancelBtn.Text = "取消"
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextColor3 = Color3.fromRGB(255,255,255)
    cancelBtn.Parent = box
    local cancelCorner = Instance.new("UICorner"); cancelCorner.CornerRadius = UDim.new(0,6); cancelCorner.Parent = cancelBtn

    local result = nil
    local finished = false
    local function cleanUp()
        if gui and gui.Parent then
            pcall(function() gui:Destroy() end)
        end
    end

    okBtn.MouseButton1Click:Connect(function()
        if finished then return end
        result = tostring(input.Text or "")
        finished = true
        cleanUp()
    end)
    cancelBtn.MouseButton1Click:Connect(function()
        if finished then return end
        result = nil
        finished = true
        cleanUp()
    end)
    input.FocusLost:Connect(function(enterPressed)
        if finished then return end
        if enterPressed then
            result = tostring(input.Text or "")
        else
            result = nil
        end
        finished = true
        cleanUp()
    end)

    local start = tick()
    while not finished and tick() - start < 120 do
        task.wait(0.05)
    end
    if not finished then
        cleanUp()
        return nil
    end
    return result
end

-- 渲染脚本条目并绑定运行逻辑（运行前检查网络探测标志）
for i, v in ipairs(scriptList) do
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, math.floor(70 * scale))
    item.BackgroundColor3 = Color3.fromRGB(18, 80, 50)
    item.BackgroundTransparency = 0.12
    item.BorderSizePixel = 0
    item.Parent = scrollFrame
    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = UDim.new(0, 14)
    itemCorner.Parent = item

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.6, -16, 0, math.floor(30 * scale))
    nameLabel.Position = UDim2.new(0, math.floor(12 * scale), 0, math.floor(8 * scale))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = v.name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = math.floor(18 * scale)
    nameLabel.TextColor3 = Color3.fromRGB(200, 255, 220)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = item

    local descL = Instance.new("TextLabel")
    descL.Size = UDim2.new(0.6, -16, 0, math.floor(20 * scale))
    descL.Position = UDim2.new(0, math.floor(12 * scale), 0, math.floor(36 * scale))
    descL.BackgroundTransparency = 1
    descL.Text = v.desc
    descL.Font = Enum.Font.Gotham
    descL.TextSize = math.floor(14 * scale)
    descL.TextColor3 = Color3.fromRGB(200, 255, 220)
    descL.TextXAlignment = Enum.TextXAlignment.Left
    descL.Parent = item

    local runButton = Instance.new("TextButton")
    runButton.Size = UDim2.new(0, math.floor(72 * scale), 0, math.floor(36 * scale))
    runButton.Position = UDim2.new(1, -math.floor(96 * scale), 0.5, -math.floor(18 * scale))
    runButton.BackgroundColor3 = Color3.fromRGB(40, 150, 90)
    runButton.Text = "运行"
    runButton.Font = Enum.Font.GothamBold
    runButton.TextSize = math.floor(16 * scale)
    runButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    runButton.Parent = item
    local runBtnCorner = Instance.new("UICorner")
    runBtnCorner.CornerRadius = UDim.new(0, 10)
    runBtnCorner.Parent = runButton

    -- 点击执行（增加对 v.run_key 的本地校验）
    runButton.MouseButton1Click:Connect(function()
        pcall(function() print("[MSFW] Run clicked:", v.name) end)

        -- 如果该条目需要 key，则先弹出输入框核验
        if v.run_key and type(v.run_key) == "string" and #tostring(v.run_key) > 0 then
            local entered = promptUserForKey(("运行「%s」需要密钥，请输入："):format(v.name), "运行密钥")
            if not entered then
                pcall(function() warn("[MSFW] 运行取消：未输入密钥或超时") end)
                pcall(function() showRunToast(false, 2) end)
                return
            end
            if entered ~= tostring(v.run_key) then
                pcall(function() warn("[MSFW] 错误的密钥输入:", entered) end)
                pcall(function() showRunToast(false, 2) end)
                return
            end
            -- 密钥验证通过，继续执行
        end

        enqueueRun(function()
            pcall(function() setStatus("running") end)
            task.wait(0.06)

            -- 如果探测到网络拦截，优先回退到本地备份或内联
            if _G.__MSFW_NETWORK_INTERFERENCE then
                pcall(function() warn("[MSFW] Network interference detected: using local backup if available.") end)
                if v.code_backup and type(v.code_backup) == "string" and #v.code_backup > 0 then
                    local okb, errb = safeLoadAndRun(v.code_backup)
                    if okb then
                        pcall(function() setStatus("success") end)
                        pcall(function() showRunToast(true) end)
                        return
                    else
                        pcall(function() warn("[MSFW] code_backup execution failed:", tostring(errb)) end)
                    end
                end
                local okInline, errInline = safeLoadAndRun(v.code)
                if okInline then
                    pcall(function() setStatus("success") end)
                    pcall(function() showRunToast(true) end)
                else
                    pcall(function() setStatus("fail") end)
                    pcall(function() showRunToast(false) end)
                    warn("[MSFW] Network interference and inline execution failed:", tostring(errInline))
                end
                return
            end

            -- 正常路径：尝试提取 URL 并 robustFetch
            local urls = extractUrlsFromString(v.code or "")
            if #urls > 0 then
                pcall(function() showRunPanel() end)
                local ok, bodyOrErr, usedUrl = robustFetch(urls, {retries = 3, retryDelay = 0.45, maxConcurrency = 3})
                pcall(function() hideRunPanel() end)
                if ok and type(bodyOrErr) == "string" and #bodyOrErr > 0 then
                    -- 这里对 fetched 脚本做额外的编译与执行保护，避免未捕获错误导致全局崩溃
                    local executedOk, execErr = false, nil
                    do
                        local loader = load or loadstring
                        local fn = nil
                        local compOk, compRes = pcall(function()
                            local suc, f = pcall(function() return loader(bodyOrErr, "FetchedScript", "t", _G) end)
                            if suc and type(f) == "function" then return f end
                            local suc2, f2 = pcall(function() return loader(bodyOrErr) end)
                            if suc2 and type(f2) == "function" then return f2 end
                            return nil, "compile failed"
                        end)
                        if compOk and compRes and type(compRes) == "function" then
                            fn = compRes
                        else
                            fn = nil
                            execErr = ("脚本编译失败: %s"):format(tostring(compRes))
                        end

                        if fn then
                            local runOk, runRes = pcall(function() return fn() end)
                            if runOk then
                                executedOk = true
                            else
                                executedOk = false
                                execErr = ("执行错误: %s"):format(tostring(runRes))
                            end
                        end
                    end

                    if executedOk then
                        pcall(function() setStatus("success") end)
                        pcall(function() showRunToast(true) end)
                    else
                        pcall(function() setStatus("fail") end)
                        pcall(function() showRunToast(false) end)
                        warn("[MSFW] Execution error for fetched script:", tostring(execErr))
                    end
                else
                    pcall(function() warn("[MSFW] robustFetch failed:", tostring(bodyOrErr)) end)
                    if v.code_backup and type(v.code_backup) == "string" and #v.code_backup > 0 then
                        local okb, errb = safeLoadAndRun(v.code_backup)
                        if okb then
                            pcall(function() setStatus("success") end)
                            pcall(function() showRunToast(true) end)
                        else
                            pcall(function() setStatus("fail") end)
                            pcall(function() showRunToast(false) end)
                            warn("[MSFW] code_backup execution failed:", tostring(errb))
                        end
                    else
                        local ok2, err2 = safeLoadAndRun(v.code)
                        if ok2 then
                            pcall(function() setStatus("success") end)
                            pcall(function() showRunToast(true) end)
                        else
                            pcall(function() setStatus("fail") end)
                            pcall(function() showRunToast(false) end)
                            warn("[MSFW] remote fetch failed and inline execution failed:", tostring(bodyOrErr), tostring(err2))
                        end
                    end
                end
            else
                if v.code_backup and type(v.code_backup) == "string" and #v.code_backup > 0 then
                    local okb, errb = safeLoadAndRun(v.code_backup)
                    if okb then
                        pcall(function() setStatus("success") end)
                        pcall(function() showRunToast(true) end)
                    else
                        local ok3, err3 = safeLoadAndRun(v.code)
                        if ok3 then
                            pcall(function() setStatus("success") end)
                            pcall(function() showRunToast(true) end)
                        else
                            pcall(function() setStatus("fail") end)
                            pcall(function() showRunToast(false) end)
                            warn("[MSFW] inline & backup both failed:", tostring(errb), tostring(err3))
                        end
                    end
                else
                    local ok3, err3 = safeLoadAndRun(v.code)
                    if ok3 then
                        pcall(function() setStatus("success") end)
                        pcall(function() showRunToast(true) end)
                    else
                        pcall(function() setStatus("fail") end)
                        pcall(function() showRunToast(false) end)
                        warn("[MSFW] inline script execution failed:", tostring(err3))
                    end
                end
            end
        end)
    end)
end

-- 浮动开关（用于打开/关闭主窗）
local floatToggle = Instance.new("TextButton")
floatToggle.Name = "FloatToggle"
floatToggle.Size = UDim2.new(0, math.floor(48 * scale), 0, math.floor(48 * scale))
floatToggle.BackgroundColor3 = Color3.fromRGB(20, 120, 70)
floatToggle.Text = "☰"
floatToggle.Font = Enum.Font.GothamBold
floatToggle.TextSize = math.floor(22 * scale)
floatToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
floatToggle.Parent = screenGui
local ftCorner = Instance.new("UICorner")
ftCorner.CornerRadius = UDim.new(1, 0)
ftCorner.Parent = floatToggle
pcall(function() if floatToggle.ZIndex and type(floatToggle.ZIndex) == "number" then floatToggle.ZIndex = 1006 end end)

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

local allowOpenMain = false

-- 浮动按钮拖动逻辑（更稳健）
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
            startAbsPos = safeAbsolutePosition(floatToggle)
            dragging = false
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragInput = nil
                    task.delay(0.05, function() dragging = false end)
                end
            end)
        end
    end)

    trackConnection(UserInputService.InputChanged:Connect(function(input)
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
            local vs2 = cam and cam.ViewportSize or Vector2.new(800, 600)
            local ftSize = safeAbsoluteSize(floatToggle)
            newPos = Vector2.new(
                math.clamp(newPos.X, 0, vs2.X - ftSize.X),
                math.clamp(newPos.Y, 0, vs2.Y - ftSize.Y)
            )
            floatToggle.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
            floatToggle:SetAttribute("posX", newPos.X)
            floatToggle:SetAttribute("posY", newPos.Y)
            lastMoveTime = tick()
        end
    end))

    floatToggle.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        if (tick() - lastMoveTime) < 0.12 then return end
        if dragging then return end

        if not allowOpenMain then
            pcall(function()
                local enlarge = TweenService:Create(floatToggle, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, math.floor(52 * scale), 0, math.floor(52 * scale))})
                local shrink = TweenService:Create(floatToggle, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, math.floor(48 * scale), 0, math.floor(48 * scale))})
                if enlarge then enlarge:Play() end
                if enlarge then pcall(function() enlarge.Completed:Wait() end) end
                if shrink then shrink:Play() end
            end)
            return
        end

        if not mainFrame.Visible or mainFrame.Size == UDim2.new(0, 0, 0, 0) then
            local savedMX = mainFrame:GetAttribute("posX")
            local savedMY = mainFrame:GetAttribute("posY")
            local cam = getViewportCamera()
            local vs2 = cam and cam.ViewportSize or Vector2.new(800, 600)
            local targetX, targetY
            if savedMX and savedMY then
                targetX = savedMX
                targetY = savedMY
            else
                targetX = math.floor(vs2.X * 0.5 - winW * 0.5)
                targetY = math.floor(vs2.Y * 0.5 - winH * 0.5)
            end
            mainFrame.Position = UDim2.new(0, targetX + math.floor(winW / 2), 0, targetY + math.floor(winH / 2))
            mainFrame.Size = UDim2.new(0, 0, 0, 0)
            mainFrame.BackgroundTransparency = 1
            mainFrame.Visible = true
            local twInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            pcall(function()
                local tw = TweenService:Create(mainFrame, twInfo, {
                    Size = UDim2.new(0, winW, 0, winH),
                    Position = UDim2.new(0, targetX, 0, targetY),
                    BackgroundTransparency = 0.08
                })
                if tw then tw:Play() end
            end)
            mainFrame:SetAttribute("posX", targetX)
            mainFrame:SetAttribute("posY", targetY)
        else
            local twInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            pcall(function()
                local t1 = TweenService:Create(mainFrame, twInfo, {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})
                if t1 then
                    t1:Play()
                    pcall(function() t1.Completed:Wait() end)
                end
            end)
            mainFrame.Visible = false
        end
    end)
end

-- 主窗顶部拖动逻辑（保持健壮）
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
            startAbsMain = safeAbsolutePosition(mainFrame)
            draggingMain = false
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragInputMain = nil
                    task.delay(0.05, function() draggingMain = false end)
                end
            end)
        end
    end)

    trackConnection(UserInputService.InputChanged:Connect(function(input)
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
            local vs2 = cam and cam.ViewportSize or Vector2.new(800, 600)
            local mfSize = safeAbsoluteSize(mainFrame)
            newPos = Vector2.new(
                math.clamp(newPos.X, 0, vs2.X - mfSize.X),
                math.clamp(newPos.Y, 0, vs2.Y - mfSize.Y)
            )
            mainFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
            mainFrame:SetAttribute("posX", newPos.X)
            mainFrame:SetAttribute("posY", newPos.Y)
            lastMoveTimeMain = tick()
        end
    end))

    topBar.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        if (tick() - lastMoveTimeMain) < 0.12 then return end
        if draggingMain then return end
        local absPos = safeAbsolutePosition(mainFrame)
        mainFrame:SetAttribute("posX", absPos.X)
        mainFrame:SetAttribute("posY", absPos.Y)
    end)
end

-- 视口大小变化处理
task.spawn(function()
    local cam = getViewportCamera()
    if not cam then
        repeat task.wait() until getViewportCamera()
        cam = getViewportCamera()
    end
    trackConnection(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local vs2 = cam.ViewportSize
        scale = math.min(vs2.X / 800, vs2.Y / 600, 1)
        winW, winH = math.floor(baseW * scale), math.floor(baseH * scale)
        if mainFrame and mainFrame.Parent and mainFrame.Size ~= UDim2.new(0, 0, 0, 0) then
            mainFrame.Size = UDim2.new(0, winW, 0, winH)
        end
        local savedMX = mainFrame:GetAttribute("posX")
        local savedMY = mainFrame:GetAttribute("posY")
        if savedMX and savedMY then
            local mfSize = safeAbsoluteSize(mainFrame)
            local newX = math.clamp(savedMX, 0, vs2.X - mfSize.X)
            local newY = math.clamp(savedMY, 0, vs2.Y - mfSize.Y)
            mainFrame.Position = UDim2.new(0, newX, 0, newY)
            mainFrame:SetAttribute("posX", newX)
            mainFrame:SetAttribute("posY", newY)
        else
            mainFrame.Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2)
        end
    end))
end)

if uiListLayout and uiListLayout.AbsoluteContentSize then
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + math.floor(8 * scale))
end

-- 启动公告（保持原行为）
task.delay(0.04, function()
    pcall(function()
        local function startMainExpand()
            local cam = getViewportCamera()
            local vs = cam and cam.ViewportSize or Vector2.new(800, 600)
            local targetX = math.floor(vs.X * 0.5 - winW * 0.5)
            local targetY = math.floor(vs.Y * 0.5 - winH * 0.5)
            mainFrame.Position = UDim2.new(0, targetX + math.floor(winW / 2), 0, targetY + math.floor(winH / 2))
            mainFrame.Size = UDim2.new(0, 0, 0, 0)
            mainFrame.BackgroundTransparency = 1
            mainFrame.Visible = true
            local twInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            pcall(function()
                local tw = TweenService:Create(mainFrame, twInfo, {
                    Size = UDim2.new(0, winW, 0, winH),
                    Position = UDim2.new(0, targetX, 0, targetY),
                    BackgroundTransparency = 0.08
                })
                if tw then tw:Play() end
            end)
        end

        local announceGui = Instance.new("ScreenGui")
        announceGui.Name = "MSFW_Announcement"
        announceGui.ResetOnSpawn = false
        announceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        announceGui.Parent = playerGui
        pcall(function() announceGui.DisplayOrder = math.max(5000, (announceGui.DisplayOrder or 0) + 1000) end)

        local cam = getViewportCamera()
        local vs = cam and cam.ViewportSize or Vector2.new(800, 600)
        local targetX = math.floor(vs.X * 0.5 - winW * 0.5)
        local targetY = math.floor(vs.Y * 0.5 - winH * 0.5)

        local mainAreaBlocker = Instance.new("Frame")
        mainAreaBlocker.Name = "MSFW_MainAreaBlocker"
        mainAreaBlocker.Size = UDim2.new(0, winW, 0, winH)
        mainAreaBlocker.Position = UDim2.new(0, targetX, 0, targetY)
        mainAreaBlocker.BackgroundTransparency = 1
        mainAreaBlocker.BorderSizePixel = 0
        mainAreaBlocker.Active = true
        mainAreaBlocker.Parent = announceGui
        pcall(function() mainAreaBlocker.ZIndex = 4500 end)

        local aFrame = Instance.new("Frame")
        local aW = math.floor(math.clamp(winW * 0.9, 280, 520))
        local aH = math.floor(120 * scale)
        aFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        aFrame.Size = UDim2.new(0, aW, 0, aH)
        aFrame.Position = UDim2.new(0.5, 0, 0.28, 0)
        aFrame.BackgroundColor3 = Color3.fromRGB(15, 100, 60)
        aFrame.BackgroundTransparency = 1
        aFrame.BorderSizePixel = 0
        aFrame.ZIndex = 6000
        aFrame.Parent = announceGui
        local aCorner = Instance.new("UICorner")
        aCorner.CornerRadius = UDim.new(0, 12)
        aCorner.Parent = aFrame

        local aLabel = Instance.new("TextLabel")
        aLabel.Size = UDim2.new(1, -24, 1, -24)
        aLabel.Position = UDim2.new(0, 12, 0, 12)
        aLabel.BackgroundTransparency = 1
        aLabel.Text = "欢迎使用脚本"
        aLabel.Font = Enum.Font.GothamBold
        aLabel.TextSize = math.floor(28 * scale)
        aLabel.TextColor3 = Color3.fromRGB(200, 255, 220)
        aLabel.TextTransparency = 1
        aLabel.TextWrapped = true
        aLabel.TextScaled = false
        aLabel.TextXAlignment = Enum.TextXAlignment.Center
        aLabel.TextYAlignment = Enum.TextYAlignment.Center
        aLabel.ZIndex = 6001
        aLabel.Parent = aFrame

        local fadeInTime = 1.0
        local fadeOutTime = 0.8
        local total = 4
        local holdTime = math.max(0, total - fadeInTime - fadeOutTime)

        local bgPulseTween = nil
        local posPulseTween = nil
        pcall(function()
            bgPulseTween = TweenService:Create(aFrame, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.02})
            posPulseTween = TweenService:Create(aFrame, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = UDim2.new(0.5, 0, 0.28, -6)})
        end)

        pcall(function()
            local t1 = TweenService:Create(aFrame, TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.08})
            local t2 = TweenService:Create(aLabel, TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
            if t1 then t1:Play() end
            if t2 then t2:Play() end
        end)

        task.delay(fadeInTime, function()
            pcall(function()
                if bgPulseTween then bgPulseTween:Play() end
                if posPulseTween then posPulseTween:Play() end
            end)
        end)

        task.delay(fadeInTime + holdTime, function()
            pcall(function()
                if posPulseTween then
                    pcall(function() posPulseTween:Cancel() end)
                    local t = TweenService:Create(aFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Position = UDim2.new(0.5, 0, 0.28, 0)})
                    if t then t:Play() end
                end
                if bgPulseTween then
                    pcall(function() bgPulseTween:Cancel() end)
                    local t2 = TweenService:Create(aFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.08})
                    if t2 then t2:Play() end
                end

                local t1 = TweenService:Create(aLabel, TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
                local t2 = TweenService:Create(aFrame, TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
                if t1 then t1:Play() end
                if t2 then t2:Play() end
                if t1 then
                    t1.Completed:Connect(function()
                        if announceGui and announceGui.Parent then pcall(function() announceGui:Destroy() end) end
                        allowOpenMain = true
                        pcall(startMainExpand)
                    end)
                end
            end)
        end)
    end)
end)

print("MultiScriptFloatingWindow v5.2")
