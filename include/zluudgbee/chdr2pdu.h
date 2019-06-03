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


#ifndef INCLUDED_ZLUUDGBEE_CHDR2PDU_H
#define INCLUDED_ZLUUDGBEE_CHDR2PDU_H

#include <zluudgbee/api.h>
#include <ettus/device3.h>
#include <ettus/rfnoc_block.h>
#include <uhd/stream.hpp> // TODO verify whether this is needed

namespace gr {
  namespace zluudgbee {

    /*!
     * \brief Converts an incoming CHDR packet of 32-bit samples into
     * a PDU. The PDU is represented by a PMT pair, one empty dict
     * (no metadate/tags) and one uint8 vector where element 'n' is
     * extracted from word 'n' in the incoming CHDR packet.
     * \ingroup zluudgbee
     *
     */
    class ZLUUDGBEE_API chdr2pdu : virtual public gr::ettus::rfnoc_block
    {
     public:
      typedef boost::shared_ptr<chdr2pdu> sptr;

      /*!
       * \brief Return a shared_ptr to a new instance of zluudgbee::chdr2pdu.
       *
       * To avoid accidental use of raw pointers, zluudgbee::chdr2pdu's
       * constructor is in a private implementation
       * class. zluudgbee::chdr2pdu::make is the public interface for
       * creating new instances.
       */
      static sptr make(
        const gr::ettus::device3::sptr &dev,
        const ::uhd::stream_args_t &tx_stream_args,
        const ::uhd::stream_args_t &rx_stream_args,
        const std::string &block_name,
        const int block_select=-1,
        const int device_select=-1,
        const int mtu=2048,
        const bool enable_eob_on_stop=true
        );
    };
  } // namespace zluudgbee
} // namespace gr

#endif /* INCLUDED_ZLUUDGBEE_CHDR2PDU_H */

