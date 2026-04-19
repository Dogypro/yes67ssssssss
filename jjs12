-- ============================================
-- AUTO COUNTER v3 — Eye Catching (Jujutsu Shenanigans)
-- Animation detection restored with STRICT targeting filters
-- Only fires when an attacker is truly aimed at YOU
-- ============================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local counterOn = false
local counters = 0
local lastFire = 0
local lastSelfAttack = 0

-- ============================================
-- TUNABLES  (adjust these if you still get FP/misses)
-- ============================================
local MELEE_RANGE       = 7     -- studs — how close counts as melee
local FACING_DOT        = 0.75  -- attacker must look at you (1.0 = perfect, 0.75 ≈ 40° cone)
local YOUR_ANGLE_DOT    = 0.30  -- you must be roughly in front of them (loose)
local EXTENDED_RANGE    = 14    -- longer-range anim (dash attacks, sweeps)
local EXTENDED_DOT      = 0.9   -- but must be aimed nearly dead-on

-- ============================================
-- KEY DETECTION
-- ============================================
local COUNTER_KEY = 0x33
local function refreshKey()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local ec = char:FindFirstChild("Moveset") and char.Moveset:FindFirstChild("Eye Catching")
		if ec then
			local k = ec:GetAttribute("Key")
			if k == 1 then COUNTER_KEY = 0x31
			elseif k == 2 then COUNTER_KEY = 0x32
			elseif k == 3 then COUNTER_KEY = 0x33
			elseif k == 4 then COUNTER_KEY = 0x34 end
		end
	end)
end
refreshKey()

local function fireCounter(reason)
	if not counterOn then return end
	if (tick() - lastFire) < 0.35 then return end
	lastFire = tick()
	counters = counters + 1
	keypress(COUNTER_KEY)
	task.delay(0.12, function() keyrelease(COUNTER_KEY) end)
end

-- ============================================
-- SELF-ATTACK TRACKING
-- ============================================
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(i, gpe)
	if gpe then return end
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.KeyCode == Enum.KeyCode.F or i.KeyCode == Enum.KeyCode.R
		or i.KeyCode == Enum.KeyCode.Q or i.KeyCode == Enum.KeyCode.E
		or i.KeyCode == Enum.KeyCode.Z or i.KeyCode == Enum.KeyCode.X
		or i.KeyCode == Enum.KeyCode.C then
		lastSelfAttack = tick()
	end
end)

local function isMyOwnHitbox(part)
	if (tick() - lastSelfAttack) < 0.4 then return true end
	local owner = part:GetAttribute("Owner") or part:GetAttribute("Player") or part:GetAttribute("Caster")
	if owner == LocalPlayer.Name or owner == LocalPlayer.UserId then return true end
	return false
end

-- ============================================
-- ANIM FILTER — non-combat anims to skip
-- ============================================
local SAFE = {}
for _, id in {"180435571","180435792","15621270146","7012721719","180436334","9442520397","178130996"} do
	SAFE[id] = true
end
local function isCombatAnim(track)
	if not track or not track.Animation then return false end
	local id = track.Animation.AnimationId
	if not id then return false end
	local n = id:match("%d+")
	return n and not SAFE[n]
end

-- ============================================
-- STRICT TARGETING CHECK
-- Returns true only if attacker is aimed at us
-- ============================================
local function isAimedAtMe(theirRoot, myRoot)
	local delta = myRoot.Position - theirRoot.Position
	local dist = delta.Magnitude
	if dist < 0.1 then return false end
	local toMe = delta.Unit

	-- attacker's forward dotted with direction-to-me
	local theirDot = theirRoot.CFrame.LookVector:Dot(toMe)
	-- our forward dotted with direction-to-them (are we in their swing arc)
	local myFacing = myRoot.CFrame.LookVector:Dot(-toMe)

	-- Melee: close + tightly facing us
	if dist <= MELEE_RANGE and theirDot >= FACING_DOT then
		-- and we're not completely behind them turning away
		if myFacing >= -0.8 then -- almost always true unless we're pointed directly away
			return true
		end
	end

	-- Extended (dashes/sweeps): further but has to be dead-on
	if dist <= EXTENDED_RANGE and theirDot >= EXTENDED_DOT then
		return true
	end

	return false
end

-- ============================================
-- MELEE ANIM WATCH
-- ============================================
local function watchPlayer(p)
	if p == LocalPlayer then return end
	local function onChar(char)
		pcall(function()
			local hum = char:WaitForChild("Humanoid", 10)
			if not hum then return end
			local animator = hum:WaitForChild("Animator", 5)
			if not animator then return end
			animator.AnimationPlayed:Connect(function(animTrack)
				if not counterOn then return end
				if not isCombatAnim(animTrack) then return end

				local myChar = LocalPlayer.Character
				if not myChar then return end
				local myRoot = myChar:FindFirstChild("HumanoidRootPart")
				local theirRoot = char:FindFirstChild("HumanoidRootPart")
				if not myRoot or not theirRoot then return end

				if isAimedAtMe(theirRoot, myRoot) then
					fireCounter("anim")
				end
			end)
		end)
	end
	if p.Character then onChar(p.Character) end
	p.CharacterAdded:Connect(onChar)
end

for _, p in Players:GetPlayers() do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

-- ============================================
-- HITBOX OVERLAP — for AoE/projectile/zone hits
-- ============================================
local processed = setmetatable({}, {__mode = "k"})

local function watchHitbox(part)
	if processed[part] then return end
	if not part:IsA("BasePart") then return end
	processed[part] = true

	task.spawn(function()
		local start = tick()
		while part.Parent and (tick() - start) < 0.8 do
			if counterOn then
				local myChar = LocalPlayer.Character
				if myChar and not isMyOwnHitbox(part) then
					local myHRP = myChar:FindFirstChild("HumanoidRootPart")
					if myHRP then
						local dist = (part.Position - myHRP.Position).Magnitude
						if dist < (part.Size.Magnitude + 10) then
							local params = OverlapParams.new()
							params.FilterType = Enum.RaycastFilterType.Include
							params.FilterDescendantsInstances = {myChar}
							params.MaxParts = 1
							local hits = workspace:GetPartsInPart(part, params)
							if #hits > 0 then
								fireCounter("hitbox")
								return
							end
						end
					end
				end
			end
			task.wait(0.025)
		end
	end)
end

local function monitorContainer(container)
	if not container then return end
	for _, c in container:GetChildren() do watchHitbox(c) end
	container.ChildAdded:Connect(watchHitbox)
end

monitorContainer(workspace:FindFirstChild("Effects"))
monitorContainer(workspace:FindFirstChild("Debris"))
monitorContainer(workspace:FindFirstChild("Hitboxes"))
workspace.ChildAdded:Connect(function(c)
	local n = c.Name:lower()
	if n == "effects" or n == "debris" or n:find("hitbox") then
		monitorContainer(c)
	end
end)

-- ============================================
-- PROJECTILE PREDICTION
-- ============================================
pcall(function()
	local eff = workspace:FindFirstChild("Effects")
	if not eff then return end
	eff.ChildAdded:Connect(function(part)
		if not counterOn or not part:IsA("BasePart") then return end
		if isMyOwnHitbox(part) then return end
		task.defer(function()
			for _ = 1, 15 do
				if not part.Parent or not counterOn then return end
				pcall(function()
					local myChar = LocalPlayer.Character
					local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
					if not myRoot then return end
					local toMe = myRoot.Position - part.Position
					local dist = toMe.Magnitude
					local vel = part.AssemblyLinearVelocity
					if vel.Magnitude > 15 and dist < 12 then
						local aimed = vel.Unit:Dot(toMe.Unit)
						local timeToHit = dist / vel.Magnitude
						if aimed > 0.75 and timeToHit < 0.15 then
							fireCounter("projectile")
							return
						end
					end
				end)
				task.wait(0.03)
			end
		end)
	end)
end)

-- ============================================
-- REMOTE BACKUP
-- ============================================
pcall(function()
	for _, svc in RS.Knit.Knit.Services:GetChildren() do
		local re = svc:FindFirstChild("RE")
		if not re or svc.Name == "EyeCatchService" then continue end
		for _, remote in re:GetChildren() do
			if not remote:IsA("RemoteEvent") then continue end
			remote.OnClientEvent:Connect(function(...)
				if not counterOn then return end
				local myChar = LocalPlayer.Character
				for _, arg in {...} do
					if typeof(arg) == "Instance" and arg == myChar then
						fireCounter("remote")
						return
					end
				end
			end)
		end
	end
end)

-- ============================================
-- RESPAWN
-- ============================================
LocalPlayer.CharacterAdded:Connect(function(char)
	character = char
	task.wait(0.5)
	refreshKey()
end)

-- ============================================
-- GUI
-- ============================================
pcall(function() game:GetService("CoreGui"):FindFirstChild("ACX"):Destroy() end)
local guiParent
local ok1 = pcall(function() local g = Instance.new("ScreenGui") g.Name="ACX" g.Parent=game:GetService("CoreGui") guiParent=g end)
if not ok1 then
	local ok2 = pcall(function() local g = Instance.new("ScreenGui") g.Name="ACX" g.Parent=gethui() guiParent=g end)
	if not ok2 then local g = Instance.new("ScreenGui") g.Name="ACX" g.ResetOnSpawn=false g.Parent=LocalPlayer.PlayerGui guiParent=g end
end
guiParent.ResetOnSpawn = false

local fr = Instance.new("Frame")
fr.Size = UDim2.new(0, 140, 0, 55)
fr.Position = UDim2.new(1, -150, 0, 10)
fr.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
fr.BorderSizePixel = 0 fr.Active = true fr.Parent = guiParent
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", fr).Color = Color3.fromRGB(80, 50, 100)

local dragging, dragStart, startPos
fr.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true dragStart = i.Position startPos = fr.Position
		i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		fr.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

local titleL = Instance.new("TextLabel")
titleL.Size = UDim2.new(0.6, 0, 0, 12) titleL.Position = UDim2.new(0, 8, 0, 4)
titleL.BackgroundTransparency = 1 titleL.Text = "COUNTER v3" titleL.TextColor3 = Color3.fromRGB(255, 180, 50)
titleL.TextSize = 10 titleL.Font = Enum.Font.GothamBold titleL.TextXAlignment = Enum.TextXAlignment.Left titleL.Parent = fr

local countL = Instance.new("TextLabel")
countL.Size = UDim2.new(0.4, -8, 0, 12) countL.Position = UDim2.new(0.6, 0, 0, 4)
countL.BackgroundTransparency = 1 countL.Text = "0" countL.TextColor3 = Color3.fromRGB(140, 140, 150)
countL.TextSize = 10 countL.Font = Enum.Font.Gotham countL.TextXAlignment = Enum.TextXAlignment.Right countL.Parent = fr

local toggleB = Instance.new("TextButton")
toggleB.Size = UDim2.new(1, -14, 0, 22) toggleB.Position = UDim2.new(0, 7, 0, 20)
toggleB.BackgroundColor3 = Color3.fromRGB(35, 35, 45) toggleB.Text = "OFF"
toggleB.TextColor3 = Color3.fromRGB(200, 200, 210) toggleB.TextSize = 13 toggleB.Font = Enum.Font.GothamBold
toggleB.Parent = fr Instance.new("UICorner", toggleB).CornerRadius = UDim.new(0, 6)
toggleB.MouseButton1Click:Connect(function()
	counterOn = not counterOn
	toggleB.Text = counterOn and "ON" or "OFF"
	toggleB.BackgroundColor3 = counterOn and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(35, 35, 45)
end)

task.spawn(function()
	while true do pcall(function() countL.Text = tostring(counters) end) task.wait(0.3) end
end)

print("Auto Counter v3 loaded. Key: 0x" .. string.format("%X", COUNTER_KEY))
