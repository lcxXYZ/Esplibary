--// Variables
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local cache = {}

local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

--// Settings: Now initialized and stored in the global environment (getgenv())
-- Ensure these settings are available for the UI (main_ui_loader.lua)
if not getgenv().ESP_SETTINGS then
    getgenv().ESP_SETTINGS = {
        BoxOutlineColor = Color3.new(0, 0, 0),
        BoxColor = Color3.new(1, 1, 1),
        NameColor = Color3.new(1, 1, 1),
        HealthOutlineColor = Color3.new(0, 0, 0),
        HealthHighColor = Color3.new(0, 1, 0),
        HealthLowColor = Color3.new(1, 0, 0),
        CharSize = Vector2.new(4, 6),
        Teamcheck = false,
        WallCheck = false,
        Enabled = true,
        ShowBox = true,
        BoxType = "2D", -- Options: "2D", "Corner Box Esp"
        ShowName = true,
        ShowHealth = false,
        ShowDistance = false,
        ShowSkeletons = false,
        ShowTracer = false,
        TracerColor = Color3.new(1, 1, 1), 
        TracerThickness = 2,
        SkeletonsColor = Color3.new(1, 1, 1),
        TracerPosition = "Bottom", -- Options: "Top", "Middle", "Bottom"
    }
end
local ESP_SETTINGS = getgenv().ESP_SETTINGS -- Local reference for cleaner code

local function create(class, properties)
    local drawing = Drawing.new(class)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

local function createEsp(player)
    local esp = {
        boxOutline = create("Square", {
            Color = ESP_SETTINGS.BoxOutlineColor,
            Thickness = 3,
            Filled = false
        }),
        box = create("Square", {
            Color = ESP_SETTINGS.BoxColor,
            Thickness = 1,
            Filled = false
        }),
        name = create("Text", {
            Color = ESP_SETTINGS.NameColor,
            Outline = true,
            Center = true,
            Size = 13
        }),
        healthOutline = create("Line", {
            Thickness = 3,
            Color = ESP_SETTINGS.HealthOutlineColor
        }),
        health = create("Line", {
            Thickness = 1
        }),
        distance = create("Text", {
            Color = Color3.new(1, 1, 1),
            Size = 12,
            Outline = true,
            Center = true
        }),
        tracer = create("Line", {
            Thickness = ESP_SETTINGS.TracerThickness,
            Color = ESP_SETTINGS.TracerColor,
            Transparency = 1
        }),
        boxLines = {},
        skeletonlines = {}, -- Initialize skeleton lines array
    }

    -- Pre-create Corner Box lines (they are just hidden initially)
    for i = 1, 16 do
        esp.boxLines[#esp.boxLines + 1] = create("Line", {
            Thickness = 1,
            Color = ESP_SETTINGS.BoxColor,
            Transparency = 1,
            Visible = false
        })
    end

    cache[player] = esp
end

local function isPlayerBehindWall(player)
    local character = player.Character
    if not character then
        return false
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false
    end

    local ray = Ray.new(camera.CFrame.Position, (rootPart.Position - camera.CFrame.Position).Unit * (rootPart.Position - camera.CFrame.Position).Magnitude)
    local hit, position = workspace:FindPartOnRayWithIgnoreList(ray, {localPlayer.Character, character})
    
    return hit and hit:IsA("Part")
end

local function removeEsp(player)
    local esp = cache[player]
    if not esp then return end

    -- Remove all drawing objects associated with the player
    for _, drawing in pairs(esp) do
        if type(drawing) == "userdata" and drawing.ClassName == "Drawing" then
            drawing:Remove()
        elseif type(drawing) == "table" and drawing ~= esp.boxLines and drawing ~= esp.skeletonlines then -- If it's a table that isn't the line caches, skip
            for _, line in ipairs(drawing) do
                if line and line.ClassName == "Drawing" then
                    line:Remove()
                end
            end
        end
    end

    -- Also explicitly remove cached lines
    for _, line in ipairs(esp.boxLines) do
        line:Remove()
    end
    for _, lineData in ipairs(esp.skeletonlines) do
        lineData[1]:Remove()
    end

    cache[player] = nil
end


local function updateVisibility(esp, isVisible)
    for key, drawing in pairs(esp) do
        -- Skip the line caches which are tables, not single Drawing objects
        if key ~= "boxLines" and key ~= "skeletonlines" then
            if type(drawing) == "userdata" and drawing.ClassName == "Drawing" then
                drawing.Visible = isVisible
            end
        end
    end
    
    -- Hide all cached lines explicitly if main visibility is off
    if not isVisible then
        for _, line in ipairs(esp.boxLines) do
            line.Visible = false
        end
        for _, lineData in ipairs(esp.skeletonlines) do
            lineData[1].Visible = false
        end
    end
end

local function updateEsp()
    for player, esp in pairs(cache) do
        local character, team = player.Character, player.Team
        -- Check if player is valid and team check passes
        if character and (not ESP_SETTINGS.Teamcheck or (team and team ~= localPlayer.Team)) then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChild("Humanoid")
            local isBehindWall = ESP_SETTINGS.WallCheck and isPlayerBehindWall(player)
            local shouldShow = not isBehindWall and ESP_SETTINGS.Enabled
            
            if rootPart and head and humanoid and shouldShow then
                local position, onScreen = camera:WorldToViewportPoint(rootPart.Position)
                
                if onScreen then
                    -- Player is visible and should be drawn
                    
                    local hrp2D = camera:WorldToViewportPoint(rootPart.Position)
                    -- Calculate dynamic box size
                    local charSize = (camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0)).Y - camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2.6, 0)).Y) / 2
                    local boxSize = Vector2.new(math.floor(charSize * 1.8), math.floor(charSize * 1.9))
                    local boxPosition = Vector2.new(math.floor(hrp2D.X - boxSize.X / 2), math.floor(hrp2D.Y - charSize * 1.6 / 2))

                    
                    -- NAME
                    if ESP_SETTINGS.ShowName then
                        esp.name.Visible = true
                        esp.name.Text = string.lower(player.Name)
                        esp.name.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y - 16)
                        esp.name.Color = ESP_SETTINGS.NameColor
                    else
                        esp.name.Visible = false
                    end

                    -- BOX
                    if ESP_SETTINGS.ShowBox then
                        if ESP_SETTINGS.BoxType == "2D" then
                            -- Hide corner lines
                            for _, line in ipairs(esp.boxLines) do line.Visible = false end
                            
                            -- Show 2D box
                            esp.boxOutline.Size = boxSize
                            esp.boxOutline.Position = boxPosition
                            esp.boxOutline.Color = ESP_SETTINGS.BoxOutlineColor
                            esp.boxOutline.Visible = true

                            esp.box.Size = boxSize
                            esp.box.Position = boxPosition
                            esp.box.Color = ESP_SETTINGS.BoxColor
                            esp.box.Visible = true

                        elseif ESP_SETTINGS.BoxType == "Corner Box Esp" then
                            -- Hide 2D box
                            esp.box.Visible = false
                            esp.boxOutline.Visible = false
                            
                            local lineW = (boxSize.X / 5)
                            local lineH = (boxSize.Y / 6)
                            local lineT = 1
    
                            local boxLines = esp.boxLines
                            
                            -- Update Corner Box Lines
                            -- 1-8: Main box lines (using BoxColor)
                            boxLines[1].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                            boxLines[1].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y - lineT)
                            boxLines[2].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                            boxLines[2].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + lineH)
                            boxLines[3].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y - lineT)
                            boxLines[3].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                            boxLines[4].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                            boxLines[4].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + lineH)
                            boxLines[5].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y - lineH)
                            boxLines[5].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                            boxLines[6].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                            boxLines[6].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y + lineT)
                            boxLines[7].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y + lineT)
                            boxLines[7].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
                            boxLines[8].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y - lineH)
                            boxLines[8].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
    
                            -- 9-16: Outline lines (using BoxOutlineColor, thicker)
                            boxLines[9].From = Vector2.new(boxPosition.X, boxPosition.Y)
                            boxLines[9].To = Vector2.new(boxPosition.X, boxPosition.Y + lineH)
                            boxLines[10].From = Vector2.new(boxPosition.X, boxPosition.Y)
                            boxLines[10].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y)
                            boxLines[11].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y)
                            boxLines[11].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)
                            boxLines[12].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)
                            boxLines[12].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + lineH)
                            boxLines[13].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y - lineH)
                            boxLines[13].To = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)
                            boxLines[14].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)
                            boxLines[14].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y)
                            boxLines[15].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y)
                            boxLines[15].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)
                            boxLines[16].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y - lineH)
                            boxLines[16].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)
    
                            for i, line in ipairs(boxLines) do
                                line.Visible = true
                                if i <= 8 then
                                    line.Thickness = 1
                                    line.Color = ESP_SETTINGS.BoxColor
                                else -- Outline lines
                                    line.Thickness = 2
                                    line.Color = ESP_SETTINGS.BoxOutlineColor
                                end
                            end
                        end
                    else -- ShowBox is false
                        esp.box.Visible = false
                        esp.boxOutline.Visible = false
                        for _, line in ipairs(esp.boxLines) do
                            line.Visible = false
                        end
                    end

                    -- HEALTH
                    if ESP_SETTINGS.ShowHealth then
                        esp.healthOutline.Visible = true
                        esp.health.Visible = true
                        local healthPercentage = humanoid.Health / humanoid.MaxHealth
                        
                        esp.healthOutline.Color = ESP_SETTINGS.HealthOutlineColor
                        esp.healthOutline.From = Vector2.new(boxPosition.X - 6, boxPosition.Y + boxSize.Y)
                        esp.healthOutline.To = Vector2.new(esp.healthOutline.From.X, boxPosition.Y) -- Outline runs full height
                        
                        esp.health.From = Vector2.new(boxPosition.X - 5, boxPosition.Y + boxSize.Y)
                        esp.health.To = Vector2.new(esp.health.From.X, boxPosition.Y + (boxSize.Y * (1 - healthPercentage))) -- Health fill starts from bottom
                        esp.health.Color = ESP_SETTINGS.HealthLowColor:Lerp(ESP_SETTINGS.HealthHighColor, healthPercentage)
                    else
                        esp.healthOutline.Visible = false
                        esp.health.Visible = false
                    end

                    -- DISTANCE
                    if ESP_SETTINGS.ShowDistance then
                        local distance = (camera.CFrame.p - rootPart.Position).Magnitude
                        esp.distance.Text = string.format("%.1f studs", distance)
                        esp.distance.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 5)
                        esp.distance.Visible = true
                    else
                        esp.distance.Visible = false
                    end

                    -- SKELETONS
                    if ESP_SETTINGS.ShowSkeletons then
                        if #esp.skeletonlines == 0 then
                            for _, bonePair in ipairs(bones) do
                                local parentBone, childBone = bonePair[1], bonePair[2]
                                
                                if character:FindFirstChild(parentBone) and character:FindFirstChild(childBone) then
                                    local skeletonLine = create("Line", {
                                        Thickness = 1,
                                        Color = ESP_SETTINGS.SkeletonsColor,
                                        Transparency = 1
                                    })
                                    esp.skeletonlines[#esp.skeletonlines + 1] = {skeletonLine, parentBone, childBone}
                                end
                            end
                        end
                    
                        for _, lineData in ipairs(esp.skeletonlines) do
                            local skeletonLine = lineData[1]
                            local parentBone, childBone = lineData[2], lineData[3]
                            local p1, p2 = character:FindFirstChild(parentBone), character:FindFirstChild(childBone)
                    
                            if p1 and p2 then
                                local parentPosition, onScreen1 = camera:WorldToViewportPoint(p1.Position)
                                local childPosition, onScreen2 = camera:WorldToViewportPoint(p2.Position)
                    
                                if onScreen1 and onScreen2 then
                                    skeletonLine.From = Vector2.new(parentPosition.X, parentPosition.Y)
                                    skeletonLine.To = Vector2.new(childPosition.X, childPosition.Y)
                                    skeletonLine.Color = ESP_SETTINGS.SkeletonsColor
                                    skeletonLine.Visible = true
                                else
                                    skeletonLine.Visible = false
                                end
                            else
                                -- Clean up invalid bone line (should only happen if the part is destroyed)
                                skeletonLine:Remove()
                                lineData[1] = nil 
                            end
                        end
                    else
                        for _, lineData in ipairs(esp.skeletonlines) do
                            if lineData and lineData[1] then
                                lineData[1].Visible = false
                            end
                        end
                    end                    

                    -- TRACER
                    if ESP_SETTINGS.ShowTracer then
                        local tracerY
                        if ESP_SETTINGS.TracerPosition == "Top" then
                            tracerY = 0
                        elseif ESP_SETTINGS.TracerPosition == "Middle" then
                            tracerY = camera.ViewportSize.Y / 2
                        else
                            tracerY = camera.ViewportSize.Y
                        end
                        
                        -- Team check logic
                        if ESP_SETTINGS.Teamcheck and player.Team and player.Team == localPlayer.Team then
                            esp.tracer.Visible = false
                        else
                            esp.tracer.Visible = true
                            esp.tracer.From = Vector2.new(camera.ViewportSize.X / 2, tracerY)
                            esp.tracer.To = Vector2.new(hrp2D.X, hrp2D.Y)
                            esp.tracer.Color = ESP_SETTINGS.TracerColor
                            esp.tracer.Thickness = ESP_SETTINGS.TracerThickness
                        end
                    else
                        esp.tracer.Visible = false
                    end
                
                else
                    -- Player is off-screen but character is valid, so hide all drawings
                    updateVisibility(esp, false)
                end
            
            else
                -- Character or necessary parts (HRP, Head, Humanoid) don't exist, or WallCheck failed, so hide all drawings
                updateVisibility(esp, false)
            end
        
        else
            -- Player doesn't exist, or Teamcheck failed (if enabled), so hide all drawings
            updateVisibility(esp, false)
        end
    end
end


-- ====================================================================
-- // Initialization and Event Handling
-- ====================================================================

-- Initial creation for existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        createEsp(player)
    end
end

-- New player handling
Players.PlayerAdded:Connect(function(player)
    if player ~= localPlayer then
        createEsp(player)
    end
end)

-- Player removal handling
Players.PlayerRemoving:Connect(function(player)
    removeEsp(player)
end)

-- Main rendering loop
RunService.RenderStepped:Connect(updateEsp)
