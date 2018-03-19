#import "Objective-Zip.h"
#include <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <Foundation/Foundation.h>
#include <QuickLook/QuickLook.h>
#include <zlib.h>

// Stolen from ProvisionQL because I'm lazy
NSString *mainIconNameForApp(NSDictionary *appPropertyList) {
  id icons;
  NSString *iconName;

  // Check for CFBundleIcons (since 5.0)
  id iconsDict = [appPropertyList objectForKey:@"CFBundleIcons"];
  if ([iconsDict isKindOfClass:[NSDictionary class]]) {
    id primaryIconDict = [iconsDict objectForKey:@"CFBundlePrimaryIcon"];
    if ([primaryIconDict isKindOfClass:[NSDictionary class]]) {
      id tempIcons = [primaryIconDict objectForKey:@"CFBundleIconFiles"];
      if ([tempIcons isKindOfClass:[NSArray class]]) {
        icons = tempIcons;
      }
    }
  }

  if (!icons) {
    // Check for CFBundleIconFiles (since 3.2)
    id tempIcons = [appPropertyList objectForKey:@"CFBundleIconFiles"];
    if ([tempIcons isKindOfClass:[NSArray class]]) {
      icons = tempIcons;
    }
  }

  if (icons) {
    // Search some patterns for primary app icon (120x120)
    NSArray *matches = @[ @"120", @"60", @"@2x" ];

    for (NSString *match in matches) {
      NSPredicate *predicate =
          [NSPredicate predicateWithFormat:@"SELF contains[c] %@", match];
      NSArray *results = [icons filteredArrayUsingPredicate:predicate];
      if ([results count]) {
        iconName = [results firstObject];
        // Check for @2x existence
        if ([match isEqualToString:@"60"] &&
            ![[iconName pathExtension] length]) {
          if (![iconName hasSuffix:@"@2x"]) {
            iconName = [iconName stringByAppendingString:@"@2x"];
          }
        }
        break;
      }
    }

    // If no one matches any pattern, just take first item
    if (!iconName) {
      iconName = [icons firstObject];
    }
  } else {
    // Check for CFBundleIconFile (legacy, before 3.2)
    NSString *legacyIcon = [appPropertyList objectForKey:@"CFBundleIconFile"];
    if ([legacyIcon length]) {
      iconName = legacyIcon;
    }
  }

  // Load NSImage
  if ([iconName length]) {
    if (![[iconName pathExtension] length]) {
      iconName = [iconName stringByAppendingPathExtension:@"png"];
    }
    return iconName;
  }

  return nil;
}
OSStatus GenerateThumbnailForURL(void *thisInterface,
                                 QLThumbnailRequestRef thumbnail, CFURLRef url,
                                 CFStringRef contentTypeUTI,
                                 CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface,
                               QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as
   possible
   -----------------------------------------------------------------------------
 */

OSStatus GenerateThumbnailForURL(void *thisInterface,
                                 QLThumbnailRequestRef thumbnail, CFURLRef url,
                                 CFStringRef contentTypeUTI,
                                 CFDictionaryRef options, CGSize maxSize) {
  // To complete your generator please implement the function
  // GenerateThumbnailForURL in GenerateThumbnailForURL.c
  OZZipFile *ipaZip =
      [[OZZipFile alloc] initWithFileName:[(__bridge NSURL *)url path]
                                     mode:OZZipFileModeUnzip];
  NSArray *infos = [ipaZip listFileInZipInfos];
  for (OZFileInZipInfo *info in infos) {
    if ([info.name hasPrefix:@"Payload/"] && [info.name hasSuffix:@".app/"]) {
      NSString *BundleRoot = info.name;
      NSString *InfoPlistPath =
          [BundleRoot stringByAppendingString:@"Info.plist"];
      if ([ipaZip locateFileInZip:InfoPlistPath] == YES) {
        OZFileInZipInfo *info = [ipaZip getCurrentFileInZipInfo];
        OZZipReadStream *read = [ipaZip readCurrentFileInZip];
        NSMutableData *data =
            [[NSMutableData alloc] initWithLength:info.length];
        [read readDataWithBuffer:data];
        [read finishedReading];
        NSError *err = nil;
        NSDictionary *Info = (NSDictionary *)[NSPropertyListSerialization
            propertyListWithData:data
                         options:NSPropertyListImmutable
                          format:nil
                           error:&err];
        NSString *iconName = mainIconNameForApp(Info);
        iconName = [BundleRoot stringByAppendingString:iconName];
        if ([ipaZip locateFileInZip:iconName] == YES) {
          OZFileInZipInfo *info = [ipaZip getCurrentFileInZipInfo];
          OZZipReadStream *read = [ipaZip readCurrentFileInZip];
          NSMutableData *data =
              [[NSMutableData alloc] initWithLength:info.length];
          [read readDataWithBuffer:data];
          [read finishedReading];
          CGImageSourceRef ImageSrcRef =
              CGImageSourceCreateWithData(CFBridgingRetain(data), NULL);
          CFStringRef keys[] = {kCGImageSourceCreateThumbnailFromImageAlways,
                                kCGImageSourceCreateThumbnailWithTransform,
                                kCGImageSourceShouldCache};
          CFTypeRef values[] = {kCFBooleanTrue, kCFBooleanTrue, kCFBooleanTrue};
          CFDictionaryRef options = CFDictionaryCreate(
              kCFAllocatorDefault, (const void **)keys, values, 3,
              &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
          CGImageRef ImageRef =
              CGImageSourceCreateThumbnailAtIndex(ImageSrcRef, 0, options);
          QLThumbnailRequestSetImage(thumbnail, ImageRef, NULL);
        }
      } else {
        NSLog(@"Can't Find Info.plist");
      }
    }
  }
  return invalidDataRef;
}

void CancelThumbnailGeneration(void *thisInterface,
                               QLThumbnailRequestRef thumbnail) {
  // Implement only if supported
}
