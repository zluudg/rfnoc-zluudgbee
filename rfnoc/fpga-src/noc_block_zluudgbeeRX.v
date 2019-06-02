
//
/* 
 * Copyright 2019 Leon Fernandez (zluudg).
 * 
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this software; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

//
module noc_block_zluudgbeeRX #(
  parameter NOC_ID = 64'h600DC0FFEE1571FE,
  parameter STR_SINK_FIFOSIZE = 11)
(
  input bus_clk, input bus_rst,
  input ce_clk, input ce_rst,
  input  [63:0] i_tdata, input  i_tlast, input  i_tvalid, output i_tready,
  output [63:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready,
  output [63:0] debug
);

  ////////////////////////////////////////////////////////////
  //
  // RFNoC Shell
  //
  ////////////////////////////////////////////////////////////
  wire [31:0] set_data;
  wire [7:0]  set_addr;
  wire        set_stb;
  reg  [63:0] rb_data;
  wire [7:0]  rb_addr;

  wire [63:0] cmdout_tdata, ackin_tdata;
  wire        cmdout_tlast, cmdout_tvalid, cmdout_tready, ackin_tlast, ackin_tvalid, ackin_tready;

  wire [63:0] str_sink_tdata, str_src_tdata;
  wire        str_sink_tlast, str_sink_tvalid, str_sink_tready, str_src_tlast, str_src_tvalid, str_src_tready;

  wire [15:0] src_sid;
  wire [15:0] next_dst_sid, resp_out_dst_sid;
  wire [15:0] resp_in_dst_sid;

  wire        clear_tx_seqnum;

  noc_shell #(
    .NOC_ID(NOC_ID),
    .STR_SINK_FIFOSIZE(STR_SINK_FIFOSIZE))
  noc_shell (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .i_tdata(i_tdata), .i_tlast(i_tlast), .i_tvalid(i_tvalid), .i_tready(i_tready),
    .o_tdata(o_tdata), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready),
    // Computer Engine Clock Domain
    .clk(ce_clk), .reset(ce_rst),
    // Control Sink
    .set_data(set_data), .set_addr(set_addr), .set_stb(set_stb), .set_time(), .set_has_time(),
    .rb_stb(1'b1), .rb_data(rb_data), .rb_addr(rb_addr),
    // Control Source
    .cmdout_tdata(cmdout_tdata), .cmdout_tlast(cmdout_tlast), .cmdout_tvalid(cmdout_tvalid), .cmdout_tready(cmdout_tready),
    .ackin_tdata(ackin_tdata), .ackin_tlast(ackin_tlast), .ackin_tvalid(ackin_tvalid), .ackin_tready(ackin_tready),
    // Stream Sink
    .str_sink_tdata(str_sink_tdata), .str_sink_tlast(str_sink_tlast), .str_sink_tvalid(str_sink_tvalid), .str_sink_tready(str_sink_tready),
    // Stream Source
    .str_src_tdata(str_src_tdata), .str_src_tlast(str_src_tlast), .str_src_tvalid(str_src_tvalid), .str_src_tready(str_src_tready),
    // Stream IDs set by host
    .src_sid(src_sid),                   // SID of this block
    .next_dst_sid(next_dst_sid),         // Next destination SID
    .resp_in_dst_sid(resp_in_dst_sid),   // Response destination SID for input stream responses / errors
    .resp_out_dst_sid(resp_out_dst_sid), // Response destination SID for output stream responses / errors
    // Misc
    .vita_time('d0), .clear_tx_seqnum(clear_tx_seqnum),
    .debug(debug));

  ////////////////////////////////////////////////////////////
  //
  // AXI Wrapper
  // Convert RFNoC Shell interface into AXI stream interface
  //
  ////////////////////////////////////////////////////////////
  wire [31:0]  m_axis_data_tdata;
  wire         m_axis_data_tlast;
  wire         m_axis_data_tvalid;
  wire         m_axis_data_tready;
  wire [127:0] m_axis_data_tuser;

  wire [31:0]  s_axis_data_tdata;
  wire         s_axis_data_tlast;
  wire         s_axis_data_tvalid;
  wire         s_axis_data_tready;
  wire [127:0] s_axis_data_tuser;

  axi_wrapper #(
    .SIMPLE_MODE(0))
  axi_wrapper (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .clk(ce_clk), .reset(ce_rst),
    .clear_tx_seqnum(clear_tx_seqnum),
    .next_dst(next_dst_sid),
    .set_stb(), .set_addr(), .set_data(),
    .i_tdata(str_sink_tdata), .i_tlast(str_sink_tlast), .i_tvalid(str_sink_tvalid), .i_tready(str_sink_tready),
    .o_tdata(str_src_tdata), .o_tlast(str_src_tlast), .o_tvalid(str_src_tvalid), .o_tready(str_src_tready),
    .m_axis_data_tdata(m_axis_data_tdata),
    .m_axis_data_tlast(m_axis_data_tlast),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tready(m_axis_data_tready),
    .m_axis_data_tuser(m_axis_data_tuser),
    .s_axis_data_tdata(s_axis_data_tdata),
    .s_axis_data_tlast(s_axis_data_tlast),
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tready(s_axis_data_tready),
    .s_axis_data_tuser(s_axis_data_tuser),
    .m_axis_config_tdata(),
    .m_axis_config_tlast(),
    .m_axis_config_tvalid(),
    .m_axis_config_tready(),
    .m_axis_pkt_len_tdata(),
    .m_axis_pkt_len_tvalid(),
    .m_axis_pkt_len_tready());

  ////////////////////////////////////////////////////////////
  //
  // User code
  //
  ////////////////////////////////////////////////////////////

  // Control Source Unused
  assign cmdout_tdata  = 64'd0;
  assign cmdout_tlast  = 1'b0;
  assign cmdout_tvalid = 1'b0;
  assign ackin_tready  = 1'b1;

  localparam [7:0] SR_SYMSYNC_MODE  = 130;
  localparam [7:0] SR_SHIFT_THRESHOLD  = 131;
  localparam [7:0] SR_DECIM_RATE       = 132;
  localparam [7:0] SR_MA_LINE_DEPTH    = 133;
  localparam [7:0] SR_SHR_SENS         = 134;
  localparam [7:0] SR_CRAPPY_THRESHOLD = 135;

  wire [31:0] symsync_mode;
  setting_reg #(
    .my_addr(SR_SYMSYNC_MODE), .awidth(8), .width(32), .at_reset(32'h2ccccccc))
  sr_symsync_mode (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(symsync_mode), .changed());

  wire [31:0] shift_threshold;
  setting_reg #(
    .my_addr(SR_SHIFT_THRESHOLD), .awidth(8), .width(32), .at_reset(32'h2ccccccc))
  sr_shift_threshold (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(shift_threshold), .changed());

  wire [31:0] decim_rate;
  setting_reg #(
    .my_addr(SR_DECIM_RATE), .awidth(8), .width(32), .at_reset(32'h00000032))
  sr_decim_rate (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(decim_rate), .changed());

  wire [31:0] ma_line_depth;
  setting_reg #(
    .my_addr(SR_MA_LINE_DEPTH), .awidth(8), .width(32), .at_reset(32'h00000008))
  sr_ma_line_depth (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(ma_line_depth), .changed());

  wire [31:0] shr_sens;
  setting_reg #(
    .my_addr(SR_SHR_SENS), .awidth(8), .width(32), .at_reset(32'h00000014))
  sr_shr_sens (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(shr_sens), .changed());

  wire [31:0] crappy_threshold;
  setting_reg #(
    .my_addr(SR_CRAPPY_THRESHOLD), .awidth(8), .width(32), .at_reset(32'h00000008))
  sr_crappy_threshold (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(crappy_threshold), .changed());

  assign s_axis_data_tuser = {
    2'b00,        // Data Packet type
    1'b0,         // No time
    1'b0,      // Don't use EOB
    12'd0,        // Sequence number, don't care handled by AXI wrapper
    16'd0,    // Don't care, AXI wrapper fills this in based on tlast
    src_sid,      // SRC SID
    next_dst_sid, // DST SID
    64'd0};       // VITA time (ignored)

  zluudg_receiver zluudg_receiver (
    .aclk(ce_clk),
    .areset(ce_rst | clear_tx_seqnum),
    .sr_symsync_mode(symsync_mode),
    .sr_shift_threshold(shift_threshold),
    .sr_decim_rate(decim_rate),
    .sr_ma_line_depth(ma_line_depth),
    .sr_shr_sens(shr_sens),
    .sr_crappy_threshold(crappy_threshold),
    .s_iqsample_tready(m_axis_data_tready),
    .s_iqsample_tdata({m_axis_data_tdata[15:0],m_axis_data_tdata[31:16]}), // Swap I/Q order
    .s_iqsample_tvalid(m_axis_data_tvalid),
    .s_iqsample_tlast(m_axis_data_tlast),
    .m_outbyte_tready(s_axis_data_tready),
    .m_outbyte_tdata(s_axis_data_tdata),
    .m_outbyte_tvalid(s_axis_data_tvalid),
    .m_outbyte_tlast(s_axis_data_tlast));

endmodule
