--[[
    LURKER EXPERIMENT - CORE ENGINE REPLICA (CFRAME MOTION - NO LAG)
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

print("[Lurker Master] Versión de Deslizamiento Puro Inyectada. Cero fricción de servidor.")

-- Configuraciones de comportamiento real del Lurker
local maxVisionDistance = 110
local currentTarget = nil

-- Configuración de patrulla de área abierta
local currentTargetPos = rootPart.Position
local movementSpeed = 15 -- Velocidad de patrulla fluida
local isResting = false
local restTimer = 0

-- Parámetros de Raycast para escaneo visual
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- 1. BUSCADOR DE COORDENADAS ABIERTAS (Evita atascos en cajas y pasillos)
local function getNewPatrolPoint()
	rayParams.FilterDescendantsInstances = {character}
	local bestPoint = rootPart.Position
	local maxFreeSpace = 0
	
	-- El bot escanea 12 direcciones a su alrededor en un ángulo de 360 grados
	-- Busca cuál pasillo o sala de Examination tiene el camino más largo y despejado
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		-- Generamos una dirección de patrulla larga estilo Lurker (40 a 70 unidades)
		local distance = math.random(40, 70)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		
		-- Lanzamos un rayo grueso para simular el NavMesh del juego
		local rayResult = Workspace:Raycast(rootPart.Position + Vector3.new(0, 1, 0), direction * distance, rayParams)
		
		-- Si el rayo no choca con nada, significa que es un pasillo completamente abierto y habilitado
		local freeDistance = rayResult and (rayResult.Position - rootPart.Position).Magnitude or distance
		
		-- Prioriza caminos largos (pasillos) en lugar de esquinas cortas (evita el bucle de atrás/adelante)
		if freeDistance > maxFreeSpace and freeDistance > 15 then
			maxFreeSpace = freeDistance
			-- Restamos un pequeño margen para no quedar pegados exactamente a la pared final del pasillo
			bestPoint = rootPart.Position + direction * (freeDistance - 6)
		end
	end
	return bestPoint
end

-- 2. FILTRO DE LÍNEA DE VISIÓN HUMANA
local function hasLineOfSight(enemyRoot)
	rayParams.FilterDescendantsInstances = {character}
	local toEnemy = (enemyRoot.Position - rootPart.Position).Unit
	local dotProduct = rootPart.CFrame.LookVector:Dot(toEnemy)
	
	if dotProduct < 0.65 then return false end -- Campo visual frontal
	
	local origin = rootPart.Position + Vector3.new(0, 2, 0)
	local direction = (enemyRoot.Position - origin)
	local rayResult = Workspace:Raycast(origin, direction, rayParams)
	
	if rayResult and rayResult.Instance:IsDescendantOf(enemyRoot.Parent) then
		return true
	end
	return false
end

-- 3. ESCÁNER DE ENTIDADES (Excluye jugadores reales)
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

-- 4. BUCLE DE DESLIZAMIENTO C-FRAME (Sincronizado a los hercios de tu pantalla para 0 TIRONES)
RunService.Heartbeat:Connect(function(deltaTime)
	if not humanoid or humanoid.Health <= 0 then return end
	
	local visibleEntity = getVisibleEntity()
	if visibleEntity then currentTarget = visibleEntity end
	
	-- ESTADO A: MODO CAZA (Se activa si hay una entidad en pantalla)
	if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
		isResting = false
		local enemyPos = currentTarget.Position
		local distance = (rootPart.Position - enemyPos).Magnitude
		
		if distance > 140 then
			currentTarget = nil
		elseif distance <= 6.5 then
			-- Rango de ataque: Detenerse y golpear
			local tool = character:FindFirstChildOfClass("Tool")
			if tool then tool:Activate() end
		else
			-- Deslizamiento veloz de caza (Velocidad Lurker: 24)
			local moveDir = (Vector3.new(enemyPos.X, rootPart.Position.Y, enemyPos.Z) - rootPart.Position).Unit
			rootPart.CFrame = CFrame.lookAt(rootPart.Position + moveDir * (24 * deltaTime), Vector3.new(enemyPos.X, rootPart.Position.Y, enemyPos.Z))
		end
		
	-- ESTADO B: MODO PATRULLA DE ACECHO (Deambular de forma fluida por pasillos)
	else
		currentTarget = nil
		
		if isResting then
			-- El bot se queda quieto imitando la pausa del Lurker original
			restTimer = restTimer - deltaTime
			if restTimer <= 0 then
				isResting = false
				currentTargetPos = getNewPatrolPoint() -- Elige un nuevo pasillo largo desocupado
			end
		else
			local targetFlat = Vector3.new(currentTargetPos.X, rootPart.Position.Y, currentTargetPos.Z)
			local distanceToPoint = (rootPart.Position - targetFlat).Magnitude
			
			if distanceToDistanceToPoint > 3 then
				-- Nos deslizamos suavemente fotograma a fotograma hacia el punto despejado
				local moveDir = (targetFlat - rootPart.Position).Unit
				rootPart.CFrame = CFrame.lookAt(rootPart.Position + moveDir * (movementSpeed * deltaTime), targetFlat)
			else
				-- ¡Llegamos al final del pasillo libre! Activamos la pausa de acecho del Lurker
				isResting = true
				restTimer = math.random(15, 25) / 10 -- Pausa de 1.5 a 2.5 segundos
			end
		end
	end
end)
