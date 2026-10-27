local ENVT = nil
local function envTable()
	if ENVT then return ENVT end
	local ok, v = pcall(getgenv)
	if ok and type(v) == "table" then ENVT = v; return ENVT end
	ENVT = _G
	return ENVT
end
local function safeGet(name)
	local env = envTable()
	local ok, v = pcall(function() return env[name] end)
	if ok and v ~= nil then return v end
	local ok2, v2 = pcall(function() return _G[name] end)
	if ok2 and v2 ~= nil then return v2 end
	return nil
end
local genv
do
	local gf = safeGet("getgenv")
	if type(gf) == "function" then
		local ok, v = pcall(gf)
		if ok and type(v) == "table" then genv = v end
	end
	if not genv then genv = envTable() end
end
local COMPAT = {
	hook = safeGet("hookmetamethod"),
	restore = safeGet("restorefunction") or safeGet("restorefunction_"),
	m1press = safeGet("mouse1press"),
	m1release = safeGet("mouse1release"),
	m1click = safeGet("mouse1click"),
}
if genv.__BTRHUB then
	local OLD = genv.__BTRHUB
	pcall(function()
		if OLD.api and OLD.api.clearOrigin then OLD.api.clearOrigin() end
		if OLD.cfg then
			OLD.cfg.aimbot = false
			OLD.cfg.silentPacket = false
			OLD.cfg.packetMode = false
			OLD.cfg.autoFire = false
		end
		if OLD.destroy then OLD.destroy() end
	end)
	genv.__BTRHUB = nil
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local LP = Players.LocalPlayer
if not LP then
	for _ = 1, 120 do
		LP = Players.LocalPlayer
		if LP then break end
		task.wait(0.05)
	end
end
if not LP then return end

local Internal = {}

local HUB = {
	conns = {}, drawing = {}, destroy = nil, fps = 0, warned = false, worldOn = false,
	otherBeams = 0, otherDrawn = 0, otherSkip = 0,
	rayHits = 0, rayCasts = 0, rayLast = nil, raySkip = nil,
	maxOffsetOK = 4, offsetAccepted = 0, offsetRejected = 0,
	packetOK = 0, packetTries = 0, packetStrat = 1, packetStratFail = 0,
	packetShots = 0, packetGaveUp = false, silentIdle = 0, silentIdleAt = 0,
	reloadAt = 0, reloadNotified = false, silentPacketShots = 0, badDirs = 0,
	ammoCount = 0, packetStratOK = {}, packetStratN = {}, packetRetryAt = 0,
	renderMode = "", reserveOK = false, silentAmmo = nil, fireInterval = 0.12,
	silentAcc = 0, silentFallbackReal = false, silentWallCap = 2.5, silentObsCap = 4,
	noDamage = 0, aimPartCycle = 0, silentBypass = {}, silentNoCast = {},
	silentBypassHits = 0, ourCasts = 0, netCheckAt = 0, packetCall = 0,
	packetWarned = false, packetWarnedAt = 0,
	reloadBusy = false, api = nil, cfg = nil, stats = nil,
	lastPellets = 1, hitSends = 0, pelletOverride = nil, mainFrame = nil,
	netReady = true, lastHitAt = 0,
}
genv.__BTRHUB = HUB

local PALETTE = {
	Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(255, 220, 0), Color3.fromRGB(90, 255, 90),
	Color3.fromRGB(0, 230, 255), Color3.fromRGB(60, 120, 255),
	Color3.fromRGB(200, 80, 255), Color3.fromRGB(255, 255, 255),
}

local CFG = {
	espPlayers = true, espMonsters = true, espItems = true, espAmmo = true, espFriends = true,
	showSelf = false, box = true, name = true, health = true, distance = true, tracer = true,
	maxDist = 500,
	colorPlayer = Color3.fromRGB(70, 255, 110), colorFriend = Color3.fromRGB(255, 105, 180),
	colorMonster = PALETTE[1], colorBoss = PALETTE[7], colorItem = PALETTE[3],
	colorAmmo = Color3.fromRGB(0, 255, 200),
	aimbot = false, silent = true, autoFire = false,
	aimPart = "Head", fov = 600, visibleOnly = true,
	aimMonsters = true, aimPlayers = false, aimSmartPart = true, aim360 = true,
	fovAngle = 180, dropComp = true, spoofCam = true,
	noShield = false, muzzleOffset = true, muzzleRadius = 4, muzzleStep = 0.5,
	silentWallOffset = 2.5, silentObsOffset = 4,
	packetMode = false,
	debugLog = false,
	hotkeyEnabled = true,
	islandClickExpand = true,
	islandLongPressDrag = true,
	silentPacket = false,
	silentReal = false,          
	autoReload = true,           
	trail = true, trailTime = 5, muzzleTrail = true,
	trailColor = Color3.fromRGB(255, 190, 60),
	otherTrails = true, colorTeamTrail = Color3.fromRGB(70, 255, 110),
	colorEnemyTrail = Color3.fromRGB(255, 45, 45),
	noFog = false, mapGlow = false, infStamina = false, customWalkSpeed = false, walkSpeed = 24, customJumpPower = false, jumpPower = 60,
	noFall = false, fallSpeed = 45,
	camUnlock = false, camForceThird = false, camBodyVisible = true,
	camMinZoom = 0.5, camMaxZoom = 200, camForceMin = 8,
	camLock = false, camLockMode = "fixed", camFreeze = false,
}

local STATS = genv.__BTRHUB_STATS
if not STATS then
	STATS = { fires = 0, hits = 0, target = "-", hitCalls = 0 }
	genv.__BTRHUB_STATS = STATS
end
STATS.target = "-"
STATS.hitCalls = STATS.hitCalls or 0

local Aim = {
	point = nil, target = nil, gunCfg = nil, occluded = false, part = nil,
	origin = nil, originAt = 0, muzzle = nil, offsetUsed = nil, offsetDir = nil,
	forceOrigin = nil, muzzleAt = 0, muzzleBlocked = false, lastOffset = nil,
	hadOrigin = false, shotOK = false, shotDist = 0, offsetKind = nil,
	packetMuzzle = nil, packetTarget = nil,
}

local losClearFrom, getRealMuzzle, resolveMuzzleShot, findFiringOrigin

local function w2s(pos)
	local cam = workspace.CurrentCamera
	if not cam then return Vector2.new(), false end
	local ok, sp = pcall(function() return cam:WorldToViewportPoint(pos) end)
	if ok and sp then
		return Vector2.new(sp.X, sp.Y), (sp.Z > 0)
	end
	return Vector2.new(), false
end
local function rayParams(exclude)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = exclude
	rp.IgnoreWater = true
	rp.RespectCanCollide = false
	return rp
end
local function getMyChar()
	local c = LP.Character
	if c and c.Parent then return c end
	return nil
end
local function getMyHumanoid()
	local c = getMyChar()
	return c and c:FindFirstChildOfClass("Humanoid") or nil
end
local function getEquippedGun()
	local c = getMyChar()
	if not c then return nil end
	for _, v in ipairs(c:GetChildren()) do
		if v:IsA("Tool") and v:GetAttribute("IsGun") == true then return v end
	end
	return nil
end

local gunCfgCache = setmetatable({}, { __mode = "k" })
local function getGunConfig(tool)
	if not tool then return nil end
	local hit = gunCfgCache[tool]
	if hit then return hit end
	local found
	for _, c in ipairs(tool:GetChildren()) do
		if c:IsA("ModuleScript") then
			local nm = string.lower(c.Name)
			local nameOk = (c.Name == "")
				or string.find(nm, "config", 1, true) ~= nil
				or string.find(nm, "gun", 1, true) ~= nil
				or string.find(nm, "weapon", 1, true) ~= nil
				or string.find(nm, "fire", 1, true) ~= nil
			if nameOk then
				local ok, r = pcall(require, c)
				if ok and type(r) == "table" and r.fire and r.ammo then found = r; break end
			end
		end
	end
	if not found then
		for _, c in ipairs(tool:GetChildren()) do
			if c:IsA("ModuleScript") then
				local ok, r = pcall(require, c)
				if ok and type(r) == "table" and r.fire and r.ammo then found = r; break end
			end
		end
	end
	if found then gunCfgCache[tool] = found end
	return found
end

local Network
local function getNetwork()
	if Network then return Network end
	local ok, m = pcall(require, RS.Assets.Modules.Network)
	if ok and type(m) == "table" then Network = m; return m end
	return nil
end

local spawnTrail, spawnImpact
local trailBudget = {}

local function onFirePacket(tool, cfg, dir) STATS.fires = STATS.fires + 1 end
local function onHitPacket(hit, tool, cfg, payload)
	if hit then
		STATS.hits = STATS.hits + 1
		HUB.lastHitAt = os.clock()
	end
	if not CFG.trail or not CFG.muzzleTrail then return end
	if type(payload) == "table" and typeof(payload[3]) == "Vector3" then
		spawnImpact(payload[3])
	end
end

local NB = nil
local function installNetHooks()
	if NB then return end
	local net = getNetwork()
	if not net then return end
	local ORIG = genv.__BTRHUB_NET_ORIG
	if ORIG and ORIG.net == net then
		pcall(function() net.FireServer = ORIG.FireServer end)
		pcall(function() net.InvokeServer = ORIG.InvokeServer end)
	end
	genv.__BTRHUB_NET_ORIG = { net = net, FireServer = net.FireServer, InvokeServer = net.InvokeServer }
	NB = { onFire = nil, onHit = nil, net = net }
	genv.__BTRHUB_NET = NB

	local oldFire = net.FireServer
	net.FireServer = function(self, channel, ...)
		if channel == "fire" then
			local a = table.pack(...)
			if NB.onFire then pcall(NB.onFire, a[1], a[2], a[3]) end
			if (CFG.aimbot or CFG.silentPacket or CFG.packetMode) and Aim.point and typeof(a[3]) == "Vector3" then
				local base = nil
				if (Aim.offsetUsed or 0) > 0 and typeof(Aim.muzzle) == "Vector3" then
					base = Aim.muzzle
				else
					local cam = workspace.CurrentCamera
					base = cam and cam.CFrame.Position or nil
				end
				if base then
					local nd = Aim.point - base
					if nd.Magnitude > 0.1 then return oldFire(self, channel, a[1], a[2], nd.Unit) end
				end
			end
			return oldFire(self, channel, ...)
		end
		if channel == "cam/mouse" and (CFG.aimbot or CFG.silentPacket or CFG.packetMode) and CFG.spoofCam and Aim.point then
			local cam = workspace.CurrentCamera
			if cam then
				local base = cam.CFrame.Position
				local cf = CFrame.lookAt(base, Aim.point)
				return oldFire(self, channel, cf, { base, Aim.point })
			end
		end
		return oldFire(self, channel, ...)
	end

	local oldInvoke = net.InvokeServer
	net.InvokeServer = function(self, channel, ...)
		if channel == "hit" or channel == "fleshHit" or channel == "droneHit" then
			STATS.hitCalls = (STATS.hitCalls or 0) + 1
			local args = table.pack(...)
			if channel == "hit" and type(args[3]) == "table" then
				local pl = args[3]
				local m = Aim.packetMuzzle or Aim.origin
				local hp = pl[3]
				local hum = pl[1]
				local charInst = (typeof(hum) == "Instance" and hum:IsA("Humanoid")) and hum.Parent or nil
				local sameTarget = (not Aim.packetTarget) or (not charInst) or (Aim.packetTarget == charInst)
				if typeof(m) == "Vector3" and typeof(pl[5]) == "Vector3" and sameTarget
					and (Aim.offsetUsed or 0) > 0 then
					local real = getRealMuzzle()
					local md = real and (m - real).Magnitude or 0
					if (m - pl[5]).Magnitude > 0.75 and md <= 14
						and (typeof(hp) ~= "Vector3" or not charInst or losClearFrom(m, hp, charInst)) then
						pl[5] = m
					end
				end
			end
			local r = table.pack(oldInvoke(self, channel, table.unpack(args, 1, args.n)))
			if channel == "hit" then
				local used = Aim.offsetUsed or 0
				local kind = Aim.offsetKind
				if used > 0 then
					if r[1] then
						HUB.offsetAccepted = (HUB.offsetAccepted or 0) + 1
						if used > (HUB.maxOffsetOK or 0) then HUB.maxOffsetOK = used end
					else
						HUB.offsetRejected = (HUB.offsetRejected or 0) + 1
						if kind == "wall" then
							HUB.silentWallCap = math.max(1, math.min(HUB.silentWallCap or 2.5, used - 0.5))
						elseif kind == "obstacle" then
							HUB.silentObsCap = math.max(1, math.min(HUB.silentObsCap or 4, used - 0.5))
						else
							HUB.maxOffsetOK = math.max(1, math.min(HUB.maxOffsetOK or used, used - 0.5))
						end
						Aim.lastOffset = nil
					end
				end
			end
			if NB.onHit then pcall(NB.onHit, r[1], args[1], args[2], args[3]) end
			return table.unpack(r, 1, r.n)
		end
		return oldInvoke(self, channel, ...)
	end
end
spawnTrail = function(from, to, duration, flash, color)
	if (to - from).Magnitude < 1 then return end
	duration = duration or CFG.trailTime
	color = color or CFG.trailColor
	if #trailBudget > 420 then
		local old = table.remove(trailBudget, 1)
		if old and old.Parent then old:Destroy() end
	end
	local part = Instance.new("Part")
	part.Name = "__btrTrail"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.045, 0.045, (to - from).Magnitude)
	part.CFrame = CFrame.lookAt(from + (to - from) * 0.5, to)
	part.Transparency = 0.1
	part.Parent = workspace.Terrain
	table.insert(trailBudget, part)
	Tween:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	Debris:AddItem(part, duration + 0.2)

	if CFG.muzzleTrail and flash ~= false then
		local m = Instance.new("Part")
		m.Name = "__btrMuzzle"
		m.Shape = Enum.PartType.Ball
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.CastShadow = false
		m.Material = Enum.Material.Neon
		m.Color = color
		m.Size = Vector3.new(0.34, 0.34, 0.34)
		m.CFrame = CFrame.new(from)
		m.Transparency = 0.05
		m.Parent = workspace.Terrain
		table.insert(trailBudget, m)
		Tween:Create(m, TweenInfo.new(duration * 0.95, Enum.EasingStyle.Quad), {
			Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05),
		}):Play()
		Debris:AddItem(m, duration + 0.2)
	end
end

spawnImpact = function(pos)
	if #trailBudget > 420 then
		local old = table.remove(trailBudget, 1)
		if old and old.Parent then old:Destroy() end
	end
	local p = Instance.new("Part")
	p.Name = "__btrImpact"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 90, 90)
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.CFrame = CFrame.new(pos)
	p.Transparency = 0.1
	p.Parent = workspace.Terrain
	table.insert(trailBudget, p)
	Tween:Create(p, TweenInfo.new(CFG.trailTime, Enum.EasingStyle.Quad), {
		Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05),
	}):Play()
	Debris:AddItem(p, CFG.trailTime + 0.2)
end

local shieldCache = {}
local lastShieldScan = 0
local lastFlash = 0

local function scanShields()
	local list = {}
	local ch = getMyChar()
	local chars = workspace:FindFirstChild("Characters")
	if not chars then return list end
	for _, m in ipairs(chars:GetChildren()) do
		if m ~= ch then
			for _, t in ipairs(m:GetChildren()) do
				if t:IsA("Tool") then list[#list + 1] = t end
			end
		end
	end
	return list
end

local RAY = genv.__BTRHUB_RAY
if not RAY then RAY = {}; genv.__BTRHUB_RAY = RAY end

RAY.restore = function()
	if RAY.mod then
		if RAY.oldNew then pcall(function() RAY.mod.new = RAY.oldNew end) end
		if RAY.oldFire then pcall(function() RAY.mod.Fire = RAY.oldFire end) end
	end
	RAY.mod = nil
	RAY.oldNew = nil
	RAY.oldFire = nil
	RAY.ready = false
end

local function ensureRaycastWrapped()
	local mod = RS.Assets.Modules:FindFirstChild("Raycast")
	if not mod then return false end
	local okm, RaycastMod = pcall(require, mod)
	if not (okm and type(RaycastMod) == "table") then return false end
	if RAY.mod == RaycastMod then return true end
	if RAY.mod and RAY.oldNew then pcall(function() RAY.mod.new = RAY.oldNew end) end
	if RAY.mod and RAY.oldFire then pcall(function() RAY.mod.Fire = RAY.oldFire end) end
	local oldNew = RaycastMod.new
	local oldFire = RaycastMod.Fire
	RAY.oldNew = oldNew
	RAY.oldFire = oldFire
	RAY.mod = RaycastMod
	RaycastMod.new = function(self, ...)
		local cast = oldNew(self, ...)
		RAY.casts = (RAY.casts or 0) + 1
		pcall(function()
			cast.RayHit:Connect(function(c, result)
				if RAY.onHit then RAY.onHit(c, result) end
			end)
			cast.RayPierced:Connect(function(c, result, vel)
				if RAY.onPierce then RAY.onPierce(c, result, vel) end
			end)
		end)
		return cast
	end
	RaycastMod.Fire = function(self, origin, dir, speed, behavior)
		if RAY.onOrigin then
			local okO, no = pcall(RAY.onOrigin, origin, dir)
			if okO and typeof(no) == "Vector3" then origin = no end
		end
		if RAY.onAim then
			local okAim, nd = pcall(RAY.onAim, origin, dir)
			if okAim and typeof(nd) == "Vector3" then dir = nd end
		end
		if typeof(dir) == "Vector3" then
			local len = dir.Magnitude
			if len ~= len or len < 0.001 or len > 1e9 then
				HUB.badDirs = (HUB.badDirs or 0) + 1
				dir = Vector3.new(0, 0, -1)
			end
		end
		local cast = oldFire(self, origin, dir, speed, behavior)
		pcall(function()
			if cast then
				cast.__btrOrigin = origin
				cast.__btrLast = origin
			end
			if RAY.onCast then RAY.onCast(cast) end
		end)
		return cast
	end
	RAY.ready = true
	return true
end

ensureRaycastWrapped()

local function installRayHooks()
	pcall(ensureRaycastWrapped)
	RAY.onOrigin = function(origin, dir)
		if not (CFG.aimbot or CFG.packetMode or CFG.silentPacket) then return nil end
		local o = Aim.origin
		if typeof(o) ~= "Vector3" then return nil end
		local real = getRealMuzzle()
		if real and (o - real).Magnitude > 20 then return nil end
		return o
	end
	RAY.onAim = function(origin, dir)
		RAY.fires = (RAY.fires or 0) + 1
		if Aim.shotOK and typeof(origin) == "Vector3" and typeof(Aim.muzzle) == "Vector3"
			and (origin - Aim.muzzle).Magnitude < 3.5 then
			HUB.ourCasts = (HUB.ourCasts or 0) + 1
		end
		if not (CFG.aimbot or CFG.packetMode or CFG.silentPacket) then return nil end
		local p = Aim.point
		if not p or typeof(origin) ~= "Vector3" then return nil end
		local cfg = Aim.gunCfg
		if CFG.dropComp and cfg and type(cfg.fire) == "table" then
			local speed = cfg.fire.fireSpeed or 3000
			local acc = cfg.fire.acceleration
			local ay = (typeof(acc) == "Vector3") and acc.Y or -50
			local d = (p - origin).Magnitude
			local tt = d / math.max(speed, 1)
			p = p + Vector3.new(0, -0.5 * ay * tt * tt, 0)
		end
		local v = p - origin
		if v.Magnitude < 0.05 then return nil end
		return v.Unit
	end
	RAY.onPierce = function(c, result)
		if not CFG.trail then return end
		if not (c and result) then return end
		local from = c.__btrLast or c.__btrOrigin
		if typeof(from) ~= "Vector3" or typeof(result.Position) ~= "Vector3" then return end
		c.__btrLast = result.Position
		spawnTrail(from, result.Position, nil, false)
	end
	RAY.onHit = function(c, result)
		RAY.hits = (RAY.hits or 0) + 1
		HUB.rayHits = RAY.hits
		if not CFG.trail then HUB.raySkip = "trail"; return end
		if not (c and result) then HUB.raySkip = "args"; return end
		local origin = c.__btrLast or c.__btrOrigin or (c.RayInfo and c.RayInfo.Origin)
		c.__btrLast = result.Position
		if typeof(origin) ~= "Vector3" or typeof(result.Position) ~= "Vector3" then
			HUB.raySkip = "origin"
			return
		end
		local now = os.clock()
		local flash = (now - lastFlash) > 0.03
		if flash then lastFlash = now end
		pcall(spawnTrail, origin, result.Position, nil, flash)
	end
	RAY.onCast = function(cast)
		if not CFG.noShield then return end
		local p = cast and cast.RayInfo and cast.RayInfo.Parameters
		if not p then return end
		local list = {}
		for _, v in ipairs(p.FilterDescendantsInstances) do
			if v then list[#list + 1] = v end
		end
		for _, t in ipairs(shieldCache) do
			if t.Parent then list[#list + 1] = t end
		end
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = list
	end
end

local function isAlive(hum) return hum and hum.Health > 0 end

local BOSS_NAMES = {
	Chimera = true, Gilbert = true, Slasher = true, Mutant = true, Riser = true,
	Vorax = true, Lurker = true, Deceiver = true, ViralSin = true, Bulldozer = true,
	Mikhail = true, Shielder = true,
}
local function classifyMonster(model, hum)
	local base = model.Name:gsub("%d+$", "")
	if BOSS_NAMES[base] or (hum.MaxHealth and hum.MaxHealth >= 500) then return "boss" end
	return "monster"
end

local monsterCache = {}
local lastMonsterScan = 0
local function scanMonsters()
	local out = {}
	local chars = workspace:FindFirstChild("Characters")
	if not chars then return out end
	for _, m in ipairs(chars:GetChildren()) do
		if m:FindFirstChildOfClass("Humanoid") then
			out[#out + 1] = m
		else
			for _, c in ipairs(m:GetChildren()) do
				if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then out[#out + 1] = c end
			end
		end
	end
	return out
end

local function otherShotTrail(beam)
	HUB.otherBeams = (HUB.otherBeams or 0) + 1
	task.spawn(function()
		local p0, p1
		for _ = 1, 6 do
			task.wait(0.02)
			if not beam.Parent then return end
			local a0, a1 = beam.Attachment0, beam.Attachment1
			if a0 and a1 then
				p0, p1 = a0.WorldPosition, a1.WorldPosition
				if (p1 - p0).Magnitude >= 2 then break end
			end
		end
		if not (p0 and p1) then return end
		if (p1 - p0).Magnitude < 2 then return end
		local myChar = getMyChar()
		local shooter, bestD
		for _, m in ipairs(monsterCache) do
			if m.Parent then
				local rp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m.PrimaryPart
				if rp then
					local d = (rp.Position - p0).Magnitude
					if not bestD or d < bestD then bestD, shooter = d, m end
				end
			end
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			if c and c ~= myChar then
				local rp = c:FindFirstChild("HumanoidRootPart")
				if rp then
					local d = (rp.Position - p0).Magnitude
					if not bestD or d < bestD then bestD, shooter = d, c end
				end
			end
		end
		if not shooter or (bestD or 999) > 14 or shooter == myChar then
			HUB.otherSkip = (HUB.otherSkip or 0) + 1
			return
		end
		local isPlayer = Players:GetPlayerFromCharacter(shooter) ~= nil
		HUB.otherDrawn = (HUB.otherDrawn or 0) + 1
		spawnTrail(p0, p1, CFG.trailTime, false,
			isPlayer and CFG.colorTeamTrail or CFG.colorEnemyTrail)
	end)
end

table.insert(HUB.conns, workspace.Terrain.ChildAdded:Connect(function(v)
	if not CFG.otherTrails then return end
	if v:IsA("Beam") then otherShotTrail(v) end
end))

local friendCache = {}
local friendPending = {}
local NEUTRAL_PLAYER_COLOR = Color3.fromRGB(160, 160, 175)

local function isFriend(pl)
	local v = friendCache[pl.UserId]
	if v ~= nil then return v end
	if not friendPending[pl.UserId] then
		friendPending[pl.UserId] = true
		task.spawn(function()
			local ok, res = pcall(function() return LP:IsFriendsWith(pl.UserId) end)
			friendCache[pl.UserId] = (ok and res) and true or false
			friendPending[pl.UserId] = nil
		end)
	end
	return false
end

Players.PlayerRemoving:Connect(function(pl)
	friendCache[pl.UserId] = nil
	friendPending[pl.UserId] = nil
end)

local function buildTargets()
	local list = {}
	local myChar = getMyChar()
	local cam = workspace.CurrentCamera
	if not cam or not myChar then return list end
	local origin = cam.CFrame.Position

	if CFG.espPlayers or CFG.aimPlayers then
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= LP or CFG.showSelf then
				local ch = pl.Character
				local hum = ch and ch:FindFirstChildOfClass("Humanoid")
				if ch and isAlive(hum) then
					local head = ch:FindFirstChild("Head")
					local root = ch:FindFirstChild("HumanoidRootPart")
					if head and root then
						local d = (head.Position - origin).Magnitude
						if d <= CFG.maxDist then
							local isFr = isFriend(pl)
							local pending = friendPending[pl.UserId] == true
							local col
							if isFr then col = CFG.colorFriend
							elseif pending then col = NEUTRAL_PLAYER_COLOR
							else col = CFG.colorPlayer end
							list[#list + 1] = {
								inst = ch, hum = hum, head = head, root = root,
								kind = "player", isPlayer = true, friend = isFr,
								isSelf = (pl == LP),
								color = col,
								label = (isFr and "[好友] " or "") .. pl.Name, dist = d,
								part = nil, visible = false, visiblePart = nil,
							}
						end
					end
				end
			end
		end
	end

	if CFG.espMonsters or (CFG.aimbot and CFG.aimMonsters) then
		for _, m in ipairs(monsterCache) do
			if m.Parent and m ~= myChar and not Players:GetPlayerFromCharacter(m) then
				local hum = m:FindFirstChildOfClass("Humanoid")
				if isAlive(hum) then
					local head = m:FindFirstChild("Head")
					local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m.PrimaryPart
					if root then
						local d = ((head and head.Position or root.Position) - origin).Magnitude
						if d <= CFG.maxDist then
							local kind = classifyMonster(m, hum)
							list[#list + 1] = {
								inst = m, hum = hum, head = head or root, root = root,
								kind = kind, isPlayer = false, isSelf = false,
								color = kind == "boss" and CFG.colorBoss or CFG.colorMonster,
								label = m.Name, dist = d,
								part = nil, visible = false, visiblePart = nil,
							}
						end
					end
				end
			end
		end
	end
	return list
end

local itemCache = {}
local ITEM_PATTERNS = {
	"Ammo", "Crate", "Loot", "Medkit", "Morphine", "Bandage", "C4", "Landmine",
	"Glowstick", "Chemlight", "Keycard", "Intel", "Sample", "Battery", "Food",
	"Water", "NVG", "Case", "Supply", "Pickup", "Weapon", "Tool", "Objective",
}
local function nameMatchesItem(n)
	for _, p in ipairs(ITEM_PATTERNS) do
		if n:find(p, 1, true) then return true end
	end
	return false
end
local function isAmmoName(n)
	local l = string.lower(n)
	return l == "ammobox" or l == "ammo box" or l == "ammoboxgiver"
		or string.find(l, "ammobox", 1, true) ~= nil
end
local function scanItems()
	local out, seen = {}, {}
	local function consider(v)
		if seen[v] then return end
		seen[v] = true
		if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then return end
		if not (v:IsA("Tool") or v:IsA("Model") or v:IsA("BasePart")) then return end
		local nm = v.Name
		if nm:sub(1, 2) == "__" then return end
		if isAmmoName(nm) then return end
		if nameMatchesItem(nm) or v:GetAttribute("IsLandmine") or v:GetAttribute("IsPickup") then
			local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
			if part then out[#out + 1] = { inst = v, part = part, label = nm } end
		end
	end
	local BUDGET = 15000
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name ~= "Map" and c.Name ~= "Terrain" and c.Name ~= "Characters" then
			consider(c)
			for _, cc in ipairs(c:GetDescendants()) do
				if BUDGET <= 0 then break end
				BUDGET = BUDGET - 1
				consider(cc)
			end
		end
	end
	itemCache = out
end

local ammoCache = {}
local ammoSeen = setmetatable({}, { __mode = "k" })
local function pruneAmmoCache()
	for i = #ammoCache, 1, -1 do
		local it = ammoCache[i]
		if not it.inst or not it.inst.Parent then
			table.remove(ammoCache, i)
		end
	end
end
local function isGiverName(n) return string.find(string.lower(n), "giver", 1, true) ~= nil end
local function hasAmmoAncestor(m)
	local cur = m.Parent
	while cur and cur ~= workspace do
		if cur:IsA("Model") then
			local l = string.lower(cur.Name)
			if string.find(l, "giver", 1, true) or string.find(l, "ammo", 1, true) then return true end
		end
		cur = cur.Parent
	end
	return false
end
local function inInteractions(m)
	local cur = m.Parent
	while cur and cur ~= workspace do
		if cur.Name == "Interactions" then return true end
		cur = cur.Parent
	end
	return false
end
local function addAmmoHost(m)
	if not m or not m:IsA("Model") then return end
	if hasAmmoAncestor(m) then return end
	local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
	local giver = isGiverName(m.Name)
	local region = inInteractions(m)
	if not prompt and not giver and not region then return end
	local part = m:FindFirstChildWhichIsA("BasePart", true)
	local pivot = nil
	if not part then
		local ok, pv = pcall(function() return m:GetPivot().Position end)
		if ok then pivot = pv end
	end
	if not part and not pivot then return end
	local att = nil
	if prompt then
		local pp = prompt.Parent
		if pp and pp:IsA("Attachment") then att = pp end
	end
	local label = prompt and "弹药" or (giver and "弹药" or "弹药点")
	if ammoSeen[m] then
		for _, a in ipairs(ammoCache) do
			if a.inst == m then
				if part then a.part = part end
				if pivot then a.pivot = pivot end
				if prompt then a.prompt = prompt end
				if att then a.att = att end
				if prompt then a.label = "弹药" end
				return
			end
		end
		return
	end
	ammoSeen[m] = true
	ammoCache[#ammoCache + 1] = {
		inst = m, part = part, att = att, prompt = prompt, label = label, pivot = pivot,
	}
	HUB.ammoCount = #ammoCache
end
local function ancestorAmmoHost(v)
	local cur = v
	while cur and cur ~= workspace do
		if cur:IsA("Model") then
			if isGiverName(cur.Name) or (string.lower(cur.Name) == "ammo box") then return cur end
		end
		cur = cur.Parent
	end
	return nil
end
local function scanAmmo()
	pruneAmmoCache()
	ammoCache = {}
	ammoSeen = setmetatable({}, { __mode = "k" })
	local stack = {}
	for _, c in ipairs(workspace:GetChildren()) do
		if c ~= workspace.CurrentCamera and c.Name ~= "Characters" and c.Name ~= "Terrain" then
			stack[#stack + 1] = c
		end
	end
	local budget = 120000
	while #stack > 0 and budget > 0 do
		local v = table.remove(stack)
		budget = budget - 1
		if v.Parent then
			if v:IsA("Model") and (isGiverName(v.Name) or string.lower(v.Name) == "ammo box") then
				addAmmoHost(v)
			end
			for _, ch in ipairs(v:GetChildren()) do stack[#stack + 1] = ch end
		end
	end
	HUB.ammoCount = #ammoCache
end

table.insert(HUB.conns, workspace.DescendantAdded:Connect(function(v)
	if not (v:IsA("BasePart") or v:IsA("ProximityPrompt") or v:IsA("Model")) then return end
	task.defer(function()
		local host = ancestorAmmoHost(v)
		if host then addAmmoHost(host) end
	end)
end))

table.insert(HUB.conns, workspace.DescendantAdded:Connect(function(v)
	pcall(function()
		if not (v:IsA("Tool") or v:IsA("Model")) then return end
		if v:FindFirstChildOfClass("Humanoid") then return end
		local nm = v.Name
		if nm == "" or nm:sub(1, 2) == "__" then return end
		if not (nameMatchesItem(nm) or v:GetAttribute("IsLandmine") or v:GetAttribute("IsPickup")) then return end
		local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
		if part then table.insert(itemCache, { inst = v, part = part, label = nm }) end
	end)
end))

local function installAimHook() end
local function removeAimHook() end

local Fire = { down = false }
local VIM = game:FindFirstChild("VirtualInputManager") or game:GetService("VirtualInputManager")

local function vpCenter()
	local cam = workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		return math.floor(v.X * 0.5), math.floor(v.Y * 0.5)
	end
	return 400, 300
end

local function nearestMonster(maxDist)
	local me = getMyChar()
	if not me then return nil end
	local origin = me:FindFirstChild("HumanoidRootPart")
	if not origin then return nil end
	local best, bd
	for _, t in ipairs(buildTargets()) do
		if not t.isPlayer and not t.isSelf and (not bd or t.dist < bd) and t.dist <= (maxDist or 250) then
			bd = t.dist; best = t
		end
	end
	return best
end

local PACKET_STRATS = {
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos, ctx.normal, ctx.origin, ctx.dir, ctx.rel } end,
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos, ctx.normal, ctx.origin, ctx.dir } end,
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos } end,
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos, ctx.normal, ctx.origin, ctx.dir, ctx.rel, 1 } end,
}

getRealMuzzle = function()
	local gun = getEquippedGun()
	if gun then
		local fp = gun:FindFirstChild("FirePoint", true)
		if fp and fp:IsA("Attachment") then return fp.WorldPosition end
		local hd = gun:FindFirstChild("Handle")
		if hd and hd:IsA("BasePart") then return hd.Position end
	end
	local ch = getMyChar()
	local head = ch and ch:FindFirstChild("Head")
	if head then return head.Position end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or nil
end

local toastGui, toastLabel, toastUntil = nil, nil, 0
local function toastParent()
	local ok, p = pcall(function()
		local gh = safeGet("gethui") or safeGet("get_hidden_gui")
		if gh then
			local r = gh()
			if typeof(r) == "Instance" then return r end
		end
		return CoreGui
	end)
	return (ok and p) or CoreGui
end
local function toast(msg, secs)
	pcall(function()
		if not toastGui or not toastGui.Parent then
			toastGui = Instance.new("ScreenGui")
			toastGui.Name = "__btrToast"
			toastGui.IgnoreGuiInset = true
			toastGui.ResetOnSpawn = false
			toastGui.DisplayOrder = 1000
			toastGui.Parent = toastParent()
			toastLabel = Instance.new("TextLabel")
			toastLabel.Name = "msg"
			toastLabel.AnchorPoint = Vector2.new(0.5, 1)
			toastLabel.Position = UDim2.new(0.5, 0, 0.82, 0)
			toastLabel.Size = UDim2.new(0, 420, 0, 40)
			toastLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			toastLabel.BackgroundTransparency = 0.08
			toastLabel.BorderSizePixel = 0
			toastLabel.Font = Enum.Font.GothamMedium
			toastLabel.TextSize = 15
			toastLabel.TextColor3 = Color3.fromRGB(60, 60, 75)
			toastLabel.Text = ""
			toastLabel.Visible = false
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 14)
			corner.Parent = toastLabel
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Transparency = 0.5
			stroke.Color = Color3.fromRGB(220, 225, 235)
			stroke.Parent = toastLabel
			toastLabel.Parent = toastGui
		end
		toastLabel.Text = msg
		toastLabel.Visible = true
		toastUntil = os.clock() + (secs or 2)
	end)
end
local function toastTick()
	if toastLabel and toastLabel.Visible and os.clock() >= toastUntil then
		toastLabel.Visible = false
	end
end

local Cam = {
	bound = false, name = "__btrCameraApply",
	origMode = nil, origMin = nil, origMax = nil, origTaken = false,
	lastBodyAt = 0, wasOn = false, lastReason = "-",
	snapUntil = 0, snapDist = 0.5,
	lockPitch = nil, lockYaw = nil, lockCharYaw = nil,
	locked = false, lockDist = 0, lockAt = 0, lockModeUsed = "-",
	mouseApplied = false, mouseOrigIcon = nil,
}
local function camTakeOriginals()
	if Cam.origTaken then return end
	Cam.origTaken = true
	pcall(function()
		Cam.origMode = LP.CameraMode
		Cam.origMin = LP.CameraMinZoomDistance
		Cam.origMax = LP.CameraMaxZoomDistance
	end)
end
local function camRestoreOriginals()
	if not Cam.origTaken then return end
	pcall(function()
		if Cam.origMax then LP.CameraMaxZoomDistance = Cam.origMax end
		if Cam.origMin then LP.CameraMinZoomDistance = Cam.origMin end
		if Cam.origMode then LP.CameraMode = Cam.origMode end
	end)
end
local function camBodyReveal()
	local ch = LP.Character
	if not ch then return 0 end
	local n = 0
	for _, d in ipairs(ch:GetDescendants()) do
		if d:IsA("BasePart") then
			if (d.LocalTransparencyModifier or 0) > 0.001 then
				d.LocalTransparencyModifier = 0
				n = n + 1
			end
		end
	end
	return n
end
local function camYawOf(v)
	if v.Magnitude < 1e-4 then return 0 end
	return math.atan2(-v.X, -v.Z)
end
local function camCaptureLook()
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local lv = cam.CFrame.LookVector
	if lv.Magnitude < 0.1 then return false end
	lv = lv.Unit
	Cam.lockPitch = math.asin(math.clamp(lv.Y, -1, 1))
	Cam.lockYaw = camYawOf(lv)
	local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	Cam.lockCharYaw = camYawOf(root and root.CFrame.LookVector or lv)
	Cam.lockAt = os.clock()
	return true
end
local function camApplyLock(cam)
	local ch = LP.Character
	local head = ch and ch:FindFirstChild("Head")
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not (head and root and cam) then
		Cam.locked = false
		return
	end
	local dist = (cam.CFrame.Position - head.Position).Magnitude
	Cam.lockDist = dist
	if dist <= 1.5 then
		Cam.locked = false
		Cam.lastReason = "第一人称不锁视角"
		return
	end
	if Cam.lockPitch == nil then
		if not camCaptureLook() then
			Cam.locked = false
			return
		end
	end
	local yaw
	if CFG.camLockMode == "person" then
		local charYaw = camYawOf(root.CFrame.LookVector)
		local base = Cam.lockCharYaw or charYaw
		local delta = charYaw - base
		while delta > math.pi do delta = delta - math.pi * 2 end
		while delta < -math.pi do delta = delta + math.pi * 2 end
		yaw = Cam.lockYaw + delta
		Cam.lockModeUsed = "跟随人物"
	else
		yaw = Cam.lockYaw
		Cam.lockModeUsed = "固定朝向"
	end
	local dir = CFrame.fromEulerAnglesYXZ(Cam.lockPitch, yaw, 0).LookVector
	local pos = cam.CFrame.Position
	cam.CFrame = CFrame.lookAt(pos, pos + dir)
	Cam.locked = true
	Cam.lastReason = "锁定视角(" .. Cam.lockModeUsed .. ")"
end
local function camApplyMouseLock(third)
	if not CFG.camLock then
		if Cam.mouseApplied then
			Cam.mouseApplied = false
			pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
		end
		return
	end
	local allow = third
	if HUB.mainFrame and HUB.mainFrame.Visible then allow = false end
	if allow and UIS.MouseIconEnabled then
		pcall(function() UIS.MouseIconEnabled = false end)
	end
	if UIS.MouseIconEnabled then allow = false end
	if allow then
		Cam.mouseApplied = true
		if UIS.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end)
		end
		Cam.lastReason = "视角锁定(鼠标锁中心)"
	elseif Cam.mouseApplied then
		Cam.mouseApplied = false
		pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
	end
end
local function camApply()
	local on = CFG.camUnlock or CFG.camForceThird or CFG.camLock
	if not on then
		if Cam.wasOn then
			Cam.wasOn = false
			Cam.locked = false
			camRestoreOriginals()
			Cam.lastReason = "已关闭，恢复游戏默认"
		end
		return
	end
	Cam.wasOn = true
	camTakeOriginals()
	local cam = workspace.CurrentCamera
	if not cam then return end
	if Cam.snapUntil and os.clock() < Cam.snapUntil then
		pcall(function()
			if LP.CameraMode ~= Enum.CameraMode.Classic then LP.CameraMode = Enum.CameraMode.Classic end
			LP.CameraMaxZoomDistance = Cam.snapDist
			LP.CameraMinZoomDistance = Cam.snapDist
		end)
		return
	end
	local userMin = math.clamp(tonumber(CFG.camMinZoom) or 0.5, 0.5, 60)
	local userMax = math.max(tonumber(CFG.camMaxZoom) or 200, userMin + 1)
	local minZ, maxZ
	if CFG.camForceThird then
		local forceMin = math.clamp(tonumber(CFG.camForceMin) or 8, 6, 60)
		minZ = math.max(forceMin, userMin)
		maxZ = math.max(userMax, minZ + 10)
	else
		minZ = userMin
		maxZ = userMax
	end
	if math.abs((LP.CameraMaxZoomDistance or 0) - maxZ) > 0.05 then
		pcall(function() LP.CameraMaxZoomDistance = maxZ end)
	end
	if math.abs((LP.CameraMinZoomDistance or 0) - minZ) > 0.05 then
		pcall(function() LP.CameraMinZoomDistance = minZ end)
	end
	if LP.CameraMode ~= Enum.CameraMode.Classic then
		pcall(function() LP.CameraMode = Enum.CameraMode.Classic end)
		Cam.lastReason = CFG.camForceThird and "强制第三人称" or "解锁相机"
	end
	if cam.CameraType == Enum.CameraType.Fixed or cam.CameraType == Enum.CameraType.Attach then
		pcall(function() cam.CameraType = Enum.CameraType.Custom end)
	end
	if CFG.camForceThird and CFG.camBodyVisible ~= false then
		local now = os.clock()
		if now - Cam.lastBodyAt > 0.1 then
			Cam.lastBodyAt = now
			camBodyReveal()
		end
	end
	local dist = 9e9
	do
		local ch = LP.Character
		local head = ch and ch:FindFirstChild("Head")
		if head then dist = (cam.CFrame.Position - head.Position).Magnitude end
	end
	Cam.lockDist = dist
	camApplyMouseLock(dist > 1.5)
	if CFG.camFreeze then
		if CFG.aimbot and not CFG.silent and Aim.point then
			Cam.locked = false
			Cam.lastReason = "自瞄接管视角，冻结暂停"
		else
			pcall(camApplyLock, cam)
		end
	else
		Cam.locked = false
	end
end
local function camBind()
	if Cam.bound then return end
	Cam.bound = true
	camTakeOriginals()
	pcall(function() Run:UnbindFromRenderStep(Cam.name) end)
	local ok = pcall(function()
		Run:BindToRenderStep(Cam.name, Enum.RenderPriority.Camera.Value + 1, function()
			pcall(camApply)
		end)
	end)
	if not ok then Cam.bound = false end
	return ok
end
local function camUnbind()
	if not Cam.bound then return end
	Cam.bound = false
	pcall(function() Run:UnbindFromRenderStep(Cam.name) end)
	pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
	Cam.mouseApplied = false
end
local function camSnap(dist, hold)
	dist = math.clamp(tonumber(dist) or 0.5, 0.5, 400)
	Cam.snapDist = dist
	Cam.snapUntil = os.clock() + (hold or 0.35)
	pcall(function()
		if LP.CameraMode ~= Enum.CameraMode.Classic then LP.CameraMode = Enum.CameraMode.Classic end
		LP.CameraMaxZoomDistance = dist
		LP.CameraMinZoomDistance = dist
	end)
end
local function camSetThird(on)
	if on then
		CFG.camForceThird = true
		if not CFG.camUnlock then CFG.camUnlock = true end
		Cam.snapUntil = 0
		pcall(function()
			LP.CameraMaxZoomDistance = math.max(tonumber(CFG.camMaxZoom) or 200, 60)
			LP.CameraMinZoomDistance = math.clamp(tonumber(CFG.camForceMin) or 8, 6, 60)
			LP.CameraMode = Enum.CameraMode.Classic
		end)
		pcall(camApply)
	else
		CFG.camForceThird = false
		pcall(function()
			LP.CameraMinZoomDistance = 0.5
			LP.CameraMode = Enum.CameraMode.Classic
		end)
		camSnap(0.5, 0.35)
		task.delay(0.4, function() pcall(camApply) end)
	end
	return true
end

local silentGui, silentLabel = nil, nil
local function gunFireInterval(cfg)
	local fd = nil
	if cfg and type(cfg.fire) == "table" then fd = tonumber(cfg.fire.fireDelay) end
	if not fd or fd <= 0 then return 0.12 end
	local mode = 1
	if cfg.ammo and type(cfg.ammo.mode) == "number" then mode = cfg.ammo.mode end
	if mode == 2 then fd = fd * 2 end
	if fd < 0.02 then fd = 0.02 end
	if fd > 2 then fd = 2 end
	return fd
end
local function ensureSilentAmmo(gun)
	local sa = HUB.silentAmmo
	if not sa then
		sa = { clip = 0, reserve = 0, size = 30, gun = nil,
			lastRealClip = nil, lastRealReserve = nil, pending = 0, pendingAt = 0 }
		HUB.silentAmmo = sa
	end
	if not gun then return sa end
	if sa.gun ~= gun then
		sa.gun = gun
		sa.size = gun:GetAttribute("ClipSize") or 30
		sa.lastRealClip = gun:GetAttribute("ClipCurrent")
		sa.lastRealReserve = gun:GetAttribute("MaxAmmo")
		sa.pending = 0
	end
	local cs = gun:GetAttribute("ClipSize")
	if type(cs) == "number" and cs > 0 then sa.size = cs end
	local rc = gun:GetAttribute("ClipCurrent")
	if type(rc) == "number" then
		sa.clip = math.max(0, rc)
		sa.lastRealClip = rc
		sa.pending = 0
	end
	local rm = gun:GetAttribute("MaxAmmo")
	if type(rm) == "number" then
		sa.reserve = rm
		sa.lastRealReserve = rm
	end
	return sa
end
local function silentHudTick(on, gun)
	if not on then
		if silentLabel and silentLabel.Visible then silentLabel.Visible = false end
		return
	end
	if not gun then return end
	local sa = ensureSilentAmmo(gun)
	if not silentGui or not silentGui.Parent then
		pcall(function()
			silentGui = Instance.new("ScreenGui")
			silentGui.Name = "__btrAmmo"
			silentGui.IgnoreGuiInset = true
			silentGui.ResetOnSpawn = false
			silentGui.DisplayOrder = 2147483647
			silentGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			silentGui.Parent = toastParent()
			silentLabel = Instance.new("TextLabel")
			silentLabel.AnchorPoint = Vector2.new(0.5, 0)
			silentLabel.Position = UDim2.new(0.5, 0, 0.5, 46)
			silentLabel.Size = UDim2.new(0, 220, 0, 28)
			silentLabel.BackgroundTransparency = 0.15
			silentLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			silentLabel.Font = Enum.Font.GothamBold
			silentLabel.TextSize = 15
			silentLabel.TextColor3 = Color3.fromRGB(55, 55, 70)
			silentLabel.Text = ""
			silentLabel.ZIndex = 2147483647
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = silentLabel
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Transparency = 0.5
			stroke.Color = Color3.fromRGB(220, 225, 235)
			stroke.Parent = silentLabel
			silentLabel.Parent = silentGui
		end)
	end
	HUB.fireInterval = gunFireInterval(getGunConfig(gun))
	if silentLabel then
		silentLabel.Visible = true
		if sa.clip <= 0 then
			silentLabel.Text = string.format("0 / %d", sa.reserve)
			silentLabel.TextColor3 = Color3.fromRGB(220, 80, 100)
		else
			silentLabel.Text = string.format("%d / %d", sa.clip, sa.reserve)
			silentLabel.TextColor3 = Color3.fromRGB(55, 55, 70)
		end
	end
end

local function packetShot(gun, cfg, t, partHint)
	HUB.packetCall = (HUB.packetCall or 0) + 1
	if not HUB.netReady then return false end
	local N = getNetwork()
	if not N or not gun then return false end
	if not cfg then
		pcall(function()
			for _, c in ipairs(gun:GetChildren()) do
				if c:IsA("ModuleScript") and c.Name == "" then
					local ok, r = pcall(require, c)
					if ok and type(r) == "table" and r.fire then cfg = r end
					break
				end
			end
		end)
	end
	t = t or nearestMonster(250)
	if not t then return false end
	local part = partHint or t.part or t.head or t.root
	local hum = t.hum
	if not (part and hum and hum.Parent) then return false end
	local origin = Aim.muzzle or Aim.origin or getRealMuzzle()
	if not origin then return false end
	local hitPos = part.Position
	local delta = hitPos - origin
	if delta.Magnitude < 0.3 then return false end
	local pellets = 1
	if type(cfg.fire) == "table" then
		local bp = tonumber(cfg.fire.bulletPerRound)
		if bp and bp > 1 then pellets = math.min(math.floor(bp), 24) end
	end
	if HUB.pelletOverride then pellets = HUB.pelletOverride end
	HUB.lastPellets = pellets
	local function makeCtx(hp)
		local d = hp - origin
		if d.Magnitude < 0.3 then return nil end
		local dir = d.Unit
		local normal = -dir
		local rel = CFrame.new()
		pcall(function()
			if hum.RootPart then
				rel = hum.RootPart.CFrame:ToObjectSpace(CFrame.new(hp, hp + normal * 1.5))
			end
		end)
		return { hum = hum, part = part, hitPos = hp, normal = normal,
			origin = origin, dir = dir, rel = rel }
	end
	HUB.packetTries = (HUB.packetTries or 0) + 1
	local baseCtx = makeCtx(hitPos)
	if not baseCtx then return false end
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then
			local from = origin
			local cp = cam.CFrame.Position
			if (from - cp).Magnitude > 8 then from = cp end
			if (hitPos - from).Magnitude > 0.2 then
				local cf = CFrame.lookAt(from, hitPos)
				N:FireServer("cam/mouse", cf, { from, hitPos })
			end
		end
	end)
	pcall(function() N:FireServer("fire", gun, cfg, baseCtx.dir) end)
	local idx = HUB.packetStrat or 1
	local ctxList = { baseCtx }
	for i = 2, pellets do
		local jitter = Vector3.new(
			(math.random() - 0.5) * 0.14,
			(math.random() - 0.5) * 0.14,
			(math.random() - 0.5) * 0.14)
		local ctx2 = makeCtx(hitPos + jitter)
		if ctx2 then ctxList[#ctxList + 1] = ctx2 end
	end
	local okS, payload = pcall(PACKET_STRATS[idx], baseCtx)
	if not okS then return false end
	for i, ctx in ipairs(ctxList) do
		local pl = payload
		if i > 1 then
			local okp, p2 = pcall(PACKET_STRATS[idx], ctx)
			pl = okp and p2 or nil
		end
		if pl then
			local isFirst = (i == 1)
			task.spawn(function()
				HUB.hitSends = (HUB.hitSends or 0) + 1
				local ok, ret = pcall(function() return N:InvokeServer("hit", gun, cfg, pl) end)
				if ok and ret ~= false and ret ~= nil then
					HUB.packetOK = (HUB.packetOK or 0) + 1
					HUB.packetStratOK = HUB.packetStratOK or {}
					HUB.packetStratOK[idx] = (HUB.packetStratOK[idx] or 0) + 1
					HUB.packetStratN = HUB.packetStratN or {}
					HUB.packetStratN[idx] = (HUB.packetStratN[idx] or 0) + 1
					if isFirst and CFG.trail then
						pcall(spawnTrail, origin, ctx.hitPos, nil, true)
					end
				else
					HUB.packetStratFail = (HUB.packetStratFail or 0) + 1
					HUB.packetStratN = HUB.packetStratN or {}
					HUB.packetStratN[idx] = (HUB.packetStratN[idx] or 0) + 1
					if isFirst then
						local okN = HUB.packetStratOK or {}
						local nN = HUB.packetStratN or {}
						local best, bestScore = nil, -1
						for j = 1, #PACKET_STRATS do
							if j ~= idx then
								local fails = (nN[j] or 0) - (okN[j] or 0)
								if fails <= 0 then best = j; break end
								local score = (okN[j] or 0) / math.max(nN[j] or 1, 1)
								if score > bestScore then bestScore, best = score, j end
							end
						end
						HUB.packetStrat = best or ((idx % #PACKET_STRATS) + 1)
						if (HUB.packetTries or 0) >= 40 and (HUB.packetOK or 0) == 0 then
							CFG.packetMode = false
						end
					end
				end
			end)
		end
	end
	return true
end

local function startReloadCycle(gun, cfg)
	if HUB.reloadBusy then return end
	HUB.reloadBusy = true
	HUB.reloadAt = os.clock()
	HUB.reloadNotified = true
	local N = getNetwork()
	if not N then
		HUB.reloadBusy = false
		return
	end
	pcall(function() N:FireServer("reload", gun, cfg, "register") end)
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(0.45)
			if not gun.Parent then break end
			local clip = gun:GetAttribute("ClipCurrent")
			if type(clip) == "number" and clip > 0 then break end
			pcall(function() N:FireServer("reload", gun, cfg, "reloaded") end)
		end
		HUB.reloadBusy = false
	end)
end

local function sendMouse(isDown)
	if VIM then
		local x, y = vpCenter()
		local ok = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, isDown, game, 0) end)
		if ok then return end
	end
	local f = isDown and COMPAT.m1press or COMPAT.m1release
	if type(f) == "function" then
		if pcall(f) then return end
	end
	if isDown and type(COMPAT.m1click) == "function" then pcall(COMPAT.m1click) end
end
local function mouseDown()
	if Fire.down then return end
	Fire.down = true
	sendMouse(true)
end
local function mouseUp()
	if not Fire.down then return end
	Fire.down = false
	sendMouse(false)
end
local function forceRelease()
	Fire.down = false
	sendMouse(false)
end

local SpeedHook = { installed = false, orig = nil }
local function installSpeedHook()
	if SpeedHook.installed then return true end
	if type(COMPAT.hook) ~= "function" then return false end
	local ok = pcall(function()
		local orig
		orig = COMPAT.hook(game, "__newindex", function(self, key, value)
			if key == "WalkSpeed" and CFG.customWalkSpeed then
				local h = getMyHumanoid()
				if h and self == h then value = CFG.walkSpeed end
			end
			if key == "JumpPower" and CFG.customJumpPower then
				local h = getMyHumanoid()
				if h and self == h then value = CFG.jumpPower end
			end
			return orig(self, key, value)
		end)
		SpeedHook.orig = orig
		SpeedHook.installed = true
	end)
	return ok
end
local function removeSpeedHook()
	if not SpeedHook.installed then return end
	pcall(function() (COMPAT.restore or restorefunction)(SpeedHook.orig) end)
	SpeedHook.installed = false
end

local staminaGui = { bar = nil, vig = nil, last = 0 }
local function refreshStaminaGui()
	local pg = LP:FindFirstChildOfClass("PlayerGui")
	local g = pg and pg:FindFirstChild("Gui")
	local sf = g and g:FindFirstChild("statusFrame")
	local st = sf and sf:FindFirstChild("stamina")
	staminaGui.bar = st and st:FindFirstChild("bar")
	staminaGui.vig = g and g:FindFirstChild("exhaust-vignette")
end

local lightBackup = genv.__BTRHUB_LIGHT
local function ensureBackup()
	if lightBackup then return end
	lightBackup = {
		Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
		GlobalShadows = Lighting.GlobalShadows, FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor,
	}
	local atmo = {}
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("Atmosphere") then
			atmo[#atmo + 1] = { obj = e, Density = e.Density, Haze = e.Haze, Glare = e.Glare }
		end
	end
	lightBackup.Atmosphere = atmo
	genv.__BTRHUB_LIGHT = lightBackup
end
local function applyWorld()
	ensureBackup()
	local fogOn = CFG.noFog or CFG.mapGlow
	if fogOn then
		pcall(function() Lighting:SetAttribute("LocalFogFullbright", true) end)
		Lighting.FogStart = 1e6
		Lighting.FogEnd = 1e6
		for _, a in ipairs(lightBackup.Atmosphere) do
			a.obj.Density = 0; a.obj.Haze = 0; a.obj.Glare = 0
		end
	else
		pcall(function() Lighting:SetAttribute("LocalFogFullbright", false) end)
		Lighting.FogStart = lightBackup.FogStart
		Lighting.FogEnd = lightBackup.FogEnd
		Lighting.FogColor = lightBackup.FogColor
		for _, a in ipairs(lightBackup.Atmosphere) do
			a.obj.Density = a.Density; a.obj.Haze = a.Haze; a.obj.Glare = a.Glare
		end
	end
	if CFG.mapGlow then
		Lighting.Ambient = Color3.fromRGB(80, 80, 85)
		Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 105)
		Lighting.Brightness = 1.7
		Lighting.ClockTime = 13.5
		Lighting.GlobalShadows = false
	else
		Lighting.Ambient = lightBackup.Ambient
		Lighting.OutdoorAmbient = lightBackup.OutdoorAmbient
		Lighting.Brightness = lightBackup.Brightness
		Lighting.ClockTime = lightBackup.ClockTime
		Lighting.GlobalShadows = lightBackup.GlobalShadows
	end
end
local DRAW
for _, nm in ipairs({ "Drawing", "drawing", "Draw", "Render" }) do
	local d = safeGet(nm)
	if d ~= nil then
		local okNew = pcall(function() return d.new end)
		if okNew then
			local ok = pcall(function()
				local s = d.new("Square")
				s.Visible = false
				pcall(function() s:Remove() end)
			end)
			if ok then DRAW = d; break end
		end
	end
end
local hasDrawing = DRAW ~= nil
HUB.renderMode = hasDrawing and "Drawing" or "Highlight"
local PROP_ALIAS = {
	TextSize = { "TextSize", "Size", "FontSize", "TextFontSize" },
	Center = { "Center", "Centered" },
	Outline = { "Outline", "Outlined" },
	OutlineColor = { "OutlineColor", "OutlinedColor" },
	Filled = { "Filled", "Fill" },
	Thickness = { "Thickness", "Width", "LineWidth" },
	NumSides = { "NumSides", "Sides", "Segments" },
	Transparency = { "Transparency", "Alpha" },
	Font = { "Font", "FontFace" },
}
local propCache = setmetatable({}, { __mode = "k" })
local function setP(obj, prop, value)
	if obj == nil then return false end
	local cache = propCache[obj]
	if not cache then cache = {}; propCache[obj] = cache end
	local name = cache[prop]
	if name == false then return false end
	if name then
		if pcall(function() obj[name] = value end) then return true end
		cache[prop] = false
		return false
	end
	for _, cand in ipairs(PROP_ALIAS[prop] or { prop }) do
		if pcall(function() obj[cand] = value end) then
			cache[prop] = cand
			return true
		end
	end
	cache[prop] = false
	return false
end

local pool, used = {}, {}
local function getPool(id)
	local e = pool[id]
	if e then return e end
	local ok, res = pcall(function()
		local o = {
			box = DRAW.new("Square"), name = DRAW.new("Text"),
			hpBg = DRAW.new("Square"), hp = DRAW.new("Square"),
			dist = DRAW.new("Text"), tracer = DRAW.new("Line"),
		}
		setP(o.box, "Thickness", 1)
		setP(o.box, "Filled", false)
		setP(o.hpBg, "Filled", true)
		o.hpBg.Color = Color3.fromRGB(0, 0, 0)
		setP(o.hpBg, "Transparency", 0.6)
		setP(o.hp, "Filled", true)
		setP(o.name, "Center", true)
		setP(o.name, "Outline", true)
		setP(o.name, "OutlineColor", Color3.fromRGB(0, 0, 0))
		setP(o.name, "TextSize", 14)
		setP(o.dist, "Center", true)
		setP(o.dist, "Outline", true)
		setP(o.dist, "OutlineColor", Color3.fromRGB(0, 0, 0))
		setP(o.dist, "TextSize", 12)
		setP(o.tracer, "Thickness", 1)
		return o
	end)
	if not ok or not res then
		hasDrawing = false
		HUB.renderMode = "Highlight(回退)"
		return nil
	end
	pool[id] = res
	return res
end

local lastDraw = {}
local function hideStale(now)
	for id, e in pairs(pool) do
		if now - (lastDraw[id] or 0) > 0.15 then
			e.box.Visible = false
			e.name.Visible = false
			e.hpBg.Visible = false
			e.hp.Visible = false
			e.dist.Visible = false
			e.tracer.Visible = false
		end
	end
end

local hlCache = setmetatable({}, { __mode = "k" })
local function espHighlight(targets)
	local seen = {}
	for _, t in ipairs(targets) do
		local show = (t.isPlayer and CFG.espPlayers) or ((not t.isPlayer) and CFG.espMonsters)
		if t.isPlayer and t.friend and CFG.espFriends then show = true end
		if show and t.inst and t.inst.Parent then
			seen[t.inst] = true
			local hl = hlCache[t.inst]
			if not hl or not hl.Parent then
				hl = Instance.new("Highlight")
				hl.Name = "__btrHL"
				hl.Adornee = t.inst
				hl.FillTransparency = 0.62
				hl.OutlineTransparency = 0.1
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = workspace.Terrain
				hlCache[t.inst] = hl
			end
			hl.FillColor = t.color
			hl.OutlineColor = t.color
			hl.Enabled = true
		end
	end
	if CFG.espAmmo then
		for _, it in ipairs(ammoCache) do
			if it.inst and it.inst.Parent then
				seen[it.inst] = true
				local hl = hlCache[it.inst]
				if not hl or not hl.Parent then
					hl = Instance.new("Highlight")
					hl.Name = "__btrHL"
					hl.Adornee = it.inst
					hl.FillTransparency = 0.55
					hl.OutlineTransparency = 0
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = workspace.Terrain
					hlCache[it.inst] = hl
				end
				hl.FillColor = CFG.colorAmmo
				hl.OutlineColor = CFG.colorAmmo
				hl.Enabled = true
			end
		end
	end
	for inst, hl in pairs(hlCache) do
		if not seen[inst] or not inst.Parent then
			if hl and hl.Parent then pcall(function() hl:Destroy() end) end
			hlCache[inst] = nil
		end
	end
end

local function drawTarget(t)
	pcall(function()
		local e = getPool(t.inst)
		if not e then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		local headSizeY = 0
		if t.head:IsA("BasePart") then headSizeY = t.head.Size.Y end
		local headPos = t.head.Position + Vector3.new(0, headSizeY * 0.5, 0)
		local footPos = t.root.Position - Vector3.new(0, 2.75, 0)
		local sTop, onTop = w2s(headPos)
		local sBot, onBot = w2s(footPos)
		if not (onTop and onBot) then return end
		lastDraw[t.inst] = os.clock()
		local h = math.abs(sBot.Y - sTop.Y)
		local w = h * 0.55
		if h < 4 or h > 3000 then return end
		local boxPos = Vector2.new(sTop.X - w * 0.5, sTop.Y)
		if CFG.box then
			e.box.Visible = true
			e.box.Color = t.color
			e.box.Position = boxPos
			e.box.Size = Vector2.new(w, h)
			setP(e.box, "Thickness", 1)
		end
		if CFG.health then
			local frac = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
			local barX = boxPos.X - 5
			e.hpBg.Visible = true
			e.hpBg.Position = Vector2.new(barX - 1, sTop.Y - 1)
			e.hpBg.Size = Vector2.new(4, h + 2)
			e.hp.Visible = true
			e.hp.Color = Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 40)
			e.hp.Position = Vector2.new(barX, sTop.Y + h * (1 - frac))
			e.hp.Size = Vector2.new(2, h * frac)
		end
		if CFG.name then
			e.name.Visible = true
			e.name.Text = t.label
			e.name.Color = t.color
			e.name.Position = Vector2.new(sTop.X, sTop.Y - 16)
			setP(e.name, "TextSize", math.clamp(16 - t.dist / 120, 10, 16))
		end
		if CFG.distance then
			e.dist.Visible = true
			e.dist.Text = string.format("[%d]", math.floor(t.dist))
			e.dist.Color = t.color
			e.dist.Position = Vector2.new(sTop.X, sBot.Y + 2)
			setP(e.dist, "TextSize", 12)
		end
		if CFG.tracer then
			e.tracer.Visible = true
			e.tracer.Color = t.color
			e.tracer.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y)
			e.tracer.To = Vector2.new(sTop.X, sBot.Y)
			setP(e.tracer, "Thickness", 1)
		end
	end)
end

local fovCircle
if hasDrawing then
	local okC, c = pcall(function() return DRAW.new("Circle") end)
	if okC and c then
		fovCircle = c
		setP(fovCircle, "Thickness", 1)
		setP(fovCircle, "Filled", false)
		setP(fovCircle, "NumSides", 48)
		setP(fovCircle, "Transparency", 0.7)
		fovCircle.Visible = false
	else
		fovCircle = nil
	end
end

local PART_ORDER = { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local PART_ROT = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }
local function muzzleSees(part, inst)
	if not part then return false end
	local m = getRealMuzzle()
	if not m then return false end
	return losClearFrom(m, part.Position, inst)
end
local function pickVisiblePart(t, rot)
	local cands, seen = {}, {}
	local function add(p)
		if p and p:IsA("BasePart") and not seen[p] then seen[p] = true; cands[#cands + 1] = p end
	end
	if rot and rot > 0 then
		for i = 0, #PART_ROT - 1 do
			add(t.inst and t.inst:FindFirstChild(PART_ROT[((i + rot) % #PART_ROT) + 1]))
		end
	end
	if t.head then add(t.head) end
	for _, nm in ipairs(PART_ORDER) do add(t.inst and t.inst:FindFirstChild(nm)) end
	if #cands == 0 then return nil, false end
	for _, p in ipairs(cands) do
		if muzzleSees(p, t.inst) then t.visiblePart = p; return p, true end
	end
	return cands[1], false
end

losClearFrom = function(pos, targetPos, targetInst)
	local d = targetPos - pos
	local dist = d.Magnitude
	if dist < 0.6 then return false end
	local dir = d / dist
	local excl = { workspace.Terrain:FindFirstChild("Ignore"), getMyChar() }
	local rp = rayParams(excl)
	local cur, left = pos, dist
	for _ = 1, 4 do
		local res = workspace:Raycast(cur, dir * left, rp)
		if res == nil then return true end
		if targetInst and (res.Instance == targetInst or res.Instance:IsDescendantOf(targetInst)) then return true end
		local p = res.Instance
		local soft = (p.CanCollide == false) or (p.Transparency and p.Transparency > 0.6)
		if not soft then return false end
		local adv = (res.Position - cur).Magnitude + 0.06
		left = left - adv
		if left <= 0.2 then return true end
		cur = res.Position + dir * 0.06
	end
	return false
end

local function pointIsOpen(p)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { getMyChar(), workspace.Terrain:FindFirstChild("Ignore") }
	local parts = workspace:GetPartBoundsInRadius(p, 0.35, op)
	for _, part in ipairs(parts) do
		if part.CanCollide then return false end
	end
	return true
end

local WALL_HINTS = {
	"wall", "floor", "ceiling", "roof", "ground", "cliff", "building",
	"tower", "structure", "stairs", "ramp", "platform", "door", "gate",
}
local OFFSET_MAX_WALL = 4
local OFFSET_MAX_OBSTACLE = 6
local function isWallPart(p)
	if not p or not p.Parent then return false end
	if p:IsA("Terrain") then return true end
	if not p:IsA("BasePart") then return false end
	local sz = p.Size
	local a, b, c = sz.X, sz.Y, sz.Z
	local minD = math.min(a, math.min(b, c))
	local maxD = math.max(a, math.max(b, c))
	local midD = a + b + c - minD - maxD
	if midD >= 12 then return true end
	if midD >= 6 and minD <= 2.5 then return true end
	local n = string.lower(p.Name)
	for _, k in ipairs(WALL_HINTS) do
		if string.find(n, k, 1, true) then return true end
	end
	return false
end
local function firstBlocker(from, to, targetInst)
	local d = to - from
	local dist = d.Magnitude
	if dist < 0.6 then return nil, nil, true end
	local dir = d / dist
	local rp = rayParams({ workspace.Terrain:FindFirstChild("Ignore"), getMyChar() })
	local cur, left = from, dist
	for _ = 1, 4 do
		local res = workspace:Raycast(cur, dir * left, rp)
		if res == nil then return nil, nil, true end
		local p = res.Instance
		if targetInst and (p == targetInst or p:IsDescendantOf(targetInst)) then return nil, nil, true end
		local soft = (p.CanCollide == false) or (p.Transparency and p.Transparency > 0.6)
		if not soft then return p, res.Position, false, res.Normal end
		local adv = (res.Position - cur).Magnitude + 0.06
		left = left - adv
		if left <= 0.2 then return nil, nil, true end
		cur = res.Position + dir * 0.06
	end
	return nil, nil, false
end
local OFFSET_EMBED_SKIP = 1.2
local function offsetPathClear(from, to)
	local d = to - from
	local dist = d.Magnitude
	if dist < 0.05 then return true end
	local dir = d / dist
	local rp = rayParams({ workspace.Terrain:FindFirstChild("Ignore"), getMyChar() })
	local cur, left, travelled = from, dist, 0
	for _ = 1, 4 do
		local res = workspace:Raycast(cur, dir * left, rp)
		if res == nil then return true end
		local hitI = res.Instance
		local stepd = (res.Position - cur).Magnitude
		travelled = travelled + stepd
		local soft = (hitI.CanCollide == false) or (hitI.Transparency and hitI.Transparency > 0.6)
		if not soft and travelled > OFFSET_EMBED_SKIP then return false end
		local adv = stepd + 0.06
		left = left - adv
		if left <= 0.1 then return true end
		cur = res.Position + dir * 0.06
	end
	return false
end

local function findSilentOffset(fromPos, targetPos, targetInst)
	if not fromPos or not targetPos then return nil end
	if (targetPos - fromPos).Magnitude < 1.0 then return nil end
	local blocker, bPos, clear, bNormal = firstBlocker(fromPos, targetPos, targetInst)
	if clear or not blocker then return nil end
	local wall = isWallPart(blocker)
	local cap
	if wall then cap = math.min(CFG.silentWallOffset or 2.5, HUB.silentWallCap or 2.5, OFFSET_MAX_WALL)
	else cap = math.min(CFG.silentObsOffset or 4, HUB.silentObsCap or 4, OFFSET_MAX_OBSTACLE) end
	cap = math.max(0.8, cap)
	local kind = wall and "wall" or "obstacle"
	local function sameSide(cand)
		if not (bPos and bNormal) then return true end
		local n = bNormal
		if n.Magnitude < 0.1 then return true end
		local dm = n:Dot(fromPos - bPos)
		if math.abs(dm) < 0.55 then return true end
		local dc = n:Dot(cand - bPos)
		if math.abs(dc) < 0.35 then return true end
		return dm * dc > 0
	end
	local dirs = {}
	local toT = (targetPos - fromPos).Unit
	local right = toT:Cross(Vector3.new(0, 1, 0))
	if right.Magnitude < 0.05 then right = Vector3.new(1, 0, 0) end
	right = right.Unit
	for i = 0, 11 do
		local a = math.rad(i * 30)
		dirs[#dirs + 1] = (right * math.cos(a) + toT * math.sin(a)).Unit
	end
	local heights = { 0, 0.7, -0.7, 1.4 }
	local step = math.max(math.min(CFG.muzzleStep or 0.5, 1.0), 0.3)
	local hw = 1.0
	if blocker:IsA("BasePart") then
		local a, b, c = blocker.Size.X, blocker.Size.Y, blocker.Size.Z
		local mid = a + b + c - math.min(a, b, c) - math.max(a, b, c)
		hw = math.max(mid * 0.5, 0.5)
	end
	local need = hw + 0.7
	local rMin = math.max(step, math.min(need, cap) - step)
	local asc, desc = {}, {}
	do
		local r = rMin
		while r < cap - 0.05 do asc[#asc + 1] = r; r = r + step end
		asc[#asc + 1] = cap
		r = cap
		while r > rMin + 0.05 do desc[#desc + 1] = r; r = r - step end
		desc[#desc + 1] = rMin
	end
	local budget = 150
	local function attempt(radiiList, heightList)
		for _, r in ipairs(radiiList) do
			for _, hy in ipairs(heightList) do
				for _, d in ipairs(dirs) do
					if budget <= 0 then return nil end
					budget = budget - 1
					local cand = fromPos + d * r + Vector3.new(0, hy, 0)
					if sameSide(cand) and offsetPathClear(fromPos, cand) then
						if losClearFrom(cand, targetPos, targetInst) then
							if pointIsOpen(cand) then return cand, r end
						end
					end
				end
			end
		end
		return nil
	end
	local p, r = attempt(asc, { 0 })
	if p then return p, r, kind end
	p, r = attempt(desc, heights)
	if p then return p, r, kind end
	return nil
end

local shotCache = { inst = nil, part = nil, at = 0, origin = nil, dist = 0, kind = "none", ok = false }
resolveMuzzleShot = function(t, targetPos, part, silentRules, force)
	if not (t and targetPos) then return nil, 0, "none", false end
	local now = os.clock()
	if not force and shotCache.inst == t.inst and shotCache.part == part then
		local ttl = shotCache.ok and 0.07 or 0.35
		if now - shotCache.at < ttl then
			return shotCache.origin, shotCache.dist, shotCache.kind, shotCache.ok
		end
	end
	local muzzle = getRealMuzzle()
	local origin, dist, kind, ok = nil, 0, "none", false
	if muzzle then
		if losClearFrom(muzzle, targetPos, t.inst) then
			origin, dist, kind, ok = muzzle, 0, "muzzle", true
		elseif silentRules then
			local p, d, k = findSilentOffset(muzzle, targetPos, t.inst)
			if p then origin, dist, kind, ok = p, d, k, true end
		else
			local p = findFiringOrigin(targetPos)
			if p then origin, dist, kind, ok = p, (Aim.offsetUsed or 0), "offset", true end
		end
	end
	shotCache.inst, shotCache.part, shotCache.at = t.inst, part, now
	shotCache.origin, shotCache.dist, shotCache.kind, shotCache.ok = origin, dist, kind, ok
	return origin, dist, kind, ok
end

findFiringOrigin = function(targetPos)
	local ch = getMyChar()
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root or not targetPos then return nil end
	local base = root.Position
	local muzzle = getRealMuzzle()
	local targetInst = Aim.target and Aim.target.inst
	if muzzle and losClearFrom(muzzle, targetPos, targetInst) then
		Aim.muzzle = muzzle
		Aim.offsetUsed = 0
		Aim.lastOffset = nil
		return nil
	end
	local escape = nil
	if muzzle then
		local rp = rayParams({ workspace.Terrain:FindFirstChild("Ignore"), ch })
		local block = workspace:Raycast(muzzle, targetPos - muzzle, rp)
		if block then
			local n = block.Normal
			n = Vector3.new(n.X, 0, n.Z)
			if n.Magnitude > 0.01 then escape = n.Unit end
		end
	end
	local dirs = {}
	if escape then dirs[#dirs + 1] = escape end
	for i = 0, 7 do
		local a = math.rad(i * 45)
		dirs[#dirs + 1] = Vector3.new(math.cos(a), 0, math.sin(a))
	end
	local heights = { 0.4, 1.2, -0.6 }
	local lo = Aim.lastOffset
	if lo then
		local cand = base + lo.d * lo.r + Vector3.new(0, lo.hy or 0, 0)
		if pointIsOpen(cand) and losClearFrom(cand, targetPos, targetInst) then
			Aim.muzzle = cand
			Aim.offsetUsed = lo.r
			Aim.offsetDir = lo.d
			return cand
		end
	end
	local step = math.max(CFG.muzzleStep or 0.5, 0.3)
	local maxR = math.min(CFG.muzzleRadius, HUB.maxOffsetOK or CFG.muzzleRadius)
	local budget = 130
	local r = step
	while r <= maxR + 0.001 and budget > 0 do
		for _, d in ipairs(dirs) do
			for _, hy in ipairs(heights) do
				if budget <= 0 then break end
				budget = budget - 1
				local cand = base + d * r + Vector3.new(0, hy, 0)
				if pointIsOpen(cand) and losClearFrom(cand, targetPos, targetInst) then
					Aim.muzzle = cand
					Aim.offsetUsed = r
					Aim.offsetDir = d
					Aim.lastOffset = { d = d, r = r, hy = hy }
					return cand
				end
			end
		end
		r = r + step
	end
	Aim.muzzle = nil
	Aim.offsetUsed = nil
	return nil
end

local silentScan = { at = 0, t = nil, part = nil, origin = nil, dist = 0, kind = "none" }
local silentFailAt = setmetatable({}, { __mode = "k" })
local function silentTarget(maxDist)
	local now = os.clock()
	if now - silentScan.at < 0.1 then
		return silentScan.t, silentScan.part, silentScan.origin, silentScan.dist, silentScan.kind
	end
	silentScan.at = now
	silentScan.t, silentScan.part, silentScan.origin = nil, nil, nil
	silentScan.dist, silentScan.kind = 0, "none"
	local list = buildTargets()
	local cand = {}
	for _, t in ipairs(list) do
		if not t.isPlayer and not t.isSelf and t.dist <= (maxDist or 320) and t.hum and t.hum.Health > 0 then
			cand[#cand + 1] = t
		end
	end
	if #cand == 0 then return nil end
	table.sort(cand, function(a, b) return a.dist < b.dist end)
	local m = getRealMuzzle()
	local rot = HUB.aimPartCycle or 0
	for i = 1, math.min(#cand, 8) do
		local t = cand[i]
		local part, okv = pickVisiblePart(t, rot)
		t.part, t.visible = part, okv
		if okv then
			silentScan.t, silentScan.part = t, part
			silentScan.origin, silentScan.dist, silentScan.kind = m, 0, "muzzle"
			return t, part, m, 0, "muzzle"
		end
	end
	for i = 1, math.min(#cand, 2) do
		local t = cand[i]
		local part = t.part or t.head or t.root
		local failedAt = silentFailAt[t.inst]
		if part and not (failedAt and now - failedAt < 0.35) then
			local o, d, k, ok = resolveMuzzleShot(t, part.Position, part, true, true)
			if ok then
				silentFailAt[t.inst] = nil
				silentScan.t, silentScan.part = t, part
				silentScan.origin, silentScan.dist, silentScan.kind = o, d, k
				return t, part, o, d, k
			end
			silentFailAt[t.inst] = now
		end
	end
	return nil
end

local function pickTarget(targets)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
	local halfFov = CFG.fov * 0.5
	local camPos = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local cands = {}
	local camHalf = math.rad(math.clamp(cam.FieldOfView, 1, 179)) * 0.5
	local halfH = math.max(cam.ViewportSize.Y * 0.5, 1)
	local angleFromPx = math.deg(math.atan(math.tan(camHalf) * (halfFov / halfH)))
	local angleLimit = math.min(CFG.fovAngle, math.max(angleFromPx, 1))
	for _, t in ipairs(targets) do
		if not t.isSelf then
			local allowed = t.isPlayer and CFG.aimPlayers or CFG.aimMonsters
			if allowed then
				local pos = (t.head or t.root).Position
				local score
				if CFG.aim360 then
					local d = pos - camPos
					if d.Magnitude > 0.1 then
						local ang = math.deg(math.acos(math.clamp(look:Dot(d.Unit), -1, 1)))
						if ang <= angleLimit then score = (ang / math.max(angleLimit, 1)) * 120 + t.dist end
					end
				else
					local sp, on = w2s(pos)
					if on then
						local sd = (sp - center).Magnitude
						if sd <= halfFov then score = (sd / math.max(halfFov, 1)) * 120 + t.dist end
					end
				end
				if score then cands[#cands + 1] = { t = t, s = score } end
			end
		end
	end
	if #cands == 0 then return nil end
	table.sort(cands, function(a, b) return a.s < b.s end)
	local rot = HUB.aimPartCycle or 0
	local fallback
	local limit = math.min(#cands, 5)
	for i = 1, limit do
		local t = cands[i].t
		local part, visible = pickVisiblePart(t, rot)
		t.part = part
		t.visible = visible
		if visible then return t end
		if not fallback then fallback = t end
	end
	if CFG.visibleOnly and not CFG.silentPacket then return nil end
	return fallback or cands[1].t
end

local function computeAimPoint(t, gun, part)
	part = part or ((CFG.aimPart == "Head" and t.head) or t.root)
	local p = part.Position
	if gun then
		local cfg = getGunConfig(gun)
		if cfg and type(cfg.fire) == "table" then
			local speed = cfg.fire.fireSpeed or 3000
			local d = (p - workspace.CurrentCamera.CFrame.Position).Magnitude
			local tt = d / math.max(speed, 1)
			local vel = t.root.AssemblyLinearVelocity
			if vel and vel.Magnitude > 2 then p = p + vel * tt * 0.85 end
		end
	end
	return p
end

local dmgWatch = { t = 0, inst = nil, hp = nil, hitAt = 0, ammoBefore = nil }
local function dmgWatchTick(now)
	if not dmgWatch.inst then return end
	if now - dmgWatch.t < 0.45 then return end
	local inst, hp = dmgWatch.inst, dmgWatch.hp
	local hitAt = dmgWatch.hitAt or 0
	local ammoBefore = dmgWatch.ammoBefore
	dmgWatch.inst, dmgWatch.hp, dmgWatch.t = nil, nil, 0
	dmgWatch.hitAt, dmgWatch.ammoBefore = 0, nil
	local hum = inst and inst.Parent and inst:FindFirstChildOfClass("Humanoid")
	if not (hum and hp) then return end
	local gotHitReceipt = (HUB.lastHitAt or 0) > hitAt
	local ammoChanged = false
	local gun = getEquippedGun()
	if gun and ammoBefore ~= nil then
		local after = gun:GetAttribute("ClipCurrent")
		if type(after) == "number" and after < ammoBefore then ammoChanged = true end
	end
	if not gotHitReceipt and not ammoChanged then
		if hum.Health >= hp and hum.Health > 0 then
			HUB.noDamage = (HUB.noDamage or 0) + 1
			HUB.aimPartCycle = ((HUB.aimPartCycle or 0) + 1) % #PART_ROT
			shotCache.at, shotCache.ok = 0, false
			Aim.lastOffset = nil
			if (HUB.noDamage % 4) == 0 then toast("连续未命中 · 自动切换瞄准部位", 2) end
		end
	end
end

local lastFire = 0
local lastWorld = 0
local lastItem = 0

local function onRender(dt)
	local now = os.clock()
	HUB.fps = HUB.fps and (HUB.fps * 0.9 + (1 / math.max(dt, 0.001)) * 0.1) or (1 / math.max(dt, 0.001))
	local ok, err = pcall(function()
		local myChar = getMyChar()
		local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
		local alive = hum and hum.Health > 0
		local gun = getEquippedGun()

		pcall(dmgWatchTick, now)

		if now - (HUB.netCheckAt or 0) > 3 then
			HUB.netCheckAt = now
			local okN, m = pcall(require, RS.Assets.Modules.Network)
			if okN and type(m) == "table" and NB and NB.net ~= m then
				Network = nil
				NB = nil
				genv.__BTRHUB_NET = nil
				installNetHooks()
				if NB then NB.onFire = onFirePacket; NB.onHit = onHitPacket end
			end
		end

		local wantWorld = CFG.noFog or CFG.mapGlow
		if wantWorld ~= HUB.worldOn then
			HUB.worldOn = wantWorld
			applyWorld()
		elseif wantWorld and now - lastWorld > 1 then
			lastWorld = now
			applyWorld()
		end

		if CFG.infStamina then
			installSpeedHook()
			if now - staminaGui.last > 2 or not staminaGui.bar or not staminaGui.bar.Parent then
				staminaGui.last = now
				refreshStaminaGui()
			end
			if staminaGui.bar and staminaGui.bar:IsA("GuiObject") then
				staminaGui.bar.Size = UDim2.new(1, 0, 1, 0)
			end
			if staminaGui.vig and staminaGui.vig:IsA("ImageLabel") then
				staminaGui.vig.ImageTransparency = 1
			end
		else
			removeSpeedHook()
		end

		if hum and alive then
			if CFG.customWalkSpeed and hum.WalkSpeed ~= CFG.walkSpeed then
				hum.WalkSpeed = CFG.walkSpeed
			end
			if CFG.customJumpPower and hum.JumpPower ~= CFG.jumpPower then
				hum.JumpPower = CFG.jumpPower
			end
		end

		if CFG.noFall and hum and alive and myChar then
			local root = myChar:FindFirstChild("HumanoidRootPart")
			if root then
				if hum.FloorMaterial == Enum.Material.Air then
					local v = root.AssemblyLinearVelocity
					if v.Y < -CFG.fallSpeed then
						root.AssemblyLinearVelocity = Vector3.new(v.X, -CFG.fallSpeed, v.Z)
					end
				end
			end
		end

		if CFG.noShield and now - lastShieldScan > 0.5 then
			lastShieldScan = now
			shieldCache = scanShields()
		end

		if now - lastMonsterScan > 1 then
			lastMonsterScan = now
			monsterCache = scanMonsters()
		end
		local targets = buildTargets()

		if hasDrawing then
			hideStale(now)
			toastTick()
			silentHudTick(CFG.silentPacket == true, getEquippedGun())
			used = {}
			for _, t in ipairs(targets) do
				local show = (t.isPlayer and CFG.espPlayers) or ((not t.isPlayer) and CFG.espMonsters)
				if t.isPlayer and t.friend and CFG.espFriends then show = true end
				if show then used[t.inst] = true; drawTarget(t) end
			end
			if CFG.espItems and now - lastItem > 0.35 then
				lastItem = now
				scanItems()
			end
			if CFG.espItems then
				local cam = workspace.CurrentCamera
				for _, it in ipairs(itemCache) do
					if it.inst.Parent and it.part.Parent then
						local e = getPool(it.inst)
						if not e then break end
						local sp, on = w2s(it.part.Position)
						local d = (it.part.Position - cam.CFrame.Position).Magnitude
						if on and d <= CFG.maxDist then
							e.box.Visible = true
							e.box.Color = CFG.colorItem
							e.box.Position = Vector2.new(sp.X - 3, sp.Y - 3)
							e.box.Size = Vector2.new(6, 6)
							setP(e.box, "Thickness", 1)
							e.name.Visible = true
							e.name.Text = it.label
							e.name.Color = CFG.colorItem
							e.name.Position = Vector2.new(sp.X, sp.Y - 14)
							setP(e.name, "TextSize", 11)
							e.dist.Visible = true
							e.dist.Text = string.format("[%d]", math.floor(d))
							e.dist.Color = CFG.colorItem
							e.dist.Position = Vector2.new(sp.X, sp.Y + 6)
							setP(e.dist, "TextSize", 11)
						end
					end
				end
			end
			if CFG.espAmmo then
				local cam2 = workspace.CurrentCamera
				for _, it in ipairs(ammoCache) do
					if it.inst.Parent then
						if not (it.part and it.part.Parent) then
							it.part = it.inst:FindFirstChildWhichIsA("BasePart", true)
							if not it.part then
								local okp, pv = pcall(function() return it.inst:GetPivot().Position end)
								if okp then it.pivot = pv end
							end
						end
						if it.att and not it.att.Parent then it.att = nil end
						local e = getPool(it.inst)
						local pos = (it.att and it.att.Parent and it.att.WorldPosition)
							or (it.part and it.part.Parent and it.part.Position) or it.pivot
						if e and pos then
							local sp, on = w2s(pos)
							local d = (pos - cam2.CFrame.Position).Magnitude
							if on and d <= CFG.maxDist then
								e.box.Visible = true
								e.box.Color = CFG.colorAmmo
								e.box.Position = Vector2.new(sp.X - 5, sp.Y - 5)
								e.box.Size = Vector2.new(10, 10)
								setP(e.box, "Thickness", 2)
								e.name.Visible = true
								e.name.Text = it.label or "弹药"
								e.name.Color = CFG.colorAmmo
								e.name.Position = Vector2.new(sp.X, sp.Y - 17)
								setP(e.name, "TextSize", 12)
								e.dist.Visible = true
								e.dist.Text = string.format("[%d]", math.floor(d))
								e.dist.Color = CFG.colorAmmo
								e.dist.Position = Vector2.new(sp.X, sp.Y + 8)
								setP(e.dist, "TextSize", 11)
							end
						end
					end
				end
			end
		else
			espHighlight(targets)
		end

		local aimTarget
		if CFG.aimbot and alive then aimTarget = pickTarget(targets) end

		if CFG.aimbot and aimTarget and gun then
			Aim.target = aimTarget
			Aim.gunCfg = getGunConfig(gun)
			local part = aimTarget.part
			local visible = aimTarget.visible
			if part == nil then
				if CFG.aimSmartPart then part, visible = pickVisiblePart(aimTarget, HUB.aimPartCycle or 0)
				else
					part = (CFG.aimPart == "Head" and aimTarget.head) or aimTarget.root
					visible = muzzleSees(part, aimTarget.inst)
				end
				aimTarget.part = part
				aimTarget.visible = visible
			end
			Aim.part = part
			Aim.occluded = not visible
			Aim.point = computeAimPoint(aimTarget, gun, part)
			if Aim.forceOrigin then
				Aim.origin = Aim.forceOrigin
				Aim.muzzle = Aim.forceOrigin
				Aim.offsetUsed = 0
				Aim.offsetKind = "force"
				Aim.shotOK = true
			elseif CFG.muzzleOffset or CFG.silentPacket then
				if now - Aim.muzzleAt > 0.07 then
					Aim.muzzleAt = now
					local o, d, k, ok = resolveMuzzleShot(aimTarget, Aim.point, part, CFG.silentPacket == true)
					local dd = d or 0
					Aim.shotOK = ok == true
					Aim.shotDist = dd
					if ok then
						Aim.muzzle = o
						Aim.offsetUsed = dd
						Aim.offsetKind = k
						Aim.muzzleBlocked = dd > 0
						Aim.origin = (dd > 0) and o or nil
					else
						Aim.muzzle = nil
						Aim.offsetUsed = nil
						Aim.offsetKind = "none"
						Aim.muzzleBlocked = true
						Aim.origin = nil
					end
				end
			else
				Aim.origin = nil
				Aim.muzzle = getRealMuzzle()
				Aim.offsetUsed = 0
				Aim.offsetKind = "muzzle"
				Aim.muzzleBlocked = not visible
				Aim.shotOK = visible == true
			end
			if not CFG.silent then
				local aimPart = (CFG.aimPart == "Head" and aimTarget.head) or aimTarget.root
				local cam = workspace.CurrentCamera
				if cam then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPart.Position) end
			end
			local extra = ""
			if Aim.shotOK and (Aim.offsetUsed or 0) > 0 then
				extra = string.format(" 偏移%.1f(%s)", Aim.offsetUsed, tostring(Aim.offsetKind or "?"))
			end
			STATS.target = aimTarget.label .. " " .. math.floor(aimTarget.dist) .. "m" ..
				(visible and "" or " (枪口被挡)") .. extra
		else
			Aim.point = nil; Aim.target = nil; Aim.gunCfg = nil; Aim.occluded = false
			Aim.origin = nil; Aim.muzzle = nil; Aim.offsetUsed = nil; Aim.offsetKind = nil
			Aim.muzzleBlocked = false; Aim.shotOK = false; Aim.shotDist = 0
			STATS.target = "-"
		end

		local wantFire = CFG.autoFire and alive and gun and aimTarget ~= nil
		if wantFire and not Aim.shotOK then
			wantFire = false
		end
		if wantFire and Aim.origin and not Aim.hadOrigin then lastFire = 0 end
		Aim.hadOrigin = (Aim.origin ~= nil)
		if wantFire and gun then
			local clip = gun:GetAttribute("ClipCurrent")
			if clip ~= nil and clip <= 0 then wantFire = false end
			if gun:GetAttribute("Reloading") == true then wantFire = false end
		end

		
		if CFG.silentPacket and alive and gun and HUB.netReady then
			local cfgP = getGunConfig(gun)
			local sa = ensureSilentAmmo(gun)
			local pT, pPart, pOrigin, pDist, pKind = nil, nil, nil, 0, "none"
			if aimTarget and Aim.shotOK and Aim.part then
				pT, pPart = aimTarget, Aim.part
				pOrigin, pDist, pKind = Aim.muzzle, Aim.offsetUsed or 0, Aim.offsetKind or "muzzle"
			else
				pT, pPart, pOrigin, pDist, pKind = silentTarget(320)
			end
			local fired = 0
			
			if CFG.autoReload and sa.clip <= 0 and not HUB.reloadBusy then
				startReloadCycle(gun, cfgP)
				toast("Ragebot · 弹夹空了，自动换弹", 1.6)
			end
			if pT and pPart and cfgP and sa.clip > 0 and (not pT.hum or pT.hum.Health > 0) then
				local origin = (typeof(pOrigin) == "Vector3") and pOrigin or nil
				local od = pDist or 0
				local okShot = origin ~= nil and losClearFrom(origin, pPart.Position, pT.inst)
				if not okShot then
					local o2, d2, k2, ok2 = resolveMuzzleShot(pT, pPart.Position, pPart, true, true)
					if ok2 then origin, od, pKind, okShot = o2, d2 or 0, k2, true end
				end
				if not okShot then
					HUB.silentAcc = 0
					HUB.silentIdle = (HUB.silentIdle or 0) + 1
				else
					local intervalP = gunFireInterval(cfgP)
					HUB.fireInterval = intervalP
					HUB.silentAcc = (HUB.silentAcc or 0) + (dt or 0)
					local burst = 0
					while HUB.silentAcc >= intervalP and burst < 8 and sa.clip > 0 do
						HUB.silentAcc = HUB.silentAcc - intervalP
						burst = burst + 1
						fired = fired + 1
						Aim.point = pPart.Position
						Aim.gunCfg = cfgP
						Aim.target = pT
						Aim.part = pPart
						Aim.muzzle = origin
						Aim.offsetUsed = od
						Aim.offsetKind = (od > 0) and (pKind or "obstacle") or "muzzle"
						Aim.origin = origin
						Aim.packetMuzzle = origin
						Aim.packetTarget = pT.inst
						Aim.shotOK = true
						Aim.shotDist = od
						lastFire = now
						HUB.silentPacketShots = (HUB.silentPacketShots or 0) + 1
						local firesBefore = HUB.ourCasts or 0
						local clipBefore = gun:GetAttribute("ClipCurrent")
						local useReal = (CFG.silentReal or HUB.silentFallbackReal) and not HUB.silentBypass[gun.Name]
						if useReal then
							sendMouse(true)
							task.delay(0.05, function() pcall(function() sendMouse(false) end) end)
							local gunName = gun.Name
							if not HUB.silentBypass[gunName] then
								task.delay(0.2, function()
									local after = gun.Parent and gun:GetAttribute("ClipCurrent")
									local consumed = (type(clipBefore) == "number" and type(after) == "number")
										and (after < clipBefore) or false
									if (HUB.ourCasts or 0) > firesBefore then
										HUB.silentNoCast[gunName] = 0
									elseif consumed then
										HUB.silentNoCast[gunName] = (HUB.silentNoCast[gunName] or 0) + 1
										if HUB.silentNoCast[gunName] >= 3 and not HUB.silentBypass[gunName] then
											HUB.silentBypass[gunName] = true
											HUB.silentBypassHits = (HUB.silentBypassHits or 0) + 1
											toast("该枪械绕过弹道层 · 已自动改用命中包", 3)
										end
									end
								end)
							end
						else
							packetShot(gun, cfgP, pT, pPart)
						end
					end
					if fired > 0 and not dmgWatch.inst then
						dmgWatch.inst = pT.inst
						dmgWatch.hp = pT.hum and pT.hum.Health or nil
						dmgWatch.t = now
						dmgWatch.hitAt = HUB.lastHitAt or 0
						dmgWatch.ammoBefore = gun:GetAttribute("ClipCurrent")
					end
					local capAcc = intervalP * 4
					if HUB.silentAcc > capAcc then HUB.silentAcc = capAcc end
				end
			else
				HUB.silentAcc = 0
			end
			if not CFG.silentReal and not HUB.packetWarned
				and (HUB.packetTries or 0) >= 15 and (HUB.packetOK or 0) == 0
				and now - (HUB.packetWarnedAt or 0) > 30 then
				HUB.packetWarned = true
				HUB.packetWarnedAt = now
				toast("发包一直被服务器拒绝 · 检查 Ragebot 配置", 4)
			end
			if (HUB.packetOK or 0) > 0 then
				HUB.packetWarned = false
				HUB.silentFallbackReal = false
			end
			wantFire = false
		end

		if not CFG.silentPacket and HUB.silentFallbackReal and not CFG.packetMode then
			HUB.silentFallbackReal = false
		end

		if CFG.packetMode and alive and gun and HUB.netReady then
			local pTarget, pPart, pOrigin, pDist, pKind = nil, nil, nil, 0, "none"
			if aimTarget and Aim.shotOK then
				pTarget, pPart = aimTarget, Aim.part
				pOrigin, pDist, pKind = Aim.muzzle, Aim.offsetUsed or 0, Aim.offsetKind or "muzzle"
			else
				pTarget, pPart, pOrigin, pDist, pKind = silentTarget(250)
			end
			local cfg = getGunConfig(gun)
			local clip = gun:GetAttribute("ClipCurrent")
			local reloading = gun:GetAttribute("Reloading") == true
			if not pTarget and now - (HUB.silentIdleAt or 0) > 0.5 then
				HUB.silentIdleAt = now
				HUB.silentIdle = (HUB.silentIdle or 0) + 1
			end
			if pTarget and cfg and pPart then
				Aim.point = pPart.Position
				Aim.gunCfg = cfg
				Aim.target = pTarget
				Aim.part = pPart
				Aim.muzzle = pOrigin
				Aim.offsetUsed = pDist or 0
				Aim.offsetKind = ((pDist or 0) > 0) and (pKind or "obstacle") or "muzzle"
				Aim.origin = ((pDist or 0) > 0) and pOrigin or nil
				Aim.packetMuzzle = pOrigin
				Aim.packetTarget = pTarget.inst
				Aim.shotOK = true
				Aim.shotDist = pDist or 0
				if clip ~= nil and clip <= 0 then
					
					if CFG.autoReload and not reloading and not HUB.reloadBusy and now - (HUB.reloadAt or 0) > 1.0 then
						startReloadCycle(gun, cfg)
						toast("弹匣打空 · 正在自动换弹", 2.2)
					end
				elseif not reloading then
					if HUB.reloadNotified and clip and clip > 0 then
						HUB.reloadNotified = false
						toast("换弹完成 · 继续射击", 1.6)
					end
					local interval = gunFireInterval(cfg)
					if now - lastFire >= interval then
						lastFire = now
						HUB.packetShots = (HUB.packetShots or 0) + 1
						sendMouse(true)
						task.delay(0.045, function() sendMouse(false) end)
					end
				end
			end
			wantFire = false
		end

		if wantFire then
			local cfg = getGunConfig(gun)
			local interval = 0.12
			if cfg and cfg.fire then interval = math.max(cfg.fire.fireDelay or 0.12, 0.03) end
			if now - lastFire >= interval then
				lastFire = now
				if not Fire.down then
					mouseDown()
					task.delay(0.06, function() forceRelease() end)
				end
			end
		else
			mouseUp()
		end

		if fovCircle then
			local cam = workspace.CurrentCamera
			if CFG.aimbot and cam then
				local vp = cam.ViewportSize
				fovCircle.Visible = true
				fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
				local r = CFG.fov * 0.5
				if r ~= r then r = 100 end
				local maxR = math.min(vp.X, vp.Y) * 0.47
				fovCircle.Radius = math.clamp(r, 6, maxR)
				if not aimTarget then
					fovCircle.Color = Color3.fromRGB(255, 255, 255)
				elseif not Aim.shotOK then
					fovCircle.Color = Color3.fromRGB(255, 70, 70)
				elseif (Aim.offsetUsed or 0) <= 0 then
					fovCircle.Color = Color3.fromRGB(90, 255, 120)
				else
					fovCircle.Color = Color3.fromRGB(90, 200, 255)
				end
			else
				fovCircle.Visible = false
			end
		end
	end)
	if not ok and not HUB.warned then
		HUB.warned = true
		warn("[BTR-HUB] loop error: " .. tostring(err))
	end
end

table.insert(HUB.conns, Run.RenderStepped:Connect(onRender))
local DynamicContext = {
	ActiveToggles = {}, ActiveSliders = {}, TextElements = {}, BorderElements = {},
	CurrentTab = "", TabSwitchThread = nil, TabButtons = {},
	IsSubCardActive = true, GlobalAudio = nil, CurrentVolume = 2,
	BgPhase = math.random() * 100, StrokeRotation = 0, StatusLabel = nil, ScreenGui = nil,
}

pcall(function()
	for _, cont in ipairs({ CoreGui, LP:FindFirstChildOfClass("PlayerGui") }) do
		if cont then
			for _, child in ipairs(cont:GetChildren()) do
				if child:IsA("ScreenGui") and (string.sub(child.Name, 1, 5) == "__btr" or child.Name == "LinkCcUI") then
					pcall(function() child:Destroy() end)
				end
			end
		end
	end
end)

local function safeTween(obj, info, prop)
	if obj and obj.Parent then
		local t = Tween:Create(obj, info, prop)
		if t then t:Play() end
		return t
	end
	return nil
end

Internal.mouseDown = function() mouseDown() end
Internal.mouseUp = function() mouseUp() end
Internal.forceRelease = function() forceRelease() end
Internal.getGun = getEquippedGun
Internal.getGunConfig = getGunConfig
Internal.spawnTrail = function(a, b, d) return spawnTrail(a, b, d) end
Internal.reinstallRay = function() installRayHooks() end
Internal.silentProbe = function()
	local gun = getEquippedGun()
	local cfg = gun and getGunConfig(gun)
	local sa = gun and ensureSilentAmmo(gun)
	local pT, pPart, pOrigin, pDist, pKind = silentTarget(320)
	local m = getRealMuzzle()
	return tostring(pT and pT.label or "nil"), tostring(pPart and pPart.Name or "nil"),
		tostring(pKind), pDist or 0, tostring(cfg ~= nil),
		sa and (sa.clip or -1) or -1,
		typeof(m) == "Vector3" and "muzzleOK" or "noMuzzle",
		typeof(pOrigin) == "Vector3" and string.format("%.2f", m and (pOrigin - m).Magnitude or -1) or "-"
end
Internal.offsetProbe = function(fromPos, targetPos, targetInst)
	return findSilentOffset(fromPos, targetPos, targetInst)
end
Internal.classifyPart = function(p)
	if not p then return "nil" end
	return isWallPart(p) and "wall" or "obstacle"
end
Internal.setOrigin = function(p) Aim.forceOrigin = p end
Internal.clearOrigin = function() Aim.forceOrigin = nil; Aim.origin = nil end
Internal.camApply = function() pcall(camApply); return true end
Internal.camThird = function(on) return camSetThird(on == true) end
Internal.camLock = function(on)
	CFG.camLock = (on ~= false)
	if CFG.camLock then CFG.camUnlock = true
	else Cam.mouseApplied = false; pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end) end
	pcall(camApply); return CFG.camLock
end
Internal.camFreeze = function(on)
	CFG.camFreeze = (on ~= false)
	if CFG.camFreeze then
		CFG.camUnlock = true
		if not Cam.lockPitch then camCaptureLook() end
	else
		Cam.locked = false
		Cam.lockPitch, Cam.lockYaw, Cam.lockCharYaw = nil, nil, nil
	end
	pcall(camApply); return CFG.camFreeze
end
Internal.camLockRecapture = function()
	Cam.lockPitch, Cam.lockYaw, Cam.lockCharYaw = nil, nil, nil
	local ok = camCaptureLook()
	pcall(camApply)
	return ok == true
end

local UISuccess, UIErr = pcall(function()
	local PalettePresets = {
		["Bubblegum"] = { Primary = Color3.fromRGB(255, 242, 248), Secondary = Color3.fromRGB(248, 240, 255),
			Accent = Color3.fromRGB(240, 250, 255), LogoAccent = Color3.fromRGB(255, 70, 135),
			ActiveColor = Color3.fromRGB(255, 90, 155), TextColor = Color3.fromRGB(35, 25, 40),
			SubTextColor = Color3.fromRGB(120, 100, 130), BorderColor = Color3.fromRGB(255, 215, 235) },
		["Dark Pastel"] = { Primary = Color3.fromRGB(235, 230, 248), Secondary = Color3.fromRGB(225, 235, 255),
			Accent = Color3.fromRGB(242, 235, 250), LogoAccent = Color3.fromRGB(135, 90, 210),
			ActiveColor = Color3.fromRGB(145, 100, 225), TextColor = Color3.fromRGB(30, 25, 45),
			SubTextColor = Color3.fromRGB(110, 105, 130), BorderColor = Color3.fromRGB(215, 205, 240) },
		["Ocean Mist"] = { Primary = Color3.fromRGB(230, 250, 255), Secondary = Color3.fromRGB(238, 255, 253),
			Accent = Color3.fromRGB(240, 248, 255), LogoAccent = Color3.fromRGB(10, 150, 245),
			ActiveColor = Color3.fromRGB(20, 170, 255), TextColor = Color3.fromRGB(20, 40, 55),
			SubTextColor = Color3.fromRGB(90, 115, 135), BorderColor = Color3.fromRGB(195, 238, 255) },
		["Sunset Glow"] = { Primary = Color3.fromRGB(255, 240, 235), Secondary = Color3.fromRGB(255, 248, 228),
			Accent = Color3.fromRGB(255, 240, 250), LogoAccent = Color3.fromRGB(255, 85, 65),
			ActiveColor = Color3.fromRGB(255, 105, 85), TextColor = Color3.fromRGB(45, 25, 25),
			SubTextColor = Color3.fromRGB(135, 100, 100), BorderColor = Color3.fromRGB(255, 212, 200) },
		["Mint Fresh"] = { Primary = Color3.fromRGB(235, 255, 245), Secondary = Color3.fromRGB(240, 255, 250),
			Accent = Color3.fromRGB(245, 255, 248), LogoAccent = Color3.fromRGB(15, 195, 130),
			ActiveColor = Color3.fromRGB(25, 215, 140), TextColor = Color3.fromRGB(20, 45, 30),
			SubTextColor = Color3.fromRGB(90, 125, 100), BorderColor = Color3.fromRGB(205, 250, 225) },
		["Lavender Dream"] = { Primary = Color3.fromRGB(242, 235, 255), Secondary = Color3.fromRGB(232, 225, 250),
			Accent = Color3.fromRGB(250, 240, 255), LogoAccent = Color3.fromRGB(170, 105, 255),
			ActiveColor = Color3.fromRGB(185, 120, 255), TextColor = Color3.fromRGB(45, 30, 65),
			SubTextColor = Color3.fromRGB(125, 105, 150), BorderColor = Color3.fromRGB(220, 200, 250) },
		["Cherry Red"] = { Primary = Color3.fromRGB(255, 235, 238), Secondary = Color3.fromRGB(255, 225, 230),
			Accent = Color3.fromRGB(255, 242, 245), LogoAccent = Color3.fromRGB(225, 35, 75),
			ActiveColor = Color3.fromRGB(240, 55, 90), TextColor = Color3.fromRGB(65, 20, 30),
			SubTextColor = Color3.fromRGB(145, 90, 105), BorderColor = Color3.fromRGB(250, 190, 200) },
		["Cyber Blue"] = { Primary = Color3.fromRGB(225, 245, 255), Secondary = Color3.fromRGB(220, 235, 255),
			Accent = Color3.fromRGB(235, 250, 255), LogoAccent = Color3.fromRGB(0, 145, 255),
			ActiveColor = Color3.fromRGB(0, 175, 255), TextColor = Color3.fromRGB(15, 35, 65),
			SubTextColor = Color3.fromRGB(80, 115, 155), BorderColor = Color3.fromRGB(170, 220, 255) },
		["Golden Cream"] = { Primary = Color3.fromRGB(255, 248, 225), Secondary = Color3.fromRGB(255, 240, 205),
			Accent = Color3.fromRGB(255, 252, 235), LogoAccent = Color3.fromRGB(235, 165, 25),
			ActiveColor = Color3.fromRGB(245, 180, 35), TextColor = Color3.fromRGB(60, 45, 20),
			SubTextColor = Color3.fromRGB(145, 120, 75), BorderColor = Color3.fromRGB(245, 215, 145) },
		["Forest Calm"] = { Primary = Color3.fromRGB(230, 250, 235), Secondary = Color3.fromRGB(220, 245, 225),
			Accent = Color3.fromRGB(240, 255, 242), LogoAccent = Color3.fromRGB(35, 155, 80),
			ActiveColor = Color3.fromRGB(40, 180, 90), TextColor = Color3.fromRGB(20, 55, 30),
			SubTextColor = Color3.fromRGB(85, 125, 95), BorderColor = Color3.fromRGB(175, 230, 185) },
		["Rose Gold"] = { Primary = Color3.fromRGB(255, 238, 235), Secondary = Color3.fromRGB(250, 225, 220),
			Accent = Color3.fromRGB(255, 245, 242), LogoAccent = Color3.fromRGB(205, 105, 115),
			ActiveColor = Color3.fromRGB(225, 125, 135), TextColor = Color3.fromRGB(65, 30, 35),
			SubTextColor = Color3.fromRGB(145, 100, 105), BorderColor = Color3.fromRGB(240, 195, 190) },
	}
	local PaletteNames = {
		"Bubblegum", "Dark Pastel", "Ocean Mist", "Sunset Glow", "Mint Fresh",
		"Lavender Dream", "Cherry Red", "Cyber Blue", "Golden Cream", "Forest Calm", "Rose Gold",
	}
	local function GeneratePalette(preset)
		local p, s, a, white = preset.Primary, preset.Secondary, preset.Accent, Color3.fromRGB(255, 255, 255)
		return { p:Lerp(white, 0.2), p:Lerp(s, 0.15), s:Lerp(white, 0.25), s:Lerp(a, 0.2), a:Lerp(white, 0.2) }
	end
	local function ApplyPalette(selected)
		local p = PalettePresets[selected]
		if not p then return end
		DynamicContext.CurrentPreset = p
		DynamicContext.TargetPalette = GeneratePalette(p)
		DynamicContext.TargetLogoColor = p.LogoAccent
		DynamicContext.TargetActiveColor = p.ActiveColor
		DynamicContext.TargetTextColor = p.TextColor
		DynamicContext.TargetSubTextColor = p.SubTextColor
		DynamicContext.TargetBorderColor = p.BorderColor
	end
	local defaultPreset = PalettePresets["Bubblegum"]
	DynamicContext.CurrentPreset = defaultPreset
	DynamicContext.CurrentPalette = GeneratePalette(defaultPreset)
	DynamicContext.TargetPalette = DynamicContext.CurrentPalette
	DynamicContext.CurrentLogoColor = defaultPreset.LogoAccent
	DynamicContext.TargetLogoColor = DynamicContext.CurrentLogoColor
	DynamicContext.CurrentActiveColor = defaultPreset.ActiveColor
	DynamicContext.TargetActiveColor = DynamicContext.CurrentActiveColor
	DynamicContext.CurrentTextColor = defaultPreset.TextColor
	DynamicContext.TargetTextColor = DynamicContext.CurrentTextColor
	DynamicContext.CurrentSubTextColor = defaultPreset.SubTextColor
	DynamicContext.TargetSubTextColor = DynamicContext.CurrentSubTextColor
	DynamicContext.CurrentBorderColor = defaultPreset.BorderColor
	DynamicContext.TargetBorderColor = DynamicContext.CurrentBorderColor

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "LinkCcUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.DisplayOrder = 999999
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.IgnoreGuiInset = true
	pcall(function() ScreenGui.Parent = CoreGui end)
	if not ScreenGui.Parent then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end
	DynamicContext.ScreenGui = ScreenGui

	local function MakeDraggable(dragHandle, targetFrame)
		local dragging, dragStart, startPos
		dragHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = Vector2.new(input.Position.X, input.Position.Y)
				startPos = targetFrame.Position
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
				targetFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	local MainFrame = Instance.new("CanvasGroup")
	MainFrame.Name = "MainFrame"
	HUB.mainFrame = MainFrame
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.Size = UDim2.new(0, 530, 0, 320)
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.GroupTransparency = 1
	MainFrame.ZIndex = 10
	MainFrame.Parent = ScreenGui

	local MainUIScale = Instance.new("UIScale", MainFrame)
	MainUIScale.Scale = 1
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)
	local MainStroke = Instance.new("UIStroke", MainFrame)
	MainStroke.Thickness = 2
	MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	MainStroke.Color = Color3.fromRGB(255, 255, 255)
	local StrokeGradient = Instance.new("UIGradient", MainStroke)
	StrokeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(210, 210, 210)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(210, 210, 210)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 255, 255)),
	})
	local MainGradient = Instance.new("UIGradient", MainFrame)

	local TopBar = Instance.new("Frame")
	TopBar.Name = "TopBar"
	TopBar.Size = UDim2.new(1, 0, 0, 42)
	TopBar.BackgroundTransparency = 1
	TopBar.Active = true
	TopBar.ZIndex = 11
	TopBar.Parent = MainFrame

	local LogoBtn = Instance.new("TextButton")
	LogoBtn.Size = UDim2.new(0, 180, 1, 0)
	LogoBtn.Position = UDim2.new(0.5, -90, 0, 0)
	LogoBtn.Font = Enum.Font.FredokaOne
	LogoBtn.Text = "Link.cc"
	LogoBtn.TextColor3 = DynamicContext.CurrentLogoColor
	LogoBtn.TextSize = 24
	LogoBtn.BackgroundTransparency = 1
	LogoBtn.AutoButtonColor = false
	LogoBtn.Selectable = false
	LogoBtn.ZIndex = 12
	LogoBtn.Parent = TopBar

	local StatusDot = Instance.new("Frame")
	StatusDot.Size = UDim2.new(0, 6, 0, 6)
	StatusDot.Position = UDim2.new(1, -95, 0.5, -3)
	StatusDot.BackgroundColor3 = Color3.fromRGB(60, 210, 100)
	StatusDot.ZIndex = 12
	StatusDot.Parent = TopBar
	Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

	local StatusText = Instance.new("TextLabel")
	StatusText.Size = UDim2.new(0, 80, 1, 0)
	StatusText.Position = UDim2.new(1, -85, 0, 0)
	StatusText.Font = Enum.Font.GothamMedium
	StatusText.Text = "运行中"
	StatusText.TextColor3 = DynamicContext.CurrentSubTextColor
	StatusText.TextSize = 11
	StatusText.TextXAlignment = Enum.TextXAlignment.Left
	StatusText.BackgroundTransparency = 1
	StatusText.ZIndex = 12
	StatusText.Parent = TopBar
	table.insert(DynamicContext.TextElements, { Obj = StatusText, Type = "Sub" })

	MakeDraggable(TopBar, MainFrame)

	local ContentArea = Instance.new("Frame")
	ContentArea.Name = "ContentArea"
	ContentArea.Size = UDim2.new(1, -24, 1, -54)
	ContentArea.Position = UDim2.new(0, 12, 0, 42)
	ContentArea.BackgroundTransparency = 1
	ContentArea.ZIndex = 11
	ContentArea.Parent = MainFrame

	local NavCard = Instance.new("Frame")
	NavCard.Name = "NavCard"
	NavCard.Size = UDim2.new(0, 116, 1, 0)
	NavCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	NavCard.BackgroundTransparency = 0.15
	NavCard.ZIndex = 12
	NavCard.Parent = ContentArea
	Instance.new("UICorner", NavCard).CornerRadius = UDim.new(0, 12)
	local NavStroke = Instance.new("UIStroke", NavCard)
	NavStroke.Thickness = 1
	NavStroke.Transparency = 0.2
	NavStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, NavStroke)

	local MainConfigCard = Instance.new("Frame")
	MainConfigCard.Name = "MainConfigCard"
	MainConfigCard.Position = UDim2.new(0, 124, 0, 0)
	MainConfigCard.Size = UDim2.new(0, 232, 1, 0)
	MainConfigCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	MainConfigCard.BackgroundTransparency = 0.15
	MainConfigCard.ClipsDescendants = true
	MainConfigCard.ZIndex = 12
	MainConfigCard.Parent = ContentArea
	Instance.new("UICorner", MainConfigCard).CornerRadius = UDim.new(0, 12)
	local MainConfigStroke = Instance.new("UIStroke", MainConfigCard)
	MainConfigStroke.Thickness = 1
	MainConfigStroke.Transparency = 0.2
	MainConfigStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, MainConfigStroke)

	local SubMaskContainer = Instance.new("Frame")
	SubMaskContainer.Name = "SubMaskContainer"
	SubMaskContainer.Size = UDim2.new(0, 134, 1, 0)
	SubMaskContainer.Position = UDim2.new(0, 364, 0, 0)
	SubMaskContainer.BackgroundTransparency = 1
	SubMaskContainer.ZIndex = 12
	SubMaskContainer.Parent = ContentArea

	local SubConfigCard = Instance.new("Frame")
	SubConfigCard.Name = "SubConfigCard"
	SubConfigCard.Size = UDim2.new(1, 0, 1, 0)
	SubConfigCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	SubConfigCard.BackgroundTransparency = 0.15
	SubConfigCard.ClipsDescendants = true
	SubConfigCard.ZIndex = 12
	SubConfigCard.Parent = SubMaskContainer
	Instance.new("UICorner", SubConfigCard).CornerRadius = UDim.new(0, 12)
	local SubConfigStroke = Instance.new("UIStroke", SubConfigCard)
	SubConfigStroke.Thickness = 1
	SubConfigStroke.Transparency = 0.2
	SubConfigStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, SubConfigStroke)

	task.spawn(function()
		MainFrame.Size = UDim2.new(0, 500, 0, 300)
		MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		MainFrame.GroupTransparency = 1
		safeTween(MainFrame, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 530, 0, 320),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			GroupTransparency = 0,
		})
	end)

	local SIZE_MAIN_NORMAL = UDim2.new(0, 232, 1, 0)
	local SIZE_MAIN_EXPAND = UDim2.new(0, 374, 1, 0)
	local function AdjustLayoutMode(showSubCard)
		if DynamicContext.IsSubCardActive == showSubCard then return end
		DynamicContext.IsSubCardActive = showSubCard
		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		if showSubCard then
			SubMaskContainer.Visible = true
			SubConfigCard.Visible = true
			safeTween(MainConfigCard, tweenInfo, { Size = SIZE_MAIN_NORMAL })
			safeTween(SubConfigCard, tweenInfo, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.15 })
			safeTween(SubConfigStroke, tweenInfo, { Transparency = 0.2 })
		else
			safeTween(MainConfigCard, tweenInfo, { Size = SIZE_MAIN_EXPAND })
			local subTween = safeTween(SubConfigCard, tweenInfo, { Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1 })
			safeTween(SubConfigStroke, tweenInfo, { Transparency = 1 })
			if subTween then
				subTween.Completed:Connect(function()
					if not DynamicContext.IsSubCardActive then
						SubMaskContainer.Visible = false
						SubConfigCard.Visible = false
					end
				end)
			end
		end
	end

	local function CreateScrollList(parent, topOffset)
		topOffset = topOffset or 68
		local Scroll = Instance.new("ScrollingFrame")
		Scroll.Size = UDim2.new(1, 0, 1, -topOffset)
		Scroll.Position = UDim2.new(0, 0, 0, topOffset)
		Scroll.BackgroundTransparency = 1
		Scroll.BorderSizePixel = 0
		Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		Scroll.ScrollBarThickness = 3
		Scroll.ScrollBarImageColor3 = Color3.fromRGB(150, 160, 180)
		Scroll.ScrollBarImageTransparency = 0.5
		Scroll.ZIndex = 13
		Scroll.Parent = parent
		local List = Instance.new("UIListLayout", Scroll)
		List.Padding = UDim.new(0, 8)
		List.HorizontalAlignment = Enum.HorizontalAlignment.Center
		List.SortOrder = Enum.SortOrder.LayoutOrder
		local UIPadding = Instance.new("UIPadding", Scroll)
		UIPadding.PaddingTop = UDim.new(0, 4)
		UIPadding.PaddingBottom = UDim.new(0, 12)
		return Scroll
	end

	local function ClearContainer(container)
		if not container then return end
		for _, child in ipairs(container:GetChildren()) do
			if not child:IsA("UICorner") and not child:IsA("UIStroke") then
				pcall(function() child:Destroy() end)
			end
		end
	end

	local function CreateTitle(parent, text)
		local Title = Instance.new("TextLabel", parent)
		Title.Size = UDim2.new(1, -20, 0, 25)
		Title.Position = UDim2.new(0, 10, 0, 6)
		Title.Text = text
		Title.Font = Enum.Font.GothamBold
		Title.TextColor3 = DynamicContext.CurrentTextColor
		Title.TextSize = 13
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.BackgroundTransparency = 1
		Title.ZIndex = 13
		table.insert(DynamicContext.TextElements, { Obj = Title, Type = "Main" })
		return Title
	end

	local function AddButton(parent, title, subText, callback)
		local Frame = Instance.new("CanvasGroup")
		Frame.Size = UDim2.new(1, -12, 0, 38)
		Frame.BackgroundTransparency = 1
		Frame.ZIndex = 14
		Frame.Parent = parent
		local Btn = Instance.new("TextButton", Frame)
		Btn.Size = UDim2.new(1, 0, 1, 0)
		Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Btn.BackgroundTransparency = 0.6
		Btn.Text = ""
		Btn.AutoButtonColor = false
		Btn.Selectable = false
		Btn.ZIndex = 14
		Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
		local BtnStroke = Instance.new("UIStroke", Btn)
		BtnStroke.Thickness = 1
		BtnStroke.Transparency = 0.5
		BtnStroke.Color = DynamicContext.CurrentBorderColor
		table.insert(DynamicContext.BorderElements, BtnStroke)
		local Label = Instance.new("TextLabel", Btn)
		Label.Size = UDim2.new(1, -16, 0, subText and 16 or 30)
		Label.Position = UDim2.new(0, 10, 0, subText and 2 or 0)
		Label.Text = title
		Label.Font = Enum.Font.GothamMedium
		Label.TextColor3 = DynamicContext.CurrentTextColor
		Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.BackgroundTransparency = 1
		Label.ZIndex = 15
		table.insert(DynamicContext.TextElements, { Obj = Label, Type = "Main" })
		if subText then
			local SubLabel = Instance.new("TextLabel", Btn)
			SubLabel.Size = UDim2.new(1, -16, 0, 12)
			SubLabel.Position = UDim2.new(0, 10, 0, 20)
			SubLabel.Text = subText
			SubLabel.Font = Enum.Font.Gotham
			SubLabel.TextColor3 = DynamicContext.CurrentSubTextColor
			SubLabel.TextSize = 8
			SubLabel.TextXAlignment = Enum.TextXAlignment.Left
			SubLabel.BackgroundTransparency = 1
			SubLabel.ZIndex = 15
			table.insert(DynamicContext.TextElements, { Obj = SubLabel, Type = "Sub" })
		end
		Btn.MouseButton1Click:Connect(function()
			if callback then callback() end
		end)
		return Frame
	end

	local function AddToggle(parent, title, subText, default, callback)
		local Frame = Instance.new("CanvasGroup")
		Frame.Size = UDim2.new(1, -12, 0, 38)
		Frame.BackgroundTransparency = 1
		Frame.ZIndex = 14
		Frame.Parent = parent
		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(0.62, 0, 0, 16)
		Label.Position = UDim2.new(0, 0, 0, 2)
		Label.Text = title
		Label.Font = Enum.Font.GothamMedium
		Label.TextColor3 = DynamicContext.CurrentTextColor
		Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.TextTruncate = Enum.TextTruncate.AtEnd
		Label.BackgroundTransparency = 1
		Label.ZIndex = 14
		table.insert(DynamicContext.TextElements, { Obj = Label, Type = "Main" })
		if subText then
			local SubLabel = Instance.new("TextLabel", Frame)
			SubLabel.Size = UDim2.new(1, -45, 0, 12)
			SubLabel.Position = UDim2.new(0, 0, 0, 20)
			SubLabel.Text = subText
			SubLabel.Font = Enum.Font.Gotham
			SubLabel.TextColor3 = DynamicContext.CurrentSubTextColor
			SubLabel.TextSize = 8
			SubLabel.TextXAlignment = Enum.TextXAlignment.Left
			SubLabel.TextTruncate = Enum.TextTruncate.AtEnd
			SubLabel.BackgroundTransparency = 1
			SubLabel.ZIndex = 14
			table.insert(DynamicContext.TextElements, { Obj = SubLabel, Type = "Sub" })
		end
		local Track = Instance.new("TextButton", Frame)
		Track.Size = UDim2.new(0, 36, 0, 18)
		Track.Position = UDim2.new(1, -38, 0.5, -9)
		Track.BackgroundColor3 = Color3.fromRGB(200, 205, 215)
		Track.Text = ""
		Track.AutoButtonColor = false
		Track.Selectable = false
		Track.ZIndex = 15
		Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)
		local Knob = Instance.new("Frame", Track)
		Knob.Size = UDim2.new(0, 14, 0, 14)
		Knob.AnchorPoint = Vector2.new(0, 0.5)
		Knob.Position = UDim2.new(0, 2, 0.5, 0)
		Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Knob.ZIndex = 16
		Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
		local toggled = default or false
		local lastColor = Track.BackgroundColor3
		local function setToggleState(state, animate)
			toggled = state
			local targetColor = toggled and DynamicContext.CurrentActiveColor or Color3.fromRGB(205, 210, 220)
			local targetPos = toggled and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
			if animate then
				safeTween(Track, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundColor3 = targetColor })
				safeTween(Knob, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = targetPos })
			else
				Track.BackgroundColor3 = targetColor
				Knob.Position = targetPos
			end
			lastColor = targetColor
			if callback then callback(toggled) end
		end
		Track.MouseButton1Click:Connect(function() setToggleState(not toggled, true) end)
		setToggleState(toggled, false)
		table.insert(DynamicContext.ActiveToggles, {
			Update = function()
				local targetColor = toggled and DynamicContext.CurrentActiveColor or Color3.fromRGB(205, 210, 220)
				if targetColor ~= lastColor then
					lastColor = targetColor
					safeTween(Track, TweenInfo.new(0.3), { BackgroundColor3 = targetColor })
				end
			end,
		})
		return Frame
	end

	local function AddSlider(parent, title, min, max, default, unit, callback)
		local Frame = Instance.new("CanvasGroup")
		Frame.Size = UDim2.new(1, -12, 0, 38)
		Frame.BackgroundTransparency = 1
		Frame.ZIndex = 14
		Frame.Parent = parent
		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(0.5, 0, 0, 16)
		Label.Position = UDim2.new(0, 0, 0, 0)
		Label.Text = title
		Label.Font = Enum.Font.GothamMedium
		Label.TextColor3 = DynamicContext.CurrentTextColor
		Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.TextTruncate = Enum.TextTruncate.AtEnd
		Label.BackgroundTransparency = 1
		Label.ZIndex = 14
		table.insert(DynamicContext.TextElements, { Obj = Label, Type = "Main" })
		local ValLabel = Instance.new("TextLabel", Frame)
		ValLabel.Size = UDim2.new(0.5, 0, 0, 16)
		ValLabel.Position = UDim2.new(0.5, 0, 0, 0)
		ValLabel.Text = tostring(default) .. (unit or "")
		ValLabel.Font = Enum.Font.Gotham
		ValLabel.TextColor3 = DynamicContext.CurrentSubTextColor
		ValLabel.TextSize = 10
		ValLabel.TextXAlignment = Enum.TextXAlignment.Right
		ValLabel.BackgroundTransparency = 1
		ValLabel.ZIndex = 14
		table.insert(DynamicContext.TextElements, { Obj = ValLabel, Type = "Sub" })
		local TrackBtn = Instance.new("TextButton", Frame)
		TrackBtn.Size = UDim2.new(1, 0, 0, 14)
		TrackBtn.Position = UDim2.new(0, 0, 0, 18)
		TrackBtn.BackgroundTransparency = 1
		TrackBtn.Text = ""
		TrackBtn.AutoButtonColor = false
		TrackBtn.Selectable = false
		TrackBtn.ZIndex = 15
		local SliderBg = Instance.new("Frame", TrackBtn)
		SliderBg.Size = UDim2.new(1, 0, 0, 5)
		SliderBg.Position = UDim2.new(0, 0, 0.5, -2)
		SliderBg.BackgroundColor3 = Color3.fromRGB(215, 220, 230)
		SliderBg.ZIndex = 15
		Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(1, 0)
		local startRatio = math.clamp((default - min) / (max - min), 0, 1)
		local SliderFill = Instance.new("Frame", SliderBg)
		SliderFill.Size = UDim2.new(startRatio, 0, 1, 0)
		SliderFill.BackgroundColor3 = DynamicContext.CurrentActiveColor
		SliderFill.ZIndex = 15
		Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)
		local Knob = Instance.new("Frame", SliderFill)
		Knob.Size = UDim2.new(0, 10, 0, 10)
		Knob.Position = UDim2.new(1, -5, 0.5, -5)
		Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Knob.ZIndex = 16
		Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
		local lastFillColor = SliderFill.BackgroundColor3
		local slidingConn, endConn
		local function update(input)
			local posX = input.Position.X - SliderBg.AbsolutePosition.X
			local ratio = math.clamp(posX / SliderBg.AbsoluteSize.X, 0, 1)
			local raw = min + (max - min) * ratio
			local val = raw
			if max - min > 5 then val = math.floor(raw)
			else val = math.floor(raw * 10 + 0.5) / 10 end
			SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
			ValLabel.Text = tostring(val) .. (unit or "")
			if callback then callback(val) end
		end
		TrackBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				update(input)
				if slidingConn then slidingConn:Disconnect() end
				if endConn then endConn:Disconnect() end
				slidingConn = UIS.InputChanged:Connect(function(moveInput)
					if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
						update(moveInput)
					end
				end)
				endConn = UIS.InputEnded:Connect(function(endInput)
					if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
						if slidingConn then slidingConn:Disconnect() end
						if endConn then endConn:Disconnect() end
					end
				end)
			end
		end)
		table.insert(DynamicContext.ActiveSliders, {
			Update = function()
				if DynamicContext.CurrentActiveColor ~= lastFillColor then
					lastFillColor = DynamicContext.CurrentActiveColor
					safeTween(SliderFill, TweenInfo.new(0.3), { BackgroundColor3 = lastFillColor })
				end
			end,
		})
		return Frame
	end

	local function AddDropdown(parent, title, options, defaultIndex, callback)
		local DropFrame = Instance.new("CanvasGroup")
		DropFrame.Size = UDim2.new(1, -12, 0, 32)
		DropFrame.BackgroundTransparency = 1
		DropFrame.ClipsDescendants = true
		DropFrame.ZIndex = 20
		DropFrame.Parent = parent
		local DropBg = Instance.new("Frame", DropFrame)
		DropBg.Size = UDim2.new(1, 0, 1, 0)
		DropBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		DropBg.BackgroundTransparency = 0
		DropBg.ZIndex = 20
		Instance.new("UICorner", DropBg).CornerRadius = UDim.new(0, 6)
		local DropStroke = Instance.new("UIStroke", DropBg)
		DropStroke.Thickness = 1
		DropStroke.Transparency = 0.4
		DropStroke.Color = Color3.fromRGB(200, 200, 200)
		local HeaderBtn = Instance.new("TextButton", DropBg)
		HeaderBtn.Size = UDim2.new(1, 0, 0, 32)
		HeaderBtn.BackgroundTransparency = 1
		HeaderBtn.Text = ""
		HeaderBtn.AutoButtonColor = false
		HeaderBtn.Selectable = false
		HeaderBtn.ZIndex = 21
		local TitleLabel = Instance.new("TextLabel", HeaderBtn)
		TitleLabel.Size = UDim2.new(0.48, 0, 1, 0)
		TitleLabel.Position = UDim2.new(0, 8, 0, 0)
		TitleLabel.Text = title
		TitleLabel.Font = Enum.Font.GothamMedium
		TitleLabel.TextColor3 = DynamicContext.CurrentTextColor
		TitleLabel.TextSize = 10
		TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		TitleLabel.BackgroundTransparency = 1
		TitleLabel.ZIndex = 21
		table.insert(DynamicContext.TextElements, { Obj = TitleLabel, Type = "Main" })
		local SelectedLabel = Instance.new("TextLabel", HeaderBtn)
		SelectedLabel.Size = UDim2.new(0.42, -10, 1, 0)
		SelectedLabel.Position = UDim2.new(0.48, 0, 0, 0)
		SelectedLabel.Text = options[defaultIndex or 1] or "选择..."
		SelectedLabel.Font = Enum.Font.Gotham
		SelectedLabel.TextColor3 = DynamicContext.CurrentSubTextColor
		SelectedLabel.TextSize = 9
		SelectedLabel.TextXAlignment = Enum.TextXAlignment.Right
		SelectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
		SelectedLabel.BackgroundTransparency = 1
		SelectedLabel.ZIndex = 21
		table.insert(DynamicContext.TextElements, { Obj = SelectedLabel, Type = "Sub" })
		local ArrowLabel = Instance.new("TextLabel", HeaderBtn)
		ArrowLabel.Size = UDim2.new(0, 14, 1, 0)
		ArrowLabel.Position = UDim2.new(1, -16, 0, 0)
		ArrowLabel.Text = "▼"
		ArrowLabel.Font = Enum.Font.GothamBold
		ArrowLabel.TextColor3 = DynamicContext.CurrentSubTextColor
		ArrowLabel.TextSize = 8
		ArrowLabel.BackgroundTransparency = 1
		ArrowLabel.ZIndex = 21
		table.insert(DynamicContext.TextElements, { Obj = ArrowLabel, Type = "Sub" })
		local OptionContainer = Instance.new("Frame", DropBg)
		OptionContainer.Size = UDim2.new(1, -10, 0, 0)
		OptionContainer.Position = UDim2.new(0, 5, 0, 30)
		OptionContainer.BackgroundTransparency = 1
		OptionContainer.ClipsDescendants = true
		OptionContainer.ZIndex = 21
		local OptionList = Instance.new("UIListLayout", OptionContainer)
		OptionList.Padding = UDim.new(0, 3)
		OptionList.SortOrder = Enum.SortOrder.LayoutOrder
		local isExpanded = false
		local optionHeight, expandedHeight = 22, 34 + (#options * 25)
		for i, optionText in ipairs(options) do
			local OptBtn = Instance.new("TextButton", OptionContainer)
			OptBtn.Size = UDim2.new(1, 0, 0, optionHeight)
			OptBtn.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
			OptBtn.BackgroundTransparency = (i == (defaultIndex or 1)) and 0.1 or 0.4
			OptBtn.Text = optionText
			OptBtn.Font = Enum.Font.Gotham
			OptBtn.TextColor3 = Color3.fromRGB(60, 60, 60)
			OptBtn.TextSize = 9
			OptBtn.TextTruncate = Enum.TextTruncate.AtEnd
			OptBtn.AutoButtonColor = false
			OptBtn.Selectable = false
			OptBtn.ZIndex = 22
			Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)
			OptBtn.MouseButton1Click:Connect(function()
				SelectedLabel.Text = optionText
				for _, child in ipairs(OptionContainer:GetChildren()) do
					if child:IsA("TextButton") then
						safeTween(child, TweenInfo.new(0.2), { BackgroundTransparency = (child == OptBtn) and 0.1 or 0.4 })
					end
				end
				isExpanded = false
				local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				safeTween(DropFrame, tweenInfo, { Size = UDim2.new(1, -12, 0, 32) })
				safeTween(OptionContainer, tweenInfo, { Size = UDim2.new(1, -10, 0, 0) })
				safeTween(ArrowLabel, tweenInfo, { Rotation = 0 })
				if callback then callback(optionText, i) end
			end)
		end
		HeaderBtn.MouseButton1Click:Connect(function()
			isExpanded = not isExpanded
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			if isExpanded then
				safeTween(DropFrame, tweenInfo, { Size = UDim2.new(1, -12, 0, expandedHeight) })
				safeTween(OptionContainer, tweenInfo, { Size = UDim2.new(1, -10, 0, #options * 25) })
				safeTween(ArrowLabel, tweenInfo, { Rotation = 180 })
			else
				safeTween(DropFrame, tweenInfo, { Size = UDim2.new(1, -12, 0, 32) })
				safeTween(OptionContainer, tweenInfo, { Size = UDim2.new(1, -10, 0, 0) })
				safeTween(ArrowLabel, tweenInfo, { Rotation = 0 })
			end
		end)
		return DropFrame
	end

	local COLOR_CYCLE = {
		Color3.fromRGB(70, 255, 110), Color3.fromRGB(255, 105, 180), Color3.fromRGB(255, 60, 60),
		Color3.fromRGB(200, 80, 255), Color3.fromRGB(255, 220, 0), Color3.fromRGB(0, 230, 255),
		Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 140, 0),
	}
	local function AddColor(parent, title, get, set)
		local Frame = Instance.new("CanvasGroup")
		Frame.Size = UDim2.new(1, -12, 0, 30)
		Frame.BackgroundTransparency = 1
		Frame.ZIndex = 14
		Frame.Parent = parent
		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(1, -60, 1, 0)
		Label.Position = UDim2.new(0, 0, 0, 0)
		Label.Text = title
		Label.Font = Enum.Font.GothamMedium
		Label.TextColor3 = DynamicContext.CurrentTextColor
		Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.BackgroundTransparency = 1
		Label.ZIndex = 14
		table.insert(DynamicContext.TextElements, { Obj = Label, Type = "Main" })
		local Swatch = Instance.new("TextButton", Frame)
		Swatch.Size = UDim2.new(0, 36, 0, 18)
		Swatch.Position = UDim2.new(1, -38, 0.5, -9)
		Swatch.BackgroundColor3 = get()
		Swatch.Text = ""
		Swatch.AutoButtonColor = false
		Swatch.Selectable = false
		Swatch.ZIndex = 15
		Instance.new("UICorner", Swatch).CornerRadius = UDim.new(0, 4)
		Swatch.MouseButton1Click:Connect(function()
			local cur = get()
			local idx = 1
			for i, c in ipairs(COLOR_CYCLE) do
				if c == cur then idx = i; break end
			end
			idx = idx % #COLOR_CYCLE + 1
			set(COLOR_CYCLE[idx])
			Swatch.BackgroundColor3 = COLOR_CYCLE[idx]
		end)
		return Frame
	end

	local function CreateSubSegmentNav(parent, segments, onSegmentChanged)
		local SegmentFrame = Instance.new("Frame")
		SegmentFrame.Size = UDim2.new(1, -16, 0, 26)
		SegmentFrame.Position = UDim2.new(0, 8, 0, 32)
		SegmentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		SegmentFrame.BackgroundTransparency = 0.4
		SegmentFrame.BorderSizePixel = 0
		SegmentFrame.ZIndex = 15
		SegmentFrame.Parent = parent
		Instance.new("UICorner", SegmentFrame).CornerRadius = UDim.new(0, 13)
		local SegStroke = Instance.new("UIStroke", SegmentFrame)
		SegStroke.Thickness = 1
		SegStroke.Transparency = 0.5
		SegStroke.Color = DynamicContext.CurrentBorderColor
		table.insert(DynamicContext.BorderElements, SegStroke)
		local Indicator = Instance.new("Frame", SegmentFrame)
		Indicator.Size = UDim2.new(1 / #segments, -4, 1, -4)
		Indicator.Position = UDim2.new(0, 2, 0, 2)
		Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Indicator.BackgroundTransparency = 0.1
		Indicator.ZIndex = 16
		Instance.new("UICorner", Indicator).CornerRadius = UDim.new(0, 11)
		local currentIdx = 0
		local Buttons = {}
		local function selectSegment(index, animate)
			if currentIdx == index then return end
			currentIdx = index
			for j, b in ipairs(Buttons) do
				b.TextColor3 = (j == index) and DynamicContext.CurrentTextColor or DynamicContext.CurrentSubTextColor
			end
			if animate then
				safeTween(Indicator, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.new((index - 1) * (1 / #segments), 2, 0, 2),
				})
			else
				Indicator.Position = UDim2.new((index - 1) * (1 / #segments), 2, 0, 2)
			end
			if onSegmentChanged then onSegmentChanged(segments[index], index) end
		end
		for i, segName in ipairs(segments) do
			local Btn = Instance.new("TextButton", SegmentFrame)
			Btn.Size = UDim2.new(1 / #segments, 0, 1, 0)
			Btn.Position = UDim2.new((i - 1) * (1 / #segments), 0, 0, 0)
			Btn.BackgroundTransparency = 1
			Btn.Text = segName
			Btn.Font = Enum.Font.GothamBold
			Btn.TextColor3 = (i == 1) and DynamicContext.CurrentTextColor or DynamicContext.CurrentSubTextColor
			Btn.TextSize = 9
			Btn.AutoButtonColor = false
			Btn.Selectable = false
			Btn.ZIndex = 17
			Btn.MouseButton1Click:Connect(function() selectSegment(i, true) end)
			table.insert(Buttons, Btn)
		end
		selectSegment(1, false)
		return SegmentFrame
	end

	local function AnimateSubPageTransition(container, buildContentFunc)
		for _, child in ipairs(container:GetChildren()) do
			if child.Name == "SubContentPage" then
				child.Parent = nil
				child:Destroy()
			end
		end
		local newPage = Instance.new("CanvasGroup")
		newPage.Name = "SubContentPage"
		newPage.Size = UDim2.new(1, 0, 1, -68)
		newPage.Position = UDim2.new(0, 0, 0, 78)
		newPage.BackgroundTransparency = 1
		newPage.GroupTransparency = 1
		newPage.ZIndex = 14
		newPage.Parent = container
		local Scroll = CreateScrollList(newPage, 0)
		buildContentFunc(Scroll)
		local children = {}
		for _, c in ipairs(Scroll:GetChildren()) do
			if c:IsA("GuiObject") then table.insert(children, c) end
		end
		for i, c in ipairs(children) do
			local origPos = c.Position
			c.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + 15)
			c.GroupTransparency = 1
			task.delay((i - 1) * 0.04, function()
				if c.Parent and c.Parent.Parent == newPage then
					safeTween(c, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
						Position = origPos,
						GroupTransparency = 0,
					})
				end
			end)
		end
		safeTween(newPage, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 68),
			GroupTransparency = 0,
		})
	end

	local function renderStatusPanel(parent)
		ClearContainer(parent)
		CreateTitle(parent, "实时状态")
		local StatusLabel = Instance.new("TextLabel", parent)
		StatusLabel.Size = UDim2.new(1, -16, 0, 64)
		StatusLabel.Position = UDim2.new(0, 8, 0, 34)
		StatusLabel.Text = "等待数据..."
		StatusLabel.Font = Enum.Font.Gotham
		StatusLabel.TextColor3 = DynamicContext.CurrentSubTextColor
		StatusLabel.TextSize = 9
		StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
		StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
		StatusLabel.TextWrapped = true
		StatusLabel.BackgroundTransparency = 1
		StatusLabel.ZIndex = 13
		table.insert(DynamicContext.TextElements, { Obj = StatusLabel, Type = "Sub" })
		DynamicContext.StatusLabel = StatusLabel
		local SubScroll = CreateScrollList(parent, 104)
		AddToggle(SubScroll, "自瞄", nil, CFG.aimbot, function(v)
			CFG.aimbot = v
			if not v then removeAimHook(); Aim.point = nil end
		end)
		AddToggle(SubScroll, "开火", nil, CFG.autoFire, function(v)
			CFG.autoFire = v
			if not v then forceRelease() end
		end)
		AddToggle(SubScroll, "Ragebot", nil, CFG.silentPacket, function(v)
			CFG.silentPacket = v
		end)
	end

	local function createColorRow(parent, title, get, set) return AddColor(parent, title, get, set) end

	local Island = Instance.new("CanvasGroup")
	Island.Name = "DynamicIsland"
	Island.Size = UDim2.new(0, 200, 0, 36)
	Island.Position = UDim2.new(0.5, -100, 0, 15)
	Island.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Island.GroupTransparency = 1
	Island.Visible = false
	Island.ZIndex = 200
	Island.Parent = ScreenGui
	local IslandCorner = Instance.new("UICorner", Island)
	IslandCorner.CornerRadius = UDim.new(0, 18)
	local IslandStroke = Instance.new("UIStroke", Island)
	IslandStroke.Thickness = 2
	IslandStroke.Color = Color3.fromRGB(255, 255, 255)
	local IslandGradient = Instance.new("UIGradient", Island)
	local IslandStrokeGradient = Instance.new("UIGradient", IslandStroke)
	IslandStrokeGradient.Color = StrokeGradient.Color
	local IslandLightOverlay = Instance.new("Frame", Island)
	IslandLightOverlay.Size = UDim2.new(1, 0, 1, 0)
	IslandLightOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	IslandLightOverlay.BackgroundTransparency = 0.35
	IslandLightOverlay.ZIndex = 200
	local IslandContent = Instance.new("Frame", Island)
	IslandContent.Size = UDim2.new(1, 0, 1, 0)
	IslandContent.BackgroundTransparency = 1
	IslandContent.ZIndex = 201
	local IslandLogo = Instance.new("TextLabel", IslandContent)
	IslandLogo.Size = UDim2.new(1, -80, 1, 0)
	IslandLogo.Position = UDim2.new(0, 20, 0, 0)
	IslandLogo.Font = Enum.Font.FredokaOne
	IslandLogo.Text = "Link.cc"
	IslandLogo.TextColor3 = DynamicContext.CurrentLogoColor
	IslandLogo.TextSize = 16
	IslandLogo.TextXAlignment = Enum.TextXAlignment.Left
	IslandLogo.TextYAlignment = Enum.TextYAlignment.Center
	IslandLogo.BackgroundTransparency = 1
	IslandLogo.ZIndex = 202
	local IslandBall = Instance.new("TextLabel", IslandContent)
	IslandBall.Size = UDim2.new(1, 0, 1, 0)
	IslandBall.Font = Enum.Font.FredokaOne
	IslandBall.Text = "L"
	IslandBall.TextColor3 = DynamicContext.CurrentLogoColor
	IslandBall.TextSize = 18
	IslandBall.BackgroundTransparency = 1
	IslandBall.Visible = false
	IslandBall.ZIndex = 204
	local ExpandBtn = Instance.new("TextButton", IslandContent)
	ExpandBtn.Size = UDim2.new(0, 50, 0, 22)
	ExpandBtn.Position = UDim2.new(1, -58, 0.5, -11)
	ExpandBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ExpandBtn.BackgroundTransparency = 0.2
	ExpandBtn.Text = "打开"
	ExpandBtn.Font = Enum.Font.GothamBold
	ExpandBtn.TextColor3 = DynamicContext.CurrentTextColor
	ExpandBtn.TextSize = 10
	ExpandBtn.AutoButtonColor = false
	ExpandBtn.Selectable = false
	ExpandBtn.ZIndex = 203
	Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 11)
	table.insert(DynamicContext.TextElements, { Obj = ExpandBtn, Type = "Main" })
	local WaveBarsContainer = Instance.new("Frame", IslandContent)
	WaveBarsContainer.Size = UDim2.new(0, 120, 1, 0)
	WaveBarsContainer.Position = UDim2.new(0, 18, 0, 0)
	WaveBarsContainer.BackgroundTransparency = 1
	WaveBarsContainer.Visible = false
	WaveBarsContainer.ZIndex = 202
	local waveBars = {}
	for i = 1, 7 do
		local bar = Instance.new("Frame", WaveBarsContainer)
		bar.Size = UDim2.new(0, 5, 0, 6)
		bar.Position = UDim2.new(0, (i - 1) * 14, 0.5, -3)
		bar.BackgroundColor3 = DynamicContext.CurrentLogoColor
		bar.BorderSizePixel = 0
		bar.ZIndex = 203
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
		bar:SetAttribute("PhaseOffset", math.random() * 50)
		bar:SetAttribute("SpeedMultiplier", 0.8 + math.random() * 0.5)
		table.insert(waveBars, bar)
	end

	local AudioIslandModal = Instance.new("CanvasGroup")
	AudioIslandModal.Name = "AudioIslandModal"
	AudioIslandModal.Size = UDim2.new(0, 280, 0, 140)
	AudioIslandModal.Position = UDim2.new(0.5, -140, 0.5, -70)
	AudioIslandModal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	AudioIslandModal.GroupTransparency = 1
	AudioIslandModal.Visible = false
	AudioIslandModal.ZIndex = 300
	AudioIslandModal.Parent = ScreenGui
	Instance.new("UICorner", AudioIslandModal).CornerRadius = UDim.new(0, 22)
	local AudioModalStroke = Instance.new("UIStroke", AudioIslandModal)
	AudioModalStroke.Thickness = 2
	AudioModalStroke.Color = Color3.fromRGB(255, 255, 255)
	local AudioModalStrokeGradient = Instance.new("UIGradient", AudioModalStroke)
	AudioModalStrokeGradient.Color = StrokeGradient.Color
	local AudioModalGradient = Instance.new("UIGradient", AudioIslandModal)
	local AudioModalLightOverlay = Instance.new("Frame", AudioIslandModal)
	AudioModalLightOverlay.Size = UDim2.new(1, 0, 1, 0)
	AudioModalLightOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	AudioModalLightOverlay.BackgroundTransparency = 0.35
	AudioModalLightOverlay.ZIndex = 300
	local InputContainer = Instance.new("Frame", AudioIslandModal)
	InputContainer.Size = UDim2.new(1, -24, 0, 32)
	InputContainer.Position = UDim2.new(0, 12, 0, 12)
	InputContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	InputContainer.BackgroundTransparency = 0.3
	InputContainer.ZIndex = 301
	Instance.new("UICorner", InputContainer).CornerRadius = UDim.new(0, 16)
	local InputStroke = Instance.new("UIStroke", InputContainer)
	InputStroke.Thickness = 1.5
	InputStroke.Color = Color3.fromRGB(255, 255, 255)
	local InputStrokeGradient = Instance.new("UIGradient", InputStroke)
	InputStrokeGradient.Color = StrokeGradient.Color
	local AudioTextBox = Instance.new("TextBox", InputContainer)
	AudioTextBox.Size = UDim2.new(1, -16, 1, 0)
	AudioTextBox.Position = UDim2.new(0, 8, 0, 0)
	AudioTextBox.BackgroundTransparency = 1
	AudioTextBox.Font = Enum.Font.GothamMedium
	AudioTextBox.PlaceholderText = "输入音频 ID..."
	AudioTextBox.PlaceholderColor3 = DynamicContext.CurrentSubTextColor
	AudioTextBox.Text = ""
	AudioTextBox.TextColor3 = DynamicContext.CurrentTextColor
	AudioTextBox.TextSize = 11
	AudioTextBox.ClearTextOnFocus = false
	AudioTextBox.Selectable = false
	AudioTextBox.ZIndex = 302
	table.insert(DynamicContext.TextElements, { Obj = AudioTextBox, Type = "Main" })
	AudioTextBox:GetPropertyChangedSignal("Text"):Connect(function()
		AudioTextBox.Text = AudioTextBox.Text:gsub("%D+", "")
	end)
	local ModalVolumeFrame = Instance.new("Frame", AudioIslandModal)
	ModalVolumeFrame.Size = UDim2.new(1, -24, 0, 32)
	ModalVolumeFrame.Position = UDim2.new(0, 12, 0, 50)
	ModalVolumeFrame.BackgroundTransparency = 1
	ModalVolumeFrame.ZIndex = 301
	AddSlider(ModalVolumeFrame, "音量", 0, 5, 2, "", function(val)
		DynamicContext.CurrentVolume = val
		if DynamicContext.GlobalAudio then DynamicContext.GlobalAudio.Volume = val end
	end)
	local ControlIsland = Instance.new("Frame", AudioIslandModal)
	ControlIsland.Size = UDim2.new(1, -24, 0, 32)
	ControlIsland.Position = UDim2.new(0, 12, 0, 94)
	ControlIsland.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ControlIsland.BackgroundTransparency = 0.25
	ControlIsland.ZIndex = 301
	Instance.new("UICorner", ControlIsland).CornerRadius = UDim.new(0, 16)
	local ControlStroke = Instance.new("UIStroke", ControlIsland)
	ControlStroke.Thickness = 1
	ControlStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, ControlStroke)
	local ConfirmBtn = Instance.new("TextButton", ControlIsland)
	ConfirmBtn.Size = UDim2.new(0.6, -2, 1, -4)
	ConfirmBtn.Position = UDim2.new(0, 2, 0, 2)
	ConfirmBtn.BackgroundColor3 = DynamicContext.CurrentActiveColor
	ConfirmBtn.Text = "确认"
	ConfirmBtn.Font = Enum.Font.GothamBold
	ConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	ConfirmBtn.TextSize = 11
	ConfirmBtn.AutoButtonColor = false
	ConfirmBtn.Selectable = false
	ConfirmBtn.ZIndex = 302
	Instance.new("UICorner", ConfirmBtn).CornerRadius = UDim.new(0, 14)
	local CancelBtn = Instance.new("TextButton", ControlIsland)
	CancelBtn.Size = UDim2.new(0.4, -4, 1, -4)
	CancelBtn.Position = UDim2.new(0.6, 2, 0, 2)
	CancelBtn.BackgroundTransparency = 1
	CancelBtn.Text = "取消"
	CancelBtn.Font = Enum.Font.GothamMedium
	CancelBtn.TextColor3 = DynamicContext.CurrentSubTextColor
	CancelBtn.TextSize = 10
	CancelBtn.AutoButtonColor = false
	CancelBtn.Selectable = false
	CancelBtn.ZIndex = 302
	table.insert(DynamicContext.TextElements, { Obj = CancelBtn, Type = "Sub" })

	local function PlayAntiOverrideAudio(soundId)
		if soundId == "" then return end
		if DynamicContext.GlobalAudio then
			DynamicContext.GlobalAudio:Stop()
			DynamicContext.GlobalAudio:Destroy()
			DynamicContext.GlobalAudio = nil
		end
		local sound = Instance.new("Sound")
		sound.Name = "LinkCcAudioPlayer"
		sound.SoundId = "rbxassetid://" .. tostring(soundId)
		sound.Volume = DynamicContext.CurrentVolume
		sound.Looped = false
		sound.Parent = SoundService
		sound.Ended:Connect(function()
			if DynamicContext.GlobalAudio == sound then
				sound:Destroy()
				DynamicContext.GlobalAudio = nil
			end
		end)
		sound:Play()
		DynamicContext.GlobalAudio = sound
	end
	local function ShowAudioModal()
		AudioIslandModal.Visible = true
		AudioIslandModal.GroupTransparency = 1
		AudioIslandModal.Size = UDim2.new(0, 220, 0, 110)
		AudioIslandModal.Position = UDim2.new(0.5, -110, 0.5, -55)
		safeTween(AudioIslandModal, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			GroupTransparency = 0, Size = UDim2.new(0, 280, 0, 140), Position = UDim2.new(0.5, -140, 0.5, -70),
		})
		AudioTextBox:CaptureFocus()
	end
	local function HideAudioModal(isConfirm)
		local closeTween = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		local tSize = isConfirm and UDim2.new(0, 300, 0, 150) or UDim2.new(0, 240, 0, 120)
		local tPos = isConfirm and UDim2.new(0.5, -150, 0.5, -75) or UDim2.new(0.5, -120, 0.5, -60)
		safeTween(AudioIslandModal, closeTween, { GroupTransparency = 1, Size = tSize, Position = tPos })
		task.delay(0.28, function()
			AudioIslandModal.Visible = false
			if isConfirm then PlayAntiOverrideAudio(AudioTextBox.Text) end
		end)
	end
	ConfirmBtn.MouseButton1Click:Connect(function() HideAudioModal(true) end)
	CancelBtn.MouseButton1Click:Connect(function() HideAudioModal(false) end)
	AudioTextBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then HideAudioModal(true) end
	end)

	local TabData = {
		["General"] = {
			hasSub = true,
			render = function()
				CreateTitle(MainConfigCard, "常规")
				CreateSubSegmentNav(MainConfigCard, { "世界", "移动", "相机", "其它" }, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "世界" then
							AddToggle(scroll, "除雾", nil, CFG.noFog, function(v) CFG.noFog = v; applyWorld() end)
							AddToggle(scroll, "增亮", nil, CFG.mapGlow, function(v) CFG.mapGlow = v; applyWorld() end)
						elseif seg == "移动" then
							AddToggle(scroll, "体力", "无限", CFG.infStamina, function(v) CFG.infStamina = v end)
							AddToggle(scroll, "加速", "覆盖", CFG.customWalkSpeed, function(v)
								CFG.customWalkSpeed = v
								if v then
									local ok = installSpeedHook()
									if not ok then toast("执行器不支持移速覆盖", 3) end
								end
							end)
							AddSlider(scroll, "速度", 16, 120, CFG.walkSpeed, "", function(v) CFG.walkSpeed = v end)
							AddToggle(scroll, "跳力", "覆盖", CFG.customJumpPower, function(v)
								CFG.customJumpPower = v
								if v then
									local ok = installSpeedHook()
									if not ok then toast("执行器不支持跳跃力覆盖", 3) end
								end
							end)
							AddSlider(scroll, "跳跃", 50, 200, CFG.jumpPower, "", function(v) CFG.jumpPower = v end)
							AddToggle(scroll, "防摔", "限速", CFG.noFall, function(v) CFG.noFall = v end)
							AddSlider(scroll, "落速", 20, 200, CFG.fallSpeed, "", function(v) CFG.fallSpeed = v end)
						elseif seg == "相机" then
							AddToggle(scroll, "解锁", "自由缩放", CFG.camUnlock, function(v)
								CFG.camUnlock = v
								pcall(camApply)
								toast(v and "相机已解锁" or "已恢复", 1.8)
							end)
							AddToggle(scroll, "三人称", "强制", CFG.camForceThird, function(v)
								CFG.camForceThird = v
								if v and not CFG.camUnlock then CFG.camUnlock = true end
								pcall(camApply)
								toast(v and "强制三人称" or "已退出", 1.8)
							end)
							AddToggle(scroll, "显身", "全显示", CFG.camBodyVisible, function(v)
								CFG.camBodyVisible = v
								pcall(camApply)
							end)
							AddSlider(scroll, "近距", 0.5, 20, CFG.camMinZoom, "", function(v) CFG.camMinZoom = v; pcall(camApply) end)
							AddSlider(scroll, "远距", 10, 400, CFG.camMaxZoom, "", function(v) CFG.camMaxZoom = v; pcall(camApply) end)
							AddSlider(scroll, "三人距", 6, 40, CFG.camForceMin, "", function(v) CFG.camForceMin = v; pcall(camApply) end)
							AddToggle(scroll, "视角锁", "锁中心", CFG.camLock, function(v)
								CFG.camLock = v
								if v then
									if not CFG.camUnlock then CFG.camUnlock = true end
									toast("视角锁已开", 2)
								else
									UIS.MouseBehavior = Enum.MouseBehavior.Default
									Cam.mouseApplied = false
									toast("视角锁已关", 1.6)
								end
								pcall(camApply)
							end)
							AddToggle(scroll, "冻结", "锁朝向", CFG.camFreeze, function(v)
								CFG.camFreeze = v
								if v then
									if not CFG.camUnlock then CFG.camUnlock = true end
									if not Cam.lockPitch then camCaptureLook() end
								else
									Cam.locked = false
									Cam.lockPitch, Cam.lockYaw, Cam.lockCharYaw = nil, nil, nil
								end
								pcall(camApply)
							end)
							local lockModes = { "固定", "跟随" }
							AddDropdown(scroll, "冻结式", lockModes, CFG.camLockMode == "person" and 2 or 1, function(selected, idx)
								CFG.camLockMode = (idx == 2) and "person" or "fixed"
								Cam.lockPitch = nil; Cam.lockYaw = nil; Cam.lockCharYaw = nil
								pcall(camCaptureLook); pcall(camApply)
							end)
							AddButton(scroll, "重捕获", "镜头朝向", function()
								Cam.lockPitch = nil; Cam.lockYaw = nil; Cam.lockCharYaw = nil
								local okc = camCaptureLook()
								pcall(camApply)
								toast(okc and "已捕获" or "失败", 1.6)
							end)
							AddButton(scroll, "切三人", nil, function() pcall(camSetThird, true); toast("已切三人", 1.6) end)
							AddButton(scroll, "切一人", nil, function() pcall(camSetThird, false); toast("已切一人", 1.6) end)
						else
							AddButton(scroll, "清轨迹", "移除弹道线", function()
								for _, v in ipairs(workspace.Terrain:GetChildren()) do
									if v.Name == "__btrTrail" or v.Name == "__btrMuzzle" or v.Name == "__btrImpact" then
										v:Destroy()
									end
								end
							end)
							AddButton(scroll, "重连接", "修复发包", function()
								Network = nil
								installNetHooks()
								installRayHooks()
								if NB then NB.onFire = onFirePacket; NB.onHit = onHitPacket end
							end)
						end
					end)
				end)
				renderStatusPanel(SubConfigCard)
			end,
		},
		["Combat"] = {
			hasSub = true,
			render = function()
				CreateTitle(MainConfigCard, "战斗")
				CreateSubSegmentNav(MainConfigCard, { "自瞄", "偏移" }, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "自瞄" then
							AddToggle(scroll, "自瞄", nil, CFG.aimbot, function(v) CFG.aimbot = v; if not v then removeAimHook() end end)
							AddToggle(scroll, "静默", nil, CFG.silent, function(v) CFG.silent = v end)
							AddToggle(scroll, "伪装", "上报对齐", CFG.spoofCam, function(v) CFG.spoofCam = v end)
							AddToggle(scroll, "开火", "自动", CFG.autoFire, function(v) CFG.autoFire = v; if not v then forceRelease() end end)
							AddToggle(scroll, "只可见", nil, CFG.visibleOnly, function(v) CFG.visibleOnly = v end)
							AddToggle(scroll, "360°", nil, CFG.aim360, function(v) CFG.aim360 = v end)
							AddSlider(scroll, "角度", 5, 180, CFG.fovAngle, "°", function(v) CFG.fovAngle = v end)
							AddToggle(scroll, "打怪", nil, CFG.aimMonsters, function(v) CFG.aimMonsters = v end)
							AddToggle(scroll, "打人", nil, CFG.aimPlayers, function(v) CFG.aimPlayers = v end)
							AddToggle(scroll, "智能部位", nil, CFG.aimSmartPart, function(v) CFG.aimSmartPart = v end)
							AddToggle(scroll, "补偿", "落点", CFG.dropComp, function(v) CFG.dropComp = v end)
							AddToggle(scroll, "枪口偏移", "绕掩体", CFG.muzzleOffset, function(v) CFG.muzzleOffset = v end)
							AddToggle(scroll, "破盾", nil, CFG.noShield, function(v) CFG.noShield = v end)
							AddSlider(scroll, "FOV", 40, 1600, CFG.fov, "", function(v) CFG.fov = v end)
							local aimParts = {"头", "躯干", "根"}
							local curIdx = 1
							if CFG.aimPart == "Torso" then curIdx = 2
							elseif CFG.aimPart == "HumanoidRootPart" then curIdx = 3 end
							AddDropdown(scroll, "部位", aimParts, curIdx, function(selected, idx)
								if idx == 1 then CFG.aimPart = "Head"
								elseif idx == 2 then CFG.aimPart = "Torso"
								elseif idx == 3 then CFG.aimPart = "HumanoidRootPart" end
							end)
						else
							AddSlider(scroll, "搜索半径", 0.5, 4, CFG.muzzleRadius, "", function(v) CFG.muzzleRadius = v end)
							AddSlider(scroll, "隔墙", 1, 4, CFG.silentWallOffset, "", function(v)
								CFG.silentWallOffset = v; HUB.silentWallCap = v
							end)
							AddSlider(scroll, "绕障", 1, 6, CFG.silentObsOffset, "", function(v)
								CFG.silentObsOffset = v; HUB.silentObsCap = v
							end)
							AddSlider(scroll, "步长", 0.3, 2, CFG.muzzleStep, "", function(v) CFG.muzzleStep = v end)
						end
					end)
				end)
				renderStatusPanel(SubConfigCard)
			end,
		},
		
		["Ragebot"] = {
			hasSub = true,
			render = function()
				CreateTitle(MainConfigCard, "Ragebot")
				CreateSubSegmentNav(MainConfigCard, { "核心", "辅助" }, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "核心" then
							AddToggle(scroll, "Ragebot", "静默", CFG.silentPacket, function(v) CFG.silentPacket = v end)
							
							AddToggle(scroll, "自动换弹", "瞬间补充", CFG.autoReload, function(v) CFG.autoReload = v end)
						else
							AddSlider(scroll, "静默·隔墙最大偏移", 1, 4, CFG.silentWallOffset, "", function(v)
								CFG.silentWallOffset = v; HUB.silentWallCap = v
							end)
							AddSlider(scroll, "静默·绕障碍最大偏移", 1, 6, CFG.silentObsOffset, "", function(v)
								CFG.silentObsOffset = v; HUB.silentObsCap = v
							end)
							AddSlider(scroll, "偏移步长", 0.3, 2, CFG.muzzleStep, "", function(v) CFG.muzzleStep = v end)
						end
					end)
				end)
				renderStatusPanel(SubConfigCard)
			end,
		},
		["Visuals"] = {
			hasSub = true,
			render = function()
				CreateTitle(MainConfigCard, "透视")
				CreateSubSegmentNav(MainConfigCard, { "ESP", "颜色", "轨迹" }, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "ESP" then
							AddToggle(scroll, "玩家", nil, CFG.espPlayers, function(v) CFG.espPlayers = v end)
							AddToggle(scroll, "怪物", nil, CFG.espMonsters, function(v) CFG.espMonsters = v end)
							AddToggle(scroll, "物品", nil, CFG.espItems, function(v) CFG.espItems = v end)
							AddToggle(scroll, "弹药点", nil, CFG.espAmmo, function(v) CFG.espAmmo = v end)
							AddToggle(scroll, "好友", nil, CFG.espFriends, function(v) CFG.espFriends = v end)
							AddToggle(scroll, "方框", nil, CFG.box, function(v) CFG.box = v end)
							AddToggle(scroll, "名字", nil, CFG.name, function(v) CFG.name = v end)
							AddToggle(scroll, "血量", nil, CFG.health, function(v) CFG.health = v end)
							AddToggle(scroll, "距离", nil, CFG.distance, function(v) CFG.distance = v end)
							AddToggle(scroll, "连线", nil, CFG.tracer, function(v) CFG.tracer = v end)
							AddToggle(scroll, "自己", nil, CFG.showSelf, function(v) CFG.showSelf = v end)
							AddSlider(scroll, "最大距离", 50, 2000, CFG.maxDist, "m", function(v) CFG.maxDist = v end)
						elseif seg == "颜色" then
							createColorRow(scroll, "玩家", function() return CFG.colorPlayer end, function(v) CFG.colorPlayer = v end)
							createColorRow(scroll, "好友", function() return CFG.colorFriend end, function(v) CFG.colorFriend = v end)
							createColorRow(scroll, "怪物", function() return CFG.colorMonster end, function(v) CFG.colorMonster = v end)
							createColorRow(scroll, "BOSS", function() return CFG.colorBoss end, function(v) CFG.colorBoss = v end)
							createColorRow(scroll, "物品", function() return CFG.colorItem end, function(v) CFG.colorItem = v end)
							createColorRow(scroll, "弹药", function() return CFG.colorAmmo end, function(v) CFG.colorAmmo = v end)
						else
							AddToggle(scroll, "轨迹", nil, CFG.trail, function(v) CFG.trail = v end)
							AddToggle(scroll, "枪口", nil, CFG.muzzleTrail, function(v) CFG.muzzleTrail = v end)
							AddSlider(scroll, "时长", 1, 10, CFG.trailTime, "s", function(v) CFG.trailTime = v end)
							createColorRow(scroll, "颜色", function() return CFG.trailColor end, function(v) CFG.trailColor = v end)
							AddToggle(scroll, "他人", nil, CFG.otherTrails, function(v) CFG.otherTrails = v end)
							createColorRow(scroll, "队友", function() return CFG.colorTeamTrail end, function(v) CFG.colorTeamTrail = v end)
							createColorRow(scroll, "怪道", function() return CFG.colorEnemyTrail end, function(v) CFG.colorEnemyTrail = v end)
						end
					end)
				end)
				renderStatusPanel(SubConfigCard)
			end,
		},
		["Settings"] = {
			hasSub = true,
			render = function()
				CreateTitle(MainConfigCard, "设置")
				CreateSubSegmentNav(MainConfigCard, { "主题", "音频", "界面" }, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "主题" then
							local curIdx = 1
							for i, n in ipairs(PaletteNames) do
								if PalettePresets[n] == DynamicContext.CurrentPreset then curIdx = i end
							end
							AddDropdown(scroll, "调色板", PaletteNames, curIdx, function(selected)
								ApplyPalette(selected)
							end)
						elseif seg == "音频" then
							AddButton(scroll, "音乐", "播放音频", ShowAudioModal)
						else
							AddSlider(scroll, "缩放", 50, 150, math.floor(MainUIScale.Scale * 100), "%", function(v)
								MainUIScale.Scale = v / 100
							end)
						end
					end)
				end)
				renderStatusPanel(SubConfigCard)
			end,
		},
		["Updates"] = {
			hasSub = false,
			render = function()
				CreateTitle(MainConfigCard, "更新")
				local SubScroll = CreateScrollList(MainConfigCard, 35)
				local lbl = Instance.new("TextLabel", SubScroll)
				lbl.Size = UDim2.new(1, -12, 0, 780)
				lbl.BackgroundTransparency = 1
				lbl.TextWrapped = true
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextYAlignment = Enum.TextYAlignment.Top
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 10
				lbl.TextColor3 = DynamicContext.CurrentSubTextColor
				lbl.Text = table.concat({
					"v2.4",
					"──────────────────────────",
					"",
					"【用户请求】",
					"· 删除 Ragebot 内「真实Ragebot」开关",
					"  （silentReal 字段保留默认 false）",
					"· Ragebot 新增独立「自动换弹」开关",
					"  默认开，可关闭",
					"· 全部功能按中文重新分类",
					"· 功能副标题大幅精简",
					"· 单击 Logo 直接缩小（v2.3 起）",
					"",
					"【v2.3 深度审计修复】",
					"· N-01 Raycast hook 可还原",
					"· N-02 视角锁定鼠标逻辑修复",
					"· N-03 监听全纳入 HUB.conns",
					"· N-04 hlCache 弱引用 + destroy 清理",
					"· N-05 副作用方法收入 Internal",
					"· N-06 缓存弱引用",
					"· N-07 spawnImpact 预算",
					"· N-08 dmgWatch 双条件",
					"· N-09 换弹 10 次轮询",
					"· N-10 camMinZoom 参与约束",
					"· N-11 自瞄排除 isSelf",
					"· N-12 好友 pending 中性色",
					"· N-13 gunConfig 模糊匹配",
					"· N-14 _newindex 链式",
					"· N-15 packetWarned 冷却",
				}, "\n")
				table.insert(DynamicContext.TextElements, { Obj = lbl, Type = "Sub" })
			end,
		},
		["Advanced"] = {
			hasSub = true,
			render = function()
				CreateTitle(MainConfigCard, "高级")
				CreateSubSegmentNav(MainConfigCard, { "调试", "工具" }, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "调试" then
							AddToggle(scroll, "日志", nil, CFG.debugLog, function(v)
								CFG.debugLog = v
								warn("[BTR][debug] " .. (v and "enabled" or "disabled"))
							end)
							AddButton(scroll, "重载网络", nil, function()
								Network = nil
								installNetHooks()
								installRayHooks()
								if NB then NB.onFire = onFirePacket; NB.onHit = onHitPacket end
							end)
							AddButton(scroll, "重载射线", nil, function() installRayHooks() end)
						else
							AddButton(scroll, "静默探测", nil, function()
								local a, b, c, d = Internal.silentProbe()
								toast(string.format("%s / %s / %s / %.1f", tostring(a), tostring(b), tostring(c), d or 0), 3)
							end)
							AddButton(scroll, "重捕获", "镜头", function()
								local ok = Internal.camLockRecapture()
								toast(ok and "已重捕获" or "失败", 1.6)
							end)
						end
					end)
				end)
				renderStatusPanel(SubConfigCard)
			end,
		},
		["Help"] = {
			hasSub = false,
			render = function()
				CreateTitle(MainConfigCard, "帮助")
				CreateSubSegmentNav(MainConfigCard, { "说明", "按键" }, function(seg)
					AnimateSubPageTransition(MainConfigCard, function(scroll)
						if seg == "说明" then
							AddToggle(scroll, "热键", "RightShift", CFG.hotkeyEnabled, function(v) CFG.hotkeyEnabled = v end)
							AddButton(scroll, "单击 Logo", "缩小（默认）", function()
								toast("单击 Logo 已默认缩小", 2.2)
							end)
						else
							AddToggle(scroll, "单击岛", "展开", CFG.islandClickExpand, function(v) CFG.islandClickExpand = v end)
							AddToggle(scroll, "长按岛", "拖动", CFG.islandLongPressDrag, function(v) CFG.islandLongPressDrag = v end)
						end
					end)
				end)
				renderStatusPanel(SubConfigCard)
			end,
		},
	}

	local function SwitchTabWithAnimation(tabName)
		if DynamicContext.CurrentTab == tabName then return end
		DynamicContext.CurrentTab = tabName
		for name, btnObj in pairs(DynamicContext.TabButtons) do
			if btnObj and btnObj.Parent then
				if name == tabName then
					safeTween(btnObj, TweenInfo.new(0.2), { BackgroundTransparency = 0.25 })
					btnObj.TextColor3 = DynamicContext.CurrentTextColor
				else
					safeTween(btnObj, TweenInfo.new(0.2), { BackgroundTransparency = 0.85 })
					btnObj.TextColor3 = DynamicContext.CurrentSubTextColor
				end
			end
		end
		if DynamicContext.TabSwitchThread then
			task.cancel(DynamicContext.TabSwitchThread)
			DynamicContext.TabSwitchThread = nil
		end
		DynamicContext.ActiveToggles = {}
		DynamicContext.ActiveSliders = {}
		DynamicContext.TextElements = {}
		DynamicContext.BorderElements = {}
		ClearContainer(MainConfigCard)
		ClearContainer(SubConfigCard)
		local tabInfo = TabData[tabName]
		if tabInfo then
			AdjustLayoutMode(tabInfo.hasSub)
			tabInfo.render()
		end
	end
	DynamicContext.SwitchTab = SwitchTabWithAnimation

	local NavLayout = Instance.new("UIListLayout", NavCard)
	NavLayout.Padding = UDim.new(0, 4)
	NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local NavPadding = Instance.new("UIPadding", NavCard)
	NavPadding.PaddingTop = UDim.new(0, 8)
	NavPadding.PaddingLeft = UDim.new(0, 8)
	NavPadding.PaddingRight = UDim.new(0, 8)

	local Buttons = {}
	DynamicContext.TabButtons = Buttons
	local Tabs = { "General", "Combat", "Ragebot", "Visuals", "Settings", "Updates", "Advanced", "Help" }
	local TabLabels = { General = "常规", Combat = "战斗", Ragebot = "Ragebot", Visuals = "透视", Settings = "设置", Updates = "更新", Advanced = "高级", Help = "帮助" }
	for _, name in ipairs(Tabs) do
		local Btn = Instance.new("TextButton", NavCard)
		Btn.Size = UDim2.new(1, 0, 0, 28)
		Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Btn.BackgroundTransparency = 0.85
		Btn.Text = TabLabels[name] or name
		Btn.TextColor3 = DynamicContext.CurrentSubTextColor
		Btn.Font = Enum.Font.GothamMedium
		Btn.TextSize = 12
		Btn.AutoButtonColor = false
		Btn.Selectable = false
		Btn.ZIndex = 13
		Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
		Btn:SetAttribute("TabKey", name)
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

	local audioPlayStateLast = false
	table.insert(HUB.conns, Run.RenderStepped:Connect(function(dt)
		local lerpSpeed = math.clamp(dt * 3.5, 0, 1)
		for i = 1, 5 do
			DynamicContext.CurrentPalette[i] = DynamicContext.CurrentPalette[i]:Lerp(DynamicContext.TargetPalette[i], lerpSpeed)
		end
		DynamicContext.CurrentLogoColor = DynamicContext.CurrentLogoColor:Lerp(DynamicContext.TargetLogoColor, lerpSpeed)
		DynamicContext.CurrentActiveColor = DynamicContext.CurrentActiveColor:Lerp(DynamicContext.TargetActiveColor, lerpSpeed)
		DynamicContext.CurrentTextColor = DynamicContext.CurrentTextColor:Lerp(DynamicContext.TargetTextColor, lerpSpeed)
		DynamicContext.CurrentSubTextColor = DynamicContext.CurrentSubTextColor:Lerp(DynamicContext.TargetSubTextColor, lerpSpeed)
		DynamicContext.CurrentBorderColor = DynamicContext.CurrentBorderColor:Lerp(DynamicContext.TargetBorderColor, lerpSpeed)
		LogoBtn.TextColor3 = DynamicContext.CurrentLogoColor
		IslandLogo.TextColor3 = DynamicContext.CurrentLogoColor
		IslandBall.TextColor3 = DynamicContext.CurrentLogoColor
		ConfirmBtn.BackgroundColor3 = DynamicContext.CurrentActiveColor
		for _, item in ipairs(DynamicContext.TextElements) do
			if item.Obj and item.Obj.Parent then
				if item.Type == "Main" then
					item.Obj.TextColor3 = DynamicContext.CurrentTextColor
				elseif item.Type == "Sub" then
					item.Obj.TextColor3 = DynamicContext.CurrentSubTextColor
				end
			end
		end
		for _, stroke in ipairs(DynamicContext.BorderElements) do
			if stroke and stroke.Parent then stroke.Color = DynamicContext.CurrentBorderColor end
		end
		for _, tog in ipairs(DynamicContext.ActiveToggles) do tog.Update() end
		for _, sld in ipairs(DynamicContext.ActiveSliders) do sld.Update() end

		if DynamicContext.StatusLabel and DynamicContext.StatusLabel.Parent then
			DynamicContext.StatusLabel.Text = string.format(
				"目标: %s\n开火: %d   命中: %d/%d\n发包: %d/%d\n枪口: %s %.1f\nFPS: %d",
				STATS.target, STATS.fires, STATS.hits, STATS.hitCalls or 0,
				HUB.packetOK or 0, HUB.packetTries or 0,
				tostring(Aim.offsetKind or (Aim.shotOK and "muzzle" or "none")), Aim.offsetUsed or 0,
				math.floor(HUB.fps or 0))
		end
		StatusText.Text = string.format("FPS %d", math.floor(HUB.fps or 0))

		DynamicContext.BgPhase = DynamicContext.BgPhase + dt * 0.25
		local wave1 = (math.sin(DynamicContext.BgPhase) + 1) / 2
		local wave2 = (math.sin(DynamicContext.BgPhase * 1.3 + 1.2) + 1) / 2
		local c1 = DynamicContext.CurrentPalette[1]:Lerp(DynamicContext.CurrentPalette[2], wave1)
		local c2 = DynamicContext.CurrentPalette[2]:Lerp(DynamicContext.CurrentPalette[4], wave2)
		local c3 = DynamicContext.CurrentPalette[3]:Lerp(DynamicContext.CurrentPalette[5], wave1)
		local newSeq = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, c1),
			ColorSequenceKeypoint.new(0.5, c2),
			ColorSequenceKeypoint.new(1.0, c3),
		})
		MainGradient.Color = newSeq
		MainGradient.Rotation = (MainGradient.Rotation + dt * 8) % 360
		IslandGradient.Color = newSeq
		IslandGradient.Rotation = MainGradient.Rotation
		AudioModalGradient.Color = newSeq
		AudioModalGradient.Rotation = MainGradient.Rotation

		local isPlayingMusic = (DynamicContext.GlobalAudio ~= nil and DynamicContext.GlobalAudio.IsPlaying)
		if isPlayingMusic then
			local soundObj = DynamicContext.GlobalAudio
			local currentVolume = soundObj.Volume or 1
			local progressFactor = 1.0
			if soundObj.TimeLength and soundObj.TimeLength > 0 then
				local remainingTime = soundObj.TimeLength - soundObj.TimePosition
				if remainingTime < 2.0 then
					progressFactor = math.clamp(remainingTime / 2.0, 0.05, 1.0)
				end
			end
			local globalTime = tick()
			local isDJMode = (currentVolume > 1.2)
			local speedScale = isDJMode and 14.0 or 6.0
			local amplitudeMultiplier = (isDJMode and 24.0 or 12.0) * progressFactor
			for idx, bar in ipairs(waveBars) do
				bar.BackgroundColor3 = DynamicContext.CurrentLogoColor
				local phase = bar:GetAttribute("PhaseOffset") or 0
				local speedMult = bar:GetAttribute("SpeedMultiplier") or 1.0
				local t = globalTime * speedScale * speedMult + phase
				local heightFactor = math.abs(math.sin(t)) * 0.7 + math.abs(math.cos(t * 0.7)) * 0.3
				local targetHeight = math.max(4, math.floor(heightFactor * amplitudeMultiplier * (currentVolume / 2) + 4))
				bar.Size = UDim2.new(0, 5, 0, targetHeight)
				bar.Position = UDim2.new(0, (idx - 1) * 14, 0.5, -targetHeight / 2)
			end
			if not audioPlayStateLast then
				audioPlayStateLast = true
				IslandLogo.Visible = false
				WaveBarsContainer.Visible = true
			end
		else
			if audioPlayStateLast then
				audioPlayStateLast = false
				WaveBarsContainer.Visible = false
				IslandLogo.Visible = true
			end
		end
	end))

	local isBallMode, autoBallTask = false, nil
	local function cancelAutoBall()
		if autoBallTask then task.cancel(autoBallTask); autoBallTask = nil end
	end
	local function doSmoothToBall()
		if isBallMode then return end
		isBallMode = true
		cancelAutoBall()
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local centerX = Island.Position.X.Offset + (Island.Size.X.Offset / 2)
		local targetOffset = centerX - 18
		safeTween(Island, tweenInfo, {
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(Island.Position.X.Scale, targetOffset, Island.Position.Y.Scale, Island.Position.Y.Offset),
		})
		safeTween(IslandCorner, tweenInfo, { CornerRadius = UDim.new(1, 0) })
		IslandLogo.Visible = false
		WaveBarsContainer.Visible = false
		ExpandBtn.Visible = false
		IslandBall.Visible = true
	end
	local function doSmoothToRect()
		if not isBallMode then return end
		isBallMode = false
		cancelAutoBall()
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local centerX = Island.Position.X.Offset + (Island.Size.X.Offset / 2)
		local targetOffset = centerX - 100
		local isPlayingMusic = (DynamicContext.GlobalAudio ~= nil and DynamicContext.GlobalAudio.IsPlaying)
		safeTween(Island, tweenInfo, {
			Size = UDim2.new(0, 200, 0, 36),
			Position = UDim2.new(Island.Position.X.Scale, targetOffset, Island.Position.Y.Scale, Island.Position.Y.Offset),
		})
		safeTween(IslandCorner, tweenInfo, { CornerRadius = UDim.new(0, 18) })
		IslandBall.Visible = false
		task.delay(0.2, function()
			if isPlayingMusic then
				WaveBarsContainer.Visible = true
				IslandLogo.Visible = false
			else
				WaveBarsContainer.Visible = false
				IslandLogo.Visible = true
			end
			ExpandBtn.Visible = true
		end)
	end

	local longPressTime = 0.6
	local isIslandDragging = false
	local islandDragStartVec = Vector2.new()
	local islandStartPosUDim = UDim2.new()
	local pressStartTime = 0
	local isPressing = false
	local longPressTask = nil

	Island.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isPressing = true
			pressStartTime = os.clock()
			islandDragStartVec = Vector2.new(input.Position.X, input.Position.Y)
			islandStartPosUDim = Island.Position
			cancelAutoBall()
			if longPressTask then task.cancel(longPressTask) end
			longPressTask = task.delay(longPressTime, function()
				if not CFG.islandLongPressDrag then return end
				if isPressing and not isIslandDragging then
					isIslandDragging = true
					safeTween(IslandStroke, TweenInfo.new(0.2), { Thickness = 4 })
				end
			end)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isPressing then
				local duration = os.clock() - pressStartTime
				isPressing = false
				if longPressTask then task.cancel(longPressTask) end
				if isIslandDragging then
					isIslandDragging = false
					safeTween(IslandStroke, TweenInfo.new(0.2), { Thickness = 2 })
				elseif duration < longPressTime and isBallMode then
					if CFG.islandClickExpand then doSmoothToRect() end
				end
			end
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if isIslandDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - islandDragStartVec
			Island.Position = UDim2.new(islandStartPosUDim.X.Scale, islandStartPosUDim.X.Offset + delta.X,
				islandStartPosUDim.Y.Scale, islandStartPosUDim.Y.Offset + delta.Y)
		end
	end)

	local function HideMainAndShowIsland()
		local shrinkTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		safeTween(MainFrame, shrinkTweenInfo, {
			GroupTransparency = 1, Size = UDim2.new(0, 480, 0, 290), Position = UDim2.new(0.5, 0, 0.5, 0),
		})
		task.delay(0.25, function()
			MainFrame.Visible = false
			MainFrame.Size = UDim2.new(0, 530, 0, 320)
			MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
			local isPlayingMusic = (DynamicContext.GlobalAudio ~= nil and DynamicContext.GlobalAudio.IsPlaying)
			Island.Visible = true
			Island.GroupTransparency = 1
			Island.Size = UDim2.new(0, 140, 0, 30)
			Island.Position = UDim2.new(0.5, -70, 0, 15)
			IslandCorner.CornerRadius = UDim.new(0, 15)
			isBallMode = false
			IslandBall.Visible = false
			if isPlayingMusic then
				WaveBarsContainer.Visible = true
				IslandLogo.Visible = false
			else
				WaveBarsContainer.Visible = false
				IslandLogo.Visible = true
			end
			ExpandBtn.Visible = true
			local islandShowTween = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			safeTween(Island, islandShowTween, {
				GroupTransparency = 0, Size = UDim2.new(0, 200, 0, 36), Position = UDim2.new(0.5, -100, 0, 15),
			})
			safeTween(IslandCorner, islandShowTween, { CornerRadius = UDim.new(0, 18) })
		end)
	end
	local function HideIslandAndShowMain()
		cancelAutoBall()
		local hideIslandTween = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		safeTween(Island, hideIslandTween, {
			GroupTransparency = 1, Size = UDim2.new(0, 150, 0, 30), Position = UDim2.new(0.5, -75, 0, 15),
		})
		task.delay(0.2, function()
			Island.Visible = false
			MainFrame.Visible = true
			MainFrame.GroupTransparency = 1
			MainFrame.Size = UDim2.new(0, 490, 0, 296)
			MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
			safeTween(MainFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				GroupTransparency = 0, Size = UDim2.new(0, 530, 0, 320), Position = UDim2.new(0.5, 0, 0.5, 0),
			})
		end)
	end

	LogoBtn.MouseButton1Click:Connect(function()
		HideMainAndShowIsland()
	end)
	ExpandBtn.MouseButton1Click:Connect(function()
		if not CFG.islandClickExpand then return end
		HideIslandAndShowMain()
	end)

	MainFrame.Visible = true
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.GroupTransparency = 1
	SwitchTabWithAnimation("General")
	safeTween(MainFrame, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })

	UIS.InputBegan:Connect(function(input, gpe)
		if gpe or not CFG.hotkeyEnabled then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			if MainFrame.Visible then HideMainAndShowIsland() else HideIslandAndShowMain() end
		end
	end)

	Internal.hideToIsland = HideMainAndShowIsland
	Internal.showMain = HideIslandAndShowMain
end)

if not UISuccess then
	warn("[BTR-HUB][Link UI] 加载错误: " .. tostring(UIErr))
end

installNetHooks()
installRayHooks()
if NB then
	NB.onFire = onFirePacket
	NB.onHit = onHitPacket
end
if CFG.noFog or CFG.mapGlow then applyWorld() end

camBind()

task.spawn(function()
	task.wait(0.5)
	pcall(scanAmmo)
	HUB.ammoCount = #ammoCache
end)

local function onRespawn()
	Aim.point = nil; Aim.target = nil; Aim.part = nil; Aim.occluded = false
	Aim.gunCfg = nil; Aim.origin = nil; Aim.muzzle = nil; Aim.offsetUsed = nil
	Aim.offsetKind = nil; Aim.muzzleBlocked = false; Aim.hadOrigin = false
	Aim.shotOK = false; Aim.shotDist = 0; Aim.lastOffset = nil
	Aim.packetMuzzle = nil; Aim.packetTarget = nil
	gunCfgCache = setmetatable({}, { __mode = "k" })
	staminaGui.bar = nil; staminaGui.vig = nil; staminaGui.last = 0
	forceRelease()
	HUB.silentAmmo = nil
	HUB.silentAcc = 0
	HUB.silentIdle, HUB.silentIdleAt = 0, 0
	HUB.silentFallbackReal = false
	HUB.packetRetryAt = 0
	HUB.ourCasts = 0
	HUB.packetOK, HUB.packetTries = 0, 0
	HUB.silentBypassHits = 0
	HUB.packetWarned = false
	HUB.packetWarnedAt = 0
	HUB.reloadNotified, HUB.reloadAt = false, 0
	HUB.reloadBusy = false
	HUB.noDamage, HUB.aimPartCycle = 0, 0
	HUB.silentWallCap = CFG.silentWallOffset or 2.5
	HUB.silentObsCap = CFG.silentObsOffset or 4
	HUB.maxOffsetOK = CFG.muzzleRadius or 4
	shotCache.inst, shotCache.ok, shotCache.at = nil, false, 0
	silentScan.at, silentScan.t, silentScan.part = 0, nil, nil
	silentFailAt = setmetatable({}, { __mode = "k" })
	dmgWatch.inst, dmgWatch.hp, dmgWatch.t = nil, nil, 0
	dmgWatch.hitAt, dmgWatch.ammoBefore = 0, nil
	Aim.muzzleAt = 0
	HUB.netReady = false
	if CFG.camUnlock or CFG.camForceThird then
		task.defer(function() pcall(camApply) end)
	end
	task.delay(0.8, function()
		Network = nil
		NB = nil
		genv.__BTRHUB_NET = nil
		installNetHooks()
		installRayHooks()
		if NB then NB.onFire = onFirePacket; NB.onHit = onHitPacket end
		gunCfgCache = setmetatable({}, { __mode = "k" })
		HUB.netReady = true
	end)
end

table.insert(HUB.conns, LP.CharacterAdded:Connect(function() pcall(onRespawn) end))

HUB.cfg = CFG
HUB.stats = STATS
HUB.api = {
	aimInfo = function()
		return Aim.point, Aim.occluded, Aim.origin, Aim.muzzle,
			Aim.part and Aim.part.Name, Aim.offsetUsed, Aim.muzzleBlocked
	end,
	debugInfo = function()
		return Aim.shotOK == true, tostring(Aim.offsetKind or "none"), Aim.shotDist or 0,
			HUB.noDamage or 0, HUB.aimPartCycle or 0, HUB.silentBypassHits or 0,
			HUB.packetOK or 0, HUB.silentWallCap or 2.5, HUB.silentObsCap or 4,
			HUB.silentPacketShots or 0
	end,
	camInfo = function()
		local cam = workspace.CurrentCamera
		local ch = LP.Character
		local head = ch and ch:FindFirstChild("Head")
		local hidden = 0
		if ch then
			for _, d in ipairs(ch:GetDescendants()) do
				if d:IsA("BasePart") and (d.LocalTransparencyModifier or 0) > 0.001 then
					hidden = hidden + 1
				end
			end
		end
		return tostring(LP.CameraMode), LP.CameraMinZoomDistance or -1, LP.CameraMaxZoomDistance or -1,
			cam and tostring(cam.CameraType) or "nil",
			(head and cam) and (cam.CFrame.Position - head.Position).Magnitude or -1,
			hidden, tostring(Cam.lastReason),
			Cam.locked == true, tostring(CFG.camLockMode or "fixed"), tostring(Cam.lockModeUsed or "-")
	end,
	rayStats = function() return RAY.casts or 0, RAY.hits or 0, RAY.ready == true end,
	offsetStats = function() return HUB.maxOffsetOK or 0, HUB.offsetAccepted or 0, HUB.offsetRejected or 0 end,
	packetStats = function()
		return HUB.packetOK or 0, HUB.packetTries or 0, HUB.packetStrat or 1,
			HUB.packetStratFail or 0, HUB.packetStratOK, HUB.packetGaveUp == true
	end,
	badDirs = function() return HUB.badDirs or 0 end,
	packetShots = function() return HUB.silentPacketShots or 0 end,
	silentMode = function()
		return (CFG.silentReal == true) or (HUB.silentFallbackReal == true),
			HUB.packetOK or 0, HUB.packetTries or 0
	end,
	silentAmmo = function()
		local sa = HUB.silentAmmo
		if not sa then return 0, 0, 0 end
		return sa.clip, sa.reserve, 0
	end,
	reserveOK = function() return HUB.reserveOK == true end,
	silentStats = function() return HUB.packetShots or 0, HUB.reloadNotified == true, HUB.silentIdle or 0 end,
	espVisible = function()
		local total, vis = 0, 0
		for _, e in pairs(pool) do
			total = total + 1
			if e.box.Visible then vis = vis + 1 end
		end
		return total, vis
	end,
	targets = function() return buildTargets() end,
	pellets = function() return HUB.lastPellets or 1 end,
}

HUB.destroy = function()
	pcall(removeAimHook)
	pcall(removeSpeedHook)
	pcall(forceRelease)
	CFG.camUnlock = false
	CFG.camForceThird = false
	pcall(camUnbind)
	pcall(camRestoreOriginals)
	pcall(RAY.restore)
	local ORIG = genv.__BTRHUB_NET_ORIG
	if ORIG and ORIG.net then
		pcall(function() ORIG.net.FireServer = ORIG.FireServer end)
		pcall(function() ORIG.net.InvokeServer = ORIG.InvokeServer end)
	end
	genv.__BTRHUB_NET = nil
	genv.__BTRHUB_NET_ORIG = nil
	NB = nil
	if lightBackup then
		CFG.noFog = false
		CFG.mapGlow = false
		pcall(applyWorld)
	end
	for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
	HUB.conns = {}
	for inst, hl in pairs(hlCache) do
		if hl and hl.Parent then pcall(function() hl:Destroy() end) end
		hlCache[inst] = nil
	end
	hlCache = setmetatable({}, { __mode = "k" })
	if hasDrawing then
		for _, e in pairs(pool) do
			for _, d in pairs(e) do pcall(function() d:Remove() end) end
		end
		if fovCircle then pcall(function() fovCircle:Remove() end) end
	end
	pool = {}
	lastDraw = {}
	pcall(function()
		for _, v in ipairs(workspace.Terrain:GetChildren()) do
			if v.Name == "__btrTrail" or v.Name == "__btrMuzzle" or v.Name == "__btrImpact" or v.Name == "__btrHL" then
				v:Destroy()
			end
		end
	end)
	trailBudget = {}
	gunCfgCache = setmetatable({}, { __mode = "k" })
	ammoCache = {}
	ammoSeen = setmetatable({}, { __mode = "k" })
	itemCache = {}
	monsterCache = {}
	friendCache = {}
	friendPending = {}
	silentFailAt = setmetatable({}, { __mode = "k" })
	if DynamicContext.GlobalAudio then
		pcall(function()
			DynamicContext.GlobalAudio:Stop()
			DynamicContext.GlobalAudio:Destroy()
		end)
		DynamicContext.GlobalAudio = nil
	end
	pcall(function()
		if DynamicContext.ScreenGui then DynamicContext.ScreenGui:Destroy() end
	end)
	pcall(function()
		for _, cont in ipairs({ CoreGui, LP:FindFirstChildOfClass("PlayerGui") }) do
			if cont then
				for _, child in ipairs(cont:GetChildren()) do
					if child:IsA("ScreenGui") and (string.sub(child.Name, 1, 5) == "__btr" or child.Name == "LinkCcUI") then
						child:Destroy()
					end
				end
			end
		end
	end)
	genv.__BTRHUB = nil
	genv.__BTRHUB_STATS = nil
	genv.__BTRHUB_RAY = nil
end
