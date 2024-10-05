//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// Create Date:
// Design Name: 
// Module Name: tb_data_mover_bram
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Verifify module data_mover_bram
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

`define CNT_BIT 31
`define ADDR_WIDTH 21
`define DATA_WIDTH 32
`define MEM_DEPTH 8192
`define IN_DATA_WITDH 8
`define NUM_CORE 2


module tb_data_mover_bram;
reg clk , reset_n;
reg 					i_run;
reg  [`CNT_BIT-1:0]	i_num_cnt;
wire 					o_idle;
wire 					o_write;
wire 					o_read;
wire 					o_done;
 
// Memory I/F
wire [`ADDR_WIDTH-1:0] 	addr0_b0;
wire  					ce0_b0;
wire  					we0_b0;
wire [`DATA_WIDTH-1:0]  q0_b0;
wire [`DATA_WIDTH-1:0] 	d0_b0;

wire [`ADDR_WIDTH-1:0] 	addr0_b1;
wire  					ce0_b1;
wire  					we0_b1;
wire [`DATA_WIDTH-1:0]  q0_b1;
wire [`DATA_WIDTH-1:0] 	d0_b1;

// Write BRAM 0
reg [`ADDR_WIDTH-1:0] 	addr1_b0;
reg  					ce1_b0	;
reg  					we1_b0	;
wire [`DATA_WIDTH-1:0]  q1_b0	;
reg [`DATA_WIDTH-1:0] 	d1_b0	;

reg [`IN_DATA_WITDH-1:0]  a_0;
reg [`IN_DATA_WITDH-1:0]  b_0;
reg [`IN_DATA_WITDH-1:0]  a_1;
reg [`IN_DATA_WITDH-1:0]  b_1;

reg [`IN_DATA_WITDH-1:0]  a_2;
reg [`IN_DATA_WITDH-1:0]  b_2;
reg [`IN_DATA_WITDH-1:0]  a_3;
reg [`IN_DATA_WITDH-1:0]  b_3;

// Read BRAM 1
reg [`ADDR_WIDTH-1:0] 	addr1_b1;
reg  					ce1_b1	;
reg  					we1_b1	;
wire [`DATA_WIDTH-1:0]  q1_b1	;
reg [`DATA_WIDTH-1:0] 	d1_b1	;


// clk gen
always
    #5 clk = ~clk;

integer i,f_in, f_ot, status;
reg [(`DATA_WIDTH/`NUM_CORE)-1 :0] result_rtl_0;
reg [(`DATA_WIDTH/`NUM_CORE)-1 :0] result_rtl_1;


initial begin
//initialize value
$display("initialize value [%0d]", $time);
    reset_n <= 1;
    clk     <= 0;
	i_run 	<= 0;
	i_num_cnt <= `MEM_DEPTH;
	addr1_b0 <= 0;
	ce1_b0	 <= 0;
	we1_b0	 <= 0;
	d1_b0	 <= 0;
	addr1_b1 <= 0;
	ce1_b1	 <= 0;
	we1_b1	 <= 0;
	d1_b1	 <= 0;
// reset_n gen
$display("Reset! [%0d]", $time);
# 100
    reset_n <= 0;
# 10
    reset_n <= 1;
@(posedge clk);

$display("Step 1. Mem write to Bram0 [%0d]", $time);
for(i = 0; i < i_num_cnt / 2; i = i + 1) begin
	a_0 = i & 8'b01111111;
	a_1 = i & 8'b01111111;
	a_2 = i & 8'b01111111;
	a_3 = i & 8'b01111111;
	u_TDPBRAM_0.ram[i] <= {a_0, a_1, a_2, a_3};
end

for(i = i_num_cnt / 2; i < i_num_cnt; i = i + 1) begin
	b_0 = i & 8'b01111111;
	b_1 = i & 8'b01111111;
	b_2 = i & 8'b01111111;
	b_3 = i & 8'b01111111;
	u_TDPBRAM_0.ram[i] <= {b_0, b_1, b_2, b_3};
end

$display("Step 2. Check Idle [%0d]", $time);
wait(o_idle);

$display("Step 3. Start! data_mover_bram [%0d]", $time);
	i_run <= 1;
@(posedge clk);
	i_run <= 0;

$display("Step 4. Wait Done [%0d]", $time);
wait(o_done);

$display("Step 5. Mem Read from Bram1 [%0d]", $time);
// TODO Check to compare result
for(i = 0; i < i_num_cnt; i = i + 1) begin
	{result_rtl_0, result_rtl_1} <= u_TDPBRAM_1.ram[i];
end

//$fclose(f_in);
$fclose(f_ot);
# 100
$display("Success Simulation!! (Matbi = gudok & joayo) [%0d]", $time);
$finish;
end

// Call DUT
data_mover_bram 
#(	
	.CNT_BIT  (`CNT_BIT),
	.DWIDTH   (`DATA_WIDTH), 
	.AWIDTH   (`ADDR_WIDTH), 
	.MEM_SIZE (`MEM_DEPTH),
	.IN_DATA_WITDH (`IN_DATA_WITDH))
u_data_mover_bram (
    .clk			(clk		),
    .reset_n		(reset_n	),
	.i_run			(i_run		),
	.i_num_cnt		(i_num_cnt	),
	.o_idle			(o_idle		),
	.o_read			(o_read		),
	.o_write		(o_write	),
	.o_done			(o_done		),
                            	
	.addr_b0		(addr0_b0	),
	.ce_b0			(ce0_b0		),
	.we_b0			(we0_b0		),
	.q_b0			(q0_b0		),
	.d_b0			(d0_b0		),
                            	
	.addr_b1		(addr0_b1	),
	.ce_b1			(ce0_b1		),
	.we_b1			(we0_b1		),
	.q_b1			(q0_b1		),
	.d_b1			(d0_b1		)
    );

true_dpbram 
#(	.DWIDTH   (`DATA_WIDTH), 
	.AWIDTH   (`ADDR_WIDTH), 
	.MEM_SIZE (`MEM_DEPTH)) 
u_TDPBRAM_0(
	.clk		(clk), 

	.addr0		(addr0_b0), 
	.ce0		(ce0_b0), 
	.we0		(we0_b0), 
	.q0			(q0_b0), 
	.d0			(d0_b0), 

// no use port B. Use in TB
	.addr1 		(addr1_b0), 
	.ce1		(ce1_b0	), 
	.we1		(we1_b0	),
	.q1			(q1_b0	), 
	.d1			(d1_b0	)
);

true_dpbram 
#(	.DWIDTH   (`DATA_WIDTH), 
	.AWIDTH   (`ADDR_WIDTH), 
	.MEM_SIZE (`MEM_DEPTH)) 
u_TDPBRAM_1(
	.clk		(clk), 

	.addr0		(addr0_b1), 
	.ce0		(ce0_b1), 
	.we0		(we0_b1), 
	.q0			(q0_b1), 
	.d0			(d0_b1), 

// no use port B. Use in TB
	.addr1 		(addr1_b1), 
	.ce1		(ce1_b1	), 
	.we1		(we1_b1	),
	.q1			(q1_b1	), 
	.d1			(d1_b1	)
);

endmodule
