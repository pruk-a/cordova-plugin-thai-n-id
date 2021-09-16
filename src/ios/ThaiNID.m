/********* ThaiNID.m Cordova Plugin Implementation *******/

#import <ExternalAccessory/ExternalAccessory.h>
#include "winscard.h"
#include "ft301u.h"
#include "ReaderInterface.h"
#import "ThaiNID.h"

@implementation ThaiNID

@synthesize readInf=_readInf;

#pragma mark -
#pragma mark ReaderInterfaceDelegate Methods
BOOL cardIsAttached=FALSE;

/*Update UI on main thread*/
-(void)changeCardState
{
    if (cardIsAttached == FALSE) {

        //When card plug-out, do power off
        SCardDisconnect(gCardHandle,SCARD_UNPOWER_CARD);
    }

}

- (void) cardInterfaceDidDetach:(BOOL)attached
{
    cardIsAttached = attached;
    //According with card slot status to do display
    [self performSelectorOnMainThread:@selector(changeCardState) withObject:nil waitUntilDone:YES];

}

- (void) readerInterfaceDidChange:(BOOL)attached
{
    //check card slot status to do specified dispaly
    if (attached) {
        NSLog(@"Reader attached");
//        [self performSelectorOnMainThread:@selector(disAccDig) withObject:nil waitUntilDone:YES];
    }
    else{
        NSLog(@"Reader DidDetach");
//        SCardReleaseContext(gContxtHandle);
//        [self performSelectorOnMainThread:@selector(disNoAccDig) withObject:nil waitUntilDone:YES];
    }

}

#pragma mark -
SCARDCONTEXT gContxtHandle;
SCARDHANDLE  gCardHandle;
char * errCode(int err)
{
    static char errmsg[200];
    char *errTbl[] = {
        "",
        "NI_INTERNAL_ERROR (-1)",
        "NI_INVALID_LICENSE (-2)",
        "NI_READER_NOT_FOUND (-3)",
        "NI_CONNECTION_ERROR (-4)",
        "NI_GET_PHOTO_ERROR (-5)",
        "NI_GET_TEXT_ERROR	(-6)",
        "NI_INVALID_CARD (-7)",
        "NI_UNKNOWN_CARD_VERSION (-8)",
        "NI_DISCONNECTION_ERROR (-9)",
        "NI_INIT_ERROR (-10)",
        "NI_READER_NOT_SUPPORTED (-11)",
        "NI_LICENSE_FILE_ERROR (-12)",
        "NI_PARAMETER_ERROR (-13)",
        "NI_UNKNOWN (-14)",
        "NI_INTERNET_ERROR (-15)",
        "NI_UNKNOWN (-16)",
        "NI_UNKNOWN (-17)",
        "NI_LICENSE_UPDATE_ERROR (-18)"
    };
    errmsg[0] = 0;
    sprintf( errmsg , "code = %d",err);
    err = err*-1;
    if( err >0  && err <= 18)
    {
        strcpy (errmsg , errTbl[err]);
    }
    return errmsg;
}
// -(char * ) getReaderType
// {
//     char *arrReadType[]=
//     {
//         "FtGetCurrentReaderType return Error",
//         "Unknown Reader",
//         "Bluetooth Reader 301BT",
//         "Dock Reader 301U30",
//         "Lightning Reader 301U8"
//     };
//
//     LONG iRet;
//     unsigned int i_readerType = 0;
//     iRet = FtGetCurrentReaderType(&i_readerType);
//     i_readerType++;
//     if( iRet != 0 )
//     {
//         i_readerType =0;
//     }
//
//     return arrReadType[i_readerType];
// }

- (NSString*) hexStringWithData: (unsigned char*) data ofLength: (NSUInteger) len
{
    NSMutableString *tmp = [NSMutableString string];
    for (NSUInteger i=0; i<len; i++)
        [tmp appendFormat:@"%02x", data[i]];
    return [NSString stringWithString:tmp];
}

- (NSString *) stringFromHex:(NSString *)str
{
    unsigned char whole_byte;
    NSUInteger temp,hex;
    NSString *strhex, *hexstr, *theString;
    NSString *rstr = @"";
    NSScanner* pScanner;
    unsigned int iValue;
    unichar thaiAlpha;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < ([str length] / 2) - 2 ; i++) {
        byte_chars[0] = [str characterAtIndex:i*2];
        byte_chars[1] = [str characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        if([self isThaiChar:(Byte)whole_byte]){
            temp = (NSUInteger)whole_byte;
            hex = 0x0E00 + temp - 0xA0;
            strhex = [NSString stringWithFormat:@"%lu",(unsigned long)hex];
            hexstr = [NSString stringWithFormat:@"0x%lx",(unsigned long)[strhex integerValue]];
            pScanner = [NSScanner scannerWithString: hexstr];
            [pScanner scanHexInt: &iValue];
            thaiAlpha = iValue;
            theString = [NSString stringWithFormat:@"%C", thaiAlpha];
        } else {
            hexstr = [self hexStringWithData:&whole_byte ofLength:sizeof(whole_byte)];
            theString = [self stringFromHexAscii:hexstr];
        }
        rstr = [rstr stringByAppendingString:theString];

    }

    NSData* data = [rstr dataUsingEncoding:NSUTF16StringEncoding];
    return [[NSString alloc] initWithData: data encoding:NSUTF16StringEncoding] ;
}

- (NSString *) stringFromHexAscii:(NSString *)str
{
    NSMutableData *stringData = [[NSMutableData alloc] init] ;
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [str length] / 2; i++) {
        byte_chars[0] = [str characterAtIndex:i*2];
        byte_chars[1] = [str characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [stringData appendBytes:&whole_byte length:1];
    }

    return [[NSString alloc] initWithData: stringData encoding:NSASCIIStringEncoding] ;
}

-(BOOL) isThaiChar:(Byte)c{
    if ( ((c >= 0xA1) && (c <= 0xDA)) || ((c >= 0xDF) && (c <= 0xFB)) )
    {
        return YES;
    }
    return NO;
}

- (void)connectReader:(CDVInvokedUrlCommand*)command{

  [self.commandDelegate runInBackground:^{

      _readInf = [[ReaderInterface alloc]init];
      [_readInf setDelegate:self];

      CDVPluginResult* result = nil;

      LONG iRet = 0;
      DWORD dwActiveProtocol = -1;
      char mszReaders[128] = "";
      DWORD dwReaders = -1;

      iRet = SCardEstablishContext(SCARD_SCOPE_SYSTEM,NULL,NULL,&gContxtHandle);

      iRet = SCardListReaders(gContxtHandle, NULL, mszReaders, &dwReaders);

      if(iRet != SCARD_S_SUCCESS)
      {
        NSLog(@"SCardListReaders error %08x",iRet);
//        SCardReleaseContext(gContxtHandle);
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:[NSString stringWithFormat:
                @"%08x", iRet]];
          [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];

      }

      iRet = SCardConnect(gContxtHandle,mszReaders,SCARD_SHARE_SHARED,SCARD_PROTOCOL_T0,&gCardHandle,&dwActiveProtocol);

      if(iRet != SCARD_S_SUCCESS)
      {
        NSLog(@"SCardConnect error %08x",iRet);
//        SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:[NSString stringWithFormat:
                @"%08x", iRet]];
          [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];

      } else {
         unsigned char patr[33];
         DWORD len = sizeof(patr);
         iRet = SCardGetAttrib(gCardHandle,NULL, patr, &len);
         if(iRet != SCARD_S_SUCCESS)
         {
             NSLog(@"SCardGetAttrib error %08x",iRet);
             SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
             result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                 messageAsString:[NSString stringWithFormat:
                     @"%08x", iRet]];
             [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
         } else {
           if ((patr[0] == 0x3b && patr[1] == 0x67) ||
                (patr[0] == 0x3b && patr[1] == 0x68) ||
                (patr[0] == 0x3b && patr[1] == 0x78) ||
                (patr[0] == 0x3b && patr[1] == 0x79) ){
                  NSMutableData *tmpData = [NSMutableData data];
                  [tmpData appendBytes:patr length:len];
                  NSString* dataString= [NSString stringWithFormat:@"ATR %@",tmpData];
                  DWORD pcchReaderLen;
                  DWORD pdwState;
                  DWORD pdwProtocol;
                  len = sizeof(patr);
                  pcchReaderLen = sizeof(mszReaders);
                  iRet =  SCardStatus(gCardHandle,mszReaders,&pcchReaderLen,&pdwState,&pdwProtocol,patr,&len);
                  if(iRet != SCARD_S_SUCCESS)
                  {
                      NSLog(@"SCardStatus error %08x",iRet);
                      SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                      result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                          messageAsString:[NSString stringWithFormat:
                              @"%08x", iRet]];
                      [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                  } else {
                      result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:dataString];
                      [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                  }
                } else {
                  iRet = 02;
                  NSLog(@"Invalid Card Type %08x",iRet);
                  SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                  result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                      messageAsString:[NSString stringWithFormat:
                          @"%08x", iRet]];
                  [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                }
         }
      }

  }];

}

- (void)getCardData:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{

        CDVPluginResult* result = nil;

        LONG iRet = 0;
        unsigned char resp[1024];
        unsigned char* p;
        unsigned int resplen = sizeof(resp) ;
        NSString *cardData = @"";
        NSString *str, *b, *c;

        resplen = sizeof(resp);

        BYTE pbSendBuffer1[] = {0x00, 0xA4, 0x04, 0x00, 0x08, 0xA0, 0x00, 0x00, 0x00, 0x54, 0x48, 0x00, 0x01};
        BYTE pbSendBuffer2[] = {0x00, 0xc0, 0x00, 0x00, 0x0a};
        BYTE pbSendBuffer3[] = {0x80, 0xb0, 0x00, 0x04, 0x02, 0x00, 0x0d};
        BYTE pbSendBuffer4[] = {0x00, 0xc0, 0x00, 0x00, 0x0d};
        BYTE pbSendBuffer5[] = {0x80, 0xb0, 0x00, 0x11, 0x02, 0x00, 0xd1};
        BYTE pbSendBuffer6[] = {0x00, 0xc0, 0x00, 0x00, 0xd1};
        BYTE pbSendBuffer7[] = {0x80, 0xb0, 0x15, 0x79, 0x02, 0x00, 0x64};
        BYTE pbSendBuffer8[] = {0x00, 0xc0, 0x00, 0x00, 0x64};
        BYTE pbSendBuffer9[] = {0x80, 0xb0, 0x01, 0x67, 0x02, 0x00, 0x12};
        BYTE pbSendBuffer10[] = {0x00, 0xc0, 0x00, 0x00, 0x12};

        DWORD dwSendLength;

        SCARD_IO_REQUEST pioSendPci, pioRecvPci;

        pioSendPci.dwProtocol=SCARD_PROTOCOL_T0;
        pioRecvPci.dwProtocol=SCARD_PROTOCOL_T0;

        dwSendLength = sizeof(pbSendBuffer1);
        iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer1,dwSendLength,&pioRecvPci,resp, &resplen);

        if (iRet != 0) {
            SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
            NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
            NSMutableData *tmpData = [NSMutableData data];
            [tmpData appendBytes:resp length:sizeof(pbSendBuffer1)*2];


        } else {
            dwSendLength = sizeof(pbSendBuffer2);
            resplen = sizeof(resp);
            iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer2,dwSendLength,&pioRecvPci,resp,&resplen);

            if (iRet != 0) {
                SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                NSMutableData *tmpData = [NSMutableData data];
                [tmpData appendBytes:resp length:sizeof(pbSendBuffer2)*2];

            } else {
                dwSendLength = sizeof(pbSendBuffer3);
                resplen = sizeof(resp);
                iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer3,dwSendLength,&pioRecvPci,resp,&resplen);

                if (iRet != 0) {
                    SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                    NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                    NSMutableData *tmpData = [NSMutableData data];
                    [tmpData appendBytes:resp length:sizeof(pbSendBuffer3)*2];

                }
                else {
                    dwSendLength = sizeof(pbSendBuffer4);
                    resplen = sizeof(resp);
                    iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer4,dwSendLength,&pioRecvPci,resp,&resplen);

                    if (iRet != 0) {
                        SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                        NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                        NSMutableData *tmpData = [NSMutableData data];
                        [tmpData appendBytes:resp length:sizeof(pbSendBuffer4)*2];

                    }
                    else {

                        p = resp;

                        NSMutableString* mutString = [[NSMutableString alloc] init];

                        for(int i=0;i<=resplen-1;i++){

                            [mutString appendString:[NSString stringWithFormat:@"%02X",p[i]]];
                        }

                        str = mutString;

                        c = [self stringFromHex:str];

                        cardData = [cardData stringByAppendingString:c];

                    }

                }

                dwSendLength = sizeof(pbSendBuffer5);
                resplen = sizeof(resp);
                iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer5,dwSendLength,&pioRecvPci,resp,&resplen);

                if (iRet != 0) {
                    SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                    NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                    NSMutableData *tmpData = [NSMutableData data];
                    [tmpData appendBytes:resp length:sizeof(pbSendBuffer5)*2];

                }
                else {
                    dwSendLength = sizeof(pbSendBuffer6);
                    resplen = sizeof(resp);
                    iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer6,dwSendLength,&pioRecvPci,resp,&resplen);

                    if (iRet != 0) {
                        SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                        NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                        NSMutableData *tmpData = [NSMutableData data];
                        [tmpData appendBytes:resp length:sizeof(pbSendBuffer6)*2];

                    }
                    else {

                        p = resp;

                        NSMutableString* mutString = [[NSMutableString alloc] init];

                        for(int i=0;i<=resplen-1;i++){

                            [mutString appendString:[NSString stringWithFormat:@"%02X",p[i]]];
                        }

                        str = mutString;

                        c = [self stringFromHex:str];

                        b = @"#";

                        b = [b stringByAppendingString:c];

                        cardData = [cardData stringByAppendingString:b];

                    }

                }

                dwSendLength = sizeof(pbSendBuffer7);
                resplen = sizeof(resp);
                iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer7,dwSendLength,&pioRecvPci,resp,&resplen);

                if (iRet != 0) {
                    SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                    NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                    NSMutableData *tmpData = [NSMutableData data];
                    [tmpData appendBytes:resp length:sizeof(pbSendBuffer7)*2];

                }
                else {
                    dwSendLength = sizeof(pbSendBuffer8);
                    resplen = sizeof(resp);
                    iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer8,dwSendLength,&pioRecvPci,resp,&resplen);

                    if (iRet != 0) {
                        SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                        NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                        NSMutableData *tmpData = [NSMutableData data];
                        [tmpData appendBytes:resp length:sizeof(pbSendBuffer8)*2];

                    }
                    else {

                        p = resp;

                        NSMutableString* mutString = [[NSMutableString alloc] init];

                        for(int i=0;i<=resplen-1;i++){

                            [mutString appendString:[NSString stringWithFormat:@"%02X",p[i]]];
                        }

                        str = mutString;

                        c = [self stringFromHex:str];

                        b = @"#";

                        b = [b stringByAppendingString:c];

                        cardData = [cardData stringByAppendingString:b];

                    }



                }

                dwSendLength = sizeof(pbSendBuffer9);
                resplen = sizeof(resp);
                iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer9,dwSendLength,&pioRecvPci,resp,&resplen);

                if (iRet != 0) {
                    SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                    NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                    NSMutableData *tmpData = [NSMutableData data];
                    [tmpData appendBytes:resp length:sizeof(pbSendBuffer9)*2];

                }
                else {
                    dwSendLength = sizeof(pbSendBuffer10);
                    resplen = sizeof(resp);
                    iRet=SCardTransmit(gCardHandle,&pioSendPci,pbSendBuffer10,dwSendLength,&pioRecvPci,resp,&resplen);

                    if (iRet != 0) {
                        SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
                        NSLog(@"ERROR SCardTransmit ret %08X.", iRet);
                        NSMutableData *tmpData = [NSMutableData data];
                        [tmpData appendBytes:resp length:sizeof(pbSendBuffer10)*2];

                    }
                    else {

                        p = resp;

                        NSMutableString* mutString = [[NSMutableString alloc] init];

                        for(int i=0;i<=resplen-1;i++){

                            [mutString appendString:[NSString stringWithFormat:@"%02X",p[i]]];
                        }

                        str = mutString;

                        c = [self stringFromHex:str];

                        b = @"#";

                        b = [b stringByAppendingString:c];

                        cardData = [cardData stringByAppendingString:b];

                        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:cardData];
                    }



                }


            }

        }

        SCardDisconnect(gCardHandle, SCARD_RESET_CARD);
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];

    }];
}

- (void)disconnectReader:(CDVInvokedUrlCommand*)command{

  [self.commandDelegate runInBackground:^{

      CDVPluginResult* result = nil;
      LONG res;
      SCardEstablishContext(SCARD_SCOPE_SYSTEM, NULL, NULL, &gContxtHandle);
      res = SCardReleaseContext(gContxtHandle);
      if (res!=0) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
        messageAsString:[NSString stringWithFormat:@"error code on disconnect: %s", errCode(res)]];
      } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"disconnect completed"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
      }
  }];
}
@end
