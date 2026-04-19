-- ============================================
-- SCRIPT SCANNER v2 — Dump + Summarize
-- Now with: full source dump + multi-method clipboard
-- ============================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- SCRIPT COLLECTION
-- ============================================
local SCAN_ROOTS = {
    game:GetService("ReplicatedStorage"),
    game:GetService("ReplicatedFirst"),
    game:GetService("StarterPlayer"),
    game:GetService("StarterGui"),
    game:GetService("StarterPack"),
    game:GetService("Lighting"),
    game:GetService("Workspace"),
    LocalPlayer:FindFirstChild("PlayerGui"),
    LocalPlayer:FindFirstChild("PlayerScripts"),
    LocalPlayer.Character,
}

local function collectScripts()
    local found = {}
    local seen = {}
    for _, root in SCAN_ROOTS do
        if root then
            for _, inst in root:GetDescendants() do
                if (inst:IsA("LocalScript") or inst:IsA("ModuleScript") or inst:IsA("Script"))
                    and not seen[inst] then
                    seen[inst] = true
                    table.insert(found, inst)
                end
            end
        end
    end
    return found
end

local function tryReadSource(script)
    local ok, src = pcall(function() return script.Source end)
    if ok and type(src) == "string" and #src > 0 then return src end
    if decompile then
        local ok2, src2 = pcall(decompile, script)
        if ok2 and type(src2) == "string" and #src2 > 0 then return src2 end
    end
    return nil
end

local function getScriptPath(inst)
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, ".")
end

-- ============================================
-- MULTI-METHOD CLIPBOARD WITH CHUNKING + FILE FALLBACK
-- ============================================
local function findClipboardFn()
    local env = getfenv()
    local candidates = {
        "setclipboard", "set_clipboard", "toclipboard", "writeclipboard",
    }
    for _, name in candidates do
        if type(env[name]) == "function" then
            return env[name], name
        end
    end
    if Clipboard and type(Clipboard.set) == "function" then
        return function(s) Clipboard.set(s) end, "Clipboard.set"
    end
    return nil, nil
end

-- Returns: success(bool), method_used(string), error(string or nil)
local function robustCopy(text)
    if not text or #text == 0 then
        return false, "none", "nothing to copy"
    end

    local clip, name = findClipboardFn()
    if not clip then
        return false, "none", "no clipboard function available"
    end

    -- Small strings: direct copy
    if #text < 20000 then
        local ok, err = pcall(clip, text)
        if ok then return true, name, nil end
        return false, name, tostring(err)
    end

    -- Large strings: try direct first, fall back to just-copy-first-chunk with note
    local ok, err = pcall(clip, text)
    if ok then return true, name, nil end

    -- Some executors crash on huge strings — try a smaller chunk
    local truncated = text:sub(1, 50000) ..
        "\n\n-- [TRUNCATED — full content too large for clipboard. Use Save File for full content.] --"
    local ok2, err2 = pcall(clip, truncated)
    if ok2 then
        return true, name .. " (truncated)", nil
    end
    return false, name, tostring(err2 or err)
end

local function robustSave(text, filename)
    if not text or #text == 0 then return false, "nothing to save" end
    if type(writefile) ~= "function" then return false, "writefile unavailable" end
    local ok, err = pcall(writefile, filename, text)
    if ok then return true, nil end
    return false, tostring(err)
end

-- ============================================
-- DUMP BUILDER
-- ============================================
local function buildFullDump(scripts, includePreviewOnly, previewChars)
    local out = {}
    table.insert(out, "-- SCRIPT DUMP")
    table.insert(out, "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(out, "-- Total scripts: " .. #scripts)
    table.insert(out, "")

    local readable = 0
    local unreadable = 0

    for _, s in scripts do
        local path = getScriptPath(s)
        local src = tryReadSource(s)
        table.insert(out, "")
        table.insert(out, "========================================")
        table.insert(out, "-- " .. path)
        table.insert(out, "-- Type: " .. s.ClassName)
        table.insert(out, "========================================")
        if src then
            readable = readable + 1
            if includePreviewOnly then
                table.insert(out, src:sub(1, previewChars or 500))
                if #src > (previewChars or 500) then
                    table.insert(out, "-- [truncated, " .. #src .. " chars total]")
                end
            else
                table.insert(out, src)
            end
        else
            unreadable = unreadable + 1
            table.insert(out, "-- [source not readable]")
        end
    end

    table.insert(out, 1, "-- Readable: " .. readable .. " / Unreadable: " .. unreadable)
    return table.concat(out, "\n")
end

-- ============================================
-- HEURISTIC SUMMARIZER (kept from v1)
-- ============================================
local function summarizeHeuristic(source, name)
    local lines = {}
    local function add(s) table.insert(lines, s) end
    local loc = select(2, source:gsub("\n", "\n")) + 1
    local services = {}
    for svc in source:gmatch('GetService%(%s*"([%w_]+)"') do services[svc] = true end
    local svcList = {}
    for s in pairs(services) do table.insert(svcList, s) end
    table.sort(svcList)
    local remotes = {}
    for p in source:gmatch('([%w_]+):FireServer') do remotes[p .. ":FireServer"] = true end
    for p in source:gmatch('([%w_]+):InvokeServer') do remotes[p .. ":InvokeServer"] = true end
    for p in source:gmatch('([%w_]+)%.OnClientEvent') do remotes[p .. ".OnClientEvent"] = true end
    local keys = {}
    for k in source:gmatch('KeyCode%.([%w_]+)') do keys[k] = true end
    local flags = {}
    if source:find("HttpGet") or source:find("request%s*%(") then table.insert(flags, "HTTP") end
    if source:find("loadstring") then table.insert(flags, "loadstring") end
    if source:find("RenderStepped") or source:find("Heartbeat") then table.insert(flags, "per-frame") end
    if source:find("UserInputService") then table.insert(flags, "input") end
    if source:find("ScreenGui") then table.insert(flags, "GUI") end
    if source:find("Humanoid") then table.insert(flags, "humanoid") end

    add("Lines: " .. loc)
    if #svcList > 0 then add("Services: " .. table.concat(svcList, ", ")) end
    local rl = {} for r in pairs(remotes) do table.insert(rl, r) end
    if #rl > 0 then add("Remotes: " .. table.concat(rl, ", "):sub(1, 200)) end
    local kl = {} for k in pairs(keys) do table.insert(kl, k) end
    if #kl > 0 then add("Keys: " .. table.concat(kl, ", ")) end
    if #flags > 0 then add("Flags: " .. table.concat(flags, ", ")) end
    return table.concat(lines, " | ")
end

-- ============================================
-- GUI
-- ============================================
pcall(function() game:GetService("CoreGui"):FindFirstChild("ScriptScanner"):Destroy() end)
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("ScriptScanner"):Destroy() end)

local guiParent
local ok1 = pcall(function()
    local g = Instance.new("ScreenGui")
    g.Name = "ScriptScanner"
    g.ResetOnSpawn = false
    g.Parent = game:GetService("CoreGui")
    guiParent = g
end)
if not ok1 then
    local g = Instance.new("ScreenGui")
    g.Name = "ScriptScanner"
    g.ResetOnSpawn = false
    g.Parent = LocalPlayer:WaitForChild("PlayerGui")
    guiParent = g
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 820, 0, 500)
main.Position = UDim2.new(0.5, -410, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
main.BorderSizePixel = 0
main.Active = true
main.Parent = guiParent
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
titleBar.BorderSizePixel = 0
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Script Scanner v2 — Dump & Summarize"
titleLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 26)
closeBtn.Position = UDim2.new(1, -38, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(90, 35, 35)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
closeBtn.MouseButton1Click:Connect(function() guiParent:Destroy() end)

-- content area
local textArea = Instance.new("ScrollingFrame")
textArea.Size = UDim2.new(1, -20, 1, -140)
textArea.Position = UDim2.new(0, 10, 0, 44)
textArea.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
textArea.BorderSizePixel = 0
textArea.ScrollBarThickness = 6
textArea.CanvasSize = UDim2.new(0, 0, 0, 0)
textArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
textArea.Parent = main
Instance.new("UICorner", textArea).CornerRadius = UDim.new(0, 6)

local contentLabel = Instance.new("TextLabel")
contentLabel.Size = UDim2.new(1, -16, 0, 0)
contentLabel.Position = UDim2.new(0, 8, 0, 8)
contentLabel.AutomaticSize = Enum.AutomaticSize.Y
contentLabel.BackgroundTransparency = 1
contentLabel.Text = "Click 'Scan' to begin. Then 'Dump All' to gather every script's source into one blob for Gemini."
contentLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
contentLabel.Font = Enum.Font.Code
contentLabel.TextSize = 11
contentLabel.TextXAlignment = Enum.TextXAlignment.Left
contentLabel.TextYAlignment = Enum.TextYAlignment.Top
contentLabel.TextWrapped = true
contentLabel.Parent = textArea

-- button row 1
local function makeBtn(text, x, y, w, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 1, y)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(230, 230, 230)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local scanBtn       = makeBtn("Scan",         10,  -88, 90,  Color3.fromRGB(40, 85, 50))
local dumpAllBtn    = makeBtn("Dump All",     108, -88, 110, Color3.fromRGB(60, 50, 110))
local dumpIndexBtn  = makeBtn("Dump Index",   226, -88, 110, Color3.fromRGB(70, 60, 130))
local summariesBtn  = makeBtn("Summaries",    344, -88, 110, Color3.fromRGB(80, 65, 40))
local promptBtn     = makeBtn("Gemini Prompt",462, -88, 130, Color3.fromRGB(50, 80, 100))

local copyBtn       = makeBtn("Copy",         10,  -48, 90,  Color3.fromRGB(50, 60, 95))
local saveBtn       = makeBtn("Save File",    108, -48, 110, Color3.fromRGB(90, 65, 40))
local clearBtn      = makeBtn("Clear",        226, -48, 90,  Color3.fromRGB(60, 60, 70))

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -340, 0, 28)
statusLabel.Position = UDim2.new(0, 330, 1, -48)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready."
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = main

-- drag
local dragging, dragStart, startPos
local function beginDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true dragStart = input.Position startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end
titleBar.InputBegan:Connect(beginDrag)
titleLabel.InputBegan:Connect(beginDrag)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ============================================
-- STATE
-- ============================================
local scannedScripts = {}
local currentContent = "" -- full content, used by Copy and Save
local currentLabel = ""

local function setStatus(txt, color)
    statusLabel.Text = txt
    statusLabel.TextColor3 = color or Color3.fromRGB(160, 160, 170)
end

local function setContent(full, displayLabel)
    currentContent = full
    currentLabel = displayLabel or ""
    local display = full
    if #display > 50000 then
        display = display:sub(1, 50000) .. "\n\n-- [view truncated at 50k chars. Full " .. #full .. " chars available for Copy/Save] --"
    end
    contentLabel.Text = display
end

-- ============================================
-- GEMINI PROMPT
-- ============================================
local GEMINI_PROMPT = [[You're analyzing a Roblox game's client-side script dump to help me understand the game's architecture.

Below is a concatenation of every readable LocalScript and ModuleScript in the game, separated by banners that look like:

========================================
-- Full.Path.To.Script
-- Type: LocalScript
========================================

Please produce:

1. **High-level overview** — what kind of game this is and the main systems you can identify (combat, inventory, movement, UI framework, networking pattern, etc.)

2. **Key scripts** — for the 10-15 most important scripts, give me:
   - Full path
   - One-sentence purpose
   - Notable remotes it fires/listens to
   - Notable keybinds or input it handles

3. **Remote event map** — list every RemoteEvent/RemoteFunction name you see and guess what it does based on surrounding code.

4. **Client-side abilities/mechanics** — any interesting abilities, movesets, buffs, or custom mechanics and how they're triggered.

5. **Oddities** — anything that looks unusual, obfuscated, broken, or notable for debugging/development.

Be concise. Use bullet points. Skip scripts that are clearly boilerplate (stock Roblox UI modules, default character scripts, Knit/Nevermore framework internals) unless something looks customized.

Script dump follows:

---

]]

-- ============================================
-- ACTIONS
-- ============================================
scanBtn.MouseButton1Click:Connect(function()
    setStatus("Scanning...")
    task.spawn(function()
        scannedScripts = collectScripts()
        setContent("Scan complete. Found " .. #scannedScripts .. " scripts.\n\n"
            .. "Next steps:\n"
            .. "• Click 'Dump All' to get every script's full source (huge, for Gemini)\n"
            .. "• Click 'Dump Index' for a lighter version with previews only\n"
            .. "• Click 'Summaries' for heuristic per-script summaries\n"
            .. "• Click 'Gemini Prompt' to copy a ready-to-use prompt", "scan_result")
        setStatus("Found " .. #scannedScripts .. " scripts.", Color3.fromRGB(120, 220, 120))
    end)
end)

dumpAllBtn.MouseButton1Click:Connect(function()
    if #scannedScripts == 0 then setStatus("Scan first.", Color3.fromRGB(230, 150, 80)) return end
    setStatus("Dumping all sources...")
    task.spawn(function()
        local dump = buildFullDump(scannedScripts, false, nil)
        setContent(dump, "full_dump")
        setStatus("Dump built: " .. #dump .. " chars. Use Save File for large dumps.", Color3.fromRGB(120, 220, 120))
    end)
end)

dumpIndexBtn.MouseButton1Click:Connect(function()
    if #scannedScripts == 0 then setStatus("Scan first.", Color3.fromRGB(230, 150, 80)) return end
    setStatus("Building index with previews...")
    task.spawn(function()
        local dump = buildFullDump(scannedScripts, true, 400)
        setContent(dump, "index")
        setStatus("Index built: " .. #dump .. " chars.", Color3.fromRGB(120, 220, 120))
    end)
end)

summariesBtn.MouseButton1Click:Connect(function()
    if #scannedScripts == 0 then setStatus("Scan first.", Color3.fromRGB(230, 150, 80)) return end
    setStatus("Generating heuristic summaries...")
    task.spawn(function()
        local out = {"-- HEURISTIC SUMMARIES", "-- Total: " .. #scannedScripts, ""}
        for _, s in scannedScripts do
            local path = getScriptPath(s)
            local src = tryReadSource(s)
            if src then
                table.insert(out, "[" .. s.ClassName:sub(1,1) .. "] " .. path)
                table.insert(out, "    " .. summarizeHeuristic(src, s.Name))
            else
                table.insert(out, "[" .. s.ClassName:sub(1,1) .. "] " .. path .. "  [unreadable]")
            end
        end
        local joined = table.concat(out, "\n")
        setContent(joined, "summaries")
        setStatus("Done.", Color3.fromRGB(120, 220, 120))
    end)
end)

promptBtn.MouseButton1Click:Connect(function()
    setContent(GEMINI_PROMPT, "gemini_prompt")
    setStatus("Gemini prompt loaded. Copy it, then separately copy your dump, and paste both into Gemini.",
        Color3.fromRGB(120, 220, 120))
end)

copyBtn.MouseButton1Click:Connect(function()
    local ok, method, err = robustCopy(currentContent)
    if ok then
        setStatus("Copied via " .. method .. " (" .. #currentContent .. " chars)", Color3.fromRGB(120, 220, 120))
    else
        setStatus("Copy failed (" .. tostring(err) .. "). Use Save File instead.", Color3.fromRGB(230, 150, 80))
    end
end)

saveBtn.MouseButton1Click:Connect(function()
    local fname = currentLabel ~= "" and ("script_" .. currentLabel .. ".txt") or "script_dump.txt"
    local ok, err = robustSave(currentContent, fname)
    if ok then
        setStatus("Saved to workspace/" .. fname .. " (" .. #currentContent .. " chars)",
            Color3.fromRGB(120, 220, 120))
    else
        setStatus("Save failed: " .. tostring(err), Color3.fromRGB(230, 80, 80))
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    setContent("", "")
    setStatus("Cleared.")
end)

-- initial scan
task.spawn(function()
    scannedScripts = collectScripts()
    setContent("Initial scan complete. " .. #scannedScripts .. " scripts found.\n\n"
        .. "Buttons:\n"
        .. "  Scan          — rescan the game\n"
        .. "  Dump All      — full source of every script (biggest, for Gemini)\n"
        .. "  Dump Index    — paths + 400-char previews per script (lighter)\n"
        .. "  Summaries     — heuristic per-script structural summary\n"
        .. "  Gemini Prompt — shows the prompt to paste into Gemini\n"
        .. "  Copy          — tries setclipboard / toclipboard / set_clipboard / writeclipboard / Clipboard.set\n"
        .. "  Save File     — writes current content to workspace/ (best for large dumps)", "help")
    setStatus("Ready. " .. #scannedScripts .. " scripts detected.")
end)

print("[ScriptScanner v2] Loaded. Clipboard fn detected:",
    (select(2, findClipboardFn()) or "NONE"))
