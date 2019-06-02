
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.zluudg_constants.all;

entity zluudg_ram is
    port ( aclk  : in  std_logic;
           ena   : in  std_logic;
           addra : in  std_logic_vector(C_FIFO_ADDRW - 1 downto 0);
           addrb : in  std_logic_vector(C_FIFO_ADDRW - 1 downto 0);
           dia   : in  std_logic_vector(C_OUTW - 1 downto 0);
           dob   : out std_logic_vector(C_OUTW - 1 downto 0));
end zluudg_ram;

architecture Behavioral of zluudg_ram is
    
    type ram_type is array (C_FIFO_DEPTH - 1 downto 0) of std_logic_vector(C_OUTW - 1 downto 0);
    signal ram : ram_type := (others => (others => '0'));

begin

    P_WRITE: process (aclk)
    begin
        if rising_edge(aclk) then
            if (ena = '1') then
                ram(to_integer(unsigned(addra))) <= dia;
            end if;
        end if;
    end process P_WRITE;

    P_READ: process (aclk)
    begin
        if rising_edge(aclk) then
            dob <= ram(to_integer(unsigned(addrb)));
        end if;
    end process P_READ;

end Behavioral;
