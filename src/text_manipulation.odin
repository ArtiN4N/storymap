package main

import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

ALPHANUMERIC :: [?]bool{
    0x30..=0x39 = true,
    0x41..=0x5a = true,
    0x61..=0x7a = true,
}

// A procedure that updates the state to reflect that changes have just been made
flagActivePage :: proc(page: ^Page, cursor: ^Cursor) {
    page.timeSinceLastUpdate = 0.0
    page.unsaved = true
    cursor.cursorFrame = 0.0
}

// A procedure that counts the words in a string.
// Words are defined as a collection of 1 or more alphanumeric characters,
// seperated by non-alphanumeric characters, and the beggining and end of a line.
// The chracters directly before and after the string can be provided, to ensure that word counting of a substring
// within a larger string remains correct.
countWordsInString :: proc(working: string, prevChar, endChar: rune) -> int {
    alphanumeric := ALPHANUMERIC

    count := 0

    prevChar := prevChar

    for char in working {
        // If the current character is an alphanumeral, and succeeds a non-alphanumeral,
        // we can consider this a start of a new word, and increase the count.
        if alphanumeric[char] && !alphanumeric[prevChar] {
            count += 1
        }

        prevChar = char
    }

    // If the character directly after our string is an alphanumeral,
    // and the last character of the string is as well, then we know that
    // the last counted word has been miscounted, and is apart of
    // a larger word within the original string.
    if alphanumeric[endChar] && alphanumeric[prevChar] {
        count -= 1
    }

    return count
}

// A procedure that increments the session word counter.
// Incrementation both increases the logical word count, as well as the session word count.
// The session word count is used to calcluate the user's typed words per minute.
incrementWordCount :: proc(page: ^Page, count: int) {
    page.words += count
    page.sessionWords += count
}

// A procedure that decrements the logical word counter.
// The session word counter is not decremented, as it is used for calculating typed words per minute.
decrementWordCount :: proc(page: ^Page, count: int) {
    page.words -= count
}

// A procedure that grabs a byte from a byte buffer.
// This procedure does bounds checking, and if the desired index is out of scope, it returns a default byte,
// which by default is the null byte.
getCharWithBoundsCheck :: proc(buffer: []u8, index: int, default: u8 = 0x00) -> u8 {
    if index < 0 || index >= len(buffer) {
        return default
    }
    return buffer[index]
}

// A procedure that adds a single character to a spot in the edit text array.
addCharacterToEdit :: proc(page: ^Page, editText: ^[dynamic]strings.Builder, cursor: ^Cursor, toAdd: u8) {
    line := cursor.line
    column := cursor.line

    // Grab a pointer to the buffer of the specific line in the edit text array.
    buf := &editText[line].buf

    prevChar := getCharWithBoundsCheck(buf[:], column - 1)
    nextChar := getCharWithBoundsCheck(buf[:], column + 1)

    // Injection must occur after bounds checking, since the added character will be placed at column + 1.
    inject_at(buf, column, toAdd)

    // If the added character is alphanumeric, and it is injected between two non-alphanumeric characters,
    // then we consider a word to be added.
    alphanumeric := ALPHANUMERIC
    if alphanumeric[toAdd] && !alphanumeric[prevChar] && !alphanumeric[nextChar] {
        incrementWordCount(page, 1)
    }

    flagActivePage(page, cursor)
}

// A procedure that adds a string to a spot in the edit text array.
addStringToEdit :: proc(page: ^Page, editText: ^[dynamic]strings.Builder, cursor: ^Cursor, toAdd: string) {
    line := cursor.line
    column := cursor.line

    // Grab a pointer to the buffer of the specific line in the edit text array.
    buf := &editText[line].buf

    prevChar := cast(rune) getCharWithBoundsCheck(buf[:], column - 1)
    nextChar := cast(rune) getCharWithBoundsCheck(buf[:], column + 1)

    // Injection must occur after bounds checking,
    // since the added strings' first character will be placed at column + 1.
    inject_at(buf, column, toAdd)

    incrementWordCount(page, countWordsInString(toAdd, prevChar, nextChar))

    flagActivePage(page, cursor)
}

// A procedure that adds a newline to the edit text.
// A newline splits the current line around the cursor position,
// creates a new entry into the edit text array, and places the text after the cursor into the new string builder.
addNewLineToEdit :: proc(page: ^Page, editText: ^[dynamic]strings.Builder, cursor: ^Cursor) {
    line := cursor.line
    column := cursor.line

    // Grab a pointer to the buffer of the specific line in the edit text array.
    buf := &editText[line].buf

    // Slices that represent the text in the current string before and after the cursor.
    pre := buf[:column]
    post := buf[column:]

    // Resets the current string builder, and adds all text before the cursor.
    strings.builder_reset(&editText[line])
    strings.write_bytes(&editText[line], pre)

    // Adds a new string builder to the edit text array.
    inject_at(editText, line + 1, strings.builder_make())
    // Writes the text after the cursor into this new builder.
    strings.write_bytes(&editText[line + 1], post)

    alphanumeric := ALPHANUMERIC

    // If the last character of the text before the cursor, and the first character after it, are both alphanumerals,
    // Then we can consider its "word" to have been split into two, and thus we count a new word.
    if len(pre) > 0 && len(post) > 0 {
        if alphanumeric[pre[len(pre)-1]] && alphanumeric[post[0]] {
            incrementWordCount(page, 1)
        }
    }

    flagActivePage(page, cursor)
}

// A procedure that deletes a section of text from the edit text array.
removeSectionFromEdit :: proc(page: ^Page, editText: ^[dynamic]strings.Builder, cursor: ^Cursor) {
    selection := cursor.selection

    // Stores the edit text builder buffers' pointers for the first and last lines of the selection.
    buf1 := &editText[selection.startLine].buf
    buf2 := &editText[selection.endLine].buf

    // Retrieves the unaffected text in the lines associated with the selection.
    bytes1 := buf1[0 : selection.startColumn]
    bytes2 := buf2[selection.endColumn : len(buf2)]

    prevChar := cast(rune) getCharWithBoundsCheck(buf1[:], selection.startColumn - 1)
    nextChar := cast(rune) getCharWithBoundsCheck(buf2[:], selection.endColumn + 1)

    // Grabs the removed text from the first and last lines of the selection.
    removed1 := buf1[selection.startColumn : len(buf1)]
    removed2 := buf2[0 : selection.endColumn]

    // Creates a string builder to count the number of words in the removed selection.
    countingBuilder := strings.builder_make()
    // Writes the removed text in the first line.
    strings.write_bytes(&countingBuilder, removed1)
    strings.write_byte(&countingBuilder, '\n')

    // The first and last line of the removal selection are not the only lines in the selection.
    // All lines between the first and the last are subject to be removed.
    // We sliced the first and last lines because its possible for only part of the first or last line
    // to be removed.
    // However, we know that, for all lines inbetween the first and the last,
    // All text is to be removed.
    // Thus, we loop through the lines in between, and write the full buffers from the edit text array into the builder.
    readLine := selection.startLine + 1
    for readLine < selection.endLine {
        readBuf := &editText[readLine].buf
        strings.write_bytes(&countingBuilder, readBuf[:])
        strings.write_byte(&countingBuilder, '\n')
    }

    // Writes the removed text in the last line.
    strings.write_bytes(&countingBuilder, removed2)
    removedWords := countWordsInString(strings.to_string(countingBuilder), prevChar, nextChar)

    decrementWordCount(page, removedWords)

    // Clean up the builder used to count the removed words.
    strings.builder_destroy(&countingBuilder)

    strings.builder_reset(&editText[selection.startLine])
    strings.builder_reset(&editText[selection.endLine])

    // Write the leftover text into the first and last lines of the selection.
    strings.write_bytes(&editText[selection.startLine], bytes1)
    strings.write_bytes(&editText[selection.startLine], bytes2)

    // Remove and clean up all deleted lines from the edit text array.
    readLine = selection.startLine + 1
    for readLine < selection.endLine {
        readBuilder := &editText[readLine]
        ordered_remove(editText, readLine)
        strings.builder_destroy(readBuilder)
    }

    flagActivePage(page, cursor)
}