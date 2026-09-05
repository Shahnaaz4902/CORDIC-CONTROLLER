
module cordic_top #(
    parameter DATA_WIDTH  = 16,   // signed fixed-point data width
    parameter FRAC_BITS   = 14,   // fractional bits (Q1.FRAC_BITS format)
    parameter ITERATIONS  = 16,   // number of CORDIC iterations = number of pipeline stages
    parameter GUARD_BITS  = 2     // extra integer-side bits on the internal x/y datapath
)(
    input  wire                          clk,
    input  wire                          rst_n,      // asynchronous, active-low (see stage-level comment)

    input  wire                          valid_in,
    input  wire                          mode_in,    // 0 = ROTATION, 1 = VECTORING
    input  wire signed [DATA_WIDTH-1:0]  x_in,
    input  wire signed [DATA_WIDTH-1:0]  y_in,
    input  wire signed [DATA_WIDTH-1:0]  z_in,       // angle in HALF-TURNS (z=1.0 == 180deg); see cordic_constants.v

    output wire                          valid_out,
    output wire                          mode_out,
    output wire signed [DATA_WIDTH-1:0]  x_out,      // ROTATION: cos(theta)-like ; VECTORING: magnitude
    output wire signed [DATA_WIDTH-1:0]  y_out,      // ROTATION: sin(theta)-like ; VECTORING: unused (~0)
    output wire signed [DATA_WIDTH-1:0]  z_out       // ROTATION: residual angle (~0) ; VECTORING: atan2(y,x), half-turns
);

    localparam WIDTH_XY = DATA_WIDTH + GUARD_BITS;

    // ---------------- stage 0: preprocess ----------------
    wire                          pre_valid;
    wire                          pre_mode;
    wire signed [WIDTH_XY-1:0]    pre_x, pre_y;
    wire signed [DATA_WIDTH-1:0]  pre_z;
    wire                          pre_negate;
    wire signed [1:0]             pre_quad_offset;

    cordic_preprocess #(
        .DATA_WIDTH(DATA_WIDTH), .FRAC_BITS(FRAC_BITS), .GUARD_BITS(GUARD_BITS)
    ) u_preprocess (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .mode_in(mode_in),
        .x_in(x_in), .y_in(y_in), .z_in(z_in),
        .valid_out(pre_valid), .mode_out(pre_mode),
        .x_out(pre_x), .y_out(pre_y), .z_out(pre_z),
        .negate_xy_out(pre_negate), .quad_offset_out(pre_quad_offset)
    );

    // ---------------- stages 1..ITERATIONS: the CORDIC pipeline itself ----------------
    // tap[0] = preprocess output ; tap[k] = output of cordic_stage instance k-1
    wire                          valid_tap [0:ITERATIONS];
    wire                          mode_tap  [0:ITERATIONS];
    wire signed [WIDTH_XY-1:0]    x_tap     [0:ITERATIONS];
    wire signed [WIDTH_XY-1:0]    y_tap     [0:ITERATIONS];
    wire signed [DATA_WIDTH-1:0]  z_tap     [0:ITERATIONS];

    assign valid_tap[0] = pre_valid;
    assign mode_tap[0]  = pre_mode;
    assign x_tap[0]     = pre_x;
    assign y_tap[0]     = pre_y;
    assign z_tap[0]     = pre_z;

    genvar g;
    generate
        for (g = 0; g < ITERATIONS; g = g + 1) begin : gen_cordic_stage
            cordic_stage #(
                .DATA_WIDTH(DATA_WIDTH), .FRAC_BITS(FRAC_BITS),
                .GUARD_BITS(GUARD_BITS), .ITERATION(g)
            ) u_stage (
                .clk(clk), .rst_n(rst_n),
                .valid_in(valid_tap[g]), .mode_in(mode_tap[g]),
                .x_in(x_tap[g]), .y_in(y_tap[g]), .z_in(z_tap[g]),
                .valid_out(valid_tap[g+1]), .mode_out(mode_tap[g+1]),
                .x_out(x_tap[g+1]), .y_out(y_tap[g+1]), .z_out(z_tap[g+1])
            );
        end
    endgenerate

    // ---------------- side-channel delay line (negate_xy, quad_offset) ----------------
    // Exactly ITERATIONS registers deep, run in lockstep with the ITERATIONS
    // cordic_stage instances above, so this metadata reaches
    // cordic_postprocess in the same cycle as the x/y/z data it describes.
    // Small (1+2 bits wide) -> resetting the whole array is cheap, unlike
    // the wide x/y/z datapath (see cordic_stage.v's reset-strategy comment).
    reg                negate_pipe [0:ITERATIONS-1];
    reg signed [1:0]   quad_pipe   [0:ITERATIONS-1];
    integer si;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (si = 0; si < ITERATIONS; si = si + 1) begin
                negate_pipe[si] <= 1'b0;
                quad_pipe[si]   <= 2'sd0;
            end
        end else begin
            negate_pipe[0] <= pre_negate;
            quad_pipe[0]   <= pre_quad_offset;
            for (si = 1; si < ITERATIONS; si = si + 1) begin
                negate_pipe[si] <= negate_pipe[si-1];
                quad_pipe[si]   <= quad_pipe[si-1];
            end
        end
    end

    // ---------------- final stage: postprocess ----------------
    cordic_postprocess #(
        .DATA_WIDTH(DATA_WIDTH), .FRAC_BITS(FRAC_BITS),
        .GUARD_BITS(GUARD_BITS), .ITERATIONS(ITERATIONS)
    ) u_postprocess (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_tap[ITERATIONS]), .mode_in(mode_tap[ITERATIONS]),
        .x_in(x_tap[ITERATIONS]), .y_in(y_tap[ITERATIONS]), .z_in(z_tap[ITERATIONS]),
        .negate_xy_in(negate_pipe[ITERATIONS-1]), .quad_offset_in(quad_pipe[ITERATIONS-1]),
        .valid_out(valid_out), .mode_out(mode_out),
        .x_out(x_out), .y_out(y_out), .z_out(z_out)
    );

endmodule
