# Account Viewer for iPad #

Account Viewer is a free, full-featured open-source native iPad app written in Objective-C and Cocoa. Account Viewer is the easiest way to browse your Accounts in any Salesforce environment and read news headlines tailored to them. Store your most important Accounts locally for secure offline access. Account Viewer has robust encrypted local account functionality and does not require you ever connect it to a Salesforce org.

Account Viewer was available on the Apple App Store for a few months in late 2011 but has since been replaced by Salesforce Viewer. Salesforce Viewer is (or will shortly be) [available free on the App Store](http://itunes.apple.com/us/app/salesforce-viewer/id458454196?ls=1&mt=8) and will also be on Github.

by [Jonathan Hersh](mailto:jhersh@salesforce.com).

This document is intended to introduce you to the app's architecture and design and make it as easy as possible for you to jump in, run it, and start contributing.

Account Viewer's source is [freely available on GitHub](https://github.com/ForceDotComLabs/Account-Viewer).

In this document:

- Release History
- Account Viewer License
- Authentication and Security
- Getting Started
- App Architecture
- External APIs
- Third-party Code

## Release History ##

New in v1.1 (October 12, 2011)

- Related Lists! Browse all related lists on your Account layout and tap individual related records to view full related record detail!
- Share any article or URL to Chatter! With any webpage open, tap the action link and choose 'Share to Chatter'.
- Browse up to 50,000 owned accounts in the "My Accounts" list.
- Full support for rich text fields, including links and images!
- Numerous other tweaks, fixes, and performance improvements.

New in v1.0.1 (September 8, 2011)

- Fixes an issue where some users were unable to view any remote account if they didn't have field-level security access to one of the four overview fields on Account (Name, Phone, Website, Industry)
- Corrected display of decimal fields to properly match their formatting on salesforce.com
- Better validation on custom login host endpoints
- Preliminary support for rich text fields
- Numerous spacing/sizing/alignment fixes and other minor corrections

New in v1.0 (August 25, 2010) 

- Initial Release

## Account Viewer License ##

Copyright (c) 2011, salesforce.com, inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided 
that the following conditions are met:
 
- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution. 
- Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Authentication and Security ##

Almost all interaction with Salesforce web services is accomplished through the `zksForce` library with the exception of the OAuth flow in the `OAuthViewController` class. By default, the app uses OAuth for all authentication, but there is built-in support for a hardcoded username/password as well - this is left in largely for testing purposes and to enable you to get up and running without setting up OAuth.

Local Accounts and OAuth refresh tokens are encrypted into the device's keychain. Remote accounts, page layouts, and Account sObject describes are cached in-memory and cleared upon logout.

Some data (Account names and addresses) are sent to third-party APIs to provide app functionality, but always over HTTPS. More details below in the API section.

Other app details (first-run settings, other app preferences) are stored in `NSUserDefaults`.

## Getting Started ##

1. Grab the Account Viewer source code: `git clone https://github.com/ForceDotComLabs/Account-Viewer.git`
2. Choose either OAuth or a hardcoded username/password for your login method. 

	For OAuth, create a new Remote Access application (Setup -> Develop -> Remote Access) and copy your OAuth Client ID into the `OAuthClientID` variable in `RootViewController.h`. Then, set the `useClientLogin` variable in `RootViewController.m` to `NO`.

	For client login with a hardcoded username/password, enter your credentials into the `clientUserName` and `clientPassword` variables in `RootViewController.m`. Then, set the `useClientLogin` variable in `RootViewController.m` to `YES`.

3. If you have a Google API key, paste it into `RecordNewsViewController.h` under `NEWS_API_KEY`.
4. Build and run, and you should be good to go!
5. If you're getting build warnings/errors akin to "Multiple build commands for output file...", you'll need to remove the .git directory from your project. See [this answer](http://stackoverflow.com/questions/2718246/xcode-strange-warning-multiple-build-commands-for-output-file) for more detail.

## App Architecture ##

When the app first loads, it evaluates whether it has a stored OAuth refresh token from a previous authentication. If so, it attempts to refresh the SFDC session with that refresh token. See `appFinishedLaunching` in `RootViewController.m`. If there is no stored refresh token, or if the refresh fails for any reason, the app destroys all session data and places itself in offline Local Accounts mode. 

The left-side navigation view (in landscape mode, also visible in portrait mode in a popover when you tap the 'Accounts' button), a.k.a. the Master view, is powered by the `SubNavViewController` class. The `RootViewController` initializes three instances of `SubNavViewController` - Local Accounts, My Accounts, and Accounts I Follow - and stacks them on top of each other in the Master view. You can switch between them by tapping on the `SubNavViewController`'s name in the upper left. If the user does not have a valid SFDC session, only Local Accounts are accessible and attempting to switch to any of the others will show a login screen.

The right-side view is powered by the `DetailViewController`. It serves mostly as a container for the rest of the app's content and is responsible for creating, managing, and destroying Flying Windows. It also ensures that Flying Windows cannot be dragged off the screen, and it is responsible for applying inertial dragging when Flying Windows are moved as well as the overall management of the Flying Window stack.

The various interactive, draggable panes that fill the `DetailViewController` - the record overview pane, news results pane, web view pane, list of related lists, related record grid, and related record views - are termed Flying Windows and each is a subclass of the `FlyingWindowController` class. They are, respectively, `RecordOverviewController`, `RecordNewsViewController`, `WebViewController`, `ListOfRelatedListsViewController`, `RelatedListGridView`, and `RelatedRecordViewController`. The `FlyingWindowController` base class defines some basics about its look and enables it to be dragged about the screen.

`RecordOverviewController` is responsible for displaying a selected Account's record overview (Name, Industry, Phone, Website), rendering the Account's location on a map, and rendering the full record page layout for the Account.

`RecordNewsViewController` is responsible for querying Google News (over HTTPS) and displaying news stories about a single Account or a list of Accounts (if no single Account has yet been selected). 

`WebViewController` is a simple `UIWebView` with a few added pieces of functionality, like being able to email the link to the open page, copy its URL, open in Safari, and expand the webview to full-screen.

`ListOfRelatedListsViewController` lists all of the related lists on an Account. The list ordering as well as which lists appear is determined by your Account page layout. This view controller also chains subqueries together to display the number of related records on each list before you tap one.

`RelatedListGridView` displays the related records on an Account for a given related object. The columns displayed on the grid are determined by your Account page layout. Related record grids have tap-to-sort columns and tapping an individual record's name will open its full detail.

`RelatedRecordViewController` renders the full two-column layout for a related record. It supports any layoutable object, standard and custom alike.

`FieldPopoverButton` is a generic `UIButton` intended to display the value of an sObject field. All `FieldPopoverButton`s can be tapped to copy the text value of that field, but depending on the field type, some may have additional actions. For example, a `FieldPopoverButton` displaying an address will offer to open the address in Google Maps, phone/email fields will offer to call with Facetime or Skype, and lookups to User will display a full-featured user profile with a photo and other details from the User record.

`CommButton` is a generic `UIButton` intended to make it easy to Email, Skype, Facetime, or open the website for any field on the sObject. If an Account page layout has three fields of type Phone, for example, a `CommButton` of type Skype, when tapped, will allow you to place a Skype call to any of those three phone numbers.

`FollowButton` is a generic `UIBarButtonItem` intended to make it easy to create a follow/unfollow toggle between the running user and any other chatter-enabled object (User, Account, etc). 

`ChatterPostController` is the main interface for sharing an article or URL to chatter. It's geared mostly around sharing links, so while linkUrl and title are not traditionally required fields in a Chatter post, they are required here.

`ObjectLookupController` is a lookup box launched when you tap the 'Post To' field in the `ChatterPostController`. It allows you to search for a User, Chatter Group, or Account (if Accounts are chatter-enabled in the current environment). 

`AccountUtil` is a singleton, a general utility class that encapsulates many common functions used throughout the application. `AccountUtil` handles metadata operations, like querying and processing sObject describes, page layouts, as well as rendering the full record page layout for an Account. `AccountUtil` is also responsible for all local database operations for local accounts, processing sObject fields, various string manipulation utility functions, managing the network activity indicator, logging app errors, and other miscellaneous operations like determining the current IP address.

## External APIs ##

Account Viewer makes use of several external APIs.

- [Google's Geocoding API](http://code.google.com/apis/maps/documentation/geocoding/) allows Account Viewer to convert an account street address into a latitude/longitude coordinate pair for display on a map. 
- [Google's News Search API](http://code.google.com/apis/newssearch/) provides news articles, images, bylines, and article summaries. Google deprecated this API on May 26, 2011, but it will remain operational for at least 2.5-3 years after that date. At some point, Account Viewer will likely need to transition to a different news API.

Account Viewer uses HTTPS when communicating with these APIs, so no user or account data should ever be traveling in the clear.

## Third-party Code ##

Account Viewer makes use of a number of third-party components:

- [zksForce](https://github.com/superfell/zkSforce), a Cocoa library for calling the Salesforce Web Services APIs.
- Various components from Matt Drance's excellent [iOS Recipes book](http://pragprog.com/book/cdirec/ios-recipes).
- [DSActivityView](http://www.dejal.com/developer/dsactivityview) for loading and authentication indicators.
- [MGSplitViewController](http://mattgemmell.com/2010/07/31/mgsplitviewcontroller-for-ipad), a modified split view that powers the app's main interface.
- [JSON-Framework](https://github.com/stig/json-framework/), a JSON parser for objective-C.
- [InAppSettingsKit](http://inappsettingskit.com/) for in-app and Settings.app settings.
- [SynthesizeSingleton](http://cocoawithlove.com/2008/11/singletons-appdelegates-and-top-level.html)
- [AQGridView](https://github.com/AlanQuatermain/AQGridView), a grid layout system used in the Account record overview.
- [PullRefreshTableViewController](https://github.com/leah/PullToRefresh), an easy way to add pull-to-refresh to most any table.