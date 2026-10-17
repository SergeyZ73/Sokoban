-- scenes/game.lua
local composer  = require("composer")
local data      = require("modules.data")
local gameState = require("modules.gameState")
local save      = require("modules.save")
local undo      = require("modules.undo")
local uiButton  = require("modules.uiButton")
local THEME     = require("modules.theme")

local scene = composer.newScene()

-- ==================================================================
-- Local state
-- ==================================================================

local state        = nil
local rootGroup    = nil
local fieldGroup   = nil
local levelLabel   = nil
local movesLabel   = nil
local menuButton   = nil
local undoButton   = nil
local resetButton  = nil
local undoListener = nil

local cellSize    = 0
local rows        = 0
local cols        = 0

local VW, VH, VCX, VCY = 0, 0, 0, 0

local selectedBoxIndex = nil
local isAnimating      = false
local animTimer        = nil
local preAnimSnapshot  = nil   -- снимок состояния ДО авто-доставки
local flashTimers      = {}
local boxSprites       = {}
local playerSprite     = nil

-- "Пустые" клетки за пределами уровня (внешние пробелы).
-- true = снаружи; такие клетки не рисуются, не кликаются,
-- и блокируют движение игрока/ящиков.
local voidGrid         = nil

local stopAnimation
local cancelAllFlashes
local goToNextLevel
local resetLevel
local handleCellTap
local tryMove
local undoMove
local tryDeliverTo

-- ==================================================================
-- Void handling (пустые клетки вне уровня)
-- ==================================================================

-- true, если клетка вне уровня (void) или за пределами сетки.
local function isVoidAt(x, y)
    if not voidGrid then return false end
    if x < 1 or x > cols or y < 1 or y > rows then return true end
    return voidGrid[y][x] == true
end

-- Flood fill от рамки по пробелам: всё, что соединено с рамкой через
-- пробелы, помечаем как "снаружи". Внутренние пробелы (реальный пол)
-- остаются нетронутыми.
local function computeVoids(map, R, C)
    local isSpace = {}
    for y = 1, R do
        isSpace[y] = {}
        local row = map[y] or ""
        for x = 1, C do
            local ch = row:sub(x, x)
            isSpace[y][x] = (ch == "" or ch == " ")
        end
    end

    local void = {}
    for y = 1, R do void[y] = {} end

    local queue = {}
    local head  = 1

    local function tryPush(x, y)
        if x < 1 or x > C or y < 1 or y > R then return end
        if void[y][x] then return end
        if not isSpace[y][x] then return end
        void[y][x] = true
        queue[#queue + 1] = { x = x, y = y }
    end

    for x = 1, C do
        tryPush(x, 1)
        tryPush(x, R)
    end
    for y = 1, R do
        tryPush(1, y)
        tryPush(C, y)
    end

    while head <= #queue do
        local c = queue[head]; head = head + 1
        tryPush(c.x + 1, c.y)
        tryPush(c.x - 1, c.y)
        tryPush(c.x, c.y + 1)
        tryPush(c.x, c.y - 1)
    end

    return void
end

-- ==================================================================
-- Animation / flashes
-- ==================================================================

stopAnimation = function()
    if animTimer then timer.cancel(animTimer); animTimer = nil end
    isAnimating = false
end

cancelAllFlashes = function()
    for _, tid in ipairs(flashTimers) do timer.cancel(tid) end
    flashTimers = {}
end

-- ==================================================================
-- Snapshots
-- ==================================================================

local function makeSnapshot()
    local snap = { moves = state.moves or 0, boxes = {} }
    if state.playerPos then
        snap.playerPos = { x = state.playerPos.x, y = state.playerPos.y }
    end
    for i, b in ipairs(state.boxes) do
        snap.boxes[i] = { x = b.x, y = b.y }
    end
    return snap
end

local function applySnapshot(snap)
    if snap.playerPos then
        state.playerPos = { x = snap.playerPos.x, y = snap.playerPos.y }
    end
    state.boxes = {}
    for i, b in ipairs(snap.boxes) do
        state.boxes[i] = { x = b.x, y = b.y }
    end
    state.moves = snap.moves or 0
end

-- ==================================================================
-- Cell utils
-- ==================================================================

local function isTargetAt(tx, ty)
    for _, t in ipairs(state.targets) do
        if t.x == tx and t.y == ty then return true end
    end
    return false
end

local function isBoxAt(bx, by)
    for _, b in ipairs(state.boxes) do
        if b.x == bx and b.y == by then return true end
    end
    return false
end

local function getBoxIndexAt(x, y)
    for i, b in ipairs(state.boxes) do
        if b.x == x and b.y == y then return i end
    end
    return nil
end

-- Стена = настоящая стена ИЛИ клетка вне уровня.
local function isWallAt(x, y)
    if isVoidAt(x, y) then return true end
    for _, w in ipairs(state.walls) do
        if w.x == x and w.y == y then return true end
    end
    return false
end

-- ==================================================================
-- Draw helpers
-- ==================================================================

local function drawX(parent, cx, cy, size, color)
    local t = display.newGroup()
    t.x, t.y = cx, cy
    parent:insert(t)
    local thickness = math.max(2, size * 0.22)
    local length    = size * 0.85
    local col       = color or {1, 0.85, 0.15}
    local b1 = display.newRect(t, 0, 0, length, thickness); b1.rotation = 45
    b1:setFillColor(col[1], col[2], col[3])
    local b2 = display.newRect(t, 0, 0, length, thickness); b2.rotation = -45
    b2:setFillColor(col[1], col[2], col[3])
    return t
end

local SELECT_COLOR = {0.35, 0.85, 1.0}

local function applySelectionHighlight()
    for i, s in ipairs(boxSprites) do
        if s and s.parent then
            if i == selectedBoxIndex then
                s.strokeWidth = 4
                s:setStrokeColor(SELECT_COLOR[1], SELECT_COLOR[2], SELECT_COLOR[3])
            else
                s.strokeWidth = 2
                s:setStrokeColor(unpack(THEME.boxStroke))
            end
        end
    end
end

local function clearSelection()
    selectedBoxIndex = nil
    applySelectionHighlight()
end

local function selectBox(boxIndex)
    selectedBoxIndex = boxIndex
    applySelectionHighlight()
end

-- ==================================================================
-- Flashes — ONLY red
-- ==================================================================

local FLASH_RED = {1.0, 0.2, 0.2}

local function flashBox(boxIndex, flashColor, cycles, delayMs)
    local sprite = boxSprites[boxIndex]
    if not sprite or not sprite.parent then return end
    local b = state.boxes[boxIndex]
    if not b then return end
    local origCol = isTargetAt(b.x, b.y) and THEME.boxOnTarget or THEME.boxIdle

    local count = 0
    local total = cycles * 2
    local tid
    tid = timer.performWithDelay(delayMs, function()
        count = count + 1
        if sprite and sprite.parent then
            if count % 2 == 1 then
                sprite:setFillColor(flashColor[1], flashColor[2], flashColor[3])
            else
                sprite:setFillColor(origCol[1], origCol[2], origCol[3])
            end
        end
        if count >= total then
            if sprite and sprite.parent then
                sprite:setFillColor(origCol[1], origCol[2], origCol[3])
            end
            timer.cancel(tid)
        end
    end, -1)
    flashTimers[#flashTimers + 1] = tid
end

local function flashRedSelected(boxIndex)
    flashBox(boxIndex, FLASH_RED, 3, 180)
end

-- ==================================================================
-- BFS
-- ==================================================================

local DIRS = {
    { 0, -1, 'U' }, { 0, 1, 'D' },
    { -1, 0, 'L' }, { 1, 0, 'R' },
}

local function buildBlockedGrid(moveBox)
    local blocked = {}
    -- void-клетки блокируют движение
    for y = 1, rows do
        for x = 1, cols do
            if isVoidAt(x, y) then
                blocked[y * cols + x] = true
            end
        end
    end
    for _, w in ipairs(state.walls) do
        blocked[w.y * cols + w.x] = true
    end
    for _, b in ipairs(state.boxes) do
        if b ~= moveBox then
            blocked[b.y * cols + b.x] = true
        end
    end
    return blocked
end

local function stateKey(px, py, bx, by)
    return px .. "," .. py .. "|" .. bx .. "," .. by
end

local function findDeliveryPath(box, target)
    local blocked = buildBlockedGrid(box)
    local startP = { x = state.playerPos.x, y = state.playerPos.y }
    local startB = { x = box.x, y = box.y }

    if startB.x == target.x and startB.y == target.y then return {} end

    local visited = {}
    visited[stateKey(startP.x, startP.y, startB.x, startB.y)] = true

    local queue = { { p = startP, b = startB, path = {} } }
    local head  = 1

    while head <= #queue do
        local s = queue[head]; head = head + 1
        for _, d in ipairs(DIRS) do
            local nx, ny = s.p.x + d[1], s.p.y + d[2]
            local inBounds = nx >= 1 and nx <= cols
                         and ny >= 1 and ny <= rows
            if inBounds and not blocked[ny * cols + nx] then
                local np    = { x = nx, y = ny }
                local nb    = s.b
                local valid = true
                if nx == s.b.x and ny == s.b.y then
                    local bx2, by2 = s.b.x + d[1], s.b.y + d[2]
                    local inB2 = bx2 >= 1 and bx2 <= cols
                             and by2 >= 1 and by2 <= rows
                    if not inB2 or blocked[by2 * cols + bx2] then
                        valid = false
                    else
                        nb = { x = bx2, y = by2 }
                    end
                end
                if valid then
                    local k = stateKey(np.x, np.y, nb.x, nb.y)
                    if not visited[k] then
                        visited[k] = true
                        local newPath = {}
                        for i = 1, #s.path do newPath[i] = s.path[i] end
                        newPath[#newPath + 1] = d[3]
                        if nb.x == target.x and nb.y == target.y then
                            return newPath
                        end
                        queue[#queue + 1] = { p = np, b = nb, path = newPath }
                    end
                end
            end
        end
    end
    return nil
end

-- ==================================================================
-- Load level
-- ==================================================================

local function loadLevel(levelIndex)
    stopAnimation()
    cancelAllFlashes()
    selectedBoxIndex = nil
    preAnimSnapshot  = nil

    local level = data.levels[levelIndex]
    if not level then
        native.showAlert("Ошибка", "Уровень не найден", {"OK"})
        composer.gotoScene("scenes.menu", { effect = "fade", time = 300 })
        return false
    end

    state.playerPos = nil
    state.boxes     = {}
    state.targets   = {}
    state.walls     = {}

    local map = level.map
    rows = #map
    cols = 0
    for _, row in ipairs(map) do
        if #row > cols then cols = #row end
    end

    for y, row in ipairs(map) do
        for x = 1, cols do
            local char = row:sub(x, x)
            if     char == '#' then table.insert(state.walls,   {x=x, y=y})
            elseif char == '.' then table.insert(state.targets, {x=x, y=y})
            elseif char == '$' then table.insert(state.boxes,   {x=x, y=y})
            elseif char == '@' then state.playerPos = {x=x, y=y}
            elseif char == '*' then
                table.insert(state.targets, {x=x, y=y})
                table.insert(state.boxes,   {x=x, y=y})
            elseif char == '+' then
                table.insert(state.targets, {x=x, y=y})
                state.playerPos = {x=x, y=y}
            end
        end
    end

    -- Вычисляем "пустые" клетки снаружи уровня
    voidGrid = computeVoids(map, rows, cols)

    state.moves        = 0
    state.currentLevel = levelIndex
    state.levelName    = level.name

    if not state.playerPos then state.playerPos = {x=2, y=2} end

    undo.clear()
    undo.push(makeSnapshot())
    return true
end

-- ==================================================================
-- Draw field
-- ==================================================================

local function drawField()
    if fieldGroup then fieldGroup:removeSelf(); fieldGroup = nil end
    boxSprites   = {}
    playerSprite = nil

    fieldGroup = display.newGroup()
    rootGroup:insert(fieldGroup)

    local topOffset    = 110
    local bottomOffset = 15
    local leftOffset   = 15
    local rightOffset  = 15

    local availWidth  = VW - leftOffset - rightOffset
    local availHeight = VH - topOffset  - bottomOffset

    cellSize = math.floor(math.min(availWidth / cols, availHeight / rows))

    local gridWidth  = cellSize * cols
    local gridHeight = cellSize * rows
    local gridOffsetX = (VW - gridWidth)  / 2
    local gridOffsetY = topOffset + (availHeight - gridHeight) / 2

    -- Пол и стены (void-клетки пропускаем — просвечивает фон)
    for y = 1, rows do
        for x = 1, cols do
            if not isVoidAt(x, y) then
                local isWall = false
                for _, w in ipairs(state.walls) do
                    if w.x == x and w.y == y then isWall = true; break end
                end
                local cx = gridOffsetX + (x-1)*cellSize + cellSize/2
                local cy = gridOffsetY + (y-1)*cellSize + cellSize/2
                local rect = display.newRect(fieldGroup, cx, cy, cellSize, cellSize)
                local col = isWall and THEME.boardWall or THEME.boardFloor
                rect:setFillColor(col[1], col[2], col[3])
                rect.strokeWidth = 1
                rect:setStrokeColor(unpack(THEME.boardCellStroke))
            end
        end
    end

    for _, t in ipairs(state.targets) do
        if not isBoxAt(t.x, t.y) and not isVoidAt(t.x, t.y) then
            drawX(fieldGroup,
                gridOffsetX + (t.x-1)*cellSize + cellSize/2,
                gridOffsetY + (t.y-1)*cellSize + cellSize/2,
                cellSize * 0.60, THEME.targetEmpty)
        end
    end

    for i, b in ipairs(state.boxes) do
        local cx = gridOffsetX + (b.x-1)*cellSize + cellSize/2
        local cy = gridOffsetY + (b.y-1)*cellSize + cellSize/2
        local onTarget = isTargetAt(b.x, b.y)
        local rect = display.newRect(fieldGroup, cx, cy,
                                     cellSize * 0.72, cellSize * 0.72)
        local col = onTarget and THEME.boxOnTarget or THEME.boxIdle
        rect:setFillColor(col[1], col[2], col[3])
        rect.strokeWidth = 2
        rect:setStrokeColor(unpack(THEME.boxStroke))

        local inner = display.newRect(fieldGroup, cx, cy,
                                      cellSize * 0.52, cellSize * 0.52)
        inner:setFillColor(0, 0, 0, 0)
        inner.strokeWidth = 1
        inner:setStrokeColor(unpack(THEME.boxInnerStroke))

        boxSprites[i] = rect
    end

    for _, t in ipairs(state.targets) do
        if isBoxAt(t.x, t.y) and not isVoidAt(t.x, t.y) then
            drawX(fieldGroup,
                gridOffsetX + (t.x-1)*cellSize + cellSize/2,
                gridOffsetY + (t.y-1)*cellSize + cellSize/2,
                cellSize * 0.55, THEME.targetFilled)
        end
    end

    if state.playerPos then
        local px, py = state.playerPos.x, state.playerPos.y
        local cx = gridOffsetX + (px-1)*cellSize + cellSize/2
        local cy = gridOffsetY + (py-1)*cellSize + cellSize/2
        local player = display.newCircle(fieldGroup, cx, cy, cellSize * 0.35)
        player:setFillColor(unpack(THEME.playerBody))
        player.strokeWidth = 2
        player:setStrokeColor(unpack(THEME.playerStroke))
        local eye = display.newCircle(fieldGroup,
            cx - cellSize*0.10, cy - cellSize*0.10, cellSize * 0.08)
        eye:setFillColor(unpack(THEME.playerEye))
        playerSprite = player
    end

    applySelectionHighlight()

    local gridW = cellSize * cols
    local gridH = cellSize * rows
    local overlay = display.newRect(fieldGroup,
        gridOffsetX + gridW / 2, gridOffsetY + gridH / 2, gridW, gridH)
    overlay:setFillColor(0, 0, 0, 0.01)
    overlay.isHitTestable = true
    overlay:addEventListener("tap", function(event)
        if not state or not state.playerPos then return true end
        -- Обратное преобразование поворота rootGroup (rotation=90, x=720, y=0)
        local lx = event.y
        local ly = display.contentWidth - event.x
        local fx = lx - gridOffsetX
        local fy = ly - gridOffsetY
        local gx = math.floor(fx / cellSize) + 1
        local gy = math.floor(fy / cellSize) + 1
        if gx >= 1 and gx <= cols and gy >= 1 and gy <= rows
           and not isVoidAt(gx, gy) then
            handleCellTap(gx, gy)
        else
            clearSelection()
        end
        return true
    end)

    if levelLabel then
        levelLabel.text = state.levelName or ("Уровень " .. state.currentLevel)
    end
    if movesLabel then
        movesLabel.text = "Ход: " .. state.moves
    end
end

-- ==================================================================
-- Win
-- ==================================================================

local function checkWin()
    for _, box in ipairs(state.boxes) do
        local onTarget = false
        for _, target in ipairs(state.targets) do
            if box.x == target.x and box.y == target.y then
                onTarget = true; break
            end
        end
        if not onTarget then return false end
    end
    return true
end

goToNextLevel = function()
    local total = #data.levels

    -- Все уровни пройдены?
    if save.areAllLevelsCompleted(total) then
        undo.clear()
        native.showAlert(
            "Поздравляем!",
            "Вы прошли все " .. total .. " уровней!",
            { "OK" },
            function()
                composer.gotoScene("scenes.menu", { effect = "fade", time = 300 })
            end
        )
        return
    end

    -- Последний по индексу, но не все пройдены — тихо в меню
    if state.currentLevel >= total then
        undo.clear()
        composer.gotoScene("scenes.menu", { effect = "fade", time = 300 })
        return
    end

    -- Иначе — следующий уровень
    save.saveState(state)
    if loadLevel(state.currentLevel + 1) then
        drawField()
        save.saveState(state)
    end
end

-- ==================================================================
-- Step
-- push в undo делается ТОЛЬКО для обычных ходов.
-- Для авто-доставки push делает animatePath по завершении анимации.
-- ==================================================================

tryMove = function(dx, dy, isAuto)
    if not state.playerPos then return end
    if isAnimating and not isAuto then return end

    if not isAuto then
        clearSelection()
        cancelAllFlashes()
    end

    local newX = state.playerPos.x + dx
    local newY = state.playerPos.y + dy

    if isWallAt(newX, newY) then return end

    local boxIndex = getBoxIndexAt(newX, newY)
    if boxIndex then
        local boxNewX, boxNewY = newX + dx, newY + dy
        if isWallAt(boxNewX, boxNewY) then return end
        if isBoxAt(boxNewX, boxNewY)  then return end
        state.boxes[boxIndex].x = boxNewX
        state.boxes[boxIndex].y = boxNewY
    end

    state.playerPos.x = newX
    state.playerPos.y = newY
    state.moves = state.moves + 1

    if not isAuto then
        undo.push(makeSnapshot())
    end

    drawField()

    if checkWin() then
        save.markCompleted(state.currentLevel)
        save.saveState(state)
        undo.clear()
        stopAnimation()
        goToNextLevel()
    else
        save.saveState(state)
    end
end

-- ==================================================================
-- Path animation — один снапшот на всю доставку
-- ==================================================================

local function animatePath(path)
    if not path or #path == 0 then
        clearSelection()
        return
    end
    isAnimating = true
    preAnimSnapshot = makeSnapshot()   -- состояние ДО анимации

    local i = 1
    animTimer = timer.performWithDelay(130, function()
        if i > #path then
            -- ВАЖНО: stopAnimation() отменяет таймер и сбрасывает isAnimating.
            -- Если просто сделать animTimer = nil, таймер продолжит стрелять
            -- каждые 130 мс и будет постоянно вызывать clearSelection().
            stopAnimation()
            clearSelection()
            if preAnimSnapshot then
                undo.push(makeSnapshot())
                preAnimSnapshot = nil
            end
            return
        end

        local dir = path[i]; i = i + 1
        local dx, dy = 0, 0
        if     dir == 'U' then dy = -1
        elseif dir == 'D' then dy =  1
        elseif dir == 'L' then dx = -1
        elseif dir == 'R' then dx =  1
        end
        tryMove(dx, dy, true)
    end, -1)
end

-- ==================================================================
-- Deliver selected box to a cell
-- ==================================================================

tryDeliverTo = function(tx, ty)
    if not selectedBoxIndex then return end
    local box = state.boxes[selectedBoxIndex]
    if not box then clearSelection(); return end

    if isWallAt(tx, ty) then
        local idx = selectedBoxIndex
        clearSelection()
        flashRedSelected(idx)
        return
    end
    if isBoxAt(tx, ty) and not (box.x == tx and box.y == ty) then
        local idx = selectedBoxIndex
        clearSelection()
        flashRedSelected(idx)
        return
    end

    local path = findDeliveryPath(box, { x = tx, y = ty })
    if path then
        animatePath(path)
    else
        local idx = selectedBoxIndex
        clearSelection()
        flashRedSelected(idx)
    end
end

-- ==================================================================
-- Cell tap
-- ==================================================================

handleCellTap = function(x, y)
    if isAnimating then return end
    if isVoidAt(x, y) then clearSelection(); return end
    local boxIdx = getBoxIndexAt(x, y)

    if not selectedBoxIndex then
        if boxIdx then selectBox(boxIdx) end
        return
    end

    if boxIdx then
        if selectedBoxIndex == boxIdx then
            clearSelection()
        else
            selectBox(boxIdx)
        end
        return
    end

    tryDeliverTo(x, y)
end

-- ==================================================================
-- Undo
--
-- Если отмена нажата во время авто-доставки — просто возвращаем
-- состояние, зафиксированное в preAnimSnapshot, и не трогаем стек.
-- ==================================================================

undoMove = function()
    local wasAnimating = isAnimating
    stopAnimation()
    cancelAllFlashes()
    clearSelection()

    if wasAnimating and preAnimSnapshot then
        applySnapshot(preAnimSnapshot)
        preAnimSnapshot = nil
        drawField()
        save.saveState(state)
        return
    end

    local snap = undo.undo()
    if not snap then return end
    applySnapshot(snap)
    drawField()
    save.saveState(state)
end

-- ==================================================================
-- Reset
-- ==================================================================

resetLevel = function()
    stopAnimation()
    cancelAllFlashes()
    if loadLevel(state.currentLevel) then
        drawField()
        save.saveState(state)
    end
end

-- ==================================================================
-- Scene
-- ==================================================================

function scene:create(event)
    local group = self.view

    VW  = display.contentHeight    -- 1280
    VH  = display.contentWidth     -- 720
    VCX = VW / 2
    VCY = VH / 2

    local params = event.params
    local levelParam = params and params.level

    if levelParam then
        state = gameState.new()
        state.currentLevel = levelParam
        save.saveState(state)
    else
        state = save.loadState()
        if not state then
            state = gameState.new()
            save.saveState(state)
        end
    end

    if not loadLevel(state.currentLevel) then
        composer.gotoScene("scenes.menu", { effect = "fade", time = 300 })
        return
    end

    rootGroup = display.newGroup()
    group:insert(rootGroup)

    local bg = display.newRect(rootGroup, VCX, VCY, VW, VH)
    bg:setFillColor(unpack(THEME.bgDark))

    local hudY = 44

    levelLabel = display.newText({
        parent = rootGroup,
        text = state.levelName or ("Уровень " .. state.currentLevel),
        x = 40, y = hudY,
        fontSize = 26, font = native.systemFontBold, align = "left"
    })
    levelLabel.anchorX = 0
    levelLabel:setFillColor(1, 0.95, 0.8)

    movesLabel = display.newText({
        parent = rootGroup,
        text = "Ход: " .. state.moves,
        x = VCX, y = hudY,
        fontSize = 22, font = native.systemFontBold
    })
    movesLabel:setFillColor(0.85, 0.85, 0.9)

    local btnW, btnH = 140, 56
    local spacing    = 14
    local rightX     = VW - 40

    resetButton = uiButton.new({
        label = "Сброс",
        x = rightX - btnW/2, y = hudY,
        width = btnW, height = btnH, cornerRadius = 14, fontSize = 18,
        fillColor     = THEME.danger,
        fillColorOver = THEME.dangerHi,
        fillColorDown = THEME.dangerDown,
        onPress = resetLevel
    })
    rootGroup:insert(resetButton)

    undoButton = uiButton.new({
        label = "Отмена",
        x = rightX - btnW - spacing - btnW/2, y = hudY,
        width = btnW, height = btnH, cornerRadius = 14, fontSize = 18,
        fillColor     = {0.35, 0.35, 0.55},
        fillColorOver = {0.55, 0.55, 0.85},
        fillColorDown = {0.22, 0.22, 0.40},
        onPress = undoMove
    })
    rootGroup:insert(undoButton)

    menuButton = uiButton.new({
        label = "Меню",
        x = rightX - 2*btnW - 2*spacing - btnW/2, y = hudY,
        width = btnW, height = btnH, cornerRadius = 14, fontSize = 18,
        fillColor     = THEME.neutral,
        fillColorOver = THEME.neutralHi,
        fillColorDown = THEME.neutralDown,
        onPress = function()
            save.saveState(state)
            undo.clear()
            stopAnimation()
            cancelAllFlashes()
            composer.gotoScene("scenes.menu", { effect = "fade", time = 300 })
        end
    })
    rootGroup:insert(menuButton)

    if undoListener then
        undo.unsubscribe(undoListener); undoListener = nil
    end
    undoListener = undo.subscribe(function(canUndo)
        if undoButton and undoButton.setEnabled then
            undoButton:setEnabled(canUndo)
        end
    end)

    drawField()

    -- ПОВОРОТ
    rootGroup.rotation = 90
    rootGroup.x = display.contentWidth
    rootGroup.y = 0
end

-- ==================================================================
-- Keyboard (desktop testing only)
-- ==================================================================

local function onKeyEvent(event)
    if event.phase == "down" then
        local key = event.keyName
        if     key == "up"    then tryMove(0, -1)
        elseif key == "down"  then tryMove(0,  1)
        elseif key == "left"  then tryMove(-1, 0)
        elseif key == "right" then tryMove( 1, 0)
        elseif key == "r"     then resetLevel()
        elseif key == "z"     then undoMove()
        end
    end
    return true
end

function scene:show(event)
    if event.phase == "will" then
        Runtime:addEventListener("key", onKeyEvent)
        if state and undo.depth() == 0 then
            undo.push(makeSnapshot())
        end
    end
end

function scene:hide(event)
    if event.phase == "will" then
        Runtime:removeEventListener("key", onKeyEvent)
        stopAnimation()
        cancelAllFlashes()
        if state then save.saveState(state) end
        undo.clear()
    end
end

function scene:destroy(event)
    stopAnimation()
    cancelAllFlashes()
    if undoListener then
        undo.unsubscribe(undoListener)
        undoListener = nil
    end
    undo.clear()
    undoButton   = nil
    resetButton  = nil
    menuButton   = nil
    selectedBoxIndex = nil
    preAnimSnapshot  = nil
    boxSprites   = {}
    playerSprite = nil
    rootGroup    = nil
    fieldGroup   = nil
    voidGrid     = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene