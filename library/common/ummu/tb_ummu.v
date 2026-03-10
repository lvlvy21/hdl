`timescale 1ns/1ps

module tb_ummu;

reg         clk;
reg         rst_n;
reg  [31:0] v_addr_in;
reg         v_addr_vld;
wire [31:0] p_addr_out;
wire        mmu_stall;
wire        page_fault;
reg  [31:0] satb_in;
reg         tlb_flush;

wire [31:0] m_axi_araddr;
wire [7:0]  m_axi_arlen;
wire [2:0]  m_axi_arsize;
wire [1:0]  m_axi_arburst;
wire        m_axi_arvalid;
reg         m_axi_arready;
reg  [31:0] m_axi_rdata;
reg  [1:0]  m_axi_rresp;
reg         m_axi_rlast;
reg         m_axi_rvalid;
wire        m_axi_rready;

localparam [31:0] TEST_VADDR = 32'h1234_5000;
localparam [31:0] SATB_ROOT  = 32'h0001_0000;

localparam [31:0] VPN1 = (TEST_VADDR[31:22]);
localparam [31:0] VPN0 = (TEST_VADDR[21:12]);
localparam [31:0] L1_PTE_ADDR = SATB_ROOT + (VPN1 << 2);
localparam [31:0] L2_BASE     = 32'h0002_0000;
localparam [31:0] L2_PTE_ADDR = L2_BASE + (VPN0 << 2);

localparam [21:0] L2_BASE_PPN = (L2_BASE >> 12);
localparam [31:0] PTE1_DATA    = {L2_BASE_PPN, 10'b0} | 32'h1;

localparam [21:0] MAP_PPN      = 22'h00234;
localparam [31:0] PTE2_DATA    = {MAP_PPN, 10'b0} | 32'h1;
localparam [31:0] EXPECT_PADDR = {MAP_PPN, TEST_VADDR[11:0]};

ummu dut (
  .clk(clk),
  .rst_n(rst_n),
  .v_addr_in(v_addr_in),
  .v_addr_vld(v_addr_vld),
  .p_addr_out(p_addr_out),
  .mmu_stall(mmu_stall),
  .page_fault(page_fault),
  .satb_in(satb_in),
  .tlb_flush(tlb_flush),
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

always #5 clk = ~clk;

reg [31:0] pending_araddr;
reg [1:0]  resp_delay;
reg        has_pending;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    m_axi_arready  <= 1'b1;
    m_axi_rvalid   <= 1'b0;
    m_axi_rdata    <= 32'd0;
    m_axi_rresp    <= 2'b00;
    m_axi_rlast    <= 1'b1;
    pending_araddr <= 32'd0;
    resp_delay     <= 2'd0;
    has_pending    <= 1'b0;
  end else begin
    if (m_axi_arvalid && m_axi_arready) begin
      pending_araddr <= m_axi_araddr;
      resp_delay <= 2'd2; // emulate bus latency
      has_pending <= 1'b1;
    end

    if (has_pending && (resp_delay != 0)) begin
      resp_delay <= resp_delay - 1'b1;
    end

    if (has_pending && (resp_delay == 1)) begin
      m_axi_rvalid <= 1'b1;
      m_axi_rresp  <= 2'b00;
      if (pending_araddr == L1_PTE_ADDR) begin
        m_axi_rdata <= PTE1_DATA;
      end else if (pending_araddr == L2_PTE_ADDR) begin
        m_axi_rdata <= PTE2_DATA;
      end else begin
        m_axi_rdata <= 32'd0;
      end
    end

    if (m_axi_rvalid && m_axi_rready) begin
      m_axi_rvalid <= 1'b0;
      has_pending  <= 1'b0;
    end
  end
end

initial begin
  clk = 1'b0;
  rst_n = 1'b0;
  v_addr_in = 32'd0;
  v_addr_vld = 1'b0;
  satb_in = SATB_ROOT;
  tlb_flush = 1'b0;

  repeat (4) @(posedge clk);
  rst_n = 1'b1;

  // 1) First access -> expected TLB miss, PTW starts and mmu_stall is asserted
  @(posedge clk);
  v_addr_in  <= TEST_VADDR;
  v_addr_vld <= 1'b1;

  while (mmu_stall) begin
    @(posedge clk);
  end

  // 2) Re-issue same VA -> should hit in TLB (no stall), and PA should be translated
  @(posedge clk);
  v_addr_in  <= TEST_VADDR;
  v_addr_vld <= 1'b1;
  @(posedge clk);

  if (p_addr_out !== EXPECT_PADDR) begin
    $display("ERROR: TLB hit translation mismatch. got=0x%08x exp=0x%08x", p_addr_out, EXPECT_PADDR);
    $finish;
  end

  if (page_fault) begin
    $display("ERROR: unexpected page_fault asserted");
    $finish;
  end

  $display("PASS: PTW handled miss and TLB hit returns PA=0x%08x", p_addr_out);
  $finish;
end

endmodule
