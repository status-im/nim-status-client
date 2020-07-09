import eventemitter, json, sequtils
import libstatus/contacts as status_contacts
import profile/profile

type
  ContactModel* = ref object
    events*: EventEmitter

type 
  ContactUpdateArgs* = ref object of Args
    contacts*: seq[Profile]

proc newContactModel*(events: EventEmitter): ContactModel =
    result = ContactModel()
    result.events = events

proc getContactByID*(self: ContactModel, id: string): Profile =
  let response = status_contacts.getContactByID(id)
  # TODO: change to options
  let responseResult = parseJSON($response)["result"]
  if responseResult == nil or responseResult.kind == JNull:
    result = nil
  else:
    result = toProfileModel(parseJSON($response)["result"])

proc blockContact*(self: ContactModel, id: string): string =
  var contact = self.getContactByID(id)
  contact.systemTags.add(":contact/blocked")
  status_contacts.blockContact(contact)

proc getContacts*(self: ContactModel): seq[Profile] =
  result = map(status_contacts.getContacts().getElems(), proc(x: JsonNode): Profile = x.toProfileModel())
  self.events.emit("contactUpdate", ContactUpdateArgs(contacts: result))

proc addContact*(self: ContactModel, id: string): string =
  let contact = self.getContactByID(id)
  contact.systemTags.add(":contact/added")
  result = status_contacts.saveContact(contact.id, contact.ensVerified, contact.ensName, contact.ensVerifiedAt, contact.ensVerificationRetries, contact.alias, contact.identicon, contact.systemTags)
  self.events.emit("contactAdded", Args())

proc removeContact*(self: ContactModel, id: string) =
  let contact = self.getContactByID(id)
  contact.systemTags.delete(contact.systemTags.find(":contact/added"))
  discard status_contacts.saveContact(contact.id, contact.ensVerified, contact.ensName, contact.ensVerifiedAt, contact.ensVerificationRetries, contact.alias, contact.identicon, contact.systemTags)
  self.events.emit("contactRemoved", Args())

proc isAdded*(self: ContactModel, id: string): bool =
  var contact = self.getContactByID(id)
  if contact.isNil: return false
  contact.systemTags.contains(":contact/added")
