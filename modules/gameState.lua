-- modules/gameState.lua
local gameState = {}

function gameState.new()
    return {
        currentLevel = 1,          -- номер текущего уровня
        playerPos = {x=0, y=0},    -- позиция игрока
        boxes = {},                -- таблица ящиков { {x,y}, ... }
        targets = {},              -- таблица целей (для быстрой проверки)
        walls = {},                -- таблица стен (для столкновений)
        moves = 0,                 -- количество ходов
        maxLevel = 1,              -- максимальный пройденный уровень (для продолжения)
        completed = {}             -- массив булевых, какие уровни пройдены
    }
end

return gameState