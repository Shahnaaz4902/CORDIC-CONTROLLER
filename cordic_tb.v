
`timescale 1ns/1ps

module cordic_tb;

    localparam DATA_WIDTH = 16;
    localparam FRAC_BITS  = 14;
    localparam ITERATIONS = 16;
    localparam GUARD_BITS = 2;

    localparam LATENCY = ITERATIONS + 2;   // computed: preprocess(1) + stages(ITERATIONS) + postprocess(1)
    localparam TOLERANCE = 6;              // LSBs; see header note - RTL should match the bit-exact model tightly

    reg                          clk, rst_n;
    reg                          valid_in, mode_in;
    reg  signed [DATA_WIDTH-1:0] x_in, y_in, z_in;
    wire                         valid_out, mode_out;
    wire signed [DATA_WIDTH-1:0] x_out, y_out, z_out;

    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;

    cordic_top #(
        .DATA_WIDTH(DATA_WIDTH), .FRAC_BITS(FRAC_BITS),
        .ITERATIONS(ITERATIONS), .GUARD_BITS(GUARD_BITS)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .mode_in(mode_in),
        .x_in(x_in), .y_in(y_in), .z_in(z_in),
        .valid_out(valid_out), .mode_out(mode_out),
        .x_out(x_out), .y_out(y_out), .z_out(z_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- generic checking helper ----------------
    // name is sized generously (100 chars) - some messages (e.g. the reset-
    // test and streaming-test summary strings, or a directed-test name
    // concatenated with its failure suffix) run well past 32 characters;
    // Verilog concatenation into a narrower `input` silently truncates from
    // the LEFT (drops the start of the string, keeps the end) instead of
    // erroring, so this must stay wide enough for the longest message used
    // anywhere below rather than merely "long enough for now".
    task automatic report(input passed, input [800:0] name);
        begin
            total_tests = total_tests + 1;
            if (passed) begin
                passed_tests = passed_tests + 1;
                $display("PASS: %0s", name);
            end else begin
                failed_tests = failed_tests + 1;
                $display("FAIL: %0s", name);
            end
        end
    endtask

    function automatic within_tol;
        input signed [DATA_WIDTH-1:0] got;
        input signed [DATA_WIDTH-1:0] exp;
        input integer tol;
        integer diff;
        begin
            diff = got - exp;
            if (diff < 0) diff = -diff;
            within_tol = (diff <= tol);
        end
    endfunction

    // =========================================================================
    // Test vector table (rotation + vectoring), generated from
    // cordic_golden_model.py's bit-exact fixed-point model.
    // =========================================================================
    localparam NUM_TV = 28;
    reg                          tv_mode  [0:NUM_TV-1];
    reg  signed [DATA_WIDTH-1:0] tv_x     [0:NUM_TV-1];
    reg  signed [DATA_WIDTH-1:0] tv_y     [0:NUM_TV-1];
    reg  signed [DATA_WIDTH-1:0] tv_z     [0:NUM_TV-1];
    reg  signed [DATA_WIDTH-1:0] tv_exp_x [0:NUM_TV-1];
    reg  signed [DATA_WIDTH-1:0] tv_exp_y [0:NUM_TV-1];
    reg  signed [DATA_WIDTH-1:0] tv_exp_z [0:NUM_TV-1];
    reg                          tv_chk_x [0:NUM_TV-1];
    reg                          tv_chk_y [0:NUM_TV-1];
    reg                          tv_chk_z [0:NUM_TV-1];
    reg [255:0]                  tv_name  [0:NUM_TV-1];

    integer IDX;
    initial begin
        IDX = 0;
        // ---- ROTATION: x_in=1.0, y_in=0.0, z_in=theta (half-turns) ----
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd0;      tv_exp_x[IDX]=16'sd16382; tv_exp_y[IDX]=-16'sd4;     tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=0deg";     IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd2731;   tv_exp_x[IDX]=16'sd14185; tv_exp_y[IDX]=16'sd8198;   tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=30deg";    IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd4096;   tv_exp_x[IDX]=16'sd11588; tv_exp_y[IDX]=16'sd11582;  tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=45deg";    IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd5461;   tv_exp_x[IDX]=16'sd8195;  tv_exp_y[IDX]=16'sd14186;  tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=60deg";    IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd8192;   tv_exp_x[IDX]=-16'sd6;    tv_exp_y[IDX]=16'sd16384;  tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=90deg";    IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd16384;  tv_exp_x[IDX]=-16'sd16382;tv_exp_y[IDX]=16'sd4;      tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=180deg";   IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=-16'sd2731;  tv_exp_x[IDX]=16'sd14186; tv_exp_y[IDX]=-16'sd8196;  tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=-30deg";   IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=-16'sd4096;  tv_exp_x[IDX]=16'sd11581; tv_exp_y[IDX]=-16'sd11589; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=-45deg";   IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=-16'sd8192;  tv_exp_x[IDX]=-16'sd7;    tv_exp_y[IDX]=-16'sd16383; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=-90deg";   IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=-16'sd12288; tv_exp_x[IDX]=-16'sd11588;tv_exp_y[IDX]=-16'sd11582; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=-135deg";  IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=-16'sd16293; tv_exp_x[IDX]=-16'sd16380;tv_exp_y[IDX]=-16'sd282;   tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=-179deg";  IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd1365;   tv_exp_x[IDX]=16'sd15825; tv_exp_y[IDX]=16'sd4242;   tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=15deg";    IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=-16'sd5461;  tv_exp_x[IDX]=16'sd8201;  tv_exp_y[IDX]=-16'sd14186; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=-60deg";   IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd10923;  tv_exp_x[IDX]=-16'sd8201; tv_exp_y[IDX]=16'sd14186;  tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=120deg";   IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=16'sd13653;  tv_exp_x[IDX]=-16'sd14186;tv_exp_y[IDX]=16'sd8196;   tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=150deg";   IDX=IDX+1;
        tv_mode[IDX]=1'b0; tv_x[IDX]=16'sd16384; tv_y[IDX]=16'sd0; tv_z[IDX]=-16'sd10923; tv_exp_x[IDX]=-16'sd8195; tv_exp_y[IDX]=-16'sd14186; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=0; tv_name[IDX]="rotation theta=-120deg";  IDX=IDX+1;

        // ---- VECTORING: (x_in, y_in) -> magnitude=x_out, angle=z_out ----
        tv_mode[IDX]=1'b1; tv_x[IDX]=16'sd16384;  tv_y[IDX]=16'sd0;     tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd16386; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=16'sd1;     tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (1,0)";       IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=16'sd0;      tv_y[IDX]=16'sd16384; tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd16384; tv_exp_y[IDX]=16'sd0; tv_exp_z[IDX]=16'sd8191;   tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (0,1)";       IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=16'sd16384;  tv_y[IDX]=16'sd16384; tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd23171; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=16'sd4097;  tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (1,1)";       IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=-16'sd16384; tv_y[IDX]=16'sd16384; tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd23171; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=16'sd12289; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (-1,1)";      IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=-16'sd16384; tv_y[IDX]=-16'sd16384;tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd23171; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=-16'sd12287;tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (-1,-1)";     IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=16'sd16384;  tv_y[IDX]=-16'sd16384;tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd23171; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=-16'sd4095; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (1,-1)";      IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=16'sd8192;   tv_y[IDX]=16'sd4096;  tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd9160;  tv_exp_y[IDX]=16'sd0; tv_exp_z[IDX]=16'sd2417;   tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (0.5,0.25)";  IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=-16'sd12288; tv_y[IDX]=16'sd4915;  tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd13234; tv_exp_y[IDX]=16'sd0; tv_exp_z[IDX]=16'sd14399;  tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (-0.75,0.3)"; IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=16'sd4915;   tv_y[IDX]=-16'sd14746;tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd15542; tv_exp_y[IDX]=16'sd0; tv_exp_z[IDX]=-16'sd6517; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (0.3,-0.9)"; IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=-16'sd9830;  tv_y[IDX]=-16'sd3277; tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd10366; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=-16'sd14703;tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (-0.6,-0.2)";IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=16'sd0;      tv_y[IDX]=-16'sd16384;tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd16386; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=-16'sd8191; tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (0,-1)";      IDX=IDX+1;
        tv_mode[IDX]=1'b1; tv_x[IDX]=-16'sd16384; tv_y[IDX]=16'sd0;     tv_z[IDX]=16'sd0; tv_exp_x[IDX]=16'sd16386; tv_exp_y[IDX]=-16'sd1; tv_exp_z[IDX]=16'sd16385;tv_chk_x[IDX]=1;tv_chk_y[IDX]=1;tv_chk_z[IDX]=1; tv_name[IDX]="vectoring (-1,0)";      IDX=IDX+1;
    end

    // =========================================================================
    // Section A+B: directed tests, one transaction at a time
    // =========================================================================
    task automatic run_directed_test(input integer idx);
        begin
            @(negedge clk);
            mode_in = tv_mode[idx];
            x_in    = tv_x[idx];
            y_in    = tv_y[idx];
            z_in    = tv_z[idx];
            valid_in = 1'b1;
            @(posedge clk);
            @(negedge clk);
            valid_in = 1'b0;

            repeat (LATENCY - 1) @(posedge clk);
            @(negedge clk);   // race-free sample point, exactly LATENCY cycles after the input-capture edge

            if (!valid_out) begin
                report(1'b0, {tv_name[idx], " (valid_out did not assert at expected latency)"});
            end else begin
                report(tv_chk_x[idx] ? within_tol(x_out, tv_exp_x[idx], TOLERANCE) : 1'b1,
                       {tv_name[idx], " x_out"});
                report(tv_chk_y[idx] ? within_tol(y_out, tv_exp_y[idx], TOLERANCE) : 1'b1,
                       {tv_name[idx], " y_out"});
                if (tv_chk_z[idx])
                    report(within_tol(z_out, tv_exp_z[idx], TOLERANCE), {tv_name[idx], " z_out"});
            end
        end
    endtask

    // =========================================================================
    // Section C: streaming - back-to-back inputs, one per clock, verifying
    // outputs emerge IN ORDER after exactly LATENCY cycles each.
    // =========================================================================
    localparam STREAM_N = 8;
    reg signed [DATA_WIDTH-1:0] stream_exp_x [0:STREAM_N-1];
    reg signed [DATA_WIDTH-1:0] stream_exp_y [0:STREAM_N-1];
    integer stream_push_idx, stream_pop_idx;
    integer stream_errors;
    reg stream_checking;

    // checker: runs concurrently with the driver below, race-free (negedge sampling)
    task automatic stream_checker_step;
        begin
            @(negedge clk);
            if (valid_out && stream_checking) begin
                if (!within_tol(x_out, stream_exp_x[stream_pop_idx], TOLERANCE) ||
                    !within_tol(y_out, stream_exp_y[stream_pop_idx], TOLERANCE)) begin
                    stream_errors = stream_errors + 1;
                    $display("FAIL: streaming element %0d out of tolerance (x=%0d exp=%0d, y=%0d exp=%0d)",
                              stream_pop_idx, x_out, stream_exp_x[stream_pop_idx], y_out, stream_exp_y[stream_pop_idx]);
                end
                stream_pop_idx = stream_pop_idx + 1;
            end
        end
    endtask

    integer s;
    task automatic run_streaming_test;
        begin
            stream_push_idx = 0;
            stream_pop_idx  = 0;
            stream_errors   = 0;
            stream_checking = 1'b1;

            // preload STREAM_N distinct rotation angles (reuse the directed
            // test vectors' inputs/expected outputs, indices 0..STREAM_N-1)
            for (s = 0; s < STREAM_N; s = s + 1) begin
                stream_exp_x[s] = tv_exp_x[s];
                stream_exp_y[s] = tv_exp_y[s];
            end

            @(negedge clk);
            for (s = 0; s < STREAM_N; s = s + 1) begin
                mode_in  = tv_mode[s];
                x_in     = tv_x[s];
                y_in     = tv_y[s];
                z_in     = tv_z[s];
                valid_in = 1'b1;
                @(posedge clk);
                stream_checker_step;   // (negedge sample happens inside this task)
            end
            valid_in = 1'b0;

            // drain: keep sampling until all STREAM_N results have popped
            while (stream_pop_idx < STREAM_N) begin
                @(posedge clk);
                stream_checker_step;
            end

            report(stream_errors == 0,
                   "streaming: 8 back-to-back inputs produced correct outputs in order");
        end
    endtask

    // =========================================================================
    // Section D: reset behaviour
    // =========================================================================
    task automatic run_reset_test;
        integer k;
        reg saw_valid_during_reset;
        reg saw_early_valid;
        begin
            // 1) assert reset, verify valid_out stays low
            rst_n = 1'b0;
            saw_valid_during_reset = 1'b0;
            repeat (5) begin
                @(posedge clk);
                @(negedge clk);
                if (valid_out) saw_valid_during_reset = 1'b1;
            end
            report(!saw_valid_during_reset, "reset: valid_out stays low while rst_n is asserted");

            // 2) release reset, immediately apply one valid input, verify
            //    valid_out stays low for LATENCY-1 cycles and then asserts
            //    on cycle LATENCY (not early, not late)
            rst_n = 1'b1;
            repeat (2) @(posedge clk);

            @(negedge clk);
            mode_in = 1'b0; x_in = 16'sd16384; y_in = 16'sd0; z_in = 16'sd0;
            valid_in = 1'b1;
            @(posedge clk);
            @(negedge clk);
            valid_in = 1'b0;

            // The input-capture edge itself (the @(posedge clk) right after
            // valid_in was raised, above) counts as cycle 1 of the LATENCY-
            // cycle pipeline delay - this matches run_directed_test's
            // convention exactly (there: 1 edge to capture + repeat(LATENCY-1)
            // more edges = LATENCY edges total before sampling). So here we
            // must only assert "still low" for LATENCY-2 MORE edges (cycles
            // 2 .. LATENCY-1), then the single edge after that is cycle
            // LATENCY, where valid_out is expected to assert.
            saw_early_valid = 1'b0;
            for (k = 0; k < LATENCY - 2; k = k + 1) begin
                @(posedge clk);
                @(negedge clk);
                if (valid_out) saw_early_valid = 1'b1;
            end
            report(!saw_early_valid, "reset: valid_out inactive until the full pipeline latency has elapsed");

            @(posedge clk);
            @(negedge clk);
            report(valid_out === 1'b1, "reset: valid_out asserts exactly at cycle LATENCY after a valid input");
        end
    endtask

    // =========================================================================
    // main test sequence
    // =========================================================================
    integer t;
    initial begin
        rst_n = 1'b0; valid_in = 1'b0; mode_in = 1'b0;
        x_in = 0; y_in = 0; z_in = 0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("================================================================");
        $display("Section A+B: directed rotation and vectoring tests (latency=%0d)", LATENCY);
        $display("================================================================");
        for (t = 0; t < NUM_TV; t = t + 1)
            run_directed_test(t);

        $display("================================================================");
        $display("Section C: streaming back-to-back test");
        $display("================================================================");
        run_streaming_test;

        $display("================================================================");
        $display("Section D: reset behaviour");
        $display("================================================================");
        run_reset_test;

        $display("================================================================");
        $display("SUMMARY");
        $display("================================================================");
        $display("Total tests  : %0d", total_tests);
        $display("Passed       : %0d", passed_tests);
        $display("Failed       : %0d", failed_tests);
        if (failed_tests == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", failed_tests);

        $finish;
    end

    initial begin
        #100000;
        $display("[TIMEOUT] simulation did not finish in time");
        $finish;
    end

endmodule
