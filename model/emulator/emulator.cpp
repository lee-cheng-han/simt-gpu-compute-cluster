#include "emulator.hpp"
#include <algorithm>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>
namespace simt {
static int32_t sx10(uint32_t x){return (x&0x200)?int32_t(x|0xfffffc00u):int32_t(x);}
Emulator::Emulator(std::size_t n,std::size_t sn):memory_(n,0),shared_(sn,0){}
void Emulator::load_program(const std::vector<uint32_t>&w){program_=w;pc_=0;active_=0xff;result_={};stack_.clear();ssy_valid_=false;for(auto&v:r_)v.fill(0);p_.fill(0);}
void Emulator::load_memory_text(const std::string&path){std::ifstream f(path);if(!f)throw std::runtime_error("cannot open memory: "+path);std::string line;while(std::getline(f,line)){if(auto q=line.find('#');q!=std::string::npos)line.resize(q);std::istringstream s(line);uint32_t a,v;if(s>>std::hex>>a>>v){if(a>memory_.size()||memory_.size()-a<4)throw std::runtime_error("memory initializer out of range");store32(memory_,a,v);}}}
bool Emulator::fault(Fault f){result_.fault=f;result_.fault_pc=pc_;return false;}
uint32_t Emulator::load32(const std::vector<uint8_t>&m,uint32_t a){return uint32_t(m[a])|(uint32_t(m[a+1])<<8)|(uint32_t(m[a+2])<<16)|(uint32_t(m[a+3])<<24);}
void Emulator::store32(std::vector<uint8_t>&m,uint32_t a,uint32_t v){for(unsigned i=0;i<4;i++)m[a+i]=uint8_t(v>>(8*i));}
bool Emulator::canonical(uint32_t w,Opcode op)const{
 uint32_t pe=(w>>25)&1,inv=(w>>24)&1,p=(w>>22)&3,rd=(w>>18)&15,ra=(w>>14)&15,rb=(w>>10)&15,im=w&1023;
 if(!pe&&(inv||p))return false;
 switch(op){
  case Opcode::NOP:case Opcode::BAR:case Opcode::EXIT:return !(rd||ra||rb||im);
  case Opcode::SYNC:return !pe&&!(rd||ra||rb||im);
  case Opcode::ADD:case Opcode::SUB:case Opcode::MUL:case Opcode::MIN:case Opcode::MAX:
  case Opcode::AND:case Opcode::OR:case Opcode::XOR:case Opcode::SHL:case Opcode::SHR:
  case Opcode::SAR:case Opcode::SEL:return im==0;
  case Opcode::NOT:case Opcode::MOV:return !(rb||im);
  case Opcode::MOVI:return !(ra||rb);
  case Opcode::SETP_EQ:case Opcode::SETP_NE:case Opcode::SETP_LT:case Opcode::SETP_LE:
  case Opcode::SETP_GT:case Opcode::SETP_GE:return rd<4&&im==0;
  case Opcode::LD_G:case Opcode::LD_S:return rb==0;
  case Opcode::ST_G:case Opcode::ST_S:return rd==0;
  case Opcode::BRA:return !(rd||ra||rb);
  case Opcode::SSY:return !pe&&!(rd||ra||rb);
  case Opcode::S2R:return !(ra||rb)&&im<=6;
 }
 return false;
}
Result Emulator::run(uint64_t limit){
 while(result_.fault==Fault::None&&!result_.exited&&result_.steps<limit){
  if(pc_>=program_.size()){fault(Fault::PcOutOfRange);break;} uint32_t w=program_[pc_],code=w>>26;if(code>31){fault(Fault::IllegalInstruction);break;}auto op=Opcode(code);if(!canonical(w,op)){fault(Fault::IllegalInstruction);break;}
  uint32_t oldpc=pc_++,rd=(w>>18)&15,ra=(w>>14)&15,rb=(w>>10)&15;int32_t im=sx10(w&1023);bool pe=(w>>25)&1,inv=(w>>24)&1;unsigned pi=(w>>22)&3;Mask exec=active_;if(pe&&op!=Opcode::SEL)exec&=inv?Mask(~p_[pi]):p_[pi];result_.steps++;
  auto each=[&](auto fn){for(unsigned l=0;l<kLanes;l++)if(exec&(1u<<l))fn(l);};
  auto bin=[&](auto fn){each([&](unsigned l){r_[rd][l]=fn(r_[ra][l],r_[rb][l]);});};
  switch(op){
   case Opcode::NOP:break; case Opcode::ADD:bin([](auto a,auto b){return a+b;});break;case Opcode::SUB:bin([](auto a,auto b){return a-b;});break;case Opcode::MUL:bin([](auto a,auto b){return a*b;});break;
   case Opcode::MIN:bin([](auto a,auto b){return uint32_t(std::min(int32_t(a),int32_t(b)));});break;case Opcode::MAX:bin([](auto a,auto b){return uint32_t(std::max(int32_t(a),int32_t(b)));});break;
   case Opcode::AND:bin([](auto a,auto b){return a&b;});break;case Opcode::OR:bin([](auto a,auto b){return a|b;});break;case Opcode::XOR:bin([](auto a,auto b){return a^b;});break;case Opcode::NOT:each([&](auto l){r_[rd][l]=~r_[ra][l];});break;
   case Opcode::SHL:bin([](auto a,auto b){return a<<(b&31);});break;case Opcode::SHR:bin([](auto a,auto b){return a>>(b&31);});break;case Opcode::SAR:bin([](auto a,auto b){return uint32_t(int32_t(a)>>(b&31));});break;
   case Opcode::MOV:each([&](auto l){r_[rd][l]=r_[ra][l];});break;case Opcode::MOVI:each([&](auto l){r_[rd][l]=uint32_t(im);});break;case Opcode::SEL:each([&](auto l){bool q=(p_[pi]>>l)&1;r_[rd][l]=r_[q!=inv?ra:rb][l];});break;
   case Opcode::SETP_EQ:case Opcode::SETP_NE:case Opcode::SETP_LT:case Opcode::SETP_LE:case Opcode::SETP_GT:case Opcode::SETP_GE:{Mask n=p_[rd&3];each([&](auto l){int32_t a=int32_t(r_[ra][l]),b=int32_t(r_[rb][l]);bool q=op==Opcode::SETP_EQ?a==b:op==Opcode::SETP_NE?a!=b:op==Opcode::SETP_LT?a<b:op==Opcode::SETP_LE?a<=b:op==Opcode::SETP_GT?a>b:a>=b;n=q?Mask(n|(1u<<l)):Mask(n&~(1u<<l));});p_[rd&3]=n;break;}
   case Opcode::LD_G:case Opcode::LD_S:case Opcode::ST_G:case Opcode::ST_S:{bool shared=op==Opcode::LD_S||op==Opcode::ST_S;bool store=op==Opcode::ST_G||op==Opcode::ST_S;auto&mem=shared?shared_:memory_;std::array<uint32_t,kLanes>a{};bool misaligned=false,out_of_range=false;each([&](auto l){a[l]=r_[ra][l]+uint32_t(im);misaligned|=(a[l]&3)!=0;out_of_range|=a[l]>mem.size()||mem.size()-a[l]<4;});if(misaligned||out_of_range){pc_=oldpc;fault(misaligned?Fault::MisalignedMemory:Fault::MemoryOutOfRange);break;}each([&](auto l){if(store)store32(mem,a[l],r_[rb][l]);else r_[rd][l]=load32(mem,a[l]);});break;}
   case Opcode::BRA:{Mask taken=exec,not_taken=active_&Mask(~exec);if(!pe)taken=active_,not_taken=0;if(taken&&not_taken){if(!ssy_valid_||stack_.empty()){pc_=oldpc;fault(Fault::IllegalInstruction);break;}auto&s=stack_.back();s.deferred_pc=pc_;s.deferred_mask=not_taken;s.union_mask=active_;s.deferred=true;active_=taken;pc_=uint32_t(int32_t(pc_)+im);ssy_valid_=false;}else if(taken)pc_=uint32_t(int32_t(pc_)+im);break;}
   case Opcode::SSY:if(stack_.size()>=kStackDepth){pc_=oldpc;fault(Fault::StackOverflow);break;}ssy_=uint32_t(int32_t(pc_)+im);ssy_valid_=true;stack_.push_back({ssy_,0,0,active_,false});break;
   case Opcode::BAR:if(pe||active_!=0xff){pc_=oldpc;fault(Fault::BarrierViolation);}break;
   case Opcode::S2R:if((w&1023)>6){pc_=oldpc;fault(Fault::IllegalInstruction);break;}each([&](auto l){switch(w&1023){case 0:r_[rd][l]=l;break;case 3:r_[rd][l]=l;break;case 5:r_[rd][l]=kLanes;break;default:r_[rd][l]=0;}});break;
   case Opcode::EXIT:active_&=Mask(~exec);if(!active_)result_.exited=true;break;
   case Opcode::SYNC:if(stack_.empty()){pc_=oldpc;fault(Fault::StackUnderflow);break;}if(stack_.back().reconv!=oldpc){pc_=oldpc;fault(Fault::IllegalInstruction);break;}if(stack_.back().deferred){auto&s=stack_.back();pc_=s.deferred_pc;active_=s.deferred_mask;s.deferred=false;}else{active_=stack_.back().union_mask;stack_.pop_back();}break;
  }
 }
 if(result_.fault==Fault::None&&!result_.exited&&result_.steps>=limit) fault(Fault::StepLimit);
 return result_;
}
void Emulator::dump(const std::string&path)const{std::ofstream f(path);f<<"PC "<<pc_<<"\nACTIVE "<<std::hex<<unsigned(active_)<<"\nFAULT "<<std::dec<<int(result_.fault)<<"\n";for(unsigned l=0;l<kLanes;l++){f<<"LANE "<<l;for(unsigned r=0;r<kRegs;r++)f<<" R"<<r<<'='<<std::hex<<std::setw(8)<<std::setfill('0')<<r_[r][l];f<<"\n";}for(size_t a=0;a+4<=memory_.size();a+=4){auto v=load32(memory_,a);if(v)f<<"MEM "<<std::hex<<a<<' '<<v<<"\n";}for(size_t a=0;a+4<=shared_.size();a+=4){auto v=load32(shared_,a);if(v)f<<"SHMEM "<<std::hex<<a<<' '<<v<<"\n";}}
}
