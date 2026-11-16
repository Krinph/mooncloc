// A tiny Rust sample: a fibonacci function with a comment.
pub fn fib(n: u64) -> u64 {
    if n < 2 {
        return n;
    }
    // iterative version
    let mut a = 0u64;
    let mut b = 1u64;
    for _ in 0..n {
        let tmp = a + b;
        a = b;
        b = tmp;
    }
    a
}
