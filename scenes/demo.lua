-- scenes/demo.lua
local composer  = require("composer")
local uiButton  = require("modules.uiButton")
local THEME     = require("modules.theme")
local save      = require("modules.save")
local gameState = require("modules.gameState")

local scene = composer.newScene()

-- ==================================================================
-- Константы
-- ==================================================================

local VW, VH, VCX, VCY

local HEADER_HEIGHT  = 160
local FIELD_PADDING  = 20
local AUTO_TAP_DELAY = 3000

local DEMO_MAP = {
    "##########",
    "#. .     #",   -- цели (2,2) и (4,2)
    "#        #",   -- y=3
    "#  $     #",   -- верхний ящик (4,4)
    "#  $     #",   -- нижний ящик (4,5)
    "#        #",   -- y=6
    "#@       #",   -- игрок (2,7)
    "##########",
}
local DEMO_ROWS = #DEMO_MAP
local DEMO_COLS = #DEMO_MAP[1]

-- Этапы
local S_BOX2, S_FREE2, S_BOX1, S_TARGET1, S_BOX2B, S_TARGET2, S_DONE =
    1, 2, 3, 4, 5, 6, 7

-- ==================================================================
-- Переменные
-- ==================================================================

local state          = nil
local rootGroup      = nil
local fieldGroup     = nil
local uiGroup        = nil
local topGroup       = nil
local handGroup      = nil
local hintLabel      = nil

local cellSize       = 0
local gridOffsetX    = 0
local gridOffsetY    = 0

local boxSprites     = {}
local playerSprite   = nil

local selectedBoxIndex = nil
local stage          = 0
local isAnimating    = false
local animTimer      = nil
local autoTimer      = nil
local handPulseTween = nil

-- ==================================================================
-- Forward declarations
-- ==================================================================

local stopAnimation
local stopAutoTimer
local hideHand
local placeHandAt
local advanceStage
local scheduleAutoTap
local handleCellTap
local tryMove
local tryAutoDeliverTo
local drawField
local goToGame
local goToGameSkipped

-- ==================================================================
-- Хелперы
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

local function isWallAt(wx, wy)
    for _, w in ipairs(state.walls) do
        if w.x == wx and w.y == wy then return true end
    end
    return false
end

local function getBoxIndexAt(x, y)
    for i, b in ipairs(state.boxes) do
        if b.x == x and b.y == y then return i end
    end
    return nil
end

-- ==================================================================
-- Загрузка демо
-- ==================================================================

local function loadDemo()
    state = {
        playerPos = nil,
        boxes = {}, targets = {}, walls = {},
        moves = 0,
        levelName = "Демо",
    }
    for y, row in ipairs(DEMO_MAP) do
        for x = 1, #row do
            local c = row:sub(x, x)
            if     c == '#' then table.insert(state.walls,   {x=x, y=y})
            elseif c == '.' then table.insert(state.targets, {x=x, y=y})
            elseif c == '$' then table.insert(state.boxes,   {x=x, y=y})
            elseif c == '@' then state.playerPos = {x=x, y=y}
            elseif c == '*' then
                table.insert(state.targets, {x=x, y=y})
                table.insert(state.boxes,   {x=x, y=y})
            elseif c == '+' then
                table.insert(state.targets, {x=x, y=y})
                state.playerPos = {x=x, y=y}
            end
        end
    end
end

-- ==================================================================
-- Таймеры
-- ==================================================================

stopAnimation = function()
    if animTimer then timer.cancel(animTimer); animTimer = nil end
    isAnimating = false
end

stopAutoTimer = function()
    if autoTimer then timer.cancel(autoTimer); autoTimer = nil end
end

-- ==================================================================
-- Крестик
-- ==================================================================

local function drawX(parent, cx, cy, size, color)
    local t = display.newGroup()
    t.x, t.y = cx, cy
    parent:insert(t)

    local thickness = math.max(2, size * 0.22)
    local length    = size * 0.85
    local col       = color or {1, 0.85, 0.15}

    local b1 = display.newRect(t, 0, 0, length, thickness)
    b1.rotation = 45
    b1:setFillColor(col[1], col[2], col[3])

    local b2 = display.newRect(t, 0, 0, length, thickness)
    b2.rotation = -45
    b2:setFillColor(col[1], col[2], col[3])
    return t
end

-- ==================================================================
-- Стрелка-указатель
-- ==================================================================

local function drawHand()
    if handGroup then handGroup:removeSelf(); handGroup = nil end

    handGroup = display.newGroup()
    topGroup:insert(handGroup)

    local arrow = display.newPolygon(handGroup, 0, 0, {
         0,   0,
       -22,  30,
       -22,  12,
       -64,  12,
       -64, -12,
       -22, -12,
       -22, -30,
    })
    arrow:setFillColor(1, 0.9, 0.2)
    arrow.strokeWidth = 3
    arrow:setStrokeColor(0.4, 0.25, 0)

    arrow.anchorX = 1
    arrow.anchorY = 0.5

    handGroup.isVisible = false
end

placeHandAt = function(gridX, gridY)
    if not handGroup then return end

    local cx = gridOffsetX + (gridX - 0.5) * cellSize
    local cy = gridOffsetY + (gridY - 0.5) * cellSize

    handGroup.x = cx
    handGroup.y = cy
    handGroup.isVisible = true
    handGroup.xScale = 1
    handGroup.yScale = 1

    if handPulseTween then
        transition.cancel(handPulseTween); handPulseTween = nil
    end
    handPulseTween = transition.to(handGroup, {
        time = 550,
        xScale = 1.15, yScale = 1.15,
        iterations = -1, autoreverse = true,
        transition = easing.inOutSine,
    })
end

hideHand = function()
    if handGroup then handGroup.isVisible = false end
    if handPulseTween then
        transition.cancel(handPulseTween); handPulseTween = nil
    end
end

-- ==================================================================
-- BFS
-- ==================================================================

local DIRS = {
    { 0, -1, 'U' }, { 0, 1, 'D' },
    { -1, 0, 'L' }, { 1, 0, 'R' },
}

local function buildBlockedGrid(exceptBox)
    local blocked = {}
    for _, w in ipairs(state.walls) do
        blocked[w.y * DEMO_COLS + w.x] = true
    end
    for _, b in ipairs(state.boxes) do
        if b ~= exceptBox then
            blocked[b.y * DEMO_COLS + b.x] = true
        end
    end
    return blocked
end

local function findDeliveryPath(box, target)
    local blocked = buildBlockedGrid(box)
    local startP = { x = state.playerPos.x, y = state.playerPos.y }
    local startB = { x = box.x, y = box.y }

    if startB.x == target.x and startB.y == target.y then return {} end

    local visited = {}
    visited[startP.x..","..startP.y.."|"..startB.x..","..startB.y] = true
    local queue = { { p = startP, b = startB, path = {} } }
    local head = 1

    while head <= #queue do
        local s = queue[head]; head = head + 1
        for _, d in ipairs(DIRS) do
            local nx, ny = s.p.x + d[1], s.p.y + d[2]
            if nx >= 1 and nx <= DEMO_COLS and ny >= 1 and ny <= DEMO_ROWS
               and not blocked[ny * DEMO_COLS + nx] then
                local np, nb, ok = { x = nx, y = ny }, s.b, true
                if nx == s.b.x and ny == s.b.y then
                    local bx, by = s.b.x + d[1], s.b.y + d[2]
                    if bx < 1 or bx > DEMO_COLS or by < 1 or by > DEMO_ROWS
                       or blocked[by * DEMO_COLS + bx] then
                        ok = false
                    else
                        nb = { x = bx, y = by }
                    end
                end
                if ok then
                    local k = np.x..","..np.y.."|"..nb.x..","..nb.y
                    if not visited[k] then
                        visited[k] = true
                        local np2 = {}
                        for i = 1, #s.path do np2[i] = s.path[i] end
                        np2[#np2 + 1] = d[3]
                        if nb.x == target.x and nb.y == target.y then
                            return np2
                        end
                        queue[#queue + 1] = { p = np, b = nb, path = np2 }
                    end
                end
            end
        end
    end
    return nil
end

-- ==================================================================
-- Движение
-- ==================================================================

tryMove = function(dx, dy)
    if not state.playerPos then return end
    local nx, ny = state.playerPos.x + dx, state.playerPos.y + dy
    if isWallAt(nx, ny) then return end

    local bi = getBoxIndexAt(nx, ny)
    if bi then
        local bx, by = nx + dx, ny + dy
        if isWallAt(bx, by) or isBoxAt(bx, by) then return end
        state.boxes[bi].x = bx
        state.boxes[bi].y = by
    end
    state.playerPos.x = nx
    state.playerPos.y = ny
    state.moves = state.moves + 1
    drawField()
end

local function animatePath(path, onDone)
    if not path or #path == 0 then
        if onDone then onDone() end
        return
    end
    isAnimating = true
    local i = 1
    animTimer = timer.performWithDelay(150, function()
        if i > #path then
            stopAnimation()
            if onDone then onDone() end
            return
        end
        local dir = path[i]; i = i + 1
        local dx, dy = 0, 0
        if     dir == 'U' then dy = -1
        elseif dir == 'D' then dy =  1
        elseif dir == 'L' then dx = -1
        elseif dir == 'R' then dx =  1
        end
        tryMove(dx, dy)
    end, -1)
end

tryAutoDeliverTo = function(tx, ty)
    if not selectedBoxIndex then return end
    if isWallAt(tx, ty) then return end

    local bi = getBoxIndexAt(tx, ty)
    if bi and bi ~= selectedBoxIndex then
        selectedBoxIndex = bi
        drawField()
        return
    end

    local box = state.boxes[selectedBoxIndex]
    if box.x == tx and box.y == ty then return end

    local path = findDeliveryPath(box, { x = tx, y = ty })
    if not path or #path == 0 then
        drawField()
        return
    end

    selectedBoxIndex = nil
    animatePath(path, function()
        if     stage == S_FREE2   then advanceStage(S_BOX1)
        elseif stage == S_TARGET1 then advanceStage(S_BOX2B)
        elseif stage == S_TARGET2 then advanceStage(S_DONE)
        end
    end)
end

-- ==================================================================
-- Отрисовка
-- ==================================================================

drawField = function()
    if fieldGroup then fieldGroup:removeSelf(); fieldGroup = nil end
    boxSprites = {}
    playerSprite = nil

    fieldGroup = display.newGroup()
    rootGroup:insert(fieldGroup)

    local topOffset    = HEADER_HEIGHT + FIELD_PADDING
    local bottomOffset = FIELD_PADDING
    local leftOffset   = FIELD_PADDING
    local rightOffset  = FIELD_PADDING

    local availW = VW - leftOffset - rightOffset
    local availH = VH - topOffset  - bottomOffset

    cellSize = math.min(availW / DEMO_COLS, availH / DEMO_ROWS)
    cellSize = math.floor(cellSize)

    local gridW = cellSize * DEMO_COLS
    local gridH = cellSize * DEMO_ROWS

    gridOffsetX = (VW - gridW) / 2
    gridOffsetY = topOffset + (availH - gridH) / 2

    for y = 1, DEMO_ROWS do
        for x = 1, DEMO_COLS do
            local cx = gridOffsetX + (x-1)*cellSize + cellSize/2
            local cy = gridOffsetY + (y-1)*cellSize + cellSize/2
            local rect = display.newRect(fieldGroup, cx, cy, cellSize, cellSize)
            local col = isWallAt(x, y) and THEME.boardWall or THEME.boardFloor
            rect:setFillColor(col[1], col[2], col[3])
            rect.strokeWidth = 1
            rect:setStrokeColor(unpack(THEME.boardCellStroke))
        end
    end

    for _, t in ipairs(state.targets) do
        if not isBoxAt(t.x, t.y) then
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
                                     cellSize * 0.80, cellSize * 0.80)
        local col = onTarget and THEME.boxOnTarget or THEME.boxIdle
        rect:setFillColor(col[1], col[2], col[3])
        rect.strokeWidth = 2
        rect:setStrokeColor(unpack(THEME.boxStroke))

        if i == selectedBoxIndex then
            rect.strokeWidth = 5
            rect:setStrokeColor(1, 0.9, 0.15)
        end

        local inner = display.newRect(fieldGroup, cx, cy,
                                      cellSize * 0.58, cellSize * 0.58)
        inner:setFillColor(0, 0, 0, 0)
        inner.strokeWidth = 1
        inner:setStrokeColor(unpack(THEME.boxInnerStroke))

        boxSprites[i] = rect
    end

    for _, t in ipairs(state.targets) do
        if isBoxAt(t.x, t.y) then
            drawX(fieldGroup,
                gridOffsetX + (t.x-1)*cellSize + cellSize/2,
                gridOffsetY + (t.y-1)*cellSize + cellSize/2,
                cellSize * 0.60, THEME.targetFilled)
        end
    end

    if state.playerPos then
        local cx = gridOffsetX + (state.playerPos.x-1)*cellSize + cellSize/2
        local cy = gridOffsetY + (state.playerPos.y-1)*cellSize + cellSize/2
        local player = display.newCircle(fieldGroup, cx, cy, cellSize * 0.36)
        player:setFillColor(unpack(THEME.playerBody))
        player.strokeWidth = 2
        player:setStrokeColor(unpack(THEME.playerStroke))

        local eye = display.newCircle(fieldGroup,
            cx - cellSize*0.10, cy - cellSize*0.10, cellSize * 0.08)
        eye:setFillColor(unpack(THEME.playerEye))

        playerSprite = player
    end

    local overlay = display.newRect(fieldGroup,
        gridOffsetX + gridW/2, gridOffsetY + gridH/2, gridW, gridH)
    overlay:setFillColor(0, 0, 0, 0.01)
    overlay.isHitTestable = true
    overlay:addEventListener("tap", function(event)
        if isAnimating then return true end
        local lx, ly = overlay:contentToLocal(event.x, event.y)
        local fx = lx + overlay.width  / 2
        local fy = ly + overlay.height / 2
        local gx = math.floor(fx / cellSize) + 1
        local gy = math.floor(fy / cellSize) + 1
        if gx >= 1 and gx <= DEMO_COLS and gy >= 1 and gy <= DEMO_ROWS then
            handleCellTap(gx, gy)
        end
        return true
    end)

    if uiGroup  then uiGroup:toFront()  end
    if topGroup then topGroup:toFront() end
end

-- ==================================================================
-- Этапы
-- ==================================================================

local function setHint(text)
    if hintLabel then hintLabel.text = text end
end

scheduleAutoTap = function(tx, ty)
    stopAutoTimer()
    autoTimer = timer.performWithDelay(AUTO_TAP_DELAY, function()
        if isAnimating then return end
        handleCellTap(tx, ty)
    end)
end

advanceStage = function(newStage)
    stage = newStage

    if stage == S_BOX2 then
        setHint("1. Нижний ящик мешает. Тапни по нему, чтобы выбрать.")
        local b = state.boxes[2]
        placeHandAt(b.x, b.y)
        scheduleAutoTap(b.x, b.y)

    elseif stage == S_FREE2 then
        setHint("2. Тапни по клетке в стороне — сдвинем ящик с пути.")
        placeHandAt(6, 5)
        scheduleAutoTap(6, 5)

    elseif stage == S_BOX1 then
        setHint("3. Путь свободен. Теперь тапни по верхнему ящику.")
        local b = state.boxes[1]
        placeHandAt(b.x, b.y)
        scheduleAutoTap(b.x, b.y)

    elseif stage == S_TARGET1 then
        setHint("4. Укажи цель — верхний ряд, левый крестик.")
        placeHandAt(2, 2)
        scheduleAutoTap(2, 2)

    elseif stage == S_BOX2B then
        setHint("5. Отлично! Теперь доведи второй ящик. Тапни по нему.")
        local b = state.boxes[2]
        placeHandAt(b.x, b.y)
        scheduleAutoTap(b.x, b.y)

    elseif stage == S_TARGET2 then
        setHint("6. Укажи вторую цель — верхний ряд, правый крестик.")
        placeHandAt(4, 2)
        scheduleAutoTap(4, 2)

    elseif stage == S_DONE then
        hideHand()
        stopAutoTimer()
        setHint("Готово! Ты умеешь выбирать ящик, сдвигать и доставлять на цель.")
        timer.performWithDelay(1600, goToGame)
    end
end

-- ==================================================================
-- Обработка тапа
-- ==================================================================

handleCellTap = function(x, y)
    if isAnimating then return end
    stopAutoTimer()

    local bi = getBoxIndexAt(x, y)

    if stage == S_BOX2 then
        if bi == 2 then
            selectedBoxIndex = 2
            drawField()
            advanceStage(S_FREE2)
        else
            local b = state.boxes[2]
            placeHandAt(b.x, b.y)
            scheduleAutoTap(b.x, b.y)
        end
        return
    end

    if stage == S_FREE2 then
        if x == 6 and y == 5 and not bi then
            tryAutoDeliverTo(6, 5)
        else
            placeHandAt(6, 5)
            scheduleAutoTap(6, 5)
        end
        return
    end

    if stage == S_BOX1 then
        if bi == 1 then
            selectedBoxIndex = 1
            drawField()
            advanceStage(S_TARGET1)
        else
            local b = state.boxes[1]
            placeHandAt(b.x, b.y)
            scheduleAutoTap(b.x, b.y)
        end
        return
    end

    if stage == S_TARGET1 then
        if x == 2 and y == 2 and not bi then
            tryAutoDeliverTo(2, 2)
        else
            placeHandAt(2, 2)
            scheduleAutoTap(2, 2)
        end
        return
    end

    if stage == S_BOX2B then
        if bi == 2 then
            selectedBoxIndex = 2
            drawField()
            advanceStage(S_TARGET2)
        else
            local b = state.boxes[2]
            placeHandAt(b.x, b.y)
            scheduleAutoTap(b.x, b.y)
        end
        return
    end

    if stage == S_TARGET2 then
        if x == 4 and y == 2 and not bi then
            tryAutoDeliverTo(4, 2)
        else
            placeHandAt(4, 2)
            scheduleAutoTap(4, 2)
        end
        return
    end
end

-- ==================================================================
-- Переходы
-- ==================================================================

-- После demo создаём НОВЫЙ стейт и сохраняем его,
-- чтобы меню переключилось на «Продолжить» при следующем входе.
local function startNewGame()
    local state = gameState.new()
    save.saveState(state)
    composer.gotoScene("scenes.game", {
        effect = "fade", time = 300,
        params = { level = 1 }
    })
end

goToGame = function()
    startNewGame()
end

goToGameSkipped = function()
    startNewGame()
end

-- ==================================================================
-- Сцена
-- ==================================================================

function scene:create(event)
    local group = self.view

    VW  = display.contentHeight
    VH  = display.contentWidth
    VCX = VW / 2
    VCY = VH / 2

    loadDemo()

    rootGroup = display.newGroup()
    group:insert(rootGroup)

    local bg = display.newRect(rootGroup, VCX, VCY, VW, VH)
    bg:setFillColor(unpack(THEME.bgDark))

    uiGroup = display.newGroup()
    rootGroup:insert(uiGroup)

    topGroup = display.newGroup()
    rootGroup:insert(topGroup)

    local title = display.newText({
        parent = uiGroup,
        text = "Как играть",
        x = 40, y = 60,
        fontSize = 30, font = native.systemFontBold,
        align = "left"
    })
    title.anchorX = 0
    title:setFillColor(1, 0.95, 0.8)

    hintLabel = display.newText({
        parent = uiGroup,
        text = "",
        x = VCX, y = 120,
        fontSize = 20, font = native.systemFont,
        align = "center", width = VW - 80
    })
    hintLabel:setFillColor(0.95, 0.95, 1)

    local skipButton = uiButton.new({
        label = "Пропустить",
        x = VW - 120, y = 60,
        width = 180, height = 50, cornerRadius = 12, fontSize = 18,
        fillColor = THEME.neutral, fillColorOver = THEME.neutralHi,
        fillColorDown = THEME.neutralDown,
        onPress = goToGameSkipped
    })
    uiGroup:insert(skipButton)

    drawField()
    drawHand()

    rootGroup.rotation = 90
    rootGroup.x = display.contentWidth
    rootGroup.y = 0

    advanceStage(S_BOX2)
end

function scene:hide(event)
    if event.phase == "will" then
        stopAnimation()
        stopAutoTimer()
    end
    if event.phase == "did" then
        composer.removeScene("scenes.demo")
    end
end

function scene:destroy(event)
    stopAnimation()
    stopAutoTimer()
    if handPulseTween then
        transition.cancel(handPulseTween); handPulseTween = nil
    end
    handGroup    = nil
    fieldGroup   = nil
    topGroup     = nil
    uiGroup      = nil
    rootGroup    = nil
    hintLabel    = nil
    boxSprites   = {}
    playerSprite = nil
end

scene:addEventListener("create",  scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)

return scene