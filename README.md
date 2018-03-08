# fluent-plugin-input-gelf

[![Build Status](https://travis-ci.org/andreycizov/fluent-plugin-input-gelf.svg?branch=master)](https://travis-ci.org/andreycizov/fluent-plugin-input-gelf)
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
</source>

<match example.gelf>
  type stdout
</match>
```
