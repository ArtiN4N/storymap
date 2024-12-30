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

Cursor :: struct {
    line: int,
    column: int,

    cursorFrame: f32,
    cursorCooldown: f32,
}

initialCursor :: proc() -> Cursor {
    return {
        line = 0,
        column = 0,

        cursorFrame = 0.0,
        cursorCooldown = 0.0,
    }
}

drawCursor :: proc(state: State) {
    if state.cursor.cursorFrame > 0.5 {
        return
    }

    visualLine := state.cursor.line - state.window.topViewLine

    characterSize := rl.MeasureTextEx(state.page.font, "a", state.page.fontSize, state.page.fontSpacing)
    cursor : rl.Rectangle = {
        x = TEXT_MARGIN + SPINE_WIDTH + (characterSize.x + state.page.fontSpacing) * cast(f32) state.cursor.column,
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

    state.cursor.cursorFrame = 0.0

    axis: ^int
    direction: int

    if state.heldKey == .LEFT {
        direction = -1
        axis = &state.cursor.column

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = -1 * state.cursor.column
            if direction > -1 {
                direction = -1
            }
        }
    } else if state.heldKey == .RIGHT {
        direction = 1
        axis = &state.cursor.column

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = strings.builder_len(state.page.text[state.cursor.line]) - state.cursor.column
            if direction < 1 {
                direction = 1
            }
        }
    } else if state.heldKey == .UP {
        direction = -1
        axis = &state.cursor.line

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = -1 * (state.cursor.line - state.window.topViewLine)
        }
    } else if state.heldKey == .DOWN {
        direction = 1
        axis = &state.cursor.line

        if rl.IsKeyDown(.LEFT_CONTROL) {
            direction = maxViewLines(state.window.height) + state.window.topViewLine - state.cursor.line
        }
    } else {
        return
    }

    if state.cursor.cursorCooldown == 0.0 {
        axis^ += direction

        if axis == &state.cursor.column {
            if axis^ < 0 {
                state.cursor.line -= 1
            } else if axis^ > strings.builder_len(state.page.text[state.cursor.line]) {
                state.cursor.line += 1
            }
        }
    }

    state.cursor.cursorCooldown += rl.GetFrameTime()

    if state.cursor.cursorCooldown >= CURSOR_WAIT {
        if state.cursor.cursorCooldown >= CURSOR_CYCLE {
            axis^ += direction
            state.cursor.cursorCooldown = CURSOR_WAIT
        }
    }

    capCursor(state)
}

updateCursor :: proc(state: ^State) {
    state.cursor.cursorFrame += rl.GetFrameTime()
    if state.cursor.cursorFrame > 1.0 {
        state.cursor.cursorFrame = 0.0
    }

    if !rl.IsKeyDown(state.heldKey) {
        state.heldKey = .KEY_NULL
    }

    if rl.IsKeyPressed(.UP) {
        state.heldKey = .UP
        state.cursor.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(.DOWN) {
        state.heldKey = .DOWN
        state.cursor.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(.LEFT) {
        state.heldKey = .LEFT
        state.cursor.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(.RIGHT) {
        state.heldKey = .RIGHT
        state.cursor.cursorCooldown = 0.0
    }

    moveCursor(state)

    wheelMove := rl.GetMouseWheelMove()
    if wheelMove > 0 {
        if state.cursor.line == state.window.topViewLine + maxViewLines(state.window.height) - 1 && state.window.topViewLine != 0 {
            state.cursor.line -= 1
        }
        state.window.topViewLine -= 1
    } else if wheelMove < 0 {
        if state.cursor.line == state.window.topViewLine + 1 || state.cursor.line == state.window.topViewLine  {
            state.cursor.line += 1
        }
        state.window.topViewLine += 1
    }

    if state.window.topViewLine < 0 {
        state.window.topViewLine = 0
    }

    capCursor(state)
}

capCursor :: proc(state: ^State) {
    if state.cursor.line < 0 {
        state.cursor.line = 0
    } else if state.cursor.line >= len(state.page.text) && state.cursor.line > 0 {
        state.cursor.line = len(state.page.text) - 1
    }

    if state.cursor.column < 0 {
        state.cursor.column = 0
    } else if len(state.page.text) > 0 {
        if state.cursor.column > strings.builder_len(state.page.text[state.cursor.line]) {
            state.cursor.column = strings.builder_len(state.page.text[state.cursor.line])
        }
    }

    if state.cursor.line > state.window.topViewLine + maxViewLines(state.window.height) - VIEW_LINE_BUFFER {
        state.window.topViewLine += 1
    } else if state.cursor.line < state.window.topViewLine + VIEW_LINE_BUFFER && state.window.topViewLine > 0 {
        state.window.topViewLine -= 1
    }
}