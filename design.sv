module FIFO (
input clk, wr, rd, reset, 
input [7:0] data_in,
output empty, full,
output [7:0] data_out,
output [15:0] count
);
    reg EMPTY, FULL;
    reg [7:0] DATA_OUT;
    reg [6:0] COUNT;
    reg [63:0][7:0] BUFFER;

    reg [5:0] TAIL, HEAD;

    always @(posedge clk) begin
        if (reset == 1'b1)
            begin
                EMPTY <= 1'b1;
                FULL <= 1'b0;
                COUNT <= 1'b0;
                DATA_OUT <= 1'b0;
                HEAD <= 0;
                TAIL <= 0;
            end
    end

    always @(posedge clk) begin
        if (!reset)
            if ((!FULL) && wr)
                begin
                  	EMPTY <= 1'b0;
                    BUFFER[HEAD] <= data_in;
                    HEAD <= HEAD + 1;
                    COUNT <= COUNT + 1;
                    if (COUNT == 63)
                        FULL <= 1'b1;
                    else
                        FULL <= 1'b0;
                end
    end

    always @(posedge clk) begin
        if (!reset)
            if ((!EMPTY) && rd)
                begin
                  	FULL <= 1'b0;
                    DATA_OUT <= BUFFER[TAIL];
                    TAIL <= TAIL + 1;
                    COUNT <= COUNT - 1;
                    if (COUNT == 1)
                        EMPTY <= 1'b1;
                    else
                        EMPTY <= 1'b0;
                  @(posedge clk)
                  	DATA_OUT <= 0;
                end
    end

    assign empty = EMPTY;
    assign full = FULL;
    assign data_out = DATA_OUT;
    assign count = COUNT;
endmodule