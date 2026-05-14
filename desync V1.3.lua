local plsraknet = Raknet or raknet
if not plsraknet then return end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PLS_DesyncGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 240, 0, 120)
Frame.Position = UDim2.new(0, 20, 0, 20)
Frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner", Frame)
UICorner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1, -16, 0, 28)
Title.Position = UDim2.new(0, 8, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "PLS Desync"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.SourceSansSemibold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left

local function tryRestorePosition()
    if not LocalPlayer then return end
    local val = LocalPlayer:GetAttribute("PLS_DesyncGUI_Pos")
    if type(val) == "string" then
        local a,b,c,d = string.match(val, "^([%d%.%-e]+),([%d%.%-e]+),([%d%.%-e]+),([%d%.%-e]+)$")
        if a and b and c and d then
            local sx = tonumber(a)
            local ox = tonumber(b)
            local sy = tonumber(c)
            local oy = tonumber(d)
            if sx and ox and sy and oy then
                Frame.Position = UDim2.new(sx, ox, sy, oy)
            end
        end
    end
end

tryRestorePosition()

local function savePosition()
    if not LocalPlayer then return end
    local pos = Frame.Position
    local sxs = tostring(pos.X.Scale)
    local oxs = tostring(pos.X.Offset)
    local sys = tostring(pos.Y.Scale)
    local oys = tostring(pos.Y.Offset)
    LocalPlayer:SetAttribute("PLS_DesyncGUI_Pos", table.concat({sxs, oxs, sys, oys}, ","))
end

local function showInjectionNotification(duration)
    duration = duration or 5

    local notifGui = Instance.new("ScreenGui")
    notifGui.Name = "PLS_InjectionNotif"
    notifGui.ResetOnSpawn = false
    notifGui.Parent = CoreGui

    local width = 260
    local height = 56
    local margin = 20

    local notifFrame = Instance.new("Frame")
    notifFrame.Size = UDim2.new(0, width, 0, height)
    notifFrame.Position = UDim2.new(0, -width - margin, 1, -height - margin)
    notifFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    notifFrame.BorderSizePixel = 0
    notifFrame.AnchorPoint = Vector2.new(0, 0)
    notifFrame.Parent = notifGui

    local nc = Instance.new("UICorner", notifFrame)
    nc.CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Parent = notifFrame
    title.Size = UDim2.new(1, -12, 0, 26)
    title.Position = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "注入成功"
    title.TextColor3 = Color3.fromRGB(220, 220, 220)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.SourceSansSemibold
    title.TextSize = 16

    local pbBg = Instance.new("Frame")
    pbBg.Parent = notifFrame
    pbBg.Size = UDim2.new(1, -16, 0, 12)
    pbBg.Position = UDim2.new(0, 8, 1, -20)
    pbBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    pbBg.BorderSizePixel = 0
    pbBg.ClipsDescendants = true

    local pbCorner = Instance.new("UICorner", pbBg)
    pbCorner.CornerRadius = UDim.new(0, 6)

    local pb = Instance.new("Frame")
    pb.Parent = pbBg
    pb.Size = UDim2.new(1, 0, 1, 0)
    pb.Position = UDim2.new(0, 0, 0, 0)
    pb.BackgroundColor3 = Color3.fromRGB(120, 200, 120)
    pb.BorderSizePixel = 0

    local pbCorner2 = Instance.new("UICorner", pb)
    pbCorner2.CornerRadius = UDim.new(0, 6)

    local slideIn = TweenService:Create(notifFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, margin, 1, -height - margin)})
    slideIn:Play()

    local progressTween = TweenService:Create(pb, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)})
    progressTween:Play()

    progressTween.Completed:Connect(function()
        wait(0.08)
        local slideOut = TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, -width - margin, 1, -height - margin)})
        slideOut:Play()
        slideOut.Completed:Connect(function()
            notifGui:Destroy()
        end)
    end)
end

local function createToggle(parent, yOffset, labelText)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -80, 0, 24)
    Label.Position = UDim2.new(0, 8, 0, yOffset)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(255,255,255)
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.SourceSans
    Label.TextSize = 16
    Label.Parent = parent

    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0, 50, 0, 24)
    ToggleButton.Position = UDim2.new(1, -60, 0, yOffset)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(40,40,40)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Text = ""
    ToggleButton.AutoButtonColor = false
    ToggleButton.Parent = parent

    local ToggleCorner = Instance.new("UICorner", ToggleButton)
    ToggleCorner.CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 20, 0, 20)
    Knob.Position = UDim2.new(0, 2, 0.5, -10)
    Knob.BackgroundColor3 = Color3.fromRGB(200,200,200)
    Knob.BorderSizePixel = 0
    Knob.Parent = ToggleButton

    local KnobCorner = Instance.new("UICorner", Knob)
    KnobCorner.CornerRadius = UDim.new(1, 0)

    local state = false
    local callback
    local function update(stateNow)
        local knobPos = stateNow and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        local bgColor = stateNow and Color3.fromRGB(80,80,80) or Color3.fromRGB(40,40,40)
        TweenService:Create(Knob, TweenInfo.new(0.18), {Position = knobPos}):Play()
        TweenService:Create(ToggleButton, TweenInfo.new(0.18), {BackgroundColor3 = bgColor}):Play()
    end

    ToggleButton.MouseButton1Click:Connect(function()
        state = not state
        update(state)
        if callback then
            pcall(callback, state)
        end
    end)

    return {
        label = Label;
        button = ToggleButton;
        knob = Knob;
        getState = function() return state end;
        setState = function(v) state = v; update(state) end;
        onToggled = function(fn) callback = fn end;
    }
end

local toggle1 = createToggle(Frame, 36, "desync 1")
local toggle2 = createToggle(Frame, 36 + 36, "desync 2")

local activationId1 = 0

toggle1.onToggled(function(state)
    if plsraknet and plsraknet.desync then
        pcall(function() plsraknet.desync(state) end)
    end

    activationId1 = activationId1 + 1
    local myId = activationId1

    if state then
        task.spawn(function()
            task.wait(3)
            if myId == activationId1 and toggle1.getState() then
                local player = LocalPlayer
                if player then
                    local character = player.Character or player.CharacterAdded:Wait()
                    if character then
                        local humanoid = character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            pcall(function()
                                humanoid.Health = 0
                            end)
                        end
                    end
                end
                showInjectionNotification(5)
            end
        end)
    end
end)

toggle2.onToggled(function(state)
    if plsraknet and plsraknet.desync then
        pcall(function() plsraknet.desync(state) end)
    end
end)

do
    local dragging, dragInput, dragStart, startPos
    local BLOCK_ACTION = "PLS_BlockTouchWhileDragging_Main"
    local blocking = false

    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            dragInput = input

            if input.UserInputType == Enum.UserInputType.Touch and not blocking then
                ContextActionService:BindAction(BLOCK_ACTION, function() return Enum.ContextActionResult.Sink end, false, Enum.UserInputType.Touch)
                blocking = true
            end

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if blocking then
                        ContextActionService:UnbindAction(BLOCK_ACTION)
                        blocking = false
                    end
                    pcall(savePosition)
                end
            end)
        end
    end)

    Frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local Ball = Instance.new("TextButton")
Ball.Size = UDim2.new(0, 48, 0, 48)
Ball.Position = UDim2.new(0, 10, 0.5, -24)
Ball.AnchorPoint = Vector2.new(0, 0)
Ball.BackgroundColor3 = Color3.fromRGB(60,60,60)
Ball.BorderSizePixel = 0
Ball.Text = ""
Ball.Parent = ScreenGui
Ball.Name = "PLS_FloatBall"
local ballCorner = Instance.new("UICorner", Ball)
ballCorner.CornerRadius = UDim.new(1, 0)

local inner = Instance.new("Frame", Ball)
inner.Size = UDim2.new(0, 18, 0, 18)
inner.Position = UDim2.new(0.5, -9, 0.5, -9)
inner.BackgroundColor3 = Color3.fromRGB(200,200,200)
inner.BorderSizePixel = 0
local innerCorner = Instance.new("UICorner", inner)
innerCorner.CornerRadius = UDim.new(1, 0)

do
    local ballDragging, ballDragInput, ballDragStart, ballStartPos
    local BALL_BLOCK_ACTION = "PLS_BlockTouchWhileDragging_Ball"
    local ballBlocking = false
    local ballWasDragging = false

    Ball.Activated:Connect(function()
        if ballWasDragging then
            ballWasDragging = false
            return
        end
        local targetVis = not Frame.Visible
        Frame.Visible = targetVis
        if targetVis then
            tryRestorePosition()
        end
    end)

    Ball.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ballDragging = true
            ballDragStart = input.Position
            ballStartPos = Ball.Position
            ballDragInput = input

            if input.UserInputType == Enum.UserInputType.Touch and not ballBlocking then
                ContextActionService:BindAction(BALL_BLOCK_ACTION, function() return Enum.ContextActionResult.Sink end, false, Enum.UserInputType.Touch)
                ballBlocking = true
            end

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    ballDragging = false
                    if ballBlocking then
                        ContextActionService:UnbindAction(BALL_BLOCK_ACTION)
                        ballBlocking = false
                    end
                    delay(0.03, function() ballWasDragging = false end)
                end
            end)
        end
    end)

    Ball.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            ballDragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == ballDragInput and ballDragging then
            local delta = input.Position - ballDragStart
            if (delta.Magnitude > 6) then
                ballWasDragging = true
            end
            Ball.Position = UDim2.new(
                ballStartPos.X.Scale,
                ballStartPos.X.Offset + delta.X,
                ballStartPos.Y.Scale,
                ballStartPos.Y.Offset + delta.Y
            )
        end
    end)
end

Frame.Visible = true
