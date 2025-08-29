module fipe_line ( //이것이 동작, DUT
    input clk,
    input reset,
    input i_valid,
    input i_data,
    output o_valid
    output o_data
    
);
reg [63:0] r_project2;
reg [63:0] r_project4;
reg [63:0] r_project8;
reg [2:0]  r_valid;

wire [63:0] project2;
wire [63:0] project4;
wire [63:0] project8;

//valid 신호 
always @(posedge clk or negedge clk) begin
    if(!reset) begin
        r_valid <= 3'b0;
    end
    else begin
        r_valid <= {r_valid[1:0],i_valid}; //시프트 동작을 한다. 총 3사이클 밀림.
    end
    end

// 곱셍승 동시에 움직이는 파이프라인.
always@(posedge clk or negedge reset) begin
    if(!reset) begin
    r_project2 = 64b'0;
    r_project4 = 64b'0;
    r_project8 = 64b'0;
    end
    else begin
    r_project2 = project2;
    r_project4 = project4;
    r_project8 = project8; 
    end
end
 
assign project2 = i_data*i_data;
assign project4 = project2*project2;
assign project8 = project4*project4;
assign o_valid = r_valid[2];
assign o_data = r_project8;
endmodule