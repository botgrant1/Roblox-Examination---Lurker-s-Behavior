--[[
    LURKER EXPERIMENT - DEFINITIVE VERSION (LONG PATHS & ANTI-STUCK SYSTEM)
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Forzamos el apagado completo de los scripts de control para erradicar los tirones
pcall(function()
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	if playerModule then playerModule:GetControls():Disable() end
end)

print("[IA Lurker] Inicializado con éxito. Buscando rutas largas de Sector.")

-- Parámetros de comportamiento estrictos del Lurker
local maxVisionDistance = 110
local currentTarget = nil

-- Configuración de patrulla de trayecto largo
local moveDirection = rootPart.CFrame.LookVector
local timeMovingOnCurrentPath = 0
local maxPathTime = math.random(5, 8) -- Camina entre 5 y 8 segundos en línea recta antes de pausar
local isResting = false

-- Parámetros de Raycast para evadir cajas y muros de Examination
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- 1. SISTEMA DE EVASIÓN DIAGONAL (Evita bucles de atrás hacia adelante)
local function adjustDirectionForObstacles()
	rayParams.FilterDescendantsInstances = {character}
	
	-- Escaneo desde las piernas y el torso
	local origin = rootPart.Position + Vector3.new(0, -0.8, 0)
	local forward = moveDirection.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	
	-- 3 Rayos frontales de advertencia anticipada
	local hitCenter = Workspace:Raycast(origin, forward * 8, rayParams)
	local hitLeft = Workspace:Raycast(origin, (forward - right * 0.4).Unit * 7, rayParams)
	local hitRight = Workspace:Raycast(origin, (forward + right * 0.4).Unit * 7, rayParams)
	
	if hitCenter or hitLeft or hitRight then
		-- Salto automático instantáneo si la caja u objeto es bajo
		humanoid.Jump = true
		
		-- Lanzamos dos rayos laterales profundos para buscar el escape del pasillo
		local escapeLeft = Workspace:Raycast(origin, -right * 14, rayParams)
		local escapeRight = Workspace:Raycast(origin, right * 14, rayParams)
		
		-- En lugar de dar la vuelta completa (atrás), se desvía de forma fluida hacia los lados
		if not escapeLeft then
			moveDirection = (-right + forward * 0.5).Unit
		elseif not escapeRight then
			moveDirection = (right + forward * 0.5).Unit
		else
			-- Si está totalmente acorralado por cajas y muros, calcula un ángulo aleatorio oblicuo
			local randomAngle = math.rad(math.random(110, 250))
			moveDirection = CFrame.Angles(0, randomAngle, 0) * moveDirection
		end
		
		-- Reiniciamos el temporizador del trayecto para que no se canse en medio del desvío
		timeMovingOnCurrentPath = 0
	end
end

-- 2. FILTRO DE LÍNEA DE VISIÓN PARA ENTIDADES
local function hasLineOfSight(enemyRoot)
	rayParams.FilterDescendantsInstances = {character}
	
	local toEnemy = (enemyRoot.Position - rootPart.Position).Unit
	local dotProduct = rootPart.CFrame.LookVector:Dot(toEnemy)
	
	if dotProduct < 0.65 then return false end -- Campo de visión frontal de 90 grados
	
	local origin = rootPart.Position + Vector3.new(0, 2, 0)
	local direction = (enemyRoot.Position - origin)
	local rayResult = Workspace:Raycast(origin, direction, rayParams)
	
	if rayResult and rayResult.Instance:IsDescendantOf(enemyRoot.Parent) then
		return true
	end
	return false
end

-- 3. ESCÁNER DE ENTIDADES (Ignora por completo a los jugadores)
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

-- 4. INYECCIÓN DEL RENDER DE MOVIMIENTO (Fluidez a 60 FPS garantizada)
local movementVector = Vector3.new()

RunService.RenderStepped:Connect(function()
	if not humanoid or humanoid.Health <= 0 then return end
	
	-- Control de orientación continuo para que gire el cuerpo con suavidad hacia donde camina
	if movementVector.Magnitude > 0 and not currentTarget then
		local targetLook = rootPart.Position + movementVector
		rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(rootPart.Position, Vector3.new(targetLook.X, rootPart.Position.Y, targetLook.Z)), 0.2)
	end
	
	humanoid:Move(movementVector, false)
end)

-- 5. LOGICA LURKER: TRAYECTOS LARGOS, PAUSAS Y CAZA
task.spawn(function()
	while task.wait(0.05) do
		if not humanoid or humanoid.Health <= 0 then break end
		
		local visibleEntity = getVisibleEntity()
		if visibleEntity then currentTarget = visibleEntity end
		
		-- ESTADO 1: PERSIGUIENDO ENTIDAD (Sigue al objetivo rompiendo sectores)
		if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
			isResting = false
			local distance = (rootPart.Position - currentTarget.Position).Magnitude
			
			if distance > 140 then
				currentTarget = nil
				movementVector = Vector3.new()
			elseif distance <= 6.5 then
				-- Rango letal: Frenar y atacar
				movementVector = Vector3.new()
				local tool = character:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			else
				-- Carrera de persecución directa
				humanoid.WalkSpeed = 24
				rootPart.CFrame = CFrame.new(rootPart.Position, Vector3.new(currentTarget.Position.X, rootPart.Position.Y, currentTarget.Position.Z))
				movementVector = (currentTarget.Position - rootPart.Position).Unit
			end
			
		-- ESTADO 2: PATRULLA ESTILO LURKER (Trayectos largos y pausas de acecho)
		else
			currentTarget = nil
			
			if isResting then
				movementVector = Vector3.new()
			else
				humanoid.WalkSpeed = 15
				
				-- Evaluamos constantemente si hay cajas o muros adelante para desviarnos sutilmente
				adjustDirectionForObstacles()
				movementVector = moveDirection
				
				-- Aumentamos el contador del trayecto largo actual
				timeMovingOnCurrentPath = timeMovingOnCurrentPath + 0.05
				
				-- Al completar el trayecto largo, se detiene a acechar como el Lurker original
				if timeMovingOnCurrentPath >= maxPathTime then
					isResting = true
					movementVector = Vector3.new()
					
					-- Pausa de 1.5 a 2 segundos en el sitio
					task.wait(math.random(15, 20) / 10)
					
					-- Elige un rumbo totalmente nuevo y reinicia configuraciones
					local randomAngle = math.rad(math.random(0, 360))
					moveDirection = Vector3.new(math.cos(randomAngle), 0, math.sin(randomAngle)).Unit
					maxPathTime = math.random(5, 8)
					timeMovingOnCurrentPath = 0
					isResting = false
				end
			end
		end
	end
end)
