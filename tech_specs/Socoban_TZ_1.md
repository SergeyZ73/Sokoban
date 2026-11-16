# Спецификация проекта «Сокобан»

Платформа: Solar2D (Corona SDK), Lua
Целевая платформа: Android (iOS-специфика не блокирует сборку, но и не приоритет)
Ориентация: portrait в манифесте, UI рисуется в landscape-координатах через поворот rootGroup на 90°
Звук: не используется
Уровни: файл data.lua считается готовым и поставляется как есть
Иконка: дефолтная Solar2D (кастомная опциональна)

Документ описывает все файлы проекта и сквозные сценарии — достаточно, чтобы воспроизвести игру с нуля.

---

## 1. Решённые вопросы

| # | Вопрос | Решение |
|---|---|---|
| 1 | Кол-во уровней | 200. Формат data.lua фиксирован, файл поставляется готовым |
| 2 | Иконка / LaunchScreen | Опциональны, по умолчанию — стандартные ассеты Solar2D |
| 3 | Звук | Не нужен, модуль sound.lua не создаётся |
| 4 | Платформа | Android (приоритет). os.exit() в меню допустим |
| 5 | Разбиение data.lua | Оставляем единым файлом |

---

## 2. Конфигурация платформы

### 2.1. config.lua

| Параметр | Значение |
|---|---|
| content.width | 720 |
| content.height | 1280 |
| scale | letterbox |
| fps | 60 |

### 2.2. build.settings

| Секция | Значение |
|---|---|
| splashScreen.enable | false |
| orientation.default | portrait |
| orientation.supported | { "portrait" } |
| android.usesPermissions | пусто |
| iphone.xcassets | "Images.xcassets" (опционально) |
| iphone.plist.UIStatusBarHidden | false |
| iphone.plist.UILaunchStoryboardName | "LaunchScreen" |
| plugins | пусто |
| excludeFiles.all | Icon.png, Icon-*dpi.png, Images.xcassets |
| excludeFiles.android | LaunchScreen.storyboardc |

Плагины (AdMob, IAP) не подключаются.

### 2.3. main.lua

```lua
local composer = require("composer")
composer.gotoScene("scenes.menu")

3. Архитектурные принципы
Никакого ООП на метатаблицах. Данные — {x=, y=}. Логика перемещения — в tryMove. Модули — синглтоны-таблицы.

Сцены — Composer-scene. create/show/hide/destroy.

Модули нижнего уровня не зависят от верхних. Исключение — save → gameState.

Комментарии — «почему», а не «что».

Магические числа — в константы.

Публично только return M.

4. Ориентация и поворот UI
4.1. Схема
config.lua — portrait 720×1280. Внутри каждой сцены — rootGroup с:

rootGroup.rotation = 90
rootGroup.x = display.contentWidth   -- 720
rootGroup.y = 0

Виртуальные размеры внутри сцены:

Константа Значение  Формула
VW  1280  display.contentHeight
VH  720 display.contentWidth
VCX 640 VW / 2
VCY 360 VH / 2
4.2. Обратное преобразование тапа для overlay в корне rootGroup
Для rotation=90, x=720, y=0:

local lx = event.y
local ly = display.contentWidth - event.x

Эта формула применима только к обработчику, висящему на объекте, чей parent == rootGroup, и это единственный поворот в иерархии (overlay в сценах game и demo). Для всех остальных обработчиков — см. §4.4.

Хрупко. При изменении угла/точки поворота сломается тихо.

4.3. Правила сцен
Всё рисуется в rootGroup, поворот — один раз в конце create.

destroy зануляет все ссылки.

Таймеры останавливаются в hide и destroy.

4.4. Координатные пространства и обработка тача
В Solar2D обработчики touch/tap всегда получают event.x/y в screen-space (в координатах дисплея 720×1280), независимо от того, в какой группе находится event.target. Это источник тихих ошибок попадания.

Правила:

Перевод в локальные координаты rootGroup. Формула §4.2 применима только если обработчик висит на прямом ребёнке rootGroup, и это единственный поворот. Не переносить формулу «по аналогии» вглубь иерархии.

Проверка попадания внутри произвольного объекта. Использовать obj.contentBounds (мировые границы с учётом всех трансформаций родичей) либо obj:contentToLocal(event.x, event.y).

Запрет на сравнение event.x/y с group.x/y внутри повёрнутой или вложенной иерархии. Это всегда даёт неверный результат.

Декоративные объекты. shadow, блики, подписи, pulse-круги — обязательно isHitTestable = false. Иначе они перехватывают тач.

alpha = 0 не отключает hit-test. Прозрачный объект продолжает ловить тапы, пока isHitTestable = true.

4.5. Порядок групп (z-order)
Порядок добавления детей в Solar2D = z-order: последний добавленный — сверху, первым получает hit-test.

Обязательный порядок в rootGroup для всех сцен:

Фон (bg).

Основной контент: в game — boardGroup (field + hand), в menu/levelSelect/credits — панель контента.

Прозрачный интерактивный overlay (только в game/demo), alpha = 0.01, isHitTestable = true — ловит тапы по полю.

HUD и интерактивные элементы управления: hudGroup в game, все кнопки в menu/levelSelect/credits.

Кнопки/интерактив — всегда последними, иначе overlay съест их тапы. Overlay — обязательно до HUD.

5. Модель управления
5.1. Игровой экран (scenes/game.lua)
Управление — по клеткам. Логика в handleCellTap(x, y):

Ситуация  Реакция
Нет выделения, тап по ящику selectBox(idx)
Есть выделение, тап по тому же ящику  clearSelection()
Есть выделение, тап по другому ящику  selectBox(newIdx)
Есть выделение, тап по пустой клетке / цели tryDeliverTo(x, y)
Тап по стене/void с выделением  clearSelection() + flashRedSelected()
Тап по клетке с другим ящиком flashRedSelected()
Тап по void без выделения clearSelection()
Тап ловится прозрачным overlay (alpha 0.01, isHitTestable = true), вставленным между boardGroup и hudGroup (см. §4.5). Во время isAnimating тапы игнорируются.

5.2. Клавиатура (desktop-отладка)
Клавиша Действие
up / down / left / right  tryMove(±1, 0/±1)
r resetLevel()
z undoMove()
5.3. Демо-сцена
Управление то же. Дополнительно:

Подсказка-текст вверху.

Анимированная стрелка-«рука» с pulse-tween.

AUTO_TAP_DELAY = 3000 мс — автотап, если игрок не тапает.

Этапы строго фиксированы (см. §7.8).

6. Карта проекта

'''text
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
'''

7. Спецификация по файлам
7.1. modules/theme.lua
Палитра. Каждый цвет — {r, g, b} (0..1).

Группа  Ключи
primary primary, primaryHi, primaryDown
neutral neutral, neutralHi, neutralDown
danger  danger, dangerHi, dangerDown
gold  gold, goldHi, goldDown
success success, successHi, successDown
фон bgDark, bgPanel
клетки  boardFloor, boardWall, boardCellStroke
цели  targetEmpty, targetFilled
ящики boxIdle, boxOnTarget, boxStroke, boxInnerStroke
игрок playerBody, playerStroke, playerEye
Используется как unpack(THEME.xxx).

7.2. modules/uiButton.lua
Универсальная кнопка. Возвращает display.newGroup().

Опции:

Опция По умолчанию
label ""
x, y  центр экрана
width, height 200 / 50
cornerRadius  min(h/2, 14)
fontSize, font  18 / native.systemFontBold
fillColor, fillColorOver, fillColorDown синий набор
labelColor  белый
strokeColor белый α=0.30
shadow  true
onPress(event)  —
enabled true
Методы: group:setEnabled(state), group:setLabel(s), group:isEnabled().

Структура (порядок вставки фиксирован): shadow → bg → hl (блик) → label. Все четыре объекта — дети возвращаемой группы. Создавать их либо через display.newXxx(group, ...), либо через group:insert(obj) до возврата. Создание display.newText({...}) без parent — запрещено (§4.4, §15).

Hit-testing. isHitTestable = true устанавливается только на bg. shadow, hl, label получают isHitTestable = false. Причина: в Solar2D display.newRect/newRoundedRect по умолчанию hit-testable, и декоративный слой перехватывает тач.

Проверка попадания. В обработчике touch проверку «внутри кнопки» делать через bg.contentBounds (мировые координаты) либо bg:contentToLocal(event.x, event.y). Прямое сравнение event.x/y с group.x/y — запрещено (§4.4).

Пример-псевдокод:

local function insideBg(px, py)
    local b = bg.contentBounds
    if not b then return true end
    return px >= b.xMin and px <= b.xMax
       and py >= b.yMin and py <= b.yMax
end

Поведение тача:

began — фокус, fillDown, сжатие 0.95.

moved — уход за пределы → fillHi, возврат → fillDown.

ended внутри — onPress(event), отпускание — fill.

cancelled — сброс фокуса, fill, снятие фокуса со stage.

7.3. modules/gameState.lua

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

Файл  Содержимое
save.json currentLevel, moves, playerPos, boxes, levelName
progress.json {"1": true, "2": true, ...}
API:

Функция Назначение
saveState(state)  сериализация партии
loadState() чтение + gameState.new() с восстановленными полями
hasProgress() валидный save.json?
markCompleted(levelIndex) отметить уровень
isCompleted(levelIndex) проверка
areAllLevelsCompleted(total)  все от 1 до total
wipeAll() удалить оба файла
Зависимости: json, modules.gameState.

7.5. modules/undo.lua
Снимок — произвольная таблица, глубокая копия.

Модель:

history[1] — исходное состояние.

history[N] — текущее.

MAX_HISTORY = 5000, при переполнении — FIFO.

API: clear, push, canUndo, undo, peek, depth, moveCount, exportAll, subscribe, unsubscribe.

7.6. modules/data.lua
lua
return {
    levels = {
        { name = "Уровень N", map = { "строка", "строка", ... } },
        ...
    }
}
90 записей. Формат символов — см. §8. Файл поставляется готовым.

7.7. scenes/menu.lua
6 кнопок:

# Метка Действие
1 «Новая игра» / «Продолжить» hasProgress() → game, иначе → demo
2 «Как играть»  demo
3 «Выбрать уровень» levelSelect
4 «Сброс прогресса» native.showAlert → save.wipeAll()
5 «Об игре» credits
6 «Выйти» os.exit() (Android)
refreshStartButton() вызывается в create и show(did).

После save.wipeAll() обязательно вызвать composer.removeScene для всех stateful-сцен (game, demo, levelSelect). Иначе кэшированная сцена при следующем визите вызовет hide → save.saveState(state) и воскресит save.json со старым уровнем — кнопка «Продолжить» появится снова, хотя файла только что не было.

Порядок в rootGroup: bg → декоративные элементы (полоса, заголовок, подзаголовок) → кнопки (последними, §4.5).

Повторный вход в сцену с состоянием. Composer по умолчанию не удаляет предыдущую сцену при gotoScene — вызывается только hide/show, create повторно не выполняется. Для сцен, хранящих состояние между визитами (demo, game, levelSelect), перед переходом обязательно вызывать composer.removeScene(name, false), иначе пользователь увидит остатки предыдущей сессии (завершённое демо, старый уровень, старую миниатюру).

Верстка меню (landscape 1280×720). Кнопки не должны выходить за пределы VH. Обязательная проверка при изменении: firstY − btnH/2 ≥ 0 и firstY + step * (N − 1) + btnH/2 ≤ VH. Для N = 6: firstY = 240, step = 78, btnH = 56, btnW = 460 — низ последней кнопки 658 < 720, верх первой 212 > 145 (подзаголовок). Стек центрируется относительно доступной области между подзаголовком и нижней границей экрана, а не относительно VCY напрямую, потому что верхняя треть VH занята заголовком.

7.8. scenes/demo.lua
Демо-карта (8×10):

text
##########
#. .     #   ← цели (2,2) и (4,2)
#        #
#  $     #   ← верхний ящик (4,4)
#  $     #   ← нижний ящик (4,5)
#        #
#@       #   ← игрок (2,7)
##########
Константы: HEADER_HEIGHT = 160, FIELD_PADDING = 20, AUTO_TAP_DELAY = 3000.

Этапы:

Этап  Подсказка Целевой тап
S_BOX2  «1. Нижний ящик мешает. Тапни по нему, чтобы выбрать.»  boxes[2]
S_FREE2 «2. Тапни по клетке в стороне — сдвинем ящик с пути.» (6,5)
S_BOX1  «3. Путь свободен. Теперь тапни по верхнему ящику.» boxes[1]
S_TARGET1 «4. Укажи цель — верхний ряд, левый крестик.» (2,2)
S_BOX2B «5. Отлично! Теперь доведи второй ящик. Тапни по нему.» boxes[2]
S_TARGET2 «6. Укажи вторую цель — верхний ряд, правый крестик.» (4,2)
S_DONE  «Готово! Ты умеешь…»  через 1600 мс — goToGame
Логика тапа — упрощённый handleCellTap, привязанный к этапу. «Не туда» → стрелка и автотап возвращаются.

Переход: startNewGame() → gameState.new() → save.saveState → gotoScene("scenes.game", {params = {level = 1}}).

Кнопка «Пропустить» → startNewGame().

Дублирование: своя копия findDeliveryPath, drawField, tryMove, drawX, drawHand. Осознанно.

Void: в demo-карте отсутствует — границы замкнуты стенами.

Порядок в rootGroup: bg → header → boardGroup → handGroup (внутри boardGroup) → overlay → hintText → skipBtn. Overlay до интерактивных элементов (§4.5).

«В demo.lua tryDeliverTo выполняет движения синхронно (без timer.performWithDelay), чтобы advanceStage() вызывался после фактического перемещения ящика. Анимация в демо не применяется — этапы должны переключаться атомарно.»

7.9. scenes/game.lua — ядро
Функции:

Функция Ответственность
loadLevel(levelIndex) парсинг, computeVoids, undo.clear/push
drawField() перерисовка + overlay
tryMove(dx, dy, isAuto) один шаг
animatePath(path) проигрывание с задержкой 130 мс
handleCellTap(x, y) выбор / доставка
tryDeliverTo(tx, ty)  BFS-доставка
undoMove()  отмена с учётом анимации
resetLevel()  перезапуск
checkWin()  победа
goToNextLevel() следующий / меню
computeVoids(map, R, C) flood-fill снаружи
findDeliveryPath(box, target) BFS
makeSnapshot / applySnapshot  undo
flashBox / flashRedSelected красная вспышка
Void-клетки — считаются в loadLevel, участвуют в isWallAt, isVoidAt, buildBlockedGrid, drawField, в тап-обработчике.

7.9.1. Порядок групп в rootGroup (обязателен)
bg (фон).

boardGroup (внутри: fieldGroup, затем handGroup).

overlay (прозрачный, alpha=0.01, isHitTestable=true).

hudGroup (имя уровня, счётчик ходов, кнопки «Меню» / «Отмена» / «Сброс»).

Почему такой порядок: hit-testing в Solar2D идёт сверху вниз (последний добавленный — сверху). HUD должен быть последним, иначе overlay съест тапы по кнопкам. Overlay должен быть над полем, иначе тапы по клеткам не сработают (§4.5).

HUD:

Слева сверху: имя уровня.

По центру: «Ход: N».

Справа: «Меню», «Отмена», «Сброс» (140×56, cornerRadius 14).

Жизненный цикл:

Фаза  Действия
create  params.level → новый state / save.loadState(); loadLevel; HUD; drawField; поворот. undo.subscribe(...) → enabled кнопки «Отмена»
show(will)  keyboard listener; если undo.depth()==0 → undo.push(makeSnapshot())
hide(will)  снять keyboard; stopAnimation; cancelAllFlashes; save.saveState; undo.clear
destroy стоп таймеров, undo.unsubscribe, зануление ссылок
7.10. scenes/levelSelect.lua
Компоненты: заголовок, счётчик «N / total», миниатюра, имя уровня, метка «ПРОЙДЕНО», кнопки <, >, «ИГРАТЬ», «Назад».

parseLevel(levelData) — локальный парсер (без computeVoids).

drawThumbnail(group, levelData, x, y, maxCellSize=22) — миниатюра. Void не учитывается.

Поведение:

</> — циклический переход.

«ИГРАТЬ» — composer.removeScene("scenes.game", false) → gotoScene("scenes.game", {params = {level = currentLevelIndex}}).

show(did) — updateLevelDisplay().

Порядок в rootGroup: bg → заголовок → счётчик → thumbGroup → имя → метка → кнопки <, > → кнопки «ИГРАТЬ», «Назад» (последними, §4.5).

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

Помощник addLine(text, size, color, spacing).

Порядок в rootGroup: bg → акцент → заголовок → текстовый блок → кнопка «Назад» (последней, §4.5).

8. Формат карт уровней
Символ  Значение  В state
# стена walls
. цель  targets
$ ящик  boxes
@ игрок playerPos
* ящик на цели  boxes + targets
+ игрок на цели playerPos + targets
пустая клетка (пол) —
Пустые клетки снаружи контура стен → voidGrid через computeVoids.

Валидация: число ящиков должно совпадать с числом целей (проверяется по факту в checkWin; формальной валидации при загрузке нет).

9. Алгоритмы
9.1. computeVoids(map, R, C)
isSpace[y][x] = (char == ' ' or char == '').

queue ← все крайние isSpace-клетки.

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

Сложность: O(R²·C²). Для 20×20 — ~160k, приемлемо.

BFS, не A*: эвристика Манхэттена не учитывает обход ящика игроком.

Возврат: {'U','D','L','R', ...} или nil.

9.3. animatePath(path)
isAnimating = true, preAnimSnapshot = makeSnapshot().

timer.performWithDelay(130, fn, -1).

Каждый тик — tryMove(dx, dy, true).

По завершении:

stopAnimation() (критично — иначе таймер продолжит стрелять и сбрасывать выделение),

clearSelection(),

undo.push(makeSnapshot()) — один раз на всю доставку,

preAnimSnapshot = nil.

9.4. Undo
Снимок:

lua
{ moves = N, playerPos = {x, y}, boxes = { {x, y}, ... } }
Push:

Обычный ход → сразу.

Авто-доставка → один push по завершении.

loadLevel → clear + push.

undoMove():

wasAnimating = isAnimating; stopAnimation; cancelAllFlashes; clearSelection.

Если wasAnimating and preAnimSnapshot → applySnapshot(preAnimSnapshot), drawField, save.saveState.

Иначе → undo.undo() → applySnapshot, drawField, save.saveState.

Кнопка «Отмена» — через undo.subscribe.

10. Сквозные сценарии
10.1. Холодный старт
text
main.lua → gotoScene("scenes.menu")
menu:create → UI → refreshStartButton()
menu:show(did) → refreshStartButton()
10.2. Новая игра
text
«Новая игра» → gotoScene("scenes.demo")
demo:create → loadDemo → drawField → drawHand → advanceStage(S_BOX2)
10.3. Демо → игра
text
S_DONE → через 1600 мс → startNewGame()
  ├── state = gameState.new()
  ├── save.saveState(state)
  └── gotoScene("scenes.game", {params = {level = 1}})

game:create
  ├── params.level → gameState.new() + save.saveState
  ├── loadLevel(1) → parse + computeVoids + undo
  └── drawField()
10.4. Один тап по клетке
text
overlay:tap
  ├── if isAnimating → return
  ├── обратное преобразование §4.2 → (lx, ly)
  ├── → (gx, gy)
  └── handleCellTap(gx, gy)

handleCellTap
  ├── void → clearSelection
  ├── нет выделения + ящик → selectBox
  ├── тот же ящик → clearSelection
  ├── другой ящик → selectBox
  └── пустая/цель → tryDeliverTo

tryDeliverTo
  ├── стена / чужой ящик → flashRedSelected
  ├── findDeliveryPath → animatePath
  └── nil → flashRedSelected
10.5. Авто-доставка
text
animatePath(path)
  ├── isAnimating = true
  ├── preAnimSnapshot = makeSnapshot()
  ├── timer(130, ..., -1)
  │     └── tryMove(dx, dy, true)
  ├── по завершении:
  │     ├── stopAnimation()
  │     ├── clearSelection()
  │     ├── undo.push(makeSnapshot())
  │     └── preAnimSnapshot = nil
  └── tryMove → save.saveState, checkWin
10.6. Undo
text
Обычный ход: tryMove → undo.push
Авто-доставка: animatePath → undo.push в конце

undoMove
  ├── stopAnimation, cancelAllFlashes, clearSelection
  ├── if preAnimSnapshot → applySnapshot, drawField
  └── иначе → undo.undo() → applySnapshot, drawField
10.7. Победа
text
checkWin == true
  ├── save.markCompleted(currentLevel)
  ├── save.saveState(state)
  ├── undo.clear()
  ├── stopAnimation()
  └── goToNextLevel()

goToNextLevel
  ├── areAllLevelsCompleted(total) → alert → menu
  ├── currentLevel >= total → menu
  └── иначе → save, loadLevel(currentLevel+1), drawField, save
10.8. Сохранение
Сохраняется:

каждый обычный ход,

победа,

выход из сцены (hide),

переход на следующий уровень,

loadLevel.

Не сохраняется:

undo-история между сессиями.

Повторный вход в сцену с состоянием. Composer по умолчанию не удаляет предыдущую сцену при gotoScene — вызывается только hide/show, create повторно не выполняется. Для сцен, хранящих состояние между визитами (demo, game, levelSelect), перед переходом обязательно вызывать composer.removeScene(name, false), иначе пользователь увидит остатки предыдущей сессии (завершённое демо, старый уровень, старую миниатюру).

11. Границы модулей
text
uiButton     — ничего о проекте
theme        — чистая таблица
data         — чистые данные
gameState    — ничего
undo         — ничего о структуре снимка
save         — знает gameState (для loadState)
scenes       — знают все модули выше
Приватные функции в game.lua — forward declarations, в _G не попадают.

12. Известные ограничения и «грабли»
# Ограничение Что делать
1 Поворот UI хрупкий  Формула выведена для rotation=90, x=720, y=0. При изменении сломается тихо. См. §4.4
2 data.lua компилируется целиком  ~3 000 строк. На бюджетных Android — заметная задержка
3 Undo не сохраняется между сессиями  Осознанно
4 native.showAlert для победы Блокирует UI. Допустимо
5 demo.lua дублирует BFS / drawField  Осознанно, править в двух местах
6 levelSelect.lua переписывает parseLevel Дублирование
7 levelSelect.lua не учитывает void В миниатюрах все клетки — пол/стена
8 save.saveState вызывается на каждом ходу  Не дебаунсится, приемлемо для пошаговой игры
9 alpha = 0 не отключает hit-test Обязательно isHitTestable = false для декора
10  event.x/y приходят в screen-space Не сравнивать с group.x/y внутри повёрнутой иерархии (§4.4)
13. Roadmap (не входит в v1.0)
Приоритеты сверху вниз:

Переключить проект в реальный landscape (убрать поворот, event.x/y напрямую).

Вынести игровую логику из scenes/game.lua в modules/gameplay.lua — чтобы demo.lua использовал общий BFS.

Разбить data.lua на data/levels_NN_NN.lua с ленивой загрузкой.

Заменить native.showAlert на кастомную модалку победы.

Ввести modules/layout.lua с VW, VH, VCX, VCY, applyRotation(rootGroup).

modules/i18n.lua — при появлении перевода.

14. Чек-лист приёмки
14.1. Сценарии игры
□ На старте — scenes/menu, кнопка №1 = «Новая игра» / «Продолжить» в зависимости от save.json.

□ Первый запуск ведёт в scenes/demo; 7 этапов проходятся, стрелка подсказывает, автотап через 3 с работает.

□ После демо создаётся новый state, открывается scenes.game на уровне 1.

□ Тап по ящику — выделение (толстая подсветка).

□ Тап по пустой клетке/цели — авто-доставка с анимацией 130 мс/шаг.

□ Тап по стене/void/чужому ящику при выделении — красная вспышка.

□ «Отмена» возвращает ход; во время анимации — откатывает до preAnimSnapshot.

□ «Сброс» перезапускает уровень.

□ Победа → progress.json, переход; на последнем — «Поздравляем!» → меню.

□ save.json переживает перезапуск; в меню — «Продолжить».

□ credits содержит корректные ссылки.

□ UI визуально landscape 1280×720, но приложение portrait в манифесте.

□ Клавиатура в desktop-отладке (стрелки, R, Z).

□ os.exit() работает на Android.

□ Звук отсутствует (нет обращений к audio.*).

□ data.lua содержит 200 записей, игра проходится до конца.

□ В scenes/menu все 6 кнопок видны целиком и не пересекаются с заголовком/подзаголовком при VH = 720.

□ В scenes/menu после полного прохождения демо повторный тап «Как играть» открывает демо с первого этапа (см. §7.7 про composer.removeScene).

□ Повторный заход в «Как играть» после полного прохождения демо запускает демо с первого этапа, а не показывает финальное состояние.

14.2. Правила Solar2D (hit-testing / координаты / parentage)
□ У каждой кнопки текст — внутри её группы. Проверка: #group > 0, group[1] — тень/bg, group[#group] — label.

□ У shadow, hl, label в uiButton isHitTestable == false; тач принимает только bg.

□ Ни один декоративный объект (блик, подсветка, pulse-круг руки в demo) не перехватывает тапы — проверяется тапом «мимо цели» на демо-сцене.

□ В scenes/game кнопки HUD «Меню / Отмена / Сброс» нажимаются при любом положении игрока — overlay не перекрывает.

□ Тап по клетке в scenes/game при разных DPI/разрешениях даёт одну и ту же клетку (проверка §4.2 для overlay + §4.4 для всех остальных).

□ Порядок детей в rootGroup каждой сцены соответствует §4.5: bg → контент → overlay → интерактив.

□ Все display.newXxx вызовы без parent отсутствуют в сценах и модулях (проверка grep-ом по display.newText({, display.newRect( и т.п. без первого аргумента-родителя).

□ contentBounds используется для hit-test, group.x/y — не используется для сравнения с event.x/y.

15. Правила Solar2D (gotchas)
Список неочевидного в API. Нарушение любого пункта даёт тихие баги, которые выглядят как «кнопки пустые и не работают».

display.newText, newRect, newCircle, newRoundedRect без parent создают объект в корне сцены, а не в текущей группе. Всегда либо передавать parent первым аргументом, либо вызывать group:insert(obj).

Все display-объекты по умолчанию isHitTestable = true. Декоративные слои (тени, блики, подписи, pulse-круги) обязаны явно получать isHitTestable = false.

alpha = 0 не выключает hit-test. Прозрачный объект продолжает ловить тапы. Отключать только через isHitTestable = false.

event.x/y в touch-обработчике — всегда screen-space. Не local, не координаты группы. Не сравнивать с group.x/y внутри повёрнутой/вложенной иерархии. Для попадания использовать obj.contentBounds или obj:contentToLocal(event.x, event.y).

Порядок добавления детей = z-order. Последний добавленный — сверху, получает hit-test первым. Интерактив добавлять последним (§4.5).

При parent.rotation ≠ 0 group.x/y не соответствуют screen-space. Для проверок попадания внутри повёрнутой группы — contentBounds/contentToLocal.

transition.to(group, {...}) на группе работает, но не обновляет contentBounds детей мгновенно. Для hit-теста во время анимации использовать event.x/y + obj:contentToLocal.

display.newText({...}) без x/y размещает объект в (0,0) родителя. При создании подписи кнопки — либо x=0, y=0 в таблице, либо obj.x, obj.y = 0, 0.

setFocus при touch. При event.phase == "began" обязательно display.getCurrentStage():setFocus(event.target, event.id) и group.isFocus = true, иначе moved/ended могут прийти вне группы. При ended/cancelled — setFocus(nil).

timer.performWithDelay(..., -1) возвращает handle, который обязательно сохранять и отменять по завершении, иначе таймер продолжит стрелять и «сбрасывать выделение» (см. §9.3).
В Lua local function foo() создаёт локальный биндинг только со строки определения. Всё, что объявлено раньше и ссылается на foo, видит глобал — то есть nil.

Правило: любая локальная функция, которая:

вызывается из timer.performWithDelay, transition.to/from, audio.* callbacks, Runtime:addEventListener, object:addEventListener, native.showAlert callback, или

используется в замыкании, созданном выше её определения,

обязана быть объявлена в блоке forward declarations в начале файла и определена как foo = function() ... end (без local).

Пример ошибки:

lua
-- НЕПРАВИЛЬНО
advanceStage = function()
    timer.performWithDelay(1600, function()
        startNewGame()          -- видит ГЛОБАЛ startNewGame → nil
    end)
end

local function startNewGame()   -- создаёт ЛОКАЛ только с этой строки
    ...
end
lua
-- ПРАВИЛЬНО
local startNewGame              -- forward declaration

advanceStage = function()
    timer.performWithDelay(1600, function()
        startNewGame()          -- видит ЛОКАЛ startNewGame
    end)
end

startNewGame = function()       -- присваивание уже объявленному локалу
    ...
end
Обнаружение: любой attempt to call global '<name>' (a nil value) в трейсе с участием timer.lua / transition.lua / runtime.lua — почти всегда именно это. Grep по файлу: имя функции должно встречаться ровно дважды — в forward-блоке и в определении; если local function <name> есть, а в forward-блоке имени нет, а функция вызывается из колбэка выше по файлу — баг.

native.showAlert колбэк. Сигнатура колбэка менялась: старые версии передавали (event, buttonIndex), современные — только event с полем event.index. Код, читающий только второй аргумент, на новых сборках получает nil и «тихо» не выполняет действие. Универсальный шаблон:

lua
function(event, buttonIndex)
    local idx = buttonIndex
    if idx == nil and type(event) == "table" then idx = event.index end
    if idx == 1 then ... end
end
Симптом: «диалог показывается, кнопка нажимается, ничего не происходит».


16. Резюме изменений относительно v1.0
Добавлены §4.4 (координатные пространства) и §4.5 (порядок групп).

Расширен §7.2 тремя обязательными правилами: parentage, hit-testing, bounds-check.

Добавлен §7.9.1 — обязательный порядок групп в game.

Добавлены аналогичные уточнения порядка в §7.7, §7.8, §7.10, §7.11.

Расширен §12 ограничениями 9–10 (alpha/hit-test, screen-space координаты).

Добавлен §14.2 — чек-лист по правилам Solar2D.

Добавлен §15 — правила Solar2D (gotchas).
