import
  options, strutils

import
  stint, web3/ethtypes

import
  types
from utils as status_utils import toUInt64, gwei2Wei, parseAddress

proc buildTransaction*(source: Address, value: Uint256, gas = "", gasPrice = "", isEIP1559Enabled = false, maxPriorityFeePerGas = "", maxFeePerGas = "", data = ""): EthSend =
  result = EthSend(
    source: source,
    value: value.some,
    gas: (if gas.isEmptyOrWhitespace: Quantity.none else: Quantity(cast[uint64](parseFloat(gas).toUInt64)).some),
    gasPrice: (if gasPrice.isEmptyOrWhitespace: int.none else: gwei2Wei(parseFloat(gasPrice)).truncate(int).some),
    data: data
  )

proc buildTokenTransaction*(source, contractAddress: Address, gas = "", gasPrice = "", isEIP1559Enabled = false, maxPriorityFeePerGas = "", maxFeePerGas = ""): EthSend =
  result = buildTransaction(source, 0.u256, gas, gasPrice, isEIP1559Enabled, maxPriorityFeePerGas, maxFeePerGas)
  result.to = contractAddress.some