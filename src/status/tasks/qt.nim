import # status-desktop libs
  ./common

type
  QObjectTaskArg* = ref object of TaskArg
    vptr*: ByteAddress
    slot*: string
