----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: iir (Single pole IIR filter)
-- Description: Single pole IIR filter of the form y[n] = (a-1)*y[n-1] + a*x[n].
-- Has a low-pass characteristic in order to filter out the DC component that occurs in the
-- phase difference between to chips due to carrier frequency offset impairments.
-- The block has four output modes (DEFAULT is 0):
-- 0: z[n] = x[n]. No attempted DC offset correction.
-- 1: z[n] = u[n] = x[n]-y[n]. Subtract away the estimated DC offset component from the phase.
-- 2: z[n] = y[n]. Just output the estimated DC component, for debugging purposes.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_iir is
    port ( aclk            : in std_logic;
           areset          : in std_logic;
           sr_symsync_mode : in std_logic_vector(C_SETREGW - 1 downto 0);
           s_x_tready      : out std_logic;
           s_x_tvalid      : in std_logic;
           s_x_tdata       : in std_logic_vector(C_PHASEW - 1 downto 0);
           m_z_tready      : in std_logic;
           m_z_tvalid      : out std_logic;
           m_z_tdata       : out std_logic_vector(C_CHIPW - 1 downto 0));
end zluudg_iir;

architecture Behavioral of zluudg_iir is

    -- The exponent of the filter transfer function should be a small value, Wime uses 0.00016.
    -- If we use a power of two, we can replace the multiplication with a simple shift.
    constant ALPHA : integer := 13; -- 2^(-31) approx 0.00016

    signal x             : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal x_d           : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal v             : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal y             : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal y_reg         : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal u             : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal z             : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal int_m_z_tdata : signed(C_CHIPW - 1 downto 0) := (others => '0');

    signal tvalid_d : std_logic := '0';
    signal int_m_z_tvalid : std_logic := '0';
begin

    s_x_tready <= m_z_tready and (not areset);
    m_z_tvalid <= int_m_z_tvalid;
    m_z_tdata <= std_logic_vector(int_m_z_tdata);

    with sr_symsync_mode(1 downto 0) select z <=
        u when "01",
        y_reg when "10",
        x_d when others;

    x <= signed(s_x_tdata);
    v <= shift_right((x - y_reg), ALPHA);
    y <= v + y_reg;
    u <= x_d - y_reg;

    P_Y: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                y_reg <= (others => '0');
            else
                y_reg <= y;
            end if;
        end if;
    end process P_Y;

    P_X_DLY: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                x_d <= (others => '0');
            else
                if (s_x_tvalid = '1') then
                    x_d <= x;
                end if;
            end if;
        end if;
    end process P_X_DLY;
    
    P_TVALID_DLY: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                tvalid_d <= '0';
            else
                tvalid_d <= s_x_tvalid;
                int_m_z_tvalid <= tvalid_d;
            end if;
        end if;
    end process P_TVALID_DLY;

    P_OUT_REG: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                int_m_z_tdata <= (others => '0');
            else
                int_m_z_tdata <= z;
            end if;
        end if;
    end process P_OUT_REG;

end Behavioral;
