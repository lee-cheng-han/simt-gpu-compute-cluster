#include "emulator.hpp"
#include <fstream>
#include <iostream>
#include <iterator>
static std::vector<uint32_t> read_words(const std::string& p) { std::ifstream f(p,std::ios::binary); if(!f) throw std::runtime_error("cannot open program: "+p); std::vector<unsigned char>b((std::istreambuf_iterator<char>(f)),{}); if(b.size()%4) throw std::runtime_error("program size is not a multiple of four"); std::vector<uint32_t>w; for(size_t i=0;i<b.size();i+=4) w.push_back(uint32_t(b[i])|(uint32_t(b[i+1])<<8)|(uint32_t(b[i+2])<<16)|(uint32_t(b[i+3])<<24)); return w; }
int main(int argc,char**argv){ try { if(argc<2){std::cerr<<"usage: simt-emulator PROGRAM [--memory FILE] [--dump FILE]\n";return 2;} std::string mem,dump="build/state.txt"; for(int i=2;i<argc;i++){std::string a=argv[i]; if((a=="--memory"||a=="--dump")&&i+1<argc){(a=="--memory"?mem:dump)=argv[++i];}else throw std::runtime_error("bad argument: "+a);} simt::Emulator e; e.load_program(read_words(argv[1])); if(!mem.empty())e.load_memory_text(mem); auto r=e.run(); e.dump(dump); std::cout<<"steps="<<r.steps<<" exited="<<r.exited<<" fault="<<int(r.fault)<<" fault_pc="<<r.fault_pc<<"\n"; return r.fault==simt::Fault::None&&r.exited?0:1; }catch(const std::exception&e){std::cerr<<"error: "<<e.what()<<'\n';return 2;} }

