-- 🔐 Key Validator + Remote Script Runner + Advanced Anti-Sandbox

local env = {
    HttpService = game:GetService("HttpService"),
    Players = game:GetService("Players"),
    StarterGui = game:GetService("StarterGui"),
    RunService = game:GetService("RunService"),
    player = game:GetService("Players").LocalPlayer,
    tick = tick,
    typeof = typeof,
    getgenv = getgenv,
    getidentity = getidentity or (syn and syn.get_thread_identity) or function() return 2 end,
    getconnections = getconnections or get_signal_cons or nil,
    debug = debug or {},
    GLOBALS = getfenv(0),
}

local username = env.player and env.player.Name or "anonymous"
local AUTH_KEY = "sigmadigmabigma"  -- your fixed auth key (must match backend)
local VALIDATE_URL = "https://backend-9lks.onrender.com/validate-tempkey"

local function notify(title, text, duration)
    pcall(function()
        env.StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

-- 🧠 Advanced Anti-Sandbox
local function isSandboxed()
    local flags = {}

    -- ⛔ Suspicious usernames
    local bannedNames = {
        ["sandbox"] = true, ["testbot"] = true, ["altuser"] = true,
        ["localplayer"] = true, ["executor"] = true
    }
    if bannedNames[username:lower()] then
        table.insert(flags, "Suspicious username")
    end

    -- 🚫 Not in a real game
    if game.PlaceId == 0 or game.GameId == 0 then
        table.insert(flags, "Game not published")
    end

    -- 🧪 Studio or simulation
    if env.RunService:IsStudio() or env.RunService:IsRunning() == false then
        table.insert(flags, "Running in Studio/simulation")
    end

    -- 🔧 Check getconnections
    if env.typeof(env.getconnections) ~= "function" then
        table.insert(flags, "Missing getconnections")
    end

    -- 🧬 Check thread identity
    local ok, identity = pcall(env.getidentity)
    if not ok or identity > 2 then
        table.insert(flags, "Suspicious thread identity")
    end

    -- 📡 HttpService test
    local success = pcall(function()
        env.HttpService:RequestAsync({
            Url = "https://google.com",
            Method = "GET"
        })
    end)
    if not success then
        table.insert(flags, "Http blocked or faked")
    end

    -- 🕵️ Detect known globals
    local badGlobals = {
        "is_sirhurt_closure", "pebc_execute", "syn", "secure_call", "getrenv",
        "inject", "dumpstring", "hookfunction", "islclosure"
    }
    for _, g in ipairs(badGlobals) do
        if env.GLOBALS[g] ~= nil then
            table.insert(flags, "Detected global: " .. g)
        end
    end

    -- ⏱️ Timing-based analysis
    local start = env.tick()
    for _ = 1, 1e6 do end
    local delta = env.tick() - start
    if delta > 1 then
        table.insert(flags, "Slow tick response: " .. tostring(delta))
    end

    -- 🧾 Source info check
    local info = env.debug.getinfo and env.debug.getinfo(1)
    if info and info.short_src and info.short_src:lower():find("script") then
        table.insert(flags, "Script run from sandboxed file")
    end

    return #flags > 0, flags
end

-- 🛡️ Check sandbox status
local isBad, reasons = isSandboxed()
if isBad then
    notify("Security Error", "⚠️ Sandbox detected", 6)
    warn("[SANDBOX BLOCKED] Reasons:\n- " .. table.concat(reasons, "\n- "))
    return
end

-- 🔑 Key Input
local tempKey = env.getgenv().TempKey or nil
if not tempKey then
    notify("Key Loader", "❌ No TempKey in global env!", 6)
    return
end

notify("Key Loader", "🔍 Validating your temp key...")

-- 📬 Validate key request
local success, res = pcall(function()
    return env.HttpService:RequestAsync({
        Url = VALIDATE_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = AUTH_KEY,
        },
        Body = env.HttpService:JSONEncode({
            tempKey = tempKey,
            username = username,
        })
    })
end)

if not success or not res.Success then
    notify("Validation Failed", "⚠️ Could not validate key", 6)
    return
end

local data = env.HttpService:JSONDecode(res.Body)

if not data.valid then
    notify("Invalid Key", "❌ TempKey is invalid or expired.", 6)
    return
end

notify("Key Validated", "✅ Key accepted! Fetching script...")

if not data.script or type(data.script) ~= "string" then
    notify("Loader Error", "❌ Server didn’t return script.", 6)
    return
end

local func, compileErr = loadstring(data.script)
if not func then
    notify("Script Error", "❌ Compilation failed: " .. tostring(compileErr), 6)
    return
end

notify("Running Script", "⚙️ Executing remote code...")

local ok, runtimeErr = pcall(func)
if not ok then
    notify("Runtime Error", "❌ Error running script: " .. tostring(runtimeErr), 6)
else
    notify("Success", "🎉 Script executed!", 5)
end
