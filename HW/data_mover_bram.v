//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// Create Date: 2021.01.31
// Design Name: 
// Module Name: data_mover_bram
// Project Name:
// Target Devices:
// Tool Versions:
// Description: To study ctrl sram. (WRITE / READ)
//            FSM + mem I/F
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
 
`timescale 1ns / 1ps
module data_mover_bram
// Param
#(
   parameter CNT_BIT = 31,
// BRAM
   parameter DWIDTH = 32,
   parameter AWIDTH = 12,
   parameter MEM_SIZE = 2048,
   parameter IN_DATA_WITDH = 8,
   
   parameter MATRIX_SIZE = 128,
   parameter BLOCK_SIZE = 16
)

(
    input                    clk,
    input                    reset_n,
    input                    i_run,
    input  [CNT_BIT-1:0]     i_num_cnt,
    output                   o_idle,
    output                   o_read,
    output                   o_write,
    output                   o_done,

// Memory I/F (Read from bram0)
   output[AWIDTH-1:0]    addr_b0,
   output             ce_b0,
   output             we_b0,
   input [DWIDTH-1:0]  q_b0,
   output[DWIDTH-1:0]    d_b0,

// Memory I/F (Write to bram1)
   output[AWIDTH-1:0]    addr_b1,
   output             ce_b1,
   output             we_b1,
   input [DWIDTH-1:0]  q_b1,
   output[DWIDTH-1:0]    d_b1
    );

/////// Local Param. to define state (원본)////////
localparam S_IDLE   = 2'b00;
localparam S_RUN   = 2'b01;
localparam S_DONE     = 2'b10;

localparam ADDR_MATRIX_SIZE = MATRIX_SIZE * MATRIX_SIZE / 4;
localparam ADDR_BLOCK_SIZE = BLOCK_SIZE * BLOCK_SIZE / 4;
localparam MATRIX_BLOCK = MATRIX_SIZE / BLOCK_SIZE;

localparam BLOCK_NUM = MATRIX_SIZE / BLOCK_SIZE;

/////// Type ////////
reg [1:0] c_state_read; // Current state  (F/F)  = state
reg [1:0] n_state_read; // Next state (Variable in Combinational Logic) 
reg [1:0] c_state_write; // Current state  (F/F)
reg [1:0] n_state_write; // Next state (Variable in Combinational Logic)
wire     is_write_done;
wire     is_read_done;

/////// Main ////////

// Step 1. always block to update state 
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      c_state_read <= S_IDLE;
    end else begin
      c_state_read <= n_state_read;
    end
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      c_state_write <= S_IDLE;
    end else begin
      c_state_write <= n_state_write;
    end
end

// Step 2. always block to compute n_state_read
//always @(c_state_read or i_run or is_done) 
always @(*) 
begin
   n_state_read = c_state_read; // To prevent Latch.
   case(c_state_read)
   S_IDLE   : if(i_run)
            n_state_read = S_RUN;
   S_RUN   : if(is_read_done)
            n_state_read = S_DONE;
   S_DONE   : n_state_read     = S_IDLE;
   endcase
end 

always @(*) 
begin
   n_state_write = c_state_write; // To prevent Latch.
   case(c_state_write)
   S_IDLE   : if(i_run)
            n_state_write = S_RUN;
   S_RUN   : if(is_write_done)
            n_state_write = S_DONE;
   S_DONE   : n_state_write = S_IDLE;
   endcase
end 

// Step 3.  always block to compute output
// Added to communicate with control signals.
assign o_idle       = (c_state_read == S_IDLE) && (c_state_write == S_IDLE);
assign o_read       = (c_state_read == S_RUN);
assign o_write       = (c_state_write == S_RUN);
assign o_done       = (c_state_write == S_DONE); // The write state is slower than the read state.

// Step 4. Registering (Capture) number of Count
reg [CNT_BIT-1:0] num_cnt;
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        num_cnt <= 0;
    end else if (i_run) begin
        num_cnt <= i_num_cnt;
   end else if (o_done) begin
        num_cnt <= 0;
   end
end

// Step 5. increased addr_cnt
reg [CNT_BIT-1:0] addr_cnt_read;  
reg [CNT_BIT-1:0] addr_cnt_write;

reg success;
assign is_read_done  = o_read  && (success == 1); // 수정
assign is_write_done = o_write && (addr_cnt_write == num_cnt-1);

reg [CNT_BIT-1:0] addr_cnt_read_B;
reg [CNT_BIT-1:0] addr_cnt; // 수정
integer i, j, k;
reg [2:0] valid_state;
reg [1:0] addr_state;

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        addr_cnt_read <= 0; 
        addr_cnt <= 0;
        addr_cnt_read_B <= ADDR_MATRIX_SIZE;
        i <= 0;
        j <= 0;
        k <= 0;
        success <= 0;
        addr_state <= 2'b0;
        valid_state <= 3'b0;
    end else if (is_read_done) begin
        addr_cnt_read <= 0; 
    end else if (o_read) begin
        case(addr_state)
        2'b00: begin
            addr_cnt_read <= i * ADDR_BLOCK_SIZE * MATRIX_BLOCK + k * ADDR_BLOCK_SIZE + addr_cnt;
            addr_cnt = (addr_cnt + 1) & (ADDR_BLOCK_SIZE - 1);
            if (!addr_cnt) begin
                addr_state <= 2'b01;
            end
        end 
        2'b01: begin
            addr_cnt_read = addr_cnt_read_B + k * ADDR_BLOCK_SIZE * MATRIX_BLOCK + j * ADDR_BLOCK_SIZE + addr_cnt;
            addr_cnt = (addr_cnt + 1) & (ADDR_BLOCK_SIZE - 1);
            if (!addr_cnt) begin
                valid_state = (valid_state + 1) & 7;
                if(!valid_state) begin
                    addr_state <= 2'b10;
                end
                else begin
                    addr_state <= 2'b0;
                end
                k = (k + 1) & (MATRIX_BLOCK-1);
                if(!k) begin
                    j = (j + 1) & (MATRIX_BLOCK-1);
                    if(!j) begin
                        i = (i + 1) & (MATRIX_BLOCK-1);
                        if(!i) begin
                            success = 1;
                        end
                    end
                end
            end
        end
        2'b10: begin
            if(go_signal) 
                addr_state <= 2'b00;
        end
        default: begin
            //None
        end
        endcase
    end
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        addr_cnt_write <= 0;  
    end else if (is_write_done) begin
        addr_cnt_write <= 0; 
    end else if (o_write && we_b1) begin  // core delay
        addr_cnt_write <= addr_cnt_write + 1;
   end
end

// Step 6. Read Data from BRAM0
// Assign Memory I/F. Read from BRAM0
assign addr_b0    = addr_cnt_read;
assign ce_b0    = o_read;
assign we_b0    = 1'b0; // read only
assign d_b0      = {DWIDTH{1'b0}}; // no use

reg             r_valid1, r_valid2, r_valid3, r_valid4, r_valid5, r_valid6, r_valid7, r_valid8;
reg  [4:0]           delay;
wire [DWIDTH-1:0]    mem_data;

// 1 cycle latency to sync mem output
reg [2:0] prev_valid_state; // 이전 valid_state 저장 레지스터

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        r_valid1 <= 1'b0;
        r_valid2 <= 1'b0;
        r_valid3 <= 1'b0;
        r_valid4 <= 1'b0;
        r_valid5 <= 1'b0;
        r_valid6 <= 1'b0;
        r_valid7 <= 1'b0;
        r_valid8 <= 1'b0;
        delay    <= 3;           
        prev_valid_state <= 3'b000; 
    end else begin
        if (valid_state != prev_valid_state) begin
            delay <= 1;            
            prev_valid_state <= valid_state; 
        
        end else if (delay) begin
            delay <= delay - 1;    
        
        end else begin
            case (valid_state)
                3'b000: 
                    r_valid1 <= o_read; // read data 

                3'b001: 
                    r_valid2 <= o_read;  
                  
                3'b010: 
                    r_valid3 <= o_read;

                3'b011: 
                    r_valid4 <= o_read;

                3'b100: 
                    r_valid5 <= o_read;

                3'b101: 
                    r_valid6 <= o_read;

                3'b110: 
                    r_valid7 <= o_read;

                3'b111: 
                    r_valid8 <= o_read;
            endcase
        end
    end
end


assign mem_data = q_b0;

wire   [(2*IN_DATA_WITDH)-1:0] w_result0, w_result1,w_result2, w_result3, w_result4, w_result5, w_result6, w_result7, w_result8,
                               w_result9, w_result10, w_result11, w_result12, w_result13, w_result14, w_result15;
wire   w_valid1, w_valid2, w_valid3, w_valid4, w_valid5, w_valid6, w_valid7, w_valid8;

                      
go_matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix1(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid1    ),
   .data       (mem_data),
   .go_signal   (go_signal), 
   .o_result0   (w_result0   ),
   .o_result1   (w_result1   ),
   .o_valid   (w_valid1   ) // port_name(signal_name)
);

matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix2(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid2    ),
   .data       (mem_data), 
   .o_result0   (w_result2   ),
   .o_result1   (w_result3   ),
   .o_valid   (w_valid2   ) // port_name(signal_name)
);

matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix3(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid3   ),
   .data       (mem_data),
   .o_result0   (w_result4   ),
   .o_result1   (w_result5   ),
   .o_valid   (w_valid3   ) // port_name(signal_name)
);

matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix4(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid4    ),
   .data       (mem_data), 
   .o_result0   (w_result6   ),
   .o_result1   (w_result7   ),
   .o_valid   (w_valid4   ) // port_name(signal_name)
);

matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix5(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid5    ),
   .data       (mem_data), 
   .o_result0   (w_result8   ),
   .o_result1   (w_result9   ),
   .o_valid   (w_valid5   ) // port_name(signal_name)
);

matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix6(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid6    ),
   .data       (mem_data), 
   .o_result0   (w_result10   ),
   .o_result1   (w_result11   ),
   .o_valid   (w_valid6   ) // port_name(signal_name)
);

matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix7(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid7    ),
   .data       (mem_data), 
   .o_result0   (w_result12   ),
   .o_result1   (w_result13  ),
   .o_valid   (w_valid7   ) // port_name(signal_name)
);

stop_matrix_core
// Param
#(
   .IN_DATA_WITDH (IN_DATA_WITDH),
   .MATRIX_SIZE(),
   .BLOCK_SIZE(),
   .INDEX_MATRIX_SIZE(),
   .INDEX_BLOCK_SIZE()
)

    matrix8(
    .clk      (clk       ),
    .reset_n   (reset_n    ),
   .i_valid   (r_valid8    ),
   .data       (mem_data),
   .o_result0   (w_result14   ),
   .o_result1   (w_result15   ),
   .o_valid   (w_valid8   ) // port_name(signal_name)
);

reg [(2*IN_DATA_WITDH)-1:0] C[BLOCK_SIZE-1:0][BLOCK_SIZE-1:0];
integer     ii, jj;
wire [(2*IN_DATA_WITDH)-1:0] result0 = (w_valid1) ? w_result0 :
                                       (w_valid2) ? w_result2 :
                                       (w_valid3) ? w_result4 :
                                       (w_valid4) ? w_result6 :
                                       (w_valid5) ? w_result8 :
                                       (w_valid6) ? w_result10 :
                                       (w_valid7) ? w_result12 :
                                       (w_valid8) ? w_result14 : 1'b0;
wire [(2*IN_DATA_WITDH)-1:0] result1 = (w_valid1) ? w_result1 :
                                       (w_valid2) ? w_result3 :
                                       (w_valid3) ? w_result5 :
                                       (w_valid4) ? w_result7 :
                                       (w_valid5) ? w_result9 :
                                       (w_valid6) ? w_result11 :
                                       (w_valid7) ? w_result13 :
                                       (w_valid8) ? w_result15 : 1'b0;
reg                 result_valid;
reg     [7:0]       block_cnt;
reg     [31:0]      result_value;
reg     w_ready;
reg     w_ready_done;
reg     [1:0] write_state;

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        w_ready <= 0;
    end else begin
       w_ready <= w_valid1 | w_valid2 | w_valid3 | w_valid4 | w_valid5 | w_valid6 | w_valid7 | w_valid8;
    end
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        ii <= 0;
        jj <= 0;
        write_state <= 0;
        block_cnt <= 0;
    end else begin
        case(write_state)
            2'b00: begin
                C[ii][jj]   <= 0;
                C[ii][jj+1] <= 0;
                jj = (jj + 2) & (BLOCK_SIZE - 1);
                if(!jj) begin
                    ii = (ii + 1) & (BLOCK_SIZE-1);
                    if(!ii) begin
                       write_state <= 2'b01;
                    end
                end
            end
        2'b01: begin
            if(w_ready) begin
                C[ii][jj]     <= w_result0 + C[ii][jj];
                C[ii][jj+1]   <= w_result1 + C[ii][jj+1];
        
                jj = (jj + 2) & (BLOCK_SIZE - 1);
                if(!jj) begin
                    ii = (ii + 1) & (BLOCK_SIZE-1);
                    if(!ii) begin
                        block_cnt = block_cnt + 1;
                        if(block_cnt == BLOCK_NUM) begin
                            block_cnt = 0;
                            write_state <= 2'b10;
                        end
                    end
                end
            end
        end
        2'b10: begin
            result_valid = 1'b1;
            result_value = {C[ii][jj], C[ii][jj+1]};
    
            jj = (jj + 2) & (BLOCK_SIZE - 1);
            if(!jj) begin
                ii = (ii + 1) & (BLOCK_SIZE-1);
                if(!ii) begin
                    result_valid = 1'b0;
                    write_state <= 2'b0;
                end
            end
        end
    endcase
    end
end

// Step 8. Write Data to BRAM1
assign addr_b1      = addr_cnt_write;
assign ce_b1        = result_valid;
assign we_b1        = result_valid;
assign d_b1         = result_value;

//assign q_b1; // no use

endmodule