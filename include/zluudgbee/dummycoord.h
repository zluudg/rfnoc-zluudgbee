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


#ifndef INCLUDED_ZLUUDGBEE_DUMMYCOORD_H
#define INCLUDED_ZLUUDGBEE_DUMMYCOORD_H

#include <zluudgbee/api.h>
#include <gnuradio/block.h>

namespace gr {
  namespace zluudgbee {

    /*!
     * \brief <+description of block+>
     * \ingroup zluudgbee
     *
     */
    class ZLUUDGBEE_API dummycoord : virtual public gr::block
    {
     public:
      typedef boost::shared_ptr<dummycoord> sptr;

      /*!
       * \brief Return a shared_ptr to a new instance of zluudgbee::dummycoord.
       *
       * To avoid accidental use of raw pointers, zluudgbee::dummycoord's
       * constructor is in a private implementation
       * class. zluudgbee::dummycoord::make is the public interface for
       * creating new instances.
       */
      static sptr make(int pan_id=0xabcd, long src_addr=0x0000000000000001, bool short_addr_mode=true, long epid=0x000000000000000a);
    };

  } // namespace zluudgbee
} // namespace gr

#endif /* INCLUDED_ZLUUDGBEE_DUMMYCOORD_H */

