local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer

local FIRST_URL = nil
local SECOND_URL = "https://raw.githubusercontent.com/jianlobiano/LOADER/refs/heads/main/JX-Loader"
local POINT_FILE = "crime_touch_points.json"
local RESET_DELAY_SEC = 1

local function _isfile(name)
    if type(isfile) == "function" then
        local ok, res = pcall(isfile, name)
        if ok then return res end
    end
    if type(readfile) == "function" then
        local ok, _ = pcall(readfile, name)
        return ok
    end
    if syn and syn.read_file then
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
    pcall(function()
        if type(delfile) == "function" then delfile(name) end
    end)
    pcall(function()
        if syn and syn.delete_file then syn.delete_file(name) end
    end)
    pcall(function() _writefile(name, HttpService:JSONEncode({})) end)
end

local function savePointsToFile(pttbl)
    local data = { points = pttbl.points or {}, interval = pttbl.interval or 0 }
    local ok, enc = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then
        warn("[points] encode failed", enc)
        return false
    end
    local wrote = _writefile(POINT_FILE, enc)
    if not wrote then
        warn("[points] write file failed")
        return false
    end
    return true
end
local function loadPointsFromFile()
    if not _isfile(POINT_FILE) then return nil end
    local content = _readfile(POINT_FILE)
    if not content or content == "" then return nil end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok or type(decoded) ~= "table" then return nil end
    decoded.points = decoded.points or {}
    decoded.interval = tonumber(decoded.interval) or 0
    for i,p in ipairs(decoded.points) do
        p.x = tonumber(p.x) or 0
        p.y = tonumber(p.y) or 0
        if not p.ts then p.ts = tick() end
    end
    return decoded
end
local function clearPointsFile() _delfile(POINT_FILE) end

local function safeLoadAndRunCode(code, srcName)
    if not code then return false, "no code" end
    local loader = loadstring or load
    if not loader then return false, "no loader" end
    local ok, fnOrErr = pcall(function() return loader(code) end)
    if not ok then return false, fnOrErr end
    if type(fnOrErr) ~= "function" then return false, "not function" end
    local ok2, res = pcall(fnOrErr)
    return ok2, res
end
local function fetchAndRun(url, name)
    if not url or url == "" then return end
    spawn(function()
        local ok, codeOrErr = pcall(function() return game:HttpGet(url) end)
        if not ok then warn(("fetchAndRun[%s] HttpGet failed: %s"):format(tostring(name or url), tostring(codeOrErr))); return end
        safeLoadAndRunCode(codeOrErr, name or url)
    end)
end

local function tryLocalDesync(on)
    local plsraknet = nil
    pcall(function()
        if rawget and rawget(_G, "Raknet") then plsraknet = rawget(_G, "Raknet")
        elseif rawget and rawget(_G, "raknet") then plsraknet = rawget(_G, "raknet")
        else plsraknet = (Raknet or raknet) end
    end)
    if not plsraknet then warn("[desync] local Raknet not found"); return false end
    if type(plsraknet.desync) == "function" then pcall(function() plsraknet.desync(on) end); print("[desync] called local desync(", tostring(on), ")"); return true end
    warn("[desync] found Raknet but missing desync method"); return false
end

spawn(function()
    pcall(function() tryLocalDesync(true) end)

    if FIRST_URL and FIRST_URL ~= "" then
        print("[auto-run] fetching & running first script:", FIRST_URL)
        fetchAndRun(FIRST_URL, "des-remote")
    end

    spawn(function()
        task.wait(RESET_DELAY_SEC)
        pcall(function()
            local pl = Players.LocalPlayer
            if not pl then return end
            local ch = pl.Character or pl.CharacterAdded:Wait(2)
            if not ch then return end
            local hum = ch:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function() hum.Health = 0 end)
                print("[auto-reset] reset attempted")
            end
        end)
    end)

    spawn(function() task.wait(2.5); print("[auto-run] fetching & running second script:", SECOND_URL); fetchAndRun(SECOND_URL, "second-remote") end)

    print("[auto-run] UI and auto-clicker functionality have been removed from this script. Reset restored.")
end)

local savedPreview = loadPointsFromFile()
local savedCount = savedPreview and savedPreview.points and #savedPreview.points or 0
print(("[Crime AutoFarm] started (UI/clicker removed; reset restored). FIRST=%s SECOND=%s saved_points=%d"):format(tostring(FIRST_URL), tostring(SECOND_URL), savedCount))