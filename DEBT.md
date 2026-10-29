# Technical debt

## Ginga remote images hold the whole response in memory

`ee/engine/core/bind/ginga/draw_image.lua` only starts decoding a remote zcis
after the response is complete, so the encoded body stays in memory in full
before the first pixel reaches the canvas.

It used to be incremental. `02b004c` added to `ee/engine/protocol/http_fsc09.lua`
a `self.stream(chunk)` callback and a `self.discard_body` flag, and the image
bind pushed every chunk into `zcis_decoder.stream()`, so memory stayed bounded
no matter the image size. `f3ee475` rewrote that callback to drop chunked
support and the streaming hooks went away with it, leaving the bind talking to
a protocol that no longer answered. On 2026-10-29 the dead streaming path was
removed from the bind as well, together with its protocol test
(`test_fsc09_streams_without_retaining_body`).

Streaming does not depend on chunked transfer encoding: Ginga already delivers
the body in several `http` events, the protocol just chooses whether to
concatenate them. To bring it back:

- in the fsc09 callback, forward `evt.body` to `self.stream(evt.body, headers)`
  and skip the `data_dict` concat when `self.discard_body` is set;
- count the received bytes in their own table, since the completion check
  compares against `#data_dict`, which stays empty when the body is discarded;
- pass the response headers to the callback, the image bind needs them to spot
  `X-Encoding: cobs` while the body is still arriving;
- in the bind, create the decoder with `zcis_decoder.stream()` and feed it from
  the callback, keeping `zcis_decoder.new()` for the whole-body fallback.
