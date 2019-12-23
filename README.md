# fluent-plugin-input-gelf

[![Build Status](https://travis-ci.org/MerlinDMC/fluent-plugin-input-gelf.svg?branch=master)](https://travis-ci.org/MerlinDMC/fluent-plugin-input-gelf)
[![Gem Version](https://badge.fury.io/rb/fluent-plugin-input-gelf.svg)](http://badge.fury.io/rb/fluent-plugin-input-gelf)

## Overview

A GELF compatible input for [Fluentd](http://www.fluentd.org/).

### Configuration

Accept GELF encoded messages over UDP

```
<source>
  type gelf
  tag example.gelf
  bind 127.0.0.1
  port 12201
  # protocol_type            tcp   ##  (defaults to udp) 
  # trust_client_timestamp   false ##  (defaults to true)
  # client_timestamp_to_i    true  ##  (defaults to false)
  # remove_timestamp_record  false ##  (defaults to true)
</source>

<match example.gelf>
  @type file
  <format>
    @type out_file
    time_type string
    time_format '%Y-%m-%dT%H:%M:%S.%N %z'
  </format>
  path /tmp/output
</match>

```

### Configuration flags
  * protocol_type   
    * udp
    * tcp

  * trust_client_timestamp (default: true)
    * true  (use client provided timestamp for fluent metadata if it exists)
    * false (ignore client provided timestamp for fluent metadata)

    * client_timestamp_to_i (default: false) (ignored if trust_client_timestamp is false)
      * true  (truncate client provided timestamp to only time_t with no added resolution)
      * false (retain full client provided resolution)

    * remove_timestamp_record (default: true) (ignored if trust_client_timestamp is false)
      * true  (remove original timestamp record from client provided document)
      * false (retain original record and set fluent metadata time


