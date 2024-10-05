`timescale 1ns / 1ps
module matrix_core
// Param
#(

    parameter IN_DATA_WITDH = 8, // 데이터 너비 8bit
    parameter  BLOCK_SIZE = 16,    // nxn Block matrix의 n
    parameter INDEX_BLOCK_SIZE = 15 

)

(
    input                                       clk,
    input                                       reset_n,
    input                                       i_valid,           //input data 유효 신호
    input       [IN_DATA_WITDH*4-1:0]           data,
    output                                      o_valid,    //결과 data 유효 신호
    output      [(2*IN_DATA_WITDH)-1:0]         o_result0,  //결과 data (곱셈 결과)
    output      [(2*IN_DATA_WITDH)-1:0]         o_result1 
);

reg                                         r_valid;                    //data_mover_bram로 갈 reg o_valid로 보냄
reg    [(2*IN_DATA_WITDH)-1:0]              r_result0;            //mul_core에서 곱한 결과
reg    [(2*IN_DATA_WITDH)-1:0]              r_result1;             

reg     [1:0]                               state;               //state machine 상태변수
reg     [IN_DATA_WITDH-1:0]                 A[INDEX_BLOCK_SIZE:0][INDEX_BLOCK_SIZE:0];
reg     [IN_DATA_WITDH-1:0]                 B[INDEX_BLOCK_SIZE:0][INDEX_BLOCK_SIZE:0];
reg     [(4 * IN_DATA_WITDH-1):0]           C[INDEX_BLOCK_SIZE:0][INDEX_BLOCK_SIZE:0];
integer                                     i,j,k;
// i: A & B matrix row index, j: A & B matrix column index, 
reg [15:0]  sum_result;

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_valid <= 1'b0;                            
        r_result0 <= {(2*IN_DATA_WITDH){1'b0}};
        r_result1 <= {(2*IN_DATA_WITDH){1'b0}};
        i <= 0;
        j <= 0;
        k <= 0;
        state <= 2'b00;
    end else if(i_valid) begin
        case(state)
            2'b00: begin
                if(i_valid) begin
                    A[i][j]     <= data[7:0];
                    A[i][j+1]   <= data[15:8];
                    A[i][j+2]   <= data[23:16];
                    A[i][j+3]   <= data[31:24];
                    C[i][j]     <= 0;
                    C[i][j + 1] <= 0;
                    C[i][j + 2] <= 0;
                    C[i][j + 3] <= 0;
                    j = (j + 4) & INDEX_BLOCK_SIZE;
                    if(!j) begin
                        i = (i + 1) & INDEX_BLOCK_SIZE;
                        if(!i) begin
                            state <= 2'b01;
                        end      
                    end
                end
            end
            2'b01: begin
                B[i][j]     <= data[7:0];
                B[i][j+1]   <= data[15:8];
                B[i][j+2]   <= data[23:16];
                B[i][j+3]   <= data[31:24];
                j = (j + 4) & INDEX_BLOCK_SIZE;
                if(!j) begin
                    i = (i + 1) & INDEX_BLOCK_SIZE;
                    if(!i) begin
                        state = 2'b10;
                    end        
                end
            end 
            2'b10: begin
                sum_result = A[i][k] * B[k][j];
                C[i][j] = sum_result  + C[i][j];
                k = (k + 1) & INDEX_BLOCK_SIZE;
                if(!k) begin
                    j = (j + 1) & INDEX_BLOCK_SIZE;
                    if(!j) begin
                        i = (i + 1) & INDEX_BLOCK_SIZE;
                        if(!i) begin
                            state <= 2'b11;
                        end
                    end
                end    
            end    
            2'b11: begin
                r_valid <= i_valid;
                r_result0 <= C[i][j];
                r_result1 <= C[i][j+1];

                j = (j + 2) & INDEX_BLOCK_SIZE;
                if(!j) begin
                    i = (i + 1) & INDEX_BLOCK_SIZE;
                    if(!i) begin
                        r_valid <= 1'b0;
                        state <= 2'b00;
                    end
                end
            end
        endcase
    end
end

assign o_valid   = r_valid;
assign o_result0 = r_result0;
assign o_result1 = r_result1;

endmodule