package main

import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

CURSORWIDTH :: 2
CURSORWAIT :: 0.3
CURSORCYCLE :: CURSORWAIT + 0.025

VIEWLINEBUFFER :: 1

drawCursor :: proc(state: State) {
    if state.cursorFrame > 0.5 {
        return
    }

    visualLine := state.line - state.topViewLine

    characterSize := rl.MeasureTextEx(state.page.font, "a", state.page.fontSize, state.page.fontSpacing)
    cursor : rl.Rectangle = {
        x = TEXTMARGIN + SPINEWIDTH + (characterSize.x + state.page.fontSpacing) * cast(f32) state.column,
        y = TEXTMARGIN + characterSize.y * cast(f32) visualLine + INFOHEIGHT,
        width = CURSORWIDTH,
        height = LINEHEIGHT
    }
    rl.DrawRectangleRec(cursor, CURSORCOLOR)
}

moveCursor :: proc(state: ^State) {
    if state.heldKey == rl.KeyboardKey.KEY_NULL {
        return
    }

    state.cursorFrame = 0.0

    axis: ^int
    direction: int

    if state.heldKey == rl.KeyboardKey.LEFT {
        direction = -1
        axis = &state.column

        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
            direction = -1 * state.column
            if direction > -1 {
                direction = -1
            }
        }
    } else if state.heldKey == rl.KeyboardKey.RIGHT {
        direction = 1
        axis = &state.column

        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
            direction = strings.builder_len(state.page.text[state.line]) - state.column
            if direction < 1 {
                direction = 1
            }
        }
    } else if state.heldKey == rl.KeyboardKey.UP {
        direction = -1
        axis = &state.line

        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
            direction = -1 * (state.line - state.topViewLine)
        }
    } else if state.heldKey == rl.KeyboardKey.DOWN {
        direction = 1
        axis = &state.line

        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
            direction = state.maxViewLines + state.topViewLine - state.line
        }
    }

    if state.cursorCooldown == 0.0 {
        axis^ += direction

        if axis == &state.column {
            if axis^ < 0 {
                state.line -= 1
            } else if axis^ > strings.builder_len(state.page.text[state.line]) {
                state.line += 1
            }
        }
    }

    state.cursorCooldown += rl.GetFrameTime()

    if state.cursorCooldown >= CURSORWAIT {
        if state.cursorCooldown >= CURSORCYCLE {
            axis^ += direction
            state.cursorCooldown = CURSORWAIT
        }
    }

    capCursor(state)
}

updateCursor :: proc(state: ^State) {
    state.cursorFrame += rl.GetFrameTime()
    if state.cursorFrame > 1.0 {
        state.cursorFrame = 0.0
    }

    if !rl.IsKeyDown(state.heldKey) {
        state.heldKey = rl.KeyboardKey.KEY_NULL
    }

    if rl.IsKeyPressed(rl.KeyboardKey.UP) {
        state.heldKey = rl.KeyboardKey.UP
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
        state.heldKey = rl.KeyboardKey.DOWN
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
        state.heldKey = rl.KeyboardKey.LEFT
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
        state.heldKey = rl.KeyboardKey.RIGHT
        state.cursorCooldown = 0.0
    }

    moveCursor(state)

    wheelMove := rl.GetMouseWheelMove()
    if wheelMove > 0 {
        if state.line == state.topViewLine + state.maxViewLines - 1 && state.topViewLine != 0 {
            state.line -= 1
        }
        state.topViewLine -= 1
    } else if wheelMove < 0 {
        if state.line == state.topViewLine + 1 {
            state.line += 1
        }
        state.topViewLine += 1
    }

    if state.topViewLine < 0 {
        state.topViewLine = 0
    }

    capCursor(state)
}

capCursor :: proc(state: ^State) {
    if state.line < 0 {
        state.line = 0
    } else if state.line >= len(state.page.text) && state.line > 0 {
        state.line = len(state.page.text) - 1
    }

    if state.column < 0 {
        state.column = 0
    } else if len(state.page.text) > 0 {
        if state.column > strings.builder_len(state.page.text[state.line]) {
            state.column = strings.builder_len(state.page.text[state.line])
        }
    }

    if state.line > state.topViewLine + state.maxViewLines - VIEWLINEBUFFER {
        state.topViewLine += 1
    } else if state.line < state.topViewLine + VIEWLINEBUFFER && state.topViewLine > 0 {
        state.topViewLine -= 1
    }
}