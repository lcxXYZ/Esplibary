getgenv().Settings = {
    -- Your UI should set this value to 'true' or 'false'
    IsZooming = false, 	 	 	 	-- Current state (False = Wide FOV, True = Zoom FOV)

    -- === FOV Values ===
    DesiredFOV = 120,	 	 	 	-- Wide FOV when IsZooming is false
    ZoomFOV = 30,	 	 	 	 	-- Tight FOV when IsZooming is true
}

local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')

local Settings = getgenv().Settings

-- --- CORE CAMERA LOGIC ---

local function UpdateFOV()
    local camera = Workspace.CurrentCamera
    
    -- Ensure the camera object exists before trying to access its properties
    if camera and camera:IsA("Camera") then
        
        -- Determine the target FOV based on the current state of IsZooming
        local targetFOV
        if Settings.IsZooming then
            targetFOV = Settings.ZoomFOV  -- 30
        else
            targetFOV = Settings.DesiredFOV -- 120
        end
        
        -- Apply the selected FOV to the camera
        camera.FieldOfView = targetFOV
    end
end

-- --- MAIN EXECUTOR ---

local function Initialize()
    
    -- Connect the update function to run every frame (RenderStepped).
    -- This is essential because it constantly reads the 'IsZooming' state 
    -- set by your UI and applies the corresponding FOV instantly.
    RunService.RenderStepped:Connect(UpdateFOV)
    
    print("FOV Enforcer initialized and linked to getgenv().Settings.IsZooming.")
end

Initialize()
