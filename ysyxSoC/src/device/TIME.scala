package ysyx

import chisel3._
import chisel3.util._

import freechips.rocketchip.amba.axi4._
import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._

class TIMEHelper extends BlackBox with HasBlackBoxInline {
  val io = IO(new Bundle {
    val clock = Input(Clock())
    val reset = Input(Reset())
    val raddr = Input(UInt(32.W))
    val ren = Input(Bool())
    val rdata = Output(UInt(32.W))
  })
  setInline(
    "TIMEHelper.v",
    """module TIMEHelper(
      |  input clock,
      |  input reset,
      |  input [31:0] raddr,
      |  input ren,
      |  output reg [31:0] rdata
      |);
      |reg [63:0] mtime;
      |always @(posedge clock) begin
      |   if(reset) mtime <= 'b0;
      |   else mtime <= mtime + 'b1;
      |end
      |
      |import "DPI-C" function void time_read(input int raddr, output int rdata);
      |always @(*) begin
      |   if(ren) begin
      |     if(raddr[3:0] == 'h0)
      |       rdata = mtime[31:0];
      |     else if(raddr[3:0] == 'h4)
      |       rdata = mtime[63:32];
      |     else if(raddr[3:0] == 'h8 || raddr[3:0] == 'hc)
      |       time_read(raddr, rdata);
      |     else rdata = 'h0;
      |   end else rdata = 'h0;
      |end
      |endmodule
    """.stripMargin
  )
}

class AXI4TIME(address: Seq[AddressSet])(implicit p: Parameters)
    extends LazyModule {
  val beatBytes = 4
  val node = AXI4SlaveNode(
    Seq(
      AXI4SlavePortParameters(
        Seq(
          AXI4SlaveParameters(
            address = address,
            executable = true,
            supportsWrite = TransferSizes.none,
            supportsRead = TransferSizes(1, beatBytes),
            interleavedId = Some(0)
          )
        ),
        beatBytes = beatBytes
      )
    )
  )

  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    val (in, _) = node.in(0)

    val time = Module(new TIMEHelper)

    val (stateIdle, stateWaitRready) = (0.U, 1.U)
    val state = RegInit(stateIdle)
    state := Mux(
      state === stateIdle,
      Mux(in.ar.fire, stateWaitRready, stateIdle),
      Mux(in.r.fire, stateIdle, stateWaitRready)
    )

    time.io.clock := clock
    time.io.reset := reset.asBool
    time.io.raddr := in.ar.bits.addr
    time.io.ren := in.ar.fire
    in.ar.ready := (state === stateIdle)
//    assert(!(in.ar.fire && in.ar.bits.size === 3.U), "do not support 8 byte transfter")

    in.r.bits.data := RegEnable(time.io.rdata, in.ar.fire)
    in.r.bits.id := RegEnable(in.ar.bits.id, in.ar.fire)
    in.r.bits.resp := 0.U
    in.r.bits.last := true.B
    in.r.valid := (state === stateWaitRready)

    in.aw.ready := false.B
    in.w.ready := false.B
    in.b.valid := false.B

    assert(!in.aw.valid, "do not support write operations")
    assert(!in.w.valid, "do not support write operations")
  }
}
