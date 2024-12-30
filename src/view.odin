package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

SPINECOLOR  : rl.Color : {0x18, 0x18, 0x28, 0xff}
TEXTCOLOR : rl.Color : {0xdd, 0xdd, 0xdd, 0xff}

SPINEWIDTH :: 40
LINEHEIGHT :: 22

TEXTMARGIN :: 15

drawPageText :: proc(state: State) {
    pos : rl.Vector2 = { TEXTMARGIN + SPINEWIDTH, TEXTMARGIN + INFOHEIGHT }

    lines := state.topViewLine + state.maxViewLines + 1
    if lines > len(state.page.text) {
        lines = len(state.page.text)
    }

    sb := strings.builder_make()

    for i in state.topViewLine..<lines {
        splits := state.page.textSplits[state.topViewLine + i]

        strings.write_string(&sb, strings.to_string(state.page.text[state.topViewLine + i]))

        j := 0
        splitCount := len(splits)
        for k in 0..<splitCount {
            inject_at(&sb.buf, splits[k] + j, '\n')
            j += 1
        }

        rl.DrawTextEx(
            state.page.font, strings.to_cstring(&sb),
            pos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
        )
        pos.y += LINEHEIGHT * cast(f32) (splitCount + 1)

        strings.builder_reset(&sb)
    }

    strings.builder_destroy(&sb)
}

drawLineNumbers :: proc(state: State) {
    visualLine := state.line - state.topViewLine

    spine : rl.Rectangle = { 0, 0, SPINEWIDTH, cast(f32) state.screenHeight }
    rl.DrawRectangleRec(spine, SPINECOLOR)

    cursorline : rl.Rectangle = {
        0, cast(f32) (TEXTMARGIN + visualLine * LINEHEIGHT + INFOHEIGHT),
        cast(f32) state.screenWidth, LINEHEIGHT
    }
    rl.DrawRectangleRec(cursorline, CURSORLINECOLOR)

    pos : rl.Vector2 = { 0, TEXTMARGIN + INFOHEIGHT }
    lines := state.topViewLine + state.maxViewLines + 1
    if lines > len(state.page.text) {
        lines = len(state.page.text)
    }

    fmt.println(lines)
    fmt.println(len(state.page.textSplits))
    for i in state.topViewLine..<lines {
        splits := state.page.textSplits[i]

        splitCount := len(splits)

        text := rl.TextFormat("%d", i)
        characterSize := rl.MeasureTextEx(state.page.font, text, state.page.fontSize, state.page.fontSpacing)
        drawpos := pos
        drawpos.x += (SPINEWIDTH - characterSize.x) / 2.0
        rl.DrawTextEx(
            state.page.font, text,
            drawpos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
        )
        pos.y += LINEHEIGHT * cast(f32) (splitCount + 1)
    }
}