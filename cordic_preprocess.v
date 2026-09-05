
module cordic_preprocess #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS  = 14,
    parameter GUARD_BITS = 2
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire                          valid_in,
    input  wire                          mode_in,      // 0=ROTATION, 1=VECTORING
    input  wire signed [DATA_WIDTH-1:0]  x_in,
    input  wire signed [DATA_WIDTH-1:0]  y_in,
    input  wire signed [DATA_WIDTH-1:0]  z_in,

    output reg                                     valid_out,
    output reg                                     mode_out,
    output reg  signed [DATA_WIDTH+GUARD_BITS-1:0] x_out,
    output reg  signed [DATA_WIDTH+GUARD_BITS-1:0] y_out,
    output reg  signed [DATA_WIDTH-1:0]            z_out,

    output reg                           negate_xy_out,   // rotation: negate x_out/y_out in postprocess
    output reg  signed [1:0]             quad_offset_out  // vectoring: add {-1,0,+1} half-turns to z_out
);

    localparam WIDTH_XY = DATA_WIDTH + GUARD_BITS;

    `include "cordic_constants.v"

    // 0.5 half-turns = 90 degrees ; 1.0 half-turns = 180 degrees
    localparam signed [DATA_WIDTH-1:0] ANGLE_HALF = (1 <<< (FRAC_BITS-1));
    localparam signed [DATA_WIDTH-1:0] ANGLE_ONE  = (1 <<< FRAC_BITS);

    // ---- rotation-mode angle fold ----
    wire rot_hi = (z_in > ANGLE_HALF);
    wire rot_lo = (z_in < -ANGLE_HALF);
    wire signed [DATA_WIDTH-1:0] z_rot_folded = rot_hi ? (z_in - ANGLE_ONE) :
                                                  rot_lo ? (z_in + ANGLE_ONE) : z_in;
    wire rot_negate = rot_hi | rot_lo;

    // ---- vectoring-mode 180-degree pre-rotation ----
    wire vec_neg = x_in[DATA_WIDTH-1];   // x_in < 0
    wire signed [DATA_WIDTH-1:0] vec_x0 = vec_neg ? -x_in : x_in;
    wire signed [DATA_WIDTH-1:0] vec_y0 = vec_neg ? -y_in : y_in;
    wire signed [1:0] vec_quad_offset = vec_neg ? (y_in[DATA_WIDTH-1] ? -2'sd1 : 2'sd1) : 2'sd0;

    // ---- mode select ----
    wire signed [DATA_WIDTH-1:0] x0_sel = (mode_in == CORDIC_MODE_VECTORING) ? vec_x0 : x_in;
    wire signed [DATA_WIDTH-1:0] y0_sel = (mode_in == CORDIC_MODE_VECTORING) ? vec_y0 : y_in;
    wire signed [DATA_WIDTH-1:0] z0_sel = (mode_in == CORDIC_MODE_VECTORING) ? z_in   : z_rot_folded;
    wire                         negate_sel = (mode_in == CORDIC_MODE_VECTORING) ? 1'b0 : rot_negate;
    wire signed [1:0]            quad_offset_sel = (mode_in == CORDIC_MODE_VECTORING) ? vec_quad_offset : 2'sd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out       <= 1'b0;
            mode_out        <= 1'b0;
            negate_xy_out   <= 1'b0;
            quad_offset_out <= 2'sd0;
        end else begin
            valid_out       <= valid_in;
            mode_out        <= mode_in;
            // sign-extend DATA_WIDTH -> WIDTH_XY for the guard-bit-widened datapath
            x_out           <= {{GUARD_BITS{x0_sel[DATA_WIDTH-1]}}, x0_sel};
            y_out           <= {{GUARD_BITS{y0_sel[DATA_WIDTH-1]}}, y0_sel};
            z_out           <= z0_sel;
            negate_xy_out   <= negate_sel;
            quad_offset_out <= quad_offset_sel;
        end
    end

endmodule
