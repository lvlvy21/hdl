module ummu (
  input  wire         clk,
  input  wire         rst_n,

  // Upstream (IP Core)
  input  wire [31:0]  v_addr_in,
  input  wire         v_addr_vld,
  output wire [31:0]  p_addr_out,
  output wire         mmu_stall,
  output reg          page_fault,

  // Control (CSR)
  input  wire [31:0]  satb_in,
  input  wire         tlb_flush,

  // AXI4 Master Read Channels (for PTW)
  output wire [31:0]  m_axi_araddr,
  output wire [7:0]   m_axi_arlen,
  output wire [2:0]   m_axi_arsize,
  output wire [1:0]   m_axi_arburst,
  output wire         m_axi_arvalid,
  input  wire         m_axi_arready,

  input  wire [31:0]  m_axi_rdata,
  input  wire [1:0]   m_axi_rresp,
  input  wire         m_axi_rlast,
  input  wire         m_axi_rvalid,
  output wire         m_axi_rready
);

localparam integer ENTRY_NUM = 32;

wire [ENTRY_NUM*20-1:0] tlb_tag_bus;
wire [ENTRY_NUM-1:0]    tlb_valid_bus;
wire                    tlb_hit;
wire [$clog2(ENTRY_NUM)-1:0] tlb_hit_idx;
wire [21:0]             tlb_hit_ppn;
wire                    tlb_hit_valid;

wire ptw_busy;
wire ptw_done;
wire ptw_fault;
wire [19:0] ptw_done_vpn;
wire [21:0] ptw_done_ppn;
wire [11:0] ptw_done_attr;

wire ptw_start;
reg [$clog2(ENTRY_NUM)-1:0] rr_ptr;
reg  tlb_wr_en;

assign ptw_start = v_addr_vld && !tlb_hit && !ptw_busy;
assign mmu_stall = (v_addr_vld && !tlb_hit) || ptw_busy;
assign p_addr_out = (v_addr_vld && tlb_hit && tlb_hit_valid) ? {tlb_hit_ppn, v_addr_in[11:0]} : 32'd0;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    rr_ptr <= {($clog2(ENTRY_NUM)){1'b0}};
    tlb_wr_en <= 1'b0;
    page_fault <= 1'b0;
  end else begin
    tlb_wr_en <= 1'b0;
    page_fault <= 1'b0;

    if (ptw_done) begin
      tlb_wr_en <= 1'b1;
      rr_ptr <= rr_ptr + 1'b1; // Round-robin replacement
    end

    if (ptw_fault) begin
      page_fault <= 1'b1;
    end
  end
end

tlb_data_ram #(
  .ENTRY_NUM(ENTRY_NUM)
) u_tlb_data_ram (
  .clk(clk),
  .rst_n(rst_n),
  .flush(tlb_flush),
  .wr_en(tlb_wr_en),
  .wr_idx(rr_ptr),
  .wr_vpn(ptw_done_vpn),
  .wr_ppn(ptw_done_ppn),
  .wr_attr(ptw_done_attr),
  .rd_idx(tlb_hit_idx),
  .rd_vpn(),
  .rd_ppn(tlb_hit_ppn),
  .rd_attr(),
  .rd_valid(tlb_hit_valid),
  .tag_bus(tlb_tag_bus),
  .valid_bus(tlb_valid_bus)
);

tlb_tag_cam #(
  .ENTRY_NUM(ENTRY_NUM)
) u_tlb_tag_cam (
  .lookup_vpn(v_addr_in[31:12]),
  .lookup_en(v_addr_vld),
  .tag_bus(tlb_tag_bus),
  .valid_bus(tlb_valid_bus),
  .hit(tlb_hit),
  .hit_idx(tlb_hit_idx)
);

ptw_fsm u_ptw_fsm (
  .clk(clk),
  .rst_n(rst_n),
  .start(ptw_start),
  .miss_vaddr(v_addr_in),
  .satb_in(satb_in),
  .busy(ptw_busy),
  .done(ptw_done),
  .page_fault(ptw_fault),
  .done_vpn(ptw_done_vpn),
  .done_ppn(ptw_done_ppn),
  .done_attr(ptw_done_attr),
  .m_axi_araddr(m_axi_araddr),
  .m_axi_arlen(m_axi_arlen),
  .m_axi_arsize(m_axi_arsize),
  .m_axi_arburst(m_axi_arburst),
  .m_axi_arvalid(m_axi_arvalid),
  .m_axi_arready(m_axi_arready),
  .m_axi_rdata(m_axi_rdata),
  .m_axi_rresp(m_axi_rresp),
  .m_axi_rlast(m_axi_rlast),
  .m_axi_rvalid(m_axi_rvalid),
  .m_axi_rready(m_axi_rready)
);

endmodule
