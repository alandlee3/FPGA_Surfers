`timescale 1ns / 1ps
`default_nettype none

module top_level(
        input wire          clk_100mhz,
        output logic [15:0] led,

        input wire [15:0]   sw,
        input wire [3:0]    btn,
        output logic [2:0]  rgb0,
        output logic [2:0]  rgb1,

        // seven segment
        output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
        output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
        output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
        output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits

        // hdmi port
        output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
        output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
        output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock

        // (DDR3) ports
        inout wire [15:0]   ddr3_dq, //data input/output
        inout wire [1:0]    ddr3_dqs_n, //data input/output differential strobe (negative)
        inout wire [1:0]    ddr3_dqs_p, //data input/output differential strobe (positive)
        output wire [13:0]  ddr3_addr, //address
        output wire [2:0]   ddr3_ba, //bank address
        output wire         ddr3_ras_n, //row active strobe
        output wire         ddr3_cas_n, //column active strobe
        output wire         ddr3_we_n, //write enable
        output wire         ddr3_reset_n, //reset (active low!!!)
        output wire         ddr3_clk_p, //general differential clock (p)
        output wire         ddr3_clk_n, //general differential clock (n)
        output wire         ddr3_clke, //clock enable
        output wire [1:0]   ddr3_dm, //data mask
        output wire         ddr3_odt //on-die termination (helps impedance match)
);

    ///////////////////////////////////////////////////////// CLOCKS & RESET //////////////////////////////////////////////////////////////

    logic clk_render;

    // Clock and Reset Signals
    logic          sys_rst_pixel;
    logic          sys_rst_controller;
    logic          sys_rst_render;

    assign sys_rst_render = sw[0];
    assign sys_rst_pixel = sw[0];

    logic          clk_pixel;
    logic          clk_5x;
    logic          clk_xc;

    logic          clk_100_passthrough;

    // clocking wizards to generate the clock speeds we need for our different domains
    // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
    cw_hdmi_clk_wiz wizard_hdmi(
        .sysclk(clk_100_passthrough),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(0),
        .locked()
    );

    logic clk_controller;
    logic clk_ddr3;
    logic i_ref_clk;
    logic clk_ddr3_90;

    logic lab06_clk_locked;

    lab06_clk_wiz lcw(
        .reset(sw[0]),
        .clk_in1(clk_100mhz),
        .clk_camera(i_ref_clk),
        .clk_xc(clk_xc),
        .clk_passthrough(clk_100_passthrough),
        .clk_controller(clk_controller),
        .clk_ddr3(clk_ddr3),
        .clk_ddr3_90(clk_ddr3_90),
        .locked(lab06_clk_locked)
    );

    // Currently using 83.333 MHz clock as driver
    assign clk_render = clk_controller;

    // assign i_ref_clk = clk_render;

    (* mark_debug = "true" *) wire ddr3_clk_locked;

    assign ddr3_clk_locked = lab06_clk_locked;

     ///////////////////////////////////////// OBSTACLE GENERATION //////////////////////////////////////////////////////////////////
    logic new_frame; // TODO: need to wire up to something to be single-cycle high at start of each frame
    logic [15:0] obstacle;
    logic obstacle_valid;
    logic firstrow;
    logic obstacles_done;
    
    obstacle_generator #(.CYCLES_PER_OBSTACLE(30)) obs_gen (
        .clk(clk_render),
        .rst(state == RST),
        .activate(new_frame), // one cycle high activate

        .valid(obstacle_valid),
        .first_row(firstrow),
        .obstacle(obstacle), // 3 bits type, 2 bits lane, 11 bits depth (unsigned), the END of the obstacle
        .done(obstacles_done) // wired to 3d projection
    );

    ////////////////////////////////////////////// PROJECTION /////////////////////////////////////////////////////////////

    logic projector_done;

    full_projector full_projector_inst (
        .clk(clk_render),
        .rst(state == RST),
        .obstacle(obstacle),
        .obstacle_valid(obstacle_valid),
        .done_in(obstacles_done),

        .player_height(player_height),
        .player_lane(player_lane),

        .triangle(render_triangle),
        .triangle_valid(render_triangle_valid),
        .done_out(projector_done)
    );

    ///////////////////////////////////////// GAME LOGIC //////////////////////////////////////////////////////////////////
    logic [3:0] clean_controls; // left, duck, jump, right in that order

    logic game_over;
    logic [1:0] player_lane;
    logic signed [15:0] player_height;
    logic [15:0] player_score;

    generate
        genvar d;
        for (d = 0; d < 4; d=d+1) begin
            debouncer #(.CLK_PERIOD_NS(12),
                        .DEBOUNCE_TIME_MS(50)) game_debouncers
                (.clk(clk_render),
                .rst(state == RST),
                .dirty(btn[d]),
                .clean(clean_controls[d]));
        end
    endgenerate

    logic obstacle_in_half_block;
    logic signed [15:0] ground_level;
    logic [5:0] half_block_progress;

    game_logic #(
        .HALF_BLOCK_LENGTH(64), // length in "score points" of half block
        .GRAVITY(1), // how much vertical velocity decreases per frame
        .DUCK_LIMIT(15), // how long a duck lasts for
        .VERTICAL_JUMP(10), // how much vertical velocity a jump gives
        .SPEED(1), // how many "score points" we move up per frame, MUST divide HALF_BLOCK_LENGTH/2
        .GROUND(-128), // where the floor of the game is (no train car)
        .MARGIN_OF_ERROR(15) // how below the ground level of a train car we can be without dying
    ) game (
        .clk(clk_render),
        .rst(state == RST),
        .new_frame(new_frame),
        .obstacle(obstacle),
        .obstacle_valid(obstacle_valid),
        .duck(clean_controls[2]),
        .jump(clean_controls[1]),
        .left(clean_controls[3]),
        .right(clean_controls[0]),
        .firstrow(firstrow), // high only if obstacle is in the first row (valid to check collisions)
        .game_over(game_over),
        .player_lane(player_lane),
        .player_height(player_height),
        .player_score(player_score),
        .obstacle_in_half_block(obstacle_in_half_block),
        .ground_level(ground_level),
        .half_block_progress(half_block_progress)
    );

    ///////////////////////////////////////// RENDERING //////////////////////////////////////////////////////////////////

    logic [8:0] render_h_count;
    logic [7:0] render_v_count;
    logic render_valid;
    logic [15:0] render_pixel;

    logic render_active;
    logic render_done;

    logic [127:0] render_triangle;
    logic render_triangle_valid;

    renderer renderer_inst (
        .clk(clk_render),
        .rst(state == RST),
        .active(render_active),
        .triangle(render_triangle),
        .triangle_valid(render_triangle_valid),

        .h_count(render_h_count),
        .v_count(render_v_count),
        .valid(render_valid),
        .last(),
        .data(render_pixel),

        .done(render_done)
    );
    
    //////////////////////////////////////////////////////// FSM ///////////////////////////////////////////////////////////

    typedef enum { 
        RST,
        START,
        WAIT, // must wait like 30 cycles for done signal to clear out
        WAIT2,
        GENERATION,
        RENDERING,
        DONE // a way for us to slow down frame rate
    } tl_state;

    tl_state state;

    logic [6:0] wait_counter;
    logic [31:0] lag_counter;

    always_ff @( posedge clk_render ) begin
        new_frame <= 0;

        if(sw[0]) begin
            state <= RST;
        end else if (state == RST) begin
            render_active <= 0;
            state <= START;
            lag_counter <= 0;
        end else if (state == START) begin
            render_active <= 0;
            state <= WAIT;
            new_frame <= 1;
            wait_counter <= 0;
            lag_counter <= lag_counter + 1;
        end else if(state == WAIT) begin
            lag_counter <= lag_counter + 1;
            wait_counter <= wait_counter + 1;

            if(wait_counter == 100) begin
                state <= GENERATION;
            end
        end else if(state == GENERATION) begin
            lag_counter <= lag_counter + 1;
            if(projector_done) begin
                state <= RENDERING;
                render_active <= 1;
            end
        end else if(state == RENDERING) begin
            if (render_done && lag_counter >= {sw[15:8],16'b0000000000000000}) begin
                state <= START;
                lag_counter <= 0;
            end else begin
                lag_counter <= lag_counter + 1;
            end
        end
    end

    ///////////////////////////////////// HDEF FRAME BUFFER //////////////////////////////////////

    logic [15:0] frame_buff_dram; // data out of DRAM frame buffer

    // Currently not being used, still wired to ports tho for easy access in the future
    // When being used, DRAM will get overwhelmed with high frequency of writes. Can really only be maybe 100MHz.
    // When I tried with 200 MHz, did not work properly.

    high_definition_frame_buffer highdef_fb(
        // Input data from game
        .clk_camera      (clk_render),
        .sys_rst_camera  (sys_rst_render),
        .camera_valid    (0),
        .camera_pixel    (0),
        .camera_h_count  (0),
        .camera_v_count  (0),
        
        // Output data to HDMI display pipeline
        .clk_pixel       (clk_pixel),
        .sys_rst_pixel   (sys_rst_pixel),
        .active_draw_hdmi(0),
        .h_count_hdmi    (0),
        .v_count_hdmi    (0),
        .frame_buff_dram (),

        // Clock/reset signals for UberDDR3 controller
        .clk_controller  (clk_controller),
        .clk_ddr3        (clk_ddr3),
        .clk_ddr3_90     (clk_ddr3_90),
        .i_ref_clk       (i_ref_clk),
        .i_rst           (sys_rst_controller),
        .ddr3_clk_locked (ddr3_clk_locked),

        // Bus wires to connect FPGA to SDRAM chip
        .ddr3_dq         (ddr3_dq[15:0]),
        .ddr3_dqs_n      (ddr3_dqs_n[1:0]),
        .ddr3_dqs_p      (ddr3_dqs_p[1:0]),
        .ddr3_addr       (ddr3_addr[13:0]),
        .ddr3_ba         (ddr3_ba[2:0]),
        .ddr3_ras_n      (ddr3_ras_n),
        .ddr3_cas_n      (ddr3_cas_n),
        .ddr3_we_n       (ddr3_we_n),
        .ddr3_reset_n    (ddr3_reset_n),
        .ddr3_clk_p      (ddr3_clk_p),
        .ddr3_clk_n      (ddr3_clk_n),
        .ddr3_clke       (ddr3_clke),
        .ddr3_dm         (ddr3_dm[1:0]),
        .ddr3_odt        (ddr3_odt)
    );

    //////////////////////////////////////////// HDMI Wiring //////////////////////////////////////////

    // // video signal generator signals
    logic           h_sync_hdmi;
    logic           v_sync_hdmi;
    logic [10:0]    h_count_hdmi;
    logic [9:0]     v_count_hdmi;
    logic           active_draw_hdmi;
    logic           new_frame_hdmi;
    logic [5:0]     frame_count_hdmi;

    // // HDMI video signal generator
    video_sig_gen vsg (
        .pixel_clk(clk_pixel),
        .rst(sys_rst_pixel),
        .h_count(h_count_hdmi),
        .v_count(v_count_hdmi),
        .v_sync(v_sync_hdmi),
        .h_sync(h_sync_hdmi),
        .new_frame(new_frame_hdmi),
        .active_draw(active_draw_hdmi),
        .frame_count(frame_count_hdmi)
    );

    ////////////////////////////////////// BRAM Frame Buffer /////////////////////////////////////////////

    // Temporarily using a BRAM for 320 x 180 quality.
    // The end outputs of this bit of code is the red,green,blue variables at the end

    logic [15:0] frame_buff_raw; // the frame buffer output.

    localparam FB_DEPTH = 320*180;
    localparam FB_SIZE = $clog2(FB_DEPTH);
    logic [FB_SIZE-1:0] addra;
    assign addra = render_v_count * 320 + render_h_count;

    logic [15:0]        camera_mem; //used to pass pixel data into frame buffer

    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(16), //each entry in this memory is 16 bits
        .RAM_DEPTH(FB_DEPTH)) //there are 320*180 or 57600 entries for full frame
    frame_buffer (
        .addra(addra), //pixels are stored using this math
        .clka(clk_render),
        .wea(render_valid),
        .dina(render_pixel),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sw[0]),
        .douta(), //never read from this side
        .addrb(addrb),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sw[0]),
        .regceb(1'b1),
        .doutb(frame_buff_raw)
    );

    logic [FB_SIZE-1:0] addrb; //used to lookup address in memory for reading from buffer
    logic               good_addrb; //used to indicate within valid frame for scaling
    
    // // scale logic! copy in only the 4X zoom logic from last week. XX

    always_ff @(posedge clk_pixel) begin
        // you already wrote this!
        addrb <= (h_count_hdmi >> 2) + 320*(v_count_hdmi >> 2);
        good_addrb <= (h_count_hdmi<1280)&&(v_count_hdmi<720);
    end
    

    //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] red, green, blue;
    always_ff @(posedge clk_pixel)begin
      red <= good_addrb?{frame_buff_raw[15:11],3'b0}:8'b0;
      green <= good_addrb?{frame_buff_raw[10:5], 2'b0}:8'b0;
      blue <= good_addrb?{frame_buff_raw[4:0],3'b0}:8'b0;
    end

    ///////////////////////////////////////////// HDMI Encoding Stuff //////////////////////////////////////

    // HDMI Output: just like before!

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic       tmds_signal [2:0]; //output of each TMDS serializer!

    //three tmds_encoders (blue, green, red)
    //note green should have no control signal like red
    //the blue channel DOES carry the two sync signals:
    //  * control[0] = horizontal sync signal
    //  * control[1] = vertical sync signal

    tmds_encoder tmds_red(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .video_data(red),
        .control(2'b0),
        .video_enable(active_draw_hdmi),
        .tmds(tmds_10b[2])
    );
    tmds_encoder tmds_green(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .video_data(green),
        .control(2'b0),
        .video_enable(active_draw_hdmi),
        .tmds(tmds_10b[1])
    );
    tmds_encoder tmds_blue(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .video_data(blue),
        .control({v_sync_hdmi,h_sync_hdmi}),
        .video_enable(active_draw_hdmi),
        .tmds(tmds_10b[0])
    );


    //three tmds_serializers (blue, green, red):
    //MISSING: two more serializers for the green and blue tmds signals.
    tmds_serializer red_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst_pixel),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2])
    );
    tmds_serializer green_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst_pixel),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1])
    );
    tmds_serializer blue_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst_pixel),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0])
    );

    //output buffers generating differential signals:
    //three for the r,g,b signals and one that is at the pixel clock rate
    //the HDMI receivers use recover logic coupled with the control signals asserted
    //during blanking and sync periods to synchronize their faster bit clocks off
    //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
    //the slower 74.25 MHz clock)
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
    
    ////////////////////////////////////////////////////////// SAMPLING /////////////////////////////////////////////////////

    // shut up those RGBs
    assign rgb0 = 0;
    assign rgb1 = 0;

    logic [3:0] sampled_state;
    logic [15:0] sampled_frame_rate;

    logic [15:0] frame_rate;

    logic [31:0] sampling_counter;
    evt_counter #(.MAX_COUNT(83333333), .WIDTH(32)) sampler_inst (
        .clk(clk_render),
        .rst(sw[0]),
        .evt(1),
        .count(sampling_counter)
    );

    logic [15:0] last_valid_obstacle;
    logic [15:0] sampled_obstacle;

    always_ff @( posedge clk_render ) begin
        if (sampling_counter == 0) begin
            sampled_state <= renderer_inst.state;
            sampled_frame_rate <= frame_rate;
            frame_rate <= 0;
            sampled_obstacle <= last_valid_obstacle;
        end else begin
            if(obstacle_valid) begin
                last_valid_obstacle <= obstacle;
            end
            if (state == START) begin
                frame_rate <= frame_rate + 1;
            end
        end
    end

    logic [6:0] ss_c;

    // sampled_frame_rate can also be displayed here
    seven_segment_controller mssc(
     .clk(clk_render),
     .rst(sys_rst_render),
     .val({ground_level, player_height}),
     .cat(ss_c),
     .an({ss0_an, ss1_an})
     );

    assign ss0_c = ss_c; //control upper four digit's cathodes!
    assign ss1_c = ss_c; //same as above but for lower four digits!

    // assign led[3:0] = obs_gen.obstacle_storage[15][0];
    // assign led[9:4] = num_obstacles;

    // assign led[15:12] = sampled_state;
    // assign led[7] = 0;
    assign led[7:0] = renderer_inst.num_triangles[7:0];

    assign led[15] = game_over;
    assign led[14] = obstacle_in_half_block;
    // assign led[13] = reached;
    // assign led[4] = render_pixel[15];
    // assign led[3] = render_h_count[8];
    // assign led[2] = render_valid;
    // assign led[1] = render_done;
    // assign led[0] = render_active;
    

endmodule // top_level


`default_nettype wire