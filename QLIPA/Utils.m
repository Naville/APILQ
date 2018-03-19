//
//  Utils.m
//  QLIPA
//
//  Created by Naville Zhang on 2018/3/19.
//  Copyright © 2018年 Naville Zhang. All rights reserved.
//

#import "Utils.h"
NSString* VMProtectionString(vm_prot_t prot){
    switch (prot) {
        case VM_PROT_NONE:
            return @"VM\\_PROT\\_NONE";
        case VM_PROT_READ:
            return @"VM\\_PROT\\_READ";
        case VM_PROT_WRITE:
            return @"VM\\_PROT\\_WRITE";
        case VM_PROT_EXECUTE:
            return @"VM\\_PROT\\_EXECUTE";
        case VM_PROT_DEFAULT:
            return @"VM\\_PROT\\_DEFAULT";
        case VM_PROT_ALL:
            return @"VM\\_PROT\\_ALL";
        case VM_PROT_NO_CHANGE:
            return @"VM\\_PROT\\_NO\\_CHANGE";
        case VM_PROT_COPY:
            return @"VM\\_PROT\\_COPY|VM\\_PROT\\_WANTS\\_COPY";
        case VM_PROT_EXECUTE_ONLY:
            return @"VM\\_PROT\\_EXECUTE\\_ONLY";
        case VM_PROT_STRIP_READ:
            return @"VM\\_PROT\\_STRIP\\_READ";
        case VM_PROT_IS_MASK:
            return @"VM\\_PROT\\_IS\\_MASK";
        default:
            return [NSString stringWithFormat:@"0x%08x",prot];
    }
}

