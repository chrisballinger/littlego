// -----------------------------------------------------------------------------
// Copyright 2011-2012 Patrick Näf (herzbube@herzbube.ch)
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
#import "SaveGameCommand.h"
#import "../../gtp/GtpCommand.h"
#import "../../gtp/GtpResponse.h"
#import "../../main/ApplicationDelegate.h"
#import "../../archive/ArchiveViewModel.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for SaveGameCommand.
// -----------------------------------------------------------------------------
@interface SaveGameCommand()
/// @name Initialization and deallocation
//@{
- (void) dealloc;
//@}
/// @name Helpers
//@{
- (void) showAlertWithError:(NSError*)error;
- (void) showAlertWithMessage:(NSString*)message;
//@}
@end


@implementation SaveGameCommand

@synthesize gameName;


// -----------------------------------------------------------------------------
/// @brief Initializes a SaveGameCommand object.
///
/// @note This is the designated initializer of SaveGameCommand.
// -----------------------------------------------------------------------------
- (id) initWithSaveGame:(NSString*)aGameName
{
  // Call designated initializer of superclass (CommandBase)
  self = [super init];
  if (! self)
    return nil;

  self.gameName = aGameName;

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this SaveGameCommand object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.gameName = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Executes this command. See the class documentation for details.
// -----------------------------------------------------------------------------
- (bool) doIt
{
  if (! self.gameName)
    return false;
  ArchiveViewModel* model = [ApplicationDelegate sharedDelegate].archiveViewModel;
  if (! model)
    return false;

  NSError* error;

  // The GTP engine saves its file into the temporary directory, but the final
  // destination is in the archive folder
  NSString* temporaryDirectory = NSTemporaryDirectory();
  NSString* sgfTemporaryFilePath = [temporaryDirectory stringByAppendingPathComponent:sgfTemporaryFileName];
  NSString* fileName = [gameName stringByAppendingString:@".sgf"];
  NSString* filePath = [model.archiveFolder stringByAppendingPathComponent:fileName];

  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSString* oldCurrentDirectory = [fileManager currentDirectoryPath];
  [fileManager changeCurrentDirectoryPath:temporaryDirectory];
  // Use the file *NAME* without the path
  NSString* commandString = [NSString stringWithFormat:@"savesgf %@", sgfTemporaryFileName];
  GtpCommand* command = [GtpCommand command:commandString];
  command.waitUntilDone = true;
  [command submit];

  // Switch back as soon as possible; from now on operations use the full path
  // to the temporary file
  [fileManager changeCurrentDirectoryPath:oldCurrentDirectory];

  if (! command.response.status)
  {
    [fileManager removeItemAtPath:sgfTemporaryFilePath error:nil];
    assert(0);
    NSString* errorMessage = [NSString stringWithFormat:@"Internal error: GTP engine failed to process 'savesgf' command, reason: %@", [command.response parsedResponse]];
    [self showAlertWithMessage:errorMessage];
    return false;
  }

  // Get rid of another file of the same name (otherwise the subsequent move
  // operation fails)
  if ([fileManager fileExistsAtPath:filePath])
  {
    BOOL success = [fileManager removeItemAtPath:filePath error:&error];
    if (! success)
    {
      [fileManager removeItemAtPath:sgfTemporaryFilePath error:nil];
      assert(0);
      [self showAlertWithError:error];
      return false;
    }
  }

  BOOL success = [fileManager moveItemAtPath:sgfTemporaryFilePath toPath:filePath error:&error];
  if (! success)
  {
    [fileManager removeItemAtPath:sgfTemporaryFilePath error:nil];
    assert(0);
    [self showAlertWithError:error];
    return false;
  }

  [[NSNotificationCenter defaultCenter] postNotificationName:gameSavedToArchive object:self.gameName];
  [[NSNotificationCenter defaultCenter] postNotificationName:archiveContentChanged object:nil];
  return true;
}

// -----------------------------------------------------------------------------
/// @brief Displays "failed to save game" alert with the error details stored
/// in @a error.
// -----------------------------------------------------------------------------
- (void) showAlertWithError:(NSError*)error
{
  NSString* errorMessage = [NSString stringWithFormat:@"Internal error: Failed to save game, reason: %@", [error localizedDescription]];
  [self showAlertWithMessage:errorMessage];
}

// -----------------------------------------------------------------------------
/// @brief Displays "failed to save game" alert with the error details stored
/// in @a message.
// -----------------------------------------------------------------------------
- (void) showAlertWithMessage:(NSString*)message
{
  UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Failed to save game"
                                                  message:message
                                                 delegate:nil
                                        cancelButtonTitle:nil
                                        otherButtonTitles:@"Ok", nil];
  alert.tag = AlertViewTypeSaveGameFailed;
  [alert show];
}

@end
