-- modules/save.lua
-- Два файла в DocumentsDirectory:
--   save.json     — текущая партия (уровень, ходы, позиция игрока, ящики)
--   progress.json — какие уровни пройдены
local M = {}

local json = require("json")   -- встроенная библиотека Solar2D/Corona

local SAVE_FILE     = "save.json"
local PROGRESS_FILE = "progress.json"

local function readFile(name)
    local path = system.pathForFile(name, system.DocumentsDirectory)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function writeFile(name, content)
    local path = system.pathForFile(name, system.DocumentsDirectory)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

-- ----- Партия -------------------------------------------------

function M.saveState(state)
    if not state then return end
    local data = {
        currentLevel = state.currentLevel,
        moves        = state.moves,
        playerPos    = state.playerPos,
        boxes        = state.boxes,
        levelName    = state.levelName,
    }
    writeFile(SAVE_FILE, json.encode(data))
end

function M.loadState()
    local raw = readFile(SAVE_FILE)
    if not raw then return nil end

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then return nil end

    local gs = require("modules.gameState")
    local state = gs.new()
    state.currentLevel = data.currentLevel or 1
    state.moves        = data.moves or 0
    state.playerPos    = data.playerPos
    state.boxes        = data.boxes or {}
    state.levelName    = data.levelName
    return state
end

-- Есть ли сохранённая партия (валидный save.json)
function M.hasProgress()
    local raw = readFile(SAVE_FILE)
    if not raw then return false end
    local ok, data = pcall(json.decode, raw)
    return ok and type(data) == "table"
end

-- ----- Прогресс -----------------------------------------------

function M._loadProgress()
    local raw = readFile(PROGRESS_FILE)
    if not raw then return {} end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then return {} end
    return data
end

function M.markCompleted(levelIndex)
    local p = M._loadProgress()
    p[tostring(levelIndex)] = true
    writeFile(PROGRESS_FILE, json.encode(p))
end

function M.isCompleted(levelIndex)
    local p = M._loadProgress()
    return p[tostring(levelIndex)] == true
end

-- Все уровни от 1 до total отмечены как пройденные?
function M.areAllLevelsCompleted(total)
    local p = M._loadProgress()
    for i = 1, total do
        if p[tostring(i)] ~= true then return false end
    end
    return true
end

-- ----- Полная очистка -----------------------------------------

function M.wipeAll()
    os.remove(system.pathForFile(SAVE_FILE,     system.DocumentsDirectory))
    os.remove(system.pathForFile(PROGRESS_FILE, system.DocumentsDirectory))
end

return M