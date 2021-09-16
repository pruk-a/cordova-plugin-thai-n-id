#import <Cordova/CDVPlugin.h>
#include "winscard.h"
#import "ReaderInterface.h"

@interface ThaiNID : CDVPlugin <ReaderInterfaceDelegate>{

}

@property (nonatomic, readonly) ReaderInterface *readInf;

-(void)getCardData:(CDVInvokedUrlCommand*)command;
-(void)connectReader:(CDVInvokedUrlCommand*)command;
-(void)disconnectReader:(CDVInvokedUrlCommand*)command;

@end
