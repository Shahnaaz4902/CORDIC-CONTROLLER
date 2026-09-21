# Pipelined CORDIC Accelerator

A parameterized **pipelined CORDIC hardware accelerator** implemented in Verilog RTL for efficient trigonometric rotation and vectoring operations using fixed-point arithmetic.

The design supports both **rotation mode** and **vectoring mode**, with a fully pipelined datapath consisting of a configurable number of CORDIC iterations.

## Features

- Fully pipelined CORDIC architecture
- Parameterized data width
- Parameterized fractional precision
- Parameterized number of CORDIC iterations
- Rotation mode
- Vectoring mode
- Sine/cosine generation through rotation
- Magnitude/phase calculation through vectoring
- Fixed-point arithmetic
- Guard bits for internal CORDIC gain
- Quadrant preprocessing/postprocessing
- Precomputed `atan(2^-i)` constants
- CORDIC gain compensation
- Saturating output logic
- Valid signal pipelined with the data
- Bit-exact Python/MATLAB golden reference models
- Self-checking Verilog testbench
- Intel Quartus Prime project

---

## Architecture

```text
                         INPUT
                           |
                           v
                  +----------------+
                  |  PREPROCESSING  |
                  |                |
                  | Quadrant Fold  |
                  | Input Mapping  |
                  +--------+-------+
                           |
                           v
                  +----------------+
                  | CORDIC Stage 0 |
                  +--------+-------+
                           |
                  +----------------+
                  | CORDIC Stage 1 |
                  +--------+-------+
                           |
                          ...
                           |
                  +----------------+
                  | CORDIC Stage 15|
                  +--------+-------+
                           |
                           v
                  +----------------+
                  |  POSTPROCESSING |
                  |                |
                  | Gain Correction|
                  | Saturation     |
                  | Quadrant Fix   |
                  +--------+-------+
                           |
                           v
                         OUTPUT
```

With the default configuration, the datapath contains:

```text
1 preprocessing stage
+ 16 CORDIC stages
+ 1 postprocessing stage
= 18 clock cycles latency
```

Because the datapath is pipelined, a new input transaction can be accepted every clock cycle after the pipeline is filled.

---

## Default Configuration

The top-level module is parameterized as:

```verilog
module cordic_top #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS  = 14,
    parameter ITERATIONS = 16,
    parameter GUARD_BITS = 2
)
```

| Parameter | Default |
|---|---:|
| Data width | 16 bits |
| Fractional bits | 14 |
| Fixed-point format | Q1.14 |
| CORDIC iterations | 16 |
| Internal guard bits | 2 |
| Internal X/Y width | 18 bits |
| Pipeline latency | 18 cycles |

---

## Fixed-Point Representation

The default Cartesian data format is:

```text
Q1.14
```

The raw integer value is interpreted as:

```text
real_value = raw_value / 2^14
```

Examples:

```text
1.0  = 16384
0.5  = 8192
0.25 = 4096
```

The angle `z` uses the same fixed-point container but is expressed in **half-turns**:

```text
z = 1.0  -> 180°
z = 0.5  -> 90°
z = 0.25 -> 45°
z = -0.5 -> -90°
```

This representation allows the angle datapath to use the same fixed-point scaling as the Cartesian values.

---

# Operating Modes

## 1. Rotation Mode

Rotation mode rotates the input vector by the requested angle.

For an input:

```text
(x, y) = (1, 0)
```

the output approximates:

```text
x_out ≈ cos(θ)
y_out ≈ sin(θ)
```

Example:

```text
Input:
x = 1.0
y = 0
z = 45°

Output:
x ≈ 0.7071
y ≈ 0.7071
```

The RTL internally performs the iterative CORDIC rotation:

```text
x' = x -/+ y·2^-i
y' = y +/- x·2^-i
z' = z +/- atan(2^-i)
```

The direction is determined from the sign of the residual angle.

---

## 2. Vectoring Mode

Vectoring mode rotates an input vector toward the x-axis.

For:

```text
(x, y)
```

the output provides approximately:

```text
x_out ≈ sqrt(x² + y²)
z_out ≈ atan2(y, x)
```

The `y_out` output is approximately zero after convergence.

Example:

```text
Input:
x = 1.0
y = 1.0

Output:
x ≈ √2
y ≈ 0
z ≈ 45°
```

This makes the accelerator useful for:

- Magnitude calculation
- Phase calculation
- Cartesian-to-polar conversion

---

# Input / Output Interface

The top-level interface is:

```verilog
input  wire                         clk;
input  wire                         rst_n;
input  wire                         valid_in;
input  wire                         mode_in;

input  wire signed [DATA_WIDTH-1:0] x_in;
input  wire signed [DATA_WIDTH-1:0] y_in;
input  wire signed [DATA_WIDTH-1:0] z_in;

output wire                         valid_out;
output wire                         mode_out;

output wire signed [DATA_WIDTH-1:0] x_out;
output wire signed [DATA_WIDTH-1:0] y_out;
output wire signed [DATA_WIDTH-1:0] z_out;
```

### `mode_in`

```text
0 → Rotation
1 → Vectoring
```

### `valid_in`

Indicates that the input transaction is valid.

The `valid` signal is delayed through the pipeline and appears as `valid_out` when the corresponding output data becomes available.

---

# Pipeline Operation

For the default 16-iteration configuration:

```text
Cycle N
  |
  +--> Preprocess
  |
Cycle N+1
  |
  +--> CORDIC iteration 0
  |
Cycle N+2
  |
  +--> CORDIC iteration 1
  |
 ...
  |
Cycle N+16
  |
  +--> CORDIC iteration 15
  |
Cycle N+17
  |
  +--> Postprocess
  |
Cycle N+18
  |
  +--> Output valid
```

Therefore:

```text
Latency = ITERATIONS + 2
        = 18 cycles
```

The architecture is designed for **high throughput rather than minimum latency**.

---

# CORDIC Iteration

Each CORDIC stage performs one micro-rotation.

For iteration `i`:

```text
x_shifted = x >>> i
y_shifted = y >>> i
```

The direction is selected based on the operating mode.

### Rotation

The sign of the residual angle determines the direction.

```text
if z < 0:
    x_next = x + y_shifted
    y_next = y - x_shifted
    z_next = z + atan(2^-i)
else:
    x_next = x - y_shifted
    y_next = y + x_shifted
    z_next = z - atan(2^-i)
```

### Vectoring

The sign of `y` determines the direction so that the vector converges toward the x-axis.

---

# Gain Compensation

CORDIC iterations introduce a scale factor:

```text
K_N = Π sqrt(1 + 2^(-2i))
```

The implementation compensates for this gain using:

```text
1 / K_N
```

during postprocessing.

The inverse gain constants are precomputed for supported iteration counts and stored in:

```text
cordic_constants.v
```

This allows the datapath to avoid a general-purpose multiplier inside every CORDIC stage.

---

# Quadrant Handling

The basic CORDIC algorithm has a limited convergence range.

The design therefore performs preprocessing before the iterative pipeline.

### Rotation

Angles outside the primary convergence region are folded into the supported range.

The postprocessor restores the appropriate sign of the final X/Y values.

### Vectoring

For vectors with negative X coordinates, the input vector is transformed into the CORDIC convergence region.

The corresponding quadrant offset is carried through the pipeline and added back to the final phase.

This allows vectoring to produce the correct `atan2(y,x)` phase across all four quadrants.

---

# Guard Bits

CORDIC rotation introduces gain before gain compensation.

The internal X/Y datapath is therefore widened using:

```text
WIDTH_XY = DATA_WIDTH + GUARD_BITS
```

With the default parameters:

```text
DATA_WIDTH = 16
GUARD_BITS = 2

WIDTH_XY = 18 bits
```

The additional bits provide headroom for the approximately 1.647× CORDIC gain before the final gain correction.

---

# Output Saturation

After gain correction, the internal result is reduced from the widened datapath back to the configured data width.

The postprocessing stage uses saturation rather than simple truncation/wraparound.

Therefore, values exceeding the representable output range are clipped to the maximum/minimum signed value.

---

# Project Structure

```text
cordic/
│
├── cordic_top.v
├── cordic_preprocess.v
├── cordic_stage.v
├── cordic_postprocess.v
├── cordic_constants.v
│
├── cordic_tb.v
│
├── cordic_golden_model.py
├── cordic_golden_model.m
│
├── cordic_top.qpf
├── cordic_top.qsf
├── cordic_top.sdc
└── README.md
```

### Module Description

| File | Function |
|---|---|
| `cordic_top.v` | Top-level pipelined CORDIC accelerator |
| `cordic_preprocess.v` | Input quadrant folding and vector preprocessing |
| `cordic_stage.v` | Single pipelined CORDIC iteration |
| `cordic_postprocess.v` | Gain correction, saturation and quadrant restoration |
| `cordic_constants.v` | atan and inverse-gain lookup functions |
| `cordic_tb.v` | Self-checking RTL testbench |
| `cordic_golden_model.py` | Bit-exact Python reference model |
| `cordic_golden_model.m` | MATLAB/Octave reference model |

---

# Verification

The project contains a self-checking testbench with **28 directed test vectors** covering both operating modes.

## Rotation Tests

Rotation vectors include:

```text
0°
15°
30°
45°
60°
90°
120°
150°
180°
-30°
-45°
-60°
-90°
-120°
-135°
-179°
```

The expected results verify the generated sine/cosine values.

## Vectoring Tests

Vectoring tests include:

```text
(1, 0)
(0, 1)
(1, 1)
(-1, 1)
(-1, -1)
(1, -1)
(0.5, 0.25)
(-0.75, 0.3)
(0.3, -0.9)
(-0.6, -0.2)
(0, -1)
(-1, 0)
```

These tests verify:

- Magnitude
- Phase
- Quadrant correction
- Negative X/Y handling
- Near-axis cases

---

# Bit-Exact Golden Model

The project includes both Python and MATLAB reference models.

The golden models perform three main tasks:

### 1. Constant Generation

Generate:

```text
atan(2^-i)
```

constants and inverse CORDIC gain constants.

### 2. Bit-Exact Fixed-Point Model

The reference model reproduces the RTL arithmetic, including:

- Fixed-point quantization
- Arithmetic right shifts
- Two's-complement behavior
- CORDIC direction decisions
- Guard-bit datapath
- Gain compensation
- Saturation
- Quadrant correction

This allows the RTL testbench to use a tight numerical tolerance.

### 3. Floating-Point Reference

A floating-point CORDIC implementation is also used to compare the fixed-point hardware model against the expected mathematical behavior.

---

# Testbench Tolerance

The RTL testbench uses:

```text
TOLERANCE = 6 LSBs
```

This tolerance accounts for fixed-point quantization and atan-table rounding while still detecting meaningful RTL errors.

The testbench checks:

```text
valid_out
x_out
y_out
z_out
```

where applicable for the selected operating mode.

---

# Simulation

## Questa / ModelSim

Compile the design:

```tcl
vlog cordic_constants.v
vlog cordic_preprocess.v
vlog cordic_stage.v
vlog cordic_postprocess.v
vlog cordic_top.v
vlog cordic_tb.v
```

Run the testbench:

```tcl
vsim cordic_tb
run -all
```

The testbench reports individual PASS/FAIL results and maintains:

```text
total_tests
passed_tests
failed_tests
```

---

# Golden Model Usage

## Python

Run:

```bash
python cordic_golden_model.py
```

The script can be used to:

- Generate/verify CORDIC constants
- Evaluate rotation-mode results
- Evaluate vectoring-mode results
- Compare fixed-point and floating-point results
- Generate expected values for RTL verification

## MATLAB / Octave

Run:

```matlab
cordic_golden_model
```

The MATLAB model provides the same fixed-point and floating-point reference functionality.

No MATLAB Fixed-Point Designer toolbox is required for the reference calculations.

---

# Key RTL Concepts Demonstrated

- CORDIC algorithm
- Iterative shift-add arithmetic
- Fully pipelined datapath
- Fixed-point arithmetic
- Q-format representation
- Parameterized RTL
- Generate loops
- Pipeline valid propagation
- Quadrant correction
- Gain compensation
- Saturation logic
- Signed arithmetic
- Arithmetic right shifts
- Hardware-friendly trigonometric computation
- Self-checking verification
- Bit-exact software/hardware co-verification

---

# Applications

This CORDIC accelerator can be used as a hardware building block for:

- Sine/cosine generation
- Magnitude calculation
- Phase/angle calculation
- Cartesian-to-polar conversion
- Digital signal processing
- Communication systems
- Software-defined radio
- Radar/beamforming
- Motor-control algorithms
- DSP accelerators

---

# Tools Used

- **Verilog HDL**
- **Intel Quartus Prime**
- **Questa / ModelSim**
- **Python**
- **MATLAB / GNU Octave**

---

# Possible Extensions

Future improvements could include:

- Configurable pipeline depth
- Runtime-selectable iteration count
- AXI-Stream interface
- Ready/valid backpressure
- Higher precision fixed-point formats
- Additional CORDIC functions
- Hyperbolic CORDIC mode
- Square-root acceleration
- Logarithm/exponential operations
- FPGA resource/performance optimization
- Automated hardware/software co-verification
- Timing and area benchmarking for different iteration counts

---

## Author

**Shahnaaz Parveen**

M.Tech — Electrical Engineering  
Digital Design | RTL | DSP | Computer Architecture
