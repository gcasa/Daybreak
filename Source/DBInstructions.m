/* Derived from Dwarf by Dr. Hans-Walter Latz.  See COPYING.
   Reproduced by Tools/port-instructions.py; no Java runtime is used. */
#import "DBProcessorPrivate.h"

@implementation DBProcessor (Instructions)

/* Ch03_Memory_Organization: ESC_x07_SM. */
- (void) ESC_x07_SM
{
  int16_t mf = [self pop];
  int64_t rp = [self popLong];
  int64_t vp = [self popLong];

  [_memory mapPage: vp to: rp flags: mf];
}

/* Ch03_Memory_Organization: ESC_x09_GMF. */
- (void) ESC_x09_GMF
{
  int64_t vp = [self popLong];
  int16_t mf = [_memory flagsForPage: vp];
  int64_t rp = [_memory realPageForPage: vp];

  [self push: mf];
  [self pushLong: rp];
}

/* Ch03_Memory_Organization: ESC_x08_SMF. */
- (void) ESC_x08_SMF
{
  int16_t newMf = [self pop];
  int64_t vp = [self popLong];
  int16_t mf = [_memory flagsForPage: vp];
  int64_t rp = [_memory realPageForPage: vp];

  [self push: mf];
  [self pushLong: rp];
  if (![DBMemory isVacant: mf])
    {

      [_memory mapPage: vp to: rp flags: newMf];
    }
}

/* Ch03_Memory_Organization: OPC_xF7_LP. */
- (void) OPC_xF7_LP
{
  int16_t ptr = [self pop];
  [self pushLong: (ptr == 0) ? 0 : [self lengthenPointer: ptr]];
}

/* Ch03_Memory_Organization: ESC_x1E_ROB_alpha. */
- (void) ESC_x1E_ROB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t ptr = [self pop] & 0xFFFF;
  if (alpha < 1 || alpha > 4)
    {
      [self hardwareError: @"ROB :: invalid alpha = "];
    }
  [self push: (int16_t) [self readMDSWord: ptr - alpha]];
}

/* Ch03_Memory_Organization: ESC_x1F_WOB_alpha. */
- (void) ESC_x1F_WOB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t ptr = [self pop] & 0xFFFF;
  if (alpha < 1 || alpha > 4)
    {
      [self hardwareError: @"WOB :: invalid alpha = "];
    }
  [self writeMDSWord: ptr - alpha value: [self pop]];
}

/* Ch03_Memory_Organization: ESC_x79_RRMDS. */
- (void) ESC_x79_RRMDS
{
  [self push: _state.MDS >> 16];
}

/* Ch03_Memory_Organization: ESC_x71_WRMDS. */
- (void) ESC_x71_WRMDS
{
  _state.MDS = (uint32_t) (uint16_t) [self pop] << 16;
}

/* Ch05_Stack_Instructions: OPC_xA2_REC. */
- (void) OPC_xA2_REC
{
  [self recover];
}

/* Ch05_Stack_Instructions: OPC_xA3_REC2. */
- (void) OPC_xA3_REC2
{
  [self recover];
  [self recover];
}

/* Ch05_Stack_Instructions: OPC_xA4_DIS. */
- (void) OPC_xA4_DIS
{
  [self discard];
}

/* Ch05_Stack_Instructions: OPC_xA5_DIS2. */
- (void) OPC_xA5_DIS2
{
  [self discard];
  [self discard];
}

/* Ch05_Stack_Instructions: OPC_xA6_EXCH. */
- (void) OPC_xA6_EXCH
{
  int16_t v = [self pop];
  int16_t u = [self pop];
  [self push: v];
  [self push: u];
}

/* Ch05_Stack_Instructions: OPC_xA7_DEXCH. */
- (void) OPC_xA7_DEXCH
{
  int64_t v = [self popLong];
  int64_t u = [self popLong];
  [self pushLong: v];
  [self pushLong: u];
}

/* Ch05_Stack_Instructions: OPC_xA8_DUP. */
- (void) OPC_xA8_DUP
{
  int16_t u = [self pop];
  [self push: u];
  [self push: u];
}

/* Ch05_Stack_Instructions: OPC_xA9_DDUP. */
- (void) OPC_xA9_DDUP
{
  int64_t u = [self popLong];
  [self pushLong: u];
  [self pushLong: u];
}

/* Ch05_Stack_Instructions: OPC_xAA_EXDIS. */
- (void) OPC_xAA_EXDIS
{
  int16_t u = [self pop];
  [self pop];
  [self push: u];
}

/* Ch05_Stack_Instructions: OPC_x3C_BNDCK. */
- (void) OPC_x3C_BNDCK
{
  int64_t range = [self pop] & 0xFFFF;
  int64_t index = [self pop] & 0xFFFF;
  [self push: index];
  if (index >= range)
    {
      [self boundsTrap];
    }
}

/* Ch05_Stack_Instructions: ESC_x24_BNDCKL. */
- (void) ESC_x24_BNDCKL
{
  uint64_t range = [self popLong] & 0xFFFFFFFFL;
  uint64_t index = [self popLong] & 0xFFFFFFFFL;
  [self pushLong: (int64_t) index];
  if (index >= range)
    {
      [self boundsTrap];
    }
}

/* Ch05_Stack_Instructions: ESC_x25_NILCK. */
- (void) ESC_x25_NILCK
{
  int16_t pointer = [self pop];
  [self push: pointer];
  if (pointer == 0)
    {
      [self pointerTrap];
    }
}

/* Ch05_Stack_Instructions: ESC_x26_NILCKL. */
- (void) ESC_x26_NILCKL
{
  int64_t longPointer = [self popLong];
  [self pushLong: longPointer];
  if (longPointer == 0)
    {
      [self pointerTrap];
    }
}

/* Ch05_Stack_Instructions: OPC_xAB_NEG. */
- (void) OPC_xAB_NEG
{
  int16_t i = [self pop];
  [self push: -i];
}

/* Ch05_Stack_Instructions: OPC_xAC_INC. */
- (void) OPC_xAC_INC
{
  int64_t s = [self pop] & 0xFFFF;
  [self push: (int16_t) ((s + 1) & 0xFFFF)];
}

/* Ch05_Stack_Instructions: OPC_xAE_DINC. */
- (void) OPC_xAE_DINC
{
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  [self pushLong: (int64_t) ((s + 1) & 0xFFFFFFFFL)];
}

/* Ch05_Stack_Instructions: OPC_xAD_DEC. */
- (void) OPC_xAD_DEC
{
  int64_t s = [self pop] & 0xFFFF;
  [self push: (int16_t) ((s - 1) & 0xFFFF)];
}

/* Ch05_Stack_Instructions: OPC_xB4_ADDSB_alpha. */
- (void) OPC_xB4_ADDSB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t i = [self pop];
  [self push: (int16_t) (i + db_sign_byte (alpha))];
}

/* Ch05_Stack_Instructions: OPC_xAF_DBL. */
- (void) OPC_xAF_DBL
{
  int16_t i = [self pop];
  [self push: (int16_t) ((i * 2) & 0xFFFF)];
}

/* Ch05_Stack_Instructions: OPC_xB0_DDBL. */
- (void) OPC_xB0_DDBL
{
  int64_t i = [self popLong];
  [self pushLong: i * 2];
}

/* Ch05_Stack_Instructions: OPC_xB1_TRPL. */
- (void) OPC_xB1_TRPL
{
  int64_t i = [self pop] & 0xFFFF;
  [self push: i * 3];
}

/* Ch05_Stack_Instructions: ESC_x18_LINT. */
- (void) ESC_x18_LINT
{
  int16_t i = [self pop];
  [self push: i];
  [self push: (i < 0) ? (int16_t) -1 : 0];
}

/* Ch05_Stack_Instructions: OPC_x7C_SHIFTSB_alpha. */
- (void) OPC_x7C_SHIFTSB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t u = [self pop];
  int64_t shift = db_sign_byte (alpha);
  if (shift < -15 || shift > 15)
    {
      [self hardwareError: @"opcode SHIFTSB :: shift < -15 || shift > 15"];
    }
  [self push: db_shift_word (u, shift)];
}

/* Ch05_Stack_Instructions: OPC_xB2_AND. */
- (void) OPC_xB2_AND
{
  int16_t v = [self pop];
  int16_t u = [self pop];
  [self push: (int16_t) (v & u)];
}

/* Ch05_Stack_Instructions: ESC_x13_DAND. */
- (void) ESC_x13_DAND
{
  int64_t v = [self popLong];
  int64_t u = [self popLong];
  [self pushLong: v & u];
}

/* Ch05_Stack_Instructions: OPC_xB3_IOR. */
- (void) OPC_xB3_IOR
{
  int16_t v = [self pop];
  int16_t u = [self pop];
  [self push: (int16_t) (v | u)];
}

/* Ch05_Stack_Instructions: ESC_x14_DIOR. */
- (void) ESC_x14_DIOR
{
  int64_t v = [self popLong];
  int64_t u = [self popLong];
  [self pushLong: v | u];
}

/* Ch05_Stack_Instructions: ESC_x12_XOR. */
- (void) ESC_x12_XOR
{
  int16_t v = [self pop];
  int16_t u = [self pop];
  [self push: (int16_t) (v ^ u)];
}

/* Ch05_Stack_Instructions: ESC_x15_DXOR. */
- (void) ESC_x15_DXOR
{
  int64_t v = [self popLong];
  int64_t u = [self popLong];
  [self pushLong: v ^ u];
}

/* Ch05_Stack_Instructions: OPC_x7B_SHIFT. */
- (void) OPC_x7B_SHIFT
{
  int16_t shift = [self pop];
  int16_t u = [self pop];
  [self push: db_shift_word (u, shift)];
}

/* Ch05_Stack_Instructions: ESC_x17_DSHIFT. */
- (void) ESC_x17_DSHIFT
{
  int16_t shift = [self pop];
  int64_t u = [self popLong];
  [self pushLong: db_shift_long (u, shift)];
}

/* Ch05_Stack_Instructions: ESC_x16_ROTATE. */
- (void) ESC_x16_ROTATE
{
  int16_t rotate = [self pop];
  int16_t u = [self pop];
  [self push: db_rotate_word (u, rotate)];
}

/* Ch05_Stack_Instructions: OPC_xB5_ADD. */
- (void) OPC_xB5_ADD
{
  int64_t t = [self pop] & 0xFFFF;
  int64_t s = [self pop] & 0xFFFF;
  [self push: (int16_t) ((s + t) & 0xFFFF)];
}

/* Ch05_Stack_Instructions: OPC_xB6_SUB. */
- (void) OPC_xB6_SUB
{
  int64_t t = [self pop] & 0xFFFF;
  int64_t s = [self pop] & 0xFFFF;
  [self push: (int16_t) ((s - t) & 0xFFFF)];
}

/* Ch05_Stack_Instructions: OPC_xB7_DADD. */
- (void) OPC_xB7_DADD
{
  uint64_t t = [self popLong] & 0xFFFFFFFFL;
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  [self pushLong: (int64_t) ((s + t) & 0xFFFFFFFFL)];
}

/* Ch05_Stack_Instructions: OPC_xB8_DSUB. */
- (void) OPC_xB8_DSUB
{
  uint64_t t = [self popLong] & 0xFFFFFFFFL;
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  [self pushLong: (int64_t) ((s - t) & 0xFFFFFFFFL)];
}

/* Ch05_Stack_Instructions: OPC_xB9_ADC. */
- (void) OPC_xB9_ADC
{
  int64_t t = [self pop] & 0xFFFF;
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  [self pushLong: (int64_t) ((s + t) & 0xFFFFFFFFL)];
}

/* Ch05_Stack_Instructions: OPC_xBA_ACD. */
- (void) OPC_xBA_ACD
{
  uint64_t t = [self popLong] & 0xFFFFFFFFL;
  int64_t s = [self pop] & 0xFFFF;
  [self pushLong: (int64_t) ((s + t) & 0xFFFFFFFFL)];
}

/* Ch05_Stack_Instructions: OPC_xBC_MUL. */
- (void) OPC_xBC_MUL
{
  uint64_t t = [self pop] & 0xFFFF;
  uint64_t s = [self pop] & 0xFFFF;
  [self pushLong: (int64_t) ((s * t) & 0xFFFFFFFFL)];
  [self discard];
}

/* Ch05_Stack_Instructions: ESC_x30_DMUL. */
- (void) ESC_x30_DMUL
{
  uint64_t t = [self popLong] & 0xFFFFFFFFL;
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  [self pushLong: (int64_t) ((s * t) & 0xFFFFFFFFL)];
}

/* Ch05_Stack_Instructions: ESC_x31_SDIV. */
- (void) ESC_x31_SDIV
{
  int16_t k = [self pop];
  int16_t j = [self pop];
  if (k == 0)
    {
      [self divZeroTrap];
    }
  [self push: j / k];
  [self push: j % k];
  [self discard];
}

/* Ch05_Stack_Instructions: ESC_x1C_UDIV. */
- (void) ESC_x1C_UDIV
{
  int64_t t = [self pop] & 0xFFFF;
  int64_t s = [self pop] & 0xFFFF;
  if (t == 0)
    {
      [self divZeroTrap];
    }
  [self push: (int16_t) (s / t)];
  [self push: (int16_t) (s % t)];
  [self discard];
}

/* Ch05_Stack_Instructions: ESC_x1D_LUDIV. */
- (void) ESC_x1D_LUDIV
{
  int64_t t = [self pop] & 0xFFFF;
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  if (t == 0)
    {
      [self divZeroTrap];
    }
  if ((s >> 16) >= (uint64_t) t)
    {
      [self divCheckTrap];
    }
  [self push: (int16_t) ((s / t) & 0xFFFFL)];
  [self push: (int16_t) ((s % t) & 0xFFFFL)];
  [self discard];
}

/* Ch05_Stack_Instructions: ESC_x32_SDDIV. */
- (void) ESC_x32_SDDIV
{
  int64_t k = [self popLong];
  int64_t j = [self popLong];
  if (k == 0)
    {
      [self divZeroTrap];
    }
  [self pushLong: j / k];
  [self pushLong: j % k];
  [self discard];
  [self discard];
}

/* Ch05_Stack_Instructions: ESC_x33_UDDIV. */
- (void) ESC_x33_UDDIV
{
  uint64_t t = [self popLong] & 0xFFFFFFFFL;
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  if (t == 0)
    {
      [self divZeroTrap];
    }
  [self pushLong: (int64_t) ((s / t) & 0xFFFFFFFFL)];
  [self pushLong: (int64_t) ((s % t) & 0xFFFFFFFFL)];
  [self discard];
  [self discard];
}

/* Ch05_Stack_Instructions: OPC_xBD_DCMP. */
- (void) OPC_xBD_DCMP
{
  int64_t k = [self popLong];
  int64_t j = [self popLong];
  [self push: (j > k) ? (int16_t) 1 : (j < k) ? (int16_t) -1 : (int16_t) 0];
}

/* Ch05_Stack_Instructions: OPC_xBE_UDCMP. */
- (void) OPC_xBE_UDCMP
{
  uint64_t t = [self popLong] & 0xFFFFFFFFL;
  uint64_t s = [self popLong] & 0xFFFFFFFFL;
  [self push: (s > t) ? (int16_t) 1 : (s < t) ? (int16_t) -1 : (int16_t) 0];
}

/* Ch05_Stack_Instructions: ESC_x40_FADD. */
- (void) ESC_x40_FADD
{
  float t = [self popFloat];
  float s = [self popFloat];
  float result = s + t;
  [self pushFloat: result];
}

/* Ch05_Stack_Instructions: ESC_x41_FSUB. */
- (void) ESC_x41_FSUB
{
  float t = [self popFloat];
  float s = [self popFloat];
  float result = s - t;
  [self pushFloat: result];
}

/* Ch05_Stack_Instructions: ESC_x42_FMUL. */
- (void) ESC_x42_FMUL
{
  float t = [self popFloat];
  float s = [self popFloat];
  float result = s * t;
  [self pushFloat: result];
}

/* Ch05_Stack_Instructions: ESC_x43_FDIV. */
- (void) ESC_x43_FDIV
{
  float t = [self popFloat];
  float s = [self popFloat];
  if (t == 0.0f)
    {
      [self divZeroTrap];
    }
  float result = s / t;
  [self pushFloat: result];
}

/* Ch05_Stack_Instructions: ESC_x44_FCOMP. */
- (void) ESC_x44_FCOMP
{
  float t = [self popFloat];
  float s = [self popFloat];
  int64_t result = (s > t) ? 1 : (s == t) ? 0 : -1;
  [self push: (int16_t) result];
}

/* Ch05_Stack_Instructions: ESC_x46_FLOAT. */
- (void) ESC_x46_FLOAT
{
  int64_t s = [self popLong];
  float result = (float) s;
  [self pushFloat: result];
}

/* Ch06_Jump_Instructions: OPC_x81_J2. */
- (void) OPC_x81_J2
{
  _state.PC = (_state.savedPC + 2) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x82_J3. */
- (void) OPC_x82_J3
{
  _state.PC = (_state.savedPC + 3) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x83_J4. */
- (void) OPC_x83_J4
{
  _state.PC = (_state.savedPC + 4) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x84_J5. */
- (void) OPC_x84_J5
{
  _state.PC = (_state.savedPC + 5) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x85_J6. */
- (void) OPC_x85_J6
{
  _state.PC = (_state.savedPC + 6) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x86_J7. */
- (void) OPC_x86_J7
{
  _state.PC = (_state.savedPC + 7) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x87_J8. */
- (void) OPC_x87_J8
{
  _state.PC = (_state.savedPC + 8) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x88_JB_salpha. */
- (void) OPC_x88_JB_salpha
{
  int64_t disp = [self nextCodeByte];
  _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x89_JW_sword. */
- (void) OPC_x89_JW_sword
{
  int64_t disp = [self nextCodeWord];
  _state.PC = (_state.savedPC + db_sign_word (disp)) & 0xFFFF;
}

/* Ch06_Jump_Instructions: ESC_x19_JS. */
- (void) ESC_x19_JS
{
  _state.PC = [self pop] & 0xFFFF;
}

/* Ch06_Jump_Instructions: OPC_x80_CATCH_alpha. */
- (void) OPC_x80_CATCH_alpha
{
  [self nextCodeByte];
}

/* Ch06_Jump_Instructions: OPC_x98_JZ3. */
- (void) OPC_x98_JZ3
{
  int16_t u = [self pop];
  if (u == 0)
    {
      _state.PC = (_state.savedPC + 3) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x99_JZ4. */
- (void) OPC_x99_JZ4
{
  int16_t u = [self pop];
  if (u == 0)
    {
      _state.PC = (_state.savedPC + 4) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x9B_JNZ3. */
- (void) OPC_x9B_JNZ3
{
  int16_t u = [self pop];
  if (u != 0)
    {
      _state.PC = (_state.savedPC + 3) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x9C_JNZ4. */
- (void) OPC_x9C_JNZ4
{
  int16_t u = [self pop];
  if (u != 0)
    {
      _state.PC = (_state.savedPC + 4) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x9A_JZB_salpha. */
- (void) OPC_x9A_JZB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t data = [self pop];
  if (data == 0)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x9D_JNZB_salpha. */
- (void) OPC_x9D_JNZB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t data = [self pop];
  if (data != 0)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x8B_JEB_salpha. */
- (void) OPC_x8B_JEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t v = [self pop];
  int16_t u = [self pop];
  if (u == v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x8E_JNEB_salpha. */
- (void) OPC_x8E_JNEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t v = [self pop];
  int16_t u = [self pop];
  if (u != v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x9E_JDEB_salpha. */
- (void) OPC_x9E_JDEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int64_t v = [self popLong];
  int64_t u = [self popLong];
  if (u == v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x9F_JDNEB_salpha. */
- (void) OPC_x9F_JDNEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int64_t v = [self popLong];
  int64_t u = [self popLong];
  if (u != v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x8A_JEP_pair. */
- (void) OPC_x8A_JEP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t data = [self pop] & 0xFFFF;
  if (data == (pair >> 4))
    {
      _state.PC = (_state.savedPC + (pair & 0x0F) + 4) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x8D_JNEP_pair. */
- (void) OPC_x8D_JNEP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t data = [self pop] & 0xFFFF;
  if (data != (pair >> 4))
    {
      _state.PC = (_state.savedPC + (pair & 0x0F) + 4) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x8C_JEBB_alphasbeta. */
- (void) OPC_x8C_JEBB_alphasbeta
{
  int64_t b = [self nextCodeByte];
  int64_t disp = [self nextCodeByte];
  int64_t data = [self pop] & 0xFFFF;
  if (data == b)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x8F_JNEBB_alphasbeta. */
- (void) OPC_x8F_JNEBB_alphasbeta
{
  int64_t b = [self nextCodeByte];
  int64_t disp = [self nextCodeByte];
  int64_t data = [self pop] & 0xFFFF;
  if (data != b)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x90_JLB_salpha. */
- (void) OPC_x90_JLB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t k = [self pop];
  int16_t j = [self pop];
  if (j < k)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x93_JLEB_salpha. */
- (void) OPC_x93_JLEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t k = [self pop];
  int16_t j = [self pop];
  if (j <= k)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x92_JGB_salpha. */
- (void) OPC_x92_JGB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t k = [self pop];
  int16_t j = [self pop];
  if (j > k)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x91_JGEB_salpha. */
- (void) OPC_x91_JGEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int16_t k = [self pop];
  int16_t j = [self pop];
  if (j >= k)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x94_JULB_salpha. */
- (void) OPC_x94_JULB_salpha
{
  int64_t disp = [self nextCodeByte];
  int64_t v = [self pop] & 0xFFFF;
  int64_t u = [self pop] & 0xFFFF;
  if (u < v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x97_JULEB_salpha. */
- (void) OPC_x97_JULEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int64_t v = [self pop] & 0xFFFF;
  int64_t u = [self pop] & 0xFFFF;
  if (u <= v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x96_JUGB_salpha. */
- (void) OPC_x96_JUGB_salpha
{
  int64_t disp = [self nextCodeByte];
  int64_t v = [self pop] & 0xFFFF;
  int64_t u = [self pop] & 0xFFFF;
  if (u > v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_x95_JUGEB_salpha. */
- (void) OPC_x95_JUGEB_salpha
{
  int64_t disp = [self nextCodeByte];
  int64_t v = [self pop] & 0xFFFF;
  int64_t u = [self pop] & 0xFFFF;
  if (u >= v)
    {
      _state.PC = (_state.savedPC + db_sign_byte (disp)) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_xA0_JIB_word. */
- (void) OPC_xA0_JIB_word
{
  int64_t base = [self nextCodeWord] & 0xFFFF;
  int64_t limit = [self pop] & 0xFFFF;
  int64_t index = [self pop] & 0xFFFF;
  if (index < limit)
    {
      int64_t dispPair = (int16_t) [self readCode: base + (index / 2)] & 0xFFFF;
      int64_t offset
          = ((index % 2) == 0) ? (dispPair >> 8) : (dispPair & 0x00FF);
      _state.PC = (_state.savedPC + offset) & 0xFFFF;
    }
}

/* Ch06_Jump_Instructions: OPC_xA1_JIW_word. */
- (void) OPC_xA1_JIW_word
{
  int64_t base = [self nextCodeWord] & 0xFFFF;
  int64_t limit = [self pop] & 0xFFFF;
  int64_t index = [self pop] & 0xFFFF;
  if (index < limit)
    {
      int64_t disp = (int16_t) [self readCode: base + index] & 0xFFFF;
      _state.PC = (_state.savedPC + disp) & 0xFFFF;
    }
}

/* Ch07_Assignment_Instructions: OPC_xCB_LIN1. */
- (void) OPC_xCB_LIN1
{
  [self push: (int16_t) -1];
}

/* Ch07_Assignment_Instructions: OPC_xCC_LINI. */
- (void) OPC_xCC_LINI
{
  [self push: (int16_t) 0x8000];
}

/* Ch07_Assignment_Instructions: OPC_xD1_LID0. */
- (void) OPC_xD1_LID0
{
  [self push: (int16_t) 0];
  [self push: (int16_t) 0];
}

/* Ch07_Assignment_Instructions: OPC_xC0_LI0. */
- (void) OPC_xC0_LI0
{
  [self push: (int16_t) 0];
}

/* Ch07_Assignment_Instructions: OPC_xC1_LI1. */
- (void) OPC_xC1_LI1
{
  [self push: (int16_t) 1];
}

/* Ch07_Assignment_Instructions: OPC_xC2_LI2. */
- (void) OPC_xC2_LI2
{
  [self push: (int16_t) 2];
}

/* Ch07_Assignment_Instructions: OPC_xC3_LI3. */
- (void) OPC_xC3_LI3
{
  [self push: (int16_t) 3];
}

/* Ch07_Assignment_Instructions: OPC_xC4_LI4. */
- (void) OPC_xC4_LI4
{
  [self push: (int16_t) 4];
}

/* Ch07_Assignment_Instructions: OPC_xC5_LI5. */
- (void) OPC_xC5_LI5
{
  [self push: (int16_t) 5];
}

/* Ch07_Assignment_Instructions: OPC_xC6_LI6. */
- (void) OPC_xC6_LI6
{
  [self push: (int16_t) 6];
}

/* Ch07_Assignment_Instructions: OPC_xC7_LI7. */
- (void) OPC_xC7_LI7
{
  [self push: (int16_t) 7];
}

/* Ch07_Assignment_Instructions: OPC_xC8_LI8. */
- (void) OPC_xC8_LI8
{
  [self push: (int16_t) 8];
}

/* Ch07_Assignment_Instructions: OPC_xC9_LI9. */
- (void) OPC_xC9_LI9
{
  [self push: (int16_t) 9];
}

/* Ch07_Assignment_Instructions: OPC_xCA_LI10. */
- (void) OPC_xCA_LI10
{
  [self push: (int16_t) 10];
}

/* Ch07_Assignment_Instructions: OPC_xCD_LIB_alpha. */
- (void) OPC_xCD_LIB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: alpha];
}

/* Ch07_Assignment_Instructions: OPC_xCF_LINB_alpha. */
- (void) OPC_xCF_LINB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: alpha | 0xFF00];
}

/* Ch07_Assignment_Instructions: OPC_xD0_LIHB_alpha. */
- (void) OPC_xD0_LIHB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: alpha << 8];
}

/* Ch07_Assignment_Instructions: OPC_xCE_LIW_word. */
- (void) OPC_xCE_LIW_word
{
  int64_t u = [self nextCodeWord];
  [self push: u];
}

/* Ch07_Assignment_Instructions: OPC_xD2_LA0. */
- (void) OPC_xD2_LA0
{
  [self push: _state.LF];
}

/* Ch07_Assignment_Instructions: OPC_xD3_LA1. */
- (void) OPC_xD3_LA1
{
  [self push: _state.LF + 1];
}

/* Ch07_Assignment_Instructions: OPC_xD4_LA2. */
- (void) OPC_xD4_LA2
{
  [self push: _state.LF + 2];
}

/* Ch07_Assignment_Instructions: OPC_xD5_LA3. */
- (void) OPC_xD5_LA3
{
  [self push: _state.LF + 3];
}

/* Ch07_Assignment_Instructions: OPC_xD6_LA6. */
- (void) OPC_xD6_LA6
{
  [self push: _state.LF + 6];
}

/* Ch07_Assignment_Instructions: OPC_xD7_LA8. */
- (void) OPC_xD7_LA8
{
  [self push: _state.LF + 8];
}

/* Ch07_Assignment_Instructions: OPC_xD8_LAB_alpha. */
- (void) OPC_xD8_LAB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: _state.LF + alpha];
}

/* Ch07_Assignment_Instructions: OPC_xD9_LAW_word. */
- (void) OPC_xD9_LAW_word
{
  int64_t word = [self nextCodeWord];
  [self push: _state.LF + word];
}

/* Ch07_Assignment_Instructions: OPC_x01_LL0. */
- (void) OPC_x01_LL0
{
  [self push: (int16_t) [self readMDSWord: _state.LF]];
}

/* Ch07_Assignment_Instructions: OPC_x02_LL1. */
- (void) OPC_x02_LL1
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 1]];
}

/* Ch07_Assignment_Instructions: OPC_x03_LL2. */
- (void) OPC_x03_LL2
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 2]];
}

/* Ch07_Assignment_Instructions: OPC_x04_LL3. */
- (void) OPC_x04_LL3
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 3]];
}

/* Ch07_Assignment_Instructions: OPC_x05_LL4. */
- (void) OPC_x05_LL4
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 4]];
}

/* Ch07_Assignment_Instructions: OPC_x06_LL5. */
- (void) OPC_x06_LL5
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 5]];
}

/* Ch07_Assignment_Instructions: OPC_x07_LL6. */
- (void) OPC_x07_LL6
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 6]];
}

/* Ch07_Assignment_Instructions: OPC_x08_LL7. */
- (void) OPC_x08_LL7
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 7]];
}

/* Ch07_Assignment_Instructions: OPC_x09_LL8. */
- (void) OPC_x09_LL8
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 8]];
}

/* Ch07_Assignment_Instructions: OPC_x0A_LL9. */
- (void) OPC_x0A_LL9
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 9]];
}

/* Ch07_Assignment_Instructions: OPC_x0B_LL10. */
- (void) OPC_x0B_LL10
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 10]];
}

/* Ch07_Assignment_Instructions: OPC_x0C_LL11. */
- (void) OPC_x0C_LL11
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 11]];
}

/* Ch07_Assignment_Instructions: OPC_x0D_LLB_alpha. */
- (void) OPC_x0D_LLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: alpha]];
}

/* Ch07_Assignment_Instructions: OPC_x0E_LLD0. */
- (void) OPC_x0E_LLD0
{
  [self push: (int16_t) [self readMDSWord: _state.LF]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 1]];
}

/* Ch07_Assignment_Instructions: OPC_x0F_LLD1. */
- (void) OPC_x0F_LLD1
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 1]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 2]];
}

/* Ch07_Assignment_Instructions: OPC_x10_LLD2. */
- (void) OPC_x10_LLD2
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 2]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 3]];
}

/* Ch07_Assignment_Instructions: OPC_x11_LLD3. */
- (void) OPC_x11_LLD3
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 3]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 4]];
}

/* Ch07_Assignment_Instructions: OPC_x12_LLD4. */
- (void) OPC_x12_LLD4
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 4]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 5]];
}

/* Ch07_Assignment_Instructions: OPC_x13_LLD5. */
- (void) OPC_x13_LLD5
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 5]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 6]];
}

/* Ch07_Assignment_Instructions: OPC_x14_LLD6. */
- (void) OPC_x14_LLD6
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 6]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 7]];
}

/* Ch07_Assignment_Instructions: OPC_x15_LLD7. */
- (void) OPC_x15_LLD7
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 7]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 8]];
}

/* Ch07_Assignment_Instructions: OPC_x16_LLD8. */
- (void) OPC_x16_LLD8
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 8]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 9]];
}

/* Ch07_Assignment_Instructions: OPC_x17_LLD10. */
- (void) OPC_x17_LLD10
{
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 10]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: 11]];
}

/* Ch07_Assignment_Instructions: OPC_x18_LLDB_alpha. */
- (void) OPC_x18_LLDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: alpha]];
  [self push: (int16_t) [self readMDSWord: _state.LF offset: alpha + 1]];
}

/* Ch07_Assignment_Instructions: OPC_x19_SL0. */
- (void) OPC_x19_SL0
{
  [self writeMDSWord: _state.LF value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x1A_SL1. */
- (void) OPC_x1A_SL1
{
  [self writeMDSWord: _state.LF offset: 1 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x1B_SL2. */
- (void) OPC_x1B_SL2
{
  [self writeMDSWord: _state.LF offset: 2 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x1C_SL3. */
- (void) OPC_x1C_SL3
{
  [self writeMDSWord: _state.LF offset: 3 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x1D_SL4. */
- (void) OPC_x1D_SL4
{
  [self writeMDSWord: _state.LF offset: 4 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x1E_SL5. */
- (void) OPC_x1E_SL5
{
  [self writeMDSWord: _state.LF offset: 5 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x1F_SL6. */
- (void) OPC_x1F_SL6
{
  [self writeMDSWord: _state.LF offset: 6 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x20_SL7. */
- (void) OPC_x20_SL7
{
  [self writeMDSWord: _state.LF offset: 7 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x21_SL8. */
- (void) OPC_x21_SL8
{
  [self writeMDSWord: _state.LF offset: 8 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x22_SL9. */
- (void) OPC_x22_SL9
{
  [self writeMDSWord: _state.LF offset: 9 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x23_SL10. */
- (void) OPC_x23_SL10
{
  [self writeMDSWord: _state.LF offset: 10 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x24_SLB_alpha. */
- (void) OPC_x24_SLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self writeMDSWord: _state.LF offset: alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x25_SLD0. */
- (void) OPC_x25_SLD0
{
  [self writeMDSWord: _state.LF offset: 1 value: [self pop]];
  [self writeMDSWord: _state.LF value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x26_SLD1. */
- (void) OPC_x26_SLD1
{
  [self writeMDSWord: _state.LF offset: 2 value: [self pop]];
  [self writeMDSWord: _state.LF offset: 1 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x27_SLD2. */
- (void) OPC_x27_SLD2
{
  [self writeMDSWord: _state.LF offset: 3 value: [self pop]];
  [self writeMDSWord: _state.LF offset: 2 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x28_SLD3. */
- (void) OPC_x28_SLD3
{
  [self writeMDSWord: _state.LF offset: 4 value: [self pop]];
  [self writeMDSWord: _state.LF offset: 3 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x29_SLD4. */
- (void) OPC_x29_SLD4
{
  [self writeMDSWord: _state.LF offset: 5 value: [self pop]];
  [self writeMDSWord: _state.LF offset: 4 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x2A_SLD5. */
- (void) OPC_x2A_SLD5
{
  [self writeMDSWord: _state.LF offset: 6 value: [self pop]];
  [self writeMDSWord: _state.LF offset: 5 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x2B_SLD6. */
- (void) OPC_x2B_SLD6
{
  [self writeMDSWord: _state.LF offset: 7 value: [self pop]];
  [self writeMDSWord: _state.LF offset: 6 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x2C_SLD8. */
- (void) OPC_x2C_SLD8
{
  [self writeMDSWord: _state.LF offset: 9 value: [self pop]];
  [self writeMDSWord: _state.LF offset: 8 value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x75_SLDB_alpha. */
- (void) OPC_x75_SLDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self writeMDSWord: _state.LF offset: alpha + 1 value: [self pop]];
  [self writeMDSWord: _state.LF offset: alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x2D_PL0. */
- (void) OPC_x2D_PL0
{
  [self writeMDSWord: _state.LF value: [self popRecover]];
}

/* Ch07_Assignment_Instructions: OPC_x2E_PL1. */
- (void) OPC_x2E_PL1
{
  [self writeMDSWord: _state.LF offset: 1 value: [self popRecover]];
}

/* Ch07_Assignment_Instructions: OPC_x2F_PL2. */
- (void) OPC_x2F_PL2
{
  [self writeMDSWord: _state.LF offset: 2 value: [self popRecover]];
}

/* Ch07_Assignment_Instructions: OPC_x30_PL3. */
- (void) OPC_x30_PL3
{
  [self writeMDSWord: _state.LF offset: 3 value: [self popRecover]];
}

/* Ch07_Assignment_Instructions: OPC_x31_PLB_alpha. */
- (void) OPC_x31_PLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self writeMDSWord: _state.LF offset: alpha value: [self popRecover]];
}

/* Ch07_Assignment_Instructions: OPC_x32_PLD0. */
- (void) OPC_x32_PLD0
{
  [self writeMDSWord: _state.LF offset: 1 value: [self pop]];
  [self writeMDSWord: _state.LF value: [self pop]];
  [self recover];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x33_PLDB_alpha. */
- (void) OPC_x33_PLDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self writeMDSWord: _state.LF offset: alpha + 1 value: [self pop]];
  [self writeMDSWord: _state.LF offset: alpha value: [self pop]];
  [self recover];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_xBB_AL0IB_alpha. */
- (void) OPC_xBB_AL0IB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (int16_t) (((int16_t) [self readMDSWord: _state.LF] & 0xFFFF)
                        + alpha)];
}

/* Ch07_Assignment_Instructions: OPCo_xDA_GA0. */
- (void) OPCo_xDA_GA0
{
  [self push: _state.GF16];
}

/* Ch07_Assignment_Instructions: OPCn_xDA_GA0. */
- (void) OPCn_xDA_GA0
{
  [self push: _state.GF32 & 0xFFFF];
}

/* Ch07_Assignment_Instructions: OPCo_xDB_GA1. */
- (void) OPCo_xDB_GA1
{
  [self push: _state.GF16 + 1];
}

/* Ch07_Assignment_Instructions: OPCn_xDB_GA1. */
- (void) OPCn_xDB_GA1
{
  [self push: (_state.GF32 + 1) & 0xFFFF];
}

/* Ch07_Assignment_Instructions: OPCo_xDC_GAB_alpha. */
- (void) OPCo_xDC_GAB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: _state.GF16 + alpha];
}

/* Ch07_Assignment_Instructions: OPCn_xDC_GAB_alpha. */
- (void) OPCn_xDC_GAB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (_state.GF32 + alpha) & 0xFFFF];
}

/* Ch07_Assignment_Instructions: OPCo_xDD_GAW_word. */
- (void) OPCo_xDD_GAW_word
{
  int64_t word = [self nextCodeWord];
  [self push: _state.GF16 + word];
}

/* Ch07_Assignment_Instructions: OPCn_xDD_GAW_word. */
- (void) OPCn_xDD_GAW_word
{
  int64_t word = [self nextCodeWord];
  [self push: (_state.GF32 + word) & 0xFFFF];
}

/* Ch07_Assignment_Instructions: OPCn_xFA_LGA0. */
- (void) OPCn_xFA_LGA0
{
  [self pushLong: _state.GF32];
}

/* Ch07_Assignment_Instructions: OPCn_xFB_LGAB_alpha. */
- (void) OPCn_xFB_LGAB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self pushLong: _state.GF32 + alpha];
}

/* Ch07_Assignment_Instructions: OPCn_xFC_LGAW_word. */
- (void) OPCn_xFC_LGAW_word
{
  int64_t word = [self nextCodeWord];
  [self pushLong: _state.GF32 + word];
}

/* Ch07_Assignment_Instructions: OPCo_x34_LG0. */
- (void) OPCo_x34_LG0
{
  [self push: (int16_t) [self readMDSWord: _state.GF16]];
}

/* Ch07_Assignment_Instructions: OPCn_x34_LG0. */
- (void) OPCn_x34_LG0
{
  [self push: (int16_t) [_memory readWord: _state.GF32]];
}

/* Ch07_Assignment_Instructions: OPCo_x35_LG1. */
- (void) OPCo_x35_LG1
{
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: 1]];
}

/* Ch07_Assignment_Instructions: OPCn_x35_LG1. */
- (void) OPCn_x35_LG1
{
  [self push: (int16_t) [_memory readWord: _state.GF32 + 1]];
}

/* Ch07_Assignment_Instructions: OPCo_x36_LG2. */
- (void) OPCo_x36_LG2
{
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: 2]];
}

/* Ch07_Assignment_Instructions: OPCn_x36_LG2. */
- (void) OPCn_x36_LG2
{
  [self push: (int16_t) [_memory readWord: _state.GF32 + 2]];
}

/* Ch07_Assignment_Instructions: OPCo_x37_LGB_alpha. */
- (void) OPCo_x37_LGB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: alpha]];
}

/* Ch07_Assignment_Instructions: OPCn_x37_LGB_alpha. */
- (void) OPCn_x37_LGB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (int16_t) [_memory readWord: _state.GF32 + alpha]];
}

/* Ch07_Assignment_Instructions: OPCo_x38_LGD0. */
- (void) OPCo_x38_LGD0
{
  [self push: (int16_t) [self readMDSWord: _state.GF16]];
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: 1]];
}

/* Ch07_Assignment_Instructions: OPCn_x38_LGD0. */
- (void) OPCn_x38_LGD0
{
  [self push: (int16_t) [_memory readWord: _state.GF32]];
  [self push: (int16_t) [_memory readWord: _state.GF32 + 1]];
}

/* Ch07_Assignment_Instructions: OPCo_x39_LGD2. */
- (void) OPCo_x39_LGD2
{
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: 2]];
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: 3]];
}

/* Ch07_Assignment_Instructions: OPCn_x39_LGD2. */
- (void) OPCn_x39_LGD2
{
  [self push: (int16_t) [_memory readWord: _state.GF32 + 2]];
  [self push: (int16_t) [_memory readWord: _state.GF32 + 3]];
}

/* Ch07_Assignment_Instructions: OPCo_x3A_LGDB_alpha. */
- (void) OPCo_x3A_LGDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: alpha]];
  [self push: (int16_t) [self readMDSWord: _state.GF16 offset: alpha + 1]];
}

/* Ch07_Assignment_Instructions: OPCn_x3A_LGDB_alpha. */
- (void) OPCn_x3A_LGDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self push: (int16_t) [_memory readWord: _state.GF32 + alpha]];
  [self push: (int16_t) [_memory readWord: _state.GF32 + alpha + 1]];
}

/* Ch07_Assignment_Instructions: OPCo_x3B_SGB_alpha. */
- (void) OPCo_x3B_SGB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self writeMDSWord: _state.GF16 offset: alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPCn_x3B_SGB_alpha. */
- (void) OPCn_x3B_SGB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [_memory writeWord: _state.GF32 + alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPCo_x76_SGDB_alpha. */
- (void) OPCo_x76_SGDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [self writeMDSWord: _state.GF16 offset: alpha + 1 value: [self pop]];
  [self writeMDSWord: _state.GF16 offset: alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPCn_x76_SGDB_alpha. */
- (void) OPCn_x76_SGDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  [_memory writeWord: _state.GF32 + alpha + 1 value: [self pop]];
  [_memory writeWord: _state.GF32 + alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x40_R0. */
- (void) OPC_x40_R0
{
  int16_t pointer = [self pop];
  [self push: (int16_t) [self readMDSWord: pointer]];
}

/* Ch07_Assignment_Instructions: OPC_x41_R1. */
- (void) OPC_x41_R1
{
  int16_t pointer = [self pop];
  [self push: (int16_t) [self readMDSWord: pointer offset: 1]];
}

/* Ch07_Assignment_Instructions: OPC_x42_RB_alpha. */
- (void) OPC_x42_RB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t pointer = [self pop];
  [self push: (int16_t) [self readMDSWord: pointer offset: alpha]];
}

/* Ch07_Assignment_Instructions: OPC_x43_RL0. */
- (void) OPC_x43_RL0
{
  int64_t longPointer = [self popLong];
  [self push: (int16_t) [_memory readWord: longPointer]];
}

/* Ch07_Assignment_Instructions: OPC_x44_RLB_alpha. */
- (void) OPC_x44_RLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t longPointer = [self popLong];
  [self push: (int16_t) [_memory readWord: longPointer + alpha]];
}

/* Ch07_Assignment_Instructions: OPC_x45_RD0. */
- (void) OPC_x45_RD0
{
  int16_t pointer = [self pop];
  int16_t u = (int16_t) [self readMDSWord: pointer];
  int16_t v = (int16_t) [self readMDSWord: pointer offset: 1];
  [self push: u];
  [self push: v];
}

/* Ch07_Assignment_Instructions: OPC_x46_RDB_alpha. */
- (void) OPC_x46_RDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t pointer = [self pop];
  int16_t u = (int16_t) [self readMDSWord: pointer offset: alpha];
  int16_t v = (int16_t) [self readMDSWord: pointer offset: alpha + 1];
  [self push: u];
  [self push: v];
}

/* Ch07_Assignment_Instructions: OPC_x47_RDL0. */
- (void) OPC_x47_RDL0
{
  int64_t longPointer = [self popLong];
  int16_t u = (int16_t) [_memory readWord: longPointer];
  int16_t v = (int16_t) [_memory readWord: longPointer + 1];
  [self push: u];
  [self push: v];
}

/* Ch07_Assignment_Instructions: OPC_x48_RDLB_alpha. */
- (void) OPC_x48_RDLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t longPointer = [self popLong];
  int16_t u = (int16_t) [_memory readWord: longPointer + alpha];
  int16_t v = (int16_t) [_memory readWord: longPointer + alpha + 1];
  [self push: u];
  [self push: v];
}

/* Ch07_Assignment_Instructions: ESC_x1B_RC_alpha. */
- (void) ESC_x1B_RC_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t offset = [self pop] & 0xFFFF;
  [self push: (int16_t) [self readCode: offset + alpha]];
}

/* Ch07_Assignment_Instructions: OPC_x49_W0. */
- (void) OPC_x49_W0
{
  int16_t pointer = [self pop];
  [self writeMDSWord: pointer value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x4A_WB_alpha. */
- (void) OPC_x4A_WB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t pointer = [self pop];
  [self writeMDSWord: pointer offset: alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x4C_WLB_alpha. */
- (void) OPC_x4C_WLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t longPointer = [self popLong];
  [_memory writeWord: longPointer + alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x4E_WDB_alpha. */
- (void) OPC_x4E_WDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t pointer = [self pop];
  [self writeMDSWord: pointer offset: alpha + 1 value: [self pop]];
  [self writeMDSWord: pointer offset: alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x51_WDLB_alpha. */
- (void) OPC_x51_WDLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t longPointer = [self popLong];
  [_memory writeWord: longPointer + alpha + 1 value: [self pop]];
  [_memory writeWord: longPointer + alpha value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x4B_PSB_alpha. */
- (void) OPC_x4B_PSB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t u = [self pop];
  int16_t pointer = [self pop];
  [self writeMDSWord: pointer offset: alpha value: u];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x4F_PSD0. */
- (void) OPC_x4F_PSD0
{
  int16_t v = [self pop];
  int16_t u = [self pop];
  int16_t pointer = [self pop];
  [self writeMDSWord: pointer offset: 1 value: v];
  [self writeMDSWord: pointer value: u];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x50_PSDB_alpha. */
- (void) OPC_x50_PSDB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t v = [self pop];
  int16_t u = [self pop];
  int16_t pointer = [self pop];
  [self writeMDSWord: pointer offset: alpha + 1 value: v];
  [self writeMDSWord: pointer offset: alpha value: u];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x4D_PSLB_alpha. */
- (void) OPC_x4D_PSLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t u = [self pop];
  int64_t longPointer = [self popLong];
  [_memory writeWord: longPointer + alpha value: u];
  [self recover];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x52_PSDLB_alpha. */
- (void) OPC_x52_PSDLB_alpha
{
  int64_t alpha = [self nextCodeByte];
  int16_t v = [self pop];
  int16_t u = [self pop];
  int64_t longPointer = [self popLong];
  [_memory writeWord: longPointer + alpha + 1 value: v];
  [_memory writeWord: longPointer + alpha value: u];
  [self recover];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x53_RLI00. */
- (void) OPC_x53_RLI00
{
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF];
  [self push: (int16_t) [self readMDSWord: pointer]];
}

/* Ch07_Assignment_Instructions: OPC_x54_RLI01. */
- (void) OPC_x54_RLI01
{
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF];
  [self push: (int16_t) [self readMDSWord: pointer offset: 1]];
}

/* Ch07_Assignment_Instructions: OPC_x55_RLI02. */
- (void) OPC_x55_RLI02
{
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF];
  [self push: (int16_t) [self readMDSWord: pointer offset: 2]];
}

/* Ch07_Assignment_Instructions: OPC_x56_RLI03. */
- (void) OPC_x56_RLI03
{
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF];
  [self push: (int16_t) [self readMDSWord: pointer offset: 3]];
}

/* Ch07_Assignment_Instructions: OPC_x57_RLIP_pair. */
- (void) OPC_x57_RLIP_pair
{
  int64_t pair = [self nextCodeByte];
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF + (pair >> 4)];
  [self push: (int16_t) [self readMDSWord: pointer + (pair & 0x0F)]];
}

/* Ch07_Assignment_Instructions: OPC_x58_RLILP_pair. */
- (void) OPC_x58_RLILP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t longPointer = [self readMDSDoubleWord: _state.LF + (pair >> 4)];
  [self push: (int16_t) [_memory readWord: longPointer + (pair & 0x0F)]];
}

/* Ch07_Assignment_Instructions: OPCo_x5C_RGIP_pair. */
- (void) OPCo_x5C_RGIP_pair
{
  int64_t pair = [self nextCodeByte];
  int16_t pointer = (int16_t) [self readMDSWord: _state.GF16 + (pair >> 4)];
  [self push: (int16_t) [self readMDSWord: pointer + (pair & 0x0F)]];
}

/* Ch07_Assignment_Instructions: OPCn_x5C_RGIP_pair. */
- (void) OPCn_x5C_RGIP_pair
{
  int64_t pair = [self nextCodeByte];
  int16_t pointer = (int16_t) [_memory readWord: _state.GF32 + (pair >> 4)];
  [self push: (int16_t) [self readMDSWord: pointer + (pair & 0x0F)]];
}

/* Ch07_Assignment_Instructions: OPCo_x5D_RGILP_pair. */
- (void) OPCo_x5D_RGILP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t longPointer = [self readMDSDoubleWord: _state.GF16 + (pair >> 4)];
  [self push: (int16_t) [_memory readWord: longPointer + (pair & 0x0F)]];
}

/* Ch07_Assignment_Instructions: OPCn_x5D_RGILP_pair. */
- (void) OPCn_x5D_RGILP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t longPointer = [_memory readDoubleWord: _state.GF32 + (pair >> 4)];
  [self push: (int16_t) [_memory readWord: longPointer + (pair & 0x0F)]];
}

/* Ch07_Assignment_Instructions: OPC_x59_RLDI00. */
- (void) OPC_x59_RLDI00
{
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF];
  int16_t u = (int16_t) [self readMDSWord: pointer];
  int16_t v = (int16_t) [self readMDSWord: pointer + 1];
  [self push: u];
  [self push: v];
}

/* Ch07_Assignment_Instructions: OPC_x5A_RLDIP_pair. */
- (void) OPC_x5A_RLDIP_pair
{
  int64_t pair = [self nextCodeByte];
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF + (pair >> 4)];
  int16_t u = (int16_t) [self readMDSWord: pointer + (pair & 0x0F)];
  int16_t v = (int16_t) [self readMDSWord: pointer + (pair & 0x0F) + 1];
  [self push: u];
  [self push: v];
}

/* Ch07_Assignment_Instructions: OPC_x5B_RLDILP_pair. */
- (void) OPC_x5B_RLDILP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t longPointer = [self readMDSDoubleWord: _state.LF + (pair >> 4)];
  int16_t u = (int16_t) [_memory readWord: longPointer + (pair & 0x0F)];
  int16_t v = (int16_t) [_memory readWord: longPointer + (pair & 0x0F) + 1];
  [self push: u];
  [self push: v];
}

/* Ch07_Assignment_Instructions: OPC_x5E_WLIP_pair. */
- (void) OPC_x5E_WLIP_pair
{
  int64_t pair = [self nextCodeByte];
  int16_t pointer = (int16_t) [self readMDSWord: _state.LF + (pair >> 4)];
  [self writeMDSWord: pointer + (pair & 0x0F) value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x5F_WLILP_pair. */
- (void) OPC_x5F_WLILP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t longPointer = [self readMDSDoubleWord: _state.LF + (pair >> 4)];
  [_memory writeWord: longPointer + (pair & 0x0F) value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x60_WLDILP_pair. */
- (void) OPC_x60_WLDILP_pair
{
  int64_t pair = [self nextCodeByte];
  int64_t longPointer = [self readMDSDoubleWord: _state.LF + (pair >> 4)];
  [_memory writeWord: longPointer + (pair & 0x0F) + 1 value: [self pop]];
  [_memory writeWord: longPointer + (pair & 0x0F) value: [self pop]];
}

/* Ch07_Assignment_Instructions: OPC_x61_RS_alpha. */
- (void) OPC_x61_RS_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t index = [self pop] & 0xFFFF;
  int64_t pointer = [self pop] & 0xFFFF;
  [self push: [_memory fetchByte: [self lengthenPointer: pointer]
                         offset: alpha + index]];
}

/* Ch07_Assignment_Instructions: OPC_x62_RLS_alpha. */
- (void) OPC_x62_RLS_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t index = [self pop] & 0xFFFF;
  int64_t longPointer = [self popLong];
  [self push: [_memory fetchByte: longPointer offset: alpha + index]];
}

/* Ch07_Assignment_Instructions: OPC_x63_WS_alpha. */
- (void) OPC_x63_WS_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t index = [self pop] & 0xFFFF;
  int64_t pointer = [self pop] & 0xFFFF;
  int16_t data = (int16_t) ([self pop] & 0x00FF);
  [_memory storeByte: [self lengthenPointer: pointer]
              offset: alpha + index
               value: data];
}

/* Ch07_Assignment_Instructions: OPC_x64_WLS_alpha. */
- (void) OPC_x64_WLS_alpha
{
  int64_t alpha = [self nextCodeByte];
  int64_t index = [self pop] & 0xFFFF;
  int64_t longPointer = [self popLong];
  int16_t data = (int16_t) ([self pop] & 0x00FF);
  [_memory storeByte: longPointer offset: alpha + index value: data];
}

/* Ch07_Assignment_Instructions: OPC_x66_RF_word. */
- (void) OPC_x66_RF_word
{
  int64_t fieldDesc = [self nextCodeWord];
  int64_t pointer = [self pop] & 0x0FFFF;
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [self readMDSWord: pointer
                                                    offset: fieldDesc >> 8]
                 specification: fieldDesc & 0xFF]];
}

/* Ch07_Assignment_Instructions: OPC_x65_R0F_alpha. */
- (void) OPC_x65_R0F_alpha
{
  int64_t spec = [self nextCodeByte];
  int64_t pointer = [self pop] & 0x0FFFF;
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [self readMDSWord: pointer]
                 specification: spec]];
}

/* Ch07_Assignment_Instructions: OPC_x68_RLF_word. */
- (void) OPC_x68_RLF_word
{
  int64_t fieldDesc = [self nextCodeWord];
  int64_t longPointer = [self popLong];
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [_memory
                                   readWord: longPointer + (fieldDesc >> 8)]
                 specification: fieldDesc & 0xFF]];
}

/* Ch07_Assignment_Instructions: OPC_x67_RL0F_alpha. */
- (void) OPC_x67_RL0F_alpha
{
  int64_t spec = [self nextCodeByte];
  int64_t longPointer = [self popLong];
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [_memory readWord: longPointer]
                 specification: spec]];
}

/* Ch07_Assignment_Instructions: OPC_x69_RLFS. */
- (void) OPC_x69_RLFS
{
  int64_t fieldDesc = [self pop] & 0xFFFF;
  int64_t longPointer = [self popLong];
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [_memory
                                   readWord: longPointer + (fieldDesc >> 8)]
                 specification: fieldDesc & 0xFF]];
}

/* Ch07_Assignment_Instructions: ESC_x1A_RCFS. */
- (void) ESC_x1A_RCFS
{
  int64_t fieldDesc = [self pop] & 0xFFFF;
  int64_t offset = [self pop] & 0xFFFF;
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [self
                                   readCode: offset + (fieldDesc >> 8)]
                 specification: fieldDesc & 0xFF]];
}

/* Ch07_Assignment_Instructions: OPC_x6A_RLIPF_alphabeta. */
- (void) OPC_x6A_RLIPF_alphabeta
{
  int64_t pair = [self nextCodeByte];
  int64_t spec = [self nextCodeByte];
  int64_t pointer
      = (int16_t) [self readMDSWord: _state.LF offset: pair >> 4] & 0x0FFFF;
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [self readMDSWord: pointer
                                                    offset: pair & 0x0F]
                 specification: spec]];
}

/* Ch07_Assignment_Instructions: OPC_x6B_RLILPF_alphabeta. */
- (void) OPC_x6B_RLILPF_alphabeta
{
  int64_t pair = [self nextCodeByte];
  int64_t spec = [self nextCodeByte];
  int64_t longPointer = [self readMDSDoubleWord: _state.LF offset: pair >> 4];
  [self push: (int16_t) [DBMemory
                 fieldFromWord: (int16_t) [_memory
                                   readWord: longPointer + (pair & 0x0F)]
                 specification: spec]];
}

/* Ch07_Assignment_Instructions: OPC_x6D_WF_word. */
- (void) OPC_x6D_WF_word
{
  int64_t fieldDesc = [self nextCodeWord];
  int64_t pointer = [self pop] & 0xFFFF;
  int16_t data = [self pop];
  int64_t offset = fieldDesc >> 8;
  int16_t src = (int16_t) [self readMDSWord: pointer offset: offset];
  [self writeMDSWord: pointer
              offset: offset
               value: [DBMemory word: src
                         specification: fieldDesc & 0xFF
                             withField: data]];
}

/* Ch07_Assignment_Instructions: OPC_x6C_W0F_alpha. */
- (void) OPC_x6C_W0F_alpha
{
  int64_t spec = [self nextCodeByte];
  int64_t pointer = [self pop] & 0x0FFFF;
  int16_t data = [self pop];
  int16_t src = (int16_t) [self readMDSWord: pointer];
  [self writeMDSWord: pointer
               value: [DBMemory word: src specification: spec withField: data]];
}

/* Ch07_Assignment_Instructions: OPC_x72_WLF_word. */
- (void) OPC_x72_WLF_word
{
  int64_t fieldDesc = [self nextCodeWord];
  int64_t longPointer = [self popLong];
  int16_t data = [self pop];
  longPointer += fieldDesc >> 8;
  int16_t src = (int16_t) [_memory readWord: longPointer];
  [_memory writeWord: longPointer
               value: [DBMemory word: src
                         specification: fieldDesc & 0xFF
                             withField: data]];
}

/* Ch07_Assignment_Instructions: OPC_x71_WL0F_alpha. */
- (void) OPC_x71_WL0F_alpha
{
  int64_t spec = [self nextCodeByte];
  int64_t longPointer = [self popLong];
  int16_t data = [self pop];
  int16_t src = (int16_t) [_memory readWord: longPointer];
  [_memory writeWord: longPointer
               value: [DBMemory word: src specification: spec withField: data]];
}

/* Ch07_Assignment_Instructions: OPC_x74_WLFS. */
- (void) OPC_x74_WLFS
{
  int64_t fieldDesc = [self pop] & 0xFFFF;
  int64_t longPointer = [self popLong];
  int16_t data = [self pop];
  longPointer += fieldDesc >> 8;
  int16_t src = (int16_t) [_memory readWord: longPointer];
  [_memory writeWord: longPointer
               value: [DBMemory word: src
                         specification: fieldDesc & 0xFF
                             withField: data]];
}

/* Ch07_Assignment_Instructions: OPC_x70_WS0F_alpha. */
- (void) OPC_x70_WS0F_alpha
{
  int64_t spec = [self nextCodeByte];
  int16_t data = [self pop];
  int64_t pointer = [self pop] & 0x0FFFF;
  int16_t src = (int16_t) [self readMDSWord: pointer];
  [self writeMDSWord: pointer
               value: [DBMemory word: src specification: spec withField: data]];
}

/* Ch07_Assignment_Instructions: OPC_x6F_PS0F. */
- (void) OPC_x6F_PS0F
{
  [self OPC_x70_WS0F_alpha];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x6E_PSF_word. */
- (void) OPC_x6E_PSF_word
{
  int64_t fieldDesc = [self nextCodeWord];
  int16_t data = [self pop];
  int64_t pointer = [self pop] & 0x0FFFF;
  int64_t offset = fieldDesc >> 8;
  int16_t src = (int16_t) [self readMDSWord: pointer offset: offset];
  [self writeMDSWord: pointer
              offset: offset
               value: [DBMemory word: src
                         specification: fieldDesc & 0xFF
                             withField: data]];
  [self recover];
}

/* Ch07_Assignment_Instructions: OPC_x73_PSLF_word. */
- (void) OPC_x73_PSLF_word
{
  int64_t fieldDesc = [self nextCodeWord];
  int16_t data = [self pop];
  int64_t longPointer = [self popLong];
  longPointer += fieldDesc >> 8;
  int16_t src = (int16_t) [_memory readWord: longPointer];
  [_memory writeWord: longPointer
               value: [DBMemory word: src
                         specification: fieldDesc & 0xFF
                             withField: data]];
  [self recover];
  [self recover];
}

@end
