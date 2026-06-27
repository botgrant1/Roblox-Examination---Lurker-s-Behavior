--[[
    LURKER AUTOPILOT - VERSION 17 (BUTTON FIXED & SECTOR-1 COORD)
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Variable global limpia
getgenv().LurkerAI_Enabled = true

-- =========================================================================
-- INTERFAZ GRÁFICA (MENÚ DE CONTROL REPARADO)
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

-- Variables de control de la IA
local targetPosition = rootPart.Position
local isResting = false
local restTimer = 0
local currentVisualHeading = rootPart.CFrame.LookVector

-- CLIC DEL BOTÓN CORREGIDO (100% Funcional)
toggleButton.MouseButton1Click:Connect(function()
	getgenv().LurkerAI_Enabled = not getgenv().LurkerAI_Enabled
	
	if getgenv().LurkerAI_Enabled then
		toggleButton.Text = "ESTADO: ACTIVO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		targetPosition = rootPart.Position
		currentVisualHeading = rootPart.CFrame.LookVector
		isResting = false
		print("[AI] Botón activado. Iniciando deambular del Sector-1.")
	else
		toggleButton.Text = "ESTADO: DESACTIVADO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		print("[AI] Botón desactivado. Modo Lurker en pausa.")
	end
end)

-- =========================================================================
-- ESCÁNER ADAPTADO A PASILLOS CERRADOS (SECTOR-1)
-- =========================================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function calculateSector1Point()
	rayParams.FilterDescendantsInstances = {character}
	local origin = rootPart.Position + Vector3.new(0, 0.5, 0)
	
	local bestPoint = rootPart.Position
	local maxFreeSpace = 0
	
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		local distance = math.random(20, 35) -- Distancias cortas ideales para el Sector-1
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		
		local originLow = rootPart.Position + Vector3.new(0, -0.7, 0)
		local originHigh = rootPart.Position + Vector3.new(0, 0.8, 0)
		
		local rayLow = Workspace:Raycast(originLow, direction * distance, rayParams)
		local rayHigh = Workspace:Raycast(originHigh, direction * distance, rayParams)
		
		local distLow = rayLow and (rayLow.Position - rootPart.Position).Magnitude or distance
		local distHigh = rayHigh and (rayHigh.Position - rootPart.Position).Magnitude or distance
		local effectiveDistance = math.min(distLow, distHigh)
		
		if effectiveDistance < 4 then
			humanoid.Jump = true
		end
		
		if effectiveDistance > maxFreeSpace and effectiveDistance > 8 then
			maxFreeSpace = effectiveDistance
			bestPoint = rootPart.Position + direction * (effectiveDistance - 4)
		end
	end
	return bestPoint
end

-- =========================================================================
-- MOTOR DE MOVIMIENTO Y ANIMACIONES
-- =========================================================================
RunService.Heartbeat:Connect(function(deltaTime)
	if not getgenv().LurkerAI_Enabled or not humanoid or humanoid.Health <= 0 then return end
	
	if isResting then
		restTimer = restTimer - deltaTime
		if restTimer <= 0 then
			isResting = false
			targetPosition = calculateSector1Point()
		end
		return
	end
	
	local flatCharacterPos = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
	local flatTargetPos = Vector3.new(targetPosition.X, 0, targetPosition.Z)
	local distance = (flatCharacterPos - flatTargetPos).Magnitude
	
	if distance > 2.5 then
		local speed = 6.5 -- Paso sigiloso del Lurker oficial
		local moveDirection = (flatTargetPos - flatCharacterPos).Unit
		
		local nextPosition = rootPart.Position + moveDirection * (speed * deltaTime)
		
		currentVisualHeading = currentVisualHeading:Lerp(moveDirection, 18 * deltaTime).Unit
		rootPart.CFrame = CFrame.lookAt(nextPosition, rootPart.Position + currentVisualHeading)
		
		pcall(function()
			humanoid.RootPart.AssemblyLinearVelocity = moveDirection * speed
		end)
	else
		isResting = true
		restTimer = math.random(5, 12) / 10 -- Pausa corta en la esquina (0.5 a 1.2 segundos)
		
		pcall(function()
			humanoid.RootPart.AssemblyLinearVelocity = Vector3.new()
		end)
	end
end)

humanoid.Died:Connect(function()
	screenGui:Destroy()
end)
