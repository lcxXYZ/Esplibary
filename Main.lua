--[[
    T R A C E R Executor Core Logic (Expanded Custom ESP)
    
    This script provides a complete, raw Drawing-based ESP implementation 
    that now includes:
    1. Skeleton drawing.
    2. Viewline tracing.
    3. Weapon tracer line.
    4. Max Distance check.
    5. Team Check toggle.
    6. Visible Only (Raycast) check.
    
    All UI code and external dependencies (except the Aimbot loadstring) are removed.
]]

-- ====================================================================
-- === 1. DEPENDENCY LOADING ===
-- ====================================================================

-- Load Aimbot Library (Kept as requested)
loadstring(
    game:HttpGet(
        'https://raw.githubusercontent.com/Exunys/Aimbot-V3/main/src/Aimbot.lua'
    )
)()
-- Initialize Aimbot (Must be called once to start)
ExunysDeveloperAimbot.Load()

-- ====================================================================
-- === 2. CONFIGURATION AND CONTROL (Accessible via getgenv()) ===
-- ====================================================================

getgenv().ESPSettings = {
    -- === GLOBAL CONTROL ===
    Enabled = false, 

    -- === FEATURE TOGGLES (Set to true/false) ===
    FillEnabled = false,
    OutlineEnabled = false,
    HealthEnabled = false,   
    NameEnabled = false,     
    DistanceEnabled = false,
    
    -- --- NEW ESP FEATURES ---
    SkeletonEnabled = true,   -- TOGGLE: Enable/disable skeleton lines
    WeaponEnabled = false,    -- TOGGLE: Enable/disable weapon tracer/indicator
    ViewlineEnabled = true,   -- TOGGLE: Enable/disable view line
    TeamCheck = false,        -- TOGGLE: Enable/disable checking if targets are on the same team
    VisibleOnly = false,      -- TOGGLE: Enable/disable visibility check (requires Raycast)
    
    -- === DISTANCE & CHECK SETTINGS ===
    MaxDistance = 500,        -- Maximum distance (in studs) for ESP to render

    -- === COLORS AND THICKNESS ===
    BoxColor = Color3.fromRGB(255, 255, 255), 
    FillColor = Color3.fromRGB(0, 0, 0),    
    OutlineColor = Color3.fromRGB(0, 0, 0), 
    
    -- NEW COLOR/THICKNESS
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    ViewlineColor = Color3.fromRGB(255, 0, 0),
    WeaponColor = Color3.fromRGB(0, 255, 255),
    SkeletonThickness = 1,

    BoxThickness = 1,
    OutlineThickness = 1.5,
    FillTransparency = 0.5, 

    -- === TEXT SETTINGS ===
    NameColor = Color3.fromRGB(255, 255, 255),
    ToolColor = Color3.fromRGB(170, 0, 255),
    Font = Drawing.Fonts.Plex,

    -- === DIMENSION SETTINGS ===
    FootOffset = 5,
    WidthRatio = 1, 
}

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local ESPObjects = {}
local RenderStepConnection = nil -- Stores the connection for the main loop

-- Defines the skeleton structure (part name pairs) for drawing lines
local SKELETON_MAP = {
    {"Head", "UpperTorso"}, -- Changed "Torso" to "UpperTorso" for better alignment in R15
    {"UpperTorso", "RightUpperArm"}, {"UpperTorso", "LeftUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"RightLowerArm", "RightHand"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "LowerTorso"}, -- Link upper and lower torso
    {"LowerTorso", "RightUpperLeg"}, {"LowerTorso", "LeftUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"RightLowerLeg", "RightFoot"}, {"LeftLowerLeg", "LeftFoot"}
}

--// --- Utility Functions ---

-- Calculates the health color (Green -> Yellow -> Red gradient)
local function GetHealthColor(health, maxHealth)
    local ratio = health / maxHealth
    -- Interpolate from Red (0) to Green (1)
    return Color3.fromHSV(ratio * 0.35, 1, 1) -- HSV 0.35 is green, 0 is red
end

--// --- ESP Core Logic ---

--// Create ESP visuals
local function CreateESP(player)
    local esp = {}
    local settings = getgenv().ESPSettings

    -- 1. Outline box (Black, outer border)
    esp.BoxOutline = Drawing.new('Square')
    esp.BoxOutline.Thickness = settings.OutlineThickness
    esp.BoxOutline.Filled = false
    esp.BoxOutline.Color = settings.OutlineColor
    esp.BoxOutline.Transparency = 1

    -- 2. Filled Box (Transparent Background)
    esp.FilledBox = Drawing.new('Square')
    esp.FilledBox.Thickness = 0
    esp.FilledBox.Filled = true
    esp.FilledBox.Color = settings.FillColor
    esp.FilledBox.Transparency = settings.FillTransparency

    -- 3. Inner box (Main Line Border)
    esp.Box = Drawing.new('Square')
    esp.Box.Thickness = settings.BoxThickness
    esp.Box.Filled = false
    esp.Box.Color = settings.BoxColor
    esp.Box.Transparency = 1
    
    -- 4. Health Bar Outline
    esp.HealthBarOutline = Drawing.new('Square')
    esp.HealthBarOutline.Thickness = 1
    esp.HealthBarOutline.Filled = false
    esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.HealthBarOutline.Transparency = 1
    
    -- 5. Health Bar Fill
    esp.HealthBarFill = Drawing.new('Square')
    esp.HealthBarFill.Thickness = 0
    esp.HealthBarFill.Filled = true
    esp.HealthBarFill.Color = Color3.fromRGB(0, 255, 0)
    esp.HealthBarFill.Transparency = 0
    
    -- 6. Name tag
    esp.Name = Drawing.new('Text')
    esp.Name.Size = 14
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Font = settings.Font
    esp.Name.Color = settings.NameColor

    -- 7. Tool tag
    esp.Tool = Drawing.new('Text')
    esp.Tool.Size = 14
    esp.Tool.Center = true
    esp.Tool.Outline = true
    esp.Tool.Font = settings.Font
    esp.Tool.Color = settings.ToolColor
    
    -- 8. Distance Text
    esp.Distance = Drawing.new('Text')
    esp.Distance.Size = 13
    esp.Distance.Center = false
    esp.Distance.Outline = true
    esp.Distance.Font = settings.Font
    esp.Distance.Color = Color3.fromRGB(255, 255, 255)
    
    -- 9. Skeleton Lines (New)
    esp.Skeleton = {}
    for i = 1, #SKELETON_MAP do
        local line = Drawing.new('Line')
        line.Color = settings.SkeletonColor
        line.Thickness = settings.SkeletonThickness
        line.Visible = false
        table.insert(esp.Skeleton, line)
    end
    
    -- 10. View Line (New)
    esp.Viewline = Drawing.new('Line')
    esp.Viewline.Color = settings.ViewlineColor
    esp.Viewline.Thickness = 1
    esp.Viewline.Visible = false
    
    -- 11. Weapon Tracer (Line from HRP to Tool) (New)
    esp.WeaponTracer = Drawing.new('Line')
    esp.WeaponTracer.Color = settings.WeaponColor
    esp.WeaponTracer.Thickness = 1.5
    esp.WeaponTracer.Visible = false
    
    -- Ensure everything starts hidden
    for _, obj in pairs(esp) do
        if type(obj) == 'table' then -- Handle nested Skeleton table
            for _, line in pairs(obj) do
                line.Visible = false
            end
        else
            obj.Visible = false
        end
    end

    return esp
end

--// Cleanup function to remove all drawings for a single player
local function RemoveESP(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            -- Handle both single drawings and the nested Skeleton table
            if type(obj) == 'table' then
                for _, line in pairs(obj) do
                    line:Remove()
                end
            else
                obj:Remove()
            end
        end
        ESPObjects[player] = nil
    end
end

--// Function to hide all active ESP drawings
local function HideAllESP()
    for _, esp in pairs(ESPObjects) do
        for _, obj in pairs(esp) do
            -- Handle both single drawings and the nested Skeleton table
            if type(obj) == 'table' then
                for _, line in pairs(obj) do
                    line.Visible = false
                end
            else
                obj.Visible = false
            end
        end
    end
end

--// Main rendering loop (Update function)
local function UpdateESP()
    local settings = getgenv().ESPSettings
    local hrpLocal = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')

    for _, player in pairs(Players:GetPlayers()) do
        if
            player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild('HumanoidRootPart')
        then
            if not ESPObjects[player] then
                ESPObjects[player] = CreateESP(player)
            end

            local esp = ESPObjects[player]
            local char = player.Character
            local hrp = char:FindFirstChild('HumanoidRootPart')
            local head = char:FindFirstChild('Head')
            local humanoid = char:FindFirstChildOfClass('Humanoid')
            local tool = char:FindFirstChildOfClass('Tool')

            if hrp and head and humanoid and hrpLocal then
                
                local shouldRender = true
                local distance = (hrp.Position - hrpLocal.Position).Magnitude

                -- === 1. Pre-Render Checks ===

                -- Max Distance Check
                if distance > settings.MaxDistance then
                    shouldRender = false
                end
                
                -- Team Check
                if settings.TeamCheck and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                    shouldRender = false
                end
                
                -- Visibility Check (Raycasting from the camera to the target's Head)
                local isVisible = true
                if settings.VisibleOnly and shouldRender then
                    local raycastParams = RaycastParams.new()
                    -- Exclude the local player's character and the target's character to allow 'peeking' over walls
                    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
                    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

                    local raycastResult = workspace:Raycast(
                        Camera.CFrame.p, 
                        (head.Position - Camera.CFrame.p).unit * distance, 
                        raycastParams
                    )
                    
                    if raycastResult and raycastResult.Instance then
                        -- If anything is hit, it means the target is blocked by something
                        isVisible = false
                    end
                end

                if settings.VisibleOnly and not isVisible then
                    shouldRender = false
                end


                -- === Hide if checks fail, otherwise proceed ===
                if not shouldRender then
                    HideAllESP()
                    goto continue_loop
                end


                -- 2. Calculate 3D positions and Screen positions
                local headPosition = head.Position
                local footPosition = hrp.Position - Vector3.new(0, settings.FootOffset, 0)
                local headScreenPos, headOnScreen = Camera:WorldToViewportPoint(headPosition)
                local footScreenPos, footOnScreen = Camera:WorldToViewportPoint(footPosition)
                
                if headOnScreen and footOnScreen then
                    
                    -- Calculate dynamic box dimensions
                    local boxHeight = footScreenPos.Y - headScreenPos.Y
                    local boxWidth = boxHeight * settings.WidthRatio

                    -- Calculate Top-Left corner and center
                    local boxX = headScreenPos.X - boxWidth / 2
                    local boxYTop = headScreenPos.Y 
                    local centerX = headScreenPos.X

                    -- === BOX ELEMENTS ===
                    
                    -- Outline (Black)
                    esp.BoxOutline.Position = Vector2.new(boxX - 1, boxYTop - 1)
                    esp.BoxOutline.Size = Vector2.new(boxWidth + 2, boxHeight + 2)
                    esp.BoxOutline.Visible = settings.OutlineEnabled
                    esp.BoxOutline.Color = settings.OutlineColor 

                    -- Filled Box (Transparent)
                    esp.FilledBox.Position = Vector2.new(boxX, boxYTop)
                    esp.FilledBox.Size = Vector2.new(boxWidth, boxHeight)
                    esp.FilledBox.Visible = settings.FillEnabled
                    esp.FilledBox.Color = settings.FillColor 
                    esp.FilledBox.Transparency = settings.FillTransparency 

                    -- Inner box (Main Line Border)
                    esp.Box.Position = Vector2.new(boxX, boxYTop)
                    esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                    esp.Box.Visible = true 
                    esp.Box.Color = settings.BoxColor

                    -- === HEALTH BAR (Left of the box) ===
                    local health = humanoid.Health
                    local maxHealth = humanoid.MaxHealth
                    local healthRatio = health / maxHealth
                    local healthColor = GetHealthColor(health, maxHealth)
                    
                    local barWidth = 4
                    local barSpacing = 3
                    local barX = boxX - barWidth - barSpacing
                    
                    local fillHeight = boxHeight * healthRatio
                    -- Vertical position of the fill is anchored to the bottom of the bar
                    local fillY = boxYTop + (boxHeight - fillHeight) 

                    if settings.HealthEnabled then
                        -- Outline (full size)
                        esp.HealthBarOutline.Position = Vector2.new(barX, boxYTop)
                        esp.HealthBarOutline.Size = Vector2.new(barWidth, boxHeight)
                        esp.HealthBarOutline.Visible = true
                        
                        -- Fill (dynamic size)
                        esp.HealthBarFill.Position = Vector2.new(barX, fillY)
                        esp.HealthBarFill.Size = Vector2.new(barWidth, fillHeight)
                        esp.HealthBarFill.Color = healthColor
                        esp.HealthBarFill.Visible = true
                    else
                        esp.HealthBarOutline.Visible = false
                        esp.HealthBarFill.Visible = false
                    end

                    -- === NAME & TOOL TEXT ===

                    -- Name (Top Center)
                    esp.Name.Text = player.Name
                    esp.Name.Position = Vector2.new(centerX, boxYTop - 16)
                    esp.Name.Visible = settings.NameEnabled

                    -- Tool (Bottom Center - uses original tool logic)
                    local toolName = tool and '[' .. tool.Name .. ']' or ''
                    esp.Tool.Text = toolName
                    esp.Tool.Position = Vector2.new(centerX, footScreenPos.Y + 3)
                    esp.Tool.Visible = (tool ~= nil)
                    
                    -- === DISTANCE TEXT (Bottom Right of the box) ===
                    if settings.DistanceEnabled then
                        local distanceText = string.format("%.0f m", distance)
                        esp.Distance.Text = distanceText
                        -- Positioned to the right of the box
                        esp.Distance.Position = Vector2.new(boxX + boxWidth + 5, boxYTop + boxHeight - 16)
                        esp.Distance.Visible = true
                    else
                        esp.Distance.Visible = false
                    end


                    -- === NEW FEATURE LOGIC ===

                    -- SKELETON DRAWING
                    if settings.SkeletonEnabled then
                        for i, pair in ipairs(SKELETON_MAP) do
                            local partA = char:FindFirstChild(pair[1])
                            local partB = char:FindFirstChild(pair[2])
                            
                            if partA and partB and esp.Skeleton[i] then
                                local posA, onScreenA = Camera:WorldToViewportPoint(partA.CFrame.p)
                                local posB, onScreenB = Camera:WorldToViewportPoint(partB.CFrame.p)

                                if onScreenA and onScreenB then
                                    esp.Skeleton[i].Visible = true
                                    esp.Skeleton[i].From = Vector2.new(posA.X, posA.Y)
                                    esp.Skeleton[i].To = Vector2.new(posB.X, posB.Y)
                                    -- Color and Thickness are set during CreateESP but can be changed here if needed
                                else
                                    esp.Skeleton[i].Visible = false
                                end
                            elseif esp.Skeleton[i] then
                                esp.Skeleton[i].Visible = false
                            end
                        end
                    else
                        -- Hide all skeleton lines if feature is disabled
                        for _, line in pairs(esp.Skeleton) do
                            line.Visible = false
                        end
                    end


                    -- VIEWLINE DRAWING (from Head to the point 100 studs in front of the Head)
                    if settings.ViewlineEnabled and head then
                        -- Project 100 studs forward from the head's look direction
                        local targetPosition = head.CFrame.p + head.CFrame.LookVector * 100 
                        
                        local targetScreenPos, targetOnScreen = Camera:WorldToViewportPoint(targetPosition)
                        
                        if targetOnScreen then -- Only check the target point, Head is already on screen (headOnScreen is true)
                            esp.Viewline.Visible = true
                            esp.Viewline.From = Vector2.new(headScreenPos.X, headScreenPos.Y)
                            esp.Viewline.To = Vector2.new(targetScreenPos.X, targetScreenPos.Y)
                        else
                            esp.Viewline.Visible = false
                        end
                    else
                        esp.Viewline.Visible = false
                    end


                    -- WEAPON TRACER DRAWING (Line from HRP to Tool Handle)
                    if settings.WeaponEnabled and hrp and tool then
                        local toolHandle = tool:FindFirstChild("Handle")
                        if toolHandle then
                            local hrpScreenPos, hrpOnScreen = Camera:WorldToViewportPoint(hrp.CFrame.p)
                            local toolScreenPos, toolOnScreen = Camera:WorldToViewportPoint(toolHandle.CFrame.p)

                            if hrpOnScreen and toolScreenPos then
                                esp.WeaponTracer.Visible = true
                                esp.WeaponTracer.From = Vector2.new(hrpScreenPos.X, hrpScreenPos.Y)
                                esp.WeaponTracer.To = Vector2.new(toolScreenPos.X, toolScreenPos.Y)
                            else
                                esp.WeaponTracer.Visible = false
                            end
                        else
                            esp.WeaponTracer.Visible = false
                        end
                    else
                        esp.WeaponTracer.Visible = false
                    end
                    -- === END NEW FEATURE LOGIC ===


                else
                    -- Player off screen: Hide all
                    HideAllESP()
                end
            else
                -- Character or necessary parts missing: Hide all
                HideAllESP()
            end

            ::continue_loop::
        elseif ESPObjects[player] then
            -- Player missing or not targetable: Hide all
            HideAllESP()
        end
    end
end

--// --- Global Toggle Functions ---

local function StartESP()
    if not RenderStepConnection then
        RenderStepConnection = RunService.RenderStepped:Connect(UpdateESP)
        getgenv().ESPSettings.Enabled = true
    end
end

local function StopESP()
    if RenderStepConnection then
        RenderStepConnection:Disconnect()
        RenderStepConnection = nil
        getgenv().ESPSettings.Enabled = false
    end
    HideAllESP()
end

-- Global function to toggle the ESP state
getgenv().ToggleESP = function(enabled)
    if enabled == true then
        StartESP()
    elseif enabled == false then
        StopESP()
    else
        -- Toggle the current state if no argument is provided
        if getgenv().ESPSettings.Enabled then
            StopESP()
        else
            StartESP()
        end
    end
end

-- Initial setup: Check the starting state from settings
if getgenv().ESPSettings.Enabled then
    StartESP()
end

-- Ensure cleanup when players leave
Players.PlayerRemoving:Connect(RemoveESP)
