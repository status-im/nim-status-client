import NimQml, std/wrapnils, json, tables
import ../../../status/[chat/chat, status]
import channels_list
import ../../../eventemitter
import community_members_list
import category_list, category_item
import community_membership_request_list

QtObject:
  type CommunityItemView* = ref object of QObject
    communityItem*: Community
    communityMembershipRequestList*: CommunityMembershipRequestList
    chats*: ChannelsList
    categories*: CategoryList
    members*: CommunityMembersView
    status*: Status
    active*: bool
    categoryItemViews: Table[string, CategoryItemView]

  proc setup(self: CommunityItemView) =
    self.QObject.setup

  proc delete*(self: CommunityItemView) =
    if not self.chats.isNil: self.chats.delete
    if not self.categories.isNil: self.categories.delete
    self.QObject.delete

  proc newCommunityItemView*(status: Status): CommunityItemView =
    new(result, delete)
    result = CommunityItemView()
    result.status = status
    result.active = false
    result.chats = newChannelsList(status)
    result.categories = newCategoryList(status)
    result.communityMembershipRequestList = newCommunityMembershipRequestList()
    result.members = newCommunityMembersView(status)
    result.setup

  proc nbMembersChanged*(self: CommunityItemView) {.signal.}

  proc setCommunityItem*(self: CommunityItemView, communityItem: Community) =
    self.communityItem = communityItem
    self.chats.setChats(communityItem.chats)
    self.categories.setCategories(communityItem.categories)
    self.members.setMembers(communityItem.members)
    self.nbMembersChanged()
    if communityItem.membershipRequests.len > 0:
      self.communityMembershipRequestList.setNewData(communityItem.membershipRequests)

  proc activeChanged*(self: CommunityItemView) {.signal.}

  proc setActive*(self: CommunityItemView, value: bool) {.slot.} =
    if (self.active == value):
      return
    self.active = value
    self.status.events.emit("communityActiveChanged", CommunityActiveChangedArgs(active: value))
    self.activeChanged()

  proc removeMember*(self: CommunityItemView, pubKey: string) =
    self.members.removeMember(pubKey)
    self.nbMembersChanged()

  proc active*(self: CommunityItemView): bool {.slot.} = result = ?.self.active
  
  QtProperty[bool] active:
    read = active
    write = setActive
    notify = activeChanged

  proc id*(self: CommunityItemView): string {.slot.} = result = ?.self.communityItem.id
  
  QtProperty[string] id:
    read = id

  proc name*(self: CommunityItemView): string {.slot.} = result = ?.self.communityItem.name
  
  QtProperty[string] name:
    read = name

  proc description*(self: CommunityItemView): string {.slot.} = result = ?.self.communityItem.description
  
  QtProperty[string] description:
    read = description

  proc access*(self: CommunityItemView): int {.slot.} = result = ?.self.communityItem.access
  
  QtProperty[int] access:
    read = access

  proc admin*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.admin
  
  QtProperty[bool] admin:
    read = admin

  proc joined*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.joined
  
  QtProperty[bool] joined:
    read = joined

  proc verified*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.verified
  
  QtProperty[bool] verified:
    read = verified

  proc mutedChanged*(self: CommunityItemView) {.signal.}

  proc setMuted*(self: CommunityItemView, muted: bool) {.slot.} =
    self.communityItem.muted = muted
    self.mutedChanged()

  proc muted*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.muted
  
  QtProperty[bool] muted:
    read = muted
    notify = mutedChanged

  proc ensOnly*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.ensOnly
  
  QtProperty[bool] ensOnly:
    read = ensOnly

  proc canRequestAccess*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.canRequestAccess
  
  QtProperty[bool] canRequestAccess:
    read = canRequestAccess

  proc canManageUsers*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.canManageUsers
  
  QtProperty[bool] canManageUsers:
    read = canManageUsers

  proc canJoin*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.canJoin
  
  QtProperty[bool] canJoin:
    read = canJoin

  proc isMember*(self: CommunityItemView): bool {.slot.} = result = ?.self.communityItem.isMember
  
  QtProperty[bool] isMember:
    read = isMember

  proc nbMembers*(self: CommunityItemView): int {.slot.} = result = ?.self.members.members.len
  
  QtProperty[int] nbMembers:
    read = nbMembers
    notify = nbMembersChanged

  proc communityColor*(self: CommunityItemView): string {.slot.} = result = ?.self.communityItem.communityColor

  QtProperty[string] communityColor:
    read = communityColor

  proc chatsChanged*(self: CommunityItemView) {.signal.}

  proc getChats*(self: CommunityItemView): QVariant {.slot.} =
    result = newQVariant(self.chats)

  proc getCategories*(self: CommunityItemView): QVariant {.slot.} =
    result = newQVariant(self.categories)

  proc changeChats*(self: CommunityItemView, chats: seq[Chat]) =
    self.communityItem.chats = chats
    self.chats.setChats(chats)
    self.chatsChanged()

  proc addChatItemToList*(self: CommunityItemView, chat: Chat) =
    self.communityItem.chats.add(chat)
    discard self.chats.addChatItemToList(chat)
    self.chatsChanged()
  
  proc updateChatItemInList*(self: CommunityItemView, chat: Chat) =
    self.chats.updateChat(chat)
    self.chatsChanged()

  proc addCategoryToList*(self: CommunityItemView, category: CommunityCategory) =
    self.communityItem.categories.add(category)
    discard self.categories.addCategoryToList(category)
    self.chatsChanged()

  proc removeCategoryFromList*(self: CommunityItemView, categoryId: string) =
    discard self.categories.removeCategoryFromList(categoryId)
    let idx = self.communityItem.categories.findIndexById(categoryId)
    self.chatsChanged()
    if idx == -1: return
    self.communityItem.categories.delete(idx)

  QtProperty[QVariant] chats:
    read = getChats
    notify = chatsChanged

  QtProperty[QVariant] categories:
    read = getCategories
    notify = chatsChanged

  proc getMembers*(self: CommunityItemView): QVariant {.slot.} =
    result = newQVariant(self.members)

  proc triggerMemberUpdate*(self: CommunityItemView) =
    self.members.triggerUpdate()

  proc memberLastSeen*(self: CommunityItemView, pubKey: string): string {.slot.} =
    if self.communityItem.memberStatus.hasKey(pubKey):
      result = $self.communityItem.memberStatus[pubKey].clock
    else:
      result = "0"

  proc memberStatus*(self: CommunityItemView, pubKey: string): int {.slot.} =
    if self.communityItem.memberStatus.hasKey(pubKey):
      result = self.communityItem.memberStatus[pubKey].statusType.int

  proc hasMember*(self: CommunityItemView, pubKey: string): bool {.slot.} =
    result = self.members.members.contains(pubKey)

  QtProperty[QVariant] members:
    read = getMembers

  proc getChatIdsByCategory*(self: CommunityItemView, categoryId: string): string {.slot.} =
    var res:seq[string] = @[]
    for chat in self.communityItem.chats:
      if chat.categoryId == categoryId:
        res.add(chat.id)
    return $(%*res)

  proc getCommunityMembershipRequest*(self: CommunityItemView): QVariant {.slot.} =
    result = newQVariant(self.communityMembershipRequestList)

  QtProperty[QVariant] communityMembershipRequests:
    read = getCommunityMembershipRequest

  proc thumbnailImage*(self: CommunityItemView): string {.slot.} =
    if (self.communityItem.communityImage.isNil):
        return ""
    result = self.communityItem.communityImage.thumbnail

  QtProperty[string] thumbnailImage:
    read = thumbnailImage

  proc largeImage*(self: CommunityItemView): string {.slot.} =
    if (self.communityItem.communityImage.isNil):
        return ""
    result = self.communityItem.communityImage.large

  QtProperty[string] largeImage:
    read = largeImage

  proc getCommunityCategoryItemById*(self: CommunityItemView, id: string): QObject {.slot.} =
    if self.categoryItemViews.hasKey(id): return self.categoryItemViews[id]
    let category = self.categories.getCategoryById(id)
    let categoryItemView = newCategoryItemView()
    categoryItemView.setCategoryItem(category)
    self.categoryItemViews[id] = categoryItemView
    return categoryItemView
