--[[
    LURKER SIMULATOR - DEFINITIVE EDITION WITH DESIGNATED UI MENU
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Variable de control global (Controlada por el menú UI)
getgenv().LurkerAI_Enabled = false

-- =========================================================================
-- CREACIÓN DE LA INTERFAZ GRÁFICA (MENÚ DE CONTROL)
-- =========================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LurkerControlGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Contenedor Principal (Panel)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 130)
mainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true -- Te permite arrastrar el menú por tu pantalla
mainFrame.Parent = screenGui

-- Bordes redondeados del menú
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- Título del menú
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "LURKER AUTOPILOT"
titleLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

-- Botón de Encendido / Apagado
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

-- Función para liberar las teclas físicas al apagar
local function releaseAllKeys()
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, game)
end

-- Mecánica del clic en el botón
toggleButton.MouseButton1Click:Connect(function()
	getgenv().LurkerAI_Enabled = not getgenv().LurkerAI_Enabled
	
	if getgenv().LurkerAI_Enabled then
		toggleButton.Text = "ESTADO: ACTIVO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		print("[AI] Piloto automático del Lurker encendido.")
	else
		toggleButton.Text = "ESTADO: DESACTIVADO"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		releaseAllKeys()
		print("[AI] Piloto automático apagado. Controles devueltos.")
	end
end)

-- =========================================================================
-- LÓGICA DE NAVEGACIÓN Y ESCÁNER DE ENTORNO (Hardware Inputs)
-- =========================================================================
local maxVisionDistance = 110
local currentTarget = nil
local currentDirection = rootPart.CFrame.LookVector
local isResting = false
local timeOnPath = 0
local maxPathTime = math.random(4, 7)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- 1. DETECTOR DE PASILLOS ABIERTOS POR ESCÁNER DE RAYOS RADIAL
local function scanBestPasillo()
	rayParams.FilterDescendantsInstances = {character}
	local origin = rootPart.Position + Vector3.new(0, -0.5, 0) -- Escaneo a baja altura (muros y cajas)
	
	local bestDir = currentDirection
	local maxFreeSpace = 0
	
	-- Escanea 12 puntos a la redonda para encontrar la zona más abierta y larga del Sector
	for i = 1, 12 do
		local angle = math.rad(i * (360 / 12))
		local testDir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		
		local rayResult = Workspace:Raycast(origin, testDir * 50, rayParams)
		local freeDistance = rayResult and (rayResult.Position - rootPart.Position).Magnitude or 50
		
		-- Filtramos cajas pequeñas forzando saltos automáticos si choca muy cerca
		if rayResult and freeDistance < 4 then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
			task.wait(0.02)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
		end
		
		-- Prioriza pasillos largos y espacios habilitados del mapa en vez de giros cerrados
		if freeDistance > maxFreeSpace and freeDistance > 12 then
			maxFreeSpace = freeDistance
			bestDir = testDir
		end
	end
	return bestDir
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

-- 4. BUCLE LOGICO ASÍNCRONO DE LA IA
task.spawn(function()
	while task.wait(0.08) do -- Ciclo ligero adaptado a la red de Roblox
		-- Si la IA está apagada en el menú, el script espera sin consumir recursos
		if not getgenv().LurkerAI_Enabled then continue end
		if not humanoid or humanoid.Health <= 0 then break end
		
		local visibleEntity = getVisibleEntity()
		if visibleEntity then currentTarget = visibleEntity end
		
		-- ESTADO DE COMBATE (Entidad detectada en el FOV)
		if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
			isResting = false
			local enemyPos = currentTarget.Position
			local distance = (rootPart.Position - enemyPos).Magnitude
			
			if distance > 130 then
				currentTarget = nil
				releaseAllKeys()
			elseif distance <= 7 then
				-- Rango letal: Frenar simulación de teclado y atacar con la Tool
				releaseAllKeys()
				local tool = character:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			else
				-- Persecución mecánica limpia alineando la cámara física al objetivo
				humanoid.WalkSpeed = 24
				
				-- Rotación fluida usando interpolación matemática para simular un mouse humano
				local targetLook = Vector3.new(enemyPos.X, rootPart.Position.Y, enemyPos.Z)
				rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(rootPart.Position, targetLook), 0.25)
				
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
			end
			
		-- ESTADO DE PATRULLA REALISTA (Deambular de forma fluida por pasillos)
		else
			currentTarget = nil
			humanoid.WalkSpeed = 15
			
			if isResting then
				releaseAllKeys()
			else
				-- Escanea el entorno para ajustar su vector de caminata evitando colisiones de frente
				currentDirection = scanBestPasillo()
				
				-- Orienta el cuerpo de forma natural hacia el pasillo despejado elegido
				local targetLook = rootPart.Position + currentDirection
				rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(rootPart.Position, Vector3.new(targetLook.X, rootPart.Position.Y, targetLook.Z)), 0.2)
				
				-- Presionamos físicamente el avance nativo del juego
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
				
				-- Incrementamos el tiempo de la caminata larga actual del Lurker
				timeOnPath = timeOnPath + 0.08
				if timeOnPath >= maxPathTime then
					isResting = true
					releaseAllKeys()
					
					-- Pausa estática característica del Lurker para acechar la zona
					task.wait(math.random(15, 25) / 10)
					
					-- Reiniciamos parámetros para el siguiente pasillo largo habilitado
					maxPathTime = math.random(4, 7)
					timeOnPath = 0
					isResting = false
				end
			end
		end
	end
end)

-- Limpieza si el jugador muere
humanoid.Died:Connect(function()
	releaseAllKeys()
	screenGui:Destroy()
end)
