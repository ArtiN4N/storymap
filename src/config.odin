package main

import rl "vendor:raylib"
import "core:fmt"

// Struct that wraps raylibs window flags.
FlagManager :: struct {
    fullscreen: bool,
    flags: rl.ConfigFlags,
}

// Procedure that initializes config flags.
initializeConfigFlags :: proc(flagManager: ^FlagManager) {
    addConfigFlags(flagManager, .VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT, .WINDOW_HIGHDPI)
    rl.SetConfigFlags(flagManager.flags)

    flagManager.fullscreen = false
}

// Procedure that adds a set of flags to a FlagManager.
addConfigFlags :: proc(flagManager: ^FlagManager, flag: ..rl.ConfigFlag) {
    for f in flag {
        flagManager.flags += {f}
    }
}

// Procedure that removes a set of flags from a FlagManager.
removeConfigFlags :: proc(flagManager: ^FlagManager, flag: ..rl.ConfigFlag) {
    for f in flag {
        flagManager.flags -= {f}
    }
}