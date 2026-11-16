# Спецификация проекта «Сокобан» (v1.6)

Платформа: Solar2D (Corona SDK), Lua
Целевая платформа: Android (iOS-специфика не блокирует сборку, но и не приоритет)
Ориентация: portrait в манифесте, UI рисуется в landscape-координатах через поворот rootGroup на 90°
Звук: не используется
Уровни: файл data.lua считается готовым и поставляется как есть
Иконка: дефолтная Solar2D (кастомная опциональна)

Документ описывает все файлы проекта и сквозные сценарии — достаточно, чтобы воспроизвести игру с нуля. В v1.6 в соответствующие разделы встроены все известные «грабли» Solar2D и принятые обходные решения (костыли), а также закрыты дополнительные типовые баги, выявленные при сборке: смещение стрелки-«руки» на соседнюю клетку в demo и потеря сохранённого состояния при нажатии «Продолжить».


# 0. Что нового в v1.6

§7.8 (demo.lua) — точное позиционирование стрелки-«руки». Стрелка должна позиционироваться по формуле, при которой острие касается верхней грани целевой клетки, а не висит на целую клетку выше. Прежняя формула py = fieldY + (ty - 0.5) * cellSize - cellSize * 0.95 для цели (4,5) давала py = fieldY + 3.55·cellSize, что соответствует клетке (4,4) — то есть верхнему ящику. Пользователь читает это как «стрелка показывает на соседнюю клетку». См. §15.17.

§7.9 (game.lua) — восстановление сохранённой партии при «Продолжить». loadLevel перезаписывает state.boxes, state.playerPos, state.moves начальной раскладкой карты (это необходимо — уровень всегда должен сначала распарситься). При загрузке через save.loadState() сохранённые поля обязаны быть прочитаны в локальные переменные до loadLevel и восстановлены после. Иначе пользователь, нажавший «Продолжить», видит уровень с самого начала: ходы и позиции ящиков теряются, счётчик ходов обнулён, undo-база — стартовая карта. См. §15.18.

§12 — добавлены пункты 27 (стрелка demo смещена на соседнюю клетку), 28 (Continue не восстанавливает сохранённую партию).

§14.1 — добавлены четыре пункта чек-листа: Continue восстанавливает позиции ящиков, Continue восстанавливает счётчик ходов, стрелка demo точно над целевой клеткой на каждом этапе, Continue с несовместимым save.json не падает.

§15.17 — новое правило: позиционирование overlay-стрелок, «руки» и любых указателей в повёрнутой сцене.

§15.18 — новое правило: порядок read-save / load-level / apply-save при загрузке партии.

Что было в v1.5 (сохраняется):

§7.9 (loadLevel) — запрет алиасинга на data.lua. loadLevel обязан создать локальную копию lvl.map перед паддингом строк пробелами. См. §15.16.

§7.9 (flashBox) — таймер вспышки: конечное число повторов N (например, 6) вместо timer.performWithDelay(..., -1). Handle сохраняется в flashTimers и отменяется через cancelAllFlashes.

§7.9 (undo.subscribe) — callback хранится в локальной переменной сцены и передаётся в undo.unsubscribe в scene:destroy.

§15.15 — только ASCII в комментариях.

§15.16 — modules/data.lua — read-only.

Что было в v1.4 (сохраняется):

§7.9 (game.lua) — переход на следующий уровень: nextLevel вычисляется из ТЕКУЩЕГО state до его замены на gameState.new().

§7.9 (game.lua) — overlay переразмечается через positionOverlay() после каждого loadLevel/resetLevel/goToNextLevel.

§5.2 (клавиатура) — во время isAnimating клавиши-стрелки, R и Z игнорируются.

Что было в v1.3 (сохраняется):

§9.3 (animatePath) — отказ от timer.performWithDelay(..., -1) в пользу одноразовых таймеров с явной переустановкой и двумя guard'ами.

§7.8 (demo.lua) — симметричное правило для stepDemoAnim: guard в начале и после tryMove.

Что было в v1.2 (сохраняется):

§3.1 — общее правило «один кадр = один шаг» и правило разделения маркеров.

§7.8 (demo.lua): tryDeliverTo пошагово через timer.performWithDelay(MOVE_DELAY, step, 1), advanceStage — из onComplete.

§7.10 (levelSelect.lua): двухпроходный рендер миниатюры.


# 1. Решённые вопросы
   Вопрос  Решение
1   Кол-во уровней  200. Формат data.lua фиксирован, файл поставляется готовым
2   Иконка / LaunchScreen   Опциональны, по умолчанию — стандартные ассеты Solar2D
3   Звук    Не нужен, модуль sound.lua не создаётся
4   Платформа   Android (приоритет). os.exit() в меню допустим
5   Разбиение data.lua  Оставляем единым файлом
6   Ориентация  Portrait в манифесте, UI через rootGroup.rotation = 90 (см. §4)
7   Обработка тача  Только через overlay в game/demo; все кнопки — прямые дети rootGroup (см. §4.4, §4.5)

# 2. Конфигурация платформы

2.1. config.lua
Параметр    Значение
content.width   720
content.height  1280
scale   "letterbox"
fps 60
2.2. build.settings
Секция  Значение
splashScreen.enable false
orientation.default "portrait"
orientation.supported   { "portrait" }
android.usesPermissions пусто
iphone.xcassets "Images.xcassets" (опционально)
iphone.plist.UIStatusBarHidden  false
iphone.plist.UILaunchStoryboardName "LaunchScreen"
plugins пусто
excludeFiles.all    Icon.png, Icon-*dpi.png, Images.xcassets
excludeFiles.android    LaunchScreen.storyboardc
Плагины (AdMob, IAP) не подключаются.

2.3. main.lua
lua
local composer = require("composer")
composer.gotoScene("scenes.menu")

# 3. Архитектурные принципы

Никакого ООП на метатаблицах. Данные — {x=, y=}. Логика перемещения — в tryMove. Модули — синглтоны-таблицы.

Сцены — Composer-scene. create/show/hide/destroy.

Модули нижнего уровня не зависят от верхних. Исключение — save → gameState.

Комментарии — «почему», а не «что». Только ASCII (см. §15.15).

Магические числа — в константы.

Публично только return M.

Все локальные функции, вызываемые из колбэков (timer, transition, Runtime:addEventListener, native.showAlert, object listeners), обязаны быть объявлены в блоке forward declarations (см. §15.1).

3.1. Общее правило визуального состояния
Правило «один кадр = один шаг».

Любое изменение игрового состояния, которое пользователь должен увидеть, отображается пошагово: одна дискретная единица изменения = один вызов drawField() (или точечного апдейта спрайта) = минимум один кадр. Мгновенная перерисовка финального состояния после многократного изменения данных (for ... do tryMove() end) запрещена — она даёт эффект «телепорта».

Для многошаговых операций (авто-доставка, скриптованная демо-анимация, любые tween-серии) применяется timer.performWithDelay(delay, step, 1) с сохранением handle, с двумя guard'ами (§9.3) и вызовом onComplete после последнего шага. onComplete — единственное место, где переключается этап / сохраняется снапшот / выставляется итоговое состояние.

Правило разделения маркеров.

Если на одной клетке могут одновременно находиться несколько логических объектов (ящик + цель, игрок + цель), они рисуются разными примитивами поверх друга в фиксированном порядке, а не «одним цветом на клетку». Совпадение строк/столбцов нескольких таких клеток не должно давать визуальных полос: маркеры обязаны читаться как отдельные фигуры (крест ≠ квадрат ≠ круг).


# 4. Ориентация, поворот UI, координаты и hit-testing

Это самый хрупкий участок проекта. Всё, что ниже, обязательно к соблюдению.

4.1. Схема поворота
config.lua — portrait 720×1280. Внутри каждой сцены — rootGroup с:

lua
rootGroup.rotation = 90
rootGroup.x = display.contentWidth   -- 720
rootGroup.y = 0
Виртуальные размеры внутри сцены:

Константа   Значение    Формула
VW  1280    display.contentHeight
VH  720 display.contentWidth
VCX 640 VW / 2
VCY 360 VH / 2
Поворот выполняется один раз в конце scene:create. В destroy — все ссылки зануляются.

4.2. Обратное преобразование тапа для overlay в game/demo
Единственное место, где допустимо «сырое» преобразование event.x/y в локальные координаты поля — обработчик тапа на overlay, чей parent == rootGroup, и rootGroup.rotation == 90:

lua
local lx = event.y
local ly = display.contentWidth - event.x
Формула верна только при rotation=90, x=720, y=0. Она тихо сломается при любом изменении точки/угла поворота. Для всех остальных обработчиков — только contentToLocal/contentBounds.

4.3. Правила сцен
Всё рисуется в rootGroup, поворот — один раз в конце create.

destroy зануляет все ссылки (fieldGroup, uiGroup, handGroup, topGroup, hintLabel, boxSprites, playerSprite, undoCallback).

Таймеры останавливаются в hide и destroy.

composer.removeScene(name) вызывается в hide(will) для stateful-сцен (demo, game, levelSelect) — иначе повторный вход покажет остатки предыдущей сессии.

4.4. Координатные пространства
В Solar2D обработчики touch/tap всегда получают event.x/y в screen-space (координаты дисплея 720×1280), независимо от того, в какой группе находится event.target. Это источник тихих ошибок попадания.

Правила:

Перевод в локальные координаты rootGroup — только формула §4.2, и только для прямого ребёнка rootGroup (то есть overlay).

Запрещено сравнивать event.x/y с group.x/y внутри повёрнутой или вложенной иерархии — это всегда даёт неверный результат.

Проверка попадания внутри произвольного объекта — через obj.contentBounds (мировые границы с учётом всех трансформаций родичей) либо obj:contentToLocal(event.x, event.y).

Декоративные объекты (shadow, блики, подписи, pulse-круги) обязаны иметь isHitTestable = false.

alpha = 0 не отключает hit-test. Прозрачный объект продолжает ловить тапы, пока isHitTestable = true. Отключать только через isHitTestable = false.

4.5. Порядок групп (z-order)
Порядок добавления детей в Solar2D = z-order: последний добавленный — сверху, первым получает hit-test.

Обязательный порядок в rootGroup для всех сцен:

Фон (bg).

Основной контент:

в game — boardGroup (внутри: fieldGroup, затем handGroup);

в menu/levelSelect/credits — панель контента.

Прозрачный интерактивный overlay (только в game/demo), alpha = 0.01, isHitTestable = true — ловит тапы по полю.

HUD и интерактивные элементы управления: hudGroup в game, все кнопки в menu/levelSelect/credits.

Кнопки/интерактив — всегда последними, иначе overlay съест их тапы. Overlay — обязательно до HUD.

4.6. Поворот и contentBounds
transition.to(group, {...}) на группе работает, но не обновляет contentBounds детей мгновенно. Для hit-теста во время анимации использовать event.x/y + obj:contentToLocal.

4.7. display.newXxx без parent
display.newText, newRect, newCircle, newRoundedRect без первого аргумента-родителя создают объект в корне сцены, а не в текущей группе. Всегда либо передавать parent первым аргументом, либо вызывать group:insert(obj).

Для display.newText({...}) без x/y объект попадает в (0,0) родителя. Для подписи кнопки — либо x=0, y=0 в таблице, либо obj.x, obj.y = 0, 0.


# 5. Модель управления

5.1. Игровой экран (scenes/game.lua)
Управление — по клеткам. Логика в handleCellTap(x, y):

Ситуация    Реакция
Нет выделения, тап по ящику selectBox(idx)
Есть выделение, тап по тому же ящику    clearSelection()
Есть выделение, тап по другому ящику    selectBox(newIdx)
Есть выделение, тап по пустой клетке / цели tryDeliverTo(x, y)
Тап по стене/void с выделением  clearSelection() + flashRedSelected()
Тап по клетке с другим ящиком   flashRedSelected()
Тап по void без выделения   clearSelection()
Тап ловится прозрачным overlay (alpha = 0.01, isHitTestable = true), вставленным между boardGroup и hudGroup (см. §4.5). Во время isAnimating тапы игнорируются.

5.2. Клавиатура (desktop-отладка)
Клавиша Действие
up / down / left / right    tryMove(±1, 0/±1)
r   resetLevel()
z   undoMove()
Все клавиши игнорируются при isAnimating == true. Иначе нажатие стрелки или R/Z вклинивается в авто-доставку между тиками таймера, состояние полей рассинхронизируется с animQueue, а последующий вызов stepAnim работает с устаревшей геометрией. Guard ставится в самом начале onKey.

5.3. Демо-сцена
Управление то же. Дополнительно:

Подсказка-текст вверху.

Анимированная стрелка-«рука» с pulse-tween.

AUTO_TAP_DELAY = 3000 мс — автотап, если игрок не тапает.

MOVE_DELAY = 130 мс — шаг проигрывания пути авто-доставки (см. §3.1, §7.8).

Этапы строго фиксированы (см. §7.8).


# 6. Карта проекта
```text
project/
├── main.lua
├── config.lua
├── build.settings
│
├── scenes/
│   ├── menu.lua
│   ├── demo.lua
│   ├── game.lua
│   ├── levelSelect.lua
│   └── credits.lua
│
└── modules/
    ├── data.lua
    ├── gameState.lua
    ├── save.lua
    ├── theme.lua
    ├── uiButton.lua
    └── undo.lua
```

# 7. Спецификация по файлам

7.1. modules/theme.lua
Палитра. Каждый цвет — {r, g, b} (0..1). Используется как unpack(THEME.xxx).

Группа  Ключи   Где используется
primary primary, primaryHi, primaryDown кнопки меню (кроме «Об игре» и «Выйти»), HUD-кнопки при желании
neutral neutral, neutralHi, neutralDown кнопки «Назад», «Меню», «Пропустить», <, >
danger  danger, dangerHi, dangerDown    «Сброс», «Сброс прогресса», «Выйти»
gold    gold, goldHi, goldDown  «Об игре»
success success, successHi, successDown «ИГРАТЬ» в levelSelect
фон bgDark, bgPanel фон всех сцен, панели
клетки  boardFloor, boardWall, boardCellStroke  game, demo, levelSelect
цели    targetEmpty, targetFilled   крестики на полу / поверх ящика
ящики   boxIdle, boxOnTarget, boxStroke, boxInnerStroke ящики
игрок   playerBody, playerStroke, playerEye круг игрока + «глаз»
Значения (0..1):

text
primary = {0.30, 0.55, 0.85}, primaryHi = {0.45, 0.72, 0.98}, primaryDown = {0.20, 0.40, 0.65}
neutral = {0.32, 0.32, 0.38}, neutralHi = {0.52, 0.52, 0.60}, neutralDown = {0.20, 0.20, 0.25}
danger = {0.80, 0.30, 0.30}, dangerHi = {0.95, 0.45, 0.45}, dangerDown = {0.55, 0.18, 0.18}
gold = {0.75, 0.60, 0.25}, goldHi = {0.90, 0.75, 0.35}, goldDown = {0.55, 0.42, 0.15}
success = {0.25, 0.70, 0.30}, successHi = {0.35, 0.85, 0.40}, successDown = {0.15, 0.50, 0.20}
bgDark = {0.10, 0.10, 0.15}, bgPanel = {0.18, 0.18, 0.24}
boardFloor = {0.85, 0.85, 0.82}, boardWall = {0.35, 0.35, 0.40}, boardCellStroke = {0.55, 0.55, 0.55}
targetEmpty = {0.75, 0.10, 0.10}, targetFilled = {0.85, 1.00, 0.85}
boxIdle = {0.65, 0.35, 0.12}, boxOnTarget = {0.30, 0.55, 0.25}, boxStroke = {0.20, 0.20, 0.20}, boxInnerStroke = {0,0,0,0.35}
playerBody = {0.20, 0.55, 0.95}, playerStroke = {0,0,0}, playerEye = {1,1,1,0.85}
Оговорки и костыли:

targetEmpty/targetFilled — это разные цвета: красный крест на полу и светло-зелёный крест поверх ящика. Не путать.

boxInnerStroke имеет 4-й компонент (alpha) — единственный цвет с alpha; при unpack используется 4 значения.

boxIdle (коричневый) → boxOnTarget (тёмно-зелёный). Переключение — в drawField по isTargetAt(b.x, b.y).

При redraw нельзя пересоздавать палитру — только читать THEME.

7.2. modules/uiButton.lua
Универсальная кнопка. Возвращает display.newGroup().

Опция   По умолчанию
label   ""
x, y    центр экрана
width, height   200 / 50
cornerRadius    min(h/2, 14)
fontSize, font  18 / native.systemFontBold
fillColor, fillColorOver, fillColorDown синий набор
labelColor  белый
strokeColor белый alpha=0.30
shadow  true
onPress(event)  —
enabled true
Методы: group:setEnabled(state), group:setLabel(s), group:isEnabled().

Структура (порядок вставки фиксирован): shadow → bg → hl (блик) → label. Все четыре объекта — дети возвращаемой группы. Создавать их либо через display.newXxx(group, ...), либо через group:insert(obj) до возврата.

Оговорки и костыли:

isHitTestable = true устанавливается только на bg. shadow, hl, label получают isHitTestable = false. Причина: display.newRect/newRoundedRect по умолчанию hit-testable, и декоративный слой перехватывает тач.

Проверка попадания в обработчике touch — через bg.contentBounds (мировые координаты) либо bg:contentToLocal(event.x, event.y). Прямое сравнение event.x/y с group.x/y запрещено (§4.4).

Шаблон проверки:

lua
local function insideBg(px, py)
    local b = bg.contentBounds
    if not b then return true end
    return px >= b.xMin and px <= b.xMax
       and py >= b.yMin and py <= b.yMax
end
Поведение тача:

began — setFocus, fillDown, сжатие 0.95.

moved — уход за пределы → fillHi, возврат → fillDown.

ended внутри — onPress(event), отпускание — fill.

cancelled — сброс фокуса, fill, setFocus(nil).

setFocus при event.phase == "began" обязателен: без него moved/ended могут прийти вне группы.

Кнопка при setEnabled(false) — alpha = 0.45, bg.isHitTestable = false. Возврат — alpha = 1, isHitTestable = true.

7.3. modules/gameState.lua
lua
function gameState.new()
    return {
        currentLevel = 1,
        playerPos    = {x=0, y=0},
        boxes        = {},
        targets      = {},
        walls        = {},
        moves        = 0,
        maxLevel     = 1,
        completed    = {},
    }
end
7.4. modules/save.lua
I/O в system.DocumentsDirectory.

Файл    Содержимое
save.json   currentLevel, moves, playerPos, boxes
progress.json   {"1": true, "2": true, ...}
API:

Функция Назначение
saveState(state)    сериализация партии
loadState() чтение + gameState.new() с восстановленными полями
hasProgress()   валидный save.json?
markCompleted(levelIndex)   отметить уровень
isCompleted(levelIndex) проверка
areAllLevelsCompleted(total)    все от 1 до total
wipeAll()   удалить оба файла
Зависимости: json, modules.gameState.

Оговорки и костыли:

save.saveState вызывается на каждом обычном ходу и на победе. Не дебаунсится, приемлемо для пошаговой игры.

wipeAll() не трогает уже созданные Composer-сцены: кэшированная game.lua при следующем gotoScene вызовет hide → save.saveState(state) и воскресит save.json. В menu.lua после wipeAll() обязательно вызвать composer.removeScene для game/demo/levelSelect (§7.7).

undo-история между сессиями не сохраняется.

loadState не восстанавливает targets/walls (они парсятся loadLevel заново).

loadState не должен модифицировать таблицу, полученную из json.decode, только копировать нужные поля в свежий gameState.new(). Если json.decode кэширует результат (в некоторых сборках), мутация полей таблицы-источника приведёт к «залипанию» значений между вызовами.

json.decode вызывается под pcall — повреждённый файл трактуется как «нет сохранения».

loadState сам по себе не восстанавливает партию в сцене. Он только читает файл и возвращает таблицу. Восстановление boxes/playerPos/moves в state — задача scene:create в game.lua (см. §7.9, §15.18).

7.5. modules/undo.lua
Снимок — произвольная Lua-таблица, кладётся как есть (глубокой копией).

history[1] — исходное состояние.

history[N] — текущее.

MAX_HISTORY = 5000, при переполнении — FIFO.

API: clear, push, canUndo, undo, peek, depth, moveCount, exportAll, subscribe, unsubscribe.

Оговорки и костыли:

push делает deepCopy снимка. Мелкие таблицы {x=,y=} быстро копируются.

Подписчики уведомляются на каждый push/clear/undo — undo.subscribe вызывается сразу же при подписке, что используется для инициализации состояния кнопки «Отмена».

«Отмена» во время анимации авто-доставки — особый случай: снимок берётся из preAnimSnapshot, а не из стека undo (см. §9.4).

undo — синглтон-модуль. subscribers не сбрасываются при composer.removeScene. Каждая сцена обязана хранить свой callback в локальной переменной и снимать его в destroy через undo.unsubscribe(callback). Иначе подписчики накапливаются, и на исчезнувших ссылках UI падает с attempt to index a nil value.

7.6. modules/data.lua
lua
return {
    levels = {
        { name = "Уровень N", map = { "строка", "строка", ... } },
        ...
    }
}
200 записей. Формат символов — см. §8. Файл поставляется готовым.

Оговорки и костыли:

data.lua — read-only. Никакой код не мутирует data.levels[i].map, включая «безобидный» паддинг пробелами. См. §15.16.

Файл ~3 000 строк, компилируется целиком при старте. На бюджетных Android — заметная задержка на холодном старте. Осознанно, разбиение не входит в v1.0.

Формальной валидации карт при загрузке нет. Соответствие числа ящиков и целей проверяется по факту в checkWin.

7.7. scenes/menu.lua
6 кнопок:

   Метка   Действие
1   «Новая игра» / «Продолжить» hasProgress() → game, иначе → demo
2   «Как играть»    demo
3   «Выбрать уровень»   levelSelect
4   «Сброс прогресса»   native.showAlert → save.wipeAll()
5   «Об игре»   credits
6   «Выйти» os.exit() (Android)
refreshStartButton() вызывается в create и show(did).

Порядок в rootGroup: bg → декоративные элементы (полоса, заголовок, подзаголовок) → кнопки (последними, §4.5).

Вёрстка (landscape 1280×720):

firstY = 240, step = 78, btnH = 56, btnW = 460.

Верх первой кнопки 212 > 145 (подзаголовок), низ последней 658 < 720.

Стек центрируется относительно доступной области между подзаголовком и нижней границей экрана, а не относительно VCY.

Оговорки и костыли:

После save.wipeAll() обязательно composer.removeScene для всех stateful-сцен (game, demo, levelSelect). Иначе кэшированная сцена при следующем визите вызовет hide → save.saveState(state) и воскресит save.json — кнопка «Продолжить» появится снова.

Повторный вход в сцену с состоянием. Composer по умолчанию не удаляет предыдущую сцену при gotoScene — вызывается только hide/show, create повторно не выполняется. Для demo, game, levelSelect перед переходом обязательно вызывать composer.removeScene(name, false).

native.showAlert callback: читать и event.index, и второй аргумент (buttonIndex) — сигнатура менялась между сборками (см. §15.4).

Все кнопки меню создаются через uiButton.new и вставляются в rootGroup последними.

7.8. scenes/demo.lua
Демо-карта (8×10):

text
##########
#. .     #   <- цели (2,2) и (4,2)
#        #
#  $     #   <- верхний ящик (4,4)
#  $     #   <- нижний ящик (4,5)
#        #
#@       #   <- игрок (2,7)
##########
Константы: TOP_OFFSET = 100, BOTTOM_OFFSET = 80, LEFT_OFFSET = 15, RIGHT_OFFSET = 15, AUTO_TAP_DELAY = 3000, MOVE_DELAY = 130.

Этапы:

Этап    Подсказка   Целевой тап
S_BOX2  «1. Нижний ящик мешает. Тапни по нему, чтобы выбрать.»  boxes[2] (4,5)
S_FREE2 «2. Тапни по клетке в стороне — сдвинем ящик с пути.»   (6,5)
S_BOX1  «3. Путь свободен. Теперь тапни по верхнему ящику.» boxes[1] (4,4)
S_TARGET1   «4. Укажи цель — верхний ряд, левый крестик.»   (2,2)
S_BOX2B «5. Отлично! Теперь доведи второй ящик. Тапни по нему.» boxes[2]
S_TARGET2   «6. Укажи вторую цель — верхний ряд, правый крестик.»   (4,2)
S_DONE  «Готово! Ты умеешь…»    через 1600 мс — goToGame
Логика тапа — упрощённый handleCellTap, привязанный к этапу. «Не туда» → стрелка и автотап возвращаются.

Переход: startNewGame() → gameState.new() → save.saveState → gotoScene("scenes.game", {params = {level = 1}}).

Кнопка «Пропустить» → startNewGame().

Оговорки и костыли:

Дублирование: своя копия findDeliveryPath, drawField, tryMove, drawHand. Осознанно (см. §12).

tryDeliverTo в demo.lua выполняется пошагово, асинхронно. Путь прогоняется через timer.performWithDelay(MOVE_DELAY, step, 1): один шаг таймера = один tryMove = один drawField. Колбэк advanceStage вызывается из onComplete после последнего шага, а не из тела цикла. Синхронный for _, dir in ipairs(path) do tryMove(...) end запрещён — даёт телепорт.

Флаг isDemoAnimating взводится на время проигрывания пути и блокирует: повторный tryDeliverTo, onOverlayTap, scheduleAutoTap. Снимается в stopDemoAnim.

stopDemoAnim() — отменяет demoAnimTimer, сбрасывает isDemoAnimating, обнуляет demoAnimQueue и demoAnimIndex. Вызывается в scene:hide(will), scene:destroy, onSkipPress.

autoTapTimer сбрасывается в начале tryDeliverTo (чтобы игрок не получил автотап в середину анимации) и заново ставится в advanceStage после её завершения.

drawHand() сам позиционирует стрелку по текущему этапу (не advanceStage), и drawField() переставляет руку при пересоздании fieldGroup. Иначе после первого drawField внутри анимации рука «уезжает» в старую позицию.

Void: в demo-карте отсутствует — границы замкнуты стенами.

Порядок в rootGroup: bg → header → boardGroup → handGroup (внутри boardGroup) → overlay → hintText → skipBtn. Overlay до интерактивных элементов (§4.5).

Все колбэки advanceStage, scheduleAutoTap, handleCellTap, tryMove, tryDeliverTo, stopDemoAnim, drawField, drawHand, goToGame, goToGameSkipped, startNewGame — обязательно объявлены в forward declarations. startNewGame вызывается из timer-колбэка внутри advanceStage, который определён выше startNewGame (см. §15.1).

Повторный заход в «Как играть» после полного прохождения демо должен запускать демо с первого этапа — за это отвечает composer.removeScene("scenes.demo", false) при выходе из demo (в hide(will)) или перед входом.

Самоперезапуск таймера после stopDemoAnim. stepDemoAnim вызывает tryMove, а внутри tryMove/advanceStage анимация может быть остановлена (onSkipPress, scene:hide(will), scene:destroy, ветка «последний шаг»). Обязательны два guard'а:

в начале stepDemoAnim — if not isDemoAnimating or not demoAnimQueue or not demoAnimIndex then return end;
после tryMove — повторная проверка if not isDemoAnimating or not demoAnimQueue then return end перед созданием таймера.
stopDemoAnim обязан обнулять demoAnimQueue и demoAnimIndex (а не только isDemoAnimating). См. §9.3, §15.12.

7.8.1. Точное позиционирование стрелки-«руки» (v1.6)
Стрелка позиционируется так, чтобы острие касалось верхней грани целевой клетки. Формула:

lua
local headW = math.max(16, cellSize * 0.34)
local headH = math.max(10, cellSize * 0.20)
local stemW = math.max(4,  cellSize * 0.08)
local stemH = math.max(10, cellSize * 0.22)

-- Tip of the triangle touches top edge of cell (tx, ty).
local tipY = fieldY + (ty - 1) * cellSize - 2
local px   = fieldX + (tx - 0.5) * cellSize
local py   = tipY - headH / 2         -- group origin is head center
Структура: handArrow — display.newGroup(), содержащая:

stem — вертикальный прямоугольник (stemW × stemH), центр на (0, -headH/2 - stemH/2);

head — треугольник через display.newPolygon, вершина в (0, +headH/2), основание на y = -headH/2.

Почему нельзя - cellSize * 0.95. Для цели (4,5) формула py = fieldY + (ty - 0.5) * cellSize - cellSize * 0.95 даёт py = fieldY + 3.55 * cellSize, что попадает в клетку (4,4) — над верхним ящиком, а не над нижним. Пользователь видит «стрелка показывает на соседнюю клетку» — при этом сам тап-этап засчитывается правильно (обработчик работает по координатам клетки, а не по координатам стрелки), что делает баг особенно коварным.

Обнаружение: grep по scenes/demo.lua на - cellSize * 0.95 или - cellSize * 0.9; если есть — это старый баг позиционирования.

Проверка: для каждой цели этапа из STAGES[i].target вычислить py вручную и убедиться, что py + headH/2 лежит в диапазоне [fieldY + (ty - 1) * cellSize - 4, fieldY + (ty - 1) * cellSize + 2].

7.9. scenes/game.lua — ядро
Функции:

Функция Ответственность
loadLevel(levelIndex)   парсинг, computeVoids, undo.clear/push
drawField() перерисовка поля
positionOverlay()   переразметка overlay под текущую геометрию поля
tryMove(dx, dy, isAuto) один шаг
animatePath(path)   запуск пошаговой серии с задержкой 130 мс (см. §9.3)
stepAnim()  один шаг серии с guard'ами (см. §9.3)
handleCellTap(x, y) выбор / доставка
tryDeliverTo(tx, ty)    BFS-доставка
undoMove()  отмена с учётом анимации
resetLevel()    перезапуск
checkWin()  победа
goToNextLevel() следующий / меню
computeVoids(map, R, C) flood-fill снаружи
findDeliveryPath(box, target)   BFS
makeSnapshot / applySnapshot    undo
flashBox / flashRedSelected красная вспышка
Void-клетки считаются в loadLevel, участвуют в isWallAt, isVoidAt, buildBlockedGrid, drawField, в тап-обработчике.

7.9.1. Порядок групп в rootGroup (обязателен)
bg (фон).

boardGroup (внутри: fieldGroup, затем handGroup).

overlay (прозрачный, alpha=0.01, isHitTestable=true).

hudGroup (имя уровня, счётчик ходов, кнопки «Меню» / «Отмена» / «Сброс»).

Почему такой порядок: hit-testing в Solar2D идёт сверху вниз (последний добавленный — сверху). HUD должен быть последним, иначе overlay съест тапы по кнопкам. Overlay должен быть над полем, иначе тапы по клеткам не сработают (§4.5).

HUD:

Слева сверху: имя уровня.

По центру: «Ход: N».

Справа: «Меню», «Отмена», «Сброс» (140×56, cornerRadius 14, spacing 14, rightX = VW - 40).

Жизненный цикл:

Фаза    Действия
create  см. §7.9.2 (v1.6): params.level → новый state; иначе loadState + loadLevel + apply saved state; HUD; drawField; positionOverlay; поворот. undo.subscribe(undoCallback) → enabled кнопки «Отмена»
show(will)  keyboard listener; если undo.depth()==0 → undo.push(makeSnapshot())
hide(will)  снять keyboard; stopAnimation; cancelAllFlashes; save.saveState; undo.clear
destroy стоп таймеров; cancelAllFlashes; undo.unsubscribe(undoCallback); зануление ссылок
7.9.2. Восстановление сохранённой партии при «Продолжить» (v1.6)
Проблема. loadLevel перезаписывает state.boxes, state.playerPos, state.moves начальной раскладкой карты (это необходимо — уровень всегда должен сначала распарситься). Если сразу после loadLevel не восстановить сохранённые данные, пользователь, нажавший «Продолжить», видит уровень с нуля: ходы, позиции ящиков, undo-база — всё стартовое.

Правило. Сохранённые данные читаются в локальные переменные до loadLevel и применяются после. Шаблон:

lua
local params = event.params or {}
local lvl = params.level

if lvl then
    -- Fresh start on a specific level. Ignore any prior save.
    state = gameState.new()
    state.currentLevel = lvl
    loadLevel(lvl)
else
    -- Continue from save. loadLevel rebuilds boxes/playerPos/moves
    -- from the level map (initial layout), so we must read the saved
    -- dynamic state BEFORE loadLevel and re-apply it AFTER.
    local loaded       = save.loadState()
    local savedLevel   = loaded.currentLevel or 1
    if savedLevel < 1 then savedLevel = 1 end
    if savedLevel > #data.levels then savedLevel = #data.levels end

    local pendingPos   = loaded.playerPos
    local pendingBoxes = loaded.boxes
    local pendingMoves = loaded.moves

    local s = gameState.new()
    s.currentLevel = savedLevel
    state = s
    loadLevel(savedLevel)   -- overwrites boxes/playerPos/moves

    -- Re-apply saved dynamic state if compatible with the loaded map
    -- (same number of boxes). Guards against mismatched save.json.
    if pendingPos and pendingBoxes
       and #pendingBoxes == #state.boxes then
        state.playerPos.x = pendingPos.x or state.playerPos.x
        state.playerPos.y = pendingPos.y or state.playerPos.y
        state.moves = pendingMoves or 0
        for i = 1, #pendingBoxes do
            state.boxes[i].x = pendingBoxes[i].x
            state.boxes[i].y = pendingBoxes[i].y
        end
        -- Make the restored state the undo base, not the level start.
        undo.clear()
        undo.push(makeSnapshot())
        save.saveState(state)
    end
end
Почему #pendingBoxes == #state.boxes. Защита от рассогласования, если save.json остался от уровня с другим числом ящиков (пользователь вручную подменил файл, или версия data.lua изменилась). При несовпадении сохранённое состояние отбрасывается и уровень начинается с нуля.

Почему undo.clear(); undo.push(...). База undo должна стать восстановленным состоянием, а не стартовой раскладкой. Иначе первый же «Отмена» после Continue прыгает к началу карты, что читается как «Отмена не работает».

Почему save.saveState(state) после восстановления. Гарантирует, что текущий save.json согласован с in-memory state (на случай, если loadState вернул slightly-different структуру). Идемпотентно.

Обнаружение: grep по scenes/game.lua. Если loadLevel(state.currentLevel) вызывается без последующего восстановления pendingBoxes/pendingPos/pendingMoves — это баг. Симптомы: Continue открывает нужный уровень, но с начальной позиции; ходы обнуляются; undo откатывает к старту карты.

Проверка чек-листа:

Пройти 2-3 хода на уровне N.

Выйти в меню.

Нажать «Продолжить».

Убедиться: уровень N, ящики на своих местах, счётчик ходов показывает то же число, что и до выхода.

Нажать «Отмена» — состояние откатывается к состоянию перед последним ходом, а не к началу карты.

7.9.3. Прочие оговорки и костыли
Мутация data.lua. loadLevel обязан копировать карту уровня в локальную таблицу до любого паддинга:

lua
map = {}
for i, row in ipairs(lvl.map) do
    map[i] = row
end
R = #map
C = 0
for _, row in ipairs(map) do
    if #row > C then C = #row end
end
for i = 1, R do
    if #map[i] < C then
        map[i] = map[i] .. string.rep(" ", C - #map[i])
    end
end
Прямое lvl.map[i] = lvl.map[i] .. " " мутирует data.levels[i].map, и после первого прохода уровня карта остаётся расширенной. См. §15.16.

flashBox. Таймер вспышки использует timer.performWithDelay(delay, tick, N) с конечным числом повторов N (например, 6), а не (..., -1). Handle всё равно сохраняется в flashTimers для возможного досрочного cancelAllFlashes. Конечный счётчик гарантирует, что вспышка остановится сама, даже если cancelAllFlashes не вызвался. См. §15.11.

undo.subscribe. Callback хранится в локальной переменной сцены и передаётся в undo.unsubscribe в scene:destroy:

lua
local undoCallback
...
undoCallback = function()
    if undoBtn then undoBtn:setEnabled(undo.canUndo()) end
end
undo.subscribe(undoCallback)
...
-- scene:destroy
if undoCallback then
    undo.unsubscribe(undoCallback)
    undoCallback = nil
end
animatePath завершает себя через stopAnimation(), а не просто animTimer = nil.

undo.push для авто-доставки делается один раз по завершении анимации, а не на каждый шаг.

Redraw (drawField) полностью пересоздаёт fieldGroup. Все ссылки в boxSprites/playerSprite становятся невалидными — их надо заново заполнить в drawField.

Вспышка — только красная (FLASH_RED = {1.0, 0.2, 0.2}). Не путать с boxOnTarget.

Клик по пустой клетке без выделения → clearSelection() без вспышки.

Клик по клетке с другим ящиком при выделении → flashRedSelected(), без изменения выделения.

Void-клетки не рисуются, не кликаются, блокируют движение.

Авто-доставка и победа. Последний шаг stepAnim может привести ящик на цель и вызвать tryMove → checkWin → stopAnimation. Требуются два guard'а — см. §9.3.

Переход на следующий уровень. goToNextLevel обязан вычислить номер следующего уровня из ТЕКУЩЕГО state ДО его замены на новый gameState.new(). См. §15.13.

Overlay и смена геометрии поля. Overlay создаётся один раз в scene:create с фиктивными размерами и остаётся ребёнком rootGroup. Реальные width/height/x/y выставляются positionOverlay() — вызывается из scene:create, resetLevel, goToNextLevel. Без positionOverlay при переходе на уровень с другим R/C тапы уходят мимо клеток. См. §15.14.

Guard клавиатуры во время анимации. В onKey первой строкой после проверки event.phase == "up" идёт if isAnimating then return end.

7.9.4. Геометрия поля
topOffset = 110, bottomOffset = 15, leftOffset = 15, rightOffset = 15.

cellSize = floor(min(availWidth/cols, availHeight/rows)).

Ящики — rect размером 0.72 * cellSize, внутренний rect — 0.52 * cellSize.

Крестик цели — 0.60 * cellSize (пустой) / 0.55 * cellSize (заполненный).

Игрок — круг радиуса 0.35 * cellSize, «глаз» — 0.08 * cellSize, смещён на (-0.10, -0.10) * cellSize.

Overlay — прямоугольник cellSize*cols × cellSize*rows; переразмечается positionOverlay() при каждом loadLevel/resetLevel/goToNextLevel.

7.10. scenes/levelSelect.lua
Компоненты: заголовок, счётчик «N / total», миниатюра, имя уровня, метка «ПРОЙДЕНО», кнопки <, >, «ИГРАТЬ», «Назад».

parseLevel(levelData) — локальный парсер (без computeVoids).

drawThumbnail(group, levelData) — миниатюра. Void не учитывается.

Отрисовка миниатюры — строго в два прохода:

Проход 1 — тайлы. Для каждой клетки: # → THEME.boardWall, остальное → THEME.boardFloor. Один display.newRect(group, px, py, cell, cell) без штриха.

Проход 2 — маркеры поверх тайлов. Для каждой НЕ-стены:

цель (. / * / +) → красный крест: два тонких прямоугольника THEME.targetEmpty, повёрнутые на +45° и -45°. Размер 0.65 * cell, толщина max(1, 0.18 * cell).

ящик ($ / *) → коричневый квадрат THEME.boxIdle размером 0.68 * cell со штрихом THEME.boxStroke (1 px). Для * — THEME.boxOnTarget.

игрок (@ / +) → синий круг THEME.playerBody радиусом 0.34 * cell со штрихом THEME.playerStroke (1 px).

Порядок внутри прохода 2 обязателен: сначала крест цели, затем ящик, затем игрок. Это гарантирует, что * читается как «ящик на цели», а + — как «игрок на цели».

Запрещено рисовать ящик или цель одной заливкой клетки. См. §12 п.16.

Поведение:

< / > — циклический переход.

«ИГРАТЬ» — composer.removeScene("scenes.game", false) → gotoScene("scenes.game", {params = {level = currentIndex}}).

show(did) — updateLevelDisplay().

Порядок в rootGroup: bg → заголовок → счётчик → thumbGroup → имя → метка → кнопки <, > → кнопки «ИГРАТЬ», «Назад» (последними, §4.5).

Оговорки и костыли:

parseLevel дублирует логику loadLevel из game.lua, но без computeVoids.

drawThumbnail полностью очищает группу (for i = group.numChildren, 1, -1 do group:remove(i) end) перед перерисовкой.

Ограничение maxCellSize = 22 — чтобы миниатюра не раздувалась на маленьких картах.

composer.removeScene("scenes.game", false) перед gotoScene — иначе старая сцена game.lua может остаться в кэше с прежним state.

parseLevel и drawThumbnail не мутируют levelData. Все вычисления — на локальных копиях. См. §15.16.

7.11. scenes/credits.lua
Статика: фон, акцентная полоса, заголовок «Об игре», текстовый блок, кнопка «Назад».

Текст:

text

УРОВНИ
Microban
Copyright: David W. Skinner
E-Mail: sasquatch@bentonrea.com
Web Site:
http://users.bentonrea.com/~sasquatch/sokoban/
Уровни распространяются свободно
при условии указания авторства.

Помощник addLine(text, y, size, color).

Порядок в rootGroup: bg → акцент → заголовок → текстовый блок → кнопка «Назад» (последней, §4.5).

Оговорки и костыли:

addLine использует display.newText({parent = rootGroup, ...}) — родитель обязателен.

Кнопка «Назад» — последняя в rootGroup, чтобы тап не съедался декоративными элементами.

Поворот rootGroup — в конце create.

Строки UI (тексты для пользователя) — единственное место, где допустим UTF-8. Комментарии и имена — только ASCII (§15.15).

# 8. Формат карт уровней
Символ  Значение    В state
   стена   walls
.   цель    targets
$   ящик    boxes
@   игрок   playerPos
*   ящик на цели    boxes + targets
+   игрок на цели   playerPos + targets
пустая клетка (пол) —
Пустые клетки снаружи контура стен → voidGrid через computeVoids.

Валидация: число ящиков должно совпадать с числом целей (проверяется по факту в checkWin; формальной валидации при загрузке нет).


# 9. Алгоритмы

9.1. computeVoids(map, R, C)
isSpace[y][x] = (char == ' ' or char == '').

queue <- все крайние isSpace-клетки.

BFS: сосед isSpace и не void → пометить void, push.

Возврат — voidGrid[y][x].

Почему не вручную: 200 карт — ручное проставление сломается при редактировании.

9.2. findDeliveryPath(box, target)
Состояние узла: (playerPos, boxPos). Другие ящики фиксированы.

Переход: для каждого dir:

n = p + dir. Если n == b: b сдвигается в b + dir (если не блокировано).

Иначе: двигается только игрок.

Если b == target — готово.

buildBlockedGrid(moveBox) — стены + void + все ящики кроме moveBox.

Сложность: O(R² · C²). Для 20×20 — ~160k, приемлемо.

BFS, не A*: эвристика Манхэттена не учитывает обход ящика игроком.

Возврат: {'U','D','L','R', ...} или nil.

9.3. animatePath(path) и stepAnim()
animatePath:

isAnimating = true;

preAnimSnapshot = makeSnapshot();

animQueue = path, animIndex = 1;

один вызов stepAnim() для запуска серии (не timer.performWithDelay(..., -1), см. ниже «почему»).

stepAnim() — один шаг серии, всегда timer.performWithDelay(MOVE_DELAY, stepAnim, 1):

lua
if not isAnimating or not animQueue or not animIndex then return end   -- guard 1
if animIndex > #animQueue then
    stopAnimation()
    clearSelection()
    undo.push(makeSnapshot())
    preAnimSnapshot = nil
    return
end
local dir = animQueue[animIndex]; animIndex = animIndex + 1
tryMove(dx, dy, true)
if not isAnimating or not animQueue then return end                    -- guard 2
animTimer = timer.performWithDelay(MOVE_DELAY, stepAnim, 1)
Почему guard #1: timer.performWithDelay(..., 1) возвращает handle, но между постановкой таймера и его срабатыванием анимация может быть остановлена (undoMove, resetLevel, checkWin, scene:hide). Отменённый таймер уже не выстрелит, но повторный заход в stepAnim извне (или по висячей ссылке) должен быть безопасен.

Почему guard #2: tryMove может вызвать checkWin → stopAnimation, который обнуляет animQueue/animIndex и сбрасывает isAnimating. В этом случае НЕ переставляем таймер.

Почему отказ от timer.performWithDelay(..., -1): при -1 колбэк сам себя переустанавливает безусловно — тот же баг самоперезапуска после внешнего stopAnimation (см. §12 п.19 и §15.12). Одноразовые таймеры (1) с явной переустановкой в конце stepAnim дают контроль над моментом «ставить или не ставить следующий тик».

stopAnimation обязан обнулять все три поля: animTimer (через timer.cancel), animQueue, animIndex, и сбрасывать isAnimating = false. Без обнуления animQueue/animIndex guard #1 не сработает.

По завершении серии (ветка animIndex > #animQueue): stopAnimation(), clearSelection(), undo.push(makeSnapshot()) — один раз на всю доставку, preAnimSnapshot = nil.

9.4. Undo
Снимок:

lua
{ moves = N, playerPos = {x, y}, boxes = { {x, y}, ... } }
Push:

Обычный ход → сразу.

Авто-доставка → один push по завершении.

loadLevel → clear + push.

Continue (v1.6) → после восстановления сохранённого состояния: undo.clear() + undo.push(makeSnapshot()). База undo = восстановленное состояние, а не стартовая карта.

undoMove():

wasAnimating = isAnimating; snapBeforeAnim = preAnimSnapshot; stopAnimation; cancelAllFlashes; clearSelection.

Если wasAnimating and snapBeforeAnim → applySnapshot(snapBeforeAnim), preAnimSnapshot = nil, drawField, save.saveState.

Иначе → undo.undo() → applySnapshot, drawField, save.saveState.

Кнопка «Отмена» — через undo.subscribe, callback хранится в локальной переменной сцены и снимается в destroy (§7.9).

# 10. Сквозные сценарии
10.1. Холодный старт
text
main.lua -> gotoScene("scenes.menu")
menu:create -> UI -> refreshStartButton()
menu:show(did) -> refreshStartButton()
10.2. Новая игра
text
«Новая игра» -> gotoScene("scenes.demo")
demo:create -> loadDemo -> drawField -> drawHand -> applyStage(S_BOX2)
10.3. Демо -> игра
text
S_DONE -> через 1600 мс -> startNewGame()
  |-- state = gameState.new()
  |-- save.saveState(state)
  |-- gotoScene("scenes.game", {params = {level = 1}})

game:create
  |-- params.level -> новый state + loadLevel(1)
  |-- drawField()
  |-- positionOverlay()
10.4. Продолжить (v1.6)
text
«Продолжить» -> gotoScene("scenes.game")   (без params.level)

game:create
  |-- loaded = save.loadState()
  |-- savedLevel   = loaded.currentLevel
  |-- pendingPos   = loaded.playerPos      <- читаем ДО loadLevel
  |-- pendingBoxes = loaded.boxes
  |-- pendingMoves = loaded.moves
  |-- state = gameState.new(); state.currentLevel = savedLevel
  |-- loadLevel(savedLevel)                <- перезаписывает boxes/playerPos/moves
  |-- if #pendingBoxes == #state.boxes then
  |       state.playerPos = pendingPos
  |       state.moves      = pendingMoves
  |       state.boxes[i]   = pendingBoxes[i]
  |       undo.clear(); undo.push(makeSnapshot())
  |       save.saveState(state)
  |   end
  |-- drawField()
  |-- positionOverlay()
10.5. Один тап по клетке
text
overlay:tap
  |-- if isAnimating -> return
  |-- обратное преобразование §4.2 -> (lx, ly)
  |-- -> (gx, gy)
  |-- handleCellTap(gx, gy)

handleCellTap
  |-- void -> clearSelection
  |-- нет выделения + ящик -> selectBox
  |-- тот же ящик -> clearSelection
  |-- другой ящик -> selectBox
  |-- пустая/цель -> tryDeliverTo

tryDeliverTo
  |-- стена / чужой ящик -> flashRedSelected
  |-- findDeliveryPath -> animatePath
  |-- nil -> flashRedSelected
10.6. Авто-доставка
text
animatePath(path)
  |-- isAnimating = true
  |-- preAnimSnapshot = makeSnapshot()
  |-- animQueue = path, animIndex = 1
  |-- stepAnim()
  |     |-- guard 1
  |     |-- если index > #queue -> stopAnimation, clearSelection,
  |     |                       undo.push, preAnimSnapshot = nil
  |     |-- tryMove(dx, dy, true)
  |     |-- guard 2
  |     |-- timer(MOVE_DELAY, stepAnim, 1)
  |-- tryMove -> save.saveState, checkWin
10.7. Undo
text
Обычный ход: tryMove -> undo.push
Авто-доставка: animatePath -> undo.push в конце

undoMove
  |-- stopAnimation, cancelAllFlashes, clearSelection
  |-- if preAnimSnapshot -> applySnapshot, drawField
  |-- иначе -> undo.undo() -> applySnapshot, drawField
10.8. Победа и переход на следующий уровень
text
checkWin == true
  |-- save.markCompleted(currentLevel)
  |-- save.saveState(state)
  |-- undo.clear()
  |-- stopAnimation()
  |-- native.showAlert("Победа!") -> onAlert(event, buttonIndex)
        |-- idx = buttonIndex or event.index
        |-- idx == 1 -> goToNextLevel()

goToNextLevel
  |-- nextLevel = (state.currentLevel or 1) + 1     <- ДО замены state
  |-- if nextLevel > total -> removeScene -> gotoScene("scenes.menu")
  |-- stopAnimation, cancelAllFlashes, clearSelection, preAnimSnapshot = nil
  |-- s = gameState.new(); s.currentLevel = nextLevel; state = s
  |-- loadLevel(nextLevel)
  |-- drawField()
  |-- updateHud()
  |-- positionOverlay()                              <- переразметка overlay
  |-- save.saveState(state)
10.9. Сохранение
Сохраняется:

каждый обычный ход,

победа,

выход из сцены (hide),

переход на следующий уровень,

loadLevel,

после восстановления при Continue (v1.6).

Не сохраняется:

undo-история между сессиями.

# 11. Границы модулей
text
uiButton     — ничего о проекте
theme        — чистая таблица
data         — чистые данные (read-only, см. §15.16)
gameState    — ничего
undo         — ничего о структуре снимка
save         — знает gameState (для loadState)
scenes       — знают все модули выше
Приватные функции в game.lua — forward declarations, в _G не попадают.

# 12. Известные ограничения и «грабли»
   Ограничение Что делать
1   Поворот UI хрупкий  Формула выведена для rotation=90, x=720, y=0. При изменении сломается тихо. См. §4.4
2   data.lua компилируется целиком  ~10 000 строк. На бюджетных Android — заметная задержка
3   Undo не сохраняется между сессиями  Осознанно
4   native.showAlert для победы Блокирует UI. Допустимо
5   demo.lua дублирует BFS / drawField  Осознанно, править в двух местах
6   levelSelect.lua переписывает parseLevel Дублирование
7   levelSelect.lua не учитывает void   В миниатюрах все клетки — пол/стена
8   save.saveState вызывается на каждом ходу    Не дебаунсится, приемлемо для пошаговой игры
9   alpha = 0 не отключает hit-test Обязательно isHitTestable = false для декора
10  event.x/y приходят в screen-space   Не сравнивать с group.x/y внутри повёрнутой иерархии (§4.4)
11  transition.to(group, ...) не обновляет contentBounds мгновенно  Для hit-теста во время анимации — contentToLocal
12  Forward declaration локальных функций   Любая функция, вызываемая из колбэка выше по файлу, обязана быть в forward-блоке (§15.1)
13  Сигнатура native.showAlert callback Читать event.index и второй аргумент (§15.4)
14  timer.performWithDelay(..., -1) возвращает handle   Обязательно сохранять и отменять (stopAnimation, cancelAllFlashes)
15  local function foo() виден только со строки определения Всё, что ссылается на foo раньше — видит глобал (nil) (§15.1)
16  Ящики и цели, нарисованные одной заливкой клетки в миниатюре, сливаются в полосы    Миниатюра — два прохода: тайлы, поверх — разные маркеры (крест / квадрат / круг). См. §7.10
17  Синхронный прогон tryDeliverTo (цикл по path) даёт телепорт ящика   Пошаговая анимация timer.performWithDelay(MOVE_DELAY, step, 1), advanceStage — в onComplete. См. §7.8, §3.1
18  Мгновенная перерисовка конечного состояния после многократного tryMove в цикле  Один кадр = один шаг (§3.1)
19  Самоперезапускающийся таймер воскрешает остановленную анимацию  Guard #1 в начале stepAnim/stepDemoAnim, guard #2 после tryMove. stopAnimation/stopDemoAnim обнуляют queue/index. См. §9.3, §15.12
20  Отказ перехода на следующий уровень после победы    Вычислить nextLevel из старого state в локальную переменную, потом создавать новый state. См. §7.9, §10.8, §15.13
21  Overlay не переразмечается при смене геометрии поля Отдельная positionOverlay(), вызываемая после каждого loadLevel/resetLevel/goToNextLevel. См. §7.9, §15.14
22  Клавиатура вклинивается в анимацию  Guard if isAnimating then return end в начале onKey. См. §5.2
23  loadLevel мутирует data.levels[i].map (паддинг пробелами)   Перед паддингом скопировать map в локальную таблицу. См. §7.9, §15.16
24  Многобайтные комментарии (box-drawing, стрелки, знаки ©) ломают парсер  Только ASCII в комментариях. Grep: [^\x00-\x7F]. См. §15.15
25  flashBox с timer.performWithDelay(..., -1) бесконечно стреляет  Использовать конечное число повторов N и сохранять handle. См. §7.9, §15.11
26  undo.subscribe без парного unsubscribe накапливает подписчиков  Хранить callback в локальной переменной сцены и вызывать undo.unsubscribe(callback) в scene:destroy. См. §7.9
27  Стрелка-«рука» в demo показывает на соседнюю клетку Позиционировать по формуле tipY = fieldY + (ty - 1)*cellSize - 2, py = tipY - headH/2. Не использовать - cellSize * 0.95. См. §7.8.1, §15.17
28  Continue не восстанавливает сохранённую партию (ящики, позиция игрока, счётчик ходов)   Прочитать pendingPos/pendingBoxes/pendingMoves ДО loadLevel, применить ПОСЛЕ (при совпадении числа ящиков). undo.clear + push(makeSnapshot()). См. §7.9.2, §15.18

# 13. Roadmap (не входит в v1.0)

Приоритеты сверху вниз:

Переключить проект в реальный landscape (убрать поворот, event.x/y напрямую).

Вынести игровую логику из scenes/game.lua в modules/gameplay.lua — чтобы demo.lua использовал общий BFS.

Разбить data.lua на data/levels_NN_NN.lua с ленивой загрузкой.

Заменить native.showAlert на кастомную модалку победы.

Ввести modules/layout.lua с VW, VH, VCX, VCY, applyRotation(rootGroup), positionOverlay().

modules/i18n.lua — при появлении перевода.


# 14. Чек-лист приёмки

14.1. Сценарии игры
□ На старте — scenes/menu, кнопка №1 = «Новая игра» / «Продолжить» в зависимости от save.json.
□ Первый запуск ведёт в scenes/demo; 7 этапов проходятся, стрелка подсказывает, автотап через 3 с работает.
□ После демо создаётся новый state, открывается scenes.game на уровне 1.
□ Тап по ящику — выделение (толстая подсветка).
□ Тап по пустой клетке/цели — авто-доставка с анимацией 130 мс/шаг.
□ Тап по стене/void/чужому ящику при выделении — красная вспышка.
□ «Отмена» возвращает ход; во время анимации — откатывает до preAnimSnapshot.
□ «Сброс» перезапускает уровень; номер уровня не сбрасывается на 1.
□ Победа → нажатие OK — переход ровно на следующий уровень.
□ Победа на последнем уровне → «Поздравляем!» → меню.
□ Переход между уровнями с разными R/C не ломает тапы.
□ save.json переживает перезапуск; в меню — «Продолжить».
□ credits содержит корректные ссылки.
□ UI визуально landscape 1280×720, но приложение portrait в манифесте.
□ Клавиатура в desktop-отладке (стрелки, R, Z).
□ Клавиатура не вклинивается в авто-доставку.
□ os.exit() работает на Android.
□ Звук отсутствует.
□ data.lua содержит 200 записей.
□ В scenes/menu все 6 кнопок видны целиком.
□ Повторный заход в «Как играть» после полного прохождения демо запускает демо с первого этапа.
□ На каждом этапе demo движение ящика видно пошагово (~130 мс/шаг).
□ В demo повторный тап во время анимации и автотап в середину анимации не запускают анимацию повторно.
□ В demo на каждом этапе стрелка-«рука» стоит точно над целевой клеткой актуального этапа.
□ В scenes/levelSelect миниатюры ящиков и целей не сливаются в одну полосу.
□ Авто-доставка, последний шаг которой ставит ящик на цель, не вызывает краш.
□ Undo во время авто-доставки корректно откатывает до preAnimSnapshot.
□ «Пропустить» в demo во время движения ящика отменяет demoAnimTimer.
□ Повторная загрузка одного и того же уровня (Сброс → Сброс, повторный вход) не увеличивает размер поля.
□ В исходниках нет не-ASCII символов в комментариях.
□ Кнопка «Отмена» после многократных входов/выходов не «дёргает» исчезнувшие ссылки.
□ (v1.6) Continue восстанавливает позиции ящиков: пройти 2–3 хода, выйти в меню, нажать «Продолжить» — ящики на своих местах.
□ (v1.6) Continue восстанавливает счётчик ходов: до выхода — N ходов, после Continue — то же N.
□ (v1.6) Continue восстанавливает undo-базу: после Continue первая же «Отмена» откатывает к состоянию перед последним ходом, а не к началу карты.
□ (v1.6) Continue с несовместимым save.json (число ящиков не совпадает с картой) не падает, уровень стартует с нуля.
□ (v1.6) Стрелка-«рука» в demo на этапе S_BOX2 указывает точно на нижний ящик (4,5), не на верхний (4,4).
□ (v1.6) Стрелка-«рука» в demo на этапе S_TARGET1 указывает точно на цель (2,2), не на клетку выше.
□ (v1.6) Стрелка-«рука» в demo на этапе S_BOX1 указывает точно на верхний ящик (4,4).
14.2. Правила Solar2D (hit-testing / координаты / parentage)
□ У каждой кнопки текст — внутри её группы.
□ У shadow, hl, label в uiButton isHitTestable == false; тач принимает только bg.
□ Ни один декоративный объект не перехватывает тапы.
□ В scenes/game кнопки HUD «Меню / Отмена / Сброс» нажимаются при любом положении игрока.
□ Тап по клетке в scenes/game при разных DPI/разрешениях даёт одну и ту же клетку.
□ Порядок детей в rootGroup каждой сцены соответствует §4.5.
□ Все display.newXxx вызовы без parent отсутствуют.
□ contentBounds используется для hit-test, group.x/y — не используется.

# 15. Правила Solar2D (gotchas)

15.1. Forward declarations для колбэк-функций
В Lua local function foo() создаёт локальный биндинг только со строки определения. Всё, что объявлено раньше и ссылается на foo, видит глобал — то есть nil.

Правило: любая локальная функция, которая:

вызывается из timer.performWithDelay, transition.to/from, audio.* callbacks, Runtime:addEventListener, object:addEventListener, native.showAlert callback, или

используется в замыкании, созданном выше её определения,

обязана быть объявлена в блоке forward declarations в начале файла и определена как foo = function() ... end (без local).

Обнаружение: любой attempt to call global '<name>' (a nil value) в трейсе с участием timer.lua / transition.lua / runtime.lua — почти всегда именно это.

15.2. display.newXxx без parent
Без parent создают объект в корне сцены, а не в текущей группе.

15.3. isHitTestable и alpha
Все display-объекты по умолчанию isHitTestable = true. Декоративные слои обязаны явно получать isHitTestable = false.

alpha = 0 не выключает hit-test.

15.4. native.showAlert callback
Сигнатура колбэка менялась. Универсальный шаблон:

lua
function(event, buttonIndex)
    local idx = buttonIndex
    if idx == nil and type(event) == "table" then idx = event.index end
    if idx == 1 then ... end
end
Симптом: «диалог показывается, кнопка нажимается, ничего не происходит».

15.5. event.x/y в screen-space
Не сравнивать с group.x/y внутри повёрнутой/вложенной иерархии.

15.6. Порядок детей = z-order
Последний добавленный — сверху, получает hit-test первым.

15.7. parent.rotation != 0 и group.x/y
При parent.rotation != 0 group.x/y не соответствуют screen-space.

15.8. transition.to и contentBounds
Не обновляет contentBounds детей мгновенно.

15.9. display.newText без x/y
Объект попадает в (0,0) родителя.

15.10. setFocus при touch
При event.phase == "began" обязательно display.getCurrentStage():setFocus(event.target, event.id) и group.isFocus = true.

15.11. timer.performWithDelay(..., -1)
Возвращает handle, обязательно сохранять и отменять. Для вспышек предпочтительно использовать конечное число повторов.

15.12. Самоперезапускающиеся таймеры и внешний stop
Два обязательных guard'а:

lua
-- 1) в начале fn
if not isRunning or not queue or not index then return end

-- 2) после любого вызова, способного остановить серию
someFunctionThatMightStop()
if not isRunning or not queue then return end
nextTimer = timer.performWithDelay(delay, fn, 1)
Правило: stop* обязан обнулять queue и index, а не только флаг.

15.13. Пересоздание state до вычисления зависимых значений
Порядок операций: сначала вычислить всё, что зависит от старого state, в локальные переменные; только затем заменять state на новый.

Обнаружение: HUD после победы показывает «Уровень 1», хотя ожидался «Уровень N+1».

15.14. Overlay и смена геометрии поля
Overlay переразмечается отдельной positionOverlay(). Вызывается: в scene:create, в resetLevel, в goToNextLevel.

Обнаружение: после перехода между уровнями разного размера тапы работают только в левой верхней части поля.

15.15. Только ASCII в комментариях и именах
Многобайтные символы (box-drawing, стрелки, кавычки-ёлочки, знаки ©) в комментариях некоторых редакторов ломают парсер.

Правило: комментарии и имена — только ASCII. Строковые литералы UI — либо ASCII, либо осознанный UTF-8.

Обнаружение: ошибка парсера '=' expected near ... с указанием на строку, визуально не имеющую отношения к делу. Grep: [^\x00-\x7F].

15.16. modules/data.lua — read-only
Любой потребитель (game.lua, demo.lua, levelSelect.lua) копирует map в свою локальную таблицу перед любыми модификациями.

Обнаружение: после двух-трёх заходов в один и тот же уровень R/C растут, миниатюра в levelSelect становится шире исходной.

15.17. Позиционирование overlay-указателей в повёрнутой сцене (v1.6)
Правило. Любой указатель-оверлей (стрелка-«рука», маркер этапа, подсветка) в повёрнутой сцене позиционируется от геометрии целевой клетки, а не от её центра плюс произвольный offset.

Для стрелки в demo координата группы = центр головы. Острие = центр головы + headH/2 (для треугольника, направленного вниз). Чтобы острие касалось верхней грани клетки:

lua
tipY = fieldY + (ty - 1) * cellSize - 2   -- чуть выше верхней грани
py   = tipY - headH / 2                    -- центр головы
Запрещённая формула: py = fieldY + (ty - 0.5) * cellSize - cellSize * 0.95. Для ty = 5 она даёт py = fieldY + 3.55 * cellSize, что лежит в клетке (x, 4). Пользователь видит стрелку на соседней клетке, хотя тап-этап засчитывается правильно.

Общая ошибка: смещение через (ty - 0.5) * cellSize даёт центр клетки. Любое дополнительное вычитание cellSize * k (k ≈ 0.5–1.0) сдвигает указатель на предыдущую строку/столбец. Проверять визуально: острие указателя должно пересекать границу целевой клетки, а не её центр.

Обнаружение: grep по scenes/demo.lua на - cellSize * 0.95 или - cellSize * 0.9. Если есть — это баг.

15.18. Порядок read-save / load-level / apply-save при загрузке партии (v1.6)
Правило. loadLevel всегда перезаписывает динамическое состояние (boxes, playerPos, moves) начальной раскладкой карты. Это правильно и необходимо: уровень должен сначала распарситься из строк в state. Поэтому восстановление сохранённой партии обязательно делается до и после loadLevel, а не «вместо» него.

Порядок операций:

Прочитать save.loadState() → локальные переменные (pendingLevel, pendingPos, pendingBoxes, pendingMoves).

Создать новый state, установить currentLevel = pendingLevel.

Вызвать loadLevel(pendingLevel) — он распарсит карту и выставит boxes/playerPos/moves в стартовое состояние.

Проверить совместимость: #pendingBoxes == #state.boxes.

Применить сохранённые данные: state.playerPos = pendingPos, state.moves = pendingMoves, state.boxes[i] = pendingBoxes[i].

Сбросить undo-базу: undo.clear() + undo.push(makeSnapshot()) — иначе первая «Отмена» откатывает к началу карты.

Сохранить согласованное состояние: save.saveState(state).

Почему нельзя просто присвоить boxes после loadLevel без шагов 4–5. При несовпадении числа ящиков (save.json остался от старого уровня/версии data.lua) в state окажутся либо лишние ящики, либо недостающие, и checkWin начнёт вести себя странно. Проверка #pendingBoxes == #state.boxes — минимальная валидация.

Почему нельзя прочитать save ПОСЛЕ loadLevel. save.loadState() только читает файл; он не знает про state в сцене. Но если прочитать его после loadLevel, то pendingBoxes уже будут прочитаны из save.json, а state.boxes — уже из карты; логика та же. Однако читать до loadLevel удобнее: все pending* доступны на одной строке, и не путаются с полями state. Оба порядка технически эквивалентны, но первый (до) читается легче.

Обнаружение: Continue открывает правильный уровень, но с начальной позиции; счётчик ходов 0; первая «Отмена» отбрасывает к старту карты. Grep по scenes/game.lua: если loadLevel(state.currentLevel) вызывается без последующего применения pendingBoxes/pendingPos/pendingMoves, это баг.

