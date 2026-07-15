--[[luraph同款antitamper ByCcat a函数放源码 大概率不会被envlogger绕过 和原版相比我更改了一部分
 __  __                    /\/|___           ____         _
|  \/  | ___  _____      _|/\/  |_ _|_ __ ___  / ___|___ __ _| |_ 
| | \/| |/ _ \/ _ \ \ /\ / /     | || '_ ` _ \  | |   / __/ _` | __|
| |   | |  __/ (_) \ V  V /     | || | | | | | | |__| (_| (_| | |_ 
|_|   |_|\___|\___/ \_/\_/       |___|_| |_| |_|  \____\___\__,_|\__|
]]
local GlobalLuraphData = {}
GlobalLuraphData[2] = {}
GlobalLuraphData[3] = {}
local Stack = {}
local function a()
--这里放
end
local function b() error(":1:", 0) end
local c = b
local d = b
local function e() end
local function f() end
local function g() end
local h = {1, 2, 3, 4, 5, 6, -6783953644, 8}
local i
local j = {[11] = {}}
local w = next
local _done = false
local k,l,m,n,o = {}, {}, 0, {[5] = 1, [10] = 6, [3] = 2}, 0
        local function RunCrashFunction()
            local p = string.rep(' ', 8)
            local function ID_145(q, r)
                local s, t = 0, 1
                while 0 < q and 0 < r do
                    local u, v = q % 2, r % 2
                    if u ~= v then s = s + t end
                    q = (q - u) / 2
                    r = (r - v) / 2
                    t = t * 2
                end

                if q >= r then
                    r = q
                end

                while r > 0 do
                    local u = r % 2

                    if u > 0 then
                        s = s + t
                        r = (r - u) / 2
                        t = t * 2
                    else
                        r = (r - u) / 2
                        t = t * 2
                    end
                end

                return s
            end
            local function ID_153(q, r, s)
                if s then
                    local t = q / 2 ^ (r - 1) % 2 ^ (s - 1 - (r - 1) + 1)

                    return t - t % 1
                end

                local t = 2 ^ (r - 1)
                local u = q % (t + t)

                return u >= t and 1 or u or 0
            end
            local function ID_160()
                local q, r, s, t = string.byte(p, 1, 4)

                return ID_145(t, 64) * 16777216 + ID_145(s, 32) * 65536 + ID_145(r, 16) * 256 + ID_145(q, 8)
            end
            local function ID_165()
                local q, r = ID_160(), ID_160()
                local s, t, u = ID_153(r, 1, 20) * 4294967296 + q, ID_153(r, 21, 31), -1 ^ ID_153(r, 32)

                if t == 0 then
                    if s == 0 then
                        return 0
                    else
                        return u * 2.2250738585072014E-308 * (s / 4503599627370496)
                    end
                else
                    if t ~= 2047 then
                        return u * 2 ^ (t - 1023) * (1 + s / 4503599627370496)
                    end
                    if s == 0 then
                        r = u / 0
                    end

                    return r or 0 / 0
                end
            end
            local function ID_172()
                for q = 1, ID_160()do
                    local r = {}

                    for s = 0, 255 do
                        r[ID_145(ID_160(), ID_160())] = ID_145(ID_160(), ID_160())
                        r[ID_145(ID_160(), ID_160())] = ID_145(ID_160(), ID_160())
                    end
                    for s = 1, ID_160()do
                        for t = 0, 255 do
                            local u = ID_165()

                            if u then
                                u = ID_160()
                            end

                            r[u] = r[ID_165()] or ID_145(ID_165(), ID_165())

                            local v, w = ID_160(), ID_165()

                            if w then
                                w = ID_165()
                            end

                            r[ID_153(ID_165(), ID_160())] = {
                                ID_165(),
                                ID_160(),
                            }
                        end
                    end
                end

                return ID_145(ID_165(), ID_160())
            end

            while ID_172() do
                ID_172()
            end

            local q, r = j[11], {}

            for s = 1, #j[11]do
                q[s] = r
            end

            while true do end
        end

        local p = {
            [1642754488] = 25,
            [3105969070] = 50,
            [48342080] = 50,
            [793184576] = 25,
        }

        local function RunCrashFunctionIndirect()
            a = RunCrashFunction

            pcall(string.find, pcall(string.rep, ' ', 1048576), pcall(string.rep, '.?', 1048576))
            pcall(unpack, {}, 0, 2147483647)

            return RunCrashFunction()
        end

        local q, r, s, t = getfenv(), next, {}

        while true do
            t, Value = next(q, t)

            if t == nil then
                break
            end
            if type(t) == 'string' and #t < 20 then
                local u, v, w, x = 2166136261, {
                    string.byte(t, 1, -1),
                }, r

                while true do
                    local y

                    x, y = r(v, x)

                    if x == nil then
                        break
                    end

                    local z = bit32.bxor(u, y)

                    if z >= 134217728 then
                        local A = z % 65536
                        local B, C = (z - A) / 65536, A * 403

                        u = (B * 403 + A * 256) % 65536 * 65536 + C
                    else
                        u = z * 16777619 % 4294967296
                    end
                end

                m = m + (p[u] or 0)
                o = o + 1

                if not _done then
                    _done = true

                    local function CreateTrapMt()
                        local y = {
                            __index = RunCrashFunctionIndirect,
                            __newindex = RunCrashFunctionIndirect,
                            __eq = RunCrashFunctionIndirect,
                            __call = RunCrashFunctionIndirect,
                            __tostring = RunCrashFunctionIndirect,
                            __metatable = false,
                        }

                        k[#k + 1] = y

                        return y
                    end
                    local function CreateTrapTable()
                        return setmetatable({}, setmetatable(CreateTrapMt(), CreateTrapMt()))
                    end
                    local function MustEqOrCrash(y, ...)
                        local z = {...}

                        for A = 1, select('#', ...)do
                            if y == z[A] then
                                return true
                            end
                        end

                        RunCrashFunctionIndirect()
                    end

                    if Stack then
                        if type(Stack) ~= 'table' then
                            RunCrashFunctionIndirect()
                        elseif getmetatable(Stack) ~= nil then
                            RunCrashFunctionIndirect()
                        end
                    else
                        RunCrashFunctionIndirect()
                    end

                    setmetatable(Stack, nil)

                    local function TrapTableCheck()
                        local function ReturnItself(...)
                            return ...
                        end

                        local y = {
                            __tostring = RunCrashFunctionIndirect,
                            __call = ReturnItself,
                            __add = ReturnItself,
                            __sub = ReturnItself,
                            __mul = ReturnItself,
                            __div = ReturnItself,
                            __mod = ReturnItself,
                            __pow = ReturnItself,
                            __eq = ReturnItself,
                            __lt = ReturnItself,
                            __le = ReturnItself,
                            __concat = ReturnItself,
                            __index = ReturnItself,
                            __newindex = ReturnItself,
                            __metatable = false,
                        }

                        local function TrueIfEq(z, A)
                            return ({
                                [z] = false,
                                [A] = true,
                            })[z]
                        end

                        local z = setmetatable({}, y)

                        MustEqOrCrash(TrueIfEq(z, z(z, z, z(z), z())), true)
                        MustEqOrCrash(TrueIfEq(z, z(z .. z, z .. '', '' .. z)), true)
                        MustEqOrCrash(TrueIfEq(z, z + z - z * z / z % z ^ z), true)
                        MustEqOrCrash(TrueIfEq(z, z(z, z, z(), z(z), z(z, z))), true)

                        z[z] = MustEqOrCrash(TrueIfEq(z, z), true)
                        z[z] = MustEqOrCrash(TrueIfEq(z[z], z), true)

                        MustEqOrCrash(TrueIfEq(z, (function(...)
                            return ..., z
                        end)(z, z)), true)

                        z[''] = z['']
                        y.__tostring = nil
                    end

                    TrapTableCheck()

                    local y, z = pcall(b)
                    local A, B = pcall(c)
                    local C, D = pcall(d)

                    if y then
                        RunCrashFunctionIndirect()
                    end
                    if A then
                        RunCrashFunctionIndirect()
                    end
                    if C then
                        RunCrashFunctionIndirect()
                    end

                    local function RunAntiBeautifyChecks(E)
                        local F, G, H, I, J = string.match(E, ':(%d+)[:\r\n]'), string.gmatch(E, ':(%d+)[:\r\n]')(), nil, string.find(E, ':(%d+)[:\r\n]')

                        if not I then
                            RunCrashFunctionIndirect()
                        end
                        if not J then
                            RunCrashFunctionIndirect()
                        end

                        local K, L = string.sub(E, I + 1, J - 1), string.char(string.byte(E, I + 1, J - 1))

                        string.gsub(E, ':(%d+)[:\r\n]', function(M)
                            H = M
                        end)

                        if not F then
                            RunCrashFunctionIndirect()
                        end
                        if not G then
                            RunCrashFunctionIndirect()
                        end
                        if not K then
                            RunCrashFunctionIndirect()
                        end
                        if not L then
                            RunCrashFunctionIndirect()
                        end
                        if not H then
                            RunCrashFunctionIndirect()
                        end

                        MustEqOrCrash(F, G)
                        MustEqOrCrash(G, K)
                        MustEqOrCrash(K, L)
                        MustEqOrCrash(L, H)
                        MustEqOrCrash(F, G)
                        MustEqOrCrash(G, K)
                        MustEqOrCrash(K, L)
                        MustEqOrCrash(L, H)

                        return F
                    end

                    local E, F, G = RunAntiBeautifyChecks(z), RunAntiBeautifyChecks(B), RunAntiBeautifyChecks(D)

                    MustEqOrCrash(E, F)
                    MustEqOrCrash(F, G)
                    MustEqOrCrash(G, E)

                    for H = 0, 2 do
                        local I, J = pcall(getfenv, H)

                        if I then
                            if J then
                                if type(J) == 'table' then
                                    if l[J] then
                                        l[H] = l[J]
                                    else
                                        local K = {[13091] = J}

                                        l[J] = K
                                        l[H] = K
                                        K[55579] = rawget(J, 'tostring')

                                        rawset(J, 'tostring', RunCrashFunctionIndirect)

                                        local L = CreateTrapTable()

                                        l[L] = K

                                        pcall(setfenv, H, L)
                                    end
                                end
                            end
                        end
                    end

                    TrapTableCheck()

                    for H = 0, 2 do
                        if l[H] then
                            pcall(setfenv, H, l[H][13091])
                            rawset(l[H][13091], 'tostring', l[H][55579])
                        end
                    end

                    if h then
                        local H, I = #h, h[1]

                        if I >= h[6] then
                            I = h[3]
                        end
                        if H ~= -6783953710 + (bit32.bxor(bit32.lshift(I or h[1], 6), h[5]) - h[7] + h[5]) then
                            RunCrashFunctionIndirect()
                        end
                    else
                        RunCrashFunctionIndirect()
                    end

                    for H = 1, 4 + bit32.countlz(bit32.lshift(h[5] - h[2], 22) - h[8] + h[1])do
                        e()
                    end

                    local H = bit32.bxor(h[2], h[1]) + h[1] < h[8]

                    if H then
                        H = h[7]
                    end

                    for I = 1, -192623621 + ((H or h[2]) + h[1])do
                        f()
                    end

                    local I = h[3]

                    if I <= h[2] then
                        I = h[3]
                    end

                    for J = 1, -979832072 + (bit32.lshift(bit32.lrotate((I or h[6]) - h[1], 31), 5) - h[1])do
                        g()
                    end

                    local J, K, L = a(), 226, GlobalLuraphData[2]

                    for M = 0, 255 do
                        s[bit32.bxor(K, 98)] = string.char(K)
                        K = (97 * K + 33) % 256
                    end

                    local function DecryptConstant(M)
                        local N = M[0]
                        local O, P = (type(N))

                        if O ~= 'boolean' then
                            if O ~= 'string' then
                                if O ~= 'number' or N == 0 then
                                    P = N
                                else
                                    P = -N
                                end
                            else
                                local Q = (97 * string.byte(N, 1, 1) + 33) % 256

                                P = ''

                                for R = 2, #N do
                                    local S = string.byte(N, R)

                                    P = P .. s[bit32.bxor(S, Q)]
                                    Q = (97 * Q + 33) % 256
                                end
                            end
                        else
                            P = not N
                        end

                        for Q = 1, #M, 3 do
                            local R, S, T = M[Q], M[Q + 1], M[Q + 2]

                            R[T][S] = P
                            R[n[T] ][S] = nil
                        end
                    end

                    local M, N = {
                        __index = function(M, N)
                            local O = M[0][N]

                            if not O then
                                return nil
                            end

                            L[O] = nil

                            DecryptConstant(GlobalLuraphData[2][O])

                            return M[N]
                        end,
                    }

                    while true do
                        local O

                        N, O = w(GlobalLuraphData[3], N)

                        if N == nil then
                            break
                        end

                        local P, Q, R = O[3], O[10], O[5]

                        P[0] = O[2]
                        Q[0] = O[6]
                        R[0] = O[1]

                        setmetatable(O[3], M)
                        setmetatable(O[10], M)
                        setmetatable(O[5], M)
                    end

                    GlobalLuraphData[2] = nil
                    GlobalLuraphData[3] = nil

                    local O, P = w

                    while true do
                        local Q

                        P, Q = w(k, P)

                        if P == nil then
                            break
                        end

                        local R, S = Q

                        while true do
                            S, Value2 = O(Q, S)

                            if S == nil then
                                break
                            end

                            R[S] = nil
                        end

                        O = O
                    end

                    local Q, R = pcall(loadstring, [=[

        --[[

                         .@%(/*,.......      ...,,*/(#%&@@.
                     (*   ,/(#%%&&@@@@&%((////(((##%###((/**,,.     ,//(&.
                   /* .%@@@@@@@@%,  .(&@@@&&&&&&@@@@@@&#(*,........*%@@@(.  ,#.
                 */ .&@@@@@@@*  (%,   *(&&@@@@@&%(*,.             .,*(#%(*@@&*  *,
                #, /@@@@@@* *&( ,&&/.,/#%&&@@@&(&@@@@@@@@@@@@#*,.....,/&@@@@@@@@( .%
               #  #@@@@@*/@% .#%./(,.,/*,//*,.,/(*@@@@@@@@@@@@%@@@@@@@@@#.#@@@@@@&. %
              /  &@@@@@@@@(%@# *&&*&@@@@#/&@@@@/%%.,%@@@@@@@%/@@&(,  ,,,...  *%@@@# *
            #  .&@@@@@@@@@@@,((%@@@@@#.    ,&@@#@@&* .&@@@@@&,.#@@@@/&@@%(@@@&(/,(&, /,
         (/   (@&&&%&@@@&/, ,@#(@@@@,        #@@/,&@& /@@@@@,%#%@@@@@(     *@@@@@&,%%. .
        /  #/,#@@@&#(//#@@@/ %@@@&@@@(.    ,&@@(.*/*  %@@*   %@@@@@@%       (@@&(*...%&.
         ///@@&,  (&@@#,   /@/ ,*&@@@@#&@@%#%((%@&* /@@@@@@&. #@@@#&@@@&%%@@@@@@&,/(*@/#
        %%.&@# .&@@@# /@@@@%&@@@&/.   ,/((/*,  ./&@@@@@@@@@@,*&(./%@@#*&@@@(#(....,&#*@/
        @%.&& .&@@@&*    /&@@@@@@@@@@@@@@@@&@@#/(%@@@@@@@@@@&,  (@@@@@@@@@@@@/,@@@@@#.&*
        &&,%% .&*    /@@@(.  ,(@@@@@&/(////#( /&@@@@@@@@@@@@@@@(  ,&@@@@@@@@&, (@@&*/@(/
        .%*#@( /@@@@( *@@@@@@/     *%@@@@@@@&.,@& ,#, .&@@@@@@# .#*%&/,#@@@@*   *@@&/*&*
         .&/.#@@@@@@@,   *&@@%.,&@@&(,    ,(%@%&@@@@@@@@@(.*,  /@@@@@@@@@&,      %@@@@..
        @* .%@@@@@@@@(       .   (@@@@@@@@(       .*(%&@@@@@@@@@@@@&(,  ./.*@%   /@@% ./
          @* .&@@@@@@&.             ./&@@@*.&@@@@@@@&, ,**,.    .,*(&(.%@@# %@*  ,@@% ,#
            &, /@@@@@@*                    .#@@@@@@@@*.%@@@@@(,@@@@@@& ,%(.      .&@% ,#
              / *@@@@@#                                                           %@&.,#
              (( .&@@@@*                                                          #@&.,#
               .&. ,&@@@,                                                         (@&.,#
                  #. .%@@* /@@/                                                   /@&.,(
                    ./  #@%. %@&,,#,                                              /@@,./
                      *(  #@%. . (@@@@@%/,                                        /@@,.*
                        //  %@&, *@@@@@@@@( (@%/.                                 #@@, (
                          #* .&@@#. (@@@@&.*@@@@@@@@%. */.                  *..%*.&@@, /
                            @* .%@@@%, ,/ .@@@@@@@@@@,.%@@@@@% .&@@@* #@&..&@*,* %@@&. *
                               /  *&@@@@%,   *(&@@@@&. #@@@@@* #@@@% (@@* ,.   /@@@@* (
                                 @#. .#@@@@@@&(,.                      .,*(%&@@@@@&..(
                                     &(.   ./%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(. ((
                                          ,#/*.       ..,,,,,,,,....          ,/#

        ]]--

        ]=] .. string.format(' return setfenv(function(...) return %s(...) end, setmetatable({ ["%s"] = ... }, { __index = getfenv((...)) })) ', 'VFjoOcwIn', 'VFjoOcwIn'), 'Luraph', nil)

                    if not Q then
                        local function Fail()
                            error"Your Lua environment does not support load or loadstring, therefore you are unable to use Luraph's 'LPH_NO_UPVALUES' macro."
                        end

                        GlobalLuraphData[5] = Fail

                        return J
                    end
                    if not R then
                        local function Fail()
                            error"Your Lua environment does not support load or loadstring, therefore you are unable to use Luraph's 'LPH_NO_UPVALUES' macro."
                        end

                        GlobalLuraphData[5] = Fail

                        return J
                    end
                    if type(R) == 'function' then
                        GlobalLuraphData[5] = R

                        return J
                    end

                    local function Fail()
                        error"Your Lua environment does not support load or loadstring, therefore you are unable to use Luraph's 'LPH_NO_UPVALUES' macro."
                    end

                    GlobalLuraphData[5] = Fail

                    return J
                end

                r = w
            end
        end