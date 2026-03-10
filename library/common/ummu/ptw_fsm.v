module ptw_fsm (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         start,
  input  wire [31:0]  miss_vaddr,
  input  wire [31:0]  satb_in,

  output reg          busy,
  output reg          done,
  output reg          page_fault,
  output reg  [19:0]  done_vpn,
  output reg  [21:0]  done_ppn,
  output reg  [11:0]  done_attr,

  output reg  [31:0]  m_axi_araddr,
  output reg  [7:0]   m_axi_arlen,
  output reg  [2:0]   m_axi_arsize,
  output reg  [1:0]   m_axi_arburst,
  output reg          m_axi_arvalid,
  input  wire         m_axi_arready,

  input  wire [31:0]  m_axi_rdata,
  input  wire [1:0]   m_axi_rresp,
  input  wire         m_axi_rlast,
  input  wire         m_axi_rvalid,
  output reg          m_axi_rready
);

localparam [2:0]
  S_IDLE       = 3'd0,
  S_REQ_L1     = 3'd1,
  S_WAIT_L1    = 3'd2,
  S_REQ_L2     = 3'd3,
  S_WAIT_L2    = 3'd4,
  S_DONE       = 3'd5,
  S_PAGE_FAULT = 3'd6;

reg [2:0] state;
reg [31:0] vaddr_q;
reg [31:0] pte1_q;
reg [31:0] pte2_q;
reg [31:0] l1_pte_addr;
reg [31:0] l2_pte_addr;

wire [9:0] vpn1 = vaddr_q[31:22];
wire [9:0] vpn0 = vaddr_q[21:12];

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state          <= S_IDLE;
    busy           <= 1'b0;
    done           <= 1'b0;
    page_fault     <= 1'b0;
    done_vpn       <= 20'd0;
    done_ppn       <= 22'd0;
    done_attr      <= 12'd0;
    vaddr_q        <= 32'd0;
    pte1_q         <= 32'd0;
    pte2_q         <= 32'd0;
    l1_pte_addr    <= 32'd0;
    l2_pte_addr    <= 32'd0;
    m_axi_araddr   <= 32'd0;
    m_axi_arlen    <= 8'd0;
    m_axi_arsize   <= 3'b010; // 4-byte beat
    m_axi_arburst  <= 2'b01;  // INCR
    m_axi_arvalid  <= 1'b0;
    m_axi_rready   <= 1'b0;
  end else begin
    done       <= 1'b0;
    page_fault <= 1'b0;

    case (state)
      // IDLE: wait for a new miss request from top-level uMMU
      S_IDLE: begin
        busy         <= 1'b0;
        m_axi_arvalid <= 1'b0;
        m_axi_rready  <= 1'b0;

        if (start) begin
          busy        <= 1'b1;
          vaddr_q     <= miss_vaddr;
          l1_pte_addr <= {satb_in[31:12], 12'b0} + {20'd0, miss_vaddr[31:22], 2'b00};
          state       <= S_REQ_L1;
        end
      end

      // REQ_L1: issue AXI AR for level-1 PTE
      S_REQ_L1: begin
        m_axi_araddr  <= l1_pte_addr;
        m_axi_arvalid <= 1'b1;
        if (m_axi_arvalid && m_axi_arready) begin
          m_axi_arvalid <= 1'b0;
          m_axi_rready  <= 1'b1;
          state         <= S_WAIT_L1;
        end
      end

      // WAIT_L1: wait AXI R for level-1 PTE, then check PTE_V
      S_WAIT_L1: begin
        if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
          pte1_q       <= m_axi_rdata;
          m_axi_rready <= 1'b0;

          if ((m_axi_rresp != 2'b00) || !m_axi_rdata[0]) begin
            state <= S_PAGE_FAULT;
          end else begin
            l2_pte_addr <= {m_axi_rdata[31:10], 12'b0} + {20'd0, vpn0, 2'b00};
            state <= S_REQ_L2;
          end
        end
      end

      // REQ_L2: issue AXI AR for level-2 PTE
      S_REQ_L2: begin
        m_axi_araddr  <= l2_pte_addr;
        m_axi_arvalid <= 1'b1;
        if (m_axi_arvalid && m_axi_arready) begin
          m_axi_arvalid <= 1'b0;
          m_axi_rready  <= 1'b1;
          state         <= S_WAIT_L2;
        end
      end

      // WAIT_L2: wait AXI R for level-2 PTE, then check PTE_V
      S_WAIT_L2: begin
        if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
          pte2_q       <= m_axi_rdata;
          m_axi_rready <= 1'b0;

          if ((m_axi_rresp != 2'b00) || !m_axi_rdata[0]) begin
            state <= S_PAGE_FAULT;
          end else begin
            done_vpn  <= vaddr_q[31:12];
            done_ppn  <= m_axi_rdata[31:10];
            done_attr <= m_axi_rdata[11:0];
            state     <= S_DONE;
          end
        end
      end

      // DONE: translation completed successfully (1-cycle pulse)
      S_DONE: begin
        done <= 1'b1;
        busy <= 1'b0;
        state <= S_IDLE;
      end

      // PAGE_FAULT: invalid PTE or AXI error (1-cycle pulse)
      S_PAGE_FAULT: begin
        page_fault <= 1'b1;
        busy <= 1'b0;
        state <= S_IDLE;
      end

      default: begin
        state <= S_IDLE;
      end
    endcase
  end
end

endmodule
