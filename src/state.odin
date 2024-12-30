package main

import rl "vendor:raylib"
import "core:fmt"

// Struct that holds all information relevant to the program.
// Used by passing it to a procedure as a reference, which can then edit the state of the program.
State :: struct {
    // A boolean that, when set to true, exits program on next frame.
    close: bool,

    // A struct that contains all data for interfacing with the window on screen.
    window: WindowObject,

    // A map that binds specific keys to shortcut procedures, which then interface the state.
    shortcuts: map[rl.KeyboardKey]Shortcut,

    cursor: Cursor,

    backspaceCooldown: f32,
    enterCooldown: f32,

    heldKey: rl.KeyboardKey,

    page: Page,

    menuActive: bool,

    fBox: FileBox,

    loadDir: cstring,
}

// Procuedure that returns an initialized State.
initialState :: proc() -> State {
    shortcuts := setShortcuts()

    dir := rl.GetWorkingDirectory()

    return {
        close = false,

        window = initialWindow(),

        shortcuts = shortcuts,

        cursor = initialCursor(),

        backspaceCooldown = 0.0,
        enterCooldown = 0.0,

        heldKey = .KEY_NULL,

        page = {},

        menuActive = false,

        fBox = initialFileBox(),

        loadDir = dir,
    }
}

destroyState :: proc(state: ^State) {
    destroyShortcuts(&state.shortcuts)

    destroyPage(&state.page)
}

resetState :: proc(state: ^State) {
    state.cursor = initialCursor()

    state.backspaceCooldown = 0.0
    state.enterCooldown = 0.0

    state.heldKey = .KEY_NULL

    state.menuActive = false

    resetWindow(&state.window)

    destroyPage(&state.page)
    setPage(state)
}