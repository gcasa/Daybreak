/** <title>Internal opcode methods</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_INSTRUCTIONS_H
#define DAYBREAK_INSTRUCTIONS_H
#import "DBProcessor.h"
/** Internal methods corresponding to Dwarf opcode implementations. */
@interface DBProcessor (Instructions)
/** Execute the reference ESC_x07_SM instruction. */
- (void) ESC_x07_SM;
/** Execute the reference ESC_x09_GMF instruction. */
- (void) ESC_x09_GMF;
/** Execute the reference ESC_x08_SMF instruction. */
- (void) ESC_x08_SMF;
/** Execute the reference OPC_xF7_LP instruction. */
- (void) OPC_xF7_LP;
/** Execute the reference ESC_x1E_ROB_alpha instruction. */
- (void) ESC_x1E_ROB_alpha;
/** Execute the reference ESC_x1F_WOB_alpha instruction. */
- (void) ESC_x1F_WOB_alpha;
/** Execute the reference ESC_x79_RRMDS instruction. */
- (void) ESC_x79_RRMDS;
/** Execute the reference ESC_x71_WRMDS instruction. */
- (void) ESC_x71_WRMDS;
/** Execute the reference OPC_xA2_REC instruction. */
- (void) OPC_xA2_REC;
/** Execute the reference OPC_xA3_REC2 instruction. */
- (void) OPC_xA3_REC2;
/** Execute the reference OPC_xA4_DIS instruction. */
- (void) OPC_xA4_DIS;
/** Execute the reference OPC_xA5_DIS2 instruction. */
- (void) OPC_xA5_DIS2;
/** Execute the reference OPC_xA6_EXCH instruction. */
- (void) OPC_xA6_EXCH;
/** Execute the reference OPC_xA7_DEXCH instruction. */
- (void) OPC_xA7_DEXCH;
/** Execute the reference OPC_xA8_DUP instruction. */
- (void) OPC_xA8_DUP;
/** Execute the reference OPC_xA9_DDUP instruction. */
- (void) OPC_xA9_DDUP;
/** Execute the reference OPC_xAA_EXDIS instruction. */
- (void) OPC_xAA_EXDIS;
/** Execute the reference OPC_x3C_BNDCK instruction. */
- (void) OPC_x3C_BNDCK;
/** Execute the reference ESC_x24_BNDCKL instruction. */
- (void) ESC_x24_BNDCKL;
/** Execute the reference ESC_x25_NILCK instruction. */
- (void) ESC_x25_NILCK;
/** Execute the reference ESC_x26_NILCKL instruction. */
- (void) ESC_x26_NILCKL;
/** Execute the reference OPC_xAB_NEG instruction. */
- (void) OPC_xAB_NEG;
/** Execute the reference OPC_xAC_INC instruction. */
- (void) OPC_xAC_INC;
/** Execute the reference OPC_xAE_DINC instruction. */
- (void) OPC_xAE_DINC;
/** Execute the reference OPC_xAD_DEC instruction. */
- (void) OPC_xAD_DEC;
/** Execute the reference OPC_xB4_ADDSB_alpha instruction. */
- (void) OPC_xB4_ADDSB_alpha;
/** Execute the reference OPC_xAF_DBL instruction. */
- (void) OPC_xAF_DBL;
/** Execute the reference OPC_xB0_DDBL instruction. */
- (void) OPC_xB0_DDBL;
/** Execute the reference OPC_xB1_TRPL instruction. */
- (void) OPC_xB1_TRPL;
/** Execute the reference ESC_x18_LINT instruction. */
- (void) ESC_x18_LINT;
/** Execute the reference OPC_x7C_SHIFTSB_alpha instruction. */
- (void) OPC_x7C_SHIFTSB_alpha;
/** Execute the reference OPC_xB2_AND instruction. */
- (void) OPC_xB2_AND;
/** Execute the reference ESC_x13_DAND instruction. */
- (void) ESC_x13_DAND;
/** Execute the reference OPC_xB3_IOR instruction. */
- (void) OPC_xB3_IOR;
/** Execute the reference ESC_x14_DIOR instruction. */
- (void) ESC_x14_DIOR;
/** Execute the reference ESC_x12_XOR instruction. */
- (void) ESC_x12_XOR;
/** Execute the reference ESC_x15_DXOR instruction. */
- (void) ESC_x15_DXOR;
/** Execute the reference OPC_x7B_SHIFT instruction. */
- (void) OPC_x7B_SHIFT;
/** Execute the reference ESC_x17_DSHIFT instruction. */
- (void) ESC_x17_DSHIFT;
/** Execute the reference ESC_x16_ROTATE instruction. */
- (void) ESC_x16_ROTATE;
/** Execute the reference OPC_xB5_ADD instruction. */
- (void) OPC_xB5_ADD;
/** Execute the reference OPC_xB6_SUB instruction. */
- (void) OPC_xB6_SUB;
/** Execute the reference OPC_xB7_DADD instruction. */
- (void) OPC_xB7_DADD;
/** Execute the reference OPC_xB8_DSUB instruction. */
- (void) OPC_xB8_DSUB;
/** Execute the reference OPC_xB9_ADC instruction. */
- (void) OPC_xB9_ADC;
/** Execute the reference OPC_xBA_ACD instruction. */
- (void) OPC_xBA_ACD;
/** Execute the reference OPC_xBC_MUL instruction. */
- (void) OPC_xBC_MUL;
/** Execute the reference ESC_x30_DMUL instruction. */
- (void) ESC_x30_DMUL;
/** Execute the reference ESC_x31_SDIV instruction. */
- (void) ESC_x31_SDIV;
/** Execute the reference ESC_x1C_UDIV instruction. */
- (void) ESC_x1C_UDIV;
/** Execute the reference ESC_x1D_LUDIV instruction. */
- (void) ESC_x1D_LUDIV;
/** Execute the reference ESC_x32_SDDIV instruction. */
- (void) ESC_x32_SDDIV;
/** Execute the reference ESC_x33_UDDIV instruction. */
- (void) ESC_x33_UDDIV;
/** Execute the reference OPC_xBD_DCMP instruction. */
- (void) OPC_xBD_DCMP;
/** Execute the reference OPC_xBE_UDCMP instruction. */
- (void) OPC_xBE_UDCMP;
/** Execute the reference ESC_x40_FADD instruction. */
- (void) ESC_x40_FADD;
/** Execute the reference ESC_x41_FSUB instruction. */
- (void) ESC_x41_FSUB;
/** Execute the reference ESC_x42_FMUL instruction. */
- (void) ESC_x42_FMUL;
/** Execute the reference ESC_x43_FDIV instruction. */
- (void) ESC_x43_FDIV;
/** Execute the reference ESC_x44_FCOMP instruction. */
- (void) ESC_x44_FCOMP;
/** Execute the reference ESC_x46_FLOAT instruction. */
- (void) ESC_x46_FLOAT;
/** Execute the reference OPC_x81_J2 instruction. */
- (void) OPC_x81_J2;
/** Execute the reference OPC_x82_J3 instruction. */
- (void) OPC_x82_J3;
/** Execute the reference OPC_x83_J4 instruction. */
- (void) OPC_x83_J4;
/** Execute the reference OPC_x84_J5 instruction. */
- (void) OPC_x84_J5;
/** Execute the reference OPC_x85_J6 instruction. */
- (void) OPC_x85_J6;
/** Execute the reference OPC_x86_J7 instruction. */
- (void) OPC_x86_J7;
/** Execute the reference OPC_x87_J8 instruction. */
- (void) OPC_x87_J8;
/** Execute the reference OPC_x88_JB_salpha instruction. */
- (void) OPC_x88_JB_salpha;
/** Execute the reference OPC_x89_JW_sword instruction. */
- (void) OPC_x89_JW_sword;
/** Execute the reference ESC_x19_JS instruction. */
- (void) ESC_x19_JS;
/** Execute the reference OPC_x80_CATCH_alpha instruction. */
- (void) OPC_x80_CATCH_alpha;
/** Execute the reference OPC_x98_JZ3 instruction. */
- (void) OPC_x98_JZ3;
/** Execute the reference OPC_x99_JZ4 instruction. */
- (void) OPC_x99_JZ4;
/** Execute the reference OPC_x9B_JNZ3 instruction. */
- (void) OPC_x9B_JNZ3;
/** Execute the reference OPC_x9C_JNZ4 instruction. */
- (void) OPC_x9C_JNZ4;
/** Execute the reference OPC_x9A_JZB_salpha instruction. */
- (void) OPC_x9A_JZB_salpha;
/** Execute the reference OPC_x9D_JNZB_salpha instruction. */
- (void) OPC_x9D_JNZB_salpha;
/** Execute the reference OPC_x8B_JEB_salpha instruction. */
- (void) OPC_x8B_JEB_salpha;
/** Execute the reference OPC_x8E_JNEB_salpha instruction. */
- (void) OPC_x8E_JNEB_salpha;
/** Execute the reference OPC_x9E_JDEB_salpha instruction. */
- (void) OPC_x9E_JDEB_salpha;
/** Execute the reference OPC_x9F_JDNEB_salpha instruction. */
- (void) OPC_x9F_JDNEB_salpha;
/** Execute the reference OPC_x8A_JEP_pair instruction. */
- (void) OPC_x8A_JEP_pair;
/** Execute the reference OPC_x8D_JNEP_pair instruction. */
- (void) OPC_x8D_JNEP_pair;
/** Execute the reference OPC_x8C_JEBB_alphasbeta instruction. */
- (void) OPC_x8C_JEBB_alphasbeta;
/** Execute the reference OPC_x8F_JNEBB_alphasbeta instruction. */
- (void) OPC_x8F_JNEBB_alphasbeta;
/** Execute the reference OPC_x90_JLB_salpha instruction. */
- (void) OPC_x90_JLB_salpha;
/** Execute the reference OPC_x93_JLEB_salpha instruction. */
- (void) OPC_x93_JLEB_salpha;
/** Execute the reference OPC_x92_JGB_salpha instruction. */
- (void) OPC_x92_JGB_salpha;
/** Execute the reference OPC_x91_JGEB_salpha instruction. */
- (void) OPC_x91_JGEB_salpha;
/** Execute the reference OPC_x94_JULB_salpha instruction. */
- (void) OPC_x94_JULB_salpha;
/** Execute the reference OPC_x97_JULEB_salpha instruction. */
- (void) OPC_x97_JULEB_salpha;
/** Execute the reference OPC_x96_JUGB_salpha instruction. */
- (void) OPC_x96_JUGB_salpha;
/** Execute the reference OPC_x95_JUGEB_salpha instruction. */
- (void) OPC_x95_JUGEB_salpha;
/** Execute the reference OPC_xA0_JIB_word instruction. */
- (void) OPC_xA0_JIB_word;
/** Execute the reference OPC_xA1_JIW_word instruction. */
- (void) OPC_xA1_JIW_word;
/** Execute the reference OPC_xCB_LIN1 instruction. */
- (void) OPC_xCB_LIN1;
/** Execute the reference OPC_xCC_LINI instruction. */
- (void) OPC_xCC_LINI;
/** Execute the reference OPC_xD1_LID0 instruction. */
- (void) OPC_xD1_LID0;
/** Execute the reference OPC_xC0_LI0 instruction. */
- (void) OPC_xC0_LI0;
/** Execute the reference OPC_xC1_LI1 instruction. */
- (void) OPC_xC1_LI1;
/** Execute the reference OPC_xC2_LI2 instruction. */
- (void) OPC_xC2_LI2;
/** Execute the reference OPC_xC3_LI3 instruction. */
- (void) OPC_xC3_LI3;
/** Execute the reference OPC_xC4_LI4 instruction. */
- (void) OPC_xC4_LI4;
/** Execute the reference OPC_xC5_LI5 instruction. */
- (void) OPC_xC5_LI5;
/** Execute the reference OPC_xC6_LI6 instruction. */
- (void) OPC_xC6_LI6;
/** Execute the reference OPC_xC7_LI7 instruction. */
- (void) OPC_xC7_LI7;
/** Execute the reference OPC_xC8_LI8 instruction. */
- (void) OPC_xC8_LI8;
/** Execute the reference OPC_xC9_LI9 instruction. */
- (void) OPC_xC9_LI9;
/** Execute the reference OPC_xCA_LI10 instruction. */
- (void) OPC_xCA_LI10;
/** Execute the reference OPC_xCD_LIB_alpha instruction. */
- (void) OPC_xCD_LIB_alpha;
/** Execute the reference OPC_xCF_LINB_alpha instruction. */
- (void) OPC_xCF_LINB_alpha;
/** Execute the reference OPC_xD0_LIHB_alpha instruction. */
- (void) OPC_xD0_LIHB_alpha;
/** Execute the reference OPC_xCE_LIW_word instruction. */
- (void) OPC_xCE_LIW_word;
/** Execute the reference OPC_xD2_LA0 instruction. */
- (void) OPC_xD2_LA0;
/** Execute the reference OPC_xD3_LA1 instruction. */
- (void) OPC_xD3_LA1;
/** Execute the reference OPC_xD4_LA2 instruction. */
- (void) OPC_xD4_LA2;
/** Execute the reference OPC_xD5_LA3 instruction. */
- (void) OPC_xD5_LA3;
/** Execute the reference OPC_xD6_LA6 instruction. */
- (void) OPC_xD6_LA6;
/** Execute the reference OPC_xD7_LA8 instruction. */
- (void) OPC_xD7_LA8;
/** Execute the reference OPC_xD8_LAB_alpha instruction. */
- (void) OPC_xD8_LAB_alpha;
/** Execute the reference OPC_xD9_LAW_word instruction. */
- (void) OPC_xD9_LAW_word;
/** Execute the reference OPC_x01_LL0 instruction. */
- (void) OPC_x01_LL0;
/** Execute the reference OPC_x02_LL1 instruction. */
- (void) OPC_x02_LL1;
/** Execute the reference OPC_x03_LL2 instruction. */
- (void) OPC_x03_LL2;
/** Execute the reference OPC_x04_LL3 instruction. */
- (void) OPC_x04_LL3;
/** Execute the reference OPC_x05_LL4 instruction. */
- (void) OPC_x05_LL4;
/** Execute the reference OPC_x06_LL5 instruction. */
- (void) OPC_x06_LL5;
/** Execute the reference OPC_x07_LL6 instruction. */
- (void) OPC_x07_LL6;
/** Execute the reference OPC_x08_LL7 instruction. */
- (void) OPC_x08_LL7;
/** Execute the reference OPC_x09_LL8 instruction. */
- (void) OPC_x09_LL8;
/** Execute the reference OPC_x0A_LL9 instruction. */
- (void) OPC_x0A_LL9;
/** Execute the reference OPC_x0B_LL10 instruction. */
- (void) OPC_x0B_LL10;
/** Execute the reference OPC_x0C_LL11 instruction. */
- (void) OPC_x0C_LL11;
/** Execute the reference OPC_x0D_LLB_alpha instruction. */
- (void) OPC_x0D_LLB_alpha;
/** Execute the reference OPC_x0E_LLD0 instruction. */
- (void) OPC_x0E_LLD0;
/** Execute the reference OPC_x0F_LLD1 instruction. */
- (void) OPC_x0F_LLD1;
/** Execute the reference OPC_x10_LLD2 instruction. */
- (void) OPC_x10_LLD2;
/** Execute the reference OPC_x11_LLD3 instruction. */
- (void) OPC_x11_LLD3;
/** Execute the reference OPC_x12_LLD4 instruction. */
- (void) OPC_x12_LLD4;
/** Execute the reference OPC_x13_LLD5 instruction. */
- (void) OPC_x13_LLD5;
/** Execute the reference OPC_x14_LLD6 instruction. */
- (void) OPC_x14_LLD6;
/** Execute the reference OPC_x15_LLD7 instruction. */
- (void) OPC_x15_LLD7;
/** Execute the reference OPC_x16_LLD8 instruction. */
- (void) OPC_x16_LLD8;
/** Execute the reference OPC_x17_LLD10 instruction. */
- (void) OPC_x17_LLD10;
/** Execute the reference OPC_x18_LLDB_alpha instruction. */
- (void) OPC_x18_LLDB_alpha;
/** Execute the reference OPC_x19_SL0 instruction. */
- (void) OPC_x19_SL0;
/** Execute the reference OPC_x1A_SL1 instruction. */
- (void) OPC_x1A_SL1;
/** Execute the reference OPC_x1B_SL2 instruction. */
- (void) OPC_x1B_SL2;
/** Execute the reference OPC_x1C_SL3 instruction. */
- (void) OPC_x1C_SL3;
/** Execute the reference OPC_x1D_SL4 instruction. */
- (void) OPC_x1D_SL4;
/** Execute the reference OPC_x1E_SL5 instruction. */
- (void) OPC_x1E_SL5;
/** Execute the reference OPC_x1F_SL6 instruction. */
- (void) OPC_x1F_SL6;
/** Execute the reference OPC_x20_SL7 instruction. */
- (void) OPC_x20_SL7;
/** Execute the reference OPC_x21_SL8 instruction. */
- (void) OPC_x21_SL8;
/** Execute the reference OPC_x22_SL9 instruction. */
- (void) OPC_x22_SL9;
/** Execute the reference OPC_x23_SL10 instruction. */
- (void) OPC_x23_SL10;
/** Execute the reference OPC_x24_SLB_alpha instruction. */
- (void) OPC_x24_SLB_alpha;
/** Execute the reference OPC_x25_SLD0 instruction. */
- (void) OPC_x25_SLD0;
/** Execute the reference OPC_x26_SLD1 instruction. */
- (void) OPC_x26_SLD1;
/** Execute the reference OPC_x27_SLD2 instruction. */
- (void) OPC_x27_SLD2;
/** Execute the reference OPC_x28_SLD3 instruction. */
- (void) OPC_x28_SLD3;
/** Execute the reference OPC_x29_SLD4 instruction. */
- (void) OPC_x29_SLD4;
/** Execute the reference OPC_x2A_SLD5 instruction. */
- (void) OPC_x2A_SLD5;
/** Execute the reference OPC_x2B_SLD6 instruction. */
- (void) OPC_x2B_SLD6;
/** Execute the reference OPC_x2C_SLD8 instruction. */
- (void) OPC_x2C_SLD8;
/** Execute the reference OPC_x75_SLDB_alpha instruction. */
- (void) OPC_x75_SLDB_alpha;
/** Execute the reference OPC_x2D_PL0 instruction. */
- (void) OPC_x2D_PL0;
/** Execute the reference OPC_x2E_PL1 instruction. */
- (void) OPC_x2E_PL1;
/** Execute the reference OPC_x2F_PL2 instruction. */
- (void) OPC_x2F_PL2;
/** Execute the reference OPC_x30_PL3 instruction. */
- (void) OPC_x30_PL3;
/** Execute the reference OPC_x31_PLB_alpha instruction. */
- (void) OPC_x31_PLB_alpha;
/** Execute the reference OPC_x32_PLD0 instruction. */
- (void) OPC_x32_PLD0;
/** Execute the reference OPC_x33_PLDB_alpha instruction. */
- (void) OPC_x33_PLDB_alpha;
/** Execute the reference OPC_xBB_AL0IB_alpha instruction. */
- (void) OPC_xBB_AL0IB_alpha;
/** Execute the reference OPCo_xDA_GA0 instruction. */
- (void) OPCo_xDA_GA0;
/** Execute the reference OPCn_xDA_GA0 instruction. */
- (void) OPCn_xDA_GA0;
/** Execute the reference OPCo_xDB_GA1 instruction. */
- (void) OPCo_xDB_GA1;
/** Execute the reference OPCn_xDB_GA1 instruction. */
- (void) OPCn_xDB_GA1;
/** Execute the reference OPCo_xDC_GAB_alpha instruction. */
- (void) OPCo_xDC_GAB_alpha;
/** Execute the reference OPCn_xDC_GAB_alpha instruction. */
- (void) OPCn_xDC_GAB_alpha;
/** Execute the reference OPCo_xDD_GAW_word instruction. */
- (void) OPCo_xDD_GAW_word;
/** Execute the reference OPCn_xDD_GAW_word instruction. */
- (void) OPCn_xDD_GAW_word;
/** Execute the reference OPCn_xFA_LGA0 instruction. */
- (void) OPCn_xFA_LGA0;
/** Execute the reference OPCn_xFB_LGAB_alpha instruction. */
- (void) OPCn_xFB_LGAB_alpha;
/** Execute the reference OPCn_xFC_LGAW_word instruction. */
- (void) OPCn_xFC_LGAW_word;
/** Execute the reference OPCo_x34_LG0 instruction. */
- (void) OPCo_x34_LG0;
/** Execute the reference OPCn_x34_LG0 instruction. */
- (void) OPCn_x34_LG0;
/** Execute the reference OPCo_x35_LG1 instruction. */
- (void) OPCo_x35_LG1;
/** Execute the reference OPCn_x35_LG1 instruction. */
- (void) OPCn_x35_LG1;
/** Execute the reference OPCo_x36_LG2 instruction. */
- (void) OPCo_x36_LG2;
/** Execute the reference OPCn_x36_LG2 instruction. */
- (void) OPCn_x36_LG2;
/** Execute the reference OPCo_x37_LGB_alpha instruction. */
- (void) OPCo_x37_LGB_alpha;
/** Execute the reference OPCn_x37_LGB_alpha instruction. */
- (void) OPCn_x37_LGB_alpha;
/** Execute the reference OPCo_x38_LGD0 instruction. */
- (void) OPCo_x38_LGD0;
/** Execute the reference OPCn_x38_LGD0 instruction. */
- (void) OPCn_x38_LGD0;
/** Execute the reference OPCo_x39_LGD2 instruction. */
- (void) OPCo_x39_LGD2;
/** Execute the reference OPCn_x39_LGD2 instruction. */
- (void) OPCn_x39_LGD2;
/** Execute the reference OPCo_x3A_LGDB_alpha instruction. */
- (void) OPCo_x3A_LGDB_alpha;
/** Execute the reference OPCn_x3A_LGDB_alpha instruction. */
- (void) OPCn_x3A_LGDB_alpha;
/** Execute the reference OPCo_x3B_SGB_alpha instruction. */
- (void) OPCo_x3B_SGB_alpha;
/** Execute the reference OPCn_x3B_SGB_alpha instruction. */
- (void) OPCn_x3B_SGB_alpha;
/** Execute the reference OPCo_x76_SGDB_alpha instruction. */
- (void) OPCo_x76_SGDB_alpha;
/** Execute the reference OPCn_x76_SGDB_alpha instruction. */
- (void) OPCn_x76_SGDB_alpha;
/** Execute the reference OPC_x40_R0 instruction. */
- (void) OPC_x40_R0;
/** Execute the reference OPC_x41_R1 instruction. */
- (void) OPC_x41_R1;
/** Execute the reference OPC_x42_RB_alpha instruction. */
- (void) OPC_x42_RB_alpha;
/** Execute the reference OPC_x43_RL0 instruction. */
- (void) OPC_x43_RL0;
/** Execute the reference OPC_x44_RLB_alpha instruction. */
- (void) OPC_x44_RLB_alpha;
/** Execute the reference OPC_x45_RD0 instruction. */
- (void) OPC_x45_RD0;
/** Execute the reference OPC_x46_RDB_alpha instruction. */
- (void) OPC_x46_RDB_alpha;
/** Execute the reference OPC_x47_RDL0 instruction. */
- (void) OPC_x47_RDL0;
/** Execute the reference OPC_x48_RDLB_alpha instruction. */
- (void) OPC_x48_RDLB_alpha;
/** Execute the reference ESC_x1B_RC_alpha instruction. */
- (void) ESC_x1B_RC_alpha;
/** Execute the reference OPC_x49_W0 instruction. */
- (void) OPC_x49_W0;
/** Execute the reference OPC_x4A_WB_alpha instruction. */
- (void) OPC_x4A_WB_alpha;
/** Execute the reference OPC_x4C_WLB_alpha instruction. */
- (void) OPC_x4C_WLB_alpha;
/** Execute the reference OPC_x4E_WDB_alpha instruction. */
- (void) OPC_x4E_WDB_alpha;
/** Execute the reference OPC_x51_WDLB_alpha instruction. */
- (void) OPC_x51_WDLB_alpha;
/** Execute the reference OPC_x4B_PSB_alpha instruction. */
- (void) OPC_x4B_PSB_alpha;
/** Execute the reference OPC_x4F_PSD0 instruction. */
- (void) OPC_x4F_PSD0;
/** Execute the reference OPC_x50_PSDB_alpha instruction. */
- (void) OPC_x50_PSDB_alpha;
/** Execute the reference OPC_x4D_PSLB_alpha instruction. */
- (void) OPC_x4D_PSLB_alpha;
/** Execute the reference OPC_x52_PSDLB_alpha instruction. */
- (void) OPC_x52_PSDLB_alpha;
/** Execute the reference OPC_x53_RLI00 instruction. */
- (void) OPC_x53_RLI00;
/** Execute the reference OPC_x54_RLI01 instruction. */
- (void) OPC_x54_RLI01;
/** Execute the reference OPC_x55_RLI02 instruction. */
- (void) OPC_x55_RLI02;
/** Execute the reference OPC_x56_RLI03 instruction. */
- (void) OPC_x56_RLI03;
/** Execute the reference OPC_x57_RLIP_pair instruction. */
- (void) OPC_x57_RLIP_pair;
/** Execute the reference OPC_x58_RLILP_pair instruction. */
- (void) OPC_x58_RLILP_pair;
/** Execute the reference OPCo_x5C_RGIP_pair instruction. */
- (void) OPCo_x5C_RGIP_pair;
/** Execute the reference OPCn_x5C_RGIP_pair instruction. */
- (void) OPCn_x5C_RGIP_pair;
/** Execute the reference OPCo_x5D_RGILP_pair instruction. */
- (void) OPCo_x5D_RGILP_pair;
/** Execute the reference OPCn_x5D_RGILP_pair instruction. */
- (void) OPCn_x5D_RGILP_pair;
/** Execute the reference OPC_x59_RLDI00 instruction. */
- (void) OPC_x59_RLDI00;
/** Execute the reference OPC_x5A_RLDIP_pair instruction. */
- (void) OPC_x5A_RLDIP_pair;
/** Execute the reference OPC_x5B_RLDILP_pair instruction. */
- (void) OPC_x5B_RLDILP_pair;
/** Execute the reference OPC_x5E_WLIP_pair instruction. */
- (void) OPC_x5E_WLIP_pair;
/** Execute the reference OPC_x5F_WLILP_pair instruction. */
- (void) OPC_x5F_WLILP_pair;
/** Execute the reference OPC_x60_WLDILP_pair instruction. */
- (void) OPC_x60_WLDILP_pair;
/** Execute the reference OPC_x61_RS_alpha instruction. */
- (void) OPC_x61_RS_alpha;
/** Execute the reference OPC_x62_RLS_alpha instruction. */
- (void) OPC_x62_RLS_alpha;
/** Execute the reference OPC_x63_WS_alpha instruction. */
- (void) OPC_x63_WS_alpha;
/** Execute the reference OPC_x64_WLS_alpha instruction. */
- (void) OPC_x64_WLS_alpha;
/** Execute the reference OPC_x66_RF_word instruction. */
- (void) OPC_x66_RF_word;
/** Execute the reference OPC_x65_R0F_alpha instruction. */
- (void) OPC_x65_R0F_alpha;
/** Execute the reference OPC_x68_RLF_word instruction. */
- (void) OPC_x68_RLF_word;
/** Execute the reference OPC_x67_RL0F_alpha instruction. */
- (void) OPC_x67_RL0F_alpha;
/** Execute the reference OPC_x69_RLFS instruction. */
- (void) OPC_x69_RLFS;
/** Execute the reference ESC_x1A_RCFS instruction. */
- (void) ESC_x1A_RCFS;
/** Execute the reference OPC_x6A_RLIPF_alphabeta instruction. */
- (void) OPC_x6A_RLIPF_alphabeta;
/** Execute the reference OPC_x6B_RLILPF_alphabeta instruction. */
- (void) OPC_x6B_RLILPF_alphabeta;
/** Execute the reference OPC_x6D_WF_word instruction. */
- (void) OPC_x6D_WF_word;
/** Execute the reference OPC_x6C_W0F_alpha instruction. */
- (void) OPC_x6C_W0F_alpha;
/** Execute the reference OPC_x72_WLF_word instruction. */
- (void) OPC_x72_WLF_word;
/** Execute the reference OPC_x71_WL0F_alpha instruction. */
- (void) OPC_x71_WL0F_alpha;
/** Execute the reference OPC_x74_WLFS instruction. */
- (void) OPC_x74_WLFS;
/** Execute the reference OPC_x70_WS0F_alpha instruction. */
- (void) OPC_x70_WS0F_alpha;
/** Execute the reference OPC_x6F_PS0F instruction. */
- (void) OPC_x6F_PS0F;
/** Execute the reference OPC_x6E_PSF_word instruction. */
- (void) OPC_x6E_PSF_word;
/** Execute the reference OPC_x73_PSLF_word instruction. */
- (void) OPC_x73_PSLF_word;
@end
#endif
