  if (!escape)
    {
      switch (opcode)
        {
        case 0x01:
          if (!execute) return YES;
          [self OPC_x01_LL0];
          return YES;
        case 0x02:
          if (!execute) return YES;
          [self OPC_x02_LL1];
          return YES;
        case 0x03:
          if (!execute) return YES;
          [self OPC_x03_LL2];
          return YES;
        case 0x04:
          if (!execute) return YES;
          [self OPC_x04_LL3];
          return YES;
        case 0x05:
          if (!execute) return YES;
          [self OPC_x05_LL4];
          return YES;
        case 0x06:
          if (!execute) return YES;
          [self OPC_x06_LL5];
          return YES;
        case 0x07:
          if (!execute) return YES;
          [self OPC_x07_LL6];
          return YES;
        case 0x08:
          if (!execute) return YES;
          [self OPC_x08_LL7];
          return YES;
        case 0x09:
          if (!execute) return YES;
          [self OPC_x09_LL8];
          return YES;
        case 0x0a:
          if (!execute) return YES;
          [self OPC_x0A_LL9];
          return YES;
        case 0x0b:
          if (!execute) return YES;
          [self OPC_x0B_LL10];
          return YES;
        case 0x0c:
          if (!execute) return YES;
          [self OPC_x0C_LL11];
          return YES;
        case 0x0d:
          if (!execute) return YES;
          [self OPC_x0D_LLB_alpha];
          return YES;
        case 0x0e:
          if (!execute) return YES;
          [self OPC_x0E_LLD0];
          return YES;
        case 0x0f:
          if (!execute) return YES;
          [self OPC_x0F_LLD1];
          return YES;
        case 0x10:
          if (!execute) return YES;
          [self OPC_x10_LLD2];
          return YES;
        case 0x11:
          if (!execute) return YES;
          [self OPC_x11_LLD3];
          return YES;
        case 0x12:
          if (!execute) return YES;
          [self OPC_x12_LLD4];
          return YES;
        case 0x13:
          if (!execute) return YES;
          [self OPC_x13_LLD5];
          return YES;
        case 0x14:
          if (!execute) return YES;
          [self OPC_x14_LLD6];
          return YES;
        case 0x15:
          if (!execute) return YES;
          [self OPC_x15_LLD7];
          return YES;
        case 0x16:
          if (!execute) return YES;
          [self OPC_x16_LLD8];
          return YES;
        case 0x17:
          if (!execute) return YES;
          [self OPC_x17_LLD10];
          return YES;
        case 0x18:
          if (!execute) return YES;
          [self OPC_x18_LLDB_alpha];
          return YES;
        case 0x19:
          if (!execute) return YES;
          [self OPC_x19_SL0];
          return YES;
        case 0x1a:
          if (!execute) return YES;
          [self OPC_x1A_SL1];
          return YES;
        case 0x1b:
          if (!execute) return YES;
          [self OPC_x1B_SL2];
          return YES;
        case 0x1c:
          if (!execute) return YES;
          [self OPC_x1C_SL3];
          return YES;
        case 0x1d:
          if (!execute) return YES;
          [self OPC_x1D_SL4];
          return YES;
        case 0x1e:
          if (!execute) return YES;
          [self OPC_x1E_SL5];
          return YES;
        case 0x1f:
          if (!execute) return YES;
          [self OPC_x1F_SL6];
          return YES;
        case 0x20:
          if (!execute) return YES;
          [self OPC_x20_SL7];
          return YES;
        case 0x21:
          if (!execute) return YES;
          [self OPC_x21_SL8];
          return YES;
        case 0x22:
          if (!execute) return YES;
          [self OPC_x22_SL9];
          return YES;
        case 0x23:
          if (!execute) return YES;
          [self OPC_x23_SL10];
          return YES;
        case 0x24:
          if (!execute) return YES;
          [self OPC_x24_SLB_alpha];
          return YES;
        case 0x25:
          if (!execute) return YES;
          [self OPC_x25_SLD0];
          return YES;
        case 0x26:
          if (!execute) return YES;
          [self OPC_x26_SLD1];
          return YES;
        case 0x27:
          if (!execute) return YES;
          [self OPC_x27_SLD2];
          return YES;
        case 0x28:
          if (!execute) return YES;
          [self OPC_x28_SLD3];
          return YES;
        case 0x29:
          if (!execute) return YES;
          [self OPC_x29_SLD4];
          return YES;
        case 0x2a:
          if (!execute) return YES;
          [self OPC_x2A_SLD5];
          return YES;
        case 0x2b:
          if (!execute) return YES;
          [self OPC_x2B_SLD6];
          return YES;
        case 0x2c:
          if (!execute) return YES;
          [self OPC_x2C_SLD8];
          return YES;
        case 0x2d:
          if (!execute) return YES;
          [self OPC_x2D_PL0];
          return YES;
        case 0x2e:
          if (!execute) return YES;
          [self OPC_x2E_PL1];
          return YES;
        case 0x2f:
          if (!execute) return YES;
          [self OPC_x2F_PL2];
          return YES;
        case 0x30:
          if (!execute) return YES;
          [self OPC_x30_PL3];
          return YES;
        case 0x31:
          if (!execute) return YES;
          [self OPC_x31_PLB_alpha];
          return YES;
        case 0x32:
          if (!execute) return YES;
          [self OPC_x32_PLD0];
          return YES;
        case 0x33:
          if (!execute) return YES;
          [self OPC_x33_PLDB_alpha];
          return YES;
        case 0x34:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x34_LG0];
          if (_post40) [self OPCn_x34_LG0];
          return YES;
        case 0x35:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x35_LG1];
          if (_post40) [self OPCn_x35_LG1];
          return YES;
        case 0x36:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x36_LG2];
          if (_post40) [self OPCn_x36_LG2];
          return YES;
        case 0x37:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x37_LGB_alpha];
          if (_post40) [self OPCn_x37_LGB_alpha];
          return YES;
        case 0x38:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x38_LGD0];
          if (_post40) [self OPCn_x38_LGD0];
          return YES;
        case 0x39:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x39_LGD2];
          if (_post40) [self OPCn_x39_LGD2];
          return YES;
        case 0x3a:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x3A_LGDB_alpha];
          if (_post40) [self OPCn_x3A_LGDB_alpha];
          return YES;
        case 0x3b:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x3B_SGB_alpha];
          if (_post40) [self OPCn_x3B_SGB_alpha];
          return YES;
        case 0x3c:
          if (!execute) return YES;
          [self OPC_x3C_BNDCK];
          return YES;
        case 0x40:
          if (!execute) return YES;
          [self OPC_x40_R0];
          return YES;
        case 0x41:
          if (!execute) return YES;
          [self OPC_x41_R1];
          return YES;
        case 0x42:
          if (!execute) return YES;
          [self OPC_x42_RB_alpha];
          return YES;
        case 0x43:
          if (!execute) return YES;
          [self OPC_x43_RL0];
          return YES;
        case 0x44:
          if (!execute) return YES;
          [self OPC_x44_RLB_alpha];
          return YES;
        case 0x45:
          if (!execute) return YES;
          [self OPC_x45_RD0];
          return YES;
        case 0x46:
          if (!execute) return YES;
          [self OPC_x46_RDB_alpha];
          return YES;
        case 0x47:
          if (!execute) return YES;
          [self OPC_x47_RDL0];
          return YES;
        case 0x48:
          if (!execute) return YES;
          [self OPC_x48_RDLB_alpha];
          return YES;
        case 0x49:
          if (!execute) return YES;
          [self OPC_x49_W0];
          return YES;
        case 0x4a:
          if (!execute) return YES;
          [self OPC_x4A_WB_alpha];
          return YES;
        case 0x4b:
          if (!execute) return YES;
          [self OPC_x4B_PSB_alpha];
          return YES;
        case 0x4c:
          if (!execute) return YES;
          [self OPC_x4C_WLB_alpha];
          return YES;
        case 0x4d:
          if (!execute) return YES;
          [self OPC_x4D_PSLB_alpha];
          return YES;
        case 0x4e:
          if (!execute) return YES;
          [self OPC_x4E_WDB_alpha];
          return YES;
        case 0x4f:
          if (!execute) return YES;
          [self OPC_x4F_PSD0];
          return YES;
        case 0x50:
          if (!execute) return YES;
          [self OPC_x50_PSDB_alpha];
          return YES;
        case 0x51:
          if (!execute) return YES;
          [self OPC_x51_WDLB_alpha];
          return YES;
        case 0x52:
          if (!execute) return YES;
          [self OPC_x52_PSDLB_alpha];
          return YES;
        case 0x53:
          if (!execute) return YES;
          [self OPC_x53_RLI00];
          return YES;
        case 0x54:
          if (!execute) return YES;
          [self OPC_x54_RLI01];
          return YES;
        case 0x55:
          if (!execute) return YES;
          [self OPC_x55_RLI02];
          return YES;
        case 0x56:
          if (!execute) return YES;
          [self OPC_x56_RLI03];
          return YES;
        case 0x57:
          if (!execute) return YES;
          [self OPC_x57_RLIP_pair];
          return YES;
        case 0x58:
          if (!execute) return YES;
          [self OPC_x58_RLILP_pair];
          return YES;
        case 0x59:
          if (!execute) return YES;
          [self OPC_x59_RLDI00];
          return YES;
        case 0x5a:
          if (!execute) return YES;
          [self OPC_x5A_RLDIP_pair];
          return YES;
        case 0x5b:
          if (!execute) return YES;
          [self OPC_x5B_RLDILP_pair];
          return YES;
        case 0x5c:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x5C_RGIP_pair];
          if (_post40) [self OPCn_x5C_RGIP_pair];
          return YES;
        case 0x5d:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x5D_RGILP_pair];
          if (_post40) [self OPCn_x5D_RGILP_pair];
          return YES;
        case 0x5e:
          if (!execute) return YES;
          [self OPC_x5E_WLIP_pair];
          return YES;
        case 0x5f:
          if (!execute) return YES;
          [self OPC_x5F_WLILP_pair];
          return YES;
        case 0x60:
          if (!execute) return YES;
          [self OPC_x60_WLDILP_pair];
          return YES;
        case 0x61:
          if (!execute) return YES;
          [self OPC_x61_RS_alpha];
          return YES;
        case 0x62:
          if (!execute) return YES;
          [self OPC_x62_RLS_alpha];
          return YES;
        case 0x63:
          if (!execute) return YES;
          [self OPC_x63_WS_alpha];
          return YES;
        case 0x64:
          if (!execute) return YES;
          [self OPC_x64_WLS_alpha];
          return YES;
        case 0x65:
          if (!execute) return YES;
          [self OPC_x65_R0F_alpha];
          return YES;
        case 0x66:
          if (!execute) return YES;
          [self OPC_x66_RF_word];
          return YES;
        case 0x67:
          if (!execute) return YES;
          [self OPC_x67_RL0F_alpha];
          return YES;
        case 0x68:
          if (!execute) return YES;
          [self OPC_x68_RLF_word];
          return YES;
        case 0x69:
          if (!execute) return YES;
          [self OPC_x69_RLFS];
          return YES;
        case 0x6a:
          if (!execute) return YES;
          [self OPC_x6A_RLIPF_alphabeta];
          return YES;
        case 0x6b:
          if (!execute) return YES;
          [self OPC_x6B_RLILPF_alphabeta];
          return YES;
        case 0x6c:
          if (!execute) return YES;
          [self OPC_x6C_W0F_alpha];
          return YES;
        case 0x6d:
          if (!execute) return YES;
          [self OPC_x6D_WF_word];
          return YES;
        case 0x6e:
          if (!execute) return YES;
          [self OPC_x6E_PSF_word];
          return YES;
        case 0x6f:
          if (!execute) return YES;
          [self OPC_x6F_PS0F];
          return YES;
        case 0x70:
          if (!execute) return YES;
          [self OPC_x70_WS0F_alpha];
          return YES;
        case 0x71:
          if (!execute) return YES;
          [self OPC_x71_WL0F_alpha];
          return YES;
        case 0x72:
          if (!execute) return YES;
          [self OPC_x72_WLF_word];
          return YES;
        case 0x73:
          if (!execute) return YES;
          [self OPC_x73_PSLF_word];
          return YES;
        case 0x74:
          if (!execute) return YES;
          [self OPC_x74_WLFS];
          return YES;
        case 0x75:
          if (!execute) return YES;
          [self OPC_x75_SLDB_alpha];
          return YES;
        case 0x76:
          if (!execute) return YES;
          if (!_post40) [self OPCo_x76_SGDB_alpha];
          if (_post40) [self OPCn_x76_SGDB_alpha];
          return YES;
        case 0x7b:
          if (!execute) return YES;
          [self OPC_x7B_SHIFT];
          return YES;
        case 0x7c:
          if (!execute) return YES;
          [self OPC_x7C_SHIFTSB_alpha];
          return YES;
        case 0x80:
          if (!execute) return YES;
          [self OPC_x80_CATCH_alpha];
          return YES;
        case 0x81:
          if (!execute) return YES;
          [self OPC_x81_J2];
          return YES;
        case 0x82:
          if (!execute) return YES;
          [self OPC_x82_J3];
          return YES;
        case 0x83:
          if (!execute) return YES;
          [self OPC_x83_J4];
          return YES;
        case 0x84:
          if (!execute) return YES;
          [self OPC_x84_J5];
          return YES;
        case 0x85:
          if (!execute) return YES;
          [self OPC_x85_J6];
          return YES;
        case 0x86:
          if (!execute) return YES;
          [self OPC_x86_J7];
          return YES;
        case 0x87:
          if (!execute) return YES;
          [self OPC_x87_J8];
          return YES;
        case 0x88:
          if (!execute) return YES;
          [self OPC_x88_JB_salpha];
          return YES;
        case 0x89:
          if (!execute) return YES;
          [self OPC_x89_JW_sword];
          return YES;
        case 0x8a:
          if (!execute) return YES;
          [self OPC_x8A_JEP_pair];
          return YES;
        case 0x8b:
          if (!execute) return YES;
          [self OPC_x8B_JEB_salpha];
          return YES;
        case 0x8c:
          if (!execute) return YES;
          [self OPC_x8C_JEBB_alphasbeta];
          return YES;
        case 0x8d:
          if (!execute) return YES;
          [self OPC_x8D_JNEP_pair];
          return YES;
        case 0x8e:
          if (!execute) return YES;
          [self OPC_x8E_JNEB_salpha];
          return YES;
        case 0x8f:
          if (!execute) return YES;
          [self OPC_x8F_JNEBB_alphasbeta];
          return YES;
        case 0x90:
          if (!execute) return YES;
          [self OPC_x90_JLB_salpha];
          return YES;
        case 0x91:
          if (!execute) return YES;
          [self OPC_x91_JGEB_salpha];
          return YES;
        case 0x92:
          if (!execute) return YES;
          [self OPC_x92_JGB_salpha];
          return YES;
        case 0x93:
          if (!execute) return YES;
          [self OPC_x93_JLEB_salpha];
          return YES;
        case 0x94:
          if (!execute) return YES;
          [self OPC_x94_JULB_salpha];
          return YES;
        case 0x95:
          if (!execute) return YES;
          [self OPC_x95_JUGEB_salpha];
          return YES;
        case 0x96:
          if (!execute) return YES;
          [self OPC_x96_JUGB_salpha];
          return YES;
        case 0x97:
          if (!execute) return YES;
          [self OPC_x97_JULEB_salpha];
          return YES;
        case 0x98:
          if (!execute) return YES;
          [self OPC_x98_JZ3];
          return YES;
        case 0x99:
          if (!execute) return YES;
          [self OPC_x99_JZ4];
          return YES;
        case 0x9a:
          if (!execute) return YES;
          [self OPC_x9A_JZB_salpha];
          return YES;
        case 0x9b:
          if (!execute) return YES;
          [self OPC_x9B_JNZ3];
          return YES;
        case 0x9c:
          if (!execute) return YES;
          [self OPC_x9C_JNZ4];
          return YES;
        case 0x9d:
          if (!execute) return YES;
          [self OPC_x9D_JNZB_salpha];
          return YES;
        case 0x9e:
          if (!execute) return YES;
          [self OPC_x9E_JDEB_salpha];
          return YES;
        case 0x9f:
          if (!execute) return YES;
          [self OPC_x9F_JDNEB_salpha];
          return YES;
        case 0xa0:
          if (!execute) return YES;
          [self OPC_xA0_JIB_word];
          return YES;
        case 0xa1:
          if (!execute) return YES;
          [self OPC_xA1_JIW_word];
          return YES;
        case 0xa2:
          if (!execute) return YES;
          [self OPC_xA2_REC];
          return YES;
        case 0xa3:
          if (!execute) return YES;
          [self OPC_xA3_REC2];
          return YES;
        case 0xa4:
          if (!execute) return YES;
          [self OPC_xA4_DIS];
          return YES;
        case 0xa5:
          if (!execute) return YES;
          [self OPC_xA5_DIS2];
          return YES;
        case 0xa6:
          if (!execute) return YES;
          [self OPC_xA6_EXCH];
          return YES;
        case 0xa7:
          if (!execute) return YES;
          [self OPC_xA7_DEXCH];
          return YES;
        case 0xa8:
          if (!execute) return YES;
          [self OPC_xA8_DUP];
          return YES;
        case 0xa9:
          if (!execute) return YES;
          [self OPC_xA9_DDUP];
          return YES;
        case 0xaa:
          if (!execute) return YES;
          [self OPC_xAA_EXDIS];
          return YES;
        case 0xab:
          if (!execute) return YES;
          [self OPC_xAB_NEG];
          return YES;
        case 0xac:
          if (!execute) return YES;
          [self OPC_xAC_INC];
          return YES;
        case 0xad:
          if (!execute) return YES;
          [self OPC_xAD_DEC];
          return YES;
        case 0xae:
          if (!execute) return YES;
          [self OPC_xAE_DINC];
          return YES;
        case 0xaf:
          if (!execute) return YES;
          [self OPC_xAF_DBL];
          return YES;
        case 0xb0:
          if (!execute) return YES;
          [self OPC_xB0_DDBL];
          return YES;
        case 0xb1:
          if (!execute) return YES;
          [self OPC_xB1_TRPL];
          return YES;
        case 0xb2:
          if (!execute) return YES;
          [self OPC_xB2_AND];
          return YES;
        case 0xb3:
          if (!execute) return YES;
          [self OPC_xB3_IOR];
          return YES;
        case 0xb4:
          if (!execute) return YES;
          [self OPC_xB4_ADDSB_alpha];
          return YES;
        case 0xb5:
          if (!execute) return YES;
          [self OPC_xB5_ADD];
          return YES;
        case 0xb6:
          if (!execute) return YES;
          [self OPC_xB6_SUB];
          return YES;
        case 0xb7:
          if (!execute) return YES;
          [self OPC_xB7_DADD];
          return YES;
        case 0xb8:
          if (!execute) return YES;
          [self OPC_xB8_DSUB];
          return YES;
        case 0xb9:
          if (!execute) return YES;
          [self OPC_xB9_ADC];
          return YES;
        case 0xba:
          if (!execute) return YES;
          [self OPC_xBA_ACD];
          return YES;
        case 0xbb:
          if (!execute) return YES;
          [self OPC_xBB_AL0IB_alpha];
          return YES;
        case 0xbc:
          if (!execute) return YES;
          [self OPC_xBC_MUL];
          return YES;
        case 0xbd:
          if (!execute) return YES;
          [self OPC_xBD_DCMP];
          return YES;
        case 0xbe:
          if (!execute) return YES;
          [self OPC_xBE_UDCMP];
          return YES;
        case 0xc0:
          if (!execute) return YES;
          [self OPC_xC0_LI0];
          return YES;
        case 0xc1:
          if (!execute) return YES;
          [self OPC_xC1_LI1];
          return YES;
        case 0xc2:
          if (!execute) return YES;
          [self OPC_xC2_LI2];
          return YES;
        case 0xc3:
          if (!execute) return YES;
          [self OPC_xC3_LI3];
          return YES;
        case 0xc4:
          if (!execute) return YES;
          [self OPC_xC4_LI4];
          return YES;
        case 0xc5:
          if (!execute) return YES;
          [self OPC_xC5_LI5];
          return YES;
        case 0xc6:
          if (!execute) return YES;
          [self OPC_xC6_LI6];
          return YES;
        case 0xc7:
          if (!execute) return YES;
          [self OPC_xC7_LI7];
          return YES;
        case 0xc8:
          if (!execute) return YES;
          [self OPC_xC8_LI8];
          return YES;
        case 0xc9:
          if (!execute) return YES;
          [self OPC_xC9_LI9];
          return YES;
        case 0xca:
          if (!execute) return YES;
          [self OPC_xCA_LI10];
          return YES;
        case 0xcb:
          if (!execute) return YES;
          [self OPC_xCB_LIN1];
          return YES;
        case 0xcc:
          if (!execute) return YES;
          [self OPC_xCC_LINI];
          return YES;
        case 0xcd:
          if (!execute) return YES;
          [self OPC_xCD_LIB_alpha];
          return YES;
        case 0xce:
          if (!execute) return YES;
          [self OPC_xCE_LIW_word];
          return YES;
        case 0xcf:
          if (!execute) return YES;
          [self OPC_xCF_LINB_alpha];
          return YES;
        case 0xd0:
          if (!execute) return YES;
          [self OPC_xD0_LIHB_alpha];
          return YES;
        case 0xd1:
          if (!execute) return YES;
          [self OPC_xD1_LID0];
          return YES;
        case 0xd2:
          if (!execute) return YES;
          [self OPC_xD2_LA0];
          return YES;
        case 0xd3:
          if (!execute) return YES;
          [self OPC_xD3_LA1];
          return YES;
        case 0xd4:
          if (!execute) return YES;
          [self OPC_xD4_LA2];
          return YES;
        case 0xd5:
          if (!execute) return YES;
          [self OPC_xD5_LA3];
          return YES;
        case 0xd6:
          if (!execute) return YES;
          [self OPC_xD6_LA6];
          return YES;
        case 0xd7:
          if (!execute) return YES;
          [self OPC_xD7_LA8];
          return YES;
        case 0xd8:
          if (!execute) return YES;
          [self OPC_xD8_LAB_alpha];
          return YES;
        case 0xd9:
          if (!execute) return YES;
          [self OPC_xD9_LAW_word];
          return YES;
        case 0xda:
          if (!execute) return YES;
          if (!_post40) [self OPCo_xDA_GA0];
          if (_post40) [self OPCn_xDA_GA0];
          return YES;
        case 0xdb:
          if (!execute) return YES;
          if (!_post40) [self OPCo_xDB_GA1];
          if (_post40) [self OPCn_xDB_GA1];
          return YES;
        case 0xdc:
          if (!execute) return YES;
          if (!_post40) [self OPCo_xDC_GAB_alpha];
          if (_post40) [self OPCn_xDC_GAB_alpha];
          return YES;
        case 0xdd:
          if (!execute) return YES;
          if (!_post40) [self OPCo_xDD_GAW_word];
          if (_post40) [self OPCn_xDD_GAW_word];
          return YES;
        case 0xf7:
          if (!execute) return YES;
          [self OPC_xF7_LP];
          return YES;
        case 0xfa:
          if (!_post40) return NO;
          if (!execute) return YES;
          [self OPCn_xFA_LGA0];
          return YES;
        case 0xfb:
          if (!_post40) return NO;
          if (!execute) return YES;
          [self OPCn_xFB_LGAB_alpha];
          return YES;
        case 0xfc:
          if (!_post40) return NO;
          if (!execute) return YES;
          [self OPCn_xFC_LGAW_word];
          return YES;
        default: break;
        }
    }
  if (escape)
    {
      switch (opcode)
        {
        case 0x07:
          if (!execute) return YES;
          [self ESC_x07_SM];
          return YES;
        case 0x08:
          if (!execute) return YES;
          [self ESC_x08_SMF];
          return YES;
        case 0x09:
          if (!execute) return YES;
          [self ESC_x09_GMF];
          return YES;
        case 0x12:
          if (!execute) return YES;
          [self ESC_x12_XOR];
          return YES;
        case 0x13:
          if (!execute) return YES;
          [self ESC_x13_DAND];
          return YES;
        case 0x14:
          if (!execute) return YES;
          [self ESC_x14_DIOR];
          return YES;
        case 0x15:
          if (!execute) return YES;
          [self ESC_x15_DXOR];
          return YES;
        case 0x16:
          if (!execute) return YES;
          [self ESC_x16_ROTATE];
          return YES;
        case 0x17:
          if (!execute) return YES;
          [self ESC_x17_DSHIFT];
          return YES;
        case 0x18:
          if (!execute) return YES;
          [self ESC_x18_LINT];
          return YES;
        case 0x19:
          if (!execute) return YES;
          [self ESC_x19_JS];
          return YES;
        case 0x1a:
          if (!execute) return YES;
          [self ESC_x1A_RCFS];
          return YES;
        case 0x1b:
          if (!execute) return YES;
          [self ESC_x1B_RC_alpha];
          return YES;
        case 0x1c:
          if (!execute) return YES;
          [self ESC_x1C_UDIV];
          return YES;
        case 0x1d:
          if (!execute) return YES;
          [self ESC_x1D_LUDIV];
          return YES;
        case 0x1e:
          if (!execute) return YES;
          [self ESC_x1E_ROB_alpha];
          return YES;
        case 0x1f:
          if (!execute) return YES;
          [self ESC_x1F_WOB_alpha];
          return YES;
        case 0x24:
          if (!execute) return YES;
          [self ESC_x24_BNDCKL];
          return YES;
        case 0x25:
          if (!execute) return YES;
          [self ESC_x25_NILCK];
          return YES;
        case 0x26:
          if (!execute) return YES;
          [self ESC_x26_NILCKL];
          return YES;
        case 0x30:
          if (!execute) return YES;
          [self ESC_x30_DMUL];
          return YES;
        case 0x31:
          if (!execute) return YES;
          [self ESC_x31_SDIV];
          return YES;
        case 0x32:
          if (!execute) return YES;
          [self ESC_x32_SDDIV];
          return YES;
        case 0x33:
          if (!execute) return YES;
          [self ESC_x33_UDDIV];
          return YES;
        case 0x40:
          if (!execute) return YES;
          [self ESC_x40_FADD];
          return YES;
        case 0x41:
          if (!execute) return YES;
          [self ESC_x41_FSUB];
          return YES;
        case 0x42:
          if (!execute) return YES;
          [self ESC_x42_FMUL];
          return YES;
        case 0x43:
          if (!execute) return YES;
          [self ESC_x43_FDIV];
          return YES;
        case 0x44:
          if (!execute) return YES;
          [self ESC_x44_FCOMP];
          return YES;
        case 0x46:
          if (!execute) return YES;
          [self ESC_x46_FLOAT];
          return YES;
        case 0x71:
          if (!execute) return YES;
          [self ESC_x71_WRMDS];
          return YES;
        case 0x79:
          if (!execute) return YES;
          [self ESC_x79_RRMDS];
          return YES;
        default: break;
        }
    }
