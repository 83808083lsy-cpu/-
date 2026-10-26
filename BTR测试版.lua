local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGuiSvc = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")

local ENVT = nil
local function envTable()
	if ENVT then return ENVT end
	local ok, v = pcall(getgenv)
	if ok and type(v) == "table" then
		ENVT = v
		return ENVT
	end
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
	hook     = safeGet("hookmetamethod"),
	restore  = safeGet("restorefunction") or safeGet("restorefunction_"),
	m1press  = safeGet("mouse1press"),
	m1release = safeGet("mouse1release"),
	m1click  = safeGet("mouse1click"),
}

if genv.__BTRHUB and genv.__BTRHUB.destroy then
	pcall(genv.__BTRHUB.destroy)
end

local LP = Players.LocalPlayer
if not LP then
	for _ = 1, 120 do
		LP = Players.LocalPlayer
		if LP then break end
		task.wait(0.05)
	end
end
if not LP then
	warn("[BTR-HUB] 找不到 LocalPlayer，脚本中止")
	return
end

local HUB = { conns = {}, drawing = {}, destroy = nil, fps = 0, warned = false, worldOn = false, tweaksActive = false, otherBeams = 0, otherDrawn = 0, otherSkip = 0, rayHits = 0, rayCasts = 0, rayLast = nil, raySkip = nil, maxOffsetOK = 5, offsetAccepted = 0, offsetRejected = 0, packetOK = 0, packetTries = 0, packetStrat = 1, packetStratFail = 0, packetShots = 0, packetGaveUp = false, silentIdle = 0, silentIdleAt = 0, reloadAt = 0, reloadNotified = false, silentPacketShots = 0, badDirs = 0, ammoCount = 0, packetStratOK = {}, renderMode = "", reserveOK = false }
genv.__BTRHUB = HUB

local PALETTE = {
	Color3.fromRGB(255, 60, 60),   Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(255, 220, 0),   Color3.fromRGB(90, 255, 90),
	Color3.fromRGB(0, 230, 255),   Color3.fromRGB(60, 120, 255),
	Color3.fromRGB(200, 80, 255),  Color3.fromRGB(255, 255, 255),
}

local CFG = {
	espPlayers = true, espMonsters = true, espItems = true, espAmmo = true, espFriends = true, showSelf = false,
	box = true, name = true, health = true, distance = true, tracer = true, maxDist = 500,
	colorPlayer = Color3.fromRGB(70, 255, 110), colorFriend = Color3.fromRGB(255, 105, 180),
	colorMonster = PALETTE[1], colorBoss = PALETTE[7], colorItem = PALETTE[3], colorAmmo = Color3.fromRGB(0, 255, 200),
	aimbot = false, silent = true, autoFire = false, aimPart = "Head", fov = 600, visibleOnly = true,
	aimMonsters = true, aimPlayers = false, aimSmartPart = true, aim360 = true, fovAngle = 180,
	dropComp = true, spoofCam = true, noShield = false,
	muzzleOffset = true, muzzleRadius = 5, muzzleStep = 1.5, ricochet = true,
	packetMode = false, packetForge = false, silentPacket = false,
	trail = true, trailTime = 5, muzzleTrail = true, trailColor = Color3.fromRGB(255, 190, 60),
	otherTrails = true, colorTeamTrail = Color3.fromRGB(70, 255, 110), colorEnemyTrail = Color3.fromRGB(255, 45, 45),
	noFog = false, mapGlow = false, infStamina = false, 
	changeSpeed = false, walkSpeed = 24, 
	changeJump = false, jumpPower = 60, 
	noFall = false, fallSpeed = 45,
}

local STATS = genv.__BTRHUB_STATS
if not STATS then
	STATS = { fires = 0, hits = 0, target = "-", hitCalls = 0 }
	genv.__BTRHUB_STATS = STATS
end
STATS.target = "-"
STATS.hitCalls = STATS.hitCalls or 0

local Aim = { point = nil, target = nil, gunCfg = nil, occluded = false, part = nil, origin = nil, originAt = 0, muzzle = nil, offsetUsed = nil, offsetDir = nil, forceOrigin = nil, muzzleAt = 0, muzzleBlocked = false, lastOffset = nil, hadOrigin = false }

local function w2s(pos)
	local cam = workspace.CurrentCamera
	if not cam then return Vector2.new(), false end
	local sp, on = cam:WorldToViewportPoint(pos)
	return Vector2.new(sp.X, sp.Y), (on and sp.Z > 0)
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

local gunCfgCache = {}
local function getGunConfig(tool)
	if not tool then return nil end
	local hit = gunCfgCache[tool]
	if hit then return hit end
	local found
	for _, c in ipairs(tool:GetChildren()) do
		if c:IsA("ModuleScript") and c.Name == "" then
			local ok, r = pcall(require, c)
			if ok and type(r) == "table" and r.fire and r.ammo then found = r; break end
		end
	end
	if found then gunCfgCache[tool] = found end
	return found
end

local Network
local function getNetwork()
	if Network then return Network end
	local ok, m = pcall(require, RS.Assets.Modules.Network)
	if ok and type(m) == "table" then
		Network = m
		return m
	end
	return nil
end

local spawnTrail, spawnImpact
local trailBudget = {}

local function onFirePacket(tool, cfg, dir) STATS.fires = STATS.fires + 1 end
local function onHitPacket(hit, tool, cfg, payload)
	if hit then STATS.hits = STATS.hits + 1 end
	if not CFG.trail or not CFG.muzzleTrail then return end
	if type(payload) == "table" and typeof(payload[3]) == "Vector3" then spawnImpact(payload[3]) end
end

local NB = genv.__BTRHUB_NET
local function installNetHooks()
	if NB then return end
	local net = getNetwork()
	if not net then return end
	NB = { onFire = nil, onHit = nil }
	genv.__BTRHUB_NET = NB
	local oldFire = net.FireServer
	net.FireServer = function(self, channel, ...)
		if channel == "fire" then
			local a = table.pack(...)
			if NB.onFire then pcall(NB.onFire, a[1], a[2], a[3]) end
			if CFG.aimbot and Aim.point and typeof(a[3]) == "Vector3" then
				local cam = workspace.CurrentCamera
				if cam then
					local nd = Aim.point - cam.CFrame.Position
					if nd.Magnitude > 0.1 then return oldFire(self, channel, a[1], a[2], nd.Unit) end
				end
			end
			return oldFire(self, channel, ...)
		end
		if channel == "cam/mouse" and CFG.aimbot and CFG.spoofCam and Aim.point then
			local cam = workspace.CurrentCamera
			if cam then
				local base = cam.CFrame.Position
				local pos = base
				local cf = CFrame.lookAt(pos, Aim.point)
				return oldFire(self, channel, cf, { pos, Aim.point })
			end
		end
		return oldFire(self, channel, ...)
	end
	local oldInvoke = net.InvokeServer
	net.InvokeServer = function(self, channel, ...)
		if channel == "hit" or channel == "fleshHit" or channel == "droneHit" then
			STATS.hitCalls = (STATS.hitCalls or 0) + 1
			local args = table.pack(...)
			if channel == "hit" and Aim.origin and type(args[3]) == "table" then
				local pl = args[3]
				if typeof(pl[5]) == "Vector3" then pl[5] = Aim.origin end
			end
			local r = table.pack(oldInvoke(self, channel, table.unpack(args, 1, args.n)))
			if channel == "hit" then
				local used = Aim.offsetUsed or 0
				if used > 0 then
					if r[1] then
						HUB.offsetAccepted = (HUB.offsetAccepted or 0) + 1
						if used > (HUB.maxOffsetOK or 0) then HUB.maxOffsetOK = used end
					else
						HUB.offsetRejected = (HUB.offsetRejected or 0) + 1
						HUB.maxOffsetOK = math.max(1.5, math.min(HUB.maxOffsetOK or used, used - 1))
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
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
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
		TweenService:Create(m, TweenInfo.new(duration * 0.95, Enum.EasingStyle.Quad), {
			Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05),
		}):Play()
		Debris:AddItem(m, duration + 0.2)
	end
end

spawnImpact = function(pos)
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
	TweenService:Create(p, TweenInfo.new(CFG.trailTime, Enum.EasingStyle.Quad), {
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
if not RAY then
	RAY = {}
	genv.__BTRHUB_RAY = RAY
	local mod = RS.Assets.Modules:FindFirstChild("Raycast")
	local okm, RaycastMod = pcall(require, mod)
	if okm and type(RaycastMod) == "table" then
		local oldNew = RaycastMod.new
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
		local oldFire = RaycastMod.Fire
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
	end
end

local function installRayHooks()
	RAY.onOrigin = function(origin, dir)
		if not CFG.aimbot then return nil end
		local o = Aim.origin
		if o and typeof(o) == "Vector3" then return o end
		return nil
	end
	RAY.onAim = function(origin, dir)
		if not (CFG.aimbot or CFG.packetMode) then return nil end
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
		if typeof(origin) ~= "Vector3" or typeof(result.Position) ~= "Vector3" then return end
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
		if CFG.noShield then
			for _, t in ipairs(shieldCache) do
				if t.Parent then list[#list + 1] = t end
			end
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
	local nm = model.Name
	local base = nm:gsub("%d+$", "")
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
				if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
					out[#out + 1] = c
				end
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
		if not (p0 and p1) or (p1 - p0).Magnitude < 2 then return end
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
		spawnTrail(p0, p1, CFG.trailTime, false, isPlayer and CFG.colorTeamTrail or CFG.colorEnemyTrail)
	end)
end

workspace.Terrain.ChildAdded:Connect(function(v)
	if not CFG.otherTrails then return end
	if v:IsA("Beam") then otherShotTrail(v) end
end)

local friendCache = {}
local friendPending = {}
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
							list[#list + 1] = {
								inst = ch, hum = hum, head = head, root = root,
								kind = "player", isPlayer = true, friend = isFr,
								color = isFr and CFG.colorFriend or CFG.colorPlayer,
								label = (isFr and "[好友] " or "") .. pl.Name, dist = d,
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
								kind = kind, isPlayer = false,
								color = kind == "boss" and CFG.colorBoss or CFG.colorMonster,
								label = m.Name, dist = d,
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
local ITEM_PATTERNS = { "Ammo", "Crate", "Loot", "Medkit", "Morphine", "Bandage", "C4", "Landmine", "Glowstick", "Chemlight", "Keycard", "Intel", "Sample", "Battery", "Food", "Water", "NVG", "Case", "Supply", "Pickup", "Weapon", "Tool", "Objective" }
local function nameMatchesItem(n)
	for _, p in ipairs(ITEM_PATTERNS) do if n:find(p, 1, true) then return true end end
	return false
end
local function isAmmoName(n)
	local l = string.lower(n)
	return l == "ammobox" or l == "ammo box" or l == "ammoboxgiver" or string.find(l, "ammobox", 1, true) ~= nil
end
local function scanItems()
	local out, seen = {}, {}
	local function consider(v)
		if seen[v] then return end
		seen[v] = true
		if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then return end
		if not (v:IsA("Tool") or v:IsA("Model") or v:IsA("BasePart")) then return end
		local nm = v.Name
		if nm:sub(1, 2) == "__" or isAmmoName(nm) then return end
		if nameMatchesItem(nm) or v:GetAttribute("IsLandmine") or v:GetAttribute("IsPickup") then
			local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
			if part then out[#out + 1] = { inst = v, part = part, label = nm } end
		end
	end
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name ~= "Map" and c.Name ~= "Terrain" then
			consider(c)
			for _, cc in ipairs(c:GetChildren()) do consider(cc) end
		end
	end
	itemCache = out
end

local ammoCache, ammoSeen = {}, {}
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
	if not m or not m:IsA("Model") or hasAmmoAncestor(m) then return end
	local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt and not isGiverName(m.Name) and not inInteractions(m) then return end
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
	if ammoSeen[m] then
		for _, a in ipairs(ammoCache) do
			if a.inst == m then
				if part then a.part = part end
				if pivot then a.pivot = pivot end
				if prompt then a.prompt = prompt end
				if att then a.att = att end
				return
			end
		end
		return
	end
	ammoSeen[m] = true
	ammoCache[#ammoCache + 1] = { inst = m, part = part, att = att, prompt = prompt, label = prompt and "弹药" or "弹药点", pivot = pivot }
	HUB.ammoCount = #ammoCache
end
local function ancestorAmmoHost(v)
	local cur = v
	while cur and cur ~= workspace do
		if cur:IsA("Model") and (isGiverName(cur.Name) or string.lower(cur.Name) == "ammo box") then return cur end
		cur = cur.Parent
	end
	return nil
end
local function scanAmmo()
	ammoCache, ammoSeen = {}, {}
	local stack = {}
	for _, c in ipairs(workspace:GetChildren()) do
		if c ~= workspace.CurrentCamera and c.Name ~= "Characters" and c.Name ~= "Terrain" then stack[#stack + 1] = c end
	end
	local budget = 120000
	while #stack > 0 and budget > 0 do
		local v = table.remove(stack)
		budget = budget - 1
		if v.Parent then
			if v:IsA("Model") and (isGiverName(v.Name) or string.lower(v.Name) == "ammo box") then addAmmoHost(v) end
			for _, ch in ipairs(v:GetChildren()) do stack[#stack + 1] = ch end
		end
	end
	HUB.ammoCount = #ammoCache
end
workspace.DescendantAdded:Connect(function(v)
	if not (v:IsA("BasePart") or v:IsA("ProximityPrompt") or v:IsA("Model")) then return end
	task.defer(function()
		local host = ancestorAmmoHost(v)
		if host then addAmmoHost(host) end
	end)
end)
workspace.DescendantAdded:Connect(function(v)
	pcall(function()
		if not (v:IsA("Tool") or v:IsA("Model")) or v:FindFirstChildOfClass("Humanoid") then return end
		local nm = v.Name
		if nm == "" or nm:sub(1, 2) == "__" or not (nameMatchesItem(nm) or v:GetAttribute("IsLandmine") or v:GetAttribute("IsPickup")) then return end
		local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
		if part then table.insert(itemCache, { inst = v, part = part, label = nm }) end
	end)
end)

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
		if not t.isPlayer and (not bd or t.dist < bd) and t.dist <= (maxDist or 250) then bd = t.dist; best = t end
	end
	return best
end

local PACKET_STRATS = {
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos, ctx.normal, ctx.origin, ctx.dir, ctx.rel } end,
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos, ctx.normal, ctx.origin, ctx.dir } end,
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos } end,
	function(ctx) return { ctx.hum, ctx.part, ctx.hitPos, ctx.normal, ctx.origin, ctx.dir, ctx.rel, 1 } end,
}
local function getRealMuzzle()
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
		return game:GetService("CoreGui")
	end)
	return (ok and p) or game:GetService("CoreGui")
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
			toastLabel.Position = UDim2.new(0.5, 0, 0.78, 0)
			toastLabel.Size = UDim2.new(0, 420, 0, 42)
			toastLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
			toastLabel.BackgroundTransparency = 0.15
			toastLabel.BorderSizePixel = 0
			toastLabel.Font = Enum.Font.GothamBold
			toastLabel.TextSize = 18
			toastLabel.TextColor3 = Color3.fromRGB(120, 230, 255)
			toastLabel.Text = ""
			toastLabel.Visible = false
			Instance.new("UICorner", toastLabel).CornerRadius = UDim.new(0, 8)
			toastLabel.Parent = toastGui
		end
		toastLabel.Text = msg
		toastLabel.Visible = true
		toastUntil = os.clock() + (secs or 2)
	end)
end
local function toastTick()
	if toastLabel and toastLabel.Visible and os.clock() >= toastUntil then toastLabel.Visible = false end
end

local function packetShot(gun, cfg, t)
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
	local part, hum = t.part or t.head or t.root, t.hum
	if not (part and hum and hum.Parent) then return false end
	local origin = Aim.origin or Aim.muzzle or getRealMuzzle()
	if not origin then return false end
	local hitPos = part.Position
	local delta = hitPos - origin
	if delta.Magnitude < 0.3 then return false end
	local dir = delta.Unit
	local normal = -dir
	local rel = CFrame.new()
	pcall(function()
		if hum.RootPart then rel = hum.RootPart.CFrame:ToObjectSpace(CFrame.new(hitPos, hitPos + normal * 1.5)) end
	end)
	local ctx = { hum = hum, part = part, hitPos = hitPos, normal = normal, origin = origin, dir = dir, rel = rel }
	HUB.packetTries = (HUB.packetTries or 0) + 1
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then N:FireServer("cam/mouse", cam.CFrame, { cam.CFrame.Position, hitPos }) end
	end)
	pcall(function() N:FireServer("fire", gun, cfg, dir) end)
	local idx = HUB.packetStrat or 1
	local okS, payload = pcall(PACKET_STRATS[idx], ctx)
	if not okS then return false end
	local ok, ret = pcall(function() return N:InvokeServer("hit", gun, cfg, payload) end)
	if ok and ret ~= false and ret ~= nil then
		HUB.packetOK = (HUB.packetOK or 0) + 1
		pcall(function()
			local clipNow = gun:GetAttribute("ClipCurrent")
			if clipNow ~= nil and clipNow <= 0 and not HUB.reserveOK then
				HUB.reserveOK = true
				toast("备用弹药射击已生效", 2)
			end
		end)
		HUB.packetStratOK = HUB.packetStratOK or {}
		HUB.packetStratOK[idx] = (HUB.packetStratOK[idx] or 0) + 1
		if CFG.trail then spawnTrail(origin, hitPos, nil, true) end
		return true
	end
	HUB.packetStrat = (idx % #PACKET_STRATS) + 1
	HUB.packetStratFail = (HUB.packetStratFail or 0) + 1
	if (HUB.packetTries or 0) >= 40 and (HUB.packetOK or 0) == 0 then
		CFG.packetMode = false
		HUB.packetGaveUp = true
	end
	return false
end

local function sendMouse(isDown)
	if VIM then
		local x, y = vpCenter()
		if pcall(function() VIM:SendMouseButtonEvent(x, y, 0, isDown, game, 0) end) then return end
	end
	local f = isDown and COMPAT.m1press or COMPAT.m1release
	if type(f) == "function" and pcall(f) then return end
	if isDown and type(COMPAT.m1click) == "function" then pcall(COMPAT.m1click) end
end
local function mouseDown() if not Fire.down then Fire.down = true; sendMouse(true) end end
local function mouseUp() if Fire.down then Fire.down = false; sendMouse(false) end end
local function forceRelease() Fire.down = false; sendMouse(false) end

local SpeedHook = { installed = false, orig = nil }
local function installSpeedHook()
	if SpeedHook.installed or type(COMPAT.hook) ~= "function" then return false end
	local ok = pcall(function()
		local orig
		orig = COMPAT.hook(game, "__newindex", function(self, key, value)
			if key == "WalkSpeed" and CFG.changeSpeed then
				local h = getMyHumanoid()
				if h and self == h then value = CFG.walkSpeed end
			elseif key == "JumpPower" and CFG.changeJump then
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
	lightBackup = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor, Atmosphere = {} }
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("Atmosphere") then table.insert(lightBackup.Atmosphere, { obj = e, Density = e.Density, Haze = e.Haze, Glare = e.Glare }) end
	end
	genv.__BTRHUB_LIGHT = lightBackup
end
local function applyWorld()
	ensureBackup()
	local fogOn = CFG.noFog or CFG.mapGlow
	if fogOn then
		pcall(function() Lighting:SetAttribute("LocalFogFullbright", true) end)
		Lighting.FogStart = 1e6
		Lighting.FogEnd = 1e6
		for _, a in ipairs(lightBackup.Atmosphere) do a.obj.Density = 0; a.obj.Haze = 0; a.obj.Glare = 0 end
	else
		pcall(function() Lighting:SetAttribute("LocalFogFullbright", false) end)
		Lighting.FogStart = lightBackup.FogStart
		Lighting.FogEnd = lightBackup.FogEnd
		Lighting.FogColor = lightBackup.FogColor
		for _, a in ipairs(lightBackup.Atmosphere) do a.obj.Density = a.Density; a.obj.Haze = a.Haze; a.obj.Glare = a.Glare end
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
	if d ~= nil and pcall(function() return d.new end) then
		if pcall(function() local s = d.new("Square"); s.Visible = false; pcall(function() s:Remove() end) end) then DRAW = d; break end
	end
end
local hasDrawing = DRAW ~= nil
HUB.renderMode = hasDrawing and "Drawing" or "Highlight"

local PROP_ALIAS = { TextSize = { "TextSize", "Size", "FontSize", "TextFontSize" }, Center = { "Center", "Centered" }, Outline = { "Outline", "Outlined" }, OutlineColor = { "OutlineColor", "OutlinedColor" }, Filled = { "Filled", "Fill" }, Thickness = { "Thickness", "Width", "LineWidth" }, NumSides = { "NumSides", "Sides", "Segments" }, Transparency = { "Transparency", "Alpha" }, Font = { "Font", "FontFace" } }
local propCache = setmetatable({}, { __mode = "k" })
local function setP(obj, prop, value)
	if obj == nil then return false end
	local cache = propCache[obj] or {}
	propCache[obj] = cache
	local name = cache[prop]
	if name == false then return false end
	if name then if pcall(function() obj[name] = value end) then return true end; cache[prop] = false; return false end
	for _, cand in ipairs(PROP_ALIAS[prop] or { prop }) do
		if pcall(function() obj[cand] = value end) then cache[prop] = cand; return true end
	end
	cache[prop] = false
	return false
end

local pool, used = {}, {}
local function getPool(id)
	local e = pool[id]
	if e then return e end
	local ok, res = pcall(function()
		local o = { box = DRAW.new("Square"), name = DRAW.new("Text"), hpBg = DRAW.new("Square"), hp = DRAW.new("Square"), dist = DRAW.new("Text"), tracer = DRAW.new("Line") }
		setP(o.box, "Thickness", 1); setP(o.box, "Filled", false)
		setP(o.hpBg, "Filled", true); o.hpBg.Color = Color3.fromRGB(0, 0, 0); setP(o.hpBg, "Transparency", 0.6)
		setP(o.hp, "Filled", true)
		setP(o.name, "Center", true); setP(o.name, "Outline", true); setP(o.name, "OutlineColor", Color3.fromRGB(0, 0, 0)); setP(o.name, "TextSize", 14)
		setP(o.dist, "Center", true); setP(o.dist, "Outline", true); setP(o.dist, "OutlineColor", Color3.fromRGB(0, 0, 0)); setP(o.dist, "TextSize", 12)
		setP(o.tracer, "Thickness", 1)
		return o
	end)
	if not ok or not res then hasDrawing = false; HUB.renderMode = "Highlight(回退)"; return nil end
	pool[id] = res
	return res
end

local lastDraw = {}
local function hideStale(now)
	for id, e in pairs(pool) do
		if now - (lastDraw[id] or 0) > 0.15 then
			e.box.Visible = false; e.name.Visible = false; e.hpBg.Visible = false; e.hp.Visible = false; e.dist.Visible = false; e.tracer.Visible = false
		end
	end
end

local hlCache = {}
local function espHighlight(targets)
	local seen = {}
	for _, t in ipairs(targets) do
		local show = (t.isPlayer and CFG.espPlayers) or ((not t.isPlayer) and CFG.espMonsters)
		if t.isPlayer and t.friend and CFG.espFriends then show = true end
		if show and t.inst and t.inst.Parent then
			seen[t.inst] = true
			local hl = hlCache[t.inst]
			if not hl or not hl.Parent then
				hl = Instance.new("Highlight"); hl.Name = "__btrHL"; hl.Adornee = t.inst; hl.FillTransparency = 0.62; hl.OutlineTransparency = 0.1; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = workspace.Terrain; hlCache[t.inst] = hl
			end
			hl.FillColor = t.color; hl.OutlineColor = t.color; hl.Enabled = true
		end
	end
	if CFG.espAmmo then
		for _, it in ipairs(ammoCache) do
			if it.inst and it.inst.Parent then
				seen[it.inst] = true
				local hl = hlCache[it.inst]
				if not hl or not hl.Parent then
					hl = Instance.new("Highlight"); hl.Name = "__btrHL"; hl.Adornee = it.inst; hl.FillTransparency = 0.55; hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = workspace.Terrain; hlCache[it.inst] = hl
				end
				hl.FillColor = CFG.colorAmmo; hl.OutlineColor = CFG.colorAmmo; hl.Enabled = true
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
	local e = getPool(t.inst)
	if not e then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local headPos = t.head.Position + Vector3.new(0, t.head.Size.Y * 0.5, 0)
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
		e.box.Visible = true; e.box.Color = t.color; e.box.Position = boxPos; e.box.Size = Vector2.new(w, h); setP(e.box, "Thickness", 1)
	end
	if CFG.health then
		local frac = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
		local barX = boxPos.X - 5
		e.hpBg.Visible = true; e.hpBg.Position = Vector2.new(barX - 1, sTop.Y - 1); e.hpBg.Size = Vector2.new(4, h + 2)
		e.hp.Visible = true; e.hp.Color = Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 40); e.hp.Position = Vector2.new(barX, sTop.Y + h * (1 - frac)); e.hp.Size = Vector2.new(2, h * frac)
	end
	if CFG.name then
		e.name.Visible = true; e.name.Text = t.label; e.name.Color = t.color; e.name.Position = Vector2.new(sTop.X, sTop.Y - 16); setP(e.name, "TextSize", math.clamp(16 - t.dist / 120, 10, 16))
	end
	if CFG.distance then
		e.dist.Visible = true; e.dist.Text = string.format("[%d]", math.floor(t.dist)); e.dist.Color = t.color; e.dist.Position = Vector2.new(sTop.X, sBot.Y + 2); setP(e.dist, "TextSize", 12)
	end
	if CFG.tracer then
		e.tracer.Visible = true; e.tracer.Color = t.color; e.tracer.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y); e.tracer.To = Vector2.new(sTop.X, sBot.Y); setP(e.tracer, "Thickness", 1)
	end
end

local fovCircle
if hasDrawing then
	local okC, c = pcall(function() return DRAW.new("Circle") end)
	if okC and c then
		fovCircle = c; setP(fovCircle, "Thickness", 1); setP(fovCircle, "Filled", false); setP(fovCircle, "NumSides", 48); setP(fovCircle, "Transparency", 0.7); fovCircle.Visible = false
	else
		fovCircle = nil
	end
end

local function hasLineOfSight(part)
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local excl = { workspace.Terrain:FindFirstChild("Ignore") }
	local ch = getMyChar()
	if ch then table.insert(excl, ch) end
	local res = workspace:Raycast(cam.CFrame.Position, (part.Position - cam.CFrame.Position), rayParams(excl))
	if res == nil then return true end
	return res.Instance:IsDescendantOf(part.Parent) or res.Instance == part
end

local PART_ORDER = { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local function pickVisiblePart(t)
	local cands = {}
	if t.head then cands[#cands + 1] = t.head end
	for _, nm in ipairs(PART_ORDER) do
		local p = t.inst:FindFirstChild(nm)
		if p and p:IsA("BasePart") and p ~= t.head then cands[#cands + 1] = p end
	end
	if #cands == 0 then return nil, false end
	for _, p in ipairs(cands) do if hasLineOfSight(p) then return p, true end end
	return cands[1], false
end

local function losClearFrom(pos, targetPos, targetInst)
	local d = targetPos - pos
	if d.Magnitude < 0.6 then return false end
	local excl = { workspace.Terrain:FindFirstChild("Ignore"), getMyChar() }
	local res = workspace:Raycast(pos, d, rayParams(excl))
	if res == nil then return true end
	if targetInst and (res.Instance == targetInst or res.Instance:IsDescendantOf(targetInst)) then return true end
	return false
end

local function pointIsOpen(p)
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = { getMyChar(), workspace.Terrain:FindFirstChild("Ignore") }
	local parts = workspace:GetPartBoundsInRadius(p, 0.35, op)
	for _, part in ipairs(parts) do if part.CanCollide then return false end end
	return true
end

local function findFiringOrigin(targetPos)
	local ch = getMyChar()
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root or not targetPos then return nil end
	local base = root.Position
	local muzzle = getRealMuzzle()
	local targetInst = Aim.target and Aim.target.inst
	if muzzle and losClearFrom(muzzle, targetPos, targetInst) then Aim.muzzle = muzzle; Aim.offsetUsed = 0; Aim.lastOffset = nil; return nil end
	local escape = nil
	if muzzle then
		local rp = rayParams({ workspace.Terrain:FindFirstChild("Ignore"), ch })
		local block = workspace:Raycast(muzzle, targetPos - muzzle, rp)
		if block then
			local n = block.Normal; n = Vector3.new(n.X, 0, n.Z)
			if n.Magnitude > 0.01 then escape = n.Unit end
		end
	end
	local dirs = {}
	if escape then dirs[#dirs + 1] = escape end
	for i = 0, 7 do local a = math.rad(i * 45); dirs[#dirs + 1] = Vector3.new(math.cos(a), 0, math.sin(a)) end
	local heights = { 0.4, 1.2, -0.6 }
	local lo = Aim.lastOffset
	if lo then
		local cand = base + lo.d * lo.r + Vector3.new(0, lo.hy or 0, 0)
		if pointIsOpen(cand) and losClearFrom(cand, targetPos, targetInst) then Aim.muzzle = cand; Aim.offsetUsed = lo.r; Aim.offsetDir = lo.d; return cand end
	end
	local step = math.max(CFG.muzzleStep or 1.5, 0.5)
	local maxR = math.min(CFG.muzzleRadius, HUB.maxOffsetOK or CFG.muzzleRadius)
	local budget = 130
	local r = step
	while r <= maxR + 0.001 and budget > 0 do
		for _, d in ipairs(dirs) do
			for _, hy in ipairs(heights) do
				if budget <= 0 then break end
				budget = budget - 1
				local cand = base + d * r + Vector3.new(0, hy, 0)
				if pointIsOpen(cand) and losClearFrom(cand, targetPos, targetInst) then Aim.muzzle = cand; Aim.offsetUsed = r; Aim.offsetDir = d; Aim.lastOffset = { d = d, r = r, hy = hy }; return cand end
			end
		end
		r = r + step
	end
	Aim.muzzle = nil; Aim.offsetUsed = nil
	return nil
end

local function nearestVisibleMonster(maxDist)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local vp = cam.ViewportSize
	local best, bd = nil, nil
	for _, t in ipairs(buildTargets()) do
		if not t.isPlayer and t.dist <= (maxDist or 250) then
			local part = t.part or t.head or t.root
			local onScreen = false
			if part then
				local sp, on = cam:WorldToViewportPoint(part.Position)
				onScreen = on and sp.Z > 0 and sp.X >= 0 and sp.Y >= 0 and sp.X <= vp.X and sp.Y <= vp.Y
			end
			if part and onScreen and hasLineOfSight(part) then if not bd or t.dist < bd then bd = t.dist; best = t end end
		end
	end
	return best
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
		local allowed = t.isPlayer and CFG.aimPlayers or (not t.isPlayer and CFG.aimMonsters)
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
	if #cands == 0 then return nil end
	table.sort(cands, function(a, b) return a.s < b.s end)
	local fallback
	local limit = math.min(#cands, 5)
	for i = 1, limit do
		local t = cands[i].t
		local part, visible = pickVisiblePart(t)
		t.part = part; t.visible = visible
		if visible then return t end
		if not fallback then fallback = t end
	end
	if CFG.visibleOnly then return nil end
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

local lastFire, lastWorld, lastItem = 0, 0, 0
local function onRender(dt)
	local now = os.clock()
	HUB.fps = HUB.fps and (HUB.fps * 0.9 + (1 / math.max(dt, 0.001)) * 0.1) or (1 / math.max(dt, 0.001))
	local ok, err = pcall(function()
		local myChar = getMyChar()
		local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
		local alive = hum and hum.Health > 0
		local gun = getEquippedGun()
		local wantWorld = CFG.noFog or CFG.mapGlow
		if wantWorld ~= HUB.worldOn then HUB.worldOn = wantWorld; applyWorld()
		elseif wantWorld and now - lastWorld > 1 then lastWorld = now; applyWorld() end

		if CFG.changeSpeed or CFG.changeJump or CFG.infStamina then
			installSpeedHook()
		else
			removeSpeedHook()
		end
		
		if CFG.infStamina then
			if now - staminaGui.last > 2 or not staminaGui.bar or not staminaGui.bar.Parent then staminaGui.last = now; refreshStaminaGui() end
			if staminaGui.bar and staminaGui.bar:IsA("GuiObject") then staminaGui.bar.Size = UDim2.new(1, 0, 1, 0) end
			if staminaGui.vig and staminaGui.vig:IsA("ImageLabel") then staminaGui.vig.ImageTransparency = 1 end
		end
		
		if hum and alive then
			if CFG.changeSpeed and hum.WalkSpeed ~= CFG.walkSpeed then hum.WalkSpeed = CFG.walkSpeed end
			if CFG.changeJump and hum.JumpPower ~= CFG.jumpPower then hum.JumpPower = CFG.jumpPower end
		end

		if CFG.noFall and hum and alive and myChar then
			local root = myChar:FindFirstChild("HumanoidRootPart")
			if root and hum.FloorMaterial == Enum.Material.Air then
				local v = root.AssemblyLinearVelocity
				if v.Y < -CFG.fallSpeed then root.AssemblyLinearVelocity = Vector3.new(v.X, -CFG.fallSpeed, v.Z) end
			end
		end
		if CFG.noShield and now - lastShieldScan > 0.5 then lastShieldScan = now; shieldCache = scanShields() end
		if now - lastMonsterScan > 1 then lastMonsterScan = now; monsterCache = scanMonsters() end
		local targets = buildTargets()

		if hasDrawing then
			hideStale(now)
			toastTick()
			used = {}
			for _, t in ipairs(targets) do
				local show = (t.isPlayer and CFG.espPlayers) or ((not t.isPlayer) and CFG.espMonsters)
				if t.isPlayer and t.friend and CFG.espFriends then show = true end
				if show then used[t.inst] = true; drawTarget(t) end
			end
			if CFG.espItems and now - lastItem > 0.35 then lastItem = now; scanItems() end
			if CFG.espItems then
				local cam = workspace.CurrentCamera
				for _, it in ipairs(itemCache) do
					if it.inst.Parent and it.part.Parent then
						local e = getPool(it.inst)
						if not e then break end
						local sp, on = w2s(it.part.Position)
						local d = (it.part.Position - cam.CFrame.Position).Magnitude
						if on and d <= CFG.maxDist then
							e.box.Visible = true; e.box.Color = CFG.colorItem; e.box.Position = Vector2.new(sp.X - 3, sp.Y - 3); e.box.Size = Vector2.new(6, 6); setP(e.box, "Thickness", 1)
							e.name.Visible = true; e.name.Text = it.label; e.name.Color = CFG.colorItem; e.name.Position = Vector2.new(sp.X, sp.Y - 14); setP(e.name, "TextSize", 11)
							e.dist.Visible = true; e.dist.Text = string.format("[%d]", math.floor(d)); e.dist.Color = CFG.colorItem; e.dist.Position = Vector2.new(sp.X, sp.Y + 6); setP(e.dist, "TextSize", 11)
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
							if not it.part then local okp, pv = pcall(function() return it.inst:GetPivot().Position end); if okp then it.pivot = pv end end
						end
						if it.att and not it.att.Parent then it.att = nil end
						local e = getPool(it.inst)
						local pos = (it.att and it.att.Parent and it.att.WorldPosition) or (it.part and it.part.Parent and it.part.Position) or it.pivot
						if e and pos then
							local sp, on = w2s(pos)
							local d = (pos - cam2.CFrame.Position).Magnitude
							if on and d <= CFG.maxDist then
								e.box.Visible = true; e.box.Color = CFG.colorAmmo; e.box.Position = Vector2.new(sp.X - 5, sp.Y - 5); e.box.Size = Vector2.new(10, 10); setP(e.box, "Thickness", 2)
								e.name.Visible = true; e.name.Text = it.label or "弹药"; e.name.Color = CFG.colorAmmo; e.name.Position = Vector2.new(sp.X, sp.Y - 17); setP(e.name, "TextSize", 12)
								e.dist.Visible = true; e.dist.Text = string.format("[%d]", math.floor(d)); e.dist.Color = CFG.colorAmmo; e.dist.Position = Vector2.new(sp.X, sp.Y + 8); setP(e.dist, "TextSize", 11)
							end
						end
					end
				end
			end
		else espHighlight(targets) end

		local aimTarget
		if CFG.aimbot and alive then aimTarget = pickTarget(targets) end
		if CFG.aimbot and aimTarget and gun then
			Aim.target = aimTarget
			Aim.gunCfg = getGunConfig(gun)
			local part, visible = aimTarget.part, aimTarget.visible
			if part == nil then
				if CFG.aimSmartPart then part, visible = pickVisiblePart(aimTarget)
				else part = (CFG.aimPart == "Head" and aimTarget.head) or aimTarget.root; visible = hasLineOfSight(part) end
				aimTarget.part, aimTarget.visible = part, visible
			end
			Aim.part, Aim.occluded, Aim.point = part, not visible, computeAimPoint(aimTarget, gun, part)
			if Aim.forceOrigin then Aim.origin = Aim.forceOrigin
			elseif CFG.muzzleOffset then
				if now - Aim.muzzleAt > 0.1 then
					Aim.muzzleAt = now
					local realM = getRealMuzzle()
					local blocked = realM and (not losClearFrom(realM, Aim.point, aimTarget.inst))
					Aim.muzzleBlocked = blocked and true or false
					if blocked then Aim.origin = findFiringOrigin(Aim.point)
					else Aim.origin = nil; Aim.muzzle = realM; Aim.offsetUsed = 0 end
				end
			else Aim.origin = nil; Aim.muzzleBlocked = false end
			if not CFG.silent then
				local aimPart = (CFG.aimPart == "Head" and aimTarget.head) or aimTarget.root
				local cam = workspace.CurrentCamera
				if cam then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPart.Position) end
			end
			STATS.target = aimTarget.label .. " " .. math.floor(aimTarget.dist) .. "m" .. (visible and "" or " (遮挡)")
		else
			Aim.point, Aim.target, Aim.gunCfg, Aim.occluded, Aim.origin, Aim.muzzle, Aim.muzzleBlocked, STATS.target = nil, nil, nil, false, nil, nil, false, "-"
		end

		local wantFire = CFG.autoFire and alive and gun and aimTarget ~= nil
		if wantFire and not CFG.packetMode and Aim.occluded and not Aim.origin then
			wantFire = false
		end
		if wantFire and Aim.origin and not Aim.hadOrigin then lastFire = 0 end
		Aim.hadOrigin = (Aim.origin ~= nil)
		if wantFire and gun then
			local clip = gun:GetAttribute("ClipCurrent")
			if clip ~= nil and clip <= 0 then wantFire = false end
			if gun:GetAttribute("Reloading") == true then wantFire = false end
		end
		if CFG.silentPacket and alive and gun then
			local cfgP = getGunConfig(gun)
			local pT = nearestVisibleMonster(320) or aimTarget
			local clipP = gun:GetAttribute("ClipCurrent")
			if pT and cfgP and clipP ~= nil and clipP > 0 then
				local intervalP = 0.12
				if cfgP.fire then intervalP = math.max(cfgP.fire.fireDelay or 0.12, 0.03) end
				if now - lastFire >= intervalP then
					lastFire = now
					if not aimTarget then local ap = pT.part or pT.head or pT.root; Aim.point = ap and ap.Position; Aim.gunCfg = cfgP; Aim.target = pT end
					HUB.silentPacketShots = (HUB.silentPacketShots or 0) + 1
					packetShot(gun, cfgP, pT)
				end
			end
			wantFire = false
		end
		if CFG.packetMode and alive and gun then
			local pTarget = aimTarget or nearestVisibleMonster(250)
			local cfg = getGunConfig(gun)
			local clip = gun:GetAttribute("ClipCurrent")
			local reloading = gun:GetAttribute("Reloading") == true
			if not pTarget and now - (HUB.silentIdleAt or 0) > 0.5 then HUB.silentIdleAt = now; HUB.silentIdle = (HUB.silentIdle or 0) + 1 end
			if pTarget and cfg then
				if not aimTarget then local ap = pTarget.part or pTarget.head or pTarget.root; Aim.point = ap and ap.Position; Aim.gunCfg = cfg; Aim.target = pTarget; HUB.packetShots = (HUB.packetShots or 0) end
				if clip ~= nil and clip <= 0 then
					if not reloading and now - (HUB.reloadAt or 0) > 1.0 then
						HUB.reloadAt = now; HUB.reloadNotified = true
						local N = getNetwork()
						if N then pcall(function() N:FireServer("reload", gun, cfg, "register") end) end
						toast("弹匣打空 · 正在自动换弹", 2.2)
					end
				elseif not reloading then
					if HUB.reloadNotified and clip and clip > 0 then HUB.reloadNotified = false; toast("换弹完成 · 继续射击", 1.6) end
					local interval = 0.12
					if cfg.fire then interval = math.max(cfg.fire.fireDelay or 0.12, 0.03) end
					if now - lastFire >= interval then
						lastFire = now; HUB.packetShots = (HUB.packetShots or 0) + 1
						sendMouse(true); task.delay(0.045, function() sendMouse(false) end)
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
				if not Fire.down then mouseDown(); task.delay(0.06, function() if CFG.autoFire then mouseUp() end end) end
			end
		else mouseUp() end
		if fovCircle then
			local cam = workspace.CurrentCamera
			if CFG.aimbot and cam then
				local vp = cam.ViewportSize
				fovCircle.Visible = true; fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
				local r = CFG.fov * 0.5
				if r ~= r then r = 100 end
				local maxR = math.min(vp.X, vp.Y) * 0.47
				fovCircle.Radius = math.clamp(r, 6, maxR)
				if not aimTarget then fovCircle.Color = Color3.fromRGB(255, 255, 255)
				elseif not Aim.occluded then fovCircle.Color = Color3.fromRGB(90, 255, 120)
				else fovCircle.Color = Color3.fromRGB(255, 70, 70) end
			else fovCircle.Visible = false end
		end
	end)
	if not ok and not HUB.warned then HUB.warned = true; warn("[BTR-HUB] loop error: " .. tostring(err)) end
end
table.insert(HUB.conns, RunService.RenderStepped:Connect(onRender))

--============================================================================
-- UI 架构及优化
--============================================================================
local DynamicContext = {
	ActiveToggles = {}, ActiveSliders = {}, TextElements = {}, BorderElements = {},
	CurrentTab = nil, TabSwitchThread = nil, IsSubCardActive = true, GlobalAudio = nil,
	CurrentVolume = 2, BgPhase = math.random() * 100, StrokeRotation = 0
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
local PaletteNames = { "泡泡糖", "暗黑柔和", "海洋迷雾", "日落余晖", "薄荷清鲜", "薰衣草梦", "樱桃红", "赛博蓝", "金奶油", "森林宁静", "玫瑰金" }

local function GeneratePalette(preset)
	local p, s, a, white = preset.Primary, preset.Secondary, preset.Accent, Color3.fromRGB(255, 255, 255)
	return { p:Lerp(white, 0.2), p:Lerp(s, 0.15), s:Lerp(white, 0.25), s:Lerp(a, 0.2), a:Lerp(white, 0.2) }
end

local function ApplyPalette(selected)
	local p = PalettePresets[selected]
	if not p then
		for name, val in pairs(PalettePresets) do
			if name == selected then p = val; break end
		end
	end
	if not p then return end
	DynamicContext.CurrentPreset = p
	DynamicContext.TargetPalette = GeneratePalette(p)
	DynamicContext.TargetLogoColor = p.LogoAccent
	DynamicContext.TargetActiveColor = p.ActiveColor
	DynamicContext.TargetTextColor = p.TextColor
	DynamicContext.TargetSubTextColor = p.SubTextColor
	DynamicContext.TargetBorderColor = p.BorderColor
end

local defaultPreset = PalettePresets["Ocean Mist"]
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

local UiScreenGui = Instance.new("ScreenGui")
UiScreenGui.Name = "BTRLinkUI"
UiScreenGui.ResetOnSpawn = false
UiScreenGui.DisplayOrder = 999999
UiScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UiScreenGui.IgnoreGuiInset = true
pcall(function() UiScreenGui.Parent = CoreGuiSvc end)
if not UiScreenGui.Parent then UiScreenGui.Parent = LP:WaitForChild("PlayerGui") end

local activeDrag = nil
UserInputService.InputChanged:Connect(function(input)
	if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = Vector2.new(input.Position.X, input.Position.Y) - activeDrag.startPos
		activeDrag.frame.Position = UDim2.new(activeDrag.initialPos.X.Scale, activeDrag.initialPos.X.Offset + delta.X, activeDrag.initialPos.Y.Scale, activeDrag.initialPos.Y.Offset + delta.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if activeDrag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		activeDrag = nil
	end
end)

local function MakeDraggable(dragHandle, targetFrame)
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeDrag = {
				frame = targetFrame,
				startPos = Vector2.new(input.Position.X, input.Position.Y),
				initialPos = targetFrame.Position
			}
		end
	end)
end

local MainFrame = Instance.new("CanvasGroup")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 530, 0, 320)
MainFrame.Position = UDim2.new(0.5, -265, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.GroupTransparency = 1
MainFrame.ZIndex = 10
MainFrame.Parent = UiScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Parent = MainFrame

local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(210, 210, 210)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(210, 210, 210)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 255, 255))
})
StrokeGradient.Parent = MainStroke

local MainGradient = Instance.new("UIGradient")
MainGradient.Parent = MainFrame

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundTransparency = 1
TopBar.Active = true
TopBar.ZIndex = 11
TopBar.Parent = MainFrame

local LogoBtn = Instance.new("TextButton")
LogoBtn.Size = UDim2.new(0, 150, 1, 0)
LogoBtn.Position = UDim2.new(0.5, -75, 0, 0)
LogoBtn.Font = Enum.Font.FredokaOne
LogoBtn.Text = "Link.cc"
LogoBtn.TextColor3 = DynamicContext.CurrentLogoColor
LogoBtn.TextSize = 26
LogoBtn.BackgroundTransparency = 1
LogoBtn.ZIndex = 12
LogoBtn.Parent = TopBar

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 6, 0, 6)
StatusDot.Position = UDim2.new(1, -150, 0.5, -3)
StatusDot.BackgroundColor3 = Color3.fromRGB(60, 210, 100)
StatusDot.ZIndex = 12
StatusDot.Parent = TopBar
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(0, 110, 1, 0)
StatusText.Position = UDim2.new(1, -140, 0, 0)
StatusText.Font = Enum.Font.GothamMedium
StatusText.Text = "运行中"
StatusText.TextColor3 = DynamicContext.CurrentSubTextColor
StatusText.TextSize = 11
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.BackgroundTransparency = 1
StatusText.ZIndex = 12
StatusText.Parent = TopBar
table.insert(DynamicContext.TextElements, {Obj = StatusText, Type = "Sub"})

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
	MainFrame.Position = UDim2.new(0.5, -250, 0.5, -150)
	MainFrame.GroupTransparency = 1
	TweenService:Create(MainFrame, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 530, 0, 320),
		Position = UDim2.new(0.5, -265, 0.5, -160),
		GroupTransparency = 0
	}):Play()
end)

local SIZE_MAIN_NORMAL = UDim2.new(0, 232, 1, 0)
local SIZE_MAIN_EXPAND = UDim2.new(0, 374, 1, 0)

local function AdjustLayoutMode(showSubCard)
	if DynamicContext.IsSubCardActive == showSubCard then return end
	DynamicContext.IsSubCardActive = showSubCard
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	if showSubCard then
		SubMaskContainer.Visible = true
		SubConfigCard.Visible = true
		TweenService:Create(MainConfigCard, tweenInfo, {Size = SIZE_MAIN_NORMAL}):Play()
		TweenService:Create(SubConfigCard, tweenInfo, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.15}):Play()
		TweenService:Create(SubConfigStroke, tweenInfo, {Transparency = 0.2}):Play()
	else
		TweenService:Create(MainConfigCard, tweenInfo, {Size = SIZE_MAIN_EXPAND}):Play()
		local subTween = TweenService:Create(SubConfigCard, tweenInfo, {Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1})
		TweenService:Create(SubConfigStroke, tweenInfo, {Transparency = 1}):Play()
		subTween:Play()
		subTween.Completed:Connect(function()
			if not DynamicContext.IsSubCardActive then
				SubMaskContainer.Visible = false
				SubConfigCard.Visible = false
			end
		end)
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
	
	local List = Instance.new("UIListLayout")
	List.Padding = UDim.new(0, 8)
	List.HorizontalAlignment = Enum.HorizontalAlignment.Center
	List.SortOrder = Enum.SortOrder.LayoutOrder
	List.Parent = Scroll
	
	local UIPadding = Instance.new("UIPadding")
	UIPadding.PaddingTop = UDim.new(0, 4)
	UIPadding.PaddingBottom = UDim.new(0, 80) -- 留出底部空间，防止下拉菜单被切掉
	UIPadding.Parent = Scroll
	
	local function updateScrollState()
		if List.AbsoluteContentSize.Y + 80 > Scroll.AbsoluteSize.Y then
			Scroll.ScrollingEnabled = true
			Scroll.ScrollBarImageTransparency = 0.5
		else
			Scroll.ScrollingEnabled = false
			Scroll.ScrollBarImageTransparency = 1
		end
	end
	List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScrollState)
	Scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScrollState)
	return Scroll
end

local function ClearContainer(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			if child and child.Parent then child:Destroy() end
		end
	end
end

local function AddButton(parent, title, subText, callback)
	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.new(1, -12, 0, 38)
	Frame.BackgroundTransparency = 1
	Frame.ZIndex = 14
	Frame.Parent = parent
	local Btn = Instance.new("TextButton")
	Btn.AnchorPoint = Vector2.new(0.5, 0.5)
	Btn.Position = UDim2.new(0.5, 0, 0.5, 0)
	Btn.Size = UDim2.new(1, 0, 1, 0)
	Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Btn.BackgroundTransparency = 0.6
	Btn.Text = ""
	Btn.ZIndex = 14
	Btn.Parent = Frame
	Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
	local BtnStroke = Instance.new("UIStroke", Btn)
	BtnStroke.Thickness = 1; BtnStroke.Transparency = 0.5; BtnStroke.Color = DynamicContext.CurrentBorderColor
	table.insert(DynamicContext.BorderElements, BtnStroke)
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -16, 0, 18); Label.Position = UDim2.new(0, 10, 0, 2)
	Label.Text = title; Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
	Label.TextXAlignment = Enum.TextXAlignment.Left; Label.BackgroundTransparency = 1; Label.ZIndex = 15; Label.Parent = Btn
	table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})
	if subText then
		local SubLabel = Instance.new("TextLabel")
		SubLabel.Size = UDim2.new(1, -16, 0, 12); SubLabel.Position = UDim2.new(0, 10, 0, 20)
		SubLabel.Text = subText; SubLabel.Font = Enum.Font.Gotham; SubLabel.TextColor3 = DynamicContext.CurrentSubTextColor; SubLabel.TextSize = 8
		SubLabel.TextXAlignment = Enum.TextXAlignment.Left; SubLabel.BackgroundTransparency = 1; SubLabel.ZIndex = 15; SubLabel.Parent = Btn
		table.insert(DynamicContext.TextElements, {Obj = SubLabel, Type = "Sub"})
	end
	
	Btn.MouseButton1Down:Connect(function()
		TweenService:Create(Btn, TweenInfo.new(0.1), {Size = UDim2.new(0.96, 0, 0.9, 0)}):Play()
	end)
	Btn.MouseButton1Up:Connect(function()
		TweenService:Create(Btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
	end)
	Btn.MouseLeave:Connect(function()
		TweenService:Create(Btn, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
	end)
	
	Btn.MouseButton1Click:Connect(function() if callback then callback() end end)
	return Frame
end

local function AddToggle(parent, title, subText, default, callback)
	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.new(1, -12, 0, 38)
	Frame.BackgroundTransparency = 1
	Frame.ZIndex = 14
	Frame.Parent = parent
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(0.6, 0, 0, 18); Label.Position = UDim2.new(0, 0, 0, 2)
	Label.Text = title; Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
	Label.TextXAlignment = Enum.TextXAlignment.Left; Label.TextTruncate = Enum.TextTruncate.AtEnd; Label.BackgroundTransparency = 1; Label.ZIndex = 14; Label.Parent = Frame
	table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})
	if subText then
		local SubLabel = Instance.new("TextLabel")
		SubLabel.Size = UDim2.new(1, -45, 0, 12); SubLabel.Position = UDim2.new(0, 0, 0, 20)
		SubLabel.Text = subText; SubLabel.Font = Enum.Font.Gotham; SubLabel.TextColor3 = DynamicContext.CurrentSubTextColor; SubLabel.TextSize = 8
		SubLabel.TextXAlignment = Enum.TextXAlignment.Left; SubLabel.TextTruncate = Enum.TextTruncate.AtEnd; SubLabel.BackgroundTransparency = 1; SubLabel.ZIndex = 14; SubLabel.Parent = Frame
		table.insert(DynamicContext.TextElements, {Obj = SubLabel, Type = "Sub"})
	end
	local Track = Instance.new("TextButton")
	Track.Size = UDim2.new(0, 36, 0, 18); Track.Position = UDim2.new(1, -38, 0.5, -9)
	Track.BackgroundColor3 = Color3.fromRGB(200, 205, 215); Track.Text = ""; Track.AutoButtonColor = false; Track.ZIndex = 15; Track.Parent = Frame
	Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)
	local Knob = Instance.new("Frame")
	Knob.Size = UDim2.new(0, 14, 0, 14); Knob.AnchorPoint = Vector2.new(0, 0.5); Knob.Position = UDim2.new(0, 2, 0.5, 0)
	Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Knob.ZIndex = 16; Knob.Parent = Track
	Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
	local toggled = default or false
	local function setToggleState(state, animate)
		toggled = state
		local targetColor = toggled and DynamicContext.CurrentActiveColor or Color3.fromRGB(205, 210, 220)
		local targetPos = toggled and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
		if animate then
			TweenService:Create(Track, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
			TweenService:Create(Knob, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPos}):Play()
		else
			Track.BackgroundColor3 = targetColor; Knob.Position = targetPos
		end
		if callback then callback(toggled) end
	end
	Track.MouseButton1Down:Connect(function()
		TweenService:Create(Track, TweenInfo.new(0.1), {Size = UDim2.new(0, 34, 0, 16), Position = UDim2.new(1, -37, 0.5, -8)}):Play()
	end)
	Track.MouseButton1Up:Connect(function()
		TweenService:Create(Track, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -38, 0.5, -9)}):Play()
	end)
	Track.MouseLeave:Connect(function()
		TweenService:Create(Track, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -38, 0.5, -9)}):Play()
	end)
	Track.MouseButton1Click:Connect(function() setToggleState(not toggled, true) end)
	setToggleState(toggled, false)
	table.insert(DynamicContext.ActiveToggles, { Update = function() 
		if toggled and Track.BackgroundColor3 ~= DynamicContext.CurrentActiveColor then
			Track.BackgroundColor3 = DynamicContext.CurrentActiveColor
		end
	end })
	return Frame
end

local activeSlider = nil
UserInputService.InputChanged:Connect(function(input)
	if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		activeSlider.update(input)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if activeSlider then
			activeSlider.onEnd()
			activeSlider = nil
		end
	end
end)

local function AddSlider(parent, title, min, max, default, unit, callback)
	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.new(1, -12, 0, 38)
	Frame.BackgroundTransparency = 1
	Frame.ZIndex = 14
	Frame.Parent = parent
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(0.5, 0, 0, 16); Label.Position = UDim2.new(0, 0, 0, 0)
	Label.Text = title; Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
	Label.TextXAlignment = Enum.TextXAlignment.Left; Label.TextTruncate = Enum.TextTruncate.AtEnd; Label.BackgroundTransparency = 1; Label.ZIndex = 14; Label.Parent = Frame
	table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})
	local ValLabel = Instance.new("TextLabel")
	ValLabel.Size = UDim2.new(0.5, 0, 0, 16); ValLabel.Position = UDim2.new(0.5, 0, 0, 0)
	ValLabel.Text = tostring(default) .. (unit or ""); ValLabel.Font = Enum.Font.Gotham; ValLabel.TextColor3 = DynamicContext.CurrentSubTextColor; ValLabel.TextSize = 10
	ValLabel.TextXAlignment = Enum.TextXAlignment.Right; ValLabel.BackgroundTransparency = 1; ValLabel.ZIndex = 14; ValLabel.Parent = Frame
	table.insert(DynamicContext.TextElements, {Obj = ValLabel, Type = "Sub"})
	local TrackBtn = Instance.new("TextButton")
	TrackBtn.Size = UDim2.new(1, 0, 0, 14); TrackBtn.Position = UDim2.new(0, 0, 0, 18)
	TrackBtn.BackgroundTransparency = 1; TrackBtn.Text = ""; TrackBtn.ZIndex = 15; TrackBtn.Parent = Frame
	local SliderBg = Instance.new("Frame")
	SliderBg.Size = UDim2.new(1, 0, 0, 5); SliderBg.Position = UDim2.new(0, 0, 0.5, -2)
	SliderBg.BackgroundColor3 = Color3.fromRGB(215, 220, 230); SliderBg.ZIndex = 15; SliderBg.Parent = TrackBtn
	Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(1, 0)
	local startRatio = math.clamp((default - min) / math.max(max - min, 1), 0, 1)
	local SliderFill = Instance.new("Frame")
	SliderFill.Size = UDim2.new(startRatio, 0, 1, 0); SliderFill.BackgroundColor3 = DynamicContext.CurrentActiveColor; SliderFill.ZIndex = 15; SliderFill.Parent = SliderBg
	Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)
	local Knob = Instance.new("Frame")
	Knob.Size = UDim2.new(0, 10, 0, 10); Knob.Position = UDim2.new(1, -5, 0.5, -5)
	Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Knob.ZIndex = 16; Knob.Parent = SliderFill
	Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
	
	local function update(input)
		local posX = input.Position.X - SliderBg.AbsolutePosition.X
		local ratio = math.clamp(posX / math.max(SliderBg.AbsoluteSize.X, 1), 0, 1)
		local val = math.floor(min + (max - min) * ratio)
		SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
		ValLabel.Text = tostring(val) .. (unit or "")
		if callback then callback(val) end
	end
	
	TrackBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
			TweenService:Create(Knob, TweenInfo.new(0.1), {Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(1, -6, 0.5, -6)}):Play()
			update(input)
			activeSlider = {
				update = update,
				onEnd = function()
					TweenService:Create(Knob, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(1, -5, 0.5, -5)}):Play()
				end
			}
		end
	end)
	
	table.insert(DynamicContext.ActiveSliders, { Update = function() 
		if SliderFill.BackgroundColor3 ~= DynamicContext.CurrentActiveColor then
			SliderFill.BackgroundColor3 = DynamicContext.CurrentActiveColor
		end
	end })
	return Frame
end

local function AddColorRow(parent, title, getColor, setColor)
	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.new(1, -12, 0, 38); Frame.BackgroundTransparency = 1; Frame.ZIndex = 14; Frame.Parent = parent
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -60, 1, 0); Label.Text = title; Label.Font = Enum.Font.GothamMedium; Label.TextColor3 = DynamicContext.CurrentTextColor; Label.TextSize = 11
	Label.TextXAlignment = Enum.TextXAlignment.Left; Label.BackgroundTransparency = 1; Label.ZIndex = 14; Label.Parent = Frame
	table.insert(DynamicContext.TextElements, {Obj = Label, Type = "Main"})
	local ColorBtn = Instance.new("TextButton")
	ColorBtn.Size = UDim2.new(0, 50, 0, 22); ColorBtn.Position = UDim2.new(1, -50, 0.5, -11); ColorBtn.BackgroundColor3 = getColor(); ColorBtn.Text = ""; ColorBtn.AutoButtonColor = false; ColorBtn.ZIndex = 15; ColorBtn.Parent = Frame
	Instance.new("UICorner", ColorBtn).CornerRadius = UDim.new(0, 6)
	local currentIdx = 1
	for i, c in ipairs(PALETTE) do if c == getColor() then currentIdx = i; break end end
	
	ColorBtn.MouseButton1Down:Connect(function()
		TweenService:Create(ColorBtn, TweenInfo.new(0.1), {Size = UDim2.new(0, 46, 0, 20), Position = UDim2.new(1, -48, 0.5, -10)}):Play()
	end)
	ColorBtn.MouseButton1Up:Connect(function()
		TweenService:Create(ColorBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Size = UDim2.new(0, 50, 0, 22), Position = UDim2.new(1, -50, 0.5, -11)}):Play()
	end)
	ColorBtn.MouseLeave:Connect(function()
		TweenService:Create(ColorBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 50, 0, 22), Position = UDim2.new(1, -50, 0.5, -11)}):Play()
	end)
	
	ColorBtn.MouseButton1Click:Connect(function()
		currentIdx = currentIdx % #PALETTE + 1
		local newColor = PALETTE[currentIdx]
		setColor(newColor)
		ColorBtn.BackgroundColor3 = newColor
	end)
	return Frame
end

local function AddDropdown(parent, title, options, defaultIndex, callback)
	local DropFrame = Instance.new("Frame")
	DropFrame.Size = UDim2.new(1, -12, 0, 32); DropFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255); DropFrame.BackgroundTransparency = 0.5; DropFrame.ClipsDescendants = true; DropFrame.ZIndex = 20; DropFrame.Parent = parent
	Instance.new("UICorner", DropFrame).CornerRadius = UDim.new(0, 6)
	local DropStroke = Instance.new("UIStroke", DropFrame); DropStroke.Thickness = 1; DropStroke.Transparency = 0.5; DropStroke.Color = DynamicContext.CurrentBorderColor; table.insert(DynamicContext.BorderElements, DropStroke)
	local HeaderBtn = Instance.new("TextButton"); HeaderBtn.Size = UDim2.new(1, 0, 0, 32); HeaderBtn.BackgroundTransparency = 1; HeaderBtn.Text = ""; HeaderBtn.ZIndex = 21; HeaderBtn.Parent = DropFrame
	local TitleLabel = Instance.new("TextLabel"); TitleLabel.Size = UDim2.new(0.48, 0, 1, 0); TitleLabel.Position = UDim2.new(0, 8, 0, 0); TitleLabel.Text = title; TitleLabel.Font = Enum.Font.GothamMedium; TitleLabel.TextColor3 = DynamicContext.CurrentTextColor; TitleLabel.TextSize = 10; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.BackgroundTransparency = 1; TitleLabel.ZIndex = 21; TitleLabel.Parent = HeaderBtn; table.insert(DynamicContext.TextElements, {Obj = TitleLabel, Type = "Main"})
	local SelectedLabel = Instance.new("TextLabel"); SelectedLabel.Size = UDim2.new(0.42, -10, 1, 0); SelectedLabel.Position = UDim2.new(0.48, 0, 0, 0); SelectedLabel.Text = options[defaultIndex or 1] or "选择..."; SelectedLabel.Font = Enum.Font.Gotham; SelectedLabel.TextColor3 = DynamicContext.CurrentSubTextColor; SelectedLabel.TextSize = 9; SelectedLabel.TextXAlignment = Enum.TextXAlignment.Right; SelectedLabel.BackgroundTransparency = 1; SelectedLabel.ZIndex = 21; SelectedLabel.Parent = HeaderBtn; table.insert(DynamicContext.TextElements, {Obj = SelectedLabel, Type = "Sub"})
	local ArrowLabel = Instance.new("TextLabel"); ArrowLabel.Size = UDim2.new(0, 14, 1, 0); ArrowLabel.Position = UDim2.new(1, -16, 0, 0); ArrowLabel.Text = "▼"; ArrowLabel.Font = Enum.Font.GothamBold; ArrowLabel.TextColor3 = DynamicContext.CurrentSubTextColor; ArrowLabel.TextSize = 8; ArrowLabel.BackgroundTransparency = 1; ArrowLabel.ZIndex = 21; ArrowLabel.Parent = HeaderBtn; table.insert(DynamicContext.TextElements, {Obj = ArrowLabel, Type = "Sub"})
	local OptionContainer = Instance.new("Frame"); OptionContainer.Size = UDim2.new(1, -10, 0, 0); OptionContainer.Position = UDim2.new(0, 5, 0, 30); OptionContainer.BackgroundTransparency = 1; OptionContainer.ClipsDescendants = true; OptionContainer.ZIndex = 21; OptionContainer.Parent = DropFrame
	local OptionList = Instance.new("UIListLayout"); OptionList.Padding = UDim.new(0, 3); OptionList.SortOrder = Enum.SortOrder.LayoutOrder; OptionList.Parent = OptionContainer
	local isExpanded = false; local optionHeight = 22; local expandedHeight = 34 + (#options * 25)
	for i, optionText in ipairs(options) do
		local OptBtn = Instance.new("TextButton"); OptBtn.Size = UDim2.new(1, 0, 0, optionHeight); OptBtn.BackgroundColor3 = Color3.fromRGB(245, 248, 255); OptBtn.BackgroundTransparency = (i == (defaultIndex or 1)) and 0.2 or 0.7; OptBtn.Text = optionText; OptBtn.Font = Enum.Font.Gotham; OptBtn.TextColor3 = DynamicContext.CurrentTextColor; OptBtn.TextSize = 9; OptBtn.TextTruncate = Enum.TextTruncate.AtEnd; OptBtn.ZIndex = 22; OptBtn.Parent = OptionContainer; table.insert(DynamicContext.TextElements, {Obj = OptBtn, Type = "Main"}); Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)
		OptBtn.MouseButton1Click:Connect(function()
			SelectedLabel.Text = optionText
			for _, child in ipairs(OptionContainer:GetChildren()) do if child:IsA("TextButton") then TweenService:Create(child, TweenInfo.new(0.2), {BackgroundTransparency = (child == OptBtn) and 0.2 or 0.7}):Play() end end
			isExpanded = false
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			TweenService:Create(DropFrame, tweenInfo, {Size = UDim2.new(1, -12, 0, 32)}):Play()
			TweenService:Create(OptionContainer, tweenInfo, {Size = UDim2.new(1, -10, 0, 0)}):Play()
			TweenService:Create(ArrowLabel, tweenInfo, {Rotation = 0}):Play()
			if callback then callback(optionText, i) end
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

local function CreateSubSegmentNav(parent, segments, onSegmentChanged)
	local SegmentFrame = Instance.new("Frame"); SegmentFrame.Size = UDim2.new(1, -16, 0, 26); SegmentFrame.Position = UDim2.new(0, 8, 0, 32); SegmentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255); SegmentFrame.BackgroundTransparency = 0.4; SegmentFrame.BorderSizePixel = 0; SegmentFrame.ZIndex = 15; SegmentFrame.Parent = parent
	Instance.new("UICorner", SegmentFrame).CornerRadius = UDim.new(0, 13)
	local SegStroke = Instance.new("UIStroke", SegmentFrame); SegStroke.Thickness = 1; SegStroke.Transparency = 0.5; SegStroke.Color = DynamicContext.CurrentBorderColor; table.insert(DynamicContext.BorderElements, SegStroke)
	local Indicator = Instance.new("Frame"); Indicator.Size = UDim2.new(1 / #segments, -4, 1, -4); Indicator.Position = UDim2.new(0, 2, 0, 2); Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Indicator.BackgroundTransparency = 0.1; Indicator.ZIndex = 16; Indicator.Parent = SegmentFrame
	Instance.new("UICorner", Indicator).CornerRadius = UDim.new(0, 11)
	local Buttons = {}
	local currentActiveIndex = 1
	for i, segName in ipairs(segments) do
		local Btn = Instance.new("TextButton"); Btn.Size = UDim2.new(1 / #segments, 0, 1, 0); Btn.Position = UDim2.new((i - 1) * (1 / #segments), 0, 0, 0); Btn.BackgroundTransparency = 1; Btn.Text = segName; Btn.Font = Enum.Font.GothamBold; Btn.TextColor3 = (i == 1) and DynamicContext.CurrentTextColor or DynamicContext.CurrentSubTextColor; Btn.TextSize = 9; Btn.ZIndex = 17; Btn.Parent = SegmentFrame
		Btn.MouseButton1Click:Connect(function()
			if i == currentActiveIndex then return end
			currentActiveIndex = i
			for _, b in ipairs(Buttons) do b.TextColor3 = DynamicContext.CurrentSubTextColor end
			Btn.TextColor3 = DynamicContext.CurrentTextColor
			TweenService:Create(Indicator, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new((i - 1) * (1 / #segments), 2, 0, 2)}):Play()
			if onSegmentChanged then onSegmentChanged(segName, i) end
		end)
		table.insert(Buttons, Btn)
	end
	return SegmentFrame
end

local Island = Instance.new("CanvasGroup"); Island.Name = "DynamicIsland"; Island.Size = UDim2.new(0, 200, 0, 36); Island.Position = UDim2.new(0.5, -100, 0, 15); Island.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Island.GroupTransparency = 1; Island.Visible = false; Island.ZIndex = 200; Island.Parent = UiScreenGui
local IslandCorner = Instance.new("UICorner", Island); IslandCorner.CornerRadius = UDim.new(0, 18)
local IslandStroke = Instance.new("UIStroke", Island); IslandStroke.Thickness = 2; IslandStroke.Color = Color3.fromRGB(255, 255, 255)
local IslandGradient = Instance.new("UIGradient", Island); local IslandStrokeGradient = Instance.new("UIGradient", IslandStroke); IslandStrokeGradient.Color = StrokeGradient.Color
local IslandLightOverlay = Instance.new("Frame", Island); IslandLightOverlay.Size = UDim2.new(1, 0, 1, 0); IslandLightOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255); IslandLightOverlay.BackgroundTransparency = 0.35; IslandLightOverlay.ZIndex = 200
local IslandContent = Instance.new("Frame", Island); IslandContent.Size = UDim2.new(1, 0, 1, 0); IslandContent.BackgroundTransparency = 1; IslandContent.ZIndex = 201

local IslandInfoFrame = Instance.new("Frame", IslandContent)
IslandInfoFrame.Size = UDim2.new(0, 140, 1, 0)
IslandInfoFrame.Position = UDim2.new(0, 12, 0, 0)
IslandInfoFrame.BackgroundTransparency = 1
IslandInfoFrame.ZIndex = 202

local InfoLayout = Instance.new("UIListLayout", IslandInfoFrame)
InfoLayout.FillDirection = Enum.FillDirection.Horizontal
InfoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
InfoLayout.SortOrder = Enum.SortOrder.LayoutOrder
InfoLayout.Padding = UDim.new(0, 6)

local IslandLogo = Instance.new("TextLabel", IslandInfoFrame)
IslandLogo.Size = UDim2.new(0, 55, 1, 0)
IslandLogo.Font = Enum.Font.FredokaOne
IslandLogo.Text = "Link.cc"
IslandLogo.TextColor3 = DynamicContext.CurrentLogoColor
IslandLogo.TextSize = 15
IslandLogo.TextXAlignment = Enum.TextXAlignment.Left
IslandLogo.BackgroundTransparency = 1
IslandLogo.ZIndex = 202
IslandLogo.LayoutOrder = 1
IslandLogo.TextTruncate = Enum.TextTruncate.AtEnd

local IslandStatus = Instance.new("TextLabel", IslandInfoFrame)
IslandStatus.Size = UDim2.new(0, 50, 1, 0)
IslandStatus.Font = Enum.Font.GothamMedium
IslandStatus.Text = "运行中"
IslandStatus.TextColor3 = DynamicContext.CurrentSubTextColor
IslandStatus.TextSize = 10
IslandStatus.TextXAlignment = Enum.TextXAlignment.Left
IslandStatus.BackgroundTransparency = 1
IslandStatus.ZIndex = 202
IslandStatus.LayoutOrder = 2
IslandStatus.TextTruncate = Enum.TextTruncate.AtEnd
table.insert(DynamicContext.TextElements, {Obj = IslandStatus, Type = "Sub"})

local ExpandBtn = Instance.new("TextButton", IslandContent); ExpandBtn.Size = UDim2.new(0, 50, 0, 22); ExpandBtn.Position = UDim2.new(1, -58, 0.5, -11); ExpandBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); ExpandBtn.BackgroundTransparency = 0.2; ExpandBtn.Text = "打开"; ExpandBtn.Font = Enum.Font.GothamBold; ExpandBtn.TextColor3 = DynamicContext.CurrentTextColor; ExpandBtn.TextSize = 10; ExpandBtn.ZIndex = 203; Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 11); table.insert(DynamicContext.TextElements, {Obj = ExpandBtn, Type = "Main"})

local function AnimateSubPageTransition(container, buildContentFunc)
	local oldPage = container:FindFirstChild("SubContentPage")
	if oldPage then oldPage:Destroy() end
	
	local newPage = Instance.new("CanvasGroup")
	newPage.Name = "SubContentPage"; newPage.Size = UDim2.new(1, 0, 1, -68); newPage.Position = UDim2.new(0, 0, 0, 50); newPage.BackgroundTransparency = 1; newPage.GroupTransparency = 1; newPage.ZIndex = 14; newPage.Parent = container
	local Scroll = CreateScrollList(newPage, 0)
	buildContentFunc(Scroll)
	TweenService:Create(newPage, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 68), GroupTransparency = 0}):Play()
end

local TabData = {
	["自瞄"] = {
		hasSub = true,
		render = function()
			ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
			DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}; DynamicContext.TextElements = {}; DynamicContext.BorderElements = {}
			local Title = Instance.new("TextLabel", MainConfigCard); Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "自瞄系统"; Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13; table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})
			CreateSubSegmentNav(MainConfigCard, {"基础设置", "高级参数", "静默开火"}, function(seg)
				AnimateSubPageTransition(MainConfigCard, function(scroll)
					if seg == "基础设置" then
						AddToggle(scroll, "启用自瞄", "开启自瞄系统", CFG.aimbot, function(v) CFG.aimbot = v; if not v then Aim.point = nil end end)
						AddToggle(scroll, "静默模式", "视角不转动", CFG.silent, function(v) CFG.silent = v end)
						AddToggle(scroll, "自动开火", "锁定后自动射击", CFG.autoFire, function(v) CFG.autoFire = v; if not v then forceRelease() end end)
						AddToggle(scroll, "瞄准怪物", "锁定目标包含怪物", CFG.aimMonsters, function(v) CFG.aimMonsters = v end)
						AddToggle(scroll, "瞄准玩家", "锁定目标包含玩家", CFG.aimPlayers, function(v) CFG.aimPlayers = v end)
						AddToggle(scroll, "360° 锁敌", "无视屏幕范围锁定", CFG.aim360, function(v) CFG.aim360 = v end)
						AddSlider(scroll, "角度上限", 5, 180, CFG.fovAngle, "°", function(v) CFG.fovAngle = v end)
						AddSlider(scroll, "FOV 半径", 40, 1600, CFG.fov, "", function(v) CFG.fov = v end)
						AddDropdown(scroll, "瞄准部位", {"头部", "躯干"}, (CFG.aimPart == "Head") and 1 or 2, function(selected, idx)
							CFG.aimPart = (idx == 1) and "Head" or "Torso"
						end)
					elseif seg == "高级参数" then
						AddToggle(scroll, "伪装摄像机", "服务端视角同步", CFG.spoofCam, function(v) CFG.spoofCam = v end)
						AddToggle(scroll, "只打可见目标", "无遮挡才锁定", CFG.visibleOnly, function(v) CFG.visibleOnly = v end)
						AddToggle(scroll, "智能部位", "自动选取露出部位", CFG.aimSmartPart, function(v) CFG.aimSmartPart = v end)
						AddToggle(scroll, "弹道补偿", "补偿子弹下坠", CFG.dropComp, function(v) CFG.dropComp = v end)
						AddToggle(scroll, "枪口偏移", "绕过掩体", CFG.muzzleOffset, function(v) CFG.muzzleOffset = v end)
						AddSlider(scroll, "偏移搜索半径", 1, 5, math.floor(CFG.muzzleRadius), "", function(v) CFG.muzzleRadius = v end)
						AddSlider(scroll, "偏移步长", 1, 5, math.floor(CFG.muzzleStep), "", function(v) CFG.muzzleStep = v end)
						AddToggle(scroll, "无视盾牌", "过滤敌方盾牌", CFG.noShield, function(v) CFG.noShield = v end)
					elseif seg == "静默开火" then
						AddToggle(scroll, "静默自动射击", "真实开火但有特效", CFG.packetMode, function(v) CFG.packetMode = v end)
						AddToggle(scroll, "完全静默", "仅发包无特效", CFG.silentPacket, function(v) CFG.silentPacket = v end)
					end
				end)
			end)
			AnimateSubPageTransition(MainConfigCard, function(scroll)
				AddToggle(scroll, "启用自瞄", "开启自瞄系统", CFG.aimbot, function(v) CFG.aimbot = v; if not v then Aim.point = nil end end)
				AddToggle(scroll, "静默模式", "视角不转动", CFG.silent, function(v) CFG.silent = v end)
				AddToggle(scroll, "自动开火", "锁定后自动射击", CFG.autoFire, function(v) CFG.autoFire = v; if not v then forceRelease() end end)
				AddToggle(scroll, "瞄准怪物", "锁定目标包含怪物", CFG.aimMonsters, function(v) CFG.aimMonsters = v end)
				AddToggle(scroll, "瞄准玩家", "锁定目标包含玩家", CFG.aimPlayers, function(v) CFG.aimPlayers = v end)
				AddSlider(scroll, "FOV 半径", 40, 1600, CFG.fov, "", function(v) CFG.fov = v end)
				AddDropdown(scroll, "瞄准部位", {"头部", "躯干"}, (CFG.aimPart == "Head") and 1 or 2, function(selected, idx)
					CFG.aimPart = (idx == 1) and "Head" or "Torso"
				end)
			end)
			
			local SubTitle = Instance.new("TextLabel", SubConfigCard); SubTitle.Size = UDim2.new(1, -16, 0, 25); SubTitle.Position = UDim2.new(0, 8, 0, 6); SubTitle.Text = "快捷面板"; SubTitle.Font = Enum.Font.GothamBold; SubTitle.TextColor3 = DynamicContext.CurrentTextColor; SubTitle.TextSize = 13; SubTitle.TextXAlignment = Enum.TextXAlignment.Left; SubTitle.BackgroundTransparency = 1; SubTitle.ZIndex = 13; table.insert(DynamicContext.TextElements, {Obj = SubTitle, Type = "Main"})
			local SubScroll = CreateScrollList(SubConfigCard, 35)
			AddToggle(SubScroll, "启用", "快捷开关", CFG.aimbot, function(v) CFG.aimbot = v end)
			AddToggle(SubScroll, "静默", "隐藏视角转动", CFG.silent, function(v) CFG.silent = v end)
			AddToggle(SubScroll, "自动", "自动开火", CFG.autoFire, function(v) CFG.autoFire = v end)
			AddSlider(SubScroll, "FOV", 40, 1600, CFG.fov, "", function(v) CFG.fov = v end)
		end
	},
	["透视"] = {
		hasSub = false,
		render = function()
			ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
			DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}; DynamicContext.TextElements = {}; DynamicContext.BorderElements = {}
			local Title = Instance.new("TextLabel", MainConfigCard); Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "ESP 透视"; Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13; table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})
			CreateSubSegmentNav(MainConfigCard, {"绘制开关", "显示元素", "目标颜色"}, function(seg)
				AnimateSubPageTransition(MainConfigCard, function(scroll)
					if seg == "绘制开关" then
						AddToggle(scroll, "玩家 ESP", "显示玩家方框", CFG.espPlayers, function(v) CFG.espPlayers = v end)
						AddToggle(scroll, "怪物 ESP", "显示怪物方框", CFG.espMonsters, function(v) CFG.espMonsters = v end)
						AddToggle(scroll, "物品 ESP", "显示物品", CFG.espItems, function(v) CFG.espItems = v end)
						AddToggle(scroll, "弹药 ESP", "显示弹药补给点", CFG.espAmmo, function(v) CFG.espAmmo = v end)
						AddToggle(scroll, "好友 ESP", "独立标记好友", CFG.espFriends, function(v) CFG.espFriends = v end)
						AddToggle(scroll, "显示自己", "在 ESP 中显示自身", CFG.showSelf, function(v) CFG.showSelf = v end)
					elseif seg == "显示元素" then
						AddToggle(scroll, "方框", "绘制目标方框", CFG.box, function(v) CFG.box = v end)
						AddToggle(scroll, "名字", "显示目标名称", CFG.name, function(v) CFG.name = v end)
						AddToggle(scroll, "血量", "显示目标血量", CFG.health, function(v) CFG.health = v end)
						AddToggle(scroll, "距离", "显示距离数值", CFG.distance, function(v) CFG.distance = v end)
						AddToggle(scroll, "屏幕连线", "从屏幕底部画线", CFG.tracer, function(v) CFG.tracer = v end)
						AddSlider(scroll, "最大距离", 50, 2000, CFG.maxDist, "米", function(v) CFG.maxDist = v end)
					elseif seg == "目标颜色" then
						AddColorRow(scroll, "玩家颜色", function() return CFG.colorPlayer end, function(v) CFG.colorPlayer = v end)
						AddColorRow(scroll, "好友颜色", function() return CFG.colorFriend end, function(v) CFG.colorFriend = v end)
						AddColorRow(scroll, "怪物颜色", function() return CFG.colorMonster end, function(v) CFG.colorMonster = v end)
						AddColorRow(scroll, "Boss 颜色", function() return CFG.colorBoss end, function(v) CFG.colorBoss = v end)
						AddColorRow(scroll, "物品颜色", function() return CFG.colorItem end, function(v) CFG.colorItem = v end)
						AddColorRow(scroll, "弹药颜色", function() return CFG.colorAmmo end, function(v) CFG.colorAmmo = v end)
					end
				end)
			end)
			AnimateSubPageTransition(MainConfigCard, function(scroll)
				AddToggle(scroll, "玩家 ESP", "显示玩家方框", CFG.espPlayers, function(v) CFG.espPlayers = v end)
				AddToggle(scroll, "怪物 ESP", "显示怪物方框", CFG.espMonsters, function(v) CFG.espMonsters = v end)
				AddToggle(scroll, "物品 ESP", "显示物品", CFG.espItems, function(v) CFG.espItems = v end)
				AddToggle(scroll, "弹药 ESP", "显示弹药补给点", CFG.espAmmo, function(v) CFG.espAmmo = v end)
				AddToggle(scroll, "好友 ESP", "独立标记好友", CFG.espFriends, function(v) CFG.espFriends = v end)
				AddToggle(scroll, "显示自己", "在 ESP 中显示自身", CFG.showSelf, function(v) CFG.showSelf = v end)
			end)
		end
	},
	["角色"] = {
		hasSub = false,
		render = function()
			ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
			DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}; DynamicContext.TextElements = {}; DynamicContext.BorderElements = {}
			local Title = Instance.new("TextLabel", MainConfigCard); Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "角色属性"; Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13; table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})
			local Scroll = CreateScrollList(MainConfigCard, 35)
			AddToggle(Scroll, "无限体力", "不会疲劳耗尽体力", CFG.infStamina, function(v) CFG.infStamina = v end)
			AddToggle(Scroll, "修改移动速度", "覆盖默认移速", CFG.changeSpeed, function(v) CFG.changeSpeed = v end)
			AddSlider(Scroll, "移动速度", 16, 120, CFG.walkSpeed, "", function(v) CFG.walkSpeed = v end)
			AddToggle(Scroll, "修改跳跃力", "覆盖默认跳跃力", CFG.changeJump, function(v) CFG.changeJump = v end)
			AddSlider(Scroll, "跳跃力", 50, 200, CFG.jumpPower, "", function(v) CFG.jumpPower = v end)
			AddToggle(Scroll, "无坠落伤害", "安全下落", CFG.noFall, function(v) CFG.noFall = v end)
			AddSlider(Scroll, "安全下落速度", 20, 200, CFG.fallSpeed, "", function(v) CFG.fallSpeed = v end)
		end
	},
	["视觉"] = {
		hasSub = false,
		render = function()
			ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
			DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}; DynamicContext.TextElements = {}; DynamicContext.BorderElements = {}
			local Title = Instance.new("TextLabel", MainConfigCard); Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "视觉特效"; Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13; table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})
			CreateSubSegmentNav(MainConfigCard, {"子弹轨迹", "环境修改"}, function(seg)
				AnimateSubPageTransition(MainConfigCard, function(scroll)
					if seg == "子弹轨迹" then
						AddToggle(scroll, "子弹轨迹", "显示子弹飞行轨迹", CFG.trail, function(v) CFG.trail = v end)
						AddToggle(scroll, "枪口特效", "显示开火闪光", CFG.muzzleTrail, function(v) CFG.muzzleTrail = v end)
						AddSlider(scroll, "轨迹持续时间", 1, 10, CFG.trailTime, "秒", function(v) CFG.trailTime = v end)
						AddToggle(scroll, "他人弹道", "显示队友或怪物轨迹", CFG.otherTrails, function(v) CFG.otherTrails = v end)
						AddColorRow(scroll, "轨迹颜色", function() return CFG.trailColor end, function(v) CFG.trailColor = v end)
						AddColorRow(scroll, "队友颜色", function() return CFG.colorTeamTrail end, function(v) CFG.colorTeamTrail = v end)
						AddColorRow(scroll, "怪物颜色", function() return CFG.colorEnemyTrail end, function(v) CFG.colorEnemyTrail = v end)
					else
						AddToggle(scroll, "除雾", "移除场景雾气", CFG.noFog, function(v) CFG.noFog = v; applyWorld() end)
						AddToggle(scroll, "地图高亮", "提高场景亮度", CFG.mapGlow, function(v) CFG.mapGlow = v; applyWorld() end)
					end
				end)
			end)
			AnimateSubPageTransition(MainConfigCard, function(scroll)
				AddToggle(scroll, "子弹轨迹", "显示子弹飞行轨迹", CFG.trail, function(v) CFG.trail = v end)
				AddToggle(scroll, "枪口特效", "显示开火闪光", CFG.muzzleTrail, function(v) CFG.muzzleTrail = v end)
				AddSlider(scroll, "轨迹持续时间", 1, 10, CFG.trailTime, "秒", function(v) CFG.trailTime = v end)
				AddToggle(scroll, "他人弹道", "显示队友或怪物轨迹", CFG.otherTrails, function(v) CFG.otherTrails = v end)
			end)
		end
	},
	["系统"] = {
		hasSub = false,
		render = function()
			ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
			DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}; DynamicContext.TextElements = {}; DynamicContext.BorderElements = {}
			local Title = Instance.new("TextLabel", MainConfigCard); Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "系统与调试"; Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13; table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})
			CreateSubSegmentNav(MainConfigCard, {"调试工具", "界面配置"}, function(seg)
				AnimateSubPageTransition(MainConfigCard, function(scroll)
					if seg == "调试工具" then
						AddButton(scroll, "清除轨迹", "移除所有生成的轨迹", function()
							for _, v in ipairs(workspace.Terrain:GetChildren()) do
								if v.Name == "__btrTrail" or v.Name == "__btrMuzzle" or v.Name == "__btrImpact" then v:Destroy() end
							end
						end)
						AddButton(scroll, "重新连接网络", "重新装载钩子", function()
							Network = nil; installNetHooks(); installRayHooks()
							if NB then NB.onFire = onFirePacket; NB.onHit = onHitPacket end
						end)
					else
						AddDropdown(scroll, "界面主题", PaletteNames, 3, function(selected) 
							local keys = {}
							for k in pairs(PalettePresets) do table.insert(keys, k) end
							ApplyPalette(keys[table.find(PaletteNames, selected) or 1]) 
						end)
					end
				end)
			end)
			AnimateSubPageTransition(MainConfigCard, function(scroll)
				AddButton(scroll, "清除轨迹", "移除所有生成的轨迹", function()
					for _, v in ipairs(workspace.Terrain:GetChildren()) do
						if v.Name == "__btrTrail" or v.Name == "__btrMuzzle" or v.Name == "__btrImpact" then v:Destroy() end
					end
				end)
				AddButton(scroll, "重新连接网络", "重新装载钩子", function()
					Network = nil; installNetHooks(); installRayHooks()
					if NB then NB.onFire = onFirePacket; NB.onHit = onHitPacket end
				end)
				-- 补充默认渲染的界面主题下拉框，防止切回来不显示
				AddDropdown(scroll, "界面主题", PaletteNames, 3, function(selected) 
					local keys = {}
					for k in pairs(PalettePresets) do table.insert(keys, k) end
					ApplyPalette(keys[table.find(PaletteNames, selected) or 1]) 
				end)
			end)
		end
	},
	["关于"] = {
		hasSub = false,
		render = function()
			ClearContainer(MainConfigCard); ClearContainer(SubConfigCard)
			DynamicContext.ActiveToggles = {}; DynamicContext.ActiveSliders = {}; DynamicContext.TextElements = {}; DynamicContext.BorderElements = {}
			local Title = Instance.new("TextLabel", MainConfigCard); Title.Size = UDim2.new(1, -20, 0, 25); Title.Position = UDim2.new(0, 10, 0, 6); Title.Text = "关于与帮助"; Title.Font = Enum.Font.GothamBold; Title.TextColor3 = DynamicContext.CurrentTextColor; Title.TextSize = 13; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.BackgroundTransparency = 1; Title.ZIndex = 13; table.insert(DynamicContext.TextElements, {Obj = Title, Type = "Main"})
			CreateSubSegmentNav(MainConfigCard, {"更新公告", "快捷键"}, function(seg)
				AnimateSubPageTransition(MainConfigCard, function(scroll)
					if seg == "更新公告" then
						local infoFrame = Instance.new("Frame")
						infoFrame.Size = UDim2.new(1, -12, 0, 160)
						infoFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
						infoFrame.BackgroundTransparency = 0.7
						infoFrame.ZIndex = 14
						infoFrame.Parent = scroll
						Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 8)
						
						local infoTxt = Instance.new("TextLabel")
						infoTxt.Size = UDim2.new(1, -20, 1, -20)
						infoTxt.Position = UDim2.new(0, 10, 0, 10)
						infoTxt.BackgroundTransparency = 1
						infoTxt.TextColor3 = DynamicContext.CurrentTextColor
						infoTxt.Font = Enum.Font.Gotham
						infoTxt.TextSize = 11
						infoTxt.TextXAlignment = Enum.TextXAlignment.Left
						infoTxt.TextYAlignment = Enum.TextYAlignment.Top
						infoTxt.TextWrapped = true
						infoTxt.Text = "【更新公告】\n- 修复下拉菜单消失问题\n- 补齐了默认页漏掉的控件\n- 增加下拉菜单展开空间"
						infoTxt.ZIndex = 15
						infoTxt.Parent = infoFrame
						table.insert(DynamicContext.TextElements, {Obj = infoTxt, Type = "Main"})
					else
						AddButton(scroll, "按 RightShift", "显示 / 隐藏 UI", function() end)
						AddButton(scroll, "点击 Logo", "收起为悬浮小岛", function() end)
						AddButton(scroll, "双击悬浮小岛", "展开 / 收起", function() end)
					end
				end)
			end)
			AnimateSubPageTransition(MainConfigCard, function(scroll)
				local infoFrame = Instance.new("Frame")
				infoFrame.Size = UDim2.new(1, -12, 0, 160)
				infoFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				infoFrame.BackgroundTransparency = 0.7
				infoFrame.ZIndex = 14
				infoFrame.Parent = scroll
				Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 8)
				
				local infoTxt = Instance.new("TextLabel")
				infoTxt.Size = UDim2.new(1, -20, 1, -20)
				infoTxt.Position = UDim2.new(0, 10, 0, 10)
				infoTxt.BackgroundTransparency = 1
				infoTxt.TextColor3 = DynamicContext.CurrentTextColor
				infoTxt.Font = Enum.Font.Gotham
				infoTxt.TextSize = 11
				infoTxt.TextXAlignment = Enum.TextXAlignment.Left
				infoTxt.TextYAlignment = Enum.TextYAlignment.Top
				infoTxt.TextWrapped = true
				infoTxt.Text = "【更新公告】\n- 修复下拉菜单消失问题\n- 补齐了默认页漏掉的控件\n- 增加下拉菜单展开空间"
				infoTxt.ZIndex = 15
				infoTxt.Parent = infoFrame
				table.insert(DynamicContext.TextElements, {Obj = infoTxt, Type = "Main"})
			end)
		end
	}
}

local NavLayout = Instance.new("UIListLayout", NavCard); NavLayout.Padding = UDim.new(0, 4); NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
local NavPadding = Instance.new("UIPadding", NavCard); NavPadding.PaddingTop = UDim.new(0, 8); NavPadding.PaddingLeft = UDim.new(0, 8); NavPadding.PaddingRight = UDim.new(0, 8)
local Buttons = {}
local Tabs = {"自瞄", "透视", "角色", "视觉", "系统", "关于"}

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
	if DynamicContext.TabSwitchThread then task.cancel(DynamicContext.TabSwitchThread) end
	DynamicContext.TabSwitchThread = task.spawn(function()
		local tabInfo = TabData[tabName]
		if tabInfo then
			AdjustLayoutMode(tabInfo.hasSub)
			tabInfo.render()
		end
	end)
end

for _, name in ipairs(Tabs) do
	local Btn = Instance.new("TextButton", NavCard)
	Btn.Size = UDim2.new(1, 0, 0, 28)
	Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Btn.BackgroundTransparency = 0.85
	Btn.Text = name
	Btn.TextColor3 = DynamicContext.CurrentSubTextColor
	Btn.Font = Enum.Font.GothamMedium
	Btn.TextSize = 12
	Btn.ZIndex = 13
	Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
	Buttons[name] = Btn
	Btn.MouseButton1Click:Connect(function() SwitchTabWithAnimation(name) end)
end

task.spawn(function()
	while task.wait(0.016) do
		DynamicContext.StrokeRotation = (DynamicContext.StrokeRotation + 2.5) % 360
		StrokeGradient.Rotation = DynamicContext.StrokeRotation
		IslandStrokeGradient.Rotation = DynamicContext.StrokeRotation
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local lerpSpeed = math.clamp(dt * 3.5, 0, 1)
	for i = 1, 5 do DynamicContext.CurrentPalette[i] = DynamicContext.CurrentPalette[i]:Lerp(DynamicContext.TargetPalette[i], lerpSpeed) end
	DynamicContext.CurrentLogoColor = DynamicContext.CurrentLogoColor:Lerp(DynamicContext.TargetLogoColor, lerpSpeed)
	DynamicContext.CurrentActiveColor = DynamicContext.CurrentActiveColor:Lerp(DynamicContext.TargetActiveColor, lerpSpeed)
	DynamicContext.CurrentTextColor = DynamicContext.CurrentTextColor:Lerp(DynamicContext.TargetTextColor, lerpSpeed)
	DynamicContext.CurrentSubTextColor = DynamicContext.CurrentSubTextColor:Lerp(DynamicContext.TargetSubTextColor, lerpSpeed)
	DynamicContext.CurrentBorderColor = DynamicContext.CurrentBorderColor:Lerp(DynamicContext.TargetBorderColor, lerpSpeed)
	
	LogoBtn.TextColor3 = DynamicContext.CurrentLogoColor
	IslandLogo.TextColor3 = DynamicContext.CurrentLogoColor
	
	for _, item in ipairs(DynamicContext.TextElements) do
		if item.Obj and item.Obj.Parent then
			if item.Type == "Main" then
				if Buttons[item.Obj.Text] and item.Obj.Text == DynamicContext.CurrentTab then
					item.Obj.TextColor3 = DynamicContext.CurrentTextColor
				elseif Buttons[item.Obj.Text] then
					item.Obj.TextColor3 = DynamicContext.CurrentSubTextColor
				else
					item.Obj.TextColor3 = DynamicContext.CurrentTextColor
				end
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
	
	DynamicContext.BgPhase = DynamicContext.BgPhase + dt * 0.25
	local wave1 = (math.sin(DynamicContext.BgPhase) + 1) / 2
	local wave2 = (math.sin(DynamicContext.BgPhase * 1.3 + 1.2) + 1) / 2
	local c1 = DynamicContext.CurrentPalette[1]:Lerp(DynamicContext.CurrentPalette[2], wave1)
	local c2 = DynamicContext.CurrentPalette[2]:Lerp(DynamicContext.CurrentPalette[4], wave2)
	local c3 = DynamicContext.CurrentPalette[3]:Lerp(DynamicContext.CurrentPalette[5], wave1)
	local newSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, c1),
		ColorSequenceKeypoint.new(0.5, c2),
		ColorSequenceKeypoint.new(1.0, c3)
	})
	MainGradient.Color = newSeq
	MainGradient.Rotation = (MainGradient.Rotation + dt * 8) % 360
	IslandGradient.Color = newSeq
	IslandGradient.Rotation = MainGradient.Rotation
end)

local isBallMode, autoBallTask = false, nil
local function SmoothToBall()
	if isBallMode then return end
	isBallMode = true
	local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	IslandLogo.Visible = false; IslandStatus.Visible = false; ExpandBtn.Visible = false
	local targetOffset = (Island.Position.X.Offset + (Island.Size.X.Offset / 2)) - 18
	TweenService:Create(Island, tweenInfo, {Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(Island.Position.X.Scale, targetOffset, Island.Position.Y.Scale, Island.Position.Y.Offset)}):Play()
	TweenService:Create(IslandCorner, tweenInfo, {CornerRadius = UDim.new(1, 0)}):Play()
end

local function SmoothToRectangle()
	if not isBallMode then return end
	isBallMode = false
	local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local targetOffset = (Island.Position.X.Offset + (Island.Size.X.Offset / 2)) - 100
	TweenService:Create(Island, tweenInfo, {Size = UDim2.new(0, 200, 0, 36), Position = UDim2.new(Island.Position.X.Scale, targetOffset, Island.Position.Y.Scale, Island.Position.Y.Offset)}):Play()
	TweenService:Create(IslandCorner, tweenInfo, {CornerRadius = UDim.new(0, 18)}):Play()
	task.delay(0.2, function()
		IslandLogo.Visible = true; IslandStatus.Visible = true; ExpandBtn.Visible = true
	end)
	if autoBallTask then task.cancel(autoBallTask) end
	autoBallTask = task.delay(3.5, SmoothToBall)
end

local lastClickTime = 0
local longPressTime = 0.6
local islandDragging, islandDragStart, islandStartPos, pressStartTime, isPressing, longPressTask = false, Vector2.new(), UDim2.new(), 0, false, nil

Island.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isPressing = true; pressStartTime = os.clock(); islandDragStart = Vector2.new(input.Position.X, input.Position.Y); islandStartPos = Island.Position
		if longPressTask then task.cancel(longPressTask) end
		longPressTask = task.delay(longPressTime, function()
			if isPressing and not islandDragging then
				islandDragging = true
				TweenService:Create(IslandStroke, TweenInfo.new(0.2), {Thickness = 4}):Play()
			end
		end)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if isPressing then
			local duration = os.clock() - pressStartTime
			isPressing = false
			if longPressTask then task.cancel(longPressTask) end
			if islandDragging then
				islandDragging = false
				TweenService:Create(IslandStroke, TweenInfo.new(0.2), {Thickness = 2}):Play()
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
end)

UserInputService.InputChanged:Connect(function(input)
	if islandDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = Vector2.new(input.Position.X, input.Position.Y) - islandDragStart
		Island.Position = UDim2.new(islandStartPos.X.Scale, islandStartPos.X.Offset + delta.X, islandStartPos.Y.Scale, islandStartPos.Y.Offset + delta.Y)
	end
end)

local function HideMainAndShowIsland()
	local shrinkTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(MainFrame, shrinkTweenInfo, {GroupTransparency = 1, Size = UDim2.new(0, 480, 0, 290), Position = UDim2.new(0.5, -240, 0.5, -145)}):Play()
	task.delay(0.25, function()
		MainFrame.Visible = false
		MainFrame.Size = UDim2.new(0, 530, 0, 320)
		MainFrame.Position = UDim2.new(0.5, -265, 0.5, -160)
		
		Island.Visible = true; Island.GroupTransparency = 1; Island.Size = UDim2.new(0, 140, 0, 30)
		
		IslandCorner.CornerRadius = UDim.new(0, 15); isBallMode = false
		IslandLogo.Visible = true; IslandStatus.Visible = true; ExpandBtn.Visible = true
		local islandShowTween = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(Island, islandShowTween, {GroupTransparency = 0, Size = UDim2.new(0, 200, 0, 36), Position = UDim2.new(Island.Position.X.Scale, Island.Position.X.Offset, Island.Position.Y.Scale, Island.Position.Y.Offset)}):Play()
		TweenService:Create(IslandCorner, islandShowTween, {CornerRadius = UDim.new(0, 18)}):Play()
		if autoBallTask then task.cancel(autoBallTask) end
		autoBallTask = task.delay(3, SmoothToBall)
	end)
end

local function HideIslandAndShowMain()
	if autoBallTask then task.cancel(autoBallTask) end
	local hideIslandTween = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	TweenService:Create(Island, hideIslandTween, {GroupTransparency = 1, Size = UDim2.new(0, 150, 0, 30), Position = UDim2.new(Island.Position.X.Scale, Island.Position.X.Offset, Island.Position.Y.Scale, Island.Position.Y.Offset)}):Play()
	task.delay(0.2, function()
		Island.Visible = false
		MainFrame.Visible = true; MainFrame.GroupTransparency = 1; MainFrame.Size = UDim2.new(0, 490, 0, 296); MainFrame.Position = UDim2.new(0.5, -245, 0.5, -148)
		TweenService:Create(MainFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			GroupTransparency = 0, Size = UDim2.new(0, 530, 0, 320), Position = UDim2.new(0.5, -265, 0.5, -160)
		}):Play()
	end)
end

LogoBtn.MouseButton1Click:Connect(HideMainAndShowIsland)
ExpandBtn.MouseButton1Click:Connect(HideIslandAndShowMain)

MainFrame.Visible = true
MainFrame.Position = UDim2.new(0.5, -265, 0.5, -160)
MainFrame.GroupTransparency = 1
SwitchTabWithAnimation("自瞄")
TweenService:Create(MainFrame, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		UiScreenGui.Enabled = not UiScreenGui.Enabled
		if UiScreenGui.Enabled and not MainFrame.Visible and not Island.Visible then
			MainFrame.Visible = true; MainFrame.GroupTransparency = 0
		end
	end
end)

installNetHooks()
installRayHooks()
if NB then NB.onFire = onFirePacket; NB.onHit = onHitPacket end
if CFG.noFog or CFG.mapGlow then applyWorld() end

task.spawn(function()
	task.wait(0.5)
	pcall(scanAmmo)
	HUB.ammoCount = #ammoCache
end)

table.insert(HUB.conns, LP.CharacterAdded:Connect(function()
	Aim.point = nil; Aim.target = nil; Aim.part = nil; Aim.occluded = false; Aim.gunCfg = nil
	gunCfgCache = {}
	staminaGui.bar = nil; staminaGui.vig = nil; staminaGui.last = 0
	forceRelease()
end))

HUB.cfg = CFG
HUB.stats = STATS
HUB.destroy = function()
	pcall(removeSpeedHook); pcall(forceRelease)
	if lightBackup then CFG.noFog = false; CFG.mapGlow = false; pcall(applyWorld) end
	for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
	if hasDrawing then
		for _, e in pairs(pool) do for _, d in pairs(e) do pcall(function() d:Remove() end) end end
		if fovCircle then pcall(function() fovCircle:Remove() end) end
	end
	if toastGui and toastGui.Parent then pcall(function() toastGui:Destroy() end) end
	pcall(function() UiScreenGui:Destroy() end)
	genv.__BTRHUB = nil
end

print("[Link.cc] UI 完整版 已加载 OK   RightShift 显示/隐藏")