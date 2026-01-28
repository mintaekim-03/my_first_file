module tb_layer_1 ();

    parameter NODE_1 = 784; // Input Size
    parameter NODE_2 = 128; // Layer 1 Output Size
    parameter NODE_3 = 32;  // Layer 2 Output Size
    parameter NODE_4 = 10;  // Final Output Size
    
    parameter CORE_1   = 8;
    parameter WEIGHT_1 = 8; 

    // Layer 1 Output Width
    parameter INPUT_1 = 8;
    parameter CORE_RESULT_1     = INPUT_1 + WEIGHT_1 + $clog2(CORE_1);
    parameter FC_layer_result_1 = INPUT_1 + WEIGHT_1 + $clog2(NODE_1); 
    
    // Layer 2 Output Width
    parameter INPUT_2 = FC_layer_result_1; 
    parameter CORE_RESULT_2     = INPUT_2 + WEIGHT_1 + $clog2(CORE_1);
    parameter FC_layer_result_2 = INPUT_2 + WEIGHT_1 + $clog2(NODE_2); 

    // Layer 3 Output Width
    parameter INPUT_3 = FC_layer_result_2; 
    parameter CORE_RESULT_3     = INPUT_3 + WEIGHT_1 + $clog2(CORE_1);
    parameter FC_layer_result_3 = INPUT_3 + WEIGHT_1 + $clog2(NODE_3); 

    parameter INPUT_4 = FC_layer_result_3; 

    // Multi-Image Simulation Parameters
    parameter NUM_IMAGES = 10;   
    integer sent_img_cnt = 0;    
    integer check_img_cnt = 0;   

    // Global Signals
    reg  clk, rst;
    reg  go; 

    
    // 2. Wire & Reg Definitions
    
    
    // Layer 1 Signals
    reg  [INPUT_1-1:0]              din_pp;        
    wire [INPUT_1-1:0]              din_ppp;      
    reg                             w_valid_1;                 
    reg                             w_done_1;                  
    wire                            w_done1;                   
    
    wire                            r_request_1;
    wire                            done_read_1;
    wire                            run_1;
    wire                            din_valid_1;
    wire [INPUT_1-1:0]              din_1;        

    wire [WEIGHT_1-1 : 0]           weight_data_1;
    wire                            weight_valid_1;
    wire [FC_layer_result_1-1:0]    one_node_1;
    wire                            one_node_valid_1;
    wire                            w_done_layer_1;

    reg [WEIGHT_1-1:0]              weight_in_1;
    reg                             weight_in_valid_1;

    // Layer 2 Signals
    wire                            w_done2;                
    wire                            r_request_2;
    wire                            done_read_2;
    wire                            run_2;
    wire                            din_valid_2;
    wire [INPUT_2-1:0]              din_2;        

    wire [WEIGHT_1-1:0]             weight_data_2;
    wire                            weight_valid_2;
    wire [FC_layer_result_2-1:0]    one_node_2;
    wire                            one_node_valid_2;
    wire                            w_done_layer_2;

    reg [WEIGHT_1-1:0]              weight_in_2;
    reg                             weight_in_valid_2;

    // Layer 3 Signals
    wire                            w_done3;                 
    wire                            r_request_3;
    wire                            done_read_3;
    wire                            run_3;
    wire                            din_valid_3;
    wire [INPUT_3-1:0]              din_3;        
    
    wire [WEIGHT_1-1:0]             weight_data_3;
    wire                            weight_valid_3;
    wire [FC_layer_result_3-1:0]    one_node_3; 
    wire                            one_node_valid_3; 
    wire                            w_done_layer_3;          

    reg [WEIGHT_1-1:0]              weight_in_3;
    reg                             weight_in_valid_3;
    
    // Testbench Variables
    reg [9:0] d_cnt;
    reg signed [FC_layer_result_3-1 : 0] result_reg [0:NODE_4-1]; 
    integer i;
    integer result_cnt;
    integer error_count; 

    // Basic Assignments
    assign din_ppp = din_pp;
    assign w_done1 = w_done_1;
    assign w_done2 = w_done_layer_1; 
    assign w_done3 = w_done_layer_2;

    wire run_4;
    assign run_4 = 1'b1; // Layer 3 이후 준비 완료

    wire weight_write_done_1;
    wire weight_write_done_2;
    wire weight_write_done_3;
    wire weight_write_all_done;
    assign weight_write_all_done = weight_write_done_1 && weight_write_done_2 && weight_write_done_3;


    
    // 3. Instantiations
    

    // ------------------- Layer 1 -------------------
    pingpong #( .INPUT (INPUT_1), .NODE  (NODE_1) ) pingpong_1 (
        .clk           (clk),
        .rst           (rst),
        .r_request     (r_request_1),
        .done_read     (done_read_1),
        .done_write    (w_done1),
        .din           (din_ppp),
        .pingpong_swap (run_1),
        .w_valid       (w_valid_1),
        .o_valid       (din_valid_1),
        .o_dout        (din_1)
    );

    weight_BRAM #( .CORE (CORE_1), .WEIGHT (WEIGHT_1), .NODE (NODE_1), .N_NODE (NODE_2) ) weight_BRAM_1 (
        .clk               (clk),
        .rst               (rst),
        .w_data            (weight_in_1),
        .w_valid           (weight_in_valid_1),
        .r_request         (r_request_1),
        .weight_data       (weight_data_1),
        .weight_valid      (weight_valid_1),
        .weight_write_done (weight_write_done_1) 
    );

    FC_DUT #( .NODE (NODE_1), .N_NODE (NODE_2), .INPUT (INPUT_1), .WEIGHT (WEIGHT_1), .CORE (CORE_1) ) FC_DUT_1 (
        .clk            (clk),
        .rst            (rst),
        .run            (run_1),
        .run_after      (run_2), 
        .input_data     (din_1), 
        .input_valid    (din_valid_1),
        .weight         (weight_data_1), 
        .weight_valid   (weight_valid_1),
        .r_request      (r_request_1),
        .done_read      (done_read_1),
        .done_write     (w_done_layer_1),
        .one_node       (one_node_1),
        .one_node_valid (one_node_valid_1)
    );

    // ------------------- Layer 2 -------------------
    pingpong #( .INPUT (INPUT_2), .NODE  (NODE_2) ) pingpong_2 (
        .clk           (clk),
        .rst           (rst),
        .r_request     (r_request_2),
        .done_read     (done_read_2),
        .done_write    (w_done2),
        .din           (one_node_1),
        .pingpong_swap (run_2),
        .w_valid       (one_node_valid_1),
        .o_valid       (din_valid_2),
        .o_dout        (din_2)
    );

    weight_BRAM #( .CORE (CORE_1), .WEIGHT (WEIGHT_1), .NODE (NODE_2), .N_NODE (NODE_3) ) weight_BRAM_2 (
        .clk               (clk),
        .rst               (rst),
        .w_data            (weight_in_2),
        .w_valid           (weight_in_valid_2), 
        .r_request         (r_request_2),
        .weight_data       (weight_data_2),
        .weight_valid      (weight_valid_2),
        .weight_write_done (weight_write_done_2) 
    );

    FC_DUT #( .NODE (NODE_2), .N_NODE (NODE_3), .INPUT (INPUT_2), .WEIGHT (WEIGHT_1), .CORE (CORE_1) ) FC_DUT_2 ( 
        .clk            (clk),
        .rst            (rst),
        .run            (run_2),
        .run_after      (run_3),
        .input_data     (din_2), 
        .input_valid    (din_valid_2),
        .weight         (weight_data_2), 
        .weight_valid   (weight_valid_2),
        .r_request      (r_request_2),
        .done_read      (done_read_2),
        .done_write     (w_done_layer_2),
        .one_node       (one_node_2),
        .one_node_valid (one_node_valid_2)
    );

    // ------------------- Layer 3 -------------------
    pingpong #( .INPUT (INPUT_3), .NODE  (NODE_3) ) pingpong_3 (
        .clk           (clk),
        .rst           (rst),
        .r_request     (r_request_3),
        .done_read     (done_read_3),
        .done_write    (w_done3), 
        .din           (one_node_2),
        .pingpong_swap (run_3),
        .w_valid       (one_node_valid_2),
        .o_valid       (din_valid_3),
        .o_dout        (din_3)
    );

    weight_BRAM #( .CORE (CORE_1), .WEIGHT (WEIGHT_1), .NODE (NODE_3), .N_NODE (NODE_4) ) weight_BRAM_3 (
        .clk               (clk),
        .rst               (rst),
        .w_data            (weight_in_3),
        .w_valid           (weight_in_valid_3), 
        .r_request         (r_request_3),
        .weight_data       (weight_data_3),
        .weight_valid      (weight_valid_3),
        .weight_write_done (weight_write_done_3) 
    );

    FC_DUT #( .NODE (NODE_3), .N_NODE (NODE_4), .INPUT (INPUT_3), .WEIGHT (WEIGHT_1), .CORE (CORE_1) ) FC_DUT_3 ( 
        .clk            (clk),
        .rst            (rst),
        .run            (run_3), 
        .run_after      (run_4), 
        .input_data     (din_3), 
        .input_valid    (din_valid_3),
        .weight         (weight_data_3), 
        .weight_valid   (weight_valid_3),
        .r_request      (r_request_3),
        .done_read      (done_read_3),
        .done_write     (w_done_layer_3),
        .one_node       (one_node_3),
        .one_node_valid (one_node_valid_3)
    );


    
    // 4. Testbench Logic & Golden Reference
    

    reg signed [7:0] tb_w_l1 [0:(NODE_1*NODE_2)-1];
    reg signed [7:0] tb_w_l2 [0:(NODE_2*NODE_3)-1];
    reg signed [7:0] tb_w_l3 [0:(NODE_3*NODE_4)-1];

    reg signed [7:0]  tb_inputs [0:NODE_1-1];      
    reg signed [63:0]           l1_results [0:NODE_2-1];     
    reg signed [63:0]           l2_results [0:NODE_3-1];      
    reg signed [63:0]            golden_results [0:NODE_4-1];   

    integer k, n;        
    reg signed [63:0]  sum_tmp;     
    integer w_idx, w_idx2, w_idx3;

    always #5 clk = ~clk;

    // --- HW Weight Loaders (BRAM으로 전송) ---
    initial begin
        @(posedge rst)
        for (w_idx = 0; w_idx < (NODE_1 * NODE_2); w_idx = w_idx + 1) begin
            @(negedge clk); 
            weight_in_1 <= tb_w_l1[w_idx];  
            weight_in_valid_1 <= 1'b1;
        end
        @(negedge clk);
        weight_in_valid_1 <= 1'b0;
    end 

    initial begin
        @(posedge rst)
        for (w_idx2 = 0; w_idx2 < (NODE_2 * NODE_3); w_idx2 = w_idx2 + 1) begin
            @(negedge clk);
            weight_in_2 <= tb_w_l2[w_idx2];
            weight_in_valid_2 <= 1'b1;
        end
        @(negedge clk);
        weight_in_valid_2 <= 1'b0;
    end

    initial begin
        @(posedge rst) 
        for (w_idx3 = 0; w_idx3 < (NODE_3 * NODE_4); w_idx3 = w_idx3 + 1) begin
            @(negedge clk);
            weight_in_3 <= tb_w_l3[w_idx3];
            weight_in_valid_3 <= 1'b1;
        end
        @(negedge clk);
        weight_in_valid_3 <= 1'b0;
    end

    // --- Main Control & Golden Calc ---
    integer idx; // Loop variable for initialization

    initial begin
        clk = 0;
        rst = 0;
        go  = 0;
        
        weight_in_valid_1 = 0;
        weight_in_valid_2 = 0;
        weight_in_valid_3 = 0;
        error_count = 0;

        
        for (idx = 0; idx < NODE_1 * NODE_2; idx = idx + 1) tb_w_l1[idx] = 8'sd1 + idx;
        for (idx = 0; idx < NODE_2 * NODE_3; idx = idx + 1) tb_w_l2[idx] = 8'sd1 + idx;
        for (idx = 0; idx < NODE_3 * NODE_4; idx = idx + 1) tb_w_l3[idx] = 8'sd1 + idx;

        //  모든 입력 데이터도 1로 초기화
        for (k = 0; k < NODE_1; k = k + 1) begin 
            tb_inputs[k] = 8'sd1; 
        end

        #20;
        rst = 1;
        #20;
        
        $display("Writing weights (all 1s) into BRAM...");
        wait(weight_write_all_done); 
        $display("Weight writing done.");
        
        go = 1;

        // --- Golden Reference Calculation ---
        // 모든 가중치와 입력이 1이므로, 합은 노드 개수와 같아야 함을 검증
        
        // Layer 1
        for (n = 0; n < NODE_2; n = n + 1) begin 
            sum_tmp = 0;
            for (k = 0; k < NODE_1; k = k + 1) begin 
                sum_tmp = sum_tmp + (tb_w_l1[n * NODE_1 + k] * tb_inputs[k]);
            end
            if (sum_tmp < 0) l1_results[n] = 0; 
            else             l1_results[n] = sum_tmp;
        end
 
        // Layer 2
        for (n = 0; n < NODE_3; n = n + 1) begin 
            sum_tmp = 0;
            for (k = 0; k < NODE_2; k = k + 1) begin
                sum_tmp = sum_tmp + (tb_w_l2[n * NODE_2 + k] * l1_results[k]);
            end
            if (sum_tmp < 0) l2_results[n] = 0; 
            else             l2_results[n] = sum_tmp;
        end

        // Layer 3 (Final)
        for (n = 0; n < NODE_4; n = n + 1) begin
            sum_tmp = 0;
            for (k = 0; k < NODE_3; k = k + 1) begin 
                sum_tmp = sum_tmp + (tb_w_l3[n * NODE_3 + k] * l2_results[k]);
            end
            
            if (sum_tmp < 0) golden_results[n] = 0; 
            else             golden_results[n] = sum_tmp;
            
            $display("Golden[%0d] = %d", n, golden_results[n]);
        end
        $display("Golden result calculation complete.\n");
    end
    

    
    // 5. Input Feeder (10 Images)
    
    localparam S_WRITE     = 1'b0;
    localparam S_WAIT_SWAP = 1'b1;

    reg current_state; 

    always @(posedge clk or negedge rst) begin
        if(!rst) begin 
            din_pp        <= 0;
            w_valid_1     <= 0;
            d_cnt         <= 0;
            w_done_1      <= 0;
            sent_img_cnt  <= 0;
            current_state <= S_WRITE; 
        end 
        else if (go) begin 
            if (sent_img_cnt < NUM_IMAGES) begin 
                case (current_state)
                    S_WRITE: begin
                        if(d_cnt < NODE_1) begin 
                            din_pp    <= 1;     
                            w_valid_1 <= 1;
                            d_cnt     <= d_cnt + 1; 
                            if(d_cnt == NODE_1 - 1) begin 
                                w_done_1      <= 1;         
                                current_state <= S_WAIT_SWAP;
                            end
                        end 
                    end
                  
                    S_WAIT_SWAP: begin
                        w_valid_1 <= 0;  
                        din_pp    <= 0;
                        if (run_1 == 1'b1) begin 
                           w_done_1      <= 0;
                           d_cnt         <= 0;                 
                           sent_img_cnt  <= sent_img_cnt + 1;  
                           current_state <= S_WRITE;           
                        end
                    end
                endcase
            end
            else begin
                w_valid_1 <= 0;
                w_done_1  <= 0;
                din_pp    <= 0;
            end
        end
    end

    
    // 6. Verification Monitor
    
    always @(posedge clk or negedge rst) begin 
        if (!rst) begin
            for(i = 0; i < NODE_4; i = i+1) begin
                result_reg[i] = 0;
            end
            result_cnt = 0;
            check_img_cnt = 0;
            error_count = 0;
        end else begin
            if(one_node_valid_3) begin 
                result_reg[result_cnt] <= one_node_3;
                
                // Real-time Comparison
                if (one_node_3 == golden_results[result_cnt]) begin
                    $display("[Img %0d] Node %2d: HW = %6d / Golden = %6d [MATCH]", 
                             check_img_cnt, result_cnt, one_node_3, golden_results[result_cnt]);
                end else begin
                    $display("[Img %0d] Node %2d: HW = %6d / Golden = %6d [MISMATCH] !!!", 
                             check_img_cnt, result_cnt, one_node_3, golden_results[result_cnt]);
                    error_count = error_count + 1;
                end

                result_cnt = result_cnt + 1;

                // Check completion for one image
                if (result_cnt == NODE_4) begin 
                    $display("-------------------------------------------");
                    result_cnt    = 0;                
                    check_img_cnt = check_img_cnt + 1;

                    // Check all images
                    if (check_img_cnt == NUM_IMAGES) begin
                        #100;
                        if (error_count == 0) $display("\n(Success) All %0d images Verified!", NUM_IMAGES);
                        else $display("\n(Fail) Total Error Count: %d", error_count);
                        $finish;
                    end
                end
            end
        end
    end
endmodule



module FC_DUT #(
    parameter NODE   = 784,    
    parameter N_NODE = 128,    
    parameter INPUT  = 8,
    parameter WEIGHT = 8,
    parameter CORE   = 8,
    parameter CORE_RESULT  = INPUT + WEIGHT + $clog2(CORE),      // 19bit
    parameter ACC_RESULT   = INPUT + WEIGHT + $clog2(NODE)       // 26bit
) (
    input  clk,
    input  rst,
    input  run,
    input  run_after,
    input  [INPUT-1:0] input_data,
    input  input_valid,
    input  [WEIGHT-1:0] weight,
    input  weight_valid,
    output  r_request,
    output done_read,
    output done_write,
    output [ACC_RESULT-1:0] one_node,
    output                  one_node_valid  
);

    wire w_done;
    wire [ACC_RESULT-1:0] one_node_result;
    wire                  one_node_result_valid;

    reg  done_write;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            done_write <= 0;
        end else begin
            done_write <= w_done;
        end
    end

    //FC layer 
    FC_layer #(
        .NODE(NODE),    
        .N_NODE(N_NODE),     
        .INPUT(INPUT),
        .WEIGHT(WEIGHT),
        .CORE(CORE)
    ) u_FC_layer (
        .clk(clk),
        .rst(rst),
        .run(run), 
        .run_after(run_after),
        .input_data(input_data), 
        .input_valid(input_valid),
        .weight_data(weight),
        .weight_valid(weight_valid),
        .r_request(r_request),
        .done_read(done_read),
        .done_write(w_done),
        .one_node_result(one_node_result),
        .one_node_result_valid(one_node_result_valid)
    );

    ReLU #(
        .NODE(NODE),
        .INPUT(INPUT),
        .WEIGHT(WEIGHT)
    ) u_relu (
        .clk(clk),
        .rst(rst),
        .w_valid(one_node_result_valid),
        .din(one_node_result),
        .dout(one_node),
        .dout_valid(one_node_valid)
    );
endmodule




module FC_layer #(
    parameter NODE   = 784,    
    parameter N_NODE = 128,    
    parameter INPUT  = 8,
    parameter WEIGHT = 8,
    parameter CORE   = 8,
    parameter CORE_RESULT  = INPUT + WEIGHT + $clog2(CORE),      // 19bit
    parameter ACC_RESULT   = INPUT + WEIGHT + $clog2(NODE)       // 26bit
) (
    input                            clk,
    input                            rst,
    input                            run, 
    input                            run_after,             
    input signed [INPUT-1:0]         input_data,    
    input                            input_valid,   
    input signed [WEIGHT-1:0]        weight_data,   
    input                            weight_valid,  
    output                             r_request, 
    output                             done_read,             
    output                             done_write,         
    output reg signed [ACC_RESULT-1:0] one_node_result,       
    output reg                         one_node_result_valid  
);  

    localparam IDLE         = 3'b000;
    localparam DATA_FLOW    = 3'b001; 
    localparam CALC_IN_CORE = 3'b010; 
    localparam ACC_DATA     = 3'b011; 
    localparam DONE_ONE     = 3'b100; 
    localparam MEM_WR       = 3'b101; 
    localparam FC_DONE      = 3'b110; 

    reg [2:0] c_state, n_state;

    localparam CNT_BIT_CORE  = $clog2(CORE + 1);
    localparam CNT_BIT_ACC   = $clog2((NODE/CORE) + 1);
    localparam CNT_BIT_WRITE = $clog2(N_NODE + 1);



    reg [CNT_BIT_CORE-1:0]  data_cnt;       
    reg [CNT_BIT_ACC-1:0]  acc_cnt;        
    reg [CNT_BIT_WRITE-1:0]  write_cnt;  

    reg signed [ACC_RESULT-1:0] one_node;          

    wire signed [CORE_RESULT-1:0] o_core_data;
    wire                          o_core_valid;

    reg signed [INPUT-1:0]  input_data_reg;
    reg                     input_valid_reg;
    reg signed [WEIGHT-1:0] weight_data_reg;
    reg                     weight_valid_reg;

    reg run_forward;
    reg run_back;

    //run신호 두개 주면 연산 시작하도록
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            run_forward <= 0;
        end else if (run) begin
            run_forward <= 1;
        end else if(c_state == DATA_FLOW) begin
            run_forward <= 0;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            run_back <= 0;
        end else if (run_after) begin
            run_back <= 1;
        end else if(c_state == DATA_FLOW) begin
            run_back <= 0;
        end
    end


    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            input_data_reg  <= 0;
            input_valid_reg <= 0;
        end else begin
            input_data_reg  <= input_data;
            input_valid_reg <= input_valid;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            weight_data_reg  <= 0;
            weight_valid_reg <= 0;
        end else begin
            weight_data_reg  <= weight_data;
            weight_valid_reg <= weight_valid;
        end
    end

    wire   data_valid_comb; //가중치 valid와 input valid 
    assign data_valid_comb = input_valid_reg & weight_valid_reg; //가중치와 input 동시에 들어오기

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end
    reg [1:0] first_swap;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            first_swap <= 0;
        end else if(first_swap == 2) begin
            first_swap <= first_swap;
        end else if(run) begin
            first_swap <= first_swap+1;
        end else if(c_state == DATA_FLOW) begin
            first_swap <= first_swap+1;
        end
    end

    always @(*) begin
        n_state = c_state; 
        case (c_state)
            IDLE: begin
                if (first_swap == 1'b1 ||run_forward&&run_back) n_state = DATA_FLOW;
            end
            DATA_FLOW: begin
                if (data_cnt == CORE) n_state = CALC_IN_CORE; //코어만큼 들어왔을시 data가 다 들어왔다고 간주
            end 
            CALC_IN_CORE: begin
                if (o_core_valid) n_state = ACC_DATA; //core에서 연산이 끝나면 valid 신호를 보내서 state 넘어감
            end
            ACC_DATA: begin 
                if (acc_cnt == (NODE/CORE)) n_state = DONE_ONE;
                else                        n_state = DATA_FLOW;  
            end 
            DONE_ONE: begin
                n_state = MEM_WR; 
            end
            MEM_WR : begin 
                if (write_cnt == N_NODE-1) n_state = FC_DONE; 
                else                     n_state = DATA_FLOW;
            end
            FC_DONE : begin 
                n_state = IDLE;
            end
        endcase
    end

    //data flow state action

    reg [3:0] req_cnt;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            req_cnt <= 0;
        end else if (c_state == DATA_FLOW && req_cnt < CORE) begin
            req_cnt <= req_cnt + 1;
        end else if (c_state != DATA_FLOW) begin
            req_cnt <= 0;
        end
    end

    assign r_request = (c_state == DATA_FLOW) && (req_cnt < CORE);

    wire i_data_valid_comb = input_valid && weight_valid;
 
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            data_cnt <= 0;
        end else if (i_data_valid_comb && (data_cnt < CORE)) begin
            data_cnt <= data_cnt + 1;  
        end else if (c_state != DATA_FLOW) begin 
            data_cnt <= 0;
        end
    end
   
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            one_node <= 0; //one_node가 나올 때 까지 더할 register
            acc_cnt <= 0;  //누산을 얼마나 했는 지 카운팅
        end else begin
            if ((c_state == CALC_IN_CORE) && o_core_valid) begin //n_state가 ACC_DATA일 때
                one_node <= one_node + o_core_data;  //one_node + o_core_data
                acc_cnt <= acc_cnt + 1;
            end 
            else if (c_state == DONE_ONE) begin
                one_node <= 0;      
                acc_cnt <= 0;   
            end
        end
    end

    reg [ACC_RESULT-1:0] one_node_reg;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            one_node_reg <= 0;
        end else if (c_state == ACC_DATA && acc_cnt == (NODE/CORE)) begin
            one_node_reg <= one_node; 
        end else if(c_state == MEM_WR) begin
            one_node_reg <= 0;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            one_node_result <= 0;
            one_node_result_valid <= 0;
        end else if(c_state == MEM_WR) begin
            one_node_result <= one_node_reg;
            one_node_result_valid <= 1'b1; 
        end else begin
            one_node_result_valid <= 0;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            write_cnt <= 0;
        end else if (c_state == MEM_WR) begin
            write_cnt <= write_cnt + 1;
        end else if(c_state == FC_DONE) begin 
            write_cnt <= 0;
        end
    end

    assign done_read     = (n_state == FC_DONE || n_state == IDLE&&!run_forward && !run); 
    assign done_write    = (c_state == FC_DONE); 
 
    core #(
        .NODE(NODE), .INPUT(INPUT), .WEIGHT(WEIGHT), .CORE(CORE)
    ) u0 (
        .clk(clk),
        .rst(rst),
        .i_input(input_data_reg),   
        .i_weight(weight_data_reg),  
        .i_data_valid(data_valid_comb),
        .o_core_data(o_core_data),
        .o_core_valid(o_core_valid)
    );

endmodule

module core #(
    parameter NODE   = 784,
    parameter INPUT  = 8,
    parameter WEIGHT = 8,
    parameter CORE   = 8,
    parameter OUT    = INPUT + WEIGHT + $clog2(CORE) 
)(
    input                        clk,
    input                        rst,
    input  signed [INPUT-1:0]    i_input,
    input  signed [WEIGHT-1:0]   i_weight,     
    input                        i_data_valid, 
    output reg signed [OUT-1:0]  o_core_data,  
    output reg                   o_core_valid  
);
    //inside signal
    localparam MULT_WIDTH  = INPUT + WEIGHT;            
    localparam SUM_WIDTH   = MULT_WIDTH + $clog2(CORE); 
    //state
    localparam IDLE        = 3'b000;
    localparam MULT_WAIT   = 3'b001;
    localparam MULT_RUN    = 3'b010;
    localparam DONE        = 3'b011;

    wire             data_all_ready;      
    wire [CORE-1:0]  mult_valid_vec;      
    wire             all_valid;           
    wire signed [MULT_WIDTH-1:0] mult_out [0:CORE-1]; 

    reg  [2:0]  c_state, n_state;
    reg  [3:0]  data_counter; 

    reg  signed [INPUT-1:0]  reg_input   [0:CORE-1]; 
    reg  signed [WEIGHT-1:0] reg_weight  [0:CORE-1];

    assign data_all_ready = (data_counter == CORE-1); 
    assign all_valid      = &mult_valid_vec; 

    //add_tree 구조는 일단 1clk 안에 끝나야한다는 단점이 있는데 만약 core수가 많아진다면 pipeline add tree 구조로 설계를 하면 된다.
    //입력도 동기화이고 출력도 동기화로 연결되는 경우에 조합회로 계산도 안전하게 할 수 있다.
    //1번째 덧셈
    wire signed [SUM_WIDTH-1:0] sum_step1 [0:3]; 
    assign sum_step1[0] = mult_out[0] + mult_out[1];
    assign sum_step1[1] = mult_out[2] + mult_out[3];
    assign sum_step1[2] = mult_out[4] + mult_out[5];
    assign sum_step1[3] = mult_out[6] + mult_out[7];
    //2번째 덧셈
    wire signed [SUM_WIDTH-1:0] sum_step2 [0:1];
    assign sum_step2[0] = sum_step1[0] + sum_step1[1];
    assign sum_step2[1] = sum_step1[2] + sum_step1[3];
    //최종 덧셈 + 결과
    wire signed [SUM_WIDTH-1:0] sum_result;
    assign sum_result = sum_step2[0] + sum_step2[1];


    always @(posedge clk or negedge rst) begin
        if (!rst) c_state <= IDLE;
        else      c_state <= n_state;
    end

    always @(*) begin
        n_state = c_state;
        case(c_state)
            IDLE: begin
                if (i_data_valid) n_state = MULT_WAIT; 
            end
            MULT_WAIT: begin   
                if(data_all_ready) n_state = MULT_RUN;
            end
            MULT_RUN: begin    
                if (all_valid) n_state = DONE; 
            end
            DONE: begin        
                n_state = IDLE;
            end
            default: n_state = IDLE;
        endcase 
    end


    always @(posedge clk or negedge rst) begin
        if (!rst) data_counter <= 0;
        else begin
            if (c_state == DONE)
                data_counter <= 0;
            else if (i_data_valid && (c_state == MULT_WAIT|| c_state == IDLE) && data_counter < CORE) 
                data_counter <= data_counter + 1;
        end
    end

    genvar j;
    generate
        for (j = 0; j < CORE; j = j + 1) begin : input_reg
            always @(posedge clk or negedge rst) begin
                if (!rst) begin
                    reg_input[j]  <= 0;
                    reg_weight[j] <= 0;
                end else if (i_data_valid && (data_counter == j)) begin
                    reg_input[j]  <= i_input;
                    reg_weight[j] <= i_weight;
                end
            end
        end
    endgenerate

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            o_core_data  <= 0;
            o_core_valid <= 0;
        end else begin
            if (c_state == DONE) begin
                o_core_data  <= sum_result; // Adder Tree의 최종 결과
                o_core_valid <= 1'b1;     
            end else begin
                o_core_valid <= 1'b0;     
            end
        end
    end

    genvar i;
    generate
        for(i = 0; i < CORE; i = i + 1) begin: mult
            multiplier #(
            .INPUT(INPUT),
            .WEIGHT(WEIGHT)
            ) u_multiplier (  
                .clk(clk),
                .rst(rst),
                .i_input(reg_input[i]),   
                .i_weight(reg_weight[i]), 
                .mult_ready(c_state == MULT_RUN), 
                .mult_out(mult_out[i]),       
                .mult_valid(mult_valid_vec[i]) 
            );
        end
    endgenerate
endmodule

module multiplier #(
    parameter INPUT = 8,
    parameter WEIGHT = 8,
    parameter OUT = INPUT+WEIGHT
)
(
    input                       clk,
    input                       rst,
    input signed  [INPUT-1:0]   i_input, //1층 input은 signed로 한다.
    input signed  [WEIGHT-1:0]  i_weight, //가중치는 signed
    input                       mult_ready,            
    output signed [OUT-1:0]     mult_out,
    output                      mult_valid
);
    reg signed [OUT-1:0] mult_out_d;
    reg                  mult_out_valid; //output이랑 같이 나가기

    //step 1 곱셈 진행하기기
    always@(posedge clk or negedge rst)begin
        if(!rst)begin
            mult_out_d <= 0;
        end else if(mult_ready)begin        //mult_ready 신호가 들어오면 연산을 시작한다.
            mult_out_d <= i_input*i_weight; //일단 두개 곱한거 연결 
        end
    end

    reg valid_shift_reg; 

    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            valid_shift_reg <= 2'b00; 
        end else begin
            valid_shift_reg <= mult_ready;
        end
    end

    assign mult_valid = valid_shift_reg; //2클락
    assign mult_out = mult_out_d; //1clk 지연한다.  //1clk 뒤에 값이 나온다.

endmodule

module ReLU #(
    parameter NODE   = 784,
    parameter INPUT  = 8,
    parameter WEIGHT = 8,
    parameter DWIDTH = INPUT + WEIGHT + $clog2(NODE)
) (
    input  wire clk,
    input  wire rst,
    input  wire w_valid,
    input  wire signed [DWIDTH-1:0] din,
    output reg  signed [DWIDTH-1:0] dout, 
    output reg                     dout_valid
);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            dout       <= 0;
            dout_valid <= 0;
        end else begin
            dout_valid <= w_valid; 
            dout <= (w_valid && din[DWIDTH-1] == 1'b0) ? din : {DWIDTH{1'b0}};
        end
    end

endmodule


module pingpong #(
    parameter INPUT = 8,
    parameter NODE = 784,
    parameter AWIDTH = $clog2(NODE), 
    parameter DEPTH = NODE      
)(
    input                  rst,
    input                  clk,
    input                  r_request,       
    input     [INPUT-1:0]  din,
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
    
    // --- [수정 핵심 1] 완료 신호 기억을 위한 레지스터 추가 ---
    reg flag_write_done;
    reg flag_read_done;

    // Write Done 신호 기억 (Latch)
    always @(posedge clk or negedge rst) begin
        if (!rst) 
            flag_write_done <= 0;
        else if (c_state == SWAP) // Swap이 일어나면 플래그 초기화
            flag_write_done <= 0;
        else if (done_write)      // 펄스가 들어오면 1로 저장
            flag_write_done <= 1;
    end

    // Read Done 신호 기억 (Latch)
    // done_read는 보통 Level 신호(IDLE상태)지만, 타이밍 엇갈림 방지를 위해 저장 로직 사용 권장
    always @(posedge clk or negedge rst) begin
        if (!rst) 
            flag_read_done <= 0;
        else if (c_state == SWAP) 
            flag_read_done <= 0;
        else if (done_read) 
            flag_read_done <= 1;
    end
    // -----------------------------------------------------

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
    // 여기 조건도 flag를 사용하는 것이 안전하지만, FSM이 SWAP state를 거치므로
    // c_state == SWAP을 감지하여 토글하는 것이 가장 깔끔함.
    always@(posedge clk or negedge rst) begin 
        if(!rst)begin
            BRAM_choice <= 1;
        end else if(c_state == SWAP) begin // [수정] SWAP 상태일 때 토글
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
        end else if(r_addr == DEPTH-1 && r_request) begin // [보완] r_request 조건 추가 (Wrapping 타이밍 명확화)
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

module SPRAM #(
    parameter NODE = 784, //이거는 인스턴스 하면서 바꾸는 것
    parameter DWIDTH = 8,
    parameter AWIDTH = $clog2(NODE) //
)
(
    input clk,
    input [AWIDTH-1:0] addr, 
    input we,
    input en,
    input [DWIDTH-1:0] din,
    output reg [DWIDTH-1:0]dout
);

(* ram_style = "block" *) reg [DWIDTH-1:0] mem[0:NODE-1]; // Mem size 결정 64 12544 width Depth

always @(posedge clk)  begin //클락이 뛸 때 마다 주소에 값이 저장.
    if(en) begin
        if(we)begin
            mem[addr] <= din; 
        end
        else begin //we가 아니라면 mem[addr]을 dout에 보내기
            dout <= mem[addr]; 
        end
    end    
end
endmodule


module weight_BRAM #( 
    parameter CORE = 8,
    parameter WEIGHT = 8,
    parameter NODE = 784,
    parameter N_NODE = 128,
    parameter DWIDTH = WEIGHT, 
    parameter AWIDTH = $clog2(NODE*N_NODE) 
) (
    input clk,
    input rst,
    input [WEIGHT-1:0] w_data,
    input w_valid,     
    input r_request,   
    output [WEIGHT-1:0] weight_data,
    output weight_valid,
    output reg weight_write_done
);

    localparam DELAY = 2;

    wire [WEIGHT-1:0] weight_data_wire;
    wire [AWIDTH-1:0] addr; 
    reg  [AWIDTH-1:0] w_counter; 
    reg  [AWIDTH-1:0] r_counter; 
    reg  [DELAY-1:0]  r_valid_delay; 
    reg  [WEIGHT-1:0] weight_data_delay;
  
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            w_counter <= 0;
            weight_write_done <= 0;
        end else if (w_valid) begin
            if (w_counter == NODE*N_NODE - 1) begin
                w_counter <= 0;
                weight_write_done <= 1;
            end else
                w_counter <= w_counter + 1;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            r_counter <= 0;
        end else if (r_request && !w_valid) begin 
            if (r_counter == NODE*N_NODE - 1)
                r_counter <= 0;
            else
                r_counter <= r_counter + 1;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            r_valid_delay <= 0;
            weight_data_delay <= 0;
        end else begin
            if (w_valid) 
                r_valid_delay <= 0;
            else 
                r_valid_delay <= {r_valid_delay[0], r_request};

            weight_data_delay <= weight_data_wire;
        end
    end

    assign weight_valid = r_valid_delay[1]; 
    assign weight_data  = weight_data_delay; 
    assign addr = (w_valid) ? w_counter : r_counter;

    SPRAM_WBRAM #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH),
        .NODE(NODE),
        .N_NODE(N_NODE)
    ) u_bram (
        .clk(clk),
        .addr(addr), 
        .we(w_valid),      
        .en(w_valid || r_request), 
        .din(w_data),
        .dout(weight_data_wire)
    );
endmodule

module SPRAM_WBRAM #(
    parameter CORE = 8,
    parameter NODE = 784,
    parameter N_NODE = 128, 
    parameter WEIGHT = 8,
    parameter DWIDTH = WEIGHT, 
    parameter AWIDTH = $clog2(NODE*N_NODE)
)
(
    input clk,
    input [AWIDTH-1:0] addr,
    input we,
    input en,
    input [DWIDTH-1:0] din,
    output reg [DWIDTH-1:0] dout
);

    (* ram_style = "block" *) reg [DWIDTH-1:0] mem [0:NODE*N_NODE-1]; 

    always @(posedge clk) begin
        if(en) begin
            if(we) begin
                mem[addr] <= din; 
            end
            else begin
                dout <= mem[addr]; 
            end
        end    
    end
endmodule
