//
//  TakePhotoViewController.m
//  BabyinFamily
//
//  Created by dong quan on 12-11-8.
//
//

#import "TakePhotoViewController.h"
#import "SendAndSaveViewController.h"
#import "RaisedCenterButton.h"

@implementation TakePhotoViewController {
    BOOL isStatic;
    BOOL hasBlur;
    int selectedFilter;
}

@synthesize delegate;
@synthesize imageView;
@synthesize cameraToggleButton;
@synthesize photoCaptureButton;
@synthesize blurToggleButton;
@synthesize flashToggleButton;
@synthesize cancelButton;
@synthesize retakeButton;
@synthesize libraryToggleButton;
@synthesize photoBar;
@synthesize topBar;
@synthesize outputJPEGQuality;

-(id) init {
    self = [super initWithNibName:@"TakePhotoViewController" bundle:nil];
    
    if (self) {
        self.wantsFullScreenLayout = YES;
        [self.navigationController setNavigationBarHidden:YES animated:NO];
        self.outputJPEGQuality = 1.0;
        self.title = @"拍照";
        NSString *fullpath = [NSString stringWithFormat:@"sourcekit.bundle/image/%@", @"tabbar_camera"];
        self.tabBarItem.image = [UIImage imageNamed:fullpath];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    CGRect mainScreenFrame = CGRectMake(0,0,320,480);
    [[UIScreen mainScreen] bounds];
	[[GPUImageView alloc] initWithFrame:mainScreenFrame];
    self.wantsFullScreenLayout = YES;
    //set background color
    self.view.backgroundColor = [UIColor colorWithPatternImage:
                                 [UIImage imageNamed:@"TakePhoto.bundle/UI/micro_carbon"]];
    
    self.photoBar.backgroundColor = [UIColor colorWithPatternImage:
                                     [UIImage imageNamed:@"TakePhoto.bundle/UI/photo_bar"]];
    
    self.topBar.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/photo_bar"]];
    //button states
    [self.blurToggleButton setSelected:NO];
    
    staticPictureOriginalOrientation = UIImageOrientationUp;
    
    hasBlur = NO;
    
    //[self loadFilters];
    
    //we need a crop filter for the live video
    cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(0.0f, 0.0f, 1.0f, 0.75f)];
    filter = [[GPUImageRGBFilter alloc] init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self setUpCamera];
    });
   // self.navigationController.navigationBarHidden = YES;
    [self.navigationController setNavigationBarHidden:YES animated:NO];


    
    
}


-(void) setUpCamera {
    
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        // Has camera
        
        stillCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPresetPhoto cameraPosition:AVCaptureDevicePositionBack];
        
        stillCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        runOnMainQueueWithoutDeadlocking(^{
            [stillCamera startCameraCapture];
            if([stillCamera.inputCamera hasFlash]){
                [self.flashToggleButton setEnabled:NO];
                [stillCamera.inputCamera lockForConfiguration:nil];
                if([stillCamera.inputCamera flashMode] == AVCaptureFlashModeOff){
                    [self.flashToggleButton setImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/flash-off"] forState:UIControlStateNormal];
                }else if([stillCamera.inputCamera flashMode] == AVCaptureFlashModeAuto){
                    [self.flashToggleButton setImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/flash-auto"] forState:UIControlStateNormal];
                }else{
                    [self.flashToggleButton setImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/flash"] forState:UIControlStateNormal];
                }
                [stillCamera.inputCamera unlockForConfiguration];
                [self.flashToggleButton setEnabled:YES];
            }else{
                [self.flashToggleButton setEnabled:NO];
            }
            [self prepareFilter];
        });
    } else {
        // No camera
        NSLog(@"No camera");
        runOnMainQueueWithoutDeadlocking(^{
            [self prepareFilter];
        });
    }
    
}


-(void) setFilter:(int) index {
    switch (index) {
        case 1:{
            filter = [[GPUImageContrastFilter alloc] init];
            [(GPUImageContrastFilter *) filter setContrast:1.75];
        } break;
        case 2: {
            filter = [[GPUImageToneCurveFilter alloc] initWithACV:@"TakePhoto.bundle/Filters/crossprocess"];
        } break;
        case 3: {
            filter = [[GPUImageToneCurveFilter alloc] initWithACV:@"TakePhoto.bundle/Filters/02"];
        } break;
            /*case 4: {
             filter = [[GrayscaleContrastFilter alloc] init];
             } break;*/
        case 5: {
            filter = [[GPUImageToneCurveFilter alloc] initWithACV:@"TakePhoto.bundle/Filters/17"];
        } break;
        case 6: {
            filter = [[GPUImageToneCurveFilter alloc] initWithACV:@"TakePhoto.bundle/Filters/aqua"];
        } break;
        case 7: {
            filter = [[GPUImageToneCurveFilter alloc] initWithACV:@"TakePhoto.bundle/Filters/yellow-red"];
        } break;
        case 8: {
            filter = [[GPUImageToneCurveFilter alloc] initWithACV:@"TakePhoto.bundle/Filters/06"];
        } break;
        case 9: {
            filter = [[GPUImageToneCurveFilter alloc] initWithACV:@"TakePhoto.bundle/Filters/purple-green"];
        } break;
        default:
            filter = [[GPUImageRGBFilter alloc] init];
            break;
    }
}

-(void) prepareFilter {
    if (![UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        isStatic = YES;
    }
    
    if (!isStatic) {
        [self prepareLiveFilter];
    } else {
        [self prepareStaticFilter];
    }
}

-(void) prepareLiveFilter {
    
    [stillCamera addTarget:cropFilter];
    [cropFilter addTarget:filter];
    //blur is terminal filter
    if (hasBlur) {
        [filter addTarget:blurFilter];
        [blurFilter addTarget:self.imageView];
        //regular filter is terminal
    } else {
        [filter addTarget:self.imageView];
    }
    
    [filter prepareForImageCapture];
    
}

-(void) prepareStaticFilter {
    
    if (!staticPicture) {
        // TODO: fix this hack
        //这个地方不可理，不应该指定死延时时间,在内存紧张的情况下，容易发生崩溃,原因是多个presend动作同时执行了
        //可以考虑其它的方式
        [self performSelector:@selector(switchToLibrary:) withObject:nil afterDelay:1.5];
    }
    
    [staticPicture addTarget:filter];
    
    // blur is terminal filter
    if (hasBlur) {
        [filter addTarget:blurFilter];
        [blurFilter addTarget:self.imageView];
        //regular filter is terminal
    } else {
        [filter addTarget:self.imageView];
    }
    
    GPUImageRotationMode imageViewRotationMode = kGPUImageNoRotation;
    switch (staticPictureOriginalOrientation) {
        case UIImageOrientationLeft:
            imageViewRotationMode = kGPUImageRotateLeft;
            break;
        case UIImageOrientationRight:
            imageViewRotationMode = kGPUImageRotateRight;
            break;
        case UIImageOrientationDown:
            imageViewRotationMode = kGPUImageRotate180;
            break;
        default:
            imageViewRotationMode = kGPUImageNoRotation;
            break;
    }
    
    // seems like atIndex is ignored by GPUImageView...
    [self.imageView setInputRotation:imageViewRotationMode atIndex:0];
    
    
    [staticPicture processImage];
}

-(void) removeAllTargets {
    [stillCamera removeAllTargets];
    [staticPicture removeAllTargets];
    [cropFilter removeAllTargets];
    
    //regular filter
    [filter removeAllTargets];
    
    //blur
    [blurFilter removeAllTargets];
}

-(IBAction)switchToLibrary:(id)sender {
    
    if (!isStatic) {
        // shut down camera
        [stillCamera stopCameraCapture];
        [self removeAllTargets];
    }
    
    UIImagePickerController* imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:NULL];
}

-(IBAction)toggleFlash:(UIButton *)sender{
    
    if([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]
       && stillCamera
       && [stillCamera.inputCamera hasFlash]) {
        [self.flashToggleButton setEnabled:NO];
        [stillCamera.inputCamera lockForConfiguration:nil];
        if([stillCamera.inputCamera flashMode] == AVCaptureFlashModeOff){
            [stillCamera.inputCamera setFlashMode:AVCaptureFlashModeAuto];
            [self.flashToggleButton setImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/flash-auto"] forState:UIControlStateNormal];
        }else if([stillCamera.inputCamera flashMode] == AVCaptureFlashModeAuto){
            [stillCamera.inputCamera setFlashMode:AVCaptureFlashModeOn];
            [self.flashToggleButton setImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/flash"] forState:UIControlStateNormal];
        }else{
            [stillCamera.inputCamera setFlashMode:AVCaptureFlashModeOff];
            [self.flashToggleButton setImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/flash-off"] forState:UIControlStateNormal];
        }
        [stillCamera.inputCamera unlockForConfiguration];
        [self.flashToggleButton setEnabled:YES];
    }
    
}

-(IBAction) toggleBlur:(UIButton*)blurButton {
    
    [self.blurToggleButton setEnabled:NO];
    [self removeAllTargets];
    
    if (hasBlur) {
        hasBlur = NO;
        [self.blurToggleButton setSelected:NO];
    } else {
        if (!blurFilter) {
            blurFilter = [[GPUImageGaussianSelectiveBlurFilter alloc] init];
            [(GPUImageGaussianSelectiveBlurFilter*)blurFilter setExcludeCircleRadius:80.0/320.0];
            [(GPUImageGaussianSelectiveBlurFilter*)blurFilter setExcludeCirclePoint:CGPointMake(0.5f, 0.5f)];
            [(GPUImageGaussianSelectiveBlurFilter*)blurFilter setBlurSize:5.0f];
            [(GPUImageGaussianSelectiveBlurFilter*)blurFilter setAspectRatio:1.0f];
        }
        hasBlur = YES;
        [self.blurToggleButton setSelected:YES];
    }
    
    [self prepareFilter];
    [self.blurToggleButton setEnabled:YES];
    
    if (isStatic) {
        [staticPicture processImage];
    }
}

-(IBAction) switchCamera {
    [self.cameraToggleButton setEnabled:NO];
    [stillCamera rotateCamera];
    [self.cameraToggleButton setEnabled:YES];
}

-(IBAction) takePhoto:(id)sender{
    [self.photoCaptureButton setEnabled:NO];
    
    if (!isStatic) {
        [stillCamera capturePhotoAsImageProcessedUpToFilter:cropFilter
                                      withCompletionHandler:^(UIImage *processed, NSError *error) {
                                          isStatic = YES;
                                          runOnMainQueueWithoutDeadlocking(^{
                                              @autoreleasepool {
                                                  [stillCamera stopCameraCapture];
                                                  [self removeAllTargets];
                                                  [self.retakeButton setHidden:NO];
                                                  [self.libraryToggleButton setHidden:YES];
                                                  [self.cameraToggleButton setEnabled:NO];
                                                  [self.flashToggleButton setEnabled:NO];
                                                  staticPicture = [[GPUImagePicture alloc] initWithImage:processed smoothlyScaleOutput:YES];
                                                  staticPictureOriginalOrientation = processed.imageOrientation;
                                                  [self prepareFilter];
                                                  [self.photoCaptureButton setTitle:@"完成" forState:UIControlStateNormal];
                                                  [self.photoCaptureButton setImage:nil forState:UIControlStateNormal];
                                                  [self.photoCaptureButton setEnabled:YES];
                                              }
                                          });
                                      }];
        
    } else {
        
        GPUImageOutput<GPUImageInput> *processUpTo;
        
        if (hasBlur) {
            processUpTo = blurFilter;
        } else {
            processUpTo = filter;
        }
        
        [staticPicture processImage];
        
        UIImage *currentFilteredVideoFrame = [processUpTo imageFromCurrentlyProcessedOutputWithOrientation:staticPictureOriginalOrientation];
        
        NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:
                              UIImageJPEGRepresentation(currentFilteredVideoFrame, self.outputJPEGQuality), @"data", nil];
        [self.delegate imagePickerController:self didFinishPickingMediaWithInfo:info];
    }
}

-(IBAction) retakePhoto:(UIButton *)button {
    [self.retakeButton setHidden:YES];
    [self.libraryToggleButton setHidden:NO];
    staticPicture = nil;
    staticPictureOriginalOrientation = UIImageOrientationUp;
    isStatic = NO;
    [self removeAllTargets];
    [stillCamera startCameraCapture];
    [self.cameraToggleButton setEnabled:YES];
    
    if([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]
       && stillCamera
       && [stillCamera.inputCamera hasFlash]) {
        [self.flashToggleButton setEnabled:YES];
    }
    
    [self.photoCaptureButton setImage:[UIImage imageNamed:@"TakePhoto.bundle/UI/camera-icon"] forState:UIControlStateNormal];
    [self.photoCaptureButton setTitle:nil forState:UIControlStateNormal];
    
    cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(0.0f, 0.0f, 1.0f, 0.75f)];
    [self setFilter:selectedFilter];
    [self prepareFilter];
}

-(IBAction) cancel:(id)sender
{
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:NO];

    self.tabBarController.tabBar.hidden = NO;
    self.tabBarController.tabBar.selectedItem = 0;
   // [self.tabBarController.selectedViewController.reloadData ];
    [self dismissModalViewControllerAnimated:NO];
}

-(IBAction) handlePan:(UIGestureRecognizer *) sender
{
    if (hasBlur) {
        CGPoint tapPoint = [sender locationInView:imageView];
        GPUImageGaussianSelectiveBlurFilter* gpu =
        (GPUImageGaussianSelectiveBlurFilter*)blurFilter;
        
        if ([sender state] == UIGestureRecognizerStateBegan) {
            //NSLog(@"Start tap");
            if (isStatic) {
                [staticPicture processImage];
            }
        }
        
        if ([sender state] == UIGestureRecognizerStateBegan || [sender state] == UIGestureRecognizerStateChanged) {
            //NSLog(@"Moving tap");
            [gpu setBlurSize:5.0f];
            [gpu setExcludeCirclePoint:CGPointMake(tapPoint.x/320.0f, tapPoint.y/320.0f)];
        }
        
        if([sender state] == UIGestureRecognizerStateEnded){
            //NSLog(@"Done tap");
            [gpu setBlurSize:5.0f];
            
            if (isStatic) {
                [staticPicture processImage];
            }
        }
    }
}

-(IBAction) handlePinch:(UIPinchGestureRecognizer *) sender
{
    if (hasBlur) {
        CGPoint midpoint = [sender locationInView:imageView];
        GPUImageGaussianSelectiveBlurFilter* gpu =
        (GPUImageGaussianSelectiveBlurFilter*)blurFilter;
        
        if ([sender state] == UIGestureRecognizerStateBegan) {
            //NSLog(@"Start tap");
            if (isStatic) {
                [staticPicture processImage];
            }
        }
        
        if ([sender state] == UIGestureRecognizerStateBegan || [sender state] == UIGestureRecognizerStateChanged) {
            [gpu setBlurSize:10.0f];
            [gpu setExcludeCirclePoint:CGPointMake(midpoint.x/320.0f, midpoint.y/320.0f)];
            CGFloat radius = MIN(sender.scale*[gpu excludeCircleRadius], 0.6f);
            [gpu setExcludeCircleRadius:radius];
            sender.scale = 1.0f;
        }
        
        if ([sender state] == UIGestureRecognizerStateEnded) {
            [gpu setBlurSize:5.0f];
            
            if (isStatic) {
                [staticPicture processImage];
            }
        }
    }
}


-(void) dealloc {
    [self removeAllTargets];
    stillCamera = nil;
    cropFilter = nil;
    filter = nil;
    blurFilter = nil;
    staticPicture = nil;
    [super dealloc];
}

- (void)viewWillDisappear:(BOOL)animated {
    [stillCamera stopCameraCapture];
    [super viewWillDisappear:animated];
}
#pragma mark AFPhotoEditorControllerDelegate
- (void)photoEditor:(AFPhotoEditorController *)editor finishedWithImage:(UIImage *)image
{
    // Handle the result image here
    if (image != nil) {
        SendAndSaveViewController* viewController = [[SendAndSaveViewController alloc] initWithImage:image];
        
       [self.navigationController pushViewController:viewController animated:NO];
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:NO];
        //[self presentModalViewController:viewController animated:NO];
        //[self.navigationController popToViewController:viewController animated:NO];
          //NSLog(@"self navigation is %@", self.navigationController);
       // NSLog(@"self superviewcontroll navigation is %@", self.parentViewController.navigationController);

        [viewController release];

    }
    
    //关闭图像选择器
    [self dismissModalViewControllerAnimated:NO];
}
- (void)photoEditorCanceled:(AFPhotoEditorController *)editor
{
    // Handle cancelation here
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - UIImagePickerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
   
#if 0
    [self dismissModalViewControllerAnimated:NO];
    //UIImage *image = [UIImage imageNamed:@"Default.png"];
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self performSelector:@selector(displayEditorForImage:) withObject:image afterDelay:0.5];
#else
    [self dismissModalViewControllerAnimated:NO];
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self displayEditorForImage:image];
#endif
    UIImage* outputImage = [info objectForKey:UIImagePickerControllerEditedImage];
    if (outputImage == nil) {
        outputImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    
    if (outputImage) {
        staticPicture = [[GPUImagePicture alloc] initWithImage:outputImage smoothlyScaleOutput:YES];
        staticPictureOriginalOrientation = outputImage.imageOrientation;
        isStatic = YES;
        [self dismissModalViewControllerAnimated:YES];
        [self.cameraToggleButton setEnabled:NO];
        [self.flashToggleButton setEnabled:NO];
        [self prepareStaticFilter];
        [self.photoCaptureButton setTitle:@"完成" forState:UIControlStateNormal];
        [self.photoCaptureButton setImage:nil forState:UIControlStateNormal];
        [self.photoCaptureButton setEnabled:YES];
        
    }
}
- (void)displayEditorForImage:(UIImage *)imageToEdit
{
    AFPhotoEditorController *editorController = [[AFPhotoEditorController alloc] initWithImage:imageToEdit];
    [editorController setDelegate:self];
    [self presentViewController:editorController animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    if (isStatic) {
        // TODO: fix this hack
        [self dismissModalViewControllerAnimated:NO];
        [self.delegate imagePickerControllerDidCancel:self];
    } else {
        [self dismissModalViewControllerAnimated:YES];
        [self retakePhoto:nil];
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#endif

@end
