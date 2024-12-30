package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

INFO_COLOR  : rl.Color : {0x10, 0x10, 0x20, 0xff}

INFO_HEIGHT :: 30

drawInfo :: proc(state: State) {
    info : rl.Rectangle = { 0, 0, cast(f32) state.window.width, INFO_HEIGHT }
    rl.DrawRectangleRec(info, INFO_COLOR)

    sb := strings.builder_make()
    strings.write_string(&sb,
        fmt.aprintf(
            "%s%s",
            state.page.name, state.page.extension
        )
    )

    if state.page.unsaved {
        strings.write_byte(&sb, '*')
    } else {
        strings.write_byte(&sb, ' ')
    }

    strings.write_string(&sb,
        fmt.aprintf(
            " | %d words | ",
            state.page.words
        )
    )

    hours := state.page.totalTimeMinutes / 60
    minutes := state.page.totalTimeMinutes % 60
    seconds := cast(int) state.page.timeSeconds

    strings.write_string(&sb,
        fmt.aprintf(
            "%d:%2d:%2d | ",
            hours, minutes, seconds
        )
    )

    idlePct := cast(i32) (100 * (1.0 - state.page.activeRatio))

    strings.write_string(&sb,
        fmt.aprintf(
            "Time idle: %d%% | ",
            idlePct
        )
    )

    totalActiveMinutes := cast(f32) state.page.totalActiveTimeMinutes + state.page.timeActiveSeconds / 60.0
    wpm := cast(f32) state.page.sessionWords / totalActiveMinutes
    strings.write_string(&sb,
        fmt.aprintf(
            "WPM: %.0f",
            wpm
        )
    )

    textSize := rl.MeasureTextEx(state.page.font, strings.to_cstring(&sb), state.page.fontSize, state.page.fontSpacing)
    drawPos : rl.Vector2 = { TEXT_MARGIN, (INFO_HEIGHT - textSize.y) / 2 }
    rl.DrawTextEx(
        state.page.font, strings.to_cstring(&sb),
        drawPos, state.page.fontSize, state.page.fontSpacing, TEXT_COLOR
    )

    strings.builder_destroy(&sb)
}