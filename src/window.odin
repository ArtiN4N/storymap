package main

import rl "vendor:raylib"
import "core:fmt"

// The width (in px) of the default window.
INITIAL_WINDOW_WIDTH :: 800

// The height (in px) of the default window.
INITIAL_WINDOW_HEIGHT :: 800

// The width (in px) of the editor area. This includes the spine and line numbers, as well as all written text.
// The window can be resized, but the editor will always stay this width.
TOTAL_EDITOR_WIDTH :: 800
// The width (in px) of the area that text is displayed on the screen.
// Is the width of the editor sans the width of the spine, and space for margins.
TOTAL_TEXT_WIDTH :: TOTAL_EDITOR_WIDTH - (SPINE_WIDTH + TEXT_MARGIN * 2)

// Struct that contains measurements of the open window, along with a manager that handles window flags.
WindowObject :: struct {
    // Size of the window (in px).
    width: i32,
    height: i32,

    // Struct that handles window flags, i.e. fullscreen, resizeable, etc.
    flagManager: FlagManager,

    // Size of a single char (in px) of the text in the opened file.
    characterWidth: i32,
    // The maximum number of characters that can fit in a line of the editor.
    // This is used to ensure that all writing is visually contained in TOTAL_TEXT_WIDTH.
    lineCharactersMax: i32,

    // The first line number to be displayed in the editor.
    topViewLine: int,
    // The maximum number of lines that can be displayed in the editor.
    maxViewLines: i32,
}

// Procedure that returns an initialized WindowObject.
initialWindow :: proc() -> WindowObject {
    return {
        width = INITIAL_WINDOW_WIDTH,
        height = INITIAL_WINDOW_HEIGHT,

        flagManager = initialFlagManager(),

        characterWidth = 0,
        lineCharactersMax = 0,

        topViewLine = 0,
        maxViewLines = maxViewLines(INITIAL_WINDOW_HEIGHT),
    }
}

// A procedure that returns the maximum number of editor lines that can be displayed for the current window.
maxViewLines :: proc(height: i32) {
    return (height - TEXT_MARGIN * 2 - INFO_HEIGHT) / LINE_HEIGHT - 1
}

// Procedure that changes the window size, and updates necessary information about editor view.
changeWindowSize :: proc(window: ^WindowObject, width, height: i32) {
    window.width = width
    window.height = height
    window.maxViewLines = maxViewLines(height)
    //logicalHeight = window.height * 3
}

// Procedure that toggles fullscreen, and changes window size if necessary.
toggleFullscreen :: proc(window: ^WindowObject) {
    window.flagManager.fullscreen = !window.flagManager.fullscreen

    // Fullscreen does not update screen size to monitor size.
    // What this means is, if the screen was 800x800px before fullscreen,
    // after fullscreen, raylib thinks the screen width and height is still 800x800,
    // instead of the monitor size. Thus, if the screen is fullscreen, we change
    // the screen size to the monitor size before the toggle function is called.
    if window.flagManager.fullscreen {
        mon := rl.GetCurrentMonitor()
        changeWindowSize(window, rl.GetMonitorWidth(mon), rl.GetMonitorHeight(mon))
    }

    rl.ToggleFullscreen()
}

// Procedure that updates window data to new screen size.
updateWindowSize :: proc(window: ^WindowObject) {
    if window.fullscreen {
        return
    }

    changeWindowSize(window, rl.GetScreenWidth(), rl.GetScreenHeight())
}