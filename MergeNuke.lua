local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local LP = game:GetService("Players").LocalPlayer
local Work = game:GetService("Workspace")
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("NukeRemotes")

local PickUp = Remotes:WaitForChild("PickUp")
local Merge = Remotes:WaitForChild("MergeRequest")
local Lock = Remotes:WaitForChild("RequestLockBase")
local Upgrade = Remotes:WaitForChild("PurchaseUpgrade")
local RedeemCode = Remotes:WaitForChild("RedeemCode")

local Flags = { Merge = false, Lock = false, Upgrade = false }
local Selected = {}
local Cache = nil

local function gradTxt(txt, c1, c2)
    local res = ""
    local chars = {}
    for uchar in txt:gmatch("[%z\1-\127\194-\244][\128-\191]*") do table.insert(chars, uchar) end
    local len = #chars
    for i = 1, len do
        local t = (i - 1) / math.max(len - 1, 1)
        local r = c1.R + (c2.R - c1.R) * t
        local g = c1.G + (c2.G - c1.G) * t
        local b = c1.B + (c2.B - c1.B) * t
        res = res .. string.format('<font color="rgb(%d,%d,%d)">%s</font>', math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), chars[i])
    end
    return res
end

local W = WindUI:CreateWindow({
    Title = gradTxt("Mikkado Hub", Color3.fromHex("#FFFFFF"), Color3.fromHex("#000000")),
    Folder = "ByCcat",
    AutoSize = true,
    Resizable = false,
    Transparent = false,
    Background = "https://raw.githubusercontent.com/lIllIIlII/Secular/refs/heads/main/1782475290965.png",
    Theme = "Dark",
    SideBarWidth = 140,
    HideSearchBar = true,
    OpenButton = {
        Title = gradTxt("Mikkado", Color3.fromHex("#FFFFFF"), Color3.fromHex("#000000")),
        CornerRadius = UDim.new(0.3, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 1,
        Color = ColorSequence.new(Color3.fromHex("#FFFFFF"), Color3.fromHex("#000000"))
    }
})

W:Tag({ Title = "Nuke Hack", Color = Color3.fromHex("#ffaa00"), Radius = 2 })

local T1 = W:Tab({ Title = "主要", Opened = true })

T1:Toggle({
    Title = "自动合成",
    Default = false,
    Callback = function(v) Flags.Merge = v end
})

T1:Toggle({
    Title = "自动锁(当有人疑似攻击你时)",
    Default = false,
    Callback = function(v) Flags.Lock = v end
})

T1:Divider()

T1:Dropdown({
    Title = "选择",
    Values = {"MAX", "TIER", "LOCKBASE"},
    Value = {},
    Multi = true,
    Callback = function(v) Selected = v end
})

T1:Toggle({
    Title = "自动买",
    Default = false,
    Callback = function(v) Flags.Upgrade = v end
})

T1:Button({
    Title = "一键兑换兑换码",
    Callback = function()
        local codes = {"BOOM", "UPDATE", "UPDATE2", "ATOMIC", "ADMIN", "update"}
        for _, code in ipairs(codes) do
            RedeemCode:InvokeServer(code)
            task.wait(0.35)
        end
    end
})

local function getFolder()
    if Cache and Cache.Parent then return Cache end
    local B = Work:FindFirstChild("Bases")
    if not B then return end
    for _, b in ipairs(B:GetChildren()) do
        local N = b:FindFirstChild("Nukes")
        if N then
            for _, n in ipairs(N:GetChildren()) do
                if n:GetAttribute("OwnerUserId") == LP.UserId then
                    Cache = N
                    return N
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        if Flags.Merge then
            local f = getFolder()
            if f then
                local c = f:GetChildren()
                for i = 1, #c do
                    local v = c[i]
                    if v:IsA("BasePart") and v:GetAttribute("State") ~= "flying" then
                        local t = v:GetAttribute("Tier")
                        if t then
                            for j = i + 1, #c do
                                local p = c[j]
                                if p:IsA("BasePart") and p:GetAttribute("State") ~= "flying" and p:GetAttribute("Tier") == t then
                                    PickUp:FireServer(v)
                                    task.wait()
                                    if v.Parent == f and p.Parent == f then
                                        Merge:FireServer(p)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

local function isUnderAttack()
    local bases = Work:FindFirstChild("Bases")
    if not bases then return false end

    for _, base in ipairs(bases:GetChildren()) do
        local id = base:GetAttribute("OwnerUserId")
        if id and tonumber(id) ~= tonumber(LP.UserId) then
            local nukes = base:FindFirstChild("Nukes")
            if nukes then
                for _, nuke in ipairs(nukes:GetChildren()) do
                    if nuke.Name == "Nuke" then
                        local state = nuke:GetAttribute("State")
                        if state == "held" or not nuke:IsDescendantOf(base) then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    for _, obj in ipairs(Work:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name:lower():match("nuke") and not obj:IsDescendantOf(bases) then
            return true
        end
    end
    
    return false
end

task.spawn(function()
    while true do
        if Flags.Lock and isUnderAttack() then
            Lock:FireServer()
            task.wait(0.2)
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while true do
        if Flags.Upgrade then
            for i = 1, #Selected do
                if not Flags.Upgrade then break end
                local item = Selected[i]
                if item then
                    Upgrade:FireServer(item)
                end
            end
        end
        task.wait(0.5)
    end
end)