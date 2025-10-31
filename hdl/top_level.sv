`timescale 1ns / 1ps
`default_nettype none

module top_level
    (
        input wire          clk_100mhz,
        output logic [15:0] led,
        // camera bus
        input wire [7:0]    camera_d, // 8 parallel data wires
        output logic        cam_xclk, // XC driving camera
        input wire          cam_h_sync, // camera h_sync wire
        input wire          cam_v_sync, // camera v_sync wire
        input wire          cam_pclk, // camera pixel clock
        inout wire          i2c_scl, // i2c inout clock
        inout wire          i2c_sda, // i2c inout data
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
        output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
    );
    // shut up those RGBs
    assign rgb1 = 0;

    // Clock and Reset Signals
    logic          sys_rst_camera;
    logic          sys_rst_pixel;

    logic          clk_camera;
    logic          clk_pixel;
    logic          clk_5x;
    logic          clk_xc;

    logic clk_camera_locked;

    logic          clk_100_passthrough;

    // clocking wizards to generate the clock speeds we need for our different domains
    // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
    cw_hdmi_clk_wiz wizard_hdmi(
        .sysclk(clk_100_passthrough),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(0)
    );

    cw_fast_clk_wiz wizard_migcam(
        .clk_in1(clk_100mhz),
        .clk_camera(clk_camera),
        .locked(clk_camera_locked),
        .clk_xc(clk_xc),
        .clk_100(clk_100_passthrough),
        .reset(0)
    );

    // assign camera's xclk to pmod port: drive the operating clock of the camera!
    // this port also is specifically set to high drive by the XDC file.
    assign cam_xclk = clk_xc;
    //assign sys_rst_camera = btn[0]; //use for resetting camera side of logic
    //assign sys_rst_pixel = btn[0]; //use for resetting hdmi/draw side of logic


    // video signal generator signals
    logic           h_sync_hdmi;
    logic           v_sync_hdmi;
    logic [10:0]    h_count_hdmi;
    logic [9:0]     v_count_hdmi;
    logic           active_draw_hdmi;
    logic           new_frame_hdmi;
    logic [5:0]     frame_count_hdmi;

    // rgb output values
    logic [7:0]     red,green,blue;

    // ** Handling input from the camera **

    // synchronizers to prevent metastability
    logic [7:0]     camera_d_buf [1:0];
    logic           cam_h_sync_buf [1:0];
    logic           cam_v_sync_buf [1:0];
    logic           cam_pclk_buf [1:0];

    logic           sys_rst_camera_buf [1:0];
    logic           sys_rst_pixel_buf [1:0];

    always_ff @(posedge clk_pixel )begin
        sys_rst_pixel_buf <= {btn[0], sys_rst_pixel_buf[1]};
    end
    assign sys_rst_pixel = sys_rst_pixel_buf[0];

    always_ff @(posedge clk_camera) begin
        camera_d_buf <= {camera_d, camera_d_buf[1]};
        cam_pclk_buf <= {cam_pclk, cam_pclk_buf[1]};
        cam_h_sync_buf <= {cam_h_sync, cam_h_sync_buf[1]};
        cam_v_sync_buf <= {cam_v_sync, cam_v_sync_buf[1]};
        sys_rst_camera_buf <= {btn[0], sys_rst_camera_buf[1]};
    end

    assign sys_rst_camera = sys_rst_camera_buf[0] || !clk_camera_locked;

    logic [10:0]    camera_h_count;
    logic [9:0]     camera_v_count;
    logic [15:0]    camera_pixel;
    logic           camera_valid;

    // your pixel_reconstruct module, from the exercise!
    // hook it up to buffered inputs.
    pixel_reconstruct(
        .clk(clk_camera),
        .rst(sys_rst_camera),
        .camera_pclk(cam_pclk_buf[0]),
        .camera_h_sync(cam_h_sync_buf[0]),
        .camera_v_sync(cam_v_sync_buf[0]),
        .camera_data(camera_d_buf[0]),
        .pixel_valid(camera_valid),
        .pixel_h_count(camera_h_count),
        .pixel_v_count(camera_v_count),
        .pixel_data(camera_pixel)
    );

    //----------------BEGIN NEW STUFF FOR LAB 07------------------
    //clock domain cross (from clk_camera to clk_pixel)
    //switching from camera clock domain to pixel clock domain early
    //this lets us do convolution on the 74.25 MHz clock rather than the
    //200 MHz clock domain that the camera lives on.
    logic empty;
    logic cdc_valid;
    logic [15:0] cdc_pixel;
    logic [10:0] cdc_h_count;
    logic [9:0] cdc_v_count;


    xpm_fifo_async #(
       .CASCADE_HEIGHT(0),            // DECIMAL
       .CDC_SYNC_STAGES(2),           // DECIMAL
       .DOUT_RESET_VALUE("0"),        // String
       .ECC_MODE("no_ecc"),           // String
       .EN_SIM_ASSERT_ERR("warning"), // String
       .FIFO_MEMORY_TYPE("auto"),     // String
       .FIFO_READ_LATENCY(1),         // DECIMAL
       .FIFO_WRITE_DEPTH(64),       // DECIMAL
       .FULL_RESET_VALUE(0),          // DECIMAL
       .PROG_EMPTY_THRESH(10),        // DECIMAL
       .PROG_FULL_THRESH(10),         // DECIMAL
       .RD_DATA_COUNT_WIDTH(1),       // DECIMAL
       .READ_DATA_WIDTH(37),          // DECIMAL
       .READ_MODE("std"),             // String
       .RELATED_CLOCKS(0),            // DECIMAL
       .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
       .USE_ADV_FEATURES("0707"),     // String
       .WAKEUP_TIME(0),               // DECIMAL
       .WRITE_DATA_WIDTH(37),         // DECIMAL
       .WR_DATA_COUNT_WIDTH(1)        // DECIMAL
    )
    cdc_fifo (
        .wr_clk(clk_camera),
        .full(),
        .din({camera_h_count, camera_v_count, camera_pixel}),
        .wr_en(camera_valid),

        .rd_clk(clk_pixel),
        .empty(empty),
        .dout({cdc_h_count, cdc_v_count, cdc_pixel}),
        .rd_en(1) //always read
    );


    assign cdc_valid = ~empty; //watch when empty. Ready immediately if something there

    //----
    //Filter 0: 1280x720 convolution of gaussian blur
    logic [10:0] f0_h_count;  //h_count from filter0 module
    logic [9:0] f0_v_count; //v_count from filter0 module
    logic [15:0] f0_pixel; //pixel data from filter0 module
    logic f0_valid; //valid signals for filter0 module
    //full resolution filter
    filter #(.K_SELECT(1),.HRES(1280),.VRES(720)) filtern(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .data_in_valid(cdc_valid),
        .pixel_data_in(cdc_pixel),
        .h_count_in(cdc_h_count),
        .v_count_in(cdc_v_count),
        .data_out_valid(f0_valid),
        .pixel_data_out(f0_pixel),
        .h_count_out(f0_h_count),
        .v_count_out(f0_v_count)
    );

    //----
    logic [10:0] lb_h_count;  //h_count to filter modules
    logic [9:0] lb_v_count; //v_count to filter modules
    logic [15:0] lb_pixel; //pixel data to filter modules
    logic lb_valid; //valid signals to filter modules

    //selection logic to either go through (btn[1]=1)
    //or bypass (btn[1]==0) the first filter
    //in the first part of lab as you develop line buffer, you'll want to bypass
    //since your filter won't be working, but it would be good to test the
    //downsampling line buffer below on its own
    always_ff @(posedge clk_pixel) begin
        if (btn[1])begin
            ds_h_count <= cdc_h_count;
            ds_v_count <= cdc_v_count;
            ds_pixel <= cdc_pixel;
            ds_valid <= cdc_valid;
        end else begin
            ds_h_count <= f0_h_count;
            ds_v_count <= f0_v_count;
            ds_pixel <= f0_pixel;
            ds_valid <= f0_valid;
        end
    end

    //----
    //A line buffer that, in conjunction with the control signal will down sample
    //the camera (or f0 filter) values from 1280x720 to 320x180
    //in reality we could get by without this, but it does make things a little easier
    //and we've also added it since it gives us a means of testing the line buffer
    //design outside of the filter.
    logic [2:0][15:0] lb_buffs; //grab output of down sample line buffer
    logic ds_control; //controlling when to write (every fourth pixel and line)
    logic [10:0] ds_h_count;  //h_count to downsample line buffer
    logic [9:0] ds_v_count; //v_count to downsample line buffer
    logic [15:0] ds_pixel; //pixel data to downsample line buffer
    logic ds_valid; //valid signals to downsample line buffer
    assign ds_control = ds_valid&&(ds_h_count[1:0]==2'b0)&&(ds_v_count[1:0]==2'b0);
    line_buffer #(.HRES(320), .VRES(180)) ds_lbuff (
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .data_in_valid(ds_control),
        .pixel_data_in(ds_pixel),
        .h_count_in(ds_h_count[10:2]),
        .v_count_in(ds_v_count[9:2]),
        .data_out_valid(lb_valid),
        .line_buffer_out(lb_buffs),
        .h_count_out(lb_h_count),
        .v_count_out(lb_v_count)
    );

    assign lb_pixel = lb_buffs[1]; //pass on only the middle one.

    //----
    //Create six different filters that all exist in parallel
    //The outputs of all six filters are fed into the unpacked arrays below:
    logic [10:0] f_h_count [5:0];  //h_count from filter modules
    logic [9:0] f_v_count [5:0]; //v_count from filter modules
    logic [15:0] f_pixel [5:0]; //pixel data from filter modules
    logic f_valid [5:0]; //valid signals for filter modules

    //using generate/genvar, create five *Different* instances of the
    //filter module (you'll write that).  Each filter will implement a different
    //kernel
    generate
        genvar i;
        for (i=0; i<6; i=i+1)begin
            filter #(.K_SELECT(i),.HRES(320),.VRES(180))filterm(
                .clk(clk_pixel),
                .rst(sys_rst_pixel),
                .data_in_valid(lb_valid),
                .pixel_data_in(lb_pixel),
                .h_count_in(lb_h_count),
                .v_count_in(lb_v_count),
                .data_out_valid(f_valid[i]),
                .pixel_data_out(f_pixel[i]),
                .h_count_out(f_h_count[i]),
                .v_count_out(f_v_count[i])
            );
        end
    endgenerate

    //combine hor and vert signals from filters 4 and 5 for special signal:
    logic [7:0] fcomb_r, fcomb_g, fcomb_b;
    assign fcomb_r = (f_pixel[4][15:11]+f_pixel[5][15:11])>>1;
    assign fcomb_g = (f_pixel[4][10:5]+f_pixel[5][10:5])>>1;
    assign fcomb_b = (f_pixel[4][4:0]+f_pixel[5][4:0])>>1;

    //------
    //Choose which filter to use
    //based on values of sw[2:0] select which filter output gets handed on to the
    //next module. We must make sure to route h_count, v_count, pixels and valid signal
    // for each module.  Could have done this with a for loop as well!  Think
    // about it!
    logic [10:0] fmux_h_count; //h_count from filter mux
    logic [9:0]  fmux_v_count; //v_count from filter mux
    logic [15:0] fmux_pixel; //pixel data from filter mux
    logic fmux_valid; //data valid from filter mux

    //000 Identity Kernel
    //001 Gaussian Blur
    //010 Sharpen
    //011 Ridge Detection
    //100 Sobel Y-axis Edge Detection
    //101 Sobel X-axis Edge Detection
    //110 Total Sobel Edge Detection
    //111 Output of Line Buffer Directly (Helpful for debugging line buffer in first part)
    always_ff @(posedge clk_pixel)begin
        case (sw[2:0])
            3'b000: begin
                fmux_h_count <= f_h_count[0];
                fmux_v_count <= f_v_count[0];
                fmux_pixel <= f_pixel[0];
                fmux_valid <= f_valid[0];
            end
            3'b001: begin
                fmux_h_count <= f_h_count[1];
                fmux_v_count <= f_v_count[1];
                fmux_pixel <= f_pixel[1];
                fmux_valid <= f_valid[1];
            end
            3'b010: begin
                fmux_h_count <= f_h_count[2];
                fmux_v_count <= f_v_count[2];
                fmux_pixel <= f_pixel[2];
                fmux_valid <= f_valid[2];
            end
            3'b011: begin
                fmux_h_count <= f_h_count[3];
                fmux_v_count <= f_v_count[3];
                fmux_pixel <= f_pixel[3];
                fmux_valid <= f_valid[3];
            end
            3'b100: begin
                fmux_h_count <= f_h_count[4];
                fmux_v_count <= f_v_count[4];
                fmux_pixel <= f_pixel[4];
                fmux_valid <= f_valid[4];
            end
            3'b101: begin
                fmux_h_count <= f_h_count[5];
                fmux_v_count <= f_v_count[5];
                fmux_pixel <= f_pixel[5];
                fmux_valid <= f_valid[5];
            end
            3'b110: begin
                fmux_h_count <= f_h_count[4];
                fmux_v_count <= f_v_count[4];
                fmux_pixel <= {fcomb_r[4:0],fcomb_g[5:0],fcomb_b[4:0]};
                fmux_valid <= f_valid[4]&&f_valid[5];
            end
            default: begin
                fmux_h_count <= lb_h_count;
                fmux_v_count <= lb_v_count;
                fmux_pixel <= lb_pixel;
                fmux_valid <= lb_valid;
            end
        endcase
    end

    localparam FB_DEPTH = 320*180;
    localparam FB_SIZE = $clog2(FB_DEPTH);
    logic [FB_SIZE-1:0] addra; //used to specify address to write to in frame buffer
    logic valid_camera_mem; //used to enable writing pixel data to frame buffer
    logic [15:0] camera_mem; //used to pass pixel data into frame buffer

    //because the down sampling already happened upstream, there's no need to do here.
    always_ff @(posedge clk_pixel) begin
        if(fmux_valid) begin
            addra <= fmux_h_count + fmux_v_count * 320;
            camera_mem <= fmux_pixel;
            valid_camera_mem <= 1;
        end else begin
            valid_camera_mem <= 0;
        end
    end
    //end of new Lab 7 stuff.....

    //two-port BRAM used to hold image from camera.
    //The camera is producing video at 720p and 30fps, but we can't store all of that
    //we're going to down-sample by a factor of 4 in both dimensions
    //so we have 320 by 180.  this is kinda a bummer, but we'll fix it
    //in future weeks by using off-chip DRAM.
    //even with the down-sample, because our camera is producing data at 30fps
    //and  our display is running at 720p at 60 fps, there's no hope to have the
    //production and consumption of inew_frameormation be synchronized in this system.
    //even if we could line it up once, the clocks of both systems will drift over time
    //so to avoid this sync issue, we use a conew_framelict-resolution device...the frame buffer
    //instead we use a frame buffer as a go-between. The camera sends pixels in at
    //its own rate, and we pull them out for display at the 720p rate/requirement
    //this avoids the whole sync issue. It will however result in artifacts when you
    //introduce fast motion in front of the camera. These lines/tears in the image
    //are the result of unsynced frame-rewriting happening while displaying. It won't
    //matter for slow movement


    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(16), //each entry in this memory is 16 bits
        .RAM_DEPTH(FB_DEPTH)) //there are 320*180 or 57600 entries for full frame
    frame_buffer (
        .addra(addra), //pixels are stored using this math
        .clka(clk_pixel), //was previous clk_camera!!! but clock-domain crossing happens earlier now!
        .wea(valid_camera_mem),
        .dina(camera_mem),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst_camera),
        .douta(), //never read from this side
        .addrb(addrb),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst_pixel),
        .regceb(1'b1),
        .doutb(frame_buff_raw)
    );


    logic [15:0] frame_buff_raw; //data out of frame buffer (565)
    logic [FB_SIZE-1:0] addrb; //used to lookup address in memory for reading from buffer
    logic good_addrb; //used to indicate within valid frame for scaling


    //TO DO in camera part 1:
    // Scale pixel coordinates from HDMI to the frame buffer to grab the right pixel
    //scaling logic!!! You need to complete!!! We want 1X, 2X, and 4X!
    always_ff @(posedge clk_pixel)begin
        addrb <= ((h_count_hdmi >> 2)) + 320*(v_count_hdmi >> 2);
        good_addrb <= (h_count_hdmi<1280)&&(v_count_hdmi<720);
    end

    //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] fb_red, fb_green, fb_blue;
    always_ff @(posedge clk_pixel)begin
        fb_red <= good_addrb?{frame_buff_raw[15:11],3'b0}:8'b0;
        fb_green <= good_addrb?{frame_buff_raw[10:5], 2'b0}:8'b0;
        fb_blue <= good_addrb?{frame_buff_raw[4:0],3'b0}:8'b0;
    end
    // Pixel Processing pre-HDMI output

    // RGB to YCrCb

    //output of rgb to ycrcb conversion (10 bits due to module):
    logic [9:0] y_full, cr_full, cb_full; //ycrcb conversion of full pixel
    //bottom 8 of y, cr, cb conversions:
    logic [7:0] y, cr, cb; //ycrcb conversion of full pixel
    //Convert RGB of full pixel to YCrCb
    //See lecture 07 for YCrCb discussion.
    //Module has a 3 cycle latency
    rgb_to_ycrcb rgbtoycrcb_m(
        .clk(clk_pixel),
        .r(fb_red),
        .g(fb_green),
        .b(fb_blue),
        .y(y_full),
        .cr(cr_full),
        .cb(cb_full)
    );

    //take lower 8 of full outputs.
    // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
    assign y = y_full[7:0];
    assign cr = {!cr_full[7],cr_full[6:0]};
    assign cb = {!cb_full[7],cb_full[6:0]};

    //channel select module (select which of six color channels to mask):
    logic [2:0] channel_sel;
    logic [7:0] selected_channel; //selected channels
    //selected_channel could contain any of the six color channels depend on selection

    //threshold module (apply masking threshold):
    logic [7:0] lower_threshold;
    logic [7:0] upper_threshold;
    logic mask; //Whether or not thresholded pixel is 1 or 0

    //Center of Mass variables (tally all mask=1 pixels for a frame and calculate their center of mass)
    logic [10:0] x_com, x_com_calc; //long term x_com and output from module, resp
    logic [9:0] y_com, y_com_calc; //long term y_com and output from module, resp
    logic new_com; //used to know when to update x_com and y_com ...


    assign channel_sel = {1'b1, sw[4:3]}; //[3:1];
    // * 3'b000: green
    // * 3'b001: red
    // * 3'b010: blue
    // * 3'b011: not valid
    // * 3'b100: y (luminance)
    // * 3'b101: Cr (Chroma Red)
    // * 3'b110: Cb (Chroma Blue)
    // * 3'b111: not valid
    //Channel Select: Takes in the full RGB and YCrCb inew_frameormation and
    // chooses one of them to output as an 8 bit value
    channel_select mcs(
        .select(channel_sel),
        .r(fb_red),    
        .g(fb_green), 
        .b(fb_blue), 
        .y(y),
        .cr(cr),
        .cb(cb),
        .selected_channel(selected_channel)
    );

    //threshold values used to determine what value  passes:
    assign lower_threshold = {sw[11:8],4'b0};
    assign upper_threshold = {sw[15:12],4'b0};

    //Thresholder: Takes in the full selected channedl and
    //based on upper and lower bounds provides a binary mask bit
    // * 1 if selected channel is within the bounds (inclusive)
    // * 0 if selected channel is not within the bounds
    threshold mt(
       .clk(clk_pixel),
       .rst(sys_rst_pixel),
       .pixel(selected_channel),
       .lower_bound(lower_threshold),
       .upper_bound(upper_threshold),
       .mask(mask) //single bit if pixel within mask.
    );


    logic [6:0] ss_c;
    //modified version of seven segment display for showing
    // thresholds and selected channel
    // special customized version
    lab05_ssc mssc(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .lower_threshold(lower_threshold),
        .upper_threshold(upper_threshold),
        .channel_select(channel_sel),
        .cathode(ss_c),
        .anode({ss0_an, ss1_an})
    );
    assign ss0_c = ss_c; //control upper four digit's cathodes!
    assign ss1_c = ss_c; //same as above but for lower four digits!

    //Center of Mass Calculation: (you need to do)
    //using x_com_calc and y_com_calc values
    //Center of Mass:
    center_of_mass com_m(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .pixel_x(h_count_hdmi),  
        .pixel_y(v_count_hdmi), 
        .pixel_valid(mask), //aka threshold
        .calculate((new_frame_hdmi)),
        .com_x(x_com_calc),
        .com_y(y_com_calc),
        .com_valid(new_com)
    );
    //grab logic for above
    //update center of mass x_com, y_com based on new_com signal
    always_ff @(posedge clk_pixel)begin
        if (sys_rst_pixel)begin
            x_com <= 0;
            y_com <= 0;
        end if(new_com)begin
            x_com <= x_com_calc;
            y_com <= y_com_calc;
        end
    end

    //image_sprite output:
    logic [7:0] img_red, img_green, img_blue;

    //bring in an instance of your popcat image sprite! remember the correct mem files too!

    logic [31:0] pop_counter;
    logic pop;

    always_ff @(posedge clk_pixel)begin
        if (pop_counter==30_000_000)begin
            pop_counter <= 0;
            pop <= ~pop;
        end else begin
            pop_counter <= pop_counter + 1 ;
        end
    end
    //bring in an instance of your popcat image sprite! remember the correct mem files too!
    image_sprite_2 #(
        .WIDTH(256),
        .HEIGHT(256))
    com_sprite_m (
    .pixel_clk(clk_pixel),
    .rst(sys_rst_pixel),
    .pop(pop),
    .h_count(h_count_hdmi),   
    .v_count(v_count_hdmi),   
    .x(x_com>128 ? x_com-128 : 0),
    .y(y_com>128 ? y_com-128 : 0),
    .pixel_red(img_red),
    .pixel_green(img_green),
    .pixel_blue(img_blue)); //output colors

    //crosshair output:
    logic [7:0] ch_red, ch_green, ch_blue;

    //Create Crosshair patter on center of mass:
    //0 cycle latency
    always_comb begin
        ch_red   = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
        ch_green = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
        ch_blue  = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
    end


    // HDMI video signal generator
    video_sig_gen vsg(
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


    // Video Mux: select from the different display modes based on switch values
    //used with switches for display selections
    logic [1:0] background_choice;
    logic [1:0] target_choice;

    //assign background_choice = sw[5:4];
    //assign target_choice =  sw[7:6];

    assign background_choice = sw[6:5]; //was [5:4]; not anymore
    assign target_choice =  {1'b0,sw[7]}; //was [7:6]; not anymore

    //choose what background from the camera:
    // * 'b00:  normal camera out
    // * 'b01:  selected channel image in grayscale
    // * 'b10:  masked pixel (all on if 1, all off if 0)
    // * 'b11:  chroma channel with mask overtop as magenta
    //
    //then choose what to use with center of mass:
    // * 'b00: nothing
    // * 'b01: crosshair
    // * 'b10: sprite on top
    // * 'b11: nothing

    video_mux mvm(
        .background_choice(background_choice), //choose background
        .target_choice(target_choice), //choose target
        .camera_pixel({fb_red, fb_green, fb_blue}), 
        .camera_y_channel(y), //luminance 
        .selected_channel(selected_channel), //current channel being drawn 
        .thresholded_pixel(mask), //one bit mask signal 
        .crosshair({ch_red, ch_green, ch_blue}), 
        .com_sprite_pixel({img_red, img_green, img_blue}), 
        .muxed_pixel({red,green,blue}) //output to tmds
    );

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

    // Nothing To Touch Down Here:
    // register writes to the camera

    // The OV5640 has an I2C bus connected to the board, which is used
    // for setting all the hardware settings (gain, white balance,
    // compression, image quality, etc) needed to start the camera up.
    // We've taken care of setting these all these values for you:
    // "rom.mem" holds a sequence of bytes to be sent over I2C to get
    // the camera up and running, and we've written a design that sends
    // them just after a reset completes.

    // If the camera is not giving data, press your reset button.

    logic  busy, bus_active;
    logic  cr_init_valid, cr_init_ready;

    logic request_config;

    localparam DELAY_CLOCK_CYCLES = 200_000_000 * 1;
    logic [$clog2(DELAY_CLOCK_CYCLES):0] count_delay;

    always_ff @(posedge clk_camera) begin
        if (sys_rst_camera) begin
            request_config <= 1'b0;
            cr_init_valid  <= 1'b0;
            count_delay <= 'b0;
        end else if (btn[2]) begin
            request_config <= 1'b1;
            cr_init_valid  <= 1'b0;
            count_delay <= 'b0;
        end else if (request_config) begin
            if (count_delay >= DELAY_CLOCK_CYCLES) begin
                cr_init_valid  <= 1'b1;
                request_config <= 1'b0;
                count_delay <= 'b0;
            end else begin
                count_delay <= count_delay + 1;
            end
        end else if (cr_init_valid && cr_init_ready) begin
            cr_init_valid <= 1'b0;
            count_delay <= 'b0;
        end
    end

    logic [23:0] bram_dout;
    logic [7:0]  bram_addr;

    // ROM holding pre-built camera settings to send
    xilinx_single_port_ram_read_first
    #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE("rom.mem")
    ) registers
    (
        .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(24'b0),          // RAM input data, width determined from RAM_WIDTH
        .clka(clk_camera),     // Clock
        .wea(1'b0),            // Write enable
        .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
        .rsta(sys_rst_camera), // Output reset (does not affect memory contents)
        .regcea(1'b1),         // Output register enable
        .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
    );

    logic [23:0] registers_dout;
    logic [7:0]  registers_addr;
    assign registers_dout = bram_dout;
    assign bram_addr = registers_addr;

    logic       con_scl_i, con_scl_o, con_scl_t;
    logic       con_sda_i, con_sda_o, con_sda_t;

    // NOTE these also have pullup specified in the xdc file!
    // access our inouts properly as tri-state pins
    IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
    IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

    // provided module to send data BRAM -> I2C
    camera_registers crw
    (   .clk_in(clk_camera),
        .rst_in(sys_rst_camera),
        .init_valid(cr_init_valid),
        .init_ready(cr_init_ready),
        .scl_i(con_scl_i),
        .scl_o(con_scl_o),
        .scl_t(con_scl_t),
        .sda_i(con_sda_i),
        .sda_o(con_sda_o),
        .sda_t(con_sda_t),
        .bram_dout(registers_dout),
        .bram_addr(registers_addr)
    );
    // a handful of debug signals for writing to registers

    assign rgb0[0] = crw.bus_active;
    assign rgb0[2] = ~clk_camera_locked;
    assign rgb0[1] = 0;

    assign led[0] = cam_h_sync_buf[0];
    assign led[1] = cam_v_sync_buf[0];
    assign led[2] = cam_pclk_buf[0];
    assign led[3] = cr_init_valid;
    assign led[4] = cr_init_ready;
    assign led[15:5] = 0;
endmodule // top_level


`default_nettype wire

