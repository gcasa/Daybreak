/* Copyright (c) 2017, Dr. Hans-Walter Latz.  See COPYING. */
#import "DBMemory.h"
#include <stdlib.h>

@implementation DBMemory
+ (BOOL) isVacant: (uint16_t)flags
{
  return (flags & 7) == DB_MAP_VACANT;
}
- (id) initWithRealPages: (uint32_t)realPages virtualPages: (uint32_t)virtualPages
{
  uint32_t i;
  self = [super init];
  if (self != nil)
    {
      if (realPages == 0 || realPages > virtualPages || virtualPages > 131072)
        {
          [self release];
          [NSException raise: NSInvalidArgumentException
                      format: @"Invalid memory size"];
          return nil;
        }
      _realPages = realPages;
      _virtualPages = virtualPages;
      _words
          = calloc ((size_t) realPages * DB_WORDS_PER_PAGE, sizeof (*_words));
      _map = calloc (virtualPages, sizeof (*_map));
      _flags = calloc (virtualPages, sizeof (*_flags));
      if (_words == NULL || _map == NULL || _flags == NULL)
        {
          [self release];
          [NSException raise: NSMallocException
                      format: @"Cannot allocate Mesa memory"];
          return nil;
        }
      for (i = 0; i < virtualPages; i++)
        {
          _map[i] = i < realPages ? i : 0;
          _flags[i] = i < realPages ? 0 : DB_MAP_VACANT;
        }
    }
  return self;
}
- (void) dealloc
{
  free (_words);
  free (_map);
  free (_flags);
  [super dealloc];
}
- (uint32_t) realPages
{
  return _realPages;
}
- (uint32_t) virtualPages
{
  return _virtualPages;
}
- (void) fault: (NSString *)name address: (uint32_t)address
{
  NSDictionary *info;
  info = [NSDictionary
      dictionaryWithObject: [NSNumber numberWithUnsignedInt: address]
                    forKey: @"address"];
  [[NSException exceptionWithName: name
                           reason: @"Mesa memory access fault"
                         userInfo: info] raise];
}
- (uint32_t) translate: (uint32_t)address writing: (BOOL)writing
{
  uint32_t page = address >> 8;
  if (page == 0 || page >= _virtualPages)
    [self fault: @"DBPointerTrap" address: address];
  if ((_flags[page] & 7) == DB_MAP_VACANT)
    [self fault: @"DBPageFault" address: address];
  if (writing && (_flags[page] & DB_MAP_PROTECTED) != 0)
    [self fault: @"DBWriteProtectFault" address: address];
  _flags[page]
      |= writing ? DB_MAP_REFERENCED | DB_MAP_DIRTY : DB_MAP_REFERENCED;
  return (_map[page] << 8) | (address & 255);
}
- (uint16_t) readWord: (uint32_t)address
{
  return _words[[self translate: address writing: NO]];
}
- (void) writeWord: (uint32_t)address value: (uint16_t)value
{
  _words[[self translate: address writing: YES]] = value;
}
- (uint32_t) readDoubleWord: (uint32_t)address
{
  uint32_t low = [self readWord: address];
  uint32_t high = [self readWord: address + 1];
  return low | (high << 16);
}
- (uint8_t) fetchByte: (uint32_t)address offset: (uint32_t)byteOffset
{
  uint16_t word = [self readWord: address + (byteOffset >> 1)];
  return (byteOffset & 1) ? word & 255 : word >> 8;
}
- (void) storeByte: (uint32_t)address
           offset: (uint32_t)byteOffset
            value: (uint8_t)value
{
  uint32_t real = [self translate: address + (byteOffset >> 1) writing: YES];
  uint16_t word = _words[real];
  _words[real] = (byteOffset & 1) ? (word & 0xff00) | value
                                  : (word & 255) | ((uint16_t) value << 8);
}
- (void) mapPage: (uint32_t)virtualPage
             to: (uint32_t)realPage
          flags: (uint16_t)flags
{
  BOOL vacant = (flags & 7) == DB_MAP_VACANT;
  if (virtualPage >= _virtualPages || (!vacant && realPage >= _realPages))
    [NSException raise: NSInvalidArgumentException
                format: @"Invalid page mapping"];
  _map[virtualPage] = vacant ? 0 : realPage;
  _flags[virtualPage] = flags;
}
- (uint16_t) flagsForPage: (uint32_t)page
{
  return page < _virtualPages ? _flags[page] : DB_MAP_VACANT;
}
- (uint32_t) realPageForPage: (uint32_t)page
{
  return page < _virtualPages ? _map[page] : 0;
}
- (void) loadData: (NSData *)data atRealAddress: (uint32_t)address
{
  const unsigned char *bytes = [data bytes];
  unsigned long size = [data length];
  unsigned long i;
  uint32_t capacity = _realPages * DB_WORDS_PER_PAGE;
  if (data == nil || (size & 1) || address > capacity
      || size / 2 > capacity - address)
    [NSException raise: NSInvalidArgumentException
                format: @"Invalid image size or address"];
  for (i = 0; i < size / 2; i++)
    _words[address + i] = ((uint16_t) bytes[2 * i] << 8) | bytes[2 * i + 1];
}
+ (uint16_t) fieldFromWord: (uint16_t)word specification: (uint8_t)spec
{
  unsigned int width = (spec & 15) + 1;
  unsigned int position = spec >> 4;
  if (position + width > 16)
    [NSException raise: NSInvalidArgumentException
                format: @"Invalid Mesa field"];
  return (word >> (16 - position - width)) & ((1UL << width) - 1);
}
+ (uint16_t) word: (uint16_t)word
    specification: (uint8_t)spec
        withField: (uint16_t)value
{
  unsigned int width = (spec & 15) + 1;
  unsigned int position = spec >> 4;
  uint32_t mask;
  unsigned int shift;
  if (position + width > 16)
    [NSException raise: NSInvalidArgumentException
                format: @"Invalid Mesa field"];
  shift = 16 - position - width;
  mask = ((1UL << width) - 1) << shift;
  return (word & ~mask) | (((uint32_t) value << shift) & mask);
}
@end
