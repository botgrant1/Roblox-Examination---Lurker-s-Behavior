--[[
    LURKER SIMULATOR - INDEPENDENT THIRD PERSON VERSION
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

getgenv().LurkerAI_Enabled = false

-- =========================================================================
-- INTERFAZ GRÁFICA (MENÚ DE CONTROL)
-- =========================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LurkerControlGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 130)
mainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "LURKER AUTOPILOT"
titleLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 180, 0, 45)
toggleButton.Position = UDim2.new(0, 20, 0, 55)
toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
toggleButton.Text = "ESTADO: DESACTIVADO"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 14
toggleButton.Font = Enum.Font.SourceSans
toggleButton.Parent = mainFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton

local function releaseAllKeys()
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, game)
end

toggleButton.MouseButton1Click:Connect(function()
	getgenv().LurkerAI_Enabled = not getgenv().LurkerAI_Enabled
	
	if getgenv().LurkerAI_Enabled then
		toggleButton.Text = "ESTADO: ACTIVO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		-- TRUCO MAESTRO: Apagamos la rotación automática de la cámara del juego
		humanoid.AutoRotate = false 
		print("[AI] Simulación encendida de forma independiente a la cámara.")
	else
		toggleButton.Text = "ESTADO: DESACTIVADO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		humanoid.AutoRotate = true -- Devolvemos el control normal de cámara
		releaseAllKeys()
		print("[AI] Simulación apagada.")
	end
end)

-- =========================================================================
-- SISTEMA DE VISIÓN Y COMPORTAMIENTO AUTOMÁTICO
-- =========================================================================
local maxVisionDistance = 110
local currentTarget = nil
local currentDirection = rootPart.CFrame.LookVector
local isResting = false
local timeOnPath = 0
local maxPathTime = math.random(4, 7)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Buscador de pasillos abiertos mejorado (Ignora colisiones bajas)
local function scanBestPasillo()
	rayParams.FilterDescendantsInstances = {character}
	local origin = rootPart.Position + Vector3.new(0, 0.5, 0) -- Escaneo limpio a la altura de la cadera
	
	local bestDir = currentDirection
	local maxFreeSpace = 0
	
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		local testDir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		local rayResult = Workspace:Raycast(origin, testDir * 60, rayParams)
		local freeDistance = rayResult and (rayResult.Position - rootPart.Position).Magnitude or 60
		
		-- Si una caja obstruye de forma crítica la marcha, saltamos automáticamente
		if rayResult and freeDistance < 4.5 then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
			task.wait(0.01)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
		end
		
		if freeDistance > maxFreeSpace and freeDistance > 10 then
			maxFreeSpace = freeDistance
			bestDir = testDir
		end
	end
	return bestDir
end

local function hasLineOfSight(enemyRoot)
	rayParams.FilterDescendantsInstances = {character}
	local toEnemy = (enemyRoot.Position - rootPart.Position).Unit
	
	-- Usamos la dirección física real hacia donde apunta el pecho del personaje, NO la cámara
	local dotProduct = rootPart.CFrame.LookVector:Dot(toEnemy)
	if dotProduct < 0.6 then return false end 
	
	local origin = rootPart.Position + Vector3.new(0, 2, 0)
	local direction = (enemyRoot.Position - origin)
	local rayResult = Workspace:Raycast(origin, direction, rayParams)
	
	if rayResult and rayResult.Instance:IsDescendantOf(enemyRoot.Parent) then
		return true
	end
	return false
end

local function getVisibleEntity()
	local target = nil
	local closestDistance = maxVisionDistance
	
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj.Health > 0 then
			local enemyCharacter = obj.Parent
			if enemyCharacter and enemyCharacter:IsA("Model") and enemyCharacter ~= character then
				if not Players:GetPlayerFromCharacter(enemyCharacter) then
					local enemyRoot = enemyCharacter:FindFirstChild("HumanoidRootPart")
					if enemyRoot and hasLineOfSight(enemyRoot) then
						local distance = (rootPart.Position - enemyRoot.Position).Magnitude
						if distance < closestDistance then
							closestDistance = distance
							target = enemyRoot
						end
					end
				end
			end
		end
	end
	return target
end

-- Bucle asíncrono de IA
task.spawn(function()
	while task.wait(0.06) do
		if not getgenv().LurkerAI_Enabled then continue end
		if not humanoid or humanoid.Health <= 0 then break end
		
		local visibleEntity = getVisibleEntity()
		if visibleEntity then currentTarget = visibleEntity end
		
		-- ESTADO DE CAZA
		if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
			isResting = false
			local enemyPos = currentTarget.Position
			local distance = (rootPart.Position - enemyPos).Magnitude
			
			if distance > 130 then
				currentTarget = nil
				releaseAllKeys()
			elseif distance <= 7 then
				releaseAllKeys()
				local tool = character:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			else
				humanoid.WalkSpeed = 24
				
				-- Forzamos la rotación física del cuerpo hacia la entidad ignorando la cámara
				local targetLook = Vector3.new(enemyPos.X, rootPart.Position.Y, enemyPos.Z)
				rootPart.CFrame = CFrame.new(rootPart.Position, targetLook)
				
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
			end
			
		-- ESTADO DE PATRULLA REALISTA (Independiente del ratón/cámara)
		else
			currentTarget = nil
			humanoid.WalkSpeed = 15
			
			if isResting then
				releaseAllKeys()
			else
				currentDirection = scanBestPasillo()
				
				-- Orientamos físicamente el torso hacia el pasillo despejado
				local targetLook = rootPart.Position + currentDirection
				rootPart.CFrame = CFrame.new(rootPart.Position, Vector3.new(targetLook.X, rootPart.Position.Y, targetLook.Z))
				
				-- Presionamos la tecla de avance físico hacia esa rotación
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
				
				timeOnPath = timeOnPath + 0.06
				if timeOnPath >= maxPathTime then
					isResting = true
					releaseAllKeys()
					
					task.wait(math.random(15, 25) / 10) -- Pausa estática
					
					maxPathTime = math.random(4, 7)
					timeOnPath = 0
					isResting = false
				end
			end
		end
	end
end)

humanoid.Died:Connect(function()
	humanoid.AutoRotate = true
	releaseAllKeys()
	screenGui:Destroy()
end)
