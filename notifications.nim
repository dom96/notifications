import os, asyncdispatch
{.passL: "-framework Foundation".}
{.passL: "-framework AppKit".}
{.compile: "notifications_macosx.m".}

# Types defined in the Objective C file.

type
  AdditionalButton = object
    title: cstring
    identifier: cstring

  NSApplication = distinct pointer
  ActivationInfo {.bycopy.} = object
    activationType: cint
    selectedActionTitle: cstring
    selectedActionIdentifier: cstring
  
  NotificationCallback = proc (info: ActivationInfo, data: pointer) {.cdecl.}
  NotificationState {.bycopy.} = object
    app: NSApplication
    onNotificationClick: NotificationCallback
    data: pointer

# Nim types
type
  NotificationCenterObj* = object
    state: NotificationState
    pollInterval: float # In ms
    pollTimeout: float # In ms
    polling: bool
    onNotificationClick: proc (info: ClickInfo) {.closure.}
  NotificationCenter* = ref NotificationCenterObj

  ClickKind* {.pure.} = enum
    None, ContentsClicked, ActionButtonClicked, Replied, AdditionalActionClicked
  ## Information about what the user clicked on the notification.
  ClickInfo* = object ## Apple call this an "Activation"
    case kind: ClickKind
    of ClickKind.None, ClickKind.ContentsClicked,
       ClickKind.ActionButtonClicked: discard
    of ClickKind.Replied:
      message*: string
    of ClickKind.AdditionalActionClicked:
      selectedTitle*: string
      selectedIdentifier*: string

  NotificationError* = object of OSError

# Wrapped C functions

proc showNotification(title, subtitle, message, actionButtonTitle,
    otherButtonTitle: cstring, hasReplyButton: bool,
    additionalButtons: ptr AdditionalButton, additionalButtonsSize: cint,
    errorCode: ptr cint): cint {.importc, cdecl.}

proc createApp(onNotificationClick: NotificationCallback,
    data: pointer): NotificationState
    {.importc, cdecl.}

proc poll(app: NotificationState, timeout: cfloat) {.importc, cdecl.}

# Nim procedures

proc defaultNotificationClick(info: ClickInfo) = discard

proc newNotificationCenter*(
    onNotificationClick: proc (info: ClickInfo) {.closure.} = defaultNotificationClick,
    pollInterval = 100.0,
    pollTimeout = 100.0): NotificationCenter =
  ## Creates a new NotificationCenter.
  ##
  ## The ``pollInterval`` parameter determines (in milliseconds) how often the
  ## Cocoa events should be read.
  ##
  ## The ``pollTimeout`` parameter determines (in milliseconds) how long the
  ## the notification center should wait for new Cocoa events.
  proc objCCallback(info: ActivationInfo, data: pointer) {.cdecl.} =
    let center = cast[ptr NotificationCenterObj](data)
    var clickKind = ClickKind.None
    case info.activationType
    of 0: clickKind = ClickKind.None
    of 1: clickKind = ClickKind.ContentsClicked
    of 2: clickKind = ClickKind.ActionButtonClicked
    of 3: clickKind = ClickKind.Replied
    of 4: clickKind = ClickKind.AdditionalActionClicked
    else:
      raise newException(NotificationError,
          "Unknown activation type, got " & $info.activationType)

    # The kinds above are actually not reported correctly.
    if not info.selectedActionTitle.isNil:
      clickKind = ClickKind.AdditionalActionClicked
      center.onNotificationClick(ClickInfo(
        kind: clickKind,
        selectedTitle: $info.selectedActionTitle,
        selectedIdentifier: $info.selectedActionIdentifier
      ))
    else:
      center.onNotificationClick(ClickInfo(
        kind: clickKind
      ))

  var ret: NotificationCenter
  new ret
  ret.state = createApp(objCCallback, addr ret[])
  ret.pollInterval = pollInterval
  ret.pollTimeout = pollTimeout
  ret.onNotificationClick = onNotificationClick
  return ret

proc doPoll(center: NotificationCenter) {.async.} =
  while center.polling:
    poll(center.state, center.pollTimeout / 1000)
    await sleepAsync(center.pollInterval.int)

proc show*(center: NotificationCenter,
           title, message: string,
           subtitle = "",
           actionButtonTitle = "",
           otherButtonTitle = "",
           hasReplyButton = false) {.async.} =
  if not center.polling:
    center.polling = true
    asyncCheck doPoll(center)

  var errorCode = 0.cint
  let ret = showNotification(title, subtitle, message, actionButtonTitle,
      otherButtonTitle, hasReplyButton, nil, 0, addr errorCode)
  if ret != 0:
    case errorCode
    of 0:
      raise newException(NotificationError, "Error code reports no error.")
    of 1:
      raise newException(NotificationError,
          "Default Notification Center is nil. Have you specified the value" &
          " for the CFBundleIdentifier key in Info.plist?")
    else:
      raise newException(NotificationError, "Unknown error code.")

  # Only hacks available to see when the notification actually disappears.
  # Let's just assume for now (TODO) that it takes 5 seconds for a notification
  # to disappear on its own.
  await sleepAsync(5000)

when isMainModule:
  proc onNotificationClick(info: ClickInfo) =
    echo("Notification clicked: ", info)

  var center = newNotificationCenter(onNotificationClick)
  waitFor center.show("Nim", "Version 1.0 has been released!", actionButtonTitle="Action", otherButtonTitle="Other", hasReplyButton=true)
  echo("Finished!")

when false:

  proc onNotificationClick(info: ActivationInfo) {.cdecl.} =
    echo("Notification click!")
    echo(info.activationType.toHex(10))
    echo(info.repr)

  var additionalButtons = [AdditionalButton(title: "Test", identifier: "1"),
      AdditionalButton(title: "Test2", identifier: "2")]
  var errorCode = 0.cint
  echo showNotification("Amy", "<3", "You are the love of my life!",
                        "Hi", "Other", false, addr(additionalButtons[0]),
                        additionalButtons.len.cint, addr errorCode)
  var app = createApp(onNotificationClick)
  while true:
    poll(app, 0.1)