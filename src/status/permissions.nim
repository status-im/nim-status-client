import json
import strutils
import sets
import libstatus/core
import libstatus/types
import chronicles
import eventemitter
import sequtils

type
  Permission* {.pure.} = enum
    Web3 = "web3",
    ContactCode = "contact-code"
    Unknown = "unknown"

logScope:
  topics = "permissions-model"

type
    PermissionsModel* = ref object
      events*: EventEmitter

proc toPermission*(value: string): Permission =
  result = Permission.Unknown
  try:
    result = parseEnum[Permission](value)
  except:
    warn "Unknown permission requested", value

proc newPermissionsModel*(events: EventEmitter): PermissionsModel =
  result = PermissionsModel()
  result.events = events

proc init*(self: PermissionsModel) =
  discard

proc getPermissions*(self: PermissionsModel, dapp: string): HashSet[Permission] =
  let response = callPrivateRPC("permissions_getDappPermissions")
  result = initHashSet[Permission]()
  for dappPermission in response.parseJson["result"].getElems():
    if dappPermission["dapp"].getStr() == dapp:
      for permission in dappPermission["permissions"].getElems():
        result.incl(permission.getStr().toPermission())

proc hasPermission*(self: PermissionsModel, dapp: string, permission: Permission): bool =
  result = self.getPermissions(dapp).contains(permission)

proc addPermission*(self: PermissionsModel, dapp: string, permission: Permission) =
  var permissions = self.getPermissions(dapp)
  permissions.incl(permission)
  discard callPrivateRPC("permissions_addDappPermissions", %*[{
    "dapp": dapp,
    "permissions": permissions.toSeq()
  }])

proc revokePermission*(self: PermissionsModel, dapp: string, permission: Permission) =
  # TODO: implement
  discard

proc clearPermissions*(self: PermissionsModel, dapp: string) =
  # TODO implement
  discard

proc clearPermissions*(self: PermissionsModel) =
  let response = callPrivateRPC("permissions_getDappPermissions")
  for dapps in response.parseJson["result"].getElems():
    discard callPrivateRPC("permissions_deleteDappPermissions", %*[dapps["dapp"].getStr()])
