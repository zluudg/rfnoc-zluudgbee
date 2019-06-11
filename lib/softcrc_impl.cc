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

#include <zluudgbee/softcrc.h>
#include <gnuradio/io_signature.h>
#include <gnuradio/block_detail.h>

#include <iostream>
#include <iomanip>

using namespace gr::zluudgbee;


class softcrc_impl : public softcrc {

public:

    softcrc_impl(bool rx_mode) :
      gr::block("softcrc", gr::io_signature::make(0, 0, 0), gr::io_signature::make(0, 0, 0)),
      _rx_mode(rx_mode) {

	    message_port_register_in(pmt::mp("pdu in"));
	    set_msg_handler(pmt::mp("pdu in"), boost::bind(&softcrc_impl::handle_pdu, this, _1));

    	message_port_register_out(pmt::mp("pdu out"));
    }

  ~softcrc_impl() {

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
    uint16_t crc = crc16(pdu_ptr, pdu_len);

    if (_rx_mode) {

      if (!crc) {
        pmt::pmt_t vector = pmt::make_blob((uint8_t *) pmt::blob_data(blob), pdu_len-2);
        pmt::pmt_t pdu = pmt::cons(pmt::make_dict(), vector);
        message_port_pub(pmt::mp("pdu out"), pdu);
      }
    }
    else { // tx mode
      for (int i=0; i<pdu_len; i++)
        outgoing[i] = pdu_ptr[i];

      outgoing[pdu_len] = (uint8_t) crc & 0xFF;
      outgoing[pdu_len+1] = (uint8_t) (crc >> 1) & 0xFF;

      pmt::pmt_t vector = pmt::make_blob(outgoing, pdu_len+2);
      pmt::pmt_t pdu = pmt::cons(pmt::make_dict(), vector);
      message_port_pub(pmt::mp("pdu out"), pdu);
    }

  }


private:
  bool _rx_mode;
  uint8_t outgoing[256];

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

softcrc::sptr softcrc::make(bool rx_mode) {

  return gnuradio::get_initial_sptr(new softcrc_impl(rx_mode));
}
