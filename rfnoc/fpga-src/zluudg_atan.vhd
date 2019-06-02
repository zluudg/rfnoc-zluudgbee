----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: atan (CORDIC-style arctangent)
-- Description: Pipelined arctan-calculator. Output is a
-- between -pi and pi and represented by a Q3.13 number.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_atan is
    port ( aclk           : in std_logic;
           areset         : in std_logic;
           s_tready       : out std_logic;
           s_tvalid       : in std_logic;
           s_real_tdata   : in std_logic_vector(C_PRODW - 1 downto 0);
           s_imag_tdata   : in std_logic_vector(C_PRODW - 1 downto 0);
           m_phase_tready : in std_logic;
           m_phase_tvalid : out std_logic;
           m_phase_tdata  : out std_logic_vector(C_PHASEW - 1 downto 0));
end zluudg_atan;

architecture Behavioral of zluudg_atan is

    -- Phase data interpretation is signed Q2.F where F is the number of
    -- fractional bits. 1 + 2 + F = C_PHASEW. We iterate once for every
    -- fractional bit since that roughy agrees with the convergence rate
    -- of the algorithm.
    constant n_iter : integer := C_PHASEW - 3;

    -- Delay line for delaying tvalid input to match the delay of the pipeline.
    -- Note that the delay has one extra stage compared to the number of CORDIC
    -- microrotations, which is 13. This is due to the fact that the coarse rotation
    -- that is done to resolve angles in quadrant 2 and 3 takes up one extra cycle.
    signal tvalid_dly : std_logic_vector(n_iter downto 0) := (others => '0');

    type t_lut is array (0 to n_iter-1) of signed(C_PHASEW - 1 downto 0);
    signal angle_lut : t_lut := (X"1921F",
                                 X"0ED63",
                                 X"07D6D",
                                 X"03FAB",
                                 X"01FF5",
                                 X"00FFE",
                                 X"007FF",
                                 X"003FF",
                                 X"001FF",
                                 X"000FF",
                                 X"0007F",
                                 X"0003F",
                                 X"0001F",
                                 X"0000F",
                                 X"00007",
                                 X"00003",
                                 X"00001");

    type t_pipe_rect is array (integer range <>) of signed(C_PRODW - 1 downto 0);
    type t_pipe_ph is array (integer range <>) of signed(C_PHASEW - 1 downto 0);

    signal coarse_real : signed(C_PRODW - 1 downto 0) := (others => '0');
    signal coarse_imag : signed(C_PRODW - 1 downto 0) := (others => '0');
    signal coarse_phase : signed(C_PHASEW - 1 downto 0) := (others => '0');


    -- The signal used to indicate the direction of the current micro-rotation
    signal d_pipe : std_logic_vector(0 to n_iter-1) := (others => '0');
    signal re_pipe : t_pipe_rect(0 to n_iter-1) := (others => (others => '0'));
    signal im_pipe : t_pipe_rect(0 to n_iter-1) := (others => (others => '0'));
    signal re_res : t_pipe_rect(0 to n_iter-1) := (others => (others => '0'));
    signal im_res : t_pipe_rect(0 to n_iter-1) := (others => (others => '0'));
    signal ph_pipe : t_pipe_ph(0 to n_iter-1) := (others => (others => '0'));
    signal ph_res : t_pipe_ph(0 to n_iter-1) := (others => (others => '0'));

begin

    s_tready <= m_phase_tready and (not areset);

    m_phase_tdata <= std_logic_vector(ph_pipe(n_iter - 1));
    m_phase_tvalid <= tvalid_dly(n_iter);

    -- Direction selector is 1 when imaginary part is negative (== sign bit is 1)
    G_DIRECTION:
    for i in 0 to n_iter-1 generate
        d_pipe(i) <= im_pipe(i)(C_PRODW - 1);
    end generate G_DIRECTION;

    G_INTERMEDIATE:
    for i in 0 to n_iter-1 generate
        with d_pipe(i) select re_res(i) <=
            re_pipe(i) - shift_right(im_pipe(i),i) when '1',
            re_pipe(i) + shift_right(im_pipe(i),i) when others;

        with d_pipe(i) select im_res(i) <=
            im_pipe(i) + shift_right(re_pipe(i),i) when '1',
            im_pipe(i) - shift_right(re_pipe(i),i) when others;

        with d_pipe(i) select ph_res(i) <=
            ph_pipe(i) - angle_lut(i) when '1',
            ph_pipe(i) + angle_lut(i) when others;
    end generate G_INTERMEDIATE;
    
    P_COARSE: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                coarse_real <= (others => '0');
                coarse_imag <= (others => '0');
                coarse_phase <= (others => '0');
            else
                if (s_tvalid = '1') then
                    if (s_imag_tdata(C_PRODW - 1) = '1') then -- imag is negative
                        coarse_real <= -signed(s_imag_tdata);
                        coarse_imag <= signed(s_real_tdata);
                        coarse_phase <= X"CDBC0"; -- -pi/2;
                    else -- imag is non-negative
                        coarse_real <= signed(s_imag_tdata);
                        coarse_imag <= -signed(s_real_tdata);
                        coarse_phase <= X"3243F"; -- pi/2
                    end if;
                end if;
            end if;
        end if;
    end process P_COARSE;

    P_CORDIC: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                re_pipe <= (others => (others => '0'));
                im_pipe <= (others => (others => '0'));
                ph_pipe <= (others => (others => '0'));
            else
                re_pipe(0) <= coarse_real;
                im_pipe(0) <= coarse_imag;
                ph_pipe(0) <= coarse_phase;
                for i in 1 to n_iter-1 loop
                    re_pipe(i) <= re_res(i-1);
                    im_pipe(i) <= im_res(i-1);
                    ph_pipe(i) <= ph_res(i-1);
                end loop;
            end if;
        end if;
    end process P_CORDIC;

    P_TVALID: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                tvalid_dly <= (others => '0');
            else
                -- tvalid_dly has n_iter+1 elements, which is why n_iter-1 is used
                -- instead of n_iter-2.
                tvalid_dly <= tvalid_dly(n_iter - 1 downto 0) & s_tvalid;
            end if;
        end if;
    end process P_TVALID;

end Behavioral;
