package main

import rl "vendor:raylib"
import "core:fmt"

SHORTCUT_KEY :: rl.KeyboardKey.LEFT_CONTROL

FULLSCREEN_KEY :: rl.KeyboardKey.F
BORDERLESS_KEY :: rl.KeyboardKey.B
QUIT_KEY :: rl.KeyboardKey.Q
SAVE_KEY :: rl.KeyboardKey.S

Shortcut :: proc(state: ^State)

fullscreenShortcut :: proc(state: ^State) {
    toggleFullscreen(&state.window)
}

borderlessShortcut :: proc(state: ^State) {
    rl.ToggleBorderlessWindowed()
}

quitShortcut :: proc(state: ^State) {
    state.close = true
}

saveShortcut :: proc(state: ^State) {
    savePage(state)
}

setShortcuts :: proc() -> map[rl.KeyboardKey]Shortcut {
    ret := make(map[rl.KeyboardKey]Shortcut)

    ret[FULLSCREEN_KEY] = fullscreenShortcut
    ret[BORDERLESS_KEY] = borderlessShortcut
    ret[QUIT_KEY] = quitShortcut
    ret[SAVE_KEY] = saveShortcut
}

destroyShortcuts :: proc(shortcuts: ^map[rl.KeyboardKey]Shortcut) {
    delete(shortcuts)
}

checkShortCuts :: proc(state: ^State) {
    if !rl.IsKeyDown(.LEFT_CONTROL) {
        return
    }

    for key, value in state.shortcuts {
        if rl.IsKeyPressed(key) {
            value(state)
        }
    }
}