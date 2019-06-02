----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: detector (Frame detector/Squelch filter)
-- Description: Processes a stream of bit vectors representing the sign of the phase difference
-- and tries to match this stream to the SHR of an IEEE 802.15.4 packet. If there is a match,
-- it starts outputting one sequence at a time to the decoder. It stops when it gets a
-- clear frame signal.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_detector is
    port ( aclk                : in std_logic;
           areset              : in std_logic;
           sr_shr_sens         : in std_logic_vector(C_SETREGW - 1 downto 0);
           clr_frame           : in std_logic; -- used to clear a frame and start detection anew
           s_chip_tready       : out std_logic;
           s_chip_tdata        : in std_logic_vector(C_CHIPW - 1 downto 0);
           s_chip_tvalid       : in std_logic;
           m_chipseq_tready    : in std_logic;
           m_chipseq_tdata     : out std_logic_vector(C_CHIPSEQW - 1 downto 0);
           m_chipseq_tvalid    : out std_logic);
end zluudg_detector;

architecture Behavioral of zluudg_detector is

    -- Use only 2 bytes of synch header + delimiter in (terms of chips) for lock-on, saves space
    constant N_PREAMBLE_BYTES_FOR_SYNCH : integer := 3;
    constant SHR_LENGTH : integer := C_CHIPS_PER_BYTE * N_PREAMBLE_BYTES_FOR_SYNCH;
    constant synch_header : std_logic_vector(SHR_LENGTH-1 downto 0) :=
    --    |    LAST 2 BYTES OF PREAMBLE     | |   DELIMITER   |
        X"6077AE6C_6077AE6C_6077AE6C_6077AE6C_077AE6CE_131F8851";

    -- Due to initial phase state ambiguity, the LS Chip of every seq is unknown, hence this mask
    constant bad_chip_mask : std_logic_vector(SHR_LENGTH-1 downto 0) :=
        X"7FFFFFFF_7FFFFFFF_7FFFFFFF_7FFFFFFF_7FFFFFFF_7FFFFFFF";

    -- Shift register used to hold the sign bit of the inputs while scanning for the synch_header
    signal synch_header_shreg : std_logic_vector(SHR_LENGTH-1 downto 0) := (others => '0');

    -- Register for delaying the output signal in order to match corr_score signal.
    signal m_chipseq_tdata_reg : std_logic_vector(C_CHIPSEQW-1 downto 0) := (others => '0');

    -- Signal that will hold the correlation (bitwise xor) between the contents of
    -- synch_header_shreg. Should ideally contain all zeros if the contents of
    -- synch_header_shreg matches the synchronization header. bad_chip_mask will
    -- be used to filter out unusable chips.
    signal synch_header_corr : std_logic_vector(SHR_LENGTH-1 downto 0);

    -- Signal that contains the score (calculated as the number of ones in synch_header_corr).
    -- If the contents of synch_header_shreg yield a sufficiently low score, it will count
    -- as if the synchronization header has been found.
    signal corr_score : unsigned(clogb2(SHR_LENGTH) downto 0) := (others => '1');

    -- Signal that will be asserted if the contents of synch_header_shreg yield a
    -- sufficiently low score, i.e. the synchronization header has been found.
    -- It will only be deasserted upon reset or when an external component assers
    -- the "clear_frame" signal.
    signal synch_header_found : std_logic := '0';

    -- Counter for keeping track of how many new chips have been shifted in and is
    -- currently driving the output.
    constant CHIP_COUNTER_W : integer := clogb2(C_CHIPSEQW);
    signal chip_counter : unsigned(CHIP_COUNTER_W-1 downto 0) := (others => '0');


    -- Delay the input "tvalid"-blips to match the delay in the device. Use a gate
    -- circuit to only pass the delayed blips which correspond to valid chipsequences
    signal tvalid_d : std_logic := '0';
    signal tvalid_dd : std_logic := '0';

begin

    -- This block can always accept input, except when it's being reset
    s_chip_tready <= m_chipseq_tready and (not areset);

    -- A shift register that contains a number of values that is equal to the length of the
    -- part of the synchronization header that we are trying to match. The values in this shift
    -- register are equal to the most recent sign bits of the input, which is the only thing
    -- we are required to know about the angular values of the input.
    P_SYNCH_HEADER_SHREG: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                synch_header_shreg <= (others => '0');
            else 
                if (s_chip_tvalid = '1') then
                    synch_header_shreg <= synch_header_shreg(SHR_LENGTH-2 downto 0) & 
                                     not (s_chip_tdata(s_chip_tdata'length-1));
                end if; 
            end if;
        end if;
    end process P_SYNCH_HEADER_SHREG;

    -- We feed the 32 (by default) most recent values of synch_header_shreg to the output.
    -- When we have detected a frame, the s_imag_tvalid flag will be used to signal to
    -- the subsequent blocks whenever the output is expected to contain one of the
    -- 16 valid chip sequences defined by the IEEE 802.15.4 standard.
    -- The process delays the output to match corr_score signal assertion.
    P_OUT_REG: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                m_chipseq_tdata_reg <= (others => '0');
            else
                m_chipseq_tdata_reg <= synch_header_shreg(C_CHIPSEQW-1 downto 0);
            end if;
        end if;
    end process P_OUT_REG;
    m_chipseq_tdata <= m_chipseq_tdata_reg;

    -- This signal contains a number of ones which is equal to the hamming distance between
    -- the contents of synch_header_shreg and the part of the synchronization header that
    -- is used for detection.
    synch_header_corr <= (synch_header_shreg xor synch_header) and bad_chip_mask;

    -- Process for calculating the score of the contents of synch_header_shreg.
    -- The score is calculated as the hamming distance between the contents of
    -- synch_header_shreg and the part of the synchronization header that is used
    -- for detection (with some of the chips filtered out with a mask).
    P_CORR_SCORE: process (aclk)
        variable sum : unsigned(clogb2(SHR_LENGTH) downto 0) := (others => '0');
    begin
        if rising_edge(aclk) then
            if (areset = '1' or clr_frame = '1') then
                corr_score <= (others => '1');
            else
                sum := (others => '0');
                for i in 0 to SHR_LENGTH-1 loop
                    if (synch_header_corr(i) = '1') then
                        sum := sum + 1;
                    end if;
                end loop;
                corr_score <= sum;
            end if;
        end if;
    end process P_CORR_SCORE;

    -- Process that looks at the score of the current contents of synch_header_shreg
    -- and asserts the latched signal synch_header_found if the score is below a certain threshold.
    -- The asserted signal will cause two counters to start ticking:
    -- chip_counter will keep track of how many new chips has been shifted in. When
    -- 32 new values have been shifted in, it means a chip sequence ready for decoding is
    -- driving the output, and if this chip sequence belongs to the payload,
    -- s_imag_tvalid will be asserted.
    -- out_counter will keep track of how much of the payload has been output. When all
    -- bytes have been output, the block will start scanning for a new header.
    P_SYNCH_HEADER_FOUND: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1' or clr_frame = '1') then
                synch_header_found <= '0';
            else
                if (corr_score <= unsigned(sr_shr_sens)) then
                    synch_header_found <= '1';
                end if;
            end if;
        end if;
    end process P_SYNCH_HEADER_FOUND;

    -- Process that starts a counter once the synchronization header has been found.
    -- With every new input a bit gets shifted into the output register. The purpose
    -- of the counter is to keep track of when a new sequence has been shifted in to
    -- this register, which will happen every 32nd (by default) clock cycle once
    -- the frame has been detected.
    P_CHIP_COUNTER: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1' or clr_frame = '1') then
                chip_counter <= to_unsigned(0, CHIP_COUNTER_W);
            else
                if (synch_header_found = '1') then
                    if (s_chip_tvalid = '1') then
                        if (chip_counter = C_CHIPSEQW-1) then
                            chip_counter <= to_unsigned(0, CHIP_COUNTER_W);
                        else
                            chip_counter <= chip_counter + 1;
                        end if;
                    end if;
                else
                    chip_counter <= to_unsigned(0, CHIP_COUNTER_W);
                end if;
            end if;
        end if;
    end process P_CHIP_COUNTER;

    -- Every time chip counter is about to wrap around it is time to assert the
    -- valid flag since the output register contains a valid sequence, given
    -- that the synchronization header has been found, of course.
    P_BLIP_TVALID: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1' or clr_frame = '1') then
               tvalid_d <= '0';
               tvalid_dd <= '0';
            else
                tvalid_d <= s_chip_tvalid;
                tvalid_dd <= tvalid_d;
            end if;
        end if;
    end process P_BLIP_TVALID;
    m_chipseq_tvalid <= tvalid_dd when (synch_header_found = '1' and (chip_counter = 0)) else '0';

end Behavioral;
