module tlb_data_ram #(
  parameter integer ENTRY_NUM = 32,
  parameter integer VPN_WIDTH = 20,
  parameter integer PPN_WIDTH = 22,
  parameter integer ATTR_WIDTH = 12
) (
  input  wire                                clk,
  input  wire                                rst_n,
  input  wire                                flush,
  input  wire                                wr_en,
  input  wire [$clog2(ENTRY_NUM)-1:0]        wr_idx,
  input  wire [VPN_WIDTH-1:0]                wr_vpn,
  input  wire [PPN_WIDTH-1:0]                wr_ppn,
  input  wire [ATTR_WIDTH-1:0]               wr_attr,

  input  wire [$clog2(ENTRY_NUM)-1:0]        rd_idx,
  output wire [VPN_WIDTH-1:0]                rd_vpn,
  output wire [PPN_WIDTH-1:0]                rd_ppn,
  output wire [ATTR_WIDTH-1:0]               rd_attr,
  output wire                                rd_valid,

  output wire [ENTRY_NUM*VPN_WIDTH-1:0]      tag_bus,
  output wire [ENTRY_NUM-1:0]                valid_bus
);

integer i;
reg [VPN_WIDTH-1:0]  tag_array [0:ENTRY_NUM-1];
reg [PPN_WIDTH-1:0]  ppn_array [0:ENTRY_NUM-1];
reg [ATTR_WIDTH-1:0] attr_array[0:ENTRY_NUM-1];
reg                  valid_array[0:ENTRY_NUM-1];

generate
  genvar g;
  for (g = 0; g < ENTRY_NUM; g = g + 1) begin : GEN_PACK
    assign tag_bus[g*VPN_WIDTH +: VPN_WIDTH] = tag_array[g];
    assign valid_bus[g] = valid_array[g];
  end
endgenerate

assign rd_vpn   = tag_array[rd_idx];
assign rd_ppn   = ppn_array[rd_idx];
assign rd_attr  = attr_array[rd_idx];
assign rd_valid = valid_array[rd_idx];

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    for (i = 0; i < ENTRY_NUM; i = i + 1) begin
      tag_array[i]   <= {VPN_WIDTH{1'b0}};
      ppn_array[i]   <= {PPN_WIDTH{1'b0}};
      attr_array[i]  <= {ATTR_WIDTH{1'b0}};
      valid_array[i] <= 1'b0;
    end
  end else if (flush) begin
    for (i = 0; i < ENTRY_NUM; i = i + 1) begin
      valid_array[i] <= 1'b0;
    end
  end else if (wr_en) begin
    tag_array[wr_idx]   <= wr_vpn;
    ppn_array[wr_idx]   <= wr_ppn;
    attr_array[wr_idx]  <= wr_attr;
    valid_array[wr_idx] <= 1'b1;
  end
end

endmodule
