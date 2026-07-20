import pathlib, subprocess, sys, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT/'tools/assembler'))
from assembler import assemble
class EmulatorTests(unittest.TestCase):
 def run_program(self,name,memory=None,ok=True):
  import struct
  with tempfile.TemporaryDirectory() as d:
   b=pathlib.Path(d)/'p.bin'; state=pathlib.Path(d)/'state.txt'; ws=assemble((ROOT/'tb/programs'/name).read_text(),name); b.write_bytes(struct.pack('<%dI'%len(ws),*ws))
   cmd=[str(ROOT/'build/simt-emulator'),str(b),'--dump',str(state)]
   if memory:cmd += ['--memory',str(ROOT/'tb/programs'/memory)]
   r=subprocess.run(cmd,text=True,capture_output=True); self.assertEqual(r.returncode,0 if ok else 1,r.stdout+r.stderr); return state.read_text(),r.stdout
 def test_arithmetic(self):
  s,_=self.run_program('arithmetic.s'); self.assertIn('R3=0000000a',s);self.assertIn('R4=0000001e',s)
 def test_predication(self):
  s,_=self.run_program('predication.s');self.assertIn('LANE 0',s);self.assertIn('R3=00000001',s.splitlines()[3]);self.assertIn('R3=00000002',s.splitlines()[7])
 def test_select_uses_predicate_without_masking_write(self):
  s,_=self.run_program('select.s')
  lanes=[line for line in s.splitlines() if line.startswith('LANE ')]
  for lane in lanes[:4]: self.assertIn('R4=0000000b',lane)
  for lane in lanes[4:]: self.assertIn('R4=00000016',lane)
 def test_branch(self):
  s,_=self.run_program('branch.s');self.assertIn('R3=00000005',s)
 def test_divergence_and_reconvergence(self):
  s,_=self.run_program('divergence.s')
  lanes=[line for line in s.splitlines() if line.startswith('LANE ')]
  for lane in lanes[:4]: self.assertIn('R3=00000005',lane)
  for lane in lanes[4:]: self.assertIn('R3=00000009',lane)
 def test_global_memory(self):
  s,_=self.run_program('global_memory.s');self.assertIn('R3=0000002a',s);self.assertIn('MEM 80 2a',s)
 def test_vector_add(self):
  s,_=self.run_program('vector_add.s','vector_add.mem');
  for a,v in [(0x40,11),(0x44,22),(0x48,33),(0x4c,44),(0x50,55),(0x54,66),(0x58,77),(0x5c,88)]:self.assertIn(f'MEM {a:x} {v:x}',s)
 def test_illegal_instruction_fault(self):
  s,o=self.run_program('illegal.s',ok=False);self.assertIn('fault=1',o);self.assertIn('FAULT 1',s)
 def test_noncanonical_instruction_fault(self):
  s,o=self.run_program('noncanonical.s',ok=False);self.assertIn('fault=1',o);self.assertIn('PC 0',s)
 def test_stack_underflow_fault(self):
  s,o=self.run_program('stack_underflow.s',ok=False);self.assertIn('fault=6',o);self.assertIn('PC 0',s)
 def test_stack_overflow_fault(self):
  s,o=self.run_program('stack_overflow.s',ok=False);self.assertIn('fault=5',o);self.assertIn('PC 8',s)
if __name__=='__main__':unittest.main()
