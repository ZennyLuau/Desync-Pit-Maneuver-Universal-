local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "ZenithViking | Tactical System",
   LoadingTitle = "Loading Combat Systems...",
   LoadingSubtitle = "by Zen",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local MainTab = Window:CreateTab("Ghost PIT", 4483362458)
local ModTab = Window:CreateTab("Interceptor Mods", 4483362458)
local CombatTab = Window:CreateTab("Combat & ESP", 4483362458) -- NEW TAB

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- VARIABLES
-- ==========================================
-- Ghost PIT
local desyncEnabled = false
local heavyAnchorEnabled = false
local brakeForceMultiplier = 40
local isPitting = false
local pitCooldown = 1.5 

-- Interceptor Mods
local noclipEnabled = false
local pursuitMode = false
local pursuitSpeed = 150
local pursuitTurn = 50
local pushBarEnabled = false
local activePushBar = nil

-- Combat & ESP
local espEnabled = false
local espObjects = {} -- Stores highlights and text
local aimbotEnabled = false
local aimSmoothness = 0.5
local teamCheckEnabled = true
local wallCheckEnabled = true

-
MainTab:CreateToggle({Name = "Enable Ghost PIT (Turn Desync)", CurrentValue = false, Callback = function(Value) desyncEnabled = Value end})
MainTab:CreateToggle({Name = "Titanium Rear Guard", CurrentValue = false, Callback = function(Value) heavyAnchorEnabled = Value end})
MainTab:CreateSlider({Name = "Lateral Brake Force", Range = {10, 100}, Increment = 5, CurrentValue = 40, Callback = function(Value) brakeForceMultiplier = Value end})

-- ==========================================
-- GUI: INTERCEPTOR MODS
-- ==========================================
ModTab:CreateToggle({Name = "Vehicle Noclip", CurrentValue = false, Callback = function(Value) noclipEnabled = Value end})
ModTab:CreateToggle({Name = "Pursuit Override", CurrentValue = false, Callback = function(Value) pursuitMode = Value end})
ModTab:CreateSlider({Name = "Pursuit Max Speed", Range = {50, 500}, Increment = 10, CurrentValue = 150, Callback = function(Value) pursuitSpeed = Value end})
ModTab:CreateSlider({Name = "Pursuit Turn Sharpness", Range = {10, 100}, Increment = 5, CurrentValue = 50, Callback = function(Value) pursuitTurn = Value end})
ModTab:CreateToggle({
   Name = "Equip Heavy Ram Bar", 
   CurrentValue = false, 
   Callback = function(Value) 
      pushBarEnabled = Value 
      if not pushBarEnabled and activePushBar then
          activePushBar:Destroy()
          activePushBar = nil
      end
   end
})

-- ==========================================
-- GUI: COMBAT & ESP
-- ==========================================
CombatTab:CreateToggle({
    Name = "Enable Player ESP", 
    CurrentValue = false, 
    Callback = function(Value) 
        espEnabled = Value 
        if not espEnabled then
            for _, obj in pairs(espObjects) do obj:Destroy() end
            table.clear(espObjects)
        end
    end
})

CombatTab:CreateToggle({Name = "Enable Aimlock", CurrentValue = false, Callback = function(Value) aimbotEnabled = Value end})
CombatTab:CreateToggle({Name = "Aimbot Team Check", CurrentValue = true, Callback = function(Value) teamCheckEnabled = Value end})
CombatTab:CreateToggle({Name = "Aimbot Wall Check", CurrentValue = true, Callback = function(Value) wallCheckEnabled = Value end})
CombatTab:CreateSlider({Name = "Aim Smoothness", Range = {1, 100}, Increment = 1, CurrentValue = 50, Callback = function(Value) aimSmoothness = Value / 100 end})

-- ==========================================
-- CORE FUNCTIONS
-- ==========================================
local function attachPushBar(myCar, vehicleRoot)
    if activePushBar or not vehicleRoot then return end
    local carCFrame, carSize = myCar:GetBoundingBox()
    activePushBar = Instance.new("Model")
    activePushBar.Name = "ZenithRamBar"

    local mainBar = Instance.new("Part")
    mainBar.Size = Vector3.new(carSize.X + 0.5, 1.5, 1.5)
    mainBar.Color = Color3.new(0.1, 0.1, 0.1)
    mainBar.Material = Enum.Material.DiamondPlate
    mainBar.CanCollide = true
    mainBar.CustomPhysicalProperties = PhysicalProperties.new(100, 0.5, 0) 
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = vehicleRoot
    weld.Part1 = mainBar
    mainBar.CFrame = carCFrame * CFrame.new(0, -carSize.Y/4, -(carSize.Z/2 + 0.5))
    
    mainBar.Parent = activePushBar
    activePushBar.Parent = myCar
    weld.Parent = mainBar
    activePushBar.PrimaryPart = mainBar
end

local function getCarData()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or not hum.SeatPart then return nil end
    
    local seat = hum.SeatPart
    local myCar = seat:FindFirstAncestorOfClass("Model")
    while myCar and myCar.Parent and myCar.Parent:IsA("Model") do myCar = myCar.Parent end
    
    if myCar and myCar ~= workspace then
        local root = myCar.PrimaryPart or seat
        return myCar, root, seat
    end
    return nil
end

-- Aimbot Target Acquisition
local function getClosestValidTarget()
    local closestTarget = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
            
            -- Dead Check
            if player.Character.Humanoid.Health <= 0 then continue end
            
            -- Team Check
            if teamCheckEnabled and player.Team == LocalPlayer.Team then continue end

            local rootPart = player.Character.HumanoidRootPart
            local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

            if onScreen then
                -- Wall Check
                local isVisible = true
                if wallCheckEnabled then
                    local rayOrigin = Camera.CFrame.Position
                    local rayDirection = (rootPart.Position - rayOrigin).Unit * (rootPart.Position - rayOrigin).Magnitude
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, getCarData()}
                    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                    
                    local hit = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                    if hit and hit.Instance and not hit.Instance:IsDescendantOf(player.Character) then
                        isVisible = false -- A wall is in the way
                    end
                end

                if isVisible then
                    local distanceToCenter = (Vector2.new(vector.X, vector.Y) - screenCenter).Magnitude
                    if distanceToCenter < shortestDistance then
                        closestTarget = rootPart
                        shortestDistance = distanceToCenter
                    end
                end
            end
        end
    end
    return closestTarget
end

-- ==========================================
-- SYSTEM LOOPS
-- ==========================================

RunService.Stepped:Connect(function()
    local carData = {getCarData()}
    if not carData[1] then return end
    local myCar = carData[1]

    if noclipEnabled then
        for _, part in pairs(myCar:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "ZenithRamBar" then
                part.CanCollide = false
            end
        end
    end
end)

-- Combat, ESP & Aimlock Loop (RenderStepped for buttery smooth visuals)
RunService.RenderStepped:Connect(function()
    -- AIMLOCK
    if aimbotEnabled then
        local targetPart = getClosestValidTarget()
        if targetPart then
            local targetPosition = targetPart.Position
            -- Smoothly lock camera onto target
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, targetPosition), aimSmoothness)
        end
    end

    -- ESP
    if espEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    local teamColor = player.TeamColor and player.TeamColor.Color or Color3.new(1, 1, 1)
                    local teamName = player.Team and player.Team.Name or "No Team"
                    local distance = math.floor((Camera.CFrame.Position - char.HumanoidRootPart.Position).Magnitude)
                    
                    -- Highlight
                    local highlight = espObjects[player.Name.."_HL"]
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Parent = game:GetService("CoreGui")
                        highlight.Adornee = char
                        espObjects[player.Name.."_HL"] = highlight
                    end
                    highlight.FillColor = teamColor
                    highlight.OutlineColor = teamColor
                    highlight.FillTransparency = 0.5
                    
                    -- Text Billboard
                    local billboard = espObjects[player.Name.."_BB"]
                    if not billboard then
                        billboard = Instance.new("BillboardGui")
                        billboard.AlwaysOnTop = true
                        billboard.Size = UDim2.new(0, 200, 0, 50)
                        billboard.ExtentsOffset = Vector3.new(0, 3, 0)
                        
                        local textLabel = Instance.new("TextLabel", billboard)
                        textLabel.BackgroundTransparency = 1
                        textLabel.Size = UDim2.new(1, 0, 1, 0)
                        textLabel.Font = Enum.Font.GothamBold
                        textLabel.TextSize = 14
                        textLabel.TextStrokeTransparency = 0 -- Black outline for readability
                        textLabel.TextColor3 = Color3.new(1, 1, 1)
                        
                        billboard.Parent = game:GetService("CoreGui")
                        billboard.Adornee = char.HumanoidRootPart
                        espObjects[player.Name.."_BB"] = billboard
                    end
                    
                    -- Update Text
                    billboard.TextLabel.Text = string.format("[%s]\n%s (@%s)\n%d Studs", teamName, player.DisplayName, player.Name, distance)
                    billboard.TextLabel.TextColor3 = teamColor
                else
                    -- Cleanup if player dies or leaves
                    if espObjects[player.Name.."_HL"] then espObjects[player.Name.."_HL"]:Destroy(); espObjects[player.Name.."_HL"] = nil end
                    if espObjects[player.Name.."_BB"] then espObjects[player.Name.."_BB"]:Destroy(); espObjects[player.Name.."_BB"] = nil end
                end
            end
        end
    end
end)

-- Physics & PIT Loop
RunService.Heartbeat:Connect(function(deltaTime)
    local myCar, vehicleRoot, seat = getCarData()
    if not myCar then return end

    local steerInput = seat:IsA("VehicleSeat") and seat.SteerFloat or 0 
    local throttleInput = seat:IsA("VehicleSeat") and seat.ThrottleFloat or 0
    local currentVelocity = vehicleRoot.AssemblyLinearVelocity
    local speed = currentVelocity.Magnitude

    if pushBarEnabled and not activePushBar then attachPushBar(myCar, vehicleRoot) end

    if pursuitMode then
        if math.abs(throttleInput) > 0 or math.abs(steerInput) > 0 then
            local flatRight = (vehicleRoot.CFrame.RightVector * Vector3.new(1, 0, 1)).Unit
            local flatLook = (vehicleRoot.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
            
            local targetVelocity = flatLook * (throttleInput * pursuitSpeed)
            local newVelocity = currentVelocity:Lerp(targetVelocity + Vector3.new(0, currentVelocity.Y, 0), 0.1)
            
            vehicleRoot.AssemblyLinearVelocity = newVelocity
            if math.abs(steerInput) > 0 then vehicleRoot.AssemblyAngularVelocity = Vector3.new(0, -steerInput * (pursuitTurn/10), 0) end
        end
    end

    if desyncEnabled and speed > 30 and math.abs(steerInput) > 0.8 then
        if not isPitting then
            isPitting = true 
            
            local flatRight = (vehicleRoot.CFrame.RightVector * Vector3.new(1, 0, 1)).Unit
            local flatLook = (vehicleRoot.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
            local lateralDirection = flatRight * steerInput
            local brakingForce = -flatLook * (brakeForceMultiplier * 0.5)
            
            vehicleRoot.AssemblyLinearVelocity = currentVelocity + (lateralDirection * brakeForceMultiplier) + brakingForce

            if heavyAnchorEnabled then
                local originalProperties = vehicleRoot.CustomPhysicalProperties or PhysicalProperties.new(vehicleRoot.Material)
                vehicleRoot.CustomPhysicalProperties = PhysicalProperties.new(100, originalProperties.Friction, originalProperties.Elasticity)
                
                task.delay(0.2, function()
                    if vehicleRoot then vehicleRoot.CustomPhysicalProperties = originalProperties end
                end)
            end

            task.delay(pitCooldown, function() isPitting = false end)
        end
    elseif math.abs(steerInput) < 0.2 then
        isPitting = false
    end
end)

