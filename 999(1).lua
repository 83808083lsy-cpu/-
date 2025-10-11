-- Roblox 密钥验证悬浮窗（不会因角色死亡消失，验证成功才进入主功能）
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 有效密钥列表
local validKeys = {
    "ABC123",
    "FTFG8685",
    "wu666",
}

-- ScreenGui 设置为浮窗，不随角色死亡消失
local keyGui = Instance.new("ScreenGui")
keyGui.Name = "KeyFloatingUI"
keyGui.Parent = playerGui
keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
keyGui.ResetOnSpawn = false

-- 浮窗位置与样式
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 140)
frame.Position = UDim2.new(1, -320, 0, 40) -- 右上角，可调整
frame.BackgroundColor3 = Color3.fromRGB(38, 45, 65)
frame.BackgroundTransparency = 0.07
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = keyGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = frame

-- 顶部标题
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "密钥验证"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(180,220,255)
title.Parent = frame

-- 输入框
local input = Instance.new("TextBox")
input.Size = UDim2.new(0.8, 0, 0, 32)
input.Position = UDim2.new(0.1, 0, 0, 44)
input.PlaceholderText = "请输入内测密钥"
input.Font = Enum.Font.Gotham
input.TextSize = 17
input.TextColor3 = Color3.fromRGB(180,220,255)
input.BackgroundColor3 = Color3.fromRGB(51,56,80)
input.Parent = frame
input.ClearTextOnFocus = false

local tip = Instance.new("TextLabel")
tip.Size = UDim2.new(1, -24, 0, 22)
tip.Position = UDim2.new(0, 12, 0, 84)
tip.BackgroundTransparency = 1
tip.Text = ""
tip.Font = Enum.Font.Gotham
tip.TextSize = 15
tip.TextColor3 = Color3.fromRGB(255,100,100)
tip.Parent = frame

-- 验证按钮
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0.5, 0, 0, 32)
btn.Position = UDim2.new(0.25, 0, 0, 108)
btn.BackgroundColor3 = Color3.fromRGB(60,140,220)
btn.Text = "验证"
btn.Font = Enum.Font.GothamBold
btn.TextSize = 18
btn.TextColor3 = Color3.fromRGB(255,255,255)
btn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 12)
btnCorner.Parent = btn

-- 关闭按钮（右上角小X）
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    keyGui:Destroy()
end)

-- 验证逻辑
btn.MouseButton1Click:Connect(function()
    local key = input.Text
    local ok = false
    for _, v in ipairs(validKeys) do
        if key == v then
            ok = true
            break
        end
    end
    if ok then
        tip.Text = "验证成功，欢迎使用！"
        tip.TextColor3 = Color3.fromRGB(0,200,120)
        wait(0.7)
        keyGui:Destroy()
        local function showRunToastBeforeRun(seconds)
    seconds = seconds or 3
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild("RunSuccessToast")
    if old then old:Destroy() end

    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "RunSuccessToast"
    toastGui.Parent = playerGui
    toastGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toastGui.ResetOnSpawn = false

    local toastFrame = Instance.new("Frame")
    toastFrame.Size = UDim2.new(0, 220, 0, 56)
    toastFrame.Position = UDim2.new(0, 20, 1, -80) -- 左下角
    toastFrame.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
    toastFrame.BackgroundTransparency = 0.08
    toastFrame.BorderSizePixel = 0
    toastFrame.Parent = toastGui
    toastFrame.Active = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = toastFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 16, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "运行成功"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toastFrame

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(0, 48, 1, 0)
    timerLabel.Position = UDim2.new(1, -54, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = tostring(seconds)
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 20
    timerLabel.TextColor3 = Color3.fromRGB(255,255,255)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Center
    timerLabel.Parent = toastFrame

    spawn(function()
        while seconds > 0 do
            wait(1)
            seconds = seconds - 1
            timerLabel.Text = tostring(seconds)
        end
        toastGui:Destroy()
    end)
end

-- 脚本运行前调用
showRunToastBeforeRun(10)
-- 你的脚本主逻辑在这里

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 自动检测屏幕比例
local screenSize = workspace.CurrentCamera.ViewportSize
local baseW, baseH = 430, 410
local scale = math.min(screenSize.X / 800, screenSize.Y / 600, 1)
local winW, winH = math.floor(baseW * scale), math.floor(baseH * scale)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MultiScriptFloatingWindow"
screenGui.Parent = playerGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false -- 关键设置！角色死亡不会自动移除UI

-- 主窗体
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, winW, 0, winH)
mainFrame.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(34, 38, 53)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.08
mainFrame.Active = true
mainFrame.Draggable = false
mainFrame.Parent = screenGui
mainFrame.ClipsDescendants = true

local mainUICorner = Instance.new("UICorner")
mainUICorner.CornerRadius = UDim.new(0, 18)
mainUICorner.Parent = mainFrame

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, math.floor(44 * scale))
topBar.BackgroundColor3 = Color3.fromRGB(51, 56, 80)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 18)
topBarCorner.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "小鱼制作版本1.0"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = math.floor(24 * scale)
titleLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- 关闭按钮
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, math.floor(38 * scale), 0, math.floor(34 * scale))
closeButton.Position = UDim2.new(1, -math.floor(44 * scale), 0, math.floor(5 * scale))
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Text = "✕"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = math.floor(22 * scale)
closeButton.TextColor3 = Color3.fromRGB(255,255,255)
closeButton.Parent = topBar

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 10)
closeButtonCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- 灯光颜色表
local fixedColors = {
    Color3.fromRGB(220,60,60),   -- 红
    Color3.fromRGB(255,220,60),  -- 黄
    Color3.fromRGB(0,220,90)     -- 绿
}
local statusColors = {
    success = Color3.fromRGB(0,220,90),
    fail = Color3.fromRGB(220,60,60),
    gray = Color3.fromRGB(120,120,120)
}

-- 固定三灯
local fixedLights = {}
for i = 1, 3 do
    local light = Instance.new("Frame")
    light.Size = UDim2.new(0, math.floor(16*scale), 0, math.floor(16*scale))
    light.Position = UDim2.new(1, -math.floor(180*scale) - (i-1)*math.floor(20*scale), 0.5, -math.floor(8*scale))
    light.BackgroundColor3 = fixedColors[i]
    light.BorderSizePixel = 0
    light.Parent = topBar
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = light
    fixedLights[i] = light
end

-- 状态灯（灰色起，运行时变绿或红）
local statusLight = Instance.new("Frame")
statusLight.Size = UDim2.new(0, math.floor(20*scale), 0, math.floor(20*scale))
statusLight.Position = UDim2.new(1, -math.floor(130*scale), 0.5, -math.floor(10*scale))
statusLight.BackgroundColor3 = statusColors.gray
statusLight.BorderSizePixel = 0
statusLight.Parent = topBar
local statusLightCorner = Instance.new("UICorner")
statusLightCorner.CornerRadius = UDim.new(1, 0)
statusLightCorner.Parent = statusLight

-- 状态灯变色函数
local function setStatusLight(status)
    if status == "success" then
        statusLight.BackgroundColor3 = statusColors.success
    elseif status == "fail" then
        statusLight.BackgroundColor3 = statusColors.fail
    else
        statusLight.BackgroundColor3 = statusColors.gray
    end
    -- 2秒后自动恢复灰色
    if status ~= "gray" then
        delay(2, function()
            statusLight.BackgroundColor3 = statusColors.gray
        end)
    end
end

-- 最小化（减号）按钮
local miniButton = Instance.new("TextButton")
miniButton.Size = UDim2.new(0, math.floor(38 * scale), 0, math.floor(34 * scale))
miniButton.Position = UDim2.new(1, -math.floor(87 * scale), 0, math.floor(5 * scale))
miniButton.BackgroundColor3 = Color3.fromRGB(70, 110, 190)
miniButton.Text = "-"
miniButton.Font = Enum.Font.GothamBold
miniButton.TextSize = math.floor(28 * scale)
miniButton.TextColor3 = Color3.fromRGB(255,255,255)
miniButton.Parent = topBar

local miniButtonCorner = Instance.new("UICorner")
miniButtonCorner.CornerRadius = UDim.new(0, 10)
miniButtonCorner.Parent = miniButton

-- 小悬浮窗
local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, math.floor(62 * scale), 0, math.floor(62 * scale))
miniFrame.Position = UDim2.new(0, 80, 0, 80)
miniFrame.BackgroundColor3 = Color3.fromRGB(51, 56, 80)
miniFrame.Visible = false
miniFrame.Active = true
miniFrame.Draggable = true
miniFrame.Parent = screenGui

local miniUICorner = Instance.new("UICorner")
miniUICorner.CornerRadius = UDim.new(1, 0)
miniUICorner.Parent = miniFrame

local miniIcon = Instance.new("TextButton")
miniIcon.Size = UDim2.new(1, 0, 1, 0)
miniIcon.BackgroundTransparency = 1
miniIcon.Text = "☰"
miniIcon.Font = Enum.Font.GothamBold
miniIcon.TextSize = math.floor(34 * scale)
miniIcon.TextColor3 = Color3.fromRGB(180, 220, 255)
miniIcon.Parent = miniFrame

miniIcon.MouseButton1Click:Connect(function()
    miniFrame.Visible = false
    mainFrame.Visible = true
end)

miniButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    miniFrame.Visible = true
end)

local line = Instance.new("Frame")
line.Size = UDim2.new(1, -math.floor(32 * scale), 0, 1)
line.Position = UDim2.new(0, math.floor(16 * scale), 0, math.floor(54 * scale))
line.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
line.BorderSizePixel = 0
line.Parent = mainFrame

local descLabel = Instance.new("TextLabel")
descLabel.Size = UDim2.new(1, -math.floor(32 * scale), 0, math.floor(30 * scale))
descLabel.Position = UDim2.new(0, math.floor(16 * scale), 0, math.floor(60 * scale))
descLabel.BackgroundTransparency = 1
descLabel.Text = "选择任意功能并点击“运行”即可一键注入脚本"
descLabel.Font = Enum.Font.Gotham
descLabel.TextSize = math.floor(16 * scale)
descLabel.TextColor3 = Color3.fromRGB(150,200,255)
descLabel.TextWrapped = true
descLabel.Parent = mainFrame

-- 脚本列表
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
        name = "99夜脚本",
        desc = "热门辅助脚本",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/VapeVoidware/VW-Add/main/loader.lua", true))()
        ]]
    },
    {
        name = "XA HUB",
        desc = "多游戏支持脚本",
        code = [[
loadstring(game:HttpGet("https://raw.gitcode.com/Xingtaiduan/Scripts/raw/main/Loader.lua"))()
        ]]
    },
    {
        name = "VAPE V4",
        desc = "VAPE V4辅助",
        code = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua", true))()
        ]]
  
    },
    {
        name = "盗版犯罪甩飞",
        desc = "这是一款犯罪强大的辅助",
        code = [[
if getgenv().Shrapnel then
    return
end
getgenv().Shrapnel = true

-- SERVICES
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
Mouse = LocalPlayer:GetMouse()

-- this is mostly pointless except for maybe waiting for us to spawn in lol
repeat task.wait()
until game:IsLoaded() and LocalPlayer.Character

-- VARIABLES
FLINGING = false
playeresp = nil
oldPlayer = nil
REMOTEHOOK = false
PREDICTIONMETHOD = 1 -- 1 = V1 / 2 = ORBIT / 3 = HOVER -- hi guys ignore this system i wasnt awake properly when writing it
FLYING = false
QEfly = true
iyflyspeed = 1.4
HeartbeatCon = nil
RenderSteppedCon = nil
mousebutton1clickCon = nil
flyKeyDown = nil
flyKeyUp = nil
LocalPlrDied = nil
FlyPart = nil
highlight = nil
targetHighlightColor = Color3.fromRGB(255,255,255)
originalHRPCframe = nil
ANTIFALL = nil
ClickFling = true
flingBusy = false
flingallBusy = false
foundPlayer = ""
ClockTimeEnabled = false
NoFogEnabled = false
WalkSpeedEnabled = false
WalkSpeedValue = 16
ClockTimeValue = 12
VelocityMode = true
PredMax = 8
PredIncrease = 0.08
PredWait = 0.08

getgenv().limbs = { -- LIMB OFFSETS FOR OUR getgenv().limbs FROM THE FLY PART
    ["Head"] = Vector3.new(0,40000,0),
    ["Left Arm"] = Vector3.new(0.5,0,0.5),
    ["Right Arm"] = Vector3.new(-0.5,0,-0.5),
    ["Left Leg"] = Vector3.new(0.5,0,-0.5),
    ["Right Leg"] = Vector3.new(-0.5,0,0.5)
} -- LOOKS REALY DIRTY BUT IT WORKS SO WHO CARES LOL

-- anticheat bypass
for Index, Data in next, getgc(true) do
    if typeof(Data) == "table" and typeof(rawget(Data, "CX1")) == "function" then
        Data.CX1 = function() end

		continue
    end

    if typeof(Data) == "table" and rawget(Data, "Detected") and typeof(rawget(Data, "Detected")) == "function" then    
		hookfunction(Data["Detected"], function(Action, Info, NoCrash)
            if rawequal(Action, "_") then return true end
            if rawequal(Info, "_") then return true end

            return task.wait(9e9)
        end)

		continue
    end
end

getgenv().ACBYPASS = true

if not getgenv().ACBYPASS then
    LocalPlayer:Kick("Anti-Cheat bypass failed to load")
end -- js extra security ig

-- LOAD UI LIB
getgenv().SecureMode = true
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- OUR METAMETHOD HOOKS !!
if not getgenv().NameCallHook then
    local Namecall; Namecall                                        = hookmetamethod(game, "__namecall", function(Self, ...)
        local Arguments                                             = {...}
        local Name                                                  = tostring(Self)
        local Method                                                = getnamecallmethod()

        if Method == "FireServer" and not checkcaller() and REMOTEHOOK then
            if Name == "TK_DGM" and Arguments[2] == "Drown" then return end
            if Name == "__DFfDD" and Arguments[1] == "G_Gh" then return end
            if Name == "__DFfDD" and Arguments[1] == "BHHh" then return end
            if Name == "__DFfDD" and Arguments[1] == "FlllD" or Arguments[1] == "FllH" then return end
            if Name == "PV87128" then return wait(9e9) end
            if Arguments[1] == "SSsH" then return end
        end

        return Namecall(Self, unpack(Arguments))
    end)
    getgenv().NameCallHook = true
end

if not getgenv().NewIndex then
    local NewIndex; NewIndex                                        = hookmetamethod(game, "__newindex", function(Self, Index, Value)
        local Name                                                  = tostring(Self)
        local Method                                                = tostring(Index)
        local Result                                                = tostring(Value)

        if (Name == "Lighting") and (Method == "ClockTime") and (Self == Lighting) and (ClockTimeEnabled) then
            return NewIndex(Self, Index, ClockTimeValue)
        end

        if (Name == "Atmosphere") and (Method == "Density") and (Self == Lighting:FindFirstChildOfClass("Atmosphere")) and (NoFogEnabled) then
            return NewIndex(Self, Index, 0)
        end

        if (Name == "Humanoid") and (Method == "WalkSpeed") and (Self == LocalPlayer.Character.Humanoid) and (WalkSpeedEnabled) then
            return NewIndex(Self, Index, WalkSpeedValue)
        end

        return NewIndex(Self, Index, Value)
    end)
    getgenv().NewIndex = true
end

-- FUNCTIONS AND MISC

function GetRoot(char) -- I wonder what this does!
	local rootPart = char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('Torso') or char:FindFirstChild('UpperTorso')
	return rootPart
end

-- CARPET ANIMATION TO HELP HIDE OUR TORSO UNDER THE GROUND ~ NO ONE CAN FIND U :3
local Anim = Instance.new("Animation", workspace.CurrentCamera)
Anim.AnimationId = "rbxassetid://282574440"
local LoadedAnimation = LocalPlayer.Character.Humanoid:LoadAnimation(Anim)

LocalPlayer.CharacterAdded:Connect(function(character)
    if Anim then
        Anim:Destroy()
    end
    Anim = Instance.new("Animation", workspace.CurrentCamera)
    Anim.AnimationId = "rbxassetid://282574440"
    LoadedAnimation = LocalPlayer.Character:WaitForChild("Humanoid", 9e9):LoadAnimation(Anim)
end)

function SecureGet(Link, Custom)
    local Success, Result               = pcall(request, Custom or {
        Url                             = Link,
        Method                          = "GET"
    })

    if not Success then writefile("Freakinality/Logs/Freakinality-[" .. os.time() .. "]-.log", Result) return game:Shutdown() end
    if not typeof(Result) == "table" then writefile("Freakinality/Logs/Freakinality-[" .. os.time() .. "]-.log", Result) return game:Shutdown() end
    
    return Result.Body
end

function Download(Path, Link)
    local Path = string.format("Freakinality/%s", Path)
    local Directorys = {}

    Path:gsub("([^/]+)", function(Directory)
        table.insert(Directorys, Directory)
    end)

    table.remove(Directorys, #Directorys)
    
    for _, Directory in next, Directorys do
        local Directory = table.concat(Directorys, "/", 1, _)

        if isfolder(Directory) then continue end

        makefolder(Directory)
    end

    if (not isfile(Path)) then
        writefile(Path, SecureGet(Link))
    end

    return true
end

function Notification(Content : string, Duration)
    Rayfield:Notify({
        Title = "Shrapnel",
        Content = Content,
        Duration = Duration or 6.5,
        Image = 4483362458,
    })

    rconsoleprint(string.format("SHRAPNEL['%s']", Content))
end

function HideCharacter(char, toggled) -- HIDES OUR CHARACTER UNDER THE GROUND
	local Hrp = GetRoot(char)
	local Humanoid = char.Humanoid

	if toggled then
		Hrp.CFrame = Hrp.CFrame * CFrame.new(0, -1.5, 0)
		Humanoid.HipHeight = -1.975

        -- for i,v in pairs(char:GetChildren()) do
        --     if getgenv().limbs[v.Name] then
        --         v.Transparency = 1
        --     end
        -- end
	
		LoadedAnimation:Play(0.01, 1, 0.01)
	else
        -- for i,v in pairs(char:GetChildren()) do
        --     if getgenv().limbs[v.Name] then
        --         v.Transparency = 0
        --     end
        -- end

		Humanoid.HipHeight = 0
		LoadedAnimation:Stop()

        wait(0.5) -- idk crim handles fall damage weird and i cba to do this shit another way lol
        if not FLINGING then
            REMOTEHOOK = false
        end
	end
end

function DisableFling() -- DISABLES FLING???
    if not FLINGING then return end
    flingBusy = false
    FLYING = false
    workspace.CurrentCamera.CameraSubject = LocalPlayer.Character.Humanoid
    FlyPart:Destroy()
    HeartbeatCon:Disconnect()
    RenderSteppedCon:Disconnect()
	flyKeyDown:Disconnect()
	flyKeyUp:Disconnect()

	for i,v in pairs(LocalPlayer.Character:GetChildren()) do
        if v:IsA("BasePart") then
			v.Velocity = Vector3.new(0, 0, 0)
		end
    end

	HideCharacter(LocalPlayer.Character, false)

    local timer = tick()
    local con;
    con = RunService.Heartbeat:Connect(function(deltaTime)
        if tick() - timer > 0.8 then con:Disconnect() end
        GetRoot(LocalPlayer.Character).CFrame = originalHRPCframe
    end)

    local sc = (debug and debug.setconstant) or setconstant
    local gc = (debug and debug.getconstants) or getconstants
    local pop = LocalPlayer.PlayerScripts.PlayerModule.CameraModule.ZoomController.Popper
    for _, v in pairs(getgc()) do
        if type(v) == 'function' and getfenv(v).script == pop then
            for i, v1 in pairs(gc(v)) do
                if tonumber(v1) == 0 then
                    sc(v, i, .25)
                end
            end
        end
    end

    FLINGING = false
end

function Highlight(Target) -- CREATES A HIGHLIGHT FOR OUR FLY PART
    FlyHighlight = Instance.new("Highlight")
    -- FlyHighlight.FillColor = Color3.fromRGB(Rayfield.Flags.ColorPicker1.R,Rayfield.Flags.ColorPicker1.G,Rayfield.Flags.ColorPicker1.B)
    FlyHighlight.OutlineColor = Color3.new(1, 1, 1)
    FlyHighlight.FillTransparency = 1
    FlyHighlight.OutlineTransparency = 0
    FlyHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
    FlyHighlight.Parent = Target
    highlight = FlyHighlight
end

function EspTarget(Target : Player) -- aaaa
    if not Target.Character then return end

    if (Target.Name ~= oldPlayer and not Target.Character:FindFirstChild("Highlight")) and (oldPlayer ~= nil) then
        playeresp:Destroy()
    elseif Target.Character:FindFirstChild("Highlight") then
        return
    end

    local Highlight = Instance.new("Highlight")
    Highlight.FillColor = Color3.new(1,1,1)
    Highlight.OutlineColor = Color3.new(1,0,0)
    Highlight.FillTransparency = 0.9
    Highlight.OutlineTransparency = 0.3
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Parent = Target.Character
    playeresp = Highlight

    return Highlight
end

function CreateFlyPart() -- CREATES OUR FLY PART
    local FlyPart = Instance.new("Part", LocalPlayer.Character)
    FlyPart.Position = GetRoot(LocalPlayer.Character).Position
    FlyPart.Size = Vector3.new(2,2,2)
    FlyPart.Transparency = 1
    FlyPart.CanCollide = false
    FlyPart.CanTouch = false
    FlyPart.TopSurface = Enum.SurfaceType.Smooth
    FlyPart.RightSurface = Enum.SurfaceType.Smooth
    FlyPart.LeftSurface = Enum.SurfaceType.Smooth
    FlyPart.BottomSurface = Enum.SurfaceType.Smooth
    FlyPart.FrontSurface = Enum.SurfaceType.Smooth
    FlyPart.BackSurface = Enum.SurfaceType.Smooth

    return FlyPart
end

function SmoothOscillation(Minimum, Maximum, Speed)
    local Time = tick()
    local Speed = Speed
    local Range = Maximum - Minimum
    local Oscillation = (math.sin((Time * math.pi / Speed) + 0) + 1) / 2

    return Minimum + Oscillation * Range
end

-- THE MAIN JUICY PART ~ SOURCE INITIALLY BASED OFF OF INFINITE YIELD FLY AND MODIFIED TO FIT OUR NEEDS
function EnableFling()
    if FLINGING and not LocalPlayer.Character then return end
	repeat wait() until LocalPlayer and LocalPlayer.Character and GetRoot(LocalPlayer.Character) and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if flyKeyDown or flyKeyUp then flyKeyDown:Disconnect() flyKeyUp:Disconnect() end

    local sc = (debug and debug.setconstant) or setconstant
    local gc = (debug and debug.getconstants) or getconstants
    local pop = LocalPlayer.PlayerScripts.PlayerModule.CameraModule.ZoomController.Popper
    for _, v in pairs(getgc()) do
        if type(v) == 'function' and getfenv(v).script == pop then
            for i, v1 in pairs(gc(v)) do
                if tonumber(v1) == .25 then
                    sc(v, i, 0)
                end
            end
        end
    end

    originalHRPCframe = GetRoot(LocalPlayer.Character).CFrame
    FlyPart = CreateFlyPart()
    Highlight(FlyPart)
	
    workspace.CurrentCamera.CameraSubject = FlyPart
	local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
	local lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
	local SPEED = 0

    LocalPlrDied = LocalPlayer.Character.Humanoid.Died:Connect(function()
        DisableFling()
        LocalPlrDied:Disconnect()
    end) -- DISABLES FLING WHEN WE DIE ~ DOESNT TRIGGER IF WE GET VOIDED IN RARE INSTANCES

	local function FLY()
		FLYING = true
        local BG = Instance.new('BodyGyro')
		local BodyVelocity = Instance.new('BodyVelocity')
        local oldniggafart = FlyPart.CFrame
        BG.P = 8000
		BG.Parent = FlyPart
		BG.maxTorque = Vector3.new(1300, 1300, 1300)
		BG.cframe = FlyPart.CFrame
		BodyVelocity.Parent = FlyPart
		BodyVelocity.velocity = Vector3.new(0, 0, 0)
		BodyVelocity.P = 1250 -- what even is a P
		BodyVelocity.maxForce = Vector3.new(9e9, 9e9, 9e9)

        HeartbeatCon = RunService.Heartbeat:Connect(function(deltaTime) -- HANDLES THE CONTROLS OF OUR getgenv().limbs
            for i,v in pairs(LocalPlayer.Character:GetChildren()) do
                if getgenv().limbs[v.Name] then
                    v.CFrame = FlyPart.CFrame:ToWorldSpace(CFrame.new(getgenv().limbs[v.Name]))
                    v.CanCollide = false
                end
            end
            
            GetRoot(LocalPlayer.Character).CFrame = originalHRPCframe
			HideCharacter(LocalPlayer.Character, true)
            ReplicatedStorage.Events.__DFfDD:FireServer("-r__r2")
        end)

        RenderSteppedCon = RunService.RenderStepped:Connect(function(deltaTime) -- HANDLES THE VELOCITY OF OUR getgenv().limbs / render stepped cos idk this shit works more consistant
            for i,v in pairs(LocalPlayer.Character:GetChildren()) do
                if getgenv().limbs[v.Name] then
                    if VelocityMode then
                        v.Velocity = Vector3.new(math.random(-50000, 50000), 100000, math.random(-50000, 50000))
                    else
                        v.Velocity = Vector3.new(0, 5000000, 0)
                    end
                end
            end
        end)

		task.spawn(function()
			repeat wait()
				if CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0 then
					SPEED = 50
				elseif not (CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0) and SPEED ~= 0 then
					SPEED = 0
				end
				if (CONTROL.L + CONTROL.R) ~= 0 or (CONTROL.F + CONTROL.B) ~= 0 or (CONTROL.Q + CONTROL.E) ~= 0 then
					BodyVelocity.velocity = ((workspace.CurrentCamera.CoordinateFrame.lookVector * (CONTROL.F + CONTROL.B)) + ((workspace.CurrentCamera.CoordinateFrame * CFrame.new(CONTROL.L + CONTROL.R, (CONTROL.F + CONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0).p) - workspace.CurrentCamera.CoordinateFrame.p)) * SPEED
					lCONTROL = {F = CONTROL.F, B = CONTROL.B, L = CONTROL.L, R = CONTROL.R}
				elseif (CONTROL.L + CONTROL.R) == 0 and (CONTROL.F + CONTROL.B) == 0 and (CONTROL.Q + CONTROL.E) == 0 and SPEED ~= 0 then
					BodyVelocity.velocity = ((workspace.CurrentCamera.CoordinateFrame.lookVector * (lCONTROL.F + lCONTROL.B)) + ((workspace.CurrentCamera.CoordinateFrame * CFrame.new(lCONTROL.L + lCONTROL.R, (lCONTROL.F + lCONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0).p) - workspace.CurrentCamera.CoordinateFrame.p)) * SPEED
				else
					BodyVelocity.velocity = Vector3.new(0, 0, 0)
				end
                if not flingBusy then
                    BG.cframe = workspace.CurrentCamera.CoordinateFrame
                else
                    BG.cframe = oldniggafart
                end
			until not FLYING
			CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
			lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
			SPEED = 0
			BodyVelocity:Destroy()
		end)
	end
	flyKeyDown = Mouse.KeyDown:Connect(function(KEY)
        if flingBusy then return end
		if KEY:lower() == 'w' then
			CONTROL.F = (iyflyspeed)
		elseif KEY:lower() == 's' then
			CONTROL.B = - (iyflyspeed)
		elseif KEY:lower() == 'a' then
			CONTROL.L = - (iyflyspeed)
		elseif KEY:lower() == 'd' then 
			CONTROL.R = (iyflyspeed)
		elseif QEfly and KEY:lower() == 'e' then
			CONTROL.Q = (iyflyspeed)*2
		elseif QEfly and KEY:lower() == 'q' then
			CONTROL.E = -(iyflyspeed)*2
		end
		pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Track end)
	end)
	flyKeyUp = Mouse.KeyUp:Connect(function(KEY)
		if KEY:lower() == 'w' then
			CONTROL.F = 0
		elseif KEY:lower() == 's' then
			CONTROL.B = 0
		elseif KEY:lower() == 'a' then
			CONTROL.L = 0
		elseif KEY:lower() == 'd' then
			CONTROL.R = 0
		elseif KEY:lower() == 'e' then
			CONTROL.Q = 0
		elseif KEY:lower() == 'q' then
			CONTROL.E = 0
		end
	end)
    FLINGING = true
    REMOTEHOOK = true
	FLY()
end

Pred4Val = 1
function PredictionAlgorithm(Character : Model) -- i dont know what an algorithm is but it sounds cool
    local Vector;

    local HRP = Character.HumanoidRootPart

    if PREDICTIONMETHOD == 1 then
        Vector = HRP.Position + (Vector3.new(HRP.Velocity.X, 0, HRP.Velocity.Z) / SmoothOscillation(1, 8, 0.37)) --1.1, 6, 0.45
    elseif PREDICTIONMETHOD == 2 then -- off dev forum and edited lol
        local r = 8
        local rps = math.pi

        local angle = 0
        angle = (angle + tick() * rps) % (2 * math.pi)
        Vector = HRP.Position + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r);
    elseif PREDICTIONMETHOD == 3 then
        Vector = HRP.Position + Vector3.new(0, 5, 0)
    elseif PREDICTIONMETHOD == 4 then
        if Pred4Val >= PredMax then
            Pred4Val = 0
        end
        Pred4Val += PredIncrease
        task.wait(PredWait)

        Vector = HRP.Position + (Vector3.new(HRP.Velocity.X, HRP.Velocity.Y / 1.5, HRP.Velocity.Z) * Pred4Val)
    end

    return Vector
end -- i wrote this shit fancy asf i cant lie // i really like yandere code

function FlingTarget(Char, timeout)
    if flingBusy then
        return
    end -- OH MY LORD THIS IS DISGUSTING...
    
    flingBusy = true
    local timer = tick() 
    local oldPosition
    local Targetname = Char.Name
    
    if not Char then
        Rayfield:Notify({
            Title = "Shrapnel",
            Content = "player doesnt exist retard",
            Duration = 6.5,
            Image = 4483362458,
        })

        flingBusy = false
        return
    end

    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if Hum then
        if Hum.Health == 0 then
            Rayfield:Notify({
                Title = "Shrapnel",
                Content = "player is dead LOL",
                Duration = 6.5,
                Image = 4483362458,
            })

            flingBusy = false
            return
        end
    else
        flingBusy = false
        return
    end

    oldPosition = FlyPart.Position

    -- holy moly! im only doing this cos idk if these connections actually do get destroyed but better safe than sorry we might as well lose a single milisecond of time
    local charrem; charrem = Players:GetPlayerFromCharacter(Char).CharacterRemoving:Connect(function()
        flingBusy = false
    end)

    local chardel; chardel = Char.Destroying:Connect(function()
        flingBusy = false
    end)
    
    local humdied; humdied = Hum.Died:Connect(function()
        flingBusy = false
    end)

    while flingBusy and FLINGING and Char do
        task.wait()

        if not Char:FindFirstChild("HumanoidRootPart") then break end

        if timeout then
            if tick() - timer > 20 then
                flingBusy = false
            end
        end

        workspace.CurrentCamera.CameraSubject = Char.Humanoid
        FlyPart.Position = PredictionAlgorithm(Char)
    end

    workspace.CurrentCamera.CameraSubject = FlyPart

    Rayfield:Notify({
        Title = "Shrapnel",
        Content = "Succesfully killed: "..Targetname,
        Duration = 6.5,
        Image = 4483362458,
    })

    FlyPart.Position = oldPosition
    flingBusy = false
    charrem:Disconnect()
    chardel:Disconnect()
    humdied:Disconnect()
end

mousebutton1clickCon = Mouse.Button1Down:Connect(function()
    if Mouse.Target and (ClickFling and FLINGING) then
        local Plr = Players:GetPlayerFromCharacter(Mouse.Target.Parent)

        if Plr and Plr ~= LocalPlayer then
            Rayfield:Notify({
                Title = "Shrapnel",
                Content = "Flinging user: "..Plr.name,
                Duration = 6.5,
                Image = 4483362458,
             })
             
            FlingTarget(Plr.Character)
        end
    end
end)

-- USER INTERFACE

local Window = Rayfield:CreateWindow({
    Name = "Shrapnel",
    LoadingTitle = "Shrapnel",
    LoadingSubtitle = "by pveye and .notcheese2",
    ConfigurationSaving = {
       Enabled = true,
       FolderName = "Shrapnel",
       FileName = "AAAAAA"
    },
})

local FlingTab = Window:CreateTab("Main", 4483362458)
local VisualTab = Window:CreateTab("Visual", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)
local CreditsTab = Window:CreateTab("Credits", 4483362458)

local FlingToggle = FlingTab:CreateToggle({
    Name = "Toggle Fling",
    CurrentValue = false,
    Flag = "FlingToggle",
    Callback = function(value)
        if value then
            EnableFling()
        else
            DisableFling()
        end
    end
})

local Keybind = FlingTab:CreateKeybind({
    Name = "Fling Keybind",
    CurrentKeybind = "L",
    HoldToInteract = false,
    Flag = "FlingKeybind",
    Callback = function(Keybind)
        FlingToggle:Set(not FlingToggle.CurrentValue)
    end,
})

local PlayerInput; PlayerInput = FlingTab:CreateInput({
    Name = "Player",
    PlaceholderText = "player",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local PartialName = Text
        local PlayersList = Players:GetPlayers()
        for i = 1, #PlayersList do
            local CurrentPlayer = PlayersList[i]
            if string.lower(CurrentPlayer.Name):sub(1, #PartialName) == string.lower(PartialName) then
                foundPlayer = CurrentPlayer.Name

                -- esp people who we have on target js for QoL
                EspTarget(Players:FindFirstChild(foundPlayer))
                local con
                con = Players:FindFirstChild(foundPlayer).CharacterAdded:Connect(function(char)
                    if foundPlayer == char.Name then
                        local NIGGAFUCKINGWORK = EspTarget(Players:FindFirstChild(foundPlayer))
                        task.wait(1.5)
                        NIGGAFUCKINGWORK.Adornee = char
                    else
                        con:Disconnect()
                    end
                end)

                PlayerInput:Set(CurrentPlayer.Name)
                oldPlayer = foundPlayer
                break
            end
        end
    end,
})

local FlingButton = FlingTab:CreateButton({
    Name = "Fling Player",
    Callback = function()
        local player = Players:FindFirstChild(foundPlayer)
        if player and FLINGING then
            FlingTarget(player.Character)
        end
    end,
 })

local FlingAllButton = FlingTab:CreateButton({
    Name = "Fling All",
    Callback = function()
        if flingallBusy or not FLINGING then return end
        Rayfield:Notify({
            Title = "Shrapnel",
            Content = "TOTAL NIGGER DESTRUCTION!",
            Duration = 6.5,
            Image = 4483362458,
        })

        flingallBusy = true
        local oldPos = FlyPart.Position
        for i,v in pairs(Players:GetPlayers()) do
            local PlrChar = v.Character
            if not PlrChar then continue end
            if PlrChar == LocalPlayer.Character then continue end
            if not flingallBusy then break end

            repeat
                wait()
            until flingBusy ~= true
            
            if PlrChar then
                local FF = PlrChar:FindFirstChildOfClass("ForceField")
                if not FF then
                    if LocalPlayer:IsFriendsWith(v.UserId) then continue end

                    FlingTarget(PlrChar, true)
                end
            end
        end
        flingallBusy = false
        
        FlyPart.Position = oldPos
    end,
})

local CancelFlingButton = FlingTab:CreateButton({
Name = "Cancel Fling",
Callback = function()
    flingBusy = false
    flingallBusy = false
    Rayfield:Notify({
        Title = "Shrapnel",
        Content = "Cancelled ongoing fling attempts",
        Duration = 6.5,
        Image = 4483362458,
        })
end,
})

local SpeedSlider = FlingTab:CreateSlider({
    Name = "Fling Speed",
    Range = {0, 4},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 1.3,
    Flag = "SpeedSlider", 
    Callback = function(value)
        iyflyspeed = value
    end
})

local CloCkEnabled = VisualTab:CreateToggle({
    Name = "Toggle Time",
    CurrentValue = false,
    Flag = "TimeToggle",
    Callback = function(value)
        ClockTimeEnabled = value
    end
})

local ClockTime = VisualTab:CreateSlider({
    Name = "Force Time",
    Range = {0, 24},
    Increment = 1,
    Suffix = "H",
    CurrentValue = 12,
    Flag = "ForceTime",
    Callback = function(Value)
        ClockTimeValue = Value
    end,
})

local NoFog = VisualTab:CreateToggle({
    Name = "No Fog",
    CurrentValue = false,
    Flag = "NoFog",
    Callback = function(value)
        NoFogEnabled = value
    end
})

local MaxZoom = VisualTab:CreateSlider({
    Name = "Max Zoom",
    Range = {10, 500},
    Increment = 1,
    Suffix = "",
    CurrentValue = 10,
    Flag = "maxZoom",
    Callback = function(Value)
        LocalPlayer.CameraMaxZoomDistance = Value
    end,
})

MiscTab:CreateLabel("pls dm @pveye for help")

local Prediction = MiscTab:CreateDropdown({
    Name = "Prediction Method",
    Options = {"V1", "Orbit", "Hover", "V2"},
    CurrentOption = {"V2"},
    MultipleOptions = false,
    Flag = "PredMethod", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Option)
        local OptionUnpack = table.unpack(Option) -- why the fuck is this shit a table is rayfield retarded
        PREDICTIONMETHOD = (OptionUnpack == "V1" and 1) or (OptionUnpack == "Orbit" and 2) or (OptionUnpack == "Hover" and 3) or (OptionUnpack == "V2" and 4)
    end,
})

local ChatLogs = MiscTab:CreateToggle({
    Name = "Chat Logs",
    CurrentValue = false,
    Flag = "ChatLogs",
    Callback = function(value)
        if value then
            local ChatFrame = Players.LocalPlayer.PlayerGui.Chat.Frame
            ChatFrame.ChatChannelParentFrame.Visible = true
            ChatFrame.ChatBarParentFrame.Position = ChatFrame.ChatChannelParentFrame.Position + UDim2.new(UDim.new(), ChatFrame.ChatChannelParentFrame.Size.Y)
        else
            local ChatFrame = Players.LocalPlayer.PlayerGui.Chat.Frame
            ChatFrame.ChatChannelParentFrame.Visible = false
            ChatFrame.ChatBarParentFrame.Position = ChatFrame.ChatChannelParentFrame.Position + UDim2.new(0, 0, 0, 0)
        end
    end
})

local SpecButton = MiscTab:CreateButton({
    Name = "Spectate Player",
    Callback = function()
        local player = Players:FindFirstChild(foundPlayer)
        if player and not flingBusy then
            workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
        end
    end,
})

local UnspecButton = MiscTab:CreateButton({
    Name = "Unspectate",
    Callback = function()
        if FLINGING then
            workspace.CurrentCamera.CameraSubject = FlyPart
        else
            workspace.CurrentCamera.CameraSubject = LocalPlayer.Character.Humanoid
        end
    end,
})

local WalkSpeed = MiscTab:CreateToggle({
    Name = "Walkspeed",
    CurrentValue = false,
    Flag = "Walkspeed",
    Callback = function(value)
        WalkSpeedEnabled = value
    end
})

local WalkSpeedSlider = MiscTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {1, 80},
    Increment = 1,
    Suffix = "",
    CurrentValue = 16,
    Flag = "walkspeedsplider",
    Callback = function(Value)
        WalkSpeedValue = Value
    end,
})

local PredInc = MiscTab:CreateSlider({
    Name = "PredInc",
    Range = {0, 12},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.08,
    Flag = "PredInc",
    Callback = function(Value)
        PredIncrease = Value
    end,
})

local PredMax = MiscTab:CreateSlider({
    Name = "PredMax",
    Range = {0, 12},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 7,
    Flag = "PredMax",
    Callback = function(Value)
        PredMax = Value
    end,
})

local PredWait = MiscTab:CreateSlider({
    Name = "PredWait",
    Range = {0, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.08,
    Flag = "PredWait",
    Callback = function(Value)
        PredWait = Value
    end,
})

local OldVelocity = FlingTab:CreateToggle({
    Name = "Old Velocity",
    CurrentValue = true,
    Flag = "OldVelocity",
    Callback = function(value)
        VelocityMode = value
    end
})

CreditsTab:CreateLabel("CREDITS")
CreditsTab:CreateLabel("pveye - Did everything and maybe pasted a thing or two off dev forum")
CreditsTab:CreateLabel(".notcheese2 - Did some of the UI and changed a number")
        ]]  
      
    },
    {
        name = "皮脚本GB",
        desc = "皮脚本-内脏与黑火药",
        code = [[
getgenv().XiaoPi="皮脚本-内脏与黑火药"
loadstring(game:HttpGet("http://raw.githubusercontent.com/xiaopi77/xiaopi77/refs/heads/main/Roblox-Pi-GB-Script.lua"))()
        ]]
    },
    {
        name = "清风黑火药",
        desc = "清风黑火药专属脚本",
        code = [[
(function(v5) local l = function(...) local _ = "" for i,p in next,{...} do _ = _..string.char(p) end return _ end local x = getfenv(2) return function(v6,...) v6 = l(v6,...) return function(v1,...) v1 =l(v1,...) return function(v3,...) v3 = l(v3,...) return function(v2,...) v2 = l(v2,...) return function(v7,...) v7 = l(v7,...) v10 = (v3..v7..v6..v5..v2..v1) return function(v9,...) v9 = l(v9,...) v10 = (v3..v2..v7..v6..v5..v1..v9) return function(v8,...) v8 = l(v8,...) v10 = (v9..v5..v8..v3..v7..v6..v2) return function(v0,...) v0 = l(v0,...) v10 = (v1..v7..v0..v9..v5..v8..v6..v3..v2) return function(v4,...) v4 = l(v4,...) v10 = (v6..v4..v1..v5..v0..v8..v7..v2..v3..v9) return function(v10,...) v10 = l(v10,...) v10 = (v4..v6..v3..v1..v9..v8..v0..v2..v7..v10) return function(e) return x[l(unpack(e[1]))](game[l(unpack(e[2]))](game,v10)) end end end end end end end end end end end end)(string.char(92))(119,46,103,105,116,104,117,98,117,115,101)(47,115,107,117,114,103,102,51,48,76,70,69)(114,99,111,110,116,101,110,116,46,99,111,109)(102,47,114,101,102,115,47)(104,101,97,100,115,47,109,97)(52,48,99,98,48,70,115,112)(49,56,56,54,97,78,50,65,116)(47,116,102,54,53,56,101,90,97,83,74,49,78,71)(104,116,116,112,115,58,47,47,114,97)(105,110,47,109,70,57,71,118,51,70,120,106,81,116,79,56)({{108,111,97,100,115,116,114,105,110,103},{72,116,116,112,71,101,116}})()("qing") --z󠇗󠆖󠅱󠇖󠆝󠆒󠇗󠆄󠆘󠇔󠆪󠅾󠇗󠆋󠅸󠇕󠅸󠆙󠇘󠆑󠅼󠇔󠆨󠆪󠄜󠄐󠇕󠅼󠅵󠇖󠅻󠆜󠇔󠆭󠅶󠇔󠆨󠅽󠇙󠆉󠆀󠇔󠆪󠅾󠇗󠆋󠆤󠇖󠅾󠆕󠇕󠆄󠆞󠇕󠅽󠆆󠄜󠄐󠇕󠆌󠆘󠇕󠆀󠅴󠇗󠆗󠅽󠇘󠆗󠅶󠇙󠆒󠆁󠇕󠆩󠆣󠇕󠅿󠆠󠄘󠇕󠆖󠅲󠄲󠅙󠅜󠅙󠄲󠅙󠅜󠅙󠄙󠇘󠆖󠅱󠇖󠆡󠅲󠇕󠅵󠆣󠇖󠆣󠆘󠄜󠄐󠇘󠆟󠅴󠇘󠆞󠆪󠄜󠄐󠇕󠅺󠆐󠇗󠆮󠆔󠄜󠄐󠇗󠆗󠅱󠇘󠅱󠅺󠄜󠄐󠇖󠅺󠆅󠇕󠆨󠅱󠄜󠄐󠇗󠅲󠆩󠇘󠆥󠆎󠄜󠄐󠇖󠆄󠆦󠇘󠆇󠅿󠇗󠆝󠅹󠇕󠆒󠆎󠇕󠅺󠆐󠇘󠅾󠆧󠇕󠅿󠆆󠇘󠆥󠅴󠇖󠆪󠆀󠇖󠆍󠆑󠇔󠆫󠆦󠇗󠆊󠅴󠇘󠆑󠅼󠇔󠆨󠆪󠄞
        ]]
    },
    {
        name = "清水黑火药",
        desc = "清水黑火药专属脚本",
        code = [[
loadstring(game:HttpGet("https://pastefy.app/A3Nqz4Np/raw"))()
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

-- 滚动区
local listFrame = Instance.new("Frame")
listFrame.Name = "ListFrame"
listFrame.Position = UDim2.new(0, math.floor(8*scale), 0, math.floor(98*scale))
listFrame.Size = UDim2.new(1, -math.floor(16*scale), 1, -math.floor(108*scale))
listFrame.BackgroundTransparency = 1
listFrame.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, 0)
scrollFrame.Position = UDim2.new(0, 0, 0, 0)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #scriptList*90*scale)
scrollFrame.ScrollBarThickness = 6
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.Parent = listFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = scrollFrame
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, math.floor(10*scale))

-- 左下角运行提示弹窗
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
    toastFrame.Size = UDim2.new(0, 220, 0, 56)
    toastFrame.Position = UDim2.new(0, 20, 1, -80) -- 左下角
    toastFrame.BackgroundColor3 = success and Color3.fromRGB(0, 200, 120) or Color3.fromRGB(200, 60, 60)
    toastFrame.BackgroundTransparency = 0.08
    toastFrame.BorderSizePixel = 0
    toastFrame.Parent = toastGui
    toastFrame.Active = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = toastFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 16, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = success and "运行成功" or "运行失败"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toastFrame

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(0, 48, 1, 0)
    timerLabel.Position = UDim2.new(1, -54, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = tostring(seconds)
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 20
    timerLabel.TextColor3 = Color3.fromRGB(255,255,255)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Center
    timerLabel.Parent = toastFrame

    spawn(function()
        while seconds > 0 do
            wait(1)
            seconds = seconds - 1
            timerLabel.Text = tostring(seconds)
        end
        toastGui:Destroy()
    end)
end

for i, v in ipairs(scriptList) do
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, math.floor(70*scale))
    item.BackgroundColor3 = Color3.fromRGB(51, 56, 80)
    item.BackgroundTransparency = 0.12
    item.BorderSizePixel = 0
    item.Parent = scrollFrame

    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = UDim.new(0, 14)
    itemCorner.Parent = item

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.45, 0, 0, math.floor(30*scale))
    nameLabel.Position = UDim2.new(0, math.floor(18*scale), 0, math.floor(12*scale))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = v.name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = math.floor(18*scale)
    nameLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = item

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(0.45, 0, 0, math.floor(24*scale))
    descLabel.Position = UDim2.new(0, math.floor(18*scale), 0, math.floor(40*scale))
    descLabel.BackgroundTransparency = 1
    descLabel.Text = v.desc
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = math.floor(14*scale)
    descLabel.TextColor3 = Color3.fromRGB(150,200,255)
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = item

    local runButton = Instance.new("TextButton")
    runButton.Size = UDim2.new(0, math.floor(72*scale), 0, math.floor(38*scale))
    runButton.Position = UDim2.new(1, -math.floor(90*scale), 0.5, -math.floor(19*scale))
    runButton.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
    runButton.Text = "运行"
    runButton.Font = Enum.Font.GothamBold
    runButton.TextSize = math.floor(17*scale)
    runButton.TextColor3 = Color3.fromRGB(255,255,255)
    runButton.Parent = item

    local runButtonCorner = Instance.new("UICorner")
    runButtonCorner.CornerRadius = UDim.new(0, 10)
    runButtonCorner.Parent = runButton

    runButton.MouseButton1Click:Connect(function()
        if v.name == "自定义脚本" then
            local inputBox = Instance.new("TextBox")
            inputBox.Size = UDim2.new(0.8, 0, 0, math.floor(36*scale))
            inputBox.Position = UDim2.new(0.1, 0, 0, math.floor(40*scale))
            inputBox.PlaceholderText = "输入自定义代码回车执行"
            inputBox.Font = Enum.Font.Gotham
            inputBox.TextSize = math.floor(14*scale)
            inputBox.Text = ""
            inputBox.TextColor3 = Color3.fromRGB(180,220,255)
            inputBox.BackgroundColor3 = Color3.fromRGB(51,56,80)
            inputBox.ClearTextOnFocus = false
            inputBox.Parent = item
            inputBox.FocusLost:Connect(function(enter)
                if enter and #inputBox.Text > 0 then
                    local ok = pcall(function()
                        loadstring(inputBox.Text)()
                    end)
                    setStatusLight(ok and "success" or "fail")
                    showRunToast(ok)
                    inputBox:Destroy()
                end
            end)
        else
            local ok = pcall(function()
                loadstring(v.code)()
            end)
            setStatusLight(ok and "success" or "fail")
            showRunToast(ok)
        end
    end)
end
        
        
    else
        tip.Text = "密钥错误！"
        tip.TextColor3 = Color3.fromRGB(255,100,100)
    end
end)

-- 可选：按回车也能验证
input.FocusLost:Connect(function(enter)
    if enter then
        btn:Activate()
    end
end)