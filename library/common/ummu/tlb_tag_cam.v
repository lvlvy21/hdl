module tlb_tag_cam #(
  parameter integer ENTRY_NUM = 32,
  parameter integer VPN_WIDTH = 20
) (
  input  wire [VPN_WIDTH-1:0]                lookup_vpn,
  input  wire                                lookup_en,
  input  wire [ENTRY_NUM*VPN_WIDTH-1:0]      tag_bus,
  input  wire [ENTRY_NUM-1:0]                valid_bus,
  output reg                                 hit,
  output reg [$clog2(ENTRY_NUM)-1:0]         hit_idx
);

integer i;
reg [VPN_WIDTH-1:0] tag_i;

always @(*) begin
  hit = 1'b0;
  hit_idx = {($clog2(ENTRY_NUM)){1'b0}};

  if (lookup_en) begin
    for (i = 0; i < ENTRY_NUM; i = i + 1) begin
      tag_i = tag_bus[i*VPN_WIDTH +: VPN_WIDTH];
      if (!hit && valid_bus[i] && (tag_i == lookup_vpn)) begin
        hit = 1'b1;
        hit_idx = i[$clog2(ENTRY_NUM)-1:0];
      end
    end
  end
end

endmodule
