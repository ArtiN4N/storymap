package main

import "core:strings"

import rl "vendor:raylib"

BACKSPACEWAIT :: 0.3
BACKSPACECYCLE :: BACKSPACEWAIT + 0.025

ENTERWAIT :: 0.3
ENTERCYCLE :: ENTERWAIT + 0.025

Page :: struct {
    text: [dynamic]strings.Builder,
    font: rl.Font,
    fontSize: f32,
    fontSpacing: f32,
    select: PageSelection,
}

initialPage :: proc() -> Page {
    cpoints : [^]rune
    return {
        text = make([dynamic]strings.Builder),
        font = rl.LoadFontEx("fonts/Noto_Sans_Mono/NotoSansMono-VariableFont_wdth,wght.ttf", 40, cpoints, 0),
        fontSize = 22,
        fontSpacing = 2,
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

    if state.column > 0 {
        ordered_remove(work, state.column - 1)
        state.column -= 1
    } else if state.line > 0 {
        line := state.page.text[state.line]
        ordered_remove(&state.page.text, state.line)

        old_len := strings.builder_len(state.page.text[state.line - 1])
        strings.write_string(&state.page.text[state.line - 1], strings.to_string(line))
        state.line -= 1
        state.column = old_len
    }

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

    for key != 0 {
        if key < 0x20 || key > 0x7e {
            key = cast(int) rl.GetCharPressed()
            continue
        }

        sb := strings.builder_make()
        strings.write_string(&sb, strings.to_string(state.page.text[state.line]))
        strings.write_byte(&sb, 0x42)
        textpos := rl.MeasureTextEx(
            state.page.font, strings.to_cstring(&sb), state.page.fontSize, state.page.fontSpacing
        )
        if textpos.x > cast(f32) state.editWidth {
            addNewLine(state)
            work = &state.page.text[state.line].buf
        }

        inject_at(work, state.column, cast(u8) key)
        state.column += 1
        key = cast(int) rl.GetCharPressed()
    }

    backspacePage(state)

    enterPage(state)
}