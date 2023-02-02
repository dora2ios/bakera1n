/* Copyright 2023 0x7ff
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#ifndef LZFSE_H
#    define LZFSE_H
#    include <inttypes.h>
#    include <stdio.h>


#define LZFSE_ENCODE_L_STATES (64)
#define LZFSE_ENCODE_M_STATES (64)
#define LZFSE_ENCODE_D_STATES (256)
#define LZFSE_ENCODE_L_SYMBOLS (20)
#define LZFSE_ENCODE_M_SYMBOLS (20)
#define LZFSE_ENCODE_D_SYMBOLS (64)
#define LZFSE_MATCHES_PER_BLOCK (10000)
#define LZFSE_NO_BLOCK_MAGIC (0x00000000U)
#define LZFSE_ENCODE_LITERAL_STATES (1024)
#define LZFSE_ENCODE_LITERAL_SYMBOLS (256)
#define LZFSE_ENDOFSTREAM_BLOCK_MAGIC (0x24787662U)
#define LZFSE_UNCOMPRESSED_BLOCK_MAGIC (0x2D787662U)
#define LZFSE_COMPRESSEDV1_BLOCK_MAGIC (0x31787662U)
#define LZFSE_COMPRESSEDV2_BLOCK_MAGIC (0x32787662U)
#define LZFSE_COMPRESSEDLZVN_BLOCK_MAGIC (0x6E787662U)
#define LZFSE_LITERALS_PER_BLOCK (4 * LZFSE_MATCHES_PER_BLOCK)

size_t lzfse_decode_scratch_size(void);
size_t lzfse_decode_buffer(uint8_t *, size_t, const uint8_t *, size_t, void *);
#endif
