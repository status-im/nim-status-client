import # std libs
  NimQml, json, strutils, tables

import # vendor libs
  chronicles, json_serialization

import # status-desktop libs
  ../../../status/chat/chat, ../../../status/status, ../../../status/accounts

type
  CommunityRoles {.pure.} = enum
    Id = UserRole + 1,
    Name = UserRole + 2
    Description = UserRole + 3
    Access = UserRole + 4
    Admin = UserRole + 5
    Joined = UserRole + 6
    Verified = UserRole + 7
    NumMembers = UserRole + 8
    ThumbnailImage = UserRole + 9
    LargeImage = UserRole + 10
    EnsOnly = UserRole + 11
    CanRequestAccess = UserRole + 12
    CanManageUsers = UserRole + 13
    CanJoin = UserRole + 14
    IsMember = UserRole + 15
    UnviewedMessagesCount = UserRole + 16
    CommunityColor = UserRole + 17
    Muted = UserRole + 18

QtObject:
  type
    CommunityList* = ref object of QAbstractListModel
      communities*: seq[Community]
      status: Status
      fetched*: bool

  proc setup(self: CommunityList) = self.QAbstractListModel.setup

  proc delete(self: CommunityList) = 
    self.communities = @[]
    self.QAbstractListModel.delete

  proc newCommunityList*(status: Status): CommunityList =
    new(result, delete)
    result.communities = @[]
    result.status = status
    result.setup()

  method rowCount*(self: CommunityList, index: QModelIndex = nil): int = self.communities.len

  proc getCommunityIndex(self: CommunityList, communityId: string): int {.slot.} =
    var i = 0
    for community in self.communities:
      if (community.id == communityId):
        return i
      i = i + 1
    return -1

  proc rowData(self: CommunityList, index: int, column: string): string {.slot.} =
    if (index > self.communities.len - 1):
      return
    let community = self.communities[index]
    case column:
      of "name": result = community.name
      of "description": result = community.description
      of "id": result = community.id
      of "access": result = $community.access
      of "admin": result = $community.admin
      of "verified": result = $community.verified
      of "joined": result = $community.joined
      of "ensOnly": result = $community.ensOnly
      of "canRequestAccess": result = $community.canRequestAccess
      of "canJoin": result = $community.canJoin
      of "isMember": result = $community.isMember
      of "nbMembers": result = $community.members.len
      of "unviewedMessagesCount": result = $community.unviewedMessagesCount
      of "thumbnailImage":
        if (not community.communityImage.isNil):
          result = community.communityImage.thumbnail
        else:
          result = ""
      of "largeImage":
        if (not community.communityImage.isNil):
          result = community.communityImage.large
        else:
          result = ""
      of "communityColor": result = community.communityColor

  method data(self: CommunityList, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.communities.len:
      return

    let communityItem = self.communities[index.row]
    let communityItemRole = role.CommunityRoles
    case communityItemRole:
      of CommunityRoles.Name: result = newQVariant(communityItem.name)
      of CommunityRoles.Description: result = newQVariant(communityItem.description)
      of CommunityRoles.Id: result = newQVariant(communityItem.id)
      of CommunityRoles.Access: result = newQVariant(communityItem.access.int)
      of CommunityRoles.Admin: result = newQVariant(communityItem.admin.bool)
      of CommunityRoles.Joined: result = newQVariant(communityItem.joined.bool)
      of CommunityRoles.Verified: result = newQVariant(communityItem.verified.bool)
      of CommunityRoles.EnsOnly: result = newQVariant(communityItem.ensOnly.bool)
      of CommunityRoles.CanRequestAccess: result = newQVariant(communityItem.canRequestAccess.bool)
      of CommunityRoles.CanManageUsers: result = newQVariant(communityItem.canManageUsers.bool)
      of CommunityRoles.CanJoin: result = newQVariant(communityItem.canJoin.bool)
      of CommunityRoles.Muted: result = newQVariant(communityItem.muted.bool)
      of CommunityRoles.IsMember: result = newQVariant(communityItem.isMember.bool)
      of CommunityRoles.NumMembers: result = newQVariant(communityItem.members.len)
      of CommunityRoles.UnviewedMessagesCount: result = newQVariant(communityItem.unviewedMessagesCount)
      of CommunityRoles.ThumbnailImage:
        if (not communityItem.communityImage.isNil):
          result = newQVariant(communityItem.communityImage.thumbnail)
        else:
          result = newQVariant("")
      of CommunityRoles.LargeImage:
        if (not communityItem.communityImage.isNil):
          result = newQVariant(communityItem.communityImage.large)
        else:
          result = newQVariant("")
      of CommunityRoles.CommunityColor: result = newQVariant(communityItem.communityColor)
  
  proc getCommunityByIdJson(self: CommunityList, communityId: string): string {.slot.} =
    for community in self.communities:
      if (community.id == communityId):
        result = Json.encode(community)

  method roleNames(self: CommunityList): Table[int, string] =
    {
      CommunityRoles.Name.int:"name",
      CommunityRoles.Description.int:"description",
      CommunityRoles.Id.int: "id",
      CommunityRoles.Access.int: "access",
      CommunityRoles.Admin.int: "admin",
      CommunityRoles.Verified.int: "verified",
      CommunityRoles.Joined.int: "joined",
      CommunityRoles.EnsOnly.int: "ensOnly",
      CommunityRoles.CanRequestAccess.int: "canRequestAccess",
      CommunityRoles.CanManageUsers.int: "canManageUsers",
      CommunityRoles.CanJoin.int: "canJoin",
      CommunityRoles.IsMember.int: "isMember",
      CommunityRoles.Muted.int: "muted",
      CommunityRoles.NumMembers.int: "nbMembers",
      CommunityRoles.UnviewedMessagesCount.int: "unviewedMessagesCount",
      CommunityRoles.ThumbnailImage.int:"thumbnailImage",
      CommunityRoles.LargeImage.int:"largeImage",
      CommunityRoles.CommunityColor.int:"communityColor"
    }.toTable

  proc setNewData*(self: CommunityList, communityList: seq[Community]) =
    self.beginResetModel()
    self.communities = communityList
    self.endResetModel()

  proc addCommunityItemToList*(self: CommunityList, community: Community) =
    self.beginInsertRows(newQModelIndex(), self.communities.len, self.communities.len)
    self.communities.add(community)
    self.endInsertRows()

  proc removeCommunityItemFromList*(self: CommunityList, id: string) =
    let idx = self.communities.findIndexById(id)
    self.beginRemoveRows(newQModelIndex(), idx, idx)
    self.communities.delete(idx)
    self.endRemoveRows()

  proc getCommunityById*(self: CommunityList, communityId: string): Community =
    for community in self.communities:
      if community.id == communityId:
        return community

  proc updateMemberVisibility*(self: CommunityList, statusUpdate: StatusUpdate) =
    for community in self.communities.mitems:
      if not community.members.contains(statusUpdate.publicKey): continue
      if community.memberStatus.haskey(statusUpdate.publicKey):
        if statusUpdate.clock > community.memberStatus[statusUpdate.publicKey].clock:
          community.memberStatus[statusUpdate.publicKey] = statusUpdate
      else:
        community.memberStatus[statusUpdate.publicKey] = statusUpdate
      break
    
  proc addChannelToCommunity*(self: CommunityList, communityId: string, chat: Chat) =
    var community = self.getCommunityById(communityId)
    community.chats.add(chat)

    let index = self.communities.findIndexById(communityId)
    self.communities[index] = community
  
  proc replaceChannelInCommunity*(self: CommunityList, communityId: string, channel: Chat) =
    var community = self.getCommunityById(communityId)
    if community.id != "":
      let channelIdx = community.chats.findIndexById(channel.id)
      if channelIdx > -1:
        community.chats[channelIdx] = channel

  proc addCategoryToCommunity*(self: CommunityList, communityId: string, category: CommunityCategory) =
    var community = self.getCommunityById(communityId)
    community.categories.add(category)

    let index = self.communities.findIndexById(communityId)
    self.communities[index] = community

  proc replaceCommunity*(self: CommunityList, community: var Community) =
    let index = self.communities.findIndexById(community.id)
    if (index == -1):
      return
    let topLeft = self.createIndex(index, index, nil)
    let bottomRight = self.createIndex(index, index, nil)
    var oldCommunity = self.communities[index]
    community.memberStatus = oldCommunity.memberStatus
    self.communities[index] = community
    self.dataChanged(topLeft, bottomRight, @[CommunityRoles.Name.int, CommunityRoles.Description.int, CommunityRoles.UnviewedMessagesCount.int, CommunityRoles.ThumbnailImage.int])

  proc removeCategoryFromCommunity*(self: CommunityList, communityId: string, categoryId:string) =
    var community = self.getCommunityById(communityId)
    let idx = community.categories.findIndexById(categoryId)
    if idx == -1: return
    community.categories.delete(idx)
    let index = self.communities.findIndexById(communityId)
    self.communities[index] = community

  proc clearUnreadMessages*(self: CommunityList, communityId: string, clearFromChannels : bool) =
    let idx = self.communities.findIndexById(communityId)
    if (idx == -1): 
      return

    if (clearFromChannels):
      # Clear unread messages for each channel in community. 
      for c in self.communities[idx].chats:
        c.unviewedMessagesCount = 0

    let index = self.createIndex(idx, 0, nil)
    self.communities[idx].unviewedMessagesCount = 0

    self.dataChanged(index, index, @[CommunityRoles.UnviewedMessagesCount.int])
  
  proc clearAllMentions*(self: CommunityList, communityId: string, clearFromChannels : bool) =
    let idx = self.communities.findIndexById(communityId)
    if (idx == -1): 
      return

    if (clearFromChannels):
      # Clear mentions for each chat in community. No need to emit dataChanged
      # as mentins are not exposed to qml using roles from this model.
      for c in self.communities[idx].chats:
        c.mentionsCount = 0

    # If we decide in one moment to expose mention role we should do that here.

  proc decrementMentions*(self: CommunityList, communityId: string, channelId : string) =
    let comIndex = self.communities.findIndexById(communityId)
    if (comIndex == -1): 
      return

    let chatIndex = self.communities[comIndex].chats.findIndexById(channelId)
    if (chatIndex == -1): 
      return

    self.communities[comIndex].chats[chatIndex].mentionsCount.dec

  proc incrementMentions*(self: CommunityList, channelId : string) =
    for c in self.communities:
      let chatIndex = c.chats.findIndexById(channelId)
      if (chatIndex != -1): 
        c.chats[chatIndex].mentionsCount.inc