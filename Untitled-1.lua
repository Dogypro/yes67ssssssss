local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
player.CharacterAdded:Connect(function(c) char = c hrp = c:WaitForChild("HumanoidRootPart") end)

local Net = RS:WaitForChild("Network")
local RUN = false
local room = 0
local done = false
local LOG = {}
local tapOn = false
local showTimer = false
local raidStart = 0
local raids = 0
local chestsDone = false
local creatingRaid = false
local locallyDead = {}

local CHEST_POS = Vector3.new(1134, 108, -5700)

local SignalMod, RaidCmds, ClientRaidInstance, RaidTypes, InstancingCmds, NetworkMod, BreakableCmds
local modulesOk = true
local function tryReq(path) local ok, mod = pcall(require, path) if ok then return mod end modulesOk = false return nil end
SignalMod = tryReq(RS.Library.Signal)
RaidCmds = tryReq(RS.Library.Client.RaidCmds)
ClientRaidInstance = tryReq(RS.Library.Client.RaidCmds.ClientRaidInstance)
RaidTypes = tryReq(RS.Library.Types.Raids)
InstancingCmds = tryReq(RS.Library.Client.InstancingCmds)
NetworkMod = tryReq(RS.Library.Client.Network)
BreakableCmds = tryReq(RS.Library.Client.BreakableCmds)

local function rf(n) return Net:FindFirstChild(n) end
local function log(m) pcall(function() table.insert(LOG, string.format("[%.1f] %s", tick() % 10000, m)) if #LOG > 500 then table.remove(LOG, 1) end end) end

-- Events
if NetworkMod then
	pcall(function() NetworkMod.Fired("PrivateInstance_Join"):Connect(function(d) if d then room = 0 done = false chestsDone = false creatingRaid = false locallyDead = {} raidStart = tick() end end) end)
	pcall(function() NetworkMod.Fired("Raid: Spawned Room"):Connect(function(n) room = n end) end)
	pcall(function() NetworkMod.Fired("Raid: Completed"):Connect(function() done = true log("COMPLETED") end) end)
end
pcall(function() rf("PrivateInstance_Join").OnClientEvent:Connect(function(d) if d then room = 0 done = false chestsDone = false creatingRaid = false locallyDead = {} raidStart = tick() end end) end)
pcall(function() rf("Raid: Spawned Room").OnClientEvent:Connect(function(n) room = n end) end)
pcall(function() rf("Raid: Completed").OnClientEvent:Connect(function() done = true end) end)

pcall(function() workspace.__THINGS.Breakables.ChildRemoved:Connect(function(c) local uid = c:GetAttribute("BreakableUID") if uid then locallyDead[uid] = nil end end) end)
pcall(function() workspace.__THINGS.AnimatedBreakables.ChildRemoved:Connect(function(c) local uid = c:GetAttribute("BreakableUID") if uid then locallyDead[uid] = nil end end) end)

local function loc()
	local ok, r = pcall(function()
		local a = workspace.__THINGS.__INSTANCE_CONTAINER.Active
		if a:FindFirstChild("LuckyRaid") then return "R" end
		if a:FindFirstChild("LuckyEventWorld") then return "E" end
	end)
	return ok and r or "?"
end

local function tp(p) pcall(function() local c = player.Character if c then local h = c:FindFirstChild("HumanoidRootPart") if h then h.CFrame = CFrame.new(p) end end end) end

local function smartTapAll()
	local tapped, killed = 0, 0
	for _, folder in {"Breakables", "AnimatedBreakables"} do
		pcall(function()
			for _, b in workspace.__THINGS[folder]:GetChildren() do
				local uid = b:GetAttribute("BreakableUID")
				if not uid or locallyDead[uid] then continue end
				if SignalMod then SignalMod.Fire("AutoClicker_Nearby", uid) end
				pcall(function() for _, d in b:GetDescendants() do if d:IsA("ClickDetector") then fireclickdetector(d) end end end)
				tapped = tapped + 1
				local hp = b:GetAttribute("Health")
				if hp and hp <= 0 then locallyDead[uid] = true killed = killed + 1 end
			end
		end)
	end
	pcall(function() rf("Click"):FireServer() end)
	return tapped, killed
end

local function scanBreakables()
	local myPos = Vector3.new(0, 108, -5700)
	pcall(function() myPos = player.Character.HumanoidRootPart.Position end)
	local best, bestDist = nil, math.huge
	local total = 0
	for _, folder in {"Breakables", "AnimatedBreakables"} do
		pcall(function()
			for _, b in workspace.__THINGS[folder]:GetChildren() do
				local uid = b:GetAttribute("BreakableUID")
				if uid and locallyDead[uid] then continue end
				local hp = b:GetAttribute("Health")
				if hp and hp <= 0 then continue end
				local pos
				local hitbox = b:FindFirstChild("Hitbox")
				if hitbox and hitbox:IsA("BasePart") then pos = hitbox.Position
				else for _, p in b:GetDescendants() do if p:IsA("BasePart") then pos = p.Position break end end end
				if pos then
					total = total + 1
					local d = (pos - myPos).Magnitude
					if d < bestDist then best = pos bestDist = d end
				end
			end
		end)
	end
	return best, bestDist, total
end

local function openChests()
	local ct = ""
	pcall(function() local cur = ClientRaidInstance.GetCurrent() if cur then ct = cur._ct or "" end end)
	if NetworkMod and ct ~= "" then
		pcall(function() NetworkMod.Invoke("Raids_CollectReward", "Tier1000Chest", ct) end)
		pcall(function() NetworkMod.Invoke("Raids_CollectReward", "LootChest", ct) end)
		pcall(function() NetworkMod.Invoke("Raids_CollectReward", "HugeChest", ct) end)
		pcall(function() NetworkMod.Invoke("Raids_CollectReward", "TitanicChest", ct) end)
	else
		task.spawn(function() pcall(function() rf("Raids_OpenChest"):InvokeServer("LootChest") end) end)
		task.spawn(function() pcall(function() rf("Raids_OpenChest"):InvokeServer("HugeChest") end) end)
		task.spawn(function() pcall(function() rf("Raids_OpenChest"):InvokeServer("TitanicChest") end) end)
		task.spawn(function() pcall(function() rf("Raids_OpenChest"):InvokeServer("Tier1000Chest") end) end)
		task.spawn(function() pcall(function() rf("Raids_CollectReward"):InvokeServer() end) end)
	end
end

local function createNewRaid()
	if not modulesOk then return end
	creatingRaid = true
	local function doCreate()
		local level = 1 pcall(function() level = RaidCmds.GetLevel() end)
		local pm = 1 pcall(function() pm = RaidTypes.PartyMode.Solo end)
		local portal pcall(function() local ok, p = pcall(SignalMod.Invoke, "Get Portal Number") if ok and p then portal = p end end)
		if not portal then pcall(function() for i = 1, 10 do if not ClientRaidInstance.GetByPortal(i) then portal = i break end end end) end
		if not portal then creatingRaid = false return end
		local ok, s, m, raid = pcall(RaidCmds.Create, { Portal = portal, Difficulty = level, PartyMode = pm })
		if ok and s and raid then pcall(raid.Join, raid) end
		creatingRaid = false
	end
	local inInst = false pcall(function() inInst = InstancingCmds.IsInInstance() end)
	if inInst then pcall(function() InstancingCmds.Leave(false, true, function() doCreate() end) end)
	else doCreate() end
end

-- Anti-AFK
task.spawn(function()
	local VIM pcall(function() VIM = game:GetService("VirtualInputManager") end)
	while true do
		if VIM then pcall(function() local vp = workspace.CurrentCamera.ViewportSize VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 0) task.wait(0.05) VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 0) end) end
		if SignalMod then pcall(function() SignalMod.Fire("ResetIdleTimer") end) end
		task.wait(30)
	end
end)

-- ============================================================
-- GUI: try CoreGui → gethui() → PlayerGui
-- ============================================================
pcall(function() game:GetService("CoreGui"):FindFirstChild("AR46"):Destroy() end)
pcall(function() player.PlayerGui:FindFirstChild("AR46"):Destroy() end)

local guiParent
local ok1 = pcall(function()
	local g = Instance.new("ScreenGui")
	g.Name = "AR46"
	g.Parent = game:GetService("CoreGui")
	guiParent = g
end)
if not ok1 then
	local ok2 = pcall(function()
		local g = Instance.new("ScreenGui")
		g.Name = "AR46"
		g.Parent = gethui()
		guiParent = g
	end)
	if not ok2 then
		local g = Instance.new("ScreenGui")
		g.Name = "AR46"
		g.ResetOnSpawn = false
		g.Parent = player.PlayerGui
		guiParent = g
	end
end
guiParent.ResetOnSpawn = false

local fr = Instance.new("Frame") fr.Size = UDim2.new(0, 195, 0, 220) fr.Position = UDim2.new(0, 10, 0.5, -110) fr.BackgroundColor3 = Color3.fromRGB(15, 15, 15) fr.BorderSizePixel = 0 fr.Active = true fr.Parent = guiParent
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)

-- Custom drag
local dragging, dragStart, startPos
fr.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true dragStart = input.Position startPos = fr.Position
		input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
	end
end)
UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		fr.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

local yy = 4
local function lbl(t, c, s) local l = Instance.new("TextLabel") l.Size = UDim2.new(1, -10, 0, 14) l.Position = UDim2.new(0, 5, 0, yy) l.BackgroundTransparency = 1 l.Text = t l.TextColor3 = c or Color3.fromRGB(190, 190, 190) l.TextSize = s or 11 l.Font = Enum.Font.Gotham l.TextXAlignment = Enum.TextXAlignment.Left l.Parent = fr yy = yy + 15 return l end
local function mbtn(t, c) local b = Instance.new("TextButton") b.Size = UDim2.new(1, -10, 0, 22) b.Position = UDim2.new(0, 5, 0, yy) b.BackgroundColor3 = c b.Text = t b.TextColor3 = Color3.new(1, 1, 1) b.TextSize = 12 b.Font = Enum.Font.GothamBold b.Parent = fr Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5) yy = yy + 25 return b end

lbl("RAID BOOST v46", Color3.new(1, 1, 1), 14).Font = Enum.Font.GothamBold
local sL = lbl("OFF") local rL = lbl("--") local dL = lbl("", Color3.fromRGB(255, 200, 80), 9) local tL = lbl("", Color3.fromRGB(100, 200, 255), 9)

local tapB = mbtn("360° Tap: OFF", Color3.fromRGB(50, 50, 50))
tapB.MouseButton1Click:Connect(function()
	tapOn = not tapOn
	tapB.Text = "360° Tap: " .. (tapOn and "ON" or "OFF")
	tapB.BackgroundColor3 = tapOn and Color3.fromRGB(200, 80, 0) or Color3.fromRGB(50, 50, 50)
end)

local timerB = mbtn("Timer: OFF", Color3.fromRGB(50, 50, 50))
timerB.MouseButton1Click:Connect(function() showTimer = not showTimer timerB.Text = "Timer: " .. (showTimer and "ON" or "OFF") timerB.BackgroundColor3 = showTimer and Color3.fromRGB(0, 130, 130) or Color3.fromRGB(50, 50, 50) if not showTimer then tL.Text = "" end end)

local goB = mbtn("START", Color3.fromRGB(0, 150, 0))

local function st(t) sL.Text = t end
local function rm(t) rL.Text = t end
local function db(t) dL.Text = t end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function boostLoop()
	local emptyTime = 0
	local sawBreakables = false

	while RUN do
		local l = loc()

		if l ~= "R" and not creatingRaid then
			st("Waiting...")
			db("loc=" .. l)
			chestsDone = false done = false emptyTime = 0 sawBreakables = false locallyDead = {}
			task.wait(0.5)
		elseif creatingRaid then
			st("Creating...")
			db("transitioning")
			task.wait(0.3)
		else
			if showTimer and raidStart > 0 then tL.Text = string.format("%.0fs", tick() - raidStart) end

			if not done then
				local nearest, dist, total = scanBreakables()
				local r = room if r < 1 then r = 1 end
				st("Room " .. r)

				local deadCount = 0
				for _ in locallyDead do deadCount = deadCount + 1 end
				rm(total .. " alive | " .. deadCount .. " dead")

				if total > 0 and nearest then
					sawBreakables = true emptyTime = 0
					tp(Vector3.new(nearest.X, 108, nearest.Z))
					db(total .. " | d=" .. string.format("%.0f", dist))
				else
					if sawBreakables then emptyTime = emptyTime + 0.03 end
					if r >= 10 and sawBreakables and emptyTime > 2 then done = true log("FORCE DONE") end
					db("empty " .. string.format("%.1f", emptyTime) .. "s")
				end

				if tapOn then smartTapAll() end

			elseif not chestsDone then
				st("Chests!")
				tp(CHEST_POS)
				task.wait(0.5)
				openChests()
				task.wait(1)
				chestsDone = true
				raids = raids + 1
				if showTimer and raidStart > 0 then tL.Text = string.format("Last: %.0fs", tick() - raidStart) end
				rm("Raids: " .. raids)
				log("DONE #" .. raids)
				task.spawn(createNewRaid)
			else
				st("Next raid...")
				db(creatingRaid and "creating" or "waiting")
			end
			task.wait(0.03)
		end
	end
end

goB.MouseButton1Click:Connect(function()
	RUN = not RUN
	if RUN then
		LOG = {} raidStart = tick() raids = 0 room = 0 done = false chestsDone = false creatingRaid = false locallyDead = {}
		goB.Text = "STOP" goB.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
		task.spawn(function()
			while RUN do
				local ok, err = pcall(boostLoop)
				if not ok then log("ERR: " .. tostring(err)) end
				if RUN then task.wait(2) end
			end
			st("OFF") rm("--") db("") tL.Text = ""
		end)
	else
		goB.Text = "START" goB.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
		tapOn = false tapB.Text = "360° Tap: OFF" tapB.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	end
end)