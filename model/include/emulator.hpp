#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>
#include "isa_generated.hpp"
namespace simt {
enum class Fault { None, IllegalInstruction, PcOutOfRange, MisalignedMemory, MemoryOutOfRange, StackOverflow, StackUnderflow, BarrierViolation, StepLimit };
struct Result { Fault fault{Fault::None}; uint32_t fault_pc{}; uint64_t steps{}; bool exited{}; };
class Emulator {
 public:
  explicit Emulator(std::size_t memory_bytes=4096, std::size_t shared_bytes=2048);
  void load_program(const std::vector<uint32_t>& words); void load_memory_text(const std::string& path);
  Result run(uint64_t max_steps=100000); void dump(const std::string& path) const;
 private:
  using Vec=std::array<uint32_t,kLanes>; using Mask=uint8_t;
  struct Stack { uint32_t reconv{}, deferred_pc{}; Mask deferred_mask{}, union_mask{}; bool deferred{}; };
  std::vector<uint32_t> program_; std::vector<uint8_t> memory_, shared_; std::array<Vec,kRegs> r_{};
  std::array<Mask,kPreds> p_{}; std::vector<Stack> stack_; uint32_t pc_{}; Mask active_{0xff}; Result result_{}; uint32_t ssy_{}; bool ssy_valid_{};
  bool fault(Fault f); bool canonical(uint32_t w, Opcode op) const;
  static uint32_t load32(const std::vector<uint8_t>& memory, uint32_t a);
  static void store32(std::vector<uint8_t>& memory, uint32_t a, uint32_t v);
};
}
