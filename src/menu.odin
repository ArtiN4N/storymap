package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

MENU_WIDTH :: 130
MENU_HEIGHT :: INFO_HEIGHT + len(MENU_OPTS) * LINE_HEIGHT + INFO_HEIGHT

MENU_COLOR : rl.Color : {0x10, 0x10, 0x20, 0xff}

MENUOPTS :: [?]cstring{
    "new",
    "open",
    "save",
    "save as",
    "rename",
    "quit"
}

drawMenu :: proc(state: State) {
    mBoxStartX := state.window.width - MENU_WIDTH

    radius : int = 5
    menuBox : rl.Rectangle = { cast(f32) mBoxStartX - 1, 1, MENU_WIDTH, MENU_HEIGHT }

    if state.menuActive {
        tempBox := menuBox
        tempBox = { cast(f32) mBoxStartX - 2, 0, MENU_WIDTH + 2, MENU_HEIGHT + 2 }
        rl.DrawRectangleRec(tempBox, rl.WHITE)

        rl.DrawRectangleRec(menuBox, MENU_COLOR)

        selColor := TEXT_COLOR
        selColor.a = 50
        rl.DrawCircle(
            cast(i32) (state.window.width - radius - 10), INFO_HEIGHT / 2,
            cast(f32) radius + 5, selColor
        )
    }

    rl.DrawCircle(
        cast(i32) (state.window.width - radius - 10), INFO_HEIGHT / 2,
        cast(f32) radius, TEXT_COLOR
    )

    if !state.menuActive {
        return
    }

    mousePos := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mousePos, menuBox) && !state.fBox.active {
        hoverPos := (mousePos.y - INFO_HEIGHT) / LINE_HEIGHT
        if hoverPos < 0 {
            hoverPos = -1
        }

        hoverOpt := cast(int) hoverPos

        if hoverOpt >= 0 && hoverOpt < len(MENU_OPTS) {
            hoverRec : rl.Rectangle = {
                cast(f32) mBoxStartX - 1, INFO_HEIGHT + cast(f32) hoverOpt * LINE_HEIGHT,
                MENU_WIDTH, LINE_HEIGHT
            }
            rl.DrawRectangleRec(hoverRec, CURSOR_LINE_COLOR)
        } 
    }

    pos : rl.Vector2 = { cast(f32) mBoxStartX + TEXT_MARGIN, INFO_HEIGHT }
    for str in MENU_OPTS {
        rl.DrawTextEx(
            state.page.font, str,
            pos, state.page.fontSize, state.page.fontSpacing, TEXT_COLOR
        )
        pos.y += LINE_HEIGHT
    }
}

updateMenu :: proc(state: ^State) {
    radius : f32 = 5
    x : f32 = cast(f32) state.window.width - radius - 10
    y : f32 = INFO_HEIGHT / 2

    mousePos := rl.GetMousePosition()
    leftClick := rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
    if rl.CheckCollisionPointCircle(mousePos, {x, y}, radius + 20) && leftClick {
        state.menuActive = !state.menuActive
    }

    if !state.menuActive {
        return
    }

    mBoxStartX := state.window.width - MENU_WIDTH
    menuBox : rl.Rectangle = { cast(f32) mBoxStartX - 1, 1, MENU_WIDTH, MENU_HEIGHT }

    if rl.CheckCollisionPointRec(mousePos, menuBox) && leftClick {
        hoverPos := (mousePos.y - INFO_HEIGHT) / LINE_HEIGHT
        if hoverPos < 0 {
            hoverPos = -1
        }

        hoverOpt := cast(int) hoverPos
        switch (hoverOpt) {
            case 0:
                resetState(state)
            case 1:
                openFileBox(state)
            case 2:
                savePage(state)
            case 3:
            case 4:
            case 5:
                quitShortcut(state)
        }
    }
}