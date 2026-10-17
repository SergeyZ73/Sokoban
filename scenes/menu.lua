-- scenes/menu.lua
local composer  = require("composer")
local save      = require("modules.save")
local gameState = require("modules.gameState")
local uiButton  = require("modules.uiButton")
local THEME     = require("modules.theme")

local scene = composer.newScene()
local startBtn  = nil
local rootGroup = nil

local VW, VH, VCX, VCY

local function refreshStartButton()
    if not startBtn or not startBtn.setLabel then return end
    if save.hasProgress() then startBtn:setLabel("Продолжить")
    else startBtn:setLabel("Новая игра") end
end

local function onStartPress()
    if save.hasProgress() then
        -- Продолжаем сохранённую партию
        composer.gotoScene("scenes.game", { effect = "fade", time = 300 })
    else
        -- Новая игра — сначала demo, чтобы показать механику
        composer.gotoScene("scenes.demo", { effect = "fade", time = 300 })
    end
end

local function onHowToPlay()
    composer.gotoScene("scenes.demo", { effect = "fade", time = 300 })
end

function scene:create(event)
    VW  = display.contentHeight    -- 720
    VH  = display.contentWidth     -- 1280
    VCX = VW / 2
    VCY = VH / 2

    local group = self.view
    rootGroup = display.newGroup()
    group:insert(rootGroup)

    local bg = display.newRect(rootGroup, VCX, VCY, VW, VH)
    bg:setFillColor(unpack(THEME.bgDark))

    local topAccent = display.newRect(rootGroup, VCX, 2, VW, 4)
    topAccent:setFillColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.6)

    local title = display.newText({
        parent = rootGroup, text = "СОКОБАН",
        x = VCX, y = 80,
        fontSize = 56, font = native.systemFontBold
    })
    title:setFillColor(1, 0.95, 0.8)

    local subtitle = display.newText({
        parent = rootGroup, text = "классическая головоломка",
        x = VCX, y = 132,
        fontSize = 18, font = native.systemFont
    })
    subtitle:setFillColor(0.7, 0.7, 0.8)

    local function onSelectLevel()
        composer.gotoScene("scenes.levelSelect", { effect = "fade", time = 300 })
    end

    local function onResetProgress()
        native.showAlert(
            "Сброс прогресса",
            "Все сохранения, пройденные уровни и отметки будут удалены.\nПродолжить?",
            { "Отмена", "Сбросить" },
            function(event)
                if event.action ~= "clicked" or event.index ~= 2 then return end
                save.wipeAll()
                refreshStartButton()
                native.showAlert("Готово", "Все сохранения удалены.", {"OK"})
            end
        )
    end

    local function onCredits()
        composer.gotoScene("scenes.credits", { effect = "fade", time = 300 })
    end

    local function onExit() os.exit() end

    local function theme3(name)
        if name == "danger" then return THEME.danger, THEME.dangerHi, THEME.dangerDown end
        if name == "gold"   then return THEME.gold,   THEME.goldHi,   THEME.goldDown   end
        return THEME.primary, THEME.primaryHi, THEME.primaryDown
    end

    local btnW, btnH = 520, 58
    local spacing    = 12
    local firstY     = 200

    local buttons = {
        { label = "Новая игра",      theme = "primary", onPress = onStartPress, isStart = true },
        { label = "Как играть",      theme = "primary", onPress = onHowToPlay },
        { label = "Выбрать уровень", theme = "primary", onPress = onSelectLevel },
        { label = "Сброс прогресса", theme = "danger",  onPress = onResetProgress },
        { label = "Об игре",         theme = "gold",    onPress = onCredits },
        { label = "Выйти",           theme = "danger",  onPress = onExit },
    }

    for i, b in ipairs(buttons) do
        local base, hi, dn = theme3(b.theme)
        local btn = uiButton.new({
            label = b.label,
            x = VCX, y = firstY + (i - 1) * (btnH + spacing),
            width = btnW, height = btnH,
            cornerRadius = btnH / 2, fontSize = 20,
            fillColor = base, fillColorOver = hi, fillColorDown = dn,
            onPress = b.onPress
        })
        rootGroup:insert(btn)
        if b.isStart then startBtn = btn end
    end

    refreshStartButton()

    rootGroup.rotation = 90
    rootGroup.x = display.contentWidth
    rootGroup.y = 0
end

function scene:show(event)
    if event.phase == "did" then refreshStartButton() end
end

function scene:hide(event) end

function scene:destroy(event)
    startBtn  = nil
    rootGroup = nil
end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)

return scene