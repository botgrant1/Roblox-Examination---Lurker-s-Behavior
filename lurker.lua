--[[
    LURKER AUTOPILOT FOR EXECUTORS (VERSION 2 - UNIVERSAL TRACKER)
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

print("[Lurker Exploit] ¡Versión 2 cargada con Rastreador Universal!")

-- Bucle principal
local loopConnection
loopConnection = RunService.Heartbeat:Connect(function()
	if not humanoid or humanoid.Health <= 0 then 
		loopConnection:Disconnect()
		return 
	end
	
	local target = nil
	local maxDistance = 250 -- Aumentamos el rango para que los detecte desde lejos
	
	-- BUSCADOR AVANZADO: Revisa todo el mapa en profundidad (carpetas y subcarpetas)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj.Health > 0 then
			local enemyCharacter = obj.Parent
			
			-- Asegurarse de que no te persigas a ti mismo ni a otros miembros de tu equipo
			if enemyCharacter and enemyCharacter:IsA("Model") and enemyCharacter ~= character then
				local enemyRoot = enemyCharacter:FindFirstChild("HumanoidRootPart")
				
				if enemyRoot then
					local distance = (rootPart.Position - enemyRoot.Position).Magnitude
					if distance < maxDistance then
						maxDistance = distance
						target = enemyRoot
					end
				end
			end
		end
	end
	
	-- ACCIONES DE LA IA
	if target then
		local distanceToEnemy = (rootPart.Position - target.Position).Magnitude
		
		if distanceToEnemy <= 7 then
			-- Ataque automático si tienes una herramienta en mano
			local tool = character:FindFirstChildOfClass("Tool")
			if tool then
				tool:Activate()
			end
		else
			-- Camina automáticamente hacia el objetivo con velocidad de Lurker
			humanoid.WalkSpeed = 24
			humanoid:MoveTo(target.Position)
		end
	else
		-- Si realmente no encuentra absolutamente a nadie vivo en el mapa
		humanoid.WalkSpeed = 16
	end
end)
