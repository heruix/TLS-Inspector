#import "InitialViewController.h"
#import "SplitViewController.h"
#import "UIHelper.h"

#include <MobileCoreServices/MobileCoreServices.h>

@interface InitialViewController ()

@property (strong, nonatomic) CKCertificateChain * chainManager;

@end

@implementation InitialViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    [[AppState currentState] setAppearance];
    [AppState currentState].extensionContext = self.extensionContext;

    self.chainManager = [[CKCertificateChain alloc] init];

    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            
            NSString * urlString = [item.attributedContentText string];
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePlainText]) {
                // Long-press on URL in Safari or share from other app
                [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypePlainText options:nil completionHandler:^(NSString *text, NSError *error) {
                    [self parseURLString:text];
                }];
                return;
            } else if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL]) {
                // Share page from within Safari
                [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeURL options:nil completionHandler:^(NSURL *url, NSError *error) {
                    if (!error && [url.scheme isEqualToString:@"https"]) {
                        [self loadURL:url];
                    } else {
                        [self unsupportedURL];
                    }
                }];
                return;
            } else if (urlString)  {
                // Share page from third-party browsers (Chrome, Brave 🦁)
                [self parseURLString:urlString];
                return;
            }
        }
    }

    [self closeExtension];
}

- (void) parseURLString:(NSString *)urlString {
    if ([urlString hasPrefix:@"https://"]){
        [self loadURL:[NSURL URLWithString:[urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
    } else {
        [self unsupportedURL];
    }
    return;
}

- (void) loadURL:(NSURL *)url {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    });

    [self.chainManager certificateChainFromURL:url finished:^(NSError * _Nullable error, CKCertificateChain * _Nullable chain) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });

        if (error) {
            [[UIHelper sharedInstance]
             presentAlertInViewController:self
             title:l(@"Could not get certificates")
             body:error.localizedDescription
             dismissButtonTitle:l(@"Dismiss")
             dismissed:^(NSInteger buttonIndex) {
                 [self closeExtension];
             }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                currentChain = chain;
                selectedCertificate = chain.certificates[0];
                UIStoryboard * main = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
                UISplitViewController * split = [main instantiateViewControllerWithIdentifier:@"SplitView"];
                [self presentViewController:split animated:YES completion:nil];
            });
        }
    }];
}

- (void) unsupportedURL {
    [[UIHelper sharedInstance]
     presentAlertInViewController:self
     title:l(@"Unsupported Scheme")
     body:l(@"Only HTTPS sites can be inspected")
     dismissButtonTitle:l(@"Dismiss")
     dismissed:^(NSInteger buttonIndex) {
         [self closeExtension];
     }];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) closeExtension {
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
}

- (IBAction)closeButton:(id)sender {
    [self closeExtension];
}
@end
