package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

EDITORCOLOR : rl.Color : {0x1e, 0x1e, 0x2e, 0xff}
SPINECOLOR  : rl.Color : {0x18, 0x18, 0x28, 0xff}
TEXTCOLOR : rl.Color : {0xdd, 0xdd, 0xdd, 0xff}
CURSORCOLOR : rl.Color : {0x10, 0x7a, 0xb0, 0xff}
CURSORLINECOLOR : rl.Color : {0x2e, 0x2e, 0x3e, 0xff}

SPINEWIDTH :: 40
LINEHEIGHT :: 22

TEXTMARGIN :: 15

CURSORWIDTH :: 2
CURSORWAIT :: 0.3
CURSORCYCLE :: CURSORWAIT + 0.025

BACKSPACEWAIT :: 0.3
BACKSPACECYCLE :: BACKSPACEWAIT + 0.025

ENTERWAIT :: 0.3
ENTERCYCLE :: ENTERWAIT + 0.025


PageSelection :: struct {
    linea: int,
    lineb: int,
    columna: int,
    columnb: int,
}

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


drawLineNumbers :: proc(state: State) {
    spine : rl.Rectangle = { 0, 0, SPINEWIDTH, cast(f32) state.screenHeight }
    rl.DrawRectangleRec(spine, SPINECOLOR)

    cursorline : rl.Rectangle = {
        0, cast(f32) (TEXTMARGIN + state.line * LINEHEIGHT),
        cast(f32) state.screenWidth, LINEHEIGHT
    }
    rl.DrawRectangleRec(cursorline, CURSORLINECOLOR)

    pos : rl.Vector2 = { 0, TEXTMARGIN }
    lines := len(state.page.text)
    for i in 1..=lines {
        text := rl.TextFormat("%d", i)
        characterSize := rl.MeasureTextEx(state.page.font, text, state.page.fontSize, state.page.fontSpacing)
        drawpos := pos
        drawpos.x += (SPINEWIDTH - characterSize.x) / 2.0
        rl.DrawTextEx(
            state.page.font, text,
            drawpos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
        )
        pos.y += LINEHEIGHT
    }
}

drawPageText :: proc(state: State) {
    pos : rl.Vector2 = { TEXTMARGIN + SPINEWIDTH, TEXTMARGIN }
    lines := len(state.page.text)

    for i in 0..<lines {
        rl.DrawTextEx(
            state.page.font, strings.to_cstring(&state.page.text[i]),
            pos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
        )
        pos.y += LINEHEIGHT
    }
}

drawCursor :: proc(state: State) {
    if state.cursorFrame > 0.5 {
        return
    }

    characterSize := rl.MeasureTextEx(state.page.font, "a", state.page.fontSize, state.page.fontSpacing)
    cursor : rl.Rectangle = {
        x = TEXTMARGIN + SPINEWIDTH + (characterSize.x + state.page.fontSpacing) * cast(f32) state.column,
        y = TEXTMARGIN + characterSize.y * cast(f32) state.line,
        width = CURSORWIDTH,
        height = LINEHEIGHT
    }
    rl.DrawRectangleRec(cursor, CURSORCOLOR)
}

moveCursor :: proc(state: ^State) {
    if state.heldKey == rl.KeyboardKey.KEY_NULL {
        return
    }

    state.cursorFrame = 0.0

    axis: ^int
    direction: int

    if state.heldKey == rl.KeyboardKey.LEFT {
        direction = -1
        axis = &state.column
    } else if state.heldKey == rl.KeyboardKey.RIGHT {
        direction = 1
        axis = &state.column
    } else if state.heldKey == rl.KeyboardKey.UP {
        direction = -1
        axis = &state.line
    } else if state.heldKey == rl.KeyboardKey.DOWN {
        direction = 1
        axis = &state.line
    }

    if state.cursorCooldown == 0.0 {
        axis^ += direction
    }

    state.cursorCooldown += rl.GetFrameTime()

    if state.cursorCooldown >= CURSORWAIT {
        if state.cursorCooldown >= CURSORCYCLE {
            axis^ += direction
            state.cursorCooldown = CURSORWAIT
        }
    }

    capCursor(state)
}

updateCursor :: proc(state: ^State) {
    state.cursorFrame += rl.GetFrameTime()
    if state.cursorFrame > 1.0 {
        state.cursorFrame = 0.0
    }

    if !rl.IsKeyDown(state.heldKey) {
        state.heldKey = rl.KeyboardKey.KEY_NULL
    }

    if rl.IsKeyPressed(rl.KeyboardKey.UP) {
        state.heldKey = rl.KeyboardKey.UP
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
        state.heldKey = rl.KeyboardKey.DOWN
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
        state.heldKey = rl.KeyboardKey.LEFT
        state.cursorCooldown = 0.0
    }
    if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
        state.heldKey = rl.KeyboardKey.RIGHT
        state.cursorCooldown = 0.0
    }

    moveCursor(state)
}

capCursor :: proc(state: ^State) {
    if state.line < 0 {
        state.line = 0
    } else if state.line >= len(state.page.text) && state.line > 0 {
        state.line = len(state.page.text) - 1
    }

    if state.column < 0 {
        state.column = 0
    } else if len(state.page.text) > 0 {
        if state.column > strings.builder_len(state.page.text[state.line]) {
            state.column = strings.builder_len(state.page.text[state.line])
        }
    }
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

        editLength := state.screenWidth - 2 * TEXTMARGIN - SPINEWIDTH
        sb := strings.builder_make()
        strings.write_string(&sb, strings.to_string(state.page.text[state.line]))
        strings.write_byte(&sb, 0x42)
        textpos := rl.MeasureTextEx(
            state.page.font, strings.to_cstring(&sb), state.page.fontSize, state.page.fontSpacing
        )
        if textpos.x > cast(f32) editLength {
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

main :: proc() {
    state := initialState()
    defer destroyState(&state)

    addConfigFlag(&state, rl.ConfigFlag.VSYNC_HINT)
    addConfigFlag(&state, rl.ConfigFlag.WINDOW_RESIZABLE)
    addConfigFlag(&state, rl.ConfigFlag.MSAA_4X_HINT)
    addConfigFlag(&state, rl.ConfigFlag.WINDOW_HIGHDPI)
    rl.SetConfigFlags(state.flags)

    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    rl.InitWindow(state.screenWidth, state.screenHeight, "storymap")
    defer rl.CloseWindow()

    createPage(&state)
    defer destroyPage(&state.page)

    rl.SetTargetFPS(30)

    for !rl.WindowShouldClose() && !state.close {
        checkShortCuts(&state)

        if rl.IsWindowResized() {
            updateScreenSize(&state)
        }

        updateCursor(&state)
        writePage(&state)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(EDITORCOLOR)

        drawLineNumbers(state)
        drawPageText(state)
        drawCursor(state)
    }
}