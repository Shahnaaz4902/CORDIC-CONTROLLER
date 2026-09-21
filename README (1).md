# 5-Stage Pipelined RISC-V Processor

A **32-bit 5-stage pipelined RISC-V processor** implemented in Verilog RTL, with data-hazard forwarding, load-use hazard detection, pipeline stalls, and branch flushing.

The processor follows the classic:

```text
IF → ID → EX → MEM → WB
```

pipeline organization and is implemented as a Quartus project for Intel FPGA development.

## Features

- 32-bit RISC-V processor
- 5-stage pipeline:
  - Instruction Fetch (IF)
  - Instruction Decode (ID)
  - Execute (EX)
  - Memory Access (MEM)
  - Write Back (WB)
- Pipeline registers between every stage
- EX/MEM → EX forwarding
- MEM/WB → EX forwarding
- Load-use hazard detection
- One-cycle pipeline stall for load-use hazards
- Branch resolution in EX stage
- Two-instruction branch flush
- Write-first register-file bypass
- Separate instruction and data memory models
- Parameterized instruction-memory program file
- Self-checking verification testbench
- Multiple test programs for functional and hazard verification
- Intel Quartus Prime project included

---

## Processor Architecture

```text
                    +----------------+
                    | Instruction    |
                    |    Memory      |
                    +-------+--------+
                            |
                            v
      +-------+      +-------------+
      |  IF   | ---> |   IF / ID   |
      |       |      |  Pipeline   |
      |  PC   |      |   Register  |
      +-------+      +------+------+
                            |
                            v
                    +---------------+
                    |      ID       |
                    |               |
                    | Control       |
                    | Register File |
                    | Immediate Gen |
                    | Hazard Detect |
                    +-------+-------+
                            |
                            v
                    +---------------+
                    |    ID / EX    |
                    |   Pipeline    |
                    |    Register   |
                    +-------+-------+
                            |
                            v
                    +---------------+
                    |      EX       |
                    |               |
                    | Forwarding    |
                    | ALU Control   |
                    | ALU           |
                    | Branch Logic  |
                    +-------+-------+
                            |
                            v
                    +---------------+
                    |   EX / MEM    |
                    |   Pipeline    |
                    |    Register   |
                    +-------+-------+
                            |
                            v
                    +---------------+
                    |      MEM      |
                    |               |
                    |  Data Memory  |
                    +-------+-------+
                            |
                            v
                    +---------------+
                    |   MEM / WB    |
                    |   Pipeline    |
                    |    Register   |
                    +-------+-------+
                            |
                            v
                    +---------------+
                    |      WB       |
                    |               |
                    | ALU / Memory  |
                    | Result Select |
                    +---------------+
```

---

## Pipeline Stages

### 1. Instruction Fetch — IF

The program counter provides the current instruction address.

The next PC is normally:

```text
PC + 4
```

For a taken branch, the EX-stage branch target replaces the sequential PC.

### 2. Instruction Decode — ID

The instruction is decoded and the following operations are performed:

- Opcode decoding
- Register-file read
- Immediate generation
- Control-signal generation
- Load-use hazard detection

### 3. Execute — EX

The EX stage contains:

- ALU control
- ALU
- Forwarding multiplexers
- Branch target calculation
- Branch condition evaluation

Forwarding allows the EX stage to obtain the newest operand value without waiting for it to be written back to the register file.

### 4. Memory — MEM

The MEM stage performs:

- Load operations
- Store operations
- Data-memory access

### 5. Write Back — WB

The WB stage selects between:

```text
ALU result
     OR
Loaded memory data
```

and writes the selected value into the register file.

---

## Hazard Handling

A major objective of this project is handling hazards introduced by pipelining.

### Data Hazards

The processor handles RAW (Read After Write) hazards using forwarding.

```text
Instruction 1: ADD x5, x1, x2
Instruction 2: SUB x6, x5, x3
```

Instead of waiting for `x5` to reach the register file:

```text
EX/MEM
   |
   | forwarding
   v
  EX
```

### Forwarding Paths

Two forwarding paths are implemented:

```text
EX/MEM → EX
MEM/WB → EX
```

Priority is given to the EX/MEM result because it represents the more recent value.

```text
forwardA / forwardB

00 → Register value
10 → EX/MEM value
01 → MEM/WB value
```

---

## Load-Use Hazard

Forwarding alone cannot resolve an immediate load-use dependency.

Example:

```text
lw  x5, 0(x1)
add x6, x5, x2
```

The loaded data is not available early enough for the following instruction's EX stage.

The hazard detection unit therefore:

1. Freezes the PC
2. Holds the IF/ID register
3. Inserts a bubble into ID/EX
4. Allows the load to continue
5. Uses normal forwarding after the stall

```text
Cycle:      1    2    3    4    5

LW          IF   ID   EX   MEM  WB
ADD              IF   ID   ST   EX
                         ↑
                      1-cycle
                       stall
```

---

## Control Hazards

Branches are resolved in the EX stage.

When a branch is taken:

```text
PC ← Branch Target
```

The two instructions already fetched along the wrong path are flushed.

```text
             Branch
               |
               v
IF → ID → EX → Taken
     |     |
     |     +---- Branch target
     |
     +---- Wrong-path instructions
              |
              v
            FLUSH
```

The current implementation therefore has a **2-cycle branch penalty for taken branches**.

---

## Supported Instructions

The processor implements an RV32I subset including:

### R-Type

```text
ADD
SUB
AND
OR
XOR
SLL
SRL
SRA
SLT
SLTU
```

### I-Type ALU Instructions

```text
ADDI
ANDI
ORI
XORI
SLLI
SRLI
SRAI
SLTI
SLTIU
```

### Memory Instructions

```text
LW
SW
```

### Branch Instructions

```text
BEQ
BNE
BLT
BGE
```

The control logic also decodes `JAL` and `JALR`, but the current datapath does not implement the corresponding PC-redirection/write-back behavior. They are therefore a known limitation of this implementation.

---

## Project Structure

```text
PipelineRiscV_quartus_project/
│
├── PipelinedRiscV.v
│
├── PC.v
├── Adder.v
├── InstructionMemory.v
├── Register.v
├── Control.v
├── ImmGen.v
├── ALUCtrl.v
├── ALU.v
├── DataMemory.v
├── Mux2to1.v
├── ShiftLeftOne.v
│
├── IF_ID_Reg.v
├── ID_EX_Reg.v
├── EX_MEM_Reg.v
├── MEM_WB_Reg.v
│
├── HazardDetectionUnit.v
├── ForwardingUnit.v
│
├── tb_pipeline.v
│
├── q1.dat
├── Q2withhazards.dat
├── hazard_test.dat
│
├── PipelineRiscV.qpf
├── PipelineRiscV.qsf
└── PipelineRiscV.out.sdc
```

### Module Description

| Module | Purpose |
|---|---|
| `PipelinedRiscV.v` | Top-level 5-stage pipelined processor |
| `PC.v` | Program counter |
| `InstructionMemory.v` | Instruction storage/program loader |
| `Register.v` | 32-register register file |
| `Control.v` | Main instruction decoder |
| `ImmGen.v` | Immediate-value generation |
| `ALUCtrl.v` | ALU operation decoder |
| `ALU.v` | Arithmetic and logical operations |
| `DataMemory.v` | Load/store memory |
| `ForwardingUnit.v` | EX-stage RAW hazard forwarding |
| `HazardDetectionUnit.v` | Load-use hazard detection |
| `IF_ID_Reg.v` | IF/ID pipeline register |
| `ID_EX_Reg.v` | ID/EX pipeline register |
| `EX_MEM_Reg.v` | EX/MEM pipeline register |
| `MEM_WB_Reg.v` | MEM/WB pipeline register |
| `tb_pipeline.v` | Self-checking verification testbench |

---

## Verification

The project includes a self-checking testbench that runs multiple programs through independent DUT instances.

### Test Programs

#### `q1.dat`

Basic functional program covering:

- R-type operations
- I-type operations
- Load/store behavior

#### `Q2withhazards.dat`

Hazard-oriented program exercising data dependencies and forwarding.

#### `hazard_test.dat`

Dedicated hazard test covering:

- EX/MEM → EX forwarding
- MEM/WB → EX forwarding
- Register-file write-first bypass
- Load-use hazard and one-cycle stall
- Load used after additional instructions
- Store-data forwarding
- Not-taken branch
- Taken branch and pipeline flush

The testbench monitors both:

```text
stall
branch_taken_EX
```

and counts how many times hazard handling is activated.

It also compares the final architectural register state against expected values generated from a sequential reference model.

---

## Simulation

### Questa / ModelSim

Compile the RTL:

```tcl
vlog Adder.v
vlog ALU.v
vlog ALUCtrl.v
vlog Control.v
vlog DataMemory.v
vlog ImmGen.v
vlog InstructionMemory.v
vlog Mux2to1.v
vlog PC.v
vlog Register.v
vlog ShiftLeftOne.v

vlog IF_ID_Reg.v
vlog ID_EX_Reg.v
vlog EX_MEM_Reg.v
vlog MEM_WB_Reg.v

vlog HazardDetectionUnit.v
vlog ForwardingUnit.v
vlog PipelinedRiscV.v
vlog tb_pipeline.v
```

Run the testbench:

```tcl
vsim tb_pipeline
run -all
```

The testbench reports individual PASS/FAIL results and summarizes the total number of tests.

---

## Verification Flow

```text
                 Test Program
                      |
                      v
             +----------------+
             | Instruction    |
             |    Memory      |
             +-------+--------+
                     |
                     v
             Pipelined RISC-V
                     |
                     v
             Final Registers
                     |
                     v
             +----------------+
             | Self-Checking  |
             |   Testbench    |
             +-------+--------+
                     |
                     v
                PASS / FAIL
```

The testbench checks that the pipelined implementation produces the same architectural results as the expected sequential execution.

---

## Key RTL Concepts Demonstrated

- 5-stage CPU pipelining
- RV32I instruction decoding
- Pipeline registers
- Data-path/control-path separation
- RAW hazard handling
- Forwarding logic
- Load-use stall insertion
- Control-hazard handling
- Pipeline flushing
- Register-file write-first bypass
- Instruction and data memory
- Parameterized program loading
- Self-checking verification
- Quartus FPGA project development

---

## Tools Used

- **Verilog HDL**
- **Intel Quartus Prime**
- **Questa / ModelSim**
- **Cyclone V SoC Development Kit target**

Quartus project configuration targets:

```text
Family : Cyclone V
Device : 5CSXFC6D6F31C6
```

---

## Future Improvements

Possible extensions include:

- Complete JAL/JALR datapath support
- CSR support
- More RV32I instructions
- Branch prediction
- Earlier branch resolution
- Static/dynamic branch prediction
- Instruction/data cache integration
- AXI/Avalon memory interface
- FPGA board-level I/O
- Performance counters
- Formal verification
- Deeper pipeline optimization

---

## Author

**Shahnaaz Parveen**

M.Tech — Electrical Engineering  
Digital Design | RTL | Computer Architecture
