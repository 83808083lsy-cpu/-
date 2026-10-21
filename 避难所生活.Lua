local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local PathfindingService = game:GetService("PathfindingService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local Module = ReplicatedStorage:WaitForChild("Module")
local SL = require(Module:WaitForChild("SharedLibrary"))
local MovementShared = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("Movement"):WaitForChild("MovementShared"))
local Namespaces = require(ReplicatedStorage:WaitForChild("Service"):WaitForChild("Namespaces"))

--============================================================
-- 配置
--============================================================
local CFG = {
	AutoAttack = false,
	AutoFace = false,
	AutoEquip = false,
	AttackTeammates = false,
	AttackNPCs = false,
	ReachBoost = false,

	AttackCooldown = 0.75,
	Adaptive = true,
	AuraIntervalMul = 1,

	KillAura = false,
	AuraDirect = true,
	AuraAnim = false,
	AuraRadius = 10,
	AuraHead = false,
	AuraCustomRange = false,

	MultiTargetAttack = false,
	MultiTargetCount = 1,
	UseWeaponSpeed = false,  -- v3.3 新增：使用武器原始攻速

	Whitelist = {},
	Blacklist = {},
	OnlyAttackBlacklist = false,
	ESPOnlyBlacklist = false,

	ItemFilter = {},

	Stealth = false,
	SafeSpeed = 34,

	NoCameraShake = false,
	NoScreenFX = false,
	PerfMode = false,
	HideGameUI = false,
	CustomFOV = false,
	FOV = 70,

	Noclip = false,
	Fly = false,
	FlySpeed = 36,
	InfiniteJump = false,
	MoveMode = "WalkSpeed",

	AutoWalkDoor = false,
	AutoWalkLoot = false,
	AutoPath = false,

	AutoBestWeapon = false,
	AutoShoot = false,
	ShootOnlyPlayers = false,
	CombatFollow = false,
	AutoOpenDoors = false,
	PlayerList = false,
	InfoHUD = false,
	AutoGetUp = false,
	Freecam = false,

	PlayerESP = true,
	EnemyOnly = false,
	ItemESP = true,
	DoorESP = true,

	ESPPlayerExcludeList = {},
	ESPShowPumpkins = true,
	ESPShowPickups = true,
	ESPItemKeywordList = {},
	ESPDoorKeywordList = { "WindowedDoor" },

	AutoInteract = false,
	InteractAll = false,

	InfiniteStamina = false,
	HighJump = false,
	Fullbright = false,
	AntiAFK = false,

	Speed = 16,
	UIScale = 100,

	ESPPerfMode = "Standard",

	AttackInterval = 0.10,
	MaxTargetDistance = 12,
	MaxESPDistance = 900,
	MaxItemDistance = 400,
	InteractInterval = 0.12,

	__listEditMode = "White",
}
shared.__AsylumHubCFG = CFG

--============================================================
-- 清理旧实例
--============================================================
for _, n in ipairs({ "AsylumHub", "AsylumHubESP", "AsylumHubWS", "AsylumHubList", "AsylumHubStatus", "LinkCcUI" }) do
	local a = PlayerGui:FindFirstChild(n)
	if a then a:Destroy() end
	local b = Workspace:FindFirstChild(n)
	if b then b:Destroy() end
	local c = CoreGui:FindFirstChild(n)
	if c then c:Destroy() end
end
if shared.__HubRender then
	pcall(function() RunService:UnbindFromRenderStep(shared.__HubRender) end)
	shared.__HubRender = nil
end
do
	local oldCC = Lighting:FindFirstChild("HubFullbright")
	if oldCC then oldCC:Destroy() end
end
if shared.__HubConn and typeof(shared.__HubConn) == "table" then
	for _, c in ipairs(shared.__HubConn) do pcall(function() c:Disconnect() end) end
end
shared.__HubConn = {}

do
	local prev = shared.__HubVisualState
	if prev then
		if prev.fxDisabled then
			for e in pairs(prev.fxDisabled) do if e and e.Parent then pcall(function() e.Enabled = true end) end end
		end
		if prev.perfHidden then
			for d in pairs(prev.perfHidden) do if d and d.Parent then pcall(function() d.Enabled = true end) end end
		end
		if prev.hiddenGUIs then
			for g in pairs(prev.hiddenGUIs) do if g and g.Parent then pcall(function() g.Enabled = true end) end end
		end
	end
end

local fxDisabled = {}
local perfHidden = {}
local hiddenGUIs = {}
shared.__HubVisualState = { fxDisabled = fxDisabled, perfHidden = perfHidden, hiddenGUIs = hiddenGUIs }

local function keep(c)
	table.insert(shared.__HubConn, c)
	return c
end

local Handlers = {}
local promptSet = {}
local promptState = {}
local UIToggles = {}
local UISliders = {}
local doorHighlights = {}

local hubMoveTarget = nil
local hubMoveEndTime = 0

local activeSliderUpdate = nil
keep(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeSliderUpdate = nil
	end
end))
keep(UserInputService.InputChanged:Connect(function(input)
	if activeSliderUpdate and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		activeSliderUpdate(input)
	end
end))

local function parseKeywords(str)
	local list = {}
	for k in tostring(str or ""):gmatch("[^,，]+") do
		local trimmed = k:gsub("^%s+", ""):gsub("%s+$", "")
		if trimmed ~= "" then list[#list + 1] = trimmed end
	end
	return list
end

local function matchAnyKeyword(name, keywords)
	if type(keywords) ~= "table" or #keywords == 0 then return false end
	local lower = tostring(name or ""):lower()
	for _, k in ipairs(keywords) do
		if lower:find(tostring(k):lower(), 1, true) then return true end
	end
	return false
end

local function colorNearlyEqual(a, b, eps)
	if not a or not b then return false end
	eps = eps or 0.02
	return math.abs(a.R - b.R) < eps and math.abs(a.G - b.G) < eps and math.abs(a.B - b.B) < eps
end

local function isWhitelisted(player)
	if not player then return false end
	return CFG.Whitelist[player.Name] == true
end
local function isBlacklisted(player)
	if not player then return false end
	return CFG.Blacklist[player.Name] == true
end
local function isItemAllowed(itemName)
	if not itemName then return true end
	return CFG.ItemFilter[itemName] ~= false
end

--============================================================
-- 性能模式 FPS 智能优化器
--============================================================
local autoPerf = { Level = 0, LowStreak = 0, HighStreak = 0, LastCheck = 0 }

local PERF_LEVELS = {
	[0] = { playerMax = 12, itemMax = 8,  doorMax = 6, espDist = 400, itemDist = 200, ringInterval = 0.10 },
	[1] = { playerMax = 10, itemMax = 6,  doorMax = 5, espDist = 300, itemDist = 150, ringInterval = 0.12 },
	[2] = { playerMax = 8,  itemMax = 4,  doorMax = 4, espDist = 220, itemDist = 120, ringInterval = 0.15 },
	[3] = { playerMax = 6,  itemMax = 3,  doorMax = 3, espDist = 150, itemDist = 80,  ringInterval = 0.20 },
}

local function useAdaptivePerf()
	return CFG.PerfMode or CFG.ESPPerfMode == "Adaptive"
end

local function updateAutoPerf(dt, fps)
	if not useAdaptivePerf() then
		autoPerf.Level = 0; autoPerf.LowStreak = 0; autoPerf.HighStreak = 0
		return
	end
	autoPerf.LastCheck = autoPerf.LastCheck + dt
	if autoPerf.LastCheck < 0.5 then return end
	autoPerf.LastCheck = 0

	if fps < 40 then
		autoPerf.LowStreak = autoPerf.LowStreak + 1
		autoPerf.HighStreak = 0
		if autoPerf.LowStreak >= 2 and autoPerf.Level < 3 then
			autoPerf.Level = autoPerf.Level + 1
			autoPerf.LowStreak = 0
		end
	elseif fps > 55 then
		autoPerf.HighStreak = autoPerf.HighStreak + 1
		autoPerf.LowStreak = 0
		if autoPerf.HighStreak >= 3 and autoPerf.Level > 0 then
			autoPerf.Level = autoPerf.Level - 1
			autoPerf.HighStreak = 0
		end
	else
		autoPerf.LowStreak = 0; autoPerf.HighStreak = 0
	end
end

local function getPerfParams()
	if not useAdaptivePerf() then
		return {
			playerMax = 30, itemMax = 25, doorMax = 15,
			espDist = CFG.MaxESPDistance, itemDist = CFG.MaxItemDistance,
			ringInterval = 0, isPerf = false, level = 0,
		}
	end
	local lv = PERF_LEVELS[autoPerf.Level] or PERF_LEVELS[0]
	return {
		playerMax = lv.playerMax, itemMax = lv.itemMax, doorMax = lv.doorMax,
		espDist = lv.espDist, itemDist = lv.itemDist,
		ringInterval = 0, isPerf = true, level = autoPerf.Level,
	}
end

--============================================================
-- RaycastHitbox 缓存
--============================================================
local _RaycastHitboxModule
local function getRaycastHitbox()
	if not _RaycastHitboxModule then
		_RaycastHitboxModule = require(Module:WaitForChild("RaycastHitbox"))
	end
	return _RaycastHitboxModule
end

--============================================================
-- UI 与 ESP 核心容器初始化
--============================================================
local ESP = Instance.new("ScreenGui")
ESP.Name = "AsylumHubESP"; ESP.ResetOnSpawn = false; ESP.IgnoreGuiInset = true
ESP.DisplayOrder = 150000; ESP.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ESP.Parent = PlayerGui

local WsFolder = Instance.new("Folder", Workspace)
WsFolder.Name = "AsylumHubWS"

local AURA_RING_N = 24
local auraRingParts = {}
for i = 1, AURA_RING_N do
	local part = Instance.new("Part")
	part.Name = "AuraRingSeg" .. i
	part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false; part.Massless = true
	part.Material = Enum.Material.Neon
	part.Size = Vector3.new(0.5, 0.1, 1)
	part.Color = Color3.fromRGB(60, 255, 60)
	part.Transparency = 1
	part.Parent = WsFolder
	auraRingParts[i] = part
end

--============================================================
-- ReachBoost 全局清理辅助
--============================================================
local reachApplied = {}

local function clearAllReachPoints()
	local function scanTool(tool)
		local hb = tool:FindFirstChild("Hitbox")
		if not hb then return end
		local RaycastHitbox = getRaycastHitbox()
		local obj = nil
		pcall(function() obj = RaycastHitbox.GetHitbox(hb) end)
		for _, a in ipairs(hb:GetChildren()) do
			if a:IsA("Attachment") and a:GetAttribute("HubReachPoint") then
				if obj and obj.HitboxRaycastPoints then
					for i = #obj.HitboxRaycastPoints, 1, -1 do
						if obj.HitboxRaycastPoints[i] == a then table.remove(obj.HitboxRaycastPoints, i) end
					end
				end
				a:Destroy()
			end
		end
	end
	
	local char = LP.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Tool") then scanTool(d) end
		end
	end
	local bp = LP:FindFirstChild("Backpack")
	if bp then
		for _, d in ipairs(bp:GetDescendants()) do
			if d:IsA("Tool") then scanTool(d) end
		end
	end
	table.clear(reachApplied)
end

--============================================================
-- 公共模型扫描（去重）
--============================================================
local function scanAllModels()
	local playerChars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then playerChars[p.Character] = p end
	end
	local scanned = {}
	local list = {}
	for char in pairs(playerChars) do scanned[char] = true end
	
	local folder = Workspace:FindFirstChild("Characters")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Model") and not scanned[m] and m:FindFirstChildOfClass("Humanoid") then
				scanned[m] = true
				list[#list + 1] = m
			end
		end
	end
	for _, m in ipairs(Workspace:GetChildren()) do
		if m:IsA("Model") and m.Name ~= "Characters" and not scanned[m] and m:FindFirstChildOfClass("Humanoid") then
			scanned[m] = true
			list[#list + 1] = m
		end
	end
	return list, playerChars
end

--============================================================
-- 功能实现
--============================================================
local charConns = {}
local function onCharacter(char)
	for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
	charConns = {}
	if not char then return end
	task.delay(1, function()
		pcall(function() SL.UpdateWalkspeed(CFG.Speed) end)
		if CFG.HighJump then pcall(function() SL.UpdateJumpParameters(13) end) end
		if CFG.Noclip then pcall(setCharCollide, char, false) end
		if CFG.ReachBoost then pcall(Handlers.ReachBoost, true) end
	end)
end

local staminaName = "Hub_InfStamina"
local staminaBound = false
local function applyStamina(v)
	if v and not staminaBound then
		staminaBound = true
		RunService:BindToRenderStep(staminaName, Enum.RenderPriority.Character.Value + 2, function()
			if not CFG.InfiniteStamina then return end
			local gm = MovementShared.getPlayerMaximumEnergy
			local ge = MovementShared.getPlayerEnergy
			local se = MovementShared.setPlayerEnergy
			if gm and ge and se then
				local m = gm()
				if type(m) ~= "number" then m = 100 end
				if ge() < m then se(m) end
			end
		end)
	elseif not v and staminaBound then
		staminaBound = false
		pcall(function() RunService:UnbindFromRenderStep(staminaName) end)
	end
end
Handlers.InfiniteStamina = applyStamina

Handlers.HighJump = function(v)
	pcall(function()
		if v then SL.UpdateJumpParameters(13) else SL.UpdateJumpParameters(StarterPlayer.CharacterJumpHeight) end
	end)
end

local lightOrig
local fullbrightCC
Handlers.Fullbright = function(v)
	pcall(function()
		if v then
			if not lightOrig then
				lightOrig = {
					Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
					OutdoorAmbient = Lighting.OutdoorAmbient, ClockTime = Lighting.ClockTime,
					GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd,
				}
			end
			if not fullbrightCC or not fullbrightCC.Parent then
				fullbrightCC = Instance.new("ColorCorrectionEffect")
				fullbrightCC.Name = "HubFullbright"
				fullbrightCC.Brightness = 0.15; fullbrightCC.Contrast = 0.05
				fullbrightCC.Saturation = 0; fullbrightCC.TintColor = Color3.fromRGB(255, 250, 240)
				fullbrightCC.Parent = Lighting
			end
		else
			if fullbrightCC then fullbrightCC:Destroy(); fullbrightCC = nil end
			if lightOrig then
				Lighting.Brightness = lightOrig.Brightness; Lighting.Ambient = lightOrig.Ambient
				Lighting.OutdoorAmbient = lightOrig.OutdoorAmbient; Lighting.ClockTime = lightOrig.ClockTime
				Lighting.GlobalShadows = lightOrig.GlobalShadows; Lighting.FogEnd = lightOrig.FogEnd
				lightOrig = nil
			end
		end
	end)
end

local afkConn
Handlers.AntiAFK = function(v)
	if v then
		if not afkConn then
			afkConn = LP.Idled:Connect(function()
				pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
			end)
		end
	else
		if afkConn then afkConn:Disconnect(); afkConn = nil end
	end
end

local prevSpeedBeforeStealth = nil
Handlers.Stealth = function(v)
	if v then
		prevSpeedBeforeStealth = CFG.Speed
		if CFG.Speed > CFG.SafeSpeed then
			CFG.Speed = CFG.SafeSpeed
			if UISliders.Speed then UISliders.Speed(CFG.Speed) end
			pcall(function() SL.UpdateWalkspeed(CFG.Speed) end)
		end
	else
		if prevSpeedBeforeStealth then
			CFG.Speed = prevSpeedBeforeStealth
			if UISliders.Speed then UISliders.Speed(CFG.Speed) end
			pcall(function() SL.UpdateWalkspeed(CFG.Speed) end)
			prevSpeedBeforeStealth = nil
		end
	end
end

local PlayerSettings = require(ReplicatedStorage:WaitForChild("PlayerSettings"))
Handlers.NoCameraShake = function(v)
	pcall(function() PlayerSettings:Set("CameraShakeEnabled", not v) end)
end

local function applyNoFX(on)
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") and e.Name ~= "HubFullbright" then
			if on then
				if e.Enabled then e.Enabled = false; fxDisabled[e] = true end
			elseif fxDisabled[e] then
				if e.Parent then e.Enabled = true end
				fxDisabled[e] = nil
			end
		end
	end
end
Handlers.NoScreenFX = function(v) applyNoFX(v) end

Handlers.PerfMode = function(v)
	if v then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")) and d.Enabled then
				d.Enabled = false
				perfHidden[d] = true
			end
		end
		for door, h in pairs(doorHighlights) do
			if h then h:Destroy() end
			doorHighlights[door] = nil
		end
	else
		for d in pairs(perfHidden) do if d.Parent then d.Enabled = true end end
		table.clear(perfHidden)
		autoPerf.Level = 0; autoPerf.LowStreak = 0; autoPerf.HighStreak = 0
	end
end

local function applyHideUI(on)
	for _, g in ipairs(PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Name ~= "LinkCcUI" and g.Name ~= "AsylumHubESP" and g.Name ~= "AsylumHubStatus" and g.Name ~= "AsylumHubList" then
			if on then
				if g.Enabled then g.Enabled = false; hiddenGUIs[g] = true end
			elseif hiddenGUIs[g] then
				if g.Parent then g.Enabled = true end
				hiddenGUIs[g] = nil
			end
		end
	end
end
Handlers.HideGameUI = function(v) applyHideUI(v) end

local flyBV = nil
local function setCharCollide(ch, collide)
	if not ch then return end
	for _, p in ipairs(ch:GetDescendants()) do
		if p:IsA("BasePart") and not p:FindFirstAncestorOfClass("Accessory") then
			if p.CanCollide ~= collide then
				p.CanCollide = collide
			end
		end
	end
end

Handlers.Noclip = function(v)
	if not v then
		if not hubMoveTarget then
			pcall(setCharCollide, LP.Character, true)
		end
	end
end

Handlers.Fly = function(v)
	if not v then
		if flyBV then flyBV:Destroy() end
		flyBV = nil
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		end
	end
end

local freecamCF = CFrame.new()
Handlers.Freecam = function(v)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if v then
		freecamCF = cam.CFrame
		cam.CameraType = Enum.CameraType.Scriptable
	else
		pcall(function() cam.CameraType = Enum.CameraType.Custom end)
	end
end

Handlers.ReachBoost = function(v)
	if not v then
		clearAllReachPoints()
		return
	end
	local char = LP.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then return end
	local hbPart = tool:FindFirstChild("Hitbox")
	if not hbPart then return end

	local RaycastHitbox = getRaycastHitbox()
	local obj = nil
	pcall(function() obj = RaycastHitbox.GetHitbox(hbPart) end)

	if reachApplied[tool] then return end
	reachApplied[tool] = true
	local added = {}
	for _, r in ipairs({ 3.5, 6, 8 }) do
		for _, dir in ipairs({
			Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
			Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
			Vector3.new(1, 0, 1), Vector3.new(-1, 0, -1),
			Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1),
		}) do
			local a = Instance.new("Attachment")
			a.Name = "DmgPoint"
			a.Position = dir.Unit * r
			a:SetAttribute("HubReachPoint", true)
			a.Parent = hbPart
			added[#added + 1] = a
		end
	end
	if obj and obj.HitboxRaycastPoints then
		for _, a in ipairs(added) do table.insert(obj.HitboxRaycastPoints, a) end
	end
end

--============================================================
-- 移动逻辑
--============================================================
local function getHorizontalDir(hum)
	local dir = hum.MoveDirection
	if not dir then return nil end
	local h = Vector3.new(dir.X, 0, dir.Z)
	if h.Magnitude < 0.01 then return nil end
	return h.Unit
end

local function applySpeed(dt, hum, hrp)
	local mode = CFG.MoveMode or "WalkSpeed"
	local speed = CFG.Stealth and math.min(CFG.Speed, CFG.SafeSpeed) or CFG.Speed

	if mode == "WalkSpeed" then
		if math.abs(hum.WalkSpeed - speed) > 0.1 then hum.WalkSpeed = speed end
	elseif mode == "Velocity" then
		if hum.WalkSpeed > 16 then hum.WalkSpeed = 16 end
		local dir = getHorizontalDir(hum)
		if dir then
			local v = hrp.AssemblyLinearVelocity
			local targetV = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
			if (v - targetV).Magnitude > 2 then hrp.AssemblyLinearVelocity = targetV end
		end
	elseif mode == "MoveDirection" then
		if math.abs(hum.WalkSpeed - speed) > 0.1 then hum.WalkSpeed = speed end
		local dir = getHorizontalDir(hum)
		if dir then hum:Move(dir, false) end
	end
end

local function requestMove(targetPos)
	if not targetPos then return end
	if not CFG.AutoPath then return end
	hubMoveTarget = targetPos
	hubMoveEndTime = os.clock() + 30
end

--============================================================
-- 自动攻击 / 光环
--============================================================
local lastActivate = 0
local lastEquipTry = 0

local function isWeaponTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	if tool:GetAttribute("BaseDamage") ~= nil then return true end
	local primary = tool:FindFirstChild("Primary")
	if primary and primary:GetAttribute("AnimationAttack1") then return true end
	return false
end

local function findBestWeapon()
	local bp = LP:FindFirstChild("Backpack")
	if not bp then return nil end
	local best, bestDmg
	for _, t in ipairs(bp:GetDescendants()) do
		if t:IsA("Tool") and isWeaponTool(t) then
			local dmg = tonumber(t:GetAttribute("BaseDamage")) or 0
			if not bestDmg or dmg > bestDmg then best = t; bestDmg = dmg end
		end
	end
	return best
end

local function equipWeapon(hum)
	local best
	if CFG.AutoBestWeapon then
		best = findBestWeapon()
	else
		local bp = LP:FindFirstChild("Backpack")
		if bp then
			for _, t in ipairs(bp:GetDescendants()) do
				if t:IsA("Tool") and isWeaponTool(t) then best = t; break end
			end
		end
	end
	if best then pcall(function() hum:EquipTool(best) end) end
end

local function getTarget(maxDist, playersOnly)
	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if not myRoot or not myHum or myHum.Health <= 0 then return nil end

	local myTeam = LP.Team
	local bestAny, bestAnyDist = nil, nil
	local bestBlack, bestBlackDist = nil, nil

	local function consider(char, player)
		if not char or char == myChar then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health <= 0 then return end
		local isBlack = false
		if player then
			if player == LP then return end
			if isWhitelisted(player) then return end
			if not CFG.AttackTeammates and player.Team == myTeam then return end
			isBlack = isBlacklisted(player)
			if CFG.OnlyAttackBlacklist and not isBlack then return end
		else
			if CFG.OnlyAttackBlacklist then return end
		end
		local d = (root.Position - myRoot.Position).Magnitude
		if d > maxDist then return end
		local entry = { char = char, hum = hum, root = root, player = player, black = isBlack }
		if isBlack then
			if not bestBlackDist or d < bestBlackDist then
				bestBlack = entry; bestBlackDist = d
			end
		end
		if not bestAnyDist or d < bestAnyDist then
			bestAny = entry; bestAnyDist = d
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then consider(p.Character, p) end
	end

	if CFG.AttackNPCs and not playersOnly then
		local models = scanAllModels()
		for _, m in ipairs(models) do
			consider(m, nil)
		end
	end

	if bestBlack then return bestBlack end
	return bestAny
end

-- 【v3.3】读取武器原始攻速（优先 CooldownTime，其次 1/Speed）
local function getWeaponOriginalInterval(tool)
	if not tool then return nil end
	local cd = tonumber(tool:GetAttribute("CooldownTime"))
	if cd and cd > 0 then
		return math.clamp(cd, 0.08, 2.5)
	end
	local spd = tonumber(tool:GetAttribute("Speed"))
	if spd and spd > 0 then
		return math.clamp(1 / spd, 0.08, 2.5)
	end
	return nil
end

local function resolveAttackInterval(baseCd, tool)
	-- 【v3.3】使用武器原始攻速
	if CFG.UseWeaponSpeed and tool then
		local orig = getWeaponOriginalInterval(tool)
		if orig then
			return orig
		end
		return baseCd or CFG.AttackCooldown
	end
	if CFG.MultiTargetAttack then
		return math.max(CFG.AttackCooldown, 0.3)
	end
	if CFG.Adaptive then
		local cd = tonumber(baseCd) or 0.9
		return math.max(0.15, cd * 0.75) * CFG.AuraIntervalMul
	else
		return math.clamp(CFG.AttackCooldown, 0.5, 1.0)
	end
end

local function isRangedTool(tool)
	if not isWeaponTool(tool) then return false end
	local rangedAttrs = {
		"Ammo", "FireMode", "Magazine", "Cartridge", "Projectile",
		"BulletType", "ProjectileSpeed", "Spread", "Recoil",
	}
	for _, attr in ipairs(rangedAttrs) do
		if tool:GetAttribute(attr) ~= nil then return true end
	end
	for _, d in ipairs(tool:GetDescendants()) do
		local n = d.Name:lower()
		if n:find("muzzle", 1, true) or n:find("barrel", 1, true) or n:find("gun", 1, true) then
			return true
		end
	end
	for _, d in ipairs(tool:GetDescendants()) do
		local n = d.Name:lower()
		if n:find("hitbox", 1, true) or n:find("blade", 1, true) then
			return false
		end
	end
	return false
end

local lastShoot = 0
local function doAutoShoot(cam)
	if not CFG.AutoShoot then return end
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool or not isRangedTool(tool) then return end

	local range = tonumber(tool:GetAttribute("Range")) or 150
	local target = getTarget(math.min(range, 300), CFG.ShootOnlyPlayers)
	if not target then return end

	local aimPart = target.char:FindFirstChild("Head") or target.root
	if not aimPart then return end

	if not CFG.Freecam then
		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPart.Position)
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local look = Vector3.new(aimPart.Position.X, root.Position.Y, aimPart.Position.Z)
		if (look - root.Position).Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, look) end
	end

	local now = os.clock()
	local cd = tonumber(tool:GetAttribute("CooldownTime")) or 0.3
	local interval = math.clamp(cd, 0.08, 0.5)
	if now - lastShoot >= interval then
		lastShoot = now
		pcall(function() tool:Activate() end)
	end
end

local function doAutoAttack()
	if not CFG.AutoAttack then return end
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local target = getTarget(CFG.MaxTargetDistance)
	if not target then return end

	local tool = char:FindFirstChildOfClass("Tool")
	if not isWeaponTool(tool) then
		local now0 = os.clock()
		if CFG.AutoEquip and now0 - lastEquipTry > 1 then
			lastEquipTry = now0
			equipWeapon(hum)
			return
		end
		return
	end

	if isRangedTool(tool) then return end

	if CFG.CombatFollow then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (target.root.Position - root.Position).Magnitude
			if d > 4 then requestMove(target.root.Position) end
		end
	end

	local interval = resolveAttackInterval(tool:GetAttribute("CooldownTime"), tool)
	-- 使用武器原始攻速时不加随机
	if CFG.Stealth and not CFG.UseWeaponSpeed then
		interval = interval * (0.9 + math.random() * 0.2)
	end

	local now = os.clock()
	if now - lastActivate >= interval then
		lastActivate = now
		pcall(function() tool:Activate() end)
	end
end

local auraSent, auraEffective = 0, 0
local auraRotate = 0
local lastAura = 0
local pendingHits = {}
local hitCooldowns = {}
local snapSent, snapEff = 0, 0
local lastAdapt = 0
local auraStatus = ""
local auraTargetCache = {}
local auraCacheTime = 0

local function collectTargets(radius, maxN)
	local list = {}
	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return list end
	local myTeam = LP.Team
	local playerChars = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then playerChars[p.Character] = p end end
	local function add(char, player)
		if not char or char == myChar then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health <= 0 then return end
		local isBlack = false
		if player then
			if player == LP then return end
			if isWhitelisted(player) then return end
			if not CFG.AttackTeammates and player.Team == myTeam then return end
			isBlack = isBlacklisted(player)
			if CFG.OnlyAttackBlacklist and not isBlack then return end
		else
			if CFG.OnlyAttackBlacklist then return end
		end
		local d = (root.Position - myRoot.Position).Magnitude
		if d <= radius then
			list[#list + 1] = { char = char, hum = hum, root = root, player = player, d = d, black = isBlack }
		end
	end
	for char, p in pairs(playerChars) do if p ~= LP then add(char, p) end end
	if CFG.AttackNPCs then
		local models = scanAllModels()
		for _, m in ipairs(models) do
			add(m, nil)
		end
	end
	table.sort(list, function(a, b)
		local ab = a.black and 1 or 0
		local bb = b.black and 1 or 0
		if ab ~= bb then return ab > bb end
		return a.d < b.d
	end)
	local out = {}
	for i = 1, math.min(#list, maxN) do out[i] = list[i] end
	return out
end

local function processPending()
	local now = os.clock()
	for i = #pendingHits, 1, -1 do
		local h = pendingHits[i]
		if now - h.t > 0.45 and now - h.t < 5 then
			if h.hum and h.hum.Parent and h.hum.Health < h.before then
				auraEffective = auraEffective + 1
			end
			table.remove(pendingHits, i)
		end
	end
end

local function doKillAura()
	if not CFG.KillAura then return end
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local tool = char:FindFirstChildOfClass("Tool")
	if not isWeaponTool(tool) then
		local now0 = os.clock()
		if CFG.AutoEquip and now0 - lastEquipTry > 1 then
			lastEquipTry = now0
			equipWeapon(hum)
			return
		end
		return
	end

	if isRangedTool(tool) then auraStatus = "当前武器是远程武器，用「自动射击」"; return end

	processPending()

	local toolRange = tonumber(tool:GetAttribute("Range")) or 10
	local radius = math.min(CFG.AuraRadius, toolRange)
	if CFG.AuraCustomRange then radius = CFG.AuraRadius end

	local maxTargets = 1
	if CFG.MultiTargetAttack then maxTargets = math.clamp(CFG.MultiTargetCount, 1, 3) end

	local now = os.clock()
	local interval = resolveAttackInterval(tool:GetAttribute("CooldownTime"), tool)
	-- 使用武器原始攻速时不加随机
	if CFG.Stealth and not CFG.UseWeaponSpeed then
		interval = interval * (0.9 + math.random() * 0.2)
	end
	if now - lastAura < interval then return end
	lastAura = now

	if now - auraCacheTime > 0.4 or #auraTargetCache == 0 then
		auraCacheTime = now
		auraTargetCache = collectTargets(radius, math.max(maxTargets, 1))
	end

	local targets = auraTargetCache
	if #targets == 0 then auraStatus = string.format("范围内无目标（%.0f 格）", radius); return end

	if not CFG.AuraDirect then
		if CFG.AuraAnim then pcall(function() tool:Activate() end) end
		auraStatus = "⚠ 直伤已关闭，光环无伤害输出（仅动画）"
		return
	end

	if CFG.AuraAnim then pcall(function() tool:Activate() end) end

	auraRotate = (auraRotate % #targets) + 1
	local t = targets[auraRotate]

	if not t or not t.hum or not t.hum.Parent or t.hum.Health <= 0 then
		auraTargetCache = {}; auraRotate = 0; return
	end

	local lastHit = hitCooldowns[t.hum]
	if lastHit and now - lastHit < 0.5 then return end

	local part = t.char:FindFirstChild(CFG.AuraHead and "Head" or "HumanoidRootPart") or t.root
	local before = t.hum.Health
	local ok = pcall(function() Namespaces.MeleeReplication.packets.sendHit.send({ t.hum, part, tool }) end)
	if ok then
		auraSent = auraSent + 1
		hitCooldowns[t.hum] = now
		table.insert(pendingHits, { hum = t.hum, before = before, t = now })
		auraStatus = string.format("直伤 %d/%d | 间隔 %.2fs | 半径 %.0f", auraRotate, #targets, interval, radius)
	end

	if AuraStats and AuraStats.Visible then
		shared.__auraStats = { sent = auraSent, eff = auraEffective, mul = CFG.AuraIntervalMul, interval = interval }
	end
end

--============================================================
-- 光环半径可视化
--============================================================
local function hideAuraRing()
	for _, p in ipairs(auraRingParts) do
		if p.Transparency ~= 1 then p.Transparency = 1 end
	end
end

local function updateAuraRing(params)
	if not CFG.KillAura then hideAuraRing(); return end

	local char = LP.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not (tool and isWeaponTool(tool)) then hideAuraRing(); return end

	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then hideAuraRing(); return end

	local radius = CFG.AuraRadius
	if not CFG.AuraCustomRange then
		local toolRange = tonumber(tool:GetAttribute("Range")) or 10
		radius = math.min(radius, toolRange)
	end

	local hasEnemy = false
	local myTeam = LP.Team
	local myPos = hrp.Position

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			if not isWhitelisted(p) then
				local ehrp = p.Character:FindFirstChild("HumanoidRootPart")
				local ehum = p.Character:FindFirstChildOfClass("Humanoid")
				if ehrp and ehum and ehum.Health > 0 then
					local isEnemy = CFG.AttackTeammates or p.Team ~= myTeam
					if isEnemy then
						if not CFG.OnlyAttackBlacklist or isBlacklisted(p) then
							if (ehrp.Position - myPos).Magnitude <= radius then hasEnemy = true; break end
						end
					end
				end
			end
		end
	end

	if not hasEnemy and CFG.AttackNPCs and not CFG.OnlyAttackBlacklist then
		local models = scanAllModels()
		for _, m in ipairs(models) do
			local ehrp = m:FindFirstChild("HumanoidRootPart")
			local ehum = m:FindFirstChildOfClass("Humanoid")
			if ehrp and ehum and ehum.Health > 0 then
				if (ehrp.Position - myPos).Magnitude <= radius then hasEnemy = true; break end
			end
		end
	end

	local color = hasEnemy and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 255, 60)
	local basePos = Vector3.new(hrp.Position.X, hrp.Position.Y - 2.7, hrp.Position.Z)
	local chord = 2 * radius * math.sin(math.pi / AURA_RING_N) * 1.15

	for i = 1, AURA_RING_N do
		local phi = (i / AURA_RING_N) * math.pi * 2
		local cx = math.cos(phi) * radius
		local cz = math.sin(phi) * radius
		local p = auraRingParts[i]
		p.Color = color
		p.Transparency = 0.35
		p.Size = Vector3.new(0.5, 0.1, chord)
		p.CFrame = CFrame.new(basePos + Vector3.new(cx, 0, cz)) * CFrame.Angles(0, -phi, 0)
	end
end

local function mkObj(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function newBoxMarker()
	local m = { edges = {} }
	for i = 1, 4 do
		m.edges[i] = mkObj("Frame", { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 20 }, ESP)
	end
	m.fill = mkObj("Frame", { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.9, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 19 }, ESP)
	m.name = mkObj("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.new(0,0,0), AnchorPoint = Vector2.new(0.5, 1), Visible = false, ZIndex = 22, RichText = true, Size = UDim2.fromOffset(190, 34) }, ESP)
	m.dist = mkObj("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = Color3.fromRGB(220, 220, 220), TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0,0,0), AnchorPoint = Vector2.new(0.5, 0), Visible = false, ZIndex = 22, Size = UDim2.fromOffset(120, 16) }, ESP)
	m.hpBg = mkObj("Frame", { BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, ZIndex = 21 }, ESP)
	m.hpFill = mkObj("Frame", { BackgroundColor3 = Color3.fromRGB(90,220,110), BorderSizePixel = 0, Visible = false, ZIndex = 21 }, ESP)
	return m
end

local function hideMarker(m)
	for i = 1, 4 do m.edges[i].Visible = false end
	m.fill.Visible = false; m.name.Visible = false; m.dist.Visible = false; m.hpBg.Visible = false; m.hpFill.Visible = false
end

local function projectRect(cam, cf, size, isPerf)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2

	if isPerf then
		local sp1 = cam:WorldToViewportPoint((cf * CFrame.new(-hx, -hy, -hz)).Position)
		local sp2 = cam:WorldToViewportPoint((cf * CFrame.new(hx, hy, hz)).Position)
		if sp1.Z <= 0 or sp2.Z <= 0 then return nil end
		return math.min(sp1.X, sp2.X), math.min(sp1.Y, sp2.Y), math.max(sp1.X, sp2.X), math.max(sp1.Y, sp2.Y)
	end

	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local any = false
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local p = (cf * CFrame.new(sx * hx, sy * hy, sz * hz)).Position
				local sp = cam:WorldToViewportPoint(p)
				if sp.Z > 0 then
					any = true
					if sp.X < minX then minX = sp.X end; if sp.Y < minY then minY = sp.Y end
					if sp.X > maxX then maxX = sp.X end; if sp.Y > maxY then maxY = sp.Y end
				end
			end
		end
	end
	if not any then return nil end
	return minX, minY, maxX, maxY
end

local function drawBox(m, cam, cf, size, color, title, sub, hpRatio, minW, minH, isPerf)
	local x1, y1, x2, y2 = projectRect(cam, cf, size, isPerf)
	local vp = cam.ViewportSize
	if not x1 or (x2 < 0 or y2 < 0 or x1 > vp.X or y1 > vp.Y) then hideMarker(m); return end
	local w, h = x2 - x1, y2 - y1
	local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
	if w < (minW or 12) then w = minW or 12 end
	if h < (minH or 18) then h = minH or 18 end
	local left, top = cx - w / 2, cy - h / 2

	for i = 1, 4 do
		m.edges[i].BackgroundColor3 = color; m.edges[i].Visible = true
		if i <= 2 then m.edges[i].Size = UDim2.fromOffset(w, 1.5) else m.edges[i].Size = UDim2.fromOffset(1.5, h) end
	end
	m.edges[1].Position = UDim2.fromOffset(cx, top); m.edges[2].Position = UDim2.fromOffset(cx, top + h)
	m.edges[3].Position = UDim2.fromOffset(left, cy); m.edges[4].Position = UDim2.fromOffset(left + w, cy)

	m.fill.Visible = true; m.fill.BackgroundColor3 = color
	m.fill.Position = UDim2.fromOffset(cx, cy); m.fill.Size = UDim2.fromOffset(w, h)

	m.name.Visible = title ~= nil
	if title then m.name.Text = title; m.name.TextColor3 = color; m.name.Position = UDim2.fromOffset(cx, top - 3) end

	if sub then
		m.dist.Text = sub; m.dist.TextColor3 = Color3.fromRGB(235, 235, 235)
		m.dist.Visible = true; m.dist.Position = UDim2.fromOffset(cx, top + h + 2)
	else
		m.dist.Visible = false
	end

	if hpRatio then
		local barY = top + h + (sub and 18 or 3)
		m.hpBg.Visible = true; m.hpBg.Position = UDim2.fromOffset(left, barY); m.hpBg.Size = UDim2.fromOffset(w, 3)
		m.hpFill.Visible = true; m.hpFill.Position = UDim2.fromOffset(left, barY)
		m.hpFill.Size = UDim2.fromOffset(math.max(w * math.clamp(hpRatio, 0, 1), 0), 3)
		if hpRatio > 0.5 then m.hpFill.BackgroundColor3 = Color3.fromRGB(90,220,110)
		elseif hpRatio > 0.25 then m.hpFill.BackgroundColor3 = Color3.fromRGB(240,200,70)
		else m.hpFill.BackgroundColor3 = Color3.fromRGB(235,80,80) end
	else
		m.hpBg.Visible = false; m.hpFill.Visible = false
	end
end

local playerMarkers = {}
for i = 1, 30 do playerMarkers[i] = newBoxMarker() end

local function teamColorOf(p)
	local t = p.Team
	if t then
		local ok, c = pcall(function() return t.TeamColor.Color end)
		if ok and c then return c end
	end
	return Color3.fromRGB(200, 200, 200)
end

local function updatePlayerESP(cam, params)
	if not CFG.PlayerESP then
		for _, m in ipairs(playerMarkers) do hideMarker(m) end
		return
	end
	local perf = params.isPerf
	local maxMarkers = params.playerMax
	local maxDist = params.espDist

	local excludeList = CFG.ESPPlayerExcludeList or {}
	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myPos = myRoot and myRoot.Position or cam.CFrame.Position
	local myTeam = LP.Team
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			local skip = false
			if CFG.ESPOnlyBlacklist and not isBlacklisted(p) then skip = true end
			if not skip and matchAnyKeyword(p.Name, excludeList) then skip = true end
			if not skip then
				local hum = p.Character:FindFirstChildOfClass("Humanoid")
				local root = p.Character:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 then
					if not CFG.EnemyOnly or p.Team ~= myTeam then
						local d = (root.Position - myPos).Magnitude
						if d <= maxDist then list[#list + 1] = { p = p, hum = hum, root = root, d = d } end
					end
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)

	for i, m in ipairs(playerMarkers) do
		local e = (i <= maxMarkers) and list[i] or nil
		if not e then hideMarker(m) else
			local isEnemy = e.p.Team ~= myTeam
			local col = isEnemy and Color3.fromRGB(255, 90, 90) or teamColorOf(e.p)
			if isBlacklisted(e.p) then col = Color3.fromRGB(255, 60, 60) end
			local teamName = e.p.Team and e.p.Team.Name or "?"
			local title = string.format("<b>%s</b>\n<font size=\"10\">%s</font>", e.p.Name, teamName)
			local sub = perf and nil or string.format("%d 格", math.floor(e.d + 0.5))
			local hp = perf and nil or (e.hum.Health / math.max(e.hum.MaxHealth, 1))
			drawBox(m, cam, e.root.CFrame, Vector3.new(3, 5.2, 2), col, title, sub, hp, 14, 22, perf)
		end
	end
end

local itemMarkers = {}
for i = 1, 25 do itemMarkers[i] = newBoxMarker() end

local function makeItemEntry(inst, label, color)
	return { inst = inst, label = label, color = color }
end

local function collectItems()
	local list, seen = {}, {}
	local kws = CFG.ESPItemKeywordList or {}

	if type(kws) == "table" and #kws > 0 then
		local maxCustom, count = 80, 0
		for _, inst in ipairs(Workspace:GetDescendants()) do
			if count >= maxCustom then break end
			if inst:IsA("Model") and inst.Parent and not seen[inst] then
				local nm = inst.Name:lower()
				for _, k in ipairs(kws) do
					if nm:find(tostring(k):lower(), 1, true) then
						if isItemAllowed(inst.Name) then
							seen[inst] = true
							list[#list + 1] = makeItemEntry(inst, inst.Name, Color3.fromRGB(200, 200, 255))
							count = count + 1
						end
						break
					end
				end
			end
		end
		return list
	end

	if CFG.ESPShowPumpkins then
		for _, inst in ipairs(CollectionService:GetTagged("ScavengerHuntItem")) do
			if inst.Parent and not seen[inst] and isItemAllowed(inst.Name) then
				seen[inst] = true
				list[#list + 1] = makeItemEntry(inst, "南瓜", Color3.fromRGB(255, 150, 40))
			end
		end
	end
	if CFG.ESPShowPickups then
		for d in pairs(promptSet) do
			if d.Parent and d.Enabled then
				local a = (d.ActionText or ""):lower()
				if a:find("collect", 1, true) or a:find("pick up", 1, true) or a:find("grab", 1, true) or a:find("take", 1, true) then
					local model = d:FindFirstAncestorWhichIsA("Model")
					if model and not seen[model] and isItemAllowed(model.Name) then
						seen[model] = true
						list[#list + 1] = makeItemEntry(model, d.ObjectText or d.ActionText or "物品", Color3.fromRGB(110, 220, 140))
					end
				end
			end
		end
	end

	return list
end

local itemCache, lastItemScan = {}, 0
local function updateItemESP(cam, params)
	if not CFG.ItemESP then
		for _, m in ipairs(itemMarkers) do hideMarker(m) end
		return
	end
	local perf = params.isPerf
	local maxMarkers = params.itemMax
	local maxDist = params.itemDist
	local scanInterval = perf and 1.0 or 0.5
	if os.clock() - lastItemScan > scanInterval then
		lastItemScan = os.clock()
		itemCache = collectItems()
	end
	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myPos = myRoot and myRoot.Position or cam.CFrame.Position
	local list = {}
	for _, it in ipairs(itemCache) do
		local inst = it.inst
		if inst and inst.Parent then
			local ok, cf = pcall(function() return inst:GetBoundingBox() end)
			if ok and cf then
				local d = (cf.Position - myPos).Magnitude
				if d <= maxDist then
					list[#list + 1] = { cf = cf, d = d, label = it.label, color = it.color }
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for i, m in ipairs(itemMarkers) do
		local e = (i <= maxMarkers) and list[i] or nil
		if not e then hideMarker(m) else
			local sub = perf and nil or string.format("%d 格", math.floor(e.d + 0.5))
			drawBox(m, cam, e.cf, Vector3.new(2.5, 2.5, 2.5), e.color, e.label, sub, nil, 8, 8, perf)
		end
	end
end

local doorMarkers = {}
for i = 1, 15 do doorMarkers[i] = newBoxMarker() end
local doorRefs = {}
local lastDoorScan = 0

local function findDoorInstances()
	local kws = CFG.ESPDoorKeywordList or {}
	if type(kws) ~= "table" or #kws == 0 then kws = { "WindowedDoor" } end
	local list, seen = {}, {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and inst.Parent and not seen[inst] then
			local nm = inst.Name
			for _, k in ipairs(kws) do
				if tostring(k) ~= "" and nm:find(tostring(k), 1, true) then
					seen[inst] = true
					list[#list + 1] = inst
					break
				end
			end
		end
	end
	return list
end

local MAX_HIGHLIGHTS = 20

local function refreshDoorRefs()
	local instances = findDoorInstances()
	
	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myPos = myRoot and myRoot.Position or Vector3.new()

	local sortList = {}
	for _, door in ipairs(instances) do
		local cf, size = nil, nil
		pcall(function() cf, size = door:GetBoundingBox() end)
		if cf then
			local d = (cf.Position - myPos).Magnitude
			table.insert(sortList, {inst = door, cf = cf, size = size, d = d})
		end
	end
	
	table.sort(sortList, function(a, b) return a.d < b.d end)

	doorRefs = {}
	for i, data in ipairs(sortList) do
		local door = data.inst
		local used = false
		for _, x in ipairs(door:GetDescendants()) do
			if x:IsA("ProximityPrompt") then used = x.Enabled == false; break end
		end
		doorRefs[i] = { inst = door, cf = data.cf, size = data.size, used = used }
	end

	if not CFG.PerfMode then
		local keepSet = {}
		for i = 1, math.min(#sortList, MAX_HIGHLIGHTS) do
			local door = sortList[i].inst
			keepSet[door] = true
			local used = false
			for _, x in ipairs(door:GetDescendants()) do
				if x:IsA("ProximityPrompt") then used = x.Enabled == false; break end
			end
			local h = doorHighlights[door]
			if not h then
				h = Instance.new("Highlight")
				h.Name = "HubDoorHL"
				h.Adornee = door
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = WsFolder
				doorHighlights[door] = h
			end
			if used then
				h.FillColor = Color3.fromRGB(150, 150, 150)
				h.FillTransparency = 0.7
				h.OutlineColor = Color3.fromRGB(180, 180, 180)
			else
				h.FillColor = Color3.fromRGB(255, 145, 35)
				h.FillTransparency = 0.7
				h.OutlineColor = Color3.fromRGB(255, 205, 130)
			end
		end
		
		for door, h in pairs(doorHighlights) do
			if not keepSet[door] or not door.Parent then
				if h then h:Destroy() end
				doorHighlights[door] = nil
			end
		end
	end
end

local function updateDoorESP(cam, params)
	if not CFG.DoorESP then
		for _, m in ipairs(doorMarkers) do hideMarker(m) end
		for _, h in pairs(doorHighlights) do if h then h:Destroy() end end
		doorHighlights, doorRefs = {}, {}
		return
	end
	local perf = params.isPerf

	if perf then
		for door, h in pairs(doorHighlights) do
			if h then h:Destroy() end
			doorHighlights[door] = nil
		end
	end

	local scanInterval = perf and 5.0 or 2.0
	if os.clock() - lastDoorScan > scanInterval then
		lastDoorScan = os.clock()
		refreshDoorRefs()
	end
	local maxMarkers = params.doorMax

	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myPos = myRoot and myRoot.Position or cam.CFrame.Position
	local list = {}
	for _, data in ipairs(doorRefs) do
		if data.inst.Parent and data.cf and data.size then
			local d = (data.cf.Position - myPos).Magnitude
			list[#list + 1] = { cf = data.cf, size = data.size, d = d, used = data.used, name = data.inst.Name }
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for i, m in ipairs(doorMarkers) do
		local e = (i <= maxMarkers) and list[i] or nil
		if not e then hideMarker(m) else
			local sub = perf and nil or string.format("%d 格", math.floor(e.d + 0.5))
			drawBox(m, cam, e.cf, e.size, e.used and Color3.fromRGB(150,150,150) or Color3.fromRGB(255,145,35), e.used and (e.name .. "（已开启）") or e.name, sub, nil, 14, 20, perf)
		end
	end
end

local ListGui = Instance.new("ScreenGui")
ListGui.Name = "AsylumHubList"; ListGui.ResetOnSpawn = false; ListGui.IgnoreGuiInset = true; ListGui.DisplayOrder = 160000; ListGui.Parent = PlayerGui

local ListFrame = Instance.new("Frame", ListGui)
ListFrame.Name = "Panel"; ListFrame.Position = UDim2.new(1, -238, 0, 110); ListFrame.Size = UDim2.fromOffset(230, 520)
ListFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18); ListFrame.BackgroundTransparency = 0.18; ListFrame.BorderSizePixel = 0; ListFrame.Visible = false
Instance.new("UICorner", ListFrame).CornerRadius = UDim.new(0, 8)
local ListStroke = Instance.new("UIStroke", ListFrame)
ListStroke.Color = Color3.fromRGB(255, 145, 35); ListStroke.Thickness = 1; ListStroke.Transparency = 0.5; ListStroke.Parent = ListFrame

local ListTitle = Instance.new("TextLabel", ListFrame)
ListTitle.BackgroundTransparency = 1; ListTitle.Font = Enum.Font.GothamBold; ListTitle.TextSize = 13; ListTitle.TextColor3 = Color3.fromRGB(255, 190, 120)
ListTitle.Text = "玩家列表"; ListTitle.Size = UDim2.new(1, 0, 0, 24); ListTitle.Position = UDim2.fromOffset(0, 4)

local ListRows = {}
for i = 1, 36 do
	local r = Instance.new("TextLabel", ListFrame)
	r.BackgroundTransparency = 1; r.Font = Enum.Font.Gotham; r.TextSize = 12; r.TextColor3 = Color3.fromRGB(235, 235, 235)
	r.TextXAlignment = Enum.TextXAlignment.Left; r.RichText = true; r.Text = ""
	r.Size = UDim2.new(1, -12, 0, 13); r.Position = UDim2.fromOffset(6, 26 + (i - 1) * 13); r.Visible = false
	ListRows[i] = r
end

local listAccum = 0
local infoLabel = Instance.new("TextLabel", ListGui)
infoLabel.Name = "InfoHUD"; infoLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 14); infoLabel.BackgroundTransparency = 0.35
infoLabel.Font = Enum.Font.Code; infoLabel.TextSize = 13; infoLabel.TextColor3 = Color3.fromRGB(140, 255, 170)
infoLabel.TextXAlignment = Enum.TextXAlignment.Center; infoLabel.Position = UDim2.new(0.5, -160, 0, 4)
infoLabel.Size = UDim2.fromOffset(320, 22); infoLabel.Visible = false; infoLabel.Text = ""
Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0, 4)

local fpsAccum, fpsFrames = 0, 0
local globalFPS = 60
local infoAccum = 0
local function updateInfoHUD(dt, hrp)
	infoLabel.Visible = CFG.InfoHUD == true
	if not CFG.InfoHUD then return end
	infoAccum = infoAccum + dt
	if infoAccum < 0.5 then return end
	infoAccum = 0
	local ping = 0
	pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
	local pos = hrp and hrp.Position or Vector3.new()
	local perfTag = ""
	if useAdaptivePerf() and autoPerf.Level > 0 then perfTag = string.format("  [Perf Lv%d]", autoPerf.Level) end
	infoLabel.Text = string.format("FPS %d   PING %dms   POS %.0f, %.0f, %.0f%s", globalFPS, ping, pos.X, pos.Y, pos.Z, perfTag)
end

local function updatePlayerList(dt)
	ListFrame.Visible = CFG.PlayerList == true
	if not CFG.PlayerList then return end
	listAccum = listAccum + dt
	if listAccum < 0.5 then return end
	listAccum = 0

	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myPos = myRoot and myRoot.Position or Vector3.new()
	local myTeam = LP.Team
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local rr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local d = (rr and myRoot) and (rr.Position - myPos).Magnitude or 99999
		list[#list + 1] = { p = p, hum = hum, d = d }
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	ListTitle.Text = string.format("玩家列表  %d", #list)

	for i, row in ipairs(ListRows) do
		local e = list[i]
		if not e then row.Visible = false else
			local isEnemy = e.p.Team ~= myTeam
			local col = isEnemy and "#ff6060" or "#9ad0ff"
			local tag = ""
			if isBlacklisted(e.p) then tag = "<font color=\"#ff3030\">[黑]</font> "
			elseif isWhitelisted(e.p) then tag = "<font color=\"#5ac8ff\">[白]</font> " end
			local hp = e.hum and math.floor(e.hum.Health) or 0
			local teamName = e.p.Team and e.p.Team.Name or "?"
			row.Text = string.format('%s<font color="%s">●</font> %s <font size="10" color="#999">%s %dHP %d格</font>', tag, col, e.p.Name, teamName, hp, math.floor(e.d))
			row.Visible = true
		end
	end
end

local StatusGui = Instance.new("ScreenGui")
StatusGui.Name = "AsylumHubStatus"; StatusGui.ResetOnSpawn = false; StatusGui.IgnoreGuiInset = true; StatusGui.DisplayOrder = 155000; StatusGui.Parent = PlayerGui

local AuraStats = Instance.new("TextLabel", StatusGui)
AuraStats.BackgroundColor3 = Color3.fromRGB(30, 24, 16); AuraStats.BackgroundTransparency = 0.2
AuraStats.BorderSizePixel = 0; AuraStats.Font = Enum.Font.GothamSemibold; AuraStats.TextSize = 11
AuraStats.TextColor3 = Color3.fromRGB(255, 190, 120); AuraStats.TextXAlignment = Enum.TextXAlignment.Left
AuraStats.TextYAlignment = Enum.TextYAlignment.Center; AuraStats.Position = UDim2.new(0, 16, 1, -104)
AuraStats.Size = UDim2.fromOffset(300, 42); AuraStats.TextWrapped = true; AuraStats.Text = ""; AuraStats.Visible = false
Instance.new("UICorner", AuraStats).CornerRadius = UDim.new(0, 6)

local WeaponInfo = Instance.new("TextLabel", StatusGui)
WeaponInfo.BackgroundColor3 = Color3.fromRGB(24, 24, 30); WeaponInfo.BackgroundTransparency = 0.25
WeaponInfo.BorderSizePixel = 0; WeaponInfo.Font = Enum.Font.GothamSemibold; WeaponInfo.TextSize = 11
WeaponInfo.TextColor3 = Color3.fromRGB(190, 220, 255); WeaponInfo.TextXAlignment = Enum.TextXAlignment.Center
WeaponInfo.Position = UDim2.new(0, 16, 1, -56); WeaponInfo.Size = UDim2.fromOffset(300, 20)
WeaponInfo.Text = ""; WeaponInfo.Visible = false
Instance.new("UICorner", WeaponInfo).CornerRadius = UDim.new(0, 6)

--============================================================
-- 自动交互
--============================================================
local function registerPrompt(p) if p:IsA("ProximityPrompt") then promptSet[p] = true end end
for _, d in ipairs(Workspace:GetDescendants()) do registerPrompt(d) end
keep(Workspace.DescendantAdded:Connect(registerPrompt))

task.delay(2, function()
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and not promptSet[d] then
			promptSet[d] = true
		end
	end
end)

local SAFE_ACTIONS = { "collect", "pick up", "search", "take", "grab", "get" }
local BLOCK_ACTIONS = {
	"purchase", "steal", "restock", "deliver", "buy", "sell", "vote", "drop", "place",
	"delete", "destroy", "discard", "trade", "gift", "spend", "unlock", "attack", "kill", "harm",
}

local function isAllowedPrompt(p)
	if CFG.InteractAll then return true end
	local a = (p.ActionText or ""):lower()
	for _, b in ipairs(BLOCK_ACTIONS) do if a:find(b, 1, true) then return false end end
	if CFG.AutoOpenDoors and (a:find("open", 1, true) or a:find("knock", 1, true) or a:find("door", 1, true)) then return true end
	for _, s in ipairs(SAFE_ACTIONS) do if a:find(s, 1, true) then return true end end
	return false
end

local function promptPosition(p)
	local parent = p.Parent
	if parent and parent:IsA("Attachment") then return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then return parent.Position end
	return nil
end

local function updateAutoInteract()
	if not CFG.AutoInteract then return end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local now = os.clock()
	for p in pairs(promptSet) do
		if not p.Parent then
			promptSet[p] = nil; promptState[p] = nil
		elseif p.Enabled then
			local st = promptState[p]
			if st and st.idleUntil and now < st.idleUntil then
			elseif st and st.holding then
				if now - st.holdStart >= (p.HoldDuration + 0.05) then
					pcall(function() p:InputHoldEnd() end)
					promptState[p] = { idleUntil = now + 1.2 }
				end
			else
				local pos = promptPosition(p)
				if pos and (pos - root.Position).Magnitude <= p.MaxActivationDistance then
					if isAllowedPrompt(p) then
						local ok = pcall(function() p:InputHoldBegin() end)
						if ok then
							if p.HoldDuration <= 0 then
								pcall(function() p:InputHoldEnd() end)
								promptState[p] = { idleUntil = now + 1.2 }
							else
								promptState[p] = { holding = true, holdStart = now }
							end
						else
							promptState[p] = { idleUntil = now + 1 }
						end
					end
				end
			end
		end
	end
end

--============================================================
-- 主循环
--============================================================
local interactAccum, weaponAccum, fxAccum = 0, 0, 0
local noclipAccum = 0
local lootSearchAccum = 0
local cachedLootTarget = nil
local auraStatsAccum = 0
local faceAccum = 0
local cachedFaceTarget = nil
local cleanupAccum = 0

local function tick(dt)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local char0 = LP.Character
	local hum0 = char0 and char0:FindFirstChildOfClass("Humanoid")
	local hrp0 = char0 and char0:FindFirstChild("HumanoidRootPart")

	fpsAccum = fpsAccum + dt; fpsFrames = fpsFrames + 1
	if fpsAccum >= 0.5 then
		globalFPS = math.max(1, math.floor(fpsFrames / fpsAccum))
		fpsAccum, fpsFrames = 0, 0
	end

	updateAutoPerf(dt, globalFPS)
	local params = getPerfParams()

	cleanupAccum = cleanupAccum + dt
	if cleanupAccum > 3 then
		cleanupAccum = 0
		local now = os.clock()
		for hum, t in pairs(hitCooldowns) do
			if not hum.Parent or now - t > 3 then hitCooldowns[hum] = nil end
		end
		for i = #pendingHits, 1, -1 do
			local h = pendingHits[i]
			if now - h.t > 5 then table.remove(pendingHits, i) end
		end
	end

	if CFG.Fullbright then
		pcall(function()
			if Lighting.ClockTime ~= 14 then Lighting.ClockTime = 14 end
			if Lighting.Brightness ~= 1.5 then Lighting.Brightness = 1.5 end
			if Lighting.Ambient ~= Color3.fromRGB(100, 100, 110) then Lighting.Ambient = Color3.fromRGB(100, 100, 110) end
			if Lighting.OutdoorAmbient ~= Color3.fromRGB(100, 100, 110) then Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 110) end
			if Lighting.EnvironmentDiffuseScale ~= 1 then Lighting.EnvironmentDiffuseScale = 1 end
			if Lighting.EnvironmentSpecularScale ~= 1 then Lighting.EnvironmentSpecularScale = 1 end
			if Lighting.GlobalShadows then Lighting.GlobalShadows = false end
		end)
	end

	if hum0 and hrp0 then
		pcall(applySpeed, dt, hum0, hrp0)
	end

	local needNoclip = CFG.Noclip or hubMoveTarget ~= nil
	if char0 then
		noclipAccum = noclipAccum + dt
		if noclipAccum >= 0.1 then
			noclipAccum = 0
			setCharCollide(char0, not needNoclip)
		end
	end

	if CFG.Fly and hrp0 and hum0 then
		local dir = Vector3.zero
		local cf = cam.CFrame
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
		
		if dir.Magnitude > 0 then
			local targetVel = dir.Unit * CFG.FlySpeed
			if (hrp0.AssemblyLinearVelocity - targetVel).Magnitude > 2 then
				hrp0.AssemblyLinearVelocity = targetVel
			end
		else
			if hrp0.AssemblyLinearVelocity.Magnitude > 2 then
				hrp0.AssemblyLinearVelocity = Vector3.zero
			end
		end
		if hum0:GetState() ~= Enum.HumanoidStateType.Physics then
			hum0:ChangeState(Enum.HumanoidStateType.Physics)
		end
	elseif not CFG.Fly and not hubMoveTarget and hum0 and hum0:GetState() == Enum.HumanoidStateType.Physics then
		hum0:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	if CFG.Freecam then
		if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
		local delta = UserInputService:GetMouseDelta()
		if delta.Magnitude > 0 then freecamCF = freecamCF * CFrame.Angles(0, -math.rad(delta.X * 0.35), 0) * CFrame.Angles(-math.rad(delta.Y * 0.35), 0, 0) end
		local mv = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + freecamCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - freecamCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + freecamCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - freecamCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0, 1, 0) end
		if mv.Magnitude > 0 then freecamCF = freecamCF + mv.Unit * 40 * math.min(dt, 0.05) end
		cam.CFrame = freecamCF
	end

	if CFG.AutoGetUp and hum0 and hum0.PlatformStand then pcall(function() hum0.PlatformStand = false end) end
	if CFG.CustomFOV and math.abs(cam.FieldOfView - CFG.FOV) > 0.1 then cam.FieldOfView = CFG.FOV end

	local moveGoal = nil
	if CFG.AutoWalkDoor and hum0 and hrp0 then
		for _, data in ipairs(doorRefs) do
			if data.inst.Parent and data.cf and not data.used then
				local dp = data.cf.Position
				if (dp - hrp0.Position).Magnitude > 4 then moveGoal = dp end
				break
			end
		end
	end
	if not moveGoal and CFG.AutoWalkLoot and hum0 and hrp0 then
		lootSearchAccum = lootSearchAccum + dt
		if lootSearchAccum >= 0.5 then
			lootSearchAccum = 0
			local best, bd
			for _, it in ipairs(itemCache) do
				if it.inst and it.inst.Parent then
					local ok, cf2 = pcall(function() return it.inst:GetBoundingBox() end)
					if ok and cf2 then
						local d = (cf2.Position - hrp0.Position).Magnitude
						if d > 3.5 and (not bd or d < bd) then best = cf2.Position; bd = d end
					end
				end
			end
			cachedLootTarget = best
		end
		if cachedLootTarget then moveGoal = cachedLootTarget end
	end

	if moveGoal and hrp0 and hum0 then requestMove(moveGoal) end

	if hubMoveTarget and hrp0 and hum0 then
		if os.clock() > hubMoveEndTime then
			hubMoveTarget = nil
			if hrp0.AssemblyLinearVelocity.Magnitude > 2 then hrp0.AssemblyLinearVelocity = Vector3.zero end
		else
			local delta = hubMoveTarget - hrp0.Position
			local dist = delta.Magnitude
			if dist < 2.5 then
				hubMoveTarget = nil
				if hrp0.AssemblyLinearVelocity.Magnitude > 2 then hrp0.AssemblyLinearVelocity = Vector3.zero end
			else
				local speed = math.max(CFG.FlySpeed or 36, 25)
				local targetVel = delta.Unit * speed
				if (hrp0.AssemblyLinearVelocity - targetVel).Magnitude > 2 then
					hrp0.AssemblyLinearVelocity = targetVel
				end
				if hum0:GetState() ~= Enum.HumanoidStateType.Physics then
					hum0:ChangeState(Enum.HumanoidStateType.Physics)
				end
			end
		end
	end

	if WeaponInfo then
		weaponAccum = weaponAccum + dt
		if weaponAccum > 0.25 then
			weaponAccum = 0
			local t = char0 and char0:FindFirstChildOfClass("Tool")
			if t and isWeaponTool(t) then
				WeaponInfo.Visible = true
				WeaponInfo.Text = string.format("%s  伤害 %s  范围 %s  冷却 %s  速度 %s", t.Name, tostring(t:GetAttribute("BaseDamage") or "?"), tostring(t:GetAttribute("Range") or "?"), tostring(t:GetAttribute("CooldownTime") or "?"), tostring(t:GetAttribute("Speed") or "?"))
			else
				WeaponInfo.Visible = false
			end
		end
	end

	if CFG.KillAura then pcall(doKillAura) else pcall(doAutoAttack) end
	pcall(doAutoShoot, cam)

	if CFG.AutoFace then
		local tool = char0 and char0:FindFirstChildOfClass("Tool")
		if tool and isWeaponTool(tool) then
			faceAccum = faceAccum + dt
			if faceAccum >= 0.1 then
				faceAccum = 0
				cachedFaceTarget = getTarget(CFG.MaxTargetDistance * 1.5)
				if not cachedFaceTarget and CFG.KillAura then
					local range = CFG.AuraCustomRange and CFG.AuraRadius or (tonumber(tool:GetAttribute("Range")) or 10)
					local targets = collectTargets(math.min(CFG.AuraRadius, range), 1)
					if targets[1] then cachedFaceTarget = targets[1] end
				end
			end
			if cachedFaceTarget and hrp0 and cachedFaceTarget.root and cachedFaceTarget.root.Parent then
				local tp = cachedFaceTarget.root.Position
				local look = Vector3.new(tp.X, hrp0.Position.Y, tp.Z)
				if (look - hrp0.Position).Magnitude > 0.1 then
					hrp0.CFrame = CFrame.lookAt(hrp0.Position, look)
				end
			end
		end
	end

	if CFG.KillAura and CFG.Adaptive and not CFG.MultiTargetAttack and not CFG.UseWeaponSpeed and os.clock() - lastAdapt > 6 then
		lastAdapt = os.clock()
		local dSent = auraSent - snapSent
		local dEff = auraEffective - snapEff
		snapSent, snapEff = auraSent, auraEffective
		if dSent >= 4 then
			local ratio = dEff / dSent
			if ratio < 0.45 then CFG.AuraIntervalMul = math.min(CFG.AuraIntervalMul * 1.35, 6)
			elseif ratio > 0.85 then CFG.AuraIntervalMul = math.max(CFG.AuraIntervalMul * 0.92, 1) end
		end
	end

	if AuraStats then
		if CFG.KillAura then
			auraStatsAccum = auraStatsAccum + dt
			if auraStatsAccum >= 0.1 then
				auraStatsAccum = 0
				AuraStats.Visible = true
				local total = auraSent
				local rate = total > 0 and (auraEffective / total * 100) or 0
				local modeText
				if not CFG.AuraDirect then
					modeText = "⚠ 直伤关闭"
				elseif CFG.UseWeaponSpeed then
					modeText = "原始攻速"
				elseif CFG.MultiTargetAttack then
					modeText = "多目标轮转"
				elseif CFG.Adaptive then
					modeText = "自适应 x" .. string.format("%.2f", CFG.AuraIntervalMul)
				else
					modeText = "固定 " .. string.format("%.2fs", CFG.AttackCooldown)
				end
				AuraStats.Text = string.format("光环  有效 %d / 发送 %d (%.0f%%)  间隔 %s\n%s", auraEffective, total, rate, modeText, auraStatus)
			end
		else
			AuraStats.Visible = false
		end
	end

	if CFG.ReachBoost then
		local ch = LP.Character
		local t = ch and ch:FindFirstChildOfClass("Tool")
		if t and isWeaponTool(t) and not reachApplied[t] then pcall(Handlers.ReachBoost, true) end
	end

	pcall(updatePlayerESP, cam, params)
	pcall(updateItemESP, cam, params)
	pcall(updateDoorESP, cam, params)

	pcall(updatePlayerList, dt)
	pcall(updateInfoHUD, dt, hrp0)
	pcall(updateAuraRing, params)

	interactAccum = interactAccum + dt
	if interactAccum >= CFG.InteractInterval then
		interactAccum = 0
		pcall(updateAutoInteract)
	end

	fxAccum = fxAccum + dt
	if fxAccum > 2 then
		fxAccum = 0
		if CFG.NoScreenFX then pcall(applyNoFX, true) end
		if CFG.HideGameUI then pcall(applyHideUI, true) end
	end
end

shared.__HubRender = "Hub_MainTick"
RunService:BindToRenderStep(shared.__HubRender, Enum.RenderPriority.Camera.Value + 2, tick)

--============================================================
-- 快捷键
--============================================================
local KEYMAP = {
	[Enum.KeyCode.X] = "KillAura", [Enum.KeyCode.F] = "AutoAttack", [Enum.KeyCode.V] = "PlayerESP",
	[Enum.KeyCode.B] = "ItemESP", [Enum.KeyCode.J] = "DoorESP", [Enum.KeyCode.G] = "AutoInteract",
	[Enum.KeyCode.K] = "InfiniteStamina", [Enum.KeyCode.L] = "Fullbright",
}

keep(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local key = KEYMAP[input.KeyCode]
	if key then
		CFG[key] = not CFG[key]
		if UIToggles[key] then pcall(UIToggles[key], CFG[key], true, true) end
		if Handlers[key] then pcall(Handlers[key], CFG[key]) end
	end
end))

keep(UserInputService.JumpRequest:Connect(function()
	if CFG.InfiniteJump then
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end))

--============================================================
-- Link UI V2
--============================================================
local success, err = pcall(function()
	local function safeDestroy(instance) if instance and instance.Parent then instance:Destroy() end end

	local player = Players.LocalPlayer
	if not player then
		pcall(function() player = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end)
		player = player or Players.LocalPlayer
	end

	if CoreGui:FindFirstChild("LinkCcUI") then safeDestroy(CoreGui.LinkCcUI) end

	local DynamicContext = {
		ActiveToggles = {}, ActiveSliders = {}, TextElements = {}, BorderElements = {},
		CurrentTab = nil, IsSubCardActive = true, GlobalAudio = nil, CurrentVolume = 2,
		BgPhase = math.random() * 100, StrokeRotation = 0,
		CurrentPresetName = "Bubblegum",
	}

	local PalettePresets = {
		["Bubblegum"] = { Primary = Color3.fromRGB(255, 242, 248), Secondary = Color3.fromRGB(248, 240, 255), Accent = Color3.fromRGB(240, 250, 255), LogoAccent = Color3.fromRGB(255, 70, 135), ActiveColor = Color3.fromRGB(255, 90, 155), TextColor = Color3.fromRGB(35, 25, 40), SubTextColor = Color3.fromRGB(120, 100, 130), BorderColor = Color3.fromRGB(255, 215, 235) },
		["Dark Pastel"] = { Primary = Color3.fromRGB(235, 230, 248), Secondary = Color3.fromRGB(225, 235, 255), Accent = Color3.fromRGB(242, 235, 250), LogoAccent = Color3.fromRGB(135, 90, 210), ActiveColor = Color3.fromRGB(145, 100, 225), TextColor = Color3.fromRGB(30, 25, 45), SubTextColor = Color3.fromRGB(110, 105, 130), BorderColor = Color3.fromRGB(215, 205, 240) },
		["Ocean Mist"] = { Primary = Color3.fromRGB(230, 250, 255), Secondary = Color3.fromRGB(238, 255, 253), Accent = Color3.fromRGB(240, 248, 255), LogoAccent = Color3.fromRGB(10, 150, 245), ActiveColor = Color3.fromRGB(20, 170, 255), TextColor = Color3.fromRGB(20, 40, 55), SubTextColor = Color3.fromRGB(90, 115, 135), BorderColor = Color3.fromRGB(195, 238, 255) },
		["Sunset Glow"] = { Primary = Color3.fromRGB(255, 240, 235), Secondary = Color3.fromRGB(255, 248, 228), Accent = Color3.fromRGB(255, 240, 250), LogoAccent = Color3.fromRGB(255, 85, 65), ActiveColor = Color3.fromRGB(255, 105, 85), TextColor = Color3.fromRGB(45, 25, 25), SubTextColor = Color3.fromRGB(135, 100, 100), BorderColor = Color3.fromRGB(255, 212, 200) },
		["Mint Fresh"] = { Primary = Color3.fromRGB(235, 255, 245), Secondary = Color3.fromRGB(240, 255, 250), Accent = Color3.fromRGB(245, 255, 248), LogoAccent = Color3.fromRGB(15, 195, 130), ActiveColor = Color3.fromRGB(25, 215, 140), TextColor = Color3.fromRGB(20, 45, 30), SubTextColor = Color3.fromRGB(90, 125, 100), BorderColor = Color3.fromRGB(205, 250, 225) },
		["Lavender Dream"] = { Primary = Color3.fromRGB(242, 235, 255), Secondary = Color3.fromRGB(232, 225, 250), Accent = Color3.fromRGB(250, 240, 255), LogoAccent = Color3.fromRGB(170, 105, 255), ActiveColor = Color3.fromRGB(185, 120, 255), TextColor = Color3.fromRGB(45, 30, 65), SubTextColor = Color3.fromRGB(125, 105, 150), BorderColor = Color3.fromRGB(220, 200, 250) },
		["Cherry Red"] = { Primary = Color3.fromRGB(255, 235, 238), Secondary = Color3.fromRGB(255, 225, 230), Accent = Color3.fromRGB(255, 242, 245), LogoAccent = Color3.fromRGB(225, 35, 75), ActiveColor = Color3.fromRGB(240, 55, 90), TextColor = Color3.fromRGB(65, 20, 30), SubTextColor = Color3.fromRGB(145, 90, 105), BorderColor = Color3.fromRGB(250, 190, 200) },
		["Cyber Blue"] = { Primary = Color3.fromRGB(225, 245, 255), Secondary = Color3.fromRGB(220, 235, 255), Accent = Color3.fromRGB(235, 250, 255), LogoAccent = Color3.fromRGB(0, 145, 255), ActiveColor = Color3.fromRGB(0, 175, 255), TextColor = Color3.fromRGB(15, 35, 65), SubTextColor = Color3.fromRGB(80, 115, 155), BorderColor = Color3.fromRGB(170, 220, 255) },
		["Golden Cream"] = { Primary = Color3.fromRGB(255, 248, 225), Secondary = Color3.fromRGB(255, 240, 205), Accent = Color3.fromRGB(255, 252, 235), LogoAccent = Color3.fromRGB(235, 165, 25), ActiveColor = Color3.fromRGB(245, 180, 35), TextColor = Color3.fromRGB(60, 45, 20), SubTextColor = Color3.fromRGB(145, 120, 75), BorderColor = Color3.fromRGB(245, 215, 145) },
		["Forest Calm"] = { Primary = Color3.fromRGB(230, 250, 235), Secondary = Color3.fromRGB(220, 245, 225), Accent = Color3.fromRGB(240, 255, 242), LogoAccent = Color3.fromRGB(35, 155, 80), ActiveColor = Color3.fromRGB(40, 180, 90), TextColor = Color3.fromRGB(20, 55, 30), SubTextColor = Color3.fromRGB(85, 125, 95), BorderColor = Color3.fromRGB(175, 230, 185) },
		["Rose Gold"] = { Primary = Color3.fromRGB(255, 238, 235), Secondary = Color3.fromRGB(250, 225, 220), Accent = Color3.fromRGB(255, 245, 242), LogoAccent = Color3.fromRGB(205, 105, 115), ActiveColor = Color3.fromRGB(225, 125, 135), TextColor = Color3.fromRGB(65, 30, 35), SubTextColor = Color3.fromRGB(145, 100, 105), BorderColor = Color3.fromRGB(240, 195, 190) }
	}
	local PaletteNames = { "Bubblegum", "Dark Pastel", "Ocean Mist", "Sunset Glow", "Mint Fresh", "Lavender Dream", "Cherry Red", "Cyber Blue", "Golden Cream", "Forest Calm", "Rose Gold" }

	local function GeneratePalette(preset)
		local p, s, a, white = preset.Primary, preset.Secondary, preset.Accent, Color3.fromRGB(255, 255, 255)
		return { p:Lerp(white, 0.2), p:Lerp(s, 0.15), s:Lerp(white, 0.25), s:Lerp(a, 0.2), a:Lerp(white, 0.2) }
	end

	local function ApplyPalette(selected)
		local p = PalettePresets[selected]; if not p then return end
		DynamicContext.CurrentPreset = p
		DynamicContext.CurrentPresetName = selected
		DynamicContext.TargetPalette = GeneratePalette(p)
		DynamicContext.TargetLogoColor = p.LogoAccent; DynamicContext.TargetActiveColor = p.ActiveColor
		DynamicContext.TargetTextColor = p.TextColor; DynamicContext.TargetSubTextColor = p.SubTextColor; DynamicContext.TargetBorderColor = p.BorderColor
	end

	local function getCurrentPaletteIndex()
		for i, name in ipairs(PaletteNames) do
			if name == DynamicContext.CurrentPresetName then return i end
		end
		return 1
	end

	local defaultPreset = PalettePresets["Bubblegum"]
	DynamicContext.CurrentPreset = defaultPreset
	DynamicContext.CurrentPalette = GeneratePalette(defaultPreset); DynamicContext.TargetPalette = DynamicContext.CurrentPalette
	DynamicContext.CurrentLogoColor = defaultPreset.LogoAccent; DynamicContext.TargetLogoColor = DynamicContext.CurrentLogoColor
	DynamicContext.CurrentActiveColor = defaultPreset.ActiveColor; DynamicContext.TargetActiveColor = DynamicContext.CurrentActiveColor
	DynamicContext.CurrentTextColor = defaultPreset.TextColor; DynamicContext.TargetTextColor = DynamicContext.CurrentTextColor
	DynamicContext.CurrentSubTextColor = defaultPreset.SubTextColor; DynamicContext.TargetSubTextColor = DynamicContext.CurrentSubTextColor
	DynamicContext.CurrentBorderColor = defaultPreset.BorderColor; DynamicContext.TargetBorderColor = DynamicContext.CurrentBorderColor

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "LinkCcUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 999999
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ScreenGui.IgnoreGuiInset = true
	pcall(function() ScreenGui.Parent = CoreGui end)
	if not ScreenGui.Parent then ScreenGui.Parent = player:WaitForChild("PlayerGui") end

	local function MakeDraggable(dragHandle, targetFrame)
		local dragging, dragInput, dragStart, startPos
		dragHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true; dragStart = Vector2.new(input.Position.X, input.Position.Y); startPos = targetFrame.Position
				local conn
				conn = UserInputService.InputEnded:Connect(function(endInput)
					if endInput.UserInputType == input.UserInputType then dragging = false; if conn then conn:Disconnect() end end
				end)
			end
		end)
		dragHandle.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
		end)
		keep(UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
				targetFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end))
	end

	local MainFrame = Instance.new("CanvasGroup")
	MainFrame.Name = "MainFrame"; MainFrame.Size = UDim2.new(0, 530, 0, 320); MainFrame.AnchorPoint = Vector2.new(0.5, 0.5); MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255); MainFrame.BorderSizePixel = 0; MainFrame.ClipsDescendants = true
	MainFrame.GroupTransparency = 1; MainFrame.ZIndex = 10; MainFrame.Parent = ScreenGui
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

	local uiScale = Instance.new("UIScale", MainFrame)
	uiScale.Scale = CFG.UIScale / 100

	local MainStroke = Instance.new("UIStroke", MainFrame)
	MainStroke.Thickness = 2; MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; MainStroke.Color = Color3.fromRGB(255, 255, 255)

	local StrokeGradient = Instance.new("UIGradient", MainStroke)
	StrokeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(210, 210, 210)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(210, 210, 210)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 255, 255))
	})
	local MainGradient = Instance.new("UIGradient", MainFrame)

	local TopBar = Instance.new("Frame", MainFrame)
	TopBar.Name = "TopBar"; TopBar.Size = UDim2.new(1, 0, 0, 42); TopBar.BackgroundTransparency = 1; TopBar.Active = true; TopBar.ZIndex = 11

	local LogoBtn = Instance.new("TextButton", TopBar)
	LogoBtn.Size = UDim2.new(0, 140, 1, 0); LogoBtn.Position = UDim2.new(0.5, -70, 0, 0); LogoBtn.Font = Enum.Font.FredokaOne
	LogoBtn.Text = "Link.cc"; LogoBtn.TextColor3 = DynamicContext.CurrentLogoColor; LogoBtn.TextSize = 22; LogoBtn.BackgroundTransparency = 1; LogoBtn.ZIndex = 12

	local StatusDot = Instance.new("Frame", TopBar)
	StatusDot.Size = UDim2.new(0, 6, 0, 6); StatusDot.Position = UDim2.new(1, -85, 0.5, -3); StatusDot.BackgroundColor3 = Color3.fromRGB(60, 210, 100); StatusDot.ZIndex = 12
	Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

	local StatusText = Instance.new("TextLabel", TopBar)
	StatusText.Size = UDim2.new(0, 70, 1, 0); StatusText.Position = UDim2.new(1, -75, 0, 0); StatusText.Font = Enum.Font.GothamMedium
	StatusText.Text = "v3.3 Active"; StatusText.TextColor3 = DynamicContext.CurrentSubTextColor; StatusText.TextSize = 11
	StatusText.TextXAlignment = Enum.TextXAlignment.Left; StatusText.BackgroundTransparency = 1; StatusText.ZIndex = 12
	table.insert(DynamicContext.TextElements, {Obj = StatusText, Type = "Sub"})

	MakeDraggable(TopBar, MainFrame)

	local ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Name = "ContentArea"; ContentArea.Size = UDim2.new(1, -24, 1, -54); ContentArea.Position = UDim2.new(0, 12, 0, 42)
	ContentArea.BackgroundTransparency = 1; ContentArea.ZIndex = 11

	local NavCard = Instance.new("Frame", ContentArea)
	NavCard.Name = "NavCard"; NavCard.Size = UDim2.new(0, 116, 1, 0); NavCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	NavCard.BackgroundTransparency = 0.15; NavCard.ZIndex = 12
	Instance.new("UICorner", NavCard).CornerRadius = UDim.new(0, 12)
	local NavStroke = Instance.new("UIStroke", NavCard)
	NavStroke.Thickness = 1; NavStroke.Transparency = 0.2; NavStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, NavStroke)

	local MainConfigCard = Instance.new("CanvasGroup", ContentArea)
	MainConfigCard.Name = "MainConfigCard"; MainConfigCard.Position = UDim2.new(0, 124, 0, 0); MainConfigCard.Size = UDim2.new(0, 232, 1, 0)
	MainConfigCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255); MainConfigCard.BackgroundTransparency = 0.15; MainConfigCard.ClipsDescendants = true; MainConfigCard.ZIndex = 12
	MainConfigCard.GroupTransparency = 0
	Instance.new("UICorner", MainConfigCard).CornerRadius = UDim.new(0, 12)
	local MainConfigStroke = Instance.new("UIStroke", MainConfigCard)
	MainConfigStroke.Thickness = 1; MainConfigStroke.Transparency = 0.2; MainConfigStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, MainConfigStroke)

	local SubMaskContainer = Instance.new("Frame", ContentArea)
	SubMaskContainer.Name = "SubMaskContainer"; SubMaskContainer.Size = UDim2.new(0, 134, 1, 0); SubMaskContainer.Position = UDim2.new(0, 364, 0, 0)
	SubMaskContainer.BackgroundTransparency = 1; SubMaskContainer.ZIndex = 12

	local SubConfigCard = Instance.new("CanvasGroup", SubMaskContainer)
	SubConfigCard.Name = "SubConfigCard"; SubConfigCard.Size = UDim2.new(1, 0, 1, 0); SubConfigCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	SubConfigCard.BackgroundTransparency = 0.15; SubConfigCard.ClipsDescendants = true; SubConfigCard.ZIndex = 12
	SubConfigCard.GroupTransparency = 0
	Instance.new("UICorner", SubConfigCard).CornerRadius = UDim.new(0, 12)
	local SubConfigStroke = Instance.new("UIStroke", SubConfigCard)
	SubConfigStroke.Thickness = 1; SubConfigStroke.Transparency = 0.2; SubConfigStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, SubConfigStroke)

	task.spawn(function()
		MainFrame.Size = UDim2.new(0, 500, 0, 300); MainFrame.GroupTransparency = 1
		TweenService:Create(MainFrame, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 530, 0, 320), GroupTransparency = 0
		}):Play()
	end)

	local SIZE_MAIN_NORMAL = UDim2.new(0, 232, 1, 0)
	local SIZE_MAIN_EXPAND = UDim2.new(0, 374, 1, 0)

	local function AdjustLayoutMode(showSubCard)
		if DynamicContext.IsSubCardActive == showSubCard then return end
		DynamicContext.IsSubCardActive = showSubCard
		local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		if showSubCard then
			SubMaskContainer.Visible = true; SubConfigCard.Visible = true
			TweenService:Create(MainConfigCard, tweenInfo, {Size = SIZE_MAIN_NORMAL}):Play()
			TweenService:Create(SubConfigCard, tweenInfo, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.15}):Play()
			TweenService:Create(SubConfigStroke, tweenInfo, {Transparency = 0.2}):Play()
		else
			TweenService:Create(MainConfigCard, tweenInfo, {Size = SIZE_MAIN_EXPAND}):Play()
			local subTween = TweenService:Create(SubConfigCard, tweenInfo, {Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1})
			TweenService:Create(SubConfigStroke, tweenInfo, {Transparency = 1}):Play()
			subTween:Play()
			subTween.Completed:Connect(function()
				if not DynamicContext.IsSubCardActive then SubMaskContainer.Visible = false; SubConfigCard.Visible = false end
			end)
		end
	end

	local function CreateScrollList(parent, topOffset)
		topOffset = topOffset or 68
		local Scroll = Instance.new("ScrollingFrame", parent)
		Scroll.Size = UDim2.new(1, 0, 1, -topOffset); Scroll.Position = UDim2.new(0, 0, 0, topOffset)
		Scroll.BackgroundTransparency = 1; Scroll.BorderSizePixel = 0; Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.ScrollBarThickness = 3
		Scroll.ScrollBarImageColor3 = Color3.fromRGB(150, 160, 180); Scroll.ScrollBarImageTransparency = 0.5; Scroll.ZIndex = 13

		local List = Instance.new("UIListLayout", Scroll)
		List.Padding = UDim.new(0, 8); List.HorizontalAlignment = Enum.HorizontalAlignment.Center; List.SortOrder = Enum.SortOrder.LayoutOrder
		local UIPadding = Instance.new("UIPadding", Scroll)
		UIPadding.PaddingTop = UDim.new(0, 4); UIPadding.PaddingBottom = UDim.new(0, 12)

		local function updateScrollState()
			if List.AbsoluteContentSize.Y > Scroll.AbsoluteSize.Y then
				Scroll.ScrollingEnabled = true; Scroll.ScrollBarImageTransparency = 0.5
			else
				Scroll.ScrollingEnabled = false; Scroll.ScrollBarImageTransparency = 1
			end
		end
		List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScrollState)
		Scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScrollState)
		return Scroll
	end

	local function ClearContainer(container)
		if not container then return end
		for _, child in ipairs(container:GetChildren()) do
			if not child:IsA("UICorner") and not child:IsA("UIStroke") then safeDestroy(child) end
		end
	end

	local function AddButton(parent, title, subText, callback)
		local Frame = Instance.new("Frame", parent)
		Frame.Size = UDim2.new(1, -12, 0, 38); Frame.BackgroundTransparency = 1; Frame.ZIndex = 14

		local Btn = Instance.new("TextButton", Frame)
		Btn.Size = UDim2.new(1, 0, 1, 0); Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Btn.BackgroundTransparency = 0.6; Btn.Text = ""; Btn.ZIndex = 14
		Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)

		local BtnStroke = Instance.new("UIStroke", Btn)
		BtnStroke.Thickness = 1; BtnStroke.Transparency = 0.5; BtnStroke.Color = DynamicContext.CurrentBorderColor
		table.insert(DynamicContext.BorderElements, BtnStroke)

		local Label = Instance.new("TextLabel", Btn)
		Label.Size = UDim2.new(1, -16, 0, 18); Label.Position = UDim2.new(0, 10, 0, 2); Label.Text = title
		Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left; Label.BackgroundTransparency = 1; Label.ZIndex = 15
		table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})

		if subText then
			local SubLabel = Instance.new("TextLabel", Btn)
			SubLabel.Size = UDim2.new(1, -16, 0, 12); SubLabel.Position = UDim2.new(0, 10, 0, 20); SubLabel.Text = subText
			SubLabel.Font = Enum.Font.Gotham; SubLabel.TextColor3 = DynamicContext.CurrentSubTextColor; SubLabel.TextSize = 8
			SubLabel.TextXAlignment = Enum.TextXAlignment.Left; SubLabel.BackgroundTransparency = 1; SubLabel.ZIndex = 15
			table.insert(DynamicContext.TextElements, {Obj = SubLabel, Type = "Sub"})
		end

		Btn.MouseButton1Click:Connect(function() if callback then pcall(callback) end end)
		return Frame
	end

	local function AddToggle(parent, title, subText, default, callback, cfgKey)
		local Frame = Instance.new("Frame", parent)
		Frame.Size = UDim2.new(1, -12, 0, 38); Frame.BackgroundTransparency = 1; Frame.ZIndex = 14

		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(0.6, 0, 0, 18); Label.Position = UDim2.new(0, 0, 0, 2); Label.Text = title
		Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left; Label.TextTruncate = Enum.TextTruncate.AtEnd; Label.BackgroundTransparency = 1; Label.ZIndex = 14
		table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})

		if subText then
			local SubLabel = Instance.new("TextLabel", Frame)
			SubLabel.Size = UDim2.new(1, -45, 0, 12); SubLabel.Position = UDim2.new(0, 0, 0, 20); SubLabel.Text = subText
			SubLabel.Font = Enum.Font.Gotham; SubLabel.TextColor3 = DynamicContext.CurrentSubTextColor; SubLabel.TextSize = 8
			SubLabel.TextXAlignment = Enum.TextXAlignment.Left; SubLabel.TextTruncate = Enum.TextTruncate.AtEnd; SubLabel.BackgroundTransparency = 1; SubLabel.ZIndex = 14
			table.insert(DynamicContext.TextElements, {Obj = SubLabel, Type = "Sub"})
		end

		local Track = Instance.new("TextButton", Frame)
		Track.Size = UDim2.new(0, 36, 0, 18); Track.Position = UDim2.new(1, -38, 0.5, -9)
		Track.BackgroundColor3 = Color3.fromRGB(200, 205, 215); Track.Text = ""; Track.AutoButtonColor = false; Track.ZIndex = 15
		Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

		local Knob = Instance.new("Frame", Track)
		Knob.Size = UDim2.new(0, 14, 0, 14); Knob.AnchorPoint = Vector2.new(0, 0.5); Knob.Position = UDim2.new(0, 2, 0.5, 0)
		Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Knob.ZIndex = 16
		Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

		local toggled = default or false
		local function setToggleState(state, animate, silent)
			toggled = state
			local targetColor = toggled and DynamicContext.CurrentActiveColor or Color3.fromRGB(205, 210, 220)
			local targetPos = toggled and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
			if animate then
				TweenService:Create(Track, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
				TweenService:Create(Knob, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPos}):Play()
			else
				Track.BackgroundColor3 = targetColor; Knob.Position = targetPos
			end
			if callback and not silent then pcall(callback, toggled) end
		end

		Track.MouseButton1Click:Connect(function() setToggleState(not toggled, true) end)
		setToggleState(toggled, false)

		if cfgKey then
			UIToggles[cfgKey] = setToggleState
			DynamicContext.ActiveToggles[cfgKey] = { Update = function()
				if toggled and Track.Parent then
					if not colorNearlyEqual(Track.BackgroundColor3, DynamicContext.CurrentActiveColor, 0.03) then
						Track.BackgroundColor3 = DynamicContext.CurrentActiveColor
					end
				end
			end }
		end
		return Frame
	end

	local function AddSlider(parent, title, min, max, default, unit, callback, cfgKey, precision)
		precision = precision or 0
		local function snapVal(v)
			if precision == 0 then return math.floor(v + 0.5) end
			local mul = 10 ^ precision
			return math.floor(v * mul + 0.5) / mul
		end
		local function fmtVal(v)
			if precision == 0 then return tostring(math.floor(v + 0.5)) end
			return string.format("%." .. precision .. "f", v)
		end

		local Frame = Instance.new("Frame", parent)
		Frame.Size = UDim2.new(1, -12, 0, 38); Frame.BackgroundTransparency = 1; Frame.ZIndex = 14

		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(0.5, 0, 0, 16); Label.Position = UDim2.new(0, 0, 0, 0); Label.Text = title
		Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left; Label.TextTruncate = Enum.TextTruncate.AtEnd; Label.BackgroundTransparency = 1; Label.ZIndex = 14
		table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})

		local ValLabel = Instance.new("TextLabel", Frame)
		ValLabel.Size = UDim2.new(0.5, 0, 0, 16); ValLabel.Position = UDim2.new(0.5, 0, 0, 0); ValLabel.Text = fmtVal(default) .. (unit or "")
		ValLabel.Font = Enum.Font.Gotham; ValLabel.TextColor3 = DynamicContext.CurrentSubTextColor; ValLabel.TextSize = 10
		ValLabel.TextXAlignment = Enum.TextXAlignment.Right; ValLabel.BackgroundTransparency = 1; ValLabel.ZIndex = 14
		table.insert(DynamicContext.TextElements, {Obj = ValLabel, Type = "Sub"})

		local TrackBtn = Instance.new("TextButton", Frame)
		TrackBtn.Size = UDim2.new(1, 0, 0, 14); TrackBtn.Position = UDim2.new(0, 0, 0, 18); TrackBtn.BackgroundTransparency = 1; TrackBtn.Text = ""; TrackBtn.ZIndex = 15

		local SliderBg = Instance.new("Frame", TrackBtn)
		SliderBg.Size = UDim2.new(1, 0, 0, 5); SliderBg.Position = UDim2.new(0, 0, 0.5, -2); SliderBg.BackgroundColor3 = Color3.fromRGB(215, 220, 230); SliderBg.ZIndex = 15
		Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(1, 0)

		local startRatio = math.clamp((default - min) / math.max(max - min, 0.0001), 0, 1)
		local SliderFill = Instance.new("Frame", SliderBg)
		SliderFill.Size = UDim2.new(startRatio, 0, 1, 0); SliderFill.BackgroundColor3 = DynamicContext.CurrentActiveColor; SliderFill.ZIndex = 15
		Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

		local Knob = Instance.new("Frame", SliderFill)
		Knob.Size = UDim2.new(0, 10, 0, 10); Knob.Position = UDim2.new(1, -5, 0.5, -5); Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Knob.ZIndex = 16
		Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

		local function applyVal(v)
			v = math.clamp(v, min, max); v = snapVal(v)
			local ratio = (v - min) / math.max(max - min, 0.0001)
			SliderFill.Size = UDim2.new(ratio, 0, 1, 0); ValLabel.Text = fmtVal(v) .. (unit or "")
			if callback then pcall(callback, v) end
		end

		local function update(input)
			local posX = input.Position.X - SliderBg.AbsolutePosition.X
			local ratio = math.clamp(posX / SliderBg.AbsoluteSize.X, 0, 1)
			local val = snapVal(min + (max - min) * ratio)
			SliderFill.Size = UDim2.new(ratio, 0, 1, 0); ValLabel.Text = fmtVal(val) .. (unit or "")
			if callback then pcall(callback, val) end
		end

		TrackBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				activeSliderUpdate = update
				update(input)
			end
		end)

		if cfgKey then
			UISliders[cfgKey] = applyVal
			DynamicContext.ActiveSliders[cfgKey] = { Update = function()
				if SliderFill.Parent then
					if not colorNearlyEqual(SliderFill.BackgroundColor3, DynamicContext.CurrentActiveColor, 0.03) then
						SliderFill.BackgroundColor3 = DynamicContext.CurrentActiveColor
					end
				end
			end }
		end
		return Frame
	end

	local function AddTextBox(parent, title, placeholder, default, callback)
		local Frame = Instance.new("Frame", parent)
		Frame.Size = UDim2.new(1, -12, 0, 50); Frame.BackgroundTransparency = 1; Frame.ZIndex = 14

		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(1, 0, 0, 16); Label.Position = UDim2.new(0, 0, 0, 0); Label.Text = title
		Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left; Label.BackgroundTransparency = 1; Label.ZIndex = 14
		table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})

		local Box = Instance.new("TextBox", Frame)
		Box.Size = UDim2.new(1, 0, 0, 28); Box.Position = UDim2.new(0, 0, 0, 18)
		Box.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Box.BackgroundTransparency = 0.5; Box.Font = Enum.Font.Gotham
		Box.PlaceholderText = placeholder or ""; Box.PlaceholderColor3 = DynamicContext.CurrentSubTextColor
		Box.Text = default or ""; Box.TextColor3 = DynamicContext.CurrentTextColor; Box.TextSize = 11; Box.ClearTextOnFocus = false; Box.ZIndex = 15
		Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 6)

		local stroke = Instance.new("UIStroke", Box)
		stroke.Thickness = 1; stroke.Transparency = 0.5; stroke.Color = DynamicContext.CurrentBorderColor
		table.insert(DynamicContext.BorderElements, stroke); table.insert(DynamicContext.TextElements, {Obj = Box, Type = "Main"})

		Box.FocusLost:Connect(function() if callback then pcall(callback, Box.Text) end end)
		return Frame
	end

	local function AddDropdown(parent, title, options, defaultIndex, callback)
		local DropFrame = Instance.new("Frame", parent)
		DropFrame.Size = UDim2.new(1, -12, 0, 32); DropFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		DropFrame.BackgroundTransparency = 0.5; DropFrame.ClipsDescendants = true; DropFrame.ZIndex = 20
		Instance.new("UICorner", DropFrame).CornerRadius = UDim.new(0, 6)

		local DropStroke = Instance.new("UIStroke", DropFrame)
		DropStroke.Thickness = 1; DropStroke.Transparency = 0.5; DropStroke.Color = DynamicContext.CurrentBorderColor
		table.insert(DynamicContext.BorderElements, DropStroke)

		local HeaderBtn = Instance.new("TextButton", DropFrame)
		HeaderBtn.Size = UDim2.new(1, 0, 0, 32); HeaderBtn.BackgroundTransparency = 1; HeaderBtn.Text = ""; HeaderBtn.ZIndex = 21

		local TitleLabel = Instance.new("TextLabel", HeaderBtn)
		TitleLabel.Size = UDim2.new(0.48, 0, 1, 0); TitleLabel.Position = UDim2.new(0, 8, 0, 0); TitleLabel.Text = title
		TitleLabel.Font = Enum.Font.GothamMedium; TitleLabel.TextColor3 = DynamicContext.CurrentTextColor; TitleLabel.TextSize = 10
		TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd; TitleLabel.BackgroundTransparency = 1; TitleLabel.ZIndex = 21
		table.insert(DynamicContext.TextElements, {Obj = TitleLabel, Type = "Main"})

		local SelectedLabel = Instance.new("TextLabel", HeaderBtn)
		SelectedLabel.Size = UDim2.new(0.42, -10, 1, 0); SelectedLabel.Position = UDim2.new(0.48, 0, 0, 0); SelectedLabel.Text = options[defaultIndex or 1] or "Select..."
		SelectedLabel.Font = Enum.Font.Gotham; SelectedLabel.TextColor3 = DynamicContext.CurrentSubTextColor; SelectedLabel.TextSize = 9
		SelectedLabel.TextXAlignment = Enum.TextXAlignment.Right; SelectedLabel.TextTruncate = Enum.TextTruncate.AtEnd; SelectedLabel.BackgroundTransparency = 1; SelectedLabel.ZIndex = 21
		table.insert(DynamicContext.TextElements, {Obj = SelectedLabel, Type = "Sub"})

		local ArrowLabel = Instance.new("TextLabel", HeaderBtn)
		ArrowLabel.Size = UDim2.new(0, 14, 1, 0); ArrowLabel.Position = UDim2.new(1, -16, 0, 0); ArrowLabel.Text = "▼"
		ArrowLabel.Font = Enum.Font.GothamBold; ArrowLabel.TextColor3 = DynamicContext.CurrentSubTextColor; ArrowLabel.TextSize = 8; ArrowLabel.BackgroundTransparency = 1; ArrowLabel.ZIndex = 21
		table.insert(DynamicContext.TextElements, {Obj = ArrowLabel, Type = "Sub"})

		local OptionContainer = Instance.new("Frame", DropFrame)
		OptionContainer.Size = UDim2.new(1, -10, 0, 0); OptionContainer.Position = UDim2.new(0, 5, 0, 30)
		OptionContainer.BackgroundTransparency = 1; OptionContainer.ClipsDescendants = true; OptionContainer.ZIndex = 21

		local OptionList = Instance.new("UIListLayout", OptionContainer)
		OptionList.Padding = UDim.new(0, 3); OptionList.SortOrder = Enum.SortOrder.LayoutOrder

		local isExpanded = false
		local optionHeight, expandedHeight = 22, 34 + (#options * 25)

		for i, optionText in ipairs(options) do
			local OptBtn = Instance.new("TextButton", OptionContainer)
			OptBtn.Size = UDim2.new(1, 0, 0, optionHeight); OptBtn.BackgroundColor3 = Color3.fromRGB(245, 248, 255)
			OptBtn.BackgroundTransparency = (i == (defaultIndex or 1)) and 0.2 or 0.7; OptBtn.Text = optionText
			OptBtn.Font = Enum.Font.Gotham; OptBtn.TextColor3 = DynamicContext.CurrentTextColor; OptBtn.TextSize = 9
			OptBtn.TextTruncate = Enum.TextTruncate.AtEnd; OptBtn.ZIndex = 22
			table.insert(DynamicContext.TextElements, {Obj = OptBtn, Type = "Main"})
			Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)

			OptBtn.MouseButton1Click:Connect(function()
				SelectedLabel.Text = optionText
				for _, child in ipairs(OptionContainer:GetChildren()) do
					if child:IsA("TextButton") then
						TweenService:Create(child, TweenInfo.new(0.2), {BackgroundTransparency = (child == OptBtn) and 0.2 or 0.7}):Play()
					end
				end
				isExpanded = false
				local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				TweenService:Create(DropFrame, tweenInfo, {Size = UDim2.new(1, -12, 0, 32)}):Play()
				TweenService:Create(OptionContainer, tweenInfo, {Size = UDim2.new(1, -10, 0, 0)}):Play()
				TweenService:Create(ArrowLabel, tweenInfo, {Rotation = 0}):Play()
				if callback then pcall(callback, optionText, i) end
			end)
		end

		HeaderBtn.MouseButton1Click:Connect(function()
			isExpanded = not isExpanded
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			if isExpanded then
				TweenService:Create(DropFrame, tweenInfo, {Size = UDim2.new(1, -12, 0, expandedHeight)}):Play()
				TweenService:Create(OptionContainer, tweenInfo, {Size = UDim2.new(1, -10, 0, #options * 25)}):Play()
				TweenService:Create(ArrowLabel, tweenInfo, {Rotation = 180}):Play()
			else
				TweenService:Create(DropFrame, tweenInfo, {Size = UDim2.new(1, -12, 0, 32)}):Play()
				TweenService:Create(OptionContainer, tweenInfo, {Size = UDim2.new(1, -10, 0, 0)}):Play()
				TweenService:Create(ArrowLabel, tweenInfo, {Rotation = 0}):Play()
			end
		end)
		return DropFrame
	end

	local function CreateSubSegmentNav(parent, segments, onSegmentChanged, initialIndex)
		initialIndex = initialIndex or 1
		local currentIndex = initialIndex
		local SegmentFrame = Instance.new("Frame", parent)
		SegmentFrame.Size = UDim2.new(1, -16, 0, 26); SegmentFrame.Position = UDim2.new(0, 8, 0, 32)
		SegmentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255); SegmentFrame.BackgroundTransparency = 0.4; SegmentFrame.BorderSizePixel = 0; SegmentFrame.ZIndex = 15
		Instance.new("UICorner", SegmentFrame).CornerRadius = UDim.new(0, 13)

		local SegStroke = Instance.new("UIStroke", SegmentFrame)
		SegStroke.Thickness = 1; SegStroke.Transparency = 0.5; SegStroke.Color = DynamicContext.CurrentBorderColor
		table.insert(DynamicContext.BorderElements, SegStroke)

		local Indicator = Instance.new("Frame", SegmentFrame)
		Indicator.Size = UDim2.new(1 / #segments, -4, 1, -4)
		Indicator.Position = UDim2.new((initialIndex - 1) * (1 / #segments), 2, 0, 2)
		Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Indicator.BackgroundTransparency = 0.1; Indicator.ZIndex = 16
		Instance.new("UICorner", Indicator).CornerRadius = UDim.new(0, 11)

		local Buttons = {}
		for i, segName in ipairs(segments) do
			local Btn = Instance.new("TextButton", SegmentFrame)
			Btn.Size = UDim2.new(1 / #segments, 0, 1, 0); Btn.Position = UDim2.new((i - 1) * (1 / #segments), 0, 0, 0)
			Btn.BackgroundTransparency = 1; Btn.Text = segName; Btn.Font = Enum.Font.GothamBold
			Btn.TextColor3 = (i == initialIndex) and DynamicContext.CurrentTextColor or DynamicContext.CurrentSubTextColor
			Btn.TextSize = 9; Btn.TextTruncate = Enum.TextTruncate.AtEnd; Btn.ZIndex = 17

			Btn.MouseButton1Click:Connect(function()
				if currentIndex == i then return end
				currentIndex = i
				for _, b in ipairs(Buttons) do b.TextColor3 = DynamicContext.CurrentSubTextColor end
				Btn.TextColor3 = DynamicContext.CurrentTextColor
				TweenService:Create(Indicator, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.new((i - 1) * (1 / #segments), 2, 0, 2)
				}):Play()
				if onSegmentChanged then pcall(onSegmentChanged, segName, i) end
			end)
			table.insert(Buttons, Btn)
		end
		return SegmentFrame
	end

	local Island = Instance.new("CanvasGroup", ScreenGui)
	Island.Name = "DynamicIsland"; Island.Size = UDim2.new(0, 200, 0, 36); Island.Position = UDim2.new(0.5, -100, 0, 15)
	Island.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Island.GroupTransparency = 1; Island.Visible = false; Island.ZIndex = 200
	local IslandCorner = Instance.new("UICorner", Island)
	IslandCorner.CornerRadius = UDim.new(0, 18)

	local IslandStroke = Instance.new("UIStroke", Island)
	IslandStroke.Thickness = 2; IslandStroke.Color = Color3.fromRGB(255, 255, 255)
	local IslandGradient = Instance.new("UIGradient", Island)
	local IslandStrokeGradient = Instance.new("UIGradient", IslandStroke)
	IslandStrokeGradient.Color = StrokeGradient.Color

	local IslandLightOverlay = Instance.new("Frame", Island)
	IslandLightOverlay.Size = UDim2.new(1, 0, 1, 0); IslandLightOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	IslandLightOverlay.BackgroundTransparency = 0.35; IslandLightOverlay.ZIndex = 200

	local IslandContent = Instance.new("Frame", Island)
	IslandContent.Size = UDim2.new(1, 0, 1, 0); IslandContent.BackgroundTransparency = 1; IslandContent.ZIndex = 201

	local IslandLogo = Instance.new("TextLabel", IslandContent)
	IslandLogo.Size = UDim2.new(0, 90, 1, 0); IslandLogo.Position = UDim2.new(0, 10, 0, 0); IslandLogo.Font = Enum.Font.FredokaOne
	IslandLogo.Text = "Link.cc"; IslandLogo.TextColor3 = DynamicContext.CurrentLogoColor; IslandLogo.TextSize = 14; IslandLogo.BackgroundTransparency = 1; IslandLogo.ZIndex = 202

	local IslandStatus = Instance.new("TextLabel", IslandContent)
	IslandStatus.Size = UDim2.new(0, 70, 1, 0); IslandStatus.Position = UDim2.new(0, 85, 0, 0); IslandStatus.Font = Enum.Font.GothamMedium
	IslandStatus.Text = "Running"; IslandStatus.TextColor3 = DynamicContext.CurrentSubTextColor; IslandStatus.TextSize = 10
	IslandStatus.TextXAlignment = Enum.TextXAlignment.Left; IslandStatus.BackgroundTransparency = 1; IslandStatus.ZIndex = 202
	table.insert(DynamicContext.TextElements, {Obj = IslandStatus, Type = "Sub"})

	local ExpandBtn = Instance.new("TextButton", IslandContent)
	ExpandBtn.Size = UDim2.new(0, 50, 0, 22); ExpandBtn.Position = UDim2.new(1, -58, 0.5, -11)
	ExpandBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); ExpandBtn.BackgroundTransparency = 0.2; ExpandBtn.Text = "Open"
	ExpandBtn.Font = Enum.Font.GothamBold; ExpandBtn.TextColor3 = DynamicContext.CurrentTextColor; ExpandBtn.TextSize = 10; ExpandBtn.ZIndex = 203
	Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 11)
	table.insert(DynamicContext.TextElements, {Obj = ExpandBtn, Type = "Main"})

	local AudioIslandModal = Instance.new("CanvasGroup", ScreenGui)
	AudioIslandModal.Name = "AudioIslandModal"; AudioIslandModal.Size = UDim2.new(0, 280, 0, 140); AudioIslandModal.Position = UDim2.new(0.5, -140, 0.5, -70)
	AudioIslandModal.BackgroundColor3 = Color3.fromRGB(255, 255, 255); AudioIslandModal.GroupTransparency = 1; AudioIslandModal.Visible = false; AudioIslandModal.ZIndex = 300
	Instance.new("UICorner", AudioIslandModal).CornerRadius = UDim.new(0, 22)

	local AudioModalStroke = Instance.new("UIStroke", AudioIslandModal)
	AudioModalStroke.Thickness = 2; AudioModalStroke.Color = Color3.fromRGB(255, 255, 255)
	local AudioModalStrokeGradient = Instance.new("UIGradient", AudioModalStroke)
	AudioModalStrokeGradient.Color = StrokeGradient.Color
	local AudioModalGradient = Instance.new("UIGradient", AudioIslandModal)

	local AudioModalLightOverlay = Instance.new("Frame", AudioIslandModal)
	AudioModalLightOverlay.Size = UDim2.new(1, 0, 1, 0); AudioModalLightOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	AudioModalLightOverlay.BackgroundTransparency = 0.35; AudioModalLightOverlay.ZIndex = 300

	local InputContainer = Instance.new("Frame", AudioIslandModal)
	InputContainer.Size = UDim2.new(1, -24, 0, 32); InputContainer.Position = UDim2.new(0, 12, 0, 12)
	InputContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255); InputContainer.BackgroundTransparency = 0.3; InputContainer.ZIndex = 301
	Instance.new("UICorner", InputContainer).CornerRadius = UDim.new(0, 16)

	local InputStroke = Instance.new("UIStroke", InputContainer)
	InputStroke.Thickness = 1.5; InputStroke.Color = Color3.fromRGB(255, 255, 255)
	local InputStrokeGradient = Instance.new("UIGradient", InputStroke)
	InputStrokeGradient.Color = StrokeGradient.Color

	local AudioTextBox = Instance.new("TextBox", InputContainer)
	AudioTextBox.Size = UDim2.new(1, -16, 1, 0); AudioTextBox.Position = UDim2.new(0, 8, 0, 0); AudioTextBox.BackgroundTransparency = 1
	AudioTextBox.Font = Enum.Font.GothamMedium; AudioTextBox.PlaceholderText = "Enter Roblox Sound ID..."
	AudioTextBox.PlaceholderColor3 = DynamicContext.CurrentSubTextColor; AudioTextBox.Text = ""
	AudioTextBox.TextColor3 = DynamicContext.CurrentTextColor; AudioTextBox.TextSize = 11; AudioTextBox.ClearTextOnFocus = false; AudioTextBox.ZIndex = 302
	table.insert(DynamicContext.TextElements, {Obj = AudioTextBox, Type = "Main"})

	AudioTextBox:GetPropertyChangedSignal("Text"):Connect(function() AudioTextBox.Text = AudioTextBox.Text:gsub("%D+", "") end)

	local ModalVolumeFrame = Instance.new("Frame", AudioIslandModal)
	ModalVolumeFrame.Size = UDim2.new(1, -24, 0, 32); ModalVolumeFrame.Position = UDim2.new(0, 12, 0, 50)
	ModalVolumeFrame.BackgroundTransparency = 1; ModalVolumeFrame.ZIndex = 301

	AddSlider(ModalVolumeFrame, "Volume", 0, 5, 2, "", function(val)
		DynamicContext.CurrentVolume = val
		if DynamicContext.GlobalAudio then DynamicContext.GlobalAudio.Volume = val end
	end)

	local ControlIsland = Instance.new("Frame", AudioIslandModal)
	ControlIsland.Size = UDim2.new(1, -24, 0, 32); ControlIsland.Position = UDim2.new(0, 12, 0, 94)
	ControlIsland.BackgroundColor3 = Color3.fromRGB(255, 255, 255); ControlIsland.BackgroundTransparency = 0.25; ControlIsland.ZIndex = 301
	Instance.new("UICorner", ControlIsland).CornerRadius = UDim.new(0, 16)
	local ControlStroke = Instance.new("UIStroke", ControlIsland)
	ControlStroke.Thickness = 1; ControlStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, ControlStroke)

	local ConfirmBtn = Instance.new("TextButton", ControlIsland)
	ConfirmBtn.Size = UDim2.new(0.6, -2, 1, -4); ConfirmBtn.Position = UDim2.new(0, 2, 0, 2)
	ConfirmBtn.BackgroundColor3 = DynamicContext.CurrentActiveColor; ConfirmBtn.Text = "Confirm"
	ConfirmBtn.Font = Enum.Font.GothamBold; ConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255); ConfirmBtn.TextSize = 11; ConfirmBtn.ZIndex = 302
	Instance.new("UICorner", ConfirmBtn).CornerRadius = UDim.new(0, 14)

	local CancelBtn = Instance.new("TextButton", ControlIsland)
	CancelBtn.Size = UDim2.new(0.4, -4, 1, -4); CancelBtn.Position = UDim2.new(0.6, 2, 0, 2)
	CancelBtn.BackgroundTransparency = 1; CancelBtn.Text = "Cancel"
	CancelBtn.Font = Enum.Font.GothamMedium; CancelBtn.TextColor3 = DynamicContext.CurrentSubTextColor; CancelBtn.TextSize = 10; CancelBtn.ZIndex = 302
	table.insert(DynamicContext.TextElements, {Obj = CancelBtn, Type = "Sub"})

	local function PlayAntiOverrideAudio(soundId)
		if soundId == "" then return end
		if DynamicContext.GlobalAudio then
			DynamicContext.GlobalAudio:Stop(); DynamicContext.GlobalAudio:Destroy(); DynamicContext.GlobalAudio = nil
		end
		local sound = Instance.new("Sound")
		sound.Name = "LinkCcAudioPlayer"; sound.SoundId = "rbxassetid://" .. tostring(soundId)
		sound.Volume = DynamicContext.CurrentVolume; sound.Looped = false; sound.Parent = SoundService
		sound.Ended:Connect(function() if DynamicContext.GlobalAudio == sound then sound:Destroy(); DynamicContext.GlobalAudio = nil end end)
		sound:Play(); DynamicContext.GlobalAudio = sound
	end

	local function ShowAudioModal()
		AudioIslandModal.Visible = true; AudioIslandModal.GroupTransparency = 1
		AudioIslandModal.Size = UDim2.new(0, 220, 0, 110); AudioIslandModal.Position = UDim2.new(0.5, -110, 0.5, -55)
		TweenService:Create(AudioIslandModal, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			GroupTransparency = 0, Size = UDim2.new(0, 280, 0, 140), Position = UDim2.new(0.5, -140, 0.5, -70)
		}):Play()
		AudioTextBox:CaptureFocus()
	end

	local function HideAudioModal(isConfirm)
		local closeTween = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		local tSize = isConfirm and UDim2.new(0, 300, 0, 150) or UDim2.new(0, 240, 0, 120)
		local tPos = isConfirm and UDim2.new(0.5, -150, 0.5, -75) or UDim2.new(0.5, -120, 0.5, -60)
		TweenService:Create(AudioIslandModal, closeTween, {GroupTransparency = 1, Size = tSize, Position = tPos}):Play()
		task.delay(0.28, function()
			AudioIslandModal.Visible = false
			if isConfirm then PlayAntiOverrideAudio(AudioTextBox.Text) end
		end)
	end

	ConfirmBtn.MouseButton1Click:Connect(function() HideAudioModal(true) end)
	CancelBtn.MouseButton1Click:Connect(function() HideAudioModal(false) end)
	AudioTextBox.FocusLost:Connect(function(enterPressed) if enterPressed then HideAudioModal(true) end end)

	local function AnimateSubPageTransition(container, buildContentFunc)
		local oldPage = container:FindFirstChild("SubContentPage")
		if oldPage then oldPage:Destroy() end
		local newPage = Instance.new("CanvasGroup")
		newPage.Name = "SubContentPage"
		newPage.Size = UDim2.new(1, 0, 1, -68); newPage.Position = UDim2.new(0, 0, 0, 28)
		newPage.BackgroundTransparency = 1; newPage.GroupTransparency = 1; newPage.ZIndex = 14
		newPage.Parent = container
		local Scroll = CreateScrollList(newPage, 0)
		local ok, err = pcall(buildContentFunc, Scroll)
		if not ok then warn("[AsylumHub] UI Build Error: " .. tostring(err)) end
		TweenService:Create(newPage, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 68), GroupTransparency = 0
		}):Play()
	end

	local function scanItemNames()
		local names, seen = {}, {}
		for _, inst in ipairs(CollectionService:GetTagged("ScavengerHuntItem")) do
			if inst.Parent and not seen[inst.Name] then
				seen[inst.Name] = true
				names[#names + 1] = inst.Name
			end
		end
		for d in pairs(promptSet) do
			if d.Parent and d.Enabled then
				local model = d:FindFirstAncestorWhichIsA("Model")
				if model and not seen[model.Name] then
					seen[model.Name] = true
					names[#names + 1] = model.Name
				end
			end
		end
		table.sort(names)
		return names
	end

	local activeItemToggleContainer = nil

	local TabData = {
		["Combat"] = {
			hasSub = true,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "战斗"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local SubTitle = Instance.new("TextLabel", SubConfigCard)
				SubTitle.Size = UDim2.new(1, -16, 0, 25); SubTitle.Position = UDim2.new(0, 8, 0, 6); SubTitle.Text = "详细设置"
				SubTitle.Font = Enum.Font.GothamBold; SubTitle.TextColor3 = DynamicContext.CurrentTextColor; SubTitle.TextSize = 13
				SubTitle.TextXAlignment = Enum.TextXAlignment.Left; SubTitle.BackgroundTransparency = 1; SubTitle.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = SubTitle, Type = "Main"})

				local function buildAuraPage(scroll)
					AddToggle(scroll, "杀戮光环 [X]", "范围内轮转结算伤害", CFG.KillAura, function(v) CFG.KillAura = v end, "KillAura")
					AddToggle(scroll, "光环直伤", "必须开启，否则光环无输出", CFG.AuraDirect, function(v) CFG.AuraDirect = v end, "AuraDirect")
					AddToggle(scroll, "光环播放动画", "看起来像正常攻击", CFG.AuraAnim, function(v) CFG.AuraAnim = v end, "AuraAnim")
					AddToggle(scroll, "命中头部", "无伤害加成，模型小易 miss", CFG.AuraHead, function(v) CFG.AuraHead = v end, "AuraHead")

					AddToggle(scroll, "多目标轮转", "每轮攻击一个目标，忽略自适应倍率", CFG.MultiTargetAttack, function(v) CFG.MultiTargetAttack = v end, "MultiTargetAttack")
					AddSlider(scroll, "轮转个数", 1, 3, CFG.MultiTargetCount, " 个", function(v) CFG.MultiTargetCount = v end, "MultiTargetCount")
					-- v3.3 新增
					AddToggle(scroll, "使用武器原始攻速", "以武器 CooldownTime/Speed 为准，忽略冷却滑块", CFG.UseWeaponSpeed, function(v) CFG.UseWeaponSpeed = v end, "UseWeaponSpeed")

					AddSlider(scroll, "光环半径", 4, 15, CFG.AuraRadius, "", function(v) CFG.AuraRadius = v end, "AuraRadius")
					AddToggle(scroll, "无视原武器范围", "强制使用滑块半径", CFG.AuraCustomRange, function(v) CFG.AuraCustomRange = v end, "AuraCustomRange")
					AddSlider(scroll, "攻击冷却", 0.5, 1.0, CFG.AttackCooldown, "s", function(v) CFG.AttackCooldown = v end, "AttackCooldown", 2)
					AddToggle(scroll, "自适应优先", "多目标/原始攻速开启时自动失效", CFG.Adaptive, function(v) CFG.Adaptive = v end, "Adaptive")
					AddToggle(scroll, "仅攻击黑名单", "只打「Players」页黑名单玩家", CFG.OnlyAttackBlacklist, function(v) CFG.OnlyAttackBlacklist = v end, "OnlyAttackBlacklist")
					AddToggle(scroll, "隐蔽模式", "限制速度 + 随机延迟", CFG.Stealth, function(v) CFG.Stealth = v; if Handlers.Stealth then Handlers.Stealth(v) end end, "Stealth")
				end

				local function buildAttackPage(scroll)
					AddToggle(scroll, "自动攻击 [F]", "全武器通用", CFG.AutoAttack, function(v) CFG.AutoAttack = v end, "AutoAttack")
					AddToggle(scroll, "自动朝向", "仅手持武器时生效", CFG.AutoFace, function(v) CFG.AutoFace = v end, "AutoFace")
					AddToggle(scroll, "自动换武器", "有目标时换出", CFG.AutoEquip, function(v) CFG.AutoEquip = v end, "AutoEquip")
					AddToggle(scroll, "选最高伤害武器", nil, CFG.AutoBestWeapon, function(v) CFG.AutoBestWeapon = v end, "AutoBestWeapon")
					AddToggle(scroll, "自动贴近目标", "Fly 方式", CFG.CombatFollow, function(v) CFG.CombatFollow = v end, "CombatFollow")
				end

				local function buildRangedPage(scroll)
					AddToggle(scroll, "远程/电击枪自动射击", "自动瞄准 + 激活", CFG.AutoShoot, function(v) CFG.AutoShoot = v end, "AutoShoot")
					AddToggle(scroll, "只对玩家开火", nil, CFG.ShootOnlyPlayers, function(v) CFG.ShootOnlyPlayers = v end, "ShootOnlyPlayers")
					AddToggle(scroll, "攻击队友（危险）", nil, CFG.AttackTeammates, function(v) CFG.AttackTeammates = v end, "AttackTeammates")
					AddToggle(scroll, "攻击 NPC", nil, CFG.AttackNPCs, function(v) CFG.AttackNPCs = v end, "AttackNPCs")
					AddToggle(scroll, "攻击范围增强", "扩大挥击体积", CFG.ReachBoost, function(v) CFG.ReachBoost = v; if Handlers.ReachBoost then Handlers.ReachBoost(v) end end, "ReachBoost")
				end

				CreateSubSegmentNav(MainConfigCard, {"光环", "攻击", "远程"}, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "光环" then buildAuraPage(scroll)
						elseif seg == "攻击" then buildAttackPage(scroll)
						else buildRangedPage(scroll) end
					end)
				end)
				AnimateSubPageTransition(MainConfigCard, buildAuraPage)

				local SubScroll = CreateScrollList(SubConfigCard, 35)
				local infoLabel = Instance.new("TextLabel", SubScroll)
				infoLabel.Size = UDim2.new(1, -12, 0, 100)
				infoLabel.BackgroundTransparency = 1
				infoLabel.Font = Enum.Font.Gotham
				infoLabel.TextSize = 10
				infoLabel.TextColor3 = DynamicContext.CurrentSubTextColor
				infoLabel.TextXAlignment = Enum.TextXAlignment.Left
				infoLabel.TextYAlignment = Enum.TextYAlignment.Top
				infoLabel.TextWrapped = true
				infoLabel.Text = "提示：\n战斗功能区切换在左侧主卡片内。\n详细设置请使用上方选项卡。"
				table.insert(DynamicContext.TextElements, {Obj = infoLabel, Type = "Sub"})
			end
		},
		["Visuals"] = {
			hasSub = false,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "视觉 / 画面"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local function buildPlayerESPPage(scroll)
					AddToggle(scroll, "玩家 ESP [V]", "方框 + 名字 + 距离", CFG.PlayerESP, function(v) CFG.PlayerESP = v end, "PlayerESP")
					AddToggle(scroll, "只显示敌人", nil, CFG.EnemyOnly, function(v) CFG.EnemyOnly = v end, "EnemyOnly")
					AddToggle(scroll, "只 ESP 黑名单玩家", "仅显示「Players」页黑名单玩家", CFG.ESPOnlyBlacklist, function(v) CFG.ESPOnlyBlacklist = v end, "ESPOnlyBlacklist")
					AddToggle(scroll, "玩家列表", "右侧面板", CFG.PlayerList, function(v) CFG.PlayerList = v end, "PlayerList")
					AddToggle(scroll, "FPS / 坐标 / 延迟", nil, CFG.InfoHUD, function(v) CFG.InfoHUD = v end, "InfoHUD")
					AddTextBox(scroll, "排除玩家（逗号分隔）", "输入玩家名关键词，如: Noob, Bot", type(CFG.ESPPlayerExcludeList)=="table" and table.concat(CFG.ESPPlayerExcludeList, ", ") or tostring(CFG.ESPPlayerExcludeList), function(text) CFG.ESPPlayerExcludeList = parseKeywords(text) end)
				end

				local function buildItemESPPage(scroll)
					AddToggle(scroll, "物品 ESP [B]", "南瓜 / 拾取物", CFG.ItemESP, function(v) CFG.ItemESP = v end, "ItemESP")
					AddToggle(scroll, "显示南瓜", "ScavengerHuntItem", CFG.ESPShowPumpkins, function(v) CFG.ESPShowPumpkins = v end, "ESPShowPumpkins")
					AddToggle(scroll, "显示拾取物", "ProximityPrompt 类型", CFG.ESPShowPickups, function(v) CFG.ESPShowPickups = v end, "ESPShowPickups")
					AddTextBox(scroll, "单独透视物品名（留空则显示全部）", "例如输入: Chest", type(CFG.ESPItemKeywordList)=="table" and table.concat(CFG.ESPItemKeywordList, ", ") or tostring(CFG.ESPItemKeywordList), function(text) CFG.ESPItemKeywordList = parseKeywords(text) end)

					local container = Instance.new("Frame", scroll)
					container.Size = UDim2.new(1, -12, 0, 0)
					container.AutomaticSize = Enum.AutomaticSize.Y
					container.BackgroundTransparency = 1
					container.ZIndex = 14
					local ll = Instance.new("UIListLayout", container)
					ll.Padding = UDim.new(0, 8)
					ll.SortOrder = Enum.SortOrder.LayoutOrder

					local function rebuildItemToggles()
						if not container.Parent then return end
						for _, c in ipairs(container:GetChildren()) do
							if not c:IsA("UIListLayout") then c:Destroy() end
						end
						local names = scanItemNames()
						if #names == 0 then
							local tip = Instance.new("TextLabel", container)
							tip.Size = UDim2.new(1, 0, 0, 22)
							tip.BackgroundTransparency = 1
							tip.Font = Enum.Font.Gotham
							tip.TextSize = 10
							tip.Text = "（场景中未检测到物品，点击上方按钮刷新）"
							tip.TextColor3 = DynamicContext.CurrentSubTextColor
							tip.TextXAlignment = Enum.TextXAlignment.Left
							table.insert(DynamicContext.TextElements, {Obj = tip, Type = "Sub"})
							return
						end
						for _, n in ipairs(names) do
							AddToggle(container, n, nil, CFG.ItemFilter[n] ~= false, function(v) CFG.ItemFilter[n] = v end, nil)
						end
					end

					activeItemToggleContainer = container

					AddButton(scroll, "刷新物品开关列表", "重新扫描场景中的物品名", function()
						rebuildItemToggles()
					end)

					rebuildItemToggles()
				end

				local function buildDoorESPPage(scroll)
					AddToggle(scroll, "门 ESP [J]", "穿墙高亮", CFG.DoorESP, function(v) CFG.DoorESP = v end, "DoorESP")
					AddTextBox(scroll, "门名称关键词（逗号分隔）", "默认 WindowedDoor", type(CFG.ESPDoorKeywordList)=="table" and table.concat(CFG.ESPDoorKeywordList, ", ") or tostring(CFG.ESPDoorKeywordList), function(text)
						local kws = parseKeywords(text)
						if #kws == 0 then kws = { "WindowedDoor" } end
						CFG.ESPDoorKeywordList = kws
					end)
				end

				local function buildDisplayPage(scroll)
					AddToggle(scroll, "全亮 [L]", "夜视", CFG.Fullbright, function(v) CFG.Fullbright = v; if Handlers.Fullbright then Handlers.Fullbright(v) end end, "Fullbright")
					AddToggle(scroll, "关闭滤镜", "红光/模糊", CFG.NoScreenFX, function(v) CFG.NoScreenFX = v; if Handlers.NoScreenFX then Handlers.NoScreenFX(v) end end, "NoScreenFX")
					AddToggle(scroll, "性能模式", "关粒子 + 启用 FPS 分级", CFG.PerfMode, function(v) CFG.PerfMode = v; if Handlers.PerfMode then Handlers.PerfMode(v) end end, "PerfMode")
					AddToggle(scroll, "隐藏游戏界面", nil, CFG.HideGameUI, function(v) CFG.HideGameUI = v; if Handlers.HideGameUI then Handlers.HideGameUI(v) end end, "HideGameUI")
				end

				local function buildCameraPage(scroll)
					AddToggle(scroll, "禁用相机抖动", nil, CFG.NoCameraShake, function(v) CFG.NoCameraShake = v; if Handlers.NoCameraShake then Handlers.NoCameraShake(v) end end, "NoCameraShake")
					AddToggle(scroll, "自定义视野", nil, CFG.CustomFOV, function(v) CFG.CustomFOV = v end, "CustomFOV")
					AddSlider(scroll, "视野角度", 50, 110, CFG.FOV, "°", function(v) CFG.FOV = v; local cam = workspace.CurrentCamera; if cam and CFG.CustomFOV then cam.FieldOfView = v end end, "FOV")
				end

				CreateSubSegmentNav(MainConfigCard, {"玩家", "物品", "门", "画面", "相机"}, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "玩家" then buildPlayerESPPage(scroll)
						elseif seg == "物品" then buildItemESPPage(scroll)
						elseif seg == "门" then buildDoorESPPage(scroll)
						elseif seg == "画面" then buildDisplayPage(scroll)
						else buildCameraPage(scroll) end
					end)
				end)
				AnimateSubPageTransition(MainConfigCard, buildPlayerESPPage)
			end
		},
		["Movement"] = {
			hasSub = false,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "移动 / 位移"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local function buildBasePage(scroll)
					AddSlider(scroll, "移速", 16, 90, CFG.Speed, "", function(v) 
						if CFG.Stealth then
							prevSpeedBeforeStealth = v
						end
						CFG.Speed = v
						local cap = CFG.Stealth and math.min(v, CFG.SafeSpeed) or v
						pcall(function() SL.UpdateWalkspeed(cap) end)
					end, "Speed")
					local speedModeIndex = 1
					if CFG.MoveMode == "Velocity" then speedModeIndex = 2
					elseif CFG.MoveMode == "MoveDirection" then speedModeIndex = 3 end
					AddDropdown(scroll, "速度模式", {"WalkSpeed", "Velocity", "MoveDirection"}, speedModeIndex, function(selected)
						CFG.MoveMode = selected
						if selected == "WalkSpeed" then
							local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
							if hum then pcall(function() hum.WalkSpeed = CFG.Speed end) end
						end
					end)
					AddToggle(scroll, "高跳", nil, CFG.HighJump, function(v) CFG.HighJump = v; if Handlers.HighJump then Handlers.HighJump(v) end end, "HighJump")
					AddToggle(scroll, "无限跳", nil, CFG.InfiniteJump, function(v) CFG.InfiniteJump = v end, "InfiniteJump")
					AddToggle(scroll, "自动起身", "被击倒/电击后", CFG.AutoGetUp, function(v) CFG.AutoGetUp = v end, "AutoGetUp")
				end

				local function buildSpecialPage(scroll)
					AddToggle(scroll, "穿墙", nil, CFG.Noclip, function(v) CFG.Noclip = v; if Handlers.Noclip then Handlers.Noclip(v) end end, "Noclip")
					AddToggle(scroll, "飞行", "WASD + 空格/左Ctrl", CFG.Fly, function(v) CFG.Fly = v; if Handlers.Fly then Handlers.Fly(v) end end, "Fly")
					AddSlider(scroll, "飞行速度", 20, 100, CFG.FlySpeed, "", function(v) CFG.FlySpeed = v end, "FlySpeed")
					AddToggle(scroll, "自由视角", nil, CFG.Freecam, function(v) CFG.Freecam = v; if Handlers.Freecam then Handlers.Freecam(v) end end, "Freecam")
				end

				CreateSubSegmentNav(MainConfigCard, {"基础", "特殊"}, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "基础" then buildBasePage(scroll) else buildSpecialPage(scroll) end
					end)
				end)
				AnimateSubPageTransition(MainConfigCard, buildBasePage)
			end
		},
		["Auto"] = {
			hasSub = false,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "自动 / 生存"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local function buildInteractPage(scroll)
					AddToggle(scroll, "自动寻路 (Fly)", "关闭后不再自动移动", CFG.AutoPath, function(v) CFG.AutoPath = v end, "AutoPath")
					AddToggle(scroll, "自动交互 [G]", "收集 / 拾取", CFG.AutoInteract, function(v) CFG.AutoInteract = v end, "AutoInteract")
					AddToggle(scroll, "自动交互-全部", "⚠ 危险：会放行任意交互（含购买/出售/丢弃）", CFG.InteractAll, function(v) CFG.InteractAll = v end, "InteractAll")
					AddToggle(scroll, "自动开门", "敲附近的门", CFG.AutoOpenDoors, function(v) CFG.AutoOpenDoors = v end, "AutoOpenDoors")
					AddToggle(scroll, "走向万圣节门", "Fly 直达", CFG.AutoWalkDoor, function(v) CFG.AutoWalkDoor = v end, "AutoWalkDoor")
					AddToggle(scroll, "走向最近拾取物", "Fly 直达", CFG.AutoWalkLoot, function(v) CFG.AutoWalkLoot = v end, "AutoWalkLoot")
				end

				local function buildSurvivePage(scroll)
					AddToggle(scroll, "无限体力 [K]", nil, CFG.InfiniteStamina, function(v) CFG.InfiniteStamina = v; if Handlers.InfiniteStamina then Handlers.InfiniteStamina(v) end end, "InfiniteStamina")
					AddToggle(scroll, "防挂机", nil, CFG.AntiAFK, function(v) CFG.AntiAFK = v; if Handlers.AntiAFK then Handlers.AntiAFK(v) end end, "AntiAFK")
				end

				CreateSubSegmentNav(MainConfigCard, {"交互", "生存"}, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "交互" then buildInteractPage(scroll) else buildSurvivePage(scroll) end
					end)
				end)
				AnimateSubPageTransition(MainConfigCard, buildInteractPage)
			end
		},
		["Players"] = {
			hasSub = false,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "玩家名单"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local currentMode = CFG.__listEditMode or "White"
				local initialSeg = (currentMode == "Black") and 2 or 1

				local containerRef = nil

				local function rebuildList()
					if not containerRef or not containerRef.Parent then return end
					for _, c in ipairs(containerRef:GetChildren()) do
						if not c:IsA("UIListLayout") then c:Destroy() end
					end

					local players = {}
					for _, p in ipairs(Players:GetPlayers()) do
						if p ~= LP then players[#players + 1] = p end
					end
					table.sort(players, function(a, b)
						local ac = (CFG.Whitelist[a.Name] or CFG.Blacklist[a.Name]) and 1 or 0
						local bc = (CFG.Whitelist[b.Name] or CFG.Blacklist[b.Name]) and 1 or 0
						if ac ~= bc then return ac > bc end
						local at = a.Team and a.Team.Name or ""
						local bt = b.Team and b.Team.Name or ""
						if at ~= bt then return at < bt end
						return a.Name < b.Name
					end)

					if #players == 0 then
						local empty = Instance.new("TextLabel", containerRef)
						empty.Size = UDim2.new(1, 0, 0, 24)
						empty.BackgroundTransparency = 1
						empty.Font = Enum.Font.Gotham
						empty.TextSize = 10
						empty.Text = "（无其他玩家）"
						empty.TextColor3 = DynamicContext.CurrentSubTextColor
						empty.TextXAlignment = Enum.TextXAlignment.Left
						table.insert(DynamicContext.TextElements, {Obj = empty, Type = "Sub"})
						return
					end

					for _, p in ipairs(players) do
						local isW = CFG.Whitelist[p.Name] == true
						local isB = CFG.Blacklist[p.Name] == true
						local checked = (currentMode == "White" and isW) or (currentMode == "Black" and isB)
						local modeColor = currentMode == "White" and Color3.fromRGB(60, 170, 255) or Color3.fromRGB(255, 90, 90)

						local row = Instance.new("TextButton", containerRef)
						row.Size = UDim2.new(1, 0, 0, 32)
						row.BackgroundColor3 = checked and Color3.fromRGB(255, 245, 220) or Color3.fromRGB(255, 255, 255)
						row.BackgroundTransparency = checked and 0.45 or 0.7
						row.Text = ""
						row.AutoButtonColor = false
						row.ZIndex = 15
						Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

						local rowStroke = Instance.new("UIStroke", row)
						rowStroke.Thickness = 1
						rowStroke.Transparency = checked and 0.35 or 0.7
						rowStroke.Color = checked and modeColor or Color3.fromRGB(200, 205, 215)
						table.insert(DynamicContext.BorderElements, rowStroke)

						local nameLbl = Instance.new("TextLabel", row)
						nameLbl.Size = UDim2.new(1, -46, 1, 0)
						nameLbl.Position = UDim2.new(0, 10, 0, 0)
						nameLbl.BackgroundTransparency = 1
						nameLbl.Font = Enum.Font.GothamMedium
						nameLbl.TextSize = 11
						nameLbl.TextXAlignment = Enum.TextXAlignment.Left
						nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
						nameLbl.ZIndex = 16

						local prefix = ""
						if isW then prefix = "[白] "
						elseif isB then prefix = "[黑] " end
						nameLbl.Text = prefix .. p.Name
						nameLbl.TextColor3 = isB and Color3.fromRGB(255, 90, 90) or (isW and Color3.fromRGB(60, 170, 255) or Color3.fromRGB(35, 35, 45))
						nameLbl:SetAttribute("_HubFixedColor", true)

						local checkBox = Instance.new("Frame", row)
						checkBox.Size = UDim2.new(0, 18, 0, 18)
						checkBox.Position = UDim2.new(1, -24, 0.5, -9)
						checkBox.BackgroundColor3 = checked and modeColor or Color3.fromRGB(255, 255, 255)
						checkBox.BackgroundTransparency = checked and 0.05 or 0.6
						checkBox.ZIndex = 16
						Instance.new("UICorner", checkBox).CornerRadius = UDim.new(1, 0)

						local cbStroke = Instance.new("UIStroke", checkBox)
						cbStroke.Thickness = 1.5
						cbStroke.Color = checked and modeColor or Color3.fromRGB(170, 175, 185)
						cbStroke.Transparency = checked and 0 or 0.5

						if checked then
							local tick = Instance.new("TextLabel", checkBox)
							tick.Size = UDim2.new(1, 0, 1, 0)
							tick.BackgroundTransparency = 1
							tick.Font = Enum.Font.ArialBold
							tick.TextSize = 14
							tick.Text = "✓"
							tick.TextColor3 = Color3.fromRGB(255, 255, 255)
							tick.ZIndex = 17
						end

						row.MouseButton1Click:Connect(function()
							local targetList = currentMode == "White" and CFG.Whitelist or CFG.Blacklist
							local otherList = currentMode == "White" and CFG.Blacklist or CFG.Whitelist
							if targetList[p.Name] then
								targetList[p.Name] = nil
							else
								targetList[p.Name] = true
								otherList[p.Name] = nil
							end
							rebuildList()
						end)
					end
				end

				local function buildPlayersPage(Scroll)
					local tip = Instance.new("TextLabel", Scroll)
					tip.Size = UDim2.new(1, -12, 0, 32)
					tip.BackgroundTransparency = 1
					tip.Font = Enum.Font.Gotham
					tip.TextSize = 10
					tip.TextColor3 = DynamicContext.CurrentSubTextColor
					tip.TextXAlignment = Enum.TextXAlignment.Left
					tip.TextWrapped = true
					tip.Text = "白名单跳过所有自动攻击/ESP。黑名单优先攻击。点条目最右端勾选框打勾。白/黑互斥。"
					table.insert(DynamicContext.TextElements, {Obj = tip, Type = "Sub"})

					local container = Instance.new("Frame", Scroll)
					container.Size = UDim2.new(1, -12, 0, 0)
					container.AutomaticSize = Enum.AutomaticSize.Y
					container.BackgroundTransparency = 1
					container.ZIndex = 14
					local ll = Instance.new("UIListLayout", container)
					ll.Padding = UDim.new(0, 6)
					ll.SortOrder = Enum.SortOrder.LayoutOrder

					containerRef = container
					rebuildList()

					local lastCount = -1
					task.spawn(function()
						while container.Parent do
							task.wait(2)
							if not container.Parent then break end
							local pCount = #Players:GetPlayers()
							if pCount ~= lastCount then
								lastCount = pCount
								rebuildList()
							end
						end
					end)
				end

				CreateSubSegmentNav(MainConfigCard, {"白名单", "黑名单"}, function(seg)
					currentMode = (seg == "黑名单") and "Black" or "White"
					CFG.__listEditMode = currentMode
					AnimateSubPageTransition(MainConfigCard, buildPlayersPage)
				end, initialSeg)

				AnimateSubPageTransition(MainConfigCard, buildPlayersPage)
			end
		},
		["Config"] = {
			hasSub = false,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "配置 / 主题"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local function buildThemePage(scroll)
					AddDropdown(scroll, "调色板", PaletteNames, getCurrentPaletteIndex(), function(selected) ApplyPalette(selected) end)
				end

				local function buildActionsPage(scroll)
					AddButton(scroll, "一键全部关闭", "关闭所有开关", function()
						for k, v in pairs(CFG) do
							if type(v) == "boolean" and v then
								CFG[k] = false
								if Handlers[k] then pcall(Handlers[k], false) end
								if UIToggles[k] then pcall(UIToggles[k], false, true, true) end
							end
						end
					end)
					AddButton(scroll, "清空白/黑名单", "移除所有名单记录", function()
						table.clear(CFG.Whitelist)
						table.clear(CFG.Blacklist)
						if DynamicContext.CurrentTab == "Players" then
							local tabInfo = TabData["Players"]
							if tabInfo then tabInfo.render() end
						end
					end)
					AddButton(scroll, "音乐播放器", "播放自定义音频 ID", ShowAudioModal)
				end

				CreateSubSegmentNav(MainConfigCard, {"主题", "操作"}, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "主题" then buildThemePage(scroll) else buildActionsPage(scroll) end
					end)
				end)
				AnimateSubPageTransition(MainConfigCard, buildThemePage)
			end
		},
		["Updates"] = {
			hasSub = false,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "更新公告"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local Scroll = CreateScrollList(MainConfigCard, 35)

				local TextBox = Instance.new("TextLabel", Scroll)
				TextBox.Size = UDim2.new(1, -12, 0, 1600)
				TextBox.BackgroundTransparency = 1
				TextBox.Font = Enum.Font.Gotham
				TextBox.TextSize = 11
				TextBox.TextColor3 = DynamicContext.CurrentSubTextColor
				TextBox.TextXAlignment = Enum.TextXAlignment.Left
				TextBox.TextYAlignment = Enum.TextYAlignment.Top
				TextBox.TextWrapped = true
				TextBox.Text = [[
【v3.3 更新日志】
------------------------------------------
[新增] 使用武器原始攻速（杀戮光环页）
  · 开启后直接读取当前武器的 CooldownTime 属性
  · 若无 CooldownTime 则读取 Speed 属性（1/Speed）
  · 两者都没有则回退到攻击冷却滑块
  · 完全忽略 自适应 / 多目标轮转 / Stealth 随机延迟
  · 自动攻击和光环同时生效
  · 状态栏显示"原始攻速"

[继承 v3.2 全部修复]
  · N-01~N-10 全部修复
  · findBestWeapon 深度扫描子文件夹
  · hitCooldowns 独立清理定时器
  · getTarget/collectTargets 抽取公共函数
  · Stealth 速度记录/恢复
  · BLOCK_ACTIONS 危险操作补充
  · InteractAll 二次警告
]]
				TextBox.ZIndex = 14
				table.insert(DynamicContext.TextElements, {Obj = TextBox, Type = "Sub"})
			end
		},
		["Help"] = {
			hasSub = false,
			render = function()
				ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
				DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}
				UIToggles = {}; UISliders = {}
				activeItemToggleContainer = nil

				local Title = Instance.new("TextLabel", MainConfigCard)
				Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "帮助 / 快捷键"
				Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13
				Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13
				table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})

				local function buildInfoPage(scroll)
					AddDropdown(scroll, "ESP 性能模式", {"Standard", "Adaptive"}, CFG.ESPPerfMode == "Adaptive" and 2 or 1, function(selected)
						CFG.ESPPerfMode = selected
					end)
					local perfTip = Instance.new("TextLabel", scroll)
					perfTip.Size = UDim2.new(1, -12, 0, 30)
					perfTip.BackgroundTransparency = 1
					perfTip.Font = Enum.Font.Gotham
					perfTip.TextSize = 9
					perfTip.TextColor3 = DynamicContext.CurrentSubTextColor
					perfTip.TextWrapped = true
					perfTip.TextXAlignment = Enum.TextXAlignment.Left
					perfTip.Text = "说明：视觉页的「性能模式」开关是全局粒子关闭，开启后会同时启用 FPS 分级；此下拉是 ESP 专用 FPS 分级开关。"
					table.insert(DynamicContext.TextElements, {Obj = perfTip, Type = "Sub"})

					AddSlider(scroll, "界面缩放大小", 100, 145, CFG.UIScale, "%", function(v)
						CFG.UIScale = v
						if uiScale then uiScale.Scale = v / 100 end
					end, "UIScale")

					AddToggle(scroll, "RightShift", "显示/隐藏面板", true, function() end)
					AddToggle(scroll, "点击顶部 Logo", "缩成动态岛", true, function() end)
					AddToggle(scroll, "双击动态岛", "恢复主面板", true, function() end)
				end

				local function buildKeysPage(scroll)
					local keys = {
						{"X", "杀戮光环"}, {"F", "自动攻击"}, {"V", "玩家 ESP"},
						{"B", "物品 ESP"}, {"J", "门 ESP"}, {"G", "自动交互"},
						{"K", "无限体力"}, {"L", "全亮"},
					}
					for _, kv in ipairs(keys) do AddToggle(scroll, kv[1] .. " → " .. kv[2], nil, true, function() end) end
				end

				CreateSubSegmentNav(MainConfigCard, {"信息", "快捷键"}, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "信息" then buildInfoPage(scroll) else buildKeysPage(scroll) end
					end)
				end)
				AnimateSubPageTransition(MainConfigCard, buildInfoPage)
			end
		}
	}

	local NavLayout = Instance.new("UIListLayout", NavCard)
	NavLayout.Padding = UDim.new(0, 3); NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local NavPadding = Instance.new("UIPadding", NavCard)
	NavPadding.PaddingTop = UDim.new(0, 8); NavPadding.PaddingLeft = UDim.new(0, 8); NavPadding.PaddingRight = UDim.new(0, 8)

	local Buttons = {}
	local Tabs = {"Combat", "Visuals", "Movement", "Auto", "Players", "Config", "Updates", "Help"}

	local function SwitchTabWithAnimation(tabName)
		if DynamicContext.CurrentTab == tabName then return end
		DynamicContext.CurrentTab = tabName
		for name, btnObj in pairs(Buttons) do
			if name == tabName then
				TweenService:Create(btnObj, TweenInfo.new(0.2), {BackgroundTransparency = 0.25}):Play()
				btnObj.TextColor3 = DynamicContext.CurrentTextColor
			else
				TweenService:Create(btnObj, TweenInfo.new(0.2), {BackgroundTransparency = 0.85}):Play()
				btnObj.TextColor3 = DynamicContext.CurrentSubTextColor
			end
		end

		local tabInfo = TabData[tabName]
		if tabInfo then
			local tweenOut = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tweenIn = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			
			TweenService:Create(MainConfigCard, tweenOut, {GroupTransparency = 1}):Play()
			TweenService:Create(SubConfigCard, tweenOut, {GroupTransparency = 1}):Play()

			task.delay(0.15, function()
				if DynamicContext.CurrentTab ~= tabName then return end
				AdjustLayoutMode(tabInfo.hasSub)
				tabInfo.render()
				MainConfigCard.GroupTransparency = 1
				SubConfigCard.GroupTransparency = 1
				TweenService:Create(MainConfigCard, tweenIn, {GroupTransparency = 0}):Play()
				if SubConfigCard.Visible then
					TweenService:Create(SubConfigCard, tweenIn, {GroupTransparency = 0}):Play()
				end
			end)
		end
	end

	for _, name in ipairs(Tabs) do
		local Btn = Instance.new("TextButton", NavCard)
		Btn.Size = UDim2.new(1, 0, 0, 26); Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Btn.BackgroundTransparency = 0.85; Btn.Text = name; Btn.TextColor3 = DynamicContext.CurrentSubTextColor
		Btn.Font = Enum.Font.GothamMedium; Btn.TextSize = 11; Btn.ZIndex = 13
		Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
		Buttons[name] = Btn
		Btn.MouseButton1Click:Connect(function() SwitchTabWithAnimation(name) end)
	end

	task.spawn(function()
		while task.wait(0.016) do
			DynamicContext.StrokeRotation = (DynamicContext.StrokeRotation + 2.5) % 360
			StrokeGradient.Rotation = DynamicContext.StrokeRotation
			IslandStrokeGradient.Rotation = DynamicContext.StrokeRotation
			AudioModalStrokeGradient.Rotation = DynamicContext.StrokeRotation
			InputStrokeGradient.Rotation = DynamicContext.StrokeRotation
		end
	end)

	local uiColorAccum = 0
	local UI_COLOR_INTERVAL = 0.15
	local cleanAccum = 0

	keep(RunService.RenderStepped:Connect(function(dt)
		if not MainFrame.Parent then return end

		local lerpSpeed = math.clamp(dt * 3.5, 0, 1)
		for i = 1, 5 do DynamicContext.CurrentPalette[i] = DynamicContext.CurrentPalette[i]:Lerp(DynamicContext.TargetPalette[i], lerpSpeed) end
		DynamicContext.CurrentLogoColor = DynamicContext.CurrentLogoColor:Lerp(DynamicContext.TargetLogoColor, lerpSpeed)
		DynamicContext.CurrentActiveColor = DynamicContext.CurrentActiveColor:Lerp(DynamicContext.TargetActiveColor, lerpSpeed)
		DynamicContext.CurrentTextColor = DynamicContext.CurrentTextColor:Lerp(DynamicContext.TargetTextColor, lerpSpeed)
		DynamicContext.CurrentSubTextColor = DynamicContext.CurrentSubTextColor:Lerp(DynamicContext.TargetSubTextColor, lerpSpeed)
		DynamicContext.CurrentBorderColor = DynamicContext.CurrentBorderColor:Lerp(DynamicContext.TargetBorderColor, lerpSpeed)

		if LogoBtn.Parent and not colorNearlyEqual(LogoBtn.TextColor3, DynamicContext.CurrentLogoColor, 0.03) then
			LogoBtn.TextColor3 = DynamicContext.CurrentLogoColor
		end
		if IslandLogo.Parent and not colorNearlyEqual(IslandLogo.TextColor3, DynamicContext.CurrentLogoColor, 0.03) then
			IslandLogo.TextColor3 = DynamicContext.CurrentLogoColor
		end

		uiColorAccum = uiColorAccum + dt
		if uiColorAccum >= UI_COLOR_INTERVAL then
			uiColorAccum = 0

			local ctc = DynamicContext.CurrentTextColor
			local csc = DynamicContext.CurrentSubTextColor
			local cbc = DynamicContext.CurrentBorderColor

			for _, item in ipairs(DynamicContext.TextElements) do
				if item.Obj and item.Obj.Parent then
					if item.Type == "Main" then
						if Buttons[item.Obj.Text] and item.Obj.Text == DynamicContext.CurrentTab then
							if not colorNearlyEqual(item.Obj.TextColor3, ctc, 0.03) then item.Obj.TextColor3 = ctc end
						elseif Buttons[item.Obj.Text] then
							if not colorNearlyEqual(item.Obj.TextColor3, csc, 0.03) then item.Obj.TextColor3 = csc end
						else
							if not item.Obj:GetAttribute("_HubFixedColor") then
								if not colorNearlyEqual(item.Obj.TextColor3, ctc, 0.03) then item.Obj.TextColor3 = ctc end
							end
						end
					elseif item.Type == "Sub" then
						if not colorNearlyEqual(item.Obj.TextColor3, csc, 0.03) then item.Obj.TextColor3 = csc end
					end
				end
			end

			for _, stroke in ipairs(DynamicContext.BorderElements) do
				if stroke and stroke.Parent then
					if not colorNearlyEqual(stroke.Color, cbc, 0.03) then stroke.Color = cbc end
				end
			end

			for _, tog in pairs(DynamicContext.ActiveToggles) do
				if tog.Update then pcall(tog.Update) end
			end
			for _, sld in pairs(DynamicContext.ActiveSliders) do
				if sld.Update then pcall(sld.Update) end
			end
		end

		cleanAccum = cleanAccum + dt
		if cleanAccum > 2 then
			cleanAccum = 0
			for i = #DynamicContext.TextElements, 1, -1 do
				local it = DynamicContext.TextElements[i]
				if not it.Obj or not it.Obj.Parent then table.remove(DynamicContext.TextElements, i) end
			end
			for i = #DynamicContext.BorderElements, 1, -1 do
				local s = DynamicContext.BorderElements[i]
				if not s or not s.Parent then table.remove(DynamicContext.BorderElements, i) end
			end
		end

		DynamicContext.BgPhase = DynamicContext.BgPhase + dt * 0.25
		local wave1 = (math.sin(DynamicContext.BgPhase) + 1) / 2
		local wave2 = (math.sin(DynamicContext.BgPhase * 1.3 + 1.2) + 1) / 2
		local c1 = DynamicContext.CurrentPalette[1]:Lerp(DynamicContext.CurrentPalette[2], wave1)
		local c2 = DynamicContext.CurrentPalette[2]:Lerp(DynamicContext.CurrentPalette[4], wave2)
		local c3 = DynamicContext.CurrentPalette[3]:Lerp(DynamicContext.CurrentPalette[5], wave1)
		local newSeq = ColorSequence.new({ ColorSequenceKeypoint.new(0.0, c1), ColorSequenceKeypoint.new(0.5, c2), ColorSequenceKeypoint.new(1.0, c3) })

		if MainGradient.Parent then
			MainGradient.Color = newSeq
			MainGradient.Rotation = (MainGradient.Rotation + dt * 8) % 360
		end
		if IslandGradient.Parent then
			IslandGradient.Color = newSeq
			IslandGradient.Rotation = MainGradient.Rotation
		end
	end))

	local isBallMode, autoBallTask = false, nil

	local function SmoothToBall()
		if isBallMode or not Island.Parent then return end
		isBallMode = true
		local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		IslandLogo.Visible = false; IslandStatus.Visible = false; ExpandBtn.Visible = false
		local targetOffset = (Island.Position.X.Offset + (Island.Size.X.Offset / 2)) - 18
		TweenService:Create(Island, tweenInfo, {Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(Island.Position.X.Scale, targetOffset, Island.Position.Y.Scale, Island.Position.Y.Offset)}):Play()
		if IslandCorner.Parent then TweenService:Create(IslandCorner, tweenInfo, {CornerRadius = UDim.new(1, 0)}):Play() end
	end

	local function SmoothToRectangle()
		if not isBallMode or not Island.Parent then return end
		isBallMode = false
		local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local targetOffset = (Island.Position.X.Offset + (Island.Size.X.Offset / 2)) - 100
		TweenService:Create(Island, tweenInfo, {Size = UDim2.new(0, 200, 0, 36), Position = UDim2.new(Island.Position.X.Scale, targetOffset, Island.Position.Y.Scale, Island.Position.Y.Offset)}):Play()
		if IslandCorner.Parent then TweenService:Create(IslandCorner, tweenInfo, {CornerRadius = UDim.new(0, 18)}):Play() end
		task.delay(0.2, function() if Island.Parent then IslandLogo.Visible = true; IslandStatus.Visible = true; ExpandBtn.Visible = true end end)
		if autoBallTask then task.cancel(autoBallTask) end
		autoBallTask = task.delay(3.5, SmoothToBall)
	end

	local lastClickTime = 0
	local longPressTime = 0.6
	local islandDragging, islandDragStart, islandStartPos, pressStartTime, isPressing, longPressTask = false, Vector2.new(), UDim2.new(), 0, false, nil

	keep(Island.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isPressing = true; pressStartTime = os.clock(); islandDragStart = Vector2.new(input.Position.X, input.Position.Y)
			islandStartPos = Island.Position
			if longPressTask then task.cancel(longPressTask) end
			longPressTask = task.delay(longPressTime, function()
				if isPressing and not islandDragging then
					islandDragging = true; TweenService:Create(IslandStroke, TweenInfo.new(0.2), {Thickness = 4}):Play()
				end
			end)
		end
	end))

	keep(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isPressing then
				local duration = os.clock() - pressStartTime; isPressing = false
				if longPressTask then task.cancel(longPressTask) end
				if islandDragging then
					islandDragging = false; TweenService:Create(IslandStroke, TweenInfo.new(0.2), {Thickness = 2}):Play()
				elseif duration < longPressTime then
					local currentTime = os.clock()
					if (currentTime - lastClickTime) < 0.35 then
						lastClickTime = 0
						if isBallMode then SmoothToRectangle() else SmoothToBall() end
					else
						lastClickTime = currentTime
						task.delay(0.36, function() if lastClickTime == currentTime then if isBallMode then SmoothToRectangle() end end end)
					end
				end
			end
		end
	end))

	keep(UserInputService.InputChanged:Connect(function(input)
		if islandDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - islandDragStart
			Island.Position = UDim2.new(islandStartPos.X.Scale, islandStartPos.X.Offset + delta.X, islandStartPos.Y.Scale, islandStartPos.Y.Offset + delta.Y)
		end
	end))

	local function HideMainAndShowIsland()
		local shrinkTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(MainFrame, shrinkTweenInfo, {GroupTransparency = 1, Size = UDim2.new(0, 480, 0, 290)}):Play()
		task.delay(0.25, function()
			MainFrame.Visible = false; MainFrame.Size = UDim2.new(0, 530, 0, 320)

			local curSizeX = Island.Size.X.Offset
			local curSizeY = Island.Size.Y.Offset
			local centerX = Island.Position.X.Offset + curSizeX / 2
			local centerY = Island.Position.Y.Offset + curSizeY / 2

			Island.Visible = true
			Island.GroupTransparency = 1
			Island.Size = UDim2.new(0, 140, 0, 30)
			Island.Position = UDim2.new(Island.Position.X.Scale, centerX - 70, Island.Position.Y.Scale, centerY - 15)

			if IslandCorner.Parent then IslandCorner.CornerRadius = UDim.new(0, 15) end
			isBallMode = false
			IslandLogo.Visible = true; IslandStatus.Visible = true; ExpandBtn.Visible = true

			local islandShowTween = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local targetPos = UDim2.new(Island.Position.X.Scale, centerX - 100, Island.Position.Y.Scale, centerY - 18)
			TweenService:Create(Island, islandShowTween, {GroupTransparency = 0, Size = UDim2.new(0, 200, 0, 36), Position = targetPos}):Play()
			if IslandCorner.Parent then TweenService:Create(IslandCorner, islandShowTween, {CornerRadius = UDim.new(0, 18)}):Play() end
			if autoBallTask then task.cancel(autoBallTask) end
			autoBallTask = task.delay(3, SmoothToBall)
		end)
	end

	local function HideIslandAndShowMain()
		if autoBallTask then task.cancel(autoBallTask) end
		local curSizeX = Island.Size.X.Offset
		local curSizeY = Island.Size.Y.Offset
		local centerX = Island.Position.X.Offset + curSizeX / 2
		local centerY = Island.Position.Y.Offset + curSizeY / 2
		local targetSizeX, targetSizeY = 150, 30
		local hideIslandTween = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		TweenService:Create(Island, hideIslandTween, {
			GroupTransparency = 1,
			Size = UDim2.new(0, targetSizeX, 0, targetSizeY),
			Position = UDim2.new(Island.Position.X.Scale, centerX - targetSizeX / 2, Island.Position.Y.Scale, centerY - targetSizeY / 2)
		}):Play()
		task.delay(0.2, function()
			Island.Visible = false; MainFrame.Visible = true; MainFrame.GroupTransparency = 1
			MainFrame.Size = UDim2.new(0, 490, 0, 296)
			TweenService:Create(MainFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				GroupTransparency = 0, Size = UDim2.new(0, 530, 0, 320)
			}):Play()
		end)
	end

	LogoBtn.MouseButton1Click:Connect(HideMainAndShowIsland)
	ExpandBtn.MouseButton1Click:Connect(HideIslandAndShowMain)

	MainFrame.Visible = true; MainFrame.GroupTransparency = 1
	SwitchTabWithAnimation("Combat")
	TweenService:Create(MainFrame, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()

	keep(UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
			if MainFrame.Visible then HideMainAndShowIsland() else HideIslandAndShowMain() end
		end
	end))
end)

if not success then warn("[Hub UI Load Error]: " .. tostring(err)) end

shared.__HubSet = function(key, value)
	CFG[key] = value
	if UIToggles[key] then pcall(UIToggles[key], value, false, true) end
	if UISliders[key] then pcall(UISliders[key], value) end
	if Handlers[key] then
		local ok, err = pcall(Handlers[key], value)
		if not ok then warn("[Hub] set " .. key .. ": " .. tostring(err)) end
	end
end

for key, handler in pairs(Handlers) do
	if CFG[key] then
		local ok, err = pcall(handler, true)
		if not ok then warn("[Hub] init " .. key .. ": " .. tostring(err)) end
	end
end

keep(LP.CharacterAdded:Connect(onCharacter))
if LP.Character then onCharacter(LP.Character) end

print("[Link.cc v3.3] loaded | UseWeaponSpeed added")
