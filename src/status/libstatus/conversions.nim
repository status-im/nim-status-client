import
  json, options, strutils, ../types

import
  web3/[conversions, ethtypes], stint

# TODO: make this public in nim-web3 lib
template stripLeadingZeros*(value: string): string =
  var cidx = 0
  # ignore the last character so we retain '0' on zero value
  while cidx < value.len - 1 and value[cidx] == '0':
    cidx.inc
  value[cidx .. ^1]

proc `%`*(x: TransactionData): JsonNode =
  result = newJobject()
  result["from"] = %x.source
  result["type"] = %x.txType
  if x.to.isSome:
    result["to"] = %x.to.unsafeGet
  if x.gas.isSome:
    result["gas"] = %x.gas.unsafeGet
  if x.gasPrice.isSome:
    result["gasPrice"] = %("0x" & x.gasPrice.unsafeGet.toHex.stripLeadingZeros)
  if x.maxFeePerGas.isSome:
    result["maxFeePerGas"] = %x.maxFeePerGas.unsafeGet
  if x.maxPriorityFeePerGas.isSome:
    result["maxPriorityFeePerGas"] = %x.maxPriorityFeePerGas.unsafeGet
  if x.value.isSome:
    result["value"] = %("0x" & x.value.unsafeGet.toHex)
  result["data"] = %x.data
  if x.nonce.isSome:
    result["nonce"] = %x.nonce.unsafeGet