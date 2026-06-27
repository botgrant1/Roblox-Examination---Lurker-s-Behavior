--[[
    LURKER AUTOPILOT - VERSION 13 (VIRTUAL INPUT CLICK STEERING)
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
-- INTERFAZ GRÁFICA (MENÚ DE CONTROL TOTALMENTE SEGURO)
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
toggleButton.Parent = toggleButton.Parent

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton
toggleButton.Parent = mainFrame

toggleButton.MouseButton1Click:Connect(function()
	getgenv().LurkerAI_Enabled = not getgenv().LurkerAI_Enabled
	
	if getgenv().LurkerAI_Enabled then
		toggleButton.Text = "ESTADO: ACTIVO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		-- Aseguramos que las propiedades nativas queden por defecto para evitar congelamientos
		humanoid.AutoRotate = true 
		print("[AI] Buscador por Clic Nativo Iniciado.")
	else
		toggleButton.Text = "ESTADO: DESACTIVADO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		humanoid:Move(Vector3.new(), false) -- Detener marcha
	end
end)

-- =========================================================================
-- SISTEMA DE VISIÓN Y LOGICA DE NAVEGACIÓN POR IMPULSO
-- =========================================================================
local maxVisionDistance = 110
local currentTarget = nil
local isResting = false
local currentTargetPos = rootPart.Position

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Buscador de pasillos abiertos con Raycast radial de seguridad
local function getNewPatrolPoint()
	rayParams.FilterDescendantsInstances = {character}
	local origin = rootPart.Position + Vector3.new(0, 0.5, 0)
	
	local bestPoint = rootPart.Position
	local maxFreeSpace = 0
	
	-- Escanea 12 direcciones a la redonda de forma tridimensional limpia
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		local distance = math.random(35, 65) -- Trayectos largos tipo Lurker
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		
		local rayResult = Workspace:Raycast(origin, direction * distance, rayParams)
		local freeDistance = rayResult and (rayResult.Position - rootPart.Position).Magnitude or distance
		
		if freeDistance > maxFreeSpace and freeDistance > 15 then
			maxFreeSpace = freeDistance
			-- Guardamos el punto restando un pequeño margen para no chocar de frente con el muro final
			bestPoint = rootPart.Position + direction * (freeDistance - 5)
		end
	end
	return bestPoint
end

local function hasLineOfSight(enemyRoot)
	rayParams.FilterDescendantsInstances = {character}
	local toEnemy = (enemyRoot.Position - rootPart.Position).Unit
	local dotProduct = rootPart.CFrame.LookVector:Dot(toEnemy)
	
	if dotProduct < 0.65 then return false end 
	
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

-- BUCLE DE ACCIÓN PRINCIPAL (Sincronizado de forma segura)
task.spawn(function()
	while task.wait(0.05) do
		if not getgenv().LurkerAI_Enabled then continue end
		if not humanoid or humanoid.Health <= 0 then break end
		
		local visibleEntity = getVisibleEntity()
		if visibleEntity then currentTarget = visibleEntity end
		
		-- ESTADO DE CAZA AGRESIVA
		if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
			isResting = false
			local enemyPos = currentTarget.Position
			local distance = (rootPart.Position - enemyPos).Magnitude
			
			if distance > 130 then
				currentTarget = nil
			elseif distance <= 6.5 then
				humanoid:Move(Vector3.new(), false)
				local tool = character:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			else
				humanoid.WalkSpeed = 24
				-- Impulsamos al jugador usando la dirección de mundo limpia hacia la entidad
				local targetDir = (Vector3.new(enemyPos.X, rootPart.Position.Y, enemyPos.Z) - rootPart.Position).Unit
				humanoid:Move(targetDir, false) -- Al estar AutoRotate en true, Roblox gira el cuerpo solo y de forma fluida
			end
			
		-- ESTADO DE PATRULLA ESTILO LURKER REPARADO
		else
			currentTarget = nil
			humanoid.WalkSpeed = 15
			
			if isResting then
				humanoid:Move(Vector3.new(), false)
			else
				local flatCharacterPos = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
				local flatTargetPos = Vector3.new(currentTargetPos.X, 0, currentTargetPos.Z)
				local distanceToPoint = (flatCharacterPos - flatTargetPos).Magnitude
				
				-- Si estamos lejos del pasillo abierto elegido, avanzamos de forma fluida e independiente de la cámara
				if distanceToPoint > 4 then
					local patrolDir = (flatTargetPos - flatCharacterPos).Unit
					
					-- Salto automático si nos topamos con un obstáculo bajo/caja de forma inesperada
					local frontRay = Workspace:Raycast(rootPart.Position, patrolDir * 4, rayParams)
					if frontRay then humanoid.Jump = true end
					
					humanoid:Move(patrolDir, false)
				else
					-- ¡Llegamos al final del pasillo despejado! Hacemos la pausa estática de acecho del Lurker original
					isResting = true
					humanoid:Move(Vector3.new(), false)
					
					task.wait(math.random(15, 25) / 10) -- Pausa de 1.5 a 2.5 segundos inmóvil
					
					-- Calculamos un nuevo pasillo largo y despejado de Examination
					currentTargetPos = getNewPatrolPoint()
					isResting = false
				end
			end
		end
	end
end)
