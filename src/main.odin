package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

EDITORCOLOR : rl.Color : {0x1e, 0x1e, 0x2e, 0xff}

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

    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    rl.InitWindow(state.screenWidth, state.screenHeight, "storymap")
    defer rl.CloseWindow()

    createPage(&state)
    defer destroyPage(&state.page)

    setCharWidth(&state)

    rl.SetTargetFPS(30)

    for !rl.WindowShouldClose() && !state.close {
        checkShortCuts(&state)

        if rl.IsWindowResized() {
            updateScreenSize(&state)
        }

        if !state.fBox.active {
            updateMenu(&state)
        }
        if !state.menuActive && !state.fBox.active {
            updatePage(&state)
        }
        if state.fBox.active {
            updateFileBox(&state)
        }
        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(EDITORCOLOR)

        drawLineNumbers(state)
        drawInfo(state)
        drawPageText(state)
        drawCursor(state)
        drawMenu(state)

        drawFileBox(state)
    }
}