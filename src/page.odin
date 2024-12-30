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
    textSplits: [dynamic][dynamic]int,
    font: rl.Font,
    symbolsFont: rl.Font,
    fontSize: f32,
    fontSpacing: f32,

    select: PageSelection,

    name: string,
    extension: string,
    path: cstring,
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

initialPage :: proc(state: State) -> Page {
    cpoints : [^]rune

    rl.ChangeDirectory(rl.GetApplicationDirectory())

    return {
        text = make([dynamic]strings.Builder),
        textSplits = make([dynamic][dynamic]int),
        font = rl.LoadFontEx("fonts/Noto_Sans_Mono/NotoSansMono-VariableFont_wdth,wght.ttf", 40, cpoints, 0),
        symbolsFont = rl.LoadFontEx("fonts/Geist_Mono/GeistMono-VariableFont_wght.ttf", 40, cpoints, 0),
        fontSize = 22,
        fontSpacing = 2,

        select = {},

        name = "untitled",
        extension = ".txt",
        path = "",
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
    // unload builders in text
    for i in 0..<len(page.text) {
        strings.builder_destroy(&page.text[i])
    }
    delete(page.text)

    for i in 0..<len(page.textSplits) {
        delete(page.textSplits[i])
    }
    delete(page.textSplits)

    rl.UnloadFont(page.font)
    rl.UnloadFont(page.symbolsFont)
}

createPage :: proc(state: ^State) {
    state.page = initialPage(state^)
    rl.SetTextureFilter(state.page.font.texture, rl.TextureFilter.TRILINEAR);
    append(&state.page.text, strings.builder_make())
    append(&state.page.textSplits, make([dynamic]int))
}

loadPageFromFile :: proc(state: ^State, path: cstring, file: cstring) {
    state.page = initialPage(state^)
    rl.SetTextureFilter(state.page.font.texture, rl.TextureFilter.TRILINEAR);

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

    append(&state.page.text, strings.builder_make())
    append(&state.page.textSplits, make([dynamic]int))
    indx := 0
    for i in 0..<datalen {
        byt := data[i]

        if byt == '\n' {
            for j := state.lineCharsMax ; j < cast(i32) len(state.page.text[indx].buf) - 1 ; j += state.lineCharsMax {
                if state.lineCharsMax < 1 {
                    break
                }
                append(&state.page.textSplits[indx], cast(int) j + 1)
            }

            append(&state.page.text, strings.builder_make())
            append(&state.page.textSplits, make([dynamic]int))
            indx += 1
            continue
        }

        strings.write_byte(&state.page.text[indx], byt)
        len := strings.builder_len(state.page.text[indx])
        if len == 1 && alphanumeric[byt] {
            words += 1
        } else if alphanumeric[byt] && !alphanumeric[state.page.text[indx].buf[len - 2]] {
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
        line := &state.page.text[state.line]
        ordered_remove(&state.page.text, state.line)

        old_len := strings.builder_len(state.page.text[state.line - 1])
        strings.write_string(&state.page.text[state.line - 1], strings.to_string(line^))
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

        strings.builder_destroy(line)
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

        /*sb := strings.builder_make()
        strings.write_string(&sb, strings.to_string(state.page.text[state.line]))
        strings.write_byte(&sb, 'a')
        textpos := rl.MeasureTextEx(
            state.page.font, strings.to_cstring(&sb), state.page.fontSize, state.page.fontSpacing
        )

        strings.builder_destroy(&sb)

        if textpos.x > cast(f32) state.editWidth {
            if key != ' ' {
                addNewLine(state)
                work = &state.page.text[state.line].buf
            }
        }*/

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

savePage :: proc(state: ^State) {
    master := strings.builder_make()
    for i in 0..<len(state.page.text) {
        write := strings.to_string(state.page.text[i])
        strings.write_string(&master, write)
        if write == "" && len(state.page.text) > 1 {
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