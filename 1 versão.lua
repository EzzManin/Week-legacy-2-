-- 🌀 EzzHub - Versão Final com OK / Cancel Auto Equip + Toggles funcionais
-- ✅ LocalScript para executores (usa VirtualInputManager quando disponível)
-- Autor: Script by EzzManin (credits in UI)

if game.CoreGui:FindFirstChild("EzzHubUI") then
	pcall(function() game.CoreGui.EzzHubUI:Destroy() end)
end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- Config
local safePosition = Vector3.new(-256, -16, -215)
local targetsNames = {
	"Dungeon Bandit",
	"Dungeon Nezuko",
	"Dungeon Akaza",
	"Dungeon Zenitsu",
	"Dungeon Sanemi"
}

-- State
local attacking = false
local attackThread = nil
local followConnection = nil
local currentTarget = nil
local lastFarmPosition = nil
local teleportedForHP = false

local breathing = false
local autoHuman = false

-- Auto equip item state
local selectedFarmItem = nil       -- string name of tool
local autoEquipEnabled = false     -- on/off by OK/Cancel
local lastHeldChangeTick = 0       -- time when player changed held tool
local reEquipDelay = 5             -- seconds to wait before re-equipping selected item
local autoEquipLoopRunning = false

-- UI creation
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "EzzHubUI"
ScreenGui.ResetOnSpawn = false

-- Open button
local OpenButton = Instance.new("ImageButton", ScreenGui)
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.new(0, 64, 0, 64)
OpenButton.Position = UDim2.new(0, 18, 0.5, -32)
OpenButton.BackgroundTransparency = 1
OpenButton.Image = "rbxthumb://type=Asset&id=133393242441626&w=150&h=150"
OpenButton.Active = true
OpenButton.Draggable = true

-- Main frame
local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 420, 0, 360)
Frame.Position = UDim2.new(0.5, -210, 0.5, -180)
Frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Visible = false

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1, 0, 0, 44)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextScaled = true
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Text = "🌀 EzzHub"

-- Tabs
local Tabs = Instance.new("Frame", Frame)
Tabs.Size = UDim2.new(1, -20, 0, 40)
Tabs.Position = UDim2.new(0, 10, 0, 46)
Tabs.BackgroundTransparency = 1

local function newTabBtn(text, x)
	local b = Instance.new("TextButton", Tabs)
	b.Size = UDim2.new(0, 100, 1, 0)
	b.Position = UDim2.new(0, x, 0, 0)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.BackgroundColor3 = Color3.fromRGB(36,36,36)
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.BorderSizePixel = 0
	return b
end

local tabRaid = newTabBtn("Raid", 0)
local tabSettings = newTabBtn("Settings", 110)
local tabAutoFarm = newTabBtn("Auto Farm", 220)
local tabCredits = newTabBtn("Credits", 330)

-- Content frames
local function newContent()
	local f = Instance.new("Frame", Frame)
	f.Size = UDim2.new(1, -20, 1, -110)
	f.Position = UDim2.new(0, 10, 0, 100)
	f.BackgroundTransparency = 1
	f.Visible = false
	return f
end

local contentRaid = newContent()
local contentSettings = newContent()
local contentAutoFarm = newContent()
local contentCredits = newContent()
contentRaid.Visible = true

local function showTab(name)
	contentRaid.Visible = (name == "Raid")
	contentSettings.Visible = (name == "Settings")
	contentAutoFarm.Visible = (name == "Auto Farm")
	contentCredits.Visible = (name == "Credits")
end

tabRaid.MouseButton1Click:Connect(function() showTab("Raid") end)
tabSettings.MouseButton1Click:Connect(function() showTab("Settings") end)
tabAutoFarm.MouseButton1Click:Connect(function() showTab("Auto Farm") end)
tabCredits.MouseButton1Click:Connect(function() showTab("Credits") end)

OpenButton.MouseButton1Click:Connect(function()
	Frame.Visible = not Frame.Visible
end)

-- small helper to set chat system messages
local function sysMsg(text, color)
	pcall(function() StarterGui:SetCore("ChatMakeSystemMessage", {Text = text; Color = color or Color3.fromRGB(200,200,200)}) end)
end

-- Helper toggle creator
local function createToggle(parent, label, y)
	local btn = Instance.new("TextButton", parent)
	btn.Size = UDim2.new(0.95, 0, 0, 34)
	btn.Position = UDim2.new(0.025, 0, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.TextColor3 = Color3.fromRGB(255,255,255)
	btn.Text = "🔘 "..label..": OFF"
	return btn
end

-- ---------------- Raid tab UI ----------------
local killToggle = createToggle(contentRaid, "Kill NPCs", 0)
local raidWarning = Instance.new("TextLabel", contentRaid)
raidWarning.Size = UDim2.new(0.95,0,0,44)
raidWarning.Position = UDim2.new(0.025,0,0,44)
raidWarning.BackgroundTransparency = 1
raidWarning.Font = Enum.Font.GothamBold
raidWarning.TextScaled = true
raidWarning.TextColor3 = Color3.fromRGB(255,200,100)
raidWarning.Text = "⚠️ Requer level 250+ e estar dentro da masmorra"

-- ---------------- Settings tab UI ----------------
local breatheToggle = createToggle(contentSettings, "Auto Breathing", 0)
local humanToggle = createToggle(contentSettings, "Auto Human Perks", 44)

local equipHint = Instance.new("TextLabel", contentSettings)
equipHint.Size = UDim2.new(0.95,0,0,40)
equipHint.Position = UDim2.new(0.025,0,0,92)
equipHint.BackgroundTransparency = 1
equipHint.Font = Enum.Font.GothamBold
equipHint.TextScaled = true
equipHint.TextColor3 = Color3.fromRGB(255,255,180)
equipHint.Text = "Segure uma espada e aperte OK para equipar sozinho"

local okBtn = Instance.new("TextButton", contentSettings)
okBtn.Size = UDim2.new(0.42,0,0,34)
okBtn.Position = UDim2.new(0.05,0,0,140)
okBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
okBtn.Font = Enum.Font.GothamBold
okBtn.TextScaled = true
okBtn.TextColor3 = Color3.fromRGB(255,255,255)
okBtn.Text = "OK"
okBtn.BorderSizePixel = 0

local cancelBtn = Instance.new("TextButton", contentSettings)
cancelBtn.Size = UDim2.new(0.42,0,0,34)
cancelBtn.Position = UDim2.new(0.53,0,0,140)
cancelBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextScaled = true
cancelBtn.TextColor3 = Color3.fromRGB(255,255,255)
cancelBtn.Text = "Cancelar"
cancelBtn.BorderSizePixel = 0

local refreshBtn = Instance.new("TextButton", contentSettings)
refreshBtn.Size = UDim2.new(0.95,0,0,30)
refreshBtn.Position = UDim2.new(0.025,0,0,186)
refreshBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextScaled = true
refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
refreshBtn.Text = "🔄 Refresh"

local selectedLabel = Instance.new("TextLabel", contentSettings)
selectedLabel.Size = UDim2.new(0.95,0,0,28)
selectedLabel.Position = UDim2.new(0.025,0,0,220)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Font = Enum.Font.SourceSansBold
selectedLabel.TextScaled = true
selectedLabel.TextColor3 = Color3.fromRGB(200,200,255)
selectedLabel.Text = "Item selecionado: (nenhum)"

-- ---------------- Auto Farm / Credits UI ----------------
local afLabel = Instance.new("TextLabel", contentAutoFarm)
afLabel.Size = UDim2.new(0.95,0,0,80)
afLabel.Position = UDim2.new(0.025,0,0,10)
afLabel.BackgroundTransparency = 1
afLabel.Font = Enum.Font.GothamBold
afLabel.TextScaled = true
afLabel.TextColor3 = Color3.fromRGB(200,200,200)
afLabel.Text = "🚧 Em breve / Soon"

local cred1 = Instance.new("TextLabel", contentCredits)
cred1.Size = UDim2.new(0.95,0,0,30)
cred1.Position = UDim2.new(0.025,0,0,10)
cred1.BackgroundTransparency = 1
cred1.Font = Enum.Font.GothamBold
cred1.TextScaled = true
cred1.TextColor3 = Color3.fromRGB(200,200,200)
cred1.Text = "Script by EzzManin"

local cred2 = Instance.new("TextLabel", contentCredits)
cred2.Size = UDim2.new(0.95,0,0,48)
cred2.Position = UDim2.new(0.025,0,0,46)
cred2.BackgroundTransparency = 1
cred2.Font = Enum.Font.SourceSans
cred2.TextScaled = true
cred2.TextColor3 = Color3.fromRGB(180,180,180)
cred2.Text = "Script 100% criado por IA (ChatGPT)\nScript 100% created by AI (ChatGPT)"

local discordBtn = Instance.new("TextButton", contentCredits)
discordBtn.Size = UDim2.new(0.5,0,0,36)
discordBtn.Position = UDim2.new(0.25,0,0,120)
discordBtn.Text = "Discord"
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextScaled = true
discordBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
discordBtn.TextColor3 = Color3.fromRGB(255,255,255)
discordBtn.BorderSizePixel = 0

discordBtn.MouseButton1Click:Connect(function()
	local ok = false
	pcall(function()
		if setclipboard then setclipboard("https://discord.gg/fNCbwt6hXG"); ok = true end
		if syn and syn.set_clipboard then syn.set_clipboard("https://discord.gg/fNCbwt6hXG"); ok = true end
	end)
	if ok then sysMsg("[EzzHub] Link copiado para área de transferência.", Color3.fromRGB(120,255,120)) end
end)

-- Tab switching behavior
tabRaid.MouseButton1Click:Connect(function() showTab("Raid") end)
tabSettings.MouseButton1Click:Connect(function() showTab("Settings") end)
tabAutoFarm.MouseButton1Click:Connect(function() showTab("Auto Farm") end)
tabCredits.MouseButton1Click:Connect(function() showTab("Credits") end)

-- ---------- Core behaviors (functions) ----------

-- helper to send keys robustly (try strings then Enum)
local function sendKey(key)
	pcall(function() VirtualInputManager:SendKeyEvent(true, key, false, game) end)
	task.wait(0.04)
	pcall(function() VirtualInputManager:SendKeyEvent(false, key, false, game) end)
end

-- Find first matching raid npc
local function getFirstRaidNPC()
	local folder = Workspace:FindFirstChild("CharactersAndNPCs")
	if not folder then return nil end
	for _, npc in ipairs(folder:GetChildren()) do
		if npc and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") and npc.Humanoid.Health > 0 then
			if table.find(targetsNames, npc.Name) then
				return npc
			end
		end
	end
	return nil
end

-- smooth follow
local function startFollowingNPC(npc)
	if followConnection then
		pcall(function() followConnection:Disconnect() end)
		followConnection = nil
	end
	if not npc or not npc.Parent then return end
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local root = char.HumanoidRootPart
	local targetPart = npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
	if not targetPart then return end

	-- initial teleport if far
	if (root.Position - targetPart.Position).Magnitude > 16 then
		pcall(function()
			root.CFrame = CFrame.new(targetPart.Position + Vector3.new(0,10,0), targetPart.Position)
		end)
	end

	-- follow per-frame
	followConnection = RunService.RenderStepped:Connect(function()
		if not attacking or not npc or not npc.Parent or not npc:FindFirstChild("Humanoid") or npc.Humanoid.Health <= 0 then return end
		local desired = targetPart.Position + Vector3.new(0,10,0)
		local cur = root.Position
		local lerpPos = cur:Lerp(desired, 0.28)
		pcall(function() root.CFrame = CFrame.new(lerpPos, targetPart.Position) end)
	end)
end

local function stopFollowing()
	if followConnection then
		pcall(function() followConnection:Disconnect() end)
		followConnection = nil
	end
end

-- Attack loop
local function startAttackLoop()
	if attackThread then return end
	attackThread = task.spawn(function()
		while true do
			if attacking then
				local npc = getFirstRaidNPC()
				if npc then
					currentTarget = npc
					-- save last position
					if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
						lastFarmPosition = LocalPlayer.Character.HumanoidRootPart.Position
					end
					startFollowingNPC(npc)
					-- attack until npc dead
					while attacking and npc and npc.Parent and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 do
						-- click
						pcall(function()
							VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
							VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
						end)
						-- skills
						for _, k in ipairs({"Z","X","C","V","B"}) do
							pcall(sendKey, k)
							task.wait(0.05)
						end
						task.wait(0.04)
					end
					currentTarget = nil
					stopFollowing()
				else
					task.wait(0.4)
				end
			else
				task.wait(0.4)
			end
		end
	end)
end

-- Kill toggle behavior
killToggle.MouseButton1Click:Connect(function()
	attacking = not attacking
	killToggle.Text = attacking and "✅ Kill NPCs: ON" or "🔘 Kill NPCs: OFF"
	if attacking then
		showTab("Raid")
		startAttackLoop()
	else
		stopFollowing()
	end
end)

-- Auto Breathing toggle
breatheToggle.MouseButton1Click:Connect(function()
	breathing = not breathing
	breatheToggle.Text = breathing and "✅ Auto Breathing: ON" or "🔘 Auto Breathing: OFF"
	if breathing then
		task.spawn(function()
			while breathing do
				pcall(function() VirtualInputManager:SendKeyEvent(true, "G", false, game) end)
				task.wait(10)
				pcall(function() VirtualInputManager:SendKeyEvent(false, "G", false, game) end)
				task.wait(10)
			end
		end)
	end
end)

-- Auto Human Perks toggle
humanToggle.MouseButton1Click:Connect(function()
	autoHuman = not autoHuman
	humanToggle.Text = autoHuman and "✅ Auto Human Perks: ON" or "🔘 Auto Human Perks: OFF"
	if autoHuman then
		task.spawn(function()
			while autoHuman do
				local bp = LocalPlayer:FindFirstChild("Backpack")
				local char = LocalPlayer.Character
				if bp and char and char:FindFirstChild("Humanoid") then
					local tool = bp:FindFirstChild("Human Perks") or char:FindFirstChild("Human Perks")
					if tool then
						-- equip if in backpack
						if tool.Parent == bp then
							pcall(function() char.Humanoid:EquipTool(tool) end)
							task.wait(0.25)
						end
						-- press Z
						pcall(sendKey, "Z")
					end
				end
				-- wait 3 minutes with break condition
				local waited = 0
				while waited < 180 and autoHuman do
					task.wait(1); waited = waited + 1
				end
			end
		end)
	end
end)

-- Health monitor: only teleports when raid (attacking) and contentRaid is visible
local function monitorHealthForCharacter(char)
	if not char then return end
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end
	hum.HealthChanged:Connect(function(hp)
		-- hp can be nil if character resetting
		if hp and hp <= 4000 and attacking and not teleportedForHP then
			-- save and teleport to safe
			if char:FindFirstChild("HumanoidRootPart") then
				lastFarmPosition = char.HumanoidRootPart.Position
			end
			teleportedForHP = true
			pcall(function() char:MoveTo(safePosition) end)
			sysMsg("[EzzHub] Vida abaixo de 4k! Teleportando para local seguro...", Color3.fromRGB(255,100,100))
		elseif teleportedForHP and hp and hp >= (hum.MaxHealth or 100) then
			-- return
			if lastFarmPosition and char:FindFirstChild("HumanoidRootPart") then
				pcall(function() char:MoveTo(lastFarmPosition) end)
				sysMsg("[EzzHub] Vida recuperada! Voltando ao farm.", Color3.fromRGB(100,255,100))
			end
			teleportedForHP = false
			lastFarmPosition = nil
		end
	end)
end

monitorHealthForCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.6); monitorHealthForCharacter(c) end)

-- -------- Auto Equip logic (OK / Cancel / Refresh) --------
local function getHeldToolName()
	local char = LocalPlayer.Character
	if not char then return nil end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then return tool.Name end
	return nil
end

-- OK: select item and start auto-equip loop
okBtn.MouseButton1Click:Connect(function()
	local held = getHeldToolName()
	if held then
		selectedFarmItem = held
		autoEquipEnabled = true
		selectedLabel.Text = "Item selecionado: "..selectedFarmItem
		sysMsg("[EzzHub] Item salvo: "..selectedFarmItem, Color3.fromRGB(100,255,100))
		-- start loop if not running
		if not autoEquipLoopRunning then
			autoEquipLoopRunning = true
			task.spawn(function()
				while autoEquipLoopRunning do
					-- check currently held tool
					local char = LocalPlayer.Character
					if char and char:FindFirstChild("Humanoid") and selectedFarmItem and autoEquipEnabled then
						local heldTool = char:FindFirstChildOfClass("Tool")
						if heldTool and heldTool.Name == selectedFarmItem then
							-- reset timer
							lastHeldChangeTick = tick()
						else
							-- if holding another tool or none, wait reEquipDelay seconds (but allow player to hold different item during this time)
							local startWait = tick()
							while tick() - startWait < reEquipDelay and autoEquipEnabled do
								task.wait(0.2)
							end
							-- after wait, equip if still enabled and item in backpack
							if autoEquipEnabled and selectedFarmItem and char and char:FindFirstChild("Humanoid") then
								local bp = LocalPlayer:FindFirstChild("Backpack")
								if bp then
									local toolInBP = bp:FindFirstChild(selectedFarmItem)
									if toolInBP then
										pcall(function() char.Humanoid:EquipTool(toolInBP) end)
										lastHeldChangeTick = tick()
									end
								end
							end
						end
					end
					task.wait(0.6)
				end
			end)
		end
	else
		sysMsg("[EzzHub] Segure uma espada antes de apertar OK.", Color3.fromRGB(255,200,100))
	end
end)

-- Cancel: stop auto equip
cancelBtn.MouseButton1Click:Connect(function()
	autoEquipEnabled = false
	selectedFarmItem = nil
	selectedLabel.Text = "Item selecionado: (nenhum)"
	autoEquipLoopRunning = false
	sysMsg("[EzzHub] Auto Equip cancelado.", Color3.fromRGB(255,150,150))
end)

-- Refresh: update selected item with current held tool
refreshBtn.MouseButton1Click:Connect(function()
	local held = getHeldToolName()
	if held then
		selectedFarmItem = held
		selectedLabel.Text = "Item selecionado: "..selectedFarmItem
		sysMsg("[EzzHub] Item atualizado: "..selectedFarmItem, Color3.fromRGB(180,255,180))
	else
		sysMsg("[EzzHub] Nenhum item na mão para atualizar.", Color3.fromRGB(255,200,100))
	end
end)

-- Ensure UI indicates current selected item on load
if selectedFarmItem then selectedLabel.Text = "Item selecionado: "..selectedFarmItem end

-- Final ready message
sysMsg("[EzzHub] Carregado. Clique no ícone para abrir o menu.", Color3.fromRGB(120,200,255))
print("EzzHub loaded.")