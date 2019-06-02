----------------------------------------------------------------------------------------------------
-- Project: IT245X Degree Project in Microelectronics
-- Developer: Leon Fernandez
-- Component: constants (Custom package)
-- Description: Some useful constants and functions to make the code a bit
-- leaner and cleaner.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

package zluudg_constants is

----------------------------------------------------------------------------------------------------
------------------------------- USEFUL FUNCTIONS ---------------------------------------------------
----------------------------------------------------------------------------------------------------

    -- Function for calculating the minimal number of bits required to represent the input
    function clogb2(bit_depth : integer) return integer;

    -- Function for calculating the floor of the base 2 logarithm of the input
    function flogb2(bit_depth : integer) return integer;

    -- Function for calculating the minimal number of bytes required to contain a certain bitwidth
    function bytepad(n_bits : integer) return integer;

    -- Reduction OR operation for std_logic_vector
    function or_reduction(vec : std_logic_vector) return std_logic;

----------------------------------------------------------------------------------------------------
------------------------------- GLOBAL CONSTANTS ---------------------------------------------------
----------------------------------------------------------------------------------------------------
    -- The width of a byte
    constant C_BYTEW : integer := 8;

    -- The width of a chipsequence
    constant C_CHIPSEQW : integer := 32;

    -- The width of the I- or Q-part of the input samples
    constant C_SAMPLEW : integer := 16;

    -- The width of the entire complex input sample
    constant C_IQSAMPLEW : integer := 2*C_SAMPLEW;

    -- The width of the I- or Q-part of the product of two raw input I/Q-samples
    constant C_PRODW : integer := 2*C_SAMPLEW + 1;

    -- The width used to represent the phase of a complex number
    constant C_PHASEW : integer := 20;

    -- The width used to represent a chip before a hard decision is made, signed Q3.28
    constant C_CHIPW : integer := 20;

    -- The width (in bits) of a nibble
    constant C_NIBBLEW : integer := 4;

    -- The width of the component output. |Data|Crap1|Crap2|EOF|
    constant C_OUTW : integer := 32;

    -- The width of the PRNG generator
    constant C_PRNGW : integer := 32;

    -- The width of the byte counter for the payload segment (7 bits according to IEEE 802.15.4)
    constant C_BYTECOUNTERW : integer := 7;

    -- The width of the CRC checksum, 16 according to IEEE 802.15.4
    constant C_CRCW : integer := 16;

    -- The maximum depth of the MA-line, should always be a power of 2!
    constant C_MA_LINE_MAX : integer := 16;

    -- The width of the decimation rate settings register for the symbol synchronizer
    constant C_SETREGW : integer := 32;

    -- The number of differenct chip sequences representing a nibble
    constant C_NSEQ : integer := 16;

    -- The number of chips required to get a decoded byte
    constant C_DECIM_COUNTERW : integer := 16; -- Don't touch

    -- The number of chips required to get a decoded byte
    constant C_CHIPS_PER_BYTE : integer := C_CHIPSEQW*2; -- Don't touch

    -- The depth of the buffers in the output pingpong fifo
    constant C_FIFO_DEPTH : integer := 256;

    -- The depth of the buffers in the output pingpong fifo
    constant C_FIFO_ADDRW : integer := clogb2(C_FIFO_DEPTH);
    
    -- The last index of the buffers in the output pingpong fifo
    constant C_FIFO_END : integer := C_FIFO_DEPTH - 1;

    -- How many elements left of the output PDU before we set the "almost full" watermark
    constant C_WATERMARK_LIM : integer := 2;

    -- The number of elements in the sine lut for the transmitter
    constant C_SINLUT_SIZE : integer := 4;

    constant C_SINLUT_ADDRW : integer := clogb2(C_SINLUT_SIZE);

----------------------------------------------------------------------------------------------------
------------------------------- TESTBENCH-RELATED --------------------------------------------------
----------------------------------------------------------------------------------------------------

    -- Type of the input stumulus vector in the testbench
    type t_input is array(integer range <>) of std_logic_vector(C_IQSAMPLEW - 1 downto 0);

    -- Type of the output vector in the testbench
    type t_payload is array(integer range <>) of std_logic_vector(C_BYTEW - 1 downto 0);

    -- Function for getting the length of the payload used for reference in the testbench
    impure function tb_get_payload_length(filename : string) return integer;

    -- Function for getting the length of the input used for stimulus in the testbench
    impure function tb_get_input_length(filename : string) return integer;

    -- Function for getting the input stimulus vector
    impure function tb_get_input(filename : string; length : integer) return t_input;

    -- Function for getting the payload vector used for reference in the testbench
    impure function tb_get_reference_payload(filename : string; length : integer) return t_payload;

    procedure tb_report_ber(ref_pl, out_pl : t_payload);

end zluudg_constants;

package body zluudg_constants is

	 -- function called clogb2 that returns an integer which has the   
	 -- value of the ceiling of the log base 2.
	 -- NOTE: The returned value is the width of the 2's complement representation
	 -- of the input integer.
	 -- Borrowed from Xilinx Vivado autogenerated AXIS-code.
    function clogb2(bit_depth : integer) return integer is                  
        variable depth  : integer := bit_depth;                               
        variable count  : integer := 1;                                       
    begin                                                                   
        for clogb2 in 1 to bit_depth loop  -- Works for up to 32 bit integers
            if (bit_depth <= 2) then                                           
                count := 1;                                                      
            else                                                               
                if(depth <= 1) then                                              
                    count := count;                                                
                else                                                             
                depth := depth / 2;                                            
                count := count + 1;                                            
                end if;                                                          
            end if;                                                            
        end loop;                                                             
        return(count);        	                                              
    end;

    -- Similar to clogb2 except that the result is the FLOOR of the base 2 logarithm
    -- and it does so for the UNSIGNED REPRESENTATION of the input integer.
    function flogb2(bit_depth : integer) return integer is                  
        variable depth  : integer := bit_depth;                               
        variable count  : integer := 1;                                       
    begin                                                                   
        for flogb2 in 1 to bit_depth loop  -- Works for up to 32 bit integers
            if (bit_depth < 2) then                                           
                count := 0;                                                      
            else                                                               
                if(depth < 4) then                                              
                    count := count;                                                
                else                                                             
                depth := depth / 2;                                            
                count := count + 1;                                            
                end if;                                                          
            end if;                                                            
        end loop;                                                             
        return(count);        	                                              
    end;

    function or_reduction(vec : std_logic_vector) return std_logic is
        variable res : std_logic := '0';
    begin
        for i in vec'range loop
            res := res or vec(i);
        end loop;
        return res;
    end;

    -- AXIS tdata interfaces require an width equal to an integer number of bytes.
    -- E.g. if the output consists of 33 bits, the corresponding AXIS tdata interface
    -- must have a width of at least 40 (5 * 8). This function calculates the
    -- appropriate width for an AXIS tdata interface for a given number of bits.
    function bytepad(n_bits : integer) return integer is
    begin
        return (n_bits + (8-(n_bits mod 8)));
    end;

    impure function tb_get_payload_length(filename : string) return integer is
        file f : text;
        variable l : line;
        variable payload_length : integer := 0;
    begin
        file_open(f, filename, read_mode);

        while (not endfile(f)) loop
            readline(f, l);
            if (l(1) = '%') then
                payload_length := payload_length + 1;
            else
                -- Do nothing
            end if;
        end loop;

        file_close(f);

        return payload_length;
    end;

    impure function tb_get_input_length(filename : string) return integer is
        file f : text;
        variable l : line;
        variable input_length : integer := 0;
    begin
        file_open(f, filename, read_mode);

        while (not endfile(f)) loop
            readline(f, l);
            if (l(1) = '#' or l(1) = '%') then
                -- Do nothing
            else
                input_length := input_length + 1;
            end if;
        end loop;

        file_close(f);

        return input_length;
    end;

    impure function tb_get_input(filename : string; length : integer) return t_input is
        file f : text;
        variable l : line;
        variable stim_vector : t_input(0 to length - 1);
        variable stim_i : integer;
        variable stim_q : integer;
        variable iqsample : std_logic_vector(C_IQSAMPLEW - 1 downto 0);
    begin
        file_open(f, filename, read_mode);

        for j in 0 to length-1 loop
            readline(f, l);

            while (l(1) = '#' or l(1) = '%') loop
                readline(f, l);
            end loop;

            read(l, stim_i);
            read(l, stim_q);

            iqsample(C_IQSAMPLEW - 1 downto C_SAMPLEW) :=
                std_logic_vector(to_signed(stim_q, C_SAMPLEW));
            iqsample(C_SAMPLEW - 1 downto 0) :=
                std_logic_vector(to_signed(stim_i, C_SAMPLEW));

            stim_vector(j) := iqsample;

        end loop;

        file_close(f);

        return stim_vector;
    end;

    impure function tb_get_reference_payload(filename : string; length : integer) return t_payload is
        file f : text;
        variable l : line;
        variable b : integer;
        variable c : character;
        variable payload_vector : t_payload(0 to 126) := (others => (others => '0'));
    begin
        file_open(f, filename, read_mode);

        for j in 0 to length-1 loop
            readline(f, l);
    
            while (l(1) /= '%') loop
                readline(f, l);
            end loop;
    
            read(l, c); -- Read percentage sign into garbage variable
            read(l, b);
    
            payload_vector(j) := std_logic_vector(to_unsigned(b, C_BYTEW));
    
        end loop;

        file_close(f);

        return payload_vector;
    end;

    procedure tb_report_ber(ref_pl, out_pl : t_payload) is
        file f : text;
        variable l : line;
        variable ref_byte : integer;
        variable out_byte : integer;
    begin
        file_open(f, "ber_report.txt", write_mode);

        writeline(f, l);
        for j in 0 to ref_pl'length-1 loop
            ref_byte := to_integer(unsigned(ref_pl(j)));
            out_byte := to_integer(unsigned(out_pl(j)));
            write(l, integer'image(ref_byte) & "   " & integer'image(out_byte));
            writeline(f, l);
        end loop;
        file_close(f);
    end;

end zluudg_constants;
