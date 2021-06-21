import json, times, strutils, sequtils, chronicles, json_serialization, algorithm, strformat, sugar
import core, ../utils
import ../chat/[chat, message]
import ../signals/messages
import ../types
import ./settings as status_settings

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

proc saveChat*(chatId: string, chatType: ChatType, active: bool = true, color: string = "#000000", ensName: string = "", profile: string = "", joined: int64 = 0) =
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
      "timestamp": 1588940692659,  # TODO:
      "joined": joined
    }
  ])

proc createPublicChat*(chatId: string):string =
  callPrivateRPC("createPublicChat".prefix, %* [{"ID": chatId}])

proc createOneToOneChat*(chatId: string):string =
  callPrivateRPC("createOneToOneChat".prefix, %* [{"ID": chatId}])

proc deactivateChat*(chat: Chat):string =
  chat.isActive = false
  callPrivateRPC("deactivateChat".prefix, %* [{ "ID": chat.id }])

proc createProfileChat*(pubKey: string):string =
  callPrivateRPC("createProfileChat".prefix, %* [{ "ID": pubKey }])

proc sortChats(x, y: Chat): int =
  var t1 = x.lastMessage.whisperTimestamp
  var t2 = y.lastMessage.whisperTimestamp

  if t1 <= $x.joined:
    t1 = $x.joined
  if t2 <= $y.joined:
    t2 = $y.joined

  if t1 > t2: 1
  elif t1 == t2: 0
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

proc parseChatMessagesResponse*(rpcResult: JsonNode): (string, seq[Message]) =
  var messages: seq[Message] = @[]
  let messagesObj = rpcResult{"messages"}
  if(messagesObj != nil and messagesObj.kind != JNull):
    let pk = status_settings.getSetting[string](Setting.PublicKey, "0x0")
    for jsonMsg in messagesObj:
      messages.add(jsonMsg.toMessage(pk))
  return (rpcResult{"cursor"}.getStr, messages)

proc parseActivityCenterNotifications*(rpcResult: JsonNode): (string, seq[ActivityCenterNotification]) =
  let pk = status_settings.getSetting[string](Setting.PublicKey, "0x0")
  var notifs: seq[ActivityCenterNotification] = @[]
  var msg: Message
  if rpcResult{"notifications"}.kind != JNull:
    for jsonMsg in rpcResult["notifications"]:
      notifs.add(jsonMsg.toActivityCenterNotification(pk))
  return (rpcResult{"cursor"}.getStr, notifs)

proc rpcChatMessages*(chatId: string, cursorVal: JsonNode, limit: int, success: var bool): string =
  success = true
  try:
    result = callPrivateRPC("chatMessages".prefix, %* [chatId, cursorVal, limit])
  except RpcException as e:
    success = false
    result = e.msg

proc chatMessages*(chatId: string, cursor: string = ""): (string, seq[Message]) =
  var cursorVal: JsonNode

  if cursor == "":
    cursorVal = newJNull()
  else:
    cursorVal = newJString(cursor)

  var success: bool
  let callResult = rpcChatMessages(chatId, cursorVal, 20, success)
  if success:
    result = parseChatMessagesResponse(callResult.parseJson()["result"])

proc parseReactionsResponse*(chatId: string, rpcResult: JsonNode): (string, seq[Reaction]) =
  var reactions: seq[Reaction] = @[]
  if rpcResult != nil and rpcResult.kind != JNull and rpcResult.len != 0:
    for jsonMsg in rpcResult:
      reactions.add(jsonMsg.toReaction)
  return (rpcResult{"cursor"}.getStr, reactions)

proc rpcReactions*(chatId: string, cursorVal: JsonNode, limit: int, success: var bool): string =
  success = true
  try:
    result = callPrivateRPC("emojiReactionsByChatID".prefix, %* [chatId, cursorVal, limit])
  except RpcException as e:
    success = false
    result = e.msg

proc getEmojiReactionsByChatId*(chatId: string, cursor: string = ""): (string, seq[Reaction]) =
  var cursorVal: JsonNode
  
  if cursor == "":
    cursorVal = newJNull()
  else:
    cursorVal = newJString(cursor)

  var success: bool
  let rpcResult = rpcReactions(chatId, cursorVal, 20, success)
  if success:
    result = parseReactionsResponse(chatId, rpcResult.parseJson()["result"])

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

proc sendImageMessages*(chatId: string, images: var seq[string]): string =
  let
    preferredUsername = getSetting[string](Setting.PreferredUsername, "")
  let imagesJson = %* images.map(image => %*
      {
        "chatId": chatId,
        "contentType": ContentType.Image.int,
        "imagePath": image,
        "ensName": preferredUsername,
        "text": "Update to latest version to see a nice image here!"
      }
    )
  callPrivateRPC("sendChatMessages".prefix, %* [imagesJson])

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

proc getLinkPreviewData*(link: string, success: var bool): JsonNode =
  let
    responseStr = callPrivateRPC("getLinkPreviewData".prefix, %*[link])
    response = Json.decode(responseStr, RpcResponseTyped[JsonNode], allowUnknownFields = false)

  if not response.error.isNil:
    success = false
    return %* { "error": fmt"""Error getting link preview data for '{link}': {response.error.message}""" }

  success = true
  response.result

proc getAllComunities*(): seq[Community] =
  var communities: seq[Community] = @[]
  let rpcResult = callPrivateRPC("communities".prefix).parseJSON()
  if rpcResult{"result"}.kind != JNull:
    for jsonCommunity in rpcResult["result"]:
      var community = jsonCommunity.toCommunity()

      communities.add(community)
  return communities

proc getJoinedComunities*(): seq[Community] =
  var communities: seq[Community] = @[]
  let rpcResult = callPrivateRPC("joinedCommunities".prefix).parseJSON()
  if rpcResult{"result"}.kind != JNull:
    for jsonCommunity in rpcResult["result"]:
      var community = jsonCommunity.toCommunity()

      communities.add(community)
  return communities

proc createCommunity*(name: string, description: string, access: int, ensOnly: bool, color: string, imageUrl: string, aX: int, aY: int, bX: int, bY: int): Community =
  let rpcResult = callPrivateRPC("createCommunity".prefix, %*[{
      # TODO this will need to be renamed membership (small m)
      "Membership": access,
      "name": name,
      "description": description,
      "ensOnly": ensOnly,
      "color": color,
      "image": imageUrl,
      "imageAx": aX,
      "imageAy": aY,
      "imageBx": bX,
      "imageBy": bY
    }]).parseJSON()

  if rpcResult{"error"} != nil:
    let error = Json.decode($rpcResult{"error"}, RpcError)
    raise newException(RpcException, "Error editing community channel: " & error.message)

  if rpcResult{"result"} != nil and rpcResult{"result"}.kind != JNull:
    result = rpcResult["result"]["communities"][0].toCommunity()

proc editCommunity*(communityId: string, name: string, description: string, access: int, ensOnly: bool, color: string, imageUrl: string, aX: int, aY: int, bX: int, bY: int): Community =
  let rpcResult = callPrivateRPC("editCommunity".prefix, %*[{
      # TODO this will need to be renamed membership (small m)
      "CommunityID": communityId,
      "Membership": access,
      "name": name,
      "description": description,
      "ensOnly": ensOnly,
      "color": color,
      "image": imageUrl,
      "imageAx": aX,
      "imageAy": aY,
      "imageBx": bX,
      "imageBy": bY
    }]).parseJSON()

  if rpcResult{"error"} != nil:
    let error = Json.decode($rpcResult{"error"}, RpcError)
    raise newException(RpcException, "Error editing community channel: " & error.message)

  if rpcResult{"result"} != nil and rpcResult{"result"}.kind != JNull:
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

  if rpcResult{"error"} != nil:
    let error = Json.decode($rpcResult{"error"}, RpcError)
    raise newException(RpcException, "Error creating community channel: " & error.message)

  if rpcResult{"result"} != nil and rpcResult{"result"}.kind != JNull:
    result = rpcResult["result"]["chats"][0].toChat()

proc editCommunityChannel*(communityId: string, channelId: string, name: string, description: string): Chat =
  let rpcResult = callPrivateRPC("editCommunityChat".prefix, %*[
    communityId,
    channelId.replace(communityId, ""),
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

  if rpcResult{"error"} != nil:
    let error = Json.decode($rpcResult{"error"}, RpcError)
    raise newException(RpcException, "Error editing community channel: " & error.message)

  if rpcResult{"result"} != nil and rpcResult{"result"}.kind != JNull:
    result = rpcResult["result"]["chats"][0].toChat()

proc createCommunityCategory*(communityId: string, name: string, channels: seq[string]): CommunityCategory =
  let rpcResult = callPrivateRPC("createCommunityCategory".prefix, %*[
    {
      "communityId": communityId,
      "categoryName": name,
      "chatIds": channels
    }]).parseJSON()

  if rpcResult.contains("error"):
    raise newException(StatusGoException, rpcResult["error"]["message"].getStr())
  else:
    for k, v in rpcResult["result"]["communityChanges"].getElems()[0]["categoriesAdded"].pairs():
      result.id = v["category_id"].getStr()
      result.name = v["name"].getStr()
      result.position = v{"position"}.getInt()


proc editCommunityCategory*(communityId: string, categoryId: string, name: string, channels: seq[string]) =
  let rpcResult = callPrivateRPC("editCommunityCategory".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId,
      "categoryName": name,
      "chatIds": channels
    }]).parseJSON()
  if rpcResult.contains("error"):
    raise newException(StatusGoException, rpcResult["error"]["message"].getStr())

proc reorderCommunityChat*(communityId: string, categoryId: string, chatId: string, position: int) =
  let rpcResult = callPrivateRPC("reorderCommunityChat".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId,
      "chatId": chatId,
      "position": position
    }]).parseJSON()
  if rpcResult.contains("error"):
    raise newException(StatusGoException, rpcResult["error"]["message"].getStr())

proc deleteCommunityCategory*(communityId: string, categoryId: string) =
  let rpcResult = callPrivateRPC("deleteCommunityCategory".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId
    }]).parseJSON()
  if rpcResult.contains("error"):
    raise newException(StatusGoException, rpcResult["error"]["message"].getStr())

proc requestCommunityInfo*(communityId: string) =
  discard callPrivateRPC("requestCommunityInfoFromMailserver".prefix, %*[communityId])

proc joinCommunity*(communityId: string) =
  discard callPrivateRPC("joinCommunity".prefix, %*[communityId])

proc leaveCommunity*(communityId: string) =
  discard callPrivateRPC("leaveCommunity".prefix, %*[communityId])

proc inviteUsersToCommunity*(communityId: string, pubKeys: seq[string]) =
  discard callPrivateRPC("inviteUsersToCommunity".prefix, %*[{
    "communityId": communityId,
    "users": pubKeys
  }])

proc exportCommunity*(communityId: string):string  =
  result = callPrivateRPC("exportCommunity".prefix, %*[communityId]).parseJson()["result"].getStr

proc importCommunity*(communityKey: string): string =
  return callPrivateRPC("importCommunity".prefix, %*[communityKey])

proc removeUserFromCommunity*(communityId: string, pubKey: string) =
  discard callPrivateRPC("removeUserFromCommunity".prefix, %*[communityId, pubKey])

proc requestToJoinCommunity*(communityId: string, ensName: string): seq[CommunityMembershipRequest] =
  let rpcResult = callPrivateRPC("requestToJoinCommunity".prefix, %*[{
    "communityId": communityId,
    "ensName": ensName
  }]).parseJSON()

  var communityRequests: seq[CommunityMembershipRequest] = @[]

  if rpcResult{"result"}{"requestsToJoinCommunity"}.kind != JNull:
    for jsonCommunityReqest in rpcResult["result"]["requestsToJoinCommunity"]:
      communityRequests.add(jsonCommunityReqest.toCommunityMembershipRequest())

  return communityRequests

proc acceptRequestToJoinCommunity*(requestId: string) =
  discard callPrivateRPC("acceptRequestToJoinCommunity".prefix, %*[{
    "id": requestId
  }])

proc declineRequestToJoinCommunity*(requestId: string) =
  discard callPrivateRPC("declineRequestToJoinCommunity".prefix, %*[{
    "id": requestId
  }])

proc pendingRequestsToJoinForCommunity*(communityId: string): seq[CommunityMembershipRequest] =
  let rpcResult = callPrivateRPC("pendingRequestsToJoinForCommunity".prefix, %*[communityId]).parseJSON()

  var communityRequests: seq[CommunityMembershipRequest] = @[]

  if rpcResult{"result"}.kind != JNull:
    for jsonCommunityReqest in rpcResult["result"]:
      communityRequests.add(jsonCommunityReqest.toCommunityMembershipRequest())

  return communityRequests

proc myPendingRequestsToJoin*(): seq[CommunityMembershipRequest] =
  let rpcResult = callPrivateRPC("myPendingRequestsToJoin".prefix).parseJSON()
  var communityRequests: seq[CommunityMembershipRequest] = @[]

  if rpcResult.hasKey("result") and rpcResult{"result"}.kind != JNull:
    for jsonCommunityReqest in rpcResult["result"]:
      communityRequests.add(jsonCommunityReqest.toCommunityMembershipRequest())

  return communityRequests

proc banUserFromCommunity*(pubKey: string, communityId: string): string =
  return callPrivateRPC("banUserFromCommunity".prefix, %*[{
    "communityId": communityId,
    "user": pubKey
  }])


proc parseChatPinnedMessagesResponse*(rpcResult: JsonNode): (string, seq[Message]) =
  var messages: seq[Message] = @[]
  let messagesObj = rpcResult{"pinnedMessages"}
  if(messagesObj != nil and messagesObj.kind != JNull):
    let pk = status_settings.getSetting[string](Setting.PublicKey, "0x0")
    var msg: Message
    for jsonMsg in messagesObj:
      msg = jsonMsg["message"].toMessage(pk)
      msg.pinnedBy = $jsonMsg{"pinnedBy"}.getStr
      messages.add(msg)
  return (rpcResult{"cursor"}.getStr, messages)

proc rpcPinnedChatMessages*(chatId: string, cursorVal: JsonNode, limit: int, success: var bool): string =
  success = true
  try:
    result = callPrivateRPC("chatPinnedMessages".prefix, %* [chatId, cursorVal, limit])
    debug "chatPinnedMessages", result
  except RpcException as e:
    success = false
    result = e.msg

proc pinnedMessagesByChatID*(chatId: string, cursor: string): (string, seq[Message]) =
  var cursorVal: JsonNode
  
  if cursor == "":
    cursorVal = newJNull()
  else:
    cursorVal = newJString(cursor)

  var success: bool
  let callResult = rpcPinnedChatMessages(chatId, cursorVal, 20, success)
  if success:
    result = parseChatPinnedMessagesResponse(callResult.parseJson()["result"])

proc setPinMessage*(messageId: string, chatId: string, pinned: bool) =
  discard callPrivateRPC("sendPinMessage".prefix, %*[{
    "message_id": messageId,
    "pinned": pinned,
    "chat_id": chatId
  }])

proc rpcActivityCenterNotifications*(cursorVal: JsonNode, limit: int, success: var bool): string =
  success = true
  try:
    result = callPrivateRPC("activityCenterNotifications".prefix, %* [cursorVal, limit])
  except RpcException as e:
    success = false
    result = e.msg

proc activityCenterNotification*(cursor: string = ""): (string, seq[ActivityCenterNotification]) =
  var cursorVal: JsonNode
  
  if cursor == "":
    cursorVal = newJNull()
  else:
    cursorVal = newJString(cursor)

  var success: bool
  let callResult = rpcActivityCenterNotifications(cursorVal, 20, success)
  if success:
    result = parseActivityCenterNotifications(callResult.parseJson()["result"])

proc markAllActivityCenterNotificationsRead*() =
  discard callPrivateRPC("markAllActivityCenterNotificationsRead".prefix, %*[])

proc markActivityCenterNotificationsRead*(ids: seq[string]) =
  let res = callPrivateRPC("markActivityCenterNotificationsRead".prefix, %*[ids])

proc unreadActivityCenterNotificationsCount*(): int =
  let rpcResult = callPrivateRPC("unreadActivityCenterNotificationsCount".prefix, %*[]).parseJson

  if rpcResult{"result"}.kind != JNull:
    return rpcResult["result"].getInt
