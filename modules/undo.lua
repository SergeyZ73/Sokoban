-- modules/undo.lua
-- Полная история ходов текущей игровой сессии.
-- history[1]  = исходное состояние уровня
-- history[N]  = текущее состояние (N = depth)
-- Откат = удалить последний снимок и вернуть предыдущий.
-- Очищается при рестарте уровня, победе и выходе из сцены.
--
-- Модуль универсален: он не знает структуры снимка.
-- Снимок — произвольная Lua-таблица, кладётся как есть (глубокой копией).

local M = {}

local MAX_HISTORY = 5000
local history = {}
local listeners = {}

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local copy = {}
    for k, val in pairs(v) do
        copy[k] = deepCopy(val)
    end
    return copy
end

local function notify()
    for i = 1, #listeners do
        listeners[i](M.canUndo(), M.depth())
    end
end

function M.clear()
    history = {}
    notify()
end

function M.push(snapshot)
    history[#history + 1] = deepCopy(snapshot)
    if #history > MAX_HISTORY then
        table.remove(history, 1)
    end
    notify()
end

function M.canUndo()
    return #history > 1
end

function M.undo()
    if #history <= 1 then return nil end
    table.remove(history)
    notify()
    return deepCopy(history[#history])
end

function M.peek()
    if #history == 0 then return nil end
    return deepCopy(history[#history])
end

function M.depth()
    return #history
end

function M.moveCount()
    return math.max(0, #history - 1)
end

function M.exportAll()
    local out = {}
    for i = 1, #history do
        out[i] = deepCopy(history[i])
    end
    return out
end

function M.subscribe(fn)
    listeners[#listeners + 1] = fn
    fn(M.canUndo(), M.depth())
    return fn
end

function M.unsubscribe(fn)
    for i = #listeners, 1, -1 do
        if listeners[i] == fn then
            table.remove(listeners, i)
        end
    end
end

return M