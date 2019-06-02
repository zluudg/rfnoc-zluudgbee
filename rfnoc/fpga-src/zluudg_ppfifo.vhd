----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: ppfifo (Output R/W buffer)
-- Description: An output pingpong-buffer for facilitating
-- reads/writes by RFNoC
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_ppfifo is
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
end zluudg_ppfifo;

architecture Mixed of zluudg_ppfifo is

    component zluudg_ram is
        port ( aclk  : in  std_logic;
               ena   : in  std_logic;
               addra : in  std_logic_vector(C_FIFO_ADDRW - 1 downto 0);
               addrb : in  std_logic_vector(C_FIFO_ADDRW - 1 downto 0);
               dia   : in  std_logic_vector(C_OUTW - 1 downto 0);
               dob   : out std_logic_vector(C_OUTW - 1 downto 0));
    end component zluudg_ram;

    -- Read and write pointers for the fifos. Goes to one higher than the highest
    -- index since the reading is done up until the index before the write pointer.
    signal w1_ptr : integer range 0 to C_FIFO_DEPTH-1 := 0;
    signal r1_ptr : integer range 0 to C_FIFO_DEPTH-1 := 0;
    signal w2_ptr : integer range 0 to C_FIFO_DEPTH-1 := 0;
    signal r2_ptr : integer range 0 to C_FIFO_DEPTH-1 := 0;

    type t_state is (s_MA,    -- Mode A: Reading from fifo2,   writing to fifo1
                     s_MA_R,  -- Mode A: Read from fifo2 done, writing to fifo1
                     s_MA_W,  -- Mode A: Reading from fifo2,   write to fifo1 done
                     s_MB,    -- Mode B: Reading from fifo1,   writing to fifo2
                     s_MB_R,  -- Mode B: Read from fifo1 done, writing to fifo2
                     s_MB_W); -- Mode B: Reading from fifo1,   write to fifo2 done
    signal state : t_state := s_MA;

    -- Flags to indicate whether a fifo buffer is corrupted or not. If
    -- a flag is set when the mode changes the corresponding fifo buffer
    -- will not be outputted. A flag will be asserted if during the writing
    -- process the word has a '1' in the 12th position (counting from 0).
    signal skip_fifo1 : std_logic := '0';
    signal skip_fifo2 : std_logic := '0';

    signal fifo1_ena    : std_logic := '0';
    signal fifo1_addra  : std_logic_vector(C_FIFO_ADDRW - 1 downto 0) := (others => '0');
    signal fifo1_addrb  : std_logic_vector(C_FIFO_ADDRW - 1 downto 0) := (others => '0');
    signal fifo1_in     : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');
    signal fifo1_out    : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');
    signal fifo2_ena    : std_logic := '0';
    signal fifo2_addra  : std_logic_vector(C_FIFO_ADDRW - 1 downto 0) := (others => '0');
    signal fifo2_addrb  : std_logic_vector(C_FIFO_ADDRW - 1 downto 0) := (others => '0');
    signal fifo2_in     : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');
    signal fifo2_out    : std_logic_vector(C_OUTW - 1 downto 0) := (others => '0');

    signal sel_fifo : std_logic := '0';

    -- Signal that is asserted once the first write after reset has been completed
    signal initialized : std_logic := '0';
begin

    with sel_fifo select m_axis_tdata <=
        fifo1_out when '1',
        fifo2_out when others;

    fifo1_in <= s_axis_tdata;
    fifo2_in <= s_axis_tdata;
    fifo1_addra <= std_logic_vector(to_unsigned(w1_ptr, C_FIFO_ADDRW));
    fifo1_addrb <= std_logic_vector(to_unsigned(r1_ptr, C_FIFO_ADDRW));
    fifo2_addra <= std_logic_vector(to_unsigned(w2_ptr, C_FIFO_ADDRW));
    fifo2_addrb <= std_logic_vector(to_unsigned(r2_ptr, C_FIFO_ADDRW));
    fifo1_ena <= s_axis_tvalid when (state = s_MA or state = s_MA_R) else '0';
    fifo2_ena <= s_axis_tvalid when (state = s_MB or state = s_MB_R) else '0';

    

    fifo1: zluudg_ram
        port map( aclk  => aclk,
                  ena   => fifo1_ena,
                  addra => fifo1_addra,
                  addrb => fifo1_addrb,
                  dia   => fifo1_in,
                  dob   => fifo1_out);

    fifo2: zluudg_ram
        port map( aclk  => aclk,
                  ena   => fifo2_ena,
                  addra => fifo2_addra,
                  addrb => fifo2_addrb,
                  dia   => fifo2_in,
                  dob   => fifo2_out);

    P_PPFIFO: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                state <= s_MA;
                w1_ptr <= 0;
                r1_ptr <= 0;
                w2_ptr <= 0;
                r2_ptr <= 0;
                skip_fifo1 <= '0';
                skip_fifo2 <= '0';
                initialized <= '0';

            else
                case state is

                    when s_MA =>
                        if (m_axis_tready = '1' and s_axis_tvalid = '1') then
                            if ((w1_ptr = C_FIFO_END or s_axis_tlast = '1') and r2_ptr = w2_ptr) then
                                if (skip_fifo1 = '1'  or skip_burst = '1') then
                                    state <= s_MB_R; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo1 <= '0';
                                else
                                    state <= s_MB; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= w1_ptr;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo1 <= '0';
                                end if;
                                initialized <= '1';
    
                            elsif (w1_ptr = C_FIFO_END or s_axis_tlast = '1') then
                                state <= s_MA_W;
                                r2_ptr <= r2_ptr + 1;
                                if (skip_burst = '1') then
                                    skip_fifo1 <= '1';
                                else
                                    skip_fifo1 <= skip_fifo1;
                                end if;
    
                            elsif (r2_ptr = w2_ptr) then
                                state <= s_MA_R;
                                w1_ptr <= w1_ptr + 1;
                                if (skip_burst = '1') then
                                    skip_fifo1 <= '1';
                                else
                                    skip_fifo1 <= skip_fifo1;
                                end if;
    
                            else
                                state <= state;
                                r2_ptr <= r2_ptr + 1;
                                w1_ptr <= w1_ptr + 1;
                                if (skip_burst = '1') then
                                    skip_fifo1 <= '1';
                                else
                                    skip_fifo1 <= skip_fifo1;
                                end if;
                            end if;
    
                        elsif (m_axis_tready = '1' and s_axis_tvalid = '0') then
                            if (r2_ptr = w2_ptr) then
                                state <= s_MA_R;
                            else
                                state <= state;
                                r2_ptr <= r2_ptr + 1;
                            end if;
    
                        elsif (m_axis_tready = '0' and s_axis_tvalid = '1') then
                            if (skip_burst = '1') then
                                skip_fifo1 <= '1';
                            else
                                skip_fifo1 <= skip_fifo1;
                            end if;
                            if (w1_ptr = C_FIFO_END or s_axis_tlast = '1') then
                                state <= s_MA_W;
                            else
                                state <= state;
                                w1_ptr <= w1_ptr + 1;
                            end if;
    
                        end if;
    
                    when s_MA_R =>
                        if (s_axis_tvalid = '1') then
                            if (skip_burst = '1') then
                                skip_fifo1 <= '1';
                            else
                                skip_fifo1 <= skip_fifo1;
                            end if;

                            if (w1_ptr = C_FIFO_END or s_axis_tlast = '1') then
                                if (skip_burst = '1' or skip_fifo1 = '1') then
                                    state <= s_MB_R; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo1 <= '0';
                                else
                                    state <= s_MB; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= w1_ptr;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo1 <= '0';
                                end if;
                                initialized <= '1';

                            else
                                state <= state;
                                w1_ptr <= w1_ptr + 1;
                            end if;
                        end if;
    
                    when s_MA_W =>
                        if (m_axis_tready = '1') then
                            if (r1_ptr = w1_ptr) then
                                if (skip_fifo2 = '1') then
                                    state <= s_MB_R; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo1 <= '0';
                                else
                                    state <= s_MB; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= w1_ptr;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo1 <= '0';
                                end if;
                                initialized <= '1';
                            else
                                state <= state;
                                r1_ptr <= r1_ptr + 1;
                            end if;
                        end if;

                    when s_MB =>
                        if (m_axis_tready = '1' and s_axis_tvalid = '1') then
                            if ((w2_ptr = C_FIFO_END or s_axis_tlast = '1') and r1_ptr = w1_ptr) then
                                if (skip_fifo2 = '1'  or skip_burst = '1') then
                                    state <= s_MA_R; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo2 <= '0';
                                else
                                    state <= s_MA; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= w2_ptr;
                                    skip_fifo2 <= '0';
                                end if;

                            elsif (w2_ptr = C_FIFO_END or s_axis_tlast = '1') then
                                state <= s_MB_W;
                                r1_ptr <= r1_ptr + 1;
                                if (skip_burst = '1') then
                                    skip_fifo2 <= '1';
                                else
                                    skip_fifo2 <= skip_fifo2;
                                end if;

                            elsif (r1_ptr = w1_ptr) then
                                state <= s_MB_R;
                                w2_ptr <= w2_ptr + 1;
                                if (skip_burst = '1') then
                                    skip_fifo2 <= '1';
                                else
                                    skip_fifo2 <= skip_fifo2;
                                end if;

                            else
                                state <= state;
                                r1_ptr <= r1_ptr + 1;
                                w2_ptr <= w2_ptr + 1;
                                if (skip_burst = '1') then
                                    skip_fifo2 <= '1';
                                else
                                    skip_fifo2 <= skip_fifo2;
                                end if;
                            end if;

                        elsif (m_axis_tready = '1' and s_axis_tvalid = '0') then
                            if (r1_ptr = w1_ptr) then
                                state <= s_MB_R;
                            else
                                state <= state;
                                r1_ptr <= r1_ptr + 1;
                            end if;
    
                        elsif (m_axis_tready = '0' and s_axis_tvalid = '1') then
                            if (skip_burst = '1') then
                                skip_fifo2 <= '1';
                            else
                                skip_fifo2 <= skip_fifo2;
                            end if;
                            if (w2_ptr = C_FIFO_END or s_axis_tlast = '1') then
                                state <= s_MB_W;
                            else
                                state <= state;
                                w2_ptr <= w2_ptr + 1;
                            end if;

                        end if;

                    when s_MB_R =>
                        if (s_axis_tvalid = '1') then
                            if (skip_burst = '1') then
                                skip_fifo2 <= '1';
                            else
                                skip_fifo2 <= skip_fifo2;
                            end if;
                            if (w2_ptr = C_FIFO_END or s_axis_tlast = '1') then
                                if (skip_burst = '1' or skip_fifo2 = '1') then
                                    state <= s_MA_R; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo2 <= '0';
                                else
                                    state <= s_MA; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= w2_ptr;
                                    skip_fifo2 <= '0';
                                end if;

                            else
                                state <= state;
                                w2_ptr <= w2_ptr + 1;
                            end if;
                        end if;

                    when s_MB_W =>
                        if (m_axis_tready = '1') then
                            if (r1_ptr = w1_ptr) then
                                if (skip_fifo2 = '1') then
                                    state <= s_MA_R; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= 0;
                                    skip_fifo2 <= '0';
                                else
                                    state <= s_MA; -- Change mode
                                    r1_ptr <= 0;
                                    w1_ptr <= 0;
                                    r2_ptr <= 0;
                                    w2_ptr <= w2_ptr;
                                    skip_fifo2 <= '0';
                                end if;
                            else
                                state <= state;
                                r1_ptr <= r1_ptr + 1;
                            end if;
                        end if;

                    when others =>
                        state <= s_MA;
                        w1_ptr <= 0;
                        r1_ptr <= 0;
                        w2_ptr <= 0;
                        r2_ptr <= 0;
                        skip_fifo1 <= '0';
                        skip_fifo2 <= '0';
                        initialized <= '0';
                end case;
            end if;
        end if;
    end process P_PPFIFO;

    P_STATE_DECODE: process (aclk)
    begin
        if rising_edge(aclk) then
            if (areset = '1') then
                m_axis_tvalid <= '0';
                m_axis_tlast <= '0';
                s_axis_tready <= '0';
                almost_full <= '0';
                sel_fifo <= '0';
            else
                case state is
                    when s_MA =>
                        m_axis_tvalid <= initialized;
                        if (r2_ptr=w2_ptr) then
                            m_axis_tlast <= initialized;
                        else
                            m_axis_tlast <= '0';
                        end if;
                        s_axis_tready <= '1';
                        if (w1_ptr >= C_FIFO_END-C_WATERMARK_LIM) then
                            almost_full <= '1';
                        else
                            almost_full <= '0';
                        end if;
                        sel_fifo <= '0';
        
                    when s_MA_R =>
                        m_axis_tvalid <= '0';
                        m_axis_tlast <= '0';
                        s_axis_tready <= '1';
                        if (w1_ptr >= C_FIFO_END-C_WATERMARK_LIM) then
                            almost_full <= '1';
                        else
                            almost_full <= '0';
                        end if;
                        sel_fifo <= '0';
        
                    when s_MA_W =>
                        m_axis_tvalid <= '1';
                        if (r2_ptr=w2_ptr) then
                            m_axis_tlast <= '1';
                        else
                            m_axis_tlast <= '0';
                        end if;
                        s_axis_tready <= '0';
                        if (w1_ptr >= C_FIFO_END-C_WATERMARK_LIM) then
                            almost_full <= '1';
                        else
                            almost_full <= '0';
                        end if;
                        sel_fifo <= '0';
        
                    when s_MB =>
                        m_axis_tvalid <= '1';
                        if (r1_ptr=w1_ptr) then
                            m_axis_tlast <= '1';
                        else
                            m_axis_tlast <= '0';
                        end if;
                            s_axis_tready <= '1';
                        if (w2_ptr >= C_FIFO_END-C_WATERMARK_LIM) then
                            almost_full <= '1';
                        else
                            almost_full <= '0';
                        end if;
                        sel_fifo <= '1';
                
                    when s_MB_R =>
                        m_axis_tvalid <= '0';
                        m_axis_tlast <= '0';
                        s_axis_tready <= '1';
                        if (w2_ptr >= C_FIFO_END-C_WATERMARK_LIM) then
                            almost_full <= '1';
                        else
                            almost_full <= '0';
                        end if;
                        sel_fifo <= '1';
                
                    when s_MB_W =>
                        m_axis_tvalid <= '1';
                        if (r1_ptr=w1_ptr) then
                            m_axis_tlast <= '1';
                        else
                            m_axis_tlast <= '0';
                        end if;
                        s_axis_tready <= '0';
                        if (w2_ptr >= C_FIFO_END-C_WATERMARK_LIM) then
                            almost_full <= '1';
                        else
                            almost_full <= '0';
                        end if;
                        sel_fifo <= '1';
        
                    when others =>
                        m_axis_tvalid <= '0';
                        m_axis_tlast <= '0';
                        s_axis_tready <= '0';
                        almost_full <= '0';
                        sel_fifo <= '0';
                end case;
            end if;
        end if;
    end process P_STATE_DECODE;

end Mixed;
