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
