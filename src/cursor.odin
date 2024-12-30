package main

import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

CURSOR_COLOR : rl.Color : {0x10, 0x7a, 0xb0, 0xff}
CURSOR_LINE_COLOR : rl.Color : {0x2e, 0x2e, 0x3e, 0xff}

CURSOR_WIDTH :: 2
CURSOR_WAIT :: 0.3
CURSOR_CYCLE :: CURSOR_WAIT + 0.025

VIEW_LINE_BUFFER :: 1

drawCursor :: proc(state: State) {
    if state.cursorFrame > 0.5 {
        return
    }

    visualLine := state.line - state.window.topViewLine

    characterSize := rl.MeasureTextEx(state.page.font, "a", state.page.fontSize, state.page.fontSpacing)
    cursor : rl.Rectangle = {
        x = TEXT_MARGIN + SPINE_WIDTH + (characterSize.x + state.page.fontSpacing) * cast(f32) state.column,
        y = TEXT_MARGIN + characterSize.y * cast(f32) visualLine + INFO_HEIGHT,
        width = CURSOR_WIDTH,
        height = LINE_HEIGHT
    }
    rl.DrawRectangleRec(cursor, CURSOR_COLOR)
}

moveCursor :: proc(state: ^State) {
    if state.heldKey == .KEY_NULL {
        return
    }

    state.cursorFrame = 0.0

    axis: ^int
    direction: int

    if state.heldKey == .LEFT {
        direction = -1
        axis = &state.column

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = -1 * state.column
            if direction > -1 {
                direction = -1
            }
        }
    } else if state.heldKey == .RIGHT {
        direction = 1
        axis = &state.column

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = strings.builder_len(state.page.text[state.line]) - state.column
            if direction < 1 {
                direction = 1
            }
        }
    } else if state.heldKey == .UP {
        direction = -1
        axis = &state.line

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = -1 * (state.line - state.window.topViewLine)
        }
    } else if state.heldKey == .DOWN {
        direction = 1
        axis = &state.line

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = maxViewLines(state.window.height) + state.window.topViewLine - state.line
        }
    } else {
        return
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

    if state.cursorCooldown >= CURSOR_WAIT {
        if state.cursorCooldown >= CURSOR_CYCLE {
            axis^ += direction
            state.cursorCooldown = CURSOR_WAIT
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
        state.heldKey = .KEY_NULL
    }

    if rl.IsKeyPressed(.UP) {
        state.heldKey = .UP
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(.DOWN) {
        state.heldKey = .DOWN
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(.LEFT) {
        state.heldKey = .LEFT
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(.RIGHT) {
        state.heldKey = .RIGHT
        state.cursorCooldown = 0.0
    }

    moveCursor(state)

    wheelMove := rl.GetMouseWheelMove()
    if wheelMove > 0 {
        if state.line == state.window.topViewLine + maxViewLines(state.window.height) - 1 && state.window.topViewLine != 0 {
            state.line -= 1
        }
        state.window.topViewLine -= 1
    } else if wheelMove < 0 {
        if state.line == state.window.topViewLine + 1 || state.line == state.window.topViewLine  {
            state.line += 1
        }
        state.window.topViewLine += 1
    }

    if state.window.topViewLine < 0 {
        state.window.topViewLine = 0
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

    if state.line > state.window.topViewLine + maxViewLines(state.window.height) - VIEW_LINE_BUFFER {
        state.window.topViewLine += 1
    } else if state.line < state.window.topViewLine + VIEW_LINE_BUFFER && state.window.topViewLine > 0 {
        state.window.topViewLine -= 1
    }
}