-- scenes/levelSelect.lua
local composer  = require("composer")
local data      = require("modules.data")
local save      = require("modules.save")
local uiButton  = require("modules.uiButton")
local THEME     = require("modules.theme")

local scene = composer.newScene()

local currentLevelIndex = 1
local levelDisplayGroup = nil
local levelNameText     = nil
local levelNumberText   = nil
local levelStatusText   = nil
local rootGroup         = nil
local levels            = data.levels

local VW, VH, VCX, VCY

local function parseLevel(levelData)
    local map = levelData.map
    local rows, cols = #map, #map[1]
    local walls, targets, boxes = {}, {}, {}
    local playerPos = nil

    for y = 1, rows do
        for x = 1, cols do
            local ch = map[y]:sub(x, x)
            if     ch == '#' then walls[#walls + 1]     = {x=x, y=y}
            elseif ch == '.' then targets[#targets + 1] = {x=x, y=y}
            elseif ch == '$' then boxes[#boxes + 1]     = {x=x, y=y}
            elseif ch == '@' then playerPos             = {x=x, y=y}
            elseif ch == '*' then
                targets[#targets + 1] = {x=x, y=y}
                boxes[#boxes + 1]     = {x=x, y=y}
            elseif ch == '+' then
                targets[#targets + 1] = {x=x, y=y}
                playerPos             = {x=x, y=y}
            end
        end
    end

    return { rows=rows, cols=cols, walls=walls, targets=targets,
             boxes=boxes, playerPos=playerPos }
end

local function drawX(parent, cx, cy, size, color)
    local t = math.max(1, size * 0.22)
    local l = size * 0.85
    local b1 = display.newRect(parent, cx, cy, l, t); b1.rotation = 45
    b1:setFillColor(color[1], color[2], color[3])
    local b2 = display.newRect(parent, cx, cy, l, t); b2.rotation = -45
    b2:setFillColor(color[1], color[2], color[3])
end

local function hasBoxAt(boxes, bx, by)
    for _, b in ipairs(boxes) do
        if b.x == bx and b.y == by then return true end
    end
    return false
end

local function drawThumbnail(group, levelData, x, y, maxCellSize)
    for i = group.numChildren, 1, -1 do
        group:remove(i)
    end

    local L = parseLevel(levelData)
    local rows, cols = L.rows, L.cols

    local availW = VW - 260
    local availH = 380

    local cellSize = math.min(availW / cols, availH / rows, maxCellSize or 22)
    cellSize = math.max(2, math.floor(cellSize))

    local gridWidth  = cellSize * cols
    local gridHeight = cellSize * rows
    local startX = x - gridWidth  / 2
    local startY = y - gridHeight / 2

    local function px(c) return startX + (c-1)*cellSize + cellSize/2 end
    local function py(r) return startY + (r-1)*cellSize + cellSize/2 end

    for ry = 1, rows do
        for rx = 1, cols do
            local isWall = false
            for _, w in ipairs(L.walls) do
                if w.x == rx and w.y == ry then isWall = true; break end
            end
            local rect = display.newRect(group, px(rx), py(ry), cellSize, cellSize)
            local col = isWall and THEME.boardWall or THEME.boardFloor
            rect:setFillColor(col[1], col[2], col[3])
            rect.strokeWidth = 1
            rect:setStrokeColor(unpack(THEME.boardCellStroke))
        end
    end

    for _, t in ipairs(L.targets) do
        if not hasBoxAt(L.boxes, t.x, t.y) then
            drawX(group, px(t.x), py(t.y), cellSize * 0.60, THEME.targetEmpty)
        end
    end

    for _, b in ipairs(L.boxes) do
        local cx, cy = px(b.x), py(b.y)
        local onTarget = hasBoxAt(L.targets, b.x, b.y)
        local rect = display.newRect(group, cx, cy, cellSize * 0.72, cellSize * 0.72)
        local col = onTarget and THEME.boxOnTarget or THEME.boxIdle
        rect:setFillColor(col[1], col[2], col[3])
        rect.strokeWidth = math.max(1, cellSize * 0.08)
        rect:setStrokeColor(unpack(THEME.boxStroke))

        local inner = display.newRect(group, cx, cy, cellSize * 0.52, cellSize * 0.52)
        inner:setFillColor(0, 0, 0, 0)
        inner.strokeWidth = 1
        inner:setStrokeColor(unpack(THEME.boxInnerStroke))
    end

    for _, t in ipairs(L.targets) do
        if hasBoxAt(L.boxes, t.x, t.y) then
            drawX(group, px(t.x), py(t.y), cellSize * 0.55, THEME.targetFilled)
        end
    end

    if L.playerPos then
        local cx, cy = px(L.playerPos.x), py(L.playerPos.y)
        local player = display.newCircle(group, cx, cy, cellSize * 0.35)
        player:setFillColor(unpack(THEME.playerBody))
        player.strokeWidth = math.max(1, cellSize * 0.08)
        player:setStrokeColor(unpack(THEME.playerStroke))

        local eye = display.newCircle(group,
            cx - cellSize*0.10, cy - cellSize*0.10, cellSize * 0.08)
        eye:setFillColor(unpack(THEME.playerEye))
    end
end

local function updateLevelDisplay()
    local level = levels[currentLevelIndex]
    if not level then return end

    if levelNameText then
        levelNameText.text = level.name or ("Уровень " .. currentLevelIndex)
    end
    if levelNumberText then
        levelNumberText.text = string.format("%d / %d", currentLevelIndex, #levels)
    end

    local isCompleted = save.isCompleted and save.isCompleted(currentLevelIndex)
    if levelStatusText then
        if isCompleted then
            levelStatusText.text = "ПРОЙДЕНО"
            levelStatusText:setFillColor(0.2, 0.9, 0.3)
        else
            levelStatusText.text = ""
        end
    end

    if levelDisplayGroup then
        drawThumbnail(levelDisplayGroup, level, VCX, VCY, 22)
    end
end

local function onLeftTap()
    currentLevelIndex = currentLevelIndex - 1
    if currentLevelIndex < 1 then currentLevelIndex = #levels end
    updateLevelDisplay()
end

local function onRightTap()
    currentLevelIndex = currentLevelIndex + 1
    if currentLevelIndex > #levels then currentLevelIndex = 1 end
    updateLevelDisplay()
end

local function onPlayTap()
    composer.removeScene("scenes.game", false)
    composer.gotoScene("scenes.game", {
        effect = "fade", time = 300,
        params = { level = currentLevelIndex }
    })
end

local function onBackTap()
    composer.gotoScene("scenes.menu", { effect = "fade", time = 300 })
end

function scene:create(event)
    VW  = display.contentHeight   -- 1280
    VH  = display.contentWidth    -- 720
    VCX = VW / 2
    VCY = VH / 2

    local group = self.view
    rootGroup = display.newGroup()
    group:insert(rootGroup)

    local bg = display.newRect(rootGroup, VCX, VCY, VW, VH)
    bg:setFillColor(unpack(THEME.bgDark))

    local title = display.newText({
        parent = rootGroup, text = "ВЫБОР УРОВНЯ",
        x = VCX, y = 45, fontSize = 32,
        font = native.systemFontBold, align = "center"
    })
    title:setFillColor(1, 0.95, 0.8)

    levelNumberText = display.newText({
        parent = rootGroup, text = "",
        x = VCX, y = 90, fontSize = 22,
        font = native.systemFont, align = "center"
    })
    levelNumberText:setFillColor(0.8, 0.8, 0.85)

    levelDisplayGroup = display.newGroup()
    rootGroup:insert(levelDisplayGroup)

    levelNameText = display.newText({
        parent = rootGroup, text = "",
        x = VCX, y = VH - 160, fontSize = 26,
        font = native.systemFontBold, align = "center"
    })
    levelNameText:setFillColor(1, 1, 1)

    levelStatusText = display.newText({
        parent = rootGroup, text = "",
        x = VCX, y = VH - 122, fontSize = 20,
        font = native.systemFontBold, align = "center"
    })
    levelStatusText:setFillColor(0.2, 0.9, 0.3)

    local leftBtn = uiButton.new({
        label = "<", x = 70, y = VCY,
        width = 60, height = 60, cornerRadius = 30, fontSize = 28,
        fillColor = THEME.neutral, fillColorOver = THEME.neutralHi,
        fillColorDown = THEME.neutralDown, onPress = onLeftTap
    })
    rootGroup:insert(leftBtn)

    local rightBtn = uiButton.new({
        label = ">", x = VW - 70, y = VCY,
        width = 60, height = 60, cornerRadius = 30, fontSize = 28,
        fillColor = THEME.neutral, fillColorOver = THEME.neutralHi,
        fillColorDown = THEME.neutralDown, onPress = onRightTap
    })
    rootGroup:insert(rightBtn)

    local playBtn = uiButton.new({
        label = "ИГРАТЬ", x = VCX - 130, y = VH - 65,
        width = 220, height = 60, cornerRadius = 30, fontSize = 22,
        fillColor = THEME.success, fillColorOver = THEME.successHi,
        fillColorDown = THEME.successDown, onPress = onPlayTap
    })
    rootGroup:insert(playBtn)

    local backBtn = uiButton.new({
        label = "Назад", x = VCX + 130, y = VH - 65,
        width = 220, height = 60, cornerRadius = 30, fontSize = 22,
        fillColor = THEME.neutral, fillColorOver = THEME.neutralHi,
        fillColorDown = THEME.neutralDown, onPress = onBackTap
    })
    rootGroup:insert(backBtn)

    currentLevelIndex = 1
    updateLevelDisplay()

    -- ПОВОРОТ
    rootGroup.rotation = 90
    rootGroup.x = display.contentWidth
    rootGroup.y = 0
end

function scene:show(event)
    if event.phase == "did" then updateLevelDisplay() end
end

function scene:hide(event) end
function scene:destroy(event)
    rootGroup = nil
    levelDisplayGroup = nil
end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)

return scene