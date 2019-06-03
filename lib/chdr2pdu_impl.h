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

#ifndef INCLUDED_ZLUUDGBEE_CHDR2PDU_IMPL_H
#define INCLUDED_ZLUUDGBEE_CHDR2PDU_IMPL_H

#include <zluudgbee/chdr2pdu.h>
#include <ettus/rfnoc_block_impl.h>

namespace gr {
  namespace zluudgbee {

    enum vector_type { byte_t, float_t, complex_t }; // TODO verify whether this is needed
   /*
    * This class was largely based on the rfnoc_pdu_rx_impl class found in the gr-ettus package.
    * Assume that everything in this class were copied from gr-ettus except where noted.
    * Link: https://github.com/EttusResearch/GR-Ettus
    */
    class chdr2pdu_impl : public chdr2pdu, public gr::ettus::rfnoc_block_impl
    {
     public:
      chdr2pdu_impl(
        const gr::ettus::device3::sptr &dev,
        const ::uhd::stream_args_t &tx_stream_args,
        const ::uhd::stream_args_t &rx_stream_args,
        const std::string &block_name,
        const int block_select,
        const int device_select,
        const int mtu,
        const bool enable_eob_on_stop
      );
      bool start();
      ~chdr2pdu_impl();

     private:
      bool d_started;
      bool d_finished;
      std::vector<uint8_t> d_rxbuf;
      gr::thread::thread d_thread;

      pmt::pmt_t d_port;
      basic_block *d_blk;

      void run();
      void start_rxthread(basic_block *blk, pmt::pmt_t rxport);
      void stop_rxthread();
    };

  } // namespace zluudgbee
} // namespace gr

#endif /* INCLUDED_ZLUUDGBEE_CHDR2PDU_IMPL_H */

