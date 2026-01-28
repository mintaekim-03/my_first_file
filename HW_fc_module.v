module axi4_lite_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5 
)
(
    // AXI4-Lite Interface Ports
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input wire  S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input wire  S_AXI_RREADY
);

    // 내부 신호 선언
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg  axi_awready;
    reg  axi_wready;
    reg [1 : 0] axi_bresp;
    reg  axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg  axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
    reg [1 : 0] axi_rresp;
    reg  axi_rvalid;
    
    // User Registers
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0; // Input Data Storage (0x00)
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1; // Weight Data Storage (0x04)

    wire slv_reg_rden;
    wire slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
    reg aw_en;

    // AXI Output Assignments
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // AXI Handshake Logic (Standard)
    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        axi_awready <= 1'b0;
        aw_en <= 1'b1;
      end else begin
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
          axi_awready <= 1'b1;
          aw_en <= 1'b0;
        end else if (S_AXI_BREADY && axi_bvalid) begin
          aw_en <= 1'b1;
          axi_awready <= 1'b0;
        end else begin
          axi_awready <= 1'b0;
        end
      end
    end      

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) axi_awaddr <= 0;
      else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) axi_awaddr <= S_AXI_AWADDR;
    end      

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) axi_wready <= 1'b0;
      else if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en ) axi_wready <= 1'b1;
      else axi_wready <= 1'b0;
    end      

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        axi_bvalid  <= 0;
        axi_bresp   <= 2'b0;
      end else begin
        if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b0; 
        end else if (S_AXI_BREADY && axi_bvalid) begin
          axi_bvalid <= 1'b0; 
        end
      end
    end   

    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    reg r_input_write_pulse;
    reg r_weight_write_pulse;
    reg r_input_write_done;
    reg r_result_read_done;
    reg r_r_request_pulse;

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        slv_reg0 <= 0;
        slv_reg1 <= 0;
        r_input_write_pulse  <= 0;
        r_weight_write_pulse <= 0;
        r_input_write_done   <= 0;
        r_result_read_done   <= 0;
        r_r_request_pulse     <= 0;
      end else begin
        r_input_write_pulse  <= 0;
        r_weight_write_pulse <= 0;
        r_input_write_done   <= 0;
        r_result_read_done   <= 0;
        r_r_request_pulse     <= 0;
        if (slv_reg_wren) begin
          case ( axi_awaddr[4:2] )
            3'h0: begin // Input Data 
                slv_reg0 <= S_AXI_WDATA;
                r_input_write_pulse <= 1'b1; 
            end
            3'h1: begin // Weight Data 
                slv_reg1 <= S_AXI_WDATA;
                r_weight_write_pulse <= 1'b1; 
            end
            3'h3: begin // Control
                if (S_AXI_WDATA[0]) r_input_write_done   <= 1'b1;
                if (S_AXI_WDATA[1]) r_result_read_done   <= 1'b1;
                if (S_AXI_WDATA[2]) r_r_request_pulse     <= 1'b1;
            end
            default : ;
          endcase
        end
      end
    end    

    assign w_input_write_pulse  = r_input_write_pulse;
    assign w_weight_write_pulse = r_weight_write_pulse;
    assign w_input_write_done   = r_input_write_done;
    assign w_result_read_done   = r_result_read_done;
    assign w_r_request_pulse     = r_r_request_pulse;
    
    // AXI Read Logic
    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        axi_arready <= 1'b0;
        axi_araddr  <= 32'b0;
      end else begin    
        if (~axi_arready && S_AXI_ARVALID) begin
          axi_arready <= 1'b1;
          axi_araddr  <= S_AXI_ARADDR;
        end else begin
          axi_arready <= 1'b0;
        end
      end 
    end       

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        axi_rvalid <= 0;
        axi_rresp  <= 0;
      end else begin    
        if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
          axi_rvalid <= 1'b1;
          axi_rresp  <= 2'b0; 
        end else if (axi_rvalid && S_AXI_RREADY) begin
          axi_rvalid <= 1'b0;
        end                
      end
    end    

    wire w_input_swap_pulse;
    wire w_result_swap_pulse;
    
    reg r_input_swap_latched;
    reg r_result_swap_latched;
    
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

    // Input Swap 잡아두기
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            r_input_swap_latched <= 1'b0;
        end else begin
            if (w_input_swap_pulse) begin
                r_input_swap_latched <= 1'b1;
            end
            else if (slv_reg_rden && (axi_araddr[4:2] == 3'h2)) begin
                r_input_swap_latched <= 1'b0;
            end
        end
    end

    // Result Swap 잡아두기 상태 레지스터 읽으면 초기화 
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            r_result_swap_latched <= 1'b0;
        end else begin
            if (w_result_swap_pulse) begin
                r_result_swap_latched <= 1'b1;
            end
            else if (slv_reg_rden && (axi_araddr[4:2] == 3'h2)) begin
                r_result_swap_latched <= 1'b0;
            end
        end
    end

    // Result Capture 로직
    wire [31:0] w_npu_result_lower;
    wire [31:0] w_npu_result_upper;
    wire o_slv_reg_valid;
    wire w_weight_write_all_done;

    reg [31:0] r_lower_catch;
    reg [31:0] r_upper_catch;
    reg        r_valid_status;      

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        r_lower_catch <= 32'b0;
        r_upper_catch <= 32'b0;
        r_valid_status <= 1'b0;
      end else begin
        if (o_slv_reg_valid) begin 
            r_lower_catch <= w_npu_result_lower;
            r_upper_catch <= w_npu_result_upper;
            r_valid_status <= 1'b1; 
        end else if (slv_reg_rden && (axi_araddr[4:2] == 3'h5)) begin 
            r_valid_status <= 1'b0; 
        end
      end
    end

    always @(*) begin
        case ( axi_araddr[4:2] )
            3'h2 : reg_data_out <= {
                                     28'b0, 
                                     r_valid_status,        // Bit 3
                                     r_input_swap_latched,  // Bit 2 
                                     r_result_swap_latched, // Bit 1 
                                     w_weight_write_all_done// Bit 0
                                   };
            3'h4 : reg_data_out <= r_upper_catch; //  0x10 -> Upper
            3'h5 : reg_data_out <= r_lower_catch; //  0x14 -> Lower         
            default : reg_data_out <= 0;
        endcase
    end

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) axi_rdata <= 0;
      else if (slv_reg_rden)       axi_rdata <= reg_data_out;
    end    
    //case문에 조건을 직접 넣으면 reg_data_out은 계속 바뀌는 조합회로이기 때문에 신호를 무조건 적으로 놓친다.
    //따라서 register에 한번 저장을 했다가 넣어야한다. 

    NPU_Top u_npu (
        .clk                     (S_AXI_ACLK),    
        .rst                     (S_AXI_ARESETN), 
        // Input Data
        .i_input_data            (slv_reg0[7:0]), 
        .i_input_valid           (w_input_write_pulse), //적는 순간의 pulse
        // Weight Data
        .i_weigth_data           (slv_reg1[7:0]), 
        .i_weight_valid          (w_weight_write_pulse), //적는 순간의 pulse
        .o_weight_write_all_done (w_weight_write_all_done), 
        // Control Signals
        .w_done_1                (w_input_write_done),    
        .i_done_read_4           (w_result_read_done),    
        .i_r_request_4           (w_r_request_pulse),      
        // swap signals
        .input_swap              (w_input_swap_pulse),                
        .result_swap             (w_result_swap_pulse),               
        // Result Data
        .o_slv_reg_result_lower  (w_npu_result_lower),
        .o_slv_reg_result_upper  (w_npu_result_upper),
        .o_slv_reg_valid         (o_slv_reg_valid)
    );

endmodule

module NPU_Top #(
    parameter NODE_1 = 784,
    parameter NODE_2 = 128,
    parameter NODE_3 = 32,
    parameter NODE_4 = 10,
    parameter CPU_WIDTH = 32,
    parameter CORE_1   = 8,
    parameter WEIGHT_1 = 8,

    // Layer 1 Output Width
    parameter INPUT_1 = 8,
    parameter CORE_RESULT_1     = INPUT_1 + WEIGHT_1 + $clog2(CORE_1),
    parameter FC_layer_result_1 = INPUT_1 + WEIGHT_1 + $clog2(NODE_1), //  26 bit
    
    // Layer 2 Output Width
    parameter INPUT_2 = FC_layer_result_1, 
    parameter CORE_RESULT_2     = INPUT_2 + WEIGHT_1 + $clog2(CORE_1),
    parameter FC_layer_result_2 = INPUT_2 + WEIGHT_1 + $clog2(NODE_2), //  41 bit

    // Layer 3 Output Width
    parameter INPUT_3 = FC_layer_result_2,
    parameter CORE_RESULT_3     = INPUT_3 + WEIGHT_1 + $clog2(CORE_1),
    parameter FC_layer_result_3 = INPUT_3 + WEIGHT_1 + $clog2(NODE_3), //  54 bit

    parameter INPUT_4 = FC_layer_result_3 // Final Output Width
)(
    input wire clk,
    input wire rst,              
            
    input wire [WEIGHT_1-1:0] i_weigth_data,
    input wire                i_weight_valid,
    output wire               o_weight_write_all_done, // 다 썻는지 확인용 이게 떠야지 input data를 넘겨줄 수 있다. 


    input wire [INPUT_1-1:0]  i_input_data,
    input wire                i_input_valid, 
    input wire                w_done_1, 
    
    // CPU가 결과를 읽기 위해 보내는 제어 신호
    input wire                i_r_request_4, 
    input wire                i_done_read_4, 
    
    // CPU로 나가는 결과 데이터
    output wire [CPU_WIDTH-1:0] o_slv_reg_result_upper,
    output wire [CPU_WIDTH-1:0] o_slv_reg_result_lower,
    output wire                 o_slv_reg_valid,

    //npu 탑에서 연결 시켜줘야한다. 각 pingpong의 swap을 AXI로 
    output wire input_swap,
    output wire result_swap
);

    // Internal Wires & Regs
    
    // Demux Signals
    reg [WEIGHT_1-1:0]  weight_in_1, weight_in_2, weight_in_3;
    reg                 weight_in_valid_1, weight_in_valid_2, weight_in_valid_3;
    
    // Status
    wire weight_write_done_1, weight_write_done_2, weight_write_done_3;

    // Inter-Layer Signals
    wire w_done2, w_done3;
    wire r_request_1, r_request_2, r_request_3;
    wire done_read_1, done_read_2, done_read_3;
    wire run_1, run_2, run_3, run_4;
    
    wire din_valid_1, din_valid_2, din_valid_3;
    wire [INPUT_1-1:0] din_1;
    wire [INPUT_2-1:0] din_2;
    wire [INPUT_3-1:0] din_3;

    wire [WEIGHT_1-1:0]         weight_data_1, weight_data_2, weight_data_3;
    wire                        weight_valid_1, weight_valid_2, weight_valid_3;
    
    wire [FC_layer_result_1-1:0] one_node_1;
    wire [FC_layer_result_2-1:0] one_node_2;
    wire [FC_layer_result_3-1:0] one_node_3;
    
    wire one_node_valid_1, one_node_valid_2, one_node_valid_3;
    wire w_done_layer_1, w_done_layer_2, w_done_layer_3;

    // Result
    wire signed [FC_layer_result_3-1:0] slv_reg_result;
    //result 2개로 나누기
    assign o_slv_reg_result_lower = slv_reg_result[CPU_WIDTH-1:0];
    assign o_slv_reg_result_upper = { 
        {(CPU_WIDTH - (INPUT_4 - CPU_WIDTH)){slv_reg_result[INPUT_4-1]}}, // Sign Ext
        slv_reg_result[INPUT_4-1:CPU_WIDTH] 
    };
    //
    assign input_swap = run_1;
    assign result_swap = run_4;

    // Signal Assignments
    assign w_done2 = w_done_layer_1; 
    assign w_done3 = w_done_layer_2; 
    
    //wegight 적기 신호 끝
    assign o_weight_write_all_done = weight_write_done_1 && weight_write_done_2 && weight_write_done_3;

    always @(*) begin
        // Latch 방지 초기화
        weight_in_1 = 0; weight_in_valid_1 = 0;
        weight_in_2 = 0; weight_in_valid_2 = 0;
        weight_in_3 = 0; weight_in_valid_3 = 0;
        if (!weight_write_done_1) begin
            weight_in_1 = i_weigth_data; weight_in_valid_1 = i_weight_valid;
        end else if (!weight_write_done_2) begin
            weight_in_2 = i_weigth_data; weight_in_valid_2 = i_weight_valid;
        end else if (!weight_write_done_3) begin
            weight_in_3 = i_weigth_data; weight_in_valid_3 = i_weight_valid;
        end
    end


   

    // --------------- Layer 1 ---------------
    pingpong #(
        .INPUT(INPUT_1),
        .NODE(NODE_1)
    ) pingpong_1 (
        .clk(clk),
        .rst(rst),
        .r_request(r_request_1),
        .done_read(done_read_1),
        .done_write(w_done_1), // <--- 됨: 안전한 Latched 신호 연결
        .din(i_input_data),       
        .pingpong_swap(run_1),         // 이 신호가 다시 w_done_1_latched를 끄게 됨
        .w_valid(i_input_valid),  
        .o_valid(din_valid_1),
        .o_dout(din_1)
    );
    
    weight_BRAM #(
        .CORE(CORE_1),
        .WEIGHT(WEIGHT_1),
        .NODE(NODE_1),
        .N_NODE(NODE_2)
    ) weight_BRAM_1 (
        .clk(clk),
        .rst(rst),
        .w_data(weight_in_1),
        .w_valid(weight_in_valid_1),
        .r_request(r_request_1),
        .weight_data(weight_data_1),
        .weight_valid(weight_valid_1),
        .weight_write_done(weight_write_done_1)
    );

    FC_DUT #(
        .NODE(NODE_1),
        .N_NODE(NODE_2),
        .INPUT(INPUT_1),
        .WEIGHT(WEIGHT_1),
        .CORE(CORE_1)
    ) FC_DUT_1 (
        .clk(clk),
        .rst(rst),
        .run(run_1), 
        .run_after(run_2),
        .input_data(din_1),
        .input_valid(din_valid_1),
        .weight(weight_data_1),
        .weight_valid(weight_valid_1),
        .r_request(r_request_1),
        .done_read(done_read_1),
        .done_write(w_done_layer_1),
        .one_node(one_node_1),
        .one_node_valid(one_node_valid_1)
    );

    // --------------- Layer 2 ---------------
    pingpong #(
        .INPUT(INPUT_2),
        .NODE(NODE_2)
    ) pingpong_2 (
        .clk(clk),
        .rst(rst),
        .r_request(r_request_2),
        .done_read(done_read_2),
        .done_write(w_done2),
        .din(one_node_1),
        .pingpong_swap(run_2),
        .w_valid(one_node_valid_1),
        .o_valid(din_valid_2),
        .o_dout(din_2)
    );

    weight_BRAM #(
        .CORE(CORE_1),
        .WEIGHT(WEIGHT_1),
        .NODE(NODE_2),
        .N_NODE(NODE_3)
    ) weight_BRAM_2 (
        .clk(clk),
        .rst(rst),
        .w_data(weight_in_2),
        .w_valid(weight_in_valid_2), 
        .r_request(r_request_2),
        .weight_data(weight_data_2),
        .weight_valid(weight_valid_2),
        .weight_write_done(weight_write_done_2) 
    );

    FC_DUT #(
        .NODE(NODE_2),
        .N_NODE(NODE_3),
        .INPUT(INPUT_2),
        .WEIGHT(WEIGHT_1),
        .CORE(CORE_1)
    ) FC_DUT_2 ( 
        .clk(clk),
        .rst(rst),
        .run(run_2),
        .run_after(run_3), //w_done 신호를 언제 주는지 알아야함 FCdone일 때 주네 그럼 정상동작 무조건 함
        .input_data(din_2),
        .input_valid(din_valid_2),
        .weight(weight_data_2),
        .weight_valid(weight_valid_2),
        .r_request(r_request_2),
        .done_read(done_read_2),
        .done_write(w_done_layer_2),
        .one_node(one_node_2),
        .one_node_valid(one_node_valid_2)
    );

    // --------------- Layer 3 ---------------
    pingpong #(
        .INPUT(INPUT_3),
        .NODE(NODE_3)
    ) pingpong_3 (
        .clk(clk),
        .rst(rst),
        .r_request(r_request_3),
        .done_read(done_read_3),
        .done_write(w_done3), 
        .din(one_node_2),
        .pingpong_swap(run_3),
        .w_valid(one_node_valid_2),
        .o_valid(din_valid_3),
        .o_dout(din_3)
    );

    weight_BRAM #(
        .CORE(CORE_1),
        .WEIGHT(WEIGHT_1),
        .NODE(NODE_3),
        .N_NODE(NODE_4)
    ) weight_BRAM_3 (
        .clk(clk),
        .rst(rst),
        .w_data(weight_in_3),
        .w_valid(weight_in_valid_3), 
        .r_request(r_request_3),
        .weight_data(weight_data_3),
        .weight_valid(weight_valid_3),
        .weight_write_done(weight_write_done_3) 
    );

    FC_DUT #(
        .NODE(NODE_3),
        .N_NODE(NODE_4),
        .INPUT(INPUT_3),
        .WEIGHT(WEIGHT_1),
        .CORE(CORE_1)
    ) FC_DUT_3 ( 
        .clk(clk),
        .rst(rst),
        .run(run_3), 
        .run_after(run_4),
        .input_data(din_3),
        .input_valid(din_valid_3),
        .weight(weight_data_3),
        .weight_valid(weight_valid_3),
        .r_request(r_request_3),
        .done_read(done_read_3),
        .done_write(w_done_layer_3),
        .one_node(one_node_3),
        .one_node_valid(one_node_valid_3)
    );

  
    //악시의 지연시간을 고려한 r_done의 제어

    reg latched_r_done;
    reg r_done_prev; //
    wire r_done_posedge; // 
    
    always @(posedge clk or negedge rst) begin
        if (!rst) r_done_prev <= 0;
        else      r_done_prev <= i_done_read_4;
    end

    assign r_done_posedge = (i_done_read_4 && !r_done_prev); // 0->1 일때만 1임 즉 posedge 검출 하는 로직

    // 3.켜는 건 CPU가, 끄는 건 하드웨어(SWAP)가 함
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            latched_r_done <= 1'b1; 
        end
        else if (run_4) begin 
            latched_r_done <= 1'b0; 
        end
        else if (r_done_posedge) begin
            latched_r_done <= 1'b1;
        end
    end
    

    pingpong #(
        .INPUT(INPUT_4),
        .NODE(NODE_4)
    ) result_pingpong (
        .clk(clk),
        .rst(rst),
        .r_request(i_r_request_4),    //AXI Read Pulse
        .done_read(latched_r_done),    //AXI Handshake
        .done_write(w_done_layer_3), 
        .din(one_node_3), 
        .pingpong_swap(run_4),  //이게 아웃웃으로 나가야함 그래야 악시가 읽어가지
        .w_valid(one_node_valid_3),
        .o_valid(o_slv_reg_valid),    // [Port] Output Valid
        .o_dout(slv_reg_result) // Internal 54bit Result
    );

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
    output                           r_request, 
    output                           done_read,             
    output                           done_write,         
    output reg signed [ACC_RESULT-1:0] one_node_result,       
    output reg                       one_node_result_valid  
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
    reg [CNT_BIT_ACC-1:0]   acc_cnt;        
    reg [CNT_BIT_WRITE-1:0] write_cnt;   

    reg signed [ACC_RESULT-1:0] one_node;           

    wire signed [CORE_RESULT-1:0] o_core_data;
    wire                          o_core_valid;

    reg signed [INPUT-1:0]  input_data_reg;
    reg                     input_valid_reg;
    reg signed [WEIGHT-1:0] weight_data_reg;
    reg                     weight_valid_reg;

    reg run_forward;
    reg run_back;
    reg first_run;

    
    always @(posedge clk or negedge rst) begin
        if(!rst) first_run <= 1'b1;
        else if(c_state == FC_DONE) first_run <= 1'b0;
    end

    // run_forward 래치 (FC_DONE 전까지 유지)
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            run_forward <= 0;
        end else if (run) begin
            run_forward <= 1;
        end else if(c_state == FC_DONE) begin 
            run_forward <= 0;
        end
    end

    // run_back 래치 (FC_DONE 전까지 유지)
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            run_back <= 0;
        end else if (run_after) begin
            run_back <= 1;
        end else if(c_state == FC_DONE) begin
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

    wire   data_valid_comb; 
    assign data_valid_comb = input_valid_reg & weight_valid_reg; 

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    //State Machine Start Condition
    always @(*) begin
        n_state = c_state; 
        case (c_state)
            IDLE: begin
                if ( run_forward && (first_run || run_back) ) 
                    n_state = DATA_FLOW;
            end
            DATA_FLOW: begin
                if (data_cnt == CORE) n_state = CALC_IN_CORE; 
            end 
            CALC_IN_CORE: begin
                if (o_core_valid) n_state = ACC_DATA; 
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

    // req_cnt Logic
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
            one_node <= 0; 
            acc_cnt <= 0;  
        end else begin
            if ((c_state == CALC_IN_CORE) && o_core_valid) begin 
                one_node <= one_node + o_core_data;  
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

    // Handshake logic
    assign done_read     = (n_state == FC_DONE || (n_state == IDLE && !run_forward)); 
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
            valid_shift_reg <= 1'b0; 
        end else begin
            valid_shift_reg <= mult_ready;
        end
    end

    assign mult_valid = valid_shift_reg; //2클락
    assign mult_out = mult_out_d; //1clk 지연한다.  //1clk 뒤에 값이 나온다.

endmodule

