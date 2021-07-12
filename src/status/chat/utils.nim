proc formatChatUpdate(response: JsonNode): (seq[Chat], seq[Message]) =
  var chats: seq[Chat] = @[]
  var messages: seq[Message] = @[]
  if response["result"]{"messages"} != nil:
    for jsonMsg in response["result"]["messages"]:
      messages.add(jsonMsg.toMessage())
  if response["result"]{"chats"} != nil:
    for jsonChat in response["result"]["chats"]:
      chats.add(jsonChat.toChat)
  result = (chats, messages)

proc processChatUpdate(self: ChatModel, response: JsonNode): (seq[Chat], seq[Message]) =
  var chats: seq[Chat] = @[]
  var messages: seq[Message] = @[]
  if response{"result"}{"messages"} != nil:
    for jsonMsg in response["result"]["messages"]:
      messages.add(jsonMsg.toMessage())
  if response{"result"}{"chats"} != nil:
    for jsonChat in response["result"]["chats"]:
      let chat = jsonChat.toChat
      self.channels[chat.id] = chat
      chats.add(chat) 
  result = (chats, messages)

proc emitUpdate(self: ChatModel, response: string) =
  var (chats, messages) = self.processChatUpdate(parseJson(response))
  self.events.emit("chatUpdate", ChatUpdateArgs(messages: messages, chats: chats, contacts: @[]))

proc removeFiltersByChatId(self: ChatModel, chatId: string, filters: JsonNode)

proc removeChatFilters(self: ChatModel, chatId: string) =
  # TODO: this code should be handled by status-go / stimbus instead of the client
  # Clients should not have to care about filters. For more info about filters:
  # https://github.com/status-im/specs/blob/master/docs/stable/3-whisper-usage.md#keys-management
  let filters = parseJson(status_chat.loadFilters(@[]))["result"]

  case self.channels[chatId].chatType
  of ChatType.Public:
    for filter in filters:
      if filter["chatId"].getStr == chatId:
        status_chat.removeFilters(chatId, filter["filterId"].getStr)
  of ChatType.OneToOne, ChatType.Profile:
    # Check if user does not belong to any active chat group
    var inGroup = false
    for channel in self.channels.values:
      if channel.isActive and channel.id != chatId and channel.chatType == ChatType.PrivateGroupChat:
        inGroup = true
        break
    if not inGroup: self.removeFiltersByChatId(chatId, filters)
  of ChatType.PrivateGroupChat:
    for member in self.channels[chatId].members:
      # Check that any of the members are not in other active group chats, or that you don’t have a one-to-one open.
      var hasConversation = false
      for channel in self.channels.values:
        if (channel.isActive and channel.chatType == ChatType.OneToOne and channel.id == member.id) or
           (channel.isActive and channel.id != chatId and channel.chatType == ChatType.PrivateGroupChat and channel.isMember(member.id)):
          hasConversation = true
          break
      if not hasConversation: self.removeFiltersByChatId(member.id, filters)
  else:
    error "Unknown chat type removed", chatId

proc removeFiltersByChatId(self: ChatModel, chatId: string, filters: JsonNode) =
  var partitionedTopic = ""
  for filter in filters:
    # Contact code filter should be removed
    if filter["identity"].getStr == chatId and filter["chatId"].getStr.endsWith("-contact-code"):
      status_chat.removeFilters(chatId, filter["filterId"].getStr)

    # Remove partitioned topic if no other user in an active group chat or one-to-one is from the 
    # same partitioned topic
    if filter["identity"].getStr == chatId and filter["chatId"].getStr.startsWith("contact-discovery-"):
      partitionedTopic = filter["topic"].getStr
      var samePartitionedTopic = false
      for f in filters.filterIt(it["topic"].getStr == partitionedTopic and it["filterId"].getStr != filter["filterId"].getStr):
        let fIdentity = f["identity"].getStr;
        if self.channels.hasKey(fIdentity) and self.channels[fIdentity].isActive:
          samePartitionedTopic = true
          break
      if not samePartitionedTopic:
        status_chat.removeFilters(chatId, filter["filterId"].getStr)
