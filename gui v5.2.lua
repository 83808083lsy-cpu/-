local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "内测版v7.6",
    LoadingTitle = "欢迎使用",
    LoadingSubtitle = "嘿！",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "公测版v7.6配置文件",
        FileName = "AAAAAA"
    },
})

-- 第一个功能区
local FunctionTab1 = Window:CreateTab("犯罪脚本", 4483362458)
FunctionTab1:CreateButton({
    Name = "cat.gg",
    Callback = function()
        loadstring(game:HttpGet("https://pastefy.app/DcSKb72e/raw"))()
    end,
})

FunctionTab1:CreateButton({
    Name = "femboyshub",
    Callback = function()
        writefile("Rayfield/Key System/Key123.rfld","NoHomo");
        loadstring(game:HttpGet("https://raw.githubusercontent.com/LisSploit/FemboysHubBoosr/2784d6c4ede4340ad9af4865828d915ffc26c7bb/Criminality"))()
    end,
})

FunctionTab1:CreateButton({
    Name = "盗版犯罪甩飞",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/83808083lsy-cpu/-/refs/heads/main/message%20(3)%20(1)%20(1).txt"))()
    end,
})

FunctionTab1:CreateButton({
    Name = "JX-Loader",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/jianlobiano/LOADER/refs/heads/main/JX-Loader"))()
    end,
})

-- 黑火药脚本功能区
local FunctionTab2 = Window:CreateTab("黑火药脚本")
FunctionTab2:CreateButton({
    Name = "皮黑火药",
    Callback = function()
        loadstring(game:HttpGet("\104\116\116\112\115\58\47\47\114\97\119\46\103\105\116\104\117\98\117\115\101\114\99\111\110\116\101\110\116\46\99\111\109\47\120\105\97\111\112\105\55\55\47\120\105\97\111\112\105\55\55\47\114\101\102\115\47\104\101\97\100\115\47\109\97\105\110\47\82\111\98\108\111\120\45\80\105\45\71\66\45\83\99\114\105\112\116\46\108\117\97"))()
    end,
})
FunctionTab2:CreateButton({
    Name = "清风黑火药",
    Callback = function()
        loadstring(game:HttpGet("https://pastebin.com/raw/wbY3hYF1"))()
    end,
})

-- 通用脚本功能区
local FunctionTab3 = Window:CreateTab("通用脚本")
FunctionTab3:CreateButton({
    Name = "VapeV4通用",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua", true))()
    end,
})
FunctionTab3:CreateButton({
    Name = "XAHUB",
    Callback = function()
        loadstring(game:HttpGet("https://raw.gitcode.com/Xingtaiduan/Scripts/raw/main/Loader.lua"))()
    end,
})

-- 娱乐脚本功能区
local FunctionTab4 = Window:CreateTab("娱乐脚本")
FunctionTab4:CreateButton({
    Name = "Egor",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Roblox-Egor-Script-50669"))()
    end,
})

-- 新增功能区：MaxHub 加载器
local FunctionTab5 = Window:CreateTab("MaxHub脚本")
FunctionTab5:CreateButton({
    Name = "MaxHub",
    Callback = function()
        -- 设置脚本密钥（可根据需要修改）
        script_key = "QuDnnUGUqiBjOFZASOYtZPWhcsCKRieB"

        -- MaxHub 配置
        _G.MaxHub = {
            ['Maxhub Notifications'] = true -- (Maxhub Shows number of executions, scriptname)
        }

        -- 加载远程 loader
        loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/993b07de445441e83e15ce5fde260d5f.lua"))()
    end,
})

-- 新增功能区：暴力区（根据 暴力区.txt 中的脚本按名字添加）
local FunctionTabViolence = Window:CreateTab("暴力区")
FunctionTabViolence:CreateButton({
    Name = "freev1",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Violence-District-OP-FEATURES-KEYLESS-52037"))()
    end,
})
FunctionTabViolence:CreateButton({
    Name = "freev2",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/UPDATE-Violence-District-Vgxmod-X-Violence-District-49225"))()
    end,
})
FunctionTabViolence:CreateButton({
    Name = "freev3",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/UPDATE-Violence-District-Legit-script-55506"))()
    end,
})
FunctionTabViolence:CreateButton({
    Name = "key系统",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Violence-District-Auto-Repair-Generators-Auto-Kill-Players-Auto-Carry-ESP-OP-50093"))()
    end,
})
FunctionTabViolence:CreateButton({
    Name = "key系统",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Violence-District-Distruct-Violence-Esp-Kill-all-49648"))()
    end,
})

-- 新增功能区：最后的黎明脚本（你要求添加的脚本）
local FunctionTabLastDawn = Window:CreateTab("最后的黎明脚本")
FunctionTabLastDawn:CreateButton({
    Name = "最后的黎明脚本",
    Callback = function()
        loadstring(game:HttpGet("https://atlasteam.live/LastDawn"))()
    end,
})

-- 你可以在这里继续添加更多功能区或按钮
