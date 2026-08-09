-- 极致反应版：周围采样 + 预测瞄准
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local ShootEvent = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("ShootEvent")
local meleeEvent = ReplicatedStorage:FindFirstChild("meleeEvent")

local autoFireEnabled = false
local fireRate = 0.1
local lastFire = 0

local MIN_RATE = 0.00
local MAX_RATE = 0.5
local RATE_RANGE = MAX_RATE - MIN_RATE

local MAX_DISTANCE = 1200
local TRACER_LIFETIME = 6
local FADE_DURATION = 0.6

local soundEnabled = true
-- 新增：音效选择（已加入第四个 Skeet）
local selectedSoundId = nil
local SOUND_OPTIONS = {
    { name = "MP5",  id = "rbxassetid://7698730413" },
    { name = "M9",   id = "rbxassetid://2934888024" },
    { name = "AK",   id = "rbxassetid://2934888736" },
    { name = "Skeet",id = "rbxassetid://8726881116" },
}

local meleeEnabled = false
local MELEE_MIN = 0
local MELEE_MAX = 8
local meleeRange = 8
local MELEE_COOLDOWN = 0.01
local meleeLastFire = 0

-- 自动换弹相关（保留手动触发函数，但已移除“5次未命中自动触发”逻辑）
local FuncReloadEvent = ReplicatedStorage:WaitForChild("GunRemotes"):FindFirstChild("FuncReload")
local RELOAD_COOLDOWN = 0.5
local reloadLastInvoke = 0
local RELOAD_DURATION = 2.6
local isReloading = false

-- ========== 新增：极致响应的采样 & 预测配置 ==========
-- 你要极致响应，所以这些默认数值较激进（短窗口、高频率）
local SAMPLE_WINDOW = 0.12      -- 样本保留的时间窗口（秒），短时间提高响应
local SAMPLE_MAX = 6           -- 每个目标保留的最大样本数
local PREDICTION_MIN = 0.3    -- 最小预测时间（秒）
local PREDICTION_MAX = 0.02  -- 最大预测时间（秒）
local PREDICTION_SPEED_FACTOR = 0-- 用于将距离映射到预测时间（可调）
-- 注意：更大的预测时间会更“超前”但容易错失高度机动目标

local samples = {} -- samples[player] = { {pos=Vector3, t=time}, ... }
local ownSamples = {} -- own position samples
local function recordSampleForPlayer(plr, pos, t)
    if not plr then return end
    local s = samples[plr]
    if not s then
        s = {}
        samples[plr] = s
    end
    table.insert(s, {pos = pos, t = t})
    -- 删除过旧样本或超出数量
    while #s > SAMPLE_MAX or (s[1] and t - s[1].t > SAMPLE_WINDOW) do
        table.remove(s, 1)
    end
end

local function recordOwnSample(pos, t)
    table.insert(ownSamples, {pos = pos, t = t})
    while #ownSamples > SAMPLE_MAX or (ownSamples[1] and t - ownSamples[1].t > SAMPLE_WINDOW) do
        table.remove(ownSamples, 1)
    end
end

local function estimateVelocityFromSamples(tlist)
    if not tlist or #tlist < 2 then
        return Vector3.new(0,0,0)
    end
    local first = tlist[1]
    local last = tlist[#tlist]
    local dt = last.t - first.t
    if dt <= 0 then return Vector3.new(0,0,0) end
    return (last.pos - first.pos) / dt
end

local function getPlayerVelocity(plr)
    local s = samples[plr]
    if not s or #s < 2 then
        return Vector3.new(0,0,0)
    end
    return estimateVelocityFromSamples(s)
end

local function getOwnVelocity()
    if #ownSamples < 2 then return Vector3.new(0,0,0) end
    return estimateVelocityFromSamples(ownSamples)
end

-- 计算预测时间：基于距离与配置，越远预测时间略增
local function computePredictionTime(dist)
    local t = dist / (600) * PREDICTION_SPEED_FACTOR -- 基于距离换算（600 可调）
    if t < PREDICTION_MIN then t = PREDICTION_MIN end
    if t > PREDICTION_MAX then t = PREDICTION_MAX end
    return t
end

-- ========== UI 与 原有控件（保持不变） ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFireUi"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local isExpanded = true

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 210)
MainFrame.Position = UDim2.new(0.02,0,0.25,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(245,245,247)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
local mainCorner = Instance.new("UICorner", MainFrame)
mainCorner.CornerRadius = UDim.new(0,14)
local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = Color3.fromRGB(220,220,225)
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.LineJoinMode = Enum.LineJoinMode.Round
mainStroke.Thickness = 1

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,44)
Header.BackgroundTransparency = 1
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0,12,0,0)
Title.BackgroundTransparency = 1
Title.Text = "Link.cc"
Title.TextColor3 = Color3.fromRGB(30,30,30)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CollapseBtn = Instance.new("ImageButton")
CollapseBtn.Size = UDim2.new(0,36,0,36)
CollapseBtn.Position = UDim2.new(1, -44, 0, 4)
CollapseBtn.BackgroundTransparency = 1
CollapseBtn.Image = "rbxassetid://3926307971"
CollapseBtn.ImageColor3 = Color3.fromRGB(120,120,130)
CollapseBtn.Parent = Header

local SwitchFrame = Instance.new("Frame")
SwitchFrame.Size = UDim2.new(0,56,0,32)
SwitchFrame.Position = UDim2.new(1, -108, 0, 6)
SwitchFrame.BackgroundColor3 = Color3.fromRGB(230,230,235)
SwitchFrame.Parent = Header
local switchCorner = Instance.new("UICorner", SwitchFrame)
switchCorner.CornerRadius = UDim.new(0,16)
local switchStroke = Instance.new("UIStroke", SwitchFrame)
switchStroke.Color = Color3.fromRGB(210,210,215)
switchStroke.Thickness = 1

local SwitchKnob = Instance.new("Frame")
SwitchKnob.Size = UDim2.new(0,28,0,28)
SwitchKnob.Position = UDim2.new(0,2,0,2)
SwitchKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
SwitchKnob.Parent = SwitchFrame
local knobCorner = Instance.new("UICorner", SwitchKnob)
knobCorner.CornerRadius = UDim.new(0,14)
local knobStroke = Instance.new("UIStroke", SwitchKnob)
knobStroke.Color = Color3.fromRGB(210,210,215)
knobStroke.Thickness = 1

local SoundFrame = Instance.new("Frame")
SoundFrame.Size = UDim2.new(0,56,0,32)
SoundFrame.Position = UDim2.new(1, -172, 0, 6)
SoundFrame.BackgroundColor3 = Color3.fromRGB(230,230,235)
SoundFrame.Parent = Header
local soundCorner = Instance.new("UICorner", SoundFrame)
soundCorner.CornerRadius = UDim.new(0,16)
local soundStroke = Instance.new("UIStroke", SoundFrame)
soundStroke.Color = Color3.fromRGB(210,210,215)
soundStroke.Thickness = 1

local SoundKnob = Instance.new("Frame")
SoundKnob.Size = UDim2.new(0,28,0,28)
SoundKnob.Position = UDim2.new(1, -30,0,2)
SoundKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
SoundKnob.Parent = SoundFrame
local soundKnobCorner = Instance.new("UICorner", SoundKnob)
soundKnobCorner.CornerRadius = UDim.new(0,14)
local soundKnobStroke = Instance.new("UIStroke", SoundKnob)
soundKnobStroke.Color = Color3.fromRGB(210,210,215)
soundKnobStroke.Thickness = 1

local SoundLabel = Instance.new("TextLabel")
SoundLabel.Size = UDim2.new(0,40,0,20)
SoundLabel.Position = UDim2.new(0,6,0,6)
SoundLabel.BackgroundTransparency = 1
SoundLabel.Text = "音效"
SoundLabel.TextColor3 = Color3.fromRGB(80,80,90)
SoundLabel.Font = Enum.Font.Gotham
SoundLabel.TextSize = 12
SoundLabel.TextXAlignment = Enum.TextXAlignment.Left
SoundLabel.Parent = SoundFrame

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,0,0,166)
Content.Position = UDim2.new(0,0,0,44)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1,-24,0,20)
StatusLabel.Position = UDim2.new(0,12,0,6)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "状态：关闭"
StatusLabel.TextColor3 = Color3.fromRGB(120,120,130)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Content

local RateLabel = Instance.new("TextLabel")
RateLabel.Size = UDim2.new(1,-24,0,20)
RateLabel.Position = UDim2.new(0,12,0,30)
RateLabel.BackgroundTransparency = 1
RateLabel.Text = string.format("开火间隔: %.2f s", fireRate)
RateLabel.TextColor3 = Color3.fromRGB(100,100,110)
RateLabel.Font = Enum.Font.Gotham
RateLabel.TextSize = 12
RateLabel.TextXAlignment = Enum.TextXAlignment.Left
RateLabel.Parent = Content

local SliderBackground = Instance.new("Frame")
SliderBackground.Size = UDim2.new(0.92,0,0,14)
SliderBackground.Position = UDim2.new(0.04,0,0,60)
SliderBackground.BackgroundColor3 = Color3.fromRGB(235,235,240)
SliderBackground.Parent = Content
local sliderBgCorner = Instance.new("UICorner", SliderBackground)
sliderBgCorner.CornerRadius = UDim.new(1,0)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new((fireRate - MIN_RATE)/RATE_RANGE, 0, 1, 0)
SliderFill.Position = UDim2.new(0,0,0,0)
SliderFill.BackgroundColor3 = Color3.fromRGB(255,255,255)
SliderFill.Parent = SliderBackground
local sliderFillCorner = Instance.new("UICorner", SliderFill)
sliderFillCorner.CornerRadius = UDim.new(1,0)

local SliderKnob = Instance.new("ImageButton")
SliderKnob.Name = "SliderKnob"
SliderKnob.Size = UDim2.new(0,26,0,26)
local initialT = math.clamp((fireRate - MIN_RATE)/RATE_RANGE, 0, 1)
SliderKnob.Position = UDim2.new(initialT, -13, 0, -6)
SliderKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
SliderKnob.Parent = SliderBackground
SliderKnob.Image = ""
local knobCorner2 = Instance.new("UICorner", SliderKnob)
knobCorner2.CornerRadius = UDim.new(1,0)
local knobShadow = Instance.new("UIStroke", SliderKnob)
knobShadow.Color = Color3.fromRGB(220,220,225)
knobShadow.Thickness = 1

-- ========== 传送/近战/范围滑块/提示（保持原样） ==========
local TeleportButton = Instance.new("ImageButton")
TeleportButton.Name = "TeleportButton"
TeleportButton.Size = UDim2.new(0, 110, 0, 32)
TeleportButton.Position = UDim2.new(0.04, 0, 0, 84)
TeleportButton.BackgroundColor3 = Color3.fromRGB(255,255,255)
TeleportButton.BorderSizePixel = 0
TeleportButton.Parent = Content
TeleportButton.Image = ""
local tpCorner = Instance.new("UICorner", TeleportButton)
tpCorner.CornerRadius = UDim.new(0, 16)
local tpStroke = Instance.new("UIStroke", TeleportButton)
tpStroke.Color = Color3.fromRGB(220,220,225)
tpStroke.Thickness = 1

local tpLabel = Instance.new("TextLabel", TeleportButton)
tpLabel.Size = UDim2.new(1, -12, 1, 0)
tpLabel.Position = UDim2.new(0, 6, 0, 0)
tpLabel.BackgroundTransparency = 1
tpLabel.Text = "传送点"
tpLabel.TextColor3 = Color3.fromRGB(30,30,30)
tpLabel.Font = Enum.Font.GothamSemibold
tpLabel.TextSize = 14
tpLabel.TextXAlignment = Enum.TextXAlignment.Left

local tpDot = Instance.new("Frame", TeleportButton)
tpDot.Size = UDim2.new(0, 22, 0, 22)
tpDot.Position = UDim2.new(1, -28, 0, 5)
tpDot.BackgroundColor3 = Color3.fromRGB(240,240,245)
tpDot.BorderSizePixel = 0
local tpDotCorner = Instance.new("UICorner", tpDot)
tpDotCorner.CornerRadius = UDim.new(1, 0)
local tpDotInner = Instance.new("Frame", tpDot)
tpDotInner.Size = UDim2.new(0, 12, 0, 12)
tpDotInner.Position = UDim2.new(0.5, -6, 0.5, -6)
tpDotInner.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
local tpDotInnerCorner = Instance.new("UICorner", tpDotInner)
tpDotInnerCorner.CornerRadius = UDim.new(1, 0)

local teleportDebounce = false
local TELEPORT_POS = Vector3.new(-932.30, 96.59, 2039.05)

TeleportButton.MouseButton1Click:Connect(function()
    if teleportDebounce then return end
    teleportDebounce = true
    local pressedTween = TweenService:Create(TeleportButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(245,245,250)})
    local releaseTween = TweenService:Create(TeleportButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255,255,255)})
    pressedTween:Play()
    pressedTween.Completed:Wait()
    local myChar = localPlayer.Character
    if not myChar then
        releaseTween:Play()
        teleportDebounce = false
        return
    end
    local hrp = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head")
    if not hrp then
        releaseTween:Play()
        teleportDebounce = false
        return
    end
    local originalCFrame = hrp.CFrame
    hrp.CFrame = CFrame.new(TELEPORT_POS)
    releaseTween:Play()
    task.delay(0.5, function()
        local charNow = localPlayer.Character
        if not charNow then
            teleportDebounce = false
            return
        end
        local hrpNow = charNow:FindFirstChild("HumanoidRootPart") or charNow:FindFirstChild("Head")
        if hrpNow and originalCFrame then
            hrpNow.CFrame = originalCFrame
        end
        teleportDebounce = false
    end)
end)

local MeleeToggle = Instance.new("ImageButton")
MeleeToggle.Name = "MeleeToggle"
MeleeToggle.Size = UDim2.new(0, 110, 0, 32)
MeleeToggle.Position = UDim2.new(0.52, 0, 0, 84)
MeleeToggle.BackgroundColor3 = Color3.fromRGB(255,255,255)
MeleeToggle.BorderSizePixel = 0
MeleeToggle.Parent = Content
MeleeToggle.Image = ""
local meleeCorner = Instance.new("UICorner", MeleeToggle)
meleeCorner.CornerRadius = UDim.new(0,16)
local meleeStroke = Instance.new("UIStroke", MeleeToggle)
meleeStroke.Color = Color3.fromRGB(220,220,225)
meleeStroke.Thickness = 1

local meleeLabel = Instance.new("TextLabel", MeleeToggle)
meleeLabel.Size = UDim2.new(1, -12, 1, 0)
meleeLabel.Position = UDim2.new(0, 6, 0, 0)
meleeLabel.BackgroundTransparency = 1
meleeLabel.Text = "近战触发"
meleeLabel.TextColor3 = Color3.fromRGB(30,30,30)
meleeLabel.Font = Enum.Font.GothamSemibold
meleeLabel.TextSize = 14
meleeLabel.TextXAlignment = Enum.TextXAlignment.Left

local meleeDot = Instance.new("Frame", MeleeToggle)
meleeDot.Size = UDim2.new(0, 22, 0, 22)
meleeDot.Position = UDim2.new(1, -28, 0, 5)
meleeDot.BackgroundColor3 = Color3.fromRGB(240,240,245)
meleeDot.BorderSizePixel = 0
local meleeDotCorner = Instance.new("UICorner", meleeDot)
meleeDotCorner.CornerRadius = UDim.new(1, 0)
local meleeDotInner = Instance.new("Frame", meleeDot)
meleeDotInner.Size = UDim2.new(0, 12, 0, 12)
meleeDotInner.Position = UDim2.new(0.5, -6, 0.5, -6)
meleeDotInner.BackgroundColor3 = Color3.fromRGB(200,200,200)
local meleeDotInnerCorner = Instance.new("UICorner", meleeDotInner)
meleeDotInnerCorner.CornerRadius = UDim.new(1, 0)

local function updateMeleeVisual(enabled)
    if enabled then
        meleeDot.BackgroundColor3 = Color3.fromRGB(100, 230, 100)
        meleeDotInner.BackgroundColor3 = Color3.fromRGB(255,255,255)
    else
        meleeDot.BackgroundColor3 = Color3.fromRGB(240,240,245)
        meleeDotInner.BackgroundColor3 = Color3.fromRGB(200,200,200)
    end
end

MeleeToggle.MouseButton1Click:Connect(function()
    meleeEnabled = not meleeEnabled
    updateMeleeVisual(meleeEnabled)
end)

local RangeLabel = Instance.new("TextLabel")
RangeLabel.Size = UDim2.new(1,-24,0,18)
RangeLabel.Position = UDim2.new(0,12,0,124)
RangeLabel.BackgroundTransparency = 1
RangeLabel.Text = string.format("近战触发范围: %.1f m", meleeRange)
RangeLabel.TextColor3 = Color3.fromRGB(100,100,110)
RangeLabel.Font = Enum.Font.Gotham
RangeLabel.TextSize = 12
RangeLabel.TextXAlignment = Enum.TextXAlignment.Left
RangeLabel.Parent = Content

local RangeBg = Instance.new("Frame")
RangeBg.Size = UDim2.new(0.92,0,0,10)
RangeBg.Position = UDim2.new(0.04,0,0,146)
RangeBg.BackgroundColor3 = Color3.fromRGB(235,235,240)
RangeBg.Parent = Content
local rangeBgCorner = Instance.new("UICorner", RangeBg)
rangeBgCorner.CornerRadius = UDim.new(1,0)

local RangeFill = Instance.new("Frame")
local initialRangeT = math.clamp((meleeRange - MELEE_MIN)/(MELEE_MAX - MELEE_MIN), 0, 1)
RangeFill.Size = UDim2.new(initialRangeT, 0, 1, 0)
RangeFill.Position = UDim2.new(0,0,0,0)
RangeFill.BackgroundColor3 = Color3.fromRGB(255,255,255)
RangeFill.Parent = RangeBg
local rangeFillCorner = Instance.new("UICorner", RangeFill)
rangeFillCorner.CornerRadius = UDim.new(1,0)

local RangeKnob = Instance.new("ImageButton")
RangeKnob.Name = "RangeKnob"
RangeKnob.Size = UDim2.new(0,18,0,18)
RangeKnob.Position = UDim2.new(initialRangeT, -9, 0, -4)
RangeKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
RangeKnob.Parent = RangeBg
RangeKnob.Image = ""
local rangeKnobCorner = Instance.new("UICorner", RangeKnob)
rangeKnobCorner.CornerRadius = UDim.new(1,0)
local rangeKnobStroke = Instance.new("UIStroke", RangeKnob)
rangeKnobStroke.Color = Color3.fromRGB(220,220,225)
rangeKnobStroke.Thickness = 1

local draggingRange = false
local function setRangeFromPosition(absX)
    local bgMin = RangeBg.AbsolutePosition.X
    local bgMax = bgMin + RangeBg.AbsoluteSize.X
    if bgMax <= bgMin then return end
    local t = math.clamp((absX - bgMin) / (bgMax - bgMin), 0, 1)
    meleeRange = MELEE_MIN + t * (MELEE_MAX - MELEE_MIN)
    RangeFill.Size = UDim2.new(t, 0, 1, 0)
    RangeKnob.Position = UDim2.new(t, -9, 0, -4)
    RangeLabel.Text = string.format("近战触发范围: %.1f m", meleeRange)
end

RangeKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingRange = true
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingRange = false
            end
        end)
    end
end)
RangeBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingRange = true
        setRangeFromPosition(input.Position.X)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingRange = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingRange then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setRangeFromPosition(input.Position.X)
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingRange = false
    end
end)

local HintLabel = Instance.new("TextLabel")
HintLabel.Size = UDim2.new(1,-24,0,20)
HintLabel.Position = UDim2.new(0,12,0,166)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "谨慎使用封号概不负责"
HintLabel.TextColor3 = Color3.fromRGB(140,140,150)
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 11
HintLabel.TextXAlignment = Enum.TextXAlignment.Left
HintLabel.Parent = Content

local function setExpanded(exp)
    if exp == isExpanded then return end
    isExpanded = exp
    if isExpanded then
        TweenService:Create(MainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0,260,0,210)}):Play()
        TweenService:Create(CollapseBtn, TweenInfo.new(0.28), {Rotation = 180}):Play()
        task.delay(0.02, function()
            for _,v in ipairs(Content:GetDescendants()) do
                if v:IsA("GuiObject") then
                    v.Visible = true
                end
            end
        end)
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0,260,0,50)}):Play()
        TweenService:Create(CollapseBtn, TweenInfo.new(0.28), {Rotation = 0}):Play()
        task.delay(0.28, function()
            for _,v in ipairs(Content:GetDescendants()) do
                if v:IsA("GuiObject") and v ~= Title then
                    v.Visible = isExpanded
                end
            end
        end)
    end
end

CollapseBtn.MouseButton1Click:Connect(function()
    setExpanded(not isExpanded)
end)

local function updateSwitchVisual(enabled)
    if enabled then
        TweenService:Create(SwitchFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(80,200,120)}):Play()
        TweenService:Create(SwitchKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, -30, 0, 2)}):Play()
    else
        TweenService:Create(SwitchFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(230,230,235)}):Play()
        TweenService:Create(SwitchKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0,2,0,2)}):Play()
    end
end

local function updateSoundVisual(enabled)
    if enabled then
        TweenService:Create(SoundFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255,190,200)}):Play()
        TweenService:Create(SoundKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, -30, 0, 2)}):Play()
    else
        TweenService:Create(SoundFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(230,230,235)}):Play()
        TweenService:Create(SoundKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0,2,0,2)}):Play()
    end
end

local function updateUi()
    if autoFireEnabled then
        StatusLabel.Text = "状态：开启"
        StatusLabel.TextColor3 = Color3.fromRGB(34,139,34)
    else
        StatusLabel.Text = "状态：关闭"
        StatusLabel.TextColor3 = Color3.fromRGB(145,35,45)
    end
    RateLabel.Text = string.format("开火间隔: %.2f s", fireRate)
    local t = math.clamp((fireRate - MIN_RATE)/RATE_RANGE, 0, 1)
    SliderFill:TweenSize(UDim2.new(t, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
    TweenService:Create(SliderKnob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(t, -13, 0, -6)}):Play()
    updateSwitchVisual(autoFireEnabled)
    updateSoundVisual(soundEnabled)
    updateMeleeVisual(meleeEnabled)
    RangeLabel.Text = string.format("近战触发范围: %.1f m", meleeRange)
    local rt = math.clamp((meleeRange - MELEE_MIN)/(MELEE_MAX - MELEE_MIN), 0, 1)
    RangeFill:TweenSize(UDim2.new(rt, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
    TweenService:Create(RangeKnob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(rt, -9, 0, -4)}):Play()
end

local function toggleAutoFire()
    autoFireEnabled = not autoFireEnabled
    updateUi()
end
SwitchFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleAutoFire()
    end
end)
SwitchKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleAutoFire()
    end
end)

-- 新增：音效选择悬浮窗（面板加宽以容纳 4 个选项）
local function showSoundSelector()
    -- 如果已存在则不重复创建
    if ScreenGui:FindFirstChild("SoundSelector") then return end

    local overlay = Instance.new("Frame")
    overlay.Name = "SoundSelector"
    overlay.Size = UDim2.new(0, 420, 0, 160) -- 加宽
    overlay.Position = UDim2.new(0.5, -210, 0.5, -80)
    overlay.BackgroundColor3 = Color3.fromRGB(20,20,20)
    overlay.BackgroundTransparency = 0
    overlay.BorderSizePixel = 0
    overlay.AnchorPoint = Vector2.new(0,0)
    overlay.Parent = ScreenGui
    local overlayCorner = Instance.new("UICorner", overlay)
    overlayCorner.CornerRadius = UDim.new(0,8)
    overlay.ZIndex = 10000

    local title = Instance.new("TextLabel", overlay)
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.new(0,10,0,8)
    title.BackgroundTransparency = 1
    title.Text = "选择命中音效"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(240,240,240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 10001

    local info = Instance.new("TextLabel", overlay)
    info.Size = UDim2.new(1, -20, 0, 18)
    info.Position = UDim2.new(0,10,0,36)
    info.BackgroundTransparency = 1
    info.Text = "点击试听并选择；取消则关闭音效"
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = Color3.fromRGB(190,190,190)
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.ZIndex = 10001

    local btnY = 64
    for i, opt in ipairs(SOUND_OPTIONS) do
        local btn = Instance.new("TextButton", overlay)
        btn.Size = UDim2.new(0, 90, 0, 34)
        btn.Position = UDim2.new(0, 16 + (i-1) * 100, 0, btnY)
        btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        btn.TextColor3 = Color3.fromRGB(240,240,240)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 14
        btn.Text = opt.name
        btn.AutoButtonColor = true
        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0,6)
        btn.ZIndex = 10002

        btn.MouseButton1Click:Connect(function()
            -- 选择并试听
            selectedSoundId = opt.id
            -- 播放试听音效（本地）
            spawn(function()
                local s = Instance.new("Sound")
                s.SoundId = selectedSoundId
                s.Volume = 1
                s.PlaybackSpeed = 1
                s.Parent = PlayerGui
                SoundService:PlayLocalSound(s)
                task.delay(1.5, function()
                    if s and s.Parent then s:Destroy() end
                end)
            end)
            -- 关闭选择界面
            if overlay and overlay.Parent then overlay:Destroy() end
            -- 更新 UI 状态显示
            updateUi()
        end)
    end

    local cancelBtn = Instance.new("TextButton", overlay)
    cancelBtn.Size = UDim2.new(0, 80, 0, 28)
    cancelBtn.Position = UDim2.new(1, -90, 1, -40)
    cancelBtn.Text = "取消"
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.TextSize = 14
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
    cancelBtn.TextColor3 = Color3.fromRGB(230,230,230)
    local cancelCorner = Instance.new("UICorner", cancelBtn)
    cancelCorner.CornerRadius = UDim.new(0,6)
    cancelBtn.ZIndex = 10002

    cancelBtn.MouseButton1Click:Connect(function()
        -- 取消选择 -> 关闭音效开关（按需求：取消则不启用）
        if overlay and overlay.Parent then overlay:Destroy() end
        soundEnabled = false
        selectedSoundId = nil
        updateUi()
    end)
end

local function toggleSound()
    soundEnabled = not soundEnabled
    if soundEnabled then
        -- 每次打开都要求重新选择（关闭再打开需重新选择）
        selectedSoundId = nil
        showSoundSelector()
    else
        -- 关闭时清除已选，以便下次重新选择
        selectedSoundId = nil
    end
    updateUi()
end
SoundFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleSound()
    end
end)
SoundKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleSound()
    end
end)

local draggingSlider = false
local function setSliderFromPosition(absX)
    local bgMin = SliderBackground.AbsolutePosition.X
    local bgMax = bgMin + SliderBackground.AbsoluteSize.X
    if bgMax <= bgMin then return end
    local t = math.clamp((absX - bgMin) / (bgMax - bgMin), 0, 1)
    fireRate = MIN_RATE + t * RATE_RANGE
    SliderFill.Size = UDim2.new(t, 0, 1, 0)
    SliderKnob.Position = UDim2.new(t, -13, 0, -6)
    updateUi()
end

SliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingSlider = false
            end
        end)
    end
end)
SliderBackground.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        setSliderFromPosition(input.Position.X)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingSlider = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingSlider then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setSliderFromPosition(input.Position.X)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)

local draggingWindow = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function startDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    draggingWindow = true
    dragInput = input
    dragStart = input.Position
    startPos = MainFrame.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            draggingWindow = false
            dragInput = nil
        end
    end)
end

Header.InputBegan:Connect(startDrag)
Title.InputBegan:Connect(startDrag)

UserInputService.InputChanged:Connect(function(input)
    if not draggingWindow or not dragInput then return end
    if input ~= dragInput then return end
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end)

updateUi()

-- ========== 渲染弹道 & 射击逻辑（调整为使用预测点做可视化，但仍向服务器发送真实 targetPart） ==========
local function fadeAndDestroyBeam(beam, parts)
    local steps = 12
    local waitTime = FADE_DURATION / steps
    for i = 1, steps do
        local alpha = i / steps
        if beam and beam.Parent then
            beam.Transparency = NumberSequence.new(alpha)
        end
        task.wait(waitTime)
    end
    if beam and beam.Parent then beam:Destroy() end
    for _,p in ipairs(parts) do
        if p and p.Parent then p:Destroy() end
    end
end

local function drawTracer(startPos, endPos)
    local p1 = Instance.new("Part")
    p1.Size = Vector3.new(0.2,0.2,0.2)
    p1.Transparency = 1
    p1.Anchored = true
    p1.CanCollide = false
    p1.CFrame = CFrame.new(startPos)
    local a1 = Instance.new("Attachment", p1)
    a1.Name = "A1"

    local p2 = Instance.new("Part")
    p2.Size = Vector3.new(0.2,0.2,0.2)
    p2.Transparency = 1
    p2.Anchored = true
    p2.CanCollide = false
    p2.CFrame = CFrame.new(endPos)
    local a2 = Instance.new("Attachment", p2)
    a2.Name = "A2"

    local beam = Instance.new("Beam")
    beam.Attachment0 = a1
    beam.Attachment1 = a2
    beam.FaceCamera = true
    beam.Width0 = 0.12
    beam.Width1 = 0.12

    local h = math.random()
    local s = 0.6 + math.random() * 0.4
    local v = 0.7 + math.random() * 0.3
    local color = Color3.fromHSV(h, s, v)
    beam.Color = ColorSequence.new(color)

    beam.Transparency = NumberSequence.new(0)
    beam.LightEmission = 0.5
    beam.Parent = p1

    p1.Parent = workspace
    p2.Parent = workspace

    task.delay(TRACER_LIFETIME - FADE_DURATION, function()
        if beam and beam.Parent then
            spawn(function() fadeAndDestroyBeam(beam, {p1,p2}) end)
        else
            for _,p in ipairs({p1,p2}) do
                if p and p.Parent then p:Destroy() end
            end
        end
    end)
end

-- 修改 playHitSound 使用选中的音效
local function playHitSound()
    if not soundEnabled then return end
    local id = selectedSoundId or SOUND_OPTIONS[1].id
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = 1
    s.PlaybackSpeed = 1
    s.Parent = PlayerGui
    SoundService:PlayLocalSound(s)
    task.delay(2, function()
        if s and s.Parent then s:Destroy() end
    end)
end

-- ========== 敌方判定 / 选择躯干部位（保持原逻辑） ==========
local function isEnemyPlayer(plr)
    if plr == localPlayer then return false end
    if plr.Team == localPlayer.Team then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end
    if localPlayer.Team == Teams.Guards and plr.Team == Teams.Inmates then
        if not char:GetAttribute("Hostile") then
            return false
        end
    end
    return true
end

local function chooseTorsoAdornee(char)
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChild("Head")
end

-- ========== 关键改动：基于采样与预测选择最佳目标部位 ==========
local function getBestTargetPart()
    local myChar = localPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") or not myChar:FindFirstChild("Head") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    local myHeadPos = myChar.Head.Position
    local ownVel = getOwnVelocity()

    local bestPart = nil
    local bestChar = nil
    local bestScore = math.huge -- 越小越好 (例如预测后与我距离)

    -- 遍历玩家，使用预测位置判断视线与距离
    for _, plr in ipairs(Players:GetPlayers()) do
        if not isEnemyPlayer(plr) then continue end
        local char = plr.Character
        if not char then continue end

        -- 优先考虑 Head
        local candidateParts = {}
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then table.insert(candidateParts, head) end
        -- 其他部位作为备选
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Head" then
                table.insert(candidateParts, part)
            end
        end

        local plrVel = getPlayerVelocity(plr)

        for _, part in ipairs(candidateParts) do
            local basePos = part.Position
            local dist = (basePos - myHeadPos).Magnitude
            if dist > MAX_DISTANCE then
                continue
            end

            -- 计算预测时间并得到预测位置
            local predT = computePredictionTime(dist)
            local predictedPos = basePos + plrVel * predT

            -- 进一步考虑自身移动（如果极快移动，抵消一部分）
            local selfComp = ownVel * (predT * 0.25) -- 只抵消一小部分，避免过度矫正
            predictedPos = predictedPos + selfComp

            -- 尝试 Raycast 到预测点（黑名单仅自己）
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Blacklist
            rp.FilterDescendantsInstances = { myChar }
            rp.IgnoreWater = true

            local dir = predictedPos - myHeadPos
            if dir.Magnitude <= 0 then
                dir = Vector3.new(0,0.001,0)
            end

            local ray = workspace:Raycast(myHeadPos, dir, rp)
            local visible = false
            if not ray then
                visible = true
            else
                local hitInst = ray.Instance
                if hitInst and hitInst:IsDescendantOf(char) then
                    visible = true
                end
            end

            if visible then
                -- 评分函数：优先较近预测距离（越小越好）
                local score = dir.Magnitude
                -- 旁注：可以对头部额外加权（加小数）
                if part == head then score = score * 0.85 end
                if score < bestScore then
                    bestScore = score
                    bestPart = part
                    bestChar = char
                end
            end
        end
    end

    return bestPart, bestChar
end

-- ========== 射击（使用预测位置作视觉反馈，但仍把 targetPart 传给服务器） ==========
local function isHoldingTool(character)
    if not character then return false end
    for _,child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            return true
        end
    end
    return false
end

local function tryInvokeReload()
    if isReloading then return end
    if not FuncReloadEvent then return end
    local now = os.clock()
    if now - reloadLastInvoke < RELOAD_COOLDOWN then return end
    local ok, res = pcall(function()
        return FuncReloadEvent:InvokeServer()
    end)
    reloadLastInvoke = now
    if ok then
        isReloading = true
        -- 显示吐司并播放换弹音（本地）
        local function showReloadToast(duration)
            -- 简略吐司：复用之前的显示函数逻辑，如果需要更复杂 UI 请参考上文
            local TOAST_NAME = "ReloadToast"
            if ScreenGui:FindFirstChild(TOAST_NAME) then return end
            local toast = Instance.new("Frame")
            toast.Name = TOAST_NAME
            toast.Size = UDim2.new(0, 220, 0, 56)
            toast.Position = UDim2.new(0, 12, 1, -72)
            toast.BackgroundColor3 = Color3.fromRGB(24,24,24)
            toast.BorderSizePixel = 0
            toast.ZIndex = 9999
            toast.Parent = ScreenGui
            local tlabel = Instance.new("TextLabel", toast)
            tlabel.Size = UDim2.new(1, -20, 0, 24)
            tlabel.Position = UDim2.new(0, 10, 0, 8)
            tlabel.BackgroundTransparency = 1
            tlabel.Text = "自动换弹"
            tlabel.Font = Enum.Font.GothamSemibold
            tlabel.TextSize = 14
            tlabel.TextColor3 = Color3.fromRGB(240,240,240)
            local progress = Instance.new("Frame", toast)
            progress.Size = UDim2.new(0,0,0,12)
            progress.Position = UDim2.new(0,10,0,32)
            progress.BackgroundColor3 = Color3.fromRGB(100,200,255)
            local durationVal = duration or RELOAD_DURATION
            spawn(function()
                local start = tick()
                while tick() - start < durationVal do
                    local p = (tick() - start)/durationVal
                    progress.Size = UDim2.new(p, 0, 1, 0)
                    task.wait()
                end
                if toast and toast.Parent then toast:Destroy() end
            end)
        end
        showReloadToast(RELOAD_DURATION)
        local reloadSound = Instance.new("Sound")
        reloadSound.SoundId = "rbxassetid://93481383611512"
        reloadSound.Volume = 1
        reloadSound.Parent = PlayerGui
        SoundService:PlayLocalSound(reloadSound)
        task.delay(RELOAD_DURATION + 0.05, function()
            if reloadSound and reloadSound.Parent then reloadSound:Destroy() end
        end)
        task.delay(RELOAD_DURATION, function() isReloading = false end)
    end
end

local function fireAtTarget(targetPart, targetChar)
    if isReloading then return end
    if not targetPart or not targetChar then return end
    local myChar = localPlayer.Character
    if not myChar or not myChar:FindFirstChild("Head") then return end
    if not isHoldingTool(myChar) then return end
    local myHum = myChar:FindFirstChild("Humanoid")
    if myHum and myHum.Health <= 0 then return end

    local startPos = myChar.Head.Position
    local targetPos = targetPart.Position

    -- 使用最新估计速度与距离计算预测点以作弹道可视反馈
    local plrVel = Vector3.new(0,0,0)
    for p,_ in pairs(samples) do
        if p and p.Character == targetChar then
            plrVel = getPlayerVelocity(p)
            break
        end
    end
    local dist = (targetPos - startPos).Magnitude
    local predT = computePredictionTime(dist)
    local predictedPos = targetPos + plrVel * predT

    -- 兼顾自身微小运动，减少偏差（仅少量补偿）
    local ownVel = getOwnVelocity()
    predictedPos = predictedPos + ownVel * (predT * 0.12)

    -- 如果预测点过远超出 MAX_DISTANCE，则回退为真实位置
    if (predictedPos - startPos).Magnitude > MAX_DISTANCE then
        predictedPos = targetPos
    end

    -- 绘制弹道到预测点（本地视觉）
    drawTracer(startPos, predictedPos)

    -- 仍向服务器发送真实 targetPart（服务器通常使用目标部位或射线）
    local packet = {
        {
            startPos,
            targetPos,
            targetPart
        }
    }
    ShootEvent:FireServer(packet)

    -- 简单命中回调检测：延迟检查血量变化以播放命中音
    local targetHum = targetChar:FindFirstChild("Humanoid")
    local prevHealth = nil
    if targetHum then prevHealth = targetHum.Health end
    if targetHum and prevHealth then
        task.delay(0.20, function()
            if not targetHum.Parent then return end
            local newHealth = targetHum.Health
            if newHealth < prevHealth then
                playHitSound()
            end
        end)
    end
end

-- ========== 采样主循环（对所有玩家与自己高频采样） ==========
-- 使用 Heartbeat 进行物理同步采样（极致反应倾向）
RunService.Heartbeat:Connect(function(dt)
    local now = tick()
    -- 记录自身位置样本（HRP 或 Head）
    local ownChar = localPlayer.Character
    if ownChar then
        local hrp = ownChar:FindFirstChild("HumanoidRootPart") or ownChar:FindFirstChild("Head")
        if hrp and hrp:IsA("BasePart") then
            recordOwnSample(hrp.Position, now)
        end
    end

    -- 记录其他玩家样本
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
                if hrp and hrp:IsA("BasePart") then
                    recordSampleForPlayer(plr, hrp.Position, now)
                end
            end
        end
    end
end)

-- ========== RunService Heartbeat 射击循环（保留你的节奏） ==========
RunService.Heartbeat:Connect(function()
    local myChar = localPlayer.Character
    if myChar then
        local myHum = myChar:FindFirstChild("Humanoid")
        if myHum and myHum.Health <= 0 then return end
    end

    if not autoFireEnabled then return end
    if isReloading then return end -- 换弹期间停止射击

    local now = os.clock()
    if now - lastFire < fireRate then return end

    local targetPart, targetChar = getBestTargetPart()
    if targetPart and targetChar then
        fireAtTarget(targetPart, targetChar)
        lastFire = now
    end
end)

updateUi()

-- ========== ESP（保留原有更细血条等） ==========
local ESP_MAX_DISTANCE = 2000
local espMap = {}

local function healthColorFromPercent(p)
    if p >= 0.66 then
        return Color3.fromRGB(50,205,50) -- 绿
    elseif p >= 0.33 then
        return Color3.fromRGB(255,215,0) -- 黄
    else
        return Color3.fromRGB(255,69,0) -- 红
    end
end

local function createEspForPlayer(plr)
    if not plr or not plr.Character then return end
    local char = plr.Character
    local adornee = chooseTorsoAdornee(char)
    if not adornee then return end

    local bg = Instance.new("BillboardGui")
    bg.Name = "ESP_" .. plr.UserId
    bg.Adornee = adornee
    bg.Size = UDim2.new(0, 110, 0, 34)
    bg.StudsOffset = Vector3.new(0, 0.2, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = ESP_MAX_DISTANCE
    bg.Parent = PlayerGui

    local main = Instance.new("Frame", bg)
    main.Size = UDim2.new(1, 0, 1, 0)
    main.BackgroundTransparency = 1

    local hbBg = Instance.new("Frame", main)
    hbBg.Name = "HealthBg"
    hbBg.Size = UDim2.new(0, 2, 0, 24)
    hbBg.Position = UDim2.new(0, 3, 0, 5)
    hbBg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    hbBg.AnchorPoint = Vector2.new(0, 0)
    hbBg.ZIndex = 9
    local hbBgCorner = Instance.new("UICorner", hbBg)
    hbBgCorner.CornerRadius = UDim.new(0,1)

    local hbFill = Instance.new("Frame", hbBg)
    hbFill.Name = "HealthFill"
    hbFill.Size = UDim2.new(1, 0, 0, 0)
    hbFill.Position = UDim2.new(0, 0, 1, 0)
    hbFill.AnchorPoint = Vector2.new(0,1)
    hbFill.BackgroundColor3 = Color3.fromRGB(50,205,50)
    hbFill.ZIndex = 9
    local hbFillCorner = Instance.new("UICorner", hbFill)
    hbFillCorner.CornerRadius = UDim.new(0,1)

    local healthText = Instance.new("TextLabel", main)
    healthText.Name = "HealthText"
    healthText.Size = UDim2.new(0, 56, 0, 14)
    healthText.Position = UDim2.new(0, 8, 0, 18)
    healthText.BackgroundTransparency = 1
    healthText.Text = ""
    healthText.TextColor3 = Color3.fromRGB(230,230,230)
    healthText.Font = Enum.Font.Gotham
    healthText.TextSize = 11
    healthText.TextXAlignment = Enum.TextXAlignment.Left
    healthText.ZIndex = 10

    local nameLabel = Instance.new("TextLabel", main)
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0, 85, 0, 14)
    nameLabel.Position = UDim2.new(0, 8, 0, 3)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.Name -- 只显示真实用户名
    nameLabel.TextColor3 = Color3.fromRGB(230,230,230)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextStrokeTransparency = 0.7
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    local nameStroke = Instance.new("UIStroke", nameLabel)
    nameStroke.Color = Color3.fromRGB(0,0,0)
    nameStroke.Transparency = 0.6
    nameStroke.Thickness = 1
    nameLabel.ZIndex = 10

    local distLabel = Instance.new("TextLabel", main)
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(0, 54, 0, 12)
    distLabel.Position = UDim2.new(1, -6, 0, 2)
    distLabel.AnchorPoint = Vector2.new(1, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = ""
    distLabel.TextColor3 = Color3.fromRGB(200,200,200)
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 11
    distLabel.TextXAlignment = Enum.TextXAlignment.Right
    distLabel.ZIndex = 10
    distLabel.TextStrokeTransparency = 0.8

    espMap[plr] = {
        gui = bg,
        healthBg = hbBg,
        healthFill = hbFill,
        nameLabel = nameLabel,
        distLabel = distLabel,
        healthText = healthText,
        adornee = adornee
    }
end

local function removeEspForPlayer(plr)
    local data = espMap[plr]
    if data then
        if data.gui and data.gui.Parent then data.gui:Destroy() end
        espMap[plr] = nil
    end
end

local function isAllyPlayer(plr)
    if not plr then return false end
    if plr.Team and localPlayer.Team and plr.Team == localPlayer.Team then
        return true
    end
    return false
end

local function updateOrCreateEsp(plr)
    if not plr or plr == localPlayer then
        removeEspForPlayer(plr)
        return
    end
    local char = plr.Character
    if not char then
        removeEspForPlayer(plr)
        return
    end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then
        removeEspForPlayer(plr)
        return
    end
    if char:FindFirstChildOfClass("ForceField") then
        removeEspForPlayer(plr)
        return
    end

    local ally = isAllyPlayer(plr)
    local enemy = isEnemyPlayer(plr)

    if not ally and not enemy then
        removeEspForPlayer(plr)
        return
    end

    local data = espMap[plr]
    if not data then
        createEspForPlayer(plr)
        data = espMap[plr]
        if not data then return end
    end

    local maxH = (hum and hum.MaxHealth ~= 0) and hum.MaxHealth or 100
    local curH = hum and hum.Health or 0
    local perc = math.clamp(curH / maxH, 0, 1)
    data.healthFill.Size = UDim2.new(1, 0, perc, 0)
    data.healthFill.BackgroundColor3 = healthColorFromPercent(perc)

    local percentDisplay = math.floor(perc * 100 + 0.5)
    data.healthText.Text = string.format("%d / %d (%d%%)", math.max(0, math.floor(curH+0.5)), math.max(1, math.floor(maxH+0.5)), percentDisplay)

    data.nameLabel.Text = plr.Name

    if ally then
        data.nameLabel.TextColor3 = Color3.fromRGB(100, 230, 100)
    else
        data.nameLabel.TextColor3 = Color3.fromRGB(230,230,230)
    end

    local myChar = localPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if myChar and myChar:FindFirstChild("HumanoidRootPart") and hrp then
        local dist = (myChar.HumanoidRootPart.Position - hrp.Position).Magnitude
        if dist >= 1000 then
            data.distLabel.Text = string.format("%.2f km", dist / 1000)
        else
            data.distLabel.Text = string.format("%.1f m", dist)
        end
    else
        data.distLabel.Text = ""
    end

    if data.adornee == nil or data.adornee.Parent == nil then
        local newAdornee = chooseTorsoAdornee(char)
        if newAdornee and data.gui then
            data.gui.Adornee = newAdornee
            data.adornee = newAdornee
        end
    end
end

Players.PlayerRemoving:Connect(function(plr)
    removeEspForPlayer(plr)
end)

local function onCharacterAdded(plr, char)
    task.delay(0.1, function()
        if plr and plr.Character == char then
            updateOrCreateEsp(plr)
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr.Character then
        onCharacterAdded(plr, plr.Character)
    end
    plr.CharacterAdded:Connect(function(char) onCharacterAdded(plr, char) end)
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char) onCharacterAdded(plr, char) end)
end)

RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == localPlayer then
            removeEspForPlayer(plr)
            continue
        end
        updateOrCreateEsp(plr)
    end
end)

-- ========== 近战自动循环（保持原逻辑） ==========
task.spawn(function()
    while true do
        task.wait(0.2)
        if not meleeEnabled then
            continue
        end
        if not meleeEvent then
            continue
        end
        local character = localPlayer.Character
        if not character then
            continue
        end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            continue
        end

        local now = os.clock()
        if now - meleeLastFire < MELEE_COOLDOWN then
            continue
        end

        local nearestPlayer = nil
        local minDistance = math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == localPlayer then continue end
            local plrChar = plr.Character
            if not plrChar then continue end
            local humRoot = plrChar:FindFirstChild("HumanoidRootPart")
            local hum = plrChar:FindFirstChild("Humanoid")
            if not humRoot or not hum or hum.Health <= 0 then continue end

            local dist = (rootPart.Position - humRoot.Position).Magnitude
            if dist <= meleeRange and dist < minDistance then
                minDistance = dist
                nearestPlayer = plr
            end
        end

        if not nearestPlayer then
            continue
        end

        local args = {
            nearestPlayer,
            1,
            1
        }
        pcall(function()
            meleeEvent:FireServer(unpack(args))
        end)
        meleeLastFire = now
    end
end)
