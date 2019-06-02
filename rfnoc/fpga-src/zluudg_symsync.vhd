----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: symsync (Symbol synchronizer)
-- Description: Wrapper for the components that make up the
-- downsampler/symbol synchronizer.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_symsync is
    port ( aclk               : in std_logic;
           areset             : in std_logic;
           sr_symsync_mode    : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_shift_threshold : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_decim_rate      : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_ma_line_depth   : in std_logic_vector(C_SETREGW - 1 downto 0);
           s_iqsample_tready  : out std_logic;
           s_iqsample_tvalid  : in std_logic;
           s_iqsample_tlast   : in std_logic;
           s_iqsample_tdata   : in std_logic_vector(C_IQSAMPLEW - 1 downto 0);
           m_chip_tready      : in std_logic;
           m_chip_tvalid      : out std_logic;
           m_chip_tdata       : out std_logic_vector(C_CHIPW - 1 downto 0));
end zluudg_symsync;

architecture Structural of zluudg_symsync is

    component zluudg_decimator is
        port ( aclk               : in std_logic;
               areset             : in std_logic;
               shift              : in std_logic_vector(1 downto 0);
               sr_decim_rate      : in std_logic_vector(C_SETREGW - 1 downto 0);
               s_iqsample_tready  : out std_logic;
               s_iqsample_tvalid  : in std_logic;
               s_iqsample_tlast   : in std_logic;
               s_iqsample_tdata	  : in std_logic_vector(C_IQSAMPLEW - 1 downto 0);
               m_tready           : in std_logic;
               m_tvalid           : out std_logic;
               m_sym_tdata        : out std_logic_vector(C_IQSAMPLEW - 1 downto 0);
               m_oldsym_tdata     : out std_logic_vector(C_IQSAMPLEW - 1 downto 0));
    end component zluudg_decimator;

    component zluudg_mult is
        port ( aclk           : in std_logic;
               areset         : in std_logic;
               s_tready       : out std_logic;
               s_tvalid       : in std_logic;
               s_fact1_tdata  : in std_logic_vector(C_IQSAMPLEW - 1 downto 0);
               s_fact2_tdata  : in std_logic_vector(C_IQSAMPLEW - 1 downto 0);
               m_tready       : in std_logic;
               m_tvalid       : out std_logic;
               m_imag_tdata   : out std_logic_vector(C_PRODW - 1 downto 0);
               m_real_tdata   : out std_logic_vector(C_PRODW - 1 downto 0));
    end component zluudg_mult;

    component zluudg_atan is
        port ( aclk           : in std_logic;
               areset         : in std_logic;
               s_tready       : out std_logic;
               s_tvalid       : in std_logic;
               s_real_tdata   : in std_logic_vector(C_PRODW - 1 downto 0);
               s_imag_tdata   : in std_logic_vector(C_PRODW - 1 downto 0);
               m_phase_tready : in std_logic;
               m_phase_tvalid : out std_logic;
               m_phase_tdata  : out std_logic_vector(C_PHASEW - 1 downto 0));
    end component zluudg_atan;

    component zluudg_iir is
        port ( aclk            : in std_logic;
               areset          : in std_logic;
               sr_symsync_mode : in std_logic_vector(C_SETREGW - 1 downto 0);
               s_x_tready      : out std_logic;
               s_x_tvalid      : in std_logic;
               s_x_tdata       : in std_logic_vector(C_PHASEW - 1 downto 0);
               m_z_tready      : in std_logic;
               m_z_tvalid      : out std_logic;
               m_z_tdata       : out std_logic_vector(C_CHIPW - 1 downto 0));
    end component zluudg_iir;

    component zluudg_shifter is
        port ( aclk               : in std_logic;
               areset             : in std_logic;
               sr_ma_line_depth   : in std_logic_vector(C_SETREGW - 1 downto 0);
               sr_shift_threshold : in std_logic_vector(C_SETREGW - 1 downto 0);
               en                 : in std_logic;
               data               : in std_logic_vector(C_CHIPW - 1 downto 0);
               shift              : out std_logic_vector(1 downto 0));
    end component zluudg_shifter;

    signal int_tready_decim_mult : std_logic;
    signal int_tvalid_decim_mult : std_logic;
    signal int_sym_tdata         : std_logic_vector(C_IQSAMPLEW - 1 downto 0);
    signal int_oldsym_tdata      : std_logic_vector(C_IQSAMPLEW - 1 downto 0);

    signal int_tready_mult_atan : std_logic;
    signal int_tvalid_mult_atan : std_logic;
    signal int_real_tdata       : std_logic_vector(C_PRODW - 1 downto 0);
    signal int_imag_tdata       : std_logic_vector(C_PRODW - 1 downto 0);

    signal int_phase_tready_atan_iir : std_logic;
    signal int_phase_tvalid_atan_iir : std_logic;
    signal int_phase_tdata_atan_iir  : std_logic_vector(C_PHASEW - 1 downto 0);

    signal int_chip_tready : std_logic;
    signal int_chip_tvalid : std_logic;
    signal int_chip_tdata  : std_logic_vector(C_CHIPW - 1 downto 0);


    signal int_shift : std_logic_vector(1 downto 0);

begin

    m_chip_tdata <= int_chip_tdata;
    m_chip_tvalid <= int_chip_tvalid;
    int_chip_tready <= m_chip_tready;

    z_decimator: zluudg_decimator
        port map (
            aclk              => aclk,
            areset            => areset,
            shift             => int_shift,
            sr_decim_rate     => sr_decim_rate,
            s_iqsample_tready => s_iqsample_tready,
            s_iqsample_tdata  => s_iqsample_tdata,
            s_iqsample_tvalid => s_iqsample_tvalid,
            s_iqsample_tlast  => s_iqsample_tlast,
            m_tready          => int_tready_decim_mult,
            m_tvalid          => int_tvalid_decim_mult,
            m_sym_tdata	      => int_sym_tdata,
            m_oldsym_tdata    => int_oldsym_tdata);

    z_mult: zluudg_mult
        port map (
            aclk          => aclk,
            areset        => areset,
            s_tready      => int_tready_decim_mult,
            s_tvalid      => int_tvalid_decim_mult,       
            s_fact1_tdata => int_sym_tdata,
            s_fact2_tdata => int_oldsym_tdata,
            m_tready      => int_tready_mult_atan,
            m_tvalid      => int_tvalid_mult_atan, 
            m_real_tdata  => int_real_tdata,
            m_imag_tdata  => int_imag_tdata);

    z_atan: zluudg_atan
        port map (
            aclk           => aclk,
            areset         => areset,
            s_tready       => int_tready_mult_atan,
            s_tvalid       => int_tvalid_mult_atan,
            s_real_tdata   => int_real_tdata,
            s_imag_tdata   => int_imag_tdata,
            m_phase_tready => int_phase_tready_atan_iir,
            m_phase_tdata  => int_phase_tdata_atan_iir,
            m_phase_tvalid => int_phase_tvalid_atan_iir);

    z_iir: zluudg_iir
        port map (
            aclk            => aclk,
            areset          => areset,
            sr_symsync_mode => sr_symsync_mode,
            s_x_tready      => int_phase_tready_atan_iir,
            s_x_tdata       => int_phase_tdata_atan_iir,
            s_x_tvalid      => int_phase_tvalid_atan_iir,
            m_z_tready      => int_chip_tready,
            m_z_tdata       => int_chip_tdata,
            m_z_tvalid      => int_chip_tvalid);

    z_shifter: zluudg_shifter
        port map (
            aclk               => aclk,
            areset             => areset,
            sr_shift_threshold => sr_shift_threshold,
            sr_ma_line_depth   => sr_ma_line_depth,
            data               => int_chip_tdata,
            en                 => int_chip_tvalid,
            shift              => int_shift);

end Structural;
