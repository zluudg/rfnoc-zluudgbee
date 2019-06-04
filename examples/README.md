# rx\_basic.grc
A simple receiver that outputs a message upon detection and logs all detections in a .pcap
file. If zluudgCRC is enabled in the flowgraph everything will still work. However, since
the CRC is expected to be present for .pcap-entry, Wireshark will point out that the checksum
has failed.i

# zluudgbee\_hybrid\_phy.grc
A hybrid PHY were the transmitter is implemented purely in software and the receiver
is implemented in the USRP's FPGA. The transmitter design was taken directly from
https://github.com/bastibl/gr-ieee802-15-4, make sure to check it out. Also check out
https://www.wime-project.net/, a huge inspiration for the receiver design.

# zluudgbee\_transceiver.grc
A simple transceiver that spams a 'Hello World!' frame for transmission while simultaneously
receving any valid frames. Again, a lot of code was borrowed from
https://github.com/bastibl/gr-ieee802-15-4. To use it, make sure that 'zluudgbee\_hybrid\_phy.grc'
is built first, as it is used as an hierarchical block in this flowgraph.

# zluudgbee\_X310\_RFNOC\_HG.bit
An FPGA image containing 1x DUC, 1x zluudgbeeRX, 1x zluudgbeeCRC and a bunch of FIFOs.
Flashing a USRP x310 device with this image is needed in order to run the above flowgraphs.
