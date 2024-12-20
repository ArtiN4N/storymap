package main

import rl "vendor:raylib"

State :: struct {
    close: bool,

    screenWidth: i32,
    screenHeight: i32,

    fullscreen: bool,
    flags: rl.ConfigFlags,
    shortcuts: map[rl.KeyboardKey]Shortcut,

    line: int,
    column: int,
    cursorFrame: f32,
    cursorCooldown: f32,

    backspaceCooldown: f32,
    enterCooldown: f32,

    heldKey: rl.KeyboardKey,

    page: Page,
}

Shortcut :: proc(state: ^State)

fullscreenShortcut :: proc(state: ^State) {
    state.fullscreen = !state.fullscreen

    // Fullscreen does not update screen size to monitor size.
    // What this means is, if the screen was 800x800px before fullscreen,
    // after fullscreen, raylib thinks the screen width and height is still 800x800,
    // instead of the monitor size. Thus, if the screen is fullscreen, we change
    // the screen size to the monitor size before the toggle function is called.
    if state.fullscreen {
        mon := rl.GetCurrentMonitor()
        state.screenWidth = rl.GetMonitorWidth(mon)
        state.screenHeight = rl.GetMonitorHeight(mon)
    }

    rl.ToggleFullscreen()
}

borderlessShortcut :: proc(state: ^State) {
    rl.ToggleBorderlessWindowed()
}

quitShortcut :: proc(state: ^State) {
    state.close = true
}

initialState :: proc() -> State {
    scuts := make(map[rl.KeyboardKey]Shortcut)

    scuts[rl.KeyboardKey.F] = fullscreenShortcut
    scuts[rl.KeyboardKey.B] = borderlessShortcut
    scuts[rl.KeyboardKey.Q] = quitShortcut

    return {
        close = false,

        screenWidth = 800,
        screenHeight = 800,

        fullscreen = false,
        flags = {},
        shortcuts = scuts,

        line = 0,
        column = 0,
        cursorFrame = 0.0,
        cursorCooldown = 0.0,

        backspaceCooldown = 0.0,
        enterCooldown = 0.0,

        heldKey = rl.KeyboardKey.KEY_NULL,

        page = {},
    }
}

destroyState :: proc(state: ^State) {
    delete(state.shortcuts)
}

addConfigFlag :: proc(state: ^State, flag: rl.ConfigFlag) {
    state.flags += {flag}
}
removeConfigFlag :: proc(state: ^State, flag: rl.ConfigFlag) {
    state.flags -= {flag}
}

checkShortCuts :: proc(state: ^State) {
    if !rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
        return
    }

    for key, value in state.shortcuts {
        if rl.IsKeyPressed(key) {
            value(state)
        }
    }
}

updateScreenSize :: proc(state: ^State) {
    // Fullscreen does not update screen size to monitor size.
    // What this means is, if the screen was 800x800px before fullscreen,
    // after fullscreen, raylib thinks the screen width and height is still 800x800,
    // instead of the monitor size. Thus, if the screen is fullscreen, we ignore the
    // change in screen size, and instead directly update it when the toggle function
    // is called.
    if state.fullscreen {
        return
    }

    state.screenWidth = rl.GetScreenWidth()
    state.screenHeight = rl.GetScreenHeight()
}