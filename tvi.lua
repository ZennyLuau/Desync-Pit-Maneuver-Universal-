local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "ZenithViking | Tactical System",
   LoadingTitle = "Initializing Systems...",
   LoadingSubtitle = "by Tâm",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false,
   Theme = {
       TextColor = Color3.fromRGB(240, 248, 255),       
       Background = Color3.fromRGB(10, 25, 40),         
       Topbar = Color3.fromRGB(5, 15, 25),              
       Shadow = Color3.fromRGB(0, 0, 0),
       Toggle = Color3.fromRGB(0, 180, 255),            
       ToggleOutline = Color3.fromRGB(0, 100, 200),
       ToggleOff = Color3.fromRGB(30, 45, 60),
       Slider = Color3.fromRGB(0, 150, 255),
       Tab = Color3.fromRGB(15, 35, 55),
       TabBackground = Color3.fromRGB(10, 25, 40)
   }
})

task.spawn(function()
    for _, gui in pairs(game:GetService("CoreGui"):GetDescendants()) do
        if gui:IsA("Frame") and gui.BackgroundColor3 == Color3.fromRGB(10, 25, 40) then
            gui.BackgroundTransparency = 0.25 
        end
    end
end)

local MainTab = Window:CreateTab("Combat & PIT", 4483362458)
local ModTab = Window:CreateTab("Vehicle Mods", 4483362458)
local AimTab = Window:CreateTab("Aimlock", 4483362458) 
local VisualsTab = Window:CreateTab("Visuals & ESP", 4483362458) 

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- [>] SYSTEM VARIABLES
-- ==========================================
local desyncEnabled, heavyAnchorEnabled = false, false
local brakeForceMultiplier = 40
local isPitting = false
local autoGrokPITEnabled = false
local wedgeStrikeEnabled = false
local wedgeForce = 75

local noclipEnabled, pushBarEnabled = false, false
local activePushBar = nil
local spoofyVehicleEnabled = false
local engineOverclockEnabled = false
local speedBoostAmount = 5

local aimbotEnabled, teamCheckMode, wallCheckEnabled = false, "Ignore Friendly", true
local aimSmoothness, predictionFactor = 0.5, 0
local fovEnabled = false
local FOVCircle = Drawing.new("Circle")
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(0, 180, 255)
FOVCircle.Thickness = 1
FOVCircle.Visible = false

local espEnabled, espShowName, espShowHighlight = false, true, true
local espObjects = {}
local showDesyncVisuals, pingPrediction = false, 0.1
local activeGhostModel, trackedTarget = nil, nil

local antiCheatBypassEnabled = false
local antiKickEnabled = false
local createESP 

-- ==========================================
-- [>] ANTI-CHEAT BYPASS & ANTI-KICK
-- ==========================================
local function detectAndBypassAntiCheat()
    print("[ZenithViking] Scanning game for anti-cheat (Fling/Fly/Speed/Adonis/Prodais)...")
    local acNames = {"AntiCheat", "AC", "AntiExploit", "Adonis", "Prodais", "AntiFling", "AntiFly", "AntiSpeed", "AntiCheatFolder", "AntiHack", "AntiCheatModule"}
    local detected = false

    for _, name in ipairs(acNames) do
        local found = workspace:FindFirstChild(name, true) or game.ReplicatedStorage:FindFirstChild(name, true) or game.StarterPlayer:FindFirstChild(name, true) or game.ServerScriptService:FindFirstChild(name, true)
        if found then
            pcall(function() found:Destroy() end)
            detected = true
        end
    end

    for _, obj in pairs(game:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            local lower = obj.Name:lower()
            if lower:find("anti") or lower:find("ac_") or lower:find("adonis") or lower:find("prodais") or lower:find("fling") or lower:find("fly") or lower:find("speedhack") then
                pcall(function() obj.Disabled = true; obj:Destroy() end)
                detected = true
            end
        end
    end

    if detected then
        task.spawn(function()
            while antiCheatBypassEnabled do
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("BasePart") and v.AssemblyLinearVelocity.Magnitude > 600 then
                        v.AssemblyLinearVelocity *= 0.15
                    end
                end
                task.wait(0.08)
            end
        end)
    end
end

local function enableAntiKick()
    if not antiKickEnabled then return end
    local lp = Players.LocalPlayer
    local oldKick = lp.Kick
    lp.Kick = function(self, reason)
        if self == lp then return end
        return oldKick(self, reason)
    end
end

-- ==========================================
-- [>] COMMAND INTERFACE (GUI)
-- ==========================================
local LateralSection = MainTab:CreateSection("Ghost PIT (Lateral Strike)")
MainTab:CreateToggle({Name = "Enable Manual Ghost PIT (Steering)", CurrentValue = false, Callback = function(Value) desyncEnabled = Value end})
MainTab:CreateToggle({Name = "Enable Auto-Grok PIT (Proximity Scan)", CurrentValue = false, Callback = function(Value) autoGrokPITEnabled = Value end})
MainTab:CreateToggle({Name = "Titanium Rear Guard (Max Mass)", CurrentValue = false, Callback = function(Value) heavyAnchorEnabled = Value end})
MainTab:CreateSlider({Name = "Lateral Strike Force", Range = {10, 150}, Increment = 5, CurrentValue = 40, Callback = function(Value) brakeForceMultiplier = Value end})

local WedgeSection = MainTab:CreateSection("Wedge Strike (Barrel-Roll Upgrade)")
MainTab:CreateToggle({Name = "Enable Wedge Strike (Vertical Launch)", CurrentValue = false, Callback = function(Value) wedgeStrikeEnabled = Value end})
MainTab:CreateSlider({Name = "Wedge Upward Force", Range = {10, 200}, Increment = 10, CurrentValue = 75, Callback = function(Value) wedgeForce = Value end})

ModTab:CreateToggle({Name = "Vehicle Noclip", CurrentValue = false, Callback = function(Value) noclipEnabled = Value end})
ModTab:CreateToggle({Name = "Spoofy Vehicle (Power Steering & Downforce)", CurrentValue = false, Callback = function(Value) spoofyVehicleEnabled = Value end})
ModTab:CreateToggle({Name = "Engine Overclock (Speed Hack)", CurrentValue = false, Callback = function(Value) engineOverclockEnabled = Value end})
ModTab:CreateSlider({Name = "Overclock Multiplier", Range = {1, 50}, Increment = 1, CurrentValue = 5, Callback = function(Value) speedBoostAmount = Value end})
ModTab:CreateToggle({Name = "Equip Heavy Ram Bar", CurrentValue = false, Callback = function(Value) pushBarEnabled = Value if not pushBarEnabled and activePushBar then activePushBar:Destroy() activePushBar = nil end end})

ModTab:CreateToggle({Name = "Bypass anti Fling/Fly/Speedhack/Adonis", CurrentValue = false, Callback = function(Value) 
    antiCheatBypassEnabled = Value 
    if Value then detectAndBypassAntiCheat() end 
end})
ModTab:CreateToggle({Name = "Anti-Kick (Local Script Only)", CurrentValue = false, Callback = function(Value) 
    antiKickEnabled = Value 
    if Value then enableAntiKick() end 
end})

AimTab:CreateToggle({Name = "Enable Aimlock", CurrentValue = false, Callback = function(Value) aimbotEnabled = Value end})
AimTab:CreateDropdown({Name = "Team Check Mode", Options = {"Off", "Ignore Friendly"}, CurrentOption = {"Ignore Friendly"}, MultipleOptions = false, Callback = function(Option) teamCheckMode = Option[1] end})
AimTab:CreateToggle({Name = "Aimbot Wall Check", CurrentValue = true, Callback = function(Value) wallCheckEnabled = Value end})
AimTab:CreateSlider({Name = "Aim Smoothness", Range = {1, 100}, Increment = 1, CurrentValue = 50, Callback = function(Value) aimSmoothness = Value / 100 end})
AimTab:CreateSlider({Name = "Aim Velocity Prediction", Range = {0, 200}, Increment = 5, CurrentValue = 0, Callback = function(Value) predictionFactor = Value / 1000 end})
AimTab:CreateToggle({Name = "Show FOV Circle", CurrentValue = false, Callback = function(Value) fovEnabled = Value; FOVCircle.Visible = Value end})
AimTab:CreateSlider({Name = "FOV Size", Range = {10, 500}, Increment = 5, CurrentValue = 100, Callback = function(Value) FOVCircle.Radius = Value end})

VisualsTab:CreateToggle({Name = "Show Tactical Hologram (Desync)", CurrentValue = false, Callback = function(Value) showDesyncVisuals = Value if not showDesyncVisuals and activeGhostModel then activeGhostModel:Destroy() activeGhostModel = nil trackedTarget = nil end end})
VisualsTab:CreateSlider({Name = "Prediction Ping (ms)", Range = {0, 300}, Increment = 10, CurrentValue = 100, Callback = function(Value) pingPrediction = Value / 1000 end})
VisualsTab:CreateToggle({
    Name = "Enable Master ESP", 
    CurrentValue = false, 
    Callback = function(Value) 
        espEnabled = Value 
        if espEnabled then
            for _, player in pairs(Players:GetPlayers()) do createESP(player) end
        else
            for _, obj in pairs(espObjects) do obj:Destroy() end
            table.clear(espObjects)
        end
    end
})
VisualsTab:CreateToggle({Name = "Show Highlight Box", CurrentValue = true, Callback = function(Value) espShowHighlight = Value end})
VisualsTab:CreateToggle({Name = "Show Text Data", CurrentValue = true, Callback = function(Value) espShowName = Value end})

-- ==========================================
-- [>] TACTICAL FUNCTIONS
-- ==========================================
local function getCarData(player)
    player = player or LocalPlayer
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or not hum.SeatPart then return nil end
    local seat = hum.SeatPart
    local myCar = seat:FindFirstAncestorOfClass("Model")
    while myCar and myCar.Parent and myCar.Parent:IsA("Model") do myCar = myCar.Parent end
    if myCar and myCar ~= workspace then return myCar, myCar.PrimaryPart or seat, seat end
    return nil
end

local function tryGrokAutoPIT(myCar, myRoot)
    if isPitting then return end
    for _, enemy in pairs(Players:GetPlayers()) do
        if enemy ~= LocalPlayer then
            local enemyCarData = {getCarData(enemy)}
            if enemyCarData[1] then
                local targetRoot = enemyCarData[2]
                local distance = (myRoot.Position - targetRoot.Position).Magnitude
                if distance <= 12 then
                    local relativeDir = (targetRoot.Position - myRoot.Position).Unit
                    local forward = myRoot.CFrame.LookVector
                    local alignment = forward:Dot(relativeDir)
                    if alignment > 0.55 then
                        isPitting = true
                        local relPos = myRoot.Position - targetRoot.Position
                        local sideDot = targetRoot.CFrame.RightVector:Dot(relPos.Unit)
                        local pushSide = (sideDot > 0) and targetRoot.CFrame.RightVector or -targetRoot.CFrame.RightVector
                        
                        -- Dynamic Force: Scales with speed for a harder hit
                        local dynamicMultiplier = 120 * (1 + (myRoot.AssemblyLinearVelocity.Magnitude / 100))
                        local lateralForce = pushSide * dynamicMultiplier
                        
                        local verticalForce = wedgeStrikeEnabled and Vector3.new(0, wedgeForce, 0) or Vector3.new(0, 0, 0)
                        local angularForce = Vector3.new(
                            wedgeStrikeEnabled and (sideDot > 0 and 15 or -15) or 0, 
                            sideDot > 0 and 12 or -12, 
                            wedgeStrikeEnabled and (sideDot > 0 and 10 or -10) or 0
                        )
                        
                        myRoot.AssemblyLinearVelocity = myRoot.AssemblyLinearVelocity + lateralForce + verticalForce
                        myRoot.AssemblyAngularVelocity = angularForce
                        
                        local originalProps = myRoot.CustomPhysicalProperties or PhysicalProperties.new(myRoot.Material)
                        -- Density 100, Friction 2.0 (High drag), Elasticity 0 (No bounce)
                        myRoot.CustomPhysicalProperties = PhysicalProperties.new(100, 2, 0)
                        
                        -- Auto PIT needs a tiny reset to avoid crashing the game in a 1-frame loop
                        task.delay(0.25, function() 
                            if myRoot then myRoot.CustomPhysicalProperties = originalProps end 
                            isPitting = false 
                        end)
                        return 
                    end
                end
            end
        end
    end
end

-- ==========================================
-- [>] ESP ENGINE
-- ==========================================
createESP = function(player)
    if player == LocalPlayer or not espEnabled then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    if espObjects[player.Name.."_HL"] then espObjects[player.Name.."_HL"]:Destroy() end
    if espObjects[player.Name.."_BB"] then espObjects[player.Name.."_BB"]:Destroy() end

    local teamColor = player.TeamColor and player.TeamColor.Color or Color3.new(1, 1, 1)
    
    local highlight = Instance.new("Highlight")
    highlight.Parent = CoreGui
    highlight.Adornee = char
    highlight.FillColor = teamColor
    highlight.OutlineColor = teamColor
    highlight.FillTransparency = 0.5
    highlight.Enabled = false
    espObjects[player.Name.."_HL"] = highlight
    
    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.ExtentsOffset = Vector3.new(0, 3, 0)
    local textLabel = Instance.new("TextLabel", billboard)
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 14
    textLabel.TextStrokeTransparency = 0 
    textLabel.TextColor3 = teamColor
    billboard.Parent = CoreGui
    billboard.Adornee = char.HumanoidRootPart
    billboard.Enabled = false
    espObjects[player.Name.."_BB"] = billboard
end

local function removeESP(player)
    if espObjects[player.Name.."_HL"] then espObjects[player.Name.."_HL"]:Destroy(); espObjects[player.Name.."_HL"] = nil end
    if espObjects[player.Name.."_BB"] then espObjects[player.Name.."_BB"]:Destroy(); espObjects[player.Name.."_BB"] = nil end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function() task.wait(1) createESP(player) end)
    player:GetPropertyChangedSignal("Team"):Connect(function() createESP(player) end)
end)
Players.PlayerRemoving:Connect(removeESP)

for _, player in pairs(Players:GetPlayers()) do 
    if player.Character then
        player.CharacterAdded:Connect(function() task.wait(1) createESP(player) end)
    end
end

-- ==========================================
-- [>] EXECUTION LOOPS
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

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    if aimbotEnabled then
        local closestTarget, shortestDistance = nil, math.huge
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                if teamCheckMode == "Off" or (teamCheckMode == "Ignore Friendly" and player.Team ~= LocalPlayer.Team) then
                    local rootPart = player.Character.HumanoidRootPart
                    local predictedPos = rootPart.Position + (rootPart.AssemblyLinearVelocity * predictionFactor)
                    local vector, onScreen = Camera:WorldToViewportPoint(predictedPos)
                    if onScreen then
                        local distanceToCenter = (Vector2.new(vector.X, vector.Y) - FOVCircle.Position).Magnitude
                        if (not fovEnabled or distanceToCenter <= FOVCircle.Radius) and distanceToCenter < shortestDistance then
                            closestTarget = predictedPos
                            shortestDistance = distanceToCenter
                        end
                    end
                end
            end
        end
        if closestTarget then Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, closestTarget), aimSmoothness) end
    end

    if showDesyncVisuals then
        local character = LocalPlayer.Character
        if character then
            local currentTarget = character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid and humanoid.SeatPart then
                local myCar = humanoid.SeatPart:FindFirstAncestorOfClass("Model")
                if myCar then currentTarget = myCar rootPart = myCar.PrimaryPart or humanoid.SeatPart end
            end
            if rootPart then
                if trackedTarget ~= currentTarget then
                    if activeGhostModel then activeGhostModel:Destroy() end
                    activeGhostModel = currentTarget:Clone()
                    for _, p in ipairs(activeGhostModel:GetDescendants()) do
                        if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.Massless = true p.Material = Enum.Material.ForceField p.Color = Color3.fromRGB(150, 200, 255)
                        else pcall(function() p:Destroy() end) end
                    end
                    activeGhostModel.Parent = Camera
                    trackedTarget = currentTarget
                end
                if activeGhostModel then activeGhostModel:PivotTo(rootPart.CFrame + (rootPart.AssemblyLinearVelocity * pingPrediction)) end
            end
        end
    end

    if espEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                local hl = espObjects[player.Name.."_HL"]
                local bb = espObjects[player.Name.."_BB"]
                
                if hl then hl.Enabled = espShowHighlight end
                if bb then
                    bb.Enabled = espShowName
                    if espShowName then
                        local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
                        local teamStr = player.Team and ("["..player.Team.Name.."]\n") or ""
                        bb.TextLabel.Text = teamStr .. player.DisplayName .. " (@" .. player.Name .. ")\n" .. dist .. " Studs"
                    end
                end
            end
        end
    else
        for _, obj in pairs(espObjects) do obj.Enabled = false end
   end
end)

RunService.Heartbeat:Connect(function(deltaTime)
    local myCar, vehicleRoot, seat = getCarData()
    if not myCar then return end
    
    local steerInput = seat:IsA("VehicleSeat") and seat.SteerFloat or 0 
    local throttleInput = seat:IsA("VehicleSeat") and seat.ThrottleFloat or 0
    local currentVelocity = vehicleRoot.AssemblyLinearVelocity
    local speed = currentVelocity.Magnitude

    -- TRUE PIVOT SPOOFY VEHICLE
    if spoofyVehicleEnabled and not isPitting then
        local carCFrame = myCar:GetPivot()
        local rightVector = carCFrame.RightVector
        
        vehicleRoot.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, currentVelocity.Y - 1.5, currentVelocity.Z)
        
        local lateralVelocity = vehicleRoot.AssemblyLinearVelocity:Dot(rightVector)
        vehicleRoot.AssemblyLinearVelocity = vehicleRoot.AssemblyLinearVelocity - (rightVector * (lateralVelocity * 0.85))
        
        if math.abs(steerInput) > 0 then
            vehicleRoot.AssemblyAngularVelocity = Vector3.new(
                vehicleRoot.AssemblyAngularVelocity.X,
                -steerInput * 8, 
                vehicleRoot.AssemblyAngularVelocity.Z
            )
        else
            vehicleRoot.AssemblyAngularVelocity = Vector3.new(
                vehicleRoot.AssemblyAngularVelocity.X,
                0, 
                vehicleRoot.AssemblyAngularVelocity.Z
            )
        end
    end

    -- ENGINE OVERCLOCK
    if engineOverclockEnabled and throttleInput > 0 then
        local flatLook = (vehicleRoot.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
        vehicleRoot.AssemblyLinearVelocity = vehicleRoot.AssemblyLinearVelocity + (flatLook * speedBoostAmount)
        if antiCheatBypassEnabled then
            vehicleRoot.AssemblyLinearVelocity = vehicleRoot.AssemblyLinearVelocity + (flatLook * (speedBoostAmount * 1.8))
        end
    end

    -- MANUAL GHOST PIT (0 Cooldown, Dynamic Speed Scaling)
    if desyncEnabled and not autoGrokPITEnabled and speed > 30 and math.abs(steerInput) > 0.8 then
        if not isPitting then
            isPitting = true 
            
            local carCFrame = myCar:GetPivot()
            local flatRight = (carCFrame.RightVector * Vector3.new(1, 0, 1)).Unit
            local flatLook = (carCFrame.LookVector * Vector3.new(1, 0, 1)).Unit
            local lateralDirection = flatRight * steerInput
            local verticalForce = wedgeStrikeEnabled and Vector3.new(0, wedgeForce * 2, 0) or Vector3.new(0, 0, 0)
            
            -- Speed Multiplier: Hitting them at 100 MPH makes the strike force 2x stronger
            local dynamicMultiplier = brakeForceMultiplier * (1 + (speed / 100))
            
            -- Forward Lunge: Injects 20% of your current speed forward to punch through the target
            local forwardLunge = flatLook * (speed * 0.2)
            
            vehicleRoot.AssemblyLinearVelocity = currentVelocity + forwardLunge + (lateralDirection * dynamicMultiplier) + verticalForce
            vehicleRoot.AssemblyAngularVelocity = Vector3.new(0, steerInput * (dynamicMultiplier * 0.5), 0)
            
            if heavyAnchorEnabled then
                local ogProps = vehicleRoot.CustomPhysicalProperties or PhysicalProperties.new(vehicleRoot.Material)
                
                -- True Titanium: Density 100, High Drag Friction (2), Zero Bounce Elasticity (0)
                vehicleRoot.CustomPhysicalProperties = PhysicalProperties.new(100, 2, 0)
                
                -- Anti-Flip Anchor: Freezes your car from barrel-rolling when hitting them
                vehicleRoot.AssemblyAngularVelocity = Vector3.new(0, vehicleRoot.AssemblyAngularVelocity.Y, 0)
                
                task.delay(0.25, function() if vehicleRoot then vehicleRoot.CustomPhysicalProperties = ogProps end end)
            end
            
            -- COOLDOWN DELETED: isPitting is only reset by straightening the steering wheel below.
        end
    elseif math.abs(steerInput) < 0.2 then
        -- INSTANT RESET: The millisecond you let go of steer, you can strike again
        isPitting = false
    end
end)
