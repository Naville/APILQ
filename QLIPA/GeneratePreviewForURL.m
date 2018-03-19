#import "MMMarkdown/MMMarkdown.h"
#import "MachOKit/MachOKit.h"
#import "Objective-Zip.h"
#import <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview,
                               CFURLRef url, CFStringRef contentTypeUTI,
                               CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   -----------------------------------------------------------------------------
 */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview,
                               CFURLRef url, CFStringRef contentTypeUTI,
                               CFDictionaryRef options) {
  // To complete your generator please implement the function
  // GeneratePreviewForURL in GeneratePreviewForURL.c
  OZZipFile *ipaZip =
      [[OZZipFile alloc] initWithFileName:[(__bridge NSURL *)url path]
                                     mode:OZZipFileModeUnzip];
  for (OZFileInZipInfo *info in [ipaZip listFileInZipInfos]) {
    if ([info.name hasPrefix:@"Payload/"] && [info.name hasSuffix:@".app/"]) {
      NSString *BundleRoot = info.name;
      NSString *InfoPlistPath =
          [BundleRoot stringByAppendingString:@"Info.plist"];
      [ipaZip locateFileInZip:InfoPlistPath];
      OZFileInZipInfo *info = [ipaZip getCurrentFileInZipInfo];
      OZZipReadStream *read = [ipaZip readCurrentFileInZip];
      NSMutableData *data = [[NSMutableData alloc] initWithLength:info.length];
      [read readDataWithBuffer:data];
      [read finishedReading];
      NSError *err = nil;
      NSDictionary *Info = (NSDictionary *)[NSPropertyListSerialization
          propertyListWithData:data
                       options:NSPropertyListImmutable
                        format:nil
                         error:&err];
        NSString* ExecutablePath=[BundleRoot stringByAppendingString:[Info objectForKey:@"CFBundleExecutable"]];
         [ipaZip locateFileInZip:ExecutablePath];
        info = [ipaZip getCurrentFileInZipInfo];
        read = [ipaZip readCurrentFileInZip];
        NSMutableData *MachOData = [[NSMutableData alloc] initWithLength:info.length];
        [read readDataWithBuffer:MachOData];
        [read finishedReading];
        // TODO:Use MachOKit to process
    }
  }
  return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
  // Implement only if supported
}
