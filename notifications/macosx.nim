# Copyright (C) Dominik Picheta. All rights reserved.
# MIT License. Look at license.txt for more info.
import os, asyncdispatch
{.passL: "-framework Foundation".}
{.passL: "-framework AppKit".}
{.compile: "macosx.m".}

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
    reply: cstring

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
    pollFut: Future[void]
    onNotificationClick: proc (info: ClickInfo) {.closure.}
  NotificationCenter* = ref NotificationCenterObj

  ClickKind* {.pure.} = enum
    None, ContentsClicked, ActionButtonClicked, Replied, AdditionalActionClicked
  ## Information about what the user clicked on the notification.
  ClickInfo* = object ## Apple call this an "Activation"
    case kind*: ClickKind
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

proc freeActivationInfo(info: ActivationInfo) {.importc, cdecl.}

# Nim procedures

proc newNotificationCenter*(
    onNotificationClick: proc (info: ClickInfo) {.closure.} = nil,
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

    if not center.onNotificationClick.isNil:
      case clickKind
      of ClickKind.AdditionalActionClicked:
        center.onNotificationClick(ClickInfo(
          kind: clickKind,
          selectedTitle: $info.selectedActionTitle,
          selectedIdentifier: $info.selectedActionIdentifier
        ))
      of ClickKind.Replied:
        center.onNotificationClick(ClickInfo(
          kind: clickKind,
          message: $info.reply
        ))
      else:
        center.onNotificationClick(ClickInfo(
          kind: clickKind
        ))

    # Free the ActivationInfo struct's fields.
    freeActivationInfo(info)
    center.polling = false

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
           actionButtons: seq[tuple[ident: string, title: string]],
           subtitle = "",
           actionButtonTitle = "",
           otherButtonTitle = "",
           hasReplyButton = false) {.async.} =
  if not center.polling:
    center.polling = true
    center.pollFut = doPoll(center)

  var additionalButtons: seq[AdditionalButton] = @[]
  for i in actionButtons:
    additionalButtons.add(AdditionalButton(title: i.title, identifier: i.ident))

  var errorCode = 0.cint
  let ret = showNotification(title, subtitle, message, actionButtonTitle,
      otherButtonTitle, hasReplyButton,
      if additionalButtons.len > 0: addr additionalButtons[0] else: nil,
      additionalButtons.len.cint, addr errorCode)
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
  await center.pollFut or sleepAsync(5000)

proc show*(center: NotificationCenter,
           title, message: string,
           subtitle = "",
           actionButtonTitle = "",
           otherButtonTitle = "",
           hasReplyButton = false): Future[void] =
  show(center, title, message, @[], subtitle, actionButtonTitle,
      otherButtonTitle, hasReplyButton)

when isMainModule:
  proc onNotificationClick(info: ClickInfo) =
    echo("Notification clicked: ", info)

  var center = newNotificationCenter(onNotificationClick)

  waitFor center.show("Nim", "Version 1.0 has been released!",
      @[("#1", "Kill All Humans"), ("#2", "Kill John Locke"),
       ("#3", "Join Star Helix")],
      actionButtonTitle="Action", otherButtonTitle="Other")
  echo("First done!")

  waitFor center.show("Sept 1st", "Hello World")
  echo("Second done!")

  waitFor center.show("Please reply", "What's your name, stranger?",
    hasReplyButton = true)
  echo("Third done!")
