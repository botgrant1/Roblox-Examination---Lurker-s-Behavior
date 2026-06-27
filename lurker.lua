--[[
    LURKER AUTOPILOT - VERSION 6 (RAYCAST AVOIDANCE - ANTI-LAG)
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

print("[Lurker Exploit] Versión 6: Movimiento continuo por Raycast (Sin tirones).")

-- Configuraciones de visión y físicas
local maxVisionDistance = 120
local currentTarget = nil
local patrolDirection = rootPart.CFrame.LookVector

-- Parámetros globales para ignorar tu propio cuerpo al lanzar rayos
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- 1. DETECTOR DE PAREDES (Previene choques de forma realista)
local function checkObstaclesAndSteer()
	rayParams.FilterDescendantsInstances = {character}
	
	-- Lanzamos un rayo principal hacia adelante para ver si hay una pared cerca
	local forwardRay = Workspace:Raycast(rootPart.Position, patrolDirection * 8, rayParams)
	
	if forwardRay and not forwardRay.Instance:IsDescendantOf(character) then
		-- Si detectamos una pared, elegimos una nueva dirección girando a la izquierda o derecha
		local leftVector = -rootPart.CFrame.RightVector
		local rightVector = rootPart.CFrame.RightVector
		
		-- Evaluamos cuál lado está más despejado lanzando dos rayos laterales
		local rayLeft = Workspace:Raycast(rootPart.Position, leftVector * 12, rayParams)
		local rayRight = Workspace:Raycast(rootPart.Position, rightVector * 12, rayParams)
		
		if not rayLeft then
			patrolDirection = (patrolDirection + leftVector * 1.5).Unit
		elseif not rayRight then
			patrolDirection = (patrolDirection + rightVector * 1.5).Unit
		else
			-- Si ambos lados están bloqueados, gira completamente hacia atrás
			patrolDirection = -patrolDirection
		end
		
		-- Si nos pegamos mucho a un objeto bajo, forzamos un salto automático
		if (forwardRay.Position - rootPart.Position).Magnitude < 4 then
			humanoid.Jump = true
		end
	end
end

-- 2. FILTRO DE LÍNEA DE VISIÓN PARA ENTIDADES
local function hasLineOfSight(enemyRoot)
	rayParams.FilterDescendantsInstances = {character}
	
	local toEnemy = (enemyRoot.Position - rootPart.Position).Unit
	local dotProduct = rootPart.CFrame.LookVector:Dot(toEnemy)
	
	if dotProduct < 0.65 then return false end -- Cono frontal de 90 grados
	
	local origin = rootPart.Position + Vector3.new(0, 2, 0)
	local direction = (enemyRoot.Position - origin)
	local rayResult = Workspace:Raycast(origin, direction, rayParams)
	
	if rayResult and rayResult.Instance:IsDescendantOf(enemyRoot.Parent) then
		return true
	end
	return false
end

-- 3. BUSCADOR DE ENMIGOS (Solo NPCs/Entidades)
local function getVisibleEntity()
	local target = nil
	local closestDistance = maxVisionDistance
	
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj.Health > 0 then
			local enemyCharacter = obj.Parent
			if enemyCharacter and enemyCharacter:IsA("Model") and enemyCharacter ~= character then
				if not Players:GetPlayerFromCharacter(enemyCharacter) then -- Filtra solo bots
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

-- 4. BUCLE PRINCIPAL DE MOVIMIENTO CONTINUO (Cero tirones)
task.spawn(function()
	while task.wait(0.05) do -- Ciclo rápido y ultraligero para simular físicas naturales
		if not humanoid or humanoid.Health <= 0 then break end
		
		local visibleEntity = getVisibleEntity()
		if visibleEntity then
			currentTarget = visibleEntity
		end
		
		-- COMPORTAMIENTO DE COMBATE (Si ve una entidad)
		if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
			local distance = (rootPart.Position - currentTarget.Position).Magnitude
			
			if distance > 130 then -- El enemigo escapó de la zona
				currentTarget = nil
			elseif distance <= 7 then
				-- Rango de ataque cuerpo a cuerpo automático
				local tool = character:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
				humanoid:Move(Vector3.new(0,0,0)) -- Se detiene a atacar
			else
				-- Avanzar de forma fluida hacia el objetivo visible
				humanoid.WalkSpeed = 24
				local directionToEnemy = (currentTarget.Position - rootPart.Position).Unit
				humanoid:Move(directionToEnemy)
			end
			
		-- COMPORTAMIENTO DE PATRULLA INTELIGENTE (Deambular solo)
		else
			currentTarget = nil
			humanoid.WalkSpeed = 15
			
			-- Analiza el entorno en busca de colisiones antes de dar el siguiente paso
			checkObstaclesAndSteer()
			
			-- Mueve al personaje continuamente hacia la dirección libre calculada
			humanoid:Move(patrolDirection)
		end
	end
end)
