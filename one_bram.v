module axi4_lite_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5 
)
(
    // AXI4-Lite Interface Ports
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
    /* verilator lint_off UNUSED */
    input  wire [2 : 0]                        S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    output wire [1 : 0]                        S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
    input  wire [2 : 0]                        S_AXI_ARPROT,
    /* verilator lint_on UNUSED */
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
    output wire [1 : 0]                        S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY
);

    // 내부 신호 선언
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg                            axi_awready;
    reg                            axi_wready;
    reg [1 : 0]                    axi_bresp;
    reg                            axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg                            axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
    reg [1 : 0]                    axi_rresp;
    reg                            axi_rvalid;
    
    // User Registers
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0; // Input Data Storage (0x00)
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1; // Weight Data Storage (0x04)

    wire                          slv_reg_rden;
    wire                          slv_reg_wren;
    reg  [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
    reg                           aw_en;

    function [C_S_AXI_DATA_WIDTH-1:0] apply_wstrb;
      input [C_S_AXI_DATA_WIDTH-1:0] old_data;
      input [C_S_AXI_DATA_WIDTH-1:0] new_data;
      input [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb;
      integer byte_idx;
      begin
        apply_wstrb = old_data;
        for (byte_idx = 0; byte_idx < (C_S_AXI_DATA_WIDTH/8); byte_idx = byte_idx + 1) begin
          if (wstrb[byte_idx]) begin
            apply_wstrb[(byte_idx*8) +: 8] = new_data[(byte_idx*8) +: 8];
          end
        end
      end
    endfunction

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
        aw_en       <= 1'b1;
      end else begin
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
          axi_awready <= 1'b1;
          aw_en       <= 1'b0;
        end else if (S_AXI_BREADY && axi_bvalid) begin
          aw_en       <= 1'b1;
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
    
    wire w_awaddr_aligned;
    wire w_araddr_aligned;
    assign w_awaddr_aligned = (axi_awaddr[1:0] == 2'b00);
    assign w_araddr_aligned = (axi_araddr[1:0] == 2'b00);
    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && w_awaddr_aligned;

    reg r_input_write_pulse;
    reg r_weight_write_pulse;
    reg r_input_write_done;
    reg r_result_read_done;
    reg r_r_request_pulse;
    reg r_pl_swap_fetch;
    wire w_input_write_pulse;
    wire w_weight_write_pulse;
    wire w_input_write_done;
    wire w_result_read_done;
    wire w_r_request_pulse;

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        slv_reg0             <= 0;
        slv_reg1             <= 0;
        r_input_write_pulse  <= 0;
        r_weight_write_pulse <= 0;
        r_input_write_done   <= 0;
        r_result_read_done   <= 0;
        r_r_request_pulse    <= 0;
        r_pl_swap_fetch      <= 0;
      end else begin
        r_input_write_pulse  <= 0;
        r_weight_write_pulse <= 0;
        r_input_write_done   <= 0;
        r_result_read_done   <= 0;
        r_r_request_pulse    <= 0;
        if (slv_reg_wren) begin
          case ( axi_awaddr[4:2] )
            3'h0: begin // Input Data 
                slv_reg0            <= apply_wstrb(slv_reg0, S_AXI_WDATA, S_AXI_WSTRB);
                if (S_AXI_WSTRB != {C_S_AXI_DATA_WIDTH/8{1'b0}}) begin
                  r_input_write_pulse <= 1'b1;
                end
            end
            3'h1: begin // Weight Data 
                slv_reg1             <= apply_wstrb(slv_reg1, S_AXI_WDATA, S_AXI_WSTRB);
                if (S_AXI_WSTRB != {C_S_AXI_DATA_WIDTH/8{1'b0}}) begin
                  r_weight_write_pulse <= 1'b1;
                end
            end
            3'h3: begin // Control
                if (S_AXI_WSTRB[0]) begin
                  if (S_AXI_WDATA[0]) r_input_write_done <= 1'b1;
                  if (S_AXI_WDATA[1]) r_result_read_done <= 1'b1;
                  if (S_AXI_WDATA[2]) r_r_request_pulse  <= 1'b1;
                  r_pl_swap_fetch <= S_AXI_WDATA[3];
                end
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
    assign w_r_request_pulse    = r_r_request_pulse;
    
    // AXI Read Logic
    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        axi_arready <= 1'b0;
        axi_araddr  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
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
    
    reg r_input_swap_register;
    reg r_result_swap_register;
    
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid & w_araddr_aligned;

    // Input Swap 잡아두기 pl 상태까지 체크한다.
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            r_input_swap_register <= 1'b0;
        end else begin
            if (w_input_swap_pulse) begin
                r_input_swap_register <= 1'b1;
            end
            else if (slv_reg_rden && (axi_araddr[4:2] == 3'h2) && r_pl_swap_fetch) begin
                r_input_swap_register <= 1'b0;
            end
        end
    end

    // Result Swap 잡아두기 상태 레지스터 읽으면 초기화 
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            r_result_swap_register <= 1'b0;
        end else begin
            if (w_result_swap_pulse) begin
                r_result_swap_register <= 1'b1;
            end
            else if (slv_reg_rden && (axi_araddr[4:2] == 3'h2) && r_pl_swap_fetch) begin
                r_result_swap_register <= 1'b0;
            end
        end
    end


    wire [31:0] w_npu_result_lower;
    // wire [31:0] w_npu_result_upper; 
    wire        o_slv_reg_valid;
    wire        w_weight_write_all_done;
    wire        w_input_buffer_write_ready;
    reg         buffer_reset;

    reg [31:0] r_lower_catch;
    // reg [31:0] r_upper_catch;       
    reg        r_valid_status;      

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
        r_lower_catch  <= 32'b0;
        // r_upper_catch <= 32'b0;     
        r_valid_status <= 1'b0;
      end else begin
        if (o_slv_reg_valid) begin 
            r_lower_catch  <= w_npu_result_lower;
            // r_upper_catch <= 32'b0; 
            r_valid_status <= 1'b1; 
        end else if (slv_reg_rden && (axi_araddr[4:2] == 3'h5)) begin 
            r_valid_status <= 1'b0; 
        end
      end
    end

    always @(*) begin
        case ( axi_araddr[4:2] )
            3'h0 : reg_data_out = slv_reg0;
            3'h1 : reg_data_out = slv_reg1;
            3'h2 : reg_data_out = {
                                     27'b0, 
                                     w_input_buffer_write_ready, // Bit 4
                                     r_valid_status,             // Bit 3
                                     r_input_swap_register,      // Bit 2 
                                     r_result_swap_register,     // Bit 1 
                                     w_weight_write_all_done     // Bit 0
                                   };
            // 3'h4 : reg_data_out = r_upper_catch; 
            3'h5 : reg_data_out = r_lower_catch; // 0x14 -> Lower         
            default : reg_data_out = 0;
        endcase
    end

    always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 ) axi_rdata <= 0;
      else if (slv_reg_rden)       axi_rdata <= reg_data_out;
    end    


    always @(posedge S_AXI_ACLK) begin
        if(S_AXI_ARESETN == 1'b0) begin
            buffer_reset <= 1'b0;
        end else begin
            buffer_reset <= 1'b1;
        end
    end


    NPU_Top u_npu (
        .clk                     ( S_AXI_ACLK ),    
        .rst                     ( buffer_reset ), 
        // Input Data
        .i_input_data            ( slv_reg0[7:0] ), 
        .i_input_valid           ( w_input_write_pulse ), //적는 순간의 pulse
        // Weight Data
        .i_weigth_data           ( slv_reg1[7:0] ), 
        .i_weight_valid          ( w_weight_write_pulse ), //적는 순간의 pulse
        .o_weight_write_all_done ( w_weight_write_all_done ), 
        // Control Signals
        .w_done_1                ( w_input_write_done ),    
        .i_done_read_4           ( w_result_read_done ),    
        .i_r_request_4           ( w_r_request_pulse ),      
        // swap signals
        .input_swap              ( w_input_swap_pulse ),                
        .result_swap             ( w_result_swap_pulse ),               
        .o_input_buffer_write_ready ( w_input_buffer_write_ready ),
        // Result Data
        .o_slv_reg_result_lower  ( w_npu_result_lower ),
        // .o_slv_reg_result_upper ( w_npu_result_upper )
        .o_slv_reg_valid         ( o_slv_reg_valid )
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
    parameter QUANT_RESULT = 8,
    parameter INPUT_1 = 8,
    parameter INPUT_2 = QUANT_RESULT, 
    parameter INPUT_3 = QUANT_RESULT,
    parameter INPUT_4 = QUANT_RESULT, // Final Output Width
    // QUANT_SHIFT per layer (calibrated from weight scales)
    // Layer1: uint8 input(0~255), scale=0.00646 -> log2(2/scale) ≈ 9
    // Layer2: int8  input(0~127), scale=0.00648 -> log2(1/scale) ≈ 8
    // Layer3: int8  input(0~127), scale=0.00858 -> log2(1/scale) ≈ 7
    parameter QUANT_SHIFT_1 = 9,
    parameter QUANT_SHIFT_2 = 8,
    parameter QUANT_SHIFT_3 = 7
)(
    input  wire                   clk,
    input  wire                   rst,              
             
    input  wire [WEIGHT_1-1:0]    i_weigth_data,
    input  wire                   i_weight_valid,
    output wire                   o_weight_write_all_done, // 다 썻는지 확인용 이게 떠야지 input data를 넘겨줄 수 있다. 


    input  wire [INPUT_1-1:0]     i_input_data,
    input  wire                   i_input_valid, 
    input  wire                   w_done_1, 
    
    // CPU가 결과를 읽기 위해 보내는 제어 신호
    input  wire                   i_r_request_4, 
    input  wire                   i_done_read_4, 
    
    // CPU로 나가는 결과 데이터
    output wire [CPU_WIDTH-1:0]   o_slv_reg_result_lower,
    output wire                   o_slv_reg_valid,

    output wire                   input_swap,
    output wire                   result_swap,
    output wire                   o_input_buffer_write_ready
);

    // one-BRAM 비교용 상위 데이터 흐름:
    // 1) CPU가 전체 weight를 쓰면 top demux가 순서대로 layer1/2/3의 weight_BRAM으로 분배한다.
    // 2) CPU가 입력 한 프레임을 input_buffer_1에 저장한 뒤 w_done_1로 입력 완료를 알린다.
    // 3) 각 FC stage는 자신의 입력 버퍼를 읽어 연산하고, 양자화된 출력을 다음 버퍼에 기록한다.
    // 4) 마지막 layer는 logit을 result_buffer에 저장하고, CPU는 i_r_request_4/i_done_read_4로 결과를 읽어 간다.
    // 5) 원래 ping-pong 구조와 달리, 아래 bram_buffer는 BRAM 1개만 사용하며 write/read를 phase로 분리한다.

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
    wire input_buffer_ready_1, input_buffer_ready_2, input_buffer_ready_3;
    wire result_buffer_write_ready;
    
    wire din_valid_1, din_valid_2, din_valid_3;
    wire [INPUT_1-1:0] din_1;
    wire [INPUT_2-1:0] din_2;
    wire [INPUT_3-1:0] din_3;

    wire [WEIGHT_1-1:0] weight_data_1, weight_data_2, weight_data_3;
    wire                weight_valid_1, weight_valid_2, weight_valid_3;
    
    wire [QUANT_RESULT-1:0] one_node_1;
    wire [QUANT_RESULT-1:0] one_node_2;
    wire [QUANT_RESULT-1:0] one_node_3;
    
    wire one_node_valid_1, one_node_valid_2, one_node_valid_3;
    wire w_done_layer_1, w_done_layer_2, w_done_layer_3;

    // Result
    wire signed [QUANT_RESULT-1:0] slv_reg_result;

    //lower만 살아남기.
    assign o_slv_reg_result_lower = {{24{slv_reg_result[7]}}, slv_reg_result}; 

    assign input_swap = run_1;
    assign result_swap = run_4;
    assign o_input_buffer_write_ready = input_buffer_ready_1;

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

    // 원래 layer 1의 ping-pong 입력 버퍼를 one-BRAM 비교용 버퍼로 교체했다.
    // 읽기와 쓰기를 두 개의 BRAM bank로 나누지 않고, bram_buffer 내부에서 순차적으로 처리한다.
    bram_buffer #(
        .INPUT ( INPUT_1 ),
        .NODE  ( NODE_1 )
    ) input_buffer_1 (
        .clk           ( clk ),
        .rst           ( rst ),
        .r_request     ( r_request_1 ),
        .done_read     ( done_read_1 ),
        .done_write    ( w_done_1 ),
        .din           ( i_input_data ),       
        .buffer_swap   ( run_1 ), // 기존 pingpong_swap 역할을 하던 경계 펄스 신호이다.
        .w_ready       ( input_buffer_ready_1 ),
        .w_valid       ( i_input_valid ),  
        .o_valid       ( din_valid_1 ),
        .o_dout        ( din_1 )
    );
    
    weight_BRAM #(
        .WEIGHT ( WEIGHT_1 ),
        .NODE   ( NODE_1 ),
        .N_NODE ( NODE_2 )
    ) weight_BRAM_1 (
        .clk               ( clk ),
        .rst               ( rst ),
        .w_data            ( weight_in_1 ),
        .w_valid           ( weight_in_valid_1 ),
        .r_request         ( r_request_1 ),
        .weight_data       ( weight_data_1 ),
        .weight_valid      ( weight_valid_1 ),
        .weight_write_done ( weight_write_done_1 )
    );

    FC_DUT #(
        .NODE        ( NODE_1 ),
        .N_NODE      ( NODE_2 ),
        .INPUT       ( INPUT_1 ),
        .WEIGHT      ( WEIGHT_1 ),
        .CORE        ( CORE_1 ),
        .QUANT_SHIFT ( QUANT_SHIFT_1 )
    ) FC_DUT_1 (
        .clk            ( clk ),
        .rst            ( rst ),
        .run            ( run_1 ), 
        .out_buf_ready  ( input_buffer_ready_2 ),
        .input_data     ( din_1 ),
        .input_valid    ( din_valid_1 ),
        .weight         ( weight_data_1 ),
        .weight_valid   ( weight_valid_1 ),
        .r_request      ( r_request_1 ),
        .done_read      ( done_read_1 ),
        .done_write     ( w_done_layer_1 ),
        .one_node       ( one_node_1 ),
        .one_node_valid ( one_node_valid_1 )
    );

    // layer 2도 동일하게 교체했다. 바깥쪽 handshake는 유지하고 데이터 저장만 single-BRAM 버퍼로 바꿨다.
    bram_buffer #(
        .INPUT ( INPUT_2 ),
        .NODE  ( NODE_2 )
    ) input_buffer_2 (
        .clk           ( clk ),
        .rst           ( rst ),
        .r_request     ( r_request_2 ),
        .done_read     ( done_read_2 ),
        .done_write    ( w_done2 ),
        .din           ( one_node_1 ),
        .buffer_swap   ( run_2 ),
        .w_ready       ( input_buffer_ready_2 ),
        .w_valid       ( one_node_valid_1 ),
        .o_valid       ( din_valid_2 ),
        .o_dout        ( din_2 )
    );

    weight_BRAM #(
        .WEIGHT ( WEIGHT_1 ),
        .NODE   ( NODE_2 ),
        .N_NODE ( NODE_3 )
    ) weight_BRAM_2 (
        .clk               ( clk ),
        .rst               ( rst ),
        .w_data            ( weight_in_2 ),
        .w_valid           ( weight_in_valid_2 ), 
        .r_request         ( r_request_2 ),
        .weight_data       ( weight_data_2 ),
        .weight_valid      ( weight_valid_2 ),
        .weight_write_done ( weight_write_done_2 ) 
    );

    FC_DUT #(
        .NODE        ( NODE_2 ),
        .N_NODE      ( NODE_3 ),
        .INPUT       ( INPUT_2 ),
        .WEIGHT      ( WEIGHT_1 ),
        .CORE        ( CORE_1 ),
        .QUANT_SHIFT ( QUANT_SHIFT_2 )
    ) FC_DUT_2 (
        .clk            ( clk ),
        .rst            ( rst ),
        .run            ( run_2 ),
        .out_buf_ready  ( input_buffer_ready_3 ), 
        .input_data     ( din_2 ),
        .input_valid    ( din_valid_2 ),
        .weight         ( weight_data_2 ),
        .weight_valid   ( weight_valid_2 ),
        .r_request      ( r_request_2 ),
        .done_read      ( done_read_2 ),
        .done_write     ( w_done_layer_2 ),
        .one_node       ( one_node_2 ),
        .one_node_valid ( one_node_valid_2 )
    );

    // layer 3도 동일하게 교체했다. 이 stage 역시 ping-pong 대신 phase 기반 one-BRAM 버퍼를 사용한다.
    bram_buffer #(
        .INPUT ( INPUT_3 ),
        .NODE  ( NODE_3 )
    ) input_buffer_3 (
        .clk           ( clk ),
        .rst           ( rst ),
        .r_request     ( r_request_3 ),
        .done_read     ( done_read_3 ),
        .done_write    ( w_done3 ), 
        .din           ( one_node_2 ),
        .buffer_swap   ( run_3 ),
        .w_ready       ( input_buffer_ready_3 ),
        .w_valid       ( one_node_valid_2 ),
        .o_valid       ( din_valid_3 ),
        .o_dout        ( din_3 )
    );

    weight_BRAM #(
        .WEIGHT ( WEIGHT_1 ),
        .NODE   ( NODE_3 ),
        .N_NODE ( NODE_4 )
    ) weight_BRAM_3 (
        .clk               ( clk ),
        .rst               ( rst ),
        .w_data            ( weight_in_3 ),
        .w_valid           ( weight_in_valid_3 ), 
        .r_request         ( r_request_3 ),
        .weight_data       ( weight_data_3 ),
        .weight_valid      ( weight_valid_3 ),
        .weight_write_done ( weight_write_done_3 ) 
    );

    // Layer3: ReLU 없이 FC_layer 직접 인스턴스 (logit 출력)
    FC_layer #(
        .NODE        ( NODE_3 ),
        .N_NODE      ( NODE_4 ),
        .INPUT       ( INPUT_3 ),
        .WEIGHT      ( WEIGHT_1 ),
        .CORE        ( CORE_1 ),
        .QUANT_SHIFT ( QUANT_SHIFT_3 )
    ) FC_layer_3 (
        .clk                   ( clk ),
        .rst                   ( rst ),
        .run                   ( run_3 ),
        .out_buf_ready         ( result_buffer_write_ready ),
        .input_data            ( din_3 ),
        .input_valid           ( din_valid_3 ),
        .weight_data           ( weight_data_3 ),
        .weight_valid          ( weight_valid_3 ),
        .r_request             ( r_request_3 ),
        .done_read             ( done_read_3 ),
        .done_write            ( w_done_layer_3 ),
        .one_node_result       ( one_node_3 ),
        .one_node_result_valid ( one_node_valid_3 )
    );



    reg latched_r_done;
    reg r_done_prev; 
    wire r_done_posedge; 
    
    always @(posedge clk or negedge rst) begin
        if (!rst) r_done_prev <= 0;
        else      r_done_prev <= i_done_read_4;
    end

    assign r_done_posedge = (i_done_read_4 && !r_done_prev); 


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
    

    // 최종 결과 저장부도 ping-pong 대신 BRAM 1개로 바꿔서 PS 쪽 읽기까지 같은 비교 조건을 맞췄다.
    bram_buffer #(
        .INPUT ( INPUT_4 ),
        .NODE  ( NODE_4 )
    ) result_buffer (
        .clk           ( clk ),
        .rst           ( rst ),
        .r_request     ( i_r_request_4 ),   
        .done_read     ( latched_r_done ),  
        .done_write    ( w_done_layer_3 ), 
        .din           ( one_node_3 ), 
        .buffer_swap   ( run_4 ),
        .w_ready       ( result_buffer_write_ready ),
        .w_valid       ( one_node_valid_3 ),
        .o_valid       ( o_slv_reg_valid ),   
        .o_dout        ( slv_reg_result ) 
    );

endmodule

module FC_DUT #(
    parameter NODE         = 784,
    parameter N_NODE       = 128,
    parameter INPUT        = 8,
    parameter WEIGHT       = 8,
    parameter CORE         = 8,
    parameter QUANT_RESULT = 8,
    parameter QUANT_SHIFT  = (INPUT + WEIGHT + $clog2(NODE)) - 8  // default: same formula as FC_layer
) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   run,
    input  wire                   out_buf_ready,
    input  wire [INPUT-1:0]       input_data,
    input  wire                   input_valid,
    input  wire [WEIGHT-1:0]      weight,
    input  wire                   weight_valid,
    output wire                   r_request,
    output wire                   done_read,
    output wire                   done_write,
    output wire [QUANT_RESULT-1:0] one_node,
    output wire                   one_node_valid  
);

    wire                   w_done;
    wire [QUANT_RESULT-1:0] one_node_result; // Quantized Result (8bit)
    wire                   one_node_result_valid;
    assign done_write = w_done;

    //FC layer 
    FC_layer #(
        .NODE         ( NODE ),
        .N_NODE       ( N_NODE ),
        .INPUT        ( INPUT ),
        .WEIGHT       ( WEIGHT ),
        .CORE         ( CORE ),
        .QUANT_SHIFT  ( QUANT_SHIFT ),
        .QUANT_RESULT ( QUANT_RESULT )
    ) u_FC_layer (
        .clk                   ( clk ),
        .rst                   ( rst ),
        .run                   ( run ), 
        .out_buf_ready         ( out_buf_ready ),
        .input_data            ( input_data ), 
        .input_valid           ( input_valid ),
        .weight_data           ( weight ),
        .weight_valid          ( weight_valid ),
        .r_request             ( r_request ),
        .done_read             ( done_read ),
        .done_write            ( w_done ),
        .one_node_result       ( one_node_result ),
        .one_node_result_valid ( one_node_result_valid )
    );

    ReLU #(
        .DWIDTH ( QUANT_RESULT )
    ) u_relu (
        .clk        ( clk ),
        .rst        ( rst ),
        .w_valid    ( one_node_result_valid ),
        .din        ( one_node_result ),
        .dout       ( one_node ),
        .dout_valid ( one_node_valid )
    );
endmodule



module FC_layer #(
    parameter NODE   = 784,    
    parameter N_NODE = 128,     
    parameter INPUT  = 8,
    parameter WEIGHT = 8,
    parameter CORE   = 8,
    parameter CORE_RESULT  = INPUT + WEIGHT + $clog2(CORE),      // 19bit
    parameter ACC_RESULT   = INPUT + WEIGHT + $clog2(NODE),       // 26bit
    parameter QUANT_SHIFT = ACC_RESULT - 8, //8비트만 남도록 시프트해야하는 값
    parameter QUANT_RESULT = 8

) (
    input                            clk,
    input                            rst,
    input                            run, 
    input                            out_buf_ready,             
    input [INPUT-1:0]                input_data,    
    input                            input_valid,   
    input signed [WEIGHT-1:0]        weight_data,   
    input                            weight_valid,  
    output                           r_request, 
    output                           done_read,             
    output                           done_write,         
    output reg signed [QUANT_RESULT-1:0] one_node_result,       
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
    localparam [31:0] ACC_TARGET_FULL = NODE/CORE;
    localparam [CNT_BIT_ACC-1:0] ACC_TARGET = ACC_TARGET_FULL[CNT_BIT_ACC-1:0];

    reg [CNT_BIT_CORE-1:0]  data_cnt;       
    reg [CNT_BIT_ACC-1:0]   acc_cnt;        
    reg [CNT_BIT_WRITE-1:0] write_cnt;   

    reg signed [ACC_RESULT-1:0] one_node;           

    wire signed [CORE_RESULT-1:0] o_core_data;
    wire signed [ACC_RESULT-1:0]  o_core_data_ext;
    wire                          o_core_valid;

    reg [INPUT-1:0]  input_data_reg;
    reg                     input_valid_reg;
    reg signed [WEIGHT-1:0] weight_data_reg;
    reg                     weight_valid_reg;

    reg run_forward;
    reg signed [ACC_RESULT-1:0] one_node_reg;

    // 1. 반올림(+0.5) 상수 덧셈: 정수 1은 기본 signed이므로 안전하게 연산됨
    wire signed [ACC_RESULT-1:0] pre_shift_half_up;
    assign pre_shift_half_up = one_node_reg + (1 << (QUANT_SHIFT - 1));

    // 2. 수동 산술 시프트 (Manual Sign Extension): 부호 비트(MSB) 물리적 복제
    wire signed [ACC_RESULT-1:0] shifted_data;
    assign shifted_data = { 
        {QUANT_SHIFT{pre_shift_half_up[ACC_RESULT-1]}}, // 잘려나간 빈자리를 MSB로 채움
        pre_shift_half_up[ACC_RESULT-1 : QUANT_SHIFT]   // 필요한 데이터 구간만 잘라냄
    };

    reg signed [QUANT_RESULT-1:0] quantized_data; // 8비트 결과
    

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
    assign o_core_data_ext = {{(ACC_RESULT-CORE_RESULT){o_core_data[CORE_RESULT-1]}}, o_core_data};

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
                if ( run_forward && out_buf_ready ) 
                    n_state = DATA_FLOW;
            end
            DATA_FLOW: begin
                if ((data_cnt == CORE-1) && data_valid_comb) n_state = CALC_IN_CORE; 
            end 
            CALC_IN_CORE: begin
                if (o_core_valid) n_state = ACC_DATA; 
            end
            ACC_DATA: begin 
                if (acc_cnt == ACC_TARGET) n_state = DONE_ONE;
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
            default : begin
                n_state = IDLE;
            end
        endcase
    end

    // req_cnt Logic
    reg [CNT_BIT_CORE-1:0] req_cnt;
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
 
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            data_cnt <= 0;
        end else if (data_valid_comb && (data_cnt < CORE)) begin 
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
                one_node <= one_node + o_core_data_ext;
                acc_cnt <= acc_cnt + 1;
            end 
            else if (c_state == DONE_ONE) begin
                one_node <= 0;      
                acc_cnt <= 0;   
            end
        end
    end

  
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            one_node_reg <= 0;
        end else if (c_state == ACC_DATA && acc_cnt == ACC_TARGET) begin
            one_node_reg <= one_node; 
        end else if(c_state == MEM_WR) begin
            one_node_reg <= 0;
        end
    end

    always @(*) begin
        if (shifted_data > 127) begin
            quantized_data = 8'sd127;
        end else if (shifted_data < -128) begin 
            quantized_data = -8'sd128;        
        end else begin
            quantized_data = shifted_data[7:0];
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            one_node_result <= 0;
            one_node_result_valid <= 0;
        end else if(c_state == MEM_WR) begin
            one_node_result <= quantized_data;
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
    assign done_read     = (c_state == FC_DONE || (c_state == IDLE && !run_forward));
    assign done_write    = (c_state == FC_DONE); 
 
    core #(
        .INPUT  ( INPUT ), 
        .WEIGHT ( WEIGHT ), 
        .CORE   ( CORE )
    ) u0 (
        .clk          ( clk ),
        .rst          ( rst ),
        .i_input      ( input_data_reg ),   
        .i_weight     ( weight_data_reg ),  
        .i_data_valid ( data_valid_comb ),
        .o_core_data  ( o_core_data ),
        .o_core_valid ( o_core_valid )
    );
endmodule

module core #(
    parameter INPUT  = 8,
    parameter WEIGHT = 8,
    parameter CORE   = 8,
    parameter OUT    = INPUT + WEIGHT + $clog2(CORE) 
)(
    input                            clk,
    input                            rst,
    input  [INPUT-1:0]               i_input,
    input  signed [WEIGHT-1:0]       i_weight,     
    input                            i_data_valid, 
    output reg signed [OUT-1:0]      o_core_data,  
    output reg                       o_core_valid  
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
    localparam CNT_BIT_CORE = $clog2(CORE + 1);

    reg  [2:0]  c_state, n_state;
    reg  [CNT_BIT_CORE-1:0]  data_counter; 

    reg         [INPUT-1:0]  reg_input   [0:CORE-1]; 
    reg  signed [WEIGHT-1:0] reg_weight  [0:CORE-1];

    assign data_all_ready = (data_counter == CORE-1); 
    assign all_valid      = &mult_valid_vec; 


    //1번째 덧셈
    wire signed [SUM_WIDTH-1:0] sum_step1 [0:3]; 
    assign sum_step1[0] = {{(SUM_WIDTH-MULT_WIDTH){mult_out[0][MULT_WIDTH-1]}}, mult_out[0]} +
                          {{(SUM_WIDTH-MULT_WIDTH){mult_out[1][MULT_WIDTH-1]}}, mult_out[1]};
    assign sum_step1[1] = {{(SUM_WIDTH-MULT_WIDTH){mult_out[2][MULT_WIDTH-1]}}, mult_out[2]} +
                          {{(SUM_WIDTH-MULT_WIDTH){mult_out[3][MULT_WIDTH-1]}}, mult_out[3]};
    assign sum_step1[2] = {{(SUM_WIDTH-MULT_WIDTH){mult_out[4][MULT_WIDTH-1]}}, mult_out[4]} +
                          {{(SUM_WIDTH-MULT_WIDTH){mult_out[5][MULT_WIDTH-1]}}, mult_out[5]};
    assign sum_step1[3] = {{(SUM_WIDTH-MULT_WIDTH){mult_out[6][MULT_WIDTH-1]}}, mult_out[6]} +
                          {{(SUM_WIDTH-MULT_WIDTH){mult_out[7][MULT_WIDTH-1]}}, mult_out[7]};
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
    // 1클럭 지연된 MULT_RUN 상태를 저장할 레지스터
    reg r_mult_run_delay;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            r_mult_run_delay <= 1'b0;
        end else begin
            // 현재 상태가 MULT_RUN인지 여부(1 또는 0)를 다음 클럭으로 넘김
            r_mult_run_delay <= (c_state == MULT_RUN); 
        end
    end

    // 상승 에지(Rising Edge) 검출을 통한 1클럭 펄스 생성
    wire w_mult_ready_pulse;
    assign w_mult_ready_pulse = (c_state == MULT_RUN) & ~r_mult_run_delay;
   


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
            multiplier u_multiplier (  
                .clk        ( clk ),
                .rst        ( rst ), 
                .a          ( reg_input[i] ),   
                .b          ( reg_weight[i] ), 
                .mult_ready ( w_mult_ready_pulse ), 
                .product    ( mult_out[i] ),       
                .mult_valid ( mult_valid_vec[i] ) 
            );
        end
    endgenerate
endmodule

module ReLU #(
    parameter DWIDTH = 8
) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   w_valid,
    input  wire signed [DWIDTH-1:0] din,
    output reg  signed [DWIDTH-1:0] dout, 
    output reg                    dout_valid
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

module weight_BRAM #( 
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
        .DWIDTH ( DWIDTH ),
        .AWIDTH ( AWIDTH ),
        .NODE   ( NODE ),
        .N_NODE ( N_NODE )
    ) u_bram (
        .clk  ( clk ),
        .addr ( addr ), 
        .we   ( w_valid ),      
        .en   ( w_valid || r_request ), 
        .din  ( w_data ),
        .dout ( weight_data_wire )
    );
endmodule

module SPRAM_WBRAM #(
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

    // 메모리 접근은 의도적으로 단순하게 구성했다. 메모리 배열 하나를 두고 phase에 따라 write/read를 나눈다.
    // 또한 주변 FC 로직이 기대하는 2-cycle 형태의 출력 파이프라인을 그대로 맞춘다.
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


(* use_dsp = "no" *)
module multiplier #(
    parameter INPUT  = 8,
    parameter WEIGHT = 8
)(
    input                                clk,
    input                                rst,
    input  [INPUT-1:0]                   a,
    input                                mult_ready,
    input  signed [WEIGHT-1:0]           b,
    output signed [INPUT+WEIGHT-1:0]     product,
    output                               mult_valid
);
    mba_wallace_8bit u_mba_wallace_8bit (
        .clk        ( clk ),
        .rst_n      ( rst ),
        .a          ( a ),
        .mult_ready ( mult_ready ),
        .b          ( b ),
        .product    ( product ),
        .mult_valid ( mult_valid )
    );
endmodule


module dot_op (
    input  wire g_upper,
    input  wire p_upper,
    input  wire g_lower,
    input  wire p_lower,
    output wire g_out,
    output wire p_out
);
    assign p_out = p_upper & p_lower;
    assign g_out = g_upper | (p_upper & g_lower);
endmodule


module brent_kung_8bit (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p, g;
    wire [8:0] c;

    assign p = a ^ b;
    assign g = a & b;

    // Level 1
    wire G10, P10;
    wire G32, P32;
    wire G54, P54;
    wire G76, P76;

    dot_op u_l1_10 (
        .g_upper(g[1]), .p_upper(p[1]),
        .g_lower(g[0]), .p_lower(p[0]),
        .g_out(G10),    .p_out(P10)
    );

    dot_op u_l1_32 (
        .g_upper(g[3]), .p_upper(p[3]),
        .g_lower(g[2]), .p_lower(p[2]),
        .g_out(G32),    .p_out(P32)
    );

    dot_op u_l1_54 (
        .g_upper(g[5]), .p_upper(p[5]),
        .g_lower(g[4]), .p_lower(p[4]),
        .g_out(G54),    .p_out(P54)
    );

    dot_op u_l1_76 (
        .g_upper(g[7]), .p_upper(p[7]),
        .g_lower(g[6]), .p_lower(p[6]),
        .g_out(G76),    .p_out(P76)
    );

    // Level 2
    wire G30, P30;
    wire G74, P74;

    dot_op u_l2_30 (
        .g_upper(G32), .p_upper(P32),
        .g_lower(G10), .p_lower(P10),
        .g_out(G30),   .p_out(P30)
    );

    dot_op u_l2_74 (
        .g_upper(G76), .p_upper(P76),
        .g_lower(G54), .p_lower(P54),
        .g_out(G74),   .p_out(P74)
    );

    // Level 3
    wire G70, P70;

    dot_op u_l3_70 (
        .g_upper(G74), .p_upper(P74),
        .g_lower(G30), .p_lower(P30),
        .g_out(G70),   .p_out(P70)
    );

    // Prefix completion
    wire G20, P20;
    wire G40, P40;
    wire G50, P50;
    wire G60, P60;

    dot_op u_pc_20 (
        .g_upper(g[2]), .p_upper(p[2]),
        .g_lower(G10),  .p_lower(P10),
        .g_out(G20),    .p_out(P20)
    );

    dot_op u_pc_40 (
        .g_upper(g[4]), .p_upper(p[4]),
        .g_lower(G30),  .p_lower(P30),
        .g_out(G40),    .p_out(P40)
    );

    dot_op u_pc_50 (
        .g_upper(G54), .p_upper(P54),
        .g_lower(G30), .p_lower(P30),
        .g_out(G50),   .p_out(P50)
    );

    dot_op u_pc_60 (
        .g_upper(g[6]), .p_upper(p[6]),
        .g_lower(G50),  .p_lower(P50),
        .g_out(G60),    .p_out(P60)
    );

    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = G10  | (P10  & c[0]);
    assign c[3] = G20  | (P20  & c[0]);
    assign c[4] = G30  | (P30  & c[0]);
    assign c[5] = G40  | (P40  & c[0]);
    assign c[6] = G50  | (P50  & c[0]);
    assign c[7] = G60  | (P60  & c[0]);
    assign c[8] = G70  | (P70  & c[0]);

    assign sum  = p ^ c[7:0];
    assign cout = c[8];
endmodule


(* use_dsp = "no" *)
module mba_wallace_8bit (
    input                   clk,
    input                   rst_n,
    input  [7:0]            a,
    input                   mult_ready,
    input  signed [7:0]     b,
    output signed [15:0]    product,
    output                  mult_valid
);
    localparam W = 16;

    // valid pipeline
    reg [5:0] valid_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_pipe <= 6'b000000;
        else
            valid_pipe <= {valid_pipe[4:0], mult_ready};
    end

    assign mult_valid = valid_pipe[5];

    // input register
    reg [7:0]        a_r;
    reg signed [7:0] b_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= 8'd0;
            b_r <= 8'sd0;
        end else begin
            a_r <= a;
            b_r <= b;
        end
    end

    // Booth encoding
    wire [2:0] booth_code0 = {b_r[1], b_r[0], 1'b0};
    wire [2:0] booth_code1 = {b_r[3], b_r[2], b_r[1]};
    wire [2:0] booth_code2 = {b_r[5], b_r[4], b_r[3]};
    wire [2:0] booth_code3 = {b_r[7], b_r[6], b_r[5]};

    wire signed [8:0] a_ext = {1'b0, a_r};
    wire signed [W-1:0] a_x1 = {{(W-9){1'b0}}, a_ext};
    wire signed [W-1:0] a_x2 = {{(W-10){1'b0}}, a_ext, 1'b0};

    function signed [W-1:0] booth_select;
        input [2:0] code;
        input signed [W-1:0] x1;
        input signed [W-1:0] x2;
        begin
            case (code)
                3'b001, 3'b010: booth_select = x1;
                3'b011:         booth_select = x2;
                3'b100:         booth_select = -x2;
                3'b101, 3'b110: booth_select = -x1;
                default:        booth_select = {W{1'b0}};
            endcase
        end
    endfunction

    wire signed [W-1:0] pp0_comb = booth_select(booth_code0, a_x1, a_x2);
    wire signed [W-1:0] pp1_comb = booth_select(booth_code1, a_x1, a_x2) <<< 2;
    wire signed [W-1:0] pp2_comb = booth_select(booth_code2, a_x1, a_x2) <<< 4;
    wire signed [W-1:0] pp3_comb = booth_select(booth_code3, a_x1, a_x2) <<< 6;

    reg signed [W-1:0] pp0_reg;
    reg signed [W-1:0] pp1_reg;
    reg signed [W-1:0] pp2_reg;
    reg signed [W-1:0] pp3_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pp0_reg <= {W{1'b0}};
            pp1_reg <= {W{1'b0}};
            pp2_reg <= {W{1'b0}};
            pp3_reg <= {W{1'b0}};
        end else begin
            pp0_reg <= pp0_comb;
            pp1_reg <= pp1_comb;
            pp2_reg <= pp2_comb;
            pp3_reg <= pp3_comb;
        end
    end

    // Wallace stage 1
    wire [W-1:0] s1_comb;
    wire [W-1:0] c1_unshift;

    assign s1_comb[0]    = pp0_reg[0];
    assign c1_unshift[0] = 1'b0;
    assign s1_comb[1]    = pp0_reg[1];
    assign c1_unshift[1] = 1'b0;

    genvar i_ha;
    generate
        for (i_ha = 2; i_ha <= 3; i_ha = i_ha + 1) begin : GEN_WALLACE_ST1_HA
            half_adder u_st1_ha (
                .a   (pp0_reg[i_ha]),
                .b   (pp1_reg[i_ha]),
                .sum (s1_comb[i_ha]),
                .cout(c1_unshift[i_ha])
            );
        end
    endgenerate

    genvar i_fa;
    generate
        for (i_fa = 4; i_fa < W; i_fa = i_fa + 1) begin : GEN_WALLACE_ST1_FA
            full_adder u_st1_fa (
                .a   (pp0_reg[i_fa]),
                .b   (pp1_reg[i_fa]),
                .cin (pp2_reg[i_fa]),
                .sum (s1_comb[i_fa]),
                .cout(c1_unshift[i_fa])
            );
        end
    endgenerate

    wire [W-1:0] c1_comb = {c1_unshift[W-2:0], 1'b0};

    reg [W-1:0] s1_reg;
    reg [W-1:0] c1_reg;
    reg [W-1:0] pp3_s1_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_reg     <= {W{1'b0}};
            c1_reg     <= {W{1'b0}};
            pp3_s1_reg <= {W{1'b0}};
        end else begin
            s1_reg     <= s1_comb;
            c1_reg     <= c1_comb;
            pp3_s1_reg <= pp3_reg;
        end
    end

    // Wallace stage 2
    wire [W-1:0] sum_stage2_comb;
    wire [W-1:0] carry_stage2_unshift;

    assign sum_stage2_comb[0]      = s1_reg[0];
    assign carry_stage2_unshift[0] = 1'b0;
    assign sum_stage2_comb[1]      = s1_reg[1];
    assign carry_stage2_unshift[1] = 1'b0;
    assign sum_stage2_comb[2]      = s1_reg[2];
    assign carry_stage2_unshift[2] = 1'b0;

    genvar i_ha2;
    generate
        for (i_ha2 = 3; i_ha2 <= 5; i_ha2 = i_ha2 + 1) begin : GEN_WALLACE_ST2_HA
            half_adder u_st2_ha (
                .a   (s1_reg[i_ha2]),
                .b   (c1_reg[i_ha2]),
                .sum (sum_stage2_comb[i_ha2]),
                .cout(carry_stage2_unshift[i_ha2])
            );
        end
    endgenerate

    genvar i_fa2;
    generate
        for (i_fa2 = 6; i_fa2 < W; i_fa2 = i_fa2 + 1) begin : GEN_WALLACE_ST2_FA
            full_adder u_st2_fa (
                .a   (s1_reg[i_fa2]),
                .b   (pp3_s1_reg[i_fa2]),
                .cin (c1_reg[i_fa2]),
                .sum (sum_stage2_comb[i_fa2]),
                .cout(carry_stage2_unshift[i_fa2])
            );
        end
    endgenerate

    wire [W-1:0] carry_stage2_comb = {carry_stage2_unshift[W-2:0], 1'b0};

    reg [W-1:0] sum_stage2_reg;
    reg [W-1:0] carry_stage2_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_stage2_reg   <= {W{1'b0}};
            carry_stage2_reg <= {W{1'b0}};
        end else begin
            sum_stage2_reg   <= sum_stage2_comb;
            carry_stage2_reg <= carry_stage2_comb;
        end
    end
    
    // Final CPA : 8bit Brent-Kung low + 8bit Brent-Kung high

    wire [7:0] final_sum_low_comb;
    wire       final_cout_low_comb;
    reg  [7:0] final_sum_low_reg;
    reg        final_cout_low_reg;
    reg  [7:0] final_a_high_reg;
    reg  [7:0] final_b_high_reg;

    wire [7:0] final_sum_high_comb;
    wire       final_cout_high_unused;

    brent_kung_8bit u_final_bk_low (
        .a    ( sum_stage2_reg[7:0] ), //상위 8비트
        .b    ( carry_stage2_reg[7:0] ), //상위 8비트
        .cin  ( 1'b0 ),
        .sum  ( final_sum_low_comb ),
        .cout ( final_cout_low_comb )
    );

    brent_kung_8bit u_final_bk_high (
        .a    ( final_a_high_reg ),
        .b    ( final_b_high_reg ),
        .cin  ( final_cout_low_reg ),
        .sum  ( final_sum_high_comb ),
        .cout ( final_cout_high_unused )
    );

    reg signed [15:0] product_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_sum_low_reg  <= 8'd0;
            final_cout_low_reg <= 1'b0;
            final_a_high_reg   <= 8'd0;
            final_b_high_reg   <= 8'd0;
            product_reg        <= 16'sd0;
        end else begin
            // stage N: low 8-bit BK result 저장
            final_sum_low_reg  <= final_sum_low_comb;
            final_cout_low_reg <= final_cout_low_comb;

            // stage N: high 입력 저장
            final_a_high_reg   <= sum_stage2_reg[15:8];
            final_b_high_reg   <= carry_stage2_reg[15:8];

            // stage N+1 효과: 이전 low carry를 사용한 high 합 + 이전 low sum 결합
            product_reg        <= {final_sum_high_comb, final_sum_low_reg};
        end
    end

    assign product = product_reg;

endmodule


module full_adder(
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    wire s1, c1, c2;
    half_adder ha1(.a(a),  .b(b),   .sum(s1),  .cout(c1));
    half_adder ha2(.a(s1), .b(cin), .sum(sum), .cout(c2));
    assign cout = c1 | c2;
endmodule


module half_adder(
    input  wire a,
    input  wire b,
    output wire sum,
    output wire cout
);
    assign sum  = a ^ b;
    assign cout = a & b;
endmodule


// 기존 ping-pong 버퍼를 대체하는 one-BRAM 버퍼이다.
// 내부에서는 메모리 배열 하나를 기준으로 WRITE, SWAP, READ 단계를 번갈아 수행한다.
module bram_buffer #(
    parameter INPUT  = 8,
    parameter NODE   = 784,
    parameter AWIDTH = $clog2(NODE),
    parameter DEPTH  = NODE
)(
    input  wire             rst,
    input  wire             clk,
    input  wire             r_request,
    input  wire [INPUT-1:0] din,
    input  wire             done_read,
    input  wire             done_write,
    input  wire             w_valid,
    output wire             buffer_swap,
    output wire             w_ready,
    output reg              o_valid,
    output wire [INPUT-1:0] o_dout
);

    // WRITE_PHASE: 이전 layer 또는 PS 영역에서 넘겨주는 값을 저장하는 Staet
    // SWAP_PHASE : 다음 layer가 시작할 수 있도록 1-cycle 경계 펄스를 내보내는 구간
    // READ_PHASE : 같은 BRAM에 저장된 데이터를 next FC layer로 다시 내보내는 구간
    localparam WRITE_PHASE = 2'b00;
    localparam SWAP_PHASE  = 2'b01;
    localparam READ_PHASE  = 2'b10;
    localparam [AWIDTH-1:0] DEPTH_LAST = NODE-1;

    (* ram_style = "block" *) reg [INPUT-1:0] mem [0:NODE-1];
    //FS 신호
    reg [1:0]          c_state;
    reg [1:0]          n_state;

    reg [AWIDTH-1:0]   w_addr;
    reg [AWIDTH-1:0]   r_addr;
    reg [INPUT-1:0]    bram_out;
    reg [INPUT-1:0]    dout_out;
    //Weight BRAM과 맞추기 위해서 설정한 Delay
    reg                reading_delay1;

    //write done과 read done을 저장할 신호
    reg                flag_write_done;
    reg                flag_read_done;

    wire can_write;
    wire can_read;

    // single-BRAM 모델이므로, 서로 다른 bank에서 동시에 read/write하는 동작은 사용하지 않는다.
    // 현재 phase에 따라 접근 방향을 결정한다.
    assign can_write = (c_state == WRITE_PHASE) && w_valid;
    assign can_read  = (c_state == READ_PHASE)  && r_request;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            c_state <= WRITE_PHASE;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        n_state = c_state;
        case (c_state)
            WRITE_PHASE: begin
                if (flag_write_done && flag_read_done) begin
                    n_state = SWAP_PHASE;
                end
            end
            SWAP_PHASE: begin
                n_state = READ_PHASE;
            end
            READ_PHASE: begin
                if (done_read) begin
                    n_state = WRITE_PHASE;
                end
            end
            default: begin
                n_state = WRITE_PHASE;
            end
        endcase
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            flag_write_done <= 1'b0;
            flag_read_done  <= 1'b0;
        end else begin
            case (c_state)
                WRITE_PHASE: begin
                    if (done_write) begin
                        flag_write_done <= 1'b1;
                    end
                    if (done_read) begin
                        flag_read_done <= 1'b1;
                    end
                end
                SWAP_PHASE: begin
                    flag_write_done <= 1'b0;
                    flag_read_done  <= 1'b0;
                end
                default: begin
                    flag_write_done <= flag_write_done;
                    flag_read_done  <= flag_read_done;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            w_addr <= 1'b0;
        end else if (c_state == READ_PHASE && done_read) begin
            w_addr <= 1'b0;
        end else if (can_write) begin
            if (w_addr == DEPTH_LAST) begin
                w_addr <= 1'b0;
            end else begin
                w_addr <= w_addr + 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            r_addr <= 1'b0;
        end else if (c_state == SWAP_PHASE) begin
            r_addr <= 1'b0;
        end else if (can_read) begin
            if (r_addr == DEPTH_LAST) begin
                r_addr <= 1'b0;
            end else begin
                r_addr <= r_addr + 1'b1;
            end
        end
    end

    //굳이 레지스터 2개 쓸 필요도 없는 것 같은데 왜 두번 담아서 나가게 하지? 그냥 concetnation 하면 되는데? 
    always @(posedge clk) begin
        if (can_write) begin
            mem[w_addr] <= din;
        end

        if (can_read) begin
            bram_out <= mem[r_addr];
        end

        dout_out <= bram_out;
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            reading_delay1 <= 1'b0;
            o_valid        <= 1'b0;
        end else begin
            reading_delay1 <= can_read;
            o_valid        <= reading_delay1;
        end
    end

    // buffer_swap은 뒷 단 layer read 시작 펄스이고, w_ready는 앞단 Layer write 허가 레벨이다.
    assign buffer_swap   = (c_state == SWAP_PHASE);
    assign w_ready       = (c_state == WRITE_PHASE);
    assign o_dout        = dout_out;

endmodule
