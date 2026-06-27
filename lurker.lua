--[[
    LURKER AUTOPILOT FOR EXECUTORS
    Este script hace que tu personaje busque enemigos y los ataque solo.
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

print("[Lurker Exploit] Script cargado correctamente.")

-- Bucle principal usando el motor de renderizado del cliente
local loopConnection
loopConnection = RunService.Heartbeat:Connect(function()
	-- Validar si el jugador sigue vivo, si no, detiene el bucle
	if not humanoid or humanoid.Health <= 0 then 
		loopConnection:Disconnect()
		return 
	end
	
	-- 1. BUSCAR OBJETIVO CERCANO (Cualquier NPC o Jugador hostil)
	local target = nil
	local maxDistance = 150 -- Rango de visión de la IA
	
	for _, obj in ipairs(Workspace:GetChildren()) do
		-- Busca modelos en el mapa que tengan vida y no seas tú mismo
		if obj:IsA("Model") and obj ~= character then
			local enemyHumanoid = obj:FindFirstChild("Humanoid")
			local enemyRoot = obj:FindFirstChild("HumanoidRootPart")
			
			if enemyHumanoid and enemyHumanoid.Health > 0 and enemyRoot then
				local distance = (rootPart.Position - enemyRoot.Position).Magnitude
				if distance < maxDistance then
					maxDistance = distance
					target = enemyRoot
				end
			end
		end
	end
	
	-- 2. SIMULAR COMPORTAMIENTO LURKER
	if target then
		local distanceToEnemy = (rootPart.Position - target.Position).Magnitude
		
		if distanceToEnemy <= 6 then
			-- COMPORTAMIENTO 1: Rango de Ataque
			-- Nota: Como el daño está protegido por el servidor, simulamos el clic/activación de tu arma
			local tool = character:FindFirstChildOfClass("Tool")
			if tool then
				tool:Activate() -- Hace que tu personaje use el arma/ataque automáticamente
			end
		else
			-- COMPORTAMIENTO 2: Persecución Agresiva
			-- Los Executors pueden alterar la velocidad localmente de forma segura
			humanoid.WalkSpeed = 24 -- Velocidad rápida de Lurker
			humanoid:MoveTo(target.Position)
		end
	else
		-- COMPORTAMIENTO 3: Patrulla/Espera pasiva
		humanoid.WalkSpeed = 16
	end
end)
