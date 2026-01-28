
module pingpong #(
    parameter INPUT = 8,
    parameter NODE = 784,
    parameter AWIDTH = $clog2(NODE), 
    parameter DEPTH = NODE      
)(
    input                  rst,
    input                  clk,
    input                  r_request,       
    input      [INPUT-1:0] din,
    input                  done_read,       
    input                  done_write,      
    input                  w_valid,         
    output                 pingpong_swap,   
    output                 o_valid,           
    output    [INPUT-1:0]  o_dout
);

    wire [INPUT-1:0]   u1_dout;
    wire [INPUT-1:0]   u2_dout;
    wire [INPUT-1:0]   dout;
    wire [AWIDTH-1:0]  u1_addr;
    wire [AWIDTH-1:0]  u2_addr;
    wire               en1;
    wire               en2;
    reg                c_state;
    reg                n_state;
    reg  [AWIDTH-1:0]  w_addr;
    reg  [AWIDTH-1:0]  r_addr;
    reg                BRAM_choice;
    reg                reading_delay1; 
    reg                reg_valid; 
    reg [INPUT-1:0]    dout_out;
              
    localparam RUN    = 0;
    localparam SWAP   = 1;
    
    reg flag_write_done;
    reg flag_read_done;

    // Write Done Latch
    always @(posedge clk or negedge rst) begin
        if (!rst) 
            flag_write_done <= 0;
        else if (c_state == SWAP) 
            flag_write_done <= 0;
        else if (done_write)      
            flag_write_done <= 1;
    end

    // Read Done Latch
    always @(posedge clk or negedge rst) begin
        if (!rst) 
            flag_read_done <= 0;
        else if (c_state == SWAP) 
            flag_read_done <= 0;
        else if (done_read) 
            flag_read_done <= 1;
    end

    assign dout    =  (BRAM_choice)  ? u2_dout : u1_dout; 
    assign u1_addr =  (BRAM_choice)  ? w_addr : r_addr;   
    assign u2_addr =  (!BRAM_choice) ? w_addr : r_addr;
    assign en1     =  (c_state == RUN)&& ((BRAM_choice) &&w_valid  || (!BRAM_choice)&&r_request);  
    assign en2     =  (c_state == RUN)&& ((!BRAM_choice)&&w_valid  || (BRAM_choice) &&r_request);
    assign o_valid = reg_valid;
    assign o_dout  = dout_out;

    always@(posedge clk or negedge rst)begin
        if(!rst)begin
            c_state <= RUN;
        end
        else begin
            c_state <= n_state;
        end
    end

    always@(*)begin 
        n_state = RUN;
        case(c_state)
        RUN:begin
            if(flag_read_done && flag_write_done) begin   
                n_state = SWAP; 
            end else begin
                n_state = RUN;
            end
        end
        SWAP:begin
            n_state = RUN;      
        end
        endcase
    end

    // step 1 BRAM_choice logic
    always@(posedge clk or negedge rst) begin 
        if(!rst)begin
            BRAM_choice <= 1;
        end else if(c_state == SWAP) begin 
            BRAM_choice <= ~BRAM_choice;
        end
    end

    // step 2 w_addr
    always@(posedge clk or negedge rst)begin
        if(!rst)begin
            w_addr <= 0;
        end else if(c_state == SWAP) begin        
            w_addr <= 0;
        end else if((c_state == RUN)&&w_valid)begin  
            w_addr <= w_addr+1;
        end
    end
    
    // step 3 r_addr
    always@(posedge clk or negedge rst) begin
        if(!rst)begin
            r_addr <= 0;
        end else if (c_state == SWAP) begin
            r_addr <= 0;
        end else if(r_addr == DEPTH-1 && r_request) begin 
            r_addr <= 0;
        end else if((c_state == RUN)&&r_request)begin  
            r_addr <= r_addr+1;
        end
    end

    // step 4 dout_out
    always@(posedge clk or negedge rst)begin
        if(!rst) begin
            dout_out <= 0;
        end else begin
            dout_out <= dout; 
        end
    end

    // step 5 o_valid
    always@(posedge clk or negedge rst)begin
        if(!rst) begin
            reading_delay1 <= 0;
            reg_valid      <= 0;
        end else begin
            reading_delay1 <= r_request;
            reg_valid      <= reading_delay1;
        end
    end

    assign pingpong_swap = (c_state == SWAP) ? 1'b1:1'b0;


    SPRAM #(
        .NODE(NODE),
        .DWIDTH(INPUT),
        .AWIDTH(AWIDTH)
    ) u1 (
        .clk(clk),
        .addr(u1_addr),
        .en(en1), 
        .we(BRAM_choice), 
        .din(din),
        .dout(u1_dout)
    );

    SPRAM #(
        .NODE(NODE),
        .DWIDTH(INPUT),
        .AWIDTH(AWIDTH)
    ) u2 (
        .clk(clk),
        .addr(u2_addr),
        .en(en2), 
        .we(!BRAM_choice), 
        .din(din),
        .dout(u2_dout)
    );
    
endmodule
