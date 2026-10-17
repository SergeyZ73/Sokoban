-- modules/uiButton.lua
-- Универсальная кнопка: скругление, тень, блик, нажатие, enabled.
local M = {}

-- opts:
--   label, x, y, width, height
--   cornerRadius (default min(h/2,14))
--   fontSize, font
--   fillColor, fillColorOver, fillColorDown  -- {r,g,b}
--   labelColor  -- {r,g,b}
--   strokeColor -- {r,g,b,a} (опц.)
--   shadow      -- bool (default true)
--   onPress     -- function(event)
--   enabled     -- bool (default true)
function M.new(opts)
    opts = opts or {}
    local w       = opts.width  or 200
    local h       = opts.height or 50
    local radius  = opts.cornerRadius or math.min(h * 0.5, 14)
    local fill    = opts.fillColor     or {0.30, 0.55, 0.85}
    local fillHi  = opts.fillColorOver or {fill[1] + 0.15, fill[2] + 0.15, fill[3] + 0.15}
    local fillDn  = opts.fillColorDown or {fill[1] * 0.65, fill[2] * 0.65, fill[3] * 0.65}
    local tCol    = opts.labelColor or {1, 1, 1}
    local fSize   = opts.fontSize   or 18
    local font    = opts.font       or native.systemFontBold
    local enabled = opts.enabled ~= false

    local group = display.newGroup()
    group.x = opts.x or display.contentCenterX
    group.y = opts.y or display.contentCenterY

    -- Тень
    if opts.shadow ~= false then
        local sh = display.newRoundedRect(group, 0, 3, w, h, radius)
        sh:setFillColor(0, 0, 0, 0.30)
        group.shadow = sh
    end

    -- Фон
    local bg = display.newRoundedRect(group, 0, 0, w, h, radius)
    bg:setFillColor(fill[1], fill[2], fill[3])
    bg.strokeWidth = 2
    if opts.strokeColor then
        bg:setStrokeColor(opts.strokeColor[1], opts.strokeColor[2],
                          opts.strokeColor[3], opts.strokeColor[4] or 1)
    else
        bg:setStrokeColor(1, 1, 1, 0.30)
    end
    group.bg = bg

    -- Блик сверху
    local hl = display.newRoundedRect(group, 0, -h * 0.22,
                                      w - 8, h * 0.5,
                                      math.max(4, radius - 4))
    hl:setFillColor(1, 1, 1, 0.14)

    -- Текст
    local text = display.newText({
        parent = group, text = opts.label or "",
        x = 0, y = 0, fontSize = fSize, font = font
    })
    text:setFillColor(tCol[1], tCol[2], tCol[3])
    group.label = text

    -- Взаимодействие
    bg.isHitTestable = true
    local isDown = false
    local function setFill(c) bg:setFillColor(c[1], c[2], c[3]) end

    bg:addEventListener("touch", function(event)
        if not enabled then return true end

        if event.phase == "began" then
            display.getCurrentStage():setFocus(bg, event.id)
            isDown = true
            setFill(fillDn)
            transition.to(group, { xScale = 0.95, yScale = 0.95, time = 70 })
        elseif event.phase == "moved" then
            local inside = math.abs(event.x - group.x) < w * 0.5
                       and math.abs(event.y - group.y) < h * 0.5
            if inside and not isDown then
                isDown = true; setFill(fillDn)
            elseif not inside and isDown then
                isDown = false; setFill(fillHi)
            end
        else
            display.getCurrentStage():setFocus(bg, nil)
            transition.to(group, { xScale = 1, yScale = 1, time = 110 })
            if event.phase == "ended" and isDown then
                setFill(fillHi)
                if opts.onPress then opts.onPress(event) end
            else
                setFill(fill)
            end
            isDown = false
        end
        return true
    end)

    function group:setEnabled(state)
        enabled = state and true or false
        self.alpha = enabled and 1 or 0.45
        bg.isHitTestable = enabled
    end
    function group:setLabel(s) text.text = s end
    function group:isEnabled() return enabled end

    return group
end

return M