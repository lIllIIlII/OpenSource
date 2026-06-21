--[[Open Source
 __  __                    /\/|___           ____         _
|  \/  | ___  _____      _|/\/  |_ _|_ __ ___  / ___|___ __ _| |_ 
| | \/| |/ _ \/ _ \ \ /\ / /     | || '_ ` _ \  | |   / __/ _` | __|
| |   | |  __/ (_) \ V  V /     | || | | | | | | |__| (_| (_| | |_ 
|_|   |_|\___|\___/ \_/\_/       |___|_| |_| |_|  \____\___\__,_|\__|
Im Ccat:)]]
local PS = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunSvc = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CollSvc = game:GetService("CollectionService")
local WS = game:GetService("Workspace")
local LP = PS.LocalPlayer
local HS = game:GetService("HttpService")

local Net = (function() local ok, m = pcall(function() return require(RS.SharedModules.Networking) end) return ok and m or nil end)()
local PSC = (function() local ok, m = pcall(function() return require(RS.ClientModules.PlayerStateClient) end) return ok and m or nil end)()
if not Net then return end

local SeedData = (function() local ok, d = pcall(function() return require(RS.SharedModules.SeedData) end) return ok and d or {} end)()
local SCost = {}
for _, e in ipairs(SeedData) do
    if type(e) == "table" and e.SeedName then SCost[e.SeedName] = tonumber(e.PurchasePrice) or math.huge end
end
local FCalc = (function() local ok, m = pcall(function() return require(RS.SharedModules.FruitValueCalc) end) return (ok and type(m) == "function") and m or nil end)()
local SVal = {}
if FCalc then
    for _, e in ipairs(SeedData) do
        if type(e) == "table" and e.SeedName then
            local ok, v = pcall(FCalc, e.SeedName, 1, nil, LP, nil)
            SVal[e.SeedName] = (ok and type(v) == "number") and v or 0
        end
    end
end
local MB = 2.35
local SE = 2.65
local function szMul(s) s = tonumber(s) or 1 return s ^ SE end
local PetDt = (function() local ok, m = pcall(function() return require(RS.SharedData.PetData) end) return ok and m or {} end)()
local function animalOpts()
    local l = {}
    for k, v in pairs(PetDt) do if type(v) == "table" and type(k) == "string" then l[#l + 1] = k end end
    table.sort(l); return l
end

local Hub = { on = true, cn = {} }
local genv = (getgenv and getgenv()) or _G
if genv.Ccat_unload then pcall(genv.Ccat_unload) end
local function tk(c) table.insert(Hub.cn, c); return c end
local function lp(iv, fn)
    task.spawn(function()
        while Hub.on do
            task.wait(iv)
            if not Hub.on then break end
            pcall(fn)
        end
    end)
end

local S = {
    abSeed = false, bSeeds = {},
    aPlant = false, pSeeds = {}, pRes = 0, mxCyc = 40, pDly = 0.14, pLoop = 1.2, smtRp = false, aExp = false,
    pPat = "填充", pSrc = "我的种子", aBld = false, rmCrops = {},
    aColl = false, hCrops = {}, hMuts = false, fDly = 0.05, hLoop = 1,
    aSell = false, sInt = 20, sFull = false,
    aSteal = false, sRet = true, sMul = 1,
    pHarv = false, retl = false,
    aGrab = false, gRare = true, pRet = true, nRare = true,
    abGear = false, bGears = {}, abCrate = false,
    aEgg = false, aCrate = false, aPack = false,
    aTame = false, tAnim = {}, aEquip = false, ePets = {},
    wSpd = 16, jPow = 50, iJump = false, nclip = false, fly = false, fSpd = 60,
    aAfk = true, opt = false, aProg = false,
    hlRdy = false, hlRare = false, rNtfy = false,
    aHop = false,
}

local SF = "GAG2·Ccat.json"
local function sv()
    if not writefile then return end
    pcall(function() writefile(SF, HS:JSONEncode(S)) end)
end
local function ld()
    if not (readfile and isfile) then return end
    local ok, raw = pcall(function() return isfile(SF) and readfile(SF) or nil end)
    if not (ok and raw) then return end
    local good, data = pcall(function() return HS:JSONDecode(raw) end)
    if not (good and type(data) == "table") then return end
    for k, v in pairs(data) do
        if S[k] ~= nil then
            if type(S[k]) == "table" and type(v) == "table" then
                table.clear(S[k]); for kk, vv in pairs(v) do S[k][kk] = vv end
            elseif type(S[k]) == type(v) then
                S[k] = v
            end
        end
    end
end
ld()

local function getRplc() if not PSC then return nil end local ok, r = pcall(function() return PSC:GetLocalReplica() end) return ok and r or nil end
local function getData() local r = getRplc() return r and r.Data or nil end
local function getShk() local d = getData() return d and d.Sheckles or 0 end
local function myPlot()
    local g = WS:FindFirstChild("Gardens"); if not g then return nil end
    for _, p in ipairs(g:GetChildren()) do if p:GetAttribute("OwnerUserId") == LP.UserId then return p end end
end
local function isNight() local n = RS:FindFirstChild("Night") return n and n.Value == true end
local function chr() return LP.Character end
local function hrp() local c = chr() return c and c:FindFirstChild("HumanoidRootPart") end
local function hmd() local c = chr() return c and c:FindFirstChildOfClass("Humanoid") end
local function fire(pkt, ...) local a = {...} return pcall(function() return pkt:Fire(table.unpack(a)) end) end

local function setColl(on)
    local c = chr(); if not c then return end
    for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide = on end) end end
end
local HOP = 70
local function reach(pos)
    local r = hrp(); if not (r and pos) then return end
    local tgt = pos + Vector3.new(0, 3, 0)
    setColl(false)
    for _ = 1, 60 do
        local cur = r.Position; local dt = tgt - cur
        if dt.Magnitude <= HOP then r.CFrame = CFrame.new(tgt); break end
        r.CFrame = CFrame.new(cur + dt.Unit * HOP); RunSvc.Heartbeat:Wait()
    end
    if not S.nclip then setColl(true) end
end
local function fVal(m)
    local base = SVal[m:GetAttribute("CorePartName") or m:GetAttribute("SeedName")] or 0
    return base * szMul(m:GetAttribute("SizeMulti") or 1) * (m:GetAttribute("Mutation") and MB or 1)
end
local function ripe(m)
    local age = tonumber(m:GetAttribute("Age")); local mx = tonumber(m:GetAttribute("MaxAge"))
    if age and mx then return age >= mx - 0.001 end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("ProximityPrompt") and CollSvc:HasTag(d, "HarvestPrompt") then return true end
    end
    return false
end
local function ownTargets(filt)
    local useCrop = filt and next(S.hCrops) ~= nil
    local out = {}
    local plot = myPlot(); if not plot then return out end
    local plants = plot:FindFirstChild("Plants"); if not plants then return out end
    local function consider(m)
        if not m:GetAttribute("PlantId") then return end
        local crop = m:GetAttribute("CorePartName") or m:GetAttribute("SeedName")
        local mutOk = (not filt) or (not S.hMuts) or (m:GetAttribute("Mutation") ~= nil)
        if ((not useCrop) or (crop and S.hCrops[crop] == true)) and mutOk then out[#out + 1] = m end
    end
    for _, plant in ipairs(plants:GetChildren()) do
        local fr = plant:FindFirstChild("Fruits")
        local fruits = fr and fr:GetChildren() or {}
        if #fruits > 0 then
            for _, m in ipairs(fruits) do if ripe(m) then consider(m) end end
        elseif ripe(plant) then
            consider(plant)
        end
    end
    return out
end
local function stealTgts()
    local out = {}
    for _, p in ipairs(CollSvc:GetTagged("StealPrompt")) do
        local m = p.Parent and p.Parent:FindFirstAncestorWhichIsA("Model")
        if m then
            local uid = tonumber(m:GetAttribute("UserId"))
            if uid and uid ~= LP.UserId and m:GetAttribute("PlantId") then out[#out + 1] = { m = m, v = fVal(m) } end
        end
    end
    table.sort(out, function(a, b) return a.v > b.v end)
    return out
end
local function harvestAll(filt)
    local plot = myPlot(); local ref = plot and plot:FindFirstChild("PlotSizeReference"); local r = hrp()
    if ref and r and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(ref.Position.X, 0, ref.Position.Z)).Magnitude > 16 then
        reach(ref.Position); task.wait(0.12)
    end
    local t = ownTargets(filt); local n = 0
    for _, m in ipairs(t) do
        local pid = m:GetAttribute("PlantId")
        if pid then fire(Net.Garden.CollectFruit, pid, m:GetAttribute("FruitId") or ""); n = n + 1; task.wait(S.fDly) end
    end
    return n
end
local function stealModel(m, mult, skip)
    if not m or not m.Parent then return end
    local uid = tonumber(m:GetAttribute("UserId")); local pid = m:GetAttribute("PlantId")
    if not (uid and pid) then return end
    if not skip then reach(m:GetPivot().Position); task.wait(0.05) end
    fire(Net.Steal.BeginSteal, uid, pid, m:GetAttribute("FruitId") or "")
    for _ = 1, math.max(1, mult or 1) do fire(Net.Steal.CompleteSteal) end
end

local function stockIt(shop)
    local sv = RS:FindFirstChild("StockValues"); sv = sv and sv:FindFirstChild(shop)
    return sv and sv:FindFirstChild("Items")
end
local function seedStock() return stockIt("SeedShop") end
local function gearStock() return stockIt("GearShop") end
local function gearOpts()
    local it = gearStock(); local l = {}
    if it then for _, sv in ipairs(it:GetChildren()) do l[#l + 1] = sv.Name end end
    table.sort(l); return l
end
local function seedOpts()
    local seen = {}
    for _, e in ipairs(SeedData) do if e.SeedName then seen[e.SeedName] = tonumber(e.SeedShopDisplayOrder) or 900 end end
    local it = seedStock(); if it then for _, sv in ipairs(it:GetChildren()) do if seen[sv.Name] == nil then seen[sv.Name] = 899 end end end
    local l = {} for name, ord in pairs(seen) do l[#l + 1] = { name, ord } end
    table.sort(l, function(a, b) if a[2] == b[2] then return a[1] < b[1] end return a[2] < b[2] end)
    local names = {} for _, x in ipairs(l) do names[#names + 1] = x[1] end
    return names
end
local function ownedSeedOpts()
    local d = getData(); local order = {}
    for _, e in ipairs(SeedData) do if e.SeedName then order[e.SeedName] = tonumber(e.SeedShopDisplayOrder) or 900 end end
    local l = {}
    if d and d.Inventory and d.Inventory.Seeds then
        for n, c in pairs(d.Inventory.Seeds) do if (c or 0) > 0 then l[#l + 1] = n end end
    end
    table.sort(l, function(a, b) local oa, ob = order[a] or 900, order[b] or 900 if oa == ob then return a < b end return oa < ob end)
    return l
end
local function plantedOpts()
    local plot = myPlot(); local seen = {}
    if plot then local plants = plot:FindFirstChild("Plants")
        if plants then for _, pl in ipairs(plants:GetChildren()) do local s = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName") if s then seen[s] = true end end end
    end
    local l = {} for k in pairs(seen) do l[#l + 1] = k end table.sort(l); return l
end
local function harvestOpts()
    local seen = {}
    local plot = myPlot()
    if plot then local plants = plot:FindFirstChild("Plants") if plants then for _, pl in ipairs(plants:GetChildren()) do local s = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName") if s then seen[s] = true end end end end
    local d = getData(); if d and d.Inventory and d.Inventory.Seeds then for n in pairs(d.Inventory.Seeds) do seen[n] = true end end
    local l = {} for k in pairs(seen) do l[#l + 1] = k end table.sort(l); return l
end
local function petOpts()
    local d = getData(); local seen = {}
    if d and d.Inventory and d.Inventory.Pets then
        for _, info in pairs(d.Inventory.Pets) do local nm = (type(info) == "table" and (info.PetType or info.Name)) or tostring(info) if nm and nm ~= "" then seen[nm] = true end end
    end
    local l = {} for k in pairs(seen) do l[#l + 1] = k end table.sort(l); return l
end
local function maxEq() return tonumber(LP:GetAttribute("MaxEquippedPets")) or 3 end

local function bestSeed()
    local d = getData(); local seeds = d and d.Inventory and d.Inventory.Seeds; if not seeds then return nil end
    local best, bv
    for name, count in pairs(seeds) do
        if (count or 0) > 0 then local v = SVal[name] or 0 if not bv or v > bv then best, bv = name, v end end
    end
    return best, bv
end
local function invVal()
    local total, n = 0, 0
    local function scan(c) if not c then return end for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and (t:GetAttribute("HarvestedFruit") or t:GetAttribute("Fruit")) then
            n = n + 1
            local base = SVal[t:GetAttribute("Fruit") or t:GetAttribute("CorePartName")] or 0
            total = total + base * szMul(t:GetAttribute("SizeMultiplier") or t:GetAttribute("SizeMulti") or 1) * (t:GetAttribute("Mutation") and MB or 1)
        end
    end end
    scan(LP:FindFirstChild("Backpack")); scan(chr())
    return total, n
end

local EVN = { Moon = "月光", Bloodmoon = "血月", Goldmoon = "金月",
    ["Rainbow Moon"] = "彩虹月", ["Chained Moon"] = "锁链月", ["Pizza Moon"] = "披萨月", Sunset = "日落", Day = "白天" }
local EVC = {
    Day = Color3.fromRGB(255, 214, 90), Sunset = Color3.fromRGB(255, 150, 90), Moon = Color3.fromRGB(190, 150, 255),
    Bloodmoon = Color3.fromRGB(176, 32, 32), Goldmoon = Color3.fromRGB(255, 205, 70), ["Rainbow Moon"] = Color3.fromRGB(255, 120, 200),
    ["Chained Moon"] = Color3.fromRGB(150, 150, 162), ["Pizza Moon"] = Color3.fromRGB(232, 120, 60) }
local function evClr(r) return EVC[r] or Color3.fromRGB(225, 225, 230) end
local function evNm(r) return EVN[r] or tostring(r or "-") end
local function curEv() return workspace:GetAttribute("ActiveWeather"), workspace:GetAttribute("ActivePhase"), tonumber(workspace:GetAttribute("PhaseDuration")) end
local function fmtClk(s) s = math.max(0, math.floor(s or 0)) return string.format("%d:%02d", s // 60, s % 60) end
local function restockIn(shop)
    local sv = RS:FindFirstChild("StockValues"); sv = sv and sv:FindFirstChild(shop)
    local nx = sv and sv:FindFirstChild("UnixNextRestock")
    return nx and math.max(0, nx.Value - os.time()) or nil
end

local CC = { accent = Color3.fromRGB(196, 30, 58), green = Color3.fromRGB(80, 220, 130) }
local function commafy(n)
    local neg = n < 0; local s = tostring(math.floor(math.abs(n) + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (neg and "-" or "") .. out
end
local function money(n) return "$" .. commafy(n) end
local function fmtPrc(n)
    n = tonumber(n); if not n or n <= 0 or n == math.huge then return "" end
    local s
    if n >= 1e9 then s = string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then s = string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then s = string.format("%.0fK", n / 1e3)
    else s = commafy(n) end
    s = s:gsub("%.0(%a)", "%1")
    return s .. "\xc2\xa2"
end

local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Lib = loadstring(game:HttpGet(repo .. "Library.lua"))()

Lib:SetWatermark("GAG2·Ccat")

local Win = Lib:CreateWindow({
    Title = "Meow·GAG2",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local StatusLabel
local function setStatus(t) if StatusLabel then StatusLabel:SetText(tostring(t)) end end
local function notify(t, title, col)
    Lib:Notify({ Title = title or "Ccat", Text = t, Time = 5 })
    pcall(function() Net.Notification:Fire("Ccat", t) end)
end

local PAT = { "填充", "棋盘", "行", "列", "对角", "间隔" }
local function patKeep(pat, gx, gz)
    if pat == "棋盘" then return (gx + gz) % 2 == 0
    elseif pat == "行" then return gz % 2 == 0
    elseif pat == "列" then return gx % 2 == 0
    elseif pat == "对角" then return (gx - gz) % 3 == 0
    elseif pat == "间隔" then return gx % 2 == 0 and gz % 2 == 0 end
    return true
end
local function plantAreas(plot)
    local areas = {}
    for _, p in ipairs(CollSvc:GetTagged("PlantArea")) do
        if p:IsA("BasePart") and p:IsDescendantOf(plot) and p.Size.X * p.Size.Z > 400 then areas[#areas + 1] = p end
    end
    if #areas == 0 then local ref = plot:FindFirstChild("PlotSizeReference"); if ref then areas = { ref } end end
    return areas
end
local function plantPos(plot)
    local pat = S.pPat or "填充"
    local step = 6
    local seen, list = {}, {}
    for _, area in ipairs(plantAreas(plot)) do
        local cf, sz = area.CFrame, area.Size
        local topY = area.Position.Y + sz.Y / 2 + 0.3
        local hx, hz = sz.X / 2 - 3, sz.Z / 2 - 3
        local nx, nz = math.floor((2 * hx) / step), math.floor((2 * hz) / step)
        for ix = 0, nx do for iz = 0, nz do
            local w = (cf * CFrame.new(-hx + ix * step, 0, -hz + iz * step)).Position
            local gx, gz = math.floor(w.X / step + 0.5), math.floor(w.Z / step + 0.5)
            if patKeep(pat, gx, gz) then
                local key = math.floor(w.X / 4 + 0.5) .. "," .. math.floor(w.Z / 4 + 0.5)
                if not seen[key] then seen[key] = true; list[#list + 1] = Vector3.new(w.X, topY, w.Z) end
            end
        end end
    end
    return list
end
local function freePos(plot)
    local grid = plantPos(plot); local plants = plot:FindFirstChild("Plants"); local occ = {}
    if plants then for _, pl in ipairs(plants:GetChildren()) do local ok, pv = pcall(function() return pl:GetPivot().Position end) if ok then occ[#occ + 1] = pv end end end
    local free = {}
    for _, pos in ipairs(grid) do
        local clear = true
        for _, o in ipairs(occ) do if (Vector3.new(o.X, 0, o.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 6 then clear = false break end end
        if clear then free[#free + 1] = pos end
    end
    return free
end

local SNF = "Ccat_GAG2_Snap.json"
local Snaps = {}
local function svSnaps() if writefile then pcall(function() writefile(SNF, HS:JSONEncode(Snaps)) end) end end
do
    if readfile and isfile then
        local ok, raw = pcall(function() return isfile(SNF) and readfile(SNF) or nil end)
        if ok and raw then local g, d = pcall(function() return HS:JSONDecode(raw) end) if g and type(d) == "table" then Snaps = d end end
    end
end
local function snapNames()
    local l = {} for n in pairs(Snaps) do l[#l + 1] = n end table.sort(l); return l
end
local function nearGarden()
    local g = WS:FindFirstChild("Gardens"); local r = hrp(); if not (g and r) then return nil end
    local best, bestD
    for _, plot in ipairs(g:GetChildren()) do
        local ref = plot:FindFirstChild("PlotSizeReference")
        if ref then local d = (Vector3.new(ref.Position.X, 0, ref.Position.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude
            if not bestD or d < bestD then best, bestD = plot, d end end
    end
    return best
end
local BF = { "Props", "Sprinklers", "Gnomes", "PottedPlants", "Pots", "Objects", "Decor" }
local function captureSnap(name)
    local plot = nearGarden(); if not plot then return false, "附近没有花园" end
    local ref = plot:FindFirstChild("PlotSizeReference"); local center = ref and ref.Position or Vector3.zero
    local snap = { seeds = {}, buildings = {}, owner = plot:GetAttribute("OwnerUserId") }
    local plants = plot:FindFirstChild("Plants")
    if plants then for _, pl in ipairs(plants:GetChildren()) do
        local s = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
        if s then snap.seeds[s] = (snap.seeds[s] or 0) + 1 end
    end end
    for _, fname in ipairs(BF) do
        local f = plot:FindFirstChild(fname)
        if f then for _, b in ipairs(f:GetChildren()) do
            local ok, piv = pcall(function() return b:GetPivot().Position end)
            if ok then
                local kind = b:GetAttribute("PropName") or b:GetAttribute("ItemName") or b:GetAttribute("Name") or b:GetAttribute("Type") or b.Name
                snap.buildings[#snap.buildings + 1] = { kind = tostring(kind), folder = fname,
                    rx = piv.X - center.X, ry = piv.Y - center.Y, rz = piv.Z - center.Z,
                    rot = (select(2, (b:GetPivot()):ToOrientation()) or 0) }
            end
        end end
    end
    Snaps[name] = snap; svSnaps()
    local nS = 0 for _ in pairs(snap.seeds) do nS = nS + 1 end
    return true, ("捕获 %d 种种子, %d 个建筑"):format(nS, #snap.buildings)
end

local function findShovel()
    local function scan(c) if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and (t:GetAttribute("Shovel") ~= nil or t.Name:lower():find("shovel")) then return t end end end end
    return scan(chr()) or scan(LP:FindFirstChild("Backpack"))
end
local function eqShovel()
    local sh = findShovel(); if not sh then return nil end
    local h = hmd()
    if h and sh.Parent ~= chr() then pcall(function() h:EquipTool(sh) end); task.wait(0.3) end
    return sh
end
local function rmPlants(matchFn)
    local plot = myPlot(); if not plot then return 0 end
    local plants = plot:FindFirstChild("Plants"); if not plants then return 0 end
    local sh = eqShovel(); if not sh then setStatus("请先装备铲子"); return 0 end
    local sa = sh:GetAttribute("Shovel"); local n = 0; local lastPos
    for _, pl in ipairs(plants:GetChildren()) do
        local pid = pl:GetAttribute("PlantId")
        local crop = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
        if pid and ((not matchFn) or matchFn(crop)) then
            local ok, pos = pcall(function() return pl:GetPivot().Position end)
            if ok and (not lastPos or (pos - lastPos).Magnitude > 10) then reach(pos); lastPos = pos end
            pcall(function() Net.Shovel.UseShovel:Fire(pid, "", sa, sh) end)
            n = n + 1; task.wait(0.05)
        end
    end
    return n
end
local function rmAllPlants() return rmPlants(nil) end
local function rmSelPlants() return rmPlants(function(c) return c and S.rmCrops[c] == true end) end
local function rmAllBld()
    local plot = myPlot(); if not plot then return 0 end
    local n = 0
    for _, fname in ipairs(BF) do
        local f = plot:FindFirstChild(fname)
        if f then for _, b in ipairs(f:GetChildren()) do
            pcall(function()
                if Net.Prop and Net.Prop.PickupProp then Net.Prop.PickupProp:Fire(b) end
                if Net.PotPlacement and Net.PotPlacement.PickUpPottedPlant then Net.PotPlacement.PickUpPottedPlant:Fire(b) end
                if fname == "Gnomes" and Net.Place and Net.Place.RemoveGnome then Net.Place.RemoveGnome:Fire(b) end
            end)
            n = n + 1; task.wait(0.06)
        end end
    end
    return n
end

lp(2, function()
    if not S.abSeed then return end
    local it = seedStock(); if not it then return end
    local anySel = next(S.bSeeds) ~= nil
    for _, sv in ipairs(it:GetChildren()) do
        if sv:IsA("ValueBase") and sv.Value > 0 and ((not anySel) or S.bSeeds[sv.Name] == true) then
            if getShk() >= (SCost[sv.Name] or 0) then fire(Net.SeedShop.PurchaseSeed, sv.Name); task.wait(0.08) end
        end
    end
end)

lp(0.6, function()
    if not S.aPlant then return end
    task.wait(math.max(0, S.pLoop - 0.6))
    if not S.aPlant then return end
    local plot = myPlot(); if not plot then return end
    local d = getData(); local seeds = d and d.Inventory and d.Inventory.Seeds; if not seeds then return end
    local useF = next(S.pSeeds) ~= nil
    local tp = {}
    local snap = (S.pSrc and S.pSrc ~= "我的种子") and Snaps[S.pSrc] or nil
    if snap then
        local have = {}
        local plf = plot:FindFirstChild("Plants")
        if plf then for _, pl in ipairs(plf:GetChildren()) do local s = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName") if s then have[s] = (have[s] or 0) + 1 end end end
        for seed, target in pairs(snap.seeds) do
            local need = math.min((target or 0) - (have[seed] or 0), seeds[seed] or 0)
            for _ = 1, math.max(0, need) do tp[#tp + 1] = seed end
        end
    elseif S.smtRp then
        local best = bestSeed()
        if best and ((not useF) or S.pSeeds[best]) then
            local keep = S.pRes or 0
            for _ = 1, math.min(math.max(0, (seeds[best] or 0) - keep), 80) do tp[#tp + 1] = best end
        end
    else
        for name, count in pairs(seeds) do
            if (not useF) or S.pSeeds[name] == true then
                local keep = S.pRes or 0
                for _ = 1, math.min(math.max(0, (count or 0) - keep), 40) do tp[#tp + 1] = name end
            end
        end
    end
    if #tp == 0 then return end
    local free = freePos(plot); if #free == 0 then return end
    local cap = math.min(#free, #tp, S.mxCyc); local planted = 0
    for i = 1, cap do
        fire(Net.Plant.PlantSeed, free[i], tp[i], plot); planted = planted + 1; task.wait(S.pDly)
    end
    if planted > 0 then setStatus("已种植 " .. planted) end
end)

lp(6, function()
    if not S.aExp then return end
    local plot = myPlot(); if not plot then return end
    local before = tonumber(plot:GetAttribute("GardenExpansion")) or 0
    fire(Net.Actions.ExpandGarden)
    task.wait(1)
    local after = tonumber(plot:GetAttribute("GardenExpansion")) or before
    if after > before then setStatus("花园已扩建至 " .. after .. " 级") end
end)

local function buildSnap()
    local snap = (S.pSrc and S.pSrc ~= "我的种子") and Snaps[S.pSrc] or nil
    if not (snap and snap.buildings and #snap.buildings > 0) then setStatus("请选择包含建筑的快照作为来源") return 0 end
    local plot = myPlot(); if not plot then return 0 end
    local ref = plot:FindFirstChild("PlotSizeReference"); local center = ref and ref.Position or Vector3.zero
    local n = 0
    for _, b in ipairs(snap.buildings) do
        local pos = Vector3.new(center.X + (b.rx or 0), center.Y + (b.ry or 0), center.Z + (b.rz or 0))
        pcall(function() if Net.Prop and Net.Prop.PlaceProp then Net.Prop.PlaceProp:Fire(pos, b.kind, b.rot or 0, b.rot or 0) end end)
        n = n + 1; task.wait(0.15)
    end
    setStatus("自动建造: 尝试了 " .. n .. " 个建筑")
    return n
end
lp(8, function()
    if not S.aBld then return end
    local snap = (S.pSrc and S.pSrc ~= "我的种子") and Snaps[S.pSrc] or nil
    if not (snap and snap.buildings and #snap.buildings > 0) then return end
    local plot = myPlot(); if not plot then return end
    local built = 0
    for _, fname in ipairs(BF) do local f = plot:FindFirstChild(fname) if f then built = built + #f:GetChildren() end end
    if built < #snap.buildings then buildSnap() end
end)

lp(0.4, function()
    if not S.aColl then return end
    task.wait(math.max(0, S.hLoop - 0.4))
    if not S.aColl then return end
    local n = harvestAll(true)
    if n > 0 then setStatus("已收获 " .. n) end
end)

lp(1, function()
    if S.sFull then
        local fc = LP:GetAttribute("FruitCount") or 0
        local mx = LP:GetAttribute("MaxFruitCapacity") or 100
        if fc >= mx - 1 then fire(Net.NPCS.SellAll); setStatus("已出售(背包已满)") end
    end
end)
do
    local acc = 0
    lp(1, function() acc = acc + 1 if S.aSell and acc >= S.sInt then acc = 0 fire(Net.NPCS.SellAll) end end)
end

lp(0.8, function()
    if not S.aSteal then return end
    if not isNight() then setStatus("偷取: 等待夜晚") return end
    local home = hrp() and hrp().Position
    local t = stealTgts(); local n = 0; local lastPos
    for _, e in ipairs(t) do
        if not S.aSteal or not isNight() then break end
        local m = e.m; local pos = (m and m.Parent) and m:GetPivot().Position or nil
        local skip = (lastPos and pos and (pos - lastPos).Magnitude <= 12) or false
        if pos and not skip then lastPos = pos end
        stealModel(m, S.sMul, skip); n = n + 1
        setStatus(string.format("偷取: %d/%d  (价值 %d)", n, #t, math.floor(e.v))); task.wait(0.03)
    end
    if n > 0 then setStatus(("本轮偷取了 %d 个果实"):format(n)) end
    if S.sRet and home then reach(home - Vector3.new(0, 3, 0)) end
end)

local function pkKind(loc)
    if loc:GetAttribute("GoldSeed") == true then return "金色种子" end
    if loc:GetAttribute("RainbowSeed") == true then return "彩虹种子" end
    if loc:GetAttribute("SeedPack") ~= nil then return tostring(loc:GetAttribute("SeedPack")) end
    return nil
end
local function isRare(loc)
    if loc:GetAttribute("GoldSeed") == true or loc:GetAttribute("RainbowSeed") == true then return true end
    local sp = loc:GetAttribute("SeedPack")
    return type(sp) == "string" and (sp:lower():find("gold") ~= nil or sp:lower():find("rainbow") ~= nil)
end
local function firePrompt(d)
    pcall(function()
        local hold = tonumber(d.HoldDuration) or 0
        if fireproximityprompt then
            if hold > 0 then fireproximityprompt(d, hold) else fireproximityprompt(d) end
        else
            d:InputHoldBegin(); task.wait(hold + 0.1); d:InputHoldEnd()
        end
    end)
end
local function packLocs()
    local map = WS:FindFirstChild("Map"); local f = map and map:FindFirstChild("SeedPackSpawnServerLocations")
    return f and f:GetChildren() or {}
end
local function holdPrompts(pos)
    local map = WS:FindFirstChild("Map")
    for _, cont in ipairs({ map and map:FindFirstChild("SeedPackSpawnServerLocations"), map and map:FindFirstChild("SeedPackSpawnClient"), WS:FindFirstChild("Temporary") }) do
        if cont then for _, d in ipairs(cont:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                local p = d.Parent; local ok, pp = pcall(function() return p.Position end)
                if (not ok) or (pp - pos).Magnitude <= 35 then firePrompt(d) end
            end
        end end
    end
end
local function locPart(loc) return loc:IsA("BasePart") and loc or loc:FindFirstChildWhichIsA("BasePart", true) end
local function locPos(loc)
    if loc:IsA("BasePart") then return loc.Position end
    local ok, cf = pcall(function() return loc:GetPivot() end); if ok then return cf.Position end
    local bp = locPart(loc); return bp and bp.Position or nil
end
local function grabPack(loc)
    local landed = false
    for _ = 1, 90 do
        if not (loc and loc.Parent) then break end
        local pos = locPos(loc); if not pos then break end
        local r = hrp()
        if (not landed) or (r and (r.Position - pos).Magnitude > 6) then reach(pos); landed = true end
        for _, d in ipairs(loc:GetDescendants()) do if d:IsA("ProximityPrompt") then firePrompt(d) end end
        holdPrompts(pos)
        local part = locPart(loc)
        if firetouchinterest and part and hrp() then pcall(function() firetouchinterest(hrp(), part, 0); firetouchinterest(hrp(), part, 1) end) end
        task.wait(0.12)
    end
end
do
    local grabbing = {}
    lp(0.6, function()
        if not S.aGrab then return end
        for _, loc in ipairs(packLocs()) do
            if loc.Parent and not grabbing[loc] then
                local rare = isRare(loc)
                if S.nRare and rare then local k = pkKind(loc) or "稀有种子"; setStatus("事件: " .. k .. " 已刷新!"); notify(k .. " 已在地图上刷新 - 正在抓取!", "稀有种子刷新", CC.accent) end
                if (not S.gRare) or rare then
                    grabbing[loc] = true
                    task.spawn(function() grabPack(loc); grabbing[loc] = nil end)
                end
            end
        end
    end)
end
do
    local wasN = false
    lp(1, function()
        local n = isNight()
        if S.pRet and S.aGrab and wasN and not n then
            local plot = myPlot(); local sp = plot and plot:FindFirstChild("SpawnPoint")
            if sp then reach(sp.Position); setStatus("活动结束 - 已返回花园") end
        end
        wasN = n
    end)
end

do
    local wasN = false
    lp(0.5, function()
        local n = isNight()
        if S.pHarv and n and not wasN then
            setStatus("防御: 紧急收获")
            harvestAll(false)
        end
        wasN = n
    end)
end
lp(0.6, function()
    if not S.retl then return end
    local plot = myPlot(); local ref = plot and plot:FindFirstChild("PlotSizeReference"); if not ref then return end
    local center, size = ref.Position, ref.Size
    for _, pl in ipairs(PS:GetPlayers()) do
        if pl ~= LP and pl.Character then
            local r = pl.Character:FindFirstChild("HumanoidRootPart")
            if r and math.abs(r.Position.X - center.X) < size.X / 2 + 4 and math.abs(r.Position.Z - center.Z) < size.Z / 2 + 4 then fire(Net.Shovel.HitPlayer, pl.UserId) end
        end
    end
end)

lp(3, function()
    if not S.abCrate then return end
    local it = stockIt("CrateShop"); if not it then return end
    for _, sv in ipairs(it:GetChildren()) do if sv:IsA("ValueBase") and sv.Value > 0 then fire(Net.CrateShop.PurchaseCrate, sv.Name); task.wait(0.1) end end
end)
lp(3, function()
    if not S.abGear then return end
    local it = gearStock(); if not it then return end
    local anySel = next(S.bGears) ~= nil
    for _, sv in ipairs(it:GetChildren()) do
        if sv:IsA("ValueBase") and sv.Value > 0 and ((not anySel) or S.bGears[sv.Name] == true) then fire(Net.GearShop.PurchaseGear, sv.Name); task.wait(0.1) end
    end
end)

local function openAll(invKey, pkt, flag)
    lp(2.5, function()
        if not S[flag] then return end
        local d = getData(); local bag = d and d.Inventory and d.Inventory[invKey]; if not bag then return end
        for name, count in pairs(bag) do local n = (type(count) == "number") and count or 1 for _ = 1, n do task.spawn(function() fire(pkt, name) end) task.wait(0.15) end end
    end)
end
openAll("Eggs", Net.Egg.OpenEgg, "aEgg")
openAll("Crates", Net.Crate.OpenCrate, "aCrate")
openAll("SeedPacks", Net.SeedPack.OpenSeedPack, "aPack")

lp(1.2, function()
    if not S.aTame then return end
    local map = WS:FindFirstChild("Map"); local refs = map and map:FindFirstChild("WildPetRef"); if not refs then return end
    local anySel = next(S.tAnim) ~= nil
    for _, pet in ipairs(refs:GetChildren()) do
        if not S.aTame then break end
        local owner = tonumber(pet:GetAttribute("OwnerUserId")) or 0
        local species = pet:GetAttribute("PetName")
        if ((not anySel) or (species and S.tAnim[species] == true)) and (owner == 0 or owner == LP.UserId) and pet:IsA("BasePart") then
            reach(pet.Position); setStatus("正在驯服 " .. tostring(species))
            for _ = 1, 6 do if not S.aTame then break end pcall(function() Net.Pets.WildPetTame:Fire(pet) end) task.wait(0.08) end
        end
    end
end)
local GP = {
    Raccoon = true, Dragonfly = true, ["Dragon Fly"] = true, Dragonling = true, Mimic = true,
    ["Disco Bee"] = true, ["Queen Bee"] = true, Kitsune = true, ["Red Fox"] = true, Fox = true,
    Owl = true, ["Night Owl"] = true, Bear = true, ["Polar Bear"] = true, Butterfly = true,
    ["Golden Lab"] = true, Cat = true, ["Red Giant Ant"] = true, Snail = true,
}
local function progBuy()
    local it = seedStock(); if not it then return end
    local funds = getShk(); local best, bv
    for _, sv in ipairs(it:GetChildren()) do
        if sv:IsA("ValueBase") and sv.Value > 0 then
            local price, val = SCost[sv.Name] or math.huge, SVal[sv.Name] or 0
            if price <= funds * 0.5 and (not bv or val > bv) then best, bv = sv.Name, val end
        end
    end
    if best then for _ = 1, 6 do if getShk() < (SCost[best] or 0) then break end fire(Net.SeedShop.PurchaseSeed, best); task.wait(0.1) end end
    return best
end
local function progPlant()
    local plot = myPlot(); if not plot then return 0 end
    local d = getData(); local seeds = d and d.Inventory and d.Inventory.Seeds; if not seeds then return 0 end
    local tp = {}
    for name, count in pairs(seeds) do for _ = 1, math.min(count or 0, 30) do tp[#tp + 1] = name end end
    if #tp == 0 then return 0 end
    local free = freePos(plot); local cap = math.min(#free, #tp); local n = 0
    for i = 1, cap do fire(Net.Plant.PlantSeed, free[i], tp[i], plot); n = n + 1; task.wait(0.08) end
    return n
end
lp(4, function()
    if not S.aProg then return end
    local h = harvestAll(false)
    if (LP:GetAttribute("FruitCount") or 0) > 0 then fire(Net.NPCS.SellAll); task.wait(0.2) end
    progBuy()
    local p = progPlant()
    setStatus(("自动进度: +%d 收获, +%d 种植, %s"):format(h, p, money(getShk())))
end)
lp(1.5, function()
    if not S.aProg then return end
    local map = WS:FindFirstChild("Map"); local refs = map and map:FindFirstChild("WildPetRef"); if not refs then return end
    for _, pet in ipairs(refs:GetChildren()) do
        if not S.aProg then break end
        local species = pet:GetAttribute("PetName"); local owner = tonumber(pet:GetAttribute("OwnerUserId")) or 0
        if species and GP[species] and (owner == 0 or owner == LP.UserId) and pet:IsA("BasePart") then
            reach(pet.Position); setStatus("自动进度: 正在驯服 " .. species)
            for _ = 1, 6 do if not S.aProg then break end pcall(function() Net.Pets.WildPetTame:Fire(pet) end) task.wait(0.08) end
        end
    end
end)
lp(5, function()
    if not S.aEquip then return end
    local n, mx = 0, maxEq()
    for name in pairs(S.ePets) do if n >= mx then break end fire(Net.Pets.RequestEquipByName, tostring(name)); n = n + 1; task.wait(0.15) end
end)

local flyBV, flyBG
local function stopFly()
    if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
    if flyBG then pcall(function() flyBG:Destroy() end) flyBG = nil end
    local h = hmd(); if h then h.PlatformStand = false end
end
Hub.stopFly = stopFly
local function startFly()
    local r = hrp(); if not r then return end
    stopFly()
    flyBV = Instance.new("BodyVelocity"); flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9; flyBV.Velocity = Vector3.zero; flyBV.Parent = r
    flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.new(1, 1, 1) * 9e9; flyBG.P = 1e5; flyBG.CFrame = r.CFrame; flyBG.Parent = r
end
tk(RunSvc.Heartbeat:Connect(function()
    if not Hub.on then return end
    local h = hmd()
    if h then
        if S.wSpd ~= 16 then h.WalkSpeed = S.wSpd end
        if S.jPow ~= 50 then h.UseJumpPower = true; h.JumpPower = S.jPow end
    end
    if S.nclip then local c = chr() if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end end end
    if S.fly then
        local r = hrp(); local cam = WS.CurrentCamera
        if r and cam then
            if not flyBV then startFly() end
            if h then h.PlatformStand = true end
            local d = Vector3.zero
            local function k(c) return UIS:IsKeyDown(c) end
            if k(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
            if k(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
            if k(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
            if k(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
            if k(Enum.KeyCode.Space) then d = d + Vector3.new(0, 1, 0) end
            if k(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0, 1, 0) end
            if flyBV then flyBV.Velocity = (d.Magnitude > 0 and d.Unit or Vector3.zero) * S.fSpd end
            if flyBG then flyBG.CFrame = cam.CFrame end
        end
    elseif flyBV then stopFly() end
end))
tk(UIS.JumpRequest:Connect(function() if S.iJump then local h = hmd() if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end))

do
    local VU = game:GetService("VirtualUser")
    tk(LP.Idled:Connect(function()
        if not S.aAfk then return end
        pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)
    end))
end

local TPS = game:GetService("TeleportService")
local httpReq = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or (typeof(request) == "function" and request) or http_request
local function sendWH(content)
    if not (S.whUrl and S.whUrl ~= "" and httpReq) then return false end
    task.spawn(function()
        pcall(function()
            httpReq({ Url = S.whUrl, Method = "POST", Headers = { ["Content-Type"] = "application/json" },
                Body = HS:JSONEncode({ username = "Ccat", content = content }) })
        end)
    end)
    return true
end
local function fetchSrv()
    local ok, res = pcall(function()
        local raw = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        return HS:JSONDecode(raw)
    end)
    return (ok and res and res.data) or {}
end
local function serverHop(lowPop)
    setStatus("正在寻找服务器...")
    local servers = fetchSrv(); local pick
    for _, s in ipairs(servers) do
        if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
            if lowPop then if not pick or s.playing < pick.playing then pick = s end
            else pick = s; break end
        end
    end
    if pick then setStatus("正在切换 (" .. pick.playing .. " 人)..."); pcall(function() TPS:TeleportToPlaceInstance(game.PlaceId, pick.id, LP) end)
    else setStatus("未找到服务器 - 请重试") end
end
local function rareInStock()
    local it = seedStock(); if not it then return false end
    for _, sv in ipairs(it:GetChildren()) do if sv:IsA("ValueBase") and sv.Value > 0 and (SCost[sv.Name] or 0) >= 5000 then return true, sv.Name end end
    return false
end
lp(20, function()
    if not S.aHop then return end
    if not rareInStock() then serverHop(false) end
end)

local Pft = { startS = nil, session = 0, perMin = 0, perHr = 0, win = {} }
lp(2, function()
    local s = getShk()
    if Pft.startS == nil then Pft.startS = s end
    Pft.session = s - Pft.startS
    table.insert(Pft.win, { t = os.clock(), s = s })
    while #Pft.win > 1 and (os.clock() - Pft.win[1].t) > 60 do table.remove(Pft.win, 1) end
    local f = Pft.win[1]; local dt = os.clock() - f.t
    if dt > 4 then Pft.perMin = (s - f.s) / dt * 60; Pft.perHr = Pft.perMin * 60 end
end)

local hlF = Instance.new("Folder"); hlF.Name = "Ccat_HL"; hlF.Parent = WS
local function clearHL() for _, h in ipairs(hlF:GetChildren()) do h:Destroy() end end
local function addHL(model, col)
    if not model or not model.Parent then return end
    local h = Instance.new("Highlight"); h.Adornee = model; h.FillColor = col; h.FillTransparency = 0.55
    h.OutlineColor = col; h.OutlineTransparency = 0; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Parent = hlF
end
lp(1, function()
    if not (S.hlRdy or S.hlRare) then if #hlF:GetChildren() > 0 then clearHL() end return end
    clearHL()
    local root = hrp(); local rp = root and root.Position
    if S.hlRdy then for _, m in ipairs(ownTargets()) do addHL(m, CC.accent) end end
    if S.hlRare and rp then
        local count = 0
        for _, p in ipairs(CollSvc:GetTagged("StealPrompt")) do
            if count >= 50 then break end
            local m = p.Parent and p.Parent:FindFirstAncestorWhichIsA("Model")
            if m and m:GetAttribute("Mutation") then
                local ok, piv = pcall(function() return m:GetPivot().Position end)
                if ok and (piv - rp).Magnitude < 220 then addHL(m, Color3.fromRGB(255, 205, 70)); count = count + 1 end
            end
        end
    end
end)
table.insert(Hub.cn, { Disconnect = function() pcall(clearHL) pcall(function() hlF:Destroy() end) end })

do
    local prev = {}
    lp(3, function()
        if not S.rNtfy then return end
        local it = seedStock(); if not it then return end
        for _, sv in ipairs(it:GetChildren()) do
            if sv:IsA("ValueBase") then
                local now = sv.Value > 0
                if now and not prev[sv.Name] and (SCost[sv.Name] or 0) >= 5000 then
                    setStatus("稀有种子上架: " .. sv.Name); notify(sv.Name .. " 刚刚补货 - " .. sv.Value .. "x 可用 (" .. fmtPrc(SCost[sv.Name]) .. ")", "稀有种子上架", CC.green)
                    if S.whRare then sendWH("**稀有种子上架:** " .. sv.Name .. " (" .. sv.Value .. "x)  -  " .. LP.Name) end
                end
                prev[sv.Name] = now
            end
        end
    end)
end

local Lighting = game:GetService("Lighting")
local optCn, optOrig
local function optInst(o)
    pcall(function()
        if o:IsA("BasePart") then o.Material = Enum.Material.SmoothPlastic; o.Reflectance = 0; o.CastShadow = false
        elseif o:IsA("Decal") or o:IsA("Texture") then o.Transparency = 1
        elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then o.Enabled = false
        elseif o:IsA("PostEffect") then o.Enabled = false
        end
    end)
end
local function setOpt(on)
    if on then
        optOrig = optOrig or { gs = Lighting.GlobalShadows, fc = Lighting.FogColor, fs = Lighting.FogStart, fe = Lighting.FogEnd, br = Lighting.Brightness, oa = Lighting.OutdoorAmbient, am = Lighting.Ambient }
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogColor = Color3.fromRGB(131, 133, 139); Lighting.FogStart = 220; Lighting.FogEnd = 780
            Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 146); Lighting.Ambient = Color3.fromRGB(122, 122, 128)
        end)
        for _, e in ipairs(Lighting:GetDescendants()) do
            if e:IsA("Atmosphere") or e:IsA("Clouds") or e:IsA("PostEffect") then pcall(function() e.Enabled = false end) end
            if e:IsA("Sky") then pcall(function() e.CelestialBodiesShown = false end) end
        end
        pcall(function() WS.Terrain.Decoration = false end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        for _, o in ipairs(WS:GetDescendants()) do optInst(o) end
        if optCn then for _, c in ipairs(optCn) do pcall(function() c:Disconnect() end) end end
        local function onAdd(o) if S.opt then task.defer(optInst, o) end end
        optCn = { WS.DescendantAdded:Connect(onAdd), Lighting.DescendantAdded:Connect(onAdd) }
        for _, c in ipairs(optCn) do tk(c) end
        setStatus("已优化 - 平面材质, 灰色天空, 特效关闭")
    else
        if optCn then for _, c in ipairs(optCn) do pcall(function() c:Disconnect() end) end optCn = nil end
        if optOrig then pcall(function()
            Lighting.GlobalShadows = optOrig.gs; Lighting.FogColor = optOrig.fc; Lighting.FogStart = optOrig.fs; Lighting.FogEnd = optOrig.fe; Lighting.Brightness = optOrig.br
            Lighting.OutdoorAmbient = optOrig.oa; Lighting.Ambient = optOrig.am
        end) end
        for _, e in ipairs(Lighting:GetDescendants()) do
            if e:IsA("Atmosphere") or e:IsA("Clouds") or e:IsA("PostEffect") then pcall(function() e.Enabled = true end) end
            if e:IsA("Sky") then pcall(function() e.CelestialBodiesShown = true end) end
        end
        pcall(function() WS.Terrain.Decoration = true end)
        for _, o in ipairs(WS:GetDescendants()) do
            if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then pcall(function() o.Enabled = true end)
            elseif o:IsA("Decal") or o:IsA("Texture") then pcall(function() o.Transparency = 0 end) end
        end
        setStatus("优化已关闭(重新加入可完全恢复)")
    end
end

local TF = Win:AddTab("农场")
local TSh = Win:AddTab("商店")
local TSt = Win:AddTab("偷取")
local TDf = Win:AddTab("防御")
local TEv = Win:AddTab("活动")
local TTm = Win:AddTab("计时")
local TIt = Win:AddTab("物品")
local TPt = Win:AddTab("宠物")
local TStt = Win:AddTab("统计")
local TTp = Win:AddTab("传送")
local TVi = Win:AddTab("视觉")
local TPl = Win:AddTab("玩家")
local TMi = Win:AddTab("杂项")
local TSr = Win:AddTab("服务器")

local function ddFromSet(getOpts, selSet)
    local vals, def = {}, {}
    for _, opt in ipairs(getOpts()) do
        vals[#vals + 1] = opt
        if selSet[opt] then def[#def + 1] = opt end
    end
    return vals, def
end

local function mkMultiDD(box, idx, text, getOpts, selSet, tip)
    local vals, def = ddFromSet(getOpts, selSet)
    local dd = box:AddDropdown(idx, {
        Text = text, Values = vals, Default = def, Multi = true, Tooltip = tip,
        Callback = function(Value)
            for k in pairs(selSet) do selSet[k] = nil end
            for k, v in pairs(Value) do if v then selSet[k] = true end end
            sv()
        end
    })
    lp(4, function()
        local nv = getOpts()
        local cur = {} for k in pairs(selSet) do cur[k] = true end
        pcall(function() dd:SetValues(nv) end)
        pcall(function() dd:SetValue(cur) end)
    end)
    return dd
end

local function mkChoiceDD(box, idx, text, getOpts, getSel, onPick, tip)
    local vals = getOpts()
    local dd = box:AddDropdown(idx, {
        Text = text, Values = vals, Default = getSel() or vals[1], Multi = false, Tooltip = tip,
        Callback = function(Value) onPick(Value) sv() end
    })
    lp(4, function()
        local nv = getOpts()
        pcall(function() dd:SetValues(nv) end)
    end)
    return dd
end

do
    local L = TF:AddLeftGroupbox("自动种植")
    L:AddToggle("autoPlantToggle", {
        Text = "自动种植", Default = S.aPlant,
        Tooltip = "在你的地块上循环种植已拥有的种子",
        Callback = function(v) S.aPlant = v sv() end
    })
    mkMultiDD(L, "plantSeedsDD", "要种植的种子（空=全部）", ownedSeedOpts, S.pSeeds, "只显示你库存中的种子")
    mkChoiceDD(L, "plantPatternDD", "种植图案", function() return PAT end, function() return S.pPat end, function(v) S.pPat = v end)
    mkChoiceDD(L, "plantSourceDD", "种植来源", function() local t = {"我的种子"} for _, n in ipairs(snapNames()) do t[#t + 1] = n end return t end, function() return S.pSrc end, function(v) S.pSrc = v end)
    L:AddToggle("smartReplantToggle", {
        Text = "智能补种", Default = S.smtRp,
        Tooltip = "只种植你拥有的最值钱的种子",
        Callback = function(v) S.smtRp = v sv() end
    })
    L:AddButton({
        Text = "立即种植一次",
        Func = function()
            local plot = myPlot(); if not plot then return end
            local d = getData(); local seeds = d and d.Inventory and d.Inventory.Seeds; if not seeds then return end
            local useF = next(S.pSeeds) ~= nil; local tp = {}
            for n, c in pairs(seeds) do if (not useF) or S.pSeeds[n] then for _ = 1, math.min(c or 0, 40) do tp[#tp + 1] = n end end end
            local free = freePos(plot)
            for i = 1, math.min(#free, #tp) do fire(Net.Plant.PlantSeed, free[i], tp[i], plot) task.wait(S.pDly) end
            setStatus("已种植 " .. math.min(#free, #tp))
        end
    })
    L:AddDivider()
    L:AddToggle("autoExpandToggle", {
        Text = "自动扩建花园", Default = S.aExp,
        Tooltip = "只要你买得起就购买下一次扩建",
        Callback = function(v) S.aExp = v sv() end
    })
    L:AddButton({
        Text = "立即扩建花园",
        Func = function()
            local plot = myPlot(); if not plot then return end
            local before = tonumber(plot:GetAttribute("GardenExpansion")) or 0
            fire(Net.Actions.ExpandGarden); task.wait(0.8)
            local after = tonumber(plot:GetAttribute("GardenExpansion")) or before
            setStatus(after > before and ("花园已扩建至 " .. after .. " 级") or "无法扩建(余额不足或已满级)")
        end
    })
    L:AddDivider()
    L:AddSlider("plantReserveSlider", { Text = "保留数量（每种种子）", Default = S.pRes, Min = 0, Max = 25, Rounding = 0, Callback = function(v) S.pRes = v sv() end })
    L:AddSlider("maxPerCycleSlider", { Text = "每轮最大种植数", Default = S.mxCyc, Min = 1, Max = 80, Rounding = 0, Callback = function(v) S.mxCyc = v sv() end })
    L:AddSlider("plantDelaySlider", { Text = "种植延迟", Default = S.pDly, Min = 0.05, Max = 1, Rounding = 2, Callback = function(v) S.pDly = v sv() end })
    L:AddSlider("plantLoopSlider", { Text = "循环延迟", Default = S.pLoop, Min = 0.5, Max = 10, Rounding = 1, Callback = function(v) S.pLoop = v sv() end })

    local R = TF:AddRightGroupbox("自动收获")
    R:AddToggle("autoCollectToggle", {
        Text = "自动收获", Default = S.aColl,
        Tooltip = "循环收集你地块上所有成熟的果实",
        Callback = function(v) S.aColl = v sv() end
    })
    mkMultiDD(R, "harvestCropsDD", "只收获这些作物（空=全部）", harvestOpts, S.hCrops)
    R:AddToggle("harvestMutsOnlyToggle", { Text = "仅收获变异果实", Default = S.hMuts, Callback = function(v) S.hMuts = v sv() end })
    R:AddSlider("perFruitDelaySlider", { Text = "每果实延迟", Default = S.fDly, Min = 0.02, Max = 0.5, Rounding = 2, Callback = function(v) S.fDly = v sv() end })
    R:AddSlider("harvestLoopSlider", { Text = "循环延迟", Default = S.hLoop, Min = 0.5, Max = 10, Rounding = 1, Callback = function(v) S.hLoop = v sv() end })
    R:AddButton({ Text = "立即收获", Func = function() setStatus("已收获 " .. harvestAll(false)) end })
    R:AddDivider()
    R:AddToggle("autoSellToggle", { Text = "自动出售（定时）", Default = S.aSell, Callback = function(v) S.aSell = v sv() end })
    R:AddSlider("sellIntervalSlider", { Text = "出售间隔（秒）", Default = S.sInt, Min = 5, Max = 120, Rounding = 0, Callback = function(v) S.sInt = v sv() end })
    R:AddToggle("sellOnFullToggle", { Text = "背包满时自动出售", Default = S.sFull, Callback = function(v) S.sFull = v sv() end })
    R:AddButton({ Text = "立即全部出售", Func = function() fire(Net.NPCS.SellAll); setStatus("已全部出售") end })
end

do
    local L = TSh:AddLeftGroupbox("种子")
    L:AddToggle("autoBuySeedToggle", {
        Text = "自动购买种子", Default = S.abSeed,
        Tooltip = "补货时立即购买你勾选的种子，留空则购买全部",
        Callback = function(v) S.abSeed = v sv() end
    })
    mkMultiDD(L, "buySeedsDD", "要购买的种子（空=全部）", seedOpts, S.bSeeds)
    L:AddButton({
        Text = "立即购买",
        Func = function()
            local it = seedStock(); if not it then return end
            local anySel = next(S.bSeeds) ~= nil
            for _, sv in ipairs(it:GetChildren()) do if sv:IsA("ValueBase") and sv.Value > 0 and ((not anySel) or S.bSeeds[sv.Name] == true) then fire(Net.SeedShop.PurchaseSeed, sv.Name) task.wait(0.08) end end
            setStatus("已购买种子")
        end
    })

    local R = TSh:AddRightGroupbox("装备与箱子")
    R:AddToggle("autoBuyGearToggle", { Text = "自动购买装备", Default = S.abGear, Callback = function(v) S.abGear = v sv() end })
    mkMultiDD(R, "buyGearsDD", "要购买的装备（空=全部）", gearOpts, S.bGears)
    R:AddToggle("autoBuyCrateToggle", { Text = "自动购买箱子", Default = S.abCrate, Callback = function(v) S.abCrate = v sv() end })
end

do
    local L = TSt:AddLeftGroupbox("夜间偷取")
    L:AddToggle("autoStealToggle", { Text = "自动偷取", Default = S.aSteal, Tooltip = "按价值从高到低偷取其他花园的成熟果实，仅限夜间", Callback = function(v) S.aSteal = v sv() end })
    L:AddToggle("stealReturnToggle", { Text = "完成后返回家中", Default = S.sRet, Callback = function(v) S.sRet = v sv() end })
    L:AddSlider("stealMultSlider", { Text = "每次偷取果实数", Default = S.sMul, Min = 1, Max = 10, Rounding = 0, Callback = function(v) S.sMul = v sv() end })

    local R = TSt:AddRightGroupbox("手动操作")
    R:AddButton({
        Text = "偷取最高价值",
        Func = function()
            if not isNight() then setStatus("非夜晚 - 无法偷取") return end
            local t = stealTgts(); if t[1] then stealModel(t[1].m, S.sMul); setStatus("偷取了价值 " .. math.floor(t[1].v) .. " 的果实") else setStatus("没有可偷取的") end
        end
    })
end

do
    local L = TDf:AddLeftGroupbox("保护你的花园")
    L:AddToggle("panicHarvestToggle", { Text = "夜晚紧急收获", Default = S.pHarv, Tooltip = "夜晚开始时立即收集所有成熟作物", Callback = function(v) S.pHarv = v sv() end })
    L:AddToggle("retaliateToggle", { Text = "反击（铲入侵者）", Default = S.retl, Tooltip = "铲击站在你地块上的非所有者", Callback = function(v) S.retl = v sv() end })
    L:AddButton({ Text = "立即收获全部", Func = function() setStatus("已收获 " .. harvestAll(false)) end })
end

do
    local L = TEv:AddLeftGroupbox("黄金月亮")
    L:AddToggle("autoGrabPacksToggle", { Text = "自动抓取种子包", Default = S.aGrab, Tooltip = "飞到刷新的种子包并完成长按领取", Callback = function(v) S.aGrab = v sv() end })
    L:AddToggle("grabRareOnlyToggle", { Text = "仅稀有（金色/彩虹）", Default = S.gRare, Callback = function(v) S.gRare = v sv() end })
    L:AddToggle("packReturnToggle", { Text = "活动结束后返回", Default = S.pRet, Callback = function(v) S.pRet = v sv() end })
    L:AddToggle("notifyRareToggle", { Text = "稀有刷新时通知", Default = S.nRare, Callback = function(v) S.nRare = v sv() end })
    L:AddButton({
        Text = "立即抓取最近的包",
        Func = function()
            local root = hrp(); if not root then return end
            local map = WS:FindFirstChild("Map"); local locs = map and map:FindFirstChild("SeedPackSpawnServerLocations")
            if not locs or #locs:GetChildren() == 0 then setStatus("当前没有种子包刷新") return end
            local best, bestD
            for _, loc in ipairs(locs:GetChildren()) do local d = (loc.Position - root.Position).Magnitude if d < (bestD or math.huge) then best, bestD = loc, d end end
            if best then grabPack(best); setStatus("已抓取最近的种子包") end
        end
    })
end

do
    local L = TTm:AddLeftGroupbox("当前活动")
    local evLbl = L:AddLabel("活动: -")
    local evTLbl = L:AddLabel("剩余: -")

    local R = TTm:AddRightGroupbox("商店补货")
    local sLbl = R:AddLabel("种子商店: -")
    local gLbl = R:AddLabel("装备商店: -")
    local cLbl = R:AddLabel("箱子商店: -")

    lp(1, function()
        local raw, _, endsAt = curEv()
        evLbl:SetText("活动: " .. evNm(raw))
        evTLbl:SetText("剩余: " .. (endsAt and fmtClk(endsAt - os.time()) or "-"))
        local s, g, c = restockIn("SeedShop"), restockIn("GearShop"), restockIn("CrateShop")
        sLbl:SetText("种子商店: " .. (s and fmtClk(s) or "-"))
        gLbl:SetText("装备商店: " .. (g and fmtClk(g) or "-"))
        cLbl:SetText("箱子商店: " .. (c and fmtClk(c) or "-"))
    end)
end

do
    local L = TIt:AddLeftGroupbox("自动开启")
    L:AddToggle("autoEggsToggle", { Text = "自动开蛋", Default = S.aEgg, Callback = function(v) S.aEgg = v sv() end })
    L:AddToggle("autoCratesToggle", { Text = "自动开箱子", Default = S.aCrate, Callback = function(v) S.aCrate = v sv() end })
    L:AddToggle("autoPacksToggle", { Text = "自动开种子包", Default = S.aPack, Callback = function(v) S.aPack = v sv() end })
    L:AddButton({ Text = "开启全部蛋", Func = function() local d = getData() local b = d and d.Inventory and d.Inventory.Eggs if b then for n in pairs(b) do task.spawn(function() fire(Net.Egg.OpenEgg, n) end) task.wait(0.15) end end setStatus("已开蛋") end })
    L:AddButton({ Text = "开启全部箱子", Func = function() local d = getData() local b = d and d.Inventory and d.Inventory.Crates if b then for n in pairs(b) do task.spawn(function() fire(Net.Crate.OpenCrate, n) end) task.wait(0.15) end end setStatus("已开箱子") end })
    L:AddButton({ Text = "开启全部种子包", Func = function() local d = getData() local b = d and d.Inventory and d.Inventory.SeedPacks if b then for n in pairs(b) do task.spawn(function() fire(Net.SeedPack.OpenSeedPack, n) end) task.wait(0.15) end end setStatus("已开种子包") end })

    local R = TIt:AddRightGroupbox("花园快照")
    local snapName = "快照 1"
    R:AddInput("snapNameInput", { Text = "快照名称", Default = snapName, Numeric = false, Finished = true, Placeholder = "快照 1", Callback = function(t) if t and t ~= "" then snapName = t end end })
    R:AddButton({
        Text = "快照当前花园",
        Func = function()
            local ok, msg = captureSnap(snapName)
            if ok then notify('已保存 "' .. snapName .. '" - ' .. msg, "花园快照", CC.green) else setStatus(tostring(msg)) end
        end
    })
    R:AddDivider()
    R:AddToggle("autoBuildToggle", { Text = "自动建造快照", Default = S.aBld, Callback = function(v) S.aBld = v sv() end })
    R:AddButton({ Text = "立即建造快照", Func = function() buildSnap() end })
    R:AddDivider()
    mkMultiDD(R, "removeCropsDD", "要移除的植物", plantedOpts, S.rmCrops)
    R:AddButton({ Text = "移除选中植物", Func = function() if not next(S.rmCrops) then setStatus("请先选择要移除的作物") return end setStatus("正在移除选中...") task.spawn(function() local n = rmSelPlants() setStatus("已移除 " .. n .. " 株植物") end) end })
    R:AddButton({ Text = "移除全部植物", Func = function() setStatus("正在移除植物...") task.spawn(function() local n = rmAllPlants() setStatus("已移除 " .. n .. " 株植物") end) end })
    R:AddButton({ Text = "移除全部建筑", Func = function() setStatus("正在移除建筑...") task.spawn(function() local n = rmAllBld() setStatus("已移除 " .. n .. " 个建筑") end) end })
end

do
    local L = TPt:AddLeftGroupbox("野生动物")
    L:AddToggle("autoTameToggle", { Text = "自动驯服野生动物", Default = S.aTame, Tooltip = "留空则驯服所有刷新的野生动物", Callback = function(v) S.aTame = v sv() end })
    mkMultiDD(L, "tameAnimalsDD", "要驯服的动物（空=全部）", animalOpts, S.tAnim)

    local R = TPt:AddRightGroupbox("你的宠物")
    R:AddToggle("autoEquipPetsToggle", { Text = "自动装备宠物", Default = S.aEquip, Tooltip = "保持所选宠物装备状态", Callback = function(v) S.aEquip = v sv() end })
    mkMultiDD(R, "equipPetsDD", "要装备的宠物", petOpts, S.ePets)
    R:AddButton({
        Text = "立即装备",
        Func = function()
            local n, mx = 0, maxEq()
            for name in pairs(S.ePets) do if n >= mx then break end fire(Net.Pets.RequestEquipByName, tostring(name)) n = n + 1 task.wait(0.12) end
            setStatus("已装备 " .. n .. " 只宠物")
        end
    })
end

do
    local L = TStt:AddLeftGroupbox("利润追踪")
    local mLbl = L:AddLabel("每分钟: -")
    local hLbl = L:AddLabel("每小时: -")
    local sLbl = L:AddLabel("本次会话获得: -")

    local R = TStt:AddRightGroupbox("库存")
    local iLbl = R:AddLabel("背包价值: -")
    local cLbl = R:AddLabel("水果数量: -")
    local bLbl = R:AddLabel("最佳种植作物: -")
    R:AddButton({ Text = "重新扫描库存", Func = function() local v, n = invVal() setStatus("库存价值 " .. money(v) .. " (" .. n .. " 个果实)") end })

    lp(1, function()
        mLbl:SetText("每分钟: " .. money(Pft.perMin))
        hLbl:SetText("每小时: " .. money(Pft.perHr))
        sLbl:SetText("本次会话获得: " .. money(Pft.session))
        local v, n = invVal(); iLbl:SetText("背包价值: " .. money(v)); cLbl:SetText("水果数量: " .. n .. "x")
        local best = bestSeed(); local d = getData(); local cnt = (best and d and d.Inventory and d.Inventory.Seeds and d.Inventory.Seeds[best]) or 0
        bLbl:SetText("最佳种植作物: " .. (best and (best .. "   " .. cnt .. "x") or "-"))
    end)
end

do
    local L = TTp:AddLeftGroupbox("商店与NPC")
    local function tpBtn(box, label, pad)
        box:AddButton({ Text = label, Func = function()
            local t = WS:FindFirstChild("Teleports"); local d = t and t:FindFirstChild(pad)
            if d and d:IsA("BasePart") then reach(d.Position); setStatus("已传送至 " .. label) else setStatus(label .. " 未找到") end
        end })
    end
    tpBtn(L, "种子商店", "Seeds"); tpBtn(L, "装备商店", "Gears"); tpBtn(L, "出售NPC", "Sell"); tpBtn(L, "道具商店", "Props")

    local R = TTp:AddRightGroupbox("花园")
    R:AddButton({ Text = "我的花园", Func = function() local plot = myPlot() local sp = plot and plot:FindFirstChild("SpawnPoint") if sp then reach(sp.Position) end setStatus("已传送回家") end })
end

do
    local L = TVi:AddLeftGroupbox("ESP与提醒")
    L:AddToggle("highlightReadyToggle", { Text = "高亮成熟作物", Default = S.hlRdy, Tooltip = "用红宝石色描出你自己成熟的作物", Callback = function(v) S.hlRdy = v sv() end })
    L:AddToggle("highlightRareToggle", { Text = "高亮变异果实", Default = S.hlRare, Tooltip = "用金色描出附近的金色/变异果实", Callback = function(v) S.hlRare = v sv() end })
    L:AddToggle("rareNotifyToggle", { Text = "稀有种子补货提醒", Default = S.rNtfy, Tooltip = "高价种子上架时通知你", Callback = function(v) S.rNtfy = v sv() end })
end

do
    local L = TPl:AddLeftGroupbox("移动")
    L:AddSlider("walkSpeedSlider", { Text = "移动速度", Default = S.wSpd, Min = 16, Max = 120, Rounding = 0, Callback = function(v) S.wSpd = v sv() end })
    L:AddSlider("jumpPowerSlider", { Text = "跳跃力", Default = S.jPow, Min = 50, Max = 250, Rounding = 0, Callback = function(v) S.jPow = v sv() end })
    L:AddToggle("infJumpToggle", { Text = "无限跳跃", Default = S.iJump, Callback = function(v) S.iJump = v sv() end })
    L:AddToggle("noclipToggle", {
        Text = "穿墙", Default = S.nclip,
        Callback = function(v)
            S.nclip = v
            if not v then local c = chr() if c then for _, pp in ipairs(c:GetDescendants()) do if pp:IsA("BasePart") then pp.CanCollide = true end end end end
            sv()
        end
    })

    local R = TPl:AddRightGroupbox("飞行")
    R:AddToggle("flyToggle", {
        Text = "飞行", Default = S.fly, Tooltip = "W/A/S/D自由飞行，空格上升，Ctrl下降",
        Callback = function(v) S.fly = v if not v and Hub.stopFly then Hub.stopFly() end sv() end
    })
    R:AddSlider("flySpeedSlider", { Text = "飞行速度", Default = S.fSpd, Min = 20, Max = 150, Rounding = 0, Callback = function(v) S.fSpd = v sv() end })
    R:AddDivider()
    R:AddButton({ Text = "传送到我的花园", Func = function() local plot = myPlot() local sp = plot and plot:FindFirstChild("SpawnPoint") if sp then reach(sp.Position) end setStatus("已传送") end })
end

do
    local L = TMi:AddLeftGroupbox("实用工具")
    L:AddToggle("autoProgressToggle", { Text = "自动进度", Default = S.aProg, Tooltip = "自动收获、出售、再投资并驯服宠物", Callback = function(v) S.aProg = v sv() end })
    L:AddDivider()
    L:AddToggle("optimizeToggle", { Text = "性能优化", Default = S.opt, Tooltip = "平面材质、灰色天空、关闭特效——大幅提升帧率", Callback = function(v) S.opt = v setOpt(v) sv() end })
    L:AddDivider()
    L:AddToggle("antiAfkToggle", { Text = "防挂机", Default = S.aAfk, Tooltip = "防止20分钟挂机被踢", Callback = function(v) S.aAfk = v sv() end })
    L:AddButton({ Text = "重新加入服务器", Func = function() pcall(function() TPS:Teleport(game.PlaceId, LP) end) end })
    L:AddButton({ Text = "切换服务器", Func = function() pcall(function() Net.AntiAfk.RequestHop:Fire() end) setStatus("正在请求新服务器") end })
    L:AddDivider()
    StatusLabel = L:AddLabel("就绪")
    L:AddLabel("Right Shift 切换菜单 | X 完全卸载")
    L:AddButton({ Text = "卸载Hub", Func = function() Hub.unload() end })
    if S.opt then task.spawn(function() setOpt(true) end) end
end

do
    local L = TSr:AddLeftGroupbox("服务器切换")
    L:AddButton({ Text = "服务器切换", Func = function() serverHop(false) end })
    L:AddButton({ Text = "低人数服务器", Func = function() serverHop(true) end })
    L:AddToggle("autoHopRareToggle", { Text = "自动切换直到稀有种子", Default = S.aHop, Tooltip = "持续切换服务器直到有5K+种子在售", Callback = function(v) S.aHop = v sv() end })
end

function Hub.unload()
    if not Hub.on then return end
    sv()
    Hub.on = false
    for _, c in ipairs(Hub.cn) do pcall(function() c:Disconnect() end) end
    Hub.cn = {}
    if Hub.stopFly then pcall(Hub.stopFly) end
    local h = hmd(); if h then h.WalkSpeed = 16; h.UseJumpPower = true; h.JumpPower = 50; h.PlatformStand = false end
    local c = chr(); if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end end end
    for k, v in pairs(S) do if type(v) == "boolean" then S[k] = false end end
    pcall(function() Lib:Unload() end)
end
genv.Ccat_unload = Hub.unload
genv.Ccat_notify = function(msg, title, col) notify(msg, title, col) end
tk(UIS.InputBegan:Connect(function(i, gpe)
    if not gpe and i.KeyCode == Enum.KeyCode.RightShift then
        pcall(function() Lib.ToggleUI() end)
    end
end))