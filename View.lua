getgenv().Settings = {
    -- IMPORTANT: You must manually change this value to 'true' or 'false'
    -- outside of this script's execution to toggle the zoom.
    IsZooming = false,          -- Set to 'true' for 30 FOV, 'false' for 120 FOV

    -- === FOV Values ===
    DesiredFOV = 120,           -- Wide FOV when IsZooming is false
    ZoomFOV = 30,               -- Tight FOV when IsZooming is true
}

local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')

local Settings = getgenv().Settings

-- --- CORE CAMERA LOGIC ---

local function UpdateFOV()
    local camera = Workspace.CurrentCamera
    
    if camera and camera:IsA("Camera") then
        
        -- Check the state of the IsZooming variable to determine the FOV
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
    
    -- Connect the update function to run every frame (RenderStepped)
    -- This ensures the FOV stays enforced based on the IsZooming state.
    RunService.RenderStepped:Connect(UpdateFOV)
    print("FOV Enforcer initialized. FOV is being set based on getgenv().Settings.IsZooming.")
end

Initialize()
