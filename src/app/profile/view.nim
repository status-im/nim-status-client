import NimQml, sequtils, strutils, sugar, os, json, chronicles
import views/[mailservers_list, ens_manager, contacts, devices, mailservers, mnemonic, network, fleets, profile_info, device_list, dapp_list, profile_picture, profile_settings, muted_chats]
import chronicles
import ../chat/views/channels_list
import ../../status/profile/profile
import ../../status/profile as status_profile
import ../../status/contacts as status_contacts
import ../../status/status
import ../../status/ens as status_ens
import ../../status/chat/chat
import ../../status/types
import ../../status/constants as accountConstants
import qrcode/qrcode
import ../utils/image_utils

logScope:
  topics = "profile-view"

QtObject:
  type ProfileView* = ref object of QObject
    profile*: ProfileInfoView
    profilePicture*: ProfilePictureView
    profileSettings*: ProfileSettingsView
    mutedChats*: MutedChatsView
    contacts*: ContactsView
    devices*: DevicesView
    mailservers*: MailserversView
    mnemonic*: MnemonicView
    dappList*: DappList
    fleets*: Fleets
    network*: NetworkView
    status*: Status
    changeLanguage*: proc(locale: string)
    ens*: EnsManager

  proc setup(self: ProfileView) =
    self.QObject.setup

  proc delete*(self: ProfileView) =
    if not self.contacts.isNil: self.contacts.delete
    if not self.devices.isNil: self.devices.delete
    if not self.ens.isNil: self.ens.delete
    if not self.profilePicture.isNil: self.profilePicture.delete
    if not self.profileSettings.isNil: self.profileSettings.delete
    if not self.mutedChats.isNil: self.mutedChats.delete
    if not self.profile.isNil: self.profile.delete
    if not self.dappList.isNil: self.dappList.delete
    if not self.fleets.isNil: self.fleets.delete
    if not self.network.isNil: self.network.delete
    if not self.mnemonic.isNil: self.mnemonic.delete
    if not self.mailservers.isNil: self.mailservers.delete
    self.QObject.delete

  proc newProfileView*(status: Status, changeLanguage: proc(locale: string)): ProfileView =
    new(result, delete)
    result = ProfileView()
    result.profile = newProfileInfoView()
    result.profilePicture = newProfilePictureView(status, result.profile)
    result.profileSettings = newProfileSettingsView(status, result.profile)
    result.mutedChats = newMutedChatsView(status)
    result.contacts = newContactsView(status)
    result.devices = newDevicesView(status)
    result.network = newNetworkView(status)
    result.mnemonic = newMnemonicView(status)
    result.mailservers = newMailserversView(status)
    result.dappList = newDappList(status)
    result.ens = newEnsManager(status)
    result.fleets = newFleets(status)
    result.changeLanguage = changeLanguage
    result.status = status
    result.setup

  proc initialized*(self: ProfileView) {.signal.}

  proc getProfile(self: ProfileView): QVariant {.slot.} =
    return newQVariant(self.profile)

  proc profileChanged*(self: ProfileView) {.signal.}

  proc setNewProfile*(self: ProfileView, profile: Profile) =
    self.profile.setProfile(profile)
    self.profileSettings.removeUnknownAccountSettings()

  QtProperty[QVariant] profile:
    read = getProfile
    notify = profileChanged

  proc logout*(self: ProfileView) {.slot.} =
    self.status.profile.logout()

  proc changeLocale*(self: ProfileView, locale: string) {.slot.} =
    self.changeLanguage(locale)
  
  proc nodeVersion*(self: ProfileView): string {.slot.} =
    self.status.getNodeVersion()

  proc qrCode*(self: ProfileView, text:string): string {.slot.} =
    result = "data:image/svg+xml;utf8," & generateQRCodeSVG(text, 2)

  proc changeTheme*(self: ProfileView, theme: int) {.slot.} =
    self.profile.setAppearance(theme)
    self.status.saveSetting(Setting.Appearance, $theme)

  proc getDappList(self: ProfileView): QVariant {.slot.} =
    return newQVariant(self.dappList)

  QtProperty[QVariant] dappList:
    read = getDappList

  proc getFleets(self: ProfileView): QVariant {.slot.} =
    return newQVariant(self.fleets)

  QtProperty[QVariant] fleets:
    read = getFleets

  proc getEnsManager(self: ProfileView): QVariant {.slot.} =
    return newQVariant(self.ens)

  QtProperty[QVariant] ens:
    read = getEnsManager

  proc getLinkPreviewWhitelist*(self: ProfileView): string {.slot.} =
    result = $(self.status.profile.getLinkPreviewWhitelist())

  proc setMessagesFromContactsOnly*(self: ProfileView, messagesFromContactsOnly: bool) {.slot.} =
    if (messagesFromContactsOnly == self.profile.messagesFromContactsOnly):
      return
    self.profile.setMessagesFromContactsOnly(messagesFromContactsOnly)
    self.status.saveSetting(Setting.MessagesFromContactsOnly, messagesFromContactsOnly)
    # TODO cleanup chats after activating this

  proc contactsChanged*(self: ProfileView) {.signal.}

  proc getContacts*(self: ProfileView): QVariant {.slot.} =
    newQVariant(self.contacts)

  QtProperty[QVariant] contacts:
    read = getContacts
    notify = contactsChanged

  proc getDevices*(self: ProfileView): QVariant {.slot.} =
    newQVariant(self.devices)

  QtProperty[QVariant] devices:
    read = getDevices

  proc getMailservers*(self: ProfileView): QVariant {.slot.} =
    newQVariant(self.mailservers)

  QtProperty[QVariant] mailservers:
    read = getMailservers

  proc getMnemonic*(self: ProfileView): QVariant {.slot.} =
    newQVariant(self.mnemonic)

  QtProperty[QVariant] mnemonic:
    read = getMnemonic

  proc getNetwork*(self: ProfileView): QVariant {.slot.} = 
    newQVariant(self.network)

  QtProperty[QVariant] network:
    read = getNetwork

  proc getProfilePicture*(self: ProfileView): QVariant {.slot.} =
    newQVariant(self.profilePicture)

  QtProperty[QVariant] picture:
    read = getProfilePicture

  proc getProfileSettings*(self: ProfileView): QVariant {.slot.} =
    newQVariant(self.profileSettings)

  QtProperty[QVariant] settings:
    read = getProfileSettings

  proc getMutedChats*(self: ProfileView): QVariant {.slot.} =
    newQVariant(self.mutedChats)

  QtProperty[QVariant] mutedChats:
    read = getMutedChats

  proc setSendUserStatus*(self: ProfileView, sendUserStatus: bool) {.slot.} =
    if (sendUserStatus == self.profile.sendUserStatus):
      return
    self.profile.setSendUserStatus(sendUserStatus)
    self.status.saveSetting(Setting.SendUserStatus, sendUserStatus)

