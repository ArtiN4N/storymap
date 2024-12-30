package main

import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

BACKSPACE_WAIT :: 0.3
BACKSPACE_CYCLE :: BACKSPACE_WAIT + 0.025

ENTER_WAIT :: 0.3
ENTER_CYCLE :: ENTER_WAIT + 0.025

INACTIVE_TIMER :: 1.0

Page :: struct {
    editText: [dynamic]strings.Builder,
    textSplits: [dynamic][dynamic]int,
    visualLines: int,

    font: rl.Font,
    fontSize: f32,
    fontSpacing: f32,

    name: string,
    extension: string,
    path: cstring,
    unsaved: bool,

    // The first line number to be displayed in the editor.
    topViewLine: int,
    bottomViewLine: int,

    words: int,
    sessionWords: int,

    totalTimeMinutes: i32,
    timeSeconds: f32,

    totalActiveTimeMinutes: i32,
    timeActiveSeconds: f32,

    timeSinceLastUpdate: f32,

    activeRatio: f32,
}

initialPage :: proc(state: State) -> Page {
    cpoints : [^]rune

    rl.ChangeDirectory(rl.GetApplicationDirectory())

    return {
        editText = make([dynamic]strings.Builder),
        textSplits = make([dynamic][dynamic]int),
        visualLines = 0,

        font = rl.LoadFontEx("fonts/Noto_Sans_Mono/NotoSansMono-VariableFont_wdth,wght.ttf", 40, cpoints, 0),
        fontSize = 22,
        fontSpacing = 2,

        name = "untitled",
        extension = ".txt",
        path = "",
        unsaved = false,

        topViewLine = 0,
        bottomViewLine = 0,

        words = 0,
        sessionWords = 0,

        totalTimeMinutes = 0,
        timeSeconds = 0.0,

        totalActiveTimeMinutes = 0,
        timeActiveSeconds = 0.0,
    }
}

destroyPage :: proc(page: ^Page) {
    // unload builders in text
    for i in 0..<len(page.editText) {
        strings.builder_destroy(&page.editText[i])
    }
    delete(page.editText)

    for i in 0..<len(page.textSplits) {
        delete(page.textSplits[i])
    }
    delete(page.textSplits)

    rl.UnloadFont(page.font)
}

setPage :: proc(state: ^State) {
    state.page = initialPage(state^)
    rl.SetTextureFilter(state.page.font.texture, .TRILINEAR);
    append(&state.page.editText, strings.builder_make())
    append(&state.page.textSplits, make([dynamic]int))
}

loadPageFromFile :: proc(state: ^State, path: cstring, file: cstring) {
    state.page = initialPage(state^)
    rl.SetTextureFilter(state.page.font.texture, .TRILINEAR);

    state.page.name = string(rl.GetFileNameWithoutExt(file))
    state.page.extension = string(rl.GetFileExtension(file))

    state.page.path = path
    rl.ChangeDirectory(path)

    readFile(state, file)
}

readFile :: proc(state: ^State, file: cstring) {

    data := rl.LoadFileText(file)
    datalen := len(cstring(data))

    words := 0

    alphanumeric := ALPHANUMERIC

    characterWidth := characterWidth(state.page.font, state.page.fontSize, state.page.fontSpacing)
    maxCharacters := maxCharactersPerLine(characterWidth, state.page.fontSpacing)

    append(&state.page.editText, strings.builder_make())
    append(&state.page.textSplits, make([dynamic]int))
    indx := 0
    for i in 0..<datalen {
        byt := data[i]

        if byt == '\n' {
            for j := maxCharacters ; j < len(state.page.editText[indx].buf) - 1 ; j += maxCharacters {
                if maxCharacters < 1 {
                    break
                }
                append(&state.page.textSplits[indx], cast(int) j + 1)
            }

            append(&state.page.editText, strings.builder_make())
            append(&state.page.textSplits, make([dynamic]int))
            indx += 1
            continue
        }

        strings.write_byte(&state.page.editText[indx], byt)
        len := strings.builder_len(state.page.editText[indx])
        if len == 1 && alphanumeric[byt] {
            words += 1
        } else if alphanumeric[byt] && !alphanumeric[state.page.editText[indx].buf[len - 2]] {
            words += 1
        }
    }

    state.page.words = words
    rl.UnloadFileText(data)
}

countPageWords :: proc(state: ^State) -> int {
    return 0
}

deleteCharacter :: proc(state: ^State) {
    work := &state.page.editText[state.cursor.line].buf

    alphanumeric := ALPHANUMERIC

    if state.cursor.column > 0 {
        char : u8 = work[state.cursor.column - 1]
        ordered_remove(work, state.cursor.column - 1)
        state.cursor.column -= 1

        if alphanumeric[char] {
            if state.cursor.column == 0 {
                state.page.words -= 1
            } else if !alphanumeric[work[state.cursor.column - 1]] {
                state.page.words -= 1
            }
        }
    } else if state.cursor.line > 0 {
        line := &state.page.editText[state.cursor.line]
        ordered_remove(&state.page.editText, state.cursor.line)

        old_len := strings.builder_len(state.page.editText[state.cursor.line - 1])
        strings.write_string(&state.page.editText[state.cursor.line - 1], strings.to_string(line^))
        state.cursor.line -= 1
        state.cursor.column = old_len

        if state.cursor.column > 0 {
            char : u8 = state.page.editText[state.cursor.line].buf[state.cursor.column - 1]
            if alphanumeric[char] {
                if strings.builder_len(state.page.editText[state.cursor.line]) > state.cursor.column {
                    char = state.page.editText[state.cursor.line].buf[state.cursor.column]
                    if alphanumeric[char] {
                        state.page.words -= 1
                    }
                }
            }
        }

        strings.builder_destroy(line)
    }

    flagActivePage(state)
    state.cursor.cursorFrame = 0.0

    capCursor(state)
}

backspacePage :: proc(state: ^State) {
    if !rl.IsKeyDown(.BACKSPACE) {
        return
    }

    if rl.IsKeyPressed(.BACKSPACE) {
        state.backspaceCooldown = 0.0
    }

    if state.backspaceCooldown == 0.0 {
        deleteCharacter(state)
    }

    state.backspaceCooldown += rl.GetFrameTime()

    if state.backspaceCooldown >= BACKSPACE_WAIT {
        if state.backspaceCooldown >= BACKSPACE_CYCLE {
            deleteCharacter(state)
            state.backspaceCooldown = BACKSPACE_WAIT
        }
    }
}

addNewLine :: proc(state: ^State) {
    work := &state.page.editText[state.cursor.line].buf

    pre := work[:state.cursor.column]
    post := work[state.cursor.column:]
    strings.builder_reset(&state.page.editText[state.cursor.line])
    strings.write_bytes(&state.page.editText[state.cursor.line], pre)

    inject_at(&state.page.editText, state.cursor.line + 1, strings.builder_make())
    strings.write_bytes(&state.page.editText[state.cursor.line + 1], post)

    state.cursor.line += 1
    state.cursor.column = 0

    flagActivePage(state)
    state.cursor.cursorFrame = 0.0

    alphanumeric := ALPHANUMERIC

    if len(pre) > 0 && len(post) > 0 {
        if alphanumeric[pre[len(pre)-1]] && alphanumeric[post[len(post)-1]] {
            state.page.words += 1
            state.page.sessionWords += 1
        }
    }

    capCursor(state)
}

enterPage :: proc(state: ^State) {
    if !rl.IsKeyDown(.ENTER) {
        return
    }

    if rl.IsKeyPressed(.ENTER) {
        state.enterCooldown = 0.0
    }

    if state.enterCooldown == 0.0 {
        addNewLine(state)
    }

    state.enterCooldown += rl.GetFrameTime()

    if state.enterCooldown >= ENTER_WAIT {
        if state.enterCooldown >= ENTER_CYCLE {
            addNewLine(state)
            state.enterCooldown = ENTER_WAIT
        }
    }
}

writePage :: proc(state: ^State) {
    key : int = cast(int) rl.GetCharPressed()

    work := &state.page.editText[state.cursor.line].buf

    alphanumeric := ALPHANUMERIC

    for key != 0 {
        if key < 0x20 || key > 0x7e {
            key = cast(int) rl.GetCharPressed()
            continue
        }

        /*sb := strings.builder_make()
        strings.write_string(&sb, strings.to_string(state.page.editText[state.cursor.line]))
        strings.write_byte(&sb, 'a')
        textpos := rl.MeasureTextEx(
            state.page.font, strings.to_cstring(&sb), state.page.fontSize, state.page.fontSpacing
        )

        strings.builder_destroy(&sb)

        if textpos.x > cast(f32) state.editWidth {
            if key != ' ' {
                addNewLine(state)
                work = &state.page.editText[state.cursor.line].buf
            }
        }*/

        inject_at(work, state.cursor.column, cast(u8) key)
        if alphanumeric[key] {
            if state.cursor.column == 0 {
                state.page.words += 1
                state.page.sessionWords += 1
            } else if !alphanumeric[work[state.cursor.column - 1]] {
                state.page.words += 1
                state.page.sessionWords += 1
            }
        }

        state.cursor.column += 1
        flagActivePage(state)

        key = cast(int) rl.GetCharPressed()
    }

    backspacePage(state)

    enterPage(state)
}

updatePage :: proc(state: ^State) {
    state.page.timeSeconds += rl.GetFrameTime()
    state.page.timeSinceLastUpdate += rl.GetFrameTime()

    if state.page.timeSinceLastUpdate <= INACTIVE_TIMER {
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

savePage :: proc(state: ^State) {
    master := strings.builder_make()
    for i in 0..<len(state.page.editText) {
        write := strings.to_string(state.page.editText[i])
        strings.write_string(&master, write)
        if write == "" && len(state.page.editText) > 1 {
            strings.write_byte(&master, '\n')
        }
    }

    strings.write_byte(&master, 0x00)

    fname := strings.builder_make()
    //strings.write_string(&fname, state.page.path)
    strings.write_string(&fname, state.page.name)
    strings.write_string(&fname, state.page.extension)

    rl.ChangeDirectory(state.page.path)
    success := rl.SaveFileText(strings.to_cstring(&fname), transmute([^]u8) strings.to_cstring(&master))

    strings.builder_destroy(&master)
    strings.builder_destroy(&fname)

    if success {
        state.page.unsaved = false
    }
}

resetPage :: proc(state: ^State) {
    state^ = initialState()
}