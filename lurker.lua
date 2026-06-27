--[[
    LURKER AUTOPILOT - VERSION 12 (WORLD SPACE NATIVE - FIXED CAMERA DECOUPLING)
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
-- INTERFAZ GRÁFICA (MENÚ DE CONTROL CON DESACTIVADO DE SEGURIDAD)
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

-- Variable para inyectar movimiento continuo al bucle del juego
local currentMoveVector = Vector3.new()

toggleButton.MouseButton1Click:Connect(function()
	getgenv().LurkerAI_Enabled = not getgenv().LurkerAI_Enabled
	
	if getgenv().LurkerAI_Enabled then
		toggleButton.Text = "ESTADO: ACTIVO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		humanoid.AutoRotate = false -- Desligamos el torso del mouse del jugador
	else
		toggleButton.Text = "ESTADO: DESACTIVADO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		humanoid.AutoRotate = true
		currentMoveVector = Vector3.new() -- Frenar en seco
	end
end)

-- =========================================================================
-- SISTEMA DE VISIÓN Y NAVEGACIÓN ABSOLUTA EN MUNDO
-- =========================================================================
local maxVisionDistance = 110
local currentTarget = nil
local patrolDirection = rootPart.CFrame.LookVector
local isResting = false
local timeOnPath = 0
local maxPathTime = math.random(5, 8)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Buscador de pasillos abiertos mediante muestreo de mundo (Ignora la cámara)
local function scanBestPasillo()
	rayParams.FilterDescendantsInstances = {character}
	local origin = rootPart.Position + Vector3.new(0, 0.5, 0)
	
	local bestDir = patrolDirection
	local maxFreeSpace = 0
	
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		local testDir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		local rayResult = Workspace:Raycast(origin, testDir * 55, rayParams)
		local freeDistance = rayResult and (rayResult.Position - rootPart.Position).Magnitude or 55
		
		-- Salto automático si nos topamos con decorado/cajas muy cerca
		if rayResult and freeDistance < 4 then
			humanoid.Jump = true
		end
		
		if freeDistance > maxFreeSpace and freeDistance > 14 then
			maxFreeSpace = freeDistance
			bestDir = testDir
		end
	end
	return bestDir
end

local function hasLineOfSight(enemyRoot)
	rayParams.FilterDescendantsInstances = {character}
	local toEnemy = (enemyRoot.Position - rootPart.Position).Unit
	
	-- El campo de visión se calcula desde el pecho del avatar, no desde tu cámara
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

-- INYECTOR DE MOVIMIENTO CONTINUO (Sincronizado a los FPS nativos)
RunService.Heartbeat:Connect(function()
	if not getgenv().LurkerAI_Enabled or not humanoid or humanoid.Health <= 0 then return end
	
	-- El truco maestro: el segundo parámetro es FALSE. Esto obliga a Roblox a caminar
	-- en coordenadas del mapa, ignorando por completo hacia dónde apunte tu cámara.
	humanoid:Move(currentMoveVector, false)
end)

-- Bucle lógico de toma de decisiones (Cero LAG de red)
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
				currentMoveVector = Vector3.new()
			elseif distance <= 6.5 then
				currentMoveVector = Vector3.new()
				local tool = character:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			else
				humanoid.WalkSpeed = 24
				
				-- Forzamos al cuerpo a mirar al infectado de frente
				local targetLook = Vector3.new(enemyPos.X, rootPart.Position.Y, enemyPos.Z)
				rootPart.CFrame = CFrame.new(rootPart.Position, targetLook)
				
				currentMoveVector = (targetLook - rootPart.Position).Unit
			end
			
		-- ESTADO DE PATRULLA SECTORIAL INDEPENDIENTE
		else
			currentTarget = nil
			humanoid.WalkSpeed = 15
			
			if isResting then
				currentMoveVector = Vector3.new()
			else
				-- Escaneamos pasillos abiertos limpios
				patrolDirection = scanBestPasillo()
				
				-- Orientamos el torso hacia el rumbo calculado
				local targetLook = rootPart.Position + patrolDirection
				rootPart.CFrame = CFrame.new(rootPart.Position, Vector3.new(targetLook.X, rootPart.Position.Y, targetLook.Z))
				
				-- Guardamos la dirección para que el Heartbeat la ejecute de forma fluida
				currentMoveVector = patrolDirection
				
				timeOnPath = timeOnPath + 0.05
				if timeOnPath >= maxPathTime then
					isResting = true
					currentMoveVector = Vector3.new()
					
					task.wait(math.random(15, 25) / 10) -- Pausa estática del Lurker
					
					maxPathTime = math.random(5, 8)
					timeOnPath = 0
					isResting = false
				end
			end
		end
	end
end)

humanoid.Died:Connect(function()
	humanoid.AutoRotate = true
	screenGui:Destroy()
end)
