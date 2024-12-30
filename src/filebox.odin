package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

FBOXWIDTH :: 600
FBOXHEIGHT :: 300

FileBox :: struct {
    cursor: u32,
    dir: cstring,
    active: bool,
    dirItems: [3]rl.FilePathList,
    itemsCount: u32,
}

initialFileBox :: proc() -> FileBox {
    return {
        0,
        "",
        false,
        {},
        0,
    }
}

setFileBox :: proc(state: ^State) {
    state.fBox.dirItems = {
        rl.LoadDirectoryFiles(state.fBox.dir),
        rl.LoadDirectoryFilesEx(state.fBox.dir, ".txt", false),
        rl.LoadDirectoryFilesEx(state.fBox.dir, ".md", false),
    }

    // +1 for previous dir
    state.fBox.itemsCount = state.fBox.dirItems[0].count + state.fBox.dirItems[1].count + state.fBox.dirItems[2].count + 1

    // -1 for fake dirs
    for k in 0..<state.fBox.dirItems[0].count {
        path := state.fBox.dirItems[0].paths[k]
        if rl.IsPathFile(path) {
            state.fBox.itemsCount -= 1
            continue
        }

        pathData := transmute([^]u8) path
        pathData = pathData[len(state.fBox.dir) + 1:]

        if pathData[0] == '.' {
            state.fBox.itemsCount -= 1
            continue
        }
    }
}

openFileBox :: proc(state: ^State) {
    state.fBox.active = true

    state.fBox.dir = rl.GetWorkingDirectory()

    setFileBox(state)
}

closeFileBox :: proc(state: ^State) {
    rl.UnloadDirectoryFiles(state.fBox.dirItems[0])
    rl.UnloadDirectoryFiles(state.fBox.dirItems[1])
    rl.UnloadDirectoryFiles(state.fBox.dirItems[2])

    state.fBox.itemsCount = 0
}

updateFileBox :: proc(state: ^State) {
    lineHeight : f32 = 18

    fBox : rl.Rectangle = {
        cast(f32) (state.screenWidth - FBOXWIDTH) / 2,
        cast(f32) (state.screenHeight - FBOXHEIGHT) / 2,
        FBOXWIDTH, FBOXHEIGHT
    }

    //Box.y + 10.0 + cast(f32) (state.fBox.cursor + 1) * lineHeight

    mousePos := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mousePos, fBox) {
        hoverPos := (mousePos.y - fBox.y - 10 - lineHeight) / lineHeight
        if hoverPos < 0 {
            hoverPos = -1
        }

        state.fBox.cursor = cast(u32) hoverPos
    }

    if rl.IsKeyPressed(rl.KeyboardKey.UP) {
        state.fBox.cursor -= 1

        if state.fBox.cursor < 0 {
            state.fBox.cursor = 0
        }
    }

    if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
        state.fBox.cursor += 1

        if state.fBox.cursor >= state.fBox.itemsCount {
            state.fBox.cursor = state.fBox.itemsCount - 1
        }
    }

    if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || (rl.CheckCollisionPointRec(mousePos, fBox) && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) {
        if state.fBox.cursor < 0 || state.fBox.cursor >= state.fBox.itemsCount {
            return
        }

        if state.fBox.cursor == 0 {
            rl.ChangeDirectory("../")
            state.fBox.dir = rl.GetWorkingDirectory()
            closeFileBox(state)
            setFileBox(state)
        } else {
            i : u32 = 0
            l := 0
            str : ^cstring
            skip := false
            for k in 0..<state.fBox.dirItems[0].count {
                path := state.fBox.dirItems[0].paths[k]
                if rl.IsPathFile(path) {
                    continue
                }

                pathData := transmute([^]u8) path
                pathData = pathData[len(state.fBox.dir) + 1:]

                if pathData[0] == '.' {
                    continue
                }

                i += 1
                if i == state.fBox.cursor {
                    str = &state.fBox.dirItems[0].paths[k]
                    skip = true
                    break
                }
            }

            finditem: for j in 1..<3 {
                if skip {
                    break
                }

                l += 1

                for k in 0..<state.fBox.dirItems[j].count {
                    i += 1
                    if i == state.fBox.cursor {
                        str = &state.fBox.dirItems[j].paths[k]
                        break finditem
                    }
                }
            }

            if l == 0 {
                rl.ChangeDirectory(str^)
                state.fBox.dir = rl.GetWorkingDirectory()
                closeFileBox(state)
                setFileBox(state)
            } else {
                destroyPage(&state.page)
                loadPageFromFile(state, state.fBox.dir, str^)
                closeFileBox(state)
                state.fBox.active = false
                return
            }
        }
    }
}

drawFileBox :: proc(state: State) {
    if !state.fBox.active {
        return
    }

    fontSize : f32 = 18
    lineHeight : f32 = 18

    fBox : rl.Rectangle = {
        cast(f32) (state.screenWidth - FBOXWIDTH) / 2,
        cast(f32) (state.screenHeight - FBOXHEIGHT) / 2,
        FBOXWIDTH, FBOXHEIGHT
    }

    tempBox := fBox
    tempBox.x -= 1
    tempBox.y -= 1
    tempBox.width += 2
    tempBox.height += 2
    rl.DrawRectangleRec(tempBox, rl.WHITE)

    rl.DrawRectangleRec(fBox, EDITORCOLOR)

    dirBox : rl.Rectangle = {
        cast(f32) (state.screenWidth - FBOXWIDTH) / 2,
        cast(f32) (state.screenHeight - FBOXHEIGHT) / 2,
        FBOXWIDTH, lineHeight + 10
    }
    rl.DrawRectangleRec(dirBox, INFOCOLOR)

    pos : rl.Vector2 = { fBox.x + 5, fBox.y + 5 }
    rl.DrawTextEx(
        state.page.font, state.fBox.dir,
        pos, fontSize, state.page.fontSpacing, TEXTCOLOR
    )

    if state.fBox.cursor >= 0 && state.fBox.cursor < state.fBox.itemsCount {
        hoverRec : rl.Rectangle = {
            cast(f32) (state.screenWidth - FBOXWIDTH) / 2,
            fBox.y + 10.0 + cast(f32) (state.fBox.cursor + 1) * lineHeight,
            FBOXWIDTH, lineHeight
        }
        rl.DrawRectangleRec(hoverRec, CURSORLINECOLOR)
    }

    pos.y += 5
    pos.y += lineHeight
    rl.DrawTextEx(
        state.page.font, "../",
        pos, fontSize, state.page.fontSpacing, TEXTCOLOR
    )

    for i in 0..<state.fBox.dirItems[0].count {
        path := state.fBox.dirItems[0].paths[i]
        if rl.IsPathFile(path) {
            continue
        }

        pathData := transmute([^]u8) path
        pathData = pathData[len(state.fBox.dir) + 1:]

        if pathData[0] == '.' {
            continue
        }

        sb := strings.builder_make()

        strings.write_string(&sb, string(cstring(pathData)))
        strings.write_byte(&sb, '/')

        pos.y += lineHeight
        rl.DrawTextEx(
            state.page.font, strings.to_cstring(&sb),
            pos, fontSize, state.page.fontSpacing, TEXTCOLOR
        )

        strings.builder_destroy(&sb)
    }

    for i in 1..<3 {
        for j in 0..<state.fBox.dirItems[i].count {
            path := state.fBox.dirItems[i].paths[j]

            pathData := transmute([^]u8) path
            pathData = pathData[len(state.fBox.dir) + 1:]

            fileName := cstring(pathData)

            pos.y += lineHeight
            rl.DrawTextEx(
                state.page.font, fileName,
                pos, fontSize, state.page.fontSpacing, TEXTCOLOR
            )
        }
    }
}