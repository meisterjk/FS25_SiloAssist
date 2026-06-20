--====================================================================
-- SiloAssist - 3D Drawing Manager (i3D-based, no drawDebugLine)
-- Uses sphere_small.i3d, sphere.i3d, line.i3d with lineShader.xml
-- for efficient 3D rendering of debug markers and lines.
-- Based on AutoDrive's DrawingManager approach (simplified).
--====================================================================

siloAssistDrawing = {}

siloAssistDrawing.MOD_DIR = ""   -- set in load()

siloAssistDrawing.DRAW_DIR = "drawing/"

siloAssistDrawing.EMITTIVITY_UPDATE_FRAMES = 300

siloAssistDrawing.MAX_SMALL_SPHERES = 600
siloAssistDrawing.MAX_SPHERES = 20
siloAssistDrawing.MAX_LINES = 600

---------------------------------------------------------------------
-- Object type definitions
---------------------------------------------------------------------
siloAssistDrawing.objTypes = {
    smallSphere = {
        fileName = "sphere_small.i3d",
        currentTask = 0,
        lastTaskCount = 0,
        tasks = {},
        itemIDs = {},
        loaded = false,
    },
    sphere = {
        fileName = "sphere.i3d",
        currentTask = 0,
        lastTaskCount = 0,
        tasks = {},
        itemIDs = {},
        loaded = false,
    },
    line = {
        fileName = "line.i3d",
        currentTask = 0,
        lastTaskCount = 0,
        tasks = {},
        itemIDs = {},
        loaded = false,
    },
}

siloAssistDrawing.emittivity = 0.5
siloAssistDrawing.emittivityNextUpdate = 0

---------------------------------------------------------------------
-- Initialize a loaded i3D node: extract child, link to root, hide
---------------------------------------------------------------------
function siloAssistDrawing.initNode(id)
    local itemId = getChildAt(id, 0)
    link(getRootNode(), itemId)
    setRigidBodyType(itemId, RigidBodyType.NONE)
    setTranslation(itemId, 0, -100, 0)
    setVisibility(itemId, false)
    delete(id)
    return itemId
end

---------------------------------------------------------------------
-- Load i3D files (call once at mod load)
---------------------------------------------------------------------
function siloAssistDrawing.load()
    siloAssistDrawing.MOD_DIR = siloAssist.modDirectory
    if siloAssistDrawing.MOD_DIR == nil or siloAssistDrawing.MOD_DIR == "" then
        return
    end
    local drawDir = siloAssistDrawing.MOD_DIR .. siloAssistDrawing.DRAW_DIR

    for typeName, obj in pairs(siloAssistDrawing.objTypes) do
        local filePath = drawDir .. obj.fileName
        local id = g_i3DManager:loadSharedI3DFile(filePath, false, false)
        if id ~= nil and id ~= 0 then
            local itemId = siloAssistDrawing.initNode(id)
            setVisibility(itemId, false)
            table.insert(obj.itemIDs, itemId)
            obj.loaded = true
        else
            siloAssistDebug.log("Drawing", "Failed to preload: " .. filePath)
        end
    end
end

---------------------------------------------------------------------
-- Unload all i3D nodes (call at mod unload)
---------------------------------------------------------------------
function siloAssistDrawing.unload()
    for typeName, obj in pairs(siloAssistDrawing.objTypes) do
        for _, itemId in ipairs(obj.itemIDs) do
            if itemId ~= nil and entityExists(itemId) then
                setVisibility(itemId, false)
                unlink(itemId)
                delete(itemId)
            end
        end
        obj.itemIDs = {}
        obj.tasks = {}
        obj.currentTask = 0
        obj.lastTaskCount = 0
        obj.loaded = false
    end
end

---------------------------------------------------------------------
-- Reset task counter (call at START of each frame, before addXxx)
---------------------------------------------------------------------
function siloAssistDrawing.reset()
    for typeName, obj in pairs(siloAssistDrawing.objTypes) do
        obj.currentTask = 0
    end
end

---------------------------------------------------------------------
-- Add tasks (call between reset() and draw())
---------------------------------------------------------------------
function siloAssistDrawing:addSmallSphere(x, y, z, r, g, b)
    local obj = siloAssistDrawing.objTypes.smallSphere
    obj.currentTask = obj.currentTask + 1
    if obj.currentTask > siloAssistDrawing.MAX_SMALL_SPHERES then
        return
    end
    local task = obj.tasks[obj.currentTask]
    if task == nil then
        task = { taskChanged = true }
        obj.tasks[obj.currentTask] = task
    end
    if task.x ~= x or task.y ~= y or task.z ~= z or task.r ~= r or task.g ~= g or task.b ~= b then
        task.x = x
        task.y = y
        task.z = z
        task.r = r
        task.g = g
        task.b = b
        task.taskChanged = true
    end
end

function siloAssistDrawing:addSphere(x, y, z, scale, r, g, b, a)
    local obj = siloAssistDrawing.objTypes.sphere
    a = a or 1
    obj.currentTask = obj.currentTask + 1
    if obj.currentTask > siloAssistDrawing.MAX_SPHERES then
        return
    end
    local task = obj.tasks[obj.currentTask]
    if task == nil then
        task = { taskChanged = true }
        obj.tasks[obj.currentTask] = task
    end
    if task.x ~= x or task.y ~= y or task.z ~= z
        or task.scale ~= scale or task.r ~= r or task.g ~= g
        or task.b ~= b or task.a ~= a then
        task.x = x
        task.y = y
        task.z = z
        task.scale = scale
        task.r = r
        task.g = g
        task.b = b
        task.a = a
        task.taskChanged = true
    end
end

function siloAssistDrawing:addLine(sx, sy, sz, ex, ey, ez, r, g, b, scale)
    local obj = siloAssistDrawing.objTypes.line
    scale = scale or 1
    obj.currentTask = obj.currentTask + 1
    if obj.currentTask > siloAssistDrawing.MAX_LINES then
        return
    end
    local task = obj.tasks[obj.currentTask]
    if task == nil then
        task = { taskChanged = true }
        obj.tasks[obj.currentTask] = task
    end
    if task.sx ~= sx or task.sy ~= sy or task.sz ~= sz
        or task.ex ~= ex or task.ey ~= ey or task.ez ~= ez
        or task.scale ~= scale or task.r ~= r or task.g ~= g or task.b ~= b then
        task.sx = sx
        task.sy = sy
        task.sz = sz
        task.ex = ex
        task.ey = ey
        task.ez = ez
        task.scale = scale
        task.r = r
        task.g = g
        task.b = b
        task.taskChanged = true
    end
end

---------------------------------------------------------------------
-- Draw all objects (call each frame after addXxx calls)
---------------------------------------------------------------------
function siloAssistDrawing.draw()
    if siloAssistDrawing.MOD_DIR == nil or siloAssistDrawing.MOD_DIR == "" then
        return
    end
    -- Update emittivity periodically
    siloAssistDrawing.emittivityNextUpdate = siloAssistDrawing.emittivityNextUpdate - 1
    if siloAssistDrawing.emittivityNextUpdate <= 0 then
        local r, g, b = 1, 1, 1
        local light = (r + g + b) / 3
        siloAssistDrawing.emittivity = math.max(0, 1 - light)
        if siloAssistDrawing.emittivity > 0.9 then
            siloAssistDrawing.emittivity = siloAssistDrawing.emittivity * 0.5
        end
        siloAssistDrawing.emittivityNextUpdate = siloAssistDrawing.EMITTIVITY_UPDATE_FRAMES
    end

    siloAssistDrawing:drawObjects(siloAssistDrawing.objTypes.smallSphere, siloAssistDrawing.drawSmallSphere, siloAssistDrawing.initNode)
    siloAssistDrawing:drawObjects(siloAssistDrawing.objTypes.sphere, siloAssistDrawing.drawSphere, siloAssistDrawing.initNode)
    siloAssistDrawing:drawObjects(siloAssistDrawing.objTypes.line, siloAssistDrawing.drawLine, siloAssistDrawing.initNode)
end

---------------------------------------------------------------------
-- Generic draw dispatcher (handles pool management)
---------------------------------------------------------------------
function siloAssistDrawing:drawObjects(obj, dFunc, iFunc)
    if obj.currentTask == 0 then
        if obj.lastTaskCount > 0 then
            for i = 1, obj.lastTaskCount do
                if obj.itemIDs[i] ~= nil then
                    setVisibility(obj.itemIDs[i], false)
                end
            end
        end
        obj.lastTaskCount = 0
        return
    end

    -- Ensure enough i3D nodes in pool
    if obj.currentTask > #obj.itemIDs then
        local drawDir = siloAssistDrawing.MOD_DIR .. siloAssistDrawing.DRAW_DIR
        local filePath = drawDir .. obj.fileName
        for i = #obj.itemIDs + 1, obj.currentTask do
            local id = g_i3DManager:loadSharedI3DFile(filePath, false, false)
            if id ~= nil and id ~= 0 then
                local itemId = iFunc(id)
                table.insert(obj.itemIDs, itemId)
            else
                siloAssistDebug.log("Drawing", "Failed to load: " .. filePath)
                break
            end
        end
    end

    -- Manage visibility: hide unused, show new
    if obj.currentTask < obj.lastTaskCount then
        for i = obj.currentTask + 1, obj.lastTaskCount do
            if obj.itemIDs[i] ~= nil then
                setVisibility(obj.itemIDs[i], false)
            end
        end
    elseif obj.currentTask > obj.lastTaskCount then
        for i = obj.lastTaskCount + 1, obj.currentTask do
            if obj.itemIDs[i] ~= nil then
                setVisibility(obj.itemIDs[i], true)
            end
        end
    end

    -- Draw changed tasks only
    for i = 1, obj.currentTask do
        local task = obj.tasks[i]
        if task ~= nil and task.taskChanged and obj.itemIDs[i] ~= nil then
            dFunc(siloAssistDrawing, obj.itemIDs[i], task)
            task.taskChanged = false
        end
    end

    obj.lastTaskCount = obj.currentTask
end

---------------------------------------------------------------------
-- Draw functions for each object type
---------------------------------------------------------------------
function siloAssistDrawing:drawSmallSphere(id, task)
    setTranslation(id, task.x, task.y, task.z)
    setVisibility(id, true)
    setShaderParameter(id, "lineColor", task.r, task.g, task.b, siloAssistDrawing.emittivity, false)
end

function siloAssistDrawing:drawSphere(id, task)
    setTranslation(id, task.x, task.y, task.z)
    setScale(id, task.scale, task.scale, task.scale)
    setVisibility(id, true)
    setShaderParameter(id, "lineColor", task.r, task.g, task.b, siloAssistDrawing.emittivity + task.a, false)
end

function siloAssistDrawing:drawLine(id, task)
    local dirX, _, dirZ = task.ex - task.sx, task.ey - task.sy, task.ez - task.sz
    local dist2D = MathUtil.vector2Length(dirX, dirZ)
    local dist3D = MathUtil.vector3Length(dirX, task.ey - task.sy, dirZ)

    if dist3D < 0.001 then
        setVisibility(id, false)
        return
    end

    local rotY = math.atan2(dirX, dirZ)
    local dy = task.ey - task.sy
    local rotX = -math.atan2(dy, dist2D + 0.0001)

    setTranslation(id, task.sx, task.sy, task.sz)
    setScale(id, task.scale, task.scale, dist3D)
    setRotation(id, rotX, rotY, 0)
    setShaderParameter(id, "lineColor", task.r, task.g, task.b, siloAssistDrawing.emittivity, false)
    setVisibility(id, true)
end