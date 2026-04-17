--[[
JS AUTO COUNTER v2 — Eye Catching
==================================
Eye Catching is a COUNTER STANCE — must be ACTIVE before hit lands.
This script keeps it active whenever threats are nearby.

Mode 1: REACTIVE — fires when enemy attacks detected via remotes
Mode 2: AGGRESSIVE — spams counter nonstop when enemy within range
]]

if _G.__AC_RUN then _G.__AC_RUN = false task.wait(0.3) end
if _G.__AC_CONNS then for _, c in _G.__AC_CONNS do pcall(function() c:Disconnect() end) end end
_G.__AC_RUN = true
_G.__AC_CONNS = {}
local CONNS = _G.__AC_CONNS
local function track(c) if c then table.insert(CONNS, c) end return c end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RUN = game:GetService("RunService")
local VIM pcall(function() VIM = game:GetService("VirtualInputManager") end)

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
track(player.CharacterAdded:Connect(function(c) char = c end))

local counterOn = false
local aggressive = false
local counters = 0
local RANGE = 30

-- ============================================================
-- ALL METHODS TO FIRE EYE CATCHING (fire all 3 every time)
-- ============================================================
local function fireCounter()
	-- Method 1: Knit remote
	pcall(function()
		local svc = RS.Knit.Knit.Services:FindFirstChild("EyeCatchService")
		if svc and svc.RE and svc.RE:FindFirstChild("Activated") then
			svc.RE.Activated:FireServer()
		end
	end)

	-- Method 2: Simulate key 3 press
	pcall(function()
		if VIM then
			VIM:SendKeyEvent(true, Enum.KeyCode.Three, false, game)
			task.defer(function()
				pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Three, false, game) end)
			end)
		end
	end)

	-- Method 3: Find the moveset value and use its service directly
	pcall(function()
		local moveset = char:FindFirstChild("Moveset")
		if moveset then
			local ec = moveset:FindFirstChild("Eye Catching")
			if ec then
				local svcName = ec:GetAttribute("Service")
				if svcName then
					local svc = RS.Knit.Knit.Services:FindFirstChild(svcName)
					if svc and svc.RE and svc.RE:FindFirstChild("Activated") then
						svc.RE.Activated:FireServer()
					end
				end
			end
		end
	end)

	counters = counters + 1
end

-- ============================================================
-- CHECK: is any enemy close enough to be a threat?
-- ============================================================
local function getClosestEnemy()
	local myHRP = char and char:FindFirstChild("HumanoidRootPart")
	if not myHRP then return nil, math.huge end
	local closest, dist = nil, math.huge
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character:FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - myHRP.Position).Magnitude
				if d < dist then closest = p dist = d end
			end
		end
	end
	return closest, dist
end

-- ============================================================
-- AGGRESSIVE MODE: spam counter every frame when enemy in range
-- ============================================================
task.spawn(function()
	while _G.__AC_RUN do
		if counterOn and aggressive then
			local _, dist = getClosestEnemy()
			if dist < RANGE then
				fireCounter()
			end
		end
		task.wait(0.05) -- 20x per second
	end
end)

-- ============================================================
-- REACTIVE MODE: listen to ALL enemy attack remotes
-- ============================================================
pcall(function()
	local services = RS.Knit.Knit.Services
	for _, svc in services:GetChildren() do
		local re = svc:FindFirstChild("RE")
		if not re then continue end

		-- Skip our own service
		if svc.Name == "EyeCatchService" then continue end

		-- Effects = attack visuals playing (someone is attacking)
		local effects = re:FindFirstChild("Effects")
		if effects and effects:IsA("RemoteEvent") then
			track(effects.OnClientEvent:Connect(function(...)
				if not counterOn then return end
				local args = {...}
				local myHRP = char and char:FindFirstChild("HumanoidRootPart")
				if not myHRP then return end

				for _, arg in args do
					-- If our character or any of our parts are in the args = we're being targeted
					if typeof(arg) == "Instance" then
						if arg == char or arg == player or (char and arg:IsDescendantOf(char)) then
							fireCounter()
							return
						end
						-- If it's another player's character attacking near us
						if arg:IsA("Model") and arg:FindFirstChild("HumanoidRootPart") then
							local d = (arg.HumanoidRootPart.Position - myHRP.Position).Magnitude
							if d < RANGE then
								fireCounter()
								return
							end
						end
					end
				end

				-- Fallback: if ANY effect fires and enemy is close, counter
				local _, dist = getClosestEnemy()
				if dist < 15 then
					fireCounter()
				end
			end))
		end

		-- Activated = someone used an ability
		local activated = re:FindFirstChild("Activated")
		if activated and activated:IsA("RemoteEvent") then
			track(activated.OnClientEvent:Connect(function(...)
				if not counterOn then return end
				local args = {...}
				local myHRP = char and char:FindFirstChild("HumanoidRootPart")
				if not myHRP then return end

				for _, arg in args do
					if typeof(arg) == "Instance" then
						if arg:IsA("Player") and arg ~= player then
							local ec = arg.Character and arg.Character:FindFirstChild("HumanoidRootPart")
							if ec and (ec.Position - myHRP.Position).Magnitude < RANGE then
								fireCounter()
								return
							end
						end
						if arg:IsA("Model") and arg:FindFirstChild("HumanoidRootPart") then
							if (arg.HumanoidRootPart.Position - myHRP.Position).Magnitude < RANGE then
								fireCounter()
								return
							end
						end
					end
				end
			end))
		end

		-- Hitbox = direct hit event
		local hitbox = re:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("RemoteEvent") then
			track(hitbox.OnClientEvent:Connect(function(...)
				if not counterOn then return end
				local args = {...}
				for _, arg in args do
					if typeof(arg) == "Instance" then
						if arg == char or arg == player or (char and arg:IsDescendantOf(char)) then
							fireCounter()
							return
						end
					end
				end
			end))
		end
	end
end)

-- ============================================================
-- BACKUP: health drop = we got hit while counter wasn't active
-- fire counter anyway in case we can still activate it
-- ============================================================
local function watchHealth()
	pcall(function()
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then return end
		local lastHP = hum.Health
		track(hum.HealthChanged:Connect(function(hp)
			if not counterOn then return end
			if hp < lastHP then fireCounter() end
			lastHP = hp
		end))
	end)
end
watchHealth()
track(player.CharacterAdded:Connect(function(c) char = c task.wait(0.5) watchHealth() end))

-- ============================================================
-- GUI
-- ============================================================
pcall(function() game:GetService("CoreGui"):FindFirstChild("AC2"):Destroy() end)
pcall(function() player.PlayerGui:FindFirstChild("AC2"):Destroy() end)
local guiParent
local ok1 = pcall(function() local g = Instance.new("ScreenGui") g.Name="AC2" g.Parent=game:GetService("CoreGui") guiParent=g end)
if not ok1 then
	local ok2 = pcall(function() local g = Instance.new("ScreenGui") g.Name="AC2" g.Parent=gethui() guiParent=g end)
	if not ok2 then local g = Instance.new("ScreenGui") g.Name="AC2" g.ResetOnSpawn=false g.Parent=player.PlayerGui guiParent=g end
end
guiParent.ResetOnSpawn = false

local fr = Instance.new("Frame")
fr.Size = UDim2.new(0, 175, 0, 115)
fr.Position = UDim2.new(1, -185, 0, 10)
fr.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
fr.BorderSizePixel = 0 fr.Active = true fr.Parent = guiParent
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke") stk.Color=Color3.fromRGB(60,40,80) stk.Thickness=1.5 stk.Parent=fr

local dragging, dragStart, startPos
track(fr.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=true dragStart=i.Position startPos=fr.Position
		i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
	end
end))
track(UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
		local d=i.Position-dragStart fr.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end))

local yy = 5
local function lbl(t, c, s)
	local l = Instance.new("TextLabel") l.Size=UDim2.new(1,-12,0,13) l.Position=UDim2.new(0,6,0,yy)
	l.BackgroundTransparency=1 l.Text=t l.TextColor3=c or Color3.fromRGB(180,180,190) l.TextSize=s or 11
	l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=fr yy=yy+15 return l
end
local function mbtn(t, c)
	local b = Instance.new("TextButton") b.Size=UDim2.new(1,-12,0,22) b.Position=UDim2.new(0,6,0,yy)
	b.BackgroundColor3=c b.Text=t b.TextColor3=Color3.new(1,1,1) b.TextSize=11 b.Font=Enum.Font.GothamBold
	b.Parent=fr Instance.new("UICorner",b).CornerRadius=UDim.new(0,5) yy=yy+25 return b
end

lbl("EYE CATCHING v2", Color3.fromRGB(255, 180, 50), 13)
local statL = lbl("Counters: 0", Color3.fromRGB(100,220,100), 10)

local toggleB = mbtn("Counter: OFF", Color3.fromRGB(50,50,60))
toggleB.MouseButton1Click:Connect(function()
	counterOn = not counterOn
	toggleB.Text = "Counter: " .. (counterOn and "ON" or "OFF")
	toggleB.BackgroundColor3 = counterOn and Color3.fromRGB(220,60,60) or Color3.fromRGB(50,50,60)
end)

local aggroB = mbtn("Aggressive: OFF", Color3.fromRGB(50,50,60))
aggroB.MouseButton1Click:Connect(function()
	aggressive = not aggressive
	aggroB.Text = "Aggressive: " .. (aggressive and "ON" or "OFF")
	aggroB.BackgroundColor3 = aggressive and Color3.fromRGB(180,50,220) or Color3.fromRGB(50,50,60)
end)

task.spawn(function()
	while _G.__AC_RUN do
		pcall(function()
			local _, dist = getClosestEnemy()
			local near = dist < RANGE
			statL.Text = "Counters: " .. counters .. (near and " | Enemy: " .. math.floor(dist) .. "s" or "")
			statL.TextColor3 = near and Color3.fromRGB(255,100,100) or Color3.fromRGB(100,220,100)
		end)
		task.wait(0.2)
	end
end)
