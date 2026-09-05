
localparam CORDIC_MODE_ROTATION  = 1'b0;
localparam CORDIC_MODE_VECTORING = 1'b1;

localparam integer CORDIC_HIGH_FRAC = 30;

// atan(2^-i)/pi, Q(CORDIC_HIGH_FRAC), i = 0..23 (supports up to 24 stages)
function signed [31:0] cordic_atan_hi;
    input integer i;
    begin
        case (i)
            0 : cordic_atan_hi = 32'sd268435456;
            1 : cordic_atan_hi = 32'sd158466703;
            2 : cordic_atan_hi = 32'sd83729454;
            3 : cordic_atan_hi = 32'sd42502378;
            4 : cordic_atan_hi = 32'sd21333666;
            5 : cordic_atan_hi = 32'sd10677233;
            6 : cordic_atan_hi = 32'sd5339919;
            7 : cordic_atan_hi = 32'sd2670123;
            8 : cordic_atan_hi = 32'sd1335082;
            9 : cordic_atan_hi = 32'sd667543;
            10: cordic_atan_hi = 32'sd333772;
            11: cordic_atan_hi = 32'sd166886;
            12: cordic_atan_hi = 32'sd83443;
            13: cordic_atan_hi = 32'sd41722;
            14: cordic_atan_hi = 32'sd20861;
            15: cordic_atan_hi = 32'sd10430;
            16: cordic_atan_hi = 32'sd5215;
            17: cordic_atan_hi = 32'sd2608;
            18: cordic_atan_hi = 32'sd1304;
            19: cordic_atan_hi = 32'sd652;
            20: cordic_atan_hi = 32'sd326;
            21: cordic_atan_hi = 32'sd163;
            22: cordic_atan_hi = 32'sd81;
            23: cordic_atan_hi = 32'sd41;
            default: cordic_atan_hi = 32'sd0;
        endcase
    end
endfunction

// Rescale to the design's actual FRAC_BITS, truncated to DATA_WIDTH bits.
// Requires FRAC_BITS <= CORDIC_HIGH_FRAC (30) - see note above.
function signed [DATA_WIDTH-1:0] cordic_atan;
    input integer i;
    begin
        cordic_atan = cordic_atan_hi(i) >>> (CORDIC_HIGH_FRAC - FRAC_BITS);
    end
endfunction

// -----------------------------------------------------------------------------
// CORDIC GAIN K_N = product_{i=0..N-1} sqrt(1 + 2^-2i); we store 1/K_N so
// gain compensation is a single MULTIPLY (x_scaled = x * (1/K_N)) rather than
// a divide. K_N converges extremely quickly (K_16 and K_24 agree to 10
// significant digits - see cordic_golden_model.py output), so a handful of
// precomputed entries covers the whole practical ITERATIONS design space;
// cordic_gain_inv_hi() below picks the closest available entry >= the
// requested N (exact for N in this table, a <0.001% approximation otherwise
// per the golden-model printout).
// -----------------------------------------------------------------------------
function signed [31:0] cordic_gain_inv_hi;
    input integer n;
    begin
        if (n <= 8)
            cordic_gain_inv_hi = 32'sd652039507;   // 1/K_8  = 0.6072591123
        else if (n <= 12)
            cordic_gain_inv_hi = 32'sd652032900;   // 1/K_12 = 0.6072529591
        else
            cordic_gain_inv_hi = 32'sd652032874;   // 1/K_N, N>=16 (converged to double precision)
    end
endfunction

function signed [DATA_WIDTH-1:0] cordic_gain_inv;
    input integer n;
    begin
        cordic_gain_inv = cordic_gain_inv_hi(n) >>> (CORDIC_HIGH_FRAC - FRAC_BITS);
    end
endfunction
