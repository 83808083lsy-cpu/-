task.wait(2.6)

loadstring(game:HttpGet("https://raw.githubusercontent.com/83808083lsy-cpu/-/refs/heads/main/Fov.lua"))()

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CoreGui = game:GetService("CoreGui")

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- UI 配置
local UIConfig = {
    MainSize = isMobile and UDim2.new(0, 480, 0, 320) or UDim2.new(0, 640, 0, 420),
    OpenSize = isMobile and UDim2.new(0, 520, 0, 350) or UDim2.new(0, 680, 0, 450),
    SidebarSize = isMobile and UDim2.new(0, 110, 0, 32) or UDim2.new(0, 120, 0, 36),
    SidebarTextSize = isMobile and 13 or 14,
    TitleTextSize = isMobile and 15 or 16,
    TabBarWidth = isMobile and 120 or 150,
    HeaderHeight = isMobile and 42 or 50,
    ControlHeight = isMobile and 42 or 46,
    ButtonHeight = isMobile and 34 or 38,
    FontSize = isMobile and 14 or 14,
    DropdownOptionHeight = 28,
    DropdownMaxVisible = 6, -- 最多显示多少项，其余可滚动
}

-- GUI 父节点，优先 CoreGui
local TargetParent = PlayerGui
pcall(function()
    if CoreGui then
        TargetParent = CoreGui
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

local isSliderDragging = false -- 全局用于阻止拖拽窗口时与滑块冲突

-- 清理旧 GUI
if TargetParent:FindFirstChild("LinkCCFrameworkGUI") then
    TargetParent.LinkCCFrameworkGUI:Destroy()
end
if PlayerGui:FindFirstChild("LinkCCFrameworkGUI") then
    PlayerGui.LinkCCFrameworkGUI:Destroy()
end

-- 创建主 ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LinkCCFrameworkGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 2147483647
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

if getgenv then
    getgenv().LinkCCScreenGui = ScreenGui
end

pcall(function()
    ScreenGui.Parent = TargetParent
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = PlayerGui
end

-- 保证 ScreenGui 始终在正确父级和 DisplayOrder
RunService.RenderStepped:Connect(function()
    if ScreenGui then
        if ScreenGui.Parent ~= TargetParent and TargetParent then
            pcall(function() ScreenGui.Parent = TargetParent end)
        end
        if ScreenGui.DisplayOrder ~= 2147483647 then
            ScreenGui.DisplayOrder = 2147483647
        end
    end
end)

-- Loader UI（略过详细注释，保持原样）
local LoaderFrame = Instance.new("Frame")
LoaderFrame.Name = "LoaderFrame"
LoaderFrame.Size = isMobile and UDim2.new(0, 280, 0, 80) or UDim2.new(0, 320, 0, 85)
LoaderFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
LoaderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
LoaderFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
LoaderFrame.BorderSizePixel = 0
LoaderFrame.ZIndex = 100
LoaderFrame.Parent = ScreenGui

local LoaderCorner = Instance.new("UICorner")
LoaderCorner.CornerRadius = UDim.new(0, 14)
LoaderCorner.Parent = LoaderFrame

local LoaderStroke = Instance.new("UIStroke")
LoaderStroke.Thickness = 1
LoaderStroke.Color = Color3.fromRGB(255, 105, 180)
LoaderStroke.Transparency = 0.4
LoaderStroke.Parent = LoaderFrame

local StaticLogo = Instance.new("TextLabel")
StaticLogo.Name = "StaticLogo"
StaticLogo.AutomaticSize = Enum.AutomaticSize.X
StaticLogo.Size = UDim2.new(0, 0, 0, 20)
StaticLogo.Position = UDim2.new(0, 16, 0, 12)
StaticLogo.BackgroundTransparency = 1
StaticLogo.Text = "Link.cc"
StaticLogo.TextColor3 = Color3.fromRGB(255, 105, 180)
StaticLogo.Font = Enum.Font.GothamBold
StaticLogo.TextSize = UIConfig.FontSize + 2
StaticLogo.TextXAlignment = Enum.TextXAlignment.Left
StaticLogo.ZIndex = 101
StaticLogo.Parent = LoaderFrame

local LoaderStatus = Instance.new("TextLabel")
LoaderStatus.Size = UDim2.new(1, -32, 0, 16)
LoaderStatus.Position = UDim2.new(0, 16, 0, 34)
LoaderStatus.BackgroundTransparency = 1
LoaderStatus.Text = "初始化组件... 0%"
LoaderStatus.TextColor3 = Color3.fromRGB(160, 160, 165)
LoaderStatus.Font = Enum.Font.Gotham
LoaderStatus.TextSize = UIConfig.FontSize - 2
LoaderStatus.TextXAlignment = Enum.TextXAlignment.Left
LoaderStatus.ZIndex = 101
LoaderStatus.Parent = LoaderFrame

local ProgressBarBG = Instance.new("Frame")
ProgressBarBG.Size = UDim2.new(1, -32, 0, 5)
ProgressBarBG.Position = UDim2.new(0, 16, 1, -14)
ProgressBarBG.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
ProgressBarBG.BorderSizePixel = 0
ProgressBarBG.ZIndex = 101
ProgressBarBG.Parent = LoaderFrame

local ProgressBarBGCorner = Instance.new("UICorner")
ProgressBarBGCorner.CornerRadius = UDim.new(1, 0)
ProgressBarBGCorner.Parent = ProgressBarBG

local ProgressBarFill = Instance.new("Frame")
ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
ProgressBarFill.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
ProgressBarFill.BorderSizePixel = 0
ProgressBarFill.ZIndex = 102
ProgressBarFill.Parent = ProgressBarBG

local ProgressBarFillCorner = Instance.new("UICorner")
ProgressBarFillCorner.CornerRadius = UDim.new(1, 0)
ProgressBarFillCorner.Parent = ProgressBarFill

-- 可拖拽函数（防止与滑块拖拽冲突）
local function EnableHeaderDragging(headerFrame, targetFrame)
    local dragging = false
    local dragInput, dragStart, startPos

    headerFrame.InputBegan:Connect(function(input)
        if isSliderDragging then return end

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

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and not isSliderDragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- 状态栏（ping/fps）
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.AutomaticSize = Enum.AutomaticSize.X
StatusBar.Size = UDim2.new(0, 0, 0, isMobile and 28 or 32)
StatusBar.Position = UDim2.new(0.5, 0, 0, -40)
StatusBar.AnchorPoint = Vector2.new(0.5, 0)
StatusBar.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
StatusBar.BorderSizePixel = 0
StatusBar.Active = true
StatusBar.BackgroundTransparency = 1
StatusBar.ZIndex = 50
StatusBar.Parent = ScreenGui

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 8)
StatusCorner.Parent = StatusBar

local StatusStroke = Instance.new("UIStroke")
StatusStroke.Thickness = 1
StatusStroke.Color = Color3.fromRGB(60, 60, 65)
StatusStroke.Transparency = 1
StatusStroke.Parent = StatusBar

EnableHeaderDragging(StatusBar, StatusBar)

local StatusListLayout = Instance.new("UIListLayout")
StatusListLayout.FillDirection = Enum.FillDirection.Horizontal
StatusListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
StatusListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
StatusListLayout.SortOrder = Enum.SortOrder.LayoutOrder
StatusListLayout.Padding = UDim.new(0, 6)
StatusListLayout.Parent = StatusBar

local StatusPadding = Instance.new("UIPadding")
StatusPadding.PaddingLeft = UDim.new(0, 10)
StatusPadding.PaddingRight = UDim.new(0, 10)
StatusPadding.Parent = StatusBar

local LogoLabel = Instance.new("TextLabel")
LogoLabel.Name = "1_Logo"
LogoLabel.AutomaticSize = Enum.AutomaticSize.X
LogoLabel.Size = UDim2.new(0, 0, 1, 0)
LogoLabel.BackgroundTransparency = 1
LogoLabel.Text = "Link.cc"
LogoLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
LogoLabel.TextTransparency = 1
LogoLabel.TextXAlignment = Enum.TextXAlignment.Left
LogoLabel.Font = Enum.Font.GothamBold
LogoLabel.TextSize = UIConfig.FontSize
LogoLabel.LayoutOrder = 1
LogoLabel.ZIndex = 51
LogoLabel.Parent = StatusBar

local Divider = Instance.new("TextLabel")
Divider.Name = "2_Divider"
Divider.AutomaticSize = Enum.AutomaticSize.X
Divider.Size = UDim2.new(0, 0, 1, 0)
Divider.BackgroundTransparency = 1
Divider.Text = "|"
Divider.TextColor3 = Color3.fromRGB(80, 80, 85)
Divider.TextTransparency = 1
Divider.Font = Enum.Font.Gotham
Divider.TextSize = UIConfig.FontSize - 1
Divider.LayoutOrder = 2
Divider.ZIndex = 51
Divider.Parent = StatusBar

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Name = "3_Info"
InfoLabel.AutomaticSize = Enum.AutomaticSize.X
InfoLabel.Size = UDim2.new(0, 0, 1, 0)
InfoLabel.BackgroundTransparency = 1
InfoLabel.RichText = true
InfoLabel.Text = "0ms 0FPS"
InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
InfoLabel.TextTransparency = 1
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Font = Enum.Font.GothamMedium
InfoLabel.TextSize = UIConfig.FontSize - 1
InfoLabel.LayoutOrder = 3
InfoLabel.ZIndex = 51
InfoLabel.Parent = StatusBar

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

local frameCount, lastCheck, currentFps = 0, tick(), 60
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    if now - lastCheck >= 0.25 then
        currentFps = math.floor(frameCount / (now - lastCheck))
        frameCount = 0
        lastCheck = now
    end
    local success, pingVal = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    local ping = success and math.floor(tonumber(pingVal) or 0) or 0
    InfoLabel.Text = string.format("<font color=\"#%s\">%dms</font>  <font color=\"#%s\">%dFPS</font>",
        Color3ToHex(GetPingColor(ping)), ping, Color3ToHex(GetFpsColor(currentFps)), currentFps)
end)

-- Sidebar + 主面板（UI 构造省略注释，保留实现，和之前版本一致）
local SideBarToggle = Instance.new("TextButton")
SideBarToggle.Name = "SideBarToggle"
SideBarToggle.Size = UIConfig.SidebarSize
SideBarToggle.Position = UDim2.new(0, 10, 0.5, 0)
SideBarToggle.AnchorPoint = Vector2.new(0, 0.5)
SideBarToggle.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
SideBarToggle.Text = isMobile and " Link.cc" or " Link.cc"
SideBarToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SideBarToggle.Font = Enum.Font.GothamBold
SideBarToggle.TextSize = UIConfig.SidebarTextSize
SideBarToggle.AutoButtonColor = false
SideBarToggle.Active = true
SideBarToggle.Visible = false
SideBarToggle.ZIndex = 50
SideBarToggle.Parent = ScreenGui

local SideBarCorner = Instance.new("UICorner")
SideBarCorner.CornerRadius = UDim.new(0, 8)
SideBarCorner.Parent = SideBarToggle

local SideBarStroke = Instance.new("UIStroke")
SideBarStroke.Thickness = 1
SideBarStroke.Color = Color3.fromRGB(255, 105, 180)
SideBarStroke.Parent = SideBarToggle

EnableHeaderDragging(SideBarToggle, SideBarToggle)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UIConfig.MainSize
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.Visible = false
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui

local MainUICorner = Instance.new("UICorner")
MainUICorner.CornerRadius = UDim.new(0, 14)
MainUICorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1
MainStroke.Color = Color3.fromRGB(60, 60, 65)
MainStroke.Transparency = 1
MainStroke.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, UIConfig.HeaderHeight)
Header.BackgroundTransparency = 1
Header.Active = true
Header.ZIndex = 11
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Link.cc"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = UIConfig.TitleTextSize
Title.ZIndex = 12
Title.Parent = Header

EnableHeaderDragging(Header, MainFrame)

local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(0, UIConfig.TabBarWidth, 1, -(UIConfig.HeaderHeight + 10))
TabBar.Position = UDim2.new(0, 10, 0, UIConfig.HeaderHeight)
TabBar.BackgroundTransparency = 1
TabBar.ScrollBarThickness = 0
TabBar.ScrollBarImageTransparency = 1
TabBar.ScrollingDirection = Enum.ScrollingDirection.Y
TabBar.HorizontalScrollBarInset = Enum.ScrollBarInset.None
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.ZIndex = 11
TabBar.Parent = MainFrame

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Padding = UDim.new(0, 6)
TabListLayout.Parent = TabBar

local function UpdateTabBarScrolling()
    local contentHeight = TabListLayout.AbsoluteContentSize.Y
    local visibleHeight = TabBar.AbsoluteSize.Y
    if contentHeight > visibleHeight then
        TabBar.ScrollingEnabled = true
        TabBar.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 10)
    else
        TabBar.ScrollingEnabled = false
        TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    end
end

TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabBarScrolling)
TabBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabBarScrolling)

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -(UIConfig.TabBarWidth + 25), 1, -(UIConfig.HeaderHeight + 10))
ContentContainer.Position = UDim2.new(0, UIConfig.TabBarWidth + 18, 0, UIConfig.HeaderHeight)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ZIndex = 11
ContentContainer.Parent = MainFrame

local tabs = {}
local activeTab = nil

-- PlayFeedbackAnimation、CreateTab、AddButton、AddToggle、AddSlider、AddDropdown 等函数沿用之前实现（UI 构建）
-- 为简洁性保留实现但省略重复注释（逻辑与上一个版本一致）
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
                TweenService:Create(item, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = origPos,
                    BackgroundTransparency = 0
                }):Play()
                for _, child in ipairs(item:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        TweenService:Create(child, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
                    elseif child:IsA("TextButton") then
                        TweenService:Create(child, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
                    elseif child:IsA("ImageButton") then
                        TweenService:Create(child, TweenInfo.new(0.35), {ImageTransparency = 0}):Play()
                    elseif child:IsA("Frame") and child.Name ~= "Hitbox" and child.Name ~= "DropdownList" then
                        TweenService:Create(child, TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
                    end
                end
            end)
        end
    end
end

local function ResetAllScrollPositions()
    TabBar.CanvasPosition = Vector2.new(0, 0)
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
    TweenService:Create(SideBarToggle, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = smallSize}):Play()
    task.delay(0.1, function()
        TweenService:Create(SideBarToggle, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UIConfig.SidebarSize}):Play()
    end)
    if isUIOpen then
        ResetAllScrollPositions()
        MainFrame.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UIConfig.OpenSize,
            BackgroundTransparency = 0
        }):Play()
        TweenService:Create(MainStroke, TweenInfo.new(0.35), {Transparency = 0.5}):Play()
        TweenService:Create(Title, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
        if activeTab then
            PlayFeedbackAnimation(activeTab.Page)
        end
    else
        local tween = TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UIConfig.MainSize,
            BackgroundTransparency = 1
        })
        TweenService:Create(MainStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
        TweenService:Create(Title, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
        tween:Play()
        tween.Completed:Connect(function()
            if not isUIOpen then
                MainFrame.Visible = false
                ResetAllScrollPositions()
            end
        end)
    end
end

SideBarToggle.MouseButton1Click:Connect(ToggleMainUI)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        ToggleMainUI()
    end
end)

-- CreateTab 与 Add* 方法：完整实现和之前版本一致，为节省篇幅此处直接实现（不省略）
local function CreateTab(tabName)
    local tabButton = Instance.new("TextButton")
    tabButton.Size = UDim2.new(1, -6, 0, isMobile and 36 or 40)
    tabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(160, 160, 165)
    tabButton.Font = Enum.Font.GothamMedium
    tabButton.TextSize = UIConfig.FontSize
    tabButton.AutoButtonColor = false
    tabButton.ZIndex = 12
    tabButton.Parent = TabBar

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
    pageFrame.Parent = ContentContainer

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
        for _, tab in pairs(tabs) do
            tab.Page.Visible = false
            tab.Page.CanvasPosition = Vector2.new(0, 0)
            TweenService:Create(tab.Button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(35, 35, 40),
                TextColor3 = Color3.fromRGB(160, 160, 165)
            }):Play()
        end
        pageFrame.CanvasPosition = Vector2.new(0, 0)
        pageFrame.Visible = true
        activeTab = tabObj
        UpdateScrollingState()
        TweenService:Create(tabButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(255, 105, 180),
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        PlayFeedbackAnimation(pageFrame)
    end

    tabButton.MouseButton1Click:Connect(selectTab)

    -- AddButton
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
            TweenService:Create(btnItem, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(48, 48, 55)
            }):Play()
            task.delay(0.12, function()
                TweenService:Create(btnItem, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Color3.fromRGB(32, 32, 36)
                }):Play()
            end)
            if callback then pcall(callback, btnItem, label) end
        end)
        return btnItem, label
    end

    -- AddToggle
    function tabObj:AddToggle(text, defaultState, callback)
        local state = defaultState or false
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

        local trackWidth = isMobile and 36 or 40
        local trackHeight = isMobile and 18 or 20
        local switchTrack = Instance.new("TextButton")
        switchTrack.Name = "SwitchTrack"
        switchTrack.Size = UDim2.new(0, trackWidth, 0, trackHeight)
        switchTrack.Position = UDim2.new(1, -(trackWidth + 12), 0.5, -trackHeight / 2)
        switchTrack.BackgroundColor3 = state and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(70, 70, 75)
        switchTrack:SetAttribute("State", state)
        switchTrack.Text = ""
        switchTrack.AutoButtonColor = false
        switchTrack.ZIndex = 14
        switchTrack.Parent = toggleFrame

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = switchTrack

        local thumbSize = isMobile and 14 or 16
        local switchThumb = Instance.new("Frame")
        switchThumb.Size = UDim2.new(0, thumbSize, 0, thumbSize)
        switchThumb.Position = state and UDim2.new(1, -(thumbSize + 2), 0.5, -thumbSize/2) or UDim2.new(0, 2, 0.5, -thumbSize/2)
        switchThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        switchThumb.ZIndex = 15
        switchThumb.Parent = switchTrack

        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(1, 0)
        thumbCorner.Parent = switchThumb

        switchTrack.MouseButton1Click:Connect(function()
            state = not state
            switchTrack:SetAttribute("State", state)
            local targetTrackColor = state and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(70, 70, 75)
            local targetThumbPos = state and UDim2.new(1, -(thumbSize + 2), 0.5, -thumbSize/2) or UDim2.new(0, 2, 0.5, -thumbSize/2)
            TweenService:Create(switchTrack, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = targetTrackColor}):Play()
            TweenService:Create(switchThumb, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetThumbPos}):Play()
            if callback then pcall(callback, state, switchTrack, switchThumb, toggleFrame, label) end
        end)
        return switchTrack, switchThumb, toggleFrame, label
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
                isSliderDragging = true
                local absX = (input.Position and input.Position.X) or UserInputService:GetMouseLocation().X
                updateInputByPos(absX)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local absX = (input.Position and input.Position.X) or UserInputService:GetMouseLocation().X
                updateInputByPos(absX)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragging then
                dragging = false
                isSliderDragging = false
            end
        end)

        -- Set initial label text using precise formatting
        do
            local rawValue = min + (range * startRatio)
            local value = formatValueByRange(rawValue)
            label.Text = text .. " : " .. tostring(value)
        end

        return sliderFrame, label, track, fill, handle, hitBox
    end

    -- AddDropdown（保留之前丰富实现）
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

        -- Background container matching source UI style for dropdown items
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

        -- ScrollingFrame for options
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

        -- helper to compute heights & open/close with animation
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

            local tween = TweenService:Create(dropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -10, 0, targetFrameHeight)
            })
            tween:Play()

            local bgTween = TweenService:Create(listBg, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -24, 0, targetListHeight + 8)
            })
            bgTween:Play()

            task.delay(0.06, function()
                UpdateListCanvas()
                local children = listContainer:GetChildren()
                local index = 0
                for _, child in ipairs(children) do
                    if child:IsA("TextButton") then
                        index = index + 1
                        child.Visible = true
                        child.BackgroundTransparency = 1
                        child.TextTransparency = 1
                        child.Position = UDim2.new(0, 0, 0, (index - 1) * (UIConfig.DropdownOptionHeight + 4) + 0)
                        task.delay(index * 0.03, function()
                            TweenService:Create(child, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                BackgroundTransparency = 0
                            }):Play()
                            TweenService:Create(child, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
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
                    TweenService:Create(child, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        BackgroundTransparency = 1
                    }):Play()
                    TweenService:Create(child, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                    task.delay(0.15, function()
                        child.Visible = false
                    end)
                end)
            end

            local tween = TweenService:Create(listBg, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, -24, 0, 0)
            })
            tween:Play()
            local frameTween = TweenService:Create(dropdownFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
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

        return dropdownFrame, titleLabel, listContainer
    end

    table.insert(tabs, tabObj)
    return tabObj
end

-- Create tabs
local AimbotTab = CreateTab("Aimbot")
local SettingsTab = CreateTab("设置")

-- Aimbot tab 基本 UI
local bindStatusLabel = Instance.new("TextLabel")
bindStatusLabel.Size = UDim2.new(1, -10, 0, 20)
bindStatusLabel.BackgroundTransparency = 1
bindStatusLabel.Text = "当前绑定: 鼠标右键"
bindStatusLabel.TextColor3 = Color3.fromRGB(240,240,240)
bindStatusLabel.Font = Enum.Font.Gotham
bindStatusLabel.TextSize = UIConfig.FontSize
bindStatusLabel.ZIndex = 14
bindStatusLabel.Parent = AimbotTab.Page

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, -10, 0, 20)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "锁定目标: 无"
targetLabel.TextColor3 = Color3.fromRGB(200,200,200)
targetLabel.Font = Enum.Font.Gotham
targetLabel.TextSize = UIConfig.FontSize - 1
targetLabel.ZIndex = 14
targetLabel.Parent = AimbotTab.Page

-- 状态变量
local aimbotEnabled = false
local bindKeycode = Enum.UserInputType.MouseButton2
local waitingForKey = false
local smoothFactor = 0 -- 0..1, 0 instant, 1 max smoothing (慢)
local lockedTarget = nil
local mousePressStart = nil
local mouseHoldActive = false
local clickToggleActive = false
local clickThreshold = 0.01
local wallCheckEnabled = false
local leadEnabled = false
local bulletSpeed = 1500
local fovValue = 50
local maxAimDistance = 500
-- 瞄准部位多选（表 keyed by name => true）
local aimPartChoices = {}
-- 保留身体默认选中
aimPartChoices["身体"] = true
local aimMode = "原文"

-- 新功能选项
local whitelist = {} -- keyed by UserId => true

local ignoreLowHpEnabled = false
local ignoreHpThreshold = 0 -- 0..100

local fovColorRandomEnabled = false
local showFov = true

local adaptiveLeadEnabled = false
local adaptiveLeadSensitivity = 0.5 -- 0..1

-- 只在手上有东西时瞄准（按用户要求）
local weaponOnlyEnabled = false

-- 预测缓存（弱键，避免内存泄漏）
local lastPredictions = setmetatable({}, { __mode = "k" })
local lastPositions = setmetatable({}, { __mode = "k" }) -- 用于加强预测（位置+时间）

-- 新增功能变量：FOV 跟随鼠标、随机偏移与概率
local fovFollowMouseEnabled = false
local randomOffsetEnabled = false
local randomOffsetProbability = 50 -- 0..100 默认 50

-- 新增：优先锁定最近目标开关（UI）
local prioritizeNearest = false

local function updateBindDisplay(inp)
    local txt = "未知"
    if typeof(inp) == "EnumItem" and inp.Name then
        txt = inp.Name
    elseif type(inp) == "string" then
        txt = inp
    else
        txt = tostring(inp)
    end
    bindStatusLabel.Text = "当前绑定: " .. txt
end

-- 修复：raycast 跳过不碰撞/半透明物体时的循环逻辑（避免使用 Lua 中不稳定的 continue）
-- 说明：旧版本使用了 continue，Luau 在某些版本不支持或会不一致。这里用 while/for 控制逻辑明确推进 origin。
local function raycastSkipPassable(fromPos, toPos, ignoreModel)
    if not fromPos or not toPos then return false end
    local dir = toPos - fromPos
    local distTotal = dir.Magnitude
    if distTotal <= 0 then return false end
    local dirUnit = dir.Unit
    local origin = fromPos
    local remaining = distTotal
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, Workspace.CurrentCamera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local maxIterations = 8
    for i = 1, maxIterations do
        local result = Workspace:Raycast(origin, dirUnit * remaining, params)
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
    local cam = Workspace.CurrentCamera
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
    local cam = Workspace.CurrentCamera
    if not cam then return Vector2.new(0,0) end
    return Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
end

-- isPartVisibleWithPenetration：用于判断部位是否可见（允许穿透一些透明/不可碰撞物）
local function isPartVisibleWithPenetration(part, cam, ignoreModel)
    if not part or not part:IsA("BasePart") then return false end
    local origin = cam.CFrame.Position
    local dir = part.Position - origin
    local distTotal = dir.Magnitude
    if distTotal <= 0 then return true end
    local dirUnit = dir.Unit
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, Workspace.CurrentCamera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local originPos = origin
    local remaining = distTotal
    local maxIter = 8
    for i = 1, maxIter do
        local result = Workspace:Raycast(originPos, dirUnit * remaining, params)
        if not result then
            return true
        end
        local inst = result.Instance
        if inst and ignoreModel and inst:IsDescendantOf(ignoreModel) then
            return true
        end
        if inst and inst:IsA("BasePart") then
            local transparency = inst.Transparency or 0
            local canCollide = inst.CanCollide
            if inst:IsDescendantOf(part.Parent) then
                return true
            end
            if (transparency >= 0.6) or (canCollide == false) then
                local hitPos = result.Position
                local hitDist = (hitPos - origin).Magnitude
                if hitDist >= distTotal - 0.01 then
                    return true
                end
                originPos = origin + dirUnit * (hitDist + 0.01)
                remaining = (part.Position - originPos).Magnitude
                if remaining <= 0 then
                    return true
                end
                -- continue loop
            else
                return false
            end
        else
            return false
        end
    end
    return false
end

-- 部位映射：保留身体并新增 头、左右手、左右腿 等选项
local chestNames = { "UpperTorso", "Torso", "HumanoidRootPart", "Chest" }

local aimOptionsMapping = {
    ["身体"] = chestNames,
    ["头"] = {"Head"},
    ["左手"] = {"LeftHand"},
    ["右手"] = {"RightHand"},
    ["左腿"] = {"LeftUpperLeg","LeftLowerLeg","LeftFoot"},
    ["右腿"] = {"RightUpperLeg","RightLowerLeg","RightFoot"},
}

-- findBestVisiblePart：优先尝试已选部位（如果已选部位中有“露出/可见”的，则直接返回）
-- 如果已选部位都不可见，则根据选中的偏好继续搜索匹配部位；最终回退到任意可见部位
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

    -- 1) 尝试直接瞄准已选部位（若选项中某个部位“露出/可见”，直接返回该部位）
    for _, list in ipairs(lists) do
        local p, d = checkList(list)
        if p then
            return p, d
        end
    end

    -- 2) 如果没有已选部位可见，用优先级映射的默认顺序查找（默认先身体）
    local fallbackLists = { chestNames, {"Head"}, {"LeftHand","RightHand"}, {"LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot"} }
    for _, list in ipairs(fallbackLists) do
        local p, d = checkList(list)
        if p then
            return p, d
        end
    end

    -- 3) 最后回退：任何可见部位（距离中心最近）
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

-- getClosestToCrosshair：遍历玩家并使用 findBestVisiblePart 选取最佳目标
local function getClosestToCrosshair()
    local cam = Workspace.CurrentCamera
    local localChar = LocalPlayer.Character
    if not cam or not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return nil end

    -- 使用是否跟随鼠标决定 centerVec
    local centerVec
    if fovFollowMouseEnabled then
        local mouseLoc = UserInputService:GetMouseLocation()
        centerVec = Vector2.new(mouseLoc.X, mouseLoc.Y)
    else
        centerVec = getScreenCenterForFov()
    end

    local radiusPx
    if showFov then
        radiusPx = computeFovRadiusPixels(fovValue)
    else
        radiusPx = math.huge -- 全屏
    end

    local best = nil
    local bestMetric = math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if whitelist[plr.UserId] then
                -- 若白名单中存在则跳过（白名单含义：不瞄准）
            else
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        if ignoreLowHpEnabled and hum.Health <= ignoreHpThreshold then
                            -- 跳过低血量目标
                        else
                            local part, dist = findBestVisiblePart(char, cam, centerVec, radiusPx, aimPartChoices)
                            if part and dist then
                                local worldDist = (part.Position - cam.CFrame.Position).Magnitude
                                local metric
                                if prioritizeNearest then
                                    metric = worldDist
                                else
                                    metric = dist
                                end
                                if worldDist <= maxAimDistance and metric < bestMetric then
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
    return best
end

-- 求解拦截时间（相对运动方程），返回 t (秒) 或 nil
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

-- 检查玩家手上是否有任何 Tool（“只要手上有东西就瞄准”的实现）
local function playerHasAnythingInHand()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            return true
        end
    end
    return false
end

-- Enhanced prediction：根据子弹速度、敌人速度与帧间观测速度计算预测位置（更准确）
local function predictPositionForPart(part, origin)
    if not part or not part:IsA("BasePart") then return part and part.Position or nil end

    local currentPos = part.Position
    local vel = part.Velocity or Vector3.new(0,0,0)

    -- 观测上一帧/上一次位置用于估算真实速度
    local now = tick()
    local last = lastPositions[part]
    local observedVel = vel
    if last and last.pos and last.t then
        local dt = now - last.t
        if dt > 1e-4 then
            local obs = (currentPos - last.pos) / dt
            observedVel = obs
        end
    end
    -- 加权平均：兼顾物理引擎 velocity 与观测速度，降低瞬时噪声影响
    local estimatedVel = vel * 0.6 + observedVel * 0.4

    -- 存储当前位置信息用于下次观测
    lastPositions[part] = { pos = currentPos, t = now }

    local predicted = currentPos

    if leadEnabled then
        local t = solveInterceptTime(origin, currentPos, estimatedVel, bulletSpeed)
        -- baseLeadBlend: 平滑度越小（即时），lead 越多；平滑度越大（慢）则减少 lead
        local baseLeadBlend = math.clamp(1 - smoothFactor, 0, 1)

        -- fovFactor: FOV 越大（视野广），可能会导致 overshoot，适当降低先导
        local fovFactor = math.clamp(fovValue / 180, 0, 1)

        local leadBlend = baseLeadBlend
        if adaptiveLeadEnabled then
            -- 自适应：根据 FOV 与自适应灵敏度减少 lead
            local reduction = adaptiveLeadSensitivity * fovFactor
            leadBlend = leadBlend * (1 - reduction)
        end
        leadBlend = math.clamp(leadBlend, 0, 1)

        if t and t > 0 then
            predicted = currentPos + estimatedVel * t * leadBlend
        else
            -- 后备：基于距离估计时间
            local toTarget = currentPos - origin
            local dist = toTarget.Magnitude
            if dist <= 0 then
                predicted = currentPos
            else
                local timeEstimate = dist / math.max(1, bulletSpeed)
                predicted = currentPos + estimatedVel * timeEstimate * leadBlend
            end
        end
    else
        predicted = currentPos
    end

    -- 帧间平滑：减少抖动（smoothFactor 越大，越平滑）
    local prev = lastPredictions[part]
    if prev then
        local smoothW = math.clamp(smoothFactor, 0, 1)
        predicted = prev:Lerp(predicted, 1 - smoothW)
    end

    lastPredictions[part] = predicted
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
local function SetAimbotState(state)
    aimbotEnabled = state
    if aimbotSwitch and aimbotSwitch.SetAttribute then
        aimbotSwitch:SetAttribute("State", state)
        aimbotSwitch.BackgroundColor3 = state and Color3.fromRGB(52,199,89) or Color3.fromRGB(70,70,75)
        local thumb = aimbotSwitch:FindFirstChildWhichIsA("Frame")
        if thumb then
            if state then
                thumb.Position = UDim2.new(1, -18, 0.5, -8)
            else
                thumb.Position = UDim2.new(0, 2, 0.5, -8)
            end
        end
    end
    if state then
        lockedTarget = getClosestToCrosshair()
        if lockedTarget then
            targetLabel.Text = "锁定目标: "..(lockedTarget.player and lockedTarget.player.Name or "未知").." ("..(lockedTarget.part and lockedTarget.part.Name or "部位")..")"
        else
            targetLabel.Text = "锁定目标: 无"
        end
    else
        lockedTarget = nil
        targetLabel.Text = "锁定目标: 无"
    end
end

-- predictAndAim：主瞄准函数，使用 predictPositionForPart，并支持 adaptiveLead 调整瞬时平滑
local function predictAndAim(cam, part)
    if not cam or not part then return false end
    local aimPos = part.Position
    if leadEnabled then
        local predicted = predictPositionForPart(part, cam.CFrame.Position)
        if predicted then aimPos = predicted end
    end
    local screenPos = cam:WorldToViewportPoint(aimPos)
    if screenPos.Z <= 0 then
        return false
    end
    local screenVec = Vector2.new(screenPos.X, screenPos.Y)

    -- 依据是否跟随鼠标决定 centerVec
    local centerVec
    if fovFollowMouseEnabled then
        local mouseLoc = UserInputService:GetMouseLocation()
        centerVec = Vector2.new(mouseLoc.X, mouseLoc.Y)
    else
        centerVec = getScreenCenterForFov()
    end

    local radiusPx = showFov and computeFovRadiusPixels(fovValue) or math.huge
    local dist = (screenVec - centerVec).Magnitude
    if dist > radiusPx then
        return false
    end

    local targetCf = CFrame.new(cam.CFrame.Position, aimPos)

    -- 自适应平滑：在 adaptiveLeadEnabled 时，如果预测偏移较大且 FOV 大，则降低平滑值使瞄准更迅速
    local smoothLocal = smoothFactor
    if adaptiveLeadEnabled then
        local predictedOffset = (aimPos - part.Position).Magnitude
        local fovFactor = math.clamp(fovValue / 180, 0, 1)
        local leadScale = math.clamp(predictedOffset / 20, 0, 1) -- 20 为经验常数，可调
        local reduce = adaptiveLeadSensitivity * fovFactor * leadScale
        smoothLocal = math.clamp(smoothFactor - reduce, 0, 1)
    end

    local lerpAlpha = math.clamp(1 - smoothLocal, 0.02, 1)
    if smoothLocal <= 0 then
        cam.CFrame = targetCf
    else
        cam.CFrame = cam.CFrame:Lerp(targetCf, lerpAlpha)
    end
    return true
end

-- FOV 可视圆与颜色动画
local FovCircle = nil
local FovStroke = nil
local fovColorTarget = Color3.fromRGB(255,182,193)
local fovColorCurrent = Color3.fromRGB(255,182,193)
local fovColorTweenSpeed = 0.01 -- 每帧线性插值步长

local function createFovCircle()
    if FovCircle and FovCircle.Parent then return end
    FovCircle = Instance.new("Frame")
    FovCircle.Name = "FovCircle"
    FovCircle.AnchorPoint = Vector2.new(0.5,0.5)
    FovCircle.Size = UDim2.new(0, 100, 0, 100)
    FovCircle.BackgroundTransparency = 1
    FovCircle.ZIndex = 200
    FovCircle.Parent = ScreenGui

    FovStroke = Instance.new("UIStroke")
    FovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FovStroke.Thickness = 2
    FovStroke.Color = fovColorCurrent
    FovStroke.Transparency = 0.25
    FovStroke.Parent = FovCircle

    local FovCorner = Instance.new("UICorner")
    FovCorner.CornerRadius = UDim.new(0.5, 0)
    FovCorner.Parent = FovCircle
end

-- Aimbot 控件（UI）
local aimbotSwitch, aimbotThumb, aimbotFrame, aimbotLabel = AimbotTab:AddToggle("Aimbot 开启", false, function(state)
    SetAimbotState(state)
end)

local wallSwitch, wallThumb = AimbotTab:AddToggle("墙壁检测", false, function(state)
    wallCheckEnabled = state
end)

local leadSwitch, leadThumb = AimbotTab:AddToggle("提前瞄准", false, function(state)
    leadEnabled = state
end)

local bindBtn, bindBtnLabel = AimbotTab:AddButton("点击设置快捷键", function(btn, label)
    if waitingForKey then return end
    waitingForKey = true
    if label and label.Text then label.Text = "请按下绑定按键..." end
    bindStatusLabel.Text = "等待输入按键"
end)

-- 白名单控件（与之前版本相同）
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
    listBg.Parent = frame

    local listBgCorner = Instance.new("UICorner")
    listBgCorner.CornerRadius = UDim.new(0, 8)
    listBgCorner.Parent = listBg

    local listBgStroke = Instance.new("UIStroke")
    listBgStroke.Thickness = 1
    listBgStroke.Color = Color3.fromRGB(60, 60, 65)
    listBgStroke.Transparency = 0.75
    listBgStroke.Parent = listBg

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
        local players = Players:GetPlayers()
        for i, plr in ipairs(players) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, UIConfig.DropdownOptionHeight)
            btn.BackgroundColor3 = whitelist[plr.UserId] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
            btn.Text = "  "..plr.Name
            btn.TextColor3 = whitelist[plr.UserId] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = UIConfig.FontSize - 1
            btn.AutoButtonColor = false
            btn.ZIndex = 15
            btn.Visible = false
            btn.Parent = listContainer

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 6)
            optCorner.Parent = btn

            btn.MouseButton1Click:Connect(function()
                local uid = plr.UserId
                if whitelist[uid] then
                    whitelist[uid] = nil
                else
                    whitelist[uid] = true
                end
                btn.BackgroundColor3 = whitelist[uid] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
                btn.TextColor3 = whitelist[uid] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)

                local count = 0
                local firstName
                for _,p in ipairs(Players:GetPlayers()) do
                    if whitelist[p.UserId] then
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
                            TweenService:Create(c, TweenInfo.new(0.18), {BackgroundTransparency = 0}):Play()
                            TweenService:Create(c, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
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
        local playersCount = #Players:GetPlayers()
        local visibleCount = math.min(playersCount, UIConfig.DropdownMaxVisible)
        local targetListHeight = visibleCount * UIConfig.DropdownOptionHeight + (math.max(0, visibleCount - 1) * listLayout.Padding.Offset)
        local targetFrameHeight = UIConfig.ControlHeight + 6 + targetListHeight
        TweenService:Create(frame, TweenInfo.new(0.25), {Size = UDim2.new(1, -10, 0, targetFrameHeight)}):Play()
        TweenService:Create(listBg, TweenInfo.new(0.25), {Size = UDim2.new(1, -24, 0, targetListHeight + 8)}):Play()
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
                TweenService:Create(c, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                TweenService:Create(c, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                task.delay(0.15, function() c.Visible = false end)
            end)
        end
        TweenService:Create(listBg, TweenInfo.new(0.22), {Size = UDim2.new(1, -24, 0, 0)}):Play()
        TweenService:Create(frame, TweenInfo.new(0.22), {Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)}):Play()
        task.delay(0.22, function()
            listBg.Visible = false
            listContainer.Visible = false
            UpdateTabBarScrolling()
        end)
    end

    expandBtn.MouseButton1Click:Connect(function()
        if isExpanded then Close() else Open() end
    end)

    Players.PlayerAdded:Connect(function() RefreshListVisual() end)
    Players.PlayerRemoving:Connect(function(plr) whitelist[plr.UserId] = nil RefreshListVisual() end)

    RefreshListVisual()
    return frame, title
end

local wlFrame, wlTitle = CreateWhitelistControl(AimbotTab)

-- 瞄准部位多选控件（新增头、左右手、左右腿，移除胸口）
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
    listBg.Parent = frame

    local listBgCorner = Instance.new("UICorner")
    listBgCorner.CornerRadius = UDim.new(0, 8)
    listBgCorner.Parent = listBg

    local listBgStroke = Instance.new("UIStroke")
    listBgStroke.Thickness = 1
    listBgStroke.Color = Color3.fromRGB(60, 60, 65)
    listBgStroke.Transparency = 0.75
    listBgStroke.Parent = listBg

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
            btn.BackgroundColor3 = aimPartChoices[name] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
            btn.Text = "  "..name
            btn.TextColor3 = aimPartChoices[name] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = UIConfig.FontSize - 1
            btn.AutoButtonColor = false
            btn.ZIndex = 15
            btn.Visible = false
            btn.Parent = listContainer

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 6)
            optCorner.Parent = btn

            btn.MouseButton1Click:Connect(function()
                if aimPartChoices[name] then
                    aimPartChoices[name] = nil
                else
                    aimPartChoices[name] = true
                end
                btn.BackgroundColor3 = aimPartChoices[name] and Color3.fromRGB(255,105,180) or Color3.fromRGB(40,40,45)
                btn.TextColor3 = aimPartChoices[name] and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,185)

                -- 更新标题文本
                local count = 0
                local firstName
                for _, n in ipairs(aimPartsList) do
                    if aimPartChoices[n] then
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
                            TweenService:Create(c, TweenInfo.new(0.18), {BackgroundTransparency = 0}):Play()
                            TweenService:Create(c, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
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
        TweenService:Create(frame, TweenInfo.new(0.25), {Size = UDim2.new(1, -10, 0, targetFrameHeight)}):Play()
        TweenService:Create(listBg, TweenInfo.new(0.25), {Size = UDim2.new(1, -24, 0, targetListHeight + 8)}):Play()
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
                TweenService:Create(c, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                TweenService:Create(c, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                task.delay(0.15, function() c.Visible = false end)
            end)
        end
        TweenService:Create(listBg, TweenInfo.new(0.22), {Size = UDim2.new(1, -24, 0, 0)}):Play()
        TweenService:Create(frame, TweenInfo.new(0.22), {Size = UDim2.new(1, -10, 0, UIConfig.ControlHeight)}):Play()
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

-- Settings tab：滑块与开关
local smoothSliderFrame, smoothLabel, smoothTrack, smoothFill, smoothHandle, smoothHit = SettingsTab:AddSlider("平滑度", 0, 1, 0, function(value, ratio)
    smoothFactor = ratio
    if smoothLabel then
        local displayVal = string.format("%.2f", value)
        smoothLabel.Text = "平滑度 : "..displayVal
    end
end)

local fovSliderFrame, fovLabelInner, fovTrack, fovFill, fovHandle, fovHit = SettingsTab:AddSlider("FOV", 1, 180, 50, function(value, ratio)
    fovValue = value
    if fovLabelInner then fovLabelInner.Text = "FOV : "..tostring(fovValue) end
    if FovCircle and Workspace.CurrentCamera then
        local radiusPx = computeFovRadiusPixels(fovValue)
        local r = math.floor(radiusPx + 0.5)
        if r < 6 then r = 6 end
        local cam = Workspace.CurrentCamera
        local maxR = math.floor(math.min(cam.ViewportSize.X, cam.ViewportSize.Y) / 2)
        if r > maxR then r = maxR end
        FovCircle.Size = UDim2.new(0, r*2, 0, r*2)
    end
end)

local bulletSliderFrame, bulletLabel, bulletTrack, bulletFill, bulletHandle, bulletHit = SettingsTab:AddSlider("子弹速度", 100, 5000, 1500, function(value)
    bulletSpeed = value
    if bulletLabel then bulletLabel.Text = "子弹速度 : "..tostring(bulletSpeed) end
end)

local maxdistSliderFrame, maxdistLabel, maxdistTrack, maxdistFill, maxdistHandle, maxdistHit = SettingsTab:AddSlider("最大距离", 50, 1000, 500, function(value)
    maxAimDistance = value
    if maxdistLabel then maxdistLabel.Text = "最大距离 : "..tostring(maxAimDistance) end
end)

-- 忽略低血量开关和阈值滑块
local hpIgnoreSwitch, hpIgnoreThumb, hpIgnoreFrame, hpIgnoreLabel = SettingsTab:AddToggle("开启忽略低血量目标", false, function(state)
    ignoreLowHpEnabled = state
end)

local hpSliderFrame, hpLabel, hpTrack, hpFill, hpHandle, hpHit = SettingsTab:AddSlider("忽略血量阈值", 0, 100, 0, function(value)
    ignoreHpThreshold = math.floor(value + 0.5)
    if hpLabel then hpLabel.Text = "忽略血量阈值 : "..tostring(ignoreHpThreshold) end
end)

-- FOV 颜色动态开关
local fovColorSwitch, fovColorThumb, fovColorFrame, fovColorLabel = SettingsTab:AddToggle("FOV 颜色动态", false, function(state)
    fovColorRandomEnabled = state
    if not state and FovStroke then
        FovStroke.Color = Color3.fromRGB(255,182,193)
        fovColorCurrent = FovStroke.Color
        fovColorTarget = fovColorCurrent
    end
end)

-- 显示 FOV 开关（关闭则全屏 360 瞄准到屏幕中心最近）
local showFovSwitch, showFovThumb, showFovFrame, showFovLabel = SettingsTab:AddToggle("显示FOV", true, function(state)
    showFov = state
    if FovCircle then
        FovCircle.Visible = state
    end
end)

-- 自适应提前瞄准开关与灵敏度滑块
local adaptiveLeadSwitchObj, adaptiveLeadThumb, adaptiveLeadFrame, adaptiveLeadLabel = SettingsTab:AddToggle("自适应提前瞄准", false, function(state)
    adaptiveLeadEnabled = state
end)

local adaptiveSliderFrame, adaptiveLabel, adaptiveTrack, adaptiveFill, adaptiveHandle, adaptiveHit = SettingsTab:AddSlider("自适应灵敏度", 0, 1, 0.5, function(value, ratio)
    adaptiveLeadSensitivity = ratio
    if adaptiveLabel then adaptiveLabel.Text = "自适应灵敏度 : "..string.format("%.2f", value) end
end)

-- 修改：只要手上有东西就瞄准（不再按名称判断枪械）
local weaponOnlySwitch, weaponOnlyThumb, weaponOnlyFrame, weaponOnlyLabel = SettingsTab:AddToggle("只要手上有东西就瞄准", false, function(state)
    weaponOnlyEnabled = state
end)

-- 新增：FOV 跟随鼠标开关
local fovFollowSwitch, fovFollowThumb = SettingsTab:AddToggle("FOV 跟随鼠标", false, function(state)
    fovFollowMouseEnabled = state
    if FovCircle then
        -- 若开启则可立即将 FovCircle 移至鼠标位置（下一帧也会更新）
        if state then
            local mouseLoc = UserInputService:GetMouseLocation()
            FovCircle.Position = UDim2.new(0, mouseLoc.X, 0, mouseLoc.Y)
        else
            local centerVec = getScreenCenterForFov()
            FovCircle.Position = UDim2.new(0, centerVec.X, 0, centerVec.Y)
        end
    end
end)

-- 新增：随机偏移目标部位开关
local randOffsetSwitch, randOffsetThumb = SettingsTab:AddToggle("随机偏移目标部位", false, function(state)
    randomOffsetEnabled = state
end)

-- 新增：偏移概率滑块（0..100 默认50）
local probSliderFrame, probLabel, probTrack, probFill, probHandle, probHit = SettingsTab:AddSlider("偏移概率", 0, 100, 50, function(value)
    randomOffsetProbability = math.clamp(math.floor(value + 0.5), 0, 100)
    if probLabel then probLabel.Text = "偏移概率 : "..tostring(randomOffsetProbability).."%" end
end)

-- 新增：优先锁定最近目标开关
local prioritizeSwitch, prioritizeThumb = SettingsTab:AddToggle("优先锁定最近目标", false, function(state)
    prioritizeNearest = state
end)

-- 瞄准模式下拉（保留）
local aimModeDropdown, aimModeTitle = AimbotTab:AddDropdown("瞄准模式", {"原文","Raycast","Ray"}, 1, function(optionText)
    aimMode = optionText
    if aimModeTitle then aimModeTitle.Text = "瞄准模式: <font color=\"#FF69B4\">"..aimMode.."</font>" end
end)

-- 初始化文本
bindStatusLabel.Text = "当前绑定: 鼠标右键"
if smoothLabel then smoothLabel.Text = string.format("平滑度 : %.2f", 0.00) end
if fovLabelInner then fovLabelInner.Text = "FOV : "..tostring(fovValue) end
if bulletLabel then bulletLabel.Text = "子弹速度 : "..tostring(bulletSpeed) end
if maxdistLabel then maxdistLabel.Text = "最大距离 : "..tostring(maxAimDistance) end
if hpLabel then hpLabel.Text = "忽略血量阈值 : "..tostring(ignoreHpThreshold) end
if aimPartsTitle then aimPartsTitle.Text = "瞄准部位: <font color=\"#FF69B4\">身体</font>" end
if aimModeTitle then aimModeTitle.Text = "瞄准模式: <font color=\"#FF69B4\">"..aimMode.."</font>" end
if probLabel then probLabel.Text = "偏移概率 : "..tostring(randomOffsetProbability).."%" end

-- 绑定按键逻辑（保留之前行为，支持鼠标右键按住/切换）
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if waitingForKey then
        waitingForKey = false
        bindBtnLabel.Text = "点击设置快捷键"
        if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
            bindKeycode = input.KeyCode
            updateBindDisplay(input.KeyCode)
        else
            bindKeycode = input.UserInputType
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                updateBindDisplay("鼠标右键")
            else
                updateBindDisplay(input.UserInputType)
            end
        end
        return
    end

    if not isMobile and input.UserInputType == Enum.UserInputType.MouseButton2 and bindKeycode == Enum.UserInputType.MouseButton2 then
        mousePressStart = os.clock()
        mouseHoldActive = false
        task.delay(clickThreshold, function()
            if mousePressStart and (os.clock() - mousePressStart) >= clickThreshold then
                mouseHoldActive = true
                SetAimbotState(true)
            end
        end)
        return
    end

    if bindKeycode then
        if typeof(bindKeycode) == "EnumItem" and bindKeycode.EnumType == Enum.KeyCode and input.KeyCode == bindKeycode then
            clickToggleActive = not clickToggleActive
            SetAimbotState(clickToggleActive)
        elseif typeof(bindKeycode) == "EnumItem" and bindKeycode.EnumType == Enum.UserInputType and bindKeycode ~= Enum.UserInputType.MouseButton2 and input.UserInputType == bindKeycode then
            clickToggleActive = not clickToggleActive
            SetAimbotState(clickToggleActive)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not isMobile and input.UserInputType == Enum.UserInputType.MouseButton2 and bindKeycode == Enum.UserInputType.MouseButton2 then
        if mousePressStart then
            mousePressStart = nil
            if mouseHoldActive then
                mouseHoldActive = false
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
RunService.RenderStepped:Connect(function(dt)
    local cam = Workspace.CurrentCamera
    -- 修复点：即使 UI 关闭，如果开启了 fovFollowMouseEnabled 也应更新 FovCircle 的位置
    if cam and FovCircle and FovCircle.Parent and (isUIOpen or fovFollowMouseEnabled) then
        local radiusPx = computeFovRadiusPixels(fovValue)
        local r = math.floor(radiusPx + 0.5)
        if r < 6 then r = 6 end
        local maxR = math.floor(math.min(cam.ViewportSize.X, cam.ViewportSize.Y) / 2)
        if r > maxR then r = maxR end

        -- FOV 圆心根据是否跟随鼠标决定
        local centerVec
        if fovFollowMouseEnabled then
            local mouseLoc = UserInputService:GetMouseLocation()
            centerVec = Vector2.new(mouseLoc.X, mouseLoc.Y)
        else
            centerVec = getScreenCenterForFov()
        end

        local clamped = clampVecToViewport(centerVec, r, cam.ViewportSize)
        FovCircle.Size = UDim2.new(0, r*2, 0, r*2)
        FovCircle.Position = UDim2.new(0, clamped.X, 0, clamped.Y)
    end

    -- FOV 颜色动画（开启且 FOV 显示时）
    if FovStroke and fovColorRandomEnabled and showFov then
        local dist = math.abs(fovColorCurrent.R - fovColorTarget.R) + math.abs(fovColorCurrent.G - fovColorTarget.G) + math.abs(fovColorCurrent.B - fovColorTarget.B)
        if dist < 0.01 then
            fovColorTarget = randomFovColor()
        end
        -- 简单线性插值
        fovColorCurrent = Color3.new(
            fovColorCurrent.R + (fovColorTarget.R - fovColorCurrent.R) * (fovColorTweenSpeed * (1 + dt*30)),
            fovColorCurrent.G + (fovColorTarget.G - fovColorCurrent.G) * (fovColorTweenSpeed * (1 + dt*30)),
            fovColorCurrent.B + (fovColorTarget.B - fovColorCurrent.B) * (fovColorTweenSpeed * (1 + dt*30))
        )
        FovStroke.Color = fovColorCurrent
    end

    if not aimbotEnabled then return end

    -- 如果启用了“只要手上有东西就瞄准”，但当前未持任何东西则不瞄准
    if weaponOnlyEnabled and not playerHasAnythingInHand() then
        targetLabel.Text = "未持任何物品，暂停瞄准"
        return
    end

    local localChar = LocalPlayer.Character
    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return end
    if not cam then cam = Workspace.CurrentCamera end
    if not cam then return end
    local camPos = cam.CFrame.Position

    -- 锁定目标存在则持续瞄准，否则寻找最近目标
    if lockedTarget and lockedTarget.part and lockedTarget.character then
        local hum = lockedTarget.character:FindFirstChild("Humanoid")
        local part = lockedTarget.part
        -- 如果角色已死亡或部位不再属于该角色，强制清除锁定（死亡是永久事件）
        if not hum or hum.Health <= 0 or not (part and part:IsDescendantOf(lockedTarget.character)) then
            lockedTarget = getClosestToCrosshair()
            if lockedTarget then
                targetLabel.Text = "锁定目标: "..(lockedTarget.player and lockedTarget.player.Name or "未知").." ("..(lockedTarget.part and lockedTarget.part.Name or "部位")..")"
            else
                targetLabel.Text = "锁定目标: 无"
            end
            return
        end

        -- 忽略低血量：若开启则视情况清除或在按住右键时保持锁定但提示
        if ignoreLowHpEnabled and hum and hum.Health <= ignoreHpThreshold then
            if mouseHoldActive then
                targetLabel.Text = "目标低血量（保持锁定）"
                return
            else
                lockedTarget = nil
                targetLabel.Text = "跳过低血量目标"
                return
            end
        end

        -- 墙体检测：若被墙挡住，在按住右键时保持锁定并提示；松开右键后允许切换
        if wallCheckEnabled and raycastSkipPassable(camPos, part.Position, lockedTarget.character) then
            if mouseHoldActive then
                targetLabel.Text = "目标被墙壁遮挡（保持锁定）"
                return
            else
                lockedTarget = nil
                targetLabel.Text = "目标被墙壁遮挡"
                return
            end
        end

        -- 处理随机偏移逻辑：按概率替换为目标角色的其它可见部位
        local aimPart = part
        if randomOffsetEnabled and math.random(1, 100) <= randomOffsetProbability then
            local centerVec = fovFollowMouseEnabled and (function() local m = UserInputService:GetMouseLocation(); return Vector2.new(m.X, m.Y) end)() or getScreenCenterForFov()
            local radiusPx = showFov and computeFovRadiusPixels(fovValue) or math.huge
            local alt = chooseRandomVisiblePart(lockedTarget.character, cam, centerVec, radiusPx, part)
            if alt then
                aimPart = alt
                -- 可选：在标签显示当前实际瞄准部位
                targetLabel.Text = "锁定目标: "..(lockedTarget.player and lockedTarget.player.Name or "未知").." ("..(part and part.Name or "部位").."->"..(alt and alt.Name or "部位")..")"
            end
        end

        -- 执行瞄准；若失败则在未按住右键时重新获取目标（按住右键时不自动切换）
        local aimed = predictAndAim(cam, aimPart)
        if not aimed then
            if mouseHoldActive then
                -- 按住右键时保持锁定（即使当前帧瞄准失败）
                targetLabel.Text = "瞄准中（受阻）"
                return
            else
                lockedTarget = getClosestToCrosshair()
                targetLabel.Text = lockedTarget and ("锁定目标: "..(lockedTarget.player and lockedTarget.player.Name or "未知").." ("..(lockedTarget.part and lockedTarget.part.Name or "部位")..")") or "锁定目标: 无"
                return
            end
        end
    else
        -- 如果当前没有锁定目标，才会去寻找新目标（按住右键不会阻止首次寻找）
        lockedTarget = getClosestToCrosshair()
        if lockedTarget then
            targetLabel.Text = "锁定目标: "..(lockedTarget.player and lockedTarget.player.Name or "未知").." ("..(lockedTarget.part and lockedTarget.part.Name or "部位")..")"
        else
            targetLabel.Text = "锁定目标: 无"
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
        if ProgressBarFill then
            ProgressBarFill.Size = UDim2.new(progress, 0, 1, 0)
        end
        if progress < 0.3 then
            LoaderStatus.Text = string.format("初始化核心环境... %d%%", math.floor(progress * 100))
        elseif progress < 0.7 then
            LoaderStatus.Text = string.format("检测设备与配置资源... %d%%", math.floor(progress * 100))
        elseif progress < 0.95 then
            LoaderStatus.Text = string.format("准备界面组件... %d%%", math.floor(progress * 100))
        else
            LoaderStatus.Text = string.format("加载完成! %d%%", math.floor(progress * 100))
        end
        if progress >= 1 then break end
        task.wait()
    end
    local fadeTween = TweenService:Create(LoaderFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.55, 0),
        BackgroundTransparency = 1
    })
    if LoaderStroke then TweenService:Create(LoaderStroke, TweenInfo.new(0.35), {Transparency = 1}):Play() end
    if StaticLogo then TweenService:Create(StaticLogo, TweenInfo.new(0.35), {TextTransparency = 1}):Play() end
    if LoaderStatus then TweenService:Create(LoaderStatus, TweenInfo.new(0.35), {TextTransparency = 1}):Play() end
    if ProgressBarBG then TweenService:Create(ProgressBarBG, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play() end
    if ProgressBarFill then TweenService:Create(ProgressBarFill, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play() end
    fadeTween:Play()
    fadeTween.Completed:Wait()
    pcall(function() LoaderFrame:Destroy() end)
    SideBarToggle.Visible = true
    TweenService:Create(StatusBar, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.05, 0),
        BackgroundTransparency = 0
    }):Play()
    TweenService:Create(StatusStroke, TweenInfo.new(0.6), {Transparency = 0.4}):Play()
    TweenService:Create(LogoLabel, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    TweenService:Create(Divider, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    TweenService:Create(InfoLabel, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    ToggleMainUI()
    createFovCircle()
end)
