/** <title>Daybreak virtual memory</title>
    <author name="Daybreak contributors"></author>
    <abstract>Word-addressed Mesa memory and page maps.</abstract>
    Copyright (c) 2017, Dr. Hans-Walter Latz.  See COPYING.
 */
#ifndef DAYBREAK_MEMORY_H
#define DAYBREAK_MEMORY_H
#import <Foundation/Foundation.h>
#include <stdint.h>

/** Mesa page size in 16-bit words. */
#define DB_WORDS_PER_PAGE 256
/** Page was read. */
#define DB_MAP_REFERENCED 1
/** Page was written. */
#define DB_MAP_DIRTY 2
/** Writes are prohibited. */
#define DB_MAP_PROTECTED 4
/** Vacant map entry (tested using the low three bits). */
#define DB_MAP_VACANT 6

/** Memory faults are NSExceptions named DBPointerTrap, DBPageFault or
   DBWriteProtectFault. Virtual page zero and addresses outside the configured
   space always trap. Their userInfo dictionary contains the faulting word
   address under <code>address</code>.  All addresses are word addresses unless
   documented otherwise.  Instances own their storage and must be confined to
   one thread. Initial mappings are identity mappings for installed RAM; other
   pages are vacant.  This is an engine configuration, not a workstation boot
   map. */
@interface DBMemory : NSObject
{
  uint16_t *_words;
  uint32_t *_map;
  uint16_t *_flags;
  uint32_t _realPages;
  uint32_t _virtualPages;
}
/** Return YES when the low three map bits describe a vacant page. */
+ (BOOL) isVacant: (uint16_t)flags;
/** Initialize with nonzero page counts, realPages no greater than
   virtualPages, and at most 131072 virtual pages.  Invalid sizes raise
   NSInvalidArgumentException. */
- (id) initWithRealPages: (uint32_t)realPages
           virtualPages: (uint32_t)virtualPages;
/** Return the installed RAM page count. */
- (uint32_t) realPages;
/** Return the virtual address space page count. */
- (uint32_t) virtualPages;
/** Read a word, setting the page's referenced flag. */
- (uint16_t) readWord: (uint32_t)address;
/** Write a word, setting referenced and dirty flags. */
- (void) writeWord: (uint32_t)address value: (uint16_t)value;
/** Read a Mesa double word: low word first, high word second. */
- (uint32_t) readDoubleWord: (uint32_t)address;
/** Read a byte at byteOffset from a word address; high byte comes first. */
- (uint8_t) fetchByte: (uint32_t)address offset: (uint32_t)byteOffset;
/** Replace one byte, preserving the other half of its word. */
- (void) storeByte: (uint32_t)address
           offset: (uint32_t)byteOffset
            value: (uint8_t)value;
/** Map a virtual page to a real page.  Vacant mappings ignore realPage.
    Invalid page numbers raise NSInvalidArgumentException. */
- (void) mapPage: (uint32_t)virtualPage
             to: (uint32_t)realPage
          flags: (uint16_t)flags;
/** Return map flags, or DB_MAP_VACANT for an out-of-range page. */
- (uint16_t) flagsForPage: (uint32_t)page;
/** Return the mapped real page, or zero for a vacant/out-of-range page. */
- (uint32_t) realPageForPage: (uint32_t)page;
/** Load big-endian word bytes at a real-memory word address, bypassing
   mapping. The complete range and even byte length are checked before
   modifying RAM. */
- (void) loadData: (NSData *)data atRealAddress: (uint32_t)address;
/** Extract a Mesa field.  The high nibble is its position from the MSB,
    and the low nibble is its width minus one.  Invalid fields raise an
   exception. */
+ (uint16_t) fieldFromWord: (uint16_t)word specification: (uint8_t)spec;
/** Replace a Mesa field, truncating value to the field width. */
+ (uint16_t) word: (uint16_t)word
    specification: (uint8_t)spec
        withField: (uint16_t)value;
@end
#endif
