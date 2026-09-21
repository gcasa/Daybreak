/* Dump Dwarf initial IOP physical words 8192..24575 to the supplied file.
 * Compile against build/reference; stdout describes the field layout. */
import dev.hawala.dmachine.engine.*;
import dev.hawala.dmachine.engine.iop6085.*;
public class DumpIO extends Mem {
 public static void main(String[] args) throws Exception {
  Mem.initializeMemoryDaybreak(false);
  IOP.initialize(HDisk.VerifyLabelOp.verify, HDisk.VerifyLabelOp.verify, HDisk.VerifyLabelOp.verify, false);
  IORegion.dumpIORegionStructure(Mem.IORegion_Virtual_StartPage*256);
  java.io.DataOutputStream out=new java.io.DataOutputStream(new java.io.FileOutputStream(args[0]));
  for(int i=8192;i<24576;i++)out.writeShort(mem[i]);
  out.close();
 }
}
