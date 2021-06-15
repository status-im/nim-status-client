import NimQml, Tables, json, sequtils, chronicles, times, re, sugar, strutils, os, strformat, algorithm

logScope:
  topics = "formatinput-view"

QtObject:
  type FormatInputView* = ref object of QObject

  proc setup(self: FormatInputView) = self.QObject.setup
  proc delete*(self: FormatInputView) = self.QObject.delete

  proc newFormatInputView*(): FormatInputView =
    new(result, delete)
    result.setup

  proc formatInputStuff(self: FormatInputView, regex: Regex, inputText: string): string =
    var matches: seq[tuple[first, last: int]] = @[(-1, 0)]

    var resultTuple: tuple[first, last: int]
    var start = 0
    var results: seq[tuple[first, last: int]] = @[]

    while true:
      resultTuple = inputText.findBounds(regex, matches, start)
      if (resultTuple[0] == -1):
        break
      start = resultTuple[1] + 1
      results.add(matches[0])

    if (results.len == 0):
      return ""
    
    var jsonString = "["
    var first = true
    
    for result in results:
      if (not first):
        jsonString = jsonString & ","
      first = false
      jsonString = jsonString & "[" & $result[0] & "," & $result[1] & "]"

    jsonString = jsonString & "]"

    return jsonString

  proc formatInputItalic(self: FormatInputView, inputText: string): string {.slot.} =
    let italicRegex = re"""(?<!\>)(?<!\*)\*(?!<span style=" font-style:italic;">)([^*]+)(?!<\/span>)\*"""
    self.formatInputStuff(italicRegex, inputText)

  proc formatInputBold(self: FormatInputView, inputText: string): string {.slot.} =
    let boldRegex = re"""(?<!\>)\*\*(?!<span style=" font-weight:600;">)([^*]+)(?!<\/span>)\*\*"""
    self.formatInputStuff(boldRegex, inputText)

  proc formatInputStrikeThrough(self: FormatInputView, inputText: string): string {.slot.} =
    let strikeThroughRegex = re"""(?<!\>)~~(?!<span style=" text-decoration: line-through;">)([^*]+)(?!<\/span>)~~"""
    self.formatInputStuff(strikeThroughRegex, inputText)

  proc formatInputCode(self: FormatInputView, inputText: string): string {.slot.} =
    let strikeThroughRegex = re"""(?<!\>)`(?!<span style=" font-family:'monospace';">)([^*]+)(?!<\/span>)`"""
    self.formatInputStuff(strikeThroughRegex, inputText)
