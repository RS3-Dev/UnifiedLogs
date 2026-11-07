-- Render completion cape models
local CapeModelCanvas = {}

local NATIVE_VIEW_DISTANCE = 900
local DEFAULT_SCALE = 1.25
local CAMERA_FOV = 90

local function applyFrontLighting(model)
    local environment = ui.ModelEnvironment.new()
    environment.ambient = 2.0
    environment.contrast = 2.5
    environment.bloomScale = 1
    environment.anticontrast = 0
    environment.minAutoExposure = 0
    environment.maxAutoExposure = 1
    environment.exposureKey = 1
    environment.shadowBias = -0.0135
    environment.envMapID = -1
    environment.sunDirection = Vector3.new(0, 0, -1)
    environment.sunRGB = Vector3.new(1, 1, 1)
    local applied = pcall(
        model.SetLighting,
        model,
        environment.ambient,
        environment.contrast,
        environment.anticontrast,
        environment.sunRGB,
        environment.sunDirection,
        environment.envMapID
    )
    if not applied then model:ResetEnvironment() end
    return environment, applied
end

function CapeModelCanvas.Create(parent, cape, options)
    options = options or {}
    local modelID = tonumber(cape.modelID)
    if
        modelID == nil
        or ui == nil
        or ui.Model == nil
        or ui.ModelGroup == nil
        or ui.ModelCameraInfo == nil
        or ui.ModelEnvironment == nil
        or ui.ModelType == nil
    then
        return nil
    end

    local canvas, group
    local ok = pcall(function()
        group = ui.ModelGroup.new(parent)
        group:SetPos(options.x or 0, options.y or 0)
        group:SetSize(options.width, options.height)
        group.clickthrough = true

        local model = ui.Model.new(group)
        model:SetPos(0, 0)
        model:SetSize(options.width, options.height)
        model:SetModel(ui.ModelType.MODEL, modelID)
        local lightingEnvironment, lightingApplied = applyFrontLighting(model)
        model:SetTransform(
            Vector3.new(0, 0, 0),
            Vector3.new(math.pi, 0, 0),
            Vector3.new(1, 1, 1),
            0
        )
        model.animID = -1
        model.rgb = 0xFFFFFF
        model.alpha = 255
        model.clickthrough = true

        local distance =
            math.floor(NATIVE_VIEW_DISTANCE / (tonumber(options.scale) or DEFAULT_SCALE) + 0.5)
        local targetY = (tonumber(options.verticalShift) or 0)
            * 2
            * distance
            / math.max(1, tonumber(options.height) or 1)
        local camera = ui.ModelCameraInfo.new()
        camera:SetFOV(CAMERA_FOV, 0)
        camera:SetPosition(Vector3.new(0, targetY, -distance), 0)
        camera:SetLookAt(Vector3.new(0, targetY, 0), 0)
        camera.clearColour = Vector4.new(0, 0, 0, 0)
        camera.useLookAt = true
        local cameraID = group:AddCamera(camera)
        group:SwitchCamera(cameraID, ui.ModelCameraTransition.NONE, -1, 0)

        canvas = {
            group = group,
            model = model,
            modelID = modelID,
            camera = camera,
            cameraID = cameraID,
            targetY = targetY,
            lightingEnvironment = lightingEnvironment,
            lightingApplied = lightingApplied,
        }
    end)
    if not ok and group ~= nil then group.hidden = true end
    return ok and canvas or nil
end

return CapeModelCanvas
