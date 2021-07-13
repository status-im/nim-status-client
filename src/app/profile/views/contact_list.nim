import NimQml, chronicles
import Tables
import ../../../status/profile/profile
from ../../../status/ens import nil

type
  ContactRoles {.pure.} = enum
    PubKey = UserRole + 1
    Name = UserRole + 2,
    Address = UserRole + 3
    Identicon = UserRole + 4
    IsContact = UserRole + 5
    IsBlocked = UserRole + 6
    Alias = UserRole + 7
    EnsVerified = UserRole + 8
    LocalNickname = UserRole + 9
    ThumbnailImage = UserRole + 10
    LargeImage = UserRole + 11
    RequestReceived = UserRole + 12

QtObject:
  type ContactList* = ref object of QAbstractListModel
    contacts*: seq[Profile]

  proc setup(self: ContactList) = self.QAbstractListModel.setup

  proc delete(self: ContactList) =
    self.contacts = @[]
    self.QAbstractListModel.delete

  proc newContactList*(): ContactList =
    new(result, delete)
    # TODO: (rramos) contacts should be a table[string, Profile] instead, with the key being the public key
    # This is to optimize determining if a contact is part of the contact list or not
    # (including those that do not have a system tag)
    result.contacts = @[]
    result.setup

  method rowCount(self: ContactList, index: QModelIndex = nil): int =
    return self.contacts.len

  proc countChanged*(self: ContactList) {.signal.}

  proc count*(self: ContactList): int {.slot.}  =
    self.contacts.len

  QtProperty[int] count:
    read = count
    notify = countChanged

  proc userName*(self: ContactList, pubKey: string, defaultValue: string = ""): string {.slot.} =
    for contact in self.contacts:
      if(contact.id != pubKey): continue
      return ens.userNameOrAlias(contact)
    return defaultValue

  proc getContactIndexByPubkey(self: ContactList, pubkey: string): int {.slot.} =
    var i = 0
    for contact in self.contacts:
      if (contact.id == pubkey):
        return i
      i = i + 1
    return -1 

  proc rowData(self: ContactList, index: int, column: string): string {.slot.} =
    let contact = self.contacts[index]
    case column:
      of "name": result = ens.userNameOrAlias(contact)
      of "address": result = contact.address
      of "identicon": result = contact.identicon
      of "pubKey": result = contact.id
      of "isContact": result = $contact.isContact()
      of "isBlocked": result = $contact.isBlocked()
      of "alias": result = contact.alias
      of "ensVerified": result = $contact.ensVerified
      of "localNickname": result = $contact.localNickname
      of "thumbnailImage": result = $contact.identityImage.thumbnail
      of "largeImage": result = $contact.identityImage.large
      of "requestReceived": result = $contact.requestReceived()

  method data(self: ContactList, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.contacts.len:
      return
    let contact = self.contacts[index.row]
    case role.ContactRoles:
      of ContactRoles.Name: result = newQVariant(ens.userNameOrAlias(contact))
      of ContactRoles.Address: result = newQVariant(contact.address)
      of ContactRoles.Identicon: result = newQVariant(contact.identicon)
      of ContactRoles.PubKey: result = newQVariant(contact.id)
      of ContactRoles.IsContact: result = newQVariant(contact.isContact())
      of ContactRoles.IsBlocked: result = newQVariant(contact.isBlocked())
      of ContactRoles.Alias: result = newQVariant(contact.alias)
      of ContactRoles.EnsVerified: result = newQVariant(contact.ensVerified)
      of ContactRoles.LocalNickname: result = newQVariant(contact.localNickname)
      of ContactRoles.ThumbnailImage: result = newQVariant(contact.identityImage.thumbnail)
      of ContactRoles.LargeImage: result = newQVariant(contact.identityImage.large)
      of ContactRoles.RequestReceived: result = newQVariant(contact.requestReceived())

  method roleNames(self: ContactList): Table[int, string] =
    {
      ContactRoles.Name.int:"name",
      ContactRoles.Address.int:"address",
      ContactRoles.Identicon.int:"identicon",
      ContactRoles.PubKey.int:"pubKey",
      ContactRoles.IsContact.int:"isContact",
      ContactRoles.IsBlocked.int:"isBlocked",
      ContactRoles.Alias.int:"alias",
      ContactRoles.LocalNickname.int:"localNickname",
      ContactRoles.EnsVerified.int:"ensVerified",
      ContactRoles.ThumbnailImage.int:"thumbnailImage",
      ContactRoles.LargeImage.int:"largeImage",
      ContactRoles.RequestReceived.int:"requestReceived"
    }.toTable

  proc addContactToList*(self: ContactList, contact: Profile) =
    self.beginInsertRows(newQModelIndex(), self.contacts.len, self.contacts.len)
    self.contacts.add(contact)
    self.endInsertRows()
    self.countChanged()

  proc hasAddedContacts(self: ContactList): bool {.slot.} = 
    for c in self.contacts:
      if(c.isContact()): return true
    return false

  proc contactChanged*(self: ContactList, pubkey: string) {.signal.}

  proc updateContact*(self: ContactList, contact: Profile) =
    var found = false
    let topLeft = self.createIndex(0, 0, nil)
    let bottomRight = self.createIndex(self.contacts.len, 0, nil)
    for c in self.contacts:
      if(c.id != contact.id): continue
      found = true
      c.ensName = contact.ensName
      c.ensVerified = contact.ensVerified
      c.identityImage = contact.identityImage
      c.systemTags = contact.systemTags

    if not found:
      self.addContactToList(contact)
    else:
      self.dataChanged(topLeft, bottomRight, @[ContactRoles.Name.int])
    self.contactChanged(contact.id)

  proc setNewData*(self: ContactList, contactList: seq[Profile]) =
    self.beginResetModel()
    self.contacts = contactList
    self.endResetModel()
    self.countChanged()
