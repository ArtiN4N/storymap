package main

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

MENUWIDTH :: 130
MENUHEIGHT :: INFOHEIGHT + len(MENUOPTS) * LINEHEIGHT + INFOHEIGHT

MENUCOLOR : rl.Color : {0x10, 0x10, 0x20, 0xff}

MENUOPTS :: [?]cstring{
    "new",
    "open",
    "save",
    "save as",
    "rename",
    "quit"
}

drawMenu :: proc(state: State) {
    mBoxStartX := state.screenWidth - MENUWIDTH

    radius : i32 = 5
    menuBox : rl.Rectangle = { cast(f32) mBoxStartX - 1, 1, MENUWIDTH, MENUHEIGHT }

    if state.menuActive {
        tempBox := menuBox
        tempBox = { cast(f32) mBoxStartX - 2, 0, MENUWIDTH + 2, MENUHEIGHT + 2 }
        rl.DrawRectangleRec(tempBox, rl.WHITE)

        rl.DrawRectangleRec(menuBox, MENUCOLOR)

        selColor := TEXTCOLOR
        selColor.a = 50
        rl.DrawCircle(
            state.screenWidth - radius - 10, INFOHEIGHT / 2,
            cast(f32) radius + 5, selColor
        )
    }

    rl.DrawCircle(
        state.screenWidth - radius - 10, INFOHEIGHT / 2,
        cast(f32) radius, TEXTCOLOR
    )

    if !state.menuActive {
        return
    }

    mousePos := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mousePos, menuBox) && !state.fBox.active {
        hoverPos := (mousePos.y - INFOHEIGHT) / LINEHEIGHT
        if hoverPos < 0 {
            hoverPos = -1
        }

        hoverOpt := cast(int) hoverPos

        if hoverOpt >= 0 && hoverOpt < len(MENUOPTS) {
            hoverRec : rl.Rectangle = {
                cast(f32) mBoxStartX - 1, INFOHEIGHT + cast(f32) hoverOpt * LINEHEIGHT,
                MENUWIDTH, LINEHEIGHT
            }
            rl.DrawRectangleRec(hoverRec, CURSORLINECOLOR)
        } 
    }

    pos : rl.Vector2 = { cast(f32) mBoxStartX + TEXTMARGIN, INFOHEIGHT }
    for str in MENUOPTS {
        rl.DrawTextEx(
            state.page.font, str,
            pos, state.page.fontSize, state.page.fontSpacing, TEXTCOLOR
        )
        pos.y += LINEHEIGHT
    }
}

updateMenu :: proc(state: ^State) {
    radius : f32 = 5
    x : f32 = cast(f32) state.screenWidth - radius - 10
    y : f32 = INFOHEIGHT / 2

    mousePos := rl.GetMousePosition()
    leftClick := rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
    if rl.CheckCollisionPointCircle(mousePos, {x, y}, radius + 20) && leftClick {
        state.menuActive = !state.menuActive
    }

    if !state.menuActive {
        return
    }

    mBoxStartX := state.screenWidth - MENUWIDTH
    menuBox : rl.Rectangle = { cast(f32) mBoxStartX - 1, 1, MENUWIDTH, MENUHEIGHT }

    if rl.CheckCollisionPointRec(mousePos, menuBox) && leftClick {
        hoverPos := (mousePos.y - INFOHEIGHT) / LINEHEIGHT
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