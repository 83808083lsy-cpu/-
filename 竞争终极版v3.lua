-- 竞争终极版.lua（已修改：移除轨迹夜光（PointLight），保留 Beam 视觉，已删除墙内扫描功能）
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Bindables = ReplicatedStorage:FindFirstChild("Bindables")

local ShootReplicate = Remotes:FindFirstChild("ShootReplicate")
local ThrowReplicate = Remotes:FindFirstChild("ThrowReplicate")
local ReportHit = Remotes:FindFirstChild("ReportHit")
local HitReplicate = Remotes:FindFirstChild("HitReplicate")
local BeginKnifeHideBindable = Bindables and Bindables:FindFirstChild("SetKnifeHideUntil")

local LocalPlayer = Players.LocalPlayer

--（保留你之前在 v4 中的极限速率设置；可按需调整）
local KNIFE_RATE = 0.00
local GUN_RATE = 2.4

local FIRE_RADIUS = 1000
local MUZZLE_OFFSET = 19.5
local MAX_ANGLE_DEG = 90

local TRACER_THICKNESS = 0.15
local TRACER_COLOR = Color3.fromRGB(255, 105, 180)
local TRACER_FADE_TIME = 10  -- 固定轨迹持续时间为 10 秒

local HIT_OFFSET = Vector3.new(0, 0, 0)
local WALL_PENETRATION_MAX = 1.5

local lastFireTimes = { knife = 0, gun = 0 }
local throwIdCounter = 0

local EffectsModule = nil
pcall(function() EffectsModule = require(ReplicatedStorage:FindFirstChild("Effect")) end)

local function safeRunEffect(effectName, params)
    if not EffectsModule then return false end
    if not EffectsModule.find or not EffectsModule.new then return false end
    local okFind = false
    pcall(function() okFind = EffectsModule.find(effectName) end)
    if not okFind then return false end
    local ok, eff = pcall(function() return EffectsModule.new(effectName) end)
    if not ok or not eff then return false end
    pcall(function() eff:replicate(params or {}) end)
    return true
end

local function getColorForOwner(ownerUserId)
    if ownerUserId == LocalPlayer.UserId then
        return TRACER_COLOR
    end
    local p = ownerUserId and Players:GetPlayerByUserId(ownerUserId) or nil
    if p == nil then
        return Color3.fromRGB(255,0,0)
    end
    local myTeam = LocalPlayer.Team
    if myTeam and p.Team and p.Team == myTeam then
        return Color3.fromRGB(0,255,0)
    else
        return Color3.fromRGB(255,0,0)
    end
end

local function randomColor()
    return Color3.fromHSV(math.random(), 0.6 + math.random()*0.4, 0.8 + math.random()*0.2)
end

local SETTINGS = {
    AutoFire = false,
    AutoKnife = false,
    AutoGun = false,
    WallCheck = true,
    MuzzleOffset = MUZZLE_OFFSET,
    FireRadius = 1000,
    ShowTracers = false,
    ShowFriendlyTracers = false,
    ShowEnemyTracers = false,
    ShowKnifeTracers = false,
    WallThickness = WALL_PENETRATION_MAX,
    HitRadius = 0,
    AttackNPCs = false,
    PlayHitSound = true,
    PlayHitSound1 = false,
    PlayHitSound2 = false,
    PlayHitSound3 = false,
    HitSoundId1 = "rbxassetid://5633695679",
    HitSoundId2 = "rbxassetid://8726881116",
    HitSoundId3 = "rbxassetid://4817809188",
    ShieldCheck = true,
    ScanRange = MUZZLE_OFFSET,
    -- 默认不自动播放音乐（脚本运行时会停止音乐）
    PlayMusic = false,
    MusicSoundId = "rbxassetid://133363390219538",
    MusicVolume = 2.5,
    MusicIndex = 1,
    -- 取消自动开启歌曲2：默认只启用曲目1
    MusicEnabled = { true, false, false },
    OneSecondTest = false,

    -- 新增开关
    RandomizeTracerColor = false,   -- 随机子弹轨迹颜色（悬浮窗开关）
    RandomizeThrowTracer = false,   -- 随机飞刀轨迹颜色
    AutoStopMusicOnRun = true       -- 脚本启动时自动停止音乐
}

local MUSIC_OPTIONS = {
    { name = "默认音乐", id = "rbxassetid://133363390219538" },
    { name = "音乐 2", id = "rbxassetid://110919391228823" },
    { name = "音乐 3", id = "rbxassetid://97285892199649" }
}

-- 随机选择已启用的曲目（若都未启用则从全部中随机）
local function getRandomEnabledMusicIndex()
    local enabled = {}
    for i = 1, #MUSIC_OPTIONS do
        if SETTINGS.MusicEnabled[i] then
            table.insert(enabled, i)
        end
    end
    if #enabled == 0 then
        for i = 1, #MUSIC_OPTIONS do table.insert(enabled, i) end
    end
    return enabled[math.random(1, #enabled)]
end

-- 如果当前索引无效或未启用，则随机选择一个
if typeof(SETTINGS.MusicIndex) ~= "number" or not SETTINGS.MusicEnabled[SETTINGS.MusicIndex] then
    SETTINGS.MusicIndex = getRandomEnabledMusicIndex()
end

local TOP_GUIS = {}
local TOP_DISPLAY_ORDER = 10000
local TOP_ZINDEX = 1000

local inputBlockCount = 0
local BLOCK_ACTION_NAME = "V67_BlockInput"

local function blockGameInput()
    if inputBlockCount == 0 then
        pcall(function()
            ContextActionService:BindAction(BLOCK_ACTION_NAME, function() return Enum.ContextActionResult.Sink end, false,
                Enum.UserInputType.Touch, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseMovement)
        end)
    end
    inputBlockCount = inputBlockCount + 1
end

local function unblockGameInput()
    if inputBlockCount <= 0 then return end
    inputBlockCount = inputBlockCount - 1
    if inputBlockCount == 0 then
        pcall(function() ContextActionService:UnbindAction(BLOCK_ACTION_NAME) end)
    end
end

local function enforceTopGui(screenGui)
    if not screenGui or not screenGui:IsA("ScreenGui") then return end
    pcall(function()
        screenGui.ResetOnSpawn = false
        screenGui.DisplayOrder = TOP_DISPLAY_ORDER
    end)
    local function setDescendantsZIndex()
        for _, obj in ipairs(screenGui:GetDescendants()) do
            if obj and obj:IsA("GuiObject") then
                pcall(function() obj.ZIndex = TOP_ZINDEX end)
            end
        end
    end
    setDescendantsZIndex()
    screenGui.DescendantAdded:Connect(function(desc)
        if desc and desc:IsA("GuiObject") then
            pcall(function() desc.ZIndex = TOP_ZINDEX end)
        end
    end)
    screenGui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
        pcall(function() screenGui.DisplayOrder = TOP_DISPLAY_ORDER end)
    end)
    screenGui.AncestryChanged:Connect(function(_, parent)
        local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not parent and playerGui then
            pcall(function() screenGui.Parent = playerGui end)
        end
        pcall(function() screenGui.DisplayOrder = TOP_DISPLAY_ORDER end)
    end)
end

local function registerTopGui(screenGui)
    if not screenGui or not screenGui:IsA("ScreenGui") then return end
    TOP_GUIS[screenGui] = true
    enforceTopGui(screenGui)
end

local enforcerAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
    enforcerAccumulator = enforcerAccumulator + dt
    if enforcerAccumulator < 0.5 then return end
    enforcerAccumulator = 0
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    for gui, _ in pairs(TOP_GUIS) do
        if gui and gui.Parent ~= playerGui then
            pcall(function() gui.Parent = playerGui end)
        end
        pcall(function() gui.DisplayOrder = TOP_DISPLAY_ORDER end)
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj and obj:IsA("GuiObject") then
                pcall(function() obj.ZIndex = TOP_ZINDEX end)
            end
        end
    end
end)

local baseMuzzleOffsets = {}
-- 移除“用尽后重置”的复杂状态：我们改为简单循环（轮询使用索引）
local muzzleCycleIndex = 1

-- 新增：记录每个偏移点最后一次被使用的时间，用于冷却
local offsetLastUsed = {}
local OFFSET_COOLDOWN = 0.5 -- 秒

local function markOffsetUsed(idx)
    if type(idx) == "number" then
        offsetLastUsed[idx] = tick()
    end
end

local function getNextUnusedIndex(startIdx)
    -- 改为简单的循环索引返回（不检查已用集合）
    local n = #baseMuzzleOffsets
    if n <= 0 then return 1 end
    startIdx = startIdx or muzzleCycleIndex
    local idx = ((startIdx - 1) % n) + 1
    -- 同步推进全局索引，确保下次更倾向不同索引（轮询）
    muzzleCycleIndex = (idx % n) + 1
    return idx
end

local function rebuildBaseMuzzleOffsets(scanRange)
    scanRange = scanRange or SETTINGS.MuzzleOffset
    baseMuzzleOffsets = {}

    -- 新增：将每次优先的向前偏移 10 单位放在列表开头（并保持其为首选）
    table.insert(baseMuzzleOffsets, Vector3.new(0, 0, 10))

    -- 保留一些中心/轴向点，保证近距离与垂直目标的覆盖
    -- 前后
    table.insert(baseMuzzleOffsets, Vector3.new(0, 0, math.clamp(scanRange * 0.5, 6, 20)))
    table.insert(baseMuzzleOffsets, Vector3.new(0, 0, -math.clamp(scanRange * 0.5, 6, 20)))
    -- 中心
    table.insert(baseMuzzleOffsets, Vector3.new(0, 0, 0))
    -- 上下
    table.insert(baseMuzzleOffsets, Vector3.new(0, scanRange * 0.5, 0))
    table.insert(baseMuzzleOffsets, Vector3.new(0, -scanRange * 0.5, 0))

    -- 新增：左右（X 方向）
    local lr = math.clamp(scanRange * 0.5, 6, 20)
    table.insert(baseMuzzleOffsets, Vector3.new(lr, 0, 0))
    table.insert(baseMuzzleOffsets, Vector3.new(-lr, 0, 0))

    -- 补上原本八角中“剩余的四个角” —— 按你的要求，这四个角的偏移采用“左右”的偏移值（即使用与左右相同的 X 偏移）
    table.insert(baseMuzzleOffsets, Vector3.new(lr, 0, 0))
    table.insert(baseMuzzleOffsets, Vector3.new(-lr, 0, 0))
    table.insert(baseMuzzleOffsets, Vector3.new(lr, 0, 0))
    table.insert(baseMuzzleOffsets, Vector3.new(-lr, 0, 0))

    -- 黄金角（Fermat 螺旋）采样，用于生成均匀分布的扫描点
    local N = math.clamp(64, 24, 128)
    local goldenAngle = math.pi * (3 - math.sqrt(5))
    for i = 1, N do
        local t = i - 0.5
        local r = (scanRange * math.sqrt(t / N))
        local ang = t * goldenAngle
        local x = math.cos(ang) * r
        local y = math.sin(ang) * r * (0.6 + 0.4 * ( (i % 3 == 0) and 1 or 0.8 ))
        local z = (math.sin(ang * 0.7) * 0.15 + (math.random() - 0.5) * 0.06) * scanRange
        table.insert(baseMuzzleOffsets, Vector3.new(x, y, z))
    end

    -- 添加一些随机散点，增加不可预测性
    for i = 1, 12 do
        local rr = scanRange * (0.3 + (i / 12) * 0.7)
        local ang = math.random() * math.pi * 2
        local x = math.cos(ang) * rr
        local y = math.sin(ang) * rr * ( (i % 2 == 0) and 1 or -1 ) * 0.5
        local z = (math.random() - 0.5) * scanRange * 0.25
        table.insert(baseMuzzleOffsets, Vector3.new(x, y, z))
    end
end
rebuildBaseMuzzleOffsets(SETTINGS.MuzzleOffset)

local function makeRayParams()
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.IgnoreWater = true
    return rp
end

local function insertTopByDist(arr, item, distSq, maxN)
    local n = #arr
    if n == 0 then
        arr[1] = {item = item, distSq = distSq}
        return
    end
    local inserted = false
    for i = 1, n do
        if distSq < arr[i].distSq then
            table.insert(arr, i, {item = item, distSq = distSq})
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(arr, {item = item, distSq = distSq})
    end
    if #arr > maxN then
        for i = #arr, maxN + 1, -1 do table.remove(arr, i) end
    end
end

local function insertTopByScore(arr, elem, score, maxN)
    local n = #arr
    if n == 0 then
        arr[1] = {elem = elem, score = score}
        return
    end
    if #arr >= maxN then
        local worst = arr[#arr].score
        if score <= worst then
            return
        end
    end
    local inserted = false
    for i = 1, n do
        if score > arr[i].score then
            table.insert(arr, i, {elem = elem, score = score})
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(arr, {elem = elem, score = score})
    end
    if #arr > maxN then
        for i = #arr, maxN + 1, -1 do table.remove(arr, i) end
    end
end

local rpTemplate = makeRayParams()
local clamp = math.clamp
local acos = math.acos
local deg = math.deg

local JITTERS = {Vector3.new(0,0,0), Vector3.new(0.5,0,0), Vector3.new(0,0.5,0), Vector3.new(0,-0.5,0)}
local VERTICAL_MATCH_THRESHOLD = 1.25
local OUTER_STEP_SIZE = 1
local MAX_OUTER_STEPS = 4
local MAX_START_TRIES = 6
local MAX_CANDIDATES = 6

local function shouldCreateTracerFor(ownerUserId, isKnife)
    if isKnife then
        if not SETTINGS.ShowKnifeTracers then return false end
    else
        if not SETTINGS.ShowTracers then return false end
    end
    if ownerUserId == nil then return true end
    if ownerUserId == LocalPlayer.UserId then return true end
    local p = Players:GetPlayerByUserId(ownerUserId)
    if not p then return true end
    local myTeam = LocalPlayer.Team
    if myTeam and p.Team and p.Team == myTeam then
        return SETTINGS.ShowFriendlyTracers
    else
        return SETTINGS.ShowEnemyTracers
    end
end

-- createTracer 保持 Beam，但移除夜光（PointLight / 中间光源）
local function createTracer(startPos, endPos, color, thickness, fadeTime, ownerUserId, isKnife)
    if not startPos or not endPos then return end
    if not shouldCreateTracerFor(ownerUserId, isKnife) then
        return nil
    end

    local useColor = color
    if SETTINGS.RandomizeTracerColor and not isKnife then
        useColor = randomColor()
    elseif not useColor then
        useColor = getColorForOwner(ownerUserId)
    end

    local cam = workspace.CurrentCamera
    if not cam then
        local dir = endPos - startPos
        local dist = dir.Magnitude
        if dist <= 0 then return end
        local part = Instance.new("Part")
        part.Name = "BulletTracer"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Size = Vector3.new(thickness or TRACER_THICKNESS, thickness or TRACER_THICKNESS, dist)
        part.Material = Enum.Material.Neon
        part.Color = useColor
        part.Transparency = 0
        part.CastShadow = false
        part.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -dist/2)
        part.Parent = workspace
        local tweenInfo = TweenInfo.new(fadeTime or TRACER_FADE_TIME, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(part, tweenInfo, {Transparency = 1})
        tween:Play()
        Debris:AddItem(part, (fadeTime or TRACER_FADE_TIME) + 0.1)
        return part
    end

    local dir = endPos - startPos
    local dist = dir.Magnitude
    if dist <= 0.01 then
        dist = 0.05
    end

    local binParent = workspace:FindFirstChild("Bin") or workspace

    local part0 = Instance.new("Part")
    part0.Name = "Tracer_Att_Part0"
    part0.Anchored = true
    part0.CanCollide = false
    part0.CanQuery = false
    part0.CanTouch = false
    part0.Size = Vector3.new(0.2, 0.2, 0.2)
    part0.Transparency = 1
    part0.CFrame = CFrame.new(startPos)
    part0.Parent = binParent

    local part1 = Instance.new("Part")
    part1.Name = "Tracer_Att_Part1"
    part1.Anchored = true
    part1.CanCollide = false
    part1.CanQuery = false
    part1.CanTouch = false
    part1.Size = Vector3.new(0.2, 0.2, 0.2)
    part1.Transparency = 1
    part1.CFrame = CFrame.new(endPos)
    part1.Parent = binParent

    local att0 = Instance.new("Attachment")
    att0.Name = "Tracer_Att_0"
    att0.Parent = part0

    local att1 = Instance.new("Attachment")
    att1.Name = "Tracer_Att_1"
    att1.Parent = part1

    local beam = Instance.new("Beam")
    beam.Name = "V67_TracerBeam"
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Width0 = thickness or TRACER_THICKNESS
    beam.Width1 = thickness or TRACER_THICKNESS
    beam.FaceCamera = true
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.LightInfluence = 1
    local beamColor = useColor or getColorForOwner(ownerUserId)
    beam.Color = ColorSequence.new(beamColor)
    beam.Transparency = NumberSequence.new(0)

    beam.Parent = part0

    local totalFade = (fadeTime or TRACER_FADE_TIME) or TRACER_FADE_TIME
    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        local elapsed = tick() - startTime
        local frac = math.clamp(elapsed / totalFade, 0, 1)
        local curTrans = NumberSequence.new(frac)
        pcall(function() beam.Transparency = curTrans end)
        if frac >= 1 then
            pcall(function() conn:Disconnect() end)
            pcall(function() beam:Destroy() end)
            pcall(function() att0:Destroy() end)
            pcall(function() att1:Destroy() end)
            pcall(function() part0:Destroy() end)
            pcall(function() part1:Destroy() end)
        end
    end)

    Debris:AddItem(part0, totalFade + 1)
    Debris:AddItem(part1, totalFade + 1)

    return beam
end

local function playHitSoundAt(pos)
    if not SETTINGS.PlayHitSound then return end
    if typeof(pos) ~= "Vector3" then return end
    if not SETTINGS.PlayHitSound1 and not SETTINGS.PlayHitSound2 and not SETTINGS.PlayHitSound3 then return end

    local part = Instance.new("Part")
    part.Name = "V67_HitSound"
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(1,1,1)
    part.CFrame = CFrame.new(pos)
    part.Parent = workspace:FindFirstChild("Bin") or workspace

    local function makeAndPlay(soundId)
        if typeof(soundId) ~= "string" or soundId == "" then return end
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        local vol = 1
        if SETTINGS.HitSoundId1 and soundId == SETTINGS.HitSoundId1 then
            vol = 1
        else
            vol = 1.8
        end
        sound.Volume = vol
        sound.PlaybackSpeed = 1
        sound.Looped = false
        sound.RollOffMode = Enum.RollOffMode.Linear
        sound.MaxDistance = 800
        sound.Parent = part
        pcall(function() sound:Play() end)
    end

    if SETTINGS.PlayHitSound1 then
        makeAndPlay(SETTINGS.HitSoundId1)
    end
    if SETTINGS.PlayHitSound2 then
        makeAndPlay(SETTINGS.HitSoundId2)
    end
    if SETTINGS.PlayHitSound3 then
        makeAndPlay(SETTINGS.HitSoundId3)
    end

    Debris:AddItem(part, 5)
end

local currentMusicSound = nil
local currentMusicConn = nil

local function stopMusic()
    if currentMusicConn then
        pcall(function() currentMusicConn:Disconnect() end)
        currentMusicConn = nil
    end
    if currentMusicSound then
        pcall(function() currentMusicSound:Stop() end)
        pcall(function() currentMusicSound:Destroy() end)
        currentMusicSound = nil
    end
end

local function getMusicIdForIndex(idx)
    if typeof(idx) ~= "number" then return nil end
    local opt = MUSIC_OPTIONS[idx]
    if opt and typeof(opt.id) == "string" and opt.id ~= "" then
        return opt.id
    end
    if typeof(SETTINGS.MusicSoundId) == "string" and SETTINGS.MusicSoundId ~= "" then
        return SETTINGS.MusicSoundId
    end
    return nil
end

local function findFirstEnabledIndex()
    for i = 1, #MUSIC_OPTIONS do
        if SETTINGS.MusicEnabled[i] then
            return i
        end
    end
    return nil
end

local function playMusic()
    stopMusic()
    if not SETTINGS.PlayMusic then return end
    local idx = SETTINGS.MusicIndex
    -- 如果当前索引不可用，则随机选一个启用曲目
    if not SETTINGS.MusicEnabled[idx] then
        idx = getRandomEnabledMusicIndex()
        SETTINGS.MusicIndex = idx
    end
    local id = getMusicIdForIndex(idx)
    if not id then return end
    local sound = Instance.new("Sound")
    sound.Name = "V67_MusicSound"
    sound.SoundId = id
    sound.Volume = SETTINGS.MusicVolume or 1.25
    sound.PlaybackSpeed = 1
    sound.Looped = false
    sound.RollOffMode = Enum.RollOffMode.Inverse
    sound.MaxDistance = 100000
    sound.Parent = SoundService
    currentMusicSound = sound
    pcall(function() sound:Play() end)
    currentMusicConn = sound.Ended:Connect(function()
        currentMusicConn = nil
        currentMusicSound = nil
        if SETTINGS.PlayMusic then
            task.delay(0.12, playMusic)
        end
    end)
end

local function setMusicIndex(idx)
    if typeof(idx) ~= "number" then return end
    idx = math.clamp(idx, 1, #MUSIC_OPTIONS)
    SETTINGS.MusicIndex = idx
    if SETTINGS.PlayMusic then
        pcall(playMusic)
    end
end

local function nudgeStartOutOfWall(startPos, hitPos, ignoreList, maxAttempts)
    maxAttempts = maxAttempts or 8
    local dirOut = (startPos - hitPos)
    if dirOut.Magnitude < 0.01 then
        dirOut = Vector3.new(0,1,0)
    end
    local unit = dirOut.Unit
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = ignoreList
    rp.IgnoreWater = true
    local cur = startPos
    for i = 1, maxAttempts do
        local smallCheck = workspace:Raycast(cur, unit * 0.15, rp)
        if not smallCheck then
            return cur
        end
        cur = cur + unit * 0.15
    end
    local side = Vector3.new(-unit.Z, 0, unit.X)
    cur = startPos
    for i = 1, maxAttempts do
        local attempt = cur + side * (0.2 * i)
        local smallCheck2 = workspace:Raycast(attempt, unit * 0.12, rp)
        if not smallCheck2 then
            return attempt
        end
    end
    return nil
end

local function findViableStart(localCFrame, localOffset, localPos, hitPos, rp, targetCharacter, forward)
    local ignoreList = rp and rp.FilterDescendantsInstances or {}
    local function testStart(trialLocal)
        local trialStart = (localCFrame * CFrame.new(trialLocal)).Position
        local dir = hitPos - trialStart
        local dirMagSq = dir.X*dir.X + dir.Y*dir.Y + dir.Z*dir.Z
        if dirMagSq <= 0 then
            return trialStart, trialLocal
        end
        local rayRes = workspace:Raycast(trialStart, dir, rp)
        if not rayRes then
            local small = workspace:Raycast(trialStart, forward * 0.12, rp)
            if small and not (small.Instance and small.Instance:IsDescendantOf(targetCharacter)) then
                local nudged = nudgeStartOutOfWall(trialStart, hitPos, ignoreList, 8)
                if nudged then
                    return nudged, (localCFrame:PointToObjectSpace(nudged))
                end
                return nil
            end
            return trialStart, trialLocal
        end
        local hitInstance = rayRes.Instance
        if hitInstance and hitInstance:IsDescendantOf(targetCharacter) then
            return trialStart, trialLocal
        end

        -- 已删除：不再支持“从墙内扫描”的分支（不会在此处接受 nudged 起点）

        local reverseDir = trialStart - hitPos
        local reverseRes = workspace:Raycast(hitPos, reverseDir, rp)
        if reverseRes and reverseRes.Instance == hitInstance then
            local thickness = (reverseRes.Position - rayRes.Position).Magnitude
            local allowed = SETTINGS.WallThickness or WALL_PENETRATION_MAX
            if thickness <= allowed then
                return trialStart, trialLocal
            end
        end
        return nil
    end

    for _, jitter in ipairs(JITTERS) do
        local trialLocal = localOffset + jitter * 0.2
        local okStart, okLocal = testStart(trialLocal)
        if okStart then return okStart, okLocal end
    end

    local originStart = (localCFrame * CFrame.new(localOffset)).Position
    local dirOut = originStart - localPos
    local dirOutMag = dirOut.Magnitude
    if dirOutMag < 0.1 then
        dirOut = forward
        dirOutMag = dirOut.Magnitude
    end
    if dirOutMag > 0 then
        local dirUnit = dirOut.Unit
        for step = 1, MAX_OUTER_STEPS do
            local move = dirUnit * (step * OUTER_STEP_SIZE)
            local trialLocal2 = localOffset + move
            local okStart2, okLocal2 = testStart(trialLocal2)
            if okStart2 then return okStart2, okLocal2 end
        end
        local side = Vector3.new(-dirUnit.Z, 0, dirUnit.X)
        for step = 1, math.max(2, math.floor(MAX_OUTER_STEPS/2)) do
            local move = side * (step * OUTER_STEP_SIZE)
            local trialLocal3 = localOffset + move
            local okStart3, okLocal3 = testStart(trialLocal3)
            if okStart3 then return okStart3, okLocal3 end
        end
    end

    return nil
end

local playerCharacterData = {}

local function setRigLocalVisible(rigModel, visible)
    if not rigModel then return end
    for _, v in rigModel:QueryDescendants("BasePart, ParticleEmitter, Beam, PointLight, SurfaceLight, SpotLight, Decal, Texture") do
        if not v.Parent or v.Parent.Name ~= "RevolverMuzzle" then
            if v:IsA("BasePart") then
                v.LocalTransparencyModifier = visible and 0 or 1
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.LocalTransparencyModifier = visible and 0 or 1
            elseif v:IsA("ParticleEmitter") then
                if not (v:GetAttribute("EmitCount") or v:GetAttribute("FromAbilityCast")) then
                    v.Enabled = visible
                    if not visible then v:Clear() end
                end
            else
                if v:IsA("Beam") or v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                    v.Enabled = visible
                end
            end
        end
    end
end

local function applyVisibilityToData(d)
    if not d then return end
    local now = workspace:GetServerTimeNow()
    local shouldBeHidden = now < (d.hideUntil or 0)
    local clientVisibleForThis = not shouldBeHidden
    if d.knifeRig then
        local desired = clientVisibleForThis and true or false
        if d.knifeRig:GetAttribute("ClientVisible") ~= desired then
            d.knifeRig:SetAttribute("ClientVisible", desired)
            setRigLocalVisible(d.knifeRig, desired)
        end
    end
    if d.revolverRig then
        local desired = clientVisibleForThis and true or false
        if d.revolverRig:GetAttribute("ClientVisible") ~= desired then
            d.revolverRig:SetAttribute("ClientVisible", desired)
            setRigLocalVisible(d.revolverRig, desired)
        end
    end
end

local function ensureSkinsForData(d)
    local KnivesFolder = ReplicatedStorage:FindFirstChild("Knives")
    local RevolversFolder = ReplicatedStorage:FindFirstChild("Revolvers")
    if not d or not d.player then return end
    local knifeSkin = d.player:GetAttribute("KnifeSkin") or "Default"
    local revolverSkin = d.player:GetAttribute("RevolverSkin") or "Default"
    if KnivesFolder and (knifeSkin ~= d.lastKnifeSkin or not (d.knifeRig and d.knifeRig.Parent)) then
        local template = KnivesFolder:FindFirstChild(knifeSkin) or KnivesFolder:FindFirstChild("Default")
        if template and template:IsA("Model") then
            if d.knifeRig then d.knifeRig:Destroy() end
            local clone = template:Clone()
            clone.Name = "KnifeRig"
            clone.Parent = d.character
            d.knifeRig = clone
            d.knifeRoot = clone:FindFirstChild("KnifeRoot") or clone.PrimaryPart
            d.lastKnifeSkin = knifeSkin
        end
    end
    if RevolversFolder and (revolverSkin ~= d.lastRevolverSkin or not (d.revolverRig and d.revolverRig.Parent)) then
        local template = RevolversFolder:FindFirstChild(revolverSkin) or RevolversFolder:FindFirstChild("Default")
        if template and template:IsA("Model") then
            if d.revolverRig then d.revolverRig:Destroy() end
            local clone = template:Clone()
            clone.Name = "RevolverRig"
            clone.Parent = d.character
            d.revolverRig = clone
            d.revolverRoot = clone:FindFirstChild("RevolverRoot") or clone.PrimaryPart
            d.lastRevolverSkin = revolverSkin
        end
    end
end

local function updateAttachmentsForData(d)
    if not d then return end
    ensureSkinsForData(d)
    if d.knifeRoot and d.rightArm then
        local attach = d.character:FindFirstChild("Knife_HandAttach")
        if attach == nil then
            attach = Instance.new("Motor6D")
            attach.Name = "Knife_HandAttach"
            attach.Part0 = d.rightArm
            attach.Part1 = d.knifeRoot
            attach.Parent = d.rightArm
            attach.C0 = CFrame.new(0, -d.rightArm.Size.Y/2, 0) * CFrame.Angles(-math.pi/2, 0, 0)
            attach.C1 = CFrame.new(0, -1, -0.1)
        end
    end
    if d.revolverRoot and d.rightArm then
        local attach = d.character:FindFirstChild("Revolver_HandAttach")
        if attach == nil then
            attach = Instance.new("Motor6D")
            attach.Name = "Revolver_HandAttach"
            attach.Part0 = d.rightArm
            attach.Part1 = d.revolverRoot
            attach.Parent = d.rightArm
            attach.C0 = CFrame.new(0, -d.rightArm.Size.Y/2 + 0.15, -0.35) * CFrame.Angles(-math.pi/2, 0, 0)
            attach.C1 = CFrame.new(0, 0, 0)
        end
    end
    applyVisibilityToData(d)
end

local function bindCharacter(playerOrProxy, character)
    if not (character and character:IsA("Model")) then return end
    local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm") or character:FindFirstChild("RightHand")
    if not rightArm then
        local start = os.clock()
        while os.clock() - start < 10 do
            rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm") or character:FindFirstChild("RightHand")
            if rightArm then break end
            task.wait(0.03)
            if not character.Parent then return end
        end
    end
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    if not torso then return end
    local d = {
        player = playerOrProxy,
        character = character,
        rightArm = rightArm,
        torso = torso,
        maid = {},
        knifeRig = nil,
        revolverRig = nil,
        knifeRoot = nil,
        revolverRoot = nil,
        hideUntil = 0,
        hideNonce = -1,
        lastKnifeSkin = "",
        lastRevolverSkin = "",
        lastKnifeEquipped = false,
        lastRevolverEquipped = false
    }
    playerCharacterData[character] = d
    if typeof(playerOrProxy) == "Instance" and playerOrProxy:IsA("Player") then
        table.insert(d.maid, playerOrProxy:GetAttributeChangedSignal("KnifeSkin"):Connect(function() updateAttachmentsForData(d) end))
        table.insert(d.maid, playerOrProxy:GetAttributeChangedSignal("RevolverSkin"):Connect(function() updateAttachmentsForData(d) end))
        table.insert(d.maid, playerOrProxy:GetAttributeChangedSignal("InMatch"):Connect(function() updateAttachmentsForData(d) end))
    end
    table.insert(d.maid, character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            for _, c in ipairs(d.maid) do
                pcall(function() c:Disconnect() end)
            end
            playerCharacterData[character] = nil
        end
    end))
    updateAttachmentsForData(d)
end

local function applyHideUntil(userId, hideUntil, nonce)
    for character, d in pairs(playerCharacterData) do
        local p = d.player
        local uid = nil
        if typeof(p) == "Instance" and p:IsA("Player") then
            uid = p.UserId
        elseif typeof(p) == "table" and p.UserId then
            uid = p.UserId
        end
        if uid == userId and d.hideNonce <= nonce then
            d.hideNonce = nonce
            d.hideUntil = hideUntil
            applyVisibilityToData(d)
        end
    end
end

if BeginKnifeHideBindable and BeginKnifeHideBindable:IsA("BindableEvent") then
    BeginKnifeHideBindable.Event:Connect(function(uId, hideUntil, nonce)
        if typeof(uId) == "number" and typeof(hideUntil) == "number" then
            applyHideUntil(uId, hideUntil, (typeof(nonce) == "number" and nonce) or 0)
        end
    end)
end

local KnifeRigHideUntil = Remotes:FindFirstChild("KnifeRigHideUntil")
if KnifeRigHideUntil and KnifeRigHideUntil:IsA("RemoteEvent") then
    KnifeRigHideUntil.OnClientEvent:Connect(function(tbl)
        if typeof(tbl) == "table" then
            local u = tbl.userId
            local hu = tbl.hideUntil
            local n = tbl.nonce
            if typeof(u) == "number" and typeof(hu) == "number" then
                applyHideUntil(u, hu, (typeof(n) == "number" and n) or 0)
            end
        end
    end)
end

for _, pl in ipairs(Players:GetPlayers()) do
    if pl.Character then
        bindCharacter(pl, pl.Character)
    end
    pl.CharacterAdded:Connect(function(c) bindCharacter(pl, c) end)
end
Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function(c) bindCharacter(pl, c) end)
end)

if workspace:FindFirstChild("Characters") then
    for _, ch in ipairs(workspace.Characters:GetChildren()) do
        local decoyOwnerName = ch:GetAttribute("Decoy")
        if decoyOwnerName then
            local pl = Players:FindFirstChild(ch.Name)
            if pl then bindCharacter(pl, ch) end
        elseif ch:GetAttribute("BotMatchBot") == true then
            local proxy = {
                UserId = ch:GetAttribute("BotUserId") or -1,
                Character = ch,
                GetAttribute = function(_, k) return ch:GetAttribute(k) end,
                GetAttributeChangedSignal = function(_, k) return ch:GetAttributeChangedSignal(k) end,
                AttributeChanged = ch.AttributeChanged,
                IsA = function(_, tp) return tp == "Player" end
            }
            bindCharacter(proxy, ch)
        end
    end
end

local UtilMisc = nil
local ViewedPlayer = nil
local Destructibles = nil
local WeaponAuthConfig = nil
pcall(function() UtilMisc = require(ReplicatedStorage:FindFirstChild("Util") and ReplicatedStorage.Util:FindFirstChild("Misc")) end)
pcall(function() ViewedPlayer = require(ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("ViewedPlayer")) end)
pcall(function() Destructibles = require(ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Destructibles")) end)
pcall(function() WeaponAuthConfig = require(ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("WeaponAuthConfig")) end)

local function getRevolverMuzzlePosition(character)
    if character and character:FindFirstChild("RevolverRig") then
        local muzzle = character.RevolverRig:FindFirstChild("RevolverMuzzle", true)
        if muzzle and muzzle:IsA("Attachment") then
            return muzzle.WorldPosition
        end
    end
    local right = character and (character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand"))
    if right and right:IsA("BasePart") then
        return right.Position - right.CFrame.UpVector/2 + right.CFrame.LookVector * 0.5
    end
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position + hrp.CFrame.LookVector * 2
    end
    return Vector3.new(0,0,0)
end

local function consumeDestructiblesAlongSegment(from, to, ignoreList, ownerUserId)
    local dir = to - from
    local len = dir.Magnitude
    if len <= 0.05 then return end
    local unit = dir.Unit
    local cur = from
    local remain = len
    while remain > 0.05 do
        local endPt = to
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = ignoreList
        rp.IgnoreWater = true
        local res = workspace:Raycast(cur, endPt - cur, rp)
        if not res then return end
        local inst = res.Instance
        if inst then
            local kind = (Destructibles and Destructibles.GetHitKind and Destructibles.GetHitKind(inst)) or "none"
            if kind ~= "none" then
                safeRunEffect("TargetBreak", {["HitPart"] = inst, ["Position"] = res.Position})
            end
        end
        cur = res.Position + unit * 0.05
        remain = (to - cur).Magnitude
    end
end

local function makeBulletTracerAndEffects(from, to, fxName, hitPart, ownerUserId)
    createTracer(from, to, nil, nil, TRACER_FADE_TIME, ownerUserId, false)
    safeRunEffect("BulletEffects." .. (fxName or "Default"), {
        ["CFrame"] = CFrame.new(from, to),
        ["Origin"] = from,
        ["HitPos"] = to,
        ["HitPart"] = hitPart
    })
end

local function spawnBulletSimple(data, ply)
    if typeof(data) ~= "table" then return end
    local ownerUserId = data.ownerUserId
    local origin = data.origin
    if typeof(origin) ~= "Vector3" then
        local player = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
        origin = player and player.Character and getRevolverMuzzlePosition(player.Character) or origin
    end
    local to = data.hitPos or data.to or data.target
    if typeof(origin) ~= "Vector3" or typeof(to) ~= "Vector3" then return end
    local ignoreList = { workspace.Characters, workspace.Bin }
    consumeDestructiblesAlongSegment(origin, to, ignoreList, ownerUserId)
    makeBulletTracerAndEffects(origin, to, data.bulletFx or nil, data.hitInstance, ownerUserId)
    if data.isCharacterHit == true and data.hitInstance then
        safeRunEffect("CharacterHit", {
            ["CFrame"] = CFrame.new(to, to + (data.hitNormal or Vector3.new(0,1,0))),
            ["Character"] = data.hitInstance.Parent,
            ["Limb"] = data.hitInstance
        })
    end
end

local function spawnKnifeSimple(tbl)
    if typeof(tbl) ~= "table" then return end
    local origin = tbl.origin
    local target = tbl.target
    local skin = tbl.skin or "Default"
    local ownerUserId = tbl.ownerUserId
    if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then return end

    local dir = target - origin
    local distance = dir.Magnitude
    if distance <= 0.01 then
        createTracer(origin, target, nil, 0.12, TRACER_FADE_TIME, ownerUserId, true)
        safeRunEffect("ThrowEffects.Default", {["Knife"] = nil, ["Origin"] = origin, ["HitPos"] = target})
        return
    end

    local workspaceGravity = (workspace and workspace.Gravity) or 196.2
    local g = Vector3.new(0, -workspaceGravity, 0)
    local power = (type(tbl.power) == "number" and tbl.power) or 1
    local randFactor = 0.9 + (math.random() * 0.2)
    local effectivePower = math.max(0.01, power * randFactor)
    local time = math.clamp(distance / (40 * effectivePower), 0.12, 3.0)

    local v0 = (target - origin - 0.5 * g * (time * time)) / time

    local visual = Instance.new("Part")
    visual.Name = "ThrownKnifeVisual"
    visual.Anchored = true
    visual.CanCollide = false
    visual.CanQuery = false
    visual.CanTouch = false
    visual.Size = Vector3.new(0.25, 0.1, 0.6)
    visual.Material = Enum.Material.Metal
    visual.Color = getColorForOwner(ownerUserId)
    visual.CastShadow = false
    visual.Parent = workspace:FindFirstChild("Bin") or workspace
    Debris:AddItem(visual, time + 4)

    -- 若启用随机飞刀轨迹色，则覆盖颜色
    local tracerColor = visual.Color
    if SETTINGS.RandomizeThrowTracer then
        tracerColor = randomColor()
    end

    -- 强制轨迹持续时间为 TRACER_FADE_TIME（即 10 秒）
    createTracer(origin, target, tracerColor, 0.12, TRACER_FADE_TIME, ownerUserId, true)
    safeRunEffect("ThrowEffects.Default", {["Knife"] = visual, ["Origin"] = origin, ["HitPos"] = target})

    spawn(function()
        local t = 0
        local prevPos = origin
        while t <= time do
            local pos = origin + v0 * t + 0.5 * g * (t * t)
            local vel = v0 + g * t
            local look = pos + (vel.Magnitude > 0.001 and vel.Unit or (target - pos).Unit)
            pcall(function()
                visual.CFrame = CFrame.new(pos, look) * CFrame.Angles(math.rad(90), 0, 0)
            end)
            prevPos = pos
            local dt = RunService.Heartbeat:Wait()
            t = t + dt
        end
        pcall(function()
            safeRunEffect("ThrowHit", {["CFrame"] = CFrame.new(target), ["HitPart"] = nil})
        end)
        pcall(function() visual:Destroy() end)
    end)
end

local SpawnKnifeBindable = Bindables and Bindables:FindFirstChild("SpawnKnife")
local SpawnBulletBindable = Bindables and Bindables:FindFirstChild("SpawnBullet")
if SpawnKnifeBindable and SpawnKnifeBindable:IsA("BindableEvent") then
    SpawnKnifeBindable.Event:Connect(spawnKnifeSimple)
end
if ThrowReplicate and ThrowReplicate:IsA("RemoteEvent") then
    ThrowReplicate.OnClientEvent:Connect(spawnKnifeSimple)
end
if SpawnBulletBindable and SpawnBulletBindable:IsA("BindableEvent") then
    SpawnBulletBindable.Event:Connect(function(tbl) spawnBulletSimple(tbl, nil) end)
end
if ShootReplicate and ShootReplicate:IsA("RemoteEvent") then
    ShootReplicate.OnClientEvent:Connect(function(tbl, ply) spawnBulletSimple(tbl, ply) end)
end
if HitReplicate and HitReplicate:IsA("RemoteEvent") then
    HitReplicate.OnClientEvent:Connect(function(hitTbl, fromPlayer)
        if typeof(hitTbl) == "table" and tostring(hitTbl.kind) == "throw" then
            safeRunEffect("ThrowHit", {["CFrame"] = CFrame.new(hitTbl.hitPos or Vector3.new(0,0,0)), ["HitPart"] = hitTbl.hitPart})
            if typeof(hitTbl.hitPos) == "Vector3" then
                pcall(function()
                    local owner = hitTbl.ownerUserId
                    if not owner then
                        if typeof(fromPlayer) == "Instance" and fromPlayer.UserId then owner = fromPlayer.UserId end
                    end
                    if owner == LocalPlayer.UserId then
                        playHitSoundAt(hitTbl.hitPos)
                    end
                end)
            end
        else
            if typeof(hitTbl) == "table" and typeof(hitTbl.hitPos) == "Vector3" then
                safeRunEffect("BulletHit", {["CFrame"] = CFrame.new(hitTbl.hitPos), ["HitPart"] = hitTbl.hitPart})
                pcall(function()
                    local owner = hitTbl.ownerUserId
                    if not owner then
                        if typeof(fromPlayer) == "Instance" and fromPlayer.UserId then owner = fromPlayer.UserId end
                    end
                    if owner == LocalPlayer.UserId then
                        playHitSoundAt(hitTbl.hitPos)
                    end
                end)
            end
        end
    end)
end

local lastSuccessfulPoints = {}

local function hasActiveShield(character)
    if not character or not character.Parent then return false end
    local ok, res = pcall(function()
        if character:FindFirstChildOfClass("ForceField") then return true end
        if character.GetAttribute then
            local a1 = character:GetAttribute("Shield")
            if a1 == true then return true end
            local a2 = character:GetAttribute("ShieldActive")
            if a2 == true then return true end
            local a3 = character:GetAttribute("HasShield")
            if a3 == true then return true end
        end
        local sh = character:FindFirstChild("Shield")
        if sh then
            if sh:IsA("BoolValue") and sh.Value == true then return true end
            return true
        end
        return false
    end)
    return ok and res or false
end

-- 新增：为外环采样（命中半径边缘）生成候选点
local function GetOffsets_Outer(center, poleDir, radius, count)
    if not radius or radius <= 0 or not count or count <= 0 then return {center} end
    local offsets = {}
    local arb = math.abs(poleDir.X) < 0.9 and Vector3.new(1,0,0) or Vector3.new(0,1,0)
    local t1 = poleDir:Cross(arb)
    if t1.Magnitude == 0 then
        arb = Vector3.new(0,0,1)
        t1 = poleDir:Cross(arb)
    end
    t1 = t1.Unit
    local t2 = poleDir:Cross(t1).Unit

    for i = 1, count do
        local theta = (2 * math.pi) * (i / count) + (math.random() - 0.5) * (2*math.pi / count) * 0.05
        local offsetVec = t1 * (math.cos(theta) * radius) + t2 * (math.sin(theta) * radius)
        table.insert(offsets, center + offsetVec)
    end
    return offsets
end

-- 旧的 GetOffsets_Algo1/2 保留（DoRagebot 可能使用）
local ScanVectors = {
    Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0),
    -Vector3.new(1, 0, 0), -Vector3.new(0, 0, 1), -Vector3.new(0, 1, 0),
    Vector3.new(1, 1, 0)/math.sqrt(2), Vector3.new(1, 0, 1)/math.sqrt(2), Vector3.new(0, 1, 1)/math.sqrt(2),
    Vector3.new(-1, 1, 0)/math.sqrt(2), Vector3.new(-1, 0, 1)/math.sqrt(2),
    -Vector3.new(1, 0, 1)/math.sqrt(2), -Vector3.new(-1, 0, 1)/math.sqrt(2), -Vector3.new(0, -1, 1)/math.sqrt(2),
    Vector3.new(1, 1, 1)/math.sqrt(3), Vector3.new(-1, 1, 1)/math.sqrt(3), Vector3.new(1, 1, -1)/math.sqrt(3),
    -Vector3.new(1, 1, 1)/math.sqrt(3), -Vector3.new(1, -1, 1)/math.sqrt(3),
    Vector3.new(1,2,0)/math.sqrt(5), Vector3.new(-1,2,0)/math.sqrt(5), Vector3.new(1,0,2)/math.sqrt(5), Vector3.new(-1,0,2)/math.sqrt(5),
    -Vector3.new(-1,0,2)/math.sqrt(5), -Vector3.new(1,0,2)/math.sqrt(5),
}

local function GetOffsets_Algo1(firePos, targetPos, offset)
    if not offset or offset <= 0 then return {firePos} end
    local offsets = {firePos}
    local cfOffset = CFrame.new(firePos, targetPos) * CFrame.Angles(0, 0, math.rad(math.random(1, 90)))
    for _, pos in ipairs(ScanVectors) do
        table.insert(offsets, (cfOffset * (pos * offset)).p)
    end
    return offsets
end

local function GetOffsets_Algo2(center, poleDir, radius, count)
    if not radius or radius <= 0 or not count or count <= 0 then return {center} end
    local offsets = {center}
    local arb = math.abs(poleDir.X) < 0.9 and Vector3.new(1,0,0) or Vector3.new(0,1,0)
    local t1 = poleDir:Cross(arb)
    if t1.Magnitude == 0 then
        arb = Vector3.new(0,0,1)
        t1 = poleDir:Cross(arb)
    end
    t1 = t1.Unit
    local t2 = poleDir:Cross(t1).Unit

    for i = 1, count do
        local theta = (2 * math.pi) * (i / count) + (math.random() - 0.5) * (2*math.pi / count)
        local r = radius * math.sqrt(math.random())
        local offsetVec = t1 * (math.cos(theta) * r) + t2 * (math.sin(theta) * r)
        table.insert(offsets, center + offsetVec)
    end
    return offsets
end

-- DoRagebot（保持原有逻辑/可选加速）——若环境存在外部函数则有用
local RB_State = RB_State
local Valid_Pair = Valid_Pair
local Locked_Path = Locked_Path
local Origin_Radius = Origin_Radius or 3
local Hit_Radius = Hit_Radius or 1.5
local Origin_Scans = Origin_Scans or 64
local Hit_Scans = Hit_Scans or 32
local ScanRate = ScanRate or 120
local WB = WB or { LastScan = 0, Threshold = 0.05, Cached = false, Round = 0 }

local function DoRagebot()
    if not RB_State then Valid_Pair = nil; Locked_Path = nil; return end
    local target = GetTarget()
    if not target or not target.Character then Valid_Pair = nil; Locked_Path = nil; return end
    if Locked_Path and Locked_Path.Target ~= target then Locked_Path = nil end

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local tRoot  = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tRoot then return end
    local myPos = GetLocalRealPosition()
    local tPos = tRoot.Position

    if Locked_Path then
        local dO = (myPos - Locked_Path.MyPos).Magnitude
        local dH = (tPos - Locked_Path.TPos).Magnitude
        local inRange = (myPos - Locked_Path.AbsO).Magnitude <= Origin_Radius
                      and (tPos - Locked_Path.AbsH).Magnitude <= Hit_Radius
        if dO <= WB.Threshold and dH <= WB.Threshold and inRange then
            if CheckWallbang(Locked_Path.AbsO, Locked_Path.AbsH) then
                Valid_Pair = {Origin = Locked_Path.AbsO, Hit = Locked_Path.AbsH, Target = target}
                WB.Cached = true
                return
            end
        end
        Locked_Path = nil
    end

    if tick() - WB.LastScan < 1 / ScanRate then return end
    WB.LastScan = tick()
    WB.Round = (WB.Round or 0) + 1

    local newOrigin, newTarget
    if WB.Round % 2 == 0 then
        newOrigin = GetOffsets_Algo1(myPos, tPos, Origin_Radius)
        newTarget = GetOffsets_Algo1(tPos, myPos, Hit_Radius)
    else
        local oPole = (tPos - myPos)
        if oPole.Magnitude < 0.001 then return end
        oPole = oPole.Unit
        local hPole = -oPole
        newOrigin = GetOffsets_Algo2(myPos, oPole, Origin_Radius, Origin_Scans)
        newTarget = GetOffsets_Algo2(tPos, hPole, Hit_Radius, Hit_Scans)
    end

    local bestPO, bestPH = nil, nil
    for _, pO in ipairs(newOrigin) do
        for _, pH in ipairs(newTarget) do
            if CheckWallbang(pO, pH) then
                bestPO = pO
                bestPH = pH
                break
            end
        end
        if bestPO then break end
    end

    if bestPO then
        Locked_Path = {AbsO = bestPO, AbsH = bestPH, Target = target, MyPos = myPos, TPos = tPos}
        Valid_Pair = {Origin = bestPO, Hit = bestPH, Target = target}
        WB.Cached = false
    else
        Valid_Pair = nil
    end
end

-- 主自动射击循环（包含：若设置了 HitRadius 则使用多环从内到外优先采样）
RunService.Heartbeat:Connect(function()
    if not LocalPlayer.Character then return end
    if not SETTINGS.AutoFire then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local localHumanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not localHumanoid or localHumanoid.Health <= 0 then return end
    local currentTime = tick()
    local localPos = hrp.Position
    local localCFrame = hrp.CFrame
    local forward = localCFrame.LookVector
    local team = LocalPlayer.Team
    local heldTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    local weaponType = "gun"
    if heldTool and typeof(heldTool.Name) == "string" then
        local lname = heldTool.Name:lower()
        if lname:find("knife") or lname:find("throw") then
            weaponType = "knife"
        elseif lname:find("revolver") or lname:find("gun") or lname:find("pistol") then
            weaponType = "gun"
        else
            weaponType = "gun"
        end
    end
    if SETTINGS.AutoKnife then weaponType = "knife" end
    if SETTINGS.AutoGun then weaponType = "gun" end

    local interval = (weaponType == "knife") and KNIFE_RATE or GUN_RATE
    if currentTime - lastFireTimes[weaponType] < interval then return end

    -- 尝试提前运行 DoRagebot（若存在）
    pcall(function() DoRagebot() end)

    -- 收集所有候选目标（不再按距离优先）
    local candidates = {}
    local fireRadiusSq = (SETTINGS.FireRadius or FIRE_RADIUS) * (SETTINGS.FireRadius or FIRE_RADIUS)

    local playersList = Players:GetPlayers()
    for i = 1, #playersList do
        local player = playersList[i]
        if player ~= LocalPlayer and player.Character and player.Character.Parent ~= nil then
            if not (team and player.Team and player.Team == team) then
                if SETTINGS.ShieldCheck and hasActiveShield(player.Character) then
                else
                    local head = player.Character:FindFirstChild("Head")
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if head and humanoid and humanoid.Health > 0 then
                        local dx = head.Position.X - localPos.X
                        local dy = head.Position.Y - localPos.Y
                        local dz = head.Position.Z - localPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if distSq <= fireRadiusSq then
                            table.insert(candidates, {player = player, character = player.Character, head = head, distSq = distSq})
                        end
                    end
                end
            end
        end
    end

    if SETTINGS.AttackNPCs and workspace:FindFirstChild("Characters") then
        local charChildren = workspace.Characters:GetChildren()
        for j = 1, #charChildren do
            local ch = charChildren[j]
            local pl = Players:FindFirstChild(ch.Name)
            if not pl and ch and ch.Parent ~= nil then
                if SETTINGS.ShieldCheck and hasActiveShield(ch) then
                else
                    local head = ch:FindFirstChild("Head")
                    local humanoid = ch:FindFirstChildOfClass("Humanoid")
                    if head and humanoid and humanoid.Health > 0 then
                        local dx = head.Position.X - localPos.X
                        local dy = head.Position.Y - localPos.Y
                        local dz = head.Position.Z - localPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if distSq <= fireRadiusSq then
                            table.insert(candidates, {player = nil, character = ch, head = head, distSq = distSq})
                        end
                    end
                end
            end
        end
    end

    -- 如果没有候选则退出
    if #candidates == 0 then return end

    -- 随机打乱候选顺序（去除“最近优先”）
    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = math.random(1, i)
            t[i], t[j] = t[j], t[i]
        end
    end
    shuffle(candidates)
    while #candidates > MAX_CANDIDATES do table.remove(candidates) end
    local topCandidates = candidates

    if SETTINGS.OneSecondTest and #topCandidates > 1 and currentTime - lastOneSecondTest >= 1 then
        lastOneSecondTest = currentTime
        for ci = 1, #topCandidates do
            local cand = topCandidates[ci]
            local targetCharacter = cand.character
            local head = cand.head
            local ownerId = LocalPlayer.UserId
            if ReportHit and ReportHit:IsA("RemoteEvent") then
                local hitReport = {
                    kind = "test",
                    ownerUserId = ownerId,
                    targetUserId = (cand.player and cand.player.UserId) or 0,
                    targetModel = targetCharacter,
                    at = time(),
                    origin = getRevolverMuzzlePosition(LocalPlayer.Character) or localPos,
                    to = head.Position,
                    vel = Vector3.new(0,0,0),
                    hitPart = head,
                    hitPos = head.Position,
                    headshot = (head and head.Name == "Head") and true or false
                }
                pcall(function() ReportHit:FireServer(hitReport) end)
            end
        end
    end

    local didFire = false

    -- 优先使用 DoRagebot 给出的 Valid_Pair（若目标匹配）
    if Valid_Pair and Valid_Pair.Target then
        for i = 1, #topCandidates do
            local cand = topCandidates[i]
            if cand.player and cand.player == Valid_Pair.Target then
                local chosenStart = Valid_Pair.Origin
                local predicted = Valid_Pair.Hit
                if chosenStart and predicted then
                    local ownerId = LocalPlayer.UserId
                    if weaponType == "knife" then
                        throwIdCounter = throwIdCounter + 1
                        local throwTbl = {
                            origin = chosenStart,
                            target = predicted,
                            id = throwIdCounter,
                            ownerUserId = ownerId,
                            skin = LocalPlayer:GetAttribute("KnifeSkin") or "Default",
                            effects = {},
                            power = 1
                        }
                        spawnKnifeSimple(throwTbl)
                        if ThrowReplicate and ThrowReplicate:IsA("RemoteEvent") then
                            pcall(function() ThrowReplicate:FireServer(throwTbl) end)
                        end
                        if ReportHit and ReportHit:IsA("RemoteEvent") then
                            local hitReport = {
                                kind = "throw",
                                throwId = throwIdCounter,
                                ownerUserId = ownerId,
                                targetUserId = (cand.player and cand.player.UserId) or 0,
                                targetModel = cand.character,
                                at = time(),
                                origin = chosenStart,
                                to = predicted,
                                vel = (predicted - chosenStart),
                                hitPart = cand.head,
                                hitPos = predicted,
                                headshot = (cand.head and cand.head.Name == "Head") and true or false
                            }
                            pcall(function() ReportHit:FireServer(hitReport) end)
                        end
                        -- 标记偏移点已使用（冷却）
                        if Valid_Pair.OriginIdx then
                            markOffsetUsed(Valid_Pair.OriginIdx)
                        end
                        lastFireTimes.knife = currentTime
                        didFire = true
                        break
                    else
                        local args = {
                            [1] = {
                                ["hitPos"] = predicted,
                                ["to"] = predicted,
                                ["hitInstance"] = cand.head,
                                ["id"] = 24,
                                ["mode"] = "single",
                                ["origin"] = chosenStart,
                                ["from"] = chosenStart,
                                ["hitNormal"] = Vector3.new(1, 0, 0),
                                ["effects"] = {
                                    ["Frost"] = 0,
                                    ["Ricochet"] = 0,
                                    ["Barrage"] = 0
                                },
                                ["ownerUserId"] = ownerId,
                                ["kind"] = "bullet",
                                ["isCharacterHit"] = true,
                                ["isADS"] = false
                            }
                        }
                        if ShootReplicate and ShootReplicate:IsA("RemoteEvent") then
                            pcall(function() ShootReplicate:FireServer(unpack(args)) end)
                        end
                        createTracer(chosenStart, predicted, nil, nil, TRACER_FADE_TIME, ownerId, false)
                        -- 标记偏移点已使用（冷却）
                        if Valid_Pair.OriginIdx then
                            markOffsetUsed(Valid_Pair.OriginIdx)
                        end
                        lastFireTimes.gun = currentTime
                        didFire = true
                        break
                    end
                end
            end
        end
        if didFire then return end
    end

    -- 主候选处理：若设置了 HitRadius (>0)，则基于多环（内到外）采样多个预测点尝试开火（以 HitRadius 的最大范围为准）
    for i = 1, #topCandidates do
        if didFire then break end
        local cand = topCandidates[i]
        local targetCharacter = cand.character
        local head = cand.head

        local baseHitPos = head.Position + HIT_OFFSET
        local hr = (type(SETTINGS.HitRadius) == "number") and SETTINGS.HitRadius or 0

        -- 生成预测点列表：如果有指定 HitRadius (>0) 则使用多环从内到外采样，否则只用中心点
        local predictedList = {}
        if hr and hr > 0 then
            local toTargetVec = (baseHitPos - localPos)
            local pole = toTargetVec.Magnitude > 0.001 and toTargetVec.Unit or Vector3.new(0,1,0)
            local rings = {0, hr * 0.25, hr * 0.5, hr * 0.75, hr}
            local totalScans = Hit_Scans or 32
            local countPerRing = math.max(6, math.floor(totalScans / math.max(1, #rings)))
            -- 保证中心点最先被考虑
            table.insert(predictedList, baseHitPos)
            for r = 2, #rings do
                local pts = GetOffsets_Outer(baseHitPos, pole, rings[r], countPerRing)
                for _, p in ipairs(pts) do table.insert(predictedList, p) end
            end
        else
            predictedList = { baseHitPos }
        end

        -- 将对 predictedList 的尝试提取到一个局部函数，以便内向优先和回退外向优先两次尝试
        local function tryPredictedList(plList)
            for _, predicted in ipairs(plList) do
                if didFire then break end
                if typeof(predicted) ~= "Vector3" then predicted = baseHitPos end

                local vecToPred = predicted - localPos
                local magPred = vecToPred.Magnitude
                if magPred <= 0 then
                    -- skip invalid
                else
                    local dirUnit = vecToPred.Unit
                    local dot3D = clamp(forward.X * dirUnit.X + forward.Y * dirUnit.Y + forward.Z * dirUnit.Z, -1, 1)
                    local angleDeg = deg(acos(dot3D))
                    if angleDeg <= MAX_ANGLE_DEG then
                        local startCandidates = {}
                        local histKey = nil
                        if cand.player and cand.player.UserId then
                            histKey = cand.player.UserId
                        elseif cand.character and cand.character.GetAttribute then
                            local buid = cand.character:GetAttribute("BotUserId")
                            if typeof(buid) == "number" then
                                histKey = buid
                            end
                        end
                        local hist = histKey and lastSuccessfulPoints[histKey] or nil

                        -- 采样所有 muzzle 偏移点（不再限制小数量）
                        local MAX_OFFSETS_TO_CHECK = #baseMuzzleOffsets
                        for sidx = 1, MAX_OFFSETS_TO_CHECK do
                            local actualIdx = getNextUnusedIndex(muzzleCycleIndex + sidx - 1)
                            if actualIdx then
                                -- 跳过在冷却内的偏移点（0.5 秒）
                                local lastUsed = offsetLastUsed[actualIdx]
                                if lastUsed and (currentTime - lastUsed) < OFFSET_COOLDOWN then
                                    -- skip 最近已使用
                                else
                                    local localOffset = baseMuzzleOffsets[actualIdx]
                                    if localOffset then
                                        local startPos = (localCFrame * CFrame.new(localOffset)).Position
                                        local dx = predicted.X - startPos.X
                                        local dy = predicted.Y - startPos.Y
                                        local dz = predicted.Z - startPos.Z
                                        local dMagSq = dx*dx + dy*dy + dz*dz
                                        local dMag = math.sqrt(dMagSq)
                                        local fwdDotHoriz = -1
                                        if dMag > 0 then
                                            local horizX = dx
                                            local horizZ = dz
                                            local horizMag = math.sqrt(horizX*horizX + horizZ*horizZ)
                                            if horizMag > 0 then
                                                local fwdHorizX = forward.X
                                                local fwdHorizZ = forward.Z
                                                local horizDot = clamp((fwdHorizX * horizX + fwdHorizZ * horizZ) / horizMag, -1, 1)
                                                fwdDotHoriz = horizDot
                                            else
                                                fwdDotHoriz = 1
                                            end
                                        else
                                            fwdDotHoriz = 1
                                        end
                                        local closeness = 1 - clamp(dMag / (SETTINGS.FireRadius or FIRE_RADIUS), 0, 1)
                                        local score = fwdDotHoriz * 0.7 + closeness * 0.25
                                        local verticalDiff = math.abs(dy)
                                        if verticalDiff <= VERTICAL_MATCH_THRESHOLD then
                                            score = score + 0.05
                                        end
                                        -- 偏好：如果偏移在本地坐标系中接近向前10单位，则显著提升分数（最高优先级）
                                        if math.abs(localOffset.Z - 10) <= 1 then
                                            -- 大幅加分以确保最优先被选择
                                            score = score + 2.5
                                        end
                                        if hist then
                                            local daX = localOffset.X - hist.X
                                            local daY = localOffset.Y - hist.Y
                                            local daZ = localOffset.Z - hist.Z
                                            local daSq = daX*daX + daY*daY + daZ*daZ
                                            if daSq < 1.5 then score = score + 0.1 end
                                        end

                                        local occlusionPenalty = 0
                                        if SETTINGS.WallCheck then
                                            local quickRp = RaycastParams.new()
                                            quickRp.FilterType = Enum.RaycastFilterType.Blacklist
                                            quickRp.IgnoreWater = true
                                            quickRp.FilterDescendantsInstances = {LocalPlayer.Character}
                                            local qres = workspace:Raycast(startPos, (predicted - startPos), quickRp)
                                            if qres and not (qres.Instance and qres.Instance:IsDescendantOf(targetCharacter)) then
                                                occlusionPenalty = 0.35
                                            end
                                        end
                                        score = score * (1 - occlusionPenalty)
                                        if #startCandidates >= MAX_START_TRIES then
                                            local worstScore = startCandidates[#startCandidates].score
                                            if score <= worstScore then
                                            else
                                                insertTopByScore(startCandidates, {localOffset = localOffset, startPos = startPos, idx = actualIdx}, score, MAX_START_TRIES)
                                            end
                                        else
                                            insertTopByScore(startCandidates, {localOffset = localOffset, startPos = startPos, idx = actualIdx}, score, MAX_START_TRIES)
                                        end
                                    end
                                end
                            end
                        end

                        local rp = rpTemplate
                        rp.FilterDescendantsInstances = {LocalPlayer.Character}
                        local hasLOS = false
                        local chosenStart = nil
                        local chosenLocal = nil
                        local chosenIdx = nil

                        if SETTINGS.WallCheck == false then
                            local s = startCandidates[1] and startCandidates[1].elem
                            if s then
                                chosenStart = s.startPos
                                chosenLocal = s.localOffset
                                chosenIdx = s.idx
                                hasLOS = true
                                if histKey then lastSuccessfulPoints[histKey] = chosenLocal end
                            end
                        else
                            for si = 1, #startCandidates do
                                if hasLOS then break end
                                local s = startCandidates[si].elem
                                local okStart, okLocal = findViableStart(localCFrame, s.localOffset, localPos, predicted, rp, targetCharacter, forward)
                                if okStart then
                                    hasLOS = true
                                    chosenStart = okStart
                                    chosenLocal = okLocal
                                    chosenIdx = s.idx
                                    if histKey then
                                        local prev = lastSuccessfulPoints[histKey]
                                        if prev then
                                            lastSuccessfulPoints[histKey] = Vector3.new(prev.X * 0.5 + chosenLocal.X * 0.5, prev.Y * 0.5 + chosenLocal.Y * 0.5, prev.Z * 0.5 + chosenLocal.Z * 0.5)
                                        else
                                            lastSuccessfulPoints[histKey] = chosenLocal
                                        end
                                    end
                                    break
                                end
                            end
                        end

                        if hasLOS and chosenStart then
                            if chosenIdx and type(chosenIdx) == "number" then
                                muzzleCycleIndex = (chosenIdx % #baseMuzzleOffsets) + 1
                            else
                                muzzleCycleIndex = (muzzleCycleIndex % #baseMuzzleOffsets) + 1
                            end

                            if chosenIdx and type(chosenIdx) == "number" then markOffsetUsed(chosenIdx) end

                            local ownerId = LocalPlayer.UserId
                            if weaponType == "knife" then
                                throwIdCounter = throwIdCounter + 1
                                local throwTbl = {
                                    origin = chosenStart,
                                    target = predicted,
                                    id = throwIdCounter,
                                    ownerUserId = ownerId,
                                    skin = LocalPlayer:GetAttribute("KnifeSkin") or "Default",
                                    effects = {},
                                    power = 1
                                }
                                spawnKnifeSimple(throwTbl)
                                if ThrowReplicate and ThrowReplicate:IsA("RemoteEvent") then
                                    pcall(function() ThrowReplicate:FireServer(throwTbl) end)
                                end
                                if ReportHit and ReportHit:IsA("RemoteEvent") then
                                    local hitReport = {
                                        kind = "throw",
                                        throwId = throwIdCounter,
                                        ownerUserId = ownerId,
                                        targetUserId = (cand.player and cand.player.UserId) or 0,
                                        targetModel = targetCharacter,
                                        at = time(),
                                        origin = chosenStart,
                                        to = predicted,
                                        vel = (predicted - chosenStart),
                                        hitPart = head,
                                        hitPos = predicted,
                                        headshot = (head and head.Name == "Head") and true or false
                                    }
                                    pcall(function() ReportHit:FireServer(hitReport) end)
                                end
                                lastFireTimes.knife = currentTime
                                didFire = true
                                break
                            else
                                local args = {
                                    [1] = {
                                        ["hitPos"] = predicted,
                                        ["to"] = predicted,
                                        ["hitInstance"] = head,
                                        ["id"] = 24,
                                        ["mode"] = "single",
                                        ["origin"] = chosenStart,
                                        ["from"] = chosenStart,
                                        ["hitNormal"] = Vector3.new(1, 0, 0),
                                        ["effects"] = {
                                            ["Frost"] = 0,
                                            ["Ricochet"] = 0,
                                            ["Barrage"] = 0
                                        },
                                        ["ownerUserId"] = ownerId,
                                        ["kind"] = "bullet",
                                        ["isCharacterHit"] = true,
                                        ["isADS"] = false
                                    }
                                }
                                if ShootReplicate and ShootReplicate:IsA("RemoteEvent") then
                                    pcall(function() ShootReplicate:FireServer(unpack(args)) end)
                                end
                                createTracer(chosenStart, predicted, nil, nil, TRACER_FADE_TIME, ownerId, false)
                                lastFireTimes.gun = currentTime
                                didFire = true
                                break
                            end
                        end
                    end
                end
            end
        end
        -- 先做一次内->外尝试
        tryPredictedList(predictedList)
        -- 如果未命中且有命中半径，则再做一次外->内回退尝试
        if not didFire and hr and hr > 0 then
            local rev = {}
            for idx = #predictedList, 1, -1 do table.insert(rev, predictedList[idx]) end
            tryPredictedList(rev)
        end
    end
end)

RunService.Heartbeat:Connect(function()
    for _, d in pairs(playerCharacterData) do
        if d.knifeRig or d.revolverRig then
            applyVisibilityToData(d)
        end
    end
end)

-- UI / 控件部分（新增开关：随机轨迹颜色、随机飞刀轨迹、脚本运行自动停止音乐）
local sliderIsDragging = false

local function makeSwitch(parent, name, labelText, default, callback)
    local container = Instance.new("Frame")
    container.Name = name .. "_Container"
    container.Size = UDim2.new(1, 0, 0, 44)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = name .. "_Label"
    label.Parent = container
    label.AnchorPoint = Vector2.new(0,0.5)
    label.Position = UDim2.new(0, 12, 0.5, 0)
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center

    local switchBg = Instance.new("Frame")
    switchBg.Name = name .. "_Bg"
    switchBg.Parent = container
    switchBg.AnchorPoint = Vector2.new(1,0.5)
    switchBg.Position = UDim2.new(1, -12, 0.5, 0)
    switchBg.Size = UDim2.new(0, 56, 0, 30)
    switchBg.BackgroundColor3 = default and Color3.fromRGB(34,197,94) or Color3.fromRGB(120,120,120)
    switchBg.BorderSizePixel = 0
    switchBg.ClipsDescendants = true
    local bgCorner = Instance.new("UICorner"); bgCorner.Parent = switchBg; bgCorner.CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Name = name .. "_Knob"
    knob.Parent = switchBg
    knob.AnchorPoint = Vector2.new(0,0.5)
    knob.Position = default and UDim2.new(1, -28, 0.5, 0) or UDim2.new(0, 6, 0.5, 0)
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.BackgroundColor3 = Color3.fromRGB(250,250,250)
    knob.BorderSizePixel = 0
    local knobCorner = Instance.new("UICorner"); knobCorner.Parent = knob; knobCorner.CornerRadius = UDim.new(1,0)

    local state = default and true or false
    local function setState(s, instant)
        state = s
        if s then
            switchBg.BackgroundColor3 = Color3.fromRGB(34,197,94)
            local pos = UDim2.new(1, -28, 0.5, 0)
            if instant then knob.Position = pos else TweenService:Create(knob, TweenInfo.new(0.16), {Position = pos}):Play() end
        else
            switchBg.BackgroundColor3 = Color3.fromRGB(120,120,120)
            local pos = UDim2.new(0, 6, 0.5, 0)
            if instant then knob.Position = pos else TweenService:Create(knob, TweenInfo.new(0.16), {Position = pos}):Play() end
        end
        if callback then pcall(callback, state) end
    end

    switchBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            blockGameInput()
            task.defer(function()
                task.wait(0.22)
                unblockGameInput()
            end)
            setState(not state)
        end
    end)

    setState(state, true)
    return container
end

local function makeSlider(parent, name, labelText, minV, maxV, default, onChange)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Parent = parent
    frame.AnchorPoint = Vector2.new(0,0)
    frame.Size = UDim2.new(1, -24, 0, 38)
    frame.BackgroundTransparency = 0.04
    frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    local corner = Instance.new("UICorner"); corner.Parent = frame; corner.CornerRadius = UDim.new(0,6)

    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.AnchorPoint = Vector2.new(0,0)
    label.Position = UDim2.new(0.02, 0, 0, 6)
    label.Size = UDim2.new(0.6, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s：%d", labelText, default)
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left

    local barBg = Instance.new("Frame")
    barBg.Parent = frame
    barBg.AnchorPoint = Vector2.new(0,0)
    barBg.Position = UDim2.new(0.02, 0, 0, 24)
    barBg.Size = UDim2.new(0.96, 0, 0, 10)
    barBg.BackgroundColor3 = Color3.fromRGB(50,50,50)
    barBg.BorderSizePixel = 0
    local barCorner = Instance.new("UICorner"); barCorner.Parent = barBg; barCorner.CornerRadius = UDim.new(0,6)

    local fill = Instance.new("Frame")
    fill.Parent = barBg
    fill.AnchorPoint = Vector2.new(0,0.5)
    fill.Position = UDim2.new(0, 0, 0.5, 0)
    local frac = (default - minV) / math.max(1, (maxV - minV))
    fill.Size = UDim2.new(math.clamp(frac,0,1), 0, 1, 0)
    fill.BackgroundColor3 = TRACER_COLOR
    local fillCorner = Instance.new("UICorner"); fillCorner.Parent = fill; fillCorner.CornerRadius = UDim.new(0,6)

    local uiGradient = Instance.new("UIGradient"); uiGradient.Color = ColorSequence.new(TRACER_COLOR, Color3.fromRGB(255,180,200)); uiGradient.Rotation = 0; uiGradient.Parent = fill

    local dragging = false
    local lastTween = nil
    local inputChangedConn = nil
    local inputEndedConn = nil

    local function setFillFrac(fracVal)
        fracVal = math.clamp(fracVal, 0, 1)
        if lastTween then
            pcall(function() lastTween:Cancel() end)
            lastTween = nil
        end
        lastTween = TweenService:Create(fill, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(fracVal, 0, 1, 0)})
        lastTween:Play()
    end

    local function updateFromPos(x, y)
        if not barBg or not barBg.AbsoluteSize then return end
        local absX = x or UserInputService:GetMouseLocation().x
        local leftX = barBg.AbsolutePosition.X
        local width = math.max(1, barBg.AbsoluteSize.X)
        local absPos = math.clamp((absX - leftX) / width, 0, 1)
        setFillFrac(absPos)
        local val = math.floor(minV + absPos * (maxV - minV))
        label.Text = string.format("%s：%d", labelText, val)
        if onChange then pcall(onChange, val) end
    end

    local function cleanupInputConnections()
        if inputChangedConn then
            pcall(function() inputChangedConn:Disconnect() end)
            inputChangedConn = nil
        end
        if inputEndedConn then
            pcall(function() inputEndedConn:Disconnect() end)
            inputEndedConn = nil
        end
        dragging = false
        if sliderIsDragging then
            sliderIsDragging = false
            pcall(function() unblockGameInput() end)
        end
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            sliderIsDragging = true
            blockGameInput()
            updateFromPos(input.Position.X, input.Position.Y)
            cleanupInputConnections()
            inputChangedConn = UserInputService.InputChanged:Connect(function(inp)
                if not dragging then return end
                if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    local pos = inp.Position
                    if pos then
                        updateFromPos(pos.X, pos.Y)
                    else
                        local mousePos = UserInputService:GetMouseLocation()
                        updateFromPos(mousePos.x, mousePos.y)
                    end
                end
            end)
            inputEndedConn = UserInputService.InputEnded:Connect(function(inp)
                if not dragging then return end
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                    sliderIsDragging = false
                    unblockGameInput()
                    cleanupInputConnections()
                end
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End and dragging then
                    dragging = false
                    sliderIsDragging = false
                    unblockGameInput()
                    cleanupInputConnections()
                end
            end)
            spawn(function()
                task.wait(6)
                if dragging then
                    cleanupInputConnections()
                end
            end)
        end
    end)

    barBg.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = input.Position
            if pos then
                updateFromPos(pos.X, pos.Y)
            else
                local mousePos = UserInputService:GetMouseLocation()
                updateFromPos(mousePos.x, mousePos.y)
            end
        end
    end)

    return frame
end

local function createControlsGui()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "V67ControlUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    registerTopGui(screenGui)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.AnchorPoint = Vector2.new(0, 0.5)
    mainFrame.Position = UDim2.new(0.02, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 420, 0, 420)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    mainFrame.ClipsDescendants = true
    local uc = Instance.new("UICorner"); uc.Parent = mainFrame; uc.CornerRadius = UDim.new(0,12)

    local savedExpandedX = LocalPlayer:GetAttribute("V67_UI_Pos_Expanded_X")
    local savedExpandedY = LocalPlayer:GetAttribute("V67_UI_Pos_Expanded_Y")
    local savedCollapsedX = LocalPlayer:GetAttribute("V67_UI_Pos_Collapsed_X")
    local savedCollapsedY = LocalPlayer:GetAttribute("V67_UI_Pos_Collapsed_Y")
    local savedExpanded = nil
    local savedCollapsed = nil
    if typeof(savedExpandedX) == "number" and typeof(savedExpandedY) == "number" then
        savedExpanded = UDim2.new(0, savedExpandedX, 0, savedExpandedY)
        pcall(function() mainFrame.Position = savedExpanded end)
    end
    if typeof(savedCollapsedX) == "number" and typeof(savedCollapsedY) == "number" then
        savedCollapsed = UDim2.new(0, savedCollapsedX, 0, savedCollapsedY)
    end

    local title = Instance.new("TextLabel")
    title.Parent = mainFrame
    title.AnchorPoint = Vector2.new(0,0)
    title.Position = UDim2.new(0, 12, 0, 8)
    title.Size = UDim2.new(1, -80, 0, 28)
    title.BackgroundTransparency = 1
    title.Text = "喵~❤️"
    title.TextColor3 = TRACER_COLOR
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center

    local hideBtn = Instance.new("TextButton")
    hideBtn.Parent = mainFrame
    hideBtn.AnchorPoint = Vector2.new(1,0)
    hideBtn.Position = UDim2.new(1, -12, 0, 8)
    hideBtn.Size = UDim2.new(0, 28, 0, 28)
    hideBtn.Text = "—"
    hideBtn.Font = Enum.Font.Gotham
    hideBtn.TextColor3 = Color3.fromRGB(220,220,220)
    hideBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    hideBtn.BorderSizePixel = 0
    local corner2 = Instance.new("UICorner"); corner2.Parent = hideBtn; corner2.CornerRadius = UDim.new(0,6)

    local slidersToggleBtn = Instance.new("TextButton")
    slidersToggleBtn.Parent = mainFrame
    slidersToggleBtn.AnchorPoint = Vector2.new(1,0)
    slidersToggleBtn.Position = UDim2.new(1, -44, 0, 8)
    slidersToggleBtn.Size = UDim2.new(0, 28, 0, 28)
    slidersToggleBtn.Text = "≡"
    slidersToggleBtn.Font = Enum.Font.Gotham
    slidersToggleBtn.TextColor3 = Color3.fromRGB(220,220,220)
    slidersToggleBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    slidersToggleBtn.BorderSizePixel = 0
    local sToggleCorner = Instance.new("UICorner"); sToggleCorner.Parent = slidersToggleBtn; sToggleCorner.CornerRadius = UDim.new(0,6)

    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Name = "ListFrame"
    listFrame.Parent = mainFrame
    listFrame.AnchorPoint = Vector2.new(0,0)
    listFrame.Position = UDim2.new(0, 12, 0, 44)
    listFrame.Size = UDim2.new(1, -24, 1, -240)
    listFrame.CanvasSize = UDim2.new(0,0,0,0)
    listFrame.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel = 0
    local uiList = Instance.new("UIListLayout")
    uiList.Parent = listFrame
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Padding = UDim.new(0, 6)
    local uiPadding = Instance.new("UIPadding"); uiPadding.Parent = listFrame; uiPadding.PaddingTop = UDim.new(0,6); uiPadding.PaddingLeft = UDim.new(0,6); uiPadding.PaddingRight = UDim.new(0,6)

    local bottomPanel = Instance.new("Frame")
    bottomPanel.Name = "BottomPanel"
    bottomPanel.Parent = mainFrame
    bottomPanel.AnchorPoint = Vector2.new(0,0)
    bottomPanel.Position = UDim2.new(0, 12, 1, -320)
    bottomPanel.Size = UDim2.new(1, -24, 0, 320)
    bottomPanel.BackgroundTransparency = 0
    bottomPanel.BackgroundColor3 = Color3.fromRGB(14,14,14)
    bottomPanel.BorderSizePixel = 0
    local bpCorner = Instance.new("UICorner"); bpCorner.Parent = bottomPanel; bpCorner.CornerRadius = UDim.new(0,8)

    local sw1 = makeSwitch(listFrame, "SwitchAutoFire", "ragebot", SETTINGS.AutoFire, function(s) SETTINGS.AutoFire = s end)
    local sw2 = makeSwitch(listFrame, "SwitchAutoKnife", "强制刀子", SETTINGS.AutoKnife, function(s) SETTINGS.AutoKnife = s end)
    local sw3 = makeSwitch(listFrame, "SwitchAutoGun", "强制枪械", SETTINGS.AutoGun, function(s) SETTINGS.AutoGun = s end)
    local sw4 = makeSwitch(listFrame, "SwitchWallCheck", "墙体检测", SETTINGS.WallCheck, function(s) SETTINGS.WallCheck = s end)
    local sep = Instance.new("Frame"); sep.Parent = listFrame; sep.Size = UDim2.new(1,0,0,8); sep.BackgroundTransparency = 1

    local sw5 = makeSwitch(listFrame, "SwitchShowTracers", "显示子弹轨迹", SETTINGS.ShowTracers, function(s) SETTINGS.ShowTracers = s end)
    local sw6 = makeSwitch(listFrame, "SwitchFriendlyTracers", "显示队友轨迹", SETTINGS.ShowFriendlyTracers, function(s) SETTINGS.ShowFriendlyTracers = s end)
    local sw7 = makeSwitch(listFrame, "SwitchEnemyTracers", "显示敌人轨迹", SETTINGS.ShowEnemyTracers, function(s) SETTINGS.ShowEnemyTracers = s end)
    local sw8 = makeSwitch(listFrame, "SwitchKnifeTracers", "显示飞刀轨迹", SETTINGS.ShowKnifeTracers, function(s) SETTINGS.ShowKnifeTracers = s end)
    local sw9 = makeSwitch(listFrame, "SwitchAttackNPCs", "攻击NPC", SETTINGS.AttackNPCs, function(s) SETTINGS.AttackNPCs = s end)

    local sw10 = makeSwitch(listFrame, "SwitchPlayHitSound", "命中音效总开", SETTINGS.PlayHitSound, function(s) SETTINGS.PlayHitSound = s end)
    local sw11 = makeSwitch(listFrame, "SwitchPlayHitSound1", "skeet命中音效", SETTINGS.PlayHitSound1, function(s) SETTINGS.PlayHitSound1 = s end)
    local sw12 = makeSwitch(listFrame, "SwitchPlayHitSound2", "Neverlose命中音效", SETTINGS.PlayHitSound2, function(s) SETTINGS.PlayHitSound2 = s end)
    local sw13 = makeSwitch(listFrame, "SwitchPlayHitSound3", "Gamesense命中音效", SETTINGS.PlayHitSound3, function(s) SETTINGS.PlayHitSound3 = s end)

    local sw14 = makeSwitch(listFrame, "SwitchShieldCheck", "护盾检测", SETTINGS.ShieldCheck, function(s) SETTINGS.ShieldCheck = s end)
    local sw15 = makeSwitch(listFrame, "SwitchPlayMusic", "播放音乐", SETTINGS.PlayMusic, function(s)
        SETTINGS.PlayMusic = s
        if s then
            playMusic()
        else
            stopMusic()
        end
    end)

    -- 新增开关：随机子弹轨迹颜色、随机飞刀轨迹、脚本运行自动停止音乐
    local swRandBullet = makeSwitch(listFrame, "SwitchRandBullet", "随机轨迹颜色", SETTINGS.RandomizeTracerColor, function(s) SETTINGS.RandomizeTracerColor = s end)
    local swRandThrow = makeSwitch(listFrame, "SwitchRandThrow", "随机飞刀轨迹", SETTINGS.RandomizeThrowTracer, function(s) SETTINGS.RandomizeThrowTracer = s end)
    local swAutoStopMusic = makeSwitch(listFrame, "SwitchAutoStopMusic", "启动时停止音乐", SETTINGS.AutoStopMusicOnRun, function(s) SETTINGS.AutoStopMusicOnRun = s end)

    local swMusic1 = makeSwitch(listFrame, "SwitchMusic1", "曲目1", SETTINGS.MusicEnabled[1], function(s)
        SETTINGS.MusicEnabled[1] = s
        if s then
            SETTINGS.MusicIndex = 1
            if SETTINGS.PlayMusic then playMusic() end
        else
            if SETTINGS.PlayMusic then playMusic() end
        end
    end)
    local swMusic2 = makeSwitch(listFrame, "SwitchMusic2", "曲目2", SETTINGS.MusicEnabled[2], function(s)
        SETTINGS.MusicEnabled[2] = s
        if s then
            SETTINGS.MusicIndex = 2
            if SETTINGS.PlayMusic then playMusic() end
        else
            if SETTINGS.PlayMusic then playMusic() end
        end
    end)
    local swMusic3 = makeSwitch(listFrame, "SwitchMusic3", "曲目3", SETTINGS.MusicEnabled[3], function(s)
        SETTINGS.MusicEnabled[3] = s
        if s then
            SETTINGS.MusicIndex = 3
            if SETTINGS.PlayMusic then playMusic() end
        else
            if SETTINGS.PlayMusic then playMusic() end
        end
    end)

    local swOneSec = makeSwitch(listFrame, "SwitchOneSecondTest", "一秒测试功能", SETTINGS.OneSecondTest, function(s) SETTINGS.OneSecondTest = s end)

    local function updateCanvas()
        local contentSize = uiList.AbsoluteContentSize.Y + 12
        listFrame.CanvasSize = UDim2.new(0,0,0, contentSize)
    end
    uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    updateCanvas()

    local sliderContainerPadding = 8
    local sliderHeight = 38
    local s1 = makeSlider(bottomPanel, "SliderMuzzle", "枪口偏移", 2, 40, math.floor(SETTINGS.MuzzleOffset), function(v)
        SETTINGS.MuzzleOffset = v
        rebuildBaseMuzzleOffsets(SETTINGS.ScanRange or v)
    end)
    s1.Parent = bottomPanel
    s1.AnchorPoint = Vector2.new(0,0)
    s1.Position = UDim2.new(0, sliderContainerPadding, 0, 8)
    s1.Size = UDim2.new(1, -sliderContainerPadding*2, 0, sliderHeight)

    local s2 = makeSlider(bottomPanel, "SliderRadius", "搜索半径", 100, 2000, math.floor(SETTINGS.FireRadius), function(v)
        SETTINGS.FireRadius = v
    end)
    s2.Parent = bottomPanel
    s2.AnchorPoint = Vector2.new(0,0)
    s2.Position = UDim2.new(0, sliderContainerPadding, 0, 8 + sliderHeight + 6)
    s2.Size = UDim2.new(1, -sliderContainerPadding*2, 0, sliderHeight)

    local s3 = makeSlider(bottomPanel, "SliderWall", "墙体厚度", 1, 200, math.floor(SETTINGS.WallThickness or WALL_PENETRATION_MAX), function(v)
        SETTINGS.WallThickness = v
    end)
    s3.Parent = bottomPanel
    s3.AnchorPoint = Vector2.new(0,0)
    s3.Position = UDim2.new(0, sliderContainerPadding, 0, 8 + (sliderHeight + 6) * 2)
    s3.Size = UDim2.new(1, -sliderContainerPadding*2, 0, sliderHeight)

    local s4 = makeSlider(bottomPanel, "SliderHitRadius", "命中半径", 0, 150, math.floor((type(SETTINGS.HitRadius)=="number" and SETTINGS.HitRadius) or 0), function(v)
        SETTINGS.HitRadius = v
    end)
    s4.Parent = bottomPanel
    s4.AnchorPoint = Vector2.new(0,0)
    s4.Position = UDim2.new(0, sliderContainerPadding, 0, 8 + (sliderHeight + 6) * 3)
    s4.Size = UDim2.new(1, -sliderContainerPadding*2, 0, sliderHeight)

    local s5 = makeSlider(bottomPanel, "SliderScanRange", "周围扫描范围", 2, 60, math.floor(SETTINGS.ScanRange or SETTINGS.MuzzleOffset), function(v)
        SETTINGS.ScanRange = v
        rebuildBaseMuzzleOffsets(v)
    end)
    s5.Parent = bottomPanel
    s5.AnchorPoint = Vector2.new(0,0)
    s5.Position = UDim2.new(0, sliderContainerPadding, 0, 8 + (sliderHeight + 6) * 4)
    s5.Size = UDim2.new(1, -sliderContainerPadding*2, 0, sliderHeight)

    local s6 = makeSlider(bottomPanel, "SliderMusicVolume", "音乐音量", 10, 250, math.floor((SETTINGS.MusicVolume or 1.25) * 100), function(v)
        SETTINGS.MusicVolume = v / 100
        if currentMusicSound then
            pcall(function() currentMusicSound.Volume = SETTINGS.MusicVolume end)
        end
    end)
    s6.Parent = bottomPanel
    s6.AnchorPoint = Vector2.new(0,0)
    s6.Position = UDim2.new(0, sliderContainerPadding, 0, 8 + (sliderHeight + 6) * 5)
    s6.Size = UDim2.new(1, -sliderContainerPadding*2, 0, sliderHeight)

    local s7 = makeSlider(bottomPanel, "SliderSelfScan", "自身扫描范围", 2, 60, math.floor(SETTINGS.MuzzleOffset), function(v)
        SETTINGS.MuzzleOffset = v
        rebuildBaseMuzzleOffsets(SETTINGS.ScanRange or v)
    end)
    s7.Parent = bottomPanel
    s7.AnchorPoint = Vector2.new(0,0)
    s7.Position = UDim2.new(0, sliderContainerPadding, 0, 8 + (sliderHeight + 6) * 6)
    s7.Size = UDim2.new(1, -sliderContainerPadding*2, 0, sliderHeight)

    local musicControl = Instance.new("Frame")
    musicControl.Name = "MusicControl"
    musicControl.Parent = bottomPanel
    musicControl.AnchorPoint = Vector2.new(0,0)
    musicControl.Position = UDim2.new(0, sliderContainerPadding, 0, 8 + (sliderHeight + 6) * 7)
    musicControl.Size = UDim2.new(1, -sliderContainerPadding*2, 0, 28)
    musicControl.BackgroundTransparency = 1

    local prevBtn = Instance.new("TextButton")
    prevBtn.Name = "PrevMusic"
    prevBtn.Parent = musicControl
    prevBtn.AnchorPoint = Vector2.new(0,0.5)
    prevBtn.Position = UDim2.new(0, 0, 0.5, 0)
    prevBtn.Size = UDim2.new(0, 28, 0, 24)
    prevBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    prevBtn.BorderSizePixel = 0
    prevBtn.Text = "‹"
    prevBtn.Font = Enum.Font.Gotham
    prevBtn.TextColor3 = Color3.fromRGB(220,220,220)
    local prevCorner = Instance.new("UICorner"); prevCorner.Parent = prevBtn; prevCorner.CornerRadius = UDim.new(0,6)

    local nextBtn = Instance.new("TextButton")
    nextBtn.Name = "NextMusic"
    nextBtn.Parent = musicControl
    nextBtn.AnchorPoint = Vector2.new(1,0.5)
    nextBtn.Position = UDim2.new(1, 0, 0.5, 0)
    nextBtn.Size = UDim2.new(0, 28, 0, 24)
    nextBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    nextBtn.BorderSizePixel = 0
    nextBtn.Text = "›"
    nextBtn.Font = Enum.Font.Gotham
    nextBtn.TextColor3 = Color3.fromRGB(220,220,220)
    local nextCorner = Instance.new("UICorner"); nextCorner.Parent = nextBtn; nextCorner.CornerRadius = UDim.new(0,6)

    local musicLabel = Instance.new("TextLabel")
    musicLabel.Name = "MusicLabel"
    musicLabel.Parent = musicControl
    musicLabel.AnchorPoint = Vector2.new(0.5,0.5)
    musicLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    musicLabel.Size = UDim2.new(1, -64, 1, 0)
    musicLabel.BackgroundTransparency = 1
    musicLabel.TextColor3 = Color3.fromRGB(220,220,220)
    musicLabel.Font = Enum.Font.Gotham
    musicLabel.TextSize = 14
    musicLabel.TextXAlignment = Enum.TextXAlignment.Center

    local function updateMusicLabel()
        local idx = SETTINGS.MusicIndex or 1
        if MUSIC_OPTIONS[idx] and MUSIC_OPTIONS[idx].name then
            musicLabel.Text = string.format("曲目：%s", MUSIC_OPTIONS[idx].name)
        else
            musicLabel.Text = "曲目：未知"
        end
    end

    prevBtn.MouseButton1Click:Connect(function()
        local newIdx = SETTINGS.MusicIndex - 1
        if newIdx < 1 then newIdx = #MUSIC_OPTIONS end
        setMusicIndex(newIdx)
        updateMusicLabel()
    end)
    nextBtn.MouseButton1Click:Connect(function()
        local newIdx = SETTINGS.MusicIndex + 1
        if newIdx > #MUSIC_OPTIONS then newIdx = 1 end
        setMusicIndex(newIdx)
        updateMusicLabel()
    end)
    updateMusicLabel()

    local isCollapsed = false
    local expandedSize = mainFrame.Size
    local collapsedSize = UDim2.new(0, 160, 0, 48)
    local savedExpandedPosition = savedExpanded or mainFrame.Position
    local savedCollapsedPosition = savedCollapsed or UDim2.new(0, 20, 0, 20)

    local bottomOriginalSize = bottomPanel.Size
    local bottomOriginalPosition = bottomPanel.Position
    local listOriginalSize = listFrame.Size
    local listExpandedSize = UDim2.new(1, -24, 1, -40)
    local slidersHidden = false

    local function toggleSliders(hidden)
        if hidden == nil then hidden = not slidersHidden end
        if hidden == slidersHidden then return end
        slidersHidden = hidden
        if slidersHidden then
            slidersToggleBtn.Text = "×"
            local hideTargetSize = UDim2.new(bottomOriginalSize.X.Scale, bottomOriginalSize.X.Offset, 0, 0)
            local hideTargetPos = UDim2.new(bottomOriginalPosition.X.Scale, bottomOriginalPosition.X.Offset, 1, 20)
            local tween1 = TweenService:Create(bottomPanel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = hideTargetPos, Size = hideTargetSize})
            tween1:Play()
            local tween2 = TweenService:Create(listFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = listExpandedSize})
            tween2:Play()
            tween1.Completed:Wait()
            bottomPanel.Visible = false
        else
            slidersToggleBtn.Text = "≡"
            bottomPanel.Visible = true
            local startPos = UDim2.new(bottomOriginalPosition.X.Scale, bottomOriginalPosition.X.Offset, 1, 20)
            bottomPanel.Position = startPos
            bottomPanel.Size = UDim2.new(bottomOriginalSize.X.Scale, bottomOriginalSize.X.Offset, 0, 0)
            local tween1 = TweenService:Create(bottomPanel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = bottomOriginalPosition, Size = bottomOriginalSize})
            tween1:Play()
            local tween2 = TweenService:Create(listFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = listOriginalSize})
            tween2:Play()
        end
    end

    slidersToggleBtn.MouseButton1Click:Connect(function()
        toggleSliders()
    end)

    local function savePosAttr(ud, expanded)
        if typeof(ud) ~= "UDim2" then return end
        local x = ud.X.Offset or 0
        local y = ud.Y.Offset or 0
        if expanded then
            pcall(function()
                LocalPlayer:SetAttribute("V67_UI_Pos_Expanded_X", x)
                LocalPlayer:SetAttribute("V67_UI_Pos_Expanded_Y", y)
            end)
        else
            pcall(function()
                LocalPlayer:SetAttribute("V67_UI_Pos_Collapsed_X", x)
                LocalPlayer:SetAttribute("V67_UI_Pos_Collapsed_Y", y)
            end)
        end
    end

    local function collapseUI()
        if isCollapsed then return end
        isCollapsed = true
        savedExpandedPosition = mainFrame.Position
        savePosAttr(savedExpandedPosition, true)
        if savedCollapsedPosition then
            pcall(function() mainFrame.Position = savedCollapsedPosition end)
        end
        for _, c in ipairs({listFrame, bottomPanel}) do
            c.Visible = false
        end
        slidersToggleBtn.Visible = false
        local tween = TweenService:Create(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = collapsedSize})
        tween:Play()
        title.Text = "Link.cc"
        hideBtn.Text = "+"
    end

    local function expandUI()
        if not isCollapsed then return end
        isCollapsed = false
        pcall(function() mainFrame.Position = savedExpandedPosition end)
        local tween = TweenService:Create(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = expandedSize})
        tween:Play()
        tween.Completed:Wait()
        for _, c in ipairs({listFrame}) do
            c.Visible = true
        end
        slidersToggleBtn.Visible = true
        if slidersHidden then
            bottomPanel.Visible = false
            listFrame.Size = listExpandedSize
            bottomPanel.Size = UDim2.new(bottomOriginalSize.X.Scale, bottomOriginalSize.X.Offset, 0, 0)
            bottomPanel.Position = UDim2.new(bottomOriginalPosition.X.Scale, bottomOriginalPosition.X.Offset, 1, 20)
            slidersToggleBtn.Text = "×"
        else
            bottomPanel.Visible = true
            bottomPanel.Size = bottomOriginalSize
            bottomPanel.Position = bottomOriginalPosition
            listFrame.Size = listOriginalSize
            slidersToggleBtn.Text = "≡"
        end
        title.Text = "喵~❤️"
        hideBtn.Text = "—"
    end

    hideBtn.MouseButton1Click:Connect(function()
        if isCollapsed then expandUI() else collapseUI() end
    end)

    local dragging = false
    local dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
        if sliderIsDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            blockGameInput()
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    unblockGameInput()
                    if isCollapsed then
                        savedCollapsedPosition = mainFrame.Position
                        savePosAttr(savedCollapsedPosition, false)
                    else
                        savedExpandedPosition = mainFrame.Position
                        savePosAttr(savedExpandedPosition, true)
                    end
                end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
        end
    end)

    mainFrame.Size = UDim2.new(0, 160, 0, 48)
    TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = expandedSize}):Play()

    if SETTINGS.PlayMusic then
        pcall(playMusic)
    end
end

local function showStartupToast()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "V67Toast"
    toastGui.ResetOnSpawn = false
    toastGui.Parent = playerGui

    registerTopGui(toastGui)

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0,1)
    root.Position = UDim2.new(0.02, 0, 0.98, 0)
    root.Size = UDim2.new(0, 320, 0, 64)
    root.BackgroundTransparency = 1
    root.Parent = toastGui

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Parent = root
    card.AnchorPoint = Vector2.new(0,1)
    card.Position = UDim2.new(0, 0, 1, 0)
    card.Size = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3 = Color3.fromRGB(22,22,22)
    card.BackgroundTransparency = 0.06
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    local cardCorner = Instance.new("UICorner"); cardCorner.Parent = card; cardCorner.CornerRadius = UDim.new(0,10)

    local glow = Instance.new("Frame")
    glow.Name = "Glow"
    glow.Parent = card
    glow.AnchorPoint = Vector2.new(0,0.5)
    glow.Position = UDim2.new(0, 8, 0.5, 0)
    glow.Size = UDim2.new(0, 48, 0, 48)
    glow.BackgroundColor3 = TRACER_COLOR
    glow.BackgroundTransparency = 0.8
    glow.BorderSizePixel = 0
    local glowCorner = Instance.new("UICorner"); glowCorner.Parent = glow; glowCorner.CornerRadius = UDim.new(0,12)

    local glowIcon = Instance.new("ImageLabel")
    glowIcon.Name = "GlowIcon"
    glowIcon.Parent = glow
    glowIcon.BackgroundTransparency = 1
    glowIcon.Size = UDim2.new(1, -4, 1, -4)
    glowIcon.Position = UDim2.new(0, 2, 0, 2)
    glowIcon.Image = "rbxassetid://108777284130945"
    glowIcon.ScaleType = Enum.ScaleType.Fit
    glowIcon.ImageTransparency = 0
    glowIcon.ImageColor3 = Color3.fromRGB(255,255,255)

    local txt = Instance.new("TextLabel")
    txt.Parent = card
    txt.AnchorPoint = Vector2.new(0,0.5)
    txt.Position = UDim2.new(0, 72, 0.5, 0)
    txt.Size = UDim2.new(0.7, 0, 0.9, 0)
    txt.BackgroundTransparency = 1
    txt.Text = "已成功越过反作弊 · UI 已加载"
    txt.TextColor3 = Color3.fromRGB(230,230,230)
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 14
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Center

    local small = Instance.new("TextLabel")
    small.Parent = card
    small.AnchorPoint = Vector2.new(1,0.5)
    small.Position = UDim2.new(1, -12, 0.5, 0)
    small.Size = UDim2.new(0.2, 0, 0.8, 0)
    small.BackgroundTransparency = 1
    small.Text = "v67"
    small.Font = Enum.Font.Gotham
    small.TextColor3 = Color3.fromRGB(170,170,170)
    small.TextScaled = true

    card.Position = UDim2.new(0, -350, 1, 0)
    local inTween = TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 1, 0)})
    inTween:Play()
    task.delay(60, function()
        local outTween = TweenService:Create(card, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, -350, 1, 0)})
        outTween:Play()
        outTween.Completed:Wait()
        toastGui:Destroy()
    end)
end

local function createLoaderUI()
    local isMobile = UserInputService.TouchEnabled
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("V67LoaderUI") or playerGui:FindFirstChild("V67ControlUI") then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "V67LoaderUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    registerTopGui(screenGui)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    if isMobile then
        mainFrame.Size = UDim2.new(0.85, 0, 0.24, 0)
    else
        mainFrame.Size = UDim2.new(0.45, 0, 0.22, 0)
    end
    mainFrame.BackgroundColor3 = Color3.fromRGB(10,10,10)
    mainFrame.BackgroundTransparency = 0
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0.03, 0)
    bgCorner.Parent = mainFrame

    local header = Instance.new("TextLabel")
    header.Parent = mainFrame
    header.AnchorPoint = Vector2.new(0.5, 0)
    header.Position = UDim2.new(0.5, 0, 0.08, 0)
    header.Size = UDim2.new(0.9, 0, 0.18, 0)
    header.BackgroundTransparency = 1
    header.Text = "加载中 · 请稍候"
    header.TextColor3 = TRACER_COLOR
    header.Font = Enum.Font.GothamBold
    header.TextScaled = true
    header.TextTransparency = 0

    local barBg = Instance.new("Frame")
    barBg.Parent = mainFrame
    barBg.AnchorPoint = Vector2.new(0.5,0)
    barBg.Position = UDim2.new(0.5, 0, 0.38, 0)
    barBg.Size = UDim2.new(0.86, 0, 0.18, 0)
    barBg.BackgroundColor3 = Color3.fromRGB(30,30,30)
    barBg.BorderSizePixel = 0
    local barCorner = Instance.new("UICorner"); barCorner.Parent = barBg; barCorner.CornerRadius = UDim.new(0.02, 0)

    local barFill = Instance.new("Frame")
    barFill.Parent = barBg
    barFill.AnchorPoint = Vector2.new(0,0.5)
    barFill.Position = UDim2.new(0, 0, 0.5, 0)
    barFill.Size = UDim2.new(0, 0, 0.85, 0)
    barFill.BackgroundColor3 = TRACER_COLOR
    barFill.BorderSizePixel = 0
    local fillCorner = Instance.new("UICorner"); fillCorner.Parent = barFill; fillCorner.CornerRadius = UDim.new(0.02, 0)
    local uiGradient = Instance.new("UIGradient"); uiGradient.Color = ColorSequence.new(TRACER_COLOR, Color3.fromRGB(255,180,200)); uiGradient.Rotation = 0; uiGradient.Parent = barFill

    local percentLabel = Instance.new("TextLabel")
    percentLabel.Parent = mainFrame
    percentLabel.AnchorPoint = Vector2.new(0.5, 0)
    percentLabel.Position = UDim2.new(0.5, 0, 0.6, 0)
    percentLabel.Size = UDim2.new(0.9, 0, 0.12, 0)
    percentLabel.BackgroundTransparency = 1
    percentLabel.Text = "0%"
    percentLabel.TextColor3 = Color3.fromRGB(220,220,220)
    percentLabel.Font = Enum.Font.Gotham
    percentLabel.TextScaled = true

    local status = Instance.new("TextLabel")
    status.Parent = mainFrame
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Position = UDim2.new(0.5, 0, 0.76, 0)
    status.Size = UDim2.new(0.9, 0, 0.12, 0)
    status.BackgroundTransparency = 1
    status.Text = "初始化界面"
    status.TextColor3 = Color3.fromRGB(160,160,160)
    status.Font = Enum.Font.Gotham
    status.TextScaled = true

    local totalTime = 2.2
    local startTime = tick()
    local function setProgress(t)
        local clamped = math.clamp(t, 0, 1)
        TweenService:Create(barFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(clamped, 0, 0.85, 0)}):Play()
        percentLabel.Text = tostring(math.floor(clamped * 100)) .. "%"
    end

    spawn(function()
        while true do
            local elapsed = tick() - startTime
            local t = math.clamp(elapsed / totalTime, 0, 1)
            setProgress(t)
            if t >= 1 then break end
            task.wait(0.03)
        end
        setProgress(1)
        status.Text = "加载完成，准备就绪"
        task.wait(0.45)
        local fadeTime = 0.6
        local fadeTween1 = TweenService:Create(mainFrame, TweenInfo.new(fadeTime), {BackgroundTransparency = 1})
        local fadeTween2 = TweenService:Create(header, TweenInfo.new(fadeTime), {TextTransparency = 1})
        local fadeTween3 = TweenService:Create(barBg, TweenInfo.new(fadeTime), {BackgroundTransparency = 1})
        local fadeTween4 = TweenService:Create(barFill, TweenInfo.new(fadeTime), {BackgroundTransparency = 1})
        local fadeTween5 = TweenService:Create(percentLabel, TweenInfo.new(fadeTime), {TextTransparency = 1})
        local fadeTween6 = TweenService:Create(status, TweenInfo.new(fadeTime), {TextTransparency = 1})
        fadeTween1:Play()
        fadeTween2:Play()
        fadeTween3:Play()
        fadeTween4:Play()
        fadeTween5:Play()
        fadeTween6:Play()
        fadeTween1.Completed:Wait()
        screenGui:Destroy()

        createControlsGui()
        showStartupToast()
    end)
end

local function ensureAutoRun()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local function spawnLoaderIfMissing()
        if not playerGui:FindFirstChild("V67LoaderUI") and not playerGui:FindFirstChild("V67ControlUI") then
            pcall(function() createLoaderUI() end)
        end
    end
    spawnLoaderIfMissing()
    playerGui.ChildRemoved:Connect(function(child)
        if child and (child.Name == "V67ControlUI" or child.Name == "V67LoaderUI" or child.Name == "V67Toast") then
            task.wait(0.25)
            spawnLoaderIfMissing()
        end
    end)

    -- 启动时根据设置自动停止音乐（如果设置为 auto stop）
    if SETTINGS.AutoStopMusicOnRun then
        pcall(stopMusic)
    end
end

ensureAutoRun()
