-- Linkv2.lua (修复版，包含“记住设备 Key（24 小时）”持久化)
task.spawn(function()
    task.wait(2.6)

    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local Camera = workspace.CurrentCamera
    local CoreGui = game:GetService("CoreGui")
    local HttpService = game:GetService("HttpService")

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PM_Blur_UI"
    ScreenGui.Parent = CoreGui

    local IS_PC = false
    pcall(function()
        IS_PC = (not UserInputService.TouchEnabled) and UserInputService.KeyboardEnabled
    end)
    local ALLOW_SHRINK = not IS_PC

    local PANEL_WIDTH = 600
    local PANEL_HEIGHT = 340
    local CENTER_Y_OFFSET = -200

    local CenterPanel = Instance.new("Frame", ScreenGui)
    CenterPanel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
    CenterPanel.Position = UDim2.new(0.5, -PANEL_WIDTH/2, 0.5, CENTER_Y_OFFSET)
    CenterPanel.BackgroundColor3 = Color3.fromRGB(20,20,20)
    CenterPanel.BackgroundTransparency = 0.05
    CenterPanel.BorderSizePixel = 0
    CenterPanel.ZIndex = 10
    CenterPanel.Active = true
    CenterPanel.ClipsDescendants = false
    local _origCenterClips = CenterPanel.ClipsDescendants

    local CenterCorner = Instance.new("UICorner")
    CenterCorner.CornerRadius = UDim.new(0, 12)
    CenterCorner.Parent = CenterPanel

    local _origCenterBg = CenterPanel.BackgroundColor3
    local _origCenterBgTrans = CenterPanel.BackgroundTransparency
    local _origCenterCorner = CenterCorner.CornerRadius

    local isAnimating = false

    local TitleLabel = Instance.new("TextLabel", CenterPanel)
    TitleLabel.Size = UDim2.new(1, -24, 0, 36)
    TitleLabel.Position = UDim2.new(0, 12, 0, 6)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 18
    TitleLabel.TextColor3 = Color3.fromRGB(0, 122, 204)
    TitleLabel.Text = "Link"
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.TextYAlignment = Enum.TextYAlignment.Center
    TitleLabel.ZIndex = CenterPanel.ZIndex + 1

    local STATUS_ENABLED = true
    local StatusFrame = Instance.new("Frame", CenterPanel)
    StatusFrame.Name = "StatusFrame"
    StatusFrame.Size = UDim2.new(0, 220, 0, 24)
    StatusFrame.Position = UDim2.new(0, 160, 0, 6)
    StatusFrame.BackgroundTransparency = 1
    StatusFrame.BorderSizePixel = 0
    StatusFrame.ZIndex = CenterPanel.ZIndex + 1

    local PingLabel = Instance.new("TextLabel", StatusFrame)
    PingLabel.Size = UDim2.new(0.6, 0, 1, 0)
    PingLabel.Position = UDim2.new(0, 0, 0, 0)
    PingLabel.BackgroundTransparency = 1
    PingLabel.Font = Enum.Font.Gotham
    PingLabel.TextSize = 12
    PingLabel.TextColor3 = Color3.fromRGB(200,200,200)
    PingLabel.Text = "Ping: --ms"
    PingLabel.TextXAlignment = Enum.TextXAlignment.Left
    PingLabel.TextYAlignment = Enum.TextYAlignment.Center
    PingLabel.ZIndex = StatusFrame.ZIndex + 1
    PingLabel.TextTransparency = 0

    local FpsLabel = Instance.new("TextLabel", StatusFrame)
    FpsLabel.Size = UDim2.new(0.4, -4, 1, 0)
    FpsLabel.Position = UDim2.new(0.6, 4, 0, 0)
    FpsLabel.BackgroundTransparency = 1
    FpsLabel.Font = Enum.Font.Gotham
    FpsLabel.TextSize = 12
    FpsLabel.TextColor3 = Color3.fromRGB(200,200,200)
    FpsLabel.Text = "FPS: --"
    FpsLabel.TextXAlignment = Enum.TextXAlignment.Right
    FpsLabel.TextYAlignment = Enum.TextYAlignment.Center
    FpsLabel.ZIndex = StatusFrame.ZIndex + 1
    FpsLabel.TextTransparency = 0

    StatusFrame.Visible = STATUS_ENABLED

    local logCount = 0
    local function showLogMessage(text)
        logCount = logCount + 1
        local isSecondOrLater = logCount >= 2
        local parentTo = ScreenGui
        local pos = UDim2.new(1, -220, 0, 8)
        if isSecondOrLater and RightTitle and RightTitle.Text == "功能设置" and RightArea and RightArea.Parent then
            parentTo = RightArea
            pos = UDim2.new(0.5, -160, 0, 8)
        else
            parentTo = ScreenGui
            pos = UDim2.new(1, -220, 0, 8)
        end

        local logFrame = Instance.new("Frame", parentTo)
        logFrame.Name = "PCLog_"..tostring(logCount)
        logFrame.Size = UDim2.new(0, 200, 0, 36)
        logFrame.Position = pos
        logFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
        logFrame.BackgroundTransparency = 0.02
        logFrame.BorderSizePixel = 0
        logFrame.ZIndex = 800 + logCount
        Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0,6)

        local txt = Instance.new("TextLabel", logFrame)
        txt.Size = UDim2.new(1, -12, 1, 0)
        txt.Position = UDim2.new(0, 8, 0, 0)
        txt.BackgroundTransparency = 1
        txt.Font = Enum.Font.Gotham
        txt.TextSize = 14
        txt.TextColor3 = Color3.fromRGB(200,200,200)
        txt.Text = text
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.TextYAlignment = Enum.TextYAlignment.Center
        txt.ZIndex = logFrame.ZIndex + 1

        pcall(function()
            local fadeIn = TweenService:Create(logFrame, TweenInfo.new(0.18), {BackgroundTransparency = 0})
            fadeIn:Play()
        end)
        spawn(function()
            task.wait(60.6)
            pcall(function()
                local fadeOut = TweenService:Create(logFrame, TweenInfo.new(0.22), {BackgroundTransparency = 1})
                fadeOut:Play()
                fadeOut.Completed:Wait()
            end)
            pcall(function() logFrame:Destroy() end)
        end)
    end

    if IS_PC then
        showLogMessage("检测到PC端用户")
    else
        showLogMessage("检测到移动端用户")
    end

    local function pingColorForValue(p)
        if not p then return Color3.fromRGB(52,211,153) end
        if p <= 99 then
            return Color3.fromRGB(52,211,153)
        elseif p <= 120 then
            return Color3.fromRGB(245,158,11)
        else
            return Color3.fromRGB(239,68,68)
        end
    end

    local function fpsColorForValue(fps)
        if not fps then return Color3.fromRGB(52,211,153) end
        if fps >= 55 then
            return Color3.fromRGB(52,211,153)
        elseif fps >= 40 then
            return Color3.fromRGB(245,158,11)
        elseif fps >= 30 then
            return Color3.fromRGB(239,68,68)
        else
            return Color3.fromRGB(239,68,68)
        end
    end

    do
        local localPlayer = Players.LocalPlayer
        local frameCount = 0
        local frameAccumTime = 0.0
        local currentPing = 0
        local serverPingItem = nil

        pcall(function()
            local ok, Stats = pcall(function() return game:GetService("Stats") end)
            if ok and Stats and Stats.Network and Stats.Network.ServerStatsItem then
                serverPingItem = Stats.Network.ServerStatsItem["Data Ping"]
            end
        end)

        RunService.RenderStepped:Connect(function(dt)
            frameCount = frameCount + 1
            frameAccumTime = frameAccumTime + (dt or 0)
        end)

        spawn(function()
            while ScreenGui and ScreenGui.Parent do
                local gotPing = false
                local newPing = 0
                if serverPingItem then
                    pcall(function()
                        local v = serverPingItem:GetValue()
                        if v then
                            local num = tonumber(v) or 0
                            if num and num > 0 then
                                if num > 1000 then
                                    newPing = math.floor(num)
                                elseif num >= 0.01 and num <= 10 then
                                    newPing = math.floor(num * 1000)
                                else
                                    newPing = math.floor(num)
                                end
                                gotPing = true
                            end
                        end
                    end)
                end

                if not gotPing then
                    pcall(function()
                        if localPlayer and localPlayer.GetNetworkPing then
                            local p = localPlayer:GetNetworkPing()
                            if p and p > 0 then
                                if p < 10 then
                                    newPing = math.floor(p * 1000)
                                else
                                    newPing = math.floor(p)
                                end
                                gotPing = true
                            end
                        end
                    end)
                end

                if not gotPing then
                    newPing = 0
                end
                currentPing = newPing

                local fps = 0
                if frameAccumTime and frameAccumTime > 0 then
                    fps = math.floor((frameCount / frameAccumTime) + 0.5)
                else
                    fps = 0
                end
                frameCount = 0
                frameAccumTime = 0.0

                pcall(function()
                    if StatusFrame and StatusFrame.Parent and StatusFrame.Visible then
                        PingLabel.Text = ("Ping: %dms"):format(currentPing or 0)
                        PingLabel.TextColor3 = pingColorForValue(currentPing or 0)
                        local fpsText = ("FPS: %d"):format(fps or 0)
                        FpsLabel.Text = fpsText
                        FpsLabel.TextColor3 = fpsColorForValue(fps or 0)
                    end
                end)

                for i = 1, 10 do
                    task.wait(0.1)
                    if not (ScreenGui and ScreenGui.Parent) then break end
                end
            end
        end)
    end

    local LEFT_PADDING = 8
    local TOP_CONTENT_Y = 52
    local LEFT_AREA_WIDTH = 180

    local LEFT_ITEM_HEIGHT = 40
    local LEFT_ITEM_PADDING = 8

    local LeftArea = Instance.new("Frame", CenterPanel)
    LeftArea.Name = "LeftArea"
    LeftArea.Size = UDim2.new(0, LEFT_AREA_WIDTH, 1, -TOP_CONTENT_Y - 12)
    LeftArea.Position = UDim2.new(0, LEFT_PADDING, 0, TOP_CONTENT_Y)
    LeftArea.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LeftArea.BackgroundTransparency = 0.02
    LeftArea.BorderSizePixel = 0
    LeftArea.ZIndex = CenterPanel.ZIndex + 1
    Instance.new("UICorner", LeftArea).CornerRadius = UDim.new(0, 10)

    local LeftAreaTitle = Instance.new("TextLabel", LeftArea)
    LeftAreaTitle.Size = UDim2.new(1, -16, 0, 28)
    LeftAreaTitle.Position = UDim2.new(0, 8, 0, 8)
    LeftAreaTitle.BackgroundTransparency = 1
    LeftAreaTitle.Font = Enum.Font.Gotham
    LeftAreaTitle.TextSize = 14
    LeftAreaTitle.Text = "功能区"
    LeftAreaTitle.TextColor3 = Color3.fromRGB(80,80,80)
    LeftAreaTitle.ZIndex = LeftArea.ZIndex + 1
    LeftAreaTitle.TextXAlignment = Enum.TextXAlignment.Left

    local LeftList = Instance.new("ScrollingFrame", LeftArea)
    LeftList.Name = "LeftList"
    LeftList.Active = true
    LeftList.Size = UDim2.new(1, -16, 1, -48)
    LeftList.Position = UDim2.new(0, 8, 0, 36)
    LeftList.BackgroundTransparency = 1
    LeftList.BorderSizePixel = 0
    LeftList.ScrollBarThickness = 6
    LeftList.CanvasSize = UDim2.new(0,0,0,0)
    LeftList.ZIndex = LeftArea.ZIndex + 1
    LeftList.ClipsDescendants = true

    local LeftListLayout = Instance.new("UIListLayout", LeftList)
    LeftListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LeftListLayout.Padding = UDim.new(0,LEFT_ITEM_PADDING)

    local selectionIndicator = nil
    local INDICATOR_WIDTH = 6
    local INDICATOR_MARGIN_LEFT = 4
    local INDICATOR_TWEEN_TIME = 0.22
    local INDICATOR_COLOR = Color3.fromRGB(0,102,204)

    LeftList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        local ok, pos = pcall(function() return LeftList.CanvasPosition end)
        if not ok then return end
        if pos and pos.X ~= 0 then
            pcall(function()
                LeftList.CanvasPosition = Vector2.new(0, pos.Y)
            end)
        end
    end)

    local RightArea = Instance.new("Frame", CenterPanel)
    RightArea.Name = "RightArea"
    RightArea.Size = UDim2.new(1, -LEFT_AREA_WIDTH - LEFT_PADDING*3, 1, -TOP_CONTENT_Y - 12)
    RightArea.Position = UDim2.new(0, LEFT_AREA_WIDTH + LEFT_PADDING*2, 0, TOP_CONTENT_Y)
    RightArea.BackgroundTransparency = 1
    RightArea.BorderSizePixel = 0
    RightArea.ZIndex = CenterPanel.ZIndex + 1

    local RightTitle = Instance.new("TextLabel", RightArea)
    RightTitle.Size = UDim2.new(1, -12, 0, 28)
    RightTitle.Position = UDim2.new(0, 6, 0, 6)
    RightTitle.BackgroundTransparency = 1
    RightTitle.Font = Enum.Font.GothamBold
    RightTitle.TextSize = 15
    RightTitle.Text = "内容"
    RightTitle.TextColor3 = Color3.fromRGB(200,200,200)
    RightTitle.TextXAlignment = Enum.TextXAlignment.Left
    RightTitle.ZIndex = RightArea.ZIndex + 1

    local RightList = Instance.new("ScrollingFrame", RightArea)
    RightList.Name = "RightList"
    RightList.Active = true
    RightList.Size = UDim2.new(1, -12, 1, -48)
    RightList.Position = UDim2.new(0, 6, 0, 36)
    RightList.BackgroundTransparency = 1
    RightList.BorderSizePixel = 0
    RightList.ScrollBarThickness = 6
    RightList.ZIndex = RightArea.ZIndex + 1

    local RightListLayout = Instance.new("UIListLayout", RightList)
    RightListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    RightListLayout.Padding = UDim.new(0,8)

    local MiniBtn = Instance.new("TextButton", CenterPanel)
    MiniBtn.Size = UDim2.new(0, 28, 0, 28)
    MiniBtn.Position = UDim2.new(1, -36, 0, 6)
    MiniBtn.AnchorPoint = Vector2.new(0, 0)
    MiniBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
    MiniBtn.BackgroundTransparency = 0.02
    MiniBtn.Font = Enum.Font.GothamBold
    MiniBtn.TextSize = 16
    MiniBtn.Text = "●"
    MiniBtn.TextColor3 = Color3.fromRGB(80,80,80)
    MiniBtn.ZIndex = CenterPanel.ZIndex + 2
    Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(0,6)

    if IS_PC then
        pcall(function()
            MiniBtn.Visible = false
            MiniBtn.Active = false
            MiniBtn.AutoButtonColor = false
        end)
    end

    local Alive = true
    local PanelVisible = true
    local IsBall = false
    local savedState = {}

    local HITBOX_SIZE = 120
    local BallHitbox = Instance.new("Frame", ScreenGui)
    BallHitbox.Name = "BallHitbox"
    BallHitbox.Size = UDim2.new(0, HITBOX_SIZE, 0, HITBOX_SIZE)
    BallHitbox.BackgroundTransparency = 1
    BallHitbox.BorderSizePixel = 0
    BallHitbox.ZIndex = 300
    BallHitbox.Visible = false
    BallHitbox.Active = true
    BallHitbox.ClipsDescendants = false

    if IS_PC then
        pcall(function()
            BallHitbox.Visible = false
            BallHitbox.Active = false
        end)
    end

    local CLICK_RADIUS_FACTOR = 0.62
    local function isPosInsideBall(pos, clickOnly)
        if not pos then return false end
        local ballTopLeft = savedState.BallAbsPosition
        local ballTarget = savedState.BallTarget
        if not ballTopLeft or not ballTarget then
            local ok, abs = pcall(function() return CenterPanel.AbsolutePosition, CenterPanel.AbsoluteSize end)
            if ok and abs and abs ~= nil then
                local absPos, absSize = abs[1], abs[2]
                if absPos and absSize then
                    ballTopLeft = Vector2.new(absPos.X, absPos.Y)
                    ballTarget = {W = absSize.X, H = absSize.Y}
                end
            end
        end
        if not ballTopLeft or not ballTarget then return false end
        local bw, bh = ballTarget.W or 48, ballTarget.H or 48
        local center = Vector2.new(ballTopLeft.X + bw/2, ballTopLeft.Y + bh/2)
        local dx = pos.X - center.X
        local dy = pos.Y - center.Y
        local dist = math.sqrt(dx*dx + dy*dy)
        local radius = math.max(bw, bh) / 2
        if clickOnly then
            radius = radius * CLICK_RADIUS_FACTOR
        end
        return dist <= radius
    end

    local function shrinkToBall()
        if not ALLOW_SHRINK then return end
        if IsBall then return end
        if isAnimating then return end
        isAnimating = true

        local panelAbsPos, panelAbsSize = (function() return CenterPanel.AbsolutePosition, CenterPanel.AbsoluteSize end)()
        savedState.PanelAbsPosition = Vector2.new(panelAbsPos.X, panelAbsPos.Y)
        savedState.PanelAbsSize = Vector2.new(panelAbsSize.X, panelAbsSize.Y)
        local targetW, targetH = 48, 48
        local ballTopLeft
        if savedState.BallAbsPosition then
            ballTopLeft = Vector2.new(savedState.BallAbsPosition.X, savedState.BallAbsPosition.Y)
        else
            ballTopLeft = Vector2.new(
                math.floor(savedState.PanelAbsPosition.X + savedState.PanelAbsSize.X/2 - targetW/2),
                math.floor(savedState.PanelAbsPosition.Y + savedState.PanelAbsSize.Y/2 - targetH/2)
            )
        end
        local hitOffsetX = math.floor((HITBOX_SIZE - targetW) / 2)
        local hitOffsetY = math.floor((HITBOX_SIZE - targetH) / 2)
        savedState.BallTarget = {W = targetW, H = targetH, HitOffsetX = hitOffsetX, HitOffsetY = hitOffsetY}
        savedState.BallAbsPosition = Vector2.new(ballTopLeft.X, ballTopLeft.Y)
        IsBall = true

        pcall(function() StatusFrame.Visible = false end)
        pcall(function() CenterPanel.ClipsDescendants = true end)

        local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local t = TweenService:Create(CenterPanel, tweenInfo, {
            Size = UDim2.new(0, targetW, 0, targetH),
            Position = UDim2.new(0, ballTopLeft.X, 0, ballTopLeft.Y)
        })
        t:Play()
        t.Completed:Connect(function()
            CenterCorner.CornerRadius = UDim.new(1,0)
            CenterPanel.BackgroundColor3 = Color3.fromRGB(20,20,20)
            CenterPanel.BackgroundTransparency = 0
            TitleLabel.Visible = false
            LeftArea.Visible = false
            RightArea.Visible = false
            MiniBtn.Visible = false
            pcall(function() StatusFrame.Visible = false end)
            BallHitbox.Position = UDim2.new(0, ballTopLeft.X - hitOffsetX, 0, ballTopLeft.Y - hitOffsetY)
            BallHitbox.Visible = true
            isAnimating = false
        end)
    end

    local function restoreFromBall()
        if not ALLOW_SHRINK then return end
        if not IsBall then return end
        if isAnimating then return end
        isAnimating = true

        IsBall = false
        BallHitbox.Visible = false
        CenterCorner.CornerRadius = _origCenterCorner or UDim.new(0,12)
        CenterPanel.BackgroundColor3 = _origCenterBg or Color3.fromRGB(20,20,20)
        CenterPanel.BackgroundTransparency = _origCenterBgTrans or 0.05
        TitleLabel.Visible = true
        LeftArea.Visible = true
        RightArea.Visible = true
        MiniBtn.Visible = true

        local targetPos = savedState.PanelAbsPosition or Vector2.new( (Camera.ViewportSize.X - PANEL_WIDTH)/2, (Camera.ViewportSize.Y/2 + CENTER_Y_OFFSET) )
        local targetSize = savedState.PanelAbsSize or Vector2.new(PANEL_WIDTH, PANEL_HEIGHT)

        pcall(function() CenterPanel.ClipsDescendants = true end)

        local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local t = TweenService:Create(CenterPanel, tweenInfo, {
            Size = UDim2.new(0, targetSize.X, 0, targetSize.Y),
            Position = UDim2.new(0, targetPos.X, 0, targetPos.Y)
        })
        t:Play()
        t.Completed:Connect(function()
            pcall(function() StatusFrame.Visible = STATUS_ENABLED end)
            pcall(function() CenterPanel.ClipsDescendants = _origCenterClips end)
            isAnimating = false
        end)
    end

    MiniBtn.MouseButton1Click:Connect(function()
        if not ALLOW_SHRINK then return end
        if isAnimating then return end
        if IsBall then
            restoreFromBall()
        else
            shrinkToBall()
        end
    end)

    do
        local dragging = false
        local dragInput = nil
        local dragStart = Vector2.new(0,0)
        local panelStart = Vector2.new(0,0)

        TitleLabel.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if IsBall then
                    return
                end
                dragging = true
                dragInput = input
                dragStart = input.Position
                local absPos, absSize = (function() return CenterPanel.AbsolutePosition, CenterPanel.AbsoluteSize end)()
                panelStart = Vector2.new(absPos.X, absPos.Y)

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        dragInput = nil
                        local curAbsPos = CenterPanel.AbsolutePosition
                        savedState.PanelAbsPosition = Vector2.new(curAbsPos.X, curAbsPos.Y)
                        savedState.PanelAbsSize = Vector2.new(CenterPanel.AbsoluteSize.X, CenterPanel.AbsoluteSize.Y)
                    end
                end)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input ~= dragInput or not dragging then return end
            pcall(function()
                local delta = input.Position - dragStart
                local newAbs = Vector2.new(panelStart.X + delta.X, panelStart.Y + delta.Y)
                CenterPanel.Position = UDim2.new(0, newAbs.X, 0, newAbs.Y)
            end)
        end)
    end

    if ALLOW_SHRINK then
        do
            local ballDragging = false
            local ballDragInput = nil
            local ballDragStart = Vector2.new(0,0)
            local ballHitStartPanelTopLeft = Vector2.new(0,0)
            local ballMoved = false
            local maybeClick = false
            local DRAG_THRESHOLD = 6

            local function readInputPosition(input)
                local ok, pos = pcall(function() return input.Position end)
                if ok and pos then return pos end
                local ok2, mpos = pcall(function() return UserInputService:GetMouseLocation() end)
                if ok2 and mpos then return mpos end
                return nil
            end

            local function onBallInputBegan(input)
                if not IsBall then return end
                if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end

                local pos = readInputPosition(input)
                if not pos then return end
                if not isPosInsideBall(pos, false) then
                    return
                end

                ballDragging = true
                ballDragInput = input
                ballDragStart = pos
                local panelAbsPos = CenterPanel.AbsolutePosition
                ballHitStartPanelTopLeft = Vector2.new(panelAbsPos.X, panelAbsPos.Y)
                ballMoved = false
                maybeClick = true

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        if maybeClick then
                            local endPos = readInputPosition(input)
                            if endPos and isPosInsideBall(endPos, true) then
                                restoreFromBall()
                            end
                        else
                            if savedState.BallAbsPosition then
                                local curPanelPos = CenterPanel.AbsolutePosition
                                savedState.BallAbsPosition = Vector2.new(curPanelPos.X, curPanelPos.Y)
                            end
                        end
                        ballDragging = false
                        ballDragInput = nil
                        maybeClick = false
                    end
                end)
            end

            local function onInputChanged(inp)
                if inp ~= ballDragInput or not ballDragging then return end
                pcall(function()
                    local pos = readInputPosition(inp)
                    if not pos then return end
                    local delta = pos - ballDragStart
                    if delta.Magnitude > DRAG_THRESHOLD then
                        ballMoved = true
                        maybeClick = false
                    end
                    local newPanelTopLeft = Vector2.new(ballHitStartPanelTopLeft.X + delta.X, ballHitStartPanelTopLeft.Y + delta.Y)
                    CenterPanel.Position = UDim2.new(0, newPanelTopLeft.X, 0, newPanelTopLeft.Y)
                    savedState.BallAbsPosition = Vector2.new(newPanelTopLeft.X, newPanelTopLeft.Y)
                    if savedState.BallTarget then
                        local hitOffsetX = savedState.BallTarget.HitOffsetX or math.floor((HITBOX_SIZE - savedState.BallTarget.W)/2)
                        local hitOffsetY = savedState.BallTarget.HitOffsetY or math.floor((HITBOX_SIZE - savedState.BallTarget.H)/2)
                        BallHitbox.Position = UDim2.new(0, newPanelTopLeft.X - hitOffsetX, 0, newPanelTopLeft.Y - hitOffsetY)
                    else
                        BallHitbox.Position = UDim2.new(0, newPanelTopLeft.X - math.floor((HITBOX_SIZE-48)/2), 0, newPanelTopLeft.Y - math.floor((HITBOX_SIZE-48)/2))
                    end
                end)
            end

            BallHitbox.InputBegan:Connect(onBallInputBegan)
            CenterPanel.InputBegan:Connect(function(input)
                if IsBall then
                    onBallInputBegan(input)
                end
            end)

            UserInputService.InputChanged:Connect(onInputChanged)
        end
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Delete and Alive then
            Alive = false
            pcall(function() ScreenGui:Destroy() end)
        end
    end)

    local ERROR_POPUP_WIDTH = 320
    local ERROR_POPUP_HEIGHT = 64
    local ERROR_POPUP_MARGIN = 8
    local ERROR_DISPLAY_TIME = 5
    local ERROR_FADE_TIME = 0.5

    local activeErrorPopups = {}

    local function clampString(str, maxLen)
        if not str then return "" end
        if #str <= maxLen then return str end
        return string.sub(str, 1, maxLen - 3) .. "..."
    end

    local function repositionErrorPopups()
        for idx, popup in ipairs(activeErrorPopups) do
            if popup and popup.Parent then
                local targetY = - (ERROR_POPUP_MARGIN + idx * (ERROR_POPUP_HEIGHT + ERROR_POPUP_MARGIN))
                pcall(function()
                    local tween = TweenService:Create(popup, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, ERROR_POPUP_MARGIN, 1, targetY)
                    })
                    tween:Play()
                end)
            end
        end
    end

    local function showErrorPopup(name, message)
        if not ScreenGui or not ScreenGui.Parent then return end
        local idx = #activeErrorPopups + 1
        local startY = - (ERROR_POPUP_MARGIN + (idx-1) * (ERROR_POPUP_HEIGHT + ERROR_POPUP_MARGIN)) + 12
        local targetY = - (ERROR_POPUP_MARGIN + idx * (ERROR_POPUP_HEIGHT + ERROR_POPUP_MARGIN))

        local popup = Instance.new("Frame", ScreenGui)
        popup.Size = UDim2.new(0, ERROR_POPUP_WIDTH, 0, ERROR_POPUP_HEIGHT)
        popup.Position = UDim2.new(0, ERROR_POPUP_MARGIN, 1, startY)
        popup.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
        popup.BackgroundTransparency = 1
        popup.BorderSizePixel = 0
        popup.ZIndex = 500
        popup.ClipsDescendants = true
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0,8)

        local pbBgZ = popup.ZIndex + 1
        local textZ = popup.ZIndex + 3

        local title = Instance.new("TextLabel", popup)
        title.Size = UDim2.new(1, -16, 0, 20)
        title.Position = UDim2.new(0, 8, 0, 6)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextColor3 = Color3.fromRGB(255,0,0)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = tostring(name or "Error")
        title.TextTransparency = 0
        title.ZIndex = textZ

        local msg = Instance.new("TextLabel", popup)
        msg.Size = UDim2.new(1, -16, 0, 34)
        msg.Position = UDim2.new(0, 8, 0, 28)
        msg.BackgroundTransparency = 1
        msg.Font = Enum.Font.Gotham
        msg.TextSize = 12
        msg.TextColor3 = Color3.fromRGB(255,0,0)
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.TextYAlignment = Enum.TextYAlignment.Top
        msg.TextWrapped = true
        msg.Text = clampString(tostring(message or "Unknown error"), 240)
        msg.TextTransparency = 0
        msg.ZIndex = textZ

        local pbBg = Instance.new("Frame", popup)
        pbBg.Size = UDim2.new(1, -16, 0, 6)
        pbBg.Position = UDim2.new(0, 8, 1, -14)
        pbBg.BackgroundColor3 = Color3.fromRGB(50,50,52)
        pbBg.BorderSizePixel = 0
        pbBg.ZIndex = pbBgZ
        Instance.new("UICorner", pbBg).CornerRadius = UDim.new(0, 6)

        local pbFill = Instance.new("Frame", pbBg)
        pbFill.Size = UDim2.new(0, 0, 1, 0)
        pbFill.Position = UDim2.new(0, 0, 0, 0)
        pbFill.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
        pbFill.BorderSizePixel = 0
        pbFill.ZIndex = pbBgZ + 1
        Instance.new("UICorner", pbFill).CornerRadius = UDim.new(0, 6)

        table.insert(activeErrorPopups, popup)
        repositionErrorPopups()

        pcall(function()
            local showTween = TweenService:Create(popup, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0,
                Position = UDim2.new(0, ERROR_POPUP_MARGIN, 1, targetY)
            })
            showTween:Play()
        end)

        pcall(function()
            local targetSize = UDim2.new(1, 0, 1, 0)
            local progTween = TweenService:Create(pbFill, TweenInfo.new(ERROR_DISPLAY_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
                Size = targetSize
            })
            progTween:Play()
            progTween.Completed:Wait()
        end)

        pcall(function()
            local fadeTween = TweenService:Create(popup, TweenInfo.new(ERROR_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundTransparency = 1
            })
            local t1 = TweenService:Create(title, TweenInfo.new(ERROR_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
            local t2 = TweenService:Create(msg, TweenInfo.new(ERROR_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
            local t3 = TweenService:Create(pbBg, TweenInfo.new(ERROR_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            fadeTween:Play(); t1:Play(); t2:Play(); t3:Play()
            fadeTween.Completed:Wait()
        end)

        for i, v in ipairs(activeErrorPopups) do
            if v == popup then
                table.remove(activeErrorPopups, i)
                break
            end
        end
        pcall(function() popup:Destroy() end)
        repositionErrorPopups()
    end

    local function clampCanvasPosition(sf)
        if not sf then return end
        sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            local ok, pos = pcall(function() return sf.CanvasPosition end)
            if not ok or not pos then return end
            local newX = 0
            local canvasY = 0
            local visibleH = 0
            pcall(function() canvasY = (sf.CanvasSize and sf.CanvasSize.Y.Offset) or 0 end)
            pcall(function() visibleH = (sf.AbsoluteSize and sf.AbsoluteSize.Y) or 0 end)
            local maxY = math.max(0, canvasY - visibleH)
            local newY = math.clamp(pos.Y, 0, maxY)
            if pos.X ~= newX or pos.Y ~= newY then
                pcall(function() sf.CanvasPosition = Vector2.new(newX, newY) end)
            end
        end)
    end

    clampCanvasPosition(LeftList)
    clampCanvasPosition(RightList)

    local AnyKeyBind = nil
    local AnyKeyConn = nil
    local BindingPrompt = nil

    local function togglePanelAnimated()
        if isAnimating then return end
        isAnimating = true

        if IsBall then
            restoreFromBall()
            task.wait(0.28)
        end

        if PanelVisible then
            PanelVisible = false
            local ok, curPos = pcall(function() return CenterPanel.AbsolutePosition end)
            if ok and curPos then
                savedState.PanelAbsPosition = Vector2.new(curPos.X, curPos.Y)
            end
            local offY = - (CenterPanel.AbsoluteSize.Y + 80)
            pcall(function() StatusFrame.Visible = false end)
            for _, v in ipairs(CenterPanel:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextButton") then
                    pcall(function() TweenService:Create(v, TweenInfo.new(0.18), {TextTransparency = 1}):Play() end)
                end
            end
            pcall(function() TweenService:Create(PingLabel, TweenInfo.new(0.18), {TextTransparency = 1}):Play() end)
            pcall(function() TweenService:Create(FpsLabel, TweenInfo.new(0.18), {TextTransparency = 1}):Play() end)

            pcall(function() CenterPanel.ClipsDescendants = true end)

            pcall(function()
                local t = TweenService:Create(CenterPanel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                    Position = UDim2.new(0, savedState.PanelAbsPosition.X, 0, offY),
                })
                t:Play()
                t.Completed:Connect(function()
                    CenterPanel.Visible = false
                    CenterPanel.Active = false
                    pcall(function() CenterPanel.ClipsDescendants = _origCenterClips end)
                    pcall(function() StatusFrame.Visible = false end)
                    isAnimating = false
                end)
            end)
        else
            PanelVisible = true
            local targetPos = savedState.PanelAbsPosition or Vector2.new( (Camera.ViewportSize.X - PANEL_WIDTH)/2, (Camera.ViewportSize.Y/2 + CENTER_Y_OFFSET) )
            CenterPanel.Visible = true
            CenterPanel.Active = true
            pcall(function() StatusFrame.Visible = STATUS_ENABLED end)
            for _, v in ipairs(CenterPanel:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextButton") then
                    pcall(function() v.TextTransparency = 1 end)
                end
            end
            pcall(function() PingLabel.TextTransparency = 1 end)
            pcall(function() FpsLabel.TextTransparency = 1 end)

            pcall(function() CenterPanel.ClipsDescendants = true end)

            pcall(function()
                local t = TweenService:Create(CenterPanel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                    Position = UDim2.new(0, targetPos.X, 0, targetPos.Y),
                })
                t:Play()
                t.Completed:Connect(function()
                    for _, v in ipairs(CenterPanel:GetDescendants()) do
                        if v:IsA("TextLabel") or v:IsA("TextButton") then
                            pcall(function() TweenService:Create(v, TweenInfo.new(0.22), {TextTransparency = 0}):Play() end)
                        end
                    end
                    pcall(function() TweenService:Create(PingLabel, TweenInfo.new(0.22), {TextTransparency = 0}):Play() end)
                    pcall(function() TweenService:Create(FpsLabel, TweenInfo.new(0.22), {TextTransparency = 0}):Play() end)
                    pcall(function() CenterPanel.ClipsDescendants = _origCenterClips end)
                    isAnimating = false
                end)
            end)
        end
    end

    local function enableAnyKeyListener(enable)
        if AnyKeyConn then
            pcall(function() AnyKeyConn:Disconnect() end)
            AnyKeyConn = nil
        end
        if enable and AnyKeyBind then
            AnyKeyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == AnyKeyBind then
                        togglePanelAnimated()
                    end
                end
            end)
        end
    end

    local function updateAnyKeyItemDesc()
        for _, cat in ipairs(categories or {}) do
            if cat.name == "功能设置" then
                for _, it in ipairs(cat.items) do
                    if it.title == "任意键绑定 (PC)" then
                        if AnyKeyBind then
                            it.desc = "绑定: " .. tostring(AnyKeyBind.Name)
                        else
                            it.desc = "未绑定"
                        end
                        break
                    end
                end
                break
            end
        end
        if RightTitle and RightTitle.Text == "功能设置" then
            for _, cat in ipairs(categories) do
                if cat.name == "功能设置" then
                    renderRight(cat.items or {})
                    break
                end
            end
        end
    end

    local function showKeyBindPrompt()
        if not IS_PC then
            showErrorPopup("绑定", "此功能仅在 PC 可用")
            return
        end
        if BindingPrompt and BindingPrompt.Parent then
            pcall(function() BindingPrompt:Destroy() end)
            BindingPrompt = nil
        end
        BindingPrompt = Instance.new("Frame", ScreenGui)
        BindingPrompt.Size = UDim2.new(0, 360, 0, 120)
        BindingPrompt.Position = UDim2.new(0.5, -180, 0.5, -60)
        BindingPrompt.BackgroundColor3 = Color3.fromRGB(20,20,22)
        BindingPrompt.BackgroundTransparency = 0.02
        BindingPrompt.BorderSizePixel = 0
        BindingPrompt.ZIndex = 1000
        Instance.new("UICorner", BindingPrompt).CornerRadius = UDim.new(0, 8)

        local title = Instance.new("TextLabel", BindingPrompt)
        title.Size = UDim2.new(1, -24, 0, 28)
        title.Position = UDim2.new(0, 12, 0, 12)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextColor3 = Color3.fromRGB(200,200,200)
        title.Text = "按下要绑定的任意键（Esc 取消）"
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.ZIndex = BindingPrompt.ZIndex + 1

        local hint = Instance.new("TextLabel", BindingPrompt)
        hint.Size = UDim2.new(1, -24, 0, 48)
        hint.Position = UDim2.new(0, 12, 0, 44)
        hint.BackgroundTransparency = 1
        hint.Font = Enum.Font.Gotham
        hint.TextSize = 14
        hint.TextColor3 = Color3.fromRGB(160,160,160)
        hint.Text = "按下后将保存该键，之后按该键即可隐藏/显示悬浮窗。"
        hint.TextWrapped = true
        hint.TextXAlignment = Enum.TextXAlignment.Center
        hint.ZIndex = BindingPrompt.ZIndex + 1

        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local kc = input.KeyCode
                if kc == Enum.KeyCode.Escape then
                    if conn then pcall(function() conn:Disconnect() end) end
                    pcall(function() BindingPrompt:Destroy() end)
                    BindingPrompt = nil
                    showErrorPopup("绑定", "已取消")
                    return
                end
                AnyKeyBind = kc
                if conn then pcall(function() conn:Disconnect() end) end
                pcall(function() BindingPrompt:Destroy() end)
                BindingPrompt = nil
                enableAnyKeyListener(true)
                showErrorPopup("绑定", "已绑定按键: " .. tostring(kc.Name))
                updateAnyKeyItemDesc()
            end
        end)
    end

    local function runPurchasesOnce()
        local ok, customize = pcall(function()
            local events = game:GetService("ReplicatedStorage"):WaitForChild("Events", 1)
            if not events then return nil end
            local customizeFolder = events:WaitForChild("Customize", 1)
            if not customizeFolder then return nil end
            return customizeFolder:WaitForChild("PurchaseEvent", 1)
        end)
        local purchaseEvent = nil
        if ok then purchaseEvent = customize end
        if not purchaseEvent then
            local success, evt = pcall(function()
                local events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
                if not events then return nil end
                local customizeFolder = events:FindFirstChild("Customize")
                if not customizeFolder then return nil end
                return customizeFolder:FindFirstChild("PurchaseEvent")
            end)
            if success then purchaseEvent = evt end
        end

        if purchaseEvent and purchaseEvent.FireServer and type(purchaseEvent.FireServer) == "function" then
            pcall(function() purchaseEvent:FireServer("Iron Stake") end)
            spawn(function()
                task.wait(1)
                pcall(function() showErrorPopup("自动购买", "Iron Stake 购买成功") end)
            end)
            pcall(function() purchaseEvent:FireServer("Voivode") end)
            pcall(function() purchaseEvent:FireServer("Baguette") end)
        else
            pcall(function() showErrorPopup("获取失败", "未找到 PurchaseEvent") end)
        end
    end

    -- UI 控件创建函数（保留原实现）
    local function createToggleControl(parent, item)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1, 0, 0, 64)
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.ZIndex = parent.ZIndex + 1

        local bg = Instance.new("Frame", container)
        bg.Size = UDim2.new(1, 0, 0, 64)
        bg.Position = UDim2.new(0, 0, 0, 0)
        bg.BackgroundColor3 = Color3.fromRGB(250,250,250)
        bg.BackgroundTransparency = 0.02
        bg.BorderSizePixel = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
        bg.ZIndex = container.ZIndex

        local label = Instance.new("TextLabel", bg)
        label.Size = UDim2.new(0.7, -12, 0, 22)
        label.Position = UDim2.new(0, 10, 0, 8)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 14
        label.Text = item.title or "Toggle"
        label.TextColor3 = Color3.fromRGB(30,30,30)
        label.ZIndex = bg.ZIndex + 2
        label.TextXAlignment = Enum.TextXAlignment.Left

        local desc = Instance.new("TextLabel", bg)
        desc.Size = UDim2.new(0.7, -12, 0, 14)
        desc.Position = UDim2.new(0, 10, 0, 30)
        desc.BackgroundTransparency = 1
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 12
        desc.Text = item.desc or ""
        desc.TextColor3 = Color3.fromRGB(100,100,100)
        desc.ZIndex = bg.ZIndex + 2
        desc.TextXAlignment = Enum.TextXAlignment.Left

        local sw = Instance.new("TextButton", bg)
        sw.Name = "Switch"
        sw.Size = UDim2.new(0, 52, 0, 30)
        sw.Position = UDim2.new(1, -72, 0.5, -15)
        sw.BackgroundColor3 = Color3.fromRGB(70,70,74)
        sw.BorderSizePixel = 0
        sw.ZIndex = bg.ZIndex + 3
        sw.AutoButtonColor = true
        sw.Active = true
        sw.Text = ""
        Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 15)

        local knob = Instance.new("Frame", sw)
        knob.Name = "Knob"
        knob.Size = UDim2.new(0,26,0,26)
        knob.Position = UDim2.new(0, 2, 0.5, -13)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 13)
        knob.ZIndex = sw.ZIndex + 1

        if item._state == nil then
            item._state = (item.defaultOn == true) or false
        end
        local state = item._state
        local animing = false
        local function setVisual(on, instant)
            animing = true
            item._state = on
            local targetBg = on and Color3.fromRGB(0,122,204) or Color3.fromRGB(70,70,74)
            local targetKnob = on and UDim2.new(1, -28, 0.5, -13) or UDim2.new(0, 2, 0.5, -13)
            if instant then
                sw.BackgroundColor3 = targetBg
                knob.Position = targetKnob
                animing = false
                return
            end
            pcall(function() TweenService:Create(sw, TweenInfo.new(0.18), {BackgroundColor3 = targetBg}):Play() end)
            pcall(function() TweenService:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Back), {Position = targetKnob}):Play() end)
            delay(0.22, function() animing = false end)
        end

        local function toggleHandler()
            if animing then return end
            state = not state
            setVisual(state, false)
            item._state = state
            if type(item.onToggle) == "function" then
                spawn(function() pcall(function() item.onToggle(state) end) end)
            end
        end
        sw.MouseButton1Click:Connect(toggleHandler)
        if sw.Activated then sw.Activated:Connect(toggleHandler) end

        setVisual(state, true)
        return container
    end

    local function createSliderControl(parent, item)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1,0,0,96)
        container.BackgroundTransparency = 1
        container.ZIndex = parent.ZIndex + 1

        local bg = Instance.new("Frame", container)
        bg.Size = UDim2.new(1,0,0,74)
        bg.Position = UDim2.new(0,0,0,10)
        bg.BackgroundColor3 = Color3.fromRGB(250,250,250)
        bg.BackgroundTransparency = 0.02
        bg.BorderSizePixel = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0,12)

        local label = Instance.new("TextLabel", bg)
        label.Name = "Label"
        label.Size = UDim2.new(0.72, -12, 0, 20)
        label.Position = UDim2.new(0,10,0,8)
        label.BackgroundTransparency = 1
        label.Text = item.title or "Slider"
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(30,30,30)
        label.ZIndex = bg.ZIndex + 1
        label.TextXAlignment = Enum.TextXAlignment.Left

        local desc = Instance.new("TextLabel", bg)
        desc.Name = "Desc"
        desc.Size = UDim2.new(0.72, -12, 0, 14)
        desc.Position = UDim2.new(0,10,0,30)
        desc.BackgroundTransparency = 1
        desc.Text = item.desc or ""
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 11
        desc.TextColor3 = Color3.fromRGB(100,100,100)
        desc.ZIndex = bg.ZIndex + 1
        desc.TextXAlignment = Enum.TextXAlignment.Left

        local slider = Instance.new("Frame", bg)
        slider.Name = "Slider"
        slider.Size = UDim2.new(0.9, 0, 0, 18)
        slider.Position = UDim2.new(0.05, 0, 1, -26)
        slider.BackgroundColor3 = Color3.fromRGB(44,44,48)
        slider.BorderSizePixel = 0
        slider.ZIndex = bg.ZIndex + 1
        Instance.new("UICorner", slider).CornerRadius = UDim.new(0,8)

        local fill = Instance.new("Frame", slider)
        fill.Name = "Fill"
        fill.Size = UDim2.new(0.5,0,1,0)
        fill.Position = UDim2.new(0,0,0,0)
        fill.BackgroundColor3 = Color3.fromRGB(0,122,204)
        fill.BorderSizePixel = 0
        fill.ZIndex = slider.ZIndex + 1
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0,8)

        local knob = Instance.new("Frame", slider)
        knob.Name = "Knob"
        knob.Size = UDim2.new(0,16,0,16)
        knob.Position = UDim2.new(0.5, -8, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0
        knob.Active = true
        knob.ZIndex = slider.ZIndex + 2
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1,8)

        local valueLabel = Instance.new("TextLabel", bg)
        valueLabel.Name = "Value"
        valueLabel.Size = UDim2.new(0, 80, 0, 18)
        valueLabel.Position = UDim2.new(1, -100, 0, 28)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 12
        valueLabel.TextColor3 = Color3.fromRGB(30,30,30)
        valueLabel.ZIndex = bg.ZIndex + 1
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right

        local minVal = tonumber(item.min) or 0
        local maxVal = tonumber(item.max) or 100
        local cur = tonumber(item._value) or tonumber(item.default) or math.floor((minVal + maxVal)/2)
        item._value = cur

        local function setPositionFromValue(v, instant)
            local pct = (v - minVal) / math.max(1, (maxVal - minVal))
            pct = math.clamp(pct, 0, 1)
            if instant then
                fill.Size = UDim2.new(pct, 0, 1, 0)
                knob.Position = UDim2.new(pct, -8, 0.5, -8)
            else
                pcall(function() TweenService:Create(fill, TweenInfo.new(0.12), {Size = UDim2.new(pct,0,1,0)}):Play() end)
                pcall(function() TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Position = UDim2.new(pct, -8, 0.5, -8)}):Play() end)
            end
            valueLabel.Text = tostring(math.floor(v))
        end

        setPositionFromValue(cur, true)

        local dragging = false
        local dragConn, endConn

        local function beginDrag(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            dragging = true
            dragConn = UserInputService.InputChanged:Connect(function(inp)
                if not dragging then return end
                if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                    local okPos, pos = pcall(function() return inp.Position end)
                    local okAbs, absPos = pcall(function() return slider.AbsolutePosition end)
                    local okSize, absSize = pcall(function() return slider.AbsoluteSize end)
                    if not okPos or not okAbs or not okSize or not pos or not absPos or not absSize then return end
                    local relX = math.clamp((pos.X - absPos.X) / math.max(1, absSize.X), 0, 1)
                    local newVal = minVal + relX * (maxVal - minVal)
                    cur = math.floor(newVal + 0.5)
                    setPositionFromValue(cur, true)
                end
            end)
            endConn = UserInputService.InputEnded:Connect(function(inp)
                if inp == input then
                    dragging = false
                    if dragConn and dragConn.Connected then dragConn:Disconnect() end
                    if endConn and endConn.Connected then endConn:Disconnect() end
                    item._value = cur
                    if type(item.onChange) == "function" then
                        spawn(function() pcall(function() item.onChange(cur) end) end)
                    end
                end
            end)
        end

        knob.InputBegan:Connect(beginDrag)
        slider.InputBegan:Connect(beginDrag)

        return container
    end

    local function safeExecuteCodeString(code, title)
        if not code then return false, "no code" end
        local ok, fnOrErr = pcall(function() local f = loadstring or load; return f(code) end)
        if not ok then return false, fnOrErr end
        if type(fnOrErr) ~= "function" then return false, "load didn't return function" end
        local ok2, res = pcall(fnOrErr)
        return ok2, res
    end

    local function runRemoteByUrlOrCode(item)
        if not item then return end
        spawn(function()
            if item.code and type(item.code) == "string" and #item.code > 0 then
                local ok, err = safeExecuteCodeString(item.code, item.title)
                if not ok then
                    pcall(function() showErrorPopup(item.title or "Script", tostring(err)) end)
                end
                return
            end
            if item.url and item.url ~= "" then
                local ok, res = pcall(function()
                    local code = game:HttpGet(item.url)
                    local fn = (loadstring and loadstring(code)) or (load and load(code))
                    if fn then fn() else error("load returned nil") end
                end)
                if not ok then
                    pcall(function() showErrorPopup(item.title or "Script", tostring(res)) end)
                end
                return
            end
            pcall(function() showErrorPopup(item.title or "Script", "无可执行代码或 URL") end)
        end)
    end

    local function runUrlAsync(url)
        spawn(function()
            local ok, err = pcall(function()
                local code = game:HttpGet(url)
                local fn = (loadstring and loadstring(code)) or (load and load(code))
                if type(fn) == "function" then
                    fn()
                else
                    error("load returned non-function")
                end
            end)
            if not ok then
                pcall(function() showErrorPopup("运行脚本失败", tostring(err)) end)
            end
        end)
    end

    local categories = {
        { name = "通用功能", items = {
            { title = "desync", type = "toggle", desc = "复活版V2", defaultOn = false, onToggle = function(on)
                local plsraknet = nil
                pcall(function()
                    if rawget and rawget(_G, "Raknet") then
                        plsraknet = rawget(_G, "Raknet")
                    elseif rawget and rawget(_G, "raknet") then
                        plsraknet = rawget(_G, "raknet")
                    else
                        plsraknet = (Raknet or raknet)
                    end
                end)
                if not plsraknet then
                    pcall(function() showErrorPopup("desync", "未找到 Raknet 或 raknet") end)
                    return
                end

                pcall(function()
                    if type(plsraknet.desync) == "function" then
                        pcall(function() plsraknet.desync(on) end)
                    else
                        showErrorPopup("desync", "找到 Raknet，但缺少 desync 方法")
                    end
                end)

                if on then
                    pcall(function() showErrorPopup("desync", "已开启 desync") end)
                    spawn(function()
                        task.wait(3)
                        local lp = Players.LocalPlayer
                        if not lp then return end
                        local ch = lp.Character or lp.CharacterAdded:Wait(2)
                        if not ch then return end
                        local hum = ch:FindFirstChildOfClass("Humanoid")
                        if hum then
                            pcall(function() hum.Health = 0 end)
                        end
                    end)
                else
                    pcall(function() showErrorPopup("desync", "已关闭 desync") end)
                end
            end },

            { title = "重置人物", desc = "测试功能", onClick = function()
                local lp = Players.LocalPlayer
                if not lp then
                    pcall(function() showErrorPopup("重置", "未找到本地玩家") end)
                    return
                end
                local ch = lp.Character or lp.CharacterAdded:Wait()
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function()
                        hum.Health = 0
                    end)
                    pcall(function() showErrorPopup("重置", "成功") end)
                else
                    pcall(function() showErrorPopup("重置", "未找到 Humanoid") end)
                end
            end },
        }},

        { name = "通用", items = {
            { title = "KOP Hub 39.76", url = "https://raw.githubusercontent.com/KOPLHUB/KOP-Hub/refs/heads/main/39.76.lua", desc = "nokey" },
            { title = "vape v4", url = "https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua", desc = "nokeys" },
            { title = "xahub", url = "https://raw.gitcode.com/XiaoYunUwU/XA/raw/main/Loader.lua", desc = "nokeys" },
            { title = "desync", url = "https://raw.githubusercontent.com/kingdos227/-/refs/heads/main/des.lua", desc = "nokeys",
              onClick = function()
                  if not ScreenGui or not ScreenGui.Parent then
                      pcall(function() showErrorPopup("desync", "UI 不可用") end)
                      return
                  end
                  local KEY_STR = "YANEPIDOR"
                  local POP_W, POP_H = 340, 140
                  local targetPos = UDim2.new(0.5, -POP_W/2, 0.35, -POP_H/2)
                  local startPos = UDim2.new(0.5, -POP_W/2, 0.25, -POP_H/2)

                  local popup = Instance.new("Frame", ScreenGui)
                  popup.Size = UDim2.new(0, POP_W, 0, POP_H)
                  popup.Position = startPos
                  popup.BackgroundColor3 = Color3.fromRGB(24,24,26)
                  popup.BackgroundTransparency = 1
                  popup.BorderSizePixel = 0
                  popup.ZIndex = 1000
                  popup.ClipsDescendants = true
                  Instance.new("UICorner", popup).CornerRadius = UDim.new(0,8)

                  local title = Instance.new("TextLabel", popup)
                  title.Size = UDim2.new(1, -20, 0, 28)
                  title.Position = UDim2.new(0, 10, 0, 10)
                  title.BackgroundTransparency = 1
                  title.Font = Enum.Font.GothamBold
                  title.TextSize = 16
                  title.TextColor3 = Color3.fromRGB(230,230,230)
                  title.Text = "复制 key"
                  title.TextXAlignment = Enum.TextXAlignment.Left
                  title.ZIndex = popup.ZIndex + 1

                  local msg = Instance.new("TextLabel", popup)
                  msg.Size = UDim2.new(1, -20, 0, 44)
                  msg.Position = UDim2.new(0, 10, 0, 40)
                  msg.BackgroundTransparency = 1
                  msg.Font = Enum.Font.Gotham
                  msg.TextSize = 14
                  msg.TextColor3 = Color3.fromRGB(190,190,190)
                  msg.Text = "点击下方按钮以复制此 key 到剪贴板：" .. KEY_STR
                  msg.TextWrapped = true
                  msg.TextXAlignment = Enum.TextXAlignment.Left
                  msg.ZIndex = popup.ZIndex + 1

                  local btn = Instance.new("TextButton", popup)
                  btn.Size = UDim2.new(0, 120, 0, 36)
                  btn.Position = UDim2.new(0.5, -60, 1, -46)
                  btn.AnchorPoint = Vector2.new(0.5, 0)
                  btn.BackgroundColor3 = Color3.fromRGB(0,122,204)
                  btn.BorderSizePixel = 0
                  btn.Font = Enum.Font.GothamBold
                  btn.TextSize = 14
                  btn.TextColor3 = Color3.fromRGB(255,255,255)
                  btn.Text = "复制"
                  btn.ZIndex = popup.ZIndex + 2
                  Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

                  local closing = false
                  local function hidePopupWithAnim()
                      if closing then return end
                      closing = true
                      pcall(function()
                          local t1 = TweenService:Create(popup, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                              BackgroundTransparency = 1,
                              Position = UDim2.new(0.5, -POP_W/2, 0.25, -POP_H/2)
                          })
                          t1:Play()
                          t1.Completed:Wait()
                      end)
                      pcall(function() popup:Destroy() end)
                  end

                  pcall(function()
                      local showTween = TweenService:Create(popup, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                          BackgroundTransparency = 0,
                          Position = targetPos
                      })
                      showTween:Play()
                  end)

                  local autoHideConn
                  spawn(function()
                      local total = 12
                      for i = 1, total do
                          task.wait(1)
                          if not (popup and popup.Parent) then break end
                          if closing then break end
                      end
                      if popup and popup.Parent and not closing then
                          hidePopupWithAnim()
                      end
                  end)

                  local clicked = false
                  local function onCopy()
                      if clicked then return end
                      clicked = true
                      local ok = false
                      pcall(function()
                          if setclipboard then
                              setclipboard(KEY_STR)
                              ok = true
                          elseif syn and syn.set_clipboard then
                              syn.set_clipboard(KEY_STR)
                              ok = true
                          elseif set_clipboard then
                              set_clipboard(KEY_STR)
                              ok = true
                          end
                      end)
                      if ok then
                          pcall(function() showErrorPopup("复制", "已复制 key: " .. KEY_STR) end)
                      else
                          pcall(function() showErrorPopup("复制", "尝试复制到剪贴板（可能不受支持）: " .. KEY_STR) end)
                      end

                      -- 立即移除复制弹窗（不销毁主 UI），并异步运行远程脚本
                      pcall(function() popup:Destroy() end)
                      local targetUrl = "https://raw.githubusercontent.com/kingdos227/-/refs/heads/main/des.lua"
                      runUrlAsync(targetUrl)
                  end

                  if btn.Activated then
                      btn.Activated:Connect(onCopy)
                  end
                  btn.MouseButton1Click:Connect(onCopy)
              end
            },
            { title = "desync v2", url = "https://raw.githubusercontent.com/83808083lsy-cpu/-/refs/heads/main/desync%20V1.3.lua", desc = "nokeys" },
        }},
        { name = "犯罪", items = {
            { title = "JX crim", url = "https://raw.githubusercontent.com/jianlobiano/LOADER/refs/heads/main/JX-Loader", desc = "key" },
            { title = "EQR", url = "https://raw.githubusercontent.com/public-account-7/storage/refs/heads/main/eqrhub%20-%20source%20code.lua", desc = "EQR" },
            { title = "femboyshub", url = "https://raw.githubusercontent.com/LisSploit/FemboysHubBoosr/2784d6c4ede4340ad9af4865828d915ffc26c7bb/Criminality", desc = "nokeys" },
        }},
        { name = "黑火药", items = {
            { title = "清水黑火药", url = "https://pastefy.app/A3Nqz4Np/raw", desc = "nokeys" },
            { title = "Katchi Hub", url = "https://raw.githubusercontent.com/rawscripts.net/raw/Guts-and-Blackpowder-Katchi-Hub-131755", desc = "key" },
            { title = "清风脚本", code = [===[
local r,X do local M=math.floor local A=math.random local B=table.remove local V=``local j=V.char local h=0 local e=2 local I={}local x={}local v=0 local t={}for M=1,256,1 do(t)[M]=M end repeat local M=A(1,#t)local X=B(t,M);(x)[X]=j(X-1)until#t==0 local H={}local function q()if#H==0 then h=(h*17+25306909122149)%35184372088832 repeat e=(e*125)%257 until e~=1 local X=e%32 local r=(M(h/2^(13-(e-X)/32))%4294967296.0)/2^X local A=M((r%1)*4294967296.0)+M(r)local B=A%65536 local V=(A-B)/65536 local j=B%256 local I=(B-j)/256 local x=V%256 local v=(V-x)/256 H={j;I;x;v}end return table.remove(H)end local m={}r=setmetatable({},{__index=m;__metatable={}})local function W(M)local X=``for r=#M,1,-1 do X=X..M:sub(r,r)end return X end function X(M,r)local A=m if(A)[r]then else M=W(M)local X=`35184372088832`do r=r-8113296 end if 344102 then do r=r-1589408 end end for M=1,1,1 do do r=r-1911272 end end if tostring(r)then do r=r-921726 end end if true then do r=r-3690890 end end H={}local B=x h=r%X if X then e=r%`255`+2 end local j=V.len(M)local I=buffer local v=I and(I.create and I.create(j));(A)[r]=V local t=253 for X=`1`,j,1 do if true then t=(((V)[(`etyb`):reverse()](M,X)+q())+t)%`256`end if v then I.writeu8(v,X-1,string.byte((B)[t+1]))else(A)[r]=(A)[r]..(B)[t+`1`]end end if v then(A)[r]=I.tostring(v)end end return r end end;((getgenv()))[(r)[X(`n!\182x7\171\157\153"[`,28957880162588)]]=(r)[X(`_\156\230\031\176s\150`,1018683209675)]local M={((getgenv()))[(r)[X(`\161\242\171V\201\154\249\163m\223`,3431830609231)]];game};((function()return(M)[1](((M)[2])[(r)[X(`\163 \004\200\240d.`,25423654285925)]]((M)[2],(r)[X(`\169\001\a}\250L\b\215Dt?#G\234Y\188\147\165g/\206F\173\141\130}\147>\157\251\255\148\243\027sX\130\253\019\145\231Z\167\167\248\150\252\209RI\185-c\246\184\221\140\245\168\004\202\137r\173\160mB6p\180\178\203#\213\a\206\025\031K\197\190K\212\164\213\144\248\243\158"\181\249\030Z\138\015wt\134\184\177\027\172bpGD\165\136)=EF^x\006\1794\096V`,35163915980121)]))end)())()
]===], desc = "nokey" },
            { title = "获得道具", desc = "获得绝版道具", onClick = function()
                pcall(function() showErrorPopup("获得中", "key通过...") end)
                runPurchasesOnce()
            end },
        }},

        { name = "付费脚本", locked = true, items = {
            { title = "ATLAS", desc = "付费脚本 ATLAS", code = [[
script_key="olkKUUVnHpBWpFYvxbzPCaXbISKngaNg";
getgenv().WB_New_ui = true
loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/5d656cc3277c546c64c1103dd09f78f2.lua"))()
]] },
            { title = "Max Hub", desc = "付费脚本 Max Hub", code = [[
_G.MaxHub = {
    ['Maxhub Notifications'] = true
}
script_key="QuDnnUGUqiBjOFZASOYtZPWhcsCKRieB";
loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/993b07de445441e83e15ce5fde260d5f.lua"))()
]] },
        }},

        { name = "FE", items = {
            { title = "撸管R6", url = "https://pastefy.app/wa3v2Vgm/raw", desc = "nokeys" },
            { title = "撸管R15", url = "https://pastefy.app/YZoglOyJ/raw", desc = "nokeys" },
            { title = "Infinite Yield", url = "https://rawscripts.net/raw/Universal-Script-IY-InfiniteYield-137097", desc = "nokeys" },
            { title = "Nameless Admin", url = "https://rawscripts.net/raw/Universal-Script-Nameless-admin-reworked-75477", desc = "nokeys" },
        }},
        { name = "被遗弃", items = {
            { title = "情云Forsaken", url = "https://raw.githubusercontent.com/ChinaQY/Scripts/Main/Forsaken", desc = "nokeys" },
            { title = "FartHub", url = "https://raw.githubusercontent.com/ivannetta/ShitScripts/main/forsaken.lua", desc = "nokeys" },
        }},
        { name = "最强战场", items = {
            { title = "OPV1", url = "https://raw.githubusercontent.com/yes1nt/yes/main/Trashcan%20Man", desc = "nokeys" },
            { title = "Flow Script Hub", code = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Flow-Script-Hub-140129"))()]], desc = "key" },
            { title = "Forge Hub", code = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Forge-Hub-41461"))()]], desc = "key" },
        }},
        { name = "过检测", items = {
            { title = "过检测 - 替换检测", type = "toggle", desc = "尝试修改/修补可能的检测表", defaultOn = false, onToggle = function(on)
                if on then
                    showErrorPopup("过检测", "开启成功")
                else
                    showErrorPopup("过检测", "关闭成功")
                end
            end },
            { title = "显示聊天框", type = "toggle", desc = "启用/显示聊天 UI", defaultOn = false, onToggle = function(on)
                if on then
                    pcall(function()
                        local StarterGui = game:GetService("StarterGui")
                        local TextChatService = game:GetService("TextChatService")
                        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) end)
                        pcall(function() if TextChatService.ChatWindowConfiguration then TextChatService.ChatWindowConfiguration.Enabled = true end end)
                        showErrorPopup("聊天", "开启成功")
                    end)
                else
                    pcall(function() showErrorPopup("聊天", "关闭：") end)
                end
            end },
            { title = "Hook（保护）", type = "toggle", desc = "尝试 hook 常见敏感调用", defaultOn = false, onToggle = function(on)
                if on then showErrorPopup("Hook", "启用 Hook（占位）") else showErrorPopup("Hook", "开启成功") end
            end },
            { title = "拦截 VirtualUser", type = "toggle", desc = "拦截对 game:GetService('VirtualUser') 的调用（开启后不可轻易关闭）", defaultOn = false, onToggle = function(on)
                if on then showErrorPopup("VirtualUser", "已尝试拦截 VirtualUser（占位）") else showErrorPopup("VirtualUser", "此功能不可关闭") end
            end },
        }},
        { name = "Blind Shot", items = {
            { title = "Blind Shot", url = "https://rawscripts.net/raw/Universal-Script-UPDATED-bobhub-BLIND-SHOT-SCRIPT-OP-FEATURES-84172", desc = "nokey" },
        }},
        { name = "血债", items = {
            { title = "血债", url = "https://raw.githubusercontent.com/ccacca444/scripts1/main/especially", desc = "nokey" },
        }},
        { name = "功能设置", items = {
            { title = "显示延迟与FPS", type = "toggle", desc = "启用或禁用标题栏的 Ping/FPS 显示", defaultOn = true, onToggle = function(on)
                STATUS_ENABLED = (on == true)
                pcall(function() StatusFrame.Visible = STATUS_ENABLED end)
                showErrorPopup("设置", "显示延迟与FPS: " .. tostring(on))
            end },
        }},
        { name = "BloxStrike", items = {
            { title = "BloxStrike", url = "https://rawscripts.net/raw/BETA-BloxStrike-Pc-Mobile-76197", desc = "BloxStrike" },
        }},
        { name = "UNC测试", items = {
            { title = "UNC", url = "https://rawscripts.net/raw/Universal-Script-UNC-TEST-136099", desc = "UNC 测试脚本" },
            { title = "sUNC", url = "https://rawscripts.net/raw/Universal-Script-sUNC-test-132644", desc = "sUNC" },
            { title = "rUNC", url = "https://rawscripts.net/raw/a-literal-baseplate.-Runc-36278", desc = "rUNC" },
            { title = "deb UNC", url = "https://rawscripts.net/raw/Universal-Script-debUNC-like-UNC-and-sUNC-but-better-38351", desc = "deb UNC" },
            { title = "detter UNC", url = "https://rawscripts.net/raw/a-literal-baseplate.-better-unc-18069", desc = "detter UNC" },
        }},
    }

    -- 如果是 PC 则添加任意键绑定项
    if IS_PC then
        for _, cat in ipairs(categories) do
            if cat.name == "功能设置" then
                table.insert(cat.items, {
                    title = "任意键绑定 (PC)",
                    desc = "",
                    onClick = function()
                        showKeyBindPrompt()
                    end
                })
                break
            end
        end
    end

    -- ========== 持久化 Key 逻辑（保存到本地文件以便 24 小时内自动跳过验证） ==========
    local STORAGE_FILE = "linkv2_key_unlock.json"
    local function _isfile(name)
        if type(isfile) == "function" then
            local ok, res = pcall(isfile, name)
            if ok then return res end
        end
        if type(readfile) == "function" then
            local ok, _ = pcall(readfile, name)
            return ok
        end
        if syn and syn.read_file and type(syn.read_file) == "function" then
            local ok, _ = pcall(syn.read_file, name)
            return ok
        end
        return false
    end
    local function _readfile(name)
        if type(readfile) == "function" then
            local ok, res = pcall(readfile, name)
            if ok then return res end
        end
        if syn and syn.read_file then
            local ok, res = pcall(syn.read_file, name)
            if ok then return res end
        end
        return nil
    end
    local function _writefile(name, data)
        if type(writefile) == "function" then
            local ok, _ = pcall(writefile, name, data)
            if ok then return true end
        end
        if syn and syn.write_file then
            local ok, _ = pcall(syn.write_file, name, data)
            if ok then return true end
        end
        if type(write_file) == "function" then
            local ok, _ = pcall(write_file, name, data)
            if ok then return true end
        end
        return false
    end
    local function _delfile(name)
        if type(delfile) == "function" then
            pcall(delfile, name)
            return
        end
        if syn and syn.delete_file then
            pcall(syn.delete_file, name)
            return
        end
    end

    local function saveKeyRecord(key)
        if not key then return false end
        local rec = { key = tostring(key), timestamp = os.time() }
        local ok, encoded = pcall(function() return HttpService:JSONEncode(rec) end)
        if not ok then return false end
        local wrote = _writefile(STORAGE_FILE, encoded)
        if not wrote then
            pcall(function() showErrorPopup("存储", "无法写入本地文件，持久化不可用") end)
            return false
        end
        return true
    end

    local function loadKeyRecord()
        if not _isfile(STORAGE_FILE) then return nil end
        local content = _readfile(STORAGE_FILE)
        if not content then return nil end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok then return nil end
        return decoded
    end

    local function clearKeyRecord()
        _delfile(STORAGE_FILE)
    end

    local function isRecordValid(rec)
        if not rec or not rec.timestamp or not rec.key then return false end
        local age = os.time() - tonumber(rec.timestamp)
        if age <= 24 * 3600 then
            return true
        end
        return false
    end

    local savedKeyRecord = nil
    pcall(function()
        savedKeyRecord = loadKeyRecord()
    end)
    if savedKeyRecord and not isRecordValid(savedKeyRecord) then
        pcall(function() clearKeyRecord() end)
        savedKeyRecord = nil
    end

    -- 若存在有效记录，则自动解锁付费脚本分类
    if savedKeyRecord and isRecordValid(savedKeyRecord) then
        for _, cat in ipairs(categories) do
            if cat.name == "付费脚本" then
                cat.locked = false
            end
        end
        pcall(function() showErrorPopup("验证", "检测到设备在 24 小时内已验证 Key，已自动解锁付费脚本") end)
    end
    -- ========== 持久化 Key 逻辑结束 ==========

    local function clearContainer(container)
        for _, child in ipairs(container:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and child.Name ~= "SelectionIndicator" then
                child:Destroy()
            end
        end
    end

    local FEEDBACK_SHOW_TIME = 0.22
    local FEEDBACK_VISIBLE_TIME = 0.5
    local FEEDBACK_HIDE_TIME = 0.34
    local FEEDBACK_TARGET_TRANSPARENCY = 0.6

    -- Helper: show paid unlock popup for a category and its button
    local function showPaidUnlockPopup(cat, btn)
        if not ScreenGui or not ScreenGui.Parent then
            pcall(function() showErrorPopup("验证", "UI 不可用") end)
            return
        end

        -- 如果已存在有效本地记录，则直接解锁（不弹窗）
        if savedKeyRecord and isRecordValid(savedKeyRecord) then
            pcall(function()
                cat.locked = false
                if btn and btn.Parent then
                    btn.BackgroundColor3 = Color3.fromRGB(255,255,255)
                    btn.TextColor3 = Color3.fromRGB(40,40,40)
                    btn.AutoButtonColor = false
                end
                setSelectedButton(btn)
                renderRight(cat.items or {})
                RightTitle.Text = cat.name or "内容"
                showErrorPopup("验证", "检测到本设备已验证，已自动解锁")
            end)
            return
        end

        local POP_W, POP_H = 520, 180
        local popup = Instance.new("Frame", ScreenGui)
        popup.Size = UDim2.new(0, POP_W, 0, POP_H)
        popup.Position = UDim2.new(0.5, -POP_W/2, 0.4, -POP_H/2)
        popup.BackgroundColor3 = Color3.fromRGB(24,24,26)
        popup.BackgroundTransparency = 1
        popup.BorderSizePixel = 0
        popup.ZIndex = 1200
        popup.ClipsDescendants = true
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0,8)

        local title = Instance.new("TextLabel", popup)
        title.Size = UDim2.new(1, -24, 0, 28)
        title.Position = UDim2.new(0, 12, 0, 10)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextColor3 = Color3.fromRGB(230,230,230)
        title.Text = "付费脚本 - Key 验证"
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = popup.ZIndex + 1

        local hint = Instance.new("TextLabel", popup)
        hint.Size = UDim2.new(1, -24, 0, 44)
        hint.Position = UDim2.new(0, 12, 0, 42)
        hint.BackgroundTransparency = 1
        hint.Font = Enum.Font.Gotham
        hint.TextSize = 14
        hint.TextColor3 = Color3.fromRGB(190,190,190)
        hint.Text = "请输入 Key"
        hint.TextWrapped = true
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.ZIndex = popup.ZIndex + 1

        local inputBox = Instance.new("TextBox", popup)
        inputBox.Size = UDim2.new(1, -40, 0, 34)
        inputBox.Position = UDim2.new(0, 20, 0, 92)
        inputBox.BackgroundColor3 = Color3.fromRGB(40,40,42)
        inputBox.BorderSizePixel = 0
        inputBox.TextColor3 = Color3.fromRGB(230,230,230)
        inputBox.Text = ""
        inputBox.PlaceholderText = "输入 Key"
        inputBox.Font = Enum.Font.Gotham
        inputBox.TextSize = 16
        Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0,6)
        inputBox.ZIndex = popup.ZIndex + 1

        local buttonsFrame = Instance.new("Frame", popup)
        buttonsFrame.Size = UDim2.new(1, -40, 0, 36)
        buttonsFrame.Position = UDim2.new(0, 20, 1, -50)
        buttonsFrame.BackgroundTransparency = 1
        buttonsFrame.ZIndex = popup.ZIndex + 2
        local layout = Instance.new("UIListLayout", buttonsFrame)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 12)

        local okBtn = Instance.new("TextButton", buttonsFrame)
        okBtn.Size = UDim2.new(0.5, -6, 1, 0)
        okBtn.LayoutOrder = 1
        okBtn.BackgroundColor3 = Color3.fromRGB(0,122,204)
        okBtn.BorderSizePixel = 0
        okBtn.Font = Enum.Font.GothamBold
        okBtn.TextSize = 14
        okBtn.TextColor3 = Color3.fromRGB(255,255,255)
        okBtn.Text = "验证并解锁"
        Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0,6)
        okBtn.ZIndex = buttonsFrame.ZIndex + 1

        local cancelBtn = Instance.new("TextButton", buttonsFrame)
        cancelBtn.Size = UDim2.new(0.5, -6, 1, 0)
        cancelBtn.LayoutOrder = 2
        cancelBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
        cancelBtn.BorderSizePixel = 0
        cancelBtn.Font = Enum.Font.GothamBold
        cancelBtn.TextSize = 14
        cancelBtn.TextColor3 = Color3.fromRGB(230,230,230)
        cancelBtn.Text = "取消"
        Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0,6)
        cancelBtn.ZIndex = buttonsFrame.ZIndex + 1

        pcall(function()
            local showTween = TweenService:Create(popup, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0,
                Position = UDim2.new(0.5, -POP_W/2, 0.35, -POP_H/2)
            })
            showTween:Play()
        end)

        local function destroyPopupWithAnim()
            pcall(function()
                local t = TweenService:Create(popup, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, -POP_W/2, 0.25, -POP_H/2)
                })
                t:Play()
                t.Completed:Wait()
            end)
            pcall(function() popup:Destroy() end)
        end

        local KEY_EXPECT = "KeyWULink3664"

        local function onVerify()
            local text = tostring(inputBox.Text or "")
            if text == KEY_EXPECT then
                pcall(function() showErrorPopup("验证", "Key 验证成功正在解锁") end)
                -- 保存已验证记录（记住本设备）
                pcall(function()
                    local ok = saveKeyRecord(text)
                    if not ok then
                        pcall(function() showErrorPopup("验证", "无法持久化记录（写文件失败），但本次会话已解锁") end)
                    else
                        -- 更新内存记录
                        savedKeyRecord = { key = tostring(text), timestamp = os.time() }
                    end
                end)
                -- set unlocked on category data
                cat.locked = false
                -- update button appearance
                pcall(function()
                    if btn and btn.Parent then
                        btn.BackgroundColor3 = Color3.fromRGB(255,255,255)
                        btn.TextColor3 = Color3.fromRGB(40,40,40)
                        btn.AutoButtonColor = false
                    end
                end)
                -- select and render right for this category
                pcall(function()
                    setSelectedButton(btn)
                    renderRight(cat.items or {})
                    RightTitle.Text = cat.name or "内容"
                end)
                destroyPopupWithAnim()
            else
                pcall(function() showErrorPopup("验证", "Key 验证失败系统错误") end)
                task.wait(0.6)
                local lp = Players.LocalPlayer
                pcall(function()
                    if lp and lp.Kick then
                        lp:Kick("Key 验证失败")
                    else
                        game:Shutdown()
                    end
                end)
            end
        end

        if okBtn.Activated then okBtn.Activated:Connect(onVerify) end
        okBtn.MouseButton1Click:Connect(onVerify)
        if cancelBtn.Activated then cancelBtn.Activated:Connect(destroyPopupWithAnim) end
        cancelBtn.MouseButton1Click:Connect(destroyPopupWithAnim)
    end

    local function renderRight(items)
        local prevY = 0
        pcall(function() prevY = RightList.CanvasPosition.Y end)

        clearContainer(RightList)
        RightList.CanvasSize = UDim2.new(0,0,0,0)

        local contentHeight = 0
        for i, item in ipairs(items) do
            if item.type == "toggle" then
                local holder = Instance.new("Frame", RightList)
                holder.Size = UDim2.new(1, -12, 0, 64)
                holder.BackgroundTransparency = 1
                holder.BorderSizePixel = 0
                holder.ZIndex = RightList.ZIndex + 1

                local extraOffset = 24
                local startOffset = -(holder.Size.Y.Offset + extraOffset)
                local content = Instance.new("Frame", holder)
                content.Size = UDim2.new(1, 0, 1, 0)
                content.Position = UDim2.new(0, 0, 0, startOffset)
                content.BackgroundTransparency = 1
                content.BorderSizePixel = 0
                content.ZIndex = holder.ZIndex + 1

                createToggleControl(content, item)

                for _, descChild in ipairs(content:GetDescendants()) do
                    if descChild:IsA("TextLabel") then
                        pcall(function() descChild.TextTransparency = 1 end)
                    end
                end

                spawn(function()
                    local delayTime = math.min(0.12 + (i-1) * 0.03, 0.32)
                    wait(delayTime)
                    local tweenInfo = TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    pcall(function() TweenService:Create(content, tweenInfo, {Position = UDim2.new(0,0,0,0)}):Play() end)
                    local textTweenTime = 0.28
                    for _, descChild in ipairs(content:GetDescendants()) do
                        if descChild:IsA("TextLabel") then
                            pcall(function()
                                TweenService:Create(descChild, TweenInfo.new(textTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                    TextTransparency = 0
                                }):Play()
                            end)
                        end
                    end
                end)

                contentHeight = contentHeight + holder.Size.Y.Offset + (RightListLayout.Padding.Offset or 8)

            elseif item.type == "slider" then
                local holder = Instance.new("Frame", RightList)
                holder.Size = UDim2.new(1, -12, 0, 96)
                holder.BackgroundTransparency = 1
                holder.BorderSizePixel = 0
                holder.ZIndex = RightList.ZIndex + 1

                local extraOffset = 24
                local startOffset = -(holder.Size.Y.Offset + extraOffset)
                local content = Instance.new("Frame", holder)
                content.Size = UDim2.new(1,0,1,0)
                content.Position = UDim2.new(0,0,0,startOffset)
                content.BackgroundTransparency = 1
                content.BorderSizePixel = 0
                content.ZIndex = holder.ZIndex + 1

                createSliderControl(content, item)

                for _, descChild in ipairs(content:GetDescendants()) do
                    if descChild:IsA("TextLabel") then
                        pcall(function() descChild.TextTransparency = 1 end)
                    end
                end

                spawn(function()
                    local delayTime = math.min(0.12 + (i-1) * 0.03, 0.32)
                    wait(delayTime)
                    local tweenInfo = TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    pcall(function() TweenService:Create(content, tweenInfo, {Position = UDim2.new(0,0,0,0)}):Play() end)
                    local textTweenTime = 0.28
                    for _, descChild in ipairs(content:GetDescendants()) do
                        if descChild:IsA("TextLabel") then
                            pcall(function()
                                TweenService:Create(descChild, TweenInfo.new(textTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                    TextTransparency = 0
                                }):Play()
                            end)
                        end
                    end
                end)

                contentHeight = contentHeight + holder.Size.Y.Offset + (RightListLayout.Padding.Offset or 8)

            else
                local holder = Instance.new("Frame", RightList)
                holder.Size = UDim2.new(1, -12, 0, 56)
                holder.BackgroundTransparency = 1
                holder.BorderSizePixel = 0
                holder.ZIndex = RightList.ZIndex + 1

                local extraOffset = 24
                local startOffset = -(holder.Size.Y.Offset + extraOffset)
                local entry = Instance.new("TextButton", holder)
                entry.Size = UDim2.new(1, 0, 1, 0)
                entry.Position = UDim2.new(0, 0, 0, startOffset)
                entry.BackgroundColor3 = Color3.fromRGB(255,255,255)
                entry.BackgroundTransparency = 0.03
                entry.BorderSizePixel = 0
                entry.ZIndex = holder.ZIndex + 1
                entry.AutoButtonColor = true
                entry.Active = true
                entry.Text = ""
                entry.ClipsDescendants = true
                Instance.new("UICorner", entry).CornerRadius = UDim.new(0,6)

                local feedback = Instance.new("Frame", entry)
                feedback.Size = UDim2.new(1, 0, 1, 0)
                feedback.Position = UDim2.new(0, 0, 0, 0)
                feedback.BackgroundColor3 = Color3.fromRGB(0, 102, 204)
                feedback.BackgroundTransparency = 1
                feedback.BorderSizePixel = 0
                feedback.ZIndex = entry.ZIndex + 1
                Instance.new("UICorner", feedback).CornerRadius = UDim.new(0,6)

                local title = Instance.new("TextLabel", entry)
                title.Size = UDim2.new(1, -100, 0, 24)
                title.Position = UDim2.new(0, 8, 0, 6)
                title.BackgroundTransparency = 1
                title.Font = Enum.Font.GothamBold
                title.TextSize = 14
                title.Text = item.title or ("Item "..i)
                title.TextColor3 = Color3.fromRGB(25,25,25)
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.ZIndex = entry.ZIndex + 2
                title.TextTransparency = 1

                local desc = Instance.new("TextLabel", entry)
                desc.Size = UDim2.new(1, -100, 0, 18)
                desc.Position = UDim2.new(0, 8, 0, 28)
                desc.BackgroundTransparency = 1
                desc.Font = Enum.Font.Gotham
                desc.TextSize = 12
                desc.Text = item.desc or ""
                desc.TextColor3 = Color3.fromRGB(90,90,90)
                desc.TextXAlignment = Enum.TextXAlignment.Left
                desc.ZIndex = entry.ZIndex + 2
                desc.TextTransparency = 1

                if entry:GetAttribute("busy") == nil then
                    entry:SetAttribute("busy", false)
                end

                local function activateEntry()
                    if entry:GetAttribute("busy") then return end
                    entry:SetAttribute("busy", true)
                    pcall(function() feedback.BackgroundTransparency = 1 end)
                    local showTween = TweenService:Create(feedback, TweenInfo.new(FEEDBACK_SHOW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundTransparency = FEEDBACK_TARGET_TRANSPARENCY
                    })
                    pcall(function() showTween:Play() end)

                    spawn(function()
                        local ok, res
                        if type(item.onClick) == "function" then
                            ok, res = pcall(function() item.onClick() end)
                            if not ok then pcall(function() showErrorPopup(item.title or "Callback", tostring(res)) end) end
                        elseif item.code and type(item.code) == "string" and #item.code > 0 then
                            runRemoteByUrlOrCode(item)
                        elseif item.url and item.url ~= "" then
                            runRemoteByUrlOrCode(item)
                        else
                            pcall(function() showErrorPopup(item.title or "Info", "无可执行链接") end)
                        end
                    end)

                    spawn(function()
                        task.wait(FEEDBACK_VISIBLE_TIME)
                        local hideTween = TweenService:Create(feedback, TweenInfo.new(FEEDBACK_HIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            BackgroundTransparency = 1
                        })
                        local success, _ = pcall(function() hideTween:Play() end)
                        if success then pcall(function() hideTween.Completed:Wait() end) end
                        pcall(function() entry:SetAttribute("busy", false) end)
                    end)
                end

                if entry.Activated then
                    entry.Activated:Connect(activateEntry)
                end
                entry.MouseButton1Click:Connect(activateEntry)

                spawn(function()
                    local delayTime = math.min(0.12 + (i-1) * 0.03, 0.32)
                    wait(delayTime)
                    local tweenInfo = TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    local moveTween = TweenService:Create(entry, tweenInfo, {
                        Position = UDim2.new(0, 0, 0, 0)
                    })
                    local titleTween = TweenService:Create(title, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        TextTransparency = 0
                    })
                    local descTween = TweenService:Create(desc, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        TextTransparency = 0
                    })
                    moveTween:Play(); titleTween:Play(); descTween:Play()
                end)

                contentHeight = contentHeight + holder.Size.Y.Offset + (RightListLayout.Padding.Offset or 8)
            end
        end

        RightList.CanvasSize = UDim2.new(0, 0, 0, contentHeight)

        delay(0.02, function()
            pcall(function()
                local visibleH = RightList.AbsoluteSize.Y or 0
                local maxY = math.max(0, contentHeight - visibleH)
                local newY = math.clamp(prevY or 0, 0, maxY)
                RightList.CanvasPosition = Vector2.new(0, newY)
            end)
        end)
    end

    local selectedButton = nil

    local function setSelectedButton(btn)
        if not btn then return end

        if not selectionIndicator or not selectionIndicator.Parent then
            selectionIndicator = Instance.new("Frame")
            selectionIndicator.Name = "SelectionIndicator"
            selectionIndicator.BackgroundColor3 = INDICATOR_COLOR
            selectionIndicator.BorderSizePixel = 0
            selectionIndicator.Size = UDim2.new(0, INDICATOR_WIDTH, 0, LEFT_ITEM_HEIGHT)
            selectionIndicator.Position = UDim2.new(0, INDICATOR_MARGIN_LEFT, 0, 0)
            selectionIndicator.ZIndex = LeftList.ZIndex + 1
            selectionIndicator.Parent = LeftList
            local ic = Instance.new("UICorner", selectionIndicator)
            ic.CornerRadius = UDim.new(0, 6)
            selectionIndicator.Visible = false
        end

        if selectedButton and selectedButton.Parent and selectedButton ~= btn then
            pcall(function()
                local bgTween = TweenService:Create(selectedButton, TweenInfo.new(INDICATOR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Color3.fromRGB(255,255,255),
                    BackgroundTransparency = 0.02
                })
                bgTween:Play()
            end)
            pcall(function()
                local textTween = TweenService:Create(selectedButton, TweenInfo.new(INDICATOR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    TextColor3 = Color3.fromRGB(40,40,40)
                })
                textTween:Play()
            end)
        end

        selectedButton = btn
        pcall(function() selectedButton.ZIndex = LeftList.ZIndex + 3 end)

        pcall(function()
            local bgTween = TweenService:Create(selectedButton, TweenInfo.new(INDICATOR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = INDICATOR_COLOR,
                BackgroundTransparency = 0
            })
            bgTween:Play()
        end)
        pcall(function()
            local textTween = TweenService:Create(selectedButton, TweenInfo.new(INDICATOR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = Color3.fromRGB(255,255,255)
            })
            textTween:Play()
        end)

        spawn(function()
            local tries = 0
            while (not selectedButton or selectedButton.AbsolutePosition.Y == 0 or LeftList.AbsolutePosition.Y == 0) and tries < 10 do
                tries = tries + 1
                wait(0.03)
            end
            if not selectionIndicator or not selectionIndicator.Parent then return end
            local ok, err = pcall(function()
                local listAbs = LeftList.AbsolutePosition
                local btnAbs = selectedButton.AbsolutePosition
                local btnSize = selectedButton.AbsoluteSize
                local targetY = btnAbs.Y - listAbs.Y
                local targetSizeY = btnSize.Y
                selectionIndicator.Visible = true
                local tweenInfo = TweenInfo.new(INDICATOR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local posTween = TweenService:Create(selectionIndicator, tweenInfo, {
                    Position = UDim2.new(0, INDICATOR_MARGIN_LEFT, 0, targetY)
                })
                local sizeTween = TweenService:Create(selectionIndicator, tweenInfo, {
                    Size = UDim2.new(0, INDICATOR_WIDTH, 0, targetSizeY)
                })
                posTween:Play(); sizeTween:Play()
            end)
            if not ok then
                pcall(function()
                    selectionIndicator.Position = UDim2.new(0, INDICATOR_MARGIN_LEFT, 0, selectedButton.Position.Y.Offset)
                    selectionIndicator.Size = UDim2.new(0, INDICATOR_WIDTH, 0, selectedButton.Size.Y.Offset)
                    selectionIndicator.Visible = true
                end)
            end
        end)
    end

    local function renderLeft(categories)
        local prevY = 0
        pcall(function() prevY = LeftList.CanvasPosition.Y end)
        local prevSelectedText = selectedButton and selectedButton.Text

        clearContainer(LeftList)
        LeftList.CanvasSize = UDim2.new(0,0,0,0)

        local totalH = 0
        local anyButton = false
        for i, cat in ipairs(categories) do
            local btn = Instance.new("TextButton", LeftList)
            btn.Size = UDim2.new(1, -12, 0, LEFT_ITEM_HEIGHT)
            btn.Position = UDim2.new(0, -200, 0, 0)
            btn.BackgroundColor3 = Color3.fromRGB(255,255,255)
            btn.BackgroundTransparency = 0.02
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 14
            btn.Text = cat.name or ("Category "..i)
            btn.TextColor3 = Color3.fromRGB(40,40,40)
            btn.ZIndex = LeftList.ZIndex + 2
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
            btn.TextXAlignment = Enum.TextXAlignment.Center
            btn.TextYAlignment = Enum.TextYAlignment.Center

            btn.TextTransparency = 1

            -- Unified click handler: 根据 cat.locked 动态决定行为
            btn.MouseButton1Click:Connect(function()
                if cat.locked then
                    -- show unlock popup (uses helper) - pass btn reference
                    showPaidUnlockPopup(cat, btn)
                else
                    if selectedButton == btn then
                        return
                    end
                    setSelectedButton(btn)
                    renderRight(cat.items or {})
                    RightTitle.Text = cat.name or "内容"
                end
            end)

            -- initial visual for locked state
            if cat.locked then
                btn.BackgroundColor3 = Color3.fromRGB(60,60,60)
                btn.TextColor3 = Color3.fromRGB(140,140,140)
                btn.AutoButtonColor = false
            end

            totalH = totalH + btn.Size.Y.Offset + (LeftListLayout.Padding.Offset or LEFT_ITEM_PADDING)
            anyButton = true

            spawn(function()
                local delayTime = math.min(0.12 + (i-1) * 0.03, 0.32)
                wait(delayTime)
                local tweenInfo = TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local moveTween = TweenService:Create(btn, tweenInfo, {
                    Position = UDim2.new(0, 6, 0, 0)
                })
                local textTween = TweenService:Create(btn, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    TextTransparency = 0
                })
                moveTween:Play(); textTween:Play()
            end)
        end

        LeftList.CanvasSize = UDim2.new(0, 0, 0, totalH)

        delay(0.02, function()
            pcall(function()
                local visibleH = LeftList.AbsoluteSize.Y or 0
                local maxY = math.max(0, totalH - visibleH)
                local newY = math.clamp(prevY or 0, 0, maxY)
                LeftList.CanvasPosition = Vector2.new(0, newY)
            end)
        end)

        delay(0.03, function()
            local visibleH = LeftList.AbsoluteSize.Y
            local contentH = LeftList.CanvasSize.Y.Offset
            if contentH <= visibleH then
                LeftList.Active = false
                LeftList.CanvasPosition = Vector2.new(0, 0)
            else
                LeftList.Active = true
            end

            if not anyButton then
                if selectionIndicator and selectionIndicator.Parent then
                    selectionIndicator.Visible = false
                end
                return
            end

            if prevSelectedText then
                for _, v in ipairs(LeftList:GetChildren()) do
                    if v:IsA("TextButton") and v.Text == prevSelectedText then
                        setSelectedButton(v)
                        for _, cat in ipairs(categories) do
                            if cat.name == v.Text then
                                renderRight(cat.items or {})
                                RightTitle.Text = cat.name or "内容"
                                break
                            end
                        end
                        return
                    end
                end
            end

            if selectedButton and selectedButton.Parent then
                setSelectedButton(selectedButton)
                return
            end
            for idx, v in ipairs(LeftList:GetChildren()) do
                if v:IsA("TextButton") then
                    setSelectedButton(v)
                    for _, cat in ipairs(categories) do
                        if cat.name == v.Text then
                            renderRight(cat.items or {})
                            RightTitle.Text = cat.name or "内容"
                            break
                        end
                    end
                    break
                end
            end
        end)
    end

    renderLeft(categories)
    if categories[1] then
        renderRight(categories[1].items or {})
        RightTitle.Text = categories[1].name or "内容"
    end

    return
end)