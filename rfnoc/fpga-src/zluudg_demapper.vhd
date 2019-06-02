----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: demapper (Chip sequence to nibble)
-- Description: Maps a chip sequence to the nibble
-- whose corresponding chip sequence has the lowest hamming distance
-- to the input signal. If the hamming distance between the input sequence
-- and the closest match is above a threshold the output nibble is tagged
-- as crappy.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_demapper is
    port ( aclk                : in std_logic;
           areset              : in std_logic;
           sr_crappy_threshold : in std_logic_vector(C_SETREGW - 1 downto 0);
           s_chipseq_tready    : out std_logic;
           s_chipseq_tdata     : in std_logic_vector(C_CHIPSEQW - 1 downto 0);
           s_chipseq_tvalid    : in std_logic;
           m_nibble_tready     : in std_logic;
           m_nibble_tdata      : out std_logic_vector(C_BYTEW - 1 downto 0);
           m_nibble_tvalid     : out std_logic);
end zluudg_demapper;

architecture Behavioral of zluudg_demapper is

        -- Some types for convenience and compactness
    subtype t_score is unsigned(clogb2(C_CHIPSEQW) downto 0);
    type t_chipseq_v is array(0 to C_NSEQ-1) of std_logic_vector(C_CHIPSEQW - 1 downto 0);
    type t_hamming_scores is array(0 to C_NSEQ-1) of t_score;

    -- A vector with the valid chip sequences, the position of each sequence corresponds to the
    -- value of the demapped nibble.
    constant chip_sequences : t_chipseq_v := (
    -- These entries were entered by hand
    -- and derived from the sequences in Schmid's paper.
---------------------------------------------------------------------------------------------------
-- |    HEX       |   UINT32    | Symbol | bits (LSB -> MSB)  | Nibble value
---------------------------------------------------------------------------------------------------
    X"6077AE6C", -- 1618456172  |    0   |        0000        | 0x0
    X"4E077AE6", -- 1309113062  |    1   |        1000        | 0x1
    X"6CE077AE", -- 1826650030  |    2   |        0100        | 0x2
    X"66CE077A", -- 1724778362  |    3   |        1100        | 0x3
    X"2E6CE077", --  778887287  |    4   |        0010        | 0x4
    X"7AE6CE07", -- 2061946375  |    5   |        1010        | 0x5
    X"77AE6CE0", -- 2007919840  |    6   |        0110        | 0x6
    X"077AE6CE", --  125494990  |    7   |        1110        | 0x7
    X"1F885193", --  529027475  |    8   |        0001        | 0x8
    X"31F88519", --  838370585  |    9   |        1001        | 0x9
    X"131F8851", --  320833617  |   10   |        0101        | 0xA
    X"1931F885", --  422705285  |   11   |        1101        | 0xB
    X"51931F88", -- 1368596360  |   12   |        0011        | 0xC
    X"051931F8", --   85537272  |   13   |        1011        | 0xD
    X"0851931F", --  139563807  |   14   |        0111        | 0xE
    X"78851931"  -- 2021988657  |   15   |        1111        | 0xF
    );

    -- A signal vector for holding the score that the current registered input sequence
    -- gets with respect to the different pre-defined sequences. Ideally,
    -- the registered input sequence should always mask one and only one sequence,
    -- and the corresponding element in this vector should be all zeros.
    signal corr_v : t_chipseq_v := (others => (others => '1'));

    -- Due to the ambiguity of decoding mentioned in Schmid's paper,
    -- we have to mask out the least significant chip in each sequence.
    signal corr_mask : std_logic_vector(C_CHIPSEQW - 1 downto 0) := X"7FFFFFFF";

    -- A signal vector where each element corresponds to the hamming distance between
    -- the contents of the input register and each of the valid chip sequences.
    signal hamming_scores : t_hamming_scores := (others => (others => '0'));

    -- A register for storing the current byte we are working on.
    signal current_byte : std_logic_vector(C_BYTEW - 1 downto 0) := (others =>'0');

    -- Delay the tvalid input to match the decoded output
    signal tvalid_d : std_logic := '0';
    signal tvalid_dd : std_logic := '0';

    -- The lowest hamming score and the corresponding decoded nibble
    signal score1 : t_score := (others => '1');
    signal nibble1 : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');

    signal score2 : t_score := (others => '1');
    signal nibble2 : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');

    signal score3 : t_score := (others => '1');
    signal nibble3 : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');

    signal score4 : t_score := (others => '1');
    signal nibble4 : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');

    signal score12 : t_score := (others => '1');
    signal nibble12 : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');

    signal score34 : t_score := (others => '1');
    signal nibble34 : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');

    signal lowest_score : t_score := (others => '1');
    signal decoded_nibble : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');

begin

    score12 <= score1 when (score1 <= score2) else score2;
    nibble12 <= nibble1 when (score1 <= score2) else nibble2;

    score34 <= score3 when (score3 <= score4) else score4;
    nibble34 <= nibble3 when (score3 <= score4) else nibble4;

    lowest_score <= score12 when (score12 <= score34) else score34;
    decoded_nibble <= nibble12 when (score12 <= score34) else nibble34;

    m_nibble_tdata(C_NIBBLEW - 1 downto 0) <= decoded_nibble;
    m_nibble_tdata(C_BYTEW - 1 downto C_NIBBLEW) <= (others => '0')
        when (lowest_score < unsigned(sr_crappy_threshold))
        else (others => '1');

    s_chipseq_tready <= m_nibble_tready and (not areset);

    P_TVALID: process(aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                tvalid_d <= '0';
                tvalid_dd <= '0';
            else
                tvalid_d <= s_chipseq_tvalid;
                tvalid_dd <= tvalid_d;
            end if;
        end if;
    end process P_TVALID;
    m_nibble_tvalid <= tvalid_dd;

    -- For each valid, pre-defined chip sequence, XOR the contents of the current
    -- input register with the sequence, mask out the bad chips. The corr_v
    -- signal vector's elements will have a number of ones that corresponds to the
    -- hamming distance between the received signal and the corresponding pre-defined
    -- sequence.
    GEN_CORR: for i in 0 to C_NSEQ-1 generate
        corr_v(i) <= (s_chipseq_tdata xor chip_sequences(i)) and corr_mask;
    end generate GEN_CORR;

    -- For each element in corr_v, calculate the number of ones and store the result in
    -- hamming_score. Each element of hamming_score will have a numerical value equal to
    -- the hamming distance between the current input being processed and each of the
    -- valid chip sequences.
    P_CALC_SCORES: process (aclk)
        variable ham_score : t_score := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                hamming_scores <= (others => (others => '0'));
            else
                for i in 0 to C_NSEQ-1 loop
                    ham_score := (others => '0');
                    for j in 0 to C_CHIPSEQW-1 loop
                        if (corr_v(i)(j) = '1') then
                            ham_score := ham_score + 1;
                        end if;
                        hamming_scores(i) <= ham_score;
                    end loop;
                end loop;
            end if;
        end if;
    end process P_CALC_SCORES;

    -- Process that iterates through the hamming scores and demaps the current registered
    -- input to whichever of the valid sequences gets the lowest score. Alternates between
    -- storing the decoded nibble in the top and bottom nibble of the current byte being decoded.
    P_DECODE1: process (aclk)
        variable score : t_score := (others => '1');
        variable nibble : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                score1 <= (others => '1');
                nibble1 <= (others => '0');
            else
                score := (others => '1');
                for i in 0 to (C_NSEQ/4)-1 loop
                    if (hamming_scores(i) <= score) then
                        score := hamming_scores(i);
                        nibble := std_logic_vector(to_unsigned(i, C_NIBBLEW));
                    end if;
                end loop;

                score1 <= score;
                nibble1 <= nibble;

            end if;
        end if;
    end process P_DECODE1;

    P_DECODE2: process (aclk)
        variable score : t_score := (others => '1');
        variable nibble : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                score2 <= (others => '1');
                nibble2 <= (others => '0');
            else
                score := (others => '1');
                for i in C_NSEQ/4 to C_NSEQ/2-1 loop
                    if (hamming_scores(i) <= score) then
                        score := hamming_scores(i);
                        nibble := std_logic_vector(to_unsigned(i, C_NIBBLEW));
                    end if;
                end loop;

                score2 <= score;
                nibble2 <= nibble;

            end if;
        end if;
    end process P_DECODE2;

    P_DECODE3: process (aclk)
        variable score : t_score := (others => '1');
        variable nibble : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                score3 <= (others => '1');
                nibble3 <= (others => '0');
            else
                score := (others => '1');
                for i in C_NSEQ/2 to 3*C_NSEQ/4-1 loop
                    if (hamming_scores(i) <= score) then
                        score := hamming_scores(i);
                        nibble := std_logic_vector(to_unsigned(i, C_NIBBLEW));
                    end if;
                end loop;

                score3 <= score;
                nibble3 <= nibble;

            end if;
        end if;
    end process P_DECODE3;

    P_DECODE4: process (aclk)
        variable score : t_score := (others => '1');
        variable nibble : std_logic_vector(C_NIBBLEW - 1 downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                score4 <= (others => '1');
                nibble4 <= (others => '0');
            else
                score := (others => '1');
                for i in 3*C_NSEQ/4 to C_NSEQ-1 loop
                    if (hamming_scores(i) <= score) then
                        score := hamming_scores(i);
                        nibble := std_logic_vector(to_unsigned(i, C_NIBBLEW));
                    end if;
                end loop;

                score4 <= score;
                nibble4 <= nibble;

            end if;
        end if;
    end process P_DECODE4;

end Behavioral;
