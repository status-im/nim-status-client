import json
import ../types

type Profile* = ref object
  id*, alias*, username*, identicon*, address*, ensName*, localNickname*: string
  ensVerified*: bool
  messagesFromContactsOnly*: bool
  sendUserStatus*: bool
  identityImage*: IdentityImage
  appearance*: int
  systemTags*: seq[string]


const contactAdded* = ":contact/added"
const contactBlocked* = ":contact/blocked"
const contactRequest* = ":contact/request-received"

proc isContact*(self: Profile): bool =
  result = self.systemTags.contains(contactAdded) and not self.systemTags.contains(":contact/blocked")

proc isBlocked*(self: Profile): bool =
  result = self.systemTags.contains(contactBlocked)

proc requestReceived*(self: Profile): bool =
  result = self.systemTags.contains(contactRequest)

proc toProfileModel*(account: Account): Profile =
  result = Profile(
    id: "",
    username: account.name,
    identicon: account.identicon,
    alias: account.name,
    ensName: "",
    ensVerified: false,
    appearance: 0,
    systemTags: @[]
  )

proc toProfileModel*(profile: JsonNode): Profile =
  var systemTags: seq[string] = @[]
  if profile["systemTags"].kind != JNull:
    systemTags = profile["systemTags"].to(seq[string])

  result = Profile(
    id: profile["id"].str,
    username: profile["alias"].str,
    identicon: profile["identicon"].str,
    identityImage: IdentityImage(),
    address: profile["id"].str,
    alias: profile["alias"].str,
    ensName: "",
    ensVerified: profile["ensVerified"].getBool,
    appearance: 0,
    systemTags: systemTags
  )
  
  if profile.hasKey("name"):
    result.ensName = profile["name"].str
  
  if profile.hasKey("localNickname"):
    result.localNickname = profile["localNickname"].str

  if profile.hasKey("images") and profile["images"].kind != JNull:
    if profile["images"].hasKey("thumbnail"):
      result.identityImage.thumbnail = profile["images"]["thumbnail"]["uri"].str
    if profile["images"].hasKey("large"):
      result.identityImage.large = profile["images"]["large"]["uri"].str
