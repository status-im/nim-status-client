import
  options, strutils

import
  stint, web3/ethtypes

import
  types
from utils as status_utils import toUInt64, gwei2Wei, parseAddress

proc buildTransaction*(source: Address, value: Uint256, gas = "", gasPrice = "", isEIP1559Enabled = false, maxPriorityFeePerGas = "", maxFeePerGas = "", data = ""): TransactionData =
  result = TransactionData(
    source: source,
    value: value.some,
    gas: (if gas.isEmptyOrWhitespace: Quantity.none else: Quantity(cast[uint64](parseFloat(gas).toUInt64)).some),
    gasPrice: (if gasPrice.isEmptyOrWhitespace: int.none else: gwei2Wei(parseFloat(gasPrice)).truncate(int).some),
    data: data
  )

  if isEIP1559Enabled:
    result.txType = "0x02"
    result.maxPriorityFeePerGas = (if maxPriorityFeePerGas.isEmptyOrWhitespace: int.none else: gwei2Wei(parseFloat(maxPriorityFeePerGas)).truncate(int).some)
    result.maxFeePerGas = (if maxFeePerGas.isEmptyOrWhitespace: int.none else: gwei2Wei(parseFloat(maxFeePerGas)).truncate(int).some)
  else:
    result.txType = "0x00"

proc buildTokenTransaction*(source, contractAddress: Address, gas = "", gasPrice = "", isEIP1559Enabled = false, maxPriorityFeePerGas = "", maxFeePerGas = ""): TransactionData =
  result = buildTransaction(source, 0.u256, gas, gasPrice, isEIP1559Enabled, maxPriorityFeePerGas, maxFeePerGas)
  result.to = contractAddress.some