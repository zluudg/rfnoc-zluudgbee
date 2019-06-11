# Credit Where Credit is Due
A lot of these examples depend on code from the Wime project. Make sure to check it
out! For the project itself, visit https://www.wime-project.net/. For the code
that this repo depends on, visit https://github.com/bastibl/gr-ieee802-15-4.

# frame\_source.grc
A simple transmitter for generating random frames using the framework provided
by the Wime project.

# rx\_basic.grc
A simple receiver that outputs a message upon detection and logs all detections in a .pcap
file. If zluudgCRC is enabled in the flowgraph everything will still work. However, since
the CRC is expected to be present for .pcap-entry, Wireshark will point out that the checksum
has failed.i

# rx\_software.grc
Same as the above but implemented in pure software by using the PHY blocks + CRC algorithm from
the Wime project.

# zluudgbee\_dummycoord\_hybrid.grc
A simple transceiver acting as a "dummy coordinator". The operation is simple; if
the received frame is a beacon request frame then it replies with a beacon. Uses
"zluudgbee\_hybrid\_phy.grc" for transmitting and receiving.

# zluudgbee\_dummycoord\_software.grc
Same as "zluudgbee\_dummycoord\_hybrid.grc" but uses "zluudgbee\_software\_phy.grc" instead.
Can be used as a reference when testing the performance of "zluudgbee\_dummycoord\_hybrid.grc".

# zluudgbee\_hybrid\_phy.grc
A hybrid PHY were the transmitter is implemented purely in software and the receiver
is implemented in the USRP's FPGA. The transmitter design was taken directly from
https://github.com/bastibl/gr-ieee802-15-4, make sure to check it out. Also check out
https://www.wime-project.net/, a huge inspiration for the receiver design.

# zluudgbee\_software\_phy.grc
A hybrid PHY that is more or less an exact copy of the PHY designed by the Wime project.

# zluudgbee\_transceiver.grc
A simple transceiver that spams a 'Hello World!' frame for transmission while simultaneously
receving any valid frames. Again, a lot of code was borrowed from
https://github.com/bastibl/gr-ieee802-15-4. To use it, make sure that 'zluudgbee\_hybrid\_phy.grc'
is built first, as it is used as an hierarchical block in this flowgraph.

# zluudgbee\_X310\_RFNOC\_HG.bit
An FPGA image containing 1x DUC, 1x zluudgbeeRX, 1x zluudgbeeCRC and a bunch of FIFOs.
Flashing a USRP x310 device with this image is needed in order to run the above flowgraphs.
