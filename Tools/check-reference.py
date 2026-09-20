#!/usr/bin/env python3
"""Differential arithmetic and jump tests against an unmodified Dwarf checkout."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
reference = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else '../dwarf').resolve()
source = reference / 'src'
build = root / 'build/reference'
build.mkdir(parents=True, exist_ok=True)
harness = build / 'ReferenceVectors.java'
harness.write_text('''
import dev.hawala.dmachine.engine.*;
import dev.hawala.dmachine.engine.opcodes.*;
import java.lang.reflect.*;
import java.util.*;
public class ReferenceVectors {
  public static void main(String[] args) throws Exception {
    Mem.initializeMemoryGuam(18, 18);
    for (int p = 0; p < 1024; p++) Mem.setMap("test", p, p, (short)0);
    for (int p = 256; p < 262144; p++) Mem.writeWord(p, (short)0);
    Cpu.thrower = (Cpu.MesaFaultTrapThrower) Proxy.newProxyInstance(
      Cpu.class.getClassLoader(), new Class<?>[] { Cpu.MesaFaultTrapThrower.class },
      (proxy, method, params) -> { throw new IllegalStateException(method.getName()); });
    Random random = new Random(20260920L);
    Class<?>[] chapters = {Ch05_Stack_Instructions.class, Ch06_Jump_Instructions.class};
    for (Class<?> chapter : chapters) {
      Field[] fields = chapter.getFields();
      Arrays.sort(fields, Comparator.comparing(Field::getName));
      for (Field field : fields) {
        String name = field.getName();
        if (!name.matches("(OPC|ESC)_x[0-9A-F]{2}_.*") || name.contains("Restore")) continue;
        int opcode = Integer.parseInt(name.substring(5, 7), 16);
        boolean escape = name.startsWith("ESC");
        Opcodes.OpImpl impl = (Opcodes.OpImpl)field.get(null);
        for (int test = 0; test < 80; test++) {
          int byte1 = random.nextInt(256), byte2 = random.nextInt(256);
          Cpu.resetRegisters(); Cpu.CB = 0x30000; Cpu.savedPC = 0;
          Cpu.PC = escape ? 2 : 1; Cpu.SP = random.nextInt(15);
          for (int i = 0; i < 14; i++) Cpu.getStack()[i] = (short)random.nextInt(65536);
          if (test % 8 == 0) Arrays.fill(Cpu.getStack(), (short)0);
          if (test % 8 == 1) Arrays.fill(Cpu.getStack(), (short)0xffff);
          if (test % 8 == 2) Arrays.fill(Cpu.getStack(), (short)0x8000);
          short[] before = Cpu.getStack().clone(); int beforeSP = Cpu.SP;
          Mem.writeWord(Cpu.CB, (short)(escape ? 0xf800 | opcode : opcode << 8 | byte1));
          Mem.writeWord(Cpu.CB + 1, (short)(escape ? byte1 << 8 | byte2 : byte2 << 8));
          try { impl.execute(); } catch (RuntimeException exception) { continue; }
          StringBuilder line = new StringBuilder();
          line.append(opcode).append(' ').append(escape ? 1 : 0).append(' ')
            .append(byte1).append(' ').append(byte2).append(' ').append(beforeSP);
          for (short word : before) line.append(' ').append(word & 65535);
          line.append(' ').append(Cpu.PC).append(' ').append(Cpu.SP);
          for (short word : Cpu.getStack()) line.append(' ').append(word & 65535);
          System.out.println(line);
        }
      }
    }
  }
}
''')
files = sorted(p for p in source.rglob('*.java') if 'unittest' not in p.parts)
if not files:
    sys.exit('No Dwarf Java sources at ' + str(source))
subprocess.run(['javac', '-encoding', 'UTF-8', '-d', str(build), *map(str, files), str(harness)], check=True)
result = subprocess.run(['java', '-cp', str(build), 'ReferenceVectors'], check=True, capture_output=True, text=True)
vectors = build / 'vectors.txt'
# Reference startup messages are not test records.
lines = [line for line in result.stdout.splitlines() if len(line.split()) == 35 and all(part.isdigit() for part in line.split())]
if not lines:
    sys.exit('No reference vectors generated:\n' + result.stdout + result.stderr)
vectors.write_text('\n'.join(lines) + '\n')
subprocess.run([str(root / 'build/tests'), str(vectors)], check=True)
