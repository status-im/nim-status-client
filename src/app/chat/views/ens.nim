import NimQml, Tables, json, sequtils, chronicles, times, re, sugar, strutils, os, strformat, algorithm

import ../../../status/[status, contacts]
import ../../../status/ens as status_ens
import ../../../status/tasks/[qt, task_runner_impl]

logScope:
  topics = "ens-view"

type
  ResolveEnsTaskArg = ref object of QObjectTaskArg
    ens: string

const resolveEnsTask: Task = proc(argEncoded: string) {.gcsafe, nimcall.} =
  let
    arg = decode[ResolveEnsTaskArg](argEncoded)
    output = %* { "address": status_ens.address(arg.ens), "pubkey": status_ens.pubkey(arg.ens) }
  arg.finish(output)

proc resolveEns[T](self: T, slot: string, ens: string) =
  let arg = ResolveEnsTaskArg(
    tptr: cast[ByteAddress](resolveEnsTask),
    vptr: cast[ByteAddress](self.vptr),
    slot: slot, ens: ens
  )
  self.status.tasks.threadpool.start(arg)

QtObject:
  type EnsView* = ref object of QObject
    status: Status

  proc setup(self: EnsView) = self.QObject.setup
  proc delete*(self: EnsView) = self.QObject.delete

  proc newEnsView*(status: Status): EnsView =
    new(result, delete)
    result.status = status
    result.setup

  proc isEnsVerified*(self: EnsView, id: string): bool {.slot.} =
    if id == "": return false
    let contact = self.status.contacts.getContactByID(id)
    if contact == nil:
      return false
    result = contact.ensVerified

  proc formatENSUsername*(self: EnsView, username: string): string {.slot.} =
    result = status_ens.addDomain(username)

  # Resolving a ENS name
  proc resolveENS*(self: EnsView, ens: string) {.slot.} =
    self.resolveEns("ensResolved", ens) # Call self.ensResolved(string) when ens is resolved

  proc ensWasResolved*(self: EnsView, resolvedPubKey: string, resolvedAddress: string) {.signal.}

  proc ensResolved(self: EnsView, addressPubkeyJson: string) {.slot.} =
    var
      parsed = addressPubkeyJson.parseJson
      address = parsed["address"].to(string)
      pubkey = parsed["pubkey"].to(string)
    self.ensWasResolved(pubKey, address)
