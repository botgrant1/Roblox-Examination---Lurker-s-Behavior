--[[
    LURKER AUTOPILOT - VERSION 15 (ANIMATION SYNC & REALSPEED CALIBRATION)
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

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

-- Variables de control de patrulla calibradas
local targetPosition = rootPart.Position
local isResting = false
local restTimer = 0

toggleButton.MouseButton1Click:Connect(function()
	getgenv().LurkerAI_Enabled = not getgenv().LurkerAI_Enabled
	
	if getgenv().LurkerAI_Enabled then
		toggleButton.Text = "ESTADO: ACTIVO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		targetPosition = rootPart.Position
		isResting = false
	else
		toggleButton.Text = "ESTADO: DESACTIVADO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	end
end)

-- =========================================================================
-- DETECTOR DE PASILLOS REALISTAS
-- =========================================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function calculateNewPatrolPoint()
	rayParams.FilterDescendantsInstances = {character}
	local origin = rootPart.Position + Vector3.new(0, 0.5, 0)
	
	local bestPoint = rootPart.Position
	local maxFreeSpace = 0
	
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		local distance = math.random(45, 75) -- Caminatas largas de exploración
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		
		local rayResult = Workspace:Raycast(origin, direction * distance, rayParams)
		local freeDistance = rayResult and (rayResult.Position - rootPart.Position).Magnitude or distance
		
		if freeDistance > maxFreeSpace and freeDistance > 15 then
			maxFreeSpace = freeDistance
			bestPoint = rootPart.Position + direction * (freeDistance - 6)
		end
	end
	return bestPoint
end

-- =========================================================================
-- MOTOR DE DESLIZAMIENTO CON SINCRONIZACIÓN DE ANIMACIONES
-- =========================================================================
RunService.Heartbeat:Connect(function(deltaTime)
	if not getgenv().LurkerAI_Enabled or not humanoid or humanoid.Health <= 0 then return end
	
	-- Si está quieto acechando, mantenemos la animación Idle por defecto
	if isResting then
		restTimer = restTimer - deltaTime
		if restTimer <= 0 then
			isResting = false
			targetPosition = calculateNewPatrolPoint()
		end
		return
	end
	
	local flatCharacterPos = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
	local flatTargetPos = Vector3.new(targetPosition.X, 0, targetPosition.Z)
	local distance = (flatCharacterPos - flatTargetPos).Magnitude
	
	if distance > 3 then
		-- CALIBRACIÓN: 13.5 studs/sec es la velocidad exacta de caminata acechante del Lurker
		local speed = 13.5 
		local moveDirection = (flatTargetPos - flatCharacterPos).Unit
		
		-- Desplazamiento matemático por CFrame
		local nextPosition = rootPart.Position + moveDirection * (speed * deltaTime)
		rootPart.CFrame = CFrame.lookAt(nextPosition, Vector3.new(targetPosition.X, rootPart.Position.Y, targetPosition.Z))
		
		-- TRUCO DE ANIMACIÓN: Forzamos al script 'Animate' del juego a detectar movimiento real.
		-- Le inyectamos una velocidad virtual para que empiece a mover las piernas de forma natural.
		pcall(function()
			humanoid.RootPart.AssemblyLinearVelocity = moveDirection * speed
		end)
		
		-- Salto automático si topamos con obstáculos bajos
		local obstacleRay = Workspace:Raycast(rootPart.Position, moveDirection * 3.5, rayParams)
		if obstacleRay then
			humanoid.Jump = true
		end
	else
		-- Llegamos al final del pasillo: entramos en pausa estática
		isResting = true
		restTimer = math.random(15, 25) / 10 -- Pausa de 1.5 a 2.5 segundos
		
		-- Frenamos la velocidad virtual para que regrese de inmediato a la animación Idle
		pcall(function()
			humanoid.RootPart.AssemblyLinearVelocity = Vector3.new()
		end)
	end
end)

humanoid.Died:Connect(function()
	screenGui:Destroy()
end)
