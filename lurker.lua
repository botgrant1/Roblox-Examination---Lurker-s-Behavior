--[[
    LURKER AUTOPILOT - VERSION 7 (PHYSICAL KEYBOARD SIMULATION)
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

print("[Lurker Exploit] Versión 7 Cargada: Simulación física de teclado sin tirones.")

-- Configuraciones de IA y sensores
local maxVisionDistance = 120
local currentTarget = nil
local activeKeys = {W = false, A = false, S = false, D = false}

-- Parámetros de Raycast para evadir muros
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- 1. CONTROLADOR DE PULSACIÓN FÍSICA (Emula tu teclado real)
local function pressKey(key, hold)
	if activeKeys[key] == hold then return end -- Si ya está en ese estado, no hace nada
	activeKeys[key] = hold
	
	if hold then
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
	else
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
	end
end

-- Limpia todas las teclas presionadas para evitar que camine solo eternamente al apagarse
local function clearKeyboard()
	for key, isPressed in pairs(activeKeys) do
		if isPressed then pressKey(key, false) end
	end
end

-- 2. DETECTOR DE OBSTÁCULOS POR RAYCAST (Bigotes de gato mecánicos)
local function getNavigationAdjustment()
	rayParams.FilterDescendantsInstances = {character}
	
	local lookDir = rootPart.CFrame.LookVector
	local rightDir = rootPart.CFrame.RightVector
	
	-- Lanza un rayo frontal para saber si hay una pared o puerta encima
	local frontRay = Workspace:Raycast(rootPart.Position, lookDir * 7, rayParams)
	
	if frontRay and not frontRay.Instance:IsDescendantOf(character) then
		-- Si nos pegamos demasiado, forzamos un salto automático para saltar barandas u objetos bajos
		if (frontRay.Position - rootPart.Position).Magnitude < 4.5 then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
			task.wait(0.05)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
		end
		
		-- Evaluamos cuál lateral del pasillo está libre
		local leftRay = Workspace:Raycast(rootPart.Position, -rightDir * 10, rayParams)
		local rightRay = Workspace:Raycast(rootPart.Position, rightDir * 10, rayParams)
		
		if not leftRay then return "A" end -- Girar a la izquierda
		if not rightRay then return "D" end -- Girar a la derecha
		return "S" -- Retroceder si es un callejón sin salida
	end
	return "W" -- Avanzar libremente si no hay nada en frente
end

-- 3. FILTRO DE LÍNEA DE VISIÓN HUMANA
local function hasLineOfSight(enemyRoot)
	rayParams.FilterDescendantsInstances = {character}
	
	local toEnemy = (enemyRoot.Position - rootPart.Position).Unit
	local dotProduct = rootPart.CFrame.LookVector:Dot(toEnemy)
	
	if dotProduct < 0.65 then return false end -- Cono de visión de 90 grados frontal
	
	local origin = rootPart.Position + Vector3.new(0, 2, 0)
	local direction = (enemyRoot.Position - origin)
	local rayResult = Workspace:Raycast(origin, direction, rayParams)
	
	if rayResult and rayResult.Instance:IsDescendantOf(enemyRoot.Parent) then
		return true
	end
	return false
end

-- 4. ESCÁNER DE ENTIDADES (Excluye jugadores reales)
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

-- 5. BUCLE PRINCIPAL DE NAVEGACIÓN MECÁNICA (Consumo óptimo de recursos)
task.spawn(function()
	while task.wait(0.08) do -- Se ejecuta unas 12 veces por segundo (Fluidez perfecta)
		if not humanoid or humanoid.Health <= 0 then 
			clearKeyboard()
			break 
		end
		
		local visibleEntity = getVisibleEntity()
		if visibleEntity then currentTarget = visibleEntity end
		
		-- COMPORTAMIENTO 1: COMBATE CONTRA ENTIDAD VISTA
		if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
			local distance = (rootPart.Position - currentTarget.Position).Magnitude
			
			if distance > 130 then
				currentTarget = nil
				clearKeyboard()
			elseif distance <= 7 then
				-- Rango letal: Nos detenemos y atacamos activando el arma en mano
				clearKeyboard()
				local tool = character:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			else
				-- Persecución mecánica guiando el cuerpo hacia el objetivo
				humanoid.WalkSpeed = 24
				local directionToEnemy = (currentTarget.Position - rootPart.Position).Unit
				
				-- Rotamos el torso suavemente hacia la dirección de la entidad para alinear la simulación del teclado
				rootPart.CFrame = CFrame.new(rootPart.Position, Vector3.new(currentTarget.Position.X, rootPart.Position.Y, currentTarget.Position.Z))
				
				-- Presionamos avanzar físicamente
				pressKey("W", true)
				pressKey("A", false)
				pressKey("D", false)
				pressKey("S", false)
			end
			
		-- COMPORTAMIENTO 2: DEAMBULAR INTELIGENTE (Patrulla Autónoma)
		else
			currentTarget = nil
			humanoid.WalkSpeed = 15
			
			-- Analizamos los sensores para saber qué tecla de dirección física presionar
			local bestAction = getNavigationAdjustment()
			
			if bestAction == "W" then
				pressKey("W", true)
				pressKey("A", false)
				pressKey("D", false)
				pressKey("S", false)
			elseif bestAction == "A" then
				pressKey("W", false)
				pressKey("A", true)
				pressKey("D", false)
				pressKey("S", false)
				task.wait(0.15) -- Tiempo mínimo de giro físico para evadir la esquina
			elseif bestAction == "D" then
				pressKey("W", false)
				pressKey("A", false)
				pressKey("D", true)
				pressKey("S", false)
				task.wait(0.15)
			elseif bestAction == "S" then
				pressKey("W", false)
				pressKey("A", false)
				pressKey("D", false)
				pressKey("S", true)
				task.wait(0.2)
			end
		end
	end
end)
