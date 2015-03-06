// -----------------------------------------------------------------------------
// Copyright 2011-2014 Patrick Näf (herzbube@herzbube.ch)
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
#import "StatusViewController.h"
#import "../model/ScoringModel.h"
#import "../../go/GoBoardPosition.h"
#import "../../go/GoGame.h"
#import "../../go/GoMove.h"
#import "../../go/GoPlayer.h"
#import "../../go/GoPoint.h"
#import "../../go/GoScore.h"
#import "../../go/GoVertex.h"
#import "../../main/ApplicationDelegate.h"
#import "../../player/Player.h"
#import "../../shared/LayoutManager.h"
#import "../../shared/LongRunningActionCounter.h"
#import "../../ui/AutoLayoutUtility.h"
#import "../../utility/ExceptionUtility.h"
#import "../../utility/NSStringAdditions.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for StatusViewController.
// -----------------------------------------------------------------------------
@interface StatusViewController()
@property(nonatomic, retain) UILabel* statusLabel;
@property(nonatomic, retain) UIActivityIndicatorView* activityIndicator;
@property(nonatomic, assign) bool activityIndicatorNeedsUpdate;
@property(nonatomic, assign) bool statusLabelNeedsUpdate;
@property(nonatomic, retain) NSArray* crossHairInformation;
@property(nonatomic, assign) bool shouldDisplayActivityIndicator;
@property(nonatomic, retain) NSLayoutConstraint* activityIndicatorWidthConstraint;
@property(nonatomic, retain) NSLayoutConstraint* activityIndicatorSpacingConstraint;
@end


@implementation StatusViewController

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a StatusViewController object.
///
/// @note This is the designated initializer of StatusViewController.
// -----------------------------------------------------------------------------
- (id) init
{
  // Call designated initializer of superclass (UIViewController)
  self = [super initWithNibName:nil bundle:nil];
  if (! self)
    return nil;
  [self releaseObjects];
  self.activityIndicatorNeedsUpdate = false;
  self.statusLabelNeedsUpdate = false;
  self.shouldDisplayActivityIndicator = false;
  self.activityIndicatorWidthConstraint = nil;
  self.activityIndicatorSpacingConstraint = nil;
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this StatusViewController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [self removeNotificationResponders];
  [self releaseObjects];
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) releaseObjects
{
  self.statusLabel = nil;
  self.activityIndicator = nil;
  self.crossHairInformation = nil;
  self.activityIndicatorWidthConstraint = nil;
  self.activityIndicatorSpacingConstraint = nil;
}

#pragma mark - UIViewController overrides

// -----------------------------------------------------------------------------
/// @brief UIViewController method.
// -----------------------------------------------------------------------------
- (void) loadView
{
  [self createViews];
  [self setupViewHierarchy];
  [self configureViews];
  [self setupAutoLayoutConstraints];
  [self updateAutoLayoutConstraints];
  [self setupNotificationResponders];

  // New controller instances may be created in mid-game after a layout change
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

#pragma mark - Private helpers for loadView

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) createViews
{
  [super loadView];
  self.statusLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
  self.activityIndicator = [[[UIActivityIndicatorView alloc] initWithFrame:CGRectZero] autorelease];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) setupViewHierarchy
{
  [self.view addSubview:self.statusLabel];
  [self.view addSubview:self.activityIndicator];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) configureViews
{
  self.statusLabel.numberOfLines = 0;
  // Font size must strike a balance between remaining legible and accomodating
  // the longest possible status text in the most space-constrained application
  // state. When testing consider this:
  // - The longest possible status text is the one that includes the player
  //   name, because that name is variable and can be entered by the user.
  // - The second-longest status text is the one about the game ending with 2
  //   pass moves.
  // - The third-longest status text is the one in scoring mode.
  // - In layouts where the space available to the status view is fixed: Make
  //   tests with the player name.
  // - In layouts where the space available to the status view is variable:
  //   Make tests both with all three
  CGFloat fontSize;
  switch ([LayoutManager sharedManager].uiType)
  {
    case UITypePhonePortraitOnly:
      // Label can have 3 lines. Player names can be somewhat longer than 40
      // characters but must consist of several words for line breaks.
      fontSize = 9.0f;
      break;
    case UITypePhone:
      // Portrait: See UITypePhonePortraitOnly.
      // Landscape: Label can have 3 lines. Player names about 40 characters
      // long are OK but must consist of several words for line breaks.
      fontSize = 11.0f;
      break;
    case UITypePad:
      // Label can have 3 lines. Player names can be insanely long and can
      // even consist of long words.
      fontSize = 10.0f;
      break;
    default:
      [ExceptionUtility throwInvalidUIType:[LayoutManager sharedManager].uiType];
  }
  self.statusLabel.font = [UIFont systemFontOfSize:fontSize];
  self.statusLabel.lineBreakMode = NSLineBreakByWordWrapping;
  self.statusLabel.textAlignment = NSTextAlignmentCenter;

  bool isLandscapeOrientation = UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
  if ([LayoutManager sharedManager].uiType == UITypePhone && isLandscapeOrientation)
  {
    self.statusLabel.textColor = [UIColor whiteColor];
    self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
  }
  else
  {
    self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
  }
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) setupAutoLayoutConstraints
{
  self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;

  NSDictionary* viewsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                   self.statusLabel, @"statusLabel",
                                   self.activityIndicator, @"activityIndicator",
                                   nil];
  NSArray* visualFormats = [NSArray arrayWithObjects:
                            @"H:|-0-[statusLabel]",
                            @"H:[activityIndicator]-0-|",
                            @"V:|-0-[statusLabel]-0-|",
                            nil];
  [AutoLayoutUtility installVisualFormats:visualFormats
                                withViews:viewsDictionary
                                   inView:self.view];
  [AutoLayoutUtility alignFirstView:self.activityIndicator
                     withSecondView:self.statusLabel
                        onAttribute:NSLayoutAttributeCenterY
                   constraintHolder:self.view];
  self.activityIndicatorWidthConstraint = [NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:nil
                                                                       attribute:NSLayoutAttributeNotAnAttribute
                                                                      multiplier:1.0f
                                                                        constant:0.0f];
  self.activityIndicatorSpacingConstraint = [NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                                         attribute:NSLayoutAttributeLeft
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.statusLabel
                                                                         attribute:NSLayoutAttributeRight
                                                                        multiplier:1.0f
                                                                          constant:0.0f];
  [self.view addConstraint:self.activityIndicatorWidthConstraint];
  [self.view addConstraint:self.activityIndicatorSpacingConstraint];
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) updateAutoLayoutConstraints
{
  if (self.shouldDisplayActivityIndicator)
  {
    // Experimentally determined custom spacing
    self.activityIndicatorSpacingConstraint.constant = 15.0f;
    self.activityIndicatorWidthConstraint.constant = self.activityIndicator.intrinsicContentSize.width;
  }
  else
  {
    self.activityIndicatorSpacingConstraint.constant = 0.0f;
    self.activityIndicatorWidthConstraint.constant = 0.0f;
  }
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) setupNotificationResponders
{
  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(goGameWillCreate:) name:goGameWillCreate object:nil];
  [center addObserver:self selector:@selector(goGameDidCreate:) name:goGameDidCreate object:nil];
  [center addObserver:self selector:@selector(goGameStateChanged:) name:goGameStateChanged object:nil];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStarts object:nil];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStops object:nil];
  [center addObserver:self selector:@selector(goScoreScoringDisabled:) name:goScoreScoringDisabled object:nil];
  [center addObserver:self selector:@selector(goScoreCalculationEnds:) name:goScoreCalculationEnds object:nil];
  [center addObserver:self selector:@selector(askGtpEngineForDeadStonesStarts:) name:askGtpEngineForDeadStonesStarts object:nil];
  [center addObserver:self selector:@selector(askGtpEngineForDeadStonesEnds:) name:askGtpEngineForDeadStonesEnds object:nil];
  [center addObserver:self selector:@selector(boardViewDidChangeCrossHair:) name:boardViewDidChangeCrossHair object:nil];
  [center addObserver:self selector:@selector(longRunningActionEnds:) name:longRunningActionEnds object:nil];
  // KVO observing
  [[GoGame sharedGame].boardPosition addObserver:self forKeyPath:@"currentBoardPosition" options:0 context:NULL];
  [[ApplicationDelegate sharedDelegate].scoringModel addObserver:self forKeyPath:@"scoreMarkMode" options:0 context:NULL];
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) removeNotificationResponders
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[GoGame sharedGame].boardPosition removeObserver:self forKeyPath:@"currentBoardPosition"];
  [[ApplicationDelegate sharedDelegate].scoringModel removeObserver:self forKeyPath:@"scoreMarkMode"];
}

// -----------------------------------------------------------------------------
/// @brief Internal helper that correctly handles delayed updates. See class
/// documentation for details.
// -----------------------------------------------------------------------------
- (void) delayedUpdate
{
  if ([LongRunningActionCounter sharedCounter].counter > 0)
    return;
  [self updateStatusView];
}

// -----------------------------------------------------------------------------
/// @brief Updates the status view with text that provides feedback to the user
/// about what's going on. Also starts/stops animating the activity indicator.
// -----------------------------------------------------------------------------
- (void) updateStatusView
{
  [self updateActivityIndicator];
  [self updateStatusLabel];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for updateStatusView.
// -----------------------------------------------------------------------------
- (void) updateActivityIndicator
{
  if (! self.activityIndicatorNeedsUpdate)
    return;
  self.activityIndicatorNeedsUpdate = false;

  GoGame* game = [GoGame sharedGame];
  bool shouldDisplayActivityIndicator = false;
  if (game.score.scoringEnabled)
  {
    if (game.score.askGtpEngineForDeadStonesInProgress)
      shouldDisplayActivityIndicator = true;
    else
      shouldDisplayActivityIndicator = false;
  }
  else
  {
    if ([game isComputerThinking])
      shouldDisplayActivityIndicator = true;
    else
      shouldDisplayActivityIndicator = false;
  }

  if (shouldDisplayActivityIndicator == self.shouldDisplayActivityIndicator)
    return;  // activity indicator already has desired state
  self.shouldDisplayActivityIndicator = shouldDisplayActivityIndicator;

  [self updateAutoLayoutConstraints];

  if (shouldDisplayActivityIndicator)
    [self.activityIndicator startAnimating];
  else
    [self.activityIndicator stopAnimating];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for updateStatusView.
// -----------------------------------------------------------------------------
- (void) updateStatusLabel
{
  if (! self.statusLabelNeedsUpdate)
    return;
  self.statusLabelNeedsUpdate = false;

  NSString* statusText = @"";

  if (self.crossHairInformation)
  {
    GoPoint* crossHairPoint = [self.crossHairInformation objectAtIndex:0];
    bool crossHairPointIsLegalMove = [[self.crossHairInformation objectAtIndex:1] boolValue];
    if (crossHairPointIsLegalMove)
    {
      statusText = crossHairPoint.vertex.string;
    }
    else
    {
      statusText = crossHairPoint.vertex.string;
      enum GoMoveIsIllegalReason isIllegalReason = [[self.crossHairInformation objectAtIndex:2] intValue];
      switch (isIllegalReason)
      {
        case GoMoveIsIllegalReasonIntersectionOccupied:
        {
          // No special message if intersection is occupied, that's too basic
          break;
        }
        default:
        {
          NSString* isIllegalReasonString = [NSString stringWithMoveIsIllegalReason:isIllegalReason];
          statusText = [statusText stringByAppendingString:@" - Cannot play: "];
          statusText = [statusText stringByAppendingString:isIllegalReasonString];
          break;
        }
      }
    }
  }
  else
  {
    GoGame* game = [GoGame sharedGame];
    if (game.isComputerThinking)
    {
      switch (game.reasonForComputerIsThinking)
      {
        case GoGameComputerIsThinkingReasonComputerPlay:
        {
          NSString* playerName = game.currentPlayer.player.name;
          if (game.isComputerPlayersTurn)
            statusText = [playerName stringByAppendingString:@" is thinking..."];
          else
            statusText = [NSString stringWithFormat:@"Computer is playing for %@...", playerName];
          break;
        }
        case GoGameComputerIsThinkingReasonPlayerInfluence:
        {
          statusText = @"Updating player influence...";
          break;
        }
        default:
        {
          assert(0);
          break;
        }
      }
    }
    else
    {
      GoScore* score = [GoGame sharedGame].score;
      if (score.scoringEnabled)
      {
        if (score.scoringInProgress)
          statusText = @"Scoring in progress...";
        else
        {
          statusText = [[GoGame sharedGame].score resultString];
          if (GoScoreMarkModeDead == [ApplicationDelegate sharedDelegate].scoringModel.scoreMarkMode)
            statusText = [statusText stringByAppendingString:@" - Tap to mark dead stones"];
          else
            statusText = [statusText stringByAppendingString:@" - Tap to mark stones in seki"];
        }
      }
      else
      {
        enum GoGameState gameState = game.state;
        if (GoGameStateGameHasStarted == gameState ||
            GoGameStateGameIsPaused == gameState ||
            (GoGameStateGameHasEnded == gameState && ! game.boardPosition.isLastPosition))
        {
          statusText = [self statusTextForCurrentAndNextBoardPosition];
        }
        else if (GoGameStateGameHasEnded == gameState)
        {
          switch (game.reasonForGameHasEnded)
          {
            case GoGameHasEndedReasonTwoPasses:
            {
              statusText = @"Game has ended by two consecutive pass moves";
              break;
            }
            case GoGameHasEndedReasonResigned:
            {
              NSString* color;
              // TODO fix when GoColor class is added
              if (game.currentPlayer.black)
                color = @"Black";
              else
                color = @"White";
              statusText = [NSString stringWithFormat:@"%@ resigned", color];
              break;
            }
            default:
              break;
          }
        }
      }
    }
  }
  self.statusLabel.text = statusText;
}

// -----------------------------------------------------------------------------
/// @brief Private helper for updateStatusLabel.
// -----------------------------------------------------------------------------
- (NSString*) statusTextForCurrentAndNextBoardPosition
{
  GoGame* game = [GoGame sharedGame];
  GoBoardPosition* boardPosition = game.boardPosition;

  NSString* colorNextBoardPosition;
  NSString* colorCurrentBoardPosition;
  if (boardPosition.currentPlayer.black)
  {
    colorNextBoardPosition = @"Black";
    colorCurrentBoardPosition = @"White";
  }
  else
  {
    colorNextBoardPosition = @"White";
    colorCurrentBoardPosition = @"Black";
  }

  NSString* statusTextCurrentBoardPosition;
  GoMove* currentMove = boardPosition.currentMove;
  GoMove* nextMove;
  if (currentMove)
  {
    nextMove = currentMove.next;
    if (GoMoveTypePlay == currentMove.type)
      statusTextCurrentBoardPosition = [NSString stringWithFormat:@"%@ played %@", colorCurrentBoardPosition, currentMove.point.vertex.string];
    else
      statusTextCurrentBoardPosition = [NSString stringWithFormat:@"%@ passed", colorCurrentBoardPosition];
  }
  else
  {
    if (boardPosition.isFirstPosition)
      nextMove = game.firstMove;  // could still be nil if no moves have been made yet
    else
      nextMove = nil;
    statusTextCurrentBoardPosition = @"Game started";
  }

  NSString* statusTextNextBoardPosition;
  if (nextMove)
  {
    if (GoMoveTypePlay == nextMove.type)
      statusTextNextBoardPosition = [NSString stringWithFormat:@"%@ will play %@", colorNextBoardPosition, nextMove.point.vertex.string];
    else
      statusTextNextBoardPosition = [NSString stringWithFormat:@"%@ will pass", colorNextBoardPosition];
  }
  else
  {
    statusTextNextBoardPosition = [NSString stringWithFormat:@"%@ to move", colorNextBoardPosition];
  }

  return [NSString stringWithFormat:@"%@\n%@", statusTextCurrentBoardPosition, statusTextNextBoardPosition];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameWillCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameWillCreate:(NSNotification*)notification
{
  GoGame* oldGame = [notification object];
  [oldGame.boardPosition removeObserver:self forKeyPath:@"currentBoardPosition"];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameDidCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameDidCreate:(NSNotification*)notification
{
  GoGame* newGame = [notification object];
  [newGame.boardPosition addObserver:self forKeyPath:@"currentBoardPosition" options:0 context:NULL];
  // In case a new game is started abruptly without cleaning up state in the
  // old game
  self.activityIndicatorNeedsUpdate = true;
  // We don't get a goGameStateChanged because the old game is deallocated
  // without a state change, and the new game already starts with its correct
  // initial state
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameStateChanged notification.
// -----------------------------------------------------------------------------
- (void) goGameStateChanged:(NSNotification*)notification
{
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #computerPlayerThinkingStarts and
/// #computerPlayerThinkingStops notifications.
// -----------------------------------------------------------------------------
- (void) computerPlayerThinkingChanged:(NSNotification*)notification
{
  self.activityIndicatorNeedsUpdate = true;
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreScoringDisabled notification.
// -----------------------------------------------------------------------------
- (void) goScoreScoringDisabled:(NSNotification*)notification
{
  // Need this to remove score summary message
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreCalculationEnds notifications.
// -----------------------------------------------------------------------------
- (void) goScoreCalculationEnds:(NSNotification*)notification
{
  // No activity indicator update here, this is handled by
  // askGtpEngineForDeadStonesEnds because the notification is optional.
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #askGtpEngineForDeadStonesStarts notifications.
// -----------------------------------------------------------------------------
- (void) askGtpEngineForDeadStonesStarts:(NSNotification*)notification
{
  self.activityIndicatorNeedsUpdate = true;
  // The activity indicator is displayed long enough so that it's worth to
  // display a status message. Note that we don't display a message if only
  // goScoreCalculationStarts is received, but no
  // askGtpEngineForDeadStonesStarts is received. The reason is that the actual
  // score calculations is quite fast, even on an older device such as an
  // iPhone 3GS, so an update for goScoreCalculationStarts would be followed
  // almost immediately by another update for goScoreCalculationEnds, which
  // might cause flickering.
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #askGtpEngineForDeadStonesEnds notifications.
// -----------------------------------------------------------------------------
- (void) askGtpEngineForDeadStonesEnds:(NSNotification*)notification
{
  self.activityIndicatorNeedsUpdate = true;
  // No label update here, the "scoring in progress..." message must remain
  // until goScoreCalculationEnds is received.
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #boardViewDidChangeCrossHair notifications.
// -----------------------------------------------------------------------------
- (void) boardViewDidChangeCrossHair:(NSNotification*)notification
{
  NSArray* crossHairInformation = notification.object;
  if (crossHairInformation.count > 0)
    self.crossHairInformation = [NSArray arrayWithArray:crossHairInformation];
  else
    self.crossHairInformation = nil;
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #longRunningActionEnds notification.
// -----------------------------------------------------------------------------
- (void) longRunningActionEnds:(NSNotification*)notification
{
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  self.statusLabelNeedsUpdate = true;
  [self delayedUpdate];
}

@end
