import sequtils, re, strutils, strformat, packages/docutils/highlite

let NEW_LINE = re"\n|\r"

type
  Highliter = ref object
    tknzr: GeneralTokenizer
    code: string
    lang: SourceLanguage

proc newHighliter(item: TextItem): Highliter =
  var tknzr: GeneralTokenizer

  tknzr.initGeneralTokenizer(item.literal)

  result = Highliter(
    tknzr: tknzr,
    code: item.literal,
    lang: getSourceLanguage(item.language)
  )

# pulls the current token
proc plain(h: Highliter): string =
  return h.code.substr(h.tknzr.start, h.tknzr.length + h.tknzr.start - 1)

# note: the css for the color should exist
proc decorate(h: Highliter, color: string): string =
  return fmt"<span class='{color}'>{h.plain()}</span>"

proc compile(h: Highliter): string =
  var f: string = ""
  if h.lang == langNone:
    return h.code
  while true:
    h.tknzr.getNextToken(h.lang)
    case h.tknzr.kind
    of gtEof: return f
    of gtOperator, gtPreprocessor, gtPunctuation:
      f &= h.decorate("red")
    of gtStringLit, gtLongStringLit:
      f &= h.decorate("yellow")
    of gtDecNumber, gtFloatNumber, gtBinNumber, gtHexNumber, gtOctNumber, 
        gtHyperlink:
      f &= h.decorate("blue")
    of gtComment, gtLongComment:
      f &= h.decorate("grey")
    of gtKeyword, gtLabel, gtReference, gtRule:
      f &= h.decorate("purple")
    of gtCharLit, gtValue, gtRawData, gtAssembler, gtDirective, gtCommand, gtTagStart, gtTagEnd:
      f &= h.decorate("pink")
    else:
      f &= h.plain()

proc sectionIdentifier(message: Message): string =
  result = message.fromAuthor
  # Force section change, because group status messages are sent with the
  # same fromAuthor, and ends up causing the header to not be shown
  if message.contentType == ContentType.Group:
    result = "GroupChatMessage"

proc mention(self: ChatMessageList, pubKey: string): string =
  if self.status.chat.contacts.hasKey(pubKey):
    return ens.userNameOrAlias(self.status.chat.contacts[pubKey], true)
  generateAlias(pubKey)


# See render-inline in status-react/src/status_im/ui/screens/chat/message/message.cljs
proc renderInline(self: ChatMessageList, elem: TextItem): string =
  let value = escape_html(elem.literal).multiReplace(("\r\n", "<br/>")).multiReplace(("\n", "<br/>")).multiReplace(("  ", "&nbsp;&nbsp;"))
  case elem.textType:
  of "": result = value
  of "code": result = fmt("<code>{value}</code>")
  of "emph": result = fmt("<em>{value}</em>")
  of "strong": result = fmt("<strong>{value}</strong>")
  of "strong-emph": result = fmt(" <strong><em>{value}</em></strong> ")
  of "link": result = fmt("{elem.destination}")
  of "mention": result = fmt("<a href=\"//{value}\" class=\"mention\">{self.mention(value)}</a>")
  of "status-tag": result = fmt("<a href=\"#{value}\" class=\"status-tag\">#{value}</a>")
  of "del": result = fmt("<del>{value}</del>")
  else: result = fmt(" {value} ")

# See render-block in status-react/src/status_im/ui/screens/chat/message/message.cljs
proc renderBlock(self: ChatMessageList, message: Message): string =
  for pMsg in message.parsedText:
    case pMsg.textType:
      of "paragraph": 
        result = result & "<p>"
        for children in pMsg.children:
          result = result & self.renderInline(children)
        result = result & "</p>"
      of "blockquote":
        var
          blockquote = escape_html(pMsg.literal)
          lines = toSeq(blockquote.split(NEW_LINE))
        for i in 0..(lines.len - 1):
          if i + 1 >= lines.len:
            continue
          if lines[i + 1] != "":
            lines[i] = lines[i] & "<br/>"
        blockquote = lines.join("")
        result = result & fmt(
          "<table class=\"blockquote\">" &
            "<tr>" &
              "<td class=\"quoteline\" valign=\"middle\"></td>" &
              "<td>{blockquote}</td>" &
            "</tr>" &
          "</table>")
      of "codeblock":
        result = result & "<code>" & newHighliter(pMsg).compile() & "</code>"
    result = result.strip()
