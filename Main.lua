--[[
    S I M P L E E S P E X E C U T O R
    
    This script provides a basic ESP (Box, Health, Name, Distance, Equipped Item) 
    using Drawing objects.
    
    -- UPDATES --
    1. Ensured health bar rendering logic is robust.
    2. Added dedicated Equipped Item ESP (ItemNameEnabled).
    3. All features are enabled by default.
]]

--// Configuration and Control (Accessible via getgenv())
getgenv().ESPSettings = {
    -- === GLOBAL CONTROL ===
    Enabled = true, 

    -- === FEATURE TOGGLES (Set to true/false) ===
    FillEnabled = true,      
    OutlineEnabled = true,   
    HealthEnabled = true,    -- Enable/Disable the health bar
    NameEnabled = true,      -- Enable/Disable the player name text
    DistanceEnabled = true,  -- Enable/Disable the distance display
    EquippedItemEnabled = true, -- NEW: Enable/Disable the equipped item name display

    -- === COLORS AND THICKNESS ===
    BoxColor = Color3.fromRGB(255, 255, 255), -- Main line/border color (White)
    FillColor = Color3.fromRGB(0, 0, 0),     -- Color of the transparent background fill (Black)
    OutlineColor = Color3.fromRGB(0, 0, 0), -- Color of the outer edge/outline (Black)
    
    BoxThickness = 1,
    OutlineThickness = 1.5,
    FillTransparency = 0.5, -- 0 is opaque, 1 is fully transparent

    -- === TEXT SETTINGS ===
    NameColor = Color3.fromRGB(255, 255, 255),
    EquippedItemColor = Color3.fromRGB(170, 0, 255), -- Color for the equipped item name
    Font = Drawing.Fonts.Plex,

    -- === DIMENSION AND SHIFT SETTINGS ===
    FootOffset = 5,
    WidthRatio = 1,
    BoxVerticalShiftPixels = 20, -- Positive value moves the entire box up (in screen pixels)
}

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local ESPObjects = {}
local RenderStepConnection = nil -- Stores the connection for the main loop

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
    esp.HealthBarFill.Transparency = 0 -- Should be opaque

    -- 6. Name tag
    esp.Name = Drawing.new('Text')
    esp.Name.Size = 14
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Font = settings.Font
    esp.Name.Color = settings.NameColor

    -- 7. Equipped Item tag (Formerly esp.Tool)
    esp.EquippedItem = Drawing.new('Text')
    esp.EquippedItem.Size = 14
    esp.EquippedItem.Center = true
    esp.EquippedItem.Outline = true
    esp.EquippedItem.Font = settings.Font
    esp.EquippedItem.Color = settings.EquippedItemColor
    
    -- 8. Distance Text
    esp.Distance = Drawing.new('Text')
    esp.Distance.Size = 13
    esp.Distance.Center = false
    esp.Distance.Outline = true
    esp.Distance.Font = settings.Font
    esp.Distance.Color = Color3.fromRGB(255, 255, 255)
    
    -- Ensure everything starts hidden
    for _, obj in pairs(esp) do
        obj.Visible = false
    end

    return esp
end

--// Cleanup function to remove all drawings for a single player
local function RemoveESP(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            obj:Remove()
        end
        ESPObjects[player] = nil
    end
end

--// Function to hide all active ESP drawings
local function HideAllESP()
    for _, esp in pairs(ESPObjects) do
        for _, obj in pairs(esp) do
            obj.Visible = false
        end
    end
end

--// Main rendering loop (Update function)
local function UpdateESP()
    local settings = getgenv().ESPSettings
    local shift = settings.BoxVerticalShiftPixels or 0
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
            -- Check for an equipped tool (subclass of Tool)
            local tool = player.Character:FindFirstChildOfClass('Tool')

            if hrp and head and humanoid and hrpLocal then
                
                -- 1. Calculate 3D positions and Screen positions
                local headPosition = head.Position
                local footPosition = hrp.Position - Vector3.new(0, settings.FootOffset, 0)
                local headScreenPos, headOnScreen = Camera:WorldToViewportPoint(headPosition)
                local footScreenPos, footOnScreen = Camera:WorldToViewportPoint(footPosition)
                local distance = (hrp.Position - hrpLocal.Position).Magnitude

                if headOnScreen and footOnScreen then
                    
                    -- Apply the vertical shift (Y decreases to move UP)
                    local boxYTop = headScreenPos.Y - shift
                    local boxYBottom = footScreenPos.Y - shift

                    -- Calculate dynamic box dimensions
                    local boxHeight = boxYBottom - boxYTop
                    local boxWidth = boxHeight * settings.WidthRatio

                    -- Calculate Top-Left corner and center
                    local boxX = headScreenPos.X - boxWidth / 2
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
                    local isHealthVisible = settings.HealthEnabled and (maxHealth > 0)
                    
                    local barWidth = 4
                    local barSpacing = 3
                    local barX = boxX - barWidth - barSpacing

                    if isHealthVisible then
                        local healthRatio = health / maxHealth
                        local healthColor = GetHealthColor(health, maxHealth)
                        local fillHeight = boxHeight * healthRatio
                        -- Vertical position of the fill is anchored to the bottom of the bar
                        local fillY = boxYTop + (boxHeight - fillHeight) 

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

                    -- === NAME TEXT (Top Center) ===
                    esp.Name.Text = player.Name
                    esp.Name.Position = Vector2.new(centerX, boxYTop - 16) -- Positioned relative to the shifted box top
                    esp.Name.Visible = settings.NameEnabled

                    -- === EQUIPPED ITEM TEXT (Bottom Center) ===
                    local equippedItemName = tool and '[' .. tool.Name .. ']' or ''
                    
                    if settings.EquippedItemEnabled and tool then
                        esp.EquippedItem.Text = equippedItemName
                        -- Positioned below the distance text/box bottom (using a fixed offset)
                        esp.EquippedItem.Position = Vector2.new(centerX, boxYBottom + 16) 
                        esp.EquippedItem.Visible = true
                    else
                        esp.EquippedItem.Visible = false
                    end
                    
                    -- === DISTANCE TEXT (Bottom Right of the box) ===
                    if settings.DistanceEnabled then
                        local distanceText = string.format("%.0f m", distance)
                        esp.Distance.Text = distanceText
                        -- Positioned relative to the shifted box
                        esp.Distance.Position = Vector2.new(boxX + boxWidth + 5, boxYTop + boxHeight - 16)
                        esp.Distance.Visible = true
                    else
                        esp.Distance.Visible = false
                    end

                else
                    -- Player off screen: Hide all
                    for _, obj in pairs(esp) do
                        obj.Visible = false
                    end
                end
            else
                -- Character or necessary parts missing: Hide all
                if ESPObjects[player] then
                    for _, obj in pairs(esp) do
                        obj.Visible = false
                    end
                end
            end
        elseif ESPObjects[player] then
            -- Player missing or not targetable: Hide all
            RemoveESP(player) -- Use the cleaner remove function
        end
    end
end

--// --- Global Toggle Functions ---

local function StartESP()
    if not RenderStepConnection then
        RenderStepConnection = RunService.RenderStepped:Connect(UpdateESP)
        getgenv().ESPSettings.Enabled = true
        print("ESP Started and Active.")
    end
end

local function StopESP()
    if RenderStepConnection then
        RenderStepConnection:Disconnect()
        RenderStepConnection = nil
        getgenv().ESPSettings.Enabled = false
        print("ESP Stopped.")
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
