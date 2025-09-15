package ysyx

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.subsystem._
import freechips.rocketchip.amba.axi4._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._

object CPUAXI4BundleParameters {
  def apply() = AXI4BundleParameters(addrBits = 32, dataBits = 32, idBits = ChipLinkParam.idBits)
}

class npc_top extends BlackBox {
  val io = IO(new Bundle {
    val clock = Input(Clock())
    val reset = Input(Reset())
    val io_interrupt = Input(Bool())
    val io_master = AXI4Bundle(CPUAXI4BundleParameters())
    val io_slave = Flipped(AXI4Bundle(CPUAXI4BundleParameters()))
    val dnpc = Output(UInt(32.W))
    val pc = Output(UInt(32.W))
    val inst = Output(UInt(32.W))
    val update_dut = Output(Bool())
  })
}

class CPU(idBits: Int)(implicit p: Parameters) extends LazyModule {
  val masterNode = AXI4MasterNode(p(ExtIn).map(params =>
    AXI4MasterPortParameters(
      masters = Seq(AXI4MasterParameters(
        name = "cpu",
        id   = IdRange(0, 1 << idBits))))).toSeq)
  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    val (master, _) = masterNode.out(0)
    val pc = IO(Output(UInt(32.W)))
    val dnpc = IO(Output(UInt(32.W)))
    val inst = IO(Output(UInt(32.W)))
    val update_dut = IO(Output(Bool()))
    val interrupt = IO(Input(Bool()))
    val slave = IO(Flipped(AXI4Bundle(CPUAXI4BundleParameters())))

    val cpu = Module(new npc_top)
    cpu.io.clock := clock
    cpu.io.reset := reset
    cpu.io.io_interrupt := interrupt
    cpu.io.io_slave <> slave

    pc := cpu.io.pc
    dnpc := cpu.io.dnpc
    inst := cpu.io.inst
    update_dut := cpu.io.update_dut
    
    master <> cpu.io.io_master
  }
}
