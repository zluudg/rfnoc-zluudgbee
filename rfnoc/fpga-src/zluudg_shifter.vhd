----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: shifter (Threshold indicator)
-- Description: Keeps a moving average of the error due to poor synchronization. Ideally, symbols
-- should be either pi/2 or -pi/2. If the error is to great, a signal is asserted, causing the
-- decimator component to change its offset.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_shifter is
    port ( aclk               : in std_logic;
           areset             : in std_logic;
           sr_ma_line_depth   : in std_logic_vector(C_SETREGW - 1 downto 0);
           sr_shift_threshold : in std_logic_vector(C_SETREGW - 1 downto 0);
           en                 : in std_logic;
           data               : in std_logic_vector(C_CHIPW - 1 downto 0);
           shift              : out std_logic_vector);
end zluudg_shifter;

architecture Behavioral of zluudg_shifter is

    -- pi/2 in Q2.17 representation. This is the expected magnitude of the
    -- output of the iir block when correct symbol synchronization has
    -- been achieved.
    signal symbol_ref : signed(C_CHIPW - 1 downto 0) := X"3243F";

    type t_ma_line is array(0 to C_MA_LINE_MAX - 1) of signed(C_CHIPW - 1 downto 0);
    signal ma_line : t_ma_line := (others => (others => '0'));

    signal fakediv_shift : unsigned(2 downto 0);

    signal int_shift : std_logic_vector(1 downto 0) := "00";

    -- Parallelized error sum calculation
    signal err1 : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal err2 : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal err3 : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal err4 : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal err12 : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal err34 : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal err_sig_unscaled : signed(C_CHIPW - 1 downto 0) := (others => '0');
    signal err_sig : signed(C_CHIPW - 1 downto 0) := (others => '0');

    signal arith_shift_threshold : signed(C_CHIPW - 1 downto 0);
    signal boost_threshold_hi : signed(C_CHIPW - 1 downto 0);
    signal boost_threshold_lo : signed(C_CHIPW - 1 downto 0);
    signal arith_ma_line_depth : signed(C_SETREGW - 1 downto 0);

begin

    -- Depending on the ma_line_depth input we emulate division by
    -- shifting the error sum.
    with sr_ma_line_depth select fakediv_shift <=
        "001" when X"00000002",
        "010" when X"00000004",
        "011" when X"00000008",
        "100" when X"00000010",
        "000" when others;

    -- Recast the input threshold to a proper width and type for easy comparison
    arith_shift_threshold <= resize(abs(signed(sr_shift_threshold)), C_CHIPW);
    boost_threshold_hi <= arith_shift_threshold + shift_right(arith_shift_threshold, 1);
    boost_threshold_lo <= arith_shift_threshold + shift_right(arith_shift_threshold, 2);


    arith_ma_line_depth <= signed(sr_ma_line_depth);

    shift <= int_shift;

    P_SHIFT: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                int_shift <= "00";
            else
                if (err_sig >= boost_threshold_hi) then
                    int_shift <= "11";
                elsif (err_sig >= boost_threshold_lo) then
                    int_shift <= "10";
                elsif (err_sig >= arith_shift_threshold) then
                    int_shift <= "01";
                else
                    int_shift <= "00";
                end if;
            end if;
        end if;
    end process P_SHIFT;

    -- Process that rescales the error signal before storing in in a register
    P_ERR_SIG: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                err_sig <= (others => '0');
            else
                err_sig <= shift_right(err_sig_unscaled, to_integer(fakediv_shift));
            end if;
        end if;
    end process P_ERR_SIG;

    -- Every decimated sample is assumed to be rotated by pi/2 radians,
    -- in either positive or negative direction, compared to the preceeding
    -- decimated sample. In this process, the real part of the product of
    -- the most recently decimated and the conjugate of the preceeding sample
    -- is stored in a delay line. The values stored are expected to be close to
    -- zero when we have found the optimal decimation offset. Thus, by using a
    -- MA-filter on the stored values we generate an error signal that we use to
    -- determine whether we should change our decimation offset.
    P_MA_LINE: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                ma_line <= (others => (others => '0'));
            else
                if (en = '1') then
                    if (int_shift = "00") then
                        for i in 1 to C_MA_LINE_MAX-1 loop
                            ma_line(i) <= ma_line(i-1);
                        end loop;    
                    else
                        ma_line(1 to C_MA_LINE_MAX-1) <= (others => (others => '0'));
                    end if;

                    ma_line(0) <= abs(symbol_ref - abs(signed(data)));    

                end if;
            end if;
        end if;
    end process P_MA_LINE;

    -- Calculates the error signal based on the contents of the MA-line.
    -- If the error signal exceeds the threshold, the shift signal is asserted.
    -- This will cause the block to offset the entire decimation process by 1.
    -- The MA line will be cleared and the calculation of the error signal
    -- will begin anew. The offsetting will utlimately cause the block
    -- to perform the decimation at a location with a low enough error, based
    -- on the threshold value that has been loaded into the threshold register.
    P_ERROR_SIG1: process (aclk)
        variable err_sum : signed(C_CHIPW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                err1 <= (others => '0');
            else
                err_sum := (others => '0');
                for i in 0 to C_MA_LINE_MAX/4-1 loop
                    if (i < arith_ma_line_depth) then
                        err_sum := err_sum + ma_line(i);
                    end if;
                end loop;
                err1 <= err_sum;
            end if;
        end if;
    end process P_ERROR_SIG1;

    P_ERROR_SIG2: process (aclk)
        variable err_sum : signed(C_CHIPW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                err2 <= (others => '0');
            else
                err_sum := (others => '0');
                for i in C_MA_LINE_MAX/4 to C_MA_LINE_MAX/2-1 loop
                    if (i < arith_ma_line_depth) then
                        err_sum := err_sum + ma_line(i);
                    end if;
                end loop;
                err2 <= err_sum;
            end if;
        end if;
    end process P_ERROR_SIG2;

    P_ERROR_SIG3: process (aclk)
        variable err_sum : signed(C_CHIPW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                err3 <= (others => '0');
            else
                err_sum := (others => '0');
                for i in C_MA_LINE_MAX/2 to 3*C_MA_LINE_MAX/4-1 loop
                    if (i < arith_ma_line_depth) then
                        err_sum := err_sum + ma_line(i);
                    end if;
                end loop;
                err3 <= err_sum;
            end if;
        end if;
    end process P_ERROR_SIG3;

    P_ERROR_SIG4: process (aclk)
        variable err_sum : signed(C_CHIPW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                err4 <= (others => '0');
            else
                err_sum := (others => '0');
                for i in 3*C_MA_LINE_MAX/4 to C_MA_LINE_MAX-1 loop
                    if (i < arith_ma_line_depth) then
                        err_sum := err_sum + ma_line(i);
                    end if;
                end loop;
                err4 <= err_sum;
            end if;
        end if;
    end process P_ERROR_SIG4;

    P_ERROR_SIG_INTERM: process(aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                err12 <= (others => '0');
                err34 <= (others => '0');
            else
                err12 <= err1 + err2;
                err34 <= err3 + err4;
            end if;
        end if;
    end process P_ERROR_SIG_INTERM;

    P_ERROR_SIG_MAIN: process(aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                err_sig_unscaled <= (others => '0');
            else
                err_sig_unscaled <= err12 + err34;
            end if;
        end if;
    end process P_ERROR_SIG_MAIN;

end Behavioral;
