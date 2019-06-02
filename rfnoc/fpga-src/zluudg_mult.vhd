----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: mult (Complex multiplier)
-- Description: Pipelined complex multiplier.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_mult is
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
end zluudg_mult;

architecture Behavioral of zluudg_mult is

    constant W_MUL : integer := C_SAMPLEW + C_SAMPLEW;


    signal a : signed(C_SAMPLEW - 1 downto 0) := (others => '0');
    signal b : signed(C_SAMPLEW - 1 downto 0) := (others => '0');
    signal c : signed(C_SAMPLEW - 1 downto 0) := (others => '0');
    signal d : signed(C_SAMPLEW - 1 downto 0) := (others => '0');

    signal re_prod1 : signed(W_MUL - 1 downto 0) := (others => '0');
    signal re_prod2 : signed(W_MUL - 1 downto 0) := (others => '0');
    signal im_prod1 : signed(W_MUL - 1 downto 0) := (others => '0');
    signal im_prod2 : signed(W_MUL - 1 downto 0) := (others => '0');

    signal m_real_tdata_int : signed(C_PRODW - 1 downto 0) := (others => '0');
    signal m_real_tvalid_int : std_logic := '0';

    signal m_imag_tdata_int : signed(C_PRODW - 1 downto 0) := (others => '0');
    signal m_imag_tvalid_int : std_logic := '0';

    signal tvalid_d : std_logic := '0';

begin

    s_tready <= m_tready and (not areset);

    a <= signed(s_fact1_tdata(C_SAMPLEW - 1 downto 0));
    b <= signed(s_fact1_tdata(C_IQSAMPLEW - 1 downto C_SAMPLEW));
    c <= signed(s_fact2_tdata(C_SAMPLEW - 1 downto 0));
    d <= signed(s_fact2_tdata(C_IQSAMPLEW - 1 downto C_SAMPLEW));


    m_tvalid <= m_real_tvalid_int;
    m_real_tdata <= std_logic_vector(m_real_tdata_int);
    m_imag_tdata <= std_logic_vector(m_imag_tdata_int);

    P_RE: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                re_prod1 <= (others => '0');
                re_prod2 <= (others => '0');
                m_real_tdata_int <= (others => '0');
            else
                re_prod1 <= a * c;
                re_prod2 <= b * d;
                m_real_tdata_int <= resize(re_prod1 - re_prod2, C_PRODW);
            end if;
        end if;
    end process P_RE;

    P_IM: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                im_prod1 <= (others => '0');
                im_prod2 <= (others => '0');
                m_imag_tdata_int <= (others => '0');
            else
                im_prod1 <= a * d;
                im_prod2 <= b * c;
                m_imag_tdata_int <= resize(im_prod1 + im_prod2, C_PRODW);
            end if;
        end if;
    end process P_IM;

    P_TVALID_D: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                m_real_tvalid_int <= '0';
            else
                tvalid_d <= s_tvalid;
                m_real_tvalid_int <= tvalid_d;
                m_imag_tvalid_int <= tvalid_d;
            end if;
        end if;
    end process P_TVALID_D;

end Behavioral;