# CXON_SIH25119 – V2X Hardware Security Module (HSM) FPGA Design

## Overview

This repository implements a **V2X Hardware Security Module (HSM)** in Verilog HDL.
The design focuses on **cryptographic SHA256 hashing** and **secure SPI communication**, integrated into a top-level FPGA project.

The project includes:

* A complete **SHA256 hashing core** (with round constants, message scheduler, and compression core).
* An **SPI Slave interface** with buffering logic for communication.
* A **protocol router** to handle V2X message routing.
* A **top-level FPGA module** with synthesis constraints.
* Multiple **testbenches** for simulation and verification.

---

## Features

* SHA256 implementation in Verilog (`sha256.v`, `sha256_core.v`, `sha256_w_mem.v`, `sha256_k_constants.v`).
* SPI Slave communication interface (`spi_slave_core.v`, `spi_buffer_manager.v`).
* V2X protocol routing (`v2x_protocol_router.v`).
* FPGA synthesis constraints (`v2x_hsm_constraints.xdc`).
* Comprehensive testbenches for **unit testing** and **system-level verification**.

---

## Repository Structure

```
v2x_hsm/
├── sha256/rtl/
│   ├── sha256.v
│   ├── sha256_core.v
│   ├── sha256_k_constants.v
│   └── sha256_w_mem.v
│
├── tb/
│   ├── tb_protocol_router.v
│   ├── tb_sha256.v
│   ├── tb_sha256_core.v
│   ├── tb_sha256_standalone.v
│   ├── tb_sha256_w_mem.v
│   ├── tb_spi_slave_core.v
│   └── tb_v2x_hsm_top.v
│
├── v2x_hsm_fpga/
│   ├── constraints/v2x_hsm_constraints.xdc
│   └── rtl/
│       ├── v2x_hsm_top.v
│       └── v2x_protocol_router.v
│
└── v2x_spi_slave/rtl/
    ├── spi_buffer_manager.v
    ├── spi_slave_core.v
    └── spi_slave_v2x_top.v
```

---

## Module Explanations (In-Depth)

### 1. **SHA256 Implementation**

* **`sha256.v`**
  Top-level wrapper for SHA256 hashing. Connects the core, message schedule, and constants.

* **`sha256_core.v`**
  Implements the **compression function** of SHA256:

  ```verilog
  module sha256_core(
      input wire clk,
      input wire reset_n,
      input wire init,
      input wire next,
      input wire [511:0] block,
      output wire ready,
      output wire [255:0] digest
  );
  ```

  * Handles the 64 SHA256 rounds using `sha256_k_constants.v`.

* **`sha256_k_constants.v`**
  Stores the **64 round constants** (K values) required for SHA256 hashing.

* **`sha256_w_mem.v`**
  Implements the **message schedule array W[0..63]**, expanding 512-bit input blocks into round data.

---

### 2. **SPI Slave Interface**

* **`spi_slave_core.v`**
  Implements a generic **SPI slave**:

  ```verilog
  module spi_slave_core(
      input wire sclk,
      input wire mosi,
      output wire miso,
      input wire cs_n
  );
  ```

* **`spi_buffer_manager.v`**
  Manages SPI data buffering and synchronization with the internal system clock.

* **`spi_slave_v2x_top.v`**
  Top-level SPI + buffer integration for the V2X system.

---

### 3. **Protocol Router & Top Level**

* **`v2x_protocol_router.v`**
  Routes commands between the **SPI interface** and the **SHA256 core**.

* **`v2x_hsm_top.v`**
  Top-level FPGA integration module:

  * Instantiates SHA256 core, SPI slave, and protocol router.
  * Interfaces with FPGA I/O.

* **`v2x_hsm_constraints.xdc`**
  FPGA pin mapping and timing constraints for synthesis.

---

### 4. **Testbenches**

* **`tb_sha256.v`** – Unit test for SHA256 wrapper.
* **`tb_sha256_core.v`** – Tests compression rounds.
* **`tb_sha256_w_mem.v`** – Tests message scheduler.
* **`tb_sha256_standalone.v`** – End-to-end SHA256 verification.
* **`tb_spi_slave_core.v`** – SPI communication test.
* **`tb_protocol_router.v`** – Ensures proper command routing.
* **`tb_v2x_hsm_top.v`** – Full system-level testbench.

---

## Build & Run Instructions

### Simulation

1. Use **ModelSim, Icarus Verilog, or Verilator** to run testbenches:

   ```bash
   iverilog -o tb_sha256 tb/tb_sha256.v sha256/rtl/*.v
   vvp tb_sha256
   ```
2. Check waveforms in GTKWave:

   ```bash
   gtkwave dump.vcd
   ```

### FPGA Synthesis

1. Open project in **Xilinx Vivado** (or compatible FPGA toolchain).
2. Add RTL sources (`sha256/rtl`, `v2x_spi_slave/rtl`, `v2x_hsm_fpga/rtl`).
3. Add constraints file:

   ```
   v2x_hsm/v2x_hsm_fpga/constraints/v2x_hsm_constraints.xdc
   ```
4. Run synthesis and implementation.
5. Generate bitstream and program FPGA.

---

## Usage Example

* Send a message block via **SPI Slave**.
* The **protocol router** forwards data to SHA256.
* The **SHA256 core** computes the digest.
* Digest output can be read back via SPI.

---

## Future Scope

* Add **other cryptographic primitives** (AES, ECC).
* Extend to a complete **V2X Security Module**.
* Integrate with automotive-grade FPGA/ASIC platforms.
* Improve test coverage with **constrained-random testing**.

---

Made by **TEAM CXON**
