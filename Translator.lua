local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Lib = loadstring(game:HttpGet(repo .. "Library.lua"))()

local cfg = {
    lng = (getfenv()["翻译目标"] or "zh-CN"):gsub("中文", "zh-CN"):gsub("日语", "ja"):gsub("韩语", "ko"),
    spd = getfenv()["速度"] or 5,
    h = game:GetService("HttpService"),
    p = game:GetService("Players"),
    r = game:GetService("RunService"),
    tcs = game:GetService("TextChatService"),
    lp = game:GetService("Players").LocalPlayer,
    pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
    cg = game:GetService("CoreGui"),
    cch = {},
    proc = {},
    tm = 0,
    act = true
}

Lib:SetWatermark("By·Ccat | 目标语言: " .. cfg.lng .. " | 翻译速度: " .. cfg.spd .. "x")

task.spawn(function()
    local target = cfg.cg:WaitForChild("LinoriaGui", 5) or cfg.pg:WaitForChild("LinoriaGui", 5)
    if target then
        for _, v in ipairs(target:GetDescendants()) do
            if v:IsA("TextLabel") and v.Text:find("By·Ccat") then
                local p = v.Parent
                if p and p:IsA("Frame") then
                    local s = Instance.new("UIStroke")
                    s.Color = Color3.fromRGB(0, 120, 255)
                    s.Thickness = 2
                    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    s.Parent = p
                end
            end
        end
    end
end)

local function isTargetLanguage(t, lang)
    if not t or t == "" then return false end
    if lang == "zh-CN" or lang == "zh-TW" then
        for _, c in ipairs({utf8.codepoint(t, 1, -1)}) do
            if c >= 0x4E00 and c <= 0x9FFF then return true end
        end
    elseif lang == "ja" then
        for _, c in ipairs({utf8.codepoint(t, 1, -1)}) do
            if (c >= 0x3040 and c <= 0x309F) or (c >= 0x30A0 and c <= 0x30FF) then return true end
        end
    elseif lang == "ko" then
        for _, c in ipairs({utf8.codepoint(t, 1, -1)}) do
            if c >= 0xAC00 and c <= 0xD7A3 then return true end
        end
    end
    return false
end

local function detLng(t)
    if isTargetLanguage(t, cfg.lng) then return cfg.lng end
    if isTargetLanguage(t, "zh-CN") then return "zh-CN" end
    if isTargetLanguage(t, "ja") then return "ja" end
    if isTargetLanguage(t, "ko") then return "ko" end
    return "en"
end

local function trns(t, sl, tl)
    if not t or t == "" or #t > 800 then return nil end
    local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl="..sl.."&tl="..tl.."&dt=t&q="..cfg.h:UrlEncode(t)
    local s, r = pcall(function() return game:HttpGet(url, false, {["User-Agent"]="Mozilla/5.0"}) end)
    if s and r then
        local d, res = pcall(function() return cfg.h:JSONDecode(r) end)
        if d and res and res[1] and res[1][1] and res[1][1][1] then
            return res[1][1][1]
        end
    end
    return nil
end

local function skp(t)
    if not t or t == "" or utf8.len(t) == nil or utf8.len(t) < 2 then return true end
    if cfg.cch[t] then return true end
    if t:match("^[%s%d%p%+=<>_/\\%*&%%$#@!~`|]+$") then return true end
    if t:match("%d+[%a%s%p]+%d*") or t:match("%d+:%d+") then return true end
    
    local l = detLng(t)
    if l == cfg.lng then 
        cfg.cch[t] = t
        return true 
    end
    return false
end

local function isUI(o)
    return o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")
end

local function isChat(o)
    if not o then return true end
    if o:IsDescendantOf(cfg.tcs) or o.Name:lower():find("chat") or o.Name:lower():find("bubble") then return true end
    return false
end

local function proc(o)
    if not isUI(o) or isChat(o) then return end
    local txt = o.Text
    if not txt or txt == "" or skp(txt) then return end
    if cfg.proc[o] == txt then return end
    
    cfg.proc[o] = txt
    
    if cfg.cch[txt] then
        if cfg.cch[txt] ~= txt then
            o.Text = cfg.cch[txt]
        end
        return
    end
    
    local sl = detLng(txt)
    task.spawn(function()
        local tr = trns(txt, sl, cfg.lng)
        if tr and tr ~= txt then
            cfg.cch[txt] = tr
            if o and o.Parent and o.Text == txt then
                o.Text = tr
                cfg.proc[o] = tr
            end
        else
            cfg.cch[txt] = txt
            cfg.proc[o] = nil
        end
    end)
end

local function scan()
    local ct = tick()
    if ct - cfg.tm < 1 / cfg.spd then return end
    cfg.tm = ct
    
    local function processTree(o)
        for _, c in ipairs(o:GetChildren()) do
            if isUI(c) and not isChat(c) then
                proc(c)
            end
            processTree(c)
        end
    end
    
    pcall(processTree, cfg.pg)
    pcall(processTree, cfg.cg)
end

cfg.pg.DescendantAdded:Connect(function(d)
    if isUI(d) and not isChat(d) then
        task.delay(0.01, function() if d.Parent then proc(d) end end)
    end
end)

cfg.cg.DescendantAdded:Connect(function(d)
    if isUI(d) and not isChat(d) then
        task.delay(0.01, function() if d.Parent then proc(d) end end)
    end
end)

cfg.r.Heartbeat:Connect(function()
    if cfg.act then scan() end
end)
