#import "MMMarkdown/MMMarkdown.h"
#import "MachOKit/MachOKit.h"
#import "Objective-Zip+NSError.h"
#import "Objective-Zip.h"
#import <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import "Utils.h"
#define ErrHandle();       if (err != nil) {\
[Output appendFormat:@"%@\n",err.localizedDescription];\
[Output appendFormat:@"%@\n",err.localizedFailureReason];\
errCode=invalidDataRef;\
goto bail;\
}

// Code Snippet Stolen From https://lowlevelbits.org/parsing-mach-o-files/ Because I'm lazy
struct _cpu_type_names {
    cpu_type_t cputype;
    const char *cpu_name;
};

static struct _cpu_type_names cpu_type_names[] = {
    { CPU_TYPE_I386, "i386" },
    { CPU_TYPE_X86_64, "x86_64" },
    { CPU_TYPE_ARM, "arm" },
    { CPU_TYPE_ARM64, "arm64" }
};

static const char *cpu_type_name(cpu_type_t cpu_type) {
    static int cpu_type_names_size = sizeof(cpu_type_names) / sizeof(struct _cpu_type_names);
    for (int i = 0; i < cpu_type_names_size; i++ ) {
        if (cpu_type == cpu_type_names[i].cputype) {
            return cpu_type_names[i].cpu_name;
        }
    }
    
    return "unknown";
}
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
  OSStatus errCode = noErr;
  OZZipFile *ipaZip =
      [[OZZipFile alloc] initWithFileName:[(__bridge NSURL *)url path]
                                     mode:OZZipFileModeUnzip];
  NSMutableString *Output = [NSMutableString stringWithCapacity:512];
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
        ErrHandle();
        
      NSString *ExecutablePath = [BundleRoot
          stringByAppendingString:[Info objectForKey:@"CFBundleExecutable"]];
      [Output appendFormat:@"# %@  \n",ExecutablePath];
      [ipaZip locateFileInZip:ExecutablePath];
      info = [ipaZip getCurrentFileInZipInfo];
      read = [ipaZip readCurrentFileInZip];
        [Output appendFormat:@"**ExecutableSize** : %lluKB  \n",info.length/1024];
      //The stupid unzip library we are using could only handle UINT16_MAX length of data each time
      NSMutableData *MachOData =
          [[NSMutableData alloc] initWithLength:info.length];

      [read readDataWithBuffer:MachOData];
      [read finishedReading];
      NSURL *temp = [NSURL fileURLWithPath:@"/tmp/QLIPA.tmp"];
      [MachOData writeToURL:temp atomically:YES];
      MKMemoryMap *MachOMap =
          [MKMemoryMap memoryMapWithContentsOfFile:temp error:&err];
        ErrHandle();
      // TODO:Use MachOKit to process
        NSMutableArray<MKMachOImage*>* Slides=[NSMutableArray arrayWithCapacity:6];
        struct fat_header* Header=(struct fat_header*)MachOData.bytes;
        if(Header->magic==FAT_CIGAM||Header->magic==FAT_MAGIC){
            MKFatBinary* FatMachO=[[MKFatBinary alloc] initWithMemoryMap:MachOMap error:&err];
            for(MKFatArch* FA in FatMachO.architectures){
                NSString* name=[NSString stringWithFormat:@"%@-%d-%d",[Info objectForKey:@"CFBundleExecutable"],FA.cputype,FA.cpusubtype];
                MKMachOImage* MachO=[[MKMachOImage alloc] initWithName:name.UTF8String flags:0 atAddress:FA.offset inMapping:MachOMap error:&err];
                ErrHandle();
                [Slides addObject:MachO];
            }
        }
        else if(Header->magic==MH_MAGIC||Header->magic==MH_MAGIC_64||Header->magic==MH_CIGAM||Header->magic==MH_CIGAM_64){
            MKMachOImage* MachO=[[MKMachOImage alloc] initWithName:[(NSString*)[Info objectForKey:@"CFBundleExecutable"] UTF8String] flags:0 atAddress:0 inMapping:MachOMap error:&err];
            ErrHandle();
            [Slides addObject:MachO];
        }
        else{
            [Output appendFormat:@"**Invalid MachO Header 0x%08x!**  \n",Header->magic];
            goto bail;
        }
        //Now do actual processing
        for(MKMachOImage* Image in Slides){
            [Output appendFormat:@"# %@-%s  \n",Image.name,cpu_type_name(Image.header.cputype)];
            [Output appendFormat:@"**Magic**:                   0x%08x  \n",Image.header.magic];
            [Output appendFormat:@"**CPUSubType**:              0x%08x  \n",Image.header.cpusubtype];
            [Output appendFormat:@"**Flags**:                   0x%08d  \n",Image.header.flags];
            if(Image.header.flags & MH_PIE){
                [Output appendFormat:@"<font color=\"red\">ASLR: ON</font>  \n"];
            }
            else{
                [Output appendFormat:@"<font color=\"red\">ASLR: OFF</font>  \n"];
            }
            if(Image.header.flags & MH_ROOT_SAFE){
                [Output appendFormat:@"<font color=\"red\">SafeForRoot: YES</font>  \n"];
            }
            else{
                [Output appendFormat:@"<font color=\"red\">SafeForRoot: NO</font>  \n"];
            }
            [Output appendFormat:@"**Number of Load Commands**: 0x%08lx  \n",Image.loadCommands.count];
            
            for(MKLoadCommand* LC in Image.loadCommands){
                switch (LC.cmd) {
                        //TODO: Fix this up
                    case LC_UUID:
                        [Output appendFormat:@"## **UUID**:                  %@  \n",[(MKLCUUID*)LC uuid].UUIDString];
                        break;
                    case LC_ENCRYPTION_INFO_64:
                        
                        [Output appendFormat:@"## EncryptionInfo  \n"];
                        [Output appendFormat:@"**CryptSize** %d  \n",[(MKLCEncryptionInfo64*)LC cryptsize]];
                        [Output appendFormat:@"**CryptOffset** %d  \n",[(MKLCEncryptionInfo64*)LC cryptoff]];
                        if([(MKLCEncryptionInfo64*)LC cryptid]==0){
                            [Output appendFormat:@"<font color=\"red\">Encrypted: NO</font>  \n"];
                        }
                        else{
                            [Output appendFormat:@"<font color=\"red\">Encrypted: YES</font>  \n"];
                        }
                        break;
                    case LC_ENCRYPTION_INFO:
                        
                        [Output appendFormat:@"## EncryptionInfo  \n"];
                        [Output appendFormat:@"**CryptSize** %d  \n",[(MKLCEncryptionInfo*)LC cryptsize]];
                        [Output appendFormat:@"**CryptOffset** %d  \n",[(MKLCEncryptionInfo*)LC cryptoff]];
                        if([(MKLCEncryptionInfo*)LC cryptid]==0){
                            [Output appendFormat:@"<font color=\"red\">Encrypted: NO</font>  \n"];
                        }
                        else{
                            [Output appendFormat:@"<font color=\"red\">Encrypted: YES</font>  \n"];
                        }
                        break;
                    case LC_MAIN:
                        [Output appendString:@"## MAIN  \n"];
                        [Output appendFormat:@"**Main Entry Offset**:     %llu  \n",[(MKLCMain*)LC entryoff]];
                        [Output appendFormat:@"**Stack Size**:               %llu  \n",[(MKLCMain*)LC stacksize]];
                        break;
                    case LC_SEGMENT:
                        [Output appendFormat:@"## **Segment Name**           %@  \n",[(MKLCSegment*)LC segname]];
                        [Output appendFormat:@"**VM Address**             %d  \n",[(MKLCSegment*)LC vmaddr]];
                        [Output appendFormat:@"**VM Size**                %d  \n",[(MKLCSegment*)LC vmsize]];
                        [Output appendFormat:@"**File Offset**            %d  \n",[(MKLCSegment*)LC fileoff]];
                        [Output appendFormat:@"**File Size**              %d  \n",[(MKLCSegment*)LC filesize]];
                        [Output appendFormat:@"**Maximum VM Protect**     %@  \n",VMProtectionString([(MKLCSegment*)LC maxprot])];
                        [Output appendFormat:@"**Initial VM Protect**     %@ \n",VMProtectionString([(MKLCSegment*)LC initprot])];
                        [Output appendFormat:@"**Number of Sections**     %d  \n",[(MKLCSegment*)LC nsects]];
                        [Output appendFormat:@"**Flags**                  %d  \n",[(MKLCSegment*)LC flags]];
                        break;
                    case LC_SEGMENT_64:
                        [Output appendFormat:@"## **Segment Name**           %@  \n",[(MKLCSegment64*)LC segname]];
                        [Output appendFormat:@"**VM Address**             %llu  \n",[(MKLCSegment64*)LC vmaddr]];
                        [Output appendFormat:@"**VM Size**                %llu  \n",[(MKLCSegment64*)LC vmsize]];
                        [Output appendFormat:@"**File Offset**            %llu  \n",[(MKLCSegment64*)LC fileoff]];
                        [Output appendFormat:@"**File Size**              %llu  \n",[(MKLCSegment64*)LC filesize]];
                        [Output appendFormat:@"**Maximum VM Protect**     %@  \n",VMProtectionString([(MKLCSegment*)LC maxprot])];
                        [Output appendFormat:@"**Initial VM Protect**     %@ \n",VMProtectionString([(MKLCSegment*)LC initprot])];
                        [Output appendFormat:@"**Number of Sections**     %d  \n",[(MKLCSegment64*)LC nsects]];
                        [Output appendFormat:@"**Flags**                  %d  \n",[(MKLCSegment64*)LC flags]];
                        break;
                    default:
                        break;
                }
                
                //[Output appendFormat:@"%@",];
            }
        }
        goto bail;
    }
  }

bail : {
    
    NSString *rendered = [NSString stringWithFormat:@"<!DOCTYPE html>\n<html lang=\"en\">\n<body>\n%@</body>\n</html>",[MMMarkdown HTMLStringWithMarkdown:Output error:nil]];
    NSLog(@"%@",rendered);
    NSDictionary *properties = @{(__bridge NSString *)kQLPreviewPropertyAttachmentsKey:@{
                                 (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
                                 (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html" }};
  QLPreviewRequestSetDataRepresentation(
      preview,
      (__bridge CFDataRef)[rendered dataUsingEncoding:NSUTF8StringEncoding],
      kUTTypeHTML,(__bridge CFDictionaryRef)properties);
    return noErr;
}
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
  // Implement only if supported
}
