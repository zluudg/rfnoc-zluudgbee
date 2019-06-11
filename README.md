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

# Dependencies
| Repo                   | Branch      | Commit
|------------------------|-------------|-----------------------------------------
| ettusresearch/uhd      | rfnoc-devel | eec24d7b0442616fdbe9adf6b426959677e67f92
| gnuradio/gnuradio      | maint-3.7   | 9e04b27bc4c96f95215b727ba3320812faa8d6aa
| ettusresearch/gr-ettus | master      | e0d2b91866a2a8d35f4822629edc3c1eeed8585b
| bastibl/gr-foo         | maint-3.7   | a2d8670313b846bc6aded3f123b02a960e59b4e6
| bastibl/gr-ieee-15-4   | maint-3.7   | d3d94023c71af9e6d7721f7412fba88ff5325234



