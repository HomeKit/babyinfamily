//
//  OAuthWebView.m
//  test
//
//  Created by jianting zhu on 11-12-31.
//  Copyright (c) 2011年 Dunbar Science & Technology. All rights reserved.
//

#import "OAuthWebView.h"
#import "WeiBoHttpManager.h"
#import "SHKActivityIndicator.h"
#import "BabyAlertWindow.h"

@implementation OAuthWebView
@synthesize webV;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (NSString *) getStringFromUrl: (NSString*) url needle:(NSString *) needle {
	NSString * str = nil;
	NSRange start = [url rangeOfString:needle];
	if (start.location != NSNotFound) {
		NSRange end = [[url substringFromIndex:start.location+start.length] rangeOfString:@"&"];
		NSUInteger offset = start.location+start.length;
		str = end.location == NSNotFound
		? [url substringFromIndex:offset]
		: [url substringWithRange:NSMakeRange(offset, end.location)];
		str = [str stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	}
	return str;
}

//剥离出url中的access_token的值
- (void) dialogDidSucceed:(NSURL*)url {
    NSString *q = [url absoluteString];
    token = [self getStringFromUrl:q needle:@"access_token="];
    
    //用户点取消 error_code=21330
    NSString *errorCode = [self getStringFromUrl:q needle:@"error_code="];
    if (errorCode != nil && [errorCode isEqualToString: @"21330"]) {
        NSLog(@"Oauth canceled");
    }
    
    NSString *refreshToken  = [self getStringFromUrl:q needle:@"refresh_token="];
    NSString *expTime       = [self getStringFromUrl:q needle:@"expires_in="];
    NSString *uid           = [self getStringFromUrl:q needle:@"uid="];
    NSString *remindIn      = [self getStringFromUrl:q needle:@"remind_in="];
    
    [[NSUserDefaults standardUserDefaults] setObject:token forKey:USER_STORE_ACCESS_TOKEN];
    [[NSUserDefaults standardUserDefaults] setObject:uid forKey:USER_STORE_USER_ID];
    [[NSUserDefaults standardUserDefaults] synchronize];

    
    NSDate *expirationDate =nil;
    NSLog(@"jtone \n\ntoken=%@\nrefreshToken=%@\nexpTime=%@\nuid=%@\nremindIn=%@\n\n",token,refreshToken,expTime,uid,remindIn);
    if (expTime != nil) {
        int expVal = [expTime intValue]-3600;
        if (expVal == 0) 
        {
            
        } else {
            expirationDate = [NSDate dateWithTimeIntervalSinceNow:expVal];
            [[NSUserDefaults standardUserDefaults]setObject:expirationDate forKey:USER_STORE_EXPIRATION_DATE];
            [[NSUserDefaults standardUserDefaults] synchronize];
			NSLog(@"jtone time = %@",expirationDate);
        } 
    } 
    if (token) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DID_GET_TOKEN_IN_WEB_VIEW object:nil];
        [self.navigationController popViewControllerAnimated:YES];
        [[UIApplication sharedApplication].delegate performSelector:@selector(prepareToMainViewControllerWithAnimate:) withObject:[NSNumber numberWithBool:NO]];
    }


}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"新浪微博登录";
    self.navigationItem.hidesBackButton  = YES;

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancelWeibo)];
    self.navigationItem.rightBarButtonItem = cancelButton;
    [cancelButton release];

    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:USER_STORE_ACCESS_TOKEN];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:USER_STORE_USER_ID];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:USER_STORE_EXPIRATION_DATE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    webV.delegate = self;
    WeiBoHttpManager *weiboHttpManager = [[WeiBoHttpManager alloc]initWithDelegate:self];
    NSURL *url = [weiboHttpManager getOauthCodeUrl];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:url];
	[webV loadRequest:request];
    [request release];
    [weiboHttpManager release];
}

- (void)viewDidUnload
{
    [self setWebV:nil];
    [super viewDidUnload];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.tabBarController.selectedIndex = 0;
}

- (void)dealloc {
    [webV release];
    [super dealloc];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
	//这里是几个重定向，将每个重定向的网址遍历，如果遇到＃号，则重定向到自己申请时候填写的网址，后面会附上access_token的值
    UIApplication *app = [UIApplication sharedApplication];
    UIWindow *window = nil;
    for (UIWindow *win in app.windows) {
        if (win.tag == 1) {
            window = win;
            window.windowLevel = UIWindowLevelNormal;
        }
        if (win.tag == 0) {
            [win makeKeyAndVisible];
        }
    }
    
	NSURL *url = [request URL];
    NSLog(@"webview's url = %@",url);
	NSArray *array = [[url absoluteString] componentsSeparatedByString:@"#"];
	if ([array count]>1) {
		[self dialogDidSucceed:url];
		return NO;
	}
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [[SHKActivityIndicator currentIndicator] displayActivity:@"正在载入..." inView:self.view];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[SHKActivityIndicator currentIndicator] hide];
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    NSLog(@"webview error=%@",error);
}
- (void) cancelWeibo {
    if ([delegate respondsToSelector:@selector(oauthControllerDidCancel:)]) {
        [delegate oauthControllerDidCancel:self];
    }
}

@end
