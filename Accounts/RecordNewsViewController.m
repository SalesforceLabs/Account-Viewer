/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh@salesforce.com
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "RecordNewsViewController.h"
#import "RootViewController.h"
#import "DetailViewController.h"
#import "WebViewController.h"
#import "NewsTableViewCell.h"
#import "JSON-Framework/JSON.h"
#import <QuartzCore/QuartzCore.h>
#import "DSActivityView.h"
#import "PRPAlertView.h"
#import "ListOfRelatedListsViewController.h"

@implementation RecordNewsViewController

@synthesize newsTableViewController, newsConnection, jsonArticles, imageRequests, noNewsView, newsSearchTerm, sourceLabel;

#pragma mark - init, layout, setup

- (id) initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) {   
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.png"]];
        
        if( !self.noNewsView ) {
            self.noNewsView = [[[UIView alloc] initWithFrame:CGRectMake( 0, 0, frame.size.width, 300 )] autorelease];
            self.noNewsView.backgroundColor = [UIColor clearColor];
            self.noNewsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            
            float curY = 0.0f;
            
            UIButton *noNewsButton = [UIButton buttonWithType:UIButtonTypeCustom];
            noNewsButton.titleLabel.numberOfLines = 0;
            noNewsButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
            [noNewsButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
            noNewsButton.titleLabel.textAlignment = UITextAlignmentCenter;
            [noNewsButton.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:28]];
            [noNewsButton setTitle:NSLocalizedString(@"No News — Tap to Refresh", @"No news label") forState:UIControlStateNormal];
            noNewsButton.backgroundColor = [UIColor clearColor];
            [noNewsButton addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventTouchUpInside];
            noNewsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            
            CGSize s = [[noNewsButton titleForState:UIControlStateNormal] sizeWithFont:noNewsButton.titleLabel.font
                                                                     constrainedToSize:CGSizeMake( frame.size.width - 20, 999 )];
            s.width = frame.size.width - 20;
            
            [noNewsButton setFrame:CGRectMake( 10, curY, s.width, s.height )];
            [self.noNewsView addSubview:noNewsButton];
            curY += noNewsButton.frame.size.height + 45;
            
            [self.noNewsView setFrame:CGRectMake( 0, lroundf( ( frame.size.height - self.navBar.frame.size.height - curY ) / 2.0f ), 
                                                  frame.size.width, curY )];
                        
            [self.view addSubview:self.noNewsView];
        }
        
        imageRequests = [[NSMutableArray alloc] init];
        imageCells = [[NSMutableDictionary alloc] init];
        
        isCompoundNewsView = NO;        
        isLoadingNews = NO;
        resultStart = 0;
    }
    
    return self;
}

- (void) setCompoundNewsView:(BOOL) cnv {
    isCompoundNewsView = cnv;
}

- (void) layoutView {
    if( !self.newsTableViewController )
        return;
            
    for( id cell in [self.newsTableViewController.tableView visibleCells] ) {
        [cell setCellWidth:(self.newsTableViewController.tableView.frame.size.width - 35)];
        [cell layoutCell];
    }
}

- (CGSize) maxImageSize {
    return CGSizeMake( 80, 100 );
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void) dealloc {
    [jsonArticles release];
    [newsConnection release];
    [imageCells release];
    [newsSearchTerm release];
    [newsTableViewController release];
    [sourceLabel release];
    [noNewsView release];
    [super dealloc];
}

#pragma mark - adding and removing the news table

- (void) addTableView {
    if( !self.newsTableViewController ) {
        PullRefreshTableViewController *ntvc = [[PullRefreshTableViewController alloc] initWithStyle:UITableViewStyleGrouped useHeaderImage:YES];
        
        ntvc.tableView.delegate = self;   
        ntvc.tableView.dataSource = self;
        ntvc.tableView.delaysContentTouches = YES;
        ntvc.tableView.canCancelContentTouches = YES;
        ntvc.tableView.separatorColor = UIColorFromRGB(0x999999);
        ntvc.tableView.backgroundColor = [UIColor clearColor];
        ntvc.tableView.backgroundView = nil;
            
        self.newsTableViewController = ntvc;
        [ntvc release];
                
        // Size our tableview        
        [self.newsTableViewController.view setFrame:CGRectMake( 0, 
                                                               self.navBar.frame.size.height,
                                                               self.view.frame.size.width, 
                                                               self.view.frame.size.height - self.navBar.frame.size.height)];
        
        self.sourceLabel = [[[UILabel alloc] initWithFrame:CGRectMake( 0, 0, self.newsTableViewController.view.frame.size.width, 20)] autorelease];
        sourceLabel.text = NSLocalizedString(@"Powered by Google News", @"Google news attribution");
        sourceLabel.backgroundColor = [UIColor clearColor];
        sourceLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:13];
        sourceLabel.textAlignment = UITextAlignmentCenter;
        sourceLabel.textColor = [UIColor darkGrayColor];
        sourceLabel.shadowColor = [UIColor whiteColor];
        sourceLabel.shadowOffset = CGSizeMake(0, 1);
        sourceLabel.numberOfLines = 1;
        
        self.newsTableViewController.tableView.tableHeaderView = sourceLabel;
        
        [self.view addSubview:self.newsTableViewController.view];
    }
    
    resultStart = 0;
    isLoadingNews = NO;
    noNewsView.hidden = YES;
        
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(layoutView)
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
}

- (void) removeTableView {
    if( self.newsTableViewController ) {
        [self.newsTableViewController.view removeFromSuperview];
        self.newsTableViewController = nil;
    }
    
    noNewsView.hidden = NO;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self 
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
}

#pragma mark - performing news search

- (void) setSearchTerm:(NSString *)st {
    if( !st )
        return;
    
    self.newsSearchTerm = st;
    
    [imageCells removeAllObjects];    
    resultStart = 0;
    isLoadingNews = NO;

    [self refresh:YES];
}

- (void) stopLoading {
    if( self.newsConnection ) {
        [self.newsConnection stop];
        [[AccountUtil sharedAccountUtil] endNetworkAction];
        self.newsConnection = nil;
    }
    
    // If we are loading images for those articles, stop those too
    if( imageRequests && [imageRequests count] > 0 ) {
        for( id request in imageRequests ) {
            [request stop];
            [[AccountUtil sharedAccountUtil] endNetworkAction];
        }
    
        [imageRequests removeAllObjects];
    }
    
    // clear out our cell cache
    if( imageCells ) {
        [imageCells release], imageCells = nil;
        imageCells = [[NSMutableDictionary alloc] init];
    }
}

- (void) updateVisibleCells {   
    // Refresh the data in each of our visible cells
    for( int x = 0; x < [[self.newsTableViewController.tableView visibleCells] count]; x++ ) {
        id cell = [[self.newsTableViewController.tableView visibleCells] objectAtIndex:x];
        int row = [self.newsTableViewController.tableView indexPathForCell:cell].section;
        
        if( row >= [jsonArticles count] )
            continue;
        
        [cell setArticle:[jsonArticles objectAtIndex:row]];
        
        // Add this cell to our image cache, to be updated later
        if( [[jsonArticles objectAtIndex:row] objectForKey:@"image"] ) {
            NSString *img = [[jsonArticles objectAtIndex:row] valueForKeyPath:@"image.url"];
            
            [imageCells setObject:cell forKey:img];
            [cell setArticleImage:[[AccountUtil sharedAccountUtil] userPhotoFromCache:img]];
        } else
            [cell setArticleImage:nil];
        
        [cell layoutCell];
    }

    [self.newsTableViewController.tableView reloadData];
    [self.newsTableViewController stopLoading];
}

- (void) refresh:(BOOL)resetRefresh { 
    if( isLoadingNews )
        return;
    
    if( resetRefresh ) {
        resultStart = 0;
        [jsonArticles removeAllObjects];
    }
    
    // Google returns a max of 64 results.
    // http://code.google.com/apis/newssearch/v1/jsondevguide.html#request_format
    if( resultStart >= 64 || ( estimatedArticles > 0 && resultStart >= estimatedArticles ) )
        return;
    
    [self stopLoading];     
    noNewsView.hidden = YES;
    
    if( self.newsTableViewController ) {
        CGRect r = self.newsTableViewController.tableView.tableFooterView.frame;
        r.size.height = 90;
        
        [self.newsTableViewController.tableView.tableFooterView setFrame:r];
    }
    
    UINavigationItem *loading = [[UINavigationItem alloc] initWithTitle:NSLocalizedString(@"Loading...", @"Loading...")];
    loading.hidesBackButton = YES;
    
    if( self.navBar.topItem.leftBarButtonItem )
        loading.leftBarButtonItem = self.navBar.topItem.leftBarButtonItem;
    
    [self.navBar pushNavigationItem:loading animated:NO];
    [loading release];
    
    NSString *newsURL = [NEWS_ENDPOINT stringByAppendingFormat:@"&q=%@&rsz=8&userip=%@&hl=%@&start=%i&key=%@%@", 
                           [[AccountUtil trimWhiteSpaceFromString:newsSearchTerm] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                           [AccountUtil getIPAddress],
                           [[NSLocale preferredLanguages] objectAtIndex:0],
                           resultStart,
                           NEWS_API_KEY,
                           ( [[[NSUserDefaults standardUserDefaults] stringForKey:@"news_sort_by"] isEqualToString:@"Date"] ? @"&scoring=d" : @"" )
                         ];
    
    NSLog(@"NEWS SEARCH '%@' with URL %@", newsSearchTerm, newsURL);
    
    // Block to be called when we receive a JSON google news response
    PRPConnectionCompletionBlock complete = ^(PRPConnection *connection, NSError *error) {
        [[AccountUtil sharedAccountUtil] endNetworkAction];
        isLoadingNews = NO;
        
        NSString *title = [NSString stringWithFormat:@"%@ %@", 
                           ( isCompoundNewsView ? NSLocalizedString(@"Account", @"Account") : newsSearchTerm ),
                           NSLocalizedString(@"News", @"News")];
        
        UINavigationItem *nav = [[[UINavigationItem alloc] initWithTitle:title] autorelease];
        nav.hidesBackButton = YES;
        
        if( self.detailViewController.recordOverviewController &&
            self.subNavViewController.subNavTableType != SubNavLocalAccounts ) {
            ZKDescribeLayout *layout = [[AccountUtil sharedAccountUtil] layoutForRecord:self.account];
            
            if( layout && [layout relatedLists] && [[layout relatedLists] count] > 0 )
                nav.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Related Lists", nil)
                                                                           style:UIBarButtonItemStyleBordered
                                                                          target:self
                                                                          action:@selector(toggleRelatedLists)] autorelease];
        } else if( self.detailViewController.browseButton && !self.detailViewController.recordOverviewController && [RootViewController isPortrait] )
            nav.leftBarButtonItem = self.detailViewController.browseButton;
        else
            nav.leftBarButtonItem = nil;
        
        [self.navBar pushNavigationItem:nav animated:YES];
        
        if (error) {
            [self removeTableView];          
            return;
        } else {
            NSString *responseStr = [[NSString alloc] initWithData:connection.downloadData encoding:NSUTF8StringEncoding];
            
            //NSLog(@"received response %@", responseStr);
            
            SBJsonParser *jp = [[SBJsonParser alloc] init];
            NSDictionary *json = [jp objectWithString:responseStr];
            [responseStr release];
            [jp release];
            
            if( !json || [[json objectForKey:@"responseData"] isMemberOfClass:[NSNull class]] || [[json valueForKeyPath:@"responseData.results"] isMemberOfClass:[NSNull class]] ) {
                [self removeTableView];
                return;
            }
            
            NSArray *articles = [json valueForKeyPath:@"responseData.results"];
            
            if( jsonArticles )
                [jsonArticles addObjectsFromArray:articles];
            else                        
                jsonArticles = [[NSMutableArray arrayWithArray:articles] retain];
            
            if( !jsonArticles || [jsonArticles count] == 0 ) {
                [self removeTableView];
            } else {
                [self addTableView];
                
                NSString *est = [json valueForKeyPath:@"responseData.cursor.estimatedResultCount"];
                
                if( est )
                    estimatedArticles = [est intValue];
                                
                resultStart = [jsonArticles count];
                
                [self performSelector:@selector(updateVisibleCells) withObject:nil afterDelay:0.1];
                
                // Async fetch the images that appear in these articles
                [self performSelector:@selector(fetchImages) withObject:nil afterDelay:0.2];
            }
        }
    }; // END JSON response block
    
    // Initiate the download
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:newsURL]];
    [req addValue:[NSString stringWithFormat:@"Salesforce %@ for iPad", [AccountUtil appFullName]] forHTTPHeaderField:@"Referer"];
    
    self.newsConnection = [PRPConnection connectionWithRequest:req
                                             progressBlock:nil
                                           completionBlock:complete];
    [self.newsConnection start];
    isLoadingNews = YES;
    
    [[AccountUtil sharedAccountUtil] startNetworkAction];       
}

// kicks off async requests to load each image in this batch of articles
- (void) fetchImages {
    if( !jsonArticles || [jsonArticles count] == 0 )
        return;
        
    for( int x = 0; x < [jsonArticles count]; x++ )
        if( [[jsonArticles objectAtIndex:x] objectForKey:@"image"] ) {
            NSString *imgURL = [[[jsonArticles objectAtIndex:x] objectForKey:@"image"] objectForKey:@"url"];
            
            // Does this image already exist in our cache?
            UIImage *articleImage = [[AccountUtil sharedAccountUtil] userPhotoFromCache:imgURL];
            
            if( articleImage ) {
                // cache success
                
                NewsTableViewCell *cell = [imageCells objectForKey:imgURL];
                
                if( cell ) {
                    [cell setArticleImage:articleImage];
                    [cell layoutCell];      
                    
                    // redraw this row
                    [self.newsTableViewController.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:
                                                                                    [NSIndexPath indexPathForRow:0 inSection:cell.tag], 
                                                                                    nil] 
                                                                  withRowAnimation:UITableViewRowAnimationNone];
                }
            } else {
                // Spawn a new async request to download this article's image.           
                // Block to be called when this image download completes
                PRPConnectionCompletionBlock complete = ^(PRPConnection *connection, NSError *error) {
                    [[AccountUtil sharedAccountUtil] endNetworkAction];
                    
                    if( !error ) {                                       
                        UIImage *articlePhoto = [UIImage imageWithData:connection.downloadData];
                        
                        NSString *url = [connection.url absoluteString];
                        // Cache this image                        
                        [[AccountUtil sharedAccountUtil] addUserPhotoToCache:articlePhoto forURL:url];
                        
                        // set the cell's image
                        NewsTableViewCell *cell = [imageCells objectForKey:url];
                        
                        if( cell ) {                           
                            [cell setArticleImage:articlePhoto];
                            [cell layoutCell];
                        
                            // redraw this row
                            [self.newsTableViewController.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:
                                                                                            [NSIndexPath indexPathForRow:0 inSection:cell.tag], 
                                                                                            nil] 
                                                                          withRowAnimation:UITableViewRowAnimationNone];
                        }
                        
                        [imageRequests removeObject:connection];
                    }
                };
                
                // Initiate the download
                PRPConnection *conn = [PRPConnection connectionWithURL:[NSURL URLWithString:imgURL]
                                                         progressBlock:nil
                                                       completionBlock:complete];
                [conn start];            
                [[AccountUtil sharedAccountUtil] startNetworkAction];        
                
                // Save this connection along with which article will receive this image
                [imageRequests addObject:conn];
            }
        }
}

#pragma mark - related lists

- (void) toggleRelatedLists {    
    // Pop everything off after this list, then slide it offscreen
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:NO];
    [self slideFlyingWindowToPoint:CGPointMake( 1200, self.view.center.y )];
    
    [self performSelector:@selector(delayedLaunchRelatedLists)
               withObject:nil
               afterDelay:0.3];
}

- (void) delayedLaunchRelatedLists {
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
    [self.detailViewController addFlyingWindow:FlyingWindowListofRelatedLists withArg:nil];
}

#pragma mark - table view setup

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [jsonArticles count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NewsTableViewCell *cell = [NewsTableViewCell cellForTableView:tableView];
    
    cell.recordNewsViewController = self;
    cell.tag = indexPath.section;
    
    [cell setCellWidth:(tableView.frame.size.width - 50.0f)];
    
    if( !jsonArticles || [jsonArticles count] <= indexPath.section )
        return cell;
    
    NSDictionary *article = [jsonArticles objectAtIndex:indexPath.section];
    [cell setArticle:article];
    
    // If we have cached an image for this article, set it here
    if( [article objectForKey:@"image"] ) {
        [imageCells setObject:cell forKey:[article valueForKeyPath:@"image.url"]];
        [cell setArticleImage:[[AccountUtil sharedAccountUtil] userPhotoFromCache:[article valueForKeyPath:@"image.url"]]];
    } else
        [cell setArticleImage:nil];
    
    [cell layoutCell];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *articleURL = [[jsonArticles objectAtIndex:indexPath.section] objectForKey:@"unescapedUrl"];
        
    [self.detailViewController openWebView:articleURL];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {    
    float curY = 10, availableWidth = tableView.frame.size.width - 60;
    
    NSDictionary *article = [jsonArticles objectAtIndex:indexPath.section];
    UIImage *img = nil;
    NSString *bits = nil;
    CGSize s, imgSize, maxSize = [self maxImageSize];
    
    // headline
    bits = [article objectForKey:@"titleNoFormatting"];
    s = [bits sizeWithFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:22]
         constrainedToSize:CGSizeMake( availableWidth, 50 )
             lineBreakMode:UILineBreakModeWordWrap];
    
    curY += s.height + 5;
    
    // article source
    curY += 20;
    
    // article image
    if( [article objectForKey:@"image"] )
        img = [[AccountUtil sharedAccountUtil] userPhotoFromCache:[article valueForKeyPath:@"image.url"]];
    
    if( img ) {
        imgSize = img.size;
        
        if( imgSize.width > maxSize.width ) {
            double d = maxSize.width / imgSize.width;
            
            imgSize.width = maxSize.width;
            imgSize.height *= d;
        }
        
        if( imgSize.height > maxSize.height ) {
            double d = maxSize.height / imgSize.height;
            
            imgSize.height = maxSize.height;
            imgSize.width *= d;
        }
        
        availableWidth -= imgSize.width + 15;
    }
    
    // article content
    bits = [article objectForKey:@"content"];
    bits = [AccountUtil stripHTMLTags:bits];
    bits = [AccountUtil stringByDecodingEntities:bits];
    s = [bits sizeWithFont:[UIFont fontWithName:@"HelveticaNeue" size:14]
         constrainedToSize:CGSizeMake( availableWidth, 80 )
             lineBreakMode:UILineBreakModeWordWrap];
    
    curY += s.height + 10;  
    
    if( img && curY < 115 + imgSize.height )
        curY = imgSize.height + 115;
        
    return lroundf(curY);
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.newsTableViewController scrollViewDidScroll:scrollView];
    [self flyingWindowDidTap:nil];
    
    if ( !isLoadingNews && ([scrollView contentOffset].y + scrollView.frame.size.height) >= [scrollView contentSize].height )    
        [self refresh:NO];
}

- (void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.newsTableViewController scrollViewWillBeginDragging:scrollView];
}

- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.newsTableViewController scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

@end