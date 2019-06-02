----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: crc16ccitt (16-bit CRC Checker)
-- Description: Verifies that the checksum in a PDU is correct.
-- This block expects bursts of 127 32-bit words. Each words represents one byte
-- in a PDU. Most of the extra bits are zero and the rest are flags for indicating
-- the status of the byte.
-- ACTIVE-flag indicates whether the byte is part of the PDU or just padding in the burst
-- CRAP1-flag indicates whether the lower nibble was decoded with confidence
-- CRAP2-flag indicates whether the upper nibble was decoded with confidence
-- ENDFRAME-flag is upper half of the CRC in the incoming word, last payload byte in the outgoing
-- CORRPUTED-flag is asserted to tell the subsequent ping-pong buffer to ignore the entire PDU
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;
entity zluudg_crc16ccitt is
    port ( aclk         : in std_logic;
           areset       : in std_logic;
           sr_crc_mode  : in std_logic_vector(C_SETREGW - 1 downto 0);
           s_in_tready  : out std_logic;
           s_in_tdata   : in std_logic_vector(C_OUTW - 1 downto 0);
           s_in_tvalid  : in std_logic;
           s_in_tlast   : in std_logic;
           m_out_tready : in std_logic;
           m_out_tdata  : out std_logic_vector(C_OUTW - 1 downto 0);
           m_out_tvalid : out std_logic;
           m_out_tlast  : out std_logic);
end zluudg_crc16ccitt;

architecture Mixed of zluudg_crc16ccitt is

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


    -- Delay line for input. Contents in last stage will be written to the output buffer
    -- in the following cycle and update the CRC register in the following cycle,
    -- unless tlast is asserted (in which case the CRC register will be reset
    -- in the following cycle). 
    signal tdata_d   : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');
    signal tdata_dd  : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');
    signal tdata_ddd : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');

    -- Delayed versions of tvalid to use as data propagates through the design.
    signal tvalid_d   : std_logic := '0';
    signal tvalid_dd  : std_logic := '0';
    signal tvalid_ddd : std_logic := '0';

    -- Delayed versions of tlast to indicate that inbyte2 contains the last byte in the
    -- PDU, which should be the upper byte in the checksum
    signal tlast_d    : std_logic := '0';
    signal tlast_dd  : std_logic := '0';
    signal tlast_ddd : std_logic := '0';

    -- If '1', we are in TX mode. In TX mode we are replacing the last two bytes in the
    -- N-length input burst with the value of the CRC calculations of the first N-2 bytes.
    -- It is up to the preceeding block to be aware of this and append two bytes to the PDU.
    -- If 0'0 we are in RX mode. In RX mode calculate the CRC for the first N-2 bytes. If
    -- the result does not match the remainging two bytes, we don't output anything. If
    -- there is a match, we output the first N-2 bytes of the input. 
    signal tx_mode : std_logic;

    -- Signal that is high while either of the last two input bytes is stored in
    -- the last stage of the input delay line.
    -- In TX mode this signal is used to mux in the CRC results into the last
    -- two bytes of the input data stream.
    -- In RX mode this signal is used to suppress the write enable signal to the
    -- output buffer so the CRC checksum gets discarded properly.
    signal skip_crc : std_logic;

    -- The LFSR that contains the results of each iteration and ultimately the,
    -- final CRC checksum.
    signal crc_reg : std_logic_vector(C_CRCW - 1 downto 0) := (others => '0');
    signal crc_result : std_logic_vector(C_CRCW - 1 downto 0) := (others => '0');
    signal bad_CRC : std_logic := '0';

    -- Flipped byte because the standard specifies it...
    signal flipped_byte : std_logic_vector(C_BYTEW - 1 downto 0) := (others => '0');
    signal flipped_crc : std_logic_vector(C_CRCW - 1 downto 0) := (others => '0');
    signal x : unsigned(C_BYTEW - 1 downto 0) := (others => '0');
    signal lut_out : std_logic_vector(C_CRCW - 1 downto 0) := (others => '0');
    signal next_crc : std_logic_vector(C_CRCW - 1 downto 0) := (others => '0');

    -- Signal that is used to load the calculated checksum into tdata_dd and
    -- tdata_ddd. In RX mode this should make no difference since those two
    -- bytes do not get written to the output buffer anyway.
    -- In TX mode, we are expecting the input burst to have two extra bytes.
    -- These get updated with the checksum and then sent to the next layer. 
    signal sel_crc : std_logic;

    -- Internal signals to/from ppfifo, which acts as an output buffer
    signal en_fifo : std_logic;
    signal int_almost_full : std_logic;
    signal tready : std_logic;
    signal fifo_tlast : std_logic;

    -- Thanks to http://automationwiki.com/index.php/CRC-16-CCITT for this LUT
    type t_lut is array (0 to 2**C_BYTEW - 1) of std_logic_vector(C_CRCW - 1 downto 0);
    signal lut : t_lut := (X"0000", X"1021", X"2042", X"3063", X"4084", X"50a5", 
                           X"60c6", X"70e7", X"8108", X"9129", X"a14a", X"b16b",
                           X"c18c", X"d1ad", X"e1ce", X"f1ef", X"1231", X"0210",
                           X"3273", X"2252", X"52b5", X"4294", X"72f7", X"62d6",
                           X"9339", X"8318", X"b37b", X"a35a", X"d3bd", X"c39c",
                           X"f3ff", X"e3de", X"2462", X"3443", X"0420", X"1401",
                           X"64e6", X"74c7", X"44a4", X"5485", X"a56a", X"b54b",
                           X"8528", X"9509", X"e5ee", X"f5cf", X"c5ac", X"d58d",
                           X"3653", X"2672", X"1611", X"0630", X"76d7", X"66f6",
                           X"5695", X"46b4", X"b75b", X"a77a", X"9719", X"8738",
                           X"f7df", X"e7fe", X"d79d", X"c7bc", X"48c4", X"58e5",
                           X"6886", X"78a7", X"0840", X"1861", X"2802", X"3823",
                           X"c9cc", X"d9ed", X"e98e", X"f9af", X"8948", X"9969",
                           X"a90a", X"b92b", X"5af5", X"4ad4", X"7ab7", X"6a96",
                           X"1a71", X"0a50", X"3a33", X"2a12", X"dbfd", X"cbdc",
                           X"fbbf", X"eb9e", X"9b79", X"8b58", X"bb3b", X"ab1a",
                           X"6ca6", X"7c87", X"4ce4", X"5cc5", X"2c22", X"3c03",
                           X"0c60", X"1c41", X"edae", X"fd8f", X"cdec", X"ddcd",
                           X"ad2a", X"bd0b", X"8d68", X"9d49", X"7e97", X"6eb6",
                           X"5ed5", X"4ef4", X"3e13", X"2e32", X"1e51", X"0e70",
                           X"ff9f", X"efbe", X"dfdd", X"cffc", X"bf1b", X"af3a",
                           X"9f59", X"8f78", X"9188", X"81a9", X"b1ca", X"a1eb",
                           X"d10c", X"c12d", X"f14e", X"e16f", X"1080", X"00a1",
                           X"30c2", X"20e3", X"5004", X"4025", X"7046", X"6067",
                           X"83b9", X"9398", X"a3fb", X"b3da", X"c33d", X"d31c",
                           X"e37f", X"f35e", X"02b1", X"1290", X"22f3", X"32d2",
                           X"4235", X"5214", X"6277", X"7256", X"b5ea", X"a5cb",
                           X"95a8", X"8589", X"f56e", X"e54f", X"d52c", X"c50d",
                           X"34e2", X"24c3", X"14a0", X"0481", X"7466", X"6447",
                           X"5424", X"4405", X"a7db", X"b7fa", X"8799", X"97b8",
                           X"e75f", X"f77e", X"c71d", X"d73c", X"26d3", X"36f2",
                           X"0691", X"16b0", X"6657", X"7676", X"4615", X"5634",
                           X"d94c", X"c96d", X"f90e", X"e92f", X"99c8", X"89e9",
                           X"b98a", X"a9ab", X"5844", X"4865", X"7806", X"6827",
                           X"18c0", X"08e1", X"3882", X"28a3", X"cb7d", X"db5c",
                           X"eb3f", X"fb1e", X"8bf9", X"9bd8", X"abbb", X"bb9a",
                           X"4a75", X"5a54", X"6a37", X"7a16", X"0af1", X"1ad0",
                           X"2ab3", X"3a92", X"fd2e", X"ed0f", X"dd6c", X"cd4d",
                           X"bdaa", X"ad8b", X"9de8", X"8dc9", X"7c26", X"6c07",
                           X"5c64", X"4c45", X"3ca2", X"2c83", X"1ce0", X"0cc1",
                           X"ef1f", X"ff3e", X"cf5d", X"df7c", X"af9b", X"bfba",
                           X"8fd9", X"9ff8", X"6e17", X"7e36", X"4e55", X"5e74",
                           X"2e93", X"3eb2", X"0ed1", X"1ef0");
    attribute rom_style : string;
    attribute rom_style of lut : signal is "block";
begin

    s_in_tready <= tready and (not areset);

    G_FLIP_BYTE:
    for i in 0 to C_BYTEW - 1 generate
        flipped_byte(i) <= tdata_ddd(C_BYTEW - 1 - i);
        flipped_crc(i) <= next_crc(2*C_BYTEW - 1 - i);
        flipped_crc(C_BYTEW + i) <= next_crc(C_BYTEW - 1 - i);
    end generate G_FLIP_BYTE;

    x <= unsigned(flipped_byte xor crc_reg(C_CRCW - 1 downto C_CRCW/2));
    lut_out <= lut(to_integer(x));
    next_crc <= lut_out xor std_logic_vector(shift_left(unsigned(crc_reg), 8));

    crc_result <= flipped_crc xor (tdata_d(C_BYTEW-1 downto 0) & tdata_dd(C_BYTEW-1 downto 0));
    bad_crc <= or_reduction(crc_result) and tlast_d and (not tx_mode);

    -- Since we don't want to write the last two bytes of the PHY payload (the CRC) to the
    -- output buffer, we can't use a purely delayed version of the tvalid signal. Luckily,
    -- the delayed versions of tlast can be used to suppres the enable signal to the output
    -- buffer.
    tx_mode <= sr_crc_mode(0);
    sel_crc <= tlast_d; -- when tlast_dd=1, it is time to load the CRC sum into the last two bytes
    skip_crc <= (tlast_dd or tlast_ddd) and (not tx_mode);
    en_fifo <= tvalid_ddd and (not skip_crc);
    fifo_tlast <= tlast_ddd when (tx_mode = '1') else tlast_d;

    P_INPUT: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                tdata_d <= (others => '0');
                tdata_dd <= (others => '0');
                tdata_ddd <= (others => '0');
            else
                if (s_in_tvalid = '1') then
                    tdata_d <= s_in_tdata;
                end if;
                if (sel_crc = '1') then -- replace last two bytes with results of CRC calculations
                    tdata_dd <= X"000000" & flipped_crc(C_CRCW - 1 downto C_CRCW/2); 
                    tdata_ddd <= X"000000" & flipped_crc(C_CRCW/2 - 1 downto 0);
                else -- regular delay line
                    tdata_dd <= tdata_d;
                    tdata_ddd <= tdata_dd;
                end if;
            end if;
        end if;
    end process P_INPUT;

    P_TVALID: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                tvalid_d <= '0';
                tvalid_dd <= '0';
                tvalid_ddd <= '0';
            else
                tvalid_d <= s_in_tvalid;
                tvalid_dd <= tvalid_d;
                tvalid_ddd <= tvalid_dd;
            end if;
        end if;
    end process P_TVALID;

    P_TLAST: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                tlast_d <= '0';
                tlast_dd <= '0';
                tlast_ddd <= '0';
            else
                tlast_d <= s_in_tlast;
                tlast_dd <= tlast_d;
                tlast_ddd <= tlast_dd;
            end if;
        end if;
    end process P_TLAST;

    P_CRC_REG: process (aclk)
    begin
        if rising_edge(aclk) then
            -- When the last byte of the PHY payload (last byte of the CRC)
            -- is is stored in tdata_ddd and about to update the register, we
            -- instead clear the register since the next value that gets shifted
            -- into tdata_ddd belongs to a different frame.
            if (areset = '1' or tlast_ddd = '1') then
                crc_reg <= (others => '0');
            else
                -- Use a delayed version of tvalid so that crc_reg gets
                -- updated at the same time the byte that caused the update gets
                if (tvalid_ddd = '1') then
                    crc_reg <= next_crc;
                end if;
            end if;
        end if;
    end process P_crc_REG;

    z_ppfifo: zluudg_ppfifo 
        port map( aclk          => aclk,
                  areset        => areset,
                  almost_full   => int_almost_full,
                  skip_burst    => bad_crc,
                  s_axis_tready => tready,
                  s_axis_tdata  => tdata_ddd,
                  s_axis_tvalid => en_fifo,
                  -- When the last MAC payload byte is in tdata_ddd, tdata_d and tdata_dd
                  -- will hold the last byte of the PHY payload (the CRC). Since we don't
                  -- want to write the CRC to the output buffer, we use a not-as-delayed
                  -- tlast to properly signal to the output buffer that the end of the
                  -- MAC payload is being written.
                  s_axis_tlast  => fifo_tlast,
                  m_axis_tready => m_out_tready,
                  m_axis_tdata  => m_out_tdata,
                  m_axis_tvalid => m_out_tvalid,
                  m_axis_tlast  => m_out_tlast);

end Mixed;
