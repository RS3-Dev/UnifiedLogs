-- Render models for one trophy view
local TrophyModels = require("Resources/Features/bosses/trophies/trophy_models")
local TrophyModelPreview = {}
local MODEL_INSET = 20
local MODEL_LABEL_HEIGHT = 74
local MODEL_DISTANCE = 500
local MODEL_PART_LIMIT = 3

function TrophyModelPreview.Create(self)
    local modelHeight = math.max(80, self.bodyHeight - (self.modelLabelHeight or MODEL_LABEL_HEIGHT) - MODEL_INSET * 2)
    self.modelGroup = ui.ModelGroup.new(self.root)
    self.modelBaseX = self.previewX + MODEL_INSET
    self.modelBaseY = self.bodyY + MODEL_INSET
    self.modelWidth = self.previewWidth - MODEL_INSET * 2
    self.modelHeight = modelHeight
    self.modelGroup:SetPos(self.modelBaseX, self.modelBaseY)
    self.modelGroup:SetSize(self.modelWidth, self.modelHeight)
    self.modelGroup.clickthrough = true
    self.modelGroup.hidden = true

    self.modelCamera = ui.ModelCameraInfo.new()
    self.modelCamera:SetFOV(90.0, 0)
    self.modelCamera:SetPosition(Vector3.new(0.0, 0.0, -MODEL_DISTANCE), 0)
    self.modelCamera:SetLookAt(Vector3.new(0.0, 0.0, 0.0), 0)
    self.modelCamera.clearColour = Vector4.new(0.0, 0.0, 0.0, 0.0)
    self.modelCamera.useLookAt = true
    self.modelCameraID = self.modelGroup:AddCamera(self.modelCamera)
    self.modelGroup:SwitchCamera(self.modelCameraID, ui.ModelCameraTransition.NONE, -1, 0)

    self.modelParts = {}
    for partIndex = 1, MODEL_PART_LIMIT do
        local part = ui.Model.new(self.modelGroup)
        part:SetPos(0, 0)
        part:SetSize(self.modelWidth, self.modelHeight)
        part.rgb = 0xFFFFFF
        part.alpha = 255
        part.clickthrough = true
        part.hidden = true
        self.modelParts[partIndex] = part
    end
end

-- Get the selected trophy transform
function TrophyModelPreview.TransformFor(self, index)
    local entry = self.entries[index]
    if entry == nil then return nil end
    local key = tostring(entry.objectConfig or entry.modelConfig or entry.label or index)
    local transform = self.modelTransforms[key]
    if transform == nil then
        -- Copy the preset so camera adjustments stay in this view
        transform =
            { x = 0, y = 0, z = 0, yaw = -90, pitch = 0, roll = 0, distance = MODEL_DISTANCE }
        for field, value in pairs(entry.transform or {}) do
            transform[field] = value
        end
        self.modelTransforms[key] = transform
    end
    return transform
end

function TrophyModelPreview.ApplyModelTransform(self, index)
    local transform = self:TransformFor(index)
    local entry = self.entries[index]
    if self.modelGroup == nil or transform == nil then return end
    local ok, cameraX, cameraY, cameraZ = pcall(function()
        self.modelGroup:SetPos(self.modelBaseX, self.modelBaseY)
        for partIndex, part in ipairs(self.modelParts or {}) do
            local modelYaw = entry ~= nil
                    and entry.selfMounted == true
                    and partIndex == 1
                    and tonumber(entry.modelYaw)
                or 0
            part:SetTransform(
                Vector3.new(0.0, 0.0, 0.0),
                Vector3.new(0.0, math.rad(modelYaw or 0), 0.0),
                Vector3.new(1.0, 1.0, 1.0),
                0
            )
        end

        local targetX = transform.x
        local targetY = transform.y
        local targetZ = transform.z
        local displayYaw = self.autoRotation:DisplayYaw(transform.yaw)
        local orbitYaw = math.rad(displayYaw)
        local orbitPitch = math.rad(transform.pitch)
        local distance = transform.distance
        local pitchRadius = math.cos(orbitPitch) * distance
        local cameraX = targetX - math.sin(orbitYaw) * pitchRadius
        local cameraY = targetY + math.sin(orbitPitch) * distance
        local cameraZ = targetZ - math.cos(orbitYaw) * pitchRadius

        local camera = ui.ModelCameraInfo.new()
        camera:SetFOV(90.0, 0)
        camera:SetPosition(Vector3.new(cameraX, cameraY, cameraZ), 0)
        camera:SetLookAt(Vector3.new(targetX, targetY, targetZ), 0)
        camera:SetYawPitchRoll(Vector3.new(0.0, 0.0, math.rad(transform.roll)), 0)
        camera.clearColour = Vector4.new(0.0, 0.0, 0.0, 0.0)
        camera.useLookAt = true

        if self.modelCameraID ~= nil then self.modelGroup:DeleteCamera(self.modelCameraID) end
        self.modelCamera = camera
        self.modelCameraID = self.modelGroup:AddCamera(camera)
        self.modelGroup:SwitchCamera(self.modelCameraID, ui.ModelCameraTransition.NONE, -1, 0)
        return cameraX, cameraY, cameraZ
    end)
    if ok then return transform, cameraX, cameraY, cameraZ end
end

function TrophyModelPreview.SetPreviewModel(self, entry, index)
    if self.modelGroup == nil or entry == nil then return false end

    local modelIDs = TrophyModels.MountedPreviewModels(entry)
    if #modelIDs > 0 then
        local ok = pcall(function()
            for partIndex, part in ipairs(self.modelParts) do
                local modelID = modelIDs[partIndex]
                if modelID ~= nil then
                    part:SetModel(ui.ModelType.MODEL, modelID)
                    part:ResetEnvironment()
                    -- Skip POH effects that emit continuous particles
                    part.animID = -1
                    part.rgb = 0xFFFFFF
                    part.alpha = 255
                    part.hidden = false
                else
                    part.hidden = true
                end
            end
            self.modelGroup.hidden = false
            self:ApplyModelTransform(index)
            self.modelGroup:MoveToFront()
        end)
        if ok then return true end
    end

    local modelType, runtimeID
    local dedicatedModelID = TrophyModels.ConfiguredModelID(entry)
    if dedicatedModelID ~= nil then
        modelType = ui.ModelType.MODEL
        runtimeID = dedicatedModelID
    else
        local object = self:ResolveObject(index)
        runtimeID = TrophyModels.ReadNumber(object, "id")
        if runtimeID ~= nil then modelType = ui.ModelType.OBJECT end
    end
    if modelType == nil or runtimeID == nil then return false end

    local ok = pcall(function()
        local primary = self.modelParts[1]
        primary:SetModel(modelType, runtimeID)
        primary:ResetEnvironment()
        primary.animID = -1
        primary.rgb = 0xFFFFFF
        primary.alpha = 255
        primary.hidden = false
        for partIndex = 2, #self.modelParts do
            self.modelParts[partIndex].hidden = true
        end
        self.modelGroup.hidden = false
        self:ApplyModelTransform(index)
        self.modelGroup:MoveToFront()
    end)
    return ok
end

return TrophyModelPreview
