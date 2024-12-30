package main

import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

movePageView :: proc(cursor: ^Cursor, page: ^Page) {
    if page.topViewLine < cursor.line {
        page.topViewLine = cursor.line
    }

    if page.bottomViewLine > cursor.line {
        page.topViewLine += page.bottomViewLine - cursor.line
    }
}

capCursor :: proc(cursor: ^Cursor, editText: ^[dynamic]strings.Builder) {
    if cursor.line < 0 {
        moveCursorToBeginning(cursor)
    }

    if cursor.line >= len(editText) {
        moveCursorToEnd(cursor, editText)
    }

    if cursor.column < 0 {
        if cursor.line > 0 {
            moveCursorUp(cursor, editText)
            moveCursorToLineEnd(cursor, editText)
        } else {
            cursor.column = 0
        }
    }

    if cursor.column >= strings.builder_len(editText[cursor.line]) {
        if cursor.line >= len(editText) {
            moveCursorDown(cursor, editText)
            moveCursorToLineBeginning(cursor)
        } else {
            cursor.column = strings.builder_len(editText[cursor.line]) - 1
        }
    }
}

moveCursorUp :: proc(cursor: ^Cursor, editText: ^[dynamic]strings.Builder) {
    cursor.line -= 1
    capCursor(cursor, editText)
}

moveCursorDown :: proc(cursor: ^Cursor, editText: ^[dynamic]strings.Builder) {
    cursor.line += 1
    capCursor(cursor, editText)
}

moveCursorLeft :: proc(cursor: ^Cursor, editText: ^[dynamic]strings.Builder) {
    cursor.column -= 1
    capCursor(cursor, editText)
}

moveCursorRight :: proc(cursor: ^Cursor, editText: ^[dynamic]strings.Builder) {
    cursor.column += 1
    capCursor(cursor, editText)
}

moveCursorToLineBeginning :: proc(cursor: ^Cursor) {
    cursor.column = 0
}

moveCursorToBeginning :: proc(cursor: ^Cursor) {
    cursor.line = 0
    moveCursorToLineBeginning(cursor)
}

moveCursorToLineEnd :: proc(cursor: ^Cursor, editText: ^[dynamic]strings.Builder) {
    cursor.column = strings.builder_len(editText[cursor.line])
}

moveCursorToEnd :: proc(cursor: ^Cursor, editText: ^[dynamic]strings.Builder) {
    cursor.line = len(editText) - 1
    moveCursorToLineEnd(cursor, editText)
}

moveCursorToTopView :: proc(cursor: ^Cursor, topViewLine: int) {
    cursor.line = topViewLine
}

moveCursorToBottomView :: proc(cursor: ^Cursor, bottomViewLine: int) {
    cursor.line = bottomViewLine
}

moveCursorToPosition :: proc(cursor: ^Cursor, line, column: int) {
    cursor.line = line
    cursor.column = column
}

capPageView :: proc(page: ^Page, window: WindowObject) {
    if page.topViewLine < 0 {
        page.topViewLine = 0
    } else if page.topViewLine >= page.visualLines {
        page.topViewLine = page.visualLines - 1
    }

    page.bottomViewLine = page.topViewLine + maxViewLines(window.height) - 1
    if page.bottomViewLine < 0 {
        page.bottomViewLine = 0
    }

    if page.bottomViewLine >= len(page.editText) {
        page.bottomViewLine = len(page.editText) - 1
    }
}

movePageViewUp :: proc(page: ^Page, window: WindowObject) {
    page.topViewLine -= 1
    capPageView(page, window)
}

movePageViewDown :: proc(page: ^Page, window: WindowObject) {
    page.topViewLine += 1
    capPageView(page, window)
}

movePageViewToPosition :: proc(page: ^Page, line: int, window: WindowObject) {
    page.topViewLine = line
    capPageView(page, window)
}
