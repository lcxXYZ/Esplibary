getgenv().FOVSettings = {
    DesiredFOV = 120, 
    ZoomFOV = 30, 
    IsZooming = false, 
}

local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')

local Settings = getgenv().FOVSettings

local function UpdateFOV()
    local camera = Workspace.CurrentCamera
    
    if camera then
        if Settings.IsZooming then
            camera.FieldOfView = Settings.ZoomFOV
        else
            camera.FieldOfView = Settings.DesiredFOV
        end
    end
end

local function StartFOVChanger()
    RunService.RenderStepped:Connect(UpdateFOV)
end

getgenv().ToggleZoom = function()
    Settings.IsZooming = not Settings.IsZooming
end

StartFOVChanger()
