// -----------------------------------------------------------------------------
// Copyright 2012-2016 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Project includes
#import "SendBugReportController.h"
#import "../command/diagnostics/GenerateDiagnosticsInformationFileCommand.h"
#import "../main/ApplicationDelegate.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for SendBugReportController.
// -----------------------------------------------------------------------------
@interface SendBugReportController()
@property(nonatomic, assign) bool sendBugReportMode;
@property(nonatomic, retain) UIViewController* modalViewControllerParent;
@property(nonatomic, retain) NSString* diagnosticsInformationFilePath;
@end


@implementation SendBugReportController

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Convenience constructor.
// -----------------------------------------------------------------------------
+ (SendBugReportController*) controller
{
  SendBugReportController* controller = [[SendBugReportController alloc] init];
  if (controller)
    [controller autorelease];
  return controller;
}

// -----------------------------------------------------------------------------
/// @brief Initializes a SendBugReportController object.
///
/// @note This is the designated initializer of SendBugReportController.
// -----------------------------------------------------------------------------
- (id) init
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;

  self.delegate = nil;
  self.bugReportDescription = @"_____";
  self.bugReportStepsToReproduce = [NSArray arrayWithObjects:@"_____", @"_____", @"_____", nil];
  self.sendBugReportMode = false;
  self.modalViewControllerParent = nil;
  self.diagnosticsInformationFilePath = nil;

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this SendBugReportController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.delegate = nil;
  self.bugReportDescription = nil;
  self.bugReportStepsToReproduce = nil;
  self.modalViewControllerParent = nil;
  self.diagnosticsInformationFilePath = nil;
  [super dealloc];
}

#pragma mark - Public API

// -----------------------------------------------------------------------------
/// @brief Triggers the "send bug report" process as described in the class
/// documentation. @a aModalViewControllerParent is used to present the "mail
/// compose" view controller.
// -----------------------------------------------------------------------------
- (void) sendBugReport:(UIViewController*)aModalViewControllerParent
{
  self.modalViewControllerParent = aModalViewControllerParent;
  self.sendBugReportMode = true;
  if (! [self canSendMail])
    return;
  if (! [self generateDiagnosticsInformationFileInternal])
    return;
  [self presentMailComposeController];
}

// -----------------------------------------------------------------------------
/// @brief Generates the diagnostics information file for later transfer with
/// iTunes file sharing. Displays an alert to let the user know the name of the
/// file.
// -----------------------------------------------------------------------------
- (void) generateDiagnosticsInformationFile
{
  self.sendBugReportMode = false;
  if (! [self generateDiagnosticsInformationFileInternal])
    return;

  NSString* alertTitle = @"Information generated";
  NSString* alertMessage = [NSString stringWithFormat:@"Diagnostics information has been generated and is ready for transfer to your computer via iTunes file sharing. In iTunes look for the file named '%@'.", bugReportDiagnosticsInformationFileName];
  NSString* buttonTitle = @"Ok";
  [self presentAlertWithTitle:alertTitle message:alertMessage buttonTitle:buttonTitle];
}

#pragma mark - Private helpers

// -----------------------------------------------------------------------------
/// @brief Returns true if the device is configured for sending emails. Displays
/// an alert and returns false if the device is not configured.
// -----------------------------------------------------------------------------
- (bool) canSendMail
{
  bool canSendMail = [MFMailComposeViewController canSendMail];
  if (! canSendMail)
  {
    NSString* alertTitle = @"Operation failed";
    NSString* alertMessage = @"This device is not configured to send email.";
    NSString* buttonTitle = @"Ok";
    [self presentAlertWithTitle:alertTitle message:alertMessage buttonTitle:buttonTitle];
  }
  return canSendMail;
}

// -----------------------------------------------------------------------------
/// @brief Generates the diagnostics information file. Returns true on success,
/// false on failure. Displays an alert on failure, but remains silent on
/// success.
// -----------------------------------------------------------------------------
- (bool) generateDiagnosticsInformationFileInternal
{
  GenerateDiagnosticsInformationFileCommand* command = [[[GenerateDiagnosticsInformationFileCommand alloc] init] autorelease];
  bool success = [command submit];
  self.diagnosticsInformationFilePath = command.diagnosticsInformationFilePath;
  if (! success)
  {
    NSString* alertTitle = @"Operation failed";
    NSString* alertMessage = @"An error occurred while generating diagnostics information.";
    NSString* buttonTitle = @"Very funny!";
    [self presentAlertWithTitle:alertTitle message:alertMessage buttonTitle:buttonTitle];
  }
  return success;
}

// -----------------------------------------------------------------------------
/// @brief Displays the "mail compose" view controller.
// -----------------------------------------------------------------------------
- (void) presentMailComposeController
{
  MFMailComposeViewController* mailComposeViewController = [[MFMailComposeViewController alloc] init];
  mailComposeViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  mailComposeViewController.mailComposeDelegate = self;

  mailComposeViewController.toRecipients = [NSArray arrayWithObject:bugReportEmailRecipient];
  mailComposeViewController.subject = bugReportEmailSubject;
  NSString* messageBody = [self mailMessageBody];
  [mailComposeViewController setMessageBody:messageBody isHTML:NO];
  NSData* data = [NSData dataWithContentsOfFile:self.diagnosticsInformationFilePath];
  NSString* mimeType = bugReportDiagnosticsInformationFileMimeType;
  [mailComposeViewController addAttachmentData:data mimeType:mimeType fileName:bugReportDiagnosticsInformationFileName];

  [self.modalViewControllerParent presentViewController:mailComposeViewController animated:YES completion:nil];
  [mailComposeViewController release];
  [self retain];  // must survive until the delegate method is invoked
}

// -----------------------------------------------------------------------------
/// @brief Returns the message body for the bug report email.
// -----------------------------------------------------------------------------
- (NSString*) mailMessageBody
{
  NSString* bugReportStepLines = @"";
  int bugReportStepNumber = 1;
  for (NSString* bugReportStepString in self.bugReportStepsToReproduce)
  {
    NSString* bugReportStepLine = [NSString stringWithFormat:@"%d. %@", bugReportStepNumber, bugReportStepString];
    if (bugReportStepNumber > 1)
      bugReportStepLines = [bugReportStepLines stringByAppendingString:@"\n"];
    bugReportStepLines = [bugReportStepLines stringByAppendingString:bugReportStepLine];
    ++bugReportStepNumber;
  }

  NSString* bugReportMessageTemplateFilePath = [[ApplicationDelegate sharedDelegate].resourceBundle pathForResource:bugReportMessageTemplateResource ofType:nil];
  NSString* bugReportMessageTemplateString = [NSString stringWithContentsOfFile:bugReportMessageTemplateFilePath encoding:NSUTF8StringEncoding error:nil];
  return [NSString stringWithFormat:bugReportMessageTemplateString, self.bugReportDescription, bugReportStepLines];
}

#pragma mark - MFMailComposeViewControllerDelegate overrides

// -----------------------------------------------------------------------------
/// @brief MFMailComposeViewControllerDelegate method
// -----------------------------------------------------------------------------
- (void) mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
  [self.modalViewControllerParent dismissViewControllerAnimated:YES completion:nil];
  switch (result)
  {
    case MFMailComposeResultSent:
    {
      DDLogInfo(@"SendBugReportController: Bug report sent");
      break;
    }
    case MFMailComposeResultCancelled:
    {
      DDLogInfo(@"SendBugReportController: Bug report cancelled");
      break;
    }
    case MFMailComposeResultSaved:
    {
      DDLogInfo(@"SendBugReportController: Bug report saved to draft folder");
      break;
    }
    case MFMailComposeResultFailed:
    {
      NSString* logMessage = [NSString stringWithFormat:@"SendBugReportController: Sending bug report failed. Error code = %ld, error description = %@",
                              (long)[error code],
                              [error localizedDescription]];
      DDLogError(@"%@", logMessage);
      break;
    }
    default:
    {
      NSString* logMessage = [NSString stringWithFormat:@"SendBugReportController: Sending bug report finished with unknown result: %d",
                              result];
      DDLogInfo(@"%@", logMessage);
      break;
    }
  }
  [self autorelease];  // balance retain that is sent before the mail view is shown
  [self notifyDelegate];
}

#pragma mark - Present and handle alerts

// -----------------------------------------------------------------------------
/// @brief Presents an alert using the specified title and message. The alert
/// has a single button with the specified button title.
// -----------------------------------------------------------------------------
- (void) presentAlertWithTitle:(NSString*)alertTitle message:(NSString*)alertMessage buttonTitle:(NSString*)buttonTitle
{
  UIAlertController* alertController = [UIAlertController alertControllerWithTitle:alertTitle
                                                                           message:alertMessage
                                                                    preferredStyle:UIAlertControllerStyleAlert];

  void (^actionBlock) (UIAlertAction*) = ^(UIAlertAction* action)
  {
    [self autorelease];  // balance retain that is sent before an alert is shown
    [self notifyDelegate];
  };
  UIAlertAction* action = [UIAlertAction actionWithTitle:buttonTitle
                                                   style:UIAlertActionStyleDefault
                                                 handler:actionBlock];
  [alertController addAction:action];

  [[ApplicationDelegate sharedDelegate].window.rootViewController presentViewController:alertController animated:YES completion:nil];

  [self retain];  // must survive until the delegate method is invoked
}

#pragma mark - Private helpers

// -----------------------------------------------------------------------------
/// @brief Notifies the delegate that the process managed by this controller
/// has ended.
// -----------------------------------------------------------------------------
- (void) notifyDelegate
{
  if (self.delegate)
  {
    if (self.sendBugReportMode)
      [self.delegate sendBugReportDidFinish:self];
    else
      [self.delegate generateDiagnosticsInformationFileDidFinish:self];
  }
}

@end
