import NimQml, json, sequtils, chronicles, strutils, strformat, json
import ../../../status/status
import ../../../status/chat/chat
import ./community_list
import ./community_item
import ./community_membership_request_list
import ./channels_list
import ../../utils/image_utils


logScope:
  topics = "communities-view"

QtObject:
  type CommunitiesView* = ref object of QObject
    status: Status
    activeCommunity*: CommunityItemView
    observedCommunity*: CommunityItemView
    communityList*: CommunityList
    joinedCommunityList*: CommunityList
    myCommunityRequests*: seq[CommunityMembershipRequest]

  proc setup(self: CommunitiesView) =
    self.QObject.setup

  proc delete*(self: CommunitiesView) =
    self.observedCommunity.delete
    self.activeCommunity.delete
    self.communityList.delete
    self.joinedCommunityList.delete
    self.QObject.delete

  proc newCommunitiesView*(status: Status): CommunitiesView =
    new(result, delete)
    result.status = status
    result.activeCommunity = newCommunityItemView(status)
    result.observedCommunity = newCommunityItemView(status)
    result.communityList = newCommunityList(status)
    result.joinedCommunityList = newCommunityList(status)
    result.setup

  proc calculateUnreadMessages*(self: CommunitiesView, community: var Community) =
    var unreadTotal = 0
    for chatItem in community.chats:
      unreadTotal = unreadTotal + chatItem.unviewedMessagesCount
    if unreadTotal != community.unviewedMessagesCount:
      community.unviewedMessagesCount = unreadTotal

  proc updateCommunityChat*(self: CommunitiesView, newChat: Chat) =
    var community = self.joinedCommunityList.getCommunityById(newChat.communityId)
    if (community.id == ""):
      return
    var i = 0
    var found = false
    for chat in community.chats:
      if (chat.id == newChat.id):
        community.chats[i] = newChat
        found = true
      i = i + 1
    if (not found):
      community.chats.add(newChat)
    
    self.calculateUnreadMessages(community)
    self.joinedCommunityList.replaceCommunity(community)
    if (self.activeCommunity.active and self.activeCommunity.communityItem.id == community.id):
      self.activeCommunity.changeChats(community.chats)
      

  proc pendingRequestsToJoinForCommunity*(self: CommunitiesView, communityId: string): seq[CommunityMembershipRequest] =
    result = self.status.chat.pendingRequestsToJoinForCommunity(communityId)

  proc membershipRequestPushed*(self: CommunitiesView, communityName: string, pubKey: string) {.signal.}

  proc addMembershipRequests*(self: CommunitiesView, membershipRequests: seq[CommunityMembershipRequest]) =
    var communityId: string
    var community: Community
    for request in membershipRequests:
      communityId = request.communityId
      community = self.joinedCommunityList.getCommunityById(communityId)
      if (community.id == ""):
        continue
      let alreadyPresentRequestIdx = community.membershipRequests.findIndexById(request.id)
      if (alreadyPresentRequestIdx == -1): 
        community.membershipRequests.add(request)
        self.membershipRequestPushed(community.name, request.publicKey)
      else:
        community.membershipRequests[alreadyPresentRequestIdx] = request
      self.joinedCommunityList.replaceCommunity(community)

      # Add to active community list
      if (communityId == self.activeCommunity.communityItem.id):
        self.activeCommunity.communityMembershipRequestList.addCommunityMembershipRequestItemToList(request)

  proc communitiesChanged*(self: CommunitiesView) {.signal.}

  proc getCommunitiesIfNotFetched*(self: CommunitiesView): CommunityList =
    if (not self.communityList.fetched):
      let communities = self.status.chat.getAllComunities()
      self.communityList.setNewData(communities)
      self.communityList.fetched = true
    return self.communityList

  proc getComunities*(self: CommunitiesView): QVariant {.slot.} =
    return newQVariant(self.getCommunitiesIfNotFetched())

  QtProperty[QVariant] list:
    read = getComunities
    notify = communitiesChanged

  proc joinedCommunitiesChanged*(self: CommunitiesView) {.signal.}
    
  proc getJoinedComunities*(self: CommunitiesView): QVariant {.slot.} =
    if (not self.joinedCommunityList.fetched):
      let communities = self.status.chat.getJoinedComunities()
      self.joinedCommunityList.setNewData(communities)
      self.joinedCommunityList.fetched = true

      # Also fetch requests
      self.myCommunityRequests = self.status.chat.myPendingRequestsToJoin()

    return newQVariant(self.joinedCommunityList)

  QtProperty[QVariant] joinedCommunities:
    read = getJoinedComunities
    notify = joinedCommunitiesChanged

  proc activeCommunityChanged*(self: CommunitiesView) {.signal.}

  proc setActiveCommunity*(self: CommunitiesView, communityId: string) {.slot.} =
    if(communityId == ""): return
    self.addMembershipRequests(self.pendingRequestsToJoinForCommunity(communityId))
    self.activeCommunity.setCommunityItem(self.joinedCommunityList.getCommunityById(communityId))
    self.activeCommunity.setActive(true)
    self.activeCommunityChanged()

  proc getActiveCommunity*(self: CommunitiesView): QVariant {.slot.} =
    newQVariant(self.activeCommunity)

  QtProperty[QVariant] activeCommunity:
    read = getActiveCommunity
    write = setActiveCommunity
    notify = activeCommunityChanged

  proc joinCommunity*(self: CommunitiesView, communityId: string, setActive: bool = true): string {.slot.} =
    result = ""
    try:
      self.status.chat.joinCommunity(communityId)
      self.joinedCommunityList.addCommunityItemToList(self.communityList.getCommunityById(communityId))
      if (setActive):
        self.setActiveCommunity(communityId)
    except Exception as e:
      error "Error joining the community", msg = e.msg
      result = fmt"Error joining the community: {e.msg}"

  proc membershipRequestChanged*(self: CommunitiesView, communityName: string, accepted: bool) {.signal.}

  proc addCommunityToList*(self: CommunitiesView, community: Community) =
    let communityCheck = self.communityList.getCommunityById(community.id)
    if (communityCheck.id == ""):
      self.communityList.addCommunityItemToList(community)
    else:
      self.communityList.replaceCommunity(community)

    if (community.joined == true):
      let joinedCommunityCheck = self.joinedCommunityList.getCommunityById(community.id)
      if (joinedCommunityCheck.id == ""):
        self.joinedCommunityList.addCommunityItemToList(community)
      else:
        self.joinedCommunityList.replaceCommunity(community)
    elif (community.isMember == true):
      discard self.joinCommunity(community.id, false)
      var i = 0
      for communityRequest in self.myCommunityRequests:
        if (communityRequest.communityId == community.id):
          self.membershipRequestChanged(community.name, true)
          self.myCommunityRequests.delete(i, i)
          break
        i = i + 1

  proc isCommunityRequestPending*(self: CommunitiesView, communityId: string): bool {.slot.} =
    for communityRequest in self.myCommunityRequests:
      if (communityRequest.communityId == communityId):
        return true
    return false

  proc createCommunity*(self: CommunitiesView, name: string, description: string, access: int, ensOnly: bool, color: string, imagePath: string, aX: int, aY: int, bX: int, bY: int): string {.slot.} =
    result = ""
    try:
      var image = image_utils.formatImagePath(imagePath)
      let community = self.status.chat.createCommunity(name, description, access, ensOnly, color, image, aX, aY, bX, bY)
     
      if (community.id == ""):
        return "Community was not created. Please try again later"

      self.communityList.addCommunityItemToList(community)
      self.joinedCommunityList.addCommunityItemToList(community)
      self.communitiesChanged()
    except Exception as e:
      error "Error creating the community", msg = e.msg
      result = fmt"Error creating the community: {e.msg}"

  proc createCommunityChannel*(self: CommunitiesView, communityId: string, name: string, description: string): string {.slot.} =
    result = ""
    try:
      let chat = self.status.chat.createCommunityChannel(communityId, name, description)
     
      if (chat.id == ""):
        return "Chat was not created. Please try again later"

      self.joinedCommunityList.addChannelToCommunity(communityId, chat)
      discard self.activeCommunity.chats.addChatItemToList(chat)
    except Exception as e:
      error "Error creating the channel", msg = e.msg
      result = fmt"Error creating the channel: {e.msg}"

  proc observedCommunityChanged*(self: CommunitiesView) {.signal.}

  proc setObservedCommunity*(self: CommunitiesView, communityId: string) {.slot.} =
    if(communityId == ""): return
    var community = self.communityList.getCommunityById(communityId) 
    if (community.id == ""):
      discard self.getCommunitiesIfNotFetched()
      community = self.communityList.getCommunityById(communityId) 
    self.observedCommunity.setCommunityItem(community)
    self.observedCommunityChanged()

  proc getObservedCommunity*(self: CommunitiesView): QVariant {.slot.} =
    newQVariant(self.observedCommunity)

  QtProperty[QVariant] observedCommunity:
    read = getObservedCommunity
    write = setObservedCommunity
    notify = observedCommunityChanged

  proc leaveCommunity*(self: CommunitiesView, communityId: string): string {.slot.} =
    result = ""
    try:
      self.status.chat.leaveCommunity(communityId)
      if (communityId == self.activeCommunity.communityItem.id):
        self.activeCommunity.setActive(false)
      self.joinedCommunityList.removeCommunityItemFromList(communityId)
      var updatedCommunity = self.communityList.getCommunityById(communityId)
      updatedCommunity.joined = false
      self.communityList.replaceCommunity(updatedCommunity)
    except Exception as e:
      error "Error leaving the community", msg = e.msg
      result = fmt"Error leaving the community: {e.msg}"

  proc leaveCurrentCommunity*(self: CommunitiesView): string {.slot.} =
    result = self.leaveCommunity(self.activeCommunity.communityItem.id)

  proc inviteUserToCommunity*(self: CommunitiesView, pubKey: string): string {.slot.} =
    try:
      self.status.chat.inviteUserToCommunity(self.activeCommunity.id(), pubKey)
    except Exception as e:
      error "Error inviting to the community", msg = e.msg
      result = fmt"Error inviting to the community: {e.msg}"

  proc inviteUsersToCommunity*(self: CommunitiesView, pubKeysJSON: string): string {.slot.} =
    try:
      let pubKeysParsed = pubKeysJSON.parseJson
      var pubKeys: seq[string] = @[]
      for pubKey in pubKeysParsed:
        pubKeys.add(pubKey.getStr)

      self.status.chat.inviteUsersToCommunity(self.activeCommunity.id(), pubKeys)
    except Exception as e:
      error "Error inviting to the community", msg = e.msg
      result = fmt"Error inviting to the community: {e.msg}"

  proc exportComumnity*(self: CommunitiesView): string {.slot.} =
    try:
      result = self.status.chat.exportCommunity(self.activeCommunity.communityItem.id)
    except Exception as e:
      error "Error exporting the community", msg = e.msg
      result = fmt"Error exporting the community: {e.msg}"

  proc importCommunity*(self: CommunitiesView, communityKey: string) {.slot.} =
    try:
      self.status.chat.importCommunity(communityKey)
    except Exception as e:
      error "Error importing the community", msg = e.msg

  proc removeUserFromCommunity*(self: CommunitiesView, pubKey: string) {.slot.} =
    try:
      self.status.chat.removeUserFromCommunity(self.activeCommunity.id(), pubKey)
      self.activeCommunity.removeMember(pubKey)
    except Exception as e:
      error "Error removing user from the community", msg = e.msg


  proc requestToJoinCommunity*(self: CommunitiesView, communityId: string, ensName: string) {.slot.} =
    try:
      let requests = self.status.chat.requestToJoinCommunity(communityId, ensName)
      for request in requests:
        self.myCommunityRequests.add(request)
    except Exception as e:
      error "Error requesting to join the community", msg = e.msg

  proc acceptRequestToJoinCommunity*(self: CommunitiesView, requestId: string): string {.slot.} =
    try:
      self.status.chat.acceptRequestToJoinCommunity(requestId)
      self.activeCommunity.communityMembershipRequestList.removeCommunityMembershipRequestItemFromList(requestId)
    except Exception as e:
      error "Error accepting request to join the community", msg = e.msg
      return "Error accepting request to join the community"
    return ""

  proc declineRequestToJoinCommunity*(self: CommunitiesView, requestId: string): string {.slot.} =
    try:
      self.status.chat.declineRequestToJoinCommunity(requestId)
      self.activeCommunity.communityMembershipRequestList.removeCommunityMembershipRequestItemFromList(requestId)
    except Exception as e:
      error "Error declining request to join the community", msg = e.msg
      return "Error declining request to join the community"
    return ""