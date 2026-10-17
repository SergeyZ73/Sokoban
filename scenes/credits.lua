-- scenes/credits.lua
local composer = require("composer")
local uiButton = require("modules.uiButton")
local THEME = require("modules.theme")

local scene = composer.newScene()
local rootGroup = nil

-- Ландшафтные координаты
local VW, VH, VCX, VCY

function scene:create(event)
    VW  = display.contentHeight    -- 1280
    VH  = display.contentWidth     -- 720
    VCX = VW / 2
    VCY = VH / 2

    local group = self.view
    rootGroup = display.newGroup()
    group:insert(rootGroup)

    -- Фон
    local bg = display.newRect(rootGroup, VCX, VCY, VW, VH)
    bg:setFillColor(unpack(THEME.bgDark))

    -- Акцентная полоса сверху
    local topAccent = display.newRect(rootGroup, VCX, 2, VW, 4)
    topAccent:setFillColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.6)

    -- Заголовок
    local title = display.newText({
        parent = rootGroup, text = "Об игре",
        x = VCX, y = 50, fontSize = 60, font = native.systemFontBold
    })
    title:setFillColor(1, 0.95, 0.8)

    -- Текстовый блок
    local DIST = 34
    local textY = 110
    local function addLine(text, size, color, spacing)
        local obj = display.newText({
            parent = rootGroup, text = text, x = VCX, y = textY,
            fontSize = size or 28, font = native.systemFont, align = "center"
        })
        obj:setFillColor(unpack(color or {1, 1, 1}))
        textY = textY + (spacing or DIST)
    end

    addLine("ПРИЛОЖЕНИЕ", 32, {1, 0.95, 0.8}, DIST)
    addLine("SergeyZ73 & deepseek & gigachat", 28, {0.75, 0.75, 0.85}, 2 * DIST)

    addLine("УРОВНИ", 32, {1, 0.95, 0.8}, DIST)
    addLine("Microban", 30, {1, 0.95, 0.8}, DIST)
    addLine("Copyright: David W. Skinner", 28, {1, 0.85, 0.65}, DIST)
    addLine("E-Mail: sasquatch@bentonrea.com", 28, {0.75, 0.75, 0.85}, DIST)
    addLine("Web Site:", 28, {0.75, 0.75, 0.85}, DIST)
    addLine("http://users.bentonrea.com/~sasquatch/sokoban/", 22, {0.7, 0.85, 1}, DIST)
    addLine("Уровни распространяются свободно", 28, {0.7, 0.9, 0.7}, DIST)
    addLine("при условии указания авторства.", 28, {0.7, 0.9, 0.7}, DIST)

    -- Кнопка «Назад»
    local backBtn = uiButton.new({
        label = "Назад",
        x = VCX, y = textY + 2 * DIST,
        width = 400, height = 100,
        cornerRadius = 50,
        fontSize = 36,
        fillColor     = THEME.neutral,
        fillColorOver = THEME.neutralHi,
        fillColorDown = THEME.neutralDown,
        onPress = function()
            composer.gotoScene("scenes.menu", { effect = "fade", time = 300 })
        end
    })
    rootGroup:insert(backBtn)

    -- ПОВОРОТ
    rootGroup.rotation = 90
    rootGroup.x = display.contentWidth    -- 720
    rootGroup.y = 0
end

function scene:show(event) end
function scene:hide(event) end
function scene:destroy(event)
    rootGroup = nil
end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)

return scene