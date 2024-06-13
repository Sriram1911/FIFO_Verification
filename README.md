# FIFO_Verification
This micro project verifies the FIFO using SystemVerilog through a set of generators, driver, monitor and scoreboard
This project utilises a single clock FIFO as DUT which can store 64 8-bit data. We have a generator which generates random sequences and sends it to a driver.
The driver then applies this sequence to the DUT which is then read by the montor. (Important point is to note that data applied doesn't generate 
results immediatley. There's a clock cycle delay in it.
The monitor reads the data from DUT and sends it to scoreboard which compares the corresponding output signals of DUT based on whether read or write is being done.
