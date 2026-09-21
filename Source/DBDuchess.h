/** <title>Duchess workstation and raw disks</title>
    <author name="Daybreak contributors"></author>
    Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_DUCHESS_H
#define DAYBREAK_DUCHESS_H
#import "DBMachine.h"
/** Raw two-head, sixteen-sector Pilot disk, with private Library copies. */
@interface DBGuamDisk : DBDisk
{
  BOOL _swapped;
}
@end
/** Guam agent workstation using the post-4.0 Mesa instruction set. */
@interface DBDuchess : DBMachine
{
  uint32_t _agents[16], _palette[256], _displayPages;
  BOOL _color;
}
/** Configure the machine and raw disk before loading a germ. Width must be a
    multiple of sixteen; dimensions are bounded to 2048 by 1536. */
- (id) initWithDisk: (NSString *)path
             width: (unsigned int)width
            height: (unsigned int)height
             color: (BOOL)color
       workingCopy: (BOOL)working;
/** Load a page-aligned post-4.0 germ, install boot switches and enter sBoot.
    Invalid files raise DBDeviceError before execution starts. */
- (void) bootWithGerm: (NSString *)path switches: (NSString *)switches;
/** Invoke a Guam agent by its published device index. */
- (void) callAgent: (unsigned int)index;
@end
#endif
