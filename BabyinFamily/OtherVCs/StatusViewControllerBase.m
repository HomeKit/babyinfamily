//
//  StatusViewControllerBase.m
//  zjtSinaWeiboClient
//
//  Created by 范艳春 on 12-11-27.
//
//

#import "StatusViewControllerBase.h"
#import "CellHeaderView.h"
#import "TakePhotoViewController.h"

#define kTextViewPadding            16.0
#define kLineBreakMode              UILineBreakModeWordWrap
#define HEADER_HEIGHT 48


@interface StatusViewControllerBase()
-(void)setup;
@end

@implementation StatusViewControllerBase
{
    BabyFullScreenScroll *_babyFullScreenScroll;
}
@synthesize table;
@synthesize statusCellNib;
@synthesize statuesArr;
@synthesize headDictionary;
@synthesize imageDictionary;
@synthesize browserView;

-(void)dealloc
{
    self.headDictionary = nil;
    self.imageDictionary = nil;
    self.statusCellNib = nil;
    self.statuesArr = nil;
    self.browserView = nil;
    _refreshHeaderView=nil;
    [table release];table = nil;
    [super dealloc];
}

-(void)setup
{
    self.title = @"主页";
    NSString *fullpath = [NSString stringWithFormat:@"sourcekit.bundle/image/%@", @"tabbar_home"];
    self.tabBarItem.image = [UIImage imageNamed:fullpath];
    
    
    CGRect frame = table.frame;
    frame.size.height = frame.size.height + REFRESH_FOOTER_HEIGHT;
    table.frame = frame;
    
    //init data
    isFirstCell = YES;
    shouldLoad = NO;
    shouldShowIndicator = YES;
    manager = [WeiBoMessageManager getInstance];
    defaultNotifCenter = [NSNotificationCenter defaultCenter];
    headDictionary = [[NSMutableDictionary alloc] init];
    imageDictionary = [[NSMutableDictionary alloc] init];
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self != nil) {
        [self setup];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setup];
    }
    return self;
}

-(UINib*)statusCellNib
{
    if (statusCellNib == nil)
    {
        [statusCellNib release];
        statusCellNib = [[StatusCell nib] retain];
    }
    return statusCellNib;
}

-(void)setUpRefreshView
{
    if (_refreshHeaderView == nil) {
		
		EGORefreshTableHeaderView *view = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
		view.delegate = self;
		[self.tableView addSubview:view];
		_refreshHeaderView = [view retain];
		[view release];
		
	}
	
	//  update the last update date
	[_refreshHeaderView refreshLastUpdatedDate];
}

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0, 0, 0);
    [self.navigationController.view layoutSubviews];
    [self setUpRefreshView];
    self.tableView.contentInset = UIEdgeInsetsOriginal;
    
    NSLog(@" sts base table = %@,delegate = %@",self.tableView,self.tableView.delegate);
    NSLog(@"navigation is height %f",self.navigationController.navigationBar.frame.size.height);
    [defaultNotifCenter addObserver:self selector:@selector(getAvatar:)         name:HHNetDataCacheNotification object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(mmRequestFailed:)   name:MMSinaRequestFailed object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(loginSucceed)       name:DID_GET_TOKEN_IN_WEB_VIEW object:nil];
    _babyFullScreenScroll = [[BabyFullScreenScroll alloc] initWithViewController:self];
    //self.tableView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0, 0, 0);

    _babyFullScreenScroll.shouldShowUIBarsOnScrollUp = YES;
    
}

-(void)viewDidUnload
{
    [defaultNotifCenter removeObserver:self name:HHNetDataCacheNotification object:nil];
    [defaultNotifCenter removeObserver:self name:MMSinaRequestFailed        object:nil];
    [defaultNotifCenter removeObserver:self name:DID_GET_TOKEN_IN_WEB_VIEW  object:nil];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.toolbarItems.copy > 0) {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.toolbarItems.count > 0) {
        [self.navigationController setToolbarHidden:NO animated:animated];
    }
    
    [_babyFullScreenScroll layoutTabBarController];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

#pragma mark - Methods
-(void)loginSucceed
{
    shouldLoad = YES;
}

//异步加载图片
-(void)getImages
{
    //得到文字数据后，开始加载图片
    for(int i=0;i<[statuesArr count];i++)
    {
        Status * member=[statuesArr objectAtIndex:i];
        NSNumber *indexNumber = [NSNumber numberWithInt:i];
        
        //下载头像图片
        [[HHNetDataCacheManager getInstance] getDataWithURL:member.user.profileImageUrl withIndex:i];
        
        //下载博文图片
        if (member.bmiddlePic && [member.bmiddlePic length] != 0)
        {
            [[HHNetDataCacheManager getInstance] getDataWithURL:member.bmiddlePic withIndex:i];

        }
        else
        {
            [imageDictionary setObject:[NSNull null] forKey:indexNumber];
            //statuesArr[i].frame
        }
        
        //下载转发的图片
        if (member.retweetedStatus.bmiddlePic && [member.retweetedStatus.bmiddlePic length] != 0)
        {
            [[HHNetDataCacheManager getInstance] getDataWithURL:member.retweetedStatus.bmiddlePic withIndex:i];
        }
        else
        {
            [imageDictionary setObject:[NSNull null] forKey:indexNumber];
        }
    }
}

//得到图片
-(void)getAvatar:(NSNotification*)sender
{
    NSDictionary * dic = sender.object;
    NSString * url          = [dic objectForKey:HHNetDataCacheURLKey];
    NSNumber *indexNumber   = [dic objectForKey:HHNetDataCacheIndex];
    NSInteger index         = [indexNumber intValue];
    NSData *data            = [dic objectForKey:HHNetDataCacheData];
    
    //当下载大图过程中，后退，又返回，如果此时收到大图的返回数据，会引起crash，在此做预防。
    if (indexNumber == nil || index == -1) {
        NSLog(@"status indexNumber = nil");
        return;
    }
    
    if (index >= [statuesArr count]) {
        NSLog(@"statues arr error ,index = %d,count = %d",index,[statuesArr count]);
        return;
    }
    
    Status *sts = [statuesArr objectAtIndex:index];
    User *user = sts.user;    
    //得到的是头像图片
    if ([url isEqualToString:user.profileImageUrl])
    {
        UIImage * image     = [UIImage imageWithData:data];
       user.avatarImage    = image;
        
        [headDictionary setObject:data forKey:indexNumber];
    }    
    //得到的是博文图片
    if([url isEqualToString:sts.bmiddlePic])
    {
        [imageDictionary setObject:data forKey:indexNumber];
    
         
    }
    //得到的是转发的图片
    if (sts.retweetedStatus && ![sts.retweetedStatus isEqual:[NSNull null]])
    {
        if ([url isEqualToString:sts.retweetedStatus.bmiddlePic])
        {
            [imageDictionary setObject:data forKey:indexNumber];
        }
    }
    
    //reload table
    NSIndexPath *indexPath  = [NSIndexPath indexPathForRow:0 inSection:index];
    NSArray     *arr        = [NSArray arrayWithObject:indexPath];
    [table reloadRowsAtIndexPaths:arr withRowAnimation:NO];
    [self.tableView reloadRowsAtIndexPaths:arr withRowAnimation:NO];
}

-(void)mmRequestFailed:(id)sender
{
    [self stopLoading];
    [self doneLoadingTableViewData];
    [[SHKActivityIndicator currentIndicator] hide];
    //[[BabyAlertWindow getInstance] hide];
}

//上拉刷新
-(void)refresh
{
    [manager getHomeLine:-1 maxID:-1 count:-1 page:-1 baseApp:1 feature:2];
    [[SHKActivityIndicator currentIndicator] displayActivity:@"正在载入..." inView:self.view];
    //[[BabyAlertWindow getInstance] showWithString:@"正在载入，请稍后..."];
}

//计算text field 的高度。
-(CGFloat)cellHeight:(NSString*)contentText with:(CGFloat)with
{
    UIFont * font=[UIFont  systemFontOfSize:14];
    CGSize size=[contentText sizeWithFont:font constrainedToSize:CGSizeMake(with - kTextViewPadding, 300000.0f) lineBreakMode:kLineBreakMode];
    CGFloat height = size.height;
    return height ;//= 200.0f;
}

- (id)cellForTableView:(UITableView *)tableView fromNib:(UINib *)nib {
    static NSString *cellID = @"StatusCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        NSLog(@"statuss cell new");
        NSArray *nibObjects = [nib instantiateWithOwner:nil options:nil];
        cell = [nibObjects objectAtIndex:0];
    }
    else {
        [(LPBaseCell *)cell reset];
    }
    
    return cell;
}

#pragma mark - UITableViewDataSource
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (statuesArr == nil) {
        return 0;
    }
    return self.statuesArr.count;
    NSLog(@"cellForRowAtIndexPath error count = %d",[statuesArr count]);

}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (statuesArr == nil) {
        return 0;
    }
    return 1;
}

//add cellHeaderView to section
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    CellHeaderView *headview= [[CellHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, HEADER_HEIGHT)];
    
    if (section >= [statuesArr count]) {
        NSLog(@"cellForRowAtIndexPath error ,index = %d,count = %d",section,[statuesArr count]);
        return headview;
    }
    NSData *data = [headDictionary objectForKey:[NSNumber numberWithInt:section]];
    Status *status = [statuesArr objectAtIndex:section];
    [headview setupHeaderView:status avatarImageData:data];
    return headview;
}

//add statusCell to sectionrows
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger  row = indexPath.section;
    StatusCell *cell = [self cellForTableView:tableView fromNib:self.statusCellNib];
    if (row >= [statuesArr count]) {
        NSLog(@"cellForRowAtIndexPath error ,index = %d,count = %d",row,[statuesArr count]);
        return cell;
    }
    NSData *imageData = [imageDictionary objectForKey:[NSNumber numberWithInt:[indexPath section]]];
   // NSData *avatarData = [headDictionary objectForKey:[NSNumber numberWithInt:[indexPath section]]];
    Status *status = [statuesArr objectAtIndex:row];
    cell.delegate = self;
    cell.cellIndexPath = indexPath;
    [cell setupCell:status contentImageData:imageData];

    //开始绘制第一个cell时，隐藏indecator.
    if (isFirstCell) {
        [[SHKActivityIndicator currentIndicator] hide];
       // [[BabyAlertWindow getInstance] hide];
        isFirstCell = NO;
    }
    return cell;
}


#pragma mark - UITableViewDelegate
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger  row = indexPath.section;
    
    if (row >= [statuesArr count])
    {
        NSLog(@"heightForRowAtIndexPath error ,index = %d,count = %d",row,[statuesArr count]);
        return 1;
    }
    
    Status *status          = [statuesArr objectAtIndex:row];
    NSString *url = status.bmiddlePic;
    StatusCell *cell = [self cellForTableView:tableView fromNib:self.statusCellNib];
    NSData *imageData = [imageDictionary objectForKey:[NSNumber numberWithInt:[indexPath section]]];
    CGFloat height = 0.0f;
    
    //
    if (url && [url length] != 0)
    {
        height = [cell setCellHeight: status contentImageData:imageData];
        NSLog(@"hight is %f",height);
    }
    return height;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return HEADER_HEIGHT;
}


 -(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger  row = indexPath.section;
    if (row >= [statuesArr count]) {
        NSLog(@"didSelectRowAtIndexPath error ,index = %d,count = %d",row,[statuesArr count]);
        return ;
    }
    
    ZJTDetailStatusVC *detailVC = [[ZJTDetailStatusVC alloc] initWithNibName:@"ZJTDetailStatusVC" bundle:nil];
    Status *status  = [statuesArr objectAtIndex:row];
    detailVC.status = status;
    
    NSData *data = [headDictionary objectForKey:[NSNumber numberWithInt:[indexPath section]]];
    detailVC.avatarImage = [UIImage imageWithData:data];
    
    NSData *imageData = [imageDictionary objectForKey:[NSNumber numberWithInt:[indexPath section]]];
    if (![imageData isEqual:[NSNull null]])
    {
        detailVC.contentImage = [UIImage imageWithData:imageData];
    }
    detailVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:detailVC animated:YES];
    [detailVC release];
   [_babyFullScreenScroll showUIBarsWithScrollView:tableView animated:YES];
}

#pragma mark - StatusCellDelegate

-(void)browserDidGetOriginImage:(NSDictionary*)dic
{
    NSString * url=[dic objectForKey:HHNetDataCacheURLKey];
    if ([url isEqualToString:browserView.bigImageURL])
    {
        [[SHKActivityIndicator currentIndicator] hide];
        //        [[ZJTStatusBarAlertWindow getInstance] hide];
        shouldShowIndicator = NO;
        
        UIImage * img=[UIImage imageWithData:[dic objectForKey:HHNetDataCacheData]];
        [browserView.imageView setImage:img];
        
        NSLog(@"big url = %@",browserView.bigImageURL);
        if ([browserView.bigImageURL hasSuffix:@".gif"])
        {
            UIImageView *iv = browserView.imageView; // your image view
            CGSize imageSize = iv.image.size;
            CGFloat imageScale = fminf(CGRectGetWidth(iv.bounds)/imageSize.width, CGRectGetHeight(iv.bounds)/imageSize.height);
            CGSize scaledImageSize = CGSizeMake(imageSize.width*imageScale, imageSize.height*imageScale);
            CGRect imageFrame = CGRectMake(floorf(0.5f*(CGRectGetWidth(iv.bounds)-scaledImageSize.width)), floorf(0.5f*(CGRectGetHeight(iv.bounds)-scaledImageSize.height)), scaledImageSize.width, scaledImageSize.height);
            
            GifView *gifView = [[GifView alloc]initWithFrame:imageFrame data:[dic objectForKey:HHNetDataCacheData]];
            
            gifView.userInteractionEnabled = NO;
            gifView.tag = GIF_VIEW_TAG;
            [browserView addSubview:gifView];
            [gifView release];
        }
    }
}

-(void)cellImageDidTaped:(StatusCell *)theCell image:(UIImage *)image
{
    shouldShowIndicator = YES;
    
    if ([theCell.cellIndexPath section] > [statuesArr count]) {
        NSLog(@"cellImageDidTaped error ,index = %d,count = %d",[theCell.cellIndexPath row],[statuesArr count]);
        return ;
    }
    
    Status *sts = [statuesArr objectAtIndex:[theCell.cellIndexPath section]];
    BOOL isRetwitter = sts.retweetedStatus && sts.retweetedStatus.originalPic != nil;
    UIApplication *app = [UIApplication sharedApplication];
    
    CGRect frame = CGRectMake(0, 0, 320, 480);
    if (browserView == nil) {
        self.browserView = [[[ImageBrowser alloc]initWithFrame:frame] autorelease];
        [browserView setUp];
    }
    
    browserView.image = image;
    browserView.theDelegate = self;
    browserView.bigImageURL = isRetwitter ? sts.retweetedStatus.originalPic : sts.originalPic;
    [browserView loadImage];
    
    app.statusBarHidden = YES;
    UIWindow *window = nil;
    for (UIWindow *win in app.windows) {
        if (win.tag == 0) {
            [win addSubview:browserView];
            window = win;
            [window makeKeyAndVisible];
        }
    }
    
    if (shouldShowIndicator == YES && browserView) {
        [[SHKActivityIndicator currentIndicator] displayActivity:@"正在载入..." inView:browserView];
        //        [[ZJTStatusBarAlertWindow getInstance] showWithString:@"正在载入，请稍后..."];
    }
    else shouldShowIndicator = YES;
}

#pragma mark -
#pragma mark  - Data Source Loading / Reloading Methods

- (void)reloadTableViewDataSource{
	_reloading = YES;
}

//调用此方法来停止。
- (void)doneLoadingTableViewData{
	
	//  model should call this when its done loading
	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
	
}


#pragma mark -
#pragma mark UIScrollViewDelegate Methods
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [_babyFullScreenScroll scrollViewWillBeginDragging:scrollView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{    
    if (scrollView.contentOffset.y < 200) {
        [_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
    }
    else
        [super scrollViewDidScroll:scrollView];
    [_babyFullScreenScroll scrollViewDidScroll:scrollView];

}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    return [_babyFullScreenScroll scrollViewShouldScrollToTop:scrollView];
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
    [_babyFullScreenScroll scrollViewDidScrollToTop:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    
    if (scrollView.contentOffset.y < 200)
    {
        [_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
    }
    else
        [super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}


#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view{
    _reloading = YES;
	[manager getHomeLine:-1 maxID:-1 count:-1 page:-1 baseApp:1 feature:2];
        [[SHKActivityIndicator currentIndicator] displayActivity:@"正在载入..." inView:self.view];
   // [[BabyAlertWindow getInstance] showWithString:@"正在载入，请稍后..."];
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view{
	
	return _reloading; // should return if data source model is reloading
	
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view{
	
	return [NSDate date]; // should return date data source was last changed
	
}
- (void)photoEditorCanceled:(TakePhotoViewController *)editor
{
    // Handle cancelation here
    [self dismissModalViewControllerAnimated:YES];
}


@end
