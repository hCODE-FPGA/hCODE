{
  "name": "test2",
  "type": "ip",
  "version": "0.0.1",
  "summary": "A summary of test.",
  "description": "A description of test.",
  "homepage": "http://www.example.com/test",
  "license": "MIT",
  "authors": {
    "tester": "tester@example.com"
  },
  "source": {
    "git": "https://example.com/test.git",
    "tag": "0.0.1"
  },
  "platforms": {
    "vc707": "0.0.0"
  },
  "shells": {
    "name": "shell-vc707-xillybus-ap_fifo32"
  },
  "code": {
    "verilog": true, 
    "verilog_generator": false,
    "vhdl": false,
    "vhdl_generator": false,
    "vivado_hls": true,
    "hls_generator": true
  },
  "ides": {
    "version": "vivado2015.3",
    "version": "vivado2015.4"
  },
  "properties": {
    "max-clock": "250MHz",
    "host-fpga": {
        "name": "xillybus-eval-virtex7-1.2c",
        "interface": {
            "protocol" : "ap-stream",
            "datawidth" : "32"
        }
    }
  }
}

