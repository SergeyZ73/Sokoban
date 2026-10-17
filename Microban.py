#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Конвертер уровней Microban.txt в формат data.lua.
Использование:
    python convert_microban.py Microban.txt data.lua
"""

import re
import sys


def parse_microban(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = [line.rstrip('\n\r') for line in f]

    header = []
    levels = []
    i = 0

    # 1. Собираем заголовочные комментарии (всё до первого уровня)
    while i < len(lines):
        line = lines[i]
        if re.match(r'^;\s*\d+', line):
            break
        if line.startswith(';'):
            header.append(line)
        i += 1

    # 2. Парсим уровни
    current_level = None
    map_lines = []

    while i < len(lines):
        line = lines[i]

        # Маркер нового уровня: ; 1, ; 44 'Duh!' и т.п.
        m = re.match(r'^;\s*(\d+)(?:\s+(.*))?$', line)
        if m:
            # Сохраняем предыдущий уровень
            if current_level is not None:
                current_level['map'] = map_lines
                levels.append(current_level)

            number = int(m.group(1))
            title = m.group(2).strip() if m.group(2) else None
            current_level = {'number': number, 'title': title}
            map_lines = []

            i += 1
            # Пропускаем пустые строки после маркера
            while i < len(lines) and lines[i].strip() == '':
                i += 1
            continue

        # Строки карты: не пустые и не комментарии
        if current_level is not None:
            if line.strip() != '' and not line.startswith(';'):
                map_lines.append(line)

        i += 1

    # Последний уровень
    if current_level is not None:
        current_level['map'] = map_lines
        levels.append(current_level)

    # 3. Выравниваем карты до прямоугольника «глухими» стенами:
    #    - обрезаем хвостовые пробелы;
    #    - добиваем справа символом '#' до максимальной ширины;
    #    - все ведущие пробелы каждой строки заменяем на '#'.
    for lvl in levels:
        m = lvl['map']
        if not m:
            continue

        # 3.1. Убираем хвостовые пробелы
        trimmed = [s.rstrip(' ') for s in m]

        # 3.2. Определяем итоговую ширину (по самой длинной обрезанной строке)
        max_w = max(len(s) for s in trimmed)

        new_map = []
        for s in trimmed:
            # 3.3. Добиваем справа '#'
            s_padded = s.ljust(max_w, '#')

            # 3.4. Меняем ведущие пробелы на '#'
            stripped = s_padded.lstrip(' ')
            n_leading = len(s_padded) - len(stripped)
            s_final = '#' * n_leading + stripped

            new_map.append(s_final)

        lvl['map'] = new_map

    return header, levels


def escape_lua_string(s):
    """Экранирование для Lua-строки в двойных кавычках."""
    return s.replace('\\', '\\\\').replace('"', '\\"')


def generate_lua(header, levels, out_path):
    with open(out_path, 'w', encoding='utf-8') as f:
        # Заголовочные комментарии: ; Комментарий -> -- Комментарий
        for line in header:
            comment = line[1:].strip()
            f.write(f"-- {comment}\n")
        f.write("\n")

        f.write("local data = {\n")
        f.write("    levels = {\n")

        for lvl in levels:
            num = lvl['number']
            title = lvl['title']
            if title:
                name = f"Microban {num} - {title}"
            else:
                name = f"Microban {num}"

            f.write("        {\n")
            f.write(f"            name = \"{escape_lua_string(name)}\",\n")
            f.write("            map = {\n")
            for row in lvl['map']:
                f.write(f"                \"{escape_lua_string(row)}\",\n")
            f.write("            }\n")
            f.write("        },\n")

        f.write("    }\n")
        f.write("}\n\n")
        f.write("return data\n")


if __name__ == "__main__":
    input_file = sys.argv[1] if len(sys.argv) > 1 else "Microban.txt"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "data.lua"

    header, levels = parse_microban(input_file)
    generate_lua(header, levels, output_file)
    print(f"Готово: {output_file}, уровней: {len(levels)}")