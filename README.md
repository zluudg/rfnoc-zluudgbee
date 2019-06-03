# Introduction
Some simple blocks for GNU Radio Companion that uses RFNoC to implement parts of
the IEEE 802.15.4 standard on the FPGA in certain USRP devices.

# Installation
```
mkdir build
cd build
cmake ..
make
sudo make install
```

# Log
1/6-2019: Created OOT module.
          UHD: rfnoc-devel, eec24d7b0442616fdbe9adf6b426959677e67f9
          GNU Radio: maint-3.7, ???
          gr-ettus: master, ???

2/6-2019: Re-created OOT module and took note of current commits.
          Added blocks 'zluudgbeeRX' and 'zluudgbeeCRC'.
          UHD: rfnoc-devel,     eec24d7b0442616fdbe9adf6b426959677e67f92
          GNU Radio: maint-3.7, 9e04b27bc4c96f95215b727ba3320812faa8d6aa
          gr-ettus: master,     e0d2b91866a2a8d35f4822629edc3c1eeed8585b
