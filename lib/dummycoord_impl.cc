/* -*- c++ -*- */
/* 
 * Copyright 2019 Leon Fernandez (zluudg).
 * 
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this software; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <zluudgbee/dummycoord.h>
#include <gnuradio/io_signature.h>
#include <gnuradio/block_detail.h>

#include <iostream>
#include <iomanip>

using namespace gr::zluudgbee;

class dummycoord_impl : public dummycoord {

public:

  dummycoord_impl(int pan_id, long src_addr, bool short_addr_mode, long epid) :
    block("dummycoord", gr::io_signature::make(0, 0, 0), gr::io_signature::make(0, 0, 0)),
    _pan_id(pan_id),
    _src_addr(src_addr),
    _short_addr_mode(short_addr_mode),
    _epid(epid) {

	  message_port_register_in(pmt::mp("pdu in"));
	  set_msg_handler(pmt::mp("pdu in"), boost::bind(&dummycoord_impl::handle_pdu, this, _1));

  	message_port_register_out(pmt::mp("pdu out"));
  }

  ~dummycoord_impl() {

  }

  void handle_pdu(pmt::pmt_t msg) {
	  pmt::pmt_t blob;

	  if(pmt::is_pair(msg)) {
		  blob = pmt::cdr(msg);
	  } else {
		  assert(false);
	  }
    size_t pdu_len = pmt::blob_length(blob);

    uint8_t *pdu_ptr = (uint8_t *) pmt::blob_data(blob);
    uint8_t frame_type = pdu_ptr[0] & FRAME_TYPE_MASK;

    if (frame_type == BEACON_FRAME) {
      handle_beacon_frame(blob);
    }
    else if (frame_type == DATA_FRAME) {
      handle_data_frame(blob);
    }
    else if (frame_type == ACK_FRAME) {
      handle_ack_frame(blob);
    }
    else if (frame_type == COMMAND_FRAME) {
      handle_command_frame(blob);
    }
    else // Some other frame type
      std::cout << "Unrecognized frame type! Dropping frame..." << std::endl;
    return;
  }


private:
  static const uint8_t FRAME_TYPE_MASK = 0x07;
  static const uint8_t BEACON_FRAME = 0x00;
  static const uint8_t DATA_FRAME = 0x01;
  static const uint8_t ACK_FRAME = 0x02;
  static const uint8_t COMMAND_FRAME = 0x03;
  static const uint8_t BEACON_REQ_CMD = 0x07;

  char _macBsn = 1;
  int _pan_id;
  long _src_addr;
  bool _short_addr_mode;
  long _epid;

  void handle_beacon_frame(pmt::pmt_t blob) {
    std::cout << "Beacon frame received! But no handler has been implemented..." << std::endl;
  }

  void handle_data_frame(pmt::pmt_t blob) {
    std::cout << "Data frame received! But no handler has been implemented..." << std::endl;
  }

  void handle_ack_frame(pmt::pmt_t blob) {
    std::cout << "ACK frame received! But no handler has been implemented..." << std::endl;
  }

  void handle_command_frame(pmt::pmt_t blob) {
    std::cout << "Command frame received! Attempting to handle..." << std::endl;

    uint8_t *pdu_ptr = (uint8_t *) pmt::blob_data(blob);
    uint8_t command_type = pdu_ptr[7];

    if (command_type = BEACON_REQ_CMD) {
      std::vector<uint8_t> beacon;
      int short_addr_mode_lim = (_short_addr_mode) ? 2 : 8;

      // MHR field for beacons according to 802.15.4
      beacon.push_back(0x00);
      if (_short_addr_mode)
        beacon.push_back(0x80); // Short addressing mode
      else
        beacon.push_back(0xc0); // Long addressing mode

      // Sequence number field according to 802.15.4
      beacon.push_back(_macBsn);
      _macBsn++;

      // Source addressing fields, no destination needed for beacons
      beacon.push_back((uint8_t) _pan_id & 0xFF);
      beacon.push_back((uint8_t) (_pan_id >> 8) & 0xFF);
      for (int i=0; i<short_addr_mode_lim; i++)
        beacon.push_back((uint8_t) (_src_addr >> i*8) & 0xFF);

      // Superframe specification, TODO look into purpose of Final CAP slot field
      beacon.push_back(0xFF); 
      beacon.push_back(0xCF); 

      // Guaranteed time slot configuration (there will be no guaranteed time slots)
      beacon.push_back(0x00);

      // Pending address field, I have no idea what this field is for TODO find out
      beacon.push_back(0x00);

      // Zigbee specific beacon field
      beacon.push_back(0x00); // protocol ID
      beacon.push_back(0x20); // Stack profile TODO find out more
      beacon.push_back(0x84); // Stack profile TODO find out more
      for (int i=0; i<8; i++)
        beacon.push_back((uint8_t) (_epid >> i*8) & 0xFF); // extended PAN ID

      beacon.push_back(0xFF); // TX offset TODO find out more
      beacon.push_back(0xFF); // TX offset TODO find out more
      beacon.push_back(0xFF); // TX offset TODO find out more

      beacon.push_back(0x00); // Update ID TODO find out more

      pub_output(beacon);
    }
  }

  void pub_output(std::vector<uint8_t>& bytes) {
      int len = (int) bytes.size();
      uint16_t crc = crc16(&bytes[0], len);
      bytes.push_back(crc & 0xFF);
      bytes.push_back((crc >> 8) & 0xFF);
      len = (int) bytes.size();
      pmt::pmt_t vector = pmt::init_u8vector(len, &bytes[0]);
      pmt::pmt_t pdu = pmt::cons(pmt::make_dict(), vector);
      message_port_pub(pmt::mp("pdu out"), pdu);
  }

  uint16_t crc16(uint8_t *buf, int len) {
	  uint16_t crc = 0;

	  for(int i = 0; i < len; i++) {
		  for(int k = 0; k < 8; k++) {
			  int input_bit = (!!(buf[i] & (1 << k)) ^ (crc & 1));
			  crc = crc >> 1;
			  if(input_bit) {
				  crc ^= (1 << 15);
				  crc ^= (1 << 10);
				  crc ^= (1 <<  3);
			  }
		  }
	  }

	  return crc;
  }

};

dummycoord::sptr dummycoord::make(int pan_id, long src_addr, bool short_addr_mode, long epid) {

  return gnuradio::get_initial_sptr (new dummycoord_impl(pan_id, src_addr, short_addr_mode, epid));
}
