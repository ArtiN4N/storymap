package main

import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

BACKSPACEWAIT :: 0.3
BACKSPACECYCLE :: BACKSPACEWAIT + 0.025

ENTERWAIT :: 0.3
ENTERCYCLE :: ENTERWAIT + 0.025

INACTIVETIMER :: 1.0

ALPHANUMERIC :: [?]bool{
    0x30..=0x39 = true,
    0x41..=0x5a = true,
    0x61..=0x7a = true,
}

Page :: struct {
    text: [dynamic]strings.Builder,
    font: rl.Font,
    fontSize: f32,
    fontSpacing: f32,

    select: PageSelection,

    name: string,
    extension: string,
    unsaved: bool,

    words: int,
    monotonicWords: int,

    totalTimeMinutes: i32,
    timeSeconds: f32,

    totalActiveTimeMinutes: i32,
    timeActiveSeconds: f32,

    timeSinceLastUpdate: f32,

    activeRatio: f32,
}

initialPage :: proc() -> Page {
    cpoints : [^]rune
    return {
        text = make([dynamic]strings.Builder),
        font = rl.LoadFontEx("fonts/Noto_Sans_Mono/NotoSansMono-VariableFont_wdth,wght.ttf", 40, cpoints, 0),
        fontSize = 22,
        fontSpacing = 2,

        select = {},

        name = "untitled",
        extension = ".txt",
        unsaved = false,

        words = 0,
        monotonicWords = 0,

        totalTimeMinutes = 0,
        timeSeconds = 0.0,

        totalActiveTimeMinutes = 0,
        timeActiveSeconds = 0.0,
    }
}

destroyPage :: proc(page: ^Page) {
    delete(page.text)
    rl.UnloadFont(page.font)
}

createPage :: proc(state: ^State) {
    state.page = initialPage()
    rl.SetTextureFilter(state.page.font.texture, rl.TextureFilter.TRILINEAR);
    append(&state.page.text, strings.builder_make())
}

deleteCharacter :: proc(state: ^State) {
    work := &state.page.text[state.line].buf

    alphanumeric := ALPHANUMERIC

    if state.column > 0 {
        char : u8 = work[state.column - 1]
        ordered_remove(work, state.column - 1)
        state.column -= 1

        if alphanumeric[char] {
            if state.column == 0 {
                state.page.words -= 1
            } else if !alphanumeric[work[state.column - 1]] {
                state.page.words -= 1
            }
        }
    } else if state.line > 0 {
        line := state.page.text[state.line]
        ordered_remove(&state.page.text, state.line)

        old_len := strings.builder_len(state.page.text[state.line - 1])
        strings.write_string(&state.page.text[state.line - 1], strings.to_string(line))
        state.line -= 1
        state.column = old_len

        if state.column > 0 {
            char : u8 = state.page.text[state.line].buf[state.column - 1]
            if alphanumeric[char] {
                if strings.builder_len(state.page.text[state.line]) > state.column {
                    char = state.page.text[state.line].buf[state.column]
                    if alphanumeric[char] {
                        state.page.words -= 1
                    }
                }
            }
        }
    }

    flagActivePage(state)
    state.cursorFrame = 0.0

    capCursor(state)
}

backspacePage :: proc(state: ^State) {
    if !rl.IsKeyDown(rl.KeyboardKey.BACKSPACE) {
        return
    }

    if rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE) {
        state.backspaceCooldown = 0.0
    }

    if state.backspaceCooldown == 0.0 {
        deleteCharacter(state)
    }

    state.backspaceCooldown += rl.GetFrameTime()

    if state.backspaceCooldown >= BACKSPACEWAIT {
        if state.backspaceCooldown >= BACKSPACECYCLE {
            deleteCharacter(state)
            state.backspaceCooldown = BACKSPACEWAIT
        }
    }
}

addNewLine :: proc(state: ^State) {
    work := &state.page.text[state.line].buf

    pre := work[:state.column]
    post := work[state.column:]
    strings.builder_reset(&state.page.text[state.line])
    strings.write_bytes(&state.page.text[state.line], pre)

    inject_at(&state.page.text, state.line + 1, strings.builder_make())
    strings.write_bytes(&state.page.text[state.line + 1], post)

    state.line += 1
    state.column = 0

    flagActivePage(state)
    state.cursorFrame = 0.0

    alphanumeric := ALPHANUMERIC

    if len(pre) > 0 && len(post) > 0 {
        if alphanumeric[pre[len(pre)-1]] && alphanumeric[post[len(post)-1]] {
            state.page.words += 1
            state.page.monotonicWords += 1
        }
    }

    capCursor(state)
}

enterPage :: proc(state: ^State) {
    if !rl.IsKeyDown(rl.KeyboardKey.ENTER) {
        return
    }

    if rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
        state.enterCooldown = 0.0
    }

    if state.enterCooldown == 0.0 {
        addNewLine(state)
    }

    state.enterCooldown += rl.GetFrameTime()

    if state.enterCooldown >= ENTERWAIT {
        if state.enterCooldown >= ENTERCYCLE {
            addNewLine(state)
            state.enterCooldown = ENTERWAIT
        }
    }
}

writePage :: proc(state: ^State) {
    key : int = cast(int) rl.GetCharPressed()

    work := &state.page.text[state.line].buf

    alphanumeric := ALPHANUMERIC

    for key != 0 {
        if key < 0x20 || key > 0x7e {
            key = cast(int) rl.GetCharPressed()
            continue
        }

        sb := strings.builder_make()
        strings.write_string(&sb, strings.to_string(state.page.text[state.line]))
        strings.write_byte(&sb, 'a')
        textpos := rl.MeasureTextEx(
            state.page.font, strings.to_cstring(&sb), state.page.fontSize, state.page.fontSpacing
        )
        if textpos.x > cast(f32) state.editWidth {
            if key != ' ' {
                addNewLine(state)
                //prevwork := &state.page.text[state.line - 1].buf
                //if alphanumeric[key] && alphanumeric[prevwork[len(prevwork) - 1]] {
                    //strings.write_string(&state.page.text[state.line - 1], "-")
                //}
                work = &state.page.text[state.line].buf
            }
        }

        inject_at(work, state.column, cast(u8) key)
        if alphanumeric[key] {
            if state.column == 0 {
                state.page.words += 1
                state.page.monotonicWords += 1
            } else if !alphanumeric[work[state.column - 1]] {
                state.page.words += 1
                state.page.monotonicWords += 1
            }
        }

        state.column += 1
        flagActivePage(state)
        state.cursorFrame = 0.0

        key = cast(int) rl.GetCharPressed()
    }

    backspacePage(state)

    enterPage(state)
}

flagActivePage :: proc(state: ^State) {
    state.page.timeSinceLastUpdate = 0.0
    state.page.unsaved = true
}

updatePage :: proc(state: ^State) {
    state.page.timeSeconds += rl.GetFrameTime()
    state.page.timeSinceLastUpdate += rl.GetFrameTime()

    if state.page.timeSinceLastUpdate <= INACTIVETIMER {
        state.page.timeActiveSeconds += rl.GetFrameTime()
        if state.page.timeActiveSeconds > 60.0 {
            state.page.totalActiveTimeMinutes += 1
            state.page.timeActiveSeconds -= 60.0
        }
    }

    if state.page.timeSeconds > 60.0 {
        state.page.totalTimeMinutes += 1
        state.page.timeSeconds -= 60.0
    }

    activeTime := (cast(f32) state.page.totalActiveTimeMinutes) + (state.page.timeActiveSeconds / 60.0)
    totalTime := (cast(f32) state.page.totalTimeMinutes) + (state.page.timeSeconds / 60.0)
    state.page.activeRatio = activeTime / totalTime

    updateCursor(state)
    writePage(state)
}