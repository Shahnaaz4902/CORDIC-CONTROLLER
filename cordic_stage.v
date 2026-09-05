
module cordic_stage #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS  = 14,
    parameter GUARD_BITS = 2,
    parameter ITERATION  = 0     // which CORDIC iteration (i) this stage performs;
                                  // a per-instance compile-time constant, not a runtime signal
)(
    input  wire                                     clk,
    input  wire                                     rst_n,

    input  wire                                     valid_in,
    input  wire                                     mode_in,   // 0=ROTATION, 1=VECTORING
    input  wire signed [DATA_WIDTH+GUARD_BITS-1:0]  x_in,
    input  wire signed [DATA_WIDTH+GUARD_BITS-1:0]  y_in,
    input  wire signed [DATA_WIDTH-1:0]             z_in,

    output reg                                      valid_out,
    output reg                                      mode_out,
    output reg  signed [DATA_WIDTH+GUARD_BITS-1:0]  x_out,
    output reg  signed [DATA_WIDTH+GUARD_BITS-1:0]  y_out,
    output reg  signed [DATA_WIDTH-1:0]             z_out
);

    localparam WIDTH_XY = DATA_WIDTH + GUARD_BITS;

    `include "cordic_constants.v"

    // atan(2^-ITERATION) for THIS stage - ITERATION is a compile-time
    // constant per instance, so this resolves to one hardwired constant;
    // Quartus does not synthesize a case-select mux for it.
    wire signed [DATA_WIDTH-1:0] atan_const = cordic_atan(ITERATION);

    // Direction bit. dir=1 means d=-1 (per the standard CORDIC iteration
    // d=+1/-1 convention), dir=0 means d=+1:
    //   ROTATION : dir = 1 when z_in < 0     (drive z toward 0)
    //   VECTORING: dir = 1 when y_in >= 0    (drive y toward 0 - note the
    //              INVERTED polarity vs rotation: verified by hand-trace in
    //              the design README/report; this is the single most
    //              common CORDIC sign bug, so it is called out explicitly
    //              here rather than left implicit).
    wire dir = (mode_in == CORDIC_MODE_VECTORING) ? ~y_in[WIDTH_XY-1] : z_in[DATA_WIDTH-1];

    // Arithmetic right shifts by ITERATION - a COMPILE-TIME constant, so
    // each stage synthesizes as fixed wiring (a hardwired bit shift), never
    // a runtime/barrel shifter. This is the key structural difference from
    // an iterative CORDIC (which needs one real barrel shifter, shared
    // across iterations, driven by a runtime iteration counter) - here the
    // "shift amount" is a different constant in every stage's netlist.
    wire signed [WIDTH_XY-1:0] x_shifted = x_in >>> ITERATION;
    wire signed [WIDTH_XY-1:0] y_shifted = y_in >>> ITERATION;

    // Standard binary-scaled CORDIC update, both branches spelled out
    // explicitly (mux-selected adder/subtractor) rather than synthesizing a
    // signed multiply by +/-1:
    //   dir=1 (d=-1): x' = x - d*y = x + y_shifted ; y' = y + d*x = y - x_shifted ; z' = z - d*atan = z + atan
    //   dir=0 (d=+1): x' = x - y_shifted           ; y' = y + x_shifted           ; z' = z - atan
    wire signed [WIDTH_XY-1:0]  x_next = dir ? (x_in + y_shifted) : (x_in - y_shifted);
    wire signed [WIDTH_XY-1:0]  y_next = dir ? (y_in - x_shifted) : (y_in + x_shifted);
    wire signed [DATA_WIDTH-1:0] z_next = dir ? (z_in + atan_const) : (z_in - atan_const);

    // ---- Reset strategy (asynchronous, active-low) ----
    // Only valid_out/mode_out are reset. x_out/y_out/z_out are deliberately
    // left WITHOUT a reset branch: they are guaranteed to be overwritten
    // with real pipeline data well before any consumer can observe them
    // (valid_out gates whether downstream logic trusts them at all), so a
    // reset mux on these wide buses would cost extra LUT/routing resources
    // and reset fan-out for zero functional benefit. This is standard FPGA
    // pipeline practice: reset the CONTROL bits (valid/mode), not the bulk
    // datapath, on registers whose garbage-until-valid state is provably
    // unobservable. Multiplying this by ITERATIONS stages is where the
    // savings actually matter.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            mode_out  <= 1'b0;
        end else begin
            valid_out <= valid_in;
            mode_out  <= mode_in;
            x_out     <= x_next;
            y_out     <= y_next;
            z_out     <= z_next;
        end
    end

endmodule
