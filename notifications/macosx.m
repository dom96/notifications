// Copyright (C) Dominik Picheta. All rights reserved.
// MIT License. Look at license.txt for more info.

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

typedef struct AdditionalButton {
  const char* title;
  const char* identifier;
} AdditionalButton;

typedef struct ActivationInfo {
  int activationType;
  const char* selectedActionTitle;
  const char* selectedActionIdentifier;
  const char* reply;
} ActivationInfo;

typedef void (*NotificationCallback)(ActivationInfo notification, void* data);

typedef struct NotificationState {
  NSApplication *app;
  NotificationCallback onNotificationClick;
  void* data;
} NotificationState;

// AppDelegate

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>
  @property NotificationState notificationState;
@end

@implementation AppDelegate


- (void)dealloc {
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
        shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

- (void) userNotificationCenter:(NSUserNotificationCenter *)center
         didActivateNotification:(NSUserNotification *)notification {
    ActivationInfo info;
    memset(&info, 0, sizeof(ActivationInfo));
    info.activationType = (int)notification.activationType;
    if (notification.additionalActivationAction != nil) {
      info.selectedActionTitle =
        strdup([notification.additionalActivationAction.title UTF8String]);
      info.selectedActionIdentifier =
        strdup([notification.additionalActivationAction.identifier UTF8String]);
    }
    if (notification.response != nil) {
      info.reply = strdup([notification.response.string UTF8String]);
    }
    self.notificationState.onNotificationClick(info, self.notificationState.data);
}


- (void)userNotificationCenter:(NSUserNotificationCenter *)center
        didDeliverNotification:(NSUserNotification *)userNotification {
    //NSLog(@"Delivered notification");
}

@end

// Functions to be wrapped in Nim.

void freeActivationInfo(ActivationInfo info) {
  free(info.selectedActionTitle);
  free(info.selectedActionIdentifier);
  free(info.reply);
}

NotificationState createApp(NotificationCallback onNotificationClick,
    void* data) {
  NotificationState result;
  AppDelegate *delegate = [[AppDelegate alloc] init];

  NSApplication* app = [NSApplication sharedApplication];
  result.app = app;
  result.onNotificationClick = onNotificationClick;
  result.data = data;
  delegate.notificationState = result;
  [app setDelegate:delegate];
  [NSApp finishLaunching];
  return result;
}

/*
  Checks for any NSApplication events. Timeout is in seconds, but values
  between 0 and 1 are allowed so you can specify it in miliseconds.
*/
void poll(NotificationState notificationState, float timeout) {
  NSEvent *event =
    [notificationState.app
        nextEventMatchingMask:NSAnyEventMask
        untilDate:[NSDate dateWithTimeIntervalSinceNow:timeout]
        inMode:NSDefaultRunLoopMode
        dequeue:YES];
  [notificationState.app sendEvent:event];
  [notificationState.app updateWindows];
}

/*
  Shows a new notification with the specified options.

  Returns 0 on success. 1 otherwise.

  On failure the ``errorCode`` is populated with an error code. It is also
  populated when there is no error (with 0). The error codes are:

  0 - No error.
  1 - Default notification center is nil. Make sure `CFBundleIdentifier` is
      defined in the Info.plist file.
*/

int showNotification(const char* title, const char* subtitle,
                     const char* message, const char* actionButtonTitle,
                     const char* otherButtonTitle, bool hasReplyButton,
                     const AdditionalButton* additionalButtons,
                     int additionalButtonsSize,
                     int* errorCode) {
  // This proved useful for debugging this http://stackoverflow.com/a/20226193/492186

  // Allocate a new NSString based on the char* passed from Nim.
  NSString *nsTitle = [[NSString alloc] initWithUTF8String:title];
  NSString *nsSubtitle = [[NSString alloc] initWithUTF8String:subtitle];
  NSString *nsMsg = [[NSString alloc] initWithUTF8String:message];
  NSString *nsActionButtonTitle = [[NSString alloc] initWithUTF8String:actionButtonTitle];
  NSString *nsOtherButtonTitle = [[NSString alloc] initWithUTF8String:otherButtonTitle];

  NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
  if (center == nil) {
    *errorCode = 1;
    return 1;
  }

  NSUserNotification *notification = [NSUserNotification new];
  notification.title = nsTitle;
  notification.subtitle = nsSubtitle;
  notification.informativeText = nsMsg;

  if (nsActionButtonTitle.length > 0 || nsOtherButtonTitle.length > 0 ||
      additionalButtonsSize > 0) {
    // Action buttons are off by default. You can force them to show though with
    // http://stackoverflow.com/a/23087567/492186
    [notification setValue:@YES forKey:@"_showsButtons"];
  }
  if (additionalButtonsSize > 0) {
    // https://github.com/indragiek/NSUserNotificationPrivate/blob/ad4fc22dd48495e4b5e8a6dc564113a8650338b9/NSUserNotificationPrivate/INDAppDelegate.m#L35
    // Force the showing of drop down arrow.
    [notification setValue:@YES forKey:@"_alwaysShowAlternateActionMenu"];

    NSMutableArray* additionalActions = [NSMutableArray array];
    for (int i = 0; i < additionalButtonsSize; i++) {
      NSString *nsBtnTitle = [[NSString alloc]
          initWithUTF8String:additionalButtons[i].title];
      NSString *nsBtnId = [[NSString alloc]
          initWithUTF8String:additionalButtons[i].identifier];
      [additionalActions addObject:
        [NSUserNotificationAction actionWithIdentifier:nsBtnId
          title:nsBtnTitle]];
    }
    notification.additionalActions = additionalActions;
  }

  if (nsActionButtonTitle.length > 0 || additionalButtonsSize > 0) {
    notification.hasActionButton = YES;
  }
  notification.hasReplyButton = hasReplyButton;
  notification.actionButtonTitle = nsActionButtonTitle;
  notification.otherButtonTitle = nsOtherButtonTitle;

  notification.soundName = NSUserNotificationDefaultSoundName;
  [center deliverNotification:notification];

  errorCode = 0;
  return 0;
}