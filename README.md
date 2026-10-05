# FPGA Compute Blocks

**SystemVerilog · Pipelining · FSMs**

SystemVerilog arithmetic and control designs: a registered ALU, Wordle controller, tanh pipeline and matrix-vector datapath.

## Quick start

```text
verilator --lint-only --top-module alu lab1/*.sv
```

## Design

`lab1/` contains arithmetic building blocks; `lab2/` contains a game FSM and integration testbench; `lab3/` contains tanh approximation; `lab4/` separates matrix-vector control, dot products and accumulation.

## Contribution

Primary contributor within the original team project. This repository retains team and starter-code attribution; see [PROVENANCE.md](PROVENANCE.md).

## Scope and validation

Full integration requires the original memory modules/IP and FPGA project environment, which are not all included. Exported binary hardware archives are omitted. Component lint does not establish timing closure or full functional correctness.

See [VALIDATION.md](VALIDATION.md) for checks run against this edition. Source background and authorship are recorded in [PROVENANCE.md](PROVENANCE.md).
