----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: receiver (Top wrapper)
-- Description: Toplevel structural VHDL for receiver architecture.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.zluudg_constants.all;

entity zluudg_receiver is
    port ( aclk                : in std_logic;
           areset              : in std_logic;
           sr_symsync_mode     : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_shift_threshold  : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_decim_rate       : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_ma_line_depth    : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_shr_sens         : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_crappy_threshold : in std_logic_vector(C_SETREGW - 1 downto 0);
           s_iqsample_tready   : out std_logic;
           s_iqsample_tdata	   : in std_logic_vector(C_IQSAMPLEW - 1 downto 0);
           s_iqsample_tvalid   : in std_logic;
           s_iqsample_tlast    : in std_logic;
		       m_outbyte_tready    : in std_logic;
		       m_outbyte_tdata     : out std_logic_vector(C_OUTW - 1 downto 0);
		       m_outbyte_tvalid    : out std_logic;
		       m_outbyte_tlast     : out std_logic);
end zluudg_receiver;

architecture Structural of zluudg_receiver is

    component zluudg_symsync is
        port ( aclk               : in std_logic;
               areset             : in std_logic;
               sr_symsync_mode    : in std_logic_vector(C_SETREGW - 1 downto 0);
               sr_shift_threshold : in std_logic_vector(C_SETREGW - 1 downto 0);
               sr_decim_rate      : in std_logic_vector(C_SETREGW - 1 downto 0);
               sr_ma_line_depth   : in std_logic_vector(C_SETREGW - 1 downto 0);
               s_iqsample_tready  : out std_logic;
               s_iqsample_tdata   : in std_logic_vector(C_IQSAMPLEW - 1 downto 0);
               s_iqsample_tvalid  : in std_logic;
               s_iqsample_tlast   : in std_logic;
               m_chip_tready      : in std_logic;
               m_chip_tdata       : out std_logic_vector(C_CHIPW - 1 downto 0);
               m_chip_tvalid      : out std_logic);
    end component zluudg_symsync;

    component zluudg_detector is
        port ( aclk             : in std_logic;
               areset           : in std_logic;
               sr_shr_sens      : in std_logic_vector(C_SETREGW - 1 downto 0);
               clr_frame        : in std_logic; -- used to clear a frame and start detection anew
               s_chip_tready    : out std_logic;
               s_chip_tdata     : in std_logic_vector(C_CHIPW - 1 downto 0);
               s_chip_tvalid    : in std_logic;
               m_chipseq_tready : in std_logic;
               m_chipseq_tdata  : out std_logic_vector(C_CHIPSEQW - 1 downto 0);
               m_chipseq_tvalid : out std_logic);
    end component zluudg_detector;

    component zluudg_demapper is
        port ( aclk                : in STD_LOGIC;
               areset              : in STD_LOGIC;
               sr_crappy_threshold : in std_logic_vector(C_SETREGW - 1 downto 0);
               s_chipseq_tready    : out STD_LOGIC;
               s_chipseq_tdata     : in STD_LOGIC_VECTOR (C_CHIPSEQW - 1 downto 0);
               s_chipseq_tvalid    : in STD_LOGIC;
               m_nibble_tready     : in STD_LOGIC;
               m_nibble_tdata      : out STD_LOGIC_VECTOR (C_BYTEW - 1 downto 0);
               m_nibble_tvalid     : out STD_LOGIC);
    end component zluudg_demapper;

    component zluudg_packager is
        port ( aclk             : in std_logic;
               areset           : in std_logic;
               frame_done       : out std_logic;
               s_nibble_tready	: out std_logic;
               s_nibble_tdata	: in std_logic_vector(C_BYTEW - 1 downto 0);
               s_nibble_tvalid	: in std_logic;
               m_outbyte_tready	: in std_logic;
               m_outbyte_tdata	: out std_logic_vector(C_OUTW - 1 downto 0);
               m_outbyte_tvalid	: out std_logic;
               m_outbyte_tlast  : out std_logic);
    end component zluudg_packager;

    component zluudg_ppfifo is
        port ( aclk          : in std_logic;
               areset        : in std_logic;
               almost_full   : out std_logic;
               skip_burst    : in std_logic;
               s_axis_tready : out std_logic;
               s_axis_tdata  : in std_logic_vector (C_OUTW - 1 downto 0);
               s_axis_tvalid : in std_logic;
               s_axis_tlast  : in std_logic;
               m_axis_tready : in std_logic;
               m_axis_tdata  : out std_logic_vector (C_OUTW - 1 downto 0);
               m_axis_tvalid : out std_logic;
               m_axis_tlast  : out std_logic);
    end component zluudg_ppfifo;

    signal int_chip_tready : std_logic;
    signal int_chip_tdata  : std_logic_vector(C_CHIPW - 1 downto 0);
    signal int_chip_tvalid : std_logic;

    signal int_chipseq_tready : std_logic;
    signal int_chipseq_tdata  : std_logic_vector(C_CHIPSEQW - 1 downto 0);
    signal int_chipseq_tvalid : std_logic;

    signal int_nibble_tready : std_logic;
    signal int_nibble_tdata  : std_logic_vector(C_BYTEW - 1 downto 0);
    signal int_nibble_tvalid : std_logic;

    signal int_outbyte_tready : std_logic;
    signal int_outbyte_tdata : std_logic_vector(C_OUTW - 1 downto 0);
    signal int_outbyte_tvalid : std_logic;
    signal int_outbyte_tlast : std_logic;

    -- Used for driving the main input tready
    signal almost_full : std_logic;
    signal int_s_iqsample_tready : std_logic;
    signal int_s_iqsample_tvalid : std_logic;

    -- Used to clear the detection of a frame once it's done
    signal int_clr_frame : std_logic;

begin

    -- Main input is ready to accept data if the output fifo is not full
    -- and able to accept data (which it always should be except for when it's
    -- entirely full)
    s_iqsample_tready <= int_s_iqsample_tready and (not almost_full);
    int_s_iqsample_tvalid <= s_iqsample_tvalid and (not almost_full);

    z_symsync: zluudg_symsync
        port map (
            aclk               => aclk,
            areset             => areset,
            sr_symsync_mode    => sr_symsync_mode,
            sr_shift_threshold => sr_shift_threshold,
            sr_decim_rate      => sr_decim_rate,
            sr_ma_line_depth   => sr_ma_line_depth,
            s_iqsample_tready  => int_s_iqsample_tready,
            s_iqsample_tdata   => s_iqsample_tdata,
            s_iqsample_tvalid  => int_s_iqsample_tvalid,
            s_iqsample_tlast   => s_iqsample_tlast,
            m_chip_tready      => int_chip_tready,
            m_chip_tdata	   => int_chip_tdata,
            m_chip_tvalid      => int_chip_tvalid);

    z_detector: zluudg_detector
        port map (
            aclk              => aclk,
            areset            => areset,
            sr_shr_sens       => sr_shr_sens,
            clr_frame         => int_clr_frame,
            s_chip_tready     => int_chip_tready,
            s_chip_tdata      => int_chip_tdata,
            s_chip_tvalid     => int_chip_tvalid,
            m_chipseq_tready  => int_chipseq_tready,
            m_chipseq_tdata   => int_chipseq_tdata,
            m_chipseq_tvalid  => int_chipseq_tvalid);

    z_demapper: zluudg_demapper
        port map (
            aclk                => aclk,
            areset              => areset,
            sr_crappy_threshold => sr_crappy_threshold,
            s_chipseq_tready    => int_chipseq_tready,
            s_chipseq_tdata     => int_chipseq_tdata,
            s_chipseq_tvalid    => int_chipseq_tvalid,
            m_nibble_tready     => int_nibble_tready,
            m_nibble_tdata      => int_nibble_tdata,
            m_nibble_tvalid     => int_nibble_tvalid);

    z_packager: zluudg_packager
        port map (
            aclk             => aclk,
            areset           => areset,
            frame_done       => int_clr_frame,
            s_nibble_tready  => int_nibble_tready,
            s_nibble_tdata   => int_nibble_tdata,
            s_nibble_tvalid  => int_nibble_tvalid,
            m_outbyte_tready => int_outbyte_tready,
            m_outbyte_tdata  => int_outbyte_tdata,
            m_outbyte_tvalid => int_outbyte_tvalid,
            m_outbyte_tlast  => int_outbyte_tlast);

    z_ppfifo: zluudg_ppfifo
        port map (
            aclk             => aclk,
            areset           => areset,
            almost_full      => almost_full,
            skip_burst       => '0',
            s_axis_tready => int_outbyte_tready,
            s_axis_tdata  => int_outbyte_tdata,
            s_axis_tvalid => int_outbyte_tvalid,
            s_axis_tlast  => int_outbyte_tlast,
            m_axis_tready => m_outbyte_tready,
            m_axis_tdata  => m_outbyte_tdata,
            m_axis_tvalid => m_outbyte_tvalid,
            m_axis_tlast  => m_outbyte_tlast);

end Structural;
