package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

EDITOR_COLOR : rl.Color : {0x1e, 0x1e, 0x2e, 0xff}

PageSelection :: struct {
    linea: int,
    lineb: int,
    columna: int,
    columnb: int,
}

main :: proc() {
    state := initialState()
    defer destroyState(&state)

    initializeConfigFlags(&state.window.flagManager)

    rl.InitWindow(cast(i32) state.window.width, cast(i32) state.window.height, "storymap")
    defer rl.CloseWindow()

    setPage(&state)

    rl.SetExitKey(.KEY_NULL)
    rl.SetTargetFPS(30)

    for !rl.WindowShouldClose() && !state.close {
        checkShortCuts(&state)

        if rl.IsWindowResized() {
            updateWindowSize(&state.window)
        }

        if !state.fBox.active {
            updateMenu(&state)

            if !state.menuActive {
                updatePage(&state)
            }
        } else {
            updateFileBox(&state)
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(EDITOR_COLOR)

        drawLineNumbers(state)
        drawInfo(state)
        drawPageText(state)
        drawCursor(state)
        drawMenu(state)

        drawFileBox(state)
    }
}