local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function toVector2(pos)
    if typeof(pos) == "Vector2" then
        return pos
    elseif typeof(pos) == "Vector3" then
        return Vector2.new(pos.X, pos.Y)
    else
        return Vector2.new(0,0)
    end
end

local function safeGetMouseLocation()
    local ok, res = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok and typeof(res) == "Vector2" then
        return res
    end
    return Vector2.new(0,0)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MeleeAutoAttack"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder = 99999
ScreenGui.Parent = CoreGui

local function enforceTopMost()
    local desired = 99999
    while true do
        if not ScreenGui or ScreenGui.Parent ~= CoreGui then
            pcall(function() ScreenGui.Parent = CoreGui end)
        end
        if ScreenGui.DisplayOrder ~= desired then
            pcall(function() ScreenGui.DisplayOrder = desired end)
        end
        if ScreenGui.ZIndexBehavior ~= Enum.ZIndexBehavior.Global then
            pcall(function() ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global end)
        end
        if ScreenGui.Enabled == false then
            pcall(function() ScreenGui.Enabled = true end)
        end
        task.wait(0.4)
    end
end
task.spawn(enforceTopMost)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,420,0,480)
MainFrame.Position = UDim2.new(0.02,0,0.12,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(255,245,250)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
local mainUICorner = Instance.new("UICorner", MainFrame)
mainUICorner.CornerRadius = UDim.new(0,14)

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1,0,0,64)
TitleBar.BackgroundColor3 = Color3.fromRGB(255,240,245)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
local titleUICorner = Instance.new("UICorner", TitleBar)
titleUICorner.CornerRadius = UDim.new(0,14)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1,0,1,0)
Title.BackgroundTransparency = 1
Title.Text = "Link.cc"
Title.TextColor3 = Color3.fromRGB(120,28,110)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22
Title.Parent = TitleBar
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Position = UDim2.new(0,14,0,0)
Title.AnchorPoint = Vector2.new(0,0)

local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Name = "CollapseBtn"
CollapseBtn.Size = UDim2.new(0,40,0,40)
CollapseBtn.Position = UDim2.new(1,-50,0,12)
CollapseBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
CollapseBtn.BorderSizePixel = 0
CollapseBtn.Text = "—"
CollapseBtn.TextColor3 = Color3.fromRGB(120,28,110)
CollapseBtn.Font = Enum.Font.GothamBold
CollapseBtn.TextSize = 22
CollapseBtn.Parent = TitleBar
local collapseUICorner = Instance.new("UICorner", CollapseBtn)
collapseUICorner.CornerRadius = UDim.new(0,10)

local ContentScroller = Instance.new("ScrollingFrame")
ContentScroller.Name = "ContentScroller"
ContentScroller.Size = UDim2.new(1,-28,1,-88)
ContentScroller.Position = UDim2.new(0,14,0,72)
ContentScroller.BackgroundTransparency = 1
ContentScroller.Parent = MainFrame
ContentScroller.ScrollBarThickness = 8

if ContentScroller:IsA("ScrollingFrame") then
    pcall(function() ContentScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    pcall(function() ContentScroller.ScrollBarImageColor3 = Color3.fromRGB(255,100,170) end)
    pcall(function() ContentScroller.HorizontalScrollBarEnabled = false end)
    pcall(function() ContentScroller.ClipsDescendants = true end)
end

local uiPadding = Instance.new("UIPadding", ContentScroller)
uiPadding.PaddingLeft = UDim.new(0,6)
uiPadding.PaddingRight = UDim.new(0,6)
uiPadding.PaddingTop = UDim.new(0,6)
uiPadding.PaddingBottom = UDim.new(0,6)

local uiList = Instance.new("UIListLayout", ContentScroller)
uiList.Padding = UDim.new(0,10)
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center

uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local absY = uiList.AbsoluteContentSize.Y
    if ContentScroller:IsA("ScrollingFrame") then
        ContentScroller.CanvasSize = UDim2.new(0,0,0,absY + 12)
    end
end)

local function createInfoLabel(text)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,-12,0,26)
    frame.BackgroundTransparency = 1
    frame.Parent = ContentScroller
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(160,80,200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    return label, frame
end

-- 信息标签
local InfoLabel, _ = createInfoLabel("状态：未启用")
local WeaponCheckLabel, _ = createInfoLabel("手持武器检测：无目标武器")
local WhitelistLabel, _ = createInfoLabel("白名单：无")

-- 开关创建函数
local function createSwitch(labelText, initial)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,-12,0,64)
    container.BackgroundTransparency = 1
    container.Parent = ContentScroller

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-120,1,0)
    label.Position = UDim2.new(0,12,0,0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(90,30,90)
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local sw = Instance.new("Frame")
    sw.Size = UDim2.new(0,56,0,34)
    sw.Position = UDim2.new(1,-76,0,15)
    sw.BackgroundColor3 = Color3.fromRGB(240,240,240)
    sw.Parent = container
    local swCorner = Instance.new("UICorner", sw)
    swCorner.CornerRadius = UDim.new(0,18)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0,30,0,30)
    knob.Position = UDim2.new(0,2,0,2)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Parent = sw
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(0,18)

    local clickArea = Instance.new("TextButton")
    clickArea.Size = UDim2.new(1,0,1,0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.Parent = container

    local state = initial or false
    local function updateVisual(immediate)
        local tweenTime = immediate and 0 or 0.18
        if state then
            TweenService:Create(sw, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255,100,170)}):Play()
            TweenService:Create(knob, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1,-34,0,2)}):Play()
        else
            TweenService:Create(sw, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(240,240,240)}):Play()
            TweenService:Create(knob, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0,2,0,2)}):Play()
        end
    end
    updateVisual(true)

    clickArea.MouseButton1Click:Connect(function()
        state = not state
        updateVisual(false)
    end)

    return {
        Container = container,
        Get = function() return state end,
        Set = function(v) state = v updateVisual(false) end,
        Label = label,
    }
end

-- 滑块创建函数
local function createSlider(labelText, minVal, maxVal, initial)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,-12,0,84)
    container.BackgroundTransparency = 1
    container.Parent = ContentScroller

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-120,0,20)
    label.Position = UDim2.new(0,12,0,4)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(90,30,90)
    label.Font = Enum.Font.Gotham
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0,120,0,20)
    valueLabel.Position = UDim2.new(1,-118,0,4)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(initial)
    valueLabel.TextColor3 = Color3.fromRGB(90,30,90)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextSize = 14
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-160,0,14)
    track.Position = UDim2.new(0,12,0,36)
    track.BackgroundColor3 = Color3.fromRGB(250,240,248)
    track.Parent = container
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(0,8)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0,0,1,0)
    fill.Position = UDim2.new(0,0,0,0)
    fill.BackgroundColor3 = Color3.fromRGB(255,100,170)
    fill.Parent = track
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(0,8)

    local knob = Instance.new("ImageButton")
    knob.Size = UDim2.new(0,22,0,22)
    knob.Position = UDim2.new(0,-11,0,-4)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Parent = track
    knob.Image = ""
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(0,12)

    local dragging = false
    local value = initial or minVal

    local function setVisualFromValue()
        local ratio = 0
        if maxVal > minVal then
            ratio = (value - minVal) / (maxVal - minVal)
            ratio = math.clamp(ratio,0,1)
        end
        fill.Size = UDim2.new(ratio,0,1,0)
        local trackX = track.AbsoluteSize.X
        if trackX <= 0 then return end
        local knobX = math.clamp(ratio * trackX - knob.AbsoluteSize.X/2, -knob.AbsoluteSize.X/2, trackX - knob.AbsoluteSize.X/2)
        knob.Position = UDim2.new(0, knobX, 0, knob.Position.Y.Offset)
        if maxVal - minVal <= 1 then
            valueLabel.Text = string.format("%.2f", value)
        else
            valueLabel.Text = string.format("%.2f", value)
        end
    end

    local function setValueFromAbsoluteX(x)
        local ok, trackPos = pcall(function() return track.AbsolutePosition.X end)
        local ok2, trackSize = pcall(function() return track.AbsoluteSize.X end)
        if not ok or not ok2 or trackSize <= 0 then return end
        local relative = (x - trackPos) / trackSize
        relative = math.clamp(relative, 0, 1)
        value = minVal + relative * (maxVal - minVal)
        value = math.floor(value * 100 + 0.5) / 100
        setVisualFromValue()
    end

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            pcall(function() ContentScroller.ScrollingEnabled = false end)
        end
    end)
    knob.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            pcall(function() ContentScroller.ScrollingEnabled = true end)
        end
    end)
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pcall(function() ContentScroller.ScrollingEnabled = false end)
            local pos = safeGetMouseLocation()
            setValueFromAbsoluteX(pos.X)
            dragging = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            pcall(function() ContentScroller.ScrollingEnabled = true end)
        end
    end)

    local conn
    conn = RunService.RenderStepped:Connect(function()
        if dragging then
            local pos = safeGetMouseLocation()
            pcall(function() setValueFromAbsoluteX(pos.X) end)
        end
    end)

    task.delay(0.06, function()
        setVisualFromValue()
    end)

    return {
        Container = container,
        Get = function() return value end,
        Set = function(v) value = math.clamp(v, minVal, maxVal) value = math.floor(value * 100 + 0.5) / 100 setVisualFromValue() end,
        Label = label,
        ValueLabel = valueLabel,
    }
end

-- 重新排序：先白名单显示（列表区域），再开关，再滑块
-- 白名单数据结构（UserId -> true）
local whitelist = {}
local whitelistButtons = {} -- UserId -> button

local function isWhitelisted(plr)
    if not plr then return false end
    return whitelist[plr.UserId] == true
end

-- 创建白名单选择面板
local function createWhitelistSection()
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,-12,0,140)
    container.BackgroundTransparency = 1
    container.Parent = ContentScroller

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,20)
    title.Position = UDim2.new(0,6,0,0)
    title.BackgroundTransparency = 1
    title.Text = "白名单（点击以切换，选中则跳过自动攻击与静默转向）"
    title.TextColor3 = Color3.fromRGB(80,30,120)
    title.Font = Enum.Font.Gotham
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = container

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1,0,1,-28)
    listFrame.Position = UDim2.new(0,0,0,28)
    listFrame.BackgroundTransparency = 1
    listFrame.Parent = container

    local listScroller = Instance.new("ScrollingFrame")
    listScroller.Size = UDim2.new(1,0,1,0)
    listScroller.BackgroundTransparency = 1
    listScroller.ScrollBarThickness = 6
    listScroller.Parent = listFrame
    listScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroller.ClipsDescendants = true

    local listLayout = Instance.new("UIListLayout", listScroller)
    listLayout.Padding = UDim.new(0,6)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function makePlayerButton(plr)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-12,0,28)
        btn.BackgroundColor3 = Color3.fromRGB(245,240,247)
        btn.BorderSizePixel = 0
        btn.Text = plr.Name .. " (" .. tostring(plr.UserId) .. ")"
        btn.TextColor3 = Color3.fromRGB(80,30,120)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.Parent = listScroller
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0,8)

        local function updateVisual()
            if isWhitelisted(plr) then
                btn.BackgroundColor3 = Color3.fromRGB(255,220,235)
                btn.TextColor3 = Color3.fromRGB(160,40,140)
            else
                btn.BackgroundColor3 = Color3.fromRGB(245,240,247)
                btn.TextColor3 = Color3.fromRGB(80,30,120)
            end
        end

        btn.MouseButton1Click:Connect(function()
            local uid = plr.UserId
            if whitelist[uid] then
                whitelist[uid] = nil
            else
                whitelist[uid] = true
            end
            updateVisual()
            -- 更新常亮显示
            local names = {}
            for id,_ in pairs(whitelist) do
                local p = Players:GetPlayerByUserId(id)
                if p then table.insert(names, p.Name) end
            end
            if #names == 0 then
                WhitelistLabel.Text = "白名单：无"
            else
                WhitelistLabel.Text = "白名单：" .. table.concat(names, "，")
            end
        end)

        whitelistButtons[plr.UserId] = btn
        updateVisual()
    end

    -- 初始化现有玩家
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            makePlayerButton(plr)
        end
    end

    -- 监听玩家加入/离开
    Players.PlayerAdded:Connect(function(plr)
        -- 延迟一点以保证 Name 等可用
        task.delay(0.05, function() 
            makePlayerButton(plr)
        end)
    end)
    Players.PlayerRemoving:Connect(function(plr)
        local btn = whitelistButtons[plr.UserId]
        if btn then
            pcall(function() btn:Destroy() end)
            whitelistButtons[plr.UserId] = nil
        end
        whitelist[plr.UserId] = nil
        -- 更新常亮显示
        local names = {}
        for id,_ in pairs(whitelist) do
            local p = Players:GetPlayerByUserId(id)
            if p then table.insert(names, p.Name) end
        end
        if #names == 0 then
            WhitelistLabel.Text = "白名单：无"
        else
            WhitelistLabel.Text = "白名单：" .. table.concat(names, "，")
        end
    end)
end

-- 先创建白名单面板（所以它会在界面上靠前）
createWhitelistSection()

-- 开关：重排顺序（常亮显示开关放前）
local AlwaysHeadSwitch = createSwitch("始终攻击头部", false) -- 新增：始终攻击头部开关
local AutoSwitch = createSwitch("杀戮光环", false)
local SilentSwitch = createSwitch("静默转向", false)
local TeamCheckSwitch = createSwitch("队伍检查（只攻击敌对）", false)

-- 滑块：按新顺序排列，并把攻击距离上限改为 14
local RangeSlider = createSlider("攻击距离 (米)", 0, 14, 14) -- 上限 14
local SilentRangeSlider = createSlider("静默转向触发范围 (米)", 0, 20, 10)
local MultiTargetSlider = createSlider("同时攻击目标数 (1-3)", 1, 3, 1)
local CooldownSlider = createSlider("攻击冷却 (秒)", 0.5, 5, 0.5)
local SilentCooldownSlider = createSlider("静默转向冷却 (秒，0可用)", 0, 5, 0)

local autoAttack = false
local silentAim = false
local teamCheck = false
local alwaysHead = false -- 新增变量
local attackRange = 14
local attackCoolDown = 0.5
local maxTargets = 1
local silentRange = 10
local silentCooldown = 0
local weaponList = {"Metal Shard","Stunstick","Riot Control","Door & Glass Shard","Glass Fragment"}
local character, rootPart
local lastAttackTime = 0
local lastSilentTime = 0

local ToolSoundEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("ToolSound")
local ServiceFolder = ReplicatedStorage:WaitForChild("Service")
local NamespaceModule = require(ServiceFolder:WaitForChild("Namespaces"))
local MeleeSendHit = NamespaceModule.MeleeReplication.packets.sendHit.send

local function refreshChar(char)
    character = char
    rootPart = character and character:WaitForChild("HumanoidRootPart")
end
if LocalPlayer.Character then
    task.spawn(refreshChar, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(refreshChar)

spawn(function()
    local prev = AutoSwitch.Get()
    while true do
        local cur = AutoSwitch.Get()
        if cur ~= prev then
            prev = cur
            autoAttack = cur
            InfoLabel.Text = autoAttack and "状态：运行中" or "状态：未启用"
        end
        task.wait(0.08)
    end
end)

spawn(function()
    local prev = SilentSwitch.Get()
    while true do
        local cur = SilentSwitch.Get()
        if cur ~= prev then
            prev = cur
            silentAim = cur
        end
        task.wait(0.08)
    end
end)

spawn(function()
    local prev = TeamCheckSwitch.Get()
    while true do
        local cur = TeamCheckSwitch.Get()
        if cur ~= prev then
            prev = cur
            teamCheck = cur
        end
        task.wait(0.08)
    end
end)

spawn(function()
    local prev = AlwaysHeadSwitch.Get()
    while true do
        local cur = AlwaysHeadSwitch.Get()
        if cur ~= prev then
            prev = cur
            alwaysHead = cur
        end
        task.wait(0.08)
    end
end)

spawn(function()
    while true do
        local r = RangeSlider.Get() or 14
        if r > 14 then r = 14 end
        attackRange = math.floor(r * 100 + 0.5) / 100
        RangeSlider.ValueLabel.Text = string.format("%.2f 米", attackRange)

        local cd = CooldownSlider.Get() or 0.5
        if cd < 0.5 then cd = 0.5 end
        attackCoolDown = math.floor(cd * 100 + 0.5) / 100
        CooldownSlider.ValueLabel.Text = string.format("%.2f s", attackCoolDown)

        local mt = MultiTargetSlider.Get() or 1
        mt = math.clamp(math.floor(mt+0.5), 1, 3)
        maxTargets = mt
        MultiTargetSlider.ValueLabel.Text = tostring(maxTargets)

        local sr = SilentRangeSlider.Get() or 10
        silentRange = math.floor(sr * 100 + 0.5) / 100
        SilentRangeSlider.ValueLabel.Text = string.format("%.2f 米", silentRange)

        local sc = SilentCooldownSlider.Get() or 0
        silentCooldown = math.floor(sc * 100 + 0.5) / 100
        SilentCooldownSlider.ValueLabel.Text = string.format("%.2f s", silentCooldown)

        task.wait(0.12)
    end
end)

local function isMeleeTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool:FindFirstChild("Handle") or tool:FindFirstChild("Grip") or tool:FindFirstChild("Primary") or tool:FindFirstChild("Controller") then
        return true
    end
    local attrs = {"MeleeIcon","SwingCooldown","AnimationAttack","AnimationEquip","PulloutTime","RegisterOnce","CustomHitbox"}
    for _, a in ipairs(attrs) do
        if tool:GetAttribute(a) ~= nil then
            return true
        end
    end
    for _, name in ipairs(weaponList) do
        local tname = tostring(tool.Name or "")
        if string.lower(tname) == string.lower(name) or string.find(string.lower(tname), string.lower(name), 1, true) then
            return true
        end
    end
    return false
end

local function getHeldWeapon()
    if not LocalPlayer.Character then return nil end
    local char = LocalPlayer.Character
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and isMeleeTool(tool) then
        return tool
    end
    for _, obj in ipairs(char:GetChildren()) do
        if obj and obj:IsA("Tool") and isMeleeTool(obj) then
            return obj
        end
    end
    return nil
end

-- 视线检测函数：若从 attackerRoot 到 targetPart 有遮挡（非目标角色本身），则返回 false
local function hasLineOfSight(attackerRoot, targetPart)
    if not attackerRoot or not targetPart then return false end
    local dir = targetPart.Position - attackerRoot.Position
    if dir.Magnitude <= 0 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    -- 忽略攻击者自身以免检测到自己的腰带等
    if character then
        params.FilterDescendantsInstances = {character}
    else
        params.FilterDescendantsInstances = {}
    end
    local ray = workspace:Raycast(attackerRoot.Position, dir, params)
    if not ray then
        return true
    end
    local hitInst = ray.Instance
    if hitInst and hitInst:IsDescendantOf(targetPart.Parent) then
        return true
    end
    return false
end

local function findTargetLimb(char, preferHead)
    -- 若 preferHead 为 true，则优先返回 Head 部位（若存在）
    if preferHead then
        local head = char:FindFirstChild("Head") or char:FindFirstChild("head")
        if head then
            return head
        end
    end
    local limb = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm") or char:FindFirstChild("RightUpperArm")
    if not limb then
        limb = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    end
    -- 最后仍可尝试 Head 作为后备
    if not limb then
        limb = char:FindFirstChild("Head") or char:FindFirstChild("head")
    end
    return limb
end

-- collectTargets 增加白名单与视线/墙体检测
local function collectTargets(maxCount, maxRange)
    if not rootPart then return {} end
    local results = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            -- 跳过白名单玩家
            if isWhitelisted(plr) then
                -- 跳过
            else
                local tarRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                local tarHum = plr.Character:FindFirstChild("Humanoid")
                if tarRoot and tarHum and tarHum.Health > 0 and tarHum:GetState() ~= Enum.HumanoidStateType.Dead then
                    if teamCheck then
                        if LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team then
                            -- 同队则跳过
                        else
                            local dis = (rootPart.Position - tarRoot.Position).Magnitude
                            if dis <= maxRange then
                                -- 视线检查（优先头部检测）
                                local limb = findTargetLimb(plr.Character, true)
                                if limb and hasLineOfSight(rootPart, limb) then
                                    table.insert(results, {plr=plr, dist=dis})
                                end
                            end
                        end
                    else
                        local dis = (rootPart.Position - tarRoot.Position).Magnitude
                        if dis <= maxRange then
                            local limb = findTargetLimb(plr.Character, true)
                            if limb and hasLineOfSight(rootPart, limb) then
                                table.insert(results, {plr=plr, dist=dis})
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(results, function(a,b) return a.dist < b.dist end)
    local out = {}
    for i=1, math.min(#results, maxCount) do
        table.insert(out, results[i].plr)
    end
    return out
end

RunService.RenderStepped:Connect(function()
    if not silentAim or not rootPart then return end
    local now = os.clock()
    if now - lastSilentTime < silentCooldown then return end

    local candidates = collectTargets(1, silentRange)
    local targetPlr = candidates[1]
    if targetPlr and targetPlr.Character then
        -- 确认目标不在白名单（collectTargets 已处理），并进行瞄准
        local tarLimb = findTargetLimb(targetPlr.Character, alwaysHead)
        if tarLimb then
            pcall(function()
                rootPart.CFrame = CFrame.new(rootPart.Position, tarLimb.Position)
            end)
            lastSilentTime = now
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not autoAttack or not rootPart then return end
    local now = os.clock()
    if now - lastAttackTime < attackCoolDown then return end

    local heldTool = getHeldWeapon()
    if heldTool then
        pcall(function() WeaponCheckLabel.Text = "手持武器检测："..heldTool.Name end)
    else
        pcall(function() WeaponCheckLabel.Text = "手持武器检测：无目标武器" end)
        return
    end

    local targets = collectTargets(maxTargets, attackRange)
    if #targets == 0 then return end

    for idx, targetPlr in ipairs(targets) do
        if not targetPlr or not targetPlr.Character then
        else
            local tarChar = targetPlr.Character
            local tarHum = tarChar:FindFirstChild("Humanoid")
            local tarLimb = findTargetLimb(tarChar, alwaysHead)
            if not tarHum or not tarLimb then
            else
                if silentAim then
                    pcall(function()
                        rootPart.CFrame = CFrame.new(rootPart.Position, tarLimb.Position)
                    end)
                end

                if heldTool.Name == "Glass Fragment" then
                    pcall(function() ToolSoundEvent:FireServer(heldTool, "Swing") end)
                else
                    pcall(function() ToolSoundEvent:FireServer(heldTool, "Plan") end)
                    task.wait(0.03)
                end

                pcall(function()
                    MeleeSendHit({tarHum, tarLimb, heldTool})
                end)

                if heldTool.Name ~= "Glass Fragment" then
                    task.wait(0.03)
                    pcall(function() ToolSoundEvent:FireServer(heldTool, "Commit") end)
                end

                if idx < #targets then
                    task.wait(0.02)
                end
            end
        end
    end

    lastAttackTime = now
end)

local collapsed = false
local expandedSize = UDim2.new(0,420,0,480)
local collapsedSize = UDim2.new(0,420,0,64)
MainFrame.Size = expandedSize
CollapseBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    if collapsed then
        local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(MainFrame, tweenInfo, {Size = collapsedSize}):Play()
        ContentScroller.Visible = false
        CollapseBtn.Text = "+"
    else
        ContentScroller.Visible = true
        local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(MainFrame, tweenInfo, {Size = expandedSize}):Play()
        CollapseBtn.Text = "—"
    end
end)

if RangeSlider and RangeSlider.Set then RangeSlider.Set(14) end
if CooldownSlider and CooldownSlider.Set then CooldownSlider.Set(0.5) end
if MultiTargetSlider and MultiTargetSlider.Set then MultiTargetSlider.Set(1) end
if SilentRangeSlider and SilentRangeSlider.Set then SilentRangeSlider.Set(10) end
if SilentCooldownSlider and SilentCooldownSlider.Set then SilentCooldownSlider.Set(0) end
if AlwaysHeadSwitch and AlwaysHeadSwitch.Set then AlwaysHeadSwitch.Set(false) end

MainFrame.Active = true
local draggingWindow = false
local dragStart = Vector2.new(0,0)
local startPos = Vector2.new(0,0)
local targetPos = MainFrame.AbsolutePosition

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingWindow = true
        dragStart = toVector2(input.Position)
        local ap = MainFrame.AbsolutePosition
        if typeof(ap) == "Vector2" then
            startPos = ap
        else
            startPos = Vector2.new(ap.X or 0, ap.Y or 0)
        end
        targetPos = startPos
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingWindow = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingWindow and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local curPos = toVector2(input.Position)
        local delta = curPos - dragStart
        local desired = startPos + delta
        targetPos = desired
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if draggingWindow and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        draggingWindow = false
    end
end)

RunService.RenderStepped:Connect(function(dt)
    local cur = MainFrame.AbsolutePosition
    if not cur then return end
    local curPos = Vector2.new(cur.X, cur.Y)
    local lerpFactor = math.clamp(1 - math.exp(-12 * dt), 0, 1)
    local newPos = curPos:Lerp(targetPos, lerpFactor)
    MainFrame.Position = UDim2.new(0, math.floor(newPos.X + 0.5), 0, math.floor(newPos.Y + 0.5))
end)

do
    MainFrame.Visible = false

    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "MeleeStartupOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.Parent = CoreGui

    local overlay = Instance.new("Frame")
    overlay.Name = "BlackOverlay"
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.Position = UDim2.new(0,0,0,0)
    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 999
    overlay.Parent = overlayGui

    local centerText = Instance.new("TextLabel")
    centerText.Name = "StartupText"
    centerText.Size = UDim2.new(0.7,0,0.18,0)
    centerText.Position = UDim2.new(0.5,0,0.5,0)
    centerText.AnchorPoint = Vector2.new(0.5,0.5)
    centerText.BackgroundTransparency = 1
    centerText.Text = "Link.cc"
    centerText.TextColor3 = Color3.fromRGB(255,240,250)
    centerText.TextStrokeTransparency = 0.6
    centerText.Font = Enum.Font.GothamBold
    centerText.TextSize = 72
    centerText.TextTransparency = 1
    centerText.ZIndex = 1000
    centerText.Parent = overlay

    local ok, err = pcall(function()
        local tIn = TweenService:Create(overlay, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        tIn:Play()
        tIn.Completed:Wait()

        local tTextIn = TweenService:Create(centerText, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0, TextStrokeTransparency = 0})
        local startPos = centerText.Position
        local newY = startPos.Y.Offset - 20
        local destPos = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, newY)
        local tFloat = TweenService:Create(centerText, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = destPos})

        tTextIn:Play()
        tFloat:Play()
        tTextIn.Completed:Wait()

        task.wait(60)

        local tTextOut = TweenService:Create(centerText, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1})
        tTextOut:Play()
        tTextOut.Completed:Wait()

        local tOut = TweenService:Create(overlay, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
        tOut:Play()
        tOut.Completed:Wait()
    end)

    pcall(function() overlayGui:Destroy() end)
    MainFrame.Visible = true
end

ScreenGui.ResetOnSpawn = false
