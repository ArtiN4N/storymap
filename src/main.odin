package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

EDITORCOLOR : rl.Color : {0x1e, 0x1e, 0x2e, 0xff}
SPINECOLOR  : rl.Color : {0x18, 0x18, 0x28, 0xff}
INFOCOLOR  : rl.Color : {0x10, 0x10, 0x20, 0xff}
TEXTCOLOR : rl.Color : {0xdd, 0xdd, 0xdd, 0xff}
CURSORCOLOR : rl.Color : {0x10, 0x7a, 0xb0, 0xff}
CURSORLINECOLOR : rl.Color : {0x2e, 0x2e, 0x3e, 0xff}

SPINEWIDTH :: 40
LINEHEIGHT :: 22

TEXTMARGIN :: 15

INFOHEIGHT :: 30

PageSelection :: struct {
    linea: int,
    lineb: int,
    columna: int,
    columnb: int,
}

drawInfo :: proc(state: State) {
    info : rl.Rectangle = { 0, 0, cast(f32) state.screenWidth, INFOHEIGHT }
    rl.DrawRectangleRec(info, INFOCOLOR)

    sb := strings.builder_make()
    strings.write_string(&sb,
        fmt.aprintf(
            "%s%s",
            state.page.name, state.page.extension
        )
    )

    if state.page.unsaved {
        strings.write_byte(&sb, '*')
    } else {
        strings.write_byte(&sb, ' ')
    }

    strings.write_string(&sb,
        fmt.aprintf(
            " | %d words | ",
            state.page.words
        )
    )

    hours := state.page.totalTimeMinutes / 60
    minutes := state.page.totalTimeMinutes % 60
    seconds := cast(int) state.page.timeSeconds

    strings.write_string(&sb,
        fmt.aprintf(
            "%d:%2d:%2d | ",
            hours, minutes, seconds
        )
    )

    idlePct := cast(i32) (100 * (1.0 - state.page.activeRatio))

    strings.write_string(&sb,
        fmt.aprintf(
            "Time idle: %d%% | ",
            idlePct
        )
    )

    totalActiveMinutes := cast(f32) state.page.totalActiveTimeMinutes + state.page.timeActiveSeconds / 60.0
    wpm := cast(f32) state.page.monotonicWords / totalActiveMinutes
    strings.write_string(&sb,
        fmt.aprintf(
            "WPM: %.0f",
            wpm
        )
    )

    textSize := rl.MeasureTextEx(state.page.font, strings.to_cstring(&sb), state.page.fontSize, state.page.fontSpacing)
    drawPos : rl.Vector2 = { TEXTMARGIN, (INFOHEIGHT - textSize.y) / 2 }
    rl.DrawTextEx(
        state.page.font, strings.to_cstring(&sb),
        drawPos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
    )
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
    for i in state.topViewLine..<lines {
        text := rl.TextFormat("%d", i)
        characterSize := rl.MeasureTextEx(state.page.font, text, state.page.fontSize, state.page.fontSpacing)
        drawpos := pos
        drawpos.x += (SPINEWIDTH - characterSize.x) / 2.0
        rl.DrawTextEx(
            state.page.font, text,
            drawpos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
        )
        pos.y += LINEHEIGHT
    }
}

drawPageText :: proc(state: State) {
    pos : rl.Vector2 = { TEXTMARGIN + SPINEWIDTH, TEXTMARGIN + INFOHEIGHT }

    lines := state.topViewLine + state.maxViewLines + 1
    if lines > len(state.page.text) {
        lines = len(state.page.text)
    }
    for i in state.topViewLine..<lines {
        rl.DrawTextEx(
            state.page.font, strings.to_cstring(&state.page.text[i]),
            pos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
        )
        pos.y += LINEHEIGHT
    }
}

main :: proc() {
    state := initialState()
    defer destroyState(&state)

    addConfigFlag(&state, rl.ConfigFlag.VSYNC_HINT)
    addConfigFlag(&state, rl.ConfigFlag.WINDOW_RESIZABLE)
    addConfigFlag(&state, rl.ConfigFlag.MSAA_4X_HINT)
    addConfigFlag(&state, rl.ConfigFlag.WINDOW_HIGHDPI)
    rl.SetConfigFlags(state.flags)

    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    rl.InitWindow(state.screenWidth, state.screenHeight, "storymap")
    defer rl.CloseWindow()

    createPage(&state)
    defer destroyPage(&state.page)

    rl.SetTargetFPS(30)

    for !rl.WindowShouldClose() && !state.close {
        checkShortCuts(&state)

        if rl.IsWindowResized() {
            updateScreenSize(&state)
        }

        updatePage(&state)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(EDITORCOLOR)

        drawLineNumbers(state)
        drawInfo(state)
        drawPageText(state)
        drawCursor(state)
    }
}