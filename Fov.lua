task.spawn(function()
    task.wait(10)
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "iOS_CompactUI_Components"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = CoreGui

    local Main = Instance.new("Frame", ScreenGui)
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 300, 0, 48)
    Main.Position = UDim2.new(0.5, -150, 0.2, 0)
    Main.BackgroundColor3 = Color3.fromRGB(245, 245, 247)
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.Active = true

    local MainCorner = Instance.new("UICorner", Main)
    MainCorner.CornerRadius = UDim.new(0, 14)

    local MainStroke = Instance.new("UIStroke", Main)
    MainStroke.Color = Color3.fromRGB(220, 220, 225)
    MainStroke.Thickness = 1

    local TopHeader = Instance.new("Frame", Main)
    TopHeader.Name = "TopHeader"
    TopHeader.Size = UDim2.new(1, 0, 0, 48)
    TopHeader.BackgroundTransparency = 1

    local Title = Instance.new("TextLabel", TopHeader)
    Title.Size = UDim2.new(1, -50, 1, 0)
    Title.Position = UDim2.new(0, 16, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = "Link.cc"
    Title.TextColor3 = Color3.fromRGB(20, 20, 20)
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local MainArrowBtn = Instance.new("TextButton", TopHeader)
    MainArrowBtn.Name = "MainArrowBtn"
    MainArrowBtn.Size = UDim2.new(0, 40, 0, 40)
    MainArrowBtn.Position = UDim2.new(1, -44, 0.5, -20)
    MainArrowBtn.BackgroundTransparency = 1
    MainArrowBtn.Font = Enum.Font.GothamBold
    MainArrowBtn.Text = "∨"
    MainArrowBtn.TextColor3 = Color3.fromRGB(140, 140, 145)
    MainArrowBtn.TextSize = 14
    MainArrowBtn.ZIndex = 5

    local Dragging, DragInput, DragStart, StartPos
    TopHeader.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = input.Position
            StartPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then Dragging = false end
            end)
        end
    end)
    TopHeader.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            DragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == DragInput and Dragging then
            local delta = input.Position - DragStart
            Main.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
        end
    end)

    local ContentHolder = Instance.new("Frame", Main)
    ContentHolder.Name = "ContentHolder"
    ContentHolder.Size = UDim2.new(1, -24, 0, 0)
    ContentHolder.Position = UDim2.new(0, 12, 0, 48)
    ContentHolder.BackgroundTransparency = 1
    ContentHolder.ClipsDescendants = true

    local ContentLayout = Instance.new("UIListLayout", ContentHolder)
    ContentLayout.Padding = UDim.new(0, 8)
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local isMainExpanded = false
    local function updateMainUI()
        local contentHeight = ContentLayout.AbsoluteContentSize.Y
        local targetMainHeight = isMainExpanded and (48 + contentHeight + 12) or 48
        TweenService:Create(MainArrowBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Rotation = isMainExpanded and 180 or 0
        }):Play()
        TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 300, 0, targetMainHeight)
        }):Play()
        TweenService:Create(ContentHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -24, 0, isMainExpanded and contentHeight or 0)
        }):Play()
    end

    MainArrowBtn.MouseButton1Click:Connect(function()
        isMainExpanded = not isMainExpanded
        updateMainUI()
    end)

    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if isMainExpanded then updateMainUI() end
    end)

    local UI = {}

    function UI.CreateCategory(categoryTitle)
        local CatFrame = Instance.new("Frame", ContentHolder)
        CatFrame.Size = UDim2.new(1, 0, 0, 40)
        CatFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        CatFrame.ClipsDescendants = true
        Instance.new("UICorner", CatFrame).CornerRadius = UDim.new(0, 10)
        local CatStroke = Instance.new("UIStroke", CatFrame)
        CatStroke.Color = Color3.fromRGB(230, 230, 235)
        CatStroke.Thickness = 1
        local CatHeader = Instance.new("TextButton", CatFrame)
        CatHeader.Size = UDim2.new(1, 0, 0, 40)
        CatHeader.BackgroundTransparency = 1
        CatHeader.Text = ""
        local CatTitle = Instance.new("TextLabel", CatHeader)
        CatTitle.Size = UDim2.new(1, -40, 1, 0)
        CatTitle.Position = UDim2.new(0, 12, 0, 0)
        CatTitle.BackgroundTransparency = 1
        CatTitle.Font = Enum.Font.GothamBold
        CatTitle.Text = categoryTitle
        CatTitle.TextColor3 = Color3.fromRGB(30, 30, 30)
        CatTitle.TextSize = 13
        CatTitle.TextXAlignment = Enum.TextXAlignment.Left
        local CatArrow = Instance.new("TextLabel", CatHeader)
        CatArrow.Size = UDim2.new(0, 30, 1, 0)
        CatArrow.Position = UDim2.new(1, -34, 0, 0)
        CatArrow.BackgroundTransparency = 1
        CatArrow.Font = Enum.Font.GothamBold
        CatArrow.Text = "∨"
        CatArrow.TextColor3 = Color3.fromRGB(160, 160, 165)
        CatArrow.TextSize = 12
        local ItemsHolder = Instance.new("Frame", CatFrame)
        ItemsHolder.Size = UDim2.new(1, 0, 0, 0)
        ItemsHolder.Position = UDim2.new(0, 0, 0, 40)
        ItemsHolder.BackgroundTransparency = 1
        local ItemsLayout = Instance.new("UIListLayout", ItemsHolder)
        ItemsLayout.Padding = UDim.new(0, 2)
        ItemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        local isCatExpanded = false
        local function updateCatHeight()
            local itemsHeight = ItemsLayout.AbsoluteContentSize.Y
            local targetHeight = isCatExpanded and (40 + itemsHeight + 6) or 40
            TweenService:Create(CatArrow, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Rotation = isCatExpanded and 180 or 0
            }):Play()
            TweenService:Create(CatFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, targetHeight)
            }):Play()
            TweenService:Create(ItemsHolder, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, isCatExpanded and itemsHeight or 0)
            }):Play()
        end
        CatHeader.MouseButton1Click:Connect(function()
            isCatExpanded = not isCatExpanded
            updateCatHeight()
        end)
        ItemsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if isCatExpanded then updateCatHeight() end
        end)
        return ItemsHolder
    end

    function UI.AddToggle(parent, titleText, defaultState, callback)
        local frame = Instance.new("Frame", parent)
        frame.Size = UDim2.new(1, 0, 0, 38)
        frame.BackgroundTransparency = 1
        local label = Instance.new("TextLabel", frame)
        label.Size = UDim2.new(1, -55, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = titleText
        label.TextColor3 = Color3.fromRGB(50, 50, 50)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        local switch = Instance.new("TextButton", frame)
        switch.Size = UDim2.new(0, 38, 0, 22)
        switch.Position = UDim2.new(1, -48, 0.5, -11)
        switch.BackgroundColor3 = defaultState and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(220, 220, 225)
        switch.Text = ""
        Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
        local knob = Instance.new("Frame", switch)
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = defaultState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local knobStroke = Instance.new("UIStroke", knob)
        knobStroke.Color = Color3.fromRGB(0, 0, 0)
        knobStroke.Transparency = 0.9
        local state = defaultState
        switch.MouseButton1Click:Connect(function()
            state = not state
            TweenService:Create(switch, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                BackgroundColor3 = state and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(220, 220, 225)
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            }):Play()
            if callback then callback(state) end
        end)
    end

    function UI.AddSlider(parent, titleText, minVal, maxVal, defaultVal, callback)
        local frame = Instance.new("Frame", parent)
        frame.Size = UDim2.new(1, 0, 0, 46)
        frame.BackgroundTransparency = 1
        local label = Instance.new("TextLabel", frame)
        label.Size = UDim2.new(0.6, 0, 0, 18)
        label.Position = UDim2.new(0, 12, 0, 4)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = titleText
        label.TextColor3 = Color3.fromRGB(50, 50, 50)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        local valLabel = Instance.new("TextLabel", frame)
        valLabel.Size = UDim2.new(0.4, -12, 0, 18)
        valLabel.Position = UDim2.new(0.6, 0, 0, 4)
        valLabel.BackgroundTransparency = 1
        valLabel.Font = Enum.Font.Gotham
        valLabel.Text = tostring(defaultVal)
        valLabel.TextColor3 = Color3.fromRGB(140, 140, 145)
        valLabel.TextSize = 11
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        local sliderBg = Instance.new("Frame", frame)
        sliderBg.Size = UDim2.new(1, -24, 0, 5)
        sliderBg.Position = UDim2.new(0, 12, 0, 28)
        sliderBg.BackgroundColor3 = Color3.fromRGB(220, 220, 225)
        Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
        local sliderFill = Instance.new("Frame", sliderBg)
        local pct = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
        sliderFill.Size = UDim2.new(pct, 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
        Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
        local dragging = false
        local function update(input)
            local pos = input.Position.X - sliderBg.AbsolutePosition.X
            local rel = math.clamp(pos / sliderBg.AbsoluteSize.X, 0, 1)
            local val = math.floor(minVal + rel * (maxVal - minVal))
            sliderFill.Size = UDim2.new(rel, 0, 1, 0)
            valLabel.Text = tostring(val)
            if callback then callback(val) end
        end
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    local Category = UI.CreateCategory("设置")

    local originalHoldDurations = {}
    local promptsDescendantConn = nil
    local promptsRemovingConn = nil
    local promptPropertyConns = {} -- store per-prompt property connections
    local holdEnforceState = false -- 默认关闭
    local enforcedHoldDuration = 0 -- 始终为 0（开启后直接设 0）

    local function setPromptHold(prompt)
        if not prompt or not prompt.Parent or not prompt:IsA("ProximityPrompt") then return end
        -- Only enforce for E-key prompts when holdEnforceState is true
        if holdEnforceState and prompt.KeyboardKeyCode ~= Enum.KeyCode.E then return end
        if originalHoldDurations[prompt] == nil then
            local ok, val = pcall(function() return prompt.HoldDuration end)
            if ok then originalHoldDurations[prompt] = val else originalHoldDurations[prompt] = 0 end
        end
        pcall(function() prompt.HoldDuration = enforcedHoldDuration end)
    end

    local function applyToAllEPrompts()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("ProximityPrompt") then
                -- attach property changed connection for KeyboardKeyCode if not already
                if not promptPropertyConns[inst] then
                    local conn = inst:GetPropertyChangedSignal("KeyboardKeyCode"):Connect(function()
                        if holdEnforceState and inst.KeyboardKeyCode == Enum.KeyCode.E then
                            pcall(function() setPromptHold(inst) end)
                        end
                    end)
                    promptPropertyConns[inst] = conn
                end
                if inst.KeyboardKeyCode == Enum.KeyCode.E then
                    pcall(function() setPromptHold(inst) end)
                end
            end
        end
    end

    local function startPromptMonitor()
        if promptsDescendantConn then return end
        promptsDescendantConn = Workspace.DescendantAdded:Connect(function(desc)
            if desc:IsA("ProximityPrompt") then
                -- attach property-changed connection
                if not promptPropertyConns[desc] then
                    local conn = desc:GetPropertyChangedSignal("KeyboardKeyCode"):Connect(function()
                        if holdEnforceState and desc.KeyboardKeyCode == Enum.KeyCode.E then
                            pcall(function() setPromptHold(desc) end)
                        end
                    end)
                    promptPropertyConns[desc] = conn
                end
                if holdEnforceState and desc.KeyboardKeyCode == Enum.KeyCode.E then
                    pcall(function() setPromptHold(desc) end)
                end
            end
        end)
        promptsRemovingConn = Workspace.DescendantRemoving:Connect(function(desc)
            if desc and promptPropertyConns[desc] then
                pcall(function() promptPropertyConns[desc]:Disconnect() end)
                promptPropertyConns[desc] = nil
            end
        end)
    end

    local function stopPromptMonitor()
        if promptsDescendantConn then
            promptsDescendantConn:Disconnect()
            promptsDescendantConn = nil
        end
        if promptsRemovingConn then
            promptsRemovingConn:Disconnect()
            promptsRemovingConn = nil
        end
        -- disconnect all per-prompt property connections
        for prompt, conn in pairs(promptPropertyConns) do
            pcall(function() conn:Disconnect() end)
            promptPropertyConns[prompt] = nil
        end
    end

    local function restoreAllPrompts()
        for prompt, orig in pairs(originalHoldDurations) do
            if prompt and prompt.Parent then
                pcall(function() prompt.HoldDuration = orig end)
            end
        end
        originalHoldDurations = {}
    end

    -- 简化后的 FOV 强制/防重置逻辑（移除开关与插值）
    local enforcedFOV = 70       -- 将默认值改为 70
    local CAM_FOV = enforcedFOV -- 当前要强制的值（使用滑块控制）
    local CAM_FOV_Conn = nil

    local function disconnect_CAM_FOV_Conn()
        if CAM_FOV_Conn then
            pcall(function() CAM_FOV_Conn:Disconnect() end)
            CAM_FOV_Conn = nil
        end
    end

    local function bind_CAM_FOV_to_camera(cam)
        disconnect_CAM_FOV_Conn()
        if not cam then return end
        if CAM_FOV then
            pcall(function() cam.FieldOfView = CAM_FOV end)
            CAM_FOV_Conn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
                local ok, cur = pcall(function() return cam.FieldOfView end)
                if ok and CAM_FOV and math.abs(cur - CAM_FOV) > 0.01 then
                    pcall(function() cam.FieldOfView = CAM_FOV end)
                end
            end)
        end
    end

    -- 瞬间互动开关（保留）
    UI.AddToggle(Category, "瞬间互动", false, function(state)
        holdEnforceState = state
        if state then
            enforcedHoldDuration = 0
            applyToAllEPrompts() -- apply only to E-key prompts
            startPromptMonitor()
        else
            stopPromptMonitor()
            restoreAllPrompts()
        end
    end)

    -- 仅保留滑块控制 FOV（默认值已设为 70）
    UI.AddSlider(Category, "FOV 值", 40, 180, enforcedFOV, function(value)
        enforcedFOV = value
        CAM_FOV = enforcedFOV
        -- 立即应用到当前摄像机并绑定防重置
        if Workspace.CurrentCamera then
            pcall(function() Workspace.CurrentCamera.FieldOfView = CAM_FOV end)
            bind_CAM_FOV_to_camera(Workspace.CurrentCamera)
        end
    end)

    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        if Workspace.CurrentCamera then
            -- 切换摄像机时重新绑定防重置连接（如果 CAM_FOV 有值）
            bind_CAM_FOV_to_camera(Workspace.CurrentCamera)
        else
            disconnect_CAM_FOV_Conn()
        end
    end)

    -- 启动时把默认值应用到当前摄像机并绑定
    if Workspace.CurrentCamera then
        pcall(function() Workspace.CurrentCamera.FieldOfView = CAM_FOV end)
        bind_CAM_FOV_to_camera(Workspace.CurrentCamera)
    end

    if holdEnforceState then
        applyToAllEPrompts()
        startPromptMonitor()
    end
end)
