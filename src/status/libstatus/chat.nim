import json, times, strutils, sequtils, chronicles, json_serialization, algorithm, strformat
import core, utils
import ../chat/[chat, message]
import ../signals/messages
import ./types
import ./settings

proc buildFilter*(chat: Chat):JsonNode =
  if chat.chatType == ChatType.PrivateGroupChat:
    return newJNull()
  result = %* { "ChatID": chat.id, "OneToOne": chat.chatType == ChatType.OneToOne }

proc loadFilters*(filters: seq[JsonNode]): string =
  result =  callPrivateRPC("loadFilters".prefix, %* [filter(filters, proc(x:JsonNode):bool = x.kind != JNull)])

proc removeFilters*(chatId: string, filterId: string) =
  discard callPrivateRPC("removeFilters".prefix, %* [
    [{ "ChatID": chatId, "FilterID": filterId }]
  ])

proc saveChat*(chatId: string, chatType: ChatType, active: bool = true, color: string = "#000000", ensName: string = "", profile: string = "") =
  # TODO: ideally status-go/stimbus should handle some of these fields instead of having the client
  # send them: lastMessage, unviewedMEssagesCount, timestamp, lastClockValue, name?
  discard callPrivateRPC("saveChat".prefix, %* [
    {
      "lastClockValue": 0, # TODO:
      "color": color,
      "name": (if ensName != "": ensName else: chatId),
      "lastMessage": nil, # TODO:
      "active": active,
      "profile": profile,
      "id": chatId,
      "unviewedMessagesCount": 0, # TODO:
      "chatType":  chatType.int,
      "timestamp": 1588940692659  # TODO:
    }
  ])

proc deactivateChat*(chat: Chat) =
  chat.isActive = false
  discard callPrivateRPC("saveChat".prefix, %* [chat.toJsonNode])

proc sortChats(x, y: Chat): int = 
  if x.lastMessage.whisperTimestamp > y.lastMessage.whisperTimestamp: 1
  elif x.lastMessage.whisperTimestamp == y.lastMessage.whisperTimestamp: 0
  else: -1

proc loadChats*(): seq[Chat] =
  result = @[]
  let jsonResponse = parseJson($callPrivateRPC("chats".prefix))
  if jsonResponse["result"].kind != JNull:
    for jsonChat in jsonResponse{"result"}:
      let chat = jsonChat.toChat
      if chat.isActive and chat.chatType != ChatType.Unknown:
        result.add(chat)
  result.sort(sortChats)

proc chatMessages*(chatId: string, cursor: string = ""): (string, seq[Message]) =
  var messages: seq[Message] = @[]
  var cursorVal: JsonNode
  
  if cursor == "":
    cursorVal = newJNull()
  else:
    cursorVal = newJString(cursor)

  let rpcResult = parseJson(callPrivateRPC("chatMessages".prefix, %* [chatId, cursorVal, 20]))["result"]
  if rpcResult["messages"].kind != JNull:
    for jsonMsg in rpcResult["messages"]:
      messages.add(jsonMsg.toMessage)

  return (rpcResult{"cursor"}.getStr, messages)


proc getEmojiReactionsByChatId*(chatId: string, cursor: string = ""): (string, seq[Reaction]) =
  var reactions: seq[Reaction] = @[]
  var cursorVal: JsonNode
  
  if cursor == "":
    cursorVal = newJNull()
  else:
    cursorVal = newJString(cursor)

  let rpcResult = parseJson(callPrivateRPC("emojiReactionsByChatID".prefix, %* [chatId, cursorVal, 20]))["result"]

  if rpcResult != nil and rpcResult.len != 0:
    for jsonMsg in rpcResult:
      reactions.add(jsonMsg.toReaction)

  return (rpcResult{"cursor"}.getStr, reactions)

proc addEmojiReaction*(chatId: string, messageId: string, emojiId: int): seq[Reaction] =
  let rpcResult = parseJson(callPrivateRPC("sendEmojiReaction".prefix, %* [chatId, messageId, emojiId]))["result"]
  
  var reactions: seq[Reaction] = @[]
  if rpcResult != nil and rpcResult["emojiReactions"] != nil and rpcResult["emojiReactions"].len != 0:
    for jsonMsg in rpcResult["emojiReactions"]:
      reactions.add(jsonMsg.toReaction)
  
  result = reactions

proc removeEmojiReaction*(emojiReactionId: string): seq[Reaction] =
  let rpcResult = parseJson(callPrivateRPC("sendEmojiReactionRetraction".prefix, %* [emojiReactionId]))["result"]
 
  var reactions: seq[Reaction] = @[]
  if rpcResult != nil and rpcResult["emojiReactions"] != nil and rpcResult["emojiReactions"].len != 0:
    for jsonMsg in rpcResult["emojiReactions"]:
      reactions.add(jsonMsg.toReaction)
  
  result = reactions

# TODO this probably belongs in another file
proc generateSymKeyFromPassword*(): string =
  result = ($parseJson(callPrivateRPC("waku_generateSymKeyFromPassword", %* [
    # TODO unhardcode this for non-status mailservers
    "status-offline-inbox"
  ]))["result"]).strip(chars = {'"'})

proc sendChatMessage*(chatId: string, msg: string, replyTo: string, contentType: int, communityId: string = ""): string =
  let preferredUsername = getSetting[string](Setting.PreferredUsername, "")
  callPrivateRPC("sendChatMessage".prefix, %* [
    {
      "chatId": chatId,
      "text": msg,
      "responseTo": replyTo,
      "ensName": preferredUsername,
      "sticker": nil,
      "contentType": contentType,
      "communityId": communityId
    }
  ])

proc sendImageMessage*(chatId: string, image: string): string =
  let preferredUsername = getSetting[string](Setting.PreferredUsername, "")
  callPrivateRPC("sendChatMessage".prefix, %* [
    {
      "chatId": chatId,
      "contentType": ContentType.Image.int,
      "imagePath": image,
      "ensName": preferredUsername,
      "text": "Update to latest version to see a nice image here!"
    }
  ])

proc sendStickerMessage*(chatId: string, sticker: Sticker): string =
  let preferredUsername = getSetting[string](Setting.PreferredUsername, "")
  callPrivateRPC("sendChatMessage".prefix, %* [
    {
      "chatId": chatId,
      "text": "Update to latest version to see a nice sticker here!",
      "responseTo": nil,
      "ensName": preferredUsername,
      "sticker": {
        "hash": sticker.hash,
        "pack": sticker.packId
      },
      "contentType": ContentType.Sticker.int
    }
  ])

proc markAllRead*(chatId: string): string =
  callPrivateRPC("markAllRead".prefix, %* [chatId])

proc markMessagesSeen*(chatId: string, messageIds: seq[string]): string =
  callPrivateRPC("markMessagesSeen".prefix, %* [chatId, messageIds])

proc confirmJoiningGroup*(chatId: string): string =
  callPrivateRPC("confirmJoiningGroup".prefix, %* [chatId])

proc leaveGroupChat*(chatId: string): string =
  callPrivateRPC("leaveGroupChat".prefix, %* [nil, chatId, true])

proc clearChatHistory*(chatId: string): string =
  callPrivateRPC("deleteMessagesByChatID".prefix, %* [chatId])

proc renameGroup*(chatId: string, newName: string): string =
  callPrivateRPC("changeGroupChatName".prefix, %* [nil, chatId, newName])

proc createGroup*(groupName: string, pubKeys: seq[string]): string =
  callPrivateRPC("createGroupChatWithMembers".prefix, %* [nil, groupName, pubKeys])

proc addGroupMembers*(chatId: string, pubKeys: seq[string]): string =
  callPrivateRPC("addMembersToGroupChat".prefix, %* [nil, chatId, pubKeys])

proc kickGroupMember*(chatId: string, pubKey: string): string =
  callPrivateRPC("removeMemberFromGroupChat".prefix, %* [nil, chatId, pubKey])

proc makeAdmin*(chatId: string, pubKey: string): string =
  callPrivateRPC("addAdminsToGroupChat".prefix, %* [nil, chatId, [pubKey]])

proc updateOutgoingMessageStatus*(messageId: string, status: string): string =
  result = callPrivateRPC("updateMessageOutgoingStatus".prefix, %* [messageId, status])
  # TODO: handle errors

proc reSendChatMessage*(messageId: string): string =
  result = callPrivateRPC("reSendChatMessage".prefix, %*[messageId])

proc muteChat*(chatId: string): string =
  result = callPrivateRPC("muteChat".prefix, %*[chatId])

proc unmuteChat*(chatId: string): string =
  result = callPrivateRPC("unmuteChat".prefix, %*[chatId])

proc getLinkPreviewData*(link: string): JsonNode =
  let
    responseStr = callPrivateRPC("getLinkPreviewData".prefix, %*[link])
    response = Json.decode(responseStr, RpcResponseTyped[JsonNode], allowUnknownFields = false)

  if not response.error.isNil:
    raise newException(RpcException, fmt"""Error getting link preview data for '{link}': {response.error.message}""")

  response.result


proc getAllComunities*(): seq[Community] =
  var communities: seq[Community] = @[]
  let rpcResult = callPrivateRPC("communities".prefix).parseJSON()
  debug "LIST", rpcResult
  if rpcResult{"result"}.kind != JNull:
    for jsonCommunity in rpcResult["result"]:
      var community = jsonCommunity.toCommunity()

      communities.add(community)
  return communities

proc getJoinedComunities*(): seq[Community] =
  var communities: seq[Community] = @[]
  let rpcResult = callPrivateRPC("joinedCommunities".prefix).parseJSON()
  debug "LIST", rpcResult
  if rpcResult{"result"}.kind != JNull:
    for jsonCommunity in rpcResult["result"]:
      var community = jsonCommunity.toCommunity()

      communities.add(community)
  return communities

proc createCommunity*(name: string, description: string, color: string, image: string, access: int): Community =
  let rpcResult = callPrivateRPC("createCommunity".prefix, %*[{
      "permissions": {
        "access": access
      },
      "identity": {
        "display_name": name,
        "description": description#,
        # "color": color#,
        # TODO add images once it is supported by Status-Go
        # "images": [
        #   {
        #     "payload": image,
        #     # TODO get that from an enum
        #     "image_type": 1 # 1 is a raw payload
        #   }
        # ]
      }
    }]).parseJSON()
  debug "RESULT", rpcResult

  if rpcResult{"result"}.kind != JNull:
    result = rpcResult["result"]["communities"][0].toCommunity()

proc createCommunityChannel*(communityId: string, name: string, description: string): Chat =
  let rpcResult = callPrivateRPC("createCommunityChat".prefix, %*[
    communityId,
    {
      "permissions": {
        "access": 1 # TODO get this from user selected privacy setting
      },
      "identity": {
        "display_name": name,
        "description": description#,
        # "color": color#,
        # TODO add images once it is supported by Status-Go
        # "images": [
        #   {
        #     "payload": image,
        #     # TODO get that from an enum
        #     "image_type": 1 # 1 is a raw payload
        #   }
        # ]
      }
    }]).parseJSON()
  debug "RESULT", rpcResult

  if rpcResult{"result"}.kind != JNull:
    result = rpcResult["result"]["chats"][0].toChat()


#{\"jsonrpc\":\"2.0\",\"id\":0,\"result\":{\"chats\":[{\"id\":\"0x03537a54bd6f697f282ae848452f25ce656026cd8d0b3d3489178c76d3bf9ddf20cbf03afb-89ab-444e-96e9-e23b6c1266c0\",\"name\":\"general\",\"color\":\"#887af9\",\"active\":true,\"chatType\":6,\"timestamp\":1606424570375,\"lastClockValue\":0,\"deletedAtClockValue\":0,\"unviewedMessagesCount\":0,\"lastMessage\":null,\"members\":null,\"membershipUpdateEvents\":null,\"identicon\":\"\",\"communityId\":\"0x03537a54bd6f697f282ae848452f25ce656026cd8d0b3d3489178c76d3bf9ddf20\"}],\"communities\":[{\"id\":\"0x03537a54bd6f697f282ae848452f25ce656026cd8d0b3d3489178c76d3bf9ddf20\",\"description\":{\"clock\":2,\"permissions\":{\"access\":1},\"identity\":{\"display_name\":\"Jo2\",\"description\":\"Jo again\"},\"chats\":{\"cbf03afb-89ab-444e-96e9-e23b6c1266c0\":{\"permissions\":{\"access\":1},\"identity\":{\"display_name\":\"general\",\"description\":\"general channel\"}}}},\"admin\":true,\"verified\":false,\"joined\":true}],\"communitiesChanges\":[{\"MembersAdded\":{},\"MembersRemoved\":{},\"ChatsRemoved\":{},\"ChatsAdded\":{\"cbf03afb-89ab-444e-96e9-e23b6c1266c0\":{\"permissions\":{\"access\":1},\"identity\":{\"display_name\":\"general\",\"description\":\"general channel\"}}},\"ChatsModified\":{}}],\"filters\":[{\"chatId\":\"0x03537a54bd6f697f282ae848452f25ce656026cd8d0b3d3489178c76d3bf9ddf20cbf03afb-89ab-444e-96e9-e23b6c1266c0\",\"filterId\":\"eb220a77bde14d967462529d0ec7c1fa09a0ece4efebefb388ea6e0ecf9a1950\",\"symKeyId\":\"0f08b999ab6571429f79c4762bd922f2b7db38c80ba99cd4a5ac15ef75357d0e\",\"oneToOne\":false,\"identity\":\"\",\"topic\":\"0x46a1c2be\",\"discovery\":false,\"negotiated\":false,\"listen\":true}]}}

  # if rpcResult{"result"}.kind != JNull:
  #   result = rpcResult["result"]["communities"][0].toCommunity()

proc joinCommunity*(communityId: string) =
  let res = callPrivateRPC("joinCommunity".prefix, %*[communityId])#.parseJSON()["result"]
  debug "RESULT", res

proc leaveCommunity*(communityId: string) =
  let res = callPrivateRPC("leaveCommunity".prefix, %*[communityId])#.parseJSON()["result"]
  debug "RESULT", res

proc inviteUserToCommunity*(communityId: string, pubKey: string) =
  let res = callPrivateRPC("inviteUserToCommunity".prefix, %*[communityId, pubKey])#.parseJSON()["result"]
  debug "RESULT", res

proc exportCommunity*(communityId: string):string  =
  result = callPrivateRPC("exportCommunity".prefix, %*[communityId]).parseJson()["result"].getStr

proc importCommunity*(communityKey: string) =
  let res = callPrivateRPC("importCommunity".prefix, %*[communityKey])
  debug "RESULT", res