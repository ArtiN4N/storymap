package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

SPINE_COLOR  : rl.Color : {0x18, 0x18, 0x28, 0xff}
TEXT_COLOR : rl.Color : {0xdd, 0xdd, 0xdd, 0xff}

SPINE_WIDTH :: 40
LINE_HEIGHT :: 22

TEXT_MARGIN :: 15

drawPageText :: proc(state: State) {
    pos : rl.Vector2 = { TEXT_MARGIN + SPINE_WIDTH, TEXT_MARGIN + INFO_HEIGHT }

    lines := state.page.topViewLine + maxViewLines(state.window.height) + 1
    if lines > len(state.page.editText) {
        lines = len(state.page.editText)
    }

    sb := strings.builder_make()

    for i in state.page.topViewLine..<lines {
        splits := state.page.textSplits[state.page.topViewLine + i]

        strings.write_string(&sb, strings.to_string(state.page.editText[state.page.topViewLine + i]))

        j := 0
        splitCount := len(splits)
        for k in 0..<splitCount {
            inject_at(&sb.buf, splits[k] + j, '\n')
            j += 1
        }

        rl.DrawTextEx(
            state.page.font, strings.to_cstring(&sb),
            pos, state.page.fontSize, state.page.fontSpacing, TEXT_COLOR
        )
        pos.y += LINE_HEIGHT * cast(f32) (splitCount + 1)

        strings.builder_reset(&sb)
    }

    strings.builder_destroy(&sb)
}

drawLineNumbers :: proc(state: State) {
    visualLine := state.cursor.line - state.page.topViewLine

    spine : rl.Rectangle = { 0, 0, SPINE_WIDTH, cast(f32) state.window.height }
    rl.DrawRectangleRec(spine, SPINE_COLOR)

    cursorline : rl.Rectangle = {
        0, cast(f32) (TEXT_MARGIN + visualLine * LINE_HEIGHT + INFO_HEIGHT),
        cast(f32) state.window.width, LINE_HEIGHT
    }
    rl.DrawRectangleRec(cursorline, CURSOR_LINE_COLOR)

    pos : rl.Vector2 = { 0, TEXT_MARGIN + INFO_HEIGHT }
    lines := state.page.topViewLine + maxViewLines(state.window.height) + 1
    if lines > len(state.page.editText) {
        lines = len(state.page.editText)
    }

    fmt.println(lines)
    fmt.println(len(state.page.textSplits))
    for i in state.page.topViewLine..<lines {
        splits := state.page.textSplits[i]

        splitCount := len(splits)

        text := rl.TextFormat("%d", i)
        characterSize := rl.MeasureTextEx(state.page.font, text, state.page.fontSize, state.page.fontSpacing)
        drawpos := pos
        drawpos.x += (SPINE_WIDTH - characterSize.x) / 2.0
        rl.DrawTextEx(
            state.page.font, text,
            drawpos, state.page.fontSize, state.page.fontSpacing, TEXT_COLOR
        )
        pos.y += LINE_HEIGHT * cast(f32) (splitCount + 1)
    }
}