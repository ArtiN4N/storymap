package main

import rl "vendor:raylib"
import "core:fmt"

// Struct that wraps raylibs window flags.
FlagManager :: struct {
    fullscreen: bool,
    flags: rl.ConfigFlags,
}

// Procedure that adds a flag to a FlagManager.
addConfigFlag :: proc(flagManager: ^FlagManager, flag: rl.ConfigFlag) {
    flagManager.flags += {flag}
}

// Procedure that removes a flag from a FlagManager.
removeConfigFlag :: proc(flagManager: ^FlagManager, flag: rl.ConfigFlag) {
    flagManager.flags -= {flag}
}