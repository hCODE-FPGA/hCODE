{
  "name": "shell-vc707-xillybus-ap_fifo128",
  "type": "shell",
  "version": "0.1.1",
  "summary": "A hCODE shell based on xillybus-eval-vertex7-1.2c PCIe module.",
  "description": "Developed in Computer Arch. Lab@Kumamoto University, Japan.",
  "homepage": "http://arch.cs.kumamoto-u.ac.jp/hcode",
  "license": "MIT",
  "authors": {
    "Qian ZHAO": "cho@arch.cs.kumamoto-u.ac.jp"
  },
  "source": {
    "git": "https://github.com/jonsonxp/shell-vc707-xillybus-ap_fifo32.git",
    "tag": "0.1.1"
  },
  "hardware": {
  	"board": "vc707",
    "device": "xc7vx485tffg1761-2"
  },
  "interface": {
    "host": {
      "ap_fifo": {
        "data_width": 128
       },
       "mem": {
        "data_width": 256
       } 
    }
  }
}
