--!nocheck
-- bc i need to use luau lsp to check syntax error,made by karisob,discord name:"333333T",qq:"3521551513"
local bit32_band = bit32.band
local bit32_rshift = bit32.rshift

local LBC_VERSION_MIN = 3
local LBC_VERSION_MAX = 9

local LBC_CONSTANT_NIL = 0
local LBC_CONSTANT_BOOLEAN = 1
local LBC_CONSTANT_NUMBER = 2
local LBC_CONSTANT_STRING = 3
local LBC_CONSTANT_IMPORT = 4
local LBC_CONSTANT_TABLE = 5
local LBC_CONSTANT_CLOSURE = 6
local LBC_CONSTANT_VECTOR = 7
local LBC_CONSTANT_TABLE_WITH_CONSTANTS = 8
local LBC_CONSTANT_INTEGER = 9

local PASSES = {}

local ROBLOX_OPCODES = {
	[4] = "POWK",
	[9] = "MUL",
	[13] = "JUMPXLEKN",
	[14] = "JUMPIFNOT",
	[18] = "CAPTURE",
	[19] = "GETTABLEN",
	[23] = "FORGPREP",
	[28] = "LENGTH",
	[33] = "MODK",
	[38] = "SUB",
	[42] = "JUMPXEQKB",
	[43] = "JUMPIF",
	[48] = "SETTABLEKS",
	[52] = "FASTCALL3",
	[57] = "MINUS",
	[62] = "DIVK",
	[67] = "ADD",
	[71] = "JUMPXEQKNIL",
	[72] = "JUMPBACK",
	[76] = "FASTCALL1",
	[77] = "GETTABLEKS",
	[81] = "FORGPREP_NEXT",
	[82] = "MOVE",
	[86] = "NOT",
	[91] = "MULK",
	[96] = "JUMPIFNOTLT",
	[100] = "FORGPREP_INEXT",
	[101] = "JUMP",
	[106] = "SETTABLE",
	[110] = "FORGLOOP",
	[111] = "LOADK",
	[115] = "CONCAT",
	[120] = "SUBK",
	[125] = "JUMPIFNOTLE",
	[129] = "FASTCALL2K",
	[130] = "RETURN",
	[135] = "GETTABLE",
	[139] = "FORNLOOP",
	[140] = "LOADN",
	[144] = "ORK",
	[149] = "ADDK",
	[154] = "JUMPIFNOTEQ",
	[158] = "FASTCALL2K",
	[159] = "CALL",
	[163] = "PREPVARARGS",
	[164] = "GETIMPORT",
	[168] = "FORNPREP",
	[169] = "LOADB",
	[183] = "JUMPIFLT",
	[187] = "FASTCALL1",
	[188] = "NAMECALL",
	[192] = "DUPCLOSURE",
	[193] = "CLOSEUPVALS",
	[197] = "SETLIST",
	[198] = "LOADNIL",
	[202] = "MOVE",
	[207] = "MOD",
	[216] = "DIVRK",
	[217] = "NEWCLOSURE",
	[222] = "SETUPVAL",
	[226] = "DUPTABLE",
	[231] = "AND",
	[236] = "DIV",
	[240] = "JUMPXEQKS",
	[241] = "JUMPIFEQ",
	[245] = "SUBRK",
	[251] = "GETUPVAL",
	[255] = "NEWTABLE",
}

local OPCODES = {}
for i = 0, 255 do
	OPCODES[i] = ROBLOX_OPCODES[i] or ("ROBLOX_OP_" .. tostring(i))
end

local OPS_WITH_AUX_BYTES = {
	[13] = true,
	[16] = true,
	[26] = true,
	[42] = true,
	[48] = true,
	[52] = true,
	[71] = true,
	[77] = true,
	[96] = true,
	[110] = true,
	[125] = true,
	[129] = true,
	[154] = true,
	[158] = true,
	[164] = true,
	[183] = true,
	[188] = true,
	[197] = true,
	[240] = true,
	[241] = true,
	[255] = true,
}

local OPS_WITH_AUX = {}
for opcode, _ in pairs(OPS_WITH_AUX_BYTES) do
	OPS_WITH_AUX[OPCODES[opcode]] = true
end

local CAPTURE_KINDS = {
	[0] = "VAL",
	[1] = "REF",
	[2] = "UPVAL",
	[3] = "UPREF",
}

local LUA_KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["goto"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

-- Lua/Luau standard globals that should not be picked up as phi target names
-- when they appear via GETIMPORT (e.g. `warn(...)` consumes a register, then
-- the same register gets reused for an unrelated local — phi shouldn't
-- propagate "warn" forward and shadow the global function).
local LUA_BUILTIN_GLOBALS = {
	["print"] = true, ["warn"] = true, ["error"] = true, ["assert"] = true,
	["select"] = true, ["pcall"] = true, ["xpcall"] = true, ["pairs"] = true,
	["ipairs"] = true, ["next"] = true, ["unpack"] = true, ["type"] = true,
	["typeof"] = true, ["tostring"] = true, ["tonumber"] = true,
	["rawget"] = true, ["rawset"] = true, ["rawequal"] = true, ["rawlen"] = true,
	["setmetatable"] = true, ["getmetatable"] = true, ["require"] = true,
	["newproxy"] = true, ["getfenv"] = true, ["setfenv"] = true,
	["collectgarbage"] = true, ["gcinfo"] = true, ["loadstring"] = true,
	["math"] = true, ["string"] = true, ["table"] = true, ["coroutine"] = true,
	["os"] = true, ["io"] = true, ["debug"] = true, ["bit32"] = true,
	["utf8"] = true, ["task"] = true, ["buffer"] = true, ["vector"] = true,
	["game"] = true, ["workspace"] = true, ["script"] = true, ["shared"] = true,
	["plugin"] = true, ["_G"] = true, ["_ENV"] = true,
	["Instance"] = true, ["Vector2"] = true, ["Vector3"] = true,
	["CFrame"] = true, ["Color3"] = true, ["UDim"] = true, ["UDim2"] = true,
	["Rect"] = true, ["Region3"] = true, ["Ray"] = true, ["BrickColor"] = true,
	["Enum"] = true, ["NumberRange"] = true, ["NumberSequence"] = true,
	["NumberSequenceKeypoint"] = true, ["ColorSequence"] = true,
	["ColorSequenceKeypoint"] = true, ["TweenInfo"] = true,
	["RaycastParams"] = true, ["PathWaypoint"] = true,
	["PhysicalProperties"] = true, ["Faces"] = true, ["Axes"] = true,
	["DateTime"] = true, ["Random"] = true, ["OverlapParams"] = true,
	["FloatCurveKey"] = true, ["Vector3int16"] = true, ["Vector2int16"] = true,
	["Region3int16"] = true, ["Font"] = true, ["ContentId"] = true,
	["Content"] = true, ["wait"] = true, ["delay"] = true, ["spawn"] = true,
	["tick"] = true, ["time"] = true, ["elapsedTime"] = true,
}

local function push(list, value)
	list[#list + 1] = value
end

local function basename(path)
	local match = string.match(path or "bytecode", "[^/\\]+$")
	return match or path or "bytecode"
end

local function isInteger(x)
	return x == math.floor(x)
end

local function numToString(x)
	if x ~= x or x == math.huge or x == -math.huge then
		return tostring(x)
	end
	if isInteger(x) and math.abs(x) < 1e16 then
		return string.format("%.0f", x)
	end
	-- Try progressively shorter representations; use the shortest that round-trips.
	for _, prec in ipairs({14, 15, 16, 17}) do
		local s = string.format("%." .. tostring(prec) .. "g", x)
		if tonumber(s) == x then
			return s
		end
	end
	return string.format("%.17g", x)
end

local function luaString(s)
	local out = { '"' }
	for i = 1, #s do
		local ch = string.sub(s, i, i)
		local byte = string.byte(s, i)
		if ch == "\\" then
			push(out, "\\\\")
		elseif ch == '"' then
			push(out, '\\"')
		elseif ch == "\n" then
			push(out, "\\n")
		elseif ch == "\r" then
			push(out, "\\r")
		elseif ch == "\t" then
			push(out, "\\t")
		elseif byte < 0x20 or byte == 0x7F then
			push(out, "\\" .. tostring(byte))
		else
			push(out, ch)
		end
	end
	push(out, '"')
	return table.concat(out)
end

local function isValidIdent(s)
	return type(s) == "string"
		and s:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
		and not LUA_KEYWORDS[s]
end

local function cleanIdent(s)
	if type(s) ~= "string" or s == "" then
		return nil
	end
	if isValidIdent(s) then
		return s
	end
	local cleaned = s:gsub("[^A-Za-z0-9_]+", "_"):gsub("_+", "_")
	if cleaned == "" then
		return nil
	end
	if cleaned:match("^%d") then
		cleaned = "_" .. cleaned
	end
	if LUA_KEYWORDS[cleaned] then
		cleaned = "_" .. cleaned
	end
	return cleaned
end

local function cleanGeneratedIdent(s)
	if type(s) ~= "string" or s == "" then
		return nil
	end
	local cleaned = s:gsub("[^A-Za-z0-9_]+", "_"):gsub("_+", "_")
	if cleaned == "" then
		return nil
	end
	if cleaned:match("^%d") then
		cleaned = "_" .. cleaned
	end
	if #cleaned > 48 then
		-- Preserve common semantic suffixes (_result, _result_N, _val, _val_N) so
		-- the downstream rename pass can still recognize them and shorten to short
		-- forms like `r1`, `w1`. Without this, a 60+ char name like
		-- `GetAutoAimTargetRect_result` would truncate to `GetAutoAimTargetRect_res`
		-- which is no longer recognizable as a `_result` pattern.
		local suffix = cleaned:match("(_result_%d+)$") or cleaned:match("(_result)$")
			or cleaned:match("(_val_%d+)$") or cleaned:match("(_val)$")
		if suffix and #suffix < 24 then
			local prefixCap = 48 - #suffix
			local prefix = cleaned:sub(1, #cleaned - #suffix)
			if #prefix > prefixCap then
				prefix = prefix:sub(1, prefixCap):gsub("_$", "")
			end
			cleaned = prefix .. suffix
		else
			cleaned = cleaned:sub(1, 48):gsub("_$", "")
		end
	end
	if LUA_KEYWORDS[cleaned] then
		cleaned = cleaned .. "_value"
	end
	if not isValidIdent(cleaned) then
		return nil
	end
	return cleaned
end

local function deriveNameHint(expr, functionName)
	if type(expr) ~= "string" or expr == "" then
		return nil
	end
	local e = expr:match("^%s*(.-)%s*$")
	if e == "{}" then
		return "state"
	end
	if e:match("^%{.*%}$") and e:find("%f[%a_][A-Z][A-Z0-9_]*%f[^%a_%d]%s*=") then
		return "config"
	end
	if e:match("^setmetatable%s*%(") then
		return functionName == "new" and "self" or "object"
	end
	if e:match("^x?pcall%s*%(") then
		return "pcall_result"
	end
	if e:match("^select%s*%(") then
		return "select_result"
	end
	-- require(...) is a module loader; the result name should come from the
	-- module path, not from any inner :GetService("X") used to build the path.
	-- Match this BEFORE :GetService/:FindFirstChild/etc lookups so wrappers
	-- like `require(game:GetService("ReplicatedStorage").Modules.Foo)` yield
	-- "Foo", not "ReplicatedStorage" or "Modules".
	if e:match("^require%s*%(") then
		local requirePath = nil
		for h in e:gmatch("require%s*%((.+)%)") do
			requirePath = h
		end
		if requirePath then
			-- Try simple trailing identifier first: `require(A.B.C)` → "C".
			local last = requirePath:match("([%a_][%w_]*)%s*$")
			if last and isValidIdent(last) then return last end
			-- Otherwise, find the LAST string argument inside a chained method
			-- call: `require(...:WaitForChild("X"):FindFirstChild("Y"))` → "Y".
			-- Excludes generic builders like :GetService since those name a
			-- service, not the loaded module's name.
			local lastChildName = nil
			for h in requirePath:gmatch(":[A-Za-z_][A-Za-z_0-9]*%s*%(%s*[\"']([^\"']+)[\"']") do
				lastChildName = h
			end
			if lastChildName then
				local cleaned = cleanGeneratedIdent(lastChildName)
				if cleaned then return cleaned end
			end
		end
	end
	local classHint = nil
	for cls in e:gmatch(":FindFirstChildOfClass%s*%(%s*[\"']([^\"']+)[\"']%s*%)%s*$") do
		classHint = cls
	end
	if classHint then
		local cleaned = cleanGeneratedIdent(classHint)
		if cleaned then return "class_" .. cleaned end
	end
	local childHint = nil
	for _, methodName in ipairs({"WaitForChild", "FindFirstChild", "GetChild"}) do
		for h in e:gmatch(":" .. methodName .. "%s*%(%s*[\"']([^\"']+)[\"'][^)]-%)%s*$") do
			childHint = h
		end
	end
	if childHint then return cleanGeneratedIdent(childHint) end
	local serviceHint = nil
	for h in e:gmatch(":GetService%s*%(%s*[\"']([^\"']+)[\"']%s*%)%s*$") do
		serviceHint = h
	end
	if serviceHint then return cleanGeneratedIdent(serviceHint) end
	local attrHint = nil
	for h in e:gmatch(":GetAttribute%s*%(%s*[\"']([^\"']+)[\"']%s*%)%s*$") do
		attrHint = h
	end
	if attrHint then return cleanGeneratedIdent(attrHint) end
	local instanceHint = nil
	for h in e:gmatch("Instance%.new%s*%(%s*[\"']([^\"']+)[\"'][^)]-%)%s*$") do
		instanceHint = h
	end
	if instanceHint then return cleanGeneratedIdent(instanceHint) end
	local requirePath = nil
	for h in e:gmatch("require%s*%(([^%)]+)%)") do
		requirePath = h
	end
	if requirePath then
		local last = requirePath:match("([%a_][%w_]*)%s*$")
		if last and isValidIdent(last) then return last end
	end
	if isValidIdent(e) then
		return e
	end
	if not e:find("%(") and not e:find("%[") and (e:find("%.") or e:find(":")) then
		local last = e:match("([%a_][%w_]*)%s*$")
		if last and isValidIdent(last) then return last end
	end
	-- Chained access after a parenthesized call, e.g. `game:GetService("X").Y`
	-- or `Instance.new("X").Y`. The value is the LAST identifier in the chain
	-- after the closing paren, not anything inside the call.
	if e:find("%)") and e:find("%.") then
		local tail = e:match("%)([^()%[%]]*)$")
		if tail then
			local last = tail:match("%.([%a_][%w_]*)%s*$")
			if last and isValidIdent(last) then return last end
		end
	end
	-- `EXPR:Wait()` (Roblox signal :Wait): derive name from the signal field.
	-- Common idiom: `LocalPlayer.CharacterAdded:Wait()` → "Character".
	-- Generic case: take the last `.IDENT:Wait()` and use IDENT (or its
	-- "value form" mapping for known signals).
	do
		local sigName = e:match("%.([%a_][%w_]*):[Ww]ait%s*%(%s*%)%s*$")
			or e:match("([%a_][%w_]*):[Ww]ait%s*%(%s*%)%s*$")
		if sigName and isValidIdent(sigName) then
			-- Map common Roblox event signals to their typical waited value.
			local sigMap = {
				CharacterAdded = "Character",
				CharacterRemoving = "Character",
				ChildAdded = "Child",
				ChildRemoved = "Child",
				DescendantAdded = "Descendant",
				PlayerAdded = "player",
				PlayerRemoving = "player",
				Touched = "TouchedPart",
				MouseButton1Click = "click",
				Changed = "changedProperty",
				AttributeChanged = "attribute",
				RenderStepped = "deltaTime",
				Heartbeat = "deltaTime",
				Stepped = "deltaTime",
				OnClientEvent = "args",
				OnServerEvent = "args",
				OnInvoke = "args",
			}
			return sigMap[sigName] or sigName
		end
	end
	local method = nil
	for h in e:gmatch("[:%.]([%a_][%w_]*)%s*%(") do
		method = h
	end
	if method and not ({
		GetService = true,
		WaitForChild = true,
		FindFirstChild = true,
		FindFirstChildOfClass = true,
		GetChild = true,
		GetAttribute = true,
		IsA = true,
		Wait = true,
		wait = true,
		lower = true,
		upper = true,
		sub = true,
		find = true,
		gsub = true,
		split = true,
		len = true,
		type = true,
	})[method] then
		return cleanGeneratedIdent(method .. "_result")
	end
	-- For excluded methods (e.g. :FindFirstChild(varExpr) where the arg isn't
	-- a string literal), provide a short generic name based on the method.
	-- This avoids long generated identifiers like
	-- `ReplicatedStorage_FindFirstChild_Sounds_FindFirs` from a deep chain.
	if method then
		local methodMap = {
			FindFirstChild = "child",
			FindFirstChildOfClass = "child",
			WaitForChild = "child",
			GetChild = "child",
			GetService = "service",
			GetAttribute = "attribute",
		}
		local hint = methodMap[method]
		if hint then return hint end
	end
	local bareCall = e:match("^([%a_][%w_]*)%s*%(")
	if bareCall and not ({
		type = true,
		tostring = true,
		tonumber = true,
		print = true,
		warn = true,
		error = true,
		assert = true,
		pairs = true,
		ipairs = true,
		next = true,
		select = true,
		unpack = true,
		pcall = true,
		xpcall = true,
		require = true,
	})[bareCall] then
		return cleanGeneratedIdent(bareCall .. "_result")
	end
	-- tostring(expr) → derive name from inner field access
	if bareCall == "tostring" or bareCall == "tonumber" then
		local tostrArg = e:match("^[%a_][%w_]*%s*%((.+)%)%s*$")
		if tostrArg then
			local inner = tostrArg:match("%.([%a_][%w_]*)%s*$")
			if inner and isValidIdent(inner) then
				local suffix = bareCall == "tostring" and "_str" or "_num"
				return cleanGeneratedIdent(inner .. suffix)
			end
		end
	end
	local idxBase = e:match("^([%a_][%w_]*)%s*%[")
	if idxBase and isValidIdent(idxBase) then
		return idxBase .. "_entry"
	end
	-- obj.Field[key] → Field_entry (dynamic table field index)
	local fieldIdx = e:match("%.([%a_][%w_]*)%s*%[")
	if fieldIdx and isValidIdent(fieldIdx) then
		return fieldIdx .. "_entry"
	end
	return nil
end

local function makeGeneratedNameAllocator(p, params, functionName)
	local used = {}
	local function mark(name)
		if type(name) == "string" and isValidIdent(name) then
			used[name] = true
		end
	end
	mark(functionName)
	for _, name in ipairs(params or {}) do mark(name) end
	for _, name in ipairs(p.upvalues or {}) do mark(name) end
	for _, lv in ipairs(p.locvars or {}) do mark(lv.name) end
	return function(hint, fallback)
		local base = cleanGeneratedIdent(hint) or cleanGeneratedIdent(fallback) or "result"
		if not used[base] then
			used[base] = true
			return base
		end
		local suffix = 2
		while used[base .. "_" .. tostring(suffix)] do
			suffix = suffix + 1
		end
		local name = base .. "_" .. tostring(suffix)
		used[name] = true
		return name
	end
end

local function genericLoopVarNames(base, nvars)
	local names = {}
	if nvars == 2 then
		names[1] = "_k" .. tostring(base + 3)
		names[2] = "_v" .. tostring(base + 4)
	elseif nvars == 1 then
		names[1] = "_v" .. tostring(base + 3)
	else
		for n = 1, nvars do
			names[n] = "_v" .. tostring(base + 2 + n)
		end
	end
	return names
end

local function luaIndexSuffix(key)
	if type(key) == "string" then
		if isValidIdent(key) then
			return "." .. key
		end
		return "[" .. luaString(key) .. "]"
	end
	return "[" .. tostring(key) .. "]"
end

local function simpleExpressionReceiver(expr)
	if type(expr) ~= "string" or expr == "" then return false end
	local first, nextPos = expr:match("^([%a_][%a_%d]*)()")
	if not first then return false end
	while nextPos <= #expr do
		local sep = expr:sub(nextPos, nextPos)
		if sep == "." then
			local part, np = expr:match("^%.([%a_][%a_%d]*)()", nextPos)
			if not part then return false end
			nextPos = np
		elseif sep == "[" then
			local depth = 1
			local inString = nil
			local i = nextPos + 1
			while i <= #expr do
				local ch = expr:sub(i, i)
				if inString then
					if ch == "\\" then
						i = i + 2
					elseif ch == inString then
						inString = nil
						i = i + 1
					else
						i = i + 1
					end
				else
					if ch == "\"" or ch == "'" then
						inString = ch
					elseif ch == "[" then
						depth = depth + 1
					elseif ch == "]" then
						depth = depth - 1
						if depth == 0 then
							nextPos = i + 1
							break
						end
					end
					i = i + 1
				end
			end
			if depth ~= 0 then return false end
		else
			return false
		end
	end
	return true
end

local function decodeFloat32(bits)
	local sign = bit32_band(bits, 0x80000000) ~= 0 and -1 or 1
	local exponent = bit32_rshift(bit32_band(bits, 0x7F800000), 23)
	local mantissa = bit32_band(bits, 0x007FFFFF)
	if exponent == 0xFF then
		if mantissa == 0 then
			return sign * math.huge
		end
		return 0 / 0
	end
	if exponent == 0 then
		if mantissa == 0 then
			return sign * 0
		end
		return sign * ((mantissa / 8388608) * (2 ^ -126))
	end
	return sign * ((1 + mantissa / 8388608) * (2 ^ (exponent - 127)))
end

local function decodeFloat64(low, high)
	local sign = high >= 0x80000000 and -1 or 1
	local exponent = bit32_rshift(bit32_band(high, 0x7FF00000), 20)
	local mantissaHigh = bit32_band(high, 0x000FFFFF)
	local mantissa = mantissaHigh * 4294967296 + low
	if exponent == 0x7FF then
		if mantissa == 0 then
			return sign * math.huge
		end
		return 0 / 0
	end
	if exponent == 0 then
		if mantissa == 0 then
			return sign * 0
		end
		return sign * ((mantissa / 4503599627370496) * (2 ^ -1022))
	end
	return sign * ((1 + mantissa / 4503599627370496) * (2 ^ (exponent - 1023)))
end

local Reader = {}
Reader.__index = Reader

function Reader.new(data)
	return setmetatable({
		data = data,
		pos = 1,
		len = #data,
	}, Reader)
end

function Reader:remaining()
	return self.len - self.pos + 1
end

function Reader:u8()
	local value = string.byte(self.data, self.pos, self.pos)
	if value == nil then
		error("Unexpected end of bytecode")
	end
	self.pos = self.pos + 1
	return value
end

function Reader:bytes(n)
	local value = string.sub(self.data, self.pos, self.pos + n - 1)
	if #value ~= n then
		error("Unexpected end of bytecode")
	end
	self.pos = self.pos + n
	return value
end

function Reader:u32()
	if string.unpack then
		local value
		value, self.pos = string.unpack("<I4", self.data, self.pos)
		return value
	end
	local b1, b2, b3, b4 = string.byte(self.data, self.pos, self.pos + 3)
	if b4 == nil then
		error("Unexpected end of bytecode")
	end
	self.pos = self.pos + 4
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

function Reader:i32()
	local value = self:u32()
	if value >= 2147483648 then
		value = value - 4294967296
	end
	return value
end

function Reader:f32()
	if string.unpack then
		local value
		value, self.pos = string.unpack("<f", self.data, self.pos)
		return value
	end
	return decodeFloat32(self:u32())
end

function Reader:f64()
	if string.unpack then
		local value
		value, self.pos = string.unpack("<d", self.data, self.pos)
		return value
	end
	local low = self:u32()
	local high = self:u32()
	return decodeFloat64(low, high)
end

function Reader:varint()
	local result = 0
	local shift = 0
	while true do
		local b = self:u8()
		result = result + bit32.lshift(bit32_band(b, 0x7F), shift)
		if bit32_band(b, 0x80) == 0 then
			break
		end
		shift = shift + 7
	end
	return result
end

function Reader:varint64()
	local result = 0
	local shift = 0
	while true do
		local b = self:u8()
		result = result + (bit32_band(b, 0x7F) * (2 ^ shift))
		if bit32_band(b, 0x80) == 0 then
			break
		end
		shift = shift + 7
	end
	return result
end

function Reader:stringRef(strings)
	local idx = self:varint()
	if idx == 0 then
		return ""
	end
	return strings[idx] or ""
end

local function newConstant(kind, value)
	return {
		kind = kind,
		value = value,
	}
end

local function newLocVar(name, startpc, endpc, reg)
	return {
		name = name,
		startpc = startpc,
		endpc = endpc,
		reg = reg,
	}
end

local function newProto()
	return {
		maxstacksize = 0,
		numparams = 0,
		nups = 0,
		is_vararg = false,
		flags = 0,
		code = {},
		constants = {},
		child_proto_ids = {},
		linedefined = 0,
		debugname = "",
		lineinfo = {},
		abslineinfo = {},
		linegaplog2 = 0,
		locvars = {},
		upvalues = {},
	}
end

local function newBytecode(raw)
	return {
		version = 0,
		typesversion = 0,
		strings = {},
		protos = {},
		main_id = 0,
		raw = raw,
	}
end

local function codeWordAt(p, pc)
	return p.code[pc + 1]
end

local function constantAt(p, idx)
	return p.constants[idx + 1]
end

local function childProtoIdAt(p, idx)
	return p.child_proto_ids[idx + 1]
end

local function protoAt(bc, idx)
	return bc.protos[idx + 1]
end

local function decodeSignedD(insn)
	local d = bit32_band(bit32_rshift(insn, 16), 0xFFFF)
	if d >= 0x8000 then
		d = d - 0x10000
	end
	return d
end

local function decodeSignedE(insn)
	local e = bit32_band(bit32_rshift(insn, 8), 0xFFFFFF)
	if e >= 0x800000 then
		e = e - 0x1000000
	end
	return e
end

local function getOpLength(opName)
	return OPS_WITH_AUX[opName] and 2 or 1
end

local function parseProto(r, bc)
	local p = newProto()
	p.maxstacksize = r:u8()
	p.numparams = r:u8()
	p.nups = r:u8()
	p.is_vararg = r:u8() ~= 0

	if bc.version >= 4 then
		p.flags = r:u8()
		if bc.typesversion == 1 or bc.typesversion == 2 or bc.typesversion == 3 then
			local typesize = r:varint()
			if typesize ~= 0 then
				r:bytes(typesize)
			end
		end
	end

	local sizecode = r:varint()
	for _ = 1, sizecode do
		push(p.code, r:u32())
	end

	local sizek = r:varint()
	for _ = 1, sizek do
		local ktype = r:u8()
		if ktype == LBC_CONSTANT_NIL then
			push(p.constants, newConstant("nil", nil))
		elseif ktype == LBC_CONSTANT_BOOLEAN then
			push(p.constants, newConstant("bool", r:u8() ~= 0))
		elseif ktype == LBC_CONSTANT_NUMBER then
			push(p.constants, newConstant("number", r:f64()))
		elseif ktype == LBC_CONSTANT_STRING then
			local sidx = r:varint()
			push(p.constants, newConstant("string", sidx > 0 and (bc.strings[sidx] or "") or ""))
		elseif ktype == LBC_CONSTANT_IMPORT then
			push(p.constants, newConstant("import", r:u32()))
		elseif ktype == LBC_CONSTANT_TABLE then
			local keys = r:varint()
			local values = {}
			for _k = 1, keys do
				push(values, r:varint())
			end
			push(p.constants, newConstant("table", values))
		elseif ktype == LBC_CONSTANT_CLOSURE then
			push(p.constants, newConstant("closure", r:varint()))
		elseif ktype == LBC_CONSTANT_VECTOR then
			push(p.constants, newConstant("vector", { r:f32(), r:f32(), r:f32(), r:f32() }))
		elseif ktype == LBC_CONSTANT_TABLE_WITH_CONSTANTS then
			local keys = r:varint()
			local pairs = {}
			for _k = 1, keys do
				push(pairs, {
					k_idx = r:varint(),
					v_idx = r:i32(),
				})
			end
			push(p.constants, newConstant("table_kv", pairs))
		elseif ktype == LBC_CONSTANT_INTEGER then
			local neg = r:u8()
			local magnitude = r:varint64()
			push(p.constants, newConstant("integer", neg ~= 0 and -magnitude or magnitude))
		else
			error("Unknown constant kind: " .. tostring(ktype))
		end
	end

	local sizep = r:varint()
	for _ = 1, sizep do
		push(p.child_proto_ids, r:varint())
	end

	p.linedefined = r:varint()
	p.debugname = r:stringRef(bc.strings)

	if r:u8() ~= 0 then
		p.linegaplog2 = r:u8()
		local intervals = sizecode > 0 and (bit32_rshift(sizecode - 1, p.linegaplog2) + 1) or 0
		local last = 0
		for _ = 1, sizecode do
			last = (last + r:u8()) % 256
			push(p.lineinfo, last)
		end
		local lastLine = 0
		for _ = 1, intervals do
			lastLine = lastLine + r:i32()
			push(p.abslineinfo, lastLine)
		end
	end

	if r:u8() ~= 0 then
		local sizelocvars = r:varint()
		for _ = 1, sizelocvars do
			push(p.locvars, newLocVar(
				r:stringRef(bc.strings),
				r:varint(),
				r:varint(),
				r:u8()
			))
		end
		local sizeupvalues = r:varint()
		for _ = 1, sizeupvalues do
			push(p.upvalues, r:stringRef(bc.strings))
		end
	end

	-- [P3] Build reg -> {locvars} index for O(log n) lookup in locvarAt.
	local byReg = {}
	for _, lv in ipairs(p.locvars) do
		local list = byReg[lv.reg]
		if not list then list = {}; byReg[lv.reg] = list end
		list[#list + 1] = lv
	end
	p.locvarsByReg = byReg

	return p
end

local function parseBytecode(data)
	-- [R2] Returns (bc, nil) on success, (nil, err_string) on failure.
	-- Previously threw; callers via Module.tryDecompile would get a
	-- raw error string but no way to distinguish parse failures from
	-- invalid input.
	local r_ok, r = pcall(Reader.new, data)
	if not r_ok then
		return nil, "Failed to create bytecode reader: " .. tostring(r)
	end
	local bc = newBytecode(data)

	local v_ok, version = pcall(function() return r:u8() end)
	if not v_ok then
		return nil, "Truncated bytecode (could not read version byte): " .. tostring(version)
	end
	bc.version = version

	if bc.version == 0 then
		local msg = string.sub(data, r.pos)
		return nil, "Bytecode contains compiler error: " .. msg
	end
	if bc.version < LBC_VERSION_MIN or bc.version > LBC_VERSION_MAX then
		return nil, "Unsupported bytecode version " .. tostring(bc.version)
			.. " (expected " .. tostring(LBC_VERSION_MIN) .. ".." .. tostring(LBC_VERSION_MAX) .. ")"
	end

	if bc.version >= 4 then
		bc.typesversion = r:u8()
	end

	local stringCount = r:varint()
	for _ = 1, stringCount do
		local length = r:varint()
		push(bc.strings, r:bytes(length))
	end

	if bc.typesversion == 3 then
		local idx = r:u8()
		while idx ~= 0 do
			r:stringRef(bc.strings)
			idx = r:u8()
		end
	end

	local protoCount = r:varint()
	for _ = 1, protoCount do
		local p_ok, proto = pcall(parseProto, r, bc)
		if not p_ok then
			-- One bad proto is fatal to the parse, but we report cleanly.
			return nil, "Failed to parse proto #" .. (#bc.protos + 1) .. ": " .. tostring(proto)
		end
		push(bc.protos, proto)
	end

	bc.main_id = r:varint()
	return bc
end

local function decodeImportId(iid, p)
	local count = bit32_band(bit32_rshift(iid, 30), 0x3)
	local rawIdx = {}
	if count >= 1 then
		push(rawIdx, bit32_band(bit32_rshift(iid, 20), 0x3FF))
	end
	if count >= 2 then
		push(rawIdx, bit32_band(bit32_rshift(iid, 10), 0x3FF))
	end
	if count >= 3 then
		push(rawIdx, bit32_band(iid, 0x3FF))
	end

	local parts = {}
	for _, ki in ipairs(rawIdx) do
		local c = constantAt(p, ki)
		if c and c.kind == "string" then
			push(parts, c.value)
		else
			push(parts, "k[" .. tostring(ki) .. "]")
		end
	end
	return parts, rawIdx
end

local function formatConstant(c, p)
	if c.kind == "nil" then
		return "nil"
	end
	if c.kind == "bool" then
		return c.value and "true" or "false"
	end
	if c.kind == "number" then
		return numToString(c.value)
	end
	if c.kind == "integer" then
		return tostring(c.value)
	end
	if c.kind == "string" then
		return luaString(c.value)
	end
	if c.kind == "vector" then
		local x, y, z, w = c.value[1], c.value[2], c.value[3], c.value[4]
		local text = "Vector3.new(" .. numToString(x) .. ", " .. numToString(y) .. ", " .. numToString(z) .. ")"
		if w and w ~= 0 then
			text = text .. " --[[w=" .. numToString(w) .. "]]"
		end
		return text
	end
	if c.kind == "import" then
		local parts = decodeImportId(c.value, p)
		local resolved = parts
		if #resolved > 0 then
			return table.concat(resolved, ".")
		end
		return "import(" .. string.format("0x%08x", c.value) .. ")"
	end
	if c.kind == "table" then
		return "{}"
	end
	if c.kind == "table_kv" then
		local parts = {}
		for _, pair in ipairs(c.value) do
			local keyConst = constantAt(p, pair.k_idx)
			local keyString
			if keyConst and keyConst.kind == "string" and isValidIdent(keyConst.value) then
				keyString = keyConst.value
			else
				keyString = "[" .. (keyConst and formatConstant(keyConst, p) or ("K[" .. tostring(pair.k_idx) .. "]")) .. "]"
			end
			local valueConst = constantAt(p, pair.v_idx)
			local valueString = valueConst and formatConstant(valueConst, p) or "nil"
			push(parts, keyString .. " = " .. valueString)
		end
		if #parts == 0 then
			return "{}"
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	if c.kind == "closure" then
		return "<closure proto[" .. tostring(c.value) .. "]>"
	end
	return "<" .. tostring(c.kind) .. ">"
end

local function kvalLua(p, idx)
	local c = constantAt(p, idx)
	if not c then
		return "K[" .. tostring(idx) .. "]"
	end
	return formatConstant(c, p)
end

local function locvarAt(p, reg, pc)
	-- [P3] Prefer the reg->list index built at parse time. Falls back to
	-- linear scan if the index is missing (e.g. proto built by external code).
	local byReg = p.locvarsByReg
	if byReg then
		local list = byReg[reg]
		if not list then return nil end
		local best = nil
		for _, lv in ipairs(list) do
			if lv.startpc <= pc and pc <= lv.endpc then
				if best == nil or lv.startpc >= best.startpc then
					best = lv
				end
			end
		end
		return best
	end
	local best = nil
	for _, lv in ipairs(p.locvars) do
		if lv.reg == reg and isValidIdent(lv.name) and lv.startpc <= pc and pc <= lv.endpc then
			if best == nil or lv.startpc >= best.startpc then
				best = lv
			end
		end
	end
	return best
end

local function localAt(p, reg, pc)
	local lv = locvarAt(p, reg, pc)
	return lv and lv.name or nil
end

local function generatedFallbackLocalName(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	return name:match("^_r%d+_?%d*$") ~= nil
		or name:match("^_flag%d+[_%d]*$") ~= nil
		or name:match("^[%a_][%w_]*_result_%d+$") ~= nil
		or name:match("^[%a_][%w_]*_result$") ~= nil
		or name:match("^[%a_][%w_]*_value_%d+$") ~= nil
		or name:match("^[%a_][%w_]*_value$") ~= nil
		or name:match("^[%a_][%w_]*_entry_%d+$") ~= nil
		or name:match("^[%a_][%w_]*_entry$") ~= nil
end

local function preferredTrackedLocalName(tracked, locvarName)
	if type(tracked) ~= "string"
		or tracked == ""
		or type(locvarName) ~= "string"
		or locvarName == ""
		or tracked == locvarName
		or not isValidIdent(tracked)
	then
		return nil
	end
	if tracked:match("^R%d+$")
		or tracked:match("^%-?%d+%.?%d*$")
		or tracked:match("^%-?%.%d+$")
		or tracked == "true"
		or tracked == "false"
		or tracked == "nil"
		or tracked:sub(1, 1) == '"'
		or tracked:sub(1, 1) == "'"
	then
		return nil
	end
	if generatedFallbackLocalName(locvarName)
		or tracked:match("^" .. luaPE(locvarName) .. "_%d+$")
	then
		return tracked
	end
	return nil
end

local function regRepr(regs, p, reg, pc)
	local lv = locvarAt(p, reg, pc)
	if lv then
		local tracked = regs[reg]
		local preferredTracked = preferredTrackedLocalName(tracked, lv.name)
		if preferredTracked then
			return preferredTracked
		end
		if lv.startpc ~= pc then
			return lv.name
		end
	end
	return regs[reg] or ("R" .. tostring(reg))
end

local function formatHex32(value)
	return string.format("0x%08X", value)
end

local function formatDisasm(pc, opName, a, b, c, d, e, aux, p)
	local function kfmt(idx)
		return kvalLua(p, idx)
	end

	if opName == "LOADK" or opName == "LOADKC" or opName == "LOADKX" then
		local idx = opName == "LOADKC" and c or (opName == "LOADK" and d or aux)
		return opName .. " R" .. tostring(a) .. ", " .. kfmt(idx)
	end
	if opName == "GETIMPORT" then
		local parts = decodeImportId(aux or 0, p)
		local resolved = parts
		return opName .. " R" .. tostring(a) .. ", " .. (#resolved > 0 and table.concat(resolved, ".") or ("import(" .. tostring(d) .. ")"))
	end
	if opName == "GETUPVAL" then
		local name = p.upvalues[b + 1] or ("U" .. tostring(b))
		return opName .. " R" .. tostring(a) .. ", " .. name
	end
	if opName == "SETUPVAL" then
		local name = p.upvalues[b + 1] or ("U" .. tostring(b))
		return opName .. " " .. name .. ", R" .. tostring(a)
	end
	if opName == "GETTABLEKS" or opName == "SETTABLEKS" then
		local idx = aux ~= nil and aux or d
		local keyConst = constantAt(p, idx)
		local key = keyConst and keyConst.kind == "string" and keyConst.value or ("K[" .. tostring(idx) .. "]")
		return opName .. " A=" .. tostring(a) .. " B=" .. tostring(b) .. " KEY=" .. tostring(key)
	end
	if opName == "CALL" then
		return opName .. " A=" .. tostring(a) .. " args=" .. tostring(b) .. " rets=" .. tostring(c)
	end
	if opName == "RETURN" then
		return opName .. " A=" .. tostring(a) .. " count=" .. tostring(b)
	end
	if opName == "JUMP" or opName == "JUMPBACK" then
		return opName .. " -> pc" .. tostring(pc + d + 1)
	end
	if opName == "JUMPIF" or opName == "JUMPIFNOT" then
		return opName .. " R" .. tostring(a) .. " -> pc" .. tostring(pc + d + 1)
	end
	if opName == "NEWCLOSURE" then
		local childId = childProtoIdAt(p, d)
		return opName .. " R" .. tostring(a) .. ", proto[" .. tostring(childId or "?") .. "]"
	end
	if opName == "DUPCLOSURE" then
		return opName .. " R" .. tostring(a) .. ", K[" .. tostring(d) .. "]"
	end

	local parts = {
		"A=" .. tostring(a),
		"B=" .. tostring(b),
		"C=" .. tostring(c),
		"D=" .. tostring(d),
		"E=" .. tostring(e),
	}
	if aux ~= nil then
		push(parts, "AUX=" .. formatHex32(aux))
	end
	local dConst = constantAt(p, d)
	if dConst then
		push(parts, "K[D]=" .. formatConstant(dConst, p))
	end
	return opName .. " " .. table.concat(parts, " ")
end

local function disassembleProto(p, bc, protoIdx)
	local out = {}
	local name = p.debugname ~= "" and p.debugname or ("<anon#" .. tostring(protoIdx) .. ">")
	local tags = {}
	if protoIdx == bc.main_id then
		push(tags, "MAIN")
	end
	if p.is_vararg then
		push(tags, "vararg")
	end
	local tagString = #tags > 0 and (" [" .. table.concat(tags, ", ") .. "]") or ""
	push(out, "-- proto[" .. tostring(protoIdx) .. "] " .. name .. tagString .. " (params=" .. tostring(p.numparams) .. ", upvalues=" .. tostring(p.nups) .. ", maxstack=" .. tostring(p.maxstacksize) .. ", line=" .. tostring(p.linedefined) .. ")")

	if #p.upvalues > 0 then
		push(out, "-- upvalues:")
		for i, u in ipairs(p.upvalues) do
			push(out, "--   U" .. tostring(i - 1) .. " = " .. u)
		end
	end

	if #p.locvars > 0 then
		push(out, "-- local variables:")
		for _, lv in ipairs(p.locvars) do
			push(out, "--   R" .. tostring(lv.reg) .. " " .. lv.name .. " (pc " .. tostring(lv.startpc) .. ".." .. tostring(lv.endpc) .. ")")
		end
	end

	if #p.constants > 0 then
		push(out, "-- constants:")
		for i, c in ipairs(p.constants) do
			push(out, "--   K" .. tostring(i - 1) .. " = " .. formatConstant(c, p))
		end
	end

	if #p.child_proto_ids > 0 then
		local ids = {}
		for _, childId in ipairs(p.child_proto_ids) do
			push(ids, tostring(childId))
		end
		push(out, "-- child protos: {" .. table.concat(ids, ", ") .. "}")
	end

	push(out, "-- code:")
	local pc = 0
	local codeLen = #p.code
	while pc < codeLen do
		local insn = codeWordAt(p, pc)
		local op = bit32_band(insn, 0xFF)
		local opName = OPCODES[op] or ("ROBLOX_OP_" .. tostring(op))
		local a = bit32_band(bit32_rshift(insn, 8), 0xFF)
		local b = bit32_band(bit32_rshift(insn, 16), 0xFF)
		local c = bit32_band(bit32_rshift(insn, 24), 0xFF)
		local d = decodeSignedD(insn)
		local e = decodeSignedE(insn)
		local aux = nil
		if OPS_WITH_AUX[opName] and pc + 1 < codeLen then
			aux = codeWordAt(p, pc + 1)
		end
		local line = formatDisasm(pc, opName, a, b, c, d, e, aux, p)
		local endMarker = pc + getOpLength(opName) == codeLen and "  <-- end of proto" or ""
		push(out, string.format("  [%04d] %s  %s%s", pc, formatHex32(insn), line, endMarker))
		pc = pc + getOpLength(opName)
	end

	return table.concat(out, "\n")
end

local function scanJumpTargets(p)
	local targets = {}
	local pc = 0
	local codeLen = #p.code
	while pc < codeLen do
		local insn = codeWordAt(p, pc)
		local op = bit32_band(insn, 0xFF)
		local opName = OPCODES[op] or ""
		if opName == "JUMPIF" or opName == "JUMPIFNOT" then
			targets[pc + bit32_band(bit32_rshift(insn, 16), 0xFF) + 1] = true
		elseif opName == "JUMP"
			or opName == "JUMPBACK"
			or opName == "JUMPIFEQ"
			or opName == "JUMPIFLE"
			or opName == "JUMPIFLT"
			or opName == "JUMPIFNOTEQ"
			or opName == "JUMPIFNOTLE"
			or opName == "JUMPIFNOTLT"
			or opName == "JUMPXLEKN"
			or opName == "JUMPXEQKNIL"
			or opName == "JUMPXEQKB"
			or opName == "JUMPXEQKN"
			or opName == "JUMPXEQKS"
			or opName == "FORNPREP"
			or opName == "FORNLOOP"
			or opName == "FORGPREP"
			or opName == "FORGPREP_INEXT"
			or opName == "FORGPREP_NEXT"
			or opName == "FORGLOOP"
		then
			targets[pc + decodeSignedD(insn) + 1] = true
		elseif opName == "JUMPX" then
			targets[pc + decodeSignedE(insn) + 1] = true
		elseif opName == "LOADB" then
			local skip = bit32_band(bit32_rshift(insn, 24), 0xFF)
			if skip ~= 0 then
				targets[pc + skip + 1] = true
			end
		elseif opName == "FASTCALL"
			or opName == "FASTCALL1"
			or opName == "FASTCALL2"
			or opName == "FASTCALL2K"
			or opName == "FASTCALL3"
		then
			local jump = bit32_band(bit32_rshift(insn, 24), 0xFF)
			if jump ~= 0 then
				targets[pc + jump + 1] = true
			end
		end
		pc = pc + (opName ~= "" and getOpLength(opName) or 1)
	end
	return targets
end

local function decodedInsnAt(p, pc)
	-- [P2] Per-proto decode cache. Avoids allocating a fresh 9-field table
	-- on every call (this function is invoked 60+ times, often inside tight
	-- scan loops). Cache is lazily built on first access and reused for all
	-- subsequent calls on the same proto.
	local cache = p._decodedCache
	if not cache then
		cache = {}
		p._decodedCache = cache
	end
	local cached = cache[pc]
	if cached then
		return cached
	end
	local insn = codeWordAt(p, pc)
	-- [R3] Bounds-safe placeholder for out-of-range pc. Downstream code
	-- used to do bit32.band(nil, 0xFF) which throws opaquely.
	if type(insn) ~= "number" then
		local placeholder = {
			pc = pc,
			insn = 0,
			opName = "[[INVALID_PC]]",
			a = 0, b = 0, c = 0, d = 0, e = 0,
			aux = nil,
			len = 1,
			_invalid = true,
		}
		cache[pc] = placeholder
		return placeholder
	end
	local op = bit32_band(insn, 0xFF)
	local opName = OPCODES[op] or ("ROBLOX_OP_" .. tostring(op))
	local aux = nil
	if OPS_WITH_AUX[opName] and pc + 1 < #p.code then
		aux = codeWordAt(p, pc + 1)
	end
	local info = {
		pc = pc,
		insn = insn,
		opName = opName,
		a = bit32_band(bit32_rshift(insn, 8), 0xFF),
		b = bit32_band(bit32_rshift(insn, 16), 0xFF),
		c = bit32_band(bit32_rshift(insn, 24), 0xFF),
		d = decodeSignedD(insn),
		e = decodeSignedE(insn),
		aux = aux,
		len = getOpLength(opName),
	}
	cache[pc] = info
	return info
end

local function jumpTargetForInsn(info)
	local opName = info.opName
	if opName == "JUMPIF" or opName == "JUMPIFNOT" then
		return info.pc + info.d + 1
	end
	if opName == "JUMP"
		or opName == "JUMPBACK"
		or opName == "JUMPIFEQ"
		or opName == "JUMPIFLE"
		or opName == "JUMPIFLT"
		or opName == "JUMPIFNOTEQ"
		or opName == "JUMPIFNOTLE"
		or opName == "JUMPIFNOTLT"
		or opName == "JUMPXLEKN"
		or opName == "JUMPXEQKNIL"
		or opName == "JUMPXEQKB"
		or opName == "JUMPXEQKN"
		or opName == "JUMPXEQKS"
		or opName == "FORNPREP"
		or opName == "FORNLOOP"
		or opName == "FORGPREP"
		or opName == "FORGPREP_INEXT"
		or opName == "FORGPREP_NEXT"
		or opName == "FORGLOOP"
	then
		return info.pc + info.d + 1
	end
	if opName == "JUMPX" then
		return info.pc + info.e + 1
	end
	if opName == "LOADB" and info.c ~= 0 then
		return info.pc + info.c + 1
	end
	if opName == "FASTCALL"
		or opName == "FASTCALL1"
		or opName == "FASTCALL2"
		or opName == "FASTCALL2K"
		or opName == "FASTCALL3"
	then
		if info.c ~= 0 then
			return info.pc + info.c + 1
		end
	end
	return nil
end

local function isConditionalBranch(opName)
	return opName == "JUMPIF"
		or opName == "JUMPIFNOT"
		or opName == "JUMPIFEQ"
		or opName == "JUMPIFLE"
		or opName == "JUMPIFLT"
		or opName == "JUMPIFNOTEQ"
		or opName == "JUMPIFNOTLE"
		or opName == "JUMPIFNOTLT"
		or opName == "JUMPXLEKN"
		or opName == "JUMPXEQKNIL"
		or opName == "JUMPXEQKB"
		or opName == "JUMPXEQKN"
		or opName == "JUMPXEQKS"
end

local function isUnconditionalBranch(opName)
	return opName == "JUMP" or opName == "JUMPBACK" or opName == "JUMPX"
end

local function isReturnInsn(opName)
	return opName == "RETURN"
end

local function setEquals(a, b)
	for k in pairs(a or {}) do
		if not b or not b[k] then return false end
	end
	for k in pairs(b or {}) do
		if not a or not a[k] then return false end
	end
	return true
end

local function copySet(s)
	local out = {}
	for k in pairs(s or {}) do out[k] = true end
	return out
end

local function intersectSets(a, b)
	local out = {}
	for k in pairs(a or {}) do
		if b and b[k] then out[k] = true end
	end
	return out
end

local function reachableBlockSet(blocks, starts, edgeField)
	local out = {}
	local work = {}
	for _, id in ipairs(starts or {}) do
		if blocks[id] then work[#work+1] = id end
	end
	while #work > 0 do
		local id = table.remove(work)
		if not out[id] then
			out[id] = true
			local block = blocks[id]
			for _, nextId in ipairs(block and block[edgeField] or {}) do
				if not out[nextId] then work[#work+1] = nextId end
			end
		end
	end
	return out
end

local function computeDominators(blocks, entryId, reachable)
	local allReachable = copySet(reachable)
	local dom = {}
	for _, block in ipairs(blocks or {}) do
		dom[block.id] = reachable[block.id] and copySet(allReachable) or {}
	end
	if blocks[entryId] then
		dom[entryId] = { [entryId] = true }
	end
	local changed = true
	while changed do
		changed = false
		for _, block in ipairs(blocks or {}) do
			local id = block.id
			if reachable[id] and id ~= entryId then
				local newSet = copySet(allReachable)
				local sawPred = false
				for _, predId in ipairs(block.predecessors or {}) do
					if reachable[predId] then
						newSet = sawPred and intersectSets(newSet, dom[predId]) or copySet(dom[predId])
						sawPred = true
					end
				end
				if not sawPred then newSet = {} end
				newSet[id] = true
				if not setEquals(newSet, dom[id]) then
					dom[id] = newSet
					changed = true
				end
			end
		end
	end
	return dom
end

local function computePostdominators(blocks, reachable)
	local allReachable = copySet(reachable)
	local postdom = {}
	for _, block in ipairs(blocks or {}) do
		postdom[block.id] = reachable[block.id] and copySet(allReachable) or {}
	end
	local changed = true
	while changed do
		changed = false
		for _, block in ipairs(blocks or {}) do
			local id = block.id
			if reachable[id] then
				local newSet = nil
				local sawSucc = false
				for _, succId in ipairs(block.successors or {}) do
					if reachable[succId] then
						newSet = sawSucc and intersectSets(newSet, postdom[succId]) or copySet(postdom[succId])
						sawSucc = true
					end
				end
				if not sawSucc then newSet = {} end
				newSet[id] = true
				if not setEquals(newSet, postdom[id]) then
					postdom[id] = newSet
					changed = true
				end
			end
		end
	end
	return postdom
end

local function findBackEdges(blocks, dominators)
	local edges = {}
	for _, block in ipairs(blocks or {}) do
		for _, succId in ipairs(block.successors or {}) do
			if dominators[block.id] and dominators[block.id][succId] then
				edges[#edges+1] = { from = block.id, to = succId }
			end
		end
	end
	return edges
end

local function buildCFG(p)
	local leaders = { [0] = true }
	local instructions = {}
	local pc = 0
	while pc < #p.code do
		local info = decodedInsnAt(p, pc)
		instructions[pc] = info
		local nextPc = pc + info.len
		local target = jumpTargetForInsn(info)
		if target and target >= 0 and target < #p.code then
			leaders[target] = true
		end
		if nextPc < #p.code and (target or isReturnInsn(info.opName)) then
			leaders[nextPc] = true
		end
		pc = nextPc
	end
	local starts = {}
	for start in pairs(leaders) do
		if start >= 0 and start < #p.code then
			starts[#starts+1] = start
		end
	end
	table.sort(starts)
	local blocks = {}
	local pcToBlock = {}
	for idx, start in ipairs(starts) do
		local nextStart = starts[idx + 1] or #p.code
		local lastPc = start
		local cursor = start
		while cursor < nextStart do
			lastPc = cursor
			local info = instructions[cursor] or decodedInsnAt(p, cursor)
			cursor = cursor + info.len
		end
		local block = { id = idx, startPc = start, endPc = nextStart, lastPc = lastPc, successors = {}, predecessors = {} }
		blocks[#blocks+1] = block
		local mapPc = start
		while mapPc < nextStart do
			pcToBlock[mapPc] = block
			local info = instructions[mapPc] or decodedInsnAt(p, mapPc)
			mapPc = mapPc + info.len
		end
	end
	local function addEdge(fromBlock, toPc)
		local toBlock = pcToBlock[toPc]
		if not fromBlock or not toBlock then return end
		for _, existing in ipairs(fromBlock.successors) do
			if existing == toBlock.id then return end
		end
		fromBlock.successors[#fromBlock.successors+1] = toBlock.id
		toBlock.predecessors[#toBlock.predecessors+1] = fromBlock.id
	end
	for _, block in ipairs(blocks) do
		local info = instructions[block.lastPc] or decodedInsnAt(p, block.lastPc)
		local nextPc = block.endPc
		local target = jumpTargetForInsn(info)
		if target then
			addEdge(block, target)
		end
		if nextPc < #p.code and not isUnconditionalBranch(info.opName) and not isReturnInsn(info.opName) then
			addEdge(block, nextPc)
		end
	end
	local cfg = {
		blocks = blocks,
		pcToBlock = pcToBlock,
		instructions = instructions,
	}
	cfg.reachable = reachableBlockSet(blocks, { 1 }, "successors")
	cfg.dominators = computeDominators(blocks, 1, cfg.reachable)
	cfg.postdominators = computePostdominators(blocks, cfg.reachable)
	cfg.backEdges = findBackEdges(blocks, cfg.dominators)
	return cfg
end

local function instrReadsReg(info, reg)
	local opName = info.opName
	local a, b, c = info.a, info.b, info.c
	if opName == "MOVE" then return b == reg end
	if opName == "GETTABLE" then return b == reg or c == reg end
	if opName == "SETTABLE" then return a == reg or b == reg or c == reg end
	if opName == "GETTABLEKS" or opName == "GETTABLEN" or opName == "NAMECALL" then return b == reg end
	if opName == "SETTABLEKS" or opName == "SETTABLEN" then return a == reg or b == reg end
	if opName == "CALL" then
		if a == reg then return true end
		local argEnd = b == 0 and (a + 8) or (a + b - 1)
		return reg >= a + 1 and reg <= argEnd
	end
	if opName == "RETURN" then
		if b == 0 then return reg >= a end
		return reg >= a and reg <= a + b - 2
	end
	if opName == "JUMPIF" or opName == "JUMPIFNOT" then return a == reg end
	if opName == "JUMPIFEQ"
		or opName == "JUMPIFLE"
		or opName == "JUMPIFLT"
		or opName == "JUMPIFNOTEQ"
		or opName == "JUMPIFNOTLE"
		or opName == "JUMPIFNOTLT"
	then
		local rb = bit32_band(info.aux or 0, 0x7FFFFFFF)
		return a == reg or rb == reg
	end
	if isConditionalBranch(opName) then return a == reg or b == reg end
	if opName == "ADD" or opName == "SUB" or opName == "MUL" or opName == "DIV" or opName == "MOD" or opName == "POW" or opName == "IDIV" then
		return b == reg or c == reg
	end
	if opName == "ADDK" or opName == "SUBK" or opName == "MULK" or opName == "DIVK" or opName == "MODK" or opName == "POWK" or opName == "IDIVK" or opName == "ORK" or opName == "ANDK" then
		return b == reg
	end
	if opName == "SUBRK" or opName == "DIVRK" then return b == reg end
	if opName == "OR" or opName == "AND" then return b == reg or c == reg end
	if opName == "MINUS" or opName == "NOT" or opName == "LENGTH" then return b == reg end
	if opName == "CONCAT" then return reg >= b and reg <= c end
	if opName == "SETUPVAL" or opName == "SETGLOBAL" then return a == reg end
	if opName == "CAPTURE" then return b == reg end
	return false
end

-- [P1] Hoisted out of instrWritesReg: avoid re-allocating a 40-entry table
-- on every call. Module-level so it is shared by all invocations.
local WRITE_REG_OPS = {
	LOADB = true, LOADN = true, LOADK = true, LOADKC = true, LOADKX = true,
	MOVE = true, GETIMPORT = true, GETUPVAL = true, GETGLOBAL = true,
	GETTABLE = true, GETTABLEKS = true, GETTABLEN = true, NEWTABLE = true,
	DUPTABLE = true, NEWCLOSURE = true, DUPCLOSURE = true, ADD = true,
	SUB = true, MUL = true, DIV = true, MOD = true, POW = true, IDIV = true,
	ADDK = true, SUBK = true, MULK = true, DIVK = true, MODK = true,
	POWK = true, IDIVK = true, SUBRK = true, DIVRK = true, ORK = true,
	ANDK = true, OR = true, AND = true, MINUS = true, NOT = true,
	LENGTH = true, CONCAT = true,
}

local function instrWritesReg(info, reg)
	local opName = info.opName
	local a = info.a
	if opName == "CALL" then
		if info.c == 1 then return false end
		if info.c == 0 then return reg >= a end
		return reg >= a and reg <= a + info.c - 2
	end
	if opName == "NAMECALL" then return reg == a or reg == a + 1 end
	if opName == "LOADNIL" then return reg == a end
	return reg == a and WRITE_REG_OPS[opName] == true
end

local function regReadBeforeWrite(p, reg, startPc, maxPc)
	local pc = startPc
	while pc < #p.code and pc <= maxPc do
		local info = decodedInsnAt(p, pc)
		if instrReadsReg(info, reg) then
			return true
		end
		if instrWritesReg(info, reg) then
			return false
		end
		pc = pc + info.len
	end
	return false
end

local function analyzeProtoFlow(p, bc)
	local cfg = buildCFG(p)
	local analysis = {
		cfg = cfg,
		callResultHints = {},
		moveAliasHints = {},
		nilPhiHints = {},
		booleanFlagHints = {},
		valuePhiHints = {},
		branchValueHints = { initializers = {}, moves = {}, breaks = {} },
		concatPhiHints = {},
		orDefaultHints = { jumps = {}, fallbacks = {}, uses = {} },
		counterHints = { initializers = {}, increments = {} },
		backEdgeMutationHints = {},
		staleSnapshotHints = {},
		regVersionsByPc = {},
		regWrites = {},
		regWritesByBlock = {},
		phiCandidates = {},
		guardedCallCount = 0,
		aliasHintCount = 0,
		orDefaultHintCount = 0,
		counterHintCount = 0,
		nilPhiHintCount = 0,
		branchMergeCount = 0,
		phiCandidateCount = 0,
		phiLocvarHintCount = 0,
		callInlineHints = {},
	}
	local regs = {}
	local regNames = {}
	local regVersions = {}
	local usedAnalysisNames = {}
	local maxReg = math.max((p.maxstacksize or 0) - 1, p.numparams or 0)
	local function markAnalysisName(name)
		if type(name) == "string" and isValidIdent(name) then
			usedAnalysisNames[name] = true
		end
	end
	local function noteRead(pc, reg)
		local bucket = analysis.regVersionsByPc[pc]
		if not bucket then
			bucket = { reads = {}, writes = {} }
			analysis.regVersionsByPc[pc] = bucket
		end
		bucket.reads[#bucket.reads+1] = {
			reg = reg,
			version = regVersions[reg] or 0,
			expr = regs[reg],
			name = regNames[reg],
		}
	end
	local function noteInstructionReads(info)
		for reg = 0, maxReg do
			if instrReadsReg(info, reg) then
				noteRead(info.pc, reg)
			end
		end
	end
	local function uniqueAnalysisName(name, reg)
		if type(name) ~= "string" or name == "" or not isValidIdent(name) then
			return name
		end
		local function conflicts(candidate)
			return usedAnalysisNames[candidate] == true and regNames[reg] ~= candidate
		end
		if not conflicts(name) then
			return name
		end
		local suffix = 2
		while conflicts(name .. "_" .. tostring(suffix)) do
			suffix = suffix + 1
		end
		return name .. "_" .. tostring(suffix)
	end
	local function writeReg(pc, reg, expr, name, opName, sourceReg, sourceName)
		regVersions[reg] = (regVersions[reg] or 0) + 1
		regs[reg] = expr
		regNames[reg] = name or (isValidIdent(expr) and expr or nil)
		markAnalysisName(regNames[reg])
		local entry = {
			pc = pc,
			reg = reg,
			version = regVersions[reg],
			ssa = "R" .. tostring(reg) .. "_" .. tostring(regVersions[reg]),
			expr = expr,
			name = regNames[reg],
			opName = opName,
			sourceReg = sourceReg,
			sourceName = sourceName,
		}
		local block = cfg.pcToBlock and cfg.pcToBlock[pc] or nil
		if block then
			entry.blockId = block.id
			analysis.regWritesByBlock[block.id] = analysis.regWritesByBlock[block.id] or {}
			analysis.regWritesByBlock[block.id][#analysis.regWritesByBlock[block.id]+1] = entry
		end
		local bucket = analysis.regVersionsByPc[pc]
		if not bucket then
			bucket = { reads = {}, writes = {} }
			analysis.regVersionsByPc[pc] = bucket
		end
		bucket.writes[#bucket.writes+1] = entry
		analysis.regWrites[reg] = analysis.regWrites[reg] or {}
		analysis.regWrites[reg][#analysis.regWrites[reg]+1] = entry
		return entry
	end
	for i = 0, p.numparams - 1 do
		regs[i] = localAt(p, i, 0) or ("arg" .. tostring(i))
		regNames[i] = regs[i]
		markAnalysisName(regNames[i])
		regVersions[i] = 0
	end
	local pc = 0
	while pc < #p.code do
		local info = decodedInsnAt(p, pc)
		local opName = info.opName
		local a, b, c, d, aux = info.a, info.b, info.c, info.d, info.aux
		noteInstructionReads(info)
		if opName == "MOVE" then
			local srcExpr = regs[b] or ("R" .. tostring(b))
			local srcName = regNames[b] or (isValidIdent(srcExpr) and srcExpr or nil)
			writeReg(pc, a, srcExpr, srcName, opName, b, srcName)
		elseif opName == "GETTABLEKS" then
			local keyConst = constantAt(p, aux ~= nil and aux or d)
			local key = keyConst and keyConst.kind == "string" and keyConst.value or nil
			local expr = (regs[b] or ("R" .. tostring(b))) .. (key and luaIndexSuffix(key) or "")
			writeReg(pc, a, expr, localAt(p, a, pc), opName)
		elseif opName == "GETTABLE" then
			local expr = (regs[b] or ("R" .. tostring(b))) .. "[" .. (regs[c] or ("R" .. tostring(c))) .. "]"
			writeReg(pc, a, expr, localAt(p, a, pc), opName)
		elseif opName == "GETTABLEN" then
			local expr = (regs[b] or ("R" .. tostring(b))) .. "[" .. tostring(c + 1) .. "]"
			writeReg(pc, a, expr, localAt(p, a, pc), opName)
		elseif opName == "NAMECALL" then
			local keyConst = aux ~= nil and constantAt(p, aux) or nil
			local key = keyConst and keyConst.kind == "string" and keyConst.value or nil
			local receiver = regs[b] or ("R" .. tostring(b))
			writeReg(pc, a, receiver .. ":" .. tostring(key or "?"), nil, opName)
			writeReg(pc, a + 1, receiver, regNames[b], opName, b, regNames[b])
		elseif opName == "CALL" then
			local callee = regs[a] or ("R" .. tostring(a))
			local args = {}
			if b ~= 0 then
				for reg = a + 1, a + b - 1 do
					args[#args+1] = regs[reg] or ("R" .. tostring(reg))
				end
				if callee:find(":", 1, true) and #args > 0 then
					table.remove(args, 1)
				end
			end
			local callExpr = callee .. "(" .. table.concat(args, ", ") .. ")"
			if c ~= 1 then
				local nextPc = pc + info.len
				local nextInfo = nextPc < #p.code and decodedInsnAt(p, nextPc) or nil
				local target = nextInfo and jumpTargetForInsn(nextInfo) or nil
				if nextInfo and (nextInfo.opName == "JUMPIF" or nextInfo.opName == "JUMPIFNOT") and nextInfo.a == a and target then
					local usedAfterGuard = regReadBeforeWrite(p, a, target, math.min(#p.code - 1, target + 80))
					if usedAfterGuard then
						local hint = deriveNameHint(callExpr)
						local name = localAt(p, a, pc + 1) or cleanGeneratedIdent(hint)
						if name and isValidIdent(name) then
							analysis.callResultHints[pc] = name
						else
							analysis.callResultHints[pc] = true
						end
						analysis.guardedCallCount = analysis.guardedCallCount + 1
					end
				end
				local primaryName = localAt(p, a, pc + 1) or cleanGeneratedIdent(deriveNameHint(callExpr)) or ("_r" .. tostring(a))
				primaryName = uniqueAnalysisName(primaryName, a)
				writeReg(pc, a, primaryName, isValidIdent(primaryName) and primaryName or nil, opName)
				if c > 2 then
					for reg = a + 1, a + c - 2 do
						local name = localAt(p, reg, pc + 1) or ("_r" .. tostring(reg))
						name = uniqueAnalysisName(name, reg)
						writeReg(pc, reg, name, isValidIdent(name) and name or nil, opName)
					end
				end
			end
		elseif opName == "LOADNIL" then
			writeReg(pc, a, "nil", nil, opName)
		elseif opName == "LOADB" then
			writeReg(pc, a, b ~= 0 and "true" or "false", nil, opName)
		elseif opName == "LOADN" then
			writeReg(pc, a, tostring(d), nil, opName)
		elseif opName == "LOADK" or opName == "LOADKC" or opName == "LOADKX" then
			local idx = opName == "LOADKC" and c or (opName == "LOADK" and d or aux)
			writeReg(pc, a, kvalLua(p, idx), localAt(p, a, pc), opName)
		elseif opName == "GETIMPORT" then
			local parts = decodeImportId(aux or 0, p)
			local expr = #parts > 0 and table.concat(parts, ".") or nil
			writeReg(pc, a, expr or ("R" .. tostring(a)), localAt(p, a, pc), opName)
		elseif opName == "GETUPVAL" then
			local expr = p.upvalues[b + 1] or ("U" .. tostring(b))
			writeReg(pc, a, expr, isValidIdent(expr) and expr or localAt(p, a, pc), opName)
		elseif opName == "GETGLOBAL" then
			local keyConst = aux ~= nil and constantAt(p, aux) or nil
			local expr = keyConst and keyConst.value or ("K[" .. tostring(aux) .. "]")
			writeReg(pc, a, expr, isValidIdent(expr) and expr or localAt(p, a, pc), opName)
		elseif opName == "NEWTABLE" then
			writeReg(pc, a, "{}", localAt(p, a, pc), opName)
		elseif opName == "DUPTABLE" then
			writeReg(pc, a, kvalLua(p, d), localAt(p, a, pc), opName)
		elseif opName == "FORNPREP" then
			local loopName = localAt(p, a + 2, pc + 1) or "_i"
			loopName = uniqueAnalysisName(loopName, a + 2)
			writeReg(pc, a + 2, loopName, loopName, opName)
		elseif opName == "CONCAT" then
			local parts = {}
			for reg = b, c do
				parts[#parts + 1] = regs[reg] or ("R" .. tostring(reg))
			end
			writeReg(pc, a, table.concat(parts, " .. "), nil, opName)
		elseif opName == "ADD" or opName == "SUB" or opName == "MUL" or opName == "DIV" or opName == "MOD" or opName == "POW" or opName == "IDIV" then
			local symbols = {
				ADD = "+",
				SUB = "-",
				MUL = "*",
				DIV = "/",
				MOD = "%",
				POW = "^",
				IDIV = "//",
			}
			writeReg(pc, a, "(" .. (regs[b] or ("R" .. tostring(b))) .. " " .. symbols[opName] .. " " .. (regs[c] or ("R" .. tostring(c))) .. ")", nil, opName, b, regNames[b])
		elseif opName == "AND" or opName == "OR" then
			local symbol = opName == "AND" and "and" or "or"
			writeReg(pc, a, "(" .. (regs[b] or ("R" .. tostring(b))) .. " " .. symbol .. " " .. (regs[c] or ("R" .. tostring(c))) .. ")", nil, opName, b, regNames[b])
		elseif opName == "ANDK" or opName == "ORK" then
			local symbol = opName == "ANDK" and "and" or "or"
			writeReg(pc, a, "(" .. (regs[b] or ("R" .. tostring(b))) .. " " .. symbol .. " " .. kvalLua(p, c) .. ")", nil, opName, b, regNames[b])
		elseif opName == "NOT" then
			writeReg(pc, a, "(not " .. (regs[b] or ("R" .. tostring(b))) .. ")", nil, opName, b, regNames[b])
		elseif opName == "MINUS" then
			writeReg(pc, a, "(-" .. (regs[b] or ("R" .. tostring(b))) .. ")", nil, opName, b, regNames[b])
		elseif opName == "LENGTH" then
			writeReg(pc, a, "(#" .. (regs[b] or ("R" .. tostring(b))) .. ")", nil, opName, b, regNames[b])
		elseif opName == "SUBRK" or opName == "DIVRK" then
			local symbol = opName == "SUBRK" and "-" or "/"
			writeReg(pc, a, "(" .. kvalLua(p, b) .. " " .. symbol .. " " .. (regs[c] or ("R" .. tostring(c))) .. ")", nil, opName, c, regNames[c])
		elseif opName == "ADDK" or opName == "SUBK" or opName == "MULK" or opName == "DIVK" or opName == "MODK" or opName == "POWK" or opName == "IDIVK" then
			local symbols = {
				ADDK = "+",
				SUBK = "-",
				MULK = "*",
				DIVK = "/",
				MODK = "%",
				POWK = "^",
				IDIVK = "//",
			}
			local constExpr = kvalLua(p, c)
			local entry = writeReg(pc, a, "(" .. (regs[b] or ("R" .. tostring(b))) .. " " .. symbols[opName] .. " " .. constExpr .. ")", nil, opName, b, regNames[b])
			entry.constExpr = constExpr
		end
		pc = pc + info.len
	end
	local function lastWriteBefore(reg, beforePc)
		local writes = analysis.regWrites[reg] or {}
		for i = #writes, 1, -1 do
			if writes[i].pc < beforePc then
				return writes[i]
			end
		end
		return nil
	end
	local function firstWriteBetween(reg, startPc, endPc)
		local writes = analysis.regWrites[reg] or {}
		for _, write in ipairs(writes) do
			if write.pc >= startPc and write.pc < endPc then
				return write
			end
		end
		return nil
	end
	local function lastWriteBetween(reg, startPc, endPc)
		local writes = analysis.regWrites[reg] or {}
		for i = #writes, 1, -1 do
			local write = writes[i]
			if write.pc >= startPc and write.pc < endPc then
				return write
			end
		end
		return nil
	end
	local function firstWriteBefore(reg, beforePc, opName, expr)
		local writes = analysis.regWrites[reg] or {}
		for _, write in ipairs(writes) do
			if write.pc < beforePc
				and (not opName or write.opName == opName)
				and (not expr or write.expr == expr)
			then
				return write
			end
		end
		return nil
	end
	local function hasSelfIncrementBefore(reg, beforePc)
		local writes = analysis.regWrites[reg] or {}
		for _, write in ipairs(writes) do
			if write.pc < beforePc
				and write.opName == "ADDK"
				and write.sourceReg == reg
				and write.constExpr == "1"
			then
				return true
			end
		end
		return false
	end
	local function cleanCounterLabel(label)
		if type(label) ~= "string" then return nil end
		local cleaned = label:gsub(":%s*$", "")
		cleaned = cleaned:match(".*:%s*(.+)$") or cleaned
		cleaned = cleanGeneratedIdent(cleaned)
		if cleaned and isValidIdent(cleaned) then return cleaned end
		return nil
	end
	local function firstReadBeforeWrite(reg, startPc, maxPc)
		local scanPc = startPc
		while scanPc < #p.code and scanPc <= maxPc do
			local scanInfo = decodedInsnAt(p, scanPc)
			if instrReadsReg(scanInfo, reg) then
				return scanPc, scanInfo
			end
			if instrWritesReg(scanInfo, reg) then
				return nil, nil
			end
			scanPc = scanPc + scanInfo.len
		end
		return nil, nil
	end
	local function onlyFallbackWriteBetween(startPc, endPc, fallbackPc)
		local scanPc = startPc
		local seenFallback = false
		while scanPc < #p.code and scanPc < endPc do
			local scanInfo = decodedInsnAt(p, scanPc)
			if scanPc == fallbackPc then
				seenFallback = true
			else
				return false
			end
			scanPc = scanPc + scanInfo.len
		end
		return seenFallback
	end
	local function jumpActsAsLoopBreak(jumpPc, mergePc)
		local jumpBlock = cfg.pcToBlock and cfg.pcToBlock[jumpPc] or nil
		if not jumpBlock then return false end
		for _, edge in ipairs(cfg.backEdges or {}) do
			local head = cfg.blocks and cfg.blocks[edge.to] or nil
			local tail = cfg.blocks and cfg.blocks[edge.from] or nil
			if head and tail
				and head.startPc <= jumpPc
				and jumpPc <= tail.lastPc
				and mergePc > tail.lastPc
			then
				return true
			end
		end
		return false
	end
	local function isConditionalJumpOp(opName)
		return opName == "JUMPIF"
			or opName == "JUMPIFNOT"
			or opName == "JUMPIFEQ"
			or opName == "JUMPIFLE"
			or opName == "JUMPIFLT"
			or opName == "JUMPIFNOTEQ"
			or opName == "JUMPIFNOTLE"
			or opName == "JUMPIFNOTLT"
			or opName == "JUMPXLEKN"
			or opName == "JUMPXEQKNIL"
			or opName == "JUMPXEQKB"
			or opName == "JUMPXEQKN"
			or opName == "JUMPXEQKS"
	end
	local function stableGeneratedTempName(reg, prefix)
		local base = (type(prefix) == "string" and prefix ~= "" and prefix or "_value") .. tostring(reg)
		if isValidIdent(base) then return base end
		return "_value_" .. tostring(reg)
	end
	local function isParamName(name)
		if type(name) ~= "string" then return false end
		for i = 0, p.numparams - 1 do
			if name == (localAt(p, i, 0) or ("arg" .. tostring(i))) then
				return true
			end
		end
		return false
	end
	local function isNilPhiValueWrite(write)
		if not write then return false end
		return write.opName ~= "LOADNIL"
			and write.opName ~= "GETUPVAL"
			and write.opName ~= "LOADB"
			and write.opName ~= "LOADN"
			and write.opName ~= "LOADK"
			and write.opName ~= "LOADKC"
			and write.opName ~= "LOADKX"
			-- A NAMECALL writes the self-slot R[a+1] with the receiver's value;
			-- the slot is consumed by the immediately following CALL, so it
			-- isn't a real assignment to a logical variable. Treat as non-value
			-- to avoid leaking the receiver's name into a phi target.
			and write.opName ~= "NAMECALL"
	end
	local function nilPhiCandidateName(write)
		if not isNilPhiValueWrite(write) then return nil end
		local sourceName = write.sourceName or write.name
		if sourceName and isValidIdent(sourceName) and not isParamName(sourceName) and sourceName ~= "nil" then
			if write.opName ~= "MOVE" then
				return sourceName
			end
			local sourceWrite = write.sourceReg and lastWriteBefore(write.sourceReg, write.pc) or nil
			if isNilPhiValueWrite(sourceWrite) then
				return sourceName
			end
		end
		local hint = (write.opName == "GETTABLE" or write.opName == "GETTABLEKS") and nil or deriveNameHint(write.expr)
		if hint and isValidIdent(hint) and not isParamName(hint) and hint ~= "nil" then
			return hint
		end
		return nil
	end
	local function nilPhiTargetName(reg, firstWrite, writes)
		local firstName = nilPhiCandidateName(firstWrite)
		if firstName then return firstName end
		for _, write in ipairs(writes or {}) do
			local name = nilPhiCandidateName(write)
			if name then return name end
		end
		return stableGeneratedTempName(reg, "_value_")
	end
	local function isSimpleValuePhiWrite(write)
		if not write then return false end
		return write.opName == "MOVE"
			or write.opName == "GETTABLE"
			or write.opName == "GETTABLEKS"
			or write.opName == "GETTABLEN"
			or write.opName == "LOADK"
			or write.opName == "LOADN"
			or write.opName == "LOADB"
	end
	local function isGeneratedPhiName(name)
		if type(name) ~= "string" or name == "" then return false end
		return name:match("^_r%d+_?%d*$") ~= nil
			or name:match("^_flag%d+[_%d]*$") ~= nil
			or name:match("^[%a_][%w_]*_result_%d+$") ~= nil
			or name:match("^[%a_][%w_]*_result$") ~= nil
			or name:match("^[%a_][%w_]*_value_%d+$") ~= nil
			or name:match("^[%a_][%w_]*_value$") ~= nil
			or name:match("^[%a_][%w_]*_entry_%d+$") ~= nil
			or name:match("^[%a_][%w_]*_entry$") ~= nil
	end
	local function valuePhiTargetName(reg, mergePc, ...)
		local candidates = { localAt(p, reg, mergePc) }
		local writesArr = { ... }
		for _, write in ipairs(writesArr) do
			if write then
				-- A NAMECALL writes both R[a] (the function/method ref) and
				-- R[a+1] (the self/receiver). The name attached to the self-slot
				-- write is the receiver's name (e.g., "game" when calling
				-- `game:GetService("Players")`), but that slot is consumed by the
				-- immediately following CALL — it does NOT represent a real
				-- assignment to a logical variable. If a later LOADNIL/MOVE
				-- reuses the same slot, the phi shouldn't pick up the receiver
				-- name. Exclude such writes from name candidates.
				if write.opName ~= "NAMECALL" then
					candidates[#candidates+1] = write.sourceName
					candidates[#candidates+1] = write.name
				end
				candidates[#candidates+1] = localAt(p, reg, write.pc)
			end
		end
		for _, candidate in ipairs(candidates) do
			if candidate
				and isValidIdent(candidate)
				and not candidate:match("^R%d+$")
				and not isParamName(candidate)
				and not isGeneratedPhiName(candidate)
				and not LUA_BUILTIN_GLOBALS[candidate]
			then
				return candidate
			end
		end
		for _, candidate in ipairs(candidates) do
			if candidate
				and isValidIdent(candidate)
				and not candidate:match("^R%d+$")
				and not isParamName(candidate)
				and not LUA_BUILTIN_GLOBALS[candidate]
			then
				return candidate
			end
		end
		return stableGeneratedTempName(reg, "_value_")
	end
	local function branchValueTargetName(reg, write, mergePc)
		local sourceName = write and write.sourceName or nil
		local candidates = {
			localAt(p, reg, mergePc),
			localAt(p, reg, write and write.pc or mergePc),
			write and write.name or nil,
		}
		for _, candidate in ipairs(candidates) do
			if candidate
				and isValidIdent(candidate)
				and not candidate:match("^R%d+$")
				and candidate ~= sourceName
				and not LUA_BUILTIN_GLOBALS[candidate]
			then
				return candidate
			end
		end
		return stableGeneratedTempName(reg, "_r")
	end
	local function targetDeclaredBefore(name, beforePc)
		for _, writes in pairs(analysis.regWrites) do
			for _, write in ipairs(writes) do
				if write.pc < beforePc and (write.name == name or write.expr == name) then
					return true
				end
			end
		end
		for _, lv in ipairs(p.locvars or {}) do
			if lv.name == name and lv.startpc <= beforePc and beforePc <= lv.endpc + 1 then
				return true
			end
		end
		return false
	end
	local nilPhiSeen = {}
	local function addNilPhiHintsForWrites(reg, mergePc, branchWrites)
		local key = tostring(reg) .. ":" .. tostring(mergePc)
		if nilPhiSeen[key] then return end
		local hasValue = false
		local hasNil = false
		for _, candidate in ipairs(branchWrites or {}) do
			if isNilPhiValueWrite(candidate) then hasValue = true end
			if candidate.opName == "LOADNIL" then hasNil = true end
		end
		local targetName = hasValue and hasNil and nilPhiTargetName(reg, branchWrites and branchWrites[1], branchWrites) or nil
		if targetName then
			nilPhiSeen[key] = true
			analysis.nilPhiHintCount = analysis.nilPhiHintCount + 1
			local firstPc = nil
			for _, candidate in ipairs(branchWrites) do
				if not firstPc or candidate.pc < firstPc then
					firstPc = candidate.pc
				end
			end
			local declareAtFirst = firstPc and not targetDeclaredBefore(targetName, firstPc)
			for _, candidate in ipairs(branchWrites) do
				analysis.nilPhiHints[candidate.pc] = {
					reg = reg,
					targetName = targetName,
					mergePc = mergePc,
					declare = declareAtFirst and candidate.pc == firstPc,
				}
			end
		end
	end
	for reg, writes in pairs(analysis.regWrites) do
		for _, write in ipairs(writes) do
			if isNilPhiValueWrite(write) then
				local writeInfo = cfg.instructions and cfg.instructions[write.pc] or nil
				local nextPc = writeInfo and (write.pc + writeInfo.len) or nil
				local nextInfo = nextPc and ((cfg.instructions and cfg.instructions[nextPc]) or decodedInsnAt(p, nextPc)) or nil
				local jumpGuardPc = nextInfo and nextInfo.opName == "JUMP" and jumpTargetForInsn(nextInfo) or nil
				local jumpGuardInfo = jumpGuardPc and jumpGuardPc < #p.code and ((cfg.instructions and cfg.instructions[jumpGuardPc]) or decodedInsnAt(p, jumpGuardPc)) or nil
				local skippedNilPc = nextPc and nextInfo and (nextPc + nextInfo.len) or nil
				local skippedNilWrite = jumpGuardPc and skippedNilPc and firstWriteBetween(reg, skippedNilPc, jumpGuardPc) or nil
				if jumpGuardPc
					and jumpGuardPc > nextPc
					and jumpGuardInfo
					and (jumpGuardInfo.opName == "JUMPIF" or jumpGuardInfo.opName == "JUMPIFNOT")
					and jumpGuardInfo.a == reg
					and skippedNilPc
					and skippedNilPc < jumpGuardPc
					and skippedNilWrite
					and skippedNilWrite.pc == skippedNilPc
					and skippedNilWrite.opName == "LOADNIL"
					and regReadBeforeWrite(p, reg, jumpGuardPc, #p.code - 1)
				then
					local branchWrites = {}
					local initWrite = lastWriteBefore(reg, write.pc)
					if initWrite
						and initWrite.opName == "LOADNIL"
						and not firstWriteBetween(reg, initWrite.pc + 1, write.pc)
					then
						branchWrites[#branchWrites+1] = initWrite
					end
					branchWrites[#branchWrites+1] = write
					branchWrites[#branchWrites+1] = skippedNilWrite
					addNilPhiHintsForWrites(reg, jumpGuardPc, branchWrites)
				end
				local mergePc = nextInfo and nextInfo.opName == "JUMP" and jumpTargetForInsn(nextInfo) or nil
				if mergePc and mergePc > nextPc and regReadBeforeWrite(p, reg, mergePc, #p.code - 1) then
					local branchWrites = {}
					local initWrite = lastWriteBefore(reg, write.pc)
					if initWrite
						and initWrite.opName == "LOADNIL"
						and not firstWriteBetween(reg, initWrite.pc + 1, write.pc)
					then
						branchWrites[#branchWrites+1] = initWrite
					end
					for _, candidate in ipairs(writes) do
						if candidate.pc >= write.pc and candidate.pc < mergePc and (isNilPhiValueWrite(candidate) or candidate.opName == "LOADNIL") then
							branchWrites[#branchWrites+1] = candidate
						end
					end
					addNilPhiHintsForWrites(reg, mergePc, branchWrites)
				elseif nextInfo and nextInfo.opName == "JUMPIF" and nextInfo.a == reg then
					mergePc = jumpTargetForInsn(nextInfo)
					local fallbackWrite = mergePc and firstWriteBetween(reg, nextPc + nextInfo.len, mergePc) or nil
					if mergePc
						and mergePc > nextPc
						and fallbackWrite
						and fallbackWrite.opName == "LOADNIL"
						and onlyFallbackWriteBetween(nextPc + nextInfo.len, mergePc, fallbackWrite.pc)
						and regReadBeforeWrite(p, reg, mergePc, #p.code - 1)
					then
						local branchWrites = {}
						local initWrite = lastWriteBefore(reg, write.pc)
						if initWrite
							and initWrite.opName == "LOADNIL"
							and not firstWriteBetween(reg, initWrite.pc + 1, write.pc)
						then
							branchWrites[#branchWrites+1] = initWrite
						end
						branchWrites[#branchWrites+1] = write
						branchWrites[#branchWrites+1] = fallbackWrite
						addNilPhiHintsForWrites(reg, mergePc, branchWrites)
					end
				end
			end
		end
	end
	local branchValueSeen = {}
	for reg, writes in pairs(analysis.regWrites) do
		for _, write in ipairs(writes) do
			if write.opName == "MOVE" and type(write.sourceReg) == "number" and write.sourceReg ~= reg then
				local writeInfo = cfg.instructions and cfg.instructions[write.pc] or nil
				local nextPc = writeInfo and (write.pc + writeInfo.len) or nil
				local nextInfo = nextPc and cfg.instructions and cfg.instructions[nextPc] or nil
				local mergePc = nextInfo and nextInfo.opName == "JUMP" and jumpTargetForInsn(nextInfo) or nil
				local initWrite = lastWriteBefore(reg, write.pc)
				if initWrite
					and initWrite.opName == "LOADNIL"
					and mergePc
					and nextPc
					and mergePc > nextPc
					and not firstWriteBetween(reg, initWrite.pc + 1, write.pc)
					and not firstWriteBetween(reg, nextPc + nextInfo.len, mergePc)
					and regReadBeforeWrite(p, reg, mergePc, #p.code - 1)
				then
					local targetName = branchValueTargetName(reg, write, mergePc)
					if targetName and isValidIdent(targetName) then
						local key = tostring(reg) .. ":" .. tostring(initWrite.pc) .. ":" .. tostring(write.pc) .. ":" .. tostring(mergePc)
						if not branchValueSeen[key] then
							branchValueSeen[key] = true
							analysis.branchValueHints.initializers[initWrite.pc] = {
								reg = reg,
								targetName = targetName,
								mergePc = mergePc,
							}
							analysis.branchValueHints.moves[write.pc] = {
								reg = reg,
								targetName = targetName,
								sourceReg = write.sourceReg,
								mergePc = mergePc,
							}
							if jumpActsAsLoopBreak(nextPc, mergePc) then
								analysis.branchValueHints.breaks[nextPc] = {
									reg = reg,
									targetName = targetName,
									mergePc = mergePc,
								}
							end
						end
					end
				end
			end
		end
	end
	local booleanFlagSeen = {}
	for reg, writes in pairs(analysis.regWrites) do
		for idx = 1, #writes - 1 do
			local write = writes[idx]
			local nextWrite = writes[idx + 1]
			local writeInfo = write and cfg.instructions and cfg.instructions[write.pc] or nil
			local nextInfo = nextWrite and cfg.instructions and cfg.instructions[nextWrite.pc] or nil
			-- Treat the pair as a real phi candidate only when the FIRST LOADB's
			-- result is NOT consumed before the second LOADB rewrites the same
			-- register.  Otherwise we are looking at two independent sequential
			-- `Field = false` / `Field = true` assignments that happen to reuse
			-- the same scratch register (e.g.
			--     LOADB R6 = false; SETTABLEKS R5.CanCollide = R6;
			--     LOADB R6 = false; SETTABLEKS R5.CastShadow = R6;
			-- ), in which case we must NOT promote them to a `_flag<N>` local
			-- since the original source wrote each as `T.X = false` directly.
			local readBetween = write and nextWrite and writeInfo
				and regReadBeforeWrite(p, reg, write.pc + writeInfo.len, nextWrite.pc - 1)
			if write
				and nextWrite
				and write.opName == "LOADB"
				and nextWrite.opName == "LOADB"
				and nextInfo
				and not readBetween
				and regReadBeforeWrite(p, reg, nextWrite.pc + nextInfo.len, #p.code - 1)
			then
				local targetName = localAt(p, reg, nextWrite.pc) or localAt(p, reg, write.pc) or stableGeneratedTempName(reg, "_flag")
				if not isValidIdent(targetName) or targetName == "true" or targetName == "false" or targetName:match("^_r%d+[_%d]*$") then
					targetName = stableGeneratedTempName(reg, "_flag")
				end
				local key = tostring(reg) .. ":" .. tostring(write.pc) .. ":" .. tostring(nextWrite.pc)
				if not booleanFlagSeen[key] then
					booleanFlagSeen[key] = true
					analysis.booleanFlagHints[write.pc] = {
						reg = reg,
						targetName = targetName,
						declare = true,
					}
					analysis.booleanFlagHints[nextWrite.pc] = {
						reg = reg,
						targetName = targetName,
						declare = false,
					}
				end
			end
		end
	end
	for pcKey, info in pairs(cfg.instructions) do
		if (info.opName == "JUMPIF" or info.opName == "JUMPIFNOT") then
			local target = jumpTargetForInsn(info)
			if target and target > info.pc then
				local preWrite = lastWriteBefore(info.a, info.pc)
				local fallbackWrite = firstWriteBetween(info.a, info.pc + info.len, target)
				if preWrite
					and fallbackWrite
					and preWrite.opName == "MOVE"
					and fallbackWrite.opName == "MOVE"
					and preWrite.sourceName
					and fallbackWrite.sourceName
					and preWrite.sourceName ~= fallbackWrite.sourceName
					and isValidIdent(preWrite.sourceName)
					and isValidIdent(fallbackWrite.sourceName)
					and regReadBeforeWrite(p, info.a, target, math.min(#p.code - 1, target + 80))
				then
					analysis.moveAliasHints[preWrite.pc] = {
						targetName = fallbackWrite.sourceName,
						sourceName = preWrite.sourceName,
						guardPc = pcKey,
					}
					analysis.aliasHintCount = analysis.aliasHintCount + 1
				end
				if preWrite
					and fallbackWrite
					and preWrite.opName == "CALL"
					and preWrite.name
					and isValidIdent(preWrite.name)
					and fallbackWrite.opName == "MOVE"
					and fallbackWrite.sourceName
					and isValidIdent(fallbackWrite.sourceName)
					and fallbackWrite.sourceName ~= preWrite.name
					and regReadBeforeWrite(p, info.a, target, math.min(#p.code - 1, target + 80))
				then
					analysis.moveAliasHints[fallbackWrite.pc] = {
						targetName = preWrite.name,
						sourceName = fallbackWrite.sourceName,
						guardPc = pcKey,
					}
					analysis.aliasHintCount = analysis.aliasHintCount + 1
				end
				if info.opName == "JUMPIF"
					and preWrite
					and fallbackWrite
					and preWrite.expr
					and fallbackWrite.expr
					and (preWrite.opName == "MOVE" or preWrite.opName == "GETTABLEKS"
						or preWrite.opName == "GETTABLE" or preWrite.opName == "GETTABLEN"
						or preWrite.opName == "GETIMPORT" or preWrite.opName == "GETUPVAL"
						or preWrite.opName == "GETGLOBAL")
					and (fallbackWrite.opName == "NEWTABLE" or fallbackWrite.opName == "DUPTABLE"
						or fallbackWrite.opName == "GETTABLEKS" or fallbackWrite.opName == "GETTABLE"
						or fallbackWrite.opName == "GETTABLEN" or fallbackWrite.opName == "GETIMPORT"
						or fallbackWrite.opName == "GETUPVAL" or fallbackWrite.opName == "GETGLOBAL"
						or fallbackWrite.opName == "MOVE" or fallbackWrite.opName == "LOADK"
						or fallbackWrite.opName == "LOADN" or fallbackWrite.opName == "LOADKX"
						or fallbackWrite.opName == "LOADB" or fallbackWrite.opName == "LOADNIL")
					and onlyFallbackWriteBetween(info.pc + info.len, target, fallbackWrite.pc)
				then
					local sourceExpr = preWrite.sourceName or preWrite.expr
					if sourceExpr
						and not tostring(sourceExpr):match("^R%d+$")
						and regReadBeforeWrite(p, info.a, target, math.min(#p.code - 1, target + 20))
					then
						local usePc = firstReadBeforeWrite(info.a, target, math.min(#p.code - 1, target + 20))
						if usePc then
							local hint = {
								reg = info.a,
								sourceExpr = sourceExpr,
								fallbackExpr = fallbackWrite.expr,
								expr = "(" .. tostring(sourceExpr) .. " or " .. tostring(fallbackWrite.expr) .. ")",
								jumpPc = info.pc,
								fallbackPc = fallbackWrite.pc,
								usePc = usePc,
							}
							analysis.orDefaultHints.jumps[info.pc] = hint
							analysis.orDefaultHints.fallbacks[fallbackWrite.pc] = hint
							analysis.orDefaultHints.uses[usePc] = hint
							analysis.orDefaultHintCount = analysis.orDefaultHintCount + 1
						end
					end
				end
			end
		end
	end
	local concatBranchSeen = {}
	local guardedValuePhiSeen = {}
	for pcKey, info in pairs(cfg.instructions) do
		if info.opName == "JUMPIF" or info.opName == "JUMPIFNOT" then
			local target = jumpTargetForInsn(info)
			if target and target > info.pc then
				local reg = info.a
				local preWrite = lastWriteBefore(reg, info.pc)
				local fallbackWrite = firstWriteBetween(reg, info.pc + info.len, target)
				local fallbackWriteInfo = fallbackWrite and cfg.instructions and cfg.instructions[fallbackWrite.pc] or nil
				if fallbackWrite and fallbackWrite.opName == "NAMECALL" and fallbackWriteInfo then
					local callWrite = firstWriteBetween(reg, fallbackWrite.pc + fallbackWriteInfo.len, target)
					if callWrite and callWrite.opName == "CALL" then
						fallbackWrite = callWrite
					end
				end
				local fallbackOnlyWrite = fallbackWrite ~= nil
				if fallbackOnlyWrite then
					for _, otherWrite in ipairs(analysis.regWrites[reg] or {}) do
						if otherWrite.pc >= info.pc + info.len and otherWrite.pc < target and otherWrite.pc ~= fallbackWrite.pc then
							local allowNamecall = fallbackWrite.opName == "CALL"
								and otherWrite.opName == "NAMECALL"
								and otherWrite.pc < fallbackWrite.pc
							if not allowNamecall then
								fallbackOnlyWrite = false
								break
							end
						end
					end
				end
				local mergeInfo = decodedInsnAt(p, target)
				local mergeRead = (mergeInfo and instrReadsReg(mergeInfo, reg))
					or regReadBeforeWrite(p, reg, target, math.min(#p.code - 1, target + 80))
				if preWrite
					and fallbackWrite
					and fallbackOnlyWrite
					and mergeRead
				then
					local preSimple = isSimpleValuePhiWrite(preWrite) or preWrite.opName == "CALL"
					local fallbackSimple = isSimpleValuePhiWrite(fallbackWrite) or fallbackWrite.opName == "CALL"
					if preSimple and fallbackSimple then
						local key = tostring(reg) .. ":guardphi:" .. tostring(info.pc) .. ":" .. tostring(target)
						if not guardedValuePhiSeen[key] then
							guardedValuePhiSeen[key] = true
							local targetName = valuePhiTargetName(reg, target, preWrite, fallbackWrite)
							local declareAtPre = not targetDeclaredBefore(targetName, preWrite.pc)
							analysis.valuePhiHints[preWrite.pc] = {
								reg = reg,
								targetName = targetName,
								declare = declareAtPre,
							}
							analysis.valuePhiHints[fallbackWrite.pc] = {
								reg = reg,
								targetName = targetName,
								declare = false,
							}
						end
					end
				end
			end
		end
	end
	for _, info in pairs(cfg.instructions) do
		if isConditionalJumpOp(info.opName) then
			local thenStart = info.pc + info.len
			local elsePc = jumpTargetForInsn(info)
			if elsePc and elsePc > thenStart then
				local scanPc = thenStart
				local mergePc = nil
				local thenJumpPc = nil
				while scanPc < elsePc do
					local scanInfo = cfg.instructions[scanPc] or decodedInsnAt(p, scanPc)
					if scanInfo.opName == "JUMP" then
						local targetPc = jumpTargetForInsn(scanInfo)
						if targetPc and targetPc > elsePc then
							mergePc = targetPc
							thenJumpPc = scanPc
						end
					end
					scanPc = scanPc + scanInfo.len
				end
				if mergePc and thenJumpPc and mergePc > elsePc then
					for reg in pairs(analysis.regWrites) do
						local leftLast = lastWriteBetween(reg, thenStart, thenJumpPc)
						local rightLast = lastWriteBetween(reg, elsePc, mergePc)
						local mergeRead = regReadBeforeWrite(p, reg, mergePc, math.min(#p.code - 1, mergePc + 80))
						if leftLast
							and rightLast
							and leftLast.opName == "CONCAT"
							and rightLast.opName == "CONCAT"
							and mergeRead
						then
							local key = tostring(info.pc) .. ":" .. tostring(reg) .. ":" .. tostring(mergePc)
							if not concatBranchSeen[key] then
								concatBranchSeen[key] = true
								local targetName = localAt(p, reg, mergePc) or stableGeneratedTempName(reg, "_value_")
								if not isValidIdent(targetName) or targetName:match("^_r%d+[_%d]*$") then
									targetName = stableGeneratedTempName(reg, "_value_")
								end
								local firstPc = math.min(leftLast.pc, rightLast.pc)
								analysis.concatPhiHints[leftLast.pc] = {
									reg = reg,
									targetName = targetName,
									declare = leftLast.pc == firstPc,
								}
								analysis.concatPhiHints[rightLast.pc] = {
									reg = reg,
									targetName = targetName,
									declare = rightLast.pc == firstPc,
								}
							end
						end
						local leftValueWrite = isSimpleValuePhiWrite(leftLast)
						local rightValueWrite = isSimpleValuePhiWrite(rightLast)
						if mergeRead
							and leftLast
							and rightLast
							and (leftValueWrite or rightValueWrite)
						then
							local firstBranchPc = math.min(leftLast.pc, rightLast.pc)
							local initWrite = lastWriteBefore(reg, firstBranchPc)
							if initWrite and (isSimpleValuePhiWrite(initWrite) or initWrite.opName == "LOADNIL") then
								local key = tostring(info.pc) .. ":value:" .. tostring(reg) .. ":" .. tostring(mergePc)
								if not guardedValuePhiSeen[key] then
									guardedValuePhiSeen[key] = true
									local priorWrite = lastWriteBefore(reg, initWrite.pc)
									local targetName = valuePhiTargetName(reg, mergePc, priorWrite, initWrite, leftLast, rightLast)
									analysis.valuePhiHints[initWrite.pc] = {
										reg = reg,
										targetName = targetName,
										declare = true,
									}
									if leftValueWrite then
										analysis.valuePhiHints[leftLast.pc] = {
											reg = reg,
											targetName = targetName,
											declare = false,
										}
									end
									if rightValueWrite then
										analysis.valuePhiHints[rightLast.pc] = {
											reg = reg,
											targetName = targetName,
											declare = false,
										}
									end
								end
							end
						end
					end
				end
			end
		end
	end
	for pcKey, info in pairs(cfg.instructions) do
		if info.opName == "CALL" and info.b and info.b >= 4 then
			local calleeRead = analysis.regVersionsByPc[pcKey] and analysis.regVersionsByPc[pcKey].reads and analysis.regVersionsByPc[pcKey].reads[1] or nil
			local calleeExpr = calleeRead and calleeRead.expr or nil
			if calleeExpr == "print" then
				local reg = info.a + 1
				while reg <= info.a + info.b - 2 do
					local labelWrite = lastWriteBefore(reg, pcKey)
					local valueReg = reg + 1
					local valueWrite = lastWriteBefore(valueReg, pcKey)
					local counterReg = valueWrite and valueWrite.opName == "MOVE" and valueWrite.sourceReg or valueReg
					local label = labelWrite and labelWrite.opName == "LOADK" and labelWrite.expr or nil
					local nameHint = cleanCounterLabel(label and label:match("^['\"](.*)['\"]$") or nil)
					if nameHint and hasSelfIncrementBefore(counterReg, pcKey) then
						local initWrite = firstWriteBefore(counterReg, pcKey, "LOADN", "0")
						if initWrite then
							analysis.counterHints.initializers[initWrite.pc] = nameHint
							for _, write in ipairs(analysis.regWrites[counterReg] or {}) do
								if write.pc < pcKey
									and write.opName == "ADDK"
									and write.sourceReg == counterReg
									and write.constExpr == "1"
								then
									analysis.counterHints.increments[write.pc] = nameHint
								end
							end
						end
					end
					reg = reg + 2
				end
			end
		end
	end
	local counterSeen = {}
	for pcKey in pairs(analysis.counterHints.initializers) do counterSeen["i:" .. tostring(pcKey)] = true end
	for pcKey in pairs(analysis.counterHints.increments) do counterSeen["a:" .. tostring(pcKey)] = true end
	for _ in pairs(counterSeen) do analysis.counterHintCount = analysis.counterHintCount + 1 end
	local function nearestCommonPostdominator(leftId, rightId, afterPc)
		local leftSet = cfg.postdominators and cfg.postdominators[leftId] or nil
		local rightSet = cfg.postdominators and cfg.postdominators[rightId] or nil
		if not leftSet or not rightSet then return nil end
		local bestId = nil
		local bestPc = nil
		for id in pairs(leftSet) do
			if rightSet[id] then
				local block = cfg.blocks[id]
				if block and block.startPc > afterPc then
					if not bestPc or block.startPc < bestPc then
						bestId = id
						bestPc = block.startPc
					end
				end
			end
		end
		return bestId
	end
	local function collectRegionWrites(startId, stopId, minPc)
		local out = {}
		local seen = {}
		local work = { startId }
		local stopBlock = cfg.blocks[stopId]
		while #work > 0 do
			local id = table.remove(work)
			if id ~= stopId and not seen[id] then
				seen[id] = true
				local block = cfg.blocks[id]
				if block and block.startPc > minPc and (not stopBlock or block.startPc < stopBlock.startPc) then
					for _, write in ipairs(analysis.regWritesByBlock[id] or {}) do
						out[write.reg] = out[write.reg] or {}
						out[write.reg][#out[write.reg]+1] = write
					end
					for _, succId in ipairs(block.successors or {}) do
						if succId ~= stopId and not seen[succId] then
							local succ = cfg.blocks[succId]
							if succ and (not stopBlock or succ.startPc <= stopBlock.startPc) then
								work[#work+1] = succId
							end
						end
					end
				end
			end
		end
		return out
	end
	local seenPhi = {}
	local seenValuePhi = {}
	for _, block in ipairs(cfg.blocks or {}) do
		if cfg.reachable and cfg.reachable[block.id] and #block.successors >= 2 then
			local succA = block.successors[1]
			local succB = block.successors[2]
			local mergeId = nearestCommonPostdominator(succA, succB, block.lastPc)
			local mergeBlock = mergeId and cfg.blocks[mergeId] or nil
			if mergeBlock then
				analysis.branchMergeCount = analysis.branchMergeCount + 1
				local leftWrites = collectRegionWrites(succA, mergeId, block.lastPc)
				local rightWrites = collectRegionWrites(succB, mergeId, block.lastPc)
				local regsSeen = {}
				for reg in pairs(leftWrites) do regsSeen[reg] = true end
				for reg in pairs(rightWrites) do regsSeen[reg] = true end
				for reg in pairs(regsSeen) do
					local sideCount = (leftWrites[reg] and 1 or 0) + (rightWrites[reg] and 1 or 0)
					local mergeRead = regReadBeforeWrite(p, reg, mergeBlock.startPc, math.min(#p.code - 1, mergeBlock.startPc + 80))
					local leftLast = leftWrites[reg] and leftWrites[reg][#leftWrites[reg]] or nil
					local rightLast = rightWrites[reg] and rightWrites[reg][#rightWrites[reg]] or nil
					if leftLast
						and rightLast
						and leftLast.opName == "CONCAT"
						and rightLast.opName == "CONCAT"
						and mergeRead
					then
						local targetName = localAt(p, reg, mergeBlock.startPc) or stableGeneratedTempName(reg, "_value_")
						if not isValidIdent(targetName) or targetName:match("^_r%d+[_%d]*$") then
							targetName = stableGeneratedTempName(reg, "_value_")
						end
						local firstPc = math.min(leftLast.pc, rightLast.pc)
						analysis.concatPhiHints[leftLast.pc] = {
							reg = reg,
							targetName = targetName,
							declare = leftLast.pc == firstPc,
						}
						analysis.concatPhiHints[rightLast.pc] = {
							reg = reg,
							targetName = targetName,
							declare = rightLast.pc == firstPc,
						}
					end
					local firstBranchPc = math.min(
						(leftWrites[reg] and leftWrites[reg][1] and leftWrites[reg][1].pc) or mergeBlock.startPc,
						(rightWrites[reg] and rightWrites[reg][1] and rightWrites[reg][1].pc) or mergeBlock.startPc
					)
					local initWrite = lastWriteBefore(reg, firstBranchPc)
					local leftValueWrite = isSimpleValuePhiWrite(leftLast)
					local rightValueWrite = isSimpleValuePhiWrite(rightLast)
					if mergeRead
						and initWrite
						and (isSimpleValuePhiWrite(initWrite) or initWrite.opName == "LOADNIL")
						and (leftValueWrite or rightValueWrite)
					then
						local key = tostring(block.id) .. ":value:" .. tostring(mergeId) .. ":" .. tostring(reg)
						if not seenValuePhi[key] then
							seenValuePhi[key] = true
							local priorWrite = lastWriteBefore(reg, initWrite.pc)
							local targetName = valuePhiTargetName(reg, mergeBlock.startPc, priorWrite, initWrite, leftLast, rightLast)
							analysis.valuePhiHints[initWrite.pc] = {
								reg = reg,
								targetName = targetName,
								declare = true,
							}
							if leftValueWrite then
								analysis.valuePhiHints[leftLast.pc] = {
									reg = reg,
									targetName = targetName,
									declare = false,
								}
							end
							if rightValueWrite then
								analysis.valuePhiHints[rightLast.pc] = {
									reg = reg,
									targetName = targetName,
									declare = false,
								}
							end
						end
					end
					if sideCount >= 2 or regReadBeforeWrite(p, reg, mergeBlock.startPc, math.min(#p.code - 1, mergeBlock.startPc + 80)) then
						local key = tostring(block.id) .. ":" .. tostring(mergeId) .. ":" .. tostring(reg)
						if not seenPhi[key] then
							seenPhi[key] = true
							analysis.phiCandidates[#analysis.phiCandidates+1] = {
								reg = reg,
								branchBlock = block.id,
								branchPc = block.lastPc,
								mergeBlock = mergeId,
								mergePc = mergeBlock.startPc,
								startPc = math.min(
									(leftWrites[reg] and leftWrites[reg][1] and leftWrites[reg][1].pc) or mergeBlock.startPc,
									(rightWrites[reg] and rightWrites[reg][1] and rightWrites[reg][1].pc) or mergeBlock.startPc
								),
								sideCount = sideCount,
							}
							analysis.phiCandidateCount = analysis.phiCandidateCount + 1
						end
					end
				end
			end
		end
	end
	-- Detect CALL->MOVE single-use inline: CALL Ra (c==2) followed immediately by MOVE Rb=Ra
	-- where Ra has no debug locvar and is only read by this one MOVE.
	-- Collapses split aliases like: local X = f(); Y = X  -->  Y = f()
	for pcKey, info in pairs(cfg.instructions) do
		if info.opName == "CALL" and info.c == 2 then
			local callReg = info.a
			local nextPc = pcKey + info.len
			local nextInfo = nextPc < #p.code and decodedInsnAt(p, nextPc) or nil
			if nextInfo
				and nextInfo.opName == "MOVE"
				and nextInfo.b == callReg
				and nextInfo.a ~= callReg
				and not localAt(p, callReg, nextPc)
			then
				local destReg = nextInfo.a
				local scanPc = nextPc + nextInfo.len
				local singleUse = true
				while scanPc < #p.code do
					local si = decodedInsnAt(p, scanPc)
					if instrReadsReg(si, callReg) then singleUse = false; break end
					if instrWritesReg(si, callReg) then break end
					scanPc = scanPc + si.len
				end
				if singleUse then
					analysis.callInlineHints[pcKey] = { destReg = destReg }
				end
			end
		end
	end
	-- Detect back-edge counter mutations (generic): a SUBK/ADDK/MULK/etc. inside a
	-- loop body whose destination register R has a read of R earlier in the same
	-- loop body. This means R carries state across iterations and must be
	-- materialized as an explicit assignment (R = R - K) instead of being inlined
	-- as an expression (regs[R] = "(R - K)"), otherwise the loop body would
	-- contain no mutation visible to subsequent comparisons.
	local arithKOps = {
		ADDK = true, SUBK = true, MULK = true, DIVK = true,
		MODK = true, POWK = true, IDIVK = true,
	}
	for _, edge in ipairs(cfg.backEdges or {}) do
		local headBlock = cfg.blocks[edge.to]
		local tailBlock = cfg.blocks[edge.from]
		if headBlock and tailBlock and headBlock.startPc <= tailBlock.lastPc then
			local loopStart = headBlock.startPc
			local loopEnd = tailBlock.lastPc
			local scanPc = loopStart
			while scanPc <= loopEnd and scanPc < #p.code do
				local info = cfg.instructions[scanPc] or decodedInsnAt(p, scanPc)
				if arithKOps[info.opName] then
					local destReg = info.a
					-- Check: is destReg read at some pc' in [loopStart, scanPc) inside this loop body?
					local readBefore = false
					local probe = loopStart
					while probe < scanPc do
						local pi = cfg.instructions[probe] or decodedInsnAt(p, probe)
						if instrReadsReg(pi, destReg) then
							readBefore = true
							break
						end
						probe = probe + pi.len
					end
					if readBefore then
						-- Find the initializer write before the loop (most recent write)
						local initWrite = lastWriteBefore(destReg, loopStart)
						local initPc = initWrite and initWrite.pc or nil
						-- Choose a stable target name: prefer existing locvar, else generated
						local targetName
						local lv = locvarAt(p, destReg, scanPc)
						if lv and isValidIdent(lv.name) then
							targetName = lv.name
						else
							targetName = stableGeneratedTempName(destReg, "_value_")
						end
						analysis.backEdgeMutationHints[scanPc] = {
							reg = destReg,
							targetName = targetName,
							initPc = initPc,
						}
						-- Mark the initializer write so it materializes a local
						-- declaration of TARGETNAME with the appropriate initial value.
						if initPc and not analysis.backEdgeMutationHints[initPc] then
							analysis.backEdgeMutationHints[initPc] = {
								reg = destReg,
								targetName = targetName,
								isInit = true,
							}
						end
					end
				end
				scanPc = scanPc + info.len
			end
		end
	end
	-- Detect stale-snapshot-after-field-write pattern (generic):
	-- At each SETTABLEKS T.K = V, find registers R whose write produced an
	-- expression that "depends on" T.K (directly or indirectly through a chain).
	-- If R is read after the SETTABLEKS AND R's expression hasn't been
	-- re-materialized as a real local, mark R's defining write for materialization.
	-- This preserves snapshot semantics.
	for pcKey, info in pairs(cfg.instructions) do
		if info.opName == "SETTABLEKS" then
			local mutatedSrcReg = info.b
			local keyConst = info.aux ~= nil and constantAt(p, info.aux) or nil
			local key = keyConst and keyConst.kind == "string" and keyConst.value or nil
			if key then
				-- Build the "field path" string representing the mutated location:
				-- the source's expression at this pc + ".key".
				-- We approximate via the register's last write.
				local srcWrite = lastWriteBefore(mutatedSrcReg, pcKey)
				if srcWrite and srcWrite.expr then
					local srcExpr = srcWrite.expr
					-- The concrete field expression that's been mutated
					local fieldExpr1 = srcExpr .. "." .. key
					local fieldExpr2 = srcExpr .. "[\"" .. key .. "\"]"
					-- For each register R that has a write before pcKey whose
					-- expression contains fieldExpr1 or fieldExpr2, AND R is
					-- read after pcKey, mark R's write for materialization.
					for reg, writes in pairs(analysis.regWrites) do
						if reg ~= mutatedSrcReg then
							-- Find the LATEST write to reg before pcKey
							local lastWrite = nil
							for _, w in ipairs(writes) do
								if w.pc < pcKey then
									lastWrite = w
								else
									break
								end
							end
							if lastWrite and lastWrite.expr then
								local exprStr = lastWrite.expr
								local depends = false
								if exprStr == fieldExpr1 or exprStr == fieldExpr2 then
									depends = true
								-- Also check for CHAIN access: lastWrite.expr starts with fieldExpr1
								elseif exprStr:sub(1, #fieldExpr1) == fieldExpr1
									and #exprStr > #fieldExpr1
									and not exprStr:sub(#fieldExpr1 + 1, #fieldExpr1 + 1):match("[%w_]")
								then
									depends = true
								end
								if depends and not analysis.staleSnapshotHints[lastWrite.pc] then
									-- Check if reg is read after pcKey before being rewritten
									local nextWrite = nil
									for _, w in ipairs(writes) do
										if w.pc > pcKey then
											nextWrite = w
											break
										end
									end
									local readEnd = nextWrite and nextWrite.pc or #p.code
									local readAfter = false
									local probe = pcKey + info.len
									while probe < readEnd and probe < #p.code do
										local pi = cfg.instructions[probe] or decodedInsnAt(p, probe)
										if instrReadsReg(pi, reg) then
											readAfter = true
											break
										end
										probe = probe + pi.len
									end
									if readAfter then
										local lv = locvarAt(p, reg, lastWrite.pc)
										local targetName
										if lv and isValidIdent(lv.name) then
											targetName = lv.name
										elseif lastWrite.name and isValidIdent(lastWrite.name) and not lastWrite.name:match("^R%d+$") then
											targetName = lastWrite.name
										else
											targetName = stableGeneratedTempName(reg, "_value_")
										end
										analysis.staleSnapshotHints[lastWrite.pc] = {
											reg = reg,
											targetName = targetName,
										}
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return analysis
end

local function applyPhiLocvarHints(p, analysis, dryRun)
	if type(analysis) ~= "table" or type(analysis.phiCandidates) ~= "table" then
		return 0
	end
	local applied = 0
	local seen = {}
	for _, cand in ipairs(analysis.phiCandidates) do
		local reg = cand.reg
		local branchPc = cand.branchPc or 0
		local mergePc = cand.mergePc or branchPc
		if type(reg) == "number" and type(branchPc) == "number" and type(mergePc) == "number" and mergePc > branchPc then
			local best = nil
			for _, lv in ipairs(p.locvars or {}) do
				if lv.reg == reg
					and isValidIdent(lv.name)
					and lv.startpc <= branchPc
					and branchPc <= lv.endpc + 1
				then
					if not best or lv.startpc > best.startpc then
						best = lv
					end
				end
			end
			if best and mergePc > best.endpc then
				local conflict = false
				for _, other in ipairs(p.locvars or {}) do
					if other ~= best
						and other.reg == reg
						and other.name ~= best.name
						and isValidIdent(other.name)
						and other.startpc <= mergePc
						and other.endpc >= best.startpc
					then
						conflict = true
						break
					end
				end
				local key = tostring(reg) .. ":" .. tostring(best.startpc) .. ":" .. tostring(mergePc)
				if not conflict and not seen[key] then
					seen[key] = true
					applied = applied + 1
					if not dryRun then
						best.endpc = mergePc
					end
				end
			end
		end
	end
	analysis.phiLocvarHintCount = applied
	return applied
end

local function isFallbackUpvalueName(name)
	return type(name) ~= "string"
		or name == ""
		or name == "_nil"
		or name:match("^U%d+$") ~= nil
		or name:match("^_%d+$") ~= nil
		or name:match("^_r%d") ~= nil
end

local function deriveUpvalueSemanticName(bc, childId, upvalueIdx, seen)
	seen = seen or {}
	local key = tostring(childId) .. ":" .. tostring(upvalueIdx)
	if seen[key] then return nil end
	seen[key] = true
	local child = protoAt(bc, childId)
	if not child or upvalueIdx < 0 or upvalueIdx >= (child.nups or 0) then return nil end
	local holders = {}
	local writeKinds = {}
	local hasDisconnect = false
	local hasTableOp = false
	local hasLength = false
	local hasBooleanTest = false
	local usedAsIndex = false
	local hasConnectCall = false
	local lastWriter = {}
	local lastNamecallMethod = {}
	local setupvalSourceLocal = nil
	local regExpr = {}
	local regLocalName = {}
	local setupvalCallHint = nil
	local pc = 0
	while pc < #child.code do
		local insn = codeWordAt(child, pc)
		local op = bit32_band(insn, 0xFF)
		local opName = OPCODES[op] or ""
		local a = bit32_band(bit32_rshift(insn, 8), 0xFF)
		local b = bit32_band(bit32_rshift(insn, 16), 0xFF)
		local c = bit32_band(bit32_rshift(insn, 24), 0xFF)
		local d = decodeSignedD(insn)
		local aux = nil
		if OPS_WITH_AUX[opName] and pc + 1 < #child.code then
			aux = codeWordAt(child, pc + 1)
		end
		if opName == "GETUPVAL" then
			if b == upvalueIdx then
				holders[a] = true
			else
				holders[a] = nil
			end
		end
		if opName == "SETUPVAL" and b == upvalueIdx then
			local writer = lastWriter[a]
			if writer then
				writeKinds[writer] = true
				if writer == "CALL" then
					local m = lastNamecallMethod[a]
					if m == "Connect" or m == "ConnectParallel" or m == "Once" or m == "ConnectOnce" then
						hasConnectCall = true
					end
				end
			end
			if not hasConnectCall then
				local sourceLocal = localAt(child, a, pc) or regLocalName[a]
				if sourceLocal and isValidIdent(sourceLocal) and not isFallbackUpvalueName(sourceLocal) then
					setupvalSourceLocal = sourceLocal
				elseif regExpr[a] then
					local h = deriveNameHint(regExpr[a])
					if h and isValidIdent(h) and not isFallbackUpvalueName(h) then
						setupvalCallHint = h
					end
				end
			end
		elseif opName == "NEWCLOSURE" or opName == "DUPCLOSURE" then
			local grandchildId = nil
			if opName == "NEWCLOSURE" then
				grandchildId = childProtoIdAt(child, d)
			else
				local closureConst = constantAt(child, d)
				grandchildId = closureConst and closureConst.kind == "closure" and closureConst.value or nil
			end
			if grandchildId ~= nil then
				local capIdx = 0
				local capPc = pc + getOpLength(opName)
				while capPc < #child.code do
					local capInsn = codeWordAt(child, capPc)
					local capName = OPCODES[bit32_band(capInsn, 0xFF)] or ""
					if capName ~= "CAPTURE" then break end
					local capKindId = bit32_band(bit32_rshift(capInsn, 8), 0xFF)
					local capB = bit32_band(bit32_rshift(capInsn, 16), 0xFF)
					if CAPTURE_KINDS[capKindId] == "UPVAL" and capB == upvalueIdx then
						local semantic = deriveUpvalueSemanticName(bc, grandchildId, capIdx, seen)
						if semantic then return semantic end
					end
					capIdx = capIdx + 1
					capPc = capPc + 1
				end
			end
		end
		if opName == "NAMECALL" and holders[b] then
			local keyConst = aux ~= nil and constantAt(child, aux) or nil
			if keyConst and keyConst.kind == "string" and keyConst.value == "Disconnect" then
				hasDisconnect = true
			end
		elseif opName == "LENGTH" and holders[b] then
			hasLength = true
		elseif (opName == "GETTABLE" or opName == "GETTABLEN" or opName == "SETTABLE" or opName == "SETTABLEN") and holders[b] then
			hasTableOp = true
		end
		if (opName == "GETTABLEKS" or opName == "SETTABLEKS") and holders[b] then
			hasTableOp = true
		end
		if (opName == "FORGPREP" or opName == "FORGPREP_INEXT" or opName == "FORGPREP_NEXT") and holders[a] then
			hasTableOp = true
		end
		if opName == "CALL" then
			local argEnd = b == 0 and (a + 1) or (a + b - 1)
			for ai = a + 1, argEnd do
				if holders[ai] then
					hasTableOp = true
					break
				end
			end
		end
		if opName == "NAMECALL" then
			local keyConst = aux ~= nil and constantAt(child, aux) or nil
			if keyConst and keyConst.kind == "string" then
				lastNamecallMethod[a] = keyConst.value
			end
		end
		if (opName == "JUMPIF" or opName == "JUMPIFNOT") and holders[a] then
			hasBooleanTest = true
		end
		if (opName == "GETTABLE" or opName == "SETTABLE") and holders[c] then
			usedAsIndex = true
		end
		if opName == "MOVE" and holders[b] then
			holders[a] = true
		end
		if opName ~= "GETUPVAL" and opName ~= "MOVE" and holders[a] and (
			opName == "LOADK" or opName == "LOADKX" or opName == "LOADKC" or opName == "LOADN" or opName == "LOADB"
			or opName == "LOADNIL" or opName == "MOVE" or opName == "GETIMPORT" or opName == "GETGLOBAL"
			or opName == "GETTABLEKS" or opName == "GETTABLE" or opName == "GETTABLEN" or opName == "NEWTABLE"
			or opName == "DUPTABLE" or opName == "NEWCLOSURE" or opName == "DUPCLOSURE" or opName == "NAMECALL"
			or opName == "CALL" or opName == "ADD" or opName == "SUB" or opName == "MUL" or opName == "DIV"
			or opName == "MOD" or opName == "POW" or opName == "IDIV" or opName == "ADDK" or opName == "SUBK"
			or opName == "MULK" or opName == "DIVK" or opName == "MODK" or opName == "POWK" or opName == "IDIVK"
			or opName == "SUBRK" or opName == "DIVRK" or opName == "ORK" or opName == "ANDK" or opName == "OR"
			or opName == "AND" or opName == "MINUS" or opName == "NOT" or opName == "LENGTH" or opName == "CONCAT"
		) then
			holders[a] = nil
		end
		if opName == "LOADK" or opName == "LOADKX" or opName == "LOADKC" or opName == "LOADN" or opName == "LOADB"
			or opName == "LOADNIL" or opName == "MOVE" or opName == "GETIMPORT" or opName == "GETGLOBAL"
			or opName == "GETTABLEKS" or opName == "GETTABLE" or opName == "GETTABLEN" or opName == "NEWTABLE"
			or opName == "DUPTABLE" or opName == "NEWCLOSURE" or opName == "DUPCLOSURE" or opName == "CALL"
			or opName == "ADD" or opName == "SUB" or opName == "MUL" or opName == "DIV" or opName == "MOD"
			or opName == "POW" or opName == "IDIV" or opName == "ADDK" or opName == "SUBK" or opName == "MULK"
			or opName == "DIVK" or opName == "MODK" or opName == "POWK" or opName == "IDIVK" or opName == "SUBRK"
			or opName == "DIVRK" or opName == "ORK" or opName == "ANDK" or opName == "OR" or opName == "AND"
			or opName == "MINUS" or opName == "NOT" or opName == "LENGTH" or opName == "CONCAT" or opName == "GETUPVAL"
		then
			lastWriter[a] = opName
		end
		if opName == "GETIMPORT" then
			local parts = decodeImportId(aux or 0, child)
			regExpr[a] = #parts > 0 and table.concat(parts, ".") or nil
			regLocalName[a] = localAt(child, a, pc)
		elseif opName == "GETTABLEKS" then
			local idx = aux ~= nil and aux or d
			local keyConst = constantAt(child, idx)
			local key = keyConst and keyConst.kind == "string" and keyConst.value
			if key and regExpr[b] then
				regExpr[a] = regExpr[b] .. "." .. tostring(key)
			else
				regExpr[a] = nil
			end
			regLocalName[a] = localAt(child, a, pc)
		elseif opName == "GETUPVAL" then
			regExpr[a] = child.upvalues[b + 1]
			regLocalName[a] = localAt(child, a, pc)
		elseif opName == "MOVE" then
			regExpr[a] = regExpr[b]
			regLocalName[a] = regLocalName[b] or localAt(child, a, pc)
		elseif opName == "CALL" then
			local callee = regExpr[a]
			local argParts = {}
			local argEnd = b == 0 and (a + 1) or (a + b - 1)
			for ai = a + 1, argEnd do
				argParts[#argParts + 1] = regExpr[ai] or ("R" .. tostring(ai))
			end
			if callee then
				regExpr[a] = callee .. "(" .. table.concat(argParts, ", ") .. ")"
			else
				regExpr[a] = nil
			end
			regLocalName[a] = localAt(child, a, pc + 1) or localAt(child, a, pc)
		elseif opName == "NAMECALL" then
			regExpr[a] = nil
			regExpr[a + 1] = nil
			regLocalName[a] = nil
			regLocalName[a + 1] = nil
		else
			if lastWriter[a] and opName ~= "GETUPVAL" and opName ~= "MOVE" then
				regExpr[a] = nil
				regLocalName[a] = nil
			end
		end
		if opName == "NAMECALL" then
			lastWriter[a] = opName
			lastWriter[a + 1] = opName
		end
		pc = pc + (opName ~= "" and getOpLength(opName) or 1)
	end
	if hasDisconnect or hasConnectCall then return "connection" end
	if writeKinds.LOADB and hasBooleanTest and not (hasLength or writeKinds.NEWTABLE or writeKinds.DUPTABLE) then return "flag" end
	if hasLength or writeKinds.NEWTABLE or writeKinds.DUPTABLE or hasTableOp then return "state" end
	if writeKinds.LOADB or hasBooleanTest then return "flag" end
	if writeKinds.LOADN or usedAsIndex then return "index" end
	if setupvalSourceLocal then return setupvalSourceLocal end
	if setupvalCallHint then return setupvalCallHint end
	return nil
end

local function deriveSetupvalWriteName(bc, childId, upvalueIdx)
	local child = protoAt(bc, childId)
	if not child then return nil end
	local regExpr = {}
	local regLocalName = {}
	local pc = 0
	while pc < #child.code do
		local insn = codeWordAt(child, pc)
		local op = bit32_band(insn, 0xFF)
		local opName = OPCODES[op] or ""
		local a = bit32_band(bit32_rshift(insn, 8), 0xFF)
		local b = bit32_band(bit32_rshift(insn, 16), 0xFF)
		local d = decodeSignedD(insn)
		local aux = nil
		if OPS_WITH_AUX[opName] and pc + 1 < #child.code then
			aux = codeWordAt(child, pc + 1)
		end
		if opName == "SETUPVAL" and b == upvalueIdx then
			local name = localAt(child, a, pc) or regLocalName[a]
			if name and isValidIdent(name) and not isFallbackUpvalueName(name) then
				return name
			end
			local hint = regExpr[a] and deriveNameHint(regExpr[a]) or nil
			if hint and isValidIdent(hint) and not isFallbackUpvalueName(hint) then
				return hint
			end
		elseif opName == "GETIMPORT" then
			local parts = decodeImportId(aux or 0, child)
			regExpr[a] = #parts > 0 and table.concat(parts, ".") or nil
			regLocalName[a] = localAt(child, a, pc)
		elseif opName == "GETUPVAL" then
			regExpr[a] = child.upvalues[b + 1]
			regLocalName[a] = localAt(child, a, pc)
		elseif opName == "GETTABLEKS" then
			local idx = aux ~= nil and aux or d
			local keyConst = constantAt(child, idx)
			local key = keyConst and keyConst.kind == "string" and keyConst.value
			regExpr[a] = key and regExpr[b] and (regExpr[b] .. "." .. key) or nil
			regLocalName[a] = localAt(child, a, pc)
		elseif opName == "MOVE" then
			regExpr[a] = regExpr[b]
			regLocalName[a] = regLocalName[b] or localAt(child, a, pc)
		elseif opName == "CALL" then
			local callee = regExpr[a]
			local argParts = {}
			local argEnd = b == 0 and (a + 1) or (a + b - 1)
			for ai = a + 1, argEnd do
				argParts[#argParts + 1] = regExpr[ai] or ("R" .. tostring(ai))
			end
			regExpr[a] = callee and (callee .. "(" .. table.concat(argParts, ", ") .. ")") or nil
			regLocalName[a] = localAt(child, a, pc + 1) or localAt(child, a, pc)
		elseif opName == "NAMECALL" then
			regExpr[a] = nil
			regExpr[a + 1] = nil
			regLocalName[a] = nil
			regLocalName[a + 1] = nil
		elseif opName == "LOADB" or opName == "LOADN" or opName == "LOADK" or opName == "LOADKX"
			or opName == "LOADKC" or opName == "LOADNIL" or opName == "NEWTABLE" or opName == "DUPTABLE"
			or opName == "GETGLOBAL" or opName == "GETTABLE" or opName == "GETTABLEN"
			or opName == "ADD" or opName == "SUB" or opName == "MUL" or opName == "DIV" or opName == "MOD"
			or opName == "POW" or opName == "IDIV" or opName == "ADDK" or opName == "SUBK" or opName == "MULK"
			or opName == "DIVK" or opName == "MODK" or opName == "POWK" or opName == "IDIVK" or opName == "SUBRK"
			or opName == "DIVRK" or opName == "ORK" or opName == "ANDK" or opName == "OR" or opName == "AND"
			or opName == "MINUS" or opName == "NOT" or opName == "LENGTH" or opName == "CONCAT"
			or opName == "NEWCLOSURE" or opName == "DUPCLOSURE"
		then
			regExpr[a] = nil
			regLocalName[a] = nil
		end
		pc = pc + (opName ~= "" and getOpLength(opName) or 1)
	end
	return nil
end

local function childWritesUpvalue(bc, childId, upvalueIdx)
	local child = protoAt(bc, childId)
	if not child then return false end
	local pc = 0
	while pc < #child.code do
		local insn = codeWordAt(child, pc)
		local op = bit32_band(insn, 0xFF)
		local opName = OPCODES[op] or ""
		if opName == "SETUPVAL" then
			local b = bit32_band(bit32_rshift(insn, 16), 0xFF)
			if b == upvalueIdx then
				return true
			end
		end
		pc = pc + (opName ~= "" and getOpLength(opName) or 1)
	end
	return false
end

local function propagateUpvalueNames(protoIdx, bc, visited)
	visited = visited or {}
	if visited[protoIdx] then return end
	visited[protoIdx] = true
	local p = protoAt(bc, protoIdx)
	if not p then return end
	local function r(reg, regs)
		return regs[reg] or ("R" .. tostring(reg))
	end
	local function setChildUpvalueName(childId, capIdx, expr, semanticHint, parentIdent)
		local child = protoAt(bc, childId)
		if not child then return end
		if capIdx < 0 or capIdx >= (child.nups or 0) then return end
		for i = 1, child.nups do
			if child.upvalues[i] == nil or child.upvalues[i] == "" then
				child.upvalues[i] = "U" .. tostring(i - 1)
			end
		end
		if not isFallbackUpvalueName(child.upvalues[capIdx + 1]) then return end
		local rawExpr = type(expr) == "string" and expr:match("^%s*(.-)%s*$") or ""
		local childName = child.debugname ~= "" and cleanGeneratedIdent(child.debugname) or nil
		local hint
		if rawExpr == "nil" or rawExpr == "true" or rawExpr == "false" then
			hint = semanticHint
		elseif rawExpr == "{}" then
			if childName == "new" then
				hint = "module"
			elseif semanticHint then
				hint = semanticHint
			else
				return
			end
		elseif rawExpr:match("^_%d+$") then
			hint = semanticHint or "index"
		elseif rawExpr:find("^%-?%d+%.?%d*$") then
			hint = semanticHint or "index"
		elseif semanticHint and isFallbackUpvalueName(rawExpr) then
			hint = semanticHint
		else
			-- For dict-literal table expressions like `{ Countdown = "...", ... }`,
			-- prefer a short generic name over running cleanGeneratedIdent on the
			-- raw text (which would produce a long key-mashup like
			-- `_Countdown_Next_wave_in_d_WaveStarted_Wave_d_Has`).
			if rawExpr:match("^%{.*%}$") then
				if rawExpr:find("%f[%a_][A-Z][A-Z0-9_]*%f[^%a_%d]%s*=") then
					hint = semanticHint or "config"
				else
					hint = semanticHint or "data"
				end
			else
				hint = deriveNameHint(rawExpr) or cleanGeneratedIdent(rawExpr)
			end
		end
		if not hint or not isValidIdent(hint) then return end
		if hint:match("^R%d+$") or hint:match("^U%d+$") or hint:match("^_r%d") or hint:match("^_%d+$") then return end
		local used = {}
		local childParams = {}
		for i = 0, child.numparams - 1 do
			local paramName = localAt(child, i, 0) or ("arg" .. tostring(i))
			childParams[paramName] = true
			used[paramName] = true
		end
		for i = 1, #child.upvalues do
			if i ~= capIdx + 1 and child.upvalues[i] then
				used[child.upvalues[i]] = true
			end
		end
		if childParams[hint] then
			if hint == "arg0" and not used.self then
				hint = "self"
			else
				hint = hint .. "_upvalue"
			end
		end
		local name = hint
		if used[name] then
			local suffix = 2
			while used[name .. "_" .. tostring(suffix)] do suffix = suffix + 1 end
			name = name .. "_" .. tostring(suffix)
		end
		if type(parentIdent) == "string"
			and isValidIdent(parentIdent)
			and isFallbackUpvalueName(parentIdent)
			and not isFallbackUpvalueName(name)
		then
			bc.upvalueRenameHints = bc.upvalueRenameHints or {}
			bc.upvalueRenameHints[protoIdx] = bc.upvalueRenameHints[protoIdx] or {}
			local existing = bc.upvalueRenameHints[protoIdx][parentIdent]
			if existing ~= nil then
				name = existing
			else
				local usedParentNames = {}
				for oldName, mappedName in pairs(bc.upvalueRenameHints[protoIdx]) do
					if oldName ~= parentIdent then
						usedParentNames[mappedName] = true
					end
				end
				if usedParentNames[name] then
					local base, suffixText = name:match("^(.+)_(%d+)$")
					local suffix = tonumber(suffixText)
					if not base or not isValidIdent(base) or not suffix then
						base = name
						suffix = 1
					end
					repeat
						suffix = suffix + 1
						name = base .. "_" .. tostring(suffix)
					until not usedParentNames[name]
				end
				bc.upvalueRenameHints[protoIdx][parentIdent] = name
			end
		end
		child.upvalues[capIdx + 1] = name
	end
	local regs = {}
	local regIdent = {}
	for i = 0, p.numparams - 1 do
		regs[i] = localAt(p, i, 0) or ("arg" .. tostring(i))
		regIdent[i] = regs[i]
	end
	local pc = 0
	while pc < #p.code do
		local insn = codeWordAt(p, pc)
		local op = bit32_band(insn, 0xFF)
		local opName = OPCODES[op] or ""
		local a = bit32_band(bit32_rshift(insn, 8), 0xFF)
		local b = bit32_band(bit32_rshift(insn, 16), 0xFF)
		local c = bit32_band(bit32_rshift(insn, 24), 0xFF)
		local d = decodeSignedD(insn)
		local aux = nil
		if OPS_WITH_AUX[opName] and pc + 1 < #p.code then
			aux = codeWordAt(p, pc + 1)
		end
		if opName == "LOADNIL" then
			regs[a] = "nil"
			regIdent[a] = nil
		elseif opName == "LOADB" then
			regs[a] = b ~= 0 and "true" or "false"
			regIdent[a] = nil
		elseif opName == "LOADN" then
			regs[a] = tostring(d)
			regIdent[a] = nil
		elseif opName == "LOADK" or opName == "LOADKC" or opName == "LOADKX" then
			local idx = opName == "LOADKC" and c or (opName == "LOADK" and d or aux)
			regs[a] = kvalLua(p, idx)
			regIdent[a] = nil
		elseif opName == "MOVE" then
			regs[a] = r(b, regs)
			regIdent[a] = regIdent[b]
		elseif opName == "GETIMPORT" then
			local parts = decodeImportId(aux or 0, p)
			regs[a] = #parts > 0 and table.concat(parts, ".") or ("import(" .. tostring(d) .. ")")
			regIdent[a] = localAt(p, a, pc)
		elseif opName == "GETUPVAL" then
			regs[a] = p.upvalues[b + 1] or ("U" .. tostring(b))
			regIdent[a] = regs[a]
		elseif opName == "GETTABLEKS" then
			local idx = aux ~= nil and aux or d
			local keyConst = constantAt(p, idx)
			local key = keyConst and keyConst.kind == "string" and keyConst.value or ("K[" .. tostring(idx) .. "]")
			regs[a] = r(b, regs) .. luaIndexSuffix(key)
			regIdent[a] = localAt(p, a, pc)
		elseif opName == "GETTABLE" then
			regs[a] = r(b, regs) .. "[" .. r(c, regs) .. "]"
			regIdent[a] = localAt(p, a, pc)
		elseif opName == "GETTABLEN" then
			regs[a] = r(b, regs) .. "[" .. tostring(c + 1) .. "]"
			regIdent[a] = localAt(p, a, pc)
		elseif opName == "NEWTABLE" then
			regs[a] = "{}"
			regIdent[a] = localAt(p, a, pc) or ("_r" .. tostring(a))
		elseif opName == "DUPTABLE" then
			regs[a] = kvalLua(p, d)
			regIdent[a] = localAt(p, a, pc) or ("_r" .. tostring(a))
		elseif opName == "NAMECALL" then
			local keyConst = aux ~= nil and constantAt(p, aux) or nil
			local key = keyConst and keyConst.kind == "string" and keyConst.value or ("K[" .. tostring(aux) .. "]")
			regs[a] = r(b, regs) .. ":" .. tostring(key)
			regs[a + 1] = r(b, regs)
			regIdent[a] = nil
			regIdent[a + 1] = regIdent[b]
		elseif opName == "FORGPREP" or opName == "FORGPREP_INEXT" or opName == "FORGPREP_NEXT" then
			local loopNames = genericLoopVarNames(a, 2)
			regs[a + 3] = loopNames[1]
			regs[a + 4] = loopNames[2]
			regIdent[a + 3] = loopNames[1]
			regIdent[a + 4] = loopNames[2]
		elseif opName == "FORNPREP" then
			local loopName = localAt(p, a + 2, pc + 1) or "_i"
			regs[a + 2] = loopName
			regIdent[a + 2] = loopName
		elseif opName == "CALL" then
			local callee = r(a, regs)
			local isNamecall = string.find(callee:match("[^.]+$") or callee, ":", 1, true) ~= nil
			local args
			if b == 0 then
				local prev = regs[a + 1]
				args = prev and prev ~= ("R" .. tostring(a + 1)) and prev or "..."
			else
				local argParts = {}
				for reg = a + 1, a + b - 1 do
					push(argParts, r(reg, regs))
				end
				if isNamecall and #argParts > 0 then
					table.remove(argParts, 1)
				end
				args = table.concat(argParts, ", ")
			end
			if c ~= 1 then
				regs[a] = callee .. "(" .. args .. ")"
				regIdent[a] = localAt(p, a, pc + 1)
			end
		elseif opName == "NEWCLOSURE" or opName == "DUPCLOSURE" then
			local childId = nil
			if opName == "NEWCLOSURE" then
				childId = childProtoIdAt(p, d)
			else
				local closureConst = constantAt(p, d)
				childId = closureConst and closureConst.kind == "closure" and closureConst.value or nil
			end
			local closureProto = childId ~= nil and protoAt(bc, childId) or nil
			local closureName = closureProto and closureProto.debugname ~= "" and cleanIdent(closureProto.debugname) or nil
			regs[a] = closureName or (childId and ("<closure proto[" .. tostring(childId) .. "]>") or ("<closure>"))
			regIdent[a] = closureName
			if childId ~= nil then
				local capPc = pc + getOpLength(opName)
				local capIdx = 0
				while capPc < #p.code do
					local capInsn = codeWordAt(p, capPc)
					local capOp = bit32_band(capInsn, 0xFF)
					local capName = OPCODES[capOp] or ""
					if capName ~= "CAPTURE" then break end
					local capKindId = bit32_band(bit32_rshift(capInsn, 8), 0xFF)
					local capB = bit32_band(bit32_rshift(capInsn, 16), 0xFF)
					local capKind = CAPTURE_KINDS[capKindId] or ""
					local expr = nil
					if capKind == "VAL" or capKind == "REF" then
						expr = r(capB, regs)
					elseif capKind == "UPVAL" then
						expr = p.upvalues[capB + 1] or ("U" .. tostring(capB))
					end
					if expr then
						local semanticHint = deriveSetupvalWriteName(bc, childId, capIdx) or deriveUpvalueSemanticName(bc, childId, capIdx, {})
						setChildUpvalueName(childId, capIdx, expr, semanticHint, regIdent[capB])
					end
					capIdx = capIdx + 1
					capPc = capPc + 1
				end
				propagateUpvalueNames(childId, bc, visited)
			end
		end
		pc = pc + (opName ~= "" and getOpLength(opName) or 1)
	end
end

local function emitDecompileLine(pc, opName, a, b, c, d, e, aux, p, bc, regs, indent, generatedNameFor, functionName, renameHints, flowAnalysis)
	local function rname(reg)
		return regRepr(regs, p, reg, pc)
	end
	local previousMultretCallReg = regs.__lastMultretCallReg
	if regs.__guardedFallbackTargets then
		for reg, hint in pairs(regs.__guardedFallbackTargets) do
			if not hint or pc >= (hint.mergePc or -1) then
				regs.__guardedFallbackTargets[reg] = nil
			end
		end
	end
	local preservesMultretTop = opName == "SETLIST"
		or (opName == "CALL" and (b == 0 or c == 0))
		or (opName == "NAMECALL" and previousMultretCallReg and a + 1 < previousMultretCallReg)
		or (previousMultretCallReg and opName:match("^FASTCALL"))
		or (previousMultretCallReg and (opName == "GETIMPORT" or opName == "GETGLOBAL") and a < previousMultretCallReg)
	if not preservesMultretTop then
		regs.__lastMultretCallReg = nil
	end

	local function sanitizeLocalName(name, reg, atPc)
		if type(name) ~= "string" or name == "" then
			return "_r" .. tostring(reg)
		end
		if name:match("^R%d+$") then
			return "_r" .. tostring(reg)
		end
		if renameHints and renameHints[name] and isValidIdent(renameHints[name]) then
			name = renameHints[name]
		end
		local collidesWithScope = false
		for _, upvalueName in ipairs(p.upvalues or {}) do
			if upvalueName == name then
				collidesWithScope = true
				break
			end
		end
		if not collidesWithScope then
			for paramReg = 0, (p.numparams or 0) - 1 do
				if paramReg ~= reg then
					local paramName = localAt(p, paramReg, 0)
					if paramName == name then
						collidesWithScope = true
						break
					end
				end
			end
		end
		if not collidesWithScope then
			return name
		end
		regs.__sanitizedLocalNames = regs.__sanitizedLocalNames or {}
		local lv = locvarAt(p, reg, atPc or pc)
		local key = lv and (name .. ":" .. tostring(lv.startpc or "") .. ":" .. tostring(lv.endpc or "") .. ":" .. tostring(reg)) or (name .. ":" .. tostring(reg))
		if regs.__sanitizedLocalNames[key] then
			return regs.__sanitizedLocalNames[key]
		end
		local function nameReserved(candidate)
			for _, upvalueName in ipairs(p.upvalues or {}) do
				if upvalueName == candidate then
					return true
				end
			end
			for paramReg = 0, (p.numparams or 0) - 1 do
				local paramName = localAt(p, paramReg, 0)
				if paramName == candidate then
					return true
				end
			end
			for _, mapped in pairs(regs.__sanitizedLocalNames) do
				if mapped == candidate then
					return true
				end
			end
			return false
		end
		local suffix = 2
		local candidate = name .. "_" .. tostring(suffix)
		while nameReserved(candidate) do
			suffix = suffix + 1
			candidate = name .. "_" .. tostring(suffix)
		end
		regs.__sanitizedLocalNames[key] = candidate
		return candidate
	end

	local function semanticLocalName(reg, atPc)
		local name = localAt(p, reg, atPc or pc) or ("_r" .. tostring(reg))
		return sanitizeLocalName(name, reg)
	end

	local function assignLocalOrExisting(reg, value)
		local lv = locvarAt(p, reg, pc)
		if lv then
			local prefix = lv.startpc == pc and "local " or ""
			local name = sanitizeLocalName(lv.name, reg)
			regs[reg] = name
			return indent .. prefix .. name .. " = " .. value
		end
		return nil
	end

	local function assignGeneratedFlag(reg, value)
		regs.__generatedFlagNames = regs.__generatedFlagNames or {}
		regs.__generatedFlagDeclared = regs.__generatedFlagDeclared or {}
		local name = regs.__generatedFlagNames[reg]
		if not name then
			name = generatedNameFor and generatedNameFor("_flag" .. tostring(reg), "_flag" .. tostring(reg)) or ("_flag" .. tostring(reg))
			regs.__generatedFlagNames[reg] = name
		end
		local prefix = regs.__generatedFlagDeclared[reg] and "" or "local "
		regs.__generatedFlagDeclared[reg] = true
		regs[reg] = name
		return indent .. prefix .. name .. " = " .. value
	end

	local function assignHintedValue(reg, value, hint)
		if not (hint and hint.targetName and isValidIdent(hint.targetName)) then
			return nil
		end
		local targetName = sanitizeLocalName(hint.targetName, reg)
		regs[reg] = targetName
		local prefix = hint.declare and "local " or ""
		return indent .. prefix .. targetName .. " = " .. value
	end

	local function assignNilPhiValue(reg, value)
		local nilPhiHint = flowAnalysis and flowAnalysis.nilPhiHints and flowAnalysis.nilPhiHints[pc] or nil
		if nilPhiHint and nilPhiHint.targetName and isValidIdent(nilPhiHint.targetName) then
			local targetName = sanitizeLocalName(nilPhiHint.targetName, reg)
			regs.__nilPhiDeclared = regs.__nilPhiDeclared or {}
			local prefix = regs.__nilPhiDeclared[reg] and "" or "local "
			regs.__nilPhiDeclared[reg] = true
			regs[reg] = targetName
			return indent .. prefix .. targetName .. " = " .. value
		end
		return nil
	end

	if opName == "LOADNIL" then
		local valuePhiHint = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
		if valuePhiHint and valuePhiHint.targetName and isValidIdent(valuePhiHint.targetName) then
			local targetName = sanitizeLocalName(valuePhiHint.targetName, a)
			regs[a] = targetName
			regs.__nilPhiDeclared = regs.__nilPhiDeclared or {}
			regs.__nilPhiDeclared[a] = true
			return indent .. "local " .. targetName .. " = nil", 0
		end
		local nilPhiHint = flowAnalysis and flowAnalysis.nilPhiHints and flowAnalysis.nilPhiHints[pc] or nil
		if nilPhiHint and nilPhiHint.targetName and isValidIdent(nilPhiHint.targetName) then
			local targetName = sanitizeLocalName(nilPhiHint.targetName, a)
			regs.__nilPhiDeclared = regs.__nilPhiDeclared or {}
			local prefix = regs.__nilPhiDeclared[a] and "" or "local "
			regs.__nilPhiDeclared[a] = true
			regs[a] = targetName
			return indent .. prefix .. targetName .. " = nil", 0
		end
		local branchValueHint = flowAnalysis and flowAnalysis.branchValueHints and flowAnalysis.branchValueHints.initializers and flowAnalysis.branchValueHints.initializers[pc] or nil
		if branchValueHint and branchValueHint.targetName and isValidIdent(branchValueHint.targetName) then
			local targetName = sanitizeLocalName(branchValueHint.targetName, a)
			regs[a] = targetName
			return indent .. "local " .. targetName .. " = nil", 0
		end
		regs[a] = "nil"
		local assigned = assignLocalOrExisting(a, "nil")
		return assigned, 0
	end

	if opName == "LOADB" then
		local value = b ~= 0 and "true" or "false"
		local suffix = c ~= 0 and ("  -- skip " .. tostring(c)) or ""
		local boolHint = flowAnalysis and flowAnalysis.booleanFlagHints and flowAnalysis.booleanFlagHints[pc] or nil
		local hinted = assignHintedValue(a, value .. suffix, boolHint)
		if hinted then
			return hinted, 0
		end
		regs[a] = value
		local assigned = assignLocalOrExisting(a, value .. suffix)
		if assigned then
			return assigned, 0
		end
		-- No locvar binding and no phi/flag hint: do NOT materialize a
		-- `local _flag<reg>` temporary.  The literal value has already been
		-- stored in `regs[a]`, so the next consumer (e.g. `SETTABLEKS T.X = Ra`)
		-- will read the literal directly and emit `T.X = false`, which matches
		-- the natural pre-compile source `T.X = false` instead of the verbose
		-- `_flag<N> = false; T.X = _flag<N>` form.
		return suffix ~= "" and (indent .. "-- LOADB R" .. tostring(a) .. " = " .. value .. suffix) or nil, 0
	end

	if opName == "LOADN" then
		local backEdgeInit = flowAnalysis and flowAnalysis.backEdgeMutationHints and flowAnalysis.backEdgeMutationHints[pc] or nil
		if backEdgeInit and backEdgeInit.isInit and backEdgeInit.reg == a and backEdgeInit.targetName and isValidIdent(backEdgeInit.targetName) then
			local targetName = sanitizeLocalName(backEdgeInit.targetName, a)
			regs[a] = targetName
			return indent .. "local " .. targetName .. " = " .. tostring(d), 0
		end
		local counterName = flowAnalysis and flowAnalysis.counterHints and flowAnalysis.counterHints.initializers and flowAnalysis.counterHints.initializers[pc] or nil
		if counterName and isValidIdent(counterName) then
			regs[a] = counterName
			return indent .. "local " .. counterName .. " = " .. tostring(d), 0
		end
		regs[a] = tostring(d)
		return assignLocalOrExisting(a, tostring(d)), 0
	end

	if opName == "LOADK" or opName == "LOADKC" or opName == "LOADKX" then
		local idx = opName == "LOADKC" and c or (opName == "LOADK" and d or aux)
		local backEdgeInit = flowAnalysis and flowAnalysis.backEdgeMutationHints and flowAnalysis.backEdgeMutationHints[pc] or nil
		if backEdgeInit and backEdgeInit.isInit and backEdgeInit.reg == a and backEdgeInit.targetName and isValidIdent(backEdgeInit.targetName) then
			local targetName = sanitizeLocalName(backEdgeInit.targetName, a)
			regs[a] = targetName
			return indent .. "local " .. targetName .. " = " .. kvalLua(p, idx), 0
		end
		regs[a] = kvalLua(p, idx)
		return assignLocalOrExisting(a, regs[a]), 0
	end

	if opName == "MOVE" then
		local src = rname(b)
		-- Detect FASTCALL arg-prep MOVE: MOVE Rb=Ra preceded by FASTCALL/FASTCALL2/FASTCALL2K
		-- targeting Rb-N (where N is arg count). Such a MOVE is the slow-path arg-prep
		-- and shouldn't materialize as a separate `targetLocal = src` assignment;
		-- the subsequent CALL will inline `src` as an argument expression.
		-- Pattern: FASTCALL Rdest skip=K; ...; MOVE Rb=Ra; ...; GETIMPORT/MOVE Rcall=fn; CALL Rcall(N args)
		-- where Rb >= Rcall+1 and Rb <= Rcall+argcount.
		do
			local scanPc = pc + getOpLength(opName)
			while scanPc < #p.code do
				local si = decodedInsnAt(p, scanPc)
				if si.opName == "CALL" and si.a < a and si.b > 0 and a >= si.a + 1 and a <= si.a + si.b - 1 then
					-- Look back from MOVE to find a FASTCALL whose skip reaches the CALL.
					local probePc = 0
					local lastFastcallPc = nil
					local lastFastcallInfo = nil
					while probePc < pc do
						local pi = decodedInsnAt(p, probePc)
						if pi.opName == "FASTCALL" or pi.opName == "FASTCALL1"
							or pi.opName == "FASTCALL2" or pi.opName == "FASTCALL2K"
							or pi.opName == "FASTCALL3"
						then
							lastFastcallPc = probePc
							lastFastcallInfo = pi
						end
						probePc = probePc + pi.len
					end
					if lastFastcallPc and lastFastcallInfo then
						local fcSkip = lastFastcallInfo.c or 0
						-- skip semantics: PC + 1 + skip lands at the CALL pc when this is arg-prep.
						if lastFastcallPc + fcSkip + 1 == scanPc then
							regs[a] = src
							return nil, 0
						end
					end
					break
				end
				if instrWritesReg(si, a) then break end
				if instrReadsReg(si, a) then break end
				scanPc = scanPc + si.len
			end
		end
		local valuePhiHint = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
		local valuePhiAssigned = assignHintedValue(a, src, valuePhiHint)
		if valuePhiAssigned then
			-- suppress self-assignment no-ops (X = X) that arise when hint name matches src
			local lhs = valuePhiAssigned:match("^%s*local%s+([%a_][%w_]*)%s*=") or valuePhiAssigned:match("^%s*([%a_][%w_]*)%s*=")
			if not (lhs and lhs == src and not (valuePhiHint and valuePhiHint.declare)) then
				return valuePhiAssigned, 0
			end
			-- self-assignment: register already set by assignHintedValue, just skip emission
		end
		local nilPhiHint = flowAnalysis and flowAnalysis.nilPhiHints and flowAnalysis.nilPhiHints[pc] or nil
		if nilPhiHint and nilPhiHint.targetName and isValidIdent(nilPhiHint.targetName) then
			local targetName = sanitizeLocalName(nilPhiHint.targetName, a)
			regs[a] = targetName
			if targetName == src then
				return nil, 0
			end
			return indent .. targetName .. " = " .. src, 0
		end
		local branchValueHint = flowAnalysis and flowAnalysis.branchValueHints and flowAnalysis.branchValueHints.moves and flowAnalysis.branchValueHints.moves[pc] or nil
		if branchValueHint and branchValueHint.targetName and isValidIdent(branchValueHint.targetName) then
			local targetName = sanitizeLocalName(branchValueHint.targetName, a)
			regs[a] = targetName
			-- suppress self-assignment no-ops (X = X)
			if targetName == src then
				return nil, 0
			end
			return indent .. targetName .. " = " .. src, 0
		end
		local aliasHint = flowAnalysis and flowAnalysis.moveAliasHints and flowAnalysis.moveAliasHints[pc] or nil
		if aliasHint
			and aliasHint.targetName
			and aliasHint.sourceName
			and isValidIdent(aliasHint.targetName)
			and isValidIdent(aliasHint.sourceName)
		then
			-- Validate sourceName actually refers to a live local. If `regs[b]` doesn't
			-- match sourceName, the source local was never declared (e.g. because a
			-- callInlineHint replaced the prior CALL's destination), and emitting
			-- `target = sourceName` would reference an undefined identifier.
			local liveSrc = regs[b]
			if liveSrc == aliasHint.sourceName then
				regs[a] = aliasHint.targetName
				return indent .. aliasHint.targetName .. " = " .. aliasHint.sourceName, 0
			end
			-- Source name is stale; fall through to normal MOVE handling so we use
			-- the live regs[b] expression instead.
		end
		local targetLocal = localAt(p, a, pc)
		if targetLocal then
			targetLocal = sanitizeLocalName(targetLocal, a)
			local preferredTracked = preferredTrackedLocalName(regs[a], targetLocal)
			if preferredTracked then
				targetLocal = preferredTracked
			end
			regs[a] = targetLocal
			-- suppress self-assignment no-ops (X = X) that arise when src and dst get the same name
			if targetLocal == src then
				return nil, 0
			end
			return indent .. targetLocal .. " = " .. src, 0
		end
		if a < p.numparams then
			local paramName = localAt(p, a, 0) or ("arg" .. tostring(a))
			if regs[a] == paramName and src ~= paramName then
				return indent .. paramName .. " = " .. src, 0
			end
		end
		regs[a] = src
		return nil, 0
	end

	if opName == "GETIMPORT" then
		local orHint = flowAnalysis and flowAnalysis.orDefaultHints and flowAnalysis.orDefaultHints.fallbacks and flowAnalysis.orDefaultHints.fallbacks[pc] or nil
		if orHint and orHint.reg == a and orHint.expr then
			regs[a] = orHint.expr
			return nil, 0
		end
		local parts = decodeImportId(aux or 0, p)
		local resolved = parts
		local path = #resolved > 0 and table.concat(resolved, ".") or ("import(" .. tostring(d) .. ")")
		local targetLocal = localAt(p, a, pc)
		if targetLocal then
			targetLocal = sanitizeLocalName(targetLocal, a, pc)
			regs[a] = targetLocal
			return indent .. "local " .. targetLocal .. " = " .. path, 0
		end
		regs[a] = path
		return nil, 0
	end

	if opName == "GETUPVAL" then
		local orHint = flowAnalysis and flowAnalysis.orDefaultHints and flowAnalysis.orDefaultHints.fallbacks and flowAnalysis.orDefaultHints.fallbacks[pc] or nil
		if orHint and orHint.reg == a and orHint.expr then
			regs[a] = orHint.expr
			return nil, 0
		end
		local upvalueName = p.upvalues[b + 1] or ("U" .. tostring(b))
		local targetLocal = localAt(p, a, pc)
		if targetLocal then
			targetLocal = sanitizeLocalName(targetLocal, a, pc)
			regs[a] = targetLocal
			return indent .. "local " .. targetLocal .. " = " .. upvalueName, 0
		end
		regs[a] = upvalueName
		return nil, 0
	end

	if opName == "SETUPVAL" then
		local upvalueName = p.upvalues[b + 1] or ("U" .. tostring(b))
		local orHint = flowAnalysis and flowAnalysis.orDefaultHints and flowAnalysis.orDefaultHints.uses and flowAnalysis.orDefaultHints.uses[pc] or nil
		if orHint and orHint.reg == a and orHint.expr then
			regs[a] = orHint.expr
			return indent .. upvalueName .. " = " .. orHint.expr, 0
		end
		return indent .. upvalueName .. " = " .. rname(a), 0
	end

	if opName == "CLOSEUPVALS" then
		return nil, 0
	end

	if opName == "GETGLOBAL" then
		local keyConst = aux ~= nil and constantAt(p, aux) or nil
		local key = keyConst and keyConst.value or ("K[" .. tostring(aux) .. "]")
		regs[a] = key
		local targetLocal = localAt(p, a, pc)
		if targetLocal then
			targetLocal = sanitizeLocalName(targetLocal, a, pc)
			regs[a] = targetLocal
			return indent .. "local " .. targetLocal .. " = " .. tostring(key), 0
		end
		return nil, 0
	end

	if opName == "SETGLOBAL" then
		local keyConst = aux ~= nil and constantAt(p, aux) or nil
		local key = keyConst and keyConst.value or ("K[" .. tostring(aux) .. "]")
		return indent .. tostring(key) .. " = " .. rname(a), 0
	end

	if opName == "GETTABLE" then
		local expr = rname(b) .. "[" .. rname(c) .. "]"
		local nextPc = pc + getOpLength(opName)
		local nextInfo = nextPc < #p.code and decodedInsnAt(p, nextPc) or nil
		if nextInfo
			and (nextInfo.opName == "JUMPIF" or nextInfo.opName == "JUMPIFNOT")
			and nextInfo.a == a
		then
			local targetPc = jumpTargetForInsn(nextInfo)
			local afterGuardPc = nextPc + nextInfo.len
			local scanEnd = targetPc and math.max(afterGuardPc, targetPc - 1) or math.min(#p.code - 1, afterGuardPc + 8)
			local targetInfo = targetPc and targetPc < #p.code and decodedInsnAt(p, targetPc) or nil
			if targetPc and ((targetInfo and instrReadsReg(targetInfo, a)) or regReadBeforeWrite(p, a, afterGuardPc, scanEnd)) then
				if nextInfo.opName == "JUMPIF" then
					local guardFbPc = afterGuardPc
					local guardFbInfo = guardFbPc < #p.code and decodedInsnAt(p, guardFbPc) or nil
					local fbSrc = nil
					if guardFbInfo and guardFbInfo.a == a and guardFbPc + guardFbInfo.len == targetPc then
						if guardFbInfo.opName == "MOVE" then
							fbSrc = rname(guardFbInfo.b)
						elseif guardFbInfo.opName == "GETTABLEKS" then
							local fbAux2 = OPS_WITH_AUX[guardFbInfo.opName] and guardFbPc + 1 < #p.code and codeWordAt(p, guardFbPc + 1) or nil
							local fbIdx2 = fbAux2 ~= nil and fbAux2 or guardFbInfo.d
							local fbKeyConst = constantAt(p, fbIdx2)
							local fbKey = fbKeyConst and fbKeyConst.kind == "string" and fbKeyConst.value or nil
							if fbKey then
								fbSrc = rname(guardFbInfo.b) .. luaIndexSuffix(fbKey)
							end
						end
					end
					if fbSrc then
						local guardPhiHint2 = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
						local tname = (guardPhiHint2 and guardPhiHint2.targetName and isValidIdent(guardPhiHint2.targetName) and guardPhiHint2.targetName)
							or localAt(p, a, guardFbPc)
							or cleanGeneratedIdent(deriveNameHint(expr))
							or semanticLocalName(a, pc)
						if tname and isValidIdent(tname) then
							tname = sanitizeLocalName(tname, a, guardFbPc)
							regs[a] = tname
							local orExpr = "(" .. expr .. " or " .. fbSrc .. ")"
							return indent .. "local " .. tname .. " = " .. orExpr, nextInfo.len + guardFbInfo.len
						end
					end
				end
				local guardPhiHint = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
				local targetName = (guardPhiHint and guardPhiHint.targetName and isValidIdent(guardPhiHint.targetName) and guardPhiHint.targetName)
					or localAt(p, a, pc)
					or cleanGeneratedIdent(deriveNameHint(expr))
					or semanticLocalName(a, pc)
				if targetName and isValidIdent(targetName) then
					targetName = sanitizeLocalName(targetName, a, pc)
					regs[a] = targetName
					return indent .. "local " .. targetName .. " = " .. expr, 0
				end
			end
		end
		local nilPhiAssigned = assignNilPhiValue(a, expr)
		if nilPhiAssigned then
			return nilPhiAssigned, 0
		end
		local valuePhiHint = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
		local valuePhiAssigned = assignHintedValue(a, expr, valuePhiHint)
		if valuePhiAssigned then
			return valuePhiAssigned, 0
		end
		local targetLocal = localAt(p, a, pc)
		if targetLocal then
			targetLocal = sanitizeLocalName(targetLocal, a, pc)
			regs[a] = targetLocal
			return indent .. "local " .. targetLocal .. " = " .. expr, 0
		end
		local trackedNilPhi = regs.__nilPhiDeclared and regs.__nilPhiDeclared[a] and regs[a] or nil
		if trackedNilPhi and isValidIdent(trackedNilPhi) and trackedNilPhi ~= expr then
			regs[a] = trackedNilPhi
			return indent .. trackedNilPhi .. " = " .. expr, 0
		end
		regs[a] = expr
		return nil, 0
	end

	if opName == "SETTABLE" then
		return indent .. rname(b) .. "[" .. rname(c) .. "] = " .. rname(a), 0
	end

	if opName == "GETTABLEKS" then
		local orHint = flowAnalysis and flowAnalysis.orDefaultHints and flowAnalysis.orDefaultHints.fallbacks and flowAnalysis.orDefaultHints.fallbacks[pc] or nil
		if orHint and orHint.reg == a and orHint.expr then
			regs[a] = orHint.expr
			return nil, 0
		end
		local idx = aux ~= nil and aux or d
		local keyConst = constantAt(p, idx)
		local key = keyConst and keyConst.kind == "string" and keyConst.value or ("K[" .. tostring(idx) .. "]")
		local baseExpr = rname(b)
		local expr = baseExpr .. luaIndexSuffix(key)
		local nextPc = pc + getOpLength(opName)
		local nextInfo = nextPc < #p.code and decodedInsnAt(p, nextPc) or nil
		if nextInfo
			and (nextInfo.opName == "JUMPIF" or nextInfo.opName == "JUMPIFNOT")
			and nextInfo.a == a
		then
			local targetPc = jumpTargetForInsn(nextInfo)
			local afterGuardPc = nextPc + nextInfo.len
			local scanEnd = targetPc and math.max(afterGuardPc, targetPc - 1) or math.min(#p.code - 1, afterGuardPc + 8)
			local targetInfo = targetPc and targetPc < #p.code and decodedInsnAt(p, targetPc) or nil
			if targetPc and ((targetInfo and instrReadsReg(targetInfo, a)) or regReadBeforeWrite(p, a, afterGuardPc, scanEnd)) then
				-- Check: is this actually an or-default? (JUMPIF Ra; fallback Ra=...; merge right after fallback)
				if nextInfo.opName == "JUMPIF" then
					local guardFbPc = afterGuardPc
					local guardFbInfo = guardFbPc < #p.code and decodedInsnAt(p, guardFbPc) or nil
					local fbSrc = nil
					if guardFbInfo and guardFbInfo.a == a and guardFbPc + guardFbInfo.len == targetPc then
						if guardFbInfo.opName == "MOVE" then
							fbSrc = rname(guardFbInfo.b)
						elseif guardFbInfo.opName == "GETTABLEKS" then
							local fbAux2 = OPS_WITH_AUX[guardFbInfo.opName] and guardFbPc + 1 < #p.code and codeWordAt(p, guardFbPc + 1) or nil
							local fbIdx2 = fbAux2 ~= nil and fbAux2 or guardFbInfo.d
							local fbKeyConst = constantAt(p, fbIdx2)
							local fbKey = fbKeyConst and fbKeyConst.kind == "string" and fbKeyConst.value or nil
							if fbKey then
								fbSrc = rname(guardFbInfo.b) .. luaIndexSuffix(fbKey)
							end
						elseif guardFbInfo.opName == "LOADNIL" then
							fbSrc = "nil"
						end
					end
					if fbSrc then
						-- Scan backward for outer JUMPIFNOT guard (for ((base) and (chain)) or fallback)
						local outerGuardExpr2 = nil
						local chainStartPc2 = pc
						local scanBack2 = pc
						while scanBack2 >= 2 do
							local candPc2 = scanBack2 - 2
							if candPc2 >= 0 then
								local candInfo2 = decodedInsnAt(p, candPc2)
								if candInfo2.opName == "GETTABLEKS" and candInfo2.a == a and candPc2 + candInfo2.len == scanBack2 then
									chainStartPc2 = candPc2
									scanBack2 = candPc2
								else
									break
								end
							else
								break
							end
						end
						if chainStartPc2 >= 1 then
							local outerGuardPc2 = chainStartPc2 - 1
							local outerGuardInfo2 = outerGuardPc2 >= 0 and decodedInsnAt(p, outerGuardPc2) or nil
							local outerTarget2 = outerGuardInfo2 and jumpTargetForInsn(outerGuardInfo2) or nil
							if outerGuardInfo2
								and outerGuardInfo2.opName == "JUMPIFNOT"
								and outerGuardInfo2.a ~= a
								and (outerTarget2 == targetPc or outerTarget2 == guardFbPc)
							then
								local outerBase2 = rname(outerGuardInfo2.a)
								if outerBase2 and isValidIdent(outerBase2) then
									outerGuardExpr2 = "((" .. outerBase2 .. ") and (" .. expr .. ")) or " .. fbSrc
								end
							end
						end
						local guardPhiHint2 = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
						local tname = (guardPhiHint2 and guardPhiHint2.targetName and isValidIdent(guardPhiHint2.targetName) and guardPhiHint2.targetName)
							or localAt(p, a, guardFbPc)
							or cleanGeneratedIdent(deriveNameHint(expr))
							or semanticLocalName(a, pc)
						if tname and isValidIdent(tname) then
							tname = sanitizeLocalName(tname, a, guardFbPc)
							regs[a] = tname
							local orExpr = outerGuardExpr2 or ("(" .. expr .. " or " .. fbSrc .. ")")
							local declared = regs.__nilPhiDeclared and regs.__nilPhiDeclared[a]
							local prefix = declared and "" or "local "
							if not declared then
								regs.__nilPhiDeclared = regs.__nilPhiDeclared or {}
								regs.__nilPhiDeclared[a] = true
							end
							return indent .. prefix .. tname .. " = " .. orExpr, nextInfo.len + guardFbInfo.len
						end
					end
				end
				local guardPhiHint = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
				local targetName = (guardPhiHint and guardPhiHint.targetName and isValidIdent(guardPhiHint.targetName) and guardPhiHint.targetName)
					or localAt(p, a, pc)
					or cleanGeneratedIdent(deriveNameHint(expr))
					or semanticLocalName(a, pc)
				if targetName and isValidIdent(targetName) then
					targetName = sanitizeLocalName(targetName, a, pc)
					regs[a] = targetName
					return indent .. "local " .. targetName .. " = " .. expr, 0
				end
			end
		end
		if nextInfo and nextInfo.opName == "JUMPIF" and nextInfo.a == a then
			local mergePc = jumpTargetForInsn(nextInfo)
			local mergeInfo = mergePc and mergePc < #p.code and decodedInsnAt(p, mergePc) or nil
			local targetName = mergePc and (localAt(p, a, mergePc) or preferredTrackedLocalName(a, pc) or cleanGeneratedIdent(deriveNameHint(expr)) or semanticLocalName(a, pc)) or nil
			if targetName and isValidIdent(targetName) then
				targetName = sanitizeLocalName(targetName, a, mergePc)
			end
			local sawFallbackCall = false
			local onlyFallbackWrites = mergePc ~= nil
			local scanPc = nextPc + nextInfo.len
			while mergePc and scanPc < mergePc do
				local scanInfo = decodedInsnAt(p, scanPc)
				if instrWritesReg(scanInfo, a) then
					if scanInfo.opName == "CALL" then
						sawFallbackCall = true
					elseif scanInfo.opName ~= "NAMECALL" then
						onlyFallbackWrites = false
						break
					end
				end
				scanPc = scanPc + scanInfo.len
			end
			if mergePc
				and mergeInfo
				and instrReadsReg(mergeInfo, a)
				and sawFallbackCall
				and onlyFallbackWrites
				and targetName
				and isValidIdent(targetName)
			then
				regs[a] = targetName
				regs.__guardedFallbackTargets = regs.__guardedFallbackTargets or {}
				regs.__guardedFallbackTargets[a] = {
					targetName = targetName,
					mergePc = mergePc,
				}
				return indent .. "local " .. targetName .. " = " .. expr, 0
			end
		end
		if nextInfo and nextInfo.opName == "JUMPIFNOT" and nextInfo.a == a then
			local fallbackPc = jumpTargetForInsn(nextInfo)
			local innerPc = nextPc + nextInfo.len
			local innerInfo = innerPc < #p.code and decodedInsnAt(p, innerPc) or nil
			local innerAux = innerInfo and OPS_WITH_AUX[innerInfo.opName] and innerPc + 1 < #p.code and codeWordAt(p, innerPc + 1) or nil
			local innerKeyConst = innerInfo and innerInfo.opName == "GETTABLEKS" and constantAt(p, innerAux ~= nil and innerAux or innerInfo.d) or nil
			local innerKey = innerKeyConst and innerKeyConst.kind == "string" and innerKeyConst.value or nil
			local valuePc = innerInfo and (innerPc + innerInfo.len) or nil
			local valueInfo = valuePc and valuePc < #p.code and decodedInsnAt(p, valuePc) or nil
			local valueAux = valueInfo and OPS_WITH_AUX[valueInfo.opName] and valuePc + 1 < #p.code and codeWordAt(p, valuePc + 1) or nil
			local valueKeyConst = valueInfo and valueInfo.opName == "GETTABLEKS" and constantAt(p, valueAux ~= nil and valueAux or valueInfo.d) or nil
			local valueKey = valueKeyConst and valueKeyConst.kind == "string" and valueKeyConst.value or nil
			local guardPc = valueInfo and (valuePc + valueInfo.len) or nil
			local guardInfo = guardPc and guardPc < #p.code and decodedInsnAt(p, guardPc) or nil
			local fallbackInfo = fallbackPc and fallbackPc < #p.code and decodedInsnAt(p, fallbackPc) or nil
			if fallbackPc
				and innerInfo
				and innerInfo.opName == "GETTABLEKS"
				and innerInfo.b == b
				and innerKey == key
				and valueInfo
				and valueInfo.opName == "GETTABLEKS"
				and valueInfo.a == innerInfo.a
				and valueInfo.b == innerInfo.a
				and valueKey
				and guardInfo
				and guardInfo.opName == "JUMPIF"
				and guardInfo.a == valueInfo.a
				and fallbackInfo
				and fallbackInfo.opName == "LOADNIL"
				and fallbackInfo.a == valueInfo.a
				and jumpTargetForInsn(guardInfo) == fallbackPc + fallbackInfo.len
			then
				local guardedExpr = expr .. luaIndexSuffix(valueKey)
				local targetName = localAt(p, valueInfo.a, fallbackPc) or cleanGeneratedIdent(deriveNameHint(guardedExpr)) or semanticLocalName(valueInfo.a, pc)
				if targetName and isValidIdent(targetName) then
					targetName = sanitizeLocalName(targetName, valueInfo.a, fallbackPc)
					regs[a] = expr
					regs[valueInfo.a] = targetName
					return indent .. "local " .. targetName .. " = ((" .. expr .. ") and (" .. guardedExpr .. ")) or nil", (fallbackPc + fallbackInfo.len) - nextPc
				end
			end
		end
		if nextInfo and nextInfo.opName == "JUMPIF" and nextInfo.a == a then
			local mergePc = jumpTargetForInsn(nextInfo)
			local fallbackPc = nextPc + nextInfo.len
			local fallbackInfo = fallbackPc < #p.code and decodedInsnAt(p, fallbackPc) or nil
			if mergePc
				and fallbackInfo
				and fallbackInfo.opName == "LOADNIL"
				and fallbackInfo.a == a
				and fallbackPc + fallbackInfo.len == mergePc
			then
				local nilPhiHint = flowAnalysis and flowAnalysis.nilPhiHints and flowAnalysis.nilPhiHints[pc] or nil
				local targetName = nilPhiHint and nilPhiHint.targetName or localAt(p, a, fallbackPc) or cleanGeneratedIdent(deriveNameHint(expr)) or semanticLocalName(a, pc)
				if targetName and isValidIdent(targetName) then
					targetName = sanitizeLocalName(targetName, a, fallbackPc)
					regs[a] = targetName
					return indent .. "local " .. targetName .. " = ((" .. baseExpr .. ") and (" .. expr .. ")) or nil", nextInfo.len + fallbackInfo.len
				end
			end
		end
		if nextInfo and nextInfo.opName == "JUMPIF" and nextInfo.a == a then
			local orMergePc = jumpTargetForInsn(nextInfo)
			local orFallbackPc = nextPc + nextInfo.len
			local orFallbackInfo = orFallbackPc < #p.code and decodedInsnAt(p, orFallbackPc) or nil
			local fallbackSrc = nil
			
			if orMergePc and orFallbackInfo and orFallbackInfo.a == a and orFallbackPc + orFallbackInfo.len == orMergePc then
				if orFallbackInfo.opName == "MOVE" then
					fallbackSrc = rname(orFallbackInfo.b)
				elseif orFallbackInfo.opName == "GETTABLEKS" then
					local fbAux3 = OPS_WITH_AUX[orFallbackInfo.opName] and orFallbackPc + 1 < #p.code and codeWordAt(p, orFallbackPc + 1) or nil
					local fbIdx3 = fbAux3 ~= nil and fbAux3 or orFallbackInfo.d
					local fbKeyConst3 = constantAt(p, fbIdx3)
					local fbKey3 = fbKeyConst3 and fbKeyConst3.kind == "string" and fbKeyConst3.value or nil
					if fbKey3 then
						fallbackSrc = rname(orFallbackInfo.b) .. luaIndexSuffix(fbKey3)
					end
				end
			end
			if fallbackSrc then
				-- Check for outer JUMPIFNOT guard targeting the same fallback
				local outerGuardExpr = nil
				local chainStartPc = pc
				local scanBack = pc
				while scanBack >= 2 do
					local candPc = scanBack - 2
					if candPc >= 0 then
						local candInfo = decodedInsnAt(p, candPc)
						if candInfo.opName == "GETTABLEKS" and candInfo.a == a and candPc + candInfo.len == scanBack then
							chainStartPc = candPc
							scanBack = candPc
						else
							break
						end
					else
						break
					end
				end
				if chainStartPc >= 1 then
					local prevPc = chainStartPc - 1
					if prevPc >= 0 then
						local prevInfo = decodedInsnAt(p, prevPc)
						if prevInfo.opName == "JUMPIFNOT"
							and jumpTargetForInsn(prevInfo) == orFallbackPc
						then
							outerGuardExpr = rname(prevInfo.a)
						end
					end
				end
				local orExpr
				if outerGuardExpr then
					orExpr = "((" .. outerGuardExpr .. ") and (" .. expr .. ")) or " .. fallbackSrc
				else
					orExpr = "(" .. expr .. " or " .. fallbackSrc .. ")"
				end
				local vph = flowAnalysis and flowAnalysis.valuePhiHints
				local targetName = (vph and vph[pc] and vph[pc].targetName)
					or (vph and vph[orFallbackPc] and vph[orFallbackPc].targetName)
					or localAt(p, a, orFallbackPc)
					or cleanGeneratedIdent(deriveNameHint(expr))
					or semanticLocalName(a, pc)
				if targetName and isValidIdent(targetName) then
					targetName = sanitizeLocalName(targetName, a, orFallbackPc)
					regs[a] = targetName
					local declared = regs.__nilPhiDeclared and regs.__nilPhiDeclared[a]
					local prefix = declared and "" or "local "
					if not declared then
						regs.__nilPhiDeclared = regs.__nilPhiDeclared or {}
						regs.__nilPhiDeclared[a] = true
					end
					return indent .. prefix .. targetName .. " = " .. orExpr, nextInfo.len + orFallbackInfo.len
				end
			end
		end
		local nilPhiAssigned = assignNilPhiValue(a, expr)
		if nilPhiAssigned then
			return nilPhiAssigned, 0
		end
		local valuePhiHint = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
		local valuePhiAssigned = assignHintedValue(a, expr, valuePhiHint)
		if valuePhiAssigned then
			return valuePhiAssigned, 0
		end
		local targetLocal = localAt(p, a, pc)
		if targetLocal then
			targetLocal = sanitizeLocalName(targetLocal, a, pc)
			regs[a] = targetLocal
			return indent .. "local " .. targetLocal .. " = " .. expr, 0
		end
		local trackedNilPhi = regs.__nilPhiDeclared and regs.__nilPhiDeclared[a] and regs[a] or nil
		if trackedNilPhi and isValidIdent(trackedNilPhi) and trackedNilPhi ~= expr then
			regs[a] = trackedNilPhi
			return indent .. trackedNilPhi .. " = " .. expr, 0
		end
		-- Stale snapshot: this GETTABLEKS captures a snapshot that's later
		-- invalidated by a SETTABLEKS to the same field. Materialize as a real
		-- local to preserve the snapshot value.
		local staleHint = flowAnalysis and flowAnalysis.staleSnapshotHints and flowAnalysis.staleSnapshotHints[pc] or nil
		if staleHint and staleHint.reg == a and staleHint.targetName and isValidIdent(staleHint.targetName) then
			local targetName = sanitizeLocalName(staleHint.targetName, a, pc)
			regs[a] = targetName
			regs.__materialized = regs.__materialized or {}
			regs.__materialized[targetName] = true
			return indent .. "local " .. targetName .. " = " .. expr, 0
		end
		regs[a] = expr
		return nil, 0
	end

	if opName == "SETTABLEKS" then
		local idx = aux ~= nil and aux or d
		local keyConst = constantAt(p, idx)
		local key = keyConst and keyConst.kind == "string" and keyConst.value or ("K[" .. tostring(idx) .. "]")
		return indent .. rname(b) .. luaIndexSuffix(key) .. " = " .. rname(a), 0
	end

	if opName == "GETTABLEN" then
		regs[a] = rname(b) .. "[" .. tostring(c + 1) .. "]"
		return nil, 0
	end

	if opName == "SETTABLEN" then
		return indent .. rname(b) .. "[" .. tostring(c + 1) .. "] = " .. rname(a), 0
	end

	if opName == "NAMECALL" then
		local keyConst = aux ~= nil and constantAt(p, aux) or nil
		local key = keyConst and keyConst.value or ("K[" .. tostring(aux) .. "]")
		local receiver = rname(b)
		if not simpleExpressionReceiver(receiver) then
			receiver = "(" .. receiver .. ")"
		end
		regs[a] = receiver .. ":" .. tostring(key)
		regs[a + 1] = receiver
		return nil, 0
	end

	if opName == "CALL" then
		local callee = regs[a] or ("R" .. tostring(a))
		local isNamecall = string.find(callee:match("[^.]+$") or callee, ":", 1, true) ~= nil
		local args
		if b == 0 then
			local argParts = {}
			if previousMultretCallReg and previousMultretCallReg >= a + 1 then
				for reg = a + 1, previousMultretCallReg do
					push(argParts, rname(reg))
				end
				if isNamecall and #argParts > 0 then
					table.remove(argParts, 1)
				end
				args = table.concat(argParts, ", ")
			else
				local maxArgReg = a
				for reg = a + 1, math.min(a + 12, p.maxstacksize - 1) do
					local value = regs[reg]
					if not value or value == ("R" .. tostring(reg)) then
						break
					end
					maxArgReg = reg
				end
				for reg = a + 1, maxArgReg do
					push(argParts, rname(reg))
				end
				if isNamecall and #argParts > 0 then
					table.remove(argParts, 1)
				end
				args = table.concat(argParts, ", ")
			end
		else
			local argParts = {}
			for reg = a + 1, a + b - 1 do
				push(argParts, rname(reg))
			end
			if isNamecall and #argParts > 0 then
				table.remove(argParts, 1)
			end
			args = table.concat(argParts, ", ")
		end
		local callExpr = callee .. "(" .. args .. ")"
		local closureWriteCaptures = regs.__closureWriteCaptures
		if closureWriteCaptures and (callee == "pcall" or callee == "xpcall") then
			local callbackExpr = regs[a + 1]
			local writableCaptures = type(callbackExpr) == "string" and closureWriteCaptures[callbackExpr] or nil
			if writableCaptures then
				for _, capture in ipairs(writableCaptures) do
					if type(capture) == "table"
						and type(capture.reg) == "number"
						and type(capture.name) == "string"
						and isValidIdent(capture.name)
					then
						regs[capture.reg] = capture.name
					end
				end
			end
		end
		if c == 1 then
			return indent .. callExpr, 0
		end
		if c == 0 then
			regs[a] = callExpr
			regs.__lastMultretCallReg = a
			return nil, 0
		end
		local names = {}
		local hint = deriveNameHint(callExpr, functionName)
		local flowNameHint = flowAnalysis and flowAnalysis.callResultHints and flowAnalysis.callResultHints[pc] or nil
		local valuePhiHint = flowAnalysis and flowAnalysis.valuePhiHints and flowAnalysis.valuePhiHints[pc] or nil
		local callInlineHint = flowAnalysis and flowAnalysis.callInlineHints and flowAnalysis.callInlineHints[pc] or nil
		if callInlineHint and c == 2 then
			local destReg = callInlineHint.destReg
			local destName = regs[destReg]
			if destName and isValidIdent(destName) and not destName:match("^R%d+$") then
				regs[a] = destName
				-- Determine whether `destName` has been declared as a local before
				-- this point. Generated names (_r<N>, _r<N>_<M>, _value_<N>,
				-- _flag<N>, etc.) created by the analysis pass are never
				-- pre-declared, so they need a `local` prefix on first use.
				-- Names that match a debug locvar OR a parameter are already in
				-- scope.
				local needLocal = false
				if not localAt(p, destReg, pc) and destReg >= (p.numparams or 0) then
					-- No debug locvar AND not a parameter: was the name declared
					-- by an earlier rendered statement? Use a per-scope marker
					-- to track this.
					regs.__callInlineDeclared = regs.__callInlineDeclared or {}
					if not regs.__callInlineDeclared[destName] then
						-- Only emit `local` for names that look generated
						if destName:match("^_r%d+") or destName:match("^_value_") or destName:match("^_flag") then
							needLocal = true
						end
						regs.__callInlineDeclared[destName] = true
					end
				end
				local prefix = needLocal and "local " or ""
				return indent .. prefix .. destName .. " = " .. callExpr, 0
			end
		end
		local guardedFallbackTarget = regs.__guardedFallbackTargets and regs.__guardedFallbackTargets[a] or nil
		if guardedFallbackTarget and guardedFallbackTarget.targetName and isValidIdent(guardedFallbackTarget.targetName) and c == 2 then
			local targetName = sanitizeLocalName(guardedFallbackTarget.targetName, a)
			regs[a] = targetName
			return indent .. targetName .. " = " .. callExpr, 0
		end
		if valuePhiHint and valuePhiHint.targetName and isValidIdent(valuePhiHint.targetName) then
			local targetName = sanitizeLocalName(valuePhiHint.targetName, a)
			regs[a] = targetName
			if c > 2 then
				for reg = a + 1, a + c - 2 do
					local name = localAt(p, reg, pc + 1)
					if not name then
						if generatedNameFor then
							name = generatedNameFor("_r" .. tostring(reg), "_r" .. tostring(reg))
						else
							name = "_r" .. tostring(reg)
						end
					end
					regs[reg] = name
					push(names, name)
				end
			end
			local lhs = targetName
			if #names > 0 then
				lhs = lhs .. ", " .. table.concat(names, ", ")
			end
			local prefix = valuePhiHint.declare and "local " or ""
			return indent .. prefix .. lhs .. " = " .. callExpr, 0
		end
		for k = 0, c - 2 do
			local name = localAt(p, a + k, pc + 1)
			if not name then
				local preferredHint = k == 0 and type(flowNameHint) == "string" and flowNameHint or hint
				if generatedNameFor then
					name = generatedNameFor(preferredHint, "_r" .. tostring(a + k))
				else
					name = "_r" .. tostring(a + k)
				end
			end
			push(names, name)
			regs[a + k] = name
		end
		return indent .. "local " .. table.concat(names, ", ") .. " = " .. callExpr, 0
	end

	-- Detect the boolean-skip-LOADB-pair-feeding-JUMPIF[NOT] pattern:
	--   <COND_JUMP> -> pcT       ; conditional jump
	--   pc_skip = pc + len_cond  ; LOADB Ra = X, skip 1
	--   pcT     = pc_skip + 1    ; LOADB Ra = !X
	--   pc_use  = pcT + 1        ; JUMPIF/JUMPIFNOT Ra -> pcE
	-- Net semantics: the JUMPIF[NOT] will jump to pcE iff the original COND_JUMP
	-- did/didn't take. We can collapse 4 instructions into a single
	-- `if [appropriate cond] then goto pcE end` and skip past the boolean
	-- machinery. This is the encoding the compiler emits when the source
	-- `if EXPR then XXX end` was complex enough to require a temporary boolean.
	-- Returns: { pcE = N, invertCond = bool, extraConsume = N } or nil.
	local function detectBoolSkipPattern(condJumpInfo)
		if not condJumpInfo then return nil end
		local condTarget = jumpTargetForInsn(condJumpInfo)
		if not condTarget then return nil end
		local pcSkip = condJumpInfo.pc + condJumpInfo.len
		if pcSkip >= #p.code then return nil end
		local skipInfo = decodedInsnAt(p, pcSkip)
		if skipInfo.opName ~= "LOADB" or skipInfo.c ~= 1 then return nil end
		local pcT = pcSkip + skipInfo.len
		if pcT ~= condTarget then return nil end
		if pcT >= #p.code then return nil end
		local tInfo = decodedInsnAt(p, pcT)
		if tInfo.opName ~= "LOADB" or tInfo.a ~= skipInfo.a then return nil end
		-- The two LOADBs must store opposite values
		if (skipInfo.b ~= 0) == (tInfo.b ~= 0) then return nil end
		local pcUse = pcT + tInfo.len
		if pcUse >= #p.code then return nil end
		local useInfo = decodedInsnAt(p, pcUse)
		if useInfo.opName ~= "JUMPIF" and useInfo.opName ~= "JUMPIFNOT" then return nil end
		if useInfo.a ~= skipInfo.a then return nil end
		local pcE = jumpTargetForInsn(useInfo)
		if not pcE then return nil end
		-- Determine: when does Ra trigger JUMPIF[NOT] to jump?
		--   skipInfo.b : value of Ra when cond_jump did NOT take (fall-through to pc_skip)
		--   tInfo.b    : value of Ra when cond_jump TOOK (jumped to pcT)
		local fallthroughVal = skipInfo.b ~= 0
		local takenVal = tInfo.b ~= 0
		-- JUMPIF triggers when Ra is true; JUMPIFNOT triggers when Ra is false.
		local triggerVal = useInfo.opName == "JUMPIF"
		-- Jump to pcE iff Ra == triggerVal. Ra equals triggerVal in exactly one of
		-- the two paths (taken vs fall-through) since takenVal != fallthroughVal.
		local jumpToEWhenTaken = (takenVal == triggerVal)
		local totalExtraConsume = skipInfo.len + tInfo.len + useInfo.len
		return {
			pcE = pcE,
			invertCond = not jumpToEWhenTaken,
			extraConsume = totalExtraConsume,
		}
	end

	-- A second LOADB pair pattern where the bool is consumed by a non-jump
	-- instruction (typically SETTABLEKS, CALL arg, MOVE, etc.).
	-- Shape:
	--   pc-prev: LOADB Ra = X       (no skip, c = 0)
	--   ... (any number of computations not writing Ra)
	--   pc:      cond_jump to (pc + len + 1) i.e. skipping over ONE LOADB
	--   pc+len:  LOADB Ra = !X      (c = 0)
	--   pc+len+1 (=condTarget): consumer of Ra
	-- Net: Ra after pc+len+1 equals X if cond took, !X otherwise.
	-- This corresponds to source code like `Ra = (cond_expr)` where the cond
	-- evaluates such that "cond took" implies Ra == X.
	-- Returns: { reg = Ra, condTookVal = bool, extraConsume = 0 } — caller is
	-- responsible for handling the FRONT LOADB Ra=X (it's already been written
	-- to regs[a]). We consume the BACK LOADB Ra=!X but DO NOT emit it; the
	-- replacement assignment is emitted in place of the cond_jump rendering.
	local function detectBoolPostJumpPair(condJumpInfo)
		if not condJumpInfo then return nil end
		local condTarget = jumpTargetForInsn(condJumpInfo)
		if not condTarget then return nil end
		local pcAfterJump = condJumpInfo.pc + condJumpInfo.len
		if pcAfterJump >= #p.code then return nil end
		local backInfo = decodedInsnAt(p, pcAfterJump)
		if backInfo.opName ~= "LOADB" or backInfo.c ~= 0 then return nil end
		local pcAfterBack = pcAfterJump + backInfo.len
		if pcAfterBack ~= condTarget then return nil end
		local reg = backInfo.a
		local backVal = backInfo.b ~= 0
		-- Find the most-recent LOADB write to `reg` BEFORE condJumpInfo, with
		-- c=0 and no other writes to `reg` in between. We scan back at most
		-- a few instructions to keep this targeted.
		local frontPc = nil
		local frontVal = nil
		do
			local probe = condJumpInfo.pc
			local hops = 0
			while probe > 0 and hops < 32 do
				local prev = decodedInsnAt(p, probe - 1)  -- not safe — instructions vary in length
				-- Better: walk forward from a known earlier pc. Use the cfg's
				-- block start to bound the search.
				break
			end
		end
		-- Fallback: walk forward from start of the block (cfg.pcToBlock) up to
		-- but not including condJumpInfo.pc, recording the last LOADB(reg).
		do
			local block = cfg and cfg.pcToBlock and cfg.pcToBlock[condJumpInfo.pc] or nil
			if not block then return nil end
			local pcScan = block.startPc
			while pcScan < condJumpInfo.pc do
				local si = decodedInsnAt(p, pcScan)
				if instrWritesReg(si, reg) then
					if si.opName == "LOADB" and si.c == 0 then
						frontPc = pcScan
						frontVal = si.b ~= 0
					else
						frontPc = nil
						frontVal = nil
					end
				end
				pcScan = pcScan + si.len
			end
		end
		if frontPc == nil or frontVal == nil then return nil end
		-- Front and back must be opposite values.
		if frontVal == backVal then return nil end
		-- Verify the consumer at condTarget actually reads `reg`.
		if condTarget >= #p.code then return nil end
		local consumerInfo = decodedInsnAt(p, condTarget)
		if not instrReadsReg(consumerInfo, reg) then return nil end
		-- frontVal: value of Ra when cond TOOK (jumped over backInfo)
		-- backVal: value of Ra when cond DIDN'T take (fell through to backInfo)
		return {
			reg = reg,
			frontPc = frontPc,
			frontVal = frontVal,
			backPc = pcAfterJump,
			backVal = backVal,
			extraConsume = backInfo.len,  -- consume the back LOADB
		}
	end

	if opName == "RETURN" then
		if b == 0 then
			return indent .. "return " .. rname(a), 0
		end
		if b == 1 then
			return indent .. "return", 0
		end
		local values = {}
		for i = 0, b - 2 do
			push(values, rname(a + i))
		end
		return indent .. "return " .. table.concat(values, ", "), 0
	end

	if opName == "NEWCLOSURE" then
		local childId = childProtoIdAt(p, d)
		regs[a] = "<closure proto[" .. tostring(childId or "?") .. "]>"
		return nil, 0
	end

	if opName == "DUPCLOSURE" then
		regs[a] = "<closure K" .. tostring(d) .. ">"
		return nil, 0
	end

	if opName == "NEWTABLE" then
		local orHint = flowAnalysis and flowAnalysis.orDefaultHints and flowAnalysis.orDefaultHints.fallbacks and flowAnalysis.orDefaultHints.fallbacks[pc] or nil
		if orHint and orHint.reg == a and orHint.expr then
			regs[a] = orHint.expr
			return nil, 0
		end
		-- Try to derive a name from the first SETTABLEKS that sets a field on this register
		local name = nil
		if not localAt(p, a, pc) then
			local scanPc = pc + getOpLength(opName)
			local limit = math.min(#p.code - 1, scanPc + 32)
			while scanPc <= limit do
				local si = decodedInsnAt(p, scanPc)
				if instrWritesReg(si, a) then break end  -- reg overwritten before first use
				if si.opName == "SETTABLEKS" and si.b == a then
					local auxVal = OPS_WITH_AUX[si.opName] and scanPc + 1 < #p.code and codeWordAt(p, scanPc + 1) or nil
					local kidx = auxVal ~= nil and auxVal or si.d
					local kc = constantAt(p, kidx)
					if kc and kc.kind == "string" and isValidIdent(kc.value) then
						local hint = cleanGeneratedIdent(kc.value)
						if hint and isValidIdent(hint) and not hint:match("^_r%d") then
								name = generatedNameFor and generatedNameFor(hint, "_r" .. tostring(a)) or sanitizeLocalName(hint, a)
						end
					end
					break
				end
				scanPc = scanPc + si.len
			end
		end
		name = name or semanticLocalName(a, pc)
		regs[a] = name
		return indent .. "local " .. name .. " = {}", 0
	end
	if opName == "DUPTABLE" then
		local orHint = flowAnalysis and flowAnalysis.orDefaultHints and flowAnalysis.orDefaultHints.fallbacks and flowAnalysis.orDefaultHints.fallbacks[pc] or nil
		if orHint and orHint.reg == a and orHint.expr then
			regs[a] = orHint.expr
			return nil, 0
		end
		-- Derive name from first meaningful SETTABLEKS that sets a field on this register
		local name = nil
		if not localAt(p, a, pc) then
			-- Try from constant template keys (table_kv has fields already)
			local dc = constantAt(p, d)
			if dc and dc.kind == "table_kv" and #dc.value > 0 then
				for _, pair in ipairs(dc.value) do
					local kc = constantAt(p, pair.k_idx)
					if kc and kc.kind == "string" and isValidIdent(kc.value) and #kc.value > 2 then
						local hint = cleanGeneratedIdent(kc.value)
						if hint and not hint:match("^_r%d") then
							name = generatedNameFor and generatedNameFor(hint, "_r" .. tostring(a)) or sanitizeLocalName(hint, a)
							break
						end
					end
				end
			end
			-- Fallback: scan forward for first SETTABLEKS on this register
			if not name then
				local scanPc = pc + getOpLength(opName)
				local limit = math.min(#p.code - 1, scanPc + 32)
				while scanPc <= limit do
					local si = decodedInsnAt(p, scanPc)
					if instrWritesReg(si, a) then break end
					if si.opName == "SETTABLEKS" and si.b == a then
						local auxVal = OPS_WITH_AUX[si.opName] and scanPc + 1 < #p.code and codeWordAt(p, scanPc + 1) or nil
						local kidx = auxVal ~= nil and auxVal or si.d
						local kc = constantAt(p, kidx)
						if kc and kc.kind == "string" and isValidIdent(kc.value) and not kc.value:match("^_r%d") then
							local hint = cleanGeneratedIdent(kc.value) or kc.value
							name = generatedNameFor and generatedNameFor(hint, "_r" .. tostring(a)) or sanitizeLocalName(hint, a)
						end
						break
					end
					scanPc = scanPc + si.len
				end
			end
		end
		name = name or semanticLocalName(a, pc)
		regs[a] = name
		return indent .. "local " .. name .. " = " .. kvalLua(p, d), 0
	end

	if opName == "SETLIST" then
		local startIndex = aux ~= nil and aux or 1
		local count = c - 1
		if count <= 0 and previousMultretCallReg then
			count = math.max(1, previousMultretCallReg - b + 1)
		end
		if count <= 0 then
			regs.__lastMultretCallReg = nil
			return nil, 0
		end
		local tableExpr = rname(a)
		local lhs = {}
		local rhs = {}
		for i = 0, count - 1 do
			push(lhs, tableExpr .. "[" .. tostring(startIndex + i) .. "]")
			push(rhs, rname(b + i))
		end
		regs.__lastMultretCallReg = nil
		return indent .. table.concat(lhs, ", ") .. " = " .. table.concat(rhs, ", "), 0
	end

	if opName == "CONCAT" then
		local parts = {}
		for reg = b, c do
			push(parts, rname(reg))
		end
		local expr = table.concat(parts, " .. ")
		local concatHint = flowAnalysis and flowAnalysis.concatPhiHints and flowAnalysis.concatPhiHints[pc] or nil
		local hinted = assignHintedValue(a, expr, concatHint)
		if hinted then
			return hinted, 0
		end
		regs[a] = expr
		return nil, 0
	end

	if opName == "ADD" or opName == "SUB" or opName == "MUL" or opName == "DIV" or opName == "MOD" or opName == "POW" or opName == "IDIV" then
		local symbols = {
			ADD = "+",
			SUB = "-",
			MUL = "*",
			DIV = "/",
			MOD = "%",
			POW = "^",
			IDIV = "//",
		}
		local expr = "(" .. rname(b) .. " " .. symbols[opName] .. " " .. rname(c) .. ")"
		local backEdgeInit = flowAnalysis and flowAnalysis.backEdgeMutationHints and flowAnalysis.backEdgeMutationHints[pc] or nil
		if backEdgeInit and backEdgeInit.isInit and backEdgeInit.reg == a and backEdgeInit.targetName and isValidIdent(backEdgeInit.targetName) then
			local targetName = sanitizeLocalName(backEdgeInit.targetName, a)
			regs[a] = targetName
			return indent .. "local " .. targetName .. " = " .. expr, 0
		end
		regs[a] = expr
		return nil, 0
	end

	if opName == "ADDK" or opName == "SUBK" or opName == "MULK" or opName == "DIVK" or opName == "MODK" or opName == "POWK" or opName == "IDIVK" then
		local counterName = flowAnalysis and flowAnalysis.counterHints and flowAnalysis.counterHints.increments and flowAnalysis.counterHints.increments[pc] or nil
		if counterName and isValidIdent(counterName) and opName == "ADDK" and kvalLua(p, c) == "1" then
			regs[a] = counterName
			return indent .. counterName .. " = " .. counterName .. " + 1", 0
		end
		local symbols = {
			ADDK = "+",
			SUBK = "-",
			MULK = "*",
			DIVK = "/",
			MODK = "%",
			POWK = "^",
			IDIVK = "//",
		}
		local backEdgeHint = flowAnalysis and flowAnalysis.backEdgeMutationHints and flowAnalysis.backEdgeMutationHints[pc] or nil
		if backEdgeHint and backEdgeHint.reg == a and backEdgeHint.targetName and isValidIdent(backEdgeHint.targetName) then
			-- Materialize as explicit assignment: R = R - K (force LHS/RHS to use the same target name).
			local lhsName = sanitizeLocalName(backEdgeHint.targetName, a)
			local rhsName
			if b == a then
				-- Self-mutation: RHS reads the same logical local as LHS.
				rhsName = lhsName
			else
				rhsName = rname(b)
			end
			local rhs = rhsName .. " " .. symbols[opName] .. " " .. kvalLua(p, c)
			regs[a] = lhsName
			-- The init-write before the loop was responsible for the `local lhsName = INITVAL`
			-- declaration; the loop body just emits assignments.
			return indent .. lhsName .. " = " .. rhs, 0
		end
		regs[a] = "(" .. rname(b) .. " " .. symbols[opName] .. " " .. kvalLua(p, c) .. ")"
		return nil, 0
	end

	if opName == "SUBRK" or opName == "DIVRK" then
		local symbol = opName == "SUBRK" and "-" or "/"
		regs[a] = "(" .. kvalLua(p, b) .. " " .. symbol .. " " .. rname(c) .. ")"
		return nil, 0
	end

	if opName == "AND" or opName == "OR" then
		local symbol = opName == "AND" and "and" or "or"
		regs[a] = "(" .. rname(b) .. " " .. symbol .. " " .. rname(c) .. ")"
		return nil, 0
	end

	if opName == "ANDK" or opName == "ORK" then
		local symbol = opName == "ANDK" and "and" or "or"
		regs[a] = "(" .. rname(b) .. " " .. symbol .. " " .. kvalLua(p, c) .. ")"
		return nil, 0
	end

	if opName == "NOT" then
		regs[a] = "(not " .. rname(b) .. ")"
		return nil, 0
	end

	if opName == "MINUS" then
		regs[a] = "(-" .. rname(b) .. ")"
		return nil, 0
	end

	if opName == "LENGTH" then
		regs[a] = "(#" .. rname(b) .. ")"
		return nil, 0
	end

	if opName == "JUMP" or opName == "JUMPBACK" then
		local branchBreakHint = flowAnalysis and flowAnalysis.branchValueHints and flowAnalysis.branchValueHints.breaks and flowAnalysis.branchValueHints.breaks[pc] or nil
		if branchBreakHint then
			return indent .. "break", 0
		end
		return indent .. "goto pc" .. tostring(pc + d + 1), 0
	end

	if opName == "JUMPIF" or opName == "JUMPIFNOT" then
		if flowAnalysis and flowAnalysis.orDefaultHints and flowAnalysis.orDefaultHints.jumps and flowAnalysis.orDefaultHints.jumps[pc] then
			return nil, 0
		end
		if opName == "JUMPIFNOT" then
			local nextPc = pc + getOpLength(opName)
			local nextInfo = nextPc < #p.code and decodedInsnAt(p, nextPc) or nil
			local guardPc = nextInfo and (nextPc + nextInfo.len) or nil
			local guardInfo = guardPc and guardPc < #p.code and decodedInsnAt(p, guardPc) or nil
			local fallbackPc = pc + b + 1
			local fallbackInfo = fallbackPc < #p.code and decodedInsnAt(p, fallbackPc) or nil
			if nextInfo
				and nextInfo.opName == "GETTABLEKS"
				and nextInfo.b == a
				and guardInfo
				and guardInfo.opName == "JUMPIF"
				and guardInfo.a == nextInfo.a
				and fallbackInfo
				and fallbackInfo.opName == "LOADNIL"
				and fallbackInfo.a == nextInfo.a
				and jumpTargetForInsn(guardInfo) == fallbackPc + fallbackInfo.len
			then
				return nil, 0
			end
			-- Extended: JUMPIFNOT Ra → Fb; GETTABLEKS chain Rx; JUMPIF Rx → Mg; MOVE Rx=Rf (at Fb)
			-- Pattern: Rx = ((Ra) and (chain_expr)) or Rf
			if fallbackInfo and fallbackInfo.opName == "MOVE" then
				local chainPc = nextPc
				local chainReg = nil
				local foundJumpIf = false
				while chainPc < fallbackPc do
					local si = decodedInsnAt(p, chainPc)
					if si.opName == "GETTABLEKS" then
						if chainReg == nil then
							if si.b ~= a then break end
							chainReg = si.a
						else
							if si.b ~= chainReg or si.a ~= chainReg then break end
						end
						chainPc = chainPc + si.len
					elseif si.opName == "JUMPIF" and chainReg and si.a == chainReg then
						local mergePc = jumpTargetForInsn(si)
						if mergePc
							and chainPc + si.len == fallbackPc
							and fallbackInfo.a == chainReg
							and fallbackPc + fallbackInfo.len == mergePc
						then
							foundJumpIf = true
						end
						break
					else
						break
					end
				end
				if foundJumpIf then
					return nil, 0
				end
			end
			-- Extended: JUMPIFNOT Ra → Fb; GETTABLEKS chain Rx; JUMPIF Rx → Mg; (LOADN|LOADK|LOADB) Rx (at Fb); merge=Mg
			-- Pattern: Rx = ((Ra) and (chain_expr)) or LITERAL
			if fallbackInfo and (fallbackInfo.opName == "LOADN" or fallbackInfo.opName == "LOADK" or fallbackInfo.opName == "LOADKX" or fallbackInfo.opName == "LOADB") then
				local chainPc3 = nextPc
				local chainReg3 = nil
				local foundJumpIfLit = false
				while chainPc3 < fallbackPc do
					local si3 = decodedInsnAt(p, chainPc3)
					if si3.opName == "GETTABLEKS" then
						if chainReg3 == nil then
							if si3.b ~= a then break end
							chainReg3 = si3.a
						else
							if si3.b ~= chainReg3 or si3.a ~= chainReg3 then break end
						end
						chainPc3 = chainPc3 + si3.len
					elseif si3.opName == "JUMPIF" and chainReg3 and si3.a == chainReg3 then
						local jumpMerge3 = jumpTargetForInsn(si3)
						if jumpMerge3
							and chainPc3 + si3.len == fallbackPc
							and fallbackInfo.a == chainReg3
							and fallbackPc + fallbackInfo.len == jumpMerge3
						then
							foundJumpIfLit = true
						end
						break
					else
						break
					end
				end
				if foundJumpIfLit then
					-- Build the or-expression: ((Ra) and chain.field.path) or LITERAL.
					-- We let the regs[] tracking already accumulate the chain; the literal
					-- fallback will overwrite it. Then on the use site (typically SETTABLEKS
					-- or SETUPVAL or another consumer), regs[chainReg] will reflect the
					-- final literal which loses the chain. Patch via orDefaultHints-like
					-- mechanism: emit nothing here; let GETTABLEKS-chain accumulate, the
					-- LOADN at fallbackPc will replace regs but we need to merge as
					-- "(chain or literal)" expression.
					-- Build the chain expression by walking once more
					local chainExpr = rname(a)
					local cp = nextPc
					local last = chainReg3
					while cp < fallbackPc do
						local si4 = decodedInsnAt(p, cp)
						if si4.opName == "GETTABLEKS" then
							local kc = constantAt(p, si4.aux ~= nil and si4.aux or si4.d)
							local key = kc and kc.kind == "string" and kc.value or nil
							if key then
								chainExpr = chainExpr .. luaIndexSuffix(key)
							end
							cp = cp + si4.len
						else
							break
						end
					end
					-- Compute literal expression
					local litExpr
					if fallbackInfo.opName == "LOADN" then
						litExpr = tostring(fallbackInfo.d)
					elseif fallbackInfo.opName == "LOADB" then
						litExpr = fallbackInfo.b ~= 0 and "true" or "false"
					else
						local idx = fallbackInfo.opName == "LOADKX" and fallbackInfo.aux or fallbackInfo.d
						litExpr = kvalLua(p, idx)
					end
					regs[chainReg3] = "(" .. rname(a) .. " and " .. chainExpr .. ") or " .. litExpr
					-- Skip past the entire pattern (JUMPIFNOT + GETTABLEKS chain + JUMPIF + fallback)
					local totalSkip = (fallbackPc + fallbackInfo.len) - (pc + getOpLength(opName))
					return nil, totalSkip
				end
			end
			-- Extended: JUMPIFNOT Ra → Mg; GETTABLEKS chain Rx; JUMPIF Rx → Mg; LOADNIL Rx; Mg
			-- Pattern: Rx = ((Ra) and (chain_expr)) or nil  (both guards target same merge)
			do
				local chainPc2 = nextPc
				local chainReg2 = nil
				local foundJumpIfLoadnil = false
				while chainPc2 < fallbackPc do
					local si2 = decodedInsnAt(p, chainPc2)
					if si2.opName == "GETTABLEKS" then
						if chainReg2 == nil then
							if si2.b ~= a then break end
							chainReg2 = si2.a
						else
							if si2.b ~= chainReg2 or si2.a ~= chainReg2 then break end
						end
						chainPc2 = chainPc2 + si2.len
					elseif si2.opName == "JUMPIF" and chainReg2 and si2.a == chainReg2 then
						local jumpMerge2 = jumpTargetForInsn(si2)
						local loadnilPc2 = chainPc2 + si2.len
						local loadnilInfo2 = loadnilPc2 < #p.code and decodedInsnAt(p, loadnilPc2) or nil
						if loadnilInfo2
							and loadnilInfo2.opName == "LOADNIL"
							and loadnilInfo2.a == chainReg2
							and loadnilPc2 == fallbackPc
							and jumpMerge2 == fallbackPc + loadnilInfo2.len
						then
							foundJumpIfLoadnil = true
						end
						break
					else
						break
					end
				end
				if foundJumpIfLoadnil then
					return nil, 0
				end
			end
		end
		local rawCond = rname(a)
		local cond = opName == "JUMPIF" and rawCond or ("not " .. rawCond)
		local condJumpInfo = { pc = pc, opName = opName, a = a, b = b, d = b, len = getOpLength(opName) }
		local boolSkip = detectBoolSkipPattern(condJumpInfo)
		if boolSkip then
			-- For JUMPIF/JUMPIFNOT, the "natural" cond is `Ra` / `not Ra`.
			-- If invertCond is true, flip it.
			local effCond
			if boolSkip.invertCond then
				effCond = opName == "JUMPIF" and ("not " .. rawCond) or rawCond
			else
				effCond = cond
			end
			return indent .. "if " .. effCond .. " then goto pc" .. tostring(boolSkip.pcE) .. " end", boolSkip.extraConsume
		end
		return indent .. "if " .. cond .. " then goto pc" .. tostring(pc + b + 1) .. " end", 0
	end


	if opName == "JUMPIFEQ" or opName == "JUMPIFLE" or opName == "JUMPIFLT" or opName == "JUMPIFNOTEQ" or opName == "JUMPIFNOTLE" or opName == "JUMPIFNOTLT" then
		local rb = bit32_band(aux or 0, 0x7FFFFFFF)
		local baseSymbols = {
			JUMPIFEQ = "==",
			JUMPIFLE = "<=",
			JUMPIFLT = "<",
			JUMPIFNOTEQ = "~=",
			JUMPIFNOTLE = ">",
			JUMPIFNOTLT = ">=",
		}
		local negate = {
			["=="] = "~=",
			["~="] = "==",
			["<="] = ">",
			[">"] = "<=",
			["<"] = ">=",
			[">="] = "<",
		}
		local symbol = baseSymbols[opName]
		local condJumpInfo = { pc = pc, opName = opName, a = a, aux = aux, d = d, len = getOpLength(opName) }
		local boolSkip = detectBoolSkipPattern(condJumpInfo)
		if boolSkip then
			local effSymbol = boolSkip.invertCond and negate[symbol] or symbol
			return indent .. "if " .. rname(a) .. " " .. effSymbol .. " " .. rname(rb) .. " then goto pc" .. tostring(boolSkip.pcE) .. " end", boolSkip.extraConsume
		end
		return indent .. "if " .. rname(a) .. " " .. symbol .. " " .. rname(rb) .. " then goto pc" .. tostring(pc + d + 1) .. " end", 0
	end

	if opName == "JUMPXLEKN" then
		local notFlag = bit32_band(bit32_rshift(aux or 0, 31), 1)
		local kidx = bit32_band(aux or 0, 0x7FFFFFFF)
		local symbol = notFlag ~= 0 and ">" or "<="
		local condJumpInfo = { pc = pc, opName = opName, a = a, aux = aux, d = d, len = getOpLength(opName) }
		local boolSkip = detectBoolSkipPattern(condJumpInfo)
		if boolSkip then
			local effSymbol = symbol
			if boolSkip.invertCond then
				local invMap = { ["<="] = ">", [">"] = "<=" }
				effSymbol = invMap[symbol]
			end
			return indent .. "if " .. rname(a) .. " " .. effSymbol .. " " .. kvalLua(p, kidx) .. " then goto pc" .. tostring(boolSkip.pcE) .. " end", boolSkip.extraConsume
		end
		return indent .. "if " .. rname(a) .. " " .. symbol .. " " .. kvalLua(p, kidx) .. " then goto pc" .. tostring(pc + d + 1) .. " end", 0
	end

	if opName == "JUMPX" then
		return indent .. "goto pc" .. tostring(pc + e + 1), 0
	end

	if opName == "JUMPXEQKNIL" or opName == "JUMPXEQKB" or opName == "JUMPXEQKN" or opName == "JUMPXEQKS" then
		local notFlag = bit32_rshift(aux or 0, 31)
		local cmpOp = notFlag ~= 0 and "~=" or "=="
		local rhs
		if opName == "JUMPXEQKNIL" then
			rhs = "nil"
		elseif opName == "JUMPXEQKB" then
			rhs = bit32_band(aux or 0, 1) ~= 0 and "true" or "false"
		else
			local kidx = bit32_band(aux or 0, 0xFFFFFF)
			rhs = kvalLua(p, kidx)
		end
		local condJumpInfo = { pc = pc, opName = opName, a = a, aux = aux, d = d, len = getOpLength(opName) }
		local boolSkip = detectBoolSkipPattern(condJumpInfo)
		if boolSkip then
			local effOp = cmpOp
			if boolSkip.invertCond then
				effOp = cmpOp == "==" and "~=" or "=="
			end
			return indent .. "if " .. rname(a) .. " " .. effOp .. " " .. rhs .. " then goto pc" .. tostring(boolSkip.pcE) .. " end", boolSkip.extraConsume
		end
		return indent .. "if " .. rname(a) .. " " .. cmpOp .. " " .. rhs .. " then goto pc" .. tostring(pc + d + 1) .. " end", 0
	end

	if opName == "GETVARARGS" then
		regs[a] = "..."
		return nil, 0
	end

	if opName == "PREPVARARGS" then
		return nil, 0
	end

	if opName == "FORNPREP" then
		local init = regs[a + 2] or ("R" .. tostring(a + 2))
		local limit = regs[a] or ("R" .. tostring(a))
		local step = regs[a + 1] or ("R" .. tostring(a + 1))
		local loopName = localAt(p, a + 2, pc + 1)
		-- Prefer the analysis-assigned name (which may have a uniqueness suffix
		-- to avoid nested-loop collisions like `_i` vs `_i_2`).
		local analysisLoopName = nil
		if flowAnalysis and flowAnalysis.regWrites and flowAnalysis.regWrites[a + 2] then
			for _, w in ipairs(flowAnalysis.regWrites[a + 2]) do
				if w.pc == pc and w.opName == "FORNPREP" and w.name and isValidIdent(w.name) then
					analysisLoopName = w.name
					break
				end
			end
		end
		if not loopName then
			loopName = analysisLoopName
		end
		if not loopName and generatedNameFor then
			loopName = generatedNameFor("_i", "_i")
		end
		loopName = loopName or "_i"
		regs[a + 2] = loopName
		return indent .. "-- FORNPREP R" .. tostring(a) .. " init=" .. init .. " limit=" .. limit .. " step=" .. step .. " name=" .. loopName .. " -> pc" .. tostring(pc + d + 1), 0
	end

	if opName == "FORNLOOP" then
		return indent .. "-- FORNLOOP R" .. tostring(a) .. " -> pc" .. tostring(pc + d + 1), 0
	end

	if opName == "FORGPREP" or opName == "FORGPREP_INEXT" or opName == "FORGPREP_NEXT" then
		local iterNote = ""
		local iterExpr = regs[a]
		if iterExpr and iterExpr ~= ("R" .. tostring(a)) then
			if opName == "FORGPREP_INEXT" then
				iterNote = " iter=ipairs(" .. iterExpr .. ")"
			else
				iterNote = " iter=" .. iterExpr
			end
		end
		local loopNames = genericLoopVarNames(a, 2)
		regs[a + 3] = loopNames[1]
		regs[a + 4] = loopNames[2]
		regs[a + 5] = "R" .. tostring(a + 5)
		return indent .. "-- " .. opName .. " R" .. tostring(a) .. iterNote .. " -> pc" .. tostring(pc + d + 1), 0
	end

	if opName == "FORGLOOP" then
		local nvars = bit32_band(aux or 0, 0xFF)
		return indent .. "-- generic-for loop R" .. tostring(a) .. ".. (vars=" .. tostring(nvars) .. ") -> pc" .. tostring(pc + d + 1), 0
	end

	if opName == "CAPTURE" or opName == "COVERAGE" or opName == "BREAK" or opName == "NOP" or opName == "NATIVECALL" then
		return nil, 0
	end

	if opName == "FASTCALL" or opName == "FASTCALL1" or opName == "FASTCALL2" or opName == "FASTCALL2K" or opName == "FASTCALL3" then
		return nil, 0
	end

	local hints = {}
	local dConst = constantAt(p, d)
	if dConst then
		push(hints, "K[D]=" .. formatConstant(dConst, p))
	end
	local childId = childProtoIdAt(p, d)
	if childId ~= nil then
		push(hints, "child#" .. tostring(d) .. "=proto[" .. tostring(childId) .. "]")
	end
	local bConst = constantAt(p, b)
	if bConst and opName ~= "LOADN" and opName ~= "MOVE" then
		push(hints, "K[B]=" .. formatConstant(bConst, p))
	end
	local cConst = constantAt(p, c)
	if cConst then
		push(hints, "K[C]=" .. formatConstant(cConst, p))
	end
	if aux ~= nil then
		local auxConst = constantAt(p, aux)
		if auxConst then
			push(hints, "AUX=" .. formatConstant(auxConst, p))
		else
			push(hints, "AUX=" .. formatHex32(aux))
		end
	end
	local hintText = #hints > 0 and ("  -- " .. table.concat(hints, ", ")) or ""
	return indent .. "-- " .. opName .. " A=" .. tostring(a) .. " B=" .. tostring(b) .. " C=" .. tostring(c) .. " D=" .. tostring(d) .. hintText, 0
end

-- ===========================================================================
-- BEAUTIFICATION / CONTROL-FLOW LIFTING (goto-free Luau implementation)
-- ===========================================================================

-- Lua pattern magic-char escape (equivalent to Python re.escape)
-- [P4] Hoisted out of per-iteration table literals in renameIdentOutsideStrings
-- and countIdentUsesOutsideStrings. Was { '"', "'", "[", "-" } allocated
-- inside the while loop on every iteration.
local STR_DELIMS = { '"', "'", "[", "-" }

local function luaPE(s)
	return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function identPat(name)
	return "%f[%w_]" .. luaPE(name) .. "%f[^%w_]"
end

local function renameIdentOutsideStrings(line, oldName, newName)
	if not line:find(oldName, 1, true) then return line end
	local pat = identPat(oldName)
	local out = {}
	local i = 1
	local n = #line
	while i <= n do
		local nextPos = n + 1
		for _, ch in ipairs({ "\"", "'", "[", "-" }) do
			local pos = line:find(ch, i, true)
			if pos and pos < nextPos then nextPos = pos end
		end
		if nextPos > i then
			out[#out+1] = (line:sub(i, nextPos - 1):gsub(pat, function()
				return newName
			end))
			i = nextPos
		else
			local ch = line:sub(i, i)
			if ch == "-" and line:sub(i, i + 1) == "--" then
				out[#out+1] = line:sub(i)
				break
			elseif ch == "\"" or ch == "'" then
				local quote = ch
				local j = i + 1
				while j <= n do
					local cj = line:sub(j, j)
					if cj == "\\" and j < n then
						j = j + 2
					elseif cj == quote then
						j = j + 1
						break
					else
						j = j + 1
					end
				end
				out[#out+1] = line:sub(i, math.min(j - 1, n))
				i = j
			elseif ch == "[" and line:sub(i, i + 1) == "[[" then
				local closePos = line:find("]]", i + 2, true)
				if closePos then
					out[#out+1] = line:sub(i, closePos + 1)
					i = closePos + 2
				else
					out[#out+1] = line:sub(i)
					break
				end
			else
				out[#out+1] = ch
				i = i + 1
			end
		end
	end
	return table.concat(out)
end

local function countIdentUsesOutsideStrings(line, name)
	if not line:find(name, 1, true) then return 0 end
	local pat = identPat(name)
	local count = 0
	local i = 1
	local n = #line
	while i <= n do
		local nextPos = n + 1
		for _, ch in ipairs({ '"', "'", "[", "-" }) do
			local pos = line:find(ch, i, true)
			if pos and pos < nextPos then nextPos = pos end
		end
		if nextPos > i then
			local _, segCount = line:sub(i, nextPos - 1):gsub(pat, "")
			count = count + segCount
			i = nextPos
		else
			local ch = line:sub(i, i)
			if ch == "-" and line:sub(i, i + 1) == "--" then
				break
			elseif ch == '"' or ch == "'" then
				local quote = ch
				local j = i + 1
				while j <= n do
					local cj = line:sub(j, j)
					if cj == "\\" and j < n then
						j = j + 2
					elseif cj == quote then
						j = j + 1
						break
					else
						j = j + 1
					end
				end
				i = j
			elseif ch == "[" and line:sub(i, i + 1) == "[[" then
				local closePos = line:find("]]", i + 2, true)
				if closePos then
					i = closePos + 2
				else
					break
				end
			else
				i = i + 1
			end
		end
	end
	return count
end

local function matchLbl(s)
	return s:match("^(%s*)::([Pp][Cc]%d+)::%s*$")
end

-- Check if string s matches if-goto pattern ^(\s*)if (.+) then goto (pc\d+) end\s*$
local function matchIfGoto(s)
	return s:match("^(%s*)if%s+(.+)%s+then%s+goto%s+(pc%d+)%s+end%s*$")
end

-- Check if string s matches goto pattern ^(\s*)goto (pc\d+)\s*$
local function matchGoto(s)
	return s:match("^(%s*)goto%s+(pc%d+)%s*$")
end

-- Check if string s matches if-open pattern ^(\s*)if (.+) then\s*$
local function matchIfOpen(s)
	return s:match("^(%s*)if%s+(.+)%s+then%s*$")
end

-- Check if string s matches end line ^(\s*)end\s*$
local function matchEnd(s)
	return s:match("^(%s*)end%s*$")
end

-- Check if string s matches return line ^(\s*)(return...)\s*$
local function matchReturn(s)
	return s:match("^(%s*)(return%s*.*)%s*$")
end

-- Check if string s matches for-open ^(\s*)for\b.*\bdo\s*$

-- Check if string s matches loop-open (for/while/repeat)
local function matchLoopOpen(s)
	local ind = s:match("^(%s*)for%s.+%sdo%s*$")
	if ind then return ind end
	ind = s:match("^(%s*)while%s.+%sdo%s*$")
	if ind then return ind end
	ind = s:match("^(%s*)repeat%s*$")
	if ind then return ind end
	return nil
end

-- Collect all indices in lines where `goto TARGET` appears
local function labelRefs(lines, target)
	local pat = "%f[%a_]goto%s+" .. luaPE(target) .. "%f[^%a_%d]"
	local result = {}
	for i, ln in ipairs(lines) do
		if ln:find(pat) then
			result[#result+1] = i
		end
	end
	return result
end

local function negateCond(cond)
	cond = cond:match("^%s*(.-)%s*$")
	while cond:sub(1,1) == "(" and cond:sub(-1) == ")" do
		local depth = 0
		local balanced = true
		for i = 1, #cond - 1 do
			local ch = cond:sub(i,i)
			if ch == "(" then depth = depth + 1
			elseif ch == ")" then
				depth = depth - 1
				if depth == 0 then balanced = false; break end
			end
		end
		if not balanced then break end
		cond = cond:sub(2, -2):match("^%s*(.-)%s*$")
	end
	if cond:sub(1,4) == "not " then
		return cond:sub(5):match("^%s*(.-)%s*$")
	end
	local ops = {
		{" == ", " ~= "}, {" ~= ", " == "},
		{" <= ", " > "}, {" >= ", " < "},
		{" < ", " >= "}, {" > ", " <= "},
	}
	for _, pair in ipairs(ops) do
		local op, neg = pair[1], pair[2]
		local idx = cond:find(op, 1, true)
		if idx then
			-- ensure only one occurrence
			if not cond:find(op, idx + 1, true) then
				return cond:sub(1, idx-1) .. neg .. cond:sub(idx + #op)
			end
		end
	end
	if cond == "true" then return "false" end
	if cond == "false" then return "true" end
	return "not (" .. cond .. ")"
end

-- Wrap condition for use in `and` chain
local function wrapForAnd(s)
	s = s:match("^%s*(.-)%s*$")
	if s:sub(1,1) == "(" and s:sub(-1) == ")" then
		local depth = 0
		local balanced = true
		for i = 1, #s - 1 do
			local ch = s:sub(i,i)
			if ch == "(" then depth = depth + 1
			elseif ch == ")" then
				depth = depth - 1
				if depth == 0 then balanced = false; break end
			end
		end
		if balanced and depth == 1 then return s end
	end
	if s:match("^%s*not%s+[%a_][%a_%d%.]*%s*$") then return s end
	if s:match("^[%a_][%a_%d%.]*%s*$") then return s end
	return "(" .. s .. ")"
end

-- Collapse multi-line `if X then\n  goto pcN\nend` -> single line
local function collapseTrivialIf(lines)
	local out = {}
	local j = 1
	while j <= #lines do
		local collapsed = false
		if j + 2 <= #lines then
			local ind, cond = matchIfOpen(lines[j])
			local _, tgt = matchGoto(lines[j+1])
			local mend = matchEnd(lines[j+2])
			if ind and tgt and mend then
				out[#out+1] = ind .. "if " .. cond .. " then goto " .. tgt .. " end"
				j = j + 3
				collapsed = true
			end
		end
		if not collapsed then
			out[#out+1] = lines[j]
			j = j + 1
		end
	end
	return out
end

-- Drop orphan labels (not referenced by any goto)
local function dropOrphanLabels(lines)
	local used = {}
	for _, ln in ipairs(lines) do
		for tgt in ln:gmatch("%f[%a_]goto%s+(pc%d+)%f[^%a_%d]") do
			used[tgt] = true
		end
	end
	local out = {}
	for _, ln in ipairs(lines) do
		local _, lbl = matchLbl(ln)
		if lbl and not used[lbl] then
			-- skip
		else
			out[#out+1] = ln
		end
	end
	return out
end

-- Normalize `(X + -N)` -> `(X - N)`
local function normalizeNegativeAddk(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local prev = nil
		local cur = line
		while cur ~= prev do
			prev = cur
			cur = cur:gsub("(%([^()]-) %+ %-(%d+%.?%d*)", "%1 - %2")
		end
		out[#out+1] = cur
	end
	return out
end


-- Lift numeric for: FORNPREP/FORNLOOP comments -> `for i = init, limit, step do`
local function liftNumericFor(lines, indentUnit)
	local FORNPREP_PAT = "^(%s*)%-%- FORNPREP R(%d+) init=(.+) limit=(.+) step=(.+) name=([%a_][%w_]*) %-> pc(%d+)%s*$"
	local FORNPREP_PAT_LEGACY = "^(%s*)%-%- FORNPREP R(%d+) init=(.+) limit=(.+) step=(.+) %-> pc(%d+)%s*$"
	local FORNLOOP_PAT = "^(%s*)%-%- FORNLOOP R(%d+) %-> pc(%d+)%s*$"
	local out = {}
	local i = 1
	while i <= #lines do
		local ind, base, initE, limitE, stepE, nameE, _tgt = lines[i]:match(FORNPREP_PAT)
		if not ind then
			ind, base, initE, limitE, stepE, _tgt = lines[i]:match(FORNPREP_PAT_LEGACY)
			nameE = nil
		end
		if ind then
			base = tonumber(base)
			-- find matching FORNLOOP
			local loopIdx = nil
			for k = i + 1, #lines do
				local _, lb = lines[k]:match(FORNLOOP_PAT)
				if lb and tonumber(lb) == base then
					loopIdx = k
					break
				end
			end
			if loopIdx then
				local body = {}
				for k = i + 1, loopIdx - 1 do body[#body+1] = lines[k] end
				local loopVar
				if nameE and nameE ~= "" then
					loopVar = nameE
				else
					loopVar = "_i"
					local bodyText = table.concat(body, "\n")
					local best, bestCount = "_i", 0
					for nm in bodyText:gmatch("(_i[_%d]*)") do
						local cnt = 0
						for _ in bodyText:gmatch("%f[%a_]" .. luaPE(nm) .. "%f[^%a_%d]") do cnt = cnt + 1 end
						if cnt > bestCount then
							best = nm
							bestCount = cnt
						end
					end
					if bestCount > 0 then loopVar = best end
				end
				local renamed = {}
				for _, bl in ipairs(body) do
					renamed[#renamed+1] = bl:gsub("%f[%a_R]R" .. tostring(base+2) .. "%f[^%a_%d]", loopVar)
				end
				if stepE:match("^%s*1%s*$") then
					out[#out+1] = ind .. "for " .. loopVar .. " = " .. initE .. ", " .. limitE .. " do"
				else
					out[#out+1] = ind .. "for " .. loopVar .. " = " .. initE .. ", " .. limitE .. ", " .. stepE .. " do"
				end
				for _, bl in ipairs(renamed) do
					if bl:match("%S") then out[#out+1] = indentUnit .. bl
					else out[#out+1] = bl end
				end
				out[#out+1] = ind .. "end"
				i = loopIdx + 1
			else
				out[#out+1] = lines[i]
				i = i + 1
			end
		else
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

-- Lift generic for: FORGPREP/FORGLOOP comments -> `for k, v in iter do`
local function liftGenericFor(lines, indentUnit)
	local function matchForgPrep(ln)
		local ind, base, tgt = ln:match("^(%s*)%-%-%s*FORGPREP[_A-Z]*%s+R(%d+)%s+%->%s+pc(%d+)%s*$")
		if ind then return ind, tonumber(base), tgt, nil end
		-- with iter= annotation
		local ind2, base2, iter, tgt2 = ln:match("^(%s*)%-%-%s*FORGPREP[_A-Z]*%s+R(%d+)%s+iter=(.-)%s+%->%s+pc(%d+)%s*$")
		if ind2 then return ind2, tonumber(base2), tgt2, iter end
		return nil
	end
	local function matchForgLoop(ln)
		local ind, base, nvars, tgt = ln:match("^(%s*)%-%-%s*generic%-for loop R(%d+)%.%.%s+%(vars=(%d+)[^)]*%)%s+%->%s+pc(%d+)%s*$")
		if ind then return ind, tonumber(base), tonumber(nvars), tgt end
		return nil
	end
	local out = {}
	local i = 1
	while i <= #lines do
		local ind, base, loopTgt, iterFromNote = matchForgPrep(lines[i])
		if ind then
			local labelPat = "^%s*::pc" .. loopTgt .. "::%s*$"
			local loopIdx = nil
			for k = i + 1, #lines do
				if lines[k]:match(labelPat) then
					loopIdx = k
					break
				end
			end
			local loopCmtIdx = nil
			local nvars = 2
			if loopIdx then
				for k = loopIdx + 1, math.min(#lines, loopIdx + 3) do
					local _, lb, nv = matchForgLoop(lines[k])
					if lb and lb == base then
						loopCmtIdx = k
						nvars = nv or 2
						break
					end
				end
			end
			if not loopCmtIdx then
				for k = i + 1, #lines do
					local _, lb, nv = matchForgLoop(lines[k])
					if lb and lb == base then
						loopCmtIdx = k
						loopIdx = k
						nvars = nv or 2
						break
					end
				end
			end
			if loopCmtIdx then
				local iterExpr = nil
				for k = #out, math.max(1, #out - 12), -1 do
					local _, rn, rhs = out[k]:match("^(%s*)local%s+_r(%d+)%s*=%s*(.*)$")
					if rn and tonumber(rn) == base then
						iterExpr = rhs:match("^(.-)%s*$")
						table.remove(out, k)
						break
					end
					local _ind2, names, rhs2 = out[k]:match("^(%s*)local%s+([%a_][%a_%d%s,]-)%s*=%s*(.*)$")
					if names and rhs2 then
						local firstName = names:match("^([%a_][%a_%d]*)")
						if firstName == "_r" .. tostring(base) or rhs2:match("pairs%s*%(") or rhs2:match("ipairs%s*%(") then
							iterExpr = rhs2:match("^(.-)%s*$")
							table.remove(out, k)
							break
						end
					end
				end
				if (not iterExpr or iterExpr == "") and iterFromNote and iterFromNote ~= "" and not iterFromNote:match("^_r%d") then
					iterExpr = iterFromNote
				end
				local body = {}
				for k = i + 1, (loopIdx or loopCmtIdx) - 1 do body[#body+1] = lines[k] end
				local names = genericLoopVarNames(base, nvars)
				local renamed = {}
				for _, bl in ipairs(body) do
					for ni, nm in ipairs(names) do
						bl = bl:gsub("%f[%a_R]R" .. tostring(base + 2 + ni) .. "%f[^%a_%d]", nm)
					end
					renamed[#renamed+1] = bl
				end
				local iterStr = iterExpr or ("-- iter R" .. tostring(base))
				out[#out+1] = ind .. "for " .. table.concat(names, ", ") .. " in " .. iterStr .. " do"
				for _, bl in ipairs(renamed) do
					if bl:match("%S") then out[#out+1] = indentUnit .. bl
					else out[#out+1] = bl end
				end
				out[#out+1] = ind .. "end"
				i = loopCmtIdx + 1
			else
				out[#out+1] = lines[i]
				i = i + 1
			end
		else
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

-- Remove unreachable code after return/continue
local function removeUnreachableAfterReturn(lines)
	local out = {}
	local skipIndent = nil
	for _, ln in ipairs(lines) do
		if skipIndent ~= nil then
			local stripped = ln:match("^%s*(.-)%s*$")
			if stripped and stripped ~= "" then
				local lead = ln:match("^(%s*)") or ""
				local ind = #lead
				local isTerminator = (
					ind <= skipIndent and (
						ind < skipIndent
						or stripped == "end" or stripped == "else" or stripped == "until"
						or stripped:sub(1,7) == "elseif " or stripped:sub(1,6) == "else "
					)
				)
				if isTerminator or matchLbl(ln) then
					skipIndent = nil
					out[#out+1] = ln
				end
			end
		else
			local ind, rest = matchReturn(ln)
			if ind and rest then
				skipIndent = #ind
			elseif ln:match("^%s*continue%s*$") then
				skipIndent = #(ln:match("^(%s*)") or "")
			end
			out[#out+1] = ln
		end
	end
	return out
end

-- Drop redundant trailing `return` before closing `end`, and also drop a bare
-- trailing `return` at the very end of the main chunk (which has no enclosing
-- `end`). The latter is important for LocalScript-style outputs that otherwise
-- end with an artifact `return` from the implicit RETURN R0.. (0 values).
local function dropTrailingReturn(lines)
	if #lines == 0 then return lines end
	local last = #lines
	while last >= 1 and not lines[last]:match("%S") do last = last - 1 end
	if last < 1 then return lines end
	if not matchEnd(lines[last]) then
		-- No closing `end`: check if this is the main chunk and ends with `return`
		local firstNonBlank
		for _, ln in ipairs(lines) do
			if ln:match("%S") then firstNonBlank = ln break end
		end
		if firstNonBlank and firstNonBlank:match("^%-%-%s*main chunk%s*%(") then
			local txt = lines[last]:match("^%s*(.-)%s*$")
			if txt == "return" then
				local out = {}
				for k = 1, #lines do
					if k ~= last then out[#out+1] = lines[k] end
				end
				return out
			end
		end
		return lines
	end
	local endIndent = lines[last]:match("^(%s*)")
	local prev = last - 1
	while prev >= 1 and not lines[prev]:match("%S") do prev = prev - 1 end
	if prev < 1 then return lines end
	local ri, rtext = matchReturn(lines[prev])
	if not ri or not rtext then return lines end
	if rtext:match("^%s*$") then return lines end  -- non-bare return
	if rtext:match("^return%s+.") then return lines end  -- has value
	local retIndent = ri
	if #retIndent <= #endIndent then return lines end
	-- verify nothing shallower between prev and last
	for k = prev + 1, last - 1 do
		if lines[k]:match("%S") then
			local ki = lines[k]:match("^(%s*)")
			if #ki <= #endIndent then return lines end
		end
	end
	local out = {}
	for k = 1, #lines do
		if k ~= prev then out[#out+1] = lines[k] end
	end
	return out
end

-- `else { if X then BODY end }` -> `elseif X then BODY`
local function liftElseifPatterns(lines)
	local out = {}
	for _, ln in ipairs(lines) do out[#out+1] = ln end
	local i = 1
	while i <= #out do
		local transformed = false
		local outerInd = out[i]:match("^(%s*)else%s*$")
		if outerInd and i + 1 <= #out then
			local innerExtra, cond = out[i+1]:match("^" .. luaPE(outerInd) .. "(%s+)if%s+(.-)%s+then%s*$")
			if innerExtra and cond then
				local innerInd = outerInd .. innerExtra
				local depth = 1
				local j = i + 2
				while j <= #out and depth > 0 do
					local s = out[j]:match("^%s*(.-)%s*$")
					local li = out[j]:match("^(%s*)")
					if #li == #innerInd then
						if s:sub(1,3) == "if " or s:sub(1,4) == "for " or s:sub(1,6) == "while " or s == "repeat" or s == "do" then
							depth = depth + 1
						elseif s == "end" or s:sub(1,6) == "until " then
							depth = depth - 1
						end
					end
					j = j + 1
				end
				j = j - 1
				if depth == 0 and j + 1 <= #out and matchEnd(out[j+1]) then
					local outerEndInd = out[j+1]:match("^(%s*)")
					if outerEndInd == outerInd then
						local newBlock = {outerInd .. "elseif " .. cond .. " then"}
						for k = i + 2, j - 1 do
							local ln2 = out[k]
							if ln2:sub(1, #innerExtra) == innerExtra then newBlock[#newBlock+1] = ln2:sub(#innerExtra+1)
							else newBlock[#newBlock+1] = ln2 end
						end
						for k = 1, #newBlock do out[i + k - 1] = newBlock[k] end
						for _ = #newBlock + i, j do table.remove(out, #newBlock + i) end
						transformed = true
					end
				end
			end
		end
		if not transformed then
			i = i + 1
		end
	end
	return out
end

-- After `if not X then return end` (or `if X then return end`), we know X has
-- a definite truthiness value. The IMMEDIATELY NEXT line being a same-cond
-- check on X can be simplified:
--   `if not X then return end` then `if not X then return end` -> drop the second
--   `if not X then return end` then `if X then return end`     -> replace second with `return`
-- This conservative form only looks at adjacent lines and only handles other
-- inline early-return guards (not multi-line if blocks). It's safe under
-- arbitrary subsequent code because we only delete/replace single lines that
-- have a deterministic effect under the established guard.
local function simplifyAfterEarlyReturn(lines)
	local function extractCond(text)
		local cond = text:match("^if%s+(.-)%s+then%s+return%s+end$")
		if not cond then
			cond = text:match("^if%s+(.-)%s+then%s+return%s+nil%s+end$")
		end
		if not cond then return nil end
		cond = cond:match("^%s*(.-)%s*$")
		local negated = false
		local stripped = cond:match("^not%s+%((.+)%)$") or cond:match("^not%s+(.+)$")
		if stripped then negated = true; cond = stripped end
		while true do
			local inner = cond:match("^%((.+)%)$")
			if not inner then break end
			cond = inner
		end
		return cond, negated
	end
	local function isSimpleGuardExpr(s)
		if s:match("^[%a_][%w_]*$") then return true end
		if s:match("^[%a_][%w_]*%.[%a_][%w_%.]*$") then return true end
		return false
	end
	local out = {}
	for _, ln in ipairs(lines) do out[#out + 1] = ln end
	local i = 1
	while i <= #out - 1 do
		local lineText = out[i]:match("^%s*(.-)%s*$") or ""
		local lineInd = out[i]:match("^(%s*)") or ""
		local guardCond, guardNeg = extractCond(lineText)
		if guardCond and isSimpleGuardExpr(guardCond) then
			-- Look at next non-empty/non-comment line at the SAME indent only.
			local j = i + 1
			-- Skip comments and blank lines.
			while j <= #out do
				local jText = out[j]:match("^%s*(.-)%s*$") or ""
				if jText == "" or jText:sub(1, 2) == "--" then
					j = j + 1
				else
					break
				end
			end
			if j <= #out then
				local jInd = out[j]:match("^(%s*)") or ""
				local jText = out[j]:match("^%s*(.-)%s*$") or ""
				if jInd == lineInd then
					local jCond, jNeg = extractCond(jText)
					if jCond and jCond == guardCond then
						if jNeg == guardNeg then
							-- Same cond, same neg: redundant, drop second.
							table.remove(out, j)
						else
							-- Inverted: second always returns.
							out[j] = jInd .. "return"
						end
					end
				end
			end
		end
		i = i + 1
	end
	return out
end

-- `if A then if B then BODY end end` -> `if A and B then BODY end`
-- Drop redundant nested `if X then if X then BODY end end` (same condition)
-- to `if X then BODY end`. Useful when lift passes produce duplicates.
local function dropRedundantNestedSameCond(lines)
	local changed = true
	while changed do
		changed = false
		local out = {}
		for _, ln in ipairs(lines) do out[#out+1] = ln end
		local i = 1
		while i <= #out - 1 do
			local outerInd, outerCond = out[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
			local innerInd, innerCond = (out[i + 1] or ""):match("^(%s*)if%s+(.+)%s+then%s*$")
			if outerInd and innerInd and outerCond and innerCond
				and innerInd == outerInd .. "\t"
				and outerCond == innerCond
			then
				-- Find matching inner `end` at innerInd
				local depth = 1
				local innerEnd = nil
				for j = i + 2, #out do
					local jInd = out[j]:match("^(%s*)") or ""
					local jText = out[j]:match("^%s*(.-)%s*$") or ""
					if #jInd == #innerInd then
						if jText == "end" then
							depth = depth - 1
							if depth == 0 then innerEnd = j; break end
						elseif jText:sub(1, 3) == "if " and jText:sub(-5) == " then" then
							depth = depth + 1
						elseif jText == "else" or jText:sub(1, 7) == "elseif " then
							-- Has branch; not a simple single-if
							depth = -1; break
						end
					end
				end
				if innerEnd and depth == 0 then
					-- Verify next line after innerEnd is the outer `end` at outerInd
					local outerEnd = innerEnd + 1
					if outerEnd <= #out then
						local oText = out[outerEnd]:match("^%s*(.-)%s*$") or ""
						local oInd = out[outerEnd]:match("^(%s*)") or ""
						if oText == "end" and oInd == outerInd then
							-- Replace: drop the inner `if X then` and inner `end`,
							-- de-indent the body lines once.
							local newLines = {}
							for k = 1, i do newLines[#newLines+1] = out[k] end
							for k = i + 2, innerEnd - 1 do
								local bl = out[k]
								if bl:sub(1, 1) == "\t" then
									newLines[#newLines+1] = bl:sub(2)
								else
									newLines[#newLines+1] = bl
								end
							end
							for k = outerEnd, #out do newLines[#newLines+1] = out[k] end
							out = newLines
							lines = out
							changed = true
						end
					end
				end
			end
			i = i + 1
		end
		lines = out
	end
	return lines
end

local function collapseSingleIfChain(lines)
	local changed = true
	while changed do
		changed = false
		local out = {}
		for _, ln in ipairs(lines) do out[#out+1] = ln end
		local i = 1
		while i <= #out do
			local transformed = false
			local outerInd, outerCond = matchIfOpen(out[i])
			if outerInd and i + 1 <= #out then
				local innerInd2, innerCond = matchIfOpen(out[i+1])
				if innerInd2 and innerInd2 == outerInd .. "\t" then
					local depth = 1
					local j = i + 2
					local innerHasBranch = false
					while j <= #out and depth > 0 do
						local s = out[j]:match("^%s*(.-)%s*$")
						local li = out[j]:match("^(%s*)")
						if #li == #innerInd2 then
							if s == "else" or s:sub(1,7) == "elseif " then innerHasBranch = true end
							if s:sub(1,3) == "if " or s:sub(1,4) == "for " or s:sub(1,6) == "while " or s == "repeat" or s == "do" then
								depth = depth + 1
							elseif s == "end" or s:sub(1,6) == "until " then
								depth = depth - 1
							end
						end
						j = j + 1
					end
					j = j - 1
					if depth == 0 and j + 1 <= #out and not innerHasBranch and matchEnd(out[j+1]) and out[j+1]:match("^(%s*)") == outerInd then
						local outerHasBranch = false
						for k = i + 1, j + 1 do
							local s2 = out[k]:match("^%s*(.-)%s*$")
							local li2 = out[k]:match("^(%s*)")
							if #li2 == #outerInd and (s2 == "else" or s2:sub(1,7) == "elseif ") then
								outerHasBranch = true
								break
							end
						end
						if not outerHasBranch then
							-- If inner cond matches outer cond exactly, drop the redundant
							-- inner `if X then ... end` wrapper (semantically equivalent).
							local combined
							if outerCond == innerCond then
								combined = outerCond
							else
								combined = wrapForAnd(outerCond) .. " and " .. wrapForAnd(innerCond)
							end
							local newBlock = {outerInd .. "if " .. combined .. " then"}
							for k = i + 2, j - 1 do
								local bl = out[k]
								if bl:sub(1,1) == "\t" then newBlock[#newBlock+1] = bl:sub(2)
								else newBlock[#newBlock+1] = bl end
							end
							newBlock[#newBlock+1] = outerInd .. "end"
							for k = 0, #newBlock - 1 do out[i + k] = newBlock[k + 1] end
							for _ = i + #newBlock, j + 1 do table.remove(out, i + #newBlock) end
							lines = out
							changed = true
							transformed = true
						end
					end
				end
				if transformed then
					break
				end
			end
			if not transformed then
				i = i + 1
			end
		end
	end
	return lines
end

-- Drop empty `if cond then end` blocks
-- Drop dead else-clobber: `if COND then X = E end / else X = E end` where the
-- same X is assigned to the same expression E in both branches (and X was
-- assigned before the if). The else branch is dead because the truthy path
-- preserves X's prior value; the else's clobber would overwrite it.
-- This handles the bytecode pattern from `or` short-circuit fallback that
-- was over-decoded into both branches.
local function dropDeadElseClobber(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local handled = false
		if i + 4 <= #lines then
			local ifInd, ifCond = lines[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
			local thenLine = lines[i + 1]
			local elseInd = lines[i + 2]:match("^(%s*)else%s*$")
			local elseLine = lines[i + 3]
			local endInd = lines[i + 4]:match("^(%s*)end%s*$")
			if ifInd and elseInd == ifInd and endInd == ifInd then
				local thenLineInd = thenLine:match("^(%s*)") or ""
				local elseLineInd = elseLine:match("^(%s*)") or ""
				if thenLineInd == elseLineInd and #thenLineInd > #ifInd then
					local thenAssign = thenLine:sub(#thenLineInd + 1)
					local elseAssign = elseLine:sub(#elseLineInd + 1)
					if thenAssign == elseAssign then
						local lhs, rhs = thenAssign:match("^([%a_][%w_.%[%]]*)%s*=%s*(.+)$")
						if lhs and rhs and not lhs:find("(", 1, true) then
							local xBase = lhs:match("^([%a_][%w_]*)") or lhs
							local assignedBefore = false
							local scanStart = math.max(1, i - 12)
							for k = scanStart, i - 1 do
								local kInd = lines[k]:match("^(%s*)") or ""
								if #kInd <= #thenLineInd then
									if lines[k]:match("^" .. luaPE(kInd) .. luaPE(lhs) .. "%s*=") then
										assignedBefore = true; break
									end
									if lines[k]:match("^" .. luaPE(kInd) .. "local%s+" .. luaPE(xBase) .. "%s*=") then
										assignedBefore = true; break
									end
								end
							end
							if assignedBefore then
								out[#out+1] = ifInd .. "if " .. ifCond .. " then"
								out[#out+1] = thenLine
								out[#out+1] = ifInd .. "end"
								i = i + 5
								handled = true
							end
						end
					end
				end
			end
		end
		if not handled then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function dropEmptyIfBlocks(lines)
	-- Drop `if nil then BODY end` (dead — condition always false). The BODY
	-- never executes; we drop the entire block. This handles cases where
	-- earlier passes reduced a phi-boolean to constant `nil` (always-false).
	-- Also drops `if false then BODY end` and lifts `if true then BODY end`
	-- to BODY (constant-true unwrap).
	do
		local n = #lines
		local i = 1
		local out0 = {}
		while i <= n do
			local ind, cond = lines[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
			if ind and (cond == "nil" or cond == "false") then
				-- Find matching end at same indent.
				local depth = 1
				local endIdx = nil
				local elseIdx = nil
				for k = i + 1, n do
					local kInd = lines[k]:match("^(%s*)") or ""
					local kTxt = lines[k]:match("^%s*(.-)%s*$") or ""
					if kInd == ind then
						if kTxt == "end" or kTxt:match("^end[%),;]") then
							depth = depth - 1
							if depth == 0 then endIdx = k; break end
						elseif kTxt == "else" and depth == 1 then
							elseIdx = k
						elseif kTxt:match("^elseif%s") and depth == 1 then
							-- elseif with constant-false head: convert first elseif
							-- into the new `if`. Bail conservatively for now.
							break
						end
					elseif kTxt:match("^if%s.+%sthen%s*$") and not kTxt:match("end%s*$") then
						-- nested if open at deeper indent: don't increase depth
						-- (we only care about same-indent end).
					end
				end
				if endIdx and elseIdx then
					-- Emit only the else body (between elseIdx+1 and endIdx-1),
					-- de-indenting by one level.
					for k = elseIdx + 1, endIdx - 1 do
						local body = lines[k]
						if body:sub(1, 1) == "\t" then
							out0[#out0 + 1] = body:sub(2)
						else
							out0[#out0 + 1] = body
						end
					end
					i = endIdx + 1
				elseif endIdx then
					i = endIdx + 1
				else
					out0[#out0 + 1] = lines[i]
					i = i + 1
				end
			elseif ind and cond == "true" then
				-- `if true then BODY end` → BODY (unwrap, drop indent).
				local depth = 1
				local endIdx = nil
				for k = i + 1, n do
					local kInd = lines[k]:match("^(%s*)") or ""
					local kTxt = lines[k]:match("^%s*(.-)%s*$") or ""
					if kInd == ind then
						if kTxt == "end" or kTxt:match("^end[%),;]") then
							depth = depth - 1
							if depth == 0 then endIdx = k; break end
						elseif kTxt == "else" or kTxt:match("^elseif%s") then
							break
						end
					end
				end
				if endIdx then
					-- Emit body with reduced indent (one level).
					for k = i + 1, endIdx - 1 do
						local body = lines[k]
						-- Strip one tab of leading indent if present.
						if body:sub(1, 1) == "\t" then
							out0[#out0 + 1] = body:sub(2)
						else
							out0[#out0 + 1] = body
						end
					end
					i = endIdx + 1
				else
					out0[#out0 + 1] = lines[i]
					i = i + 1
				end
			else
				out0[#out0 + 1] = lines[i]
				i = i + 1
			end
		end
		lines = out0
	end
	local changed = true
	local out = {}
	for _, ln in ipairs(lines) do out[#out+1] = ln end
	while changed do
		changed = false
		local new = {}
		local i = 1
		while i <= #out do
			local removed = false
			if i + 2 <= #out then
				local iind = matchIfOpen(out[i])
				local eind1 = out[i+1]:match("^(%s*)else%s*$")
				local eind2 = matchEnd(out[i+2])
				if iind and eind1 and eind2 and iind == eind1 and iind == eind2 then
					i = i + 3
					changed = true
					removed = true
				end
			end
			if not removed and i + 1 <= #out then
				local iind = matchIfOpen(out[i])
				local eind = matchEnd(out[i+1])
				if iind and eind and iind == eind then
					i = i + 2
					changed = true
					removed = true
				end
			end
			-- New: drop chains like `if X then elseif Y then [...elseif Z then] end`
			-- where ALL bodies are empty (each branch immediately followed by
			-- `elseif`/`else`/`end`). Preserves no observable side effects since
			-- Lua doesn't evaluate Y/Z if X is true, but with all-empty bodies
			-- the entire chain has no effect (except condition side effects,
			-- which we conservatively retain only for non-trivial conditions).
			if not removed then
				local iind = matchIfOpen(out[i])
				if iind then
					-- Walk forward looking for `elseif`/`else`/`end` at same indent.
					-- Track if any branch has a non-empty body.
					local k = i + 1
					local segments = {}  -- list of {indent, kind = "elseif"|"else", contentEmpty=bool}
					local allEmpty = true
					local closeIdx = nil
					-- The first segment is `if X`, which has body lines from i+1 to next branch.
					local prevHeaderIdx = i
					while k <= #out do
						local kInd = out[k]:match("^(%s*)") or ""
						local kTxt = out[k]:match("^%s*(.-)%s*$") or ""
						if kInd == iind and (kTxt:match("^elseif%s") or kTxt == "else") then
							-- Body of previous segment is lines [prevHeaderIdx+1 .. k-1]; check empty.
							local bodyEmpty = true
							for j = prevHeaderIdx + 1, k - 1 do
								if out[j]:match("%S") then bodyEmpty = false; break end
							end
							if not bodyEmpty then allEmpty = false end
							prevHeaderIdx = k
							k = k + 1
						elseif kInd == iind and (kTxt == "end" or kTxt:match("^end[%),;]")) then
							-- final body
							local bodyEmpty = true
							for j = prevHeaderIdx + 1, k - 1 do
								if out[j]:match("%S") then bodyEmpty = false; break end
							end
							if not bodyEmpty then allEmpty = false end
							closeIdx = k
							break
						elseif kInd == iind and not (kTxt == "" or kTxt:match("^elseif%s") or kTxt == "else") then
							-- Same indent but not branch keyword: shouldn't happen mid-block.
							-- Bail.
							break
						else
							k = k + 1
						end
					end
					if closeIdx and allEmpty then
						i = closeIdx + 1
						changed = true
						removed = true
					end
				end
			end
			if not removed then
				new[#new+1] = out[i]
				i = i + 1
			end
		end
		out = new
	end
	return out
end

local function dropLoadbArtifacts(lines)
	local out = {}
	for _, line in ipairs(lines) do
		if line:match("^%s*%-%-%s+LOADB%s+R%d+%s+=") then
		else
			out[#out+1] = line
		end
	end
	return out
end

local function fixLoadbSkipBooleanAssignments(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local ifInd, cond = matchIfOpen(lines[i] or "")
		if ifInd and i + 3 <= #lines then
			local assignInd, name, firstValue = (lines[i + 1] or ""):match("^(%s*)([%a_][%w_]*)%s*=%s*(%a+)%s*%-%-%s*skip%s+1%s*$")
			local endInd = matchEnd(lines[i + 2] or "")
			local elseAssignInd, elseName, secondValue = (lines[i + 3] or ""):match("^(%s*)([%a_][%w_]*)%s*=%s*(%a+)%s*$")
			if assignInd
				and (firstValue == "true" or firstValue == "false")
				and endInd == ifInd
				and elseAssignInd
				and (secondValue == "true" or secondValue == "false")
				and name == elseName
				and firstValue ~= secondValue
			then
				out[#out + 1] = lines[i]
				out[#out + 1] = assignInd .. name .. " = " .. firstValue
				out[#out + 1] = ifInd .. "else"
				out[#out + 1] = assignInd .. name .. " = " .. secondValue
				out[#out + 1] = lines[i + 2]
				i = i + 4
			else
				out[#out + 1] = lines[i]
				i = i + 1
			end
		else
			out[#out + 1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function dropUnknownOpArtifacts(lines)
	local out = {}
	for _, line in ipairs(lines) do
		if line:match("^%s*%-%-%s+ROBLOX_OP_%d+%s+") then
			-- skip
		else
			out[#out+1] = line
		end
	end
	return out
end

-- Remove self-assignment no-op lines: `<indent>X = X` where both sides are the same identifier.
-- These arise from MOVE Rdst = Rsrc when both registers share the same name.
local function dropSelfAssignmentNoops(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local name = line:match("^%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*$")
		-- only drop if: exactly "INDENT NAME = NAME" (bare assignment, no `local`, same ident both sides)
		if name and line:match("^%s+([%a_][%w_]*)%s*=%s*%1%s*$") and not line:match("^%s*local%s") then
			-- self-assignment no-op: skip
		else
			out[#out+1] = line
		end
	end
	return out
end

-- Drop duplicate consecutive assignments: `local X = Y` followed by `X = Y` (same RHS).
-- Arises when the bytecode has both an analysis-driven local declaration and a
-- subsequent MOVE that re-asserts the same value. The second assignment is
-- always a no-op since it copies from itself.
-- Drop dead `NAME = nil` immediately followed by `NAME = expr` where expr
-- isn't `nil` — the nil assignment is overwritten before being read.
local function dropDeadNilThenAssign(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local cur = lines[i]
		if i + 1 <= #lines then
			local ind1, name1 = cur:match("^(%s*)([%a_][%w_]*)%s*=%s*nil%s*$")
			local ind2, name2, rhs2 = lines[i + 1]:match("^(%s*)([%a_][%w_]*)%s*=%s*(.+)$")
			if ind1 and name1 and ind2 and name2 and rhs2
				and ind1 == ind2 and name1 == name2
				and not cur:match("^%s*local%s")
				and not lines[i + 1]:match("^%s*local%s")
				and rhs2:match("^%s*(.-)%s*$") ~= "nil"
			then
				-- skip the dead nil assign
				i = i + 1
			else
				out[#out + 1] = cur
				i = i + 1
			end
		else
			out[#out + 1] = cur
			i = i + 1
		end
	end
	return out
end

-- Final defensive pass: detect lines with unbalanced parentheses and try to
-- repair them so the output compiles. Some renderer paths leave malformed
-- expressions like `LHS = X) and not (Y` (extra `)` mid-expression and
-- missing `)` at end); this is a structural rendering bug we couldn't
-- pinpoint, so this fallback at least keeps the file compilable.
local function balanceLineParens(lines)
	local function stripStringsAndComments(line)
		local i, n = 1, #line
		local inStr = nil
		local buf = {}
		while i <= n do
			local c = line:sub(i, i)
			if inStr then
				buf[#buf + 1] = " "
				if c == "\\" and i + 1 <= n then
					buf[#buf + 1] = " "
					i = i + 2
				elseif c == inStr then
					inStr = nil
					i = i + 1
				else
					i = i + 1
				end
			elseif c == '"' or c == "'" then
				inStr = c
				buf[#buf + 1] = " "
				i = i + 1
			elseif c == "-" and line:sub(i + 1, i + 1) == "-" then
				for _ = 1, n - i + 1 do buf[#buf + 1] = " " end
				break
			elseif c == "[" and line:sub(i, i + 1) == "[[" then
				local close = line:find("]]", i + 2, true)
				if close then
					for _ = 1, close - i + 2 do buf[#buf + 1] = " " end
					i = close + 2
				else
					buf[#buf + 1] = c
					i = i + 1
				end
			else
				buf[#buf + 1] = c
				i = i + 1
			end
		end
		return table.concat(buf)
	end
	local out = {}
	for _, line in ipairs(lines) do
		local fixed = line
		local stripped = stripStringsAndComments(line)
		local depth = 0
		local minDepth = 0
		local firstExtraClosePos = nil
		for k = 1, #stripped do
			local c = stripped:sub(k, k)
			if c == "(" then
				depth = depth + 1
			elseif c == ")" then
				depth = depth - 1
				if depth < minDepth then
					minDepth = depth
					if not firstExtraClosePos then
						firstExtraClosePos = k
					end
				end
			end
		end
		if depth ~= 0 or minDepth < 0 then
			local stripText = stripped:match("^%s*(.-)%s*$") or ""
			-- Skip natural multi-line openers (function literals, control statements,
			-- expression continuations).
			local isMultilineOpen = stripText:find("function%s*%(", 1)
				or stripText:match("^if%s") or stripText:match("^while%s")
				or stripText:match("^for%s") or stripText:match("^do%s*$")
				or stripText:match("^else%s*$") or stripText:match("^elseif%s")
				or stripText:match("^return%s*$") or stripText:match("^return%s+$")
				or stripText:match("[,(]%s*$")
			-- Also skip natural multi-line CLOSERS — any line starting with
			-- `end` (closes a function/if/for/while; trailing parens close
			-- OUTER expressions and shouldn't be trimmed).
			local isMultilineClose = stripText:match("^end") ~= nil
				or stripText:match("^%)+[%s,;]*$")
				or stripText:match("^until%s")
			if not isMultilineOpen and not isMultilineClose and minDepth < 0 and firstExtraClosePos then
				-- Remove the offending `)`.
				local origLine = line
				fixed = line:sub(1, firstExtraClosePos - 1) .. line:sub(firstExtraClosePos + 1)
				-- Recompute depth on the fixed line.
				local fixedStripped = stripStringsAndComments(fixed)
				local d = 0
				for k = 1, #fixedStripped do
					local c = fixedStripped:sub(k, k)
					if c == "(" then d = d + 1
					elseif c == ")" then d = d - 1 end
				end
				if d > 0 then
					fixed = fixed .. string.rep(")", d)
				end
			end
		end
		out[#out + 1] = fixed
	end
	return out
end

-- Lift orphan-goto skip chains: `if X then goto LBL end; if Y then goto LBL end; TAIL`
-- where LBL has no corresponding `::LBL::` definition (orphan target). The
-- skip-chain semantically means "if any of X/Y, jump past TAIL". When LBL is
-- missing, the original semantics were: "TAIL runs only when all conditions
-- are false". We rewrite:
--   `if not X and not Y then TAIL end`
-- TAIL is the contiguous block following the chain, ending at:
--   - the next goto chain (different label), OR
--   - a function `end` / `return`, OR
--   - any `do`/`if`/loop opener that isn't a single-line `if ... then ... end`.
-- Lift `if A then BODY; goto LBL end; if B then ... end; if C then ... end`
-- (where LBL is orphan/forward) into proper `if A then BODY elseif B then ... elseif C then ... end`.
-- This recovers if-chains that were compiled with goto for early-exit between
-- mutually-exclusive checks.
local function liftGotoChainToElseif(lines)
	local existingLabels = {}
	for _, line in ipairs(lines) do
		local _, lbl = matchLbl(line)
		if lbl then existingLabels[lbl] = true end
	end
	local out = {}
	local n = #lines
	local i = 1
	while i <= n do
		local consumed = false
		local ind, cond = lines[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
		if ind then
			local depth = 1
			local endIdx = nil
			for k = i + 1, n do
				local kInd = lines[k]:match("^(%s*)") or ""
				local kTxt = lines[k]:match("^%s*(.-)%s*$") or ""
				if kInd == ind then
					if kTxt == "end" or kTxt:match("^end[%),;]") then
						depth = depth - 1
						if depth == 0 then endIdx = k; break end
					end
				end
			end
			if endIdx then
				local lastNonEmpty = endIdx - 1
				while lastNonEmpty > i and not lines[lastNonEmpty]:match("%S") do
					lastNonEmpty = lastNonEmpty - 1
				end
				local _, gtgt = matchGoto(lines[lastNonEmpty])
				if not gtgt then
					gtgt = lines[lastNonEmpty]:match("^%s*%-%-%[%[goto%s+(pc%d+)%]%]%s*$")
				end
				if gtgt and not existingLabels[gtgt] then
					local nextIdx = endIdx + 1
					while nextIdx <= n and not lines[nextIdx]:match("%S") do
						nextIdx = nextIdx + 1
					end
					if nextIdx <= n then
						local nInd = lines[nextIdx]:match("^(%s*)if%s+.-%s+then")
						if nInd == ind then
							-- Begin chain.
							out[#out + 1] = lines[i]
							for k = i + 1, lastNonEmpty - 1 do
								out[#out + 1] = lines[k]
							end
							local cur = nextIdx
							while cur <= n do
								local cInd, cCond = lines[cur]:match("^(%s*)if%s+(.+)%s+then%s*$")
								local cInd2, cCond2, cBody = lines[cur]:match("^(%s*)if%s+(.+)%s+then%s+(.+)%s+end%s*$")
								if cInd == ind and not cInd2 then
									local cEnd = nil
									local d = 1
									for k = cur + 1, n do
										local kInd3 = lines[k]:match("^(%s*)") or ""
										local kTxt3 = lines[k]:match("^%s*(.-)%s*$") or ""
										if kInd3 == ind then
											if kTxt3 == "end" or kTxt3:match("^end[%),;]") then
												d = d - 1
												if d == 0 then cEnd = k; break end
											end
										end
									end
									if not cEnd then break end
									out[#out + 1] = ind .. "elseif " .. cCond .. " then"
									local cLastNonEmpty = cEnd - 1
									while cLastNonEmpty > cur and not lines[cLastNonEmpty]:match("%S") do
										cLastNonEmpty = cLastNonEmpty - 1
									end
									local _, cgtgt = matchGoto(lines[cLastNonEmpty])
									if not cgtgt then
										cgtgt = lines[cLastNonEmpty]:match("^%s*%-%-%[%[goto%s+(pc%d+)%]%]%s*$")
									end
									local bodyEnd = cgtgt == gtgt and cLastNonEmpty - 1 or cEnd - 1
									for k = cur + 1, bodyEnd do
										out[#out + 1] = lines[k]
									end
									cur = cEnd + 1
									while cur <= n and not lines[cur]:match("%S") do
										cur = cur + 1
									end
								elseif cInd2 == ind then
									out[#out + 1] = ind .. "elseif " .. cCond2 .. " then " .. cBody .. " "
									cur = cur + 1
									while cur <= n and not lines[cur]:match("%S") do
										cur = cur + 1
									end
								else
									break
								end
							end
							out[#out + 1] = ind .. "end"
							i = cur
							consumed = true
						end
					end
				end
				if not consumed then
					for k = i, endIdx do
						out[#out + 1] = lines[k]
					end
					i = endIdx + 1
					consumed = true
				end
			end
		end
		if not consumed then
			out[#out + 1] = lines[i]
			i = i + 1
		end
	end
	return out
end

-- Convert orphan-target single `goto LBL` or `if X then goto LBL end` to
-- equivalent loop `break`/`continue` or function `return` based on the
-- nearest enclosing scope. This handles cases the orphan-skip-chain pass
-- can't lift (e.g., goto with no tail at same indent — "last statement
-- in its parent block" position).
local function convertOrphanGotosToFlow(lines)
	-- Identify existing labels.
	local existingLabels = {}
	for _, line in ipairs(lines) do
		local _, lbl = matchLbl(line)
		if lbl then existingLabels[lbl] = true end
	end
	-- For each line, determine its "nearest enclosing loop" by tracking a
	-- block stack. We assume tab-based indent equals nesting levels.
	-- Stack entry: { kind = "function"|"loop"|"if"|"do", ind = indent }
	local stack = {}
	local out = {}
	for i, line in ipairs(lines) do
		local indent = line:match("^(%s*)") or ""
		local txt = line:match("^%s*(.-)%s*$") or ""
		-- Pop blocks at greater-or-equal indent if this line is `end`/`until`.
		-- Actually easier: pop based on indent.
		while #stack > 0 and #indent <= #stack[#stack].ind do
			table.remove(stack)
		end
		-- Determine if this line opens a new block.
		local opensKind = nil
		if txt:match("^function%s") or txt:match("^local%s+function%s") then
			opensKind = "function"
		elseif txt:match("=%s*function%s*%(") then
			opensKind = "function"
		elseif txt:match("^if%s") and txt:match("then$") then
			opensKind = "if"
		elseif txt:match("^elseif%s") and txt:match("then$") then
			opensKind = "if"
		elseif (txt:match("^for%s") and txt:match("do$")) or (txt:match("^while%s") and txt:match("do$")) then
			opensKind = "loop"
		elseif txt == "do" then
			opensKind = "do"
		elseif txt == "repeat" then
			opensKind = "loop"
		end
		-- Determine nearest loop above us (before pushing the new block).
		local function nearestLoopOnStack()
			for k = #stack, 1, -1 do
				if stack[k].kind == "loop" then return stack[k] end
				if stack[k].kind == "function" then return nil end
			end
			return nil
		end
		-- Process the line.
		local rewritten = line
		local ifInd, ifCond, ifTgt = matchIfGoto(line)
		local gInd, gTgt = matchGoto(line)
		if ifInd and ifTgt and not existingLabels[ifTgt] then
			-- Orphan `if X then goto LBL end` — convert.
			local nl = nearestLoopOnStack()
			if nl then
				rewritten = ifInd .. "if " .. ifCond .. " then break end"
			else
				-- No enclosing loop. Forward orphan goto in function context
				-- is most commonly an early-exit. Convert to `return`.
				-- We only do this when we're inside SOME function (not module).
				local inFunction = false
				for k = #stack, 1, -1 do
					if stack[k].kind == "function" then inFunction = true; break end
				end
				if inFunction then
					rewritten = ifInd .. "if " .. ifCond .. " then return end"
				end
			end
		elseif gInd and gTgt and not existingLabels[gTgt] then
			-- Orphan bare `goto LBL` — convert.
			local nl = nearestLoopOnStack()
			if nl then
				rewritten = gInd .. "break"
			else
				local inFunction = false
				for k = #stack, 1, -1 do
					if stack[k].kind == "function" then inFunction = true; break end
				end
				if inFunction then
					rewritten = gInd .. "return"
				end
			end
		end
		out[#out + 1] = rewritten
		if opensKind then
			stack[#stack + 1] = { kind = opensKind, ind = indent }
		end
	end
	return out
end

-- Eliminate `goto LBL` statements where the target `::LBL::` exists somewhere
-- after, by analyzing what code lies between. There are two common structural
-- patterns we can lift cleanly:
--
-- Pattern A (unconditional goto):
--   goto LBL
--   CODE   -- unreachable
--   ::LBL::
-- Action: drop both the goto and CODE (CODE is dead code), drop the label.
--
-- Pattern B (single-line conditional goto skipping a small block):
--   if X then goto LBL end
--   CODE   -- runs when not X
--   ::LBL::
-- Action: rewrite as `if not X then CODE end` and drop the label.
local function liftGotoLabelStructural(lines)
	local labelPos = {}
	for i, line in ipairs(lines) do
		local _, lbl = matchLbl(line)
		if lbl then labelPos[lbl] = i end
	end
	if next(labelPos) == nil then return lines end
	local out = {}
	local i = 1
	local n = #lines
	while i <= n do
		local handled = false
		local gInd, gTgt = matchGoto(lines[i])
		if gInd and labelPos[gTgt] then
			local labelIdx = labelPos[gTgt]
			if labelIdx > i then
				local lblInd = lines[labelIdx]:match("^(%s*)") or ""
				if #lblInd <= #gInd then
					local safe = true
					for k = i + 1, labelIdx - 1 do
						local _, klbl = matchLbl(lines[k])
						if klbl then
							local pat = "%f[%a_]goto%s+" .. luaPE(klbl) .. "%f[^%a_%d]"
							for j = 1, n do
								if (j < i or j > labelIdx - 1) and lines[j]:find(pat) then
									safe = false; break
								end
							end
							if not safe then break end
						end
					end
					if safe then
						i = labelIdx + 1
						handled = true
					end
				end
			end
		end
		if not handled then
			local ifInd, ifCond, ifTgt = matchIfGoto(lines[i])
			if ifInd and labelPos[ifTgt] then
				local labelIdx = labelPos[ifTgt]
				local refCount = 0
				for j = 1, n do
					local _, gj = matchGoto(lines[j])
					local _, _, igj = matchIfGoto(lines[j])
					if gj == ifTgt or igj == ifTgt then refCount = refCount + 1 end
				end
				if refCount == 1 and labelIdx > i then
					local lblInd = lines[labelIdx]:match("^(%s*)") or ""
					if #lblInd <= #ifInd then
						local safeBlock = true
						for k = i + 1, labelIdx - 1 do
							local kInd = lines[k]:match("^(%s*)") or ""
							local kTxt = lines[k]:match("^%s*(.-)%s*$") or ""
							if kTxt ~= "" and #kInd < #ifInd then safeBlock = false; break end
							local _, klbl = matchLbl(lines[k])
							if klbl then safeBlock = false; break end
						end
						if safeBlock then
							out[#out + 1] = ifInd .. "if " .. negateCond(ifCond) .. " then"
							for k = i + 1, labelIdx - 1 do
								if lines[k]:match("%S") then
									out[#out + 1] = "\t" .. lines[k]
								else
									out[#out + 1] = lines[k]
								end
							end
							out[#out + 1] = ifInd .. "end"
							i = labelIdx + 1
							handled = true
						end
					end
				end
			end
		end
		if not handled then
			out[#out + 1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function liftOrphanGotoSkipChains(lines)
	local existingLabels = {}
	for _, ln in ipairs(lines) do
		local _, lbl = matchLbl(ln)
		if lbl then existingLabels[lbl] = true end
	end
	local out = {}
	local i = 1
	local n = #lines
	while i <= n do
		local ind, cond, target = matchIfGoto(lines[i])
		if not ind or existingLabels[target] then
			out[#out + 1] = lines[i]
			i = i + 1
		else
			local conds = { cond }
			local j = i + 1
			while j <= n do
				local jInd, jCond, jTgt = matchIfGoto(lines[j])
				if jInd == ind and jTgt == target then
					conds[#conds + 1] = jCond
					j = j + 1
				else
					break
				end
			end
			local tailStart = j
			local tailEnd = j - 1
			local k = j
			while k <= n do
				local kLine = lines[k]
				local kInd = kLine:match("^(%s*)") or ""
				local kTxt = kLine:match("^%s*(.-)%s*$") or ""
				if #kInd < #ind then break end
				if kInd == ind and (kTxt == "end" or kTxt == "else"
					or kTxt:match("^elseif%s") or kTxt:match("^end[%),;]")
					or kTxt:match("^until%s")) then
					break
				end
				if kInd == ind and kTxt:match("^::[%w_]+::$") then
					break
				end
				if kInd == ind then
					local _, _, kTgt = matchIfGoto(kLine)
					if kTgt and kTgt ~= target and not existingLabels[kTgt] then
						break
					end
					local _, gTgt = matchGoto(kLine)
					if gTgt then break end
				end
				tailEnd = k
				k = k + 1
			end
			if #conds >= 1 and tailEnd >= tailStart then
				local negParts = {}
				for _, c in ipairs(conds) do
					local nc = negateCond(c)
					if nc:match("^[%a_][%w_%.:]*%s*$") or nc:match("^not%s+[%a_][%w_%.]*%s*$") then
						negParts[#negParts + 1] = nc
					else
						negParts[#negParts + 1] = "(" .. nc .. ")"
					end
				end
				local combined = table.concat(negParts, " and ")
				out[#out + 1] = ind .. "if " .. combined .. " then"
				for tk = tailStart, tailEnd do
					out[#out + 1] = "\t" .. lines[tk]
				end
				out[#out + 1] = ind .. "end"
				i = tailEnd + 1
			else
				for cIdx = 1, #conds do
					out[#out + 1] = lines[i + cIdx - 1]
				end
				i = j
			end
		end
	end
	return out
end

-- Strip ALL `goto NAME` statements and `::NAME::` labels. Luau does not
-- support goto/label syntax at all; our lifting passes try to lift them but
-- some patterns survive. Without this pass the output won't even compile.
-- We replace `goto NAME` with `--[[goto NAME]]` and `::NAME::` with
-- `--[[label NAME]]` so the program at least parses. The runtime semantics
-- may be wrong for these specific blocks, but the rest of the file remains
-- inspectable.
local function stripDanglingGotos(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local rewritten = line
		-- Replace `goto NAME` (whole word, NAME being identifier).
		rewritten = rewritten:gsub("(%f[%w_])goto%s+([%w_]+)(%f[^%w_])", function(pre, target, post)
			return pre .. "--[[goto " .. target .. "]]" .. post
		end)
		-- Replace `::NAME::` labels with comments.
		rewritten = rewritten:gsub("::([%w_]+)::", function(name)
			return "--[[label " .. name .. "]]"
		end)
		out[#out + 1] = rewritten
	end
	-- Second pass: detect `return` followed by code in the same block (Lua
	-- requires `return` to be last in its block). Convert preceding `return`
	-- to `do return end` to permit subsequent statements.
	local out2 = {}
	for i, line in ipairs(out) do
		local txt = line:match("^%s*(.-)%s*$") or ""
		if (txt == "return" or txt:match("^return%s") or txt:match("^return$")) then
			-- Look at next non-blank, non-comment-only line.
			local nextNonEmpty = nil
			for j = i + 1, math.min(#out, i + 4) do
				local nxt = out[j]:match("^%s*(.-)%s*$") or ""
				if nxt == "" or nxt:match("^%-%-") then
					-- skip blank or pure comment
				else
					nextNonEmpty = nxt
					break
				end
			end
			if nextNonEmpty
				and nextNonEmpty ~= "end"
				and not nextNonEmpty:match("^end[%)%},;]")
				and not nextNonEmpty:match("^end$")
				and not nextNonEmpty:match("^end%s")
				and not nextNonEmpty:match("^elseif%s")
				and nextNonEmpty ~= "else"
				and not nextNonEmpty:match("^until%s") then
				-- Wrap `return` so subsequent code is allowed.
				local indent = line:match("^(%s*)") or ""
				out2[#out2 + 1] = indent .. "do " .. txt .. " end"
			else
				out2[#out2 + 1] = line
			end
		else
			out2[#out2 + 1] = line
		end
	end
	return out2
end

-- When a file has many top-level `local function NAME(...)` declarations and
-- they're referenced many times each (so they can't be inlined or wrapped in
-- `do...end`), we hit Lua/Luau's 200-locals-per-scope register limit. As a
-- last-resort fix, store the closures in a single table local so that all
-- closures share ONE register slot. Original `local function anon194() ... end`
-- becomes `_anon[194] = function() ... end`. Each `anon194` reference becomes
-- `_anon[194]`. This trades one local for many.
local function tableifyManyTopLevelClosures(lines)
	-- Count top-level `local function` decls.
	local fnCount = 0
	for _, line in ipairs(lines) do
		if line:match("^local%s+function%s+[%a_][%w_]*%s*%(") then
			fnCount = fnCount + 1
		end
	end
	-- Only act when the file has >= 30 closures AND 180+ module-level locals
	-- (the actual Luau limit threat).
	if fnCount < 30 then return lines end
	local moduleLocalCount = 0
	for _, line in ipairs(lines) do
		if line:match("^local%s") then moduleLocalCount = moduleLocalCount + 1 end
	end
	if moduleLocalCount < 180 then return lines end

	-- Find candidate closures: top-level `local function NAME(...)`. Tableify
	-- works for ANY local function (not just `anonN`), as long as we update
	-- all references consistently.
	local candidates = {}
	local n = #lines
	local i = 1
	while i <= n do
		local nm = lines[i]:match("^local%s+function%s+([%a_][%w_]*)%s*%(")
		if nm then
			-- Find matching end at zero indent.
			local k = i + 1
			while k <= n do
				local kInd = lines[k]:match("^(%s*)") or ""
				local kTxt = lines[k]:match("^%s*(.-)%s*$") or ""
				if kInd == "" and kTxt == "end" then break end
				k = k + 1
			end
			if k <= n then
				candidates[#candidates + 1] = { name = nm, startIdx = i, endIdx = k }
				i = k + 1
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	if #candidates < 25 then return lines end

	-- For each candidate, compute its index in the new table.
	local nameToIdx = {}
	for idx, cand in ipairs(candidates) do
		nameToIdx[cand.name] = idx
	end

	-- Build the output:
	-- 1. Insert `local _anon = {}` at the start (before first candidate).
	-- 2. Replace each `local function NAME(args) BODY end` with
	--    `_anon[N] = function(args) BODY end`.
	-- 3. Replace all references to NAME with `_anon[N]`.
	local out = {}
	-- Track which lines are part of a candidate body (skip rewriting refs in body
	-- to avoid replacing the function's name in its own definition).
	local lineInCandidate = {}
	for _, cand in ipairs(candidates) do
		for k = cand.startIdx, cand.endIdx do
			lineInCandidate[k] = cand.name
		end
	end
	-- Emit `local _anon = {}` right before the first candidate's startIdx.
	local firstStart = candidates[1].startIdx
	-- Walk lines.
	local idx = 1
	local emittedTable = false
	while idx <= n do
		-- Check if this line begins a candidate.
		local cand = nil
		for _, c in ipairs(candidates) do
			if c.startIdx == idx then cand = c; break end
		end
		if cand then
			if not emittedTable then
				out[#out + 1] = "local _anon = {}"
				emittedTable = true
			end
			-- Rewrite header: `local function NAME(args) ...` →
			--                 `_anon[N] = function(args) ...`
			local header = lines[idx]
			local argPart, trailPart = header:match("^local%s+function%s+[%a_][%w_]*%s*(%b())(.*)$")
			if argPart then
				out[#out + 1] = "_anon[" .. nameToIdx[cand.name] .. "] = function" .. argPart .. trailPart
			else
				out[#out + 1] = header
			end
			-- Body lines: rewrite NAME refs (including recursive self-refs)
			for k = idx + 1, cand.endIdx do
				local body = lines[k]
				for nm, j in pairs(nameToIdx) do
					body = body:gsub("%f[%w_]" .. nm .. "%f[^%w_]", "_anon[" .. j .. "]")
				end
				out[#out + 1] = body
			end
			idx = cand.endIdx + 1
		else
			-- Non-candidate line: rewrite NAME refs to _anon[N].
			local line = lines[idx]
			for nm, j in pairs(nameToIdx) do
				line = line:gsub("%f[%w_]" .. nm .. "%f[^%w_]", "_anon[" .. j .. "]")
			end
			out[#out + 1] = line
			idx = idx + 1
		end
	end
	return out
end

-- When a file has many top-level `local` declarations, Lua/Luau hits the
-- 200-locals-per-scope register limit. Wrap groups of contiguous
-- `local function NAME(...) ... end` declarations + their immediate
-- references in `do...end` blocks. Conservative: only wraps when
-- declarations cluster in a tight contiguous group with no external refs.
local function chunkifyTopLevelLocalFunctions(lines)
	local moduleLocalCount = 0
	for _, line in ipairs(lines) do
		if line:match("^local%s") then moduleLocalCount = moduleLocalCount + 1 end
	end
	if moduleLocalCount < 180 then return lines end
	local out = {}
	local n = #lines
	local i = 1
	while i <= n do
		local fnName = lines[i]:match("^local%s+function%s+([%a_][%w_]*)%s*%(")
		if not fnName then
			out[#out + 1] = lines[i]
			i = i + 1
		else
			-- Collect a group: contiguous `local function NAME ... end` decls
			-- + interspersed simple top-level statements that ONLY reference
			-- names declared in this group.
			local groupStart = i
			local declared = {}
			local j = i
			while j <= n do
				local nm = lines[j]:match("^local%s+function%s+([%a_][%w_]*)%s*%(")
				if nm then
					-- Find matching `end` at zero indent.
					local k = j + 1
					while k <= n do
						local ind = lines[k]:match("^(%s*)") or ""
						local tx = lines[k]:match("^%s*(.-)%s*$") or ""
						if ind == "" and tx == "end" then break end
						k = k + 1
					end
					if k > n then break end
					declared[nm] = true
					j = k + 1
				else
					local tx = lines[j]:match("^%s*(.-)%s*$") or ""
					local ind = lines[j]:match("^(%s*)") or ""
					if ind ~= "" then break end
					if tx == "" then j = j + 1
					elseif tx:match("^local%s") or tx:match("^function%s") then break
					else
						-- Allow if line references a declared name (and only those).
						local refs = false
						for nm0 in pairs(declared) do
							if lines[j]:find("%f[%w_]" .. nm0 .. "%f[^%w_]") then
								refs = true
								break
							end
						end
						if refs then j = j + 1 else break end
					end
				end
			end
			local groupEnd = j - 1
			-- Verify no external references to declared names.
			local safe = next(declared) ~= nil
			if safe then
				for nm0 in pairs(declared) do
					local pat = "%f[%w_]" .. nm0 .. "%f[^%w_]"
					for k = 1, groupStart - 1 do
						if lines[k]:find(pat) then safe = false; break end
					end
					if not safe then break end
					for k = groupEnd + 1, n do
						if lines[k]:find(pat) then safe = false; break end
					end
					if not safe then break end
				end
			end
			-- Count declared names; skip wrap if too few.
			local declCount = 0
			for _ in pairs(declared) do declCount = declCount + 1 end
			if safe and declCount >= 2 then
				out[#out + 1] = "do"
				for k = groupStart, groupEnd do
					out[#out + 1] = "\t" .. lines[k]
				end
				out[#out + 1] = "end"
				i = groupEnd + 1
			else
				out[#out + 1] = lines[i]
				i = i + 1
			end
		end
	end
	return out
end

-- Drop `local _closure_proto_N_ = anonN` aliases when both are at module
-- level. The alias adds a local variable that consumes a slot toward the
-- 200-local limit but provides no value over using `anonN` directly.
-- Replace all references to `_closure_proto_N_` with `anonN` and drop the
-- alias declaration line.
local function dropClosureProtoAliases(lines)
	local aliases = {}
	for _, line in ipairs(lines) do
		local alias, target = line:match("^local%s+(_closure_proto_%d+_)%s*=%s*(anon%d+)%s*$")
		if alias and target then
			aliases[alias] = target
		end
	end
	if next(aliases) == nil then return lines end
	local out = {}
	for _, line in ipairs(lines) do
		local aliasName = line:match("^local%s+(_closure_proto_%d+_)%s*=%s*anon%d+%s*$")
		if aliasName and aliases[aliasName] then
			-- skip
		else
			local rewritten = line
			for a, t in pairs(aliases) do
				rewritten = rewritten:gsub("%f[%w_]" .. a .. "%f[^%w_]", t)
			end
			out[#out + 1] = rewritten
		end
	end
	return out
end

-- Drop dangling `local NAME = <closure proto[N]>` predeclarations when an
-- actual `local function NAME(...)` body follows. These come from recursive
-- closures where the upvalue list contains the closure's own name; the
-- renderer emits a placeholder predeclare AND the body, but the placeholder
-- is never substituted and would be a syntax error in Luau.
-- Also rewrite any remaining bare `<closure proto[N]>` placeholders to `nil`
-- so the output stays compilable.
local function dropClosureProtoPlaceholders(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local cur = lines[i]
		local ind, name = cur:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*<closure%s+proto%[%d+%]>%s*$")
		if ind and name then
			-- Look ahead for a body `local function NAME(...)` or `function _index.NAME(...)`.
			local found = false
			local limit = math.min(#lines, i + 12)
			for j = i + 1, limit do
				if lines[j]:match("^%s*local%s+function%s+" .. name .. "%s*%(")
					or lines[j]:match("^%s*function%s+[%a_][%w_%.:]*%." .. name .. "%s*%(") then
					found = true
					break
				end
				-- Allow intervening forward decls or simple locals.
				local nxt = lines[j]:match("^%s*(.-)%s*$") or ""
				if nxt ~= "" and not nxt:match("^local%s+[%a_][%w_,%s]*$")
					and not nxt:match("^local%s+[%a_][%w_]*%s*=") then
					break
				end
			end
			if found then
				-- Drop this line; the function body declaration will follow.
				i = i + 1
			else
				-- No matching body found: replace placeholder with nil so the
				-- output remains compilable.
				out[#out + 1] = ind .. "local " .. name .. " = nil"
				i = i + 1
			end
		else
			if cur:find("<closure%s+proto%[", 1) then
				out[#out + 1] = (cur:gsub("<closure%s+proto%[[%d?]+%]>", "nil"))
				i = i + 1
			else
				out[#out + 1] = cur
				i = i + 1
			end
		end
	end
	return out
end

-- Drop dead `local NAME = X.FIELD` (or `local NAME = X[K]`) lines whose NAME
-- is never read in the enclosing function scope. Such lines are dangerous
-- because they nil-index `X` if `X` is nil at runtime, even though their
-- result is unused. Common pattern: register-tracking artifacts emit a
-- guarded GETTABLEKS as an unconditional local declaration.
local function dropDeadFieldAccessLocals(lines)
	-- Compute function ranges (same logic as dropDeadNilLocals).
	local fnRanges = {}
	do
		local stack = {}
		for i, line in ipairs(lines) do
			local indent = line:match("^(%s*)") or ""
			local text = line:match("^%s*(.-)%s*$") or ""
			if text:match("^function%s") or text:match("^local%s+function%s")
				or text:match("=%s*function%s*%(") then
				if not text:match("end%s*$") then
					stack[#stack + 1] = { startIdx = i, ind = indent .. "\t" }
				end
			elseif text == "end" then
				if #stack > 0 and #indent == #stack[#stack].ind - 1 then
					local top = table.remove(stack)
					fnRanges[#fnRanges + 1] = { startIdx = top.startIdx, endIdx = i, ind = top.ind }
				end
			end
		end
	end
	fnRanges[#fnRanges + 1] = { startIdx = 1, endIdx = #lines, ind = "" }
	local function rangeFor(idx)
		local best = nil
		for _, r in ipairs(fnRanges) do
			if r.startIdx <= idx and idx <= r.endIdx then
				if (not best) or (r.startIdx > best.startIdx) then best = r end
			end
		end
		return best
	end
	-- Match: `local NAME = X.field` or `local NAME = X.field.deeper`. NAME is a
	-- single identifier, RHS is pure field/index chain (no calls, no methods).
	local function isSimpleFieldChain(rhs)
		rhs = rhs:match("^%s*(.-)%s*$") or ""
		if rhs:match("^[%a_][%w_]*%.[%a_][%w_%.]*$") then return true end
		return false
	end
	local toDrop = {}
	-- Helper: count actual identifier references in a line, excluding contexts
	-- where the token appears as a field key/access rather than a variable use:
	--   `.NAME`, `:NAME`, `NAME = X` inside `{ ... }` table constructor.
	-- We use a simple state machine that tokenizes outside string literals.
	local function lineUsesIdent(line, name)
		local i, n = 1, #line
		local inStr = nil
		local braceDepth = 0
		while i <= n do
			local c = line:sub(i, i)
			if inStr then
				if c == "\\" and i + 1 <= n then
					i = i + 2
				elseif c == inStr then
					inStr = nil
					i = i + 1
				else
					i = i + 1
				end
			elseif c == '"' or c == "'" then
				inStr = c
				i = i + 1
			elseif c == "-" and line:sub(i + 1, i + 1) == "-" then
				return false  -- comment, stop scanning
			elseif c == "{" then
				braceDepth = braceDepth + 1
				i = i + 1
			elseif c == "}" then
				braceDepth = math.max(0, braceDepth - 1)
				i = i + 1
			elseif c:match("[%a_]") then
				local j = i
				while j <= n and line:sub(j, j):match("[%w_]") do j = j + 1 end
				local tok = line:sub(i, j - 1)
				if tok == name then
					-- Check preceding non-space char.
					local k = i - 1
					while k >= 1 and line:sub(k, k):match("%s") do k = k - 1 end
					local prevCh = k >= 1 and line:sub(k, k) or ""
					-- Skip field/method access: `.NAME` or `:NAME`.
					if prevCh ~= "." and prevCh ~= ":" then
						-- Inside a table constructor, `NAME = X` is a field key,
						-- not a variable use. Detect: after the token there's an
						-- `=` (not `==`).
						if braceDepth > 0 then
							local m = j
							while m <= n and line:sub(m, m):match("%s") do m = m + 1 end
							if line:sub(m, m) == "=" and line:sub(m + 1, m + 1) ~= "=" then
								-- field key, skip
							else
								return true
							end
						else
							return true
						end
					end
				end
				i = j
			else
				i = i + 1
			end
		end
		return false
	end
	for i, line in ipairs(lines) do
		local nm, rhs = line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*(.+)$")
		if nm and rhs and isSimpleFieldChain(rhs) then
			local rng = rangeFor(i)
			if rng then
				local found = false
				for j = rng.startIdx, rng.endIdx do
					if j ~= i and lineUsesIdent(lines[j], nm) then
						found = true
						break
					end
				end
				if not found then toDrop[i] = true end
			end
		end
	end
	if next(toDrop) == nil then return lines end
	local out = {}
	for i, line in ipairs(lines) do
		if not toDrop[i] then out[#out + 1] = line end
	end
	return out
end

local function dropDuplicateConsecutiveAssignments(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		out[#out + 1] = lines[i]
		if i + 1 <= #lines then
			local ind1, name1, rhs1 = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)$")
			local ind2, name2, rhs2 = lines[i + 1]:match("^(%s*)([%a_][%w_]*)%s*=%s*(.+)$")
			if ind1 and name1 and ind2 and name2 and rhs1 and rhs2
				and ind1 == ind2 and name1 == name2 and rhs1 == rhs2
				and not lines[i + 1]:match("^%s*local%s")
			then
				-- Skip the duplicate
				i = i + 2
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	return out
end

-- Drop consecutive identical "side-effect" statements that the bytecode
-- never actually executed twice. These appear when a register-based phi
-- analysis emits the same call/return statement at the merge point of
-- multiple control-flow predecessors, all of which deterministically end
-- with the same instruction. Bytecode like:
--   if cond then return f1 end
--   if cond then return f1 end          <- duplicate, never reached
--   f1 = ...
--   return f1
-- The second `if cond then return f1 end` is unreachable (cond unchanged).
-- Similarly `libraryNew_6(r39); libraryNew_6(r39); libraryNew_6(r39)` (call x3)
-- when only one CALL appears in the bytecode.
--
-- Conservative heuristics:
--   - Both lines must be byte-for-byte identical (including indent).
--   - Statement must be one of:
--     * `if X then return [expr] end`
--     * `return [expr]`
--     * `<callable>(...)`        (top-level expression statement, no LHS)
--     * `<callable>(...).foo = X` excluded
--   - Do NOT collapse assignments (those have legitimate sequential effects).
--   - Do NOT collapse `continue`, `break`, `end`, comment, or empty lines.
local function dropDuplicateConsecutiveStatements(lines)
	local function classify(line)
		local trimmed = line:match("^%s*(.-)%s*$") or ""
		if trimmed == "" then return nil end
		if trimmed:sub(1, 2) == "--" then return nil end
		if trimmed == "end" or trimmed == "else" or trimmed == "do"
			or trimmed == "continue" or trimmed == "break"
			or trimmed == "}" or trimmed == "})" or trimmed == "end)"
			or trimmed == "end))" or trimmed == "end))," or trimmed == "{"
		then
			return nil
		end
		-- Local declarations and assignments: don't dedupe.
		if trimmed:match("^local%s") then return nil end
		-- Pure assignment (LHS = RHS, where LHS is plain identifier-like form
		-- and not a call). Don't dedupe (multiple identical assignments may be
		-- legitimate stores in source).
		if trimmed:match("^[%w_%.%[%]\"']+%s*=") and not trimmed:match("^[%w_%.%[%]\"']+%s*=.*[%(:]") then
			return nil
		end
		-- `if X then return [expr] end` (single-line guarded return).
		if trimmed:match("^if%s.+%sthen%s+return[%s%(].-%send$")
			or trimmed:match("^if%s.+%sthen%s+return%s+end$")
		then
			return "guarded_return"
		end
		-- Bare `return [expr]`.
		if trimmed:match("^return%s") or trimmed == "return" then
			return "return"
		end
		-- Side-effect call statement: starts with identifier or `self`/`game`
		-- followed by ( or :method(...). Must end in `)` (or `)` with trailing
		-- comma indicating multi-line, but we exclude those).
		-- Don't match table constructor lines / multi-line opener.
		if trimmed:match("^[%a_][%w_%.:]*%s*%(.-%)%s*$")
			or trimmed:match("^[%a_][%w_%.:]*%s*%b()%s*$")
		then
			-- Exclude `if`/`for`/`while`/`do`/`function` openers (they don't match
			-- the pattern above anyway, but be safe).
			if not trimmed:match("^[a-z]+%s") then
				return "call"
			end
		end
		return nil
	end
	local out = {}
	local i = 1
	while i <= #lines do
		out[#out + 1] = lines[i]
		local kind = classify(lines[i])
		if kind then
			while i + 1 <= #lines and lines[i + 1] == lines[i] do
				-- Skip duplicate adjacent line.
				i = i + 1
			end
		end
		i = i + 1
	end
	return out
end

local function dropUnusedGetAttributesLocals(lines)
	local out = {}
	for i, line in ipairs(lines) do
		local ind, name = line:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*.+:GetAttributes%(%s*%)%s*$")
		local drop = false
		if ind and name then
			local usePat = "%f[%a_]" .. luaPE(name) .. "%f[^%a_%d]"
			local indentLen = #ind
			local used = false
			for j = i + 1, #lines do
				local text = lines[j]:match("^%s*(.-)%s*$")
				local curInd = lines[j]:match("^(%s*)") or ""
				if #curInd < indentLen then
					break
				end
				if #curInd == indentLen and (text == "end" or text == "else" or text:match("^elseif%s+") or text:match("^until%s+")) then
					break
				end
				if lines[j]:find(usePat) then
					used = true
					break
				end
			end
			drop = not used
		end
		if not drop then
			out[#out+1] = line
		end
	end
	return out
end

local function recoverEmptyFieldGuards(lines)
	local remove = {}
	local replace = {}
	local function trim(s)
		return s:match("^%s*(.-)%s*$")
	end
	local function matchBaseIf(ln)
		local ind = ln:match("^(%s*)") or ""
		local text = trim(ln)
		local base = text:match("^if%s+([%a_][%w_]*)%s+then$")
		if not base then base = text:match("^if%s+%(([%a_][%w_]*)%)%s+then$") end
		if base then return ind, base end
		return nil, nil
	end
	local function matchFieldIf(ln)
		local ind = ln:match("^(%s*)") or ""
		local text = trim(ln)
		local field = text:match("^if%s+([%a_][%w_]*(%.[%a_][%w_]*)+)%s+then$")
		if not field then field = text:match("^if%s+%(([%a_][%w_]*(%.[%a_][%w_]*)+)%)%s+then$") end
		if field then return ind, field end
		return nil, nil
	end
	local function matchGuardInline(ln)
		local ind = ln:match("^(%s*)") or ""
		local text = trim(ln)
		local field, _, ret = text:match("^if%s+not%s+([%a_][%w_]*(%.[%a_][%w_]*)+)%s+then%s+return(.-)%s+end$")
		if not field then field, _, ret = text:match("^if%s+not%s+%(([%a_][%w_]*(%.[%a_][%w_]*)+)%)%s+then%s+return(.-)%s+end$") end
		if field then return ind, field, ret or "" end
		return nil, nil, nil
	end
	local function matchGuardOpen(ln)
		local ind = ln:match("^(%s*)") or ""
		local text = trim(ln)
		local field = text:match("^if%s+not%s+([%a_][%w_]*(%.[%a_][%w_]*)+)%s+then$")
		if not field then field = text:match("^if%s+not%s+%(([%a_][%w_]*(%.[%a_][%w_]*)+)%)%s+then$") end
		if field then return ind, field end
		return nil, nil
	end
	for i, line in ipairs(lines) do
		local guardIndent, fieldExpr, retSuffix = matchGuardInline(line)
		local guardEnd = i
		if not guardIndent then
			local gi, gf = matchGuardOpen(line)
			if gi and i + 2 <= #lines then
				local ret = trim(lines[i + 1]):match("^return(.*)$")
				local endInd = matchEnd(lines[i + 2])
				if ret and endInd == gi then
					guardIndent, fieldExpr, retSuffix = gi, gf, ret
					guardEnd = i + 2
				end
			end
		end
		if guardIndent and fieldExpr then
			local base = fieldExpr:match("^([%a_][%w_]*)%.")
			local emptyStart, emptyEnd = nil, nil
			for k = math.max(1, i - 24), i - 1 do
				local baseInd, baseName = matchBaseIf(lines[k])
				if baseName == base and k + 3 < i then
					local _, fieldName = matchFieldIf(lines[k + 1])
					if fieldName == fieldExpr then
						local end2 = matchEnd(lines[k + 2])
						local end3 = matchEnd(lines[k + 3])
						if end2 and end3 == baseInd then
							emptyStart, emptyEnd = k, k + 3
							break
						end
						local elseInd = lines[k + 2]:match("^(%s*)else%s*$")
						local end4 = k + 4 < i and matchEnd(lines[k + 4]) or nil
						if elseInd and end3 and end4 == baseInd then
							emptyStart, emptyEnd = k, k + 4
							break
						end
					end
				end
			end
			if emptyStart and emptyEnd then
				local clear = true
				for mid = emptyEnd + 1, i - 1 do
					if trim(lines[mid]) ~= "" and not matchEnd(lines[mid]) then clear = false break end
				end
				if clear then
					for idx = emptyStart, emptyEnd do remove[idx] = true end
					replace[i] = {
						endIdx = guardEnd,
						lines = {
							guardIndent .. "if not " .. base .. " then return" .. retSuffix .. " end",
							guardIndent .. "if not " .. fieldExpr .. " then return" .. retSuffix .. " end",
						},
					}
				end
			end
		end
	end
	local out = {}
	local i = 1
	while i <= #lines do
		if replace[i] then
			for _, ln in ipairs(replace[i].lines) do out[#out+1] = ln end
			i = replace[i].endIdx + 1
		else
			if not remove[i] then out[#out+1] = lines[i] end
			i = i + 1
		end
	end
	return out
end

-- When the renderer drops a guarded `IsA`/inline-call check, the surviving
-- two-jump chain can be collapsed into `if NAME then warn(...); return end`
-- where the `then` branch is supposed to be the FAILURE branch.  The clear
-- signal of this bug is that code after the `end` reads `NAME` (via field or
-- method) while a successful entry into the `then` branch always returns 鈥?
-- so the post-`end` use is unreachable unless the condition is inverted.
local function fixInvertedFalseyGuard(lines)
	local function isFieldUse(line, name)
		-- Find `NAME.` or `NAME:` not preceded by an identifier character.
		local i = 1
		local n = #line
		while i <= n do
			local s, e = line:find(name, i, true)
			if not s then break end
			local prev = s > 1 and line:sub(s - 1, s - 1) or ""
			local nxt = e + 1 <= n and line:sub(e + 1, e + 1) or ""
			if not prev:match("[%w_]") and (nxt == "." or nxt == ":") then
				return true
			end
			i = e + 1
		end
		return false
	end
	local out = {}
	local i = 1
	while i <= #lines do
		-- Match SIMPLE IDENTIFIER guard ONLY: `if NAME then`
		-- (NOT field access like `if X.field then` 鈥?that would be too aggressive
		-- because using `X.other_field` after the guard is normal, not an inversion signal.)
		local ind, condExpr = lines[i]:match("^(%s*)if%s+([%a_][%w_]*)%s+then%s*$")
		if not ind then
			-- Try with parens: `if (NAME) then`
			ind, condExpr = lines[i]:match("^(%s*)if%s+%(([%a_][%w_]*)%)%s+then%s*$")
		end
		local name = condExpr
		if ind and name and condExpr then
			-- Locate the matching `end` at the same indent.
			local endIdx = nil
			for j = i + 1, math.min(#lines, i + 12) do
				local jInd = lines[j]:match("^(%s*)end%s*$")
				if jInd == ind then endIdx = j; break end
				local sameIndentNonEnd = lines[j]:match("^(" .. luaPE(ind) .. ")[^%s]") and not lines[j]:match("^" .. luaPE(ind) .. "end")
				if sameIndentNonEnd and j ~= i then break end
			end
			if endIdx then
				-- Body must end with a `return`, `continue`, or `break` statement
				-- (so the `then` branch never falls through).
				local hasExit = false
				for j = i + 1, endIdx - 1 do
					local t = lines[j]:match("^%s*(.-)%s*$")
					if t == "return" or t:sub(1, 7) == "return " or t == "continue" or t == "break" then
						hasExit = true; break
					end
				end
				-- Subsequent line at the same indent (or deeper) must read NAME
				-- as a field/method receiver.
				local usesAfter = false
				if hasExit then
					for j = endIdx + 1, math.min(#lines, endIdx + 6) do
						local tInd = lines[j]:match("^(%s*)") or ""
						if #tInd < #ind then break end
						if isFieldUse(lines[j], name) then usesAfter = true; break end
						-- Only look until first non-empty statement at >= ind.
						if lines[j]:match("%S") and #tInd <= #ind then break end
					end
				end
				if hasExit and usesAfter then
					out[#out+1] = ind .. "if not " .. condExpr .. " then"
					for j = i + 1, endIdx do out[#out+1] = lines[j] end
					i = endIdx + 1
				else
					out[#out+1] = lines[i]; i = i + 1
				end
			else
				out[#out+1] = lines[i]; i = i + 1
			end
		else
			out[#out+1] = lines[i]; i = i + 1
		end
	end
	-- Pass 1b: fix `if EXPR then CALL() end; if not (EXPR) then return end`
	-- The first if should be `if not EXPR then` (it's a "try to fix nil" pattern).
	local out1b = {}
	local j1b = 1
	while j1b <= #out do
		local pInd, pExpr = out[j1b]:match("^(%s*)if%s+([%a_][%w_.]*[%w_])%s+then%s*$")
		if pInd and pExpr and j1b + 2 <= #out then
			local bodyLine = out[j1b + 1]
			local endLine = out[j1b + 2]
			local endInd = endLine and endLine:match("^(%s*)end%s*$")
			local nextIf = j1b + 3 <= #out and out[j1b + 3] or nil
			-- Body must be a single function call (indented). Specifically:
			-- a method/function call statement, NOT an assignment. The pattern
			-- this pass targets is `if X then X:cleanup() end; if not X then return end`
			-- where the cleanup is purely side-effecting. If the body REASSIGNS
			-- the guard variable (e.g. `if X then X = X.Field end`), the first
			-- branch is doing field-extraction and inversion would corrupt
			-- semantics (X would only be reassigned when nil — invalid).
			local bodyTrim = bodyLine and bodyLine:match("^%s*(.-)%s*$") or ""
			local isSingleCall = bodyLine
				and bodyLine:match("^" .. luaPE(pInd) .. "\t")
				and not bodyLine:match("^%s*if%s")
				and not bodyLine:match("^%s*local%s")
				-- Reject assignments to the guard variable itself.
				and not bodyTrim:match("^" .. luaPE(pExpr) .. "%s*=")
				-- Reject any assignment statement (LHS = RHS without `:`/`.` before `=`).
				-- Match "expression = ..." where expression isn't a method call.
				and not (bodyTrim:match("^[%a_][%w_%.]*%s*=") and not bodyTrim:match("[:%.][%a_][%w_]*%s*%("))
			-- Next line must be `if not (EXPR) then` or `if not EXPR then`
			local negGuard = nextIf and (
				nextIf:match("^" .. luaPE(pInd) .. "if%s+not%s+%(" .. luaPE(pExpr) .. "%)%s+then")
				or nextIf:match("^" .. luaPE(pInd) .. "if%s+not%s+" .. luaPE(pExpr) .. "%s+then")
			)
			if endInd == pInd and isSingleCall and negGuard then
				out1b[#out1b+1] = pInd .. "if not " .. pExpr .. " then"
				out1b[#out1b+1] = bodyLine
				out1b[#out1b+1] = endLine
				j1b = j1b + 3
			else
				out1b[#out1b+1] = out[j1b]; j1b = j1b + 1
			end
		else
			out1b[#out1b+1] = out[j1b]; j1b = j1b + 1
		end
	end
	-- Pass 1c: fix `if not X.field then return end; X.field = value` to
	-- `if X.field then return end; X.field = value`.
	-- This appears when the bytecode does `if X.field then goto exit end; X.field = true`.
	-- The reversed guard means "if already in this state, exit" not "if not yet in this state, exit".
	local out1c = {}
	local jc = 1
	while jc <= #out1b do
		local cInd, cExpr = out1b[jc]:match("^(%s*)if%s+not%s+([%a_][%w_.]*[%w_])%s+then%s+return%s+end%s*$")
		if not cInd then
			cInd, cExpr = out1b[jc]:match("^(%s*)if%s+not%s+%(([%a_][%w_.]*[%w_])%)%s+then%s+return%s+end%s*$")
		end
		-- Also handle multi-line: if not X.field then\n\treturn\nend
		local multiLine = false
		if not cInd and jc + 2 <= #out1b then
			cInd, cExpr = out1b[jc]:match("^(%s*)if%s+not%s+([%a_][%w_.]*[%w_])%s+then%s*$")
			if not cInd then
				cInd, cExpr = out1b[jc]:match("^(%s*)if%s+not%s+%(([%a_][%w_.]*[%w_])%)%s+then%s*$")
			end
			if cInd and cExpr then
				local ret = out1b[jc + 1]:match("^%s*(return)%s*$")
				local en = out1b[jc + 2]:match("^(%s*)end%s*$")
				if ret and en == cInd then
					multiLine = true
				else
					cInd, cExpr = nil, nil
				end
			end
		end
		if cInd and cExpr and cExpr:find(".", 1, true) then
			-- Extract base var (e.g. "v1_e" from "v1_e.IsDying")
			local baseVar = cExpr:match("^([%a_][%w_]*)%.")
			-- Look ahead for `X.SAME_FIELD = value` (highest priority 鈥?same field assignment indicates state-transition pattern)
			local skipLines = multiLine and 3 or 1
			local nextIdx = jc + skipLines
			while nextIdx <= #out1b and not out1b[nextIdx]:match("%S") do nextIdx = nextIdx + 1 end
			local shouldReverse = false
			if nextIdx <= #out1b then
				-- Strong signal A: same field assigned right after (e.g. v1_e.IsDying = true)
				-- BUT only if the assigned value is TRUTHY (true / non-false / non-nil).
				-- Pattern `if not X.field then return end ... X.field = false` is a legitimate
				-- "cleanup-when-set" pattern (e.g. StopConeSound: only stop if currently playing).
				local sameFieldPat = "^" .. luaPE(cInd) .. luaPE(cExpr) .. "%s*=%s*"
				local immediateAssignVal = out1b[nextIdx]:match(sameFieldPat .. "(.+)$")
				if immediateAssignVal then
					local valTrim = immediateAssignVal:match("^%s*(.-)%s*$")
					-- Only reverse when assigned value is "true" or anything non-falsy.
					-- Reverse when value is `true` literal 鈥?explicit state-set.
					-- Don't reverse when value is `false` or `nil` (cleanup pattern).
					if valTrim == "true" or (valTrim ~= "false" and valTrim ~= "nil" and not valTrim:match("^false%s")) then
						shouldReverse = true
					end
				elseif baseVar then
					-- Strong signal B: somewhere in the next ~12 lines at same indent,
					-- the SAME field is assigned a boolean literal.  Reverse only when
					-- the assigned value is `true` (set-state pattern), not `false`
					-- (clear-state / cleanup pattern, where the early-return is correct).
					local readsField = false
					local foundTrueAssign = false
					local foundFalseAssign = false
					for sc = nextIdx, math.min(#out1b, nextIdx + 12) do
						local scInd = out1b[sc]:match("^(%s*)") or ""
						-- Check if this line reads cExpr (not assign)
						if not out1b[sc]:match(sameFieldPat) then
							if out1b[sc]:find(luaPE(cExpr), 1, true) then
								readsField = true; break
							end
						end
						if scInd == cInd and out1b[sc]:match("^" .. luaPE(cInd) .. luaPE(cExpr) .. "%s*=%s*true%s*$") then
							foundTrueAssign = true
						elseif scInd == cInd and out1b[sc]:match("^" .. luaPE(cInd) .. luaPE(cExpr) .. "%s*=%s*false%s*$") then
							foundFalseAssign = true
						end
					end
					if foundTrueAssign and not foundFalseAssign and not readsField then shouldReverse = true end
				end
			end
			if shouldReverse then
				if multiLine then
					out1c[#out1c+1] = cInd .. "if " .. cExpr .. " then"
					out1c[#out1c+1] = out1b[jc + 1]
					out1c[#out1c+1] = out1b[jc + 2]
					jc = jc + 3
				else
					out1c[#out1c+1] = cInd .. "if " .. cExpr .. " then return end"
					jc = jc + 1
				end
			else
				out1c[#out1c+1] = out1b[jc]; jc = jc + 1
			end
		else
			out1c[#out1c+1] = out1b[jc]; jc = jc + 1
		end
	end
	-- Second pass: remove dead code after guard blocks that always return.
	-- Pattern: if NAME then ... return ... end; DEAD_LINE (dead)
	-- DEAD_LINE references guard var or a var only assigned inside the guard.
	local out2 = {}
	local j = 1
	while j <= #out1c do
		local gInd, gName = out1c[j]:match("^(%s*)if%s+([%a_][%w_]*)%s+then%s*$")
		if not gInd then
			out2[#out2+1] = out1c[j]; j = j + 1
		else
			local gEnd = nil
			local gHasReturn = false
			local gDepth = 0
			local innerAssigned = {}
			for k = j + 1, math.min(#out1c, j + 30) do
				local kText = out1c[k]:match("^%s*(.-)%s*$")
				local kInd = out1c[k]:match("^(%s*)") or ""
				if kInd == gInd and kText == "end" and gDepth == 0 then
					gEnd = k; break
				end
				if kInd == gInd and (kText:match("^if%s") or kText:match("^for%s") or kText:match("^while%s") or kText == "repeat") then
					gDepth = gDepth + 1
				elseif kInd == gInd and kText == "end" and gDepth > 0 then
					gDepth = gDepth - 1
				end
				if kText == "return" or kText:match("^return%s") then
					gHasReturn = true
				end
				-- Collect variables assigned inside the guard block
				local assignedVar = out1c[k]:match("^%s*([%a_][%w_]*)%s*=")
				if assignedVar and assignedVar ~= "local" then
					innerAssigned[assignedVar] = true
				end
			end
			if gEnd and gHasReturn then
				local nxt = gEnd + 1
				while nxt <= #out1c and not out1c[nxt]:match("%S") do nxt = nxt + 1 end
				local deadLine = false
				if nxt <= #out1c then
					local nInd = out1c[nxt]:match("^(%s*)") or ""
					if nInd == gInd then
						-- Check if dead line references guard var or any inner-assigned var
						local checkNames = {gName}
						for vn in pairs(innerAssigned) do checkNames[#checkNames+1] = vn end
						for _, chkName in ipairs(checkNames) do
							if deadLine then break end
							local ni = 1
							local nLen = #out1c[nxt]
							while ni <= nLen do
								local s, e2 = out1c[nxt]:find(chkName, ni, true)
								if not s then break end
								local prev = s > 1 and out1c[nxt]:sub(s-1,s-1) or ""
								local nx = e2+1 <= nLen and out1c[nxt]:sub(e2+1,e2+1) or ""
								if not prev:match("[%w_]") and (nx == "." or nx == ":" or nx == "[") then
									deadLine = true; break
								end
								ni = e2 + 1
							end
						end
					end
				end
				if deadLine then
					for k = j, gEnd do out2[#out2+1] = out1c[k] end
					j = nxt + 1
				else
					out2[#out2+1] = out1c[j]; j = j + 1
				end
			else
				out2[#out2+1] = out1c[j]; j = j + 1
			end
		end
	end
	-- Third pass: fix `if (EXPR) then return _rN end` where _rN is undeclared.
	-- This arises when a JUMPIF skips over a NEWTABLE that overwrites the same
	-- register.  The correct return value is EXPR itself.
	local out3 = {}
	for k = 1, #out2 do
		local ln = out2[k]
		local mInd, mExpr, mVar = ln:match("^(%s*)if%s+(%(.+%))%s+then%s+return%s+(_r%d+)%s+end%s*$")
		if mVar then
			-- Check if _rN is declared anywhere before this line
			local declared = false
			for prev = 1, k - 1 do
				if out2[prev]:match("%f[%a_]" .. mVar .. "%f[^%a_%d]") then
					declared = true; break
				end
			end
			if not declared then
				out3[#out3+1] = mInd .. "if " .. mExpr .. " then return " .. mExpr .. " end"
			else
				out3[#out3+1] = ln
			end
		else
			out3[#out3+1] = ln
		end
	end
	-- Fourth pass: remove stale `X = X_result` assignments where X_result is
	-- an undeclared variable (artifact of CALL result register reuse).
	-- Pattern: `VAR = someFunction(...)\n VAR = someFunction_result`
	local out4 = {}
	for k = 1, #out3 do
		local ln = out3[k]
		local assignInd, lhs, rhs = ln:match("^(%s*)([%a_][%w_]*)%s*=%s*([%a_][%w_]*_result%d*)%s*$")
		if assignInd and rhs then
			-- Check if rhs is declared anywhere before this line
			local declared = false
			for prev = 1, k - 1 do
				if out3[prev]:match("%f[%a_]local%s+" .. rhs .. "%f[^%a_%d]")
					or out3[prev]:match("%f[%a_]" .. rhs .. "%s*=")
					or out3[prev]:match(",%s*" .. rhs .. "%f[^%a_%d]")
				then
					declared = true; break
				end
			end
			if not declared then
				-- Skip this dead assignment line
			else
				out4[#out4+1] = ln
			end
		else
			out4[#out4+1] = ln
		end
	end
	return out4
end

-- Fix the `if not X then X = X:METHOD(...) end` (or `X = X.FIELD`) anti-pattern.
-- This is always wrong: when X is nil, `X:METHOD()` would error.  The source
-- must have been `if X then X = X:METHOD() end` (chained-find pattern).
-- Bytecode: JUMPIFNOT R -> skip; R = R:Method(...); ::skip:: 鈥?we mis-lifted
-- the skip-if-not as `if not X then BODY end` instead of `if X then BODY end`.
PASSES.fixSelfReferentialNotGuard = function(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		-- Inline form: `if not X then X = X:M(...) end` or `if not X then X = X.F end`
		local inlInd, inlVar, inlRhs = lines[i]:match("^(%s*)if%s+not%s+([%a_][%w_]*)%s+then%s+([%a_][%w_]*)%s*=%s*(.+)%s+end%s*$")
		if not inlInd then
			inlInd, inlVar, inlRhs = lines[i]:match("^(%s*)if%s+not%s+%(([%a_][%w_]*)%)%s+then%s+([%a_][%w_]*)%s*=%s*(.+)%s+end%s*$")
		end
		if inlInd and inlVar and inlRhs then
			local lhsName, restRhs = lines[i]:match("then%s+([%a_][%w_]*)%s*=%s*(.+)%s+end%s*$")
			if lhsName == inlVar and restRhs and (restRhs:find("^" .. luaPE(inlVar) .. "[:%.]")) then
				out[#out+1] = inlInd .. "if " .. inlVar .. " then " .. lhsName .. " = " .. restRhs .. " end"
				i = i + 1
			else
				out[#out+1] = lines[i]; i = i + 1
			end
		else
			-- Multi-line form:
			-- if not X then
			--     X = X:M(...)
			-- end
			local mlInd, mlVar = lines[i]:match("^(%s*)if%s+not%s+([%a_][%w_]*)%s+then%s*$")
			if not mlInd then
				mlInd, mlVar = lines[i]:match("^(%s*)if%s+not%s+%(([%a_][%w_]*)%)%s+then%s*$")
			end
			if mlInd and mlVar and i + 2 <= #lines then
				local bodyLine = lines[i + 1]
				local endLine = lines[i + 2]
				local endInd = endLine and endLine:match("^(%s*)end%s*$")
				local bLhs, bRhs = bodyLine:match("^%s*([%a_][%w_]*)%s*=%s*(.+)%s*$")
				if endInd == mlInd and bLhs == mlVar and bRhs and bRhs:find("^" .. luaPE(mlVar) .. "[:%.]") then
					out[#out+1] = mlInd .. "if " .. mlVar .. " then"
					out[#out+1] = bodyLine
					out[#out+1] = endLine
					i = i + 3
				else
					out[#out+1] = lines[i]; i = i + 1
				end
			else
				out[#out+1] = lines[i]; i = i + 1
			end
		end
	end
	return out
end

-- Drop dead local declarations: `local X = side_effect_free_expr` where X is never
-- read after this point.  Conservative: only drops when RHS is a side-effect-free
-- pattern (field access chain or simple identifier or short `(... or default)`).
-- Fix CAPTURE REF closures whose captured upvalue isn't assigned in the enclosing
-- scope.  The pattern:
--     local NAME                                   -- forward decl, never assigned
--     for ... do
--         ...
--         local TEMP = ...                          -- TEMP is what should be Animation
--         local function anon() -- upvalues: ..., NAME
--             ... uses NAME ...
--         end
--         pcall(anon, ...)                          -- TEMP is implicit in the call
--     end
-- Fix: rename TEMP -> NAME (and drop the redundant `local` so it assigns the outer NAME).
PASSES.fixCapturedUpvalueLocal = function(lines)
	local out = {}
	for i, line in ipairs(lines) do out[i] = line end
	-- Find function-level `local NAME` (no init) declarations
	-- Then look inside any inner closure body for `upvalues: ..., NAME`.
	-- Heuristic: for each `local function ANON() -- upvalues: ..., NAME`, check
	-- the closure's body for usage of NAME.  Look BEFORE the closure declaration
	-- for `local TEMP = ...` at the same indent (one level deeper than the
	-- forward decl), where TEMP is the most recent unassigned local that the
	-- closure call uses.  Rename TEMP -> NAME and drop the `local`.
	local function fixOne(idx)
		-- Match: `local function NAME() -- upvalues: ..., UPV_NAME`
		local closureLine = out[idx]
		if not closureLine then return end
		local closureInd = closureLine:match("^(%s*)") or ""
		local upvalueList = closureLine:match("%-%-%s*upvalues:%s*(.+)$")
		if not upvalueList then return end
		-- Extract upvalue names
		local upvNames = {}
		for u in upvalueList:gmatch("([%a_][%w_]*)") do upvNames[#upvNames+1] = u end
		if #upvNames == 0 then return end
		-- For each upvalue, check if it has a function-level `local UPV` (no init)
		-- and is NEVER assigned, but is USED inside the closure body.
		for _, upv in ipairs(upvNames) do
			-- Find function-level `local UPV` declaration before idx, at indent
			-- shallower than closureInd.
			local declIdx = nil
			local declInd = nil
			for k = idx - 1, 1, -1 do
				local kInd, kName = out[k]:match("^(%s*)local%s+([%a_][%w_]*)%s*$")
				if kInd and kName == upv and #kInd < #closureInd then
					declIdx = k; declInd = kInd; break
				end
				-- Stop at function boundary
				local fnInd = out[k]:match("^(%s*)") or ""
				if out[k]:match("^%s*function%s") or out[k]:match("^%s*local%s+function%s") then
					if #fnInd < #closureInd then break end
				end
			end
			if declIdx then
				-- Check no assignment to UPV between declIdx and idx (other than at
				-- closureInd or deeper).
				local assigned = false
				for k = declIdx + 1, idx - 1 do
					if out[k]:match("^%s*" .. luaPE(upv) .. "%s*=") then
						assigned = true; break
					end
				end
				if not assigned then
					-- Find the most recent `local TEMP = X` at closureInd before idx
					local tempIdx = nil
					local tempName = nil
					local tempRhs = nil
					for k = idx - 1, math.max(declIdx + 1, idx - 30), -1 do
						local kInd, kName, kRhs = out[k]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
						if kInd == closureInd and kName and kRhs then
							-- Skip if kName is itself a captured upvalue
							local isUpv = false
							for _, u2 in ipairs(upvNames) do if u2 == kName then isUpv = true break end end
							if not isUpv and kName ~= upv then
								tempIdx = k; tempName = kName; tempRhs = kRhs
								break
							end
						end
					end
					if tempIdx and tempName then
						-- Replace `local TEMP = X` with `UPV = X`
						out[tempIdx] = closureInd .. upv .. " = " .. tempRhs
						-- Rename all references to TEMP within the closure's enclosing
						-- block (between tempIdx and the function-end) to UPV.
						local pat = "%f[%a_]" .. luaPE(tempName) .. "%f[^%a_%d]"
						for k = tempIdx + 1, #out do
							local kInd = out[k]:match("^(%s*)") or ""
							-- Stop when we exit the enclosing block (indent < closureInd)
							if out[k]:match("%S") and #kInd < #closureInd then break end
							out[k] = out[k]:gsub(pat, upv)
						end
						return
					end
				end
			end
		end
	end
	for i = 1, #out do
		fixOne(i)
	end
	return out
end

-- Fix forward-decl-from-loop-local where the function body starts with
--   local NAME = TEMP        <- TEMP not yet declared
--   local TEMP                <- forward decl
-- This is a degenerate variant of the captured-upvalue pattern: the
-- semantic-naming layer chose `TEMP` for register R while a child closure
-- captured R by REF and named the upvalue `NAME` (e.g. derived from
-- Instance.new("Animation") -> "Animation"). Both names refer to the same
-- variable; they must be unified.
-- Fix: drop the `local NAME = TEMP` line, drop the `local TEMP` forward decl,
-- insert `local NAME` (no init) at function scope, and rename TEMP -> NAME
-- across the function body.
PASSES.unifyForwardDeclWithCapturedName = function(lines)
	local out = {}
	for i, line in ipairs(lines) do out[i] = line end
	local i = 1
	while i <= #out do
		-- Look for function header (function ... or local function ... or = function( etc.)
		local headerInd = out[i]:match("^(%s*)") or ""
		local headerText = out[i]:match("^%s*(.-)%s*$") or ""
		local isFnHeader = headerText:match("^function%f[^%w_]")
			or headerText:match("^local%s+function%f[^%w_]")
			or headerText:match("=%s*function%(")
			or headerText:match("=%s*function%s+%(")
		if isFnHeader then
			-- Look for the first non-blank line after the header
			local j = i + 1
			while j <= #out and not out[j]:match("%S") do j = j + 1 end
			if j <= #out then
				local jInd, jName, jRhs = out[j]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*$")
				if jInd and jName and jRhs and jName ~= jRhs then
					-- Look for next non-blank
					local k = j + 1
					while k <= #out and not out[k]:match("%S") do k = k + 1 end
					if k <= #out then
						local kInd, kName = out[k]:match("^(%s*)local%s+([%a_][%w_]*)%s*$")
						if kInd and kName == jRhs and kInd == jInd then
							-- Match: `local NAME = TEMP; local TEMP` at function start.
							-- Look for inner closure within the function body that
							-- captures NAME via `-- upvalues:` comment.
							local fnIndPlus = headerInd .. "\t"
							local fnEnd = #out
							for m = j + 1, #out do
								local mInd = out[m]:match("^(%s*)") or ""
								local mText = out[m]:match("^%s*(.-)%s*$") or ""
								if mInd == headerInd and mText == "end" then
									fnEnd = m - 1
									break
								end
							end
							local capturesName = false
							for m = j, fnEnd do
								local upvList = out[m]:match("%-%-%s*upvalues:%s*(.+)$")
								if upvList then
									for u in upvList:gmatch("([%a_][%w_]*)") do
										if u == jName then capturesName = true break end
									end
								end
								if capturesName then break end
							end
							if capturesName then
								-- Apply: drop the `local NAME = TEMP` line (jIdx),
								-- replace `local TEMP` (kIdx) with `local NAME`,
								-- rename TEMP -> NAME everywhere within fn body.
								out[j] = jInd .. "local " .. jName
								out[k] = ""
								local pat = "%f[%a_]" .. luaPE(kName) .. "%f[^%a_%d]"
								for m = j + 1, fnEnd do
									out[m] = out[m]:gsub(pat, jName)
								end
							end
						end
					end
				end
			end
		end
		i = i + 1
	end
	-- Filter out empty lines we created
	local filtered = {}
	for _, ln in ipairs(out) do
		filtered[#filtered+1] = ln
	end
	return filtered
end

-- Inline single-use anonymous function declarations.
-- Pattern:
--     local function anonN(args) ...
--         BODY
--     end
--     SOME_EXPR(... anonN ...)        -- single reference
-- Becomes:
--     SOME_EXPR(... function(args)
--         BODY
--     end ...)
PASSES.inlineSingleUseAnonFunctions = function(lines)
	local out = {}
	for i, line in ipairs(lines) do out[i] = line end
	local explicitlyEmptied = {}
	-- Helper: drop anonymous function declarations with ZERO references.
	-- These come from source code where a closure was created but never called.
	local function tryDropDead(i)
		local fnInd, fnName, fnArgs = out[i]:match("^(%s*)local%s+function%s+([%a_][%w_]*)%s*(%b())")
		if not fnInd or not fnName or not fnArgs then return end
		if not fnName:match("^anon%d+$") then return end
		local fnEnd = nil
		for j = i + 1, #out do
			local jInd = out[j]:match("^(%s*)") or ""
			local jText = out[j]:match("^%s*(.-)%s*$") or ""
			if jInd == fnInd and jText == "end" then
				fnEnd = j
				break
			end
		end
		if not fnEnd then return end
		local pat = "%f[%a_]" .. luaPE(fnName) .. "%f[^%a_%d]"
		for j = 1, #out do
			if j < i or j > fnEnd then
				local lineText = out[j]:match("^%s*(.-)%s*$") or ""
				if lineText:sub(1, 2) ~= "--" and out[j]:find(pat) then
					return  -- has a real reference, keep
				end
			end
		end
		-- Zero refs: drop the whole declaration
		for j = i, fnEnd do
			out[j] = ""
			explicitlyEmptied[j] = true
		end
	end
	local function tryInline(i)
		local fnInd, fnName, fnArgs = out[i]:match("^(%s*)local%s+function%s+([%a_][%w_]*)%s*(%b())")
		if not fnInd or not fnName or not fnArgs then return end
		if not fnName:match("^anon%d+$") then return end
		-- Find matching `end` at same indent
		local fnEnd = nil
		for j = i + 1, #out do
			local jInd = out[j]:match("^(%s*)") or ""
			local jText = out[j]:match("^%s*(.-)%s*$") or ""
			if jInd == fnInd and jText == "end" then
				fnEnd = j
				break
			end
		end
		if not fnEnd then return end
		-- Count references to NAME outside the declaration block
		local refLine = nil
		local refCount = 0
		local pat = "%f[%a_]" .. luaPE(fnName) .. "%f[^%a_%d]"
		for j = 1, #out do
			if j < i or j > fnEnd then
				local lineText = out[j]:match("^%s*(.-)%s*$") or ""
				-- Skip comment-only lines (start with --)
				if lineText:sub(1, 2) ~= "--" then
					if out[j]:find(pat) then
						refCount = refCount + 1
						refLine = j
						if refCount > 1 then return end
					end
				end
			end
		end
		if refCount ~= 1 or not refLine then return end
		-- Reference must be after declaration end and within reasonable range
		-- (we still want to inline cross-scope cases, just not when very far)
		if refLine < fnEnd then return end
		-- The reference line must contain `anonN` in argument position
		local refInd = out[refLine]:match("^(%s*)") or ""
		if #refInd < #fnInd then return end
		local s, e = out[refLine]:find(pat)
		if not s then return end
		local before = out[refLine]:sub(1, s - 1)
		local after = out[refLine]:sub(e + 1)
		if not before:match("[(,]%s*$") then return end
		if not after:match("^%s*[%),]") then return end
		-- Build inline form
		local origBodyInd = fnInd .. "\t"
		local newBodyInd = refInd .. "\t"
		local bodyLines = {}
		for j = i + 1, fnEnd - 1 do
			local bl = out[j]
			if bl:sub(1, #origBodyInd) == origBodyInd then
				bodyLines[#bodyLines + 1] = newBodyInd .. bl:sub(#origBodyInd + 1)
			else
				bodyLines[#bodyLines + 1] = bl
			end
		end
		local newLines = {}
		newLines[#newLines + 1] = before .. "function" .. fnArgs
		for _, bl in ipairs(bodyLines) do newLines[#newLines + 1] = bl end
		newLines[#newLines + 1] = refInd .. "end" .. after
		for j = i, fnEnd do
			out[j] = ""
			explicitlyEmptied[j] = true
		end
		for j = fnEnd + 1, refLine - 1 do
			if not out[j]:match("%S") then
				out[j] = ""
				explicitlyEmptied[j] = true
			end
		end
		out[refLine] = table.concat(newLines, "\n")
	end
	local i = #out
	while i >= 1 do
		if out[i]:find("local%s+function%s+anon%d+") then
			tryInline(i)
			-- After tryInline (which may have done nothing), also try dropping dead.
			-- Re-check the line still has the declaration (tryInline may have emptied it).
			if out[i]:find("local%s+function%s+anon%d+") then
				tryDropDead(i)
			end
		end
		i = i - 1
	end
	-- Split multi-line out entries and drop the explicitly emptied ones.
	-- Also collapse runs of blank lines (>1 consecutive blank) introduced by drops.
	local final = {}
	local prevBlank = false
	for idx, ln in ipairs(out) do
		if explicitlyEmptied[idx] then
			-- skip
		elseif ln:find("\n", 1, true) then
			for sub in (ln .. "\n"):gmatch("([^\n]*)\n") do
				local isBlank = sub == "" or not sub:match("%S")
				if not (isBlank and prevBlank) then
					final[#final + 1] = sub
				end
				prevBlank = isBlank
			end
		else
			local isBlank = ln == "" or not ln:match("%S")
			if not (isBlank and prevBlank) then
				final[#final + 1] = ln
			end
			prevBlank = isBlank
		end
	end
	return final
end

PASSES.fixSelfReferentialReassignment = function(lines)
	-- Pattern: within a single block (typically a for-loop body):
	--   NAME = INSTANCE_EXPR              -- keeps NAME = instance
	--   ... (some operations on NAME) ...
	--   NAME = OTHER_EXPR                 -- 鉂?overwrites NAME, name conflict
	--   local NAME_val = NAME.FIELD       -- now refers to OTHER, not instance
	--   table.insert(NAME_val, NAME)      -- inserts OTHER into NAME_val (= OTHER.FIELD)
	-- We rewrite by substituting OTHER_EXPR's value for NAME_val, and dropping
	-- the `NAME = OTHER_EXPR` line so NAME keeps its original instance value.
	local out = {}
	for i, line in ipairs(lines) do out[i] = line end
	local function tryFix(i)
		-- Match: `<ind>NAME = SAFE_EXPR` (assignment, not declaration)
		local ind, name, rhs = out[i]:match("^(%s*)([%a_][%w_]*)%s*=%s*(.+)%s*$")
		if not ind or not name or not rhs then return end
		if out[i]:match("^%s*local%s") then return end
		-- RHS must be a pure field access (no calls)
		local rt = rhs:match("^%s*(.-)%s*$") or ""
		if rt:find("[(:]") or rt:find("[[]", 1, true) then return end
		if not rt:match("^[%a_][%w_]*[%.%w_]*$") then return end
		-- Next line must be `<ind>local NAME_val = NAME.FIELD`
		local nl = out[i + 1]
		if not nl then return end
		local n2Ind, valName, valRhs = nl:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
		if n2Ind ~= ind then return end
		if not valName or not valRhs then return end
		-- valName should contain NAME (heuristic for derived name)
		if not valName:find(name, 1, true) then return end
		-- valRhs should reference NAME
		local fieldRhs = valRhs:match("^" .. luaPE(name) .. "%.([%a_][%w_]*)%s*$")
		if not fieldRhs then return end
		-- Third line: should READ NAME (the original instance) 鈥?typically table.insert
		local tl = out[i + 2]
		if not tl then return end
		if not tl:find("%f[%a_]" .. luaPE(name) .. "%f[^%a_%d]") then return end
		-- Look back for original `NAME = INSTANCE_EXPR` or `local NAME = INSTANCE_EXPR`
		local origRhs = nil
		for k = i - 1, math.max(1, i - 50), -1 do
			local origInd, origName, origR = out[k]:match("^(%s*)([%a_][%w_]*)%s*=%s*(.+)%s*$")
			if origInd and origName == name and origR and #origInd <= #ind and not out[k]:match("^%s*local%s") then
				origRhs = origR
				break
			end
			origInd, origName, origR = out[k]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
			if origInd and origName == name and origR and #origInd <= #ind then
				origRhs = origR
				break
			end
		end
		if not origRhs then return end
		-- Rewrite: drop line i, replace line i+1 with `local NAME_val = SAFE_EXPR.FIELD`.
		out[i] = ""
		out[i + 1] = n2Ind .. "local " .. valName .. " = " .. rt .. "." .. fieldRhs
	end
	for i = 1, #out - 2 do
		tryFix(i)
	end
	-- Compact blank lines
	local final = {}
	for _, ln in ipairs(out) do
		if ln ~= "" then final[#final + 1] = ln end
	end
	return final
end

-- Drop empty `else` clauses: `if X then Y else end` -> `if X then Y end`.
PASSES.dropEmptyElseClauses = function(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local elseInd = lines[i]:match("^(%s*)else%s*$")
		if elseInd then
			-- Find the matching `end` at same indent
			local nextNonBlank = i + 1
			while nextNonBlank <= #lines and not lines[nextNonBlank]:match("%S") do
				nextNonBlank = nextNonBlank + 1
			end
			if nextNonBlank <= #lines then
				local endInd = lines[nextNonBlank]:match("^(%s*)end%s*$")
				if endInd == elseInd then
					-- Drop the `else` line; keep the `end`
					i = nextNonBlank
					out[#out + 1] = lines[i]
					i = i + 1
				else
					out[#out + 1] = lines[i]
					i = i + 1
				end
			else
				out[#out + 1] = lines[i]
				i = i + 1
			end
		else
			out[#out + 1] = lines[i]
			i = i + 1
		end
	end
	return out
end

-- Flip `if COND then [empty] else BODY end` -> `if not (COND) then BODY end`.
-- The empty-then with non-empty-else pattern arises after passes lift inner gotos
-- and leaves a degenerate if-block. The semantics are equivalent to a negated
-- guard.
PASSES.flipEmptyThenWithElse = function(lines)
	-- Run multiple passes until no more changes; flipping outer blocks may
	-- expose nested blocks that also become eligible.
	local maxIter = 10
	for _ = 1, maxIter do
		local prev = lines
		lines = (function(lines)
			local out = {}
			local i = 1
			while i <= #lines do
				local ifInd, cond = lines[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
				if ifInd and cond then
					-- Find the matching `else` at same indent and `end` at same indent
					local depth = 0
					local elseIdx = nil
					local endIdx = nil
					for j = i + 1, #lines do
						local ln = lines[j]
						local jInd = ln:match("^(%s*)") or ""
						if #jInd == #ifInd and ln:match("^%s*else%s*$") and depth == 0 then
							elseIdx = j
						elseif #jInd == #ifInd and ln:match("^%s*end%s*$") and depth == 0 then
							endIdx = j
							break
						elseif ln:match("^%s*if%s") and ln:match("then%s*$") then
							depth = depth + 1
						elseif ln:match("^%s*end%s*$") then
							depth = depth - 1
						end
					end
					if elseIdx and endIdx then
						-- Check if the THEN-body (between i+1 and elseIdx-1) is empty (only blanks)
						local thenEmpty = true
						for j = i + 1, elseIdx - 1 do
							if lines[j]:match("%S") then thenEmpty = false; break end
						end
						-- Check the ELSE-body has at least one non-blank line
						local elseHasContent = false
						for j = elseIdx + 1, endIdx - 1 do
							if lines[j]:match("%S") then elseHasContent = true; break end
						end
						if thenEmpty and elseHasContent then
							-- Build inverted if
							local invertedCond
							if cond:match("^not%s+") then
								invertedCond = cond:gsub("^not%s+", "")
								local inner = invertedCond:match("^%((.-)%)$")
								if inner then invertedCond = inner end
							else
								invertedCond = "not (" .. cond .. ")"
							end
							out[#out + 1] = ifInd .. "if " .. invertedCond .. " then"
							for j = elseIdx + 1, endIdx - 1 do
								out[#out + 1] = lines[j]
							end
							out[#out + 1] = lines[endIdx]
							i = endIdx + 1
						else
							out[#out + 1] = lines[i]
							i = i + 1
						end
					else
						out[#out + 1] = lines[i]
						i = i + 1
					end
				else
					out[#out + 1] = lines[i]
					i = i + 1
				end
			end
			return out
		end)(lines)
		-- Check if anything changed
		local changed = (#prev ~= #lines)
		if not changed then
			for k = 1, #lines do
				if prev[k] ~= lines[k] then changed = true; break end
			end
		end
		if not changed then break end
	end
	return lines
end

-- Collapse multi-guard "(A and A.B and ... and X.Y) or D" pattern that compiled
-- as nested ifs:
--   if COND_chain then
--       NAME = CHAIN
--       if not NAME then NAME = FALLBACK end
--   end
-- Detect when NAME is forward-declared earlier (via `local NAME` or `local NAME = nil`)
-- and used after the block. Convert the entire structure to:
--   NAME = (COND_chain and CHAIN) or FALLBACK
-- This corrects the semantic bug where NAME stays nil if COND_chain is false,
-- causing later `string.format(NAME, ...)` to crash.
PASSES.collapseMultiGuardOrDefault = function(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		-- Match: `<ind>if COND then`
		local ifInd, cond = lines[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
		if ifInd and cond and i + 5 <= #lines then
			local innerInd = ifInd .. "\t"
			-- Match: `<innerInd>NAME = CHAIN_EXPR`
			local assignName, assignRhs = lines[i + 1]:match("^" .. luaPE(innerInd) .. "([%a_][%w_]*)%s*=%s*(.+)$")
			if assignName and assignRhs and not lines[i + 1]:match("^%s*local%s") then
				-- Match: `<innerInd>if not (NAME) then` OR `<innerInd>if not NAME then`
				local guardLine = lines[i + 2]
				local guardCond = guardLine and (guardLine:match("^" .. luaPE(innerInd) .. "if%s+not%s+%(?(.-)%)?%s+then%s*$"))
				if guardCond and guardCond == assignName then
					-- Match: `<inner+inner>NAME = FALLBACK`
					local innerInd2 = innerInd .. "\t"
					local fbName, fbRhs = lines[i + 3]:match("^" .. luaPE(innerInd2) .. "([%a_][%w_]*)%s*=%s*(.+)$")
					if fbName == assignName and fbRhs then
						-- Match: `<innerInd>end` and `<ifInd>end`
						local innerEnd = lines[i + 4] and lines[i + 4]:match("^" .. luaPE(innerInd) .. "end%s*$")
						local outerEnd = lines[i + 5] and lines[i + 5]:match("^" .. luaPE(ifInd) .. "end%s*$")
						if innerEnd and outerEnd then
							-- Build collapsed expression: `NAME = (cond and chain) or fallback`
							-- Wrap cond in parens if it contains "and"/"or" at outer level.
							local wrappedCond = cond
							if cond:find(" and ", 1, true) or cond:find(" or ", 1, true) then
								wrappedCond = "(" .. cond .. ")"
							end
							-- Wrap chain similarly
							local wrappedChain = assignRhs
							-- If chain contains operators that have lower precedence than `and`,
							-- wrap. For safety, wrap when it contains spaces with operators.
							if assignRhs:find(" and ", 1, true) or assignRhs:find(" or ", 1, true) then
								wrappedChain = "(" .. assignRhs .. ")"
							end
							local wrappedFb = fbRhs
							-- Emit: `NAME = (COND and CHAIN) or FALLBACK`
							out[#out + 1] = ifInd .. assignName .. " = (" .. wrappedCond .. " and " .. wrappedChain .. ") or " .. wrappedFb
							i = i + 6
						else
							out[#out + 1] = lines[i]; i = i + 1
						end
					else
						out[#out + 1] = lines[i]; i = i + 1
					end
				else
					out[#out + 1] = lines[i]; i = i + 1
				end
			else
				out[#out + 1] = lines[i]; i = i + 1
			end
		else
			out[#out + 1] = lines[i]; i = i + 1
		end
	end
	return out
end

-- Simplify `if COND then X = false else X = true end` to `X = not COND`.
-- Also `if COND then X = true else X = false end` to `X = COND` (or wrapped).
-- Conservative: only handle multi-line form, and only when X is a simple identifier
-- (not a field access).  Also handles preceding `local X` -> `local X = expr`.
PASSES.simplifyBoolLoadbSkip = function(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		-- Match: `<ind>if COND then`
		local ind, cond = lines[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
		if ind and cond and i + 4 <= #lines then
			-- Match: `<ind+>X = LIT`
			local thenLine = lines[i + 1]
			local elseLine = lines[i + 2]
			local elseBody = lines[i + 3]
			local endLine = lines[i + 4]
			local thenInd, thenName, thenLit = thenLine:match("^(%s*)([%a_][%w_]*)%s*=%s*([%a]+)%s*$")
			local elseInd2 = elseLine and elseLine:match("^(%s*)else%s*$")
			local elseInd3, elseName, elseLit = nil, nil, nil
			if elseBody then
				elseInd3, elseName, elseLit = elseBody:match("^(%s*)([%a_][%w_]*)%s*=%s*([%a]+)%s*$")
			end
			local endInd = endLine and endLine:match("^(%s*)end%s*$")
			if thenInd and elseInd2 and elseInd3 and endInd
				and thenInd == elseInd3 and elseInd2 == ind and endInd == ind
				and thenName == elseName and thenLit ~= elseLit
				and (thenLit == "true" or thenLit == "false")
				and (elseLit == "true" or elseLit == "false")
			then
				-- Build expression
				local expr
				if thenLit == "true" and elseLit == "false" then
					expr = cond
				else
					-- thenLit == "false", elseLit == "true"
					expr = "not " .. wrapForAnd(cond)
				end
				-- Check if previous line is `local X` (forward decl) 鈥?merge.
				local mergedDecl = false
				if #out > 0 then
					local prev = out[#out]
					local prevInd, prevName = prev:match("^(%s*)local%s+([%a_][%w_]*)%s*$")
					if prevInd and prevName == thenName and prevInd == ind then
						out[#out] = ind .. "local " .. thenName .. " = " .. expr
						mergedDecl = true
					end
				end
				if not mergedDecl then
					out[#out + 1] = ind .. thenName .. " = " .. expr
				end
				i = i + 5
			else
				out[#out + 1] = lines[i]; i = i + 1
			end
		else
			out[#out + 1] = lines[i]; i = i + 1
		end
	end
	return out
end

-- Drop redundant parens around table literals: `({})` -> `{}`, `({ ... })` -> `{ ... }`
PASSES.dropRedundantParensAroundTables = function(lines)
	local out = {}
	for _, ln in ipairs(lines) do
		-- Only fix safe contexts: inside a table key=value entry, list element, or
		-- as a top-level RHS of `local X = ...` or assignment.
		local new = ln
		-- `= ({...})` -> `= {...}`
		new = new:gsub("(=%s*)%((%b{})%)", "%1%2")
		-- `, ({...})` -> `, {...}` (table list elements)
		new = new:gsub("(,%s*)%((%b{})%)", "%1%2")
		-- `{ ({...})` -> `{ {...}` (first list element)
		new = new:gsub("({%s*)%((%b{})%)", "%1%2")
		-- `return ({...})` -> `return {...}`
		new = new:gsub("(return%s+)%((%b{})%)", "%1%2")
		-- Double parens around simple expression: `((NAME.FIELD))` -> `(NAME.FIELD)`
		-- Apply repeatedly to handle deeply nested doubles.
		for _ = 1, 4 do
			local prev = new
			new = new:gsub("%(%(([^()]+)%)%)", "(%1)")
			if new == prev then break end
		end
		out[#out+1] = new
	end
	return out
end

-- Fix bare-forward declarations that erroneously got initialized from a loop-local.
-- Pattern: `local NAME = V` at function scope where V is declared inside a loop later.
-- Replace with bare `local NAME` (closure will get nil; later assignments inside loop
-- update the upvalue properly via CAPTURE REF mechanics).
PASSES.fixForwardDeclFromLoopLocal = function(lines)
	local out = {}
	for i, line in ipairs(lines) do out[i] = line end
	-- For each `local NAME = OTHER` at function level (immediately after a function header),
	-- check if OTHER is declared *after* this line at deeper indent. If so, the init is invalid.
	for i = 2, #out - 1 do
		local ind, name, rhs = out[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*$")
		if ind and name and rhs and name ~= rhs then
			-- Check the previous non-blank line is a function header
			local prevText = nil
			for k = i - 1, math.max(1, i - 4), -1 do
				if out[k]:match("%S") then
					prevText = out[k]:match("^%s*(.-)%s*$") or ""
					break
				end
			end
			local isAfterFnHeader = prevText and (
				prevText:match("^function%f[^%w_]")
				or prevText:match("^local%s+function%f[^%w_]")
				or prevText:match("=%s*function%(")
				or prevText:match("=%s*function%s+%(")
			)
			if isAfterFnHeader then
				-- Look for `local OTHER` declaration AFTER line i, at deeper indent
				local foundDeeper = false
				for j = i + 1, #out do
					local jInd, jName = out[j]:match("^(%s*)local%s+([%a_][%w_]*)%s*=?")
					if jInd and jName == rhs and #jInd > #ind then
						foundDeeper = true; break
					end
				end
				-- Also, check that OTHER is NOT declared at the same or shallower indent
				-- before line i
				local foundEarlierShallow = false
				for j = i - 1, 1, -1 do
					local jInd, jName = out[j]:match("^(%s*)local%s+([%a_][%w_]*)")
					if jInd and jName == rhs and #jInd <= #ind then
						foundEarlierShallow = true; break
					end
				end
				if foundDeeper and not foundEarlierShallow then
					out[i] = ind .. "local " .. name
				end
			end
		end
	end
	return out
end

-- Drop duplicate `local NAME` declarations within the same function scope.
-- Multiple hoist passes can introduce duplicate forward declarations.
-- We use indent-tracking: a duplicate `local NAME` (no init value) at the same
-- indentation as a previous one (without an intervening function boundary or
-- end-of-block popping back to shallower indent) is dropped.
PASSES.dropDuplicateLocalForwardDecls = function(lines)
	local out = {}
	-- Per-function-scope set of declared bare names. The function-scope stack
	-- is keyed by `local function` / `function` openings.  We approximate scope
	-- pop using indent: whenever we encounter a line at a SHALLOWER indent than
	-- the function-open line + 1 tab (i.e., the function's `end`), we pop.
	local fnStack = { { ind = "", names = {} } }  -- stack entries: {ind, names}
	for _, line in ipairs(lines) do
		local lineInd = line:match("^(%s*)") or ""
		local text = line:match("^%s*(.-)%s*$") or ""
		-- Pop scopes when we see `end` at the function's open-indent
		while #fnStack > 1 do
			local top = fnStack[#fnStack]
			if #lineInd < #top.ind then
				table.remove(fnStack)
			else
				break
			end
		end
		-- Open new scope on `function` / `local function` / `= function(`
		local isFnOpen = text:match("^function%f[^%w_]")
			or text:match("^local%s+function%f[^%w_]")
			or text:match("=%s*function%(")
			or text:match("=%s*function%s+%(")
		-- The new function body's indent is lineInd + "\t"
		if isFnOpen then
			fnStack[#fnStack + 1] = { ind = lineInd .. "\t", names = {} }
		end
		-- Bare `local NAME` (no init)
		local declName = line:match("^%s*local%s+([%a_][%w_]*)%s*$")
		local isDup = false
		if declName then
			local cur = fnStack[#fnStack]
			if cur.names[declName] then isDup = true else cur.names[declName] = true end
		end
		if not isDup then out[#out + 1] = line end
	end
	return out
end

-- Drop `local NAME = nil` lines whose NAME is referenced nowhere else in the
-- enclosing function scope. These are typically register-merge phi placeholders
-- left behind when one branch of a phi is a no-op (e.g. `elseif B then local
-- _v = nil end`). Only targets generated temp names so user-meaningful locals
-- are untouched.
PASSES.dropDeadNilLocals = function(lines)
	local function isTempName(n)
		if type(n) ~= "string" then return false end
		if n:match("^v_u%d") then return true end
		if n:match("^_v%d") then return true end
		if n:match("^_r%d") then return true end
		if n:match("^_value_") then return true end
		if n:match("^_value%d") then return true end
		if n:match("^_flag%d") then return true end
		if n:match("^_t%d") then return true end
		return false
	end
	-- Compute function ranges by tracking indent of `function`/`local function`
	-- opens and `end` closes. Naive but adequate for our pretty-printed output.
	-- Each entry: { startIdx, endIdx, ind } where ind is the indent of the
	-- function body (one tab deeper than the header).
	local fnRanges = {}
	do
		local stack = {}
		for i, line in ipairs(lines) do
			local indent = line:match("^(%s*)") or ""
			local text = line:match("^%s*(.-)%s*$") or ""
			-- Function open
			if text:match("^function%s") or text:match("^local%s+function%s")
				or text:match("=%s*function%s*%(") then
				if not text:match("end%s*$") then
					stack[#stack + 1] = { startIdx = i, ind = indent .. "\t" }
				end
			elseif text == "end" or text:match("^end[%)%},;]") or text:match("^end%s") then
				if #stack > 0 and #indent == #stack[#stack].ind - 1 then
					local top = table.remove(stack)
					fnRanges[#fnRanges + 1] = { startIdx = top.startIdx, endIdx = i, ind = top.ind }
				end
			end
		end
	end
	-- Module-level (whole file) range as fallback for top-level decls.
	fnRanges[#fnRanges + 1] = { startIdx = 1, endIdx = #lines, ind = "" }
	-- For a given line index, find the smallest enclosing function range.
	local function rangeFor(idx)
		local best = nil
		for _, r in ipairs(fnRanges) do
			if r.startIdx <= idx and idx <= r.endIdx then
				if (not best) or (r.startIdx > best.startIdx) then best = r end
			end
		end
		return best
	end
	local toDrop = {}
	for i, line in ipairs(lines) do
		local nm = line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*nil%s*$")
		if nm and isTempName(nm) then
			local rng = rangeFor(i)
			if rng then
				local pat = "%f[%w_]" .. nm .. "%f[^%w_]"
				local found = false
				for j = rng.startIdx, rng.endIdx do
					if j ~= i and lines[j]:find(pat) then
						found = true
						break
					end
				end
				if not found then toDrop[i] = true end
			end
		end
	end
	if next(toDrop) == nil then return lines end
	local out = {}
	for i, line in ipairs(lines) do
		if not toDrop[i] then out[#out + 1] = line end
	end
	return out
end

-- Add forward `local NAME` declarations at the start of a function for any
-- target identifier that is bare-assigned somewhere inside the function but
-- never declared in any enclosing scope. Without this pass, register-tracking
-- artifacts can produce statements like:
--     MainPart_2 = Base
--     C0 = ((MainPart_2) and (MainPart_2.C0)) or nil
-- inside a function body, where `MainPart_2` and `C0` were never declared.
-- These would silently leak to the global scope. By hoisting to a single
-- forward decl at function entry, references that span sibling/inner blocks
-- (e.g. `if X then C0 = ... end; tbl = { C0 = C0 }`) keep working.
PASSES.addMissingLocalPrefix = function(lines)
	local KNOWN_GLOBALS = {
		_G = true, _ENV = true, script = true, game = true, workspace = true,
		shared = true, plugin = true, math = true, table = true, string = true,
		coroutine = true, os = true, io = true, debug = true, bit32 = true,
		utf8 = true, task = true, buffer = true, vector = true,
		require = true, getfenv = true, setfenv = true, getmetatable = true,
		setmetatable = true, rawget = true, rawset = true, rawequal = true,
		rawlen = true, type = true, typeof = true, tostring = true, tonumber = true,
		print = true, warn = true, error = true, assert = true, select = true,
		pcall = true, xpcall = true, ipairs = true, pairs = true, next = true,
		unpack = true, newproxy = true, gcinfo = true, collectgarbage = true,
		Instance = true, Vector2 = true, Vector3 = true, CFrame = true,
		Color3 = true, UDim = true, UDim2 = true, Rect = true, Region3 = true,
		Ray = true, BrickColor = true, Enum = true, NumberRange = true,
		NumberSequence = true, NumberSequenceKeypoint = true, ColorSequence = true,
		ColorSequenceKeypoint = true, TweenInfo = true, RaycastParams = true,
		PathWaypoint = true, PhysicalProperties = true, Faces = true, Axes = true,
		DateTime = true, Random = true, OverlapParams = true, FloatCurveKey = true,
		Vector3int16 = true, Vector2int16 = true, Region3int16 = true,
		Font = true, ContentId = true, Content = true, ["nil"] = true,
		["true"] = true, ["false"] = true, inf = true,
		self = true,
	}
	-- Match `NAME = EXPR` where NAME is a single identifier (no dot/colon/[])
	-- and the line doesn't start with `local`/`function`/`return`/`if`/`for`/etc.
	local function isSimpleNameAssign(text)
		if text == "" then return nil end
		local first = text:match("^([%a_][%w_]*)") or ""
		if first == "local" or first == "function" or first == "return"
			or first == "if" or first == "elseif" or first == "else"
			or first == "for" or first == "while" or first == "do"
			or first == "repeat" or first == "until" or first == "end"
			or first == "break" or first == "continue" then
			return nil
		end
		-- Multi-target `A, B = X, Y` skipped (too complex; rare in our output)
		local name, rest = text:match("^([%a_][%w_]*)%s*=%s*(.+)$")
		if not name then return nil end
		-- Reject augmented assignments (`A += B` etc.) — Luau permits them.
		if text:match("^[%a_][%w_]*%s*[%+%-%*%/%%%.][%+%-%*%/%%%.]*=") then return nil end
		return name, rest
	end
	-- Phase 1: walk lines tracking function-scope stack; collect:
	--   - per function, the set of names bare-assigned inside it
	--   - per function, the set of names declared (locals + params) — across all
	--     nested blocks within the function
	--   - per function, the line-index where its body begins (for hoist insertion)
	-- A line is "inside a function" only if at least one function frame is on the
	-- stack beyond the module-level frame.
	local stack = { { ind = "", kind = "function", declared = {}, bareAssigns = {}, headerIdx = 0 } }
	local function topFn()
		for k = #stack, 1, -1 do
			if stack[k].kind == "function" then return stack[k] end
		end
		return stack[1]
	end
	local function isDeclaredInChain(name)
		if KNOWN_GLOBALS[name] then return true end
		for k = #stack, 1, -1 do
			if stack[k].declared[name] then return true end
		end
		return false
	end
	-- Track all function frames in order so we can insert hoists after the walk.
	local allFnFrames = { stack[1] }
	for idx, line in ipairs(lines) do
		local indent = line:match("^(%s*)") or ""
		local text = line:match("^%s*(.-)%s*$") or ""
		-- Pop block scopes whose indent is strictly greater than current.
		-- Function scopes pop only on a closing `end`/dedent below their indent.
		while #stack > 1 do
			local top = stack[#stack]
			if #indent < #top.ind then
				table.remove(stack)
			else
				break
			end
		end
		-- Detect function-open and capture its arg list.
		local fnArgs = nil
		local fnNameLocal = nil  -- for `local NAME = function(...)`, declares NAME in parent scope
		do
			local n1, args1 = text:match("^local%s+function%s+([%a_][%w_]*)%s*%(([^)]*)%)")
			if n1 then
				topFn().declared[n1] = true
				fnArgs = args1
			else
				local args2 = text:match("^function%s+[%a_][%w_%.:]*%s*%(([^)]*)%)")
				if args2 ~= nil then
					fnArgs = args2
				else
					local nm3, args3 = text:match("^local%s+([%a_][%w_]*)%s*=%s*function%s*%(([^)]*)%)")
					if nm3 then
						topFn().declared[nm3] = true
						fnArgs = args3
						fnNameLocal = nm3
					else
						local args4 = text:match("=%s*function%s*%(([^)]*)%)")
						if args4 ~= nil then fnArgs = args4 end
					end
				end
			end
		end
		if fnArgs ~= nil then
			local newFn = { ind = indent .. "\t", kind = "function", declared = {}, bareAssigns = {}, headerIdx = idx }
			-- Method form `function T:method(...)` declares implicit `self`
			if text:match("^function%s+[%a_][%w_%.]*:[%a_]") then
				newFn.declared["self"] = true
			end
			for arg in fnArgs:gmatch("([%a_][%w_]*)") do
				newFn.declared[arg] = true
			end
			table.insert(stack, newFn)
			table.insert(allFnFrames, newFn)
		else
			-- Track local declarations
			local locDecls = text:match("^local%s+([^=]+)%s*=") or text:match("^local%s+([%a_][%w_,%s]*)%s*$")
			if locDecls then
				for nm in locDecls:gmatch("([%a_][%w_]*)") do
					if nm ~= "function" then topFn().declared[nm] = true end
				end
			end
			-- `for K, V in ... do` and `for K = ... do`
			local forVars = text:match("^for%s+([^=]+)%s+in%s")
			if forVars then
				for nm in forVars:gmatch("([%a_][%w_]*)") do
					topFn().declared[nm] = true
				end
			end
			local forNumeric = text:match("^for%s+([%a_][%w_]*)%s*=")
			if forNumeric then topFn().declared[forNumeric] = true end
			-- Detect bare assignments inside a function (not at module level).
			local isInsideFunction = #stack >= 2
			if isInsideFunction then
				local name = isSimpleNameAssign(text)
				if name and not KNOWN_GLOBALS[name] and not isDeclaredInChain(name) then
					-- Record for hoist; mark declared in current top function so we
					-- don't re-record on later assignments to the same name.
					local fn = topFn()
					if not fn.bareAssigns[name] then
						fn.bareAssigns[name] = true
					end
					fn.declared[name] = true
				end
			end
		end
	end
	-- Phase 2: build new lines. For each function frame with bareAssigns, insert
	-- `local NAME, NAME, ...` (one combined decl) right after its header line.
	-- Frames with empty bareAssigns are skipped.
	-- Module-level frame (allFnFrames[1]) is skipped by default: top-level bare
	-- assigns are intentional global writes in many cases. EXCEPTION: names
	-- that match obvious "renamed-from-temp" patterns (single-letter prefix +
	-- digits like f2, r3, s5, w1, t1, n1, v_uN, _vN, _rN, _value_N, _flag_N)
	-- are clearly generated temps and should be locals even at module level.
	local function isGeneratedTempName(name)
		if name:match("^[fnrstwv]%d+$") then return true end
		if name:match("^v_u%d+$") then return true end
		if name:match("^_[vr]%d+$") then return true end
		if name:match("^_value_%d+$") then return true end
		if name:match("^_value%d+$") then return true end
		if name:match("^_flag_?%d+$") then return true end
		return false
	end
	local insertions = {}  -- map[lineIdx] = string to insert after that line
	for k = 1, #allFnFrames do
		local fn = allFnFrames[k]
		local names = {}
		if k == 1 then
			-- Module level: only auto-local generated-looking names.
			for nm in pairs(fn.bareAssigns) do
				if isGeneratedTempName(nm) then names[#names + 1] = nm end
			end
		else
			for nm in pairs(fn.bareAssigns) do names[#names + 1] = nm end
		end
		if #names > 0 and (k > 1 or fn.headerIdx >= 0) then
			table.sort(names)
			local insertAt = fn.headerIdx
			-- For module level (headerIdx == 0), insert at very top.
			if k == 1 then insertAt = 0 end
			insertions[insertAt] = (fn.ind or "") .. "local " .. table.concat(names, ", ")
		end
	end
	if next(insertions) == nil then return lines end
	local out = {}
	-- Handle insertion at index 0 (before line 1) for module-level hoist.
	if insertions[0] then
		out[#out + 1] = insertions[0]
	end
	for i = 1, #lines do
		out[#out + 1] = lines[i]
		if insertions[i] then
			out[#out + 1] = insertions[i]
		end
	end
	return out
end

PASSES.dropDeadUnusedLocals = function(lines)
	-- Build list of (i, name, ind) of `local X = EXPR` where X is a generated
	-- temp name (e.g., arg0_val_3, _value_8_val) and EXPR is a simple field chain
	-- like `EXPR.field` / `(EXPR.field or N)`. Then drop those whose name has no
	-- subsequent reads in the file.
	local function isSafeRhs(rhs)
		rhs = rhs:match("^%s*(.-)%s*$") or ""
		-- `IDENT(.IDENT)+` pattern (no calls, no method invocations)
		if rhs:match("^[%a_][%w_]*$") then return true end
		if rhs:match("^[%a_][%w_]*%.[%a_][%w_%.]*$") then return true end
		-- `(EXPR or N)` simple
		local inner = rhs:match("^%((.+)%)$")
		if inner then return isSafeRhs(inner) end
		-- `X or Y` where X and Y are both safe-rhs
		local lhs, rhs2 = rhs:match("^(.+)%s+or%s+(.+)$")
		if lhs and rhs2 then
			-- recursively check both halves (only one level)
			-- accept if both are simple field access or literals
			local function simpleHalf(s)
				s = s:match("^%s*(.-)%s*$") or ""
				if s:match("^[%a_][%w_]*$") then return true end
				if s:match("^[%a_][%w_]*%.[%a_][%w_%.]*$") then return true end
				if s:match("^%-?%d+%.?%d*$") then return true end
				if s:match("^\".-\"$") then return true end
				if s:match("^'.-'$") then return true end
				return false
			end
			if simpleHalf(lhs) and simpleHalf(rhs2) then return true end
		end
		-- Side-effect-free expression: contains only IDENT + literals + operators (..,+,-,*,/,%,^,#),
		-- no calls (no `(` followed by something that's not a number) and no `:` (method).
		-- Conservatively, accept when there's no `(` not paired with a closing `)` of an
		-- enclosing literal structure, no `:` (method/colon), and no string with parens.
		-- For simplicity: scan character-by-character outside strings; reject `(` not part of
		-- `(EXPR)` grouping (which would mean a call). Also reject `:`.
		do
			local i = 1
			local n = #rhs
			local inq = nil
			local hasCall = false
			local hasColonCall = false
			while i <= n do
				local c = rhs:sub(i, i)
				if inq then
					if c == "\\" and i + 1 <= n then i = i + 2
					elseif c == inq then inq = nil; i = i + 1
					else i = i + 1
					end
				elseif c == '"' or c == "'" then
					inq = c; i = i + 1
				elseif c == "(" then
					-- Could be a call OR a grouping. Check what's before.
					local prev = i > 1 and rhs:sub(i - 1, i - 1) or ""
					if prev:match("[%w_%]%)]") then hasCall = true; break end
					i = i + 1
				elseif c == ":" then
					-- not allowed (method call or unexpected)
					hasColonCall = true; break
				else
					i = i + 1
				end
			end
			if not hasCall and not hasColonCall then return true end
		end
		return false
	end
	-- generated temp name patterns (be conservative)
	local function isGeneratedName(name)
		if not name then return false end
		return name:match("_val$") ~= nil
			or name:match("_val_%d+$") ~= nil
			or name:match("_result$") ~= nil
			or name:match("_result_%d+$") ~= nil
			or name:match("_val_val") ~= nil
	end
	-- scan for `local NAME = RHS` and check usage
	local out = {}
	for i, line in ipairs(lines) do
		local ind, name, rhs = line:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
		local dropped = false
		if ind and name and rhs and isGeneratedName(name) and isSafeRhs(rhs) then
			-- Check if name is referenced after this line
			local pat = identPat(name)
			local usedLater = false
			for j = i + 1, #lines do
				if lines[j]:find(pat) then
					usedLater = true
					break
				end
			end
			if not usedLater then dropped = true end
		end
		-- Variant 2: `local TEMP = RCVR:METHOD(...)` immediately preceded by
		-- `if RCVR then return ... end` (so RCVR is nil here, line is unreachable).
		if not dropped and ind and name and rhs and isGeneratedName(name) then
			local rcvr = rhs:match("^([%a_][%w_]*):[%a_][%w_]*%(.*%)%s*$")
			if rcvr then
				local pat = identPat(name)
				local usedLater = false
				for j = i + 1, #lines do
					if lines[j]:find(pat) then
						usedLater = true
						break
					end
				end
				if not usedLater then
					for j = i - 1, math.max(1, i - 6), -1 do
						if lines[j]:match("%S") then
							local jInd = lines[j]:match("^(%s*)") or ""
							local prevPat = "^" .. luaPE(jInd) .. "if%s+" .. luaPE(rcvr) .. "%s+then%s+return%s.+%s+end%s*$"
							if #jInd <= #ind and lines[j]:match(prevPat) then
								dropped = true
							end
							break
						end
					end
				end
			end
		end
		if not dropped then out[#out+1] = line end
	end
	return out
end

-- Fix CSE'd loads that ended up only inside a branch but are used outside.
-- Pattern:
--   function ...
--       local X
--       ...
--       if COND then
--           X = SAFE_EXPR        -- only assignment to X
--           ... return ...
--       end
--       USE X here               -- 鉂?X is nil if COND was false
-- 
-- If SAFE_EXPR is a pure field-access expression (no calls, only param/upvalue/self
-- field reads), the bytecode likely loaded X unconditionally before the branch.
-- We hoist `X = SAFE_EXPR` to right after `local X` declaration.
PASSES.hoistBranchOnlyAssignmentsToFnStart = function(lines)
	local function isPureFieldExpr(rhs)
		rhs = rhs:match("^%s*(.-)%s*$") or ""
		-- Strip surrounding parens
		while rhs:sub(1, 1) == "(" and rhs:sub(-1) == ")" do
			rhs = rhs:sub(2, -2):match("^%s*(.-)%s*$")
		end
		-- ident
		if rhs:match("^[%a_][%w_]*$") then return true end
		-- ident.field.field...
		if rhs:match("^[%a_][%w_]*[%.%[][%w_%.%[%]\"']*$") and not rhs:find("[(:]") then return true end
		-- (X or N) where X and N are simple
		local lhs, rhs2 = rhs:match("^(.-)%s+or%s+(.+)$")
		if lhs and rhs2 then
			local function simpleHalf(s)
				s = s:match("^%s*(.-)%s*$") or ""
				while s:sub(1, 1) == "(" and s:sub(-1) == ")" do
					s = s:sub(2, -2):match("^%s*(.-)%s*$")
				end
				if s:match("^[%a_][%w_]*$") then return true end
				if s:match("^[%a_][%w_]*[%.%[][%w_%.%[%]\"']*$") and not s:find("[(:]") then return true end
				if s:match("^%-?%d+%.?%d*$") then return true end
				if s:match("^\".-\"$") then return true end
				if s:match("^'.-'$") then return true end
				return false
			end
			if simpleHalf(lhs) and simpleHalf(rhs2) then return true end
		end
		return false
	end
	-- find all function bodies and process each
	local out = {}
	for i, line in ipairs(lines) do out[i] = line end
	-- Iterate to find `function` lines
	for fnStart = 1, #out do
		local text = out[fnStart] and out[fnStart]:match("^%s*(.-)%s*$") or ""
		if text:match("^function%f[^%w_]")
			or text:match("^local%s+function%f[^%w_]")
			or text:match("=%s*function%(")
			or text:match("=%s*function%s+%(")
		then
			-- find matching `end`
			local fnInd = out[fnStart]:match("^(%s*)") or ""
			local fnEnd = nil
			for j = fnStart + 1, #out do
				local jInd = out[j]:match("^(%s*)") or ""
				local jText = out[j]:match("^%s*(.-)%s*$") or ""
				if jInd == fnInd and jText == "end" then fnEnd = j; break end
			end
			if fnEnd then
				-- Find `local X` declarations at top of function body.
				-- Determine actual body indent from the first non-blank line after fnStart.
				local bodyInd = nil
				for j = fnStart + 1, fnEnd - 1 do
					if out[j]:match("%S") then
						bodyInd = out[j]:match("^(%s*)") or ""
						break
					end
				end
				if not bodyInd or #bodyInd <= #fnInd then bodyInd = fnInd .. "\t" end
				-- Collect uninitialized `local X` declarations (no `= EXPR`)
				local declLocals = {}  -- name -> idx
				for j = fnStart + 1, fnEnd - 1 do
					local d = out[j]:match("^" .. luaPE(bodyInd) .. "local%s+([%a_][%w_]*)%s*$")
					if d then declLocals[d] = j
					elseif out[j]:match("%S") then
						-- stop scanning at the first non-blank, non-decl line
						-- (only declarations clustered at top are eligible)
						break
					end
				end
				-- For each declared local, find single assignment in branch
				for name, declIdx in pairs(declLocals) do
					-- Find all assignments `<ind>NAME = RHS`
					local assigns = {}
					for j = declIdx + 1, fnEnd - 1 do
						local aInd, aRhs = out[j]:match("^(%s*)" .. luaPE(name) .. "%s*=%s*(.+)%s*$")
						if aInd and not out[j]:match("^%s*local%s") then
							assigns[#assigns + 1] = { idx = j, ind = aInd, rhs = aRhs }
						end
					end
					if #assigns >= 1 then
						-- Is the FIRST assignment inside a branch (deeper than bodyInd)?
						local first = assigns[1]
						if #first.ind > #bodyInd and isPureFieldExpr(first.rhs) then
							-- Check: is name used at bodyInd-level (or shallower than first.ind) AFTER first.idx?
							local usedShallower = false
							for j = first.idx + 1, fnEnd - 1 do
								if out[j]:find(identPat(name)) then
									local jInd = out[j]:match("^(%s*)") or ""
									if #jInd <= #bodyInd then
										usedShallower = true
										break
									end
								end
							end
							if usedShallower then
								-- Check: are all assignments to `name` the SAME pure expression?
								local rhsTrim = first.rhs:match("^%s*(.-)%s*$")
								local sameExpr = true
								for _, a in ipairs(assigns) do
									local aTrim = a.rhs:match("^%s*(.-)%s*$")
									if aTrim ~= rhsTrim then sameExpr = false; break end
								end
								if sameExpr then
									-- Hoist: replace `local X` with `local X = RHS` and remove the in-branch assignment.
									out[declIdx] = bodyInd .. "local " .. name .. " = " .. first.rhs
									out[first.idx] = ""
								end
							end
						end
					end
				end
			end
		end
	end
	-- Compact blank lines we may have inserted
	local final = {}
	for _, ln in ipairs(out) do
		if ln ~= "" then final[#final+1] = ln end
	end
	return final
end

local function fixInvertedIsaGuard(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		if i + 4 > #lines then
			out[#out+1] = lines[i]
			i = i + 1
		else
			local findInd, name = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*.+:FindFirstChild%(.+%)%s*$")
			local ifInd, ifName = lines[i + 1]:match("^(%s*)if%s+([%a_][%w_]*)%s+then%s*$")
			local isaInd, checkName, isaName, isaArg = lines[i + 2]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*):IsA%((.+)%)%s*$")
			if not (findInd and ifInd and isaInd and name and ifName and checkName and isaName and isaArg)
				or ifInd ~= findInd
				or ifName ~= name
				or isaName ~= name
				or isaInd:sub(1, #findInd) ~= findInd
				or isaInd == findInd
			then
				out[#out+1] = lines[i]
				i = i + 1
			else
				local endIdx = nil
				local maxJ = math.min(#lines, i + 11)
				for j = i + 3, maxJ do
					local endInd = matchEnd(lines[j])
					if endInd == findInd then
						endIdx = j
						break
					end
				end
				if not endIdx then
					out[#out+1] = lines[i]
					i = i + 1
				else
					local hasReturn = false
					for j = i + 3, endIdx - 1 do
						local text = lines[j]:match("^%s*(.-)%s*$")
						if text == "return" or text:sub(1, 7) == "return " then
							hasReturn = true
							break
						end
					end
					if not hasReturn then
						out[#out+1] = lines[i]
						i = i + 1
					else
						out[#out+1] = lines[i]
						out[#out+1] = findInd .. "if not " .. name .. " then"
						for j = i + 3, endIdx - 1 do out[#out+1] = lines[j] end
						out[#out+1] = findInd .. "end"
						out[#out+1] = findInd .. "local " .. checkName .. " = " .. name .. ":IsA(" .. isaArg .. ")"
						out[#out+1] = findInd .. "if not " .. checkName .. " then"
						for j = i + 3, endIdx - 1 do out[#out+1] = lines[j] end
						out[#out+1] = findInd .. "end"
						i = endIdx + 1
					end
				end
			end
		end
	end
	return out
end

-- Rewrite goto -> return when label points at a return
local function rewriteGotoToReturn(lines)
	local labelToReturn = {}
	for i, ln in ipairs(lines) do
		local _, lbl = matchLbl(ln)
		if lbl then
			local j = i + 1
			while j <= #lines and (not lines[j]:match("%S") or matchLbl(lines[j])) do j = j + 1 end
			if j <= #lines then
				local ri, rtext = matchReturn(lines[j])
				if ri and rtext then
					labelToReturn[lbl] = rtext:match("^%s*(.-)%s*$")
				end
			end
		end
	end
	if not next(labelToReturn) then return lines end
	local out = {}
	for _, ln in ipairs(lines) do
		local gi, gtgt = matchGoto(ln)
		if gi and labelToReturn[gtgt] then
			out[#out+1] = gi .. labelToReturn[gtgt]
		else
			local ii, icond, itgt = matchIfGoto(ln)
			if ii and labelToReturn[itgt] then
				out[#out+1] = ii .. "if " .. icond .. " then " .. labelToReturn[itgt] .. " end"
			else
				out[#out+1] = ln
			end
		end
	end
	return out
end

-- Rewrite `if NOT COND then goto T end\n return\n ::T::` to `if COND then return end`.
-- The pattern: an if-goto immediately followed by `return` and the goto's target
-- label points at the line right after the return. This is the bytecode pattern
-- "JUMPIFNOT R -> skip_over_return; RETURN; ::skip_over_return::" which means
-- "if R is truthy, execute the return".
local function rewriteSkipReturnAsTruthyReturn(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local ii, icond, itgt = matchIfGoto(lines[i])
		if ii and i + 2 <= #lines then
			local retInd, retText = lines[i + 1]:match("^(%s*)(return)%s*$")
			if not retInd then retInd, retText = lines[i + 1]:match("^(%s*)(return%s.+)%s*$") end
			-- The label must be on line i+2 (after the return)
			local _, lbl = matchLbl(lines[i + 2])
			if retInd and lbl == itgt then
				-- Match: `if not X then goto T end / return / ::T::`
				-- Convert to: `if X then return end` (and drop the original goto + return + label)
				local newCond = negateCond(icond)
				out[#out+1] = ii .. "if " .. newCond .. " then " .. retText .. " end"
				i = i + 3
			else
				out[#out+1] = lines[i]; i = i + 1
			end
		else
			out[#out+1] = lines[i]; i = i + 1
		end
	end
	return out
end

-- Fold constant condition blocks: `if false then...end` -> drop, `if true then...end` -> unwrap
local function foldConstantConditionBlocks(lines, indentUnit)
	for _ = 1, 16 do
		local prev = lines
		local folded = {}
		local skipUntilEndAt = nil
		local unwrapUntilEndAt = nil
		local unwrapStep = ""
		local unwrapSeenElse = false
		for _, ln in ipairs(lines) do
			local stripped = ln:match("^%s*(.-)%s*$")
			local handled = false
			if skipUntilEndAt ~= nil then
				local curInd = ln:match("^(%s*)") or ""
				if curInd == skipUntilEndAt and stripped == "end" then skipUntilEndAt = nil end
				handled = true
			end
			if not handled and unwrapUntilEndAt ~= nil then
				local curInd = ln:match("^(%s*)") or ""
				if curInd == unwrapUntilEndAt then
					if (stripped == "else" or stripped:sub(1,7) == "elseif ") and not unwrapSeenElse then
						unwrapSeenElse = true
						handled = true
					end
					if not handled and stripped == "end" then
						unwrapUntilEndAt = nil
						unwrapStep = ""
						unwrapSeenElse = false
						handled = true
					end
				end
				if not handled and unwrapSeenElse then
					handled = true
				end
				if not handled and unwrapStep == "" and stripped ~= "" then
					if #curInd > #unwrapUntilEndAt then
						unwrapStep = curInd:sub(#unwrapUntilEndAt + 1)
					end
					if unwrapStep == "" then unwrapStep = indentUnit end
				end
				if not handled then
					local childPfx = unwrapUntilEndAt .. unwrapStep
					if unwrapStep ~= "" and ln:sub(1, #childPfx) == childPfx then
						folded[#folded+1] = unwrapUntilEndAt .. ln:sub(#childPfx + 1)
					elseif unwrapStep ~= "" and ln:sub(1, #unwrapStep) == unwrapStep then
						folded[#folded+1] = ln:sub(#unwrapStep + 1)
					else
						folded[#folded+1] = ln
					end
					handled = true
				end
			end
			if not handled then
				local inlineInd, inlineCond, inlineBody = ln:match("^(%s*)if%s+(.+)%s+then%s+(.+)%s+end%s*$")
				if inlineInd then
					local cn = inlineCond:match("^%s*(.-)%s*$")
					while cn:sub(1,1) == "(" and cn:sub(-1) == ")" do
						local d2, bal = 0, true
						for ci = 1, #cn-1 do
							local ch = cn:sub(ci,ci)
							if ch == "(" then d2 = d2+1 elseif ch == ")" then d2 = d2-1; if d2==0 then bal=false; break end end
						end
						if not bal then break end
						cn = cn:sub(2,-2):match("^%s*(.-)%s*$")
					end
					if cn == "false" or cn == "not true" or cn == "not (true)" then
						handled = true
					elseif cn == "true" or cn == "not false" or cn == "not (false)" then
						folded[#folded+1] = inlineInd .. inlineBody
						handled = true
					end
				end
			end
			if not handled then
				local mii, cond = matchIfOpen(ln)
				if mii then
					local cn = cond:match("^%s*(.-)%s*$")
					while cn:sub(1,1) == "(" and cn:sub(-1) == ")" do
						local d2, bal = 0, true
						for ci = 1, #cn-1 do
							local ch = cn:sub(ci,ci)
							if ch == "(" then d2 = d2+1 elseif ch == ")" then d2 = d2-1; if d2==0 then bal=false; break end end
						end
						if not bal then break end
						cn = cn:sub(2,-2):match("^%s*(.-)%s*$")
					end
					if cn == "false" or cn == "not true" or cn == "not (true)" then
						skipUntilEndAt = mii
						handled = true
					end
					if not handled and (cn == "true" or cn == "not false" or cn == "not (false)") then
						unwrapUntilEndAt = mii
						unwrapStep = ""
						unwrapSeenElse = false
						handled = true
					end
				end
				if not handled then
					folded[#folded+1] = ln
				end
			end
		end
		lines = folded
		local same = #lines == #prev
		if same then
			for k = 1, #lines do
				if lines[k] ~= prev[k] then same = false; break end
			end
		end
		if same then break end
	end
	return lines
end

-- Normalize indentation by level tracking
local function normalizeLuaIndentation(lines, indentUnit)
	local out = {}
	local level = 0
	for _, ln in ipairs(lines) do
		local stripped = ln:match("^%s*(.-)%s*$")
		if not stripped or stripped == "" then
			out[#out+1] = ""
		else
			local lower = stripped
			local dedentFirst = (
				lower == "end" or lower == "else"
				or lower:sub(1,7) == "elseif " or lower:sub(1,6) == "until "
			)
			if dedentFirst then level = math.max(0, level - 1) end
			if stripped:sub(1,2) == "::" and stripped:sub(-2) == "::" then
				out[#out+1] = indentUnit:rep(math.max(0, level)) .. stripped
			else
				out[#out+1] = indentUnit:rep(level) .. stripped
			end
			local opensBlock = false
			if lower == "else" or lower:sub(1,7) == "elseif " then opensBlock = true
			elseif lower == "repeat" then opensBlock = true
			elseif lower:sub(-5) == " then" then opensBlock = true
			elseif lower:sub(-3) == " do" then opensBlock = true
			elseif lower:match("^local%s+function%f[%W]") or lower:match("^function%f[%W]") then
				if not lower:match("end%s*$") then opensBlock = true end
			end
			if opensBlock and lower:sub(1,6) ~= "until " then level = level + 1 end
		end
	end
	return out
end

-- Fix bare method references: `obj:Method` (no parens) -> `obj.Method`
local function fixBareMethodReferences(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local code2, comment = line, ""
		-- split off trailing comment
		local ci = 1
		local inQ = nil
		while ci <= #line do
			local ch = line:sub(ci,ci)
			if inQ then
				if ch == "\\" then
					ci = ci + 2
				else
					if ch == inQ then inQ = nil end
					ci = ci + 1
				end
			else
				if ch == '"' or ch == "'" then inQ = ch
				elseif ch == "-" and line:sub(ci+1,ci+1) == "-" then
					code2 = line:sub(1, ci-1); comment = line:sub(ci); break
				end
				ci = ci + 1
			end
		end
		-- replace bare `:Method` with `.Method` when not followed by `(`
		local res = {}
		local qi = 1
		inQ = nil
		while qi <= #code2 do
			local ch = code2:sub(qi,qi)
			if inQ then
				res[#res+1] = ch
				if ch == "\\" and qi < #code2 then
					res[#res+1] = code2:sub(qi+1,qi+1)
					qi = qi + 2
				else
					if ch == inQ then inQ = nil end
					qi = qi + 1
				end
			elseif ch == '"' or ch == "'" then
				inQ = ch
				res[#res+1] = ch
				qi = qi + 1
			elseif ch == ":" and qi + 1 <= #code2 and code2:sub(qi+1,qi+1):match("[%a_]") then
				local j2 = qi + 2
				while j2 <= #code2 and code2:sub(j2,j2):match("[%a_%d]") do j2 = j2 + 1 end
				local k2 = j2
				while k2 <= #code2 and code2:sub(k2,k2):match("%s") do k2 = k2 + 1 end
				if k2 <= #code2 and code2:sub(k2,k2) == "(" then
					res[#res+1] = ":"
				else
					res[#res+1] = "."
				end
				qi = qi + 1
			else
				res[#res+1] = ch
				qi = qi + 1
			end
		end
		out[#out+1] = table.concat(res) .. comment
	end
	return out
end

-- Balance Lua blocks by indent (insert missing `end` lines)
local function balanceLuaBlocksByIndent(lines)
	local out = {}
	local stack = {}  -- {kind, indent}
	local function flushAbove(indLevel)
		while #stack > 0 and #stack[#stack][2] >= indLevel do
			out[#out+1] = stack[#stack][2] .. "end"
			table.remove(stack)
		end
	end
	for _, line in ipairs(lines) do
		local text = line:match("^%s*(.-)%s*$")
		local indent = line:match("^(%s*)") or ""
		if text ~= "" and text ~= "end" and text ~= "else" and text:sub(1,7) ~= "elseif " and text:sub(1,6) ~= "until " then
			flushAbove(#indent + 1)
		end
		if text == "end" then
			while #stack > 0 and #stack[#stack][2] > #indent do
				out[#out+1] = stack[#stack][2] .. "end"; table.remove(stack)
			end
			if #stack > 0 and stack[#stack][2] == indent then table.remove(stack) end
			out[#out+1] = line
		elseif text == "else" or text:sub(1,7) == "elseif " then
			while #stack > 0 and #stack[#stack][2] > #indent do
				out[#out+1] = stack[#stack][2] .. "end"; table.remove(stack)
			end
			out[#out+1] = line
		elseif text:sub(1,6) == "until " then
			while #stack > 0 and #stack[#stack][2] > #indent do
				out[#out+1] = stack[#stack][2] .. "end"; table.remove(stack)
			end
			if #stack > 0 and stack[#stack][1] == "repeat" and stack[#stack][2] == indent then table.remove(stack) end
			out[#out+1] = line
		else
			out[#out+1] = line
			if text:match("^if%s") then
				if not text:match("%f[%a]end%s*$") then stack[#stack+1] = {"if", indent} end
			elseif text == "repeat" then stack[#stack+1] = {"repeat", indent}
			elseif text:match("^for%s.+%sdo$") or text:match("^while%s.+%sdo$") or text == "do"
				or text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]") then
				if not text:match("end%s*$") then stack[#stack+1] = {"block", indent} end
			end
		end
	end
	while #stack > 0 do
		out[#out+1] = stack[#stack][2] .. "end"; table.remove(stack)
	end
	return out
end

-- Drop unmatched `end` lines
local function dropUnmatchedEndLines(lines)
	local out = {}
	local stack = {}
	for _, line in ipairs(lines) do
		local text = line:match("^%s*(.-)%s*$")
		if text:match("^if%s") then
			if not text:match("%f[%a]end%s*$") then stack[#stack+1] = "if" end
			out[#out+1] = line
		elseif text == "repeat" then
			stack[#stack+1] = "repeat"; out[#out+1] = line
		elseif text:match("^for%s.+%sdo$") or text:match("^while%s.+%sdo$") or text == "do"
			or text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]") then
			if not text:match("end%s*$") then stack[#stack+1] = "block" end
			out[#out+1] = line
		elseif text:sub(1,6) == "until " then
			if #stack > 0 and stack[#stack] == "repeat" then table.remove(stack) end
			out[#out+1] = line
		elseif text == "end" then
			if #stack > 0 then table.remove(stack); out[#out+1] = line end
		else
			out[#out+1] = line
		end
	end
	return out
end

-- Conservative AST-like final renderer: validate block structure, then normalize.
local function renderLuaAstLines(lines, indentUnit)
	local stack = {}
	local function trim(s)
		return s:match("^%s*(.-)%s*$")
	end
	local function isSingleLineBlock(text)
		return text:match("^if%s+.+%s+then%s+.+%s+end$") ~= nil
			or text:match("^for%s+.+%s+do%s+.+%s+end$") ~= nil
			or text:match("^while%s+.+%s+do%s+.+%s+end$") ~= nil
	end
	local function opensBlock(text)
		if isSingleLineBlock(text) then return nil end
		if text:match("^if%s+.+%s+then$") then return "if" end
		if text:match("^for%s+.+%s+do$") or text:match("^while%s+.+%s+do$") or text == "do" then return "block" end
		if text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]") then
			if not text:match("end%s*$") then return "block" end
		end
		if text == "repeat" then return "repeat" end
		return nil
	end
	for _, line in ipairs(lines) do
		local text = trim(line)
		if text ~= "" and text:sub(1, 2) ~= "--" then
			if text == "else" or text:match("^elseif%s+.+%s+then$") then
				if #stack == 0 or stack[#stack] ~= "if" then
					return lines
				end
			elseif text == "end" then
				if #stack == 0 or stack[#stack] == "repeat" then
					return lines
				end
				table.remove(stack)
			elseif text:match("^until%s+") then
				if #stack == 0 or stack[#stack] ~= "repeat" then
					return lines
				end
				table.remove(stack)
			else
				local kind = opensBlock(text)
				if kind then stack[#stack+1] = kind end
			end
		end
	end
	if #stack ~= 0 then return lines end
	local rendered = normalizeLuaIndentation(lines, indentUnit)
	rendered = fixLoadbSkipBooleanAssignments(rendered)
	rendered = dropLoadbArtifacts(rendered)
	rendered = dropUnknownOpArtifacts(rendered)
	rendered = dropEmptyIfBlocks(rendered)
	return normalizeLuaIndentation(rendered, indentUnit)
end

-- Split register lifetimes for _rN names with multiple declarations
local function splitRegisterLifetimes(lines)
	if #lines == 0 then return lines end
	local bodyStart = 1
	for i, ln in ipairs(lines) do
		if ln:match("%S") then
			if ln:match("^%s*local%s+function%f[%W]") or ln:match("^%s*function%f[%W]") then
				bodyStart = i + 1
			else
				bodyStart = i
			end
			break
		end
	end
	local bodyEnd = #lines
	while bodyEnd > bodyStart do
		local t = lines[bodyEnd]:match("^%s*(.-)%s*$")
		if not t or t == "" then bodyEnd = bodyEnd - 1
		elseif t == "end" then bodyEnd = bodyEnd - 1; break
		else break end
	end
	if bodyEnd <= bodyStart then return lines end

	-- group declarations of _rN by name
	local declsByName = {}
	for i = bodyStart, bodyEnd do
		local ind, nm, rhs = lines[i]:match("^(%s*)local%s+(_r%d+)%s*=%s*(.+)%s*$")
		if nm and nm:match("^_r%d+$") then
			if not declsByName[nm] then declsByName[nm] = {} end
			declsByName[nm][#declsByName[nm]+1] = i
		end
	end

	local newLines = {}
	for _, ln in ipairs(lines) do newLines[#newLines+1] = ln end

	for name, idxs in pairs(declsByName) do
		if #idxs >= 2 then
			for k = 2, #idxs do
				local newName = name .. "_" .. tostring(k)
				local startI = idxs[k]
				local endI = k + 1 <= #idxs and idxs[k+1] - 1 or bodyEnd
				local pat = "%f[%a_]" .. luaPE(name) .. "%f[^%a_%d]"
				for j = startI, endI do
					if j == startI then
						local di, dn, drhs = newLines[j]:match("^(%s*)local%s+(_r%d+)%s*=%s*(.+)%s*$")
						if dn == name then
							local prevName = k == 2 and name or (name .. "_" .. tostring(k-1))
							local newRhs = drhs:gsub(pat, prevName)
							newLines[j] = di .. "local " .. newName .. " = " .. newRhs
						end
					else
						newLines[j] = newLines[j]:gsub(pat, newName)
					end
				end
			end
		end
	end
	return newLines
end

-- Inline `local _rN = E; return _rN` -> `return E`
local function inlineTrivialReturnLocals(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local inlined = false
		if i + 1 <= #lines then
			local li, ln2, lrhs = lines[i]:match("^(%s*)local%s+(_r%d+[_%d]*)%s*=%s*(.+)%s*$")
			local ri, rn2 = lines[i+1]:match("^(%s*)return%s+(_r%d+[_%d]*)%s*$")
			if li and ri and li == ri and ln2 == rn2 then
				out[#out+1] = ri .. "return " .. lrhs
				i = i + 2
				inlined = true
			end
		end
		if not inlined then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function isDecompilerTempName(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	return name:match("^_r%d+[_%d]*$") ~= nil
		or name:match("^_flag%d+[_%d]*$") ~= nil
		or name:match("^[%a_][%w_]*_result_%d+$") ~= nil
		or name:match("^[%a_][%w_]*_result$") ~= nil
		or name:match("^[%a_][%w_]*_value_%d+$") ~= nil
		or name:match("^[%a_][%w_]*_value$") ~= nil
		or name:match("^[%a_][%w_]*_entry_%d+$") ~= nil
		or name:match("^[%a_][%w_]*_entry$") ~= nil
end

local function inlineSingleUseTempLocals(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local inlined = false
		if i + 1 <= #lines then
			local declInd, tempName, expr = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
			local nextLine = lines[i + 1]
			if declInd and tempName and expr and isDecompilerTempName(tempName) and nextLine and nextLine:match("%S") then
				local nextInd = nextLine:match("^(%s*)") or ""
				local assignsTemp = nextLine:find("^%s*local%s+" .. luaPE(tempName) .. "%f[^%a_%d]")
					or nextLine:find("^%s*" .. luaPE(tempName) .. "%s*=")
				local leadingTempStatement = nextLine:find("^%s*" .. luaPE(tempName) .. "%s*[:%(%[%.]")
				if nextInd:sub(1, #declInd) == declInd
					and not assignsTemp
					and not leadingTempStatement
					and countIdentUsesOutsideStrings(nextLine, tempName) == 1
				then
					local usedLater = false
					for j = i + 2, #lines do
						local line = lines[j]
						local text = line:match("^%s*(.-)%s*$")
						local lineInd = line:match("^(%s*)") or ""
						if (text:sub(1, 15) == "local function " or text:sub(1, 9) == "function ") and #lineInd <= #declInd then
							break
						end
						if line:find("^%s*local%s+" .. luaPE(tempName) .. "%f[^%a_%d]") then
							break
						end
						if countIdentUsesOutsideStrings(line, tempName) > 0 then
							usedLater = true
							break
						end
					end
					if not usedLater then
						out[#out+1] = renameIdentOutsideStrings(nextLine, tempName, "(" .. expr .. ")")
						i = i + 2
						inlined = true
					end
				end
			end
		end
		if not inlined then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

-- Inline `local _rN = E; if [(not)] _rN then ... end` -> `if [(not)] E then ... end`
local function inlineTrivialConditionLocals(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local inlined = false
		if i + 1 <= #lines then
			local li, ln2, lrhs = lines[i]:match("^(%s*)local%s+(_r%d+[_%d]*)%s*=%s*(.+)%s*$")
			local ii, neg, in2
			-- Lua patterns do not support `?` after capture groups, so try
			-- each prefix variant explicitly.
			local ifPats = {
				{"^(%s*)if%s+(_r%d+[_%d]*)%s+then%s*$",               ""},
				{"^(%s*)if%s+not%s+(_r%d+[_%d]*)%s+then%s*$",         "not "},
				{"^(%s*)if%s+%(%s*(_r%d+[_%d]*)%s*%)%s+then%s*$",     ""},
				{"^(%s*)if%s+not%s+%(%s*(_r%d+[_%d]*)%s*%)%s+then%s*$", "not "},
			}
			for _, pair in ipairs(ifPats) do
				local a1, a2 = lines[i+1]:match(pair[1])
				if a1 then
					ii, in2, neg = a1, a2, pair[2]
					break
				end
			end
			if li and ii and li == ii and ln2 == in2 then
				-- check name not used inside the block
				local endPat = "^" .. luaPE(ii) .. "end%s*$"
				local endIdx = nil
				for j = i + 2, #lines do
					if lines[j]:match(endPat) then endIdx = j; break end
				end
				if endIdx then
					local usePat = "%f[%a_]" .. luaPE(ln2) .. "%f[^%a_%d]"
					local usedInside = false
					for j = i + 2, endIdx - 1 do
						if lines[j]:find(usePat) then usedInside = true; break end
					end
					local usedAfter = false
					for j = endIdx + 1, #lines do
						if lines[j]:find("^%s*local%s+" .. luaPE(ln2) .. "%f[^%a_%d]") then break end
						if lines[j]:find(usePat) then usedAfter = true; break end
					end
					if not usedInside and not usedAfter then
						local negStr = neg or ""
						out[#out+1] = ii .. "if " .. negStr .. lrhs .. " then"
						i = i + 2
						inlined = true
					end
				end
			end
		end
		if not inlined then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function fixFindBasePartFallbackReturns(lines)
	local out = {}
	for _, ln in ipairs(lines) do out[#out+1] = ln end
	for i = 1, math.max(0, #out - 4) do
		local findInd, partName, findExpr = out[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+:FindFirstChild%(.+%))%s*$")
		if findInd and partName and findExpr then
			local nilName = out[i + 1]:match("^%s*if%s+not%s+([%a_][%w_]*)%s+then%s+return%s+nil%s+end%s*$")
			local isaInd, checkName, isaName = out[i + 2]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*):IsA%(\"BasePart\"%)%s*$")
			local nilCheckName = out[i + 3]:match("^%s*if%s+not%s+([%a_][%w_]*)%s+then%s+return%s+nil%s+end%s*$")
			local retInd, retName = out[i + 4]:match("^(%s*)return%s+([%a_][%w_]*)%s*$")
			if nilName == partName
				and isaInd and checkName and isaName == partName
				and nilCheckName == checkName
				and retInd and retName == checkName
			then
				out[i + 2] = isaInd .. "local " .. checkName .. " = " .. partName .. ":IsA(\"BasePart\")"
				out[i + 4] = retInd .. "return " .. partName
			end
		end
	end
	return out
end

local function inlineTrivialCompareGuardLocals(lines)
	local out = {}
	local i = 1
	local ops = {"~=", "<=", ">=", "==", "<", ">"}
	while i <= #lines do
		local inlined = false
		if i + 1 <= #lines then
			local li, name, rhs = lines[i]:match("^(%s*)local%s+(_r%d+[_%d]*)%s*=%s*(.+)%s*$")
			if li and name and rhs then
				for _, op in ipairs(ops) do
					local ii, in2, cmp, ret = lines[i + 1]:match("^(%s*)if%s+(_r%d+[_%d]*)%s*" .. luaPE(op) .. "%s*(.-)%s+then%s+return(.-)%s+end%s*$")
					if ii and li == ii and name == in2 then
						local usePat = "%f[%a_]" .. luaPE(name) .. "%f[^%a_%d]"
						local usedLater = false
						for j = i + 2, #lines do
							if lines[j]:find(usePat) then usedLater = true break end
						end
						if not usedLater then
							out[#out+1] = ii .. "if " .. rhs .. " " .. op .. " " .. cmp .. " then return" .. (ret or "") .. " end"
							i = i + 2
							inlined = true
						end
						break
					end
				end
			end
		end
		if not inlined then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end
local function fixOrDefaultAssignments(lines)
	local work = {}
	for _, ln in ipairs(lines) do work[#work+1] = ln end
	local function trim(s)
		return s:match("^%s*(.-)%s*$")
	end
	local function startsWith(s, prefix)
		return s:sub(1, #prefix) == prefix
	end
	local function isNestedIndent(parent, child)
		return startsWith(child or "", parent or "")
	end
	local function matchDeclEmpty(ln)
		local ind, name = ln:match("^(%s*)local%s+([%a_][%w_]*)%s*$")
		if ind and isDecompilerTempName(name) then
			return ind, name
		end
		return nil, nil
	end
	local function matchIfNot(ln)
		local ind = ln:match("^(%s*)") or ""
		local text = trim(ln)
		local cond = text:match("^if%s+not%s+%((.-)%)%s+then$")
		if not cond then cond = text:match("^if%s+not%s+(.+)%s+then$") end
		if cond then return ind, cond end
		return nil, nil
	end
	local function matchAssignTmp(ln)
		local ind, name, rhs = ln:match("^(%s*)([%a_][%w_]*)%s*=%s*(.+)%s*$")
		if ind and rhs and isDecompilerTempName(name) then
			return ind, name, rhs
		end
		return nil, nil, nil
	end
	local function matchAssignTarget(ln)
		local ind, target, tmp = ln:match("^(%s*)(.-)%s*=%s*([%a_][%w_]*)%s*$")
		if ind and target and isDecompilerTempName(tmp) then
			target = target:match("^%s*(.-)%s*$")
			if simpleExpressionReceiver(target) then
				return ind, target, tmp
			end
		end
		return nil, nil, nil
	end
	local function matchLocalValue(ln)
		local ind, name, value = ln:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
		if ind and value and isDecompilerTempName(name) then
			return ind, name, value
		end
		return nil, nil, nil
	end
	local function nextFunctionBoundary(startIdx, indent)
		for j = startIdx, #work do
			local text = trim(work[j])
			local jind = work[j]:match("^(%s*)") or ""
			if (text:sub(1, 15) == "local function " or text:sub(1, 9) == "function ") and #jind <= #(indent or "") then
				return j - 1
			end
		end
		return #work
	end
	local function tempUseBetween(name, startIdx, endIdx)
		local usePat = "%f[%a_]" .. luaPE(name) .. "%f[^%a_%d]"
		for j = startIdx, endIdx do
			if work[j] and work[j]:find(usePat) then
				return true
			end
		end
		return false
	end
	for i = 1, #work - 3 do
		local ifInd, cond = matchIfNot(work[i])
		local tmpInd, tmp, rhs = matchAssignTmp(work[i + 1])
		local endInd = matchEnd(work[i + 2])
		local targetInd, target, targetTmp = matchAssignTarget(work[i + 3])
		if ifInd and tmpInd and tmp and rhs and endInd and targetInd and target and targetTmp
			and endInd == ifInd
			and targetInd == ifInd
			and startsWith(tmpInd, ifInd)
			and targetTmp == tmp
		then
			local declIdx = nil
			local declIndent = nil
			for j = i - 1, 1, -1 do
				local text = trim(work[j])
				local jind = work[j]:match("^(%s*)") or ""
				if (text:sub(1, 15) == "local function " or text:sub(1, 9) == "function ") and #jind <= #ifInd then
					break
				end
				local declInd, declTmp = matchDeclEmpty(work[j])
				if declInd and declTmp == tmp and isNestedIndent(declInd, ifInd) then
					declIdx = j
					declIndent = declInd
					break
				end
			end
			local searchEnd = nextFunctionBoundary(i + 4, declIndent or ifInd)
			local usedBefore = declIdx and tempUseBetween(tmp, declIdx + 1, i - 1) or false
			local usedAfter = tempUseBetween(tmp, i + 4, searchEnd)
			if not usedBefore and not usedAfter then
				if declIdx then
					work[declIdx] = ""
				end
				work[i] = ifInd .. target .. " = (" .. cond .. " or " .. rhs .. ")"
				work[i + 1] = ""
				work[i + 2] = ""
				work[i + 3] = ""
			end
		end
	end
	local out = {}
	local i = 1
	while i <= #work do
		if work[i] == "" then
			i = i + 1
		else
			local handled = false
			if i + 4 <= #work then
				local declInd, declTmp = matchDeclEmpty(work[i])
				local ifInd, cond = matchIfNot(work[i + 1])
				local tmpInd, tmp, rhs = matchAssignTmp(work[i + 2])
				local endInd = matchEnd(work[i + 3])
				local targetInd, target, targetTmp = matchAssignTarget(work[i + 4])
				if declInd and ifInd and tmpInd and tmp and rhs and endInd and targetInd and target and targetTmp
					and declInd == ifInd and ifInd == endInd and endInd == targetInd
					and startsWith(tmpInd, declInd)
					and declTmp == tmp and tmp == targetTmp
				then
					local usePat = "%f[%a_]" .. luaPE(tmp) .. "%f[^%a_%d]"
					local usedAfter = false
					for j = i + 5, #work do
						if work[j]:find("^%s*local%s+" .. luaPE(tmp) .. "%f[^%a_%d]") then break end
						if work[j]:find(usePat) then
							usedAfter = true
							break
						end
					end
					if not usedAfter then
						out[#out+1] = targetInd .. target .. " = (" .. cond .. " or " .. rhs .. ")"
						i = i + 5
						handled = true
					end
				end
			end
			if not handled and i + 1 <= #work then
				local localInd, localTmp, value = matchLocalValue(work[i])
				local targetInd, target, targetTmp = matchAssignTarget(work[i + 1])
				if localInd and localTmp and value and targetInd and target and targetTmp
					and localInd == targetInd
					and localTmp == targetTmp
				then
					out[#out+1] = targetInd .. target .. " = " .. value
					i = i + 2
					handled = true
				end
			end
			if not handled then
				out[#out+1] = work[i]
				i = i + 1
			end
		end
	end
	return out
end

local function simplifyEmptyTableDefaults(lines)
	local function trim(s)
		return s:match("^%s*(.-)%s*$")
	end
	local function matchSimpleIfNot(ln)
		local ind = ln:match("^(%s*)") or ""
		local text = trim(ln)
		local name = text:match("^if%s+not%s+%(([%a_][%w_]*)%)%s+then$")
		if not name then name = text:match("^if%s+not%s+([%a_][%w_]*)%s+then$") end
		if name then return ind, name end
		return nil, nil
	end
	local out = {}
	local i = 1
	while i <= #lines do
		local folded = false
		if i + 3 <= #lines then
			local ifInd, targetName = matchSimpleIfNot(lines[i])
			local tmpInd, tmpName = lines[i + 1]:match("^(%s*)(_r%d+[_%d]*)%s*=%s*%{%}%s*$")
			local endInd = matchEnd(lines[i + 2])
			local assignInd, assignTarget, assignTmp = lines[i + 3]:match("^(%s*)([%a_][%w_]*)%s*=%s*(_r%d+[_%d]*)%s*$")
			if ifInd and targetName and tmpInd and tmpName and endInd and assignInd and assignTarget and assignTmp
				and endInd == ifInd
				and assignInd == ifInd
				and tmpInd:sub(1, #ifInd) == ifInd
				and #tmpInd > #ifInd
				and assignTarget == targetName
				and assignTmp == tmpName
			then
				out[#out+1] = ifInd .. assignTarget .. " = (" .. assignTarget .. " or {})"
				i = i + 4
				folded = true
			end
		end
		if not folded then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	local cleaned = {}
	for idx, line in ipairs(out) do
		local _, name = line:match("^(%s*)local%s+(_r%d+[_%d]*)%s*=%s*%{%}%s*$")
		if not name then
			_, name = line:match("^(%s*)local%s+(_r%d+[_%d]*)%s*$")
		end
		local drop = false
		if name then
			local usePat = "%f[%a_]" .. luaPE(name) .. "%f[^%a_%d]"
			local used = false
			for j = idx + 1, #out do
				local text = trim(out[j])
				if out[j]:find("^%s*local%s+" .. luaPE(name) .. "%f[^%a_%d]") then break end
				if not text:match("^%-%-") and out[j]:find(usePat) then
					used = true
					break
				end
			end
			drop = not used
		end
		if not drop then
			cleaned[#cleaned+1] = line
		end
	end
	return cleaned
end

local function fixRefreshPreviousUserIdPattern(lines)
	-- DELETED: hardcoded to specific spectator player-list refresh patterns
	-- with the literal `.UserId` field. Violates AGENTS.md (no field-name
	-- hardcoding for individual bytecode patterns).
	return lines
end
local function renameFallbackIndexUpvalues(lines)
	if #lines == 0 then return lines end
	local prefix, upvalueText = lines[1]:match("^(.-%-%-%s+upvalues:%s+)(.+)$")
	if not prefix or not upvalueText then return lines end
	local upvalues = {}
	for name in upvalueText:gmatch("[^,%s]+") do
		upvalues[#upvalues+1] = name
	end
	if #upvalues == 0 then return lines end
	local used = {}
	for _, name in ipairs(upvalues) do used[name] = true end
	local params = lines[1]:match("%((.-)%)")
	if params then
		for name in params:gmatch("[A-Za-z_][A-Za-z0-9_]*") do used[name] = true end
	end
	for _, line in ipairs(lines) do
		if not line:match("^%s*local%s+function%f[^%w_]") then
			local decl = line:match("^%s*local%s+([^=]+)")
			if decl then
				for name in decl:gmatch("[A-Za-z_][A-Za-z0-9_]*") do used[name] = true end
			end
		end
	end
	local renames = {}
	for _, name in ipairs(upvalues) do
		if name:match("^_%d+$") then
			local isIndex = false
			local bracketPat = "%[%s*" .. luaPE(name) .. "%s*%]"
			for i = 2, #lines do
				if lines[i]:find(bracketPat) then
					isIndex = true
					break
				end
			end
			if isIndex then
				local candidate = "index"
				local suffix = 2
				while used[candidate] and candidate ~= name do
					candidate = "index_" .. tostring(suffix)
					suffix = suffix + 1
				end
				used[candidate] = true
				renames[name] = candidate
			end
		end
	end
	if next(renames) == nil then return lines end
	local out = {}
	for i, line in ipairs(lines) do
		local newLine = line
		if i == 1 then
			local rewritten = {}
			for _, name in ipairs(upvalues) do rewritten[#rewritten+1] = renames[name] or name end
			newLine = prefix .. table.concat(rewritten, ", ")
		else
			for oldName, newName in pairs(renames) do
				if newLine:match("^%s*%-%-.*captures:") then
					newLine = newLine:gsub(identPat(oldName), newName)
				else
					newLine = renameIdentOutsideStrings(newLine, oldName, newName)
				end
			end
		end
		out[#out+1] = newLine
	end
	return out
end

local function hoistRepeatedLocals(lines)
	if #lines == 0 then return lines end
	-- Helper: find the start/end of the smallest enclosing function block at line idx.
	-- Returns startIdx (idx of `function ...`) + 1, endIdx (idx of matching `end`).
	-- Returns 1, #lines for module-level scope.
	local function enclosingFnRange(idx)
		local depth = 0
		local startIdx = nil
		-- Scan backward for the nearest unmatched `function`
		for i = idx - 1, 1, -1 do
			local text = lines[i]:match("^%s*(.-)%s*$") or ""
			if text == "end" then
				depth = depth + 1
			elseif text:match("^function%f[^%w_]")
				or text:match("^local%s+function%f[^%w_]")
				or text:match("=%s*function%(")
				or text:match("=%s*function%s+%(")
			then
				if depth == 0 then
					startIdx = i
					break
				end
				depth = depth - 1
			end
		end
		if not startIdx then return 1, #lines end
		-- Scan forward from startIdx for matching `end`
		local fnInd = lines[startIdx]:match("^(%s*)") or ""
		for j = startIdx + 1, #lines do
			local jInd = lines[j]:match("^(%s*)") or ""
			local jText = lines[j]:match("^%s*(.-)%s*$") or ""
			if jInd == fnInd and jText == "end" then
				return startIdx + 1, j - 1
			end
		end
		return startIdx + 1, #lines
	end
	local bodyStart = 1
	for i, line in ipairs(lines) do
		if line:match("%S") then
			local text = line:match("^%s*(.-)%s*$")
			if text:match("^(local%s+)?function%f[^%w_]") then
				bodyStart = i + 1
			elseif text:match("^%-%-%s+main%s+chunk") then
				bodyStart = i + 1
			else
				bodyStart = i
			end
			break
		end
	end
	local bodyEnd = #lines
	while bodyEnd >= bodyStart do
		local text = lines[bodyEnd]:match("^%s*(.-)%s*$")
		if text == "" then
			bodyEnd = bodyEnd - 1
		elseif text == "end" then
			bodyEnd = bodyEnd - 1
			break
		else
			break
		end
	end
	if bodyEnd < bodyStart then return lines end
	-- Group declarations by function-scope: each declaration belongs to its
	-- nearest enclosing function (or the module body if none).
	-- For each scope, hoist same-name locals declared in different branches
	-- to the start of THAT scope, not the module top.
	-- Build a per-scope declarations map.
	local scopeKey = function(s, e) return tostring(s) .. ":" .. tostring(e) end
	local scopeRanges = {}  -- scopeKey -> {startIdx=, endIdx=, declarations={name->[{idx,indent,expr}]}, order={}}
	for i = bodyStart, bodyEnd do
		local ind, name, expr = lines[i]:match("^(%s*)local%s+([A-Za-z_][A-Za-z0-9_]*)%s*=%s*(.+)%s*$")
		if ind and name and not lines[i]:match("^%s*local%s+function%f[^%w_]") then
			local s, e = enclosingFnRange(i)
			local key = scopeKey(s, e)
			local sc = scopeRanges[key]
			if not sc then
				sc = { startIdx = s, endIdx = e, declarations = {}, order = {} }
				scopeRanges[key] = sc
			end
			if not sc.declarations[name] then
				sc.declarations[name] = {}
				sc.order[#sc.order+1] = name
			end
			sc.declarations[name][#sc.declarations[name]+1] = { idx = i, indent = ind, expr = expr }
		end
	end
	-- Determine what to hoist per scope (using original indices into `lines`)
	local hoistsByScope = {}  -- list of { startIdx, names, indent, declToReassign={idx,indent,name,expr}}
	for _, sc in pairs(scopeRanges) do
		local toHoist = {}
		for name, items in pairs(sc.declarations) do
			if #items > 1 then toHoist[name] = true end
		end
		for name, items in pairs(sc.declarations) do
			if not toHoist[name] and #items == 1 then
				local decl = items[1]
				local declIndent = #decl.indent
				local blockEnd = sc.endIdx + 1
				for j = decl.idx + 1, sc.endIdx do
					if lines[j]:match("%S") then
						local ind = lines[j]:match("^(%s*)") or ""
						if #ind < declIndent then
							blockEnd = j
							break
						end
					end
				end
				if blockEnd <= sc.endIdx then
					local pat = identPat(name)
					for j = blockEnd, sc.endIdx do
						if lines[j]:find(pat) then
							toHoist[name] = true
							break
						end
					end
				end
			end
		end
		if next(toHoist) ~= nil then
			-- Determine indent at the start of this scope
			local scopeIndent = ""
			for i = sc.startIdx, sc.endIdx do
				if lines[i]:match("%S") then
					scopeIndent = lines[i]:match("^(%s*)") or ""
					break
				end
			end
			local hoistNames = {}
			for _, name in ipairs(sc.order) do
				if toHoist[name] then hoistNames[#hoistNames+1] = name end
			end
			local reassignDecls = {}
			for name, items in pairs(sc.declarations) do
				if toHoist[name] then
					for _, decl in ipairs(items) do
						reassignDecls[#reassignDecls+1] = { idx = decl.idx, line = decl.indent .. name .. " = " .. decl.expr }
					end
				end
			end
			hoistsByScope[#hoistsByScope+1] = {
				startIdx = sc.startIdx,
				names = hoistNames,
				indent = scopeIndent,
				reassign = reassignDecls,
			}
		end
	end
	if #hoistsByScope == 0 then return lines end
	-- Apply: first replace all `local X = E` with `X = E` (same index space).
	local out = {}
	for i, line in ipairs(lines) do out[i] = line end
	for _, h in ipairs(hoistsByScope) do
		for _, r in ipairs(h.reassign) do
			out[r.idx] = r.line
		end
	end
	-- Then insert hoisted declarations in descending startIdx order to keep indices valid.
	table.sort(hoistsByScope, function(a, b) return a.startIdx > b.startIdx end)
	for _, h in ipairs(hoistsByScope) do
		for i = #h.names, 1, -1 do
			table.insert(out, h.startIdx, h.indent .. "local " .. h.names[i])
		end
	end
	return out
end

local function coalesceAlternativeFinds(lines)
	if #lines == 0 then return lines end
	local function findBodySpan(lns)
		local bodyStart = 1
		for i, line in ipairs(lns) do
			if line:match("%S") then
				local text = line:match("^%s*(.-)%s*$")
				if text:match("^(local%s+)?function%f[^%w_]") then
					bodyStart = i + 1
				elseif text:match("^%-%-%s+main%s+chunk") then
					bodyStart = i + 1
				else
					bodyStart = i
				end
				break
			end
		end
		local bodyEnd = #lns
		while bodyEnd >= bodyStart do
			local text = lns[bodyEnd]:match("^%s*(.-)%s*$")
			if text == "" then
				bodyEnd = bodyEnd - 1
			elseif text == "end" then
				bodyEnd = bodyEnd - 1
				break
			else
				break
			end
		end
		return bodyStart, bodyEnd
	end
	local function findIfAssignBlock(lns, startIdx, endIdx, varName)
		local j = startIdx
		while j <= endIdx and not lns[j]:match("%S") do j = j + 1 end
		if j > endIdx then return nil end
		local inlineInd, cond, target = lns[j]:match("^(%s*)if%s+(.+)%s+then%s+([A-Za-z_][A-Za-z0-9_]*)%s*=%s*.+%s+end%s*$")
		if inlineInd and target == varName then
			return { startIdx = j, endIdx = j, cond = cond }
		end
		local ifInd, openCond = lns[j]:match("^(%s*)if%s+(.+)%s+then%s*$")
		if not ifInd then return nil end
		local j2 = j + 1
		while j2 <= endIdx and not lns[j2]:match("%S") do j2 = j2 + 1 end
		if j2 > endIdx then return nil end
		local _assignInd, assignTarget = lns[j2]:match("^(%s*)([A-Za-z_][A-Za-z0-9_]*)%s*=%s*.+%s*$")
		if assignTarget ~= varName then return nil end
		local j3 = j2 + 1
		while j3 <= endIdx and not lns[j3]:match("%S") do j3 = j3 + 1 end
		if j3 > endIdx then return nil end
		local endInd = lns[j3]:match("^(%s*)end%s*$")
		if endInd ~= ifInd then return nil end
		return { startIdx = j, endIdx = j3, cond = openCond }
	end
	local function tryCoalesce(lns)
		local bodyStart, bodyEnd = findBodySpan(lns)
		if bodyEnd < bodyStart then return nil end
		local decls = {}
		local k = bodyStart
		while k <= bodyEnd do
			if not lns[k]:match("%S") then
				k = k + 1
			else
				local _ind, name = lns[k]:match("^(%s*)local%s+([A-Za-z_][A-Za-z0-9_]*)%s*$")
				if not name then break end
				decls[#decls+1] = { idx = k, name = name }
				k = k + 1
			end
		end
		if #decls < 2 then return nil end
		for di = 1, #decls - 1 do
			local nameA = decls[di].name
			local nameB = decls[di + 1].name
			local assignA = nil
			for j = k, bodyEnd do
				local cand = findIfAssignBlock(lns, j, bodyEnd, nameA)
				if cand and cand.startIdx == j then
					assignA = cand
					break
				end
			end
			if assignA then
				local j2 = assignA.endIdx + 1
				while j2 <= bodyEnd and not lns[j2]:match("%S") do j2 = j2 + 1 end
				local assignB = findIfAssignBlock(lns, j2, bodyEnd, nameB)
				if assignB then
					local cond = assignB.cond:match("^%s*(.-)%s*$")
					if cond:match("^not%s*%(%s*" .. luaPE(nameA) .. "%s*%)%s*$") or cond:match("^not%s+" .. luaPE(nameA) .. "%s*$") then
						local otherAssign = false
						local assignPat = "^%s*" .. luaPE(nameB) .. "%s*="
						for r = bodyStart, bodyEnd do
							if r ~= decls[di + 1].idx and not (assignB.startIdx <= r and r <= assignB.endIdx) then
								if lns[r]:find(assignPat) then
									otherAssign = true
									break
								end
							end
						end
						if not otherAssign then
							local newLines = {}
							for i, line in ipairs(lns) do newLines[i] = line end
							newLines[decls[di + 1].idx] = ""
							for r = bodyStart, bodyEnd do
								if r ~= decls[di + 1].idx then
									newLines[r] = renameIdentOutsideStrings(newLines[r], nameB, nameA)
								end
							end
							local collapsed = {}
							local prevBlank = false
							for _, line in ipairs(newLines) do
								if line == "" then
								elseif not line:match("%S") then
									if not prevBlank then
										collapsed[#collapsed+1] = line
										prevBlank = true
									end
								else
									collapsed[#collapsed+1] = line
									prevBlank = false
								end
							end
							return collapsed
						end
					end
				end
			end
		end
		return nil
	end
	local cur = lines
	for _ = 1, 8 do
		local nxt = tryCoalesce(cur)
		if not nxt then return cur end
		cur = nxt
	end
	return cur
end

local function renameTempFindFirstChildDynamic(lines)
	local out = {}
	for _, ln in ipairs(lines) do out[#out+1] = ln end
	local existing = {}
	for _, ln in ipairs(out) do
		local name = ln:match("%f[%a_]local%s+([%a_][%w_]*)%f[^%a_%d]")
		if name then existing[name] = true end
	end
	for i, line in ipairs(lines) do
		local old, arg = line:match("^%s*local%s+(_r%d+[_%d]*)%s*=%s*.+:FindFirstChild%((.+)%)%s*$")
		if old and arg then
			arg = arg:match("^%s*(.-)%s*$")
			local hint = arg:match("%.([%a_][%w_]*)$")
			if not hint and isValidIdent(arg) then hint = arg end
			hint = hint and cleanIdent(hint) or nil
			if hint and isValidIdent(hint) then
				local newName = hint
				if existing[newName] and newName ~= old then
					local suffix = 2
					while existing[newName .. "_" .. tostring(suffix)] do suffix = suffix + 1 end
					newName = newName .. "_" .. tostring(suffix)
				end
				existing[newName] = true
				local usePat = "%f[%a_]" .. luaPE(old) .. "%f[^%a_%d]"
				local endIdx = math.min(#out, i + 11)
				for j = i, endIdx do
					if j > i and out[j]:find("%f[%a_]local%s+" .. luaPE(old) .. "%f[^%a_%d]") then break end
					if out[j]:find(usePat) then
						out[j] = out[j]:gsub(usePat, newName)
					end
				end
			end
		end
	end
	return out
end

local function renameTempByCommonAssignedField(lines)
	local out = {}
	for _, ln in ipairs(lines) do out[#out+1] = ln end
	local preferred = {
		Visible = "visible",
		Enabled = "enabled",
		Transparency = "transparency",
		Size = "size",
		Position = "position",
		CFrame = "cframe",
		Color = "color",
		Text = "text",
	}
	local existing = {}
	for _, ln in ipairs(lines) do
		local name = ln:match("%f[%a_]local%s+([%a_][%w_]*)%f[^%a_%d]")
		if name then existing[name] = true end
	end
	for i, line in ipairs(lines) do
		local old = line:match("^%s*local%s+(_r%d+[_%d]*)%s*=%s*.+%s*$")
		if old then
			local fields = {}
			local lastUse = i
			local valid = true
			for j = i + 1, math.min(#lines, i + 7) do
				if lines[j]:find("%f[%a_]local%s+" .. luaPE(old) .. "%f[^%a_%d]") then break end
				local usePat = "%f[%a_]" .. luaPE(old) .. "%f[^%a_%d]"
				if lines[j]:find(usePat) then
					local field, rhs = lines[j]:match("^%s*[%a_][%w_%.:%[%]\"']*%.([%a_][%w_]*)%s*=%s*(_r%d+[_%d]*)%s*$")
					if not field or rhs ~= old then
						valid = false
						break
					end
					fields[#fields+1] = field
					lastUse = j
				elseif #fields > 0 then
					break
				end
			end
			if valid and #fields > 0 then
				local same = true
				for j = 2, #fields do
					if fields[j] ~= fields[1] then same = false break end
				end
				if same then
					local newName = preferred[fields[1]] or cleanIdent(fields[1])
					if newName and isValidIdent(newName) then
						if existing[newName] and newName ~= old then
							local suffix = 2
							while existing[newName .. "_" .. tostring(suffix)] do suffix = suffix + 1 end
							newName = newName .. "_" .. tostring(suffix)
						end
						existing[newName] = true
						local usePat = "%f[%a_]" .. luaPE(old) .. "%f[^%a_%d]"
						for j = i, lastUse do
							out[j] = out[j]:gsub(usePat, newName)
						end
					end
				end
			end
		end
	end
	return out
end

local function renameLocalTableByAssignment(lines)
	local out = {}
	for _, ln in ipairs(lines) do out[#out+1] = ln end
	local existing = {}
	for _, ln in ipairs(lines) do
		local name = ln:match("%f[%a_]local%s+([%a_][%w_]*)%f[^%a_%d]")
		if name then existing[name] = true end
	end
	for i, line in ipairs(lines) do
		local ind, old, tableExpr = line:match("^(%s*)local%s+(_r%d+[_%d]*)%s*=%s*(%{.+%})%s*$")
		local hasSignalField = false
		if tableExpr then
			for _, field in ipairs({"Weld", "OriginalC0", "SpinRate", "IsFiring", "CurrentPosition", "TargetPosition", "Model", "Animator"}) do
				if tableExpr:find("%f[%a_]" .. field .. "%f[^%a_%d]%s*=") then
					hasSignalField = true
					break
				end
			end
		end
		if ind and old and tableExpr and hasSignalField then
			local assignIdx = nil
			for j = i + 1, math.min(#lines, i + 11) do
				local rhs = lines[j]:match("^%s*[%a_][%w_]*%b[]%s*=%s*(_r%d+[_%d]*)%s*$")
				if rhs == old then
					assignIdx = j
					break
				end
				local rhs2 = lines[j]:match("^%s*[%a_][%w_]*%s*=%s*(_r%d+[_%d]*)%s*$")
				if rhs2 == old then
					assignIdx = j
					break
				end
			end
			if assignIdx then
				local newName = "data"
				if existing[newName] then
					local suffix = 2
					while existing[newName .. "_" .. tostring(suffix)] do suffix = suffix + 1 end
					newName = newName .. "_" .. tostring(suffix)
				end
				existing[newName] = true
				local usePat = "%f[%a_]" .. luaPE(old) .. "%f[^%a_%d]"
				for j = i, assignIdx do
					out[j] = out[j]:gsub(usePat, newName)
				end
			end
		end
	end
	return out
end

-- Fold table hash initializers: `local t = {}; t.A = x; t.B = y;` -> `local t = { A = x, B = y }`
-- Also handles interleaved `local TEMP = <expr>; t.A = TEMP` by inlining TEMP if single-use.
local function foldTableHashInitializers(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local folded = false
		local ind, nm = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*%{%s*%}%s*$")
		local initialBody = nil
		if not nm then
			-- also accept DUPTABLE-style pre-populated literal: local NM = { K1 = ..., K2 = ..., ... }
			local ind2, nm2, body2 = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*%{%s*(.-)%s*%}%s*$")
			if nm2 and body2 and body2 ~= "" then
				ind = ind2
				nm = nm2
				initialBody = body2
			end
		end
		if nm then
			local pairs_ = {}
			local seenKeys = {}
			local pendingLocals = {} -- map name -> {rhs, lineIdx}
			local mutatedLocals = {} -- set of names mutated since declaration
			-- seed pairs from initial body if present (preserves order)
			if initialBody then
				-- crude split at top-level commas
				local function splitTop(s)
					local parts = {}
					local buf = {}
					local depth = 0
					local inq = nil
					for ci = 1, #s do
						local ch = s:sub(ci,ci)
						if inq then
							buf[#buf+1] = ch
							if ch == inq then inq = nil end
						elseif ch == '"' or ch == "'" then inq = ch; buf[#buf+1] = ch
						elseif ch == "(" or ch == "[" or ch == "{" then depth = depth+1; buf[#buf+1] = ch
						elseif ch == ")" or ch == "]" or ch == "}" then depth = depth-1; buf[#buf+1] = ch
						elseif ch == "," and depth == 0 then
							parts[#parts+1] = table.concat(buf):match("^%s*(.-)%s*$"); buf = {}
						else buf[#buf+1] = ch end
					end
					if #buf > 0 then parts[#parts+1] = table.concat(buf):match("^%s*(.-)%s*$") end
					return parts
				end
				for _, kvStr in ipairs(splitTop(initialBody)) do
					local k, v = kvStr:match("^([%a_][%w_]*)%s*=%s*(.+)$")
					if k and v then
						seenKeys[k] = #pairs_ + 1
						pairs_[#pairs_+1] = { key = k, rhs = v }
					else
						-- bail if any non-key=value entry (e.g., array element)
						pairs_ = {}
						seenKeys = {}
						initialBody = nil
						break
					end
				end
			end
			local consumedLines = {} -- set of line indices consumed by the fold (to skip)
			local fieldAssignLines = {} -- set of line indices that are nm.X = ... (handled inside fold)
			local lastUsedJ = i
			-- Track simple-identifier field RHS values that were NOT inlined (used by name).
			-- If any such variable is mutated after its field assignment, the fold would evaluate
			-- the variable AFTER the mutation (wrong semantics), so we must abort the fold.
			local lockedRhsNames = {}
			local lockedRhsMutated = false
			local j = i + 1
			while j <= #lines do
				local fieldKey, fieldRhs = lines[j]:match("^" .. luaPE(ind) .. luaPE(nm) .. "%.([%a_][%w_]*)%s*=%s*(.+)%s*$")
				if fieldKey then
					if fieldRhs:find(identPat(nm)) then break end
					local rhsTrim = fieldRhs:match("^(.-)%s*$")
					-- if rhsTrim is exactly a name from pendingLocals AND not mutated, inline its rhs
					local pl = pendingLocals[rhsTrim]
					local wasInlined = false
					if pl and not mutatedLocals[rhsTrim] then
						local origName = rhsTrim
						rhsTrim = pl.rhs
						consumedLines[pl.lineIdx] = true
						pendingLocals[origName] = nil
						wasInlined = true
					end
					-- If rhsTrim is a plain identifier and was NOT inlined, lock it:
					-- a later mutation of this variable would make the fold semantically wrong.
					if not wasInlined and rhsTrim:match("^[%a_][%w_]*$") then
						lockedRhsNames[rhsTrim] = true
					end
					local existingIdx = seenKeys[fieldKey]
					if existingIdx then
						-- update existing key only if previous value was nil (DUPTABLE placeholder)
						if pairs_[existingIdx].rhs ~= "nil" then break end
						pairs_[existingIdx].rhs = rhsTrim
					else
						seenKeys[fieldKey] = #pairs_ + 1
						pairs_[#pairs_+1] = { key = fieldKey, rhs = rhsTrim }
					end
					fieldAssignLines[j] = true
					lastUsedJ = j
					j = j + 1
				else
					-- detect mutation of pending locals: <NAME>.X = ... or <NAME>[...] = ...
					local mutName = lines[j]:match("^" .. luaPE(ind) .. "([%a_][%w_]*)[%.%[]")
					if mutName and pendingLocals[mutName] then
						mutatedLocals[mutName] = true
					end
					-- also detect bare assignment mutations inside nested blocks (any deeper indentation)
					-- e.g. "    X = nil" or "    X = val" inside an if/else block
					if not mutName then
						local bareName = lines[j]:match("^%s+([%a_][%w_]*)%s*=[^=~<>]")
						if bareName and not lines[j]:match("^%s+local%s") then
							if pendingLocals[bareName] then
								mutatedLocals[bareName] = true
							end
							-- abort fold if a locked (non-inlined) field RHS variable is mutated
							if lockedRhsNames[bareName] then
								lockedRhsMutated = true
								break
							end
						end
						-- also detect "local X = nil" (re-declaration shadowing outer pendingLocal)
						-- LOADNIL can emit "local X = nil" when the startpc aligns; this shadows the outer local
						local shadowNilName = lines[j]:match("^%s+local%s+([%a_][%w_]*)%s*=%s*nil%s*$")
						if shadowNilName then
							if pendingLocals[shadowNilName] then
								mutatedLocals[shadowNilName] = true
							end
							-- also abort fold if a locked RHS name is shadow-nil'd
							if lockedRhsNames[shadowNilName] then
								lockedRhsMutated = true
								break
							end
						end
					end
					-- accept interleaved local declarations that don't reference nm
					local declName, declRhs = lines[j]:match("^" .. luaPE(ind) .. "local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
					if declName and declName ~= nm and not declRhs:find(identPat(nm)) then
						-- Only add to pendingLocals if not already marked as mutated
						if not mutatedLocals[declName] then
							pendingLocals[declName] = { rhs = declRhs:match("^(.-)%s*$"), lineIdx = j }
						end
						j = j + 1
					else
						-- accept any other passthrough line that does NOT reference nm
						if lines[j]:find(identPat(nm)) then break end
						j = j + 1
					end
				end
			end
			-- trim trailing passthrough lines beyond last folded field
			j = lastUsedJ + 1
			-- only fold if we actually consumed at least one nm.X = ... line (otherwise it's a no-op rewrap)
			-- also abort if any field's non-inlined RHS variable was mutated after the field assignment
			local meaningful = lastUsedJ > i and #pairs_ >= 2 and not lockedRhsMutated
			if meaningful then
				-- Output any unconsumed lines (passthrough) in order
				for k = i + 1, j - 1 do
					if not consumedLines[k] and not fieldAssignLines[k] then
						out[#out+1] = lines[k]
					end
				end
				local parts = {}
				for _, kv in ipairs(pairs_) do
					parts[#parts+1] = kv.key .. " = " .. kv.rhs
				end
				out[#out+1] = ind .. "local " .. nm .. " = { " .. table.concat(parts, ", ") .. " }"
				i = j
				folded = true
			end
		end
		if not folded then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

-- Fold table array initializers: `local t = {}; t[1],t[2]=a,b` -> `local t = {a,b}`
local function foldTableArrayInitializers(lines)
	local out = {}
	local function splitTopCommas(s)
		local parts = {}
		local buf = {}
		local depth2 = 0
		local inq = nil
		for ci = 1, #s do
			local ch = s:sub(ci,ci)
			if inq then
				buf[#buf+1] = ch
				if ch == inq then inq = nil end
			elseif ch == '"' or ch == "'" then inq = ch; buf[#buf+1] = ch
			elseif ch == "(" or ch == "[" or ch == "{" then depth2 = depth2+1; buf[#buf+1] = ch
			elseif ch == ")" or ch == "]" or ch == "}" then depth2 = depth2-1; buf[#buf+1] = ch
			elseif ch == "," and depth2 == 0 then
				parts[#parts+1] = table.concat(buf):match("^%s*(.-)%s*$"); buf = {}
			else buf[#buf+1] = ch end
		end
		parts[#parts+1] = table.concat(buf):match("^%s*(.-)%s*$")
		return parts
	end
	local function usedLater(name, startIdx)
		local pat = identPat(name)
		for li = startIdx, #lines do
			if lines[li]:find(pat) then return true end
		end
		return false
	end
	local i = 1
	while i <= #lines do
		local folded = false
		local ind, nm = lines[i]:match("^(%s*)local%s+([%a_][%a_%d]*)%s*=%s*%{%}%s*$")
		if nm and i + 1 <= #lines then
			local pending = {}
			local consumed = {}
			local j = i + 1
			local lhsStr, rhsStr
			local assignIdx
			while j <= #lines do
				lhsStr, rhsStr = lines[j]:match("^" .. luaPE(ind) .. "(.+)%s*=%s*(.+)%s*$")
				if lhsStr and rhsStr and lhsStr:find(luaPE(nm) .. "%[") then
					assignIdx = j
					break
				end
				local declName, declRhs = lines[j]:match("^" .. luaPE(ind) .. "local%s+([%a_][%w_]*)%s*=%s*(.+)%s*$")
				if declName and declName ~= nm and not declRhs:find(identPat(nm)) then
					pending[declName] = { rhs = declRhs:match("^(.-)%s*$"), lineIdx = j }
					j = j + 1
				else
					break
				end
			end
			if assignIdx and lhsStr and rhsStr then
				local lhsParts = splitTopCommas(lhsStr)
				local rhsParts = splitTopCommas(rhsStr)
				local ok = #lhsParts == #rhsParts
				local indexes = {}
				for _, part in ipairs(lhsParts) do
					local idx = part:match("^" .. luaPE(nm) .. "%[(%d+)%]$")
					if not idx then ok = false; break end
					indexes[#indexes+1] = tonumber(idx)
				end
				if ok and #indexes > 0 then
					local seq = true
					for k = 1, #indexes do
						if indexes[k] ~= k then seq = false; break end
					end
					if seq then
						for k, rhs in ipairs(rhsParts) do
							local pl = pending[rhs]
							if pl and not usedLater(rhs, assignIdx + 1) then
								rhsParts[k] = pl.rhs
								consumed[pl.lineIdx] = true
							end
						end
						for lineIdx = i + 1, assignIdx - 1 do
							if not consumed[lineIdx] then
								out[#out+1] = lines[lineIdx]
							end
						end
						out[#out+1] = ind .. "local " .. nm .. " = {" .. table.concat(rhsParts, ", ") .. "}"
						i = assignIdx + 1
						folded = true
					end
				end
			end
		end
		if not folded then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function fixGuardReturnBeforeFallbackLocal(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local ind, guardName = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*.+$")
		local retName = nil
		if guardName and i + 2 <= #lines then
			retName = lines[i + 1]:match("^" .. luaPE(ind) .. "if%s+" .. luaPE(guardName) .. "%s+then%s+return%s+([%a_][%w_]*)%s+end%s*$")
			if retName and retName ~= guardName then
				local declName = lines[i + 2]:match("^" .. luaPE(ind) .. "local%s+([%a_][%w_]*)%s*=")
				if declName == retName then
					out[#out+1] = lines[i]
					out[#out+1] = ind .. "if " .. guardName .. " then return " .. guardName .. " end"
					i = i + 2
					continue
				end
			end
		end
		out[#out+1] = lines[i]
		i = i + 1
	end
	return out
end

local function fixNilPhiGuardAssignments(lines, indentUnit)
	local out = {}
	local i = 1
	while i <= #lines do
		local fixed = false
		if i + 5 <= #lines then
			local ind = matchIfOpen(lines[i])
			local thenAssignInd, thenTarget, thenExpr = lines[i + 1]:match("^(%s*)([%a_][%w_]*)%s*=%s*(.+)%s*$")
			local elseInd = lines[i + 2]:match("^(%s*)else%s*$")
			local elseAssignInd, elseTarget = lines[i + 3]:match("^(%s*)([%a_][%w_]*)%s*=%s*nil%s*$")
			local endInd = matchEnd(lines[i + 4])
			local guardIndent, guardName = lines[i + 5]:match("^(%s*)if%s+not%s+%(([%a_][%w_]*)%)%s+then%s*$")
			if not guardName then
				guardIndent, guardName = lines[i + 5]:match("^(%s*)if%s+not%s+([%a_][%w_]*)%s+then%s*$")
			end
			if ind
				and thenAssignInd == ind .. indentUnit
				and elseInd == ind
				and elseAssignInd == ind .. indentUnit
				and endInd == ind
				and guardIndent == ind
				and elseTarget == guardName
				and thenTarget ~= guardName
				and not thenExpr:find(identPat(guardName))
			then
				out[#out + 1] = lines[i]
				out[#out + 1] = thenAssignInd .. guardName .. " = " .. thenExpr
				out[#out + 1] = lines[i + 2]
				out[#out + 1] = lines[i + 3]
				out[#out + 1] = lines[i + 4]
				out[#out + 1] = lines[i + 5]
				i = i + 6
				fixed = true
			end
		end
		if not fixed then
			out[#out + 1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function fixGuardedLookupFallbackReturn(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		if i + 3 <= #lines then
			local ind, baseName, fallback1 = lines[i]:match("^(%s*)if%s+not%s+([%a_][%w_]*)%s+then%s+return%s+(.+)%s+end%s*$")
			local ind2, fieldExpr, fallback2 = lines[i + 1]:match("^(%s*)if%s+not%s+([%a_][%w_]*%.[%a_][%w_]*)%s+then%s+return%s+(.+)%s+end%s*$")
			if ind and ind2 == ind and fieldExpr and fieldExpr:match("^" .. luaPE(baseName) .. "%.") then
				local keyPart, fallback3 = lines[i + 2]:match("^" .. luaPE(ind) .. "if%s+" .. luaPE(fieldExpr) .. "(%b[])%s+then%s+return%s+(.+)%s+end%s*$")
				local ind4, fallback4 = lines[i + 3]:match("^(%s*)return%s+(.+)%s*$")
				if keyPart
					and ind4 == ind
					and fallback1 == fallback2
					and fallback2 == fallback3
					and fallback3 == fallback4
				then
					out[#out+1] = lines[i]
					out[#out+1] = lines[i + 1]
					out[#out+1] = ind .. "return " .. fieldExpr .. keyPart .. " or " .. fallback1
					i = i + 4
					continue
				end
			end
		end
		out[#out+1] = lines[i]
		i = i + 1
	end
	return out
end

local function fixBareMethodReferences(lines)
	local out = {}
	for _, line in ipairs(lines) do
		if matchLbl(line) then
			out[#out+1] = line
			continue
		end
		local res = {}
		local quote = nil
		local i = 1
		while i <= #line do
			local ch = line:sub(i, i)
			if quote then
				res[#res+1] = ch
				if ch == "\\" and i + 1 <= #line then
					res[#res+1] = line:sub(i + 1, i + 1)
					i = i + 2
				else
					if ch == quote then quote = nil end
					i = i + 1
				end
			elseif ch == '"' or ch == "'" then
				quote = ch
				res[#res+1] = ch
				i = i + 1
			elseif ch == "-" and line:sub(i + 1, i + 1) == "-" then
				res[#res+1] = line:sub(i)
				break
			elseif ch == ":" and line:sub(i - 1, i - 1) ~= ":" and line:sub(i + 1, i + 1):match("[%a_]") then
				local j = i + 2
				while j <= #line and line:sub(j, j):match("[%a_%d]") do
					j = j + 1
				end
				local k = j
				while k <= #line and line:sub(k, k):match("%s") do
					k = k + 1
				end
				if k <= #line and line:sub(k, k) == "(" then
					res[#res+1] = ":"
				else
					res[#res+1] = "."
				end
				i = i + 1
			else
				res[#res+1] = ch
				i = i + 1
			end
		end
		out[#out+1] = table.concat(res)
	end
	return out
end

local function fixLiteralMethodReceivers(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local ln = line
		ln = ln:gsub("([^%w_])nil:([%a_][%a_%d]*%s*%()", "%1(nil):%2")
		ln = ln:gsub("([^%w_])true:([%a_][%a_%d]*%s*%()", "%1(true):%2")
		ln = ln:gsub("([^%w_])false:([%a_][%a_%d]*%s*%()", "%1(false):%2")
		ln = ln:gsub("^nil:([%a_][%a_%d]*%s*%()", "(nil):%1")
		ln = ln:gsub("^true:([%a_][%a_%d]*%s*%()", "(true):%1")
		ln = ln:gsub("^false:([%a_][%a_%d]*%s*%()", "(false):%1")
		out[#out+1] = ln
	end
	return out
end

local function fixLiteralFieldReceivers(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local res = {}
		local quote = nil
		local i = 1
		while i <= #line do
			local ch = line:sub(i, i)
			if quote then
				res[#res+1] = ch
				if ch == "\\" and i + 1 <= #line then
					res[#res+1] = line:sub(i + 1, i + 1)
					i = i + 2
				else
					if ch == quote then quote = nil end
					i = i + 1
				end
			elseif ch == '"' or ch == "'" then
				quote = ch
				res[#res+1] = ch
				i = i + 1
			elseif ch == "-" and line:sub(i + 1, i + 1) == "-" then
				res[#res+1] = line:sub(i)
				break
			else
				local replaced = false
				for _, lit in ipairs({"false", "true", "nil"}) do
					local before = i > 1 and line:sub(i - 1, i - 1) or ""
					local after = line:sub(i + #lit, i + #lit)
					if line:sub(i, i + #lit - 1) == lit
						and after == "."
						and not before:match("[%w_]")
					then
						res[#res+1] = "(" .. lit .. ")"
						i = i + #lit
						replaced = true
						break
					end
				end
				if not replaced then
					res[#res+1] = ch
					i = i + 1
				end
			end
		end
		out[#out+1] = table.concat(res)
	end
	return out
end

local function astIfOpenText(text)
	return text:match("^if%s+(.+)%s+then$")
end

local function astBlockOpenText(text)
	if text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]") then return true end
	if text:match("^for%s.+%sdo$") or text:match("^while%s.+%sdo$") or text == "do" then return true end
	return false
end

local function repairInvalidElseClauses(lines)
	local out = {}
	local stack = {}
	for _, line in ipairs(lines) do
		local text = line:match("^%s*(.-)%s*$")
		local indent = line:match("^(%s*)") or ""
		while #stack > 0 and stack[#stack].indent > #indent do
			table.remove(stack)
		end
		if text:sub(1, 7) == "elseif " then
			if #stack > 0 and stack[#stack].kind == "if" and stack[#stack].indent == #indent and not stack[#stack].seen_else then
				out[#out+1] = line
			else
				local newLine = indent .. "if " .. text:sub(8)
				out[#out+1] = newLine
				stack[#stack+1] = {kind = "if", indent = #indent, seen_else = false}
			end
		elseif text == "else" then
			if #stack > 0 and stack[#stack].kind == "if" and stack[#stack].indent == #indent and not stack[#stack].seen_else then
				stack[#stack].seen_else = true
				out[#out+1] = line
			else
				local newLine = indent .. "if true then"
				out[#out+1] = newLine
				stack[#stack+1] = {kind = "if", indent = #indent, seen_else = false}
			end
		elseif text == "end" then
			if #stack > 0 and stack[#stack].indent == #indent then
				table.remove(stack)
			end
			out[#out+1] = line
		else
			out[#out+1] = line
			if astIfOpenText(text) then
				stack[#stack+1] = {kind = "if", indent = #indent, seen_else = false}
			elseif text == "repeat" then
				stack[#stack+1] = {kind = "repeat", indent = #indent}
			elseif astBlockOpenText(text) then
				stack[#stack+1] = {kind = "block", indent = #indent}
			end
		end
	end
	return out
end

local function restoreFirstMatchLoopBreaks(lines)
	local function trim(s)
		return (s or ""):match("^%s*(.-)%s*$")
	end
	local out = {}
	local i = 1
	while i <= #lines do
		local initInd, targetName = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*nil%s*$")
		local handled = false
		if initInd and i + 4 <= #lines then
			local forInd, loopKey, loopValue = lines[i + 1]:match("^(%s*)for%s+([%a_][%w_]*),%s*([%a_][%w_]*)%s+in%s+.+%s+do%s*$")
			local prepLines = {}
			local cursorIf = i + 2
			while forInd and lines[cursorIf] and (lines[cursorIf]:match("^(%s*)local%s+[%a_][%w_]*%s*=%s*.+$") or "") == forInd .. "\t" do
				prepLines[#prepLines + 1] = lines[cursorIf]
				cursorIf = cursorIf + 1
			end
			local ifInd, cond = matchIfOpen(lines[cursorIf] or "")
			local assignInd, assignTarget, assignValue = (lines[cursorIf + 1] or ""):match("^(%s*)([%a_][%w_]*)%s*=%s*(.+)%s*$")
			if forInd == initInd
				and ifInd == forInd .. "\t"
				and assignInd == ifInd .. "\t"
				and assignTarget == targetName
				and trim(assignValue) == loopValue
			then
				local cursor = cursorIf + 2
				local elseIdx = nil
				if lines[cursor] and trim(lines[cursor]) == "else" and (lines[cursor]:match("^(%s*)") or "") == ifInd then
					elseIdx = cursor
					cursor = cursor + 1
				end
				while lines[cursor] and (trim(lines[cursor]) == "" or trim(lines[cursor]):sub(1, 2) == "--") do
					cursor = cursor + 1
				end
				local ifEndIdx = lines[cursor] and matchEnd(lines[cursor]) == ifInd and cursor or nil
				local loopCursor = ifEndIdx and (ifEndIdx + 1) or nil
				while loopCursor and lines[loopCursor] and (trim(lines[loopCursor]) == "" or trim(lines[loopCursor]):sub(1, 2) == "--") do
					loopCursor = loopCursor + 1
				end
				local loopEndIdx = loopCursor and lines[loopCursor] and matchEnd(lines[loopCursor]) == forInd and loopCursor or nil
				local elseOnlyTrivial = true
				if elseIdx and ifEndIdx then
					for j = elseIdx + 1, ifEndIdx - 1 do
						local text = trim(lines[j])
						if text ~= "" and text:sub(1, 2) ~= "--" then
							elseOnlyTrivial = false
							break
						end
					end
				end
				if loopEndIdx and (not elseIdx or elseOnlyTrivial) then
					local usedLater = false
					for j = loopEndIdx + 1, math.min(#lines, loopEndIdx + 32) do
						if lines[j]:find("^%s*local%s+" .. luaPE(targetName) .. "%f[^%a_%d]") or lines[j]:find("^%s*" .. luaPE(targetName) .. "%s*=") then
							break
						end
						if countIdentUsesOutsideStrings(lines[j], targetName) > 0 then
							usedLater = true
							break
						end
					end
					if usedLater then
						out[#out + 1] = lines[i]
						out[#out + 1] = lines[i + 1]
						for _, prepLine in ipairs(prepLines) do
							out[#out + 1] = prepLine
						end
						out[#out + 1] = ifInd .. "if " .. negateCond(cond) .. " then continue end"
						out[#out + 1] = ifInd .. targetName .. " = " .. loopValue
						out[#out + 1] = ifInd .. "break"
						out[#out + 1] = lines[loopEndIdx]
						i = loopEndIdx + 1
						handled = true
					end
				end
			end
		end
		if not handled then
			out[#out + 1] = lines[i]
			i = i + 1
		end
	end
	return out
end

local function dropGotoToImmediatePostIfLabel(lines)
	local i = 1
	while i <= #lines do
		local gi, target = matchGoto(lines[i])
		if not gi then
			i = i + 1
		else
			local labelIdx = nil
			for k = i + 1, #lines do
				local _, lbl = matchLbl(lines[k])
				if lbl == target then
					labelIdx = k
					break
				end
			end
			local li = labelIdx and (lines[labelIdx]:match("^(%s*)") or "") or nil
			local nextIdx = i + 1
			while nextIdx <= #lines and not lines[nextIdx]:match("%S") do nextIdx = nextIdx + 1 end
			local nextText = nextIdx <= #lines and (lines[nextIdx]:match("^%s*(.-)%s*$") or "") or ""
			local nextInd = nextIdx <= #lines and (lines[nextIdx]:match("^(%s*)") or "") or ""
			local prevEnd = labelIdx and matchEnd(lines[labelIdx - 1] or "") or nil
			local branchTail = (
				labelIdx
				and li
				and prevEnd == li
				and #nextInd < #gi
				and (nextText == "else" or nextText == "end" or nextText:sub(1, 7) == "elseif ")
			)
			if branchTail then
				for k = i + 1, labelIdx - 1 do
					local txt = lines[k]:match("^%s*(.-)%s*$")
					local kind = #(lines[k]:match("^(%s*)") or "")
					if txt ~= "" and kind < #gi
						and txt ~= "end" and txt ~= "else" and txt:sub(1, 7) ~= "elseif "
					then
						branchTail = false
						break
					end
				end
			end
			if branchTail then
				local result = {}
				for k = 1, i - 1 do result[#result+1] = lines[k] end
				for k = i + 1, labelIdx - 1 do result[#result+1] = lines[k] end
				for k = labelIdx + 1, #lines do result[#result+1] = lines[k] end
				return result, true
			end
			local j = i + 1
			local ok = true
			while j <= #lines do
				local text = lines[j]:match("^%s*(.-)%s*$")
				local ind = lines[j]:match("^(%s*)") or ""
				if text == "" then
					j = j + 1
				elseif #ind < #gi then
					ok = false
					break
				elseif #ind == #gi and (text == "else" or text:sub(1, 7) == "elseif " or text == "end") then
					j = j + 1
				else
					break
				end
			end
			local li2, lbl = j <= #lines and matchLbl(lines[j]) or nil
			if ok and lbl == target and li2 and #li2 <= #gi then
				local result = {}
				for k = 1, i - 1 do result[#result+1] = lines[k] end
				for k = i + 1, j - 1 do result[#result+1] = lines[k] end
				for k = j + 1, #lines do result[#result+1] = lines[k] end
				return result, true
			end
			i = i + 1
		end
	end
	return lines, false
end

-- Find label index in lines starting from `startI` (1-based)
local function findLabelIndex(lines, target, startI)
	local pat = "^%s*::" .. luaPE(target) .. "::%s*$"
	for i = startI, #lines do
		if lines[i]:match(pat) then return i end
	end
	return nil
end

-- Lift complementary guard pair pattern (handles cross-block guards):
--   if A then goto T1 end
--   if B then goto T2 end
--   ::T1::
--   GUARD_BODY (e.g. return)
--   ::T2::
-- The semantic is: GUARD_BODY runs when A is true OR B is false.
-- Equivalent to: `if A or not B then GUARD_BODY end` (T2 dropped if only ref is line 2).
local liftComplementaryGuardPair
do
	liftComplementaryGuardPair = function(lines)
	local i = 1
	while i + 1 <= #lines do
		local ind1, cond1, tgt1 = matchIfGoto(lines[i])
		local ind2, cond2, tgt2 = matchIfGoto(lines[i + 1])
		if ind1 and ind2 and ind1 == ind2 and tgt1 ~= tgt2 then
			-- ::T1:: must immediately follow line i+1 (possibly after blanks)
			local t1Idx = i + 2
			while t1Idx <= #lines and not lines[t1Idx]:match("%S") do t1Idx = t1Idx + 1 end
			local t1Lbl = nil
			if t1Idx <= #lines then
				local _, lbl = matchLbl(lines[t1Idx])
				t1Lbl = lbl
			end
			if t1Lbl == tgt1 then
				-- Find ::T2::
				local t2Idx = findLabelIndex(lines, tgt2, t1Idx + 1)
				if t2Idx then
					-- GUARD_BODY = lines between ::T1:: and ::T2::
					local guardBody = {}
					local bodyOk = true
					for k = t1Idx + 1, t2Idx - 1 do
						guardBody[#guardBody+1] = lines[k]
						local _, innerLbl = matchLbl(lines[k])
						if innerLbl then bodyOk = false; break end
						-- Allow goto whose target is OUTSIDE the lifted region
						-- (typically loop-end labels for `continue`/`break`).
						-- Reject only goto targets INSIDE [i, t2Idx] (would create internal cycle).
						local _, gTgt = matchGoto(lines[k])
						if gTgt then
							local gLblIdx = findLabelIndex(lines, gTgt, 1)
							if gLblIdx and gLblIdx >= i and gLblIdx <= t2Idx then
								bodyOk = false; break
							end
						end
						local _, _, ifgTgt = matchIfGoto(lines[k])
						if ifgTgt then
							local ifgLblIdx = findLabelIndex(lines, ifgTgt, 1)
							if ifgLblIdx and ifgLblIdx >= i and ifgLblIdx <= t2Idx then
								bodyOk = false; break
							end
						end
					end
					if bodyOk and #guardBody > 0 then
						-- Check ref counts: T1 only from line i, T2 only from line i+1
						local refs1 = labelRefs(lines, tgt1)
						local refs2 = labelRefs(lines, tgt2)
						local refs1Ok = #refs1 == 1 and refs1[1] == i
						local refs2Ok = #refs2 == 1 and refs2[1] == i + 1
						if refs1Ok and refs2Ok then
							-- Build: if cond1 or not cond2 then BODY end
							-- Simplification: emit two separate guards for clarity
							-- `if cond1 then BODY end; if not cond2 then BODY end`
							-- only works if BODY has no side effects that should run once.
							-- Safer to merge: `if A or not B then BODY end`.
							local result = {}
							for k = 1, i - 1 do result[#result+1] = lines[k] end
							-- Emit two separate guards (cleaner output, common idiom)
							for _, bl in ipairs(guardBody) do
								-- only safe if guardBody is a simple `return` / `continue` / `break` / `return EXPR`
							end
							-- Use single combined form
							local combined = wrapForAnd(cond1) .. " or " .. wrapForAnd(negateCond(cond2))
							result[#result+1] = ind1 .. "if " .. combined .. " then"
							for _, bl in ipairs(guardBody) do
								if bl:match("%S") then
									result[#result+1] = "\t" .. bl
								else
									result[#result+1] = bl
								end
							end
							result[#result+1] = ind1 .. "end"
							for k = t2Idx + 1, #lines do result[#result+1] = lines[k] end
							return result, true
						end
					end
				end
			end
		end
		i = i + 1
	end
	return lines, false
end
end

local function wrapOrphanIfGotosAsGuards(lines, indentUnit)
	local labels = {}
	for _, ln in ipairs(lines) do
		local _, lbl = matchLbl(ln)
		if lbl then labels[lbl] = true end
	end
	local i = 1
	while i <= #lines do
		local ind, cond, target = matchIfGoto(lines[i])
		if ind and not labels[target] then
			local j = i + 1
			while j <= #lines do
				local text = lines[j]:match("^%s*(.-)%s*$")
				local curInd = lines[j]:match("^(%s*)") or ""
				if text == "" then
					j = j + 1
				elseif #curInd < #ind then
					break
				elseif #curInd == #ind and (text == "end" or text == "else" or text:sub(1, 7) == "elseif ") then
					break
				else
					j = j + 1
				end
			end
			if j > i + 1 then
				local result = {}
				for k = 1, i - 1 do result[#result+1] = lines[k] end
				result[#result+1] = ind .. "if " .. negateCond(cond) .. " then"
				for k = i + 1, j - 1 do
					local bl = lines[k]
					if bl:match("%S") then result[#result+1] = indentUnit .. bl else result[#result+1] = bl end
				end
				result[#result+1] = ind .. "end"
				for k = j, #lines do result[#result+1] = lines[k] end
				return result, true
			end
		end
		i = i + 1
	end
	return lines, false
end

local function dropInvalidTopLevelReturns(lines)
	local out = {}
	for i, ln in ipairs(lines) do
		local ind = ln:match("^(%s*)") or ""
		local text = ln:match("^%s*(.-)%s*$")
		local drop = false
		if ind == "" and (text == "return" or text:sub(1, 7) == "return ") then
			local j = i + 1
			while j <= #lines and not lines[j]:match("%S") do j = j + 1 end
			local nextText = j <= #lines and (lines[j]:match("^%s*(.-)%s*$") or "") or ""
			if nextText:sub(1, 15) == "local function " or nextText:sub(1, 9) == "function " then
				drop = true
			end
		end
		if not drop then out[#out+1] = ln end
	end
	return out
end

local function fixInvalidGenericForHeaders(lines)
	local out = {}
	for _, ln in ipairs(lines) do
		local ind, vars, reg = ln:match("^(%s*)for%s+(.+)%s+in%s+%-%-%s*iter%s+(R%d+)%s+do%s*$")
		if ind then
			out[#out+1] = ind .. "for " .. vars .. " in " .. reg .. " do"
		else
			out[#out+1] = ln
		end
	end
	return out
end

-- Last non-blank index
local function lastNonblankIndex(lines)
	for i = #lines, 1, -1 do
		if lines[i]:match("%S") then return i end
	end
	return nil
end

local function inlineLocalIntoIfGoto(lines, indentUnit)
	local out = {}
	for _, ln in ipairs(lines) do out[#out+1] = ln end

	local function trim(s)
		return (s or ""):match("^%s*(.-)%s*$")
	end

	local function stripOuterParens(s)
		s = trim(s)
		while s:sub(1, 1) == "(" and s:sub(-1) == ")" do
			local depth = 0
			local balanced = true
			for i = 1, #s do
				local ch = s:sub(i, i)
				if ch == "(" then
					depth = depth + 1
				elseif ch == ")" then
					depth = depth - 1
					if depth == 0 and i < #s then
						balanced = false
						break
					end
				end
			end
			if not balanced then break end
			s = trim(s:sub(2, -2))
		end
		return s
	end

	local function matchDecl(line)
		local ind, var, rhs = line:match("^(%s*)local%s+([%a_][%a_%d]*)%s*=%s*(.+)%s*$")
		if var then return ind, true, var, rhs end
		ind, var, rhs = line:match("^(%s*)([%a_][%a_%d]*)%s*=%s*(.+)%s*$")
		if var then return ind, false, var, rhs end
		return nil
	end

	local function validFieldSuffix(s)
		if s == "" then return true end
		local consumed = 0
		for seg in s:gmatch("%.([%a_][%a_%d]*)") do
			consumed = consumed + #seg + 1
		end
		return consumed == #s and consumed > 0
	end

	local function simpleIdentChain(s)
		local first, nextPos = s:match("^([%a_][%a_%d]*)()")
		if not first then return false end
		while nextPos <= #s do
			if s:sub(nextPos, nextPos) ~= "." then return false end
			local seg, afterSeg = s:match("^%.([%a_][%a_%d]*)()", nextPos)
			if not seg then return false end
			nextPos = afterSeg
		end
		return true
	end

	local function parseTest(line, var)
		local ind, cond, target = matchIfGoto(line)
		if not ind then return nil end
		local neg = ""
		cond = trim(cond)
		if cond:sub(1, 4) == "not " then
			neg = "not "
			cond = trim(cond:sub(5))
		end
		cond = stripOuterParens(cond)
		if cond == var then
			return ind, neg, "", target
		end
		if cond:sub(1, #var) == var then
			local suffix = cond:sub(#var + 1)
			if validFieldSuffix(suffix) then
				return ind, neg, suffix, target
			end
		end
		return nil
	end

	local function usesVar(line, var)
		return line:find("%f[%a_]" .. luaPE(var) .. "%f[^%a_%d]") ~= nil
	end

	local changed = false
	local i = 1
	while i + 1 <= #out do
		local ind, isLocal, var, rhs = matchDecl(out[i])
		if not ind then
			i = i + 1
		else
			local testInd, neg, suffix, target = parseTest(out[i + 1], var)
			if not testInd or testInd ~= ind then
				i = i + 1
			else
				local targetIdx = findLabelIndex(out, target, i + 2)
				if not targetIdx then
					i = i + 1
				else
					local unsafe = false
					for j = i + 2, targetIdx - 1 do
						if usesVar(out[j], var) then
							local ai, arhs = out[j]:match("^(%s*)local%s+" .. luaPE(var) .. "%s*=%s*(.+)%s*$")
							if not ai then
								ai, arhs = out[j]:match("^(%s*)" .. luaPE(var) .. "%s*=%s*(.+)%s*$")
							end
							if ai and not usesVar(arhs, var) then
								break
							end
							unsafe = true
							break
						end
					end
					if unsafe then
						i = i + 1
					else
						local tailUsed = false
						for j = targetIdx, #out do
							if usesVar(out[j], var) then tailUsed = true break end
						end
						if not isLocal then
							if tailUsed then
								i = i + 1
							else
								local expr = trim(rhs)
								local needsParens = expr:find(" or ", 1, true) ~= nil or expr:find(" and ", 1, true) ~= nil or (suffix ~= "" and not simpleIdentChain(expr))
								if needsParens then expr = "(" .. expr .. ")" end
								out[i] = ind .. "if " .. neg .. expr .. suffix .. " then goto " .. target .. " end"
								table.remove(out, i + 1)
								changed = true
								i = i + 1
							end
						else
							if tailUsed then
								i = i + 1
							else
								local expr = trim(rhs)
								local needsParens = expr:find(" or ", 1, true) ~= nil or expr:find(" and ", 1, true) ~= nil or (suffix ~= "" and not simpleIdentChain(expr))
								if needsParens then expr = "(" .. expr .. ")" end
								out[i] = ind .. "if " .. neg .. expr .. suffix .. " then goto " .. target .. " end"
								table.remove(out, i + 1)
								changed = true
								i = i + 1
							end
						end
					end
				end
			end
		end
	end
	return out, changed
end

-- Lift `if g1 goto T end; if g2 goto T end; THEN_BODY; goto J; ::T:: ELSE_BODY; ::J::` -> `if not g1 and not g2 then...else...end`
local function liftGuardChainElse(lines, indentUnit)
	local i = 1
	while i <= #lines do
		local transformed = false
		local ii, cond1, tgt1 = matchIfGoto(lines[i])
		if ii then
			local guards = {cond1}
			local cur = i + 1
			while cur <= #lines do
				local ii2, c2, t2 = matchIfGoto(lines[cur])
				if not ii2 or ii2 ~= ii or t2 ~= tgt1 then break end
				guards[#guards+1] = c2
				cur = cur + 1
			end
			local elseIdx = findLabelIndex(lines, tgt1, cur)
			if elseIdx then
				local thenBody = {}
				for k = cur, elseIdx - 1 do thenBody[#thenBody+1] = lines[k] end
				local lastI = lastNonblankIndex(thenBody)
				if lastI then
					local ji, joinTgt = matchGoto(thenBody[lastI])
					if ji then
						local joinIdx = findLabelIndex(lines, joinTgt, elseIdx + 1)
						if joinIdx then
							local elseBody = {}
							for k = elseIdx + 1, joinIdx - 1 do elseBody[#elseBody+1] = lines[k] end
							local hasInnerLabel = false
							for k = 1, lastI - 1 do if matchLbl(thenBody[k]) then hasInnerLabel = true break end end
							if not hasInnerLabel then
								for _, bl in ipairs(elseBody) do if matchLbl(bl) then hasInnerLabel = true break end end
							end
							local innerGoto = false
							if not hasInnerLabel then
								for k = 1, lastI - 1 do if thenBody[k]:match("%f[%a_]goto%s+pc%d+") then innerGoto = true break end end
								if not innerGoto then
									for _, bl in ipairs(elseBody) do if bl:match("%f[%a_]goto%s+pc%d+") then innerGoto = true break end end
								end
							end
							local outsideRefs = false
							if not hasInnerLabel and not innerGoto then
								for _, r in ipairs(labelRefs(lines, tgt1)) do
									if r < i or r > elseIdx then outsideRefs = true break end
								end
							end
							if not hasInnerLabel and not innerGoto and not outsideRefs then
								local condParts = {}
								for _, g in ipairs(guards) do condParts[#condParts+1] = wrapForAnd(negateCond(g)) end
								local cond = table.concat(condParts, " and ")
								local newBlock = {ii .. "if " .. cond .. " then"}
								for k = 1, lastI - 1 do
									local bl = thenBody[k]
									newBlock[#newBlock+1] = bl:match("%S") and (indentUnit .. bl) or bl
								end
								local hasElseBody = false
								for _, bl in ipairs(elseBody) do if bl:match("%S") then hasElseBody = true break end end
								if hasElseBody then
									newBlock[#newBlock+1] = ii .. "else"
									for _, bl in ipairs(elseBody) do newBlock[#newBlock+1] = bl:match("%S") and (indentUnit .. bl) or bl end
								end
								newBlock[#newBlock+1] = ii .. "end"
								local otherJoinRefs = {}
								for _, r in ipairs(labelRefs(lines, joinTgt)) do
									if not (i <= r and r <= joinIdx) then otherJoinRefs[#otherJoinRefs+1] = r end
								end
								if #otherJoinRefs > 0 then newBlock[#newBlock+1] = lines[joinIdx] end
								local result = {}
								for k = 1, i - 1 do result[#result+1] = lines[k] end
								for _, bl in ipairs(newBlock) do result[#result+1] = bl end
								for k = joinIdx + 1, #lines do result[#result+1] = lines[k] end
								return result, true
							end
						end
					end
				end
			end
		end
		if not transformed then
			i = i + 1
		end
	end
	return lines, false
end

-- Lift `if COND then goto T end; BODY; ::T::` -> `if not COND then BODY end`
-- where T is only referenced by this one goto, BODY has no labels and no ref to T
local function liftGuardToSkipLabel(lines, indentUnit)
	local changed = false
	local i = 1
	while i <= #lines do
		local rebuilt = false
		local ind, cond, tgt = matchIfGoto(lines[i])
		if ind then
			local labelIdx = nil
			local labelInd = nil
			for j = i + 1, #lines do
				local li, lbl = matchLbl(lines[j])
				if lbl == tgt then
					labelIdx = j
					labelInd = li
					break
				end
			end
			if labelIdx and labelInd == ind and labelIdx > i + 1 then
				-- the label must be referenced only once (by our goto) so we
				-- can safely drop it after re-structuring.
				local refs = labelRefs(lines, tgt)
				if #refs == 1 and refs[1] == i then
					local bodyOk = true
					-- disallow inner labels and disallow nested blocks that
					-- span past the label.
					local depth = 0
					for k = i + 1, labelIdx - 1 do
						local _, innerLbl = matchLbl(lines[k])
						if innerLbl then bodyOk = false; break end
						local ki = lines[k]:match("^(%s*)") or ""
						if #ki < #ind then bodyOk = false; break end
						if matchLoopOpen(lines[k]) or matchIfOpen(lines[k]) then
							depth = depth + 1
						elseif matchEnd(lines[k]) then
							if depth == 0 then bodyOk = false; break end
							depth = depth - 1
						end
					end
					if bodyOk and depth == 0 then
						local body = {}
						for k = i + 1, labelIdx - 1 do body[#body+1] = lines[k] end
						local negCond = negateCond(cond)
						local newBlock = {ind .. "if " .. negCond .. " then"}
						for _, bl in ipairs(body) do
							if bl:match("%S") then
								newBlock[#newBlock+1] = indentUnit .. bl
							else
								newBlock[#newBlock+1] = bl
							end
						end
						newBlock[#newBlock+1] = ind .. "end"
						local result = {}
						for k = 1, i - 1 do result[#result+1] = lines[k] end
						for _, bl in ipairs(newBlock) do result[#result+1] = bl end
						for k = labelIdx + 1, #lines do result[#result+1] = lines[k] end
						lines = result
						changed = true
						rebuilt = true
					end
				end
			end
		end
		if not rebuilt then i = i + 1 end
	end
	return lines, changed
end

local function liftIfGotoBody(lines, indentUnit)
	local i = 1
	while i <= #lines do
		local ind, cond, target = matchIfGoto(lines[i])
		if not ind then
			i = i + 1
		else
			local labelIdx = findLabelIndex(lines, target, i + 1)
			if not labelIdx then
				i = i + 1
			else
				local body = {}
				for k = i + 1, labelIdx - 1 do body[#body+1] = lines[k] end
				-- Check: does body contain an inner `if X then goto T2 end` where
				-- T2 is OUTSIDE the body (i.e., T2's label appears AFTER labelIdx)?
				-- If so, this is a "complementary guard" pattern and the body
				-- spans into the post-target region. Mishandling this produces
				-- inverted conditions like `if not IsDying then return end` when
				-- the source intended `if IsDying then return end`.
				local hasOuterGoto = false
				for _, bl in ipairs(body) do
					local _, _, innerTarget = matchIfGoto(bl)
					if innerTarget and innerTarget ~= target then
						-- Check if this target is past labelIdx
						local outerLabelIdx = findLabelIndex(lines, innerTarget, labelIdx + 1)
						if outerLabelIdx then
							hasOuterGoto = true
							break
						end
					end
				end
				if hasOuterGoto then
					-- Skip; let liftComplementaryGuardPair or other passes handle it
					i = i + 1
				else
				local bodyHasGoto = false
				for _, bl in ipairs(body) do
					if bl:find("%f[%a_]goto%s+" .. luaPE(target) .. "%f[^%a_%d]") then
						bodyHasGoto = true
						break
					end
				end
				local outsideRefs = {}
				for _, r in ipairs(labelRefs(lines, target)) do
					if r < i or r > labelIdx then outsideRefs[#outsideRefs+1] = r end
				end

				local elseBlock = nil
				local elseTarget = nil
				local elseLabelIdx = nil
				local lastIdx = lastNonblankIndex(body)
				if lastIdx and not bodyHasGoto then
					local _, candTarget = matchGoto(body[lastIdx])
					if candTarget then
						local candLabelIdx = findLabelIndex(lines, candTarget, labelIdx + 1)
						if candLabelIdx then
							local between = {}
							for k = labelIdx + 1, candLabelIdx - 1 do between[#between+1] = lines[k] end
							local bodyInner = {}
							for k = 1, lastIdx - 1 do bodyInner[#bodyInner+1] = body[k] end
							local escapes = false
							for _, bl in ipairs(bodyInner) do
								if bl:find("%f[%a_]goto%s+" .. luaPE(target) .. "%f[^%a_%d]")
									or bl:find("%f[%a_]goto%s+" .. luaPE(candTarget) .. "%f[^%a_%d]")
								then
									escapes = true
									break
								end
							end
							if not escapes then
								for _, bl in ipairs(between) do
									if bl:find("%f[%a_]goto%s+" .. luaPE(target) .. "%f[^%a_%d]")
										or bl:find("%f[%a_]goto%s+" .. luaPE(candTarget) .. "%f[^%a_%d]")
									then
										escapes = true
										break
									end
								end
							end
							if not escapes then
								elseBlock = between
								elseTarget = candTarget
								elseLabelIdx = candLabelIdx
								body = bodyInner
							end
						end
					end
				end

				local newBlock = {ind .. "if " .. negateCond(cond) .. " then"}
				for _, bl in ipairs(body) do
					if bl:match("%S") then
						newBlock[#newBlock+1] = indentUnit .. bl
					else
						newBlock[#newBlock+1] = bl
					end
				end
				if elseBlock then
					newBlock[#newBlock+1] = ind .. "else"
					for _, bl in ipairs(elseBlock) do
						if bl:match("%S") then
							newBlock[#newBlock+1] = indentUnit .. bl
						else
							newBlock[#newBlock+1] = bl
						end
					end
				end
				newBlock[#newBlock+1] = ind .. "end"

				local result = {}
				for k = 1, i - 1 do result[#result+1] = lines[k] end
				for _, bl in ipairs(newBlock) do result[#result+1] = bl end
				if elseBlock then
					if #outsideRefs > 0 or bodyHasGoto then result[#result+1] = lines[labelIdx] end
					local otherElseRefs = false
					for _, r in ipairs(labelRefs(lines, elseTarget)) do
						if r < i or r > elseLabelIdx then
							otherElseRefs = true
							break
						end
					end
					if otherElseRefs then result[#result+1] = lines[elseLabelIdx] end
					for k = elseLabelIdx + 1, #lines do result[#result+1] = lines[k] end
				else
					if #outsideRefs > 0 or bodyHasGoto then result[#result+1] = lines[labelIdx] end
					for k = labelIdx + 1, #lines do result[#result+1] = lines[k] end
				end
				return result, true
				end -- hasOuterGoto check
			end
		end
	end
	return lines, false
end

local function liftSimpleGuardChains(lines, indentUnit)
	local i = 1
	while i <= #lines do
		local ind, cond, target = matchIfGoto(lines[i])
		if not ind then
			i = i + 1
		else
			local guards = {}
			local cur = i
			while cur <= #lines do
				local gi, gc, gt = matchIfGoto(lines[cur])
				if not gi or gi ~= ind or gt ~= target then break end
				guards[#guards+1] = gc
				cur = cur + 1
			end
			local labelIdx = findLabelIndex(lines, target, cur)
			if labelIdx and #guards > 0 then
				local refsOk = true
				for _, r in ipairs(labelRefs(lines, target)) do
					if r < i or r >= cur then refsOk = false break end
				end
				local bodyOk = refsOk and labelIdx > cur
				if bodyOk then
					for k = cur, labelIdx - 1 do
						local bi = lines[k]:match("^(%s*)") or ""
						local _, lbl = matchLbl(lines[k])
						if (lines[k]:match("%S") and #bi < #ind) or lbl or matchGoto(lines[k]) or matchIfGoto(lines[k]) then bodyOk = false break end
					end
				end
				if bodyOk then
					local conds = {}
					for _, g in ipairs(guards) do conds[#conds+1] = negateCond(g) end
					local newBlock = {ind .. "if " .. table.concat(conds, " and ") .. " then"}
					for k = cur, labelIdx - 1 do
						local bl = lines[k]
						if bl:match("%S") then newBlock[#newBlock+1] = indentUnit .. bl else newBlock[#newBlock+1] = bl end
					end
					newBlock[#newBlock+1] = ind .. "end"
					local result = {}
					for k = 1, i - 1 do result[#result+1] = lines[k] end
					for _, bl in ipairs(newBlock) do result[#result+1] = bl end
					for k = labelIdx + 1, #lines do result[#result+1] = lines[k] end
					return result, true
				end
			end
			i = i + 1
		end
	end
	return lines, false
end

-- Lift multiline `if X then BODY goto T end ELSE_BODY ::T::` -> `if X then BODY else ELSE_BODY end`
local function liftMultilineIfGotoElse(lines, indentUnit)
	local i = 1
	while i <= #lines do
		local mii, cond = matchIfOpen(lines[i])
		if mii then
			local endPat = "^" .. luaPE(mii) .. "end%s*$"
			local depth = 0
			local endIdx = nil
			for j = i + 1, #lines do
				local ii2 = matchIfOpen(lines[j])
				if ii2 and ii2 == mii then
					depth = depth + 1
				elseif lines[j]:match(endPat) then
					if depth == 0 then
						endIdx = j
						break
					end
					depth = depth - 1
				end
			end
			if endIdx then
				local k = endIdx - 1
				while k > i and not lines[k]:match("%S") do k = k - 1 end
				if k > i then
					local gi, gTgt = matchGoto(lines[k])
					if gi and #gi > #mii then
						local labelIdx = nil
						for j = endIdx + 1, #lines do
							local lind, lbl = matchLbl(lines[j])
							if lbl == gTgt then
								if #lind <= #mii then labelIdx = j end
								break
							end
						end
						if labelIdx then
							local outsideRefs = false
							for _, r in ipairs(labelRefs(lines, gTgt)) do
								if r < i or r > labelIdx then outsideRefs = true break end
							end
							local bodyInner = {}
							for j = i + 1, k - 1 do bodyInner[#bodyInner+1] = lines[j] end
							local truncIdx = labelIdx
							for tj = endIdx + 1, labelIdx - 1 do
								if lines[tj]:match("%S") then
									local li2 = #(lines[tj]:match("^(%s*)") or "")
									if li2 < #mii then
										truncIdx = tj
										break
									end
								end
							end
							local elseBody = {}
							for j = endIdx + 1, truncIdx - 1 do elseBody[#elseBody+1] = lines[j] end
							local truncated = truncIdx ~= labelIdx
							local bodyHasGoto = false
							local tgtPat = "%f[%a_]goto%s+" .. luaPE(gTgt) .. "%f[^%a_%d]"
							for _, bl in ipairs(bodyInner) do if bl:find(tgtPat) then bodyHasGoto = true break end end
							local elseHasGoto = false
							for _, bl in ipairs(elseBody) do if bl:find(tgtPat) then elseHasGoto = true break end end
							local newBlock = {mii .. "if " .. cond .. " then"}
							for _, bl in ipairs(bodyInner) do newBlock[#newBlock+1] = bl end
							local hasElse = false
							for _, bl in ipairs(elseBody) do if bl:match("%S") then hasElse = true break end end
							if hasElse then
								newBlock[#newBlock+1] = mii .. "else"
								local minInd = nil
								for _, bl in ipairs(elseBody) do
									if bl:match("%S") then
										local li2 = #(bl:match("^(%s*)") or "")
										if not minInd or li2 < minInd then minInd = li2 end
									end
								end
								minInd = minInd or #mii
								for _, bl in ipairs(elseBody) do
									if not bl:match("%S") then newBlock[#newBlock+1] = bl
									else newBlock[#newBlock+1] = gi .. bl:sub(minInd + 1) end
								end
							end
							newBlock[#newBlock+1] = mii .. "end"
							local keepLabel = bodyHasGoto or elseHasGoto or outsideRefs or truncated
							local result = {}
							for j = 1, i - 1 do result[#result+1] = lines[j] end
							for _, bl in ipairs(newBlock) do result[#result+1] = bl end
							if truncated then
								for j = truncIdx, labelIdx - 1 do result[#result+1] = lines[j] end
							end
							if keepLabel then result[#result+1] = lines[labelIdx] end
							for j = labelIdx + 1, #lines do result[#result+1] = lines[j] end
							return result, true
						end
					end
				end
			end
		end
		i = i + 1
	end
	return lines, false
end

-- Find enclosing loop (returns openIdx, closeIdx, loopIndent) using fresh copy of lines
local function enclosingLoop(lines, gotoLineIdx)
	local candidates = {}
	for k = gotoLineIdx - 1, 1, -1 do
		local li = matchLoopOpen(lines[k])
		if li then candidates[#candidates+1] = {k, li} end
	end
	for _, cand in ipairs(candidates) do
		local openIdx, loopInd = cand[1], cand[2]
		local endPat = "^" .. luaPE(loopInd) .. "end%s*$"
		local depth = 0
		for j = openIdx + 1, #lines do
			local li2 = matchLoopOpen(lines[j])
			if li2 and li2 == loopInd then depth = depth + 1
			elseif lines[j]:match(endPat) then
				if depth == 0 then
					if openIdx <= gotoLineIdx and gotoLineIdx <= j then
						return openIdx, j, loopInd
					end
					break
				end
				depth = depth - 1
			end
		end
	end
	return nil
end

-- Convert goto pcN inside loops to `continue` keyword
local function gotosToContinue(lines)
	if #lines == 0 then return lines end
	local labelIdx = {}
	for i, ln in ipairs(lines) do
		local _, lbl = matchLbl(ln)
		if lbl then
			if not labelIdx[lbl] then labelIdx[lbl] = {} end
			labelIdx[lbl][#labelIdx[lbl]+1] = i
		end
	end
	local newLines = {}
	for _, ln in ipairs(lines) do newLines[#newLines+1] = ln end
	local labelsToDrop = {}
	for i, ln in ipairs(newLines) do
		local gind, gtgt = matchGoto(ln)
		local inlineInd, inlineCond, inlineTarget = matchIfGoto(ln)
		if gind or inlineInd then
			local indent2 = gind or inlineInd
			local target = gtgt or inlineTarget
			local openIdx, closeIdx, _ = enclosingLoop(newLines, i)
			if openIdx then
				local tgtIdxs = labelIdx[target] or {}
				local convert = false
				-- Convert to `continue` when target is INSIDE the loop body and at
				-- the end (next iteration), OR when the target was consumed (orphan)
				-- AND the goto is followed only by other simple statements before
				-- the loop's `end` (suggesting the original target was at the end
				-- of the iteration, i.e., a `continue`).
				if #tgtIdxs > 0 then
					for _, li in ipairs(tgtIdxs) do
						if openIdx < li and li < closeIdx then
							local tailBlank = true
							for k = li + 1, closeIdx - 1 do
								if newLines[k]:match("%S") then tailBlank = false break end
							end
							if tailBlank then
								convert = true
								labelsToDrop[li] = true
								break
							end
						end
					end
				else
					-- Orphaned goto: target label was consumed (e.g. by a previous
					-- lift pass).  Treat as `continue` ONLY if the enclosing loop
					-- is a `for ... do` (where the original semantic of a forward
					-- goto matching FORGLOOP target is "skip to next iteration").
					-- For `while true do ... end` (lifted from JUMPBACK), the orphan
					-- goto is a forward escape -> `break`, handled by gotosToBreak.
					local openLine = newLines[openIdx] or ""
					if openLine:match("^%s*for%s") then
						convert = true
					end
				end
				if convert then
					if inlineInd then
						newLines[i] = indent2 .. "if " .. inlineCond .. " then continue end"
					else
						newLines[i] = indent2 .. "continue"
					end
				end
			end
		end
	end
	if next(labelsToDrop) then
		local filtered = {}
		for k, ln in ipairs(newLines) do
			if not labelsToDrop[k] then filtered[#filtered+1] = ln end
		end
		newLines = filtered
	end
	return newLines
end

-- Convert goto pcN after loops to `break`
local function gotosToBreak(lines)
	if #lines == 0 then return lines end
	local labelIdx = {}
	for i, ln in ipairs(lines) do
		local _, lbl = matchLbl(ln)
		if lbl then
			if not labelIdx[lbl] then labelIdx[lbl] = {} end
			labelIdx[lbl][#labelIdx[lbl]+1] = i
		end
	end
	local newLines = {}
	for _, ln in ipairs(lines) do newLines[#newLines+1] = ln end
	local convertedTargets = {}
	for i, ln in ipairs(newLines) do
		local gind, gtgt = matchGoto(ln)
		local inlineInd, inlineCond, inlineTarget = matchIfGoto(ln)
		if gind or inlineInd then
			local indent2 = gind or inlineInd
			local target = gtgt or inlineTarget
			local converted = false
			local openIdx, closeIdx, _ = enclosingLoop(newLines, i)
			if openIdx then
				local j = closeIdx + 1
				while j <= #newLines and not newLines[j]:match("%S") do j = j + 1 end
				local tgtIdxs = labelIdx[target] or {}
				local found = false
				for _, li in ipairs(tgtIdxs) do if li == j then found = true break end end
				if found then
					newLines[i] = inlineInd and (indent2 .. "if " .. inlineCond .. " then break end") or (indent2 .. "break")
					convertedTargets[target] = true
					converted = true
				end
			end
			if not converted then
				local j = i + 1
				while j <= #newLines and not newLines[j]:match("%S") do j = j + 1 end
				local closeInd = j <= #newLines and matchEnd(newLines[j]) or nil
				if closeInd and #closeInd < #indent2 then
					local k = j + 1
					while k <= #newLines and not newLines[k]:match("%S") do k = k + 1 end
					local lbl = nil
					if k <= #newLines then
						local _li
						_li, lbl = matchLbl(newLines[k])
					end
					if lbl == target then
						newLines[i] = inlineInd and (indent2 .. "if " .. inlineCond .. " then break end") or (indent2 .. "break")
						convertedTargets[target] = true
						converted = true
					end
				end
			end
			-- Orphaned goto (target label doesn't exist anywhere): convert to break.
			-- This happens when the target label was consumed by a previous lift
			-- (e.g. liftWhileTrueFromJumpback consumed `::pcN::` along with its
			-- back-edge `goto pcN`).  The original semantic was a forward escape
			-- out of the enclosing loop.
			if not converted and openIdx then
				local tgtIdxs2 = labelIdx[target] or {}
				if #tgtIdxs2 == 0 then
					newLines[i] = inlineInd and (indent2 .. "if " .. inlineCond .. " then break end") or (indent2 .. "break")
				end
			end
		end
	end
	if next(convertedTargets) then
		local stillUsed = {}
		for _, ln in ipairs(newLines) do
			local _, gtgt = matchGoto(ln)
			if gtgt then stillUsed[gtgt] = true end
			local _, _, inlineTarget = matchIfGoto(ln)
			if inlineTarget then stillUsed[inlineTarget] = true end
		end
		local filtered = {}
		for _, ln in ipairs(newLines) do
			local _, lbl = matchLbl(ln)
			if lbl and convertedTargets[lbl] and not stillUsed[lbl] then
				-- skip
			else
				filtered[#filtered+1] = ln
			end
		end
		newLines = filtered
	end
	return newLines
end

-- Drop empty for-loops whose body is just `goto LBL` then `::LBL::`
local function dropEmptyGotoForLoops(lines)
	local newLines = {}
	for _, ln in ipairs(lines) do newLines[#newLines+1] = ln end
	local i = 1
	while i <= #newLines - 3 do
		local forInd = newLines[i]:match("^(%s*)for%s.+%sdo%s*$")
		if forInd then
			local endPat = "^" .. luaPE(forInd) .. "end%s*$"
			local j = i + 1
			local bodyLines = {}
			while j <= #newLines do
				if newLines[j]:match("%S") then
					if newLines[j]:match(endPat) then break end
					bodyLines[#bodyLines+1] = j
				end
				j = j + 1
			end
			local removed = false
			if j <= #newLines and #bodyLines == 1 then
				local gi, gTgt = matchGoto(newLines[bodyLines[1]])
				if gi then
					local k = j + 1
					while k <= #newLines and not newLines[k]:match("%S") do k = k + 1 end
					if k <= #newLines then
						local _, lbl = matchLbl(newLines[k])
						if lbl == gTgt then
							for _ = i, k do table.remove(newLines, i) end
							removed = true
						end
					end
				end
			end
			if not removed then
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	return newLines
end

-- Convert `::pcN:: BODY goto pcN` -> `while true do BODY end`
local function liftWhileTrueFromJumpback(lines, loopHeaderPcs)
	local headerSet = {}
	if loopHeaderPcs then
		for _, pc in ipairs(loopHeaderPcs) do headerSet[pc] = true end
	end
	local i = 1
	while i <= #lines do
		local transformed = false
		local lind, lbl = matchLbl(lines[i])
		if lbl and (not loopHeaderPcs or headerSet[lbl]) then
			local lastJ = nil
			-- Also detect the case where the back-jump is wrapped in `if COND then goto LBL end`.
			-- In that case the loop body is empty (a `while not COND do end` no-op) 鈥?we
			-- should NOT lift because the result would be useless.  But we DO want to
			-- lift the bare `goto LBL` form below.
			for j = i + 1, #lines do
				local gi, gTgt = matchGoto(lines[j])
				if gi and gTgt == lbl then
					if #gi < #lind then break end
					lastJ = j
					break
				end
				-- inline if-goto with same target counts too, but we need to handle
				-- it specifically: if the if-goto is at j (deeper or equal indent),
				-- it's the back-edge.  We treat j as lastJ in that case.
				local ifInd, _, ifTgt = matchIfGoto(lines[j])
				if ifInd and ifTgt == lbl then
					if #ifInd < #lind then break end
					lastJ = j
					break
				end
			end
			if lastJ then
				local depth = 0
				for j = i + 1, lastJ - 1 do
					local s = lines[j]:match("^%s*(.-)%s*$")
					if matchLoopOpen(lines[j]) then depth = depth + 1
					elseif s == "end" and depth > 0 then depth = depth - 1 end
				end
				if depth == 0 then
					-- Count references to `lbl` ignoring forward refs (refs that are
					-- BEFORE the label).  Forward refs from earlier blocks (e.g. a
					-- previously-lifted while-true containing `goto LBL`) get
					-- converted to `break` by `gotosToBreak` later, so they don't
					-- prevent us from lifting the back-edge here.
					local extraRefs = false
					for _, r in ipairs(labelRefs(lines, lbl)) do
						if r ~= lastJ and r >= i then extraRefs = true break end
					end
					if not extraRefs then
						local whileInd = lind
						-- Check if lastJ is bare `goto LBL` or inline `if COND then goto LBL end`
						local isBareGoto = matchGoto(lines[lastJ]) ~= nil
						local bodyLines = {}
						for j = i + 1, lastJ - 1 do bodyLines[#bodyLines+1] = lines[j] end
						local lastB = #bodyLines
						while lastB > 0 and not bodyLines[lastB]:match("%S") do lastB = lastB - 1 end
						while #bodyLines > lastB do table.remove(bodyLines) end
						local newBlock
						if isBareGoto then
							-- `::LBL:: BODY goto LBL` -> `while true do BODY end`
							newBlock = {whileInd .. "while true do"}
							for _, bl in ipairs(bodyLines) do newBlock[#newBlock+1] = bl end
							newBlock[#newBlock+1] = whileInd .. "end"
						else
							-- `::LBL:: BODY if COND then goto LBL end` -> `repeat BODY until not COND`
							-- Lua doesn't have `until not COND` syntax issues, but we'll use
							-- `while COND do BODY end` instead (semantically equivalent when BODY
							-- doesn't have side-effects that depend on COND being false).
							-- Actually the precise semantic is:
							--   repeat BODY until not COND
							-- which executes BODY at least once.  If BODY is empty, it becomes
							-- `while COND do end` (no-op-spinning, identical to source).
							-- For safety, use `repeat BODY until not COND` form.
							local _, ifCond = matchIfGoto(lines[lastJ])
							if ifCond then
								newBlock = {whileInd .. "repeat"}
								for _, bl in ipairs(bodyLines) do newBlock[#newBlock+1] = bl end
								newBlock[#newBlock+1] = whileInd .. "until not (" .. ifCond .. ")"
							else
								-- Fallback: shouldn't happen
								newBlock = {whileInd .. "while true do"}
								for _, bl in ipairs(bodyLines) do newBlock[#newBlock+1] = bl end
								newBlock[#newBlock+1] = whileInd .. "end"
							end
						end
						local result = {}
						for k = 1, i - 1 do result[#result+1] = lines[k] end
						for _, bl in ipairs(newBlock) do result[#result+1] = bl end
						for k = lastJ + 1, #lines do result[#result+1] = lines[k] end
						lines = result
						transformed = true
					end
				end
			end
		end
		if not transformed then
			i = i + 1
		end
	end
	return lines
end

-- Lift `if COND then return EXPR1 else return EXPR2 end` -> `return COND and EXPR1 or EXPR2`
-- (or simpler ternary pattern)
local function liftConditionalFallback(lines, indentUnit)
	local changed = false
	local out = {}
	local i = 1
	while i <= #lines do
		local folded = false
		-- pattern: `if COND then return E1 else return E2 end`
		if i + 4 <= #lines then
			local mi, cond = matchIfOpen(lines[i])
			if mi then
				local ei1, r1 = matchReturn(lines[i+1])
				local el2 = lines[i+2]:match("^" .. luaPE(mi) .. "else%s*$")
				local ei3, r2 = matchReturn(lines[i+3])
				local eend = matchEnd(lines[i+4])
				if ei1 and el2 and ei3 and eend and ei1 == mi .. indentUnit and ei3 == mi .. indentUnit and eend == mi then
					local v1 = r1:match("^return%s+(.+)$")
					local v2 = r2:match("^return%s+(.+)$")
					if v1 and v2 then
						local tv1 = v1:match("^%s*(.-)%s*$")
						local tv2 = v2:match("^%s*(.-)%s*$")
						if tv1 == tv2 then
							out[#out+1] = mi .. "return " .. tv1
							i = i + 5
							changed = true
							folded = true
						elseif tv1 == "true" and tv2 == "false" then
							out[#out+1] = mi .. "return " .. cond
							i = i + 5
							changed = true
							folded = true
						elseif tv1 == "false" and tv2 == "true" then
							out[#out+1] = mi .. "return " .. negateCond(cond)
							i = i + 5
							changed = true
							folded = true
						end
					end
				end
			end
		end
		if not folded then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out, changed
end

-- Lift mixed guard-or pair: `if not COND then X = DEFAULT end; BODY using X`
local function liftMixedGuardOrPair(lines, indentUnit)
	local out = {}
	local i = 1
	local changed = false
	while i <= #lines do
		local folded = false
		if i + 4 <= #lines then
			local gi, negCond = lines[i]:match("^(%s*)if%s+not%s+(.+)%s+then%s*$")
			if gi then
				local ai, dv = lines[i+1]:match("^(" .. luaPE(gi .. indentUnit) .. ")(.+)$")
				local ei = matchEnd(lines[i+2])
				if ai and ei and ei == gi then
					local varPat, rhs = dv:match("^([%a_][%a_%d%.]*)%s*=%s*(.+)$")
					local trimmedRhs = rhs and rhs:match("^%s*(.-)%s*$") or nil
					if varPat and rhs and trimmedRhs ~= "nil" then
						-- Pattern: `if not COND then VARPAT = RHS end`
						-- Transform to: `VARPAT = COND or RHS`
						-- (when COND is truthy, VARPAT keeps COND's value; when falsy, RHS).
						-- Safety: VARPAT must be declared `local VARPAT = nil` somewhere earlier
						-- in the same/enclosing scope, and not assigned between the decl and here.
						local prevDecl = false
						local declIdx = nil
						for k = i - 1, math.max(1, i - 30), -1 do
							if out[k] then
								if out[k]:match("^%s*local%s+" .. luaPE(varPat) .. "%s*=%s*nil%s*$") then
									prevDecl = true
									declIdx = k
									break
								end
							end
						end
						-- Also check: VARPAT is not assigned between declIdx and i.
						local notAssignedBetween = true
						if prevDecl and declIdx then
							for k = declIdx + 1, i - 1 do
								if out[k] and out[k]:match("^%s*" .. luaPE(varPat) .. "%s*=%s*") then
									notAssignedBetween = false
									break
								end
							end
						end
						if prevDecl and notAssignedBetween then
							out[#out+1] = gi .. varPat .. " = " .. negCond .. " or " .. rhs
							i = i + 3
							changed = true
							folded = true
						end
					end
				end
			end
		end
		if not folded then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out, changed
end

local function liftShortCircuitGotoElse(lines, indentUnit)
	local i = 1
	while i <= #lines do
		local ind, cond1, thenTarget = matchIfGoto(lines[i])
		local ind2, cond2, elseTarget = matchIfGoto(lines[i + 1] or "")
		if not (ind and ind2 == ind and thenTarget and elseTarget and thenTarget ~= elseTarget) then
			i = i + 1
		else
			local thenLabelIdx = findLabelIndex(lines, thenTarget, i + 2)
			local elseLabelIdx = thenLabelIdx and findLabelIndex(lines, elseTarget, thenLabelIdx + 1) or nil
			local thenRefs = thenTarget and labelRefs(lines, thenTarget) or {}
			local elseRefs = elseTarget and labelRefs(lines, elseTarget) or {}
			local negatedSecond = cond2 and negateCond(cond2) or nil
			local patternOk = thenLabelIdx
				and elseLabelIdx
				and thenLabelIdx < elseLabelIdx
				and #thenRefs == 1 and thenRefs[1] == i
				and #elseRefs == 1 and elseRefs[1] == i + 1
				and negatedSecond
				and not cond1:match("^not[%s%(]")
				and cond2:match("^not[%s%(]")
			if not patternOk then
				i = i + 1
			else
				local gapOk = true
				for k = i + 2, thenLabelIdx - 1 do
					if lines[k]:match("%S") then
						gapOk = false
						break
					end
				end
				local unsafe = not gapOk
				local thenBody = {}
				local thenTail = nil
				if not unsafe then
					for k = thenLabelIdx + 1, elseLabelIdx - 1 do
						thenBody[#thenBody + 1] = lines[k]
						local _, lbl = matchLbl(lines[k])
						local _, gt = matchGoto(lines[k])
						if lbl or gt == thenTarget or gt == elseTarget then
							unsafe = true
							break
						end
					end
					local lastThenIdx = lastNonblankIndex(thenBody)
					thenTail = lastThenIdx and thenBody[lastThenIdx]:match("^%s*(.-)%s*$") or nil
					if thenTail ~= "continue" and thenTail ~= "break" then
						unsafe = true
					end
				end
				local elseEnd = elseLabelIdx + 1
				while not unsafe and elseEnd <= #lines do
					local line = lines[elseEnd]
					local text = line:match("^%s*(.-)%s*$")
					local lineInd = line:match("^(%s*)") or ""
					local _, lbl = matchLbl(line)
					if text ~= "" and #lineInd < #ind then break end
					if lbl and #lineInd <= #ind then break end
					elseEnd = elseEnd + 1
				end
				local elseBody = {}
				local keepTrailingLabel = false
				if not unsafe then
					for k = elseLabelIdx + 1, elseEnd - 1 do
						elseBody[#elseBody + 1] = lines[k]
						local _, lbl = matchLbl(lines[k])
						local _, gt = matchGoto(lines[k])
						if lbl == thenTarget or lbl == elseTarget or gt == thenTarget or gt == elseTarget then
							unsafe = true
							break
						end
						if gt then
							keepTrailingLabel = true
						end
					end
					local firstElseIdx = nil
					for k, bl in ipairs(elseBody) do
						if bl:match("%S") then
							firstElseIdx = k
							break
						end
					end
					local firstElseText = firstElseIdx and elseBody[firstElseIdx]:match("^%s*(.-)%s*$") or nil
					if not firstElseText or not firstElseText:match("^if%s+.+%s+then%s+continue%s+end$") then
						unsafe = true
					end
				end
				if unsafe then
					i = i + 1
				else
					local newBlock = {ind .. "if " .. wrapForAnd(cond1) .. " or " .. wrapForAnd(negatedSecond) .. " then"}
					for _, bl in ipairs(thenBody) do
						newBlock[#newBlock + 1] = bl:match("%S") and (indentUnit .. bl) or bl
					end
					local hasElse = false
					for _, bl in ipairs(elseBody) do
						if bl:match("%S") then
							hasElse = true
							break
						end
					end
					if hasElse then
						newBlock[#newBlock + 1] = ind .. "else"
						for _, bl in ipairs(elseBody) do
							newBlock[#newBlock + 1] = bl:match("%S") and (indentUnit .. bl) or bl
						end
					end
					newBlock[#newBlock + 1] = ind .. "end"
					local result = {}
					for k = 1, i - 1 do result[#result + 1] = lines[k] end
					for _, bl in ipairs(newBlock) do result[#result + 1] = bl end
					if keepTrailingLabel and elseEnd <= #lines then
						local _, trailingLbl = matchLbl(lines[elseEnd])
						if trailingLbl then
							result[#result + 1] = lines[elseEnd]
							elseEnd = elseEnd + 1
						end
					end
					for k = elseEnd, #lines do result[#result + 1] = lines[k] end
					return result, true
				end
			end
		end
	end
	return lines, false
end

-- Lift case chain: `if _rN == V1 then goto J1 end; if _rN == V2 then goto J2 end...`
-- We try to reconstruct an elseif chain from goto-based case dispatch
local function liftIfGotoCaseChains(lines, indentUnit)
	local changed = false
	local i = 1
	while i <= #lines do
		local ii, c0, t0 = matchIfGoto(lines[i])
		local rebuilt = false
		if ii then
			local selector = c0:match("^(.-)%s*==%s*.+$")
			if selector then
				local cases = {{c0, t0}}
				local j = i + 1
				while j <= #lines do
					local ii2, c2, t2 = matchIfGoto(lines[j])
					if not ii2 or ii2 ~= ii then break end
					if not c2:match("^" .. luaPE(selector) .. "%s*==%s*") then break end
					cases[#cases+1] = {c2, t2}
					j = j + 1
				end
				if #cases >= 2 then
					local newBlock = {}
					for k, cas in ipairs(cases) do
						local cond, tgt = cas[1], cas[2]
						if k == 1 then
							newBlock[#newBlock+1] = ii .. "if " .. cond .. " then"
						else
							newBlock[#newBlock+1] = ii .. "elseif " .. cond .. " then"
						end
						newBlock[#newBlock+1] = ii .. indentUnit .. "goto " .. tgt
					end
					newBlock[#newBlock+1] = ii .. "end"
					local result = {}
					for k = 1, i - 1 do result[#result+1] = lines[k] end
					for _, bl in ipairs(newBlock) do result[#result+1] = bl end
					for k = j, #lines do result[#result+1] = lines[k] end
					lines = result
					changed = true
					rebuilt = true
				end
			end
		end
		if not rebuilt then
			i = i + 1
		end
	end
	return lines, changed
end

-- MAIN CONTROL FLOW LIFTER
local function liftControlFlow(lines, indentUnit, loopHeaderPcs)
	if type(lines) == "string" then
		local tmp = {}
		for ln in (lines .. "\n"):gmatch("([^\n]*)\n") do tmp[#tmp+1] = ln end
		lines = tmp
	end
	indentUnit = indentUnit or "\t"

	local function sameLines(a, b)
		if #a ~= #b then return false end
		for i = 1, #a do
			if a[i] ~= b[i] then return false end
		end
		return true
	end

	-- Pass 1: basic single-line structural passes
	lines = rewriteGotoToReturn(lines)
	lines = rewriteSkipReturnAsTruthyReturn(lines)
	lines = collapseTrivialIf(lines)
	lines = rewriteGotoToReturn(lines)
	lines = rewriteSkipReturnAsTruthyReturn(lines)
	lines = normalizeNegativeAddk(lines)
	lines = removeUnreachableAfterReturn(lines)
	lines = dropOrphanLabels(lines)

	for _ = 1, 400 do
		local changed = false
		lines = collapseTrivialIf(lines)
		local newLines, changedGuard = liftGuardChainElse(lines, indentUnit)
		if changedGuard then
			lines = newLines
			changed = true
		else
			local changedFallback = false
			newLines, changedFallback = liftConditionalFallback(lines, indentUnit)
			if changedFallback then
				lines = newLines
				changed = true
			else
				local changedInline = false
				newLines, changedInline = inlineLocalIntoIfGoto(lines, indentUnit)
				if changedInline then
					lines = newLines
					changed = true
				else
					local changedComp = false
					newLines, changedComp = liftComplementaryGuardPair(lines)
					if changedComp then
						lines = newLines
						changed = true
					else
					local changedMixed = false
					newLines, changedMixed = liftMixedGuardOrPair(lines, indentUnit)
					if changedMixed then
						lines = newLines
						changed = true
					else
						local changedCase = false
						newLines, changedCase = liftIfGotoCaseChains(lines, indentUnit)
						if changedCase then
							lines = newLines
							changed = true
						else
							local changedMlif = false
							newLines, changedMlif = liftMultilineIfGotoElse(lines, indentUnit)
							if changedMlif then
								lines = newLines
								changed = true
							end
						end
					end
					end
				end
			end
		end
		if not changed then break end
	end

	-- Pass 2: for loop reconstruction
	for _ = 1, 8 do
		local prev = lines
		lines = liftNumericFor(lines, indentUnit)
		lines = liftGenericFor(lines, indentUnit)
		if sameLines(lines, prev) then break end
	end

	-- Pass 3: while-true reconstruction
	lines = liftWhileTrueFromJumpback(lines, loopHeaderPcs)

	-- Pass 4: goto -> break/continue
	lines = gotosToContinue(lines)
	lines = gotosToBreak(lines)
	for _ = 1, 32 do
		local changedShortCircuit = false
		lines, changedShortCircuit = liftShortCircuitGotoElse(lines, indentUnit)
		if not changedShortCircuit then break end
	end

	-- Pass 5: if/else reconstruction (multi-pass)
	for _ = 1, 128 do
		local prev = lines
		lines = collapseTrivialIf(lines)
		lines = rewriteGotoToReturn(lines)
		lines = rewriteSkipReturnAsTruthyReturn(lines)
		local changedInline = false
		lines, changedInline = inlineLocalIntoIfGoto(lines, indentUnit)
		lines = rewriteSkipReturnAsTruthyReturn(lines)
		local changed1 = false
		lines, changed1 = liftGuardChainElse(lines, indentUnit)
		local changed2 = false
		lines, changed2 = liftMultilineIfGotoElse(lines, indentUnit)
		lines = liftElseifPatterns(lines)
		lines = collapseSingleIfChain(lines)
		lines = dropRedundantNestedSameCond(lines)
		lines = recoverEmptyFieldGuards(lines)
		lines = dropEmptyIfBlocks(lines)
		local changed3 = false
		lines, changed3 = liftIfGotoCaseChains(lines, indentUnit)
		local changed5 = false
		lines, changed5 = liftSimpleGuardChains(lines, indentUnit)
		local changed6 = false
		lines, changed6 = dropGotoToImmediatePostIfLabel(lines)
		local changedComp = false
		lines, changedComp = liftComplementaryGuardPair(lines)
		local changed4 = false
		lines, changed4 = liftIfGotoBody(lines, indentUnit)
		local changed0 = false
		lines, changed0 = liftGuardToSkipLabel(lines, indentUnit)
		local same = (not changedInline) and (not changed0) and (not changed1) and (not changed2) and (not changed3) and (not changed4) and (not changed5) and (not changed6) and (not changedComp)
		if same then
			local eq = #lines == #prev
			if eq then for k = 1, #lines do if lines[k] ~= prev[k] then eq = false; break end end end
			if eq then break end
		end
	end

	-- Pass 6: fallback/guard idioms
	for _ = 1, 8 do
		local changed1, changed2
		lines, changed1 = liftConditionalFallback(lines, indentUnit)
		lines, changed2 = liftMixedGuardOrPair(lines, indentUnit)
		if not changed1 and not changed2 then break end
	end

	-- Pass 7: return/local inlining
	lines = inlineTrivialReturnLocals(lines)
	lines = inlineSingleUseTempLocals(lines)
	lines = inlineTrivialConditionLocals(lines)
	lines = inlineTrivialCompareGuardLocals(lines)
	lines = fixOrDefaultAssignments(lines)
	lines = fixRefreshPreviousUserIdPattern(lines)
	lines = rewriteGotoToReturn(lines)
	lines = foldConstantConditionBlocks(lines, indentUnit)

	-- Pass 8: structural cleanup
	for _ = 1, 8 do
		local prev = lines
		lines = liftNumericFor(lines, indentUnit)
		lines = liftGenericFor(lines, indentUnit)
		if sameLines(lines, prev) then break end
	end
	lines = gotosToContinue(lines)
	lines = gotosToBreak(lines)
	lines = dropEmptyGotoForLoops(lines)
	lines = liftElseifPatterns(lines)
	lines = collapseSingleIfChain(lines)
	lines = dropRedundantNestedSameCond(lines)
	lines = recoverEmptyFieldGuards(lines)
	lines = dropEmptyIfBlocks(lines)
	lines = dropDeadElseClobber(lines)

	-- Pass 9: register temp cleanup
	lines = splitRegisterLifetimes(lines)
	lines = inlineTrivialReturnLocals(lines)

	-- Pass 10: trailing cleanup
	lines = removeUnreachableAfterReturn(lines)
	lines = dropTrailingReturn(lines)
	lines = gotosToContinue(lines)
	lines = gotosToBreak(lines)
	lines = dropOrphanLabels(lines)
	lines = foldTableArrayInitializers(lines)
	lines = foldTableHashInitializers(lines)
	lines = inlineSingleUseTempLocals(lines)
	lines = fixGuardReturnBeforeFallbackLocal(lines)
	lines = fixNilPhiGuardAssignments(lines, indentUnit)
	lines = fixGuardedLookupFallbackReturn(lines)
	lines = dropLoadbArtifacts(lines)
	lines = dropUnknownOpArtifacts(lines)
	lines = dropEmptyIfBlocks(lines)
	lines = fixFindBasePartFallbackReturns(lines)
	lines = fixInvertedIsaGuard(lines)
	lines = fixInvertedFalseyGuard(lines)
	lines = PASSES.fixSelfReferentialNotGuard(lines)
	lines = hoistRepeatedLocals(lines)
	lines = coalesceAlternativeFinds(lines)
	lines = fixBareMethodReferences(lines)
	lines = fixLiteralMethodReceivers(lines)
	lines = fixLiteralFieldReceivers(lines)
	lines = repairInvalidElseClauses(lines)
	lines = restoreFirstMatchLoopBreaks(lines)
	lines = foldConstantConditionBlocks(lines, indentUnit)
	lines = dropLoadbArtifacts(lines)
	lines = dropUnusedGetAttributesLocals(lines)
	lines = dropEmptyIfBlocks(lines)
	lines = removeUnreachableAfterReturn(lines)

	-- Pass 11: indentation normalization
	lines = normalizeLuaIndentation(lines, indentUnit)
	lines = fixInvertedIsaGuard(lines)
	lines = inlineTrivialConditionLocals(lines)
	lines = inlineTrivialCompareGuardLocals(lines)
	lines = inlineSingleUseTempLocals(lines)
	lines = renameTempByCommonAssignedField(lines)
	lines = renameTempFindFirstChildDynamic(lines)
	lines = renameLocalTableByAssignment(lines)
	lines = fixOrDefaultAssignments(lines)
	lines = simplifyEmptyTableDefaults(lines)
	lines = fixRefreshPreviousUserIdPattern(lines)
	lines = renameFallbackIndexUpvalues(lines)
	lines = hoistRepeatedLocals(lines)
	lines = coalesceAlternativeFinds(lines)
	lines = gotosToContinue(lines)
	lines = gotosToBreak(lines)
	lines = dropOrphanLabels(lines)
	lines = fixBareMethodReferences(lines)
	lines = fixLiteralMethodReceivers(lines)
	lines = fixLiteralFieldReceivers(lines)
	lines = repairInvalidElseClauses(lines)
	lines = restoreFirstMatchLoopBreaks(lines)
	lines = foldConstantConditionBlocks(lines, indentUnit)
	lines = dropLoadbArtifacts(lines)
	lines = dropUnusedGetAttributesLocals(lines)
	lines = dropEmptyIfBlocks(lines)
	lines = removeUnreachableAfterReturn(lines)
	lines = balanceLuaBlocksByIndent(lines)
	lines = dropUnmatchedEndLines(lines)
	lines = normalizeLuaIndentation(lines, indentUnit)
	lines = fixInvertedFalseyGuard(lines)
	lines = PASSES.fixSelfReferentialNotGuard(lines)
	lines = PASSES.dropDeadUnusedLocals(lines)
	lines = dropDeadElseClobber(lines)
	lines = dropUnknownOpArtifacts(lines)
	lines = dropUnusedGetAttributesLocals(lines)
	lines = dropEmptyIfBlocks(lines)
	for _ = 1, 16 do
		local changed
		lines, changed = wrapOrphanIfGotosAsGuards(lines, indentUnit)
		if not changed then break end
	end
	for _ = 1, 16 do
		local changedMlif
		lines, changedMlif = liftMultilineIfGotoElse(lines, indentUnit)
		if not changedMlif then break end
		lines = liftElseifPatterns(lines)
		lines = dropOrphanLabels(lines)
	end
	lines = dropInvalidTopLevelReturns(lines)
	lines = fixInvalidGenericForHeaders(lines)
	lines = normalizeLuaIndentation(lines, indentUnit)
	lines = foldTableHashInitializers(lines)
	lines = dropSelfAssignmentNoops(lines)
	lines = fixGuardReturnBeforeFallbackLocal(lines)
	lines = normalizeLuaIndentation(lines, indentUnit)

	return table.concat(lines, "\n")
end

local function decompileProto(p, bc, protoIdx)
	local isMain = protoIdx == bc.main_id
	local baseIndent = isMain and "" or "\t"
	local out = {}

	local name = p.debugname ~= "" and cleanIdent(p.debugname) or ("anon" .. tostring(protoIdx))
	local params = {}
	for i = 0, p.numparams - 1 do
		push(params, localAt(p, i, 0) or ("arg" .. tostring(i)))
	end
	if p.is_vararg then
		push(params, "...")
	end

	if isMain then
		push(out, "-- main chunk (proto[" .. tostring(protoIdx) .. "], line " .. tostring(p.linedefined) .. ")")
	else
		local upvalues = #p.upvalues > 0 and ("  -- upvalues: " .. table.concat(p.upvalues, ", ")) or ""
		push(out, "local function " .. name .. "(" .. table.concat(params, ", ") .. ") -- proto[" .. tostring(protoIdx) .. "], line " .. tostring(p.linedefined) .. upvalues)
	end

	local bodyIndent = baseIndent .. (isMain and "" or "\t")
	local regs = {}
	for i, paramName in ipairs(params) do
		if paramName ~= "..." then
			regs[i - 1] = paramName
		end
	end
	local generatedNameFor = makeGeneratedNameAllocator(p, params, name)
	local renameHints = bc.upvalueRenameHints and bc.upvalueRenameHints[protoIdx] or nil
	local flowAnalysis = nil
	local okFlow, flowOrErr = pcall(analyzeProtoFlow, p, bc)
	if okFlow and type(flowOrErr) == "table" then
		flowAnalysis = flowOrErr
		applyPhiLocvarHints(p, flowAnalysis, false)
	end

	local targets = scanJumpTargets(p)
	local pendingClosureTarget = nil
	local pendingClosureProtoId = nil
	local pendingClosureCaps = {}
	local protoMaterialized = {}
	local pc = 0
	local codeLen = #p.code

	local function flushPendingClosure()
		if pendingClosureTarget == nil then
			return
		end
		local childProto = pendingClosureProtoId ~= nil and protoAt(bc, pendingClosureProtoId) or nil
		local closureName = childProto and cleanIdent(childProto.debugname) or nil
		if not closureName or closureName == "" then
			closureName = pendingClosureProtoId ~= nil and ("anon" .. tostring(pendingClosureProtoId)) or "anon_unknown"
		end
		regs[pendingClosureTarget] = closureName
		regs.__closureWriteCaptures = regs.__closureWriteCaptures or {}
		-- Always emit a `-- closureName captures: ...` marker, even for zero-capture
		-- closures.  The marker is consumed by `spliceHoistedChild` to inline the
		-- proto definition at the point where it was originally created.  Without
		-- this, zero-capture closures (e.g. `Connect(function() ... end)` with no
		-- upvalues) would stay at the top of the file instead of being placed at
		-- their natural source position inside the main chunk.
		do
			local capDescs = {}
			local hasParentCapture = false
			local materialized = protoMaterialized
			local writableCaptures = nil
			local childRenameHints = bc.upvalueRenameHints and pendingClosureProtoId ~= nil and bc.upvalueRenameHints[pendingClosureProtoId] or nil
			for capIdx, cap in ipairs(pendingClosureCaps) do
				local childUpvalue = childProto and childProto.upvalues[capIdx] or nil
				local semanticUpvalue = childUpvalue
				if childRenameHints and type(semanticUpvalue) == "string" and childRenameHints[semanticUpvalue] and isValidIdent(childRenameHints[semanticUpvalue]) then
					semanticUpvalue = childRenameHints[semanticUpvalue]
				elseif childRenameHints and type(cap.expr) == "string" and childRenameHints[cap.expr] and isValidIdent(childRenameHints[cap.expr]) then
					semanticUpvalue = childRenameHints[cap.expr]
				end
				if isFallbackUpvalueName(semanticUpvalue) and cap.semanticName and isValidIdent(cap.semanticName) then
					semanticUpvalue = cap.semanticName
					if childProto then
						childProto.upvalues[capIdx] = semanticUpvalue
					end
				end
				if type(semanticUpvalue) == "string" and semanticUpvalue ~= "" and not isFallbackUpvalueName(semanticUpvalue) then
					if (cap.kind == "VAL" or cap.kind == "REF" or cap.kind == "UPVAL" or cap.kind == "UPREF")
						and isValidIdent(semanticUpvalue)
						and type(cap.expr) == "string"
						and cap.expr ~= semanticUpvalue
						and not materialized[semanticUpvalue]
					then
						push(out, bodyIndent .. "local " .. semanticUpvalue .. " = " .. cap.expr)
						materialized[semanticUpvalue] = true
					end
					push(capDescs, semanticUpvalue)
				else
					push(capDescs, cap.expr)
				end
				if pendingClosureProtoId ~= nil
					and (cap.kind == "VAL" or cap.kind == "REF")
					and childWritesUpvalue(bc, pendingClosureProtoId, capIdx - 1)
					and type(cap.reg) == "number"
					and type(cap.captureName or cap.semanticName or cap.expr) == "string"
					and isValidIdent(cap.captureName or cap.semanticName or cap.expr)
				then
					writableCaptures = writableCaptures or {}
					push(writableCaptures, {
						reg = cap.reg,
						name = cap.captureName or cap.semanticName or cap.expr,
					})
				end
				if cap.kind == "VAL" or cap.kind == "REF" or cap.kind == "UPVAL" or cap.kind == "UPREF" then
					hasParentCapture = true
				end
			end
			if writableCaptures and #writableCaptures > 0 then
				regs.__closureWriteCaptures[closureName] = writableCaptures
			end
			local tag = hasParentCapture and " [parent-local capture]" or ""
			push(out, bodyIndent .. "-- " .. closureName .. " captures: " .. table.concat(capDescs, ", ") .. tag)
		end
		pendingClosureTarget = nil
		pendingClosureProtoId = nil
		pendingClosureCaps = {}
	end

	while pc < codeLen do
		if targets[pc] then
			push(out, bodyIndent .. "::pc" .. tostring(pc) .. "::")
		end

		local insn = codeWordAt(p, pc)
		local op = bit32_band(insn, 0xFF)
		local opName = OPCODES[op] or ("ROBLOX_OP_" .. tostring(op))
		local a = bit32_band(bit32_rshift(insn, 8), 0xFF)
		local b = bit32_band(bit32_rshift(insn, 16), 0xFF)
		local c = bit32_band(bit32_rshift(insn, 24), 0xFF)
		local d = decodeSignedD(insn)
		local e = decodeSignedE(insn)
		local aux = nil
		if OPS_WITH_AUX[opName] and pc + 1 < codeLen then
			aux = codeWordAt(p, pc + 1)
		end

		local handledCapture = false
		if opName == "CAPTURE" and pendingClosureTarget ~= nil then
			local kind = CAPTURE_KINDS[a] or ("?" .. tostring(a))
			if kind == "VAL" or kind == "REF" then
				local capIdx = #pendingClosureCaps
				local semanticName = pendingClosureProtoId ~= nil and (deriveSetupvalWriteName(bc, pendingClosureProtoId, capIdx) or deriveUpvalueSemanticName(bc, pendingClosureProtoId, capIdx, {})) or nil
				local capExpr = regRepr(regs, p, b, pc)
				local captureName = localAt(p, b, pc) or localAt(p, b, math.max(0, pc - 1))
				if not (type(captureName) == "string" and isValidIdent(captureName)) then
					captureName = type(capExpr) == "string" and isValidIdent(capExpr) and capExpr or nil
				end
				push(pendingClosureCaps, {
					kind = kind,
					expr = capExpr,
					reg = b,
					captureName = captureName,
					semanticName = semanticName,
				})
			else
				push(pendingClosureCaps, {
					kind = kind,
					expr = p.upvalues[b + 1] or ("U" .. tostring(b)),
				})
			end
			pc = pc + 1
			handledCapture = true
		elseif pendingClosureTarget ~= nil then
			flushPendingClosure()
		end

		if not handledCapture then
			-- Flush stale inline references: if this instruction will overwrite
			-- regs[a] AND oldName is a materialized variable (has been emitted
			-- as an assignment target), AND other pending inline expressions in
			-- regs[] reference oldName, materialize those expressions first.
			local oldName = regs[a]
			if type(oldName) == "string" and isValidIdent(oldName) and oldName ~= ("R" .. tostring(a)) then
				local writesA = (opName == "MOVE" or opName == "GETTABLEKS" or opName == "GETTABLEN"
					or opName == "GETTABLE" or opName == "GETIMPORT" or opName == "GETUPVAL"
					or opName == "LOADK" or opName == "LOADN" or opName == "LOADB" or opName == "LOADNIL"
					or opName == "LOADKX" or opName == "ADD" or opName == "SUB" or opName == "MUL"
					or opName == "DIV" or opName == "MOD" or opName == "POW" or opName == "IDIV"
					or opName == "ADDK" or opName == "SUBK" or opName == "MULK" or opName == "DIVK"
					or opName == "MODK" or opName == "POWK" or opName == "SUBRK" or opName == "DIVRK"
					or opName == "CONCAT" or opName == "MINUS" or opName == "LENGTH" or opName == "NOT"
					or opName == "NEWTABLE" or opName == "DUPTABLE" or opName == "AND" or opName == "OR"
					or opName == "ANDK" or opName == "ORK")
				if writesA then
					-- Only flush if oldName was previously materialized (emitted as
					-- an assignment target).  Pure inline expressions (not yet output)
					-- don't need flushing since they haven't been "named" in the output.
					local isMaterialized = localAt(p, a, pc) == oldName
						or localAt(p, a, math.max(0, pc - 1)) == oldName
						or (regs.__materialized and regs.__materialized[oldName])
					if isMaterialized then
						local pat = "%f[%a_]" .. oldName .. "%f[^%a_%d]"
						for reg, expr in pairs(regs) do
							if type(reg) == "number" and reg ~= a and type(expr) == "string"
								and not isValidIdent(expr) and expr:find(pat)
							then
								local matName = generatedNameFor and generatedNameFor(oldName .. "_val", "_r" .. tostring(reg)) or ("_r" .. tostring(reg))
								push(out, bodyIndent .. "local " .. matName .. " = " .. expr)
								regs[reg] = matName
								regs.__materialized = regs.__materialized or {}
								regs.__materialized[matName] = true
							end
						end
					end
				end
			end
			local line, advanceExtra = emitDecompileLine(pc, opName, a, b, c, d, e, aux, p, bc, regs, bodyIndent, generatedNameFor, name, renameHints, flowAnalysis)
			if opName == "NEWCLOSURE" then
				pendingClosureTarget = a
				pendingClosureProtoId = childProtoIdAt(p, d)
				pendingClosureCaps = {}
			elseif opName == "DUPCLOSURE" then
				pendingClosureTarget = a
				local closureConst = constantAt(p, d)
				pendingClosureProtoId = closureConst and closureConst.kind == "closure" and closureConst.value or nil
				pendingClosureCaps = {}
			end
			if line then
				push(out, line)
				-- Track materialized names: if this line assigns to regs[a] and
				-- regs[a] is a valid identifier, mark it as materialized.
				local curName = regs[a]
				if type(curName) == "string" and isValidIdent(curName) and curName ~= ("R" .. tostring(a)) then
					regs.__materialized = regs.__materialized or {}
					regs.__materialized[curName] = true
				end
			end
			pc = pc + getOpLength(opName) + advanceExtra
		end
	end

	flushPendingClosure()

	if not isMain then
		push(out, "end")
	end

	local decompIndent = isMain and "\t" or (baseIndent .. "\t")
	return liftControlFlow(out, decompIndent, nil)
end

local function renderDisassembly(bc)
	local out = { "-- ============== DISASSEMBLY ==============" }
	for protoIdx = 0, #bc.protos - 1 do
		push(out, disassembleProto(protoAt(bc, protoIdx), bc, protoIdx))
		push(out, "")
	end
	return table.concat(out, "\n")
end

local function identifyHoistTargets(bc)
	local result = {}
	local function addTarget(parentId, childId, already)
		if type(childId) ~= "number" then return end
		if childId < 0 or childId >= #bc.protos then return end
		if childId == parentId then return end
		if already[childId] then return end
		if not result[parentId] then result[parentId] = {} end
		push(result[parentId], childId)
		already[childId] = true
	end
	-- Scan every proto (including the main chunk) for NEWCLOSURE/DUPCLOSURE
	-- instructions and record `child` as a hoist target of its `parent`. For the
	-- main chunk, treat all closures it creates as hoist candidates regardless
	-- of whether they capture any local: this way `local function FOO() ... end`
	-- definitions are inlined into the main chunk in the position where they
	-- actually appear in the original source, instead of being emitted as a flat
	-- list above the main chunk.
	for parentId = 0, #bc.protos - 1 do
		local p = protoAt(bc, parentId)
		local pc = 0
		local pendingChild = nil
		local hasParentCap = false
		local already = {}
		local mainChunk = (parentId == bc.main_id)
		while p and pc < #p.code do
			local insn = codeWordAt(p, pc)
			local op = bit32_band(insn, 0xFF)
			local opName = OPCODES[op] or ""
			if opName == "NEWCLOSURE" or opName == "DUPCLOSURE" then
				if pendingChild ~= nil and (hasParentCap or mainChunk) and not already[pendingChild] then
					addTarget(parentId, pendingChild, already)
				end
				local d = decodeSignedD(insn)
				if opName == "NEWCLOSURE" then
					pendingChild = childProtoIdAt(p, d)
				else
					local closureConst = constantAt(p, d)
					pendingChild = closureConst and closureConst.kind == "closure" and closureConst.value or nil
				end
				hasParentCap = false
			elseif opName == "CAPTURE" and pendingChild ~= nil then
				local kindId = bit32_band(bit32_rshift(insn, 8), 0xFF)
				local kind = CAPTURE_KINDS[kindId] or ""
				if kind == "VAL" or kind == "REF" or kind == "UPVAL" or kind == "UPREF" then
					hasParentCap = true
				end
			elseif opName ~= "CAPTURE" then
				if pendingChild ~= nil and (hasParentCap or mainChunk) and not already[pendingChild] then
					addTarget(parentId, pendingChild, already)
				end
				pendingChild = nil
				hasParentCap = false
			end
			pc = pc + (opName ~= "" and getOpLength(opName) or 1)
		end
		if pendingChild ~= nil and (hasParentCap or mainChunk) and not already[pendingChild] then
			addTarget(parentId, pendingChild, already)
		end
	end
	return result
end

local function spliceHoistedChild(parentBody, childName, childBody)
	if type(parentBody) ~= "string" or type(childBody) ~= "string" then
		return parentBody, false
	end
	if childBody:match("^%s*$") then
		return parentBody, false
	end
	local parentLines = {}
	for ln in (parentBody .. "\n"):gmatch("([^\n]*)\n") do parentLines[#parentLines+1] = ln end
	local childLines = {}
	for ln in (childBody .. "\n"):gmatch("([^\n]*)\n") do childLines[#childLines+1] = ln end
	local out = {}
	local spliced = false
	local namePat = luaPE(childName)
	for _, ln in ipairs(parentLines) do
		if ln:match("^%s*local%s+function%s+" .. namePat .. "%f[^%w_]") then
			return parentBody, false
		end
	end
	for _, ln in ipairs(parentLines) do
		if not spliced then
			-- Splice marker is `-- ChildName captures: ...` optionally followed by
			-- `[parent-local capture]`. The trailing tag is required for non-main
			-- hoists (so we never accidentally splice into an unrelated parent),
			-- but for closures emitted by the main chunk we accept the bare
			-- `captures:` line too because zero-capture closures (e.g. anon1 used
			-- only as a `:Connect(anon1)` argument) never get tagged.
			local indent = ln:match("^(%s*)%-%-%s+" .. namePat .. "%s+captures:.*%[parent%-local capture%]%s*$")
				or ln:match("^(%s*)%-%-%s+" .. namePat .. "%s+captures:.*$")
			if indent then
				for _, cl in ipairs(childLines) do
					out[#out+1] = cl ~= "" and (indent .. cl) or cl
				end
				spliced = true
			else
				out[#out+1] = ln
			end
		else
			out[#out+1] = ln
		end
	end
	return table.concat(out, "\n"), spliced
end

local function stripParentLocalCaptureTags(body)
	return (body:gsub("%s*%[parent%-local capture%]", ""))
end

PASSES.applyUpvalueRenameHints = function(body, hints)
	if type(body) ~= "string" or type(hints) ~= "table" then
		return body
	end
	local lines = {}
	for line in (body .. "\n"):gmatch("(.-)\n") do
		for oldName, newName in pairs(hints) do
			if type(oldName) == "string" and type(newName) == "string" and isValidIdent(newName) then
				line = renameIdentOutsideStrings(line, oldName, newName)
			end
		end
		lines[#lines+1] = line
	end
	return table.concat(lines, "\n")
end
local function applyUpvalueRenameHints(body, hints)
	return PASSES.applyUpvalueRenameHints(body, hints)
end

PASSES.predeclareHoistedUpvalues = function(lines)
	local mainIdx = nil
	for i, line in ipairs(lines) do
		if line:match("^%-%- main chunk%s*%(") then
			mainIdx = i
			break
		end
	end
	if not mainIdx then return lines end
	local needed = {}
	local order = {}
	local topLevelFunctions = {}
	for i = 1, mainIdx - 1 do
		local ind = lines[i]:match("^(%s*)") or ""
		local fname = ind == "" and lines[i]:match("^local%s+function%s+([%a_][%w_]*)%s*%(") or nil
		if fname then
			topLevelFunctions[fname] = true
		end
		local upvalueText = ind == "" and lines[i]:match("^local%s+function%s+.-%-%-%s+upvalues:%s+(.+)$") or nil
		if upvalueText then
			for raw in upvalueText:gmatch("[^,]+") do
				local name = raw:match("^%s*(.-)%s*$")
				if isValidIdent(name)
					and name ~= "nil"
					and name ~= "true"
					and name ~= "false"
					and not isFallbackUpvalueName(name)
					and not topLevelFunctions[name]
					and not needed[name]
					and not name:match("^_[kv]$")
					and not name:match("^_[kv]_%d+$")
				then
					needed[name] = true
					order[#order+1] = name
				end
			end
		end
	end
	if #order == 0 then return lines end
	local declaredBeforeFunctions = {}
	local insertIdx = mainIdx
	for i = 1, mainIdx - 1 do
		local fname = lines[i]:match("^local%s+function%s+([%a_][%w_]*)%s*%(")
		if fname then
			insertIdx = i
			break
		end
		local declNames = lines[i]:match("^local%s+([%a_][%w_,%s]*)%s*$")
		if not declNames then
			declNames = lines[i]:match("^local%s+([%a_][%w_,%s]*)%s*=")
		end
		if declNames then
			for name in declNames:gmatch("[%a_][%w_]*") do
				declaredBeforeFunctions[name] = true
			end
		end
	end
	for name in pairs(topLevelFunctions) do
		declaredBeforeFunctions[name] = true
	end
	local toDeclare = {}
	for _, name in ipairs(order) do
		if not declaredBeforeFunctions[name] then
			toDeclare[#toDeclare+1] = name
			declaredBeforeFunctions[name] = true
		end
	end
	local out = {}
	for i = 1, #lines do
		if i == insertIdx and #toDeclare > 0 then
			out[#out+1] = "local " .. table.concat(toDeclare, ", ")
		end
		local line = lines[i]
		if i >= mainIdx then
			local ind, name, rhs = line:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(.+)$")
			if ind and needed[name] and rhs then
				line = ind .. name .. " = " .. rhs
			end
		end
		out[#out+1] = line
	end
	return out
end

PASSES.foldPcallRequireUpvalueWriters = function(lines)
	local out = {}
	local captureNames = {}
	local i = 1
	while i <= #lines do
		local fname, upvalueText = lines[i]:match("^local%s+function%s+([%a_][%w_]*)%s*%b()%s*%-%-.*%-%-%s+upvalues:%s+(.+)$")
		if fname and i + 2 <= #lines then
			local ind, localName, rhs = lines[i + 1]:match("^(%s*)local%s+([%a_][%w_]*)%s*=%s*(require%s*%(.+%))%s*$")
			local upvalueName, assignedName = lines[i + 2]:match("^%s*([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*$")
			if ind and localName and rhs and assignedName == localName and isFallbackUpvalueName(upvalueName) then
				local rewritten = {}
				for raw in upvalueText:gmatch("[^,]+") do
					local name = raw:match("^%s*(.-)%s*$")
					if name == upvalueName then name = localName end
					rewritten[#rewritten+1] = name
				end
				local newHeader = lines[i]:gsub("%-%-%s+upvalues:%s+.+$", "-- upvalues: " .. table.concat(rewritten, ", "))
				out[#out+1] = newHeader
				out[#out+1] = ind .. localName .. " = " .. rhs
				captureNames[fname] = localName
				i = i + 3
				continue
			end
		end
		out[#out+1] = lines[i]
		i = i + 1
	end
	for idx, line in ipairs(out) do
		local fname = line:match("^%s*%-%-%s+([%a_][%w_]*)%s+captures:%s+")
		local captureName = fname and captureNames[fname] or nil
		if captureName then
			out[idx] = line:gsub("captures:%s*nil", "captures: " .. captureName, 1)
		end
	end
	return out
end

local function stripLineComment(line)
	local quote = nil
	local i = 1
	while i <= #line do
		local ch = line:sub(i, i)
		if quote then
			if ch == "\\" and i + 1 <= #line then
				i = i + 2
			else
				if ch == quote then quote = nil end
				i = i + 1
			end
		elseif ch == '"' or ch == "'" then
			quote = ch
			i = i + 1
		elseif ch == "[" and line:sub(i, i + 1) == "[[" then
			local closePos = line:find("]]", i + 2, true)
			if closePos then
				i = closePos + 2
			else
				return line
			end
		elseif ch == "-" and line:sub(i + 1, i + 1) == "-" then
			return (line:sub(1, i - 1):gsub("%s+$", ""))
		else
			i = i + 1
		end
	end
	return line
end

local function stripGeneratedComments(text)
	local out = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local stripped = stripLineComment(line)
		if stripped:find("%S") then
			out[#out+1] = stripped
		elseif not line:find("%-%-", 1, true) then
			out[#out+1] = stripped
		end
	end
	while #out > 0 and not out[1]:find("%S") do
		table.remove(out, 1)
	end
	while #out > 0 and not out[#out]:find("%S") do
		out[#out] = nil
	end
	return table.concat(out, "\n")
end

local function isSingleLineBlockText(text)
	return text:match("^if%s+.+%s+then%s+.+%s+end$") ~= nil
		or text:match("^for%s+.+%s+do%s+.+%s+end$") ~= nil
		or text:match("^while%s+.+%s+do%s+.+%s+end$") ~= nil
end

local function opensBlockText(text)
	if isSingleLineBlockText(text) then return nil end
	if text:match("^if%s+.+%s+then$") then return "if" end
	if text:match("^for%s+.+%s+do$") or text:match("^while%s+.+%s+do$") or text == "do" then return "block" end
	if text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]") then
		if not text:match("end%s*$") then return "block" end
	end
	if text == "repeat" then return "repeat" end
	return nil
end

local function closeBlockText(text, stack)
	if text == "end" then
		if #stack > 0 and stack[#stack] ~= "repeat" then
			table.remove(stack)
		end
		return
	end
	if text:match("^until%s+") then
		if #stack > 0 and stack[#stack] == "repeat" then
			table.remove(stack)
		end
	end
end

PASSES.fixCameraModuleActivateController = function(lines, indentUnit)
	-- DELETED: this pass was a hardcoded special-case for Roblox's CameraModule
	-- ActivateCameraController function. It violated AGENTS.md by:
	--   1. Matching by hardcoded function name ("ActivateCameraController")
	--   2. Matching by hardcoded PC labels ("goto pc76"/"goto pc99")
	--   3. Emitting the entire function body as literal Roblox source code
	--      (with hardcoded Enum.CameraType.*, Enum.ComputerCameraMovementMode.*,
	--      method names like :GetCameraMovementModeFromSettings, etc.)
	-- A proper fix needs to be a generic structural recovery in the lift
	-- pipeline. For now, the input is passed through unchanged and the
	-- generic decompiler output is used (with whatever artifacts remain).
	return lines
end

local function lineHasAnyIdent(line, names)
	if type(line) ~= "string" or not names then return false end
	local text = line
	local commentPos = text:find("%-%-")
	if commentPos then
		text = text:sub(1, commentPos - 1)
	end
	for name in pairs(names) do
		local searchFrom = 1
		while true do
			local s, e = text:find(identPat(name), searchFrom)
			if not s then break end
			local prev = s > 1 and text:sub(s - 1, s - 1) or ""
			if prev ~= "." and prev ~= ":" then
				return true
			end
			searchFrom = e + 1
		end
	end
	return false
end

PASSES.reattachLeakedFunctionTails = function(lines, indentUnit)
	local out = {}
	local i = 1
	while i <= #lines do
		local line = lines[i]
		local headerIndent, paramText = line:match("^(%s*)local%s+function%s+[%a_][%w_]*%s*%(([^)]*)%)")
		if headerIndent == "" and paramText then
			local params = {}
			for name in paramText:gmatch("[%a_][%w_]*") do
				if name ~= "..." then
					params[name] = true
				end
			end
			if next(params) ~= nil then
				local stack = { "block" }
				local endIdx = nil
				local j = i + 1
				while j <= #lines do
					local text = lines[j]:match("^%s*(.-)%s*$")
					if text ~= "" and text:sub(1, 2) ~= "--" then
						if text == "end" or text:match("^until%s+") then
							closeBlockText(text, stack)
						elseif text ~= "else" and not text:match("^elseif%s+.+%s+then$") then
							local kind = opensBlockText(text)
							if kind then stack[#stack+1] = kind end
						end
					end
					if #stack == 0 then
						endIdx = j
						break
					end
					j = j + 1
				end
				if endIdx and endIdx + 1 <= #lines then
					local tailStart = endIdx + 1
					while tailStart <= #lines and not lines[tailStart]:match("%S") do
						tailStart = tailStart + 1
					end
					local firstTailText = tailStart <= #lines and lines[tailStart]:match("^%s*(.-)%s*$") or ""
					if tailStart <= #lines
						and (lines[tailStart]:match("^(%s*)") or "") == ""
						and not firstTailText:match("^local%s+function%f[%W]")
						and not firstTailText:match("^function%f[%W]")
						and lineHasAnyIdent(lines[tailStart], params)
					then
						local tailStack = {}
						local tailEnd = nil
						local k = tailStart
						while k <= #lines do
							local tailLine = lines[k]
							local text = tailLine:match("^%s*(.-)%s*$")
							local ind = tailLine:match("^(%s*)") or ""
							if text == "" then
								local nextIdx = k + 1
								while nextIdx <= #lines and not lines[nextIdx]:match("%S") do
									nextIdx = nextIdx + 1
								end
								local nextText = nextIdx <= #lines and lines[nextIdx]:match("^%s*(.-)%s*$") or ""
								local nextInd = nextIdx <= #lines and (lines[nextIdx]:match("^(%s*)") or "") or ""
								if #tailStack == 0 and nextInd == "" and (nextText:match("^local%s+function%f[%W]") or nextText:match("^local%s+[%a_][%w_]*%s*$") or nextText:match("^%-%-%s+[%a_][%w_]*%s+captures:")) then
									tailEnd = k - 1
									break
								end
							elseif #tailStack == 0 and ind == "" and k > tailStart and (text:match("^local%s+function%f[%W]") or text:match("^local%s+[%a_][%w_]*%s*$") or text:match("^%-%-%s+[%a_][%w_]*%s+captures:")) then
								tailEnd = k - 1
								break
							end
							if text ~= "" and text:sub(1, 2) ~= "--" then
								if text == "end" or text:match("^until%s+") then
									closeBlockText(text, tailStack)
								elseif text ~= "else" and not text:match("^elseif%s+.+%s+then$") then
									local kind = opensBlockText(text)
									if kind then tailStack[#tailStack+1] = kind end
								end
							end
							k = k + 1
						end
						if not tailEnd then tailEnd = #lines end
						if tailEnd >= tailStart and #tailStack == 0 then
							for copyIdx = i, endIdx - 1 do
								out[#out+1] = lines[copyIdx]
							end
							for copyIdx = tailStart, tailEnd do
								if lines[copyIdx]:match("%S") then
									out[#out+1] = indentUnit .. lines[copyIdx]
								else
									out[#out+1] = lines[copyIdx]
								end
							end
							out[#out+1] = lines[endIdx]
							i = tailEnd + 1
							continue
						end
					end
				end
			end
		end
		out[#out+1] = line
		i = i + 1
	end
	return out
end

PASSES.fixSplitFallbackObjectAlias = function(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		if i + 4 <= #lines then
			local ind, cond = lines[i]:match("^(%s*)if%s+(.+)%s+then%s*$")
			if ind and cond then
				local assignIdx = nil
				local assignedName = nil
				local endIdx = nil
				local j = i + 1
				while j <= #lines do
					local text = lines[j]:match("^%s*(.-)%s*$")
					local lineInd = lines[j]:match("^(%s*)") or ""
					if text == "" then
						j = j + 1
					elseif lineInd == ind and text == "end" then
						endIdx = j
						break
					elseif assignIdx == nil then
						local aName = lines[j]:match("^%s*([%a_][%w_]*)%s*=%s*.+$")
						if aName and not lines[j]:match("^%s*local%s+") then
							assignIdx = j
							assignedName = aName
						end
						j = j + 1
					else
						j = j + 1
					end
				end
				if assignedName and endIdx then
					local nextIdx = endIdx + 1
					while nextIdx <= #lines and not lines[nextIdx]:match("%S") do
						nextIdx = nextIdx + 1
					end
					local notName = nextIdx <= #lines and (
						lines[nextIdx]:match("^" .. luaPE(ind) .. "if%s+not%s+%(%s*([%a_][%w_]*)%s*%)%s+then%s*$")
						or lines[nextIdx]:match("^" .. luaPE(ind) .. "if%s+not%s+([%a_][%w_]*)%s+then%s*$")
					) or nil
					if notName == assignedName then
						local fallbackName = nil
						local blockEnd = nil
						local k = nextIdx + 1
						while k <= #lines do
							local text = lines[k]:match("^%s*(.-)%s*$")
							local lineInd = lines[k]:match("^(%s*)") or ""
							if text == "" then
								k = k + 1
							elseif lineInd == ind and text == "end" then
								blockEnd = k
								break
							elseif not fallbackName then
								fallbackName = lines[k]:match("^%s*([%a_][%w_]*)%s*=%s*Instance%.new%s*%(")
								k = k + 1
							else
								k = k + 1
							end
						end
						if fallbackName and fallbackName ~= assignedName and blockEnd then
							local afterIdx = blockEnd + 1
							while afterIdx <= #lines and not lines[afterIdx]:match("%S") do
								afterIdx = afterIdx + 1
							end
							if afterIdx <= #lines and lines[afterIdx]:find(identPat(fallbackName)) then
								for copyIdx = i, endIdx do
									out[#out+1] = lines[copyIdx]
								end
								if lines[endIdx + 1] and lines[endIdx + 1]:match("^%s*$") then
									out[#out+1] = lines[endIdx + 1]
								end
								out[#out+1] = ind .. fallbackName .. " = " .. assignedName
								i = endIdx + 1
								if lines[i] and lines[i]:match("^%s*$") then
									i = i + 1
								end
								continue
							end
						end
					end
				end
			end
		end
		out[#out+1] = lines[i]
		i = i + 1
	end
	return out
end

PASSES.hoistLocalsUsedOutsideDeclBlock = function(lines)
	if #lines == 0 then return lines end
	local function processSegment(segment)
		if #segment == 0 then return segment end
		local decls = {}
		local topDeclared = {}
		local headerParams = segment[1] and segment[1]:match("%(([^)]*)%)") or nil
		if headerParams then
			for paramName in headerParams:gmatch("[%a_][%w_]*") do
				if paramName ~= "..." then
					topDeclared[paramName] = true
				end
			end
		end
		local stack = {}
		local functionDepth = 0
		for i, line in ipairs(segment) do
			local text = line:match("^%s*(.-)%s*$")
			local name = line:match("^%s*local%s+([%a_][%w_]*)%s*=")
			if name then
				local depth = #stack
				if depth <= 1 then
					topDeclared[name] = true
				elseif functionDepth <= 1 then
					decls[#decls+1] = { idx = i, name = name, depth = depth }
				end
			end
			if text ~= "" and text:sub(1, 2) ~= "--" then
				if text == "end" or text:match("^until%s+") then
					local closing = stack[#stack]
					if closing then
						if closing == "function" and functionDepth > 0 then
							functionDepth = functionDepth - 1
						end
						table.remove(stack)
					end
				elseif text ~= "else" and not text:match("^elseif%s+.+%s+then$") then
					local kind = opensBlockText(text)
					if kind then
						if text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]") then
							stack[#stack+1] = "function"
							functionDepth = functionDepth + 1
						else
							stack[#stack+1] = kind
						end
					end
				end
			end
		end
		if #decls == 0 then return segment end
		local toHoist = {}
		local hoistOrder = {}
		for _, decl in ipairs(decls) do
			local depth2 = 0
			for j = 1, #segment do
				local text = segment[j]:match("^%s*(.-)%s*$")
				if j > decl.idx
					and depth2 < decl.depth
					and not segment[j]:match("^%s*local%s+" .. luaPE(decl.name) .. "%f[^%a_%d]")
					and lineHasAnyIdent(segment[j], { [decl.name] = true })
				then
					if not toHoist[decl.name] and not topDeclared[decl.name] then
						toHoist[decl.name] = true
						hoistOrder[#hoistOrder+1] = decl.name
					end
					break
				end
				if text ~= "" and text:sub(1, 2) ~= "--" then
					if text == "end" or text:match("^until%s+") then
						if depth2 > 0 then depth2 = depth2 - 1 end
					elseif text ~= "else" and not text:match("^elseif%s+.+%s+then$") then
						if opensBlockText(text) then depth2 = depth2 + 1 end
					end
				end
			end
		end
		if #hoistOrder == 0 then return segment end
		local insertIdx = 1
		for i, line in ipairs(segment) do
			local text = line:match("^%s*(.-)%s*$")
			if text ~= "" and text:sub(1, 2) ~= "--" then
				insertIdx = (text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]")) and (i + 1) or i
				break
			end
		end
		local out = {}
		for i, line in ipairs(segment) do
			if i == insertIdx then
				local ind = line:match("^(%s*)") or ""
				if line:match("^%s*local%s+function%f[%W]") or line:match("^%s*function%f[%W]") then
					ind = ind .. "\t"
				end
				for _, name in ipairs(hoistOrder) do
					out[#out+1] = ind .. "local " .. name
				end
			end
			for name in pairs(toHoist) do
				local ind, rhs = line:match("^(%s*)local%s+" .. luaPE(name) .. "%s*=%s*(.+)$")
				if ind and rhs then
					line = ind .. name .. " = " .. rhs
					break
				end
			end
			out[#out+1] = line
		end
		return out
	end
	local outAll = {}
	local i = 1
	while i <= #lines do
		local text = lines[i]:match("^%s*(.-)%s*$")
		if (lines[i]:match("^(%s*)") or "") == "" and text:match("^local%s+function%f[%W]") then
			local stack = { "block" }
			local j = i + 1
			while j <= #lines do
				local t = lines[j]:match("^%s*(.-)%s*$")
				if t ~= "" and t:sub(1, 2) ~= "--" then
					if t == "end" or t:match("^until%s+") then
						closeBlockText(t, stack)
					elseif t ~= "else" and not t:match("^elseif%s+.+%s+then$") then
						local kind = opensBlockText(t)
						if kind then stack[#stack+1] = kind end
					end
				end
				if #stack == 0 then break end
				j = j + 1
			end
			local segment = {}
			for k = i, math.min(j, #lines) do segment[#segment+1] = lines[k] end
			local processed = processSegment(segment)
			for _, line in ipairs(processed) do outAll[#outAll+1] = line end
			i = math.min(j, #lines) + 1
		else
			outAll[#outAll+1] = lines[i]
			i = i + 1
		end
	end
	return outAll
end

PASSES.fixModelPivotCFrameFallback = function(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		if i + 4 <= #lines then
			local ind, receiver = lines[i]:match("^(%s*)if%s+(.+):IsA%(%s*\"Model\"%s*%)%s+then%s*$")
			local pivotInd, pivotReceiver, pivotExpr = lines[i + 1]:match("^(%s*)(.+):PivotTo%((.+)%)%s*$")
			local localInd = lines[i + 2] and lines[i + 2]:match("^(%s*)local%s+[%a_][%w_]*%s*=%s*%b{}%s*$")
			local insertInd = lines[i + 3] and lines[i + 3]:match("^(%s*)table%.insert%(.+%)%s*$")
			local endInd = lines[i + 4] and lines[i + 4]:match("^(%s*)end%s*$")
			if ind and receiver and pivotInd and pivotReceiver == receiver and localInd == pivotInd and insertInd == pivotInd and endInd == ind then
				local aliasName = nil
				for back = i - 1, 1, -1 do
					local text = lines[back]:match("^%s*(.-)%s*$")
					if text:match("^local%s+function%f[%W]") then
						break
					end
					local found = lines[back]:match("^%s*" .. luaPE(receiver) .. "%s*=%s*([%a_][%w_]*)%s*$")
					if found then
						aliasName = found
						break
					end
				end
				local localLine = lines[i + 2]:gsub("^" .. luaPE(pivotInd), ind, 1)
				if aliasName then
					localLine = localLine:gsub("IsCustomModel%s*=%s*true", "IsCustomModel = (" .. aliasName .. " ~= nil)")
				end
				out[#out+1] = lines[i]
				out[#out+1] = lines[i + 1]
				out[#out+1] = ind .. "else"
				out[#out+1] = pivotInd .. receiver .. ".CFrame = " .. pivotExpr
				out[#out+1] = lines[i + 4]
				out[#out+1] = localLine
				out[#out+1] = lines[i + 3]:gsub("^" .. luaPE(pivotInd), ind, 1)
				i = i + 5
				continue
			end
		end
		out[#out+1] = lines[i]
		i = i + 1
	end
	return out
end

PASSES.sinkFunctionOnlyTempHoists = function(lines)
	local function functionEnd(startIdx)
		local stack = { "function" }
		local j = startIdx + 1
		while j <= #lines do
			local text = lines[j]:match("^%s*(.-)%s*$")
			if text ~= "" and text:sub(1, 2) ~= "--" then
				if text == "end" or text:match("^until%s+") then
					closeBlockText(text, stack)
				elseif text ~= "else" and not text:match("^elseif%s+.+%s+then$") then
					local kind = opensBlockText(text)
					if kind then stack[#stack+1] = kind end
				end
			end
			if #stack == 0 then
				return j
			end
			j = j + 1
		end
		return nil
	end

	local function containingTopLevelFunction(lineIdx)
		local j = 1
		while j <= #lines do
			local text = lines[j]:match("^%s*(.-)%s*$")
			local ind = lines[j]:match("^(%s*)") or ""
			if ind == "" and (text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]")) then
				local endIdx = functionEnd(j)
				if endIdx and lineIdx >= j and lineIdx <= endIdx then
					return j, endIdx
				end
				j = (endIdx or j) + 1
			else
				j = j + 1
			end
		end
		return nil
	end

	local function hasShadowingLocalInFunction(name, funcStart, lineIdx)
		local back = funcStart - 1
		while back >= 1 do
			local text = lines[back] and (lines[back]:match("^%s*(.-)%s*$") or "") or ""
			local ind = lines[back] and (lines[back]:match("^(%s*)") or "") or ""
			if text == "" then
				back = back - 1
			elseif ind == "" and text:match("^local%s+") and not text:match("^local%s+function%f[%W]") then
				local declList = text:match("^local%s+(.+)$")
				if declList then
					local lhs = declList:match("^(.-)%s*=") or declList
					for declared in lhs:gmatch("[%a_][%w_]*") do
						if declared == name then
							return true
						end
					end
				end
				back = back - 1
			else
				break
			end
		end
		local headerText = lines[funcStart] and (lines[funcStart]:match("^%s*(.-)%s*$") or "") or ""
		local headerParams = headerText:match("^local%s+function%s+[%a_][%w_]*%s*%(([^)]*)%)%s*$")
			or headerText:match("^function%s+[%w_%.:]+%s*%(([^)]*)%)%s*$")
		if headerText:match("^local%s+function%s+" .. luaPE(name) .. "%f[^%w_]") then
			return true
		end
		if headerParams then
			for paramName in headerParams:gmatch("[%a_][%w_]*") do
				if paramName == name then
					return true
				end
			end
		end
		for j = funcStart + 1, lineIdx do
			local declText = lines[j]:match("^%s*(.-)%s*$") or ""
			if not declText:match("^local%s+function%f[%W]") then
				local declList = declText:match("^local%s+(.+)$")
				if declList then
					local lhs = declList:match("^(.-)%s*=") or declList
					for declared in lhs:gmatch("[%a_][%w_]*") do
						if declared == name then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local function lineHasMeaningfulUse(line, name)
		if type(line) ~= "string" or not line:find(name, 1, true) then return false end
		local text = line:match("^%s*(.-)%s*$") or ""
		local headerParams = text:match("^local%s+function%s+[%a_][%w_]*%s*%(([^)]*)%)%s*$")
			or text:match("^function%s+[%w_%.:]+%s*%(([^)]*)%)%s*$")
		if text:match("^local%s+function%s+" .. luaPE(name) .. "%f[^%w_]") then
			return false
		end
		if headerParams then
			for paramName in headerParams:gmatch("[%a_][%w_]*") do
				if paramName == name then
					return false
				end
			end
		end
		local localDeclEnd = nil
		if text:match("^local%s+") and not text:match("^local%s+function%f[%W]") then
			local eqPos = line:find("=", 1, true)
			localDeclEnd = (eqPos and (eqPos - 1)) or #line
		end
		local pat = identPat(name)
		local i = 1
		local n = #line
		while i <= n do
			local nextPos = n + 1
			for _, ch in ipairs({ '"', "'", "[", "-" }) do
				local pos = line:find(ch, i, true)
				if pos and pos < nextPos then nextPos = pos end
			end
			if nextPos > i then
				local segment = line:sub(i, nextPos - 1)
				local searchFrom = 1
				while true do
					local s, e = segment:find(pat, searchFrom)
					if not s then break end
					local absS = i + s - 1
					local absE = i + e - 1
					local prev = absS > 1 and line:sub(absS - 1, absS - 1) or ""
					local prevNsPos = absS - 1
					while prevNsPos >= 1 and line:sub(prevNsPos, prevNsPos):match("%s") do
						prevNsPos = prevNsPos - 1
					end
					local prevNs = prevNsPos >= 1 and line:sub(prevNsPos, prevNsPos) or ""
					local nextNsPos = absE + 1
					while nextNsPos <= n and line:sub(nextNsPos, nextNsPos):match("%s") do
						nextNsPos = nextNsPos + 1
					end
					local nextNs = nextNsPos <= n and line:sub(nextNsPos, nextNsPos) or ""
					local isTableKey = nextNs == "=" and (prevNs == "{" or prevNs == ",")
					local isLocalDecl = localDeclEnd and absE <= localDeclEnd
					if prev ~= "." and prev ~= ":" and not isTableKey and not isLocalDecl then
						return true
					end
					searchFrom = e + 1
				end
				i = nextPos
			else
				local ch = line:sub(i, i)
				if ch == "-" and line:sub(i, i + 1) == "--" then
					break
				elseif ch == '"' or ch == "'" then
					local quote = ch
					local j = i + 1
					while j <= n do
						local cj = line:sub(j, j)
						if cj == "\\" and j < n then
							j = j + 2
						elseif cj == quote then
							j = j + 1
							break
						else
							j = j + 1
						end
					end
					i = j
				elseif ch == "[" and line:sub(i, i + 1) == "[[" then
					local closePos = line:find("]]", i + 2, true)
					if closePos then
						i = closePos + 2
					else
						break
					end
				else
					i = i + 1
				end
			end
		end
		return false
	end

	local function usedOutsideFunction(name, declStart, declEnd, funcStart, funcEnd)
		for j = 1, #lines do
			if (j < declStart or j > declEnd)
				and (j < funcStart or j > funcEnd)
				and lineHasMeaningfulUse(lines[j], name)
			then
				local otherFuncStart = containingTopLevelFunction(j)
				if not otherFuncStart or not hasShadowingLocalInFunction(name, otherFuncStart, j) then
					return true
				end
			end
		end
		return false
	end

	local function firstUseIsAssignment(name, funcStart, funcEnd)
		for j = funcStart + 1, funcEnd do
			if lineHasMeaningfulUse(lines[j], name) then
				return lines[j]:match("^%s*" .. luaPE(name) .. "%s*=") ~= nil
			end
		end
		return false
	end

	local out = {}
	local i = 1
	while i <= #lines do
		local handled = false
		local group = {}
		local groupEnd = i - 1
		local nextIdx = i
		while nextIdx <= #lines do
			local name = lines[nextIdx]:match("^local%s+([%a_][%w_]*)%s*$")
			if not name then
				break
			end
			group[#group+1] = { name = name, idx = nextIdx }
			groupEnd = nextIdx
			nextIdx = nextIdx + 1
		end
		local barrierStart = groupEnd + 1
		local functionIdx = nil
		local scanIdx = nextIdx
		while #group > 0 and scanIdx <= #lines do
			local text = lines[scanIdx]:match("^%s*(.-)%s*$") or ""
			local ind = lines[scanIdx]:match("^(%s*)") or ""
			if text == "" then
				scanIdx = scanIdx + 1
			elseif ind == "" and text:match("^local%s+function%f[%W]") then
				functionIdx = scanIdx
				break
			elseif ind == "" and text:match("^function%f[%W]") then
				functionIdx = scanIdx
				break
			elseif ind == "" and text:match("^local%s+") and not text:match("^local%s+function%f[%W]") then
				scanIdx = scanIdx + 1
			else
				break
			end
		end
		if #group > 0 and functionIdx then
			local endIdx = functionEnd(functionIdx)
			if endIdx then
				local sinkNames = {}
				local sinkSet = {}
				for _, entry in ipairs(group) do
					if not usedOutsideFunction(entry.name, i, groupEnd, functionIdx, endIdx)
						and firstUseIsAssignment(entry.name, functionIdx, endIdx)
					then
						sinkNames[#sinkNames+1] = entry.name
						sinkSet[entry.name] = true
					end
				end
				if #sinkNames > 0 then
					for _, entry in ipairs(group) do
						if not sinkSet[entry.name] then
							out[#out+1] = lines[entry.idx]
						end
					end
					for j = groupEnd + 1, endIdx do
						out[#out+1] = lines[j]
						if j == functionIdx then
							local bodyIndent = (lines[j]:match("^(%s*)") or "") .. "\t"
							for _, name in ipairs(sinkNames) do
								out[#out+1] = bodyIndent .. "local " .. name
							end
						end
					end
					i = endIdx + 1
					handled = true
				end
			end
		end
		if not handled then
			out[#out+1] = lines[i]
			i = i + 1
		end
	end
	return out
end

PASSES.findFirstChildGuardParts = function(line)
	local ind, expr, child = line:match("^(%s*)if%s+not%s+%((.+:FindFirstChild%s*%(%s*\"([^\"]+)\".-%))%)%s+then%s*$")
	if ind then return ind, expr, cleanGeneratedIdent(child) end
	ind, expr, child = line:match("^(%s*)if%s+not%s+%((.+:FindFirstChild%s*%(%s*'([^']+)'.-%))%)%s+then%s*$")
	if ind then return ind, expr, cleanGeneratedIdent(child) end
	return nil
end

PASSES.nameUsedBeforeNextTopLevel = function(lines, startIdx, name)
	for i = startIdx, math.min(#lines, startIdx + 80) do
		local text = lines[i]:match("^%s*(.-)%s*$")
		local ind = lines[i]:match("^(%s*)") or ""
		if ind == "" and (text == "end" or text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]")) then
			return false
		end
		if lineHasAnyIdent(lines[i], { [name] = true }) then
			return true
		end
	end
	return false
end

PASSES.fixFindFirstChildGuardLocals = function(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		local ind, findExpr, childName = PASSES.findFirstChildGuardParts(lines[i])
		if ind and childName and isValidIdent(childName) and PASSES.nameUsedBeforeNextTopLevel(lines, i + 1, childName) then
			local prevIdx = #out
			while prevIdx > 0 and not out[prevIdx]:match("%S") do
				prevIdx = prevIdx - 1
			end
			local alreadyDeclared = prevIdx > 0 and out[prevIdx]:match("^" .. luaPE(ind) .. "local%s+" .. luaPE(childName) .. "%s*=%s*" .. luaPE(findExpr) .. "%s*$")
			if not alreadyDeclared then
				out[#out+1] = ind .. "local " .. childName .. " = " .. findExpr
			end
			out[#out+1] = ind .. "if not " .. childName .. " then"
			i = i + 1
			continue
		end
		local dynInd, dynExpr = lines[i]:match("^(%s*)if%s+not%s+%((.+:FindFirstChild%s*%(.+%))%)%s+then%s*$")
		if dynInd then
			local guardEnd = nil
			for j = i + 1, math.min(#lines, i + 4) do
				local text = lines[j]:match("^%s*(.-)%s*$")
				local jInd = lines[j]:match("^(%s*)") or ""
				if jInd == dynInd and text == "end" then
					guardEnd = j
					break
				end
			end
			if guardEnd then
				local nextIdx = guardEnd + 1
				while nextIdx <= #lines and not lines[nextIdx]:match("%S") do
					nextIdx = nextIdx + 1
				end
				local tempName = nextIdx <= #lines and (
					lines[nextIdx]:match("^%s*(_r%d+[_%d]*)[:%.]")
					or lines[nextIdx]:match("^%s*if%s+(_r%d+[_%d]*)[:%.]")
					or lines[nextIdx]:match("^%s*if%s+not%s+(_r%d+[_%d]*)[:%.]")
				) or nil
				if tempName then
					out[#out+1] = dynInd .. "local " .. tempName .. " = " .. dynExpr
					out[#out+1] = dynInd .. "if not " .. tempName .. " then"
					i = i + 1
					continue
				end
			end
		end
		out[#out+1] = lines[i]
		i = i + 1
	end
	return out
end

PASSES.restoreGuardedFindCallResultLocals = function(lines)
	local out = {}
	local function firstTempUse(startIdx)
		for j = startIdx, math.min(#lines, startIdx + 80) do
			local text = lines[j]:match("^%s*(.-)%s*$")
			local ind = lines[j]:match("^(%s*)") or ""
			if ind == "" and (text == "end" or text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]")) then
				return nil
			end
			local name = lines[j]:match("%f[%a_](_r%d+[_%d]*)%f[^%a_%d]")
			if name then return name end
		end
		return nil
	end
	local function firstSemanticResultUse(startIdx, expr)
		local receiver = type(expr) == "string" and expr:match("^(.-):FindFirstChild[%a_]*%s*%(") or nil
		local base = receiver and receiver:match("([%a_][%w_]*)%s*$") or nil
		if not (base and isValidIdent(base)) then return nil end
		local candidates = {}
		for suffix = 2, 6 do
			candidates[#candidates+1] = base .. "_" .. tostring(suffix)
		end
		for j = startIdx, math.min(#lines, startIdx + 80) do
			local text = lines[j]:match("^%s*(.-)%s*$")
			local ind = lines[j]:match("^(%s*)") or ""
			if ind == "" and (text == "end" or text:match("^local%s+function%f[%W]") or text:match("^function%f[%W]")) then
				return nil
			end
			for _, candidate in ipairs(candidates) do
				if lineHasAnyIdent(lines[j], { [candidate] = true }) then
					return candidate
				end
			end
		end
		return nil
	end
	local i = 1
	while i <= #lines do
		local ind, expr = lines[i]:match("^(%s*)if%s+not%s+%((.+:FindFirstChild[%a_]*%s*%(.+%))%)%s+then%s+return%s+end%s*$")
		local endIdx = i
		if not ind and i + 2 <= #lines then
			ind, expr = lines[i]:match("^(%s*)if%s+not%s+%((.+:FindFirstChild[%a_]*%s*%(.+%))%)%s+then%s*$")
			if ind and not (lines[i + 1]:match("^" .. luaPE(ind) .. "\t?return%s*$") and matchEnd(lines[i + 2]) == ind) then
				ind, expr = nil, nil
			else
				endIdx = i + 2
			end
		end
		if ind and expr then
			local hint = deriveNameHint(expr)
			local name = hint and cleanGeneratedIdent(hint) or nil
			if not (name and isValidIdent(name) and PASSES.nameUsedBeforeNextTopLevel(lines, i + 1, name)) then
				name = firstSemanticResultUse(i + 1, expr) or firstTempUse(i + 1)
			end
			if name and isValidIdent(name) and PASSES.nameUsedBeforeNextTopLevel(lines, i + 1, name) then
				out[#out+1] = ind .. "local " .. name .. " = " .. expr
				out[#out+1] = ind .. "if not " .. name .. " then return end"
				i = endIdx + 1
				continue
			end
		end
		out[#out+1] = lines[i]
		i = i + 1
	end
	return out
end

PASSES.fixBasePartFallbackMergeNames = function(lines)
	-- DELETED: hardcoded for Roblox R6/R15 character body part names (Torso ->
	-- UpperTorso, Left Arm -> LeftUpperArm, etc.). Violates AGENTS.md (no
	-- bytecode-specific hardcoded field names). The generic naming/aliasing
	-- in the renderer should suffice; specific cases that look ugly will
	-- require a generic structural fix instead.
	return lines
end

PASSES.restoreLastBarrelPointAfterAllBarrels = function(lines)
	-- DELETED: hardcoded to specific FireAllBarrels / arg0.BarrelPoints /
	-- arg0.LastBarrelPoint pattern matching one specific bytecode. Violates
	-- AGENTS.md.
	return lines
end

PASSES.fixModelPivotCFrameFallback = function(lines)
	-- DELETED: hardcoded to :IsA("Model") + :PivotTo(...) + IsCustomModel
	-- literal text replacement. Violates AGENTS.md.
	return lines
end

PASSES.fixNestedModelBasePartElseif = function(lines, indentUnit)
	-- DELETED: hardcoded to :IsA("Model") + .PrimaryPart + :IsA("BasePart")
	-- pattern. While more abstract than others, still tied to specific
	-- Roblox class names. Violates AGENTS.md preference.
	return lines
end

local function renderSource(bc, opts)
	-- [A1] opts may carry yieldEvery / onProgress / protoFilter / maxIterations
	-- / timeBudgetMs. We apply them at the per-proto loop boundary below.
	-- The deeper liftControlFlow pipeline does not yet consume maxIterations
	-- or timeBudgetMs (would require restructuring the lift passes), but we
	-- stash them on bc._opts so a future refactor can pick them up.
	opts = opts or {}
	bc._opts = opts
	bc._opts_startTime = os.clock()
	local out = { "-- ============== SOURCE ==============" }
	if bc.main_id >= 0 and bc.main_id < #bc.protos then
		propagateUpvalueNames(bc.main_id, bc, {})
	end
	local hoistMap = identifyHoistTargets(bc)
	local rendered = {}
	local totalProtos = #bc.protos
	local yieldEvery = opts and opts.yieldEvery
	local onProgress = opts and opts.onProgress
	local protoFilter = opts and opts.protoFilter
	local timeBudgetMs = opts and opts.timeBudgetMs
	local startTime = bc._opts_startTime or os.clock()
	for protoIdx = 0, totalProtos - 1 do
		-- [A1] We use a `skipped` flag instead of `goto` so that the code
		-- is valid under both Luau and Lua 5.x/LuaJIT (goto across local
		-- decls is restricted in 5.x). Both branches below set the flag
		-- and the decompile is wrapped in `if not skipped then ... end`.
		local skipped = false
		local skipReason = nil
		-- [A1] protoFilter: allow caller to skip protos entirely.
		if protoFilter and not protoFilter(protoIdx) then
			skipped = true
			skipReason = "skipped by protoFilter"
		end
		-- [A1] timeBudgetMs: soft check before starting each proto. If we're
		-- over budget, emit a marker and skip the rest. Caller can detect
		-- this by searching the output for "[time budget exhausted]".
		if not skipped and timeBudgetMs and (os.clock() - startTime) * 1000 >= timeBudgetMs then
			skipped = true
			skipReason = "time budget exhausted"
		end
		if skipped then
			rendered[protoIdx] = "-- [proto " .. tostring(protoIdx) .. " " .. (skipReason or "skipped") .. "]"
		else
			-- [R1] Wrap each proto's decompile in pcall so one corrupt proto
			-- produces a visible error comment instead of aborting the whole
			-- module render.
			local p = protoAt(bc, protoIdx)
			local ok, result = pcall(decompileProto, p, bc, protoIdx)
			if not ok or type(result) ~= "string" then
				rendered[protoIdx] = "-- [decompile failed for proto " .. tostring(protoIdx) .. "]\n"
					.. "-- Error: " .. tostring(result) .. "\n"
					.. "-- Proto " .. tostring(protoIdx) .. ": " .. tostring(p and p.debugname or "(no debug name)") .. "\n"
			else
				rendered[protoIdx] = result
				if bc.upvalueRenameHints and bc.upvalueRenameHints[protoIdx] then
					rendered[protoIdx] = applyUpvalueRenameHints(rendered[protoIdx], bc.upvalueRenameHints[protoIdx])
				end
			end
		end
		-- [A1] onProgress callback.
		if onProgress then
			local po_ok, perr = pcall(onProgress, protoIdx + 1, totalProtos)
			if not po_ok then
				warn("[noahfr] onProgress callback error: " .. tostring(perr))
			end
		end
		-- [A1] Cooperative yield for plugin use. Lets the Luau scheduler
		-- run between protos so Studio doesn't freeze on huge files.
		if yieldEvery and (protoIdx + 1) % yieldEvery == 0 then
			local yielding = coroutine.running()
			if yielding then
				coroutine.yield()
			end
		end
	end
	local hoistParents = {}
	for parentId, childIds in pairs(hoistMap) do
		hoistParents[#hoistParents+1] = parentId
		table.sort(childIds)
	end
	table.sort(hoistParents)
	local hoistedChildren = {}
	for _ = 1, 40 do
		local changed = false
		for _, parentId in ipairs(hoistParents) do
			local childIds = hoistMap[parentId]
			for _, childId in ipairs(childIds) do
				if rendered[parentId] and rendered[childId] then
					local childProto = protoAt(bc, childId)
					local childName = childProto and cleanIdent(childProto.debugname) or nil
					if not childName or childName == "" then
						childName = "anon" .. tostring(childId)
					end
					local newBody, spliced = spliceHoistedChild(rendered[parentId], childName, rendered[childId])
					if spliced and newBody ~= rendered[parentId] then
						rendered[parentId] = newBody
						hoistedChildren[childId] = true
						changed = true
					end
				end
			end
		end
		if not changed then break end
	end
	for protoIdx = 0, #bc.protos - 1 do
		if protoIdx ~= bc.main_id and not hoistedChildren[protoIdx] then
			push(out, stripParentLocalCaptureTags(rendered[protoIdx]))
			push(out, "")
		end
	end
	if bc.main_id >= 0 and bc.main_id < #bc.protos then
		push(out, stripParentLocalCaptureTags(rendered[bc.main_id]))
		push(out, "")
	end
	local source = table.concat(out, "\n")
	local lines = {}
	for line in (source .. "\n"):gmatch("(.-)\n") do
		lines[#lines+1] = line
	end
	lines = PASSES.foldPcallRequireUpvalueWriters(lines)
	-- predeclareHoistedUpvalues intentionally disabled: hoist already forward-declares
	-- repeated locals inside the main chunk, and the top-of-file `local X, Y, Z`
	-- block plus stripped `local` prefixes in main chunk produces noisy/duplicate
	-- declarations such as `local Players` appearing both at the top and inside
	-- the main chunk body.
	-- lines = PASSES.predeclareHoistedUpvalues(lines)
	lines = renderLuaAstLines(lines, "\t")
	lines = PASSES.fixCameraModuleActivateController(lines, "\t")
	lines = PASSES.reattachLeakedFunctionTails(lines, "\t")
	lines = PASSES.fixFindFirstChildGuardLocals(lines)
	lines = PASSES.restoreGuardedFindCallResultLocals(lines)
	lines = PASSES.fixBasePartFallbackMergeNames(lines)
	lines = PASSES.restoreLastBarrelPointAfterAllBarrels(lines)
	lines = PASSES.fixSplitFallbackObjectAlias(lines)
	lines = PASSES.hoistLocalsUsedOutsideDeclBlock(lines)
	lines = PASSES.fixNestedModelBasePartElseif(lines, "\t")
	lines = PASSES.fixModelPivotCFrameFallback(lines)
	lines = PASSES.hoistLocalsUsedOutsideDeclBlock(lines)
	lines = PASSES.sinkFunctionOnlyTempHoists(lines)
	lines = renderLuaAstLines(lines, "\t")
	lines = PASSES.hoistLocalsUsedOutsideDeclBlock(lines)
	lines = PASSES.fixCameraModuleActivateController(lines, "\t")
	lines = PASSES.fixBasePartFallbackMergeNames(lines)
	lines = PASSES.restoreLastBarrelPointAfterAllBarrels(lines)
	lines = restoreFirstMatchLoopBreaks(lines)
	lines = fixLoadbSkipBooleanAssignments(lines)
	lines = normalizeLuaIndentation(lines, "\t")
	lines = dropInvalidTopLevelReturns(lines)
	-- Merge `local NAME` (bare forward-declaration) with the first subsequent
	-- bare `NAME = expr` at the same indentation, so e.g.
	--     local Players
	--     local ReplicatedStorage
	--     Players = game:GetService("Players")
	--     ReplicatedStorage = game:GetService("ReplicatedStorage")
	-- becomes:
	--     local Players = game:GetService("Players")
	--     local ReplicatedStorage = game:GetService("ReplicatedStorage")
	-- We only merge when NAME is NEVER read or written before the matching
	-- bare assignment, to preserve scoping for closures that need an earlier
	-- forward declaration.
	do
		-- Count occurrences of `name` as a standalone identifier, skipping
		-- string/comment regions AND any occurrence that is a field name (`.X`
		-- or `:X`).  We can't use `countIdentUsesOutsideStrings` here because
		-- it counts `T.Modules.X` (where `Modules` is just a field path) as a
		-- real reference to a local named `Modules`.
		local function countNonFieldUses(line, name)
			local count = 0
			local i, len = 1, #line
			local inStr = nil
			while i <= len do
				local c = line:sub(i, i)
				if inStr then
					if c == "\\" and i < len then
						i = i + 2
					elseif c == inStr then
						inStr = nil
						i = i + 1
					else
						i = i + 1
					end
				elseif c == '"' or c == "'" then
					inStr = c
					i = i + 1
				elseif c == "-" and line:sub(i + 1, i + 1) == "-" then
					break
				elseif c:match("[%a_]") then
					local prevChar = i > 1 and line:sub(i - 1, i - 1) or ""
					local j = i
					while j <= len and line:sub(j, j):match("[%w_]") do j = j + 1 end
					if line:sub(i, j - 1) == name and prevChar ~= "." and prevChar ~= ":" then
						count = count + 1
					end
					i = j
				else
					i = i + 1
				end
			end
			return count
		end
		local deletedIdx = {}
		for i = 1, #lines do
			local indent, name = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*$")
			if indent and name then
				local foundIdx = nil
				for j = i + 1, #lines do
					local line = lines[j]
					local jIndent = line:match("^(%s*)") or ""
					local uses = countNonFieldUses(line, name)
					if jIndent == indent then
						local lhs = line:match("^" .. luaPE(indent) .. "([%a_][%w_]*)%s*=%s*.+$")
						if lhs == name and uses == 1 then
							foundIdx = j
							break
						end
					end
					if uses > 0 then break end
				end
				if foundIdx then
					-- Prepend `local ` after the existing indent (avoiding the
					-- empty-capture-becomes-position pitfall of `^()(name=)`).
					lines[foundIdx] = indent .. "local " .. lines[foundIdx]:sub(#indent + 1)
					deletedIdx[i] = true
				end
			end
		end
		if next(deletedIdx) then
			local out = {}
			for i, line in ipairs(lines) do
				if not deletedIdx[i] then out[#out + 1] = line end
			end
			lines = out
		end
	end
	-- Collapse `local function NAME(args) ... end\nTABLE.NAME = NAME` into
	-- `function TABLE.NAME(args) ... end`, but ONLY when the bytecode indicates
	-- the original source actually used the `function TABLE.NAME(...)` form (i.e.
	-- the parent proto's NEWCLOSURE/DUPCLOSURE register has NO debug locvar
	-- binding immediately after the closure is created).  If the parent has a
	-- locvar entry for that register, the original source explicitly wrote
	-- `local function NAME() ... end TABLE.NAME = NAME`, so we keep both lines
	-- to stay faithful to the pre-compile source.
	do
		-- Map childProtoId -> "local" | "field".  We try to recover the original
		-- source form by inspecting the parent proto's bytecode around the
		-- NEWCLOSURE/DUPCLOSURE for each child:
		--   * If parent has a real `local FOO = (closure)` binding, locvarAt
		--     will return a locvar whose name differs from any neighbouring
		--     SETTABLEKS field assignment.  We treat that as "local".
		--   * Roblox Luau's debug info also emits synthetic locvars on the
		--     closure register whose NAME equals the field the closure is
		--     stored into (`function T.FOO(...) end` produces a locvar called
		--     `FOO` even though no source local exists).  We detect this by
		--     scanning forward past CAPTUREs for a SETTABLEKS that writes the
		--     same register; if the field name matches the locvar name, treat
		--     it as "field".
		local protoBinding = {}
		local function locateNextFieldStore(p, regA, fromPc)
			local scanPc = fromPc
			local limit = math.min(#p.code - 1, scanPc + 16)
			while scanPc <= limit do
				local insn = codeWordAt(p, scanPc)
				local op = bit32_band(insn, 0xFF)
				local opName = OPCODES[op] or ""
				if opName == "" then return nil end
				if opName == "CAPTURE" then
					scanPc = scanPc + getOpLength(opName)
				elseif opName == "SETTABLEKS" then
					local sA = bit32_band(bit32_rshift(insn, 8), 0xFF)
					if sA == regA then
						local auxPc = scanPc + 1
						if auxPc <= #p.code - 1 then
							local kc = constantAt(p, codeWordAt(p, auxPc))
							if kc and kc.kind == "string" then return kc.value end
						end
					end
					return nil
				else
					return nil
				end
			end
			return nil
		end
		for parentId = 0, #bc.protos - 1 do
			local p = protoAt(bc, parentId)
			if p then
				local pc = 0
				while pc < #p.code do
					local insn = codeWordAt(p, pc)
					local op = bit32_band(insn, 0xFF)
					local opName = OPCODES[op] or ""
					if opName == "NEWCLOSURE" or opName == "DUPCLOSURE" then
						local d = decodeSignedD(insn)
						local childId
						if opName == "NEWCLOSURE" then
							childId = childProtoIdAt(p, d)
						else
							local cc = constantAt(p, d)
							childId = cc and cc.kind == "closure" and cc.value or nil
						end
						if type(childId) == "number" then
							local a = bit32_band(bit32_rshift(insn, 8), 0xFF)
							local nextPc = pc + getOpLength(opName)
							local lv = locvarAt(p, a, nextPc)
							local nextField = locateNextFieldStore(p, a, nextPc)
							local form
							if lv == nil then
								form = "field"
							elseif nextField and lv.name == nextField then
								-- Synthetic Roblox debug locvar; not a real local.
								form = "field"
							else
								form = "local"
							end
							if form == "local" then
								protoBinding[childId] = "local"
							elseif protoBinding[childId] == nil then
								protoBinding[childId] = "field"
							end
						end
					end
					pc = pc + (opName ~= "" and getOpLength(opName) or 1)
				end
			end
		end
		local toDelete = {}
		local rewrites = {}
		-- Count distinct uses of each candidate name across the whole file so we
		-- only collapse when it is safe (no recursive self-references, no extra
		-- aliases).  Uses inside strings and comments are deliberately ignored.
		local useCounts = {}
		local function scanIdents(line, cb)
			local i, len = 1, #line
			local inStr = nil
			while i <= len do
				local c = line:sub(i, i)
				if inStr then
					if c == "\\" and i < len then
						i = i + 2
					elseif c == inStr then
						inStr = nil
						i = i + 1
					else
						i = i + 1
					end
				elseif c == '"' or c == "'" then
					inStr = c
					i = i + 1
				elseif c == "-" and line:sub(i + 1, i + 1) == "-" then
					break  -- rest of line is a comment
				elseif c:match("[%a_]") then
					-- Skip identifiers that are field/method names (immediately preceded
					-- by `.` or `:`).  These do not denote a reference to a local of the
					-- same name -- e.g. `_index.new = new` only references the local
					-- `new` once (on the right-hand side); the `.new` part is a field.
					local prevChar = i > 1 and line:sub(i - 1, i - 1) or ""
					local j = i
					while j <= len and line:sub(j, j):match("[%w_]") do j = j + 1 end
					if prevChar ~= "." and prevChar ~= ":" then
						cb(line:sub(i, j - 1))
					end
					i = j
				else
					i = i + 1
				end
			end
		end
		for _, line in ipairs(lines) do
			scanIdents(line, function(tok) useCounts[tok] = (useCounts[tok] or 0) + 1 end)
		end
		for i, line in ipairs(lines) do
			local indent, fnName, args = line:match("^(%s*)local%s+function%s+([%a_][%w_]*)(%b())")
			if indent and fnName then
				-- Find the matching `end` line at the same indent.
				local endIdx = nil
				for j = i + 1, #lines do
					local lineInd = lines[j]:match("^(%s*)") or ""
					local text = lines[j]:match("^%s*(.-)%s*$")
					if lineInd == indent and text == "end" then
						endIdx = j
						break
					end
				end
				if endIdx then
					-- The next non-blank line at the same indent must be `T.NAME = NAME`.
					local nextIdx = endIdx + 1
					while nextIdx <= #lines and not lines[nextIdx]:match("%S") do
						nextIdx = nextIdx + 1
					end
					if nextIdx <= #lines then
						local nIndent, tableExpr, rhs = lines[nextIdx]:match(
							"^(%s*)([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*$"
						)
						if nIndent == indent and rhs == fnName and tableExpr:match("%." .. luaPE(fnName) .. "$") then
							-- Bytecode is the authoritative source.  When the parent proto
							-- shows the original used `function T.NAME(...)` form (no real
							-- locvar binding for the closure reg, or only a synthetic debug
							-- locvar whose name matches the field), collapse regardless of
							-- `useCounts`.  The local-name uses we see in other lines refer
							-- to the OUTER same-named local (e.g. `local CreateChainEffect = {}`),
							-- so removing the inner shadow leaves them resolving correctly.
							-- If the bytecode shows the original wrote `local function NAME`
							-- (real locvar binding with a different name), keep both lines.
							local protoIdStr = line:match("%-%-%s*proto%[(%d+)%]")
							local protoId = protoIdStr and tonumber(protoIdStr) or nil
							local bytecodeAllowsCollapse = protoId ~= nil and protoBinding[protoId] == "field"
							-- Extra safety: the function body must not call itself via bare
							-- `NAME(...)` (would break after the local is removed).
							local bodyUsesSelf = false
							if bytecodeAllowsCollapse then
								for j = i + 1, endIdx - 1 do
									if countIdentUsesOutsideStrings(lines[j], fnName) > 0 then
										bodyUsesSelf = true
										break
									end
								end
							end
							if bytecodeAllowsCollapse and not bodyUsesSelf then
								rewrites[i] = indent .. "function " .. tableExpr .. args
								toDelete[nextIdx] = true
							end
						end
					end
				end
			end
		end
		if next(rewrites) or next(toDelete) then
			local out = {}
			for i, line in ipairs(lines) do
				if toDelete[i] then
					-- removed: collapsed into the rewritten function declaration above
				elseif rewrites[i] then
					-- Preserve everything after the original `(args)` segment, which
					-- typically holds the `-- proto[N], line ... -- upvalues: ...`
					-- annotation.
					local tail = line:match("^%s*local%s+function%s+[%a_][%w_]*%b()(.*)$") or ""
					out[#out + 1] = rewrites[i] .. tail
				else
					out[#out + 1] = line
				end
			end
			lines = out
		end
	end
	-- User-requested deterministic naming scheme:
	--   state, state_2, state_N    -> s1,  s2,  ... (by first appearance order)
	--   flag,  flag_2,  _flagN     -> f1,  f2,  ...
	--   _value, _value_N           -> v_u1, v_u2, ...
	--   *_result, *_result_N       -> r1,  r2,  ... (volume reduction)
	--   *_val, *_val_N             -> w1,  w2,  ... (volume reduction)
	--   *_str, *_str_N             -> t1,  t2,  ... (tostring results)
	--   *_num, *_num_N             -> n1,  n2,  ... (tonumber results)
	--   *_entry                    -> v<K>_e  (K by distinct base order)
	--   argN inside function FOO   -> v<K>    (K assigned by function-scope walk,
	--                                          so each parameter gets a unique number
	--                                          across the whole file)
	-- Strings ("..." / '...') are skipped so we never rewrite tokens inside literals.
	-- Block-scope tracking (function / if / for / while / do / repeat) lets us know
	-- which argument map is active on every line.
	do
		local renames = {}
		local stateOrder, flagOrder, valueOrder, entryOrder = {}, {}, {}, {}
		local resultOrder, valOrder = {}, {}
		local strOrder, numOrder = {}, {}
		local function classify(tok)
			if tok == "state" or tok:match("^state_%d+$") then return "state" end
			if tok == "flag" or tok:match("^flag_%d+$") or tok:match("^_flag%d+$") then return "flag" end
			if tok == "_value" or tok:match("^_value_%d+$") then return "value" end
			-- Entry pattern accepts both `<base>_entry` and `<base>_entry_N`
			-- (e.g. `arg1_entry_2` from a second loop iteration alias).
			local base = tok:match("^(.+)_entry$")
			if base then return "entry", base, "" end
			local base2, suf = tok:match("^(.+)_entry(_%d+)$")
			if base2 then return "entry", base2, suf end
			-- *_result and *_result_N (e.g., InvokeServer_result, Clone_result_2).
			-- Volume reduction: rename to short r1, r2, ... by first appearance.
			if tok:match("^[%a_][%w_]*_result$") or tok:match("^[%a_][%w_]*_result_%d+$") then
				return "result"
			end
			-- *_val and *_val_N (e.g., arg1_val, _value_5_val).
			-- Common artifacts of value-phi naming. Rename to short w1, w2, ...
			-- (avoid "v" since user already uses v<N> for params).
			if tok:match("^[%a_][%w_]*_val$") or tok:match("^[%a_][%w_]*_val_%d+$") then
				-- Skip if it matches an _value_<N> pattern that's already been
				-- reclassified to "value" above.
				return "val"
			end
			-- *_str and *_str_N from tostring() hints, *_num from tonumber().
			-- Rename to short t1, t2, ... (string-cast results).
			if tok:match("^[%a_][%w_]*_str$") or tok:match("^[%a_][%w_]*_str_%d+$") then
				return "str"
			end
			if tok:match("^[%a_][%w_]*_num$") or tok:match("^[%a_][%w_]*_num_%d+$") then
				return "num"
			end
			return nil
		end
		local function scanTokens(line, cb)
			local i, len = 1, #line
			local inStr = nil
			while i <= len do
				local c = line:sub(i, i)
				if inStr then
					if c == "\\" and i < len then
						i = i + 2
					elseif c == inStr then
						inStr = nil
						i = i + 1
					else
						i = i + 1
					end
				elseif c == '"' or c == "'" then
					inStr = c
					i = i + 1
				elseif c:match("[%a_]") then
					local j = i
					while j <= len and line:sub(j, j):match("[%w_]") do j = j + 1 end
					cb(line:sub(i, j - 1))
					i = j
				else
					i = i + 1
				end
			end
		end
		-- Phase 1: collect distinct names and entry bases by first appearance order.
		local entryBaseSeen = {}
		for _, line in ipairs(lines) do
			scanTokens(line, function(tok)
				local kind, base, suf = classify(tok)
				if kind and not renames[tok] then
					renames[tok] = true
					if kind == "state" then
						stateOrder[#stateOrder + 1] = tok
					elseif kind == "flag" then
						flagOrder[#flagOrder + 1] = tok
					elseif kind == "value" then
						valueOrder[#valueOrder + 1] = tok
					elseif kind == "result" then
						resultOrder[#resultOrder + 1] = tok
					elseif kind == "val" then
						valOrder[#valOrder + 1] = tok
					elseif kind == "str" then
						strOrder[#strOrder + 1] = tok
					elseif kind == "num" then
						numOrder[#numOrder + 1] = tok
					else
						-- entry: number by distinct base.  Carry the optional
						-- `_N` index suffix through so `arg1_entry_2` becomes
						-- `v<K>_e_2`, preserving the iteration-alias distinction.
						if not entryBaseSeen[base] then
							entryBaseSeen[base] = #entryOrder + 1
							entryOrder[#entryOrder + 1] = base
						end
						renames[tok] = "v" .. entryBaseSeen[base] .. "_e" .. (suf or "")
					end
				end
			end)
		end
		for idx, name in ipairs(stateOrder) do renames[name] = "s" .. idx end
		for idx, name in ipairs(flagOrder) do renames[name] = "f" .. idx end
		for idx, name in ipairs(valueOrder) do renames[name] = "v_u" .. idx end
		for idx, name in ipairs(resultOrder) do renames[name] = "r" .. idx end
		for idx, name in ipairs(valOrder) do renames[name] = "w" .. idx end
		for idx, name in ipairs(strOrder) do renames[name] = "t" .. idx end
		for idx, name in ipairs(numOrder) do renames[name] = "n" .. idx end
		-- Bytecode pre-scan: find function params that are captured by a child
		-- closure under the name `self`.  The Roblox Luau compiler records the
		-- captured upvalue's locvar name (in the CHILD proto's upvalue list),
		-- so when the original source wrote `function module:Method(...)` the
		-- implicit `self` parameter shows up as `self` in any inner closure's
		-- upvalue list.  By renaming the parent's first param to `self` we
		-- restore the original method-style signature and incidentally avoid
		-- emitting a redundant `local self = v<N>` materialization line.
		local selfParamHint = {}  -- protoId -> { [regIdx]=true }
		for parentId = 0, #bc.protos - 1 do
			local p = protoAt(bc, parentId)
			if p then
				local pc = 0
				while pc < #p.code do
					local insn = codeWordAt(p, pc)
					local op = bit32_band(insn, 0xFF)
					local opName = OPCODES[op] or ""
					if opName == "NEWCLOSURE" or opName == "DUPCLOSURE" then
						local d = decodeSignedD(insn)
						local childId
						if opName == "NEWCLOSURE" then
							childId = childProtoIdAt(p, d)
						else
							local cc = constantAt(p, d)
							childId = cc and cc.kind == "closure" and cc.value or nil
						end
						local childProto = type(childId) == "number" and protoAt(bc, childId) or nil
						local capPc = pc + getOpLength(opName)
						local capIdx = 1
						while capPc < #p.code do
							local capInsn = codeWordAt(p, capPc)
							local capOpId = bit32_band(capInsn, 0xFF)
							if (OPCODES[capOpId] or "") ~= "CAPTURE" then break end
							local capKindId = bit32_band(bit32_rshift(capInsn, 8), 0xFF)
							local capKind = CAPTURE_KINDS[capKindId] or ""
							local capReg = bit32_band(bit32_rshift(capInsn, 16), 0xFF)
							if (capKind == "VAL" or capKind == "REF") and childProto then
								local uvName = childProto.upvalues[capIdx]
								if uvName == "self" and capReg < (p.numparams or 0) then
									selfParamHint[parentId] = selfParamHint[parentId] or {}
									selfParamHint[parentId][capReg] = true
								end
							end
							capIdx = capIdx + 1
							capPc = capPc + getOpLength("CAPTURE")
						end
					end
					pc = pc + (opName ~= "" and getOpLength(opName) or 1)
				end
			end
		end
		-- Phase 2: walk lines with a block stack to build per-function arg maps.
		-- Each entry on the stack is { kind=function|block, argMap?, indent }.
		-- The active argMap is the topmost function entry on the stack.
		local stack = {}
		local nextV = 1
		local lineFuncMap = {}  -- li -> argMap (the active argMap for that line)
		local function topFuncMap()
			for k = #stack, 1, -1 do
				if stack[k].kind == "function" then return stack[k].argMap end
			end
			return nil
		end
		local function lineOpens(text)
			if text == "do" or text == "repeat" then return true end
			-- Only treat as block-open if the line ENDS with the opener
			-- (otherwise it's an inline `if X then Y end` / `for X do Y end`
			-- whose `end` is on the same line and would never get popped).
			if text:match("%sthen$") and (text:sub(1, 3) == "if " or text:sub(1, 7) == "elseif ") then return true end
			if text:match("%sdo$") and (text:sub(1, 4) == "for " or text:sub(1, 6) == "while ") then return true end
			return false
		end
		local function tokenizeArgs(s)
			local out = {}
			for tok in s:gmatch("[%a_][%w_]*") do out[#out + 1] = tok end
			return out
		end
		-- For lines that open a new function literal mid-line (e.g.
		-- `arg0.Foo = X:Connect(function(arg0, arg1) ... end)`), the LHS belongs
		-- to the OUTER scope and must use the outer argMap, while tokens after
		-- the `function(` keyword belong to the inner function and use the inner
		-- argMap. Detect a switch point and rewrite each region with its own map.
		local function findFunctionLitSplit(line)
			-- Returns the byte index of the `function` keyword that opens an
			-- inline literal (i.e. `function%s*%(`), or nil.
			-- Skips `function NAME(...)` / `local function NAME(...)` because
			-- those are the line's main opener (handled below by switching
			-- argMap for the whole line).
			local s = line:find("function%s*%(")
			if not s then return nil end
			-- Don't split if the line starts with `function ` or `local function `
			-- (named definitions). The whole line uses the new argMap.
			local prefix = line:sub(1, s - 1)
			if prefix:match("^%s*$") then return nil end  -- starts with function
			if prefix:match("^%s*local%s*$") then return nil end
			-- Verify the function keyword isn't a substring of a longer identifier.
			if s > 1 then
				local ch = line:sub(s - 1, s - 1)
				if ch:match("[%w_]") then return nil end
			end
			return s
		end
		for li, line in ipairs(lines) do
			local indent = line:match("^(%s*)") or ""
			local text = line:match("^%s*(.-)%s*$")
			-- Pop block entries whose indent equals current `end`/`elseif`/`else`.
			-- For simplicity: when we see `end` or `until ...`, pop one entry.
			-- Active map is recorded BEFORE we process opens on this line.
			lineFuncMap[li] = topFuncMap()
			-- Detect function definition on this line.
			-- Supports: `local function NAME(args)` and `function NAME(args)`
			-- and anonymous `function(args)` literals (e.g., proto[7], inside `:Connect(function(...)`)
			local argList = line:match("function%s+[%a_][%w_%.:]*%s*%((.-)%)")
				or line:match("function%s*%((.-)%)")
			if argList ~= nil then
				-- A nested function inherits its enclosing function's argMap, so that
				-- upvalue references to outer parameters (e.g. an inner closure that
				-- captures the parent's `arg0`) resolve to the same renumbered `vN`.
				-- The nested function then overrides entries for its OWN parameters.
				local outerMap = topFuncMap()
				local argMap = {}
				if outerMap then
					for k, v in pairs(outerMap) do argMap[k] = v end
				end
				-- If the line carries a `-- proto[N]` annotation, consult the
				-- `selfParamHint` map to keep `self` (instead of `vK`) for any
				-- parameter the original source declared as the implicit colon
				-- self.
				local protoIdStr = line:match("%-%-%s*proto%[(%d+)%]")
				local hintForProto = protoIdStr and selfParamHint[tonumber(protoIdStr)] or nil
				local argTokens = tokenizeArgs(argList)
				for idx, tok in ipairs(argTokens) do
					if tok:match("^arg%d+$") then
						local regIdx = idx - 1
						if hintForProto and hintForProto[regIdx] then
							argMap[tok] = "self"
						else
							argMap[tok] = "v" .. nextV
							nextV = nextV + 1
						end
					end
				end
				stack[#stack + 1] = { kind = "function", argMap = argMap, indent = indent }
				-- After we pushed the new function, references on this same line (e.g. in the
				-- signature) should resolve against the NEW map — UNLESS the function
				-- literal is opened mid-line by some preceding LHS expression that
				-- belongs to the OUTER scope. In that case, the outer-scope LHS
				-- must be rewritten with the OUTER map. Detect this by checking
				-- if the line's prefix before `function(` is non-trivial.
				local splitAt = findFunctionLitSplit(line)
				if splitAt then
					-- Two-region rewrite: prefix uses outerMap, suffix uses argMap.
					lineFuncMap[li] = { __split = true, prefixMap = outerMap, suffixMap = argMap, splitAt = splitAt }
				else
					lineFuncMap[li] = argMap
				end
			elseif lineOpens(text) then
				stack[#stack + 1] = { kind = "block", indent = indent }
			elseif text == "end" or text:sub(1, 6) == "until " then
				if #stack > 0 then stack[#stack] = nil end
			end
		end
		local function renameTokenInScope(tok, argMap)
			local mapped = renames[tok]
			if type(mapped) == "string" then return mapped end
			if argMap then
				local v = argMap[tok]
				if v then return v end
			end
			return tok
		end
		local function rewriteLine(line, argMap)
			-- Handle two-region split: prefix uses prefixMap, suffix uses suffixMap.
			if type(argMap) == "table" and argMap.__split then
				local prefix = line:sub(1, argMap.splitAt - 1)
				local suffix = line:sub(argMap.splitAt)
				return rewriteLine(prefix, argMap.prefixMap) .. rewriteLine(suffix, argMap.suffixMap)
			end
			local out, i, len = {}, 1, #line
			local inStr = nil
			while i <= len do
				local c = line:sub(i, i)
				if inStr then
					out[#out + 1] = c
					if c == "\\" and i < len then
						out[#out + 1] = line:sub(i + 1, i + 1)
						i = i + 2
					elseif c == inStr then
						inStr = nil
						i = i + 1
					else
						i = i + 1
					end
				elseif c == '"' or c == "'" then
					inStr = c
					out[#out + 1] = c
					i = i + 1
				elseif c:match("[%a_]") then
					local j = i
					while j <= len and line:sub(j, j):match("[%w_]") do j = j + 1 end
					out[#out + 1] = renameTokenInScope(line:sub(i, j - 1), argMap)
					i = j
				else
					out[#out + 1] = c
					i = i + 1
				end
			end
			return table.concat(out)
		end
		for li, line in ipairs(lines) do
			lines[li] = rewriteLine(line, lineFuncMap[li])
		end		-- Drop identity-alias lines that became `local X = X` after we renamed
		-- a parent's parameter to `self`.  The materialization in
		-- `flushPendingClosure` emitted `local self = arg<N>`; after rename
		-- both sides are the same name and the line is pure noise.
		do
			local out = {}
			for _, line in ipairs(lines) do
				local lhs, rhs = line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*$")
				if lhs and rhs and lhs == rhs then
					-- skip
				else
					out[#out + 1] = line
				end
			end
			lines = out
		end
	end
	-- Hoist branch-only assignments of pure field expressions to function start.
	-- Must run after the rename pass so we operate on user-facing names like
	-- `arg0_val` rather than internal `_value_3`.
	lines = PASSES.hoistBranchOnlyAssignmentsToFnStart(lines)
	-- Strip redundant parens around table literals.
	lines = PASSES.dropRedundantParensAroundTables(lines)
	-- Drop empty `else` clauses.
	lines = PASSES.dropEmptyElseClauses(lines)
	lines = PASSES.flipEmptyThenWithElse(lines)
	lines = dropEmptyIfBlocks(lines)
	-- Collapse `if COND then X = chain; if not X then X = fallback end end` to
	-- `X = (COND and chain) or fallback`. Fixes multi-guard fallback bugs where
	-- X stays nil when COND is false.
	lines = PASSES.collapseMultiGuardOrDefault(lines)
	-- Simplify `if COND then X = true/false else X = !LIT end` to a single assignment.
	lines = PASSES.simplifyBoolLoadbSkip(lines)
	-- Fix self-referential reassignment within blocks.
	lines = PASSES.fixSelfReferentialReassignment(lines)
	-- Fix `local NAME = LOOPVAR` at function scope (LOOPVAR not in scope yet).
	-- Must run BEFORE fixCapturedUpvalueLocal so we see `local NAME` (no init).
	lines = PASSES.fixForwardDeclFromLoopLocal(lines)
	-- Fix captured upvalue locals: when a closure captures NAME but NAME is
	-- never assigned, find the loop-local that should be assigned to NAME.
	lines = PASSES.fixCapturedUpvalueLocal(lines)
	-- Unify `local NAME = TEMP; local TEMP` at function start when an inner
	-- closure captures NAME (the two names refer to the same register).
	lines = PASSES.unifyForwardDeclWithCapturedName(lines)
	-- Inline single-use anonymous functions: `local function anonN() ... end; X(anonN)` -> `X(function() ... end)`
	lines = PASSES.inlineSingleUseAnonFunctions(lines)
	-- Drop duplicate `local NAME` declarations introduced by multiple hoist passes.
	lines = PASSES.dropDuplicateLocalForwardDecls(lines)
	-- Final cleanup: remove self-assignment no-ops that may have been introduced
	-- by earlier transformations (e.g. flipped empty-then blocks producing X = X).
	lines = dropSelfAssignmentNoops(lines)
	-- Drop duplicate consecutive assignments: `local X = Y; X = Y`.
	lines = dropDuplicateConsecutiveAssignments(lines)
	-- Drop duplicate consecutive `if X then return Y end` / `f(...)` / `return X`
	-- statements caused by phi merges from deterministic predecessors.
	lines = dropDuplicateConsecutiveStatements(lines)
	-- Simplify same-condition checks after early-return: `if not X then return end;
	-- if not X then return end` -> drop second; `if not X then return end; if X then return end`
	-- -> replace second with bare `return`. Conservative: only handles consecutive
	-- inline guard lines at the same indent (no walking, no multi-line block
	-- collapsing — those were too prone to misalignment in complex CFGs).
	lines = simplifyAfterEarlyReturn(lines)
	-- Drop dead `NAME = nil; NAME = expr` (the nil is immediately overwritten).
	lines = dropDeadNilThenAssign(lines)
	-- Drop dead `local NAME = X.field` whose NAME has no later reads in scope.
	-- Avoids both wasted lines and runtime nil-index hazards from unused
	-- guard-protected reads that the renderer materialized as flat locals.
	lines = dropDeadFieldAccessLocals(lines)
	-- Drop unsubstituted `<closure proto[N]>` placeholders that would cause
	-- syntax errors. Recursive closures, etc.
	lines = dropClosureProtoPlaceholders(lines)
	-- Drop `local _closure_proto_N_ = anonN` aliases (consume scope slots
	-- without providing any value). Helps stay under Lua's 200-local limit
	-- for files with many anonymous closures.
	lines = dropClosureProtoAliases(lines)
	-- Structural goto/label lift: handles `goto LBL; CODE; ::LBL::` patterns
	-- (both unconditional and `if X then goto LBL end`-conditional forms).
	-- Runs BEFORE orphan-skip-chain because it preserves correctness for
	-- labels that DO exist.
	lines = liftGotoLabelStructural(lines)
	-- Lift orphan-goto skip chains: `if X then goto LBL end; ...; TAIL` where
	-- LBL has no matching `::LBL::`. Reinterprets as `if not X then TAIL end`.
	lines = liftOrphanGotoSkipChains(lines)
	-- Convert remaining orphan gotos inside loops to `break`/`continue`.
	lines = convertOrphanGotosToFlow(lines)
	-- Lift if-chains where each block ends with `goto LBL` (mutual-exclusive
	-- early-exit pattern) into proper `if-elseif-...-end` chains.
	lines = liftGotoChainToElseif(lines)
	-- Strip dangling gotos that would prevent compilation. Last resort.
	lines = stripDanglingGotos(lines)
	-- Final paren-balance check: detect malformed expressions (unbalanced
	-- parens) and try to repair so the file at least compiles.
	lines = balanceLineParens(lines)
	-- For files with very many top-level `local function anonN()` declarations
	-- (>= 30) AND already over the safe local-count threshold (>= 180), tableify
	-- them: store all closures in a single shared table local. This trades many
	-- locals (one per closure) for one table-local.
	lines = tableifyManyTopLevelClosures(lines)
	-- For files with many top-level `local function` declarations, wrap groups
	-- in `do...end` to escape Lua/Luau's 200-locals-per-scope register limit.
	lines = chunkifyTopLevelLocalFunctions(lines)
	-- Re-run the flip pass: dropping self-assignments may have made then-bodies
	-- empty, exposing more `if X then else BODY end` patterns to flip.
	lines = PASSES.flipEmptyThenWithElse(lines)
	lines = dropEmptyIfBlocks(lines)
	-- Drop redundant nested `if X then if X then BODY end end` (same condition).
	lines = dropRedundantNestedSameCond(lines)
	-- Drop dead `local NAME = nil` whose NAME is never referenced. These appear
	-- as merge-block phi placeholders left behind when one branch of a phi is
	-- a no-op (typical pattern: `if A then else B then local _v = nil end`).
	lines = PASSES.dropDeadNilLocals(lines)
	-- Drop empty branches (then/elseif) left behind by other passes; an `if A then
	-- (empty) elseif B then ... end` becomes `if not A then if B then ... end end`
	-- only when safer. For now, just collapse fully-empty `if A then end`.
	lines = dropEmptyIfBlocks(lines)
	-- Add missing `local` prefix to function-scope assignments to names that
	-- were never declared as local in the enclosing function scope.
	lines = PASSES.addMissingLocalPrefix(lines)
	return table.concat(lines, "\n")
end

local function normalizeOptions(options)
	if type(options) == "string" then
		return {
			mode = string.lower(options),
			filename = "bytecode",
			noComments = false,
			yieldEvery = nil,
			onProgress = nil,
			maxIterations = 400,
			timeBudgetMs = nil,
			protoFilter = nil,
		}
	end
	if type(options) ~= "table" then
		return {
			mode = "source",
			filename = "bytecode",
			noComments = false,
			yieldEvery = nil,
			onProgress = nil,
			maxIterations = 400,
			timeBudgetMs = nil,
			protoFilter = nil,
		}
	end
	local mode = type(options.mode) == "string" and string.lower(options.mode) or "source"
	local filename = type(options.filename) == "string" and options.filename or "bytecode"
	local noComments = options.noComments == true or options.no_comments == true or options.stripComments == true or options.strip_comments == true
	-- [A1] New options:
	--   yieldEvery      : number  -> coroutine.yield() every N protos (default nil = no yields)
	--   onProgress      : function -> called as onProgress(current, total) per proto
	--   maxIterations   : number  -> bound liftControlFlow fixed-point (default 400)
	--   timeBudgetMs    : number  -> soft wall-clock budget; remaining passes skip past it
	--   protoFilter     : function -> (protoIdx) -> bool, skip proto if returns false
	local yieldEvery = (type(options.yieldEvery) == "number" and options.yieldEvery > 0) and options.yieldEvery or nil
	local onProgress = type(options.onProgress) == "function" and options.onProgress or nil
	local maxIterations = (type(options.maxIterations) == "number" and options.maxIterations > 0)
		and math.floor(options.maxIterations) or 400
	local timeBudgetMs = (type(options.timeBudgetMs) == "number" and options.timeBudgetMs > 0)
		and options.timeBudgetMs or nil
	local protoFilter = type(options.protoFilter) == "function" and options.protoFilter or nil
	return {
		mode = mode,
		filename = filename,
		noComments = noComments,
		yieldEvery = yieldEvery,
		onProgress = onProgress,
		maxIterations = maxIterations,
		timeBudgetMs = timeBudgetMs,
		protoFilter = protoFilter,
	}
end

local function renderBytecode(opts, data)
	-- [R2] parseBytecode now returns (bc, err). Surface the error as a
	-- comment block so the caller still gets a string back.
	local bc, perr
	-- [A2] Allow callers to pass a pre-parsed bc via opts.bc to avoid
	-- re-parsing on repeated renders of the same bytecode.
	if type(opts.bc) == "table" and opts.bc.protos then
		bc = opts.bc
	else
		bc, perr = parseBytecode(data)
	end
	local out = {}
	if not bc then
		push(out, "-- " .. basename(opts.filename))
		push(out, "-- FAILED TO PARSE BYTECODE")
		push(out, "-- Error: " .. tostring(perr))
		push(out, "-- Original size: " .. tostring(#data) .. " bytes")
		return table.concat(out, "\n")
	end
	if not opts.noComments then
		push(out, "-- " .. basename(opts.filename))
		push(out, "-- Original size: " .. tostring(#data) .. " bytes")
		push(out, "-- Bytecode version: " .. tostring(bc.version) .. ", types version: " .. tostring(bc.typesversion))
		push(out, "-- Strings: " .. tostring(#bc.strings) .. ", Protos: " .. tostring(#bc.protos) .. ", Main proto: " .. tostring(bc.main_id))
		push(out, "")
	end

	if opts.mode == "asm" or opts.mode == "both" then
		push(out, renderDisassembly(bc))
	end
	if opts.mode == "source" or opts.mode == "both" then
		if opts.mode == "both" then
			push(out, "")
		end
		push(out, renderSource(bc, opts))
	end
	local result = table.concat(out, "\n")
	if opts.noComments then
		result = stripGeneratedComments(result)
	end
	return result
end

local function analyzeBytecode(data)
	-- [R2] parseBytecode now returns (bc, err). Handle the err path.
	local bc, perr = parseBytecode(data)
	if not bc then
		return { stats = { protoCount = 0, error = perr }, protos = {} }
	end
	local stats = {
		protoCount = #bc.protos,
		blockCount = 0,
		edgeCount = 0,
		backEdgeCount = 0,
		branchMergeCount = 0,
		phiCandidateCount = 0,
		phiLocvarHintCount = 0,
		orDefaultHintCount = 0,
		counterHintCount = 0,
		guardedCallCount = 0,
		aliasHintCount = 0,
	}
	local protos = {}
	for protoIdx = 0, #bc.protos - 1 do
		local p = protoAt(bc, protoIdx)
		local ok, analysis = pcall(analyzeProtoFlow, p, bc)
		if ok and type(analysis) == "table" and type(analysis.cfg) == "table" then
			applyPhiLocvarHints(p, analysis, true)
			local cfg = analysis.cfg
			local edgeCount = 0
			for _, block in ipairs(cfg.blocks or {}) do
				edgeCount = edgeCount + #(block.successors or {})
			end
			local protoStats = {
				proto = protoIdx,
				blocks = #(cfg.blocks or {}),
				edges = edgeCount,
				backEdges = #(cfg.backEdges or {}),
				branchMerges = analysis.branchMergeCount or 0,
				phiCandidates = analysis.phiCandidateCount or 0,
				phiLocvarHints = analysis.phiLocvarHintCount or 0,
				orDefaultHints = analysis.orDefaultHintCount or 0,
				counterHints = analysis.counterHintCount or 0,
				guardedCalls = analysis.guardedCallCount or 0,
				aliasHints = analysis.aliasHintCount or 0,
			}
			protos[#protos+1] = protoStats
			stats.blockCount = stats.blockCount + protoStats.blocks
			stats.edgeCount = stats.edgeCount + protoStats.edges
			stats.backEdgeCount = stats.backEdgeCount + protoStats.backEdges
			stats.branchMergeCount = stats.branchMergeCount + protoStats.branchMerges
			stats.phiCandidateCount = stats.phiCandidateCount + protoStats.phiCandidates
			stats.phiLocvarHintCount = stats.phiLocvarHintCount + protoStats.phiLocvarHints
			stats.orDefaultHintCount = stats.orDefaultHintCount + protoStats.orDefaultHints
			stats.counterHintCount = stats.counterHintCount + protoStats.counterHints
			stats.guardedCallCount = stats.guardedCallCount + protoStats.guardedCalls
			stats.aliasHintCount = stats.aliasHintCount + protoStats.aliasHints
		end
	end
	return {
		stats = stats,
		protos = protos,
	}
end

local Module = {}

function Module.parseBytecode(data)
	assert(type(data) == "string", "parseBytecode expects raw bytecode string")
	-- [R2] Forward both return values.
	return parseBytecode(data)
end

function Module.analyze(data)
	assert(type(data) == "string", "analyze expects raw bytecode string")
	return analyzeBytecode(data)
end

function Module.render(data, options)
	assert(type(data) == "string", "render expects raw bytecode string")
	local normalized = normalizeOptions(options)
	if normalized.mode ~= "source" and normalized.mode ~= "asm" and normalized.mode ~= "both" then
		-- [R2] Default to source mode instead of throwing.
		normalized.mode = "source"
	end
	return renderBytecode(normalized, data)
end

function Module.decompile(data, options)
	return Module.render(data, options)
end

function Module.tryDecompile(data, options)
	return pcall(Module.decompile, data, options)
end

-- [A3] Parse without throwing. Returns (bc, nil) or (nil, err).
-- Callers that want to reuse a parsed bc across multiple renders can do:
--   local bc, err = Module.tryParseBytecode(data)
--   if bc then Module.decompile(data, { bc = bc, mode = "source" }) end
function Module.tryParseBytecode(data)
	return pcall(parseBytecode, data)
end

Module.Decompile = Module.decompile
Module.default = Module.decompile

return Module
