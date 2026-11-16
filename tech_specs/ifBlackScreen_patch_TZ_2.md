Что делать при чёрном экране: замена Composer на sceneManager
Дополнение к Socoban_TZ_2.md (v1.6). Применяется, если при запуске проекта виден чёрный экран, а scene:create не вызывается. Документ описывает диагностику, обходное решение и правила миграции.

1. Назначение
В некоторых сборках Solar2D (подтверждено на 3.0.0, Build 2025.3721) библиотека composer перестаёт активировать модульные сцены:

composer.gotoScene("scenes.menu") загружает модуль (require срабатывает),

composer.getSceneName("current") возвращает "scenes.menu",

но scene:create и scene:show не вызываются,

на экране — чёрный фон, ошибок в консоли нет.

Это не ошибка проекта и не ошибка конкретной сцены. Это регрессия в рантайме Composer. Ни путь проекта, ни кириллица в путях, ни содержимое build.settings на это не влияют.

Документ описывает, как заменить Composer на собственную реализацию modules/sceneManager.lua (~40 строк), совместимую с архитектурой Socoban_TZ_2.md.

2. Диагностика (подтверждение бага)
Заменить main.lua на минимальный тест:

lua
print("[main] START")
local composer = require("composer")

local frameCount = 0
Runtime:addEventListener("enterFrame", function()
    frameCount = frameCount + 1
    if frameCount == 1 or frameCount == 60 then
        print("[frame]", frameCount)
    end
end)

local scene = composer.newScene()
function scene:create(event)
    print("[test] create called")
    display.newRect(self.view, 200, 200, 150, 150):setFillColor(0, 1, 0)
end
function scene:show(event)
    print("[test] show", event.phase)
end

print("[main] calling gotoScene")
composer.gotoScene(scene)  -- inline scene
Признак бага Composer:

text
[main] START
[main] calling gotoScene
[frame] 1
[frame] 60
[test] create called отсутствует, зелёный квадрат не появляется — значит рантайм сломан. Переходим к §3.

Если create вызывается и квадрат виден — баг не воспроизводится, документ не применяется, проект работает по исходному ТЗ.

3. Архитектура sceneManager
sceneManager — синглтон-модуль, реализующий минимальный жизненный цикл сцены, эквивалентный по смыслу composer.newScene + gotoScene:

Уничтожить предыдущую сцену (если есть): снять все ссылки, вызвать destroy, removeSelf корневой группы, collectgarbage.

Создать новую корневую группу.

Загрузить модуль сцены через require.

Вызвать mod.create(view, params) — аналог scene:create.

Вызвать mod.show() — аналог scene:show("did").

Сцена — обычный Lua-модуль с тремя необязательными функциями: M.create(view, params), M.show(), M.destroy(). Никаких composer.newScene() и self.view.

Гарантии:

Переход — синхронный: старый destroy вызывается до create нового.

Предыдущая сцена полностью уничтожается: removeScene и защита от воскрешения save.json (пункт 7.7 основного ТЗ) не нужны — их функции берёт на себя sceneManager.

Все ссылки предыдущей сцены зануляются в её собственном M.destroy.

4. Файл modules/sceneManager.lua
lua
local M = {}

local currentName   = nil
local currentModule = nil
local currentView   = nil

local function cleanup()
    if currentModule and currentModule.destroy then
        pcall(function() currentModule.destroy() end)
    end
    if currentView then
        currentView:removeSelf()
    end
    currentName   = nil
    currentModule = nil
    currentView   = nil
    collectgarbage("collect")
end

function M.go(name, params)
    cleanup()

    local view = display.newGroup()
    local mod  = require(name)

    currentName   = name
    currentModule = mod
    currentView   = view

    if mod.create then mod.create(view, params or {}) end
    if mod.show   then mod.show() end
end

function M.getCurrent()
    return currentName
end

function M.destroyCurrent()
    cleanup()
end

return M
main.lua:

lua
print("[main] START")
local sm = require("modules.sceneManager")
sm.go("scenes.menu")
5. Правила миграции сцен
Каждая сцена из основного ТЗ (menu, demo, game, levelSelect, credits) переписывается по шаблону.

5.1. Общий шаблон
Было (Composer):

lua
local composer = require("composer")
local scene = composer.newScene()

function scene:create(event)
    local sg = self.view
    rootGroup = display.newGroup()
    sg:insert(rootGroup)
    ...
    rootGroup.rotation = 90
    rootGroup.x = display.contentWidth
    rootGroup.y = 0
end

function scene:show(event)
    if event.phase == "will" then ... end
    if event.phase == "did"  then ... end
end

function scene:hide(event)
    if event.phase == "will" then ... end
end

function scene:destroy(event)
    ...
end

return scene
Стало (sceneManager):

lua
local M = {}

local rootGroup

function M.create(view, params)
    rootGroup = view
    ...
    rootGroup.rotation = 90
    rootGroup.x = display.contentWidth
    rootGroup.y = 0
end

function M.show()
    ...
end

function M.destroy()
    ...
    rootGroup = nil
end

return M
5.2. Соответствие фаз жизненного цикла
Composer    sceneManager
scene:create(event) M.create(view, params)
scene:show("will")  начало M.create или начало M.show (см. 5.3)
scene:show("did")   M.show()
scene:hide("will")  убрать целиком; логика переносится в M.destroy
scene:destroy(event)    M.destroy()
composer.gotoScene(name, {params = X})  sm.go(name, X)
composer.removeScene(name, false)   убрать (sceneManager уничтожает сцену сам)
5.3. scene:show("will") — куда девать
В основном ТЗ фаза show(will) используется для двух разных задач:

Инициализация состояния сцены, которая должна произойти до первого кадра (например, undo.push(makeSnapshot()), если undo.depth() == 0). Переносится в конец M.create — сразу после отрисовки, но до возврата в sceneManager.

Подключение listener’ов (Runtime:addEventListener("key", onKey)). Переносится в начало M.show — listener будет активен, когда сцена уже видна.

Пример из game.lua:

lua
function M.create(view, params)
    rootGroup = view
    -- ... построение UI, loadLevel, drawField ...

    -- Бывшее scene:show("will") в части undo-инициализации
    if undo.depth() == 0 and state then
        undo.push(makeSnapshot())
    end
end

function M.show()
    -- Бывшее scene:show("will") в части listener'ов
    onKey = function(ev) ... end
    Runtime:addEventListener("key", onKey)
end
5.4. Что заменяется на что
Никакого composer и self.view. Корневая группа приходит в M.create(view, params).

self.view заменяется на view во всех местах, где раньше к нему обращались (например, display.newRect(view, ...)).

view — это бывший rootGroup. Отдельный display.newGroup() для root больше не создаётся. Поворот (view.rotation = 90), позиционирование (view.x = display.contentWidth, view.y = 0) применяются к view напрямую, в конце M.create. Формула §4.2 (lx = event.y; ly = display.contentWidth - event.x) не меняется: overlay.parent == view, view.rotation == 90, view.x == display.contentWidth, view.y == 0.

event.params из основного ТЗ приходит как params. Замена: composer.gotoScene("scenes.game", {params = {level = 5}}) → sm.go("scenes.game", {level = 5}). Внутри M.create(view, params) уровень читается как params.level.

scene:show(did) → M.show(). Развилки event.phase больше нет.

scene:hide(will) → убрать целиком. Снятие listener’ов, стоп анимаций, save.saveState(state) переносятся в M.destroy.

scene:destroy → M.destroy(). Отмена таймеров, cancelAllFlashes, undo.unsubscribe(undoCallback), зануление ссылок.

composer.removeScene(...) удаляется везде. sceneManager сам уничтожает предыдущую сцену при sm.go.

Переходы — sm.go("scenes.menu") вместо composer.gotoScene("scenes.menu"). Сцена, делающая переход, добавляет local sm = require("modules.sceneManager").

6. Что переносится из основного ТЗ без изменений
Следующие пункты Socoban_TZ_2.md действуют без правок:

§3.1 — «один кадр = один шаг», разделение маркеров.

§4 — ориентация, поворот view, координаты, hit-testing. Единственное отличие: view — это корневая группа сцены, приходящая в M.create.

§5 — модель управления (тапы, клавиатура).

§7.1–7.6 — theme, uiButton, gameState, save, undo, data — не меняются вообще.

§7.8.1 — точное позиционирование стрелки-«руки».

§7.9.1–7.9.4 — порядок групп, восстановление сохранённой партии, loadLevel без алиасинга, flashBox с конечным счётчиком, undo.subscribe с парным unsubscribe, positionOverlay.

§8–9 — формат карт, computeVoids, findDeliveryPath, animatePath + stepAnim с двумя guard’ами.

§12 — известные ограничения и «грабли». Пункт 5 основного ТЗ («demo.lua дублирует BFS») остаётся в силе.

§15.1–15.18 — все правила Solar2D.

7. Что теряется при переходе на sceneManager
Эти фичи Composer не поддерживаются и не эмулируются:

Переходы с эффектами (effect = "fade", time = 300). Переключение мгновенное.

Кэширование сцен. composer.gotoScene с одной и той же сценой вызывает show, но не create. sceneManager всегда пересоздаёт сцену целиком.

hide как отдельная фаза. Раньше сцена могла уйти в фон без уничтожения (например, для показа модалки поверх). Теперь сцена либо активна, либо уничтожена.

Одновременное существование двух сцен. Модальные окна поверх игровой сцены придётся рисовать внутри самой сцены (HUD-группой), а не отдельной Composer-сценой.

composer.removeScene(name) как отдельный API. Заменяется автоматическим уничтожением при следующем sm.go.

Эти ограничения приемлемы для Сокобана (5 статических сцен, без модалок и переходов), но должны быть учтены, если проект будет расширяться. При необходимости эффекты реализуются вручную: transition.to(currentView, {alpha = 0, ...}) перед cleanup.

8. Как вернуться к Composer
Если в будущем Composer починят (в новой сборке Solar2D):

Заменить main.lua на исходный вариант из §2.3 основного ТЗ.

В каждой сцене вернуть composer.newScene(), scene:create(self, event), scene:show, scene:hide, scene:destroy.

Восстановить вызовы composer.gotoScene и composer.removeScene в menu.lua, demo.lua, game.lua, levelSelect.lua.

Удалить modules/sceneManager.lua.

Логика самих сцен (отрисовка поля, BFS, undo, сохранения) при этом не меняется — вся разница только в обёртке жизненного цикла. Поэтому обратная миграция безопасна.

9. Чек-лист приёмки для sceneManager
□ main.lua вызывает sm.go("scenes.menu") и печатает [main] START.
□ Меню отрисовывается полностью: фон, заголовок, 6 кнопок, поворот view.rotation = 90.
□ Кнопка «Новая игра» ведёт в scenes.demo (или scenes.game, если есть сохранение).
□ Кнопка «Как играть» ведёт в scenes.demo.
□ Кнопка «Выбрать уровень» ведёт в scenes.levelSelect.
□ Кнопка «Об игре» ведёт в scenes.credits.
□ Кнопка «Назад» из любой сцены ведёт в scenes.menu.
□ Повторный вход в любую сцену не оставляет артефактов предыдущей сессии: фон, поле, кнопки — только от текущей сцены.
□ Переходы мгновенные, без подвисаний.
□ При выходе из scenes.game вызывается save.saveState(state) (в M.destroy).
□ При выходе из scenes.game вызывается undo.unsubscribe(undoCallback).
□ Таймеры (animTimer, flashTimers, demoAnimTimer, autoTapTimer) отменяются в M.destroy.
□ Все пункты §14 основного ТЗ выполняются.
□ Все пункты §15 основного ТЗ (forward declarations, hit-testing, координаты) соблюдены.
□ params передаются через второй аргумент sm.go и читаются как params.<field> (без params.params).
□ Keyboard listener из бывшего scene:show("will") подключается в M.show, снимается в M.destroy.
□ Инициализация undo из бывшего scene:show("will") выполняется в конце M.create.
□ view поворачивается на 90° и позиционируется в M.create; формула §4.2 для overlay работает без изменений.
10. Ссылки
Основной ТЗ: Socoban_TZ_2.md (v1.6).

Проблема с Composer в Solar2D 3.0.0 — известная регрессия, воспроизводится на Build 2025.3721.

Обходное решение — modules/sceneManager.lua (§4).

Возврат к Composer — §8.