--VHDL instantiation template

component aud_fifo is
    port (aud_fifo_ip_Data: in std_logic_vector(15 downto 0);
        aud_fifo_ip_Q: out std_logic_vector(15 downto 0);
        aud_fifo_ip_AlmostEmpty: out std_logic;
        aud_fifo_ip_AlmostFull: out std_logic;
        aud_fifo_ip_Clock: in std_logic;
        aud_fifo_ip_Empty: out std_logic;
        aud_fifo_ip_Full: out std_logic;
        aud_fifo_ip_RdEn: in std_logic;
        aud_fifo_ip_Reset: in std_logic;
        aud_fifo_ip_WrEn: in std_logic
    );
    
end component aud_fifo; -- sbp_module=true 
_inst: aud_fifo port map (aud_fifo_ip_Data => __,aud_fifo_ip_Q => __,aud_fifo_ip_AlmostEmpty => __,
            aud_fifo_ip_AlmostFull => __,aud_fifo_ip_Clock => __,aud_fifo_ip_Empty => __,
            aud_fifo_ip_Full => __,aud_fifo_ip_RdEn => __,aud_fifo_ip_Reset => __,
            aud_fifo_ip_WrEn => __);
