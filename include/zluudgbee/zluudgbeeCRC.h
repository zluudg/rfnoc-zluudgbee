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


#ifndef INCLUDED_ZLUUDGBEE_ZLUUDGBEECRC_H
#define INCLUDED_ZLUUDGBEE_ZLUUDGBEECRC_H

#include <zluudgbee/api.h>
#include <ettus/device3.h>
#include <ettus/rfnoc_block.h>
#include <uhd/stream.hpp> // TODO Verify whether this is needed

namespace gr {
  namespace zluudgbee {

    /*!
     * \brief <+description of block+>
     * \ingroup zluudgbee
     *
     */
    class ZLUUDGBEE_API zluudgbeeCRC : virtual public gr::ettus::rfnoc_block
    {
     public:
      typedef boost::shared_ptr<zluudgbeeCRC> sptr;

      /*!
       * \brief Return a shared_ptr to a new instance of zluudgbee::zluudgbeeCRC.
       *
       * To avoid accidental use of raw pointers, zluudgbee::zluudgbeeCRC's
       * constructor is in a private implementation
       * class. zluudgbee::zluudgbeeCRC::make is the public interface for
       * creating new instances.
       */
      static sptr make(
        const gr::ettus::device3::sptr &dev,
        const ::uhd::stream_args_t &tx_stream_args,
        const ::uhd::stream_args_t &rx_stream_args,
        const int block_select=-1,
        const int device_select=-1,
        const bool enable_eob_on_stop=true
        );
    };
  } // namespace zluudgbee
} // namespace gr

#endif /* INCLUDED_ZLUUDGBEE_ZLUUDGBEECRC_H */

