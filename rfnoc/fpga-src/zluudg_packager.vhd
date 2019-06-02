----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: packager (For re-packaging a stream of nibbles into a PHY payload)
-- Description: Takes a stream of input nibbles and packages them into a stream of
-- bytes representing the payload. When the payload has been output, the last payload byte is
-- marked with "tlast" and the detector is cleared, meaning a new frame is being scanned for.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_packager is
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
end zluudg_packager;

architecture Behavioral of zluudg_packager is

    -- State type + signal that keeps track of where we are in the frame processing. That is, if we
    -- are reading from the PHR or from the actual payload, how much is left to read
    -- of the payload and if we can accept a decoded chipsequence from upstream.
    type t_state is (s_IDLE, s_PHR_PART, s_PHR_DONE, s_PL_IDLE, s_PL_PART, s_PL_DONE);
    signal state : t_state := s_IDLE;

    -- Signal for keeping track of how many bytes we've left to output before the
    -- payload segment ends.
    signal byte_counter : unsigned(C_BYTECOUNTERW - 1 downto 0) := (others => '0');

    signal int_m_outbyte_tdata : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');
    signal int_m_outbyte_tvalid : std_logic := '0';
    signal int_m_outbyte_tlast : std_logic := '0';

    signal int_frame_done : std_logic := '0';

    signal int_nibble_tdata : std_logic_vector(C_BYTEW - 1 downto 0) := (others => '0');

    -- Signal that is asserted when the PHR is decoded crappily, in which case we
    -- don't want to continue decoding and we therefore reset the detector.
    signal crappy_phr : std_logic := '0';

begin

    s_nibble_tready <= m_outbyte_tready and (not areset);

    m_outbyte_tdata <= int_m_outbyte_tdata;
    m_outbyte_tvalid <= int_m_outbyte_tvalid;
    m_outbyte_tlast <= int_m_outbyte_tlast;
    frame_done <= int_frame_done;

    P_INPUT_REG: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                int_nibble_tdata <= (others => '0');
            else
                if (s_nibble_tvalid = '1') then
                    int_nibble_tdata <= s_nibble_tdata;
                end if;
            end if;
        end if;
    end process P_INPUT_REG;

    P_FSM: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                state <= s_IDLE;
                byte_counter <= (others => '0');
                crappy_phr <= '0';
            else
                case state is

                    when s_IDLE =>
                        if (s_nibble_tvalid = '1') then
                            state <= s_PHR_PART;
                            crappy_phr <= s_nibble_tdata(4);
                            byte_counter(3 downto 0) <= unsigned(s_nibble_tdata(3 downto 0));
                        else
                            state <= s_IDLE;
                        end if;

                    when s_PHR_PART =>
                        if (s_nibble_tvalid = '1') then
                            state <= s_PHR_DONE;
                            if (crappy_phr = '1' or s_nibble_tdata(4) = '1') then
                                -- Either this or the previous nibble was crappy, so we don't
                                -- the value in our byte counter. We therefore set the byte counter
                                -- length to zero to treat the frame as degenerate.
                                byte_counter <= (others => '0');
                            else
                                byte_counter(6 downto 4) <= unsigned(s_nibble_tdata(2 downto 0));
                            end if;
                        else
                            state <= s_PHR_PART;
                        end if;

                    when s_PHR_DONE =>
                        if (byte_counter = 0) then --Degenerate case when payload has zero length
                            if (s_nibble_tvalid = '1') then
                                state <= s_PHR_PART;
                            else
                                state <= s_IDLE;
                            end if;
                        elsif (s_nibble_tvalid = '1') then
                            state <= s_PL_PART;
                        else
                            state <= s_PHR_DONE;
                        end if;

                    when s_PL_IDLE =>
                        if (s_nibble_tvalid = '1') then
                            state <= s_PL_PART;
                        else
                            state <= s_PL_IDLE;
                        end if;

                    when s_PL_PART =>
                        if (s_nibble_tvalid = '1') then
                            state <= s_PL_DONE;
                            byte_counter <= byte_counter - 1;
                        else
                            state <= s_PL_PART;
                        end if;

                    when s_PL_DONE =>
                        if (m_outbyte_tready = '0') then
                            state <= s_PL_DONE;
                        else
                            if (s_nibble_tvalid = '0') then
                                if (byte_counter = 0) then
                                    state <= s_IDLE;
                                else
                                    state <= s_PL_IDLE;
                                end if;
                            else
                                if (byte_counter = 0) then
                                    state <= s_PHR_PART;
                                else
                                    state <= s_PL_PART;
                                end if;
                            end if;
                        end if;

                    when others =>
                        state <= s_IDLE;

                end case;
            end if;
        end if;
    end process P_FSM;


    -- State decoder for internal and output signals
    P_FSM_DECODE: process (aclk)
    begin
        if rising_edge(aclk) then
            case state is
                when s_IDLE =>
                    int_m_outbyte_tvalid <= '0';
                    int_m_outbyte_tlast <= '0';
                    int_frame_done <= '0';

                when s_PHR_PART =>
                    int_m_outbyte_tvalid <= '0';
                    int_m_outbyte_tlast <= '0';
                    int_frame_done <= '0';    
    
                when s_PHR_DONE =>
                    int_m_outbyte_tvalid <= '0';
                    int_m_outbyte_tlast <= '0';
                    if (byte_counter = 0) then
                        int_frame_done <= '1';
                    else
                        int_frame_done <= '0';
                    end if;                

                when s_PL_IDLE =>
                    int_m_outbyte_tvalid <= '0';
                    int_m_outbyte_tlast <= '0';
                    int_frame_done <= '0';
        
                when s_PL_PART =>
                    int_m_outbyte_tvalid <= '0';
                    int_m_outbyte_tlast <= '0';
                    int_frame_done <= '0';
                    int_m_outbyte_tdata(C_NIBBLEW - 1 downto 0) <=
                        int_nibble_tdata(C_NIBBLEW - 1 downto 0);
    
                when s_PL_DONE =>
                    int_m_outbyte_tvalid <= '1';
                    if (byte_counter = 0) then
                        int_m_outbyte_tlast <= '1';
                        int_frame_done <= '1';
                    else
                        int_m_outbyte_tlast <= '0';
                        int_frame_done <= '0';
                    end if;

                    int_m_outbyte_tdata(C_BYTEW - 1 downto C_NIBBLEW) <=
                        int_nibble_tdata(C_NIBBLEW - 1 downto 0);
    
                when others =>
                    int_m_outbyte_tvalid <= '0';
                    int_m_outbyte_tlast <= '1';
                    int_frame_done <= '0';
                    int_m_outbyte_tdata <= (others => '0');

            end case;
        end if;
    end process P_FSM_DECODE; 


end Behavioral;