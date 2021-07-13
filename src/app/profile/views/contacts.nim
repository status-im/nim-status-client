import NimQml, chronicles, sequtils, sugar, strutils, json
import ../../../status/utils as status_utils
import ../../../status/status
import ../../../status/chat/chat
import contact_list
import ../../../status/profile/profile
import ../../../status/ens as status_ens
import ../../../status/tasks/[qt, task_runner_impl]

logScope:
  topics = "contacts-view"

type
  LookupContactTaskArg = ref object of QObjectTaskArg
    value: string

const lookupContactTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[LookupContactTaskArg](argEncoded)
  var id = arg.value
  if not id.startsWith("0x"):
    id = status_ens.pubkey(id)
  arg.finish(id)

proc lookupContact[T](self: T, slot: string, value: string) =
  let arg = LookupContactTaskArg(
    tptr: cast[ByteAddress](lookupContactTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot,
    value: value
  )
  self.status.tasks.threadpool.start(arg)

QtObject:
  type ContactsView* = ref object of QObject
    status: Status
    contactList*: ContactList
    contactRequests*: ContactList
    addedContacts*: ContactList
    blockedContacts*: ContactList
    contactToAdd*: Profile

  proc setup(self: ContactsView) =
    self.QObject.setup

  proc delete*(self: ContactsView) =
    self.contactList.delete
    self.addedContacts.delete
    self.contactRequests.delete
    self.blockedContacts.delete
    self.QObject.delete

  proc newContactsView*(status: Status): ContactsView =
    new(result, delete)
    result.status = status
    result.contactList = newContactList()
    result.contactRequests = newContactList()
    result.addedContacts = newContactList()
    result.blockedContacts = newContactList()
    result.contactToAdd = Profile(
      username: "",
      alias: "",
      ensName: ""
    )
    result.setup

  proc contactListChanged*(self: ContactsView) {.signal.}
  proc contactRequestAdded*(self: ContactsView, name: string, address: string) {.signal.}

  proc updateContactList*(self: ContactsView, contacts: seq[Profile]) =
    for contact in contacts:
      var requestAlreadyAdded = false
      for existingContact in self.contactList.contacts:
        if existingContact.address == contact.address and existingContact.requestReceived():
          requestAlreadyAdded = true
          break

      self.contactList.updateContact(contact)
      if contact.systemTags.contains(contactAdded):
        self.addedContacts.updateContact(contact)
      if contact.isBlocked():
        self.blockedContacts.updateContact(contact)
      if contact.requestReceived() and not contact.systemTags.contains(contactAdded) and not contact.systemTags.contains(contactBlocked):
        self.contactRequests.updateContact(contact)
      if not requestAlreadyAdded and contact.requestReceived():
        echo "SENDING"
        self.contactRequestAdded(status_ens.userNameOrAlias(contact), contact.address)

      self.contactListChanged()

  proc getContactList(self: ContactsView): QVariant {.slot.} =
    return newQVariant(self.contactList)

  proc setContactList*(self: ContactsView, contactList: seq[Profile]) =
    self.contactList.setNewData(contactList)
    self.addedContacts.setNewData(contactList.filter(c => c.systemTags.contains(contactAdded)))
    self.blockedContacts.setNewData(contactList.filter(c => c.systemTags.contains(contactBlocked)))
    self.contactRequests.setNewData(contactList.filter(c => c.systemTags.contains(contactRequest) and not c.systemTags.contains(contactAdded) and not c.systemTags.contains(contactBlocked)))
    self.contactListChanged()

  QtProperty[QVariant] list:
    read = getContactList
    write = setContactList
    notify = contactListChanged

  proc getAddedContacts(self: ContactsView): QVariant {.slot.} =
    return newQVariant(self.addedContacts)

  QtProperty[QVariant] addedContacts:
    read = getAddedContacts
    notify = contactListChanged

  proc getBlockedContacts(self: ContactsView): QVariant {.slot.} =
    return newQVariant(self.blockedContacts)

  QtProperty[QVariant] blockedContacts:
    read = getBlockedContacts
    notify = contactListChanged

  proc isContactBlocked*(self: ContactsView, pubkey: string): bool {.slot.} =
    for contact in self.blockedContacts.contacts:
      if contact.id == pubkey:
        return true
    return false

  proc getContactRequests(self: ContactsView): QVariant {.slot.} =
    return newQVariant(self.contactRequests)

  QtProperty[QVariant] contactRequests:
    read = getContactRequests
    notify = contactListChanged

  proc contactToAddChanged*(self: ContactsView) {.signal.}

  proc getContactToAddUsername(self: ContactsView): QVariant {.slot.} =
    var username = self.contactToAdd.alias;

    if self.contactToAdd.ensVerified and self.contactToAdd.ensName != "":
      username = self.contactToAdd.ensName

    return newQVariant(username)

  QtProperty[QVariant] contactToAddUsername:
    read = getContactToAddUsername
    notify = contactToAddChanged

  proc getContactToAddPubKey(self: ContactsView): QVariant {.slot.} =
    return newQVariant(self.contactToAdd.address)

  QtProperty[QVariant] contactToAddPubKey:
    read = getContactToAddPubKey
    notify = contactToAddChanged

  proc isAdded*(self: ContactsView, id: string): bool {.slot.} =
    if id == "": return false
    self.status.contacts.isAdded(id)

  proc contactRequestReceived*(self: ContactsView, id: string): bool {.slot.} =
    if id == "": return false
    self.status.contacts.contactRequestReceived(id)

  proc lookupContact*(self: ContactsView, value: string) {.slot.} =
    if value == "":
      return

    self.lookupContact("ensResolved", value)

  proc ensWasResolved*(self: ContactsView, resolvedPubKey: string) {.signal.}

  proc ensResolved(self: ContactsView, id: string) {.slot.} =
    self.ensWasResolved(id)
    if id == "":
      self.contactToAddChanged()
      return

    let contact = self.status.contacts.getContactByID(id)
    
    if contact != nil:
      self.contactToAdd = contact
    else:
      self.contactToAdd = Profile(
        address: id,
        username: "",
        alias: generateAlias(id),
        ensName: "",
        ensVerified: false
      )
    self.contactToAddChanged()

  proc contactChanged(self: ContactsView, publicKey: string, isAdded: bool) {.signal.}

  proc addContact*(self: ContactsView, publicKey: string): string {.slot.} =
    result = self.status.contacts.addContact(publicKey)
    self.status.chat.join(status_utils.getTimelineChatId(publicKey), ChatType.Profile, "", publicKey)
    self.contactChanged(publicKey, true)

  proc rejectContactRequest*(self: ContactsView, publicKey: string) {.slot.} =
    self.status.contacts.rejectContactRequest(publicKey)

  proc rejectContactRequests*(self: ContactsView, publicKeysJSON: string) {.slot.} =
    let publicKeys = publicKeysJSON.parseJson
    for pubkey in publicKeys:
      self.rejectContactRequest(pubkey.getStr)

  proc acceptContactRequests*(self: ContactsView, publicKeysJSON: string) {.slot.} =
    let publicKeys = publicKeysJSON.parseJson
    for pubkey in publicKeys:
      discard self.addContact(pubkey.getStr)

  proc changeContactNickname*(self: ContactsView, publicKey: string, nickname: string) {.slot.} =
    var nicknameToSet = nickname
    if (nicknameToSet == ""):
      nicknameToSet = DELETE_CONTACT
    discard self.status.contacts.setNickName(publicKey, nicknameToSet)

  proc unblockContact*(self: ContactsView, publicKey: string) {.slot.} =
    self.contactListChanged()
    discard self.status.contacts.unblockContact(publicKey)

  proc contactBlocked*(self: ContactsView, publicKey: string) {.signal.}

  proc blockContact*(self: ContactsView, publicKey: string): string {.slot.} =
    self.contactListChanged()
    self.contactBlocked(publicKey)
    return self.status.contacts.blockContact(publicKey)

  proc removeContact*(self: ContactsView, publicKey: string) {.slot.} =
    self.status.contacts.removeContact(publicKey)
    let channelId = status_utils.getTimelineChatId(publicKey)
    if self.status.chat.hasChannel(channelId):
      self.status.chat.leave(channelId)
    self.contactChanged(publicKey, false)
