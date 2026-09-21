/* Initial IOP words derived from Dwarf IOP.initialize, small screen.
   Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
static const uint16_t db_io_initial[][2] = {
  { 0x2004, 0x2104 }, /* IORTable:segments[1].ioRegionSegment */
  { 0x2006, 0x4204 }, /* IORTable:segments[2].ioRegionSegment */
  { 0x2008, 0x3704 }, /* IORTable:segments[3].ioRegionSegment */
  { 0x200a, 0x5d04 }, /* IORTable:segments[4].ioRegionSegment */
  { 0x200c, 0x4e04 }, /* IORTable:segments[5].ioRegionSegment */
  { 0x200e, 0x2304 }, /* IORTable:segments[6].ioRegionSegment */
  { 0x2022, 0x3e04 }, /* IORTable:segments[16].ioRegionSegment */
  { 0x2024, 0x7504 }, /* IORTable:segments[17].ioRegionSegment */
  { 0x2112, 0x0101 }, /* BeepFCB:beepMask.byteMaskAndOffset */
  { 0x212a, 0xffff }, /* KeyboardMouseFCB:kBbase[0] */
  { 0x212b, 0xffff }, /* KeyboardMouseFCB:kBbase[1] */
  { 0x212c, 0xffff }, /* KeyboardMouseFCB:kBbase[2] */
  { 0x212d, 0xffff }, /* KeyboardMouseFCB:kBbase[3] */
  { 0x212e, 0xffff }, /* KeyboardMouseFCB:kBbase[4] */
  { 0x212f, 0xffff }, /* KeyboardMouseFCB:kBbase[5] */
  { 0x2130, 0xffff }, /* KeyboardMouseFCB:kBbase[6] */
  { 0x2131, 0xffff }, /* KeyboardMouseFCB:kBbase[7] */
  { 0x2132, 0xffff }, /* KeyboardMouseFCB:kBbase[8] */
  { 0x21c1, 0x0102 }, /* DisplayFCB:displayLock */
  { 0x21da, 0x4003 }, /* DisplayFCB:crtConfig.numberBitsPerLine */
  { 0x21db, 0x7902 }, /* DisplayFCB:crtConfig.numberDisplayLines */
  { 0x21e0, 0x503c }, /* DisplayFCB:crtConfig.pixelsRefresh */
  { 0x21f5, 0x0104 }, /* ProcessorFCB:mesaClientMask */
  { 0x21f6, 0x0100 }, /* ProcessorFCB:timeOfDayIsValidAndCommand */
  { 0x2225, 0x0108 }, /* DiskFCB:workMask.byteMaskAndOffset */
  { 0x2226, 0x0110 }, /* DiskFCB:lockMask */
  { 0x2289, 0x4000 }, /* FloppyFCB:encodedDeviceTypes */
  { 0x228a, 0x0120 }, /* FloppyFCB:workMask.byteMaskAndOffset */
  { 0x228c, 0x0140 }, /* FloppyFCB:lockMask */
  { 0x22a1, 0x0013 }, /* FloppyFCB.dcb[0].deviceAttributes:type */
  { 0x22a2, 0x0028 }, /* FloppyFCB.dcb[0].deviceAttributes:numberOfCylinders */
  { 0x22a3, 0x0010 }, /* FloppyFCB.dcb[0].deviceAttributes:numberOfHeadsAndSectors */
  { 0x22a4, 0x3000 }, /* FloppyFCB.dcb[0].deviceAttributes:formatLength */
  { 0x22ab, 0xffff }, /* FloppyFCB.dcb[0]:doorOpen */
  { 0x22ac, 0x5800 }, /* w11:w */
  { 0x22fd, 0x0180 }, /* NetworkFCB:etherOutWorkMask.byteMaskAndOffset */
  { 0x22fe, 0x0201 }, /* NetworkFCB:etherInWorkMask.byteMaskAndOffset */
  { 0x22ff, 0x0202 }, /* NetworkFCB:etherLockMask */
  { 0x23c4, 0x0204 }, /* TTYFCB:ttyWorkMask.byteMaskAndOffset */
};
