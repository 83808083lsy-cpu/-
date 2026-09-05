task.wait(2.6)

loadstring(game:HttpGet("https://raw.githubusercontent.com/83808083lsy-cpu/-/refs/heads/main/Fov.lua"))()

-- Try to increase client FPS cap to a high value if exploit/runtime exposes a function.
-- This is optional and wrapped in safe checks/pcall so it won't error on standard Roblox environment.
pcall(function()
    local function trySetFPSCap(target)
        local g = _G or {}
        local candidates = {"setfpscap", "setfpslimit", "SetFPSCap", "SetFPSLimit", "set_fps_cap", "set_fps_limit"}
        for _, name in ipairs(candidates) do
            local fn = g[name]
            if type(fn) == "function" then
                pcall(fn, target)
                return true
            end
        end
        -- some exploit environments expose functions on 'syn' table
        if type(syn) == "table" then
            local synCandidates = {"set_request_fps", "set_request_fps_limit", "setfps", "set_fps"}
            for _, n in ipairs(synCandidates) do
                if type(syn[n]) == "function" then
                    pcall(syn[n], target)
                    return true
                end
            end
        end
        -- try other global lookup as fallback
        if type(rawget) == "function" then
            for _, name in ipairs({"setfpscap", "setfpslimit"}) do
                local fn = rawget(_G, name)
                if type(fn) == "function" then
                    pcall(fn, target)
                    return true
                end
            end
        end
        return false
    end

    trySetFPSCap(999)
end)

-- Services grouped to reduce local declarations
local svc = {}
svc.UserInputService = game:GetService("UserInputService")
svc.TweenService = game:GetService("TweenService")
svc.RunService = game:GetService("RunService")
svc.Stats = game:GetService("Stats")
svc.Players = game:GetService("Players")
svc.Workspace = game:GetService("Workspace")

-- Context (player/gui/core)
local ctx = {}
ctx.LocalPlayer = svc.Players.LocalPlayer
ctx.PlayerGui = ctx.LocalPlayer:WaitForChild("PlayerGui")
ctx.CoreGui = game:GetService("CoreGui")

-- Environment flags and small state grouped
local state = {}
state.isMobile = svc.UserInputService.TouchEnabled and not svc.UserInputService.MouseEnabled
state.isSliderDragging = false -- 全局用于阻止拖拽窗口时与滑块冲突

-- UI configuration (kept as one table)
local UIConfig = {
    MainSize = state.isMobile and UDim2.new(0, 480, 0, 320) or UDim2.new(0, 640, 0, 420),
    OpenSize = state.isMobile and UDim2.new(0, 520, 0, 350) or UDim2.new(0, 680, 0, 450),
    SidebarSize = state.isMobile and UDim2.new(0, 110, 0, 32) or UDim2.new(0, 120, 0, 36),
    SidebarTextSize = state.isMobile and 13 or 14,
    TitleTextSize = state.isMobile and 15 or 16,
    TabBarWidth = state.isMobile and 120 or 150,
    HeaderHeight = state.isMobile and 42 or 50,
    ControlHeight = state.isMobile and 42 or 46,
    ButtonHeight = state.isMobile and 34 or 38,
    FontSize = state.isMobile and 14 or 14,
    DropdownOptionHeight = 28,
    DropdownMaxVisible = 6, -- 最多显示多少项，其余可滚动
}

-- UI table to hold created UI elements
local ui = {}

-- GUI 父节点，优先 CoreGui
ctx.TargetParent = ctx.PlayerGui
pcall(function()
    if ctx.CoreGui then
        ctx.TargetParent = ctx.CoreGui
    end
end)

-- 全局标识，防止重复运行
if getgenv and getgenv().LinkCCScriptRunning then
    if getgenv().LinkCCScreenGui then
        pcall(function() getgenv().LinkCCScreenGui:Destroy() end)
    end
end
if getgenv then
    getgenv().LinkCCScriptRunning = true
end

-- 清理旧 GUI
pcall(function()
    if ctx.TargetParent:FindFirstChild("LinkCCFrameworkGUI") then
        ctx.TargetParent.LinkCCFrameworkGUI:Destroy()
    end
    if ctx.PlayerGui:FindFirstChild("LinkCCFrameworkGUI") then
        ctx.PlayerGui.LinkCCFrameworkGUI:Destroy()
    end
end)

-- 创建主 ScreenGui
ui.ScreenGui = Instance.new("ScreenGui")
ui.ScreenGui.Name = "LinkCCFrameworkGUI"
ui.ScreenGui.ResetOnSpawn = false
ui.ScreenGui.DisplayOrder = 2147483647
ui.ScreenGui.IgnoreGuiInset = true
ui.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

if getgenv then
    getgenv().LinkCCScreenGui = ui.ScreenGui
end

pcall(function()
    ui.ScreenGui.Parent = ctx.TargetParent
end)
if not ui.ScreenGui.Parent then
    ui.ScreenGui.Parent = ctx.PlayerGui
end

-- 保证 ScreenGui 始终在正确父级和 DisplayOrder
svc.RunService.RenderStepped:Connect(function()
    if ui.ScreenGui then
        if ui.ScreenGui.Parent ~= ctx.TargetParent and ctx.TargetParent then
            pcall(function() ui.ScreenGui.Parent = ctx.TargetParent end)
        end
        if ui.ScreenGui.DisplayOrder ~= 2147483647 then
            ui.ScreenGui.DisplayOrder = 2147483647
        end
    end
end)

-- Loader UI（元素都放入 ui 表）
ui.LoaderFrame = Instance.new("Frame")
ui.LoaderFrame.Name = "LoaderFrame"
ui.LoaderFrame.Size = state.isMobile and UDim2.new(0, 280, 0, 80) or UDim2.new(0, 320, 0, 85)
ui.LoaderFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
ui.LoaderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
ui.LoaderFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
ui.LoaderFrame.BorderSizePixel = 0
ui.LoaderFrame.ZIndex = 100
ui.LoaderFrame.Parent = ui.ScreenGui

ui.LoaderCorner = Instance.new("UICorner")
ui.LoaderCorner.CornerRadius = UDim.new(0, 14)
ui.LoaderCorner.Parent = ui.LoaderFrame

ui.LoaderStroke = Instance.new("UIStroke")
ui.LoaderStroke.Thickness = 1
ui.LoaderStroke.Color = Color3.fromRGB(255, 105, 180)
ui.LoaderStroke.Transparency = 0.4
ui.LoaderStroke.Parent = ui.LoaderFrame

ui.StaticLogo = Instance.new("TextLabel")
ui.StaticLogo.Name = "StaticLogo"
ui.StaticLogo.AutomaticSize = Enum.AutomaticSize.X
ui.StaticLogo.Size = UDim2.new(0, 0, 0, 20)
ui.StaticLogo.Position = UDim2.new(0, 16, 0, 12)
ui.StaticLogo.BackgroundTransparency = 1
ui.StaticLogo.Text = "Link.cc"
ui.StaticLogo.TextColor3 = Color3.fromRGB(255, 105, 180)
ui.StaticLogo.Font = Enum.Font.GothamBold
ui.StaticLogo.TextSize = UIConfig.FontSize + 2
ui.StaticLogo.TextXAlignment = Enum.TextXAlignment.Left
ui.StaticLogo.ZIndex = 101
ui.StaticLogo.Parent = ui.LoaderFrame

ui.LoaderStatus = Instance.new("TextLabel")
ui.LoaderStatus.Size = UDim2.new(1, -32, 0, 16)
ui.LoaderStatus.Position = UDim2.new(0, 16, 0, 34)
ui.LoaderStatus.BackgroundTransparency = 1
ui.LoaderStatus.Text = "初始化组件... 0%"
ui.LoaderStatus.TextColor3 = Color3.fromRGB(160, 160, 165)
ui.LoaderStatus.Font = Enum.Font.Gotham
ui.LoaderStatus.TextSize = UIConfig.FontSize - 2
ui.LoaderStatus.TextXAlignment = Enum.TextXAlignment.Left
ui.LoaderStatus.ZIndex = 101
ui.LoaderStatus.Parent = ui.LoaderFrame

ui.ProgressBarBG = Instance.new("Frame")
ui.ProgressBarBG.Size = UDim2.new(1, -32, 0, 5)
ui.ProgressBarBG.Position = UDim2.new(0, 16, 1, -14)
ui.ProgressBarBG.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
ui.ProgressBarBG.BorderSizePixel = 0
ui.ProgressBarBG.ZIndex = 101
ui.ProgressBarBG.Parent = ui.LoaderFrame

ui.ProgressBarBGCorner = Instance.new("UICorner")
ui.ProgressBarBGCorner.CornerRadius = UDim.new(1, 0)
ui.ProgressBarBGCorner.Parent = ui.ProgressBarBG

ui.ProgressBarFill = Instance.new("Frame")
ui.ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
ui.ProgressBarFill.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
ui.ProgressBarFill.BorderSizePixel = 0
ui.ProgressBarFill.ZIndex = 102
ui.ProgressBarFill.Parent = ui.ProgressBarBG

ui.ProgressBarFillCorner = Instance.new("UICorner")
ui.ProgressBarFillCorner.CornerRadius = UDim.new(1, 0)
ui.ProgressBarFillCorner.Parent = ui.ProgressBarFill

-- 可拖拽函数（使用 state.isSliderDragging）
local function EnableHeaderDragging(headerFrame, targetFrame)
    local dragging = false
    local dragInput, dragStart, startPos

    headerFrame.InputBegan:Connect(function(input)
        if state.isSliderDragging then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    headerFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    svc.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and not state.isSliderDragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- 状态栏（ping/fps）元素也 grouped into ui
ui.StatusBar = Instance.new("Frame")
ui.StatusBar.Name = "StatusBar"
ui.StatusBar.AutomaticSize = Enum.AutomaticSize.X
ui.StatusBar.Size = UDim2.new(0, 0, 0, state.isMobile and 28 or 32)
ui.StatusBar.Position = UDim2.new(0.5, 0, 0, -40)
ui.StatusBar.AnchorPoint = Vector2.new(0.5, 0)
ui.StatusBar.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
ui.StatusBar.BorderSizePixel = 0
ui.StatusBar.Active = true
ui.StatusBar.BackgroundTransparency = 1
ui.StatusBar.ZIndex = 50
ui.StatusBar.Parent = ui.ScreenGui

ui.StatusCorner = Instance.new("UICorner")
ui.StatusCorner.CornerRadius = UDim.new(0, 8)
ui.StatusCorner.Parent = ui.StatusBar

ui.StatusStroke = Instance.new("UIStroke")
ui.StatusStroke.Thickness = 1
ui.StatusStroke.Color = Color3.fromRGB(60, 60, 65)
ui.StatusStroke.Transparency = 1
ui.StatusStroke.Parent = ui.StatusBar

EnableHeaderDragging(ui.StatusBar, ui.StatusBar)

ui.StatusListLayout = Instance.new("UIListLayout")
ui.StatusListLayout.FillDirection = Enum.FillDirection.Horizontal
ui.StatusListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ui.StatusListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ui.StatusListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ui.StatusListLayout.Padding = UDim.new(0, 6)
ui.StatusListLayout.Parent = ui.StatusBar

ui.StatusPadding = Instance.new("UIPadding")
ui.StatusPadding.PaddingLeft = UDim.new(0, 10)
ui.StatusPadding.PaddingRight = UDim.new(0, 10)
ui.StatusPadding.Parent = ui.StatusBar

ui.LogoLabel = Instance.new("TextLabel")
ui.LogoLabel.Name = "1_Logo"
ui.LogoLabel.AutomaticSize = Enum.AutomaticSize.X
ui.LogoLabel.Size = UDim2.new(0, 0, 1, 0)
ui.LogoLabel.BackgroundTransparency = 1
ui.LogoLabel.Text = "Link.cc"
ui.LogoLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
ui.LogoLabel.TextTransparency = 1
ui.LogoLabel.TextXAlignment = Enum.TextXAlignment.Left
ui.LogoLabel.Font = Enum.Font.GothamBold
ui.LogoLabel.TextSize = UIConfig.FontSize
ui.LogoLabel.LayoutOrder = 1
ui.LogoLabel.ZIndex = 51
ui.LogoLabel.Parent = ui.StatusBar

ui.Divider = Instance.new("TextLabel")
ui.Divider.Name = "2_Divider"
ui.Divider.AutomaticSize = Enum.AutomaticSize.X
ui.Divider.Size = UDim2.new(0, 0, 1, 0)
ui.Divider.BackgroundTransparency = 1
ui.Divider.Text = "|"
ui.Divider.TextColor3 = Color3.fromRGB(80, 80, 85)
ui.Divider.TextTransparency = 1
ui.Divider.Font = Enum.Font.Gotham
ui.Divider.TextSize = UIConfig.FontSize - 1
ui.Divider.LayoutOrder = 2
ui.Divider.ZIndex = 51
ui.Divider.Parent = ui.StatusBar

ui.InfoLabel = Instance.new("TextLabel")
ui.InfoLabel.Name = "3_Info"
ui.InfoLabel.AutomaticSize = Enum.AutomaticSize.X
ui.InfoLabel.Size = UDim2.new(0, 0, 1, 0)
ui.InfoLabel.BackgroundTransparency = 1
ui.InfoLabel.RichText = true
ui.InfoLabel.Text = "0ms 0FPS"
ui.InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ui.InfoLabel.TextTransparency = 1
ui.InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
ui.InfoLabel.Font = Enum.Font.GothamMedium
ui.InfoLabel.TextSize = UIConfig.FontSize - 1
ui.InfoLabel.LayoutOrder = 3
ui.InfoLabel.ZIndex = 51
ui.InfoLabel.Parent = ui.StatusBar

-- Utility functions (kept local)
local function Color3ToHex(c)
    if not c then return "FFFFFF" end
    local r = math.clamp(math.floor(c.R * 255 + 0.5), 0, 255)
    local g = math.clamp(math.floor(c.G * 255 + 0.5), 0, 255)
    local b = math.clamp(math.floor(c.B * 255 + 0.5), 0, 255)
    return string.format("%02X%02X%02X", r, g, b)
end

local function GetPingColor(ping)
    if ping <= 99 then return Color3.fromRGB(52, 199, 89)
    elseif ping <= 120 then return Color3.fromRGB(52, 199, 89):Lerp(Color3.fromRGB(255, 204, 0), (ping-99)/21)
    elseif ping <= 130 then return Color3.fromRGB(255, 204, 0):Lerp(Color3.fromRGB(255, 59, 48), (ping-120)/10)
    else return Color3.fromRGB(255, 59, 48) end
end

local function GetFpsColor(fps)
    if fps >= 55 then return Color3.fromRGB(52, 199, 89)
    elseif fps >= 30 then return Color3.fromRGB(255, 204, 0)
    else return Color3.fromRGB(255, 59, 48) end
end

-- FPS/ping update
do
    local frameCount, lastCheck, currentFps = 0, tick(), 60
    svc.RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastCheck >= 0.25 then
            currentFps = math.floor(frameCount / (now - lastCheck))
            frameCount = 0
            lastCheck = now
        end
        local success, pingVal = pcall(function()
            return svc.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        local ping = success and math.floor(tonumber(pingVal) or 0) or 0
        ui.InfoLabel.Text = string.format("<font color=\"#%s\">%dms</font>  <font color=\"#%s\">%dFPS</font>",
            Color3ToHex(GetPingColor(ping)), ping, Color3ToHex(GetFpsColor(currentFps)), currentFps)
    end)
end

-- Sidebar + 主面板（UI 构造）
ui.SideBarToggle = Instance.new("TextButton")
ui.SideBarToggle.Name = "SideBarToggle"
ui.SideBarToggle.Size = UIConfig.SidebarSize
ui.SideBarToggle.Position = UDim2.new(0, 10, 0.5, 0)
ui.SideBarToggle.AnchorPoint = Vector2.new(0, 0.5)
ui.SideBarToggle.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
ui.SideBarToggle.Text = state.isMobile and " Link.cc" or " Link.cc"
ui.SideBarToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
ui.SideBarToggle.Font = Enum.Font.GothamBold
ui.SideBarToggle.TextSize = UIConfig.SidebarTextSize
ui.SideBarToggle.AutoButtonColor = false
ui.SideBarToggle.Active = true
ui.SideBarToggle.Visible = false
ui.SideBarToggle.ZIndex = 50
ui.SideBarToggle.Parent = ui.ScreenGui

ui.SideBarCorner = Instance.new("UICorner")
ui.SideBarCorner.CornerRadius = UDim.new(0, 8)
ui.SideBarCorner.Parent = ui.SideBarToggle

ui.SideBarStroke = Instance.new("UIStroke")
ui.SideBarStroke.Thickness = 1
ui.SideBarStroke.Color = Color3.fromRGB(255, 105, 180)
ui.SideBarStroke.Parent = ui.SideBarToggle

EnableHeaderDragging(ui.SideBarToggle, ui.SideBarToggle)

ui.MainFrame = Instance.new("Frame")
ui.MainFrame.Name = "MainFrame"
ui.MainFrame.Size = UIConfig.MainSize
ui.MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
ui.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
ui.MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
ui.MainFrame.BackgroundTransparency = 1
ui.MainFrame.BorderSizePixel = 0
ui.MainFrame.Active = true
ui.MainFrame.Draggable = false
ui.MainFrame.Visible = false
ui.MainFrame.ZIndex = 10
ui.MainFrame.Parent = ui.ScreenGui

ui.MainUICorner = Instance.new("UICorner")
ui.MainUICorner.CornerRadius = UDim.new(0, 14)
ui.MainUICorner.Parent = ui.MainFrame

ui.MainStroke = Instance.new("UIStroke")
ui.MainStroke.Thickness = 1
ui.MainStroke.Color = Color3.fromRGB(60, 60, 65)
ui.MainStroke.Transparency = 1
ui.MainStroke.Parent = ui.MainFrame

ui.Header = Instance.new("Frame")
ui.Header.Name = "Header"
ui.Header.Size = UDim2.new(1, 0, 0, UIConfig.HeaderHeight)
ui.Header.BackgroundTransparency = 1
ui.Header.Active = true
ui.Header.ZIndex = 11
ui.Header.Parent = ui.MainFrame

ui.Title = Instance.new("TextLabel")
ui.Title.Size = UDim2.new(1, -20, 1, 0)
ui.Title.Position = UDim2.new(0, 15, 0, 0)
ui.Title.BackgroundTransparency = 1
ui.Title.Text = "Link.cc"
ui.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
ui.Title.TextTransparency = 1
ui.Title.TextXAlignment = Enum.TextXAlignment.Left
ui.Title.Font = Enum.Font.GothamBold
ui.Title.TextSize = UIConfig.TitleTextSize
ui.Title.ZIndex = 12
ui.Title.Parent = ui.Header

EnableHeaderDragging(ui.Header, ui.MainFrame)

ui.TabBar = Instance.new("ScrollingFrame")
ui.TabBar.Name = "TabBar"
ui.TabBar.Size = UDim2.new(0, UIConfig.TabBarWidth, 1, -(UIConfig.HeaderHeight + 10))
ui.TabBar.Position = UDim2.new(0, 10, 0, UIConfig.HeaderHeight)
ui.TabBar.BackgroundTransparency = 1
ui.TabBar.ScrollBarThickness = 0
ui.TabBar.ScrollBarImageTransparency = 1
ui.TabBar.ScrollingDirection = Enum.ScrollingDirection.Y
ui.TabBar.HorizontalScrollBarInset = Enum.ScrollBarInset.None
ui.TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
ui.TabBar.ZIndex = 11
ui.TabBar.Parent = ui.MainFrame

ui.TabListLayout = Instance.new("UIListLayout")
ui.TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ui.TabListLayout.Padding = UDim.new(0, 6)
ui.TabListLayout.Parent = ui.TabBar

local tabs = {}
local activeTab = nil

local function UpdateTabBarScrolling()
    local contentHeight = ui.TabListLayout.AbsoluteContentSize.Y
    local visibleHeight = ui.TabBar.AbsoluteSize.Y
    if contentHeight > visibleHeight then
        ui.TabBar.ScrollingEnabled = true
        ui.TabBar.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 10)
    else
        ui.TabBar.ScrollingEnabled = false
        ui.TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    end
end

ui.TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabBarScrolling)
ui.TabBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabBarScrolling)

ui.ContentContainer = Instance.new("Frame")
ui.ContentContainer.Size = UDim2.new(1, -(UIConfig.TabBarWidth + 25), 1, -(UIConfig.HeaderHeight + 10))
ui.ContentContainer.Position = UDim2.new(0, UIConfig.TabBarWidth + 18, 0, UIConfig.HeaderHeight)
ui.ContentContainer.BackgroundTransparency = 1
ui.ContentContainer.ZIndex = 11
ui.ContentContainer.Parent = ui.MainFrame

-- PlayFeedbackAnimation 函数保留（内部使用临时变量，影响少）
local function PlayFeedbackAnimation(pageFrame)
    local items = pageFrame:GetChildren()
    local index = 0
    for _, item in ipairs(items) do
        if item:IsA("Frame") or item:IsA("TextButton") then
            index = index + 1
            local origPos = item:GetAttribute("OrigPos")
            if not origPos then
                origPos = item.Position
                item:SetAttribute("OrigPos", origPos)
            end
            item.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + 12)
            item.BackgroundTransparency = 1
            for _, child in ipairs(item:GetDescendants()) do
                if child:IsA("TextLabel") then
                    child.TextTransparency = 1
                elseif child:IsA("TextButton") then
                    child.TextTransparency = 1
                    child.BackgroundTransparency = (child.Name == "ExpandBtn" or child.Name:find("Option_")) and 1 or child.BackgroundTransparency
                elseif child:IsA("ImageButton") then
                    child.ImageTransparency = 1
                elseif child:IsA("Frame") and child.Name ~= "Hitbox" and child.Name ~= "DropdownList" then
                    child.BackgroundTransparency = 1
                end
            end
            task.delay(index * 0.035, function()
                svc.TweenService:Create(item, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = origPos,
                    BackgroundTransparency = 0
                }):Play()
                for _, child in ipairs(item:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        svc.TweenService:Create(child, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
                    elseif child:IsA("TextButton") then
                        svc.TweenService:Create(child, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
                    elseif child:IsA("ImageButton") then
                        svc.TweenService:Create(child, TweenInfo.new(0.35), {ImageTransparency = 0}):Play()
                    elseif child:IsA("Frame") and child.Name ~= "Hitbox" and child.Name ~= "DropdownList" then
                        svc.TweenService:Create(child, TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
                    end
                end
            end)
        end
    end
end

local function ResetAllScrollPositions()
    ui.TabBar.CanvasPosition = Vector2.new(0, 0)
    for _, tab in ipairs(tabs) do
        if tab.Page and tab.Page:IsA("ScrollingFrame") then
            tab.Page.CanvasPosition = Vector2.new(0, 0)
        end
    end
end

local isUIOpen = false
local function ToggleMainUI()
    isUIOpen = not isUIOpen
    local smallSize = UDim2.new(UIConfig.SidebarSize.X.Scale, UIConfig.SidebarSize.X.Offset - 8, UIConfig.SidebarSize.Y.Scale, UIConfig.SidebarSize.Y.Offset - 3)
    svc.TweenService:Create(ui.SideBarToggle, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = smallSize}):Play()
    task.delay(0.1, function()
        svc.TweenService:Create(ui.SideBarToggle, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UIConfig.SidebarSize}):Play()
    end)
    if isUIOpen then
        ResetAllScrollPositions()
        ui.MainFrame.Visible = true
        svc.TweenService:Create(ui.MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UIConfig.OpenSize,
            BackgroundTransparency = 0
        }):Play()
        svc.TweenService:Create(ui.MainStroke, TweenInfo.new(0.35), {Transparency = 0.5}):Play()
        svc.TweenService:Create(ui.Title, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
        if activeTab then
            PlayFeedbackAnimation(activeTab.Page)
        end
    else
        local tween = svc.TweenService:Create(ui.MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UIConfig.MainSize,
            BackgroundTransparency = 1
        })
        svc.TweenService:Create(ui.MainStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
        svc.TweenService:Create(ui.Title, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
        tween:Play()
        tween.Completed:Connect(function()
            if not isUIOpen then
                ui.MainFrame.Visible = false
                ResetAllScrollPositions()
            end
        end)
    end
end

ui.SideBarToggle.MouseButton1Click:Connect(ToggleMainUI)

svc.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        ToggleMainUI()
    end
end)

-- CreateTab 与 Add* 方法：将返回对象并将少量控件放入表，避免创建过多 locals
local function CreateTab(tabName)
    local tabButton = Instance.new("TextButton")
    tabButton.Size = UDim2.new(1, -6, 0, state.isMobile and 36 or 40)
    tabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(160, 160, 165)
    tabButton.Font = Enum.Font.GothamMedium
    tabButton.TextSize = UIConfig.FontSize
    tabButton.AutoButtonColor = false
    tabButton.ZIndex = 12
    tabButton.Parent = ui.TabBar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = tabButton

    local pageFrame = Instance.new("ScrollingFrame")
    pageFrame.Size = UDim2.new(1, 0, 1, 0)
    pageFrame.BackgroundTransparency = 1
    pageFrame.Visible = false
    pageFrame.ScrollBarThickness = 0
    pageFrame.ScrollBarImageTransparency = 1
    pageFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    pageFrame.HorizontalScrollBarInset = Enum.ScrollBarInset.None
    pageFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    pageFrame.ZIndex = 12
    pageFrame.Parent = ui.ContentContainer

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.Parent = pageFrame

    local function UpdateScrollingState()
        local contentHeight = pageLayout.AbsoluteContentSize.Y
        local visibleHeight = pageFrame.AbsoluteSize.Y
        if contentHeight > visibleHeight then
            pageFrame.ScrollingEnabled = true
            pageFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 10)
        else
            pageFrame.ScrollingEnabled = false
            pageFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        end
    end

    pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateScrollingState)
    pageFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateScrollingState)

    local tabObj = { Button = tabButton, Page = pageFrame }

    local function selectTab()
        for _, t in pairs(tabs) do
            t.Page.Visible = false
            t.Page.CanvasPosition = Vector2.new(0, 0)
            svc.TweenService:Create(t.Button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(35, 35, 40),
                TextColor3 = Color3.fromRGB(160, 160, 165)
            }):Play()
        end
        pageFrame.CanvasPosition = Vector2.new(0, 0)
        pageFrame.Visible = true
        activeTab = tabObj
        UpdateScrollingState()
        svc.TweenService:Create(tabButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(255, 105, 180),
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        PlayFeedbackAnimation(pageFrame)
    end

    tabButton.MouseButton1Click:Connect(selectTab)

    -- AddButton (returns created controls inside table)
    function tabObj:AddButton(text, callback)
        local btnItem = Instance.new("TextButton")
        btnItem.Name = "ClickableItem"
        btnItem.Size = UDim2.new(1, -10, 0, UIConfig.ButtonHeight)
        btnItem.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
        btnItem.Text = ""
        btnItem.AutoButtonColor = false
        btnItem.ZIndex = 13
        btnItem.Parent = pageFrame

        local bfCorner = Instance.new("UICorner")
        bfCorner.CornerRadius = UDim.new(0, 8)
        bfCorner.Parent = btnItem

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -24, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = UIConfig.FontSize
        label.ZIndex = 14
        label.Parent = btnItem

        btnItem.MouseButton1Click:Connect(function()
            svc.TweenService:Create(btnItem, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(48, 48, 55)
            }):Play()
            task.delay(0.12, function()
                svc.TweenService:Create(btnItem, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Color3.fromRGB(32, 32, 36)
                }):Play()
            end)
            if callback then pcall(callback, btnItem, label) end
        end)
        return { btn = btnItem, label = label }
    end

    -- AddToggle
    function tabObj:AddToggle(text, defaultState, callback)
        local stateBool = defaultState or false
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)
        toggleFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
        toggleFrame.ZIndex = 13
        toggleFrame.Parent = pageFrame

        local tfCorner = Instance.new("UICorner")
        tfCorner.CornerRadius = UDim.new(0, 10)
        tfCorner.Parent = toggleFrame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -55, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = UIConfig.FontSize
        label.ZIndex = 14
        label.Parent = toggleFrame

        local trackWidth = state.isMobile and 36 or 40
        local trackHeight = state.isMobile and 18 or 20
        local switchTrack = Instance.new("TextButton")
        switchTrack.Name = "SwitchTrack"
        switchTrack.Size = UDim2.new(0, trackWidth, 0, trackHeight)
        switchTrack.Position = UDim2.new(1, -(trackWidth + 12), 0.5, -trackHeight / 2)
        switchTrack.BackgroundColor3 = stateBool and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(70, 70, 75)
        switchTrack:SetAttribute("State", stateBool)
        switchTrack.Text = ""
        switchTrack.AutoButtonColor = false
        switchTrack.ZIndex = 14
        switchTrack.Parent = toggleFrame

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = switchTrack

        local thumbSize = state.isMobile and 14 or 16
        local switchThumb = Instance.new("Frame")
        switchThumb.Size = UDim2.new(0, thumbSize, 0, thumbSize)
        switchThumb.Position = stateBool and UDim2.new(1, -(thumbSize + 2), 0.5, -thumbSize/2) or UDim2.new(0, 2, 0.5, -thumbSize/2)
        switchThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        switchThumb.ZIndex = 15
        switchThumb.Parent = switchTrack

        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(1, 0)
        thumbCorner.Parent = switchThumb

        switchTrack.MouseButton1Click:Connect(function()
            stateBool = not stateBool
            switchTrack:SetAttribute("State", stateBool)
            local targetTrackColor = stateBool and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(70, 70, 75)
            local targetThumbPos = stateBool and UDim2.new(1, -(thumbSize + 2), 0.5, -thumbSize/2) or UDim2.new(0, 2, 0.5, -thumbSize/2)
            svc.TweenService:Create(switchTrack, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = targetTrackColor}):Play()
            svc.TweenService:Create(switchThumb, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetThumbPos}):Play()
            if callback then pcall(callback, stateBool, switchTrack, switchThumb, toggleFrame, label) end
        end)
        return { track = switchTrack, thumb = switchThumb, frame = toggleFrame, label = label }
    end

    -- AddSlider（支持浮点、0..1 两位小数显示）
    function tabObj:AddSlider(text, min, max, default, callback)
        min = min or 0
        max = max or 100
        default = default or min
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight + 8)
        sliderFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
        sliderFrame.ZIndex = 13
        sliderFrame.Parent = pageFrame

        local sfCorner = Instance.new("UICorner")
        sfCorner.CornerRadius = UDim.new(0, 10)
        sfCorner.Parent = sliderFrame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 0, 20)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.BackgroundTransparency = 1
        label.Text = text .. " : " .. tostring(default)
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = UIConfig.FontSize
        label.ZIndex = 14
        label.Parent = sliderFrame

        local track = Instance.new("Frame")
        track.Name = "Track"
        track.Size = UDim2.new(1, -24, 0, 6)
        track.Position = UDim2.new(0, 12, 1, -14)
        track.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        track.ZIndex = 14
        track.Parent = sliderFrame

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = track

        local range = max - min
        local startRatio = 0
        if range == 0 then
            startRatio = 0
        else
            startRatio = math.clamp((default - min) / range, 0, 1)
        end

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(startRatio, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
        fill.BorderSizePixel = 0
        fill.ZIndex = 15
        fill.Parent = track

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill

        local handle = Instance.new("Frame")
        handle.Name = "SliderHandleVisual"
        handle.Size = UDim2.new(0, 10, 0, 10)
        handle.Position = UDim2.new(startRatio, -5, 0.5, -5)
        handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        handle.ZIndex = 16
        handle.Parent = track

        local handleCorner = Instance.new("UICorner")
        handleCorner.CornerRadius = UDim.new(1, 0)
        handleCorner.Parent = handle

        -- Hitbox covers the visible track area (not child of handle)
        local hitBox = Instance.new("ImageButton")
        hitBox.Name = "Hitbox"
        hitBox.Size = UDim2.new(1, -24, 0, 30)
        hitBox.Position = UDim2.new(0, 12, 1, -20)
        hitBox.BackgroundTransparency = 1
        hitBox.AutoButtonColor = false
        hitBox.ZIndex = 17
        hitBox.Parent = sliderFrame

        local dragging = false

        local function formatValueByRange(raw)
            if math.abs(range) > 1 then
                return math.floor(raw + 0.5)
            else
                return math.floor(raw * 100 + 0.5) / 100
            end
        end

        local function updateInputByPos(absX)
            if not track or not fill or not handle then return end
            local trackPosX = track.AbsolutePosition.X
            local trackSizeX = math.max(1, track.AbsoluteSize.X)
            local ratio = math.clamp((absX - trackPosX) / trackSizeX, 0, 1)
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            handle.Position = UDim2.new(ratio, -5, 0.5, -5)
            local rawValue = min + (range * ratio)
            local value = formatValueByRange(rawValue)
            label.Text = text .. " : " .. tostring(value)
            if callback then
                pcall(callback, value, ratio, fill, handle, sliderFrame)
            end
        end

        hitBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                state.isSliderDragging = true
                local absX = (input.Position and input.Position.X) or svc.UserInputService:GetMouseLocation().X
                updateInputByPos(absX)
            end
        end)

        svc.UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local absX = (input.Position and input.Position.X) or svc.UserInputService:GetMouseLocation().X
                updateInputByPos(absX)
            end
        end)

        svc.UserInputService.InputEnded:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragging then
                dragging = false
                state.isSliderDragging = false
            end
        end)

        -- Set initial label text using precise formatting
        do
            local rawValue = min + (range * startRatio)
            local value = formatValueByRange(rawValue)
            label.Text = text .. " : " .. tostring(value)
        end

        return { frame = sliderFrame, label = label, track = track, fill = fill, handle = handle, hit = hitBox }
    end

    -- AddDropdown（实现保留）
    function tabObj:AddDropdown(text, options, defaultIndex, callback)
        options = options or {}
        local currentIndex = defaultIndex or 1
        local isExpanded = false

        local dropdownFrame = Instance.new("Frame")
        dropdownFrame.Name = "DropdownFrame"
        dropdownFrame.Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)
        dropdownFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
        dropdownFrame.ClipsDescendants = false -- allow child anim
        dropdownFrame.ZIndex = 13
        dropdownFrame.Parent = pageFrame

        local dfCorner = Instance.new("UICorner")
        dfCorner.CornerRadius = UDim.new(0, 10)
        dfCorner.Parent = dropdownFrame

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -55, 0, UIConfig.ControlHeight)
        titleLabel.Position = UDim2.new(0, 12, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.RichText = true
        titleLabel.Text = text .. ": <font color=\"#FF69B4\">" .. tostring(options[currentIndex] or "无") .. "</font>"
        titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Font = Enum.Font.Gotham
        titleLabel.TextSize = UIConfig.FontSize
        titleLabel.ZIndex = 14
        titleLabel.Parent = dropdownFrame

        local expandBtn = Instance.new("TextButton")
        expandBtn.Name = "ExpandBtn"
        expandBtn.Size = UDim2.new(0, 28, 0, 28)
        expandBtn.Position = UDim2.new(1, -38, 0, (UIConfig.ControlHeight - 28) / 2)
        expandBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        expandBtn.Text = "+"
        expandBtn.TextColor3 = Color3.fromRGB(255, 105, 180)
        expandBtn.Font = Enum.Font.GothamBold
        expandBtn.TextSize = 16
        expandBtn.AutoButtonColor = false
        expandBtn.ZIndex = 14
        expandBtn.Parent = dropdownFrame

        local expandCorner = Instance.new("UICorner")
        expandCorner.CornerRadius = UDim.new(0, 6)
        expandCorner.Parent = expandBtn

        local listBg = Instance.new("Frame")
        listBg.Name = "ListBg"
        listBg.Size = UDim2.new(1, -24, 0, 0)
        listBg.Position = UDim2.new(0, 12, 0, UIConfig.ControlHeight)
        listBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        listBg.BorderSizePixel = 0
        listBg.ZIndex = 13
        listBg.Visible = false
        listBg.Parent = dropdownFrame

        local listBgCorner = Instance.new("UICorner")
        listBgCorner.CornerRadius = UDim.new(0, 8)
        listBgCorner.Parent = listBg

        local listBgStroke = Instance.new("UIStroke")
        listBgStroke.Thickness = 1
        listBgStroke.Color = Color3.fromRGB(60, 60, 65)
        listBgStroke.Transparency = 0.75
        listBgStroke.Parent = listBg

        local listContainer = Instance.new("ScrollingFrame")
        listContainer.Name = "DropdownList"
        listContainer.Size = UDim2.new(1, -8, 1, -8) -- will be resized into listBg
        listContainer.Position = UDim2.new(0, 4, 0, 4)
        listContainer.BackgroundTransparency = 1
        listContainer.ScrollBarThickness = 6
        listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
        listContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listContainer.Visible = false
        listContainer.Parent = listBg
        listContainer.ZIndex = 14
        listContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85)

        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 4)
        listLayout.Parent = listContainer

        local function UpdateListCanvas()
            local contentHeight = listLayout.AbsoluteContentSize.Y
            listContainer.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
            UpdateTabBarScrolling()
        end

        local function OpenDropdown()
            if isExpanded then return end
            isExpanded = true
            expandBtn.Text = "-"
            listBg.Visible = true
            listContainer.Visible = true

            local totalOptions = #options
            local maxVisible = UIConfig.DropdownMaxVisible
            local visibleCount = math.min(totalOptions, maxVisible)
            local targetListHeight = visibleCount * UIConfig.DropdownOptionHeight + (math.max(0, visibleCount - 1) * listLayout.Padding.Offset)
            local targetFrameHeight = UIConfig.ControlHeight + 6 + targetListHeight

            local tween = svc.TweenService:Create(dropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -10, 0, targetFrameHeight)
            })
            tween:Play()

            local bgTween = svc.TweenService:Create(listBg, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -24, 0, targetListHeight + 8)
            })
            bgTween:Play()

            task.delay(0.06, function()
                UpdateListCanvas()
                local children = listContainer:GetChildren()
                local idx = 0
                for _, child in ipairs(children) do
                    if child:IsA("TextButton") then
                        idx = idx + 1
                        child.Visible = true
                        child.BackgroundTransparency = 1
                        child.TextTransparency = 1
                        child.Position = UDim2.new(0, 0, 0, (idx - 1) * (UIConfig.DropdownOptionHeight + 4) + 0)
                        task.delay(idx * 0.03, function()
                            svc.TweenService:Create(child, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                BackgroundTransparency = 0
                            }):Play()
                            svc.TweenService:Create(child, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
                        end)
                    end
                end
            end)

            tween.Completed:Connect(function()
                UpdateListCanvas()
            end)
        end

        local function CloseDropdown()
            if not isExpanded then return end
            isExpanded = false
            expandBtn.Text = "+"
            local children = {}
            for _, child in ipairs(listContainer:GetChildren()) do
                if child:IsA("TextButton") then
                    table.insert(children, 1, child)
                end
            end
            local idx = 0
            for _, child in ipairs(children) do
                idx = idx + 1
                task.delay((idx - 1) * 0.02, function()
                    svc.TweenService:Create(child, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        BackgroundTransparency = 1
                    }):Play()
                    svc.TweenService:Create(child, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                    task.delay(0.15, function()
                        child.Visible = false
                    end)
                end)
            end

            local tween = svc.TweenService:Create(listBg, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, -24, 0, 0)
            })
            tween:Play()
            local frameTween = svc.TweenService:Create(dropdownFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)
            })
            frameTween:Play()
            frameTween.Completed:Connect(function()
                listBg.Visible = false
                listContainer.Visible = false
                UpdateTabBarScrolling()
            end)
        end

        expandBtn.MouseButton1Click:Connect(function()
            if isExpanded then
                CloseDropdown()
            else
                OpenDropdown()
            end
        end)

        for idx, optionText in ipairs(options) do
            local optionBtn = Instance.new("TextButton")
            optionBtn.Name = "Option_" .. tostring(idx)
            optionBtn.Size = UDim2.new(1, -8, 0, UIConfig.DropdownOptionHeight)
            optionBtn.Position = UDim2.new(0, 4, 0, (idx - 1) * (UIConfig.DropdownOptionHeight + 4))
            optionBtn.BackgroundColor3 = (idx == currentIndex) and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(40, 40, 45)
            optionBtn.Text = "  " .. tostring(optionText)
            optionBtn.TextColor3 = (idx == currentIndex) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 185)
            optionBtn.Font = Enum.Font.Gotham
            optionBtn.TextSize = UIConfig.FontSize - 1
            optionBtn.TextXAlignment = Enum.TextXAlignment.Left
            optionBtn.AutoButtonColor = false
            optionBtn.ZIndex = 16
            optionBtn.Visible = false -- initially hidden until open
            optionBtn.Parent = listContainer

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 6)
            optCorner.Parent = optionBtn

            optionBtn.MouseButton1Click:Connect(function()
                currentIndex = idx
                titleLabel.Text = text .. ": <font color=\"#FF69B4\">" .. tostring(optionText) .. "</font>"
                for _, btn in ipairs(listContainer:GetChildren()) do
                    if btn:IsA("TextButton") then
                        local isSelected = (btn.Name == "Option_" .. tostring(idx))
                        btn.BackgroundColor3 = isSelected and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(40, 40, 45)
                        btn.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 185)
                    end
                end
                if callback then pcall(callback, optionText, idx, titleLabel, dropdownFrame) end
                CloseDropdown()
            end)
        end

        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateListCanvas)

        return { frame = dropdownFrame, title = titleLabel, list = listContainer }
    end

    table.insert(tabs, tabObj)
    return tabObj
end

-- Create tabs
local AimbotTab = CreateTab("Aimbot")
local SettingsTab = CreateTab("设置")

-- Aimbot tab 基本 UI (place elements into ui.table)
ui.bindStatusLabel = Instance.new("TextLabel")
ui.bindStatusLabel.Size = UDim2.new(1, -10, 0, 20)
ui.bindStatusLabel.BackgroundTransparency = 1
ui.bindStatusLabel.Text = "当前绑定: 鼠标右键"
ui.bindStatusLabel.TextColor3 = Color3.fromRGB(240,240,240)
ui.bindStatusLabel.Font = Enum.Font.Gotham
ui.bindStatusLabel.TextSize = UIConfig.FontSize
ui.bindStatusLabel.ZIndex = 14
ui.bindStatusLabel.Parent = AimbotTab.Page

ui.targetLabel = Instance.new("TextLabel")
ui.targetLabel.Size = UDim2.new(1, -10, 0, 20)
ui.targetLabel.BackgroundTransparency = 1
ui.targetLabel.Text = "锁定目标: 无"
ui.targetLabel.TextColor3 = Color3.fromRGB(200,200,200)
ui.targetLabel.Font = Enum.Font.Gotham
ui.targetLabel.TextSize = UIConfig.FontSize - 1
ui.targetLabel.ZIndex = 14
ui.targetLabel.Parent = AimbotTab.Page

-- 状态变量 grouped in state table
state.aimbotEnabled = false
state.bindKeycode = Enum.UserInputType.MouseButton2
state.waitingForKey = false
state.smoothFactor = 0 -- 0..1, 0 instant, 1 max smoothing (慢)
state.lockedTarget = nil
state.mousePressStart = nil
state.mouseHoldActive = false
state.clickToggleActive = false
state.clickThreshold = 0.01
state.wallCheckEnabled = false
state.leadEnabled = false
state.bulletSpeed = 1500
state.fovValue = 50
state.maxAimDistance = 500
-- 瞄准部位多选（表 keyed by name => true）
state.aimPartChoices = {}
-- 保留身体默认选中
state.aimPartChoices["身体"] = true
state.aimMode = "原文"

-- 新功能选项
state.whitelist = {} -- keyed by UserId => true

state.ignoreLowHpEnabled = false
state.ignoreHpThreshold = 0 -- 0..100

state.fovColorRandomEnabled = false
state.showFov = true

state.adaptiveLeadEnabled = false
state.adaptiveLeadSensitivity = 0.5 -- 0..1

-- 只在手上有东西时瞄准（按用户要求）
state.weaponOnlyEnabled = false

-- 预测缓存（弱键，避免内存泄漏）
state.lastPredictions = setmetatable({}, { __mode = "k" })
state.lastPositions = setmetatable({}, { __mode = "k" }) -- 用于加强预测（位置+时间）

-- 新增功能变量：FOV 跟随鼠标、随机偏移与概率
state.fovFollowMouseEnabled = false
state.randomOffsetEnabled = false
state.randomOffsetProbability = 50 -- 0..100 默认 50

-- 新增：优先锁定最近目标开关（UI）
state.prioritizeNearest = false

-- 新增：护盾检测开关（如果目标有护盾则跳过）
state.shieldCheckEnabled = false

-- 可见性/墙体检测缓存，减少短时间重复 raycast
state.visibilityCache = {} -- key: part => {t=timestamp, visible=bool, blocked=bool}
state.visibilityCacheTTL = 0.12 -- seconds

local function updateBindDisplay(inp)
    local txt = "未知"
    if typeof(inp) == "EnumItem" and inp.Name then
        txt = inp.Name
    elseif type(inp) == "string" then
        txt = inp
    else
        txt = tostring(inp)
    end
    ui.bindStatusLabel.Text = "当前绑定: " .. txt
end

-- 修复：raycast 跳过不碰撞/半透明物体时的循环逻辑（避免使用 Lua 中不稳定的 continue）
local function raycastSkipPassable(fromPos, toPos, ignoreModel)
    if not fromPos or not toPos then return false end
    local dir = toPos - fromPos
    local distTotal = dir.Magnitude
    if distTotal <= 0 then return false end
    local dirUnit = dir.Unit
    local origin = fromPos
    local remaining = distTotal
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {ctx.LocalPlayer.Character, svc.Workspace.CurrentCamera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    -- performance: limit iterations to 4 (good tradeoff between penetration checks and cost)
    local maxIterations = 4
    for i = 1, maxIterations do
        local result = svc.Workspace:Raycast(origin, dirUnit * remaining, params)
        if not result then
            return false
        end
        local inst = result.Instance
        if inst and ignoreModel and inst:IsDescendantOf(ignoreModel) then
            return false
        end
        if inst and inst:IsA("BasePart") then
            local transparency = inst.Transparency or 0
            local canCollide = inst.CanCollide
            if (transparency >= 0.6) or (canCollide == false) then
                local hitPos = result.Position
                local hitDist = (hitPos - fromPos).Magnitude
                local advance = hitDist + 0.01
                if advance >= distTotal - 0.01 then
                    return false
                end
                origin = fromPos + dirUnit * advance
                remaining = (toPos - origin).Magnitude
                if remaining <= 0 then
                    return false
                end
                -- 继续下一次循环（等价于 continue）
            else
                -- 碰撞到不透明且可碰撞物体 => 不可穿透
                return true
            end
        else
            -- 非 BasePart 或没有实例（安全返回）
            return false
        end
    end
    return true
end

-- computeFovRadiusPixels：计算 FOV 对应的像素半径（原实现）
local function computeFovRadiusPixels(angleDeg)
    local cam = svc.Workspace.CurrentCamera
    if not cam then return 0 end
    local camPos = cam.CFrame.Position
    local look = cam.CFrame.LookVector
    local right = cam.CFrame.RightVector
    local dist = 100
    local forwardPoint = camPos + look * dist
    local offsetAmount = math.tan(math.rad(math.clamp(angleDeg, 1, 179))) * dist
    local sidePoint = forwardPoint + right * offsetAmount
    local forwardScreen = cam:WorldToViewportPoint(forwardPoint)
    local sideScreen = cam:WorldToViewportPoint(sidePoint)
    if forwardScreen.Z <= 0 or sideScreen.Z <= 0 then
        return math.max(8, math.min(200, angleDeg * 2))
    end
    local forwardVec = Vector2.new(forwardScreen.X, forwardScreen.Y)
    local sideVec = Vector2.new(sideScreen.X, sideScreen.Y)
    local radius = (sideVec - forwardVec).Magnitude
    return radius
end

local function clampVecToViewport(vec, r, viewportSize)
    local x = math.clamp(vec.X, r, viewportSize.X - r)
    local y = math.clamp(vec.Y, r, viewportSize.Y - r)
    return Vector2.new(x, y)
end

local function getScreenCenterForFov()
    local cam = svc.Workspace.CurrentCamera
    if not cam then return Vector2.new(0,0) end
    return Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
end

-- isPartVisibleWithPenetration：用于判断部位是否可见（允许穿透一些透明/不可碰撞物），并带短期缓存以减少 raycast 消耗
local function isPartVisibleWithPenetration(part, cam, ignoreModel)
    if not part or not part:IsA("BasePart") then return false end
    local now = tick()
    local cache = state.visibilityCache[part]
    if cache and (now - cache.t) < state.visibilityCacheTTL then
        return cache.visible
    end

    local origin = cam.CFrame.Position
    local dir = part.Position - origin
    local distTotal = dir.Magnitude
    if distTotal <= 0 then
        state.visibilityCache[part] = { t = now, visible = true }
        return true
    end
    local dirUnit = dir.Unit
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {ctx.LocalPlayer.Character, svc.Workspace.CurrentCamera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local originPos = origin
    local remaining = distTotal
    local maxIter = 4 -- performance: reduce from 8
    local resultVisible = false
    for i = 1, maxIter do
        local result = svc.Workspace:Raycast(originPos, dirUnit * remaining, params)
        if not result then
            resultVisible = true
            break
        end
        local inst = result.Instance
        if inst and ignoreModel and inst:IsDescendantOf(ignoreModel) then
            resultVisible = true
            break
        end
        if inst and inst:IsA("BasePart") then
            if inst:IsDescendantOf(part.Parent) then
                resultVisible = true
                break
            end
            local transparency = inst.Transparency or 0
            local canCollide = inst.CanCollide
            if (transparency >= 0.6) or (canCollide == false) then
                local hitPos = result.Position
                local hitDist = (hitPos - origin).Magnitude
                if hitDist >= distTotal - 0.01 then
                    resultVisible = true
                    break
                end
                originPos = origin + dirUnit * (hitDist + 0.01)
                remaining = (part.Position - originPos).Magnitude
                if remaining <= 0 then
                    resultVisible = true
                    break
                end
                -- continue loop
            else
                resultVisible = false
                break
            end
        else
            resultVisible = false
            break
        end
    end

    state.visibilityCache[part] = { t = now, visible = resultVisible }
    return resultVisible
end

-- 部位映射：保留身体并新增 头、左右手、左右腿 等选项
local chestNames = { "UpperTorso", "Torso", "HumanoidRootPart", "Chest" }

local aimOptionsMapping = {
    ["胸部"] = chestNames,
    ["头"] = {"Head"},
    ["左手"] = {"LeftHand"},
    ["右手"] = {"RightHand"},
    ["左腿"] = {"LeftUpperLeg","LeftLowerLeg","LeftFoot"},
    ["右腿"] = {"RightUpperLeg","RightLowerLeg","RightFoot"},
}

-- findBestVisiblePart：优先尝试已选部位（使用缓存的可见性判定）
local function findBestVisiblePart(char, cam, centerVec, radiusPx, selectedPrefs)
    local function checkList(list)
        for _,name in ipairs(list) do
            local p = char:FindFirstChild(name, true)
            if p and p:IsA("BasePart") then
                local screenPos = cam:WorldToViewportPoint(p.Position)
                if screenPos.Z > 0 then
                    local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                    local dist = (screenVec - centerVec).Magnitude
                    if dist <= radiusPx and isPartVisibleWithPenetration(p, cam, char) then
                        return p, dist
                    end
                end
            end
        end
        return nil, nil
    end

    -- Build preferred lists from selectedPrefs (table keyed by name=>true)
    local lists = {}
    if type(selectedPrefs) == "table" then
        for prefName, active in pairs(selectedPrefs) do
            if active then
                local mapped = aimOptionsMapping[prefName]
                if mapped then
                    table.insert(lists, mapped)
                else
                    table.insert(lists, {prefName})
                end
            end
        end
    end

    for _, list in ipairs(lists) do
        local p, d = checkList(list)
        if p then
            return p, d
        end
    end

    local fallbackLists = { chestNames, {"Head"}, {"LeftHand","RightHand"}, {"LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot"} }
    for _, list in ipairs(fallbackLists) do
        local p, d = checkList(list)
        if p then
            return p, d
        end
    end

    -- 最后回退：任何可见部位（距离中心最近）
    local bestPart = nil
    local bestDist = math.huge
    for _,desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            local screenPos = cam:WorldToViewportPoint(desc.Position)
            if screenPos.Z > 0 then
                local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                local dist = (screenVec - centerVec).Magnitude
                if dist <= radiusPx and dist < bestDist and isPartVisibleWithPenetration(desc, cam, char) then
                    bestDist = dist
                    bestPart = desc
                end
            end
        end
    end
    return bestPart, bestPart and bestDist or nil
end

-- 检测角色是否具有护盾（ForceField / Shield 名称 / 布尔值 / 属性等多重检测）
local function characterHasShield(char)
    if not char then return false end
    if char:FindFirstChildOfClass("ForceField") then
        return true
    end
    local s = char:FindFirstChild("Shield") or char:FindFirstChild("护盾") or char:FindFirstChild("ShieldValue") or char:FindFirstChild("HasShield")
    if s then
        if s:IsA("BoolValue") or s:IsA("IntValue") or s:IsA("NumberValue") then
            if s.Value and s.Value ~= 0 then return true end
        elseif s:IsA("BasePart") or s.ClassName == "Model" then
            return true
        end
    end
    if char.GetAttribute then
        local attr = char:GetAttribute("Shield")
        if attr == true or attr == 1 then return true end
    end
    return false
end

-- getClosestToCrosshair：遍历玩家并使用 findBestVisiblePart 选取最佳目标
local function getClosestToCrosshair()
    local cam = svc.Workspace.CurrentCamera
    local localChar = ctx.LocalPlayer.Character
    if not cam or not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return nil end

    local centerVec
    if state.fovFollowMouseEnabled then
        local mouseLoc = svc.UserInputService:GetMouseLocation()
        centerVec = Vector2.new(mouseLoc.X, mouseLoc.Y)
    else
        centerVec = getScreenCenterForFov()
    end

    local radiusPx = state.showFov and computeFovRadiusPixels(state.fovValue) or math.huge

    local best = nil
    local bestMetric = math.huge
    for _,plr in ipairs(svc.Players:GetPlayers()) do
        if plr ~= ctx.LocalPlayer then
            if state.whitelist[plr.UserId] then
                -- skip whitelisted
            else
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        if state.ignoreLowHpEnabled and hum.Health <= state.ignoreHpThreshold then
                            -- skip low hp
                        else
                            if state.shieldCheckEnabled and characterHasShield(char) then
                                -- skip shielded
                            else
                                local part, dist = findBestVisiblePart(char, cam, centerVec, radiusPx, state.aimPartChoices)
                                if part and dist then
                                    local blocked = false
                                    if state.wallCheckEnabled then
                                        local ok, result = pcall(function()
                                            return raycastSkipPassable(cam.CFrame.Position, part.Position, char)
                                        end)
                                        if ok and result then
                                            blocked = true
                                        end
                                    end

                                    if not blocked then
                                        local worldDist = (part.Position - cam.CFrame.Position).Magnitude
                                        local metric = state.prioritizeNearest and worldDist or dist
                                        if worldDist <= state.maxAimDistance and metric < bestMetric then
                                            bestMetric = metric
                                            best = { character = char, part = part, player = plr, worldDist = worldDist }
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- 求解拦截时间（相对运动方程）
local function solveInterceptTime(origin, targetPos, targetVel, projectileSpeed)
    local toTarget = targetPos - origin
    local a = targetVel:Dot(targetVel) - projectileSpeed * projectileSpeed
    local b = 2 * targetVel:Dot(toTarget)
    local c = toTarget:Dot(toTarget)
    if math.abs(a) < 1e-6 then
        if math.abs(b) < 1e-6 then
            if c <= 0 then return 0 end
            return nil
        end
        local t = -c / b
        if t > 0 then return t end
        return nil
    end
    local disc = b*b - 4*a*c
    if disc < 0 then return nil end
    local sqrtD = math.sqrt(disc)
    local t1 = (-b - sqrtD) / (2*a)
    local t2 = (-b + sqrtD) / (2*a)
    local t = nil
    if t1 > 0 and t2 > 0 then t = math.min(t1, t2)
    elseif t1 > 0 then t = t1
    elseif t2 > 0 then t = t2
    end
    return t
end

-- 检查玩家手上是否有任何 Tool
local function playerHasAnythingInHand()
    local char = ctx.LocalPlayer.Character
    if not char then return false end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            return true
        end
    end
    return false
end

-- Enhanced prediction with adaptive lead auto-adjust and smoothing compensation
local function predictPositionForPart(part, origin)
    if not part or not part:IsA("BasePart") then return part and part.Position or nil end

    local currentPos = part.Position
    local vel = part.Velocity or Vector3.new(0,0,0)

    local now = tick()
    local last = state.lastPositions[part]
    local observedVel = vel
    if last and last.pos and last.t then
        local dt = now - last.t
        if dt > 1e-4 then
            local obs = (currentPos - last.pos) / dt
            observedVel = obs
        end
    end
    local estimatedVel = vel * 0.6 + observedVel * 0.4
    state.lastPositions[part] = { pos = currentPos, t = now }

    local predicted = currentPos

    if state.leadEnabled then
        local t = solveInterceptTime(origin, currentPos, estimatedVel, state.bulletSpeed)
        local dist = (currentPos - origin).Magnitude
        local timeEstimate = t or (dist / math.max(1, state.bulletSpeed))

        -- required lead magnitude (approx)
        local requiredLeadMag = estimatedVel.Magnitude * math.max(0, timeEstimate)

        -- base lead blend derived from smoothFactor (less smooth => more immediate => higher blend)
        local baseLeadBlend = math.clamp(1 - state.smoothFactor, 0, 1)

        -- lead importance: how big is required lead relative to a heuristic threshold
        local importance = math.clamp(requiredLeadMag / math.max(10, dist * 0.05), 0, 1)

        -- adaptive adjustment: combine user sensitivity and measured importance
        local adaptiveFactor = 0
        if state.adaptiveLeadEnabled then
            adaptiveFactor = state.adaptiveLeadSensitivity * importance
        end

        -- final lead blend: ensure we boost lead when smoothFactor is high (so smoothing doesn't kill leading)
        local leadBlend = baseLeadBlend + adaptiveFactor * (1 - baseLeadBlend)
        leadBlend = math.clamp(leadBlend, 0, 1)

        -- compensation factor: when smooth is high, overshoot predicted to counter camera lerp smoothing
        local compensation = 1 + state.smoothFactor * 0.8

        if timeEstimate and timeEstimate > 0 then
            predicted = currentPos + estimatedVel * timeEstimate * leadBlend * compensation
        else
            -- fallback: approximate
            local fallbackTime = dist / math.max(1, state.bulletSpeed)
            predicted = currentPos + estimatedVel * fallbackTime * leadBlend * compensation
        end
    else
        predicted = currentPos
    end

    local prev = state.lastPredictions[part]
    if prev then
        local smoothW = math.clamp(state.smoothFactor, 0, 1)
        predicted = prev:Lerp(predicted, 1 - smoothW)
    end

    state.lastPredictions[part] = predicted
    return predicted
end

-- 从角色中选择一个随机的可见部位（排除 excludePart）
local function chooseRandomVisiblePart(char, cam, centerVec, radiusPx, excludePart)
    if not char or not cam then return nil end
    local candidates = {}
    for _,desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") and desc ~= excludePart then
            local screenPos = cam:WorldToViewportPoint(desc.Position)
            if screenPos.Z > 0 then
                local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                local dist = (screenVec - centerVec).Magnitude
                if dist <= radiusPx and isPartVisibleWithPenetration(desc, cam, char) then
                    table.insert(candidates, desc)
                end
            end
        end
    end
    if #candidates == 0 then return nil end
    local idx = math.random(1, #candidates)
    return candidates[idx]
end

-- 设置 aimbot 状态（UI 同步）
local function SetAimbotState(stateBool)
    state.aimbotEnabled = stateBool
    if ui.aimbotSwitch and ui.aimbotSwitch.track then
        -- ui.aimbotSwitch holds a table when created via AddToggle; try to update visuals
        ui.aimbotSwitch.track:SetAttribute("State", stateBool)
        ui.aimbotSwitch.track.BackgroundColor3 = stateBool and Color3.fromRGB(52,199,89) or Color3.fromRGB(70,70,75)
        local thumb = ui.aimbotSwitch.thumb
        if thumb then
            if stateBool then
                thumb.Position = UDim2.new(1, -18, 0.5, -8)
            else
                thumb.Position = UDim2.new(0, 2, 0.5, -8)
            end
        end
    end
    if stateBool then
        state.lockedTarget = getClosestToCrosshair()
        if state.lockedTarget then
            ui.targetLabel.Text = "锁定目标: "..(state.lockedTarget.player and state.lockedTarget.player.Name or "未知").." ("..(state.lockedTarget.part and state.lockedTarget.part.Name or "部位")..")"
        else
            ui.targetLabel.Text = "锁定目标: 无"
        end
    else
        state.lockedTarget = nil
        ui.targetLabel.Text = "锁定目标: 无"
    end
end

-- predictAndAim：主瞄准函数（将预测位置用于构建目标 CFrame，同时在高平滑时仍尽量保留提前瞄准效果）
local function predictAndAim(cam, part)
    if not cam or not part then return false end
    local aimPos = part.Position
    if state.leadEnabled then
        local predicted = predictPositionForPart(part, cam.CFrame.Position)
        if predicted then aimPos = predicted end
    end
    local screenPos = cam:WorldToViewportPoint(aimPos)
    if screenPos.Z <= 0 then
        return false
    end
    local screenVec = Vector2.new(screenPos.X, screenPos.Y)

    local centerVec
    if state.fovFollowMouseEnabled then
        local mouseLoc = svc.UserInputService:GetMouseLocation()
        centerVec = Vector2.new(mouseLoc.X, mouseLoc.Y)
    else
        centerVec = getScreenCenterForFov()
    end

    local radiusPx = state.showFov and computeFovRadiusPixels(state.fovValue) or math.huge
    local dist = (screenVec - centerVec).Magnitude
    if dist > radiusPx then
        return false
    end

    local targetCf = CFrame.new(cam.CFrame.Position, aimPos)

    local smoothLocal = state.smoothFactor
    if state.adaptiveLeadEnabled then
        -- further reduce smoothing if predicted offset is large
        local predictedOffset = (aimPos - part.Position).Magnitude
        local fovFactor = math.clamp(state.fovValue / 180, 0, 1)
        local leadScale = math.clamp(predictedOffset / 20, 0, 1)
        local reduce = state.adaptiveLeadSensitivity * fovFactor * leadScale
        smoothLocal = math.clamp(state.smoothFactor - reduce, 0, 1)
    end

    -- ensure interpolation alpha doesn't become too tiny (prevents smoothing fully blocking aiming)
    local lerpAlpha = math.clamp(1 - smoothLocal, 0.02, 1)
    if smoothLocal <= 0 then
        cam.CFrame = targetCf
    else
        cam.CFrame = cam.CFrame:Lerp(targetCf, lerpAlpha)
    end
    return true
end

-- FOV 可视圆与颜色动画
ui.FovCircle = nil
ui.FovStroke = nil
local fovColorTarget = Color3.fromRGB(255,182,193)
local fovColorCurrent = Color3.fromRGB(255,182,193)
local fovColorTweenSpeed = 0.01 -- 每帧线性插值步长

local function createFovCircle()
    if ui.FovCircle and ui.FovCircle.Parent then return end
    ui.FovCircle = Instance.new("Frame")
    ui.FovCircle.Name = "FovCircle"
    ui.FovCircle.AnchorPoint = Vector2.new(0.5,0.5)
    ui.FovCircle.Size = UDim2.new(0, 100, 0, 100)
    ui.FovCircle.BackgroundTransparency = 1
    ui.FovCircle.ZIndex = 200
    ui.FovCircle.Parent = ui.ScreenGui

    ui.FovStroke = Instance.new("UIStroke")
    ui.FovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ui.FovStroke.Thickness = 2
    ui.FovStroke.Color = fovColorCurrent
    ui.FovStroke.Transparency = 0.25
    ui.FovStroke.Parent = ui.FovCircle

    local FovCorner = Instance.new("UICorner")
    FovCorner.CornerRadius = UDim.new(0.5, 0)
    FovCorner.Parent = ui.FovCircle
end

-- Aimbot 控件（UI） - create toggles/sliders through the tab's helpers, store references in ui table
do
    local t = AimbotTab:AddToggle("Aimbot 开启", false, function(st)
        SetAimbotState(st)
    end)
    ui.aimbotSwitch = { track = t.track, thumb = t.thumb, frame = t.frame, label = t.label }
end

do
    local t = AimbotTab:AddToggle("墙壁检测", false, function(st)
        state.wallCheckEnabled = st
    end)
    ui.wallSwitch = { track = t.track, thumb = t.thumb }
end

do
    local t = AimbotTab:AddToggle("提前瞄准", false, function(st)
        state.leadEnabled = st
    end)
    ui.leadSwitch = { track = t.track, thumb = t.thumb }
end

-- 新增：护盾检测开关（如果目标有护盾则跳过）
do
    local t = AimbotTab:AddToggle("护盾检测", false, function(st)
        state.shieldCheckEnabled = st
    end)
    ui.shieldSwitch = { track = t.track, thumb = t.thumb }
end

do
    local b = AimbotTab:AddButton("点击设置快捷键", function(btn, label)
        if state.waitingForKey then return end
        state.waitingForKey = true
        if label and label.Text then label.Text = "请按下绑定按键..." end
        ui.bindStatusLabel.Text = "等待输入按键"
    end)
    ui.bindBtn = b.btn
    ui.bindBtnLabel = b.label
end

-- 白名单控件（使用 fewer locals inside function）
local function CreateWhitelistControl(parentTab)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)
    frame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    frame.ZIndex = 13
    frame.Parent = parentTab.Page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -55, 0, UIConfig.ControlHeight)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.RichText = true
    title.Text = "白名单: <font color=\"#FF69B4\">未选择</font>"
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.Gotham
    title.TextSize = UIConfig.FontSize
    title.ZIndex = 14
    title.Parent = frame

    local expandBtn = Instance.new("TextButton")
    expandBtn.Name = "ExpandBtn"
    expandBtn.Size = UDim2.new(0, 28, 0, 28)
    expandBtn.Position = UDim2.new(1, -38, 0, (UIConfig.ControlHeight - 28) / 2)
    expandBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    expandBtn.Text = "+"
    expandBtn.TextColor3 = Color3.fromRGB(255, 105, 180)
    expandBtn.Font = Enum.Font.GothamBold
    expandBtn.TextSize = 16
    expandBtn.AutoButtonColor = false
    expandBtn.ZIndex = 14
    expandBtn.Parent = frame

    local listBg = Instance.new("Frame")
    listBg.Name = "ListBg"
    listBg.Size = UDim2.new(1, -24, 0, 0)
    listBg.Position = UDim2.new(0, 12, 0, UIConfig.ControlHeight)
    listBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    listBg.BorderSizePixel = 0
    listBg.ZIndex = 13
    listBg.Visible = false
    listBg.Parent = frame

    local listContainer = Instance.new("ScrollingFrame")
    listContainer.Name = "WhitelistList"
    listContainer.Size = UDim2.new(1, -8, 1, -8)
    listContainer.Position = UDim2.new(0, 4, 0, 4)
    listContainer.BackgroundTransparency = 1
    listContainer.ScrollBarThickness = 6
    listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    listContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listContainer.Visible = false
    listContainer.Parent = listBg
    listContainer.ZIndex = 14
    listContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85)

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = listContainer

    local isExpanded = false

    local function RefreshListVisual()
        for _,c in ipairs(listContainer:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local players = svc.Players:GetPlayers()
        for i, plr in ipairs(players) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, UIConfig.DropdownOptionHeight)
            btn.BackgroundColor3 = state.whitelist[plr.UserId] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
            btn.Text = "  "..plr.Name
            btn.TextColor3 = state.whitelist[plr.UserId] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = UIConfig.FontSize - 1
            btn.AutoButtonColor = false
            btn.ZIndex = 15
            btn.Visible = false
            btn.Parent = listContainer

            btn.MouseButton1Click:Connect(function()
                local uid = plr.UserId
                if state.whitelist[uid] then
                    state.whitelist[uid] = nil
                else
                    state.whitelist[uid] = true
                end
                btn.BackgroundColor3 = state.whitelist[uid] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
                btn.TextColor3 = state.whitelist[uid] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)

                local count = 0
                local firstName
                for _,p in ipairs(svc.Players:GetPlayers()) do
                    if state.whitelist[p.UserId] then
                        count = count + 1
                        if not firstName then firstName = p.Name end
                    end
                end
                if count == 0 then
                    title.Text = "白名单: <font color=\"#FF69B4\">未选择</font>"
                elseif count == 1 and firstName then
                    title.Text = "白名单: <font color=\"#FF69B4\">"..firstName.."</font>"
                else
                    title.Text = "白名单: <font color=\"#FF69B4\">已选 "..tostring(count).." 人</font>"
                end
            end)
        end

        if isExpanded then
            task.delay(0.05, function()
                local children = listContainer:GetChildren()
                local index = 0
                for _, c in ipairs(children) do
                    if c:IsA("TextButton") then
                        index = index + 1
                        c.Visible = true
                        c.BackgroundTransparency = 1
                        c.TextTransparency = 1
                        task.delay(index * 0.03, function()
                            svc.TweenService:Create(c, TweenInfo.new(0.18), {BackgroundTransparency = 0}):Play()
                            svc.TweenService:Create(c, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
                        end)
                    end
                end
            end)
        else
            for _, c in ipairs(listContainer:GetChildren()) do
                if c:IsA("TextButton") then
                    c.Visible = false
                end
            end
        end
        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
            UpdateTabBarScrolling()
        end)
        listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
        UpdateTabBarScrolling()
    end

    local function Open()
        if isExpanded then return end
        isExpanded = true
        expandBtn.Text = "-"
        listBg.Visible = true
        listContainer.Visible = true
        RefreshListVisual()
        local playersCount = #svc.Players:GetPlayers()
        local visibleCount = math.min(playersCount, UIConfig.DropdownMaxVisible)
        local targetListHeight = visibleCount * UIConfig.DropdownOptionHeight + (math.max(0, visibleCount - 1) * listLayout.Padding.Offset)
        local targetFrameHeight = UIConfig.ControlHeight + 6 + targetListHeight
        svc.TweenService:Create(frame, TweenInfo.new(0.25), {Size = UDim2.new(1, -10, 0, targetFrameHeight)}):Play()
        svc.TweenService:Create(listBg, TweenInfo.new(0.25), {Size = UDim2.new(1, -24, 0, targetListHeight + 8)}):Play()
    end

    local function Close()
        if not isExpanded then return end
        isExpanded = false
        expandBtn.Text = "+"
        local children = {}
        for _, c in ipairs(listContainer:GetChildren()) do
            if c:IsA("TextButton") then table.insert(children, 1, c) end
        end
        local idx = 0
        for _, c in ipairs(children) do
            idx = idx + 1
            task.delay((idx - 1) * 0.02, function()
                svc.TweenService:Create(c, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                svc.TweenService:Create(c, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                task.delay(0.15, function() c.Visible = false end)
            end)
        end
        svc.TweenService:Create(listBg, TweenInfo.new(0.22), {Size = UDim2.new(1, -24, 0, 0)}):Play()
        svc.TweenService:Create(frame, TweenInfo.new(0.22), {Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)}):Play()
        task.delay(0.22, function()
            listBg.Visible = false
            listContainer.Visible = false
            UpdateTabBarScrolling()
        end)
    end

    expandBtn.MouseButton1Click:Connect(function()
        if isExpanded then Close() else Open() end
    end)

    svc.Players.PlayerAdded:Connect(function() RefreshListVisual() end)
    svc.Players.PlayerRemoving:Connect(function(plr)
        state.whitelist[plr.UserId] = nil
        RefreshListVisual()
    end)

    RefreshListVisual()
    return frame, title
end

local wlFrame, wlTitle = CreateWhitelistControl(AimbotTab)

-- 瞄准部位多选控件（保留但避免 many top-level locals）
local function CreateAimPartMultiSelect(parentTab)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)
    frame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    frame.ZIndex = 13
    frame.Parent = parentTab.Page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -55, 0, UIConfig.ControlHeight)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.RichText = true
    title.Text = "瞄准部位: <font color=\"#FF69B4\">身体</font>"
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.Gotham
    title.TextSize = UIConfig.FontSize
    title.ZIndex = 14
    title.Parent = frame

    local expandBtn = Instance.new("TextButton")
    expandBtn.Name = "ExpandBtn"
    expandBtn.Size = UDim2.new(0, 28, 0, 28)
    expandBtn.Position = UDim2.new(1, -38, 0, (UIConfig.ControlHeight - 28) / 2)
    expandBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    expandBtn.Text = "+"
    expandBtn.TextColor3 = Color3.fromRGB(255, 105, 180)
    expandBtn.Font = Enum.Font.GothamBold
    expandBtn.TextSize = 16
    expandBtn.AutoButtonColor = false
    expandBtn.ZIndex = 14
    expandBtn.Parent = frame

    local listBg = Instance.new("Frame")
    listBg.Name = "ListBg"
    listBg.Size = UDim2.new(1, -24, 0, 0)
    listBg.Position = UDim2.new(0, 12, 0, UIConfig.ControlHeight)
    listBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    listBg.BorderSizePixel = 0
    listBg.ZIndex = 13
    listBg.Visible = false
    listBg.Parent = frame

    local listContainer = Instance.new("ScrollingFrame")
    listContainer.Name = "AimPartList"
    listContainer.Size = UDim2.new(1, -8, 1, -8)
    listContainer.Position = UDim2.new(0, 4, 0, 4)
    listContainer.BackgroundTransparency = 1
    listContainer.ScrollBarThickness = 6
    listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    listContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listContainer.Visible = false
    listContainer.Parent = listBg
    listContainer.ZIndex = 14
    listContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85)

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = listContainer

    local isExpanded = false

    local aimPartsList = {
        "身体","头","左手","右手","左腿","右腿"
    }

    local function RefreshListVisual()
        for _,c in ipairs(listContainer:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, name in ipairs(aimPartsList) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, UIConfig.DropdownOptionHeight)
            btn.BackgroundColor3 = state.aimPartChoices[name] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
            btn.Text = "  "..name
            btn.TextColor3 = state.aimPartChoices[name] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = UIConfig.FontSize - 1
            btn.AutoButtonColor = false
            btn.ZIndex = 15
            btn.Visible = false
            btn.Parent = listContainer

            btn.MouseButton1Click:Connect(function()
                if state.aimPartChoices[name] then
                    state.aimPartChoices[name] = nil
                else
                    state.aimPartChoices[name] = true
                end
                btn.BackgroundColor3 = state.aimPartChoices[name] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
                btn.TextColor3 = state.aimPartChoices[name] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)

                local count = 0
                local firstName
                for _, n in ipairs(aimPartsList) do
                    if state.aimPartChoices[n] then
                        count = count + 1
                        if not firstName then firstName = n end
                    end
                end
                if count == 0 then
                    title.Text = "瞄准部位: <font color=\"#FF69B4\">未选择</font>"
                elseif count == 1 and firstName then
                    title.Text = "瞄准部位: <font color=\"#FF69B4\">"..firstName.."</font>"
                else
                    title.Text = "瞄准部位: <font color=\"#FF69B4\">已选 "..tostring(count).." 项</font>"
                end
            end)
        end

        if isExpanded then
            task.delay(0.05, function()
                local children = listContainer:GetChildren()
                local index = 0
                for _, c in ipairs(children) do
                    if c:IsA("TextButton") then
                        index = index + 1
                        c.Visible = true
                        c.BackgroundTransparency = 1
                        c.TextTransparency = 1
                        task.delay(index * 0.03, function()
                            svc.TweenService:Create(c, TweenInfo.new(0.18), {BackgroundTransparency = 0}):Play()
                            svc.TweenService:Create(c, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
                        end)
                    end
                end
            end)
        else
            for _, c in ipairs(listContainer:GetChildren()) do
                if c:IsA("TextButton") then
                    c.Visible = false
                end
            end
        end

        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
            UpdateTabBarScrolling()
        end)
        listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
        UpdateTabBarScrolling()
    end

    local function Open()
        if isExpanded then return end
        isExpanded = true
        expandBtn.Text = "-"
        listBg.Visible = true
        listContainer.Visible = true
        RefreshListVisual()
        local visibleCount = math.min(#aimPartsList, UIConfig.DropdownMaxVisible)
        local targetListHeight = visibleCount * UIConfig.DropdownOptionHeight + (math.max(0, visibleCount - 1) * listLayout.Padding.Offset)
        local targetFrameHeight = UIConfig.ControlHeight + 6 + targetListHeight
        svc.TweenService:Create(frame, TweenInfo.new(0.25), {Size = UDim2.new(1, -10, 0, targetFrameHeight)}):Play()
        svc.TweenService:Create(listBg, TweenInfo.new(0.25), {Size = UDim2.new(1, -24, 0, targetListHeight + 8)}):Play()
    end

    local function Close()
        if not isExpanded then return end
        isExpanded = false
        expandBtn.Text = "+"
        local children = {}
        for _, c in ipairs(listContainer:GetChildren()) do
            if c:IsA("TextButton") then table.insert(children, 1, c) end
        end
        local idx = 0
        for _, c in ipairs(children) do
            idx = idx + 1
            task.delay((idx - 1) * 0.02, function()
                svc.TweenService:Create(c, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                svc.TweenService:Create(c, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                task.delay(0.15, function() c.Visible = false end)
            end)
        end
        svc.TweenService:Create(listBg, TweenInfo.new(0.22), {Size = UDim2.new(1, -24, 0, 0)}):Play()
        svc.TweenService:Create(frame, TweenInfo.new(0.22), {Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)}):Play()
        task.delay(0.22, function()
            listBg.Visible = false
            listContainer.Visible = false
            UpdateTabBarScrolling()
        end)
    end

    expandBtn.MouseButton1Click:Connect(function()
        if isExpanded then Close() else Open() end
    end)

    RefreshListVisual()
    return frame, title
end

local aimPartsFrame, aimPartsTitle = CreateAimPartMultiSelect(AimbotTab)

-- Settings tab：滑块与开关（使用 helper methods）
do
    local s = SettingsTab:AddSlider("平滑度", 0, 1, 0, function(value, ratio)
        state.smoothFactor = ratio
        if s and s.label then
            local displayVal = string.format("%.2f", value)
            s.label.Text = "平滑度 : "..displayVal
        end
    end)
    ui.smoothSlider = s
end

do
    local s = SettingsTab:AddSlider("FOV", 1, 180, 50, function(value, ratio)
        state.fovValue = value
        if s and s.label then s.label.Text = "FOV : "..tostring(state.fovValue) end
        if ui.FovCircle and svc.Workspace.CurrentCamera then
            local radiusPx = computeFovRadiusPixels(state.fovValue)
            local r = math.floor(radiusPx + 0.5)
            if r < 6 then r = 6 end
            local cam = svc.Workspace.CurrentCamera
            local maxR = math.floor(math.min(cam.ViewportSize.X, cam.ViewportSize.Y) / 2)
            if r > maxR then r = maxR end
            ui.FovCircle.Size = UDim2.new(0, r*2, 0, r*2)
        end
    end)
    ui.fovSlider = s
end

do
    local s = SettingsTab:AddSlider("子弹速度", 100, 5000, 1500, function(value)
        state.bulletSpeed = value
        if s and s.label then s.label.Text = "子弹速度 : "..tostring(state.bulletSpeed) end
    end)
    ui.bulletSlider = s
end

do
    local s = SettingsTab:AddSlider("最大距离", 50, 1000, 500, function(value)
        state.maxAimDistance = value
        if s and s.label then s.label.Text = "最大距离 : "..tostring(state.maxAimDistance) end
    end)
    ui.maxdistSlider = s
end

do
    local t = SettingsTab:AddToggle("开启忽略低血量目标", false, function(st)
        state.ignoreLowHpEnabled = st
    end)
    ui.hpIgnoreSwitch = { track = t.track, thumb = t.thumb }
end

do
    local s = SettingsTab:AddSlider("忽略血量阈值", 0, 100, 0, function(value)
        state.ignoreHpThreshold = math.floor(value + 0.5)
        if s and s.label then s.label.Text = "忽略血量阈值 : "..tostring(state.ignoreHpThreshold) end
    end)
    ui.hpSlider = s
end

do
    local t = SettingsTab:AddToggle("FOV 颜色动态", false, function(st)
        state.fovColorRandomEnabled = st
        if not st and ui.FovStroke then
            ui.FovStroke.Color = Color3.fromRGB(255,182,193)
            fovColorCurrent = ui.FovStroke.Color
            fovColorTarget = fovColorCurrent
        end
    end)
    ui.fovColorSwitch = { track = t.track, thumb = t.thumb }
end

do
    local t = SettingsTab:AddToggle("显示FOV", true, function(st)
        state.showFov = st
        if ui.FovCircle then
            ui.FovCircle.Visible = st
        end
    end)
    ui.showFovSwitch = { track = t.track, thumb = t.thumb }
end

do
    local t = SettingsTab:AddToggle("自适应提前瞄准", false, function(st)
        state.adaptiveLeadEnabled = st
    end)
    ui.adaptiveLeadSwitch = { track = t.track, thumb = t.thumb }
end

do
    local s = SettingsTab:AddSlider("自适应灵敏度", 0, 1, 0.5, function(value, ratio)
        state.adaptiveLeadSensitivity = ratio
        if s and s.label then s.label.Text = "自适应灵敏度 : "..string.format("%.2f", value) end
    end)
    ui.adaptiveSlider = s
end

do
    local t = SettingsTab:AddToggle("只要手上有东西就瞄准", false, function(st)
        state.weaponOnlyEnabled = st
    end)
    ui.weaponOnlySwitch = { track = t.track, thumb = t.thumb }
end

do
    local t = SettingsTab:AddToggle("FOV 跟随鼠标", false, function(st)
        state.fovFollowMouseEnabled = st
        if ui.FovCircle then
            if st then
                local mouseLoc = svc.UserInputService:GetMouseLocation()
                ui.FovCircle.Position = UDim2.new(0, mouseLoc.X, 0, mouseLoc.Y)
            else
                local centerVec = getScreenCenterForFov()
                ui.FovCircle.Position = UDim2.new(0, centerVec.X, 0, centerVec.Y)
            end
        end
    end)
    ui.fovFollowSwitch = { track = t.track, thumb = t.thumb }
end

do
    local t = SettingsTab:AddToggle("随机偏移目标部位", false, function(st)
        state.randomOffsetEnabled = st
    end)
    ui.randOffsetSwitch = { track = t.track, thumb = t.thumb }
end

do
    local s = SettingsTab:AddSlider("偏移概率", 0, 100, 50, function(value)
        state.randomOffsetProbability = math.clamp(math.floor(value + 0.5), 0, 100)
        if s and s.label then s.label.Text = "偏移概率 : "..tostring(state.randomOffsetProbability).."%" end
    end)
    ui.probSlider = s
end

do
    local t = SettingsTab:AddToggle("优先锁定最近目标", false, function(st)
        state.prioritizeNearest = st
    end)
    ui.prioritizeSwitch = { track = t.track, thumb = t.thumb }
end

-- 瞄准模式下拉（保留）
do
    local d = AimbotTab:AddDropdown("瞄准模式", {"原文","Raycast","Ray"}, 1, function(optionText)
        state.aimMode = optionText
        if d and d.title then d.title.Text = "瞄准模式: <font color=\"#FF69B4\">"..state.aimMode.."</font>" end
    end)
    ui.aimModeDropdown = d
end

-- 初始化文本
ui.bindStatusLabel.Text = "当前绑定: 鼠标右键"
if ui.smoothSlider and ui.smoothSlider.label then ui.smoothSlider.label.Text = string.format("平滑度 : %.2f", 0.00) end
if ui.fovSlider and ui.fovSlider.label then ui.fovSlider.label.Text = "FOV : "..tostring(state.fovValue) end
if ui.bulletSlider and ui.bulletSlider.label then ui.bulletSlider.label.Text = "子弹速度 : "..tostring(state.bulletSpeed) end
if ui.maxdistSlider and ui.maxdistSlider.label then ui.maxdistSlider.label.Text = "最大距离 : "..tostring(state.maxAimDistance) end
if ui.hpSlider and ui.hpSlider.label then ui.hpSlider.label.Text = "忽略血量阈值 : "..tostring(state.ignoreHpThreshold) end
if aimPartsTitle then aimPartsTitle.Text = "瞄准部位: <font color=\"#FF69B4\">身体</font>" end
if ui.aimModeDropdown and ui.aimModeDropdown.title then ui.aimModeDropdown.title.Text = "瞄准模式: <font color=\"#FF69B4\">"..state.aimMode.."</font>" end
if ui.probSlider and ui.probSlider.label then ui.probSlider.label.Text = "偏移概率 : "..tostring(state.randomOffsetProbability).."%" end

-- 绑定按键逻辑（保持行为）
svc.UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if state.waitingForKey then
        state.waitingForKey = false
        if ui.bindBtnLabel then ui.bindBtnLabel.Text = "点击设置快捷键" end
        if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
            state.bindKeycode = input.KeyCode
            updateBindDisplay(input.KeyCode)
        else
            state.bindKeycode = input.UserInputType
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                updateBindDisplay("鼠标右键")
            else
                updateBindDisplay(input.UserInputType)
            end
        end
        return
    end

    if not state.isMobile and input.UserInputType == Enum.UserInputType.MouseButton2 and state.bindKeycode == Enum.UserInputType.MouseButton2 then
        state.mousePressStart = os.clock()
        state.mouseHoldActive = false
        task.delay(state.clickThreshold, function()
            if state.mousePressStart and (os.clock() - state.mousePressStart) >= state.clickThreshold then
                state.mouseHoldActive = true
                SetAimbotState(true)
            end
        end)
        return
    end

    if state.bindKeycode then
        if typeof(state.bindKeycode) == "EnumItem" and state.bindKeycode.EnumType == Enum.KeyCode and input.KeyCode == state.bindKeycode then
            state.clickToggleActive = not state.clickToggleActive
            SetAimbotState(state.clickToggleActive)
        elseif typeof(state.bindKeycode) == "EnumItem" and state.bindKeycode.EnumType == Enum.UserInputType and state.bindKeycode ~= Enum.UserInputType.MouseButton2 and input.UserInputType == state.bindKeycode then
            state.clickToggleActive = not state.clickToggleActive
            SetAimbotState(state.clickToggleActive)
        end
    end
end)

svc.UserInputService.InputEnded:Connect(function(input)
    if not state.isMobile and input.UserInputType == Enum.UserInputType.MouseButton2 and state.bindKeycode == Enum.UserInputType.MouseButton2 then
        if state.mousePressStart then
            state.mousePressStart = nil
            if state.mouseHoldActive then
                state.mouseHoldActive = false
                SetAimbotState(false)
            end
        end
    end
end)

-- Helper: 随机柔和颜色（HSV -> RGB）
local function randomFovColor()
    local h = math.random()
    local s = 0.6 + math.random() * 0.3
    local v = 0.85 + math.random() * 0.15
    local function hsv(h,s,v)
        local i = math.floor(h*6)
        local f = h*6 - i
        local p = v*(1 - s)
        local q = v*(1 - f*s)
        local t = v*(1 - (1 - f)*s)
        i = i % 6
        if i == 0 then return Color3.new(v,p,t) end
        if i == 1 then return Color3.new(q,v,t) end
        if i == 2 then return Color3.new(p,v,t) end
        if i == 3 then return Color3.new(p,q,v) end
        if i == 4 then return Color3.new(t,p,v) end
        return Color3.new(v,p,q)
    end
    return hsv(h,s,v)
end

-- 主循环：更新 FOV 圆、颜色、并执行瞄准逻辑
svc.RunService.RenderStepped:Connect(function(dt)
    local cam = svc.Workspace.CurrentCamera
    if cam and ui.FovCircle and ui.FovCircle.Parent and (isUIOpen or state.fovFollowMouseEnabled) then
        local radiusPx = computeFovRadiusPixels(state.fovValue)
        local r = math.floor(radiusPx + 0.5)
        if r < 6 then r = 6 end
        local maxR = math.floor(math.min(cam.ViewportSize.X, cam.ViewportSize.Y) / 2)
        if r > maxR then r = maxR end

        local centerVec
        if state.fovFollowMouseEnabled then
            local mouseLoc = svc.UserInputService:GetMouseLocation()
            centerVec = Vector2.new(mouseLoc.X, mouseLoc.Y)
        else
            centerVec = getScreenCenterForFov()
        end

        local clamped = clampVecToViewport(centerVec, r, cam.ViewportSize)
        ui.FovCircle.Size = UDim2.new(0, r*2, 0, r*2)
        ui.FovCircle.Position = UDim2.new(0, clamped.X, 0, clamped.Y)
    end

    if ui.FovStroke and state.fovColorRandomEnabled and state.showFov then
        local dist = math.abs(fovColorCurrent.R - fovColorTarget.R) + math.abs(fovColorCurrent.G - fovColorTarget.G) + math.abs(fovColorCurrent.B - fovColorTarget.B)
        if dist < 0.01 then
            fovColorTarget = randomFovColor()
        end
        fovColorCurrent = Color3.new(
            fovColorCurrent.R + (fovColorTarget.R - fovColorCurrent.R) * (fovColorTweenSpeed * (1 + dt*30)),
            fovColorCurrent.G + (fovColorTarget.G - fovColorCurrent.G) * (fovColorTweenSpeed * (1 + dt*30)),
            fovColorCurrent.B + (fovColorTarget.B - fovColorCurrent.B) * (fovColorTweenSpeed * (1 + dt*30))
        )
        ui.FovStroke.Color = fovColorCurrent
    end

    if not state.aimbotEnabled then return end

    if state.weaponOnlyEnabled and not playerHasAnythingInHand() then
        ui.targetLabel.Text = "未持任何物品，暂停瞄准"
        return
    end

    local localChar = ctx.LocalPlayer.Character
    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return end
    if not cam then cam = svc.Workspace.CurrentCamera end
    if not cam then return end
    local camPos = cam.CFrame.Position

    if state.lockedTarget and state.lockedTarget.part and state.lockedTarget.character then
        local hum = state.lockedTarget.character:FindFirstChild("Humanoid")
        local part = state.lockedTarget.part
        if not hum or hum.Health <= 0 or not (part and part:IsDescendantOf(state.lockedTarget.character)) then
            state.lockedTarget = getClosestToCrosshair()
            if state.lockedTarget then
                ui.targetLabel.Text = "锁定目标: "..(state.lockedTarget.player and state.lockedTarget.player.Name or "未知").." ("..(state.lockedTarget.part and state.lockedTarget.part.Name or "部位")..")"
            else
                ui.targetLabel.Text = "锁定目标: 无"
            end
            return
        end

        -- 新增：若开启护盾检测且当前锁定目标有护盾，则直接跳过/清除锁定
        if state.shieldCheckEnabled and characterHasShield(state.lockedTarget.character) then
            state.lockedTarget = nil
            ui.targetLabel.Text = "目标有护盾，跳过"
            return
        end

        if state.ignoreLowHpEnabled and hum and hum.Health <= state.ignoreHpThreshold then
            if state.mouseHoldActive then
                ui.targetLabel.Text = "目标低血量（保持锁定）"
                return
            else
                state.lockedTarget = nil
                ui.targetLabel.Text = "跳过低血量目标"
                return
            end
        end

        if state.wallCheckEnabled and raycastSkipPassable(camPos, part.Position, state.lockedTarget.character) then
            if state.mouseHoldActive then
                ui.targetLabel.Text = "目标被墙壁遮挡（保持锁定）"
                return
            else
                state.lockedTarget = nil
                ui.targetLabel.Text = "目标被墙壁遮挡"
                return
            end
        end

        local aimPart = part
        if state.randomOffsetEnabled and math.random(1, 100) <= state.randomOffsetProbability then
            local centerVec = state.fovFollowMouseEnabled and (function() local m = svc.UserInputService:GetMouseLocation(); return Vector2.new(m.X, m.Y) end)() or getScreenCenterForFov()
            local radiusPx = state.showFov and computeFovRadiusPixels(state.fovValue) or math.huge
            local alt = chooseRandomVisiblePart(state.lockedTarget.character, cam, centerVec, radiusPx, part)
            if alt then
                aimPart = alt
                ui.targetLabel.Text = "锁定目标: "..(state.lockedTarget.player and state.lockedTarget.player.Name or "未知").." ("..(part and part.Name or "部位").."->"..(alt and alt.Name or "部位")..")"
            end
        end

        local aimed = predictAndAim(cam, aimPart)
        if not aimed then
            if state.mouseHoldActive then
                ui.targetLabel.Text = "瞄准中（受阻）"
                return
            else
                state.lockedTarget = getClosestToCrosshair()
                ui.targetLabel.Text = state.lockedTarget and ("锁定目标: "..(state.lockedTarget.player and state.lockedTarget.player.Name or "未知").." ("..(state.lockedTarget.part and state.lockedTarget.part.Name or "部位")..")") or "锁定目标: 无"
                return
            end
        end
    else
        state.lockedTarget = getClosestToCrosshair()
        if state.lockedTarget then
            ui.targetLabel.Text = "锁定目标: "..(state.lockedTarget.player and state.lockedTarget.player.Name or "未知").." ("..(state.lockedTarget.part and state.lockedTarget.part.Name or "部位")..")"
        else
            ui.targetLabel.Text = "锁定目标: 无"
        end
    end
end)

-- 初始激活第一个 tab
if #tabs > 0 then
    tabs[1].Page.Visible = true
    activeTab = tabs[1]
    tabs[1].Button.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
    tabs[1].Button.TextColor3 = Color3.fromRGB(255, 255, 255)
end

-- Loader 动画（与之前版本保持）
task.spawn(function()
    local randomDuration = 5 + (math.random() * 5)
    local startTime = tick()
    while true do
        local elapsed = tick() - startTime
        local progress = math.clamp(elapsed / randomDuration, 0, 1)
        if ui.ProgressBarFill then
            ui.ProgressBarFill.Size = UDim2.new(progress, 0, 1, 0)
        end
        if progress < 0.3 then
            ui.LoaderStatus.Text = string.format("初始化核心环境... %d%%", math.floor(progress * 100))
        elseif progress < 0.7 then
            ui.LoaderStatus.Text = string.format("检测设备与配置资源... %d%%", math.floor(progress * 100))
        elseif progress < 0.95 then
            ui.LoaderStatus.Text = string.format("准备界面组件... %d%%", math.floor(progress * 100))
        else
            ui.LoaderStatus.Text = string.format("加载完成! %d%%", math.floor(progress * 100))
        end
        if progress >= 1 then break end
        task.wait()
    end
    local fadeTween = svc.TweenService:Create(ui.LoaderFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.55, 0),
        BackgroundTransparency = 1
    })
    if ui.LoaderStroke then svc.TweenService:Create(ui.LoaderStroke, TweenInfo.new(0.35), {Transparency = 1}):Play() end
    if ui.StaticLogo then svc.TweenService:Create(ui.StaticLogo, TweenInfo.new(0.35), {TextTransparency = 1}):Play() end
    if ui.LoaderStatus then svc.TweenService:Create(ui.LoaderStatus, TweenInfo.new(0.35), {TextTransparency = 1}):Play() end
    if ui.ProgressBarBG then svc.TweenService:Create(ui.ProgressBarBG, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play() end
    if ui.ProgressBarFill then svc.TweenService:Create(ui.ProgressBarFill, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play() end
    fadeTween:Play()
    fadeTween.Completed:Wait()
    pcall(function() ui.LoaderFrame:Destroy() end)
    ui.SideBarToggle.Visible = true
    svc.TweenService:Create(ui.StatusBar, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.05, 0),
        BackgroundTransparency = 0
    }):Play()
    svc.TweenService:Create(ui.StatusStroke, TweenInfo.new(0.6), {Transparency = 0.4}):Play()
    svc.TweenService:Create(ui.LogoLabel, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    svc.TweenService:Create(ui.Divider, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    svc.TweenService:Create(ui.InfoLabel, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    ToggleMainUI()
    createFovCircle()
end)
