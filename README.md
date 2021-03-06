# lightning-sys

[![crates.io](https://img.shields.io/crates/v/lightning-sys.svg)](https://crates.io/crates/lightning-sys)
[![docs.rs](https://docs.rs/lightning-sys/badge.svg)](https://docs.rs/lightning-sys/)
[![Build Status](https://travis-ci.com/Petelliott/lightning-sys.svg?branch=master)](https://travis-ci.com/Petelliott/lightning-sys)

Safe gnu lightning bindings for rust

## GNU lightning version

This crate links explicitly against its own packaged copy of lightning-2.1.3.

## MSRV

The minimum supported Rust version is **1.39**.

## Examples

### a function that increments a number by one
```rust
use lightning_sys::{Jit, Reg, JitPointer, JitWord};

let mut jit = Jit::new();
let mut js = jit.new_state();

js.prolog();
let inarg = js.arg();
js.getarg(Reg::R(0), &inarg);
js.addi(Reg::R(0), Reg::R(0), 1);
js.retr(Reg::R(0));

let incr = unsafe { js.emit::<extern fn(JitWord) -> JitWord>() };
js.clear();

assert_eq!(incr(5), 6);
assert_eq!(incr(6), 7);

```

### A simple function call to `printf`
```rust
extern crate libc;

use std::ffi::CString;
use lightning_sys::{Jit, JitWord, Reg, JitPointer};
use std::convert::TryInto;

fn main() {
    let mut jit = Jit::new();
    let mut js = jit.new_state();

    // make sure this outlives any calls
    let cs = CString::new("generated %d bytes\n").unwrap();

    let start = js.note(file!(), line!());
    js.prolog();
    let inarg = js.arg();
    js.getarg(Reg::R(1), &inarg);
    js.prepare();
    js.pushargi(cs.as_ptr() as JitWord);
    js.ellipsis();
    js.pushargr(Reg::R(1));
    js.finishi(libc::printf as JitPointer);
    js.ret();
    js.epilog();
    let end = js.note(file!(), line!());

    let my_function = unsafe{ js.emit::<extern fn(JitWord)>() };
    /* call the generated code, passing its size as argument */
    my_function((js.address(&end) as u64 - js.address(&start) as u64).try_into().unwrap());
    js.clear();

    // TODO: dissasembly has not been implemented yet
    // js.dissasemble();
}

```
### Fibonacci numbers
```rust
use lightning_sys::{Jit, JitWord, Reg, JitPointer, NULL};

fn main() {
    let mut jit = Jit::new();
    let mut js = jit.new_state();

    let label = js.label();
                js.prolog();
    let inarg = js.arg();
                js.getarg(Reg::R(0), &inarg);
    let zero  = js.beqi(Reg::R(0), 0);
                js.movr(Reg::V(0), Reg::R(0));
                js.movi(Reg::R(0), 1);
    let refr  = js.blei(Reg::V(0), 2);
                js.subi(Reg::V(1), Reg::V(0), 1);
                js.subi(Reg::V(2), Reg::V(0), 2);
                js.prepare();
                js.pushargr(Reg::V(1));
    let call  = js.finishi(NULL);
                js.patch_at(&call, &label);
                js.retval(Reg::V(1));
                js.prepare();
                js.pushargr(Reg::V(2));
    let call2 = js.finishi(NULL);
                js.patch_at(&call2, &label);
                js.retval(Reg::R(0));
                js.addr(Reg::R(0), Reg::R(0), Reg::V(1));

                js.patch(&refr);
                js.patch(&zero);
                js.retr(Reg::R(0));
                js.epilog();

    let fib = unsafe{ js.emit::<extern fn(JitWord) -> JitWord>() };
    js.clear();

    println!("fib({})={}", 32, fib(32));
    assert_eq!(0, fib(0));
    assert_eq!(1, fib(1));
    assert_eq!(1, fib(2));
    assert_eq!(2178309, fib(32));
}
```

### Tail Call Optimized factorial
```rust
use lightning_sys::{Jit, JitWord, Reg, NULL};

fn main() {
    let mut jit = Jit::new();
    let mut js = jit.new_state();

    let fact = js.forward();

                js.prolog();
    let inarg = js.arg();
                js.getarg(Reg::R(0), &inarg);
                js.prepare();
                js.pushargi(1);
                js.pushargr(Reg::R(0));
    let call  = js.finishi(NULL);
                js.patch_at(&call, &fact);

                js.retval(Reg::R(0));
                js.retr(Reg::R(0));
                js.epilog();

    js.link(&fact);
                js.prolog();
                js.frame(16);
    let f_ent = js.label(); // TCO entry point
    let ac    = js.arg();
    let ina   = js.arg();
                js.getarg(Reg::R(0), &ac);
                js.getarg(Reg::R(1), &ina);
    let f_out = js.blei(Reg::R(1), 1);
                js.mulr(Reg::R(0), Reg::R(0), Reg::R(1));
                js.putargr(Reg::R(0), &ac);
                js.subi(Reg::R(1), Reg::R(1), 1);
                js.putargr(Reg::R(1), &ina);
    let jump  = js.jmpi(); // tail call optimiation
                js.patch_at(&jump, &f_ent);
                js.patch(&f_out);
                js.retr(Reg::R(0));

    let factorial = unsafe{ js.emit::<extern fn(JitWord) -> JitWord>() };
    js.clear();

    println!("factorial({}) = {}", 5, factorial(5));
}
```
