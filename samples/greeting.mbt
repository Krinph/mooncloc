# mooncloc sample files
#
# These tiny files exist to demo the tool on a realistic mix of languages.
# Run: moon run cmd/main -- samples

// A tiny MoonBit example: a greeting with a loop and a match.
pub fn greet(name: String, times: Int) -> Unit {
  for i = 0; i < times; i = i + 1 {
    // say hello in a loop
    println("Hello, \{name}!")
  }
  match times {
    0 => println("nobody to greet")
    _ => ()
  }
}
