
module cordic_postprocess #(
    parameter DATA_WIDTH  = 16,
    parameter FRAC_BITS   = 14,
    parameter GUARD_BITS  = 2,
    parameter ITERATIONS  = 16     // selects the matching 1/K_N constant
)(
    input  wire                                     clk,
    input  wire                                     rst_n,

    input  wire                                     valid_in,
    input  wire                                     mode_in,
    input  wire signed [DATA_WIDTH+GUARD_BITS-1:0]  x_in,
    input  wire signed [DATA_WIDTH+GUARD_BITS-1:0]  y_in,
    input  wire signed [DATA_WIDTH-1:0]             z_in,
    input  wire                                     negate_xy_in,
    input  wire signed [1:0]                        quad_offset_in,

    output reg                          valid_out,
    output reg                          mode_out,
    output reg  signed [DATA_WIDTH-1:0] x_out,
    output reg  signed [DATA_WIDTH-1:0] y_out,
    output reg  signed [DATA_WIDTH-1:0] z_out
);

    localparam WIDTH_XY = DATA_WIDTH + GUARD_BITS;

    `include "cordic_constants.v"

    localparam signed [DATA_WIDTH-1:0] GAIN_INV = cordic_gain_inv(ITERATIONS);

    // ---- gain compensation multiply (the one deliberate multiplier in the design) ----
    wire signed [WIDTH_XY+DATA_WIDTH-1:0] x_mul_full = x_in * GAIN_INV;
    wire signed [WIDTH_XY+DATA_WIDTH-1:0] y_mul_full = y_in * GAIN_INV;
    wire signed [WIDTH_XY-1:0] x_scaled = x_mul_full >>> FRAC_BITS;
    wire signed [WIDTH_XY-1:0] y_scaled = y_mul_full >>> FRAC_BITS;

    // ---- rotation-mode quadrant restore (conditional negate) ----
    wire signed [WIDTH_XY-1:0] x_corrected = negate_xy_in ? -x_scaled : x_scaled;
    wire signed [WIDTH_XY-1:0] y_corrected = negate_xy_in ? -y_scaled : y_scaled;

    // ---- saturate WIDTH_XY -> DATA_WIDTH (clip, don't wrap) ----
    function signed [DATA_WIDTH-1:0] sat_fn;
        input signed [WIDTH_XY-1:0] val;
        reg   signed [DATA_WIDTH-1:0] max_pos;
        reg   signed [DATA_WIDTH-1:0] max_neg;
        reg   signed [WIDTH_XY-1:0]   max_pos_ext;
        reg   signed [WIDTH_XY-1:0]   max_neg_ext;
        begin
            max_pos     = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            max_neg     = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            max_pos_ext = {{GUARD_BITS{1'b0}}, max_pos};
            max_neg_ext = {{GUARD_BITS{1'b1}}, max_neg};
            if (val > max_pos_ext)
                sat_fn = max_pos;
            else if (val < max_neg_ext)
                sat_fn = max_neg;
            else
                sat_fn = val[DATA_WIDTH-1:0];
        end
    endfunction

    wire signed [DATA_WIDTH-1:0] x_sat = sat_fn(x_corrected);
    wire signed [DATA_WIDTH-1:0] y_sat = sat_fn(y_corrected);

    // ---- vectoring-mode quadrant restore (add back +/-180deg on z) ----
    wire signed [DATA_WIDTH-1:0] quad_offset_ext   = {{(DATA_WIDTH-2){quad_offset_in[1]}}, quad_offset_in};
    wire signed [DATA_WIDTH-1:0] quad_offset_scaled = quad_offset_ext <<< FRAC_BITS;
    wire signed [DATA_WIDTH-1:0] z_corrected = z_in + quad_offset_scaled;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            mode_out  <= 1'b0;
        end else begin
            valid_out <= valid_in;
            mode_out  <= mode_in;
            x_out     <= x_sat;
            y_out     <= y_sat;
            z_out     <= z_corrected;
        end
    end

endmodule
