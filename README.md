# UART UVM Verification Project

## 📘 Overview  
This repository implements a **UART (Universal Asynchronous Receiver/Transmitter)** transmitter + receiver in SystemVerilog, along with a **self-checking UVM testbench** that verifies the correct functionality of the UART datapath. It is designed for learning and demonstrating digital-design + verification skills (useful for interviews, academic projects, or resume portfolio).  

## ✅ Features  
- Configurable baud-rate parameter  
- 8-bit data, 1 start bit, 1 stop bit  
- Separate TX (transmitter) and RX (receiver) RTL modules  
- Self-checking UVM-style verification: random data stimulus, scoreboard, and assertions to catch protocol violations  
- Clean RTL + verification separation so one can reuse the verification environment for similar UART-type designs  

## 📁 Repository Structure  

## 🛠️ How to Run / Simulate  

Using any SystemVerilog-capable simulator (e.g. ModelSim, Questa, VCS, Xcelium):

```bash
# compile RTL + testbench
vlog design.sv tb.sv  
# run simulation
vsim -c work.tb -do "run -all; quit"


