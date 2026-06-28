--[[
    LURKER AUTOPILOT - VERSION ESTABLE (PATRULLA SECTOR-1 REPARADA)
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

-- Variables de control de la IA y Seguimiento
local targetPosition = rootPart.Position
local isResting = false
local restTimer = 0
local currentVisualHeading = rootPart.CFrame.LookVector

-- Variables del sistema de comandos de voz Z
local leaderCharacter = nil      
local lastLeaderMoveTime = 0     
local leaderLastPos = Vector3.new()
local voiceCommandRange = 45     

-- Sistema de memoria a corto plazo optimizado
local lastVisitedPosition = rootPart.Position

toggleButton.MouseButton1Click:Connect(function()
	getgenv().LurkerAI_Enabled = not getgenv().LurkerAI_Enabled
	
	if getgenv().LurkerAI_Enabled then
		toggleButton.Text = "ESTADO: ACTIVO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		targetPosition = rootPart.Position
		currentVisualHeading = rootPart.CFrame.LookVector
		isResting = false
		leaderCharacter = nil
		lastVisitedPosition = rootPart.Position
		print("[AI] Regresando a versión estable de patrulla infinita.")
	else
		toggleButton.Text = "ESTADO: DESACTIVADO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		leaderCharacter = nil
	end
end)

-- =========================================================================
-- OYENTE TÁCTICO DE VOICELINES Z
-- =========================================================================
local function setupVoiceCommandListener(otherPlayer)
	otherPlayer.Chatted:Connect(function(message)
		if not getgenv().LurkerAI_Enabled then return end
		if otherPlayer == player then return end 
		
		local otherChar = otherPlayer.Character
		if not otherChar or not otherChar:FindFirstChild("HumanoidRootPart") then return end
		
		local distanceToSpeaker = (rootPart.Position - otherChar.HumanoidRootPart.Position).Magnitude
		
		if distanceToSpeaker <= voiceCommandRange then
			if message == "Follow Me!" or message == "Follow me!" or message == "Sígueme!" or message == "Sigueme!" then
				leaderCharacter = otherChar
				leaderLastPos = otherChar.HumanoidRootPart.Position
				lastLeaderMoveTime = os.clock()
				isResting = false
				print("[Voiceline Z] Siguiendo a: " .. otherPlayer.Name)
			end
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do setupVoiceCommandListener(p) end
Players.PlayerAdded:Connect(setupVoiceCommandListener)

-- =========================================================================
-- ESCÁNER INTELIGENTE DE PASILLOS (SECTOR-1)
-- =========================================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function calculateSmartLurkerPath()
	rayParams.FilterDescendantsInstances = {character}
	local origin = rootPart.Position + Vector3.new(0, 0.5, 0)
	
	local validOptions = {} 
	local backupOptions = {}
	
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		local distance = math.random(45, 80) 
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		
		local originLow = rootPart.Position + Vector3.new(0, -0.6, 0)
		local originHigh = rootPart.Position + Vector3.new(0, 1, 0)
		
		local rayLow = Workspace:Raycast(originLow, direction * distance, rayParams)
		local rayHigh = Workspace:Raycast(originHigh, direction * distance, rayParams)
		
		local distLow = rayLow and (rayLow.Position - rootPart.Position).Magnitude or distance
		local distHigh = rayHigh and (rayHigh.Position - rootPart.Position).Magnitude or distance
		local effectiveDistance = math.min(distLow, distHigh)
		
		if effectiveDistance < 4.5 then humanoid.Jump = true end
		
		if effectiveDistance > 15 then
			local potentialPoint = rootPart.Position + direction * (effectiveDistance - 5)
			local isReturnPath = (potentialPoint - lastVisitedPosition).Magnitude < 25
			
			if not isReturnPath then
				table.insert(validOptions, potentialPoint)
			else
				table.insert(backupOptions, potentialPoint)
			end
		end
	end
	
	local selectedPoint = nil
	if #validOptions > 0 then
		selectedPoint = validOptions[math.random(1, #validOptions)]
	elseif #backupOptions > 0 then
		selectedPoint = backupOptions[math.random(1, #backupOptions)]
	else
		local randomAngle = math.rad(math.random(0, 360))
		selectedPoint = rootPart.Position + Vector3.new(math.cos(randomAngle) * 20, 0, math.sin(randomAngle) * 20)
	end
	
	lastVisitedPosition = rootPart.Position
	return selectedPoint
end

-- =========================================================================
-- MOTOR DE MOVIMIENTO GENERAL (SOLO PATRULLA Y SEGUIMIENTO Z)
-- =========================================================================
RunService.Heartbeat:Connect(function(deltaTime)
	if not getgenv().LurkerAI_Enabled or not humanoid or humanoid.Health <= 0 then return end
	
	local currentSpeed = 7.2 
	local moveDirection = Vector3.new()
	local destinationPos = nil
	
	-- ESCORTANDO A JUGADOR (ORDEN "FOLLOW ME")
	if leaderCharacter and leaderCharacter:FindFirstChild("HumanoidRootPart") and leaderCharacter:FindFirstChild("Humanoid") and leaderCharacter.Humanoid.Health > 0 then
		local leaderRoot = leaderCharacter.HumanoidRootPart
		local distanceToLeader = (rootPart.Position - leaderRoot.Position).Magnitude
		
		if (leaderRoot.Position - leaderLastPos).Magnitude > 1.5 then
			leaderLastPos = leaderRoot.Position
			lastLeaderMoveTime = os.clock() 
		end
		
		if (os.clock() - lastLeaderMoveTime) > 15 then
			leaderCharacter = nil
			targetPosition = calculateSmartLurkerPath()
			return
		end
		
		if distanceToLeader > 25 then currentSpeed = 15 end
		
		if distanceToLeader > 6.5 then
			destinationPos = leaderRoot.Position
			local flatChar = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
			local flatLeader = Vector3.new(leaderRoot.Position.X, 0, leaderRoot.Position.Z)
			moveDirection = (flatLeader - flatChar).Unit
		else
			pcall(function() humanoid.RootPart.AssemblyLinearVelocity = Vector3.new() end)
			local lookTarget = Vector3.new(leaderRoot.Position.X, rootPart.Position.Y, leaderRoot.Position.Z)
			rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.lookAt(rootPart.Position, lookTarget), 10 * deltaTime)
			return
		end
		
	-- PATRULLA DE ACECHO ESTÁNDAR
	else
		if isResting then
			restTimer = restTimer - deltaTime
			if restTimer <= 0 then
				isResting = false
				targetPosition = calculateSmartLurkerPath() 
			end
			return
		end
		
		local flatCharacterPos = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
		local flatTargetPos = Vector3.new(targetPosition.X, 0, targetPosition.Z)
		local distance = (flatCharacterPos - flatTargetPos).Magnitude
		
		if distance > 3.5 then
			destinationPos = targetPosition
			moveDirection = (flatTargetPos - flatCharacterPos).Unit
		else
			isResting = true
			restTimer = math.random(3, 6) / 10 
			pcall(function() humanoid.RootPart.AssemblyLinearVelocity = Vector3.new() end)
			return
		end
	end
	
	-- Ejecución de traslación común en el mapa
	if destinationPos and moveDirection.Magnitude > 0 then
		local nextPosition = rootPart.Position + moveDirection * (currentSpeed * deltaTime)
		currentVisualHeading = currentVisualHeading:Lerp(moveDirection, 14 * deltaTime).Unit
		rootPart.CFrame = CFrame.lookAt(nextPosition, rootPart.Position + currentVisualHeading)
		
		pcall(function()
			humanoid.RootPart.AssemblyLinearVelocity = moveDirection * currentSpeed
		end)
		
		local obstacleRay = Workspace:Raycast(rootPart.Position, moveDirection * 4, rayParams)
		if obstacleRay then humanoid.Jump = true end
	end
end)

humanoid.Died:Connect(function()
	screenGui:Destroy()
end)

-- =========================================================================
-- OPTION 1 & 3: RADAR AUDITIVO Y BUSCADOR DE SUMINISTROS (Añadir funciones)
-- =========================================================================
local audioInvestigatePos = nil  -- Coordenada del ruido escuchado
local audioAlertActive = false   -- Estado de alerta
local hearingMaxRange = 60       -- Rango para escuchar pasos hostiles
local ammoBoxRange = 25          -- Distancia para buscar cajas de munición

-- 1. RADAR AUDITIVO: Detecta la velocidad física (pisadas) de Entidades
local function scanForNearbyFootsteps()
	if leaderCharacter or audioAlertActive then return nil end
	
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj.Health > 0 then
			local enemyChar = obj.Parent
			if enemyChar and enemyChar:IsA("Model") and enemyChar ~= character then
				-- Filtro: Asegura que sea un NPC/Infectado y no un jugador
				if not Players:GetPlayerFromCharacter(enemyChar) and enemyChar:FindFirstChild("HumanoidRootPart") then
					local enemyRoot = enemyChar.HumanoidRootPart
					local distance = (rootPart.Position - enemyRoot.Position).Magnitude
					
					-- Si está en rango y se está moviendo físicamente (AssemblyLinearVelocity > 2)
					if distance <= hearingMaxRange and enemyRoot.AssemblyLinearVelocity.Magnitude > 2 then
						return enemyRoot.Position
					end
				end
			end
		end
	end
	return nil
end

-- 3. RECOGIDA AUTOMÁTICA: Detecta Cajas de Munición en el mapa o del Standard
local function getNearbyAmmoBox()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		-- Revisa si es una caja de munición o el suministro de la clase Standard
		if obj:IsA("Model") and (string.find(string.lower(obj.Name), "ammo") or string.find(string.lower(obj.Name), "resupply")) then
			local boxPrimaryPart = obj.PrimaryPart or obj:FindFirstChildOfClass("Part")
			if boxPrimaryPart then
				local distance = (rootPart.Position - boxPrimaryPart.Position).Magnitude
				if distance <= ammoBoxRange then
					return boxPrimaryPart.Position, obj
				end
			end
		end
	end
	return nil, nil
end

-- =========================================================================
-- MOTOR DE MOVIMIENTO CON PRIORIDADES DE ACCIÓN (AUDIO, MUNICIÓN, PATRULLA)
-- =========================================================================
RunService.Heartbeat:Connect(function(deltaTime)
	if not getgenv().LurkerAI_Enabled or not humanoid or humanoid.Health <= 0 then return end
	
	local currentSpeed = 7.2 -- Velocidad estándar de patrulla sigilosa
	local moveDirection = Vector3.new()
	local destinationPos = nil
	
	-- ESCÁNER CONTINUO DE ESTADOS SECUNDARIOS
	local heardNoisePos = scanForNearbyFootsteps()
	if heardNoisePos and not leaderCharacter then
		audioInvestigatePos = heardNoisePos
		audioAlertActive = true
		isResting = false
	end
	
	local ammoPos, ammoObject = getNearbyAmmoBox()
	
	-- ---------------------------------------------------------------------
	-- ESTADO 1: PRIORIDAD ABSOLUTA - COOPERATIVO (VOICELINE Z "FOLLOW ME")
	-- ---------------------------------------------------------------------
	if leaderCharacter and leaderCharacter:FindFirstChild("HumanoidRootPart") and leaderCharacter:FindFirstChild("Humanoid") and leaderCharacter.Humanoid.Health > 0 then
		audioAlertActive = false -- Olvida los ruidos si tiene una orden directa
		local leaderRoot = leaderCharacter.HumanoidRootPart
		local distanceToLeader = (rootPart.Position - leaderRoot.Position).Magnitude
		
		if (leaderRoot.Position - leaderLastPos).Magnitude > 1.5 then
			leaderLastPos = leaderRoot.Position
			lastLeaderMoveTime = os.clock() 
		end
		
		if (os.clock() - lastLeaderMoveTime) > 15 then
			leaderCharacter = nil
			targetPosition = calculateSmartLurkerPath()
			return
		end
		
		if distanceToLeader > 25 then currentSpeed = 15 end
		
		if distanceToLeader > 6.5 then
			destinationPos = leaderRoot.Position
			local flatChar = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
			local flatLeader = Vector3.new(leaderRoot.Position.X, 0, leaderRoot.Position.Z)
			moveDirection = (flatLeader - flatChar).Unit
		else
			pcall(function() humanoid.RootPart.AssemblyLinearVelocity = Vector3.new() end)
			local lookTarget = Vector3.new(leaderRoot.Position.X, rootPart.Position.Y, leaderRoot.Position.Z)
			rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.lookAt(rootPart.Position, lookTarget), 10 * deltaTime)
			return
		end
		
	-- ---------------------------------------------------------------------
	-- ESTADO 2: RECOGIDA AUTOMÁTICA DE MUNICIÓN (OPCIÓN 3)
	-- ---------------------------------------------------------------------
	elseif ammoPos then
		audioAlertActive = false -- Concentrarse en reabastecerse
		local distanceToAmmo = (rootPart.Position - ammoPos).Magnitude
		
		if distanceToAmmo > 3 then
			destinationPos = ammoPos
			local flatChar = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
			local flatAmmo = Vector3.new(ammoPos.X, 0, ammoPos.Z)
			moveDirection = (flatAmmo - flatChar).Unit
			currentSpeed = 11 -- Camina un poco más rápido para recogerlo
		else
			-- Al llegar encima de la caja, simula la interacción nativa del Executor
			pcall(function()
				if ammoObject:FindFirstChildOfClass("ProximityPrompt") then
					fireproximityprompt(ammoObject:FindFirstChildOfClass("ProximityPrompt"))
				elseif ammoObject:FindFirstChildOfClass("ClickDetector") then
					fireclickdetector(ammoObject:FindFirstChildOfClass("ClickDetector"))
				end
				humanoid.RootPart.AssemblyLinearVelocity = Vector3.new()
			end)
			task.wait(0.3)
			targetPosition = calculateSmartLurkerPath() -- Sigue patrullando tras recoger
			return
		end

	-- ---------------------------------------------------------------------
	-- ESTADO 3: INVESTIGAR RUIDOS EXTRAÑOS / PISADAS CHIMERA (OPCIÓN 1)
	-- ---------------------------------------------------------------------
	elseif audioAlertActive and audioInvestigatePos then
		local distanceToNoise = (rootPart.Position - audioInvestigatePos).Magnitude
		
		if distanceToNoise > 5 then
			destinationPos = audioInvestigatePos
			local flatChar = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
			local flatNoise = Vector3.new(audioInvestigatePos.X, 0, audioInvestigatePos.Z)
			moveDirection = (flatNoise - flatChar).Unit
			currentSpeed = 13.5 -- Corre sigiloso pero alerta hacia el disturbio
		else
			-- Llegó a donde escuchó el ruido: se detiene 1 segundo a vigilar la zona
			pcall(function() humanoid.RootPart.AssemblyLinearVelocity = Vector3.new() end)
			isResting = true
			restTimer = 1.0
			audioAlertActive = false
			audioInvestigatePos = nil
			return
		end

	-- ---------------------------------------------------------------------
	-- ESTADO 4: MODO NORMAL - PATRULLA DE ACECHO INFINITA DEL LURKER
	-- ---------------------------------------------------------------------
	else
		leaderCharacter = nil
		if isResting then
			restTimer = restTimer - deltaTime
			if restTimer <= 0 then
				isResting = false
				targetPosition = calculateSmartLurkerPath() 
			end
			return
		end
		
		local flatCharacterPos = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
		local flatTargetPos = Vector3.new(targetPosition.X, 0, targetPosition.Z)
		local distance = (flatCharacterPos - flatTargetPos).Magnitude
		
		if distance > 3.5 then
			destinationPos = targetPosition
			moveDirection = (flatTargetPos - flatCharacterPos).Unit
		else
			isResting = true
			restTimer = math.random(3, 6) / 10 
			pcall(function() humanoid.RootPart.AssemblyLinearVelocity = Vector3.new() end)
			return
		end
	end
	
	-- Traslación física final del motor estable
	if destinationPos and moveDirection.Magnitude > 0 then
		local nextPosition = rootPart.Position + moveDirection * (currentSpeed * deltaTime)
		currentVisualHeading = currentVisualHeading:Lerp(moveDirection, 14 * deltaTime).Unit
		rootPart.CFrame = CFrame.lookAt(nextPosition, rootPart.Position + currentVisualHeading)
		
		pcall(function()
			humanoid.RootPart.AssemblyLinearVelocity = moveDirection * currentSpeed
		end)
		
		local obstacleRay = Workspace:Raycast(rootPart.Position, moveDirection * 4, rayParams)
		if obstacleRay then humanoid.Jump = true end
	end
end)

humanoid.Died:Connect(function()
	screenGui:Destroy()
end)
